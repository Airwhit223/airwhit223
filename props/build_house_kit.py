"""Modular house-building kit: walls with doors and windows, floors, roof,
gables and stairs, on a 2 m grid with 3 m storeys.

Run with Blender 5.x:
    blender --background --python props/build_house_kit.py [name ...]
or with the bpy pip module (Python 3.13):
    python props/build_house_kit.py [name ...]

Every piece is its own .glb in props/house_kit/. Walls run along X from
-1 to +1 m, 0.2 m thick, with the outside face toward +Z in Godot (modeled toward +Y, turned at export) and
the bottom at z = 0. Wall colors come in three schemes (cream, pink, blue).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_farm_props as fp  # noqa: E402
from build_farm_props import (  # noqa: E402
    Matrix, Vector, bpy, cyl, join, make_material, rbox, reset_scene, srgb, strip, xf,
)
from build_pets import face_plus_z  # noqa: E402

OUT = os.path.join(HERE, "house_kit")
os.makedirs(OUT, exist_ok=True)

CELL, STOREY, THICK = 2.0, 3.0, 0.2
DOOR = (-0.55, 0.55, 0.0, 2.2)      # x0, x1, z0, z1 of the door opening
WINDOW = (-0.55, 0.55, 0.9, 2.1)    # window opening

SCHEMES = {
    "cream": dict(ext=srgb(0.98, 0.9, 0.66), line=srgb(0.86, 0.76, 0.52), shutter=srgb(0.3, 0.55, 0.4)),
    "pink": dict(ext=srgb(0.98, 0.7, 0.66), line=srgb(0.86, 0.56, 0.54), shutter=srgb(0.35, 0.45, 0.75)),
    "blue": dict(ext=srgb(0.62, 0.8, 0.95), line=srgb(0.48, 0.66, 0.84), shutter=srgb(0.95, 0.95, 0.92)),
}
INTERIOR = srgb(0.97, 0.94, 0.84)
INTERIOR_STRIPE = srgb(0.93, 0.88, 0.74)
TRIM = srgb(0.97, 0.97, 0.95)
STONE = srgb(0.62, 0.6, 0.6)
GLASS = srgb(0.55, 0.78, 0.95)
GLARE = srgb(0.85, 0.94, 1.0)
ROOF = srgb(0.38, 0.36, 0.48)
ROOF_DARK = srgb(0.3, 0.28, 0.4)
WOOD = srgb(0.74, 0.52, 0.3)
WOOD_DARK = srgb(0.56, 0.36, 0.2)
WOOD_LIGHT = srgb(0.84, 0.64, 0.4)
RED = srgb(0.82, 0.2, 0.18)
BRASS = srgb(0.95, 0.78, 0.3)
TILE_A = srgb(0.96, 0.95, 0.92)
TILE_B = srgb(0.25, 0.45, 0.62)
CARPET = srgb(0.62, 0.72, 0.55)


def spans(x0, x1, hole, z):
    """Horizontal pieces of [x0, x1] at height z that avoid the opening."""
    if hole and hole[2] <= z <= hole[3]:
        return [(x0, hole[0]), (hole[1], x1)]
    return [(x0, x1)]


def box_between(name, x0, x1, z0, z1, y, depth, color, bevel=0.01):
    if x1 - x0 < 0.005 or z1 - z0 < 0.005:
        return None
    return rbox(name, ((x0 + x1) / 2, y, (z0 + z1) / 2), (x1 - x0, depth, z1 - z0), color, bevel=bevel,
                segments=1 if min(depth, z1 - z0) < 0.05 else 2)


def wall(scheme, width=CELL, hole=None):
    """A wall panel with lap siding outside, wallpaper stripes inside and an optional opening."""
    c = SCHEMES[scheme]
    hw = width / 2

    def body_color(co, n):
        if n[1] > 0.3:
            return c["ext"]
        if n[1] < -0.3:
            return INTERIOR
        return c["line"]
    parts = []
    if hole:
        x0, x1, z0, z1 = hole
        pieces = [(-hw, x0, 0, STOREY), (x1, hw, 0, STOREY), (x0, x1, z1, STOREY), (x0, x1, 0, z0)]
    else:
        pieces = [(-hw, hw, 0, STOREY)]
    for a, b, lo, hi in pieces:
        p = box_between("wall", a, b, lo, hi, 0, THICK, body_color, bevel=0.004)
        if p:
            parts.append(p)
    # Outside: stone footing and lap siding lines.
    for a, b in spans(-hw, hw, hole, 0.12):
        p = box_between("footing", a, b, 0, 0.3, THICK / 2 + 0.02, 0.04, STONE, bevel=0.01)
        if p:
            parts.append(p)
    z = 0.3
    while z < STOREY - 0.05:
        for a, b in spans(-hw, hw, hole, z + 0.01):
            p = box_between("siding", a + 0.005, b - 0.005, z, z + 0.022, THICK / 2 + 0.008, 0.016, c["line"],
                            bevel=0.004)
            if p:
                parts.append(p)
        z += 0.24
    # Inside: baseboard, chair rail and soft vertical stripes.
    for a, b in spans(-hw, hw, hole, 0.05):
        p = box_between("baseboard", a, b, 0, 0.12, -THICK / 2 - 0.01, 0.02, TRIM, bevel=0.005)
        if p:
            parts.append(p)
    for a, b in spans(-hw, hw, hole, 0.95):
        p = box_between("chair_rail", a, b, 0.92, 0.97, -THICK / 2 - 0.008, 0.016, TRIM, bevel=0.004)
        if p:
            parts.append(p)
    x = -hw + 0.1
    while x < hw - 0.1:
        inside_hole = hole and hole[0] - 0.06 < x < hole[1] + 0.06
        z0 = hole[3] if inside_hole else 0.97
        if not inside_hole or hole[3] < STOREY - 0.1:
            p = box_between("stripe", x, x + 0.08, max(z0, 0.97) + 0.02, STOREY - 0.02, -THICK / 2 - 0.003, 0.006,
                            INTERIOR_STRIPE, bevel=0.0)
            if p:
                parts.append(p)
        x += 0.25
    return parts


def frame_opening(hole, sill=False):
    """White trim around an opening on both faces."""
    x0, x1, z0, z1 = hole
    parts = []
    for y in (THICK / 2 + 0.02, -THICK / 2 - 0.02):
        for x in (x0 - 0.05, x1 + 0.05):
            parts.append(rbox("jamb", (x, y, (z0 + z1) / 2 + 0.03), (0.1, 0.04, z1 - z0 + 0.1), TRIM, bevel=0.01))
        parts.append(rbox("head", ((x0 + x1) / 2, y, z1 + 0.06), (x1 - x0 + 0.24, 0.05, 0.12), TRIM, bevel=0.012))
    for x in (x0 - 0.01, x1 + 0.01):  # reveal lining the thickness of the wall
        parts.append(rbox("reveal", (x, 0, (z0 + z1) / 2), (0.02, THICK, z1 - z0), TRIM, bevel=0.003))
    parts.append(rbox("reveal", ((x0 + x1) / 2, 0, z1 - 0.01), (x1 - x0, THICK, 0.02), TRIM, bevel=0.003))
    if sill:
        parts.append(rbox("sill", ((x0 + x1) / 2, THICK / 2, z0 - 0.02), (x1 - x0 + 0.2, THICK + 0.12, 0.05), TRIM,
                          bevel=0.012))
    return parts


def window_insert(scheme):
    x0, x1, z0, z1 = WINDOW
    c = SCHEMES[scheme]
    parts = [box_between("glass", x0, x1, z0, z1, 0, 0.02, GLASS, bevel=0.0)]
    parts.append(strip("glare", (x0 + 0.1, z0 + 0.15), (x0 + 0.35, z1 - 0.2), 0.012, 0.004, 0.06, GLARE, bevel=0.0))
    parts.append(box_between("mullion", -0.025, 0.025, z0, z1, 0.02, 0.05, TRIM, bevel=0.006))
    parts.append(box_between("transom", x0, x1, (z0 + z1) / 2 - 0.025, (z0 + z1) / 2 + 0.025, 0.02, 0.05, TRIM,
                             bevel=0.006))
    for sx in (1, -1):  # shutters on the outside
        x = x1 + 0.28 if sx > 0 else x0 - 0.28
        parts.append(rbox("shutter", (x, THICK / 2 + 0.04, (z0 + z1) / 2), (0.34, 0.03, z1 - z0 + 0.1), c["shutter"],
                          bevel=0.01))
        for k in range(6):
            parts.append(rbox("louver", (x, THICK / 2 + 0.058, z0 + 0.12 + k * (z1 - z0 - 0.14) / 5), (0.28, 0.008, 0.03),
                              c["line"] if scheme == "blue" else TRIM, bevel=0.003, segments=1))
    return parts


def build_walls():
    out = {}
    for scheme in SCHEMES:
        out[f"wall_{scheme}"] = (lambda s=scheme: wall(s))
        out[f"wall_half_{scheme}"] = (lambda s=scheme: wall(s, width=1.0))
        out[f"wall_door_{scheme}"] = (lambda s=scheme: wall(s, hole=DOOR) + frame_opening(DOOR))
        out[f"wall_window_{scheme}"] = (lambda s=scheme: wall(s, hole=WINDOW) + frame_opening(WINDOW, sill=True)
                                        + window_insert(s))
        out[f"gable_{scheme}_l"] = (lambda s=scheme: gable(s, 1))
        out[f"gable_{scheme}_r"] = (lambda s=scheme: gable(s, -1))
    return out


def corner_post():
    """Trim post for outside corners, 0.3 x 0.3 x 3 m (centered on the corner)."""
    return [rbox("post", (0, 0, STOREY / 2), (0.3, 0.3, STOREY), TRIM, bevel=0.02),
            rbox("footing", (0, 0, 0.15), (0.34, 0.34, 0.3), STONE, bevel=0.02)]


def door(front):
    """1.06 x 2.16 m door; origin at the hinge edge (bottom), swings from x = 0 to +x.
    Place at x = -0.53 in a wall_door piece (modeling frame; that is x = +0.53 in
    Godot once face_plus_z() has turned the export)."""
    w, h = 1.06, 2.16
    color = RED if front else TRIM
    parts = [rbox("slab", (w / 2, 0, h / 2), (w, 0.05, h), color, bevel=0.012)]
    panel = srgb(0.7, 0.14, 0.14) if front else srgb(0.9, 0.9, 0.86)
    for y in (0.027, -0.027):
        rows = ((0.25, 0.75), (1.0, 1.35)) if front else ((0.2, 0.9), (1.1, 1.95))
        for z0, z1 in rows:
            for x0, x1 in ((0.12, 0.49), (0.57, 0.94)):
                parts.append(rbox("panel", ((x0 + x1) / 2, y, (z0 + z1) / 2), (x1 - x0, 0.01, z1 - z0), panel,
                                  bevel=0.006))
    if front:
        parts.append(rbox("window", (w / 2, 0, 1.75), (0.6, 0.056, 0.4), GLASS, bevel=0.01))
        for x in (w / 2 - 0.1, w / 2 + 0.1):
            parts.append(rbox("muntin", (x, 0, 1.75), (0.025, 0.06, 0.4), TRIM, bevel=0.004))
    for y in (0.045, -0.045):
        parts.append(fp.br.lathe("knob", [(0, 0), (0.02, 0), (0.035, 0.03), (0.03, 0.05), (0, 0.05)],
                                 lambda co, n: BRASS, segments=16))
        rot = Matrix.Rotation(-math.pi / 2 if y > 0 else math.pi / 2, 4, "X")
        xf(parts[-1], Matrix.Translation((w - 0.09, y * 0.5, 1.0)) @ rot)
    for z in (0.3, 1.1, 1.9):
        parts.append(rbox("hinge", (0.01, 0, z), (0.03, 0.06, 0.1), BRASS, bevel=0.004))
    return parts


def door_front():
    return door(True)


def door_interior():
    return door(False)


def floor(kind):
    """2 x 2 m floor tile, 0.1 m thick, top at z = 0.022 so it never z-fights with ground at
    z = 0; the wall baseboards hide the step."""
    parts = [rbox("slab", (0, 0, -0.04), (CELL, CELL, 0.1), WOOD_DARK, bevel=0.004)]
    if kind == "wood":
        for k in range(10):
            y = -CELL / 2 + 0.1 + k * 0.2
            col = (WOOD, WOOD_LIGHT, WOOD)[k % 3]
            off = 0.5 if k % 2 else 0.0
            for x0, x1 in ((-1.0, -0.2 + off), (-0.2 + off, 1.0)):
                parts.append(rbox("plank", ((x0 + x1) / 2, y, 0.016), (x1 - x0 - 0.01, 0.19, 0.012), col, bevel=0.003,
                                  segments=1))
    elif kind == "tile":
        n = 8
        s = CELL / n
        for i in range(n):
            for j in range(n):
                col = TILE_A if (i + j) % 2 == 0 else TILE_B
                parts.append(rbox("tile", (-CELL / 2 + s * (i + 0.5), -CELL / 2 + s * (j + 0.5), 0.016),
                                  (s - 0.008, s - 0.008, 0.012), col, bevel=0.002, segments=1))
    else:
        parts.append(rbox("carpet", (0, 0, 0.016), (CELL, CELL, 0.012), CARPET, bevel=0.002))
    return parts


def floor_wood():
    return floor("wood")


def floor_tile():
    return floor("tile")


def floor_carpet():
    return floor("carpet")


PITCH = math.radians(30)
RISE = CELL * math.tan(PITCH)       # 1.155 m per 2 m of run


def to_y_slope(parts):
    """Roof pieces are modeled sloping along X; turn them so they slope along Y
    (low edge toward +Y, the outside)."""
    return [xf(p, Matrix.Rotation(math.pi / 2, 4, "Z")) for p in parts]


def roof_slope():
    """One 2 x 2 m cell of 30-degree roof: low edge at y = +1 (z = 0), high edge
    at y = -1 (z = 1.155). Chain cells up the slope; set it on top of the walls
    (z = 3) with the low edge on the wall line."""
    rows = fp.roof_rows((-1.0, RISE), (1.0, 0.0), 0, CELL, 5, (ROOF, ROOF_DARK))
    return to_y_slope(rows)


def roof_eave():
    """0.5 m overhang lip with a fascia board. Its origin goes on a roof_slope's low
    edge (y = +1 of that cell) and it runs 0.5 m further out and down."""
    run = 0.5
    drop = run * math.tan(PITCH)
    rows = fp.roof_rows((-0.02, 0.0), (run, -drop), 0, CELL, 2, (ROOF, ROOF_DARK))
    fascia = strip("fascia", (run - 0.02, -drop - 0.05), (run + 0.02, -drop + 0.12), 0, CELL, 0.05, TRIM)
    soffit = rbox("soffit", (run / 2 - 0.1, 0, -drop / 2 - 0.08), (run, CELL, 0.03), TRIM, bevel=0.005)
    return to_y_slope(rows + [fascia, soffit])


def roof_ridge():
    """Ridge cap, 2 m long along X, for the peak where two slopes meet (z = 1.155 above
    the low edges of one cell each)."""
    return [rbox("cap", (0, 0, 0.12), (CELL, 0.34, 0.2), ROOF_DARK, bevel=0.06),
            rbox("cap_top", (0, 0, 0.24), (CELL, 0.2, 0.06), ROOF, bevel=0.025)]


def gable(scheme, side):
    """Triangular gable-end infill for one 2 m roof cell: the tall edge (1.155 m) is at
    x = -side (so _l is tall at -X, _r at +X in the modeling frame, which become
    +X / -X in Godot after the export turn). Sits on a
    wall at z = 3. They are mirror pairs so the siding always stays on the outside."""
    c = SCHEMES[scheme]
    tall = -side
    outline = [(-1.0, 0.0), (1.0, 0.0), (1.0, RISE)] if tall > 0 else [(-1.0, 0.0), (1.0, 0.0), (-1.0, RISE)]

    def color(co, n):
        return c["ext"] if n[1] > 0.3 else INTERIOR if n[1] < -0.3 else c["line"]
    parts = [fp.prism("gable", outline, 0, THICK, color)]
    z = 0.06
    while z < RISE - 0.1:
        width = CELL * (1 - z / RISE)
        x0, x1 = (1.0 - width, 1.0) if tall > 0 else (-1.0, -1.0 + width)
        p = box_between("siding", x0 + 0.02, x1 - 0.04, z, z + 0.022, THICK / 2 + 0.008, 0.016, c["line"], bevel=0.004)
        if p:
            parts.append(p)
        z += 0.24
    return parts


def stairs():
    """Straight stair, 1 m wide, climbing one storey (3 m) over 4 m toward -Y.
    Bottom step at y = +2, top landing edge at y = -2. Railing on the +X side."""
    n, rise, run = 16, STOREY / 16, 4.0 / 16
    parts = []
    for k in range(n):
        y = 2.0 - run * (k + 0.5)
        z = rise * (k + 1)
        parts.append(rbox("tread", (0, y, z - 0.025), (0.96, run + 0.02, 0.05), WOOD_LIGHT, bevel=0.01))
        parts.append(rbox("riser", (0, y + run / 2 - 0.01, z - rise / 2), (0.94, 0.02, rise), TRIM, bevel=0.004))
    for sx in (1, -1):
        parts.append(strip("stringer", (-2.0, STOREY - 0.12), (2.0, -0.12), 0, 0.06, 0.3, WOOD_DARK))
        xf(parts[-1], Matrix.Translation((sx * 0.5, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"))
    for k in range(0, n + 1, 3):
        y = 2.0 - run * k
        z = rise * k
        parts.append(rbox("baluster", (0.45, y - run / 2 if k else y - 0.1, z + 0.45), (0.04, 0.04, 0.9), TRIM,
                          bevel=0.008))
    parts.append(strip("handrail", (-2.0 + 0.1, STOREY + 0.9), (2.0 - 0.1, 0.9), 0, 0.07, 0.06, WOOD_DARK))
    xf(parts[-1], Matrix.Translation((0.45, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"))
    return parts


def export(name, parts):
    parts = [p for p in parts if p is not None]
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


PIECES = dict(build_walls())
PIECES.update({
    "corner_post": corner_post, "door_front": door_front, "door_interior": door_interior,
    "floor_wood": floor_wood, "floor_tile": floor_tile, "floor_carpet": floor_carpet,
    "roof_slope": roof_slope, "roof_eave": roof_eave, "roof_ridge": roof_ridge, "stairs": stairs,
})

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if a in PIECES]
    for name, fn in PIECES.items():
        if only and name not in only:
            continue
        reset_scene()
        export(name, fn())
