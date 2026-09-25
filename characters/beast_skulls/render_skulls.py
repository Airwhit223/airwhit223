"""Build the skull keys on the kit base head and render the check strips.

    python3 render_skulls.py <kit base .glb> <out dir>      (needs `pip install bpy pillow`)

Writes silhouette_<family>.png (black side profiles, the "can you tell them apart" test) and
color_<family>.png (3/4 view in color) for beastfolk, draconic and aquatic, plus a .blend and a
.glb with the keys and parts.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tr_beast_skulls as bs  # noqa: E402

SRC, OUT = sys.argv[-2], sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
FAMILIES = {
    "beastfolk": [("Canid", "wolf", (0.42, 0.40, 0.42)), ("Feline", "cat", (0.85, 0.55, 0.28)),
                  ("Ursine", "bear", (0.42, 0.27, 0.16))],
    "draconic": [("Saurian", "lizard", (0.42, 0.58, 0.30)), ("Saurian", "dragon_horned", (0.24, 0.36, 0.30)),
                 ("Saurian", "dragon_crested", (0.55, 0.20, 0.32)), ("Gecko", "gecko", (0.92, 0.72, 0.35)),
                 ("Gecko", "chameleon", (0.35, 0.72, 0.58)), ("Gecko", "dragon_winglet", (0.82, 0.62, 0.30))],
    "aquatic": [("Shark", "shark", (0.40, 0.50, 0.62)), ("Aquatic", "fish", (0.50, 0.80, 0.78)),
                ("Aquatic", "eel", (0.12, 0.20, 0.30)), ("Aquatic", "coral", (0.95, 0.62, 0.55)),
                ("Cephalo", "octopus", (0.58, 0.45, 0.78)), ("Manta", "manta", (0.30, 0.33, 0.40))],
}
TYPES = [r for rows in FAMILIES.values() for r in rows]
ONLY = os.environ.get("ROWS")  # e.g. ROWS=shark,bear to render just those lineages
ROWS = [r for r in TYPES if not ONLY or r[1] in ONLY.split(",")]
STAGES = [0.0, 0.25, 0.5, 1.0]
SKIN = (0.85, 0.62, 0.48)


def mat(name, rgb, emit=False):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    n = nt.nodes.new("ShaderNodeEmission" if emit else "ShaderNodeBsdfPrincipled")
    n.inputs[0].default_value = (*rgb, 1)
    nt.links.new(n.outputs[0], o.inputs[0])
    return m


# --- load and clean the kit head ------------------------------------------------------------
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in list(bpy.data.objects):
    if o.name == "Icosphere":
        bpy.data.objects.remove(o)
arm = bpy.data.objects["Armature"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
head_objs = [o for o in meshes if o.name != "Body_Base"]
head = bpy.data.objects["Head_Base"]
for o in meshes:
    if o.data.shape_keys:
        for k in o.data.shape_keys.key_blocks:
            if k.name in ("Pose_Rest", "TR_Chin"):
                k.value = 1.0

bs.add_skull_keys(head_objs)
parts = {}
for t, _, fur in TYPES:
    if t not in parts:
        parts[t] = bs.make_parts(t, arm, head, fur=fur)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "beast_skulls_M.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "beast_skulls_M.glb"), export_morph=True, export_skins=True)

# --- preview materials (kit materials need the game shaders) ---------------------------------
skin = mat("PV_Skin", SKIN)
clear = bpy.data.materials.new("PV_Clear")
clear.use_nodes = True
_nt = clear.node_tree
_nt.nodes.clear()
_nt.links.new(_nt.nodes.new("ShaderNodeBsdfTransparent").outputs[0], _nt.nodes.new("ShaderNodeOutputMaterial").inputs[0])
for o in meshes:
    if o.name.startswith("AE_") or o.name in ("Blush", "DQ8_Neck_Shadow"):
        o.hide_render = True
    elif o.name in ("Head_Base", "Body_Base"):
        o.data.materials.clear()
        o.data.materials.append(skin)
    else:
        for i, m in enumerate(o.data.materials):
            if m and any(k in m.name for k in ("Skin", "Face_Shade", "Sclera_Shade")):
                o.data.materials[i] = clear
            elif m and "Iris" in m.name:
                o.data.materials[i] = mat("PV_Iris", (0.25, 0.15, 0.08))
            elif m and "Pupil" in m.name:
                o.data.materials[i] = mat("PV_Pupil", (0.01, 0.01, 0.01))
            elif m and ("Ink" in m.name or "Brow" in m.name or "Mouth_Line" in m.name):
                o.data.materials[i] = mat("PV_Ink", (0.05, 0.03, 0.03))

sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.use_denoising = False
sc.render.resolution_x = sc.render.resolution_y = 420
sc.view_settings.view_transform = "Standard"
sc.world = sc.world or bpy.data.worlds.new("w")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"]
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 0.62
sc.collection.objects.link(cam)
sc.camera = cam
sil = mat("PV_Sil", (0, 0, 0), emit=True)


def apply(t, lineage, b):
    vals = bs.beast_values(lineage, b) if t else {}
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.shape_keys:
            for k in o.data.shape_keys.key_blocks:
                if k.name.startswith("TR_Skull_"):
                    k.value = vals.get(k.name, 0.0)
    show = bs.parts_visible(lineage, b) if t else {}
    for tt, sets in parts.items():
        for name, objs in sets.items():
            for o in objs:
                o.hide_render = not (tt == t and show.get(name))
    # animal end: the skin turns to the lineage's fur/scale color from mid up
    fur = dict((ln, c) for _, ln, c in TYPES).get(lineage, SKIN)
    k = max(0.0, min(1.0, (b - 0.25) / 0.75)) if t else 0.0
    skin.node_tree.nodes[1].inputs[0].default_value = (*[s + (f - s) * k for s, f in zip(SKIN, fur)], 1)
    for name, c in ((f"Part_Fur_{t}", fur), (f"Part_Crest_{t}", tuple(x * 0.7 for x in fur))):
        m = bpy.data.materials.get(name)
        if m:
            m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*c, 1)


def shot(path, view, silhouette):
    c = Vector((0, -0.05, 1.63))
    cam.location = c + (Vector((3, 0, 0)) if view == "side" else Vector((2.0, -2.2, 0.35)))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.material_override = sil if silhouette else None
    for o in meshes:  # flat face decals are not part of the head shape
        if o.name.startswith(("Eye_", "Brow_", "Mouth", "Nose_", "Ear_Ink")):
            o.hide_render = silhouette
    sun.hide_render = silhouette
    bg.inputs[0].default_value = (1, 1, 1, 1)
    bg.inputs[1].default_value = 1.0 if silhouette else 0.55
    sc.cycles.samples = 1 if silhouette else 24
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


tiles = {}
for t, lineage, _ in ROWS:
    for b in STAGES:
        apply(t, lineage, b)
        for view, s in (("side", True), ("q", False)):
            p = os.path.join(OUT, "tiles", f"{lineage}_{b:.2f}_{view}.png")
            shot(p, view, s)
            tiles[(lineage, b, view)] = p
apply(None, None, 0)

# --- contact sheets --------------------------------------------------------------------------
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

try:
    font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
except OSError:
    font = ImageFont.load_default()
for (view, prefix), (family, frows) in [(v, f) for v in (("side", "silhouette"), ("q", "color"))
                                        for f in FAMILIES.items()]:
    frows = [r for r in frows if r in ROWS]
    if not frows:
        continue
    name = f"{prefix}_{family}.png"
    W = H = 420
    sheet = Image.new("RGB", (220 + W * len(STAGES), 50 + H * len(frows)), "white")
    d = ImageDraw.Draw(sheet)
    for j, b in enumerate(STAGES):
        label = {0.0: "b=0  human", 0.25: "b=0.25  hybrid", 0.5: "b=0.5  mid", 1.0: "b=1  full"}[b]
        d.text((220 + j * W + 20, 14), label, fill="black", font=font)
    for i, (t, lineage, _) in enumerate(frows):
        d.text((12, 50 + i * H + H // 2 - 24), t, fill="black", font=font)
        d.text((12, 50 + i * H + H // 2 + 4), lineage, fill="gray", font=font)
        for j, b in enumerate(STAGES):
            sheet.paste(Image.open(tiles[(lineage, b, view)]).convert("RGB"), (220 + j * W, 50 + i * H))
    sheet.save(os.path.join(OUT, name))
print("done")
