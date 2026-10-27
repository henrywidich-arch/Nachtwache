# Builds the UMP45 for Nachtwache, from nothing (it replaces the supplied mesh ump.glb, which
# stays in the folder unused): the .45 submachine gun with its black polymer receiver. The
# receiver one moulded box with the steel Picatinny rail on top, the large ejection port on
# the right, the cocking handle at the front left in its slot, short rails on both sides of
# the fore-end; the trigger housing below with the ergonomic grip and the big trigger guard,
# the ambidextrous selector with its pictograms and the paddle release behind the magazine;
# the skeleton stock that folds to the right; the rotary rear sight and the hooded front post;
# the straight 25-round magazine of smoky, translucent polymer with its rounds inside.
# Every part is made here, bevelled, given its material, UV-unwrapped and baked into one
# texture set (base colour, roughness and metal, normal); the magazine's shell keeps a
# material of its own that lets the light through. Written as a GLB with the nodes
#   UMP > Body / Magazine (origin: the middle of its top; the translucent "Shell" under it) /
#         Trigger (origin at its pivot)
#
#   blender --background --factory-startup --python tools/blender_make_ump.py -- [--round 4] [--tex 2048]
#           [--out assets/models/ump_built.glb] [--render <folder> --prefix ump_r1] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
# --render: fixed views (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the pistol grip. The glTF exporter turns this into Godot space (barrel along -Z, up +Y).
# The places the game needs (GUNS["ump"] in weapon_view.gd) are printed.
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
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "ump_built.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "ump_r%d" % ROUND)
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


def cut_many(obj, cutters, solver="EXACT"):
    """Cuts all `cutters` out of obj in one go (they are joined into one cutter first: one
    boolean instead of dozens)."""
    if not cutters:
        return
    cutter = cutters[0] if len(cutters) == 1 else join(cutters, "cutters")
    mod = obj.modifiers.new("Cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = solver
    # (The joined cutters may overlap one another: the exact solver must be told, or it can
    # lose the whole part.)
    mod.use_self = True
    apply(obj, mod)
    bpy.data.objects.remove(cutter, do_unlink=True)


def rail(name, y0, y1, z_top, mat, slots=True, pitch=0.010, height=0.0095, width=0.0212):
    """A Picatinny rail along y on a top face: the narrow neck, the dovetail flaring out to
    21.2 mm, chamfered on top, a cross slot every centimetre (5.2 mm wide, 3 mm deep).
    Returns the rail and the middles of its teeth (the flats between the slots)."""
    w = width / 2.0
    prof = [(-0.0078, z_top - height), (0.0078, z_top - height), (0.0078, z_top - 0.0058), (w, z_top - 0.0036), (w, z_top - 0.0016),
            (w - 0.0016, z_top), (-w + 0.0016, z_top), (-w, z_top - 0.0016), (-w, z_top - 0.0036), (-0.0078, z_top - 0.0058)]
    r = prism(name, prof, y0, y1, mat)
    teeth = []
    if slots:
        n = int((y1 - y0 - 0.004) / pitch)
        start = y0 + (y1 - y0 - n * pitch) * 0.5 + pitch * 0.5
        cutters = []
        for i in range(n):
            y = start + i * pitch - 0.0026
            cutters.append(box("slot", (-0.03, y, z_top - 0.0030), (0.03, y + 0.0052, z_top + 0.01), mat))
            if i < n - 1:
                teeth.append(start + i * pitch + pitch * 0.5)
        cut_many(r, cutters)
    if ROUND >= 2:
        bevel_object(r, 0.0004, 1, 30.0)
    smooth(r, 30)
    return r, teeth


def turn_about_y(obj, angle, centre):
    """Turns a part built on top of an axis (along y through `centre`, (x, z)) round that axis."""
    cx, cz = centre
    obj.data.transform(Matrix.Translation((cx, 0, cz)) @ Matrix.Rotation(angle, 4, "Y") @ Matrix.Translation((-cx, 0, -cz)))


def loft(name, sections, material, cap=True):
    """A skin through `sections` (lists of 3D points, all of the same length, in order)."""
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in sec] for sec in sections]
    n = len(sections[0])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


def oval(front, back, half_width, n=28, power=2.6):
    """A rounded cross-section (x, d): `front` and `back` how far it reaches before and behind
    its middle, `half_width` to the sides; a superellipse, squarer the higher `power`."""
    pts = []
    for i in range(n):
        a = math.tau * i / n
        c, s = math.cos(a), math.sin(a)
        d = (front if c > 0 else back) * math.copysign(abs(c) ** (2.0 / power), c)
        x = half_width * math.copysign(abs(s) ** (2.0 / power), s)
        pts.append((x, d))
    return pts


def frame(origin, down_angle):
    """The matrix of a cross-section of a part that hangs down from `origin` ((y, z)), leaning
    forward by down_angle (radians): local x stays x, local d (the second) points to the
    front of the section, local s (the third) runs back up the part's axis."""
    fwd = Vector((0.0, math.cos(down_angle), math.sin(down_angle)))
    up = Vector((0.0, -math.sin(down_angle), math.cos(down_angle)))
    m = Matrix(((1.0, 0.0, 0.0, 0.0), (0.0, fwd.y, up.y, origin[0]), (0.0, fwd.z, up.z, origin[1]), (0.0, 0.0, 0.0, 1.0)))
    return m


def engrave_right(text, at, size, material):
    """Flat lettering on the right face, reading from the stock forwards as one sees it from
    the right; 'at' is where its first letter begins."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.extrude = 0.00012
    # (A little bolder than the font: the thin strokes of small letters fell between the
    # texels of the baked texture.)
    curve.offset = size * 0.03
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
    # (A little bolder than the font: the thin strokes of small letters fell between the
    # texels of the baked texture.)
    curve.offset = size * 0.03
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
    # (A little bolder than the font: the thin strokes of small letters fell between the
    # texels of the baked texture.)
    curve.offset = size * 0.03
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
    """The magazine's shell: smoky, translucent polymer, a little glossy, so that the rounds
    inside can be seen. Not baked: it keeps this plain material (alpha blended in the game)."""
    mat = bpy.data.materials.new("ump_magazine_shell")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tint = (0.075, 0.075, 0.08)
    alpha = 0.6 if ROUND < 4 else 0.66
    bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Alpha"].default_value = alpha
    try:
        mat.surface_render_method = "BLENDED"
    except Exception:
        mat.blend_method = "BLEND"
    mat.use_backface_culling = False
    mat.diffuse_color = (*tint, alpha)
    return mat


def make_materials():
    wear = {1: 0.0, 2: 0.4, 3: 0.7}.get(ROUND, 0.6)
    g = 0.7 if ROUND >= 2 else 0.0
    # The receiver: black polymer with a fine moulded grain, matt; rubbed a little lighter
    # where hands and kit wear it.
    polymer = material("polymer", (0.027, 0.028, 0.03), 0.7, 0.0, wear=0.35 * wear, grime=g, bump=0.06 if ROUND >= 3 else 0.0, bump_scale=2600.0, stipple=True, worn=(0.085, 0.088, 0.092))
    grip = material("grip", (0.029, 0.03, 0.032), 0.84, 0.0, wear=0.25 * wear, grime=g, bump=0.0 if ROUND < 3 else 0.85, bump_scale=2200.0, stipple=True, worn=(0.085, 0.088, 0.092)) if ROUND >= 2 else polymer
    steel = material("steel", (0.04, 0.041, 0.044), 0.5, 0.7, wear=0.6 * wear, grime=g, worn=(0.32, 0.32, 0.33))
    dark = material("dark", (0.006, 0.006, 0.007), 0.85, 0.0)
    rubber = material("rubber", (0.02, 0.02, 0.021), 0.9, 0.0, grime=0.4 if ROUND >= 2 else 0.0, bump=0.0 if ROUND < 3 else 0.5, bump_scale=900.0, stipple=True)
    brass = material("brass", (0.66, 0.49, 0.21), 0.34, 1.0, grime=0.2)
    copper = material("copper", (0.55, 0.3, 0.16), 0.34, 1.0, grime=0.2)
    magpoly = material("magpoly", (0.022, 0.022, 0.024), 0.6, 0.0, wear=0.3 * wear, grime=g, worn=(0.08, 0.08, 0.085))
    # Moulded letters: the same black, a shade lighter and smoother.
    marking = material("marking", (0.11, 0.115, 0.12), 0.5, 0.0) if ROUND >= 3 else polymer
    white = material("white", (0.62, 0.62, 0.6), 0.55, 0.0) if ROUND >= 3 else polymer
    red = material("red", (0.5, 0.05, 0.03), 0.5, 0.0) if ROUND >= 3 else polymer
    return {"polymer": polymer, "grip": grip, "steel": steel, "dark": dark, "rubber": rubber, "brass": brass, "copper": copper,
            "magpoly": magpoly, "marking": marking, "white": white, "red": red, "shell": shell_material()}


# ------------------------------------------------------------------ the measures
BORE_Z = 0.1133                 # the bore axis above the middle of the grip
RAIL_TOP = 0.1587               # the top of the rail
REC_TOP = 0.1492                # the top of the receiver under the rail
REC_W = 0.0215                  # half the receiver's width
REC_Y = (-0.064, 0.352)         # the receiver from the stock's hinge to its nose
FORE_Z = 0.084                  # the underside of the fore-end, where the left hand lies
MUZZLE_Y = 0.3864               # the face of the muzzle nut: 69 cm over all with the stock out
BUTT_Y = -0.304
MAG_TOP = 0.085                 # the top of the magazine's body, inside the well
MAG_Y = (0.1675, 0.2045)        # its back and front
MAG_W = 0.0124                  # half its width
MAG_FOOT = -0.112
WELL_Y = (0.160, 0.212)
TRIGGER_PIVOT = Vector((0.0, 0.062, 0.066))
HOUSING_W = 0.0150
SIGHT_Y = (-0.044, 0.318)       # the rear drum and the front post
IRONS = 0.1866                  # the middle of the rear aperture, level with the tip of the post
HANDLE = Vector((-0.0207, 0.2553, 0.1346))          # the cocking handle at the front left
PORT_Y = (0.098, 0.160)         # the ejection port on the right
PORT_Z = (0.1035, 0.1315)
SUPPORT = Vector((0.0, 0.29, BORE_Z))              # where the left hand holds (its baked pose)
GRIP_TILT = math.radians(-16.0)
ROUNDS = 25


def receiver_outline():
    pts = [(REC_Y[0], REC_TOP, 0.004), (0.334, REC_TOP, 0.006), (REC_Y[1], 0.128, 0.004), (REC_Y[1], 0.097, 0.005), (0.338, FORE_Z, 0.008),
           (WELL_Y[1] + 0.002, FORE_Z, 0.004), (WELL_Y[1], 0.031, 0.003), (WELL_Y[0], 0.035, 0.003), (WELL_Y[0] - 0.002, 0.068, 0.002),
           (-0.028, 0.068, 0.006), (REC_Y[0], 0.096, 0.008)]
    return fillet(pts, 6 if ROUND >= 2 else 4)


def build(m):
    body, mag, trig, shell = [], [], [], []
    # --- the receiver: one moulded box from the hinge to the nose, the magazine well under it
    rec = slab("Receiver", receiver_outline(), -REC_W, REC_W, m["polymer"])
    cutters = [box("well", (-MAG_W - 0.0008, MAG_Y[0] - 0.0006, -0.02), (MAG_W + 0.0008, MAG_Y[1] + 0.0006, MAG_TOP + 0.004), m["polymer"])]
    if ROUND >= 2:
        cutters.append(box("port", (0.010, PORT_Y[0], PORT_Z[0]), (0.04, PORT_Y[1], PORT_Z[1]), m["polymer"], bevel=0.002))
        cutters.append(box("slot", (-0.04, 0.150, HANDLE.z - 0.0036), (-REC_W + 0.006, 0.268, HANDLE.z + 0.0036), m["polymer"], bevel=0.0012))
        # The top edges taken off along the rail, the nose's upper corners at a slant.
        for side in (-1.0, 1.0):
            c = box("te", (side * REC_W - 0.006, REC_Y[0] - 0.01, REC_TOP - 0.006), (side * REC_W + 0.006, REC_Y[1] + 0.01, REC_TOP + 0.01), m["polymer"])
            rotate(c, side * math.radians(-40.0), "Y", Vector((side * REC_W, 0, REC_TOP - 0.006)))
            cutters.append(c)
            c = box("nc", (REC_W if side > 0 else -REC_W - 0.016, REC_Y[1] - 0.016, 0.05), (REC_W + 0.016 if side > 0 else -REC_W, REC_Y[1] + 0.02, 0.2), m["polymer"])
            rotate(c, side * math.radians(20.0), "Z", Vector((side * REC_W, REC_Y[1] - 0.016, 0)))
            cutters.append(c)
        # The fore-end a little slimmer than the receiver, a step down each side before the well.
        for side in (-1.0, 1.0):
            cutters.append(box("fs", (side * REC_W - 0.0012 * (side > 0) - 0.01 * (side < 0), WELL_Y[1] + 0.012, FORE_Z - 0.01),
                               (side * REC_W + 0.01 * (side > 0) + 0.0012 * (side < 0), REC_Y[1] + 0.01, 0.1255), m["polymer"], bevel=0.0012))
    if ROUND >= 3:
        # A moulded groove along each side under the rail, and the line where the receiver's
        # two halves were joined, under the port.
        for side in (-1.0, 1.0):
            cutters.append(box("g1", (side * REC_W - 0.0007, REC_Y[0] + 0.012, 0.1388), (side * REC_W + 0.0007, WELL_Y[1] + 0.004, 0.1402), m["polymer"]))
            # (Round 4: the joint higher, between the selector's pictograms and the port.)
            gz = 0.0930 if ROUND < 4 else 0.0995
            cutters.append(box("g2", (side * REC_W - 0.0006, REC_Y[0] + 0.020, gz), (side * REC_W + 0.0006, WELL_Y[0] - 0.006, gz + 0.0012), m["polymer"]))
        # Grooves across the front of the well, for the fingers that strip a magazine.
        for k in range(7):
            z = 0.040 + k * 0.0055
            cutters.append(box("wg", (-0.03, WELL_Y[1] - 0.0008, z), (0.03, WELL_Y[1] + 0.01, z + 0.0018), m["polymer"]))
    cut_many(rec, cutters)
    bevel_object(rec, 0.0028 if ROUND >= 2 else 0.003, 3, 32.0)
    smooth(rec, 35)
    if ROUND >= 3:
        # The stippled fore-end: the faces under the rails where the left hand lies.
        for poly in rec.data.polygons:
            c = poly.center
            if c.y > WELL_Y[1] + 0.012 and c.z < 0.122:
                poly.material_index = 1
        rec.data.materials.append(m["grip"])
    body.append(rec)
    if ROUND >= 2:
        # Inside the well and the port: dark. The bolt behind the port, its face and extractor.
        body.append(box("WellRoof", (-MAG_W - 0.0008, MAG_Y[0], MAG_TOP + 0.003), (MAG_W + 0.0008, MAG_Y[1], MAG_TOP + 0.005), m["dark"]))
        for side in (-1.0, 1.0):
            body.append(box("WellWall", (side * (MAG_W + 0.0005) - 0.0002, MAG_Y[0], 0.04), (side * (MAG_W + 0.0005) + 0.0002, MAG_Y[1], MAG_TOP + 0.004), m["dark"]))
        body.append(box("Action", (0.004, PORT_Y[0] + 0.001, PORT_Z[0] + 0.001), (0.0105, PORT_Y[1] - 0.001, PORT_Z[1] - 0.001), m["dark"]))
        bolt = box("Bolt", (0.005, PORT_Y[0] - 0.004, BORE_Z - 0.0085), (0.0122, PORT_Y[1] - 0.006, BORE_Z + 0.0125), m["steel"], bevel=0.0015)
        if ROUND >= 3:
            cut(bolt, box("bc", (0.010, PORT_Y[0] + 0.006, BORE_Z + 0.003), (0.02, PORT_Y[0] + 0.030, BORE_Z + 0.0085), m["steel"], bevel=0.001))
        smooth(bolt, 35)
        body.append(bolt)
        body.append(box("Extractor", (0.0108, PORT_Y[1] - 0.010, BORE_Z + 0.004), (0.0128, PORT_Y[1] - 0.002, BORE_Z + 0.009), m["steel"], bevel=0.0005))
        body.append(box("SlotInside", (-REC_W + 0.0045, 0.151, HANDLE.z - 0.0030), (-REC_W + 0.0058, 0.267, HANDLE.z + 0.0030), m["dark"]))
    # --- the steel rail on top, the rivets that hold it
    top, teeth = rail("TopRail", REC_Y[0] + 0.012, 0.302, RAIL_TOP, m["steel"], slots=ROUND >= 2)
    body.append(top)
    if ROUND >= 3:
        for y in (-0.030, 0.060, 0.150, 0.240):
            for side in (-1.0, 1.0):
                body.append(cylinder("Rivet", (side * (REC_W - 0.004), y, REC_TOP - 0.0045), (side * (REC_W - 0.0018), y, REC_TOP - 0.0045), 0.0022, m["steel"], 12))
                rotate(body[-1], side * math.radians(-40.0), "Y", Vector((side * REC_W, y, REC_TOP - 0.006)))
    # --- short rails on both sides of the fore-end
    if ROUND >= 2:
        for side in (-1.0, 1.0):
            sr, _ = rail("SideRail", 0.236, 0.336, 0.104 + REC_W + 0.006, m["steel"], height=0.0075)
            turn_about_y(sr, side * math.radians(90.0), (0.0, 0.104))
            sr.data.transform(Matrix.Translation((-side * 0.0012, 0, 0)))
            body.append(sr)
            if ROUND >= 3:
                for y in (0.246, 0.326):
                    s = cylinder("RailScrew", (side * (REC_W - 0.001), y, 0.104), (side * (REC_W + 0.0068), y, 0.104), 0.0026, m["steel"], 6)
                    body.append(s)
    # --- the barrel, its nut in the nose, the muzzle nut
    body.append(cylinder("Barrel", (0, 0.300, BORE_Z), (0, MUZZLE_Y - 0.012, BORE_Z), 0.0086, m["steel"], 28))
    body.append(cylinder("BarrelNut", (0, REC_Y[1] - 0.004, BORE_Z), (0, REC_Y[1] + 0.006, BORE_Z), 0.0128, m["steel"], 6 if ROUND >= 2 else 28, bevel=0.0008))
    nut = cylinder("MuzzleNut", (0, MUZZLE_Y - 0.020, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.0112, m["steel"], 32, bevel=0.0012)
    cutters = [cylinder("bore", (0, MUZZLE_Y - 0.01, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0062, m["steel"], 24)]
    if ROUND >= 3:
        # Knurled ring round its back half.
        for k in range(24):
            a = math.tau * k / 24
            c = box("kn", (-0.0006, MUZZLE_Y - 0.019, 0.0106), (0.0006, MUZZLE_Y - 0.011, 0.013), m["steel"])
            c.data.transform(Matrix.Translation((0, 0, BORE_Z)) @ Matrix.Rotation(a, 4, "Y"))
            cutters.append(c)
    cut_many(nut, cutters)
    smooth(nut, 35)
    body.append(nut)
    body.append(cylinder("BoreDark", (0, MUZZLE_Y - 0.012, BORE_Z), (0, MUZZLE_Y - 0.0015, BORE_Z), 0.0061, m["dark"], 20))
    # --- the cocking handle: a short lever folded forward in its slot, a mushroom knob
    arm = box("HandleArm", (-REC_W - 0.0105, HANDLE.y - 0.004, HANDLE.z - 0.0028), (-REC_W + 0.006, HANDLE.y + 0.004, HANDLE.z + 0.0028), m["steel"], bevel=0.001)
    rotate(arm, math.radians(-18.0), "Z", Vector((-REC_W + 0.004, HANDLE.y, HANDLE.z)))
    body.append(arm)
    knob = cylinder("HandleKnob", (-REC_W - 0.008, HANDLE.y + 0.006, HANDLE.z), (-REC_W - 0.016, HANDLE.y + 0.006, HANDLE.z), 0.0056, m["polymer"], 20, bevel=0.0016)
    body.append(knob)
    # --- the trigger housing: the grip's frame and the big trigger guard, under the receiver
    outer = fillet([(-0.036, 0.0705, 0.0), (0.150, 0.0705, 0.0), (0.150, 0.040, 0.008), (0.138, 0.021, 0.012), (0.040, 0.020, 0.012),
                    (0.012, 0.042, 0.01), (-0.016, 0.048, 0.008), (-0.036, 0.058, 0.006)], 6)
    housing = slab("Housing", outer, -HOUSING_W, HOUSING_W, m["polymer"])
    hole = fillet([(0.044, 0.0625, 0.004), (0.137, 0.0625, 0.006), (0.137, 0.040, 0.008), (0.128, 0.029, 0.006), (0.052, 0.029, 0.006), (0.040, 0.040, 0.006)], 6)
    cutters = [slab("hole", hole, -0.05, 0.05, m["polymer"])]
    for side in (-1.0, 1.0):
        # The guard narrower than the frame round the trigger.
        cutters.append(box("gn", (side * 0.009 - 0.02 * (side < 0), 0.038, 0.0), (side * 0.009 + 0.02 * (side > 0), 0.17, 0.058), m["polymer"], bevel=0.002))
    cut_many(housing, cutters)
    bevel_object(housing, 0.0022, 3, 32.0)
    smooth(housing, 35)
    body.append(housing)
    # --- the grip: finger grooves at the front, a swell for the palm, leaning back
    rows = [(0.054, 0.0180, 0.0200, 0.0135), (0.040, 0.0178, 0.0210, 0.0140), (0.030, 0.0172, 0.0215, 0.0145), (0.020, 0.0205, 0.0220, 0.0148),
            (0.009, 0.0172, 0.0220, 0.0150), (-0.002, 0.0205, 0.0222, 0.0150), (-0.012, 0.0172, 0.0222, 0.0150), (-0.022, 0.0200, 0.0220, 0.0148),
            (-0.033, 0.0172, 0.0215, 0.0146), (-0.045, 0.0178, 0.0210, 0.0142), (-0.054, 0.0174, 0.0198, 0.0136), (-0.059, 0.0148, 0.0168, 0.0114),
            (-0.0615, 0.0108, 0.0122, 0.0082)]
    if ROUND < 2:
        rows = [(z, 0.0185, b, w) for z, f, b, w in rows]
    sections = [[Vector((x, d, z)) for x, d in oval(f, b, w, 32, 2.6)] for z, f, b, w in rows]
    grip = loft("Grip", sections, m["grip"])
    rotate(grip, GRIP_TILT, "X", Vector((0, 0, 0)))
    smooth(grip, 45)
    body.append(grip)
    # --- the trigger
    blade = box("Blade", (-0.003, TRIGGER_PIVOT.y - 0.004, 0.044), (0.003, TRIGGER_PIVOT.y + 0.003, TRIGGER_PIVOT.z + 0.003), m["steel"], bevel=0.0012)
    trig.append(blade)
    tip = box("BladeTip", (-0.003, TRIGGER_PIVOT.y - 0.002, 0.034), (0.003, TRIGGER_PIVOT.y + 0.005, 0.047), m["steel"], bevel=0.0012)
    rotate(tip, math.radians(-16.0), "X", Vector((0, TRIGGER_PIVOT.y, 0.046)))
    trig.append(tip)
    # --- controls: the selector on both sides, the paddle release behind the magazine, pins
    # (On the receiver just above the grip, where the thumb reaches it.)
    sel = Vector((0.0, 0.004, 0.077))
    for side in (-1.0, 1.0):
        body.append(cylinder("Selector", (side * (REC_W - 0.0006), sel.y, sel.z), (side * (REC_W + 0.0022), sel.y, sel.z), 0.0062, m["polymer"], 24, bevel=0.0008))
        lever = box("SelectorLever", (side * (REC_W + 0.0012) - 0.0016, sel.y - 0.0035, sel.z - 0.002), (side * (REC_W + 0.0012) + 0.0016, sel.y + 0.0035, sel.z + 0.014), m["polymer"], bevel=0.0012)
        # Turned forward to the row of red bullets: set to fire.
        rotate(lever, math.radians(-45.0), "X", sel)
        body.append(lever)
    if ROUND >= 2:
        paddle = box("Paddle", (-0.0085, 0.1515, 0.038), (0.0085, 0.1585, 0.066), m["polymer"], bevel=0.0018)
        rotate(paddle, math.radians(-12.0), "X", Vector((0, 0.155, 0.066)))
        if ROUND >= 3:
            for k in range(4):
                cut(paddle, box("pg", (-0.02, 0.1475, 0.041 + k * 0.004), (0.02, 0.1530, 0.0425 + k * 0.004), m["polymer"]))
        smooth(paddle, 35)
        body.append(paddle)
        # The housing's two push pins, through the receiver.
        for y, z in ((-0.024, 0.0625), (0.142, 0.064)):
            for side in (-1.0, 1.0):
                body.append(cylinder("Pin", (side * (HOUSING_W - 0.0006), y, z), (side * (HOUSING_W + 0.0008), y, z), 0.0034, m["steel"], 16))
        for y, z in ((0.006, 0.086), (0.110, 0.080)):
            for side in (-1.0, 1.0):
                body.append(cylinder("Pin", (side * (REC_W - 0.0006), y, z), (side * (REC_W + 0.0008), y, z), 0.003, m["steel"], 16))
    # --- the stock: a hinge block at the back, a skeleton frame that folds to the right,
    # a rubber butt pad
    hinge = box("Hinge", (-0.019, REC_Y[0] - 0.016, 0.094), (0.019, REC_Y[0] + 0.004, 0.146), m["polymer"], bevel=0.003, segments=2)
    smooth(hinge, 35)
    body.append(hinge)
    sb = REC_Y[0] - 0.014
    outline = fillet([(sb, 0.1445, 0.003), (BUTT_Y + 0.012, 0.150, 0.008), (BUTT_Y + 0.012, 0.010, 0.008), (BUTT_Y + 0.034, 0.008, 0.012), (-0.160, 0.066, 0.03), (sb, 0.096, 0.003)], 6)
    stock = slab("Stock", outline, -0.0165, 0.0165, m["polymer"])
    if ROUND >= 2:
        inner = fillet([(sb - 0.016, 0.131, 0.006), (BUTT_Y + 0.026, 0.136, 0.01), (BUTT_Y + 0.026, 0.032, 0.01), (BUTT_Y + 0.046, 0.026, 0.012), (-0.160, 0.082, 0.02), (sb - 0.016, 0.106, 0.006)], 6)
        cutter = slab("open", inner, -0.04, 0.04, m["polymer"])
        bevel_object(cutter, 0.004, 3, 30.0)
        cut(stock, cutter)
    if ROUND >= 3:
        # The cheek rest along the top bar: a raised, rounded strip.
        for side in (-1.0, 1.0):
            cut(stock, box("cg", (side * 0.0165 - 0.001, -0.270, 0.139), (side * 0.0165 + 0.001, -0.110, 0.1405), m["polymer"]))
    bevel_object(stock, 0.003, 3, 30.0)
    smooth(stock, 35)
    body.append(stock)
    pad = box("Pad", (-0.020, BUTT_Y, 0.004), (0.020, BUTT_Y + 0.013, 0.155), m["rubber"], bevel=0.006, segments=3)
    if ROUND >= 3:
        cutters = []
        for k in range(12):
            z = 0.016 + k * 0.0115
            cutters.append(box("pr", (-0.03, BUTT_Y - 0.01, z - 0.0016), (0.03, BUTT_Y + 0.0009, z + 0.0016), m["rubber"]))
        cut_many(pad, cutters)
    smooth(pad, 35)
    body.append(pad)
    if ROUND >= 2:
        # The hinge's pin on the right (the stock folds that way), the release button on the left.
        body.append(cylinder("HingePin", (0.0195, REC_Y[0] - 0.008, 0.092), (0.0195, REC_Y[0] - 0.008, 0.148), 0.0042, m["steel"], 20, bevel=0.0008))
        body.append(cylinder("StockButton", (-0.019, REC_Y[0] - 0.006, 0.122), (-0.0225, REC_Y[0] - 0.006, 0.122), 0.0058, m["polymer"], 24, bevel=0.0012))
        # Sling loops: at the nose on the left, at the back of the stock's top bar.
        for at in ((-REC_W, 0.336, 0.092), (-0.0165, BUTT_Y + 0.030, 0.140)):
            loop = cylinder("SlingLoop", (at[0] + 0.001, at[1], at[2]), (at[0] - 0.0035, at[1], at[2]), 0.0068, m["steel"], 20, bevel=0.0006)
            cut(loop, cylinder("li", (at[0] - 0.02, at[1], at[2]), (at[0] + 0.02, at[1], at[2]), 0.0038, m["steel"], 16))
            smooth(loop, 35)
            body.append(loop)
    # --- the sights: the rotary drum at the back of the rail, the hooded post at the front
    ry, fy = SIGHT_Y
    base = box("RearBase", (-0.0125, ry - 0.012, RAIL_TOP - 0.006), (0.0125, ry + 0.011, RAIL_TOP + 0.007), m["steel"], bevel=0.0016)
    smooth(base, 35)
    body.append(base)
    body.append(box("DrumFoot", (-0.0065, ry - 0.007, RAIL_TOP + 0.006), (0.0065, ry + 0.007, IRONS - 0.006), m["steel"], bevel=0.001))
    peep_r = 0.0022 if ROUND < 4 else 0.0036
    drum = cylinder("Drum", (-0.0092, ry, IRONS), (0.0092, ry, IRONS), 0.0102, m["steel"], 36, bevel=0.0012)
    cut(drum, cylinder("peep", (0, ry - 0.02, IRONS), (0, ry + 0.02, IRONS), peep_r, m["steel"], 28))
    if ROUND >= 3:
        # Other apertures round the drum, and the flats between them.
        for a in (90.0, 180.0, 270.0):
            c = cylinder("ap", (0, ry - 0.02, IRONS), (0, ry + 0.02, IRONS), 0.0016, m["steel"], 16)
            c.data.transform(Matrix.Translation((0, ry, IRONS)) @ Matrix.Rotation(math.radians(a), 4, "X") @ Matrix.Translation((0, -ry, -IRONS)))
            cut(drum, c)
    smooth(drum, 35)
    body.append(drum)
    for side in (-1.0, 1.0):
        ear = slab("RearEar", fillet([(ry - 0.011, RAIL_TOP + 0.004, 0.0), (ry + 0.010, RAIL_TOP + 0.004, 0.0), (ry + 0.008, IRONS + 0.010, 0.006), (ry - 0.009, IRONS + 0.012, 0.006)], 5),
                   side * 0.0108 - 0.0016, side * 0.0108 + 0.0016, m["steel"])
        bevel_object(ear, 0.0007, 2, 30.0)
        smooth(ear, 35)
        body.append(ear)
    fbase = box("FrontBase", (-0.0095, fy - 0.014, REC_TOP - 0.006), (0.0095, fy + 0.012, RAIL_TOP + 0.004), m["steel"], bevel=0.0016)
    smooth(fbase, 35)
    body.append(fbase)
    body.append(box("FrontNeck", (-0.0045, fy - 0.004, RAIL_TOP + 0.002), (0.0045, fy + 0.004, IRONS - 0.006), m["steel"], bevel=0.001))
    hood = cylinder("Hood", (0, fy - 0.0045, IRONS + 0.002), (0, fy + 0.0045, IRONS + 0.002), 0.0108, m["steel"], 36, bevel=0.0008)
    cut(hood, cylinder("hi", (0, fy - 0.02, IRONS + 0.002), (0, fy + 0.02, IRONS + 0.002), 0.0086, m["steel"], 36))
    smooth(hood, 35)
    body.append(hood)
    pw = 0.0010 if ROUND < 4 else 0.0013
    body.append(box("Post", (-pw, fy - 0.0012, IRONS - 0.0084), (pw, fy + 0.0012, IRONS), m["steel"]))
    # --- the magazine: the translucent shell, its floor plate and lips, 25 rounds inside
    section = rounded_rect(-MAG_W, MAG_W, MAG_Y[0], MAG_Y[1], 0.004, 0.003, 6)
    # (rounded_rect gives (x, y) here: across and along.)
    body_shell = upright("ShellBody", section, MAG_FOOT + 0.010, MAG_TOP, m["shell"])
    smooth(body_shell, 50)
    shell.append(body_shell)
    if ROUND >= 2:
        # Ribs down its sides and a band round its waist.
        for side in (-1.0, 1.0):
            for y in (MAG_Y[0] + 0.007, MAG_Y[1] - 0.007):
                shell.append(box("Rib", (side * MAG_W - 0.0008, y - 0.0016, MAG_FOOT + 0.012), (side * MAG_W + 0.0008, y + 0.0016, 0.026), m["shell"], bevel=0.0006))
    plate = box("FloorPlate", (-MAG_W - 0.0018, MAG_Y[0] - 0.003, MAG_FOOT), (MAG_W + 0.0018, MAG_Y[1] + 0.003, MAG_FOOT + 0.012), m["magpoly"], bevel=0.003, segments=3)
    if ROUND >= 3:
        cut(plate, box("pg", (-0.03, MAG_Y[1] - 0.004, MAG_FOOT - 0.01), (0.03, MAG_Y[1] + 0.01, MAG_FOOT + 0.004), m["magpoly"], bevel=0.002))
    smooth(plate, 35)
    mag.append(plate)
    mag.append(box("Lips", (-MAG_W, MAG_Y[0] + 0.001, MAG_TOP - 0.008), (MAG_W, MAG_Y[0] + 0.022, MAG_TOP + 0.0005), m["magpoly"], bevel=0.0012))
    cut(mag[-1], box("lo", (-MAG_W + 0.0035, MAG_Y[0] - 0.01, MAG_TOP - 0.02), (MAG_W - 0.0035, MAG_Y[0] + 0.03, MAG_TOP + 0.01), m["magpoly"]))
    # The rounds: .45 ACP, two rows staggered, bullets forward.
    seg = 14 if ROUND >= 2 else 10
    for i in range(ROUNDS):
        x = 0.0048 * (1 if i % 2 == 0 else -1)
        z = MAG_TOP - 0.0042 - i * 0.0072
        y0 = MAG_Y[0] + 0.0015
        mag.append(cylinder("Case", (x, y0, z), (x, y0 + 0.0228, z), 0.0060, m["brass"], seg))
        mag.append(cone("Bullet", (x, y0 + 0.0228, z), (x, y0 + 0.0318, z), 0.0057, 0.0022, m["copper"], seg))
        if ROUND >= 3 and i < 2:
            mag.append(cylinder("Primer", (x, y0 - 0.0002, z), (x, y0 + 0.0002, z), 0.0022, m["steel"], 12))
    mag.append(box("Follower", (-MAG_W + 0.0012, MAG_Y[0] + 0.001, MAG_FOOT + 0.012), (MAG_W - 0.0012, MAG_Y[1] - 0.001, MAG_TOP - 0.0042 - ROUNDS * 0.0072 + 0.002), m["magpoly"]))
    # --- markings (round 3)
    if ROUND >= 3:
        body.append(engrave_left("UMP45", Vector((-REC_W - 0.00015, WELL_Y[1] - 0.004, 0.072)), 0.0085, m["marking"]))
        body.append(engrave_left("Kal. .45 ACP", Vector((-REC_W - 0.00015, WELL_Y[1] - 0.004, 0.062)), 0.0045, m["marking"]))
        body.append(engrave_left("NW 45-1207", Vector((-REC_W - 0.00015, 0.140, 0.106)), 0.0040, m["marking"]))
        # The selector's pictograms on the left: a white bullet crossed out (safe), one red
        # bullet (single), a row of red bullets (fire).
        px = -REC_W
        for k, (dy, dz, count, mat) in enumerate(((-0.0127, 0.0127, 1, m["white"]), (0.0, 0.018, 1, m["red"]), (0.0127, 0.0127, 3, m["red"]))):
            for j in range(count):
                cx = sel.y + dy + j * 0.0028 - (count - 1) * 0.0014
                body.append(box("Picto", (px - 0.0003, cx - 0.0008, sel.z + dz - 0.002), (px + 0.0001, cx + 0.0008, sel.z + dz + 0.0012), mat))
                body.append(cone("PictoTip", (px - 0.0001, cx, sel.z + dz + 0.0012), (px - 0.0001, cx, sel.z + dz + 0.0028), 0.0008, 0.0001, mat, 8))
            if k == 0:
                bar = box("PictoBar", (px - 0.0003, sel.y + dy - 0.0025, sel.z + dz - 0.0004), (px + 0.0001, sel.y + dy + 0.0025, sel.z + dz + 0.0002), mat)
                rotate(bar, math.radians(40.0), "X", Vector((0, sel.y + dy, sel.z + dz)))
                body.append(bar)
        for k, y in enumerate(teeth):
            if k % 3 == 0:
                body.append(engrave_top(str(k + 1), Vector((0.0, y, RAIL_TOP + 0.00005)), 0.0024, m["white"]))
    return body, mag, trig, shell

# ------------------------------------------------------------------ bake
def bake(objs, prefix="ump"):
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


def final_material(images, name="ump"):
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
CENTRE = (0.0, 0.04, 0.05)
FLOOR = (0.0, 0.04, -0.13)
VIEWS = [
    # name, camera, target, lens (mm)
    ("schraeg", (-0.80, 0.85, 0.42), (0.0, 0.04, 0.04), 50),
    ("links", (-1.30, 0.04, 0.06), CENTRE, 55),
    ("rechts", (1.30, 0.04, 0.06), CENTRE, 55),
    ("hinten_schraeg", (0.50, -0.70, 0.40), (0.0, 0.03, 0.08), 50),
    ("oben", (0.0, 0.04, 1.45), (0.0, 0.04, 0.0), 55),
    ("unten", (-0.45, 0.10, -0.85), (0.0, 0.05, 0.02), 50),
    ("nah_receiver", (0.32, 0.02, 0.24), (0.0, 0.14, 0.09), 50),
    ("nah_vorn", (-0.30, 0.62, 0.22), (0.0, 0.28, 0.11), 50),
    ("nah_links", (-0.34, -0.06, 0.14), (0.0, 0.08, 0.06), 50),
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
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=FLOOR)
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
        images = bake(list(parts), "ump")
        final = final_material(images, "ump")
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    # The moving parts move about their own places; the shell goes with the magazine.
    mag_origin = (0.0, (MAG_Y[0] + MAG_Y[1]) * 0.5, MAG_TOP)
    place_origin(magazine, mag_origin)
    shell.data.transform(Matrix.Translation(-Vector(mag_origin)))
    shell.parent = magazine
    shell.location = (0.0, 0.0, 0.0)
    place_origin(trigger, TRIGGER_PIVOT)
    root = link(bpy.data.objects.new("UMP", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "magazine", triangles(magazine), "shell", triangles(shell), "trigger", triangles(trigger),
          "all", sum(triangles(o) for o in parts + (shell,)), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % 0.0112, "rail %.4f irons %.4f" % (RAIL_TOP, IRONS), "rear sight y %.4f front %.4f" % SIGHT_Y)
    print("SPEC handle", godot(HANDLE), "trigger", godot(TRIGGER_PIVOT), "magazine", godot(mag_origin), "support", godot(SUPPORT))
    print("SPEC magazine_foot", godot((0.0, (MAG_Y[0] + MAG_Y[1]) * 0.5, MAG_FOOT)), "eject", godot((REC_W + 0.004, (PORT_Y[0] + PORT_Y[1]) * 0.5, BORE_Z)))
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
