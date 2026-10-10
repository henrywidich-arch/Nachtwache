# Prepares the M21E for Nachtwache (the weapon with the id "mg2", a second machine gun next
# to the one the game already has) from the user's two generated models in M32_Bausatz/MGNeu:
#   MG.glb          the gun, one textured piece, 1.9 units long, muzzle towards -x, with a
#                   magazine well in front of the trigger guard and iron sights (a rotary
#                   drum at the back, a hooded post at the front)
#   mgMagazin.glb   the drum magazine, one textured piece, its feed tower on top
# The result is the game-ready GLB with the nodes MG2 > Body / Magazine, like the G36 and
# the UMP: the gun and the drum stay two parts, each with its own textures, so that the
# drum really comes off the gun during a reload.
#
# The gun is turned so that the muzzle points forward, scaled to 1.02 m (a G3-type
# machine gun) and put with the middle of its pistol grip on the origin. The drum is
# scaled so that its feed tower fits the magazine well (the drum is then 20 cm across) and
# set into the well, hanging to the left of the gun as the feed tower sits at the side of
# the drum. Both have their texture seams welded, are reduced (gun about 70,000, drum
# about 20,000 triangles) and get textures of 2048 pixels (JPEG in the GLB, as Godot
# extracts them).
#
# Run (a minute or so), from the project folder:
#   blender --background --factory-startup --python tools/blender_make_mg2.py -- [--gun <MG.glb>] [--drum <mgMagazin.glb>] [--out <mg2.glb>]
# or, with the bpy module installed:  python tools/blender_make_mg2.py -- [...]
#
# Modelling space: x = right, y = forward (muzzle), z = up, metres, origin in the middle
# of the pistol grip. The glTF exporter turns this into Godot space: barrel along -Z, up +Y.
# The places the game needs (GUNS["mg2"] in weapon_view.gd) are printed at the end.
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
GUN_SRC = os.path.abspath(arg("--gun", os.path.join(HERE, "..", "M32_Bausatz", "MGNeu", "MG.glb")))
DRUM_SRC = os.path.abspath(arg("--drum", os.path.join(HERE, "..", "M32_Bausatz", "MGNeu", "mgMagazin.glb")))
OUT_GLB = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "mg2.glb")))

# ------------------------------------------------------------------ the gun (source)
# In MG.glb (Blender after import, z up): muzzle at x = -0.961, butt plate at x = +0.951,
# bore axis at z = 0.0985. The pistol grip runs down to z = -0.229 between x = 0.30 and
# 0.44; the receiver above it begins at z = 0. The magazine well spans x = -0.011 to 0.150
# (y = -0.05 to 0.055) and ends at z = -0.057. The tip of the front post (in its hood at
# x = -0.704) stands at z = 0.205, the notch of the rear sight above the drum at x = 0.365.
GUN_SCALE = 0.533
GRIP = Vector((0.37, 0.0, -0.12))
WELL = Vector((0.0695, 0.0025, -0.057))      # the middle of the mouth of the magazine well
SIGHT_Z = 0.205
FRONT_SIGHT_X, REAR_SIGHT_X = -0.704, 0.365
GUN_TRIANGLES = 70000
# ------------------------------------------------------------------ the drum (source)
# In mgMagazin.glb: the drum is a disc about the y axis (radius 0.877, from y = -0.52 to
# 0.35), its feed tower on top from z = 0.79 to 0.949, x = -0.284 to 0.284 (along the
# gun), y = 0.256 to 0.555 (at the side of the drum). The bottom of the drum is z = -0.952.
DRUM_SCALE = 0.115
TOWER = Vector((0.0, 0.405, 0.80))            # the foot of the feed tower, where it meets the drum
DRUM_BOTTOM = -0.952
DRUM_TRIANGLES = 20000
TEXTURE = 2048


def gun_point(p):
    d = Vector(p) - GRIP
    return Vector((d.y, -d.x, d.z)) * GUN_SCALE


WELL_MOUTH = gun_point(WELL)


def drum_point(p):
    """A point of mgMagazin.glb in modelling space, with the drum seated in the well."""
    d = Vector(p) - TOWER
    return Vector((d.y, -d.x, d.z)) * DRUM_SCALE + WELL_MOUTH


def bounds(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def load(path):
    """Imports a GLB and returns its meshes joined into one object, transforms applied."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    model = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in new:
        if o != model and o.name in bpy.data.objects:
            bpy.data.objects.remove(o)
    return model


def prepare(model, matrix, name, target, prefix):
    """Moves the model into place, welds its seams, reduces it and renames and shrinks its
    textures (Godot extracts them as mg2_<prefix>_base.jpg and so on)."""
    model.data.transform(matrix)
    bm = bmesh.new()
    bm.from_mesh(model.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
    bm.to_mesh(model.data)
    bm.free()
    before = triangles(model)
    if before > target:
        mod = model.modifiers.new("Reduce", "DECIMATE")
        mod.ratio = target / before
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = model
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in model.data.polygons:
        p.use_smooth = True
    model.name = name
    model.data.name = name
    print(name.upper(), "triangles", before, "->", triangles(model))
    mat = model.data.materials[0]
    mat.name = prefix
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            outs = [l for out in node.outputs for l in out.links]
            role = "base" if any(l.to_socket.name == "Base Color" for l in outs) else ("normal" if any(l.to_node.type == "NORMAL_MAP" for l in outs) else "orm")
            image = node.image
            image.name = prefix + "_" + role
            if image.size[0] > TEXTURE:
                image.scale(TEXTURE, TEXTURE)
            print("TEXTURE", image.name, tuple(image.size))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rot = Matrix.Rotation(math.radians(-90.0), 4, "Z")
    gun = load(GUN_SRC)
    prepare(gun, Matrix.Scale(GUN_SCALE, 4) @ rot @ Matrix.Translation(-GRIP), "Body", GUN_TRIANGLES, "mg2")
    drum = load(DRUM_SRC)
    prepare(drum, Matrix.Translation(WELL_MOUTH) @ Matrix.Scale(DRUM_SCALE, 4) @ rot @ Matrix.Translation(-TOWER), "Magazine", DRUM_TRIANGLES, "mg2_drum")

    root = bpy.data.objects.new("MG2", None)
    bpy.context.scene.collection.objects.link(root)
    for o in (gun, drum):
        o.parent = root

    # The places the game needs, in Godot space (x right, y up, z back), from the grip.
    def godot(p):
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    low, high = bounds(gun)
    dlow, dhigh = bounds(drum)
    print("SPEC muzzle", godot(gun_point((-0.961, 0.0, 0.0985))), "bore %.4f" % (0.025 * GUN_SCALE))
    print("SPEC sight line %.4f" % ((SIGHT_Z - GRIP.z) * GUN_SCALE), "front post", godot(gun_point((FRONT_SIGHT_X, 0, SIGHT_Z))), "rear sight", godot(gun_point((REAR_SIGHT_X, 0, SIGHT_Z))))
    print("SPEC receiver top %.4f" % ((0.165 - GRIP.z) * GUN_SCALE))
    print("SPEC support", godot(gun_point((-0.40, 0.0, 0.085))))
    print("SPEC well", godot(WELL_MOUTH))
    centre = (dlow + dhigh) * 0.5
    print("SPEC magazine_foot", godot(Vector((centre.x, centre.y, dlow.z))), "drum from", godot(dlow), "to", godot(dhigh))
    print("SPEC gun length %.3f height %.3f" % (high.y - low.y, high.z - low.z))

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=False, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False,
                              export_image_format="JPEG", export_jpeg_quality=90)
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")


main()
