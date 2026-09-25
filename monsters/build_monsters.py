"""Monsters in a Dragon Quest / cartoon style: goblins, skeletons, a
nightmare bat and a shadow entity. Each has its own creature rig (not the
humanoid one) with idle / attack (and walk) animations baked in.

Run with Blender 5.x:
    blender --background --python monsters/build_monsters.py [name ...]
or with the bpy pip module (Python 3.13):
    python monsters/build_monsters.py [name ...]

Facing: every monster is modeled facing +Y and then turned to face -Y in
Blender, which is +Z in Godot (Godot's MODEL_FRONT and the glTF/Mixamo
convention). So in Godot they look down +Z, and "right" bones (.R) are on
the monster's own right.

Glowing parts (eyes, mouths) are a separate mesh named "glow" so they can
get an emissive material.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pets"))
import build_pets as bp  # noqa: E402
from build_pets import (  # noqa: E402
    add_capsule, add_ear, add_ellipsoid, add_sphere, apply_modifiers, bmesh, bpy, join, make_material, paint,
    remesh_and_smooth, reset_scene, srgb, surface_point, tube,
)
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

OUT = HERE
FLIP = Matrix.Rotation(math.pi, 4, "Z")   # modeled facing +Y -> exported facing -Y (+Z in Godot)
FLIP3 = FLIP.to_3x3()

BLACK = srgb(0.06, 0.05, 0.07)
WHITE = srgb(0.97, 0.96, 0.92)
BONE = srgb(0.95, 0.92, 0.8)
BONE_SHADE = srgb(0.8, 0.75, 0.6)
RUST = srgb(0.62, 0.36, 0.2)
STEEL = srgb(0.7, 0.72, 0.76)
WOOD = srgb(0.55, 0.35, 0.2)
WOOD_DARK = srgb(0.4, 0.24, 0.13)
LEATHER = srgb(0.45, 0.28, 0.16)
CLOTH = srgb(0.62, 0.48, 0.32)


# --------------------------------------------------------------------------
# Mesh helpers
# --------------------------------------------------------------------------

def blob_mesh(name, shapes, color_fn, voxel=0.008, smooth=8, spikes=(), faces=6000):
    """shapes: ("e", center, radii) / ("c", a, b, ra, rb); spikes: (base, tip, width, thickness)
    added after smoothing so they stay sharp."""
    bm = bmesh.new()
    for s in shapes:
        if s[0] == "e":
            add_ellipsoid(bm, Vector(s[1]), s[2])
        else:
            add_capsule(bm, Vector(s[1]), Vector(s[2]), s[3], s[4])
    obj = bp_obj(name, bm)
    remesh_and_smooth(obj, voxel=voxel, smooth_repeat=smooth)
    if spikes:
        bm = bmesh.new()
        for base, tip, w, t in spikes:
            add_ear(bm, Vector(base), Vector(tip), w, t)
        sp = bp_obj(name + "_spikes", bm)
        join([sp], obj)
        remesh_and_smooth(obj, voxel=voxel * 0.75, smooth_repeat=1)
    if len(obj.data.polygons) > faces:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = faces / len(obj.data.polygons)
        apply_modifiers(obj)
    smooth_shade(obj)
    paint(obj, color_fn)
    return obj


def bp_obj(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def smooth_shade(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()


def spikes_mesh(name, spikes, color):
    bm = bmesh.new()
    for base, tip, w, t in spikes:
        add_ear(bm, Vector(base), Vector(tip), w, t)
    obj = bp_obj(name, bm)
    smooth_shade(obj)
    paint(obj, lambda co, n: color)
    return obj


def ell(name, center, radii, color, rot=None, segs=(16, 10)):
    bm = bmesh.new()
    m = Matrix.Translation(center)
    if rot is not None:
        m = m @ rot
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0,
                              matrix=m @ Matrix.Diagonal((*radii, 1.0)))
    obj = bp_obj(name, bm)
    smooth_shade(obj)
    paint(obj, lambda co, n: color)
    return obj


def bone_piece(name, a, b, radius, knob=1.8, color=BONE, shade=BONE_SHADE):
    """A cartoon bone: a shaft with round knobs at both ends."""
    a, b = Vector(a), Vector(b)
    parts = [tube(name, [a, b], radius, color)]
    for p in (a, b):
        parts.append(ell(name + "_knob", p, (radius * knob,) * 3, shade, segs=(10, 6)))
    return parts


def face_point(x, z, lift=0.0):
    """Point on the front of the current mesh (ray along -Y from the front)."""
    return surface_point(x, z) + Vector((0, lift, 0))


# --------------------------------------------------------------------------
# Rig, skinning, animation
# --------------------------------------------------------------------------

def expand(bones):
    out = []
    for name, parent, head, tail in bones:
        if "{s}" not in name:
            out.append((name, parent, Vector(head), Vector(tail)))
            continue
        for side, s in (("R", 1), ("L", -1)):
            p = parent.format(s=side) if parent else None
            out.append((name.format(s=side), p, Vector((head[0] * s, head[1], head[2])),
                        Vector((tail[0] * s, tail[1], tail[2]))))
    return out


def make_rig(name, bones):
    """bones: (name, parent, head, tail), modeled facing +Y; built flipped to face -Y."""
    data = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new(name + "_rig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("root")
    root.head, root.tail = Vector((0, 0, 0)), Vector((0, 0, 0.2))
    made = {"root": root}
    for bname, parent, head, tail in expand(bones):
        eb = data.edit_bones.new(bname)
        eb.head, eb.tail = FLIP3 @ head, FLIP3 @ tail
        eb.align_roll(Vector((0, 0, 1)) if abs((tail - head).normalized().z) < 0.9 else Vector((0, -1, 0)))
        eb.parent = made[parent] if parent else root
        eb.use_connect = parent is not None and (made[parent].tail - eb.head).length < 1e-5
        made[bname] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
    return (p - (a + ab * t)).length


def skin(obj, rig, bones=None, rigid=None):
    """Nearest-bone weights (three nearest blended) among `bones`, or one rigid bone."""
    obj.vertex_groups.clear()
    if rigid:
        vg = obj.vertex_groups.new(name=rigid)
        vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        return
    segs = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones
            if b.name != "root" and (bones is None or b.name in bones)]
    groups = {}
    for v in obj.data.vertices:
        d = sorted((seg_dist(v.co, a, b), n) for n, a, b in segs)[:3]
        ws = [(n, 1.0 / (dist + 0.01) ** 3) for dist, n in d]
        total = sum(w for _, w in ws)
        for n, w in ws:
            if n not in groups:
                groups[n] = obj.vertex_groups.new(name=n)
            groups[n].add([v.index], w / total, "REPLACE")


def finish(name, rig, parts, glow_parts, animations):
    """parts / glow_parts: (obj, weight spec) where spec is a bone name (rigid), a set of
    bone names (nearest blend) or None (all bones)."""
    def prep(items):
        objs = []
        for obj, spec in items:
            obj.data.transform(obj.matrix_world)
            obj.matrix_world = Matrix.Identity(4)
            obj.data.transform(FLIP)
            if isinstance(spec, str):
                skin(obj, rig, rigid=spec)
            else:
                skin(obj, rig, bones=spec)
            objs.append(obj)
        return objs
    body = prep(parts)
    main = body[0]
    join(body[1:], main)
    main.name = name
    main.data.materials.clear()
    main.data.materials.append(make_material(name))
    meshes = [main]
    if glow_parts:
        glow = prep(glow_parts)
        g = glow[0]
        join(glow[1:], g)
        g.name = "glow"
        g.data.materials.clear()
        g.data.materials.append(make_material(name + "_glow"))
        meshes.append(g)
    for m in meshes:
        m.parent = rig
        mod = m.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    for anim_name, frames, pose_fn in animations:
        bake_action(rig, anim_name, frames, pose_fn)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL", export_animations=True,
                              export_animation_mode="NLA_TRACKS")
    tris = sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in meshes)
    print(f"{name}: {tris} triangles, {len(rig.data.bones)} bones, animations: "
          f"{', '.join(a[0] for a in animations)}")


def bake_action(rig, name, frames, pose_fn, step=2):
    """pose_fn(t in 0..1) -> {bone: dict(rot=[(world_axis, angle), ...], loc=world_offset)} with
    axes and offsets given as modeled (facing +Y); they are flipped like the mesh."""
    rig.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    keyed = set()
    for f in range(0, frames + 1, step):
        pose = pose_fn(f / frames)
        for bname, spec in pose.items():
            pb = rig.pose.bones[bname]
            pb.rotation_mode = "QUATERNION"
            rest = pb.bone.matrix_local.to_3x3()
            rq = rest.to_quaternion()
            q = Quaternion()
            for axis, ang in spec.get("rot", ()):
                q = Quaternion(FLIP3 @ Vector(axis), ang) @ q
            pb.rotation_quaternion = rq.inverted() @ q @ rq
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
            if "loc" in spec:
                pb.location = rest.inverted() @ (FLIP3 @ Vector(spec["loc"]))
                pb.keyframe_insert("location", frame=f + 1)
            keyed.add(bname)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    rig.animation_data.action = None
    for bname in keyed:
        pb = rig.pose.bones[bname]
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)


def wave(t, cycles=1.0, phase=0.0):
    return math.sin(t * math.tau * cycles + phase)


def keys(t, points):
    """Smooth interpolation through (t, value) keys."""
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / max(1e-9, t1 - t0)
            u = u * u * (3 - 2 * u)
            return v0 + (v1 - v0) * u
    return points[-1][1]


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


# --------------------------------------------------------------------------
# Goblin: about 1.05 m to the ear tips, big head, pot belly, bandy legs.
# --------------------------------------------------------------------------

GOBLIN_BONES = [
    ("pelvis", None, (0, 0, 0.36), (0, 0, 0.46)),
    ("spine", "pelvis", (0, 0, 0.46), (0, 0.02, 0.56)),
    ("chest", "spine", (0, 0.02, 0.56), (0, 0, 0.66)),
    ("neck", "chest", (0, 0, 0.66), (0, 0.03, 0.75)),
    ("head", "neck", (0, 0.03, 0.75), (0, 0.05, 1.02)),
    ("ear.{s}", "head", (0.14, 0.02, 0.88), (0.34, -0.04, 0.96)),
    ("upper_arm.{s}", "chest", (0.12, 0, 0.62), (0.2, 0.01, 0.47)),
    ("forearm.{s}", "upper_arm.{s}", (0.2, 0.01, 0.47), (0.26, 0.04, 0.34)),
    ("hand.{s}", "forearm.{s}", (0.26, 0.04, 0.34), (0.29, 0.06, 0.22)),
    ("thigh.{s}", "pelvis", (0.08, 0, 0.38), (0.12, 0.02, 0.22)),
    ("shin.{s}", "thigh.{s}", (0.12, 0.02, 0.22), (0.11, 0, 0.07)),
    ("foot.{s}", "shin.{s}", (0.11, 0, 0.07), (0.11, 0.15, 0.03)),
]

GOBLIN_COATS = {
    "goblin": dict(skin=srgb(0.45, 0.7, 0.3), belly=srgb(0.66, 0.82, 0.45), inner=srgb(0.9, 0.55, 0.55),
                   iris=srgb(0.98, 0.85, 0.2), cloth=CLOTH),
    "goblin_cave": dict(skin=srgb(0.5, 0.58, 0.72), belly=srgb(0.7, 0.76, 0.84), inner=srgb(0.85, 0.55, 0.6),
                        iris=srgb(0.95, 0.35, 0.2), cloth=srgb(0.45, 0.35, 0.5)),
}


def goblin(coat_name):
    c = GOBLIN_COATS[coat_name]
    reset_scene()
    shapes = [("e", (0, 0, 0.4), (0.12, 0.1, 0.08)), ("e", (0, 0.035, 0.5), (0.15, 0.14, 0.13)),
              ("e", (0, 0, 0.6), (0.13, 0.1, 0.09)), ("c", (0, 0.01, 0.64), (0, 0.03, 0.78), 0.055, 0.055),
              ("e", (0, 0.04, 0.88), (0.165, 0.15, 0.15)), ("e", (0, 0.13, 0.93), (0.13, 0.06, 0.045)),
              ("e", (0, 0.07, 0.8), (0.145, 0.11, 0.075)),
              ("c", (0, 0.16, 0.89), (0, 0.27, 0.83), 0.038, 0.022)]
    for s in (1, -1):
        shapes += [("c", (0.12 * s, 0, 0.62), (0.2 * s, 0.01, 0.47), 0.042, 0.034),
                   ("c", (0.2 * s, 0.01, 0.47), (0.26 * s, 0.04, 0.34), 0.036, 0.03),
                   ("e", (0.275 * s, 0.05, 0.3), (0.045, 0.04, 0.05)),
                   ("c", (0.08 * s, 0, 0.38), (0.12 * s, 0.02, 0.22), 0.052, 0.04),
                   ("c", (0.12 * s, 0.02, 0.22), (0.11 * s, 0, 0.07), 0.038, 0.03),
                   ("e", (0.11 * s, 0.06, 0.035), (0.05, 0.1, 0.035))]
        for dx, dy in ((0.02, 0.03), (0.0, 0.0), (0.02, -0.03)):
            shapes.append(("c", (0.28 * s, 0.05 + dy, 0.28), ((0.3 + dx) * s, 0.07 + dy, 0.21), 0.015, 0.011))
        shapes.append(("c", (0.26 * s, 0.08, 0.31), (0.255 * s, 0.11, 0.27), 0.014, 0.011))
    spikes = []
    for s in (1, -1):
        spikes.append(((0.13 * s, 0.02, 0.89), (0.36 * s, -0.05, 0.97), 0.13, 0.04))
        for dx in (-0.025, 0.0, 0.025):
            spikes.append(((0.11 * s + dx, 0.15, 0.03), (0.11 * s + dx * 1.3, 0.18, 0.02), 0.025, 0.02))
    hair = [((x, -0.02, 1.02), (x * 1.3, -0.1, 1.1), 0.05, 0.03) for x in (-0.05, 0.0, 0.05)]

    def color(co, n):
        x, y, z = co
        ax = abs(x)
        if ax > 0.17 and z > 0.84 and 0.07 < ax < 0.36 and n.y > 0.3 and z < 0.98 and ax < 0.3:
            return c["inner"]
        if z > 1.0 and y < 0.02:
            return BLACK
        if z < 0.05 and y > 0.14:
            return BLACK  # toenails
        if 0.42 < z < 0.6 and y > 0.1 and ax < 0.11:
            return c["belly"]
        return c["skin"]
    body = blob_mesh("goblin", shapes, color, voxel=0.007, spikes=spikes, faces=5500)
    tufts = spikes_mesh("hair", hair, BLACK)
    extras = []
    eyes = bp.add_eyes(dict(x=0.065, z=0.915, radius=0.036, sink=0.006, tall=1.1, pupil_w=0.35, iris=c["iris"],
                            rim=True))
    extras += eyes
    # Wide grin with two fangs.
    mouth = [face_point(x, 0.785 + 5.0 * x * x, 0.004) for x in [k / 10 * 0.1 for k in range(-10, 11)]]
    extras.append(tube("mouth", mouth, 0.007, BLACK))
    bm = bmesh.new()
    for s in (1, -1):
        p = face_point(0.045 * s, 0.792, -0.004)
        add_ear(bm, p, p + Vector((0, 0.01, -0.035)), 0.02, 0.012)
    fangs = bp_obj("fangs", bm)
    smooth_shade(fangs)
    paint(fangs, lambda co, n: WHITE)
    extras.append(fangs)
    brow = [face_point(x, 0.965 - 0.25 * abs(x), 0.012) for x in (-0.11, -0.06, -0.02)]
    extras.append(tube("brow", brow, 0.01, srgb(0.2, 0.3, 0.12)))
    brow = [face_point(x, 0.965 - 0.25 * abs(x), 0.012) for x in (0.02, 0.06, 0.11)]
    extras.append(tube("brow", brow, 0.01, srgb(0.2, 0.3, 0.12)))
    # Loincloth, belt and a spiked club in the right hand.
    belt = [Vector((0.135 * math.cos(a), 0.035 + 0.13 * math.sin(a), 0.43)) for a in
            [math.tau * k / 24 for k in range(25)]]
    cloth = [tube("belt", belt, 0.018, LEATHER),
             ell("flap", (0, 0.13, 0.33), (0.075, 0.02, 0.1), c["cloth"]),
             ell("flap", (0, -0.08, 0.33), (0.085, 0.02, 0.1), c["cloth"]),
             ell("buckle", (0, 0.168, 0.43), (0.028, 0.01, 0.022), srgb(0.75, 0.62, 0.3))]
    club = blob_mesh("club", [("c", (0.285, 0.06, 0.27), (0.32, 0.3, 0.46), 0.022, 0.03),
                              ("e", (0.335, 0.38, 0.52), (0.07, 0.09, 0.07))],
                     lambda co, n: WOOD if co[1] < 0.3 else WOOD_DARK, voxel=0.008, smooth=3,
                     spikes=[((0.335 + dx, 0.38 + dy, 0.52 + dz), (0.335 + dx * 2.2, 0.38 + dy * 2.2, 0.52 + dz * 2.2),
                              0.03, 0.03) for dx, dy, dz in ((0.06, 0, 0.02), (-0.06, 0.02, 0.01), (0, 0.07, 0.03),
                                                              (0.01, 0.02, 0.07), (0.02, -0.05, 0.04))],
                     faces=2500)
    paint(club, lambda co, n: WHITE if 0.105 < (Vector(co) - Vector((0.335, 0.38, 0.52))).length < 0.2 else
          (WOOD if co[1] < 0.3 else WOOD_DARK))
    rig = make_rig(coat_name, GOBLIN_BONES)
    body_bones = None
    parts = [(body, body_bones), (tufts, "head")] + [(e, "head") for e in extras] + \
            [(p, "pelvis") for p in cloth] + [(club, "hand.R")]

    def idle(t):
        b = wave(t)
        return {"root": dict(loc=(0, 0, 0.008 * wave(t, 2))),
                "chest": dict(rot=[(X, 0.03 * b)]), "head": dict(rot=[(Z, 0.12 * wave(t, 1, 1)), (Y, 0.06 * b)]),
                "ear.R": dict(rot=[(Y, -0.15 * max(0, wave(t, 2, 0.5)) ** 4)]),
                "ear.L": dict(rot=[(Y, 0.15 * max(0, wave(t, 2, 2.0)) ** 4)]),
                "upper_arm.R": dict(rot=[(X, 0.08 * b)]), "upper_arm.L": dict(rot=[(X, -0.08 * b)])}

    def walk(t):
        s = wave(t)
        return {"root": dict(loc=(0, 0, 0.02 * abs(wave(t, 1, 0.3)))),
                "pelvis": dict(rot=[(Y, 0.08 * s), (Z, 0.12 * s)]),
                "thigh.R": dict(rot=[(X, 0.55 * s)]), "thigh.L": dict(rot=[(X, -0.55 * s)]),
                "shin.R": dict(rot=[(X, -0.6 * max(0, -wave(t, 1, 0.8)))]),
                "shin.L": dict(rot=[(X, -0.6 * max(0, wave(t, 1, 0.8)))]),
                "upper_arm.R": dict(rot=[(X, -0.45 * s)]), "upper_arm.L": dict(rot=[(X, 0.45 * s)]),
                "head": dict(rot=[(Y, -0.08 * s)])}

    def attack(t):
        up = keys(t, [(0, 0.0), (0.35, 2.4), (0.5, -0.2), (0.7, -0.1), (1, 0.0)])
        lean = keys(t, [(0, 0.0), (0.35, -0.15), (0.5, 0.3), (1, 0.0)])
        return {"upper_arm.R": dict(rot=[(X, up)]), "forearm.R": dict(rot=[(X, 0.5 * max(0, up) / 2.4)]),
                "spine": dict(rot=[(X, lean), (Z, -0.3 * lean)]), "head": dict(rot=[(X, -0.5 * lean)]),
                "upper_arm.L": dict(rot=[(X, -0.4 * lean), (Y, -0.4 * max(0, lean))]),
                "thigh.R": dict(rot=[(X, 0.4 * max(0, lean))]), "root": dict(loc=(0, 0.15 * max(0, lean), 0))}

    finish(coat_name, rig, parts, [], [("idle", 48, idle), ("walk", 24, walk), ("attack", 24, attack)])


# --------------------------------------------------------------------------
# Skeleton: about 1.7 m, big friendly-spooky skull, glowing eyes.
# --------------------------------------------------------------------------

SKELETON_BONES = [
    ("pelvis", None, (0, 0, 0.84), (0, 0, 0.95)),
    ("spine", "pelvis", (0, 0, 0.95), (0, 0, 1.12)),
    ("chest", "spine", (0, 0, 1.12), (0, 0, 1.3)),
    ("neck", "chest", (0, 0, 1.3), (0, 0.01, 1.38)),
    ("head", "neck", (0, 0.01, 1.38), (0, 0.02, 1.76)),
    ("jaw", "head", (0, -0.02, 1.49), (0, 0.13, 1.41)),
    ("upper_arm.{s}", "chest", (0.21, 0, 1.28), (0.3, 0.0, 1.02)),
    ("forearm.{s}", "upper_arm.{s}", (0.3, 0.0, 1.02), (0.36, 0.05, 0.8)),
    ("hand.{s}", "forearm.{s}", (0.36, 0.05, 0.8), (0.39, 0.07, 0.66)),
    ("thigh.{s}", "pelvis", (0.1, 0, 0.84), (0.12, 0.02, 0.47)),
    ("shin.{s}", "thigh.{s}", (0.12, 0.02, 0.47), (0.12, 0, 0.08)),
    ("foot.{s}", "shin.{s}", (0.12, 0, 0.08), (0.12, 0.16, 0.03)),
]


def skeleton(name, warrior):
    reset_scene()
    parts, glow = [], []
    skull = blob_mesh("skull", [("e", (0, 0.02, 1.6), (0.17, 0.165, 0.16)), ("e", (0, 0.07, 1.5), (0.14, 0.12, 0.08)),
                                ("e", (0, 0.14, 1.48), (0.1, 0.05, 0.05))],
                      lambda co, n: BONE_SHADE if co[2] < 1.46 else BONE, voxel=0.007, smooth=6, faces=2600)
    parts.append((skull, "head"))
    for s in (1, -1):
        p = face_point(0.062 * s, 1.56)
        parts.append((ell("socket", p + Vector((0, -0.015, 0)), (0.05, 0.03, 0.055), BLACK), "head"))
        glow.append((ell("eye", p + Vector((0, 0.013, -0.005)), (0.018, 0.008, 0.022),
                         srgb(1.0, 0.25, 0.2) if not warrior else srgb(0.35, 0.95, 1.0)), "head"))
    nose = face_point(0.0, 1.5)
    parts.append((ell("nose", nose + Vector((0, -0.005, 0)), (0.02, 0.02, 0.025), BLACK), "head"))
    for k in range(7):
        x = -0.06 + k * 0.02
        p = face_point(x, 1.455)
        parts.append((ell("tooth", p + Vector((0, 0.002, 0)), (0.009, 0.006, 0.014), WHITE), "head"))
    jaw_pts = [Vector((0.1 * math.sin(a), 0.03 + 0.1 * math.cos(a), 1.42)) for a in
               [math.radians(d) for d in range(-90, 91, 15)]]
    parts.append((tube("jaw", jaw_pts, 0.028, BONE), "jaw"))
    for k in range(6):
        a = math.radians(-40 + k * 16)
        parts.append((ell("tooth", Vector((0.1 * math.sin(a), 0.03 + 0.1 * math.cos(a), 1.445)), (0.008, 0.007, 0.013),
                          WHITE, segs=(8, 5)), "jaw"))
    # Spine, ribs, sternum, pelvis, collarbones.
    for k in range(9):
        z = 0.95 + k * 0.045
        bone = "spine" if z < 1.12 else ("chest" if z < 1.3 else "neck")
        parts.append((ell("vertebra", (0, -0.03, z), (0.03, 0.03, 0.018), BONE_SHADE, segs=(10, 6)), bone))
    for i, z in enumerate((1.26, 1.2, 1.14, 1.08)):
        rx = 0.16 - 0.012 * i
        for s in (1, -1):
            pts = [Vector((s * rx * math.sin(a), -0.02 - 0.09 * math.cos(a), z - 0.03 * a / math.pi)) for a in
                   [math.radians(d) for d in range(10, 161, 15)]]
            parts.append((tube("rib", pts, 0.013, BONE), "chest"))
    parts.append((tube("sternum", [Vector((0, 0.09, 1.28)), Vector((0, 0.1, 1.1))], 0.018, BONE), "chest"))
    for s in (1, -1):
        parts.append((tube("collarbone", [Vector((0.02 * s, 0.07, 1.31)), Vector((0.2 * s, 0.0, 1.3))], 0.016, BONE),
                      "chest"))
    pelvis = blob_mesh("pelvis", [("e", (0, 0, 0.9), (0.08, 0.06, 0.05)), ("e", (0.09, 0, 0.92), (0.07, 0.05, 0.07)),
                                  ("e", (-0.09, 0, 0.92), (0.07, 0.05, 0.07))],
                       lambda co, n: BONE, voxel=0.008, smooth=4, faces=2000)
    parts.append((pelvis, "pelvis"))
    # Limbs.
    for s, side in ((1, "R"), (-1, "L")):
        for p in bone_piece("humerus", (0.21 * s, 0, 1.28), (0.3 * s, 0.0, 1.02), 0.02):
            parts.append((p, "upper_arm." + side))
        for dx in (0.012, -0.012):
            parts.append((tube("forearm", [Vector(((0.3 + dx) * s, 0.0, 1.0)), Vector(((0.36 + dx) * s, 0.05, 0.82))],
                               0.012, BONE), "forearm." + side))
        parts.append((ell("wrist", (0.36 * s, 0.05, 0.8), (0.03, 0.025, 0.025), BONE_SHADE), "hand." + side))
        for k, dy in enumerate((-0.03, -0.01, 0.01, 0.03)):
            pts = [Vector((0.37 * s, 0.05 + dy * 0.6, 0.78)), Vector((0.385 * s, 0.05 + dy, 0.72)),
                   Vector((0.38 * s, 0.06 + dy, 0.67))]
            parts.append((tube("finger", pts, 0.008, BONE), "hand." + side))
        parts.append((tube("thumb", [Vector((0.35 * s, 0.07, 0.79)), Vector((0.345 * s, 0.1, 0.75))], 0.008, BONE),
                      "hand." + side))
        for p in bone_piece("femur", (0.1 * s, 0, 0.84), (0.12 * s, 0.02, 0.47), 0.024):
            parts.append((p, "thigh." + side))
        for p in bone_piece("tibia", (0.12 * s, 0.02, 0.47), (0.12 * s, 0, 0.08), 0.02):
            parts.append((p, "shin." + side))
        parts.append((ell("kneecap", (0.12 * s, 0.05, 0.48), (0.028, 0.015, 0.03), BONE), "shin." + side))
        foot = blob_mesh("foot", [("c", (0.12 * s, 0.0, 0.05), (0.12 * s, 0.14, 0.03), 0.035, 0.025)],
                         lambda co, n: BONE, voxel=0.008, smooth=3, faces=800)
        parts.append((foot, "foot." + side))
        for dx in (-0.02, 0.0, 0.02):
            parts.append((tube("toe", [Vector(((0.12 + dx) * s, 0.14, 0.03)), Vector(((0.12 + dx * 1.3) * s, 0.19, 0.02))],
                               0.009, BONE), "foot." + side))
    if warrior:
        helm = blob_mesh("helmet", [("e", (0, -0.01, 1.71), (0.185, 0.185, 0.13)),
                                    ("c", (0, -0.01, 1.645), (0, -0.01, 1.655), 0.19, 0.19)],
                         lambda co, n: RUST if co[2] < 1.67 else STEEL, voxel=0.008, smooth=4,
                         spikes=[((0.15 * s, 0.0, 1.72), (0.3 * s, 0.02, 1.9), 0.07, 0.06) for s in (1, -1)],
                         faces=2500)
        paint(helm, lambda co, n: WHITE if abs(co[0]) > 0.17 and co[2] > 1.7 else (RUST if co[2] < 1.67 else STEEL))
        parts.append((helm, "head"))
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.24, radius2=0.2, depth=0.04,
                              matrix=Matrix.Translation((-0.44, 0.08, 0.95)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
        shield = bp_obj("shield", bm)
        smooth_shade(shield)
        paint(shield, lambda co, n: RUST if math.hypot(co[1] - 0.08, co[2] - 0.95) > 0.2 else WOOD)
        parts.append((shield, "forearm.L"))
        parts.append((ell("boss", (-0.475, 0.08, 0.95), (0.02, 0.06, 0.06), STEEL), "forearm.L"))
        parts.append((tube("grip", [Vector((0.385, 0.02, 0.72)), Vector((0.385, 0.12, 0.72))], 0.015, LEATHER), "hand.R"))
        parts.append((tube("guard", [Vector((0.33, 0.13, 0.72)), Vector((0.44, 0.13, 0.72))], 0.015, RUST), "hand.R"))
        b = ell("blade", (0.39, 0.46, 0.73), (0.012, 0.32, 0.035), STEEL)
        parts.append((b, "hand.R"))
        parts.append((ell("chip", (0.39, 0.6, 0.76), (0.014, 0.03, 0.012), RUST), "hand.R"))
        for x, h in ((-0.04, 0.16), (0.04, 0.13)):
            cloth = ell("loincloth", (x, 0.07, 0.86 - h), (0.045, 0.012, h), srgb(0.45, 0.2, 0.2), segs=(10, 6))
            parts.append((cloth, "pelvis"))
        parts.append((tube("rope", [Vector((0.1 * math.cos(a), 0.065 * math.sin(a), 0.88)) for a in
                                    [math.tau * k / 16 for k in range(17)]], 0.012, LEATHER), "pelvis"))
    rig = make_rig(name, SKELETON_BONES)

    def idle(t):
        b = wave(t)
        return {"root": dict(loc=(0, 0, 0.006 * wave(t, 2))), "spine": dict(rot=[(Y, 0.05 * b)]),
                "head": dict(rot=[(Z, 0.15 * wave(t, 1, 1.2)), (Y, -0.08 * b)]),
                "jaw": dict(rot=[(X, 0.2 * max(0, wave(t, 4)))]),
                "upper_arm.R": dict(rot=[(X, 0.1 * b)]), "upper_arm.L": dict(rot=[(X, -0.1 * b)])}

    def walk(t):
        s = wave(t)
        return {"root": dict(loc=(0, 0, 0.025 * abs(wave(t, 1, 0.3)))),
                "pelvis": dict(rot=[(Z, 0.1 * s)]), "chest": dict(rot=[(Z, -0.15 * s)]),
                "thigh.R": dict(rot=[(X, 0.45 * s)]), "thigh.L": dict(rot=[(X, -0.45 * s)]),
                "shin.R": dict(rot=[(X, -0.5 * max(0, -wave(t, 1, 0.8)))]),
                "shin.L": dict(rot=[(X, -0.5 * max(0, wave(t, 1, 0.8)))]),
                "upper_arm.R": dict(rot=[(X, -0.4 * s)]), "upper_arm.L": dict(rot=[(X, 0.4 * s)]),
                "jaw": dict(rot=[(X, 0.12 * abs(s))])}

    def attack(t):
        raise_ = keys(t, [(0, 0.0), (0.3, 2.2), (0.48, -0.3), (0.7, -0.2), (1, 0.0)])
        twist = keys(t, [(0, 0.0), (0.3, 0.35), (0.48, -0.35), (1, 0.0)])
        return {"upper_arm.R": dict(rot=[(X, raise_), (Y, -0.4 * max(0, raise_) / 2.2)]),
                "forearm.R": dict(rot=[(X, 0.4 * max(0, raise_) / 2.2)]),
                "chest": dict(rot=[(Z, twist)]), "jaw": dict(rot=[(X, keys(t, [(0, 0), (0.45, 0.45), (1, 0)]))]),
                "upper_arm.L": dict(rot=[(X, 0.5 * keys(t, [(0, 0), (0.4, 1), (1, 0)])), (Y, 0.3)]),
                "thigh.R": dict(rot=[(X, 0.35 * keys(t, [(0, 0), (0.45, 1), (1, 0)]))]),
                "root": dict(loc=(0, 0.2 * keys(t, [(0, 0), (0.48, 1), (1, 0)]), 0))}

    finish(name, rig, parts, glow, [("idle", 48, idle), ("walk", 24, walk), ("attack", 24, attack)])


# --------------------------------------------------------------------------
# Nightmare bat: round fuzzy body-head with huge wings, hovering at head height.
# --------------------------------------------------------------------------

BAT_Z = 1.45
S_, E_, W_ = (0.15, -0.02, BAT_Z + 0.05), (0.45, -0.05, BAT_Z + 0.22), (0.74, -0.02, BAT_Z + 0.12)
TIPS = [(0.98, -0.02, BAT_Z + 0.34), (1.05, -0.02, BAT_Z - 0.05), (0.82, -0.02, BAT_Z - 0.3)]

BAT_BONES = [
    ("body", None, (0, 0, BAT_Z - 0.18), (0, 0, BAT_Z + 0.18)),
    ("ear.{s}", "body", (0.1, -0.02, BAT_Z + 0.14), (0.24, -0.06, BAT_Z + 0.46)),
    ("wing_1.{s}", "body", S_, E_),
    ("wing_2.{s}", "wing_1.{s}", E_, W_),
    ("finger_1.{s}", "wing_2.{s}", W_, TIPS[0]),
    ("finger_2.{s}", "wing_2.{s}", W_, TIPS[1]),
    ("finger_3.{s}", "wing_2.{s}", W_, TIPS[2]),
    ("leg.{s}", "body", (0.07, -0.02, BAT_Z - 0.16), (0.08, -0.03, BAT_Z - 0.32)),
]


def wing_membrane(s, color_in, color_out):
    """Scalloped membrane between the wing bones, as a thin solid sheet."""
    def P(p):
        return Vector((p[0] * s, p[1], p[2]))
    base = P((0.12, -0.02, BAT_Z - 0.1))
    outline = [base, P(S_), P(E_), P(W_), P(TIPS[0])]
    for a, b in ((TIPS[0], TIPS[1]), (TIPS[1], TIPS[2]), (TIPS[2], (0.12, -0.02, BAT_Z - 0.1))):
        mid = (Vector(a) + Vector(b)) / 2
        inset = mid + (Vector(W_) - mid) * 0.28
        outline += [P(tuple(inset))]
        if b != (0.12, -0.02, BAT_Z - 0.1):
            outline.append(P(b))
    centre = sum(outline, Vector()) / len(outline)
    bm = bmesh.new()
    c = bm.verts.new(centre)
    vs = [bm.verts.new(p) for p in outline]
    for i in range(len(vs)):
        bm.faces.new((c, vs[i], vs[(i + 1) % len(vs)]))
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=3, use_grid_fill=True)
    obj = bp_obj("membrane", bm)
    sol = obj.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.012
    sol.offset = 0
    apply_modifiers(obj)
    smooth_shade(obj)
    paint(obj, lambda co, n: color_out if n.y < 0 else color_in)
    return obj


def nightmare_bat():
    name = "nightmare_bat"
    reset_scene()
    fur, fur_dark = srgb(0.36, 0.22, 0.5), srgb(0.2, 0.12, 0.3)
    rng = random.Random(4)
    tufts = []
    for _ in range(26):
        a, b = rng.uniform(0, math.tau), rng.uniform(-0.9, 0.5)
        d = Vector((math.cos(a) * math.cos(b), math.sin(a) * math.cos(b) * 0.9 - 0.2, math.sin(b)))
        if d.y > 0.35 and d.z > -0.5:
            continue  # keep the face clear
        base = Vector((0, 0, BAT_Z)) + d * 0.2
        tufts.append((tuple(base), tuple(base + d * 0.09 + Vector((0, -0.03, 0))), 0.06, 0.035))
    shapes = [("e", (0, 0, BAT_Z), (0.22, 0.2, 0.21)), ("e", (0, 0.06, BAT_Z - 0.06), (0.15, 0.12, 0.1))]
    for s in (1, -1):
        shapes.append(("c", (0.07 * s, -0.02, BAT_Z - 0.14), (0.08 * s, -0.03, BAT_Z - 0.3), 0.025, 0.018))
        tufts.append(((0.1 * s, -0.02, BAT_Z + 0.12), (0.26 * s, -0.07, BAT_Z + 0.48), 0.2, 0.05))
        for dx in (-0.015, 0.015):
            tufts.append(((0.08 * s + dx, -0.03, BAT_Z - 0.3), (0.08 * s + dx * 2, 0.0, BAT_Z - 0.36), 0.015, 0.012))

    def color(co, n):
        x, y, z = co
        if z > BAT_Z + 0.15 and abs(x) > 0.1 and n.y > 0.3 and z < BAT_Z + 0.4:
            return srgb(0.85, 0.45, 0.6)  # inner ear
        if z < BAT_Z - 0.28:
            return BLACK  # claws
        if y > 0.1 and z < BAT_Z - 0.02:
            return srgb(0.55, 0.38, 0.65)  # muzzle
        return fur if n.z > -0.2 else fur_dark
    body = blob_mesh("bat", shapes, color, voxel=0.008, smooth=6, spikes=tufts, faces=7000)
    parts = [(body, {"body", "ear.R", "ear.L", "leg.R", "leg.L"})]
    glow = []
    for s in (1, -1):
        p = face_point(0.075 * s, BAT_Z + 0.04)
        glow.append((ell("eye", p + Vector((0, -0.01, 0)), (0.05, 0.03, 0.045), srgb(1.0, 0.2, 0.15),
                         rot=Matrix.Rotation(0.35 * s, 4, "Y")), "body"))
        parts.append((ell("pupil", p + Vector((0, 0.012, 0)), (0.01, 0.015, 0.035), BLACK), "body"))
        brow = [face_point(x * s, BAT_Z + 0.1 - 0.35 * (x - 0.03), 0.015) for x in (0.03, 0.08, 0.13)]
        parts.append((tube("brow", brow, 0.014, BLACK), "body"))
    mouth = [face_point(x, BAT_Z - 0.06 + 3.0 * x * x, 0.004) for x in [k / 8 * 0.1 for k in range(-8, 9)]]
    parts.append((tube("mouth", mouth, 0.009, BLACK), "body"))
    bm = bmesh.new()
    for x in (-0.06, -0.025, 0.025, 0.06):
        p = face_point(x, BAT_Z - 0.06 + 3.0 * x * x, -0.004)
        add_ear(bm, p, p + Vector((0, 0.008, -0.04 if abs(x) > 0.04 else -0.028)), 0.024, 0.014)
    fangs = bp_obj("fangs", bm)
    smooth_shade(fangs)
    paint(fangs, lambda co, n: WHITE)
    parts.append((fangs, "body"))
    for s, side in ((1, "R"), (-1, "L")):
        wing_bones = {f"wing_1.{side}", f"wing_2.{side}", f"finger_1.{side}", f"finger_2.{side}", f"finger_3.{side}"}
        parts.append((wing_membrane(s, srgb(0.5, 0.2, 0.45), srgb(0.28, 0.14, 0.32)), wing_bones))

        def P(p):
            return Vector((p[0] * s, p[1] + 0.005, p[2]))
        parts.append((tube("arm", [P(S_), P(E_), P(W_)], 0.022, fur_dark), wing_bones))
        for tip in TIPS:
            parts.append((tube("finger", [P(W_), P(tip)], 0.012, fur_dark), wing_bones))
        spike = spikes_mesh("claw", [(tuple(P(E_)), tuple(P(E_) + Vector((0.02 * s, 0, 0.09))), 0.04, 0.03)], BLACK)
        parts.append((spike, f"wing_1.{side}"))
    rig = make_rig(name, BAT_BONES)

    def hover(t, speed=2):
        f = wave(t, speed)
        return {"root": dict(loc=(0, 0, 0.06 * wave(t, speed, 1.2))),
                "wing_1.R": dict(rot=[(Y, 0.7 * f)]), "wing_1.L": dict(rot=[(Y, -0.7 * f)]),
                "wing_2.R": dict(rot=[(Y, 0.35 * wave(t, speed, -0.8))]),
                "wing_2.L": dict(rot=[(Y, -0.35 * wave(t, speed, -0.8))]),
                "ear.R": dict(rot=[(Y, 0.1 * wave(t, speed, 2))]), "ear.L": dict(rot=[(Y, -0.1 * wave(t, speed, 2))]),
                "leg.R": dict(rot=[(X, 0.25 * wave(t, 1))]), "leg.L": dict(rot=[(X, 0.25 * wave(t, 1, 0.5))]),
                "body": dict(rot=[(X, 0.05 * f)])}

    def attack(t):
        pose = hover(t, 3)
        dive = keys(t, [(0, 0), (0.25, -0.3), (0.5, 1.0), (0.75, 0.6), (1, 0)])
        pose["root"] = dict(loc=(0, 0.6 * max(0, dive), -0.25 * max(0, dive) + 0.1 * min(0, dive)))
        pose["body"] = dict(rot=[(X, 0.6 * dive)])
        sweep = 0.9 * max(0, dive)
        pose["wing_1.R"] = dict(rot=[(Z, sweep), (Y, 0.4 * wave(t, 3))])
        pose["wing_1.L"] = dict(rot=[(Z, -sweep), (Y, -0.4 * wave(t, 3))])
        return pose

    finish(name, rig, parts, glow, [("idle", 24, hover), ("attack", 24, attack)])


# --------------------------------------------------------------------------
# Shadow entity: a floating wraith of living shadow with glowing eyes and grin.
# --------------------------------------------------------------------------

SHADOW_BONES = [
    ("body", None, (0, -0.02, 0.9), (0, 0, 1.3)),
    ("chest", "body", (0, 0, 1.3), (0, 0, 1.48)),
    ("head", "chest", (0, 0, 1.48), (0, 0.02, 1.92)),
    ("tail_1", "body", (0, -0.02, 0.9), (0, -0.1, 0.62)),
    ("tail_2", "tail_1", (0, -0.1, 0.62), (0.04, -0.22, 0.4)),
    ("tail_3", "tail_2", (0.04, -0.22, 0.4), (0.12, -0.3, 0.24)),
    ("upper_arm.{s}", "chest", (0.24, 0, 1.4), (0.42, 0.08, 1.12)),
    ("forearm.{s}", "upper_arm.{s}", (0.42, 0.08, 1.12), (0.5, 0.2, 0.9)),
    ("hand.{s}", "forearm.{s}", (0.5, 0.2, 0.9), (0.54, 0.28, 0.74)),
]


def shadow_entity():
    name = "shadow_entity"
    reset_scene()
    dark, rim, deep = srgb(0.1, 0.07, 0.16), srgb(0.26, 0.16, 0.4), srgb(0.04, 0.03, 0.07)
    shapes = [("e", (0, 0.0, 1.66), (0.2, 0.2, 0.22)), ("e", (0, -0.02, 1.38), (0.3, 0.18, 0.17)),
              ("c", (0, -0.02, 1.32), (0, -0.04, 0.85), 0.24, 0.15),
              ("c", (0, -0.04, 0.85), (0, -0.1, 0.62), 0.15, 0.1), ("c", (0, -0.1, 0.62), (0.04, -0.22, 0.4), 0.1, 0.05),
              ("c", (0.04, -0.22, 0.4), (0.12, -0.3, 0.24), 0.05, 0.015)]
    for s in (1, -1):
        shapes += [("c", (0.24 * s, 0, 1.4), (0.42 * s, 0.08, 1.12), 0.055, 0.042),
                   ("c", (0.42 * s, 0.08, 1.12), (0.5 * s, 0.2, 0.9), 0.042, 0.032),
                   ("e", (0.51 * s, 0.22, 0.87), (0.04, 0.035, 0.045))]
    rng = random.Random(8)
    spikes = [((0, -0.08, 1.8), (0, -0.3, 2.02), 0.2, 0.1)]  # hood point
    for _ in range(22):
        z = rng.uniform(0.6, 1.75)
        a = rng.uniform(math.pi * 0.55, math.pi * 2.45)
        r = 0.2 if z > 1.5 else (0.26 if z > 1.2 else 0.12 + 0.12 * (z - 0.6) / 0.6)
        d = Vector((math.cos(a), math.sin(a) * 0.8, 0))
        if d.y > 0.55 and z > 1.45:
            continue  # keep the face open
        base = Vector((0, -0.02, z)) + d * r * 0.85
        tip = base + d * rng.uniform(0.08, 0.16) + Vector((0, -0.05, rng.uniform(-0.1, 0.04)))
        spikes.append((tuple(base), tuple(tip), 0.08, 0.04))
    for s in (1, -1):
        for dy, dz in ((0.03, 0.0), (0.0, -0.01), (-0.03, 0.0)):
            spikes.append(((0.52 * s, 0.22 + dy, 0.84), (0.57 * s, 0.3 + dy, 0.66 + dz), 0.03, 0.02))

    def color(co, n):
        if co[2] < 0.5:
            return deep
        return rim if n.z > 0.45 else dark
    body = blob_mesh("shadow", shapes, color, voxel=0.01, smooth=6, spikes=spikes, faces=8000)
    parts = [(body, None)]
    glow = []
    for s in (1, -1):
        p = face_point(0.075 * s, 1.68)
        glow.append((ell("eye", p + Vector((0, -0.005, 0)), (0.055, 0.02, 0.028), srgb(1.0, 0.92, 0.45),
                         rot=Matrix.Rotation(-0.35 * s, 4, "Y")), "head"))
    grin = []
    for k in range(9):
        x = -0.1 + k * 0.025
        z = 1.56 + 1.8 * x * x + (0.018 if k % 2 else -0.004)
        grin.append(face_point(x, z, 0.004))
    glow.append((tube("grin", grin, 0.009, srgb(0.95, 0.3, 0.95)), "head"))
    rig = make_rig(name, SHADOW_BONES)

    def idle(t):
        b = wave(t)
        return {"root": dict(loc=(0, 0, 0.07 * b)),
                "tail_1": dict(rot=[(Y, 0.15 * wave(t, 1, 0.8))]), "tail_2": dict(rot=[(Y, 0.25 * wave(t, 1, 1.6))]),
                "tail_3": dict(rot=[(Y, 0.35 * wave(t, 1, 2.4))]),
                "head": dict(rot=[(Y, 0.1 * wave(t, 1, 1)), (X, 0.05 * b)]),
                "upper_arm.R": dict(rot=[(X, 0.15 * wave(t, 1, 0.5))]),
                "upper_arm.L": dict(rot=[(X, 0.15 * wave(t, 1, 2.0))]),
                "forearm.R": dict(rot=[(X, 0.2 * wave(t, 1, 1.2))]), "forearm.L": dict(rot=[(X, 0.2 * wave(t, 1, 2.6))])}

    def attack(t):
        pose = idle(t)
        reach = keys(t, [(0, 0.0), (0.3, 1.0), (0.5, -0.4), (0.75, -0.2), (1, 0.0)])
        pose["root"] = dict(loc=(0, 0.35 * max(0, -reach) + 0.1 * max(0, reach), 0.05 * reach))
        pose["body"] = dict(rot=[(X, 0.25 * max(0, -reach) - 0.1 * max(0, reach))])
        for side in ("R", "L"):
            pose["upper_arm." + side] = dict(rot=[(X, 1.8 * max(0, reach) + 0.6 * min(0, reach) + 0.9 * max(0, -reach))])
            pose["forearm." + side] = dict(rot=[(X, 0.4 * max(0, reach))])
        pose["head"] = dict(rot=[(X, -0.2 * reach)])
        return pose

    finish(name, rig, parts, glow, [("idle", 48, idle), ("attack", 24, attack)])


MONSTERS = {
    "goblin": lambda: goblin("goblin"),
    "goblin_cave": lambda: goblin("goblin_cave"),
    "skeleton": lambda: skeleton("skeleton", False),
    "skeleton_warrior": lambda: skeleton("skeleton_warrior", True),
    "nightmare_bat": nightmare_bat,
    "shadow_entity": shadow_entity,
}

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if a in MONSTERS]
    for name, fn in MONSTERS.items():
        if only and name not in only:
            continue
        fn()
