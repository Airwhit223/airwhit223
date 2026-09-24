"""The Egyptian queen rebuilt on the Meshy female base (bases/female_base_meshy.glb).

Run with Blender 5.x:
    blender --background --python characters/build_queen_meshy.py
or with the bpy pip module (Python 3.13):
    python characters/build_queen_meshy.py
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from base_character import (  # noqa: E402
    DARK, WHITE, Landmarks, Matrix, Vector, add_capsule, add_ellipsoid, anime_eyes, apply_modifiers,
    arm_band, auto_weight, blob, bmesh, bpy, build_rig, copy_weights, export, face_point, garment,
    hide_covered, join, load_base, new_object, paint, remesh_and_smooth, replace_hands, reset_scene,
    ring_skirt, sandal_straps, select_only, set_weights, skirt_weights, srgb, WRIST_T,
)

BASE = os.path.join(HERE, "..", "bases", "female_base_meshy.glb")
HEIGHT = 1.68
NAME = "egyptian_queen_meshy"

SKIN = srgb(0.74, 0.52, 0.36)
PURPLE = srgb(0.42, 0.24, 0.6)
PURPLE_DARK = srgb(0.3, 0.16, 0.45)
GOLD = srgb(0.93, 0.74, 0.3)
GOLD_DARK = srgb(0.72, 0.52, 0.18)
TURQUOISE = srgb(0.2, 0.75, 0.72)
HAIR = srgb(0.08, 0.07, 0.09)
HAIR_GOLD = srgb(0.85, 0.66, 0.3)
IRIS = srgb(0.16, 0.6, 0.62)
LIPS = srgb(0.62, 0.34, 0.3)


def torso_slice(L, z, band=0.012):
    pts = [v for v in L.verts if abs(v.z - z) < band and not L.is_arm(v) and abs(v.x) < L.H * 0.16]
    xs, ys = [p.x for p in pts], [p.y for p in pts]
    return min(xs), max(xs), min(ys), max(ys)


def build():
    reset_scene()
    body = load_base(BASE, HEIGHT)
    L = Landmarks(body, HEIGHT)
    H, c, r = L.H, L.head_center, L.head_radius
    paint(body, lambda co, n: SKIN)

    # ---- Face: big teal eyes with a kohl wing, lips.
    face = anime_eyes(L, IRIS, size=1.1, lashes=1.5, brow_tilt=-0.1)
    ez = c.z - r.z * 0.12
    for s in (1, -1):
        p = face_point(c.x + 0.07 * s, ez + 0.014)
        face.append(blob("wing", p + Vector((0, -0.002, 0)), (0.014, 0.004, 0.003), DARK,
                         rot=Matrix.Rotation(-0.4 * s, 4, "Y")))
    mouth = face_point(c.x, ez - r.z * 0.55)
    face.append(blob("lips", mouth + Vector((0, -0.002, 0)), (0.016, 0.005, 0.005), LIPS))

    rig = build_rig(NAME, L)
    auto_weight(body, rig)
    hands = replace_hands(body, L, SKIN)
    straps = sandal_straps(L, GOLD, top=H * 0.18)
    torso = lambda co: not L.is_arm(co) and abs(co.x) < H * 0.16  # noqa: E731

    # ---- Top: a purple bandeau over the bust with gold trim and a gem.
    t0, t1 = H * 0.655, H * 0.745
    top = garment(body, "top", lambda co: t0 - 0.03 < co.z < t1 + 0.03 and torso(co), lambda co: 0.008,
                  cuts=[((0, 0, t0), (0, 0, 1), None), ((0, 0, t1), (0, 0, -1), None)])
    paint(top, lambda co, n: PURPLE)
    trims = []
    for z0, z1 in ((t0, t0 + 0.014), (t1 - 0.014, t1)):
        band = garment(body, "trim", lambda co, z0=z0, z1=z1: z0 - 0.03 < co.z < z1 + 0.03 and torso(co),
                       lambda co: 0.011, cuts=[((0, 0, z0), (0, 0, 1), None), ((0, 0, z1), (0, 0, -1), None)])
        paint(band, lambda co, n: GOLD)
        trims.append(band)

    # ---- Belt low on the hips.
    b0, b1 = H * 0.515, H * 0.545
    belt = garment(body, "belt", lambda co: b0 - 0.03 < co.z < b1 + 0.03 and torso(co), lambda co: 0.014,
                   cuts=[((0, 0, b0), (0, 0, 1), None), ((0, 0, b1), (0, 0, -1), None)])
    paint(belt, lambda co, n: GOLD)

    # ---- Upper-arm bands and bracers.
    bands = [arm_band(body, L, "armband", 0.17, 0.23, 0.01, GOLD),
             arm_band(body, L, "bracer", 0.42, WRIST_T, 0.009, GOLD),
             arm_band(body, L, "bracer_gem", 0.5, 0.53, 0.013, TURQUOISE)]

    soles = garment(body, "soles", lambda co: co.z < 0.05 and not L.is_arm(co), lambda co: 0.01,
                    cuts=[((0, 0, 0.018), (0, 0, -1), None)])
    paint(soles, lambda co, n: GOLD_DARK)

    fitted = [top, belt, soles] + trims + bands + straps
    for g in fitted:
        if g is belt:
            set_weights(g, lambda co: {"Hips": 1.0})  # a belt stays on the hips
        else:
            copy_weights(g, body)

    gems = [blob("gem", face_point(0.0, (t0 + t1) / 2 - 0.01) + Vector((0, 0.004, 0)), (0.014, 0.006, 0.02), TURQUOISE),
            blob("buckle", face_point(0.0, (b0 + b1) / 2) + Vector((0, 0.006, 0)), (0.026, 0.008, 0.02), GOLD_DARK),
            blob("buckle_gem", face_point(0.0, (b0 + b1) / 2) + Vector((0, 0.012, 0)), (0.012, 0.005, 0.012), TURQUOISE)]
    set_weights(gems[0], lambda co: {"Chest": 1.0})
    for g in gems[1:]:
        set_weights(g, lambda co: {"Hips": 1.0})

    # ---- Split skirt with a detailed front panel.
    skirt_top = b0 + 0.005
    x0, x1, y0, y1 = torso_slice(L, skirt_top)
    center = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
    top_r = ((x1 - x0) / 2 + 0.018, (y1 - y0) / 2 + 0.018)
    hem_r = (top_r[0] + 0.12, top_r[1] + 0.13)
    hem = lambda th: 0.12 + 0.09 * abs(math.sin(th * 3.0))  # noqa: E731
    gaps = [(math.radians(55), math.radians(18)), (math.radians(125), math.radians(18))]
    panel_half, border = 0.34, 0.05

    def gap_dist(th, t):
        return min(abs((th - g + math.pi) % math.tau - math.pi) - w * min(1.0, 0.25 + t * 1.2)
                   for g, w in gaps)

    def skirt_color(th, t, co):
        if t < 0.035 or t > 0.945 or gap_dist(th, t) < 0.06:
            return GOLD
        return PURPLE_DARK if math.sin(th) < -0.3 else PURPLE

    in_panel = lambda th: abs(th - math.pi / 2) < panel_half  # noqa: E731
    edge_rows = [0.0, 0.035, 0.045, 0.935, 0.945, 1.0]
    skirt = ring_skirt(center, skirt_top, top_r, hem, hem_r, skirt_color, gaps=gaps, segs=128,
                       rows=edge_rows + [i / 14 for i in range(1, 14)],
                       keep=lambda th, t: not in_panel(th))

    def panel_color(th, t, co):
        d = abs(th - math.pi / 2)
        if t < 0.035 or t > 0.945 or d > panel_half - border:
            return GOLD
        u = d / (panel_half - border)
        phase = (t * 6.0) % 1.0
        if u / 0.5 + abs(phase - 0.5) / 0.32 < 1:
            return TURQUOISE
        if u / 0.62 + abs(phase - 0.5) / 0.42 < 1:
            return GOLD
        return PURPLE
    panel = ring_skirt(center, skirt_top, (top_r[0] + 0.004, top_r[1] + 0.004), hem,
                       (hem_r[0] + 0.004, hem_r[1] + 0.004), panel_color, segs=400,
                       rows=edge_rows + [i / 44 for i in range(1, 44)],
                       keep=lambda th, t: in_panel(th))
    for sk in (skirt, panel):
        set_weights(sk, skirt_weights(L, skirt_top))

    # ---- Usekh collar: follows the shoulders and upper chest around the neck.
    nz = L.neck.z + 0.01
    _, _, ny0, ny1 = torso_slice(L, nz, band=0.02)
    neck_pt = Vector((0.0, (ny0 + ny1) / 2, nz))

    def collar_dist(co):
        d = co - neck_pt
        return math.hypot(d.x / 1.15, d.y, d.z * 1.3)
    collar = garment(body, "collar", lambda co: collar_dist(co) < 0.2 and co.z < nz + 0.02 and not L.is_arm(co)
                     and co.z > t1 - 0.02, lambda co: 0.013, cuts=[((0, 0, nz), (0, 0, -1), None)])

    def collar_color(co, n):
        band = int((collar_dist(co) - 0.05) / 0.022)
        return TURQUOISE if band in (2, 4) else GOLD if band % 2 == 0 else GOLD_DARK
    paint(collar, collar_color)
    copy_weights(collar, body)

    # ---- Long wavy black hair with gold streaks.
    bm = bmesh.new()
    crown = (r.x * 1.1, r.y * 0.98, r.z * 1.08)
    crown_c = c + Vector((0, -r.y * 0.14, 0.014))
    add_ellipsoid(bm, crown_c, crown)
    add_ellipsoid(bm, c + Vector((0, r.y * 0.45, r.z * 0.62)), (r.x * 0.85, r.y * 0.5, r.z * 0.35))
    back_y = c.y - r.y * 0.75
    for k in range(9):
        z = c.z - k * (c.z - H * 0.6) / 8
        w = r.x * (1.0 + 0.3 * math.sin(k * 0.9)) + k * 0.008
        add_ellipsoid(bm, (c.x, back_y - k * 0.012, z), (w, 0.07, 0.075))
        for s in (1, -1):
            wave = 0.02 * math.sin(k * 1.7 + (0.5 if s > 0 else 0))
            add_ellipsoid(bm, (c.x + s * (w * 0.8 + wave), back_y + 0.01 - k * 0.008, z - 0.02), (0.052, 0.052, 0.06))
    for s in (1, -1):
        for k in range(8):
            z = c.z - 0.02 - k * 0.055
            x = r.x * 0.85 + k * 0.012 + 0.012 * math.sin(k * 1.9)
            add_ellipsoid(bm, (c.x + s * x, c.y + 0.02 + 0.004 * k, z), (0.045, 0.043, 0.048))
    hair = new_object("hair", bm)
    remesh_and_smooth(hair, voxel=0.009, smooth_repeat=10)
    dec = hair.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, 3500 / max(1, len(hair.data.polygons)))
    apply_modifiers(hair)
    bpy.ops.object.shade_smooth()
    paint(hair, lambda co, n: HAIR_GOLD if abs(co.x - c.x) > r.x * 0.75 and co.y > back_y + 0.05
          and math.sin(co.z * 22.0 + abs(co.x) * 60.0) > 0.9 else HAIR)

    def hair_weights(co):
        if co.z > L.chin_z:
            return {"Head": 1.0}
        if co.z > L.neck.z - 0.12:
            t = (L.chin_z - co.z) / (L.chin_z - L.neck.z + 0.12)
            return {"Head": 1.0 - t, "UpperChest": t}
        return {"UpperChest": 0.6, "Chest": 0.4}
    set_weights(hair, hair_weights)

    # ---- Cobra headband and earrings.
    bm = bmesh.new()
    ring = Matrix.Translation(crown_c + Vector((0, 0, crown[2] * 0.45))) @ Matrix.Rotation(math.radians(-16), 4, "X")
    band_scale = math.sqrt(1 - 0.45 ** 2) * 1.01
    for j in range(56):
        th = j / 56 * math.tau
        p = ring @ Vector((crown[0] * band_scale * math.cos(th), crown[1] * band_scale * math.sin(th), 0.0))
        add_ellipsoid(bm, p, (0.012, 0.012, 0.014))
    front = ring @ Vector((0, crown[1] * band_scale, 0)) + Vector((0, 0.02, 0))
    add_capsule(bm, front, front + Vector((0, 0.008, 0.055)), 0.012, 0.01)
    add_ellipsoid(bm, front + Vector((0, 0.009, 0.05)), (0.024, 0.009, 0.028))
    add_ellipsoid(bm, front + Vector((0, 0.016, 0.082)), (0.01, 0.013, 0.009))
    ear_z = c.z - r.z * 0.4
    for s in (1, -1):
        add_ellipsoid(bm, (c.x + s * r.x * 0.97, c.y, ear_z), (0.007, 0.007, 0.009))
        add_ellipsoid(bm, (c.x + s * r.x * 0.99, c.y, ear_z - 0.035), (0.01, 0.005, 0.019))
    piece = new_object("headpiece", bm)
    remesh_and_smooth(piece, voxel=0.004, smooth_repeat=2)
    dec = piece.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, 1800 / max(1, len(piece.data.polygons)))
    apply_modifiers(piece)
    bpy.ops.object.shade_smooth()
    paint(piece, lambda co, n: TURQUOISE if co.z < ear_z - 0.02 else GOLD)
    for p in [piece, *face]:
        set_weights(p, lambda co: {"Head": 1.0})

    def covered(co):
        return torso(co) and (t0 + 0.01 < co.z < t1 - 0.01 or b0 + 0.005 < co.z < b1 - 0.005)
    hide_covered(body, covered)

    join(fitted + hands + gems + [collar, skirt, panel, hair, piece] + face, body)
    export(NAME, body, rig, HERE)


if __name__ == "__main__":
    build()
