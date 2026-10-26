# Builds the FALKE SK-17 for Nachtwache, from nothing: a battle rifle in the manner of the
# modern modular ones (a long anodised upper receiver with a rail from end to end, a polymer
# lower, a side-folding stock, a charging handle on the left that runs with the bolt, a
# straight 20-round box of 7.62), grey-blue instead of the usual tan. Its name and markings
# are its own. Every part is made here, bevelled, given its material, UV-unwrapped and
# baked into one texture set (base colour, roughness and metal, normal), then written as a
# GLB with the nodes
#   Falke > Body / Magazine (its origin at the middle of its top) / Bolt (the charging
#   handle, its origin where it rests) / Trigger (its origin at its pivot) / Sights (the
#   folding iron sights, laid down under a fitted optic).
#
#   blender --background --factory-startup --python tools/blender_make_falke.py -- [--round 5] [--tex 2048]
#           [--out assets/models/falke.glb] [--render <folder> --prefix runde1] [--gpu]
#
# --round: how far the detail goes (the review rounds; the game uses the last).
# --render: fixed views of the finished, baked model (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the top of the pistol grip. The glTF exporter turns this into Godot space (barrel along
# -Z, up +Y). The places the game needs (GUNS["falke"] in weapon_view.gd) are printed.
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
ROUND = int(arg("--round", "6"))
TEX = int(arg("--tex", "2048"))
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "falke.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "runde%d" % ROUND)
GPU = "--gpu" in ARGV


def use_gpu(scene):
    """Cycles on the graphics card, when there is one (much quicker for the bake and the
    review pictures); else it stays on the processor."""
    if not GPU:
        scene.cycles.device = "CPU"
        return
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            found = [d for d in prefs.devices if d.type == kind]
            if found:
                for d in prefs.devices:
                    d.use = d.type == kind
                scene.cycles.device = "GPU"
                return
        except Exception:
            pass
    scene.cycles.device = "CPU"
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
BORE_Z = 0.072                 # the bore axis above the top of the grip
UP_Y = (-0.100, 0.400)         # the upper receiver, one piece from its back to the end of the handguard
UP_Z = (0.040, 0.108)
RAIL_Z = 0.120                 # the top of the rail along all of it
LOW_Y = (-0.082 if ROUND < 3 else -0.100, 0.152)   # the polymer lower receiver (from round 3 up to the hinge)
LOW_Z = (-0.002, 0.044)
LOW_W = 0.046
GUARD_Y = (0.215, 0.396)       # the polymer piece under the front of the upper
STOCK_BACK = -0.372            # the face of the butt plate: 1.01 m over all
# (Round 3: the barrel 3.5 cm shorter - in the first rounds it stood out like a pipe.)
MUZZLE_Y = 0.640 if ROUND < 3 else 0.605   # the face of the flash hider
HIDER_Y = 0.578 if ROUND < 3 else 0.543
MAG_TOP = 0.034
MAG_FRONT = (0.137, 0.150)     # the front of the magazine at its top and at its foot (it leans forward)
MAG_BACK = (0.071, 0.082)
MAG_FOOT = -0.108
MAG_W = 0.027
GRIP_TILT = math.radians(-17.0)
GRIP_PIVOT = Vector((0.0, -0.014, LOW_Z[0] + 0.004))
TRIGGER_PIVOT = Vector((0.0, 0.024, LOW_Z[0] - 0.002))
BOLT_REST = Vector((-0.029, 0.208, 0.091))   # the charging handle on the left, forward
BOLT_TRAVEL = 0.100            # it runs back with the bolt, ten centimetres
SIGHT_Y = (-0.088, 0.382)      # the rear and the front sight on the rail
IRONS = RAIL_Z + 0.017         # the middle of the aperture, level with the tip of the post


def upper_profile():
    """The cross-section of the upper (x, z): narrow at the rail, wider over the middle,
    tucked in at the foot."""
    z0, z1 = UP_Z
    pts = [(0.022, z0), (0.0265, z0 + 0.010), (0.0275, 0.090), (0.0235, z1 - 0.003), (0.0185, z1)]
    if ROUND == 1:
        pts = [(0.025, z0), (0.026, z1 - 0.004), (0.02, z1)]
    left = [(-x, z) for x, z in reversed(pts)]
    return pts + left


def make_materials():
    wear = {1: 0.0, 2: 0.5, 3: 0.8, 4: 0.9}.get(ROUND, 1.0)
    if ROUND == 1:
        alu = material("alu", (0.11, 0.125, 0.145), 0.5, 0.6)
        polymer = material("polymer", (0.062, 0.068, 0.078), 0.72, 0.0)
        grip = polymer
        steel = material("steel", (0.045, 0.047, 0.05), 0.42, 0.85)
    else:
        # The anodised upper: grey with a blue cast, satin; its edges worn to bare aluminium.
        # (Round 3 read as plain grey: from round 4 bluer.)
        alu = material("alu", (0.098, 0.113, 0.132) if ROUND < 4 else (0.078, 0.1, 0.132), 0.46, 0.55, wear=wear, grime=0.6, bump=0.05 if ROUND >= 3 else 0.0, bump_scale=1600.0, worn=(0.46, 0.48, 0.5))
        # The polymer: a darker graphite of the same blue-grey, matt.
        polymer = material("polymer", (0.056, 0.062, 0.072) if ROUND < 4 else (0.05, 0.058, 0.072), 0.74, 0.0, wear=0.3 * wear, grime=0.8, worn=(0.15, 0.16, 0.18))
        grip = material("grip", (0.05, 0.055, 0.064), 0.82, 0.0, wear=0.25 * wear, grime=0.9, bump=0.0 if ROUND < 4 else 0.9, bump_scale=2400.0, stipple=True, worn=(0.14, 0.15, 0.17))
        steel = material("steel", (0.04, 0.042, 0.046), 0.4, 0.85, wear=0.7 * wear, grime=0.6, worn=(0.38, 0.38, 0.38))
    dark = material("dark", (0.008, 0.008, 0.009), 0.8, 0.2)
    rubber = material("rubber", (0.022, 0.022, 0.024), 0.9, 0.0, grime=0.4, bump=0.0 if ROUND < 4 else 0.5, bump_scale=900.0, stipple=True)
    brass = material("brass", (0.66, 0.49, 0.21), 0.36, 1.0, wear=0.3, grime=0.3, worn=(0.8, 0.65, 0.35))
    copper = material("copper", (0.55, 0.27, 0.14), 0.36, 1.0, grime=0.25)
    marking = material("marking", (0.42, 0.44, 0.47), 0.42, 0.7) if ROUND >= 3 else alu
    white = material("white", (0.6, 0.6, 0.58), 0.5, 0.0) if ROUND >= 3 else polymer
    # (From round 4) the magazine: dark, slightly glossy steel with a phosphate grey, its
    # edges rubbed bright by the pouch.
    magsteel = material("magsteel", (0.032, 0.035, 0.04), 0.5, 0.6, wear=0.8, grime=0.5, worn=(0.3, 0.31, 0.33)) if ROUND >= 4 else steel
    return {"magsteel": magsteel, "alu": alu, "polymer": polymer, "grip": grip, "steel": steel, "dark": dark, "rubber": rubber, "brass": brass, "copper": copper, "marking": marking, "white": white}


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



SIGHTS = []


def rail(name, y0, y1, z_top, width, mat, notches=True, pitch=0.010, side=None):
    """A Picatinny rail: a flat top with chamfered sides and cross slots every centimetre.
    side: None for a rail on top; -1/+1 for one on the left/right face (turned on its side)."""
    h = 0.012 if side is None else 0.008
    w = width / 2.0
    prof = [(-w, z_top - h), (w, z_top - h), (w, z_top - 0.004), (w - 0.003, z_top - 0.0012), (w - 0.0035, z_top), (-w + 0.0035, z_top), (-w + 0.003, z_top - 0.0012), (-w, z_top - 0.004)]
    r = prism(name, prof, y0, y1, mat)
    if notches and ROUND >= 2:
        n = int((y1 - y0 - 0.006) / pitch)
        start = y0 + (y1 - y0 - n * pitch) * 0.5 + pitch * 0.5
        for i in range(n):
            y = start + i * pitch - 0.0027
            cut(r, box("slot", (-0.03, y, z_top - 0.0032), (0.03, y + 0.0053, z_top + 0.01), mat), "EXACT")
    if ROUND >= 2:
        bevel_object(r, 0.0005, 1, 30.0)
    if side is not None:
        # Laid on its side: its top looks left (-1) or right (+1), about the bore.
        r.data.transform(Matrix.Rotation(side * math.pi / 2.0, 4, "Y"))
    smooth(r, 30)
    return r


def build(m):
    body, mag, bolt, trig = [], [], [], []
    z0, z1 = UP_Z
    # --- the upper receiver: one long piece from the hinge of the stock to the front of the
    # handguard, the rail on top of all of it.
    upper = prism("Upper", upper_profile(), UP_Y[0], UP_Y[1], m["alu"])
    if ROUND >= 2:
        # The ejection port on the right, the slot the charging handle runs in on the left,
        # the hollow under the front where the barrel lies free.
        cut(upper, box("port", (0.018, 0.030, BORE_Z - 0.010), (0.04, 0.094, BORE_Z + 0.014), m["alu"], bevel=0.002))
        cut(upper, box("slot", (-0.04, BOLT_REST.y - BOLT_TRAVEL - 0.010, BOLT_REST.z - 0.0045), (-0.020, BOLT_REST.y + 0.012, BOLT_REST.z + 0.0045), m["alu"], bevel=0.001))
        cut(upper, cylinder("free", (0, GUARD_Y[0], BORE_Z - 0.004), (0, UP_Y[1] + 0.01, BORE_Z - 0.004), 0.0175, m["alu"], 24))
        # Its front edge taken off all round.
        cut(upper, box("nose", (-0.05, UP_Y[1] - 0.004, z0 - 0.01), (0.05, UP_Y[1] + 0.02, z0 + 0.006), m["alu"]))
    if ROUND >= 5:
        # (Round 4's front was a flat, square face.) Its foot slopes back under the barrel,
        # and the corners beside the rail are cut at a slant.
        # (Its first try cut into the channel the barrel lies in: one saw through it. The
        # slope now ends below the channel.)
        wedge = box("wedge", (-0.05, UP_Y[1] - 0.030, z0 - 0.03), (0.05, UP_Y[1] + 0.03, z0 + 0.007), m["alu"])
        rotate(wedge, math.radians(-30.0), "X", Vector((0, UP_Y[1] - 0.030, z0 + 0.007)))
        cut(upper, wedge)
        for side in (-1.0, 1.0):
            corner = box("corner", (side * 0.03 - 0.012, UP_Y[1] - 0.020, 0.080), (side * 0.03 + 0.012, UP_Y[1] + 0.03, z1 + 0.01), m["alu"])
            rotate(corner, side * math.radians(35.0), "Z", Vector((side * 0.0235, UP_Y[1] - 0.020, 0.0)))
            cut(upper, corner)
    if ROUND >= 4:
        # A step down each side: the upper half stands out over a narrower foot, as on the
        # modern receivers (in round 3 the sides were one flat sheet).
        for side in (-1.0, 1.0):
            cut(upper, box("step", (side * 0.0275 - 0.0025, UP_Y[0] + 0.03, z0 - 0.01), (side * 0.0275 + 0.0025, UP_Y[1] + 0.01, z0 + 0.012), m["alu"], bevel=0.0012))
        # Two long, shallow flutes down each side of the front: the light runs along them.
        for side in (-1.0, 1.0):
            for zc in (0.085, 0.060):
                g = box("flute", (side * 0.0275 - 0.0018, 0.228, zc - 0.0035), (side * 0.0275 + 0.0018, 0.392, zc + 0.0035), m["alu"], bevel=0.0012)
                cut(upper, g)
    bevel_object(upper, 0.0013 if ROUND >= 2 else 0.002, 2, 30.0)
    smooth(upper, 35)
    body.append(upper)
    body.append(rail("TopRail", UP_Y[0] + 0.004, UP_Y[1] - 0.004, RAIL_Z, 0.0212, m["alu"]))
    if ROUND >= 2:
        # The channel under the front, where the barrel lies free: dark inside.
        body.append(cylinder("Channel", (0, GUARD_Y[0] + 0.004, BORE_Z - 0.004), (0, UP_Y[1] - 0.003, BORE_Z - 0.004), 0.0172, m["dark"], 24))
        # Behind the port: the dark of the action and the bolt carrier's flank.
        body.append(box("Action", (0.012, 0.026, BORE_Z - 0.012), (0.019, 0.098, BORE_Z + 0.016), m["dark"]))
        body.append(box("Carrier", (0.013, 0.036, BORE_Z - 0.006), (0.0195, 0.088, BORE_Z + 0.009), m["steel"], bevel=0.0012))
        body.append(box("Track", (-0.024, BOLT_REST.y - BOLT_TRAVEL - 0.012, BOLT_REST.z - 0.006), (-0.020, BOLT_REST.y + 0.014, BOLT_REST.z + 0.006), m["dark"]))
    # --- the lower receiver, the magazine well, the pistol grip and the trigger guard
    lw = LOW_W / 2.0
    lower = box("Lower", (-lw, LOW_Y[0], LOW_Z[0]), (lw, LOW_Y[1], LOW_Z[1]), m["polymer"], bevel=0.004 if ROUND >= 2 else 0.003, segments=3)
    if ROUND >= 2:
        # The well: open below, its mouth flared (where the magazine goes in).
        mouth = box("mouth", (-MAG_W / 2.0 - 0.0015, MAG_BACK[0] - 0.002, LOW_Z[0] - 0.01), (MAG_W / 2.0 + 0.0015, MAG_FRONT[0] + 0.002, MAG_TOP + 0.001), m["polymer"])
        cut(lower, mouth)
        flare = box("Flare", (-lw - 0.002, MAG_BACK[0] - 0.008, LOW_Z[0] - 0.012), (lw + 0.002, MAG_FRONT[0] + 0.006, LOW_Z[0] + 0.006), m["polymer"], bevel=0.003, segments=2)
        cut(flare, box("fm", (-MAG_W / 2.0 - 0.0015, MAG_BACK[0] - 0.002, LOW_Z[0] - 0.03), (MAG_W / 2.0 + 0.0015, MAG_FRONT[0] + 0.002, LOW_Z[0] + 0.02), m["polymer"]))
        smooth(flare, 35)
        body.append(flare)
        body.append(box("Well", (-MAG_W / 2.0 + 0.001, MAG_BACK[0] + 0.002, LOW_Z[0] + 0.004), (MAG_W / 2.0 - 0.001, MAG_FRONT[0] - 0.002, MAG_TOP + 0.006), m["dark"]))
    smooth(lower, 35)
    body.append(lower)
    section = []
    for i in range(28):
        a = math.tau * i / 28
        y = math.cos(a) * 0.0255 - 0.004
        x = math.sin(a) * (0.0158 if math.cos(a) < 0.0 else 0.0148)
        section.append((x, y))
    grip = upright("Grip", section, -0.088, GRIP_PIVOT.z + 0.006, m["grip"])
    bevel_object(grip, 0.004, 3, 40.0)
    if ROUND >= 2:
        # A finger bump at the front, a swell at the palm.
        for z in (-0.020, -0.048):
            cut(grip, cylinder("fg", (-0.03, 0.0255, z), (0.03, 0.0255, z), 0.0095, m["grip"], 20))
    if ROUND >= 3:
        body.append(box("GripCap", (-0.0145, -0.032, -0.093), (0.0145, 0.022, -0.085), m["polymer"], bevel=0.0035, segments=3))
        rotate(body[-1], GRIP_TILT, "X", GRIP_PIVOT)
    rotate(grip, GRIP_TILT, "X", GRIP_PIVOT)
    smooth(grip, 40)
    body.append(grip)
    gwd = 0.005 if ROUND < 4 else 0.0065
    guard = box("Guard", (-gwd, 0.000, LOW_Z[0] - 0.048), (gwd, 0.070, LOW_Z[0] + 0.002), m["polymer"], bevel=0.004, segments=3)
    cut(guard, box("open", (-0.02, 0.006, LOW_Z[0] - 0.042), (0.02, 0.064, LOW_Z[0] + 0.003), m["polymer"], bevel=0.003))
    smooth(guard, 40)
    body.append(guard)
    t = box("TriggerBlade", (-0.0032, TRIGGER_PIVOT.y - 0.004, LOW_Z[0] - 0.038), (0.0032, TRIGGER_PIVOT.y + 0.003, TRIGGER_PIVOT.z), m["steel"], bevel=0.0012)
    if ROUND >= 3:
        # Curved: a second, lower piece swept forward.
        tip = box("TriggerTip", (-0.0032, TRIGGER_PIVOT.y - 0.001, LOW_Z[0] - 0.040), (0.0032, TRIGGER_PIVOT.y + 0.006, LOW_Z[0] - 0.028), m["steel"], bevel=0.0012)
        trig.append(tip)
    rotate(t, math.radians(-10.0), "X", TRIGGER_PIVOT)
    trig.append(t)
    # --- the polymer under the front, with a short rail below
    gw = 0.024
    under = box("Underguard", (-gw, GUARD_Y[0], 0.026 if ROUND < 2 else 0.022), (gw, GUARD_Y[1], z0 + 0.004), m["polymer"], bevel=0.004 if ROUND >= 2 else 0.003, segments=3)
    smooth(under, 35)
    body.append(under)
    if ROUND >= 2:
        lowrail = rail("BottomRail", GUARD_Y[0] + 0.06, GUARD_Y[1] - 0.012, 0.026, 0.0212, m["alu"])
        # (Built as a top rail on z 0.026, then turned over about its middle: its slots below.)
        lowrail.data.transform(Matrix.Translation((0, 0, 0.020)) @ Matrix.Rotation(math.pi, 4, "Y") @ Matrix.Translation((0, 0, -0.020)))
        body.append(lowrail)
        # Short rails on both sides of the front (they take a light or a laser).
        for side in (-1.0, 1.0):
            sr = rail("SideRail", 0.262, 0.372, 0.0, 0.0175, m["alu"], side=side)
            sr.data.transform(Matrix.Translation((side * 0.035, 0, 0.073)))
            body.append(sr)
    # --- barrel, gas regulator, flash hider
    body.append(cylinder("Barrel", (0, 0.10, BORE_Z), (0, HIDER_Y + 0.004, BORE_Z), 0.011 if ROUND < 3 else 0.0124, m["steel"], 28))
    if ROUND >= 2:
        # The step of the barrel where it leaves the handguard, and the gas block with its
        # two-position regulator in front of the upper.
        body.append(cylinder("Shoulder", (0, UP_Y[1] - 0.006, BORE_Z), (0, UP_Y[1] + 0.012, BORE_Z), 0.0128, m["steel"], 28, bevel=0.0012))
        gas = box("GasBlock", (-0.013, UP_Y[1] + 0.002, BORE_Z - 0.013), (0.013, UP_Y[1] + 0.026, BORE_Z + 0.004), m["steel"], bevel=0.003, segments=2)
        smooth(gas, 35)
        body.append(gas)
        knob = cylinder("Regulator", (0, UP_Y[1] + 0.006, BORE_Z - 0.021), (0, UP_Y[1] + 0.030, BORE_Z - 0.021), 0.0085, m["steel"], 20, bevel=0.0015)
        if ROUND >= 3:
            for k in range(2):
                cut(knob, box("rg", (-0.02, UP_Y[1] + 0.024 + 0.0, BORE_Z - 0.0225 + k * 0.0), (0.02, UP_Y[1] + 0.032, BORE_Z - 0.0195), m["steel"]))
        smooth(knob, 35)
        body.append(knob)
    hider = cylinder("Hider", (0, HIDER_Y, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.0118, m["steel"], 28, bevel=0.0018)
    cut(hider, cylinder("bore", (0, HIDER_Y - 0.02, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0072, m["steel"], 20))
    if ROUND >= 3:
        # Three prongs: slots cut in from the front.
        for k in range(3):
            a = math.tau * k / 3.0 + math.pi / 2.0
            s = box("prong", (-0.0022, MUZZLE_Y - 0.032, 0.0), (0.0022, MUZZLE_Y + 0.01, 0.02), m["steel"])
            s.data.transform(Matrix.Translation((0, 0, BORE_Z)) @ Matrix.Rotation(a, 4, "Y"))
            cut(hider, s)
        # The wrench flats at its back.
        for side in (-1.0, 1.0):
            cut(hider, box("flat", (side * 0.0108 - 0.004 * (side < 0), HIDER_Y - 0.002, BORE_Z - 0.02), (side * 0.0108 + 0.004 * (side > 0), HIDER_Y + 0.012, BORE_Z + 0.02), m["steel"]))
    smooth(hider, 35)
    body.append(hider)
    body.append(cylinder("Bore", (0, MUZZLE_Y - 0.05, BORE_Z), (0, MUZZLE_Y - 0.004, BORE_Z), 0.0071, m["dark"], 16))
    # --- the stock: a hinge block at the back of the upper, a closed frame of polymer that
    # folds to the right, a cheek piece on top, a rubber butt pad.
    # (Round 6, after Henry: aimed over the sights, the hinge, the stock's comb and its cheek
    # piece stood up into the lower third of the picture. From round 6 all of it stays well
    # under the line of the rail: the comb drops away behind the receiver.)
    low_stock = 0.0 if ROUND < 6 else 0.03
    hinge = box("Hinge", (-0.021, UP_Y[0] - 0.020, z0 - 0.004), (0.021, UP_Y[0] + 0.002, z1 - 0.004 - low_stock), m["polymer"], bevel=0.004, segments=3)
    smooth(hinge, 35)
    body.append(hinge)
    sb = UP_Y[0] - 0.020
    outline = [(sb, z1 - 0.006 - low_stock), (-0.215, z1 + 0.002 - low_stock * 1.4), (STOCK_BACK + 0.026, z1 + 0.006 - low_stock), (STOCK_BACK + 0.008, z1 + 0.008 - low_stock),
               (STOCK_BACK + 0.004, -0.060), (STOCK_BACK + 0.040, -0.066), (-0.200, -0.006), (sb, z0 + 0.004)]
    stock = slab("Stock", outline, -0.0175, 0.0175, m["polymer"])
    if ROUND >= 2:
        hole = [(sb - 0.024, z1 - 0.022 - low_stock), (-0.212, z1 - 0.016 - low_stock * 1.4), (STOCK_BACK + 0.046, z1 - 0.012 - low_stock), (STOCK_BACK + 0.042, -0.036), (-0.205, 0.012), (sb - 0.026, z0 + 0.012)]
        cutter = slab("hole", hole, -0.03, 0.03, m["polymer"])
        bevel_object(cutter, 0.006, 3, 30.0)
        cut(stock, cutter)
    if ROUND >= 4:
        # Grooves along both faces of the stock's top bar, and the length buttons.
        for side in (-1.0, 1.0):
            for zc in (z1 - 0.010, z1 - 0.003):
                cut(stock, box("sg", (side * 0.0175 - 0.0012, -0.290, zc - 0.0012), (side * 0.0175 + 0.0012, -0.150, zc + 0.0012), m["polymer"], bevel=0.0006))
    bevel_object(stock, 0.0035, 3, 30.0)
    smooth(stock, 35)
    body.append(stock)
    if ROUND >= 4:
        for side in (-1.0, 1.0):
            body.append(cylinder("LengthButton", (side * 0.0172, -0.330, -0.020), (side * 0.0200, -0.330, -0.020), 0.0055, m["steel"], 18, bevel=0.0012))
    if ROUND >= 3:
        # The cheek piece, raised and rounded, and the knob that lets the stock out.
        if ROUND < 6:
            cheek = box("Cheek", (-0.0195, -0.300, z1 - 0.004), (0.0195, -0.150, z1 + 0.016), m["polymer"], bevel=0.007, segments=4)
        else:
            # A low, flat cheek pad far back, where the cheek lies - behind the eye.
            cheek = box("Cheek", (-0.0195, -0.320, z1 - 0.008 - low_stock * 1.4), (0.0195, -0.232, z1 + 0.002 - low_stock * 1.4), m["polymer"], bevel=0.0045, segments=3)
        smooth(cheek, 35)
        body.append(cheek)
        body.append(cylinder("Latch", (0.0175, -0.300 + 0.02, 0.020), (0.0215, -0.300 + 0.02, 0.020), 0.006, m["steel"], 18, bevel=0.0012))
    pad = box("Pad", (-0.022, STOCK_BACK - 0.014, -0.070), (0.022, STOCK_BACK + 0.004, z1 + 0.012 - low_stock), m["rubber"], bevel=0.007, segments=3)
    if ROUND >= 5:
        # Ribs across the rubber of the butt, so that it does not slip off the shoulder.
        for k in range(9):
            zc = -0.056 + k * 0.019
            cut(pad, box("pr", (-0.03, STOCK_BACK - 0.020, zc - 0.0022), (0.03, STOCK_BACK - 0.011, zc + 0.0022), m["rubber"], bevel=0.0012))
    smooth(pad, 35)
    body.append(pad)
    # --- the magazine: a straight box of twenty, leaning forward a little, ribbed on its sides
    mw = MAG_W / 2.0
    mag_outline = [(MAG_BACK[0], MAG_TOP), (MAG_FRONT[0], MAG_TOP), (MAG_FRONT[1], MAG_FOOT), (MAG_BACK[1], MAG_FOOT)]
    box_mag = slab("Mag", mag_outline, -mw, mw, m["magsteel"])
    if ROUND >= 2:
        # Ribs pressed into both sides; from round 4 a row of holes that show how full it is.
        for side in (-1.0, 1.0):
            for k in range(3):
                zc = MAG_TOP - 0.045 - k * 0.030
                rib = box("rib", (side * mw - 0.0012, MAG_BACK[0] + 0.012 + (zc - MAG_TOP) * -0.07, zc - 0.0028), (side * mw + 0.0012, MAG_FRONT[0] - 0.010 + (zc - MAG_TOP) * -0.07, zc + 0.0028), m["steel"], bevel=0.0012)
                cut(box_mag, rib)
            if ROUND >= 4:
                for k in range(4):
                    zc = MAG_TOP - 0.028 - k * 0.018
                    y = MAG_BACK[0] + 0.006 + (MAG_TOP - zc) * 0.12
                    cut(box_mag, cylinder("w", (side * mw - 0.004, y, zc), (side * mw + 0.004, y, zc), 0.0021, m["steel"], 12))
    bevel_object(box_mag, 0.0012, 2, 30.0)
    smooth(box_mag, 35)
    mag.append(box_mag)
    if ROUND >= 2:
        plate = box("BasePlate", (-mw - 0.002, MAG_BACK[1] - 0.004, MAG_FOOT - 0.010), (mw + 0.002, MAG_FRONT[1] + 0.004, MAG_FOOT + 0.002), m["polymer"], bevel=0.0028, segments=3)
        if ROUND >= 5:
            # A notch at the front of the base plate for the fingers that strip it.
            cut(plate, cylinder("pn", (-0.03, MAG_FRONT[1] + 0.006, MAG_FOOT - 0.012), (0.03, MAG_FRONT[1] + 0.006, MAG_FOOT - 0.012), 0.0065, m["polymer"], 20))
        smooth(plate, 35)
        mag.append(plate)
    if ROUND >= 3:
        # The top round in the feed lips.
        y0 = MAG_BACK[0] + 0.006
        zt = MAG_TOP - 0.002
        mag.append(cylinder("Case", (0, y0, zt), (0, y0 + 0.050, zt), 0.0058, m["brass"], 18))
        mag.append(cone("Shoulder", (0, y0 + 0.050, zt), (0, y0 + 0.054, zt), 0.0058, 0.0042, m["brass"], 18))
        mag.append(cone("Bullet", (0, y0 + 0.054, zt), (0, y0 + 0.068, zt), 0.0040, 0.0009, m["copper"], 18))
        for side in (-1.0, 1.0):
            mag.append(box("Lip", (side * (mw - 0.0012) - 0.0010, MAG_BACK[0] + 0.004, MAG_TOP - 0.004), (side * (mw - 0.0012) + 0.0010, MAG_BACK[0] + 0.040, MAG_TOP + 0.001), m["steel"]))
    # --- the charging handle on the left (it runs back with the bolt)
    stem = box("Stem", (BOLT_REST.x - 0.003, BOLT_REST.y - 0.006, BOLT_REST.z - 0.0035), (BOLT_REST.x + 0.010, BOLT_REST.y + 0.006, BOLT_REST.z + 0.0035), m["steel"], bevel=0.0012)
    knob = cylinder("Knob", (BOLT_REST.x - 0.001, BOLT_REST.y, BOLT_REST.z), (BOLT_REST.x - 0.024, BOLT_REST.y, BOLT_REST.z), 0.0062, m["polymer"], 18, bevel=0.002)
    bolt.extend([stem, knob])
    if ROUND >= 5:
        # Grip rings round the knob.
        for k in range(3):
            x = BOLT_REST.x - 0.006 - k * 0.0055
            cut(knob, cylinder("kr", (x - 0.0012, BOLT_REST.y, BOLT_REST.z), (x + 0.0012, BOLT_REST.y, BOLT_REST.z), 0.0075, m["polymer"], 18))
    if ROUND >= 3:
        bolt.append(cylinder("KnobEnd", (BOLT_REST.x - 0.022, BOLT_REST.y, BOLT_REST.z), (BOLT_REST.x - 0.027, BOLT_REST.y, BOLT_REST.z), 0.0075, m["polymer"], 20, bevel=0.0018))
    # --- the folding iron sights on the rail
    rear = box("RearBase", (-0.0105, SIGHT_Y[0] - 0.012, RAIL_Z - 0.002), (0.0105, SIGHT_Y[0] + 0.012, RAIL_Z + 0.006), m["alu"], bevel=0.0015)
    leaf = box("RearLeaf", (-0.0075, SIGHT_Y[0] - 0.003, RAIL_Z + 0.004), (0.0075, SIGHT_Y[0] + 0.002, IRONS + 0.010), m["alu"], bevel=0.0012)
    cut(leaf, cylinder("peep", (0, SIGHT_Y[0] - 0.02, IRONS), (0, SIGHT_Y[0] + 0.02, IRONS), 0.0058, m["alu"], 28))
    SIGHTS.extend([rear, leaf])
    if ROUND >= 2:
        # Wings that guard the aperture.
        for side in (-1.0, 1.0):
            SIGHTS.append(box("RearWing", (side * 0.0095 - 0.0018, SIGHT_Y[0] - 0.006, RAIL_Z + 0.004), (side * 0.0095 + 0.0018, SIGHT_Y[0] + 0.006, IRONS + 0.008), m["alu"], bevel=0.0008))
    front = box("FrontBase", (-0.0105, SIGHT_Y[1] - 0.012, RAIL_Z - 0.002), (0.0105, SIGHT_Y[1] + 0.012, RAIL_Z + 0.006), m["alu"], bevel=0.0015)
    post = box("FrontPost", (-0.0013, SIGHT_Y[1] - 0.0015, RAIL_Z + 0.004), (0.0013, SIGHT_Y[1] + 0.0015, IRONS), m["steel"], bevel=0.0005)
    SIGHTS.extend([front, post])
    for side in (-1.0, 1.0):
        SIGHTS.append(box("FrontWing", (side * 0.0085 - 0.0016, SIGHT_Y[1] - 0.006, RAIL_Z + 0.004), (side * 0.0085 + 0.0016, SIGHT_Y[1] + 0.006, IRONS + 0.003), m["alu"], bevel=0.0007))
    if ROUND >= 4:
        # A white dot under the aperture and on the post's base for dim light.
        SIGHTS.append(cylinder("Dot", (0, SIGHT_Y[1] - 0.0016, IRONS - 0.006), (0, SIGHT_Y[1] - 0.0012, IRONS - 0.006), 0.0011, m["white"], 10))
    # --- controls: the selector both sides, magazine release, bolt catch, pins
    for side in (-1.0, 1.0):
        body.append(cylinder("Selector", (side * lw - side * 0.001, -0.046, LOW_Z[0] + 0.026), (side * lw + side * 0.0025, -0.046, LOW_Z[0] + 0.026), 0.0058, m["steel"], 18))
        if ROUND >= 2:
            lever = box("Lever", (side * lw + (0.0 if side > 0 else -0.0038), -0.050, LOW_Z[0] + 0.023), (side * lw + (0.0038 if side > 0 else 0.0), -0.022, LOW_Z[0] + 0.029), m["steel"], bevel=0.0008)
            rotate(lever, math.radians(-25.0), "X", Vector((0, -0.046, LOW_Z[0] + 0.026)))
            body.append(lever)
    if ROUND >= 2:
        body.append(box("MagRelease", (lw - 0.0005, 0.050, LOW_Z[0] + 0.014), (lw + 0.0028, 0.064, LOW_Z[0] + 0.028), m["steel"], bevel=0.001))
        body.append(box("BoltCatch", (-lw - 0.0028, 0.040, LOW_Z[0] + 0.018), (-lw + 0.0005, 0.060, LOW_Z[0] + 0.032), m["steel"], bevel=0.001))
        for y, z in ((-0.062, LOW_Z[0] + 0.030), (0.140, LOW_Z[0] + 0.030), (0.010, LOW_Z[0] + 0.012)):
            body.append(cylinder("Pin", (-lw - 0.0007, y, z), (lw + 0.0007, y, z), 0.0024, m["steel"], 14))
    if ROUND >= 3:
        # Screws on the side rails and the hinge, sling cups, the markings.
        for side in (-1.0, 1.0):
            for y in (0.274, 0.360):
                s = cylinder("Screw", (side * 0.0352, y, 0.073), (side * 0.0372, y, 0.073), 0.0026, m["steel"], 16)
                cut(s, box("sl", (side * 0.0375 - 0.0008, y - 0.0026, 0.0725), (side * 0.0375 + 0.0008, y + 0.0026, 0.0735), m["steel"]), "EXACT")
                body.append(s)
        body.append(cylinder("HingePin", (0.0, UP_Y[0] - 0.012, z0 - 0.006), (0.0, UP_Y[0] - 0.012, z1 - 0.002 - (0.0 if ROUND < 6 else 0.034)), 0.004, m["steel"], 16))
        body[-1].data.transform(Matrix.Translation((0.0215, 0, 0)))
        for at in ((STOCK_BACK + 0.030, 0.050, 0.0172), (0.300, 0.034, 0.0235)):
            cup = cylinder("QD", (at[2], at[0], at[1]), (at[2] + 0.0043, at[0], at[1]), 0.0068, m["steel"], 20, bevel=0.001)
            cut(cup, cylinder("qd", (at[2] + 0.002, at[0], at[1]), (at[2] + 0.02, at[0], at[1]), 0.0042, m["steel"], 16))
            body.append(cup)
        body.append(engrave_left("FALKE  SK-17", Vector((-lw - 0.00012, 0.136, LOW_Z[0] + 0.024)), 0.0080, m["marking"]))
        body.append(engrave_left("7,62x51   NR 0417", Vector((-lw - 0.00012, 0.136, LOW_Z[0] + 0.013)), 0.0045, m["marking"]))
        body.append(engrave_left("S       F", Vector((-lw - 0.00012, -0.030, LOW_Z[0] + 0.036)), 0.0042, m["white"]))
    if ROUND >= 4:
        # The rail's numbers: a small mark every fifth slot along the top's left edge.
        for k in range(0, 48, 5):
            y = UP_Y[0] + 0.009 + k * 0.010
            body.append(box("Tick", (-0.0108, y - 0.0006, RAIL_Z - 0.0055), (-0.0104, y + 0.0006, RAIL_Z - 0.0035), m["marking"]))
        # A hex screw at each side of the barrel nut under the front of the upper.
        for side in (-1.0, 1.0):
            body.append(cylinder("Nut", (side * 0.0262, 0.232, 0.050), (side * 0.0282, 0.232, 0.050), 0.0032, m["steel"], 6))
    if ROUND >= 5:
        # The bolt's face and extractor seen through the port; a shell deflector behind it.
        body.append(box("Deflector", (0.0205, -0.004, BORE_Z - 0.006), (0.0275, 0.030, BORE_Z + 0.014), m["alu"], bevel=0.002))
        body.append(box("Extractor", (0.0128, 0.088, BORE_Z + 0.003), (0.0188, 0.094, BORE_Z + 0.008), m["steel"]))
    return body, mag, bolt, trig


def engrave_left(text, at, size, material):
    """Flat lettering on the left face, reading from the muzzle backwards as one sees it
    from the left; 'at' is where its first letter begins."""
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
def bake(objs, prefix="falke"):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    use_gpu(scene)
    scene.cycles.samples = 12
    scene.render.bake.margin = 6
    images = {}
    for key, colour_space in (("base", "sRGB"), ("rough", "Non-Color"), ("metal", "Non-Color"), ("normal", "Non-Color")):
        img = bpy.data.images.new(prefix + "_" + key, TEX, TEX, alpha=False, float_buffer=False)
        img.colorspace_settings.name = colour_space
        images[key] = img
    mats = set()
    for o in objs:
        for slot in o.material_slots:
            mats.add(slot.material)
    targets = {}
    for mat in mats:
        node = mat.node_tree.nodes.get("BAKE")
        if node is None:
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
    # The surfaces back on their shaders, for a second set baked from the same materials.
    for mat in mats:
        nt = mat.node_tree
        nt.links.new(nt.nodes["Principled BSDF"].outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    import numpy
    rough = numpy.array(images["rough"].pixels[:], dtype=numpy.float32)
    metal = numpy.array(images["metal"].pixels[:], dtype=numpy.float32)
    orm = numpy.ones_like(rough)
    orm[1::4] = rough[0::4]
    orm[2::4] = metal[0::4]
    images["orm"] = bpy.data.images.new(prefix + "_orm", TEX, TEX, alpha=False)
    images["orm"].colorspace_settings.name = "Non-Color"
    images["orm"].pixels = orm.tolist()
    return images


def final_material(images, name="falke"):
    mat = bpy.data.materials.new(name)
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
    ("links", (-2.25, 0.135, 0.09), (0.0, 0.135, 0.06), 70),
    ("rechts", (2.25, 0.135, 0.09), (0.0, 0.135, 0.06), 70),
    ("vorn_schraeg", (-0.75, 1.30, 0.42), (0.0, 0.16, 0.08), 55),
    ("hinten_schraeg", (-0.42, -0.85, 0.36), (0.0, 0.18, 0.11), 50),
    ("oben", (0.0, 0.135, 1.85), (0.0, 0.135, 0.07), 70),
    ("nah_verschluss", (-0.34, -0.02, 0.24), (0.0, 0.120, 0.070), 55),
    ("nah_muendung", (0.30, 0.82, 0.16), (0.0, 0.560, 0.072), 55),
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
    use_gpu(scene)
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
    body_parts, mag_parts, bolt_parts, trigger_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(mag_parts, "Magazine")
    bolt = join(bolt_parts, "Bolt")
    trigger = join(trigger_parts, "Trigger")
    sights = join(SIGHTS, "Sights")
    parts = (body, magazine, bolt, trigger, sights)
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
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.003, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in parts:
        for slot in o.material_slots:
            if slot.material is None:
                slot.material = bpy.data.materials["alu"]
    images = bake(list(parts), "falke")
    final = final_material(images, "falke")
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(final)
    # The moving parts move about their own places.
    place_origin(magazine, (0.0, (MAG_BACK[0] + MAG_FRONT[0]) * 0.5, MAG_TOP))
    place_origin(bolt, BOLT_REST)
    place_origin(trigger, TRIGGER_PIVOT)
    root = link(bpy.data.objects.new("Falke", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "magazine", triangles(magazine), "bolt", triangles(bolt), "trigger", triangles(trigger), "sights", triangles(sights),
          "all", sum(triangles(o) for o in parts), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % 0.0072)
    print("SPEC rail %.4f irons %.4f" % (RAIL_Z, IRONS))
    print("SPEC handle", godot(BOLT_REST), "trigger", godot(TRIGGER_PIVOT), "magazine", godot((0.0, (MAG_BACK[0] + MAG_FRONT[0]) * 0.5, MAG_TOP)))
    print("SPEC support", godot((0, 0.330, 0.018)), "eject", godot((0.020, 0.062, BORE_Z + 0.002)), "magazine_foot", godot((0.0, MAG_BACK[1], MAG_FOOT - 0.010)))
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
