"""Builds stylized, rigged Husky and Maine Coon companion models.

Run with Blender 5.x:
    blender --background --python pets/build_pets.py
or with the bpy pip module (Python 3.13):
    python pets/build_pets.py

Outputs husky.glb / maine_coon.glb (for Godot) and .blend files next to
this script. Each animal is sculpted from simple blobs (SHAPES), fused into
one mesh, painted with vertex colors (the *_color functions), then rigged
(SKELETON) with automatic weights. Tweak the tables and re-run.

Models face +Y in Blender, which becomes -Z (forward) in Godot.
"""
import math
import os
import sys

import bpy  # must come before bmesh when using the bpy pip module
import bmesh
from mathutils import Matrix, Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__))


# --------------------------------------------------------------------------
# Shape helpers. Positions are (x, y, z) in meters. Anything with an x
# offset is mirrored to the other side automatically when mirror=True.
# --------------------------------------------------------------------------

def ball(center, radius, mirror=False):
    return ("ellipsoid", center, (radius, radius, radius), mirror)


def ellipsoid(center, size, mirror=False):
    return ("ellipsoid", center, size, mirror)


def capsule(a, b, radius, radius_b=None, mirror=False):
    return ("capsule", a, b, radius, radius_b or radius, mirror)


def chain(points, radii):
    """A tapered tube through several points (tails)."""
    return [capsule(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)]


def ear(base, tip, width, thickness, mirror=True):
    return ("ear", base, tip, width, thickness, mirror)


def toes(paw_center, paw_size, mirror=True):
    """Three little toe bumps along the front of a paw."""
    x, y, z = paw_center
    w, l, h = paw_size
    out = []
    for dx in (-0.55, 0.0, 0.55):
        out.append(("toe", (x + dx * w, y + l * 0.72, z - h * 0.1), (w * 0.36, w * 0.36, h * 0.8), mirror))
    return out


def tuft(base, tip, width, mirror=False):
    """A pointed fur spike, like the jagged fur edges in anime art."""
    return ("ear", base, tip, width * 1.9, width * 1.6, mirror)


# --------------------------------------------------------------------------
# Siberian Husky: stands to about thigh height of the player.
# --------------------------------------------------------------------------

HUSKY_SHAPES = [
    ellipsoid((0, 0.17, 0.6), (0.15, 0.2, 0.175)),        # deep chest
    ellipsoid((0, -0.22, 0.61), (0.13, 0.2, 0.14)),       # hindquarters
    capsule((0, -0.2, 0.62), (0, 0.12, 0.61), 0.125),     # waist
    capsule((0, 0.28, 0.67), (0, 0.38, 0.82), 0.125),     # neck ruff
    ball((0, 0.44, 0.9), 0.125),                          # skull
    ball((0.075, 0.45, 0.845), 0.068, mirror=True),       # cheek fluff
    capsule((0, 0.5, 0.865), (0, 0.61, 0.84), 0.06, 0.05),  # muzzle
    ball((0, 0.63, 0.858), 0.03),                         # nose
    capsule((0.082, 0.22, 0.54), (0.086, 0.25, 0.3), 0.078, 0.055, mirror=True),   # upper foreleg
    capsule((0.086, 0.25, 0.3), (0.086, 0.26, 0.06), 0.053, 0.046, mirror=True),   # lower foreleg
    ellipsoid((0.086, 0.285, 0.038), (0.055, 0.07, 0.038), mirror=True),        # front paw
    *toes((0.086, 0.285, 0.038), (0.055, 0.07, 0.038)),
    capsule((0.085, -0.28, 0.58), (0.09, -0.22, 0.33), 0.1, 0.065, mirror=True),  # thigh
    capsule((0.09, -0.22, 0.33), (0.09, -0.35, 0.13), 0.058, 0.046, mirror=True),  # shin
    capsule((0.09, -0.35, 0.13), (0.09, -0.34, 0.05), 0.046, 0.044, mirror=True),  # hock
    ellipsoid((0.09, -0.31, 0.038), (0.055, 0.07, 0.038), mirror=True),        # back paw
    *toes((0.09, -0.31, 0.038), (0.055, 0.07, 0.038)),
    *chain([(0, -0.38, 0.66), (0, -0.5, 0.72), (0, -0.6, 0.82), (0, -0.63, 0.94),
            (0, -0.57, 1.03), (0, -0.48, 1.04)],
           [0.05, 0.07, 0.085, 0.085, 0.07, 0.04]),       # sickle tail curled over the back
    ear((0.062, 0.425, 0.975), (0.08, 0.41, 1.12), 0.125, 0.05),
    # Fur tufts: cheek ruff, throat, elbows, tail.
    tuft((0.12, 0.43, 0.84), (0.19, 0.38, 0.8), 0.05, mirror=True),
    tuft((0.11, 0.42, 0.8), (0.17, 0.38, 0.73), 0.05, mirror=True),
    tuft((0.1, 0.41, 0.875), (0.17, 0.37, 0.885), 0.045, mirror=True),
    tuft((0, 0.39, 0.64), (0, 0.44, 0.52), 0.065),
    tuft((0.045, 0.39, 0.66), (0.06, 0.45, 0.56), 0.06, mirror=True),
    tuft((0.086, 0.22, 0.36), (0.09, 0.15, 0.3), 0.045, mirror=True),
    tuft((0, -0.5, 1.03), (0, -0.4, 1.02), 0.05),
    tuft((0, -0.62, 0.8), (0, -0.71, 0.75), 0.06),
    tuft((0, -0.64, 0.93), (0, -0.74, 0.95), 0.06),
    tuft((0, -0.55, 0.74), (0, -0.6, 0.65), 0.06),
]

HUSKY_SKELETON = [
    ("pelvis", None, (0, -0.26, 0.61)),
    ("spine", "pelvis", (0, -0.03, 0.61)),
    ("chest", "spine", (0, 0.18, 0.61)),
    ("neck", "chest", (0, 0.37, 0.8)),
    ("head", "neck", (0, 0.45, 0.92)),
    ("jaw", "head", (0, 0.62, 0.84)),
    ("ear.{s}", "head", (0.075, 0.41, 1.1)),
    ("upper_arm.{s}", "chest", (0.084, 0.24, 0.32)),
    ("forearm.{s}", "upper_arm.{s}", (0.086, 0.26, 0.07)),
    ("front_paw.{s}", "forearm.{s}", (0.086, 0.32, 0.03)),
    ("thigh.{s}", "pelvis", (0.088, -0.22, 0.33)),
    ("shin.{s}", "thigh.{s}", (0.088, -0.35, 0.13)),
    ("hock.{s}", "shin.{s}", (0.088, -0.34, 0.05)),
    ("back_paw.{s}", "hock.{s}", (0.088, -0.27, 0.03)),
    ("tail_1", "pelvis", (0, -0.5, 0.72)),
    ("tail_2", "tail_1", (0, -0.6, 0.82)),
    ("tail_3", "tail_2", (0, -0.63, 0.94)),
    ("tail_4", "tail_3", (0, -0.57, 1.03)),
    ("tail_5", "tail_4", (0, -0.47, 1.04)),
]


# --------------------------------------------------------------------------
# Maine Coon: large, fluffy, reaches the player's knee.
# --------------------------------------------------------------------------

COON_SHAPES = [
    ellipsoid((0, 0.1, 0.33), (0.1, 0.14, 0.11)),         # chest
    ellipsoid((0, -0.14, 0.32), (0.105, 0.15, 0.105)),    # hindquarters
    ellipsoid((0, 0.19, 0.35), (0.1, 0.075, 0.115)),      # chest mane
    capsule((0, 0.19, 0.37), (0, 0.25, 0.43), 0.085),     # neck
    ball((0, 0.29, 0.48), 0.1),                        # skull
    ball((0.058, 0.305, 0.44), 0.064, mirror=True),       # cheek fluff
    ball((0, 0.365, 0.445), 0.045),                        # muzzle
    ball((0, 0.355, 0.415), 0.032),                        # chin
    capsule((0.05, 0.14, 0.28), (0.054, 0.17, 0.15), 0.056, 0.042, mirror=True),  # upper foreleg
    capsule((0.054, 0.17, 0.15), (0.054, 0.17, 0.04), 0.041, 0.036, mirror=True),  # lower foreleg
    ellipsoid((0.054, 0.19, 0.028), (0.04, 0.05, 0.028), mirror=True),       # front paw
    *toes((0.054, 0.19, 0.028), (0.04, 0.05, 0.028)),
    capsule((0.058, -0.17, 0.31), (0.062, -0.12, 0.17), 0.075, 0.05, mirror=True),  # thigh
    capsule((0.062, -0.12, 0.17), (0.062, -0.21, 0.07), 0.042, 0.035, mirror=True),  # shin
    capsule((0.062, -0.21, 0.07), (0.062, -0.2, 0.035), 0.035, 0.034, mirror=True),  # hock
    ellipsoid((0.062, -0.18, 0.028), (0.04, 0.05, 0.028), mirror=True),       # back paw
    *toes((0.062, -0.18, 0.028), (0.04, 0.05, 0.028)),
    *chain([(0, -0.26, 0.36), (0, -0.36, 0.36), (0, -0.48, 0.34), (0, -0.6, 0.34),
            (0, -0.7, 0.38), (0, -0.76, 0.44)],
           [0.04, 0.06, 0.078, 0.085, 0.075, 0.042]),     # big bushy tail
    ear((0.05, 0.28, 0.55), (0.07, 0.27, 0.67), 0.09, 0.034),
    # Fur tufts: lynx ear tips, cheek ruff, chest mane, back legs, tail.
    tuft((0.066, 0.27, 0.64), (0.076, 0.27, 0.71), 0.022, mirror=True),
    tuft((0.1, 0.3, 0.44), (0.16, 0.27, 0.42), 0.045, mirror=True),
    tuft((0.09, 0.3, 0.41), (0.14, 0.28, 0.36), 0.04, mirror=True),
    tuft((0.1, 0.29, 0.47), (0.15, 0.26, 0.485), 0.035, mirror=True),
    tuft((0, 0.25, 0.3), (0, 0.3, 0.21), 0.05),
    tuft((0.05, 0.24, 0.31), (0.07, 0.29, 0.23), 0.045, mirror=True),
    tuft((0.06, 0.24, 0.38), (0.095, 0.29, 0.34), 0.04, mirror=True),
    tuft((0.07, -0.2, 0.25), (0.085, -0.28, 0.19), 0.05, mirror=True),
    *[t for y in (-0.45, -0.56, -0.66) for t in (
        tuft((0, y, 0.34), (0, y - 0.04, 0.47), 0.05),
        tuft((0, y, 0.34), (0, y - 0.05, 0.21), 0.05),
        tuft((0.03, y, 0.34), (0.13, y - 0.05, 0.36), 0.05, mirror=True),
    )],
    tuft((0, -0.74, 0.42), (0, -0.83, 0.5), 0.045),
]

COON_SKELETON = [
    ("pelvis", None, (0, -0.16, 0.32)),
    ("spine", "pelvis", (0, -0.02, 0.33)),
    ("chest", "spine", (0, 0.13, 0.34)),
    ("neck", "chest", (0, 0.25, 0.43)),
    ("head", "neck", (0, 0.3, 0.5)),
    ("jaw", "head", (0, 0.38, 0.43)),
    ("ear.{s}", "head", (0.068, 0.27, 0.66)),
    ("upper_arm.{s}", "chest", (0.052, 0.17, 0.15)),
    ("forearm.{s}", "upper_arm.{s}", (0.052, 0.17, 0.045)),
    ("front_paw.{s}", "forearm.{s}", (0.052, 0.22, 0.02)),
    ("thigh.{s}", "pelvis", (0.06, -0.12, 0.17)),
    ("shin.{s}", "thigh.{s}", (0.06, -0.21, 0.07)),
    ("hock.{s}", "shin.{s}", (0.06, -0.2, 0.035)),
    ("back_paw.{s}", "hock.{s}", (0.06, -0.15, 0.02)),
    ("tail_1", "pelvis", (0, -0.36, 0.36)),
    ("tail_2", "tail_1", (0, -0.48, 0.34)),
    ("tail_3", "tail_2", (0, -0.6, 0.34)),
    ("tail_4", "tail_3", (0, -0.7, 0.38)),
    ("tail_5", "tail_4", (0, -0.77, 0.45)),
]


# --------------------------------------------------------------------------
# Coat colors
# --------------------------------------------------------------------------

def in_ear(co, n, base, tip, width):
    """True on the forward-facing middle of an ear (the inner ear)."""
    x, y, z = co
    t = (z - base[2]) / (tip[2] - base[2])
    if t < 0.05 or t > 0.85 or n.y < 0.45:
        return False
    center_x = base[0] + (tip[0] - base[0]) * t
    return abs(abs(x) - center_x) < width * 0.3 * (1 - t)


def near(co, point, radius):
    return (co - Vector(point)).length < radius


def srgb(r, g, b):
    return tuple(c ** 2.2 for c in (r, g, b)) + (1.0,)


HUSKY_COATS = {
    # Sheet H1-H4.
    "husky": dict(dark=srgb(0.2, 0.21, 0.25), white=srgb(0.95, 0.95, 0.97), nose=srgb(0.07, 0.07, 0.09),
                  inner_ear=srgb(0.86, 0.84, 0.86), iris=srgb(0.55, 0.82, 0.97)),
    "husky_copper": dict(dark=srgb(0.66, 0.34, 0.17), white=srgb(0.97, 0.94, 0.9), nose=srgb(0.36, 0.2, 0.14),
                         inner_ear=srgb(0.95, 0.82, 0.76), iris=srgb(0.82, 0.58, 0.25)),
    "husky_silver": dict(dark=srgb(0.6, 0.62, 0.67), white=srgb(0.97, 0.97, 0.98), nose=srgb(0.1, 0.1, 0.12),
                         inner_ear=srgb(0.9, 0.88, 0.9), iris=srgb(0.55, 0.82, 0.97)),
    "husky_white": dict(dark=srgb(0.9, 0.9, 0.9), white=srgb(0.98, 0.98, 0.98), nose=srgb(0.12, 0.1, 0.1),
                        inner_ear=srgb(0.95, 0.83, 0.83), iris=srgb(0.45, 0.72, 0.92)),
}


def make_husky_color(coat):
    HUSKY_DARK, HUSKY_WHITE = coat["dark"], coat["white"]
    HUSKY_NOSE, HUSKY_INNER_EAR = coat["nose"], coat["inner_ear"]
    return lambda co, n: husky_color(co, n, HUSKY_DARK, HUSKY_WHITE, HUSKY_NOSE, HUSKY_INNER_EAR)


def husky_color(co, n, HUSKY_DARK, HUSKY_WHITE, HUSKY_NOSE, HUSKY_INNER_EAR):
    x, y, z = co
    ax = abs(x)
    if near(co, (0, 0.645, 0.865), 0.03):
        return HUSKY_NOSE
    if z > 0.975 and y > 0.3:  # ears
        if in_ear(co, n, (0.062, 0.425, 0.975), (0.08, 0.41, 1.12), 0.125):
            return HUSKY_INNER_EAR
        return HUSKY_DARK
    if y > 0.36 and z > 0.72:  # head
        if z < 0.872 or (y > 0.56 and z < 0.9):  # muzzle, cheeks, lower face
            return HUSKY_WHITE
        if n.y < 0.2:  # back and top of the head
            return HUSKY_DARK
        # White goggles around the eyes and eyebrow spots; the rest of
        # the forehead is the dark cap with its widow's-peak stripe.
        if ((ax - 0.056) / 0.036) ** 2 + ((z - 0.9) / 0.03) ** 2 < 1 and ax > 0.024:
            return HUSKY_WHITE
        if ((ax - 0.045) / 0.018) ** 2 + ((z - 0.945) / 0.012) ** 2 < 1:
            return HUSKY_WHITE
        return HUSKY_DARK
    if y > 0.36 and z < 0.72:  # throat ruff
        return HUSKY_WHITE
    if y < -0.4 and z > 0.62:  # tail: white underside and outer curve
        return HUSKY_WHITE if n.z < -0.15 or n.y < -0.6 else HUSKY_DARK
    if z < 0.3:  # lower legs
        return HUSKY_WHITE
    if n.z < -0.3:  # belly
        return HUSKY_WHITE
    if y > 0.16 and n.y > 0.35 and n.z < 0.55 and z < 0.84:  # chest bib and throat
        return HUSKY_WHITE
    if z < 0.46 and ax < 0.1:  # inner upper legs
        return HUSKY_WHITE
    return HUSKY_DARK


COON_COATS = {
    # Sheet M1-M4.
    "maine_coon": dict(base=srgb(0.62, 0.47, 0.28), stripe=srgb(0.27, 0.19, 0.11), cream=srgb(0.92, 0.83, 0.64),
                       nose=srgb(0.8, 0.5, 0.48), inner_ear=srgb(0.9, 0.7, 0.66), iris=srgb(0.96, 0.7, 0.2)),
    "maine_coon_silver": dict(base=srgb(0.6, 0.61, 0.64), stripe=srgb(0.33, 0.34, 0.38), cream=srgb(0.86, 0.87, 0.89),
                              nose=srgb(0.62, 0.45, 0.48), inner_ear=srgb(0.88, 0.76, 0.76),
                              iris=srgb(0.55, 0.8, 0.35)),
    "maine_coon_ginger": dict(base=srgb(0.93, 0.6, 0.28), stripe=srgb(0.74, 0.37, 0.13), cream=srgb(0.99, 0.9, 0.72),
                              nose=srgb(0.9, 0.55, 0.5), inner_ear=srgb(0.97, 0.76, 0.68),
                              iris=srgb(0.75, 0.8, 0.3)),
    "maine_coon_cream": dict(base=srgb(0.96, 0.88, 0.75), stripe=srgb(0.9, 0.72, 0.52), cream=srgb(1.0, 0.97, 0.91),
                             nose=srgb(0.92, 0.6, 0.58), inner_ear=srgb(0.98, 0.8, 0.76),
                             iris=srgb(0.9, 0.6, 0.25)),
}


def make_coon_color(coat):
    return lambda co, n: coon_color(co, n, coat["base"], coat["stripe"], coat["cream"], coat["nose"],
                                    coat["inner_ear"])


def coon_color(co, n, COON_BASE, COON_STRIPE, COON_CREAM, COON_NOSE, COON_INNER_EAR):
    x, y, z = co
    ax = abs(x)
    if near(co, (0, 0.41, 0.462), 0.018):
        return COON_NOSE
    if z > 0.55 and y > 0.2:  # ears, with dark lynx-tuft tips
        if in_ear(co, n, (0.05, 0.28, 0.55), (0.07, 0.27, 0.67), 0.09):
            return COON_INNER_EAR
        return COON_STRIPE if z > 0.64 else COON_BASE
    if y > 0.22 and ax > 0.09 and z < 0.5:  # cheek ruff
        return COON_CREAM
    if y > 0.22 and z < 0.4:  # chest mane tufts
        return COON_CREAM
    if y > 0.32 and z < 0.46:  # muzzle, chin, lower cheeks
        return COON_CREAM
    if y > 0.13 and n.y > 0.3 and 0.1 < z < 0.43:  # chest mane
        return COON_CREAM
    if n.z < -0.45 and -0.25 < y < 0.2:  # belly
        return COON_CREAM
    if z < 0.04:  # paws
        return COON_CREAM
    if y > 0.25 and z > 0.5:  # forehead "M" stripes
        s = math.sin(ax * 150.0 + 1.2)
        return COON_STRIPE if s > 0.5 and n.z > 0.2 else COON_BASE
    if y < -0.28 and z > 0.27:  # tail rings
        if y < -0.76:
            return COON_STRIPE
        s = math.sin(y * 38.0 + math.sin(z * 30.0))
        return COON_STRIPE if s > 0.3 else COON_BASE
    if z < 0.23 and ax > 0.02:  # leg bands
        return COON_STRIPE if math.sin(z * 80.0) > 0.6 else COON_BASE
    s = math.sin(y * 40.0 + 2.5 * math.sin(z * 25.0) + 1.5 * math.sin(ax * 30.0))
    return COON_STRIPE if s > 0.35 else COON_BASE


# --------------------------------------------------------------------------
# Building
# --------------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def add_ellipsoid(bm, center, size):
    m = Matrix.Translation(center) @ Matrix.Diagonal((*size, 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0, matrix=m)


def add_capsule(bm, a, b, ra, rb):
    a, b = Vector(a), Vector(b)
    steps = max(2, int((b - a).length / (min(ra, rb) * 0.35)) + 1)
    for i in range(steps + 1):
        t = i / steps
        r = ra + (rb - ra) * t
        add_ellipsoid(bm, a.lerp(b, t), (r, r, r))


def add_ear(bm, base, tip, width, thickness):
    """A flattened cone leaning slightly outward, facing forward (+Y)."""
    base, tip = Vector(base), Vector(tip)
    up = (tip - base).normalized()
    side = (Vector((1, 0, 0)) - up * up.x).normalized()
    front = up.cross(side)
    rot = Matrix((side, front, up)).transposed().to_4x4()
    scale = Matrix.Diagonal((width / 2, thickness / 2, 1.0, 1.0))
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=1.0,
                                radius2=0.02, depth=(tip - base).length)
    center = (base + tip) / 2
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ rot @ scale, verts=ret["verts"])


def blobs_to_mesh(name, shapes):
    body_bm = bmesh.new()
    ear_bm = bmesh.new()
    for shape in shapes:
        kind, mirror = shape[0], shape[-1]
        variants = [1, -1] if mirror else [1]
        for sign in variants:
            def m(p):
                return Vector((p[0] * sign, p[1], p[2]))
            if kind == "ellipsoid":
                add_ellipsoid(body_bm, m(shape[1]), shape[2])
            elif kind == "capsule":
                add_capsule(body_bm, m(shape[1]), m(shape[2]), shape[3], shape[4])
            elif kind == "ear":
                add_ear(ear_bm, m(shape[1]), m(shape[2]), shape[3], shape[4])
            elif kind == "toe":
                add_ellipsoid(ear_bm, m(shape[1]), shape[2])

    def to_obj(bm, obj_name):
        mesh = bpy.data.meshes.new(obj_name)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(obj_name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj

    body = to_obj(body_bm, name)
    ears = to_obj(ear_bm, name + "_ears")

    # Fuse the blobs and soften the seams between them.
    remesh_and_smooth(body, voxel=0.009, smooth_repeat=12)
    # Ears go on after smoothing so they stay pointy.
    join([ears], body)
    remesh_and_smooth(body, voxel=0.006, smooth_repeat=3)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.shade_smooth()
    return body


def decimate_painted(body, faces):
    """Simplifies after painting, so color edges come from the dense mesh."""
    dec = body.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, faces / max(1, len(body.data.polygons)))
    apply_modifiers(body)
    bpy.ops.object.shade_smooth()


def remesh_and_smooth(obj, voxel, smooth_repeat):
    rem = obj.modifiers.new("Remesh", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = voxel
    sm = obj.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.6
    sm.iterations = smooth_repeat
    apply_modifiers(obj)


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def join(parts, target):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()


def paint(obj, color_fn):
    mesh = obj.data
    attr = mesh.color_attributes.get("Col")
    if attr is None or attr.domain != "POINT":
        if attr is not None:
            mesh.color_attributes.remove(attr)
        attr = mesh.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for v in mesh.vertices:
        attr.data[v.index].color = color_fn(v.co, v.normal)
    mesh.color_attributes.active_color = attr


def surface_point(x, z):
    """Casts a ray from in front of the face back along -Y."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    hit, loc, _, _, _, _ = bpy.context.scene.ray_cast(
        depsgraph, Vector((x, 2.0, z)), Vector((0, -1, 0)))
    if not hit:
        sys.exit(f"eye placement missed the body at x={x}, z={z}")
    return loc


def add_sphere(name, loc, radius, color, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    paint(obj, lambda co, n: color)
    return obj


def add_eyes(eye):
    """Big cartoon eyes: iris, pupil and a highlight, pushed into the head."""
    parts = []
    r = eye["radius"]
    for sign in (1, -1):
        center = surface_point(eye["x"] * sign, eye["z"]) + Vector((0, -eye["sink"], 0))
        parts.append(add_sphere("iris", center, r, eye["iris"], scale=(1, 0.55, eye["tall"])))
        parts.append(add_sphere("pupil", center + Vector((0, r * 0.42, 0)), r * 0.5,
                                srgb(0.04, 0.04, 0.06), scale=(eye["pupil_w"], 0.5, 1.15)))
        if eye.get("rim"):
            parts.append(add_sphere("rim", center + Vector((0, -0.0015, 0)), r * 1.14, srgb(0.1, 0.07, 0.06),
                                    scale=(1, 0.55, eye["tall"])))
        else:
            parts.append(add_sphere("liner", center + Vector((0, r * 0.2, r * 1.0 * eye["tall"])),
                                    r * 1.02, srgb(0.06, 0.05, 0.06), scale=(1.05, 0.35, 0.1)))
        parts.append(add_sphere("shine", center + Vector((r * 0.3 * sign, r * 0.58, r * 0.35)),
                                r * 0.2, srgb(1, 1, 1), scale=(1, 0.5, 1)))
    return parts


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
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_smooth()
    paint(obj, lambda co, n: color)
    return obj


def mouth_line(center_z, half_width, drop, lift, radius, color, w_shape=False):
    """Philtrum from under the nose, then two curves out to the corners
    (a cat's "w" when w_shape is set)."""
    parts = []
    philtrum = [surface_point(0, center_z + drop * t) + Vector((0, 0.001, 0)) for t in (0.0, 0.5, 1.0)]
    parts.append(tube("mouth", philtrum, radius, color))
    bottom = center_z + drop
    for s in (1, -1):
        pts = []
        for k in range(9):
            t = k / 8
            x = s * half_width * t
            z = bottom + lift * (t * t if not w_shape else math.sin(t * math.pi) * 0.6 + t * t * 0.4)
            pts.append(surface_point(x, z) + Vector((0, 0.001, 0)))
        parts.append(tube("mouth", pts, radius, color))
    return parts


def husky_face(coat):
    parts = [add_sphere("nose", surface_point(0, 0.866) + Vector((0, -0.008, 0)), 0.027, coat["nose"],
                        scale=(1.0, 0.7, 0.72))]
    parts += mouth_line(0.846, 0.034, -0.022, 0.014, 0.0028, srgb(0.1, 0.08, 0.09))
    return parts


def coon_face(coat):
    nose = surface_point(0, 0.463)
    parts = [add_sphere("nose", nose + Vector((0, -0.003, 0)), 0.012, coat["nose"], scale=(1.1, 0.6, 0.75))]
    parts += mouth_line(0.455, 0.018, -0.012, 0.004, 0.0018, srgb(0.2, 0.12, 0.1), w_shape=True)
    for s in (1, -1):
        for k, dz in enumerate((0.003, -0.008)):
            root = surface_point(s * 0.03, 0.448 + dz) + Vector((0, -0.004, 0))
            tip = root + Vector((s * 0.065, -0.01 - 0.005 * k, dz * 2.5 + 0.004))
            mid = root.lerp(tip, 0.5) + Vector((0, 0, 0.004))
            parts.append(tube("whisker", [root, mid, tip], 0.0007, srgb(0.2, 0.16, 0.14)))
    return parts


def squash_legs(co):
    """Shorter, sturdier husky legs: compress everything below the back."""
    if co.z < 0.03:
        return co
    if co.z < 0.62:
        return Vector((co.x, co.y, 0.03 + (co.z - 0.03) * 0.9))
    return Vector((co.x, co.y, co.z - 0.059))


def expand(skeleton):
    out = []
    for name, parent, pos in skeleton:
        if "{s}" not in name:
            out.append((name, parent, Vector(pos)))
            continue
        for side, sign in (("R", 1), ("L", -1)):  # +X is the animal's right
            p = parent.format(s=side) if parent else None
            out.append((name.format(s=side), p, Vector((pos[0] * sign, pos[1], pos[2]))))
    return out


def build_rig(name, skeleton, remap=None):
    bones = expand(skeleton)
    if remap:
        bones = [(n, p, remap(pos)) for n, p, pos in bones]
    arm_data = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new(name + "_rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    positions = {b[0]: b[2] for b in bones}
    root_pos = next(b[2] for b in bones if b[1] is None)
    root = arm_data.edit_bones.new("root")
    root.head = Vector((0, root_pos.y, 0))
    root.tail = root_pos

    made = {}
    for bone_name, parent, pos in bones:
        if parent is None:
            continue
        eb = arm_data.edit_bones.new(bone_name)
        eb.head = positions[parent]
        eb.tail = pos
        eb.parent = made.get(parent, root)
        eb.use_connect = parent in made and (made[parent].tail - eb.head).length < 1e-5
        made[bone_name] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def bind(body, rig, extras):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    # Eyes follow the head bone rigidly.
    for obj in extras:
        vg = obj.vertex_groups.new(name="head")
        vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    join(extras, body)
    body.data.validate()


def make_material(name):
    mat = bpy.data.materials.new(name)
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    col = nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    mat.node_tree.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def add_idle_animation(rig, tail_amount):
    """Looping tail wag + breathing so the pet isn't frozen in place."""
    rig.animation_data_create()
    action = bpy.data.actions.new("idle")
    rig.animation_data.action = action
    frames = 48
    tail = ["tail_1", "tail_2", "tail_3", "tail_4", "tail_5"]
    for f in range(0, frames + 1, 4):
        phase = f / frames * math.tau
        for i, bone_name in enumerate(tail):
            pb = rig.pose.bones[bone_name]
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, math.sin(phase * 2 - i * 0.7) * tail_amount * (0.4 + i * 0.2))
            pb.keyframe_insert("rotation_euler", frame=f + 1)
        chest = rig.pose.bones["chest"]
        breath = 1 + 0.025 * math.sin(phase)
        chest.scale = (breath, 1, breath)
        chest.keyframe_insert("scale", frame=f + 1)
        head = rig.pose.bones["head"]
        head.rotation_mode = "XYZ"
        head.rotation_euler = (0.04 * math.sin(phase), 0, 0)
        head.keyframe_insert("rotation_euler", frame=f + 1)
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = frames
    track = rig.animation_data.nla_tracks.new()
    track.strips.new("idle", 1, action)
    rig.animation_data.action = None
    rig.pose.bones["chest"].scale = (1, 1, 1)


def build(name, shapes, skeleton, color_fn, eye, tail_amount, face=None, remap=None, save_blend=True):
    reset_scene()
    body = blobs_to_mesh(name, shapes)
    paint(body, color_fn)
    decimate_painted(body, 7000)
    extras = add_eyes(eye) + (face() if face else [])
    if remap:
        for obj in [body] + extras:
            for v in obj.data.vertices:
                v.co = remap(v.co)
    rig = build_rig(name, skeleton, remap)
    bind(body, rig, extras)
    body.data.materials.append(make_material(name + "_coat"))
    add_idle_animation(rig, tail_amount)

    if save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, name + ".blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT_DIR, name + ".glb"),
        export_format="GLB",
        export_animations=True,
        export_vertex_color="MATERIAL",
    )
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"{name}: {tris} triangles, {len(rig.data.bones)} bones")


if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if a in HUSKY_COATS or a in COON_COATS]
    for coat_name, coat in HUSKY_COATS.items():
        if only and coat_name not in only:
            continue
        build(coat_name, HUSKY_SHAPES, HUSKY_SKELETON, make_husky_color(coat),
              eye=dict(x=0.05, z=0.902, radius=0.028, sink=0.009, tall=0.85, pupil_w=1.0, iris=coat["iris"]),
              tail_amount=0.35, face=lambda coat=coat: husky_face(coat), remap=squash_legs,
              save_blend=coat_name == "husky")
    for coat_name, coat in COON_COATS.items():
        if only and coat_name not in only:
            continue
        build(coat_name, COON_SHAPES, COON_SKELETON, make_coon_color(coat),
              eye=dict(x=0.041, z=0.492, radius=0.028, sink=0.004, tall=1.15, pupil_w=0.5, iris=coat["iris"],
                       rim=True),
              tail_amount=0.2, face=lambda coat=coat: coon_face(coat), save_blend=coat_name == "maine_coon")
