# Builds the P90 for Nachtwache, from nothing (it replaces the supplied mesh p90.glb, which
# stays in the folder unused): the Belgian bullpup personal defence weapon in its classic
# black. A polymer body with two holes below - the thumbhole the firing hand closes round
# and the big trigger loop whose front bar the other hand holds -, the translucent 50-round
# magazine lying on top with its cartridges crosswise in two rows, the ring sight in its
# housing at the front of the top, charging handles on both sides under it, the cases
# dropping out of a chute under the butt, the fire selector a disc under the trigger.
# Every part is made here, bevelled, given its material, UV-unwrapped and baked into one
# texture set (base colour, roughness and metal, normal); the magazine's shell keeps a
# material of its own that lets the light through. Written as a GLB with the nodes
#   P90 > Body / Magazine (origin: the middle of its rear end, at its foot; the translucent
#   "Shell" under it) / Trigger (its origin at its pivot)
#
#   blender --background --factory-startup --python tools/blender_make_p90.py -- [--round 4] [--tex 2048]
#           [--out assets/models/p90_built.glb] [--render <folder> --prefix p90_r1] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3, 5 the slimmer ring sight after Henry:
#          aimed through it, its housing covered too much of the picture; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
# --render: fixed views (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the top of the grip bar (between the two holes). The glTF exporter turns this into Godot
# space (barrel along -Z, up +Y). The places the game needs (GUNS["p90"] in weapon_view.gd)
# are printed.
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
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "p90_built.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "p90_r%d" % ROUND)
GPU = "--gpu" in ARGV
NOBAKE = "--nobake" in ARGV


def use_gpu(scene):
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


def box(name, low, high, material, bevel=0.0, segments=2):
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
    start, end = Vector(start), Vector(end)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r0, radius2=r1, depth=(end - start).length)
    rot = Vector((0, 0, 1)).rotation_difference((end - start).normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((start + end) * 0.5) @ rot, verts=bm.verts)
    return mesh_object(name, bm, material)


def prism(name, profile, y0, y1, material):
    """A body of the cross-section `profile` ((x, z) points) from y0 to y1."""
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


def upright(name, section, z0, z1, material):
    """A body of the cross-section `section` ((x, y) points) from z0 up to z1."""
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


def fillet(points, n=6):
    """The polygon (y, z, r) with each corner rounded to its radius r (0: sharp)."""
    out = []
    count = len(points)
    for i in range(count):
        p = Vector(points[i][:2])
        r = points[i][2]
        if r <= 0.0:
            out.append((p.x, p.y))
            continue
        a = Vector(points[i - 1][:2])
        b = Vector(points[(i + 1) % count][:2])
        d1 = a - p
        d2 = b - p
        l1, l2 = d1.length, d2.length
        d1.normalize()
        d2.normalize()
        ang = math.acos(max(-0.999, min(0.999, d1.dot(d2))))
        t = min(r / math.tan(ang / 2.0), 0.45 * l1, 0.45 * l2)
        rr = t * math.tan(ang / 2.0)
        s = p + d1 * t
        e = p + d2 * t
        c = p + (d1 + d2).normalized() * (rr / math.sin(ang / 2.0))
        a0 = math.atan2(s.y - c.y, s.x - c.x)
        a1 = math.atan2(e.y - c.y, e.x - c.x)
        da = a1 - a0
        while da > math.pi:
            da -= math.tau
        while da < -math.pi:
            da += math.tau
        for k in range(n + 1):
            ak = a0 + da * k / n
            out.append((c.x + math.cos(ak) * rr, c.y + math.sin(ak) * rr))
    return out


def rounded_rect(x0, x1, z0, z1, r_top, r_bottom, n=6):
    return fillet([(x1, z0, r_bottom), (x1, z1, r_top), (x0, z1, r_top), (x0, z0, r_bottom)], n)


def bevel_object(obj, width, segments=2, angle=35.0):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = False
    mod.use_clamp_overlap = True
    apply(obj, mod)


def apply(obj, mod):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def cut(obj, cutter, solver="EXACT"):
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
    obj.data.set_sharp_from_angle(angle=math.radians(angle))


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
def material(name, base, rough, metal, wear=0.0, grime=0.0, bump=0.0, bump_scale=900.0, stipple=False, worn=(0.3, 0.3, 0.3)):
    """`base` colour with a little noise in it, edges rubbed to `worn` (wear 0..1), grime in
    the hollows, an optional fine bump (stipple, or a brushed grain)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 160.0 if ROUND == 1 else 480.0
    noise.inputs["Detail"].default_value = 6.0
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    colour = nodes.new("ShaderNodeMix")
    colour.data_type = "RGBA"
    spread = 0.14 if ROUND == 1 else 0.1
    colour.inputs[6].default_value = (*[c * (1.0 - spread) for c in base], 1.0)
    colour.inputs[7].default_value = (*[min(1.0, c * (1.0 + spread)) for c in base], 1.0)
    links.new(noise.outputs["Fac"], colour.inputs[0])
    out_colour = colour.outputs[2]
    rough_node = nodes.new("ShaderNodeMath")
    rough_node.operation = "MULTIPLY_ADD"
    rough_node.inputs[1].default_value = 0.16
    rough_node.inputs[2].default_value = rough - 0.08
    links.new(noise.outputs["Fac"], rough_node.inputs[0])
    out_rough = rough_node.outputs[0]
    metal_node = nodes.new("ShaderNodeValue")
    metal_node.outputs[0].default_value = metal
    out_metal = metal_node.outputs[0]
    if wear > 0.0 or grime > 0.0:
        geo = nodes.new("ShaderNodeNewGeometry")
        wear_noise = nodes.new("ShaderNodeTexNoise")
        wear_noise.inputs["Scale"].default_value = 60.0
        wear_noise.inputs["Detail"].default_value = 8.0
        links.new(coords.outputs["Object"], wear_noise.inputs["Vector"])
        if wear > 0.0:
            edge = nodes.new("ShaderNodeMapRange")
            bev = nodes.new("ShaderNodeBevel")
            bev.inputs["Radius"].default_value = 0.0011
            bev.samples = 8
            dot = nodes.new("ShaderNodeVectorMath")
            dot.operation = "DOT_PRODUCT"
            links.new(bev.outputs["Normal"], dot.inputs[0])
            links.new(geo.outputs["Normal"], dot.inputs[1])
            edge.inputs[1].default_value = 0.995
            edge.inputs[2].default_value = 0.93
            links.new(dot.outputs["Value"], edge.inputs[0])
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
            rmix.inputs[3].default_value = 0.35
            out_rough = rmix.outputs[0]
            if metal > 0.5:
                mmix = nodes.new("ShaderNodeMix")
                links.new(breakup.outputs[0], mmix.inputs[0])
                links.new(out_metal, mmix.inputs[2])
                mmix.inputs[3].default_value = 1.0
                out_metal = mmix.outputs[0]
        if grime > 0.0:
            hollow = nodes.new("ShaderNodeMapRange")
            occ = nodes.new("ShaderNodeAmbientOcclusion")
            occ.inputs["Distance"].default_value = 0.005
            occ.samples = 16
            hollow.inputs[1].default_value = 0.9
            hollow.inputs[2].default_value = 0.45
            links.new(occ.outputs["AO"], hollow.inputs[0])
            amount = nodes.new("ShaderNodeMath")
            amount.operation = "MULTIPLY"
            amount.inputs[1].default_value = grime
            links.new(hollow.outputs[0], amount.inputs[0])
            gmix = nodes.new("ShaderNodeMix")
            gmix.data_type = "RGBA"
            links.new(amount.outputs[0], gmix.inputs[0])
            links.new(out_colour, gmix.inputs[6])
            gmix.inputs[7].default_value = (0.012, 0.011, 0.01, 1.0)
            out_colour = gmix.outputs[2]
            grough = nodes.new("ShaderNodeMix")
            links.new(amount.outputs[0], grough.inputs[0])
            links.new(out_rough, grough.inputs[2])
            grough.inputs[3].default_value = 0.88
            out_rough = grough.outputs[0]
    links.new(out_colour, bsdf.inputs["Base Color"])
    links.new(out_rough, bsdf.inputs["Roughness"])
    links.new(out_metal, bsdf.inputs["Metallic"])
    mat["metal_socket"] = out_metal.node.name + ":" + str(list(out_metal.node.outputs).index(out_metal))
    mat["colour_socket"] = out_colour.node.name + ":" + str(list(out_colour.node.outputs).index(out_colour))
    if bump > 0.0:
        bump_node = nodes.new("ShaderNodeBump")
        bump_node.inputs["Strength"].default_value = bump
        bump_node.inputs["Distance"].default_value = 0.0008
        if stipple:
            cells = nodes.new("ShaderNodeTexVoronoi")
            cells.inputs["Scale"].default_value = bump_scale
            cells.feature = "DISTANCE_TO_EDGE"
            links.new(coords.outputs["Object"], cells.inputs["Vector"])
            links.new(cells.outputs["Distance"], bump_node.inputs["Height"])
        else:
            mapping = nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (1.0, 0.03, 1.0)
            links.new(coords.outputs["Object"], mapping.inputs["Vector"])
            lines = nodes.new("ShaderNodeTexNoise")
            lines.inputs["Scale"].default_value = bump_scale
            links.new(mapping.outputs["Vector"], lines.inputs["Vector"])
            links.new(lines.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def shell_material():
    """The magazine's shell: smoky, translucent polymer, a little glossy. Not baked: it
    keeps this plain material (alpha blended in the game)."""
    mat = bpy.data.materials.new("p90_magazine_shell")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tint = (0.16, 0.15, 0.13) if ROUND < 4 else (0.13, 0.125, 0.11)
    bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.22
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Alpha"].default_value = 0.42 if ROUND < 4 else 0.5
    try:
        mat.surface_render_method = "BLENDED"
    except Exception:
        mat.blend_method = "BLEND"
    mat.use_backface_culling = False
    mat.diffuse_color = (*tint, bsdf.inputs["Alpha"].default_value)
    return mat


def make_materials():
    wear = {1: 0.0, 2: 0.4, 3: 0.8}.get(ROUND, 0.9)
    polymer = material("polymer", (0.030, 0.032, 0.035), 0.66, 0.0, wear=0.35 * wear, grime=0.7 if ROUND >= 2 else 0.0, bump=0.08 if ROUND >= 3 else 0.0, bump_scale=2600.0, stipple=True, worn=(0.11, 0.115, 0.12))
    grip = material("grip", (0.034, 0.036, 0.039), 0.84, 0.0, wear=0.25 * wear, grime=0.8 if ROUND >= 2 else 0.0, bump=0.0 if ROUND < 3 else 0.85, bump_scale=2200.0, stipple=True, worn=(0.10, 0.105, 0.11)) if ROUND >= 3 else polymer
    steel = material("steel", (0.032, 0.033, 0.036), 0.42, 0.85, wear=0.7 * wear, grime=0.5 if ROUND >= 2 else 0.0, worn=(0.36, 0.36, 0.37))
    dark = material("dark", (0.006, 0.006, 0.007), 0.85, 0.0)
    rubber = material("rubber", (0.02, 0.02, 0.022), 0.9, 0.0, grime=0.4 if ROUND >= 2 else 0.0, bump=0.0 if ROUND < 3 else 0.5, bump_scale=900.0, stipple=True)
    brass = material("brass", (0.66, 0.50, 0.22), 0.34, 1.0, grime=0.2)
    copper = material("copper", (0.50, 0.30, 0.17), 0.34, 1.0, grime=0.2)
    tipcol = material("tip", (0.02, 0.02, 0.022), 0.5, 0.2) if ROUND >= 3 else copper
    marking = material("marking", (0.30, 0.31, 0.32), 0.6, 0.0) if ROUND >= 3 else polymer
    white = material("white", (0.62, 0.62, 0.6), 0.55, 0.0) if ROUND >= 3 else polymer
    red = material("red", (0.5, 0.05, 0.03), 0.5, 0.0) if ROUND >= 3 else polymer
    glass = material("glass", (0.02, 0.03, 0.035), 0.08, 0.0)
    # The black of the magazine's rear end and its follower: a shade apart from the body.
    magblack = material("magblack", (0.022, 0.023, 0.025), 0.55, 0.0, wear=0.3 * wear, grime=0.6 if ROUND >= 2 else 0.0, worn=(0.09, 0.09, 0.095))
    return {"polymer": polymer, "grip": grip, "steel": steel, "dark": dark, "rubber": rubber, "brass": brass, "copper": copper, "tip": tipcol,
            "marking": marking, "white": white, "red": red, "glass": glass, "magblack": magblack, "shell": shell_material()}


# ------------------------------------------------------------------ the measures
BODY_W = 0.027                  # half the width of the body
FRAME_W = 0.0175 if ROUND < 2 else 0.0215                # half the width of the frame round the two holes
TOP_Z = 0.050                   # the top of the body, where the magazine lies
BORE_Z = 0.026                  # the bore axis
BACK_Y = -0.300                 # the butt
FRONT_Y = 0.160                 # the front face of the body
MUZZLE_Y = 0.205                # the face of the flash hider: 50.5 cm over all
HIDER_Y = 0.176
BORE_R = 0.0036
LOW_Z = -0.092                  # the foot of the loop
MAG_Y = (-0.262, 0.020)         # the magazine, from its rear end to its nose
MAG_Z = (0.050, 0.080)
MAG_W = 0.0245
ROUNDS = 50
SIGHT_Y = (0.024, 0.136)        # the ring sight's housing
SIGHT_Z = 0.101                 # its axis: the middle of the ring
SIGHT_R = 0.0125 if ROUND < 5 else 0.0152     # the tunnel the eye looks through
SIGHT_TOP = 0.124 if ROUND < 5 else 0.1215
# Half the housing's width at its foot and at its top. From round 5 its walls round the
# wider tunnel are 3-5 mm instead of 7-10 mm: aimed, the eye sees much less of them.
HOUSING_W = (0.0215, 0.0175) if ROUND < 5 else (0.0205, 0.017)
# How far the knob, the switch and the screws move in with the slimmer walls.
SIDE_IN = 0.0 if ROUND < 5 else -0.0012
# The tunnel's radius at its front: from round 5 it widens forwards, so that from the eye
# its inner wall hides behind the rear rim instead of showing as a broad dark ring.
SIGHT_FAR = SIGHT_R if ROUND < 5 else 0.0172


def sight_r(y):
    """The radius of the sight's tunnel at y."""
    return SIGHT_R + (SIGHT_FAR - SIGHT_R) * (y - SIGHT_Y[0]) / (SIGHT_Y[1] - SIGHT_Y[0])
TRIGGER_PIVOT = Vector((0.0, 0.026, -0.006))
HANDLE = Vector((-BODY_W - 0.004, 0.118, 0.034))   # the left charging handle's knob
SELECTOR = Vector((0.0, 0.034, -0.0725))           # the fire selector disc under the trigger
CHUTE_Y = (-0.222, -0.176)      # the ejection chute under the butt
SUPPORT = Vector((0.0, 0.119, -0.008))             # the top of the front bar, where the left hand holds


def outline():
    """The side outline of the body (y, z, fillet radius), round from the top front."""
    pts = [
        (FRONT_Y, TOP_Z, 0.003),
        (MAG_Y[0] - 0.020, TOP_Z, 0.006),
        (BACK_Y + 0.006, TOP_Z - 0.004, 0.012),
        (BACK_Y - 0.002, 0.004, 0.03),
        (BACK_Y + 0.004, -0.058, 0.02),
        (BACK_Y + 0.020, -0.074, 0.02),
        (-0.190, -0.081, 0.04),
        (-0.060, -0.089, 0.05),
        (0.060, LOW_Z, 0.04),
        (0.100, LOW_Z + 0.003, 0.02),
        (0.122, -0.076, 0.02),
        (0.134, -0.030, 0.02),
        (0.141, -0.004, 0.006),
        (FRONT_Y - 0.002, 0.002, 0.006),
    ]
    return fillet(pts, 8 if ROUND >= 2 else 5)


def rear_hole():
    """The thumbhole: the palm lies in it, the grip bar before it."""
    return fillet([(-0.016, -0.006, 0.010), (-0.124, -0.006, 0.022), (-0.132, -0.046, 0.022), (-0.112, -0.068, 0.016), (-0.040, -0.071, 0.012)], 8)


def front_hole():
    """The trigger loop: the fingers of the firing hand in its back, the trigger at its top,
    the selector disc on its floor; its front bar is the front grip."""
    return fillet([(0.017, -0.006, 0.006), (0.104, -0.006, 0.012), (0.100, -0.040, 0.02), (0.088, -0.073, 0.016), (-0.006, -0.074, 0.016)], 8)


def build(m):
    body, mag, trig, shell = [], [], [], []
    # --- the body. Round 1: one slab of polymer, the two holes through it, the frame round
    # them cut narrower. From round 2: two pieces - the body proper (the butt full height,
    # above the holes the receiver) and the narrower loops round the holes, much rounder.
    frame = slab("Frame", outline(), -BODY_W, BODY_W, m["polymer"])
    for name, hole in (("rh", rear_hole()), ("fh", front_hole())):
        cut(frame, slab(name, hole, -0.05, 0.05, m["polymer"]))
    loops = None
    if ROUND < 2:
        for side in (-1.0, 1.0):
            x0, x1 = (FRAME_W, 0.05) if side > 0 else (-0.05, -FRAME_W)
            cut(frame, box("narrow", (x0, -0.142, -0.12), (x1, 0.175, -0.006), m["polymer"]))
    else:
        loops = slab("Loops", outline(), -FRAME_W, FRAME_W, m["polymer"])
        for name, hole in (("rh", rear_hole()), ("fh", front_hole())):
            cut(loops, slab(name, hole, -0.05, 0.05, m["polymer"]))
        cut(loops, box("top", (-0.05, -0.4, 0.004), (0.05, 0.3, 0.2), m["polymer"]))
        cut(loops, box("back", (-0.05, -0.4, -0.2), (0.05, -0.150, 0.2), m["polymer"]))
        # The body loses everything below the receiver ahead of the butt; the butt's front
        # face slopes back as it goes down.
        under = box("under", (-0.05, -0.150, -0.2), (0.05, 0.3, -0.006), m["polymer"])
        rotate(under, math.radians(-6.0), "X", Vector((0.0, -0.150, -0.006)))
        cut(frame, under)
        cut(frame, box("under2", (-0.05, -0.100, -0.2), (0.05, 0.3, -0.006), m["polymer"]))
        # The front corners of the receiver taken off at a slant (seen from above it narrows).
        for side in (-1.0, 1.0):
            corner = box("corner", (side * BODY_W - 0.012, FRONT_Y - 0.022, -0.05), (side * BODY_W + 0.012, FRONT_Y + 0.03, 0.1), m["polymer"])
            rotate(corner, side * math.radians(28.0), "Z", Vector((side * BODY_W, FRONT_Y - 0.022, 0.0)))
            cut(frame, corner)
    if ROUND >= 2:
        # The ejection chute under the butt: an opening, dark inside.
        cut(frame, box("chute", (-0.0085, CHUTE_Y[0], -0.10), (0.0085, CHUTE_Y[1], -0.066), m["polymer"], bevel=0.003))
        # Seams: the butt plate's joint round the back, the line where the barrel module sits
        # in the frame on both sides.
        for side in (-1.0, 1.0):
            cut(frame, box("seam", (side * BODY_W - 0.0008, -0.150, 0.0405), (side * BODY_W + 0.0008, FRONT_Y + 0.01, 0.0415), m["polymer"]))
            cut(frame, box("seam2", (side * BODY_W - 0.0008, 0.020, -0.01), (side * BODY_W + 0.0008, 0.021, 0.041), m["polymer"]))
        butt_seam = slab("bs", fillet([(BACK_Y + 0.016, 0.06, 0.0), (BACK_Y + 0.0172, 0.06, 0.0), (BACK_Y + 0.0172, -0.1, 0.0), (BACK_Y + 0.016, -0.1, 0.0)], 1), -0.05, 0.05, m["polymer"])
        cut(frame, butt_seam)
        # The charging handles run in a slot on each side, under the sight.
        for side in (-1.0, 1.0):
            cut(frame, box("slot", (side * BODY_W - 0.003, 0.050, HANDLE.z - 0.003), (side * BODY_W + 0.003, HANDLE.y + 0.006, HANDLE.z + 0.003), m["polymer"], bevel=0.001))
    if False:
        # (Tried in round 3: shallow scallops on the butt; they only drew lines across it.)
        # Shallow scallops on the sides of the butt where the cheek and the palm lie.
        for side in (-1.0, 1.0):
            sc = cylinder("sc", (side * (BODY_W + 0.052), -0.235, -0.02), (side * (BODY_W + 0.052), -0.165, -0.02), 0.0545, m["polymer"], 48)
            cut(frame, sc)
    bevel_object(frame, 0.0055 if ROUND >= 2 else 0.006, 3, 32.0)
    smooth(frame, 38)
    body.append(frame)
    if loops is not None:
        bevel_object(loops, 0.0092, 4, 32.0)
        smooth(loops, 40)
        if ROUND >= 3:
            # The stippled grip: the faces round the holes and on the bars.
            for poly in loops.data.polygons:
                c = poly.center
                if c.z < -0.004 and c.y > -0.140:
                    poly.material_index = 1
            loops.data.materials.append(m["grip"])
        body.append(loops)
    if ROUND >= 2:
        # Dark inside the chute, and the slots.
        body.append(box("ChuteInside", (-0.0075, CHUTE_Y[0] + 0.001, -0.075), (0.0075, CHUTE_Y[1] - 0.001, -0.066), m["dark"]))
        for side in (-1.0, 1.0):
            body.append(box("SlotInside", (side * (BODY_W - 0.0018) - 0.0006, 0.051, HANDLE.z - 0.0026), (side * (BODY_W - 0.0018) + 0.0006, HANDLE.y + 0.005, HANDLE.z + 0.0026), m["dark"]))
    if ROUND >= 2:
        # Low walls along both sides of the magazine: it lies a little sunk in the body.
        for side in (-1.0, 1.0):
            lip = box("MagLip", (side * (MAG_W + 0.0006) - (0.0 if side > 0 else BODY_W - MAG_W - 0.0006), MAG_Y[0] - 0.006, TOP_Z - 0.004), (side * (MAG_W + 0.0006) + (BODY_W - MAG_W - 0.0006 if side > 0 else 0.0), MAG_Y[1] + 0.002, TOP_Z + 0.007), m["polymer"], bevel=0.0012)
            smooth(lip, 35)
            body.append(lip)
    # --- the butt pad
    if ROUND >= 2:
        pad_outline = fillet([(BACK_Y + 0.006, TOP_Z - 0.006, 0.01), (BACK_Y - 0.004, 0.004, 0.03), (BACK_Y + 0.002, -0.058, 0.02), (BACK_Y + 0.018, -0.072, 0.012), (BACK_Y + 0.012, -0.040, 0.0), (BACK_Y + 0.010, 0.030, 0.0)], 8)
        pad = slab("ButtPad", pad_outline, -BODY_W + 0.0012, BODY_W - 0.0012, m["rubber"])
        if ROUND >= 3:
            for k in range(8):
                zc = -0.050 + k * 0.012
                cut(pad, box("pr", (-0.04, BACK_Y - 0.012, zc - 0.0016), (0.04, BACK_Y - 0.003, zc + 0.0016), m["rubber"]))
        bevel_object(pad, 0.004, 3, 30.0)
        smooth(pad, 35)
        body.append(pad)
    # --- the barrel module's top: the bridge the sight stands on, in front of the magazine
    bridge = slab("Bridge", fillet([(MAG_Y[1] + 0.001, TOP_Z - 0.002, 0.0), (FRONT_Y, TOP_Z - 0.002, 0.004), (FRONT_Y - 0.004, 0.056, 0.008), (SIGHT_Y[1] + 0.002, 0.082, 0.01), (MAG_Y[1] + 0.003, 0.082, 0.004)], 6),
                  -BODY_W + 0.0015, BODY_W - 0.0015, m["polymer"])
    if ROUND >= 2:
        # A notch at its back that the nose of the magazine slides into.
        cut(bridge, box("nose", (-MAG_W - 0.0005, MAG_Y[1] - 0.02, MAG_Z[0] - 0.001), (MAG_W + 0.0005, MAG_Y[1] + 0.004, MAG_Z[1] - 0.004), m["polymer"], bevel=0.003))
    if ROUND >= 2:
        for side in (-1.0, 1.0):
            corner = box("corner", (side * BODY_W - 0.012, FRONT_Y - 0.022, -0.05), (side * BODY_W + 0.012, FRONT_Y + 0.03, 0.2), m["polymer"])
            rotate(corner, side * math.radians(28.0), "Z", Vector((side * BODY_W, FRONT_Y - 0.022, 0.0)))
            cut(bridge, corner)
    bevel_object(bridge, 0.0048, 3, 30.0)
    smooth(bridge, 35)
    body.append(bridge)
    # --- the ring sight's housing: rounded on top, a tunnel through it, its front sloped
    section = rounded_rect(-0.0215, 0.0215, 0.078, SIGHT_TOP, 0.01, 0.003) if ROUND < 2 else fillet([(HOUSING_W[0], 0.078, 0.003), (HOUSING_W[1], SIGHT_TOP, 0.013), (-HOUSING_W[1], SIGHT_TOP, 0.013), (-HOUSING_W[0], 0.078, 0.003)], 8)
    housing = prism("Housing", section, SIGHT_Y[0], SIGHT_Y[1], m["polymer"])
    cut(housing, cone("tunnel", (0, SIGHT_Y[0] - 0.02, SIGHT_Z), (0, SIGHT_Y[1] + 0.02, SIGHT_Z), sight_r(SIGHT_Y[0] - 0.02), sight_r(SIGHT_Y[1] + 0.02), m["polymer"], 40))
    if ROUND >= 2:
        slope = box("slope", (-0.05, SIGHT_Y[1], 0.02), (0.05, SIGHT_Y[1] + 0.08, 0.2), m["polymer"])
        rotate(slope, math.radians(40.0), "X", Vector((0, SIGHT_Y[1], 0.080)))
        cut(housing, slope)
        # The hood over the eyepiece reaches back a little further at the top.
        hood_w = (0.0196, 0.0172) if ROUND < 5 else (SIGHT_R + 0.0024, HOUSING_W[1] - 0.0012)
        hood = prism("Hood", fillet([(hood_w[0], SIGHT_Z + 0.002, 0.0), (hood_w[1], SIGHT_TOP - 0.0004, 0.012), (-hood_w[1], SIGHT_TOP - 0.0004, 0.012), (-hood_w[0], SIGHT_Z + 0.002, 0.0)], 8), SIGHT_Y[0] - 0.008, SIGHT_Y[0] + 0.006, m["polymer"])
        cut(hood, cylinder("tunnel", (0, SIGHT_Y[0] - 0.03, SIGHT_Z), (0, SIGHT_Y[0] + 0.03, SIGHT_Z), SIGHT_R + (0.0012 if ROUND < 5 else 0.0008), m["polymer"], 40))
        bevel_object(hood, 0.0018, 2, 30.0)
        smooth(hood, 35)
        body.append(hood)
    bevel_object(housing, 0.0025 if ROUND >= 2 else 0.003, 3, 30.0)
    smooth(housing, 35)
    body.append(housing)
    # Inside the tunnel: dark, so that it reads as a tube and not as a hole in the picture.
    lining_end = 0.100 if ROUND >= 2 else SIGHT_Y[1] - 0.012
    tube = cone("TunnelLining", (0, SIGHT_Y[0] + 0.004, SIGHT_Z), (0, lining_end, SIGHT_Z), sight_r(SIGHT_Y[0] + 0.004) + 0.0004, sight_r(lining_end) + 0.0004, m["dark"], 40)
    # (Only its wall: the end faces would close the tube.)
    bm = bmesh.new()
    bm.from_mesh(tube.data)
    caps = [f for f in bm.faces if abs(f.normal.y) > 0.9]
    bmesh.ops.delete(bm, geom=caps, context="FACES")
    bm.to_mesh(tube.data)
    bm.free()
    for p in tube.data.polygons:
        p.flip()
    smooth(tube, 60)
    body.append(tube)
    if ROUND >= 2:
        # The objective's rim at the front, the eyepiece's at the back; the knob that sets the
        # reticle's height on the right, the lamp switch on the left.
        for y0, y1, r in ((0.096, 0.1, sight_r(0.098) + 0.0004), (SIGHT_Y[0] - 0.0005, SIGHT_Y[0] + 0.003, SIGHT_R + 0.0004)):
            # (From round 5 thin lips: the front one is the edge of what is seen through it.)
            rim = cylinder("Rim", (0, y0, SIGHT_Z), (0, y1, SIGHT_Z), r + (0.0018 if ROUND < 5 else 0.0012), m["steel"], 40)
            cut(rim, cylinder("in", (0, y0 - 0.01, SIGHT_Z), (0, y1 + 0.01, SIGHT_Z), r - (0.0012 if ROUND < 5 else 0.0006), m["steel"], 40))
            smooth(rim, 40)
            body.append(rim)
        knob = cylinder("Elevation", (0.0205 + SIDE_IN, 0.082, SIGHT_Z + 0.004), (0.0262 + SIDE_IN, 0.082, SIGHT_Z + 0.004), 0.0062, m["polymer"], 24, bevel=0.0012)
        body.append(knob)
        sw = cylinder("Switch", (-0.0205 - SIDE_IN, 0.070, SIGHT_Z + 0.004), (-0.0245 - SIDE_IN, 0.070, SIGHT_Z + 0.004), 0.0052, m["polymer"], 24, bevel=0.001)
        body.append(sw)
    if ROUND >= 3:
        # Ribs round the knob, a slot in it; the lamp switch's arrow; four screws that hold the
        # housing to the bridge.
        for k in range(16):
            a = math.tau * k / 16
            body.append(box("kr", (0.0258 + SIDE_IN, 0.082 + math.cos(a) * 0.0062 - 0.0005, SIGHT_Z + 0.004 + math.sin(a) * 0.0062 - 0.0005), (0.0264 + SIDE_IN, 0.082 + math.cos(a) * 0.0062 + 0.0005, SIGHT_Z + 0.004 + math.sin(a) * 0.0062 + 0.0005), m["polymer"]))
        body.append(box("KnobSlot", (0.0262 + SIDE_IN, 0.0815 - 0.004, SIGHT_Z + 0.0035), (0.0266 + SIDE_IN, 0.0825 + 0.004, SIGHT_Z + 0.0045), m["dark"]))
        body.append(box("SwitchMark", (-0.0248 - SIDE_IN, 0.0695, SIGHT_Z + 0.0065), (-0.0244 - SIDE_IN, 0.0705, SIGHT_Z + 0.0085), m["white"]))
        for side in (-1.0, 1.0):
            for y in (0.040, 0.118):
                s = cylinder("Screw", (side * (0.0213 + SIDE_IN), y, 0.084), (side * (0.0226 + SIDE_IN), y, 0.084), 0.0022, m["steel"], 14)
                body.append(s)
                body.append(box("ScrewHex", (side * (0.0225 + SIDE_IN) - 0.0002, y - 0.0009, 0.0831), (side * (0.0225 + SIDE_IN) + 0.0004 * side, y + 0.0009, 0.0849), m["dark"]))
    if ROUND >= 4:
        # The emergency iron sights moulded on both top edges of the housing: a notch at the
        # back, a post at the front, for when the sight's glass is broken or fogged.
        for side in (-1.0, 1.0):
            x = side * 0.0158
            notch = box("BackupRear", (x - 0.0024, SIGHT_Y[0] + 0.006, SIGHT_TOP - 0.010), (x + 0.0024, SIGHT_Y[0] + 0.012, SIGHT_TOP + 0.0042), m["polymer"], bevel=0.0007)
            cut(notch, box("v", (x - 0.0008, SIGHT_Y[0] + 0.004, SIGHT_TOP + 0.0018), (x + 0.0008, SIGHT_Y[0] + 0.014, SIGHT_TOP + 0.006), m["polymer"]))
            body.append(notch)
            body.append(box("BackupFront", (x - 0.0009, 0.084, SIGHT_TOP - 0.010), (x + 0.0009, 0.089, SIGHT_TOP + 0.0036), m["polymer"], bevel=0.0004))
    # --- the barrel, the collar where it leaves the body, the flash hider
    body.append(cylinder("Collar", (0, FRONT_Y - 0.006, BORE_Z), (0, FRONT_Y + 0.006, BORE_Z), 0.0125, m["polymer"], 32, bevel=0.002))
    body.append(cylinder("Barrel", (0, FRONT_Y - 0.004, BORE_Z), (0, HIDER_Y + 0.004, BORE_Z), 0.0068, m["steel"], 28))
    hider = cylinder("Hider", (0, HIDER_Y, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.0098, m["steel"], 32, bevel=0.0012 if ROUND >= 2 else 0.0)
    cut(hider, cylinder("bore", (0, HIDER_Y + 0.004, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0064 if ROUND >= 2 else BORE_R, m["steel"], 24))
    if ROUND >= 2:
        # Six slots round the front of the flash hider.
        for k in range(6):
            a = math.tau * k / 6.0
            s = box("slot", (-0.0016, MUZZLE_Y - 0.019, 0.0), (0.0016, MUZZLE_Y - 0.004, 0.02), m["steel"], bevel=0.0006)
            s.data.transform(Matrix.Translation((0, 0, BORE_Z)) @ Matrix.Rotation(a, 4, "Y"))
            cut(hider, s)
    smooth(hider, 35)
    body.append(hider)
    body.append(cylinder("Bore", (0, HIDER_Y + 0.002, BORE_Z), (0, MUZZLE_Y - 0.006, BORE_Z), 0.0064 if ROUND >= 2 else BORE_R, m["dark"], 20))
    if ROUND >= 2:
        body.append(cylinder("Muzzle", (0, MUZZLE_Y - 0.03, BORE_Z), (0, MUZZLE_Y - 0.008, BORE_Z), BORE_R + 0.0006, m["steel"], 18))
        body.append(cylinder("BoreDeep", (0, MUZZLE_Y - 0.009, BORE_Z), (0, MUZZLE_Y - 0.0085, BORE_Z), BORE_R, m["dark"], 18))
    # --- the charging handles, one each side, under the sight
    if ROUND >= 2:
        for side in (-1.0, 1.0):
            knob = cylinder("Handle", (side * (BODY_W - 0.002), HANDLE.y, HANDLE.z), (side * (BODY_W + 0.0075), HANDLE.y, HANDLE.z), 0.0048, m["polymer"], 20, bevel=0.0014)
            body.append(knob)
            body.append(cylinder("HandleCap", (side * (BODY_W + 0.0068), HANDLE.y, HANDLE.z), (side * (BODY_W + 0.0092), HANDLE.y, HANDLE.z), 0.0058, m["polymer"], 24, bevel=0.0011))
            if ROUND >= 3:
                for k in range(3):
                    x = side * (BODY_W + 0.0015 + k * 0.0018)
                    body.append(cylinder("HandleRing", (x - 0.0003, HANDLE.y, HANDLE.z), (x + 0.0003, HANDLE.y, HANDLE.z), 0.0052, m["polymer"], 20))
    # --- the trigger, at the top of the loop's back
    t = box("TriggerBlade", (-0.0034, TRIGGER_PIVOT.y - 0.004, -0.030), (0.0034, TRIGGER_PIVOT.y + 0.003, TRIGGER_PIVOT.z + 0.002), m["polymer"], bevel=0.0014)
    rotate(t, math.radians(-8.0), "X", TRIGGER_PIVOT)
    trig.append(t)
    if ROUND >= 2:
        tip = box("TriggerTip", (-0.0034, TRIGGER_PIVOT.y - 0.0015, -0.036), (0.0034, TRIGGER_PIVOT.y + 0.006, -0.026), m["polymer"], bevel=0.0014)
        trig.append(tip)
        # Its front face grooved across.
        if False:
            for k in range(4):
                z = -0.012 - k * 0.0055
                trig.append(box("tg", (-0.0035, TRIGGER_PIVOT.y + 0.0012 + (z + 0.006) * -0.14, z - 0.0007), (0.0035, TRIGGER_PIVOT.y + 0.0042 + (z + 0.006) * -0.14, z + 0.0007), m["polymer"]))
        # The slot in the loop's roof it comes down from.
        body.append(box("TriggerSlot", (-0.0045, TRIGGER_PIVOT.y - 0.007, -0.0072), (0.0045, TRIGGER_PIVOT.y + 0.007, -0.0058), m["dark"]))
    # --- the fire selector: a disc set into the floor of the loop, under the trigger
    if ROUND >= 2:
        disc = cylinder("Selector", (SELECTOR.x, SELECTOR.y, SELECTOR.z - 0.002), (SELECTOR.x, SELECTOR.y, SELECTOR.z + 0.0035), 0.0125, m["polymer"], 40, bevel=0.0012)
        body.append(disc)
        # Its ridge, which the trigger finger turns it by.
        ridge = box("SelectorRidge", (-0.0105, SELECTOR.y - 0.0018, SELECTOR.z + 0.003), (0.0105, SELECTOR.y + 0.0018, SELECTOR.z + 0.0075), m["polymer"], bevel=0.0012)
        rotate(ridge, math.radians(-20.0), "Z", SELECTOR)
        body.append(ridge)
        if ROUND >= 3:
            # S - 1 - A: safe, single, automatic.
            for k, (letter, mat) in enumerate((("S", m["white"]), ("1", m["white"]), ("A", m["red"]))):
                a = math.radians(-40.0 + 40.0 * k)
                at = Vector((math.sin(a) * 0.0145, SELECTOR.y - math.cos(a) * 0.0145 + 0.0, SELECTOR.z + 0.0002))
                body.append(engrave_top(letter, at, 0.0036, mat))
    # --- sling points: a slot in the butt's foot, a loop at the top of the front bar on the left
    if ROUND >= 2:
        lug = box("SlingLug", (-0.006, BACK_Y + 0.024, -0.092), (0.006, BACK_Y + 0.046, -0.074), m["polymer"], bevel=0.003)
        cut(lug, box("ls", (-0.01, BACK_Y + 0.030, -0.088), (0.01, BACK_Y + 0.040, -0.082), m["polymer"], bevel=0.0015))
        smooth(lug, 35)
        body.append(lug)
        loop = cylinder("SlingLoop", (-FRAME_W - 0.0005, 0.122, -0.016), (-FRAME_W - 0.0045, 0.122, -0.016), 0.0058, m["steel"], 24, bevel=0.0008)
        cut(loop, cylinder("li", (-0.03, 0.122, -0.016), (0.0, 0.122, -0.016), 0.0033, m["steel"], 18))
        smooth(loop, 35)
        body.append(loop)
    # --- the magazine release behind the magazine, and the catch the shell's tab locks to
    if ROUND >= 2:
        rel = box("MagRelease", (-0.012, MAG_Y[0] - 0.016, TOP_Z - 0.002), (0.012, MAG_Y[0] - 0.003, TOP_Z + 0.012), m["polymer"], bevel=0.003)
        if ROUND >= 3:
            for k in range(3):
                cut(rel, box("rg", (-0.02, MAG_Y[0] - 0.015 + k * 0.004, TOP_Z + 0.009), (0.02, MAG_Y[0] - 0.0135 + k * 0.004, TOP_Z + 0.014), m["polymer"]))
        smooth(rel, 35)
        body.append(rel)
    # --- pins and markings
    if ROUND >= 3:
        for y, z in ((-0.150, 0.020), (0.012, 0.022), (0.085, 0.020), (-0.270, -0.030)):
            for side in (-1.0, 1.0):
                w = BODY_W if y < -0.14 or z > -0.006 else FRAME_W
                body.append(cylinder("Pin", (side * (w - 0.0006), y, z), (side * (w + 0.0004), y, z), 0.0026, m["steel"], 16))
                body.append(cylinder("PinHead", (side * (w + 0.0002), y, z), (side * (w + 0.0006), y, z), 0.0019, m["dark"], 12))
        body.append(engrave_left("P90", Vector((-BODY_W - 0.0002, 0.012, 0.016)), 0.0095, m["marking"]))
        body.append(engrave_left("5,7x28", Vector((-BODY_W - 0.0002, -0.060, 0.022)), 0.0052, m["marking"]))
        body.append(engrave_left("NW 090 117", Vector((-BODY_W - 0.0002, -0.060, 0.012)), 0.0036, m["marking"]))
        # The arrows on the magazine release: push forward.
        body.append(engrave_top(">", Vector((0.0, MAG_Y[0] - 0.012, TOP_Z + 0.0122)), 0.006, m["white"]))
    # --- the magazine: the translucent shell, its black rear end that turns the rounds, the
    # follower at its nose, and fifty rounds lying across it in two rows
    mz0, mz1 = MAG_Z
    profile = rounded_rect(-MAG_W, MAG_W, mz0, mz1, 0.007 if ROUND >= 2 else 0.005, 0.003, 6)
    rear_len = 0.030 if ROUND >= 2 else 0.018
    case = prism("ShellBody", profile, MAG_Y[0] + rear_len - 0.002, MAG_Y[1], m["shell"])
    if ROUND >= 2:
        # Its nose: rounded off at the front.
        bevel_object(case, 0.004, 3, 60.0)
        # A rib along each top edge and the window strip down the middle of the top.
        for side in (-1.0, 1.0):
            shell.append(box("ShellRib", (side * (MAG_W - 0.006) - 0.0016, MAG_Y[0] + rear_len, mz1 - 0.0004), (side * (MAG_W - 0.006) + 0.0016, MAG_Y[1] - 0.006, mz1 + 0.0012), m["shell"], bevel=0.0007))
    smooth(case, 50)
    shell.append(case)
    rear = prism("MagRear", profile, MAG_Y[0], MAG_Y[0] + rear_len, m["magblack"])
    if ROUND >= 2:
        # The tab at its back that the release locks over, and grip ribs on its sides.
        tab = box("MagTab", (-0.009, MAG_Y[0] - 0.003, mz0 + 0.004), (0.009, MAG_Y[0] + 0.004, mz1 - 0.008), m["magblack"], bevel=0.0015)
        union(rear, tab)
        for side in (-1.0, 1.0):
            for k in range(4):
                y = MAG_Y[0] + 0.006 + k * 0.0055
                cut(rear, box("mr", (side * MAG_W - 0.0012, y, mz0 + 0.006), (side * MAG_W + 0.0012, y + 0.0022, mz1 - 0.006), m["magblack"]))
    bevel_object(rear, 0.0018, 2, 30.0)
    smooth(rear, 35)
    mag.append(rear)
    # The rounds: 5.7 x 28, lying across (bullets to the left), two rows staggered; the last
    # ones at the back turning towards the barrel on the feed ramp.
    first = MAG_Y[0] + rear_len + 0.0045
    last = MAG_Y[1] - 0.010
    pitch = (last - first) / (ROUNDS - 1)
    seg = 12 if ROUND >= 2 else 8
    for i in range(ROUNDS):
        y = first + i * pitch
        z = mz0 + 0.0102 + (0.0076 if i % 2 else 0.0)
        turn = 0.0
        if ROUND >= 3 and i < 3:
            turn = math.radians((3 - i) * 22.0)
        parts = []
        base_x, case_end, neck_end, tip_x = 0.0196, -0.0094, -0.0112, -0.0206
        parts.append(cylinder("Case", (base_x, y, z), (case_end, y, z), 0.0038, m["brass"], seg))
        parts.append(cone("Neck", (case_end, y, z), (neck_end, y, z), 0.0038, 0.0031, m["brass"], seg))
        parts.append(cone("Bullet", (neck_end, y, z), (tip_x + 0.0032, y, z), 0.00285, 0.0016, m["copper"], seg))
        parts.append(cone("Tip", (tip_x + 0.0032, y, z), (tip_x, y, z), 0.0016, 0.0003, m["tip"], seg))
        if ROUND >= 3:
            # The rim and the extractor groove before it, the primer in the base.
            parts.append(cylinder("Rim", (base_x - 0.0011, y, z), (base_x, y, z), 0.0040, m["brass"], seg))
            parts.append(cylinder("Groove", (base_x - 0.0022, y, z), (base_x - 0.0011, y, z), 0.0033, m["brass"], seg))
            parts.append(cylinder("Primer", (base_x, y, z), (base_x + 0.0002, y, z), 0.0016, m["steel"], seg))
        if turn != 0.0:
            for p in parts:
                rotate(p, -turn, "Z", Vector((0.0, y, z)))
        mag.extend(parts)
    if ROUND >= 2:
        # The follower at the nose, and the spring's last coil behind it.
        mag.append(box("Follower", (-MAG_W + 0.003, MAG_Y[1] - 0.009, mz0 + 0.004), (MAG_W - 0.003, MAG_Y[1] - 0.004, mz1 - 0.004), m["magblack"], bevel=0.0015))
        # The ramp inside the rear end that turns the rounds: seen through the shell's back.
        ramp = box("Ramp", (-MAG_W + 0.004, MAG_Y[0] + rear_len - 0.004, mz0 + 0.003), (MAG_W - 0.004, MAG_Y[0] + rear_len + 0.002, mz1 - 0.003), m["magblack"])
        mag.append(ramp)
    if ROUND >= 3:
        # Moulded on the shell's floor: the count marks, every ten rounds, white.
        for k in range(1, 5):
            y = first + (k * 10 - 0.5) * pitch
            mag.append(box("Count", (MAG_W - 0.0105, y - 0.0005, mz0 + 0.0006), (MAG_W - 0.0035, y + 0.0005, mz0 + 0.0012), m["white"]))
    return body, mag, trig, shell


def engrave_left(text, at, size, material):
    """Flat lettering on the left face, reading from the muzzle backwards as one sees it
    from the left; 'at' is where its first letter begins."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.extrude = 0.00012
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


def engrave_top(text, at, size, material):
    """Lettering on an upward face, readable from behind (the shooter's side), centred on at."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.00012
    letters = link(bpy.data.objects.new("Marking", curve))
    bpy.context.view_layer.objects.active = letters
    bpy.ops.object.select_all(action="DESELECT")
    letters.select_set(True)
    bpy.ops.object.convert(target="MESH")
    letters = bpy.context.view_layer.objects.active
    letters.data.transform(Matrix.Translation(at))
    letters.data.materials.clear()
    letters.data.materials.append(material)
    return letters


# ------------------------------------------------------------------ bake
def bake(objs, prefix="p90"):
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
    for key, socket in (("metal", "metal_socket"), ("base", "colour_socket")):
        for mat in mats:
            nt = mat.node_tree
            name, index = mat[socket].split(":")
            emit = nt.nodes.new("ShaderNodeEmission")
            nt.links.new(nt.nodes[name].outputs[int(index)], emit.inputs["Color"])
            nt.links.new(emit.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
        run("EMIT", images[key])
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


def final_material(images, name="p90"):
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
CENTRE = (0.0, -0.045, 0.012)
VIEWS = [
    # name, camera, target, lens (mm)
    ("schraeg", (-0.62, 0.62, 0.30), (0.0, -0.03, 0.01), 60),
    ("links", (-1.25, -0.045, 0.02), CENTRE, 70),
    ("rechts", (1.25, -0.045, 0.02), CENTRE, 70),
    ("hinten_schraeg", (-0.38, -0.70, 0.34), (0.0, -0.06, 0.04), 55),
    ("oben", (0.0, -0.045, 1.2), (0.0, -0.045, 0.0), 70),
    ("unten", (-0.35, 0.0, -0.75), (0.0, -0.03, -0.04), 60),
    ("nah_visier", (-0.26, -0.20, 0.22), (0.0, 0.07, 0.09), 55),
    ("nah_vorn", (0.26, 0.48, 0.06), (0.0, 0.12, 0.0), 55),
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


def render_views(folder, prefix, only=None):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    use_gpu(scene)
    scene.cycles.samples = 64
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
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0, -0.045, -0.16))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor")
    floor_mat.use_nodes = True
    floor.data.materials.append(floor_mat)
    setups = {
        "studio": [("key", "AREA", (-0.9, -0.5, 1.1), CENTRE, 30.0, (1.0, 0.97, 0.92), 1.0),
                   ("fill", "AREA", (1.0, 0.4, 0.5), CENTRE, 10.0, (0.85, 0.9, 1.0), 1.2),
                   ("rim", "AREA", (0.2, 1.2, 0.8), CENTRE, 24.0, (1.0, 1.0, 1.0), 0.7)],
        "nacht": [("lamp", "POINT", (-0.5, -0.25, 0.7), CENTRE, 22.0, (1.0, 0.72, 0.45), 0.1),
                  ("cold", "AREA", (0.4, 1.0, 0.4), CENTRE, 16.0, (0.45, 0.6, 1.0), 0.5)],
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
            if only and name not in only:
                continue
            if setup == "nacht" and name not in ("schraeg", "links"):
                continue
            cam.data.lens = lens
            floor.hide_render = name == "unten"
            look_from(cam, pos, target)
            scene.render.filepath = os.path.join(folder, "%s_%s_%s.png" % (prefix, name, setup))
            bpy.ops.render.render(write_still=True)
        for obj in made:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(floor, do_unlink=True)
    print("RENDERED", folder, prefix)


def place_origin(obj, point):
    obj.data.transform(Matrix.Translation(-Vector(point)))
    obj.location = Vector(point)


def main():
    clear()
    m = make_materials()
    body_parts, mag_parts, trigger_parts, shell_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(mag_parts, "Magazine")
    trigger = join(trigger_parts, "Trigger")
    shell = join(shell_parts, "Shell")
    parts = (body, magazine, trigger)
    for o in parts + (shell,):
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
        bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.003, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        images = bake(list(parts), "p90")
        final = final_material(images, "p90")
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    # The moving parts move about their own places; the shell goes with the magazine.
    mag_origin = (0.0, MAG_Y[0], MAG_Z[0])
    place_origin(magazine, mag_origin)
    shell.data.transform(Matrix.Translation(-Vector(mag_origin)))
    shell.parent = magazine
    shell.location = (0.0, 0.0, 0.0)
    place_origin(trigger, TRIGGER_PIVOT)
    root = link(bpy.data.objects.new("P90", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "magazine", triangles(magazine), "shell", triangles(shell), "trigger", triangles(trigger),
          "all", sum(triangles(o) for o in parts + (shell,)), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % BORE_R, "sight axis %.4f top %.4f rear %.4f front %.4f" % (SIGHT_Z, SIGHT_TOP, SIGHT_Y[0], SIGHT_Y[1]))
    print("SPEC handle", godot(HANDLE), "trigger", godot(TRIGGER_PIVOT), "magazine", godot(mag_origin), "support", godot(SUPPORT))
    print("SPEC eject", godot((0.0, (CHUTE_Y[0] + CHUTE_Y[1]) * 0.5, -0.075)), "magazine_rear_left", godot((-MAG_W, MAG_Y[0] + 0.03, (MAG_Z[0] + MAG_Z[1]) * 0.5)))
    if BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
    if NOBAKE:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts + (shell, root):
        o.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_image_quality=90)
    print("EXPORTED", OUT, os.path.getsize(OUT), "bytes")


main()
