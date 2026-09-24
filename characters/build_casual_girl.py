"""Casual girl in a cropped denim jacket, tank top, pleated skirt, knee socks
and sneakers, with a high ponytail. Built on the Meshy female base.

Run with Blender 5.x:
    blender --background --python characters/build_casual_girl.py
or with the bpy pip module (Python 3.13):
    python characters/build_casual_girl.py

OUTFITS holds color schemes; each one is exported as its own character.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from base_character import (  # noqa: E402
    WRIST_T, Landmarks, Vector, add_capsule, add_ellipsoid, anime_eyes, apply_modifiers, auto_weight,
    blob, bmesh, bpy, build_rig, copy_weights, export, face_point, garment, hide_covered, join,
    load_base, new_object, paint, remesh_and_smooth, replace_hands, reset_scene, ring_skirt,
    set_weights, skirt_weights, sneakers, srgb,
)

BASE = os.path.join(HERE, "..", "bases", "female_base_meshy.glb")
HEIGHT = 1.65

OUTFITS = {
    "casual_girl": dict(
        skin=srgb(0.96, 0.82, 0.7), iris=srgb(0.55, 0.35, 0.2), lips=srgb(0.85, 0.5, 0.5),
        hair=srgb(0.36, 0.2, 0.12), hair_alt=srgb(0.5, 0.3, 0.17), tie=srgb(0.75, 0.2, 0.25),
        tank=srgb(0.97, 0.96, 0.94), jacket=srgb(0.56, 0.7, 0.88), jacket_dark=srgb(0.42, 0.55, 0.76),
        skirt=srgb(0.6, 0.17, 0.22), skirt_dark=srgb(0.45, 0.11, 0.16), socks=srgb(0.97, 0.96, 0.94),
        sock_stripe=srgb(0.6, 0.17, 0.22), shoe=srgb(0.97, 0.96, 0.94), shoe_accent=srgb(0.6, 0.17, 0.22),
        sole=srgb(0.95, 0.94, 0.9)),
}


def torso_slice(L, z, band=0.012):
    pts = [v for v in L.verts if abs(v.z - z) < band and not L.is_arm(v) and abs(v.x) < L.H * 0.16]
    return min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts), max(p.y for p in pts)


def build(name, c):
    reset_scene()
    body = load_base(BASE, HEIGHT)
    L = Landmarks(body, HEIGHT)
    H, hc, hr = L.H, L.head_center, L.head_radius
    paint(body, lambda co, n: c["skin"])

    face = anime_eyes(L, c["iris"], size=1.15, lashes=1.4, brow_tilt=-0.05)
    ez = hc.z - hr.z * 0.12
    mouth = face_point(hc.x, ez - hr.z * 0.55)
    face.append(blob("lips", mouth + Vector((0, -0.002, 0)), (0.013, 0.004, 0.004), c["lips"]))

    rig = build_rig(name, L)
    auto_weight(body, rig)
    hands = replace_hands(body, L, c["skin"])
    torso = lambda co: not L.is_arm(co) and abs(co.x) < H * 0.16  # noqa: E731
    _, _, cy0, cy1 = torso_slice(L, H * 0.7)
    front_y = (cy0 + cy1) / 2

    def arm_t(co):
        return L.arm_param(co, 1 if co.x > 0 else -1)[0]

    def sleeve(co):
        t, d = L.arm_param(co, 1 if co.x > 0 else -1)
        return (L.is_arm(co) or (abs(co.x) > H * 0.08 and d < 0.1)) and t < WRIST_T + 0.04

    # ---- Tank top with thin straps.
    tank_top = H * 0.765
    strap = lambda co: 0.045 < abs(co.x) < 0.085  # noqa: E731
    tank = garment(body, "tank", lambda co: torso(co) and H * 0.58 < co.z < L.neck.z
                   and (co.z < tank_top + 0.03 or strap(co)), lambda co: 0.007,
                   cuts=[((0, 0, tank_top), (0, 0, -1), lambda co: not strap(co)),
                         ((0.045, 0, 0), (1, 0, 0), lambda co: co.z > tank_top and co.x > 0),
                         ((-0.045, 0, 0), (-1, 0, 0), lambda co: co.z > tank_top and co.x < 0),
                         ((0.085, 0, 0), (-1, 0, 0), lambda co: co.z > tank_top and co.x > 0),
                         ((-0.085, 0, 0), (1, 0, 0), lambda co: co.z > tank_top and co.x < 0)])
    paint(tank, lambda co, n: c["tank"])

    # ---- Cropped jacket, open at the front.
    jacket_hem = H * 0.645
    wrist_cuts, cuff_cuts = [], []
    for side in (1, -1):
        a = L.arm[side]
        up = (a["elbow"] - a["wrist"]).normalized()
        on = lambda co, side=side: co.x * side > 0 and L.is_arm(co) and arm_t(co) > 0.4  # noqa: E731
        wrist_cuts.append((a["wrist"], up, on))
        cuff_cuts += [(a["wrist"], up, lambda co, side=side: co.x * side > 0),
                      (a["wrist"] + up * 0.045, -up, lambda co, side=side: co.x * side > 0)]
    opening = 0.075

    def jacket_region(co):
        if sleeve(co):
            return True
        return jacket_hem - 0.04 < co.z < L.neck.z - 0.01 and torso(co)

    def jacket_offset(co):
        return 0.02 if L.is_arm(co) else 0.024

    front_only = lambda sign: lambda co: not L.is_arm(co) and co.y > front_y and co.x * sign > 0  # noqa: E731
    jacket = garment(body, "jacket", jacket_region, jacket_offset,
                     cuts=[((0, 0, jacket_hem), (0, 0, 1), torso),
                           ((opening, 0, 0), (1, 0, 0), front_only(1)),
                           ((-opening, 0, 0), (-1, 0, 0), front_only(-1))] + wrist_cuts)
    paint(jacket, lambda co, n: c["jacket"])
    lift = lambda extra: lambda co: jacket_offset(co) + extra  # noqa: E731
    jacket_cuffs = garment(body, "jacket_cuffs", lambda co: sleeve(co) and arm_t(co) > WRIST_T - 0.1, lift(0.004),
                           cuts=cuff_cuts)
    paint(jacket_cuffs, lambda co, n: c["jacket_dark"])
    waistband = garment(body, "jacket_band", lambda co: jacket_hem - 0.04 < co.z < jacket_hem + 0.08 and torso(co),
                        lift(0.004), cuts=[((0, 0, jacket_hem), (0, 0, 1), None),
                                           ((0, 0, jacket_hem + 0.04), (0, 0, -1), None),
                                           ((opening, 0, 0), (1, 0, 0), front_only(1)),
                                           ((-opening, 0, 0), (-1, 0, 0), front_only(-1))])
    paint(waistband, lambda co, n: c["jacket_dark"])
    collar = garment(body, "jacket_collar", lambda co: L.neck.z - 0.09 < co.z < L.neck.z + 0.02 and torso(co)
                     and not (co.y > front_y and abs(co.x) < opening + 0.01), lambda co: 0.034,
                     cuts=[((0, 0, L.neck.z - 0.05), (0, 0, 1), None), ((0, 0, L.neck.z + 0.005), (0, 0, -1), None)])
    paint(collar, lambda co, n: c["jacket_dark"])

    # ---- Knee socks with a stripe, and sneakers.
    s0, s1 = 0.1, H * 0.25
    legs = lambda co: not L.is_arm(co) and abs(co.x) < H * 0.2  # noqa: E731
    socks = garment(body, "socks", lambda co: s0 - 0.03 < co.z < s1 + 0.03 and legs(co), lambda co: 0.006,
                    cuts=[((0, 0, s0), (0, 0, 1), None), ((0, 0, s1), (0, 0, -1), None)])
    paint(socks, lambda co, n: c["socks"])
    stripes = []
    for z0 in (s1 - 0.035, s1 - 0.065):
        band = garment(body, "sock_stripe", lambda co, z0=z0: z0 - 0.03 < co.z < z0 + 0.045 and legs(co),
                       lambda co: 0.009, cuts=[((0, 0, z0), (0, 0, 1), None), ((0, 0, z0 + 0.015), (0, 0, -1), None)])
        paint(band, lambda co, n: c["sock_stripe"])
        stripes.append(band)
    shoes = sneakers(body, L, c["shoe"], c["shoe_accent"], c["sole"])

    fitted = [tank, jacket, jacket_cuffs, waistband, collar, socks] + stripes + shoes
    for g in fitted:
        copy_weights(g, body)

    # ---- Pleated mini skirt.
    skirt_top = H * 0.6
    x0, x1, y0, y1 = torso_slice(L, skirt_top)
    center = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
    top_r = ((x1 - x0) / 2 + 0.02, (y1 - y0) / 2 + 0.02)

    def skirt_color(th, t, co):
        if t < 0.06:
            return c["skirt_dark"]  # waistband
        return c["skirt_dark"] if math.cos(th * 18) < -0.55 else c["skirt"]
    skirt = ring_skirt(center, skirt_top, top_r, H * 0.43, (top_r[0] + 0.15, top_r[1] + 0.15), skirt_color,
                       pleats=18, pleat_depth=0.07, segs=144, rows=[0, 0.06, 0.07] + [i / 12 for i in range(1, 13)])
    set_weights(skirt, skirt_weights(L, skirt_top))

    # ---- Hair: side-swept bangs, chin-length side locks and a high ponytail.
    bm = bmesh.new()
    crown = (hr.x * 1.1, hr.y * 0.98, hr.z * 1.08)
    crown_c = hc + Vector((0, -hr.y * 0.14, 0.014))
    add_ellipsoid(bm, crown_c, crown)
    add_ellipsoid(bm, hc + Vector((hr.x * 0.15, hr.y * 0.5, hr.z * 0.6)), (hr.x * 0.9, hr.y * 0.45, hr.z * 0.33))
    for k in range(5):
        x = hr.x * (-0.55 + k * 0.28)
        add_ellipsoid(bm, hc + Vector((x, hr.y * 0.72, hr.z * (0.42 - 0.08 * math.sin(k * 1.3)))),
                      (hr.x * 0.2, hr.y * 0.2, hr.z * 0.28))
    for s in (1, -1):
        for k in range(4):
            add_ellipsoid(bm, hc + Vector((s * hr.x * (0.9 + 0.03 * k), hr.y * 0.35, -hr.z * 0.25 * k)),
                          (0.035, 0.035, 0.05))
    tail = [crown_c + Vector((0, -crown[1] * 0.8, crown[2] * 0.55)),
            crown_c + Vector((0, -crown[1] * 1.08, crown[2] * 0.3)),
            crown_c + Vector((0, -crown[1] * 1.12, -crown[2] * 0.35)),
            crown_c + Vector((0, -crown[1] * 1.02, -crown[2] * 1.15)),
            crown_c + Vector((0, -crown[1] * 0.92, -crown[2] * 1.9))]
    radii = [0.045, 0.06, 0.062, 0.048, 0.018]
    for p, q, ra, rb in zip(tail, tail[1:], radii, radii[1:]):
        add_capsule(bm, p, q, ra, rb)
    hair = new_object("hair", bm)
    remesh_and_smooth(hair, voxel=0.008, smooth_repeat=8)
    dec = hair.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, 3500 / max(1, len(hair.data.polygons)))
    apply_modifiers(hair)
    bpy.ops.object.shade_smooth()
    paint(hair, lambda co, n: c["hair_alt"] if n.z > 0.55 and math.sin(co.x * 70) > 0.3 else c["hair"])
    set_weights(hair, lambda co: {"Head": 1.0})

    tie = blob("hair_tie", tail[0].lerp(tail[1], 0.3), (0.05, 0.03, 0.05), c["tie"])
    set_weights(tie, lambda co: {"Head": 1.0})
    for p in face:
        set_weights(p, lambda co: {"Head": 1.0})

    def covered(co):
        if torso(co):
            return H * 0.62 < co.z < tank_top - 0.01
        return s0 + 0.02 < co.z < s1 - 0.02 and legs(co)
    hide_covered(body, covered)

    join(fitted + hands + [skirt, hair, tie] + face, body)
    export(name, body, rig, HERE)


if __name__ == "__main__":
    for outfit, colors in OUTFITS.items():
        build(outfit, colors)
