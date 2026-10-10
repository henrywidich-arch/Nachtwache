# Prepares the MP7 for Nachtwache from the user's generated model (M32_Bausatz/MGNeu/mp7.glb,
# one textured piece, 1.9 units long, muzzle towards -x): the game-ready GLB with the
# nodes MP7 > Body / Magazine, like the G36 and the UMP.
#
# The magazine of the MP7 sits in its pistol grip; the model only shows its floor plate,
# which closes the grip at the bottom. The script cuts that floor plate off the grip and
# builds the rest of the magazine on top of it (a straight polymer body that runs up the
# grip into the receiver, with a cartridge on top), so that a whole magazine comes out of
# the grip during a reload. Above the opening of the grip sits a dark plate, so that
# nobody looks into the hollow model when the magazine is out. The model has no iron
# sights, only the long top rail (as the user wanted); the game aims along that rail, or
# through a sight bought for it.
#
# It also turns the model so that the muzzle points forward, scales it (the generated
# model is taller than the real gun; 0.28 makes it a 54 cm MP7 with its stock pulled out,
# a compromise between its length and its height), puts the middle of the pistol grip on
# the origin, welds the seams of the texture, reduces it to about 70,000 triangles and
# takes the textures down to 2048 pixels (JPEG in the GLB, as Godot extracts them), with
# a little metal in its finish like the other guns of the game.
#
# Run (a minute or so), from the project folder:
#   blender --background --factory-startup --python tools/blender_make_mp7.py -- [--src <mp7.glb>] [--out <mp7.glb>]
# or, with the bpy module installed:  python tools/blender_make_mp7.py -- [--src ...] [--out ...]
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle
# of the pistol grip. The glTF exporter turns this into Godot space: barrel along -Z, up +Y.
# The places the game needs (GUNS["mp7"] in weapon_view.gd) are printed at the end.
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(arg("--src", os.path.join(HERE, "..", "M32_Bausatz", "MGNeu", "mp7.glb")))
OUT_GLB = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "mp7.glb")))

# ------------------------------------------------------------------ the source model
# In the source (Blender after import, z up): muzzle at x = -0.96, butt plate at x = +0.95,
# bore axis at z = 0.197, top of the rail at z = 0.403. The pistol grip runs from z = -0.10
# down to z = -0.40, between x = 0.03 (front) and x = 0.31 (back); its floor plate (the
# foot of the magazine) is what lies below z = -0.375.
SCALE = 0.28
GRIP = Vector((0.165, 0.0, -0.245))          # middle of the pistol grip, in the source
FLOOR_CUT = -0.375                           # the floor plate lies below this (source z)
GRIP_X = (0.0, 0.33)                         # the grip from front to back (source x)
TRIANGLES = 70000
TEXTURE = 2048
# What the roughness of the texture is multiplied with, and the least metal it gets.
ROUGH = 0.8
METAL = 0.6


def to_game(p):
    """A point of the source in modelling space."""
    d = Vector(p) - GRIP
    return Vector((d.y, -d.x, d.z)) * SCALE


def srgb(r, g, b):
    return tuple(((c / 255.0 + 0.055) / 1.055) ** 2.4 if c / 255.0 > 0.04045 else c / 255.0 / 12.92 for c in (r, g, b))


def plain(name, color, metal, rough):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*srgb(*color), 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def bounds(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def new_object(name, bm, mats):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def rounded_column(bm, bottom, top, half_w, half_d, r, mat_index, seg=3):
    """A column with rounded vertical edges from `bottom` to `top` (both centres of its
    end faces); its cross-section is 2 half_w (across, x) by 2 half_d (along y)."""
    axis = (top - bottom).normalized()
    side = Vector((1, 0, 0))
    ahead = axis.cross(side).normalized()
    ring = []
    corners = [(half_w - r, half_d - r, 0.0), (-(half_w - r), half_d - r, 90.0), (-(half_w - r), -(half_d - r), 180.0), (half_w - r, -(half_d - r), 270.0)]
    for cx, cy, start in corners:
        for i in range(seg + 1):
            a = math.radians(start + 90.0 * i / seg)
            ring.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    loops = []
    for centre in (bottom, top):
        loops.append([bm.verts.new(centre + side * u + ahead * v) for u, v in ring])
    n = len(ring)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((loops[0][i], loops[0][j], loops[1][j], loops[1][i])))
    faces.append(bm.faces.new(list(reversed(loops[0]))))
    faces.append(bm.faces.new(loops[1]))
    for f in faces:
        f.material_index = mat_index
        f.smooth = False
    return faces


def cylinder(bm, start, end, r0, r1, mat_index, seg=16, cap=True):
    axis = (end - start)
    length = axis.length
    axis.normalize()
    u = axis.orthogonal().normalized()
    v = axis.cross(u)
    a = [bm.verts.new(start + (u * math.cos(t) + v * math.sin(t)) * r0) for t in [2 * math.pi * i / seg for i in range(seg)]]
    if r1 <= 0.0:
        tip = bm.verts.new(end)
        for i in range(seg):
            bm.faces.new((a[i], a[(i + 1) % seg], tip)).material_index = mat_index
    else:
        b = [bm.verts.new(end + (u * math.cos(t) + v * math.sin(t)) * r1) for t in [2 * math.pi * i / seg for i in range(seg)]]
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i])).material_index = mat_index
        if cap:
            bm.faces.new(b).material_index = mat_index
    if cap:
        bm.faces.new(list(reversed(a))).material_index = mat_index


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    model = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != model:
            bpy.data.objects.remove(o)
    print("SOURCE triangles", triangles(model))

    # Turned, scaled, the grip on the origin.
    rot = Matrix.Rotation(math.radians(-90.0), 4, "Z")
    model.data.transform(Matrix.Scale(SCALE, 4) @ rot @ Matrix.Translation(-GRIP))
    model.data.update()

    # Weld what the generator split along the seams of its texture: the reduction would
    # tear the model open there otherwise. The UVs stay with the corners of the faces.
    bm = bmesh.new()
    bm.from_mesh(model.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
    # The floor plate: every face of the grip below the cut.
    cut_z = (FLOOR_CUT - GRIP.z) * SCALE
    front_y = (GRIP.x - GRIP_X[0]) * SCALE
    back_y = (GRIP.x - GRIP_X[1]) * SCALE
    plate = [f for f in bm.faces if f.calc_center_median().z < cut_z and back_y < f.calc_center_median().y < front_y]
    print("FLOOR PLATE faces", len(plate))
    plate_bm = bmesh.new()
    lookup = {}
    uv_src = bm.loops.layers.uv.active
    uv_dst = plate_bm.loops.layers.uv.new(uv_src.name if hasattr(uv_src, "name") else "UVMap")
    for f in plate:
        vs = []
        for v in f.verts:
            if v not in lookup:
                lookup[v] = plate_bm.verts.new(v.co)
            vs.append(lookup[v])
        nf = plate_bm.faces.new(vs)
        nf.smooth = f.smooth
        for l_src, l_dst in zip(f.loops, nf.loops):
            l_dst[uv_dst].uv = l_src[uv_src].uv
    bmesh.ops.delete(bm, geom=plate, context="FACES")
    # The opening this leaves in the grip is closed with a dark plate, so that nobody looks
    # into the hollow model when the magazine is out.
    rim = [e for e in bm.edges if e.is_boundary and all(v.co.z < cut_z + 0.006 for v in e.verts)]
    filled = bmesh.ops.holes_fill(bm, edges=rim, sides=0)["faces"]
    well_index = len(model.data.materials)
    for f in filled:
        f.material_index = well_index
    print("WELL faces", len(filled))
    bm.to_mesh(model.data)
    bm.free()
    model.data.materials.append(plain("mp7_well", (8, 8, 9), 0.0, 0.9))
    model.name = "Body"
    model.data.name = "Body"

    # Fewer triangles.
    before = triangles(model)
    if before > TRIANGLES:
        mod = model.modifiers.new("Reduce", "DECIMATE")
        mod.ratio = TRIANGLES / before
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = model
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in model.data.polygons:
        p.use_smooth = True
    print("BODY triangles", before, "->", triangles(model))

    # The textures: renamed for Godot (it extracts them as mp7_mp7_base.jpg and so on) and
    # taken down to TEXTURE pixels.
    gun_mat = model.data.materials[0]
    gun_mat.name = "mp7"
    for node in gun_mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            links = [l.to_socket.name for out in node.outputs for l in out.links]
            role = "base" if "Base Color" in links else ("normal" if any(l.to_node.type == "NORMAL_MAP" for out in node.outputs for l in out.links) else "orm")
            image = node.image
            image.name = "mp7_" + role
            if image.size[0] > TEXTURE:
                image.scale(TEXTURE, TEXTURE)
            if role == "orm":
                # The generator made it bare polymer (no metal at all, rough), which comes
                # out pale grey in the game next to the other guns; a little metal and a
                # smoother finish give it their dark sheen.
                pixels = list(image.pixels)
                for i in range(0, len(pixels), 4):
                    pixels[i + 1] *= ROUGH
                    pixels[i + 2] = max(pixels[i + 2], METAL)
                image.pixels = pixels
                image.update()
            print("TEXTURE", image.name, tuple(image.size))

    # --- the magazine: the floor plate from the model, the body on top of it
    mag_mats = [gun_mat, plain("mp7_magazine", (34, 35, 37), 0.0, 0.62), plain("mp7_brass", (196, 150, 70), 1.0, 0.32),
                plain("mp7_copper", (184, 110, 72), 1.0, 0.35)]
    mag = bmesh.new()
    uv = mag.loops.layers.uv.new("UVMap")
    # Copy the plate (material 0, its own UVs).
    lookup = {}
    puv = plate_bm.loops.layers.uv.active
    for f in plate_bm.faces:
        vs = []
        for v in f.verts:
            if v not in lookup:
                lookup[v] = mag.verts.new(v.co)
            vs.append(lookup[v])
        nf = mag.faces.new(vs)
        nf.smooth = True
        nf.material_index = 0
        for a, b in zip(f.loops, nf.loops):
            b[uv].uv = a[puv].uv
    # Its open top (where it was cut from the grip) is closed as well.
    rim = [e for e in mag.edges if e.is_boundary]
    for f in bmesh.ops.holes_fill(mag, edges=rim, sides=0)["faces"]:
        f.material_index = 1
    plate_bm.free()
    # The body follows the grip, which leans back a little towards its foot: from just
    # inside the floor plate up into the receiver.
    foot = to_game((0.168, 0.0, FLOOR_CUT - 0.008))
    head = to_game((0.140, 0.0, -0.05))
    rounded_column(mag, foot, head, 0.0105, 0.026, 0.004, 1)
    # Feed lips and the cartridge on top, bullet forward.
    axis = (head - foot).normalized()
    lips = head + axis * 0.003
    rounded_column(mag, head - axis * 0.001, lips, 0.0095, 0.024, 0.003, 1)
    case_back = lips + axis * 0.0028 + Vector((0, -0.012, 0))
    case_front = case_back + Vector((0, 0.019, 0))
    cylinder(mag, case_back, case_front, 0.0029, 0.0026, 2, 12)
    cylinder(mag, case_front, case_front + Vector((0, 0.003, 0)), 0.0024, 0.0024, 3, 12)
    cylinder(mag, case_front + Vector((0, 0.003, 0)), case_front + Vector((0, 0.009, 0)), 0.0024, 0.0, 3, 12)
    magazine = new_object("Magazine", mag, mag_mats)
    print("MAGAZINE triangles", triangles(magazine))

    root = bpy.data.objects.new("MP7", None)
    bpy.context.scene.collection.objects.link(root)
    for o in (model, magazine):
        o.parent = root
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o not in (model, magazine):
            bpy.data.objects.remove(o)

    # The places the game needs, in Godot space (x right, y up, z back), from the grip.
    def godot(p):
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    low, high = bounds(model)
    muzzle = to_game((-0.96, 0.0, 0.197))
    print("SPEC muzzle", godot(muzzle), "bore %.4f" % (0.041 * SCALE))
    print("SPEC rail %.4f" % ((0.403 - GRIP.z) * SCALE), "rail from %.4f to %.4f" % (-(to_game((-0.48, 0, 0)).y), -(to_game((0.47, 0, 0)).y)))
    print("SPEC support", godot(to_game((-0.60, 0.0, -0.12))))
    print("SPEC handle", godot(to_game((0.53, 0.0, 0.36))))
    out = (foot - head).normalized()
    print("SPEC magazine_out", godot(out), "magazine_foot", godot(to_game((0.17, 0.0, -0.405))))
    print("SPEC length %.3f height %.3f" % (high.y - low.y, high.z - low.z))

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=False, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_jpeg_quality=90)
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")


main()
