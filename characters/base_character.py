"""Turns a Meshy base-body file into a rigged, dress-able character body.

The Meshy files in bases/ are 3D versions of a whole turnaround sheet (front,
side and back figures side by side). This picks the front-facing figure,
scales it to a real height, centers it, turns it to face +Y, smooths it, and
finds joint positions for a humanoid rig from the mesh itself.

Clothing is made by lifting regions of the body surface outward (so it always
fits the body), and gets its skin weights copied from the body.
"""
import math
import os
import random
import sys

import bpy  # must come before bmesh when using the bpy pip module
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pets"))
from build_pets import (  # noqa: E402,F401
    add_capsule, add_ellipsoid, apply_modifiers, join, make_material, paint,
    remesh_and_smooth, reset_scene, srgb,
)

DARK = srgb(0.07, 0.05, 0.06)
WHITE = srgb(0.97, 0.96, 0.95)


# --------------------------------------------------------------------------
# Loading the base
# --------------------------------------------------------------------------

def bounds(obj):
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return (Vector([min(v[i] for v in vs) for i in range(3)]),
            Vector([max(v[i] for v in vs) for i in range(3)]))


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def load_base(path, height, name="body"):
    bpy.ops.import_scene.gltf(filepath=path)
    src = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    select_only(src)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    figures = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.vertices) > 100]
    # The front view is the top-left figure of the sheet.
    top = [o for o in figures if bounds(o)[0].z > -0.1]
    body = min(top, key=lambda o: bounds(o)[0].x)
    for o in list(bpy.context.scene.objects):
        if o is not body:
            bpy.data.objects.remove(o)
    body.name = name
    for attr in list(body.data.color_attributes):
        body.data.color_attributes.remove(attr)
    body.data.materials.clear()
    select_only(body)

    lo, hi = bounds(body)
    s = height / (hi.z - lo.z)
    body.scale = (s, s, s)
    body.location = (0, 0, -lo.z * s)
    bpy.ops.object.transform_apply(location=True, scale=True, rotation=True)

    # Center on the neck (the sheet figures aren't centered on their arms),
    # and turn to face +Y (Meshy's figures face -Y).
    vs = [v.co for v in body.data.vertices]
    neck = [v for v in vs if abs(v.z - height * 0.8) < height * 0.015]
    cx = sum(v.x for v in neck) / len(neck)
    torso = [v for v in vs if abs(v.z - height * 0.65) < height * 0.02 and abs(v.x - cx) < 0.15]
    cy = sum(v.y for v in torso) / len(torso)
    body.location = (-cx, -cy, 0)
    bpy.ops.object.transform_apply(location=True)
    body.rotation_euler = (0, 0, math.pi)
    bpy.ops.object.transform_apply(rotation=True)

    sub = body.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = 2
    apply_modifiers(body)
    bpy.ops.object.shade_smooth()
    return body


# --------------------------------------------------------------------------
# Landmarks
# --------------------------------------------------------------------------

def centroid(points):
    return sum(points, Vector()) / len(points) if points else None


class Landmarks:
    """Joint positions measured from the body mesh (right side is +X)."""

    def __init__(self, body, height):
        self.H = H = height
        vs = [v.co.copy() for v in body.data.vertices]
        self.verts = vs

        def slice_centroid(z, side, xmin, xmax, band=0.015):
            pts = [v for v in vs if abs(v.z - z) < band and xmin < v.x * side < xmax]
            return centroid(pts)

        head = [v for v in vs if v.z > H * 0.83]
        self.head_center = centroid(head)
        self.head_center.z = (H + H * 0.815) / 2
        self.head_radius = Vector((
            max(abs(v.x - self.head_center.x) for v in head),
            max(abs(v.y - self.head_center.y) for v in head),
            (H - H * 0.815) / 2))
        self.neck = Vector((0, self.head_center.y * 0.5, H * 0.79))
        self.chin_z = H * 0.815

        # Arms: flood-fill from the fingertip through the part of the mesh
        # that hangs away from the torso, then trace its centerline.
        bm = bmesh.new()
        bm.from_mesh(body.data)
        bm.verts.ensure_lookup_table()
        self.arm = {}
        self.arm_verts = {}
        from mathutils import kdtree
        for side in (1, -1):
            limit = H * 0.115
            tip_v = max(bm.verts, key=lambda v: v.co.x * side)
            seen = {tip_v.index}
            todo = [tip_v]
            while todo:
                v = todo.pop()
                for e in v.link_edges:
                    o = e.other_vert(v)
                    if o.index not in seen and o.co.x * side > limit:
                        seen.add(o.index)
                        todo.append(o)
            pts = [bm.verts[i].co.copy() for i in seen]
            tree = kdtree.KDTree(len(pts))
            for i, p in enumerate(pts):
                tree.insert(p, i)
            tree.balance()
            self.arm_verts[side] = tree

            bins = {}
            for p in pts:
                bins.setdefault(round(p.z / 0.03), []).append(p)
            line = [centroid(bins[k]) for k in sorted(bins, reverse=True)]
            shoulder = Vector((H * 0.096 * side, line[0].y, H * 0.725))
            bottom = min(pts, key=lambda p: p.z)
            line = [shoulder] + line[:-1] + [bottom]
            lengths = [0.0]
            for p, q in zip(line, line[1:]):
                lengths.append(lengths[-1] + (q - p).length)

            def at(frac, line=line, lengths=lengths):
                target = frac * lengths[-1]
                for i in range(len(line) - 1):
                    if lengths[i + 1] >= target:
                        t = (target - lengths[i]) / max(1e-6, lengths[i + 1] - lengths[i])
                        return line[i].lerp(line[i + 1], t)
                return line[-1].copy()
            self.arm[side] = dict(shoulder=shoulder, elbow=at(0.33), wrist=at(0.62),
                                  hand_end=at(0.82), tip=bottom,
                                  line=line, lengths=lengths, at=at)
        bm.free()

        self.leg = {}
        for side in (1, -1):
            knee = slice_centroid(H * 0.28, side, 0.02, 0.35)
            ankle = slice_centroid(H * 0.05, side, 0.02, 0.35, band=0.012)
            foot = [v for v in vs if v.z < H * 0.03 and v.x * side > 0.02]
            toe = max(foot, key=lambda v: v.y)
            hip = Vector((knee.x * 0.6, knee.y * 0.5, H * 0.5))
            self.leg[side] = dict(hip=hip, knee=knee, ankle=ankle,
                                  ball=Vector((ankle.x, (ankle.y + toe.y) / 2 + 0.02, 0.03)),
                                  toe=Vector((toe.x, toe.y, 0.03)))
        self.hips = Vector((0, 0, H * 0.52))

    def arm_param(self, co, side):
        """Position along the arm (0 shoulder .. 1 fingertip) and distance to it."""
        a = self.arm[side]
        line, lengths = a["line"], a["lengths"]
        best = (math.inf, 0.0)
        for i in range(len(line) - 1):
            seg = line[i + 1] - line[i]
            t = max(0.0, min(1.0, (co - line[i]).dot(seg) / max(1e-9, seg.length_squared)))
            d = (co - (line[i] + seg * t)).length
            if d < best[0]:
                best = (d, (lengths[i] + seg.length * t) / lengths[-1])
        return best[1], best[0]

    def is_arm(self, co):
        side = 1 if co.x > 0 else -1
        _, _, dist = self.arm_verts[side].find(co)
        return dist < 0.02


# --------------------------------------------------------------------------
# Rig
# --------------------------------------------------------------------------

def humanoid_bones(L):
    H = L.H
    spine = [L.hips, Vector((0, 0, H * 0.58)), Vector((0, 0, H * 0.64)),
             Vector((0, 0, H * 0.71)), L.neck, Vector((0, L.head_center.y, L.chin_z)),
             Vector((0, L.head_center.y, H))]
    names = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]
    bones = [(names[i], names[i - 1] if i else None, spine[i], spine[i + 1]) for i in range(6)]
    for side, s in (("Right", 1), ("Left", -1)):
        a, g = L.arm[s], L.leg[s]
        bones += [
            (side + "Shoulder", "UpperChest", Vector((0.03 * s, 0, a["shoulder"].z)), a["shoulder"]),
            (side + "UpperArm", side + "Shoulder", a["shoulder"], a["elbow"]),
            (side + "LowerArm", side + "UpperArm", a["elbow"], a["wrist"]),
            (side + "Hand", side + "LowerArm", a["wrist"], a["hand_end"]),
            (side + "UpperLeg", "Hips", g["hip"], g["knee"]),
            (side + "LowerLeg", side + "UpperLeg", g["knee"], g["ankle"]),
            (side + "Foot", side + "LowerLeg", g["ankle"], g["ball"]),
            (side + "Toes", side + "Foot", g["ball"], g["toe"]),
        ]
    return bones


def build_rig(name, L):
    arm_data = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new(name + "_rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bone, parent, head, tail in humanoid_bones(L):
        eb = arm_data.edit_bones.new(bone)
        eb.head, eb.tail = head, tail
        if parent:
            eb.parent = made[parent]
            eb.use_connect = (made[parent].tail - eb.head).length < 1e-5
        made[bone] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def auto_weight(body, rig):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def copy_weights(target, body):
    """Gives a garment the skin weights of the body underneath it."""
    for vg in body.vertex_groups:
        if vg.name not in target.vertex_groups:
            target.vertex_groups.new(name=vg.name)
    mod = target.modifiers.new("Weights", "DATA_TRANSFER")
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    select_only(target)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def set_weights(obj, fn):
    groups = {}
    for v in obj.data.vertices:
        for bone, w in fn(v.co).items():
            if w <= 0:
                continue
            if bone not in groups:
                groups[bone] = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")


# --------------------------------------------------------------------------
# Clothing and details
# --------------------------------------------------------------------------

def garment(body, name, include, offset, thickness=0.005, cuts=(), subdivide=0, keep=1.0):
    """Copies the faces of `body` where include(center) is true and pushes
    them outward by offset(co) meters along the surface normal.

    cuts: (point, normal, only) planes that trim the edges cleanly; geometry
    behind each plane is removed, limited to faces where only(center) is true
    (or everywhere when only is None)."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    drop = [f for f in bm.faces if not include(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for point, normal, only in cuts:
        faces = [f for f in bm.faces if only is None or only(f.calc_center_median())]
        geom = list({e for f in faces for e in f.edges}) + faces + list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=point, plane_no=normal, clear_inner=True)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if subdivide:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=subdivide, use_grid_fill=True)
    bm.normal_update()
    moves = [(v, v.normal.copy() * offset(v.co)) for v in bm.verts]
    for v, d in moves:
        v.co += d
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    select_only(obj)
    sm = obj.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.5
    sm.iterations = 2
    if keep < 1.0:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = keep
    if thickness:
        sol = obj.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = thickness
        sol.offset = -1
    apply_modifiers(obj)
    bpy.ops.object.shade_smooth()
    return obj


def hide_covered(body, covered):
    """Deletes body faces that clothing fully hides (saves triangles and stops
    skin poking through)."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    drop = [f for f in bm.faces if all(covered(v.co) for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()


def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def blob(name, center, size, color, rot=None):
    bm = bmesh.new()
    mat = Matrix.Translation(center)
    if rot is not None:
        mat = mat @ rot
    mat = mat @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0, matrix=mat)
    obj = new_object(name, bm)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, lambda co, n: color)
    return obj


def tube(name, points, radius, color):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, pt in zip(spline.points, points):
        p.co = (pt.x, pt.y, pt.z, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    select_only(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    paint(obj, lambda co, n: color)
    return obj


def face_point(x, z):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    hit, loc, *_ = bpy.context.scene.ray_cast(depsgraph, Vector((x, 2.0, z)), Vector((0, -1, 0)))
    if not hit:
        sys.exit(f"face placement missed at x={x}, z={z}")
    return loc


def anime_eyes(L, iris, spacing=0.043, height=0.0, size=1.0, brow_tilt=0.0, lashes=1.0):
    """Eyes, brows and mouth placed on the front of the head."""
    parts = []
    c = L.head_center
    ez = c.z - L.head_radius.z * 0.12 + height
    for s in (1, -1):
        p = face_point(c.x + spacing * s, ez) + Vector((0, -0.004, 0))
        k = size
        parts.append(blob("sclera", p, (0.02 * k, 0.006, 0.012 * k), WHITE))
        parts.append(blob("iris", p + Vector((-0.002 * s, 0.003, -0.001)), (0.011 * k, 0.005, 0.012 * k), iris))
        parts.append(blob("pupil", p + Vector((-0.002 * s, 0.006, -0.001)), (0.005 * k, 0.003, 0.007 * k), DARK))
        parts.append(blob("shine", p + Vector((0.002 * s, 0.008, 0.004 * k)), (0.0028, 0.002, 0.0028), WHITE))
        parts.append(blob("lash", p + Vector((0, 0.004, 0.011 * k)), (0.022 * k, 0.005, 0.0035 * lashes), DARK))
        brow = face_point(c.x + (spacing + 0.002) * s, ez + 0.03 * k) + Vector((0, 0.001, 0))
        parts.append(blob("brow", brow, (0.022, 0.004, 0.0042), DARK,
                          rot=Matrix.Rotation(brow_tilt * s, 4, "Y")))
    mouth = face_point(c.x, ez - L.head_radius.z * 0.55)
    parts.append(blob("mouth", mouth + Vector((0, 0.0005, 0)), (0.014, 0.003, 0.0018), srgb(0.35, 0.18, 0.16)))
    return parts


def curly_hair(L, color, color_alt, seed=7, curl=0.034, count=150, fringe=0.0):
    """A mop of curls: overlapping balls over the top, sides and back of the
    head, fused into one mesh that keeps its bumpy outline."""
    rnd = random.Random(seed)
    c, r = L.head_center, L.head_radius
    bm = bmesh.new()
    placed = 0
    while placed < count:
        # Random direction on the upper/back part of the head.
        u = rnd.uniform(-1, 1)
        a = rnd.uniform(0, math.tau)
        d = Vector((math.sqrt(1 - u * u) * math.cos(a), math.sqrt(1 - u * u) * math.sin(a), u))
        front = d.y > 0.3
        if front and d.z < 0.35 - fringe:
            continue  # keep the face clear, allowing a fringe over the brow
        if d.z < -0.35:
            continue
        rad = curl * rnd.uniform(0.8, 1.25)
        grow = 1.02 + rnd.uniform(0.0, 0.25)
        p = c + Vector((d.x * r.x * grow, d.y * r.y * grow, d.z * r.z * grow))
        add_ellipsoid(bm, p, (rad, rad, rad))
        placed += 1
    hair = new_object("hair", bm)
    remesh_and_smooth(hair, voxel=0.007, smooth_repeat=2)
    dec = hair.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, 2600 / max(1, len(hair.data.polygons)))
    apply_modifiers(hair)
    bpy.ops.object.shade_smooth()
    paint(hair, lambda co, n: color_alt if (math.sin(co.x * 90) * math.sin(co.z * 80 + co.y * 60)) > 0.55 else color)
    return hair


WRIST_T = 0.62


def replace_hands(body, L, skin):
    """Swaps the base's mitten hands for smaller anime hands with fingers."""
    def in_hand(co):
        side = 1 if co.x > 0 else -1
        return L.is_arm(co) and L.arm_param(co, side)[0] > WRIST_T + 0.02
    hide_covered(body, in_hand)

    hands = []
    for side in (1, -1):
        a = L.arm[side]
        wrist = a["wrist"]
        down = (a["tip"] - wrist).normalized()
        # Palm faces the body (thin across X), fingers point along the arm.
        across = Vector((0, 1, 0))
        across = (across - down * across.dot(down)).normalized()
        flat = down.cross(across)
        scale = L.H / 1.78
        bm = bmesh.new()
        rot = Matrix((flat, across, down)).transposed().to_4x4()

        def ell(center, size):
            m = Matrix.Translation(center) @ rot @ Matrix.Diagonal((*size, 1.0))
            bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0, matrix=m)
        palm_c = wrist + down * 0.055 * scale
        ell(palm_c, (0.018 * scale, 0.042 * scale, 0.052 * scale))
        ell(wrist + down * 0.012 * scale, (0.022 * scale, 0.03 * scale, 0.03 * scale))
        for k, (off, length) in enumerate(((-0.026, 0.066), (-0.0087, 0.075), (0.0087, 0.072), (0.025, 0.06))):
            base = palm_c + down * 0.04 * scale + across * off * scale
            for j in range(6):
                t = j / 5
                ell(base + down * length * scale * t - flat * 0.02 * scale * t * t,
                    (0.0098 * scale, 0.0092 * scale, 0.0098 * scale))
        thumb0 = wrist + down * 0.035 * scale + across * 0.035 * scale + flat * 0.01 * scale
        thumb_dir = (down + across * 0.45 + flat * 0.55).normalized()
        for j in range(6):
            ell(thumb0 + thumb_dir * 0.045 * scale * j / 5, (0.011 * scale, 0.011 * scale, 0.011 * scale))
        hand = new_object("hand", bm)
        remesh_and_smooth(hand, voxel=0.0035, smooth_repeat=3)
        dec = hand.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = min(1.0, 1400 / max(1, len(hand.data.polygons)))
        apply_modifiers(hand)
        bpy.ops.object.shade_smooth()
        paint(hand, lambda co, n: skin)
        bone = ("Right" if side > 0 else "Left") + "Hand"
        set_weights(hand, lambda co, bone=bone: {bone: 1.0})
        hands.append(hand)
    return hands


def arm_band(body, L, name, t0, t1, offset, color):
    """A band wrapping both arms between t0 and t1 along the arm, with clean
    edges square to the arm."""
    cuts = []
    for side in (1, -1):
        at = L.arm[side]["at"]
        a, b = at(t0), at(t1)
        d = (b - a).normalized()
        on_side = lambda co, side=side: co.x * side > 0  # noqa: E731
        cuts += [(a, d, on_side), (b, -d, on_side)]

    def region(co):
        side = 1 if co.x > 0 else -1
        t, dist = L.arm_param(co, side)
        return dist < 0.12 and abs(co.x) > L.H * 0.06 and t0 - 0.06 < t < t1 + 0.06
    band = garment(body, name, region, lambda co: offset, cuts=cuts)
    paint(band, lambda co, n: color)
    return band


def sandal_straps(L, color, top=0.3, turns=2.3, radius=0.0045):
    """Straps criss-crossing up each calf, fitted by casting rays at the leg.
    Call while the body is the only thing near the legs."""
    objs = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for side in (1, -1):
        ankle = L.leg[side]["ankle"]
        knee = L.leg[side]["knee"]
        for turn in (1, -1):
            pts = []
            for k in range(81):
                t = k / 80
                z = ankle.z - 0.01 + t * (top - ankle.z)
                axis = ankle.lerp(knee, (z - ankle.z) / (knee.z - ankle.z))
                a = turn * t * turns * math.tau + (0.0 if turn > 0 else math.pi)
                d = Vector((math.cos(a), math.sin(a), 0.0))
                origin = Vector((axis.x, axis.y, z)) + d * 0.075
                hit, loc, *_ = bpy.context.scene.ray_cast(depsgraph, origin, -d)
                if hit:
                    pts.append(loc + d * 0.002)
            objs.append(tube("strap", pts, radius, color))
        toe = []
        for k in range(21):
            a = math.pi * (0.12 + 0.76 * k / 20)
            d = Vector((math.cos(a), 0.0, math.sin(a)))
            center = Vector((ankle.x, L.leg[side]["ball"].y, 0.0))
            hit, loc, *_ = bpy.context.scene.ray_cast(depsgraph, center + d * 0.075, -d)
            if hit:
                toe.append(loc + d * 0.002)
        objs.append(tube("toe_strap", toe, radius * 1.2, color))
    return objs


def ring_skirt(center, top_z, top_r, hem_z, hem_r, color_fn, pleats=0, pleat_depth=0.0,
               segs=96, rings=14, gaps=(), thickness=0.007, keep=None, rows=None):
    """A skirt as a flared tube. top_r / hem_r are (x, y) radii. hem_z may be
    a function of angle (0 = her right, pi/2 = front) for pointed hems.
    gaps: (angle, half_width) slits that open toward the hem."""
    hem = hem_z if callable(hem_z) else (lambda th: hem_z)
    bm = bmesh.new()
    ts = sorted(rows) if rows else [i / rings for i in range(rings + 1)]
    rings = len(ts) - 1
    grid = []
    for t in ts:
        row = []
        for j in range(segs):
            th = j / segs * math.tau
            rx = top_r[0] + (hem_r[0] - top_r[0]) * t
            ry = top_r[1] + (hem_r[1] - top_r[1]) * t
            wave = 1.0 + pleat_depth * t * (0.5 + 0.5 * math.cos(th * pleats)) if pleats else 1.0
            z = top_z + (hem(th) - top_z) * t
            row.append(bm.verts.new((center.x + rx * wave * math.cos(th),
                                     center.y + ry * wave * math.sin(th), z)))
        grid.append(row)
    for i in range(rings):
        for j in range(segs):
            th = (j + 0.5) / segs * math.tau
            tt = (ts[i] + ts[i + 1]) / 2
            if any(abs((th - g + math.pi) % math.tau - math.pi) < w * min(1.0, 0.25 + tt * 1.2)
                   for g, w in gaps):
                continue
            if keep is not None and not keep(th, tt):
                continue
            j2 = (j + 1) % segs
            bm.faces.new((grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    skirt = new_object("skirt", bm)
    select_only(skirt)
    sol = skirt.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = thickness
    apply_modifiers(skirt)
    bpy.ops.object.shade_smooth()

    def color(co, n):
        th = math.atan2(co.y - center.y, co.x - center.x) % math.tau
        t = (top_z - co.z) / max(1e-6, top_z - hem(th))
        return color_fn(th, t, co)
    paint(skirt, color)
    return skirt


def skirt_weights(L, top_z):
    """Blend a skirt from the hips to each thigh as it goes down."""
    H = L.H

    def fn(co):
        down = max(0.0, min(1.0, (top_z - co.z) / (H * 0.35)))
        side = max(0.0, min(1.0, abs(co.x) / (H * 0.07)))
        leg = down * side * 0.8
        bone = "RightUpperLeg" if co.x > 0 else "LeftUpperLeg"
        return {"Hips": 1.0 - leg, bone: leg}
    return fn


def export(name, body, rig, out_dir):
    body.data.validate()
    body.data.materials.clear()
    body.data.materials.append(make_material(name))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, name + ".blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, name + ".glb"),
        export_format="GLB",
        export_vertex_color="MATERIAL",
    )
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"{name}: {tris} triangles, {len(rig.data.bones)} bones")


def sneakers(body, L, shoe, accent, sole, top=0.12):
    """Sneakers with colored heel counters and toe caps."""
    legs = lambda co: not L.is_arm(co) and abs(co.x) < L.H * 0.2  # noqa: E731
    shoes = garment(body, "shoes", lambda co: co.z < top + 0.04 and legs(co), lambda co: 0.013,
                    cuts=[((0, 0, top), (0, 0, -1), None)], subdivide=1)
    paint(shoes, lambda co, n: shoe)
    soles = garment(body, "soles", lambda co: co.z < 0.05 and legs(co), lambda co: 0.02,
                    cuts=[((0, 0, 0.022), (0, 0, -1), None)])
    paint(soles, lambda co, n: sole)
    parts = [shoes, soles]
    for side in (1, -1):
        ay = L.leg[side]["ankle"].y
        foot = lambda co, side=side: legs(co) and co.x * side > 0 and co.z < top + 0.01  # noqa: E731
        heel = garment(body, "heel", lambda co, f=foot, ay=ay: f(co) and co.y < ay, lambda co: 0.017,
                       cuts=[((0, ay - 0.025, 0), (0, -1, 0), None), ((0, 0, top - 0.02), (0, 0, -1), None),
                             ((0, 0, 0.02), (0, 0, 1), None)])
        cap_y = ay + (L.leg[side]["toe"].y - ay) * 0.5
        toe = garment(body, "toe", lambda co, f=foot, cy=cap_y: f(co) and co.y > cy - 0.03, lambda co: 0.017,
                      cuts=[((0, cap_y, 0), (0, 1, 0), None), ((0, 0, 0.05), (0, 0, -1), None),
                            ((0, 0, 0.02), (0, 0, 1), None)])
        for g in (heel, toe):
            paint(g, lambda co, n: accent)
        parts += [heel, toe]
    return parts
