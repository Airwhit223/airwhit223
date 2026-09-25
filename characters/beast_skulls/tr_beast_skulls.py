"""Per-skull-type beast head shape keys for the Toriyama kit head.

Replaces the single shared TR_Muzzle idea (every lineage came out as the same dog) with one pair of
sculpted targets per skull type:

    TR_Skull_<Type>_Mid    b = 0.5   clearly animal, human-sized eyes and expressions still work
    TR_Skull_<Type>_Full   b = 1.0   animal humanoid head

Only the active type's two keys are ever nonzero. See beast_values() for the slider mapping and
docs/BEAST_HEADS_FIX.md for the full plan.

Everything that sticks out and can't be a morph (noses, ears, horns...) is a part mesh, built by
make_parts(). Part meshes carry the same key names so one set of values drives the whole head.

Usage inside the kit build (Blender):
    import tr_beast_skulls as bs
    bs.add_skull_keys(head_objects)                 # all meshes riding DEF-head
    parts = bs.make_parts("Canid", armature, head_objects)

Coordinates are the kit's rest space: Z up, face toward -Y, head centre about (0, 0, 1.62).
"""
import math

import bpy
from mathutils import Vector

# ---------------------------------------------------------------------------------------------
# Skull types. Every number is in metres in kit rest space. Each type has a Mid and Full set;
# the Mid set is its own sculpt (not Full * 0.5) so the halfway face can be tuned separately.
#
#   snout_len     how far the muzzle/jaw block comes forward at its centre
#   band          (lo0, lo1, hi0, hi1): vertical window of the face that moves. Below lo0 (neck)
#                 and above hi1 nothing moves. A low hi band gives a "stop" under the eyes (dogs);
#                 a high one slopes the forehead straight into the snout (reptiles).
#   axis_z        height the snout converges toward
#   taper_w/h     how much the front of the snout narrows / flattens (0 = face-wide box)
#   drop          tip sags down this much (dog nose sits lower than the eyes)
#   cheek         (outward push, z) puffs the cheeks sideways
#   chin_back     pulls the chin back (cats have almost no chin)
#   crown_flat    squashes the top of the skull (reptiles)
#   brow          forward/up push of a ridge over each eye
#   ear_shrink    0..1 tucks the human ears into the skull (animal ears are parts)
#   jaw_short     0..1 the lower jaw comes forward less than the upper snout (dogs, cats)
#   nose_flat     pushes the human nose back into the face so it doesn't ride out as a ridge
#   lip_flat      same for the human lips
#   eye           (spread x, back y, up z, scale) applied rigidly to the eye/brow decals
#   eye_yaw       degrees the eye decals turn outward (reptile eyes look sideways)
#   eye_follow    how much of the face's forward move the eyes take (reptile eyes stay back on the
#                 sides of the skull while the snout grows past them); default 1
# ---------------------------------------------------------------------------------------------
SKULLS = {
    "Canid": {  # wolf, dog, fox (fox: parts + a narrower taper later)
        "Mid": dict(snout_len=0.070, band=(1.43, 1.48, 1.585, 1.645), axis_z=1.545, taper_w=0.30,
                    taper_h=0.22, drop=0.006, cheek=(0.0, 1.57), chin_back=0.0, crown_flat=0.0,
                    brow=0.004, ear_shrink=0.6, eye=(0.004, 0.0, 0.0, 1.0),
                    jaw_short=0.35, nose_flat=0.006, lip_flat=0.004),
        "Full": dict(snout_len=0.150, band=(1.43, 1.48, 1.590, 1.655), axis_z=1.545, taper_w=0.55,
                     taper_h=0.40, drop=0.014, cheek=(0.006, 1.57), chin_back=0.0, crown_flat=0.0,
                     brow=0.010, ear_shrink=1.0, eye=(0.010, 0.008, 0.004, 0.92),
                     jaw_short=0.45, nose_flat=0.012, lip_flat=0.008, eye_yaw=8),
    },
    "Feline": {  # cat, lion, tiger: short muzzle pad, round flat face, big eyes, tiny chin
        "Mid": dict(snout_len=0.020, band=(1.47, 1.50, 1.565, 1.60), axis_z=1.545, taper_w=0.30,
                    taper_h=0.10, drop=0.0, cheek=(0.012, 1.565), chin_back=0.012, crown_flat=0.0,
                    brow=0.0, ear_shrink=0.6, eye=(0.004, 0.0, 0.002, 1.10),
                    jaw_short=0.5, nose_flat=0.010, lip_flat=0.004),
        "Full": dict(snout_len=0.050, band=(1.47, 1.50, 1.575, 1.615), axis_z=1.548, taper_w=0.50,
                     taper_h=0.20, drop=0.002, cheek=(0.030, 1.565), chin_back=0.034, crown_flat=0.0,
                     brow=0.0, ear_shrink=1.0, eye=(0.010, -0.004, 0.004, 1.22),
                     jaw_short=0.7, nose_flat=0.018, lip_flat=0.006),
    },
    "Saurian": {  # lizard, crocodilian, horned + crested dragon: long flat skull, no stop
        "Mid": dict(snout_len=0.080, band=(1.43, 1.48, 1.68, 1.79), axis_z=1.555, taper_w=0.22,
                    taper_h=0.30, drop=0.0, cheek=(0.0, 1.56), chin_back=0.0, crown_flat=0.25,
                    brow=0.010, ear_shrink=0.8, eye=(0.008, 0.006, 0.004, 0.95),
                    jaw_short=0.10, nose_flat=0.012, lip_flat=0.010, eye_follow=0.45, eye_yaw=16),
        "Full": dict(snout_len=0.175, band=(1.43, 1.48, 1.70, 1.82), axis_z=1.555, taper_w=0.36,
                     taper_h=0.52, drop=0.0, cheek=(0.0, 1.56), chin_back=0.0, crown_flat=0.45,
                     brow=0.018, ear_shrink=1.0, eye=(0.014, 0.012, 0.010, 0.85),
                     jaw_short=0.12, nose_flat=0.020, lip_flat=0.016, eye_follow=0.30, eye_yaw=24),
    },
}

# Lineage -> skull type. Lineages not yet sculpted fall back to the closest built type.
LINEAGE_SKULL = {
    "wolf": "Canid", "dog": "Canid", "fox": "Canid",
    "cat": "Feline", "lion": "Feline", "tiger": "Feline",
    "lizard": "Saurian", "crocodile": "Saurian", "dragon_horned": "Saurian", "dragon_crested": "Saurian",
}

# Rigid decals: moved as one piece (per side) so the painted eyes never smear.
RIGID_PREFIXES = ("Eye_", "Brow_", "AE_Eye", "AE_Brow")
EYE_PREFIXES = RIGID_PREFIXES
# Decals that ride the face but are moved as one piece per side at their centre.
FLOAT_PREFIXES = ("Mouth", "AE_Mouth", "Nose_", "Blush", "Ear_Ink")

FACE_Y = -0.12   # vertices at least this far forward count as fully "face"
BACK_Y = -0.02   # behind this nothing is pulled forward
EAR_X = 0.150    # human ear starts outside this half-width


def _smooth(e0, e1, x):
    if e0 == e1:
        return 1.0 if x >= e1 else 0.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _gauss(p, c, r):
    return math.exp(-((p - c).length_squared) / (r * r))


def displace(p, s):
    """Offset for one rest-space point under skull settings s. Pure function: no Blender state."""
    lo0, lo1, hi0, hi1 = s["band"]
    front = _smooth(-BACK_Y, -FACE_Y, -p.y)  # 0 behind, 1 on the face
    band = _smooth(lo0, lo1, p.z) * (1.0 - _smooth(hi0, hi1, p.z))
    w = front * band
    d = Vector((0.0, 0.0, 0.0))

    # human nose and lips sink into the face first, so the snout grows from a smooth surface
    d.y += s["nose_flat"] * _gauss(p, Vector((0.0, -0.18, 1.59)), 0.022)
    d.y += s["lip_flat"] * _gauss(p, Vector((0.0, -0.145, 1.535)), 0.020)

    # snout block: forward, narrower and flatter toward the tip, tip sags.
    # Below the snout axis the lower jaw comes forward less.
    jaw = 1.0 - s["jaw_short"] * _smooth(s["axis_z"], s["axis_z"] - 0.06, p.z)
    d.y -= s["snout_len"] * w * jaw
    d.x -= p.x * s["taper_w"] * w
    d.z -= (p.z - s["axis_z"]) * s["taper_h"] * w
    d.z -= s["drop"] * w * w

    # cheeks: sideways puff in a soft ball on each side of the muzzle
    push, cz = s["cheek"]
    if push:
        side = 1.0 if p.x >= 0 else -1.0
        d.x += side * push * _gauss(p, Vector((side * 0.095, -0.10, cz)), 0.055)

    # chin: pull back the point of the chin
    if s["chin_back"]:
        d.y += s["chin_back"] * _gauss(p, Vector((0.0, -0.13, 1.475)), 0.045)

    # crown: flatten the top of the skull toward a level plane
    if s["crown_flat"] and p.z > 1.70:
        d.z -= (p.z - 1.70) * s["crown_flat"] * _smooth(1.70, 1.80, p.z)

    # brow ridge over each eye
    if s["brow"]:
        side = 1.0 if p.x >= 0 else -1.0
        g = _gauss(p, Vector((side * 0.072, -0.15, 1.695)), 0.035)
        d.y -= s["brow"] * g
        d.z += s["brow"] * 0.4 * g

    # tuck the human ears into the skull
    if s["ear_shrink"] and abs(p.x) > EAR_X - 0.01:
        ear = _smooth(EAR_X - 0.01, EAR_X + 0.01, abs(p.x)) * _smooth(1.57, 1.61, p.z) \
            * (1.0 - _smooth(1.74, 1.78, p.z)) * (1.0 - _smooth(0.07, 0.10, p.y))
        side = 1.0 if p.x >= 0 else -1.0
        d.x -= side * (abs(p.x) - (EAR_X - 0.012)) * s["ear_shrink"] * ear
    return d


def _eye_offset(c, s):
    """Rigid move for an eye/brow decal centred at c: follow the face, then the type's eye tweak."""
    spread, back, up, _scale = s["eye"]
    side = 1.0 if c.x >= 0 else -1.0
    d = displace(c, s)
    d.y *= s.get("eye_follow", 1.0)
    return d + Vector((side * spread, back, up))


def _islands_by_side(me):
    """Vertex indices grouped by side of the face (left, right, centre) for rigid decals."""
    groups = {-1: [], 0: [], 1: []}
    for v in me.vertices:
        groups[0 if abs(v.co.x) < 0.012 else (1 if v.co.x > 0 else -1)].append(v.index)
    return [g for g in groups.values() if g]


class _Surface:
    """Frontmost point of the deformed head near a given (x, z), to keep eye decals on the skin."""

    def __init__(self, head, s):
        self.pts = [v.co + displace(v.co, s) for v in head.data.vertices if v.co.y < 0.0]
        self.rest = [v.co.copy() for v in head.data.vertices if v.co.y < 0.0]

    @staticmethod
    def _front(pts, x, z, r=0.008):
        near = [p.y for p in pts if abs(p.x - x) < r and abs(p.z - z) < r]
        return min(near) if near else None

    def gap(self, c):
        """How far in front of the rest skin the decal centre c sits."""
        y = self._front(self.rest, c.x, c.z)
        return 0.0 if y is None else y - c.y

    def y_at(self, x, z):
        return self._front(self.pts, x, z)


def _key_coords(obj, s, surface=None):
    me = obj.data
    basis = [v.co.copy() for v in me.vertices]
    name = obj.name
    if name.startswith(RIGID_PREFIXES) or name.startswith(FLOAT_PREFIXES):
        out = list(basis)
        is_eye = name.startswith(EYE_PREFIXES)
        scale = s["eye"][3] if is_eye else 1.0
        if name == "Ear_Ink":  # human ear lines go with the human ear
            scale = max(0.0, 1.0 - s["ear_shrink"])
        if name.startswith("Nose_"):  # the lineage nose part takes over
            scale = 0.0
        for group in _islands_by_side(me):
            c = sum((basis[i] for i in group), Vector()) / len(group)
            off = _eye_offset(c, s) if is_eye else displace(c, s)
            rot = None
            if is_eye:
                side = 1.0 if c.x >= 0 else -1.0
                yaw = math.radians(s.get("eye_yaw", 0.0)) * side
                rot = (math.cos(yaw), math.sin(yaw))
                if surface is not None:  # sit on the new skin, same gap as at rest
                    new_c = c + off
                    y = surface.y_at(new_c.x, new_c.z)
                    if y is not None:
                        off.y = (y - surface.gap(c)) - c.y
            for i in group:
                q = (basis[i] - c) * scale
                if rot:  # turn about the decal centre so it faces out to the side
                    q = Vector((q.x * rot[0] - q.y * rot[1], q.x * rot[1] + q.y * rot[0], q.z))
                out[i] = c + q + off
        return out
    return [p + displace(p, s) for p in basis]


def add_skull_keys(objects, types=None):
    """Add TR_Skull_<Type>_Mid/_Full to every mesh in objects (the head and its face decals)."""
    types = types or list(SKULLS)
    head = next((o for o in objects if o.name == "Head_Base"), None)
    surfaces = {(t, st): _Surface(head, SKULLS[t][st]) for t in types for st in ("Mid", "Full")} if head else {}
    for obj in objects:
        if obj.type != "MESH":
            continue
        if not obj.data.shape_keys:
            obj.shape_key_add(name="Basis", from_mix=False)
        basis = obj.data.shape_keys.reference_key
        for t in types:
            for stage in ("Mid", "Full"):
                s = SKULLS[t][stage]
                kname = f"TR_Skull_{t}_{stage}"
                kb = obj.data.shape_keys.key_blocks.get(kname) or obj.shape_key_add(name=kname, from_mix=False)
                kb.relative_key = basis
                kb.value = 0.0
                coords = _key_coords(obj, s, surfaces.get((t, stage)))
                for i, co in enumerate(coords):
                    kb.data[i].co = co


def beast_values(lineage, b):
    """Shape-key values for a lineage at slider b (0 human .. 1 animal humanoid; >1 is awakening).

    0.25 hybrid is still a human skull: traits come from parts only.
    """
    t = LINEAGE_SKULL[lineage]
    mid = max(0.0, min(1.0, (b - 0.25) / 0.25))
    full = max(0.0, min(1.0, (b - 0.5) / 0.5))
    vals = {f"TR_Skull_{k}_{st}": 0.0 for k in SKULLS for st in ("Mid", "Full")}
    vals[f"TR_Skull_{t}_Mid"] = mid * (1.0 - full)
    vals[f"TR_Skull_{t}_Full"] = full
    return vals


def parts_visible(lineage, b):
    """Which part sets show at slider b. Ears/tail from hybrid up; nose once the skull turns."""
    return {"ears": b >= 0.2, "nose": b >= 0.3}


# ---------------------------------------------------------------------------------------------
# Parts
# ---------------------------------------------------------------------------------------------

def _mat(name, rgb):
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.55
    return m


def _mesh_from(name, verts, faces, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _ellipsoid(center, radii, seg=16, ring=10):
    verts, faces = [], []
    for r in range(ring + 1):
        th = math.pi * r / ring
        for s in range(seg):
            ph = 2 * math.pi * s / seg
            verts.append(Vector((math.sin(th) * math.cos(ph) * radii[0],
                                 math.sin(th) * math.sin(ph) * radii[1],
                                 math.cos(th) * radii[2])) + center)
    for r in range(ring):
        for s in range(seg):
            a, b = r * seg + s, r * seg + (s + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    return verts, faces


def _ear(base, tip_up, width, depth, lean_out, lean_back, cup=0.35, seg=10):
    """A curved, cupped triangular ear. base: centre of the root on the skull (right side, x>0)."""
    verts, faces = [], []
    rows = 8
    for r in range(rows + 1):
        t = r / rows
        half = width * 0.5 * (1 - t) ** 0.85
        centre = base + Vector((lean_out * t, lean_back * t * t, tip_up * t))
        for s in range(seg + 1):
            u = s / seg * 2 - 1  # -1..1 across the ear
            # cup: the middle sits back, the edges forward; thickness via front/back sheets
            y = cup * 3 * depth * (u * u - 1) * (1 - t * 0.6)
            verts.append(centre + Vector((u * half * 0.85, u * half * 0.55 + y, 0.0)))
    n = seg + 1
    for r in range(rows):
        for s in range(seg):
            a = r * n + s
            faces.append((a, a + 1, a + n + 1, a + n))
    return verts, faces


def _mirror(verts, faces):
    off = len(verts)
    mv = [Vector((-v.x, v.y, v.z)) for v in verts]
    mf = [tuple(off + i for i in reversed(f)) for f in faces]
    return verts + mv, faces + mf


def _skin_to_head(obj, arm):
    """Weight the whole part to DEF-head, like the other face parts, so it exports skinned."""
    if arm is None:
        return
    vg = obj.vertex_groups.new(name="DEF-head")
    vg.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def _tip_of(head, s):
    """Where the nose lands under settings s: the most forward displaced point on the centre line."""
    best = None
    for v in head.data.vertices:
        p = v.co
        if abs(p.x) > 0.02 or not (1.50 < p.z < 1.63) or p.y > -0.10:
            continue
        q = p + displace(p, s)
        if best is None or q.y < best.y:
            best = q
    return best


def _keyed_part(obj, head, t, rest_tip):
    """Give a nose part the skull keys: it rides from the human nose to each stage's snout tip."""
    obj.shape_key_add(name="Basis", from_mix=False)
    basis = [v.co.copy() for v in obj.data.vertices]
    for stage in ("Mid", "Full"):
        tip = _tip_of(head, SKULLS[t][stage])
        grow = 1.0 if stage == "Full" else 0.7
        kb = obj.shape_key_add(name=f"TR_Skull_{t}_{stage}", from_mix=False)
        for i, p in enumerate(basis):
            kb.data[i].co = tip + (p - rest_tip) * grow
    # at rest (b < 0.5) the nose is shrunk into the human nose tip
    for i, p in enumerate(basis):
        co = rest_tip + (p - rest_tip) * 0.35
        obj.data.shape_keys.reference_key.data[i].co = co
        obj.data.vertices[i].co = co


def make_parts(t, arm, head, fur=(0.55, 0.42, 0.32), inner=(0.93, 0.72, 0.70)):
    """Build the part meshes for skull type t. Returns {part_set: [objects]}."""
    dark = _mat("Part_NosePad", (0.04, 0.035, 0.035))
    pink = _mat("Part_NosePink", (0.88, 0.50, 0.55))
    furm = _mat(f"Part_Fur_{t}", fur)
    out = {"ears": [], "nose": []}
    rest_tip = Vector((0.0, -0.182, 1.585))

    if t == "Canid":
        v, f = _ellipsoid(rest_tip + Vector((0, -0.008, 0.006)), (0.022, 0.016, 0.015))
        # flatten the underside into a pad with a centre groove
        v = [Vector((p.x, p.y, p.z - 0.004 * math.exp(-(p.x / 0.004) ** 2) * (p.z < rest_tip.z)))
             for p in v]
        nose = _mesh_from(f"TR_Beast_Nose_{t}", v, f, dark)
        v, f = _mirror(*_ear(Vector((0.092, 0.015, 1.780)), 0.110, 0.130, 0.030, 0.028, 0.030))
        ears = _mesh_from(f"TR_Beast_Ears_{t}", v, f, furm)
    elif t == "Feline":
        # small inverted-triangle nose
        c = rest_tip + Vector((0, -0.004, 0.0))
        v = [c + Vector((-0.012, 0, 0.006)), c + Vector((0.012, 0, 0.006)), c + Vector((0, -0.004, -0.008)),
             c + Vector((-0.010, 0.008, 0.005)), c + Vector((0.010, 0.008, 0.005)), c + Vector((0, 0.006, -0.007))]
        f = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
        nose = _mesh_from(f"TR_Beast_Nose_{t}", v, f, pink)
        v, f = _mirror(*_ear(Vector((0.098, 0.005, 1.775)), 0.095, 0.145, 0.030, 0.030, 0.012))
        ears = _mesh_from(f"TR_Beast_Ears_{t}", v, f, furm)
    elif t == "Saurian":
        # two nostril bumps on top of the snout, no external ears
        v1, f1 = _ellipsoid(rest_tip + Vector((0.010, 0.000, 0.010)), (0.006, 0.009, 0.004), 10, 6)
        v2, f2 = _ellipsoid(rest_tip + Vector((-0.010, 0.000, 0.010)), (0.006, 0.009, 0.004), 10, 6)
        nose = _mesh_from(f"TR_Beast_Nose_{t}", v1 + v2, f1 + [tuple(i + len(v1) for i in q) for q in f2], dark)
        ears = None
    else:
        raise KeyError(t)

    _keyed_part(nose, head, t, rest_tip)
    out["nose"].append(nose)
    if ears:
        out["ears"].append(ears)
    for o in out["nose"] + out["ears"]:
        _skin_to_head(o, arm)
    return out
