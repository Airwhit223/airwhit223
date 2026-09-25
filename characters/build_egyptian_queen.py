"""Builds a stylized, rigged blockout of the Egyptian queen character.

Run with Blender 5.x:
    blender --background --python characters/build_egyptian_queen.py
or with the bpy pip module (Python 3.13):
    python characters/build_egyptian_queen.py

Body proportions follow the base-body sheet; the outfit (purple top and
split skirt with gold trim and turquoise gems, usekh collar, cobra headband,
bracers, strapped sandals, long black hair with gold streaks) follows the
character art. The skeleton uses Godot's humanoid bone names so Mixamo or
other humanoid animations can be retargeted onto it.

Modeled facing +Y in Blender (+X is her right side); face_plus_z() turns her at export so the .glb faces +Z in Godot.
"""
import math
import os
import sys

import bpy  # must come before bmesh when using the bpy pip module
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pets"))
from build_pets import (  # noqa: E402
    add_capsule, add_ellipsoid, apply_modifiers, join, make_material, paint,
    remesh_and_smooth, reset_scene, srgb,
)
from build_pets import face_plus_z  # noqa: E402

NAME = "egyptian_queen"

SKIN = srgb(0.74, 0.52, 0.36)
SKIN_SHADE = srgb(0.62, 0.41, 0.28)
PURPLE = srgb(0.42, 0.24, 0.6)
PURPLE_DARK = srgb(0.3, 0.16, 0.45)
GOLD = srgb(0.93, 0.74, 0.3)
GOLD_DARK = srgb(0.72, 0.52, 0.18)
TURQUOISE = srgb(0.2, 0.75, 0.72)
HAIR = srgb(0.08, 0.07, 0.09)
HAIR_GOLD = srgb(0.85, 0.66, 0.3)
WHITE = srgb(0.97, 0.96, 0.95)
DARK = srgb(0.07, 0.05, 0.06)
LIPS = srgb(0.62, 0.34, 0.3)
IRIS = srgb(0.16, 0.6, 0.62)


# --------------------------------------------------------------------------
# Joint positions (meters). Mirrored joints are given for her right (+X).
# --------------------------------------------------------------------------

def m(p, sign):
    return Vector((p[0] * sign, p[1], p[2]))


SHOULDER = (0.17, 0.0, 1.33)
ARM_ANGLE = math.radians(47)  # A-pose, like the base-body sheet
UPPER_ARM, FOREARM, HAND = 0.27, 0.24, 0.16


def arm_point(dist):
    return (SHOULDER[0] + dist * math.sin(ARM_ANGLE), 0.0, SHOULDER[2] - dist * math.cos(ARM_ANGLE))


ELBOW = arm_point(UPPER_ARM)
WRIST = arm_point(UPPER_ARM + FOREARM)
FINGERTIP = arm_point(UPPER_ARM + FOREARM + HAND)
HIP = (0.09, 0.0, 0.9)
KNEE = (0.098, 0.012, 0.49)
ANKLE = (0.1, -0.012, 0.085)
TOE = (0.1, 0.12, 0.02)


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------

def add_oriented_ellipsoid(bm, center, axis, radii, flat_axis=Vector((0, 1, 0))):
    """Ellipsoid whose long axis follows `axis` and is thinnest along flat_axis."""
    z = Vector(axis).normalized()
    y = (flat_axis - z * flat_axis.dot(z)).normalized()
    x = y.cross(z)
    rot = Matrix((x, y, z)).transposed().to_4x4()
    mat = Matrix.Translation(center) @ rot @ Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0, matrix=mat)


def new_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def finish(obj, voxel, smooth):
    remesh_and_smooth(obj, voxel=voxel, smooth_repeat=smooth)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()


def decimate(obj, faces):
    if len(obj.data.polygons) > faces:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = faces / len(obj.data.polygons)
        apply_modifiers(obj)


# --------------------------------------------------------------------------
# Body
# --------------------------------------------------------------------------

def build_body():
    bm = bmesh.new()
    add_ellipsoid(bm, (0, 0.0, 1.545), (0.092, 0.1, 0.108))        # skull
    add_ellipsoid(bm, (0, 0.03, 1.49), (0.07, 0.065, 0.05))       # cheeks
    add_ellipsoid(bm, (0, 0.045, 1.46), (0.05, 0.05, 0.045))       # jaw
    add_ellipsoid(bm, (0, 0.07, 1.432), (0.02, 0.025, 0.02))       # chin
    add_capsule(bm, (0, -0.01, 1.34), (0, 0.0, 1.46), 0.046, 0.044)      # neck
    add_ellipsoid(bm, (0, 0.0, 1.235), (0.135, 0.09, 0.13))        # ribcage
    add_ellipsoid(bm, (0, -0.005, 1.31), (0.15, 0.075, 0.05))      # shoulder line
    for s in (1, -1):
        add_ellipsoid(bm, m((0.055, 0.065, 1.205), s), (0.06, 0.055, 0.058))  # bust
        add_ellipsoid(bm, m((0.16, 0.0, 1.325), s), (0.055, 0.05, 0.055))     # deltoid
        add_ellipsoid(bm, m((0.07, -0.045, 0.87), s), (0.075, 0.065, 0.08))    # glutes
    add_ellipsoid(bm, (0, 0.0, 1.07), (0.105, 0.075, 0.11))        # waist
    add_ellipsoid(bm, (0, -0.005, 0.93), (0.162, 0.105, 0.115))    # pelvis

    for s in (1, -1):
        # Arms
        add_capsule(bm, m(SHOULDER, s), m(ELBOW, s), 0.046, 0.036)
        add_capsule(bm, m(ELBOW, s), m(WRIST, s), 0.036, 0.027)
        arm_dir = (m(WRIST, s) - m(ELBOW, s)).normalized()
        palm = m(WRIST, s) + arm_dir * 0.055
        add_oriented_ellipsoid(bm, palm, arm_dir, (0.042, 0.018, 0.058))
        fingers = palm + arm_dir * 0.065
        add_oriented_ellipsoid(bm, fingers, arm_dir, (0.037, 0.012, 0.045))
        thumb_dir = (arm_dir + Vector((0, 0.9, 0))).normalized()
        add_capsule(bm, palm + Vector((0, 0.012, 0.0)) - arm_dir * 0.02,
                    palm + thumb_dir * 0.06, 0.014, 0.01)
        # Legs
        add_capsule(bm, m(HIP, s), m(KNEE, s), 0.088, 0.055)
        add_capsule(bm, m(KNEE, s), m(ANKLE, s), 0.052, 0.032)
        add_ellipsoid(bm, m((0.1, -0.03, 0.34), s), (0.05, 0.05, 0.1))    # calf
        add_ellipsoid(bm, m((0.1, 0.045, 0.035), s), (0.042, 0.105, 0.035))  # foot
        add_ellipsoid(bm, m((0.1, -0.03, 0.05), s), (0.034, 0.045, 0.045))   # heel
    for s in (1, -1):
        add_ellipsoid(bm, m((0.093, 0.0, 1.52), s), (0.012, 0.02, 0.028))   # ears
    add_ellipsoid(bm, (0, 0.1, 1.51), (0.011, 0.014, 0.018))            # nose

    body = new_object(NAME, bm)
    finish(body, voxel=0.006, smooth=6)
    decimate(body, 8000)
    return body


def near_segment(co, a, b, radius):
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (co - a).dot(ab) / ab.length_squared))
    return t, (co - (a + ab * t)).length < radius


def body_color(co, n):
    x, y, z = co
    ax = abs(x)
    s = 1 if x >= 0 else -1

    # Top: purple halter band over the bust with gold trim and a gem.
    if 1.13 < z < 1.29 and ax < 0.15:
        if y > -0.03 or 1.17 < z < 1.22:
            if abs(z - 1.135) < 0.008 or abs(z - 1.285) < 0.008:
                return GOLD
            if y > 0.08 and ((abs(x) / 0.02) + abs(z - 1.175) / 0.028) < 1:
                return TURQUOISE
            if y > 0.05 and abs(ax - 0.055) < 0.004:
                return GOLD
            return PURPLE
    # Belt.
    if 0.925 < z < 0.975 and ax < 0.19:
        if y > 0.09 and abs(x) < 0.02:
            return TURQUOISE
        return GOLD if abs(z - 0.95) < 0.017 else GOLD_DARK

    for arm in (1, -1):
        if s != arm:
            continue
        # Upper-arm band.
        t, hit = near_segment(co, m(SHOULDER, arm), m(ELBOW, arm), 0.07)
        if hit and 0.4 < t < 0.55:
            return TURQUOISE if 0.46 < t < 0.49 else GOLD
        # Bracers from wrist to mid forearm.
        t, hit = near_segment(co, m(ELBOW, arm), m(WRIST, arm), 0.06)
        if hit and t > 0.5:
            return TURQUOISE if 0.68 < t < 0.73 else GOLD
        # Wrist cuff.
        if hit and t > 0.93:
            return GOLD

    return SKIN


# --------------------------------------------------------------------------
# Face details (separate little meshes following the head bone)
# --------------------------------------------------------------------------

def face_point(x, z):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    hit, loc, _, _, _, _ = bpy.context.scene.ray_cast(depsgraph, Vector((x, 2.0, z)), Vector((0, -1, 0)))
    if not hit:
        sys.exit(f"face placement missed at x={x}, z={z}")
    return loc


def blob(name, center, size, color, rot_y=0.0):
    bm = bmesh.new()
    mat = (Matrix.Translation(center) @ Matrix.Rotation(rot_y, 4, "Y")
           @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0, matrix=mat)
    obj = new_object(name, bm)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    paint(obj, lambda co, n: color)
    return obj


def build_face():
    parts = []
    for s in (1, -1):
        c = face_point(0.037 * s, 1.535) + Vector((0, -0.004, 0))
        parts.append(blob("sclera", c, (0.021, 0.006, 0.014), WHITE))
        parts.append(blob("iris", c + Vector((-0.002 * s, 0.003, -0.001)), (0.012, 0.005, 0.0135), IRIS))
        parts.append(blob("pupil", c + Vector((-0.002 * s, 0.006, -0.001)), (0.006, 0.003, 0.008), DARK))
        parts.append(blob("shine", c + Vector((0.002 * s, 0.008, 0.005)), (0.003, 0.002, 0.003), WHITE))
        # Thick upper lash line with an Egyptian kohl wing.
        parts.append(blob("lash", c + Vector((0, 0.004, 0.012)), (0.024, 0.005, 0.0045), DARK))
        parts.append(blob("wing", c + Vector((0.026 * s, -0.006, 0.014)), (0.013, 0.004, 0.0028), DARK,
                          rot_y=-0.35 * s))
        parts.append(blob("lower_lash", c + Vector((0.004 * s, 0.003, -0.013)), (0.017, 0.004, 0.0022), DARK))
        brow = face_point(0.039 * s, 1.562) + Vector((0, 0.001, 0))
        parts.append(blob("brow", brow, (0.022, 0.004, 0.0032), DARK, rot_y=-0.12 * s))
    mouth = face_point(0.0, 1.462)
    parts.append(blob("lips", mouth + Vector((0, -0.002, 0)), (0.017, 0.005, 0.0055), LIPS))
    parts.append(blob("mouth", mouth + Vector((0, 0.0015, 0)), (0.015, 0.003, 0.0013), DARK))
    return parts


# --------------------------------------------------------------------------
# Outfit and hair
# --------------------------------------------------------------------------

SKIRT_GAPS = [(math.radians(55), math.radians(18)), (math.radians(125), math.radians(18))]
SKIRT_TOP, PANEL_HALF, PANEL_BORDER = 0.965, 0.34, 0.05


def skirt_hem(theta):
    return 0.14 + 0.09 * abs(math.sin(theta * 3.0))


def gap_distance(theta, t):
    """Angle past the edge of the nearest slit (negative = inside the slit)."""
    best = math.inf
    for center, half in SKIRT_GAPS:
        d = abs((theta - center + math.pi) % math.tau - math.pi)
        best = min(best, d - half * min(1.0, 0.25 + t * 1.2))
    return best


def build_skirt():
    """Floor-length wrap skirt split on both sides of a front panel."""
    front = math.pi / 2
    bm = bmesh.new()

    def strip(thetas, ts, lift, closed):
        grid = []
        for t in ts:
            row = []
            for theta in thetas:
                z = SKIRT_TOP + (skirt_hem(theta) - SKIRT_TOP) * t
                rx = 0.175 + 0.13 * t ** 1.3 + lift
                ry = 0.14 + 0.13 * t ** 1.3 + lift
                row.append(bm.verts.new((rx * math.cos(theta), ry * math.sin(theta) - 0.005, z)))
            grid.append(row)
        n = len(thetas)
        for i in range(len(ts) - 1):
            for j in range(n if closed else n - 1):
                j2 = (j + 1) % n
                mid = (thetas[j] + ((thetas[j2] - thetas[j]) % math.tau) / 2) % math.tau
                if closed and (gap_distance(mid, (ts[i] + ts[i + 1]) / 2) < 0
                               or abs(mid - front) < PANEL_HALF - 0.01):
                    continue
                bm.faces.new((grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]))

    # Wrap: sparse around the back, denser along the slits.
    thetas = {j / 56 * math.tau for j in range(56)}
    thetas |= {front - PANEL_HALF, front + PANEL_HALF}
    for center, half in SKIRT_GAPS:
        thetas |= {center + half * (k / 6 - 1) * 1.6 for k in range(13)}
    thetas = sorted(t % math.tau for t in thetas)
    strip(thetas, sorted({i / 20 for i in range(21)} | {0.03, 0.955, 0.94}), 0.0, True)
    # Front panel: its own dense strip so the diamond pattern stays crisp.
    panel = [front + PANEL_HALF * (k / 14 - 1) for k in range(29)]
    panel += [front - PANEL_HALF + PANEL_BORDER, front + PANEL_HALF - PANEL_BORDER]
    strip(sorted(panel), sorted({i / 56 for i in range(57)} | {0.03, 0.955, 0.94}), 0.004, False)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    skirt = new_object("skirt", bm)
    sol = skirt.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.008
    apply_modifiers(skirt)
    bpy.ops.object.shade_smooth()

    def color(co, n):
        x, y, z = co
        theta = math.atan2(y + 0.005, x) % math.tau
        hem = skirt_hem(theta)
        front = math.pi / 2
        t = (SKIRT_TOP - z) / (SKIRT_TOP - hem)
        if t > 0.945 or t < 0.035:
            return GOLD
        if gap_distance(theta, t) < 0.06:  # gold edge along each slit
            return GOLD
        d = theta - front
        if abs(d) < PANEL_HALF:  # front panel
            if abs(d) > PANEL_HALF - PANEL_BORDER:
                return GOLD
            u = abs(d) / (PANEL_HALF - PANEL_BORDER)
            phase = (t * 6.0) % 1.0
            if u / 0.5 + abs(phase - 0.5) / 0.32 < 1:
                return TURQUOISE
            if u / 0.62 + abs(phase - 0.5) / 0.42 < 1:
                return GOLD
            return PURPLE
        return PURPLE_DARK if y < -0.05 else PURPLE
    paint(skirt, color)
    return skirt


def build_sandals():
    """Crossed gold straps wound up each calf, toe straps and soles."""
    objs = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for s in (1, -1):
        axis = Vector((0.1 * s, -0.012, 0.0))
        for turn in (1, -1):
            points = []
            for k in range(81):
                t = k / 80
                z = 0.075 + t * 0.215
                a = turn * t * 2.3 * math.tau + (0.0 if turn > 0 else math.pi)
                d = Vector((math.cos(a), math.sin(a), 0.0))
                origin = Vector((axis.x, axis.y, z)) + d * 0.075
                hit, loc, *_ = bpy.context.scene.ray_cast(depsgraph, origin, -d)
                if hit:
                    points.append(loc + d * 0.002)
            objs.append(tube("strap", points, 0.0045))
        # Toe strap arching over the front of the foot.
        toe = []
        for k in range(21):
            a = math.pi * (0.12 + 0.76 * k / 20)
            d = Vector((math.cos(a), 0.0, math.sin(a)))
            origin = Vector((0.1 * s, 0.1, 0.0)) + d * 0.075
            hit, loc, *_ = bpy.context.scene.ray_cast(depsgraph, origin, -d)
            if hit:
                toe.append(loc + d * 0.002)
        objs.append(tube("toe_strap", toe, 0.0055))
    for s in (1, -1):  # after the straps, so rays never hit the other sole
        objs.append(blob("sole", Vector((0.1 * s, 0.045, 0.004)), (0.047, 0.118, 0.007), GOLD_DARK))
    for o in objs:
        if o.name.startswith(("strap", "toe_strap")):
            paint(o, lambda co, n: GOLD)
    return objs


def tube(name, points, radius):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, pt in zip(spline.points, points):
        p.co = (pt.x, pt.y, pt.z, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.shade_smooth()
    return bpy.context.view_layer.objects.active


def build_collar():
    """Usekh broad collar: a sloped ring of gold and turquoise bands."""
    bm = bmesh.new()
    segs, rings = 64, 6
    grid = []
    for i in range(rings + 1):
        t = i / rings
        row = []
        for j in range(segs):
            theta = j / segs * math.tau
            r_x = 0.058 + 0.105 * t
            r_y = 0.052 + 0.075 * t
            front = max(0.0, math.sin(theta))
            z = 1.395 - 0.07 * t - 0.035 * t * front
            row.append(bm.verts.new((r_x * math.cos(theta), r_y * math.sin(theta) - 0.004, z)))
        grid.append(row)
    for i in range(rings):
        for j in range(segs):
            j2 = (j + 1) % segs
            bm.faces.new((grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]))
    collar = new_object("collar", bm)
    sol = collar.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.01
    apply_modifiers(collar)
    bpy.ops.object.shade_smooth()

    def color(co, n):
        r = math.hypot(co.x / 1.15, co.y + 0.004)
        band = int((r - 0.05) / 0.017)
        return TURQUOISE if band in (2, 4) else GOLD if band % 2 == 0 else GOLD_DARK
    paint(collar, color)
    return collar


def build_hair():
    bm = bmesh.new()
    add_ellipsoid(bm, (0, -0.025, 1.575), (0.108, 0.112, 0.11))    # crown
    add_ellipsoid(bm, (0, 0.035, 1.62), (0.085, 0.065, 0.05))      # bangs swept back
    # Long wavy mass down the back to the waist.
    for k in range(8):
        z = 1.5 - k * 0.075
        w = 0.13 + 0.05 * math.sin(k * 0.9) + k * 0.008
        add_ellipsoid(bm, (0, -0.085 - k * 0.006, z), (w, 0.065, 0.07))
        for s in (1, -1):
            wave = 0.02 * math.sin(k * 1.7 + (0.5 if s > 0 else 0))
            add_ellipsoid(bm, (s * (w * 0.75 + wave), -0.07 - k * 0.004, z - 0.02), (0.05, 0.05, 0.06))
    # Side locks framing the face, falling in front of the shoulders.
    for s in (1, -1):
        for k in range(7):
            z = 1.53 - k * 0.055
            x = 0.1 + k * 0.012 + 0.012 * math.sin(k * 1.9)
            y = 0.0 + 0.004 * k
            add_ellipsoid(bm, (s * x, y, z), (0.042, 0.04, 0.045))
    hair = new_object("hair", bm)
    finish(hair, voxel=0.008, smooth=10)
    decimate(hair, 3000)

    def color(co, n):
        x, y, z = co
        ax = abs(x)
        # Gold streaks: through the side locks and a few in the back.
        if ax > 0.085 and y > -0.05 and math.sin(z * 22.0 + ax * 60.0) > 0.82:
            return HAIR_GOLD
        return HAIR
    paint(hair, color)
    return hair


def build_headpiece():
    bm = bmesh.new()
    # Headband: a ring around the crown tilted down at the front.
    ring = Matrix.Translation((0, -0.02, 1.612)) @ Matrix.Rotation(math.radians(-16), 4, "X")
    segs = 48
    for j in range(segs):
        theta = j / segs * math.tau
        p = ring @ Vector((0.103 * math.cos(theta), 0.114 * math.sin(theta), 0.0))
        add_ellipsoid(bm, p, (0.011, 0.011, 0.013))
    # Cobra (uraeus) rising from the front of the band.
    add_capsule(bm, (0, 0.09, 1.63), (0, 0.098, 1.685), 0.011, 0.009)
    add_ellipsoid(bm, (0, 0.099, 1.678), (0.022, 0.008, 0.026))
    add_ellipsoid(bm, (0, 0.106, 1.708), (0.009, 0.012, 0.008))
    # Earrings.
    for s in (1, -1):
        add_ellipsoid(bm, (s * 0.098, 0.004, 1.49), (0.006, 0.006, 0.008))
        add_ellipsoid(bm, (s * 0.1, 0.004, 1.455), (0.009, 0.004, 0.017))
    piece = new_object("headpiece", bm)
    finish(piece, voxel=0.004, smooth=2)
    decimate(piece, 1500)

    def color(co, n):
        x, y, z = co
        if z < 1.47 and abs(x) > 0.08:
            return TURQUOISE
        if y > 0.104 and z > 1.703 and abs(x) > 0.003:
            return DARK  # cobra eyes
        return GOLD
    paint(piece, color)
    return piece


# --------------------------------------------------------------------------
# Rig (Godot SkeletonProfileHumanoid bone names)
# --------------------------------------------------------------------------

def humanoid_bones():
    bones = [
        ("Hips", None, (0, 0, 0.92), (0, 0, 1.0)),
        ("Spine", "Hips", (0, 0, 1.0), (0, 0, 1.1)),
        ("Chest", "Spine", (0, 0, 1.1), (0, 0, 1.22)),
        ("UpperChest", "Chest", (0, 0, 1.22), (0, 0, 1.34)),
        ("Neck", "UpperChest", (0, 0, 1.34), (0, 0.005, 1.45)),
        ("Head", "Neck", (0, 0.005, 1.45), (0, 0.005, 1.68)),
    ]
    for side, s in (("Right", 1), ("Left", -1)):
        bones += [
            (side + "Shoulder", "UpperChest", m((0.03, 0, 1.32), s), m(SHOULDER, s)),
            (side + "UpperArm", side + "Shoulder", m(SHOULDER, s), m(ELBOW, s)),
            (side + "LowerArm", side + "UpperArm", m(ELBOW, s), m(WRIST, s)),
            (side + "Hand", side + "LowerArm", m(WRIST, s), m(arm_point(UPPER_ARM + FOREARM + 0.09), s)),
            (side + "UpperLeg", "Hips", m(HIP, s), m(KNEE, s)),
            (side + "LowerLeg", side + "UpperLeg", m(KNEE, s), m(ANKLE, s)),
            (side + "Foot", side + "LowerLeg", m(ANKLE, s), m((0.1, 0.08, 0.02), s)),
            (side + "Toes", side + "Foot", m((0.1, 0.08, 0.02), s), m(TOE, s)),
        ]
    return bones


def build_rig():
    arm_data = bpy.data.armatures.new(NAME + "_rig")
    rig = bpy.data.objects.new(NAME + "_rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, parent, head, tail in humanoid_bones():
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = Vector(head), Vector(tail)
        if parent:
            eb.parent = made[parent]
            eb.use_connect = (made[parent].tail - eb.head).length < 1e-5
        made[name] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def set_weights(obj, fn):
    """Assigns weights from fn(co) -> {bone: weight}."""
    groups = {}
    for v in obj.data.vertices:
        for bone, w in fn(v.co).items():
            if w <= 0:
                continue
            if bone not in groups:
                groups[bone] = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")


def skirt_weights(co):
    # Blend from the hips to each thigh as the skirt goes down, with the
    # front and back panels staying centered.
    x, y, z = co
    down = max(0.0, min(1.0, (0.95 - z) / 0.55))
    side = max(0.0, min(1.0, abs(x) / 0.12))
    leg = down * side * 0.8
    bone = "RightUpperLeg" if x > 0 else "LeftUpperLeg"
    return {"Hips": 1.0 - leg, bone: leg}


def hair_weights(co):
    z = co.z
    if z > 1.45:
        return {"Head": 1.0}
    if z > 1.3:
        t = (1.45 - z) / 0.15
        return {"Head": 1.0 - t, "UpperChest": t}
    return {"UpperChest": 0.6, "Chest": 0.4}


def sandal_weights(co):
    side = "Right" if co.x > 0 else "Left"
    if co.z > 0.12:
        return {side + "LowerLeg": 1.0}
    t = max(0.0, (co.z - 0.06) / 0.06)
    return {side + "LowerLeg": t, side + "Foot": 1.0 - t}


def bind(body, rig, rigid):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    for obj, fn in rigid:
        set_weights(obj, fn)
    join([obj for obj, _ in rigid], body)
    body.data.validate()


def main():
    reset_scene()
    body = build_body()
    paint(body, body_color)
    face = build_face()
    sandals = build_sandals()
    skirt = build_skirt()
    collar = build_collar()
    hair = build_hair()
    headpiece = build_headpiece()

    rig = build_rig()
    head_only = lambda co: {"Head": 1.0}  # noqa: E731
    collar_w = lambda co: {"UpperChest": 0.7, "Neck": 0.3}  # noqa: E731
    bind(body, rig, [(p, head_only) for p in face]
         + [(p, sandal_weights) for p in sandals]
         + [(headpiece, head_only), (hair, hair_weights), (skirt, skirt_weights), (collar, collar_w)])
    body.data.materials.append(make_material(NAME))

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, NAME + ".blend"))
    face_plus_z()
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(HERE, NAME + ".glb"),
        export_format="GLB",
        export_vertex_color="MATERIAL",
    )
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"{NAME}: {tris} triangles, {len(rig.data.bones)} bones")


if __name__ == "__main__":
    main()
