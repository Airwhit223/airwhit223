"""Customizable beastfolk, plus two Egyptian-themed beastfolk NPCs.

Run with Blender 5.x:
    blender --background --python characters/build_beastfolk.py [male] [female] [npcs]
or with the bpy pip module (Python 3.13):
    python characters/build_beastfolk.py [male] [female] [npcs]

beastfolk_male.glb / beastfolk_female.glb hold every part as its own mesh on
one humanoid skeleton: human head, hair, species ears, animal heads (cat,
wolf, fox, bear, shark), tails, clothes. Tinted parts store a grayscale
"marking mask" in their vertex colors; beastfolk/beastfolk_toon.gdshader turns
that into fur / skin / cloth colors, and beastfolk/beastfolk.gd picks the
species, form (hybrid or beast) and colors in Godot.

npc_shark.glb and npc_wolf_egypt.glb are finished NPCs with baked colors.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from base_character import (  # noqa: E402
    DARK, WHITE, WRIST_T, Landmarks, Matrix, Vector, add_capsule, add_ellipsoid, anime_eyes, apply_modifiers,
    arm_band, auto_weight, blob, bmesh, bpy, build_rig, copy_weights, face_point, garment, hide_covered, join,
    load_base, make_material, new_object, paint, remesh_and_smooth, replace_hands, reset_scene, ring_skirt,
    select_only, set_weights, skirt_weights, srgb, tube,
)
from build_pets import add_ear  # noqa: E402

OUT = HERE
BASES = {
    "male": (os.path.join(HERE, "..", "bases", "male_base_meshy.glb"), 1.8),
    "female": (os.path.join(HERE, "..", "bases", "female_base_meshy.glb"), 1.7),
}
# Tinted parts store masks in their vertex colors: red = markings (secondary
# color: muzzles, bellies, inner ears), green = spots (tertiary color).
MASK0 = (0.0, 0.0, 0.0, 1.0)   # primary color
MASK1 = (1.0, 0.0, 0.0, 1.0)   # secondary color (markings)
HEAD_SPECIES = ("cat", "wolf", "fox", "bear", "shark", "lizard", "octopus", "manta", "eel")
EAR_SPECIES = ("cat", "wolf", "fox", "bear", "fish", "coral")
TAIL_SPECIES = ("cat", "wolf", "fox", "bear", "shark", "lizard", "eel")
SPECIES = HEAD_SPECIES


def mask(m, spot=0.0):
    return (m, spot, 0.0, 1.0)


def spots(co, scale=38.0, amount=0.35):
    """1 on scattered round spots, 0 elsewhere."""
    v = (math.sin(co[0] * scale + 1.3) * math.sin(co[1] * scale * 1.27 + 0.4)
         * math.sin(co[2] * scale * 0.93 + 2.1))
    return 1.0 if v > amount else 0.0


# --------------------------------------------------------------------------
# Head-space sculpting: positions are in units of the head size, origin at
# the head center, +Y forward, +Z up.
# --------------------------------------------------------------------------

class HeadSpace:
    def __init__(self, L):
        self.c = L.head_center + Vector((0, -L.head_radius.y * 0.15, 0))
        self.s = (L.head_radius.x + L.head_radius.z) / 2

    def p(self, x, y, z):
        return self.c + Vector((x, y, z)) * self.s

    def local(self, co):
        return (Vector(co) - self.c) / self.s


def sculpt(name, H, blobs, cones=(), voxel=0.006, smooth=6, faces=2200):
    """blobs: ("e", center, radii) ellipsoids or ("c", a, b, ra, rb) capsules;
    cones: (base, tip, width, thickness) added after smoothing so they stay sharp."""
    bm = bmesh.new()
    for b in blobs:
        if b[0] == "e":
            add_ellipsoid(bm, H.p(*b[1]), [r * H.s for r in b[2]])
        else:
            add_capsule(bm, H.p(*b[1]), H.p(*b[2]), b[3] * H.s, b[4] * H.s)
    obj = new_object(name, bm)
    remesh_and_smooth(obj, voxel=voxel, smooth_repeat=smooth)
    if cones:
        bm = bmesh.new()
        for base, tip, w, t in cones:
            add_ear(bm, H.p(*base), H.p(*tip), w * H.s, t * H.s)
        c = new_object(name + "_cones", bm)
        join([c], obj)
        remesh_and_smooth(obj, voxel=voxel * 0.8, smooth_repeat=1)
    if len(obj.data.polygons) > faces:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = faces / len(obj.data.polygons)
        apply_modifiers(obj)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    return obj


def limit(obj, faces):
    """Caps a part's polygon count."""
    if len(obj.data.polygons) > faces:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = faces / len(obj.data.polygons)
        apply_modifiers(obj)
        select_only(obj)
        bpy.ops.object.shade_smooth()
    return obj


def mirror(x, *rest):
    return [(x, *rest), (-x, *rest)]


def ear_cones(base, tip, w, t):
    return [((base[0] * s, base[1], base[2]), (tip[0] * s, tip[1], tip[2]), w, t) for s in (1, -1)]


def inner_ear(lc, base, tip, width):
    """True on the forward-facing middle of a cone ear (head units)."""
    t = (lc.z - base[2]) / (tip[2] - base[2])
    if t < 0.08 or t > 0.85:
        return False
    cx = base[0] + (tip[0] - base[0]) * t
    cy = base[1] + (tip[1] - base[1]) * t
    return abs(abs(lc.x) - cx) < width * 0.28 * (1 - t) and lc.y > cy


# Neck shared by every head: a slim column tucked under the skull, so the profile runs in one
# smooth curve from the back of the head down to the collar instead of a second bump.
NECK = [("c", (0, 0.1, -0.3), (0, 0.35, -1.0), 0.58, 0.52),
        ("c", (0, -0.3, 0.05), (0, 0.1, -0.95), 0.5, 0.48),  # nape: skull back slopes into the neck
        ("e", (0, 0.35, -1.05), (0.62, 0.52, 0.35))]


HEADS = {
    # blobs, cones, mask(local, normal) -> 0..1, eye (x, y, z), nose (x, y, z, size), ears for inner mask
    "wolf": dict(
        blobs=[("e", (0, 0.07, 0.12), (0.95, 0.86, 0.9)),
               *[("e", c, (0.5, 0.45, 0.45)) for c in mirror(0.55, 0.25, -0.35)],
               ("c", (0, 0.45, -0.18), (0, 1.45, -0.34), 0.42, 0.25),
               ("e", (0, 0.85, -0.55), (0.3, 0.55, 0.17)),
               *NECK],
        cones=ear_cones((0.45, -0.15, 0.72), (0.62, -0.25, 1.62), 0.62, 0.26)
        + [((0.7, 0.05, -0.45), (1.12, -0.1, -0.7), 0.42, 0.3), ((-0.7, 0.05, -0.45), (-1.12, -0.1, -0.7), 0.42, 0.3)],
        ear=((0.45, -0.15, 0.72), (0.62, -0.25, 1.62), 0.62),
        light=lambda lc, n: lc.z < -0.32 and lc.y > 0.15 or (lc.y > 0.6 and n.z < -0.3),
        eye=(0.36, 0.62, 0.22), nose=(0, 1.52, -0.26, 0.15), iris=srgb(0.95, 0.66, 0.2)),
    "fox": dict(
        blobs=[("e", (0, 0.07, 0.1), (0.9, 0.82, 0.85)),
               *[("e", c, (0.55, 0.45, 0.45)) for c in mirror(0.55, 0.2, -0.35)],
               ("c", (0, 0.45, -0.2), (0, 1.5, -0.36), 0.36, 0.18),
               *NECK],
        cones=ear_cones((0.42, -0.1, 0.65), (0.68, -0.2, 1.95), 0.8, 0.26)
        + [((0.7, 0.1, -0.4), (1.2, -0.05, -0.62), 0.45, 0.3), ((-0.7, 0.1, -0.4), (-1.2, -0.05, -0.62), 0.45, 0.3)],
        ear=((0.42, -0.1, 0.65), (0.68, -0.2, 1.95), 0.8),
        light=lambda lc, n: (lc.z < -0.2 and lc.y > -0.2) or (abs(lc.x) > 0.6 and lc.z < -0.25),
        eye=(0.34, 0.6, 0.2), nose=(0, 1.6, -0.3, 0.12), iris=srgb(0.96, 0.62, 0.18)),
    "cat": dict(
        blobs=[("e", (0, 0.07, 0.08), (1.0, 0.82, 0.95)),
               *[("e", c, (0.3, 0.28, 0.25)) for c in mirror(0.2, 0.78, -0.33)],
               ("e", (0, 0.72, -0.5), (0.22, 0.2, 0.15)),
               *[("e", c, (0.45, 0.4, 0.4)) for c in mirror(0.6, 0.15, -0.35)],
               *NECK],
        cones=ear_cones((0.48, -0.05, 0.68), (0.66, -0.1, 1.45), 0.78, 0.26),
        ear=((0.48, -0.05, 0.68), (0.66, -0.1, 1.45), 0.78),
        light=lambda lc, n: lc.z < -0.2 and lc.y > 0.4,
        eye=(0.38, 0.72, 0.18), nose=(0, 0.98, -0.2, 0.09), iris=srgb(0.45, 0.8, 0.35)),
    "bear": dict(
        blobs=[("e", (0, 0.07, 0.05), (1.08, 0.86, 1.0)),
               *[("e", c, (0.32, 0.22, 0.32)) for c in mirror(0.68, -0.1, 0.82)],
               ("c", (0, 0.45, -0.3), (0, 1.15, -0.35), 0.44, 0.36),
               *[("e", c, (0.5, 0.45, 0.5)) for c in mirror(0.55, 0.2, -0.3)],
               *NECK],
        cones=[],
        ear=None,
        light=lambda lc, n: lc.y > 0.75 and lc.z < 0.0,
        eye=(0.4, 0.72, 0.2), nose=(0, 1.5, -0.2, 0.2), iris=srgb(0.3, 0.2, 0.12)),
    "lizard": dict(
        blobs=[("e", (0, 0.07, 0.05), (0.85, 0.82, 0.8)),
               ("c", (0, 0.45, -0.2), (0, 1.35, -0.3), 0.5, 0.3),
               ("e", (0, 0.8, -0.52), (0.42, 0.6, 0.16)),
               *[("e", c, (0.26, 0.3, 0.13)) for c in mirror(0.36, 0.55, 0.33)],
               *NECK],
        cones=ear_cones((0.35, -0.35, 0.5), (0.52, -1.15, 0.95), 0.32, 0.26)
        + [((0, y, 0.72), (0, y - 0.35, 1.25), 0.32, 0.18) for y in (0.25, -0.15, -0.55)],
        ear=None, spots=36.0,
        light=lambda lc, n: lc.z < -0.4 and lc.y > -0.3,
        eye=(0.42, 0.55, 0.22), nose=None, iris=srgb(0.95, 0.72, 0.2)),
    "octopus": dict(
        blobs=[("e", (0, -0.12, 0.55), (1.0, 1.0, 1.1)),
               ("e", (0, 0.3, -0.2), (0.85, 0.8, 0.78)),
               *NECK],
        cones=[], ear=None, spots=30.0,
        light=lambda lc, n: False,
        eye=(0.36, 0.8, 0.0), nose=None, iris=srgb(0.3, 0.2, 0.4)),
    "manta": dict(
        blobs=[("e", (0, 0.12, 0.0), (0.95, 0.86, 0.72)),
               ("e", (0, 0.55, -0.25), (0.75, 0.6, 0.45)),
               *NECK],
        cones=[((0.5, 0.35, 0.25), (1.75, 0.1, 0.75), 0.95, 0.22), ((-0.5, 0.35, 0.25), (-1.75, 0.1, 0.75), 0.95, 0.22)],
        ear=None,
        light=lambda lc, n: n.z < -0.3,
        eye=(0.38, 0.72, 0.15), nose=None, iris=srgb(0.4, 0.6, 0.7)),
    "eel": dict(
        blobs=[("e", (0, 0.12, 0.05), (0.8, 0.9, 0.85)),
               ("c", (0, 0.55, -0.2), (0, 1.15, -0.3), 0.45, 0.3),
               *NECK],
        cones=[((0.7, -0.1, 0.1), (1.35, -0.45, 0.55), 0.55, 0.12), ((-0.7, -0.1, 0.1), (-1.35, -0.45, 0.55), 0.55, 0.12)],
        ear=None, spots=24.0,
        light=lambda lc, n: lc.z < -0.4 and lc.y > 0.0,
        eye=(0.38, 0.72, 0.18), nose=None, iris=srgb(0.3, 0.95, 0.85)),
    "shark": dict(
        blobs=[("e", (0, 0.17, 0.0), (0.92, 0.99, 0.95)),
               ("c", (0, 0.55, -0.05), (0, 1.55, -0.2), 0.78, 0.36),
               *NECK],
        cones=[],
        ear=None,
        light=lambda lc, n: lc.z < -0.3 or (lc.y > 0.4 and n.z < -0.2),
        eye=(0.55, 0.75, 0.15), nose=None, iris=srgb(0.9, 0.15, 0.12)),
}


def surface_hit(obj, origin, direction):
    """First hit on obj alone (world space) -> (location, normal), or (None, None)."""
    inv = obj.matrix_world.inverted()
    d = (inv.to_3x3() @ Vector(direction)).normalized()
    hit, loc, nrm, _ = obj.ray_cast(inv @ Vector(origin), d)
    if not hit:
        return None, None
    return obj.matrix_world @ loc, (obj.matrix_world.to_3x3() @ nrm).normalized()


def eye_frame(nrm, side):
    """Rotation whose +Y faces out of the head (biased forward so eyes look ahead), +Z up."""
    fwd = (nrm + Vector((0, 1.2, 0))).normalized()
    right = Vector((0, 0, 1)).cross(fwd).normalized()
    up = fwd.cross(right).normalized()
    return Matrix((right, fwd, up)).transposed().to_4x4()


def build_head(species, H, eye_style, iris=None):
    spec = dict(HEADS[species])
    if iris:
        spec["iris"] = iris
    head = sculpt("head_" + species, H, spec["blobs"], spec["cones"])

    def m(co, n):
        lc = H.local(co)
        spot = spots(co, spec["spots"]) if spec.get("spots") else 0.0
        if spec["ear"] and lc.z > 0.6 and inner_ear(lc, *spec["ear"]):
            return mask(1.0, spot)
        return mask(1.0 if spec["light"](lc, n) else 0.0, spot)
    paint(head, m)

    face = []
    ex, ey, ez = spec["eye"]
    k = H.s
    for s in (1, -1):
        # Aim at this head only (the other species' heads share the same spot), from outside
        # the eye position toward a point inside the skull, so the eye sits on the surface.
        target = H.p(ex * s * 0.3, ey - 0.8, ez)
        outside = H.p(ex * s, ey, ez) + (H.p(ex * s, ey, ez) - target).normalized() * 3 * k
        p, nrm = surface_hit(head, outside, target - outside)
        if p is None:
            p, nrm = H.p(ex * s, ey, ez), Vector((0, 1, 0))
        R = eye_frame(nrm, s)

        def put(name, off, size, color, tilt=None):
            rot = R if tilt is None else R @ tilt
            face.append(blob(name, p + R.to_3x3() @ Vector(off), size, color, rot=rot))
        if species == "shark":
            put("eye", (0, -0.02 * k, 0), (0.11 * k, 0.06 * k, 0.1 * k), spec["iris"])
            put("pupil", (0, 0.0, 0), (0.05 * k, 0.05 * k, 0.07 * k), DARK)
            put("brow", (-0.02 * s * k, -0.01 * k, 0.12 * k), (0.15 * k, 0.04 * k, 0.03 * k), DARK,
                Matrix.Rotation(0.35 * s, 4, "Y"))
            continue
        # Flattened discs set into the surface: only a sliver stands proud, so they read as
        # painted anime eyes and never float in profile.
        put("sclera", (0, -0.022 * k, 0), (0.26 * k, 0.06 * k, 0.22 * k), WHITE)
        put("iris", (-0.025 * s * k, -0.006 * k, -0.01 * k), (0.17 * k, 0.05 * k, 0.2 * k), spec["iris"])
        put("pupil", (-0.025 * s * k, 0.004 * k, -0.01 * k), (0.08 * k, 0.045 * k, 0.13 * k), DARK)
        put("shine", (0.03 * s * k, 0.02 * k, 0.08 * k), (0.05 * k, 0.03 * k, 0.05 * k), WHITE)
        put("lash", (0, -0.01 * k, 0.21 * k), (0.29 * k, 0.05 * k, 0.045 * k), DARK,
            Matrix.Rotation(-0.15 * s, 4, "Y"))
    if spec["nose"]:
        nx, ny, nz, ns = spec["nose"]
        face.append(blob("nose", H.p(nx, ny, nz), (ns * H.s * 1.2, ns * H.s, ns * H.s * 0.8), DARK))
    if species == "shark":
        # Wide toothy grin along the snout, and gill slits.
        def snout(a, lift, z=-0.42):
            """Point on the snout surface at angle a around the jaw line, lifted off it."""
            centre = H.p(0, 0.55, z)
            out = H.p(1.6 * math.cos(a), 0.55 + 1.6 * math.sin(a), z)
            loc, nrm = surface_hit(head, out, centre - out)
            if loc is None:
                return H.p(0.62 * math.cos(a), 0.55 + 0.9 * math.sin(a) ** 2, -0.62)
            return loc + nrm * lift * H.s
        angles = [math.radians(d) for d in range(20, 161, 8)]
        face.append(tube("mouth", [snout(a, 0.0) for a in angles], 0.028 * H.s, DARK))
        bm = bmesh.new()
        for a in [math.radians(d) for d in range(30, 151, 12)]:
            base = snout(a, 0.02)
            add_ear(bm, base + Vector((0, 0, 0.004)), base + Vector((0, 0, 0.1 * H.s)), 0.08 * H.s, 0.04 * H.s)
            add_ear(bm, base - Vector((0, 0, 0.004)), base - Vector((0, 0, 0.1 * H.s)), 0.08 * H.s, 0.04 * H.s)
        teeth = new_object("teeth", bm)
        paint(teeth, lambda co, n: WHITE)
        face.append(teeth)
        for s in (1, -1):
            for g in range(3):
                pts = []
                for z in (-0.3, -0.45, -0.6):
                    out = H.p(s * 2.0, -0.15 - g * 0.17, z)
                    loc, nrm = surface_hit(head, out, Vector((-s, 0, 0)))
                    pts.append(loc + nrm * 0.01 * H.s if loc is not None else H.p(s * 0.95, -0.15 - g * 0.17, z))
                face.append(tube("gill", pts, 0.02 * H.s, srgb(0.2, 0.22, 0.26)))
    face_obj = face[0]
    if len(face) > 1:
        join(face[1:], face_obj)
    face_obj.name = "face_" + species
    for o in (head, face_obj):
        set_weights(o, lambda co: {"Head": 1.0})
    return head, face_obj


SKULL = [None]  # the bare human head mesh, so ears never land on another species' ears


def skull_point(H, x, y):
    """Top of the real head surface above head-space point (x, y)."""
    start = H.p(x, y, 4.0)
    if SKULL[0] is not None:
        loc, _ = surface_hit(SKULL[0], start, Vector((0, 0, -1)))
        return loc if loc is not None else H.p(x, y, 1.0)
    dep = bpy.context.evaluated_depsgraph_get()
    hit, loc, *_ = bpy.context.scene.ray_cast(dep, start, Vector((0, 0, -1)))
    return loc if hit else H.p(x, y, 1.0)


EAR_SPECS = {  # (head-space x, y) on the skull, length, width, outward lean, in head units
    "wolf": (0.55, -0.1, 0.95, 0.55, 0.25),
    "fox": (0.52, -0.05, 1.25, 0.7, 0.3),
    "cat": (0.55, 0.0, 0.8, 0.62, 0.2),
}


def side_point(H, y, z, side):
    """The real head surface at the side of the head, at head-space (y, z)."""
    if SKULL[0] is not None:
        loc, _ = surface_hit(SKULL[0], H.p(4.0 * side, y, z), Vector((-side, 0, 0)))
        return loc if loc is not None else H.p(side, y, z)
    dep = bpy.context.evaluated_depsgraph_get()
    hit, loc, *_ = bpy.context.scene.ray_cast(dep, H.p(4.0 * side, y, z), Vector((-side, 0, 0)))
    return loc if hit else H.p(side, y, z)


def add_fin(bm, base, out, up, length, height, thick):
    """A thin webbed fin: a vertical root that sweeps out to two points."""
    side = out.cross(up).normalized()
    pts2d = [(0.0, -0.5), (0.0, 0.5), (0.8, 0.75), (0.55, 0.15), (1.0, 0.1), (0.65, -0.35)]
    rings = []
    for off in (-thick / 2, thick / 2):
        rings.append([bm.verts.new(base + out * (a * length) + up * (b * height) + side * off) for a, b in pts2d])
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[1])))
    for i in range(len(pts2d)):
        j = (i + 1) % len(pts2d)
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))


def build_ears(species, H):
    """Animal ears for the hybrid (human head) form, planted on the skull."""
    if species not in EAR_SPECIES:
        return None
    if species == "fish":
        bm = bmesh.new()
        for s in (1, -1):
            base = side_point(H, -0.1, -0.05, s) - Vector((0.01 * s, 0, 0))
            add_fin(bm, base, Vector((s, -0.55, 0.2)).normalized(), Vector((0, 0.1, 1)).normalized(),
                    0.95 * H.s, 0.75 * H.s, 0.02)
        ears = new_object("ears_fish", bm)
        paint(ears, lambda co, n: MASK1 if abs(co.x - H.c.x) > H.s * 1.25 else MASK0)
        set_weights(ears, lambda co: {"Head": 1.0})
        return ears
    if species == "coral":
        bm = bmesh.new()
        for s in (1, -1):
            base = skull_point(H, 0.45 * s, -0.05) - Vector((0, 0, 0.01))
            main = base + Vector((0.35 * s, -0.05, 0.9)) * H.s
            add_capsule(bm, base, main, 0.1 * H.s, 0.06 * H.s)
            for frac, d in ((0.45, Vector((0.45 * s, 0.1, 0.35))), (0.75, Vector((-0.2 * s, -0.05, 0.4))),
                            (1.0, Vector((0.25 * s, 0.05, 0.3)))):
                a = base.lerp(main, frac)
                add_capsule(bm, a, a + d * H.s, 0.06 * H.s, 0.035 * H.s)
                add_ellipsoid(bm, a + d * H.s, (0.045 * H.s,) * 3)
        ears = new_object("ears_coral", bm)
        remesh_and_smooth(ears, voxel=0.004, smooth_repeat=2)
        limit(ears, 1200)
        select_only(ears)
        bpy.ops.object.shade_smooth()
        paint(ears, lambda co, n: MASK1 if H.local(co).z > 1.3 else MASK0)
        set_weights(ears, lambda co: {"Head": 1.0})
        return ears
    bm = bmesh.new()
    inner = []
    for s in (1, -1):
        if species == "bear":
            x, y = 0.68, -0.1
            base = skull_point(H, x * s, y)
            add_ellipsoid(bm, base + Vector((0.02 * s, 0, 0.02)), (0.3 * H.s, 0.2 * H.s, 0.3 * H.s))
            inner.append((base, None))
            continue
        x, y, length, width, lean = EAR_SPECS[species]
        base = skull_point(H, x * s, y) - Vector((0, 0, 0.015))
        up = Vector((lean * s, -0.1, 1.0)).normalized()
        tip = base + up * length * H.s
        add_ear(bm, base, tip, width * H.s, 0.24 * H.s)
        inner.append((base, tip))
    ears = new_object("ears_" + species, bm)
    remesh_and_smooth(ears, voxel=0.004, smooth_repeat=1)
    select_only(ears)
    bpy.ops.object.shade_smooth()

    def m(co, n):
        for base, tip in inner:
            if tip is None:
                if (co - base).length < 0.3 * H.s * 1.4 and n.y > 0.5:
                    return MASK1
                continue
            axis = tip - base
            t = (co - base).dot(axis) / axis.length_squared
            if 0.08 < t < 0.85 and n.y > 0.35:
                closest = base + axis * t
                if abs(co.x - closest.x) < 0.2 * H.s * (1 - t):
                    return MASK1
        return MASK0
    paint(ears, m)
    ears.name = "ears_" + species
    limit(ears, 900)
    set_weights(ears, lambda co: {"Head": 1.0})
    return ears


def back_points(L):
    """Tail root and dorsal-fin root on the body's back (call before adding tails)."""
    dep = bpy.context.evaluated_depsgraph_get()
    out = []
    for z in (L.H * 0.5, L.H * 0.68):
        hit, loc, *_ = bpy.context.scene.ray_cast(dep, Vector((0, -2, z)), Vector((0, 1, 0)))
        out.append((loc if hit else Vector((0, -0.12, z))) + Vector((0, 0.03, 0)))
    return out


def build_tail(species, L, roots):
    """Tail rooted at the base of the spine."""
    H = L.H
    root, fin_root = roots
    d = lambda *v: root + Vector(v)  # noqa: E731
    bm = bmesh.new()
    cones = []
    if species in ("wolf", "fox"):
        big = 1.25 if species == "fox" else 1.0
        pts = [d(0, 0, 0), d(0, -0.12, -0.04), d(0, -0.22, -0.2), d(0, -0.26, -0.42), d(0, -0.24, -0.6)]
        radii = [0.04, 0.07 * big, 0.09 * big, 0.085 * big, 0.03]
        for p, q, a, b in zip(pts, pts[1:], radii, radii[1:]):
            add_capsule(bm, p, q, a, b)
        tip_z = pts[-1].z + 0.22
    elif species == "cat":
        pts = [d(0, 0, 0), d(0.02, -0.12, -0.1), d(0.06, -0.2, -0.3), d(0.05, -0.2, -0.5), d(0.0, -0.3, -0.62)]
        for p, q in zip(pts, pts[1:]):
            add_capsule(bm, p, q, 0.028, 0.026)
        tip_z = pts[-1].z + 0.12
    elif species == "bear":
        add_ellipsoid(bm, d(0, -0.04, 0), (0.07, 0.07, 0.07))
        tip_z = -10
    elif species == "lizard":
        pts = [d(0, 0, 0), d(0, -0.15, -0.12), d(0, -0.32, -0.35), d(0.05, -0.5, -0.55), d(0.12, -0.72, -0.72),
               d(0.18, -0.95, -0.78)]
        radii = [0.1, 0.09, 0.075, 0.055, 0.035, 0.012]
        for p, q, a, b in zip(pts, pts[1:], radii, radii[1:]):
            add_capsule(bm, p, q, a, b)
        tip_z = -10
    elif species == "eel":
        pts = [d(0, 0, 0), d(0, -0.12, -0.15), d(0, -0.2, -0.4), d(0.06, -0.22, -0.65), d(0.1, -0.35, -0.8)]
        radii = [0.06, 0.05, 0.04, 0.03, 0.015]
        for p, q, a, b in zip(pts, pts[1:], radii, radii[1:]):
            add_capsule(bm, p, q, a, b)
        tip_z = -10
    else:  # shark: thick tail with a crescent fin
        pts = [d(0, 0, 0), d(0, -0.14, -0.1), d(0, -0.25, -0.24), d(0, -0.31, -0.38)]
        radii = [0.13, 0.11, 0.08, 0.045]
        for p, q, a, b in zip(pts, pts[1:], radii, radii[1:]):
            add_capsule(bm, p, q, a, b)
        end = pts[-1]
        cones = [(end, end + Vector((0, -0.22, 0.2)), 0.16, 0.05), (end, end + Vector((0, -0.16, -0.18)), 0.13, 0.05)]
        tip_z = -10
    tail = new_object("tail_" + species, bm)
    remesh_and_smooth(tail, voxel=0.007, smooth_repeat=5)
    if cones:
        bm = bmesh.new()
        for base, tip, w, t in cones:
            add_ear(bm, base, tip, w, t)
        c = new_object("fin", bm)
        join([c], tail)
    select_only(tail)
    bpy.ops.object.shade_smooth()
    limit(tail, 1800)
    if species == "shark":
        paint(tail, lambda co, n: MASK1 if n.z < -0.3 else MASK0)
    elif species in ("lizard", "eel"):
        paint(tail, lambda co, n: mask(1.0 if n.z < -0.5 else 0.0, spots(co, 36.0 if species == "lizard" else 24.0)))
    else:
        paint(tail, lambda co, n: MASK1 if co.z < tip_z else MASK0)
    tail.name = "tail_" + species
    set_weights(tail, lambda co: {"Hips": 1.0})
    parts = [tail]
    if species == "shark":
        # Dorsal fin between the shoulder blades.
        base = fin_root
        bm = bmesh.new()
        add_ear(bm, base, base + Vector((0, -0.2, 0.22)), 0.22, 0.05)
        fin = new_object("fin_shark", bm)
        remesh_and_smooth(fin, voxel=0.005, smooth_repeat=1)
        limit(fin, 500)
        paint(fin, lambda co, n: MASK0)
        set_weights(fin, lambda co: {"UpperChest": 1.0})
        parts.append(fin)
    return parts


def build_hair(sex, H, head):
    """Hair lifted off the human head's own surface, so it always fits,
    plus spikes (male) or a long fall of hair down the back (female)."""
    def region(co):
        lc = H.local(co)
        if lc.y > 0.3 and lc.z < 0.45:
            return False  # keep the face clear, allowing a fringe on the forehead
        return lc.z > -0.1 or (lc.y < -0.1 and lc.z > (-0.6 if sex == "male" else -0.9))
    hair = garment(head, "hair", region, lambda co: 0.018 if sex == "male" else 0.022)
    copy_weights(hair, head)
    extra = []
    dep = bpy.context.evaluated_depsgraph_get()
    if sex == "male":
        bm = bmesh.new()
        for d in [(0, 0.6, 0.8), (0.45, 0.45, 0.75), (-0.45, 0.45, 0.75), (0.25, 0.15, 1), (-0.25, 0.15, 1),
                  (0.7, -0.1, 0.7), (-0.7, -0.1, 0.7), (0, -0.25, 1), (0.4, -0.6, 0.7), (-0.4, -0.6, 0.7),
                  (0, -0.85, 0.5), (0.2, 0.55, 0.9)]:
            d = Vector(d).normalized()
            hit, loc, *_ = bpy.context.scene.ray_cast(dep, H.c + d * H.s * 4, -d)
            if not hit:
                continue
            lean = (d + Vector((0, -0.55, 0.5))).normalized()
            add_ear(bm, loc - d * 0.012, loc + lean * 0.55 * H.s, 0.5 * H.s, 0.36 * H.s)
        spikes = new_object("spikes", bm)
        set_weights(spikes, lambda co: {"Head": 1.0})
        extra.append(spikes)
    else:
        bm = bmesh.new()
        add_capsule(bm, H.p(0, -0.72, -0.3), H.p(0, -0.9, -2.7), 0.85 * H.s, 0.7 * H.s)
        for x in (0.8, -0.8):
            add_capsule(bm, H.p(x, 0.05, -0.5), H.p(x * 1.1, 0.1, -1.8), 0.28 * H.s, 0.22 * H.s)
        fall = new_object("hair_fall", bm)
        remesh_and_smooth(fall, voxel=0.008, smooth_repeat=6)
        limit(fall, 1500)
        set_weights(fall, lambda co: {"Head": 1.0} if co.z > H.c.z - H.s else {"Head": 0.4, "UpperChest": 0.6})
        extra.append(fall)
    for e in extra:
        if not e.vertex_groups:
            copy_weights(e, head)
    join(extra, hair)
    select_only(hair)
    bpy.ops.object.shade_smooth()
    paint(hair, lambda co, n: MASK1 if n.z > 0.75 else MASK0)
    hair.name = "hair"
    return hair


def attach(parts, rig):
    for obj in parts:
        if obj.type != "MESH":
            continue
        obj.parent = rig
        if not any(m.type == "ARMATURE" for m in obj.modifiers):
            mod = obj.modifiers.new("Armature", "ARMATURE")
            mod.object = rig


def shirt_and_pants(body, L):
    H = L.H

    def arm_t(co):
        return L.arm_param(co, 1 if co.x > 0 else -1)[0]

    def sleeve(co):
        t, dist = L.arm_param(co, 1 if co.x > 0 else -1)
        return (L.is_arm(co) or (abs(co.x) > H * 0.08 and dist < 0.1)) and t < 0.34

    torso = lambda co: not L.is_arm(co) and abs(co.x) < H * 0.16  # noqa: E731
    hem = H * 0.52
    cuts = [((0, 0, hem), (0, 0, 1), torso)]
    for side in (1, -1):
        at = L.arm[side]["at"]
        a, b = at(0.28), at(0.33)
        cuts.append((a, (a - b).normalized(), lambda co, side=side: co.x * side > 0 and L.is_arm(co)))
    shirt = garment(body, "shirt", lambda co: sleeve(co) or (hem - 0.03 < co.z < L.neck.z - 0.01 and torso(co)),
                    lambda co: 0.022 if co.z < hem + 0.12 and not L.is_arm(co) else 0.013, cuts=cuts)
    paint(shirt, lambda co, n: MASK0)
    legs = lambda co: not L.is_arm(co) and abs(co.x) < H * 0.2  # noqa: E731
    pants = garment(body, "pants", lambda co: 0.17 < co.z < H * 0.56 and legs(co),
                    lambda co: 0.014 + 0.008 * max(0.0, (H * 0.25 - co.z) / (H * 0.25)),
                    cuts=[((0, 0, 0.2), (0, 0, 1), None), ((0, 0, H * 0.54), (0, 0, -1), None)])
    paint(pants, lambda co, n: MASK0)
    boots = garment(body, "boots", lambda co: co.z < 0.27 and legs(co), lambda co: 0.028 + (0.006 if co.z < 0.03 else 0),
                    cuts=[((0, 0, 0.23), (0, 0, -1), None)])
    paint(boots, lambda co, n: MASK1 if co.z < 0.03 else MASK0)
    arm_top = L.arm[1]["shoulder"].z - 0.07
    neck_line = L.neck.z - 0.12
    tank = garment(body, "tank", lambda co: hem - 0.03 < co.z < L.neck.z - 0.02 and torso(co),
                   lambda co: 0.022 if co.z < hem + 0.12 else 0.012,
                   cuts=[((0, 0, hem), (0, 0, 1), None),
                         # Armholes: nothing above arm_top outside the straps.
                         ((0, 0, arm_top), (0, 0, -1), lambda co: abs(co.x) > 0.1),
                         # Scoop neck front and back between the straps.
                         ((0, 0, neck_line), (0, 0, -1), lambda co: abs(co.x) < 0.055),
                         ((0.1, 0, 0), (-1, 0, 0), lambda co: co.z > arm_top and co.x > 0),
                         ((-0.1, 0, 0), (1, 0, 0), lambda co: co.z > arm_top and co.x < 0),
                         ((0.055, 0, 0), (1, 0, 0), lambda co: co.z > neck_line and co.x > 0),
                         ((-0.055, 0, 0), (-1, 0, 0), lambda co: co.z > neck_line and co.x < 0)])
    paint(tank, lambda co, n: MASK0)
    knee = L.leg[1]["knee"].z
    shorts = garment(body, "shorts", lambda co: knee < co.z < H * 0.56 and legs(co),
                     lambda co: 0.02 + 0.015 * max(0.0, (H * 0.45 - co.z) / (H * 0.45 - knee)),
                     cuts=[((0, 0, knee + 0.03), (0, 0, 1), None), ((0, 0, H * 0.54), (0, 0, -1), None)])
    paint(shorts, lambda co, n: MASK0)
    for g in (shirt, pants, boots, tank, shorts):
        copy_weights(g, body)
    return shirt, pants, boots, tank, shorts


def split_head(body, L):
    """Moves the human head onto its own mesh so animal heads can replace it."""
    cut = L.chin_z - 0.03
    head = garment(body, "head_human", lambda co: co.z > cut - 0.03 and not L.is_arm(co), lambda co: 0.0,
                   thickness=0, cuts=[((0, 0, cut), (0, 0, 1), None)])
    copy_weights(head, body)
    hide_covered(body, lambda co: co.z > cut + 0.005 and not L.is_arm(co))
    return head


def body_mask(L, co, n):
    """Lighter belly and chest for the beast form."""
    H = L.H
    if L.is_arm(co):
        return mask(0.0, spots(co))
    front = n.y > 0.35 and abs(co.x) < H * 0.07
    return mask(1.0 if front and H * 0.45 < co.z < L.neck.z else 0.0, spots(co))


def base_setup(sex):
    path, height = BASES[sex]
    reset_scene()
    SKULL[0] = None
    body = load_base(path, height)
    L = Landmarks(body, height)
    paint(body, lambda co, n: body_mask(L, co, n))
    return body, L


def human_face(L, sex):
    face = anime_eyes(L, srgb(0.45, 0.32, 0.22) if sex == "male" else srgb(0.4, 0.55, 0.3),
                      size=1.1, lashes=1.0 if sex == "male" else 1.4, brow_tilt=0.08 if sex == "male" else -0.05)
    obj = face[0]
    join(face[1:], obj)
    obj.name = "face_human"
    set_weights(obj, lambda co: {"Head": 1.0})
    return obj


def build_customizable(sex):
    body, L = base_setup(sex)
    H = HeadSpace(L)
    face = human_face(L, sex)
    rig = build_rig("beastfolk_" + sex, L)
    auto_weight(body, rig)
    hands = replace_hands(body, L, MASK0)
    hands_obj = hands[0]
    join(hands[1:], hands_obj)
    hands_obj.name = "hands"
    clothes = shirt_and_pants(body, L)
    head = split_head(body, L)
    SKULL[0] = head
    roots = back_points(L)
    parts = [head, face, hands_obj, *clothes]
    for sp in EAR_SPECIES:  # ears first: they are planted by casting rays at the bare skull
        ears = build_ears(sp, H)
        if ears:
            parts.append(ears)
    parts.append(build_hair(sex, H, head))
    for sp in HEAD_SPECIES:
        parts += build_head(sp, H, sex)
    for sp in TAIL_SPECIES:
        parts += build_tail(sp, L, roots)
    attach(parts, rig)
    body.name = "body"
    mat = make_material("beastfolk")
    for o in [body] + parts:
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(mat)
    name = "beastfolk_" + sex
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL")
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in [body] + parts if o.type == "MESH")
    print(f"{name}: {len(parts) + 1} parts, {tris} triangles total")


# --------------------------------------------------------------------------
# NPCs: baked colors, one mesh.
# --------------------------------------------------------------------------

def bake(obj, primary, secondary):
    """Turns a marking mask into final colors."""
    attr = obj.data.color_attributes["Col"]
    for i, v in enumerate(obj.data.vertices):
        m = attr.data[i].color[0]
        attr.data[i].color = tuple(primary[k] * (1 - m) + secondary[k] * m for k in range(3)) + (1.0,)


GOLD = srgb(0.93, 0.74, 0.3)
GOLD_DARK = srgb(0.7, 0.5, 0.18)
TURQUOISE = srgb(0.2, 0.72, 0.7)


def egypt_collar(body, L, color_fn):
    nz = L.neck.z + 0.01
    pts = [v for v in L.verts if abs(v.z - nz) < 0.02 and not L.is_arm(v) and abs(v.x) < 0.1]
    ny = sum(v.y for v in pts) / len(pts)
    neck_pt = Vector((0, ny, nz))

    def dist(co):
        d = co - neck_pt
        return math.hypot(d.x / 1.15, d.y, d.z * 1.3)
    collar = garment(body, "collar", lambda co: dist(co) < 0.22 and co.z < nz + 0.02 and not L.is_arm(co),
                     lambda co: 0.03, cuts=[((0, 0, nz), (0, 0, -1), None)])
    paint(collar, lambda co, n: color_fn(int((dist(co) - 0.05) / 0.024)))
    copy_weights(collar, body)
    return collar, neck_pt


def build_npc(kind):
    sex = "male"
    body, L = base_setup(sex)
    H = HeadSpace(L)
    rig = build_rig("npc_" + kind, L)
    auto_weight(body, rig)
    species = "shark" if kind == "shark" else "wolf"
    if kind == "shark":
        fur, light = srgb(0.46, 0.5, 0.56), srgb(0.84, 0.86, 0.88)
    else:
        fur, light = srgb(0.17, 0.17, 0.19), srgb(0.3, 0.3, 0.32)
    hands = replace_hands(body, L, MASK0)
    head = split_head(body, L)
    hide_covered(head, lambda co: True)
    roots = back_points(L)
    head_obj, face = build_head(species, H, sex, iris=srgb(0.9, 0.12, 0.1) if kind == "wolf" else None)
    tail = build_tail(species, L, roots)
    furred = [body, head_obj, *hands, *tail]
    for o in furred:
        bake(o, fur, light)
    extra = []
    torso = lambda co: not L.is_arm(co) and abs(co.x) < L.H * 0.16  # noqa: E731
    legs = lambda co: not L.is_arm(co) and abs(co.x) < L.H * 0.2  # noqa: E731

    if kind == "shark":
        # Purple sleeveless hooded vest with gold trim, dark trousers, gold arm bands.
        purple = srgb(0.27, 0.2, 0.42)
        hem = L.H * 0.5
        vest = garment(body, "vest", lambda co: hem - 0.03 < co.z < L.neck.z - 0.01 and torso(co), lambda co: 0.022,
                       cuts=[((0, 0, hem), (0, 0, 1), None)])
        paint(vest, lambda co, n: purple)
        trim = garment(body, "vest_trim", lambda co: hem - 0.03 < co.z < hem + 0.06 and torso(co), lambda co: 0.027,
                       cuts=[((0, 0, hem), (0, 0, 1), None), ((0, 0, hem + 0.035), (0, 0, -1), None)])
        paint(trim, lambda co, n: GOLD)
        hood_c = Vector((0, H.c.y - H.s * 1.2, L.neck.z - 0.02))
        bm = bmesh.new()
        for k in range(11):
            a = math.radians(-120 + k * 24)
            add_capsule(bm, hood_c + Vector((0.16 * math.sin(a), 0.1 * (1 - math.cos(a)) - 0.02, 0)),
                        hood_c + Vector((0.16 * math.sin(a), 0.1 * (1 - math.cos(a)) - 0.02, 0.0)), 0.06, 0.06)
        add_ellipsoid(bm, hood_c + Vector((0, -0.05, -0.08)), (0.17, 0.07, 0.12))
        hood = new_object("hood", bm)
        remesh_and_smooth(hood, voxel=0.008, smooth_repeat=5)
        paint(hood, lambda co, n: GOLD if co.z > hood_c.z + 0.04 else purple)
        set_weights(hood, lambda co: {"UpperChest": 0.7, "Neck": 0.3})
        pants = garment(body, "pants", lambda co: 0.1 < co.z < L.H * 0.56 and legs(co), lambda co: 0.018,
                        cuts=[((0, 0, 0.13), (0, 0, 1), None)])
        paint(pants, lambda co, n: srgb(0.12, 0.11, 0.14))
        belt = garment(body, "belt", lambda co: L.H * 0.52 < co.z < L.H * 0.58 and torso(co), lambda co: 0.026,
                       cuts=[((0, 0, L.H * 0.535), (0, 0, 1), None), ((0, 0, L.H * 0.555), (0, 0, -1), None)])
        paint(belt, lambda co, n: GOLD)
        bands = [arm_band(body, L, "armband", 0.2, 0.26, 0.012, GOLD),
                 arm_band(body, L, "wristband", 0.5, WRIST_T, 0.012, GOLD)]
        extra += [vest, trim, pants, belt] + bands
        for g in extra:
            copy_weights(g, body)
        extra.append(hood)
    else:
        # Gold usekh collar with an ankh, bracers, arm bands, belt and a pleated shendyt kilt.
        collar, neck_pt = egypt_collar(body, L, lambda b: TURQUOISE if b in (2, 4) else GOLD if b % 2 == 0
                                       else GOLD_DARK)
        bands = [arm_band(body, L, "armband", 0.18, 0.25, 0.014, GOLD),
                 arm_band(body, L, "bracer", 0.42, WRIST_T, 0.014, GOLD),
                 arm_band(body, L, "bracer_line", 0.5, 0.53, 0.018, srgb(0.15, 0.2, 0.45))]
        b0, b1 = L.H * 0.52, L.H * 0.555
        belt = garment(body, "belt", lambda co: b0 - 0.03 < co.z < b1 + 0.03 and torso(co), lambda co: 0.02,
                       cuts=[((0, 0, b0), (0, 0, 1), None), ((0, 0, b1), (0, 0, -1), None)])
        paint(belt, lambda co, n: GOLD)
        extra += [collar, belt] + bands
        for g in extra[1:]:
            copy_weights(g, body)
        pts = [v for v in L.verts if abs(v.z - b0) < 0.012 and torso(v)]
        xs, ys = [p.x for p in pts], [p.y for p in pts]
        center = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 0))
        top_r = ((max(xs) - min(xs)) / 2 + 0.03, (max(ys) - min(ys)) / 2 + 0.03)
        navy, stripe = srgb(0.14, 0.17, 0.35), GOLD

        def kilt_color(th, t, co):
            if t < 0.06 or t > 0.92:
                return GOLD
            return stripe if math.cos(th * 24) > 0.8 else navy
        kilt = ring_skirt(center, b0 + 0.005, top_r, L.H * 0.3, (top_r[0] + 0.08, top_r[1] + 0.08), kilt_color,
                          pleats=24, pleat_depth=0.05, segs=144,
                          rows=[0, 0.06, 0.07] + [i / 10 for i in range(1, 10)] + [0.91, 0.92, 1.0])
        set_weights(kilt, skirt_weights(L, b0))
        extra.append(kilt)
        # Ankh pendant hanging from the collar.
        dep = bpy.context.evaluated_depsgraph_get()
        hit, loc, *_ = bpy.context.scene.ray_cast(dep, Vector((0, 2, neck_pt.z - 0.2)), Vector((0, -1, 0)))
        p = (loc if hit else neck_pt + Vector((0, 0.15, -0.2))) + Vector((0, 0.012, 0))
        bm = bmesh.new()
        add_capsule(bm, p + Vector((0, 0, -0.07)), p + Vector((0, 0, 0.01)), 0.008, 0.008)
        add_capsule(bm, p + Vector((-0.035, 0, 0.01)), p + Vector((0.035, 0, 0.01)), 0.008, 0.008)
        for k in range(12):
            a = k / 12 * math.tau
            add_ellipsoid(bm, p + Vector((0.022 * math.sin(a), 0, 0.04 + 0.03 * math.cos(a))), (0.008, 0.008, 0.008))
        ankh = new_object("ankh", bm)
        remesh_and_smooth(ankh, voxel=0.003, smooth_repeat=1)
        paint(ankh, lambda co, n: GOLD)
        set_weights(ankh, lambda co: {"UpperChest": 1.0})
        extra.append(ankh)

    set_weights(head_obj, lambda co: {"Head": 1.0})
    parts = [head_obj, face, *hands, *tail, *extra]
    join(parts, body)
    select_only(head)
    bpy.data.objects.remove(head)
    body.data.validate()
    body.data.materials.clear()
    body.data.materials.append(make_material("npc_" + kind))
    name = "npc_shark" if kind == "shark" else "npc_wolf_egypt"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL")
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"{name}: {tris} triangles")


if __name__ == "__main__":
    args = sys.argv[1:]
    todo = [a for a in args if a in ("male", "female", "npcs", "shark", "wolf")] or ["male", "female", "npcs"]
    if "male" in todo:
        build_customizable("male")
    if "female" in todo:
        build_customizable("female")
    if "npcs" in todo or "shark" in todo:
        build_npc("shark")
    if "npcs" in todo or "wolf" in todo:
        build_npc("wolf")
