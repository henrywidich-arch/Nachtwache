# Builds the HORNISSE, a compact machine pistol for Nachtwache, from nothing: every part is
# made here, bevelled, given its material, UV-unwrapped and baked into one texture set
# (base colour, roughness and metal, normal), then written as a GLB with the nodes
# Hornet > Body / Magazine (and Breech, the slide, from round 4), like the other guns whose
# magazine leaves them.
#
#   blender --background --factory-startup --python tools/blender_make_hornet.py -- [--round 5] [--tex 2048] [--out assets/models/hornet.glb] [--blend <file>]
#
# --round: how far the polish goes (1: the forms, 2: the working parts and the surface,
# 3: the small parts, the markings and the wear, 4: the grip's form, the selector, holster
# wear and scratches, the slide a part of its own, 5: guard, trigger and frame, the wear
# toned down). The game uses round 5.
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle of
# the pistol grip. The glTF exporter turns this into Godot space (barrel along -Z, up +Y).
# The places the game needs (GUNS["hornet"] in weapon_view.gd) are printed at the end.
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
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "hornet.glb")))
BLEND = arg("--blend")

# ------------------------------------------------------------------ the measures
BORE_Z = 0.060            # the bore axis above the middle of the grip
SLIDE = (-0.060, 0.120)   # the slide from its back to its face (y)
SLIDE_Z = (0.046, 0.081)
SLIDE_W = 0.0245
FRAME_Z = (0.027, 0.048)
FRAME_Y = (-0.052, 0.117)
FRAME_W = 0.0262
GRIP_TILT = math.radians(-17.0)  # the grip leans back towards its foot (its foot towards -y)
MAG_FOOT = -0.128                # the lowest point of the extended magazine (z, before tilt)

SERRATIONS = 9


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
def material(name, base, rough, metal, wear=0.0, grime=0.0, bump=0.0, bump_scale=900.0, stipple=False, worn=(0.48, 0.47, 0.45), rub=0.0, scratches=0.0):
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
                bev.inputs["Radius"].default_value = 0.0009 if ROUND == 3 else 0.0014
                bev.samples = 8
                dot = nodes.new("ShaderNodeVectorMath")
                dot.operation = "DOT_PRODUCT"
                links.new(bev.outputs["Normal"], dot.inputs[0])
                links.new(geo.outputs["Normal"], dot.inputs[1])
                edge.inputs[1].default_value = 0.995 if ROUND == 3 else 0.997
                edge.inputs[2].default_value = 0.93 if ROUND == 3 else 0.9
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
                occ.inputs["Distance"].default_value = 0.005 if ROUND == 3 else 0.008
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
            gmix.inputs[7].default_value = (0.018, 0.016, 0.013, 1.0) if ROUND <= 3 else (0.034, 0.028, 0.019, 1.0)
            out_colour = gmix.outputs[2]
            grough = nodes.new("ShaderNodeMix")
            links.new(amount.outputs[0], grough.inputs[0])
            links.new(out_rough, grough.inputs[2])
            grough.inputs[3].default_value = 0.85
            out_rough = grough.outputs[0]
    if ROUND >= 4 and (rub > 0.0 or scratches > 0.0):
        geo4 = nodes.new("ShaderNodeNewGeometry")
        if rub > 0.0:
            # Holster and hand wear (round 4): broad, polished patches on the flat sides,
            # where a holster and the hand rub, broken up by a large noise.
            side = nodes.new("ShaderNodeSeparateXYZ")
            links.new(geo4.outputs["Normal"], side.inputs[0])
            flat = nodes.new("ShaderNodeMath")
            flat.operation = "ABSOLUTE"
            links.new(side.outputs["X"], flat.inputs[0])
            patch = nodes.new("ShaderNodeTexNoise")
            patch.inputs["Scale"].default_value = 38.0
            patch.inputs["Detail"].default_value = 4.0
            links.new(coords.outputs["Object"], patch.inputs["Vector"])
            patchy = nodes.new("ShaderNodeMapRange")
            patchy.inputs[1].default_value = 0.56
            patchy.inputs[2].default_value = 0.62
            links.new(patch.outputs["Fac"], patchy.inputs[0])
            place = nodes.new("ShaderNodeSeparateXYZ")
            links.new(coords.outputs["Object"], place.inputs[0])
            ahead = nodes.new("ShaderNodeMapRange")
            ahead.inputs[1].default_value = 0.045
            ahead.inputs[2].default_value = 0.115
            links.new(place.outputs["Y"], ahead.inputs[0])
            if ROUND >= 5:
                beyond = nodes.new("ShaderNodeMapRange")
                beyond.inputs[1].default_value = 0.121
                beyond.inputs[2].default_value = 0.117
                links.new(place.outputs["Y"], beyond.inputs[0])
                both = nodes.new("ShaderNodeMath")
                both.operation = "MULTIPLY"
                links.new(ahead.outputs[0], both.inputs[0])
                links.new(beyond.outputs[0], both.inputs[1])
                ahead = both
            sides = nodes.new("ShaderNodeMath")
            sides.operation = "MULTIPLY"
            links.new(flat.outputs[0], sides.inputs[0])
            links.new(ahead.outputs[0], sides.inputs[1])
            rubbed = nodes.new("ShaderNodeMath")
            rubbed.operation = "MULTIPLY"
            links.new(sides.outputs[0], rubbed.inputs[0])
            links.new(patchy.outputs[0], rubbed.inputs[1])
            strength = nodes.new("ShaderNodeMath")
            strength.operation = "MULTIPLY"
            strength.inputs[1].default_value = rub
            links.new(rubbed.outputs[0], strength.inputs[0])
            rmix4 = nodes.new("ShaderNodeMix")
            rmix4.data_type = "RGBA"
            links.new(strength.outputs[0], rmix4.inputs[0])
            links.new(out_colour, rmix4.inputs[6])
            share = 0.45 if ROUND == 4 else 0.28
            rmix4.inputs[7].default_value = (*[min(1.0, c * (1.0 - share) + w * share) for c, w in zip(base, worn)], 1.0)
            out_colour = rmix4.outputs[2]
            rr4 = nodes.new("ShaderNodeMix")
            links.new(strength.outputs[0], rr4.inputs[0])
            links.new(out_rough, rr4.inputs[2])
            rr4.inputs[3].default_value = max(0.2, rough - (0.25 if ROUND == 4 else 0.1))
            out_rough = rr4.outputs[0]
        if scratches > 0.0:
            # Scratches (round 4): thin streaks mostly along the gun, a few across, sparse.
            lines = []
            for turn, stretch, level in (((0.0, 0.025, 0.71), (0.7, 0.05, 0.74), (-1.1, 0.06, 0.75)) if ROUND == 4 else ((0.0, 0.11, 0.73), (0.7, 0.16, 0.75), (-1.1, 0.16, 0.76))):
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
                thin.inputs[2].default_value = level + (0.02 if ROUND == 4 else 0.012)
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


def make_materials():
    if ROUND == 1:
        steel = material("steel", (0.07, 0.072, 0.075), 0.45, 0.85)
        polymer = material("polymer", (0.055, 0.06, 0.052), 0.7, 0.0)
        grip = polymer
        dark = material("dark", (0.01, 0.01, 0.01), 0.8, 0.2)
        blued = steel
        accent = steel
    else:
        wear = 0.6 if ROUND == 2 else 1.0
        late = ROUND >= 4
        steel = material("steel", (0.06, 0.063, 0.066), 0.42, 0.85, wear=wear, grime=0.7, bump=0.08 if ROUND >= 3 else 0.0, bump_scale=900.0,
                         worn=(0.48, 0.47, 0.45) if not late else (0.58, 0.57, 0.54), rub=0.5 if late else 0.0, scratches=0.8 if late else 0.0)
        polymer = material("polymer", (0.03, 0.032, 0.028), 0.66, 0.0, wear=0.35 * wear if not late else 0.6, grime=0.8, worn=(0.16, 0.165, 0.15) if not late else (0.2, 0.2, 0.185),
                           rub=0.0, scratches=0.5 if late else 0.0)
        grip = material("grip", (0.026, 0.028, 0.024), 0.8, 0.0, wear=0.3 * wear, grime=0.9, bump=0.55 if ROUND == 2 else (0.9 if ROUND == 3 else 1.0), bump_scale=1400.0 if ROUND == 2 else (2200.0 if ROUND == 3 else 1500.0), stipple=True, worn=(0.15, 0.155, 0.14))
        dark = material("dark", (0.008, 0.008, 0.008), 0.8, 0.3)
        blued = material("blued", (0.03, 0.033, 0.04), 0.38, 0.9, wear=0.8 * wear, grime=0.5)
        accent = material("accent", (0.36, 0.33, 0.27), 0.35, 0.95, wear=0.3, grime=0.6) if ROUND >= 3 else steel
    marking = material("marking", (0.16, 0.16, 0.15), 0.55, 0.6) if ROUND >= 3 else steel
    # Round 4: paint in the selector's letters, white for safe, red for fire.
    paint = material("paint", (0.62, 0.6, 0.55), 0.6, 0.0, wear=0.0) if ROUND >= 4 else marking
    red = material("red", (0.45, 0.04, 0.025), 0.55, 0.0) if ROUND >= 4 else marking
    # Round 5: the barrel, which shows when the slide stays back, is plain dark steel (with
    # the edge wear of the others it came out white in the game, inside the slide).
    barrel = material("barrel", (0.045, 0.047, 0.05), 0.34, 0.9, grime=0.4) if ROUND >= 5 else blued
    return {"steel": steel, "polymer": polymer, "grip": grip, "dark": dark, "blued": blued, "accent": accent, "marking": marking, "paint": paint, "red": red, "barrel": barrel}


# ------------------------------------------------------------------ the parts
def build(m):
    body, mag, breech = [], [], []
    # What rides on the slide: from round 4 its own object, before that part of the body.
    moving = breech if ROUND >= 4 else body
    w = SLIDE_W / 2.0
    # --- slide: a box with its top edges taken well round, the nose drawn in a little
    if ROUND >= 3:
        # Its cross-section: straight sides, a 4 mm chamfer to a narrower top.
        z0, z1 = SLIDE_Z
        slide = prism("Slide", [(-w, z0), (w, z0), (w, z1 - 0.0045), (w - 0.0042, z1), (-w + 0.0042, z1), (-w, z1 - 0.0045)], SLIDE[0], SLIDE[1], m["steel"])
        bevel_object(slide, 0.0006, 2, 25.0)
    else:
        slide = box("Slide", (-w, SLIDE[0], SLIDE_Z[0]), (w, SLIDE[1], SLIDE_Z[1]), m["steel"], bevel=0.0018 if ROUND == 1 else 0.0012, segments=2 if ROUND == 1 else 3)
    if ROUND >= 2:
        # A chamfer along each top edge, as on a modern slide (round 2 cut it with a turned
        # box, which left a groove: round 3 builds the slide from its profile instead).
        for side in ((-1.0, 1.0) if ROUND == 2 else ()):
            chamfer = box("ch", (-0.02, SLIDE[0] - 0.01, SLIDE_Z[1] - 0.0055), (0.02, SLIDE[1] + 0.01, SLIDE_Z[1] + 0.01), m["steel"])
            rotate(chamfer, side * math.radians(-38.0), "Y", Vector((side * (w + 0.0005), 0, SLIDE_Z[1] - 0.0045)))
            chamfer.data.transform(Matrix.Translation((side * 0.0205, 0, 0)))
            cut(slide, chamfer)
        # Nose: the slide's face is cut back underneath (a dehorned front).
        nose = box("nose", (-0.02, SLIDE[1] - 0.012, SLIDE_Z[0] - 0.01), (0.02, SLIDE[1] + 0.01, SLIDE_Z[0] + 0.006), m["steel"])
        rotate(nose, math.radians(-25.0), "X", Vector((0, SLIDE[1] - 0.012, SLIDE_Z[0] + 0.006)))
        cut(slide, nose)
        # Serrations: grooves across both sides, at the back and at the front.
        count = SERRATIONS if ROUND == 2 else SERRATIONS + 3
        for start, n in ((SLIDE[0] + 0.006, count), (SLIDE[1] - 0.034, 6 if ROUND >= 3 else 0)):
            for i in range(n):
                y = start + i * 0.0029
                groove = box("g", (-0.03, y, SLIDE_Z[0] + 0.006), (0.03, y + 0.0013, SLIDE_Z[1] - 0.004), m["steel"])
                rotate(groove, math.radians(-8.0), "X", Vector((0, y, SLIDE_Z[0])))
                cut(slide, groove, "MANIFOLD" if ROUND == 2 else "EXACT")
        # Ejection port on the right, the barrel's hood showing through it.
        port = box("port", (0.0, 0.004, BORE_Z - 0.003), (0.03, 0.040, SLIDE_Z[1] + 0.01), m["steel"])
        cut(slide, port)
        hood = box("Hood", (-0.0075, 0.003, BORE_Z - 0.005), (0.0075, 0.042, SLIDE_Z[1] - 0.0012), m["blued"], bevel=0.0012)
        body.append(hood)
    if ROUND >= 3:
        # Lightening cuts in the slide's top before the port.
        for i in range(2):
            y0 = 0.052 + i * 0.022
            window = box("win", (-0.0045, y0, SLIDE_Z[1] - 0.004), (0.0045, y0 + 0.014, SLIDE_Z[1] + 0.01), m["steel"], bevel=0.0008)
            cut(slide, window)
        # Markings: the name and the calibre pressed into the left side.
        moving.append(engrave("HORNISSE  MP-9", Vector((-w - 0.00012, 0.036, 0.0655)), 0.006, m["marking"]))
        moving.append(engrave("9x19   KAT. 2026", Vector((-w - 0.00012, 0.036, 0.0578)), 0.0036, m["marking"]))
    smooth(slide, 35)
    moving.append(slide)
    # --- barrel, compensator and the bore
    barrel = cylinder("Barrel", (0, SLIDE[1] - (0.01 if ROUND < 4 else 0.075), BORE_Z), (0, SLIDE[1] + 0.006, BORE_Z), 0.0058, m["barrel"], 24)
    body.append(barrel)
    comp_len = 0.03
    comp = box("Comp", (-0.0115, SLIDE[1] + 0.001, BORE_Z - 0.0105), (0.0115, SLIDE[1] + comp_len, BORE_Z + 0.0125), m["steel"], bevel=0.0024 if ROUND == 1 else 0.003, segments=3)
    bore = cylinder("bore", (0, SLIDE[1] - 0.02, BORE_Z), (0, SLIDE[1] + comp_len + 0.01, BORE_Z), 0.0046, m["steel"], 20)
    cut(comp, bore)
    if ROUND >= 2:
        # Ports in the top that throw the gas upwards, and slots in the sides.
        for i in range(3 if ROUND == 2 else 4):
            y = SLIDE[1] + 0.006 + i * 0.0062
            slot = box("p", (-0.0035, y, BORE_Z), (0.0035, y + 0.0032, BORE_Z + 0.02), m["steel"], bevel=0.0006)
            cut(comp, slot)
        for side in (-1.0, 1.0):
            vent = box("v", (side * 0.006 - 0.01, SLIDE[1] + 0.012, BORE_Z - 0.0035), (side * 0.006 + 0.01, SLIDE[1] + 0.022, BORE_Z + 0.0035), m["steel"], bevel=0.001)
            cut(comp, vent)
    smooth(comp, 35)
    body.append(comp)
    inside = cylinder("Bore", (0, SLIDE[1] - 0.002, BORE_Z), (0, SLIDE[1] + comp_len - 0.004, BORE_Z), 0.0045, m["dark"], 16)
    body.append(inside)
    # --- frame: dust cover and the body over the grip
    fw = FRAME_W / 2.0
    frame = box("Frame", (-fw, FRAME_Y[0], FRAME_Z[0]), (fw, FRAME_Y[1], FRAME_Z[1]), m["polymer"], bevel=0.0025, segments=3)
    if ROUND >= 2:
        # A rail under the dust cover: three cross slots.
        rail = box("Rail", (-0.0105, 0.075, FRAME_Z[0] - 0.0035), (0.0105, FRAME_Y[1] - 0.004, FRAME_Z[0] + 0.001), m["polymer"], bevel=0.0008)
        for i in range(3):
            y = 0.081 + i * 0.0105
            notch = box("n", (-0.02, y, FRAME_Z[0] - 0.006), (0.02, y + 0.004, FRAME_Z[0] - 0.0012), m["polymer"])
            cut(rail, notch, "MANIFOLD")
        body.append(rail)
    if ROUND >= 5:
        under = box("under", (-0.02, FRAME_Y[1] - 0.01, FRAME_Z[0] - 0.01), (0.02, FRAME_Y[1] + 0.01, FRAME_Z[0] + 0.005), m["polymer"])
        rotate(under, math.radians(-30.0), "X", Vector((0, FRAME_Y[1] - 0.01, FRAME_Z[0] + 0.005)))
        cut(frame, under)
        # A relief line along the frame's side, below the slide.
        for side in (-1.0, 1.0):
            line = box("line", (side * fw - 0.0005, FRAME_Y[0] + 0.012, FRAME_Z[1] - 0.0052), (side * fw + 0.0005, FRAME_Y[1] - 0.012, FRAME_Z[1] - 0.0042), m["polymer"])
            cut(frame, line, "EXACT")
    smooth(frame, 35)
    body.append(frame)
    # --- grip: leans back; its back carries a beavertail
    pivot = Vector((0, 0, FRAME_Z[0]))
    gw, gb, gf = (0.0158, -0.031, 0.021) if ROUND == 1 else (0.0146, -0.028, 0.019)
    if ROUND >= 4:
        grip = loft("Grip", [grip_ring(z) for z in grip_levels()], m["grip"])
    elif ROUND >= 3:
        # Seen from below: narrow at the front strap, swelling into the palm, round at the back.
        section = []
        for i in range(24):
            a = math.tau * i / 24
            y = math.cos(a) * 0.0235 - 0.0045
            x = math.sin(a) * (0.0142 if math.cos(a) < 0.0 else 0.0142 - 0.0012 * max(0.0, math.cos(a)) ** 2)
            section.append((x, y))
        grip = upright("Grip", section, -0.066, FRAME_Z[0] + 0.006, m["grip"])
        bevel_object(grip, 0.004, 3, 40.0)
    else:
        grip = box("Grip", (-gw, gb, -0.066), (gw, gf, FRAME_Z[0] + 0.006), m["grip"], bevel=0.0068 if ROUND == 1 else 0.0075, segments=3)
    if ROUND in (2, 3):
        # Finger grooves down the front of the grip.
        for i in range(3):
            z = -0.005 - i * 0.019
            groove = cylinder("fg", (-0.03, 0.0285, z), (0.03, 0.0285, z), 0.0098, m["grip"], 20)
            cut(grip, groove)
        # The panel of stipple is set back from the frame's edge (a raised border).
    if ROUND >= 3:
            for side in (-1.0, 1.0):
                face = 0.0158 if ROUND == 3 else grip_half_width(-0.02) + 0.0002
                panel = box("pan", (side * face - 0.0007, -0.024, -0.058), (side * face + 0.0007, 0.012, 0.016), m["grip"], bevel=0.0004)
                panel.data.transform(Matrix.Translation((side * 0.0004, 0, 0)))
                cut(grip, panel, "MANIFOLD")
    rotate(grip, GRIP_TILT, "X", pivot)
    smooth(grip, 40)
    body.append(grip)
    tail = box("Tail", (-0.0128, FRAME_Y[0] - 0.012, FRAME_Z[1] - 0.012), (0.0128, FRAME_Y[0] + 0.006, FRAME_Z[1] - 0.001), m["polymer"], bevel=0.004, segments=3)
    smooth(tail, 40)
    body.append(tail)
    if ROUND >= 4:
        beaver = box("Beaver", (-0.0122, FRAME_Y[0] - 0.021, FRAME_Z[1] - 0.0135), (0.0122, FRAME_Y[0] + 0.004, FRAME_Z[1] - 0.003), m["polymer"], bevel=0.0042, segments=4)
        # Swept up at its tip, over the web of the hand.
        rotate(beaver, math.radians(-14.0), "X", Vector((0, FRAME_Y[0], FRAME_Z[1] - 0.008)))
        smooth(beaver, 40)
        body.append(beaver)
    # --- trigger guard: an outer form minus its opening
    if ROUND >= 5:
        # A guard swept along its path: along the bottom, a round bend, up into the frame.
        path = [(0.004, 0.0075), (0.0175, 0.0035), (0.03, 0.0005), (0.045, -0.0025), (0.056, -0.0035)]
        for i in range(1, 10):
            a = -math.pi / 2 + (math.pi / 2) * i / 9
            path.append((0.058 + 0.011 * math.cos(a), 0.0075 + 0.011 * math.sin(a)))
        path += [(0.069, 0.018), (0.069, FRAME_Z[0] + 0.003)]
        guard = sweep("Guard", path, 0.0052, 0.0064, m["polymer"])
        smooth(guard, 50)
        body.append(guard)
        # A curved trigger, its face hollow towards the front, a safety blade in it.
        bend = []
        for i in range(9):
            k = i / 8
            p0, p1, p2 = (0.0315, FRAME_Z[0] + 0.002), (0.0305, 0.013), (0.0385, 0.0045)
            bend.append(((1 - k) ** 2 * p0[0] + 2 * (1 - k) * k * p1[0] + k * k * p2[0], (1 - k) ** 2 * p0[1] + 2 * (1 - k) * k * p1[1] + k * k * p2[1]))
        trigger = sweep("Trigger", bend, 0.003, 0.0048, m["blued"])
        smooth(trigger, 50)
        body.append(trigger)
        blade = box("Blade", (-0.0007, 0.0315, 0.009), (0.0007, 0.0345, 0.019), m["steel"], bevel=0.0003)
        rotate(blade, math.radians(-10.0), "X", Vector((0, 0.033, 0.019)))
        body.append(blade)
    else:
        guard = box("Guard", (-0.0048, 0.014, -0.004), (0.0048, 0.075, FRAME_Z[0] + 0.002), m["polymer"], bevel=0.0035 if ROUND == 1 else 0.004, segments=3)
        opening = box("open", (-0.02, 0.019, 0.0018), (0.02, 0.069, FRAME_Z[0] + 0.02), m["polymer"], bevel=0.003)
        cut(guard, opening)
        smooth(guard, 40)
        body.append(guard)
        trigger = box("Trigger", (-0.0032, 0.031, 0.006), (0.0032, 0.037, FRAME_Z[0] + 0.002), m["blued"], bevel=0.0012)
        rotate(trigger, math.radians(-14.0), "X", Vector((0, 0.034, FRAME_Z[0])))
        body.append(trigger)
    # --- sights
    rear = box("Rear", (-0.0075, SLIDE[0] + 0.004, SLIDE_Z[1] - 0.001), (0.0075, SLIDE[0] + 0.012, SLIDE_Z[1] + 0.0065), m["blued"], bevel=0.0009)
    notch = box("notch", (-0.0018, SLIDE[0], SLIDE_Z[1] + 0.0025), (0.0018, SLIDE[0] + 0.02, SLIDE_Z[1] + 0.02), m["blued"])
    cut(rear, notch)
    moving.append(rear)
    front = box("Front", (-0.0016, SLIDE[1] - 0.014, SLIDE_Z[1] - 0.001), (0.0016, SLIDE[1] - 0.006, SLIDE_Z[1] + 0.0058), m["blued"], bevel=0.0007)
    moving.append(front)
    if ROUND >= 3:
        # Night-sight dots: a pale ring in the front post and two at the back.
        for x, y in ((0.0, SLIDE[1] - 0.0059), (-0.0048, SLIDE[0] + 0.0119), (0.0048, SLIDE[0] + 0.0119)):
            dot = cylinder("Dot", (x, y - 0.0004, SLIDE_Z[1] + 0.0035), (x, y + 0.0004, SLIDE_Z[1] + 0.0035), 0.0011, m["accent"], 12)
            moving.append(dot)
    # --- fire selector on the left, behind the grip's top: a lever on a round seat
    sel = cylinder("Selector", (-fw - 0.0012, -0.030, FRAME_Z[1] - 0.006), (-fw + 0.001, -0.030, FRAME_Z[1] - 0.006), 0.0045, m["blued"], 20)
    body.append(sel)
    if ROUND == 1:
        lever = box("Lever", (-fw - 0.0024, -0.032, FRAME_Z[1] - 0.007), (-fw - 0.0008, -0.016, FRAME_Z[1] - 0.004), m["blued"], bevel=0.0006)
        rotate(lever, math.radians(-30.0), "X", Vector((0, -0.030, FRAME_Z[1] - 0.006)))
    elif ROUND <= 3:
        lever = box("Lever", (-fw - 0.0022, -0.034, FRAME_Z[1] - 0.0115), (-fw - 0.0006, -0.019, FRAME_Z[1] - 0.0035), m["blued"], bevel=0.0007)
        rotate(lever, math.radians(-12.0), "X", Vector((0, -0.030, FRAME_Z[1] - 0.006)))
    if ROUND <= 3:
        body.append(lever)
    else:
        seat = Vector((0, -0.030, FRAME_Z[1] - 0.006))
        for side in (-1.0, 1.0):
            x0, x1 = (side * (fw + 0.0005), side * (fw + 0.0028)) if side > 0 else (-fw - 0.0028, -fw - 0.0005)
            if side > 0:
                ring = cylinder("Selector", (fw - 0.001, seat.y, seat.z), (fw + 0.0012, seat.y, seat.z), 0.0045, m["blued"], 20)
                body.append(ring)
            arm = box("Lever", (min(x0, x1), -0.0325, seat.z - 0.0032), (max(x0, x1), -0.0165, seat.z + 0.0032), m["blued"], bevel=0.0011)
            paddle = cylinder("Paddle", (min(x0, x1) - 0.0003, -0.0165, seat.z), (max(x0, x1) + 0.0003, -0.0165, seat.z), 0.0046, m["blued"], 20, bevel=0.0008)
            union(arm, paddle)
            for i in range(3):
                y = -0.0195 + i * 0.0026
                rib = box("rib", (min(x0, x1) - 0.0008, y, seat.z - 0.004), (max(x0, x1) + 0.0008, y + 0.0009, seat.z + 0.004), m["blued"], bevel=0.0003)
                union(arm, rib)
            # Turned down to F (full auto): the lever points forward and down.
            rotate(arm, math.radians(-30.0), "X", seat)
            smooth(arm, 35)
            body.append(arm)
        # S above the seat's back, F below its front, as on the frame's left side.
        body.append(engrave("S", Vector((-fw - 0.00012, -0.0365, FRAME_Z[1] - 0.0034)), 0.0034, m["paint"]))
        f_at = Vector((-fw - 0.00012, -0.0085, FRAME_Z[0] + 0.0068)) if ROUND == 4 else Vector((-fw - 0.00012, 0.0035, FRAME_Z[1] - 0.0105))
        body.append(engrave("F", f_at, 0.0034, m["red"]))
    if ROUND >= 2:
        # Slide stop, takedown lever and the pins through the frame.
        stop = box("Stop", (-fw - 0.0016, 0.006, FRAME_Z[1] - 0.004), (-fw + 0.001, 0.026, FRAME_Z[1] + 0.002), m["blued"], bevel=0.0007)
        body.append(stop)
        take = box("Take", (-fw - 0.0012, 0.044, FRAME_Z[0] + 0.006), (fw + 0.0012, 0.051, FRAME_Z[0] + 0.011), m["blued"], bevel=0.0008)
        body.append(take)
        for y, z in ((0.040, FRAME_Z[0] + 0.004), (-0.018, FRAME_Z[0] + 0.009), (0.012, FRAME_Z[0] + 0.012)):
            pin = cylinder("Pin", (-fw - 0.0004, y, z), (fw + 0.0004, y, z), 0.0016, m["steel"], 14)
            body.append(pin)
        # Extractor on the right side of the slide, beside the port.
        ext = box("Extractor", (w - 0.0004, -0.012, BORE_Z + 0.002), (w + 0.0007, 0.006, BORE_Z + 0.0075), m["blued"], bevel=0.0004)
        moving.append(ext)
    if ROUND >= 3:
        # Screws in the grip panel, a lanyard loop at the grip's foot and a folding fore-grip
        # under the dust cover (folded up).
        for side in (-1.0, 1.0):
            for z in (0.006, -0.046):
                face = 0.0136 if ROUND == 3 else grip_half_width(z) - 0.0012
                screw = cylinder("Screw", (side * face, -0.006, z), (side * (face + 0.0015), -0.006, z), 0.0022, m["steel"], 16)
                slot = box("slot", (side * (face + 0.0017) - 0.0006, -0.0063, z - 0.0021), (side * (face + 0.0017) + 0.0006, -0.0057, z + 0.0021), m["steel"])
                cut(screw, slot, "MANIFOLD")
                rotate(screw, GRIP_TILT, "X", pivot)
                body.append(screw)
        fold = box("Fold", (-0.006, 0.088, FRAME_Z[0] - 0.0105), (0.006, FRAME_Y[1] + 0.006, FRAME_Z[0] - 0.0045), m["blued"], bevel=0.0015)
        hinge = cylinder("Hinge", (-0.0068, FRAME_Y[1] + 0.001, FRAME_Z[0] - 0.0062), (0.0068, FRAME_Y[1] + 0.001, FRAME_Z[0] - 0.0062), 0.0028, m["steel"], 16)
        body.extend([fold, hinge])
        loop = cylinder("Loop", (-0.007, -0.0265, -0.061), (0.007, -0.0265, -0.061), 0.0024, m["steel"], 14)
        rotate(loop, GRIP_TILT, "X", pivot)
        body.append(loop)
    # --- the extended magazine: a steel body down the grip and well below it, a polymer foot
    mw = 0.0116 if ROUND < 3 else 0.0108
    mag_body = box("MagBody", (-mw, -0.016, MAG_FOOT + 0.012), (mw, 0.016, FRAME_Z[0] - 0.004), m["blued"], bevel=0.0018 if ROUND < 4 else 0.003, segments=2 if ROUND < 4 else 3)
    if ROUND >= 2:
        # Witness holes down its back half and a raised spine at the front.
        for i in range(4 if ROUND == 2 else 6):
            z = -0.072 - i * 0.0085
            if ROUND >= 3:
                hole = cylinder("w", (-0.0125, -0.006, z), (-0.0094, -0.006, z), 0.0019, m["blued"], 16)
                cut(mag_body, hole, "EXACT")
            else:
                hole = cylinder("w", (-0.02, -0.006, z), (0.02, -0.006, z), 0.0019, m["blued"], 12)
                cut(mag_body, hole, "MANIFOLD")
    rotate(mag_body, GRIP_TILT, "X", pivot)
    smooth(mag_body, 35)
    mag.append(mag_body)
    plate = box("MagPlate", (-0.0142, -0.021, MAG_FOOT), (0.0142, 0.0215, MAG_FOOT + 0.013), m["polymer"], bevel=0.0035 if ROUND == 1 else 0.004, segments=3)
    if ROUND >= 2:
        lip = box("lip", (-0.0132, 0.012, MAG_FOOT - 0.002), (0.0132, 0.027, MAG_FOOT + 0.007), m["polymer"], bevel=0.003)
        union(plate, lip)
        if ROUND >= 3:
            grooves = []
            for i in range(3):
                z = MAG_FOOT + 0.003 + i * 0.0035
                g = box("pg", (-0.02, -0.03, z), (0.02, -0.0195, z + 0.0013), m["polymer"])
                cut(plate, g, "MANIFOLD")
    rotate(plate, GRIP_TILT, "X", pivot)
    smooth(plate, 40)
    mag.append(plate)
    if ROUND >= 3:
        # The top round, its brass showing between the feed lips.
        top = cylinder("Round", (0, -0.014, FRAME_Z[0] - 0.002), (0, 0.004, FRAME_Z[0] - 0.002), 0.0045, m["accent"], 14)
        rotate(top, GRIP_TILT, "X", pivot)
        mag.append(top)
    return body, mag, breech


def grip_levels():
    """Heights of the round-4 grip's sections, from its foot to the frame (before the tilt)."""
    z0, z1 = -0.066, FRAME_Z[0] + 0.006
    levels = [z0, z0 + 0.0012, z0 + 0.003]
    n = 30
    for i in range(1, n + 1):
        levels.append(z0 + 0.003 + (z1 - z0 - 0.003) * i / n)
    return levels


def grip_half_width(z):
    """Half the grip's width at height z: a swell for the palm in its middle."""
    t = (z + 0.066) / (FRAME_Z[0] + 0.006 + 0.066)
    return 0.0138 + 0.0016 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.08) / 0.84)))


def grip_ring(z):
    """One section of the round-4 grip at height z: a front strap with finger grooves, a back
    strap that swells into the palm, sides that swell a little, the foot drawn in."""
    t = (z + 0.066) / (FRAME_Z[0] + 0.006 + 0.066)
    front = 0.022
    # Three grooves for the fingers, centred where round 3 cut them, bumps between.
    if -0.054 < z < 0.006:
        front -= 0.0028 * (0.5 + 0.5 * math.cos(math.tau * (z + 0.005) / 0.0195))
    back = -0.0285 - 0.0028 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.1) / 0.8)))
    # The memory bump: the back strap's top swells out under the beavertail.
    back -= 0.0032 * max(0.0, math.sin(math.pi * min(1.0, max(0.0, (t - 0.74) / 0.26))))
    half = grip_half_width(z)
    # The foot: drawn in over its lowest 3 mm, like a rounded edge.
    if z < -0.066 + 0.003:
        k = (z + 0.066) / 0.003
        shrink = 0.86 + 0.14 * math.sqrt(max(0.0, k))
        half *= shrink
        middle = (front + back) * 0.5
        front = middle + (front - middle) * shrink
        back = middle + (back - middle) * shrink
    middle = (front + back) * 0.5
    ring = []
    for i in range(36):
        a = math.tau * i / 36
        c, s = math.cos(a), math.sin(a)
        # A rounded box rather than an ellipse, so that the magazine stays inside.
        cs = math.copysign(abs(c) ** 0.45, c)
        ss = math.copysign(abs(s) ** 0.45, s)
        y = middle + cs * ((front - middle) if c > 0.0 else (middle - back))
        x = ss * (half - 0.0014 * max(0.0, c) ** 2)
        ring.append((x, y, z))
    return ring


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


def engrave(text, at, size, material):
    """Flat lettering on the left face of the slide, reading from the muzzle backwards as
    one sees it from the left; `at` is where its first letter begins."""
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "LEFT"
    letters = link(bpy.data.objects.new("Marking", curve))
    bpy.context.view_layer.objects.active = letters
    bpy.ops.object.select_all(action="DESELECT")
    letters.select_set(True)
    bpy.ops.object.convert(target="MESH")
    letters = bpy.context.view_layer.objects.active
    # Text x -> backwards (-y), text y -> up (z), its face -> out to the left (-x).
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
        img = bpy.data.images.new("hornet_" + key, TEX, TEX, alpha=False, float_buffer=False)
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
    # Base colour and metal: each through an emission that carries it. (Round 1 baked the
    # colour as the diffuse pass, which leaves whatever is metal black: found in its pictures.)
    for key, socket in (("metal", "metal_socket"), ("base", "colour_socket")):
        if key == "base" and ROUND == 1:
            for mat in mats:
                nt = mat.node_tree
                nt.links.new(nt.nodes["Principled BSDF"].outputs[0], nt.nodes["Material Output"].inputs["Surface"])
            run("DIFFUSE", images["base"], pass_filter={"COLOR"})
            continue
        for mat in mats:
            nt = mat.node_tree
            name, index = mat[socket].split(":")
            emit = nt.nodes.new("ShaderNodeEmission")
            nt.links.new(nt.nodes[name].outputs[int(index)], emit.inputs["Color"])
            nt.links.new(emit.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
        run("EMIT", images[key])
    # Roughness (G) and metal (B) into one picture, as glTF wants them.
    import numpy
    rough = numpy.array(images["rough"].pixels[:], dtype=numpy.float32)
    metal = numpy.array(images["metal"].pixels[:], dtype=numpy.float32)
    orm = numpy.ones_like(rough)
    orm[1::4] = rough[0::4]
    orm[2::4] = metal[0::4]
    images["orm"] = bpy.data.images.new("hornet_orm", TEX, TEX, alpha=False)
    images["orm"].colorspace_settings.name = "Non-Color"
    images["orm"].pixels = orm.tolist()
    return images


def final_material(images):
    mat = bpy.data.materials.new("hornet")
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


def main():
    clear()
    m = make_materials()
    body_parts, mag_parts, breech_parts = build(m)
    body = join(body_parts, "Body")
    magazine = join(mag_parts, "Magazine")
    parts = [body, magazine]
    if breech_parts:
        parts.append(join(breech_parts, "Breech"))
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # One UV space for both, islands packed with room for the bake's margin.
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.004, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # (A cut can leave an empty slot behind - the letters of a marking: their walls are steel.)
    for o in parts:
        for slot in o.material_slots:
            if slot.material is None:
                slot.material = bpy.data.materials["steel"]
    # The slide is baked away from the rest (round 4 on): faces that lie against each other
    # while it is home - its face and the compensator's back, the barrel inside it - show when
    # it runs back, and baked in place they came out white (edge wear found in the gap).
    if len(parts) > 2:
        parts[2].location.x += 0.3
    images = bake(parts)
    if len(parts) > 2:
        parts[2].location.x -= 0.3
    final = final_material(images)
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(final)
    root = link(bpy.data.objects.new("Hornet", None))
    for o in parts:
        o.parent = root
    print("ROUND", ROUND, "triangles body", triangles(body), "magazine", triangles(magazine), "breech", triangles(parts[2]) if len(parts) > 2 else 0, "texture", TEX)

    def godot(p):
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    tilt = Matrix.Rotation(GRIP_TILT, 4, "X")
    pivot = Vector((0, 0, FRAME_Z[0]))
    foot = pivot + tilt @ (Vector((0, 0, MAG_FOOT)) - pivot)
    out = (tilt @ Vector((0, 0, -1))).normalized()
    print("SPEC muzzle", godot(Vector((0, SLIDE[1] + 0.03, BORE_Z))), "bore 0.0046")
    print("SPEC rail %.4f irons %.4f" % (SLIDE_Z[1], SLIDE_Z[1] + 0.0058))
    print("SPEC magazine_out", godot(out), "magazine_foot", godot(foot))
    if BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_jpeg_quality=92)
    print("EXPORTED", OUT, os.path.getsize(OUT), "bytes")


main()
