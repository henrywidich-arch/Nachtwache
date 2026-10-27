# Builds the M4A4, the starting rifle of Nachtwache, from nothing (it replaces the supplied
# mesh m4a4.glb, which stays in the folder unused): a 5.56 mm carbine of the AR family with a
# flat-top upper. The anodised aluminium upper with its Picatinny rail, the ejection port with
# the dust cover hanging open and the bolt carrier behind it, the forward assist, the brass
# deflector and the T-shaped charging handle at its back; the lower with the flared magazine
# well, the selector, magazine release and bolt catch, the A2 pistol grip and the trigger
# guard; the buffer tube with its castle nut and the six-position stock; a free-floating
# quad-rail handguard, the barrel with the A2 "birdcage" flash hider; a curved 30-round
# aluminium magazine with the top round in its lips; flip-up iron sights on the rails.
# Every part is made here, bevelled, given its material, UV-unwrapped and baked into one
# texture set (base colour, roughness and metal, normal). Written as a GLB with the nodes
#   M4A4 > Body / Magazine (origin: the middle of its top) / Trigger (origin at its pivot) /
#          Sights (the standing leaves of the flip-up sights; their bases stay on the Body)
#
#   blender --background --factory-startup --python tools/blender_make_m4a4.py -- [--round 4] [--tex 2048]
#           [--out assets/models/m4a4_built.glb] [--render <folder> --prefix m4_r1] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3, 5 a second pass after review: the AR
#          silhouette of lower, magazine and stock, more contrast; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
# --render: fixed views (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the pistol grip. The glTF exporter turns this into Godot space (barrel along -Z, up +Y).
# The places the game needs (GUNS["rifle"] in weapon_view.gd) are printed.
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
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "m4a4_built.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "m4_r%d" % ROUND)
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


def ellipsoid(name, centre, radii, material, segments=28, rings=14):
    """A smooth ellipsoid of the radii (x, y, z) round centre."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centre) @ Matrix.Diagonal((*radii, 1.0)), verts=bm.verts)
    return mesh_object(name, bm, material)


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


def make_materials():
    wear = {1: 0.0, 2: 0.45, 3: 0.8}.get(ROUND, 0.9)
    g = 0.6 if ROUND >= 2 else 0.0
    # The anodised aluminium of the receivers and the rail: near black with a grey cast,
    # satin; its edges rubbed through to the bright metal.
    # (Round 4: the rubbed edges fewer and duller - in round 3 every edge was drawn white.)
    aw, aworn = (wear, (0.42, 0.43, 0.45)) if ROUND < 4 else (0.5 * wear, (0.25, 0.26, 0.27))
    alu = material("alu", (0.034, 0.036, 0.04), 0.5, 0.35, wear=aw, grime=g, bump=0.04 if ROUND >= 3 else 0.0, bump_scale=1800.0, worn=aworn)
    # The handguard: the same anodising, a shade browner (another maker's part).
    rails = material("rails", (0.036, 0.036, 0.038), 0.52, 0.35, wear=aw, grime=g, worn=aworn) if ROUND >= 2 else alu
    polymer = material("polymer", (0.026, 0.027, 0.029), 0.74, 0.0, wear=0.3 * wear, grime=g + 0.2, worn=(0.10, 0.10, 0.105))
    grip = material("grip", (0.028, 0.029, 0.031), 0.82, 0.0, wear=0.25 * wear, grime=g + 0.2, bump=0.0 if ROUND < 3 else 0.8, bump_scale=2200.0, stipple=True, worn=(0.10, 0.10, 0.105)) if ROUND >= 2 else polymer
    steel = material("steel", (0.04, 0.041, 0.043), 0.6, 0.55, wear=0.6 * aw, grime=g, worn=(0.3, 0.3, 0.31))
    carrier = material("carrier", (0.06, 0.06, 0.062), 0.38, 0.85, wear=0.5, grime=0.7, worn=(0.5, 0.5, 0.5)) if ROUND >= 2 else steel
    dark = material("dark", (0.006, 0.006, 0.007), 0.85, 0.0)
    rubber = material("rubber", (0.02, 0.02, 0.021), 0.9, 0.0, grime=0.4 if ROUND >= 2 else 0.0, bump=0.0 if ROUND < 3 else 0.5, bump_scale=900.0, stipple=True)
    magalu = material("magalu", (0.05, 0.051, 0.054), 0.5, 0.45, wear=aw, grime=g, worn=aworn)
    brass = material("brass", (0.66, 0.49, 0.21), 0.34, 1.0, grime=0.2)
    copper = material("copper", (0.55, 0.28, 0.15), 0.34, 1.0, grime=0.2)
    green = material("green", (0.08, 0.2, 0.06), 0.5, 0.0) if ROUND >= 3 else copper
    # Engraved letters cut through the anodising: bright, dull aluminium.
    marking = material("marking", (0.38, 0.39, 0.4), 0.42, 0.7) if ROUND >= 3 else alu
    white = material("white", (0.62, 0.62, 0.6), 0.55, 0.0) if ROUND >= 3 else alu
    if ROUND >= 5:
        # (Round 5, after review: everything read flat grey.) The anodising a dark grey with a
        # satin sheen, the polymer parts black and matt beside it, the edges rubbed through
        # wherever hands and kit wear them; the magazine a lighter grey.
        aw, aworn = 0.8 * wear, (0.36, 0.37, 0.38)
        alu = material("alu", (0.062, 0.064, 0.068), 0.4, 0.45, wear=aw, grime=g, bump=0.04, bump_scale=1800.0, worn=aworn)
        rails = material("rails", (0.056, 0.057, 0.06), 0.42, 0.45, wear=aw, grime=g, worn=aworn)
        polymer = material("polymer", (0.013, 0.013, 0.014), 0.8, 0.0, wear=0.45 * wear, grime=g, worn=(0.07, 0.07, 0.072))
        grip = material("grip", (0.014, 0.014, 0.015), 0.86, 0.0, wear=0.35 * wear, grime=g, bump=0.8, bump_scale=2200.0, stipple=True, worn=(0.07, 0.07, 0.072))
        steel = material("steel", (0.032, 0.033, 0.035), 0.58, 0.55, wear=0.6 * aw, grime=g, worn=(0.32, 0.32, 0.33))
        magalu = material("magalu", (0.09, 0.092, 0.095), 0.45, 0.5, wear=aw, grime=g, worn=(0.42, 0.43, 0.44))
    return {"alu": alu, "rails": rails, "polymer": polymer, "grip": grip, "steel": steel, "carrier": carrier, "dark": dark, "rubber": rubber,
            "magalu": magalu, "brass": brass, "copper": copper, "green": green, "marking": marking, "white": white}


# ------------------------------------------------------------------ the measures
BORE_Z = 0.130                  # the bore axis above the middle of the grip
RAIL_TOP = 0.160                # the top of the rails (3 cm over the bore, as on the real one)
UP_Y = (-0.012, 0.178)          # the upper receiver, from its back to its front face
UP_Z = (0.099, 0.150)           # from the parting line to the foot of the rail
UP_W = 0.0145                   # half its width
LOW_W = 0.0150                  # half the width of the lower receiver at its magazine well
# (Round 5) behind the well the lower is slimmer than the upper: the split line shows.
LOW_R = 0.0128 if ROUND >= 5 else LOW_W
HG_Y = (0.180, 0.398)           # the quad-rail handguard
HG_Z = RAIL_TOP - 0.0285        # its axis
HG_R = 0.0215                   # half its width across the flats (the rails stand 7 mm on that)
HIDER_Y = 0.560
MUZZLE_Y = 0.607                # the face of the flash hider: 84 cm over all
BUTT_Y = -0.233
TUBE_Z = 0.127                  # the buffer tube, in line with the bore
TUBE_R = 0.0146
STOCK_FRONT = -0.075
MAG_TOP = 0.104                 # the top of the magazine's body, inside the well
MAG_Y = (0.1112, 0.1718)        # its back and front at the top
MAG_W = 0.0111                  # half its width
WELL_Y = (0.104, 0.186)         # the magazine well, outside
TRIGGER_PIVOT = Vector((0.0, 0.066, 0.080))
SIGHT_Y = (0.0185, 0.382)       # the rear leaf and the front post
IRONS = RAIL_TOP + 0.0358       # the middle of the aperture, level with the tip of the post
PORT_Y = (0.066, 0.126)         # the ejection port on the right
PORT_Z = (0.1205, 0.1415)
CATCH = Vector((-LOW_W - 0.002, 0.108, 0.087))     # the bolt catch on the left
SUPPORT = Vector((0.0, 0.3251, 0.119))             # where the left hand holds (as before: its baked pose)
GRIP_TILT = math.radians(-22.0)
SIGHTS = []


def mag_spine():
    """The magazine's middle line from its top down: (y, z, lean) every few millimetres -
    straight for its upper part, then curving forward, 24 degrees at its foot."""
    pts = []
    y, z, lean = (MAG_Y[0] + MAG_Y[1]) * 0.5, MAG_TOP, 0.0
    straight, bent, bend = (0.066, 0.116, math.radians(24.0)) if ROUND < 5 else (0.058, 0.124, math.radians(30.0))
    step = 0.004
    s = 0.0
    total = straight + bent
    while s <= total + 1e-6:
        pts.append((y, z, lean))
        lean = 0.0 if s < straight else bend * (s - straight) / bent
        y += math.sin(lean) * step
        z -= math.cos(lean) * step
        s += step
    return pts


def mag_section(round_):
    """The magazine's cross-section (x, d): 22 mm by 61 mm, a raised panel pressed along
    each side (round 2 on)."""
    w, f, b = MAG_W, 0.0305, -0.0305
    if round_ < 2:
        pts = [(w, f, 0.0028), (w, b, 0.0028), (-w, b, 0.0028), (-w, f, 0.0028)]
    elif round_ >= 5:
        # Two ribs pressed along each side, as on the aluminium STANAG magazine.
        p = 0.0009
        right = [(w, f, 0.0035), (w, 0.012, 0.0), (w + p, 0.0105, 0.0), (w + p, 0.004, 0.0), (w, 0.0025, 0.0), (w, -0.008, 0.0), (w + p, -0.0095, 0.0),
                 (w + p, -0.017, 0.0), (w, -0.0185, 0.0), (w, b, 0.0035)]
        pts = right + [(-x, d, r) for x, d, r in reversed(right)]
    else:
        p = 0.0007
        pts = [(w, f, 0.0028), (w, 0.016, 0.0), (w + p, 0.014, 0.0), (w + p, -0.019, 0.0), (w, -0.021, 0.0), (w, b, 0.0028),
               (-w, b, 0.0028), (-w, -0.021, 0.0), (-w - p, -0.019, 0.0), (-w - p, 0.014, 0.0), (-w, 0.016, 0.0), (-w, f, 0.0028)]
    return fillet(pts, 3)


def lower_outline():
    if ROUND >= 5:
        # (Round 5, after review: the lower read as one long box.) The well a short, deep
        # block with its foot cut at a slant and a lip at the front; behind it the lower only
        # as deep as the trigger needs, its back rounded up into the buffer tower.
        return fillet([(0.186, UP_Z[0], 0.0), (0.187, 0.092, 0.003), (0.195, 0.033, 0.003), (0.106, 0.051, 0.004), (0.104, 0.071, 0.003),
                       (0.040, 0.071, 0.002), (0.018, 0.068, 0.006), (-0.004, 0.068, 0.006), (-0.016, 0.076, 0.008), (-0.024, 0.094, 0.010),
                       (-0.024, 0.112, 0.004), (UP_Y[0], 0.112, 0.0), (UP_Y[0], UP_Z[0], 0.0)], 6)
    # (Round 4: the front of the well leans forward towards its foot, as on the real one.)
    front = [(0.186, UP_Z[0], 0.0), (0.188, 0.090, 0.003), (0.185, 0.036, 0.004)] if ROUND < 4 else [(0.186, UP_Z[0], 0.0), (0.187, 0.092, 0.003), (0.193, 0.037, 0.004)]
    return fillet(front + [(0.104, 0.046, 0.004), (0.104, 0.060, 0.003),
                   (0.040, 0.060, 0.002), (0.020, 0.057, 0.006), (-0.006, 0.058, 0.006), (-0.018, 0.068, 0.008), (-0.026, 0.094, 0.006),
                   (-0.028, 0.136, 0.010), (-0.021, 0.146, 0.004), (UP_Y[0], 0.146, 0.0), (UP_Y[0], UP_Z[0], 0.0)], 6 if ROUND >= 2 else 4)


def build(m):
    body, mag, trig = [], [], []
    # --- the upper receiver: its cross-section narrows to the foot of the rail.
    z0, z1 = UP_Z
    prof = [(UP_W, z0), (UP_W, 0.137), (0.0118, 0.146), (0.0104, z1), (-0.0104, z1), (-0.0118, 0.146), (-UP_W, 0.137), (-UP_W, z0)]
    upper = prism("Upper", prof, UP_Y[0], UP_Y[1], m["alu"])
    if ROUND >= 2:
        cutters = [box("port", (0.006, PORT_Y[0], PORT_Z[0]), (0.03, PORT_Y[1], PORT_Z[1]), m["alu"], bevel=0.0015)]
        # The front of the upper: rounded off below the rail where the barrel nut sits.
        for side in (-1.0, 1.0):
            c = box("fc", (side * UP_W - 0.006, UP_Y[1] - 0.010, z0 - 0.01), (side * UP_W + 0.006, UP_Y[1] + 0.01, z0 + 0.016), m["alu"])
            rotate(c, side * math.radians(-30.0), "Y", Vector((side * UP_W, 0, z0 + 0.016)))
            cutters.append(c)
        # The parting line: a fine groove at the foot of the upper where it meets the lower.
        cutters.append(box("pl", (-0.03, UP_Y[0] - 0.01, z0 - 0.002), (0.03, UP_Y[1] + 0.01, z0 + 0.0009), m["alu"]))
        if ROUND >= 4:
            # The sides stand back a little above the ledge along the foot of the upper, the
            # shape of the forging.
            for side in (-1.0, 1.0):
                cutters.append(box("panel", (side * UP_W - 0.0007, 0.004, z0 + 0.0055), (side * UP_W + 0.0007, UP_Y[1] - 0.012, 0.1355), m["alu"], bevel=0.0005))
        cut_many(upper, cutters)
    bevel_object(upper, 0.0012 if ROUND >= 2 else 0.0018, 2, 30.0)
    smooth(upper, 35)
    body.append(upper)
    top, teeth = rail("TopRail", UP_Y[0] + 0.004, UP_Y[1], RAIL_TOP, m["alu"], slots=ROUND >= 2)
    body.append(top)
    if ROUND >= 2:
        # Behind the open port: the dark of the action and the bolt carrier, the bolt's head
        # with its extractor at the front of the opening.
        body.append(box("Action", (0.002, PORT_Y[0] + 0.001, PORT_Z[0] + 0.001), (0.0075, PORT_Y[1] - 0.001, PORT_Z[1] - 0.001), m["dark"]))
        car = box("Carrier", (0.003, PORT_Y[0] - 0.002, PORT_Z[0] + 0.002), (0.0104, PORT_Y[1] - 0.016, PORT_Z[1] - 0.002), m["carrier"], bevel=0.0012)
        if ROUND >= 3:
            # The cut in the carrier's flank, and the cam pin's slot.
            cut(car, box("cc", (0.009, PORT_Y[0] + 0.014, BORE_Z - 0.004), (0.02, PORT_Y[0] + 0.040, BORE_Z + 0.004), m["carrier"], bevel=0.001))
        smooth(car, 35)
        body.append(car)
        body.append(cylinder("BoltHead", (0.004, PORT_Y[1] - 0.017, BORE_Z + 0.0005), (0.004, PORT_Y[1] - 0.002, BORE_Z + 0.0005), 0.0064, m["carrier"], 20))
        body.append(box("Extractor", (0.0078, PORT_Y[1] - 0.016, BORE_Z + 0.002), (0.0102, PORT_Y[1] - 0.003, BORE_Z + 0.0075), m["steel"], bevel=0.0005))
        # The dust cover, swung down and open under the port; its hinge rod along the bottom edge.
        cover = box("DustCover", (UP_W + 0.0004, PORT_Y[0], 0.099), (UP_W + 0.0016, PORT_Y[1], PORT_Z[0] - 0.0005), m["alu"], bevel=0.0004)
        if ROUND >= 3:
            # Its stiffening rib and the catch at the back.
            union(cover, box("rib", (UP_W + 0.0012, PORT_Y[0] + 0.006, 0.106), (UP_W + 0.0026, PORT_Y[1] - 0.006, 0.1085), m["alu"]))
            union(cover, box("latch", (UP_W + 0.0012, PORT_Y[0] + 0.002, 0.112), (UP_W + 0.0028, PORT_Y[0] + 0.007, 0.117), m["alu"]))
        rotate(cover, math.radians(-14.0), "Y", Vector((UP_W + 0.001, 0, PORT_Z[0])))
        smooth(cover, 35)
        body.append(cover)
        body.append(cylinder("Hinge", (UP_W + 0.001, PORT_Y[0] - 0.004, PORT_Z[0] - 0.0005), (UP_W + 0.001, PORT_Y[1] + 0.004, PORT_Z[0] - 0.0005), 0.0012, m["steel"], 10))
        # The forward assist: a housing leaning out behind the port, its round button at the back.
        fa0, fa1 = Vector((0.0112, 0.066, 0.1215)), Vector((0.0172, 0.034, 0.1205))
        body.append(cylinder("ForwardAssist", fa0, fa1, 0.0068, m["alu"], 24, bevel=0.001))
        # Its housing grows out of the receiver's side: a rounded boss under the tube.
        if ROUND < 5:
            boss = slab("FABoss", fillet([(0.030, 0.1150, 0.004), (0.068, 0.1150, 0.004), (0.068, 0.1275, 0.004), (0.030, 0.1275, 0.004)], 4), UP_W - 0.002, 0.0150, m["alu"])
            bevel_object(boss, 0.0025, 3, 30.0)
        else:
            # (Round 5) a rounded, teardrop bulge, swelling towards the button.
            boss = ellipsoid("FABoss", (UP_W - 0.0012, 0.046, 0.1212), (0.0068, 0.025, 0.0112), m["alu"])
        smooth(boss, 35)
        body.append(boss)
        btn = cylinder("FAButton", fa1 - (fa0 - fa1).normalized() * -0.001, fa1 + (fa1 - fa0).normalized() * 0.010, 0.0074, m["steel"], 28, bevel=0.0012)
        if ROUND >= 3:
            # The notches round the button's face that the thumb pushes.
            axis = (fa1 - fa0).normalized()
            cutters = []
            for k in range(12):
                a = math.tau * k / 12.0
                c = box("bn", (-0.0009, -0.004, -0.0012), (0.0009, 0.004, 0.0012), m["steel"])
                c.data.transform(Matrix.Translation(fa1 + axis * 0.010) @ axis.to_track_quat("Y", "Z").to_matrix().to_4x4() @ Matrix.Rotation(a, 4, "Y") @ Matrix.Translation((0.0074, 0, 0)))
                cutters.append(c)
            cut_many(btn, cutters)
        smooth(btn, 35)
        body.append(btn)
        # The brass deflector: a hump behind the port's top corner.
        if ROUND < 5:
            defl = slab("Deflector", fillet([(0.048, 0.128, 0.0), (0.066, 0.128, 0.0), (0.066, 0.1465, 0.002), (0.058, 0.1465, 0.004)], 3), UP_W - 0.002, UP_W + 0.0058, m["alu"])
            bevel_object(defl, 0.0015, 2, 30.0)
        else:
            # (Round 5) a hump that rises towards the port and ends in a face at its back edge.
            defl = ellipsoid("Deflector", (UP_W - 0.0006, PORT_Y[0] + 0.001, 0.1372), (0.0052, 0.016, 0.0088), m["alu"])
            cut(defl, box("df", (0.0, PORT_Y[0], 0.12), (0.04, PORT_Y[0] + 0.03, 0.16), m["alu"]))
        smooth(defl, 35)
        body.append(defl)
    # --- the charging handle: a T at the back of the upper, under the rail, its latch on the left
    ch = box("ChargingHandle", (-0.0055, UP_Y[0] - 0.018, 0.1385), (0.0055, UP_Y[0] + 0.004, 0.1475), m["alu"], bevel=0.0012)
    body.append(ch)
    tee = slab("ChargingT", fillet([(UP_Y[0] - 0.026, 0.138, 0.002), (UP_Y[0] - 0.016, 0.138, 0.002), (UP_Y[0] - 0.016, 0.148, 0.002), (UP_Y[0] - 0.026, 0.148, 0.002)], 3), -0.0205, 0.0205, m["alu"])
    if ROUND >= 2:
        # The arms sweep back a little towards their ends.
        for side in (-1.0, 1.0):
            c = box("tc", (0.012 if side > 0 else -0.04, UP_Y[0] - 0.016, 0.13), (0.04 if side > 0 else -0.012, UP_Y[0] + 0.01, 0.16), m["alu"])
            rotate(c, -side * math.radians(20.0), "Z", Vector((side * 0.012, UP_Y[0] - 0.016, 0)))
            cut(tee, c)
    bevel_object(tee, 0.0016, 2, 30.0)
    smooth(tee, 35)
    body.append(tee)
    if ROUND >= 2:
        latch = box("Latch", (-0.0235, UP_Y[0] - 0.024, 0.1392), (-0.0185, UP_Y[0] - 0.006, 0.1468), m["alu"], bevel=0.0012)
        if ROUND >= 3:
            for k in range(4):
                cut(latch, box("lg", (-0.03, UP_Y[0] - 0.023 + k * 0.004, 0.139), (-0.0228, UP_Y[0] - 0.0215 + k * 0.004, 0.148), m["alu"]))
        smooth(latch, 35)
        body.append(latch)
    # --- the lower receiver: the magazine well, the trigger housing, the buffer tower
    lower = slab("Lower", lower_outline(), -LOW_W, LOW_W, m["alu"])
    cutters = [box("well", (-MAG_W - 0.0006, MAG_Y[0] - 0.0004, -0.02), (MAG_W + 0.0006, MAG_Y[1] + 0.0004, MAG_TOP + 0.004), m["alu"])]
    if ROUND >= 2:
        # The tower the buffer tube screws into is rounder and narrower than the receiver.
        for side in (-1.0, 1.0):
            c = box("tw", (side * LOW_W - 0.004, -0.04, 0.104), (side * LOW_W + 0.004, UP_Y[0] - 0.001, 0.16), m["alu"])
            cutters.append(c)
        # The trigger housing a little narrower below the parting line, behind the well.
        for side in ((-1.0, 1.0) if ROUND < 5 else ()):
            cutters.append(box("th", (side * LOW_W - 0.0015 * (side > 0) - 0.01 * (side < 0), -0.002, 0.05), (side * LOW_W + 0.01 * (side > 0) + 0.0015 * (side < 0), 0.101, 0.071), m["alu"], bevel=0.001))
        # The slot the trigger hangs out of.
        tz = 0.066 if ROUND < 5 else 0.077
        cutters.append(box("ts", (-0.0042, 0.054, 0.05), (0.0042, 0.092, tz), m["alu"], bevel=0.0008))
        if ROUND >= 5:
            for side in (-1.0, 1.0):
                cutters.append(box("slim", (LOW_R if side > 0 else -0.04, -0.05, 0.0), (0.04 if side > 0 else -LOW_R, 0.1025, UP_Z[0] + 0.0004), m["alu"], bevel=0.001))
    if ROUND >= 3:
        # Serrations across the front of the well, where a hand may hold it.
        for k in range(9):
            z = 0.048 + k * 0.0045
            face = 0.1860 if ROUND < 4 else 0.187 + (0.092 - z) * 0.006 / 0.055 - 0.0006
            cutters.append(box("ser", (-0.03, face, z), (0.03, face + 0.01, z + 0.0016), m["alu"]))
    cut_many(lower, cutters)
    bevel_object(lower, 0.0016 if ROUND >= 2 else 0.002, 2, 32.0)
    smooth(lower, 35)
    body.append(lower)
    if ROUND >= 2:
        # The tower: a ring round the tube's end.
        body.append(cylinder("Tower", (0, UP_Y[0] - 0.002, TUBE_Z), (0, -0.027, TUBE_Z), 0.0172, m["alu"], 32, bevel=0.0015))
        # The flared mouth of the well.
        fy0, fy1 = (0.1868, 0.1872) if ROUND < 4 else (0.1935, 0.1928)
        lip = [(0.1032, 0.0458, 0.0), (fy0, 0.0352, 0.0), (fy1, 0.0438, 0.0), (0.1035, 0.0538, 0.0)]
        if ROUND >= 5:
            # A deeper lip, flared wider, along the slanted foot of the well.
            lip = [(0.1052, 0.0498, 0.0), (0.1962, 0.0318, 0.0), (0.1948, 0.0432, 0.0), (0.1056, 0.0602, 0.0)]
        fw = 0.0016 if ROUND < 5 else 0.0024
        flare = slab("Flare", fillet(lip, 1), -LOW_W - fw, LOW_W + fw, m["alu"])
        cut(flare, box("fm", (-MAG_W - 0.0006, MAG_Y[0] - 0.0004, -0.02), (MAG_W + 0.0006, MAG_Y[1] + 0.0004, 0.08), m["alu"]))
        bevel_object(flare, 0.0012, 2, 30.0)
        smooth(flare, 35)
        body.append(flare)
        # Inside the well: dark, so that it reads as a hole when the magazine is out.
        body.append(box("WellRoof", (-MAG_W - 0.0006, MAG_Y[0], MAG_TOP + 0.003), (MAG_W + 0.0006, MAG_Y[1], MAG_TOP + 0.005), m["dark"]))
        for side in (-1.0, 1.0):
            body.append(box("WellWall", (side * (MAG_W + 0.0003) - 0.0002, MAG_Y[0], 0.05), (side * (MAG_W + 0.0003) + 0.0002, MAG_Y[1], MAG_TOP + 0.004), m["dark"]))
        twz = 0.0615 if ROUND < 5 else 0.0705
        body.append(box("TriggerWell", (-0.0040, 0.055, twz), (0.0040, 0.091, twz + 0.001), m["dark"]))
    # --- the pistol grip: the A2 grip with its finger ridge, leaning back
    rows = [(0.066, 0.0160, 0.0172, 0.0112), (0.044, 0.0156, 0.0176, 0.0117), (0.014, 0.0150, 0.0180, 0.0120), (0.004, 0.0166, 0.0182, 0.0121),
            (-0.004, 0.0190, 0.0182, 0.0121), (-0.012, 0.0157, 0.0182, 0.0121), (-0.032, 0.0150, 0.0178, 0.0118), (-0.044, 0.0142, 0.0168, 0.0112),
            (-0.049, 0.0128, 0.0150, 0.0100), (-0.0515, 0.0100, 0.0120, 0.0076)]
    if ROUND < 2:
        rows = [r for r in rows if r[0] not in (0.004, -0.004, -0.012)]
    if ROUND >= 5:
        # Its top reaches into the shallower lower.
        rows.insert(0, (0.080, 0.0160, 0.0170, 0.0110))
    sections = []
    for z, f, b, w in rows:
        sections.append([Vector((x, d, z)) for x, d in oval(f, b, w, 32, 2.4)])
    grip = loft("Grip", sections, m["grip"])
    rotate(grip, GRIP_TILT, "X", Vector((0, 0, 0)))
    smooth(grip, 45)
    body.append(grip)
    if ROUND >= 3:
        # The grip's screw from below, and the strap of the grip's back.
        body.append(cylinder("GripScrew", (0, 0.0, -0.049), (0, 0.0, -0.0535), 0.003, m["steel"], 12))
        rotate(body[-1], GRIP_TILT, "X", Vector((0, 0, 0)))
    # --- the trigger guard
    gt = 0.061 if ROUND < 5 else 0.073
    outer = fillet([(0.1055, gt, 0.0), (0.1055, 0.040, 0.005), (0.097, 0.0305, 0.005), (0.046, 0.0305, 0.006), (0.036, 0.042, 0.004), (0.036, gt, 0.0)], 5)
    inner = fillet([(0.0995, gt + 0.01, 0.0), (0.0995, 0.041, 0.003), (0.094, 0.036, 0.003), (0.049, 0.036, 0.004), (0.0425, 0.043, 0.003), (0.0425, gt + 0.01, 0.0)], 5)
    guard = slab("Guard", outer, -0.0045, 0.0045, m["alu"])
    cut(guard, slab("gi", inner, -0.02, 0.02, m["alu"]))
    bevel_object(guard, 0.0012, 2, 30.0)
    smooth(guard, 35)
    body.append(guard)
    if ROUND >= 3:
        body.append(cylinder("GuardPin", (-0.0047, 0.1015, 0.051), (0.0047, 0.1015, 0.051), 0.0017, m["steel"], 10))
    # --- the trigger: a curved blade under its pin
    blade = box("Blade", (-0.0028, TRIGGER_PIVOT.y - 0.004, 0.056), (0.0028, TRIGGER_PIVOT.y + 0.003, TRIGGER_PIVOT.z + 0.003), m["steel"], bevel=0.001)
    trig.append(blade)
    tip = box("BladeTip", (-0.0028, TRIGGER_PIVOT.y - 0.002, 0.042), (0.0028, TRIGGER_PIVOT.y + 0.0045, 0.059), m["steel"], bevel=0.001)
    rotate(tip, math.radians(-14.0), "X", Vector((0, TRIGGER_PIVOT.y, 0.058)))
    trig.append(tip)
    # --- the controls: selector, magazine release, bolt catch, pins
    sel = Vector((-LOW_R, 0.012, 0.0845))
    body.append(cylinder("Selector", (sel.x + 0.0005, sel.y, sel.z), (sel.x - 0.0022, sel.y, sel.z), 0.0056, m["steel"], 24, bevel=0.0007))
    lever = box("SelectorLever", (sel.x - 0.0038, sel.y - 0.020, sel.z - 0.0028), (sel.x - 0.0016, sel.y + 0.002, sel.z + 0.0028), m["steel"], bevel=0.0008)
    # Turned back and down a little: set to AUTO.
    rotate(lever, math.radians(12.0), "X", sel)
    body.append(lever)
    body.append(cylinder("SelectorR", (LOW_R - 0.0005, sel.y, sel.z), (LOW_R + 0.0012, sel.y, sel.z), 0.0042, m["steel"], 18))
    if ROUND >= 2:
        # The magazine release on the right, in its fence; the bolt catch on the left.
        rel = cylinder("MagRelease", (LOW_R - 0.0005, 0.0965, 0.0775), (LOW_R + 0.0026, 0.0965, 0.0775), 0.0056, m["steel"], 24, bevel=0.0008)
        if ROUND >= 3:
            for k in range(5):
                cut(rel, box("rg", (LOW_R + 0.0019, 0.0912 + k * 0.0022, 0.07), (LOW_R + 0.004, 0.0920 + k * 0.0022, 0.085), m["steel"]))
        body.append(rel)
        fence = cylinder("Fence", (LOW_R - 0.001, 0.0965, 0.0775), (LOW_R + 0.0024, 0.0965, 0.0775), 0.0098, m["alu"], 32)
        cut(fence, cylinder("fi", (LOW_R - 0.01, 0.0965, 0.0775), (LOW_R + 0.01, 0.0965, 0.0775), 0.0068, m["alu"], 32))
        cut(fence, box("fb", (LOW_R - 0.02, 0.08, 0.06), (LOW_R + 0.02, 0.12, 0.0745), m["alu"]))
        bevel_object(fence, 0.0008, 2, 30.0)
        smooth(fence, 35)
        body.append(fence)
        catch = box("BoltCatch", (CATCH.x - 0.0004, CATCH.y - 0.008, CATCH.z - 0.008), (CATCH.x + 0.0026, CATCH.y + 0.008, CATCH.z + 0.009), m["steel"], bevel=0.0008)
        if ROUND >= 3:
            for k in range(5):
                cut(catch, box("cg", (CATCH.x - 0.003, CATCH.y - 0.007 + k * 0.003, CATCH.z + 0.004), (CATCH.x + 0.0004, CATCH.y - 0.006 + k * 0.003, CATCH.z + 0.01), m["steel"]))
        body.append(catch)
        # The bosses either side of the catch's pin.
        for y in (CATCH.y - 0.0115, CATCH.y + 0.0115):
            bx = LOW_R if y < 0.1025 else LOW_W
            body.append(cylinder("Boss", (-bx + 0.0005, y, CATCH.z - 0.004), (-bx - 0.0024, y, CATCH.z - 0.004), 0.0032, m["alu"], 16, bevel=0.0006))
        # Takedown and pivot pins, hammer and trigger pins: their heads on both sides.
        for y, z, r in ((0.181, 0.094, 0.0032), (UP_Y[0] + 0.006, 0.092, 0.0032), (0.046, 0.0805, 0.0022), (TRIGGER_PIVOT.y, TRIGGER_PIVOT.z, 0.0022)):
            for side in (-1.0, 1.0):
                pw_ = LOW_W if y > 0.1025 else LOW_R
                body.append(cylinder("Pin", (side * (pw_ - 0.0006), y, z), (side * (pw_ + 0.0006), y, z), r, m["steel"], 14))
    # --- the buffer tube, its castle nut and end plate, the stock
    body.append(cylinder("Tube", (0, -0.026, TUBE_Z), (0, BUTT_Y + 0.02, TUBE_Z), TUBE_R, m["alu"], 32, bevel=0.0008))
    if ROUND >= 2:
        nut = cylinder("CastleNut", (0, -0.030, TUBE_Z), (0, -0.038, TUBE_Z), 0.0178, m["steel"], 32, bevel=0.0008)
        cutters = []
        for k in range(3):
            c = box("nn", (-0.0025, -0.04, TUBE_Z + 0.014), (0.0025, -0.0355, TUBE_Z + 0.03), m["steel"])
            c.data.transform(Matrix.Translation((0, 0, TUBE_Z)) @ Matrix.Rotation(math.tau * k / 3.0 + 0.4, 4, "Y") @ Matrix.Translation((0, 0, -TUBE_Z)))
            cutters.append(c)
        cut_many(nut, cutters)
        smooth(nut, 35)
        body.append(nut)
        plate = slab("EndPlate", fillet([(-0.027, 0.106, 0.004), (-0.027, 0.146, 0.006), (-0.0295, 0.146, 0.006), (-0.0295, 0.106, 0.004)], 3), -0.0165, 0.0165, m["steel"])
        body.append(plate)
        # Its sling loop on the left.
        loop = cylinder("SlingLoop", (-0.017, -0.0283, 0.134), (-0.024, -0.0283, 0.134), 0.0062, m["steel"], 20)
        loop.data.transform(Matrix.Translation((-0.0205, -0.0283, 0.134)) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Translation((0.0205, 0.0283, -0.134)))
        cut(loop, cylinder("li", (-0.0205, -0.04, 0.134), (-0.0205, -0.016, 0.134), 0.0034, m["steel"], 16))
        body.append(loop)
    if ROUND < 5:
        # (Round 4: longer and slimmer - a straight spine under the tube, then the drop to the butt.)
        stock_line = [(STOCK_FRONT, 0.1455, 0.003), (-0.205, 0.1485, 0.01), (BUTT_Y + 0.008, 0.151, 0.006), (BUTT_Y + 0.006, 0.030, 0.006),
                      (BUTT_Y + 0.026, 0.026, 0.01), (-0.192, 0.046, 0.03), (-0.150, 0.098, 0.03), (-0.110, 0.104, 0.01), (STOCK_FRONT, 0.1075, 0.003)]
        stock = slab("Stock", fillet(stock_line, 6), -0.0185, 0.0185, m["polymer"])
        cutters = []
        if ROUND >= 2:
            # The front narrows to the collar round the tube; the sling slot at the bottom of the butt.
            for side in (-1.0, 1.0):
                c = box("sn", (0.0155 if side > 0 else -0.03, STOCK_FRONT - 0.04, 0.09), (0.03 if side > 0 else -0.0155, STOCK_FRONT + 0.01, 0.16), m["polymer"])
                rotate(c, side * math.radians(14.0), "Z", Vector((side * 0.0155, STOCK_FRONT, 0)))
                cutters.append(c)
            cutters.append(box("sling", (-0.03, -0.214, 0.036), (0.03, -0.194, 0.0435), m["polymer"], bevel=0.002))
        if ROUND >= 3:
            # A shallow pocket on each side of the butt, ribs along the top.
            for side in (-1.0, 1.0):
                pocket = slab("pk", fillet([(-0.112, 0.136, 0.006), (-0.210, 0.138, 0.012), (-0.212, 0.058, 0.012), (-0.186, 0.074, 0.02), (-0.152, 0.110, 0.012), (-0.112, 0.114, 0.006)], 6),
                              side * 0.0185 - 0.0015, side * 0.0185 + 0.0015, m["polymer"])
                cutters.append(pocket)
        cut_many(stock, cutters)
        bevel_object(stock, 0.0026, 3, 30.0)
        smooth(stock, 35)
        body.append(stock)
        pad = slab("ButtPad", fillet([(BUTT_Y + 0.008, 0.152, 0.004), (BUTT_Y, 0.150, 0.006), (BUTT_Y - 0.002, 0.090, 0.04), (BUTT_Y, 0.027, 0.006), (BUTT_Y + 0.008, 0.025, 0.004)], 5),
                    -0.0195, 0.0195, m["rubber"])
        if ROUND >= 3:
            cutters = []
            for k in range(10):
                z = 0.036 + k * 0.0115
                cutters.append(box("pr", (-0.03, BUTT_Y - 0.01, z - 0.0013), (0.03, BUTT_Y - 0.0004, z + 0.0013), m["rubber"]))
            cut_many(pad, cutters)
        bevel_object(pad, 0.0022, 2, 30.0)
        smooth(pad, 35)
        body.append(pad)
    else:
        # (Round 5, after review: the stock read as an angular slab.) The collapsible M4 stock:
        # a rounded sleeve over the buffer tube, a cheek riser on it that rises towards the
        # butt, a thin web under it with its straight sloping foot and the sling slot, the
        # wide butt and its rubber pad.
        sleeve = cylinder("StockSleeve", (0, STOCK_FRONT, TUBE_Z), (0, BUTT_Y + 0.010, TUBE_Z), 0.0186, m["polymer"], 32, bevel=0.002)
        sleeve.data.transform(Matrix.Translation((0, 0, TUBE_Z)) @ Matrix.Diagonal((1.0, 1.0, 1.1, 1.0)) @ Matrix.Translation((0, 0, -TUBE_Z)))
        smooth(sleeve, 40)
        body.append(sleeve)
        cheek = slab("Cheek", fillet([(STOCK_FRONT - 0.028, 0.139, 0.004), (BUTT_Y + 0.012, 0.1585, 0.006), (BUTT_Y + 0.010, 0.128, 0.0), (STOCK_FRONT - 0.028, 0.128, 0.0)], 5), -0.0172, 0.0172, m["polymer"])
        bevel_object(cheek, 0.0045, 3, 30.0)
        smooth(cheek, 35)
        body.append(cheek)
        web = slab("StockWeb", fillet([(STOCK_FRONT + 0.002, 0.118, 0.003), (BUTT_Y + 0.010, 0.124, 0.0), (BUTT_Y + 0.010, 0.026, 0.004), (BUTT_Y + 0.026, 0.024, 0.006),
                                       (-0.180, 0.060, 0.03), (-0.140, 0.098, 0.02), (STOCK_FRONT - 0.012, 0.104, 0.006)], 6), -0.0112, 0.0112, m["polymer"])
        cut(web, box("sling", (-0.03, -0.215, 0.033), (0.03, -0.195, 0.041), m["polymer"], bevel=0.002))
        if ROUND >= 3:
            # A rib along the web's foot.
            for side in (-1.0, 1.0):
                cut(web, slab("wr", fillet([(-0.142, 0.092, 0.0), (-0.200, 0.036, 0.0), (-0.196, 0.032, 0.0), (-0.146, 0.088, 0.0)], 1),
                              side * 0.0112 - 0.0008, side * 0.0112 + 0.0008, m["polymer"]))
        bevel_object(web, 0.002, 2, 30.0)
        smooth(web, 35)
        body.append(web)
        butt = slab("Butt", fillet([(BUTT_Y + 0.016, 0.161, 0.004), (BUTT_Y + 0.004, 0.162, 0.004), (BUTT_Y + 0.004, 0.022, 0.004), (BUTT_Y + 0.020, 0.022, 0.004)], 4), -0.0205, 0.0205, m["polymer"])
        bevel_object(butt, 0.003, 3, 30.0)
        smooth(butt, 35)
        body.append(butt)
        pad = slab("ButtPad", fillet([(BUTT_Y + 0.005, 0.161, 0.004), (BUTT_Y - 0.003, 0.159, 0.006), (BUTT_Y - 0.005, 0.090, 0.05), (BUTT_Y - 0.003, 0.025, 0.006), (BUTT_Y + 0.005, 0.023, 0.004)], 5),
                    -0.0198, 0.0198, m["rubber"])
        cutters = []
        for k in range(11):
            z = 0.032 + k * 0.0115
            cutters.append(box("pr", (-0.03, BUTT_Y - 0.012, z - 0.0013), (0.03, BUTT_Y - 0.0035, z + 0.0013), m["rubber"]))
        cut_many(pad, cutters)
        bevel_object(pad, 0.002, 2, 30.0)
        smooth(pad, 35)
        body.append(pad)
    if ROUND >= 2:
        # The lever under the stock's front that lets it slide on the tube.
        lev = box("StockLever", (-0.0052, STOCK_FRONT - 0.034, 0.100), (0.0052, STOCK_FRONT - 0.004, 0.1085), m["polymer"], bevel=0.0018)
        body.append(lev)
    if ROUND >= 3:
        # The positions drilled along the bottom of the tube, ahead of the stock.
        for k in range(2):
            y = STOCK_FRONT + 0.012 + k * 0.016
            body.append(box("Notch", (-0.0022, y - 0.0025, TUBE_Z - TUBE_R - 0.0002), (0.0022, y + 0.0025, TUBE_Z - TUBE_R + 0.0004), m["dark"]))
    # --- the handguard: an octagonal tube on the barrel nut, a rail on each of its four flats
    c = 0.0122
    octagon = [(HG_R, -c), (HG_R, c), (c, HG_R), (-c, HG_R), (-HG_R, c), (-HG_R, -c), (-c, -HG_R), (c, -HG_R)]
    hg = prism("Handguard", [(x, HG_Z + z) for x, z in octagon], HG_Y[0] + 0.006, HG_Y[1], m["rails"])
    cutters = []
    if ROUND >= 2:
        cutters.append(cylinder("bore", (0, HG_Y[0], HG_Z), (0, HG_Y[1] + 0.01, HG_Z), 0.0172, m["rails"], 32))
        # Vent slots on the four corners, between the rails.
        for k in range(4):
            a = math.radians(45.0 + 90.0 * k)
            for i in range(7):
                y = HG_Y[0] + 0.040 + i * 0.024
                s = box("vent", (-0.0034, y - 0.0075, 0.012), (0.0034, y + 0.0075, 0.04), m["rails"], bevel=0.0028, segments=3)
                s.data.transform(Matrix.Translation((0, 0, HG_Z)) @ Matrix.Rotation(a, 4, "Y"))
                cutters.append(s)
    cut_many(hg, cutters)
    bevel_object(hg, 0.0012, 2, 30.0)
    smooth(hg, 35)
    body.append(hg)
    r, _ = rail("HGTop", HG_Y[0] + 0.003, HG_Y[1] - 0.001, RAIL_TOP, m["rails"], slots=ROUND >= 2)
    body.append(r)
    for k, (y0, y1) in enumerate(((0.232, HG_Y[1] - 0.004), (0.232, HG_Y[1] - 0.004), (0.214, HG_Y[1] - 0.004))):
        side_rail, _ = rail("HGRail", y0, y1, RAIL_TOP, m["rails"], slots=ROUND >= 2)
        turn_about_y(side_rail, math.radians(90.0 * (k + 1)), (0.0, HG_Z))
        body.append(side_rail)
    if ROUND >= 2:
        # The barrel nut where the handguard meets the upper; the cap at its front.
        body.append(cylinder("BarrelNut", (0, UP_Y[1] - 0.002, HG_Z), (0, HG_Y[0] + 0.007, HG_Z), 0.0198, m["steel"], 32, bevel=0.0008))
        body.append(cylinder("HGCap", (0, HG_Y[1] - 0.004, HG_Z), (0, HG_Y[1] + 0.0025, HG_Z), 0.0185, m["rails"], 32, bevel=0.001))
        cap_hole = cylinder("HGCapIn", (0, HG_Y[1] - 0.003, HG_Z), (0, HG_Y[1] + 0.0028, HG_Z), 0.0122, m["dark"], 24)
        body.append(cap_hole)
    if ROUND >= 3:
        # The cross bolts at the back of the handguard.
        for side in (-1.0, 1.0):
            for y in (HG_Y[0] + 0.014, HG_Y[0] + 0.030):
                body.append(cylinder("HGBolt", (side * (HG_R - 0.0004), y, HG_Z - 0.0145), (side * (HG_R + 0.0016), y, HG_Z - 0.0145), 0.0026, m["steel"], 6))
    # --- barrel, gas block and tube (seen through the vents), flash hider
    body.append(cylinder("Barrel", (0, UP_Y[1] - 0.004, BORE_Z), (0, HG_Y[1] + 0.006, BORE_Z), 0.0095, m["steel"], 28))
    body.append(cone("BarrelStep", (0, HG_Y[1] + 0.006, BORE_Z), (0, HG_Y[1] + 0.016, BORE_Z), 0.0095, 0.0082, m["steel"], 28))
    body.append(cylinder("BarrelFront", (0, HG_Y[1] + 0.015, BORE_Z), (0, HIDER_Y + 0.004, BORE_Z), 0.0082, m["steel"], 28))
    if ROUND >= 2:
        body.append(box("GasBlock", (-0.0118, 0.364, BORE_Z - 0.0105), (0.0118, 0.386, BORE_Z + 0.0195), m["steel"], bevel=0.0025))
        body.append(cylinder("GasTube", (0, UP_Y[1] - 0.002, BORE_Z + 0.0145), (0, 0.366, BORE_Z + 0.0145), 0.0024, m["steel"], 12))
        # The cut for a grenade launcher's clamp, before the muzzle.
        body.append(cylinder("M203Cut", (0, 0.452, BORE_Z), (0, 0.458, BORE_Z), 0.0076, m["steel"], 28))
        body.append(cylinder("CrushWasher", (0, HIDER_Y - 0.003, BORE_Z), (0, HIDER_Y + 0.0005, BORE_Z), 0.0102, m["steel"], 6))
    hider = cylinder("Hider", (0, HIDER_Y, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.0112, m["steel"], 32, bevel=0.0012 if ROUND >= 2 else 0.0)
    cutters = [cylinder("bore", (0, HIDER_Y + 0.006, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0079, m["steel"], 24)]
    if ROUND >= 2:
        # The A2 birdcage: five slots round its top and sides, the bottom closed (it does not
        # throw up dust when lying prone).
        for k in range(5):
            a = math.radians(-120.0 + 60.0 * k)
            s = box("slot", (-0.0016, MUZZLE_Y - 0.035, 0.004), (0.0016, MUZZLE_Y - 0.006, 0.02), m["steel"], bevel=0.0006)
            s.data.transform(Matrix.Translation((0, 0, BORE_Z)) @ Matrix.Rotation(a, 4, "Y"))
            cutters.append(s)
        # Its waist: the front a little slimmer.
        ring = cylinder("waist", (0, HIDER_Y + 0.008, BORE_Z), (0, HIDER_Y + 0.0105, BORE_Z), 0.02, m["steel"], 24)
        cut(ring, cylinder("wi", (0, HIDER_Y, BORE_Z), (0, HIDER_Y + 0.02, BORE_Z), 0.0106, m["steel"], 32))
        cutters.append(ring)
    cut_many(hider, cutters)
    smooth(hider, 35)
    body.append(hider)
    body.append(cylinder("BoreDark", (0, HIDER_Y + 0.004, BORE_Z), (0, MUZZLE_Y - 0.001, BORE_Z), 0.0078, m["dark"], 20))
    # --- the flip-up sights: low bases clamped on the rails (Body), the standing parts (Sights)
    for y in SIGHT_Y:
        b = box("SightBase", (-0.0122, y - 0.012, RAIL_TOP - 0.0062), (0.0122, y + 0.012, RAIL_TOP + 0.0062), m["alu"], bevel=0.0018)
        if ROUND >= 2:
            # Its clamp screw on the left; the spring hinge's barrel across the top.
            body.append(cylinder("Clamp", (-0.0122, y - 0.004, RAIL_TOP - 0.0026), (-0.0152, y - 0.004, RAIL_TOP - 0.0026), 0.0034, m["steel"], 6))
            body.append(cylinder("HingeBarrel", (-0.010, y + 0.006, RAIL_TOP + 0.0068), (0.010, y + 0.006, RAIL_TOP + 0.0068), 0.0028, m["alu"], 16))
        smooth(b, 35)
        body.append(b)
    ry, fy = SIGHT_Y
    # (Round 4: the large aperture - 8 mm -, so that the ring and the post in it read at a glance.)
    peep_r, disc_r, lw_ = (0.0021, 0.0058, 0.0080) if ROUND < 4 else (0.0040, 0.0078, 0.0088)
    leaf = box("RearLeaf", (-lw_, ry - 0.0022, RAIL_TOP + 0.004), (lw_, ry + 0.0022, IRONS + disc_r + 0.001), m["alu"], bevel=0.0012)
    disc = cylinder("Aperture", (0, ry - 0.0032, IRONS), (0, ry + 0.0032, IRONS), disc_r, m["alu"], 40, bevel=0.0008)
    for o in (leaf, disc):
        cut(o, cylinder("peep", (0, ry - 0.02, IRONS), (0, ry + 0.02, IRONS), peep_r, m["alu"], 32))
        smooth(o, 35)
    SIGHTS.extend([leaf, disc])
    for side in (-1.0, 1.0):
        wx = 0.0108 if ROUND < 4 else 0.0118
        wing = box("RearWing", (side * wx - 0.0015, ry - 0.008, RAIL_TOP + 0.004), (side * wx + 0.0015, ry + 0.008, IRONS + 0.004), m["alu"], bevel=0.0008)
        if ROUND >= 2:
            # Its top cut at a slant, high at the aperture.
            c = box("wc", (side * wx - 0.01, ry - 0.03, IRONS + 0.004), (side * wx + 0.01, ry + 0.03, IRONS + 0.03), m["alu"])
            rotate(c, side * math.radians(30.0), "Y", Vector((side * (wx - 0.0015), 0, IRONS + 0.004)))
            cut(wing, c)
        smooth(wing, 35)
        SIGHTS.append(wing)
    if ROUND >= 2:
        # The windage drum on the right of the rear sight.
        drum = cylinder("Windage", (0.0118, ry - 0.006, RAIL_TOP + 0.0085), (0.0168, ry - 0.006, RAIL_TOP + 0.0085), 0.0042, m["alu"], 24, bevel=0.0007)
        if ROUND >= 3:
            cutters = []
            for k in range(16):
                a = math.tau * k / 16
                cutters.append(box("wr", (0.0130, ry - 0.006 + math.cos(a) * 0.0042 - 0.0004, RAIL_TOP + 0.0085 + math.sin(a) * 0.0042 - 0.0004),
                                   (0.0180, ry - 0.006 + math.cos(a) * 0.0042 + 0.0004, RAIL_TOP + 0.0085 + math.sin(a) * 0.0042 + 0.0004), m["alu"]))
            cut_many(drum, cutters)
        SIGHTS.append(drum)
    # The front: two ears round the post, joined at their foot; the post on its threaded drum.
    for side in (-1.0, 1.0):
        ew = 0.0013 if ROUND < 4 else 0.0017
        ear = box("FrontEar", (side * 0.0088 - ew, fy - 0.0035, RAIL_TOP + 0.004), (side * 0.0088 + ew, fy + 0.0035, IRONS + 0.0045), m["alu"], bevel=0.0007)
        smooth(ear, 35)
        SIGHTS.append(ear)
    SIGHTS.append(box("FrontBridge", (-0.0101, fy - 0.0035, RAIL_TOP + 0.004), (0.0101, fy + 0.0035, RAIL_TOP + 0.013), m["alu"], bevel=0.0008))
    SIGHTS.append(cylinder("PostDrum", (0, fy, RAIL_TOP + 0.012), (0, fy, RAIL_TOP + 0.020), 0.0032, m["steel"], 16))
    pw = 0.0009 if ROUND < 4 else 0.0013
    SIGHTS.append(box("FrontPost", (-pw, fy - 0.0011, RAIL_TOP + 0.018), (pw, fy + 0.0011, IRONS), m["steel"]))
    # --- the magazine: a curved box of aluminium, ribbed sides, its floor plate, a round on top
    spine = mag_spine()
    section = mag_section(ROUND)
    rings = []
    for y, z, lean in spine:
        mtx = frame((y, z), lean)
        rings.append([mtx @ Vector((x, d, 0.0)) for x, d in section])
    body_mag = loft("MagBody", rings, m["magalu"])
    smooth(body_mag, 40)
    mag.append(body_mag)
    fy_, fz_, flean = spine[-1]
    foot = frame((fy_, fz_), flean)
    if ROUND < 5:
        plate = box("FloorPlate", (-MAG_W - 0.0012, -0.0335, -0.0062), (MAG_W + 0.0012, 0.0345, 0.0008), m["magalu"], bevel=0.0018)
    else:
        # (Round 5) the black polymer floor plate, slim, hardly wider than the body.
        plate = box("FloorPlate", (-MAG_W - 0.0009, -0.033, -0.0056), (MAG_W + 0.0009, 0.0338, 0.0006), m["polymer"], bevel=0.0016)
    plate.data.transform(foot)
    smooth(plate, 35)
    mag.append(plate)
    if ROUND >= 2:
        # The floor plate's tab at the back that its catch locks behind.
        tab = box("Tab", (-0.0055, -0.036, -0.0055), (0.0055, -0.030, -0.0005), m["magalu" if ROUND < 5 else "polymer"], bevel=0.0012)
        tab.data.transform(foot)
        mag.append(tab)
        # The feed lips, and the top round between them: 5.56 x 45, green tip.
        for side in (-1.0, 1.0):
            mag.append(box("Lip", (side * (MAG_W - 0.0008) - 0.0007, MAG_Y[0] + 0.002, MAG_TOP - 0.003), (side * (MAG_W - 0.0008) + 0.0007, MAG_Y[0] + 0.040, MAG_TOP + 0.003), m["magalu"]))
        x0, zr, y0 = 0.0028, MAG_TOP + 0.0006, MAG_Y[0] + 0.003
        mag.append(cylinder("Case", (x0, y0, zr), (x0, y0 + 0.036, zr), 0.0048, m["brass"], 16))
        mag.append(cone("Shoulder", (x0, y0 + 0.036, zr), (x0, y0 + 0.0395, zr), 0.0048, 0.0032, m["brass"], 16))
        mag.append(cylinder("Neck", (x0, y0 + 0.0395, zr), (x0, y0 + 0.0445, zr), 0.0032, m["brass"], 16))
        mag.append(cone("Bullet", (x0, y0 + 0.0445, zr), (x0, y0 + 0.054, zr), 0.0029, 0.0016, m["copper"], 16))
        mag.append(cone("Tip", (x0, y0 + 0.054, zr), (x0, y0 + 0.0575, zr), 0.0016, 0.0003, m["green"], 16))
        # The next round under it, to the other side.
        mag.append(cylinder("Case2", (-x0, y0 + 0.001, zr - 0.0068), (-x0, y0 + 0.037, zr - 0.0068), 0.0048, m["brass"], 16))
    if ROUND >= 3:
        # Pressed marks on the floor plate's foot, and the maker's letters on the left side.
        mag.append(engrave_left("CAL 5.56MM", Vector((-MAG_W - 0.0009, 0.1535, 0.022)), 0.0042, m["marking"]))
    # --- markings, rail numbers, QD cups (round 3)
    if ROUND >= 3:
        body.append(engrave_left("M4A4 CARBINE", Vector((-LOW_W - 0.00015, 0.1785, 0.0745)), 0.0050, m["marking"]))
        body.append(engrave_left("CAL 5.56 MM", Vector((-LOW_W - 0.00015, 0.1785, 0.0665)), 0.0040, m["marking"]))
        body.append(engrave_left("NW-M4 041732", Vector((-LOW_W - 0.00015, 0.1785, 0.0595)), 0.0034, m["marking"]))
        body.append(engrave_left("SAFE", Vector((-LOW_R - 0.00015, 0.032, 0.0825)), 0.0030, m["white"]))
        body.append(engrave_left("SEMI", Vector((-LOW_R - 0.00015, 0.0175, 0.0925)), 0.0030, m["white"]))
        body.append(engrave_left("AUTO", Vector((-LOW_R - 0.00015, 0.0010, 0.0722)), 0.0030, m["white"]))
        body.append(engrave_right("NW", Vector((LOW_W + 0.00015, 0.155, 0.072)), 0.0060, m["marking"]))
        for k, y in enumerate(teeth):
            if k % 2 == 0:
                body.append(engrave_top(str(k + 1), Vector((0.0, y, RAIL_TOP + 0.00005)), 0.0026, m["marking"]))
        # The ring of the receiver's back pin (for a single-point sling) and a cup on the right
        # of the handguard's back.
        cup = cylinder("QD", (0.0165, -0.0283, 0.118), (0.0205, -0.0283, 0.118), 0.0058, m["steel"], 20, bevel=0.0008)
        cut(cup, cylinder("qd", (0.018, -0.0283, 0.118), (0.03, -0.0283, 0.118), 0.0036, m["steel"], 16))
        body.append(cup)
    return body, mag, trig


# ------------------------------------------------------------------ bake
def bake(objs, prefix="m4a4"):
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


def final_material(images, name="m4a4"):
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


# ------------------------------------------------------------------ review pictures
CENTRE = (0.0, 0.19, 0.075)
FLOOR = (0.0, 0.19, -0.09)
VIEWS = [
    # name, camera, target, lens (mm)
    ("schraeg", (-0.95, 1.05, 0.48), (0.0, 0.17, 0.07), 50),
    ("links", (-1.55, 0.19, 0.09), CENTRE, 55),
    ("rechts", (1.55, 0.19, 0.09), CENTRE, 55),
    ("hinten_schraeg", (0.55, -0.75, 0.42), (0.0, 0.12, 0.10), 50),
    ("oben", (0.0, 0.19, 1.7), (0.0, 0.19, 0.0), 55),
    ("unten", (-0.5, 0.25, -1.0), (0.0, 0.17, 0.05), 50),
    ("nah_receiver", (0.34, -0.06, 0.26), (0.0, 0.08, 0.11), 50),
    ("nah_vorn", (-0.30, 0.78, 0.20), (0.0, 0.46, 0.13), 50),
    ("nah_links", (-0.34, 0.02, 0.16), (0.0, 0.11, 0.08), 50),
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
    body_parts, mag_parts, trigger_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(mag_parts, "Magazine")
    trigger = join(trigger_parts, "Trigger")
    sights = join(SIGHTS, "Sights")
    parts = (body, magazine, trigger, sights)
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
        bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.003, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        images = bake(list(parts), "m4a4")
        final = final_material(images, "m4a4")
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    # The moving parts move about their own places.
    mag_origin = ((MAG_Y[0] + MAG_Y[1]) * 0.5, MAG_TOP)
    place_origin(magazine, (0.0, mag_origin[0], mag_origin[1]))
    place_origin(trigger, TRIGGER_PIVOT)
    root = link(bpy.data.objects.new("M4A4", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "magazine", triangles(magazine), "sights", triangles(sights), "trigger", triangles(trigger),
          "all", sum(triangles(o) for o in parts), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    spine = mag_spine()
    fy, fz, flean = spine[-1]
    foot = frame((fy, fz), flean) @ Vector((0.0, -0.030, -0.006))
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % 0.0112, "rail %.4f irons %.4f" % (RAIL_TOP, IRONS), "rear sight y %.4f front %.4f" % SIGHT_Y)
    print("SPEC handle(catch)", godot(CATCH), "trigger", godot(TRIGGER_PIVOT), "magazine", godot((0.0, mag_origin[0], mag_origin[1])), "support", godot(SUPPORT))
    print("SPEC magazine_foot", godot(foot), "eject", godot((UP_W + 0.004, (PORT_Y[0] + PORT_Y[1]) * 0.5, BORE_Z)))
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
