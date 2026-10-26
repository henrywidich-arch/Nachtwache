# Reduces a generated high-poly .glb (one textured mesh) to a game-ready one, stands it
# on the origin (middle of its foot at 0, 0, 0) and scales it to a height.
# Run: blender --background --factory-startup --python blender_glb_reduce.py -- <in.glb> <out.glb> <triangles> <height> [texture]
#   [texture]  largest side of its pictures in pixels (they are scaled down to it), e.g. 2048
import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
source, target_path, target, height = args[0], args[1], int(args[2]), float(args[3])
texture = int(args[4]) if len(args) > 4 else 0

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
# Stand it on the origin and give it its height.
corners = [model.matrix_world @ Vector(c) for c in model.bound_box]
low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
scale = height / (high.z - low.z) if height > 0 else 1.0
model.location = Vector((-(low.x + high.x) * 0.5, -(low.y + high.y) * 0.5, -low.z))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
model.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.object.shade_smooth()
corners = [model.matrix_world @ Vector(c) for c in model.bound_box]
size = Vector((max(c.x for c in corners) - min(c.x for c in corners), max(c.y for c in corners) - min(c.y for c in corners), max(c.z for c in corners) - min(c.z for c in corners)))
print("REDUCED %d -> %d triangles, size %.2f x %.2f x %.2f m (Blender: x, y, z up)" % (before, after, size.x, size.y, size.z))
if texture > 0:
    for image in bpy.data.images:
        w, h = image.size[0], image.size[1]
        if max(w, h) > texture:
            k = texture / max(w, h)
            print("TEXTURE %s %dx%d -> %dx%d" % (image.name, w, h, int(w * k), int(h * k)))
            image.scale(int(w * k), int(h * k))
bpy.ops.export_scene.gltf(filepath=target_path, export_format="GLB", use_selection=True, export_apply=True, export_image_format="JPEG", export_jpeg_quality=88)
