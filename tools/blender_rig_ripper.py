# Rigs, skins and animates the mutant hound ("Ripper") and writes a game-ready GLB.
#
# Run (Blender 5.1, headless):
#   blender --background --factory-startup --python blender_rig_ripper.py -- <mesh> <texture_dir> <out.glb> [options]
#     <mesh>         prepared static mesh from blender_prepare.py (hund.obj, or hund.glb): stands on the origin,
#                    faces +Z in glTF/Godot space, metres
#     <texture_dir>  folder with texture_diffuse.png, texture_normal.png, texture_roughness.png, texture_metallic.png
#     <out.glb>      result: one skinned mesh, one armature, eight animation clips, 2048 px textures embedded
#   options:
#     --review <dir>     also render review PNGs (weights, test poses, one frame strip per clip) into <dir>
#     --work <dir>       where the resized textures are written (default: a temp folder)
#     --blend <file>     additionally save the Blender scene for inspection
#     --weights <mode>   auto (default: bone heat, then the fallbacks), proxy (voxel proxy + transfer), distance
#     --tex <pixels>     texture size, default 2048
#
# Everything is rebuilt from the inputs on every run: joint positions, weights and animations are defined in this file.
# Blender space is used throughout: X = the animal's left, -Y = forward, Z = up (glTF/Godot: X left, Y up, +Z forward).
import bpy, bmesh, sys, os, math, time, tempfile
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

T0 = time.time()


def log(*a):
    print("[ripper %6.1fs]" % (time.time() - T0), *a)
    sys.stdout.flush()


# ------------------------------------------------------------------------------------------------ arguments
OPT = {"review": None, "work": None, "blend": None, "weights": "auto", "tex": "2048", "only": None, "debug": None}
MESH_PATH = TEX_DIR = OUT_GLB = REVIEW = WORK = None
TEX_SIZE = 2048
FPS = 30


def parse_args():
    global MESH_PATH, TEX_DIR, OUT_GLB, REVIEW, WORK, TEX_SIZE
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    pos_args = []
    i = 0
    while i < len(argv):
        if argv[i].startswith("--") and argv[i][2:] in OPT:
            OPT[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            pos_args.append(argv[i])
            i += 1
    if len(pos_args) < 3:
        print("usage: blender --background --factory-startup --python blender_rig_ripper.py -- <mesh> <texture_dir> <out.glb> [--review dir] [--work dir] [--blend file] [--weights auto|proxy|distance] [--tex 2048]")
        sys.exit(1)
    MESH_PATH, TEX_DIR, OUT_GLB = [os.path.abspath(p) for p in pos_args[:3]]
    REVIEW = os.path.abspath(OPT["review"]) if OPT["review"] else None
    WORK = os.path.abspath(OPT["work"]) if OPT["work"] else tempfile.mkdtemp(prefix="ripper_")
    TEX_SIZE = int(OPT["tex"])
    for d in (WORK, REVIEW, os.path.dirname(OUT_GLB)):
        if d:
            os.makedirs(d, exist_ok=True)


# ------------------------------------------------------------------------------------------------ skeleton
# Joint positions measured on the prepared mesh (see the review renders).  The model is asymmetric (it was
# generated in mid-stride), so every leg has its own coordinates.
J = {
    "root": (0.0, 0.40, 0.0), "root_end": (0.0, 0.40, 0.20),
    "pelvis": (0.02, 0.44, 0.72), "spine1": (0.02, 0.26, 0.79), "spine2": (0.02, 0.09, 0.82),
    "chest": (0.02, -0.08, 0.84), "neck": (0.02, -0.28, 0.86), "head": (0.03, -0.42, 0.85), "head_end": (0.045, -0.61, 0.80),
    "fl_shoulder": (0.20, -0.30, 0.78), "fl_elbow": (0.283, -0.322, 0.48), "fl_wrist": (0.280, -0.400, 0.15), "fl_toe": (0.268, -0.500, 0.02),
    "fr_shoulder": (-0.15, -0.24, 0.77), "fr_elbow": (-0.250, -0.198, 0.44), "fr_wrist": (-0.300, -0.292, 0.15), "fr_toe": (-0.322, -0.395, 0.02),
    "hl_hip": (0.16, 0.42, 0.66), "hl_knee": (0.195, 0.40, 0.41), "hl_hock": (0.190, 0.575, 0.26), "hl_toe": (0.255, 0.49, 0.02),
    "hr_hip": (-0.10, 0.375, 0.64), "hr_knee": (-0.095, 0.31, 0.385), "hr_hock": (-0.125, 0.435, 0.225), "hr_toe": (-0.170, 0.31, 0.02),
    # the tail is really an arm-like growth on the left rump; the extras are the dangling limbs
    "t_a": (0.105, 0.50, 0.665), "t_b": (0.178, 0.585, 0.625), "t_c": (0.197, 0.60, 0.40),
    "e1_a": (0.20, -0.125, 0.82), "e1_b": (0.300, -0.078, 0.68), "e1_c": (0.368, -0.136, 0.375),
    "e2_a": (0.335, -0.315, 0.37), "e2_b": (0.357, -0.302, 0.235),
    "e3_a": (0.19, 0.265, 0.60), "e3_b": (0.212, 0.245, 0.345),
    "e4_a": (0.19, 0.30, 0.83), "e4_b": (0.295, 0.36, 0.715), "e4_c": (0.348, 0.338, 0.50),
    "e5_a": (-0.165, 0.112, 0.63), "e5_b": (-0.187, 0.146, 0.46), "e5_c": (-0.176, 0.136, 0.29),
}
# (name, parent, head joint, tail joint)
BONES = [
    ("root", None, "root", "root_end"),
    ("pelvis", "root", "pelvis", "spine1"),
    ("spine1", "pelvis", "spine1", "spine2"),
    ("spine2", "spine1", "spine2", "chest"),
    ("chest", "spine2", "chest", "neck"),
    ("neck", "chest", "neck", "head"),
    ("head", "neck", "head", "head_end"),
    ("front_upper.L", "chest", "fl_shoulder", "fl_elbow"),
    ("front_lower.L", "front_upper.L", "fl_elbow", "fl_wrist"),
    ("front_paw.L", "front_lower.L", "fl_wrist", "fl_toe"),
    ("front_upper.R", "chest", "fr_shoulder", "fr_elbow"),
    ("front_lower.R", "front_upper.R", "fr_elbow", "fr_wrist"),
    ("front_paw.R", "front_lower.R", "fr_wrist", "fr_toe"),
    ("hind_upper.L", "pelvis", "hl_hip", "hl_knee"),
    ("hind_lower.L", "hind_upper.L", "hl_knee", "hl_hock"),
    ("hind_paw.L", "hind_lower.L", "hl_hock", "hl_toe"),
    ("hind_upper.R", "pelvis", "hr_hip", "hr_knee"),
    ("hind_lower.R", "hind_upper.R", "hr_knee", "hr_hock"),
    ("hind_paw.R", "hind_lower.R", "hr_hock", "hr_toe"),
    ("tail1", "pelvis", "t_a", "t_b"),
    ("tail2", "tail1", "t_b", "t_c"),
    ("extra1", "chest", "e1_a", "e1_b"),            # big arm hanging from the left shoulder
    ("extra1b", "extra1", "e1_b", "e1_c"),
    ("extra2", "front_lower.L", "e2_a", "e2_b"),    # withered hand on the outside of the left front leg
    ("extra3", "spine1", "e3_a", "e3_b"),           # flap-like limb on the left flank
    ("extra4", "pelvis", "e4_a", "e4_b"),           # arm growing out of the left hip
    ("extra4b", "extra4", "e4_b", "e4_c"),
    ("extra5", "spine1", "e5_a", "e5_b"),           # limb hanging from the right flank
    ("extra5b", "extra5", "e5_b", "e5_c"),
]
BONE_NAMES = [b[0] for b in BONES]
DEFORM = [n for n in BONE_NAMES if n != "root"]
PARENT = {b[0]: b[1] for b in BONES}
HEAD = {b[0]: Vector(J[b[2]]) for b in BONES}
TAIL = {b[0]: Vector(J[b[3]]) for b in BONES}


# ------------------------------------------------------------------------------------------------ mesh
def import_mesh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.lower().endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    obj = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o)
    me = obj.data
    # weld (a GLB arrives split along UV seams) and drop the generator's custom normals: after decimation they
    # leave hard crease lines, plain smooth normals shade and deform better
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(me)
    bm.free()
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for name in ("sharp_edge", "sharp_face"):
        if me.attributes.get(name):
            me.attributes.remove(me.attributes[name])
    for p in me.polygons:
        p.use_smooth = True
    me.materials.clear()
    obj.name = "RipperMesh"
    me.name = "RipperMesh"
    me.update()
    co = np.zeros(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    log("mesh", len(me.vertices), "verts", len(me.polygons), "faces, bounds", np.round(co.min(axis=0), 3), np.round(co.max(axis=0), 3))
    return obj


def mesh_components(me):
    """Connected components as lists of vertex indices, largest first."""
    n = len(me.vertices)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    groups = {}
    for v in range(n):
        groups.setdefault(find(v), []).append(v)
    return sorted(groups.values(), key=len, reverse=True)


# ------------------------------------------------------------------------------------------------ textures
def _pixels(path, non_color=False):
    img = bpy.data.images.load(path, check_existing=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    return arr.reshape(h, w, 4)


def _save_image(arr, path, fmt, non_color=False, quality=90):
    h, w = arr.shape[:2]
    img = bpy.data.images.new("tmp_" + os.path.basename(path), w, h, alpha=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    full = np.ones((h, w, 4), dtype=np.float32)
    full[..., :3] = arr[..., :3]
    img.pixels.foreach_set(full.reshape(-1))
    img.filepath_raw = path
    img.file_format = fmt
    img.save(quality=quality)
    bpy.data.images.remove(img)


def _shrink_and_pad(rgb, mask, size, pad):
    """Box-filter to size x size counting only texels inside the UV islands, then bleed the island colours
    `pad` texels outwards so mip-mapping and the slightly moved UV borders never pick up the background."""
    h, w = rgb.shape[:2]
    f = w // size
    m = mask.reshape(size, f, size, f).astype(np.float32)
    c = rgb.reshape(size, f, size, f, 3)
    cnt = m.sum(axis=(1, 3))
    out = (c * m[..., None]).sum(axis=(1, 3)) / np.maximum(cnt, 1e-6)[..., None]
    filled = cnt > 0
    plain = c.mean(axis=(1, 3))
    out[~filled] = plain[~filled]
    for _ in range(pad):
        acc = np.zeros_like(out)
        num = np.zeros(filled.shape, dtype=np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            sf = np.roll(np.roll(filled, dy, axis=0), dx, axis=1)
            sc = np.roll(np.roll(out, dy, axis=0), dx, axis=1)
            acc += sc * sf[..., None]
            num += sf
        grow = (~filled) & (num > 0)
        out[grow] = acc[grow] / num[grow][:, None]
        filled = filled | grow
    return out


def build_textures(tex_dir, work, size):
    """Returns paths of base colour (JPEG), normal (PNG) and occlusion-roughness-metallic (PNG, glTF packing)."""
    out = {"diffuse": os.path.join(work, "ripper_diffuse.jpg"), "normal": os.path.join(work, "ripper_normal.png"), "orm": os.path.join(work, "ripper_orm.png")}
    stamp = os.path.join(work, "textures_%d.done" % size)
    if os.path.exists(stamp) and all(os.path.exists(p) for p in out.values()):
        log("textures: reusing the resized set in", work)
        return out
    rough = _pixels(os.path.join(tex_dir, "texture_roughness.png"), True)
    metal = _pixels(os.path.join(tex_dir, "texture_metallic.png"), True)
    diff = _pixels(os.path.join(tex_dir, "texture_diffuse.png"))
    # texels covered by UV islands: the generator leaves everything else pure black in all maps
    mask = (diff[..., :3].max(axis=2) > 0) | (rough[..., 0] > 0)
    log("texture coverage %.1f %%" % (100.0 * mask.mean()))
    pad = max(4, size // 256)
    _save_image(_shrink_and_pad(diff[..., :3], mask, size, pad), out["diffuse"], "JPEG", quality=90)
    del diff
    orm = np.ones(rough.shape[:2] + (3,), dtype=np.float32)
    orm[..., 1] = rough[..., 0]
    orm[..., 2] = metal[..., 0]
    del rough, metal
    _save_image(_shrink_and_pad(orm, mask, size, pad), out["orm"], "PNG", non_color=True)
    del orm
    nrm = _pixels(os.path.join(tex_dir, "texture_normal.png"), True)
    _save_image(_shrink_and_pad(nrm[..., :3], mask, size, pad), out["normal"], "PNG", non_color=True)
    del nrm
    for k, p in out.items():
        log("texture", k, os.path.basename(p), "%.2f MB" % (os.path.getsize(p) / 1e6))
    open(stamp, "w").close()
    return out


def build_material(me, tex):
    mat = bpy.data.materials.new("ripper")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]

    def image_node(key, non_color, x, y):
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(tex[key])
        node.image.name = key
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        node.location = (x, y)
        return node
    base = image_node("diffuse", False, -700, 400)
    nt.links.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    orm = image_node("orm", True, -900, 50)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-550, 50)
    nt.links.new(orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    nrm = image_node("normal", True, -900, -300)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.location = (-550, -300)
    nt.links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    nt.nodes.active = base
    # the mesh has open flaps and torn sheets of flesh: export as double sided so they never vanish
    mat.use_backface_culling = False
    me.materials.append(mat)
    return mat


# ------------------------------------------------------------------------------------------------ armature
def build_armature():
    data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, hj, tj in BONES:
        eb = data.edit_bones.new(name)
        eb.head = J[hj]
        eb.tail = J[tj]
        if parent:
            eb.parent = data.edit_bones[parent]
            eb.use_connect = (eb.head - eb.parent.tail).length < 1e-6
        # roll: local X as close as possible to the animal's left (+X), so "rotate about bone X" pitches every bone
        y = (eb.tail - eb.head).normalized()
        z = Vector((1.0, 0.0, 0.0)).cross(y)
        eb.align_roll(z.normalized() if z.length > 0.3 else Vector((0.0, 0.0, 1.0)))
    bpy.ops.object.mode_set(mode="OBJECT")
    data.bones["root"].use_deform = False
    return arm


# ------------------------------------------------------------------------------------------------ weights
def _read_groups(obj, names):
    me = obj.data
    idx = {vg.index: names.index(vg.name) for vg in obj.vertex_groups if vg.name in names}
    W = np.zeros((len(me.vertices), len(names)), dtype=np.float64)
    for v in me.vertices:
        for g in v.groups:
            if g.group in idx:
                W[v.index, idx[g.group]] = g.weight
    return W


def _heat(obj_for_heat, arm):
    """Blender's automatic (bone heat) weights on obj_for_heat. Returns W or None when the solver failed."""
    bpy.ops.object.select_all(action="DESELECT")
    obj_for_heat.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    W = _read_groups(obj_for_heat, DEFORM)
    empty = int((W.sum(axis=1) < 1e-6).sum())
    log("bone heat on", obj_for_heat.name, ":", len(W), "verts,", empty, "without weights")
    if empty > 0.01 * len(W):
        return None
    return W


def _copy_object(obj, name, keep_verts=None):
    me = obj.data.copy()
    cp = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(cp)
    if keep_verts is not None:
        keep = set(keep_verts)
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
        bm.to_mesh(me)
        bm.free()
    return cp


def weights_heat(obj, arm, main):
    """Bone heat on the main component only (floating crumbs make the solver fail for their vertices)."""
    tmp = _copy_object(obj, "heat_tmp", main)
    W_main = _heat(tmp, arm)
    bpy.data.objects.remove(tmp)
    if W_main is None:
        return None
    W = np.zeros((len(obj.data.vertices), len(DEFORM)))
    W[np.array(sorted(main))] = W_main          # bmesh.delete keeps the order of the remaining vertices
    return W


def weights_proxy(obj, arm, main):
    """Fallback 1: bone heat on a watertight voxel-remeshed proxy, transferred back by nearest surface point."""
    proxy = _copy_object(obj, "heat_proxy", main)
    bpy.ops.object.select_all(action="DESELECT")
    proxy.select_set(True)
    bpy.context.view_layer.objects.active = proxy
    mod = proxy.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = 0.012
    bpy.ops.object.modifier_apply(modifier=mod.name)
    Wp = _heat(proxy, arm)
    if Wp is None:
        bpy.data.objects.remove(proxy)
        return None
    pm = proxy.data
    pm.calc_loop_triangles()
    tris = [tuple(t.vertices) for t in pm.loop_triangles]
    pco = [v.co.copy() for v in pm.vertices]
    bvh = BVHTree.FromPolygons(pco, tris)
    W = np.zeros((len(obj.data.vertices), len(DEFORM)))
    for vi in main:
        p = obj.data.vertices[vi].co
        loc, nrm, ti, dist = bvh.find_nearest(p)
        a, b, c = tris[ti]
        # barycentric interpolation inside the proxy triangle
        v0, v1, v2 = pco[a], pco[b], pco[c]
        n = (v1 - v0).cross(v2 - v0)
        den = n.dot(n)
        if den < 1e-18:
            wa, wb, wc = 1.0, 0.0, 0.0
        else:
            wa = (v1 - loc).cross(v2 - loc).dot(n) / den
            wb = (v2 - loc).cross(v0 - loc).dot(n) / den
            wc = 1.0 - wa - wb
        W[vi] = wa * Wp[a] + wb * Wp[b] + wc * Wp[c]
    bpy.data.objects.remove(proxy)
    return np.clip(W, 0.0, None)


def weights_distance(obj, main):
    """Fallback 2: inverse-distance weights to the bone segments, sharpened, then smoothed over the surface."""
    me = obj.data
    co = np.array([v.co[:] for v in me.vertices])
    W = np.zeros((len(co), len(DEFORM)))
    for j, name in enumerate(DEFORM):
        a = np.array(HEAD[name]); b = np.array(TAIL[name])
        ab = b - a
        t = np.clip(((co - a) @ ab) / (ab @ ab), 0.0, 1.0)
        d = np.linalg.norm(co - (a + t[:, None] * ab), axis=1)
        W[:, j] = 1.0 / (d + 0.01) ** 4
    W /= W.sum(axis=1, keepdims=True)
    return smooth_weights(me, W, 6, 0.5)


def vertex_neighbours(me):
    n = len(me.vertices)
    e = np.zeros(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    return n, e


def smooth_weights(me, W, iterations, factor, mask=None):
    """Plain Laplacian smoothing of the weight functions along mesh edges."""
    n, e = vertex_neighbours(me)
    deg = np.zeros(n)
    np.add.at(deg, e[:, 0], 1.0)
    np.add.at(deg, e[:, 1], 1.0)
    deg = np.maximum(deg, 1.0)
    for _ in range(iterations):
        acc = np.zeros_like(W)
        np.add.at(acc, e[:, 0], W[e[:, 1]])
        np.add.at(acc, e[:, 1], W[e[:, 0]])
        avg = acc / deg[:, None]
        f = factor if mask is None else (factor * mask)[:, None]
        W = W * (1.0 - f) + avg * f
    return W


def smoothstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def refine_weights(obj, W, comps):
    me = obj.data
    co = np.array([v.co[:] for v in me.vertices])
    col = {n: k for k, n in enumerate(DEFORM)}
    main = np.array(comps[0])
    # 1. keep the upper leg bones from dragging the belly: fade their influence towards the body's mid-line
    for name, sign in (("front_upper.L", 1.0), ("front_upper.R", -1.0), ("hind_upper.L", 1.0), ("hind_upper.R", -1.0)):
        side = (co[:, 0] - 0.02) * sign                      # distance from the mid-plane towards the leg's side
        W[:, col[name]] *= smoothstep(side, 0.0, 0.13)
    W[main] /= np.maximum(W[main].sum(axis=1, keepdims=True), 1e-9)
    # 2. a light smoothing pass removes the solver's speckles without blurring the limbs apart
    W = smooth_weights(me, W, 2, 0.5)
    # 3. floating crumbs follow the nearest bit of the main surface rigidly
    kd = KDTree(len(main))
    for vi in main:
        kd.insert(co[vi], int(vi))
    kd.balance()
    for comp in comps[1:]:
        centre = co[comp].mean(axis=0)
        _, near, _ = kd.find(centre)
        W[comp] = W[near]
    # 4. at most four influences per vertex, normalised
    order = np.argsort(-W, axis=1)
    keep = np.zeros_like(W, dtype=bool)
    np.put_along_axis(keep, order[:, :4], True, axis=1)
    W = np.where(keep & (W > 0.004), W, 0.0)
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
    return W


def assign_weights(obj, arm, W):
    obj.vertex_groups.clear()
    for j, name in enumerate(DEFORM):
        vg = obj.vertex_groups.new(name=name)
        col = W[:, j]
        for vi in np.nonzero(col > 0.0)[0]:
            vg.add([int(vi)], float(col[vi]), "REPLACE")
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    obj.matrix_parent_inverse = Matrix.Identity(4)


def skin(obj, arm):
    comps = mesh_components(obj.data)
    log("components:", [len(c) for c in comps])
    main = comps[0]
    W = None
    mode = OPT["weights"]
    if mode == "auto":
        W = weights_heat(obj, arm, main)
        method = "bone heat"
    if W is None and mode in ("auto", "proxy"):
        W = weights_proxy(obj, arm, main)
        method = "bone heat on voxel proxy"
    if W is None:
        W = weights_distance(obj, main)
        method = "distance based"
    log("weights:", method)
    W = refine_weights(obj, W, comps)
    assign_weights(obj, arm, W)
    log("influences per vertex: max %d, mean %.2f; unweighted verts %d" % ((W > 0).sum(axis=1).max(), (W > 0).sum(axis=1).mean(), int((W.sum(axis=1) < 0.999).sum())))
    return W, method


# ------------------------------------------------------------------------------------------------ pose maths
class Rig:
    """Rest data of the armature plus forward kinematics done here in Python, so that poses, inverse kinematics,
    secondary motion and ground checks can all be computed without Blender's dependency graph."""

    def __init__(self, arm):
        self.names = list(BONE_NAMES)
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        self.rest_rot = {n: m.to_3x3() for n, m in self.rest.items()}
        self.head = {n: self.rest[n].to_translation() for n in self.names}

    def fk(self, local):
        """local: {bone: (offset Vector, rotation Quaternion)} given in armature axes, relative to the posed parent.
        Returns {bone: 4x4 delta matrix D} with posed_point = D @ rest_point."""
        D = {}
        for name in self.names:
            par = PARENT[name]
            Dp = D[par] if par else Matrix.Identity(4)
            if name in local:
                off, rot = local[name]
                h = self.head[name]
                D[name] = Dp @ (Matrix.Translation(h + off) @ rot.to_matrix().to_4x4() @ Matrix.Translation(-h))
            else:
                D[name] = Dp.copy()
        return D

    def basis(self, name, off, rot):
        """Pose-bone location / rotation_quaternion for a local delta given in armature axes."""
        r = self.rest_rot[name]
        ri = r.inverted()
        q = (ri @ rot.to_matrix() @ r).to_quaternion()
        return ri @ off, q


def quat(rx=0.0, ry=0.0, rz=0.0):
    """Rotation from degrees about the armature axes: X = pitch (+ nose down / leg back), Y = roll, Z = yaw (+ left)."""
    q = Quaternion((0, 0, 1), math.radians(rz)) @ Quaternion((1, 0, 0), math.radians(rx)) @ Quaternion((0, 1, 0), math.radians(ry))
    return q


def skin_points(co, W, D):
    """Linear blend skinning in numpy: co (n,3), W (n, len(DEFORM)), D {bone: Matrix}."""
    M = np.array([np.array(D[n]) for n in DEFORM])          # (b,4,4)
    h = np.concatenate([co, np.ones((len(co), 1))], axis=1)
    per_bone = np.einsum("bij,nj->nbi", M[:, :3, :], h)     # (n,b,3)
    return np.einsum("nb,nbi->ni", W, per_bone)


# ------------------------------------------------------------------------------------------------ animation maths
def clamp(x, a, b):
    return max(a, min(b, x))


def ease(t):
    t = clamp(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ramp(t, a, b):
    """0 before a, 1 after b, smooth in between."""
    return ease((t - a) / (b - a))


def spline(t, pts):
    """Smooth curve through (time, value) keys (floats or Vectors): Catmull-Rom, flat at both ends."""
    n = len(pts)
    if t <= pts[0][0]:
        return pts[0][1]
    if t >= pts[-1][0]:
        return pts[-1][1]
    i = 0
    while pts[i + 1][0] < t:
        i += 1
    t0, v0 = pts[i]
    t1, v1 = pts[i + 1]

    def slope(k):
        if k == 0 or k == n - 1:
            return (v1 - v0) * 0.0
        return (pts[k + 1][1] - pts[k - 1][1]) * (1.0 / (pts[k + 1][0] - pts[k - 1][0]))
    h = t1 - t0
    s = (t - t0) / h
    s2, s3 = s * s, s * s * s
    return v0 * (2 * s3 - 3 * s2 + 1) + slope(i) * ((s3 - 2 * s2 + s) * h) + v1 * (-2 * s3 + 3 * s2) + slope(i + 1) * ((s3 - s2) * h)


def hermite(s, y0, m0, y1, m1):
    s2, s3 = s * s, s * s * s
    return y0 * (2 * s3 - 3 * s2 + 1) + m0 * (s3 - 2 * s2 + s) + y1 * (-2 * s3 + 3 * s2) + m1 * (s3 - s2)


def twitch(u, at, dur=0.07, waves=1.5):
    """A short decaying wiggle starting at phase `at` of a loop (0 elsewhere)."""
    d = (u - at) % 1.0
    if d >= dur:
        return 0.0
    x = d / dur
    return math.sin(2.0 * math.pi * waves * x) * (1.0 - x) ** 2


class Leg:
    """Rest geometry of one leg for the analytic two-bone solver (upper + lower bone, the paw is oriented separately)."""

    def __init__(self, rig, key, upper, lower, paw, parent, front):
        self.key, self.bones, self.parent, self.front = key, (upper, lower, paw), parent, front
        self.h, self.k, self.a = rig.head[upper], rig.head[lower], rig.head[paw]
        toe = TAIL[paw]
        self.c = Vector((toe.x, toe.y, 0.0))                 # contact pivot: the toe tip on the ground
        self.L1, self.L2 = (self.k - self.h).length, (self.a - self.k).length
        v0 = (self.a - self.h).normalized()
        kk = self.k - self.h
        p0 = (kk - v0 * kk.dot(v0)).normalized()             # direction the knee / elbow points to
        n0 = p0.cross(v0)
        x0, y0 = kk.normalized(), (self.a - self.k).normalized()
        self.F0 = Matrix((x0, n0, x0.cross(n0))).transposed()
        self.G0 = Matrix((y0, n0, y0.cross(n0))).transposed()
        # pole: the rest direction, biased so a leg stretched forward keeps the elbow low / the knee high
        self.pole = (p0 + v0 * (0.6 if front else -0.6)).normalized()
        self.mask = None

    def solve(self, Dpar, contact, paw_q):
        """Returns local rotations (upper, lower, paw) that put the toe pivot on `contact` with the paw turned
        by `paw_q` (world, relative to rest), plus how far the target was out of reach."""
        A = contact + paw_q @ (self.a - self.c)              # where the ankle / wrist has to be
        v = Dpar.inverted() @ A - self.h
        dist = max(v.length, 1e-6)
        vh = v / dist
        d = clamp(dist, abs(self.L1 - self.L2) + 0.03, (self.L1 + self.L2) * 0.9995)
        ca = clamp((self.L1 ** 2 + d * d - self.L2 ** 2) / (2.0 * self.L1 * d), -1.0, 1.0)
        sa = math.sqrt(1.0 - ca * ca)
        pp = self.pole - vh * self.pole.dot(vh)
        if pp.length < 1e-4:
            pp = Vector((0.0, 0.0, 1.0)) - vh * vh.z
        pp.normalize()
        K = self.h + (vh * ca + pp * sa) * self.L1
        Ae = self.h + vh * d
        n1 = pp.cross(vh)
        x1, y1 = (K - self.h).normalized(), (Ae - K).normalized()
        Ru = Matrix((x1, n1, x1.cross(n1))).transposed() @ self.F0.transposed()
        Rtl = Matrix((y1, n1, y1.cross(n1))).transposed() @ self.G0.transposed()
        Rl = Ru.transposed() @ Rtl
        Rp = (Dpar.to_3x3().normalized() @ Rtl).transposed() @ paw_q.to_matrix()
        return Ru.to_quaternion(), Rl.to_quaternion(), Rp.to_quaternion(), dist - d


PIVOT = Vector((0.02, 0.09, 0.74))          # centre of the trunk: reference point for all whole-body moves
SPINE = ("pelvis", "spine1", "spine2", "chest")
# secondary-motion chains: (bones...), spring stiffness 1/s^2, damping 1/s, collision radius
CHAINS = [
    (("tail1", "tail2"), 520.0, 15.0, 0.035),
    (("extra1", "extra1b"), 460.0, 14.0, 0.035),
    (("extra2",), 600.0, 16.0, 0.03),
    (("extra3",), 440.0, 15.0, 0.04),
    (("extra4", "extra4b"), 500.0, 15.0, 0.035),
    (("extra5", "extra5b"), 450.0, 14.0, 0.035),
]
CHAIN_SWING = math.radians(50.0)            # how far a live limb may swing away from where its parent carries it
CHAIN_BONES = [b for c in CHAINS for b in c[0]]
# rough collision spheres of the body for limp limbs: bone, centre in rest space, radius
BODY_SPHERES = [
    ("pelvis", (0.03, 0.40, 0.68), 0.20), ("spine1", (0.03, 0.22, 0.75), 0.21), ("spine2", (0.03, 0.03, 0.78), 0.22),
    ("chest", (0.03, -0.17, 0.80), 0.24), ("neck", (0.03, -0.36, 0.84), 0.14), ("head", (0.04, -0.52, 0.83), 0.10),
]


class Animator:
    """Turns a pose description ("spec") into bone rotations.

    spec keys (all optional):
      mid          offset of the trunk centre from rest (x left, y back, z up), metres
      pitch/roll/yaw   orientation of the whole body in degrees (pitch + = nose down, roll + = left side down, yaw + = left)
      flex/bend/twist  per-joint increments along pelvis-spine1-spine2-chest (flex + = rounded back)
      rot          {bone: (rx, ry, rz)} extra local rotations (spine, neck, head; for chain bones: the target they chase)
      feet         {leg: {...}} leg keys FL FR HL HR:
                     pos (world offset of the toe pivot from its rest spot), pitch/roll/yaw (paw, world),
                     rel + rpitch/rroll/ryaw (the same but carried by the leg's parent bone), w (0 world .. 1 carried)
      ground       None | ("keep", 0, hop) body may not sink into the floor | ("rest", w, hop) body is put on the floor
      limp         0..1 chains go rag-doll (gravity, floor and body collisions)
    """

    def __init__(self, rig, co, W):
        self.rig, self.co, self.W = rig, co, W
        self.legs = [
            Leg(rig, "FL", "front_upper.L", "front_lower.L", "front_paw.L", "chest", True),
            Leg(rig, "FR", "front_upper.R", "front_lower.R", "front_paw.R", "chest", True),
            Leg(rig, "HL", "hind_upper.L", "hind_lower.L", "hind_paw.L", "pelvis", False),
            Leg(rig, "HR", "hind_upper.R", "hind_lower.R", "hind_paw.R", "pelvis", False),
        ]
        col = {n: k for k, n in enumerate(DEFORM)}
        self.col = col
        z = co[:, 2]
        chain_w = W[:, [col[b] for b in CHAIN_BONES]].sum(axis=1)
        head_w = W[:, col["head"]] + W[:, col["neck"]]
        leg_w = np.zeros(len(co))
        for leg in self.legs:
            w3 = W[:, [col[b] for b in leg.bones]].sum(axis=1)
            leg.mask = (w3 > 0.5) & (z < 0.55)
            leg_w += W[:, col[leg.bones[1]]] + W[:, col[leg.bones[2]]]
        self.head_mask = head_w > 0.5
        self.trunk_mask = (z > 0.55) & (chain_w < 0.5) & (head_w <= 0.5) & (leg_w < 0.5)
        # the real toe tips: the foremost floor-level vertices of each paw
        for leg in self.legs:
            low = (W[:, col[leg.bones[2]]] > 0.5) & (z < 0.035)
            tip = float(co[low, 1].min())
            near = low & (co[:, 1] < tip + 0.03)
            leg.c = Vector((float(co[near, 0].mean()), tip + 0.012, 0.0))
        log("toe pivots:", ", ".join("%s (%.3f, %.3f)" % (l.key, l.c.x, l.c.y) for l in self.legs))

    # ---- body
    def body(self, s, adj):
        d, b, tw = s.get("flex", 0.0), s.get("bend", 0.0), s.get("twist", 0.0)
        qb = quat(s.get("pitch", 0.0), s.get("roll", 0.0), s.get("yaw", 0.0))
        rot = s.get("rot", {})

        def r(name):
            return quat(*rot[name]) if name in rot else Quaternion()
        local = {"pelvis": (Vector(), qb @ quat(-1.5 * d, -1.5 * tw, -1.5 * b) @ r("pelvis"))}
        for n in ("spine1", "spine2", "chest"):
            local[n] = (Vector(), quat(d, tw, b) @ r(n))
        local["neck"] = (Vector(), adj.get("neck_fix", Quaternion()) @ r("neck"))
        local["head"] = (Vector(), r("head"))
        for n in CHAIN_BONES:
            if n in rot:
                local[n] = (Vector(), r(n))
        D = self.rig.fk(local)
        joint = D["spine2"] @ self.rig.head["spine2"]
        now = joint + qb @ (PIVOT - self.rig.head["spine2"])
        want = PIVOT + Vector(s.get("mid", (0.0, 0.0, 0.0))) + Vector((0.0, 0.0, adj.get("mid_z", 0.0)))
        local["pelvis"] = (want - now, local["pelvis"][1])
        return local

    # ---- legs
    def solve_legs(self, s, local, D, adj):
        feet = s.get("feet", {})
        over = 0.0
        for leg in self.legs:
            f = feet.get(leg.key, {})
            Dpar = D[leg.parent]
            c = leg.c + Vector(f.get("pos", (0.0, 0.0, 0.0)))
            q = quat(f.get("pitch", 0.0), f.get("roll", 0.0), f.get("yaw", 0.0))
            w = f.get("w", 0.0)
            if w > 0.0:
                cr = Dpar @ (leg.c + Vector(f.get("rel", (0.0, 0.0, 0.0))))
                qr = Dpar.to_quaternion() @ quat(f.get("rpitch", 0.0), f.get("rroll", 0.0), f.get("ryaw", 0.0))
                c = c.lerp(cr, w)
                q = q.slerp(qr, w)
            c.z += adj.get("lift", {}).get(leg.key, 0.0)
            qu, ql, qp, o = leg.solve(Dpar, c, q)
            over = max(over, o)
            for bone, qq in zip(leg.bones, (qu, ql, qp)):
                local[bone] = (Vector(), qq)
        return over

    def evaluate(self, s):
        """spec -> (local rotations of all bones except what the chains will add, deltas D, info)."""
        adj = {"mid_z": 0.0, "lift": {}, "neck_fix": Quaternion()}
        ground = s.get("ground")
        info = {}
        for it in range(5 if ground else 1):
            local = self.body(s, adj)
            D = self.rig.fk(local)
            info["over"] = self.solve_legs(s, local, D, adj)
            D = self.rig.fk(local)
            if not ground:
                break
            P = skin_points(self.co, self.W, D)
            mode, wgt, hop = ground
            changed = False
            zt = float(P[self.trunk_mask, 2].min())
            if it == 0:
                # the trunk: "keep" only stops it from sinking into the floor, "rest" blends the authored height
                # towards lying on the floor (lowest point at height `hop`)
                if mode == "rest":
                    dz = (hop - zt) * wgt
                    if zt + dz < 0.0:
                        dz = -zt
                else:
                    dz = max(0.0, -zt)
                adj["mid_z"] += dz
                changed = True          # evaluate again so head and legs are tested at the final height
            else:
                # the head: turn the neck upwards until the head is clear of the floor
                zh = float(P[self.head_mask, 2].min())
                if zh < -0.002:
                    a = D["neck"] @ self.rig.head["neck"]
                    b = D["head"] @ TAIL["head"]
                    axis = (b - a).cross(Vector((0.0, 0.0, 1.0)))
                    if axis.length > 1e-4:
                        lever = max((b - a).length, 0.1)
                        qfix = Quaternion(axis.normalized(), min(0.5, -zh / lever))
                        Rc = D["chest"].to_quaternion()
                        adj["neck_fix"] = (Rc.inverted() @ qfix @ Rc) @ adj["neck_fix"]
                        changed = True
                for leg in self.legs:
                    zl = float(P[leg.mask, 2].min())
                    if zl < -0.002:
                        adj["lift"][leg.key] = adj["lift"].get(leg.key, 0.0) - zl
                        changed = True
            if not changed and it > 0:
                break
        info["mid_z"] = adj["mid_z"]
        return local, D, info

    # ---- secondary motion
    def simulate_chains(self, frames, loop, substeps=6):
        """frames: list of dicts with local, D, limp for frames 0..N (N = the frame after the last interval).
        Adds the rotations of the chain bones to every frame's local dict."""
        n = len(frames) - 1
        dt = 1.0 / FPS
        h = dt / substeps
        gravity = Vector((0.0, 0.0, -9.81))
        for bones, stiff, damp, radius in CHAINS:
            lens = [(TAIL[b] - HEAD[b]).length for b in bones]
            par0 = PARENT[bones[0]]
            roots = [f["D"][par0] @ HEAD[bones[0]] for f in frames]
            targets = [[f["D"][b] @ TAIL[b] for b in bones] for f in frames]
            spheres = [[(f["D"][sb] @ Vector(sc), sr) for sb, sc, sr in BODY_SPHERES] for f in frames]
            pos = [t.copy() for t in targets[0]]
            vel = [Vector() for _ in bones]
            rec = [[p.copy() for p in pos]]
            cycles = 4 if loop else 1
            for cyc in range(cycles):
                if cyc == cycles - 1:
                    rec = [[p.copy() for p in pos]]
                for f in range(n):
                    limp0, limp1 = frames[f].get("limp", 0.0), frames[f + 1].get("limp", 0.0)
                    for j in range(1, substeps + 1):
                        a = j / substeps
                        limp = limp0 + (limp1 - limp0) * a
                        root = roots[f].lerp(roots[f + 1], a)
                        prev = root
                        for i in range(len(bones)):
                            tgt = targets[f][i].lerp(targets[f + 1][i], a)
                            tvel = (targets[f + 1][i] - targets[f][i]) / dt
                            k = stiff * (1.0 - limp) + 20.0 * limp
                            c = damp * (1.0 - limp) + 3.0 * limp
                            acc = (tgt - pos[i]) * k - (vel[i] - tvel * (1.0 - limp)) * c + gravity * limp
                            v = vel[i] + acc * h
                            x = pos[i] + v * h
                            for _ in range(2):
                                dvec = x - prev
                                x = prev + dvec * (lens[i] / max(dvec.length, 1e-6))
                                if x.z < radius:
                                    x.z = radius
                                if limp > 0.0:
                                    for k_s in range(len(BODY_SPHERES)):
                                        sc = spheres[f][k_s][0].lerp(spheres[f + 1][k_s][0], a)
                                        sr = spheres[f][k_s][1] + radius
                                        dv = x - sc
                                        dl = dv.length
                                        if 1e-6 < dl < sr:
                                            x = x + dv * ((sr - dl) / dl * limp)
                            dvec = (x - prev).normalized()
                            tprev = root if i == 0 else targets[f][i - 1].lerp(targets[f + 1][i - 1], a)
                            tdir = (tgt - tprev).normalized()
                            ang = dvec.angle(tdir, 0.0)
                            lim = CHAIN_SWING + (math.pi - CHAIN_SWING) * limp
                            if ang > lim:
                                dvec = Quaternion(dvec.cross(tdir).normalized(), ang - lim) @ dvec
                            x = prev + dvec * lens[i]
                            vel[i] = (x - pos[i]) / h
                            pos[i] = x
                            prev = x
                    if cyc == cycles - 1:
                        rec.append([p.copy() for p in pos])
            if loop:
                # close the loop exactly: spread the remaining mismatch over the cycle
                for i in range(len(bones)):
                    err = rec[0][i] - rec[n][i]
                    for f in range(n + 1):
                        rec[f][i] = rec[f][i] + err * (f / n)
            for f, fr in enumerate(frames):
                Dprev = fr["D"][par0].copy()
                prev = roots[f]
                for i, b in enumerate(bones):
                    Rq = Dprev.to_quaternion()
                    rdir = Rq @ (TAIL[b] - HEAD[b]).normalized()
                    ddir = (rec[f][i] - prev).normalized()
                    qw = rdir.rotation_difference(ddir)
                    ql = Rq.inverted() @ qw @ Rq
                    fr["local"][b] = (Vector(), ql)
                    hb = self.rig.head[b]
                    Dprev = Dprev @ (Matrix.Translation(hb) @ ql.to_matrix().to_4x4() @ Matrix.Translation(-hb))
                    prev = Dprev @ TAIL[b]

    # ---- a whole clip
    def build(self, name, fn, nframes, loop):
        frames = []
        over = 0.0
        for f in range(nframes + 1):
            if loop and f == nframes:
                src = frames[0]
                frames.append({"local": dict(src["local"]), "D": src["D"], "limp": src["limp"], "info": src["info"]})
                break
            s = fn(f / nframes if loop else f / FPS)
            local, D, info = self.evaluate(s)
            over = max(over, info["over"])
            frames.append({"local": local, "D": D, "limp": s.get("limp", 0.0), "info": info})
        self.simulate_chains(frames, loop)
        zmin, zmin_at = 1e9, 0
        for f, fr in enumerate(frames):
            fr["D"] = self.rig.fk(fr["local"])
            P = skin_points(self.co, self.W, fr["D"])
            fr["zmin"] = float(P[:, 2].min())
            if fr["zmin"] < zmin:
                zmin, zmin_at = fr["zmin"], f
            if OPT["debug"]:
                legs = " ".join("%s %.3f" % (l.key, float(P[l.mask, 2].min())) for l in self.legs)
                print("   %-11s f%02d zmin %.3f trunk %.3f head %.3f legs %s over %.3f fit %.3f" % (
                    name, f, fr["zmin"], float(P[self.trunk_mask, 2].min()), float(P[self.head_mask, 2].min()), legs, fr["info"]["over"], fr["info"]["mid_z"]))
        log("clip %-11s %2d frames %.3f s %s | lowest vertex %.3f m at frame %d | worst leg over-reach %.3f m | end lowest %.3f" % (
            name, nframes, nframes / FPS, "loop" if loop else "once", zmin, zmin_at, over, frames[-1]["zmin"]))
        return frames


def bake_action(arm, rig, name, frames):
    """Writes one key per frame for every bone (rotation; location too for root and pelvis)."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    n = len(frames)
    times = np.arange(n, dtype=np.float64)
    for bone in BONE_NAMES:
        quats = np.zeros((n, 4))
        locs = np.zeros((n, 3))
        prev = None
        for f, fr in enumerate(frames):
            off, rot = fr["local"].get(bone, (Vector(), Quaternion()))
            loc, q = rig.basis(bone, off, rot)
            if prev is not None and q.dot(prev) < 0.0:
                q.negate()
            prev = q
            quats[f] = q[:]
            locs[f] = loc[:]
        curves = [('pose.bones["%s"].rotation_quaternion' % bone, quats, 4)]
        if bone in ("root", "pelvis"):
            curves.append(('pose.bones["%s"].location' % bone, locs, 3))
        for path, values, dim in curves:
            for i in range(dim):
                fc = act.fcurve_ensure_for_datablock(arm, path, index=i, group_name=bone)
                fc.keyframe_points.add(n)
                co = np.empty(n * 2)
                co[0::2] = times
                co[1::2] = values[:, i]
                fc.keyframe_points.foreach_set("co", co)
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
                fc.update()
    return act


def stash_actions(arm, actions):
    """Every action on its own muted NLA track: that is what the glTF exporter turns into named clips."""
    ad = arm.animation_data
    ad.action = None
    for act in actions:
        track = ad.nla_tracks.new()
        track.name = act.name
        strip = track.strips.new(act.name, 0, act)
        strip.name = act.name
        track.mute = True
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)


def show_action(arm, act, frame):
    ad = arm.animation_data
    if ad.action != act:
        ad.action = act
        if act is not None and getattr(ad, "action_slot", None) is None and len(act.slots):
            ad.action_slot = act.slots[0]
    bpy.context.scene.frame_set(frame)


# ------------------------------------------------------------------------------------------------ the clips
# Loops take the phase u = 0..1, one-shots the time t in seconds.  Feet of the gaits run on a symmetric track
# (the rest pose itself was generated in mid-stride and is not symmetric).
def V3(x=0.0, y=0.0, z=0.0):
    return Vector((x, y, z))


def gait_foot(leg, u, touchdown, duty, stride, lift, x, y, heel=30.0, fold=45.0, carry=1.0):
    """One foot of a cyclic gait, in place: it slides back along the floor during stance, then swings forward."""
    ph = (u - touchdown) % 1.0
    back = y + stride * 0.5
    fore = y - stride * 0.5
    if ph < duty:
        s = ph / duty
        py, pz = fore + stride * s, 0.0
        pitch = heel * ramp(s, 0.70, 1.0)
    else:
        s = (ph - duty) / (1.0 - duty)
        m = stride * (1.0 - duty) / duty * carry          # keeps the ground speed at lift-off and touch-down
        py = hermite(s, back, m, fore, m)
        pz = lift * math.sin(math.pi * s ** 0.8) ** 2
        pitch = spline(s, [(0.0, heel), (0.3, fold), (0.78, 4.0), (1.0, 0.0)])
    side = 1.0 if leg.c.x > 0 else -1.0
    return {"pos": Vector((side * x, py, pz)) - leg.c, "pitch": pitch}


def clip_idle(an, u):
    """Heavy breathing, low swaying head, slow weight shifts, twitching growths."""
    w = 2.0 * math.pi * u
    breath = math.sin(2.0 * w + 0.5 * math.sin(2.0 * w))
    rot = {
        "neck": (10.0 + 3.5 * math.sin(2.0 * w - 0.7), 4.0 * math.sin(w - 0.5), 10.0 * math.sin(w - 0.3)),
        "head": (-2.0 + 4.0 * math.sin(2.0 * w - 1.3), 6.0 * math.sin(w - 1.1), 8.0 * math.sin(w - 0.9) + 7.0 * twitch(u, 0.66, 0.05, 1.0)),
        "extra1": (8.0 * twitch(u, 0.10), 0.0, 0.0), "extra1b": (32.0 * twitch(u, 0.12), 0.0, 0.0),
        "extra2": (34.0 * twitch(u, 0.33), 14.0 * twitch(u, 0.33), 0.0),
        "extra3": (18.0 * twitch(u, 0.90), -12.0 * twitch(u, 0.90), 0.0),
        "extra4": (0.0, -9.0 * twitch(u, 0.46), 0.0), "extra4b": (14.0 * twitch(u, 0.48), -24.0 * twitch(u, 0.48), 0.0),
        "extra5": (9.0 * twitch(u, 0.60), 0.0, 0.0), "extra5b": (26.0 * twitch(u, 0.62), 12.0 * twitch(u, 0.62), 0.0),
        "tail1": (0.0, 0.0, 9.0 * twitch(u, 0.76)), "tail2": (26.0 * twitch(u, 0.78), 0.0, 14.0 * twitch(u, 0.78)),
    }
    return {
        "mid": V3(0.022 * math.sin(w), 0.006 * math.sin(w + 1.0), -0.008 + 0.011 * breath),
        "pitch": 0.8 * math.sin(2.0 * w + 0.8), "roll": 2.2 * math.sin(w + 0.4), "yaw": 1.2 * math.sin(w),
        "flex": 2.2 * breath, "bend": 1.2 * math.sin(w + 0.3), "rot": rot,
    }


def clip_walk(an, u):
    """Stalking walk: low body, diagonal pairs stepping together."""
    w = 2.0 * math.pi * u
    stride, duty = 0.54, 0.62
    td = {"FL": 0.0, "HR": 0.04, "FR": 0.5, "HL": 0.54}
    feet = {}
    for leg in an.legs:
        if leg.front:
            feet[leg.key] = gait_foot(leg, u, td[leg.key], duty, stride, 0.11, 0.285, -0.49, heel=28.0, fold=50.0)
        else:
            feet[leg.key] = gait_foot(leg, u, td[leg.key], duty, stride, 0.08, 0.205, 0.365, heel=30.0, fold=38.0)
    return {
        "mid": V3(0.014 * math.sin(w + 0.4), 0.0, -0.075 + 0.010 * math.cos(2.0 * w + 0.5)),
        "pitch": 3.0 + 1.0 * math.sin(2.0 * w), "roll": 2.2 * math.sin(w + 1.0), "yaw": 1.5 * math.sin(w + 0.2),
        "flex": 1.5 + 0.8 * math.sin(2.0 * w + 1.0), "bend": 2.6 * math.sin(w - 0.2), "twist": 1.2 * math.sin(w + 0.9),
        "rot": {
            "neck": (7.0 + 2.0 * math.sin(2.0 * w + 0.3), 2.0 * math.sin(w + 2.0), -3.0 * math.sin(w - 0.2) + 5.0 * math.sin(w - 1.2)),
            "head": (-10.0 + 2.5 * math.sin(2.0 * w - 0.6), -3.0 * math.sin(w + 1.0), 4.0 * math.sin(w - 1.6)),
        },
        "feet": feet,
    }


def clip_run(an, u):
    """Gallop: the fore pair lands and pulls, the back rounds, the hind pair lands under the body and kicks."""
    w = 2.0 * math.pi * u
    stride, duty = 0.60, 0.30
    td = {"FR": 0.02, "FL": 0.10, "HR": 0.50, "HL": 0.57}     # transverse gallop, left lead
    feet = {}
    for leg in an.legs:
        if leg.front:
            feet[leg.key] = gait_foot(leg, u, td[leg.key], duty, stride, 0.24, 0.22, -0.465, heel=45.0, fold=80.0, carry=0.42)
        else:
            feet[leg.key] = gait_foot(leg, u, td[leg.key], duty, stride + 0.04, 0.20, 0.16, 0.32, heel=45.0, fold=60.0, carry=0.42)
    pitch = 7.0 * math.cos(w - 2.0 * math.pi * 0.14)
    flex = 7.5 * math.cos(w - 2.0 * math.pi * 0.42)
    chest_pitch = pitch + 1.5 * flex
    return {
        "mid": V3(0.0, 0.02 * math.sin(w + 0.5), -0.055 - 0.022 * math.cos(2.0 * (w - 2.0 * math.pi * 0.16))),
        "pitch": pitch, "roll": 2.0 * math.sin(w + 1.0), "yaw": 1.5 * math.sin(w + 2.4),
        "flex": flex, "bend": 1.5 * math.sin(w), "twist": 1.0 * math.sin(w + 0.6),
        "rot": {
            "neck": (-12.0 - 0.35 * chest_pitch, 0.0, 2.0 * math.sin(w + 1.0)),
            "head": (-10.0 - 0.40 * chest_pitch + 4.0 * math.sin(w - 1.0), 2.0 * math.sin(w + 0.3), 0.0),
        },
        "feet": feet,
    }


def clip_pounce(an, t):
    """Crouch and wind up (0-0.25 s), leap with the body stretched and the fore legs reaching (0.25-0.75 s),
    land and absorb (0.75-1.0 s)."""
    mid = spline(t, [(0.0, V3()), (0.12, V3(0, 0.05, -0.10)), (0.25, V3(0, 0.09, -0.18)), (0.33, V3(0, -0.02, -0.02)),
                     (0.45, V3(0, -0.10, 0.22)), (0.55, V3(0, -0.12, 0.29)), (0.66, V3(0, -0.10, 0.19)), (0.76, V3(0, -0.05, 0.02)),
                     (0.85, V3(0, -0.01, -0.12)), (0.94, V3(0, 0.0, -0.03)), (1.0, V3())])
    pitch = spline(t, [(0, 0), (0.12, 3), (0.25, -3), (0.33, -13), (0.45, -21), (0.55, -10), (0.66, 7), (0.76, 13), (0.85, 6), (0.94, 1), (1, 0)])
    flex = spline(t, [(0, 0), (0.12, 4), (0.25, 8), (0.33, 1), (0.45, -7), (0.55, -8), (0.66, -3), (0.76, 3), (0.85, 7), (0.94, 2), (1, 0)])
    neck = spline(t, [(0, 0), (0.25, -14), (0.45, -26), (0.62, -18), (0.76, 8), (0.85, 14), (1, 0)])
    head = spline(t, [(0, 0), (0.25, -12), (0.45, -22), (0.62, -6), (0.76, 12), (0.85, 8), (1, 0)])
    feet = {}
    for leg in an.legs:
        tt = t + (0.012 if leg.c.x < 0 else 0.0)                # the right side a touch later
        if leg.front:
            wgt = clamp(spline(tt, [(0, 0), (0.27, 0), (0.36, 1), (0.66, 1), (0.77, 0), (1, 0)]), 0.0, 1.0)
            feet[leg.key] = {
                "w": wgt, "pitch": spline(tt, [(0, 0), (0.24, 0), (0.30, 20), (0.36, 0), (1, 0)]),
                "rel": spline(tt, [(0.27, V3()), (0.45, V3(0, -0.26, 0.20)), (0.62, V3(0, -0.30, 0.16)), (0.76, V3(0, -0.10, 0.02))]),
                "rpitch": spline(tt, [(0.27, 0), (0.42, -30), (0.62, -22), (0.76, 0)]),
            }
        else:
            wgt = clamp(spline(tt, [(0, 0), (0.35, 0), (0.45, 1), (0.72, 1), (0.83, 0), (1, 0)]), 0.0, 1.0)
            feet[leg.key] = {
                "w": wgt, "pitch": spline(tt, [(0, 0), (0.24, 0), (0.35, 42), (0.45, 50), (0.80, 10), (0.84, 0), (1, 0)]),
                "rel": spline(tt, [(0.35, V3()), (0.50, V3(0, 0.26, 0.20)), (0.66, V3(0, 0.05, 0.16)), (0.82, V3(0, -0.04, 0.02))]),
                "rpitch": spline(tt, [(0.35, 42), (0.50, 55), (0.68, 15), (0.82, 0)]),
            }
    return {"mid": mid, "pitch": pitch, "flex": flex, "rot": {"neck": (neck, 0, 0), "head": (head, 0, 0)}, "feet": feet}


def clip_bite(an, t):
    """The head rears back, snaps forward and down with a sideways twist, shakes, recovers."""
    mid = spline(t, [(0, V3()), (0.07, V3(0, 0.04, 0.015)), (0.17, V3(0, -0.13, -0.06)), (0.28, V3(0, -0.12, -0.05)), (0.40, V3(0, -0.05, -0.02)), (0.5, V3())])
    env = ramp(t, 0.15, 0.19) * (1.0 - ramp(t, 0.36, 0.45))
    shake = env * math.sin(2.0 * math.pi * (t - 0.17) / 0.115)
    shake_lag = env * math.sin(2.0 * math.pi * (t - 0.195) / 0.115)
    side = spline(t, [(0, 0), (0.07, -10), (0.17, 16), (0.40, 4), (0.5, 0)])
    return {
        "mid": mid + V3(0.012 * shake_lag, 0, 0),
        "pitch": spline(t, [(0, 0), (0.07, -4), (0.17, 7), (0.30, 6), (0.42, 2), (0.5, 0)]),
        "flex": spline(t, [(0, 0), (0.07, 3), (0.17, -5), (0.30, -3), (0.5, 0)]),
        "yaw": -2.0 * shake_lag, "bend": -1.5 * shake_lag,
        "rot": {
            "neck": (spline(t, [(0, 0), (0.07, -20), (0.17, 14), (0.30, 10), (0.42, 3), (0.5, 0)]), 6.0 * shake_lag, 0.4 * side + 11.0 * shake_lag),
            "head": (spline(t, [(0, 0), (0.07, -24), (0.17, 18), (0.30, 12), (0.42, 2), (0.5, 0)]), 1.2 * side + 14.0 * shake, 0.6 * side + 26.0 * shake),
        },
    }


def clip_flinch(an, t):
    """Recoil from a hit: the fore body jerks up and back, the head whips aside, one fore paw comes off the floor."""
    e = 10.0 / FPS
    return {
        "mid": spline(t, [(0, V3()), (0.05, V3(0.02, 0.06, 0.03)), (0.12, V3(0.03, 0.09, 0.015)), (0.22, V3(0.012, 0.035, -0.02)), (e, V3())]),
        "pitch": spline(t, [(0, 0), (0.05, -7), (0.12, -10), (0.22, -3), (e, 0)]),
        "roll": spline(t, [(0, 0), (0.05, 5), (0.12, 8), (0.22, 2), (e, 0)]),
        "yaw": spline(t, [(0, 0), (0.06, -4), (0.14, -6), (0.24, -2), (e, 0)]),
        "flex": spline(t, [(0, 0), (0.05, 5), (0.12, 6), (0.22, 2), (e, 0)]),
        "rot": {
            "neck": (spline(t, [(0, 0), (0.05, -16), (0.12, -12), (0.22, -2), (e, 0)]), 0.0, spline(t, [(0, 0), (0.05, 12), (0.12, 16), (0.22, 5), (e, 0)])),
            "head": (spline(t, [(0, 0), (0.05, 12), (0.12, 6), (e, 0)]), spline(t, [(0, 0), (0.06, 14), (0.14, 10), (e, 0)]),
                     spline(t, [(0, 0), (0.05, 20), (0.12, 24), (0.22, 8), (e, 0)])),
        },
        "feet": {"FL": {"pos": spline(t, [(0, V3()), (0.06, V3(0, 0.02, 0.07)), (0.14, V3(0, 0.06, 0.09)), (0.24, V3(0, 0.02, 0.03)), (0.30, V3())]),
                        "pitch": spline(t, [(0, 0), (0.10, 25), (0.30, 0)])}},
    }


# how the legs come to lie when the animal is down on its right side (offsets carried by chest / pelvis):
# the lower (right) legs lie on the floor, the upper (left) legs sag down in front of them
LYING = {
    "FR": (V3(0.10, 0.05, 0.15), 35.0), "HR": (V3(0.05, -0.05, 0.12), 30.0),
    "FL": (V3(-0.42, -0.12, 0.10), 25.0), "HL": (V3(-0.40, 0.12, 0.10), 30.0),
}


def clip_death_side(an, t):
    """Legs buckle, the animal topples onto its right side (the growths of the left side end up on top) and stays down."""
    feet = {}
    start = {"FR": 0.24, "HR": 0.28, "FL": 0.34, "HL": 0.38}
    for leg in an.legs:
        t0 = start[leg.key]
        rel, rp = LYING[leg.key]
        sag = 1.0 if leg.c.x < 0 else spline(t, [(0, 0.0), (t0 + 0.30, 0.35), (t0 + 0.50, 1.0), (1.1, 1.0)])   # upper legs drop after the impact
        feet[leg.key] = {"w": ramp(t, t0, t0 + 0.32), "rel": V3(rel.x * sag, rel.y, rel.z), "rpitch": rp * ramp(t, t0, t0 + 0.4),
                         "pos": spline(t, [(0, V3()), (0.30, V3(0.03 if leg.c.x > 0 else 0.06, 0.02, 0.0)), (1.1, V3(0.05, 0.02, 0.0))])}
    return {
        "mid": V3(spline(t, [(0, 0), (0.10, 0.02), (0.30, -0.04), (0.50, -0.20), (0.64, -0.40), (1.1, -0.42)]),
                  spline(t, [(0, 0), (0.10, 0.03), (0.30, 0.02), (0.64, 0.0), (1.1, 0.0)]),
                  spline(t, [(0, 0), (0.10, 0.02), (0.30, -0.20), (0.50, -0.40), (0.64, -0.60), (1.1, -0.60)])),
        "pitch": spline(t, [(0, 0), (0.10, -4), (0.30, 5), (0.55, 2), (0.70, 0), (1.1, 0)]),
        "roll": spline(t, [(0, 0), (0.10, 2), (0.30, -10), (0.50, -48), (0.64, -93), (0.74, -86), (0.86, -91), (1.1, -90)]),
        "yaw": spline(t, [(0, 0), (0.30, -3), (0.64, -8), (1.1, -8)]),
        "flex": spline(t, [(0, 0), (0.10, -3), (0.30, 6), (0.64, 3), (0.80, 5), (1.1, 4)]),
        "bend": spline(t, [(0, 0), (0.50, -2), (0.70, -5), (1.1, -4)]),
        "rot": {
            "neck": (spline(t, [(0, 0), (0.10, -10), (0.30, 8), (0.64, 4), (1.1, 6)]), spline(t, [(0, 0), (0.64, -6), (1.1, -8)]),
                     spline(t, [(0, 0), (0.10, 6), (0.50, -8), (0.66, -22), (0.76, -14), (0.90, -24), (1.1, -24)])),
            "head": (spline(t, [(0, 0), (0.10, -8), (0.30, 10), (0.64, 2), (1.1, 4)]), spline(t, [(0, 0), (0.64, -8), (1.1, -10)]),
                     spline(t, [(0, 0), (0.10, -14), (0.50, -6), (0.70, -24), (0.80, -16), (0.95, -26), (1.1, -26)])),
        },
        "feet": feet,
        "ground": ("rest", ramp(t, 0.46, 0.63), spline(t, [(0, 0), (0.63, 0), (0.71, 0.035), (0.80, 0.0), (1.1, 0)])),
        "limp": ramp(t, 0.20, 0.50),
    }


def clip_death_roll(an, t):
    """Fore legs give way at speed, the chest ploughs in, the body rolls over its left shoulder and back
    and comes to rest on its right side."""
    roll = spline(t, [(0, 0), (0.18, 5), (0.30, 28), (0.44, 95), (0.57, 180), (0.71, 262), (0.83, 277), (0.96, 267), (1.2, 270)])
    feet = {}
    for leg in an.legs:
        rel, rp = LYING[leg.key]
        t0 = 0.14 if leg.front else 0.24
        k = 0.0 if leg.front else 1.5
        side = 1.0 if leg.c.x > 0 else -1.0
        flail = (1.0 - ramp(t, 0.80, 1.0)) * ramp(t, t0, t0 + 0.2)
        wob = V3(0.05 * side, 0.16 * math.sin(11.0 * t + k + side), 0.14 + 0.07 * math.sin(13.0 * t + 2.0 * k))
        sag = 1.0 if side < 0 else spline(t, [(0, 0.0), (0.84, 0.3), (1.02, 1.0), (1.2, 1.0)])
        lying = V3(rel.x * sag, rel.y, rel.z)
        feet[leg.key] = {"w": ramp(t, t0, t0 + 0.22), "rel": wob * flail + lying * (1.0 - flail), "rpitch": rp,
                         "pos": V3(0, 0.10 * ramp(t, 0.0, 0.2), 0.0) if leg.front else V3(),
                         "pitch": 0.0 if leg.front else 35.0 * ramp(t, 0.12, 0.26)}
    return {
        "mid": V3(spline(t, [(0, 0), (0.30, 0.05), (0.45, 0.20), (0.60, 0.30), (0.75, 0.24), (1.2, 0.20)]),
                  spline(t, [(0, 0), (0.18, -0.10), (0.35, -0.22), (0.60, -0.32), (0.85, -0.36), (1.2, -0.36)]),
                  spline(t, [(0, 0), (0.18, -0.20), (0.30, -0.42), (0.45, -0.50), (1.2, -0.50)])),
        "pitch": spline(t, [(0, 0), (0.18, 20), (0.30, 24), (0.45, 12), (0.60, 0), (0.80, -3), (1.2, 0)]),
        "roll": roll,
        "yaw": spline(t, [(0, 0), (0.30, 4), (0.60, 14), (0.85, 24), (1.2, 26)]),
        "flex": spline(t, [(0, 0), (0.20, 6), (0.45, 10), (0.60, 5), (0.80, -2), (1.0, 5), (1.2, 4)]),
        "bend": spline(t, [(0, 0), (0.60, 0), (1.0, -4), (1.2, -4)]),
        "rot": {
            "neck": (spline(t, [(0, 0), (0.20, 26), (0.50, 30), (0.80, 10), (1.2, 6)]), spline(t, [(0, 0), (0.85, 0), (1.2, -8)]),
                     spline(t, [(0, 0), (0.30, 8), (0.60, -4), (0.84, -10), (0.94, -26), (1.04, -18), (1.2, -24)])),
            "head": (spline(t, [(0, 0), (0.20, 24), (0.50, 20), (0.80, 6), (1.2, 4)]), spline(t, [(0, 0), (0.85, 0), (1.2, -10)]),
                     spline(t, [(0, 0), (0.30, 10), (0.60, -6), (0.86, -12), (0.96, -28), (1.06, -20), (1.2, -26)])),
        },
        "feet": feet,
        "ground": ("rest", ramp(t, 0.14, 0.30), spline(t, [(0, 0), (0.30, 0.02), (0.44, 0.10), (0.57, 0.04), (0.70, 0.09), (0.82, 0.0), (0.90, 0.03), (1.0, 0.0), (1.2, 0.0)])),
        "limp": ramp(t, 0.10, 0.35),
    }


CLIPS = [
    # name, function, frames at 30 fps, loop
    ("idle", clip_idle, 72, True),
    ("walk", clip_walk, 30, True),
    ("run", clip_run, 13, True),
    ("pounce", clip_pounce, 30, False),
    ("bite", clip_bite, 15, False),
    ("flinch", clip_flinch, 10, False),
    ("death_side", clip_death_side, 33, False),
    ("death_roll", clip_death_roll, 36, False),
]


# ------------------------------------------------------------------------------------------------ review renders
FONT = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111", "4": "101101111001001",
    "5": "111100111001111", "6": "111100111101111", "7": "111001010010010", "8": "111101111101111", "9": "111101111001111",
    "-": "000000111000000", ".": "000000000000010", " ": "000000000000000", "_": "000000000000111", ":": "000010000010000",
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
    "F": "111100110100100", "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
    "K": "101101110101101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
    "P": "110101110100100", "Q": "010101101111011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010",
    "Z": "111001010100111", "/": "001001010100100", "=": "000111000111000", "+": "000010111010000",
}


def draw_text(img, x, y, text, color=(1.0, 1.0, 0.3), scale=2):
    h, w = img.shape[:2]
    for ch in text.upper():
        g = FONT.get(ch, FONT[" "])
        for k, bit in enumerate(g):
            if bit == "1":
                yy, xx = y + (k // 3) * scale, x + (k % 3) * scale
                if 0 <= yy < h - scale and 0 <= xx < w - scale:
                    img[yy:yy + scale, xx:xx + scale, :3] = color
        x += 4 * scale


def load_png(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    return arr.reshape(h, w, 4)[::-1].copy()


def save_png(arr, path):
    h, w = arr.shape[:2]
    img = bpy.data.images.new("tmp_png", w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).reshape(-1))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


class Review:
    def __init__(self, folder, arm):
        self.folder = folder
        self.arm = arm
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.film_transparent = False
        scene.view_settings.view_transform = "Standard"
        scene.display.render_aa = "8"
        if scene.world is None:
            scene.world = bpy.data.worlds.new("review_world")
        scene.world.color = (0.05, 0.05, 0.06)
        cam_data = bpy.data.cameras.new("review_cam")
        self.cam = bpy.data.objects.new("review_cam", cam_data)
        scene.collection.objects.link(self.cam)
        scene.camera = self.cam
        arm.hide_render = True
        self.mode("clay")
        self.tmp = os.path.join(folder, "_tmp.png")

    def mode(self, mode):
        sh = bpy.context.scene.display.shading
        sh.show_shadows = False
        sh.show_specular_highlight = False
        if mode == "tex":
            sh.light = "STUDIO"
            sh.color_type = "TEXTURE"
            sh.show_cavity = False
        elif mode == "vertex":
            sh.light = "STUDIO"
            sh.color_type = "VERTEX"
            sh.show_cavity = False
        else:
            sh.light = "STUDIO"
            sh.color_type = "SINGLE"
            sh.single_color = (0.8, 0.78, 0.74)
            sh.show_cavity = True
            sh.cavity_type = "BOTH"

    def size(self, w, h):
        r = bpy.context.scene.render
        r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100

    def aim(self, pos, target, up=(0, 0, 1)):
        pos, target, up = Vector(pos), Vector(target), Vector(up)
        fwd = (target - pos).normalized()
        right = fwd.cross(up).normalized()
        upv = right.cross(fwd).normalized()
        m = Matrix((right, upv, -fwd)).transposed().to_4x4()
        m.translation = pos
        self.cam.matrix_world = m
        return right, upv

    def shot(self, pos, target, up=(0, 0, 1), ortho=None, lens=50, ground=False, label=None):
        cam = self.cam.data
        cam.clip_start, cam.clip_end = 0.01, 100.0
        if ortho:
            cam.type = "ORTHO"
            cam.ortho_scale = ortho
        else:
            cam.type = "PERSP"
            cam.lens = lens
        right, upv = self.aim(pos, target, up)
        r = bpy.context.scene.render
        r.filepath = self.tmp
        bpy.ops.render.render(write_still=True)
        img = load_png(self.tmp)
        if ortho and ground and abs(upv.z) > 0.99:
            # ground line (z = 0) for side / front views
            H, W = img.shape[:2]
            ppm = max(W, H) / ortho
            y = int(round(H / 2 + Vector(target).z * ppm))
            if 0 <= y < H:
                img[y, :, :3] = img[y, :, :3] * 0.4 + np.array((1.0, 0.45, 0.2)) * 0.6
        if label:
            draw_text(img, 8, 8, label, scale=3)
        return img

    def sheet(self, tiles, cols, path, pad=4):
        h, w = tiles[0].shape[:2]
        rows = int(math.ceil(len(tiles) / cols))
        out = np.zeros((rows * (h + pad) + pad, cols * (w + pad) + pad, 4), dtype=np.float32)
        out[..., :3] = 0.02
        out[..., 3] = 1.0
        for k, t in enumerate(tiles):
            r, c = divmod(k, cols)
            out[pad + r * (h + pad):pad + r * (h + pad) + h, pad + c * (w + pad):pad + c * (w + pad) + w] = t
        save_png(out, path)
        if os.path.exists(self.tmp):
            os.remove(self.tmp)
        log("review:", path)


def set_pose(arm, rig, local):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        off, rot = local.get(pb.name, (Vector(), Quaternion()))
        loc, q = rig.basis(pb.name, off, rot)
        pb.location = loc
        pb.rotation_quaternion = q
    bpy.context.view_layer.update()


def review_weights(rv, obj, W):
    import colorsys
    me = obj.data
    C = np.zeros((len(me.vertices), 4), dtype=np.float32)
    C[:, 3] = 1.0
    for j, n in enumerate(DEFORM):
        C[:, :3] += W[:, j:j + 1] * np.array(colorsys.hsv_to_rgb((j * 0.61803398875) % 1.0, 0.85, 1.0))[None, :]
    ca = me.color_attributes.new("weight_colours", "FLOAT_COLOR", "POINT")
    ca.data.foreach_set("color", C.reshape(-1))
    me.color_attributes.active_color = ca
    rv.mode("vertex")
    rv.size(1100, 900)
    tiles = [rv.shot((5, 0, 0.55), (0, 0, 0.55), ortho=1.6, label="LEFT"), rv.shot((-5, 0, 0.55), (0, 0, 0.55), ortho=1.6, label="RIGHT"),
             rv.shot((0, 0, 5), (0, 0, 0), up=(0, -1, 0), ortho=1.6, label="TOP"), rv.shot((0, 0, -5), (0, 0, 0), up=(0, -1, 0), ortho=1.6, label="BOTTOM")]
    rv.sheet(tiles, 2, os.path.join(rv.folder, "review_weights.png"))
    me.color_attributes.remove(ca)
    rv.mode("clay")


TEST_POSES = [
    ("FL FWD 40", {"front_upper.L": quat(-40)}, "L"), ("FL BACK 40", {"front_upper.L": quat(40)}, "L"),
    ("FR FWD 40", {"front_upper.R": quat(-40)}, "R"), ("FR BACK 40", {"front_upper.R": quat(40)}, "R"),
    ("HL FWD 40", {"hind_upper.L": quat(-40)}, "L"), ("HL BACK 40", {"hind_upper.L": quat(40)}, "L"),
    ("HR FWD 40", {"hind_upper.R": quat(-40)}, "R"), ("HR BACK 40", {"hind_upper.R": quat(40)}, "R"),
    ("SPINE ARCH", {"spine1": quat(14), "spine2": quat(14), "chest": quat(14), "pelvis": quat(-20)}, "L"),
    ("SPINE HOLLOW", {"spine1": quat(-12), "spine2": quat(-12), "chest": quat(-12), "pelvis": quat(18)}, "L"),
    ("SPINE SIDE", {"spine1": quat(rz=14), "spine2": quat(rz=14), "chest": quat(rz=14)}, "T"),
    ("HEAD TURN", {"neck": quat(rz=25), "head": quat(rz=40)}, "T"),
    ("NECK DOWN", {"neck": quat(30), "head": quat(20)}, "L"),
    ("NECK UP TWIST", {"neck": quat(-30, 15), "head": quat(-30, 25)}, "L"),
    ("KNEES BENT", {"front_lower.L": quat(-60), "front_paw.L": quat(70), "hind_lower.L": quat(50), "hind_paw.L": quat(-60),
                    "front_lower.R": quat(-60), "front_paw.R": quat(70), "hind_lower.R": quat(50), "hind_paw.R": quat(-60)}, "L"),
    ("EXTRAS OUT", {"extra1": quat(ry=-40), "extra1b": quat(ry=-30), "extra2": quat(ry=-50), "extra3": quat(ry=-50), "extra4": quat(ry=-30),
                    "extra4b": quat(ry=-40), "extra5": quat(ry=40), "extra5b": quat(ry=30), "tail1": quat(-30), "tail2": quat(-40)}, "B"),
]


def review_poses(rv, arm, rig):
    rv.size(900, 760)
    tiles = []
    for label, rots, view in TEST_POSES:
        set_pose(arm, rig, {b: (Vector(), q) for b, q in rots.items()})
        if view == "L":
            tiles.append(rv.shot((5, 0, 0.55), (0, 0, 0.55), ortho=1.9, ground=True, label=label))
        elif view == "R":
            tiles.append(rv.shot((-5, 0, 0.55), (0, 0, 0.55), ortho=1.9, ground=True, label=label))
        elif view == "T":
            tiles.append(rv.shot((0, 0, 5), (0, 0, 0), up=(0, -1, 0), ortho=1.9, label=label))
        else:
            tiles.append(rv.shot((0, 5, 0.55), (0, 0, 0.55), ortho=1.9, ground=True, label=label))
    set_pose(arm, rig, {})
    rv.sheet(tiles, 4, os.path.join(rv.folder, "review_test_poses.png"))


def review_clip(rv, arm, act, name, nframes, loop, top=False):
    """Frame strip of one clip: eight frames from the animal's left side, and a second row from the front-left
    (or from above for the death clips)."""
    rv.size(700, 520)
    if loop:
        picks = [int(round(k * nframes / 8.0)) for k in range(8)]
    else:
        picks = [int(round(k * nframes / 7.0)) for k in range(8)]
    side, second = [], []
    for f in picks:
        show_action(arm, act, f)
        label = "%s %d/%d" % (name, f, nframes)
        side.append(rv.shot((6, -0.05, 0.55), (0, -0.05, 0.55), ortho=2.1, ground=True, label=label))
        if top:
            second.append(rv.shot((0, -0.05, 6), (0, -0.05, 0), up=(0, -1, 0), ortho=2.1, label="top %d" % f))
        else:
            second.append(rv.shot((2.2, -2.8, 1.0), (0.0, -0.05, 0.48), lens=62, label="front left %d" % f))
    rv.sheet(side, 4, os.path.join(rv.folder, "review_clip_%s.png" % name))
    rv.sheet(second, 4, os.path.join(rv.folder, "review_clip_%s_b.png" % name))


def export_glb(obj, arm, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT", export_image_format="AUTO",
        export_skins=True, export_def_bones=False, export_all_influences=False, export_influence_nb=4,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_range=False,
        export_anim_slide_to_zero=True, export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=True,
        export_morph=False, export_cameras=False, export_lights=False,
    )
    log("exported", path, "%.2f MB" % (os.path.getsize(path) / 1e6))


# ------------------------------------------------------------------------------------------------ main
def main():
    parse_args()
    obj = import_mesh(MESH_PATH)
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = FPS, 1.0
    tex = build_textures(TEX_DIR, WORK, TEX_SIZE)
    build_material(obj.data, tex)
    arm = build_armature()
    W, method = skin(obj, arm)
    rig = Rig(arm)
    rv = Review(REVIEW, arm) if REVIEW else None
    only = OPT["only"].split(",") if OPT["only"] else None
    if rv and not only:
        review_weights(rv, obj, W)
        review_poses(rv, arm, rig)
    co = np.array([v.co[:] for v in obj.data.vertices])
    animator = Animator(rig, co, W)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    actions = []
    for name, fn, nframes, loop in CLIPS:
        if only and name not in only:
            continue
        frames = animator.build(name, lambda x, fn=fn: fn(animator, x), nframes, loop)
        act = bake_action(arm, rig, name, frames)
        actions.append(act)
        if rv:
            review_clip(rv, arm, act, name, nframes, loop, top=name.startswith("death"))
    scene.frame_start, scene.frame_end = 0, max([int(a.frame_range[1]) for a in actions] + [1])
    stash_actions(arm, actions)
    scene.frame_set(0)
    if OPT["blend"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OPT["blend"]))
    export_glb(obj, arm, OUT_GLB)
    log("done: weights by", method, "| clips", ", ".join("%s %.3fs" % (a.name, a.frame_range[1] / FPS) for a in actions))


if __name__ == "__main__":
    main()
