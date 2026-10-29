# Builds the vehicles of the Tokyo hall and the hay bales of the farm (v0.91, from Henry's
# reference pictures), from nothing, as plain coloured parts (no baked textures):
#   assets/tokyo/vehicles/bus.glb    the "TOKYO NEXT BUS" e-bus, fleet no. 2307, line 都23
#   assets/tokyo/vehicles/sedan.glb  a midsize saloon ("NORIKA AURA"), multi-spoke alloys
#   assets/tokyo/vehicles/jdm.glb    a widebody 80s wedge coupe with red-lit lamps, "天狗" livery
#   assets/models/hay_bale.glb       three small square bales (Bale0..Bale2), straws and twine
#
#   blender --background --factory-startup --python tools/blender_make_vehicles.py -- [--only bus,sedan,jdm,hay]
#           [--render <folder>] [--norender] [--noexport]
#
# The game recolours the material "Paint" of each car (its variants), puts its own lamps on
# the glowing parts and its own straw surface on the bale ("Straw"; the strands keep their
# vertex colours, which the farm's shader tints). Modelling space: x right, y forward (the
# front), z up, metres, origin in the middle of the footprint on the ground. The glTF exporter
# turns that into Godot space (the front toward -Z, up +Y), as _tk_car had it.
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix, noise

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from blender_make_ak47 import (arg, clear, link, mesh_object, box, cylinder, lathe, slab, loft, torus, fillet,
                               smooth, join, triangles, look_from, light, use_gpu, apply)

ROOT = os.path.abspath(os.path.join(HERE, ".."))
ONLY = (arg("--only") or "bus,sedan,jdm,hay").split(",")
RENDER = arg("--render")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NOEXPORT = "--noexport" in ARGV


# ------------------------------------------------------------------ materials
MATS = {}


def lin(hexcode):
    h = hexcode.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def mat(name, colour, rough=0.5, metal=0.0, emit=None, power=0.0, alpha=1.0):
    """A plain material; `emit` a colour that glows with `power`, `alpha` below 1 see-through."""
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*lin(colour), 1.0)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*lin(emit), 1.0)
        p.inputs["Emission Strength"].default_value = power
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, value)
            except Exception:
                pass
    MATS[name] = m
    return m


def common():
    return {
        "paint": mat("Paint", "f2f2ee", 0.28, 0.15),
        "trim": mat("Trim", "141516", 0.55),
        "gloss": mat("GlossBlack", "0c0d0f", 0.18, 0.1),
        "glass": mat("Glass", "1b232b", 0.04, 0.0, alpha=0.62),
        "darkglass": mat("DarkGlass", "0d1217", 0.06, 0.2),
        "rubber": mat("Rubber", "161616", 0.8),
        "rim": mat("Rim", "26282b", 0.32, 0.8),
        "chrome": mat("Chrome", "c8ccd0", 0.12, 1.0),
        "head": mat("HeadLamp", "f4f6ff", 0.1, 0.0, "f4f8ff", 6.0),
        "tail": mat("TailLamp", "a01010", 0.2, 0.0, "ff1a10", 4.0),
        "cyan": mat("LedCyan", "40f0ff", 0.2, 0.0, "40f0ff", 5.0),
        "orange": mat("LedOrange", "ff9a2a", 0.2, 0.0, "ff9a2a", 4.0),
        "red": mat("LedRed", "ff2020", 0.2, 0.0, "ff2018", 5.0),
        "plate": mat("Plate", "ecece6", 0.4),
        "plateink": mat("PlateInk", "1e4a2a", 0.5),
        "seat": mat("Seat", "1c2433", 0.8),
    }


# ------------------------------------------------------------------ shapes
PARTS = []


def add(o):
    PARTS.append(o)
    return o


def obox(name, centre, axes, material, bevel=0.0):
    """A box at `centre` whose edges are the three vectors `axes` (full lengths)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix((axes[0], axes[1], axes[2])).transposed().to_4x4()
    m.translation = Vector(centre)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    obj = mesh_object(name, bm, material)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.use_clamp_overlap = True
        apply(obj, mod)
    return add(obj)


def bx(name, low, high, material, bevel=0.0):
    return add(box(name, low, high, material, bevel))


def beam(name, a, b, w, h, material, up=(0, 0, 1), bevel=0.0):
    """A bar from a to b, `w` across and `h` high (h along `up` as far as it can)."""
    a, b = Vector(a), Vector(b)
    f = b - a
    length = f.length
    f.normalize()
    u = Vector(up)
    s = f.cross(u)
    if s.length < 1e-4:
        s = f.cross(Vector((1, 0, 0)))
    s.normalize()
    u = s.cross(f).normalized()
    return obox(name, (a + b) * 0.5, (s * w, f * length, u * h), material, bevel)


def cyl(name, a, b, r, material, segments=16):
    return add(cylinder(name, a, b, r, material, segments))


def blob(name, centre, axes, material, segments=12, rings=8):
    """An ellipsoid whose half axes are the three vectors `axes`."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    m = Matrix((axes[0], axes[1], axes[2])).transposed().to_4x4()
    m.translation = Vector(centre)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return add(smooth(mesh_object(name, bm, material), 80))


def ring(name, centre, axis, big, small, material, segments=28):
    return add(torus(name, centre, axis, big, small, material, segments, 6))


FONT = None


def font():
    global FONT
    if FONT is None:
        for path in ("C:/Windows/Fonts/YuGothB.ttc", "C:/Windows/Fonts/meiryob.ttc", "C:/Windows/Fonts/msgothic.ttc"):
            if os.path.exists(path):
                try:
                    FONT = bpy.data.fonts.load(path)
                    break
                except Exception:
                    pass
    return FONT


def text(s, size, material, at, normal, up=(0, 0, 1), depth=0.0, align="CENTER"):
    """Lettering standing out of a face: `at` its middle on the face, `normal` out of it."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = s
    if font():
        curve.font = font()
    curve.size = size
    curve.extrude = depth
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.resolution_u = 2
    obj = link(bpy.data.objects.new("Text", curve))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    n = Vector(normal).normalized()
    u = Vector(up)
    r = u.cross(n).normalized()
    u = n.cross(r).normalized()
    m = Matrix((r, u, n)).transposed().to_4x4()
    m.translation = Vector(at) + n * (depth + 0.002)
    obj.data.transform(m)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return add(obj)


def recolour(obj, rule):
    """Gives each face the material rule(centre, normal) returns (None: keeps its own)."""
    mesh = obj.data
    for p in mesh.polygons:
        m = rule(p.center, p.normal)
        if m is None:
            continue
        if mesh.materials.find(m.name) < 0:
            mesh.materials.append(m)
        p.material_index = mesh.materials.find(m.name)


def taper(obj, z0, z1, k):
    """Pulls the vertices in toward x 0 the higher they are (the tumblehome of a cabin)."""
    for v in obj.data.vertices:
        t = min(1.0, max(0.0, (v.co.z - z0) / (z1 - z0)))
        v.co.x *= 1.0 - k * t


def stations(y0, y1, step, dense=(), dense_step=None, half=0.6):
    ys = []
    y = y0
    while y < y1 - 1e-6:
        ys.append(y)
        near = any(abs(y - c) < half for c in dense)
        y += dense_step if (near and dense_step) else step
    ys.append(y1)
    return ys


def arch(y, axles, base, top, half):
    """The underside of a body: `base`, rising in a round arch to `top` over each wheel."""
    z = base
    for c in axles:
        d = abs(y - c)
        if d < half:
            z = max(z, base + (top - base) * math.sqrt(1.0 - (d / half) ** 2) ** 0.8)
    return z


def wheel(x, y, r, w, side, tyre, rim, spokes=10, glow=None, dish=0.03, spoke_mat=None, hub=None):
    """A wheel at (x, y) whose outer face looks to `side` (+1 right, -1 left)."""
    cz = r
    a = Vector((x - side * w * 0.5, y, cz))
    b = Vector((x + side * w * 0.5, y, cz))
    # The tyre is open in the middle (the rim shows through), round on its shoulders.
    rings = []
    for tt, rr in ((1.0, r * 0.64), (1.0, r * 0.88), (0.96, r * 0.97), (0.86, r), (0.14, r), (0.04, r * 0.97), (0.0, r * 0.88), (0.0, r * 0.64)):
        ring_ = []
        for k in range(26):
            ang = math.tau * k / 26
            ring_.append(a + (b - a) * tt + Vector((0, math.cos(ang) * rr, math.sin(ang) * rr)))
        rings.append(ring_)
    t = add(loft("Tyre", rings, tyre, caps=False))
    smooth(t, 50)
    out = x + side * (w * 0.5 - dish)
    # The barrel behind the spokes, the spokes, the hub.
    cyl("RimBack", (out - side * 0.05, y, cz), (out - side * 0.012, y, cz), r * 0.66, mat("RimDark", "0c0c0d", 0.6), 20)
    sm = spoke_mat or rim
    for k in range(spokes):
        ang = math.tau * k / spokes
        d = Vector((0, math.cos(ang), math.sin(ang)))
        beam("Spoke", Vector((out, y, cz)) + d * r * 0.12, Vector((out, y, cz)) + d * r * 0.64, r * 0.075, 0.018, sm, up=(side, 0, 0))
    ring("RimLip", (out, y, cz), (1, 0, 0), r * 0.645, r * 0.035, rim, 24)
    cyl("Hub", (out - side * 0.01, y, cz), (out + side * 0.012, y, cz), r * 0.13, hub or rim, 12)
    if glow:
        ring("RimGlow", (out + side * 0.004, y, cz), (1, 0, 0), r * 0.52, r * 0.016, glow, 28)


# ------------------------------------------------------------------ the bus
def build_bus():
    m = common()
    paint = m["paint"]
    black = m["gloss"]
    L2 = 5.3
    hw = 1.245
    axles = (3.2, -2.55)
    r = 0.5
    magenta = mat("Magenta", "e0208a", 0.3, 0.0, "ff2a9a", 1.6)
    sakura = mat("Sakura", "ff9cc8", 0.4, 0.0, "ff8cc0", 0.8)
    ink = mat("Ink", "17181a", 0.5)
    sign = mat("SignOrange", "ff8a1a", 0.3, 0.0, "ff8a1a", 5.0)
    yellow = mat("Handrail", "f2c21a", 0.35, 0.3)
    screen = mat("RouteScreen", "10203a", 0.3, 0.0, "2a4a8a", 2.0)
    ceiling = mat("Ceiling", "d8dade", 0.6, 0.0, "fff6e8", 0.8)
    floor = mat("Floor", "3a3d42", 0.8)

    # Lower body: from the ground clearance up to the window line, arches over the wheels.
    def lower_ring(y):
        zb = arch(y, axles, 0.3, 1.04, 0.66)
        end = max(0.0, abs(y) - (L2 - 0.12)) / 0.12
        w = hw - 0.06 * end * end
        zt = 1.28
        pts = [(w - 0.04, zb, 0.04), (w, zb + 0.05, 0.0), (w, 0.97, 0.0), (w, zt, 0.02), (-w, zt, 0.02), (-w, 0.97, 0.0), (-w, zb + 0.05, 0.0), (-w + 0.04, zb, 0.04)]
        return [(x, y, z) for x, z in fillet(pts, 2)]

    ys = stations(-L2, L2, 0.25, axles, 0.06, 0.7)
    for extra in (-L2 + 0.04, -L2 + 0.08, L2 - 0.04, L2 - 0.08):
        ys.append(extra)
    ys = sorted(set(round(v, 4) for v in ys))
    lower = add(loft("BusLower", [lower_ring(y) for y in ys], paint))
    recolour(lower, lambda c, n: black if (abs(n.x) > 0.5 and c.z < 0.97) or c.z < 0.4 or (n.z < -0.3 and c.z < 1.1) else None)
    smooth(lower, 30)
    # Roof: the white band over the windows, rounded on top.
    def roof_ring(y):
        end = max(0.0, abs(y) - (L2 - 0.12)) / 0.12
        w = hw - 0.06 * end * end
        pts = [(w, 2.6, 0.0), (w, 2.92, 0.12), (w - 0.25, 3.06, 0.3), (-w + 0.25, 3.06, 0.3), (-w, 2.92, 0.12), (-w, 2.6, 0.0)]
        return [(x, y, z) for x, z in fillet(pts, 3)]
    roof = add(loft("BusRoof", [roof_ring(y) for y in ys], paint))
    recolour(roof, lambda c, n: ceiling if n.z < -0.9 else None)
    smooth(roof, 30)

    # Window band: black pillars between the panes, see-through glass, the doors.
    door_mid = (0.05, 1.35)
    door_front = (4.35, 5.05)
    for side in (-1, 1):
        x = side * (hw + 0.004)
        posts = [-5.25, -4.2, -3.0, -1.8, -0.6, 0.05, 1.35, 2.3, 3.3, 4.35, 5.05] if side < 0 else [-5.25, -4.2, -3.0, -1.8, -0.6, 0.6, 1.8, 3.0, 4.2, 5.25]
        for p in posts:
            bx("Post", (x - 0.03, p - 0.07, 1.27), (x + 0.03, p + 0.07, 2.61), black)
        bx("Sill", (x - 0.03, -L2 + 0.05, 1.24), (x + 0.03, L2 - 0.05, 1.31), black)
        bx("Head", (x - 0.03, -L2 + 0.05, 2.56), (x + 0.03, L2 - 0.05, 2.63), black)
        for a, b in zip(posts, posts[1:]):
            if side < 0 and ((a, b) == door_mid or (a, b) == door_front):
                continue
            if a == -5.25:
                bx("RearPanel", (x - 0.012, a + 0.07, 1.31), (x + 0.012, b - 0.07, 2.56), paint)
                continue
            bx("Pane", (x - 0.008, a + 0.07, 1.31), (x + 0.008, b - 0.07, 2.56), m["glass"])
        # The magenta stripe and the cyan line under the roof.
        beam("Stripe", (x, -L2 + 0.2, 1.06), (x, L2 - 0.3, 1.0), 0.012, 0.06, magenta, up=(0, 0, 1))
        beam("Stripe2", (x, -L2 + 0.2, 1.15), (x, -1.2, 1.12), 0.012, 0.025, magenta)
        bx("RoofLed", (x - 0.012, -L2 + 0.15, 2.885), (x + 0.012, L2 - 0.15, 2.905), m["cyan"])
        # Lettering on the white band above the windows.
        nrm = (side, 0, 0)
        text("東京ネクストバス", 0.2, ink, (x + side * 0.004, -1.6, 2.78), nrm)
        text("TOKYO NEXT BUS", 0.13, ink, (x + side * 0.004, 1.5 if side > 0 else -3.6, 2.78), nrm)
        text("東京ネクストバス", 0.09, ink, (x + side * 0.016, -4.72, 1.5), nrm)
        text("2307", 0.16, ink, (x + side * 0.004, 4.0 if side > 0 else 3.85, 1.15), nrm)
        # Sakura logos: five petals round a dot.
        for cy, cz, size in ((-4.72, 1.98, 0.32), (3.95, 2.78, 0.09)):
            for k in range(5):
                a = math.tau * k / 5 + 0.3
                d = Vector((0, math.cos(a), math.sin(a)))
                blob("Petal", Vector((x + side * 0.016, cy, cz)) + d * size * 0.55, (Vector((0.004, 0, 0)), d * size * 0.5, d.cross(Vector((1, 0, 0))) * size * 0.32), sakura, 8, 4)
            blob("Heart", (x + side * 0.019, cy, cz), (Vector((0.004, 0, 0)), Vector((0, size * 0.18, 0)), Vector((0, 0, size * 0.18))), magenta, 8, 4)
        # Marker lights along the top edge, orange.
        for k in range(5):
            bx("Marker", (x - 0.015, -4.4 + k * 2.2, 2.95), (x + 0.015, -4.25 + k * 2.2, 2.99), m["orange"])
        # Wheels with cyan rings.
        for ay in axles:
            wheel(side * (hw - 0.17), ay, r, 0.32, side, m["rubber"], m["rim"], 3, m["cyan"], 0.035, spoke_mat=black, hub=black)
            # (Henry's picture: a silver hubcap under the three spokes.)
            out = side * (hw - 0.17) + side * (0.16 - 0.035)
            cyl("Hubcap", (out - side * 0.014, ay, r), (out - side * 0.006, ay, r), r * 0.6, mat("Hubcap", "cfd3d8", 0.3, 0.6), 24)
    # Doors on the left (the kerb side in Japan): double door in the middle, one at the front.
    for (a, b), split in ((door_mid, True), (door_front, False)):
        x = -(hw + 0.01)
        bx("Door", (x - 0.01, a + 0.06, 0.34), (x + 0.01, b - 0.06, 2.57), mat("DoorGlass", "1a2630", 0.08, 0.2))
        for z0, z1 in ((0.34, 0.95),):
            bx("DoorLow", (x - 0.016, a + 0.08, z0), (x - 0.004, b - 0.08, z1), black)
        for yy in ((a + 0.07, a + 0.095), (b - 0.095, b - 0.07)) + (((a + b) * 0.5 - 0.012, (a + b) * 0.5 + 0.012),) if split else ((a + 0.07, a + 0.095), (b - 0.095, b - 0.07)):
            bx("DoorLed", (x - 0.022, yy[0], 0.36), (x - 0.008, yy[1], 2.55), m["cyan"])
        bx("DoorLedTop", (x - 0.022, a + 0.07, 2.535), (x - 0.008, b - 0.07, 2.555), m["cyan"])
        if split:
            text("入口  ENTRANCE", 0.13, ink, (-hw - 0.004, (a + b) * 0.5, 2.7), (-1, 0, 0))
            # Wheelchair sign beside the door.
            bx("Wheelchair", (-hw - 0.016, b + 0.12, 1.55), (-hw - 0.006, b + 0.36, 1.79), mat("SignBlue", "1f5fc8", 0.4))
            ring("WcWheel", (-hw - 0.018, b + 0.25, 1.62), (1, 0, 0), 0.05, 0.008, mat("White", "f4f4f4", 0.4), 16)
            blob("WcHead", (-hw - 0.018, b + 0.22, 1.74), (Vector((0.003, 0, 0)), Vector((0, 0.017, 0)), Vector((0, 0, 0.017))), MATS["White"], 8, 4)
            beam("WcBack", (-hw - 0.018, b + 0.22, 1.72), (-hw - 0.018, b + 0.23, 1.64), 0.004, 0.014, MATS["White"], up=(-1, 0, 0))
            beam("WcSeat", (-hw - 0.018, b + 0.23, 1.645), (-hw - 0.018, b + 0.3, 1.645), 0.004, 0.014, MATS["White"], up=(-1, 0, 0))
    # Inside: floor (the lower body's top), blue seats, yellow poles and rails, the light, the screens.
    bx("Floor", (-hw + 0.06, -L2 + 0.2, 1.28), (hw - 0.06, L2 - 0.4, 1.3), floor)
    for k in range(9):
        y = -4.8 + k * 1.0
        if 0.0 < y < 1.5:
            continue
        for side in (-1, 1):
            if side < 0 and y > 3.6:
                continue
            bx("Cushion", (side * 0.35 - 0.38, y - 0.22, 1.3), (side * 0.35 + 0.38, y + 0.22, 1.42), m["seat"], 0.02)
            bx("Back", (side * 0.35 - 0.38, y - 0.3, 1.42), (side * 0.35 + 0.38, y - 0.2, 1.98), m["seat"], 0.02)
    for y in (-3.6, -1.6, 0.0, 1.4, 2.6, 4.3):
        for side in (-1, 1):
            cyl("Pole", (side * 0.62, y, 1.3), (side * 0.62, y, 2.58), 0.02, yellow, 8)
    for side in (-1, 1):
        cyl("Rail", (side * 0.55, -L2 + 0.5, 2.42), (side * 0.55, L2 - 0.6, 2.42), 0.018, yellow, 8)
        # Route map screen just behind the window near the front, lit, looking out.
        x = side * (hw - 0.05)
        bx("Screen", (x - 0.015, 2.45, 2.0), (x + 0.015, 2.95, 2.38), screen)
        beam("RouteLine", (x + side * 0.018, 2.5, 2.17), (x + side * 0.018, 2.9, 2.21), 0.004, 0.015, m["orange"], up=(0, 0, 1))
        for k in range(6):
            bx("Stop", (x + side * 0.016 - 0.004, 2.52 + k * 0.07, 2.16 + k * 0.007), (x + side * 0.016 + 0.006, 2.535 + k * 0.07, 2.215 + k * 0.007), MATS["White"] if "White" in MATS else mat("White", "f4f4f4", 0.4))
    bx("CeilingLed", (-0.12, -L2 + 0.6, 2.585), (0.12, L2 - 0.8, 2.6), mat("CeilingGlow", "fff2de", 0.4, 0.0, "fff2de", 2.5))

    # Front: big windscreen, the destination sign above it, split lamps, plate, mirrors.
    yf = L2 + 0.002
    for low, high in (((-hw + 0.02, yf - 0.03, 1.24), (hw - 0.02, yf + 0.02, 1.32)), ((-hw + 0.02, yf - 0.03, 2.52), (hw - 0.02, yf + 0.02, 2.62)),
                      ((-hw + 0.02, yf - 0.03, 0.98), (-hw + 0.1, yf + 0.02, 2.62)), ((hw - 0.1, yf - 0.03, 0.98), (hw - 0.02, yf + 0.02, 2.62))):
        bx("FrontFrame", low, high, black)
    # The driver's place behind it: dashboard, wheel, seat.
    bx("Dashboard", (-hw + 0.08, L2 - 0.55, 1.28), (hw - 0.08, L2 - 0.05, 1.5), m["trim"], 0.03)
    bx("DashScreen", (0.35, L2 - 0.5, 1.5), (0.85, L2 - 0.46, 1.66), mat("DashGlow", "1a3a5a", 0.3, 0.0, "40a0ff", 1.5))
    ring("SteeringWheel", (0.62, L2 - 0.62, 1.62), (0, 0.6, 0.8), 0.22, 0.02, m["trim"], 20)
    bx("DriverSeat", (0.4, L2 - 1.4, 1.3), (0.85, L2 - 0.95, 1.45), m["seat"], 0.03)
    bx("DriverBack", (0.4, L2 - 1.5, 1.45), (0.85, L2 - 1.38, 2.1), m["seat"], 0.03)
    beam("Windscreen", (0, yf + 0.025, 1.3), (0, yf - 0.03, 2.55), 2.28, 0.012, mat("Windscreen", "1b2530", 0.03, 0.0, alpha=0.5), up=(0, 1, 0))
    bx("SignBox", (-1.05, yf - 0.01, 2.64), (1.05, yf + 0.035, 2.98), black)
    # (Henry's picture) a sakura left of the sign, the wheelchair right of it (as one looks at it).
    for k in range(5):
        a = math.tau * k / 5 + 0.3
        d = Vector((math.cos(a), 0, math.sin(a)))
        blob("SignPetal", Vector((0.93, yf + 0.04, 2.81)) + d * 0.05, (d * 0.045, Vector((0, 0.003, 0)), d.cross(Vector((0, 1, 0))) * 0.03), magenta, 8, 4)
    white = MATS.get("White") or mat("White", "f4f4f4", 0.4)
    bx("SignWheelchair", (-1.0, yf + 0.03, 2.71), (-0.82, yf + 0.04, 2.91), MATS.get("SignBlue") or mat("SignBlue", "1f5fc8", 0.4))
    ring("SignWcWheel", (-0.91, yf + 0.043, 2.77), (0, 1, 0), 0.04, 0.007, white, 16)
    blob("SignWcHead", (-0.92, yf + 0.043, 2.875), (Vector((0.014, 0, 0)), Vector((0, 0.003, 0)), Vector((0, 0, 0.014))), white, 8, 4)
    add(_prism_y("NamePanel", [(-0.98, 0.88), (0.98, 0.88), (1.12, 1.25), (-1.12, 1.25)], yf - 0.01, yf + 0.03, black))
    text("東京ネクストバス", 0.14, white, (0.0, yf + 0.031, 1.12), (0, 1, 0))
    text("— TOKYO NEXT BUS —", 0.055, white, (0.0, yf + 0.031, 0.97), (0, 1, 0))
    ring("NameLogo", (0.0, yf + 0.033, 1.21), (0, 1, 0), 0.03, 0.006, white, 16)
    text("都23  新海町・未来駅", 0.15, sign, (0.0, yf + 0.036, 2.86), (0, 1, 0))
    text("Shinkai-cho · Mirai Station", 0.075, sign, (0.0, yf + 0.036, 2.71), (0, 1, 0))
    for side in (-1, 1):
        sx = side
        beam("LedBrow", (sx * 1.2, yf + 0.02, 0.86), (sx * 0.62, yf + 0.02, 0.78), 0.03, 0.035, m["cyan"], up=(0, 0, 1))
        beam("LampHousing", (sx * 1.18, yf + 0.012, 0.69), (sx * 0.7, yf + 0.012, 0.65), 0.03, 0.11, black, up=(0, 0, 1))
        for k in range(3):
            beam("Lamp", (sx * (1.14 - k * 0.15), yf + 0.03, 0.69 - k * 0.012), (sx * (1.03 - k * 0.15), yf + 0.03, 0.68 - k * 0.012), 0.012, 0.06, m["head"], up=(0, 0, 1))
        bx("CornerMarker", (sx * 1.18 - 0.07, yf - 0.03, 2.98), (sx * 1.18 + 0.07, yf + 0.03, 3.02), m["orange"])
        bx("CornerAmber", (sx * 1.2 - 0.02, yf - 0.01, 0.42), (sx * 1.2 + 0.02, yf + 0.035, 0.7), m["orange"])
        beam("BumperAmber", (sx * 1.12, yf + 0.065, 0.36), (sx * 0.8, yf + 0.065, 0.33), 0.02, 0.02, m["orange"], up=(0, 0, 1))
        # Mirror on its stalk, reaching forward over the screen.
        beam("MirrorArm", (sx * 1.2, L2 - 0.05, 2.62), (sx * 1.36, L2 + 0.32, 2.66), 0.04, 0.04, black)
        beam("MirrorArm2", (sx * 1.36, L2 + 0.32, 2.66), (sx * 1.36, L2 + 0.36, 2.25), 0.04, 0.04, black, up=(0, 1, 0))
        bx("Mirror", (sx * 1.36 - 0.07, L2 + 0.3, 1.9), (sx * 1.36 + 0.07, L2 + 0.42, 2.3), black, 0.02)
    bx("Bumper", (-hw + 0.03, yf - 0.05, 0.3), (hw - 0.03, yf + 0.06, 0.5), black, 0.02)
    bx("PlateFront", (-0.22, yf + 0.04, 0.5), (0.22, yf + 0.06, 0.72), mat("PlateGreen", "1f6b3a", 0.4))
    white_ink = mat("PlateWhite", "f2f2ea", 0.4)
    text("東京 230", 0.05, white_ink, (0.0, yf + 0.061, 0.68), (0, 1, 0))
    text("あ 23-07", 0.095, white_ink, (0.02, yf + 0.061, 0.57), (0, 1, 0))
    text("2307", 0.08, ink, (0.95, yf + 0.03, 0.8), (0, 1, 0))
    # Rear: small window, tall tail lamps, lettering.
    yb = -L2 - 0.002
    bx("RearWall", (-hw + 0.04, yb + 0.005, 1.27), (hw - 0.04, yb + 0.06, 2.61), paint)
    bx("RearFrame", (-0.95, yb - 0.006, 1.66), (0.95, yb + 0.01, 2.54), black)
    bx("RearWindow", (-0.9, yb - 0.012, 1.7), (0.9, yb + 0.01, 2.5), m["darkglass"])
    for side in (-1, 1):
        bx("TailLamp", (side * 1.15 - 0.06, yb - 0.02, 0.6), (side * 1.15 + 0.06, yb + 0.01, 1.6), m["tail"])
        bx("RearLed", (side * 1.15 - 0.012, yb - 0.025, 1.65), (side * 1.15 + 0.012, yb + 0.01, 2.5), m["cyan"])
    text("TOKYO NEXT BUS", 0.16, ink, (0, yb - 0.003, 1.42), (0, -1, 0))
    bx("RearBumper", (-hw + 0.03, yb - 0.06, 0.3), (hw - 0.03, yb + 0.05, 0.5), black, 0.02)
    bx("PlateRear", (-0.22, yb - 0.06, 0.5), (0.22, yb - 0.04, 0.72), MATS["PlateGreen"])
    text("あ 23-07", 0.095, white_ink, (0.0, yb - 0.061, 0.58), (0, -1, 0))
    # On the roof: the climate unit, battery packs, a sensor dome, antennas.
    bx("Climate", (-0.85, 0.4, 3.02), (0.85, 3.1, 3.32), mat("RoofGrey", "c9ccd0", 0.4, 0.2), 0.05)
    for k in range(6):
        bx("Grille", (-0.7, 0.7 + k * 0.4, 3.32), (0.7, 0.86 + k * 0.4, 3.335), m["trim"])
    for k in range(3):
        bx("Battery", (-0.95, -4.6 + k * 1.35, 3.02), (0.95, -3.4 + k * 1.35, 3.24), MATS["RoofGrey"], 0.04)
        bx("BatteryLed", (-0.96, -4.4 + k * 1.35, 3.12), (0.96, -3.6 + k * 1.35, 3.14), m["cyan"])
    blob("Dome", (0, 4.5, 3.06), (Vector((0.16, 0, 0)), Vector((0, 0.16, 0)), Vector((0, 0, 0.13))), mat("DomeGlass", "10161c", 0.05, 0.3), 14, 8)
    bx("DomeBase", (-0.2, 4.3, 3.0), (0.2, 4.7, 3.07), m["trim"], 0.02)
    for x, y, tall in ((0.6, 4.1, 0.35), (-0.6, 3.6, 0.25), (0.3, -0.2, 0.3)):
        cyl("Antenna", (x, y, 3.04), (x, y, 3.04 + tall), 0.01, m["trim"], 6)
        blob("AntennaTip", (x, y, 3.04 + tall), (Vector((0.018, 0, 0)), Vector((0, 0.018, 0)), Vector((0, 0, 0.018))), m["trim"], 6, 4)
    return "Bus"


# ------------------------------------------------------------------ the saloon
def build_sedan():
    m = common()
    paint = m["paint"]
    L2 = 2.425
    axles = (1.42, -1.40)
    r = 0.34

    def zt(y):
        pts = [(-2.43, 0.74), (-2.40, 0.88), (-2.30, 0.99), (-2.1, 1.04), (-1.3, 1.05), (-0.4, 1.03), (0.95, 0.99), (1.6, 0.93), (2.2, 0.87), (2.38, 0.82), (2.43, 0.72)]
        return interp(pts, y)

    def hw(y):
        return interp([(-2.43, 0.8), (-2.36, 0.88), (-2.2, 0.91), (-1.0, 0.925), (1.0, 0.925), (2.0, 0.905), (2.3, 0.85), (2.43, 0.74)], y)

    def zb(y):
        base = interp([(-2.43, 0.38), (-2.25, 0.27), (-1.9, 0.24), (2.0, 0.24), (2.3, 0.28), (2.43, 0.34)], y)
        return arch(y, axles, base, 0.75, 0.47)

    def body_ring(y):
        w, b, t = hw(y), zb(y), zt(y)
        pts = [(w * 0.95, b, 0.06), (w, b + (t - b) * 0.42, 0.18), (w * 0.93, t, 0.12), (-w * 0.93, t, 0.12), (-w, b + (t - b) * 0.42, 0.18), (-w * 0.95, b, 0.06)]
        return [(x, y, z) for x, z in fillet(pts, 3)]

    ys = stations(-L2, L2, 0.09, axles, 0.035, 0.5)
    body = add(loft("Body", [body_ring(y) for y in ys], paint))
    recolour(body, lambda c, n: m["trim"] if n.z < -0.3 and c.z > 0.3 else None)
    smooth(body, 45)
    # The cabin: glass all round, the roof and the pillars in paint over it.
    outline = fillet([(0.98, 0.985, 0.0), (0.3, 1.43, 0.08), (-0.55, 1.455, 0.1), (-1.32, 1.04, 0.0)], 4)
    cab = add(slab("Cabin", outline, -0.88, 0.88, m["glass"]))
    taper(cab, 0.98, 1.45, 0.22)
    roof = add(slab("Roof", fillet([(0.36, 1.405, 0.0), (0.2, 1.462, 0.05), (-0.52, 1.472, 0.06), (-0.74, 1.405, 0.0)], 3), -0.895, 0.895, paint))
    taper(roof, 0.98, 1.45, 0.22)
    smooth(roof, 40)
    for s in (-1, 1):
        k = lambda z: 1.0 - 0.22 * min(1.0, max(0.0, (z - 0.98) / 0.47))
        beam("APillar", (s * 0.885 * k(1.0), 0.95, 1.0), (s * 0.887 * k(1.42), 0.32, 1.425), 0.03, 0.07, paint, up=(s, 0, 0))
        beam("BPillar", (s * 0.887 * k(1.0), -0.2, 1.0), (s * 0.889 * k(1.44), -0.25, 1.445), 0.02, 0.08, m["gloss"], up=(s, 0, 0))
        beam("CPillar", (s * 0.886 * k(1.06), -1.18, 1.05), (s * 0.888 * k(1.43), -0.6, 1.435), 0.03, 0.2, paint, up=(s, 0, 0))
        beam("WindowLine", (s * 0.875, 0.92, 1.0), (s * 0.875, -1.15, 1.045), 0.012, 0.018, m["chrome"])
        # Mirrors, handles, the black sill between the wheels, the door seams.
        bx("MirrorFoot", (s * 0.86, 0.78, 1.0), (s * 0.93, 0.9, 1.05), m["gloss"])
        blob("Mirror", (s * 1.0, 0.8, 1.07), (Vector((0.09, 0, 0)), Vector((0, 0.05, 0)), Vector((0, 0, 0.055))), paint, 10, 6)
        for hy in (0.15, -0.85):
            bx("Handle", (s * 0.928 - 0.008, hy - 0.08, 0.91), (s * 0.928 + 0.008, hy + 0.08, 0.935), m["chrome"])
        bx("Sill", (s * 0.895, -0.92, 0.23), (s * 0.94, 0.95, 0.31), m["trim"])
        for sy in (0.98, -0.22, -1.2):
            bx("Seam", (s * 0.925 - 0.003, sy - 0.004, 0.33), (s * 0.925 + 0.003, sy + 0.004, 0.98), mat("Seam", "0a0a0a", 0.7))
        for ay in axles:
            wheel(s * 0.79, ay, r, 0.23, s, m["rubber"], mat("Alloy", "4a4e55", 0.25, 0.9), 10, None, 0.03, hub=m["chrome"])
    # Front: the large trapezoid grille, sharp lamps, a lit strip, the plate, a badge.
    yf = L2
    g = [(-0.6, 0.3), (0.6, 0.3), (0.44, 0.67), (-0.44, 0.67)]
    add(_prism_y("Grille", g, yf - 0.03, yf + 0.03, m["gloss"]))
    for k in range(7):
        z = 0.34 + k * 0.05
        w = 0.58 - k * 0.028
        bx("Slat", (-w, yf + 0.03, z), (w, yf + 0.036, z + 0.012), mat("SlatGrey", "3a3d42", 0.3, 0.7))
    blob("Badge", (0, yf + 0.04, 0.61), (Vector((0.07, 0, 0)), Vector((0, 0.008, 0)), Vector((0, 0, 0.045))), m["chrome"], 12, 4)
    for s in (-1, 1):
        beam("LampHousing", (s * 0.38, 2.43, 0.66), (s * 0.71, 2.395, 0.69), 0.075, 0.03, m["gloss"], up=(0, 1, 0))
        beam("Lamp", (s * 0.42, 2.442, 0.665), (s * 0.69, 2.41, 0.692), 0.04, 0.012, m["head"], up=(0, 1, 0))
        beam("Drl", (s * 0.4, 2.445, 0.637), (s * 0.7, 2.41, 0.655), 0.01, 0.012, mat("LedWhite", "e8f2ff", 0.2, 0.0, "e8f2ff", 6.0), up=(0, 1, 0))
        bx("FogVent", (s * 0.66 - 0.1, yf - 0.02, 0.32), (s * 0.66 + 0.1, yf + 0.02, 0.42), m["gloss"])
    bx("PlateF", (-0.17, yf + 0.03, 0.4), (0.17, yf + 0.045, 0.565), m["plate"])
    text("品川 330", 0.035, m["plateink"], (0, yf + 0.046, 0.535), (0, 1, 0))
    text("さ 12-34", 0.065, m["plateink"], (0.01, yf + 0.046, 0.455), (0, 1, 0))
    # Rear: lamps joined by a lit bar, the name, the plate.
    yb = -L2
    for s in (-1, 1):
        beam("Tail", (s * 0.3, yb + 0.03, 0.95), (s * 0.88, -2.3, 0.94), 0.07, 0.07, m["tail"], up=(0, -1, 0.2))
    bx("TailBar", (-0.32, yb - 0.005, 0.93), (0.32, yb + 0.04, 0.96), m["tail"])
    text("NORIKA", 0.05, m["chrome"], (0, yb - 0.002, 0.86), (0, -1, 0))
    text("AURA", 0.035, m["chrome"], (0.6, yb + 0.01, 0.84), (0, -1, 0))
    bx("PlateR", (-0.17, yb - 0.02, 0.58), (0.17, yb + 0.0, 0.745), m["plate"])
    text("さ 12-34", 0.065, m["plateink"], (0.01, yb - 0.021, 0.64), (0, -1, 0))
    bx("RearDiffuser", (-0.7, yb - 0.01, 0.3), (0.7, yb + 0.08, 0.4), m["trim"])
    # Inside: dashboard, seats.
    bx("Dash", (-0.78, 0.55, 0.9), (0.78, 0.95, 1.05), m["trim"])
    for s in (-1, 1):
        bx("Seat", (s * 0.4 - 0.24, -0.15, 0.45), (s * 0.4 + 0.24, 0.35, 0.65), m["seat"], 0.03)
        bx("SeatBack", (s * 0.4 - 0.24, -0.25, 0.65), (s * 0.4 + 0.24, -0.12, 1.25), m["seat"], 0.03)
    bx("Bench", (-0.75, -0.95, 0.45), (0.75, -0.5, 0.65), m["seat"], 0.03)
    bx("BenchBack", (-0.75, -1.0, 0.65), (0.75, -0.88, 1.12), m["seat"], 0.03)
    return "Sedan"


def _prism_y(name, profile, y0, y1, material):
    """A body of the cross-section `profile` ((x, z) points) from y0 to y1."""
    bm = bmesh.new()
    back = [bm.verts.new((x, y0, z)) for x, z in profile]
    front = [bm.verts.new((x, y1, z)) for x, z in profile]
    bm.faces.new(list(reversed(back)))
    bm.faces.new(front)
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


def interp(pts, y):
    if y <= pts[0][0]:
        return pts[0][1]
    for (y0, v0), (y1, v1) in zip(pts, pts[1:]):
        if y <= y1:
            t = (y - y0) / (y1 - y0)
            t = t * t * (3 - 2 * t)
            return v0 + (v1 - v0) * t
    return pts[-1][1]


# ------------------------------------------------------------------ the wedge coupe
def build_jdm():
    m = common()
    paint = m["paint"]
    black = mat("LiveryBlack", "121214", 0.45, 0.1)
    red = mat("LiveryRed", "d01818", 0.4)
    white = mat("LiveryWhite", "f2f0ea", 0.45)
    L2 = 2.17
    axles = (1.27, -1.22)
    r = 0.32

    def zt(y):
        return interp([(-2.18, 0.76), (-2.12, 0.9), (-1.9, 0.94), (-0.9, 0.92), (0.7, 0.86), (1.45, 0.74), (2.08, 0.6), (2.18, 0.5)], y)

    def hw(y):
        flare = 0.0
        for c in axles:
            d = abs(y - c)
            if d < 0.62:
                flare = max(flare, 0.075 * math.cos(d / 0.62 * math.pi * 0.5) ** 0.7)
        return interp([(-2.18, 0.8), (-2.1, 0.86), (2.0, 0.86), (2.18, 0.76)], y) + flare

    def zb(y):
        base = interp([(-2.18, 0.3), (-2.0, 0.2), (1.9, 0.18), (2.18, 0.24)], y)
        return arch(y, axles, base, 0.69, 0.45)

    def body_ring(y):
        w, b, t = hw(y), zb(y), zt(y)
        pts = [(w * 0.94, b, 0.03), (w, b + (t - b) * 0.35, 0.05), (w * 0.97, t, 0.04), (-w * 0.97, t, 0.04), (-w, b + (t - b) * 0.35, 0.05), (-w * 0.94, b, 0.03)]
        return [(x, y, z) for x, z in fillet(pts, 2)]

    ys = stations(-L2, L2, 0.09, axles, 0.035, 0.55)
    body = add(loft("Body", [body_ring(y) for y in ys], paint))
    # The livery: black hood and lower body, white sides and roof.
    recolour(body, lambda c, n: black if (c.z < 0.4 and abs(n.x) > 0.3) or (c.y > 0.72 and n.z > 0.55) or c.z < 0.25 or c.y < -0.95 or c.y > 1.95 else None)
    smooth(body, 28)
    outline = fillet([(0.74, 0.865, 0.0), (0.02, 1.2, 0.07), (-0.75, 1.21, 0.12), (-1.85, 0.935, 0.0)], 4)
    cab = add(slab("Cabin", outline, -0.82, 0.82, m["glass"]))
    taper(cab, 0.86, 1.21, 0.24)
    roof = add(slab("Roof", fillet([(0.1, 1.185, 0.0), (-0.02, 1.222, 0.04), (-0.7, 1.232, 0.06), (-0.95, 1.18, 0.0)], 3), -0.835, 0.835, black))
    taper(roof, 0.86, 1.21, 0.24)
    smooth(roof, 40)
    for s in (-1, 1):
        k = lambda z: 1.0 - 0.24 * min(1.0, max(0.0, (z - 0.86) / 0.35))
        beam("APillar", (s * 0.83 * k(0.88), 0.72, 0.88), (s * 0.835 * k(1.19), 0.06, 1.19), 0.025, 0.06, black, up=(s, 0, 0))
        beam("CPillar", (s * 0.83 * k(0.95), -1.62, 0.95), (s * 0.835 * k(1.2), -0.82, 1.2), 0.02, 0.07, black, up=(s, 0, 0))
        # Door art: the red sun, a white crane across it, the name behind.
        x = s * 0.868
        sun = (x, -0.42, 0.6)
        cyl("Sun", (x - s * 0.003, sun[1], sun[2]), (x + s * 0.004, sun[1], sun[2]), 0.25, red, 32)
        xo = x + s * 0.0055
        cy, cz = sun[1] + 0.03, sun[2] + 0.0
        def crane(outline, material, lift=0.0):
            add(slab("Crane", [(cy + py, cz + pz) for py, pz in outline], xo + s * lift, xo + s * (lift + 0.002), material))
        crane([(0.08, 0.0), (0.04, 0.03), (-0.04, 0.03), (-0.1, 0.0), (-0.04, -0.025), (0.04, -0.022)], white)
        crane([(0.05, 0.0), (0.2, 0.06), (0.235, 0.075), (0.225, 0.085), (0.19, 0.075), (0.04, 0.025)], white)
        crane([(0.05, 0.02), (0.02, 0.12), (-0.04, 0.22), (-0.13, 0.29), (-0.21, 0.28), (-0.19, 0.21), (-0.14, 0.12), (-0.07, 0.03)], white)
        crane([(-0.13, 0.29), (-0.21, 0.28), (-0.2, 0.235), (-0.11, 0.255)], black, 0.001)
        crane([(0.04, -0.015), (0.0, -0.1), (-0.06, -0.18), (-0.13, -0.23), (-0.19, -0.2), (-0.15, -0.13), (-0.1, -0.06), (-0.05, -0.02)], white)
        crane([(-0.13, -0.23), (-0.19, -0.2), (-0.175, -0.165), (-0.11, -0.2)], black, 0.001)
        crane([(-0.09, -0.012), (-0.25, -0.05), (-0.25, -0.058), (-0.09, -0.02)], black)
        crane([(0.225, 0.085), (0.235, 0.075), (0.3, 0.07), (0.235, 0.08)], black)
        blob("CraneCrown", (xo + s * 0.003, cy + 0.215, cz + 0.083), (Vector((0.002, 0, 0)), Vector((0, 0.014, 0)), Vector((0, 0, 0.009))), red, 6, 4)
        text("天狗", 0.22, black, (x + s * 0.004, 0.22, 0.6), (s, 0, 0))
        text("NIGHT RUN  SPEC-R", 0.04, black, (x + s * 0.004, 0.22, 0.44), (s, 0, 0))
        cyl("SillPipe", (s * 0.93, -0.75, 0.2), (s * 0.93, 0.75, 0.2), 0.03, mat("PipeSteel", "3a3c40", 0.35, 0.8), 10)
        # Red light under the sills, side pipes before the rear wheels.
        bx("SideSkirt", (s * 0.83, -0.75, 0.15), (s * 0.95, 0.8, 0.25), black)
        bx("SkirtLed", (s * 0.9, -0.7, 0.145), (s * 0.94, 0.75, 0.155), m["red"])
        for k in (0, 1):
            cyl("SidePipe", (s * 0.86, -0.7 - k * 0.09, 0.27), (s * 0.99, -0.7 - k * 0.09, 0.27), 0.035, m["chrome"], 12)
            cyl("PipeHole", (s * 0.95, -0.7 - k * 0.09, 0.27), (s * 0.992, -0.7 - k * 0.09, 0.27), 0.026, mat("Soot", "050505", 0.9), 10)
        for ay in axles:
            wheel(s * 0.84, ay, r, 0.27, s, m["rubber"], mat("DishBlack", "151517", 0.3, 0.6), 12, m["red"], 0.05, spoke_mat=mat("SpokeBlack", "202124", 0.35, 0.7), hub=m["red"])
        blob("Mirror", (s * 0.93, 0.6, 0.93), (Vector((0.07, 0, 0)), Vector((0, 0.05, 0)), Vector((0, 0, 0.04))), black, 10, 6)
    # Front (Henry's picture): a black face with low red-lit lamps, "夜走り" lit in the grille,
    # red strips in the bumper, the splitter.
    yf = L2
    bx("FrontFace", (-0.74, yf - 0.03, 0.3), (0.74, yf + 0.012, 0.5), m["gloss"])
    for s in (-1, 1):
        lo, hi = sorted((s * 0.44, s * 0.72))
        bx("LampHousing", (lo, yf - 0.02, 0.38), (hi, yf + 0.02, 0.48), black)
        for k in range(3):
            bx("RedLamp", (lo + 0.02, yf + 0.02, 0.395 + k * 0.028), (hi - 0.02, yf + 0.03, 0.41 + k * 0.028), m["red"])
        lo2, hi2 = sorted((s * 0.73, s * 0.79))
        bx("CornerLamp", (lo2, yf - 0.08, 0.36), (hi2, yf - 0.03, 0.48), m["red"])
        beam("BumperLed", (s * 0.25, yf + 0.004, 0.42), (s * 0.78, yf - 0.06, 0.44), 0.015, 0.018, m["red"], up=(0, 1, 0))
    bx("Splitter", (-0.85, 1.98, 0.13), (0.85, 2.24, 0.155), mat("Carbon", "18191b", 0.35, 0.3))
    bx("Intake", (-0.55, yf - 0.02, 0.24), (0.55, yf + 0.015, 0.36), m["gloss"])
    bx("Grille", (-0.36, yf + 0.0, 0.38), (0.36, yf + 0.022, 0.48), mat("GrilleDark", "0a0a0b", 0.6))
    text("夜走り", 0.08, m["red"], (0, yf + 0.024, 0.43), (0, 1, 0))
    mat("PlateBlack", "141414", 0.5)
    # Underglow: a lit panel under the floor.
    bx("Underglow", (-0.6, -1.6, 0.11), (0.6, 1.6, 0.125), m["red"])
    # Rear: the wing on its stands, a black panel with a red light bar, the pipes, the plate.
    for s in (-1, 1):
        beam("WingStand", (s * 0.55, -1.98, 0.93), (s * 0.55, -2.05, 1.2), 0.04, 0.14, black, up=(0, 1, 0))
        bx("EndPlate", (s * 0.86 - 0.01, -2.3, 1.08), (s * 0.86 + 0.01, -1.88, 1.3), black)
        text("天狗", 0.08, red, (s * 0.871 * 1.0 + s * 0.0, -2.08, 1.19), (s, 0, 0))
    beam("Wing", (-0.87, -2.1, 1.22), (0.87, -2.1, 1.22), 0.4, 0.035, black, up=(0, 0.2, 1))
    beam("Gurney", (-0.86, -2.29, 1.25), (0.86, -2.29, 1.25), 0.02, 0.05, red, up=(0, 0, 1))
    yb = -L2
    bx("TailPanel", (-0.8, yb - 0.015, 0.74), (0.8, yb + 0.02, 0.88), m["gloss"])
    bx("TailBar", (-0.76, yb - 0.02, 0.785), (0.76, yb + 0.01, 0.83), m["tail"])
    bx("Diffuser", (-0.75, yb - 0.02, 0.18), (0.75, yb + 0.15, 0.32), mat("Carbon", "18191b", 0.35, 0.3))
    for s in (-1, 1):
        for k in range(3):
            bx("Fin", (s * (0.2 + k * 0.18) - 0.01, yb - 0.03, 0.15), (s * (0.2 + k * 0.18) + 0.01, yb + 0.12, 0.31), black)
    bx("PlateR", (-0.16, yb - 0.03, 0.48), (0.16, yb - 0.015, 0.61), m["plate"])
    text("夜走り", 0.07, MATS["PlateBlack"], (0, yb - 0.031, 0.545), (0, -1, 0))
    # Inside: bucket seats, a roll cage hoop.
    bx("Dash", (-0.74, 0.35, 0.72), (0.74, 0.7, 0.86), m["trim"])
    for s in (-1, 1):
        bx("Bucket", (s * 0.38 - 0.22, -0.55, 0.3), (s * 0.38 + 0.22, -0.05, 0.5), mat("BucketRed", "6a0e0e", 0.8), 0.04)
        bx("BucketBack", (s * 0.38 - 0.22, -0.65, 0.5), (s * 0.38 + 0.22, -0.5, 1.08), MATS["BucketRed"], 0.04)
        cyl("Cage", (s * 0.66, -0.75, 0.4), (s * 0.6, -0.78, 1.14), 0.02, m["trim"], 6)
    cyl("CageTop", (-0.6, -0.78, 1.14), (0.6, -0.78, 1.14), 0.02, m["trim"], 6)
    return "Jdm"


# ------------------------------------------------------------------ the hay bale
def build_bale(index):
    """A small square bale, 0.9 wide, 0.72 high, 1.2 long (along y), tied with two strings
    along it and two across, straws standing out everywhere and fanned out at the cut ends."""
    rnd = random.Random(31 + index * 97)
    straw = mat("Straw", "d9b765", 0.85)
    twine = mat("Twine", "8a7350", 0.85)
    hx, hy, hz = 0.45, 0.6, 0.36
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=9, use_grid_fill=True)
    seed = Vector((index * 3.1, index * 1.7, index * 5.3))
    strings_x = (-0.22, 0.22)
    strings_y = (-0.33, 0.33)
    for v in bm.verts:
        p = v.co.copy()
        # A rounded box: corners eased, sides a little full.
        q = Vector((p.x * hx, p.y * hy, p.z * hz + hz))
        bulge = (1.0 - p.x * p.x) * (1.0 - p.z * p.z)
        q.x += math.copysign(0.012, p.x) * (1.0 - p.z * p.z) * (1.0 - p.y * p.y)
        q.z += (0.01 if p.z > 0 else -0.004) * (1.0 - p.x * p.x) * (1.0 - p.y * p.y)
        if abs(p.x) > 0.98 and abs(p.z) > 0.98:
            q.x -= math.copysign(0.03, p.x)
            q.z -= math.copysign(0.025, p.z)
        if abs(p.y) > 0.98 and (abs(p.x) > 0.98 or abs(p.z) > 0.98):
            q.y -= math.copysign(0.025, p.y)
        # Lumps: loose flakes, more at the cut ends.
        n = noise.noise(q * 9.0 + seed)
        n2 = noise.noise(q * 23.0 + seed * 2.0)
        out = Vector((math.copysign(1, p.x) if abs(p.x) > 0.98 else 0, math.copysign(1, p.y) if abs(p.y) > 0.98 else 0, math.copysign(1, p.z) if abs(p.z) > 0.98 else 0))
        if out.length > 0:
            out.normalize()
        amp = 0.018 if abs(p.y) > 0.98 else 0.009
        q += out * (n * amp + n2 * 0.004)
        # Grooves where the strings pull in.
        for sx in strings_x:
            if abs(q.x - sx) < 0.05 and abs(p.x) < 0.99:
                q -= out * 0.014 * (1.0 - abs(q.x - sx) / 0.05)
        for sy in strings_y:
            if abs(q.y - sy) < 0.05 and abs(p.y) < 0.99:
                q -= out * 0.014 * (1.0 - abs(q.y - sy) / 0.05)
        v.co = q
    body = mesh_object("Body", bm, straw)
    smooth(body, 60)
    parts = [body]
    # The strings: two along over the ends, two across round the middle.
    def loop(points, name):
        pts = [Vector(p) for p in points]
        rings = []
        for i, p in enumerate(pts):
            a = pts[i - 1]
            b = pts[(i + 1) % len(pts)]
            t = (b - a).normalized()
            side = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
            up = side.cross(t).normalized()
            rings.append([p + side * 0.005, p + up * 0.005, p - side * 0.005, p - up * 0.005])
        rings.append(rings[0])
        return loft(name, rings, twine, caps=False)
    e = 0.004
    for sx in strings_x:
        path = []
        for y, z in fillet([(-hy - e, -e, 0.04), (hy + e, -e, 0.04), (hy + e, 2 * hz + e, 0.04), (-hy - e, 2 * hz + e, 0.04)], 3):
            path.append((sx, y, z))
        parts.append(loop(path, "TwineLong"))
    for sy in strings_y:
        path = []
        for x, z in fillet([(-hx - e - 0.012, -e, 0.05), (hx + e + 0.012, -e, 0.05), (hx + e + 0.012, 2 * hz + e + 0.01, 0.05), (-hx - e - 0.012, 2 * hz + e + 0.01, 0.05)], 3):
            path.append((x, sy, z))
        parts.append(loop(path, "TwineCross"))
    # Loose ends of the knots on top.
    for sx in strings_x:
        a = Vector((sx, rnd.uniform(-0.2, 0.2), 2 * hz + 0.005))
        parts.append(loop([a, a + Vector((0.03, 0.06, 0.01)), a + Vector((0.07, 0.04, 0.008))], "Knot"))
    # Straws: thin pointed slivers standing out, most of them along the bale, a fan at the ends.
    sm = bmesh.new()
    colours = sm.loops.layers.color.new("Col")
    tones = [(1.0, 0.95, 0.82), (0.93, 0.86, 0.66), (0.84, 0.74, 0.52), (1.0, 1.0, 0.92), (0.72, 0.64, 0.46)]
    count = 0
    for k in range(1100):
        face = rnd.random()
        if face < 0.36:  # the cut ends: brushy
            sy = rnd.choice((-1, 1))
            base = Vector((rnd.uniform(-hx + 0.03, hx - 0.03), sy * (hy - 0.01), rnd.uniform(0.04, 2 * hz - 0.03)))
            d = Vector((rnd.gauss(0, 0.6), sy * 1.0, rnd.gauss(0, 0.6)))
            length = rnd.uniform(0.04, 0.16)
        elif face < 0.6:  # the top
            base = Vector((rnd.uniform(-hx + 0.02, hx - 0.02), rnd.uniform(-hy + 0.02, hy - 0.02), 2 * hz - 0.005))
            d = Vector((rnd.gauss(0, 0.35), rnd.choice((-1, 1)) * 1.0, rnd.uniform(0.04, 0.3)))
            length = rnd.uniform(0.06, 0.16)
        else:  # the long sides
            sx = rnd.choice((-1, 1))
            base = Vector((sx * (hx + 0.005), rnd.uniform(-hy + 0.02, hy - 0.02), rnd.uniform(0.04, 2 * hz - 0.04)))
            d = Vector((sx * rnd.uniform(0.04, 0.32), rnd.choice((-1, 1)) * 1.0, rnd.gauss(0, 0.3)))
            length = rnd.uniform(0.06, 0.16)
        d.normalize()
        start = base - d * 0.05
        tip = base + d * length
        w = rnd.uniform(0.0025, 0.0045)
        side = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        up = side.cross(d).normalized()
        a = sm.verts.new(start + side * w)
        b = sm.verts.new(start - side * w * 0.5 + up * w * 0.86)
        c = sm.verts.new(start - side * w * 0.5 - up * w * 0.86)
        t = sm.verts.new(tip)
        tone = tones[rnd.randrange(len(tones))]
        for f in ((a, b, t), (b, c, t), (c, a, t)):
            face_made = sm.faces.new(f)
            for loop_ in face_made.loops:
                loop_[colours] = (*tone, 1.0)
        count += 1
    strands = mesh_object("Straws", sm, mat("Strands", "e0c070", 0.8))
    parts.append(strands)
    # The body and the strings get plain white colours, so that only the strands vary.
    for o in parts:
        if o is strands:
            continue
        me = o.data
        layer = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for d_ in layer.data:
            d_.color = (1.0, 1.0, 1.0, 1.0)
    bale = join(parts, "Bale%d" % index)
    bale.location.x = (index - 1) * 1.4
    return bale


# ------------------------------------------------------------------ review pictures and export
def export(objs, path, colours=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    extra = {}
    if colours:
        extra = {"export_vertex_color": "ACTIVE"}
    try:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_normals=True,
                                  export_materials="EXPORT", export_animations=False, export_apply=True, **extra)
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_normals=True,
                                  export_materials="EXPORT", export_animations=False, export_apply=True, export_colors=True)
    print("EXPORTED", path, os.path.getsize(path), "bytes")


def render(obj_name, folder, views):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    use_gpu(scene)
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 760
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    scene.world = world
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.37, 0.4, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    cam = link(bpy.data.objects.new("cam", bpy.data.cameras.new("cam")))
    scene.camera = cam
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0, 0, 0))
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.08, 0.09, 1.0)
    floor.data.materials.append(fm)
    made = [light("key", "AREA", (-6, 6, 7), (0, 0, 1), 1800.0, (1.0, 0.96, 0.9), 4.0),
            light("fill", "AREA", (7, -3, 3), (0, 0, 1), 600.0, (0.8, 0.88, 1.0), 4.0)]
    for name, pos, target, lens in views:
        cam.data.lens = lens
        look_from(cam, pos, target)
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (obj_name.lower(), name))
        bpy.ops.render.render(write_still=True)
    for o in made + [floor, cam]:
        bpy.data.objects.remove(o, do_unlink=True)


VIEWS = {
    "Bus": [("front", (-7.5, 11.0, 2.6), (0, 2.0, 1.5), 32), ("left", (-12.0, 0.5, 2.0), (0, 0.5, 1.6), 32), ("rear", (7.0, -10.5, 3.5), (0, -2, 1.5), 32), ("nose", (-2.6, 8.2, 1.7), (0, 5.3, 1.6), 30)],
    "Sedan": [("front", (-4.2, 5.4, 1.7), (0, 0.3, 0.7), 35), ("side", (-7.0, 0, 1.2), (0, 0, 0.7), 35), ("rear", (3.8, -5.2, 1.8), (0, 0, 0.7), 35)],
    "Jdm": [("front", (-4.0, 5.2, 1.5), (0, 0.3, 0.6), 35), ("side", (-7.0, 0, 1.0), (0, 0, 0.6), 35), ("rear", (3.8, -5.0, 1.7), (0, 0, 0.6), 35), ("door", (-3.4, 0.3, 0.8), (0, -0.2, 0.6), 40)],
    "Hay": [("all", (-2.6, 3.0, 1.6), (0, 0, 0.36), 35), ("near", (-0.9, 1.3, 0.85), (0, 0.2, 0.4), 40)],
}

OUTS = {
    "bus": ("Bus", build_bus, "assets/tokyo/vehicles/bus.glb"),
    "sedan": ("Sedan", build_sedan, "assets/tokyo/vehicles/sedan.glb"),
    "jdm": ("Jdm", build_jdm, "assets/tokyo/vehicles/jdm.glb"),
}


def main():
    for key in ONLY:
        clear()
        MATS.clear()
        PARTS.clear()
        global FONT
        FONT = None
        if key == "hay":
            bales = [build_bale(i) for i in range(3)]
            print("TRIANGLES hay", [triangles(b) for b in bales])
            if RENDER:
                render("Hay", RENDER, VIEWS["Hay"])
            for b in bales:
                b.location.x = 0.0
            if not NOEXPORT:
                export(bales, os.path.join(ROOT, "assets/models/hay_bale.glb"), colours=True)
            continue
        name, build, out = OUTS[key]
        build()
        obj = join(list(PARTS), name)
        print("TRIANGLES", name, triangles(obj), "materials", [s.name for s in obj.data.materials])
        if RENDER:
            render(name, RENDER, VIEWS[name])
        if not NOEXPORT:
            export([obj], os.path.join(ROOT, out))


main()
