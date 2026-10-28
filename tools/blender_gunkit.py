# Shared parts for the self-built handguns and the Honey Badger (blender_make_pistols.py,
# blender_make_badger.py): shapes, procedural materials, the bake into one texture set, the
# review pictures and the GLB export. The helpers come from blender_make_hornet.py.
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres. The glTF exporter turns
# this into Godot space (barrel along -Z, up +Y). Set ROUND (and GPU) before building.
import bpy, bmesh, os, math
from mathutils import Vector, Matrix

ROUND = 3
GPU = True


# ------------------------------------------------------------------ scene and shapes
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


def box(name, low, high, material, bevel=0.0, segments=2, angle=35.0):
    """A box from the corner `low` to `high`; `bevel`: the radius of its edges."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    size = Vector(high) - Vector(low)
    centre = (Vector(high) + Vector(low)) * 0.5
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=centre, verts=bm.verts)
    obj = mesh_object(name, bm, material)
    if bevel > 0.0:
        bevel_object(obj, bevel, segments, angle)
    return obj


def cylinder(name, start, end, radius, material, segments=24, bevel=0.0, radius2=None, bevel_segments=2):
    start, end = Vector(start), Vector(end)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=(end - start).length)
    axis = (end - start).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((start + end) * 0.5) @ rot, verts=bm.verts)
    obj = mesh_object(name, bm, material)
    if bevel > 0.0:
        bevel_object(obj, bevel, bevel_segments)
    return obj


def prism(name, profile, y0, y1, material):
    """A body of the cross-section `profile` ((x, z) points round it) from y0 to y1."""
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


def side_plate(name, outline, x0, x1, material):
    """A body of the side outline `outline` ((y, z) points round it, as seen from the side)
    from x0 to x1 across."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in outline]
    b = [bm.verts.new((x1, y, z)) for y, z in outline]
    n = len(outline)
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
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


def loft(name, rings, material):
    """A closed body through the rings (lists of equally many points), capped at both ends."""
    bm = bmesh.new()
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    bm.faces.new(list(reversed(verts[0])))
    bm.faces.new(verts[-1])
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((verts[k][i], verts[k][j], verts[k + 1][j], verts[k + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


def sweep(name, path, half_x, thick, material):
    """A bar of a rounded section (half_x wide each side, `thick` deep) along a path of
    (y, z) points in the gun's middle plane."""
    rings = []
    for i, (y, z) in enumerate(path):
        a = path[max(0, i - 1)]
        b = path[min(len(path) - 1, i + 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        length = math.hypot(ty, tz) or 1.0
        ny, nz = -tz / length, ty / length
        ring = []
        h = thick / 2.0
        r = min(half_x, h) * 0.45
        for px, pn in ((half_x - r, -h), (half_x, -h + r), (half_x, h - r), (half_x - r, h), (-half_x + r, h), (-half_x, h - r), (-half_x, -h + r), (-half_x + r, -h)):
            ring.append((px, y + ny * pn, z + nz * pn))
        rings.append(ring)
    return loft(name, rings, material)


def rounded_rect(cx, cy, hx, hy, r, n=6):
    """Points round a rectangle (centre, half sizes) with corners of radius r."""
    pts = []
    for qx, qy, a0 in ((1, 1, 0.0), (-1, 1, 90.0), (-1, -1, 180.0), (1, -1, 270.0)):
        ox, oy = cx + qx * (hx - r), cy + qy * (hy - r)
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((ox + r * math.cos(a), oy + r * math.sin(a)))
    return pts


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
    if solver == "EXACT":
        mod.use_self = True
    apply(obj, mod)
    bpy.data.objects.remove(cutter, do_unlink=True)


def cut_many(obj, cutters, solver="EXACT"):
    """Takes several cutters out at once (joined first: much faster than one by one)."""
    if not cutters:
        return
    cutter = join(cutters, "cutters") if len(cutters) > 1 else cutters[0]
    cut(obj, cutter, solver)


def union(obj, other):
    mod = obj.modifiers.new("Join", "BOOLEAN")
    mod.operation = "UNION"
    mod.object = other
    mod.solver = "EXACT"
    apply(obj, mod)
    bpy.data.objects.remove(other, do_unlink=True)


def rotate(obj, angle, axis, pivot):
    obj.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-Vector(pivot)))


def move(obj, offset):
    obj.data.transform(Matrix.Translation(Vector(offset)))


def mirror_x(obj):
    obj.data.transform(Matrix.Scale(-1.0, 4, (1, 0, 0)))
    obj.data.flip_normals()


def smooth(obj, angle=30.0):
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.set_sharp_from_angle(angle=math.radians(angle))
    # Flat faces stay flat after the booleans (else long thin triangles shade in streaks).
    mod = obj.modifiers.new("Weighted", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    mod.mode = "FACE_AREA"
    apply(obj, mod)


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


def engrave(text, at, size, material, side=-1.0, depth=0.0):
    """Flat lettering on a side face (side -1: the left, +1: the right), reading the way one
    sees it from that side; `at` is where its first letter begins (bottom left)."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "LEFT"
    # Tiny letters vanish in the bake: a little offset makes the strokes bolder.
    curve.offset = size * 0.03
    if depth > 0.0:
        curve.extrude = depth
    letters = link(bpy.data.objects.new("Marking", curve))
    bpy.context.view_layer.objects.active = letters
    bpy.ops.object.select_all(action="DESELECT")
    letters.select_set(True)
    bpy.ops.object.convert(target="MESH")
    letters = bpy.context.view_layer.objects.active
    if side < 0.0:
        turn = Matrix(((0.0, 0.0, -1.0, 0.0), (-1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    else:
        turn = Matrix(((0.0, 0.0, 1.0, 0.0), (1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0)))
    letters.data.transform(Matrix.Translation(at) @ turn)
    letters.data.materials.clear()
    letters.data.materials.append(material)
    return letters


# ------------------------------------------------------------------ materials (procedural, baked later)
def material(name, base, rough, metal, wear=0.0, grime=0.0, bump=0.0, bump_scale=900.0, pattern="brushed",
             worn=(0.48, 0.47, 0.45), scratches=0.0, spread=0.1, grain=None):
    """A procedural material: `base` colour with a little noise in it, edges worn bright to
    `worn`, grime in the hollows, an optional fine bump (pattern: brushed metal, stipple,
    checker of a grip panel), scratches, and for wood a grain of two colours."""
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
    colour.inputs[6].default_value = (*[c * (1.0 - spread) for c in base], 1.0)
    colour.inputs[7].default_value = (*[min(1.0, c * (1.0 + spread)) for c in base], 1.0)
    links.new(noise.outputs["Fac"], colour.inputs[0])
    out_colour = colour.outputs[2]
    if grain is not None:
        # Wood: rings along the grip, warped by a noise, between two colours.
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0, 0.25, 3.5)
        links.new(coords.outputs["Object"], mapping.inputs["Vector"])
        wave = nodes.new("ShaderNodeTexWave")
        wave.wave_type = "RINGS"
        wave.inputs["Scale"].default_value = 26.0
        wave.inputs["Distortion"].default_value = 9.0
        wave.inputs["Detail"].default_value = 3.0
        links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
        wmix = nodes.new("ShaderNodeMix")
        wmix.data_type = "RGBA"
        links.new(wave.outputs["Fac"], wmix.inputs[0])
        links.new(out_colour, wmix.inputs[6])
        wmix.inputs[7].default_value = (*grain, 1.0)
        out_colour = wmix.outputs[2]
    rough_node = nodes.new("ShaderNodeMath")
    rough_node.operation = "MULTIPLY_ADD"
    rough_node.inputs[1].default_value = 0.18
    rough_node.inputs[2].default_value = rough - 0.09
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
            if ROUND >= 3:
                bev = nodes.new("ShaderNodeBevel")
                bev.inputs["Radius"].default_value = 0.0011
                bev.samples = 8
                dot = nodes.new("ShaderNodeVectorMath")
                dot.operation = "DOT_PRODUCT"
                links.new(bev.outputs["Normal"], dot.inputs[0])
                links.new(geo.outputs["Normal"], dot.inputs[1])
                edge.inputs[1].default_value = 0.996
                edge.inputs[2].default_value = 0.92
                links.new(dot.outputs["Value"], edge.inputs[0])
            else:
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
                occ = nodes.new("ShaderNodeAmbientOcclusion")
                occ.inputs["Distance"].default_value = 0.006
                occ.samples = 16
                hollow.inputs[1].default_value = 0.9
                hollow.inputs[2].default_value = 0.45
                links.new(occ.outputs["AO"], hollow.inputs[0])
            else:
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
            gmix.inputs[7].default_value = (0.03, 0.026, 0.019, 1.0)
            out_colour = gmix.outputs[2]
            grough = nodes.new("ShaderNodeMix")
            links.new(amount.outputs[0], grough.inputs[0])
            links.new(out_rough, grough.inputs[2])
            grough.inputs[3].default_value = 0.85
            out_rough = grough.outputs[0]
    if ROUND >= 3 and scratches > 0.0:
        # Scratches: thin streaks mostly along the gun, a few across, sparse.
        lines = []
        for turn, stretch, level in ((0.0, 0.11, 0.73), (0.7, 0.16, 0.75), (-1.1, 0.16, 0.76)):
            rot = nodes.new("ShaderNodeMapping")
            rot.inputs["Rotation"].default_value = (turn, 0.0, turn * 0.6)
            rot.inputs["Scale"].default_value = (1.0, stretch, 1.0)
            links.new(coords.outputs["Object"], rot.inputs["Vector"])
            streak = nodes.new("ShaderNodeTexNoise")
            streak.inputs["Scale"].default_value = 420.0
            streak.inputs["Detail"].default_value = 2.0
            links.new(rot.outputs["Vector"], streak.inputs["Vector"])
            thin = nodes.new("ShaderNodeMapRange")
            thin.inputs[1].default_value = level
            thin.inputs[2].default_value = level + 0.012
            links.new(streak.outputs["Fac"], thin.inputs[0])
            lines.append(thin.outputs[0])
        total = lines[0]
        for other in lines[1:]:
            add = nodes.new("ShaderNodeMath")
            add.operation = "MAXIMUM"
            links.new(total, add.inputs[0])
            links.new(other, add.inputs[1])
            total = add.outputs[0]
        sparse = nodes.new("ShaderNodeTexNoise")
        sparse.inputs["Scale"].default_value = 24.0
        links.new(coords.outputs["Object"], sparse.inputs["Vector"])
        where = nodes.new("ShaderNodeMapRange")
        where.inputs[1].default_value = 0.45
        where.inputs[2].default_value = 0.6
        links.new(sparse.outputs["Fac"], where.inputs[0])
        amount4 = nodes.new("ShaderNodeMath")
        amount4.operation = "MULTIPLY"
        links.new(total, amount4.inputs[0])
        links.new(where.outputs[0], amount4.inputs[1])
        amount5 = nodes.new("ShaderNodeMath")
        amount5.operation = "MULTIPLY"
        amount5.inputs[1].default_value = scratches
        links.new(amount4.outputs[0], amount5.inputs[0])
        smix = nodes.new("ShaderNodeMix")
        smix.data_type = "RGBA"
        links.new(amount5.outputs[0], smix.inputs[0])
        links.new(out_colour, smix.inputs[6])
        smix.inputs[7].default_value = (*worn, 1.0)
        out_colour = smix.outputs[2]
        sr = nodes.new("ShaderNodeMix")
        links.new(amount5.outputs[0], sr.inputs[0])
        links.new(out_rough, sr.inputs[2])
        sr.inputs[3].default_value = 0.3
        out_rough = sr.outputs[0]
    links.new(out_colour, bsdf.inputs["Base Color"])
    links.new(out_rough, bsdf.inputs["Roughness"])
    links.new(out_metal, bsdf.inputs["Metallic"])
    mat["metal_socket"] = out_metal.node.name + ":" + str(list(out_metal.node.outputs).index(out_metal))
    mat["colour_socket"] = out_colour.node.name + ":" + str(list(out_colour.node.outputs).index(out_colour))
    if bump > 0.0:
        bump_node = nodes.new("ShaderNodeBump")
        bump_node.inputs["Strength"].default_value = bump
        bump_node.inputs["Distance"].default_value = 0.0004 if ROUND < 3 else 0.0009
        if pattern == "stipple":
            cells = nodes.new("ShaderNodeTexVoronoi")
            cells.inputs["Scale"].default_value = bump_scale
            cells.feature = "DISTANCE_TO_EDGE"
            links.new(coords.outputs["Object"], cells.inputs["Vector"])
            links.new(cells.outputs["Distance"], bump_node.inputs["Height"])
        elif pattern == "checker":
            # Checkering: two sets of grooves crossing at right angles, diagonal on the side.
            prod = None
            for turn in (math.radians(45.0), math.radians(-45.0)):
                rot = nodes.new("ShaderNodeMapping")
                rot.inputs["Rotation"].default_value = (turn, 0.0, 0.0)
                links.new(coords.outputs["Object"], rot.inputs["Vector"])
                wave = nodes.new("ShaderNodeTexWave")
                wave.wave_type = "BANDS"
                wave.bands_direction = "Z"
                wave.wave_profile = "TRI"
                wave.inputs["Scale"].default_value = bump_scale
                links.new(rot.outputs["Vector"], wave.inputs["Vector"])
                if prod is None:
                    prod = wave.outputs["Fac"]
                else:
                    mul = nodes.new("ShaderNodeMath")
                    mul.operation = "MINIMUM"
                    links.new(prod, mul.inputs[0])
                    links.new(wave.outputs["Fac"], mul.inputs[1])
                    prod = mul.outputs[0]
            links.new(prod, bump_node.inputs["Height"])
        else:
            mapping = nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (1.0, 0.02, 1.0)
            links.new(coords.outputs["Object"], mapping.inputs["Vector"])
            lines = nodes.new("ShaderNodeTexNoise")
            lines.inputs["Scale"].default_value = bump_scale
            links.new(mapping.outputs["Vector"], lines.inputs["Vector"])
            links.new(lines.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# ------------------------------------------------------------------ bake, material, export
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


def unwrap(parts, margin=0.003):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=margin, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(objs, prefix, tex):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    use_gpu(scene)
    scene.cycles.samples = 12
    scene.render.bake.margin = 6
    images = {}
    for key, colour_space in (("base", "sRGB"), ("rough", "Non-Color"), ("metal", "Non-Color"), ("normal", "Non-Color")):
        img = bpy.data.images.new(prefix + "_" + key, tex, tex, alpha=False, float_buffer=False)
        img.colorspace_settings.name = colour_space
        images[key] = img
    mats = set()
    for o in objs:
        for slot in o.material_slots:
            if slot.material is not None:
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
    images["orm"] = bpy.data.images.new(prefix + "_orm", tex, tex, alpha=False)
    images["orm"].colorspace_settings.name = "Non-Color"
    images["orm"].pixels = orm.tolist()
    return images


def final_material(images, name):
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


def finish(parts, root_name, prefix, tex, nobake, fallback):
    """Applies the transforms, bakes all parts into one texture set (unless nobake) and hangs
    them under an empty named root_name. `fallback`: the material for empty slots."""
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for slot in o.material_slots:
            if slot.material is None:
                slot.material = fallback
    if not nobake:
        unwrap(parts)
        # Parts are baked apart from each other, so that faces lying against each other
        # do not shade each other.
        for i, o in enumerate(parts[1:], 1):
            o.location.x += 0.3 * i
        images = bake(parts, prefix, tex)
        for i, o in enumerate(parts[1:], 1):
            o.location.x -= 0.3 * i
        final = final_material(images, prefix)
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    root = link(bpy.data.objects.new(root_name, None))
    for o in parts:
        o.parent = root
    return root


def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_image_quality=90)
    print("EXPORTED", path, os.path.getsize(path), "bytes")


# ------------------------------------------------------------------ review pictures
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


def render_views(folder, prefix, centre, scale, floor_z, only=None, samples=48):
    """Fixed views round `centre`; `scale`: distance of the camera (about the gun's length
    times 2.5)."""
    os.makedirs(folder, exist_ok=True)
    cx, cy, cz = centre
    s = scale
    views = [
        ("schraeg", (cx - 0.62 * s, cy + 0.62 * s, cz + 0.36 * s), (cx, cy, cz), 50),
        ("links", (cx - 1.0 * s, cy, cz + 0.02 * s), (cx, cy, cz), 55),
        ("rechts", (cx + 1.0 * s, cy, cz + 0.02 * s), (cx, cy, cz), 55),
        ("hinten", (cx + 0.38 * s, cy - 0.62 * s, cz + 0.42 * s), (cx, cy, cz + 0.01), 50),
        ("oben", (cx, cy, cz + 1.1 * s), (cx, cy, cz), 55),
        ("nah", (cx - 0.3 * s, cy + 0.22 * s, cz + 0.2 * s), (cx, cy + 0.05 * s, cz + 0.06 * s), 50),
    ]
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    use_gpu(scene)
    scene.cycles.samples = samples
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
    cam.data.clip_start = 0.005
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(cx, cy, floor_z))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor")
    floor_mat.use_nodes = True
    floor.data.materials.append(floor_mat)
    c = Vector(centre)
    setups = {
        "studio": [("key", "AREA", c + Vector((-0.9, -0.5, 1.1)) * s, centre, 30.0 * s * s, (1.0, 0.97, 0.92), 1.0 * s),
                   ("fill", "AREA", c + Vector((1.0, 0.4, 0.5)) * s, centre, 10.0 * s * s, (0.85, 0.9, 1.0), 1.2 * s),
                   ("rim", "AREA", c + Vector((0.2, 1.2, 0.8)) * s, centre, 24.0 * s * s, (1.0, 1.0, 1.0), 0.7 * s)],
        "nacht": [("lamp", "POINT", c + Vector((-0.5, -0.25, 0.7)) * s, centre, 22.0 * s * s, (1.0, 0.72, 0.45), 0.1),
                  ("cold", "AREA", c + Vector((0.4, 1.0, 0.4)) * s, centre, 16.0 * s * s, (0.45, 0.6, 1.0), 0.5 * s)],
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
        for name, pos, target, lens in views:
            if only and name not in only:
                continue
            if setup == "nacht" and name != "schraeg":
                continue
            cam.data.lens = lens
            look_from(cam, pos, target)
            scene.render.filepath = os.path.join(folder, "%s_%s_%s.png" % (prefix, name, setup))
            bpy.ops.render.render(write_still=True)
        for obj in made:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(floor, do_unlink=True)
    print("RENDERED", folder, prefix)
