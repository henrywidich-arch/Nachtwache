# Builds the M21E for Nachtwache (the weapon with the id "mg2", the second machine gun), from
# nothing. It replaces the model made from the user's two generated meshes
# (tools/blender_make_mg2.py, assets/models/mg2.glb, which stay in the folder unused) and
# keeps its concept: a roller-delayed 7.62 machine gun of the G3 family - a stamped steel
# receiver with a cocking tube over the barrel, a ventilated handguard, a fixed stock - fed
# from a 75-round drum that hangs in the middle under the magazine well. The drum's own axis
# lies along the barrel: one round face looks at the muzzle, the other, with the winding key
# (two wings round a boss), at the shooter, and the box of its feed tower goes up into the
# back of the well. Aimed over the notch of its rear sight and its hooded front post.
# Every part is made here, bevelled, given its material, UV-unwrapped and baked: the gun
# into one texture set (base colour, roughness and metal, normal), the drum into a set of
# its own (it comes off the gun, and the game gives it a material of its own). Written as a
# GLB with the nodes
#   MG2 > Body / Magazine (the drum; its origin on its own axis, in the middle)
#
#   blender --background --factory-startup --python tools/blender_make_mg2_built.py -- [--round 4] [--tex 2048]
#           [--out assets/models/mg2_built.glb] [--render <folder> --prefix mg2_r1] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
# --render: fixed views (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the pistol grip. The glTF exporter turns this into Godot space (barrel along -Z, up +Y).
# The places the game needs (GUNS["mg2"] in weapon_view.gd) are printed; they are the ones
# the old model had, so that the hands and the reload stay as they were.
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
ROUND = int(arg("--round", "4"))
TEX = int(arg("--tex", "2048"))
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "mg2_built.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "mg2_r%d" % ROUND)
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




def make_materials():
    wear = {1: 0.0, 2: 0.45, 3: 0.85}.get(ROUND, 0.9)
    grit = ROUND >= 3
    # The receiver and the other stamped steel: dark grey-black phosphate, the edges rubbed.
    steel = material("steel", (0.034, 0.035, 0.037) if ROUND < 4 else (0.027, 0.028, 0.030), 0.52, 0.7, wear=0.75 * wear, grime=0.7 if ROUND >= 2 else 0.0,
                     bump=0.1 if grit else 0.0, bump_scale=1600.0, stipple="grit", worn=(0.36, 0.36, 0.37))
    # The barrel, the cocking tube and the small parts: blued, a little glossier.
    blued = material("blued", (0.026, 0.027, 0.030), 0.36, 0.9, wear=0.6 * wear, grime=0.5 if ROUND >= 2 else 0.0, worn=(0.34, 0.34, 0.36))
    # Stock, handguard and grip: black polymer, finely stippled.
    polymer = material("polymer", (0.030, 0.031, 0.033), 0.68, 0.0, wear=0.3 * wear, grime=0.7 if ROUND >= 2 else 0.0,
                       bump=0.1 if grit else 0.0, bump_scale=2600.0, stipple=True, worn=(0.10, 0.105, 0.11))
    # The drum: painted steel, black, worn through on its rims.
    drum = material("drum", (0.028, 0.029, 0.031) if ROUND < 4 else (0.022, 0.023, 0.025), 0.5, 0.65, wear=0.9 * wear, grime=0.7 if ROUND >= 2 else 0.0,
                    bump=0.1 if grit else 0.0, bump_scale=1400.0, stipple="grit", worn=(0.38, 0.38, 0.39))
    rubber = material("rubber", (0.022, 0.022, 0.024), 0.88, 0.0, grime=0.4, bump=0.5 if grit else 0.0, bump_scale=900.0, stipple=True)
    dark = material("dark", (0.005, 0.005, 0.006), 0.9, 0.0)
    brass = material("brass", (0.62, 0.46, 0.2), 0.36, 1.0, grime=0.4)
    copper = material("copper", (0.48, 0.28, 0.16), 0.36, 1.0, grime=0.3)
    white = material("white", (0.55, 0.55, 0.52), 0.6, 0.0) if ROUND >= 3 else steel
    red = material("red", (0.55, 0.05, 0.03), 0.5, 0.0) if ROUND >= 3 else steel
    return {"steel": steel, "blued": blued, "polymer": polymer, "drum": drum, "rubber": rubber, "dark": dark, "brass": brass,
            "copper": copper, "white": white, "red": red}


# ------------------------------------------------------------------ the measures
BORE_Z = 0.1165                 # the bore axis (as on the old model: the game's places stay)
MUZZLE_Y = 0.7094               # the face of the flash hider
HIDER_R = 0.0133
RECEIVER_Y = (-0.075, 0.300)
RECEIVER_Z = (0.062, 0.152)     # its top is where a sight is clamped (rail)
RECEIVER_W = 0.0235
TUBE_Z = 0.1385                 # the cocking tube over the barrel
TUBE_R = 0.0115
TUBE_Y = (0.280, 0.604)
HANDLE = Vector((-0.030, 0.520, 0.133))    # the cocking handle's knob, on the left
GUARD_Y = (0.300, 0.540)        # the handguard
GUARD_Z = (0.070, 0.124)
GUARD_W = 0.027
SUPPORT = Vector((0.0, 0.4104, 0.1093))    # where the left hand lies under the handguard
FRONT_Y = 0.575                 # the front post
POST_TIP = 0.1754               # its tip (irons)
REAR_Y = 0.0                    # the rear sight's notch, right over the grip
NOTCH = 0.180                   # the bottom of the notch: a little higher than the post
HOOD_Z = 0.170                  # the axis of the hood over the post
DRUM_C = Vector((0.0, 0.172, -0.062))      # the middle of the drum
DRUM_R = 0.085
DRUM_Y = (0.137, 0.209)         # its back face (the winding key) and its front face
TOWER_Y = (0.125, 0.160)        # the box of its feed tower
TOWER_TOP = 0.066
WELL_Y = (0.112, 0.172)         # the magazine well's housing under the receiver
WELL_Z = (0.030, 0.066)
STOCK_BACK = -0.310


def axis_cyl(name, y0, y1, r, material, segments=32, bevel=0.0, at=(0.0, BORE_Z)):
    """A cylinder along y about the axis through (x, z) = at."""
    return cylinder(name, (at[0], y0, at[1]), (at[0], y1, at[1]), r, material, segments, bevel=bevel)


def build(m):
    body, drum = [], []
    seg = 24 if ROUND == 1 else 40
    # --- the receiver: stamped steel, its upper corners chamfered
    prof = [(RECEIVER_W, RECEIVER_Z[0]), (RECEIVER_W, RECEIVER_Z[1] - 0.013), (RECEIVER_W - 0.0075, RECEIVER_Z[1]),
            (-RECEIVER_W + 0.0075, RECEIVER_Z[1]), (-RECEIVER_W, RECEIVER_Z[1] - 0.013), (-RECEIVER_W, RECEIVER_Z[0])]
    receiver = prism("Receiver", prof, RECEIVER_Y[0], RECEIVER_Y[1], m["steel"])
    if ROUND >= 2:
        # The long pressed channels along both sides, the ejection port on the right.
        for side in (-1.0, 1.0):
            cut(receiver, box("channel", (side * RECEIVER_W - 0.0016, 0.020, 0.117), (side * RECEIVER_W + 0.0016, 0.272, 0.126), m["steel"], bevel=0.0006))
            cut(receiver, box("channel2", (side * RECEIVER_W - 0.0014, -0.060, 0.080), (side * RECEIVER_W + 0.0014, 0.090, 0.086), m["steel"], bevel=0.0005))
        cut(receiver, box("port", (RECEIVER_W - 0.008, 0.060, 0.100), (RECEIVER_W + 0.01, 0.128, 0.131), m["steel"], bevel=0.002))
    if ROUND >= 4:
        # The recesses along both top edges that a claw mount for a sight bites into.
        for y in (0.040, 0.105, 0.170, 0.235):
            for side in (-1.0, 1.0):
                cut(receiver, box("claw", (side * (RECEIVER_W - 0.004) - 0.005, y, RECEIVER_Z[1] - 0.012), (side * (RECEIVER_W - 0.004) + 0.005, y + 0.012, RECEIVER_Z[1] - 0.006), m["steel"], bevel=0.001))
    bevel_object(receiver, 0.0018, 2, 35.0)
    smooth(receiver, 35)
    body.append(receiver)
    if ROUND >= 2:
        body.append(box("PortInside", (RECEIVER_W - 0.0085, 0.062, 0.101), (RECEIVER_W - 0.0065, 0.126, 0.13), m["dark"]))
        # The bolt's face, seen through the port.
        body.append(box("Bolt", (RECEIVER_W - 0.0075, 0.062, 0.106), (RECEIVER_W - 0.0045, 0.098, 0.126), m["blued"], bevel=0.0008))
        # The case deflector bump behind the port.
        body.append(box("Deflector", (RECEIVER_W - 0.002, 0.040, 0.100), (RECEIVER_W + 0.0045, 0.058, 0.130), m["steel"], bevel=0.002))
    # The front trunnion: the receiver's front end round the barrel and the tube.
    trunnion = box("Trunnion", (-RECEIVER_W - 0.001, RECEIVER_Y[1] - 0.030, 0.090), (RECEIVER_W + 0.001, RECEIVER_Y[1] + 0.008, 0.150), m["steel"], bevel=0.003)
    smooth(trunnion, 35)
    body.append(trunnion)
    # --- the lower: trigger housing (polymer), the pistol grip, the trigger guard
    lower = slab("Lower", fillet([(-0.062, 0.064, 0.0), (0.112, 0.064, 0.0), (0.112, 0.036, 0.006), (0.090, 0.022, 0.006), (0.020, 0.022, 0.0),
                                  (-0.020, 0.030, 0.01), (-0.062, 0.046, 0.012)], 6), -RECEIVER_W + 0.001, RECEIVER_W - 0.001, m["polymer"])
    bevel_object(lower, 0.003, 2, 35.0)
    smooth(lower, 35)
    body.append(lower)
    gsec = fillet([(0.0145, -0.024, 0.012), (0.0145, 0.016, 0.008), (-0.0145, 0.016, 0.008), (-0.0145, -0.024, 0.012)], 6)
    if ROUND >= 3:
        gsec = fillet([(0.0145, -0.024, 0.012), (0.0145, 0.016, 0.008), (-0.0145, 0.016, 0.008), (-0.0145, -0.024, 0.012), (0.0, -0.028, 0.0)], 6)
    if ROUND >= 4:
        # (After round 3: too thin for the hand round it.)
        gsec = fillet([(0.0165, -0.026, 0.013), (0.0165, 0.017, 0.009), (-0.0165, 0.017, 0.009), (-0.0165, -0.026, 0.013), (0.0, -0.030, 0.0)], 6)
    grip = upright("Grip", gsec, -0.072, 0.034, m["polymer"])
    if ROUND >= 3:
        for z in (0.006, -0.016, -0.038):
            cut(grip, cylinder("groove", (-0.03, 0.0255, z), (0.03, 0.0255, z), 0.011, m["polymer"], 24))
    # It leans back as it goes down.
    t = math.tan(math.radians(17.0))
    grip.data.transform(Matrix(((1, 0, 0, 0), (0, 1, t, 0), (0, 0, 1, 0), (0, 0, 0, 1))))
    bevel_object(grip, 0.0035, 3, 30.0)
    smooth(grip, 40)
    body.append(grip)
    body.append(box("GripFoot", (-0.0165, -0.050, -0.080), (0.0165, -0.003, -0.068), m["polymer"], bevel=0.004, segments=3))
    guard = slab("TriggerGuard", fillet([(0.014, 0.024, 0.0), (0.014, 0.004, 0.006), (0.092, 0.004, 0.008), (0.092, 0.024, 0.0), (0.084, 0.024, 0.0),
                                         (0.084, 0.011, 0.004), (0.020, 0.011, 0.004), (0.020, 0.024, 0.0)], 6), -0.007, 0.007, m["polymer"])
    bevel_object(guard, 0.0015, 2, 35.0)
    smooth(guard, 35)
    body.append(guard)
    trig = box("Trigger", (-0.0032, 0.038, 0.020), (0.0032, 0.046, 0.042), m["blued"], bevel=0.0014)
    rotate(trig, math.radians(-14.0), "X", Vector((0, 0.042, 0.04)))
    body.append(trig)
    # --- the magazine well's housing, open below, the release paddle behind it
    well = box("Well", (-RECEIVER_W + 0.0005, WELL_Y[0], WELL_Z[0]), (RECEIVER_W - 0.0005, WELL_Y[1], WELL_Z[1]), m["steel"], bevel=0.002)
    cut(well, box("mouth", (-0.0185, TOWER_Y[0] - 0.003, WELL_Z[0] - 0.01), (0.0185, TOWER_Y[1] + 0.004, WELL_Z[1] - 0.006), m["steel"]))
    smooth(well, 35)
    body.append(well)
    body.append(box("WellDark", (-0.0185, TOWER_Y[0] - 0.003, WELL_Z[1] - 0.008), (0.0185, TOWER_Y[1] + 0.004, WELL_Z[1] - 0.006), m["dark"]))
    if ROUND >= 2:
        paddle = box("Release", (-0.010, WELL_Y[0] - 0.012, WELL_Z[0] - 0.004), (0.010, WELL_Y[0] - 0.002, WELL_Z[0] + 0.014), m["blued"], bevel=0.0015)
        rotate(paddle, math.radians(16.0), "X", Vector((0, WELL_Y[0] - 0.006, WELL_Z[0] + 0.014)))
        body.append(paddle)
    # --- the stock: fixed polymer, a rubber pad at its end
    stock = slab("Stock", fillet([(RECEIVER_Y[0] + 0.004, 0.150, 0.0), (-0.140, 0.146, 0.02), (STOCK_BACK + 0.012, 0.138, 0.01), (STOCK_BACK + 0.012, -0.028, 0.01),
                                  (-0.205, 0.012, 0.03), (-0.120, 0.060, 0.03), (RECEIVER_Y[0] + 0.004, 0.066, 0.0)], 8), -0.0215, 0.0215, m["polymer"])
    if ROUND >= 2:
        # The hollow under the comb, where the off hand can hold it, as on the G3.
        cut(stock, slab("hollow", fillet([(-0.230, 0.060, 0.012), (-0.150, 0.088, 0.012), (-0.150, 0.110, 0.012), (-0.255, 0.110, 0.012)], 6), -0.0235, -0.0175, m["polymer"]))
        cut(stock, slab("hollow", fillet([(-0.230, 0.060, 0.012), (-0.150, 0.088, 0.012), (-0.150, 0.110, 0.012), (-0.255, 0.110, 0.012)], 6), 0.0175, 0.0235, m["polymer"]))
    bevel_object(stock, 0.0045, 3, 30.0)
    smooth(stock, 38)
    body.append(stock)
    pad = slab("ButtPad", fillet([(STOCK_BACK + 0.013, 0.139, 0.008), (STOCK_BACK, 0.139, 0.008), (STOCK_BACK, -0.029, 0.008), (STOCK_BACK + 0.013, -0.029, 0.008)], 5),
               -0.0225, 0.0225, m["rubber"])
    if ROUND >= 3:
        for k in range(10):
            z = -0.016 + k * 0.0145
            cut(pad, box("pr", (-0.04, STOCK_BACK - 0.01, z - 0.0018), (0.04, STOCK_BACK + 0.0025, z + 0.0018), m["rubber"]))
    bevel_object(pad, 0.003, 2, 30.0)
    smooth(pad, 35)
    body.append(pad)
    # --- the barrel, the cocking tube, the handguard
    body.append(axis_cyl("Barrel", RECEIVER_Y[1], MUZZLE_Y - 0.04, 0.0092, m["blued"], seg))
    tube = axis_cyl("CockingTube", TUBE_Y[0], TUBE_Y[1], TUBE_R, m["blued"], seg, bevel=0.0015, at=(0.0, TUBE_Z))
    if ROUND >= 2:
        # The slot the handle runs in, on the left.
        cut(tube, box("slot", (-0.02, 0.330, TUBE_Z - 0.003), (-0.005, HANDLE.y + 0.006, TUBE_Z + 0.003), m["blued"]))
    smooth(tube, 35)
    body.append(tube)
    if ROUND >= 2:
        body.append(box("SlotDark", (-0.0105, 0.331, TUBE_Z - 0.0026), (-0.0085, HANDLE.y + 0.005, TUBE_Z + 0.0026), m["dark"]))
    stem = cylinder("HandleStem", (-0.006, HANDLE.y, TUBE_Z), (HANDLE.x - 0.002, HANDLE.y, HANDLE.z), 0.0036, m["blued"], 16)
    body.append(stem)
    knob = cylinder("HandleKnob", (HANDLE.x + 0.004, HANDLE.y, HANDLE.z), (HANDLE.x - 0.008, HANDLE.y, HANDLE.z - 0.002), 0.0062, m["blued"], 20, bevel=0.0015)
    body.append(knob)
    gsec2 = rounded_rect(-GUARD_W, GUARD_W, GUARD_Z[0], GUARD_Z[1], 0.012, 0.018, 8)
    hg = prism("Handguard", gsec2, GUARD_Y[0], GUARD_Y[1], m["polymer"])
    if ROUND >= 2:
        # Vents along both sides: the barrel shows dark through them.
        cutters = []
        for side in (-1.0, 1.0):
            for k in range(7):
                y = GUARD_Y[0] + 0.030 + k * 0.026
                cutters.append(box("vent", (side * GUARD_W - 0.012, y, 0.086), (side * GUARD_W + 0.01, y + 0.013, 0.106), m["polymer"], bevel=0.003))
        cut(hg, join(cutters, "vents"))
        # Grooves round the front and back end.
        for y in (GUARD_Y[0] + 0.012, GUARD_Y[1] - 0.016):
            cut(hg, annulus("groove", (0.0, (GUARD_Z[0] + GUARD_Z[1]) * 0.5), y, y + 0.003, 0.05, GUARD_W - 0.0012, m["polymer"], 32))
    bevel_object(hg, 0.002, 2, 35.0)
    smooth(hg, 38)
    body.append(hg)
    if ROUND >= 2:
        # The handguard's inside: dark, so the vents read as holes.
        inner = prism("GuardInside", rounded_rect(-GUARD_W + 0.004, GUARD_W - 0.004, GUARD_Z[0] + 0.004, GUARD_Z[1] - 0.004, 0.01, 0.014, 6), GUARD_Y[0] + 0.004, GUARD_Y[1] - 0.004, m["dark"])
        for p in inner.data.polygons:
            p.flip()
        body.append(inner)
    if ROUND >= 3:
        # Its pin, and the ribs under it where the hand lies.
        for side in (-1.0, 1.0):
            body.append(cylinder("GuardPin", (side * (GUARD_W - 0.001), GUARD_Y[0] + 0.006, 0.112), (side * (GUARD_W + 0.0012), GUARD_Y[0] + 0.006, 0.112), 0.0025, m["blued"], 12))
        for k in range(8):
            y = 0.352 + k * 0.016
            body.append(box("GuardRib", (-0.016, y, GUARD_Z[0] - 0.0015), (0.016, y + 0.005, GUARD_Z[0] + 0.002), m["polymer"], bevel=0.0012))
    # --- the front sight: a block clamped round barrel and tube, the post in its hood
    fs = box("FrontBlock", (-0.0105, FRONT_Y - 0.018, BORE_Z - 0.006), (0.0105, FRONT_Y + 0.016, TUBE_Z + 0.004), m["steel"], bevel=0.003)
    smooth(fs, 35)
    body.append(fs)
    body.append(axis_cyl("FrontRing", FRONT_Y - 0.018, FRONT_Y + 0.016, 0.0145, m["steel"], seg, bevel=0.0015))
    body.append(axis_cyl("TubeCap", TUBE_Y[1] - 0.002, TUBE_Y[1] + 0.006, TUBE_R - 0.002, m["blued"], seg, bevel=0.0015, at=(0.0, TUBE_Z)))
    base = box("PostBase", (-0.0065, FRONT_Y - 0.012, TUBE_Z + 0.006), (0.0065, FRONT_Y + 0.010, HOOD_Z - 0.010), m["steel"], bevel=0.0018)
    body.append(base)
    post = box("Post", (-0.0013, FRONT_Y - 0.0015, HOOD_Z - 0.012), (0.0013, FRONT_Y + 0.0015, POST_TIP), m["blued"], bevel=0.0004)
    body.append(post)
    hood = annulus("Hood", (0.0, HOOD_Z), FRONT_Y - 0.012, FRONT_Y + 0.010, 0.0158, 0.0128, m["steel"], 40, math.radians(-25.0), math.radians(205.0))
    bevel_object(hood, 0.0008, 2, 35.0)
    smooth(hood, 35)
    body.append(hood)
    for side in (-1.0, 1.0):
        body.append(box("HoodFoot", (side * 0.0143 - 0.0018, FRONT_Y - 0.012, HOOD_Z - 0.012), (side * 0.0143 + 0.0018, FRONT_Y + 0.010, HOOD_Z - 0.004), m["steel"], bevel=0.0006))
    body.append(box("HoodWeb", (-0.0161, FRONT_Y - 0.012, HOOD_Z - 0.014), (0.0161, FRONT_Y + 0.010, HOOD_Z - 0.010), m["steel"], bevel=0.0008))
    # --- the flash hider: a birdcage
    hider = axis_cyl("Hider", MUZZLE_Y - 0.054, MUZZLE_Y, HIDER_R, m["blued"], seg, bevel=0.0015)
    cut(hider, axis_cyl("bore", MUZZLE_Y - 0.040, MUZZLE_Y + 0.01, HIDER_R - 0.0035, m["blued"], seg))
    if ROUND >= 2:
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            s = box("slot", (-0.0022, MUZZLE_Y - 0.036, 0.0), (0.0022, MUZZLE_Y - 0.008, 0.03), m["blued"], bevel=0.0008)
            s.data.transform(Matrix.Translation((0, 0, BORE_Z)) @ Matrix.Rotation(a, 4, "Y"))
            cut(hider, s)
    smooth(hider, 35)
    body.append(hider)
    body.append(axis_cyl("HiderDark", MUZZLE_Y - 0.040, MUZZLE_Y - 0.039, HIDER_R - 0.0034, m["dark"], 24))
    body.append(axis_cyl("Muzzle", MUZZLE_Y - 0.042, MUZZLE_Y - 0.030, 0.0062, m["blued"], 20))
    body.append(axis_cyl("Bore", MUZZLE_Y - 0.0302, MUZZLE_Y - 0.0298, 0.0038, m["dark"], 16))
    # --- the rear sight: ears either side of a plate with a U notch
    rs = box("RearBase", (-0.0145, REAR_Y - 0.016, RECEIVER_Z[1] - 0.003), (0.0145, REAR_Y + 0.016, RECEIVER_Z[1] + 0.008), m["steel"], bevel=0.0018)
    smooth(rs, 35)
    body.append(rs)
    plate = box("RearPlate", (-0.0085, REAR_Y - 0.0025, RECEIVER_Z[1] + 0.006), (0.0085, REAR_Y + 0.0025, NOTCH + 0.0075), m["blued"], bevel=0.0006)
    cut(plate, box("notch", (-0.0018, REAR_Y - 0.01, NOTCH), (0.0018, REAR_Y + 0.01, NOTCH + 0.02), m["blued"]))
    cut(plate, cylinder("notchround", (0.0, REAR_Y - 0.01, NOTCH), (0.0, REAR_Y + 0.01, NOTCH), 0.0018, m["blued"], 16))
    body.append(plate)
    for side in (-1.0, 1.0):
        ear = box("RearEar", (side * 0.0125 - 0.0025, REAR_Y - 0.012, RECEIVER_Z[1] + 0.006), (side * 0.0125 + 0.0025, REAR_Y + 0.012, NOTCH + 0.0085), m["steel"], bevel=0.0012)
        smooth(ear, 35)
        body.append(ear)
    if ROUND >= 3:
        # A white dot under the notch, for dusk.
        body.append(cylinder("Dot", (0.0, REAR_Y - 0.0027, NOTCH - 0.0042), (0.0, REAR_Y - 0.0024, NOTCH - 0.0042), 0.0011, m["white"], 12))
    # --- the selector on the left, the pins, the sling loops and the markings
    if ROUND >= 2:
        sel = box("Selector", (-RECEIVER_W - 0.0035, -0.020, 0.044), (-RECEIVER_W - 0.0005, 0.002, 0.052), m["blued"], bevel=0.0012)
        rotate(sel, math.radians(-30.0), "X", Vector((0, -0.006, 0.048)))
        body.append(sel)
        body.append(cylinder("SelectorHub", (-RECEIVER_W - 0.004, -0.006, 0.048), (-RECEIVER_W + 0.001, -0.006, 0.048), 0.0058, m["blued"], 20, bevel=0.0008))
        for y, z in ((-0.050, 0.048), (0.072, 0.050), (0.100, 0.046), (RECEIVER_Y[1] - 0.012, 0.100)):
            for side in (-1.0, 1.0):
                w = RECEIVER_W + (0.002 if z > 0.09 else 0.0)
                body.append(cylinder("Pin", (side * (w - 0.0008), y, z), (side * (w + 0.0012), y, z), 0.0028, m["blued"], 14))
        loop = annulus("SlingLoop", (0.0, -0.012), STOCK_BACK + 0.055, STOCK_BACK + 0.061, 0.009, 0.006, m["blued"], 20)
        body.append(loop)
    if ROUND >= 3:
        for side in (-1.0, 1.0):
            # Weld spots along the bottom edge of the receiver.
            for k in range(6):
                y = -0.050 + k * 0.058
                body.append(cylinder("Weld", (side * (RECEIVER_W - 0.0006), y, 0.069), (side * (RECEIVER_W + 0.0004), y, 0.069), 0.0022, m["steel"], 12))
        # S - E - F on the left (safe, single, burst-free automatic), white and red.
        for k, (letter, mat) in enumerate((("S", m["white"]), ("E", m["white"]), ("F", m["red"]))):
            a = math.radians(-50.0 + 50.0 * k)
            at = Vector((-RECEIVER_W - 0.0002, -0.006 + math.cos(a) * 0.0115 * -1.0, 0.048 + math.sin(a) * 0.0115 + 0.006))
            body.append(engrave_left(letter, at, 0.0042, mat, centre=True))
        body.append(engrave_left("M21E", Vector((-RECEIVER_W - 0.0002, 0.255, 0.097)), 0.0085, m["white"]))
        body.append(engrave_left("Kal. 7,62x51  NW 21-0388", Vector((-RECEIVER_W - 0.0002, 0.255, 0.087)), 0.0036, m["white"]))
    # --- the drum
    c = DRUM_C
    shell = axis_cyl("DrumShell", DRUM_Y[0] + 0.002, DRUM_Y[1] - 0.002, DRUM_R - 0.002, m["drum"], 64 if ROUND >= 2 else 40, bevel=0.002, at=(0.0, c.z))
    smooth(shell, 35)
    drum.append(shell)
    if ROUND >= 2:
        # Rolled rims at both faces, a raised band round the middle.
        for y0, y1 in ((DRUM_Y[0], DRUM_Y[0] + 0.007), (DRUM_Y[1] - 0.007, DRUM_Y[1])):
            rim = annulus("DrumRim", (0.0, c.z), y0, y1, DRUM_R, DRUM_R - 0.006, m["drum"], 64)
            bevel_object(rim, 0.0018, 2, 35.0)
            smooth(rim, 35)
            drum.append(rim)
        band = annulus("DrumBand", (0.0, c.z), c.y - 0.006, c.y + 0.006, DRUM_R - 0.0005, DRUM_R - 0.006, m["drum"], 64)
        bevel_object(band, 0.0012, 2, 35.0)
        smooth(band, 35)
        drum.append(band)
        # The front cover: domed a little, a hub in its middle, ribs pressed into it.
        cover = cylinder("FrontCover", (0.0, DRUM_Y[1] - 0.002, c.z), (0.0, DRUM_Y[1] + 0.004, c.z), DRUM_R - 0.012, m["drum"], 64, bevel=0.003)
        smooth(cover, 35)
        drum.append(cover)
        drum.append(cylinder("Hub", (0.0, DRUM_Y[1] + 0.003, c.z), (0.0, DRUM_Y[1] + 0.009, c.z), 0.016, m["drum"], 32, bevel=0.002))
        if ROUND >= 3:
            for k in range(8):
                a = math.tau * k / 8
                rib = box("CoverRib", (-0.0025, DRUM_Y[1] + 0.003, 0.022), (0.0025, DRUM_Y[1] + 0.0052, DRUM_R - 0.018), m["drum"], bevel=0.0009)
                rib.data.transform(Matrix.Translation((0, 0, c.z)) @ Matrix.Rotation(a, 4, "Y"))
                drum.append(rib)
            drum.append(cylinder("HubScrew", (0.0, DRUM_Y[1] + 0.0085, c.z), (0.0, DRUM_Y[1] + 0.0105, c.z), 0.007, m["blued"], 6, bevel=0.0008))
    # The back face, at the shooter: a plate, the winding key on its boss.
    back = cylinder("BackPlate", (0.0, DRUM_Y[0] - 0.003, c.z), (0.0, DRUM_Y[0] + 0.002, c.z), DRUM_R - 0.010, m["drum"], 64 if ROUND >= 2 else 40, bevel=0.0018)
    smooth(back, 35)
    drum.append(back)
    drum.append(cylinder("KeyBoss", (0.0, DRUM_Y[0] - 0.012, c.z), (0.0, DRUM_Y[0] - 0.002, c.z), 0.012, m["blued"], 32, bevel=0.0015))
    key = box("KeyWings", (-0.030, DRUM_Y[0] - 0.016, c.z - 0.0065), (0.030, DRUM_Y[0] - 0.008, c.z + 0.0065), m["blued"], bevel=0.003, segments=3)
    if ROUND >= 2:
        # The wings narrow to the boss and round off at the tips.
        for side in (-1.0, 1.0):
            cut(key, cylinder("waist", (side * 0.017, DRUM_Y[0] - 0.03, c.z + 0.0155), (side * 0.017, DRUM_Y[0], c.z + 0.0155), 0.011, m["blued"], 24))
            cut(key, cylinder("waist", (side * 0.017, DRUM_Y[0] - 0.03, c.z - 0.0155), (side * 0.017, DRUM_Y[0], c.z - 0.0155), 0.011, m["blued"], 24))
    smooth(key, 35)
    drum.append(key)
    if ROUND >= 2:
        # The latch strap across the back face from the tower down, and the spring's arrow.
        drum.append(box("Strap", (-0.006, DRUM_Y[0] - 0.006, c.z + 0.016), (0.006, DRUM_Y[0] - 0.001, c.z + DRUM_R - 0.004), m["drum"], bevel=0.0012))
    if ROUND >= 3:
        for k in range(10):
            a = math.tau * k / 10 + 0.3
            p = Vector((math.cos(a) * (DRUM_R - 0.016), DRUM_Y[0] - 0.0032, c.z + math.sin(a) * (DRUM_R - 0.016)))
            drum.append(cylinder("Rivet", p + Vector((0, 0.001, 0)), p - Vector((0, 0.0016, 0)), 0.0022, m["drum"], 10))
        # Its count and the turn of the key, in white on the back plate.
        # (Under the key: above it the latch strap covered the words.)
        drum.append(engrave_back("<- AUFZIEHEN", Vector((0.0, DRUM_Y[0] - 0.0032, c.z - 0.026)), 0.0055, m["white"]))
        drum.append(engrave_back("75", Vector((0.0, DRUM_Y[0] - 0.0032, c.z - 0.048)), 0.012, m["white"]))
    # The feed tower: a box up from the drum's top into the well, a round at its lips.
    tower = box("Tower", (-0.0175, TOWER_Y[0], c.z + DRUM_R - 0.025), (0.0175, TOWER_Y[1], TOWER_TOP), m["drum"], bevel=0.0025)
    smooth(tower, 35)
    drum.append(tower)
    if ROUND >= 2:
        for side in (-1.0, 1.0):
            drum.append(box("Lip", (side * 0.0115 - 0.003, TOWER_Y[0] + 0.004, TOWER_TOP - 0.001), (side * 0.0115 + 0.003, TOWER_Y[1] - 0.002, TOWER_TOP + 0.003), m["blued"], bevel=0.0008))
        drum.append(cylinder("TopRound", (0.0, TOWER_Y[0] + 0.004, TOWER_TOP - 0.002), (0.0, TOWER_Y[1] - 0.004, TOWER_TOP - 0.002), 0.0058, m["brass"], 16))
        drum.append(cone("TopBullet", (0.0, TOWER_Y[1] - 0.004, TOWER_TOP - 0.002), (0.0, TOWER_Y[1] + 0.016, TOWER_TOP - 0.002), 0.0044, 0.0012, m["copper"], 16))
        # Ribs pressed in the tower's sides.
        if ROUND >= 3:
            for side in (-1.0, 1.0):
                for z in (0.000, 0.016, 0.032):
                    drum.append(box("TowerRib", (side * 0.0175 - 0.0008, TOWER_Y[0] + 0.006, z), (side * 0.0175 + 0.0008, TOWER_Y[1] - 0.006, z + 0.004), m["drum"], bevel=0.0004))
    return body, drum


def engrave_back(text, at, size, material):
    """Lettering on a face that looks back at the shooter (normal -y), read from there."""
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
    # Text x -> right (x), text y -> up (z), its face towards -y.
    turn = Matrix(((1.0, 0.0, 0.0, 0.0), (0.0, 0.0, -1.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    letters.data.transform(Matrix.Translation(at) @ turn)
    letters.data.materials.clear()
    letters.data.materials.append(material)
    return letters


# ------------------------------------------------------------------ review pictures
CENTRE = (0.0, 0.20, 0.04)
VIEWS = [
    ("schraeg", (-1.0, 1.15, 0.55), (0.0, 0.2, 0.04), 50),
    ("links", (-1.75, 0.20, 0.06), CENTRE, 60),
    ("rechts", (1.75, 0.20, 0.06), CENTRE, 60),
    ("hinten_schraeg", (-0.32, -0.55, 0.36), (0.0, 0.25, 0.08), 35),
    ("oben", (0.0, 0.2, 1.8), (0.0, 0.2, 0.0), 60),
    ("unten", (-0.6, 0.3, -1.4), (0.0, 0.2, 0.0), 55),
    ("nah_trommel", (-0.30, -0.12, -0.10), (0.0, 0.17, -0.04), 45),
    ("nah_vorn", (0.28, 0.98, 0.22), (0.0, 0.6, 0.13), 45),
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
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0, 0.2, -0.22))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor")
    floor_mat.use_nodes = True
    floor.data.materials.append(floor_mat)
    setups = {
        "studio": [("key", "AREA", (-1.3, -0.5, 1.5), CENTRE, 75.0, (1.0, 0.97, 0.92), 1.3),
                   ("fill", "AREA", (1.5, 0.7, 0.7), CENTRE, 28.0, (0.85, 0.9, 1.0), 1.5),
                   ("rim", "AREA", (0.3, 2.0, 1.2), CENTRE, 55.0, (1.0, 1.0, 1.0), 1.0)],
        "nacht": [("lamp", "POINT", (-0.7, -0.3, 0.9), CENTRE, 45.0, (1.0, 0.72, 0.45), 0.1),
                  ("cold", "AREA", (0.6, 1.5, 0.6), CENTRE, 35.0, (0.45, 0.6, 1.0), 0.6)],
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
            if setup == "nacht" and name not in ("schraeg", "links", "hinten_schraeg"):
                continue
            cam.data.lens = lens
            floor.hide_render = name in ("unten", "nah_trommel")
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


def unwrap(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.003, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


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
    body_parts, drum_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(drum_parts, "Magazine")
    parts = (body, magazine)
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if ROUND >= 4:
            weighted(o)
    if not NOBAKE:
        # Two texture sets: the gun's, and the drum's own.
        unwrap(body)
        gun_images = bake([body], "mg2")
        unwrap(magazine)
        drum_images = bake([magazine], "mg2_drum")
        for o, images, name in ((body, gun_images, "mg2"), (magazine, drum_images, "mg2_drum")):
            final = final_material(images, name)
            o.data.materials.clear()
            o.data.materials.append(final)
    place_origin(magazine, DRUM_C)
    root = link(bpy.data.objects.new("MG2", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "drum", triangles(magazine), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    # Aimed: the gun tipped up until the notch and the post are level, the eye 14 cm behind
    # the notch on that line (VIEWS["mg2"]: aim, aim_angles).
    mount = Vector((0.0, -0.085, 0.085))       # GUNS["mg2"].mount, Godot space
    tilt = math.atan((NOTCH - POST_TIP) / (FRONT_Y - REAR_Y))
    post = Vector((0.0, mount.y + POST_TIP, mount.z - FRONT_Y))
    level = post.y * math.cos(tilt) - post.z * math.sin(tilt)
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % HIDER_R, "rail %.4f" % RECEIVER_Z[1], "irons %.4f" % POST_TIP)
    print("SPEC support", godot(SUPPORT), "handle", godot(HANDLE), "magazine_foot", godot((0.0, DRUM_C.y, DRUM_C.z - DRUM_R)), "drum origin", godot(DRUM_C))
    print("SPEC aim Vector3(0, %.4f, %.4f) aim_angles %.3f" % (-level, -(0.14 + mount.z - REAR_Y), math.degrees(tilt)))
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
