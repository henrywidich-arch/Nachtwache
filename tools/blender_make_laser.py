# Builds the laser module for Nachtwache: a small side-mounted aiming laser, the kind that is
# clamped to the right side of a rail or handguard. A housing of black anodised aluminium
# with rounded edges and cooling grooves, a clamp with its cross bolt on the side that
# touches the gun, a front bezel with the laser's small emitter over a larger lens, two
# adjusting screws (height, side) on top, a knurled battery cap on the outer side and a
# rubber switch pad on the back, where the thumb of the support hand finds it.
# Plain materials (no textures): the game puts its own grain on them.
#
#   blender --background --factory-startup --python tools/blender_make_laser.py -- [--out assets/models/laser.glb] [--render <folder>] [--gpu]
#
# Modelling space: x = away from the gun (the module sits on the gun's right side, the face
# that touches it at x = 0), y = forward (muzzle), z = up, metres; origin in the middle of
# the face that touches the gun. The glTF exporter turns this into Godot space (forward -Z).
# Nodes: Laser > Body (all the parts) and the empty "Emitter" in the mouth of the laser,
# where the game lets the beam begin and puts the glow.
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "laser.glb")))
RENDER = arg("--render")
GPU = "--gpu" in ARGV

# ------------------------------------------------------------------ the measures
LENGTH = (-0.026, 0.024)        # the housing from its back to its front face
WIDTH = (0.0045, 0.0205)        # the housing, from the clamp outwards
HEIGHT = 0.0105                 # half the housing's height
EMITTER = Vector((0.0125, 0.0, 0.0042))     # the laser's mouth (y: on the front face)
LENS = Vector((0.0125, 0.0, -0.0040))       # the larger lens under it


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def material(name, colour, rough, metal, emission=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    return m


def box(name, lo, hi, mat, bevel=0.0, segments=3):
    lo, hi = Vector(lo), Vector(hi)
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.data.transform(Matrix.Diagonal((*(hi - lo), 1.0)))
    obj.data.transform(Matrix.Translation((lo + hi) * 0.5))
    obj.data.materials.append(mat)
    if bevel > 0.0:
        bevel_object(obj, bevel, segments)
    return obj


def cylinder(name, a, b, radius, mat, sides=32, bevel=0.0):
    a, b = Vector(a), Vector(b)
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=(b - a).length)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    turn = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    obj.data.transform(turn)
    obj.data.transform(Matrix.Translation((a + b) * 0.5))
    obj.data.materials.append(mat)
    if bevel > 0.0:
        bevel_object(obj, bevel, 2)
    smooth(obj, 40)
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def bevel_object(obj, width, segments=3, angle=30.0):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = False
    apply_modifiers(obj)


def smooth(obj, angle=35.0):
    for p in obj.data.polygons:
        p.use_smooth = True
    mod = obj.modifiers.new("smooth", "SMOOTH_BY_ANGLE") if hasattr(bpy.types, "NodesModifier") and False else None
    try:
        obj.data.set_sharp_from_angle(angle=math.radians(angle))
    except AttributeError:
        pass


def cut(obj, tool):
    mod = obj.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = tool
    mod.solver = "EXACT"
    apply_modifiers(obj)
    bpy.data.objects.remove(tool, do_unlink=True)


def join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = name
    parts[0].data.name = name
    return parts[0]


def build():
    alu = material("anodised", (0.028, 0.029, 0.031), 0.42, 0.75)
    worn = material("edge", (0.09, 0.09, 0.095), 0.35, 0.85)
    rubber = material("rubber", (0.016, 0.016, 0.017), 0.88, 0.0)
    steel = material("steel", (0.32, 0.32, 0.33), 0.32, 1.0)
    glass = material("glass", (0.02, 0.025, 0.03), 0.05, 0.0)
    ruby = material("ruby", (0.35, 0.02, 0.015), 0.08, 0.0, emission=(0.6, 0.02, 0.01))
    white = material("marking", (0.55, 0.55, 0.53), 0.6, 0.0)
    parts = []
    # --- the housing: a rounded block, grooves along its outer side and its top
    house = box("Housing", (WIDTH[0], LENGTH[0], -HEIGHT), (WIDTH[1], LENGTH[1], HEIGHT), alu)
    for k in range(4):
        z = -0.0065 + k * 0.0043
        cut(house, box("groove", (WIDTH[1] - 0.0007, LENGTH[0] + 0.012, z - 0.0006), (WIDTH[1] + 0.01, LENGTH[1] - 0.016, z + 0.0006), alu))
    for k in range(3):
        y = -0.010 + k * 0.006
        cut(house, box("topgroove", (WIDTH[0] + 0.004, y - 0.0007, HEIGHT - 0.0006), (WIDTH[1] - 0.0045, y + 0.0007, HEIGHT + 0.01), alu))
    # Recesses on top for the two adjusting screws, and the window on the outer side for the
    # battery cap.
    for y in (0.010, 0.017):
        cut(house, cylinder("pit", (0.0125, y, HEIGHT - 0.0016), (0.0125, y, HEIGHT + 0.01), 0.0028, alu, 24))
    bevel_object(house, 0.0016, 3, 30.0)
    smooth(house, 35)
    parts.append(house)
    # --- the front: a slightly larger bezel with the two apertures
    bezel = box("Bezel", (WIDTH[0] - 0.0004, LENGTH[1] - 0.001, -HEIGHT - 0.0006), (WIDTH[1] + 0.0006, LENGTH[1] + 0.0042, HEIGHT + 0.0006), alu)
    cut(bezel, cylinder("mouth", EMITTER + Vector((0, LENGTH[1] - 0.01, 0)), EMITTER + Vector((0, LENGTH[1] + 0.01, 0)), 0.0026, alu, 28))
    cut(bezel, cylinder("lenspit", LENS + Vector((0, LENGTH[1] + 0.0012, 0)), LENS + Vector((0, LENGTH[1] + 0.01, 0)), 0.0047, alu, 32))
    bevel_object(bezel, 0.0012, 3, 30.0)
    smooth(bezel, 35)
    parts.append(bezel)
    # A steel collar round the laser's mouth, its ruby glass a little inside, and the larger
    # lens, dark glass behind a thin bright ring.
    ring = cylinder("MouthRing", EMITTER + Vector((0, LENGTH[1] + 0.0022, 0)), EMITTER + Vector((0, LENGTH[1] + 0.0048, 0)), 0.0031, steel, 28)
    cut(ring, cylinder("in", EMITTER + Vector((0, LENGTH[1], 0)), EMITTER + Vector((0, LENGTH[1] + 0.01, 0)), 0.0021, steel, 28))
    parts.append(ring)
    parts.append(cylinder("Ruby", EMITTER + Vector((0, LENGTH[1] + 0.0005, 0)), EMITTER + Vector((0, LENGTH[1] + 0.0012, 0)), 0.0024, ruby, 24))
    parts.append(cylinder("Lens", LENS + Vector((0, LENGTH[1] + 0.0008, 0)), LENS + Vector((0, LENGTH[1] + 0.0016, 0)), 0.0046, glass, 32))
    lens_rim = cylinder("LensRim", LENS + Vector((0, LENGTH[1] + 0.0012, 0)), LENS + Vector((0, LENGTH[1] + 0.0026, 0)), 0.0049, worn, 32)
    cut(lens_rim, cylinder("in", LENS + Vector((0, LENGTH[1], 0)), LENS + Vector((0, LENGTH[1] + 0.01, 0)), 0.0041, worn, 32))
    parts.append(lens_rim)
    # --- the clamp on the side that touches the gun: a plate with two jaws and its cross bolt
    clamp = box("Clamp", (0.0, -0.013, -0.0095), (WIDTH[0] + 0.001, 0.013, 0.0095), alu, bevel=0.0009)
    parts.append(clamp)
    for side in (-1.0, 1.0):
        jaw = box("Jaw", (-0.0012, -0.012, side * 0.0085 - 0.0016), (0.0022, 0.012, side * 0.0085 + 0.0016), alu, bevel=0.0006)
        parts.append(jaw)
    bolt = cylinder("CrossBolt", (-0.001, 0.0, -0.0118), (WIDTH[0] + 0.0015, 0.0, -0.0118), 0.0021, steel, 20, bevel=0.0004)
    parts.append(bolt)
    nut = cylinder("Nut", (WIDTH[0] - 0.0005, 0.0, -0.0118), (WIDTH[0] + 0.0038, 0.0, -0.0118), 0.0033, alu, 6, bevel=0.0004)
    parts.append(nut)
    # --- on top: the two adjusting screws, each slotted, with a white index mark beside it
    for y in (0.010, 0.017):
        screw = cylinder("Adjust", (0.0125, y, HEIGHT - 0.0018), (0.0125, y, HEIGHT - 0.0004), 0.0023, steel, 24, bevel=0.0003)
        cut(screw, box("slot", (0.0125 - 0.0021, y - 0.00035, HEIGHT - 0.0009), (0.0125 + 0.0021, y + 0.00035, HEIGHT + 0.002), steel))
        parts.append(screw)
        parts.append(box("Index", (0.0158, y - 0.0003, HEIGHT - 0.0001), (0.0175, y + 0.0003, HEIGHT + 0.00025), white))
    # --- the battery cap on the outer side: knurled, with a lanyard loop
    cap_at = Vector((WIDTH[1], -0.012, 0.0))
    cap = cylinder("BatteryCap", cap_at + Vector((-0.0004, 0, 0)), cap_at + Vector((0.0034, 0, 0)), 0.0068, alu, 40, bevel=0.0006)
    for k in range(24):
        a = math.tau * k / 24
        notch = box("knurl", (cap_at.x - 0.001, -0.0004, 0.0062), (cap_at.x + 0.0045, 0.0004, 0.0075), alu)
        notch.data.transform(Matrix.Translation((0, 0, 0)))
        rot = Matrix.Translation(cap_at) @ Matrix.Rotation(a, 4, "X") @ Matrix.Translation(-cap_at)
        notch.data.transform(Matrix.Translation((0, cap_at.y, 0)))
        notch.data.transform(rot)
        cut(cap, notch)
    parts.append(cap)
    parts.append(cylinder("CapFace", cap_at + Vector((0.0030, 0, 0)), cap_at + Vector((0.0037, 0, 0)), 0.0046, worn, 32))
    parts.append(box("CapSlot", (cap_at.x + 0.0035, -0.012 - 0.0034, -0.0004), (cap_at.x + 0.0040, -0.012 + 0.0034, 0.0004), alu))
    # --- the switch on the back: a raised rubber pad with ribs, the push button over it
    pad = box("SwitchPad", (WIDTH[0] + 0.0012, LENGTH[0] - 0.0032, -0.0082), (WIDTH[1] - 0.0012, LENGTH[0] + 0.001, 0.0082), rubber, bevel=0.0014)
    parts.append(pad)
    for k in range(5):
        z = -0.0056 + k * 0.0028
        parts.append(box("Rib", (WIDTH[0] + 0.0028, LENGTH[0] - 0.0039, z - 0.0005), (WIDTH[1] - 0.0028, LENGTH[0] - 0.0028, z + 0.0005), rubber, bevel=0.0003, segments=2))
    button = cylinder("Button", (0.0125, LENGTH[0] + 0.004, HEIGHT - 0.0002), (0.0125, LENGTH[0] + 0.004, HEIGHT + 0.0016), 0.0028, rubber, 24, bevel=0.0006)
    parts.append(button)
    # A thin white warning line round the front of the housing.
    parts.append(box("Warning", (WIDTH[1] - 0.0001, LENGTH[1] - 0.006, -HEIGHT + 0.002), (WIDTH[1] + 0.00025, LENGTH[1] - 0.0048, HEIGHT - 0.002), white))
    return parts


def render_views(folder):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    if GPU:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.get_devices()
                if [d for d in prefs.devices if d.type == kind]:
                    for d in prefs.devices:
                        d.use = d.type == kind
                    scene.cycles.device = "GPU"
                    break
            except TypeError:
                continue
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1000, 700
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.4, 0.41, 0.43, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4
    for name, kind, pos, energy in (("key", "AREA", (0.3, -0.25, 0.35), 6.0), ("fill", "AREA", (-0.2, 0.3, 0.2), 2.5)):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        data.size = 0.3
        lamp = link(bpy.data.objects.new(name, data))
        lamp.location = pos
        lamp.rotation_euler = (Vector((0, 0, 0)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cam = link(bpy.data.objects.new("cam", bpy.data.cameras.new("cam")))
    scene.camera = cam
    cam.data.clip_start = 0.005
    cam.data.lens = 85
    for name, pos in (("vorn", (0.12, 0.16, 0.07)), ("hinten", (0.1, -0.16, 0.09)), ("aussen", (0.2, -0.02, 0.03))):
        cam.location = pos
        cam.rotation_euler = (Vector((0.011, 0.0, 0.0)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "laser_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    clear()
    parts = build()
    body = join(parts, "Body")
    root = link(bpy.data.objects.new("Laser", None))
    body.parent = root
    emitter = link(bpy.data.objects.new("Emitter", None))
    emitter.location = EMITTER + Vector((0, LENGTH[1] + 0.0013, 0))
    emitter.parent = root
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("LASER triangles", tris)

    def godot(p):
        p = Vector(p)
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.z, -p.y)
    print("SPEC emitter", godot(emitter.location), "size x %.4f y %.4f z %.4f" % (WIDTH[1] + 0.004, HEIGHT * 2, LENGTH[1] - LENGTH[0]))
    if RENDER:
        render_views(os.path.abspath(RENDER))
    bpy.ops.object.select_all(action="DESELECT")
    for o in (body, emitter, root):
        o.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False)
    print("EXPORTED", OUT, os.path.getsize(OUT), "bytes")


main()
