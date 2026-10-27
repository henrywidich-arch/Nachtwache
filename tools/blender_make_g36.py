# Builds the G36 for Nachtwache, from nothing (it replaces the supplied mesh g36.glb, which
# stays in the folder unused): a modern G36K-style carbine after Henry's reference picture
# (Nachtwache-Waffen/Referenz/g36_referenz.png). A black polymer receiver; a long handguard
# with M-LOK slots in rows, a rail along its top, a short side rail at its front, a rail
# below for the vertical grip and a weapon light; a slim carry handle with a rail on top
# (sights are attachments of the game and clamp to it) and the iron sights inside it - a
# post between the cheeks of the handle's front strut, a ghost ring in a window at its back; a short
# slotted flash hider; a translucent smoke magazine with the brass rounds seen through it;
# a stippled pistol grip, a fire selector marked in red; an olive skeleton stock that
# folds at a black hinge, with a black rubber pad, a QD socket and a sling loop.
# Every part is made here, bevelled, given its material, UV-unwrapped and baked into one
# texture set (base colour, roughness and metal, normal); the magazine's shell keeps a
# material of its own that lets the light through. Written as a GLB with the nodes
#   G36 > Body / Magazine (origin: the middle of its top; the translucent "Shell" under it)
#         / Sights (the post and the ghost ring: the iron sights in the carry handle)
#
#   blender --background --factory-startup --python tools/blender_make_g36.py -- [--round 4] [--tex 2048]
#           [--out assets/models/g36_built.glb] [--render <folder> --prefix g36_r1] [--only links,visier] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
# --render: fixed views (studio light and dark in-game light).
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the top of the pistol grip. Most outlines are taken from the reference picture: Y(px) and
# Z(py) turn its pixels (it shows the left side, muzzle to the left) into metres, 0.52 mm a
# pixel, which makes the carbine 74 cm long. The glTF exporter turns this into Godot space
# (barrel along -Z, up +Y). The places the game needs (GUNS["g36"] in weapon_view.gd) are
# printed.
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
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "g36_built.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "g36_r%d" % ROUND)
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


def ring(name, centre, axis, major, minor, material, segments=24):
    """A torus round `axis` ('X', 'Y' or 'Z') through `centre`."""
    rot = {"X": (0.0, math.pi / 2.0, 0.0), "Y": (math.pi / 2.0, 0.0, 0.0), "Z": (0.0, 0.0, 0.0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segments, minor_segments=8, location=centre, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(material)
    smooth(obj, 60)
    return obj


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


def cut_all(obj, cutters):
    """Cuts many (not overlapping) cutters out at once: one boolean instead of many."""
    if not cutters:
        return
    cut(obj, join(cutters, "cutters") if len(cutters) > 1 else cutters[0])


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


def smooth(obj, angle=30.0):
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.set_sharp_from_angle(angle=math.radians(angle))
    if ROUND >= 4 and len(obj.data.polygons) > 12:
        # Normals weighted by face area: the big flat sides stay flat instead of taking a
        # shading gradient from their bevelled rims.
        mod = obj.modifiers.new("Weighted", "WEIGHTED_NORMAL")
        mod.mode = "FACE_AREA"
        mod.keep_sharp = True
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


# ------------------------------------------------------------------ materials (procedural, baked later)
def material(name, base, rough, metal, wear=0.0, grime=0.0, bump=0.0, bump_scale=900.0, stipple=False, worn=(0.3, 0.3, 0.3), scratch=0.0):
    """`base` colour with a little noise in it, edges rubbed to `worn` (wear 0..1), grime in
    the hollows, fine scratches (scratch 0..1) in the worn colour, an optional fine bump
    (stipple, or a brushed grain)."""
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
    spread = 0.14 if ROUND == 1 else 0.12
    colour.inputs[6].default_value = (*[c * (1.0 - spread) for c in base], 1.0)
    colour.inputs[7].default_value = (*[min(1.0, c * (1.0 + spread)) for c in base], 1.0)
    links.new(noise.outputs["Fac"], colour.inputs[0])
    out_colour = colour.outputs[2]
    if ROUND >= 2:
        # Large, faint blotches: the polymer is a little lighter where hands have rubbed it.
        blotch = nodes.new("ShaderNodeTexNoise")
        blotch.inputs["Scale"].default_value = 18.0
        blotch.inputs["Detail"].default_value = 3.0
        links.new(coords.outputs["Object"], blotch.inputs["Vector"])
        bmix = nodes.new("ShaderNodeMix")
        bmix.data_type = "RGBA"
        bmix.inputs[0].default_value = 0.0
        bfac = nodes.new("ShaderNodeMapRange")
        bfac.inputs[1].default_value = 0.45
        bfac.inputs[2].default_value = 0.75
        bfac.inputs[4].default_value = 0.35
        links.new(blotch.outputs["Fac"], bfac.inputs[0])
        links.new(bfac.outputs[0], bmix.inputs[0])
        links.new(out_colour, bmix.inputs[6])
        bmix.inputs[7].default_value = (*[min(1.0, c * 1.45 + 0.004) for c in base], 1.0)
        out_colour = bmix.outputs[2]
    rough_node = nodes.new("ShaderNodeMath")
    rough_node.operation = "MULTIPLY_ADD"
    rough_node.inputs[1].default_value = 0.16
    rough_node.inputs[2].default_value = rough - 0.08
    links.new(noise.outputs["Fac"], rough_node.inputs[0])
    out_rough = rough_node.outputs[0]
    metal_node = nodes.new("ShaderNodeValue")
    metal_node.outputs[0].default_value = metal
    out_metal = metal_node.outputs[0]
    if scratch > 0.0 and ROUND >= 3:
        # Scratches: the contour lines of stretched noise, thin and wandering, mostly along
        # the gun and a few across, shown only in patches. (Drawn first along the edges of
        # Voronoi cells, they came out as a net of cracks.)
        line = None
        for scale, rot, size in (((7.0, 0.45, 7.0), (0.0, 0.0, 0.0), 15.0), ((0.7, 6.0, 5.0), (0.4, 0.0, 0.7), 12.0)):
            mapping = nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = scale
            mapping.inputs["Rotation"].default_value = rot
            links.new(coords.outputs["Object"], mapping.inputs["Vector"])
            wander = nodes.new("ShaderNodeTexNoise")
            wander.inputs["Scale"].default_value = size
            wander.inputs["Detail"].default_value = 0.0
            links.new(mapping.outputs["Vector"], wander.inputs["Vector"])
            centred = nodes.new("ShaderNodeMath")
            centred.operation = "SUBTRACT"
            centred.inputs[1].default_value = 0.5
            links.new(wander.outputs["Fac"], centred.inputs[0])
            far = nodes.new("ShaderNodeMath")
            far.operation = "ABSOLUTE"
            links.new(centred.outputs[0], far.inputs[0])
            thin = nodes.new("ShaderNodeMapRange")
            thin.inputs[1].default_value = 0.0
            thin.inputs[2].default_value = 0.0035
            thin.inputs[3].default_value = 1.0
            thin.inputs[4].default_value = 0.0
            links.new(far.outputs[0], thin.inputs[0])
            if line is None:
                line = thin
            else:
                both = nodes.new("ShaderNodeMath")
                both.operation = "MAXIMUM"
                links.new(line.outputs[0], both.inputs[0])
                links.new(thin.outputs[0], both.inputs[1])
                line = both
        patches = nodes.new("ShaderNodeTexNoise")
        patches.inputs["Scale"].default_value = 9.0
        links.new(coords.outputs["Object"], patches.inputs["Vector"])
        where = nodes.new("ShaderNodeMapRange")
        where.inputs[1].default_value = 0.52
        where.inputs[2].default_value = 0.68
        links.new(patches.outputs["Fac"], where.inputs[0])
        amount = nodes.new("ShaderNodeMath")
        amount.operation = "MULTIPLY"
        links.new(line.outputs[0], amount.inputs[0])
        links.new(where.outputs[0], amount.inputs[1])
        amount2 = nodes.new("ShaderNodeMath")
        amount2.operation = "MULTIPLY"
        amount2.inputs[1].default_value = scratch
        links.new(amount.outputs[0], amount2.inputs[0])
        smix = nodes.new("ShaderNodeMix")
        smix.data_type = "RGBA"
        links.new(amount2.outputs[0], smix.inputs[0])
        links.new(out_colour, smix.inputs[6])
        smix.inputs[7].default_value = (*worn, 1.0)
        out_colour = smix.outputs[2]
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
    mat = bpy.data.materials.new("g36_magazine_shell")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tint = (0.105, 0.095, 0.08) if ROUND < 4 else (0.1, 0.09, 0.075)
    bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Alpha"].default_value = 0.5 if ROUND < 4 else 0.55
    try:
        mat.surface_render_method = "BLENDED"
    except Exception:
        mat.blend_method = "BLEND"
    mat.use_backface_culling = False
    mat.diffuse_color = (*tint, bsdf.inputs["Alpha"].default_value)
    return mat


def make_materials():
    wear = {1: 0.0, 2: 0.45, 3: 0.85}.get(ROUND, 0.95)
    g2 = ROUND >= 2
    polymer = material("polymer", (0.030, 0.031, 0.034), 0.6, 0.0, wear=0.4 * wear, grime=0.75 if g2 else 0.0, bump=0.07 if ROUND >= 3 else 0.0, bump_scale=2600.0, stipple=True, worn=(0.13, 0.135, 0.14), scratch=0.6)
    # The handguard: hard-anodised aluminium, dark grey, its edges and its flats scratched
    # down to the bright metal.
    alu = material("alu", (0.045, 0.047, 0.05), 0.48, 0.55, wear=0.9 * wear, grime=0.6 if g2 else 0.0, worn=(0.36, 0.36, 0.37), scratch=0.9)
    od = material("od", (0.068, 0.072, 0.046), 0.7, 0.0, wear=0.5 * wear, grime=0.7 if g2 else 0.0, bump=0.05 if ROUND >= 3 else 0.0, bump_scale=2400.0, stipple=True, worn=(0.2, 0.205, 0.16), scratch=0.7)
    grip = material("grip", (0.032, 0.033, 0.036), 0.86, 0.0, wear=0.25 * wear, grime=0.8 if g2 else 0.0, bump=0.0 if ROUND < 3 else 0.9, bump_scale=1900.0, stipple=True, worn=(0.10, 0.105, 0.11)) if ROUND >= 3 else polymer
    steel = material("steel", (0.03, 0.031, 0.034), 0.42, 0.85, wear=0.75 * wear, grime=0.5 if g2 else 0.0, worn=(0.38, 0.38, 0.39))
    dark = material("dark", (0.006, 0.006, 0.007), 0.85, 0.0)
    rubber = material("rubber", (0.02, 0.02, 0.022), 0.9, 0.0, grime=0.4 if g2 else 0.0, bump=0.0 if ROUND < 3 else 0.5, bump_scale=900.0, stipple=True)
    brass = material("brass", (0.62, 0.45, 0.19), 0.32, 1.0, grime=0.25)
    copper = material("copper", (0.52, 0.29, 0.16), 0.34, 1.0, grime=0.2)
    marking = material("marking", (0.42, 0.43, 0.44), 0.6, 0.0) if ROUND >= 3 else polymer
    white = material("white", (0.62, 0.62, 0.6), 0.55, 0.0) if ROUND >= 3 else polymer
    red = material("red", (0.55, 0.04, 0.025), 0.5, 0.0) if ROUND >= 3 else polymer
    lens = material("lens", (0.55, 0.56, 0.55), 0.08, 1.0)
    magblack = material("magblack", (0.022, 0.023, 0.025), 0.55, 0.0, wear=0.35 * wear, grime=0.6 if g2 else 0.0, worn=(0.1, 0.1, 0.105))
    return {"polymer": polymer, "alu": alu, "od": od, "grip": grip, "steel": steel, "dark": dark, "rubber": rubber, "brass": brass, "copper": copper,
            "marking": marking, "white": white, "red": red, "lens": lens, "magblack": magblack, "shell": shell_material()}


# ------------------------------------------------------------------ the measures
PIX = 0.00052                    # metres per pixel of the reference picture
ORIGIN_PX = (990.0, 522.0)       # the middle of the top of the pistol grip in the picture


def Y(px):
    return (ORIGIN_PX[0] - px) * PIX


def Z(py):
    return (ORIGIN_PX[1] - py) * PIX


def PX(points):
    """Reference pixels (px, py, fillet radius in metres) -> (y, z, r)."""
    return [(Y(a), Z(b), r) for a, b, r in points]


BORE_Z = Z(405)                  # the bore axis
MUZZLE_Y = Y(10)                 # the face of the flash hider: 74 cm over all
HIDER_Y = Y(118)
BORE_R = 0.0028
HG_Y = (Y(712), Y(172))          # the handguard, from its back (inside the receiver) to its face
HG_W = 0.0245                    # half its width
HG_TOP = Z(340)
HG_BOT = Z(462)
HG_CH = 0.0075                   # its corners taken off
REC_W = 0.0215                   # half the width of the receiver
REC_TOP = Z(350)
REC_BOT = Z(498)
BAR_TOP = 0.1255                 # the carry handle's bar, under its rail
BAR_BOT = 0.1165
HANDLE_RAIL = 0.133              # the top of the rail on the carry handle: sights clamp here
HANDLE_W = 0.0106
IRONS = 0.104                    # the iron sights' line, through the handle
REAR_SIGHT_Y = Y(1022)           # the ghost ring at the back of the handle
FRONT_POST_Y = 0.2365            # the post between the cheeks of the front strut
HG_RAIL = 0.1005                 # the top of the handguard's rail (under the sight line)
MAG_TOP = Vector((0.0, Y(771), -0.0068))   # the middle of the magazine's top
MAG_TILT = math.radians(8.5)     # its foot forward
MAG_LEN = 0.157                  # down its spine
MAG_HALF = 0.0355                # half its depth (front to back)
MAG_W = 0.0125                   # half its thickness
ROUNDS = 26                      # seen through the shell (the rest are up in the well)
SUPPORT = Vector((0.0, 0.300, 0.008))      # the top of the vertical grip
HANDLE = Vector((-0.022, 0.173, 0.0975))   # the charging handle's knob, folded out to the left
SELECTOR = Vector((-REC_W, Y(962), Z(489)))
PORT = Vector((REC_W, 0.117, 0.0725))      # the ejection port on the right


def mag_bend(co):
    """Local magazine space (origin at the middle of its top, -z down its spine) -> model
    space: a gentle forward curve towards the foot, then tilted and put in the well."""
    co = Vector(co)
    co.y += 0.22 * co.z * co.z
    return Matrix.Translation(MAG_TOP) @ Matrix.Rotation(MAG_TILT, 4, "X") @ co


def mag_place(obj):
    for v in obj.data.vertices:
        v.co = mag_bend(v.co)
    obj.data.update()
    return obj


def rail(name, y0, y1, z_base, z_top, half, mat, pitch=0.010):
    """A Picatinny rail standing on z_base: a narrower neck along its whole length and the
    head (chamfered sides overhanging the neck) as teeth every centimetre, so the cross
    slots are real gaps."""
    neck_half = half - 0.0022
    head_low = z_top - 0.0042
    parts = [prism(name + "Neck", [(-neck_half, z_base), (neck_half, z_base), (neck_half, z_top - 0.0028), (-neck_half, z_top - 0.0028)], y0, y1, mat)]
    head = [(-half, head_low), (half, head_low), (half, z_top - 0.0016), (half - 0.0016, z_top), (-half + 0.0016, z_top), (-half, z_top - 0.0016)]
    if ROUND < 2:
        parts.append(prism(name, head, y0, y1, mat))
    else:
        n = max(1, int((y1 - y0 + 0.0047) / pitch))
        start = y0 + ((y1 - y0) - ((n - 1) * pitch + 0.0053)) * 0.5
        for i in range(n):
            parts.append(prism(name + "Tooth", head, start + i * pitch, start + i * pitch + 0.0053, mat))
    obj = join(parts, name)
    if ROUND >= 2:
        bevel_object(obj, 0.00035, 1, 40.0)
    smooth(obj, 30)
    return obj


def side_rail(name, y0, y1, zc, side, mat):
    """A short rail on the side of the handguard: built upright, then laid on its side."""
    r = rail(name, y0, y1, 0.0, 0.0085, 0.0106 if ROUND >= 2 else 0.009, mat)
    r.data.transform(Matrix.Translation((side * (HG_W - 0.001), 0.0, zc)) @ Matrix.Rotation(side * math.pi / 2.0, 4, "Y"))
    return r


def slot_cutter(y0, y1, h, x0, x1, n=5):
    """An M-LOK slot: a long hole with round ends, from x0 to x1."""
    r = h * 0.5 * 0.98
    return slab("slot", fillet([(y0, -h / 2, r), (y1, -h / 2, r), (y1, h / 2, r), (y0, h / 2, r)], n), x0, x1, None)


def hg_profile(inset=0.0):
    """The handguard's cross-section: a box with its four long corners taken off."""
    w, t, b, c = HG_W - inset, HG_TOP - inset, HG_BOT + inset, HG_CH
    return [(w, b + c), (w, t - c), (w - c, t), (-w + c, t), (-w, t - c), (-w, b + c), (-w + c, b), (w - c, b)]


def build(m):
    body, mag, sights, shell = [], [], [], []
    g2, g3, g4 = ROUND >= 2, ROUND >= 3, ROUND >= 4

    # --- the receiver: upper and lower in one, its front cut on the slant where the
    # handguard comes out of it
    rec_outline = PX([(602, 350, 0.003), (1080, 350, 0.004), (1088, 360, 0.003), (1088, 498, 0.004), (705, 498, 0.003), (628, 372, 0.003)])
    receiver = slab("Receiver", fillet(rec_outline, 6), -REC_W, REC_W, m["polymer"])
    if g2:
        cuts = []
        for side in (-1.0, 1.0):
            # The seam between the upper and the lower half, and the stock hinge's seam.
            cuts.append(box("seam", (side * REC_W - 0.0008, Y(1086), Z(491) - 0.0004), (side * REC_W + 0.0008, Y(706), Z(491) + 0.0004), None))
            # A shallow panel on the side, behind the markings.
            cuts.append(box("panel", (side * REC_W - 0.0007, Y(1000), Z(442)), (side * REC_W + 0.0007, Y(900), Z(414)), None, bevel=0.0004))
        # The ejection port on the right.
        cuts.append(box("port", (REC_W - 0.004, PORT.y - 0.023, PORT.z - 0.0068), (REC_W + 0.01, PORT.y + 0.023, PORT.z + 0.0068), None, bevel=0.0015))
        if g4:
            # The long top edges taken off at 45 degrees, as on the real receiver: the flat
            # slab looked like a box from above.
            for side in (-1.0, 1.0):
                c = box("chamfer", (-0.0027, Y(1100), -0.0027), (0.0027, Y(580), 0.0027), None)
                c.data.transform(Matrix.Translation((side * REC_W, 0.0, REC_TOP)) @ Matrix.Rotation(math.pi / 4.0, 4, "Y"))
                cuts.append(c)
        cut_all(receiver, cuts)
    bevel_object(receiver, 0.0022 if g2 else 0.003, 2, 35.0)
    smooth(receiver, 35)
    body.append(receiver)
    if g2:
        # Inside the port: dark, the bolt's face in it; the case deflector behind it.
        body.append(box("PortInside", (REC_W - 0.0036, PORT.y - 0.022, PORT.z - 0.006), (REC_W - 0.0030, PORT.y + 0.022, PORT.z + 0.006), m["dark"]))
        body.append(box("BoltFace", (REC_W - 0.0033, PORT.y - 0.016, PORT.z - 0.0045), (REC_W - 0.0026, PORT.y + 0.004, PORT.z + 0.0045), m["steel"], bevel=0.0006))
        defl = box("Deflector", (REC_W - 0.002, PORT.y - 0.032, PORT.z - 0.010), (REC_W + 0.0042, PORT.y - 0.0245, PORT.z + 0.011), m["polymer"], bevel=0.0015)
        smooth(defl, 35)
        body.append(defl)
    # The lower receiver round the magazine well, the trigger guard, the pistol grip.
    well = slab("Well", fillet(PX([(680, 492, 0.0), (862, 492, 0.0), (862, 556, 0.004), (852, 566, 0.003), (690, 566, 0.003), (678, 554, 0.004)]), 5), -0.0168, 0.0168, m["polymer"])
    if g2:
        hole = box("maghole", (-MAG_W - 0.0006, -MAG_HALF - 0.0008, -0.06), (MAG_W + 0.0006, MAG_HALF + 0.0008, 0.012), None)
        mag_place(hole)
        cut(well, hole)
    bevel_object(well, 0.0025, 2, 35.0)
    smooth(well, 35)
    body.append(well)
    guard = slab("Guard", fillet(PX([(846, 496, 0.0), (958, 496, 0.0), (960, 548, 0.012), (936, 594, 0.008), (852, 596, 0.006)]), 6), -0.0075, 0.0075, m["polymer"])
    cut(guard, slab("gh", fillet(PX([(858, 498, 0.0), (946, 498, 0.0), (946, 545, 0.01), (928, 583, 0.006), (862, 584, 0.005)]), 6), -0.02, 0.02, None))
    bevel_object(guard, 0.0022, 2, 35.0)
    smooth(guard, 40)
    body.append(guard)
    trigger = slab("Trigger", fillet(PX([(898, 497, 0.0), (909, 497, 0.0), (913, 528, 0.008), (906, 560, 0.006), (897, 574, 0.002), (893, 566, 0.002), (899, 545, 0.006), (900, 520, 0.0)]), 5), -0.003, 0.003, m["steel"])
    bevel_object(trigger, 0.0009, 1, 35.0)
    smooth(trigger, 40)
    body.append(trigger)
    grip_outline = PX([(944, 496, 0.0), (1042, 496, 0.0), (1066, 566, 0.012), (1106, 688, 0.012), (1104, 732, 0.01), (1006, 740, 0.01), (994, 716, 0.006), (956, 582, 0.02)])
    pgrip = slab("PistolGrip", fillet(grip_outline, 6), -0.0148, 0.0148, m["polymer"])
    if g3:
        # Ribs across the front strap.
        ribs = []
        for k in range(9):
            t = 0.12 + k * 0.085
            a = Vector((Y(958), Z(585))).lerp(Vector((Y(996), Z(712))), t)
            r = box("rib", (-0.02, a.x - 0.0013, a.y - 0.0016), (0.02, a.x + 0.0026, a.y + 0.0016), None)
            rotate(r, math.radians(-17.0), "X", Vector((0.0, a.x, a.y)))
            ribs.append(r)
        cut_all(pgrip, ribs)
    bevel_object(pgrip, 0.0045 if g2 else 0.005, 3, 30.0)
    smooth(pgrip, 38)
    body.append(pgrip)
    if g3:
        # Stippled panels on both sides of the grip.
        panel = fillet(PX([(990, 566, 0.006), (1066, 572, 0.008), (1096, 690, 0.008), (1086, 704, 0.006), (1012, 706, 0.008)]), 5)
        for side in (-1.0, 1.0):
            p = slab("GripPanel", panel, side * 0.0146, side * 0.0156, m["grip"])
            bevel_object(p, 0.0005, 1, 40.0)
            body.append(p)

    # --- the handguard: hollow, slotted, the barrel and the gas tube seen through its slots
    hg = prism("Handguard", hg_profile(), HG_Y[0], HG_Y[1], m["alu"])
    bevel_object(hg, 0.0022, 2, 30.0)
    if g2:
        cut(hg, prism("hollow", hg_profile(0.0032), HG_Y[0] - 0.01, HG_Y[1] - 0.0045, None))
        cut(hg, cylinder("front", (0, HG_Y[1] - 0.02, BORE_Z), (0, HG_Y[1] + 0.02, BORE_Z), 0.0098, None, 32))
        slots = []
        # Two rows along the side, one along each chamfer (pixels of the picture).
        rows = [(372, [(214, 262), (280, 340), (358, 420), (438, 500)]),
                (416, [(336, 390), (402, 456), (468, 522)])]
        for py, spans in rows:
            for a, b in spans:
                s = slot_cutter(Y(b), Y(a), 0.0072, -0.04, 0.04)
                move(s, (0.0, 0.0, Z(py)))
                slots.append(s)
        if g3:
            for zc_sign, spans in ((1.0, [(275, 348), (356, 420), (434, 498)]), (-1.0, [(214, 262), (268, 322), (332, 390), (400, 446), (466, 520)])):
                for side in (-1.0, 1.0):
                    for a, b in spans:
                        s = slot_cutter(Y(b), Y(a), 0.0046, -0.004, 0.004)
                        # Laid in the chamfer: turned 45 degrees about the length.
                        cx = side * (HG_W - HG_CH * 0.5)
                        cz = (HG_TOP - HG_CH * 0.5) if zc_sign > 0 else (HG_BOT + HG_CH * 0.5)
                        s.data.transform(Matrix.Translation((cx, 0.0, cz)) @ Matrix.Rotation(-side * zc_sign * math.pi / 4.0, 4, "Y"))
                        slots.append(s)
        cut_all(hg, slots)
        # Its back end on the slant of the receiver's front.
        slant = box("slant", (-0.05, -0.3, -0.2), (0.05, 0.0, 0.3), None)
        slant.data.transform(Matrix.Translation((0.0, Y(628) - 0.0015, Z(372))) @ Matrix.Rotation(math.radians(-31.4), 4, "X"))
        cut(hg, slant)
        bevel_object(hg, 0.0006, 1, 50.0)
    smooth(hg, 35)
    body.append(hg)
    if g2:
        body.append(cylinder("GasTube", (0, HG_Y[0], BORE_Z + 0.0158), (0, HG_Y[1] - 0.008, BORE_Z + 0.0158), 0.0042, m["steel"], 18))
        body.append(box("GasBlock", (-0.0105, 0.395, BORE_Z - 0.008), (0.0105, 0.415, BORE_Z + 0.0215), m["steel"], bevel=0.0015))
        # Dark liners inside the roof and the floor, as deep as the chamfers: through the
        # chamfer slots of one side one saw out of those of the other.
        body.append(box("HGRoof", (-HG_W + 0.0045, HG_Y[0] + 0.03, HG_TOP - 0.0088), (HG_W - 0.0045, HG_Y[1] - 0.006, HG_TOP - 0.0034), m["dark"]))
        body.append(box("HGFloor", (-HG_W + 0.0045, HG_Y[0] + 0.03, HG_BOT + 0.0034), (HG_W - 0.0045, HG_Y[1] - 0.006, HG_BOT + 0.0088), m["dark"]))
    # The rails: along its top, under it for the grip and the light, a short one each side.
    body.append(rail("TopRail", Y(530), Y(176), HG_TOP - 0.001, HG_RAIL, 0.0106, m["alu"]))
    body.append(rail("GripRail", Y(622), Y(330), 0.0, 0.0105, 0.0106, m["alu"]))
    body[-1].data.transform(Matrix.Translation((0.0, 0.0, HG_BOT + 0.001)) @ Matrix.Rotation(math.pi, 4, "Y"))
    if g2:
        body.append(rail("LightRail", Y(302), Y(206), 0.0, 0.0105, 0.0106, m["alu"]))
        body[-1].data.transform(Matrix.Translation((0.0, 0.0, HG_BOT + 0.001)) @ Matrix.Rotation(math.pi, 4, "Y"))
        for side in (-1.0, 1.0):
            body.append(side_rail("SideRail", Y(326), Y(210), Z(408), side, m["alu"]))
        # The end cap at its face, round the barrel.
        cap = cylinder("Nut", (0, HG_Y[1] - 0.002, BORE_Z), (0, HG_Y[1] + 0.0065, BORE_Z), 0.0112, m["steel"], 32, bevel=0.0012)
        body.append(cap)
    # The folded front sight at the front of the top rail: laid flat, clear of the sight line.
    fs = box("FoldedSight", (-0.0085, Y(250), HG_RAIL - 0.0005), (0.0085, Y(198), HG_RAIL + 0.0022), m["polymer"], bevel=0.0008)
    body.append(fs)
    if g3:
        body.append(cylinder("FSHinge", (-0.0092, Y(204), HG_RAIL + 0.0004), (0.0092, Y(204), HG_RAIL + 0.0004), 0.0021, m["steel"], 14))

    # --- the barrel and the flash hider
    body.append(cylinder("Barrel", (0, HG_Y[0], BORE_Z), (0, HIDER_Y + 0.004, BORE_Z), 0.0078 if g2 else 0.008, m["steel"], 28))
    hider = cylinder("Hider", (0, HIDER_Y, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.0108, m["steel"], 32, bevel=0.0012 if g2 else 0.0)
    cut(hider, cylinder("bore", (0, HIDER_Y + 0.008, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0074 if g2 else BORE_R, None, 28))
    if g2:
        slots = []
        for k in range(6):
            a = math.tau * (k + 0.5) / 6.0
            s = slab("slot", fillet([(MUZZLE_Y - 0.033, -0.0021, 0.002), (MUZZLE_Y - 0.0035, -0.0021, 0.0), (MUZZLE_Y - 0.0035, 0.0021, 0.0), (MUZZLE_Y - 0.033, 0.0021, 0.002)], 4), 0.004, 0.02, None)
            s.data.transform(Matrix.Translation((0, 0, BORE_Z)) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Rotation(math.pi / 2.0, 4, "Y"))
            slots.append(s)
        cut_all(hider, slots)
    smooth(hider, 35)
    body.append(hider)
    if g2:
        # The ring at its back with flats for a spanner, and the bore deep inside.
        collar = cylinder("HiderCollar", (0, HIDER_Y - 0.0012, BORE_Z), (0, HIDER_Y + 0.0085, BORE_Z), 0.0118, m["steel"], 32, bevel=0.001)
        for side in (-1.0, 1.0):
            cut(collar, box("flat", (side * 0.0108, HIDER_Y - 0.01, BORE_Z - 0.02), (side * 0.03, HIDER_Y + 0.02, BORE_Z + 0.02), None))
        smooth(collar, 35)
        body.append(collar)
        body.append(cylinder("BoreDeep", (0, HIDER_Y + 0.006, BORE_Z), (0, HIDER_Y + 0.0075, BORE_Z), 0.0074, m["dark"], 24))
        body.append(cylinder("Muzzle", (0, HIDER_Y + 0.0076, BORE_Z), (0, HIDER_Y + 0.012, BORE_Z), 0.0074, m["steel"], 24))
        body.append(cylinder("MuzzleBore", (0, HIDER_Y + 0.0119, BORE_Z), (0, HIDER_Y + 0.0123, BORE_Z), BORE_R, m["dark"], 16))

    # --- the carry handle: the front strut (its cheeks guard the front post), the bar with its
    # rail, the block at its back that carries the ghost ring
    handle_outline = [(Y(494), HG_TOP - 0.0012, 0.002), (Y(556), BAR_TOP, 0.006), (Y(982), BAR_TOP, 0.0), (Y(982), BAR_BOT, 0.0),
                      (Y(584), BAR_BOT, 0.005), (Y(548), HG_TOP - 0.0012, 0.003)]
    handle = slab("CarryHandle", fillet(handle_outline, 6), -HANDLE_W, HANDLE_W, m["polymer"])
    # The strut is wider than the bar: its cheeks stand either side of the post.
    strut = slab("Strut", fillet([(Y(492), HG_TOP - 0.0012, 0.002), (Y(546), 0.1215, 0.005), (Y(574), 0.1215, 0.004), (Y(550), HG_TOP - 0.0012, 0.003)], 6), -0.0128, 0.0128, m["polymer"])
    # The strut is open in the middle: two cheeks and a roof over the post, the sight line
    # between them (a round hood through a solid strut hid most of what the ghost ring
    # framed: one saw the strut, not the target).
    for o in (strut, handle):
        cut(o, box("gap", (-0.0096, Y(610), HG_TOP - 0.006), (0.0096, Y(470), 0.1162), None))
    bevel_object(handle, 0.0016, 2, 35.0)
    bevel_object(strut, 0.0018, 2, 35.0)
    smooth(handle, 35)
    smooth(strut, 35)
    body.extend([handle, strut])
    rear = slab("RearBlock", fillet([(Y(958), REC_TOP - 0.001, 0.0), (Y(974), BAR_TOP, 0.003), (Y(1040), BAR_TOP, 0.004), (Y(1052), BAR_TOP - 0.008, 0.004), (Y(1052), REC_TOP - 0.001, 0.0)], 6), -0.0145, 0.0145, m["polymer"])
    # A window through it the eye looks along: the ghost ring stands in it between the two
    # side walls (a solid block round a peep hole filled half the picture when aiming).
    cut(rear, box("window", (-0.0106, Y(1070), REC_TOP + 0.0016), (0.0106, Y(940), BAR_BOT - 0.0004), None, bevel=0.0015 if g2 else 0.0))
    bevel_object(rear, 0.0016, 2, 35.0)
    smooth(rear, 35)
    body.append(rear)
    body.append(rail("HandleRail", Y(576), Y(1036), BAR_TOP - 0.001, HANDLE_RAIL, HANDLE_W, m["polymer"]))
    # The iron sights (node "Sights"): the post in the strut; the ghost ring on its stem, on
    # the axle of the knob that sets it.
    post = box("FrontPost", (-0.0012, FRONT_POST_Y - 0.0014, IRONS - 0.009), (0.0012, FRONT_POST_Y + 0.0014, IRONS), m["steel"], bevel=0.0004 if g2 else 0.0)
    sights.append(post)
    peep = cylinder("Peep", (0, REAR_SIGHT_Y - 0.0026, IRONS), (0, REAR_SIGHT_Y + 0.0026, IRONS), 0.0084, m["steel"], 36, bevel=0.0007 if g2 else 0.0)
    cut(peep, cylinder("hole", (0, REAR_SIGHT_Y - 0.03, IRONS), (0, REAR_SIGHT_Y + 0.03, IRONS), 0.006, None, 32))
    smooth(peep, 35)
    sights.append(peep)
    sights.append(box("PeepStem", (-0.0018, REAR_SIGHT_Y - 0.0022, REC_TOP), (0.0018, REAR_SIGHT_Y + 0.0022, IRONS - 0.0078), m["steel"], bevel=0.0005 if g2 else 0.0))
    sights.append(cylinder("Axle", (0.0074, REAR_SIGHT_Y, IRONS), (0.0146, REAR_SIGHT_Y, IRONS), 0.0018, m["steel"], 12))
    if g2:
        # The knob on the right, ribbed; the post's foot in the hood.
        knob = cylinder("SightKnob", (0.0142, REAR_SIGHT_Y, IRONS), (0.0192, REAR_SIGHT_Y, IRONS), 0.0068, m["polymer"], 28, bevel=0.001)
        sights.append(knob)
        sights.append(box("PostFoot", (-0.0035, FRONT_POST_Y - 0.003, IRONS - 0.0085), (0.0035, FRONT_POST_Y + 0.003, IRONS - 0.0062), m["steel"], bevel=0.0006))
    if g3:
        for k in range(14):
            a = math.tau * k / 14
            sights.append(box("kr", (0.0186, REAR_SIGHT_Y + math.cos(a) * 0.0068 - 0.0005, IRONS + math.sin(a) * 0.0068 - 0.0005), (0.0193, REAR_SIGHT_Y + math.cos(a) * 0.0068 + 0.0005, IRONS + math.sin(a) * 0.0068 + 0.0005), m["polymer"]))
        # A white dot on the post for dim light.
        sights.append(cylinder("PostDot", (0, FRONT_POST_Y - 0.0016, IRONS - 0.0032), (0, FRONT_POST_Y - 0.0012, IRONS - 0.0032), 0.0007, m["white"], 10))

    # --- on top of the receiver under the handle: the charging handle's track and its lever
    track = box("Track", (-0.0118, Y(866), REC_TOP - 0.001), (0.0118, Y(592), REC_TOP + 0.0048), m["polymer"], bevel=0.0012)
    smooth(track, 35)
    body.append(track)
    if g2:
        body.append(box("ChargerSlide", (-0.0062, HANDLE.y - 0.016, REC_TOP + 0.004), (0.0062, HANDLE.y + 0.012, REC_TOP + 0.0088), m["steel"], bevel=0.001))
        arm = box("ChargerArm", (HANDLE.x, HANDLE.y - 0.004, HANDLE.z - 0.0022), (-0.004, HANDLE.y + 0.004, HANDLE.z + 0.0018), m["polymer"], bevel=0.0009)
        body.append(arm)
        body.append(cylinder("ChargerKnob", (HANDLE.x, HANDLE.y, HANDLE.z - 0.005), (HANDLE.x, HANDLE.y, HANDLE.z + 0.004), 0.0042, m["polymer"], 18, bevel=0.0012))

    # --- the stock hinge and the olive skeleton stock, the rubber pad
    hinge = slab("Hinge", fillet(PX([(1084, 372, 0.003), (1176, 372, 0.004), (1176, 496, 0.004), (1084, 496, 0.004)]), 5), -0.0195, 0.0195, m["polymer"])
    bevel_object(hinge, 0.0022, 2, 35.0)
    smooth(hinge, 35)
    body.append(hinge)
    if g2:
        # The latch on its left that lets the stock fold: a loop on two pins.
        latch = slab("Latch", fillet(PX([(1086, 360, 0.004), (1108, 360, 0.004), (1108, 452, 0.004), (1086, 452, 0.004)]), 4), -0.0232, -0.0192, m["polymer"])
        cut(latch, slab("li", fillet(PX([(1092, 372, 0.002), (1102, 372, 0.002), (1102, 440, 0.002), (1092, 440, 0.002)]), 3), -0.03, 0.0, None))
        bevel_object(latch, 0.0008, 1, 35.0)
        smooth(latch, 35)
        body.append(latch)
        # The hinge's knuckle: a short barrel across it at the bottom.
        body.append(cylinder("Knuckle", (-0.0205, Y(1160), Z(480)), (0.0205, Y(1160), Z(480)), 0.0088, m["polymer"], 24, bevel=0.0012))
    cheek = slab("Cheek", fillet(PX([(1166, 372, 0.004), (1368, 376, 0.004), (1368, 458, 0.0), (1166, 458, 0.004)]), 5), -0.0195, 0.0195, m["od"])
    frame_outline = PX([(1166, 372, 0.004), (1368, 376, 0.0), (1368, 664, 0.006), (1336, 666, 0.01), (1158, 506, 0.014), (1152, 490, 0.004)])
    frame = slab("StockFrame", fillet(frame_outline, 6), -0.0158, 0.0158, m["od"])
    cut(frame, slab("big", fillet(PX([(1198, 476, 0.006), (1324, 476, 0.006), (1324, 590, 0.008)]), 6), -0.05, 0.05, None))
    if g2:
        cut(frame, slab("small", fillet(PX([(1336, 600, 0.004), (1352, 598, 0.003), (1352, 640, 0.004)]), 4), -0.05, 0.05, None))
        cuts = []
        for side in (-1.0, 1.0):
            # Long slots in the cheek and pockets in the ledge under it.
            for a, b, t, u in ((1196, 1250, 452, 464), (1262, 1312, 452, 464), (1330, 1356, 449, 466), (1212, 1300, 424, 432), (1316, 1352, 424, 432)):
                cuts.append(slab("cs", fillet(PX([(a, t, 0.002), (b, t, 0.002), (b, u, 0.002), (a, u, 0.002)]), 3), side * 0.0195 - 0.0022, side * 0.0195 + 0.0022, None))
        cut_all(cheek, cuts)
    bevel_object(cheek, 0.0032, 3, 30.0)
    bevel_object(frame, 0.003, 3, 30.0)
    smooth(cheek, 35)
    smooth(frame, 35)
    body.extend([cheek, frame])
    pad = slab("ButtPad", fillet(PX([(1366, 374, 0.0), (1430, 376, 0.012), (1440, 410, 0.006), (1440, 640, 0.006), (1432, 668, 0.012), (1366, 668, 0.0)]), 6), -0.0205, 0.0205, m["rubber"])
    if g3:
        grooves = []
        for k in range(26):
            z = Z(392) - k * 0.0054
            grooves.append(box("pg", (-0.016, Y(1446), z - 0.0012), (0.016, Y(1434), z + 0.0012), None))
        cut_all(pad, grooves)
    bevel_object(pad, 0.004, 3, 30.0)
    smooth(pad, 35)
    body.append(pad)
    if g2:
        # The plate between stock and pad.
        body.append(slab("PadPlate", fillet(PX([(1362, 372, 0.003), (1370, 372, 0.003), (1370, 668, 0.003), (1362, 668, 0.003)]), 3), -0.019, 0.019, m["polymer"]))
        # The QD socket on the left of the stock's back, the sling loop under it.
        qd = cylinder("QD", (-0.0152, Y(1348), Z(514)), (-0.0194, Y(1348), Z(514)), 0.0075, m["steel"], 28, bevel=0.0008)
        cut(qd, cylinder("qdh", (-0.03, Y(1348), Z(514)), (-0.0162, Y(1348), Z(514)), 0.0042, None, 20))
        smooth(qd, 35)
        body.append(qd)
        body.append(cylinder("QDHole", (-0.0163, Y(1348), Z(514)), (-0.0165, Y(1348), Z(514)), 0.0043, m["dark"], 20))
        body.append(ring("SlingLoop", (0.0, Y(1352), Z(676)), "X", 0.0085, 0.0016, m["steel"]))
        body.append(box("LoopMount", (-0.004, Y(1360), Z(670)), (0.004, Y(1344), Z(662)), m["steel"], bevel=0.0008))

    # --- the vertical grip under the handguard, the weapon light at its front
    vg_section = fillet([(0.0135, 0.279, 0.006), (0.0135, 0.322, 0.008), (-0.0135, 0.322, 0.008), (-0.0135, 0.279, 0.006)], 5)
    vgrip = upright("ForeGrip", vg_section, -0.068, 0.0105, m["polymer"])
    if g3:
        # Ribs round its front.
        ribs = [box("vr", (-0.02, 0.3195, z - 0.0013), (0.02, 0.325, z + 0.0013), None) for z in [-0.06 + k * 0.0058 for k in range(10)]]
        cut_all(vgrip, ribs)
    bevel_object(vgrip, 0.0035, 3, 30.0)
    rotate(vgrip, math.radians(-3.0), "X", Vector((0.0, 0.300, 0.01)))
    smooth(vgrip, 38)
    body.append(vgrip)
    vcap = upright("ForeGripCap", fillet([(0.015, 0.2775, 0.006), (0.015, 0.3245, 0.008), (-0.015, 0.3245, 0.008), (-0.015, 0.2775, 0.006)], 5), -0.0765, -0.066, m["polymer"])
    bevel_object(vcap, 0.003, 2, 30.0)
    rotate(vcap, math.radians(-3.0), "X", Vector((0.0, 0.300, 0.01)))
    smooth(vcap, 38)
    body.append(vcap)
    clamp = box("GripClamp", (-0.0145, Y(452), HG_BOT - 0.0215), (0.0145, Y(332), HG_BOT - 0.0058), m["polymer"], bevel=0.002)
    smooth(clamp, 35)
    body.append(clamp)
    if g3:
        for side in (-1.0, 1.0):
            p = upright("ForeGripPanel", fillet([(side * 0.0136, 0.283, 0.0), (side * 0.0146, 0.283, 0.0), (side * 0.0146, 0.314, 0.0), (side * 0.0136, 0.314, 0.0)], 1), -0.058, -0.004, m["grip"])
            rotate(p, math.radians(-3.0), "X", Vector((0.0, 0.300, 0.01)))
            body.append(p)
            for y in (Y(352), Y(432)):
                body.append(cylinder("ClampBolt", (side * 0.0145, y, HG_BOT - 0.0135), (side * 0.0163, y, HG_BOT - 0.0135), 0.0028, m["steel"], 16))
    lz = 0.008          # (under the light rail, not into it)
    light = cylinder("Light", (0, Y(320), lz), (0, Y(190), lz), 0.0125, m["polymer"], 32, bevel=0.001 if g2 else 0.0)
    body.append(light)
    head = cylinder("LightHead", (0, Y(192), lz), (0, Y(142), lz), 0.0172, m["polymer"], 36, bevel=0.0014 if g2 else 0.0)
    body.append(head)
    if g2:
        body.append(cylinder("LightTail", (0, Y(328), lz), (0, Y(318), lz), 0.0116, m["rubber"], 28, bevel=0.0015))
        body.append(cone("LightFlare", (0, Y(200), lz), (0, Y(192), lz), 0.0125, 0.0172, m["polymer"], 36))
        lensr = cylinder("Lens", (0, Y(144), lz), (0, Y(141.2), lz), 0.0146, m["lens"], 36)
        body.append(lensr)
        body.append(cylinder("LensCore", (0, Y(141.6), lz), (0, Y(141), lz), 0.0042, m["white"], 20))
        mount = box("LightMount", (-0.009, Y(300), lz + 0.0095), (0.009, Y(214), HG_BOT - 0.0045), m["polymer"], bevel=0.0016)
        smooth(mount, 35)
        body.append(mount)
    if g3:
        # Grip rings round the head, the switch on its back.
        for k in range(6):
            y = Y(150) - k * 0.0034
            body.append(cylinder("HeadRib", (0, y - 0.0009, lz), (0, y + 0.0009, lz), 0.0178, m["polymer"], 36))
        body.append(cylinder("Switch", (-0.0118, Y(262), lz + 0.002), (-0.0152, Y(262), lz + 0.002), 0.0038, m["rubber"], 18, bevel=0.0008))
        for y in (Y(222), Y(292)):
            body.append(cylinder("MountScrew", (-0.009, y, HG_BOT - 0.0085), (-0.0104, y, HG_BOT - 0.0085), 0.0024, m["steel"], 14))

    # --- controls: the fire selector (both sides), the bolt catch, the magazine release
    if g2:
        for side in (-1.0, 1.0):
            sx = side * REC_W
            body.append(cylinder("SelectorHub", (sx, SELECTOR.y, SELECTOR.z), (sx + side * 0.0032, SELECTOR.y, SELECTOR.z), 0.0062, m["steel"], 24, bevel=0.0007))
            lever = box("SelectorLever", (sx + side * 0.0018 - 0.0011, SELECTOR.y - 0.021, SELECTOR.z - 0.0028), (sx + side * 0.0018 + 0.0011, SELECTOR.y + 0.001, SELECTOR.z + 0.0028), m["steel"], bevel=0.0008)
            rotate(lever, math.radians(-8.0), "X", SELECTOR)
            body.append(lever)
        catch = box("BoltCatch", (-REC_W - 0.0024, Y(870), Z(504)), (-REC_W + 0.001, Y(812), Z(486)), m["polymer"], bevel=0.0009)
        body.append(catch)
        paddle = slab("MagRelease", fillet(PX([(826, 568, 0.002), (848, 566, 0.002), (852, 608, 0.003), (838, 612, 0.003)]), 3), -0.0075, 0.0075, m["polymer"])
        bevel_object(paddle, 0.001, 1, 35.0)
        body.append(paddle)
    if g3:
        # The selector's settings in the HK pictograms: a white safe, red single and burst.
        for side in (-1.0, 1.0):
            x = side * (REC_W + 0.0002)
            for (py, px), mat in (((468, 940), m["white"]), ((466, 968), m["red"]), ((503, 936), m["red"])):
                body.append(box("Pict", (x - 0.0002, Y(px + 9), Z(py + 4)), (x + 0.0002, Y(px - 9), Z(py - 4)), mat))
                body.append(box("PictIn", (x + side * 0.00025 - 0.0001, Y(px + 6), Z(py + 2)), (x + side * 0.00025 + 0.0001, Y(px - 6), Z(py - 2)), m["polymer"]))
            body.append(cylinder("SelDot", (side * (REC_W + 0.0032), SELECTOR.y - 0.016, SELECTOR.z - 0.0006), (side * (REC_W + 0.0036), SELECTOR.y - 0.016, SELECTOR.z - 0.0006), 0.0013, m["red"], 12))
        # Pins and screws through the receiver, the handle, the hinge.
        for px, py in ((790, 404), (845, 432), (862, 470), (1066, 470), (575, 357), (1030, 330), (1150, 400), (1130, 470)):
            y, z = Y(px), Z(py)
            w = REC_W
            if px < 600:
                w = HG_W
            elif px > 1100:
                w = 0.0195
            elif py < 350:
                w = 0.0145
            for side in (-1.0, 1.0):
                body.append(cylinder("Pin", (side * (w - 0.0006), y, z), (side * (w + 0.0005), y, z), 0.0026, m["steel"], 16))
                body.append(cylinder("PinHead", (side * (w + 0.0003), y, z), (side * (w + 0.0007), y, z), 0.0017, m["dark"], 12))
        # Markings on the left of the receiver: the maker, the type and calibre, the number.
        body.append(engrave_left("HK", Vector((-REC_W - 0.0002, Y(700), Z(446))), 0.0115, m["marking"], bold=True))
        body.append(engrave_left("G36", Vector((-REC_W - 0.0002, Y(700), Z(470))), 0.0072, m["marking"]))
        body.append(engrave_left("5,56 x 45", Vector((-REC_W - 0.0002, Y(700), Z(484))), 0.0052, m["marking"]))
        body.append(engrave_left("36-117420 DE", Vector((-0.0168 - 0.0002, Y(712), Z(530))), 0.004, m["marking"]))
        body.append(engrave_left("NW-36", Vector((-HG_W - 0.0002, Y(560), Z(440))), 0.0036, m["marking"]))

    # --- the magazine: the translucent shell, the black lips at its top and its floor plate,
    # the rounds in two staggered rows, the follower under them
    shell_outline = fillet([(MAG_HALF, 0.0, 0.0), (MAG_HALF, -MAG_LEN + 0.009, 0.004), (-MAG_HALF, -MAG_LEN + 0.009, 0.004), (-MAG_HALF, 0.0, 0.0)], 5)
    case = slab("ShellBody", shell_outline, -MAG_W, MAG_W, m["shell"])
    bevel_object(case, 0.0018, 2, 40.0)
    smooth(case, 40)
    shell.append(case)
    if g2:
        # Ribs across its sides and the spine down its front.
        for z in (-0.04, -0.078, -0.116):
            shell.append(box("ShellRib", (-MAG_W - 0.0008, -MAG_HALF - 0.0006, z - 0.0022), (MAG_W + 0.0008, MAG_HALF + 0.0006, z + 0.0022), m["shell"], bevel=0.0008))
        shell.append(box("Spine", (-0.004, MAG_HALF - 0.001, -MAG_LEN + 0.01), (0.004, MAG_HALF + 0.0022, -0.008), m["shell"], bevel=0.001))
    lips = box("MagLips", (-MAG_W + 0.0006, -MAG_HALF + 0.0006, -0.016), (MAG_W - 0.0006, MAG_HALF - 0.0006, 0.002), m["magblack"], bevel=0.0012)
    mag.append(lips)
    floor = box("FloorPlate", (-MAG_W - 0.0012, -MAG_HALF - 0.002, -MAG_LEN), (MAG_W + 0.0012, MAG_HALF + 0.0024, -MAG_LEN + 0.0115), m["magblack"], bevel=0.0022 if g2 else 0.0)
    smooth(floor, 35)
    mag.append(floor)
    if g3:
        # The studs on its left that clip it to the next magazine, the plate's catch.
        for y in (-0.016, 0.014):
            mag.append(cylinder("Stud", (-MAG_W - 0.0002, y, -0.026), (-MAG_W - 0.0034, y, -0.026), 0.0032, m["magblack"], 16, bevel=0.0006))
        mag.append(box("PlateCatch", (-0.005, -MAG_HALF - 0.0028, -MAG_LEN + 0.002), (0.005, -MAG_HALF - 0.0012, -MAG_LEN + 0.009), m["magblack"], bevel=0.0005))
    seg = 14 if g2 else 10
    last_z = 0.0
    for i in range(ROUNDS):
        z = -0.0128 - i * 0.0047
        x = 0.0043 if i % 2 else -0.0043
        base, body_end, neck0, neck1, tip = -MAG_HALF + 0.0022, 0.005, 0.0085, 0.0137, MAG_HALF - 0.0072
        mag.append(cylinder("Case", (x, base, z), (x, body_end, z), 0.0047, m["brass"], seg))
        mag.append(cone("Shoulder", (x, body_end, z), (x, neck0, z), 0.0047, 0.0031, m["brass"], seg))
        mag.append(cylinder("Neck", (x, neck0, z), (x, neck1, z), 0.0031, m["brass"], seg))
        mag.append(cone("Bullet", (x, neck1, z), (x, tip, z), 0.0029, 0.0005, m["copper"], seg))
        if g3:
            mag.append(cylinder("Rim", (x, base - 0.0002, z), (x, base + 0.0012, z), 0.0048, m["brass"], seg))
        last_z = z
    if g2:
        mag.append(box("Follower", (-MAG_W + 0.001, -MAG_HALF + 0.001, last_z - 0.012), (MAG_W - 0.001, MAG_HALF - 0.001, last_z - 0.0052), m["magblack"], bevel=0.0012))
    for o in mag + shell:
        mag_place(o)
    return body, mag, sights, shell


def engrave_left(text, at, size, material, bold=False):
    """Flat lettering on the left face, reading from the muzzle backwards as one sees it
    from the left; 'at' is where its first letter begins."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.extrude = 0.00012
    if bold:
        curve.offset = size * 0.035
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
def bake(objs, prefix="g36"):
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


def final_material(images, name="g36"):
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
CENTRE = (0.0, 0.14, 0.0)
VIEWS = [
    # name, camera, target, lens (mm)
    ("links", (-1.75, 0.14, 0.0), CENTRE, 70),
    ("rechts", (1.75, 0.14, 0.0), CENTRE, 70),
    ("schraeg", (-0.8, 0.95, 0.38), (0.0, 0.12, 0.0), 55),
    ("hinten_schraeg", (-0.5, -0.8, 0.36), (0.0, 0.08, 0.04), 55),
    ("oben", (0.0, 0.14, 1.7), (0.0, 0.14, 0.0), 70),
    ("unten", (-0.4, 0.14, -1.0), (0.0, 0.14, -0.02), 60),
    ("nah_vorn", (-0.36, 0.62, 0.12), (0.0, 0.36, 0.03), 50),
    ("nah_mitte", (-0.42, 0.02, 0.1), (0.0, 0.12, 0.02), 50),
    ("nah_schaft", (-0.4, -0.38, 0.12), (0.0, -0.13, 0.0), 50),
    ("visier", (0.0, REAR_SIGHT_Y - 0.14, IRONS), (0.0, 0.6, IRONS), 30),
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
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0, 0.14, -0.21))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor")
    floor_mat.use_nodes = True
    floor.data.materials.append(floor_mat)
    setups = {
        "studio": [("key", "AREA", (-1.2, -0.5, 1.4), CENTRE, 48.0, (1.0, 0.97, 0.92), 1.2),
                   ("fill", "AREA", (1.3, 0.5, 0.6), CENTRE, 16.0, (0.85, 0.9, 1.0), 1.5),
                   ("side", "AREA", (-1.4, 0.4, 0.2), CENTRE, 9.0, (1.0, 1.0, 1.0), 1.4),
                   ("rim", "AREA", (0.2, 1.6, 0.9), CENTRE, 34.0, (1.0, 1.0, 1.0), 0.8)],
        "nacht": [("lamp", "POINT", (-0.6, -0.3, 0.8), CENTRE, 30.0, (1.0, 0.72, 0.45), 0.1),
                  ("cold", "AREA", (0.5, 1.4, 0.5), CENTRE, 22.0, (0.45, 0.6, 1.0), 0.6)],
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
            if setup == "nacht" and name not in ("schraeg", "links", "visier"):
                continue
            cam.data.lens = lens
            floor.hide_render = name in ("unten", "visier")
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
    body_parts, mag_parts, sight_parts, shell_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(mag_parts, "Magazine")
    sights = join(sight_parts, "Sights")
    shell = join(shell_parts, "Shell")
    parts = (body, magazine, sights)
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
        # The cutters bring empty material slots along: give them the polymer.
        for o in parts:
            for slot in o.material_slots:
                if slot.material is None:
                    slot.material = bpy.data.materials["polymer"]
        images = bake(list(parts), "g36")
        final = final_material(images, "g36")
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    # The magazine moves about the middle of its top; the shell goes with it.
    mag_origin = tuple(MAG_TOP)
    place_origin(magazine, mag_origin)
    shell.data.transform(Matrix.Translation(-Vector(mag_origin)))
    shell.parent = magazine
    shell.location = (0.0, 0.0, 0.0)
    root = link(bpy.data.objects.new("G36", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "magazine", triangles(magazine), "shell", triangles(shell), "sights", triangles(sights),
          "all", sum(triangles(o) for o in parts + (shell,)), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    foot = mag_bend((0.0, 0.0, -MAG_LEN))
    out = (foot - Vector(MAG_TOP)).normalized()
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % 0.0108, "rail %.4f irons %.4f" % (HANDLE_RAIL, IRONS),
          "rail y %.4f..%.4f" % (Y(576), Y(1036)), "rear sight", godot((0, REAR_SIGHT_Y, IRONS)), "front post", godot((0, FRONT_POST_Y, IRONS)))
    print("SPEC handle", godot(HANDLE), "support", godot(SUPPORT), "magazine", godot(mag_origin), "magazine_foot", godot(foot), "magazine_out", godot(out), "eject", godot(PORT))
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
