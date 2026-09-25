"""Cartoony household props: kitchen appliances, living room and bedroom
furniture, generic game consoles, art supplies, cameras, sports and gym gear.

Run with Blender 5.x:
    blender --background --python props/build_house_props.py [name ...]
or with the bpy pip module (Python 3.13):
    python props/build_house_props.py [name ...]

Every prop is its own .glb in props/house/, real-world scale in meters,
origin at the bottom center, front facing +Z in Godot (modeled facing +Y, turned at export).
Colors are vertex colors. Props with a display keep it as a separate mesh
named "screen" so a game can put a ViewportTexture or video on it.

The consoles are generic: they echo familiar silhouettes but carry no
logos, names or trade dress.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_farm_props as fp  # noqa: E402
from build_farm_props import (  # noqa: E402
    Matrix, Vector, blobs, bpy, cyl, join, lathe, make_material, prism, rbox, reset_scene, srgb, strip, tube, xf,
)
from build_pets import face_plus_z  # noqa: E402

OUT = os.path.join(HERE, "house")
os.makedirs(OUT, exist_ok=True)

WHITE = srgb(0.95, 0.95, 0.93)
OFFWHITE = srgb(0.9, 0.89, 0.85)
STEEL = srgb(0.76, 0.78, 0.82)
STEEL_DARK = srgb(0.55, 0.57, 0.62)
CHROME = srgb(0.88, 0.9, 0.93)
BLACK = srgb(0.1, 0.1, 0.12)
CHARCOAL = srgb(0.22, 0.22, 0.25)
GREY = srgb(0.5, 0.5, 0.53)
GLASS = srgb(0.1, 0.13, 0.2)
GLASS_LIGHT = srgb(0.62, 0.8, 0.92)
SCREEN = srgb(0.12, 0.2, 0.36)
GLARE = srgb(0.3, 0.42, 0.62)
RED = srgb(0.88, 0.2, 0.18)
BLUE = srgb(0.2, 0.5, 0.92)
TEAL = srgb(0.2, 0.62, 0.62)
GREEN = srgb(0.3, 0.72, 0.32)
YELLOW = srgb(0.98, 0.82, 0.2)
ORANGE = srgb(0.96, 0.52, 0.14)
PURPLE = srgb(0.55, 0.35, 0.8)
PINK = srgb(0.95, 0.55, 0.65)
WOOD = srgb(0.72, 0.5, 0.3)
WOOD_DARK = srgb(0.5, 0.32, 0.18)
WOOD_LIGHT = srgb(0.86, 0.68, 0.45)
FABRIC = srgb(0.28, 0.55, 0.6)
FABRIC_DARK = srgb(0.2, 0.42, 0.47)
BLANKET = srgb(0.3, 0.45, 0.8)
BLANKET_DARK = srgb(0.22, 0.34, 0.66)
SHEET = srgb(0.97, 0.96, 0.93)
BREAD = srgb(0.98, 0.86, 0.6)
TOAST = srgb(0.86, 0.58, 0.28)
CRUST = srgb(0.6, 0.34, 0.14)
LED_GREEN = srgb(0.3, 1.0, 0.45)
LED_BLUE = srgb(0.3, 0.7, 1.0)
LEATHER = srgb(0.16, 0.15, 0.17)
RUBBER = srgb(0.14, 0.14, 0.15)

FRONT = Matrix.Rotation(-math.pi / 2, 4, "X")   # lathe/cyl axis Z -> +Y
SIDEWAYS = Matrix.Rotation(math.pi / 2, 4, "Y")  # lathe/cyl axis Z -> +X


def solid(c):
    return lambda co, n: c


def at(obj, pos, rot=None):
    m = Matrix.Translation(pos)
    if rot is not None:
        m = m @ rot
    return xf(obj, m)


def ball(name, radius, color_fn, rings=24, segments=40):
    prof = [(0.0, -radius)]
    for k in range(1, rings):
        a = -math.pi / 2 + math.pi * k / rings
        prof.append((radius * math.cos(a), radius * math.sin(a)))
    prof.append((0.0, radius))
    return lathe(name, prof, color_fn, segments=segments)


def rod(name, a, b, radius, color):
    return tube(name, [Vector(a), Vector(b)], radius, color)


def knob(pos, radius=0.02, depth=0.02, color=BLACK):
    return at(cyl("knob", (0, 0, 0), radius, depth, color, segments=16), pos, FRONT)


def screen_panel(center, size):
    """The display surface, kept as its own mesh named "screen"."""
    return rbox("screen", center, size, SCREEN, bevel=0.004)


def export(name, parts):
    screen = [p for p in parts if p.name.startswith("screen")]
    body_parts = [p for p in parts if p not in screen]
    body = body_parts[0]
    if len(body_parts) > 1:
        join(body_parts[1:], body)
    body.name = name
    mat = make_material(name)
    body.data.materials.clear()
    body.data.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if screen:
        s = screen[0]
        if len(screen) > 1:
            join(screen[1:], s)
        s.name = "screen"
        s.data.materials.clear()
        s.data.materials.append(make_material(name + "_screen"))
        s.parent = body
        tris += sum(len(p.vertices) - 2 for p in s.data.polygons)
    face_plus_z()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL")
    print(f"{name}: {tris} triangles")


# --------------------------------------------------------------------------
# Kitchen
# --------------------------------------------------------------------------

def fridge():
    """Top-freezer fridge, 0.75 x 0.7 x 1.8 m."""
    w, d, h = 0.75, 0.7, 1.8
    parts = [rbox("body", (0, -0.02, h / 2 + 0.03), (w, d - 0.04, h - 0.06), WHITE, bevel=0.03)]
    parts.append(rbox("freezer_door", (0, d / 2 - 0.02, 1.52), (w, 0.05, 0.52), WHITE, bevel=0.03))
    parts.append(rbox("door", (0, d / 2 - 0.02, 0.66), (w, 0.05, 1.16), WHITE, bevel=0.03))
    parts.append(rbox("gap", (0, d / 2 - 0.04, 1.255), (w - 0.01, 0.04, 0.012), GREY, bevel=0.002))
    for z0, z1 in ((1.33, 1.62), (0.8, 1.2)):
        parts.append(rod("handle", (-w / 2 + 0.07, d / 2 + 0.04, z0), (-w / 2 + 0.07, d / 2 + 0.04, z1), 0.014, CHROME))
        for z in (z0, z1):
            parts.append(rod("post", (-w / 2 + 0.07, d / 2, z), (-w / 2 + 0.07, d / 2 + 0.045, z), 0.01, CHROME))
    rng = random.Random(4)
    for col in (RED, YELLOW, BLUE, GREEN):
        x, z = rng.uniform(-0.15, 0.25), rng.uniform(0.9, 1.15)
        parts.append(rbox("magnet", (x, d / 2 + 0.01, z), (0.05, 0.015, 0.05), col, bevel=0.007))
    parts.append(rbox("note", (0.1, d / 2 + 0.006, 1.02), (0.12, 0.004, 0.15), srgb(1.0, 0.95, 0.6), bevel=0.001))
    for sx in (1, -1):
        parts.append(rbox("foot", (sx * (w / 2 - 0.08), d / 2 - 0.12, 0.015), (0.08, 0.08, 0.03), BLACK, bevel=0.01))
    parts.append(rbox("grille", (0, d / 2 - 0.04, 0.045), (w - 0.1, 0.02, 0.05), GREY, bevel=0.008))
    return parts


def stove():
    """Range: four-burner cooktop over an oven, 0.76 x 0.66 x 0.92 m (1.1 m with the back panel)."""
    w, d, h = 0.76, 0.66, 0.92
    parts = [rbox("body", (0, 0, h / 2), (w, d, h), WHITE, bevel=0.02)]
    parts.append(rbox("cooktop", (0, 0.01, h + 0.01), (w - 0.02, d - 0.04, 0.02), BLACK, bevel=0.008))
    for x, y, r in ((-0.19, 0.14, 0.09), (0.19, 0.14, 0.07), (-0.19, -0.14, 0.07), (0.19, -0.14, 0.09)):
        for k, rr in enumerate((r, r * 0.66, r * 0.33)):
            pts = [Vector((x + rr * math.cos(a), y + rr * math.sin(a), h + 0.025)) for a in
                   [math.tau * i / 24 for i in range(25)]]
            parts.append(tube("coil", pts, 0.006, CHARCOAL if k else STEEL_DARK))
    parts.append(rbox("back_panel", (0, -d / 2 + 0.04, h + 0.1), (w, 0.08, 0.2), WHITE, bevel=0.02))
    for x in (-0.27, -0.13, 0.13, 0.27):
        parts.append(knob((x, -d / 2 + 0.09, h + 0.1), 0.025, 0.03, BLACK))
    parts.append(rbox("clock", (0, -d / 2 + 0.085, h + 0.1), (0.14, 0.01, 0.06), GLASS, bevel=0.004))
    parts.append(rbox("clock_digits", (0, -d / 2 + 0.09, h + 0.1), (0.08, 0.005, 0.02), LED_GREEN, bevel=0.002))
    parts.append(rbox("oven_door", (0, d / 2 + 0.015, 0.5), (w - 0.06, 0.03, 0.56), WHITE, bevel=0.015))
    parts.append(rbox("window", (0, d / 2 + 0.03, 0.48), (w - 0.24, 0.01, 0.3), GLASS, bevel=0.01))
    parts.append(rod("oven_handle", (-0.28, d / 2 + 0.07, 0.74), (0.28, d / 2 + 0.07, 0.74), 0.015, CHROME))
    for sx in (1, -1):
        parts.append(rod("handle_post", (sx * 0.26, d / 2 + 0.03, 0.74), (sx * 0.26, d / 2 + 0.07, 0.74), 0.01, CHROME))
    parts.append(rbox("drawer", (0, d / 2 + 0.01, 0.12), (w - 0.06, 0.02, 0.16), OFFWHITE, bevel=0.01))
    return parts


def microwave():
    """Countertop microwave, 0.5 x 0.38 x 0.3 m."""
    w, d, h = 0.5, 0.38, 0.3
    parts = [rbox("body", (0, 0, h / 2), (w, d, h), STEEL, bevel=0.015)]
    parts.append(rbox("door", (-0.06, d / 2 + 0.005, h / 2), (0.36, 0.015, 0.26), BLACK, bevel=0.01))
    parts.append(rbox("window", (-0.07, d / 2 + 0.013, h / 2), (0.28, 0.005, 0.18), GLASS, bevel=0.006))
    parts.append(rbox("panel", (0.185, d / 2 + 0.005, h / 2), (0.1, 0.015, 0.26), CHARCOAL, bevel=0.008))
    parts.append(rbox("display", (0.185, d / 2 + 0.014, h / 2 + 0.08), (0.07, 0.005, 0.03), LED_GREEN, bevel=0.003))
    for row in range(4):
        for col in range(3):
            parts.append(rbox("button", (0.162 + col * 0.023, d / 2 + 0.015, h / 2 + 0.03 - row * 0.024),
                              (0.016, 0.006, 0.014), GREY, bevel=0.003))
    parts.append(rbox("start", (0.185, d / 2 + 0.015, h / 2 - 0.085), (0.06, 0.007, 0.02), GREEN, bevel=0.004))
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(rbox("foot", (sx * 0.2, sy * 0.14, -0.004), (0.03, 0.03, 0.01), BLACK, bevel=0.003))
    return fp.lift_to_floor(parts)


def toaster():
    """Two-slot toaster, 0.28 x 0.17 x 0.2 m. Slots at x = +-0.04, top z = 0.2."""
    w, d, h = 0.28, 0.17, 0.2
    parts = [rbox("body", (0, 0, h / 2 + 0.01), (w, d, h - 0.02), CHROME, bevel=0.05, segments=5)]
    parts.append(rbox("base", (0, 0, 0.012), (w + 0.01, d + 0.01, 0.024), BLACK, bevel=0.01))
    for x in (-0.04, 0.04):
        parts.append(rbox("slot", (x, 0, h - 0.002), (0.028, 0.13, 0.008), BLACK, bevel=0.003))
    parts.append(rbox("lever_track", (w / 2 + 0.002, 0, 0.1), (0.006, 0.02, 0.1), CHARCOAL, bevel=0.002))
    parts.append(rbox("lever", (w / 2 + 0.018, 0, 0.13), (0.03, 0.03, 0.018), BLACK, bevel=0.006))
    parts.append(at(cyl("dial", (0, 0, 0), 0.016, 0.012, BLACK, segments=16), (w / 2 + 0.006, 0, 0.06), SIDEWAYS))
    parts.append(rbox("stripe", (0, d / 2 + 0.001, 0.07), (w - 0.06, 0.004, 0.02), RED, bevel=0.002))
    return parts


def toast():
    """One slice of toast, 0.11 x 0.012 x 0.11 m, standing up (drops into a toaster slot)."""
    def color(co, n):
        return TOAST if abs(n[1]) > 0.8 else CRUST
    slice_ = fp.grid_box("toast", (0.1, 0.013, 0.1), color, cuts=4, bevel=0.005)
    top = blobs("top", [("e", (-0.02, 0, 0.05), (0.035, 0.0065, 0.018)),
                        ("e", (0.02, 0, 0.05), (0.035, 0.0065, 0.018))], color, voxel=0.004, smooth=2)
    return fp.lift_to_floor([slice_, top])


def kettle():
    """Electric kettle on its base, 0.26 m tall."""
    prof = [(0, 0.03), (0.09, 0.03), (0.1, 0.05), (0.095, 0.18), (0.075, 0.22), (0.06, 0.225), (0, 0.225)]
    parts = [lathe("jug", prof, lambda co, n: RED if co[2] > 0.06 else BLACK, segments=32)]
    parts.append(cyl("base", (0, 0, 0.015), 0.1, 0.03, BLACK, segments=32, bevel=0.006))
    parts.append(cyl("lid_knob", (0, 0, 0.232), 0.018, 0.016, BLACK, segments=16))
    parts.append(tube("spout", [Vector((0, 0.08, 0.15)), Vector((0, 0.12, 0.19)), Vector((0, 0.135, 0.205))],
                      0.018, RED))
    parts.append(tube("handle", [Vector((0, -0.085, 0.07)), Vector((0, -0.14, 0.1)), Vector((0, -0.14, 0.18)),
                                 Vector((0, -0.08, 0.21))], 0.016, BLACK))
    parts.append(rbox("switch", (0, -0.12, 0.07), (0.02, 0.02, 0.012), LED_BLUE, bevel=0.004))
    return parts


def coffee_maker():
    """Drip coffee maker with a glass pot, 0.35 m tall."""
    parts = [rbox("base", (0, 0, 0.02), (0.22, 0.26, 0.04), BLACK, bevel=0.012)]
    parts.append(rbox("tower", (0, -0.08, 0.18), (0.22, 0.1, 0.3), BLACK, bevel=0.02))
    parts.append(rbox("head", (0, 0.02, 0.3), (0.22, 0.22, 0.09), BLACK, bevel=0.02))
    parts.append(rbox("brew_light", (0.07, 0.13, 0.3), (0.02, 0.005, 0.02), RED, bevel=0.003))
    pot = [(0, 0.045), (0.07, 0.045), (0.085, 0.09), (0.08, 0.15), (0.06, 0.18), (0, 0.18)]
    parts.append(at(lathe("pot", pot, lambda co, n: srgb(0.35, 0.2, 0.12) if co[2] < 0.12 else GLASS_LIGHT,
                          segments=28), (0, 0.04, 0)))
    parts.append(tube("pot_handle", [Vector((0.08, 0.04, 0.08)), Vector((0.13, 0.04, 0.1)),
                                     Vector((0.13, 0.04, 0.15)), Vector((0.08, 0.04, 0.165))], 0.01, BLACK))
    parts.append(cyl("pot_lid", (0, 0.04, 0.185), 0.062, 0.012, BLACK, segments=24))
    return parts


def blender():
    """Countertop blender, 0.42 m tall."""
    parts = [rbox("base", (0, 0, 0.06), (0.17, 0.17, 0.12), STEEL, bevel=0.03)]
    parts.append(rbox("panel", (0, 0.086, 0.06), (0.1, 0.006, 0.05), BLACK, bevel=0.005))
    for x, c in ((-0.03, GREEN), (0.0, YELLOW), (0.03, RED)):
        parts.append(knob((x, 0.09, 0.06), 0.008, 0.008, c))
    jar = [(0, 0.12), (0.055, 0.12), (0.075, 0.3), (0.08, 0.37), (0, 0.37)]
    parts.append(lathe("jar", jar, lambda co, n: srgb(0.95, 0.55, 0.6) if co[2] < 0.22 else GLASS_LIGHT,
                       segments=28))
    parts.append(cyl("lid", (0, 0, 0.38), 0.085, 0.02, BLACK, segments=28, bevel=0.005))
    parts.append(tube("handle", [Vector((0.07, 0, 0.18)), Vector((0.12, 0, 0.2)), Vector((0.12, 0, 0.33)),
                                 Vector((0.08, 0, 0.35))], 0.012, BLACK))
    return parts


# --------------------------------------------------------------------------
# Living room
# --------------------------------------------------------------------------

def tv():
    """55-inch flat-screen TV on feet, 1.25 m wide. Screen is its own mesh."""
    w, h, z0 = 1.25, 0.72, 0.08
    parts = [rbox("bezel", (0, 0, z0 + h / 2), (w, 0.05, h), BLACK, bevel=0.012)]
    parts.append(screen_panel((0, 0.027, z0 + h / 2), (w - 0.04, 0.006, h - 0.04)))
    parts.append(strip("glare", (-w / 2 + 0.12, z0 + 0.1), (-w / 2 + 0.42, z0 + h - 0.08), 0.031, 0.002, 0.07,
                       GLARE, bevel=0.0))
    parts.append(rbox("back", (0, -0.05, z0 + h / 2), (w * 0.6, 0.06, h * 0.6), BLACK, bevel=0.02))
    for sx in (1, -1):
        parts.append(strip("foot", (sx * (w / 2 - 0.15), 0.0), (sx * (w / 2 - 0.2), z0 + 0.05), 0, 0.2, 0.03,
                           CHARCOAL))
    parts.append(rbox("led", (0.0, 0.03, z0 + 0.012), (0.012, 0.004, 0.006), RED, bevel=0.001))
    return parts


def tv_stand():
    """Low media cabinet, 1.6 x 0.45 x 0.5 m. Top at 0.5 m."""
    w, d, h = 1.6, 0.45, 0.5
    parts = [rbox("top", (0, 0, h - 0.02), (w, d, 0.04), WOOD, bevel=0.012)]
    parts.append(rbox("bottom", (0, 0, 0.08), (w, d, 0.04), WOOD, bevel=0.012))
    for x in (-w / 2 + 0.02, -0.25, 0.25, w / 2 - 0.02):
        parts.append(rbox("upright", (x, 0, 0.29), (0.04, d, 0.38), WOOD, bevel=0.01))
    parts.append(rbox("back", (0, -d / 2 + 0.01, 0.29), (w, 0.02, 0.38), WOOD_DARK, bevel=0.005))
    for sx in (1, -1):
        parts.append(rbox("door", (sx * 0.52, d / 2 - 0.01, 0.29), (0.5, 0.02, 0.36), WOOD_LIGHT, bevel=0.01))
        parts.append(rod("pull", (sx * 0.33, d / 2 + 0.02, 0.24), (sx * 0.33, d / 2 + 0.02, 0.34), 0.008, CHARCOAL))
    parts.append(rbox("shelf", (0, 0, 0.29), (0.48, d - 0.03, 0.02), WOOD, bevel=0.005))
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(cyl("leg", (sx * (w / 2 - 0.08), sy * (d / 2 - 0.06), 0.03), 0.025, 0.06, WOOD_DARK,
                             segments=12))
    return parts


def sofa():
    """Three-seat sofa, 2.0 x 0.9 x 0.85 m."""
    w, d = 2.0, 0.9
    parts = [rbox("base", (0, 0, 0.22), (w - 0.3, d - 0.1, 0.24), FABRIC_DARK, bevel=0.05)]
    for k in range(3):
        x = -0.57 + k * 0.57
        parts.append(rbox("seat", (x, 0.07, 0.42), (0.56, 0.7, 0.16), FABRIC, bevel=0.07, segments=4))
        parts.append(rbox("back_cushion", (x, -0.3, 0.65), (0.56, 0.2, 0.42), FABRIC, bevel=0.08, segments=4))
    parts.append(rbox("backrest", (0, -d / 2 + 0.08, 0.5), (w - 0.3, 0.16, 0.66), FABRIC_DARK, bevel=0.06))
    for sx in (1, -1):
        parts.append(rbox("arm", (sx * (w / 2 - 0.13), 0, 0.36), (0.26, d, 0.52), FABRIC_DARK, bevel=0.1,
                          segments=4))
        for sy in (1, -1):
            parts.append(cyl("leg", (sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), 0.05), 0.025, 0.1, WOOD_DARK,
                             segments=12, radius_top=0.03))
    parts.append(rbox("pillow", (-0.72, -0.12, 0.62), (0.34, 0.12, 0.34), YELLOW, bevel=0.08, segments=4))
    return parts


def coffee_table():
    w, d, h = 1.1, 0.6, 0.42
    parts = [rbox("top", (0, 0, h - 0.025), (w, d, 0.05), WOOD, bevel=0.015)]
    parts.append(rbox("shelf", (0, 0, 0.1), (w - 0.1, d - 0.1, 0.03), WOOD_DARK, bevel=0.01))
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(rbox("leg", (sx * (w / 2 - 0.05), sy * (d / 2 - 0.05), (h - 0.05) / 2), (0.05, 0.05, h - 0.05),
                              WOOD_DARK, bevel=0.01))
    return parts


def floor_lamp():
    parts = [cyl("base", (0, 0, 0.02), 0.16, 0.04, CHARCOAL, segments=32, bevel=0.01)]
    parts.append(rod("pole", (0, 0, 0.04), (0, 0, 1.4), 0.013, CHARCOAL))
    shade = [(0.12, 1.32), (0.2, 1.32), (0.13, 1.58), (0.12, 1.58)]
    parts.append(lathe("shade", [(0, 1.32)] + shade[1:3] + [(0, 1.58)], solid(srgb(0.98, 0.92, 0.72)),
                       segments=32))
    parts.append(ball("bulb", 0.04, solid(srgb(1.0, 0.97, 0.8)), rings=10, segments=16))
    at(parts[-1], (0, 0, 1.3))
    return parts


def table_lamp():
    parts = [lathe("base", [(0, 0), (0.08, 0), (0.09, 0.02), (0.06, 0.06), (0.07, 0.16), (0.03, 0.26),
                            (0.02, 0.3), (0, 0.3)], solid(TEAL), segments=24)]
    parts.append(lathe("shade", [(0, 0.28), (0.15, 0.28), (0.1, 0.46), (0, 0.46)], solid(srgb(0.98, 0.92, 0.72)),
                       segments=28))
    return parts


def bookshelf():
    """0.9 x 0.32 x 1.8 m bookshelf with books."""
    w, d, h = 0.9, 0.32, 1.8
    parts = []
    for sx in (1, -1):
        parts.append(rbox("side", (sx * (w / 2 - 0.02), 0, h / 2), (0.04, d, h), WOOD, bevel=0.01))
    parts.append(rbox("back", (0, -d / 2 + 0.01, h / 2), (w, 0.02, h), WOOD_DARK, bevel=0.005))
    shelves = [0.04, 0.44, 0.84, 1.24, 1.76]
    for z in shelves:
        parts.append(rbox("shelf", (0, 0, z), (w - 0.04, d, 0.035), WOOD, bevel=0.008))
    rng = random.Random(9)
    palette = [RED, BLUE, GREEN, YELLOW, PURPLE, ORANGE, TEAL, PINK, WOOD_DARK, WHITE]
    for z0 in shelves[:-1]:
        x = -w / 2 + 0.06
        while x < w / 2 - 0.1:
            bw = rng.uniform(0.025, 0.05)
            bh = rng.uniform(0.22, 0.32)
            if rng.random() < 0.12:
                x += 0.08
                continue
            col = rng.choice(palette)
            book = rbox("book", (x + bw / 2, 0.01, z0 + 0.018 + bh / 2), (bw - 0.003, 0.22, bh), col, bevel=0.004,
                        segments=1)
            parts.append(book)
            parts.append(rbox("band", (x + bw / 2, 0.121, z0 + 0.018 + bh * 0.8), (bw - 0.002, 0.003, 0.015),
                              GOLD_TRIM, bevel=0.0))
            x += bw
    return parts


GOLD_TRIM = srgb(0.96, 0.8, 0.35)


# --------------------------------------------------------------------------
# Bedroom
# --------------------------------------------------------------------------

def bed(width, pillows, name):
    length = 2.05
    parts = [rbox("frame", (0, 0, 0.2), (width + 0.06, length, 0.16), WOOD, bevel=0.02)]
    for sx in (1, -1):
        for y in (-length / 2 + 0.05, length / 2 - 0.05):
            parts.append(rbox("leg", (sx * (width / 2 - 0.02), y, 0.07), (0.08, 0.08, 0.14), WOOD_DARK, bevel=0.01))
    parts.append(rbox("headboard", (0, -length / 2 - 0.02, 0.6), (width + 0.1, 0.07, 0.95), WOOD, bevel=0.03))
    parts.append(rbox("headboard_panel", (0, -length / 2 + 0.02, 0.68), (width - 0.1, 0.02, 0.55), WOOD_LIGHT,
                      bevel=0.015))
    parts.append(rbox("footboard", (0, length / 2 + 0.02, 0.36), (width + 0.1, 0.06, 0.4), WOOD, bevel=0.025))
    parts.append(rbox("mattress", (0, 0, 0.38), (width, length - 0.04, 0.22), SHEET, bevel=0.06, segments=4))
    parts.append(rbox("blanket", (0, 0.28, 0.43), (width + 0.06, length * 0.66, 0.16), BLANKET, bevel=0.07,
                      segments=4))
    parts.append(rbox("fold", (0, 0.28 - length * 0.33 + 0.08, 0.52), (width + 0.07, 0.16, 0.05), SHEET, bevel=0.02))
    parts.append(rbox("stripe", (0, 0.66, 0.43), (width + 0.07, 0.1, 0.162), BLANKET_DARK, bevel=0.06, segments=4))
    for k in range(pillows):
        x = 0 if pillows == 1 else (-0.38 + k * 0.76) * width / 1.6
        parts.append(blobs("pillow", [("e", (x, -length / 2 + 0.26, 0.55), (0.3 if pillows == 1 else 0.33, 0.17, 0.08))],
                           solid(WHITE), voxel=0.012, smooth=3, faces=1200))
    return parts


def bed_single():
    """Single bed, 1.0 x 2.1 m, headboard at the back (-Y)."""
    return bed(1.0, 1, "bed_single")


def bed_double():
    """Double bed, 1.6 x 2.1 m, headboard at the back (-Y)."""
    return bed(1.6, 2, "bed_double")


def nightstand():
    w, d, h = 0.45, 0.4, 0.55
    parts = [rbox("body", (0, 0, h / 2 + 0.04), (w, d, h - 0.08), WOOD, bevel=0.015)]
    parts.append(rbox("top", (0, 0, h - 0.015), (w + 0.02, d + 0.02, 0.03), WOOD_DARK, bevel=0.01))
    for z in (0.18, 0.38):
        parts.append(rbox("drawer", (0, d / 2 + 0.005, z), (w - 0.06, 0.02, 0.16), WOOD_LIGHT, bevel=0.01))
        parts.append(knob((0, d / 2 + 0.02, z), 0.015, 0.02, CHARCOAL))
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(rbox("leg", (sx * (w / 2 - 0.03), sy * (d / 2 - 0.03), 0.02), (0.04, 0.04, 0.04), WOOD_DARK,
                              bevel=0.008))
    return parts


def wardrobe():
    w, d, h = 1.0, 0.58, 2.0
    parts = [rbox("body", (0, 0, h / 2 + 0.05), (w, d, h - 0.1), WOOD, bevel=0.02)]
    parts.append(rbox("crown", (0, 0, h - 0.02), (w + 0.06, d + 0.04, 0.05), WOOD_DARK, bevel=0.015))
    parts.append(rbox("plinth", (0, 0, 0.04), (w + 0.02, d + 0.02, 0.08), WOOD_DARK, bevel=0.015))
    for sx in (1, -1):
        parts.append(rbox("door", (sx * 0.245, d / 2 + 0.01, 1.05), (0.47, 0.02, 1.8), WOOD_LIGHT, bevel=0.015))
        parts.append(rbox("panel", (sx * 0.245, d / 2 + 0.025, 1.3), (0.35, 0.01, 0.9), WOOD, bevel=0.01))
        parts.append(rbox("panel", (sx * 0.245, d / 2 + 0.025, 0.5), (0.35, 0.01, 0.4), WOOD, bevel=0.01))
        parts.append(rod("handle", (sx * 0.04, d / 2 + 0.05, 0.95), (sx * 0.04, d / 2 + 0.05, 1.15), 0.01, CHARCOAL))
    return parts


def desk():
    """Computer desk, 1.4 x 0.7 x 0.75 m, drawer unit on the right."""
    w, d, h = 1.4, 0.7, 0.75
    parts = [rbox("top", (0, 0, h - 0.02), (w, d, 0.04), WOOD_LIGHT, bevel=0.012)]
    parts.append(rbox("drawers", (w / 2 - 0.23, 0, (h - 0.04) / 2), (0.42, d - 0.04, h - 0.04), WHITE, bevel=0.012))
    for k in range(3):
        z = 0.12 + k * 0.22
        parts.append(rbox("drawer", (w / 2 - 0.23, d / 2 - 0.01, z), (0.38, 0.02, 0.19), OFFWHITE, bevel=0.01))
        parts.append(rod("pull", (w / 2 - 0.3, d / 2 + 0.015, z + 0.05), (w / 2 - 0.16, d / 2 + 0.015, z + 0.05), 0.007,
                         CHARCOAL))
    for sy in (1, -1):
        parts.append(rbox("leg", (-w / 2 + 0.04, sy * (d / 2 - 0.05), (h - 0.04) / 2), (0.05, 0.05, h - 0.04), WHITE,
                          bevel=0.01))
    parts.append(rbox("modesty", (-0.2, -d / 2 + 0.03, 0.45), (0.9, 0.02, 0.5), WHITE, bevel=0.005))
    return parts


def gaming_chair():
    """Racing-style gaming chair, seat at 0.5 m, 1.3 m tall."""
    parts = []
    for k in range(5):
        a = k / 5 * math.tau + math.pi / 2
        tip = Vector((0.3 * math.cos(a), 0.3 * math.sin(a), 0.09))
        parts.append(rod("spoke", (0, 0, 0.1), tip, 0.022, CHARCOAL))
        parts.append(at(ball("caster", 0.035, solid(BLACK), rings=8, segments=12), tip - Vector((0, 0, 0.055))))
    parts.append(cyl("gas_lift", (0, 0, 0.26), 0.028, 0.32, CHROME, segments=16))
    parts.append(rbox("seat", (0, 0.02, 0.48), (0.52, 0.5, 0.1), BLACK, bevel=0.04))
    for sx in (1, -1):
        parts.append(rbox("bolster", (sx * 0.22, 0.02, 0.53), (0.1, 0.48, 0.08), RED, bevel=0.035))
        parts.append(rod("arm_post", (sx * 0.29, -0.02, 0.45), (sx * 0.29, -0.02, 0.66), 0.02, CHARCOAL))
        parts.append(rbox("arm_pad", (sx * 0.29, 0.02, 0.67), (0.08, 0.26, 0.035), BLACK, bevel=0.012))
    back = rbox("back", (0, 0, 0), (0.5, 0.1, 0.82), BLACK, bevel=0.05)
    stripes = [rbox("back_bolster", (sx * 0.21, 0.02, -0.05), (0.09, 0.1, 0.7), RED, bevel=0.035) for sx in (1, -1)]
    headrest = rbox("headrest", (0, 0.05, 0.3), (0.2, 0.08, 0.1), RED, bevel=0.035)
    tilt = Matrix.Translation((0, -0.24, 0.93)) @ Matrix.Rotation(-0.18, 4, "X")
    for p in [back, headrest] + stripes:
        parts.append(xf(p, tilt))
    return parts


# --------------------------------------------------------------------------
# Computer and consoles (generic, no logos)
# --------------------------------------------------------------------------

def monitor():
    """27-inch monitor on a stand. Screen is its own mesh."""
    w, h, z0 = 0.62, 0.36, 0.12
    parts = [rbox("bezel", (0, 0, z0 + h / 2), (w, 0.03, h), BLACK, bevel=0.01)]
    parts.append(screen_panel((0, 0.017, z0 + h / 2), (w - 0.025, 0.005, h - 0.025)))
    parts.append(rbox("neck", (0, -0.05, z0 + 0.06), (0.06, 0.03, 0.26), CHARCOAL, bevel=0.01))
    parts.append(rbox("stand", (0, -0.02, 0.01), (0.24, 0.18, 0.02), CHARCOAL, bevel=0.008))
    return parts


def keyboard():
    """Keyboard, 0.44 x 0.14 m."""
    parts = [rbox("case", (0, 0, 0.012), (0.44, 0.14, 0.024), BLACK, bevel=0.006)]
    for row in range(5):
        n = 15 - (row == 4) * 6
        for k in range(n):
            x = -0.2 + k * 0.4 / 14 if row < 4 else -0.07 + k * 0.03
            size = (0.022, 0.02, 0.01)
            if row == 4 and k == 3:
                size = (0.14, 0.02, 0.01)
            parts.append(rbox("key", (x, 0.05 - row * 0.024, 0.028), size, CHARCOAL, bevel=0.003, segments=1))
    parts.append(rbox("glow", (0, 0, 0.001), (0.445, 0.145, 0.004), LED_BLUE, bevel=0.001))
    return parts


def mouse():
    return [blobs("mouse", [("e", (0, 0, 0.018), (0.032, 0.058, 0.02)), ("e", (0, -0.01, 0.022), (0.03, 0.04, 0.02))],
                  lambda co, n: RED if abs(co[0]) < 0.003 and co[1] > 0.02 else BLACK, voxel=0.004, smooth=2),
            rbox("wheel", (0, 0.025, 0.04), (0.006, 0.014, 0.008), GREY, bevel=0.002)]


def pc_tower():
    """Gaming PC with a glass side and colored fan lights, 0.22 x 0.45 x 0.48 m."""
    w, d, h = 0.22, 0.45, 0.48
    parts = [rbox("case", (0, 0, h / 2 + 0.02), (w, d, h), BLACK, bevel=0.012)]
    parts.append(rbox("glass", (w / 2 + 0.002, 0, h / 2 + 0.02), (0.006, d - 0.04, h - 0.04), GLASS, bevel=0.005))
    for k, col in enumerate((srgb(1.0, 0.3, 0.8), LED_BLUE, LED_GREEN)):
        z = 0.12 + k * 0.14
        ring = [Vector((w / 2 + 0.008, 0.14 + 0.05 * math.cos(a), z + 0.05 * math.sin(a))) for a in
                [math.tau * i / 20 for i in range(21)]]
        parts.append(tube("fan_ring", ring, 0.006, col))
    parts.append(rbox("gpu", (w / 2 - 0.01, -0.02, 0.22), (0.015, 0.3, 0.08), CHARCOAL, bevel=0.006))
    parts.append(rbox("gpu_light", (w / 2 + 0.006, -0.02, 0.25), (0.004, 0.25, 0.01), srgb(1.0, 0.3, 0.8),
                      bevel=0.001))
    parts.append(knob((0.06, d / 2 + 0.005, h - 0.02), 0.012, 0.01, LED_BLUE))
    for sx in (1, -1):
        for sy in (1, -1):
            parts.append(rbox("foot", (sx * 0.08, sy * 0.18, 0.01), (0.04, 0.06, 0.02), RUBBER, bevel=0.006))
    return parts


def console_tower():
    """Generic tall two-tone console: dark core between curved white side
    panels, stands upright. 0.12 x 0.28 x 0.4 m."""
    parts = [rbox("core", (0, 0, 0.2), (0.06, 0.24, 0.38), BLACK, bevel=0.01)]
    wing = [(-0.13, 0.0), (0.12, 0.0), (0.15, 0.15), (0.14, 0.34), (0.1, 0.42), (-0.1, 0.4), (-0.14, 0.28)]
    for sx in (1, -1):
        panel = prism("panel", wing, 0, 0.02, WHITE)
        parts.append(xf(panel, Matrix.Translation((sx * 0.042, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")))
    parts.append(rbox("light", (0, 0.121, 0.2), (0.058, 0.004, 0.3), LED_BLUE, bevel=0.001))
    parts.append(rbox("stand", (0, 0, 0.005), (0.12, 0.2, 0.01), BLACK, bevel=0.004))
    return parts


def console_box():
    """Generic boxy console: a matte black tower with a vented top that glows
    green inside. 0.15 x 0.15 x 0.3 m."""
    parts = [rbox("body", (0, 0, 0.15), (0.15, 0.15, 0.3), BLACK, bevel=0.012)]
    parts.append(cyl("vent", (0, 0, 0.3), 0.06, 0.006, CHARCOAL, segments=32))
    parts.append(cyl("vent_glow", (0, 0, 0.301), 0.04, 0.006, srgb(0.2, 0.55, 0.25), segments=32))
    for k in range(6):
        parts.append(rbox("dot", (-0.05 + k * 0.02, 0.0, 0.3035), (0.004, 0.11, 0.003), BLACK, bevel=0.0))
    parts.append(knob((0.05, 0.076, 0.27), 0.008, 0.005, WHITE))
    parts.append(rbox("disc_slot", (-0.01, 0.0755, 0.21), (0.1, 0.003, 0.005), CHARCOAL, bevel=0.0))
    return parts


def console_retro():
    """Generic retro cartridge console with a cartridge plugged in."""
    parts = [rbox("body", (0, 0, 0.035), (0.26, 0.2, 0.07), srgb(0.72, 0.72, 0.74), bevel=0.012)]
    parts.append(rbox("top", (0, -0.02, 0.075), (0.2, 0.12, 0.014), srgb(0.58, 0.58, 0.62), bevel=0.006))
    parts.append(rbox("stripe", (0, 0.101, 0.03), (0.24, 0.003, 0.012), RED, bevel=0.0))
    parts.append(rbox("cartridge", (0, -0.02, 0.12), (0.12, 0.02, 0.09), srgb(0.35, 0.35, 0.38), bevel=0.008))
    parts.append(rbox("label", (0, -0.009, 0.125), (0.09, 0.003, 0.05), YELLOW, bevel=0.0))
    for x, c in ((-0.07, RED), (0.07, GREY)):
        parts.append(rbox("button", (x, 0.085, 0.07), (0.035, 0.02, 0.012), c, bevel=0.004))
    return parts


def controller(body_color, button_colors, name="controller"):
    """Generic twin-stick gamepad, about 0.16 m wide."""
    shapes = [("e", (0, 0.0, 0.03), (0.055, 0.04, 0.02)),
              ("c", (-0.045, 0.0, 0.028), (-0.06, -0.045, 0.02), 0.03, 0.024),
              ("c", (0.045, 0.0, 0.028), (0.06, -0.045, 0.02), 0.03, 0.024)]
    parts = [blobs("pad", shapes, solid(body_color), voxel=0.004, smooth=3, faces=1600)]
    for x in (-0.03, 0.03):
        parts.append(cyl("stick_base", (x, -0.015, 0.048), 0.013, 0.012, CHARCOAL, segments=16))
        parts.append(cyl("stick", (x, -0.015, 0.058), 0.011, 0.008, BLACK, segments=16, bevel=0.003))
    for (dx, dy), col in zip(((0, 0.014), (0.014, 0), (0, -0.014), (-0.014, 0)), button_colors):
        parts.append(cyl("button", (0.055 + dx, 0.012 + dy, 0.047), 0.0065, 0.008, col, segments=12))
    parts.append(rbox("dpad", (-0.055, 0.012, 0.047), (0.03, 0.009, 0.006), CHARCOAL, bevel=0.002))
    parts.append(rbox("dpad", (-0.055, 0.012, 0.047), (0.009, 0.03, 0.006), CHARCOAL, bevel=0.002))
    parts.append(rbox("light", (0, 0.035, 0.04), (0.03, 0.004, 0.004), LED_BLUE, bevel=0.001))
    for sx in (1, -1):
        parts.append(rbox("bumper", (sx * 0.05, 0.036, 0.035), (0.04, 0.012, 0.012), CHARCOAL, bevel=0.004))
    return fp.lift_to_floor(parts)


def controller_black():
    return controller(BLACK, (GREEN, RED, BLUE, YELLOW))


def controller_white():
    return controller(WHITE, (srgb(0.9, 0.4, 0.6), RED, BLUE, GREEN))


def console_hybrid():
    """Generic hybrid handheld: a tablet with detachable blue and red side
    controllers, 0.24 x 0.1 m, lying flat screen up. Screen is its own mesh."""
    parts = [rbox("tablet", (0, 0, 0.007), (0.17, 0.1, 0.014), BLACK, bevel=0.005)]
    parts.append(screen_panel((0, 0, 0.0145), (0.15, 0.085, 0.002)))
    for sx, col in ((-1, srgb(0.2, 0.75, 0.95)), (1, srgb(0.95, 0.32, 0.32))):
        side = rbox("joy", (sx * 0.1, 0, 0.007), (0.035, 0.1, 0.014), col, bevel=0.007)
        parts.append(side)
        parts.append(cyl("stick", (sx * 0.1, 0.025 if sx < 0 else -0.01, 0.017), 0.007, 0.008, BLACK, segments=12))
        for dx, dy in ((0, 0.009), (0.009, 0), (0, -0.009), (-0.009, 0)):
            parts.append(cyl("button", (sx * 0.1 + dx, (-0.015 if sx < 0 else 0.022) + dy, 0.0155), 0.0035, 0.004,
                             BLACK, segments=10))
    return parts


def console_dock():
    """Dock for console_hybrid: the tablet slides in standing up."""
    parts = [rbox("dock", (0, 0, 0.055), (0.18, 0.05, 0.11), CHARCOAL, bevel=0.01)]
    parts.append(rbox("slot", (0, 0, 0.11), (0.172, 0.018, 0.004), BLACK, bevel=0.0))
    parts.append(rbox("led", (0.07, 0.026, 0.015), (0.008, 0.003, 0.004), LED_GREEN, bevel=0.0))
    return parts


# --------------------------------------------------------------------------
# Art supplies
# --------------------------------------------------------------------------

def brush(length, width, flat, handle_color, paint_color):
    parts = [tube("handle", [Vector((0, 0, 0)), Vector((0, 0, length * 0.55)), Vector((0, 0, length * 0.7))],
                  width * 0.45, handle_color)]
    parts.append(cyl("ferrule", (0, 0, length * 0.76), width * 0.55, length * 0.12, CHROME, segments=16))
    tip = [("e", (0, 0, length * 0.85), (width * (0.9 if flat else 0.5), width * (0.3 if flat else 0.5), length * 0.08)),
           ("c", (0, 0, length * 0.85), (0, 0, length * 0.97), width * (0.8 if flat else 0.45), width * 0.12)]

    def color(co, n):
        return paint_color if co[2] > length * 0.9 else srgb(0.75, 0.6, 0.42)
    parts.append(blobs("bristles", tip, color, voxel=width * 0.15, smooth=2))
    return fp.lift_to_floor(parts)


def paint_brush():
    """Round artist's brush, 0.22 m long, standing on its handle."""
    return brush(0.22, 0.012, False, RED, BLUE)


def paint_brush_wide():
    """Flat house-painting brush, 0.25 m long."""
    parts = [tube("handle", [Vector((0, 0, 0)), Vector((0, 0, 0.13))], 0.014, WOOD)]
    parts.append(rbox("ferrule", (0, 0, 0.15), (0.07, 0.018, 0.04), CHROME, bevel=0.004))
    bristles = fp.grid_box("bristles", (0.066, 0.016, 0.075),
                           lambda co, n: YELLOW if co[2] > 0.012 else srgb(0.3, 0.25, 0.2), cuts=4, bevel=0.006)
    for v in bristles.data.vertices:  # taper toward the tip
        t = (v.co.z + 0.0375) / 0.075
        v.co.y *= 1.0 - 0.45 * t
    parts.append(at(bristles, (0, 0, 0.205)))
    return fp.lift_to_floor(parts)


def paint_palette():
    """Kidney-shaped palette with dabs of paint, 0.35 m wide, lying flat."""
    outline = []
    for k in range(40):
        a = k / 40 * math.tau
        r = 0.17 * (1 - 0.18 * math.cos(2 * a) ** 2) * (0.85 if abs(((a + math.pi) % math.tau) - math.pi) < 0.35 else 1)
        outline.append((r * math.cos(a), r * math.sin(a) * 0.75))
    pal = prism("palette", outline, 0, 0.008, WOOD_LIGHT)
    parts = [xf(pal, Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Translation((0, 0, 0)))]
    parts.append(cyl("thumb_hole", (-0.1, 0.0, 0.0), 0.022, 0.0085, DARK_HOLE, segments=20))
    for (x, y), col in zip(((0.02, 0.08), (0.08, 0.05), (0.11, -0.01), (0.07, -0.07), (0.0, -0.08), (-0.05, 0.07)),
                           (RED, YELLOW, BLUE, GREEN, PURPLE, WHITE)):
        parts.append(blobs("paint", [("e", (x, y, 0.006), (0.018, 0.016, 0.007))], solid(col), voxel=0.003,
                           smooth=2))
    return fp.lift_to_floor(parts)


DARK_HOLE = srgb(0.2, 0.15, 0.1)


def easel():
    """Studio easel with a painting in progress, 1.7 m tall; canvas faces +Y."""
    parts = []
    for sx in (1, -1):
        parts.append(rod("leg", (sx * 0.1, 0.05, 1.65), (sx * 0.35, 0.2, 0.0), 0.018, WOOD))
    parts.append(rod("back_leg", (0, 0.0, 1.5), (0, -0.55, 0.0), 0.018, WOOD))
    parts.append(rod("mast", (0, 0.07, 0.6), (0, 0.07, 1.7), 0.02, WOOD_DARK))
    parts.append(rbox("ledge", (0, 0.12, 0.7), (0.6, 0.08, 0.025), WOOD_DARK, bevel=0.006))
    tilt = Matrix.Translation((0, 0.11, 1.05)) @ Matrix.Rotation(-0.12, 4, "X")
    canvas = rbox("canvas", (0, 0, 0), (0.6, 0.03, 0.72), WHITE, bevel=0.006)
    art = [rbox("sky", (0, 0.017, 0.12), (0.56, 0.004, 0.44), srgb(0.55, 0.78, 0.95), bevel=0.0),
           rbox("hill", (0, 0.018, -0.2), (0.56, 0.004, 0.24), srgb(0.45, 0.75, 0.35), bevel=0.0),
           at(cyl("sun", (0, 0, 0), 0.06, 0.004, YELLOW, segments=20), (0.16, 0.02, 0.22), FRONT)]
    for p in [canvas] + art:
        parts.append(xf(p, tilt))
    return parts


def paint_can():
    """Open paint can with a stir stick, 0.2 m tall."""
    parts = [lathe("can", [(0, 0), (0.085, 0), (0.085, 0.18), (0.08, 0.185), (0.075, 0.18), (0.075, 0.16),
                           (0, 0.16)], lambda co, n: BLUE if 0.04 < co[2] < 0.13 else STEEL,
                   segments=32)]
    parts.append(cyl("paint", (0, 0, 0.165), 0.076, 0.004, BLUE, segments=32))
    parts.append(strip("stick", (0.03, 0.12), (0.08, 0.3), 0, 0.025, 0.008, WOOD_LIGHT))
    bail = [Vector((0.085 * math.cos(t), 0, 0.14 + 0.09 * math.sin(t))) for t in
            [math.radians(d) for d in range(0, 181, 15)]]
    parts.append(tube("bail", bail, 0.004, STEEL_DARK))
    return parts


# --------------------------------------------------------------------------
# Cameras
# --------------------------------------------------------------------------

def camera_dslr():
    """Generic DSLR with a zoom lens, lens pointing +Y."""
    parts = [rbox("body", (0, 0, 0.05), (0.14, 0.075, 0.1), BLACK, bevel=0.012)]
    parts.append(rbox("grip", (0.055, 0.02, 0.048), (0.035, 0.07, 0.095), LEATHER, bevel=0.015))
    parts.append(prism("prism", [(-0.03, 0.098), (0.03, 0.098), (0.02, 0.125), (-0.02, 0.125)], 0, 0.06, BLACK))
    lens = lathe("lens", [(0, 0), (0.035, 0), (0.036, 0.03), (0.034, 0.06), (0.038, 0.07), (0.038, 0.09), (0, 0.09)],
                 lambda co, n: RED if 0.058 < co[2] < 0.062 else (CHARCOAL if 0.02 < co[2] < 0.05 else BLACK),
                 segments=32)
    parts.append(at(lens, (-0.01, 0.035, 0.05), FRONT))
    parts.append(at(cyl("glass", (0, 0, 0), 0.028, 0.004, GLASS_LIGHT, segments=28), (-0.01, 0.126, 0.05), FRONT))
    parts.append(cyl("shutter", (0.055, 0.02, 0.105), 0.008, 0.008, CHROME, segments=12))
    parts.append(cyl("dial", (-0.045, 0.0, 0.105), 0.013, 0.01, CHARCOAL, segments=16))
    parts.append(rbox("screen_back", (0, -0.039, 0.05), (0.08, 0.004, 0.055), GLASS, bevel=0.003))
    for sx in (1, -1):
        parts.append(rbox("lug", (sx * 0.072, 0, 0.09), (0.008, 0.012, 0.012), CHROME, bevel=0.003))
    return parts


def camera_instant():
    """Generic chunky instant camera; photos come out of the top slot."""
    parts = [rbox("body", (0, 0, 0.06), (0.13, 0.1, 0.12), srgb(0.96, 0.9, 0.82), bevel=0.02)]
    parts.append(rbox("stripe", (0, 0.051, 0.03), (0.13, 0.003, 0.018), srgb(0.95, 0.5, 0.55), bevel=0.0))
    lens = lathe("lens", [(0, 0), (0.04, 0), (0.042, 0.02), (0.035, 0.03), (0, 0.03)],
                 lambda co, n: BLACK if co[2] < 0.025 else GLASS, segments=28)
    parts.append(at(lens, (0.0, 0.045, 0.055), FRONT))
    parts.append(rbox("flash", (-0.035, 0.052, 0.1), (0.04, 0.006, 0.02), CHROME, bevel=0.003))
    parts.append(rbox("viewfinder", (0.04, 0.05, 0.1), (0.018, 0.008, 0.015), BLACK, bevel=0.003))
    parts.append(rbox("slot", (0, 0.0, 0.1205), (0.09, 0.012, 0.002), BLACK, bevel=0.0))
    parts.append(cyl("shutter", (0.05, 0.03, 0.123), 0.009, 0.008, RED, segments=12))
    return parts


def instant_photo():
    """One instant photo, 0.088 x 0.107 m, lying flat."""
    parts = [rbox("card", (0, 0, 0.001), (0.088, 0.107, 0.002), WHITE, bevel=0.0005)]
    parts.append(rbox("picture", (0, 0.009, 0.0022), (0.078, 0.078, 0.0005), srgb(0.5, 0.72, 0.9), bevel=0.0))
    parts.append(rbox("grass", (0, -0.018, 0.0024), (0.078, 0.024, 0.0005), GREEN, bevel=0.0))
    return parts


def tripod():
    """Camera tripod, 1.4 m tall; a camera sits on the plate at the top."""
    parts = []
    for k in range(3):
        a = k / 3 * math.tau + math.pi / 2
        parts.append(rod("leg", (0, 0, 1.2), (0.45 * math.cos(a), 0.45 * math.sin(a), 0.0), 0.012, CHARCOAL))
        parts.append(rod("lower_leg", (0.3 * math.cos(a), 0.3 * math.sin(a), 0.4),
                         (0.45 * math.cos(a), 0.45 * math.sin(a), 0.0), 0.009, CHROME))
    parts.append(rod("column", (0, 0, 0.9), (0, 0, 1.33), 0.016, CHARCOAL))
    parts.append(cyl("head", (0, 0, 1.35), 0.035, 0.04, BLACK, segments=16))
    parts.append(rbox("plate", (0, 0, 1.38), (0.07, 0.07, 0.015), CHARCOAL, bevel=0.004))
    parts.append(rod("pan_handle", (0, -0.02, 1.35), (0, -0.2, 1.3), 0.008, BLACK))
    return parts


# --------------------------------------------------------------------------
# Sports gear
# --------------------------------------------------------------------------

def basketball():
    r = 0.12
    w = 0.006

    def color(co, n):
        x, y, z = co[0] / r, co[1] / r, (co[2] - r) / r
        if abs(x) < w / r or abs(z) < w / r or abs(abs(y) - 0.72) < w / r:
            return BLACK
        return ORANGE
    return [at(ball("ball", r, color, rings=32, segments=48), (0, 0, r))]


PHI = (1 + 5 ** 0.5) / 2
ICO = [Vector(v).normalized() for v in
       [(0, 1, PHI), (0, -1, PHI), (0, 1, -PHI), (0, -1, -PHI), (1, PHI, 0), (-1, PHI, 0), (1, -PHI, 0),
        (-1, -PHI, 0), (PHI, 0, 1), (-PHI, 0, 1), (PHI, 0, -1), (-PHI, 0, -1)]]


def soccer_ball():
    r = 0.11

    def color(co, n):
        d = Vector(co).normalized()
        return BLACK if max(d.dot(v) for v in ICO) > 0.94 else WHITE
    b = ball("ball", r, color, rings=32, segments=48)
    return [at(b, (0, 0, r))]


def seam_color(r, base, seam, width):
    a, b = 0.7, 0.3
    pts = [Vector((a * math.cos(t) + b * math.cos(3 * t), a * math.sin(t) - b * math.sin(3 * t),
                   2 * math.sqrt(a * b) * math.sin(2 * t))) for t in [math.tau * k / 240 for k in range(240)]]

    def color(co, n):
        d = Vector(co).normalized()
        return seam if min((d - p).length for p in pts) < width else base
    return color


def baseball():
    r = 0.037
    return [at(ball("ball", r, seam_color(r, WHITE, RED, 0.07), rings=20, segments=32), (0, 0, r))]


def tennis_ball():
    r = 0.034
    return [at(ball("ball", r, seam_color(r, srgb(0.85, 0.95, 0.25), WHITE, 0.06), rings=20, segments=32), (0, 0, r))]


def football():
    """American football lying on its side, laces up."""
    length, radius = 0.28, 0.085
    prof = [(0, 0)]
    for k in range(1, 20):
        t = k / 20
        prof.append((radius * math.sin(math.pi * t) ** 0.85, length * t))
    prof.append((0, length))
    leather = srgb(0.55, 0.28, 0.14)
    ball_ = lathe("ball", prof, lambda co, n: WHITE if abs(co[2] - 0.055) < 0.008 or abs(co[2] - 0.225) < 0.008
                  else leather, segments=32)
    parts = [at(ball_, (0, -length / 2, radius), FRONT)]
    parts.append(rbox("lace_strip", (0, 0, 2 * radius - 0.002), (0.012, 0.08, 0.004), WHITE, bevel=0.001))
    for k in range(6):
        parts.append(rbox("lace", (0, -0.035 + k * 0.014, 2 * radius), (0.03, 0.004, 0.005), WHITE, bevel=0.001))
    return parts


def baseball_bat():
    """Wooden bat, 0.84 m, standing on its knob."""
    prof = [(0, 0), (0.025, 0), (0.025, 0.012), (0.014, 0.02), (0.013, 0.3), (0.02, 0.5), (0.032, 0.7),
            (0.034, 0.82), (0.028, 0.84), (0, 0.84)]
    return [lathe("bat", prof, lambda co, n: BLACK if co[2] < 0.25 else WOOD_LIGHT, segments=24)]


def tennis_racket():
    """Tennis racket, 0.68 m, standing on the handle, face toward +Y."""
    cz, rx, rz = 0.5, 0.13, 0.17
    ring = [Vector((rx * math.cos(a), 0, cz + rz * math.sin(a))) for a in [math.tau * k / 48 for k in range(49)]]
    parts = [tube("frame", ring, 0.011, BLUE)]
    parts.append(tube("throat_l", [Vector((-0.06, 0, cz - rz + 0.02)), Vector((-0.012, 0, 0.26))], 0.009, BLUE))
    parts.append(tube("throat_r", [Vector((0.06, 0, cz - rz + 0.02)), Vector((0.012, 0, 0.26))], 0.009, BLUE))
    parts.append(lathe("handle", [(0, 0), (0.016, 0), (0.016, 0.24), (0.012, 0.27), (0, 0.27)],
                       lambda co, n: BLACK if co[2] < 0.2 else BLUE, segments=8))
    for k in range(-5, 6):
        x = k * 0.022
        h = rz * math.sqrt(max(0.0, 1 - (x / rx) ** 2))
        parts.append(rod("string", (x, 0, cz - h), (x, 0, cz + h), 0.0015, WHITE))
    for k in range(-7, 8):
        z = k * 0.022
        wdt = rx * math.sqrt(max(0.0, 1 - (z / rz) ** 2))
        parts.append(rod("string", (-wdt, 0, cz + z), (wdt, 0, cz + z), 0.0015, WHITE))
    return parts


def yoga_mat():
    """Rolled-out yoga mat, 1.8 x 0.6 m, with a rolled end."""
    parts = [rbox("mat", (0, 0.1, 0.003), (0.6, 1.6, 0.006), PURPLE, bevel=0.002)]
    parts.append(at(cyl("roll", (0, 0, 0), 0.06, 0.6, PURPLE, segments=24), (0, -0.76, 0.06), SIDEWAYS))
    parts.append(at(cyl("roll_end", (0, 0, 0), 0.03, 0.602, srgb(0.42, 0.25, 0.65), segments=16),
                    (0, -0.76, 0.06), SIDEWAYS))
    return parts


# --------------------------------------------------------------------------
# Gym
# --------------------------------------------------------------------------

def plate(name, radius, thick, color):
    prof = [(0.026, -thick / 2), (radius, -thick / 2), (radius, thick / 2), (0.026, thick / 2), (0.026, -thick / 2)]
    return lathe(name, prof, lambda co, n: WHITE if abs(math.hypot(co[0], co[1]) - radius * 0.62) < 0.006
                 and abs(n[2]) > 0.7 else color, segments=36)


def weight_plate():
    """20 kg plate standing on edge, 0.45 m across."""
    return [at(plate("plate", 0.225, 0.05, srgb(0.2, 0.35, 0.85)), (0, 0, 0.225), FRONT)]


def dumbbell():
    """Hex dumbbell lying on the floor, 0.35 m long."""
    parts = [at(cyl("handle", (0, 0, 0), 0.016, 0.16, CHROME, segments=16), (0, 0, 0.065), SIDEWAYS)]
    for sx in (1, -1):
        head = cyl("head", (0, 0, 0), 0.075, 0.09, BLACK, segments=6, bevel=0.008)
        parts.append(xf(head, Matrix.Translation((sx * 0.125, 0, 0.065)) @ SIDEWAYS @ Matrix.Rotation(
            math.pi / 6, 4, "Z")))
    return fp.lift_to_floor(parts)


def kettlebell():
    """16 kg kettlebell, 0.28 m tall."""
    body = ball("bell", 0.1, solid(srgb(0.25, 0.25, 0.28)), rings=16, segments=28)
    parts = [at(body, (0, 0, 0.1))]
    parts.append(cyl("base", (0, 0, 0.01), 0.07, 0.02, srgb(0.25, 0.25, 0.28), segments=28))
    pts = [Vector((0.075 * math.cos(a), 0, 0.17 + 0.09 * math.sin(a))) for a in
           [math.radians(d) for d in range(-20, 201, 15)]]
    parts.append(tube("handle", pts, 0.017, srgb(0.25, 0.25, 0.28)))
    parts.append(rbox("label", (0, 0.098, 0.1), (0.05, 0.006, 0.03), YELLOW, bevel=0.004))
    return parts


def barbell_parts(center, length=2.0, plates=((0.225, 0.05, srgb(0.85, 0.2, 0.2)),)):
    cx, cy, cz = center
    parts = [at(cyl("bar", (0, 0, 0), 0.014, length, CHROME, segments=16), (cx, cy, cz), SIDEWAYS)]
    for sx in (1, -1):
        parts.append(at(cyl("sleeve", (0, 0, 0), 0.025, 0.4, STEEL, segments=16), (cx + sx * (length / 2 - 0.2), cy, cz),
                        SIDEWAYS))
        parts.append(at(cyl("collar", (0, 0, 0), 0.04, 0.03, STEEL_DARK, segments=16),
                        (cx + sx * (length / 2 - 0.42), cy, cz), SIDEWAYS))
        x = length / 2 - 0.38
        for radius, thick, col in plates:
            parts.append(at(plate("plate", radius, thick, col), (cx + sx * (x + thick / 2), cy, cz), SIDEWAYS))
            x += thick + 0.004
    return parts


def barbell():
    """Olympic barbell with two red plates, resting on the plates."""
    return barbell_parts((0, 0, 0.225))


def bench_press():
    """Flat bench with a rack and a loaded barbell. The lifter lies with their
    head toward the rack (-Y)."""
    parts = [rbox("pad", (0, 0.2, 0.44), (0.3, 1.2, 0.08), srgb(0.75, 0.15, 0.15), bevel=0.03)]
    parts.append(rbox("rail", (0, 0.2, 0.37), (0.08, 1.2, 0.06), CHARCOAL, bevel=0.01))
    for y in (-0.3, 0.7):
        parts.append(rbox("leg", (0, y, 0.18), (0.06, 0.06, 0.34), CHARCOAL, bevel=0.01))
        parts.append(rbox("foot", (0, y, 0.02), (0.4, 0.07, 0.04), CHARCOAL, bevel=0.01))
    for sx in (1, -1):
        parts.append(rbox("upright", (sx * 0.55, -0.45, 0.6), (0.07, 0.07, 1.2), CHARCOAL, bevel=0.01))
        parts.append(rbox("base", (sx * 0.55, -0.35, 0.025), (0.08, 0.5, 0.05), CHARCOAL, bevel=0.01))
        parts.append(rbox("hook", (sx * 0.55, -0.39, 1.08), (0.06, 0.08, 0.03), STEEL, bevel=0.006))
        parts.append(rbox("hook_lip", (sx * 0.55, -0.35, 1.12), (0.06, 0.02, 0.06), STEEL, bevel=0.006))
        parts.append(rbox("spotter", (sx * 0.55, -0.35, 0.7), (0.06, 0.2, 0.03), STEEL, bevel=0.006))
    parts.append(rbox("crossbar", (0, -0.45, 0.15), (1.1, 0.06, 0.06), CHARCOAL, bevel=0.01))
    parts += barbell_parts((0, -0.4, 1.12), plates=((0.225, 0.05, srgb(0.2, 0.35, 0.85)),
                                                    (0.17, 0.035, YELLOW)))
    return parts


def treadmill():
    """Treadmill, 0.8 x 1.9 m; you face +Y, where the console is."""
    parts = [rbox("deck", (0, -0.1, 0.1), (0.8, 1.7, 0.16), CHARCOAL, bevel=0.03)]
    parts.append(rbox("belt", (0, -0.15, 0.185), (0.5, 1.55, 0.012), RUBBER, bevel=0.004))
    for sx in (1, -1):
        parts.append(rbox("side_rail", (sx * 0.32, -0.15, 0.185), (0.12, 1.55, 0.014), GREY, bevel=0.005))
    parts.append(rbox("hood", (0, 0.72, 0.16), (0.8, 0.3, 0.24), BLACK, bevel=0.06))
    for sx in (1, -1):
        parts.append(rod("upright", (sx * 0.35, 0.72, 0.2), (sx * 0.33, 0.62, 1.2), 0.03, GREY))
        parts.append(rod("handrail", (sx * 0.33, 0.62, 1.05), (sx * 0.33, 0.25, 1.0), 0.02, BLACK))
    parts.append(rbox("console", (0, 0.66, 1.25), (0.72, 0.16, 0.2), BLACK, bevel=0.04))
    parts.append(screen_panel((0, 0.59, 1.28), (0.28, 0.02, 0.1)))
    for k, col in enumerate((GREEN, YELLOW, RED)):
        parts.append(rbox("button", (-0.26 + k * 0.05, 0.585, 1.21), (0.035, 0.012, 0.025), col, bevel=0.006))
    for k in range(3):
        parts.append(rbox("button", (0.18 + k * 0.045, 0.585, 1.21), (0.03, 0.012, 0.025), BLUE, bevel=0.006))
    parts.append(rod("crossbar", (-0.33, 0.62, 1.1), (0.33, 0.62, 1.1), 0.02, BLACK))
    return parts


# --------------------------------------------------------------------------
# Bathroom
# --------------------------------------------------------------------------

def basin_box(name, size, wall, depth, color, bevel=0.03):
    """A box with a hollow top (tub, sink basin): the top face is inset and pushed down."""
    bm = fp.bmesh.new()
    fp.bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((*size, 1)))
    top = [f for f in bm.faces if f.normal.z > 0.9]
    res = fp.bmesh.ops.inset_region(bm, faces=top, thickness=wall, depth=0)
    inner = top[0]
    fp.bmesh.ops.translate(bm, vec=(0, 0, -depth), verts=list(inner.verts))
    obj = fp.new_object(name, bm)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 3
    mod.limit_method = "ANGLE"
    fp.apply_modifiers(obj)
    fp.select_only(obj)
    bpy.ops.object.shade_smooth()
    fp.paint(obj, color if callable(color) else solid(color))
    return obj


def faucet(pos, reach=0.14, height=0.2, color=CHROME):
    x, y, z = pos
    parts = [tube("faucet", [Vector((x, y, z)), Vector((x, y, z + height)), Vector((x, y + reach * 0.5, z + height + 0.03)),
                             Vector((x, y + reach, z + height - 0.02))], 0.013, color)]
    for sx in (1, -1):
        parts.append(cyl("tap", (x + sx * 0.07, y, z + 0.03), 0.018, 0.04, color, segments=12))
        parts.append(cyl("tap_dot", (x + sx * 0.07, y, z + 0.052), 0.008, 0.006, RED if sx < 0 else BLUE, segments=10))
    return parts


def toilet():
    """Toilet, 0.4 x 0.7 m, tank against the wall at the back (-Y)."""
    parts = []
    bowl = [(0, 0), (0.12, 0), (0.13, 0.05), (0.12, 0.2), (0.17, 0.36), (0.18, 0.4), (0.16, 0.41), (0.1, 0.33),
            (0, 0.3)]
    b = lathe("bowl", bowl, solid(WHITE), segments=32)
    parts.append(xf(b, Matrix.Translation((0, 0.08, 0)) @ Matrix.Diagonal((1.0, 1.25, 1.0, 1.0))))
    seat = [Vector((0.165 * math.cos(a), 0.08 + 0.21 * math.sin(a), 0.42)) for a in [math.tau * k / 36 for k in range(37)]]
    parts.append(tube("seat", seat, 0.025, WHITE))
    parts.append(rbox("lid", (0, -0.15, 0.62), (0.36, 0.05, 0.4), OFFWHITE, bevel=0.02))
    parts.append(rbox("tank", (0, -0.24, 0.62), (0.42, 0.18, 0.42), WHITE, bevel=0.03))
    parts.append(rbox("tank_lid", (0, -0.24, 0.845), (0.45, 0.2, 0.04), WHITE, bevel=0.015))
    parts.append(rbox("neck", (0, -0.12, 0.3), (0.2, 0.12, 0.3), WHITE, bevel=0.03))
    parts.append(rod("flush", (-0.2, -0.16, 0.78), (-0.2, -0.1, 0.78), 0.008, CHROME))
    parts.append(rbox("flush_lever", (-0.17, -0.1, 0.78), (0.06, 0.012, 0.012), CHROME, bevel=0.004))
    return parts


def bathtub():
    """Built-in bathtub, 1.6 x 0.75 x 0.55 m, with a faucet at the right end."""
    tub = basin_box("tub", (1.6, 0.75, 0.55), 0.08, 0.42, WHITE, bevel=0.04)
    parts = [at(tub, (0, 0, 0.275))]
    parts.append(rbox("water", (0, 0, 0.36), (1.4, 0.56, 0.01), srgb(0.62, 0.85, 0.97), bevel=0.0))
    parts.append(rbox("apron_line", (0, 0.376, 0.08), (1.6, 0.004, 0.02), OFFWHITE, bevel=0.0))
    parts.append(tube("spout", [Vector((0.72, 0.0, 0.6)), Vector((0.72, 0.0, 0.66)), Vector((0.64, 0.0, 0.66))], 0.018,
                      CHROME))
    for sy in (1, -1):
        parts.append(cyl("tap", (0.74, sy * 0.1, 0.6), 0.02, 0.05, CHROME, segments=12))
    duck = blobs("duck", [("e", (0, 0, 0.03), (0.04, 0.05, 0.03)), ("e", (0, 0.03, 0.07), (0.025, 0.025, 0.025))],
                 lambda co, n: ORANGE if co[1] > 0.05 and co[2] < 0.075 else YELLOW, voxel=0.004, smooth=2)
    parts.append(at(duck, (-0.3, 0.05, 0.36)))
    return parts


def bathroom_sink():
    """Pedestal sink, basin top at 0.88 m."""
    ped = [(0, 0), (0.14, 0), (0.15, 0.03), (0.09, 0.1), (0.07, 0.6), (0.1, 0.7), (0, 0.7)]
    parts = [lathe("pedestal", ped, solid(WHITE), segments=28)]
    basin = [(0, 0.66), (0.2, 0.7), (0.27, 0.8), (0.29, 0.88), (0.26, 0.89), (0.22, 0.84), (0.12, 0.78), (0, 0.76)]
    b = lathe("basin", basin, solid(WHITE), segments=32)
    parts.append(xf(b, Matrix.Diagonal((1.0, 0.8, 1.0, 1.0))))
    parts.append(rbox("deck", (0, -0.19, 0.87), (0.4, 0.08, 0.04), WHITE, bevel=0.015))
    parts += faucet((0, -0.19, 0.89), reach=0.1, height=0.1)
    parts.append(cyl("drain", (0, 0, 0.765), 0.02, 0.004, CHROME, segments=16))
    return parts


def bathroom_mirror():
    """Wall mirror, 0.6 x 0.8 m. Wall item: origin at the back-bottom, hang with the bottom at ~1.1 m."""
    parts = [rbox("frame", (0, 0.015, 0.4), (0.6, 0.03, 0.8), WOOD_LIGHT, bevel=0.012)]
    parts.append(rbox("glass", (0, 0.032, 0.4), (0.52, 0.006, 0.72), srgb(0.72, 0.86, 0.95), bevel=0.004))
    parts.append(strip("glare", (-0.2, 0.15), (0.05, 0.65), 0.036, 0.002, 0.06, WHITE, bevel=0.0))
    parts.append(strip("glare", (-0.06, 0.12), (0.1, 0.44), 0.036, 0.002, 0.03, WHITE, bevel=0.0))
    return parts


def towel_rack():
    """Wall towel bar with a striped towel. Wall item, bar at the top."""
    parts = [rod("bar", (-0.3, 0.06, 0.5), (0.3, 0.06, 0.5), 0.012, CHROME)]
    for sx in (1, -1):
        parts.append(rod("bracket", (sx * 0.3, 0.0, 0.5), (sx * 0.3, 0.06, 0.5), 0.012, CHROME))
        parts.append(cyl("rose", (0, 0, 0), 0.025, 0.01, CHROME, segments=12))
        at(parts[-1], (sx * 0.3, 0.005, 0.5), FRONT)

    def towel_color(co, n):
        return WHITE if 0.1 < co[2] < 0.14 or 0.16 < co[2] < 0.18 else TEAL
    for y, h in ((0.075, 0.46), (0.045, 0.4)):
        parts.append(rbox("towel", (0, y, 0.5 - h / 2), (0.44, 0.02, h), towel_color, bevel=0.008))
    return parts


def bath_mat():
    parts = [rbox("mat", (0, 0, 0.006), (0.8, 0.5, 0.012), srgb(0.55, 0.78, 0.9), bevel=0.005)]
    parts.append(rbox("border", (0, 0, 0.0065), (0.72, 0.42, 0.0125), WHITE, bevel=0.004))
    parts.append(rbox("center", (0, 0, 0.007), (0.66, 0.36, 0.013), srgb(0.55, 0.78, 0.9), bevel=0.004))
    return parts


def toilet_paper():
    """Toilet paper roll, 0.11 m wide, lying on its side."""
    roll = lathe("roll", [(0.02, -0.05), (0.055, -0.05), (0.055, 0.05), (0.02, 0.05), (0.02, -0.05)],
                 lambda co, n: srgb(0.7, 0.55, 0.38) if math.hypot(co[0], co[1]) < 0.024 else WHITE, segments=28)
    return [at(roll, (0, 0, 0.055), SIDEWAYS)]


# --------------------------------------------------------------------------
# Kitchen counters and laundry
# --------------------------------------------------------------------------

COUNTER_TOP = srgb(0.92, 0.9, 0.85)
CABINET = srgb(0.62, 0.8, 0.72)
CABINET_DARK = srgb(0.5, 0.68, 0.6)


def base_cabinet(width, top=True):
    parts = [rbox("carcass", (0, -0.02, 0.47), (width, 0.56, 0.78), CABINET_DARK, bevel=0.01)]
    parts.append(rbox("toe_kick", (0, -0.03, 0.04), (width - 0.02, 0.5, 0.08), CHARCOAL, bevel=0.008))
    if top:
        parts.append(rbox("counter", (0, 0.0, 0.88), (width, 0.62, 0.04), COUNTER_TOP, bevel=0.012))
    return parts


def cabinet_door(center, size, handle_side=1):
    x, y, z = center
    w, h = size
    parts = [rbox("door", (x, y, z), (w, 0.02, h), CABINET, bevel=0.01)]
    parts.append(rbox("inset", (x, y + 0.012, z), (w - 0.1, 0.006, h - 0.1), CABINET_DARK, bevel=0.004))
    hx = x + handle_side * (w / 2 - 0.05)
    parts.append(rod("handle", (hx, y + 0.03, z + h / 2 - 0.2), (hx, y + 0.03, z + h / 2 - 0.08), 0.007, CHROME))
    return parts


def counter():
    """Base cabinet with countertop, 0.6 x 0.62 m, counter at 0.9 m (fridge/stove height)."""
    parts = base_cabinet(0.6)
    parts.append(rbox("drawer", (0, 0.265, 0.75), (0.58, 0.02, 0.16), CABINET, bevel=0.01))
    parts.append(rod("pull", (-0.08, 0.29, 0.75), (0.08, 0.29, 0.75), 0.007, CHROME))
    parts += cabinet_door((0, 0.265, 0.37), (0.58, 0.58), handle_side=1)
    return parts


def counter_drawers():
    """Drawer stack cabinet, 0.6 m wide."""
    parts = base_cabinet(0.6)
    for k, h in enumerate((0.2, 0.25, 0.3)):
        z = [0.75, 0.52, 0.24][k]
        parts.append(rbox("drawer", (0, 0.265, z), (0.58, 0.02, h - 0.02), CABINET, bevel=0.01))
        parts.append(rod("pull", (-0.1, 0.29, z + 0.03), (0.1, 0.29, z + 0.03), 0.007, CHROME))
    return parts


def counter_sink():
    """1.2 m sink cabinet with a steel double basin and faucet."""
    w = 1.2
    parts = base_cabinet(w, top=False)
    basin = basin_box("basin", (0.76, 0.44, 0.2), 0.03, 0.17, STEEL, bevel=0.01)
    parts.append(at(basin, (0, 0.02, 0.8)))
    parts.append(rbox("divider", (0, 0.02, 0.86), (0.03, 0.4, 0.06), STEEL, bevel=0.006))
    for x0, x1, y0, y1 in ((-w / 2, -0.38, -0.31, 0.31), (0.38, w / 2, -0.31, 0.31), (-0.38, 0.38, -0.31, -0.2),
                           (-0.38, 0.38, 0.24, 0.31)):
        parts.append(rbox("counter", ((x0 + x1) / 2, (y0 + y1) / 2, 0.88), (x1 - x0, y1 - y0, 0.04), COUNTER_TOP,
                          bevel=0.008))
    parts += faucet((0, -0.25, 0.9), reach=0.2, height=0.28)
    for sx in (1, -1):
        parts += cabinet_door((sx * 0.3, 0.265, 0.45), (0.58, 0.74), handle_side=-sx)
    return parts


def upper_cabinet():
    """Wall cabinet, 0.6 x 0.35 x 0.7 m. Wall item: origin at the back-bottom; hang the bottom at ~1.45 m."""
    parts = [rbox("carcass", (0, 0.175, 0.35), (0.6, 0.33, 0.7), CABINET_DARK, bevel=0.01)]
    parts += cabinet_door((0, 0.345, 0.35), (0.58, 0.68), handle_side=1)
    parts[-1] = rod("handle", (0.24, 0.37, 0.04), (0.24, 0.37, 0.16), 0.007, CHROME)
    return parts


def washer_like(name, door_glass, panel_color):
    w, d, h = 0.6, 0.6, 0.85
    parts = [rbox("body", (0, 0, h / 2), (w, d, h), WHITE, bevel=0.025)]
    parts.append(rbox("panel", (0, d / 2 + 0.004, h - 0.08), (w - 0.04, 0.012, 0.13), panel_color, bevel=0.008))
    parts.append(knob((-0.2, d / 2 + 0.02, h - 0.08), 0.03, 0.03, STEEL))
    parts.append(rbox("display", (0.1, d / 2 + 0.012, h - 0.08), (0.12, 0.004, 0.04), GLASS, bevel=0.003))
    parts.append(rbox("digits", (0.1, d / 2 + 0.015, h - 0.08), (0.07, 0.003, 0.015), LED_GREEN, bevel=0.001))
    for k in range(3):
        parts.append(knob((0.22, d / 2 + 0.012, h - 0.11 + k * 0.03), 0.008, 0.01, GREY))
    ring = lathe("door_ring", [(0.16, 0.0), (0.22, 0.0), (0.225, 0.03), (0.2, 0.05), (0.16, 0.05), (0.16, 0.0)],
                 solid(CHROME), segments=40)
    parts.append(at(ring, (0, d / 2, 0.4), FRONT))
    parts.append(at(cyl("door_glass", (0, 0, 0), 0.165, 0.03, door_glass, segments=40), (0, d / 2 + 0.03, 0.4), FRONT))
    parts.append(rbox("latch", (0.2, d / 2 + 0.05, 0.4), (0.03, 0.03, 0.08), STEEL, bevel=0.008))
    parts.append(rbox("toe", (0, d / 2 - 0.01, 0.04), (w - 0.06, 0.02, 0.05), OFFWHITE, bevel=0.006))
    return parts


def washer():
    """Front-loading washing machine, 0.6 x 0.6 x 0.85 m, with a blue sudsy window."""
    parts = washer_like("washer", srgb(0.35, 0.6, 0.9), srgb(0.85, 0.87, 0.9))
    suds = blobs("suds", [("e", (x, 0, z), (0.05, 0.02, 0.04)) for x, z in ((-0.06, 0.34), (0.02, 0.33), (0.08, 0.36),
                                                                           (-0.02, 0.38))],
                 solid(WHITE), voxel=0.008, smooth=2)
    parts.append(at(suds, (0, 0.335, 0.0)))
    return parts


def dryer():
    """Front-loading dryer, matches the washer (stackable)."""
    parts = washer_like("dryer", srgb(0.2, 0.22, 0.3), srgb(0.9, 0.84, 0.7))
    rng = random.Random(2)
    clothes = blobs("clothes", [("e", (rng.uniform(-0.08, 0.08), 0, rng.uniform(0.3, 0.42)), (0.05, 0.02, 0.04))
                                for _ in range(5)],
                    lambda co, n: RED if co[0] < -0.02 else (YELLOW if co[0] < 0.04 else BLUE), voxel=0.008, smooth=2)
    parts.append(at(clothes, (0, 0.335, 0.0)))
    return parts


def laundry_basket():
    """Wicker laundry basket with clothes, 0.4 m tall."""
    prof = [(0, 0), (0.2, 0), (0.24, 0.35), (0.25, 0.36), (0.23, 0.36), (0.19, 0.03), (0, 0.03)]
    parts = [lathe("basket", prof, lambda co, n: WOOD_LIGHT if int(co[2] * 30) % 2 else WOOD, segments=32)]
    parts.append(blobs("clothes", [("e", (-0.06, 0.02, 0.33), (0.12, 0.1, 0.06)), ("e", (0.08, -0.04, 0.34),
                                                                                     (0.1, 0.1, 0.06))],
                       lambda co, n: PINK if co[0] < 0.0 else BLUE, voxel=0.012, smooth=3))
    return parts


# --------------------------------------------------------------------------
# Decor
# --------------------------------------------------------------------------

def rug_round():
    """Round rug with rings, 1.6 m across."""
    rings = [(0.8, srgb(0.85, 0.35, 0.3)), (0.7, srgb(0.98, 0.85, 0.55)), (0.55, srgb(0.3, 0.55, 0.75)),
             (0.35, srgb(0.98, 0.85, 0.55)), (0.2, srgb(0.85, 0.35, 0.3))]
    return [cyl("ring", (0, 0, 0.004 + k * 0.0006), r, 0.008, c, segments=48) for k, (r, c) in enumerate(rings)]


def rug_rect():
    """Rectangular rug with a border, 2.0 x 1.4 m."""
    parts = [rbox("rug", (0, 0, 0.004), (2.0, 1.4, 0.008), srgb(0.62, 0.22, 0.25), bevel=0.003)]
    parts.append(rbox("border", (0, 0, 0.0045), (1.8, 1.2, 0.009), srgb(0.95, 0.85, 0.6), bevel=0.003))
    parts.append(rbox("field", (0, 0, 0.005), (1.7, 1.1, 0.01), srgb(0.62, 0.22, 0.25), bevel=0.003))
    parts.append(at(cyl("medallion", (0, 0, 0), 0.3, 0.011, srgb(0.95, 0.85, 0.6), segments=6), (0, 0, 0.0055)))
    parts.append(at(cyl("medallion_in", (0, 0, 0), 0.18, 0.012, srgb(0.3, 0.5, 0.7), segments=6), (0, 0, 0.006)))
    for sx in (1, -1):
        for k in range(12):
            parts.append(rod("fringe", (sx * 1.0, -0.6 + k * 0.109, 0.004), (sx * 1.06, -0.6 + k * 0.109, 0.004), 0.004,
                             WHITE))
    return parts


def framed(w, h, art_parts, frame_color=WOOD_DARK):
    """Wall item: origin at the back-bottom center; art faces +Y."""
    parts = [rbox("frame", (0, 0.015, h / 2), (w, 0.03, h), frame_color, bevel=0.01)]
    parts.append(rbox("mat", (0, 0.031, h / 2), (w - 0.06, 0.004, h - 0.06), OFFWHITE, bevel=0.0))
    return parts + art_parts


def painting_landscape():
    """Framed landscape painting, 0.9 x 0.6 m."""
    art = [rbox("sky", (0, 0.034, 0.36), (0.74, 0.004, 0.36), srgb(0.55, 0.78, 0.95), bevel=0.0),
           rbox("field", (0, 0.035, 0.14), (0.74, 0.004, 0.12), srgb(0.45, 0.75, 0.35), bevel=0.0),
           at(cyl("sun", (0, 0, 0), 0.06, 0.004, YELLOW, segments=20), (0.22, 0.037, 0.43), FRONT),
           prism("mountain", [(-0.37, 0.18), (-0.1, 0.42), (0.1, 0.18)], 0.037, 0.004, srgb(0.5, 0.45, 0.6)),
           prism("mountain", [(-0.05, 0.18), (0.15, 0.34), (0.37, 0.18)], 0.038, 0.004, srgb(0.4, 0.38, 0.55))]
    return framed(0.9, 0.6, art)


def painting_portrait():
    """Framed portrait of a smiling cartoon cat, 0.5 x 0.65 m, gold frame."""
    art = [rbox("bg", (0, 0.034, 0.325), (0.4, 0.004, 0.55), srgb(0.55, 0.3, 0.4), bevel=0.0)]
    head = at(cyl("head", (0, 0, 0), 0.12, 0.004, ORANGE, segments=24), (0, 0.037, 0.36), FRONT)
    art.append(head)
    for sx in (1, -1):
        art.append(prism("ear", [(sx * 0.05, 0.44), (sx * 0.13, 0.54), (sx * 0.12, 0.4)], 0.037, 0.004, ORANGE))
        art.append(at(cyl("eye", (0, 0, 0), 0.018, 0.004, BLACK, segments=12), (sx * 0.045, 0.04, 0.38), FRONT))
    art.append(prism("smile", [(-0.04, 0.32), (0.04, 0.32), (0.0, 0.29)], 0.04, 0.004, BLACK))
    art.append(prism("body", [(-0.15, 0.03), (0.15, 0.03), (0.09, 0.24), (-0.09, 0.24)], 0.037, 0.004, ORANGE))
    return framed(0.5, 0.65, art, frame_color=GOLD_TRIM)


def poster():
    """Movie-style poster (no text), 0.6 x 0.9 m. Wall item."""
    parts = [rbox("poster", (0, 0.002, 0.45), (0.6, 0.004, 0.9), srgb(0.12, 0.12, 0.25), bevel=0.0)]
    parts.append(at(cyl("planet", (0, 0, 0), 0.18, 0.004, ORANGE, segments=28), (0.05, 0.006, 0.55), FRONT))
    parts.append(at(cyl("ring", (0, 0, 0), 0.26, 0.003, YELLOW, segments=28), (0.05, 0.005, 0.55),
                    FRONT @ Matrix.Diagonal((1.0, 0.25, 1.0, 1.0))))
    parts.append(prism("rocket", [(-0.2, 0.15), (-0.12, 0.15), (-0.16, 0.35)], 0.008, 0.004, RED))
    for k in range(3):
        parts.append(rbox("title_bar", (0, 0.006, 0.12 - k * 0.035), (0.45 - k * 0.1, 0.004, 0.02), YELLOW, bevel=0.0))
    return parts


def wall_clock():
    """Round wall clock, 0.35 m across. Wall item: origin at the back center."""
    parts = [at(cyl("rim", (0, 0, 0), 0.175, 0.04, RED, segments=40, bevel=0.01), (0, 0.02, 0), FRONT)]
    parts.append(at(cyl("face", (0, 0, 0), 0.15, 0.004, WHITE, segments=40), (0, 0.042, 0), FRONT))
    for k in range(12):
        a = k / 12 * math.tau
        parts.append(rbox("tick", (0.13 * math.sin(a), 0.045, 0.13 * math.cos(a)),
                          (0.012, 0.003, 0.012 if k % 3 else 0.03), BLACK, bevel=0.0))
    parts.append(strip("hour", (0, 0), (0.05, 0.05), 0.047, 0.003, 0.012, BLACK, bevel=0.0))
    parts.append(strip("minute", (0, 0), (0.0, 0.11), 0.048, 0.003, 0.008, BLACK, bevel=0.0))
    parts.append(at(cyl("pin", (0, 0, 0), 0.01, 0.006, RED, segments=10), (0, 0.05, 0), FRONT))
    return parts


def photo_frame():
    """Tabletop photo frame, 0.18 x 0.22 m, leaning back."""
    art = [rbox("frame", (0, 0, 0.11), (0.18, 0.02, 0.22), WOOD_LIGHT, bevel=0.006),
           rbox("photo", (0, 0.011, 0.11), (0.14, 0.003, 0.18), srgb(0.6, 0.8, 0.95), bevel=0.0),
           at(cyl("face1", (0, 0, 0), 0.025, 0.003, srgb(0.98, 0.8, 0.62), segments=16), (-0.035, 0.013, 0.12), FRONT),
           at(cyl("face2", (0, 0, 0), 0.025, 0.003, srgb(0.85, 0.62, 0.45), segments=16), (0.035, 0.013, 0.12), FRONT),
           rbox("grass", (0, 0.012, 0.045), (0.14, 0.003, 0.05), GREEN, bevel=0.0)]
    parts = [xf(p, Matrix.Rotation(-0.2, 4, "X")) for p in art]
    parts.append(strip("stand", (0, 0.0), (0, 0.15), -0.05, 0.03, 0.01, WOOD_DARK))
    return fp.lift_to_floor(parts)


def potted_plant():
    """Leafy house plant in a terracotta pot, 0.9 m tall."""
    parts = [lathe("pot", [(0, 0), (0.12, 0), (0.16, 0.26), (0.17, 0.27), (0.17, 0.3), (0, 0.3)],
                   lambda co, n: srgb(0.8, 0.42, 0.25) if co[2] < 0.26 else srgb(0.7, 0.35, 0.2), segments=28)]
    parts.append(cyl("soil", (0, 0, 0.29), 0.15, 0.01, srgb(0.3, 0.2, 0.12), segments=28))
    rng = random.Random(6)
    leaves = []
    for k in range(9):
        a = k / 9 * math.tau + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.15, 0.3)
        top = Vector((r * math.cos(a), r * math.sin(a), rng.uniform(0.55, 0.9)))
        parts.append(tube("stem", [Vector((0, 0, 0.29)), top * 0.6 + Vector((0, 0, 0.2)), top], 0.006, GREEN))
        leaves.append(("e", tuple(top), (0.09, 0.09, 0.04)))
    parts.append(blobs("leaves", leaves, lambda co, n: srgb(0.3, 0.7, 0.35) if n[2] > 0 else srgb(0.2, 0.55, 0.28),
                       voxel=0.015, smooth=2, faces=2500))
    return parts


PROPS = {
    "fridge": fridge, "stove": stove, "microwave": microwave, "toaster": toaster, "toast": toast,
    "kettle": kettle, "coffee_maker": coffee_maker, "blender": blender,
    "tv": tv, "tv_stand": tv_stand, "sofa": sofa, "coffee_table": coffee_table, "floor_lamp": floor_lamp,
    "table_lamp": table_lamp, "bookshelf": bookshelf,
    "bed_single": bed_single, "bed_double": bed_double, "nightstand": nightstand, "wardrobe": wardrobe,
    "desk": desk, "gaming_chair": gaming_chair,
    "monitor": monitor, "keyboard": keyboard, "mouse": mouse, "pc_tower": pc_tower,
    "console_tower": console_tower, "console_box": console_box, "console_retro": console_retro,
    "console_hybrid": console_hybrid, "console_dock": console_dock,
    "controller_black": controller_black, "controller_white": controller_white,
    "paint_brush": paint_brush, "paint_brush_wide": paint_brush_wide, "paint_palette": paint_palette,
    "easel": easel, "paint_can": paint_can,
    "camera_dslr": camera_dslr, "camera_instant": camera_instant, "instant_photo": instant_photo, "tripod": tripod,
    "basketball": basketball, "soccer_ball": soccer_ball, "football": football, "baseball": baseball,
    "baseball_bat": baseball_bat, "tennis_ball": tennis_ball, "tennis_racket": tennis_racket, "yoga_mat": yoga_mat,
    "dumbbell": dumbbell, "kettlebell": kettlebell, "weight_plate": weight_plate, "barbell": barbell,
    "bench_press": bench_press, "treadmill": treadmill,
    "toilet": toilet, "bathtub": bathtub, "bathroom_sink": bathroom_sink, "bathroom_mirror": bathroom_mirror,
    "towel_rack": towel_rack, "bath_mat": bath_mat, "toilet_paper": toilet_paper,
    "counter": counter, "counter_drawers": counter_drawers, "counter_sink": counter_sink,
    "upper_cabinet": upper_cabinet, "washer": washer, "dryer": dryer, "laundry_basket": laundry_basket,
    "rug_round": rug_round, "rug_rect": rug_rect, "painting_landscape": painting_landscape,
    "painting_portrait": painting_portrait, "poster": poster, "wall_clock": wall_clock, "photo_frame": photo_frame,
    "potted_plant": potted_plant,
}

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if a in PROPS]
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        reset_scene()
        export(name, fn())
