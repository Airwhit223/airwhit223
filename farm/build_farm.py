"""Builds stylized, rigged farm animals: cow, sheep and chicken, each with
two coats. Same style, pipeline and idle animation as the pets.

Run with Blender 5.x:
    blender --background --python farm/build_farm.py [name ...]
or with the bpy pip module (Python 3.13):
    python farm/build_farm.py [name ...]

Models face +Y in Blender (-Z forward in Godot).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pets"))
import build_pets as bp  # noqa: E402
from build_pets import (  # noqa: E402
    Vector, add_sphere, ball, capsule, chain, ear, ellipsoid, near, srgb, surface_point, tuft,
)

bp.OUT_DIR = HERE


def hoof(center, size, mirror=True):
    return ellipsoid(center, size, mirror=mirror)


# --------------------------------------------------------------------------
# Cow: back at about 1.2 m.
# --------------------------------------------------------------------------

COW_SHAPES = [
    ellipsoid((0, 0.0, 0.97), (0.34, 0.72, 0.32)),        # barrel
    ellipsoid((0, 0.0, 0.84), (0.3, 0.58, 0.27)),         # belly
    ellipsoid((0, -0.52, 1.0), (0.31, 0.26, 0.3)),       # rump
    ellipsoid((0, 0.5, 0.96), (0.3, 0.26, 0.33)),        # chest
    capsule((0, 0.62, 1.02), (0, 0.84, 1.18), 0.2, 0.17),  # neck
    ellipsoid((0, 0.95, 1.22), (0.17, 0.2, 0.2)),        # head
    ellipsoid((0, 1.13, 1.1), (0.16, 0.12, 0.12)),       # muzzle
    capsule((0.2, 0.5, 0.78), (0.2, 0.52, 0.12), 0.095, 0.07, mirror=True),     # front leg
    hoof((0.2, 0.54, 0.05), (0.078, 0.09, 0.05)),
    capsule((0.2, -0.5, 0.85), (0.2, -0.54, 0.12), 0.11, 0.07, mirror=True),    # back leg
    hoof((0.2, -0.52, 0.05), (0.078, 0.09, 0.05)),
    ellipsoid((0, -0.3, 0.62), (0.13, 0.15, 0.1)),       # udder
    *[ball((dx, -0.3 + dy, 0.52), 0.022) for dx in (-0.05, 0.05) for dy in (-0.05, 0.05)],
    *chain([(0, -0.76, 1.12), (0, -0.84, 1.0), (0, -0.86, 0.85), (0, -0.85, 0.7)],
           [0.03, 0.025, 0.022, 0.02]),                  # tail
    ball((0, -0.85, 0.64), 0.055),                       # tail tuft
    ear((0.15, 0.9, 1.25), (0.33, 0.88, 1.23), 0.1, 0.045),
    ear((0.09, 0.93, 1.38), (0.19, 0.96, 1.5), 0.055, 0.05),   # horns
]

COW_SKELETON = [
    ("pelvis", None, (0, -0.5, 1.0)),
    ("spine", "pelvis", (0, 0.0, 1.0)),
    ("chest", "spine", (0, 0.5, 1.0)),
    ("neck", "chest", (0, 0.85, 1.2)),
    ("head", "neck", (0, 1.0, 1.26)),
    ("jaw", "head", (0, 1.16, 1.08)),
    ("ear.{s}", "head", (0.32, 0.88, 1.23)),
    ("upper_arm.{s}", "chest", (0.2, 0.51, 0.45)),
    ("forearm.{s}", "upper_arm.{s}", (0.2, 0.52, 0.1)),
    ("front_paw.{s}", "forearm.{s}", (0.2, 0.6, 0.03)),
    ("thigh.{s}", "pelvis", (0.2, -0.52, 0.48)),
    ("shin.{s}", "thigh.{s}", (0.2, -0.54, 0.1)),
    ("back_paw.{s}", "shin.{s}", (0.2, -0.46, 0.03)),
    ("tail_1", "pelvis", (0, -0.8, 1.08)),
    ("tail_2", "tail_1", (0, -0.85, 0.98)),
    ("tail_3", "tail_2", (0, -0.86, 0.86)),
    ("tail_4", "tail_3", (0, -0.85, 0.74)),
    ("tail_5", "tail_4", (0, -0.85, 0.62)),
]

COW_COATS = {
    "cow": dict(base=srgb(0.97, 0.96, 0.94), patch=srgb(0.12, 0.12, 0.14), pink=srgb(0.95, 0.68, 0.7),
                hoof=srgb(0.25, 0.22, 0.22), horn=srgb(0.93, 0.88, 0.76), iris=srgb(0.35, 0.22, 0.15)),
    "cow_brown": dict(base=srgb(0.6, 0.38, 0.22), patch=srgb(0.97, 0.94, 0.9), pink=srgb(0.88, 0.62, 0.58),
                      hoof=srgb(0.22, 0.18, 0.16), horn=srgb(0.93, 0.88, 0.76), iris=srgb(0.3, 0.18, 0.1)),
}


def make_cow_color(c):
    def color(co, n):
        x, y, z = co
        ax = abs(x)
        if z > 1.3 and y > 0.85 and ax > 0.08 and ax < 0.22 and z > 1.36:
            return c["horn"]
        if z < 0.1 and ((abs(y - 0.53) < 0.1) or abs(y + 0.52) < 0.1):
            return c["hoof"]
        if y > 1.04 and z < 1.2:
            return c["pink"]  # muzzle
        if near(co, (0, -0.3, 0.6), 0.15) and z < 0.68:
            return c["pink"]  # udder
        if y < -0.8 and z < 0.7:
            return c["patch"] if c["patch"][0] < 0.5 else c["base"]  # tail tuft
        if ax > 0.2 and y > 0.84 and z > 1.18 and n.y > 0.4:
            return c["pink"]  # inner ear
        if y > 0.8 and z > 1.1:  # head: dark with a pale blaze
            blaze = ax < 0.045 and n.y > 0.3
            return c["base"] if blaze else c["patch"]
        if z < 0.45:
            return c["base"]  # lower legs
        f = (math.sin(x * 8.0 + 1.3) * math.sin(y * 6.0 + 0.5)
             + 0.7 * math.sin(z * 9.0 + y * 4.0 + x * 3.0))
        return c["patch"] if f > 0.55 else c["base"]
    return color


def cow_face(c):
    parts = []
    for s in (1, -1):
        p = surface_point(s * 0.055, 1.12)
        parts.append(add_sphere("nostril", p + Vector((0, -0.006, 0)), 0.018, srgb(0.25, 0.12, 0.13),
                                scale=(1.0, 0.5, 1.3)))
    return parts


# --------------------------------------------------------------------------
# Sheep: a woolly cloud on thin dark legs, about 0.85 m tall.
# --------------------------------------------------------------------------

def wool_balls():
    out = [ellipsoid((0, 0, 0.6), (0.27, 0.42, 0.25))]
    for i in range(7):
        y = -0.36 + i * 0.12
        for a in range(-2, 9):
            ang = a / 10 * math.pi
            r = 0.26 * math.sqrt(max(0.0, 1 - (y / 0.46) ** 2)) + 0.03
            out.append(ball((r * math.cos(ang), y, 0.62 + r * 0.95 * math.sin(ang)), 0.1))
    return out


SHEEP_SHAPES = [
    *wool_balls(),
    ellipsoid((0, 0.5, 0.72), (0.1, 0.14, 0.12)),        # face
    ball((0, 0.44, 0.84), 0.1),                           # wool cap
    ball((0.06, 0.42, 0.8), 0.08, mirror=True),
    capsule((0.13, 0.26, 0.42), (0.13, 0.28, 0.06), 0.038, 0.033, mirror=True),
    hoof((0.13, 0.29, 0.03), (0.04, 0.05, 0.03)),
    capsule((0.13, -0.28, 0.42), (0.13, -0.3, 0.06), 0.04, 0.033, mirror=True),
    hoof((0.13, -0.29, 0.03), (0.04, 0.05, 0.03)),
    *chain([(0, -0.42, 0.68), (0, -0.49, 0.64), (0, -0.53, 0.58), (0, -0.55, 0.54), (0, -0.56, 0.5)],
           [0.06, 0.06, 0.055, 0.05, 0.04]),              # stubby tail
    ear((0.08, 0.47, 0.76), (0.2, 0.45, 0.71), 0.075, 0.03),
]

SHEEP_SKELETON = [
    ("pelvis", None, (0, -0.28, 0.62)),
    ("spine", "pelvis", (0, 0.0, 0.63)),
    ("chest", "spine", (0, 0.26, 0.63)),
    ("neck", "chest", (0, 0.42, 0.72)),
    ("head", "neck", (0, 0.52, 0.78)),
    ("jaw", "head", (0, 0.62, 0.68)),
    ("ear.{s}", "head", (0.2, 0.45, 0.71)),
    ("upper_arm.{s}", "chest", (0.13, 0.27, 0.25)),
    ("forearm.{s}", "upper_arm.{s}", (0.13, 0.28, 0.05)),
    ("front_paw.{s}", "forearm.{s}", (0.13, 0.33, 0.02)),
    ("thigh.{s}", "pelvis", (0.13, -0.29, 0.25)),
    ("shin.{s}", "thigh.{s}", (0.13, -0.3, 0.05)),
    ("back_paw.{s}", "shin.{s}", (0.13, -0.25, 0.02)),
    ("tail_1", "pelvis", (0, -0.47, 0.65)),
    ("tail_2", "tail_1", (0, -0.51, 0.61)),
    ("tail_3", "tail_2", (0, -0.54, 0.56)),
    ("tail_4", "tail_3", (0, -0.555, 0.52)),
    ("tail_5", "tail_4", (0, -0.56, 0.48)),
]

SHEEP_COATS = {
    "sheep": dict(wool=srgb(0.97, 0.95, 0.9), face=srgb(0.18, 0.16, 0.16), inner=srgb(0.85, 0.6, 0.6),
                  hoof=srgb(0.1, 0.09, 0.09), iris=srgb(0.55, 0.45, 0.2)),
    "sheep_black": dict(wool=srgb(0.22, 0.2, 0.21), face=srgb(0.12, 0.11, 0.11), inner=srgb(0.6, 0.4, 0.4),
                        hoof=srgb(0.06, 0.05, 0.05), iris=srgb(0.6, 0.5, 0.2)),
}


def make_sheep_color(c):
    def color(co, n):
        x, y, z = co
        if z < 0.045:
            return c["hoof"]
        if z < 0.4 and abs(x) > 0.08:
            return c["face"]  # legs
        if near(co, (0, 0.44, 0.84), 0.11) or near(co, (0.06, 0.42, 0.8), 0.085) \
                or near(co, (-0.06, 0.42, 0.8), 0.085):
            return c["wool"]  # woolly cap
        if y > 0.4 and z < 0.85:
            if abs(x) > 0.1 and n.y > 0.3 and z > 0.69:
                return c["inner"]
            return c["face"]
        return c["wool"]
    return color


# --------------------------------------------------------------------------
# Chicken: about 0.5 m to the top of the comb.
# --------------------------------------------------------------------------

def toes_for(x):
    return [tuft((x, 0.0, 0.015), (x + dx, 0.075, 0.008), 0.011) for dx in (-0.03, 0.0, 0.03)] + \
           [tuft((x, 0.0, 0.015), (x, -0.045, 0.01), 0.01)]


CHICKEN_SHAPES = [
    ellipsoid((0, -0.01, 0.25), (0.13, 0.17, 0.14)),     # body
    ellipsoid((0, 0.08, 0.25), (0.115, 0.1, 0.12)),      # breast
    capsule((0, 0.08, 0.3), (0, 0.12, 0.4), 0.07, 0.055),  # neck
    ball((0, 0.13, 0.44), 0.065),                        # head
    ellipsoid((0.115, -0.01, 0.26), (0.035, 0.13, 0.08), mirror=True),  # wings
    capsule((0.05, 0.0, 0.14), (0.05, 0.01, 0.02), 0.013, 0.011, mirror=True),  # legs
    *toes_for(0.05), *toes_for(-0.05),
    *[("toe", p, (0.012, 0.024, 0.026), False) for p in ((0, 0.125, 0.515), (0, 0.098, 0.51), (0, 0.15, 0.503),
                                                          (0, 0.075, 0.5))],  # comb
    ellipsoid((0, 0.185, 0.39), (0.016, 0.013, 0.026)),  # wattle
    ear((0, 0.18, 0.435), (0, 0.24, 0.425), 0.04, 0.03, mirror=False),  # beak
    tuft((0, -0.13, 0.3), (0, -0.2, 0.46), 0.06),
    tuft((0.03, -0.13, 0.3), (0.05, -0.23, 0.42), 0.055, mirror=True),
    tuft((0, -0.14, 0.28), (0, -0.25, 0.36), 0.05),
    *chain([(0, -0.12, 0.29), (0, -0.15, 0.33), (0, -0.17, 0.37), (0, -0.19, 0.41), (0, -0.2, 0.44)],
           [0.05, 0.045, 0.04, 0.03, 0.02]),
]

CHICKEN_SKELETON = [
    ("pelvis", None, (0, -0.08, 0.25)),
    ("spine", "pelvis", (0, 0.02, 0.26)),
    ("chest", "spine", (0, 0.09, 0.27)),
    ("neck", "chest", (0, 0.12, 0.4)),
    ("head", "neck", (0, 0.14, 0.48)),
    ("jaw", "head", (0, 0.23, 0.43)),
    ("upper_arm.{s}", "chest", (0.12, -0.08, 0.26)),
    ("thigh.{s}", "pelvis", (0.05, 0.0, 0.14)),
    ("shin.{s}", "thigh.{s}", (0.05, 0.01, 0.02)),
    ("back_paw.{s}", "shin.{s}", (0.05, 0.07, 0.01)),
    ("tail_1", "pelvis", (0, -0.15, 0.33)),
    ("tail_2", "tail_1", (0, -0.17, 0.37)),
    ("tail_3", "tail_2", (0, -0.19, 0.41)),
    ("tail_4", "tail_3", (0, -0.2, 0.44)),
    ("tail_5", "tail_4", (0, -0.21, 0.47)),
]

CHICKEN_COATS = {
    "chicken": dict(body=srgb(0.98, 0.97, 0.94), wing=srgb(0.9, 0.88, 0.84), tail=srgb(0.95, 0.94, 0.9),
                    red=srgb(0.88, 0.16, 0.16), yellow=srgb(0.98, 0.72, 0.2), iris=srgb(0.95, 0.6, 0.1)),
    "chicken_brown": dict(body=srgb(0.66, 0.36, 0.16), wing=srgb(0.5, 0.26, 0.1), tail=srgb(0.2, 0.15, 0.12),
                          red=srgb(0.88, 0.16, 0.16), yellow=srgb(0.95, 0.68, 0.22), iris=srgb(0.95, 0.6, 0.1)),
}


def make_chicken_color(c):
    def color(co, n):
        x, y, z = co
        ax = abs(x)
        comb = any(near(co, p, 0.034) for p in ((0, 0.125, 0.515), (0, 0.098, 0.51), (0, 0.15, 0.503),
                                                 (0, 0.075, 0.5)))
        if (comb and z > 0.49) or near(co, (0, 0.185, 0.39), 0.028):
            return c["red"]  # comb and wattle
        if y > 0.19 and 0.41 < z < 0.455:
            return c["yellow"]  # beak
        if z < 0.12:
            return c["yellow"]  # legs and feet
        if y < -0.13 and z > 0.3:
            return c["tail"]
        if ax > 0.1 and -0.14 < y < 0.12 and 0.19 < z < 0.33:
            return c["wing"]
        return c["body"]
    return color


# --------------------------------------------------------------------------

ANIMALS = []
for coat, c in COW_COATS.items():
    ANIMALS.append((coat, COW_SHAPES, COW_SKELETON, make_cow_color(c),
                    dict(x=0.1, z=1.28, radius=0.035, sink=0.012, tall=0.9, pupil_w=1.0, iris=c["iris"]),
                    0.25, (lambda: cow_face(None)), coat == "cow"))
for coat, c in SHEEP_COATS.items():
    ANIMALS.append((coat, SHEEP_SHAPES, SHEEP_SKELETON, make_sheep_color(c),
                    dict(x=0.05, z=0.76, radius=0.024, sink=0.006, tall=0.8, pupil_w=1.4, iris=c["iris"]),
                    0.3, None, coat == "sheep"))
for coat, c in CHICKEN_COATS.items():
    ANIMALS.append((coat, CHICKEN_SHAPES, CHICKEN_SKELETON, make_chicken_color(c),
                    dict(x=0.04, z=0.455, radius=0.013, sink=0.002, tall=1.0, pupil_w=0.8, iris=c["iris"]),
                    0.15, None, coat == "chicken"))

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if any(a == x[0] for x in ANIMALS)]
    for name, shapes, skel, color, eye, tail, face, blend in ANIMALS:
        if only and name not in only:
            continue
        bp.build(name, shapes, skel, color, eye, tail, face=face, save_blend=blend)
