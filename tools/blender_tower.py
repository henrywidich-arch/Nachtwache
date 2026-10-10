# Prepares one of the generated containment towers for the hall of mission two: a mesh of
# a few thousand triangles with a new, tidy layout of its skin, and the look of the
# original - two million triangles and more - baked on to it: colour, relief (a normal
# map that holds the bars, panels and hose ribs the mesh has lost), what glows, and how
# rough and how metallic it is.
#
# Run: blender --background --factory-startup --python blender_tower.py -- <in.glb> <out.glb> <triangles> <height> [options]
#   <in.glb>      the model as it came from the generator (base_basic_pbr.glb: colour, normal, metal/rough)
#   <out.glb>     where the prepared model goes; its name becomes the name of mesh, material and pictures
#   <triangles>   target triangle count
#   <height>      final height in metres
# Options (name=value):
#   turn=<deg>        turn it about the upright axis first (its front should look along +z in the game)
#   glow=<file|auto>  the picture of what glows (texture_emissive.png), or "auto": taken from
#                     the colour picture - the bright, saturated cyan and amber of displays and lamps
#   size=<pixels>     edge of the colour and relief pictures (2048); glow and metal/rough get half
#   threads=<n>       processor threads to use (6)
#   breach=<x,z,w,h,d>  also writes <out>_burst.glb: the same tower torn open from inside - a
#                     ragged hole in its front (+z in the game), its middle x metres from the
#                     axis and z metres above the floor, w wide, h tall and d deep, the steel
#                     around it bent outwards. That file has no pictures of its own: in the
#                     game its first surface is the intact tower's (same mesh, same layout),
#                     its second ("…_inside") the dark of the hole and the torn edges.
#   voxel=<share>     size of the envelope's voxels as a share of the height (0.006; 0: none,
#                     the generated mesh itself is reduced)
#   sharp=<deg>       edges sharper than this stay edges (52)
#   profile=<n>       prints the footprint of n slices of its height (for the collision boxes)
#   log=<file>        what this script prints goes there (Blender has no console on a hidden desktop)
#   calm=1            runs at low priority (somebody is using the machine)
import bpy, bmesh, sys, os, math, random
import numpy as np
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
source, target_file, target, height = args[0], args[1], int(args[2]), float(args[3])
options = dict(a.split("=", 1) for a in args[4:])
if "log" in options:
    sys.stdout = open(options["log"], "w", buffering=1)
    sys.stderr = sys.stdout
if options.get("calm", "0") == "1" and os.name == "nt":
    import ctypes
    ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x00004000)
turn = float(options.get("turn", 0.0))
glow_source = options.get("glow", "auto")
edge = int(options.get("size", 2048))
threads = int(options.get("threads", 6))
name = os.path.splitext(os.path.basename(target_file))[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=source)
meshes = [o for o in scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
high = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
high.name = "high"

def bounds(obj):
    count = len(obj.data.vertices)
    flat = np.empty(count * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", flat)
    points = flat.reshape(count, 3)
    return Vector(points.min(axis=0)), Vector(points.max(axis=0)), points

# Its final size and place: standing on the origin, the middle of its footprint on the axis.
if turn != 0.0:
    high.data.transform(Matrix.Rotation(math.radians(turn), 4, "Z"))
low_corner, high_corner, _ = bounds(high)
factor = height / (high_corner.z - low_corner.z)
centre = (low_corner + high_corner) * 0.5
high.data.transform(Matrix.Translation(Vector((-centre.x * factor, -centre.y * factor, -low_corner.z * factor))) @ Matrix.Scale(factor, 4))
high.data.update()

# What the original looks like: its pictures.
original = high.data.materials[0]
pictures = {}
for node in original.node_tree.nodes:
    if node.type == "TEX_IMAGE" and node.image is not None:
        for link in node.outputs["Color"].links:
            if link.to_socket.name == "Base Color":
                pictures["colour"] = node.image
            elif link.to_node.type == "NORMAL_MAP":
                pictures["normal"] = node.image
            elif link.to_node.type in ("SEPARATE_COLOR", "SEPRGB"):
                pictures["metal_rough"] = node.image
print("PICTURES", {key: (image.name, tuple(image.size)) for key, image in pictures.items()})

def pixels_of(image):
    data = np.empty(image.size[0] * image.size[1] * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(image.size[1], image.size[0], 4)

def picture_from(pixels, title, data):
    image = bpy.data.images.new(title, pixels.shape[1], pixels.shape[0], alpha=False, is_data=data)
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    return image

if glow_source == "auto":
    # Displays and lamps are the only bright, saturated cyan and amber on these machines.
    colour = pixels_of(pictures["colour"])
    r, g, b = colour[..., 0], colour[..., 1], colour[..., 2]
    most = np.maximum(np.maximum(r, g), b)
    least = np.minimum(np.minimum(r, g), b)
    saturation = (most - least) / np.maximum(most, 1e-5)
    cyan = (g > 0.42) & (b > 0.34) & (r < g * 0.62) & (saturation > 0.5)
    amber = (r > 0.62) & (g > 0.32) & (g < r * 0.86) & (b < r * 0.45) & (saturation > 0.6)
    mask = (cyan | amber).astype(np.float32)
    glow = colour.copy()
    glow[..., 0:3] *= mask[..., None]
    glow[..., 3] = 1.0
    pictures["glow"] = picture_from(glow, "glow_source", False)
    print("GLOW auto: %.3f %% of the colour picture glows" % (100.0 * mask.mean()))
elif glow_source != "none":
    pictures["glow"] = bpy.data.images.load(glow_source)

# --- the game's mesh
bpy.ops.object.select_all(action="DESELECT")
high.select_set(True)
bpy.context.view_layer.objects.active = high
bpy.ops.object.duplicate()
low = bpy.context.view_layer.objects.active
low.name = name
low.data.name = name
low.data.calc_loop_triangles()
before = len(low.data.loop_triangles)
# An envelope first: the generated mesh is a thicket of bars and shards that no reduction
# turns into clean faces. A skin drawn over it at the size of a voxel is one closed,
# even surface; that is what gets reduced. What it smooths over comes back as relief.
voxel = float(options.get("voxel", 0.006)) * height
if voxel > 0.0:
    wrap = low.modifiers.new("Envelope", "REMESH")
    wrap.mode = "VOXEL"
    wrap.voxel_size = voxel
    wrap.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier=wrap.name)
    low.data.calc_loop_triangles()
    print("ENVELOPE voxel %.3f m: %d triangles" % (voxel, len(low.data.loop_triangles)))
if len(low.data.loop_triangles) > target:
    modifier = low.modifiers.new("Reduce", "DECIMATE")
    modifier.ratio = target / len(low.data.loop_triangles)
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0005)
bpy.ops.mesh.delete_loose()
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
mesh = low.data
while mesh.uv_layers:
    mesh.uv_layers.remove(mesh.uv_layers[0])
mesh.uv_layers.new(name="UVMap")
for polygon in mesh.polygons:
    polygon.use_smooth = True
mesh.set_sharp_from_angle(angle=math.radians(float(options.get("sharp", 52.0))))
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), margin_method="SCALED", island_margin=0.0035, area_weight=0.0)
bpy.ops.object.mode_set(mode="OBJECT")
mesh.calc_loop_triangles()
after = len(mesh.loop_triangles)

# --- baking
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 2
scene.cycles.use_denoising = False
scene.render.threads_mode = "FIXED"
scene.render.threads = threads
settings = scene.render.bake
settings.use_selected_to_active = True
settings.cage_extrusion = height * 0.014
settings.max_ray_distance = height * 0.07
settings.margin = 10
settings.margin_type = "EXTEND"
settings.use_clear = True
settings.target = "IMAGE_TEXTURES"

surface = bpy.data.materials.new(name)
surface.use_nodes = True
tree = surface.node_tree
shader = tree.nodes.get("Principled BSDF")
mesh.materials.clear()
mesh.materials.append(surface)

def target_picture(title, size, data):
    image = bpy.data.images.new(title, size, size, alpha=False, is_data=data)
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    return image, node

def bake(kind, node):
    for other in tree.nodes:
        other.select = False
    node.select = True
    tree.nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type=kind)
    print("BAKED", kind, node.image.name)

# The relief first, from the original as it is (its own normal map counts).
settings.normal_space = "TANGENT"
normal_image, normal_node = target_picture(name + "_normal", edge, True)
bake("NORMAL", normal_node)

# Everything else is carried over unlit: the original shines with the picture in question.
carrier = bpy.data.materials.new("carrier")
carrier.use_nodes = True
carry = carrier.node_tree
for node in list(carry.nodes):
    carry.nodes.remove(node)
out = carry.nodes.new("ShaderNodeOutputMaterial")
shine = carry.nodes.new("ShaderNodeEmission")
carry.links.new(shine.outputs["Emission"], out.inputs["Surface"])
feed = carry.nodes.new("ShaderNodeTexImage")
split = carry.nodes.new("ShaderNodeSeparateColor")
carry.links.new(feed.outputs["Color"], split.inputs["Color"])
high.data.materials.clear()
high.data.materials.append(carrier)

def carry_over(picture, channel, title, size, data):
    feed.image = picture
    for link in list(shine.inputs["Color"].links):
        carry.links.remove(link)
    carry.links.new((feed.outputs["Color"] if channel == "" else split.outputs[channel]), shine.inputs["Color"])
    bpy.context.view_layer.update()
    image, node = target_picture(title, size, data)
    bake("EMIT", node)
    most = float(pixels_of(image)[..., 0:3].max())
    print("CARRIED %s most %.3f" % (title, most))
    if most <= 0.0:
        # (The first bake after the original got another surface came out black once.)
        bake("EMIT", node)
        print("CARRIED again %s most %.3f" % (title, float(pixels_of(image)[..., 0:3].max())))
    return image, node

colour_image, colour_node = carry_over(pictures["colour"], "", name + "_color", edge, False)
glow_image, glow_node = None, None
if "glow" in pictures:
    glow_image, glow_node = carry_over(pictures["glow"], "", name + "_glow", edge // 2, False)
orm_image, orm_node = None, None
if "metal_rough" in pictures:
    rough_image, rough_node = carry_over(pictures["metal_rough"], "Green", name + "_rough", edge // 2, True)
    metal_image, metal_node = carry_over(pictures["metal_rough"], "Blue", name + "_metal", edge // 2, True)
    rough = pixels_of(rough_image)
    metal = pixels_of(metal_image)
    packed = np.ones_like(rough)
    packed[..., 1] = rough[..., 0]
    packed[..., 2] = metal[..., 0]
    orm_image = picture_from(packed, name + "_orm", True)
    orm_node = tree.nodes.new("ShaderNodeTexImage")
    orm_node.image = orm_image
    print("SURFACE rough %.2f metal %.2f (mean)" % (float(rough[..., 0].mean()), float(metal[..., 0].mean())))
    tree.nodes.remove(rough_node)
    tree.nodes.remove(metal_node)

# --- the surface the game gets
# (Never touch the colour space of a baked picture: that throws its pixels away.)
tree.links.new(colour_node.outputs["Color"], shader.inputs["Base Color"])
bump = tree.nodes.new("ShaderNodeNormalMap")
tree.links.new(normal_node.outputs["Color"], bump.inputs["Color"])
tree.links.new(bump.outputs["Normal"], shader.inputs["Normal"])
if glow_node is not None:
    tree.links.new(glow_node.outputs["Color"], shader.inputs["Emission Color"])
    shader.inputs["Emission Strength"].default_value = 1.0
if orm_node is not None:
    parts = tree.nodes.new("ShaderNodeSeparateColor")
    tree.links.new(orm_node.outputs["Color"], parts.inputs["Color"])
    tree.links.new(parts.outputs["Green"], shader.inputs["Roughness"])
    tree.links.new(parts.outputs["Blue"], shader.inputs["Metallic"])
else:
    shader.inputs["Roughness"].default_value = 0.6
    shader.inputs["Metallic"].default_value = 0.5

low_corner, high_corner, points = bounds(low)
print("TOWER %s tris %d -> %d size %.2f %.2f %.2f (x, y, z-up)" % (name, before, after, high_corner.x - low_corner.x, high_corner.y - low_corner.y, high_corner.z - low_corner.z))
slices = int(options.get("profile", 0))
for index in range(slices):
    z0 = height * index / slices
    z1 = height * (index + 1) / slices
    band = points[(points[:, 2] >= z0) & (points[:, 2] <= z1)]
    if len(band) > 0:
        print("PROFILE %5.2f-%5.2f  x %6.2f %6.2f  depth(-z game) %6.2f %6.2f" % (z0, z1, band[:, 0].min(), band[:, 0].max(), band[:, 1].min(), band[:, 1].max()))

bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.export_scene.gltf(filepath=target_file, export_format="GLB", use_selection=True, export_yup=True, export_image_format="JPEG", export_jpeg_quality=int(options.get("quality", 86)), export_tangents=False)
print("TOWER_DONE", target_file)

# --- the same tower, torn open
if "breach" in options:
    at_x, at_z, wide, tall, deep = [float(v) for v in options["breach"].split(",")]
    dice = random.Random(int(options.get("seed", 7)))
    inside = bpy.data.materials.new(name + "_inside")
    inside.use_nodes = True
    inside.use_backface_culling = False
    dark = inside.node_tree.nodes.get("Principled BSDF")
    dark.inputs["Base Color"].default_value = (0.012, 0.016, 0.015, 1.0)
    dark.inputs["Roughness"].default_value = 0.32
    dark.inputs["Metallic"].default_value = 0.7
    # The outline of the hole: an ellipse with teeth.
    count = 22
    outline = []
    for index in range(count):
        angle = math.tau * index / count
        reach = 1.0 + dice.uniform(-0.2, 0.12) + (0.16 if index % 3 == 0 else 0.0)
        outline.append((at_x + math.cos(angle) * wide * 0.5 * reach, at_z + math.sin(angle) * tall * 0.5 * reach))
    # Where the tower's skin lies behind every point of it (looked for from the front).
    front = low_corner.y - 1.0
    skin = []
    for x, z in outline:
        hit, where, normal, face = low.ray_cast(Vector((x, front, z)), Vector((0.0, 1.0, 0.0)))
        skin.append(where.y if hit else low_corner.y + 0.4)
    body = bmesh.new()
    near = [body.verts.new((x, front, z)) for x, z in outline]
    far = [body.verts.new((x, min(skin) + deep, z)) for x, z in outline]
    body.faces.new(near)
    body.faces.new(list(reversed(far)))
    for index in range(count):
        other = (index + 1) % count
        body.faces.new([near[index], far[index], far[other], near[other]])
    bmesh.ops.recalc_face_normals(body, faces=body.faces[:])
    cutter_mesh = bpy.data.meshes.new("cutter")
    body.to_mesh(cutter_mesh)
    body.free()
    cutter_mesh.materials.append(inside)
    cutter = bpy.data.objects.new("cutter", cutter_mesh)
    scene.collection.objects.link(cutter)
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    cut = low.modifiers.new("Breach", "BOOLEAN")
    cut.operation = "DIFFERENCE"
    cut.object = cutter
    cut.solver = "EXACT"
    cut.material_mode = "TRANSFER"
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(cutter)
    mesh = low.data
    slot = mesh.materials.find(inside.name)
    if slot < 0:
        mesh.materials.append(inside)
        slot = len(mesh.materials) - 1
    # The steel around the hole, bent outwards: a tongue on most stretches of the outline.
    rim = bmesh.new()
    rim.from_mesh(mesh)
    for index in range(count):
        if dice.random() < 0.18:
            continue
        other = (index + 1) % count
        a = Vector((outline[index][0], skin[index], outline[index][1]))
        b = Vector((outline[other][0], skin[other], outline[other][1]))
        middle = (a + b) * 0.5
        away = Vector((middle.x - at_x, 0.0, middle.z - at_z)).normalized()
        tip = middle + away * dice.uniform(0.18, 0.5) + Vector((0.0, -dice.uniform(0.25, 0.75), 0.0)) + Vector((dice.uniform(-0.12, 0.12), 0.0, dice.uniform(-0.12, 0.12)))
        tongue = rim.faces.new([rim.verts.new(a), rim.verts.new(b), rim.verts.new(tip)])
        tongue.material_index = slot
        tongue.smooth = False
    rim.to_mesh(mesh)
    rim.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = polygon.material_index != slot
    mesh.set_sharp_from_angle(angle=math.radians(float(options.get("sharp", 52.0))))
    low.name = name + "_burst"
    mesh.name = name + "_burst"
    mesh.calc_loop_triangles()
    print("BURST %s tris %d surfaces %s" % (low.name, len(mesh.loop_triangles), [m.name for m in mesh.materials]))
    burst_file = os.path.splitext(target_file)[0] + "_burst.glb"
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.export_scene.gltf(filepath=burst_file, export_format="GLB", use_selection=True, export_yup=True, export_image_format="NONE", export_tangents=False)
    print("BURST_DONE", burst_file)
