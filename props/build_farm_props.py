"""Chunky, Dragon Quest-style farm props: hay, barn, horse stalls, fences,
chicken coop and farmyard odds and ends.

Run with Blender 5.x:
    blender --background --python props/build_farm_props.py [name ...]
or with the bpy pip module (Python 3.13):
    python props/build_farm_props.py [name ...]

Every prop is its own .glb in props/farm/, real-world scale in meters,
origin at the bottom center, front facing +Y in Blender (-Z in Godot).
Colors are vertex colors; use toon_small.tres / toon_large.tres for outlines.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "pets"))
import build_restaurant as br  # noqa: E402
from build_restaurant import (  # noqa: E402
    Matrix, Vector, apply_modifiers, blobs, bmesh, bpy, cyl, join, lathe, make_material, new_object, paint,
    rbox, reset_scene, select_only, srgb, tube,
)
from build_pets import add_ear  # noqa: E402

OUT = os.path.join(HERE, "farm")
os.makedirs(OUT, exist_ok=True)

STRAW = srgb(0.96, 0.8, 0.36)
STRAW_DARK = srgb(0.82, 0.62, 0.22)
STRAW_LIGHT = srgb(1.0, 0.9, 0.55)
TWINE = srgb(0.6, 0.38, 0.18)
BARN_RED = srgb(0.76, 0.18, 0.13)
BARN_RED_DARK = srgb(0.6, 0.12, 0.1)
TRIM = srgb(0.97, 0.95, 0.9)
ROOF = srgb(0.34, 0.31, 0.36)
ROOF_DARK = srgb(0.26, 0.24, 0.28)
COOP_ROOF = srgb(0.84, 0.24, 0.16)
COOP_ROOF_DARK = srgb(0.66, 0.16, 0.12)
WOOD = srgb(0.74, 0.52, 0.3)
WOOD_DARK = srgb(0.56, 0.36, 0.2)
WOOD_LIGHT = srgb(0.84, 0.64, 0.4)
DIRT = srgb(0.52, 0.38, 0.26)
IRON = srgb(0.36, 0.36, 0.4)
STEEL = srgb(0.74, 0.77, 0.82)
STEEL_DARK = srgb(0.55, 0.58, 0.63)
WATER = srgb(0.3, 0.62, 0.9)
GLASS = srgb(0.35, 0.55, 0.8)
DARK = srgb(0.12, 0.1, 0.1)
EGG = srgb(0.98, 0.93, 0.84)
EGG_BROWN = srgb(0.86, 0.62, 0.4)
SACK = srgb(0.88, 0.8, 0.62)
SACK_BAND = srgb(0.3, 0.55, 0.28)
GRAIN = srgb(0.93, 0.76, 0.35)
GREEN = srgb(0.35, 0.65, 0.3)
GOLD = srgb(0.95, 0.75, 0.25)


def solid(c):
    return lambda co, n: c


def xf(obj, matrix):
    """Transforms a finished part's mesh in place (colors are already painted)."""
    obj.data.transform(matrix)
    obj.data.update()
    return obj


def strip(name, a, b, yc, ylen, thick, color, lift=0.0, bevel=0.015):
    """A box running from a to b in the XZ plane, ylen deep along Y and thick
    across. lift pushes it off the a-b line along its outward normal (roofs)."""
    a, b = Vector((a[0], 0, a[1])), Vector((b[0], 0, b[1]))
    d = b - a
    ang = math.atan2(d.z, d.x)
    normal = Vector((-math.sin(ang), 0, math.cos(ang)))
    obj = rbox(name, (0, 0, 0), (d.length, ylen, thick), color, bevel=bevel)
    centre = (a + b) / 2 + normal * lift + Vector((0, yc, 0))
    return xf(obj, Matrix.Translation(centre) @ Matrix.Rotation(-ang, 4, "Y"))


def prism(name, outline, y, thickness, color):
    """Extrudes an XZ outline [(x, z), ...] (counter-clockwise from the front) along Y."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y + thickness / 2, z)) for x, z in outline]
    back = [bm.verts.new((x, y - thickness / 2, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = new_object(name, bm)
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.015
    bev.segments = 2
    apply_modifiers(obj)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, solid(color) if not callable(color) else color)
    return obj


def grid_box(name, size, color_fn, cuts=10, bevel=0.04, jitter=0.0, seed=1):
    """A subdivided rounded box (enough vertices to paint patterns on)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((*size, 1)))
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=cuts, use_grid_fill=True)
    obj = new_object(name, bm)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        apply_modifiers(obj)
    if jitter:
        rng = random.Random(seed)
        for v in obj.data.vertices:
            v.co += v.normal * rng.uniform(-jitter, jitter)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn)
    return obj


def straw(co, n, scale=70.0):
    """Streaky straw: stripes that wander along the stalk direction (X)."""
    v = math.sin(co[1] * scale + math.sin(co[0] * 9.0) * 2.0 + co[2] * scale * 0.7)
    if v > 0.75:
        return STRAW_LIGHT
    if v < -0.7:
        return STRAW_DARK
    return STRAW


def spikes(name, points, color_fn, width=0.03, thick=0.012):
    """Pointed straws / tufts: points is [(base, tip), ...]."""
    bm = bmesh.new()
    for base, tip in points:
        add_ear(bm, Vector(base), Vector(tip), width, thick)
    obj = new_object(name, bm)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn)
    return obj


def lift_to_floor(parts):
    zmin = min((p.matrix_world @ v.co).z for p in parts for v in p.data.vertices)
    for p in parts:
        xf(p, Matrix.Translation((0, 0, -zmin)))
    return parts


def export(name, parts):
    body = parts[0]
    if len(parts) > 1:
        join(parts[1:], body)
    body.name = name
    body.data.materials.clear()
    body.data.materials.append(make_material(name))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL")
    print(f"{name}: {sum(len(p.vertices) - 2 for p in body.data.polygons)} triangles")


# --------------------------------------------------------------------------
# Hay
# --------------------------------------------------------------------------

def hay_bale():
    """Square bale, 0.9 x 0.46 x 0.4 m, two twine bands. Stacks at 0.4 m."""
    bale = grid_box("bale", (0.9, 0.46, 0.4), straw, cuts=12, bevel=0.05, jitter=0.006)
    xf(bale, Matrix.Translation((0, 0, 0.2)))
    parts = [bale]
    for x in (-0.24, 0.24):
        parts.append(rbox("twine", (x, 0, 0.2), (0.025, 0.475, 0.415), TWINE, bevel=0.008))
    rng = random.Random(3)
    ends = []
    for s in (1, -1):
        for _ in range(14):
            y, z = rng.uniform(-0.2, 0.2), rng.uniform(0.05, 0.36)
            base = (s * 0.44, y, z)
            ends.append((base, (s * (0.5 + rng.uniform(0, 0.04)), y + rng.uniform(-0.03, 0.03),
                                z + rng.uniform(-0.03, 0.03))))
    parts.append(spikes("ends", ends, straw, width=0.03))
    return parts


def hay_round():
    """Round bale lying on its side, 1.3 m across, 1.2 m long."""
    radius, length = 0.65, 1.2
    prof = [(0.0, -length / 2)]
    prof += [(radius * t, -length / 2) for t in [k / 14 for k in range(1, 14)]]
    prof += [(radius, -length / 2 + length * t) for t in [k / 16 for k in range(0, 17)]]
    prof += [(radius * t, length / 2) for t in [k / 14 for k in range(13, 0, -1)]]
    prof += [(0.0, length / 2)]

    def color(co, n):
        r = math.hypot(co[0], co[1])
        if abs(n[2]) > 0.6:  # the flat ends show the rolled spiral
            ang = math.atan2(co[1], co[0])
            v = math.sin(r * 55 + ang)
            return STRAW_DARK if v > 0.55 else STRAW_LIGHT if v < -0.8 else STRAW
        return straw(co, n, scale=45)
    bale = lathe("round", prof, color, segments=48)
    bm_mod = bale.modifiers.new("Bevel", "BEVEL")
    bm_mod.width = 0.05
    bm_mod.segments = 3
    bm_mod.limit_method = "ANGLE"
    apply_modifiers(bale)
    paint(bale, color)
    xf(bale, Matrix.Translation((0, 0, radius)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    net = []
    for x in (-0.35, 0.0, 0.35):
        ring = cyl("band", (0, 0, 0), radius + 0.008, 0.03, TWINE, segments=48)
        net.append(xf(ring, Matrix.Translation((x, 0, radius)) @ Matrix.Rotation(math.pi / 2, 4, "Y")))
    return [bale] + net


def hay_pile():
    """Loose hay heap, about 1.1 m across."""
    rng = random.Random(7)
    shapes = [("e", (0, 0, 0.12), (0.5, 0.42, 0.22)), ("e", (0.1, -0.05, 0.3), (0.3, 0.28, 0.18))]
    for _ in range(8):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.2, 0.42)
        shapes.append(("e", (r * math.cos(a), r * math.sin(a), 0.1), (0.16, 0.14, 0.1)))
    pile = blobs("pile", shapes, straw, voxel=0.02, smooth=4, faces=3000)
    tufts = []
    for _ in range(60):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.5)
        z = 0.42 * max(0.0, 1 - (r / 0.55) ** 2) + 0.02
        base = (r * math.cos(a), r * math.sin(a), z)
        tip = (base[0] + rng.uniform(-0.12, 0.12), base[1] + rng.uniform(-0.12, 0.12),
               base[2] + rng.uniform(0.02, 0.1))
        tufts.append((base, tip))
    parts = [pile, spikes("stalks", tufts, straw, width=0.028)]
    return lift_to_floor(parts)


def pitchfork():
    """1.6 m pitchfork standing on its tines; the grip is the top of the shaft."""
    parts = [tube("shaft", [Vector((0, 0, 0.36)), Vector((0, 0, 1.6))], 0.018, WOOD)]
    parts.append(cyl("ferrule", (0, 0, 0.37), 0.024, 0.06, IRON))
    bar = tube("bar", [Vector((-0.12, 0, 0.3)), Vector((0.12, 0, 0.3))], 0.012, IRON)
    parts.append(bar)
    parts.append(tube("neck", [Vector((0, 0, 0.3)), Vector((0, 0, 0.38))], 0.014, IRON))
    for x in (-0.12, -0.04, 0.04, 0.12):
        pts = [Vector((x, 0, 0.3)), Vector((x, 0.015, 0.16)), Vector((x, 0.04, 0.04)), Vector((x, 0.06, 0.0))]
        parts.append(tube("tine", pts, 0.008, STEEL))
    return parts


# --------------------------------------------------------------------------
# Barn: 8 m wide, 10 m deep, gambrel roof; the front doorway is open.
# --------------------------------------------------------------------------

BARN_W, BARN_D, WALL_H = 8.0, 10.0, 4.0
EAVE, KNEE, RIDGE = (4.0, 4.0), (2.8, 5.8), (0.0, 6.9)
DOOR_W, DOOR_H = 3.4, 3.6


def gable_top(x):
    ax = abs(x)
    if ax <= KNEE[0]:
        return RIDGE[1] - (RIDGE[1] - KNEE[1]) * ax / KNEE[0]
    return KNEE[1] - (KNEE[1] - EAVE[1]) * (ax - KNEE[0]) / (EAVE[0] - KNEE[0])


def roof_rows(a, b, yc, ylen, rows, colors):
    """A roof slope made of overlapping shingle rows, stepped for a chunky outline."""
    out = []
    a, b = Vector(a), Vector(b)
    for i in range(rows):
        t0, t1 = i / rows, (i + 1) / rows + 0.04
        p, q = a.lerp(b, t0), a.lerp(b, min(1.0, t1))
        out.append(strip("shingles", p, q, yc, ylen, 0.14, colors[i % 2], lift=0.07 + 0.045 * (i % 2)))
    return out


def barn():
    parts = []
    hw, hd = BARN_W / 2, BARN_D / 2
    # Walls: red board-and-batten.
    for s in (1, -1):
        parts.append(rbox("side_wall", (s * hw, 0, WALL_H / 2), (0.2, BARN_D, WALL_H), BARN_RED, bevel=0.02))
        for k in range(24):
            y = -hd + 0.2 + k * (BARN_D - 0.4) / 23
            parts.append(rbox("batten", (s * (hw + 0.12), y, WALL_H / 2), (0.05, 0.08, WALL_H - 0.1),
                              BARN_RED_DARK, bevel=0.01))
    side = (hw + DOOR_W / 2) / 2
    for s in (1, -1):
        parts.append(rbox("front_wall", (s * side, hd, WALL_H / 2), (hw - DOOR_W / 2, 0.2, WALL_H), BARN_RED,
                          bevel=0.02))
    parts.append(rbox("lintel", (0, hd, (DOOR_H + WALL_H) / 2), (DOOR_W, 0.2, WALL_H - DOOR_H), BARN_RED,
                      bevel=0.02))
    outline = [(-hw, WALL_H), (hw, WALL_H), (KNEE[0], KNEE[1]), RIDGE, (-KNEE[0], KNEE[1])]
    parts.append(prism("front_gable", outline, hd, 0.2, BARN_RED))
    back = [(-hw, 0), (hw, 0), (hw, WALL_H), (KNEE[0], KNEE[1]), RIDGE, (-KNEE[0], KNEE[1]), (-hw, WALL_H)]
    parts.append(prism("back_gable", back, -hd, 0.2, BARN_RED))
    for face_y, sign in ((hd, 1), (-hd, -1)):
        for k in range(21):
            x = -hw + 0.25 + k * (BARN_W - 0.5) / 20
            z0 = 0.05
            if face_y > 0 and abs(x) < DOOR_W / 2 + 0.1:
                z0 = DOOR_H + 0.05
            z1 = gable_top(x) - 0.12
            if z1 - z0 < 0.2:
                continue
            parts.append(rbox("batten", (x, face_y + sign * 0.12, (z0 + z1) / 2), (0.08, 0.05, z1 - z0),
                              BARN_RED_DARK, bevel=0.01))
    # White trim: corner boards, door frame, gable edges.
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(rbox("corner", (sx * (hw + 0.06), sy * (hd + 0.06), WALL_H / 2), (0.3, 0.3, WALL_H),
                              TRIM, bevel=0.03))
    for sx in (1, -1):
        parts.append(rbox("jamb", (sx * (DOOR_W / 2 + 0.1), hd + 0.12, DOOR_H / 2), (0.2, 0.08, DOOR_H), TRIM,
                          bevel=0.02))
    parts.append(rbox("head", (0, hd + 0.12, DOOR_H + 0.1), (DOOR_W + 0.4, 0.08, 0.2), TRIM, bevel=0.02))
    parts.append(rbox("track", (0, hd + 0.2, DOOR_H + 0.32), (DOOR_W * 2 + 0.2, 0.1, 0.12), IRON, bevel=0.02))
    for y in (hd + 0.14, -hd - 0.14):
        for a, b in (((-hw - 0.3, EAVE[1] - 0.2), (-KNEE[0], KNEE[1])), ((-KNEE[0], KNEE[1]), RIDGE),
                     (RIDGE, KNEE), (KNEE, (hw + 0.3, EAVE[1] - 0.2))):
            parts.append(strip("fascia", a, b, y, 0.1, 0.24, TRIM, lift=0.05))
    # Hayloft door with white X bracing.
    loft_z = 4.75
    parts.append(rbox("loft_door", (0, hd + 0.13, loft_z), (1.4, 0.06, 1.3), BARN_RED, bevel=0.02))
    for x0, z0, x1, z1 in ((-0.7, loft_z - 0.65, 0.7, loft_z - 0.65), (-0.7, loft_z + 0.65, 0.7, loft_z + 0.65)):
        parts.append(strip("loft_trim", (x0 - 0.05, z0), (x1 + 0.05, z1), hd + 0.18, 0.05, 0.12, TRIM))
    for sx in (1, -1):
        parts.append(rbox("loft_trim", (sx * 0.7, hd + 0.18, loft_z), (0.12, 0.05, 1.42), TRIM, bevel=0.01))
    parts.append(strip("loft_x", (-0.62, loft_z - 0.57), (0.62, loft_z + 0.57), hd + 0.18, 0.04, 0.1, TRIM))
    parts.append(strip("loft_x", (-0.62, loft_z + 0.57), (0.62, loft_z - 0.57), hd + 0.18, 0.04, 0.1, TRIM))
    parts.append(rbox("hay_beam", (0, hd + 0.9, 6.2), (0.16, 1.8, 0.16), WOOD_DARK, bevel=0.02))
    parts.append(tube("hook", [Vector((0, hd + 1.65, 6.12)), Vector((0, hd + 1.65, 5.7)),
                               Vector((0, hd + 1.55, 5.62))], 0.025, IRON))
    # Roof: gambrel, dark shingle rows with overhang.
    ylen = BARN_D + 0.8
    eave_out = (-hw - 0.4, EAVE[1] - 0.25)
    for a, b, rows in ((eave_out, (-KNEE[0], KNEE[1]), 5), ((-KNEE[0], KNEE[1]), RIDGE, 4),
                       (RIDGE, KNEE, 4), (KNEE, (hw + 0.4, EAVE[1] - 0.25), 5)):
        parts += roof_rows(a, b, 0, ylen, rows, (ROOF, ROOF_DARK))  # always left to right: normal points out
    parts.append(rbox("ridge_cap", (0, 0, RIDGE[1] + 0.2), (0.35, ylen + 0.05, 0.2), ROOF_DARK, bevel=0.06))
    # Weather vane on the front of the ridge.
    vy = hd - 0.6
    parts.append(tube("vane_pole", [Vector((0, vy, RIDGE[1] + 0.2)), Vector((0, vy, RIDGE[1] + 1.3))], 0.025,
                      IRON))
    parts.append(tube("vane_ns", [Vector((0, vy - 0.3, RIDGE[1] + 0.9)), Vector((0, vy + 0.3, RIDGE[1] + 0.9))],
                      0.015, IRON))
    parts.append(tube("vane_ew", [Vector((-0.3, vy, RIDGE[1] + 0.9)), Vector((0.3, vy, RIDGE[1] + 0.9))],
                      0.015, IRON))
    parts.append(prism("arrow", [(-0.45, RIDGE[1] + 1.15), (0.3, RIDGE[1] + 1.15), (0.3, RIDGE[1] + 1.08),
                                 (0.48, RIDGE[1] + 1.2), (0.3, RIDGE[1] + 1.32), (0.3, RIDGE[1] + 1.25),
                                 (-0.45, RIDGE[1] + 1.25)], vy, 0.03, GOLD))
    parts.append(br.lathe("vane_ball", [(0, RIDGE[1] + 1.28)] + [
        (0.05 * math.sin(math.pi * t), RIDGE[1] + 1.28 + 0.1 * (1 - math.cos(math.pi * t)) / 2)
        for t in [k / 8 for k in range(1, 8)]] + [(0, RIDGE[1] + 1.38)], solid(GOLD), segments=16))
    parts.append(rbox("floor", (0, 0, 0.02), (BARN_W - 0.2, BARN_D - 0.2, 0.04), DIRT, bevel=0.01))
    return parts


def barn_door():
    """One sliding barn door, 1.75 x 3.6 m. Two close the doorway: place them at
    x = -0.87 and +0.87, y = 5.22 (Blender) on the barn, and slide along X."""
    w, h = 1.75, 3.6
    parts = [rbox("panel", (0, 0, h / 2), (w, 0.08, h), BARN_RED, bevel=0.02)]
    for k in range(5):
        x = -w / 2 + 0.2 + k * (w - 0.4) / 4
        parts.append(rbox("batten", (x, 0.05, h / 2), (0.06, 0.04, h - 0.1), BARN_RED_DARK, bevel=0.01))
    for z in (0.08, h - 0.08, h / 2):
        parts.append(rbox("rail", (0, 0.08, z), (w, 0.05, 0.16), TRIM, bevel=0.015))
    for sx in (1, -1):
        parts.append(rbox("stile", (sx * (w / 2 - 0.08), 0.08, h / 2), (0.16, 0.05, h), TRIM, bevel=0.015))
    for z0, z1 in ((0.16, h / 2 - 0.08), (h / 2 + 0.08, h - 0.16)):
        parts.append(strip("brace", (-w / 2 + 0.12, z0), (w / 2 - 0.12, z1), 0.09, 0.04, 0.13, TRIM))
        parts.append(strip("brace", (-w / 2 + 0.12, z1), (w / 2 - 0.12, z0), 0.09, 0.04, 0.13, TRIM))
    for sx in (1, -1):
        parts.append(cyl("roller", (sx * 0.55, 0.06, h + 0.12), 0.07, 0.05, IRON, segments=16))
        parts[-1] = xf(parts[-1], Matrix.Translation((sx * 0.55, 0.06, h + 0.12)) @ Matrix.Rotation(
            math.pi / 2, 4, "X") @ Matrix.Translation((-sx * 0.55, -0.06, -h - 0.12)))
    parts.append(cyl("handle", (0.55, 0.14, 1.2), 0.02, 0.4, IRON, segments=12))
    return parts


# --------------------------------------------------------------------------
# Stalls and fences
# --------------------------------------------------------------------------

def plank_wall(name, length, z0, z1, rows, thick, colors, axis="Y"):
    parts = []
    step = (z1 - z0) / rows
    for i in range(rows):
        z = z0 + step * (i + 0.5)
        size = (thick, length, step - 0.025) if axis == "Y" else (length, thick, step - 0.025)
        parts.append(rbox(name, (0, 0, z), size, colors[i % len(colors)], bevel=0.015))
    return parts


def stall_divider():
    """Wall between two horse stalls: 3 m long (along Y), 1.6 m tall."""
    parts = plank_wall("plank", 3.0, 0.05, 1.15, 5, 0.06, (WOOD, WOOD_LIGHT, WOOD))
    for y in (-1.5, 1.5):
        parts.append(rbox("post", (0, y, 0.85), (0.14, 0.14, 1.7), WOOD_DARK, bevel=0.025))
    parts.append(rbox("top_rail", (0, 0, 1.62), (0.1, 3.0, 0.08), WOOD_DARK, bevel=0.02))
    parts.append(rbox("mid_rail", (0, 0, 1.18), (0.1, 3.0, 0.07), WOOD_DARK, bevel=0.02))
    for k in range(1, 12):
        parts.append(cyl("bar", (0, -1.5 + k * 0.25, 1.4), 0.013, 0.42, IRON, segments=10))
    return parts


def stall_gate():
    """Dutch stall door, 1.2 m wide; origin at the hinge, opens along +X."""
    w = 1.2
    parts = []
    for part in plank_wall("plank", w, 0.05, 1.25, 1, 0.05, (WOOD,), axis="X"):
        parts.append(xf(part, Matrix.Translation((w / 2, 0, 0))))
    for k in range(6):
        x = 0.1 + k * (w - 0.2) / 5
        parts.append(rbox("board_line", (x, 0.03, 0.65), (0.02, 0.02, 1.15), WOOD_DARK, bevel=0.004))
    for z in (0.1, 1.2):
        parts.append(rbox("rail", (w / 2, 0.05, z), (w, 0.05, 0.12), WOOD_DARK, bevel=0.015))
    parts.append(strip("brace", (0.08, 0.16), (w - 0.08, 1.14), 0.05, 0.05, 0.12, WOOD_DARK))
    for z in (0.3, 1.0):
        parts.append(rbox("hinge", (0.12, 0.06, z), (0.24, 0.03, 0.05), IRON, bevel=0.008))
    parts.append(cyl("latch", (w - 0.08, 0.08, 0.95), 0.025, 0.06, IRON, segments=12))
    return parts


def fence_section():
    """2 m of rail fence with its left post; tile them along X and cap the end
    with fence_post.glb."""
    parts = [rbox("post", (-1.0, 0, 0.55), (0.14, 0.14, 1.1), WOOD_DARK, bevel=0.03)]
    parts.append(xf(br.lathe("cap", [(0, 0), (0.09, 0), (0.09, 0.03), (0.05, 0.08), (0, 0.09)], solid(WOOD_DARK),
                             segments=8), Matrix.Translation((-1.0, 0, 1.1)) @ Matrix.Rotation(math.pi / 8, 4, "Z")))
    for z, tilt in ((0.45, 0.0), (0.85, 0.0)):
        parts.append(rbox("rail", (0, 0.08, z), (2.1, 0.05, 0.13), WOOD, bevel=0.02))
    return parts


def fence_post():
    return [rbox("post", (0, 0, 0.55), (0.14, 0.14, 1.1), WOOD_DARK, bevel=0.03),
            xf(br.lathe("cap", [(0, 0), (0.09, 0), (0.09, 0.03), (0.05, 0.08), (0, 0.09)], solid(WOOD_DARK),
                        segments=8), Matrix.Translation((0, 0, 1.1)) @ Matrix.Rotation(math.pi / 8, 4, "Z"))]


def fence_gate():
    """1.6 m gate; origin at the hinge post, swings open along +X."""
    w = 1.6
    parts = []
    for z in (0.25, 0.6, 0.95):
        parts.append(rbox("rail", (w / 2, 0, z), (w, 0.05, 0.12), WOOD, bevel=0.02))
    for x in (0.06, w - 0.06):
        parts.append(rbox("stile", (x, 0, 0.6), (0.1, 0.06, 0.9), WOOD_DARK, bevel=0.02))
    parts.append(strip("brace", (0.1, 0.25), (w - 0.1, 0.95), 0.04, 0.04, 0.11, WOOD_DARK))
    for z in (0.3, 0.9):
        parts.append(rbox("hinge", (0.1, 0.04, z), (0.2, 0.02, 0.05), IRON, bevel=0.006))
    return parts


# --------------------------------------------------------------------------
# Chicken coop and friends
# --------------------------------------------------------------------------

def egg_shape(name, height=0.058, width=0.021, color=EGG):
    prof = [(0.0, 0.0)]
    for k in range(1, 12):
        a = math.pi * k / 12
        prof.append((width * math.sin(a) * (1 + 0.12 * math.cos(a)), height * (1 - math.cos(a)) / 2))
    prof.append((0.0, height))
    return lathe(name, prof, solid(color), segments=20)


def egg():
    return [egg_shape("egg")]


def egg_brown():
    return [egg_shape("egg", color=EGG_BROWN)]


def nest_straw(name, w, d, z, seed=5):
    rng = random.Random(seed)
    shapes = [("e", (0, 0, z), (w * 0.52, d * 0.52, 0.05))]
    for _ in range(6):
        shapes.append(("e", (rng.uniform(-w, w) * 0.3, rng.uniform(-d, d) * 0.3, z + 0.02), (0.07, 0.06, 0.04)))
    return blobs(name, shapes, straw, voxel=0.012, smooth=3, faces=1500)


def nest_box():
    """Open wooden nesting box with straw and two eggs, 0.4 x 0.35 x 0.28 m."""
    w, d, h = 0.4, 0.35, 0.28
    parts = [rbox("bottom", (0, 0, 0.015), (w, d, 0.03), WOOD_DARK, bevel=0.008)]
    for s in (1, -1):
        parts.append(rbox("side", (s * (w / 2 - 0.015), 0, h / 2), (0.03, d, h), WOOD, bevel=0.008))
    parts.append(rbox("back", (0, -d / 2 + 0.015, h / 2), (w, 0.03, h), WOOD, bevel=0.008))
    parts.append(rbox("lip", (0, d / 2 - 0.015, 0.06), (w, 0.03, 0.12), WOOD_LIGHT, bevel=0.008))
    parts.append(nest_straw("straw", w - 0.06, d - 0.06, 0.07))
    for x, y, rot, col in ((-0.05, 0.0, 0.3, EGG), (0.06, 0.03, -0.5, EGG_BROWN)):
        e = egg_shape("egg", color=col)
        parts.append(xf(e, Matrix.Translation((x, y, 0.135)) @ Matrix.Rotation(rot + math.pi / 2, 4, "Y")
                        @ Matrix.Translation((0, 0, -0.029))))
    return parts


def chicken_coop():
    """Little coop on legs with a ramp, window and a side nesting box.
    1.6 x 1.2 m footprint, 2.1 m to the ridge."""
    w, d, floor, wall_top, ridge = 1.6, 1.2, 0.5, 1.4, 2.0
    parts = []
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(rbox("leg", (sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), (floor + 0.05) / 2),
                              (0.1, 0.1, floor + 0.05), WOOD_DARK, bevel=0.02))
    parts.append(rbox("floor", (0, 0, floor), (w + 0.04, d + 0.04, 0.08), WOOD_DARK, bevel=0.02))
    wall_h = wall_top - floor
    for s in (1, -1):
        parts.append(rbox("side_wall", (s * w / 2, 0, floor + wall_h / 2), (0.06, d, wall_h), WOOD, bevel=0.015))
    for y in (d / 2, -d / 2):
        gable = [(-w / 2, floor), (w / 2, floor), (w / 2, wall_top), (0, ridge), (-w / 2, wall_top)]
        parts.append(prism("end_wall", gable, y, 0.06, WOOD))
        for k in range(7):
            x = -w / 2 + 0.12 + k * (w - 0.24) / 6
            top = wall_top + (ridge - wall_top) * (1 - abs(x) / (w / 2)) - 0.08
            parts.append(rbox("board_line", (x, y + (0.035 if y > 0 else -0.035), (floor + top) / 2),
                              (0.025, 0.02, top - floor - 0.05), WOOD_DARK, bevel=0.005))
    for s in (1, -1):
        for k in range(6):
            y = -d / 2 + 0.12 + k * (d - 0.24) / 5
            parts.append(rbox("board_line", (s * (w / 2 + 0.035), y, floor + wall_h / 2), (0.02, 0.025, wall_h - 0.05),
                              WOOD_DARK, bevel=0.005))
    # Trim at the corners.
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(rbox("corner", (sx * (w / 2 + 0.02), sy * (d / 2 + 0.02), floor + wall_h / 2),
                              (0.1, 0.1, wall_h), TRIM, bevel=0.015))
    # Pop door and ramp.
    fy = d / 2 + 0.04
    parts.append(rbox("door_hole", (-0.35, fy, floor + 0.22), (0.3, 0.03, 0.36), DARK, bevel=0.01))
    for sx in (1, -1):
        parts.append(rbox("door_trim", (-0.35 + sx * 0.17, fy + 0.02, floor + 0.22), (0.05, 0.03, 0.42), TRIM,
                          bevel=0.008))
    parts.append(rbox("door_trim", (-0.35, fy + 0.02, floor + 0.43), (0.39, 0.03, 0.05), TRIM, bevel=0.008))
    ramp_top, ramp_bot = Vector((-0.35, fy, floor + 0.02)), Vector((-0.35, fy + 0.85, 0.02))
    ang = math.atan2(ramp_top.z - ramp_bot.z, ramp_bot.y - ramp_top.y)
    ramp = rbox("ramp", (0, 0, 0), (0.3, (ramp_bot - ramp_top).length, 0.04), WOOD_LIGHT, bevel=0.01)
    mid = (ramp_top + ramp_bot) / 2
    parts.append(xf(ramp, Matrix.Translation(mid) @ Matrix.Rotation(-ang, 4, "X")))
    for k in range(5):
        t = (k + 0.5) / 5
        p = ramp_top.lerp(ramp_bot, t)
        cleat = rbox("cleat", (0, 0, 0), (0.28, 0.03, 0.03), WOOD_DARK, bevel=0.006)
        parts.append(xf(cleat, Matrix.Translation(p + Vector((0, 0, 0.035))) @ Matrix.Rotation(-ang, 4, "X")))
    # Window with a cross.
    wx, wz = 0.38, 1.05
    parts.append(rbox("window", (wx, fy, wz), (0.36, 0.03, 0.32), GLASS, bevel=0.01))
    for x0, z0, sx, sz in ((wx, wz + 0.17, 0.44, 0.05), (wx, wz - 0.17, 0.44, 0.05), (wx, wz, 0.04, 0.32),
                           (wx - 0.2, wz, 0.05, 0.38), (wx + 0.2, wz, 0.05, 0.38), (wx, wz, 0.36, 0.035)):
        parts.append(rbox("window_trim", (x0, fy + 0.025, z0), (sx, 0.03, sz), TRIM, bevel=0.008))
    # Roof: red shingle rows with overhang.
    ylen = d + 0.3
    eave_l, eave_r, top = (-w / 2 - 0.2, wall_top - 0.12), (w / 2 + 0.2, wall_top - 0.12), (0.0, ridge)
    parts += roof_rows(eave_l, top, 0, ylen, 4, (COOP_ROOF, COOP_ROOF_DARK))
    parts += roof_rows(top, eave_r, 0, ylen, 4, (COOP_ROOF, COOP_ROOF_DARK))
    parts.append(rbox("ridge_cap", (0, 0, ridge + 0.14), (0.16, ylen + 0.04, 0.12), COOP_ROOF_DARK, bevel=0.04))
    # Nesting box bump on the right side with a sloped lid.
    bx0, bx1, bz0, bz1 = w / 2 + 0.03, w / 2 + 0.4, 0.62, 1.0
    parts.append(rbox("nest_box", ((bx0 + bx1) / 2, 0, (bz0 + bz1) / 2), (bx1 - bx0, 0.8, bz1 - bz0), WOOD,
                      bevel=0.015))
    for k in range(3):
        parts.append(rbox("nest_line", (bx1 + 0.005, -0.4 + (k + 1) * 0.2, (bz0 + bz1) / 2), (0.02, 0.025, 0.36),
                          WOOD_DARK, bevel=0.004))
    parts.append(strip("lid", (bx0 - 0.02, bz1 + 0.12), (bx1 + 0.06, bz1 - 0.02), 0, 0.88, 0.05, COOP_ROOF,
                       lift=0.02))
    for y in (-0.2, 0.2):
        parts.append(cyl("lid_hinge", (bx0 + 0.02, y, bz1 + 0.12), 0.015, 0.08, IRON, segments=10))
    return parts


def chicken_feeder():
    """Hanging-style galvanized feeder standing on the ground, 0.45 m tall."""
    prof = [(0, 0.0), (0.2, 0.0), (0.22, 0.03), (0.2, 0.06), (0.1, 0.06), (0.1, 0.4), (0.12, 0.41), (0.12, 0.44),
            (0, 0.45)]
    parts = [lathe("feeder", prof, lambda co, n: STEEL if co[2] > 0.07 else STEEL_DARK, segments=32)]
    parts.append(cyl("feed", (0, 0, 0.055), 0.17, 0.02, GRAIN, segments=32))
    parts.append(tube("hanger", [Vector((0, 0, 0.44)), Vector((0, 0, 0.5)), Vector((0.03, 0, 0.53)),
                                 Vector((0, 0, 0.56)), Vector((-0.03, 0, 0.53)), Vector((0, 0, 0.5))], 0.005, IRON))
    return parts


# --------------------------------------------------------------------------
# Farmyard odds and ends
# --------------------------------------------------------------------------

def water_trough():
    """Wooden water trough, 1.6 x 0.6 m, 0.55 m tall."""
    w, d, h = 1.6, 0.6, 0.55
    parts = [rbox("bottom", (0, 0, 0.12), (w, d, 0.06), WOOD_DARK, bevel=0.015)]
    for s in (1, -1):
        parts.append(rbox("long_side", (0, s * (d / 2 - 0.03), 0.12 + (h - 0.12) / 2), (w, 0.06, h - 0.12), WOOD,
                          bevel=0.015))
        parts.append(rbox("end", (s * (w / 2 - 0.03), 0, 0.12 + (h - 0.12) / 2), (0.06, d, h - 0.12), WOOD,
                          bevel=0.015))
        for sy in (1, -1):
            parts.append(rbox("leg", (s * (w / 2 - 0.12), sy * (d / 2 - 0.08), 0.06), (0.1, 0.1, 0.12), WOOD_DARK,
                              bevel=0.015))
    for x in (-0.5, 0.5):
        parts.append(rbox("band", (x, 0, 0.12 + (h - 0.12) / 2), (0.05, d + 0.02, h - 0.1), IRON, bevel=0.01))
    parts.append(rbox("water", (0, 0, h - 0.1), (w - 0.1, d - 0.1, 0.04), WATER, bevel=0.01))
    return parts


def feed_bucket():
    """Galvanized bucket of grain with a wire handle, 0.3 m tall."""
    outer = [(0, 0.0), (0.12, 0.0), (0.15, 0.3), (0.16, 0.31), (0.14, 0.31), (0.115, 0.03), (0, 0.03)]
    parts = [lathe("bucket", outer, lambda co, n: STEEL_DARK if abs(co[2] - 0.15) < 0.015 else STEEL, segments=32)]
    parts.append(cyl("grain", (0, 0, 0.25), 0.138, 0.03, GRAIN, segments=32))
    parts.append(blobs("grain_heap", [("e", (0, 0, 0.26), (0.12, 0.12, 0.04))], GRAIN, voxel=0.01, smooth=2))
    pts = [Vector((0.15 * math.cos(a), 0, 0.3 + 0.18 * math.sin(a))) for a in
           [math.radians(d) for d in range(0, 181, 15)]]
    parts.append(tube("handle", pts, 0.005, IRON))
    return parts


def feed_sack():
    """Tied grain sack, 0.75 m tall, with a green band on the front."""
    shapes = [("e", (0, 0, 0.2), (0.28, 0.21, 0.22)), ("e", (0, 0, 0.38), (0.25, 0.19, 0.18)),
              ("e", (0.12, 0.02, 0.12), (0.16, 0.16, 0.12)), ("e", (-0.13, -0.02, 0.13), (0.15, 0.16, 0.12)),
              ("c", (0, 0, 0.5), (0, 0, 0.6), 0.1, 0.055)]

    def color(co, n):
        if 0.555 < co[2] < 0.6:
            return TWINE
        if 0.24 < co[2] < 0.34 and n[1] > 0.1:
            return SACK_BAND
        return SACK
    sack = blobs("sack", shapes, color, voxel=0.012, smooth=4, faces=3000)
    # Ruffled top above the tie.
    rng = random.Random(11)
    ruffle = []
    for k in range(9):
        a = k / 9 * math.tau
        base = (0.035 * math.cos(a), 0.03 * math.sin(a), 0.6)
        tip = (0.11 * math.cos(a + rng.uniform(-0.2, 0.2)), 0.09 * math.sin(a), 0.7 + rng.uniform(-0.02, 0.03))
        ruffle.append((base, tip))
    top = spikes("ruffle", ruffle, solid(SACK), width=0.06, thick=0.02)
    return lift_to_floor([sack, top])


def wheelbarrow():
    """Wooden wheelbarrow, 1.4 m long, tray 0.6 m wide; wheel at the front (+Y)."""
    parts = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.3, radius2=0.46, depth=0.28,
                          matrix=Matrix.Rotation(math.pi / 4, 4, "Z"))
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z > 0.9], context="FACES")
    tray = new_object("tray", bm)
    sol = tray.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.03
    bev = tray.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.012
    bev.segments = 2
    apply_modifiers(tray)
    select_only(tray)
    bpy.ops.object.shade_smooth()
    paint(tray, solid(WOOD))
    parts.append(xf(tray, Matrix.Translation((0, 0.05, 0.52)) @ Matrix.Diagonal((1.0, 1.25, 1.0, 1.0))))
    for sx in (1, -1):
        parts.append(tube("handle", [Vector((sx * 0.2, 0.62, 0.3)), Vector((sx * 0.22, 0.0, 0.38)),
                                     Vector((sx * 0.28, -0.75, 0.6))], 0.022, WOOD_DARK))
        parts.append(tube("grip", [Vector((sx * 0.28, -0.62, 0.575)), Vector((sx * 0.29, -0.8, 0.61))], 0.028,
                          DARK))
        parts.append(tube("leg", [Vector((sx * 0.22, -0.3, 0.45)), Vector((sx * 0.24, -0.34, 0.0))], 0.02,
                          WOOD_DARK))
    wheel = cyl("wheel", (0, 0, 0), 0.2, 0.07, DARK, segments=24, bevel=0.02)
    hub = cyl("hub", (0, 0, 0), 0.07, 0.09, STEEL, segments=16)
    for part in (wheel, hub):
        parts.append(xf(part, Matrix.Translation((0, 0.7, 0.2)) @ Matrix.Rotation(math.pi / 2, 4, "Y")))
    parts.append(tube("axle", [Vector((-0.2, 0.7, 0.2)), Vector((0.2, 0.7, 0.2))], 0.015, IRON))
    return parts


def milk_can():
    """Old-fashioned steel milk churn, 0.7 m tall."""
    prof = [(0, 0.0), (0.17, 0.0), (0.18, 0.02), (0.18, 0.45), (0.1, 0.55), (0.1, 0.62), (0.13, 0.63),
            (0.13, 0.67), (0.08, 0.7), (0, 0.7)]
    parts = [lathe("can", prof, lambda co, n: STEEL_DARK if abs(co[2] - 0.2) < 0.02 or co[2] > 0.62 else STEEL,
                   segments=32)]
    for sx in (1, -1):
        parts.append(tube("handle", [Vector((sx * 0.1, 0, 0.56)), Vector((sx * 0.17, 0, 0.58)),
                                     Vector((sx * 0.17, 0, 0.5)), Vector((sx * 0.14, 0, 0.47))], 0.012, STEEL_DARK))
    return parts


def horse_saddle():
    """Saddle for horse_*.glb, origin at the seat's base center; front is +Y.
    Sits on the horse's back at (0, 0, 1.16) in Blender (y = 1.16 in Godot)."""
    shapes = [("e", (0, 0, 0.06), (0.2, 0.3, 0.06)), ("e", (0, 0.2, 0.12), (0.1, 0.08, 0.08)),
              ("e", (0, -0.2, 0.1), (0.16, 0.08, 0.07))]
    seat = blobs("seat", shapes, solid(srgb(0.55, 0.28, 0.14)), voxel=0.012, smooth=4, faces=2000)
    horn = blobs("horn", [("c", (0, 0.24, 0.16), (0, 0.27, 0.26), 0.03, 0.035), ("e", (0, 0.27, 0.27),
                                                                                     (0.05, 0.05, 0.025))],
                 solid(srgb(0.4, 0.2, 0.1)), voxel=0.008, smooth=2)
    blanket = rbox("blanket", (0, 0, -0.01), (0.62, 0.7, 0.04), srgb(0.2, 0.42, 0.75), bevel=0.02)
    parts = [blanket, seat, horn]
    for sx in (1, -1):
        parts.append(tube("strap", [Vector((sx * 0.2, 0.02, 0.03)), Vector((sx * 0.32, 0.02, -0.3))], 0.015,
                          srgb(0.4, 0.2, 0.1)))
        parts.append(rbox("stirrup", (sx * 0.34, 0.02, -0.36), (0.03, 0.12, 0.1), IRON, bevel=0.01))
    return parts


PROPS = {
    "hay_bale": hay_bale, "hay_round": hay_round, "hay_pile": hay_pile, "pitchfork": pitchfork,
    "barn": barn, "barn_door": barn_door, "stall_divider": stall_divider, "stall_gate": stall_gate,
    "fence_section": fence_section, "fence_post": fence_post, "fence_gate": fence_gate,
    "chicken_coop": chicken_coop, "nest_box": nest_box, "egg": egg, "egg_brown": egg_brown,
    "chicken_feeder": chicken_feeder, "water_trough": water_trough, "feed_bucket": feed_bucket,
    "feed_sack": feed_sack, "wheelbarrow": wheelbarrow, "milk_can": milk_can, "horse_saddle": horse_saddle,
}

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if a in PROPS]
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        reset_scene()
        export(name, fn())
