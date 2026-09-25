"""Cartoony (Simpsons-style) fast-food restaurant props.

Run with Blender 5.x:
    blender --background --python props/build_restaurant.py [name ...]
or with the bpy pip module (Python 3.13):
    python props/build_restaurant.py [name ...]

Every prop is its own .glb in props/restaurant/, real-world scale in meters,
origin at the bottom center, front facing +Z in Godot (modeled facing +Y, turned at export).
Food parts are separate so they can be stacked, cooked and served one by one.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "characters"))
from base_character import (  # noqa: E402
    Matrix, Vector, add_capsule, add_ellipsoid, apply_modifiers, bmesh, bpy, join, make_material, new_object,
    paint, remesh_and_smooth, reset_scene, select_only, srgb, tube,
)
from build_pets import face_plus_z  # noqa: E402

OUT = os.path.join(HERE, "restaurant")
os.makedirs(OUT, exist_ok=True)

# Bright, flat, slightly off "cartoon" colors.
BUN = srgb(0.93, 0.62, 0.26)
BUN_TOP = srgb(0.86, 0.5, 0.18)
CRUMB = srgb(0.99, 0.9, 0.66)
SESAME = srgb(1.0, 0.96, 0.82)
PATTY = srgb(0.42, 0.22, 0.12)
PATTY_DARK = srgb(0.3, 0.15, 0.08)
CHEESE = srgb(1.0, 0.78, 0.15)
LETTUCE = srgb(0.45, 0.82, 0.25)
LETTUCE_LIGHT = srgb(0.75, 0.95, 0.5)
TOMATO = srgb(0.93, 0.2, 0.15)
TOMATO_IN = srgb(1.0, 0.48, 0.35)
SEED = srgb(1.0, 0.85, 0.45)
PICKLE = srgb(0.4, 0.62, 0.2)
PICKLE_IN = srgb(0.72, 0.85, 0.42)
SAUSAGE = srgb(0.78, 0.3, 0.2)
SAUSAGE_DARK = srgb(0.55, 0.18, 0.12)
MUSTARD = srgb(1.0, 0.85, 0.1)
FRY = srgb(1.0, 0.82, 0.3)
FRY_DARK = srgb(0.85, 0.58, 0.18)
RED = srgb(0.9, 0.14, 0.14)
RED_DARK = srgb(0.68, 0.08, 0.1)
YELLOW = srgb(1.0, 0.85, 0.1)
BLUE = srgb(0.18, 0.45, 0.9)
GREEN = srgb(0.25, 0.72, 0.3)
KRAFT = srgb(0.86, 0.72, 0.5)
WHITE = srgb(0.97, 0.97, 0.95)
STEEL = srgb(0.74, 0.77, 0.82)
STEEL_DARK = srgb(0.5, 0.53, 0.58)
BLACK = srgb(0.13, 0.12, 0.14)
CHROME = srgb(0.86, 0.88, 0.92)
OIL = srgb(0.85, 0.62, 0.15)
TAN = srgb(0.87, 0.73, 0.5)
TAN_DARK = srgb(0.72, 0.56, 0.34)
CREAM = srgb(0.96, 0.92, 0.8)
SCREEN = srgb(0.3, 0.85, 0.45)
PURPLE = srgb(0.6, 0.35, 0.85)
ORANGE = srgb(1.0, 0.55, 0.12)


def solid(fn):
    return lambda co, n: fn


# --------------------------------------------------------------------------
# Modeling helpers
# --------------------------------------------------------------------------

def lathe(name, profile, color_fn, segments=40):
    """Spins a (radius, z) profile around Z. Profile runs from the axis at the
    bottom to the axis at the top."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0, z)) for r, z in profile]
    edges = [bm.edges.new((a, b)) for a, b in zip(verts, verts[1:])]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), dvec=(0, 0, 0),
                   angle=math.tau, steps=segments, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = new_object(name, bm)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn)
    return obj


def rbox(name, center, size, color_fn, bevel=0.01, segments=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(center) @ Matrix.Diagonal((*size, 1)))
    obj = new_object(name, bm)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = min(bevel, min(size) * 0.49)
        mod.segments = segments
        apply_modifiers(obj)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn if callable(color_fn) else solid(color_fn))
    return obj


def cyl(name, center, radius, height, color_fn, segments=32, bevel=0.0, radius_top=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=height,
                          matrix=Matrix.Translation(center))
    obj = new_object(name, bm)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        apply_modifiers(obj)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn if callable(color_fn) else solid(color_fn))
    return obj


def blobs(name, shapes, color_fn, voxel=0.004, smooth=3, faces=None):
    """shapes: ("e", center, radii) or ("c", a, b, ra, rb)."""
    bm = bmesh.new()
    for s in shapes:
        if s[0] == "e":
            add_ellipsoid(bm, s[1], s[2])
        else:
            add_capsule(bm, s[1], s[2], s[3], s[4])
    obj = new_object(name, bm)
    remesh_and_smooth(obj, voxel=voxel, smooth_repeat=smooth)
    if faces and len(obj.data.polygons) > faces:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = faces / len(obj.data.polygons)
        apply_modifiers(obj)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn if callable(color_fn) else solid(color_fn))
    return obj


def sheet(name, fn_xy, size, res, thickness, color_fn, round_shape=True):
    """A grid sheet with height z = fn_xy(x, y), cut to a disc if round."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=res, y_segments=res, size=size / 2)
    if round_shape:
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().length > size / 2],
                         context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        v.co.z = fn_xy(v.co.x, v.co.y)
    obj = new_object(name, bm)
    sol = obj.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = 0
    sm = obj.modifiers.new("Smooth", "SMOOTH")
    sm.iterations = 1
    apply_modifiers(obj)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn)
    return obj


def move(obj, offset):
    for v in obj.data.vertices:
        v.co += Vector(offset)
    return obj


def export(name, parts):
    body = parts[0]
    if len(parts) > 1:
        join(parts[1:], body)
    body.name = name
    body.data.materials.clear()
    body.data.materials.append(make_material(name))
    face_plus_z()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL")
    print(f"{name}: {sum(len(p.vertices) - 2 for p in body.data.polygons)} triangles")


# --------------------------------------------------------------------------
# Burger parts (stacking heights in comments, all centered on the Z axis)
# --------------------------------------------------------------------------

def bottom_bun():
    prof = [(0, 0), (0.048, 0), (0.054, 0.006), (0.056, 0.016), (0.052, 0.024), (0.045, 0.027), (0, 0.027)]
    return lathe("bottom_bun", prof, lambda co, n: CRUMB if n.z > 0.7 and co.z > 0.02 else BUN)   # 0.027 tall


def top_bun():
    prof = [(0, 0), (0.052, 0), (0.058, 0.008), (0.056, 0.022), (0.047, 0.036), (0.032, 0.046), (0.014, 0.051),
            (0, 0.052)]
    bun = lathe("top_bun", prof, lambda co, n: CRUMB if n.z < -0.7 else (BUN_TOP if co.z > 0.03 else BUN))
    rnd = random.Random(3)
    seeds = []
    for i in range(22):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.uniform(0.02, 1.0)) * 0.045
        z = 0.052 * math.sqrt(max(0.0, 1 - (r / 0.058) ** 2)) + 0.0005
        seed = blobs("seed", [("e", (r * math.cos(a), r * math.sin(a), z), (0.0045, 0.0025, 0.0018))],
                     SESAME, voxel=0.0012, smooth=1)
        seeds.append(seed)
    join(seeds, bun)
    return bun   # 0.052 tall


def patty():
    prof = [(0, 0), (0.05, 0), (0.055, 0.005), (0.056, 0.011), (0.052, 0.018), (0, 0.018)]

    def color(co, n):
        v = math.sin(co.x * 180) * math.sin(co.y * 170 + 1.0)
        return PATTY_DARK if v > 0.45 else PATTY
    return lathe("patty", prof, color, segments=36)   # 0.018 tall


def cheese():
    def z(x, y):
        r = max(abs(x), abs(y))
        corner = math.hypot(x, y)
        return -0.9 * max(0.0, corner - 0.055) ** 1.0 - 0.15 * max(0.0, r - 0.04)
    obj = sheet("cheese", z, 0.1, 16, 0.004, solid(CHEESE), round_shape=False)
    return move(obj, (0, 0, 0.002))   # ~0.004 thick, corners droop


def lettuce():
    def z(x, y):
        r = math.hypot(x, y)
        a = math.atan2(y, x)
        return 0.006 * math.sin(a * 9) * (r / 0.065) ** 2 + 0.003 * math.sin(a * 23) * (r / 0.065) ** 3

    def color(co, n):
        return LETTUCE_LIGHT if math.hypot(co.x, co.y) < 0.03 else LETTUCE
    obj = sheet("lettuce", z, 0.13, 30, 0.004, color)
    return move(obj, (0, 0, 0.004))   # ~0.01 tall with ruffles


def tomato():
    prof = [(0, 0), (0.041, 0), (0.044, 0.004), (0.041, 0.008), (0, 0.008)]

    def color(co, n):
        r = math.hypot(co.x, co.y)
        if abs(n.z) < 0.6 or r > 0.037:
            return TOMATO
        a = (math.atan2(co.y, co.x) % (math.tau / 5)) / (math.tau / 5)
        if 0.012 < r < 0.03 and 0.2 < a < 0.8:
            return SEED if abs(a - 0.5) < 0.12 and abs(r - 0.021) < 0.004 else TOMATO_IN
        return TOMATO
    return lathe("tomato", prof, color, segments=40)   # 0.008 tall


def pickle():
    prof = [(0, 0), (0.016, 0), (0.017, 0.0015), (0.016, 0.003), (0, 0.003)]
    return lathe("pickle", prof, lambda co, n: PICKLE_IN if abs(n.z) > 0.6 and math.hypot(co.x, co.y) < 0.013
                 else PICKLE, segments=24)


# --------------------------------------------------------------------------
# Hot dog parts
# --------------------------------------------------------------------------

def hotdog_bun():
    shapes = [("c", (-0.075, s * 0.019, 0.026), (0.075, s * 0.019, 0.026), 0.022, 0.022) for s in (1, -1)]
    shapes.append(("c", (-0.078, 0, 0.018), (0.078, 0, 0.018), 0.02, 0.02))

    def color(co, n):
        return CRUMB if abs(co.y) < 0.02 and co.z > 0.028 and n.z > 0.2 else BUN
    obj = blobs("hotdog_bun", shapes, color, voxel=0.0025, smooth=4, faces=4000)
    return move(obj, (0, 0, -min(v.co.z for v in obj.data.vertices)))


def sausage():
    def color(co, n):
        return SAUSAGE_DARK if (co.x * 50 + co.z * 40) % 1.0 < 0.18 and n.z > 0.3 else SAUSAGE
    return blobs("sausage", [("c", (-0.092, 0, 0.015), (0.092, 0, 0.015), 0.014, 0.014)], color,
                 voxel=0.0022, smooth=2, faces=2500)


def mustard():
    pts = [Vector((-0.085 + 0.17 * t, 0.009 * math.sin(t * math.pi * 7), 0.03)) for t in [k / 60 for k in range(61)]]
    return tube("mustard", pts, 0.0035, MUSTARD)


# --------------------------------------------------------------------------
# Fries
# --------------------------------------------------------------------------

def fry(length=0.085, bend=0.006, name="fry"):
    pts = [Vector((0, bend * math.sin(t * math.pi), length * t)) for t in [k / 6 for k in range(7)]]
    shapes = [("c", a, b, 0.0048, 0.0048) for a, b in zip(pts, pts[1:])]
    obj = blobs(name, shapes, lambda co, n: FRY_DARK if co.z < 0.004 or co.z > length - 0.004 else FRY,
                voxel=0.0016, smooth=1, faces=300)
    return obj


def fry_carton(full):
    """Red fry carton with a scooped front and a yellow zig-zag band."""
    bm = bmesh.new()
    rings = []
    levels = 12
    for i in range(levels + 1):
        t = i / levels
        hx, hy = 0.035 + 0.014 * t, 0.018 + 0.012 * t
        ring = []
        for k in range(32):
            a = k / 32 * math.tau
            x, y = hx * math.copysign(abs(math.cos(a)) ** 0.5, math.cos(a)), hy * math.copysign(
                abs(math.sin(a)) ** 0.5, math.sin(a))
            top = 0.11 + 0.025 * (x / hx) ** 2  # scooped: lower in the middle, taller at the sides
            ring.append(bm.verts.new((x, y, top * t)))
        rings.append(ring)
    for i in range(levels):
        for k in range(32):
            k2 = (k + 1) % 32
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    bm.faces.new(list(reversed(rings[0])))
    carton = new_object("fry_carton", bm)
    sol = carton.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.003
    apply_modifiers(carton)
    select_only(carton)
    bpy.ops.object.shade_smooth()

    def color(co, n):
        band = 0.055 + 0.008 * math.sin(co.x * 180 + co.y * 180)
        return YELLOW if abs(co.z - band) < 0.009 else RED
    paint(carton, color)
    parts = [carton]
    if full:
        rnd = random.Random(8)
        for i in range(24):
            x, y = rnd.uniform(-0.035, 0.035), rnd.uniform(-0.016, 0.016)
            f = fry(rnd.uniform(0.075, 0.1), rnd.uniform(-0.006, 0.006), name="fry")
            tilt = Matrix.Rotation(rnd.uniform(-0.3, 0.3), 4, "Y") @ Matrix.Rotation(rnd.uniform(-0.2, 0.2), 4, "X")
            for v in f.data.vertices:
                v.co = tilt @ v.co + Vector((x, y, 0.045 + rnd.uniform(0, 0.02)))
            parts.append(f)
    return parts


def fry_bag():
    """Small paper fry bag with a folded-over top and a red stripe."""
    bag = rbox("fry_bag", (0, 0, 0.07), (0.085, 0.05, 0.14), KRAFT, bevel=0.006)
    stripe = rbox("stripe", (0, 0, 0.07), (0.087, 0.052, 0.024), RED, bevel=0.004)
    fold = rbox("fold", (0, 0, 0.143), (0.087, 0.052, 0.012), KRAFT, bevel=0.004)
    for v in fold.data.vertices:
        v.co.z += 0.004 * math.sin(v.co.x * 90)
    return [bag, stripe, fold]


# --------------------------------------------------------------------------
# Kitchen equipment
# --------------------------------------------------------------------------

def grill():
    parts = [rbox("cabinet", (0, 0, 0.42), (1.0, 0.72, 0.82),
                  lambda co, n: STEEL_DARK if n.y > 0.7 and abs(co.x) < 0.006 else STEEL, bevel=0.03)]
    parts.append(rbox("griddle", (0, -0.02, 0.855), (0.98, 0.64, 0.05), BLACK, bevel=0.01))
    parts.append(rbox("backsplash", (0, -0.34, 0.97), (1.0, 0.04, 0.24), STEEL, bevel=0.015))
    for s in (1, -1):
        parts.append(rbox("side", (s * 0.49, -0.05, 0.93), (0.03, 0.6, 0.12), STEEL, bevel=0.01))
    parts.append(rbox("trough", (0, 0.33, 0.83), (0.96, 0.06, 0.04), STEEL_DARK, bevel=0.01))
    for i in range(4):
        x = -0.36 + i * 0.24
        k = cyl("knob", (x, 0.37, 0.72), 0.032, 0.03, RED, bevel=0.006)
        for v in k.data.vertices:
            v.co = Matrix.Rotation(math.pi / 2, 4, "X") @ (v.co - Vector((x, 0.37, 0.72))) + Vector((x, 0.37, 0.72))
        parts.append(k)
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(cyl("leg", (sx * 0.44, sy * 0.3, 0.02), 0.025, 0.04, BLACK))
    # Door handles.
    for s in (1, -1):
        parts.append(tube("handle", [Vector((s * 0.12, 0.38, 0.55)), Vector((s * 0.12, 0.38, 0.3))], 0.01, CHROME))
    return parts


def fryer():
    parts = [rbox("cabinet", (0, 0, 0.44), (0.5, 0.72, 0.86), STEEL, bevel=0.025)]
    parts.append(rbox("rim", (0, 0.02, 0.88), (0.5, 0.6, 0.04), STEEL_DARK, bevel=0.01))
    parts.append(rbox("oil", (0, 0.02, 0.891), (0.42, 0.5, 0.02), OIL, bevel=0.005))
    parts.append(rbox("control", (0, -0.34, 1.02), (0.5, 0.05, 0.3), STEEL, bevel=0.015))
    parts.append(rbox("flue", (0, -0.34, 1.2), (0.3, 0.06, 0.08), STEEL_DARK, bevel=0.01))
    for x in (-0.12, 0.12):
        d = cyl("dial", (x, -0.31, 1.05), 0.03, 0.02, RED, bevel=0.005)
        for v in d.data.vertices:
            v.co = Matrix.Rotation(math.pi / 2, 4, "X") @ (v.co - Vector((x, -0.31, 1.05))) + Vector((x, -0.31, 1.05))
        parts.append(d)
        # Wire basket resting in the oil, handle towards the front.
        basket = rbox("basket", (x, 0.02, 0.9), (0.18, 0.34, 0.12),
                      lambda co, n: STEEL_DARK if (co.x * 60) % 1.0 < 0.3 or (co.y * 60) % 1.0 < 0.3 else STEEL,
                      bevel=0.01)
        parts.append(basket)
        parts.append(tube("basket_handle", [Vector((x, 0.19, 0.95)), Vector((x, 0.38, 1.02))], 0.012, STEEL_DARK))
        parts.append(cyl("grip", (x, 0.43, 1.05), 0.018, 0.09, RED))
        g = parts[-1]
        c = Vector((x, 0.43, 1.05))
        for v in g.data.vertices:
            v.co = Matrix.Rotation(math.radians(70), 4, "X") @ (v.co - c) + c
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(cyl("leg", (sx * 0.2, sy * 0.3, 0.02), 0.022, 0.04, BLACK))
    return parts


def cash_register():
    parts = [rbox("drawer", (0, 0, 0.05), (0.42, 0.4, 0.1), CREAM, bevel=0.012)]
    parts.append(rbox("drawer_front", (0, 0.2, 0.05), (0.3, 0.012, 0.04), STEEL_DARK, bevel=0.004))
    body = rbox("body", (0, -0.04, 0.16), (0.4, 0.3, 0.14), CREAM, bevel=0.02)
    parts.append(body)
    pad = rbox("keypad", (0, 0.06, 0.22), (0.34, 0.2, 0.04), STEEL_DARK, bevel=0.01)
    tilt = Matrix.Rotation(math.radians(25), 4, "X")
    c = Vector((0, 0.06, 0.22))
    for v in pad.data.vertices:
        v.co = tilt @ (v.co - c) + c
    parts.append(pad)
    colors = [RED, YELLOW, BLUE, WHITE, GREEN]
    for i in range(4):
        for j in range(5):
            p = Vector((-0.12 + j * 0.06, -0.06 + i * 0.045, 0.025))
            key = cyl("key", p, 0.017, 0.016, colors[(i + j) % len(colors)], segments=16, bevel=0.004)
            for v in key.data.vertices:
                v.co = tilt @ v.co + c
            parts.append(key)
    parts.append(cyl("stalk", (0, -0.14, 0.3), 0.02, 0.14, STEEL_DARK))
    parts.append(rbox("display", (0, -0.14, 0.4), (0.2, 0.08, 0.08), CREAM, bevel=0.012))
    parts.append(rbox("screen", (0, -0.1, 0.4), (0.16, 0.01, 0.045), SCREEN, bevel=0.003))
    parts.append(rbox("printer", (0.14, -0.1, 0.25), (0.1, 0.1, 0.05), STEEL, bevel=0.01))
    parts.append(rbox("receipt", (0.14, -0.1, 0.3), (0.06, 0.004, 0.06), WHITE, bevel=0.0))
    return parts


# --------------------------------------------------------------------------
# Seating
# --------------------------------------------------------------------------

def booth():
    """One big red booth bench (place two facing each other across a table)."""
    parts = [rbox("base", (0, 0, 0.2), (1.3, 0.55, 0.4), RED_DARK, bevel=0.03)]
    parts.append(rbox("kick", (0, 0.27, 0.06), (1.28, 0.02, 0.1), CHROME, bevel=0.005))
    parts.append(rbox("cushion", (0, 0.03, 0.46), (1.3, 0.55, 0.13), RED, bevel=0.05, segments=4))
    # Channel-tufted backrest: a row of fat vertical rolls.
    rolls = []
    for i in range(8):
        x = -0.56 + i * 0.16
        rolls.append(("c", (x, -0.22, 0.55), (x, -0.22, 1.15), 0.085, 0.085))
    back = blobs("backrest", rolls, RED, voxel=0.012, smooth=4, faces=5000)
    parts.append(back)
    parts.append(rbox("back_panel", (0, -0.26, 0.8), (1.3, 0.08, 0.7), RED_DARK, bevel=0.03))
    parts.append(rbox("cap", (0, -0.24, 1.23), (1.34, 0.22, 0.06), CHROME, bevel=0.025))
    for s in (1, -1):
        parts.append(rbox("end", (s * 0.66, -0.05, 0.62), (0.06, 0.62, 1.24),
                          lambda co, n: CHROME if co.z > 1.2 else RED_DARK, bevel=0.025))
    return parts


def table():
    parts = [rbox("top", (0, 0, 0.745), (1.1, 0.72, 0.04), TAN, bevel=0.02)]
    parts.append(rbox("edge", (0, 0, 0.725), (1.12, 0.74, 0.02), CHROME, bevel=0.008))
    parts.append(cyl("pedestal", (0, 0, 0.37), 0.045, 0.7, CHROME))
    parts.append(cyl("foot", (0, 0, 0.025), 0.28, 0.05, BLACK, bevel=0.015, radius_top=0.24))
    parts.append(cyl("collar", (0, 0, 0.69), 0.1, 0.03, CHROME, bevel=0.008))
    return parts


# --------------------------------------------------------------------------
# Kids' fun house
# --------------------------------------------------------------------------

def fun_house():
    parts = []
    floor_z, size = 1.0, 1.5
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(cyl("post", (sx * size / 2, sy * size / 2, 1.0), 0.07, 2.0, RED, bevel=0.02))
    parts.append(rbox("floor", (0, 0, floor_z), (size + 0.1, size + 0.1, 0.1), YELLOW, bevel=0.03))

    def wall_color(co, n):
        # Round windows on each wall.
        for cx, cz in ((0.0, 1.45),):
            if abs(n.x) > 0.7 and math.hypot(co.y - cx, co.z - cz) < 0.22:
                return WHITE if math.hypot(co.y - cx, co.z - cz) > 0.18 else BLACK
            if abs(n.y) > 0.7 and math.hypot(co.x - cx, co.z - cz) < 0.22:
                return WHITE if math.hypot(co.x - cx, co.z - cz) > 0.18 else BLACK
        return BLUE
    parts.append(rbox("back_wall", (0, -size / 2, 1.45), (size, 0.08, 0.8), BLUE, bevel=0.03))
    for s in (1, -1):
        parts.append(rbox("side_wall", (s * size / 2, 0, 1.45), (0.08, size, 0.8), BLUE, bevel=0.03))
    # Round porthole windows: a white frame around a dark opening on each wall.
    for center, axis in (((0, -size / 2 - 0.045, 1.45), "X"), ((size / 2 + 0.045, 0, 1.45), "Y"),
                         ((-size / 2 - 0.045, 0, 1.45), "Y")):
        for radius, depth, color, push in ((0.23, 0.03, WHITE, 0.0), (0.18, 0.035, BLACK, 0.004)):
            w = cyl("window", (0, 0, 0), radius, depth, color, segments=32, bevel=0.008 if color == WHITE else 0)
            rot = Matrix.Rotation(math.pi / 2, 4, axis)
            c = Vector(center)
            out = c.normalized()
            out.z = 0
            out.normalize()
            for v in w.data.vertices:
                v.co = rot @ v.co + c + out * push
            parts.append(w)
    # Front railing with a gap for the slide.
    for s in (1, -1):
        parts.append(tube("rail", [Vector((s * 0.72, size / 2, 1.4)), Vector((s * 0.3, size / 2, 1.4))], 0.03, GREEN))
        for x in (0.4, 0.55, 0.7):
            parts.append(tube("baluster", [Vector((s * x, size / 2, 1.05)), Vector((s * x, size / 2, 1.4))], 0.02,
                              GREEN))
    # Peaked roof.
    roof = cyl("roof", (0, 0, 2.2), 1.2, 0.8, lambda co, n: RED if int((co.z - 1.8) * 10) % 2 else YELLOW,
               segments=4, radius_top=0.0)
    for v in roof.data.vertices:
        v.co = Matrix.Rotation(math.pi / 4, 4, "Z") @ v.co
    parts.append(roof)
    parts.append(blobs("flag_pole", [("c", (0, 0, 2.55), (0, 0, 2.95), 0.02, 0.02)], YELLOW, voxel=0.01, smooth=0))
    parts.append(rbox("flag", (0.13, 0, 2.87), (0.24, 0.02, 0.15), PURPLE, bevel=0.01))
    # Slide from the front edge down to the ground.
    path = [Vector((0, size / 2 + 0.05 + 1.5 * t, floor_z + 0.05 - (floor_z - 0.12) * (3 * t * t - 2 * t ** 3)))
            for t in [k / 20 for k in range(21)]]
    bm = bmesh.new()
    rows = []
    # U-shaped chute: raised side walls either side of a flat bed.
    section = [(-0.3, 0.14), (-0.28, 0.0), (0.28, 0.0), (0.3, 0.14)]
    for p in path:
        rows.append([bm.verts.new(p + Vector((x, 0, z))) for x, z in section])
    for a, b in zip(rows, rows[1:]):
        for i in range(len(a) - 1):
            bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    slide = new_object("slide", bm)
    sol = slide.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.03
    apply_modifiers(slide)
    select_only(slide)
    bpy.ops.object.shade_smooth()
    paint(slide, solid(YELLOW))
    parts.append(slide)
    # Ladder at the back.
    for s in (1, -1):
        parts.append(tube("ladder_rail", [Vector((s * 0.25, -size / 2 - 0.35, 0)), Vector((s * 0.25, -size / 2 - 0.05,
                                                                                            floor_z + 0.4))], 0.03, GREEN))
    for k in range(6):
        t = (k + 0.5) / 6
        y = -size / 2 - 0.35 + 0.3 * t
        z = (floor_z + 0.4) * t
        parts.append(tube("rung", [Vector((-0.25, y, z)), Vector((0.25, y, z))], 0.022, YELLOW))
    # Crawl tube on the side at ground level.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=0.35, radius2=0.35, depth=1.4,
                          matrix=Matrix.Translation((size / 2 + 0.55, 0, 0.35)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    crawl = new_object("crawl_tube", bm)
    sol = crawl.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.05
    apply_modifiers(crawl)
    select_only(crawl)
    bpy.ops.object.shade_smooth()
    paint(crawl, solid(ORANGE))
    parts.append(crawl)
    # Ball pit under the house.
    parts.append(rbox("pit_wall", (0, -size / 2 + 0.02, 0.2), (size, 0.08, 0.4), GREEN, bevel=0.02))
    for s in (1, -1):
        parts.append(rbox("pit_wall", (s * (size / 2 - 0.02), 0, 0.2), (0.08, size, 0.4), GREEN, bevel=0.02))
    parts.append(rbox("pit_front", (0, size / 2 - 0.02, 0.15), (size, 0.08, 0.3), GREEN, bevel=0.02))
    rnd = random.Random(5)
    bm = bmesh.new()
    ball_colors = []
    for i in range(70):
        p = Vector((rnd.uniform(-0.62, 0.62), rnd.uniform(-0.62, 0.62), rnd.uniform(0.06, 0.26)))
        add_ellipsoid(bm, p, (0.06, 0.06, 0.06))
        ball_colors.append((p, [RED, YELLOW, BLUE, GREEN, PURPLE, ORANGE][i % 6]))
    balls = new_object("balls", bm)
    select_only(balls)
    bpy.ops.object.shade_smooth()
    paint(balls, lambda co, n: min(ball_colors, key=lambda pc: (pc[0] - co).length_squared)[1])
    parts.append(balls)
    return parts


# --------------------------------------------------------------------------

def assembled_burger():
    stack = [(bottom_bun(), 0.0), (patty(), 0.027), (cheese(), 0.045), (lettuce(), 0.05), (tomato(), 0.059),
             (pickle(), 0.067), (top_bun(), 0.07)]
    parts = []
    for obj, z in stack:
        move(obj, (0, 0, z))
        parts.append(obj)
    return parts


def assembled_hotdog():
    bun = hotdog_bun()
    s = move(sausage(), (0, 0, 0.018))
    m = move(mustard(), (0, 0, 0.018))
    return [bun, s, m]


PROPS = {
    "bottom_bun": lambda: [bottom_bun()],
    "top_bun": lambda: [top_bun()],
    "patty": lambda: [patty()],
    "cheese": lambda: [cheese()],
    "lettuce": lambda: [lettuce()],
    "tomato": lambda: [tomato()],
    "pickle": lambda: [pickle()],
    "burger": assembled_burger,
    "hotdog_bun": lambda: [hotdog_bun()],
    "sausage": lambda: [sausage()],
    "mustard": lambda: [mustard()],
    "hotdog": assembled_hotdog,
    "fry": lambda: [fry()],
    "fry_carton_empty": lambda: fry_carton(False),
    "fry_carton_full": lambda: fry_carton(True),
    "fry_bag": fry_bag,
    "grill": grill,
    "fryer": fryer,
    "cash_register": cash_register,
    "booth": booth,
    "table": table,
    "fun_house": fun_house,
}

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if a in PROPS]
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        reset_scene()
        export(name, fn())
