# Prepares a station model for the map of mission two: a model that is built of hundreds
# of small parts (bevelled boxes and cylinders), each with a plain material and no picture
# at all, becomes one mesh with one material. Every part is thinned out by its size (a
# rivet needs no rounded edges), its lettering is kept readable, and the plain materials
# go into three tiny palette pictures - colour, occlusion/roughness/metal and glow - that
# every part points into with its texture coordinates. Lamps, displays and signs glow.
# Run: blender --background --factory-startup --python blender_station.py -- <in.glb> <out.glb> <height> [option=value ...]
#   <in.glb>   the model as it came from the generator (many meshes, plain materials)
#   <out.glb>  where the prepared model goes; its name becomes the name of mesh and material
#   <height>   final height in metres
#   turn=<deg>      degrees to turn it about the upright axis first (its front should look along +z in the game)
#   detail=<f>      how much of the parts' triangles stays, as a factor on the table below (1.0)
#   letters=<n>     triangles a piece of lettering may keep (3600)
#   sharp=<deg>     edges sharper than this stay edges (32)
#   lift=<f>        how much the dark colours are raised (0.0: as they are; 1.0: clearly)
#   metal=<f>       factor on how metallic the surfaces are (1.0)
#   report=<file>   writes the figures there too
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
source, target_file, height = args[0], args[1], float(args[2])
options = dict(a.split("=", 1) for a in args[3:] if "=" in a)
name = os.path.splitext(os.path.basename(target_file))[0]
turn = float(options.get("turn", 0.0))
detail = float(options.get("detail", 1.0))
letters = int(options.get("letters", 3600))
lift = float(options.get("lift", 0.0))
metal_factor = float(options.get("metal", 1.0))

# What glows, by a word in the material's name: its share of the colour, and how much
# the colour itself is raised so that it reads lit.
GLOWS = [
    (("lamp", "lens"), 1.0),
    (("mint", "jade", "terminal green", "display", "interface", "instrument"), 0.9),
    (("sign", "enamel", "ivory"), 0.34),
    (("red",), 0.25),
]
# Parts whose name says they are lettering: they keep their outlines.
LETTERING = ("sign", "title", "identification", "label", "letter")
CELL = 16
GRID = 4

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def corners(objects):
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in objects:
        for vertex in obj.data.vertices:
            p = vertex.co
            low = Vector((min(low.x, p.x), min(low.y, p.y), min(low.z, p.z)))
            high = Vector((max(high.x, p.x), max(high.y, p.y), max(high.z, p.z)))
    return low, high

low, high = corners(parts)
factor = height / (high.z - low.z)

# --- the palette: one cell for every material
materials = []
for part in parts:
    for material in part.data.materials:
        if material is not None and material not in materials:
            materials.append(material)
if len(materials) > GRID * GRID:
    raise SystemExit("too many materials for the palette: %d" % len(materials))

def to_srgb(value):
    value = max(0.0, min(1.0, value))
    return value * 12.92 if value <= 0.0031308 else 1.055 * value ** (1.0 / 2.4) - 0.055

def plain(material):
    shader = None
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            shader = node
    colour = tuple(shader.inputs["Base Color"].default_value[:3])
    metal = float(shader.inputs["Metallic"].default_value) * metal_factor
    rough = float(shader.inputs["Roughness"].default_value)
    glow = 0.0
    lowered = material.name.lower()
    for words, share in GLOWS:
        if glow == 0.0 and any(word in lowered for word in words):
            glow = share
    # A surface that is nearly black shows nothing of its shape under the lamps of the
    # facility: the dark ones are raised a little, the darkest the most.
    if lift > 0.0 and glow == 0.0:
        bright = max(colour)
        gain = 1.0 + lift * 2.2 * max(0.0, 1.0 - bright / 0.16)
        colour = tuple(min(1.0, c * gain + lift * 0.012 * max(0.0, 1.0 - bright / 0.05)) for c in colour)
    return colour, metal, rough, glow

side = CELL * GRID
colour_pixels = [0.0, 0.0, 0.0, 1.0] * (side * side)
orm_pixels = [1.0, 1.0, 0.0, 1.0] * (side * side)
glow_pixels = [0.0, 0.0, 0.0, 1.0] * (side * side)
cells = {}
glowing = []
for index, material in enumerate(materials):
    colour, metal, rough, glow = plain(material)
    column, row = index % GRID, index // GRID
    cells[material.name] = ((column + 0.5) / GRID, (row + 0.5) / GRID)
    if glow > 0.0:
        glowing.append("%s %.2f" % (material.name, glow))
    for y in range(row * CELL, (row + 1) * CELL):
        for x in range(column * CELL, (column + 1) * CELL):
            at = (y * side + x) * 4
            colour_pixels[at:at + 3] = [to_srgb(c) for c in colour]
            orm_pixels[at:at + 3] = [1.0, rough, metal]
            glow_pixels[at:at + 3] = [to_srgb(c * glow) for c in colour]

def picture(title, pixels, data):
    image = bpy.data.images.new(title, side, side, alpha=False, is_data=data)
    image.pixels = pixels
    image.file_format = "PNG"
    image.pack()
    return image

# --- every part: thinned out by its size, and pointing into its cell
def keep_share(size, triangles, lettering):
    if lettering:
        return min(1.0, letters / triangles)
    if triangles > 600:
        # Hoops and rings: rounded twice over.
        return (90.0 if size < 0.1 else 220.0) / triangles
    if size < 0.015:
        share = 0.12
    elif size < 0.04:
        share = 0.2
    elif size < 0.12:
        share = 0.3
    elif size < 0.4:
        share = 0.42
    else:
        share = 0.6
    return min(1.0, share * detail)

before = 0
for part in parts:
    mesh = part.data
    mesh.calc_loop_triangles()
    triangles = len(mesh.loop_triangles)
    before += triangles
    part_low, part_high = corners([part])
    size = max(part_high - part_low) * factor
    lettering = triangles > 300 and any(word in part.name.lower() for word in LETTERING)
    if lettering:
        # Flat faces of letters are cut into far more triangles than they need.
        work = bmesh.new()
        work.from_mesh(mesh)
        bmesh.ops.remove_doubles(work, verts=work.verts, dist=0.00005)
        bmesh.ops.dissolve_limit(work, angle_limit=math.radians(3.0), verts=work.verts, edges=work.edges)
        bmesh.ops.triangulate(work, faces=work.faces)
        work.to_mesh(mesh)
        work.free()
        mesh.calc_loop_triangles()
        triangles = len(mesh.loop_triangles)
    share = keep_share(size, triangles, lettering)
    if share < 0.999 and triangles > 12:
        bpy.context.view_layer.objects.active = part
        modifier = part.modifiers.new("Reduce", "DECIMATE")
        modifier.ratio = max(share, 12.5 / triangles)
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        slot = mesh.materials[polygon.material_index] if polygon.material_index < len(mesh.materials) else None
        u, v = cells[slot.name] if slot is not None else (0.5 / GRID, 0.5 / GRID)
        for loop in polygon.loop_indices:
            layer.data[loop].uv = (u, v)

bpy.ops.object.select_all(action="DESELECT")
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
model = bpy.context.view_layer.objects.active
mesh = model.data
if turn != 0.0:
    mesh.transform(Matrix.Rotation(math.radians(turn), 4, "Z"))
low, high = corners([model])
factor = height / (high.z - low.z)
centre = (low + high) * 0.5
mesh.transform(Matrix.Translation(Vector((-centre.x * factor, -centre.y * factor, -low.z * factor))) @ Matrix.Scale(factor, 4))
mesh.update()
for polygon in mesh.polygons:
    polygon.use_smooth = True
mesh.set_sharp_from_angle(angle=math.radians(float(options.get("sharp", 32.0))))

# --- one material over the three palettes
mesh.materials.clear()
surface = bpy.data.materials.new(name)
surface.use_nodes = True
tree = surface.node_tree
shader = tree.nodes.get("Principled BSDF")
colour_node = tree.nodes.new("ShaderNodeTexImage")
colour_node.image = picture(name + "_color", colour_pixels, False)
colour_node.interpolation = "Closest"
tree.links.new(colour_node.outputs["Color"], shader.inputs["Base Color"])
orm_node = tree.nodes.new("ShaderNodeTexImage")
orm_node.image = picture(name + "_orm", orm_pixels, True)
orm_node.interpolation = "Closest"
split = tree.nodes.new("ShaderNodeSeparateColor")
tree.links.new(orm_node.outputs["Color"], split.inputs["Color"])
tree.links.new(split.outputs["Green"], shader.inputs["Roughness"])
tree.links.new(split.outputs["Blue"], shader.inputs["Metallic"])
if glowing:
    glow_node = tree.nodes.new("ShaderNodeTexImage")
    glow_node.image = picture(name + "_glow", glow_pixels, False)
    glow_node.interpolation = "Closest"
    tree.links.new(glow_node.outputs["Color"], shader.inputs["Emission Color"])
    shader.inputs["Emission Strength"].default_value = float(options.get("glow", 1.0))
mesh.materials.append(surface)
for polygon in mesh.polygons:
    polygon.material_index = 0
model.name = name
mesh.name = name

low, high = corners([model])
mesh.calc_loop_triangles()
line = "STATION %s parts %d materials %d tris %d -> %d size %.2f %.2f %.2f (x, y, z-up) glows: %s" % (
    name, len(parts), len(materials), before, len(mesh.loop_triangles), high.x - low.x, high.y - low.y, high.z - low.z, "; ".join(glowing))
print(line)
if "report" in options:
    with open(options["report"], "a") as out:
        out.write(line + "\n")
bpy.ops.object.select_all(action="DESELECT")
model.select_set(True)
bpy.context.view_layer.objects.active = model
bpy.ops.export_scene.gltf(filepath=target_file, export_format="GLB", use_selection=True, export_yup=True, export_image_format="AUTO", export_tangents=False)
print("STATION_DONE", target_file)
