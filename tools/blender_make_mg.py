# Builds the machine gun ("mg", MASCHINENGEWEHR) for Nachtwache, from nothing (it replaces the
# supplied mesh mg.glb, which stays in the folder unused): a light machine gun of the kind of
# the Minimi / M249 in its later form, as the old model was - a receiver of riveted sheet
# steel, the feed cover on top with a rail along it, the belt coming up from the box that
# hangs under it on the left and going in through the feed opening on that side, the
# charging handle on the right; a tan handguard with its slots and a rail below, the heavy
# barrel with the gas cylinder under it, the folded bipod, the front sight and the
# birdcage flash hider; a tan skeleton stock with its rubber pad, a black pistol grip, the
# wide trigger guard. Every part is made here, bevelled, given its material, UV-unwrapped
# and baked into one texture set (base colour, roughness and metal, normal). Written as a
# GLB with the nodes
#   MG > Body / Feed (the feed tray and the belt guide at the opening; stays when the box
#   comes off) / Magazine (the box; origin where the old model had it) /
#   Sights (the rear sight) / BeltRound, BeltTracer (one round of the belt each, which the
#   game lays along the belt and moves with every shot)
#
#   blender --background --factory-startup --python tools/blender_make_mg.py -- [--round 4] [--tex 2048]
#           [--out assets/models/mg_built.glb] [--render <folder> --prefix mg_r1] [--only links] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
#
# The helpers (shapes, materials, the bake, the review pictures) are those of
# blender_make_ak47.py, imported from beside this file.
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the pistol grip (where the old model had it). The glTF exporter turns this into Godot space
# (barrel along -Z, up +Y). The places the game needs (GUNS["mg"] in weapon_view.gd) are
# printed.
import bpy, sys, os, math
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_make_ak47 as kit
from blender_make_ak47 import (arg, box, cylinder, cone, lathe, prism, slab, loft, sweep, torus, fillet, rounded_rect, section,
                               superellipse, bevel_object, cut, union, rotate, smooth, join, triangles, material, link,
                               engrave_left, engrave_right, bake, final_material, render_views, place_origin, export, clear, apply)

HERE = os.path.dirname(os.path.abspath(__file__))
ROUND = kit.ROUND
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "mg_built.glb")))
RENDER = arg("--render")
PREFIX = arg("--prefix", "mg_r%d" % ROUND)
NOBAKE = kit.NOBAKE


def make_materials():
    wear = {1: 0.0, 2: 0.4, 3: 0.8}.get(ROUND, 0.85)
    # Black phosphate on the steel: matt, rubbed to bare steel on the edges.
    steel = material("steel", (0.030, 0.031, 0.033), 0.55, 0.6, wear=0.6 * wear, grime=0.6 if ROUND >= 2 else 0.0, worn=(0.33, 0.33, 0.34))
    steelplain = material("steelplain", (0.028, 0.029, 0.031), 0.6, 0.55, grime=0.7)
    barrel = material("barrel", (0.040, 0.040, 0.041), 0.5, 0.75, wear=0.4 * wear, grime=0.5 if ROUND >= 2 else 0.0, worn=(0.30, 0.29, 0.28)) if ROUND >= 2 else steel
    bright = material("bright", (0.30, 0.30, 0.30), 0.34, 1.0, wear=0.2 * wear, grime=0.6 if ROUND >= 2 else 0.0, worn=(0.55, 0.55, 0.55))
    dark = material("dark", (0.006, 0.006, 0.007), 0.85, 0.0)
    # Flat dark earth polymer: the handguard and the stock, finely stippled.
    tan = material("tan", (0.30, 0.235, 0.15), 0.72, 0.0, wear=0.35 * wear, grime=0.6 if ROUND >= 2 else 0.0, bump=0.12 if ROUND >= 3 else 0.0, bump_scale=2600.0, stipple=True, worn=(0.42, 0.36, 0.26))
    polymer = material("polymer", (0.022, 0.023, 0.025), 0.7, 0.0, wear=0.3 * wear, grime=0.6 if ROUND >= 2 else 0.0, worn=(0.10, 0.10, 0.105))
    grip = material("grip", (0.024, 0.025, 0.027), 0.82, 0.0, grime=0.7, bump=0.0 if ROUND < 3 else 0.8, bump_scale=2200.0, stipple=True) if ROUND >= 3 else polymer
    rubber = material("rubber", (0.018, 0.018, 0.02), 0.9, 0.0, grime=0.4 if ROUND >= 2 else 0.0)
    boxcol = material("box", (0.050, 0.055, 0.040), 0.62, 0.0, wear=0.35 * wear, grime=0.6 if ROUND >= 2 else 0.0, worn=(0.13, 0.14, 0.11))
    brass = material("brass", (0.66, 0.50, 0.22), 0.32, 1.0, grime=0.3)
    copper = material("copper", (0.50, 0.30, 0.17), 0.34, 1.0, grime=0.2)
    red = material("red", (0.45, 0.05, 0.03), 0.5, 0.0) if ROUND >= 3 else copper
    link_steel = material("link", (0.05, 0.05, 0.052), 0.45, 0.8, grime=0.4)
    marking = material("marking", (0.30, 0.31, 0.32), 0.5, 0.6) if ROUND >= 3 else steel
    white = material("white", (0.6, 0.6, 0.58), 0.55, 0.0) if ROUND >= 3 else steel
    return {"steel": steel, "steelplain": steelplain, "barrel": barrel, "bright": bright, "dark": dark, "tan": tan, "polymer": polymer, "grip": grip,
            "rubber": rubber, "box": boxcol, "brass": brass, "copper": copper, "red": red, "link": link_steel, "marking": marking, "white": white}


# ------------------------------------------------------------------ the measures (those of the old model)
BORE_Z = 0.1217
MUZZLE_Y = 0.6683               # 89 cm over all
BORE_R = 0.0028
BARREL_R = 0.0112
REC_Y = (-0.044, 0.262)         # the receiver
REC_W = 0.0235
REC_Z = (0.060, 0.140)
COVER_Y = (0.092, 0.262)        # the feed cover on top of its front half
COVER_TOP = 0.161
RAIL_TOP = 0.170                # the rail on the cover
SIGHT_Z = 0.1897                # the line of sight: the middle of the rear aperture, the tip of the front post
REAR_Y = 0.0085                 # the rear sight's aperture
POST_Y = 0.552                  # the front post
GUARD_Y = (0.262, 0.448)        # the handguard
GUARD_W = 0.0292
GUARD_Z = (0.066, 0.158)
GAS_Z = 0.0935                  # the gas cylinder under the barrel
GAS_Y = (0.448, 0.484)          # the gas block
FRONT_Y = (0.538, 0.566)        # the front sight's base
HIDER_Y = 0.600                 # the flash hider, from here to the muzzle
STOCK_END = -0.2217
FEED_Y = (0.150, 0.214)         # the feed opening on the left
FEED_Z = (0.110, 0.140)
BOX_X = (-0.0435, 0.0255)       # the box under the receiver on the left
BOX_Y = (0.126, 0.226)
BOX_Z = (-0.052, 0.034)
MAG_ORIGIN = Vector((-0.0035, 0.1737, 0.050))
HANDLE = Vector((0.0377, 0.1011, 0.1327))
SUPPORT = Vector((0.0, 0.3539, 0.0907))
ROUND_Y = (0.1505, 0.2075)      # a cartridge in the belt, base to tip (5.56 x 45, 57 mm)
PITCH = 0.0102                  # from one round of the belt to the next


def belt_path():
    """The belt from the mouth of the box up the left side into the feed opening: (x, z)."""
    pts = fillet([(-0.0330, 0.016, 0.0), (-0.0372, 0.070, 0.02), (-0.0345, 0.112, 0.018), (-0.0215, 0.1265, 0.012), (-0.0040, 0.1290, 0.0)], 8)
    # Evenly spaced along it.
    out = []
    lengths = [0.0]
    for a, b in zip(pts, pts[1:]):
        lengths.append(lengths[-1] + (Vector(b) - Vector(a)).length)
    d = 0.0
    i = 0
    while d <= lengths[-1]:
        while lengths[i + 1] < d:
            i += 1
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        t = (d - lengths[i]) / max(1e-9, lengths[i + 1] - lengths[i])
        p = a.lerp(b, t)
        out.append((p, (b - a).normalized()))
        d += PITCH
    return out


def cartridge(m, x, z, tracer):
    """A 5.56 round lying along y at (x, z), its base at the back."""
    parts = []
    y0, y1 = ROUND_Y
    case = lathe("Case", (x, y0, z), (x, y0 + 0.0447, z), [(0.0, 0.0047), (0.03, 0.0047), (0.05, 0.0040), (0.09, 0.0040), (0.11, 0.0048), (0.80, 0.0046), (0.87, 0.0032), (1.0, 0.0032)], m["brass"], 14)
    parts.append(smooth(case, 50))
    bullet = lathe("Bullet", (x, y0 + 0.0425, z), (x, y1, z), [(0.0, 0.0029), (0.35, 0.0029), (0.7, 0.0022), (0.92, 0.0011), (1.0, 0.0003)], m["copper"], 14)
    parts.append(smooth(bullet, 50))
    if tracer and ROUND >= 3:
        parts.append(cone("Tip", (x, y1 - 0.006, z), (x, y1 + 0.0002, z), 0.0016, 0.0003, m["red"], 12))
    return parts


def belt_link(m, x, z, along):
    """The steel link round a round: two loops and the strap between them."""
    parts = []
    for y in (ROUND_Y[0] + 0.009, ROUND_Y[0] + 0.030):
        ring = cylinder("Link", (x, y, z), (x, y + 0.0055, z), 0.0055, m["link"], 14)
        cut(ring, cylinder("in", (x, y - 0.01, z), (x, y + 0.02, z), 0.0047, m["link"], 14))
        parts.append(ring)
    # The strap on the side away from the gun, joining the loops.
    side = Vector((-along.y, along.x))
    if side.x > 0:
        side = -side
    sx, sz = x + side.x * 0.0052, z + side.y * 0.0052
    parts.append(box("Strap", (sx - 0.0012, ROUND_Y[0] + 0.009, sz - 0.0012), (sx + 0.0012, ROUND_Y[0] + 0.0355, sz + 0.0012), m["link"]))
    return parts


def build(m):
    body, feed, mag, sights = [], [], [], []
    W = REC_W
    z0, z1 = REC_Z
    # --- the receiver: a box of sheet steel with ribs pressed along its sides; the feed
    # opening on the left, the slot of the charging handle on the right
    rec = box("Receiver", (-W, REC_Y[0], z0), (W, REC_Y[1], z1), m["steel"])
    bevel_object(rec, 0.0022 if ROUND >= 2 else 0.003, 3, 40.0)
    if ROUND >= 2:
        cut(rec, box("feed", (-0.03, FEED_Y[0], FEED_Z[0]), (-W + 0.004, FEED_Y[1], FEED_Z[1] + 0.01), m["steel"], bevel=0.0015))
        cut(rec, box("slot", (W - 0.004, 0.088, HANDLE.z - 0.0045), (0.03, 0.246, HANDLE.z + 0.0045), m["steel"], bevel=0.001))
        # The magazine well of the box's adapter under the feed opening.
        cut(rec, box("well", (-0.0205, 0.1505, z0 - 0.01), (0.0125, 0.2045, z0 + 0.006), m["steel"], bevel=0.0012))
    smooth(rec, 35)
    if ROUND >= 4:
        rec.data.materials.append(m["steelplain"])
        for poly in rec.data.polygons:
            c = poly.center
            if c.x < -W + 0.0039 and c.x > -W - 0.001 and FEED_Y[0] - 0.001 < c.y < FEED_Y[1] + 0.001 and c.z > FEED_Z[0] - 0.001:
                poly.material_index = 1
    body.append(rec)
    if ROUND >= 2:
        # Dark inside the opening and the slot; the feed tray's floor glinting in the opening.
        body.append(box("FeedInside", (-W + 0.0035, FEED_Y[0] - 0.001, FEED_Z[0] - 0.002), (-W + 0.0055, FEED_Y[1] + 0.001, FEED_Z[1] + 0.008), m["dark"]))
        body.append(box("SlotInside", (W - 0.0055, 0.087, HANDLE.z - 0.0046), (W - 0.0035, 0.247, HANDLE.z + 0.0046), m["dark"]))
        body.append(box("WellInside", (-0.0195, 0.1515, z0 + 0.004), (0.0115, 0.2035, z0 + 0.0058), m["dark"]))
        # The ribs pressed along both sides behind the feed, and their ends.
        for side in (-1.0, 1.0):
            for z in (0.0835, 0.1085):
                rib = cylinder("SideRib", (side * (W - 0.0012), REC_Y[0] + 0.012, z), (side * (W - 0.0012), 0.128, z), 0.0024, m["steel"], 12)
                body.append(smooth(rib, 50))
    # --- the trigger housing under the receiver, the safety through it; the trigger guard
    tg = box("TriggerHousing", (-0.0172, 0.018, 0.043), (0.0172, 0.140, z0 + 0.003), m["steel"], bevel=0.0025)
    body.append(smooth(tg, 35))
    guard_path = fillet([(0.128, 0.0445, 0.0), (0.124, 0.0200, 0.010), (0.046, 0.0175, 0.016), (0.022, 0.0450, 0.0)], 6)
    guard = sweep("TriggerGuard", guard_path, 0.0085, 0.0036, m["polymer"])
    bevel_object(guard, 0.0009, 2, 35.0)
    body.append(smooth(guard, 40))
    blade = sweep("Trigger", [(0.080, 0.0440), (0.0815, 0.0360), (0.0805, 0.0290), (0.0765, 0.0240), (0.0720, 0.0220)], 0.0034, 0.0045, m["steel"])
    bevel_object(blade, 0.0008, 2, 35.0)
    body.append(smooth(blade, 40))
    if ROUND >= 2:
        body.append(box("TriggerSlot", (-0.0045, 0.068, 0.0418), (0.0045, 0.090, 0.0434), m["dark"]))
        # The push-through safety above the trigger, and the pins of the housing.
        for side, length in ((-1.0, 0.0028), (1.0, 0.0010)):
            body.append(cylinder("Safety", (side * 0.0170, 0.1085, 0.0520), (side * (0.0172 + length), 0.1085, 0.0520), 0.0042, m["polymer"], 18, bevel=0.0006))
        for y, z in ((0.030, 0.0515), (0.128, 0.0515)):
            for side in (-1.0, 1.0):
                body.append(cylinder("HousingPin", (side * 0.0168, y, z), (side * 0.0180, y, z), 0.0026, m["bright"], 14))
    # --- the feed cover on top: hinged at its front, its latch at the back, the rail along
    # its top
    cover_profile = fillet([(W + 0.0006, z1 - 0.0012, 0.0), (W + 0.0006, 0.1515, 0.0035), (0.0185, COVER_TOP, 0.003), (-0.0185, COVER_TOP, 0.003), (-W - 0.0006, 0.1515, 0.0035), (-W - 0.0006, z1 - 0.0012, 0.0)], 4)
    cover = prism("FeedCover", cover_profile, COVER_Y[0], COVER_Y[1], m["steel"])
    bevel_object(cover, 0.0012, 2, 35.0)
    body.append(smooth(cover, 35))
    if ROUND >= 2:
        # The latch tabs at the back of the cover, both sides, and the hinge pin at its front.
        for side in (-1.0, 1.0):
            tab = box("Latch", (side * (W + 0.0006) - 0.0028, COVER_Y[0] + 0.001, 0.141), (side * (W + 0.0006) + 0.0028, COVER_Y[0] + 0.012, 0.1545), m["steel"], bevel=0.0009)
            body.append(tab)
            if ROUND >= 3:
                for k in range(4):
                    y = COVER_Y[0] + 0.0025 + k * 0.0025
                    body.append(box("LatchRib", (side * (W + 0.0034) - 0.0004, y - 0.0004, 0.1425), (side * (W + 0.0034) + 0.0004, y + 0.0004, 0.1535), m["steel"]))
        body.append(cylinder("Hinge", (-W - 0.0018, COVER_Y[1] - 0.006, 0.1475), (W + 0.0018, COVER_Y[1] - 0.006, 0.1475), 0.0032, m["bright"], 16, bevel=0.0006))
        # The cover's pressed ribs across, and the seam where it meets the receiver.
        for y in (0.135, 0.180, 0.225):
            rib = prism("CoverRib", fillet([(W + 0.0012, z1 - 0.0005, 0.0), (W + 0.0012, 0.1520, 0.0035), (0.0188, COVER_TOP + 0.0006, 0.003), (-0.0188, COVER_TOP + 0.0006, 0.003), (-W - 0.0012, 0.1520, 0.0035), (-W - 0.0012, z1 - 0.0005, 0.0)], 4), y - 0.003, y + 0.003, m["steel"])
            bevel_object(rib, 0.0008, 2, 30.0)
            body.append(smooth(rib, 35))
    # The rail: a Picatinny rail along the cover's top, its slots across.
    rail = box("Rail", (-0.0105, COVER_Y[0] + 0.014, COVER_TOP - 0.001), (0.0105, COVER_Y[1] - 0.004, RAIL_TOP), m["steel"])
    if ROUND >= 2:
        for side in (-1.0, 1.0):
            g = box("dove", (side * 0.0105 - 0.003, COVER_Y[0], COVER_TOP - 0.002), (side * 0.0105 + 0.003, COVER_Y[1], COVER_TOP + 0.0045), m["steel"])
            rotate(g, side * math.radians(45.0), "Y", Vector((side * 0.0105, 0, COVER_TOP + 0.0045)))
            cut(rail, g)
        y = COVER_Y[0] + 0.0185
        while y < COVER_Y[1] - 0.008:
            cut(rail, box("slot", (-0.02, y, RAIL_TOP - 0.003), (0.02, y + 0.0052, RAIL_TOP + 0.01), m["steel"]))
            y += 0.010
    bevel_object(rail, 0.0005, 1, 35.0)
    body.append(smooth(rail, 35))
    # --- the rear sight (the Sights node): its base on the receiver's top, the plate with the
    # aperture, the knobs that set it
    base = box("SightBase", (-0.0118, REAR_Y - 0.010, z1 - 0.002), (0.0118, REAR_Y + 0.012, 0.1515), m["steel"], bevel=0.0015)
    sights.append(base)
    plate = slab("SightPlate", fillet([(REAR_Y - 0.0024, 0.150, 0.0), (REAR_Y - 0.0024, SIGHT_Z + 0.0085, 0.0035), (REAR_Y + 0.0024, SIGHT_Z + 0.0085, 0.0035), (REAR_Y + 0.0024, 0.150, 0.0)], 4), -0.0078, 0.0078, m["steel"])
    cut(plate, cylinder("aperture", (0, REAR_Y - 0.01, SIGHT_Z), (0, REAR_Y + 0.01, SIGHT_Z), 0.0048, m["steel"], 28))
    if ROUND >= 2:
        # The plate is thinner above the base, its two guard ears beside the aperture.
        for side in (-1.0, 1.0):
            ear = box("SightEar", (side * 0.0098 - 0.0016, REAR_Y - 0.004, 0.150), (side * 0.0098 + 0.0016, REAR_Y + 0.006, SIGHT_Z + 0.0045), m["steel"], bevel=0.0007)
            sights.append(ear)
    bevel_object(plate, 0.0006, 2, 35.0)
    sights.append(smooth(plate, 35))
    knob = cylinder("Elevation", (0.0118, REAR_Y + 0.001, 0.1555), (0.0310, REAR_Y + 0.001, 0.1555), 0.0060, m["steel"], 24, bevel=0.0009)
    sights.append(knob)
    sights.append(cylinder("Windage", (-0.0118, REAR_Y + 0.001, 0.1555), (-0.0175, REAR_Y + 0.001, 0.1555), 0.0048, m["steel"], 20, bevel=0.0008))
    if ROUND >= 3:
        for k in range(18):
            a = math.tau * k / 18
            sights.append(box("Knurl", (0.0228, REAR_Y + 0.001 + math.cos(a) * 0.0060 - 0.0005, 0.1555 + math.sin(a) * 0.0060 - 0.0005), (0.0302, REAR_Y + 0.001 + math.cos(a) * 0.0060 + 0.0005, 0.1555 + math.sin(a) * 0.0060 + 0.0005), m["steel"]))
        for k in range(6):
            z = 0.1525 + k * 0.0016
            sights.append(box("Scale", (0.0117, REAR_Y - 0.0085, z - 0.0002), (0.0121, REAR_Y - 0.0055, z + 0.0002), m["white"]))
    # --- the barrel, the handguard round it, the gas cylinder under it
    body.append(cylinder("Barrel", (0, REC_Y[1] - 0.004, BORE_Z), (0, HIDER_Y + 0.004, BORE_Z), BARREL_R, m["barrel"], 32))
    if ROUND >= 2:
        # The barrel's collar where it locks into the receiver, the knob of its quick-change
        # catch on the left.
        body.append(cylinder("BarrelCollar", (0, REC_Y[1] - 0.004, BORE_Z), (0, REC_Y[1] + 0.006, BORE_Z), 0.0175, m["steel"], 32, bevel=0.001))
    guard_rings = []
    for k in range(13):
        y = GUARD_Y[0] + (GUARD_Y[1] - GUARD_Y[0]) * k / 12
        t = k / 12
        # Rounded below where the hand lies, its top flat; a little narrower at the front.
        half = GUARD_W - 0.0018 * t
        guard_rings.append(section(y, half, GUARD_Z[0] + 0.002 * t, GUARD_Z[1], 0.006, 0.014, 5))
    hg = loft("Handguard", guard_rings, m["tan"])
    if ROUND >= 2:
        # Hollow: the barrel and the gas cylinder run through it.
        cut(hg, box("hollow", (-GUARD_W + 0.0035, GUARD_Y[0] - 0.01, GUARD_Z[0] + 0.0045), (GUARD_W - 0.0035, GUARD_Y[1] + 0.01, GUARD_Z[1] - 0.0035), m["tan"], bevel=0.004))
        # Two rows of slots along each side.
        for side in (-1.0, 1.0):
            for zc, n in ((0.132, 4), (0.100, 5)):
                span = (GUARD_Y[1] - GUARD_Y[0] - 0.040)
                for k in range(n):
                    yc = GUARD_Y[0] + 0.020 + span * (k + 0.5) / n
                    sl = box("slot", (side * GUARD_W - 0.006, yc - 0.0125 * 4 / n, zc - 0.0042), (side * GUARD_W + 0.006, yc + 0.0125 * 4 / n, zc + 0.0042), m["tan"], bevel=0.0035)
                    cut(hg, sl)
        # Holes along the top, to let the heat out.
        for k in range(5):
            yc = GUARD_Y[0] + 0.030 + k * 0.032
            cut(hg, box("vent", (-0.006, yc - 0.008, GUARD_Z[1] - 0.006), (0.006, yc + 0.008, GUARD_Z[1] + 0.005), m["tan"], bevel=0.0035))
    bevel_object(hg, 0.0012, 2, 40.0)
    body.append(smooth(hg, 40))
    if ROUND >= 2:
        # Dark inside it, behind the slots; its front ring of steel.
        inner = loft("HandguardInside", [section(GUARD_Y[0] + 0.004, GUARD_W - 0.004, GUARD_Z[0] + 0.005, GUARD_Z[1] - 0.004, 0.004, 0.011, 5),
                                         section(GUARD_Y[1] - 0.004, GUARD_W - 0.006, GUARD_Z[0] + 0.007, GUARD_Z[1] - 0.004, 0.004, 0.011, 5)], m["dark"])
        for p in inner.data.polygons:
            p.flip()
        body.append(inner)
        cap = loft("GuardCap", [section(GUARD_Y[1] - 0.002, GUARD_W - 0.0012, GUARD_Z[0] + 0.0014, GUARD_Z[1] + 0.0006, 0.006, 0.0135, 5),
                                section(GUARD_Y[1] + 0.006, GUARD_W - 0.0016, GUARD_Z[0] + 0.0022, GUARD_Z[1] - 0.0002, 0.006, 0.0135, 5)], m["steel"])
        cut(cap, cylinder("bore", (0, GUARD_Y[1] - 0.01, BORE_Z), (0, GUARD_Y[1] + 0.02, BORE_Z), BARREL_R + 0.0008, m["steel"], 28))
        cut(cap, cylinder("gas", (0, GUARD_Y[1] - 0.01, GAS_Z), (0, GUARD_Y[1] + 0.02, GAS_Z), 0.0102, m["steel"], 24))
        bevel_object(cap, 0.0007, 2, 35.0)
        body.append(smooth(cap, 35))
        # The rail under it, where the left hand lies.
        brail = box("LowerRail", (-0.0105, GUARD_Y[0] + 0.040, GUARD_Z[0] - 0.0068), (0.0105, GUARD_Y[1] - 0.030, GUARD_Z[0] + 0.004), m["polymer"])
        y = GUARD_Y[0] + 0.044
        while y < GUARD_Y[1] - 0.036:
            cut(brail, box("slot", (-0.02, y, GUARD_Z[0] - 0.009), (0.02, y + 0.0052, GUARD_Z[0] - 0.0038), m["polymer"]))
            y += 0.010
        bevel_object(brail, 0.0005, 1, 35.0)
        body.append(smooth(brail, 35))
        # The screws that hold it, a pair each side.
        for side in (-1.0, 1.0):
            for y in (GUARD_Y[0] + 0.012, GUARD_Y[1] - 0.012):
                body.append(cylinder("GuardScrew", (side * (GUARD_W - 0.0006), y, 0.118), (side * (GUARD_W + 0.0008), y, 0.118), 0.0028, m["steel"], 16, bevel=0.0004))
    body.append(cylinder("GasCylinder", (0, GUARD_Y[0] + 0.03, GAS_Z), (0, GAS_Y[1] + 0.004, GAS_Z), 0.0092, m["barrel"], 24))
    # --- the gas block: the barrel's collar and the gas cylinder's, joined; the regulator's
    # lever on the left; the bipod's clamp in front of it
    gb = cylinder("GasCollar", (0, GAS_Y[0], BORE_Z), (0, GAS_Y[1] - 0.006, BORE_Z), 0.0150, m["steel"], 28)
    union(gb, cylinder("GasHousing", (0, GAS_Y[0], GAS_Z), (0, GAS_Y[1], GAS_Z), 0.0125, m["steel"], 28))
    union(gb, box("web", (-0.0085, GAS_Y[0] + 0.002, GAS_Z), (0.0085, GAS_Y[1] - 0.008, BORE_Z), m["steel"]))
    bevel_object(gb, 0.0015, 2, 35.0)
    body.append(smooth(gb, 35))
    if ROUND >= 2:
        reg = sweep("Regulator", [(GAS_Y[0] + 0.022, GAS_Z - 0.002), (GAS_Y[0] + 0.020, GAS_Z - 0.016), (GAS_Y[0] + 0.014, GAS_Z - 0.024)], 0.0011, 0.0062, m["steel"], x=-0.0138)
        body.append(reg)
        body.append(cylinder("RegulatorHub", (-0.0128, GAS_Y[0] + 0.022, GAS_Z - 0.002), (-0.0152, GAS_Y[0] + 0.022, GAS_Z - 0.002), 0.0045, m["steel"], 18, bevel=0.0006))
        # The bipod: its clamp round the gas cylinder before the block, the two legs folded
        # forward under the barrel, their feet at the front.
        clamp = cylinder("BipodClamp", (0, GAS_Y[1] + 0.001, GAS_Z), (0, GAS_Y[1] + 0.016, GAS_Z), 0.0130, m["steel"], 24, bevel=0.0012)
        body.append(clamp)
        body.append(box("BipodYoke", (-0.0135, GAS_Y[1] + 0.003, GAS_Z - 0.020), (0.0135, GAS_Y[1] + 0.014, GAS_Z - 0.006), m["steel"], bevel=0.0015))
        for side in (-1.0, 1.0):
            x = side * 0.0102
            lz = GAS_Z - 0.0155
            body.append(cylinder("LegPivot", (x - 0.0035 * side, GAS_Y[1] + 0.0085, lz), (x + 0.0050 * side, GAS_Y[1] + 0.0085, lz), 0.0036, m["bright"], 14))
            body.append(cylinder("LegUpper", (x, GAS_Y[1] + 0.008, lz), (x, 0.585, lz), 0.0046, m["steel"], 16, bevel=0.0006))
            body.append(cylinder("LegLower", (x, 0.580, lz), (x, 0.636, lz), 0.0036, m["bright"], 14))
            body.append(lathe("Foot", (x, 0.634, lz), (x, 0.650, lz), [(0.0, 0.0040), (0.3, 0.0054), (0.85, 0.0050), (1.0, 0.0030)], m["rubber"], 16))
            body.append(box("LegLock", (x - 0.003, 0.574, lz - 0.0055), (x + 0.003, 0.586, lz + 0.0055), m["steel"], bevel=0.0008))
            if ROUND >= 3:
                for k in range(6):
                    y = 0.596 + k * 0.006
                    body.append(cylinder("LegNotch", (x, y, lz), (x, y + 0.0012, lz), 0.0039, m["steel"], 14))
        # The front sling loop on the left of the gas block.
        body.append(torus("SlingLoop", (-0.0175, (GAS_Y[0] + GAS_Y[1]) * 0.5, BORE_Z + 0.002), (1, 0, 0), 0.0068, 0.0015, m["steel"], 20, 8))
    # --- the front sight: a clamp round the barrel, a tower, a hood of two ears round the post
    fs = cylinder("FrontCollar", (0, FRONT_Y[0], BORE_Z), (0, FRONT_Y[1], BORE_Z), 0.0152, m["steel"], 28)
    tower = slab("Tower", fillet([(FRONT_Y[0] + 0.002, BORE_Z, 0.0), (FRONT_Y[0] + 0.006, 0.176, 0.003), (FRONT_Y[1] - 0.006, 0.176, 0.003), (FRONT_Y[1] - 0.002, BORE_Z, 0.0)], 4), -0.0065, 0.0065, m["steel"])
    union(fs, tower)
    for side in (-1.0, 1.0):
        ear = slab("Ear", fillet([(POST_Y - 0.0085, 0.170, 0.0), (POST_Y - 0.0085, 0.2030, 0.004), (POST_Y + 0.0085, 0.2030, 0.004), (POST_Y + 0.0085, 0.170, 0.0)], 4),
                   side * 0.0078 - 0.0017, side * 0.0078 + 0.0017, m["steel"])
        union(fs, ear)
    union(fs, box("EarBridge", (-0.0095, POST_Y - 0.0085, 0.170), (0.0095, POST_Y + 0.0085, 0.1775), m["steel"]))
    if ROUND >= 2:
        # Its clamp bolt below.
        union(fs, box("ClampLug", (-0.0068, FRONT_Y[0] + 0.004, BORE_Z - 0.024), (0.0068, FRONT_Y[1] - 0.004, BORE_Z - 0.010), m["steel"]))
    bevel_object(fs, 0.0011, 2, 35.0)
    body.append(smooth(fs, 35))
    if ROUND >= 2:
        body.append(cylinder("ClampBolt", (-0.0085, (FRONT_Y[0] + FRONT_Y[1]) * 0.5, BORE_Z - 0.0175), (0.0085, (FRONT_Y[0] + FRONT_Y[1]) * 0.5, BORE_Z - 0.0175), 0.0028, m["bright"], 14))
    body.append(cylinder("PostDrum", (0, POST_Y, 0.1760), (0, POST_Y, 0.1810), 0.0040, m["steel"], 18, bevel=0.0005))
    body.append(cone("Post", (0, POST_Y, 0.1805), (0, POST_Y, SIGHT_Z), 0.0015, 0.0011, m["steel"], 14))
    # --- the flash hider: a birdcage, open slots round its front
    hider = cylinder("Hider", (0, HIDER_Y, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.0118, m["barrel"], 32)
    cut(hider, cylinder("bore", (0, HIDER_Y + 0.008, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0088, m["barrel"], 28))
    if ROUND >= 2:
        for k in range(5):
            a = math.tau * k / 5 + math.pi / 2
            s = box("slot", (-0.0021, MUZZLE_Y - 0.048, 0.0), (0.0021, MUZZLE_Y - 0.006, 0.03), m["barrel"], bevel=0.0018)
            s.data.transform(Matrix.Translation((0, 0, BORE_Z)) @ Matrix.Rotation(a + math.pi, 4, "Y"))
            cut(hider, s)
    bevel_object(hider, 0.0008, 2, 35.0)
    body.append(smooth(hider, 35))
    body.append(cylinder("Muzzle", (0, HIDER_Y + 0.004, BORE_Z), (0, HIDER_Y + 0.012, BORE_Z), 0.0062, m["barrel"], 20))
    body.append(cylinder("BoreDeep", (0, HIDER_Y + 0.0119, BORE_Z), (0, HIDER_Y + 0.0123, BORE_Z), BORE_R, m["dark"], 16))
    # --- the stock: tan polymer, a skeleton with its hole, the cheek rest on top; the butt
    # pad of rubber
    outline = fillet([(REC_Y[0] + 0.004, 0.1410, 0.004), (-0.080, 0.1505, 0.02), (STOCK_END + 0.018, 0.1525, 0.006), (STOCK_END + 0.018, 0.0040, 0.006),
                      (STOCK_END + 0.040, 0.0040, 0.012), (-0.070, 0.0640, 0.03), (REC_Y[0] + 0.004, 0.0705, 0.004)], 6)
    stock = slab("Stock", outline, -0.0185, 0.0185, m["tan"])
    if ROUND >= 2:
        hole = fillet([(-0.084, 0.1255, 0.008), (STOCK_END + 0.034, 0.1255, 0.010), (STOCK_END + 0.034, 0.0255, 0.010), (-0.098, 0.0985, 0.02)], 6)
        cut(stock, slab("hole", hole, -0.03, 0.03, m["tan"]))
        # The cheek rest's step, and the lightening flutes on the sides of the top bar.
        for side in (-1.0, 1.0):
            cut(stock, box("flute", (side * 0.0185 - 0.0012, -0.170, 0.1335), (side * 0.0185 + 0.0012, -0.075, 0.1445), m["tan"], bevel=0.0010))
    bevel_object(stock, 0.0035, 3, 35.0)
    body.append(smooth(stock, 40))
    if ROUND >= 2:
        # The plate the stock is screwed to at the back of the receiver.
        body.append(box("StockPlate", (-W + 0.001, REC_Y[0] - 0.006, 0.0655), (W - 0.001, REC_Y[0] + 0.001, z1 - 0.002), m["steel"], bevel=0.0015))
    pad = slab("ButtPad", fillet([(STOCK_END + 0.019, 0.1545, 0.006), (STOCK_END, 0.1555, 0.008), (STOCK_END, 0.0020, 0.008), (STOCK_END + 0.019, 0.0020, 0.006)], 5), -0.0205, 0.0205, m["rubber"])
    if ROUND >= 3:
        for k in range(11):
            zc = 0.012 + k * 0.0128
            cut(pad, box("pr", (-0.04, STOCK_END - 0.01, zc - 0.0018), (0.04, STOCK_END + 0.0022, zc + 0.0018), m["rubber"]))
    bevel_object(pad, 0.0025, 3, 35.0)
    body.append(smooth(pad, 35))
    if ROUND >= 2:
        # The rear sling loop at the bottom of the stock.
        body.append(torus("RearLoop", (0, STOCK_END + 0.050, 0.0030), (1, 0, 0), 0.0072, 0.0016, m["steel"], 20, 8))
        body.append(box("LoopBase", (-0.006, STOCK_END + 0.043, 0.0035), (0.006, STOCK_END + 0.057, 0.0105), m["steel"], bevel=0.0012))
    # --- the pistol grip: black polymer, a finger ridge at its front, stippled
    top_c = Vector((0.0, 0.0125, 0.058))
    foot_c = Vector((0.0, -0.0230, -0.046))
    axis = foot_c - top_c
    down = axis.normalized()
    fwd = Vector((0.0, -down.z, down.y))
    if fwd.y < 0:
        fwd = -fwd
    rings = []
    steps = [(0.0, 0.0225, 0.0130), (0.12, 0.0215, 0.0138), (0.30, 0.0205, 0.0146), (0.42, 0.0215, 0.0146), (0.55, 0.0205, 0.0146), (0.75, 0.0212, 0.0148), (0.95, 0.0220, 0.0148), (1.0, 0.0215, 0.0145), (1.03, 0.0195, 0.0128)]
    for t, a, b in steps:
        # The finger ridge: the front pushed out between the middle and ring finger.
        ridge = 0.0032 * math.exp(-((t - 0.42) / 0.06) ** 2) if ROUND >= 2 else 0.0
        c = top_c + axis * t + fwd * (ridge * 0.5 - 0.0015 * math.sin(math.pi * min(t, 1.0)))
        rings.append([tuple(c + Vector((px, 0, 0)) + fwd * (pv + (ridge * 0.5 if pv > 0 else 0.0))) for px, pv in superellipse(b, a, 2.4, 28)])
    gr = loft("Grip", rings, m["grip"])
    bevel_object(gr, 0.002, 2, 40.0)
    body.append(smooth(gr, 50))
    # --- the charging handle on the right: its slide in the slot, the arm out, the knob
    if ROUND >= 2:
        body.append(box("HandleSlide", (W - 0.004, HANDLE.y - 0.010, HANDLE.z - 0.0038), (W + 0.0012, HANDLE.y + 0.010, HANDLE.z + 0.0038), m["steel"], bevel=0.0008))
    body.append(box("HandleArm", (W, HANDLE.y - 0.0045, HANDLE.z - 0.0028), (HANDLE.x - 0.004, HANDLE.y + 0.0045, HANDLE.z + 0.0028), m["steel"], bevel=0.0009))
    knob = lathe("HandleKnob", (HANDLE.x, HANDLE.y, HANDLE.z - 0.010), (HANDLE.x, HANDLE.y, HANDLE.z + 0.010), [(0.0, 0.0040), (0.12, 0.0058), (0.88, 0.0058), (1.0, 0.0040)], m["polymer"], 20)
    body.append(smooth(knob, 50))
    if ROUND >= 3:
        for k in range(5):
            z = HANDLE.z - 0.007 + k * 0.0035
            body.append(cylinder("KnobRing", (HANDLE.x, HANDLE.y, z - 0.0004), (HANDLE.x, HANDLE.y, z + 0.0004), 0.0061, m["polymer"], 20))
    # --- rivets along the receiver, the plate of the stock, markings
    if ROUND >= 2:
        rivets = [(y, z) for y in (-0.030, 0.000, 0.030, 0.060) for z in (0.070, 0.128)] + [(0.240, 0.070), (0.240, 0.128), (0.225, 0.099), (0.135, 0.070)]
        for y, z in rivets:
            for side in (-1.0, 1.0):
                if side < 0 and FEED_Y[0] - 0.006 < y < FEED_Y[1] + 0.006 and z > FEED_Z[0] - 0.006:
                    continue
                r = cylinder("Rivet", (side * (W - 0.0003), y, z), (side * (W + 0.0008), y, z), 0.0021, m["steel"], 14)
                bevel_object(r, 0.0005, 2, 35.0)
                body.append(smooth(r, 50))
    if ROUND >= 3:
        body.append(engrave_left("NW-249 · 5,56 MM", Vector((-W - 0.0003, 0.128, 0.0745)), 0.0050, m["marking"]))
        body.append(engrave_left("№ 7716", Vector((-W - 0.0003, 0.030, 0.0905)), 0.0042, m["marking"]))
        body.append(engrave_right("S", Vector((0.0174, 0.1150, 0.0490)), 0.0040, m["white"]))
        body.append(engrave_right("F", Vector((0.0174, 0.0985, 0.0490)), 0.0040, m["red"]))
    # --- the feed (the Feed node): the tray sticking out of the opening, and the guide the
    # belt runs along up the side
    tray = box("FeedTray", (-W - 0.0035, FEED_Y[0] + 0.002, FEED_Z[0] - 0.0005), (-W + 0.004, FEED_Y[1] - 0.002, FEED_Z[0] + 0.0022), m["bright"], bevel=0.0007)
    feed.append(tray)
    if ROUND >= 2:
        # Its lip at the outer edge, the pawl that holds the belt, and the ledge under the
        # opening that the belt's links slide over.
        feed.append(box("TrayLip", (-W - 0.0045, FEED_Y[0] + 0.002, FEED_Z[0] - 0.0005), (-W - 0.0030, FEED_Y[1] - 0.002, FEED_Z[0] + 0.0045), m["bright"], bevel=0.0005))
        feed.append(box("Pawl", (-W + 0.0005, FEED_Y[0] + 0.020, FEED_Z[1] - 0.008), (-W + 0.0035, FEED_Y[0] + 0.030, FEED_Z[1] - 0.001), m["steel"], bevel=0.0005))
        ledge = slab("Ledge", fillet([(FEED_Y[0] - 0.004, FEED_Z[0] - 0.012, 0.0), (FEED_Y[1] + 0.004, FEED_Z[0] - 0.012, 0.0), (FEED_Y[1] + 0.004, FEED_Z[0] - 0.0015, 0.002), (FEED_Y[0] - 0.004, FEED_Z[0] - 0.0015, 0.002)], 3), -W - 0.0022, -W + 0.001, m["steel"])
        bevel_object(ledge, 0.0006, 2, 35.0)
        feed.append(smooth(ledge, 35))
        for y in (FEED_Y[0] + 0.002, FEED_Y[1] - 0.002):
            feed.append(cylinder("LedgeRivet", (-W - 0.0018, y, FEED_Z[0] - 0.007), (-W - 0.0030, y, FEED_Z[0] - 0.007), 0.0018, m["steel"], 12))
    # --- the box (the Magazine node): hard polymer, its lid, ribs on its sides, its latch;
    # the adapter it hangs from; the belt coming out of its mouth
    bx = box("Box", (BOX_X[0], BOX_Y[0], BOX_Z[0]), (BOX_X[1], BOX_Y[1], BOX_Z[1] - 0.006), m["box"], bevel=0.0045 if ROUND >= 2 else 0.003, segments=3)
    mag.append(smooth(bx, 35))
    lid = box("Lid", (BOX_X[0] - 0.0006, BOX_Y[0] - 0.0006, BOX_Z[1] - 0.0075), (BOX_X[1] + 0.0006, BOX_Y[1] + 0.0006, BOX_Z[1]), m["box"], bevel=0.003, segments=3)
    if ROUND >= 2:
        cut(lid, box("mouth", (BOX_X[0] + 0.0035, ROUND_Y[0] - 0.001, BOX_Z[1] - 0.012), (BOX_X[0] + 0.0185, ROUND_Y[1] + 0.001, BOX_Z[1] + 0.01), m["box"], bevel=0.0015))
    mag.append(smooth(lid, 35))
    if ROUND >= 2:
        mag.append(box("MouthInside", (BOX_X[0] + 0.004, ROUND_Y[0], BOX_Z[1] - 0.0115), (BOX_X[0] + 0.018, ROUND_Y[1], BOX_Z[1] - 0.0100), m["dark"]))
        # Ribs down the long sides, the latch on the front, the strap loops at the ends.
        for x in (BOX_X[0] - 0.0012, BOX_X[1] - 0.0004):
            for k in (0, 1, 4) if ROUND >= 3 else range(5):
                y = BOX_Y[0] + 0.016 + k * 0.017
                mag.append(box("BoxRib", (x, y - 0.0022, BOX_Z[0] + 0.008), (x + 0.0016, y + 0.0022, BOX_Z[1] - 0.012), m["box"], bevel=0.0006))
        mag.append(box("Latch", (-0.012, BOX_Y[1] - 0.0005, BOX_Z[1] - 0.026), (0.004, BOX_Y[1] + 0.0045, BOX_Z[1] - 0.004), m["box"], bevel=0.0012))
        mag.append(box("Adapter", (-0.0195, 0.1515, BOX_Z[1] - 0.001), (0.0115, 0.2035, REC_Z[0] + 0.005), m["polymer"], bevel=0.0015))
        for y in (BOX_Y[0] - 0.001, BOX_Y[1] + 0.001):
            mag.append(box("StrapLoop", (-0.020, y - 0.0018, BOX_Z[0] + 0.010), (0.002, y + 0.0018, BOX_Z[0] + 0.022), m["box"], bevel=0.0008))
        if ROUND >= 3:
            # (Between the ribs: its count, a hundred rounds.)
            mag.append(engrave_left("100", Vector((BOX_X[0] - 0.0004, BOX_Y[1] - 0.0265, -0.008)), 0.0105, m["marking"]))
    # The belt (v0.90): no longer part of the box. One round with its link ("BeltRound") and
    # one tracer ("BeltTracer"), each lying on the axis x = z = 0 with the belt running up
    # (+z) there; the game lays copies of them along belt_slots() and moves them one place
    # on with every shot (WeaponView.pose_belt).
    plain = cartridge(m, 0.0, 0.0, False)
    tracer = cartridge(m, 0.0, 0.0, True)
    if ROUND >= 2:
        plain.extend(belt_link(m, 0.0, 0.0, Vector((0.0, 1.0))))
        tracer.extend(belt_link(m, 0.0, 0.0, Vector((0.0, 1.0))))
    return body, feed, mag, sights, plain, tracer


def belt_slots():
    """The places of the rounds along the belt, from the box mouth to the feed opening."""
    out = []
    for p, d in belt_path():
        if p.y > REC_Z[1] - 0.004 or p.x > -0.010:
            break
        out.append((p, d))
    return out


VIEWS = [
    ("schraeg", (-0.95, 0.95, 0.48), (0.0, 0.2, 0.08), 55),
    ("links", (-1.95, 0.22, 0.07), (0.0, 0.22, 0.07), 70),
    ("rechts", (1.95, 0.22, 0.07), (0.0, 0.22, 0.07), 70),
    ("hinten_schraeg", (-0.50, -0.80, 0.48), (0.0, 0.12, 0.11), 50),
    ("oben", (0.0, 0.22, 1.95), (0.0, 0.22, 0.0), 70),
    ("unten", (-0.55, 0.2, -1.2), (0.0, 0.2, 0.05), 60),
    ("nah_visier", (-0.20, -0.14, 0.30), (0.0, 0.10, 0.16), 55),
    ("nah_gurt", (-0.42, 0.30, 0.12), (0.0, 0.18, 0.06), 55),
    ("nah_vorn", (-0.32, 0.86, 0.22), (0.0, 0.55, 0.12), 55),
    ("nah_rechts", (0.45, 0.02, 0.22), (0.0, 0.10, 0.10), 55),
]
CENTRE = (0.0, 0.22, 0.07)


def main():
    clear()
    m = make_materials()
    body_parts, feed_parts, mag_parts, sight_parts, round_parts, tracer_parts = build(m)
    body = join(body_parts, "Body")
    feed = join(feed_parts, "Feed")
    magazine = join(mag_parts, "Magazine")
    sights = join(sight_parts, "Sights")
    belt_round = join(round_parts, "BeltRound")
    belt_tracer = join(tracer_parts, "BeltTracer")
    parts = (body, feed, magazine, sights, belt_round, belt_tracer)
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if not NOBAKE:
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.002, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        images = bake(list(parts), "mg")
        final = final_material(images, "mg")
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    place_origin(magazine, MAG_ORIGIN)
    root = link(bpy.data.objects.new("MG", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "feed", triangles(feed), "magazine", triangles(magazine), "sights", triangles(sights),
          "all", sum(triangles(o) for o in parts), "texture", kit.TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None, VIEWS, CENTRE)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "rail %.4f irons %.4f rear %s post %s" % (RAIL_TOP, SIGHT_Z, godot((0, REAR_Y, SIGHT_Z)), godot((0, POST_Y, SIGHT_Z))))
    print("SPEC handle", godot(HANDLE), "magazine", godot(MAG_ORIGIN), "support", godot(SUPPORT),
          "magazine_foot", godot(((BOX_X[0] + BOX_X[1]) * 0.5, (BOX_Y[0] + BOX_Y[1]) * 0.5, BOX_Z[0])))
    # Where the rounds of the belt lie, in Godot space: x, y and the angle the belt runs at
    # there (radians about +z, 0 = straight up). WeaponView.GUNS["mg"].belt.
    print("SPEC belt [" + ", ".join("Vector3(%.4f, %.4f, %.4f)" % (p.x, p.y, math.atan2(-d.x, d.y)) for p, d in belt_slots()) + "]")
    if NOBAKE:
        return
    export(parts + (root,), OUT)


main()
