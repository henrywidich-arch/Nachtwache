# Builds the M32 multiple grenade launcher for Nachtwache from nothing: the geometry and
# the game-ready GLB (nodes M32 > Body / Drum / Front, and Round0 ... Round5 in the drum)
# with one plain PBR material per surface type, like the other weapons the scripts make.
# The fine surface grain is added by the game's own materials, so no textures are baked.
#
# Proportions follow the Milkor M32 and the first-person model of Combat Arms (the places
# of its moving parts in PV_LCH_M32_SH.LTB): a six-shot revolving drum between a rear
# frame with pistol grip and telescoping stock and a front frame that carries the barrel,
# a rail collar with a vertical foregrip, a long top rail with a big reflex sight.
#
# Run (a few seconds), from the project folder:
#   blender --background --factory-startup --python tools/blender_make_m32.py -- [--out <m32.glb>]
# or, with the bpy module installed:  python tools/blender_make_m32.py -- [--out <m32.glb>]
#
# Modelling space below: x = right, y = forward (muzzle), z = up, metres, bore axis at z = 0
# and y = 0 at the rear face of the drum. Everything is shifted at the end so the origin is
# the middle of the pistol grip. The glTF exporter turns this into Godot space: barrel
# along -Z, up +Y.
#
# Moving parts, each a node of its own with its origin on its axis:
#   Drum   turns about the drum axis (Godot: its local Z), 60 degrees per shot.
#   Front  the front frame with barrel, rail collar and foregrip. It swings out to the
#          right about a hinge along the lower right edge of the frame (Godot: local Z),
#          which opens the front of the drum for loading.
#   RoundN the grenade in chamber N (N = 0 at the top, counting clockwise as seen from
#          behind), so that the game can show which chambers are loaded.
import bpy, bmesh, sys, os, math
from math import sin, cos, pi, radians
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
OUT_GLB = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "m32.glb")))

# ----------------------------------------------------------------------------- dimensions
DRUM_Z = -0.050             # drum axis below the bore
CHAMBER_R = 0.050           # chamber circle radius (the top chamber lines up with the bore)
TUBE_R = 0.0245             # chamber tube, outside
BORE_R = 0.0205             # 40 mm
DRUM_L = 0.132              # rear face to front face of the drum
FRAME_W = 0.035             # half width of the rear and front frame
TOP = 0.034                 # top of the top strap
RAIL_TOP = 0.046
BOTTOM = -0.138             # underside of the bottom strap
FRONT_Y0, FRONT_Y1 = 0.136, 0.164
MUZZLE_Y = 0.462
HINGE = Vector((0.030, 0.150, -0.130))       # the front frame swings about this line (along y)
ORIGIN = Vector((0.0, -0.064, -0.182))       # middle of the pistol grip


def srgb(r, g, b):
    return tuple(((c / 255.0 + 0.055) / 1.055) ** 2.4 if c / 255.0 > 0.04045 else c / 255.0 / 12.92 for c in (r, g, b))


MATS = {
    "steel":   dict(col=srgb(46, 48, 52), metal=1.00, rough=0.50),
    "alu":     dict(col=srgb(62, 64, 69), metal=1.00, rough=0.44),
    "inside":  dict(col=srgb(24, 24, 26), metal=0.60, rough=0.62),
    "polymer": dict(col=srgb(36, 37, 39), metal=0.00, rough=0.66),
    "grip":    dict(col=srgb(30, 31, 33), metal=0.00, rough=0.80),
    "rubber":  dict(col=srgb(22, 22, 23), metal=0.00, rough=0.90),
    "bright":  dict(col=srgb(150, 152, 157), metal=1.00, rough=0.32),
    "glass":   dict(col=srgb(18, 36, 44), metal=0.00, rough=0.06),
    "red":     dict(col=srgb(200, 26, 20), metal=0.00, rough=0.45),
    "void":    dict(col=srgb(10, 10, 11), metal=0.00, rough=0.90),
    "olive":   dict(col=srgb(78, 86, 58), metal=0.20, rough=0.55),
    "brass":   dict(col=srgb(212, 168, 86), metal=1.00, rough=0.30),
    "gold":    dict(col=srgb(216, 178, 74), metal=0.90, rough=0.35),
}


# ----------------------------------------------------------------------------- 2D helpers
def rrect(cx, cy, hw, hh, r, n=4):
    """Rounded rectangle, counter-clockwise."""
    pts = []
    for (sx, sy, a0) in ((1, 1, 0.0), (-1, 1, 90.0), (-1, -1, 180.0), (1, -1, 270.0)):
        ox, oy = cx + sx * (hw - r), cy + sy * (hh - r)
        for i in range(n + 1):
            a = radians(a0 + 90.0 * i / n)
            pts.append((ox + r * cos(a), oy + r * sin(a)))
    return pts


def fillet(pts, r, n=3):
    """Rounds every corner of a closed polygon (counter-clockwise) by about r."""
    out = []
    k = len(pts)
    for i in range(k):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % k])
        a, b = (p0 - p1), (p2 - p1)
        rr = min(r, a.length * 0.45, b.length * 0.45)
        a.normalize()
        b.normalize()
        s, e = p1 + a * rr, p1 + b * rr
        for j in range(n + 1):
            t = j / n
            q = s * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + e * t * t
            out.append((q.x, q.y))
    return out


def circle(cx, cy, r, n=24, phase=0.0):
    return [(cx + r * cos(phase + 2 * pi * i / n), cy + r * sin(phase + 2 * pi * i / n)) for i in range(n)]


# ----------------------------------------------------------------------------- mesh helpers
def _to3(axis, u, v, t):
    if axis == "x":    # profile in (y, z)
        return Vector((t, u, v))
    if axis == "y":    # profile in (x, z)
        return Vector((u, t, v))
    return Vector((u, v, t))  # "z": profile in (x, y)


def prism(pts, lo, hi, axis="x"):
    """Extrudes a closed 2D outline between lo and hi along an axis."""
    bm = bmesh.new()
    a = [bm.verts.new(_to3(axis, u, v, lo)) for (u, v) in pts]
    b = [bm.verts.new(_to3(axis, u, v, hi)) for (u, v) in pts]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(x0, x1, y0, y1, z0, z1):
    return prism([(y0, z0), (y1, z0), (y1, z1), (y0, z1)], x0, x1, "x")


def lathe(profile, seg=28, c=(0.0, 0.0), axis="y", phase=0.0):
    """Turns a profile [(radius, along)] about an axis through c. Radius 0 closes a cap."""
    bm = bmesh.new()
    rings = []
    for (r, t) in profile:
        ring = []
        if r <= 1e-6:
            ring = [bm.verts.new(_axis_point(axis, c, 0.0, 0.0, t))]
        else:
            for i in range(seg):
                a = phase + 2 * pi * i / seg
                ring.append(bm.verts.new(_axis_point(axis, c, r * cos(a), r * sin(a), t)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        if len(r0) == 1 and len(r1) == 1:
            continue
        if len(r0) == 1:
            for i in range(seg):
                bm.faces.new((r0[0], r1[i], r1[(i + 1) % seg]))
        elif len(r1) == 1:
            for i in range(seg):
                bm.faces.new((r0[i], r0[(i + 1) % seg], r1[0]))
        else:
            for i in range(seg):
                j = (i + 1) % seg
                bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    if len(rings[0]) > 1:
        bm.faces.new(rings[0])
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _axis_point(axis, c, u, v, t):
    if axis == "y":
        return Vector((c[0] + u, t, c[1] + v))
    if axis == "z":
        return Vector((c[0] + u, c[1] + v, t))
    return Vector((t, c[0] + u, c[1] + v))


def tube(c, r_out, r_in, y0, y1, seg=28):
    """A pipe along y: outer and inner wall and the two rims."""
    return lathe([(r_in, y0), (r_out, y0), (r_out, y1), (r_in, y1), (r_in, y0 + 0.0005)], seg, c)


def plate_with_holes(outline, holes, y0, y1):
    """A plate in the x-z plane between y0 and y1 with round holes through it."""
    bm = prism(outline, y0, y1, "y")
    for (hx, hz, hr) in holes:
        cutter = lathe([(0.0, y0 - 0.01), (hr, y0 - 0.01), (hr, y1 + 0.01), (0.0, y1 + 0.01)], 24, (hx, hz))
        bm = boolean(bm, cutter)
    return bm


def boolean(bm, cutter, op="DIFFERENCE"):
    me_a = bpy.data.meshes.new("a")
    bm.to_mesh(me_a)
    ob_a = bpy.data.objects.new("a", me_a)
    me_b = bpy.data.meshes.new("b")
    cutter.to_mesh(me_b)
    ob_b = bpy.data.objects.new("b", me_b)
    bpy.context.scene.collection.objects.link(ob_a)
    bpy.context.scene.collection.objects.link(ob_b)
    mod = ob_a.modifiers.new("cut", "BOOLEAN")
    mod.operation = op
    mod.object = ob_b
    mod.solver = "EXACT"
    deps = bpy.context.evaluated_depsgraph_get()
    result = bmesh.new()
    result.from_mesh(ob_a.evaluated_get(deps).to_mesh())
    for ob in (ob_a, ob_b):
        me = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)
    return result


# ----------------------------------------------------------------------------- parts
PARTS = {}      # node -> list of (bmesh, material)


def add(node, bm, mat, bevel=0.0, angle=30.0):
    if bevel > 0.0:
        edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > radians(angle)]
        if edges:
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=2, profile=0.5,
                            affect="EDGES", clamp_overlap=True)
    PARTS.setdefault(node, []).append((bm, mat))


def build_body():
    # Rear frame: the housing of the lock behind the drum, seen from the side.
    rear = fillet([(-0.074, -0.020), (-0.060, -0.112), (-0.030, -0.128), (-0.004, -0.128), (-0.004, TOP),
                   (-0.068, TOP), (-0.074, 0.018)], 0.008)
    add("Body", prism(rear, -FRAME_W, FRAME_W, "x"), "steel", bevel=0.0012)
    # Raised cover plates on both sides and the screws that hold them.
    for side in (-1, 1):
        x0, x1 = (FRAME_W, FRAME_W + 0.0025) if side > 0 else (-FRAME_W - 0.0025, -FRAME_W)
        add("Body", prism(fillet([(-0.064, -0.100), (-0.012, -0.100), (-0.012, 0.022), (-0.060, 0.022)], 0.006), x0, x1, "x"), "alu", bevel=0.0007)
        for (y, z) in ((-0.054, 0.010), (-0.020, 0.010), (-0.054, -0.088), (-0.020, -0.088), (-0.037, -0.040)):
            sx = x1 if side > 0 else x0
            add("Body", _screw(sx, y, z, side), "bright")
    # Safety lever on the left, the drum release button on the right.
    add("Body", prism(fillet([(-0.046, -0.058), (-0.020, -0.050), (-0.020, -0.043), (-0.046, -0.049)], 0.003), -FRAME_W - 0.005, -FRAME_W - 0.0025, "x"), "steel", bevel=0.0005)
    add("Body", _screw(-FRAME_W - 0.005, -0.046, -0.053, -1, 0.006, 0.003), "steel")
    add("Body", _screw(FRAME_W + 0.0025, -0.010, -0.050, 1, 0.0075, 0.004), "red")
    # Top strap over the drum, and its rail.
    add("Body", box(-0.022, 0.022, -0.072, FRONT_Y1, TOP - 0.010, TOP), "steel", bevel=0.0012)
    add("Body", box(-0.0105, 0.0105, -0.066, FRONT_Y1 - 0.004, TOP, RAIL_TOP - 0.004), "alu", bevel=0.0006)
    y = -0.064
    while y < FRONT_Y1 - 0.010:
        tooth = [(-0.0105, RAIL_TOP - 0.004), (0.0105, RAIL_TOP - 0.004), (0.0080, RAIL_TOP), (-0.0080, RAIL_TOP)]
        add("Body", prism(tooth, y, y + 0.0052, "y"), "alu", bevel=0.0003)
        y += 0.0100
    # Bottom strap under the drum, from the rear frame to the hinge.
    add("Body", box(-0.020, 0.020, -0.010, FRONT_Y0 - 0.002, BOTTOM, -0.124), "steel", bevel=0.0010)
    # Drum axis behind the drum (the front end turns with the drum).
    add("Body", lathe([(0.0, -0.006), (0.010, -0.006), (0.010, 0.004), (0.0, 0.004)], 20, (0.0, DRUM_Z)), "bright")
    # Trigger housing under the rear frame, trigger and guard.
    add("Body", prism(fillet([(-0.040, -0.128), (0.026, -0.128), (0.034, -0.140), (-0.040, -0.140)], 0.004), -0.013, 0.013, "x"), "steel", bevel=0.0008)
    guard = []
    for i in range(13):
        a = radians(180 + 180 * i / 12)
        guard.append((0.005 + 0.036 * cos(a), -0.140 + 0.024 * sin(a)))
    add("Body", _bar_path(guard + [(0.041, -0.140)], 0.0045, 0.006), "steel")
    add("Body", prism(fillet([(-0.006, -0.140), (0.002, -0.140), (0.006, -0.156), (0.002, -0.162), (-0.002, -0.150)], 0.002), -0.0028, 0.0028, "x"), "bright")
    # Pistol grip: an A2 style grip raked back, with a finger swell and a flat base.
    grip = fillet([(-0.060, -0.128), (-0.022, -0.128), (-0.030, -0.150), (-0.035, -0.166), (-0.040, -0.180),
                   (-0.052, -0.236), (-0.088, -0.236), (-0.082, -0.200), (-0.070, -0.150)], 0.009, 4)
    add("Body", prism(grip, -0.0155, 0.0155, "x"), "grip", bevel=0.004, angle=20.0)
    # Stock: buffer tube, the telescoping stock on it, its cheek rest and butt pad.
    add("Body", lathe([(0.0, -0.330), (0.0160, -0.330), (0.0160, -0.072), (0.0, -0.072)], 24, (0.0, -0.010)), "steel")
    add("Body", lathe([(0.0, -0.080), (0.0205, -0.080), (0.0205, -0.070), (0.0, -0.070)], 24, (0.0, -0.010)), "steel")
    stock = fillet([(-0.352, -0.082), (-0.250, -0.050), (-0.226, -0.034), (-0.226, 0.016), (-0.352, 0.026)], 0.010, 4)
    add("Body", prism(stock, -0.0215, 0.0215, "x"), "polymer", bevel=0.003, angle=20.0)
    add("Body", prism(fillet([(-0.352, -0.010), (-0.262, -0.002), (-0.262, 0.026), (-0.352, 0.032)], 0.006), -0.024, 0.024, "x"), "polymer", bevel=0.003, angle=20.0)
    add("Body", prism(fillet([(-0.366, -0.094), (-0.352, -0.094), (-0.352, 0.034), (-0.366, 0.034)], 0.005), -0.024, 0.024, "x"), "rubber", bevel=0.003, angle=20.0)
    add("Body", box(-0.0045, 0.0045, -0.300, -0.236, -0.064, -0.050), "steel", bevel=0.0008)
    # Reflex sight: a clamp on the rail, a square hood with a slanted lens and a knob.
    sy0, sy1 = -0.010, 0.064
    add("Body", box(-0.017, 0.017, sy0 + 0.006, sy1 - 0.008, RAIL_TOP, RAIL_TOP + 0.010), "steel", bevel=0.0010)
    add("Body", box(0.017, 0.024, sy0 + 0.016, sy0 + 0.034, RAIL_TOP - 0.008, RAIL_TOP + 0.008), "steel", bevel=0.0008)
    add("Body", _screw(0.024, sy0 + 0.025, RAIL_TOP, 1, 0.006, 0.004), "bright")
    hood_out = rrect(0.0, RAIL_TOP + 0.042, 0.023, 0.032, 0.008)
    hood_in = rrect(0.0, RAIL_TOP + 0.044, 0.018, 0.026, 0.005)
    hood = prism(hood_out, sy0, sy1, "y")
    hood = boolean(hood, prism(hood_in, sy0 - 0.01, sy1 + 0.01, "y"))
    add("Body", hood, "steel", bevel=0.0010)
    lens = prism(rrect(0.0, RAIL_TOP + 0.044, 0.0182, 0.0262, 0.005), 0.0, 0.002, "y")
    bmesh.ops.rotate(lens, verts=lens.verts, cent=Vector((0.0, 0.001, RAIL_TOP + 0.044)), matrix=Matrix.Rotation(radians(-14), 3, "X"))
    bmesh.ops.translate(lens, verts=lens.verts, vec=Vector((0.0, sy1 - 0.014, 0.0)))
    add("Body", lens, "glass")
    add("Body", lathe([(0.0, 0.023), (0.0085, 0.023), (0.0085, 0.031), (0.0, 0.031)], 16, (sy0 + 0.040, RAIL_TOP + 0.050), axis="x"), "steel")
    add("Body", lathe([(0.0, 0.031), (0.0075, 0.031), (0.0075, 0.033), (0.0, 0.033)], 16, (sy0 + 0.040, RAIL_TOP + 0.050), axis="x"), "bright")


def _screw(x, y, z, side, r=0.0042, h=0.0018):
    t0, t1 = (x, x + h) if side > 0 else (x - h, x)
    return lathe([(0.0, t0), (r, t0), (r, t1), (0.0, t1)], 12, (y, z), axis="x")


def _bar_path(pts, half_x, half_t):
    """A flat bar along a path in the y-z plane (trigger guard)."""
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        p = Vector(p)
        a = Vector(pts[max(0, i - 1)])
        b = Vector(pts[min(len(pts) - 1, i + 1)])
        d = (b - a).normalized()
        n = Vector((-d.y, d.x)) * half_t * 0.5
        ring = [bm.verts.new((sx * half_x, p.x + sn * n.x, p.y + sn * n.y)) for (sx, sn) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def chambers():
    return [(CHAMBER_R * cos(radians(90 - 60 * i)), DRUM_Z + CHAMBER_R * sin(radians(90 - 60 * i))) for i in range(6)]


def build_drum():
    # Six chamber tubes round a fluted core, between a rear and a front plate.
    holes = [(x, z, BORE_R) for (x, z) in chambers()]
    core = lathe([(0.0, 0.010), (0.046, 0.010), (0.046, DRUM_L - 0.010), (0.0, DRUM_L - 0.010)], 36, (0.0, DRUM_Z))
    for (x, z) in chambers():
        core = boolean(core, lathe([(0.0, 0.0), (TUBE_R - 0.0006, 0.0), (TUBE_R - 0.0006, DRUM_L), (0.0, DRUM_L)], 24, (x, z)))
    add("Drum", core, "inside")
    for (x, z) in chambers():
        add("Drum", tube((x, z), TUBE_R, BORE_R, 0.010, DRUM_L - 0.010), "steel")
    disc = circle(0.0, DRUM_Z, 0.0735, 48)
    add("Drum", plate_with_holes(disc, holes, 0.0, 0.010), "steel", bevel=0.0012)
    add("Drum", plate_with_holes(disc, holes, DRUM_L - 0.010, DRUM_L), "steel", bevel=0.0012)
    # A band round the middle, as on the real drum, and the hub with its spring cap.
    for (x, z) in chambers():
        add("Drum", tube((x, z), TUBE_R + 0.0018, TUBE_R - 0.001, 0.060, 0.072), "alu")
    add("Drum", lathe([(0.0, DRUM_L), (0.016, DRUM_L), (0.016, DRUM_L + 0.004), (0.010, DRUM_L + 0.004), (0.010, FRONT_Y0), (0.0, FRONT_Y0)], 24, (0.0, DRUM_Z)), "bright")
    add("Drum", lathe([(0.0, -0.001), (0.022, -0.001), (0.022, 0.0), (0.0, 0.0)], 24, (0.0, DRUM_Z)), "bright")


def round_bm(x, z):
    """A 40 mm grenade sitting in its chamber, nose to the front."""
    y0, y1 = 0.018, DRUM_L - 0.003
    return lathe([(0.0, y0), (0.0195, y0), (0.0195, y1 - 0.030), (0.0190, y1 - 0.022), (0.0150, y1 - 0.010),
                  (0.0090, y1 - 0.003), (0.0, y1)], 20, (x, z))


def build_rounds():
    for i, (x, z) in enumerate(chambers()):
        add("Round%d" % i, round_bm(x, z), "olive")
        add("Round%d" % i, tube((x, z), 0.0197, 0.0170, DRUM_L - 0.040, DRUM_L - 0.032, 20), "gold")


def build_front():
    # The front frame: a plate over the face of the drum with the barrel through it.
    outline = fillet([(-FRAME_W, -0.130), (FRAME_W, -0.130), (FRAME_W, TOP), (-FRAME_W, TOP)], 0.012)
    plate = plate_with_holes(outline, [(0.0, 0.0, BORE_R)], FRONT_Y0, FRONT_Y1)
    add("Front", plate, "steel", bevel=0.0012)
    # Hinge knuckle on the lower right and the latch on the upper left.
    add("Front", lathe([(0.0, FRONT_Y0 - 0.010), (0.0075, FRONT_Y0 - 0.010), (0.0075, FRONT_Y1), (0.0, FRONT_Y1)], 16, (HINGE.x, HINGE.z)), "bright")
    add("Front", box(-FRAME_W - 0.003, -FRAME_W + 0.006, FRONT_Y0 - 0.012, FRONT_Y0 + 0.010, 0.006, 0.024), "steel", bevel=0.0008)
    # Barrel: thick where it sits in the frame, then slim to a plain crown.
    add("Front", lathe([(BORE_R, FRONT_Y1 - 0.002), (0.0300, FRONT_Y1 - 0.002), (0.0300, 0.206), (0.0262, 0.214),
                        (0.0262, MUZZLE_Y - 0.016), (0.0285, MUZZLE_Y - 0.012), (0.0285, MUZZLE_Y), (BORE_R, MUZZLE_Y),
                        (BORE_R, FRONT_Y1 - 0.0015)], 32), "steel")
    add("Front", lathe([(0.0, MUZZLE_Y - 0.05), (BORE_R + 0.0002, MUZZLE_Y - 0.05), (BORE_R + 0.0002, MUZZLE_Y - 0.0005), (0.0, MUZZLE_Y - 0.0005)], 32), "void")
    for y in (MUZZLE_Y - 0.090, MUZZLE_Y - 0.074, MUZZLE_Y - 0.058):
        add("Front", lathe([(0.0262, y), (0.0275, y), (0.0275, y + 0.006), (0.0262, y + 0.006)], 32), "steel")
    # Rail collar round the barrel behind the foregrip, rails at top, sides and bottom.
    cy0, cy1 = FRONT_Y1, 0.318
    collar = prism(rrect(0.0, -0.002, 0.032, 0.034, 0.009), cy0, cy1, "y")
    collar = boolean(collar, lathe([(0.0, cy0 - 0.01), (0.0265, cy0 - 0.01), (0.0265, cy1 + 0.01), (0.0, cy1 + 0.01)], 32))
    add("Front", collar, "alu", bevel=0.0012)
    for (ax, az, rot) in ((0.0, 0.032, 0), (0.030, -0.002, 1), (-0.030, -0.002, 1), (0.0, -0.036, 2)):
        y = cy0 + 0.010
        while y < cy1 - 0.012:
            if rot == 0:
                t = prism([(-0.0095, az), (0.0095, az), (0.0072, az + 0.0045), (-0.0072, az + 0.0045)], y, y + 0.0052, "y")
            elif rot == 2:
                t = prism([(-0.0072, az - 0.0045), (0.0072, az - 0.0045), (0.0095, az), (-0.0095, az)], y, y + 0.0052, "y")
            else:
                s = 1 if ax > 0 else -1
                t = prism([(ax, -0.0095 + az), (ax + s * 0.0045, -0.0072 + az), (ax + s * 0.0045, 0.0072 + az), (ax, 0.0095 + az)][::s], y, y + 0.0052, "y")
            add("Front", t, "alu", bevel=0.0003)
            y += 0.0100
    # Vertical foregrip under the collar.
    gy = 0.258
    add("Front", box(-0.012, 0.012, gy - 0.022, gy + 0.022, -0.048, -0.040), "polymer", bevel=0.002)
    add("Front", lathe([(0.0, -0.048), (0.0170, -0.048), (0.0172, -0.090), (0.0160, -0.150), (0.0140, -0.158), (0.0, -0.160)], 24, (0.0, gy), axis="z"), "polymer")
    for z in (-0.080, -0.096, -0.112, -0.128):
        add("Front", lathe([(0.0, z), (0.0178, z), (0.0178, z + 0.008), (0.0, z + 0.008)], 24, (0.0, gy), axis="z"), "rubber")


# ----------------------------------------------------------------------------- objects
def node_object(name, parts, pivot, parent=None):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mat_names = list(MATS.keys())
    for (part, mat) in parts:
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        for p in tmp.polygons:
            p.material_index = mat_names.index(mat)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        part.free()
    bmesh.ops.translate(bm, verts=bm.verts, vec=-pivot)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00001)
    bm.to_mesh(me)
    bm.free()
    for key in mat_names:
        me.materials.append(MATERIALS[key])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = pivot
    if parent is not None:
        ob.parent = parent
        ob.location = pivot - parent_pivot(parent)
    for poly in me.polygons:
        poly.use_smooth = True
    me.set_sharp_from_angle(angle=radians(40))
    return ob


PIVOTS = {}


def parent_pivot(ob):
    return PIVOTS.get(ob.name, Vector())


def make_materials():
    out = {}
    for key, m in MATS.items():
        mat = bpy.data.materials.new(key)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (m["col"][0], m["col"][1], m["col"][2], 1.0)
        bsdf.inputs["Metallic"].default_value = m["metal"]
        bsdf.inputs["Roughness"].default_value = m["rough"]
        out[key] = mat
    return out


def main():
    global MATERIALS
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATERIALS = make_materials()
    build_body()
    build_drum()
    build_rounds()
    build_front()
    root = bpy.data.objects.new("M32", None)
    bpy.context.scene.collection.objects.link(root)
    PIVOTS["M32"] = ORIGIN
    drum_axis = Vector((0.0, 0.0, DRUM_Z))
    body = node_object("Body", PARTS["Body"], ORIGIN, root)
    PIVOTS["Body"] = ORIGIN
    drum = node_object("Drum", PARTS["Drum"], drum_axis, root)
    PIVOTS["Drum"] = drum_axis
    for i in range(6):
        node_object("Round%d" % i, PARTS["Round%d" % i], drum_axis, drum)
    node_object("Front", PARTS["Front"], HINGE, root)
    # The root sits at the grip; everything else is placed relative to it, so moving the
    # root to the origin puts the middle of the grip there.
    root.location = Vector()
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.data.update()
    tris = sum(len(p.vertices) - 2 for ob in bpy.data.objects if ob.type == "MESH" for p in ob.data.polygons)
    print("TRIANGLES", tris)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=False, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False)
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")


MATERIALS = {}
main()
