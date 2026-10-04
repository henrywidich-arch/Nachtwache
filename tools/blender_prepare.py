# Reduces a generated high-poly model to a game-ready mesh and stands it on the origin.
# Run: blender --background --factory-startup --python blender_prepare.py -- <in> <out_base> <triangles> <height> [length]
#   <in>         .obj or .fbx as it came from the generator
#   <out_base>   path without extension; writes <out_base>.glb and <out_base>.obj
#   <triangles>  target triangle count
#   <height>     final height in metres (0 keeps the scale and uses <length> instead)
#   [length]     final length along the body axis in metres, for four-legged models
import bpy, sys, os
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
source, out_base, target = args[0], args[1], int(args[2])
height = float(args[3])
length = float(args[4]) if len(args) > 4 else 0.0

bpy.ops.wm.read_factory_settings(use_empty=True)
if source.lower().endswith(".obj"):
    bpy.ops.wm.obj_import(filepath=source)
else:
    try:
        bpy.ops.wm.fbx_import(filepath=source)
    except Exception as error:
        print("wm.fbx_import failed:", error)
        bpy.ops.import_scene.fbx(filepath=source)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    print("OBJECT", o.name, o.type, "scale", tuple(round(v, 4) for v in o.scale), "rot", tuple(round(v, 3) for v in o.rotation_euler))
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

def bounds(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))

low, high = bounds(model)
print("BEFORE tris", before, "verts", len(mesh.vertices), "min", tuple(round(v, 3) for v in low), "max", tuple(round(v, 3) for v in high))

if before > target:
    modifier = model.modifiers.new("Reduce", "DECIMATE")
    modifier.ratio = target / before
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)

# Stand on the ground, centred, at the requested size.
low, high = bounds(model)
size = high - low
factor = 1.0
if height > 0.0:
    factor = height / size.z
elif length > 0.0:
    factor = length / max(size.x, size.y)
centre = (low + high) * 0.5
shift = Matrix.Translation(Vector((-centre.x * factor, -centre.y * factor, -low.z * factor)))
mesh.transform(shift @ Matrix.Scale(factor, 4))
mesh.update()
for polygon in mesh.polygons:
    polygon.use_smooth = True
low, high = bounds(model)
mesh.calc_loop_triangles()
print("AFTER tris", len(mesh.loop_triangles), "verts", len(mesh.vertices), "min", tuple(round(v, 3) for v in low), "max", tuple(round(v, 3) for v in high), "uv", [uv.name for uv in mesh.uv_layers])
model.name = os.path.basename(out_base)
mesh.materials.clear()

bpy.ops.object.select_all(action="DESELECT")
model.select_set(True)
bpy.context.view_layer.objects.active = model
bpy.ops.export_scene.gltf(filepath=out_base + ".glb", export_format="GLB", use_selection=True, export_materials="NONE", export_yup=True)
bpy.ops.wm.obj_export(filepath=out_base + ".obj", export_selected_objects=True, export_materials=False, export_uv=True, export_normals=True, export_triangulated_mesh=True)
print("PREPARE_DONE", out_base)
