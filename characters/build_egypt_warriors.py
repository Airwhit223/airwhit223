"""Egyptian warrior NPCs: Anubis guard, bald axe warrior and archer.

Run with Blender 5.x:
    blender --background --python characters/build_egypt_warriors.py [anubis] [warrior] [archer]
or with the bpy pip module (Python 3.13):
    python characters/build_egypt_warriors.py [anubis] [warrior] [archer]

Weapons (spear, axe, bow, quiver) are separate models in characters/weapons/.
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
    sandal_straps, select_only, set_weights, skirt_weights, srgb,
)
import build_beastfolk as bf  # noqa: E402

GOLD, GOLD_DARK, TURQUOISE = bf.GOLD, bf.GOLD_DARK, bf.TURQUOISE
BRONZE = srgb(0.78, 0.58, 0.3)
LINEN = srgb(0.95, 0.93, 0.87)
LEATHER = srgb(0.42, 0.26, 0.14)
TAN = srgb(0.78, 0.55, 0.37)

# Jackal head: a longer, narrower wolf muzzle and tall pointed ears.
bf.HEADS["jackal"] = dict(bf.HEADS["wolf"])
bf.HEADS["jackal"].update(
    blobs=[("e", (0, -0.05, 0.12), (0.88, 0.95, 0.88)),
           *[("e", c, (0.4, 0.4, 0.4)) for c in bf.mirror(0.5, 0.25, -0.35)],
           ("c", (0, 0.45, -0.15), (0, 1.65, -0.36), 0.36, 0.2),
           ("e", (0, 0.95, -0.5), (0.24, 0.6, 0.14)),
           *bf.NECK],
    cones=bf.ear_cones((0.42, -0.2, 0.7), (0.55, -0.3, 2.05), 0.62, 0.24),
    ear=((0.42, -0.2, 0.7), (0.55, -0.3, 2.05), 0.62),
    light=lambda lc, n: False,
    eye=(0.33, 0.62, 0.24), nose=(0, 1.72, -0.3, 0.12), iris=srgb(0.97, 0.78, 0.2))


def torso_fn(L):
    return lambda co: not L.is_arm(co) and abs(co.x) < L.H * 0.16


def legs_fn(L):
    return lambda co: not L.is_arm(co) and abs(co.x) < L.H * 0.2


def scales(co, n, base=GOLD, edge=GOLD_DARK, size=26.0):
    """Overlapping scale pattern for armor."""
    row = math.floor(co.z * size)
    u = co.x * size + (0.5 if row % 2 else 0.0)
    v = co.z * size - row
    du = (u - math.floor(u)) - 0.5
    return edge if v < 0.22 or (du * du) + (v - 0.9) ** 2 * 0.6 > 0.3 else base


def greaves(body, L, name, color, gem):
    """Shin guards from ankle to below the knee, with a gem at the front."""
    legs = legs_fn(L)
    z0, z1 = 0.1, L.leg[1]["knee"].z - 0.04
    g = garment(body, name, lambda co: z0 - 0.03 < co.z < z1 + 0.03 and legs(co), lambda co: 0.016,
                cuts=[((0, 0, z0), (0, 0, 1), None), ((0, 0, z1), (0, 0, -1), None)])

    def color_fn(co, n):
        side = 1 if co.x > 0 else -1
        k = L.leg[side]
        front = n.y > 0.5
        mid = (z0 + z1) / 2
        if front and abs(co.x - k["knee"].x) / 0.022 + abs(co.z - mid) / 0.05 < 1:
            return gem
        if abs(co.z - z0) < 0.015 or abs(co.z - z1) < 0.015:
            return GOLD_DARK
        return color
    paint(g, color_fn)
    knees = []
    dep = bpy.context.evaluated_depsgraph_get()
    for side in (1, -1):
        k = L.leg[side]["knee"]
        hit, loc, *_ = bpy.context.scene.ray_cast(dep, Vector((k.x, 2, k.z)), Vector((0, -1, 0)))
        p = (loc if hit else k) + Vector((0, 0.012, 0))
        knees.append(blob("knee", p, (0.045, 0.02, 0.05), color))
    return [g], knees


def sandals(body, L, strap_color):
    legs = legs_fn(L)
    soles = garment(body, "soles", lambda co: co.z < 0.05 and legs(co), lambda co: 0.012,
                    cuts=[((0, 0, 0.018), (0, 0, -1), None)])
    paint(soles, lambda co, n: strap_color)
    straps = sandal_straps(L, strap_color, top=0.1, turns=1.2, radius=0.006)
    return [soles] + straps


def belt(body, L, z0, z1, color, offset=0.02):
    torso = torso_fn(L)
    b = garment(body, "belt", lambda co: z0 - 0.03 < co.z < z1 + 0.03 and torso(co), lambda co: offset,
                cuts=[((0, 0, z0), (0, 0, 1), None), ((0, 0, z1), (0, 0, -1), None)])
    paint(b, lambda co, n: color)
    return b


def front_gem(z, color, size=0.02, depth=0.02):
    p = face_point(0.0, z) + Vector((0, depth * 0.5, 0))
    return blob("gem", p, (size, depth * 0.5, size * 0.8), color)


def skirt_ring(L, top_z):
    torso = torso_fn(L)
    pts = [v for v in L.verts if abs(v.z - top_z) < 0.012 and torso(v)]
    xs, ys = [p.x for p in pts], [p.y for p in pts]
    return (Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 0)),
            ((max(xs) - min(xs)) / 2 + 0.03, (max(ys) - min(ys)) / 2 + 0.03))


def finish(name, body, rig, parts, weights_from_body, rigid):
    """rigid: (obj, weight_fn) pairs."""
    for g in weights_from_body:
        copy_weights(g, body)
    for obj, fn in rigid:
        set_weights(obj, fn)
    join(parts, body)
    body.data.validate()
    body.data.materials.clear()
    body.data.materials.append(make_material(name))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL")
    print(f"{name}: {sum(len(p.vertices) - 2 for p in body.data.polygons)} triangles")


# --------------------------------------------------------------------------

def anubis():
    body, L = bf.base_setup("male")
    H = bf.HeadSpace(L)
    rig = build_rig("npc_anubis", L)
    auto_weight(body, rig)
    hands = replace_hands(body, L, bf.MASK0)
    head = bf.split_head(body, L)
    bpy.data.objects.remove(head)
    roots = bf.back_points(L)
    head_obj, face = bf.build_head("jackal", H, "male")
    tail = []  # the guard wears his tail tucked under the armor
    fur = srgb(0.1, 0.1, 0.11)
    for o in [body, head_obj, *hands]:
        bf.bake(o, fur, fur)
    torso, legs = torso_fn(L), legs_fn(L)

    # Nemes headdress: striped cap, lappets over the chest, and a back fall.
    nemes = bf.sculpt("nemes", H, [
        ("e", (0, -0.35, 0.6), (1.05, 1.0, 0.7)),
        ("e", (0, -0.7, -0.4), (0.95, 0.45, 1.0)),
        ("c", (0.85, -0.05, 0.1), (0.95, 0.25, -2.3), 0.34, 0.3),
        ("c", (-0.85, -0.05, 0.1), (-0.95, 0.25, -2.3), 0.34, 0.3)], voxel=0.007, smooth=4, faces=2500)
    paint(nemes, lambda co, n: TURQUOISE if int((H.local(co).z + 3) / 0.22) % 2 else GOLD)
    band = bf.sculpt("nemes_band", H, [("c", (x * 1.02, y, 0.28), (x2 * 1.02, y2, 0.28), 0.1, 0.1)
                                       for (x, y), (x2, y2) in zip(
                                           [(math.sin(a) * 0.98, math.cos(a) * 0.8 - 0.3) for a in
                                            [math.radians(d) for d in range(-110, 111, 20)]],
                                           [(math.sin(a) * 0.98, math.cos(a) * 0.8 - 0.3) for a in
                                            [math.radians(d) for d in range(-90, 131, 20)]])],
                       voxel=0.005, smooth=1, faces=1200)
    paint(band, lambda co, n: GOLD)

    # Gold scale armor: cuirass, pauldrons, armored skirt, belt.
    b0, b1 = L.H * 0.52, L.H * 0.56
    cuirass = garment(body, "cuirass", lambda co: b1 - 0.02 < co.z < L.neck.z - 0.02 and torso(co), lambda co: 0.024,
                      cuts=[((0, 0, b1), (0, 0, 1), None)], subdivide=1)
    front_y = sum(v.y for v in L.verts if abs(v.z - L.H * 0.65) < 0.02 and torso(v)) / max(
        1, len([v for v in L.verts if abs(v.z - L.H * 0.65) < 0.02 and torso(v)]))

    def cuirass_color(co, n):
        if co.y > front_y and n.y > 0.3:
            # Turquoise chevrons down the chest.
            v = (L.neck.z - co.z) * 12 - abs(co.x) * 18
            if abs(co.x) < 0.1 and (v % 1.0) < 0.3 and co.z < L.neck.z - 0.1:
                return TURQUOISE
        return scales(co, n)
    paint(cuirass, cuirass_color)
    collar, neck_pt = bf.egypt_collar(body, L, lambda b: TURQUOISE if b in (1, 3) else GOLD if b % 2 == 0
                                      else GOLD_DARK)
    pauldrons = []
    for side in (1, -1):
        sh = L.arm[side]["shoulder"]
        pauldrons.append(blob("pauldron", sh + Vector((0.04 * side, 0.0, 0.03)), (0.11, 0.11, 0.08), GOLD))
        paint(pauldrons[-1], lambda co, n: scales(co, n, size=34))
    belt_obj = belt(body, L, b0, b1, GOLD)
    center, top_r = skirt_ring(L, b0)
    front = math.pi / 2

    def skirt_color(th, t, co):
        d = abs(((th - front + math.pi) % math.tau) - math.pi)
        if d < 0.35:
            chev = (t * 6 - (d / 0.35) * 0.8) % 1.0
            return TURQUOISE if chev < 0.3 else GOLD
        if t > 0.92:
            return GOLD_DARK
        return scales(co, None, size=30)
    skirt = ring_skirt(center, b0 + 0.005, top_r, L.H * 0.3, (top_r[0] + 0.07, top_r[1] + 0.08), skirt_color,
                       segs=128, rows=[i / 20 for i in range(21)])
    bands = [arm_band(body, L, "armband", 0.16, 0.22, 0.014, GOLD),
             arm_band(body, L, "bracer", 0.4, WRIST_T, 0.016, GOLD)]
    for bnd in bands[1:]:
        paint(bnd, lambda co, n: scales(co, n, size=34))
    greave, knees = greaves(body, L, "greaves", GOLD, TURQUOISE)
    shoes = sandals(body, L, GOLD)
    gem = front_gem((b0 + b1) / 2, TURQUOISE, size=0.025)

    fitted = [cuirass, collar, belt_obj] + bands + greave + shoes
    rigid = [(head_obj, lambda co: {"Head": 1.0}), (face, lambda co: {"Head": 1.0}),
             (nemes, lambda co: {"Head": 1.0} if co.z > H.c.z - H.s else {"Head": 0.3, "UpperChest": 0.7}),
             (band, lambda co: {"Head": 1.0}), (skirt, skirt_weights(L, b0)), (gem, lambda co: {"Hips": 1.0})]
    for p in pauldrons:
        side = "Right" if p.location.x > 0 or sum(v.co.x for v in p.data.vertices) > 0 else "Left"
        rigid.append((p, lambda co, side=side: {side + "UpperArm": 0.6, "UpperChest": 0.4}))
    for k in knees:
        side = "Right" if sum(v.co.x for v in k.data.vertices) > 0 else "Left"
        rigid.append((k, lambda co, side=side: {side + "LowerLeg": 1.0}))
    parts = [head_obj, face, nemes, band, *hands, *tail, *fitted, *pauldrons, *knees, skirt, gem]
    finish("npc_anubis", body, rig, parts, fitted, rigid)


def warrior():
    body, L = bf.base_setup("male")
    paint(body, lambda co, n: TAN)
    face = anime_eyes(L, srgb(0.25, 0.18, 0.12), size=0.95, brow_tilt=0.25)
    rig = build_rig("npc_egypt_warrior", L)
    auto_weight(body, rig)
    hands = replace_hands(body, L, TAN)
    torso, legs = torso_fn(L), legs_fn(L)
    H = bf.HeadSpace(L)

    # White headband with knot tails at the back.
    z0, z1 = H.c.z + H.s * 0.3, H.c.z + H.s * 0.62
    headband = garment(body, "headband", lambda co: z0 - 0.03 < co.z < z1 + 0.03 and co.z > L.chin_z,
                       lambda co: 0.012, cuts=[((0, 0, z0), (0, 0, 1), None), ((0, 0, z1), (0, 0, -1), None)])
    paint(headband, lambda co, n: LINEN)
    knot = bf.sculpt("knot", H, [("e", (0.25, -1.0, 0.45), (0.25, 0.18, 0.2)),
                                 ("c", (0.3, -1.05, 0.35), (0.55, -1.2, -0.5), 0.14, 0.1),
                                 ("c", (0.2, -1.05, 0.35), (0.3, -1.25, -0.35), 0.13, 0.09)],
                     voxel=0.005, smooth=2, faces=900)
    paint(knot, lambda co, n: LINEN)

    # Bronze chest plate, collar, belt with a gem, white kilt with a front panel.
    b0, b1 = L.H * 0.53, L.H * 0.57
    plate = garment(body, "plate", lambda co: b1 - 0.02 < co.z < L.neck.z - 0.03 and torso(co), lambda co: 0.022,
                    cuts=[((0, 0, b1), (0, 0, 1), None)])

    def plate_color(co, n):
        if abs(co.x) < 0.008 and n.y > 0.3:
            return GOLD_DARK  # center ridge
        return BRONZE
    paint(plate, plate_color)
    collar, _ = bf.egypt_collar(body, L, lambda b: TURQUOISE if b in (1, 3) else GOLD if b % 2 == 0 else GOLD_DARK)
    sash = belt(body, L, b0 - 0.02, b0 + 0.015, LINEN, offset=0.026)
    belt_obj = belt(body, L, b0 + 0.015, b1, GOLD)
    center, top_r = skirt_ring(L, b0)
    front = math.pi / 2

    def kilt(th, t, co):
        return LINEN
    skirt = ring_skirt(center, b0, top_r, lambda th: L.H * 0.33 + 0.03 * math.sin(th * 5),
                       (top_r[0] + 0.08, top_r[1] + 0.09), kilt, pleats=10, pleat_depth=0.04, segs=128)

    def panel_color(th, t, co):
        d = abs(th - front)
        if d > 0.2 or t > 0.93:
            return GOLD
        return TURQUOISE if (t * 8) % 1.0 < 0.25 else GOLD_DARK
    panel = ring_skirt(center, b0, (top_r[0] + 0.012, top_r[1] + 0.02), L.H * 0.34,
                       (top_r[0] + 0.1, top_r[1] + 0.13), panel_color, segs=360,
                       rows=[i / 30 for i in range(31)], keep=lambda th, t: abs(th - front) < 0.26)
    gem = front_gem((b0 + b1) / 2 + 0.01, TURQUOISE, size=0.026)
    bands = [arm_band(body, L, "armband", 0.17, 0.23, 0.014, GOLD),
             arm_band(body, L, "bracer", 0.42, WRIST_T, 0.016, GOLD),
             arm_band(body, L, "bracer_line", 0.5, 0.53, 0.02, TURQUOISE)]
    greave, knees = greaves(body, L, "greaves", GOLD, TURQUOISE)
    shoes = sandals(body, L, LEATHER)

    fitted = [headband, plate, collar, sash, belt_obj] + bands + greave + shoes
    rigid = [(p, lambda co: {"Head": 1.0}) for p in face] + [
        (knot, lambda co: {"Head": 1.0}), (skirt, skirt_weights(L, b0)), (panel, lambda co: {"Hips": 1.0}),
        (gem, lambda co: {"Hips": 1.0})]
    for k in knees:
        side = "Right" if sum(v.co.x for v in k.data.vertices) > 0 else "Left"
        rigid.append((k, lambda co, side=side: {side + "LowerLeg": 1.0}))
    parts = [*face, knot, *hands, *fitted, *knees, skirt, panel, gem]
    finish("npc_egypt_warrior", body, rig, parts, fitted, rigid)


def archer():
    body, L = bf.base_setup("female")
    paint(body, lambda co, n: TAN)
    face = anime_eyes(L, srgb(0.2, 0.16, 0.14), size=1.12, lashes=1.4, brow_tilt=0.05)
    rig = build_rig("npc_egypt_archer", L)
    auto_weight(body, rig)
    hands = replace_hands(body, L, TAN)
    torso, legs = torso_fn(L), legs_fn(L)
    H = bf.HeadSpace(L)

    # Black bob with bangs, lifted off the head's surface.
    def bob(co):
        lc = H.local(co)
        if lc.y > 0.3 and lc.z < 0.4:
            return False
        return co.z > L.chin_z + 0.01 and (lc.z > -0.15 or lc.y < 0.35)
    hair = garment(body, "hair", bob, lambda co: 0.03 if H.local(co).z > -0.2 else 0.04)
    fringe = bf.sculpt("fringe", H, [("e", (x, 0.72, 0.5), (0.3, 0.2, 0.28)) for x in (-0.45, -0.15, 0.15, 0.45)],
                       voxel=0.005, smooth=3, faces=900)
    for h in (hair, fringe):
        paint(h, lambda co, n: srgb(0.06, 0.06, 0.08))
    # Gold circlet with a turquoise gem.
    bm = bmesh.new()
    ring = Matrix.Translation(H.c + Vector((0, -0.01, H.s * 0.5))) @ Matrix.Rotation(math.radians(-12), 4, "X")
    for j in range(48):
        th = j / 48 * math.tau
        add_ellipsoid(bm, ring @ Vector((H.s * 1.05 * math.cos(th), H.s * 1.08 * math.sin(th), 0)),
                      (0.009, 0.009, 0.011))
    circlet = new_object("circlet", bm)
    remesh_and_smooth(circlet, voxel=0.004, smooth_repeat=1)
    bf.limit(circlet, 800)
    paint(circlet, lambda co, n: GOLD)
    cgem = blob("circlet_gem", ring @ Vector((0, H.s * 1.1, 0)), (0.018, 0.01, 0.022), TURQUOISE)

    # White wrap dress with a V neckline, gold belt, purple sash.
    front_y = sum(v.y for v in L.verts if abs(v.z - L.H * 0.65) < 0.02 and torso(v)) / max(
        1, len([v for v in L.verts if abs(v.z - L.H * 0.65) < 0.02 and torso(v)]))
    vz = L.neck.z - 0.2

    def top_region(co):
        if not (L.H * 0.58 < co.z < L.neck.z - 0.02 and torso(co)):
            return False
        if co.y > front_y and co.z > vz and abs(co.x) < (co.z - vz) * 0.55:
            return False  # V neckline
        return True
    dress_top = garment(body, "dress_top", top_region, lambda co: 0.012)
    paint(dress_top, lambda co, n: LINEN)
    collar, _ = bf.egypt_collar(body, L, lambda b: TURQUOISE if b in (1, 3) else GOLD if b % 2 == 0 else GOLD_DARK)
    b0, b1 = L.H * 0.585, L.H * 0.61
    belt_obj = belt(body, L, b0, b1, GOLD, offset=0.018)
    center, top_r = skirt_ring(L, b0)
    skirt = ring_skirt(center, b0, top_r, lambda th: L.H * 0.36 + 0.035 * math.sin(th * 3 + 1),
                       (top_r[0] + 0.1, top_r[1] + 0.1), lambda th, t, co: LINEN, pleats=12, pleat_depth=0.05,
                       segs=128)
    # Purple sash hanging from her right hip.
    hip = Vector((top_r[0] * 0.9 + center.x, center.y + 0.02, b0))
    bm = bmesh.new()
    add_ellipsoid(bm, hip + Vector((0.02, 0.01, 0)), (0.05, 0.035, 0.035))
    for k in range(6):
        t = k / 5
        add_ellipsoid(bm, hip + Vector((0.05 + 0.02 * t, 0.02 + 0.02 * math.sin(t * 3), -0.06 - 0.36 * t)),
                      (0.05 - 0.01 * t, 0.015, 0.05))
    sash = new_object("sash", bm)
    remesh_and_smooth(sash, voxel=0.006, smooth_repeat=3)
    bf.limit(sash, 900)
    paint(sash, lambda co, n: srgb(0.45, 0.24, 0.6))
    bands = [arm_band(body, L, "armband", 0.17, 0.22, 0.012, GOLD),
             arm_band(body, L, "bracer", 0.46, WRIST_T, 0.012, GOLD)]
    greave, knees = greaves(body, L, "greaves", GOLD, TURQUOISE)
    shoes = sandals(body, L, LEATHER)
    # Quiver slung diagonally across her back.
    dep = bpy.context.evaluated_depsgraph_get()
    hit, loc, *_ = bpy.context.scene.ray_cast(dep, Vector((0, -2, L.H * 0.68)), Vector((0, 1, 0)))
    back = (loc if hit else Vector((0, -0.12, L.H * 0.68))) + Vector((0, -0.07, 0))
    axis = Vector((0.35, 0.0, 1.0)).normalized()
    bm = bmesh.new()
    add_capsule(bm, back - axis * 0.25, back + axis * 0.25, 0.055, 0.065)
    for k, off in enumerate((-0.2, 0.0, 0.2)):
        add_ellipsoid(bm, back + axis * off, (0.07, 0.07, 0.02))
    quiver = new_object("quiver", bm)
    remesh_and_smooth(quiver, voxel=0.006, smooth_repeat=1)
    bf.limit(quiver, 900)
    paint(quiver, lambda co, n: GOLD if any(abs((co - back).dot(axis) - o) < 0.022 for o in (-0.2, 0.0, 0.2))
          else LEATHER)
    from base_character import tube
    arrows = []
    for dx, dy in ((0, 0), (0.02, 0.015), (-0.02, 0.012), (0.01, -0.02)):
        top = back + axis * 0.38 + Vector((dx, dy, 0))
        arrows.append(tube("arrow", [back + axis * 0.2 + Vector((dx, dy, 0)), top], 0.004, LEATHER))
        arrows.append(blob("fletch", top - axis * 0.03, (0.012, 0.012, 0.035), LINEN))

    fitted = [hair, dress_top, collar, belt_obj] + bands + greave + shoes
    rigid = [(p, lambda co: {"Head": 1.0}) for p in face] + [
        (fringe, lambda co: {"Head": 1.0}), (circlet, lambda co: {"Head": 1.0}), (cgem, lambda co: {"Head": 1.0}),
        (skirt, skirt_weights(L, b0)), (sash, lambda co: {"Hips": 0.6, "RightUpperLeg": 0.4})]
    for k in knees:
        side = "Right" if sum(v.co.x for v in k.data.vertices) > 0 else "Left"
        rigid.append((k, lambda co, side=side: {side + "LowerLeg": 1.0}))
    for q in [quiver, *arrows]:
        rigid.append((q, lambda co: {"UpperChest": 1.0}))
    parts = [*face, fringe, circlet, cgem, *hands, *fitted, *knees, skirt, sash, quiver, *arrows]
    finish("npc_egypt_archer", body, rig, parts, fitted, rigid)


if __name__ == "__main__":
    todo = [a for a in sys.argv[1:] if a in ("anubis", "warrior", "archer")] or ["anubis", "warrior", "archer"]
    for name in todo:
        {"anubis": anubis, "warrior": warrior, "archer": archer}[name]()
