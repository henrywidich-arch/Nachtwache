# Builds the handguns of Nachtwache from nothing: the M9 pistol, the USP .45, the G18
# Automatik, the Desert Eagle and the .44 Magnum revolver. Every part is made here,
# bevelled, given a procedural material and baked into one texture set (tools/blender_gunkit.py).
#
#   blender --background --factory-startup --python tools/blender_make_pistols.py -- --gun usp [--round 4] [--tex 2048]
#           [--out assets/models/usp_built.glb] [--render <folder>] [--only schraeg,links] [--nobake] [--cpu]
#
# --round: how far the polish goes (1: the forms, 2: the working parts, 3: the small parts,
# markings and wear, 4: the last details after the review pictures). The game uses round 4.
#
# All five share one frame (the one of the M9 model they replace): the origin is where the
# hand holds the grip, the bore about 8 cm above it. weapon_view.gd mounts them at
# Vector3(0, -0.075, 0.076); the places it needs in view space are printed at the end (SPEC).
import bpy, sys, os, math
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import blender_gunkit as kit
from blender_gunkit import box, cylinder, prism, side_plate, loft, sweep, bevel_object, cut, cut_many, union, rotate, move, smooth, engrave, material, rounded_rect

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


GUN = arg("--gun", "usp")
ROUND = int(arg("--round", "4"))
TEX = int(arg("--tex", "2048"))
NOBAKE = "--nobake" in ARGV
kit.ROUND = ROUND
kit.GPU = "--cpu" not in ARGV
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", GUN + "_built.glb")))
RENDER = arg("--render")
MOUNT = Vector((0.0, -0.075, 0.076))


def view(p):
    """A point of the model in the weapon view (Godot space, mounted at MOUNT)."""
    return Vector((p[0], p[2] + MOUNT.y, MOUNT.z - p[1]))


def vec3(p):
    return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.y, p.z)


# ------------------------------------------------------------------ the guns' measures
# slide: back and face (y), bottom and top (z), half width; frame: the dust cover's front and
# bottom; grip: its top and foot (z, before it is tilted), front and back (y), half width,
# tilt (degrees, the foot towards the back); guard: its front (y) and bottom (z); irons: the
# top of the front sight.
SPECS = {
    "pistol": {"slide": (-0.031, 0.166, 0.064, 0.094, 0.0145), "profile": "round", "bore": 0.080, "barrel_r": 0.0068, "muzzle": 0.172,
               "frame": (0.150, 0.045), "frame_w": 0.0135, "grip": (0.046, -0.036, 0.028, -0.031, 0.0158, 16.0),
               "guard": (0.083, 0.016, 0.016), "trigger": 0.036, "irons": 0.1018, "hammer": True, "open_top": True,
               "label": ("M9   9mm NATO", "U.S. 9mm M9-A1  1987"), "root": "Pistol"},
    "usp": {"slide": (-0.034, 0.170, 0.064, 0.095, 0.0152), "profile": "usp", "bore": 0.080, "barrel_r": 0.0074, "muzzle": 0.171,
            "frame": (0.158, 0.044), "frame_w": 0.0145, "grip": (0.046, -0.040, 0.030, -0.033, 0.0162, 17.0),
            "guard": (0.088, 0.015, 0.009), "trigger": 0.037, "irons": 0.1025, "hammer": True, "rail": "grooves",
            "label": ("USP   .45 AUTO", "MADE 2026   NACHTWACHE"), "root": "USP"},
    "g18": {"slide": (-0.030, 0.158, 0.065, 0.094, 0.0128), "profile": "box", "bore": 0.081, "barrel_r": 0.0066, "muzzle": 0.159,
            "frame": (0.150, 0.045), "frame_w": 0.0135, "grip": (0.046, -0.040, 0.029, -0.032, 0.0152, 20.0),
            "guard": (0.084, 0.016, 0.006), "trigger": 0.036, "irons": 0.1012, "hammer": False, "rail": "slot", "extended": True,
            "comp": True, "selector": True, "label": ("18   AUTOMATIK", "9x19"), "root": "G18"},
}


def make_materials():
    late = ROUND >= 3
    wear = 1.0 if ROUND >= 3 else 0.0
    m = {}
    if GUN == "pistol":
        m["slide"] = material("slide", (0.034, 0.035, 0.037), 0.5, 0.65, wear=wear, grime=0.6, bump=0.06 if late else 0.0, worn=(0.42, 0.42, 0.41), scratches=0.7)
        m["frame"] = material("frame", (0.03, 0.031, 0.034), 0.55, 0.55, wear=wear * 0.8, grime=0.6, worn=(0.38, 0.38, 0.38), scratches=0.5)
        m["grip"] = material("grip", (0.022, 0.022, 0.023), 0.75, 0.0, wear=0.2 * wear, grime=0.8, bump=0.0 if ROUND == 1 else 0.7, bump_scale=420.0, pattern="checker", worn=(0.12, 0.12, 0.12))
        m["barrel"] = material("barrel", (0.07, 0.072, 0.075), 0.32, 0.9, wear=wear * 0.5, grime=0.4, worn=(0.5, 0.5, 0.49))
    elif GUN == "usp":
        m["slide"] = material("slide", (0.04, 0.041, 0.043), 0.48, 0.7, wear=wear, grime=0.6, bump=0.05 if late else 0.0, worn=(0.45, 0.45, 0.44), scratches=0.8)
        m["frame"] = material("frame", (0.028, 0.029, 0.027), 0.68, 0.0, wear=0.4 * wear, grime=0.8, worn=(0.16, 0.16, 0.15), scratches=0.5)
        m["grip"] = material("grip", (0.026, 0.027, 0.025), 0.82, 0.0, wear=0.3 * wear, grime=0.9, bump=0.0 if ROUND == 1 else 0.9, bump_scale=1800.0, pattern="stipple", worn=(0.15, 0.15, 0.14))
        m["barrel"] = material("barrel", (0.06, 0.062, 0.066), 0.36, 0.9, wear=wear * 0.5, grime=0.4)
    elif GUN == "g18":
        m["slide"] = material("slide", (0.045, 0.046, 0.048), 0.52, 0.65, wear=wear, grime=0.6, bump=0.05 if late else 0.0, worn=(0.46, 0.46, 0.45), scratches=0.8)
        m["frame"] = material("frame", (0.032, 0.033, 0.031), 0.7, 0.0, wear=0.4 * wear, grime=0.8, worn=(0.17, 0.17, 0.16), scratches=0.5)
        m["grip"] = material("grip", (0.03, 0.031, 0.029), 0.85, 0.0, wear=0.3 * wear, grime=0.9, bump=0.0 if ROUND == 1 else 0.8, bump_scale=1100.0, pattern="stipple", worn=(0.16, 0.16, 0.15))
        m["barrel"] = material("barrel", (0.05, 0.052, 0.055), 0.4, 0.9, wear=wear * 0.5, grime=0.4)
    elif GUN == "deagle":
        m["slide"] = material("slide", (0.5, 0.505, 0.51), 0.3, 1.0, wear=0.0, grime=0.5, bump=0.0 if ROUND == 1 else 0.12, bump_scale=700.0, worn=(0.7, 0.7, 0.7), scratches=0.6)
        m["frame"] = material("frame", (0.42, 0.425, 0.43), 0.36, 1.0, wear=0.0, grime=0.6, bump=0.0 if ROUND == 1 else 0.1, bump_scale=700.0, worn=(0.62, 0.62, 0.62), scratches=0.6)
        m["grip"] = material("grip", (0.024, 0.024, 0.024), 0.85, 0.0, wear=0.2 * wear, grime=0.9, bump=0.0 if ROUND == 1 else 0.9, bump_scale=900.0, pattern="stipple", worn=(0.13, 0.13, 0.13))
        m["barrel"] = material("barrel", (0.2, 0.2, 0.205), 0.35, 1.0, grime=0.5)
    else:
        m["slide"] = material("slide", (0.022, 0.025, 0.033), 0.28, 0.9, wear=wear, grime=0.6, bump=0.04 if late else 0.0, worn=(0.5, 0.5, 0.5), scratches=0.7)
        m["frame"] = m["slide"]
        m["grip"] = material("grip", (0.2, 0.085, 0.035), 0.5, 0.0, wear=0.3 * wear, grime=0.6, bump=0.0 if ROUND == 1 else 0.25, bump_scale=300.0, pattern="checker" if ROUND >= 4 else "brushed",
                             worn=(0.34, 0.18, 0.09), grain=(0.13, 0.054, 0.022), spread=0.06)
        m["barrel"] = m["slide"]
    m["dark"] = material("dark", (0.008, 0.008, 0.008), 0.8, 0.3)
    m["steel"] = material("steel", (0.1, 0.102, 0.105), 0.38, 0.9, wear=wear * 0.6, grime=0.5, worn=(0.52, 0.52, 0.5))
    m["black"] = material("black", (0.025, 0.025, 0.026), 0.55, 0.5, wear=wear * 0.7, grime=0.5, worn=(0.36, 0.36, 0.35))
    m["marking"] = material("marking", (0.2, 0.2, 0.19), 0.55, 0.6) if ROUND >= 3 else m["slide"]
    m["white"] = material("white", (0.75, 0.74, 0.7), 0.6, 0.0) if ROUND >= 3 else m["black"]
    m["red"] = material("red", (0.5, 0.04, 0.03), 0.55, 0.0) if ROUND >= 3 else m["black"]
    m["brass"] = material("brass", (0.5, 0.36, 0.14), 0.32, 1.0, grime=0.4) if ROUND >= 3 else m["steel"]
    return m


# ------------------------------------------------------------------ shared pieces
def slide_profile(style, w, z0, z1):
    """The slide's cross-section ((x, z) points, counter-clockwise from the front)."""
    pts = []
    if style == "round":
        r = 0.0075
        pts = [(-w, z0), (w, z0), (w, z1 - r)]
        for i in range(1, 7):
            a = math.radians(90.0 * i / 6)
            pts.append((w - r + r * math.cos(a), z1 - r + r * math.sin(a)))
        for i in range(0, 7):
            a = math.radians(90.0 + 90.0 * i / 6)
            pts.append((-w + r + r * math.cos(a), z1 - r + r * math.sin(a)))
    elif style == "usp":
        # Straight lower sides, then drawn in towards a rounded top.
        r = 0.006
        k = z0 + 0.015
        t = w - 0.0022
        pts = [(-w, z0), (w, z0), (w, k), (t, z1 - r)]
        for i in range(1, 6):
            a = math.radians(90.0 * i / 5)
            pts.append((t - r + r * math.cos(a), z1 - r + r * math.sin(a)))
        for i in range(0, 6):
            a = math.radians(90.0 + 90.0 * i / 5)
            pts.append((-t + r + r * math.cos(a), z1 - r + r * math.sin(a)))
        pts.append((-w, k))
    else:
        c = 0.0022
        pts = [(-w, z0), (w, z0), (w, z1 - c), (w - c, z1), (-w + c, z1), (-w, z1 - c)]
    return pts


def grip_body(name, mat, top, foot, front, back, half, grooves=0, swell=0.0016, hump=0.003):
    """A grip from its foot up to its top (before it is tilted): a front strap (with finger
    grooves if asked), a back strap that swells into the palm, rounded sides."""
    levels = [foot, foot + 0.0012, foot + 0.003]
    n = 28
    for i in range(1, n + 1):
        levels.append(foot + 0.003 + (top - foot - 0.003) * i / n)
    rings = []
    for z in levels:
        t = (z - foot) / (top - foot)
        f = front
        if grooves:
            g0, g1 = foot + 0.012, top - 0.026
            if g0 < z < g1:
                f -= 0.0024 * (0.5 - 0.5 * math.cos(math.tau * grooves * (z - g0) / (g1 - g0)))
        b = back - swell * math.sin(math.pi * min(1.0, max(0.0, (t - 0.1) / 0.8)))
        b -= hump * max(0.0, math.sin(math.pi * min(1.0, max(0.0, (t - 0.72) / 0.28))))
        h = half + 0.0012 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.08) / 0.84)))
        if z < foot + 0.003:
            k = (z - foot) / 0.003
            s = 0.86 + 0.14 * math.sqrt(max(0.0, k))
            mid = (f + b) * 0.5
            h *= s
            f = mid + (f - mid) * s
            b = mid + (b - mid) * s
        mid = (f + b) * 0.5
        ring = []
        for i in range(36):
            a = math.tau * i / 36
            c, s_ = math.cos(a), math.sin(a)
            cs = math.copysign(abs(c) ** 0.5, c)
            ss = math.copysign(abs(s_) ** 0.45, s_)
            y = mid + cs * ((f - mid) if c > 0.0 else (mid - b))
            x = ss * (h - 0.0016 * max(0.0, c) ** 2)
            ring.append((x, y, z))
        rings.append(ring)
    return loft(name, rings, mat)


def guard_path(back, front, frame_z, bottom, r):
    """The trigger guard's path (y, z): out of the grip's front, along the bottom, round its
    front corner (radius r) and up into the frame."""
    path = [(back, frame_z + 0.002), (back + 0.002, bottom + 0.012), (back + 0.008, bottom + 0.002), (back + 0.018, bottom)]
    path.append((front - r - 0.002, bottom))
    for i in range(1, 9):
        a = -math.pi / 2 + (math.pi / 2) * i / 8
        path.append((front - r + r * math.cos(a), bottom + r + r * math.sin(a)))
    path += [(front + 0.001, frame_z - 0.004), (front + 0.0015, frame_z + 0.002)]
    return path


def curved_trigger(y, top, bottom, mat, width=0.0048):
    bend = []
    for i in range(9):
        k = i / 8
        p0, p1, p2 = (y - 0.001, top), (y - 0.002, (top + bottom) * 0.5), (y + 0.004, bottom)
        bend.append(((1 - k) ** 2 * p0[0] + 2 * (1 - k) * k * p1[0] + k * k * p2[0], (1 - k) ** 2 * p0[1] + 2 * (1 - k) * k * p1[1] + k * k * p2[1]))
    trig = sweep("Trigger", bend, 0.0029, width, mat)
    smooth(trig, 50)
    return trig


def tilt_all(objs, angle, pivot):
    for o in objs:
        rotate(o, angle, "X", pivot)


# ------------------------------------------------------------------ semi-automatic pistols
def build_auto(s, m):
    parts = []
    y0, y1, z0, z1, w = s["slide"]
    bore = s["bore"]
    late = ROUND >= 3
    # --- slide
    slide = prism("Slide", slide_profile(s["profile"], w, z0, z1), y0, y1, m["slide"])
    if s.get("open_top"):
        # The M9's open top: the slide's top is cut away from the port to the front ring,
        # the barrel lies bare in it.
        cutters = [box("open", (-0.03, 0.006, z1 - 0.0085), (0.03, y1 - 0.016, z1 + 0.01), m["slide"])]
        # The front ring's top is drawn down in a curve.
        ring = box("ringtop", (-0.03, y1 - 0.016, z1 - 0.0035), (0.03, y1 + 0.01, z1 + 0.01), m["slide"])
        rotate(ring, math.radians(4.0), "X", Vector((0, y1 - 0.016, z1 - 0.0035)))
        cutters.append(ring)
        if ROUND >= 3:
            # Its sides are drawn down before the front ring: the barrel shows from the side.
            scallop = box("scallop", (-0.03, 0.042, bore - 0.001), (0.03, y1 - 0.02, z1 + 0.01), m["slide"], bevel=0.003, segments=3)
            rotate(scallop, math.radians(1.5), "X", Vector((0, 0.042, bore - 0.001)))
            cutters.append(scallop)
        cut_many(slide, cutters)
    else:
        # Ejection port on the right.
        port = box("port", (0.0, 0.004, bore - 0.0025), (0.03, 0.046, z1 + 0.01), m["slide"])
        cut(slide, port)
        hood = box("Hood", (-0.0078, 0.003, bore - 0.004), (0.0078, 0.047, z1 - 0.0012), m["barrel"], bevel=0.001)
        parts.append(hood)
    # Muzzle face: a bore through the slide's front for the barrel.
    hole = cylinder("hole", (0, y1 - 0.02, bore), (0, y1 + 0.02, bore), s["barrel_r"] + 0.0006, m["slide"], 28)
    cut(slide, hole)
    if ROUND >= 2:
        # Serrations at the back of the slide, on both sides.
        grooves = []
        count = 9 if s["profile"] != "round" else 10
        for i in range(count):
            y = y0 + 0.006 + i * 0.0026
            g = box("g", (-0.03, y, z0 + 0.005), (0.03, y + 0.0012, z1 - (0.004 if s["profile"] != "box" else 0.0025)), m["slide"])
            grooves.append(g)
        cut_many(slide, grooves)
        # The nose drawn in underneath (a dehorned front).
        nose = box("nose", (-0.03, y1 - 0.01, z0 - 0.01), (0.03, y1 + 0.01, z0 + 0.004), m["slide"])
        rotate(nose, math.radians(-22.0), "X", Vector((0, y1 - 0.01, z0 + 0.004)))
        cut(slide, nose)
    if s.get("comp") and ROUND >= 2:
        # G18: compensator cuts in the top of the slide over the ported barrel.
        cuts = []
        for i in range(2):
            y = y1 - 0.034 + i * 0.013
            cuts.append(box("c", (-0.0042, y, z1 - 0.006), (0.0042, y + 0.008, z1 + 0.01), m["slide"], bevel=0.0012))
        cut_many(slide, cuts)
    bevel_object(slide, 0.0007, 2, 30.0)
    smooth(slide, 35)
    parts.append(slide)
    # --- barrel and bore
    barrel = cylinder("Barrel", (0, -0.006, bore), (0, s["muzzle"], bore), s["barrel_r"], m["barrel"], 32, bevel=0.0006 if ROUND >= 2 else 0.0)
    smooth(barrel, 40)
    parts.append(barrel)
    if s.get("open_top"):
        # The locking block's lugs and the chamber under the open top.
        chamber = box("Chamber", (-0.0088, -0.004, bore - 0.005), (0.0088, 0.022, bore + 0.0072), m["barrel"], bevel=0.0018, segments=3)
        smooth(chamber, 40)
        parts.append(chamber)
    if s.get("comp"):
        # The ports in the barrel under the cuts.
        ports = []
        for i in range(2):
            y = y1 - 0.033 + i * 0.013
            ports.append(box("bp", (-0.0024, y, bore), (0.0024, y + 0.006, bore + 0.02), m["barrel"], bevel=0.0008))
        cut_many(barrel, ports)
    inside = cylinder("Bore", (0, s["muzzle"] - 0.03, bore), (0, s["muzzle"] + 0.0004, bore), s["barrel_r"] * 0.62, m["dark"], 18)
    parts.append(inside)
    # --- frame: one side outline, across its width
    fw = s["frame_w"]
    fy, fz = s["frame"]
    g_top, g_foot, g_front, g_back, g_half, g_tilt = s["grip"]
    gf, gb_ = s["guard"][0], s["guard"][1]
    outline = [(y0 - 0.006, 0.048), (y0 - 0.002, z0), (fy - 0.003, z0), (fy, z0 - 0.003), (fy, fz + 0.003), (fy - 0.004, fz),
               (gf + 0.001, fz), (g_front - 0.008, fz), (g_front - 0.006, 0.034), (g_back + 0.004, 0.034), (y0 - 0.008, 0.042)]
    frame = side_plate("Frame", outline, -fw, fw, m["frame"])
    if s.get("rail") == "grooves" and ROUND >= 2:
        # USP: a groove along each side of the dust cover for a light.
        cutters = []
        for side in (-1.0, 1.0):
            cutters.append(box("rg", (side * fw - 0.002, 0.096, fz + 0.0045), (side * fw + 0.002, fy + 0.01, fz + 0.0082), m["frame"]))
        cut_many(frame, cutters)
    if s.get("rail") == "slot" and ROUND >= 2:
        cutters = []
        for side in (-1.0, 1.0):
            cutters.append(box("rg", (side * fw - 0.0018, 0.098, fz + 0.004), (side * fw + 0.002, fy + 0.01, fz + 0.0072), m["frame"]))
        cutters.append(box("slot", (-0.03, 0.118, fz - 0.01), (0.03, 0.123, fz + 0.0022), m["frame"]))
        cut_many(frame, cutters)
    bevel_object(frame, 0.0018 if s["profile"] != "round" else 0.0014, 3, 40.0)
    smooth(frame, 40)
    parts.append(frame)
    # --- grip
    pivot = Vector((0, 0, 0.040))
    tilt = math.radians(-g_tilt)
    grip_parts = []
    if GUN == "pistol":
        # The M9's grip: the frame's narrow strap all round, panels on both sides.
        core = grip_body("GripFrame", m["frame"], g_top, g_foot, g_front, g_back, g_half - 0.0028, swell=0.0012, hump=0.002)
        smooth(core, 40)
        grip_parts.append(core)
        if ROUND >= 1:
            for side in (-1.0, 1.0):
                pts = rounded_rect((g_front + g_back) * 0.5 + 0.0005, (g_top + g_foot) * 0.5 - 0.004, (g_front - g_back) * 0.5 - 0.0035, (g_top - g_foot) * 0.5 - 0.009, 0.006)
                panel = side_plate("Panel", [(y, z) for y, z in pts], side * (g_half - 0.0045), side * (g_half + 0.0006), m["grip"])
                bevel_object(panel, 0.0014, 3, 30.0)
                smooth(panel, 40)
                grip_parts.append(panel)
                if ROUND >= 3:
                    sc = cylinder("Screw", (side * (g_half + 0.0002), -0.004, g_foot + 0.016), (side * (g_half + 0.0016), -0.004, g_foot + 0.016), 0.0026, m["steel"], 16, bevel=0.0004)
                    grip_parts.append(sc)
                    sc2 = cylinder("Screw", (side * (g_half + 0.0002), 0.000, g_top - 0.014), (side * (g_half + 0.0016), 0.000, g_top - 0.014), 0.0026, m["steel"], 16, bevel=0.0004)
                    grip_parts.append(sc2)
    else:
        g = grip_body("Grip", m["grip"], g_top, g_foot, g_front, g_back, g_half, grooves=3 if GUN == "g18" else 0)
        if ROUND >= 3:
            # A smooth border round the stippled field on each side.
            pass
        smooth(g, 40)
        grip_parts.append(g)
    # magazine base plate at the foot
    mid = (g_front + g_back) * 0.5
    if s.get("extended"):
        # G18: the long 33-round magazine stands well below the grip.
        mag = box("MagBody", (-0.0105, mid - 0.0175, g_foot - 0.052), (0.0105, mid + 0.0165, g_foot + 0.004), m["black"], bevel=0.0022, segments=3)
        if ROUND >= 2:
            holes = [cylinder("w", (-0.02, mid - 0.009, g_foot - 0.012 - i * 0.009), (0.02, mid - 0.009, g_foot - 0.012 - i * 0.009), 0.0016, m["black"], 12) for i in range(4)]
            cut_many(mag, holes)
        smooth(mag, 35)
        grip_parts.append(mag)
        plate = box("MagPlate", (-0.0122, mid - 0.0195, g_foot - 0.058), (0.0122, mid + 0.019, g_foot - 0.049), m["frame"], bevel=0.003, segments=3)
    else:
        plate = box("MagPlate", (-g_half + 0.0012, mid - (g_front - g_back) * 0.5 - 0.001, g_foot - 0.004), (g_half - 0.0012, mid + (g_front - g_back) * 0.5 - 0.002, g_foot + 0.0015), m["black"], bevel=0.0018, segments=3)
    smooth(plate, 40)
    grip_parts.append(plate)
    tilt_all(grip_parts, tilt, pivot)
    parts += grip_parts
    # --- beavertail / tang behind the slide
    tang = box("Tang", (-fw + 0.0012, y0 - 0.012, z0 - 0.016), (fw - 0.0012, y0 + 0.004, z0 - 0.002), m["frame"], bevel=0.004, segments=3)
    rotate(tang, math.radians(-10.0), "X", Vector((0, y0, z0 - 0.008)))
    smooth(tang, 40)
    parts.append(tang)
    # --- trigger guard and trigger
    path = guard_path(g_front - 0.006, gf, fz, gb_, s["guard"][2] if s["guard"][2] > 0.006 else 0.006)
    guard = sweep("Guard", path, 0.0052, 0.0062, m["frame"])
    smooth(guard, 50)
    parts.append(guard)
    if ROUND >= 2 and s["guard"][2] <= 0.009:
        # A squared guard with a hook at its front for the other hand's finger.
        hook = box("Hook", (-0.0048, gf - 0.006, gb_ - 0.0005), (0.0048, gf + 0.0035, gb_ + 0.012), m["frame"], bevel=0.0018, segments=2)
        smooth(hook, 40)
        parts.append(hook)
    parts.append(curved_trigger(s["trigger"], fz + 0.002, gb_ + 0.008, m["black"]))
    # --- sights
    rear = box("Rear", (-0.0078, y0 + 0.004, z1 - 0.001), (0.0078, y0 + 0.013, z1 + 0.0072), m["black"], bevel=0.0009)
    notch = box("notch", (-0.0017, y0, z1 + 0.0028), (0.0017, y0 + 0.02, z1 + 0.02), m["black"])
    cut(rear, notch)
    parts.append(rear)
    front_y = y1 - 0.013
    front_base = z1 - 0.004 if s.get("open_top") else z1 - 0.001
    front = box("Front", (-0.0016, front_y, front_base), (0.0016, front_y + 0.0085, s["irons"]), m["black"], bevel=0.0006)
    parts.append(front)
    if ROUND >= 3:
        for x, y, z in ((0.0, front_y + 0.0089, s["irons"] - 0.0025), (-0.0049, y0 + 0.0132, z1 + 0.0042), (0.0049, y0 + 0.0132, z1 + 0.0042)):
            dot = cylinder("Dot", (x, y - 0.0004, z), (x, y + 0.0002, z), 0.0011, m["white"], 12)
            parts.append(dot)
    # --- hammer or striker
    if s.get("hammer"):
        hy = y0 - 0.001
        outline = [(hy + 0.002, z0 - 0.004), (hy + 0.002, z1 - 0.004), (hy - 0.004, z1 + 0.003), (hy - 0.012, z1 + 0.002), (hy - 0.013, z1 - 0.004), (hy - 0.007, z1 - 0.009), (hy - 0.006, z0 - 0.004)]
        hammer = side_plate("Hammer", outline, -0.0036, 0.0036, m["black"])
        if ROUND >= 2:
            ringh = cylinder("hr", (-0.01, hy - 0.006, z1 - 0.003), (0.01, hy - 0.006, z1 - 0.003), 0.0024, m["black"], 16)
            cut(hammer, ringh)
        bevel_object(hammer, 0.0008, 2, 30.0)
        smooth(hammer, 40)
        parts.append(hammer)
    if s.get("selector") and ROUND >= 2:
        # G18: the fire selector on the left of the slide's back.
        sel = box("Selector", (-w - 0.0028, y0 + 0.014, z1 - 0.012), (-w + 0.001, y0 + 0.022, z1 - 0.004), m["black"], bevel=0.0009)
        rotate(sel, math.radians(-18.0), "Y", Vector((-w, y0 + 0.018, z1 - 0.008)))
        parts.append(sel)
    # --- controls
    if ROUND >= 2:
        if GUN == "pistol":
            # Safety-decocker levers on both sides of the slide's back.
            for side in (-1.0, 1.0):
                hub = cylinder("Safety", (side * (w - 0.001), y0 + 0.012, z1 - 0.008), (side * (w + 0.0022), y0 + 0.012, z1 - 0.008), 0.0042, m["black"], 20, bevel=0.0006)
                lever = box("Lever", (min(side * (w + 0.0005), side * (w + 0.003)), y0 + 0.012, z1 - 0.0105), (max(side * (w + 0.0005), side * (w + 0.003)), y0 + 0.028, z1 - 0.0055), m["black"], bevel=0.001)
                rotate(lever, math.radians(-8.0), "X", Vector((0, y0 + 0.012, z1 - 0.008)))
                parts += [hub, lever]
        elif GUN == "usp":
            # The control lever on the left of the frame, behind the grip's top.
            lever = box("Lever", (-fw - 0.0026, y0 + 0.004, z0 - 0.012), (-fw + 0.001, y0 + 0.022, z0 - 0.004), m["black"], bevel=0.0012)
            rotate(lever, math.radians(-12.0), "X", Vector((0, y0 + 0.008, z0 - 0.008)))
            parts.append(lever)
        # Slide stop on the left above the trigger, mag release behind the guard, pins.
        stop = box("Stop", (-fw - 0.0018, 0.008, z0 - 0.007), (-fw + 0.001, 0.034, z0 - 0.0015), m["black"], bevel=0.0008)
        parts.append(stop)
        release = box("Release", (-fw - 0.0022, g_front - 0.006, 0.030), (-fw + 0.001, g_front + 0.004, 0.038), m["black"], bevel=0.0012)
        rotate(release, math.radians(-g_tilt * 0.5), "X", Vector((0, g_front, 0.034)))
        parts.append(release)
        take = box("Take", (-fw - 0.0014, 0.048, z0 - 0.012), (fw + 0.0014, 0.056, z0 - 0.006), m["black"], bevel=0.0008)
        parts.append(take)
        for y, z in ((0.03, fz + 0.005), (-0.012, fz + 0.012), (0.062, fz + 0.006)):
            parts.append(cylinder("Pin", (-fw - 0.0004, y, z), (fw + 0.0004, y, z), 0.0016, m["steel"], 14))
        if not s.get("open_top"):
            ext = box("Extractor", (w - 0.0005, -0.014, bore + 0.002), (w + 0.0008, 0.004, bore + 0.0078), m["black"], bevel=0.0004)
            parts.append(ext)
    if ROUND >= 3:
        top_line, low_line = s["label"]
        # (On the M9 the letters stay below the drawn-down sides of the open top.)
        low_top = s.get("open_top", False)
        parts.append(engrave(top_line, Vector((-w - 0.00012, y1 - 0.03, z0 + (0.0095 if low_top else 0.0145))), 0.0046 if low_top else 0.0058, m["marking"]))
        parts.append(engrave(low_line, Vector((-w - 0.00012, y1 - 0.03, z0 + (0.0037 if low_top else 0.0065))), 0.003 if low_top else 0.0034, m["marking"]))
        if s.get("selector"):
            parts.append(engrave("•", Vector((-w - 0.00012, y0 + 0.024, z1 - 0.009)), 0.004, m["white"]))
            parts.append(engrave("••", Vector((-w - 0.00012, y0 + 0.012, z1 - 0.017)), 0.004, m["red"]))
        if GUN == "pistol":
            parts.append(engrave("PB  9mm", Vector((w + 0.00012, 0.040, z0 + 0.008)), 0.0034, m["marking"], side=1.0))
    return parts


# ------------------------------------------------------------------ Desert Eagle
def build_deagle(m):
    parts = []
    bore = 0.084
    w = 0.0165
    y0, ys = -0.048, 0.096    # the slide
    yb = 0.232                # the barrel's face
    z0, z1 = 0.064, 0.104
    # --- slide: tall, with an angled upper flank.
    prof = [(-w, z0), (w, z0), (w, z0 + 0.024), (w - 0.0042, z1 - 0.002), (w - 0.006, z1), (-w + 0.006, z1), (-w + 0.0042, z1 - 0.002), (-w, z0 + 0.024)]
    slide = prism("Slide", prof, y0, ys, m["slide"])
    if ROUND >= 2:
        grooves = []
        for i in range(10):
            y = y0 + 0.006 + i * 0.003
            grooves.append(box("g", (-0.03, y, z0 + 0.006), (0.03, y + 0.0014, z0 + 0.022), m["slide"]))
        cut_many(slide, grooves)
        port = box("port", (0.0, 0.026, bore - 0.004), (0.03, 0.068, z0 + 0.03), m["slide"])
        cut(slide, port)
    bevel_object(slide, 0.0008, 2, 30.0)
    smooth(slide, 35)
    parts.append(slide)
    if ROUND >= 2:
        hood = box("Bolt", (-0.009, 0.024, bore - 0.006), (0.009, 0.07, bore + 0.008), m["barrel"], bevel=0.0015)
        parts.append(hood)
    # --- barrel: a heavy block with a polygonal section, a rail on top, the bore through it.
    bw = 0.0158
    bprof = [(-bw + 0.004, 0.061), (bw - 0.004, 0.061), (bw, 0.068), (bw, 0.094), (bw - 0.006, 0.1035), (-bw + 0.006, 0.1035), (-bw, 0.094), (-bw, 0.068)]
    barrel = prism("Barrel", bprof, ys - 0.002, yb, m["slide"])
    hole = cylinder("hole", (0, yb - 0.04, bore), (0, yb + 0.01, bore), 0.0068, m["slide"], 28)
    cut(barrel, hole)
    if ROUND >= 2:
        # Flutes along the flanks, a muzzle face cut back and the rail grooves on top.
        flutes = []
        for side in (-1.0, 1.0):
            flutes.append(box("fl", (side * bw - 0.0012, ys + 0.02, 0.074), (side * bw + 0.002, yb - 0.012, 0.086), m["slide"], bevel=0.0009))
        cut_many(barrel, flutes)
    bevel_object(barrel, 0.0009, 2, 30.0)
    smooth(barrel, 35)
    parts.append(barrel)
    rail = box("Rail", (-0.0078, ys + 0.004, 0.1032), (0.0078, yb - 0.006, 0.1095), m["slide"], bevel=0.0006)
    if ROUND >= 2:
        slots = [box("rs", (-0.02, ys + 0.012 + i * 0.01, 0.106), (0.02, ys + 0.017 + i * 0.01, 0.112), m["slide"]) for i in range(12)]
        cut_many(rail, slots)
    parts.append(rail)
    inside = cylinder("Bore", (0, yb - 0.03, bore), (0, yb + 0.0004, bore), 0.0062, m["dark"], 18)
    parts.append(inside)
    # --- frame
    fw = 0.0158
    fz = 0.042
    outline = [(y0 - 0.004, 0.046), (y0, z0), (0.158, z0), (0.162, z0 - 0.004), (0.162, fz + 0.004), (0.157, fz), (0.098, fz),
               (0.026, fz), (0.024, 0.034), (-0.034, 0.034), (y0 - 0.008, 0.040)]
    frame = side_plate("Frame", outline, -fw, fw, m["frame"])
    bevel_object(frame, 0.0016, 3, 40.0)
    smooth(frame, 40)
    parts.append(frame)
    # --- grip: wide, wrapped in a rubber sleeve with finger grooves.
    pivot = Vector((0, 0, 0.040))
    g = grip_body("Grip", m["grip"], 0.046, -0.044, 0.031, -0.036, 0.0178, grooves=3)
    smooth(g, 40)
    plate = box("MagPlate", (-0.016, -0.034, -0.049), (0.016, 0.029, -0.0425), m["frame"], bevel=0.002, segments=3)
    smooth(plate, 40)
    tilt_all([g, plate], math.radians(-14.0), pivot)
    parts += [g, plate]
    tang = box("Tang", (-fw + 0.0015, y0 - 0.012, z0 - 0.018), (fw - 0.0015, y0 + 0.004, z0 - 0.002), m["frame"], bevel=0.0045, segments=3)
    rotate(tang, math.radians(-8.0), "X", Vector((0, y0, z0 - 0.01)))
    smooth(tang, 40)
    parts.append(tang)
    # --- guard (squared) and trigger
    guard = sweep("Guard", guard_path(0.022, 0.094, fz, 0.012, 0.007), 0.0058, 0.0066, m["frame"])
    smooth(guard, 50)
    parts.append(guard)
    parts.append(curved_trigger(0.041, fz + 0.002, 0.021, m["black"], 0.0056))
    # --- sights, hammer, controls
    rear = box("Rear", (-0.0085, y0 + 0.004, z1 - 0.001), (0.0085, y0 + 0.014, z1 + 0.0075), m["black"], bevel=0.001)
    notch = box("notch", (-0.0019, y0, z1 + 0.0032), (0.0019, y0 + 0.02, z1 + 0.02), m["black"])
    cut(rear, notch)
    parts.append(rear)
    front = box("Front", (-0.0018, yb - 0.018, 0.1092), (0.0018, yb - 0.008, z1 + 0.0072), m["black"], bevel=0.0006)
    parts.append(front)
    hy = y0 - 0.001
    hammer = side_plate("Hammer", [(hy + 0.002, z0 - 0.004), (hy + 0.002, z1 - 0.004), (hy - 0.005, z1 + 0.002), (hy - 0.013, z1 + 0.001), (hy - 0.014, z1 - 0.005), (hy - 0.007, z1 - 0.01), (hy - 0.006, z0 - 0.004)], -0.004, 0.004, m["black"])
    bevel_object(hammer, 0.0008, 2, 30.0)
    parts.append(hammer)
    if ROUND >= 2:
        for side in (-1.0, 1.0):
            hub = cylinder("Safety", (side * (w - 0.001), y0 + 0.012, z1 - 0.01), (side * (w + 0.0024), y0 + 0.012, z1 - 0.01), 0.0046, m["black"], 20, bevel=0.0006)
            lever = box("Lever", (min(side * (w + 0.0006), side * (w + 0.0032)), y0 + 0.012, z1 - 0.0128), (max(side * (w + 0.0006), side * (w + 0.0032)), y0 + 0.03, z1 - 0.0072), m["black"], bevel=0.001)
            parts += [hub, lever]
        stop = box("Stop", (-fw - 0.0018, 0.004, z0 - 0.008), (-fw + 0.001, 0.036, z0 - 0.002), m["black"], bevel=0.0008)
        parts.append(stop)
        release = box("Release", (-fw - 0.0022, 0.018, 0.031), (-fw + 0.001, 0.028, 0.039), m["black"], bevel=0.0012)
        parts.append(release)
        for y, z in ((0.03, fz + 0.006), (-0.014, fz + 0.012), (0.07, fz + 0.007), (0.13, fz + 0.012)):
            parts.append(cylinder("Pin", (-fw - 0.0004, y, z), (fw + 0.0004, y, z), 0.0018, m["steel"], 14))
    if ROUND >= 3:
        parts.append(engrave("DESERT EAGLE", Vector((-bw - 0.00012, yb - 0.022, 0.0882)), 0.0062, m["marking"]))
        parts.append(engrave(".50 AE   PISTOL", Vector((-bw - 0.00012, yb - 0.022, 0.0682)), 0.0042, m["marking"]))
        parts.append(engrave(".50 A.E.", Vector((bw + 0.00012, ys + 0.03, 0.0682)), 0.0042, m["marking"], side=1.0))
        for x, y, z in ((0.0, yb - 0.0076, z1 + 0.0048), (-0.0055, y0 + 0.0143, z1 + 0.0045), (0.0055, y0 + 0.0143, z1 + 0.0045)):
            parts.append(cylinder("Dot", (x, y - 0.0004, z), (x, y + 0.0002, z), 0.0012, m["white"], 12))
    return parts, {"bore": bore, "muzzle": yb, "irons": z1 + 0.0072, "rail": 0.1095, "optic": 0.15}


# ------------------------------------------------------------------ .44 Magnum
def build_revolver(m):
    parts = []
    bore = 0.086
    fw = 0.0128
    cyl_y = (0.032, 0.078)
    cyl_r = 0.0225
    cyl_axis = 0.071
    muzzle = 0.237
    # --- frame: the side outline of a large double-action frame, with the window for the
    # cylinder cut out.
    outline = [(-0.032, 0.040), (-0.034, 0.066), (-0.029, 0.092), (-0.019, 0.1025), (-0.004, 0.1045), (0.030, 0.1025), (0.080, 0.1022),
               (0.086, 0.1015), (0.086, 0.060), (0.074, 0.050), (0.060, 0.044), (0.020, 0.040), (0.0, 0.034), (-0.026, 0.034)]
    frame = side_plate("Frame", outline, -fw, fw, m["frame"])
    window = box("window", (-0.03, cyl_y[0] - 0.001, cyl_axis - cyl_r - 0.004), (0.03, cyl_y[1] + 0.002, cyl_axis + cyl_r + 0.004), m["frame"])
    cut(frame, window)
    if ROUND >= 2:
        # The top strap's groove as the rear sight's channel, and the side plate's outline.
        chan = box("chan", (-0.0016, -0.02, 0.1085), (0.0016, 0.09, 0.12), m["frame"])
        cut(frame, chan)
    bevel_object(frame, 0.0016, 3, 40.0)
    smooth(frame, 40)
    parts.append(frame)
    # --- cylinder: six chambers, flutes between them.
    cyl = cylinder("Cylinder", (0, cyl_y[0], cyl_axis), (0, cyl_y[1], cyl_axis), cyl_r, m["slide"], 48, bevel=0.0018 if ROUND >= 2 else 0.0, bevel_segments=3)
    chambers = []
    flutes = []
    for i in range(6):
        a = math.tau * i / 6 + math.pi / 2
        cx, cz = math.cos(a) * 0.0148, cyl_axis + math.sin(a) * 0.0148
        chambers.append(cylinder("ch", (cx, cyl_y[1] - 0.012, cz), (cx, cyl_y[1] + 0.01, cz), 0.0056, m["slide"], 20))
        if ROUND >= 2:
            fa = a + math.tau / 12
            fx, fz = math.cos(fa) * (cyl_r + 0.0012), cyl_axis + math.sin(fa) * (cyl_r + 0.0012)
            flute = cylinder("fl", (fx, cyl_y[0] + 0.012, fz), (fx, cyl_y[1] - 0.006, fz), 0.0042, m["slide"], 18)
            flutes.append(flute)
    cut_many(cyl, chambers + flutes)
    smooth(cyl, 40)
    parts.append(cyl)
    if ROUND >= 3:
        # Brass case heads in the chambers at the back, seen through the frame's gap.
        for i in range(6):
            a = math.tau * i / 6 + math.pi / 2
            cx, cz = math.cos(a) * 0.0148, cyl_axis + math.sin(a) * 0.0148
            parts.append(cylinder("Case", (cx, cyl_y[1] - 0.004, cz), (cx, cyl_y[1] - 0.0016, cz), 0.0054, m["brass"], 16))
            parts.append(cylinder("Bullet", (cx, cyl_y[1] - 0.0018, cz), (cx, cyl_y[1] - 0.0012, cz), 0.0042, m["dark"], 12))
    # --- barrel with a full underlug and a ventilated rib on top.
    bar = cylinder("Barrel", (0, 0.084, bore), (0, muzzle, bore), 0.0098, m["slide"], 36)
    lug = box("Lug", (-0.0078, 0.084, 0.058), (0.0078, muzzle - 0.002, bore), m["slide"], bevel=0.0035, segments=3)
    union(bar, lug)
    rib = box("Rib", (-0.0058, 0.084, bore + 0.006), (0.0058, muzzle, bore + 0.0142), m["slide"], bevel=0.0012)
    union(bar, rib)
    hole = cylinder("hole", (0, muzzle - 0.03, bore), (0, muzzle + 0.01, bore), 0.0058, m["slide"], 24)
    cut(bar, hole)
    if ROUND >= 2:
        vents = [box("vent", (-0.02, 0.098 + i * 0.024, bore + 0.0075), (0.02, 0.112 + i * 0.024, bore + 0.0125), m["slide"], bevel=0.0012) for i in range(6)]
        cut_many(bar, vents)
        # The ejector rod's shroud: a groove along the underlug's foot.
        rod_cut = cylinder("rc", (0, 0.084, 0.0625), (0, 0.17, 0.0625), 0.0036, m["slide"], 18)
        cut(bar, rod_cut)
    smooth(bar, 40)
    parts.append(bar)
    if ROUND >= 2:
        rod = cylinder("Rod", (0, cyl_y[1], 0.0625), (0, 0.166, 0.0625), 0.0029, m["steel"], 16)
        knob = cylinder("Knob", (0, 0.163, 0.0625), (0, 0.172, 0.0625), 0.0034, m["steel"], 18, bevel=0.0008)
        parts += [rod, knob]
    inside = cylinder("Bore", (0, muzzle - 0.03, bore), (0, muzzle + 0.0004, bore), 0.0054, m["dark"], 18)
    parts.append(inside)
    # --- sights: a red ramp on the rib's front, an adjustable rear on the top strap.
    ramp = side_plate("Front", [(muzzle - 0.022, bore + 0.0135), (muzzle - 0.003, bore + 0.0135), (muzzle - 0.004, bore + 0.0255), (muzzle - 0.008, bore + 0.0255)], -0.0016, 0.0016, m["black"])
    bevel_object(ramp, 0.0005, 2, 30.0)
    parts.append(ramp)
    if ROUND >= 3:
        insert = side_plate("Insert", [(muzzle - 0.0085, bore + 0.018), (muzzle - 0.0045, bore + 0.018), (muzzle - 0.005, bore + 0.0252), (muzzle - 0.0078, bore + 0.0252)], -0.0017, 0.0017, m["red"])
        parts.append(insert)
    irons = bore + 0.0255
    rear = box("Rear", (-0.0072, -0.016, 0.1095), (0.0072, 0.006, irons), m["black"], bevel=0.0009)
    notch = box("notch", (-0.0016, -0.03, irons - 0.0034), (0.0016, 0.02, irons + 0.01), m["black"])
    cut(rear, notch)
    parts.append(rear)
    if ROUND >= 2:
        screw = cylinder("Wind", (0.0072, -0.005, irons - 0.0055), (0.0088, -0.005, irons - 0.0055), 0.0018, m["steel"], 12)
        parts.append(screw)
    # --- hammer with a wide spur, cocked down (resting)
    hammer = side_plate("Hammer", [(-0.026, 0.074), (-0.026, 0.102), (-0.033, 0.113), (-0.046, 0.112), (-0.047, 0.106), (-0.038, 0.102), (-0.034, 0.08)], -0.0042, 0.0042, m["steel"])
    bevel_object(hammer, 0.0009, 2, 30.0)
    smooth(hammer, 40)
    parts.append(hammer)
    if ROUND >= 2:
        for i in range(4):
            g = box("hs", (-0.006, -0.046 + i * 0.0032, 0.111), (0.006, -0.0448 + i * 0.0032, 0.116), m["steel"])
            cut(hammer, g)
    # --- grip: a wooden grip round the frame's grip strap.
    pivot = Vector((0, 0, 0.040))
    strap = grip_body("Strap", m["frame"], 0.046, -0.036, 0.024, -0.03, 0.0098, swell=0.001, hump=0.002)
    wood = grip_body("Grip", m["grip"], 0.042, -0.034, 0.029, -0.034, 0.0168, grooves=0, swell=0.0022, hump=0.003)
    smooth(strap, 40)
    smooth(wood, 40)
    grip_parts = [strap, wood]
    if ROUND >= 3:
        for side in (-1.0, 1.0):
            grip_parts.append(cylinder("Medal", (side * 0.0175, -0.004, 0.014), (side * 0.0186, -0.004, 0.014), 0.0034, m["steel"], 18, bevel=0.0004))
    tilt_all(grip_parts, math.radians(-18.0), pivot)
    parts += grip_parts
    # --- guard (round) and a smooth trigger
    guard = sweep("Guard", guard_path(0.018, 0.068, 0.044, 0.014, 0.018), 0.0048, 0.0058, m["frame"])
    smooth(guard, 50)
    parts.append(guard)
    parts.append(curved_trigger(0.038, 0.046, 0.022, m["steel"], 0.0058))
    if ROUND >= 2:
        latch = box("Latch", (-fw - 0.0024, 0.006, 0.072), (-fw + 0.001, 0.022, 0.080), m["steel"], bevel=0.0012)
        parts.append(latch)
        for y, z in ((0.012, 0.096), (-0.012, 0.058), (0.050, 0.050), (-0.02, 0.09)):
            parts.append(cylinder("Pin", (-fw - 0.0005, y, z), (fw + 0.0005, y, z), 0.0019, m["steel"], 14))
        # The crane's line on the frame's left, under the cylinder.
        crane = box("Crane", (-fw - 0.0006, cyl_y[1] + 0.001, 0.046), (-fw + 0.002, 0.086, 0.054), m["frame"], bevel=0.0008)
        parts.append(crane)
    if ROUND >= 3:
        parts.append(engrave(".44 MAGNUM", Vector((-0.0099, muzzle - 0.016, bore - 0.004)), 0.0058, m["marking"]))
        parts.append(engrave("NACHTWACHE  MOD. 29", Vector((0.0099, 0.105, bore - 0.004)), 0.0042, m["marking"], side=1.0))
    return parts, {"bore": bore, "muzzle": muzzle, "irons": irons, "rail": 0.110, "optic": 0.035}


# ------------------------------------------------------------------ main
def main():
    kit.clear()
    m = make_materials()
    if GUN == "deagle":
        parts, spec = build_deagle(m)
        root_name = "Deagle"
    elif GUN == "revolver":
        parts, spec = build_revolver(m)
        root_name = "Revolver"
    else:
        s = SPECS[GUN]
        parts = build_auto(s, m)
        spec = {"bore": s["bore"], "muzzle": s["muzzle"], "irons": s["irons"], "rail": s["slide"][3], "optic": 0.02}
        root_name = s["root"]
    body = kit.join(parts, "Body")
    root = kit.finish([body], root_name, GUN, TEX, NOBAKE, m["black"])
    print("ROUND", ROUND, "GUN", GUN, "triangles", kit.triangles(body))
    if RENDER:
        kit.render_views(os.path.abspath(RENDER), "%s_r%d" % (GUN, ROUND), (0.0, 0.07, 0.04), 0.62 if GUN not in ("deagle", "revolver") else 0.72, -0.12,
                         arg("--only", "").split(",") if arg("--only") else None)
    # The places weapon_view.gd needs, in view space (mount ZERO in MOD_MOUNTS).
    muzzle = view((0, spec["muzzle"], spec["bore"]))
    irons = spec["irons"] + MOUNT.y
    print("SPEC muzzle", vec3(muzzle), "rail %.4f irons %.4f optic %.4f" % (spec["rail"] + MOUNT.y, irons, MOUNT.z - spec["optic"] - 0.06))
    print("SPEC aim Vector3(0.0, %.4f, -0.5)" % (-irons + 0.0012))
    if not NOBAKE:
        kit.export(OUT, [body, root])


main()
