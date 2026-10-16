"""The infected sharks of the flooded laboratory: a spine chain from the snout to the tail, a jaw, and the clips
the game plays (swim, swim_fast, turn_l, turn_r, lunge, bite, thrash, death). One GLB comes out.

The body comes prepared by the character pipeline of the model workshop (p4_prepare.py: reduced, new UVs, its
colour, roughness/metal and normal maps baked over from the untouched mesh), as prep.blend and bake_*.png.

  blender --background --factory-startup --python tools/blender_rig_shark.py -- \\
      --blend <work>/shark1/prep.blend --maps <work>/shark1 --out assets/models/shark1.glb \\
      --length 3.8 --jaw "y0,z0;y1,z1;..." [--review <folder>] [--name shark1]

  --jaw     the lower jaw seen from the side (from +X), as a closed outline of (y, z) points in the space of the
            prepared body (metres; -y forward, the belly on z = 0), read off f_marks.py pictures of prep.blend.
            Everything inside it moves with the jaw; within 5 cm of its edge the skin is shared with the head.
  --hinge   y,z of the jaw's hinge (where the outline turns about), in the same space.
  --jawscale  how far the jaws open, as a share of the clips' angles (a mouth that is modelled open needs less).

The animal looks along -Y in Blender (+Z in the game's file), its left side is +X, up is +Z. The origin of the
finished model lies on the body's axis, at BODY_MID of its length from the snout: the game holds it there.
"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Quaternion, Matrix

FPS = 30
OPT = {"blend": None, "maps": None, "out": None, "length": "3.8", "jaw": None, "hinge": None, "review": None, "name": "shark",
       "jawscale": "1.0"}
# where the body's origin was moved from (the prepared body's space: --jaw and --hinge are given in it)
SHIFT = Vector((0.0, 0.0, 0.0))
SCALE = 1.0
# where along the body (0 snout, 1 tip of the tail fin) the joints lie
STATIONS = {"nose": 0.0, "head": 0.22, "chest": 0.36, "s1": 0.48, "s2": 0.60, "s3": 0.70, "s4": 0.79, "tail": 0.86, "tip": 1.0}
BODY_MID = 0.42
# bone: (parent, from station, to station)
CHAIN = [("root", None, "chest", "head"), ("head", "root", "head", "nose"), ("spine1", "root", "chest", "s1"),
         ("spine2", "spine1", "s1", "s2"), ("spine3", "spine2", "s2", "s3"), ("spine4", "spine3", "s3", "s4"),
         ("tail", "spine4", "s4", "tip")]


def log(*a):
    print("[shark]", *a)
    sys.stdout.flush()


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    i = 0
    while i < len(argv):
        k = argv[i].lstrip("-")
        if k in OPT and i + 1 < len(argv):
            OPT[k] = argv[i + 1]
            i += 2
        else:
            i += 1


def smoothstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------------------------------------ the body
def load_body():
    bpy.ops.wm.open_mainfile(filepath=OPT["blend"])
    obj = next(o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("_closed"))
    for o in list(bpy.data.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    me = obj.data
    co = np.array([v.co[:] for v in me.vertices])
    lo, hi = co.min(axis=0), co.max(axis=0)
    length = hi[1] - lo[1]
    f = float(OPT["length"]) / length
    co *= f
    lo, hi = co.min(axis=0), co.max(axis=0)
    L = hi[1] - lo[1]
    nose = lo[1]
    # the body's axis: in thin slices across it, the middle of the skin (fins pull the extremes, not the median)
    # the body's axis: a straight line through the middle of the head and of the tail's root (thin slices across
    # the body there have no fins to pull the middle up or down); every joint lies on it, the tail fin's on its own
    def middle(t):
        y = nose + L * t
        sel = np.abs(co[:, 1] - y) < 0.02 * L
        z = co[sel, 2]
        return y, float((z.min() + z.max()) * 0.5)
    ya, za = middle(0.12)
    yb, zb = middle(0.78)

    def line(y):
        return za + (zb - za) * (y - ya) / (yb - ya)
    axis = {}
    for name, t in STATIONS.items():
        y = nose + L * t
        axis[name] = Vector((0.0, y, line(y) if t < 0.9 else middle(0.97)[1]))
    mid_y = nose + L * BODY_MID
    origin = Vector((0.0, mid_y, line(mid_y)))
    co -= np.array(origin)
    global SHIFT, SCALE
    SHIFT, SCALE = origin, f
    for k in axis:
        axis[k] = axis[k] - origin
    me.vertices.foreach_set("co", co.astype(np.float32).reshape(-1))
    me.update()
    log("body: %d triangles, length %.2f m, height %.2f m, width %.2f m" % (
        sum(len(p.vertices) - 2 for p in me.polygons), L, hi[2] - lo[2], hi[0] - lo[0]))
    for k in STATIONS:
        log("   %-5s y %6.3f z %6.3f" % (k, axis[k].y, axis[k].z))
    return obj, axis, L


def material(obj):
    folder = OPT["maps"]
    mat = bpy.data.materials.new(OPT["name"])
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def image(file, non_color):
        node = nt.nodes.new("ShaderNodeTexImage")
        img = bpy.data.images.load(os.path.join(folder, file))
        if non_color:
            img.colorspace_settings.name = "Non-Color"
        img.pack()
        node.image = img
        return node
    col = image("bake_diffuse.png", False)
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    mr = image("bake_metallic_roughness.png", True)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(mr.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    nrm = image("bake_normal.png", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ------------------------------------------------------------------------------------------------ the skeleton
def build(obj, axis):
    data = bpy.data.armatures.new("SharkRig")
    arm = bpy.data.objects.new("SharkRig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, a, b in CHAIN:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = axis[a], axis[b]
        eb.roll = 0.0
        if parent:
            eb.parent = data.edit_bones[parent]
    def placed(y, z):
        return (y * SCALE - SHIFT.y, z * SCALE - SHIFT.z)
    hinge = Vector((0.0, *placed(*[float(v) for v in OPT["hinge"].split(",")])))
    jaw_pts = [placed(*[float(v) for v in p.split(",")]) for p in OPT["jaw"].split(";")]
    tip = min(jaw_pts, key=lambda p: p[0])
    eb = data.edit_bones.new("jaw")
    eb.head = hinge
    eb.tail = Vector((0.0, tip[0], tip[1]))
    eb.roll = 0.0
    eb.parent = data.edit_bones["head"]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm, jaw_pts, hinge


def inside_polygon(py, pz, poly):
    """Points (py, pz) inside the outline poly [(y, z), ...] (even-odd rule)."""
    inside = np.zeros(len(py), dtype=bool)
    n = len(poly)
    for i in range(n):
        y0, z0 = poly[i]
        y1, z1 = poly[(i + 1) % n]
        cross = ((z0 > pz) != (z1 > pz)) & (py < (y1 - y0) * (pz - z0) / ((z1 - z0) if z1 != z0 else 1e-9) + y0)
        inside ^= cross
    return inside


def weigh(obj, arm, axis, jaw_pts, L):
    me = obj.data
    co = np.array([v.co[:] for v in me.vertices])
    nose = axis["nose"].y
    t = (co[:, 1] - nose) / L
    # along the body every vertex is shared between the two bones whose middles it lies between
    names = ["head", "root", "spine1", "spine2", "spine3", "spine4", "tail"]
    centres = [0.08, 0.29, 0.42, 0.54, 0.65, 0.745, 0.90]
    W = np.zeros((len(co), len(names) + 1))
    for i, c in enumerate(centres):
        left = centres[i - 1] if i > 0 else -1.0
        right = centres[i + 1] if i + 1 < len(centres) else 2.0
        up = np.clip((t - left) / max(c - left, 1e-6), 0.0, 1.0) if i > 0 else (t <= c).astype(float)
        down = np.clip((right - t) / max(right - c, 1e-6), 0.0, 1.0) if i + 1 < len(centres) else (t >= c).astype(float)
        w = np.where(t <= c, up if i > 0 else 1.0, down if i + 1 < len(centres) else 1.0)
        W[:, i] = w
    # the head is one piece up to the gills
    rigid = t < 0.17
    W[rigid] = 0.0
    W[rigid, 0] = 1.0
    jaw = inside_polygon(co[:, 1], co[:, 2], jaw_pts)
    # how deep inside the outline: full weight from 5 cm in
    edge = np.full(len(co), np.inf)
    for i in range(len(jaw_pts)):
        a = np.array(jaw_pts[i])
        b = np.array(jaw_pts[(i + 1) % len(jaw_pts)])
        p = co[:, 1:3]
        t = np.clip(((p - a) @ (b - a)) / max((b - a) @ (b - a), 1e-9), 0.0, 1.0)
        edge = np.minimum(edge, np.linalg.norm(p - (a + t[:, None] * (b - a)), axis=1))
    soft = np.where(jaw, np.clip(0.35 + 0.65 * edge / 0.05, 0.0, 1.0), 0.0)
    # a little softness at the corners of the mouth, none along the jaw's own edge
    W[jaw] *= (1.0 - soft[jaw])[:, None]
    W[jaw, len(names)] = soft[jaw]
    W /= W.sum(axis=1, keepdims=True)
    groups = names + ["jaw"]
    obj.vertex_groups.clear()
    for j, n in enumerate(groups):
        vg = obj.vertex_groups.new(name=n)
        idx = np.nonzero(W[:, j] > 0.001)[0]
        for vi in idx:
            vg.add([int(vi)], float(W[vi, j]), "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    log("weights: %d vertices on the jaw, %d on the head alone" % (int(jaw.sum()), int(rigid.sum())))


# ------------------------------------------------------------------------------------------------ clips
def q(axis, deg):
    return Quaternion(axis, math.radians(deg))


YAW, PITCH, ROLL = Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))
SPINE = ["spine1", "spine2", "spine3", "spine4", "tail"]
# how far each of them swings in the tail beat (degrees) and how late (share of a beat)
# (each turns on top of the one before it: the tail fin swings by the sum, about 30 degrees)
BEAT = {"head": (2.5, -0.08), "root": (1.5, 0.0), "spine1": (2.5, 0.08), "spine2": (4.0, 0.16), "spine3": (5.5, 0.24), "spine4": (7.0, 0.32), "tail": (10.0, 0.42)}


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def key(t, pts):
    if t <= pts[0][0]:
        return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * ease((t - t0) / (t1 - t0))
    return pts[-1][1]


class Pose:
    def __init__(self):
        self.yaw = {b: 0.0 for b in BEAT}     # to the animal's left (degrees), each relative to its parent
        self.pitch = {b: 0.0 for b in BEAT}   # nose up
        self.roll = 0.0                       # the whole body about its axis, to its left
        self.jaw = 0.0                        # open (degrees)
        self.lift = Vector((0, 0, 0))


def beat(P, u, amp=1.0, side=0.0):
    for b, (a, lag) in BEAT.items():
        sign = -1.0 if b == "head" else 1.0
        P.yaw[b] += sign * a * amp * math.sin(2 * math.pi * (u - lag)) + side * (1.0 if b != "head" else 1.0)


def clip_swim(P, u):
    beat(P, u)
    P.jaw = 4 + 2 * math.sin(2 * math.pi * u)
    P.pitch["head"] = 1.5 * math.sin(4 * math.pi * u)


def clip_fast(P, u):
    beat(P, u, 1.45)
    P.jaw = 8
    P.roll = 2.5 * math.sin(2 * math.pi * u)


def clip_turn(P, u, side):
    beat(P, u, 0.8)
    for b in BEAT:
        P.yaw[b] += side * (9.0 if b != "head" else 12.0)
    P.roll = side * 8.0
    P.jaw = 5


def clip_lunge(P, t):
    coil = key(t, [(0, 0), (0.30, 1), (0.42, 0)])
    out = key(t, [(0.32, 0), (0.45, 1), (0.70, 1), (0.95, 0)])
    snap = key(t, [(0.55, 0), (0.62, 1), (1.1, 1)])
    s = math.sin(t * 2 * math.pi * 3.0)
    for i, b in enumerate(SPINE):
        P.yaw[b] += coil * (6 + 3 * i) * (1 if i % 2 == 0 else -1) + out * 7 * math.sin(2 * math.pi * (t * 4.0 - 0.1 * i))
    P.pitch["head"] = -6 * coil + 22 * out
    P.pitch["root"] = -4 * coil + 12 * out
    P.pitch["spine1"] = 4 * out
    P.pitch["tail"] = -10 * out
    P.yaw["head"] += 3 * s * out
    P.jaw = 4 + 44 * out * (1.0 - snap) + 6 * snap * out


def clip_bite(P, t):
    open_ = key(t, [(0, 0), (0.15, 1), (0.24, 1), (0.30, 0.1), (0.6, 0)])
    shake = key(t, [(0.28, 0), (0.32, 1), (0.50, 1), (0.6, 0)])
    P.jaw = 4 + 40 * open_
    P.pitch["head"] = 10 * open_ - 4 * shake
    P.yaw["head"] += 14 * math.sin(t * 2 * math.pi * 7) * shake
    P.yaw["root"] += -6 * math.sin(t * 2 * math.pi * 7) * shake
    P.roll = 10 * math.sin(t * 2 * math.pi * 7 + 1.0) * shake
    for i, b in enumerate(SPINE):
        P.yaw[b] += 5 * math.sin(t * 2 * math.pi * 7 - 0.6 * i) * shake


def clip_thrash(P, u):
    w = 2 * math.pi * u
    P.yaw["head"] += 22 * math.sin(3 * w)
    P.yaw["root"] += -8 * math.sin(3 * w)
    for i, b in enumerate(SPINE):
        P.yaw[b] += (4 + 2 * i) * math.sin(3 * w - 0.7 * (i + 1))
    P.roll = 26 * math.sin(2 * w + 0.5)
    P.pitch["head"] = 8 * math.sin(3 * w + 1.2)
    P.jaw = 20 + 18 * math.sin(6 * w)


def clip_death(P, t):
    over = key(t, [(0, 0), (0.25, 0.15), (1.6, 1.0), (2.6, 1.0)])
    twitch = key(t, [(0, 1), (1.2, 0.4), (2.2, 0)])
    P.roll = 172 * over
    for i, b in enumerate(SPINE):
        P.yaw[b] += 8 * twitch * math.sin(t * 2 * math.pi * 2.2 - 0.6 * i) + 2 * i * over
        P.pitch[b] = -3 * over
    P.yaw["head"] += -10 * twitch * math.sin(t * 2 * math.pi * 2.2 + 0.4)
    P.pitch["head"] = -8 * over
    P.jaw = 6 + 26 * key(t, [(0, 0), (0.3, 1), (1.5, 0.6), (2.6, 0.55)])


CLIPS = [
    ("swim", clip_swim, 1.4, True),
    ("swim_fast", clip_fast, 0.62, True),
    ("turn_l", lambda P, u: clip_turn(P, u, 1.0), 1.0, True),
    ("turn_r", lambda P, u: clip_turn(P, u, -1.0), 1.0, True),
    ("lunge", clip_lunge, 1.1, False),
    ("bite", clip_bite, 0.6, False),
    ("thrash", clip_thrash, 1.0, True),
    ("death", clip_death, 2.6, False),
]


def local_rotations(arm, P):
    """Rotations of every bone in its own rest axes, from deltas given in the model's axes (each relative to the
    parent's own turn)."""
    out = {}
    for b in arm.data.bones:
        r = b.matrix_local.to_quaternion()
        n = b.name
        if n == "jaw":
            d = q(PITCH, P.jaw * float(OPT["jawscale"]))
        elif n == "root":
            d = q(ROLL, P.roll) @ q(YAW, P.yaw["root"]) @ q(PITCH, -P.pitch["root"])
        else:
            d = q(YAW, P.yaw[n]) @ q(PITCH, -P.pitch[n])
        out[n] = r.inverted() @ d @ r
    return out


def bake(arm, name, fn, seconds, loop):
    n = int(round(seconds * FPS))
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    prev = {}
    rows = {b.name: [] for b in arm.data.bones}
    for f in range(n + 1):
        P = Pose()
        fn(P, (f % n) / float(n) if loop else f / float(FPS))
        rot = local_rotations(arm, P)
        for b, qq in rot.items():
            if b in prev and qq.dot(prev[b]) < 0:
                qq.negate()
            prev[b] = qq
            rows[b].append(qq[:])
    for b, values in rows.items():
        values = np.array(values)
        for i in range(4):
            fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["%s"].rotation_quaternion' % b, index=i, group_name=b)
            fc.keyframe_points.add(n + 1)
            k = np.empty((n + 1) * 2)
            k[0::2] = np.arange(n + 1)
            k[1::2] = values[:, i]
            fc.keyframe_points.foreach_set("co", k)
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
            fc.update()
    log("clip %-9s %.2f s" % (name, seconds))
    return act, n


def stash(arm, actions):
    ad = arm.animation_data
    ad.action = None
    for act in actions:
        track = ad.nla_tracks.new()
        track.name = act.name
        strip = track.strips.new(act.name, 0, act)
        strip.name = act.name
        track.mute = True
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)


# ------------------------------------------------------------------------------------------------ review
def review(arm, obj, actions, L, folder):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.16, 0.17, 0.2)
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_cavity = True
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    W, H = 420, 300
    scene.render.resolution_x, scene.render.resolution_y = W, H
    tmp = os.path.join(folder, "_tmp.png")
    rows = []

    def shot(pos, target, ortho):
        pos, target = Vector(pos), Vector(target)
        fwd = (target - pos).normalized()
        up = Vector((0, 1, 0)) if abs(fwd.z) > 0.99 else Vector((0, 0, 1))
        right = fwd.cross(up).normalized()
        upv = right.cross(fwd).normalized()
        m = Matrix((right, upv, -fwd)).transposed().to_4x4()
        m.translation = pos
        cam.matrix_world = m
        cam.data.type = "ORTHO" if ortho else "PERSP"
        cam.data.ortho_scale = ortho or 1.0
        cam.data.lens = 40
        cam.data.clip_end = 100
        scene.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        a = np.empty(W * H * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        bpy.data.images.remove(img)
        return a.reshape(H, W, 4)
    for act, n, loop in actions:
        arm.animation_data.action = act
        if getattr(arm.animation_data, "action_slot", None) is None and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        picks = [int(round(k * n / (6.0 if loop else 5.0))) for k in range(6)]
        side, top = [], []
        for f in picks:
            scene.frame_set(f)
            side.append(shot((L * 2.5, 0, 0.2), (0, 0, 0), L * 1.25))
            top.append(shot((L * 0.9, -L * 0.9, L * 0.9), (0, 0, 0), None))
        rows.append((act.name, side, top))
    pad = 4
    out = np.zeros((len(rows) * 2 * (H + pad) + pad, 6 * (W + pad) + pad, 4), dtype=np.float32)
    out[..., 3] = 1
    for g, (name, side, top) in enumerate(rows):
        for r, tiles in enumerate((side, top)):
            for c, tile in enumerate(tiles):
                y = pad + (g * 2 + r) * (H + pad)
                x = pad + c * (W + pad)
                out[out.shape[0] - y - H:out.shape[0] - y, x:x + W] = tile
    img = bpy.data.images.new("sheet", out.shape[1], out.shape[0], alpha=True)
    img.pixels.foreach_set(out.reshape(-1))
    img.filepath_raw = os.path.join(folder, "%s_clips.png" % OPT["name"])
    img.file_format = "PNG"
    img.save()
    if os.path.exists(tmp):
        os.remove(tmp)
    log("review:", img.filepath_raw)


def main():
    parse()
    obj, axis, L = load_body()
    material(obj)
    arm, jaw_pts, hinge = build(obj, axis)
    weigh(obj, arm, axis, jaw_pts, L)
    bpy.context.scene.render.fps = FPS
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    made = []
    for name, fn, seconds, loop in CLIPS:
        act, n = bake(arm, name, fn, seconds, loop)
        made.append((act, n, loop))
    if OPT["review"]:
        review(arm, obj, made, L, OPT["review"])
    stash(arm, [m[0] for m in made])
    bpy.context.scene.frame_set(0)
    if OPT["out"]:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.export_scene.gltf(
            filepath=os.path.abspath(OPT["out"]), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
            export_texcoords=True, export_normals=True, export_tangents=True, export_materials="EXPORT",
            export_image_format="JPEG", export_image_quality=90,
            export_skins=True, export_def_bones=False, export_all_influences=False, export_influence_nb=4,
            export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_range=False,
            export_anim_slide_to_zero=True, export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=True,
            export_morph=False, export_cameras=False, export_lights=False)
        log("exported", OPT["out"], "%.2f MB" % (os.path.getsize(os.path.abspath(OPT["out"])) / 1e6))
    log("SHARK_DONE")


if __name__ == "__main__":
    main()
