# Looks at generated .glb models and says what is wrong with them: triangles, size, where
# the origin is, loose islands (floating bits), open edges (holes), faces that look inward,
# pictures and their sizes.
# Run: blender --background --factory-startup --python blender_glb_inspect.py -- <a.glb> [<b.glb> ...]
import bpy, bmesh, sys
from mathutils import Vector

files = sys.argv[sys.argv.index("--") + 1:]
for path in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    corners = []
    for o in meshes:
        corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    tris = 0
    islands_all = []
    open_edges = 0
    inward = 0
    faces_all = 0
    for o in meshes:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        tris += len(bm.faces)
        open_edges += sum(1 for e in bm.edges if len(e.link_faces) == 1)
        # Islands by shared vertices.
        bm.verts.ensure_lookup_table()
        seen = set()
        for v in bm.verts:
            if v.index in seen:
                continue
            stack = [v]
            count = 0
            box_lo = Vector(v.co)
            box_hi = Vector(v.co)
            seen.add(v.index)
            while stack:
                w = stack.pop()
                count += 1
                box_lo = Vector((min(box_lo.x, w.co.x), min(box_lo.y, w.co.y), min(box_lo.z, w.co.z)))
                box_hi = Vector((max(box_hi.x, w.co.x), max(box_hi.y, w.co.y), max(box_hi.z, w.co.z)))
                for e in w.link_edges:
                    u = e.other_vert(w)
                    if u.index not in seen:
                        seen.add(u.index)
                        stack.append(u)
            islands_all.append((count, (box_hi - box_lo).length))
        # Faces whose normal points toward the middle of the model: likely flipped.
        middle = (low + high) * 0.5
        for f in bm.faces:
            faces_all += 1
            if (f.calc_center_median() - middle).dot(f.normal) < -0.0001 * (high - low).length:
                inward += 1
        bm.free()
    size = high - low
    tiny = sum(1 for c, d in islands_all if d < size.length * 0.03)
    print("MODEL %s" % path.split("\\")[-1].split("/")[-1])
    print("  triangles %d, meshes %d, size %.3f x %.3f x %.3f (x, y deep, z up), origin offset to foot-middle %.3f %.3f %.3f" % (tris, len(meshes), size.x, size.y, size.z, (low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    print("  islands %d (tiny floating ones %d), open edges %d, inward faces %.1f %%" % (len(islands_all), tiny, open_edges, 100.0 * inward / max(1, faces_all)))
    for image in bpy.data.images:
        if image.size[0] > 0:
            print("  picture %s %dx%d" % (image.name, image.size[0], image.size[1]))
