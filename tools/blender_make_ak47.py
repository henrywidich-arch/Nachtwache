# Builds the AK-47 for Nachtwache, from nothing (it replaces the supplied meshes ak47.glb and
# ak47_low.glb, which stay in the folder unused): the Kalashnikov in its common later form,
# the AKM - a receiver bent from sheet steel and held together by rivets, its top cover with
# stamped ribs across it, the bolt carrier and its handle in the port on the right, the long
# selector lever over the slot below it, the rear sight's leaf on its block before the cover,
# the gas tube over the barrel, the gas block and the front sight with its two ears near the
# slanted muzzle brake; laminated wood with its grain for the stock and the handguards, a
# bakelite pistol grip with its chequered sides, and the curved steel magazine with its ribs.
# Every part is made here, bevelled, given its material, UV-unwrapped and baked into one
# texture set (base colour, roughness and metal, normal). Written as a GLB with the nodes
#   AK47 > Body / Magazine (origin: the middle of its top) / Bolt (the bolt carrier and its
#   handle, which the hand pulls back at the end of a reload; origin: the handle's knob) /
#   Trigger (origin: its pivot)
# and the same once more, much lighter, for the soldiers who carry it (ak47_low_built.glb:
# AK47 > Body / Magazine, the same places).
#
#   blender --background --factory-startup --python tools/blender_make_ak47.py -- [--round 4] [--tex 2048]
#           [--out assets/models/ak47_built.glb] [--low assets/models/ak47_low_built.glb]
#           [--render <folder> --prefix ak_r1] [--only links,schraeg] [--nobake] [--gpu]
#
# --round: how far the detail goes (1 silhouette, 2 main parts and seams, 3 fine detail,
#          4 the corrections after looking at round 3; the game uses the last).
# --nobake: render the procedural materials straight away and write no GLB (quick reviews).
# --render: fixed views (studio light and dark in-game light).
#
# Its helpers (shapes, materials with wear and wood grain, the bake, the review pictures)
# are borrowed by blender_make_mg.py.
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the pistol grip (where the old model had it, so that the hands and the soldiers' grips stay
# right). The glTF exporter turns this into Godot space (barrel along -Z, up +Y). The places
# the game needs (GUNS["ak"] in weapon_view.gd) are printed.
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
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "ak47_built.glb")))
LOW = os.path.abspath(arg("--low", os.path.join(HERE, "..", "assets", "models", "ak47_low_built.glb")))
BLEND = arg("--blend")
RENDER = arg("--render")
PREFIX = arg("--prefix", "ak_r%d" % ROUND)
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


def lathe(name, start, end, profile, material, segments=24):
    """A body turned about the axis start -> end: `profile` is (t, radius) pairs, t 0..1
    along the axis, closed with a cap at both ends."""
    start, end = Vector(start), Vector(end)
    axis = end - start
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix()
    rings = []
    for t, r in profile:
        ring = []
        for k in range(segments):
            a = math.tau * k / segments
            ring.append(start + axis * t + rot @ Vector((math.cos(a) * r, math.sin(a) * r, 0.0)))
        rings.append(ring)
    return loft(name, rings, material)


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


def loft(name, rings, material, caps=True):
    """A body through the closed rings of points (all of the same count), capped at both ends."""
    bm = bmesh.new()
    verts = [[bm.verts.new(tuple(p)) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(verts, verts[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps:
        bm.faces.new(verts[0])
        bm.faces.new(list(reversed(verts[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, material)


def sweep(name, path, half_w, thick, material, x=0.0):
    """A flat strip of steel (a trigger guard, a spring, a blade) along the path of (y, z)
    points in the plane x, `half_w` to each side of it, `thick` across the path."""
    pts = [Vector(p) for p in path]
    rings = []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = (b - a).normalized()
        nrm = Vector((-t.y, t.x)) * (thick * 0.5)
        rings.append([(x - half_w, p.x + nrm.x, p.y + nrm.y), (x + half_w, p.x + nrm.x, p.y + nrm.y),
                      (x + half_w, p.x - nrm.x, p.y - nrm.y), (x - half_w, p.x - nrm.x, p.y - nrm.y)])
    return loft(name, rings, material)


def torus(name, centre, axis, big, small, material, segments=20, sides=8):
    centre = Vector(centre)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_matrix()
    rings = []
    for k in range(segments):
        a = math.tau * k / segments
        d = Vector((math.cos(a), math.sin(a), 0.0))
        ring = []
        for s in range(sides):
            b = math.tau * s / sides
            p = d * (big + math.cos(b) * small) + Vector((0, 0, math.sin(b) * small))
            ring.append(centre + rot @ p)
        rings.append(ring)
    rings.append(rings[0])
    bm = bmesh.new()
    verts = [[bm.verts.new(tuple(p)) for p in ring] for ring in rings[:-1]]
    for i in range(segments):
        a, b = verts[i], verts[(i + 1) % segments]
        for s in range(sides):
            t = (s + 1) % sides
            bm.faces.new((a[s], a[t], b[t], b[s]))
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


def section(y, half_w, z0, z1, r_top, r_bottom, n=5):
    """A rounded cross-section at y as 3D points (for loft)."""
    return [(x, y, z) for x, z in rounded_rect(-half_w, half_w, z0, z1, r_top, r_bottom, n)]


def superellipse(half_a, half_b, power=2.6, count=28):
    """Points round a rounded-square oval: (a along the first axis, b along the second)."""
    out = []
    for k in range(count):
        t = math.tau * k / count
        c, s = math.cos(t), math.sin(t)
        out.append((half_a * math.copysign(abs(c) ** (2.0 / power), c), half_b * math.copysign(abs(s) ** (2.0 / power), s)))
    return out


def bevel_object(obj, width, segments=2, angle=35.0):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = False
    mod.use_clamp_overlap = True
    apply(obj, mod)


def subdivide(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
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
    return obj


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
def material(name, base, rough, metal, wear=0.0, grime=0.0, bump=0.0, bump_scale=900.0, stipple=False, worn=(0.3, 0.3, 0.3), checker=0.0, scratches=0.0):
    """`base` colour with a little noise in it, edges rubbed to `worn` (wear 0..1), grime in
    the hollows, an optional fine bump (stipple, or a brushed grain), or chequering (a grid
    of little pyramids, `checker` lines per metre, for the grip)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 160.0 if ROUND == 1 else 420.0
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
    out_colour, out_rough, out_metal = wear_and_grime(nt, coords, out_colour, out_rough, out_metal, metal, wear, grime, worn)
    if scratches > 0.0:
        # Fine scratches: the thin edges of large cells, only where a slow noise lets them
        # through, rubbed towards the bare steel and a little smoother.
        cells = nodes.new("ShaderNodeTexVoronoi")
        cells.feature = "DISTANCE_TO_EDGE"
        cells.inputs["Scale"].default_value = 130.0
        cells.inputs["Randomness"].default_value = 1.0
        # (Squeezed along the gun: long cells, so the scratches mostly run fore and aft,
        # as rubbing in a rack or a sling leaves them.)
        stretch = nodes.new("ShaderNodeMapping")
        stretch.inputs["Scale"].default_value = (1.0, 0.12, 1.0)
        links.new(coords.outputs["Object"], stretch.inputs["Vector"])
        links.new(stretch.outputs["Vector"], cells.inputs["Vector"])
        line = nodes.new("ShaderNodeMapRange")
        line.inputs[1].default_value = 0.0
        line.inputs[2].default_value = 0.0035
        line.inputs[3].default_value = 1.0
        line.inputs[4].default_value = 0.0
        links.new(cells.outputs["Distance"], line.inputs[0])
        patch_noise = nodes.new("ShaderNodeTexNoise")
        patch_noise.inputs["Scale"].default_value = 18.0
        links.new(coords.outputs["Object"], patch_noise.inputs["Vector"])
        patch = nodes.new("ShaderNodeMapRange")
        patch.inputs[1].default_value = 0.56
        patch.inputs[2].default_value = 0.72
        links.new(patch_noise.outputs["Fac"], patch.inputs[0])
        amount = nodes.new("ShaderNodeMath")
        amount.operation = "MULTIPLY"
        links.new(line.outputs[0], amount.inputs[0])
        links.new(patch.outputs[0], amount.inputs[1])
        gain = nodes.new("ShaderNodeMath")
        gain.operation = "MULTIPLY"
        gain.inputs[1].default_value = scratches
        links.new(amount.outputs[0], gain.inputs[0])
        smix = nodes.new("ShaderNodeMix")
        smix.data_type = "RGBA"
        links.new(gain.outputs[0], smix.inputs[0])
        links.new(out_colour, smix.inputs[6])
        smix.inputs[7].default_value = (*worn, 1.0)
        out_colour = smix.outputs[2]
        srough = nodes.new("ShaderNodeMix")
        links.new(gain.outputs[0], srough.inputs[0])
        links.new(out_rough, srough.inputs[2])
        srough.inputs[3].default_value = 0.3
        out_rough = srough.outputs[0]
    links.new(out_colour, bsdf.inputs["Base Color"])
    links.new(out_rough, bsdf.inputs["Roughness"])
    links.new(out_metal, bsdf.inputs["Metallic"])
    mat["metal_socket"] = out_metal.node.name + ":" + str(list(out_metal.node.outputs).index(out_metal))
    mat["colour_socket"] = out_colour.node.name + ":" + str(list(out_colour.node.outputs).index(out_colour))
    if checker > 0.0:
        # Two triangle waves crossing at right angles, diagonal on the side of the grip: the
        # lower of the two is the height of a little pyramid.
        heights = []
        for turn in (45.0, -45.0):
            mapping = nodes.new("ShaderNodeMapping")
            mapping.inputs["Rotation"].default_value = (math.radians(turn), 0.0, 0.0)
            links.new(coords.outputs["Object"], mapping.inputs["Vector"])
            wave = nodes.new("ShaderNodeTexWave")
            wave.wave_type = "BANDS"
            wave.bands_direction = "Y"
            wave.wave_profile = "TRI"
            wave.inputs["Scale"].default_value = checker
            wave.inputs["Distortion"].default_value = 0.0
            links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
            heights.append(wave.outputs["Fac"])
        low = nodes.new("ShaderNodeMath")
        low.operation = "MINIMUM"
        links.new(heights[0], low.inputs[0])
        links.new(heights[1], low.inputs[1])
        bump_node = nodes.new("ShaderNodeBump")
        bump_node.inputs["Strength"].default_value = 0.9
        bump_node.inputs["Distance"].default_value = 0.0007
        links.new(low.outputs[0], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    elif bump > 0.0:
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


def wear_and_grime(nt, coords, out_colour, out_rough, out_metal, metal, wear, grime, worn):
    """Edges rubbed to `worn` (by the curvature Cycles sees), grime in the hollows."""
    nodes, links = nt.nodes, nt.links
    if wear <= 0.0 and grime <= 0.0:
        return out_colour, out_rough, out_metal
    geo = nodes.new("ShaderNodeNewGeometry")
    wear_noise = nodes.new("ShaderNodeTexNoise")
    wear_noise.inputs["Scale"].default_value = 60.0
    wear_noise.inputs["Detail"].default_value = 8.0
    links.new(coords.outputs["Object"], wear_noise.inputs["Vector"])
    if wear > 0.0:
        edge = nodes.new("ShaderNodeMapRange")
        bev = nodes.new("ShaderNodeBevel")
        bev.inputs["Radius"].default_value = 0.0012
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
        convex = edge.outputs[0]
        if ROUND >= 4:
            # (The bevel sees an inside corner as an edge too: a hollow - a dimple, the root of
            # a rib - is kept from wearing by its occlusion.)
            inside = nodes.new("ShaderNodeAmbientOcclusion")
            inside.inputs["Distance"].default_value = 0.003
            inside.samples = 8
            open_ = nodes.new("ShaderNodeMapRange")
            open_.inputs[1].default_value = 0.72
            open_.inputs[2].default_value = 0.95
            links.new(inside.outputs["AO"], open_.inputs[0])
            masked = nodes.new("ShaderNodeMath")
            masked.operation = "MULTIPLY"
            links.new(edge.outputs[0], masked.inputs[0])
            links.new(open_.outputs[0], masked.inputs[1])
            convex = masked.outputs[0]
        links.new(convex, breakup.inputs[0])
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
        rmix.inputs[3].default_value = 0.32
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
        gmix.inputs[7].default_value = (0.012, 0.010, 0.008, 1.0)
        out_colour = gmix.outputs[2]
        grough = nodes.new("ShaderNodeMix")
        links.new(amount.outputs[0], grough.inputs[0])
        links.new(out_rough, grough.inputs[2])
        grough.inputs[3].default_value = 0.88
        out_rough = grough.outputs[0]
    return out_colour, out_rough, out_metal


def wood(name, light, dark, rough, wear=0.0, grime=0.0, rings=160.0, worn=(0.42, 0.24, 0.12)):
    """Laminated birch under a reddish varnish, as on the AKM: growth rings round the long
    axis (y) of the part, so that its grain runs along it, wavy, with darker streaks; its
    pores a fine bump; the varnish rubbed thin on the edges."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    # The rings: about an axis along y well outside the part, distorted by a slow noise.
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (0.11, 0.0, 0.17)
    links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    warp = nodes.new("ShaderNodeTexNoise")
    warp.inputs["Scale"].default_value = 6.0 if ROUND >= 4 else 14.0
    warp.inputs["Detail"].default_value = 3.0
    stretch = nodes.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (1.0, 0.25, 1.0)
    links.new(coords.outputs["Object"], stretch.inputs["Vector"])
    links.new(stretch.outputs["Vector"], warp.inputs["Vector"])
    shift = nodes.new("ShaderNodeVectorMath")
    shift.operation = "MULTIPLY_ADD"
    shift.inputs[1].default_value = (0.014, 0.0, 0.014) if ROUND >= 4 else (0.007, 0.0, 0.007)
    links.new(warp.outputs["Color"], shift.inputs[0])
    links.new(mapping.outputs["Vector"], shift.inputs[2])
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.rings_direction = "Y"
    wave.wave_profile = "SIN"
    wave.inputs["Scale"].default_value = rings if ROUND >= 2 else rings * 0.5
    wave.inputs["Distortion"].default_value = 0.9
    wave.inputs["Detail"].default_value = 2.0
    wave.inputs["Detail Scale"].default_value = 2.5
    links.new(shift.outputs["Vector"], wave.inputs["Vector"])
    sharpen = nodes.new("ShaderNodeMapRange")
    sharpen.inputs[1].default_value = 0.25
    sharpen.inputs[2].default_value = 0.85
    links.new(wave.outputs["Fac"], sharpen.inputs[0])
    if ROUND >= 4:
        # Some stretches of the grain stand out, others are faint.
        fade_map = nodes.new("ShaderNodeMapping")
        fade_map.inputs["Scale"].default_value = (30.0, 4.0, 30.0)
        links.new(coords.outputs["Object"], fade_map.inputs["Vector"])
        fade = nodes.new("ShaderNodeTexNoise")
        fade.inputs["Scale"].default_value = 1.0
        links.new(fade_map.outputs["Vector"], fade.inputs["Vector"])
        fade_r = nodes.new("ShaderNodeMapRange")
        fade_r.inputs[1].default_value = 0.35
        fade_r.inputs[2].default_value = 0.65
        fade_r.inputs[3].default_value = 0.35
        fade_r.inputs[4].default_value = 1.0
        links.new(fade.outputs["Fac"], fade_r.inputs[0])
        scaled = nodes.new("ShaderNodeMath")
        scaled.operation = "MULTIPLY"
        links.new(sharpen.outputs[0], scaled.inputs[0])
        links.new(fade_r.outputs[0], scaled.inputs[1])
        sharpen = scaled
    # Streaks: long, slow changes of tone along the grain.
    streak_map = nodes.new("ShaderNodeMapping")
    streak_map.inputs["Scale"].default_value = (60.0, 2.5, 60.0)
    links.new(coords.outputs["Object"], streak_map.inputs["Vector"])
    streak = nodes.new("ShaderNodeTexNoise")
    streak.inputs["Scale"].default_value = 1.0
    streak.inputs["Detail"].default_value = 4.0
    links.new(streak_map.outputs["Vector"], streak.inputs["Vector"])
    grain = nodes.new("ShaderNodeMix")
    grain.data_type = "RGBA"
    grain.inputs[6].default_value = (*light, 1.0)
    grain.inputs[7].default_value = (*dark, 1.0)
    links.new(sharpen.outputs[0], grain.inputs[0])
    tone = nodes.new("ShaderNodeMix")
    tone.data_type = "RGBA"
    tone.blend_type = "MULTIPLY"
    tone.inputs[0].default_value = 0.55
    links.new(grain.outputs[2], tone.inputs[6])
    tone_ramp = nodes.new("ShaderNodeMapRange")
    tone_ramp.inputs[3].default_value = 0.7
    tone_ramp.inputs[4].default_value = 1.25
    links.new(streak.outputs["Fac"], tone_ramp.inputs[0])
    tone_rgb = nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        links.new(tone_ramp.outputs[0], tone_rgb.inputs[i])
    links.new(tone_rgb.outputs[0], tone.inputs[7])
    out_colour = tone.outputs[2]
    rough_node = nodes.new("ShaderNodeMath")
    rough_node.operation = "MULTIPLY_ADD"
    rough_node.inputs[1].default_value = 0.14
    rough_node.inputs[2].default_value = rough - 0.07
    links.new(sharpen.outputs[0], rough_node.inputs[0])
    out_rough = rough_node.outputs[0]
    metal_node = nodes.new("ShaderNodeValue")
    metal_node.outputs[0].default_value = 0.0
    out_metal = metal_node.outputs[0]
    out_colour, out_rough, out_metal = wear_and_grime(nt, coords, out_colour, out_rough, out_metal, 0.0, wear, grime, worn)
    links.new(out_colour, bsdf.inputs["Base Color"])
    links.new(out_rough, bsdf.inputs["Roughness"])
    links.new(out_metal, bsdf.inputs["Metallic"])
    mat["metal_socket"] = out_metal.node.name + ":" + str(list(out_metal.node.outputs).index(out_metal))
    mat["colour_socket"] = out_colour.node.name + ":" + str(list(out_colour.node.outputs).index(out_colour))
    if ROUND >= 3:
        # The pores: short dashes along the grain, and the rings themselves a touch raised.
        pore_map = nodes.new("ShaderNodeMapping")
        pore_map.inputs["Scale"].default_value = (1.0, 0.06, 1.0)
        links.new(coords.outputs["Object"], pore_map.inputs["Vector"])
        pores = nodes.new("ShaderNodeTexNoise")
        pores.inputs["Scale"].default_value = 2600.0
        pores.inputs["Detail"].default_value = 2.0
        links.new(pore_map.outputs["Vector"], pores.inputs["Vector"])
        height = nodes.new("ShaderNodeMath")
        height.operation = "MULTIPLY_ADD"
        height.inputs[1].default_value = 0.35
        links.new(pores.outputs["Fac"], height.inputs[0])
        links.new(sharpen.outputs[0], height.inputs[2])
        bump_node = nodes.new("ShaderNodeBump")
        bump_node.inputs["Strength"].default_value = 0.22
        bump_node.inputs["Distance"].default_value = 0.0004
        links.new(height.outputs[0], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def make_materials():
    wear = {1: 0.0, 2: 0.4, 3: 0.8}.get(ROUND, 0.85)
    # (Round 5: the steel was too clean and glossy black, the wood flat orange plastic.)
    # The receiver and the steel parts: dark grey phosphate over blueing, satin, rubbed to
    # bare steel on the edges, scratched, dirt in the corners.
    steel = material("steel", (0.046, 0.048, 0.052), 0.56, 0.7, wear=0.95 * wear, grime=0.85 if ROUND >= 2 else 0.0, worn=(0.42, 0.42, 0.43), scratches=0.4 if ROUND >= 4 else 0.0)
    # The barrel, the gas tube and the muzzle brake: a shade lighter and duller, sooty.
    barrel = material("barrel", (0.070, 0.068, 0.066), 0.62, 0.7, wear=0.6 * wear, grime=0.8 if ROUND >= 2 else 0.0, worn=(0.36, 0.35, 0.34), scratches=0.3 if ROUND >= 4 else 0.0) if ROUND >= 2 else steel
    bright = material("bright", (0.26, 0.26, 0.26), 0.40, 1.0, wear=0.3 * wear, grime=0.7 if ROUND >= 2 else 0.0, worn=(0.55, 0.55, 0.55))
    dark = material("dark", (0.006, 0.006, 0.007), 0.85, 0.0)
    # Laminated birch under a dark red-brown varnish, darker in the corners, worn lighter
    # on the edges.
    timber = wood("wood", (0.150, 0.062, 0.032), (0.052, 0.020, 0.010), 0.5, wear=0.95 * wear, grime=0.9 if ROUND >= 2 else 0.0, worn=(0.30, 0.17, 0.09))
    # The pistol grip: plum-brown bakelite with chequered sides.
    bakelite = material("bakelite", (0.070, 0.024, 0.022), 0.4, 0.0, wear=0.35 * wear, grime=0.7 if ROUND >= 2 else 0.0, worn=(0.20, 0.09, 0.07))
    chequer = material("chequer", (0.060, 0.021, 0.019), 0.6, 0.0, grime=0.8, checker=380.0) if ROUND >= 3 else bakelite
    magsteel = material("magsteel", (0.040, 0.041, 0.044), 0.58, 0.65, wear=0.7 * wear, grime=0.75 if ROUND >= 2 else 0.0, worn=(0.30, 0.30, 0.31), scratches=0.35 if ROUND >= 4 else 0.0)
    lacquer = material("lacquer", (0.22, 0.20, 0.10), 0.4, 0.55, grime=0.3)
    copper = material("copper", (0.45, 0.26, 0.15), 0.34, 1.0, grime=0.2)
    steelplain = material("steelplain", (0.052, 0.054, 0.058), 0.6, 0.65, grime=0.85)
    marking = material("marking", (0.30, 0.31, 0.32), 0.5, 0.6) if ROUND >= 3 else steel
    return {"steel": steel, "barrel": barrel, "bright": bright, "dark": dark, "wood": timber, "bakelite": bakelite, "chequer": chequer,
            "magsteel": magsteel, "steelplain": steelplain, "lacquer": lacquer, "copper": copper, "marking": marking}


# ------------------------------------------------------------------ the measures (those of the old model)
BORE_Z = 0.0764                 # the bore axis above the middle of the grip
MUZZLE_Y = 0.6253               # the face of the muzzle brake: 88 cm over all
BORE_R = 0.0039
BARREL_R = 0.0082
REC_Y = (-0.016, 0.236)         # the receiver, from its rear end to the front trunnion
REC_W = 0.0150                  # half its width
REC_Z = (0.048, 0.0965)         # its floor and the top of its side walls
COVER_TOP = 0.1185              # the top of the cover over it
SIGHT_Z = 0.1285                # the line of sight: the top of the rear sight's plate, the tip of the front post (the post sits in the notch, its tip level with the plate)
NOTCH_Y = 0.240                 # the rear sight's notch (the back end of its leaf)
POST_Y = 0.5785                 # the front sight post
GAS_Z = 0.0975                  # the gas tube's axis
GAS_Y = (0.463, 0.502)          # the gas block
FRONT_Y = (0.565, 0.594)        # the front sight's base
GUARD_Y = (0.238, 0.389)        # the lower handguard
UPPER_Y = (0.292, 0.396)        # the upper handguard
STOCK_END = -0.2535             # the face of the butt plate
MAG_ORIGIN = Vector((0.0, 0.1806, 0.0486))
MAG_C = Vector((0.539, 0.070))  # the centre the magazine's curve is drawn about (y, z)
# (Round 5, after Henry's lead: the first one was long and thin like an RPK's. A 30-round
# AKM magazine is deep - 6.8 cm front to back at the top, 5.6 at the floor - and about 19
# cm round its front below the well.)
MAG_R = (0.3250, 0.3930)        # the radius of its front, and of its back at the top
MAG_DEPTH = (0.068, 0.058)      # front to back at the top and at the floor
MAG_TOP = 0.0686
MAG_END = math.radians(31.0)    # how far round it goes
MAG_W = 0.0146
TRIGGER_PIVOT = Vector((0.0, 0.066, 0.056))
HANDLE = Vector((0.0398, 0.2084, 0.0905))       # the knob of the bolt carrier's handle
BOLT_TRAVEL = 0.095
SUPPORT = Vector((0.0, 0.330, 0.079))


def mag_point(r, phi):
    return Vector((MAG_C.x - r * math.cos(phi), MAG_C.y - r * math.sin(phi)))


def mag_back(phi):
    """The radius of the magazine's back at the angle phi: it narrows towards the floor."""
    t = max(0.0, min(1.0, phi / MAG_END))
    return MAG_R[0] + MAG_DEPTH[0] + (MAG_DEPTH[1] - MAG_DEPTH[0]) * t


def mag_band(r0, r1, phi0, phi1, steps=18):
    """The outline (y, z) of a band of the magazine's curve between two radii."""
    out = [tuple(mag_point(r0, phi0 + (phi1 - phi0) * k / steps)) for k in range(steps + 1)]
    out += [tuple(mag_point(r1, phi1 - (phi1 - phi0) * k / steps)) for k in range(steps + 1)]
    return out


def stock_section(y, grow=0.0):
    """The stock's cross-section at y: its top and bottom are straight lines from the
    receiver to the butt, it widens towards the butt."""
    t = (y - REC_Y[0]) / (STOCK_END + 0.006 - REC_Y[0])
    top = 0.0935 + (0.0815 - 0.0935) * t
    bottom = 0.0505 + (-0.0305 - 0.0505) * t
    half = 0.0122 + (0.0196 - 0.0122) * min(1.0, t * 1.15)
    # A gentle rise of the comb where the cheek lies.
    top += 0.0012 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.25) / 0.6)))
    return section(y, half + grow, bottom - grow, top + grow, 0.0075, 0.0065, 5)


def guard_section(y, grow=0.0):
    """The lower handguard's cross-section at y: round below, flat sides that swell out at
    its back where the palm lies, its top at the seam to the upper one."""
    t = (y - GUARD_Y[0]) / (GUARD_Y[1] - GUARD_Y[0])
    swell = math.exp(-((t - 0.16) / 0.16) ** 2) if ROUND >= 2 else 0.0
    half = 0.0168 + 0.0030 * swell - 0.0008 * t
    bottom = 0.0478 + 0.0055 * t
    return section(y, half + grow, bottom - grow, 0.0905 + grow, 0.002, 0.0115, 5)


def build(m):
    body, mag, bolt, trig = [], [], [], []
    W = REC_W
    z0, z1 = REC_Z
    # --- the receiver: bent from sheet, its lower edges rounded, open at the top under the
    # cover; the port on the right, the slot the handle runs in, the magazine well below.
    rec = box("Receiver", (-W, REC_Y[0], z0), (W, REC_Y[1], z1), m["steel"])
    # (Rounded first: bevelled after the shallow cuts, the bevel tore the dimples' floors.)
    bevel_object(rec, 0.0022 if ROUND >= 2 else 0.003, 3, 40.0)
    if ROUND >= 2:
        cut(rec, box("port", (-0.0125, 0.130, 0.0735), (0.03, 0.226, 0.12), m["steel"], bevel=0.0015))
        cut(rec, box("slot", (0.004, 0.096, 0.0872), (0.03, 0.222, 0.12), m["steel"]))
        cut(rec, box("well", (-MAG_W - 0.0003, 0.1448, z0 - 0.01), (MAG_W + 0.0003, 0.2165, 0.072), m["steel"], bevel=0.002))
        # The stamped dimples above the magazine well, both sides, that guide the magazine.
        for side in (-1.0, 1.0):
            d = box("dimple", (side * W - 0.0011, 0.150, 0.0565), (side * W + 0.0011, 0.210, 0.0705), m["steel"], bevel=0.0009)
            cut(rec, d)
        # The rails pressed into the walls the cover sits on: a groove along each side.
        for side in (-1.0, 1.0):
            cut(rec, box("groove", (side * W - 0.0005, REC_Y[0] + 0.006, 0.0905), (side * W + 0.0005, REC_Y[1] - 0.004, 0.0915), m["steel"]))
    smooth(rec, 35)
    if ROUND >= 4:
        # The floors and walls of the dimples and of the port: steel that is not rubbed (the
        # bake took their inside corners for worn edges).
        rec.data.materials.append(m["steelplain"])
        for poly in rec.data.polygons:
            c = poly.center
            if abs(c.x) < W - 0.00025 and 0.148 < c.y < 0.212 and 0.0550 < c.z < 0.0720:
                poly.material_index = 1
            elif c.x > -0.0126 and 0.129 < c.y < 0.227 and c.z > 0.0730 and abs(c.x) < W - 0.0002:
                poly.material_index = 1
    body.append(rec)
    if ROUND >= 2:
        # Dark inside: the well, behind the port, under the slot.
        body.append(box("WellInside", (-MAG_W + 0.0008, 0.1458, 0.06), (MAG_W - 0.0008, 0.2155, 0.0712), m["dark"]))
        body.append(box("PortWall", (-0.0136, 0.128, 0.0725), (-0.0118, 0.228, 0.0975), m["dark"]))
        body.append(box("PortFloor", (-0.0125, 0.128, 0.0726), (0.0138, 0.228, 0.0740), m["dark"]))
        body.append(box("SlotInside", (0.0040, 0.094, 0.0868), (0.0058, 0.224, 0.0950), m["dark"]))
        # The bolt's rail glinting along the far wall of the port.
        body.append(box("Rail", (-0.0119, 0.129, 0.0842), (-0.0100, 0.227, 0.0866), m["bright"]))
    # --- the top cover, rounded, its back end on the rear trunnion, its front tucked under
    # the rear sight's block; the button of the recoil spring's guide through its back.
    cover_profile = fillet([(W + 0.0007, 0.0938, 0.0), (W + 0.0007, COVER_TOP, 0.016), (-W - 0.0007, COVER_TOP, 0.016), (-W - 0.0007, 0.0938, 0.0)], 8)
    cover = prism("Cover", cover_profile, REC_Y[0] + 0.003, 0.246, m["steel"])
    if ROUND >= 2:
        # Hollow below (the walls show their edge from beneath, at the slot).
        inner = fillet([(W - 0.0004, 0.0925, 0.0), (W - 0.0004, COVER_TOP - 0.0012, 0.014), (-W + 0.0004, COVER_TOP - 0.0012, 0.014), (-W + 0.0004, 0.0925, 0.0)], 8)
        cut(cover, prism("hollow", inner, REC_Y[0] + 0.0045, 0.26, m["steel"]))
    bevel_object(cover, 0.0007, 2, 40.0)
    smooth(cover, 40)
    body.append(cover)
    if ROUND >= 2:
        # Its stamped ribs across: the AKM's, raised bands from edge to edge.
        rib_profile = fillet([(W + 0.0013, 0.0968, 0.0), (W + 0.0013, COVER_TOP + 0.0007, 0.0165), (-W - 0.0013, COVER_TOP + 0.0007, 0.0165), (-W - 0.0013, 0.0968, 0.0)], 8)
        for y in ((0.012, 0.044, 0.076, 0.108, 0.140, 0.172, 0.204) if ROUND >= 3 else (0.03, 0.09, 0.15, 0.21)):
            rib = prism("CoverRib", rib_profile, y - 0.0021, y + 0.0021, m["steel"])
            cut(rib, prism("rh", inner, y - 0.01, y + 0.01, m["steel"]))
            bevel_object(rib, 0.0009, 2, 30.0)
            body.append(smooth(rib, 40))
        body.append(box("GuideButton", (-0.0048, REC_Y[0] - 0.0035, 0.1005), (0.0048, REC_Y[0] + 0.004, 0.1108), m["bright"], bevel=0.0012))
        # The dark space under the cover's edges, seen past the handle.
        body.append(box("CoverInside", (-W + 0.0008, REC_Y[0] + 0.005, 0.0925), (W - 0.0008, 0.240, 0.0935), m["dark"]))
    # --- the rear sight's block over the chamber, its leaf hinged at the front, the notch at
    # the back end of the leaf; the slider that sets the range on it.
    block_outline = fillet([(0.2345, BORE_Z - 0.012, 0.002), (0.2345, 0.1185, 0.002), (0.2795, 0.1185, 0.004), (0.2935, 0.1060, 0.004), (0.2935, BORE_Z - 0.012, 0.002)], 4)
    block = slab("SightBlock", block_outline, -0.0122, 0.0122, m["steel"])
    if ROUND >= 2:
        # The leaf lies in a channel in the top of the block, between two cheeks.
        cut(block, box("channel", (-0.0074, 0.230, 0.1135), (0.0074, 0.2900, 0.13), m["steel"]))
    bevel_object(block, 0.0012, 2, 35.0)
    body.append(smooth(block, 35))
    hinge = Vector((0.0, 0.2870, 0.1175))
    leaf_end = Vector((0.0, NOTCH_Y, SIGHT_Z))
    leaf = slab("Leaf", fillet([(hinge.y + 0.0035, hinge.z - 0.0035, 0.002), (hinge.y + 0.0035, hinge.z + 0.0022, 0.002), (leaf_end.y, leaf_end.z, 0.0), (leaf_end.y, leaf_end.z - 0.0065, 0.0), (hinge.y - 0.004, hinge.z - 0.0035, 0.0)], 3),
                -0.0068, 0.0068, m["steel"])
    # The notch: a U cut down to the line of sight.
    notch = box("notch", (-0.0012, NOTCH_Y - 0.01, SIGHT_Z - 0.0023), (0.0012, NOTCH_Y + 0.008, SIGHT_Z + 0.02), m["steel"])
    cut(leaf, notch)
    cut(leaf, cylinder("notchround", (0, NOTCH_Y - 0.01, SIGHT_Z - 0.0023), (0, NOTCH_Y + 0.008, SIGHT_Z - 0.0023), 0.0012, m["steel"], 16))
    if ROUND >= 2:
        # The ear on each side of the notch (the leaf's back end stands up as a little plate).
        cut(leaf, box("bevel", (-0.02, NOTCH_Y + 0.003, SIGHT_Z - 0.004), (0.02, NOTCH_Y + 0.02, SIGHT_Z + 0.02), m["steel"]))
    bevel_object(leaf, 0.0004, 1, 35.0)
    body.append(smooth(leaf, 35))
    if ROUND >= 2:
        # The slider on the leaf with its two catches, the range scale engraved along it.
        slider_y = 0.268
        slider_z = hinge.z + (leaf_end.z - hinge.z) * (hinge.y - slider_y) / (hinge.y - leaf_end.y)
        sl = box("Slider", (-0.0084, slider_y - 0.0045, slider_z - 0.0055), (0.0084, slider_y + 0.0045, slider_z + 0.0026), m["steel"], bevel=0.0009)
        rotate(sl, math.atan2(leaf_end.z - hinge.z, hinge.y - leaf_end.y), "X", Vector((0, slider_y, slider_z)))
        body.append(sl)
        for side in (-1.0, 1.0):
            body.append(cylinder("SliderCatch", (side * 0.0084, slider_y, slider_z - 0.001), (side * 0.0108, slider_y, slider_z - 0.001), 0.0024, m["steel"], 14, bevel=0.0006))
        # The hinge pin through the block.
        body.append(cylinder("HingePin", (-0.0125, hinge.y, hinge.z - 0.0015), (0.0125, hinge.y, hinge.z - 0.0015), 0.0019, m["bright"], 14))
        # The gas tube's lever on the right of the block, and its catch.
        lever = sweep("GasLever", [(0.2895, 0.0985), (0.281, 0.1075), (0.272, 0.1105)], 0.0009, 0.004, m["steel"], x=0.0131)
        body.append(lever)
        body.append(cylinder("LeverPivot", (0.0122, 0.2895, 0.0985), (0.0142, 0.2895, 0.0985), 0.003, m["steel"], 14, bevel=0.0005))
    if ROUND >= 3:
        # The range marks on the leaf: 1 to 10, in tiny steps (white lines), and the "П".
        for k in range(10):
            y = 0.2815 - k * 0.0038
            z = hinge.z + (leaf_end.z - hinge.z) * (hinge.y - y) / (hinge.y - leaf_end.y) + 0.0023
            body.append(box("Scale", (-0.0058, y - 0.00025, z - 0.0003), (-0.0028, y + 0.00025, z + 0.0002), m["marking"]))
    # --- the barrel, the front trunnion's collar round it, the gas tube above it
    body.append(cylinder("Barrel", (0, 0.230, BORE_Z), (0, FRONT_Y[1] + 0.003, BORE_Z), BARREL_R, m["barrel"], 28))
    if ROUND >= 2:
        # The barrel steps down in front of the gas block.
        body.append(cylinder("Chamber", (0, 0.230, BORE_Z), (0, 0.300, BORE_Z), BARREL_R + 0.0016, m["barrel"], 28))
    gas = cylinder("GasTube", (0, UPPER_Y[0] - 0.004, GAS_Z), (0, GAS_Y[0] + 0.002, GAS_Z), 0.0094, m["barrel"], 28)
    if ROUND >= 3:
        # Its vents, in front of the handguard: three round holes each side.
        for side in (-1.0, 1.0):
            for y in (0.4075, 0.4195, 0.4315):
                cut(gas, cylinder("vent", (side * 0.004, y, GAS_Z), (side * 0.02, y, GAS_Z), 0.0023, m["barrel"], 14))
    body.append(smooth(gas, 40))
    if ROUND >= 3:
        body.append(cylinder("GasInside", (0, 0.400, GAS_Z), (0, 0.440, GAS_Z), 0.0088, m["dark"], 20))
        body.append(cylinder("Piston", (0, 0.398, GAS_Z), (0, 0.442, GAS_Z), 0.0046, m["bright"], 16))
    if ROUND >= 2:
        # The ring the gas tube ends in at the gas block.
        body.append(cylinder("GasRing", (0, GAS_Y[0] - 0.006, GAS_Z), (0, GAS_Y[0] + 0.001, GAS_Z), 0.0103, m["barrel"], 28, bevel=0.0008))
    # --- the gas block: a collar round the barrel, the cylinder over it bent up at 45 degrees,
    # its front rounded; the front sling loop on its left.
    gb = cylinder("GasCollar", (0, GAS_Y[0], BORE_Z), (0, GAS_Y[1] - 0.008, BORE_Z), 0.0118, m["steel"], 28)
    union(gb, cylinder("GasCylinder", (0, GAS_Y[0], GAS_Z), (0, GAS_Y[1], GAS_Z), 0.0112, m["steel"], 28))
    web = box("web", (-0.0068, GAS_Y[0] + 0.003, BORE_Z), (0.0068, GAS_Y[1] - 0.012, GAS_Z), m["steel"])
    union(gb, web)
    if ROUND >= 2:
        # The front of the gas cylinder sloped back over the barrel.
        slope = box("slope", (-0.03, GAS_Y[1] - 0.006, BORE_Z + 0.002), (0.03, GAS_Y[1] + 0.03, GAS_Z + 0.03), m["steel"])
        rotate(slope, math.radians(-38.0), "X", Vector((0, GAS_Y[1] - 0.006, BORE_Z + 0.008)))
        cut(gb, slope)
    bevel_object(gb, 0.0015, 2, 35.0)
    body.append(smooth(gb, 35))
    if ROUND >= 2:
        loop_at = Vector((-0.0128, (GAS_Y[0] + GAS_Y[1]) * 0.5 - 0.004, BORE_Z - 0.003))
        lug = box("LoopLug", (loop_at.x - 0.003, loop_at.y - 0.006, loop_at.z - 0.003), (loop_at.x + 0.004, loop_at.y + 0.006, loop_at.z + 0.006), m["steel"], bevel=0.0012)
        body.append(lug)
        body.append(torus("SlingLoop", (loop_at.x - 0.004, loop_at.y, loop_at.z - 0.006), (0, 1, 0), 0.0072, 0.0014, m["steel"], 20, 8))
        # The pin through the block.
        for side in (-1.0, 1.0):
            body.append(cylinder("GasPin", (side * 0.0112, GAS_Y[0] + 0.012, BORE_Z + 0.0115), (side * 0.0121, GAS_Y[0] + 0.012, BORE_Z + 0.0115), 0.0017, m["bright"], 12))
    # --- the front sight: a collar round the barrel, a tower on it, the two ears that guard
    # the post, the post on its threaded drum; the bayonet lug below.
    fs = cylinder("FrontCollar", (0, FRONT_Y[0], BORE_Z), (0, FRONT_Y[1], BORE_Z), 0.0106, m["steel"], 28)
    tower = slab("Tower", fillet([(FRONT_Y[0] + 0.004, BORE_Z, 0.0), (FRONT_Y[0] + 0.0075, 0.1105, 0.003), (FRONT_Y[1] - 0.0075, 0.1105, 0.003), (FRONT_Y[1] - 0.002, BORE_Z, 0.0)], 4), -0.0050, 0.0050, m["steel"])
    union(fs, tower)
    base = box("EarBase", (-0.0086, POST_Y - 0.0082, 0.1045), (0.0086, POST_Y + 0.0082, 0.1112), m["steel"])
    union(fs, base)
    for side in (-1.0, 1.0):
        ear = slab("Ear", fillet([(POST_Y - 0.0072, 0.1050, 0.0), (POST_Y - 0.0072, SIGHT_Z + 0.0062, 0.003), (POST_Y + 0.0072, SIGHT_Z + 0.0062, 0.003), (POST_Y + 0.0072, 0.1050, 0.0)], 4),
                   side * 0.0064 - 0.0012, side * 0.0064 + 0.0012, m["steel"])
        union(fs, ear)
    if ROUND >= 2:
        # The lug below for the bayonet, and the hole the cleaning rod's head sits in.
        lug = box("BayonetLug", (-0.0036, FRONT_Y[0] + 0.006, BORE_Z - 0.0235), (0.0036, FRONT_Y[1] - 0.002, BORE_Z - 0.0170), m["steel"])
        union(lug, box("LugNeck", (-0.0036, FRONT_Y[0] + 0.006, BORE_Z - 0.019), (-0.0010, FRONT_Y[1] - 0.002, BORE_Z - 0.008), m["steel"]))
        union(fs, lug)
    bevel_object(fs, 0.0011, 2, 35.0)
    body.append(smooth(fs, 35))
    drum = cylinder("PostDrum", (0, POST_Y, 0.1095), (0, POST_Y, 0.1180), 0.0040, m["steel"], 20, bevel=0.0006)
    body.append(drum)
    body.append(cone("Post", (0, POST_Y, 0.1175), (0, POST_Y, SIGHT_Z), 0.0016, 0.0012, m["steel"], 14))
    if ROUND >= 3:
        # The drum's notches, which a tool turns it by to move the post up and down.
        for k in range(8):
            a = math.tau * k / 8
            body.append(box("DrumNotch", (math.cos(a) * 0.0040 - 0.0004, POST_Y + math.sin(a) * 0.0040 - 0.0004, 0.110), (math.cos(a) * 0.0040 + 0.0004, POST_Y + math.sin(a) * 0.0040 + 0.0004, 0.1176), m["dark"]))
        # The detent pin of the muzzle brake through the collar.
        body.append(cylinder("DetentPin", (0.0094, FRONT_Y[1] - 0.006, BORE_Z - 0.006), (0.0114, FRONT_Y[1] - 0.006, BORE_Z - 0.006), 0.0015, m["bright"], 12))
    # --- the muzzle brake: the AKM's, slanted at its front so that the gas pushes the
    # muzzle down; the barrel's thread behind it.
    brake = cylinder("Brake", (0, FRONT_Y[1] - 0.001, BORE_Z), (0, MUZZLE_Y, BORE_Z), 0.0102, m["barrel"], 28)
    if ROUND >= 2:
        # The face cut at a slant: from the top, 12 mm short of the muzzle, down to the full
        # length at the bottom.
        top = Vector((0.0, MUZZLE_Y - 0.0125, BORE_Z + 0.0102))
        slant = box("slant", (-0.03, top.y, top.z), (0.03, top.y + 0.05, top.z + 0.05), m["barrel"])
        rotate(slant, math.radians(-58.0), "X", top)
        cut(brake, slant)
        cut(brake, cylinder("bore", (0, MUZZLE_Y - 0.03, BORE_Z), (0, MUZZLE_Y + 0.01, BORE_Z), 0.0048, m["barrel"], 20))
    bevel_object(brake, 0.0008, 2, 35.0)
    body.append(smooth(brake, 35))
    if ROUND >= 2:
        # Inside the brake: the barrel's crown, its bore dark.
        body.append(cylinder("Muzzle", (0, MUZZLE_Y - 0.03, BORE_Z), (0, MUZZLE_Y - 0.017, BORE_Z), 0.0047, m["barrel"], 18))
        body.append(cylinder("BoreDeep", (0, MUZZLE_Y - 0.0175, BORE_Z), (0, MUZZLE_Y - 0.0168, BORE_Z), BORE_R, m["dark"], 18))
    else:
        body.append(cylinder("Bore", (0, MUZZLE_Y - 0.026, BORE_Z), (0, MUZZLE_Y - 0.004, BORE_Z), 0.0046, m["dark"], 20))
    # --- the cleaning rod under the barrel, its head in the front sight's base
    rod_z = BORE_Z - 0.0148
    body.append(cylinder("CleaningRod", (0, GUARD_Y[1] - 0.004, rod_z), (0, FRONT_Y[1] - 0.004, rod_z), 0.0029, m["bright"], 14))
    if ROUND >= 2:
        body.append(cylinder("RodHead", (0, FRONT_Y[0] - 0.006, rod_z), (0, FRONT_Y[1] - 0.003, rod_z), 0.0041, m["steel"], 16, bevel=0.0007))
        # The spring that holds it, a strap under the gas block.
        body.append(box("RodClip", (-0.0035, GAS_Y[0] + 0.004, rod_z - 0.0036), (0.0035, GAS_Y[1] - 0.006, BORE_Z - 0.006), m["steel"], bevel=0.0008))
    # --- the lower handguard: wood, lofted along its length; the steel retainer at its front
    rings = [guard_section(GUARD_Y[0] + (GUARD_Y[1] - GUARD_Y[0]) * k / 14) for k in range(15)]
    lower = loft("LowerGuard", rings, m["wood"])
    if ROUND >= 2:
        # The channel the barrel lies in shows at the ends; the finger grooves along its sides.
        cut(lower, cylinder("bed", (0, GUARD_Y[0] - 0.01, BORE_Z), (0, GUARD_Y[1] + 0.01, BORE_Z), BARREL_R + 0.0025, m["wood"], 24))
        for side in (-1.0, 1.0):
            g = cylinder("groove", (side * 0.0180, GUARD_Y[0] + 0.048, 0.0690), (side * 0.0180, GUARD_Y[1] - 0.012, 0.0690), 0.0026, m["wood"], 16)
            cut(lower, g)
    bevel_object(lower, 0.0012, 2, 40.0)
    body.append(smooth(lower, 45))
    if ROUND >= 2:
        band = loft("Retainer", [guard_section(GUARD_Y[1] - 0.003, 0.0008), guard_section(GUARD_Y[1] + 0.006, 0.0008)], m["steel"])
        cut(band, cylinder("bed", (0, GUARD_Y[1] - 0.02, BORE_Z), (0, GUARD_Y[1] + 0.02, BORE_Z), BARREL_R + 0.0005, m["steel"], 24))
        bevel_object(band, 0.0007, 2, 40.0)
        body.append(smooth(band, 45))
        # Its lever on the right, turned down (locked).
        body.append(sweep("RetainerLever", [(GUARD_Y[1] + 0.002, 0.0845), (GUARD_Y[1] + 0.001, 0.0705), (GUARD_Y[1] - 0.006, 0.0645)], 0.0009, 0.0055, m["steel"], x=0.0196))
        body.append(cylinder("RetainerPivot", (0.0186, GUARD_Y[1] + 0.002, 0.0845), (0.0212, GUARD_Y[1] + 0.002, 0.0845), 0.0028, m["steel"], 14, bevel=0.0005))
        # The rear ferrule: a steel cap where the handguard meets the receiver.
        ferrule = loft("Ferrule", [guard_section(REC_Y[1] - 0.002, 0.0006), guard_section(GUARD_Y[0] + 0.004, 0.0006)], m["steel"])
        bevel_object(ferrule, 0.0006, 2, 40.0)
        body.append(smooth(ferrule, 45))
    # --- the upper handguard over the gas tube
    up_profile = fillet([(0.0131, 0.0912, 0.0015), (0.0131, 0.1050, 0.006), (0.0040, 0.1172, 0.006), (-0.0040, 0.1172, 0.006), (-0.0131, 0.1050, 0.006), (-0.0131, 0.0912, 0.0015)], 6)
    upper = prism("UpperGuard", up_profile, UPPER_Y[0], UPPER_Y[1], m["wood"])
    if ROUND >= 2:
        cut(upper, cylinder("bed", (0, UPPER_Y[0] - 0.01, GAS_Z), (0, UPPER_Y[1] + 0.01, GAS_Z), 0.0097, m["wood"], 24))
        # Its front end rounded off downwards.
        nose = box("nose", (-0.03, UPPER_Y[1] - 0.010, 0.106), (0.03, UPPER_Y[1] + 0.03, 0.13), m["wood"])
        rotate(nose, math.radians(-30.0), "X", Vector((0, UPPER_Y[1] - 0.010, 0.106)))
        cut(upper, nose)
    bevel_object(upper, 0.0016, 3, 35.0)
    body.append(smooth(upper, 45))
    if ROUND >= 2:
        # Its steel cap at the back, under the rear sight's block.
        body.append(prism("UpperCap", fillet([(0.0134, 0.0905, 0.001), (0.0134, 0.1052, 0.006), (0.0042, 0.1178, 0.006), (-0.0042, 0.1178, 0.006), (-0.0134, 0.1052, 0.006), (-0.0134, 0.0905, 0.001)], 6), UPPER_Y[0] - 0.002, UPPER_Y[0] + 0.0045, m["steel"]))
    # --- the stock: wood, lofted from the receiver to the butt plate
    ys = [REC_Y[0] + 0.004 + (STOCK_END + 0.006 - REC_Y[0] - 0.004) * k / 16 for k in range(17)]
    stock = loft("Stock", [stock_section(y) for y in ys], m["wood"])
    bevel_object(stock, 0.0015, 2, 40.0)
    body.append(smooth(stock, 45))
    # The butt plate: steel, its trap for the cleaning kit, the button that opens it.
    plate = loft("ButtPlate", [stock_section(STOCK_END + 0.0062, 0.0004), stock_section(STOCK_END, 0.0004)], m["steel"])
    if ROUND >= 3:
        for z in (0.018, 0.034, 0.050):
            cut(plate, box("pg", (-0.03, STOCK_END - 0.002, z - 0.0007), (0.03, STOCK_END + 0.0009, z + 0.0007), m["steel"]))
    bevel_object(plate, 0.0012, 2, 40.0)
    body.append(smooth(plate, 40))
    if ROUND >= 2:
        trap = box("TrapLid", (-0.0118, STOCK_END - 0.0012, -0.006), (0.0118, STOCK_END + 0.001, 0.009), m["steel"], bevel=0.001)
        body.append(trap)
        body.append(box("TrapSeam", (-0.0126, STOCK_END - 0.0006, -0.0068), (0.0126, STOCK_END + 0.001, 0.0098), m["dark"]))
        body.append(cylinder("TrapButton", (0, STOCK_END - 0.0006, 0.0205), (0, STOCK_END - 0.003, 0.0205), 0.0034, m["bright"], 16, bevel=0.0006))
        # The tangs of the rear trunnion along the top and the bottom of the stock's neck, and
        # their screws.
        top = 0.0935 + (0.0815 - 0.0935) * ((REC_Y[0] - 0.060) - REC_Y[0]) / (STOCK_END + 0.006 - REC_Y[0])
        tang = slab("TopTang", [(REC_Y[0] + 0.003, 0.0925), (REC_Y[0] + 0.003, 0.0958), (REC_Y[0] - 0.066, top + 0.0024), (REC_Y[0] - 0.071, top - 0.0006), (REC_Y[0] - 0.060, top - 0.0008)], -0.0062, 0.0062, m["steel"])
        bevel_object(tang, 0.0012, 2, 35.0)
        body.append(smooth(tang, 35))
        body.append(cylinder("TangScrew", (0, REC_Y[0] - 0.058, top + 0.002), (0, REC_Y[0] - 0.058, top + 0.0036), 0.0033, m["bright"], 16, bevel=0.0006))
        lowtang = sweep("LowTang", [(REC_Y[0] + 0.004, 0.0502), (REC_Y[0] - 0.040, 0.0502 + (-0.0305 - 0.0505) * 0.044 / 0.2435 - 0.0006)], 0.0058, 0.0028, m["steel"])
        body.append(lowtang)
        # The rear sling loop on the stock's left near the butt, on its plate.
        sy = STOCK_END + 0.045
        t = (sy - REC_Y[0]) / (STOCK_END + 0.006 - REC_Y[0])
        half = 0.0122 + (0.0196 - 0.0122) * min(1.0, t * 1.15)
        zc = (0.0505 + (-0.0305 - 0.0505) * t) + 0.012
        body.append(box("LoopPlate", (-half - 0.0012, sy - 0.012, zc - 0.006), (-half + 0.001, sy + 0.012, zc + 0.006), m["steel"], bevel=0.001))
        body.append(torus("RearLoop", (-half - 0.0022, sy, zc - 0.0045), (1, 0, 0), 0.0068, 0.0014, m["steel"], 20, 8))
        for k in (-1.0, 1.0):
            body.append(cylinder("LoopScrew", (-half - 0.0014, sy + k * 0.0085, zc + 0.002), (-half - 0.0024, sy + k * 0.0085, zc + 0.002), 0.0019, m["bright"], 12))
    # --- the pistol grip: bakelite, its chequered sides; the screw at its foot
    top_c = Vector((0.0, 0.0205, 0.052))
    foot_c = Vector((0.0, -0.0085, -0.0435))
    axis = foot_c - top_c
    down = axis.normalized()
    fwd = Vector((0.0, -down.z, down.y))
    if fwd.y < 0:
        fwd = -fwd
    grip_rings = []
    steps = [(0.0, 0.0212, 0.0122), (0.12, 0.0206, 0.0132), (0.35, 0.0198, 0.0141), (0.6, 0.0203, 0.0144), (0.85, 0.0210, 0.0144), (1.0, 0.0207, 0.0141), (1.035, 0.0188, 0.0126)]
    for t, a, b in steps:
        c = top_c + axis * t + fwd * (-0.0012 * math.sin(math.pi * min(t, 1.0)))
        grip_rings.append([tuple(c + Vector((px, 0, 0)) + fwd * pv) for px, pv in superellipse(b, a, 2.4, 28)])
    grip = loft("Grip", grip_rings, m["bakelite"])
    bevel_object(grip, 0.002, 2, 40.0)
    smooth(grip, 50)
    if ROUND >= 3:
        # Chequering on the flats of its sides, between a smooth border.
        grip.data.materials.append(m["chequer"])
        for poly in grip.data.polygons:
            c = poly.center
            t = (c - top_c).dot(down) / axis.length
            if abs(poly.normal.x) > 0.72 and 0.12 < t < 0.9 and abs((c - top_c - axis * t).dot(fwd)) < 0.0135:
                poly.material_index = 1
    body.append(grip)
    if ROUND >= 2:
        body.append(cylinder("GripScrew", tuple(foot_c + down * 0.0045), tuple(foot_c + down * 0.0062), 0.0042, m["steel"], 18, bevel=0.0006))
        body.append(box("GripSlot", tuple(foot_c + down * 0.0060 - Vector((0.0006, 0.0035, 0.0006))), tuple(foot_c + down * 0.0066 + Vector((0.0006, 0.0035, 0.0006))), m["dark"]))
    # --- the trigger guard: a flat strip bent round from before the trigger to the grip
    guard_path = fillet([(0.1165, 0.0495, 0.0), (0.1135, 0.0200, 0.010), (0.0450, 0.0170, 0.012), (0.0300, 0.0420, 0.0)], 6)
    guard = sweep("TriggerGuard", guard_path, 0.0056, 0.0028, m["steel"])
    bevel_object(guard, 0.0006, 1, 35.0)
    body.append(smooth(guard, 40))
    if ROUND >= 2:
        # Its front rivets, and the magazine catch: a paddle before it.
        for y in (0.112, 0.124):
            body.append(cylinder("GuardRivet", (0, y, z0 - 0.0008), (0, y, z0 + 0.001), 0.0021, m["steel"], 12))
        catch = sweep("MagCatch", fillet([(0.1400, 0.0495, 0.0), (0.1395, 0.0360, 0.005), (0.1205, 0.0290, 0.0)], 4), 0.0074, 0.0030, m["steel"])
        bevel_object(catch, 0.0006, 1, 35.0)
        body.append(smooth(catch, 40))
        body.append(cylinder("CatchPin", (-W - 0.0004, 0.1335, 0.0525), (W + 0.0004, 0.1335, 0.0525), 0.0016, m["bright"], 12))
        body.append(box("CatchHousing", (-0.0068, 0.1290, 0.0445), (0.0068, 0.1410, 0.0492), m["steel"], bevel=0.0008))
    # --- the trigger
    blade = sweep("TriggerBlade", [(0.0660, 0.0560), (0.0675, 0.0465), (0.0668, 0.0365), (0.0632, 0.0290), (0.0580, 0.0255)], 0.0030, 0.0042, m["steel"])
    bevel_object(blade, 0.0008, 2, 35.0)
    trig.append(smooth(blade, 40))
    # --- rivets and pins of the stamped receiver
    if ROUND >= 2:
        rivets = [(0.2215, 0.0560), (0.2305, 0.0620), (0.2230, 0.0695),                    # the front trunnion
                  (-0.0055, 0.0590), (-0.0055, 0.0730), (0.0055, 0.0660),                  # the rear trunnion
                  (0.028, 0.0545), (0.046, 0.0545)]                                        # the centre support
        for y, z in rivets:
            for side in (-1.0, 1.0):
                r = cylinder("Rivet", (side * (W - 0.0003), y, z), (side * (W + 0.0008), y, z), 0.0021, m["steel"], 14)
                bevel_object(r, 0.0005, 2, 35.0)
                body.append(smooth(r, 50))
        # The pins of the trigger, the hammer and the auto sear, their heads on the left, the
        # "shepherd's crook" spring's hook over them.
        for y, z, r in ((0.066, 0.0560, 0.0026), (0.0905, 0.0620, 0.0026), (0.1085, 0.0725, 0.0022)):
            for side in (-1.0, 1.0):
                body.append(cylinder("Pin", (side * (W - 0.0004), y, z), (side * (W + 0.0006), y, z), r, m["bright"], 14))
        if ROUND >= 3:
            body.append(sweep("Crook", [(0.0655, 0.0532), (0.072, 0.0505), (0.084, 0.0505), (0.0905, 0.0590)], 0.0005, 0.0010, m["bright"], x=-W - 0.0008))
    # --- the selector: the long lever on the right over the slot below the port, its pivot
    # at the back, its tab at the front, set to automatic; the stops stamped for it
    if ROUND >= 2:
        pivot = Vector((W + 0.0012, 0.0045, 0.0840))
        outline = fillet([(0.0045 - 0.0085, 0.0840, 0.008), (0.0045, 0.0840 + 0.0085, 0.006), (0.1210, 0.0915, 0.002), (0.1290, 0.0900, 0.002), (0.1290, 0.0690, 0.004),
                          (0.1180, 0.0690, 0.004), (0.1150, 0.0790, 0.002), (0.0045, 0.0840 - 0.0085, 0.006)], 4)
        lever = slab("Selector", outline, W + 0.0006, W + 0.0019, m["steel"])
        rotate(lever, math.radians(-7.0), "X", pivot)
        bevel_object(lever, 0.0005, 1, 35.0)
        body.append(smooth(lever, 40))
        body.append(cylinder("SelectorPivot", (W + 0.0012, pivot.y, pivot.z), (W + 0.0032, pivot.y, pivot.z), 0.0042, m["steel"], 18, bevel=0.0008))
        body.append(cylinder("SelectorPin", (W + 0.0028, pivot.y, pivot.z), (W + 0.0036, pivot.y, pivot.z), 0.0021, m["bright"], 14))
    # --- the bolt carrier and its handle (the Bolt node), seen in the port; the bolt below it
    carrier = box("Carrier", (-0.0105, 0.100, 0.0858), (0.0125, 0.2145, 0.0952), m["bright"], bevel=0.0012)
    bolt.append(carrier)
    if ROUND >= 2:
        # The carrier's lower part behind the bolt, the bolt itself at the bore, its extractor
        # on the right, the cam lug that turns it.
        bolt.append(box("CarrierLow", (-0.0095, 0.100, 0.0745), (0.0105, 0.186, 0.0870), m["bright"], bevel=0.0012))
        bolt.append(cylinder("BoltHead", (0.0, 0.186, BORE_Z + 0.0005), (0.0, 0.2355, BORE_Z + 0.0005), 0.0069, m["bright"], 22, bevel=0.0006))
        bolt.append(box("Extractor", (0.0058, 0.203, BORE_Z - 0.0025), (0.0080, 0.2348, BORE_Z + 0.0045), m["steel"], bevel=0.0005))
        bolt.append(box("CamLug", (0.0035, 0.1885, BORE_Z + 0.004), (0.0092, 0.1990, 0.0866), m["bright"], bevel=0.0006))
    # The handle: out of the carrier's right side, a round knob at its end.
    arm = cylinder("HandleArm", (0.0115, HANDLE.y, 0.0905), (HANDLE.x - 0.004, HANDLE.y, HANDLE.z), 0.0032, m["bright"], 16)
    bolt.append(arm)
    bolt.append(box("HandleRoot", (0.0105, HANDLE.y - 0.0055, 0.0868), (0.0168, HANDLE.y + 0.0055, 0.0948), m["bright"], bevel=0.0008))
    knob = lathe("HandleKnob", (HANDLE.x - 0.0085, HANDLE.y, HANDLE.z), (HANDLE.x + 0.0012, HANDLE.y, HANDLE.z),
                 [(0.0, 0.0034), (0.25, 0.0058), (0.6, 0.0064), (0.88, 0.0058), (1.0, 0.0038)], m["bright"], 24)
    bolt.append(smooth(knob, 60))
    if ROUND >= 3:
        for k in range(5):
            x = HANDLE.x - 0.0065 + k * 0.0015
            bolt.append(cylinder("KnobGroove", (x - 0.0002, HANDLE.y, HANDLE.z), (x + 0.0002, HANDLE.y, HANDLE.z), 0.0066, m["steel"], 20))
    # --- markings: the serial and the year on the left of the receiver, the selector's
    # positions on the right (АВ automatic, ОД single), the factory's arrow in a triangle
    if ROUND >= 3:
        body.append(engrave_left("НВ 1974", Vector((-W - 0.0003, 0.095, 0.0835)), 0.0052, m["marking"]))
        body.append(engrave_left("№ 0473", Vector((-W - 0.0003, 0.040, 0.0665)), 0.0040, m["marking"]))
        body.append(engrave_right("АВ", Vector((W + 0.0003, 0.1325, 0.0628)), 0.0036, m["marking"]))
        body.append(engrave_right("ОД", Vector((W + 0.0003, 0.1325, 0.0545)), 0.0036, m["marking"]))
        tri = slab("Arrow", [(0.0, 0.0), (-0.0056, 0.0), (-0.0028, 0.0050)], -W - 0.0004, -W - 0.0001, m["marking"])
        tri.data.transform(Matrix.Translation((0.0, 0.140, 0.0640)))
        body.append(tri)
    # --- the magazine: steel, curved; the ribs pressed into its sides, the lugs at its top,
    # the floor plate, and the top round between its lips
    rf, rr = MAG_R
    phi_f = math.asin((MAG_C.y - MAG_TOP) / rf)
    phi_r = math.asin((MAG_C.y - MAG_TOP) / rr)
    outline = [tuple(mag_point(rf, phi_f + (MAG_END - phi_f) * k / 24)) for k in range(25)]
    outline += [tuple(mag_point(mag_back(MAG_END - (MAG_END - phi_r) * k / 24), MAG_END - (MAG_END - phi_r) * k / 24)) for k in range(25)]
    shell = slab("MagBody", outline, -MAG_W, MAG_W, m["magsteel"])
    if ROUND >= 4:
        # Its top, the part that goes into the well, is narrower: it passes the well's dimples.
        for side in (-1.0, 1.0):
            cut(shell, box("neck", (side * 0.0131 - (0.0 if side > 0 else 0.02), 0.10, 0.0505), (side * 0.0131 + (0.02 if side > 0 else 0.0), 0.30, 0.09), m["magsteel"]))
    bevel_object(shell, 0.0022 if ROUND >= 2 else 0.003, 3, 30.0)
    mag.append(smooth(shell, 35))
    if ROUND >= 2:
        # Two ribs down each side, following the curve, and the welded spine at the back.
        for side in (-1.0, 1.0):
            for r0, r1 in ((rf + 0.0115, rf + 0.0180), (rf + 0.0355, rf + 0.0420)):
                rib = slab("MagRib", mag_band(r0, r1, phi_f + 0.07, MAG_END - 0.035), side * MAG_W - 0.0006, side * (MAG_W + 0.0006), m["magsteel"])
                bevel_object(rib, 0.0007, 3, 30.0)
                mag.append(smooth(rib, 35))
        steps = 20
        a0, a1 = phi_r + 0.02, MAG_END - 0.01
        band = [tuple(mag_point(mag_back(a0 + (a1 - a0) * k / steps) - 0.0006, a0 + (a1 - a0) * k / steps)) for k in range(steps + 1)]
        band += [tuple(mag_point(mag_back(a1 - (a1 - a0) * k / steps) + 0.0012, a1 - (a1 - a0) * k / steps)) for k in range(steps + 1)]
        spine = slab("Spine", band, -0.0062, 0.0062, m["magsteel"])
        bevel_object(spine, 0.0005, 1, 30.0)
        mag.append(smooth(spine, 35))
        # The lugs: at the front the one it is rocked in by, at the back the one the catch holds.
        mag.append(box("FrontLug", (-0.0075, mag_point(rf, phi_f).x - 0.002, 0.0555), (0.0075, mag_point(rf, phi_f).x + 0.0045, 0.0655), m["magsteel"], bevel=0.0012))
        mag.append(box("RearLug", (-0.0072, mag_point(rr, phi_r).x - 0.0052, 0.0505), (0.0072, mag_point(rr, phi_r).x + 0.002, 0.0585), m["magsteel"], bevel=0.0012))
        # The floor plate: a little proud all round, its tab sticking out at the back.
        d = 0.0052 / ((rf + rr) * 0.5)
        back = mag_back(MAG_END)
        plate = [tuple(mag_point(rf - 0.0028, MAG_END - 0.001)), tuple(mag_point(back + 0.0075, MAG_END - 0.001)),
                 tuple(mag_point(back + 0.0075, MAG_END + d)), tuple(mag_point(rf - 0.0028, MAG_END + d))]
        fp = slab("FloorPlate", plate, -MAG_W - 0.0016, MAG_W + 0.0016, m["magsteel"])
        bevel_object(fp, 0.0016, 2, 35.0)
        mag.append(smooth(fp, 35))
        if ROUND >= 3:
            # Its lock: the round boss of the catch through it, and its rolled edges.
            centre = mag_point((rf + back) * 0.5 + 0.012, MAG_END + d)
            out = Vector((0.0, math.sin(MAG_END), -math.cos(MAG_END)))
            at = Vector((0.0, centre.x, centre.y))
            boss = cylinder("PlateLock", tuple(at - out * 0.0005), tuple(at + out * 0.0012), 0.0042, m["magsteel"], 18, bevel=0.0004)
            mag.append(boss)
        # The lips at the top and the round between them, its bullet towards the muzzle.
        for side in (-1.0, 1.0):
            mag.append(box("Lip", (side * (MAG_W - 0.0012) - 0.0016, 0.1505, MAG_TOP - 0.001), (side * (MAG_W - 0.0012) + 0.0016, 0.2005, MAG_TOP + 0.0032), m["magsteel"], bevel=0.0007))
        rz = MAG_TOP + 0.0022
        base_y = 0.1505
        rx = 0.0038
        case = lathe("Round", (rx, base_y, rz), (rx, base_y + 0.0565, rz + 0.0018),
                     [(0.0, 0.0050), (0.02, 0.0056), (0.04, 0.0056), (0.06, 0.0050), (0.08, 0.0056), (0.52, 0.0052), (0.58, 0.0044),
                      (0.66, 0.0041), (0.69, 0.0041)], m["lacquer"], 20)
        mag.append(smooth(case, 50))
        bullet = lathe("Bullet", (rx, base_y + 0.0565 * 0.69, rz + 0.0018 * 0.69), (rx, base_y + 0.0565, rz + 0.0018),
                       [(0.0, 0.0039), (0.35, 0.0039), (0.7, 0.0030), (0.92, 0.0015), (1.0, 0.0004)], m["copper"], 20)
        mag.append(smooth(bullet, 50))
    return body, mag, bolt, trig


def engrave_left(text, at, size, material):
    """Flat lettering on the left face, reading from the muzzle backwards as one sees it
    from the left; 'at' is where its first letter begins."""
    return _letters(text, at, size, material, Matrix(((0.0, 0.0, -1.0, 0.0), (-1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0))))


def engrave_right(text, at, size, material):
    """Flat lettering on the right face, reading towards the muzzle."""
    return _letters(text, at, size, material, Matrix(((0.0, 0.0, 1.0, 0.0), (1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0))))


def _letters(text, at, size, material, turn):
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
    letters.data.transform(Matrix.Translation(at) @ turn)
    letters.data.materials.clear()
    letters.data.materials.append(material)
    return letters


# ------------------------------------------------------------------ bake
def bake(objs, prefix):
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


# ------------------------------------------------------------------ review pictures
CENTRE = (0.0, 0.19, 0.04)
VIEWS = [
    # name, camera, target, lens (mm)
    ("schraeg", (-0.95, 0.95, 0.42), (0.0, 0.2, 0.04), 55),
    ("links", (-1.95, 0.19, 0.04), CENTRE, 70),
    ("rechts", (1.95, 0.19, 0.04), CENTRE, 70),
    ("hinten_schraeg", (-0.50, -0.80, 0.42), (0.0, 0.12, 0.07), 50),
    ("oben", (0.0, 0.19, 1.95), (0.0, 0.19, 0.0), 70),
    ("unten", (-0.55, 0.2, -1.2), (0.0, 0.2, 0.0), 60),
    ("nah_visier", (-0.22, 0.02, 0.24), (0.0, 0.26, 0.11), 55),
    ("nah_vorn", (-0.30, 0.82, 0.18), (0.0, 0.54, 0.09), 55),
    ("nah_rechts", (0.42, 0.06, 0.18), (0.0, 0.14, 0.07), 55),
    ("nah_magazin", (-0.40, 0.42, -0.12), (0.0, 0.2, -0.02), 55),
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


def render_views(folder, prefix, only=None, views=None, centre=None):
    """Renders the fixed views (another gun's script passes its own views and middle)."""
    views = views or VIEWS
    centre = centre or CENTRE
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    use_gpu(scene)
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1400, 820
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    scene.world = world
    background = world.node_tree.nodes["Background"]
    cam = link(bpy.data.objects.new("cam", bpy.data.cameras.new("cam")))
    scene.camera = cam
    cam.data.clip_start = 0.01
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0, centre[1], centre[2] - 0.23))
    floor = bpy.context.active_object
    floor_mat = bpy.data.materials.new("floor")
    floor_mat.use_nodes = True
    floor.data.materials.append(floor_mat)
    setups = {
        "studio": [("key", "AREA", (-1.2, -0.4, 1.4), centre, 55.0, (1.0, 0.97, 0.92), 1.4),
                   ("fill", "AREA", (1.3, 0.6, 0.6), centre, 18.0, (0.85, 0.9, 1.0), 1.5),
                   ("rim", "AREA", (0.2, 1.6, 1.0), centre, 40.0, (1.0, 1.0, 1.0), 0.9)],
        "nacht": [("lamp", "POINT", (-0.6, -0.1, 0.8), centre, 30.0, (1.0, 0.72, 0.45), 0.1),
                  ("cold", "AREA", (0.5, 1.3, 0.5), centre, 22.0, (0.45, 0.6, 1.0), 0.6)],
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


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_image_quality=90)
    print("EXPORTED", path, os.path.getsize(path), "bytes")


def main():
    clear()
    m = make_materials()
    body_parts, mag_parts, bolt_parts, trigger_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(mag_parts, "Magazine")
    bolt = join(bolt_parts, "Bolt")
    trigger = join(trigger_parts, "Trigger")
    parts = (body, magazine, bolt, trigger)
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
        images = bake(list(parts), "ak47")
        final = final_material(images, "ak47")
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(final)
    place_origin(magazine, MAG_ORIGIN)
    place_origin(bolt, HANDLE)
    place_origin(trigger, TRIGGER_PIVOT)
    root = link(bpy.data.objects.new("AK47", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "magazine", triangles(magazine), "bolt", triangles(bolt), "trigger", triangles(trigger),
          "all", sum(triangles(o) for o in parts), "texture", TEX)
    if RENDER:
        render_views(os.path.abspath(RENDER), PREFIX, arg("--only", "").split(",") if arg("--only") else None)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    rf, rr = MAG_R
    foot = (mag_point(rf, MAG_END) + mag_point(mag_back(MAG_END), MAG_END)) * 0.5
    print("SPEC muzzle", godot((0, MUZZLE_Y, BORE_Z)), "bore %.4f" % BORE_R, "rail (cover top) %.4f irons %.4f notch %s post %s" % (COVER_TOP, SIGHT_Z, godot((0, NOTCH_Y, SIGHT_Z)), godot((0, POST_Y, SIGHT_Z))))
    print("SPEC handle", godot(HANDLE), "bolt travel %.3f" % BOLT_TRAVEL, "trigger", godot(TRIGGER_PIVOT), "magazine", godot(MAG_ORIGIN), "support", godot(SUPPORT))
    print("SPEC magazine_foot", godot((0.0, foot.x, foot.y - 0.006)), "eject", godot((0.016, 0.160, 0.090)))
    if BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
    if NOBAKE:
        return
    export(parts + (root,), OUT)
    # The soldiers' copy: the moving parts back in the body, far fewer triangles, smaller
    # pictures. The same nodes AK47 > Body / Magazine at the same places.
    bpy.ops.object.select_all(action="DESELECT")
    for o in (bolt, trigger):
        o.parent = None
        o.select_set(True)
    for o in (bolt, trigger):
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    body.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for o in (body, bolt, trigger):
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Body"
    body.parent = root
    # (The magazine is thinned by merging flat faces: collapsing its long thin faces tore
    # it into spikes.)
    mod = body.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = 0.16
    mod.use_collapse_triangulate = True
    apply(body, mod)
    mod = magazine.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "DISSOLVE"
    mod.angle_limit = math.radians(8.0)
    mod.delimit = {"UV"}
    apply(magazine, mod)
    for img in bpy.data.images:
        if img.name.startswith("ak47_") and img.size[0] > 1024:
            img.scale(1024, 1024)
    print("LOW triangles body", triangles(body), "magazine", triangles(magazine))
    export((body, magazine, root), LOW)


# (blender_make_mg.py borrows the helpers above: then this is not run.)
if __name__ == "__main__":
    main()
