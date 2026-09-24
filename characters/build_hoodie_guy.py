"""Curly-haired guy in an oversized hoodie, jeans and sneakers, built on the
Meshy male base (bases/male_base_meshy.glb).

Run with Blender 5.x:
    blender --background --python characters/build_hoodie_guy.py
or with the bpy pip module (Python 3.13):
    python characters/build_hoodie_guy.py

OUTFITS holds color schemes; each one is exported as its own character.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from base_character import (  # noqa: E402
    DARK, WHITE, WRIST_T, Landmarks, Vector, add_capsule, add_ellipsoid, anime_eyes, auto_weight,
    bmesh, build_rig, copy_weights, curly_hair, export, face_point, garment, hide_covered,
    join, load_base, new_object, paint, remesh_and_smooth, replace_hands, reset_scene, set_weights, srgb,
    tube,
)

BASE = os.path.join(HERE, "..", "bases", "male_base_meshy.glb")
HEIGHT = 1.78

OUTFITS = {
    # Green hoodie, blue jeans, green-and-white sneakers.
    "hoodie_guy": dict(
        skin=srgb(0.93, 0.77, 0.63), hair=srgb(0.1, 0.08, 0.07), hair_alt=srgb(0.2, 0.15, 0.12),
        iris=srgb(0.32, 0.28, 0.27), hoodie=srgb(0.47, 0.64, 0.46), hoodie_dark=srgb(0.36, 0.51, 0.36),
        hoodie_pocket=srgb(0.43, 0.6, 0.42),
        string=srgb(0.86, 0.9, 0.84), pants=srgb(0.27, 0.41, 0.63), pants_light=srgb(0.43, 0.56, 0.75),
        shoe=WHITE, shoe_accent=srgb(0.36, 0.56, 0.38), sole=srgb(0.95, 0.94, 0.9)),
    # Black hoodie, grey cargo pants, dark shoes.
    "hoodie_guy_black": dict(
        skin=srgb(0.93, 0.77, 0.63), hair=srgb(0.07, 0.07, 0.1), hair_alt=srgb(0.14, 0.14, 0.2),
        iris=srgb(0.3, 0.35, 0.5), hoodie=srgb(0.13, 0.13, 0.15), hoodie_dark=srgb(0.08, 0.08, 0.1),
        hoodie_pocket=srgb(0.11, 0.11, 0.13),
        string=srgb(0.6, 0.6, 0.62), pants=srgb(0.4, 0.4, 0.4), pants_light=srgb(0.48, 0.48, 0.47),
        shoe=srgb(0.2, 0.17, 0.15), shoe_accent=srgb(0.3, 0.25, 0.2), sole=srgb(0.15, 0.13, 0.12)),
}


def build(name, c):
    reset_scene()
    body = load_base(BASE, HEIGHT)
    L = Landmarks(body, HEIGHT)
    H = L.H
    paint(body, lambda co, n: c["skin"])
    face = anime_eyes(L, c["iris"], brow_tilt=0.05)

    rig = build_rig(name, L)
    auto_weight(body, rig)

    def arm_t(co):
        side = 1 if co.x > 0 else -1
        return L.arm_param(co, side)[0]

    # ---- Hoodie: loose torso and sleeves down to the wrists.
    hem_z, neck_z = H * 0.47, H * 0.775
    wrist_cuts = []
    for side in (1, -1):
        a = L.arm[side]
        up = (a["elbow"] - a["wrist"]).normalized()
        wrist_cuts.append((a["wrist"], up, lambda co, side=side: L.is_arm(co) and co.x * side > 0
                           and arm_t(co) > 0.45))

    def sleeve(co):
        side = 1 if co.x > 0 else -1
        t, d = L.arm_param(co, side)
        return (L.is_arm(co) or (abs(co.x) > H * 0.08 and d < 0.1)) and t < WRIST_T + 0.04

    def hoodie_region(co):
        return sleeve(co) or (hem_z - 0.04 < co.z < neck_z and abs(co.x) < H * 0.16 and not L.is_arm(co))

    def hoodie_offset(co):
        if L.is_arm(co):
            return 0.025 - 0.008 * max(0.0, (arm_t(co) - 0.45) / (WRIST_T - 0.45))
        return 0.012 if co.z > neck_z - 0.03 else 0.028

    torso = lambda co: not L.is_arm(co) and abs(co.x) < H * 0.13  # noqa: E731
    hoodie = garment(body, "hoodie", hoodie_region, hoodie_offset, keep=0.5,
                     cuts=[((0, 0, hem_z), (0, 0, 1), torso)] + wrist_cuts)
    paint(hoodie, lambda co, n: c["hoodie"])

    # Ribbed hem, ribbed cuffs and the kangaroo pocket sit just on top.
    lift = lambda extra: lambda co: hoodie_offset(co) + extra  # noqa: E731
    hem = garment(body, "hem", lambda co: hem_z - 0.04 < co.z < hem_z + 0.09 and torso(co), lift(0.004),
                  cuts=[((0, 0, hem_z), (0, 0, 1), None), ((0, 0, hem_z + 0.05), (0, 0, -1), None)])
    paint(hem, lambda co, n: c["hoodie_dark"])
    cuff_cuts = []
    for side in (1, -1):
        a = L.arm[side]
        up = (a["elbow"] - a["wrist"]).normalized()
        cuff_cuts += [(a["wrist"], up, lambda co, side=side: co.x * side > 0),
                      (a["wrist"] + up * 0.055, -up, lambda co, side=side: co.x * side > 0)]
    sleeve_cuffs = garment(body, "sleeve_cuffs", lambda co: sleeve(co) and arm_t(co) > WRIST_T - 0.1,
                           lift(0.004), cuts=cuff_cuts)
    paint(sleeve_cuffs, lambda co, n: c["hoodie_dark"])
    pz0, pz1 = hem_z + 0.07, hem_z + 0.21
    pocket = garment(body, "pocket", lambda co: co.y > 0.05 and abs(co.x) < 0.16 and pz0 - 0.04 < co.z < pz1 + 0.04
                     and torso(co), lift(0.006),
                     cuts=[((0, 0, pz0), (0, 0, 1), None), ((0, 0, pz1), (0, 0, -1), None),
                           ((0.12, 0, 0), (-1, 0, 0), None), ((-0.12, 0, 0), (1, 0, 0), None)])
    paint(pocket, lambda co, n: c["hoodie_pocket"] if pz0 + 0.012 < co.z < pz1 - 0.012 and abs(co.x) < 0.108
          else c["hoodie_dark"])

    # ---- Jeans: baggy straight legs with rolled cuffs.
    waist_z, cuff_z = H * 0.56, 0.075
    legs = lambda co: not L.is_arm(co) and abs(co.x) < H * 0.2  # noqa: E731

    def jeans_offset(co):
        return 0.012 + 0.03 * max(0.0, (H * 0.3 - co.z) / (H * 0.3))

    jeans = garment(body, "jeans", lambda co: cuff_z - 0.04 < co.z < waist_z and legs(co), jeans_offset, keep=0.5,
                    cuts=[((0, 0, cuff_z), (0, 0, 1), None)])
    paint(jeans, lambda co, n: c["pants"])

    cuffs = garment(body, "cuffs", lambda co: cuff_z - 0.04 < co.z < cuff_z + 0.09 and legs(co),
                    lambda co: 0.05, cuts=[((0, 0, cuff_z), (0, 0, 1), None),
                                           ((0, 0, cuff_z + 0.05), (0, 0, -1), None)])
    paint(cuffs, lambda co, n: c["pants_light"])

    # ---- Sneakers.
    shoes = garment(body, "shoes", lambda co: co.z < 0.16 and legs(co), lambda co: 0.013,
                    cuts=[((0, 0, 0.12), (0, 0, -1), None)], subdivide=1)

    paint(shoes, lambda co, n: c["shoe"])
    # Colored heel counters and toe caps as crisp overlay pieces.
    accents = []
    for side in (1, -1):
        ay = L.leg[side]["ankle"].y
        foot = lambda co, side=side: legs(co) and co.x * side > 0 and co.z < 0.13  # noqa: E731
        heel = garment(body, "heel", lambda co, f=foot, ay=ay: f(co) and co.y < ay, lambda co: 0.017,
                       cuts=[((0, ay - 0.025, 0), (0, -1, 0), None), ((0, 0, 0.1), (0, 0, -1), None),
                             ((0, 0, 0.02), (0, 0, 1), None)])
        toe = garment(body, "toe", lambda co, f=foot, ay=ay: f(co) and co.y > ay + 0.04, lambda co: 0.017,
                      cuts=[((0, ay + 0.075, 0), (0, 1, 0), None), ((0, 0, 0.05), (0, 0, -1), None),
                            ((0, 0, 0.02), (0, 0, 1), None)])
        for g in (heel, toe):
            paint(g, lambda co, n: c["shoe_accent"])
        accents += [heel, toe]
    soles = garment(body, "soles", lambda co: co.z < 0.05 and legs(co), lambda co: 0.02,
                    cuts=[((0, 0, 0.022), (0, 0, -1), None)])
    paint(soles, lambda co, n: c["sole"])

    hands = replace_hands(body, L, c["skin"])
    garments = [hoodie, hem, sleeve_cuffs, pocket, jeans, cuffs, shoes, soles] + accents
    for g in garments:
        copy_weights(g, body)

    # ---- Hood lying behind the neck, and drawstrings.
    bm = bmesh.new()
    ring = []
    for k in range(13):
        a = math.radians(-130 + k * (260 / 12))
        ring.append(L.neck + Vector((0.1 * math.sin(a), -0.075 * math.cos(a) - 0.01, -0.035 - 0.02 * math.cos(a))))
    for a, b in zip(ring, ring[1:]):
        add_capsule(bm, a, b, 0.036, 0.036)
    add_ellipsoid(bm, L.neck + Vector((0, -0.11, -0.07)), (0.12, 0.045, 0.075))
    hood = new_object("hood", bm)
    remesh_and_smooth(hood, voxel=0.008, smooth_repeat=6)
    paint(hood, lambda co, n: c["hoodie_dark"] if n.y > 0.2 else c["hoodie"])
    set_weights(hood, lambda co: {"UpperChest": 0.7, "Neck": 0.3})

    strings = []
    for s in (1, -1):
        pts = []
        for k in range(8):
            z = neck_z - 0.02 - k * 0.018
            pts.append(face_point(0.035 * s, z) + Vector((0, 0.004, 0)))
        strings.append(tube("string", pts, 0.0045, c["string"]))
        strings.append(tube("aglet", [pts[-1], pts[-1] + Vector((0, 0.001, -0.02))], 0.005, c["hoodie_dark"]))
    for st in strings:
        set_weights(st, lambda co: {"UpperChest": 0.5, "Chest": 0.5})

    # ---- Curly hair, with curls falling over the forehead.
    hair = curly_hair(L, c["hair"], c["hair_alt"], fringe=0.25)
    set_weights(hair, lambda co: {"Head": 1.0})
    for p in face:
        set_weights(p, lambda co: {"Head": 1.0})

    # Remove skin that the clothes completely hide.
    def covered(co):
        if L.is_arm(co):
            return arm_t(co) < WRIST_T - 0.02
        return (co.z < 0.1 or 0.14 < co.z < H * 0.76) and abs(co.x) < H * 0.16
    hide_covered(body, covered)

    join(garments + hands + [hood, hair] + strings + face, body)
    export(name, body, rig, HERE)


if __name__ == "__main__":
    only = sys.argv[-1] if sys.argv[-1] in OUTFITS else None
    for outfit, colors in OUTFITS.items():
        if only in (None, outfit):
            build(outfit, colors)
