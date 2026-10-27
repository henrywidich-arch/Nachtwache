# Builds the minigun for Nachtwache, from nothing (it replaces the old minigun.glb, which
# stays in the folder unused), after Henry's reference picture: a six-barrelled rotary gun
# in black, gritty, worn metal. Six long barrels held by three clamp rings and a muzzle ring
# with a hole for each bore, a big drum-like housing behind them, a boxy receiver with a
# data plate, a long carry handle on top that runs back to the rear grip (a pistol grip
# rising at the back, a red fire button at the top of it), a Picatinny rail under the
# handle, a cylindrical motor and battery pod underneath with yellow hazard stripes, and
# cables and hoses running along it.
# Every part is made here, bevelled, given its material, UV-unwrapped and baked into one
# texture set (base colour, roughness and metal, normal), then written as a GLB with the
# nodes
#   Minigun > Body / Barrels (the six barrels, their clamps, the muzzle ring and the rotor
#   plate; its origin on the axis of the cluster, so that the game spins it about its z)
#
#   blender --background --factory-startup --python tools/blender_make_minigun.py -- [--round 4] [--tex 4096]
#           [--out assets/models/minigun_built.glb] [--render <folder> --prefix minigun_r1] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
# --render: fixed views (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the rear grip (where the right hand closes). The glTF exporter turns this into Godot
# space (barrels along -Z, up +Y). The places the game needs (MODELS["minigun"] in
# weapon_view.gd) are printed.
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
ROUND = int(arg("--round", "4"))
TEX = int(arg("--tex", "4096"))
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "minigun_built.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "minigun_r%d" % ROUND)
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
    # (Round 4: larger, blotchier patches - the gun is big and seen at arm's length.)
    noise.inputs["Scale"].default_value = 160.0 if ROUND == 1 else (480.0 if ROUND < 4 else 110.0)
    noise.inputs["Detail"].default_value = 6.0
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    colour = nodes.new("ShaderNodeMix")
    colour.data_type = "RGBA"
    spread = 0.14 if ROUND == 1 else (0.1 if ROUND < 4 else 0.24)
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
            bev.inputs["Radius"].default_value = 0.0011 if ROUND < 4 else 0.0022
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
        if stipple == "grit":
            # Gritty, pitted metal: a fine rough grain with shallow pits scattered in it.
            grain = nodes.new("ShaderNodeTexNoise")
            grain.inputs["Scale"].default_value = bump_scale
            grain.inputs["Detail"].default_value = 12.0
            grain.inputs["Roughness"].default_value = 0.7
            links.new(coords.outputs["Object"], grain.inputs["Vector"])
            pits = nodes.new("ShaderNodeTexVoronoi")
            pits.inputs["Scale"].default_value = bump_scale * 0.35
            links.new(coords.outputs["Object"], pits.inputs["Vector"])
            pit = nodes.new("ShaderNodeMapRange")
            pit.inputs[1].default_value = 0.0
            pit.inputs[2].default_value = 0.25
            links.new(pits.outputs["Distance"], pit.inputs[0])
            height = nodes.new("ShaderNodeMath")
            height.operation = "MULTIPLY"
            links.new(grain.outputs["Fac"], height.inputs[0])
            links.new(pit.outputs[0], height.inputs[1])
            links.new(height.outputs[0], bump_node.inputs["Height"])
        elif stipple:
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


# ------------------------------------------------------------------ more helpers
def annulus(name, centre, y0, y1, r_out, r_in, material, segments=48, a0=0.0, a1=math.tau):
    """A ring round an axis along y through `centre` ((x, z)), from y0 to y1; with a0/a1 only
    the part between those angles (measured from +x towards +z), closed at its ends."""
    full = abs(a1 - a0 - math.tau) < 1e-6
    n = segments if full else max(2, int(segments * (a1 - a0) / math.tau)) + 1
    bm = bmesh.new()
    rings = []
    for y in (y0, y1):
        for r in (r_out, r_in):
            row = []
            for k in range(n):
                a = a0 + (a1 - a0) * k / (n if full else n - 1)
                row.append(bm.verts.new((centre[0] + math.cos(a) * r, y, centre[1] + math.sin(a) * r)))
            rings.append(row)
    oa, ia, ob, ib = rings[0], rings[1], rings[2], rings[3]
    count = n if full else n - 1
    for k in range(count):
        j = (k + 1) % n
        bm.faces.new((oa[k], oa[j], ob[j], ob[k]))
        bm.faces.new((ia[k], ib[k], ib[j], ia[j]))
        bm.faces.new((oa[k], ia[k], ia[j], oa[j]))
        bm.faces.new((ob[k], ob[j], ib[j], ib[k]))
    if not full:
        for e in (0, n - 1):
            bm.faces.new((oa[e], ob[e], ib[e], ia[e]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


def curve_tube(name, points, radius, material, resolution=10):
    """A hose: a smooth curve through `points` with a round section of `radius`."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    curve.resolution_u = resolution
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, p in zip(spline.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    obj = link(bpy.data.objects.new(name, curve))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.data.materials.clear()
    obj.data.materials.append(material)
    smooth(obj, 70)
    return obj


def engrave_right(text, at, size, material, centre=False):
    """Flat lettering on the right face (normal +x), read from that side: it runs forward."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.extrude = 0.00012
    if centre:
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
    letters = link(bpy.data.objects.new("Marking", curve))
    bpy.context.view_layer.objects.active = letters
    bpy.ops.object.select_all(action="DESELECT")
    letters.select_set(True)
    bpy.ops.object.convert(target="MESH")
    letters = bpy.context.view_layer.objects.active
    turn = Matrix(((0.0, 0.0, 1.0, 0.0), (1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    letters.data.transform(Matrix.Translation(at) @ turn)
    letters.data.materials.clear()
    letters.data.materials.append(material)
    return letters


def engrave_left(text, at, size, material, centre=False):
    """Flat lettering on the left face (normal -x), read from that side: it runs backwards."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.extrude = 0.00012
    if centre:
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
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


def hazard_material(name="hazard"):
    """Yellow and black diagonal stripes, a little scuffed (baked like the others)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], sep.inputs[0])
    # Stripes across y + z (and x + z on the faces that look forward): every 9 mm.
    add = nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    links.new(sep.outputs["Y"], add.inputs[0])
    links.new(sep.outputs["Z"], add.inputs[1])
    add2 = nodes.new("ShaderNodeMath")
    add2.operation = "ADD"
    links.new(add.outputs[0], add2.inputs[0])
    links.new(sep.outputs["X"], add2.inputs[1])
    scale = nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = 1.0 / 0.009
    links.new(add2.outputs[0], scale.inputs[0])
    frac = nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    links.new(scale.outputs[0], frac.inputs[0])
    step = nodes.new("ShaderNodeMath")
    step.operation = "GREATER_THAN"
    step.inputs[1].default_value = 0.5
    links.new(frac.outputs[0], step.inputs[0])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 300.0
    noise.inputs["Detail"].default_value = 8.0
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    scuff = nodes.new("ShaderNodeMapRange")
    scuff.inputs[1].default_value = 0.62
    scuff.inputs[2].default_value = 0.72
    links.new(noise.outputs["Fac"], scuff.inputs[0])
    colour = nodes.new("ShaderNodeMix")
    colour.data_type = "RGBA"
    colour.inputs[6].default_value = (0.020, 0.020, 0.020, 1.0)
    colour.inputs[7].default_value = (0.62, 0.42, 0.03, 1.0)
    links.new(step.outputs[0], colour.inputs[0])
    worn = nodes.new("ShaderNodeMix")
    worn.data_type = "RGBA"
    links.new(scuff.outputs[0], worn.inputs[0])
    links.new(colour.outputs[2], worn.inputs[6])
    worn.inputs[7].default_value = (0.09, 0.09, 0.09, 1.0)
    links.new(worn.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    metal = nodes.new("ShaderNodeValue")
    metal.outputs[0].default_value = 0.0
    links.new(metal.outputs[0], bsdf.inputs["Metallic"])
    mat["metal_socket"] = metal.name + ":0"
    mat["colour_socket"] = worn.name + ":2"
    return mat


def make_materials():
    wear = {1: 0.0, 2: 0.45, 3: 0.85}.get(ROUND, 0.95)
    grit = ROUND >= 3
    # The black of the gun: worn steel, the paint rubbed to bare metal on the edges.
    steel = material("steel", (0.034, 0.035, 0.037) if ROUND < 4 else (0.026, 0.027, 0.029), 0.5 if ROUND < 4 else 0.42, 0.75, wear=0.8 * wear, grime=0.7 if ROUND >= 2 else 0.0,
                     bump=0.12 if grit else 0.0, bump_scale=1400.0, stipple="grit", worn=(0.30, 0.30, 0.31) if ROUND < 4 else (0.40, 0.40, 0.41))
    # The receiver and the housing: a duller, matt black finish.
    parker = material("parker", (0.040, 0.041, 0.043) if ROUND < 4 else (0.029, 0.030, 0.032), 0.66, 0.5, wear=0.7 * wear, grime=0.8 if ROUND >= 2 else 0.0,
                      bump=0.16 if grit else 0.0, bump_scale=1800.0, stipple="grit", worn=(0.27, 0.27, 0.28) if ROUND < 4 else (0.34, 0.34, 0.35))
    # The barrels: darker, a little oily.
    barrel = material("barrel", (0.022, 0.022, 0.024), 0.38, 0.9, wear=0.5 * wear, grime=0.5 if ROUND >= 2 else 0.0,
                      bump=0.06 if grit else 0.0, bump_scale=900.0, stipple=False, worn=(0.26, 0.26, 0.27))
    rubber = material("rubber", (0.022, 0.022, 0.024), 0.88, 0.0, wear=0.2 * wear, grime=0.5 if ROUND >= 2 else 0.0,
                      bump=0.7 if grit else 0.0, bump_scale=2400.0, stipple=True, worn=(0.07, 0.07, 0.075))
    hose = material("hose", (0.018, 0.018, 0.02), 0.62, 0.0, grime=0.4 if ROUND >= 2 else 0.0)
    dark = material("dark", (0.005, 0.005, 0.006), 0.9, 0.0)
    red = material("red", (0.62, 0.035, 0.025), 0.4, 0.0, wear=0.3 * wear, worn=(0.3, 0.08, 0.06)) if ROUND >= 2 else steel
    plate = material("plate", (0.28, 0.28, 0.27), 0.42, 0.9, grime=0.6, wear=0.4 * wear, worn=(0.5, 0.5, 0.5)) if ROUND >= 2 else parker
    white = material("white", (0.55, 0.55, 0.52), 0.6, 0.0) if ROUND >= 3 else parker
    hazard = hazard_material() if ROUND >= 2 else parker
    brass = material("brass", (0.62, 0.46, 0.2), 0.36, 1.0, grime=0.4)
    copper = material("copper", (0.48, 0.28, 0.16), 0.36, 1.0, grime=0.3)
    return {"steel": steel, "parker": parker, "barrel": barrel, "rubber": rubber, "hose": hose, "dark": dark, "red": red,
            "plate": plate, "white": white, "hazard": hazard, "brass": brass, "copper": copper}


# ------------------------------------------------------------------ the measures
# (From the reference: the gun is 98 cm from the back of the grip's foot to the muzzle.)
BORE_Z = -0.080                 # the axis of the barrel cluster, 8 cm under the grip's middle
MUZZLE_Y = 0.930                # the face of the muzzle ring
CLUSTER_R = 0.0375              # how far each barrel's axis is from the cluster's
BARREL_R = 0.0112
BORE_R = 0.0052
BARREL_Y0 = 0.436               # where the barrels leave the rotor plate
HOUSING_Y = (0.326, 0.433)      # the drum-like housing the barrels turn in
HOUSING_R = 0.076
RECEIVER_Y = (0.040, 0.334)
RECEIVER_W = 0.042              # half its width
RECEIVER_Z = (-0.080, 0.0)
POD_Z = -0.128                  # the motor and battery pod's axis
POD_R = 0.050
POD_Y = (0.072, 0.306)
HANDLE_Y = (0.150, 0.402)       # the carry handle, from the back of its rear leg to the front of its front leg
HANDLE_Z = (0.046, 0.072)       # its bar
HANDLE_W = 0.011
SUPPORT = Vector((0.0, 0.275, 0.059))   # where the left hand holds it: the middle of the bar
RAIL_Y = (0.184, 0.326)
RAIL_Z = 0.012                  # the top of the rail
GRIP_LEAN = math.radians(15.0)  # the rear grip leans forward at the top
CLAMPS = [(0.585, 0.655, 0.061), (0.725, 0.772, 0.058), (0.798, 0.840, 0.058)]
MUZZLE_RING = (0.868, MUZZLE_Y, 0.060)
PIVOT = Vector((0.0, HOUSING_Y[1], BORE_Z))   # the origin of the Barrels node


def axis_cyl(name, y0, y1, r, material, segments=48, bevel=0.0, at=(0.0, BORE_Z)):
    """A cylinder along y about the axis through (x, z) = at."""
    return cylinder(name, (at[0], y0, at[1]), (at[0], y1, at[1]), r, material, segments, bevel=bevel)


def barrel_angles():
    # One barrel on top, one at the bottom, two on each side: seen from the side, four rows.
    return [math.radians(90.0 + 60.0 * k) for k in range(6)]


def lean(obj, pivot_z=0.0):
    """Leans a part forward like the grip: y moves on with height."""
    t = math.tan(GRIP_LEAN)
    obj.data.transform(Matrix(((1, 0, 0, 0), (0, 1, t, -t * pivot_z), (0, 0, 1, 0), (0, 0, 0, 1))))


def build(m):
    body, spin = [], []
    seg = 32 if ROUND == 1 else 48
    # --- the receiver: a long box, its top edges well rounded
    section = rounded_rect(-RECEIVER_W, RECEIVER_W, RECEIVER_Z[0], RECEIVER_Z[1], 0.012, 0.006, 6)
    receiver = prism("Receiver", section, RECEIVER_Y[0], RECEIVER_Y[1], m["parker"])
    if ROUND >= 2:
        # Seams: the cover over the top and the joint between front and rear halves.
        for side in (-1.0, 1.0):
            cut(receiver, box("seam", (side * RECEIVER_W - 0.0008, RECEIVER_Y[0] + 0.01, -0.0105), (side * RECEIVER_W + 0.0008, RECEIVER_Y[1] - 0.012, -0.0095), m["parker"]))
        cut(receiver, box("joint", (-0.06, 0.2195, -0.1), (0.06, 0.2205, -0.0105), m["parker"]))
        # The feed port on the left: the belt of rounds comes in here from the ammunition box.
        cut(receiver, box("port", (-RECEIVER_W - 0.01, 0.105, -0.068), (-RECEIVER_W + 0.006, 0.185, -0.036), m["parker"], bevel=0.003))
    bevel_object(receiver, 0.003, 2, 35.0)
    smooth(receiver, 35)
    body.append(receiver)
    # The collar between the receiver and the housing.
    body.append(axis_cyl("Collar", RECEIVER_Y[1] - 0.012, HOUSING_Y[0] + 0.004, 0.058, m["steel"], seg, bevel=0.002))
    # --- the housing: the big drum the barrels turn in
    housing = axis_cyl("Housing", HOUSING_Y[0], HOUSING_Y[1], HOUSING_R, m["parker"], 64 if ROUND >= 2 else seg, bevel=0.003)
    smooth(housing, 35)
    body.append(housing)
    if ROUND >= 2:
        # Its lips front and back, and eight raised plates round it with gaps between.
        for y0, y1 in ((HOUSING_Y[0] - 0.002, HOUSING_Y[0] + 0.009), (HOUSING_Y[1] - 0.010, HOUSING_Y[1] + 0.001)):
            lip = annulus("HousingLip", (0.0, BORE_Z), y0, y1, HOUSING_R + 0.0045, HOUSING_R - 0.01, m["steel"], 64)
            bevel_object(lip, 0.0012, 2, 35.0)
            smooth(lip, 35)
            body.append(lip)
        for k in range(8):
            a = math.tau * k / 8 + math.radians(22.5)
            plate = annulus("HousingPlate", (0.0, BORE_Z), HOUSING_Y[0] + 0.013, HOUSING_Y[1] - 0.014, HOUSING_R + 0.0035, HOUSING_R - 0.004, m["parker"], 64, a - math.radians(19.5), a + math.radians(19.5))
            bevel_object(plate, 0.0012, 2, 35.0)
            smooth(plate, 35)
            body.append(plate)
            if ROUND >= 3:
                # Four screws in each plate.
                for da in (-14.0, 14.0):
                    for y in (HOUSING_Y[0] + 0.022, HOUSING_Y[1] - 0.023):
                        b = a + math.radians(da)
                        c = Vector((math.cos(b) * (HOUSING_R + 0.0035), y, BORE_Z + math.sin(b) * (HOUSING_R + 0.0035)))
                        n = Vector((math.cos(b), 0.0, math.sin(b)))
                        body.append(cylinder("Screw", c - n * 0.001, c + n * 0.0016, 0.0026, m["steel"], 12, bevel=0.0006))
                        body.append(cylinder("ScrewHex", c + n * 0.0012, c + n * 0.0018, 0.0012, m["dark"], 6))
    # The front face of the housing: dark round the rotor plate, where the barrels come out.
    body.append(axis_cyl("HousingFace", HOUSING_Y[1] - 0.003, HOUSING_Y[1] + 0.0005, HOUSING_R - 0.012, m["dark"], seg))
    # --- the motor and battery pod under the receiver
    pod = axis_cyl("Pod", POD_Y[0], POD_Y[1], POD_R, m["parker"], seg, bevel=0.006, at=(0.0, POD_Z))
    smooth(pod, 35)
    body.append(pod)
    if ROUND >= 2:
        # Bands round both ends and two straps that hold it to the receiver.
        for y0, y1 in ((POD_Y[0] - 0.002, POD_Y[0] + 0.024), (POD_Y[1] - 0.030, POD_Y[1] + 0.002)):
            band = annulus("PodBand", (0.0, POD_Z), y0, y1, POD_R + 0.004, POD_R - 0.01, m["steel"], seg)
            bevel_object(band, 0.0015, 2, 35.0)
            smooth(band, 35)
            body.append(band)
        for y in (0.150, 0.232):
            strap = annulus("PodStrap", (0.0, POD_Z), y, y + 0.012, POD_R + 0.0028, POD_R - 0.004, m["steel"], seg)
            bevel_object(strap, 0.0008, 2, 35.0)
            smooth(strap, 35)
            body.append(strap)
            for side in (-1.0, 1.0):
                lug = box("StrapLug", (side * 0.026 - 0.008, y - 0.002, POD_Z + 0.036), (side * 0.026 + 0.008, y + 0.014, RECEIVER_Z[0] + 0.006), m["steel"], bevel=0.0015)
                body.append(lug)
        # The end caps: a connector at the back for the cable, a vent grille at the front.
        body.append(cylinder("PodPlug", (0.012, POD_Y[0] - 0.016, POD_Z + 0.012), (0.012, POD_Y[0] + 0.004, POD_Z + 0.012), 0.012, m["steel"], 24, bevel=0.002))
        body.append(cylinder("PodPlugNut", (0.012, POD_Y[0] - 0.012, POD_Z + 0.012), (0.012, POD_Y[0] - 0.004, POD_Z + 0.012), 0.0145, m["steel"], 6, bevel=0.001))
        # Hazard stripes on both sides, and a small label under each.
        # (Curved, lying on the pod: angles from +x towards +z.)
        for side in (-1.0, 1.0):
            def at(deg):
                return math.radians(deg if side > 0 else 180.0 - deg)
            lo, hi = sorted((at(9.0), at(36.0)))
            body.append(annulus("Hazard", (0.0, POD_Z), 0.166, 0.224, POD_R + 0.0014, POD_R - 0.001, m["hazard"], 96, lo, hi))
            if ROUND >= 3:
                lo, hi = sorted((at(-13.0), at(4.0)))
                body.append(annulus("Tag", (0.0, POD_Z), 0.172, 0.218, POD_R + 0.001, POD_R - 0.001, m["plate"], 96, lo, hi))
    if ROUND >= 3:
        # Cooling ribs round the pod's front half, and its labels' lettering.
        for k in range(6):
            y = 0.248 + k * 0.007
            rib = annulus("PodRib", (0.0, POD_Z), y, y + 0.0028, POD_R + 0.0018, POD_R - 0.003, m["parker"], seg)
            smooth(rib, 35)
            body.append(rib)
        body.append(engrave_right("24V  LI-ION", Vector((POD_R + 0.0013, 0.1765, POD_Z - 0.0055)), 0.0042, m["dark"]))
        body.append(engrave_left("24V  LI-ION", Vector((-POD_R - 0.0013, 0.2135, POD_Z - 0.0055)), 0.0042, m["dark"]))
    # --- the rear block under the grip, which the receiver's back is fixed to
    block = box("RearBlock", (-0.030, -0.060, -0.090), (0.030, RECEIVER_Y[0] + 0.03, -0.044), m["parker"], bevel=0.006 if ROUND >= 2 else 0.004, segments=3)
    if ROUND >= 2:
        # A recess in its back with a plate in it.
        cut(block, box("recess", (-0.022, -0.066, -0.082), (0.022, -0.056, -0.052), m["parker"], bevel=0.002))
    smooth(block, 35)
    body.append(block)
    if ROUND >= 2:
        body.append(box("BackPlate", (-0.0205, -0.0585, -0.0805), (0.0205, -0.055, -0.0535), m["steel"], bevel=0.001))
    # --- the rear grip, rising from the block and leaning forward
    gsec = fillet([(0.016, -0.021, 0.008), (0.016, 0.019, 0.012), (-0.016, 0.019, 0.012), (-0.016, -0.021, 0.008)], 6)
    if ROUND >= 4:
        # (After round 3: the grip read as a thin stick beside the reference's chunky one. Now
        # wider, deeper, its back swelling into the palm.)
        gsec = fillet([(0.0185, -0.026, 0.014), (0.0185, 0.021, 0.014), (-0.0185, 0.021, 0.014), (-0.0185, -0.026, 0.014), (0.0, -0.030, 0.0)], 6)
    grip = upright("Grip", gsec, -0.050, 0.046, m["rubber"])
    if ROUND >= 3:
        # Finger grooves down its front.
        for z in (0.020, -0.002, -0.024):
            cut(grip, cylinder("groove", (-0.03, 0.0285, z), (0.03, 0.0285, z), 0.0125, m["rubber"], 24))
    lean(grip)
    bevel_object(grip, 0.004, 3, 30.0)
    smooth(grip, 40)
    body.append(grip)
    # Its head: wider, the fire button at the front of its top.
    head = box("GripHead", (-0.0195, -0.020, 0.040), (0.0195, 0.048, 0.074), m["steel"], bevel=0.007 if ROUND >= 2 else 0.005, segments=3)
    smooth(head, 35)
    body.append(head)
    if ROUND >= 4:
        # A tail over the web of the hand at the back of the head, sloping down.
        tail = box("GripTail", (-0.017, -0.040, 0.047), (0.017, -0.010, 0.066), m["steel"], bevel=0.006, segments=3)
        rotate(tail, math.radians(-18.0), "X", Vector((0.0, -0.012, 0.056)))
        smooth(tail, 35)
        body.append(tail)
    if ROUND >= 2:
        button_at = Vector((0.0, 0.052, 0.062))
        guard = cylinder("ButtonGuard", button_at - Vector((0, 0.008, 0)), button_at + Vector((0, 0.002, 0)), 0.0105, m["steel"], 32, bevel=0.0012)
        cut(guard, cylinder("in", button_at - Vector((0, 0.004, 0)), button_at + Vector((0, 0.01, 0)), 0.0078, m["steel"], 32))
        smooth(guard, 35)
        body.append(guard)
        body.append(cylinder("Button", button_at - Vector((0, 0.006, 0)), button_at + Vector((0, 0.0005, 0)), 0.0072, m["red"], 32, bevel=0.0018))
    if ROUND >= 3:
        # The safety: a small lever on the left of the head, and a lamp on top.
        safety = box("Safety", (-0.0235, 0.004, 0.050), (-0.0185, 0.026, 0.060), m["steel"], bevel=0.0015)
        rotate(safety, math.radians(-12.0), "X", Vector((0, 0.004, 0.055)))
        body.append(safety)
        body.append(cylinder("SafetyPin", (-0.0245, 0.006, 0.055), (-0.0185, 0.006, 0.055), 0.004, m["steel"], 16, bevel=0.0008))
        body.append(cylinder("Lamp", (0.0, 0.0, 0.073), (0.0, 0.0, 0.0765), 0.005, m["steel"], 20, bevel=0.0008))
        body.append(cylinder("LampGlass", (0.0, 0.0, 0.0755), (0.0, 0.0, 0.0772), 0.0034, m["red"], 20))
        for side in (-1.0, 1.0):
            body.append(cylinder("HeadScrew", (side * 0.0193, 0.034, 0.057), (side * 0.0209, 0.034, 0.057), 0.0024, m["steel"], 12))
    # --- the top frame from the grip's head forward to the handle's rear leg
    frame = slab("TopFrame", fillet([(0.030, 0.058, 0.0), (0.070, 0.058, 0.012), (0.118, 0.014, 0.012), (0.176, 0.014, 0.0), (0.176, -0.002, 0.0),
                                     (0.112, -0.002, 0.01), (0.064, 0.042, 0.01), (0.030, 0.042, 0.0)], 6), -0.009, 0.009, m["steel"])
    bevel_object(frame, 0.0025, 2, 35.0)
    smooth(frame, 35)
    body.append(frame)
    # --- the carry handle: a U of flat bar from the receiver's back to the housing
    y0, y1 = HANDLE_Y
    z0, z1 = HANDLE_Z
    outline = fillet([(y0, -0.002, 0.0), (y0, z1, 0.012), (y1, z1, 0.012), (y1, -0.006, 0.0), (y1 - 0.026, -0.006, 0.0),
                      (y1 - 0.026, z0, 0.008), (y0 + 0.026, z0, 0.008), (y0 + 0.026, -0.002, 0.0)], 6)
    handle = slab("Handle", outline, -HANDLE_W, HANDLE_W, m["steel"])
    bevel_object(handle, 0.0028, 2, 35.0)
    smooth(handle, 35)
    body.append(handle)
    # Its foot on the housing: a saddle clamped round the top.
    saddle = annulus("Saddle", (0.0, BORE_Z), y1 - 0.034, y1 + 0.004, HOUSING_R + 0.009, HOUSING_R + 0.002, m["steel"], 64, math.radians(62), math.radians(118))
    bevel_object(saddle, 0.0012, 2, 35.0)
    smooth(saddle, 35)
    body.append(saddle)
    if ROUND >= 2:
        # The rubber sleeve the hand holds, ribbed.
        sleeve = prism("HandleGrip", rounded_rect(-HANDLE_W - 0.003, HANDLE_W + 0.003, z0 - 0.003, z1 + 0.003, 0.009, 0.009, 6), 0.198, 0.352, m["rubber"])
        if ROUND >= 3:
            for k in range(14):
                y = 0.205 + k * 0.0105
                cut(sleeve, box("rib", (-0.03, y, z0 - 0.01), (0.03, y + 0.0028, z0 - 0.0006), m["rubber"]))
        bevel_object(sleeve, 0.003, 3, 35.0)
        smooth(sleeve, 40)
        body.append(sleeve)
    if ROUND >= 3:
        # The bolts through the handle's legs.
        for y in (y0 + 0.013, y1 - 0.013):
            for side in (-1.0, 1.0):
                body.append(cylinder("LegBolt", (side * (HANDLE_W - 0.001), y, z0 - 0.022), (side * (HANDLE_W + 0.0022), y, z0 - 0.022), 0.0042, m["steel"], 6, bevel=0.0006))
    # --- the Picatinny rail under the handle
    rail = box("RailBase", (-0.0105, RAIL_Y[0], RECEIVER_Z[1] - 0.002), (0.0105, RAIL_Y[1], RAIL_Z - 0.0042), m["steel"], bevel=0.0008)
    body.append(rail)
    if ROUND >= 2:
        y = RAIL_Y[0] + 0.004
        while y + 0.0052 < RAIL_Y[1] - 0.003:
            tooth = prism("RailTooth", [(0.0105, RAIL_Z - 0.0042), (0.0082, RAIL_Z), (-0.0082, RAIL_Z), (-0.0105, RAIL_Z - 0.0042)], y, y + 0.0052, m["steel"])
            bevel_object(tooth, 0.0004, 1, 35.0)
            body.append(tooth)
            y += 0.01
    else:
        body.append(box("RailTop", (-0.0082, RAIL_Y[0], RAIL_Z - 0.0042), (0.0082, RAIL_Y[1], RAIL_Z), m["steel"]))
    # --- the receiver's sides
    if ROUND >= 2:
        for side in (-1.0, 1.0):
            x = side * RECEIVER_W
            # A raised plate along each side.
            pl = box("SidePlate", (min(x, x + side * 0.0035), 0.052, -0.070), (max(x, x + side * 0.0035), 0.212, -0.016), m["parker"], bevel=0.0012)
            if side < 0:
                cut(pl, box("portcut", (-RECEIVER_W - 0.02, 0.103, -0.070), (-RECEIVER_W + 0.004, 0.187, -0.034), m["parker"], bevel=0.003))
            body.append(pl)
        # The feed port's lips and the dark inside, with the tip of a cartridge belt showing.
        body.append(box("PortInside", (-RECEIVER_W + 0.004, 0.106, -0.067), (-RECEIVER_W + 0.006, 0.184, -0.037), m["dark"]))
        if ROUND >= 3:
            # Two rounds of the belt in the port, along the barrels, held by their links.
            for x in (-RECEIVER_W + 0.001, -RECEIVER_W - 0.011):
                body.append(cylinder("Case", (x, 0.112, -0.052), (x, 0.160, -0.052), 0.0058, m["brass"], 16))
                body.append(cone("Neck", (x, 0.160, -0.052), (x, 0.166, -0.052), 0.0058, 0.0042, m["brass"], 16))
                body.append(cone("Bullet", (x, 0.166, -0.052), (x, 0.183, -0.052), 0.0042, 0.0012, m["copper"], 16))
                for y in (0.122, 0.148):
                    body.append(annulus("Link", (x, -0.052), y, y + 0.007, 0.0072, 0.0059, m["steel"], 20))
        for z in (-0.0715, -0.0315):
            body.append(box("PortLip", (-RECEIVER_W - 0.006, 0.100, z - 0.0025), (-RECEIVER_W + 0.001, 0.190, z + 0.0025), m["steel"], bevel=0.0008))
        # Right side: the box with the data plate, and the control box before it.
        db = box("PlateBox", (RECEIVER_W + 0.002, 0.136, -0.062), (RECEIVER_W + 0.010, 0.198, -0.012), m["parker"], bevel=0.002)
        body.append(db)
        body.append(box("DataPlate", (RECEIVER_W + 0.0095, 0.141, -0.057), (RECEIVER_W + 0.0108, 0.193, -0.017), m["plate"], bevel=0.0004))
        cb = box("ControlBox", (RECEIVER_W + 0.002, 0.228, -0.044), (RECEIVER_W + 0.013, 0.300, -0.008), m["parker"], bevel=0.0025)
        body.append(cb)
        body.append(cylinder("Connector", (RECEIVER_W + 0.013, 0.282, -0.026), (RECEIVER_W + 0.022, 0.282, -0.026), 0.0075, m["steel"], 24, bevel=0.0012))
        body.append(cylinder("ConnectorNut", (RECEIVER_W + 0.012, 0.282, -0.026), (RECEIVER_W + 0.017, 0.282, -0.026), 0.009, m["steel"], 6, bevel=0.0008))
        # Left side: the gearbox block before the feed port, vents cut in it.
        gb = box("Gearbox", (-RECEIVER_W - 0.012, 0.222, -0.066), (-RECEIVER_W + 0.002, 0.312, -0.014), m["parker"], bevel=0.0025)
        if ROUND >= 3:
            for k in range(6):
                z = -0.058 + k * 0.0072
                cut(gb, box("vent", (-RECEIVER_W - 0.02, 0.236, z), (-RECEIVER_W - 0.0095, 0.296, z + 0.0034), m["parker"], bevel=0.0008))
        smooth(gb, 35)
        body.append(gb)
        if ROUND >= 3:
            body.append(box("VentBack", (-RECEIVER_W - 0.0098, 0.234, -0.060), (-RECEIVER_W - 0.0094, 0.298, -0.018), m["dark"]))
    if ROUND >= 3:
        # Screws along the side plates, the corners of the data plate and the boxes.
        for side in (-1.0, 1.0):
            x = side * (RECEIVER_W + 0.0035)
            for y in (0.060, 0.120, 0.204) if side > 0 else (0.060, 0.096, 0.196, 0.204):
                for z in (-0.064, -0.022):
                    body.append(cylinder("Screw", (x - side * 0.0005, y, z), (x + side * 0.0013, y, z), 0.0023, m["steel"], 12, bevel=0.0004))
        for y in (0.1445, 0.1895):
            for z in (-0.0535, -0.0205):
                body.append(cylinder("Rivet", (RECEIVER_W + 0.0105, y, z), (RECEIVER_W + 0.0118, y, z), 0.0013, m["steel"], 10))
        for y in (0.234, 0.294):
            for z in (-0.039, -0.013):
                body.append(cylinder("Screw", (RECEIVER_W + 0.0125, y, z), (RECEIVER_W + 0.0142, y, z), 0.002, m["steel"], 12))
        # The data plate's lettering.
        body.append(engrave_right("NACHTWACHE", Vector((RECEIVER_W + 0.0109, 0.1455, -0.0255)), 0.0058, m["dark"]))
        body.append(engrave_right("M134-NW  7,62x51", Vector((RECEIVER_W + 0.0109, 0.1455, -0.0355)), 0.0038, m["dark"]))
        body.append(engrave_right("SER 0417  6000/MIN", Vector((RECEIVER_W + 0.0109, 0.1455, -0.0435)), 0.0034, m["dark"]))
        body.append(engrave_right("24 V DC", Vector((RECEIVER_W + 0.0109, 0.1455, -0.0525)), 0.0034, m["dark"]))
        # The control box's switch and its two lamps.
        body.append(box("Toggle", (RECEIVER_W + 0.013, 0.244, -0.030), (RECEIVER_W + 0.021, 0.250, -0.022), m["steel"], bevel=0.001))
        for z, mat in ((-0.016, m["red"]), (-0.0355, m["white"])):
            body.append(cylinder("Lamp", (RECEIVER_W + 0.012, 0.262, z), (RECEIVER_W + 0.0155, 0.262, z), 0.0032, mat, 16))
        # White marks on the left: the arrow of the belt's way in.
        body.append(engrave_left("FEED >", Vector((-RECEIVER_W - 0.0036, 0.196, -0.0275)), 0.0048, m["white"]))
        body.append(engrave_left("NW-M134", Vector((-RECEIVER_W - 0.0036, 0.096, -0.0205)), 0.0062, m["white"]))
    # --- cables and hoses
    if ROUND >= 2:
        # From the grip's foot down into the back of the pod: the power cable, thick.
        body.append(curve_tube("PowerCable", [(0.024, -0.024, -0.060), (0.036, -0.008, -0.100), (0.030, 0.026, -0.134), (0.018, 0.048, -0.122), (0.012, POD_Y[0] - 0.014, POD_Z + 0.012)], 0.0085, m["hose"]))
        # A second, thinner line from the block into the pod from below.
        body.append(curve_tube("SignalCable", [(-0.024, -0.020, -0.084), (-0.030, 0.000, -0.118), (-0.026, 0.040, -0.160), (-0.012, POD_Y[0] + 0.004, -0.170)], 0.0058, m["hose"]))
        # From the grip's head, over the top frame and along the receiver's top edge on the
        # right, to the control box: the trigger's line.
        body.append(curve_tube("TriggerLine", [(0.016, 0.004, 0.044), (0.020, 0.050, 0.036), (0.028, 0.110, 0.006), (0.036, 0.170, -0.004), (0.040, 0.226, -0.008), (RECEIVER_W + 0.006, 0.246, -0.012)], 0.0042, m["hose"]))
        # On the left: a hose from the block forward along the receiver to the gearbox.
        body.append(curve_tube("Hose", [(-0.026, 0.010, -0.050), (-0.040, 0.050, -0.036), (-0.046, 0.090, -0.012), (-0.044, 0.160, -0.006), (-0.046, 0.230, -0.010), (-RECEIVER_W - 0.008, 0.252, -0.016)], 0.0052, m["hose"]))
    if ROUND >= 3:
        # Clips that hold the lines to the gun, and the cable's sleeves at its ends.
        for at, size in (((0.036, 0.170, -0.004), 0.0062), ((0.040, 0.226, -0.008), 0.0062), ((-0.044, 0.160, -0.006), 0.0072), ((-0.045, 0.205, -0.008), 0.0072)):
            body.append(cylinder("Clip", (at[0], at[1] - 0.004, at[2]), (at[0], at[1] + 0.004, at[2]), size, m["steel"], 16, bevel=0.0008))
        body.append(cylinder("CableSleeve", (0.022, -0.026, -0.054), (0.023, -0.016, -0.068), 0.0092, m["steel"], 20, bevel=0.001))
    # --- the spinning part: rotor plate, barrels, spindle, clamps, muzzle ring
    spin.append(axis_cyl("Rotor", HOUSING_Y[1] - 0.004, BARREL_Y0 + 0.006, HOUSING_R - 0.016, m["steel"], seg, bevel=0.0015))
    spin.append(axis_cyl("Hub", BARREL_Y0, BARREL_Y0 + 0.022, 0.024, m["steel"], seg, bevel=0.0015))
    for a in barrel_angles():
        cx, cz = math.cos(a) * CLUSTER_R, BORE_Z + math.sin(a) * CLUSTER_R
        b = cylinder("Barrel", (cx, BARREL_Y0, cz), (cx, MUZZLE_Y - 0.0035, cz), BARREL_R, m["barrel"], 24 if ROUND >= 2 else 16)
        smooth(b, 40)
        spin.append(b)
        spin.append(cylinder("Bore", (cx, MUZZLE_Y - 0.006, cz), (cx, MUZZLE_Y - 0.003, cz), BORE_R, m["dark"], 16))
        if ROUND >= 2:
            # The thicker breech end of each barrel, where it is screwed into the rotor.
            spin.append(cylinder("Breech", (cx, BARREL_Y0, cz), (cx, BARREL_Y0 + 0.03, cz), BARREL_R + 0.0018, m["barrel"], 24, bevel=0.001))
    spin.append(axis_cyl("Spindle", BARREL_Y0, MUZZLE_Y - 0.01, 0.011, m["steel"], 24))
    for k, (c0, c1, r) in enumerate(CLAMPS):
        core = axis_cyl("Clamp", c0 + 0.003, c1 - 0.003, r - 0.004, m["steel"], 64 if ROUND >= 2 else seg, bevel=0.0015)
        smooth(core, 35)
        spin.append(core)
        if ROUND >= 2:
            width = 0.017 if k == 0 else 0.012
            for y0, y1 in ((c0, c0 + width), (c1 - width, c1)):
                band = annulus("ClampBand", (0.0, BORE_Z), y0, y1, r, r - 0.012, m["steel"], 64)
                bevel_object(band, 0.0014, 2, 35.0)
                smooth(band, 35)
                spin.append(band)
            if ROUND >= 3:
                # Bolts round the bands, between the barrels.
                for j, a in enumerate(barrel_angles()):
                    b = a + math.radians(30.0)
                    n = Vector((math.cos(b), 0.0, math.sin(b)))
                    for y in ((c0 + width * 0.5, c1 - width * 0.5) if k == 0 else ((c0 + c1) * 0.5,)):
                        c = Vector((0.0, y, BORE_Z)) + n * r
                        spin.append(cylinder("ClampBolt", c - n * 0.001, c + n * 0.003, 0.0032, m["steel"], 6, bevel=0.0006))
    # The muzzle ring: a disc with a hole for each barrel, one in the middle, and smaller ones
    # round its rim.
    m0, m1, mr = MUZZLE_RING
    ring = axis_cyl("MuzzleRing", m0, m1, mr, m["steel"], 64 if ROUND >= 2 else seg)
    cutters = []
    for a in barrel_angles():
        cx, cz = math.cos(a) * CLUSTER_R, BORE_Z + math.sin(a) * CLUSTER_R
        cutters.append(cylinder("hole", (cx, m1 - 0.006, cz), (cx, m1 + 0.01, cz), BARREL_R + 0.0012, m["steel"], 24))
    cutters.append(axis_cyl("mid", m1 - 0.012, m1 + 0.01, 0.0135, m["steel"], 32))
    if ROUND >= 2:
        for a in barrel_angles():
            b = a + math.radians(30.0)
            cutters.append(cylinder("rimhole", (math.cos(b) * 0.050, m1 - 0.007, BORE_Z + math.sin(b) * 0.050), (math.cos(b) * 0.050, m1 + 0.01, BORE_Z + math.sin(b) * 0.050), 0.0042, m["steel"], 16))
    cutter = join(cutters, "cutter")
    cut(ring, cutter)
    bevel_object(ring, 0.0022, 2, 35.0)
    smooth(ring, 35)
    spin.append(ring)
    spin.append(axis_cyl("MidHole", m1 - 0.012, m1 - 0.011, 0.0136, m["dark"], 32))
    if ROUND >= 2:
        for a in barrel_angles():
            b = a + math.radians(30.0)
            spin.append(cylinder("RimHole", (math.cos(b) * 0.050, m1 - 0.0068, BORE_Z + math.sin(b) * 0.050), (math.cos(b) * 0.050, m1 - 0.0062, BORE_Z + math.sin(b) * 0.050), 0.0043, m["dark"], 16))
        # A band round the back of the muzzle ring.
        band = annulus("MuzzleBand", (0.0, BORE_Z), m0 - 0.002, m0 + 0.012, mr + 0.003, mr - 0.01, m["steel"], 64)
        bevel_object(band, 0.0014, 2, 35.0)
        smooth(band, 35)
        spin.append(band)
    return body, spin


# ------------------------------------------------------------------ review pictures
CENTRE = (0.0, 0.43, -0.05)
VIEWS = [
    # name, camera, target, lens (mm)
    ("schraeg", (-1.15, 1.55, 0.62), (0.0, 0.42, -0.04), 50),
    ("links", (-2.0, 0.43, -0.03), CENTRE, 60),
    ("rechts", (2.0, 0.43, -0.03), CENTRE, 60),
    ("hinten_schraeg", (-0.42, -0.52, 0.36), (0.02, 0.36, -0.06), 32),
    ("oben", (0.0, 0.43, 2.0), (0.0, 0.43, 0.0), 60),
    ("unten", (-0.7, 0.5, -1.7), (0.0, 0.43, -0.08), 55),
    ("nah_hinten", (0.42, -0.30, 0.22), (0.0, 0.10, -0.02), 45),
    ("nah_vorn", (0.30, 1.32, 0.06), (0.0, 0.82, -0.08), 45),
]


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
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0, 0.43, -0.30))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor")
    floor_mat.use_nodes = True
    floor.data.materials.append(floor_mat)
    setups = {
        "studio": [("key", "AREA", (-1.4, -0.4, 1.7), CENTRE, 90.0, (1.0, 0.97, 0.92), 1.4),
                   ("fill", "AREA", (1.6, 0.9, 0.8), CENTRE, 35.0, (0.85, 0.9, 1.0), 1.6),
                   ("rim", "AREA", (0.3, 2.3, 1.3), CENTRE, 70.0, (1.0, 1.0, 1.0), 1.0)],
        "nacht": [("lamp", "POINT", (-0.8, -0.2, 1.0), CENTRE, 60.0, (1.0, 0.72, 0.45), 0.1),
                  ("cold", "AREA", (0.7, 1.7, 0.7), CENTRE, 45.0, (0.45, 0.6, 1.0), 0.7)],
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
            if setup == "nacht" and name not in ("schraeg", "rechts", "hinten_schraeg"):
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


def weighted(obj):
    """Normals weighted by face area: the big flat faces shade flat, and the long thin
    triangles that the cuts and bevels leave on them no longer show as streaks (round 4)."""
    mod = obj.modifiers.new("Weighted", "WEIGHTED_NORMAL")
    mod.mode = "FACE_AREA"
    mod.weight = 50
    mod.keep_sharp = True
    apply(obj, mod)


def main():
    clear()
    m = make_materials()
    body_parts, spin_parts = build(m)
    body = join(body_parts, "Body")
    barrels = join(spin_parts, "Barrels")
    parts = (body, barrels)
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if ROUND >= 4:
            weighted(o)
    if not NOBAKE:
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.002, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        images = bake(list(parts), "minigun")
        final = final_material(images, "minigun")
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    # The barrels spin about the cluster's axis: their origin lies on it.
    place_origin(barrels, PIVOT)
    root = link(bpy.data.objects.new("Minigun", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "barrels", triangles(barrels), "all", sum(triangles(o) for o in parts), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "barrels pivot", godot(PIVOT), "support", godot(SUPPORT), "rail %.4f" % RAIL_Z)
    if BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
    if NOBAKE:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts + (root,):
        o.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_image_quality=90)
    print("EXPORTED", OUT, os.path.getsize(OUT), "bytes")


main()
