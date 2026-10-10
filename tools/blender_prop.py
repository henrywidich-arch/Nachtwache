# Prepares a generated prop for the map of mission two: fewer triangles, an ordinary lit
# colour texture instead of one that only glows, the right size, standing on the origin.
# Run: blender --background --factory-startup --python blender_prop.py -- <in.glb> <out.glb> <triangles> <height> [turn]
#   <in.glb>     the model as it came from the generator (one mesh, its picture as emission)
#   <out.glb>    where the prepared model goes; its name becomes the name of mesh and material
#   <triangles>  target triangle count
#   <height>     final height in metres
#   [turn]       degrees to turn it about the upright axis first (its front should look along +z in the game)
import bpy, sys, os, math
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
source, target_file, target = args[0], args[1], int(args[2])
height = float(args[3])
turn = float(args[4]) if len(args) > 4 else 0.0
name = os.path.splitext(os.path.basename(target_file))[0]

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

# The picture the generator painted: whatever image its material uses.
picture = None
for material in mesh.materials:
    if material is None or not material.use_nodes:
        continue
    for node in material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            picture = node.image
print("PICTURE", picture.name if picture else None, tuple(picture.size) if picture else None)

mesh.calc_loop_triangles()
before = len(mesh.loop_triangles)
if before > target:
    modifier = model.modifiers.new("Reduce", "DECIMATE")
    modifier.ratio = target / before
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)

def bounds(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))

if turn != 0.0:
    mesh.transform(Matrix.Rotation(math.radians(turn), 4, "Z"))
low, high = bounds(model)
size = high - low
factor = height / size.z
centre = (low + high) * 0.5
mesh.transform(Matrix.Translation(Vector((-centre.x * factor, -centre.y * factor, -low.z * factor))) @ Matrix.Scale(factor, 4))
mesh.update()
for polygon in mesh.polygons:
    polygon.use_smooth = True

# An ordinary surface: the picture is its colour, nothing glows.
mesh.materials.clear()
surface = bpy.data.materials.new(name)
surface.use_nodes = True
tree = surface.node_tree
shader = tree.nodes.get("Principled BSDF")
shader.inputs["Roughness"].default_value = 0.72
shader.inputs["Metallic"].default_value = 0.0
if picture is not None:
    picture.name = name + "_color"
    texture = tree.nodes.new("ShaderNodeTexImage")
    texture.image = picture
    tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
mesh.materials.append(surface)
model.name = name
mesh.name = name

low, high = bounds(model)
mesh.calc_loop_triangles()
print("PROP %s tris %d -> %d size %.2f %.2f %.2f (x, y, z-up)" % (name, before, len(mesh.loop_triangles), high.x - low.x, high.y - low.y, high.z - low.z))
bpy.ops.object.select_all(action="DESELECT")
model.select_set(True)
bpy.context.view_layer.objects.active = model
bpy.ops.export_scene.gltf(filepath=target_file, export_format="GLB", use_selection=True, export_yup=True, export_image_format="JPEG", export_tangents=False)
print("PROP_DONE", target_file)
