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
#   skull_wide    pushes the sides of the skull out (bears, geckos)
#   throat        fills the angle under the jaw forward so the head runs into the neck (sharks)
#   brow_scale    size of the brow decals (reptiles and sharks get slimmer brows); default 1
#   taper_jaw     True: the lower jaw also skips the snout taper, so an underslung jaw stays put
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
                    jaw_short=0.10, nose_flat=0.012, lip_flat=0.010, eye_follow=0.45, eye_yaw=16, brow_scale=0.85),
        "Full": dict(snout_len=0.175, band=(1.43, 1.48, 1.70, 1.82), axis_z=1.555, taper_w=0.36,
                     taper_h=0.52, drop=0.0, cheek=(0.0, 1.56), chin_back=0.0, crown_flat=0.45,
                     brow=0.018, ear_shrink=1.0, eye=(0.014, 0.012, 0.010, 0.85),
                     jaw_short=0.12, nose_flat=0.020, lip_flat=0.016, eye_follow=0.30, eye_yaw=24, brow_scale=0.7),
    },
    "Shark": {  # pointed rostrum over an underslung mouth, eyes on the sides, head runs into the neck
        "Mid": dict(snout_len=0.070, band=(1.47, 1.51, 1.70, 1.80), axis_z=1.585, taper_w=0.45,
                    taper_h=0.40, drop=0.0, cheek=(0.0, 1.56), chin_back=0.018, crown_flat=0.12,
                    brow=0.004, ear_shrink=1.0, eye=(0.010, 0.008, 0.0, 0.92),
                    jaw_short=0.85, nose_flat=0.012, lip_flat=0.012, eye_follow=0.5, eye_yaw=18,
                    throat=0.012, skull_wide=0.006, taper_jaw=True, brow_scale=0.85),
        "Full": dict(snout_len=0.140, band=(1.48, 1.52, 1.72, 1.84), axis_z=1.590, taper_w=0.70,
                     taper_h=0.62, drop=0.0, cheek=(0.0, 1.56), chin_back=0.040, crown_flat=0.28,
                     brow=0.006, ear_shrink=1.0, eye=(0.020, 0.018, 0.0, 0.80),
                     jaw_short=0.95, nose_flat=0.020, lip_flat=0.018, eye_follow=0.35, eye_yaw=36,
                     throat=0.024, skull_wide=0.012, taper_jaw=True, brow_scale=0.75),
    },
    "Ursine": {  # bear: round wide skull, short broad blunt snout, small eyes, round ears (part)
        "Mid": dict(snout_len=0.035, band=(1.44, 1.49, 1.600, 1.650), axis_z=1.550, taper_w=0.15,
                    taper_h=0.15, drop=0.004, cheek=(0.012, 1.56), chin_back=0.0, crown_flat=0.0,
                    brow=0.004, ear_shrink=0.7, eye=(0.006, 0.0, 0.004, 0.92),
                    jaw_short=0.30, nose_flat=0.008, lip_flat=0.004, skull_wide=0.008),
        "Full": dict(snout_len=0.085, band=(1.44, 1.49, 1.605, 1.660), axis_z=1.550, taper_w=0.28,
                     taper_h=0.25, drop=0.008, cheek=(0.026, 1.57), chin_back=0.010, crown_flat=0.0,
                     brow=0.008, ear_shrink=1.0, eye=(0.012, 0.004, 0.006, 0.78),
                     jaw_short=0.35, nose_flat=0.014, lip_flat=0.008, skull_wide=0.018),
    },
    "Gecko": {  # gecko, chameleon, winglet dragon: wide round head, huge smile, no snout, big side eyes
        "Mid": dict(snout_len=0.020, band=(1.44, 1.49, 1.66, 1.74), axis_z=1.560, taper_w=0.05,
                    taper_h=0.12, drop=0.0, cheek=(0.018, 1.53), chin_back=0.0, crown_flat=0.15,
                    brow=0.003, ear_shrink=1.0, eye=(0.012, 0.004, 0.006, 1.15),
                    jaw_short=0.0, nose_flat=0.014, lip_flat=0.010, eye_follow=0.8, eye_yaw=12,
                    skull_wide=0.012, brow_scale=0.75),
        "Full": dict(snout_len=0.045, band=(1.44, 1.49, 1.68, 1.78), axis_z=1.560, taper_w=0.12,
                     taper_h=0.25, drop=0.0, cheek=(0.035, 1.53), chin_back=0.0, crown_flat=0.30,
                     brow=0.006, ear_shrink=1.0, eye=(0.024, 0.010, 0.012, 1.35),
                     jaw_short=0.0, nose_flat=0.020, lip_flat=0.016, eye_follow=0.6, eye_yaw=20,
                     skull_wide=0.020, brow_scale=0.55),
    },
}

# Lineage -> skull type. Lineages not yet sculpted fall back to the closest built type.
LINEAGE_SKULL = {
    "wolf": "Canid", "dog": "Canid", "fox": "Canid",
    "cat": "Feline", "lion": "Feline", "tiger": "Feline",
    "lizard": "Saurian", "crocodile": "Saurian", "dragon_horned": "Saurian", "dragon_crested": "Saurian",
    "shark": "Shark",
    "bear": "Ursine",
    "gecko": "Gecko", "chameleon": "Gecko", "dragon_winglet": "Gecko",
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
    tw = w * jaw if s.get("taper_jaw") else w
    d.x -= p.x * s["taper_w"] * tw
    d.z -= (p.z - s["axis_z"]) * s["taper_h"] * tw
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

    # wider skull sides
    if s.get("skull_wide"):
        side = 1.0 if p.x >= 0 else -1.0
        g = _smooth(0.03, 0.12, abs(p.x)) * math.exp(-((p.z - 1.62) / 0.10) ** 2) * (1.0 - _smooth(0.08, 0.14, p.y))
        d.x += side * s["skull_wide"] * g

    # fill under the jaw so the head runs into the neck
    if s.get("throat"):
        g = _smooth(1.415, 1.46, p.z) * (1.0 - _smooth(1.49, 1.52, p.z)) * _smooth(0.0, 0.05, -p.y)
        d.y -= s["throat"] * g

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
        if name.startswith(("Brow_", "AE_Brow")):
            scale *= s.get("brow_scale", 1.0)
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
    """Which part sets show at slider b. Ears and gills from hybrid up; nose/mouth once the skull turns."""
    return {"ears": b >= 0.2, "gills": b >= 0.2, "nose": b >= 0.3, "mouth": b >= 0.3,
            "casque": lineage == "chameleon" and b >= 0.3}


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


def _ear(base, tip_up, width, depth, lean_out, lean_back, cup=0.35, seg=10, round_tip=False):
    """A curved, cupped triangular ear. base: centre of the root on the skull (right side, x>0)."""
    verts, faces = [], []
    rows = 8
    for r in range(rows + 1):
        t = r / rows
        half = width * 0.5 * (math.sqrt(max(0.0, 1 - t * t)) if round_tip else (1 - t) ** 0.85)
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


def _rest_front(head, x, z, r=0.010):
    """Frontmost rest-space point on the head near (x, z)."""
    near = [v.co for v in head.data.vertices if abs(v.co.x - x) < r and abs(v.co.z - z) < r and v.co.y < 0]
    return min(near, key=lambda p: p.y).copy()


def _rest_top(head, y, r=0.010):
    """Top of the skull on the centre line at depth y."""
    near = [v.co for v in head.data.vertices if abs(v.co.x) < r and abs(v.co.y - y) < r and v.co.z > 1.6]
    return max(near, key=lambda p: p.z).copy()


def _rest_side(head, y, z, r=0.010):
    """Outermost rest-space point on the right side of the head near (y, z)."""
    near = [v.co for v in head.data.vertices if abs(v.co.y - y) < r and abs(v.co.z - z) < r and v.co.x > 0]
    return max(near, key=lambda p: p.x).copy()


def _keyed_sheet(name, t, rows, mat, rest_shrink=None):
    """A grid part whose points are (anchor on the rest head, offset). Each skull stage moves every
    anchor with displace(), so the part stays glued to the reshaped skin.

    rows: list of rows, each a list of (anchor Vector, offset Vector). Faces join neighbouring rows.
    rest_shrink: (centre, factor) to shrink the basis (the part is hidden at rest anyway).
    """
    verts = [a + o for row in rows for a, o in row]
    n = len(rows[0])
    faces = [(r * n + i, r * n + i + 1, (r + 1) * n + i + 1, (r + 1) * n + i)
             for r in range(len(rows) - 1) for i in range(n - 1)]
    obj = _mesh_from(name, verts, faces, mat)
    obj.shape_key_add(name="Basis", from_mix=False)
    for stage in ("Mid", "Full"):
        st = SKULLS[t][stage]
        kb = obj.shape_key_add(name=f"TR_Skull_{t}_{stage}", from_mix=False)
        i = 0
        for row in rows:
            for a, o in row:
                kb.data[i].co = a + displace(a, st) + o
                i += 1
    if rest_shrink:
        c, k = rest_shrink
        for i, p in enumerate(verts):
            co = c + (p - c) * k
            obj.data.shape_keys.reference_key.data[i].co = co
            obj.data.vertices[i].co = co
    return obj


def _out(a, amount=0.0025):
    """Offset that lifts a point off the skin, away from the head centre."""
    return (a - Vector((0.0, 0.0, 1.62))).normalized() * amount


def _mouth_line(head, t, name, half_w, z0, curve, width, mat, samples=15):
    """A dark mouth ribbon on the face surface along z = z0 + curve * (x / half_w)^2."""
    top, bot = [], []
    for i in range(samples):
        x = -half_w + 2 * half_w * i / (samples - 1)
        a = _rest_front(head, x, z0 + curve * (x / half_w) ** 2)
        top.append((a, _out(a)))
        bot.append((a, _out(a) + Vector((0, 0, -width))))
    return _keyed_sheet(name, t, [top, bot], mat, (Vector((0, -0.145, 1.535)), 0.3)), top


def _teeth(head, t, name, row, size, mat):
    """Small triangles hanging from a mouth line (row of anchors, as returned by _mouth_line)."""
    verts_rows = []
    objs = []
    tri_rows = [[], []]
    for i in range(0, len(row) - 1):
        a0, o0 = row[i]
        a1, o1 = row[i + 1]
        mid = (a0 + a1) * 0.5
        tri_rows[0] += [(a0, o0 * 1.3), (a1, o1 * 1.3)]
        tri_rows[1] += [(mid, (o0 + o1) * 0.65 + Vector((0, 0, -size))), (mid, (o0 + o1) * 0.65 + Vector((0, 0, -size)))]
    # quads with a collapsed bottom edge = triangles; drop the faces between neighbouring teeth
    obj = _keyed_sheet(name, t, tri_rows, mat, (Vector((0, -0.145, 1.535)), 0.3))
    me = obj.data
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for i, f in enumerate(bm.faces) if i % 2 == 1], context="FACES")
    bm.to_mesh(me)
    bm.free()
    return obj


def _gill_slits(head, mat):
    """Three slits on each side of the jaw, behind the mouth. Static: the neck doesn't reshape."""
    verts, faces = [], []
    for k, y in enumerate((-0.035, -0.012, 0.011)):
        z0, z1 = 1.485, 1.545 - 0.006 * k
        a0, a1 = _rest_side(head, y, z0), _rest_side(head, y, z1)
        b = len(verts)
        for a in (a0, a1):
            verts += [a + Vector((0.002, -0.003, 0)), a + Vector((0.002, 0.003, 0))]
        faces.append((b, b + 1, b + 3, b + 2))
    return _mirror(verts, faces)


def make_parts(t, arm, head, fur=(0.55, 0.42, 0.32), inner=(0.93, 0.72, 0.70)):
    """Build the part meshes for skull type t. Returns {part_set: [objects]}."""
    dark = _mat("Part_NosePad", (0.04, 0.035, 0.035))
    pink = _mat("Part_NosePink", (0.88, 0.50, 0.55))
    white = _mat("Part_Teeth", (0.95, 0.94, 0.90))
    furm = _mat(f"Part_Fur_{t}", fur)
    out = {"ears": [], "nose": [], "mouth": [], "gills": [], "casque": []}
    rest_tip = Vector((0.0, -0.182, 1.585))
    nose = ears = None

    if t in ("Canid", "Ursine"):
        big = 1.0 if t == "Canid" else 1.35
        v, f = _ellipsoid(rest_tip + Vector((0, -0.008, 0.006)), (0.022 * big, 0.016 * big, 0.015 * big))
        # flatten the underside into a pad with a centre groove
        v = [Vector((p.x, p.y, p.z - 0.004 * math.exp(-(p.x / 0.004) ** 2) * (p.z < rest_tip.z)))
             for p in v]
        nose = _mesh_from(f"TR_Beast_Nose_{t}", v, f, dark)
        if t == "Canid":
            v, f = _mirror(*_ear(Vector((0.092, 0.015, 1.780)), 0.110, 0.130, 0.030, 0.028, 0.030))
        else:  # small round bear ears, set wide on the crown
            v, f = _mirror(*_ear(Vector((0.100, 0.025, 1.790)), 0.075, 0.095, 0.030, 0.022, 0.010, round_tip=True))
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
    elif t in ("Saurian", "Gecko"):
        # two nostril bumps on top of the snout, no external ears
        k = 1.0 if t == "Saurian" else 0.7
        v1, f1 = _ellipsoid(rest_tip + Vector((0.010, 0.000, 0.010)), (0.006 * k, 0.009 * k, 0.004 * k), 10, 6)
        v2, f2 = _ellipsoid(rest_tip + Vector((-0.010, 0.000, 0.010)), (0.006 * k, 0.009 * k, 0.004 * k), 10, 6)
        nose = _mesh_from(f"TR_Beast_Nose_{t}", v1 + v2, f1 + [tuple(i + len(v1) for i in q) for q in f2], dark)
    elif t != "Shark":
        raise KeyError(t)

    if t == "Shark":
        # wide grin under the rostrum, with a row of teeth, and gill slits on the jaw
        m, row = _mouth_line(head, t, f"TR_Beast_Mouth_{t}", 0.105, 1.515, 0.030, 0.006, dark)
        out["mouth"] += [m, _teeth(head, t, f"TR_Beast_Teeth_{t}", row, 0.011, white)]
        v, f = _gill_slits(head, dark)
        out["gills"].append(_mesh_from(f"TR_Beast_Gills_{t}", v, f, dark))
    if t == "Gecko":
        # the big gecko smile wraps round to the cheeks
        m, _row = _mouth_line(head, t, f"TR_Beast_Mouth_{t}", 0.125, 1.528, 0.028, 0.004, dark)
        out["mouth"].append(m)
        # chameleon casque: a crest sheet along the top centre line, riding the flattened crown
        base = [_rest_top(head, y) for y in [-0.10 + 0.25 * i / 12 for i in range(13)]]
        prof = [math.sin(math.pi * min(1.0, i / 12 * 1.15)) for i in range(13)]
        rows = [[(a, Vector((0, 0, -0.004))) for a in base],
                [(a, Vector((0, 0.012 * h, 0.075 * h))) for a, h in zip(base, prof)]]
        out["casque"].append(_keyed_sheet(f"TR_Beast_Casque_{t}", t, rows, furm,
                                          (Vector((0, 0.03, 1.84)), 0.4)))

    if nose:
        _keyed_part(nose, head, t, rest_tip)
        out["nose"].append(nose)
    if ears:
        out["ears"].append(ears)
    for objs in out.values():
        for o in objs:
            _skin_to_head(o, arm)
    return out
