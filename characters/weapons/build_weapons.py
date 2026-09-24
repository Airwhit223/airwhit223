"""Egyptian weapons: spear, battle axe, bow and quiver.

Run with Blender 5.x:
    blender --background --python characters/weapons/build_weapons.py
or with the bpy pip module (Python 3.13):
    python characters/weapons/build_weapons.py

Each weapon's origin is its grip point and it points up +Z (+Y in Godot), so
it can be dropped under a BoneAttachment3D on the hand bone.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
from base_character import (  # noqa: E402
    Matrix, Vector, add_capsule, add_ellipsoid, apply_modifiers, bmesh, bpy, join, make_material, new_object, paint,
    remesh_and_smooth, reset_scene, select_only, srgb, tube,
)

GOLD = srgb(0.93, 0.74, 0.3)
GOLD_DARK = srgb(0.68, 0.48, 0.16)
TURQUOISE = srgb(0.2, 0.72, 0.7)
WOOD = srgb(0.42, 0.26, 0.14)
STEEL = srgb(0.8, 0.82, 0.86)
LEATHER = srgb(0.5, 0.3, 0.16)
WHITE = srgb(0.95, 0.94, 0.9)


def solid(name, bm, color_fn, voxel=None, smooth=0):
    obj = new_object(name, bm)
    if voxel:
        remesh_and_smooth(obj, voxel=voxel, smooth_repeat=smooth)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn)
    return obj


def prism(name, outline, thickness, color_fn, axis_y=True):
    """Extrudes a 2D outline [(x, z), ...] in the XZ plane by thickness along Y."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -thickness / 2, z)) for x, z in outline]
    back = [bm.verts.new((x, thickness / 2, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = new_object(name, bm)
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = min(0.006, thickness * 0.4)
    bev.segments = 2
    apply_modifiers(obj)
    select_only(obj)
    bpy.ops.object.shade_smooth()
    paint(obj, color_fn)
    return obj


def rings(name, zs, radius, height, color):
    bm = bmesh.new()
    for z in zs:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=radius, radius2=radius, depth=height,
                              matrix=Matrix.Translation((0, 0, z)))
    return solid(name, bm, lambda co, n: color)


def export(name, parts):
    body = parts[0]
    join(parts[1:], body)
    body.data.materials.clear()
    body.data.materials.append(make_material(name))
    body.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, name + ".glb"), export_format="GLB",
                              export_vertex_color="MATERIAL")
    print(f"{name}: {sum(len(p.vertices) - 2 for p in body.data.polygons)} triangles")


def spear():
    reset_scene()
    parts = [tube("shaft", [Vector((0, 0, -0.9)), Vector((0, 0, 1.05))], 0.016, WOOD)]
    parts.append(rings("bands", [-0.88, -0.2, 0.2, 1.02], 0.021, 0.035, GOLD))
    # Leaf-shaped blade.
    outline = [(0, 1.45)] + [(0.045 * math.sin(math.pi * (1 - t)) ** 0.7, 1.08 + 0.37 * t) for t in
                             [k / 10 for k in range(1, 10)]] + [(0, 1.08)] + \
              [(-0.045 * math.sin(math.pi * (1 - t)) ** 0.7, 1.08 + 0.37 * t) for t in [k / 10 for k in range(9, 0, -1)]]
    parts.append(prism("blade", outline, 0.012, lambda co, n: STEEL))
    bm = bmesh.new()
    add_ellipsoid(bm, (0, 0, 1.08), (0.028, 0.028, 0.05))
    add_ellipsoid(bm, (0, 0, 0.96), (0.022, 0.022, 0.03))
    parts.append(solid("socket", bm, lambda co, n: TURQUOISE if abs(co.z - 1.08) < 0.02 else GOLD, voxel=0.004))
    # Turquoise tassel below the blade.
    bm = bmesh.new()
    add_capsule(bm, (0, 0, 0.93), (0, 0, 0.8), 0.018, 0.03)
    parts.append(solid("tassel", bm, lambda co, n: TURQUOISE, voxel=0.004, smooth=1))
    bm = bmesh.new()
    add_ellipsoid(bm, (0, 0, -0.93), (0.02, 0.02, 0.05))
    parts.append(solid("butt", bm, lambda co, n: GOLD))
    export("spear", parts)


def axe():
    reset_scene()
    parts = [tube("shaft", [Vector((0, 0, -0.35)), Vector((0, 0, 0.65))], 0.018, WOOD)]
    parts.append(rings("bands", [-0.33, 0.35, 0.44], 0.023, 0.03, GOLD))
    # Crescent head facing +X.
    outline = []
    for k in range(13):
        a = math.radians(-70 + k * (140 / 12))
        outline.append((0.03 + 0.2 * math.cos(a), 0.5 + 0.2 * math.sin(a)))
    for k in range(12, -1, -1):
        a = math.radians(-60 + k * (120 / 12))
        outline.append((0.005 + 0.07 * math.cos(a) * 0.35, 0.5 + 0.1 * math.sin(a)))

    def head_color(co, n):
        r = math.hypot(co.x - 0.03, co.z - 0.5)
        if r > 0.195:
            return STEEL  # edge
        return TURQUOISE if 0.13 < r < 0.155 and abs(n.y) > 0.5 else GOLD
    parts.append(prism("head", outline, 0.022, head_color))
    bm = bmesh.new()
    add_ellipsoid(bm, (0, 0, 0.5), (0.03, 0.03, 0.08))
    parts.append(solid("socket", bm, lambda co, n: GOLD_DARK))
    # Back spike and top point.
    parts.append(prism("spike", [(-0.02, 0.46), (-0.14, 0.5), (-0.02, 0.54)], 0.02, lambda co, n: GOLD))
    parts.append(prism("tip", [(-0.015, 0.64), (0, 0.72), (0.015, 0.64)], 0.02, lambda co, n: GOLD))
    export("axe", parts)


def bow():
    reset_scene()
    # Recurve bow: limbs curve back from the grip then tips flick forward (+Y).
    pts = []
    for k in range(41):
        t = -1 + k / 20
        z = 0.72 * t
        y = -0.12 * (1 - t * t) + 0.06 * max(0.0, abs(t) - 0.8) / 0.2
        pts.append(Vector((0, y, z)))
    parts = [tube("limb", pts, 0.016, WOOD)]

    def wraps(co, n):
        return TURQUOISE if int(abs(co.z) * 30) % 3 == 0 and 0.2 < abs(co.z) < 0.6 else GOLD
    paint(parts[0], wraps)
    parts.append(tube("grip", [Vector((0, -0.12, -0.08)), Vector((0, -0.12, 0.08))], 0.022, LEATHER))
    parts.append(tube("string", [pts[0], pts[-1]], 0.0025, WHITE))
    export("bow", parts)


def quiver():
    reset_scene()
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.055, radius2=0.07, depth=0.55,
                          matrix=Matrix.Translation((0, 0, 0.0)))
    parts = [solid("case", bm, lambda co, n: LEATHER)]
    parts.append(rings("bands", [-0.26, 0.0, 0.26], 0.074, 0.035, GOLD))
    for i, (x, y) in enumerate([(0, 0), (0.025, 0.02), (-0.025, 0.02), (0.02, -0.025), (-0.02, -0.025)]):
        top = Vector((x, y, 0.42 + 0.02 * (i % 2)))
        parts.append(tube("arrow", [Vector((x, y, 0.2)), top], 0.004, WOOD))
        bm = bmesh.new()
        add_ellipsoid(bm, top + Vector((0, 0, -0.03)), (0.016, 0.004, 0.04))
        add_ellipsoid(bm, top + Vector((0, 0, -0.03)), (0.004, 0.016, 0.04))
        parts.append(solid("fletch", bm, lambda co, n: WHITE))
    export("quiver", parts)


if __name__ == "__main__":
    spear()
    axe()
    bow()
    quiver()
