# Builds the WIRBEL, an assault rifle whose magazine spins, for Nachtwache, from nothing: a
# cylinder of 45 rounds lies along the barrel on top of the receiver, inside a cage that
# carries the sights, and turns a step with every shot. Every part is made here, bevelled,
# given its material, UV-unwrapped and baked into one texture set (base colour, roughness
# and metal, normal), then written as a GLB with the nodes
#   Wirbel > Body / Magazine (the drum, its origin on its own axis) / Bolt (the charging
#   handle on the left, its origin where it rests) / Trigger (its origin at its pivot).
#
#   blender --background --factory-startup --python tools/blender_make_wirbel.py -- [--round 5] [--tex 2048]
#           [--out assets/models/wirbel.glb] [--blend <file>] [--render <folder> --prefix runde1]
#
# --round: how far the polish goes (the five review rounds; the game uses the last).
# --render: fixed views of the finished, baked model (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the pistol grip. The glTF exporter turns this into Godot space (barrel along -Z, up +Y).
# The places the game needs (GUNS["wirbel"] in weapon_view.gd) are printed at the end.
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
ROUND = int(arg("--round", "5"))
TEX = int(arg("--tex", "2048"))
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "wirbel.glb")))
BLEND = arg("--blend")

RENDER = arg("--render")
PREFIX = arg("--prefix", "runde%d" % ROUND)
# ------------------------------------------------------------------ helpers
def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, bm, material):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.data.materials.append(material)
    return obj


def box(name, low, high, material, bevel=0.0, segments=2, where=None):
    """A box from the corner `low` to `high`; `bevel`: the radius of its edges."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    size = Vector(high) - Vector(low)
    centre = (Vector(high) + Vector(low)) * 0.5
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=centre, verts=bm.verts)
    obj = mesh_object(name, bm, material)
    if bevel > 0.0:
        bevel_object(obj, bevel, segments)
    return obj


def cylinder(name, start, end, radius, material, segments=24, bevel=0.0, cap_segments=1):
    start, end = Vector(start), Vector(end)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius, depth=(end - start).length)
    axis = (end - start).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((start + end) * 0.5) @ rot, verts=bm.verts)
    obj = mesh_object(name, bm, material)
    if bevel > 0.0:
        bevel_object(obj, bevel, cap_segments + 1)
    return obj


def cone(name, start, end, r0, r1, material, segments=16):
    """A frustum from `start` (radius r0) to `end` (radius r1)."""
    start, end = Vector(start), Vector(end)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r0, radius2=r1, depth=(end - start).length)
    rot = Vector((0, 0, 1)).rotation_difference((end - start).normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((start + end) * 0.5) @ rot, verts=bm.verts)
    return mesh_object(name, bm, material)


def prism(name, profile, y0, y1, material):
    """A body of the cross-section `profile` ((x, z) points, counter-clockwise seen from the
    front) from y0 to y1."""
    bm = bmesh.new()
    back = [bm.verts.new((x, y0, z)) for x, z in profile]
    front = [bm.verts.new((x, y1, z)) for x, z in profile]
    n = len(profile)
    bm.faces.new(list(reversed(back)))
    bm.faces.new(front)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


def upright(name, section, z0, z1, material):
    """A body of the cross-section `section` ((x, y) points round its outline) from z0 up to z1."""
    bm = bmesh.new()
    low = [bm.verts.new((x, y, z0)) for x, y in section]
    high = [bm.verts.new((x, y, z1)) for x, y in section]
    n = len(section)
    bm.faces.new(low)
    bm.faces.new(list(reversed(high)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((low[i], low[j], high[j], high[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


def bevel_object(obj, width, segments=2, angle=35.0):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = False
    apply(obj, mod)


def apply(obj, mod):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def cut(obj, cutter, solver="EXACT"):
    """Takes `cutter` out of `obj` and throws the cutter away."""
    mod = obj.modifiers.new("Cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = solver
    apply(obj, mod)
    bpy.data.objects.remove(cutter, do_unlink=True)


def union(obj, other):
    mod = obj.modifiers.new("Join", "BOOLEAN")
    mod.operation = "UNION"
    mod.object = other
    mod.solver = "EXACT"
    apply(obj, mod)
    bpy.data.objects.remove(other, do_unlink=True)


def rotate(obj, angle, axis, pivot):
    obj.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-Vector(pivot)))


def smooth(obj, angle=30.0):
    for p in obj.data.polygons:
        p.use_smooth = True
    if ROUND >= 3:
        # Edges sharper than `angle` stay hard; the rest is smooth.
        obj.data.set_sharp_from_angle(angle=math.radians(angle))
    else:
        try:
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
        except Exception:
            pass


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


# ------------------------------------------------------------------ materials (procedural, baked later)
def material(name, base, rough, metal, wear=0.0, grime=0.0, bump=0.0, bump_scale=900.0, stipple=False, worn=(0.48, 0.47, 0.45)):
    """A procedural material: `base` colour with a little noise in it, edges worn bright to
    `worn` (wear 0..1, by the curvature Cycles sees), grime in the hollows, an optional
    fine bump (brushed metal, or the stipple of a grip)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 160.0 if ROUND == 1 else 520.0
    noise.inputs["Detail"].default_value = 6.0
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    colour = nodes.new("ShaderNodeMix")
    colour.data_type = "RGBA"
    spread = 0.18 if ROUND == 1 else 0.1
    colour.inputs[6].default_value = (*[c * (1.0 - spread) for c in base], 1.0)
    colour.inputs[7].default_value = (*[min(1.0, c * (1.0 + spread)) for c in base], 1.0)
    links.new(noise.outputs["Fac"], colour.inputs[0])
    out_colour = colour.outputs[2]
    rough_node = nodes.new("ShaderNodeMath")
    rough_node.operation = "MULTIPLY_ADD"
    rough_node.inputs[1].default_value = 0.18
    rough_node.inputs[2].default_value = rough - 0.09
    links.new(noise.outputs["Fac"], rough_node.inputs[0])
    out_rough = rough_node.outputs[0]
    metal_node = nodes.new("ShaderNodeValue")
    metal_node.outputs[0].default_value = metal
    metal_node.name = "METAL"
    out_metal = metal_node.outputs[0]
    if wear > 0.0 or grime > 0.0:
        geo = nodes.new("ShaderNodeNewGeometry")
        wear_noise = nodes.new("ShaderNodeTexNoise")
        wear_noise.inputs["Scale"].default_value = 60.0
        wear_noise.inputs["Detail"].default_value = 8.0
        links.new(coords.outputs["Object"], wear_noise.inputs["Vector"])
        if wear > 0.0:
            edge = nodes.new("ShaderNodeMapRange")
            if ROUND >= 3:
                # Where a rounded normal of the bevel node leaves the true normal: an edge.
                bev = nodes.new("ShaderNodeBevel")
                bev.inputs["Radius"].default_value = 0.0009
                bev.samples = 8
                dot = nodes.new("ShaderNodeVectorMath")
                dot.operation = "DOT_PRODUCT"
                links.new(bev.outputs["Normal"], dot.inputs[0])
                links.new(geo.outputs["Normal"], dot.inputs[1])
                edge.inputs[1].default_value = 0.995
                edge.inputs[2].default_value = 0.93
                links.new(dot.outputs["Value"], edge.inputs[0])
            else:
                # Pointiness above 0.5 is a convex edge; the noise breaks it up.
                edge.inputs[1].default_value = 0.53
                edge.inputs[2].default_value = 0.6
                links.new(geo.outputs["Pointiness"], edge.inputs[0])
            breakup = nodes.new("ShaderNodeMath")
            breakup.operation = "MULTIPLY"
            links.new(edge.outputs[0], breakup.inputs[0])
            ramp = nodes.new("ShaderNodeMapRange")
            ramp.inputs[1].default_value = 0.42 - 0.12 * wear
            ramp.inputs[2].default_value = 0.6 - 0.1 * wear
            links.new(wear_noise.outputs["Fac"], ramp.inputs[0])
            links.new(ramp.outputs[0], breakup.inputs[1])
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            links.new(breakup.outputs[0], mix.inputs[0])
            links.new(out_colour, mix.inputs[6])
            mix.inputs[7].default_value = (*worn, 1.0)
            out_colour = mix.outputs[2]
            rmix = nodes.new("ShaderNodeMix")
            links.new(breakup.outputs[0], rmix.inputs[0])
            links.new(out_rough, rmix.inputs[2])
            rmix.inputs[3].default_value = 0.28
            out_rough = rmix.outputs[0]
            mmix = nodes.new("ShaderNodeMix")
            links.new(breakup.outputs[0], mmix.inputs[0])
            links.new(out_metal, mmix.inputs[2])
            mmix.inputs[3].default_value = 0.95 if metal > 0.5 else 0.3
            out_metal = mmix.outputs[0]
        if grime > 0.0:
            hollow = nodes.new("ShaderNodeMapRange")
            if ROUND >= 3:
                # Ambient occlusion over a few millimetres: the hollows and the corners.
                occ = nodes.new("ShaderNodeAmbientOcclusion")
                occ.inputs["Distance"].default_value = 0.005
                occ.samples = 16
                hollow.inputs[1].default_value = 0.9
                hollow.inputs[2].default_value = 0.45
                links.new(occ.outputs["AO"], hollow.inputs[0])
            else:
                # Below 0.47 is a hollow: darker and duller there.
                hollow.inputs[1].default_value = 0.47
                hollow.inputs[2].default_value = 0.40
                links.new(geo.outputs["Pointiness"], hollow.inputs[0])
            amount = nodes.new("ShaderNodeMath")
            amount.operation = "MULTIPLY"
            amount.inputs[1].default_value = grime
            links.new(hollow.outputs[0], amount.inputs[0])
            gmix = nodes.new("ShaderNodeMix")
            gmix.data_type = "RGBA"
            links.new(amount.outputs[0], gmix.inputs[0])
            links.new(out_colour, gmix.inputs[6])
            gmix.inputs[7].default_value = (0.018, 0.016, 0.013, 1.0)
            out_colour = gmix.outputs[2]
            grough = nodes.new("ShaderNodeMix")
            links.new(amount.outputs[0], grough.inputs[0])
            links.new(out_rough, grough.inputs[2])
            grough.inputs[3].default_value = 0.85
            out_rough = grough.outputs[0]
    links.new(out_colour, bsdf.inputs["Base Color"])
    links.new(out_rough, bsdf.inputs["Roughness"])
    links.new(out_metal, bsdf.inputs["Metallic"])
    mat["metal_socket"] = out_metal.node.name + ":" + str(list(out_metal.node.outputs).index(out_metal))
    mat["colour_socket"] = out_colour.node.name + ":" + str(list(out_colour.node.outputs).index(out_colour))
    if bump > 0.0:
        bump_node = nodes.new("ShaderNodeBump")
        bump_node.inputs["Strength"].default_value = bump
        bump_node.inputs["Distance"].default_value = 0.0004 if ROUND < 3 else 0.0009
        if stipple:
            cells = nodes.new("ShaderNodeTexVoronoi")
            cells.inputs["Scale"].default_value = bump_scale
            cells.feature = "DISTANCE_TO_EDGE"
            links.new(coords.outputs["Object"], cells.inputs["Vector"])
            links.new(cells.outputs["Distance"], bump_node.inputs["Height"])
        else:
            # Brushed: noise stretched along the slide.
            mapping = nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (1.0, 0.02, 1.0)
            links.new(coords.outputs["Object"], mapping.inputs["Vector"])
            lines = nodes.new("ShaderNodeTexNoise")
            lines.inputs["Scale"].default_value = bump_scale
            links.new(mapping.outputs["Vector"], lines.inputs["Vector"])
            links.new(lines.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    return mat



# ------------------------------------------------------------------ the measures
BORE_Z = 0.072                 # the bore axis above the middle of the grip
RECV_Y = (-0.075, 0.185) if ROUND == 1 else (-0.080, 0.190)   # the receiver from its back to its front (y)
RECV_Z = (0.040, 0.100) if ROUND == 1 else (0.034, 0.112)
RECV_W = 0.052
STOCK_BACK = -0.330            # the butt plate's face
MUZZLE_Y = 0.600               # the face of the muzzle brake: 93 cm over all
DRUM_Z = 0.146 if ROUND == 1 else 0.151   # the drum's axis
DRUM_Y = (0.020, 0.276)        # the drum from its back to its front
DRUM_R = 0.037 if ROUND == 1 else 0.034
CAGE_R = 0.046                 # (round 1) the cage's bars round the drum's axis
CAGE_Y = (-0.006, 0.302)       # the rear and front towers that carry the rail
RAIL_Z = 0.200                 # the top of the rail over the drum
GRIP_TILT = math.radians(-18.0)
GRIP_PIVOT = Vector((0.0, -0.010, RECV_Z[0] + 0.004))
FOREGRIP_Y = 0.355
BOLT_REST = Vector((-RECV_W / 2.0, 0.112, 0.074 if ROUND == 1 else 0.078))   # the charging handle on the left
BOLT_TRAVEL = 0.075            # how far it runs back with every shot
TRIGGER_PIVOT = Vector((0.0, 0.020, RECV_Z[0] - 0.002))
FLUTES = 8                     # grooves in the drum: one shot turns it on by one
GUARD_R = 0.029 if ROUND == 1 else 0.033   # the handguard round the bore


def make_materials():
    if ROUND == 1:
        steel = material("steel", (0.065, 0.068, 0.07), 0.45, 0.85)
        polymer = material("polymer", (0.075, 0.078, 0.06), 0.7, 0.0)
        grip = polymer
        dark = material("dark", (0.01, 0.01, 0.01), 0.8, 0.2)
        blued = steel
        brass = material("brass", (0.55, 0.40, 0.16), 0.35, 1.0)
        accent = material("accent", (0.75, 0.25, 0.05), 0.5, 0.0)
        rubber = polymer
    else:
        wear = {2: 0.6, 3: 0.9}.get(ROUND, 1.0)
        steel = material("steel", (0.058, 0.061, 0.064) if ROUND == 2 else (0.048, 0.05, 0.053), 0.42, 0.85, wear=wear, grime=0.7, bump=0.08 if ROUND >= 3 else 0.0, bump_scale=900.0)
        polymer = material("polymer", (0.072, 0.075, 0.055) if ROUND == 2 else (0.058, 0.06, 0.045), 0.68, 0.0, wear=0.35 * wear, grime=0.8, worn=(0.2, 0.2, 0.17))
        grip = material("grip", (0.06, 0.063, 0.047) if ROUND == 2 else (0.048, 0.05, 0.038), 0.8, 0.0, wear=0.3 * wear, grime=0.9, bump=0.55 if ROUND == 2 else 0.9, bump_scale=1400.0 if ROUND == 2 else 2200.0, stipple=True, worn=(0.18, 0.18, 0.15))
        dark = material("dark", (0.008, 0.008, 0.008), 0.8, 0.3)
        blued = material("blued", (0.03, 0.033, 0.04), 0.38, 0.9, wear=0.8 * wear, grime=0.5)
        brass = material("brass", (0.58, 0.42, 0.17), 0.3, 1.0, wear=0.4 * wear, grime=0.6, worn=(0.8, 0.65, 0.35))
        accent = material("accent", (0.72, 0.22, 0.04), 0.5, 0.0, wear=0.5 * wear, grime=0.5, worn=(0.4, 0.38, 0.35))
        rubber = material("rubber", (0.025, 0.025, 0.024), 0.9, 0.0, grime=0.5)
        if ROUND == 4:
            accent = material("accent", (0.9, 0.3, 0.04), 0.45, 0.0, wear=0.5 * wear, grime=0.35, worn=(0.4, 0.38, 0.35))
        elif ROUND >= 5:
            accent = material("accent", (0.7, 0.2, 0.03), 0.5, 0.0, wear=0.8 * wear, grime=0.6, worn=(0.3, 0.3, 0.28))
    marking = material("marking", (0.2, 0.2, 0.19), 0.55, 0.6) if ROUND >= 3 else steel
    copper = material("copper", (0.55, 0.26, 0.14), 0.32, 1.0, wear=0.3, grime=0.5, worn=(0.8, 0.5, 0.35)) if ROUND >= 4 else brass
    return {"steel": steel, "polymer": polymer, "grip": grip, "dark": dark, "blued": blued, "brass": brass, "accent": accent, "rubber": rubber, "marking": marking, "copper": copper}


def ring_section(r, n=24, start=0.0):
    return [(math.cos(start + math.tau * i / n) * r, math.sin(start + math.tau * i / n) * r) for i in range(n)]


def along(name, section, y0, y1, centre, material):
    """A body of the cross-section `section` ((x, z) points round its outline, about `centre`
    (x, z)) from y0 to y1."""
    return prism(name, [(centre[0] + x, centre[1] + z) for x, z in section], y0, y1, material)


# ------------------------------------------------------------------ the parts
def slab(name, outline, x0, x1, material):
    """A body of the side outline `outline` ((y, z) points round it) from x0 to x1."""
    bm = bmesh.new()
    left = [bm.verts.new((x0, y, z)) for y, z in outline]
    right = [bm.verts.new((x1, y, z)) for y, z in outline]
    n = len(outline)
    bm.faces.new(left)
    bm.faces.new(list(reversed(right)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


# (From round 5) the iron sights, a node of their own ("Sights"): the game lays them down
# when a sight is fitted, so that the front post does not fill a scope (seen in the game).
SIGHTS = []


def build(m):
    body, drum, bolt, trig = [], [], [], []
    w = RECV_W / 2.0
    z0, z1 = RECV_Z
    # --- the receiver: a long box, its top edges chamfered
    c = 0.006
    recv = prism("Receiver", [(-w, z0), (w, z0), (w, z1 - c), (w - c, z1), (-w + c, z1), (-w, z1 - c)], RECV_Y[0], RECV_Y[1], m["steel"])
    if ROUND >= 2:
        # The ejection port on the right (where spent cases leave), a slot on the left the
        # charging handle runs in.
        port = box("port", (w - 0.006, 0.030, BORE_Z - 0.009), (w + 0.01, 0.088, BORE_Z + 0.015), m["steel"], bevel=0.0015)
        cut(recv, port)
        slot = box("slot", (-w - 0.01, BOLT_REST.y - BOLT_TRAVEL - 0.008, BOLT_REST.z - 0.0045), (-w + 0.006, BOLT_REST.y + 0.008, BOLT_REST.z + 0.0045), m["steel"], bevel=0.001)
        cut(recv, slot)
    if ROUND >= 4:
        # (Round 3's receiver sides were one flat sheet.) A shallow milled panel behind the
        # port on each side and a seam line along the bottom break them up.
        for side in (-1.0, 1.0):
            panel = box("panel", (side * w - 0.0016, -0.068, z0 + 0.024), (side * w + 0.0016, 0.012, z1 - 0.014), m["steel"], bevel=0.0012)
            cut(recv, panel)
            seam = box("seam", (side * w - 0.0008, RECV_Y[0] - 0.01, z0 + 0.0035), (side * w + 0.0008, RECV_Y[1] + 0.01, z0 + 0.0050), m["steel"])
            cut(recv, seam, "EXACT")
    bevel_object(recv, 0.0012, 2, 30.0)
    smooth(recv, 35)
    body.append(recv)
    if ROUND >= 2:
        # What lies behind the port and the slot: the dark of the action.
        body.append(box("Action", (-w + 0.004, 0.026, BORE_Z - 0.012), (w - 0.004, 0.092, BORE_Z + 0.018), m["dark"]))
        body.append(box("Track", (-w + 0.003, BOLT_REST.y - BOLT_TRAVEL - 0.01, BOLT_REST.z - 0.006), (-w + 0.0065, BOLT_REST.y + 0.01, BOLT_REST.z + 0.006), m["dark"]))
    lower = box("Lower", (-w + 0.004, -0.06, z0 - 0.016), (w - 0.004, 0.15, z0 + 0.004), m["polymer"], bevel=0.004, segments=3)
    smooth(lower, 35)
    body.append(lower)
    # --- the stock
    if ROUND == 1:
        top = box("StockTop", (-0.017, STOCK_BACK + 0.02, 0.070), (0.017, RECV_Y[0] + 0.004, 0.098), m["polymer"], bevel=0.005, segments=3)
        strut = box("Strut", (-0.012, STOCK_BACK + 0.03, -0.012), (0.012, RECV_Y[0] + 0.02, 0.006), m["polymer"], bevel=0.004, segments=3)
        rotate(strut, math.radians(-17.0), "X", Vector((0, RECV_Y[0] + 0.01, 0.0)))
        butt = box("Butt", (-0.021, STOCK_BACK, -0.060), (0.021, STOCK_BACK + 0.034, 0.108), m["polymer"], bevel=0.007, segments=3)
        stock_parts = [top, strut, butt]
    else:
        # One skeleton stock: a closed frame of polymer from the receiver to the butt, the
        # hole through it rounded, its edges taken off.
        outline = [(RECV_Y[0] + 0.006, z1 - 0.004), (-0.20, z1 - 0.010), (STOCK_BACK + 0.030, z1 - 0.002), (STOCK_BACK + 0.008, z1 + 0.004),
                   (STOCK_BACK + 0.004, -0.058), (STOCK_BACK + 0.040, -0.064), (-0.170, -0.020), (RECV_Y[0] + 0.006, z0 + 0.002)]
        stock = slab("Stock", outline, -0.0175, 0.0175, m["polymer"])
        hole = [(RECV_Y[0] - 0.026, z1 - 0.026), (-0.196, z1 - 0.032), (STOCK_BACK + 0.050, z1 - 0.026), (STOCK_BACK + 0.044, -0.034), (-0.178, -0.004), (RECV_Y[0] - 0.030, z0 + 0.008)]
        cutter = slab("hole", hole, -0.03, 0.03, m["polymer"])
        bevel_object(cutter, 0.006, 3, 30.0)
        cut(stock, cutter)
        bevel_object(stock, 0.0035, 3, 30.0)
        stock_parts = [stock]
    pad = box("Pad", (-0.022, STOCK_BACK - 0.012, -0.066), (0.022, STOCK_BACK + 0.004, 0.114), m["rubber"], bevel=0.006, segments=3)
    stock_parts.append(pad)
    for o in stock_parts:
        smooth(o, 35)
        body.append(o)
    # --- the grip, leaning back
    section = []
    for i in range(24):
        a = math.tau * i / 24
        y = math.cos(a) * 0.025 - 0.004
        x = math.sin(a) * (0.0155 if math.cos(a) < 0.0 else 0.0145)
        section.append((x, y))
    grip = upright("Grip", section, -0.080, GRIP_PIVOT.z + 0.004, m["grip"])
    bevel_object(grip, 0.004, 3, 40.0)
    if ROUND >= 2:
        for i in range(3):
            z = 0.012 - i * 0.026
            groove = cylinder("fg", (-0.03, 0.0245, z), (0.03, 0.0245, z), 0.010, m["grip"], 20)
            cut(grip, groove)
    rotate(grip, GRIP_TILT, "X", GRIP_PIVOT)
    smooth(grip, 40)
    body.append(grip)
    # --- the trigger guard and the trigger (its own object, turning about its pivot)
    guard = box("Guard", (-0.0045, 0.0, z0 - 0.050), (0.0045, 0.072, z0 - 0.012), m["polymer"], bevel=0.004, segments=3)
    opening = box("open", (-0.02, 0.006, z0 - 0.044), (0.02, 0.066, z0), m["polymer"], bevel=0.003)
    cut(guard, opening)
    smooth(guard, 40)
    body.append(guard)
    t = box("TriggerBlade", (-0.0032, TRIGGER_PIVOT.y - 0.004, z0 - 0.040), (0.0032, TRIGGER_PIVOT.y + 0.003, TRIGGER_PIVOT.z), m["blued"], bevel=0.0012)
    rotate(t, math.radians(-12.0), "X", TRIGGER_PIVOT)
    trig.append(t)
    # --- barrel, handguard, gas block and the muzzle brake
    barrel = cylinder("Barrel", (0, RECV_Y[1] - 0.01, BORE_Z), (0, MUZZLE_Y - 0.05, BORE_Z), 0.0095, m["blued"], 24)
    body.append(barrel)
    hand = along("Handguard", ring_section(GUARD_R, 8, math.pi / 8), RECV_Y[1], 0.43, (0.0, BORE_Z), m["polymer"])
    if ROUND >= 3:
        # Bevelled first, then hollowed and vented (round 2 bevelled after its cuts, and its
        # vents ran together into one black bar): short rounded slots in two rows, with the
        # dark of the inside behind them.
        bevel_object(hand, 0.002, 2, 30.0)
        hollow = cylinder("hollow", (0, RECV_Y[1] - 0.01, BORE_Z), (0, 0.44, BORE_Z), GUARD_R - 0.0045, m["polymer"], 24)
        cut(hand, hollow)
        for side in (-1.0, 1.0):
            for row in range(2):
                for i in range(6):
                    y = RECV_Y[1] + 0.026 + i * 0.034 + row * 0.017
                    zc = BORE_Z + 0.009 - row * 0.016
                    vent = box("v", (side * GUARD_R - 0.010, y, zc - 0.0038), (side * GUARD_R + 0.010, y + 0.019, zc + 0.0038), m["polymer"], bevel=0.0035, segments=3)
                    cut(hand, vent)
        inner = cylinder("Inner", (0, RECV_Y[1] + 0.004, BORE_Z), (0, 0.426, BORE_Z), GUARD_R - 0.009, m["dark"], 16)
        body.append(inner)
    elif ROUND == 2:
        # Vents down both sides in two rows, and the inside dark through them.
        for side in (-1.0, 1.0):
            for row in range(2):
                for i in range(5):
                    y = RECV_Y[1] + 0.03 + i * 0.042
                    zc = BORE_Z + 0.008 - row * 0.016
                    vent = box("v", (side * GUARD_R - 0.012, y, zc - 0.0045), (side * GUARD_R + 0.012, y + 0.028, zc + 0.0045), m["polymer"], bevel=0.002)
                    cut(hand, vent)
        inner = cylinder("Inner", (0, RECV_Y[1] + 0.004, BORE_Z), (0, 0.426, BORE_Z), GUARD_R - 0.006, m["dark"], 16)
        body.append(inner)
    if ROUND < 3:
        bevel_object(hand, 0.002, 2, 30.0)
    smooth(hand, 30)
    body.append(hand)
    gas = box("GasBlock", (-0.013, 0.440, BORE_Z - 0.013), (0.013, 0.468, BORE_Z + 0.028), m["steel"], bevel=0.003)
    body.append(gas)
    brake = cylinder("Brake", (0, MUZZLE_Y - 0.072, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.016, m["steel"], 24, bevel=0.002)
    bore = cylinder("bore", (0, MUZZLE_Y - 0.09, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0062, m["steel"], 20)
    cut(brake, bore)
    if ROUND >= 2:
        for i in range(3):
            y = MUZZLE_Y - 0.060 + i * 0.017
            port = box("bp", (-0.03, y, BORE_Z - 0.006), (0.03, y + 0.009, BORE_Z + 0.006), m["steel"], bevel=0.0015)
            cut(brake, port)
    smooth(brake, 35)
    body.append(brake)
    inside = cylinder("Bore", (0, MUZZLE_Y - 0.07, BORE_Z), (0, MUZZLE_Y - 0.004, BORE_Z), 0.0061, m["dark"], 16)
    body.append(inside)
    # --- the foregrip under the handguard
    fg = cylinder("Foregrip", (0, FOREGRIP_Y, BORE_Z - GUARD_R + 0.004), (0, FOREGRIP_Y, BORE_Z - GUARD_R - 0.090), 0.016, m["grip"], 20, bevel=0.003)
    rotate(fg, math.radians(8.0), "X", Vector((0, FOREGRIP_Y, BORE_Z - GUARD_R)))
    smooth(fg, 35)
    body.append(fg)
    # --- what carries the drum and the rail
    if ROUND == 1:
        for y0, y1 in ((CAGE_Y[0], CAGE_Y[0] + 0.016), (CAGE_Y[1] - 0.016, CAGE_Y[1])):
            plate = box("CagePlate", (-0.030, y0, z1 - 0.004), (0.030, y1, RAIL_Z - 0.006), m["steel"], bevel=0.003, segments=2)
            hole = cylinder("hole", (0, y0 - 0.01, DRUM_Z), (0, y1 + 0.01, DRUM_Z), DRUM_R + 0.002, m["steel"], 28)
            cut(plate, hole)
            smooth(plate, 35)
            body.append(plate)
        for a in (90.0, 200.0, 340.0):
            r = math.radians(a)
            p = Vector((math.cos(r) * CAGE_R, 0, DRUM_Z + math.sin(r) * CAGE_R))
            body.append(cylinder("Bar", (p.x, CAGE_Y[0] + 0.008, p.z), (p.x, CAGE_Y[1] - 0.008, p.z), 0.0042, m["steel"], 12))
    else:
        # A trough on the receiver that cradles the drum's lower half ...
        # (Round 2: the trough ran to the faces of the towers and shared them - two faces in one
        # plane, which baked black. From round 3 it ends inside them, and they are wider.)
        inset = 0.0 if ROUND == 2 else 0.005
        tw = 0.034 if ROUND == 2 else 0.032
        trough = box("Trough", (-tw, CAGE_Y[0] + inset, z1 - 0.006), (tw, CAGE_Y[1] - inset, DRUM_Z + 0.006), m["steel"], bevel=0.003, segments=2)
        bed = cylinder("bed", (0, CAGE_Y[0] + 0.012, DRUM_Z), (0, CAGE_Y[1] - 0.012, DRUM_Z), DRUM_R + 0.003, m["steel"], 40)
        cut(trough, bed)
        if ROUND >= 5:
            # (Round 4: both sides of the trough rose to just below the drum's axis.) The left
            # side, the one the shooter looks at, is cut down to a low lip: the rounds can be
            # seen turning, and the drum comes out that way, sideways and a little up, under
            # the rail and over the lip.
            gate = box("gate", (-0.05, CAGE_Y[0] + 0.020, DRUM_Z - 0.030), (-0.012, CAGE_Y[1] - 0.020, DRUM_Z + 0.02), m["steel"], bevel=0.004, segments=3)
            cut(trough, gate)
        smooth(trough, 35)
        body.append(trough)
        # ... and two towers that carry the rail over it: the rear one a ring the end of the
        # drum shows through, the front one solid round the axle.
        for y0, y1, open_ in ((CAGE_Y[0], CAGE_Y[0] + 0.018, True), (CAGE_Y[1] - 0.018, CAGE_Y[1], False)):
            half = 0.030 if ROUND == 2 else 0.035
            tower = slab("Tower", [(y0, z1 - 0.004), (y1, z1 - 0.004), (y1, RAIL_Z - 0.008), (y0, RAIL_Z - 0.008)], -half, half, m["steel"])
            bevel_object(tower, 0.004, 2, 30.0)
            if open_:
                window = cylinder("win", (0, y0 - 0.01, DRUM_Z), (0, y1 + 0.01, DRUM_Z), DRUM_R - 0.004, m["steel"], 32)
                cut(tower, window)
            smooth(tower, 35)
            body.append(tower)
    rail = box("Rail", (-0.011, CAGE_Y[0] - 0.012, RAIL_Z - 0.010), (0.011, CAGE_Y[1] + 0.004, RAIL_Z), m["steel"], bevel=0.0015)
    if ROUND >= 2:
        # Cross slots of a rail.
        for i in range(14):
            y = CAGE_Y[0] + 0.004 + i * 0.0215
            notch = box("n", (-0.02, y, RAIL_Z - 0.004), (0.02, y + 0.008, RAIL_Z + 0.01), m["steel"])
            cut(rail, notch, "EXACT")
    body.append(rail)
    # --- sights on the rail: an aperture at the back, a post at the front
    if ROUND < 5:
        rear = box("RearSight", (-0.010, CAGE_Y[0] - 0.010, RAIL_Z - 0.001), (0.010, CAGE_Y[0] + 0.004, RAIL_Z + 0.020), m["blued"], bevel=0.0015)
        peep = cylinder("peep", (0, CAGE_Y[0] - 0.02, RAIL_Z + 0.013), (0, CAGE_Y[0] + 0.02, RAIL_Z + 0.013), 0.0022, m["blued"], 16)
    else:
        # (Seen in the game, round 5's first aperture - a hole of 4 mm in a block of 2 cm -
        # filled the picture when aimed and showed the post as a speck.) A ghost ring: a
        # thin ring of 13 mm on a short, narrow foot, the post framed inside it.
        rear = box("RearSight", (-0.0045, CAGE_Y[0] - 0.008, RAIL_Z - 0.001), (0.0045, CAGE_Y[0] + 0.002, RAIL_Z + 0.006), m["blued"], bevel=0.0012)
        ring = cylinder("Ring", (0, CAGE_Y[0] - 0.006, RAIL_Z + 0.013), (0, CAGE_Y[0], RAIL_Z + 0.013), 0.0085, m["blued"], 32)
        union(rear, ring)
        bevel_object(rear, 0.0008, 2, 30.0)
        peep = cylinder("peep", (0, CAGE_Y[0] - 0.02, RAIL_Z + 0.013), (0, CAGE_Y[0] + 0.02, RAIL_Z + 0.013), 0.0065, m["blued"], 32)
    cut(rear, peep)
    (SIGHTS if ROUND >= 5 else body).append(rear)
    # (Round 5: the tip of the post level with the middle of the aperture, 13 mm over the
    # rail, so that the line over both is parallel to the bore.)
    tip = 0.017 if ROUND < 5 else 0.013
    post = box("FrontPost", (-0.0014, CAGE_Y[1] - 0.008, RAIL_Z - 0.001), (0.0014, CAGE_Y[1] - 0.002, RAIL_Z + tip), m["blued"], bevel=0.0006)
    (SIGHTS if ROUND >= 5 else body).append(post)
    if ROUND >= 2:
        # Ears that guard the front post.
        for side in (-1.0, 1.0):
            (SIGHTS if ROUND >= 5 else body).append(box("Ear", (side * 0.008 - 0.0018, CAGE_Y[1] - 0.010, RAIL_Z - 0.001), (side * 0.008 + 0.0018, CAGE_Y[1], RAIL_Z + tip + 0.002), m["blued"], bevel=0.0008))
    # --- the drum
    core = cylinder("Drum", (0, DRUM_Y[0], DRUM_Z), (0, DRUM_Y[1], DRUM_Z), DRUM_R, m["steel"], 32 if ROUND == 1 else 48, bevel=0.002)
    if ROUND >= 2:
        # Flutes down its length, each with a row of brass in it: they flicker as it turns.
        for k in range(FLUTES):
            a = math.tau * (k + 0.5) / FLUTES
            groove = box("fl", (-0.0055, DRUM_Y[0] + 0.012, DRUM_R - 0.008), (0.0055, DRUM_Y[1] - 0.012, DRUM_R + 0.01), m["steel"], bevel=0.002)
            groove.data.transform(Matrix.Translation((0, 0, DRUM_Z)) @ Matrix.Rotation(a, 4, "Y"))
            cut(core, groove)
            p = Matrix.Rotation(a, 4, "Y") @ Vector((0, 0, DRUM_R - 0.0075))
            if ROUND >= 4:
                # (Round 3 laid one long brass rod in each flute: it read as a pipe.) Four
                # cartridges nose to tail instead - case, shoulder, neck, copper bullet - so the
                # gaps and tips flicker past as the drum turns.
                for i in range(4):
                    y = DRUM_Y[0] + 0.017 + i * 0.0555
                    # (Round 5: ten sides instead of fourteen - round 4's drum alone had 10,000
                    # triangles; at the size it is seen, ten are as round.)
                    n = 14 if ROUND == 4 else 10
                    drum.append(cylinder("Case", (p.x, y, DRUM_Z + p.z), (p.x, y + 0.033, DRUM_Z + p.z), 0.0046, m["brass"], n))
                    drum.append(cone("Shoulder", (p.x, y + 0.033, DRUM_Z + p.z), (p.x, y + 0.037, DRUM_Z + p.z), 0.0046, 0.0031, m["brass"], n))
                    drum.append(cylinder("Neck", (p.x, y + 0.037, DRUM_Z + p.z), (p.x, y + 0.042, DRUM_Z + p.z), 0.0031, m["brass"], n))
                    drum.append(cone("Bullet", (p.x, y + 0.042, DRUM_Z + p.z), (p.x, y + 0.0525, DRUM_Z + p.z), 0.0029, 0.0007, m["copper"], n))
            else:
                drum.append(cylinder("Round", (p.x, DRUM_Y[0] + 0.016, DRUM_Z + p.z), (p.x, DRUM_Y[1] - 0.016, DRUM_Z + p.z), 0.0045, m["brass"], 12))
    smooth(core, 35)
    drum.append(core)
    if ROUND == 1:
        stripe = box("Index", (-0.004, DRUM_Y[0] - 0.003, DRUM_Z + DRUM_R - 0.012), (0.004, DRUM_Y[0] + 0.002, DRUM_Z + DRUM_R - 0.002), m["accent"])
        drum.append(stripe)
    else:
        # The end that looks at the shooter: a wheel of spokes, an orange mark on its rim.
        cap = cylinder("Cap", (0, DRUM_Y[0] - 0.006, DRUM_Z), (0, DRUM_Y[0] + 0.002, DRUM_Z), DRUM_R - 0.006, m["blued"], 40, bevel=0.0015)
        for k in range(FLUTES):
            a = math.tau * (k + 0.5) / FLUTES
            p = Matrix.Rotation(a, 4, "Y") @ Vector((0, 0, (DRUM_R - 0.006) * 0.56))
            pocket = cylinder("pk", (p.x, DRUM_Y[0] - 0.01, DRUM_Z + p.z), (p.x, DRUM_Y[0] - 0.002, DRUM_Z + p.z), 0.0065, m["blued"], 16)
            cut(cap, pocket)
            if ROUND >= 3:
                # The base of a round in each pocket: brass with a primer, catching the light.
                drum.append(cylinder("Base", (p.x, DRUM_Y[0] - 0.004, DRUM_Z + p.z), (p.x, DRUM_Y[0] + 0.001, DRUM_Z + p.z), 0.0058, m["brass"], 16))
                drum.append(cylinder("Primer", (p.x, DRUM_Y[0] - 0.0045, DRUM_Z + p.z), (p.x, DRUM_Y[0] - 0.003, DRUM_Z + p.z), 0.0022, m["steel"], 12))
        smooth(cap, 35)
        drum.append(cap)
        drum.append(cylinder("Hub", (0, DRUM_Y[0] - 0.009, DRUM_Z), (0, DRUM_Y[0] - 0.004, DRUM_Z), 0.008, m["steel"], 20, bevel=0.001))
        if ROUND >= 3:
            # A wedge of orange on the rim of the drum's end, and a stripe down one rib: one
            # look tells how far it has turned.
            # (Round 3 put both on top, under the rail, where nobody saw them; from round 4 they
            # sit on the left rib, the side the shooter looks at, and are larger.)
            turn = Matrix.Rotation(-math.pi / 2.0, 4, "Y") if ROUND >= 4 else Matrix.Identity(4)
            big = 1.5 if ROUND >= 4 else 1.0
            mark = prism("Index", [(-0.006 * big, DRUM_R - 0.0002), (0.006 * big, DRUM_R - 0.0002), (0.0, DRUM_R - 0.011 * big)], DRUM_Y[0] - 0.007, DRUM_Y[0] - 0.003, m["accent"])
            mark.data.transform(Matrix.Translation((0, 0, DRUM_Z)) @ turn)
            drum.append(mark)
            # (Round 4's band, 8 mm of flat orange, looked like tape and drowned the rounds: from
            # round 5 a line of 3 mm, set into the rib.)
            sw = 0.0028 * big if ROUND == 4 else 0.0015
            stripe = box("Stripe", (-sw, DRUM_Y[0] + 0.004, DRUM_R - 0.0012), (sw, DRUM_Y[1] - 0.004, DRUM_R + (0.0004 if ROUND < 5 else 0.0001)), m["accent"])
            stripe.data.transform(Matrix.Translation((0, 0, DRUM_Z)) @ turn)
            drum.append(stripe)
        else:
            mark = box("Index", (-0.0035, DRUM_Y[0] - 0.0075, DRUM_Z + DRUM_R - 0.0175), (0.0035, DRUM_Y[0] - 0.0045, DRUM_Z + DRUM_R - 0.0065), m["accent"], bevel=0.0008)
            drum.append(mark)
    # --- the charging handle on the left (its own object: it runs back with every shot)
    knob = cylinder("Handle", (BOLT_REST.x + 0.004, BOLT_REST.y, BOLT_REST.z), (BOLT_REST.x - 0.022, BOLT_REST.y, BOLT_REST.z), 0.0055, m["blued"], 16)
    cap = cylinder("Knob", (BOLT_REST.x - 0.018, BOLT_REST.y, BOLT_REST.z), (BOLT_REST.x - 0.030, BOLT_REST.y, BOLT_REST.z), 0.0085, m["polymer"], 18, bevel=0.002)
    bolt.extend([knob, cap])
    if ROUND == 1:
        port = box("Port", (w - 0.002, 0.030, BORE_Z - 0.008), (w + 0.0005, 0.085, BORE_Z + 0.014), m["dark"])
        body.append(port)
    sel = cylinder("Selector", (-w - 0.002, -0.040, z0 + 0.012), (-w + 0.001, -0.040, z0 + 0.012), 0.0055, m["blued"], 18)
    body.append(sel)
    if ROUND >= 2:
        lever = box("Lever", (-w - 0.0035, -0.044, z0 + 0.009), (-w - 0.0012, -0.022, z0 + 0.015), m["blued"], bevel=0.0007)
        rotate(lever, math.radians(-20.0), "X", Vector((0, -0.040, z0 + 0.012)))
        body.append(lever)
        # Pins through the receiver.
        for y, z in ((-0.050, z0 + 0.008), (0.140 if ROUND < 4 else 0.178, z0 + 0.008), (0.165, z1 - 0.012)):
            body.append(cylinder("Pin", (-w - 0.0006, y, z), (w + 0.0006, y, z), 0.0022, m["steel"], 14))
    if ROUND >= 3:
        # Screws in the towers, the name on the left of the receiver, a sling loop at the
        # butt and a cheek rest on the stock.
        for y in (CAGE_Y[0] + 0.009, CAGE_Y[1] - 0.009):
            for zz in (z1 + 0.012, RAIL_Z - 0.022):
                for side in (-1.0, 1.0):
                    screw = cylinder("Screw", (side * 0.0345, y, zz), (side * 0.0365, y, zz), 0.0028, m["steel"], 16)
                    slot = box("sl", (side * 0.0368 - 0.0007, y - 0.0028, zz - 0.0006), (side * 0.0368 + 0.0007, y + 0.0028, zz + 0.0006), m["steel"])
                    cut(screw, slot, "EXACT")
                    body.append(screw)
        body.append(engrave_left("WIRBEL  W-45", Vector((-w - 0.00012, 0.150, z0 + 0.014)), 0.0085, m["marking"]))
        body.append(engrave_left("5,56   SERIE 07", Vector((-w - 0.00012, 0.150, z0 + 0.005)), 0.0046, m["marking"]))
        loop = cylinder("Loop", (-0.0185, STOCK_BACK + 0.024, -0.030), (0.0185, STOCK_BACK + 0.024, -0.030), 0.0034, m["steel"], 14)
        body.append(loop)
        riser = box("Riser", (-0.016, -0.235, z1 - 0.012), (0.016, -0.125, z1 + 0.004), m["polymer"], bevel=0.005, segments=3)
        smooth(riser, 35)
        body.append(riser)
    return body, drum, bolt, trig


def engrave_left(text, at, size, material):
    """Flat lettering on the left face of the receiver, reading from the muzzle backwards
    as one sees it from the left; 'at' is where its first letter begins."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    letters = link(bpy.data.objects.new("Marking", curve))
    bpy.context.view_layer.objects.active = letters
    bpy.ops.object.select_all(action="DESELECT")
    letters.select_set(True)
    bpy.ops.object.convert(target="MESH")
    letters = bpy.context.view_layer.objects.active
    turn = Matrix(((0.0, 0.0, -1.0, 0.0), (-1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    letters.data.transform(Matrix.Translation(at) @ turn)
    letters.data.materials.clear()
    letters.data.materials.append(material)
    return letters


# ------------------------------------------------------------------ bake
def bake(objs):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    scene.render.bake.margin = 6
    images = {}
    for key, colour_space in (("base", "sRGB"), ("rough", "Non-Color"), ("metal", "Non-Color"), ("normal", "Non-Color")):
        img = bpy.data.images.new("wirbel_" + key, TEX, TEX, alpha=False, float_buffer=False)
        img.colorspace_settings.name = colour_space
        images[key] = img
    mats = set()
    for o in objs:
        for slot in o.material_slots:
            mats.add(slot.material)
    targets = {}
    for mat in mats:
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.name = "BAKE"
        targets[mat] = node
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

    def run(kind, image, **extra):
        for mat, node in targets.items():
            node.image = image
            mat.node_tree.nodes.active = node
        bpy.ops.object.bake(type=kind, **extra)

    run("ROUGHNESS", images["rough"])
    run("NORMAL", images["normal"])
    # Base colour and metal: each through an emission that carries it.
    for key, socket in (("metal", "metal_socket"), ("base", "colour_socket")):
        for mat in mats:
            nt = mat.node_tree
            name, index = mat[socket].split(":")
            emit = nt.nodes.new("ShaderNodeEmission")
            nt.links.new(nt.nodes[name].outputs[int(index)], emit.inputs["Color"])
            nt.links.new(emit.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
        run("EMIT", images[key])
    import numpy
    rough = numpy.array(images["rough"].pixels[:], dtype=numpy.float32)
    metal = numpy.array(images["metal"].pixels[:], dtype=numpy.float32)
    orm = numpy.ones_like(rough)
    orm[1::4] = rough[0::4]
    orm[2::4] = metal[0::4]
    images["orm"] = bpy.data.images.new("wirbel_orm", TEX, TEX, alpha=False)
    images["orm"].colorspace_settings.name = "Non-Color"
    images["orm"].pixels = orm.tolist()
    return images


def final_material(images):
    mat = bpy.data.materials.new("wirbel")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    base = nt.nodes.new("ShaderNodeTexImage")
    base.image = images["base"]
    nt.links.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    orm = nt.nodes.new("ShaderNodeTexImage")
    orm.image = images["orm"]
    split = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm.outputs["Color"], split.inputs["Color"])
    nt.links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
    normal_img = nt.nodes.new("ShaderNodeTexImage")
    normal_img.image = images["normal"]
    normal_map = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(normal_img.outputs["Color"], normal_map.inputs["Color"])
    nt.links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# ------------------------------------------------------------------ review pictures
VIEWS = [
    # name, camera, target, lens (mm)
    ("links", (-1.75, 0.135, 0.09), (0.0, 0.135, 0.07), 70),
    ("rechts", (1.75, 0.135, 0.09), (0.0, 0.135, 0.07), 70),
    ("vorn_schraeg", (-0.75, 1.30, 0.42), (0.0, 0.16, 0.08), 55),
    ("hinten_schraeg", (-0.42, -0.85, 0.36), (0.0, 0.18, 0.11), 50),
    ("oben", (0.0, 0.135, 1.85), (0.0, 0.135, 0.07), 70),
    ("nah_magazin", (-0.30, -0.06, 0.29), (0.0, 0.150, 0.140), 60),
]


def look_from(cam, pos, target):
    pos, target = Vector(pos), Vector(target)
    fwd = (target - pos).normalized()
    up = Vector((0, 1, 0)) if abs(fwd.z) > 0.98 else Vector((0, 0, 1))
    right = fwd.cross(up).normalized()
    upv = right.cross(fwd).normalized()
    m = Matrix((right, upv, -fwd)).transposed().to_4x4()
    m.translation = pos
    cam.matrix_world = m


def light(name, kind, pos, target, energy, colour, size=0.5):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = colour
    if kind == "AREA":
        data.size = size
    obj = link(bpy.data.objects.new(name, data))
    look_from(obj, pos, target)
    return obj


def render_views(folder, prefix):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 800
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    scene.world = world
    background = world.node_tree.nodes["Background"]
    cam = link(bpy.data.objects.new("cam", bpy.data.cameras.new("cam")))
    scene.camera = cam
    cam.data.clip_start = 0.01
    centre = (0.0, 0.135, 0.07)
    # A floor far below that catches a soft shadow (studio) and nothing much at night.
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0, 0.135, -0.16))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor")
    floor_mat.use_nodes = True
    floor.data.materials.append(floor_mat)
    setups = {
        "studio": [("key", "AREA", (-1.2, -0.6, 1.4), centre, 45.0, (1.0, 0.97, 0.92), 1.2),
                   ("fill", "AREA", (1.3, 0.5, 0.6), centre, 15.0, (0.85, 0.9, 1.0), 1.5),
                   ("rim", "AREA", (0.2, 1.6, 0.9), centre, 35.0, (1.0, 1.0, 1.0), 0.8)],
        "nacht": [("lamp", "POINT", (-0.6, -0.3, 0.9), centre, 35.0, (1.0, 0.72, 0.45), 0.1),
                  ("cold", "AREA", (0.5, 1.4, 0.5), centre, 25.0, (0.45, 0.6, 1.0), 0.6)],
    }
    for setup, lights in setups.items():
        made = [light(*entry) for entry in lights]
        if setup == "studio":
            background.inputs["Color"].default_value = (0.42, 0.43, 0.45, 1.0)
            background.inputs["Strength"].default_value = 0.35
            floor_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.5, 0.5, 0.52, 1.0)
        else:
            background.inputs["Color"].default_value = (0.012, 0.014, 0.02, 1.0)
            background.inputs["Strength"].default_value = 1.0
            floor_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.03, 0.03, 1.0)
        for name, pos, target, lens in VIEWS:
            cam.data.lens = lens
            look_from(cam, pos, target)
            scene.render.filepath = os.path.join(folder, "%s_%s_%s.png" % (prefix, name, setup))
            bpy.ops.render.render(write_still=True)
        for obj in made:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(floor, do_unlink=True)
    print("RENDERED", folder, prefix)


def place_origin(obj, point):
    """Moves the object's origin to `point` without moving its mesh."""
    obj.data.transform(Matrix.Translation(-Vector(point)))
    obj.location = Vector(point)


def main():
    clear()
    m = make_materials()
    body_parts, drum_parts, bolt_parts, trigger_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(drum_parts, "Magazine")
    bolt = join(bolt_parts, "Bolt")
    trigger = join(trigger_parts, "Trigger")
    parts = (body, magazine, bolt, trigger)
    if SIGHTS:
        parts += (join(SIGHTS, "Sights"),)
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.004, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in parts:
        for slot in o.material_slots:
            if slot.material is None:
                slot.material = bpy.data.materials["steel"]
    images = bake(list(parts))
    final = final_material(images)
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(final)
    # The moving parts turn and run about their own places.
    place_origin(magazine, (0.0, (DRUM_Y[0] + DRUM_Y[1]) * 0.5, DRUM_Z))
    place_origin(bolt, BOLT_REST)
    place_origin(trigger, TRIGGER_PIVOT)
    root = link(bpy.data.objects.new("Wirbel", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body) + (triangles(parts[4]) if len(parts) > 4 else 0), "magazine", triangles(magazine), "bolt", triangles(bolt), "trigger", triangles(trigger),
          "all", sum(triangles(o) for o in parts), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % 0.0062)
    print("SPEC rail %.4f irons %.4f" % (RAIL_Z, RAIL_Z + 0.013))
    print("SPEC drum", godot((0.0, (DRUM_Y[0] + DRUM_Y[1]) * 0.5, DRUM_Z)), "bolt", godot(BOLT_REST), "trigger", godot(TRIGGER_PIVOT))
    print("SPEC support", godot((0, FOREGRIP_Y, BORE_Z - 0.06)), "eject", godot((RECV_W / 2.0, 0.057, BORE_Z + 0.003)))
    if BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts + (root,):
        o.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_image_quality=90)
    print("EXPORTED", OUT, os.path.getsize(OUT), "bytes")


main()
