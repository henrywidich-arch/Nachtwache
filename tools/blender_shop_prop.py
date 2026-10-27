# Prepares a generated prop of the supply counters (the table, the medkit, the ammunition
# crate): fewer triangles, smaller pictures (colour, normal and roughness/metal stay), the
# middle of its foot on the origin, its front along +z in the game, and its final size.
# Run: blender --background --factory-startup --python blender_shop_prop.py -- <in.glb> <out.glb> <triangles> <texture> <width> <height> <depth>
#   <texture>  largest side of its pictures in pixels
#   <width> <height> <depth>  metres in the game's axes (x across, y up, z front to back);
#              0 for width and depth keeps the proportions and scales by the height alone
import bpy, sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
source, target_path, target, texture = args[0], args[1], int(args[2]), int(args[3])
width, height, depth = float(args[4]), float(args[5]), float(args[6])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
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
mesh = model.data
mesh.calc_loop_triangles()
before = len(mesh.loop_triangles)
if before > target:
    decimate = model.modifiers.new("Reduce", "DECIMATE")
    decimate.ratio = target / before
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
mesh.calc_loop_triangles()
after = len(mesh.loop_triangles)

xs = [v.co.x for v in mesh.vertices]
ys = [v.co.y for v in mesh.vertices]
zs = [v.co.z for v in mesh.vertices]
low = Vector((min(xs), min(ys), min(zs)))
high = Vector((max(xs), max(ys), max(zs)))
size = high - low
# Blender: x across, y back to front (-y is the game's front), z up.
k = height / size.z
fx = width / size.x if width > 0 else k
fy = depth / size.y if depth > 0 else k
centre = (low + high) * 0.5
mesh.transform(Matrix.Diagonal(Vector((fx, fy, k, 1.0))) @ Matrix.Translation(Vector((-centre.x, -centre.y, -low.z))))
mesh.update()
bpy.ops.object.shade_smooth()

for image in bpy.data.images:
    w, h = image.size[0], image.size[1]
    if max(w, h) > texture:
        f = texture / max(w, h)
        image.scale(int(w * f), int(h * f))

xs = [v.co.x for v in mesh.vertices]
ys = [v.co.y for v in mesh.vertices]
zs = [v.co.z for v in mesh.vertices]
print("SHOP_PROP %s %d -> %d triangles, %.3f x %.3f x %.3f m (game: across, up, deep)" % (target_path, before, after, max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys)))
bpy.ops.object.select_all(action="DESELECT")
model.select_set(True)
bpy.ops.export_scene.gltf(filepath=target_path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_image_format="JPEG", export_jpeg_quality=88)
