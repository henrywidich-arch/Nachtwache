# Makes a generated model of a building part (a window, a door, a balcony, a shop front)
# game-ready for the facades of the simulation hall (TokyoHall), as gently as it can:
#   welds the seams the export split (Meshy cuts a model into thousands of pieces along the
#   seams of its pictures), deletes only what floats free after that, reduces it in ONE pass
#   (and only when it has more than asked), gives it its real size, flattens its depth (so
#   that it sits in a wall instead of standing out of it) and puts its origin at the middle
#   of the foot of its back: placed on a wall it stands on the wall line, its front toward
#   the street. Normals and pictures stay as they came (they were right); the pictures are
#   only made smaller. Godot makes the distance versions (LOD) on import.
# Run: blender --background --factory-startup --python blender_kit_fix.py -- <in.glb> <out.glb> <triangles> <width m> <depth m> <texture px> [flip]
#   triangles: at most this many (0: keep all).
#   width: the real width; the height follows it (the proportions stay).
#   depth: what is left of its depth (0: as it is).
#   flip: its front was its back (turned half round first).
import bpy, bmesh, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
source, target_path = args[0], args[1]
target, width, depth, texture = int(args[2]), float(args[3]), float(args[4]), int(args[5])
flip = len(args) > 6 and args[6] == "flip"

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
if flip:
    model.rotation_euler = (0, 0, math.pi)
    bpy.ops.object.transform_apply(rotation=True)

def size_of(obj):
    c = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
    lo = Vector((min(p.x for p in c), min(p.y for p in c), min(p.z for p in c)))
    hi = Vector((max(p.x for p in c), max(p.y for p in c), max(p.z for p in c)))
    return lo, hi

lo, hi = size_of(model)
diagonal = (hi - lo).length
# Reduced first, in ONE pass, while Meshy's pieces are still apart along the seams.
mesh = model.data
mesh.calc_loop_triangles()
before = len(mesh.loop_triangles)
if target > 0 and before > target:
    decimate = model.modifiers.new("Reduce", "DECIMATE")
    decimate.ratio = target / before
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
bm = bmesh.new()
bm.from_mesh(model.data)
# Only now the seams: vertices the export kept twice (the pictures' coordinates stay per
# corner). (Reduced while the pieces were still apart along the seams of the pictures, the
# reduction could not drag a picture across a seam: the pictures stay sharp.)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=diagonal * 0.0008)
# What still floats free after that: islands of very few faces in a very small box.
bm.faces.ensure_lookup_table()
seen = set()
crumbs = []
for f in bm.faces:
    if f.index in seen:
        continue
    group = []
    stack = [f]
    seen.add(f.index)
    while stack:
        g = stack.pop()
        group.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    if len(group) > 6:
        continue
    pts = [v.co for g in group for v in g.verts]
    span = Vector((max(p.x for p in pts) - min(p.x for p in pts), max(p.y for p in pts) - min(p.y for p in pts), max(p.z for p in pts) - min(p.z for p in pts)))
    if span.length < diagonal * 0.01:
        crumbs.extend(group)
bmesh.ops.delete(bm, geom=crumbs, context="FACES")
loose = [v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm, geom=loose, context="VERTS")
bm.to_mesh(model.data)
bm.free()
model.data.update()
mesh = model.data
mesh.calc_loop_triangles()
after = len(mesh.loop_triangles)
# Size: the width given, the height in proportion, the depth flattened.
lo, hi = size_of(model)
k = width / (hi.x - lo.x)
deep = (hi.y - lo.y) * k
squash = depth / deep if depth > 0 and deep > depth else 1.0
# Origin: middle of the foot of its back. In Blender the front looks toward -y (glTF +z),
# so the back is the largest y.
model.location = Vector((-(lo.x + hi.x) * 0.5, -hi.y, -lo.z))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
model.scale = (k, k * squash, k)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
lo, hi = size_of(model)
if texture > 0:
    for image in bpy.data.images:
        w, h = image.size[0], image.size[1]
        if max(w, h) > texture:
            s = texture / max(w, h)
            image.scale(int(w * s), int(h * s))
print("FIXED %s: %d crumb faces removed, %d -> %d triangles, size %.2f x %.2f x %.2f m (w, deep, high)" % (source.replace("\\", "/").split("/")[-1], len(crumbs), before, after, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))
bpy.ops.export_scene.gltf(filepath=target_path, export_format="GLB", use_selection=True, export_apply=True, export_image_format="JPEG", export_jpeg_quality=90, export_normals=True)
