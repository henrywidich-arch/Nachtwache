"""The end boss of mission two ("Subjekt Null"): skeleton, skin and every clip, written by script.

SUPERSEDED (2026-10-26): the game now uses Mixamo's rig and motions, see tools/blender_mixamo_boss.py.

The source is Meshy's static model (biomech_mutant_boss_3: 3.7 million triangles, no skeleton, A-pose).
It is reduced once (kept in --work as boss_base.blend), stood on the origin, given a humanoid skeleton,
skinned (bone heat on a watertight voxel proxy, carried back to the real surface) and animated: the trunk
and arms by hand-written curves, the legs by two-bone IK towards foot targets so that a standing foot
does not slide. One GLB comes out.

  blender --background --factory-startup --python tools/blender_rig_boss.py -- \
      --src "D:/Games/AI Games/Nachtwache/tokyo/Meshy_AI_biomech_mutant_boss_3_1025214907_image-to-3d-texture.glb" \
      --out assets/models/boss_mutant.glb [--work <folder>] [--review <folder>] [--tris 60000] [--tex 2048]

Blender space: the boss looks along -Y, his left is +X, Z is up (glTF/Godot: +Z forward, Y up).
Model units: he is 1.9 m tall in the file; the game scales him (scripts/boss_visual.gd, BOSS_SCALE).
Ground speeds of the gaits in model units: walk 1.1 m/s, sprint 3.6 m/s (boss_visual.gd has the same numbers).
"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Quaternion, Matrix
from mathutils.bvhtree import BVHTree

FPS = 30
OPT = {"src": None, "out": None, "work": None, "review": None, "tris": "60000", "tex": "2048", "only": None}
WALK_SPEED = 1.1
SPRINT_SPEED = 3.6


def log(*a):
    print("[boss]", *a)
    sys.stdout.flush()


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    i = 0
    while i < len(argv):
        k = argv[i].lstrip("-")
        if k in OPT and i + 1 < len(argv):
            OPT[k] = argv[i + 1]
            i += 2
        else:
            i += 1


# ------------------------------------------------------------------------------------------------ the model
def prepare():
    work = OPT["work"]
    base = os.path.join(work, "boss_base.blend") if work else None
    if base and os.path.exists(base):
        bpy.ops.wm.open_mainfile(filepath=base)
        obj = next(o for o in bpy.data.objects if o.type == "MESH")
        log("reduced model from", base)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=OPT["src"])
        obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for o in list(bpy.data.objects):
            if o != obj:
                bpy.data.objects.remove(o, do_unlink=True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.0005)
        bpy.ops.object.mode_set(mode="OBJECT")
        me = obj.data
        count = sum(len(p.vertices) - 2 for p in me.polygons)
        tris = int(OPT["tris"])
        if count > tris:
            mod = obj.modifiers.new("reduce", "DECIMATE")
            mod.ratio = tris / float(count)
            bpy.ops.object.modifier_apply(modifier="reduce")
        try:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        except Exception as e:
            log("normals:", e)
        bpy.ops.object.shade_smooth()
        tex = int(OPT["tex"])
        for img in bpy.data.images:
            if img.size[0] > tex:
                img.scale(tex, tex)
            img.pack()
        if base:
            bpy.ops.wm.save_as_mainfile(filepath=base)
    me = obj.data
    # stand him on the origin
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    low = co[:, 2].min()
    co[:, 2] -= low
    co[:, 0] -= (co[:, 0].max() + co[:, 0].min()) * 0.5
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    obj.name = "Boss"
    me.name = "Boss"
    for m in me.materials:
        if m:
            m.name = "boss"
    log("mesh %d triangles, %d vertices, height %.3f" % (sum(len(p.vertices) - 2 for p in me.polygons), len(me.vertices), co[:, 2].max()))
    return obj


# ------------------------------------------------------------------------------------------------ the skeleton
# Joint positions measured on the reduced mesh (front and side orthographic renders), feet at z = 0.
J = {
    "root": (0, 0, 0), "root_end": (0, 0, 0.25),
    "hips": (0, 0.02, 1.13), "spine": (0, 0.02, 1.30), "chest": (0, 0.03, 1.46), "neck": (0, 0.03, 1.64),
    "head": (0, 0.0, 1.71), "head_end": (0, -0.06, 1.90),
}
for s, x in (("L", 1.0), ("R", -1.0)):
    J.update({
        "clav." + s: (0.07 * x, 0.03, 1.59), "shoulder." + s: (0.28 * x, 0.04, 1.58),
        "elbow." + s: (0.49 * x, 0.02, 1.31), "wrist." + s: (0.665 * x, -0.07, 1.06),
        "fingers." + s: (0.72 * x, -0.15, 0.88),
        "hip." + s: (0.125 * x, 0.02, 1.10), "knee." + s: (0.19 * x, -0.01, 0.64),
        "ankle." + s: (0.21 * x, 0.04, 0.19), "ball." + s: (0.21 * x, -0.15, 0.05), "toe." + s: (0.21 * x, -0.25, 0.04),
    })
BONES = [
    ("root", None, "root", "root_end"),
    ("hips", "root", "hips", "spine"),
    ("spine", "hips", "spine", "chest"),
    ("chest", "spine", "chest", "neck"),
    ("neck", "chest", "neck", "head"),
    ("head", "neck", "head", "head_end"),
]
for s in ("L", "R"):
    BONES += [
        ("clavicle." + s, "chest", "clav." + s, "shoulder." + s),
        ("upperarm." + s, "clavicle." + s, "shoulder." + s, "elbow." + s),
        ("forearm." + s, "upperarm." + s, "elbow." + s, "wrist." + s),
        ("hand." + s, "forearm." + s, "wrist." + s, "fingers." + s),
        ("thigh." + s, "hips", "hip." + s, "knee." + s),
        ("shin." + s, "thigh." + s, "knee." + s, "ankle." + s),
        ("foot." + s, "shin." + s, "ankle." + s, "ball." + s),
        ("toes." + s, "foot." + s, "ball." + s, "toe." + s),
    ]
NAMES = [b[0] for b in BONES]
PARENT = {b[0]: b[1] for b in BONES}
HEAD = {b[0]: Vector(J[b[2]]) for b in BONES}
TAIL = {b[0]: Vector(J[b[3]]) for b in BONES}
DEFORM = [n for n in NAMES if n != "root"]


def build_armature():
    ad = bpy.data.armatures.new("BossRig")
    arm = bpy.data.objects.new("BossRig", ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, h, t in BONES:
        eb = ad.edit_bones.new(name)
        eb.head = J[h]
        eb.tail = J[t]
        # roll: every bone's Z axis points forward (-Y) or up for the forward-pointing foot bones
        d = (Vector(J[t]) - Vector(J[h])).normalized()
        up = Vector((0, -1, 0)) if abs(d.y) < 0.7 else Vector((0, 0, 1))
        eb.align_roll(up)
        if parent:
            eb.parent = ad.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


# ------------------------------------------------------------------------------------------------ skin
def read_groups(obj):
    me = obj.data
    idx = {vg.index: DEFORM.index(vg.name) for vg in obj.vertex_groups if vg.name in DEFORM}
    W = np.zeros((len(me.vertices), len(DEFORM)))
    for v in me.vertices:
        for g in v.groups:
            if g.group in idx:
                W[v.index, idx[g.group]] = g.weight
    return W


def smooth_weights(me, W, iterations, factor):
    n = len(me.vertices)
    e = np.zeros(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    deg = np.zeros(n)
    np.add.at(deg, e[:, 0], 1.0)
    np.add.at(deg, e[:, 1], 1.0)
    deg = np.maximum(deg, 1.0)
    for _ in range(iterations):
        acc = np.zeros_like(W)
        np.add.at(acc, e[:, 0], W[e[:, 1]])
        np.add.at(acc, e[:, 1], W[e[:, 0]])
        W = W * (1.0 - factor) + acc / deg[:, None] * factor
    return W


def distance_weights(co):
    W = np.zeros((len(co), len(DEFORM)))
    for j, name in enumerate(DEFORM):
        a = np.array(HEAD[name])
        b = np.array(TAIL[name])
        ab = b - a
        t = np.clip(((co - a) @ ab) / (ab @ ab), 0.0, 1.0)
        d = np.linalg.norm(co - (a + t[:, None] * ab), axis=1)
        W[:, j] = 1.0 / (d + 0.015) ** 4
    return W / W.sum(axis=1, keepdims=True)


def skin(obj, arm):
    me = obj.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    # bone heat on a watertight voxel copy: the generated surface has holes and loose plates
    proxy = bpy.data.objects.new("proxy", me.copy())
    bpy.context.scene.collection.objects.link(proxy)
    bpy.ops.object.select_all(action="DESELECT")
    proxy.select_set(True)
    bpy.context.view_layer.objects.active = proxy
    mod = proxy.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = 0.014
    bpy.ops.object.modifier_apply(modifier=mod.name)
    dec = proxy.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, 80000.0 / max(1, len(proxy.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    W = None
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        Wp = read_groups(proxy)
        empty = int((Wp.sum(axis=1) < 1e-6).sum())
        log("bone heat on proxy: %d verts, %d without weights" % (len(Wp), empty))
        if empty < 0.02 * len(Wp):
            pm = proxy.data
            pm.calc_loop_triangles()
            tris = [tuple(t.vertices) for t in pm.loop_triangles]
            pco = [v.co.copy() for v in pm.vertices]
            bvh = BVHTree.FromPolygons(pco, tris)
            W = np.zeros((len(co), len(DEFORM)))
            for vi in range(len(co)):
                loc, nrm, ti, dist = bvh.find_nearest(Vector(co[vi]))
                a, b, c = tris[ti]
                W[vi] = (Wp[a] + Wp[b] + Wp[c]) / 3.0
    except Exception as e:
        log("bone heat failed:", e)
    bpy.data.objects.remove(proxy, do_unlink=True)
    D = distance_weights(co)
    if W is None:
        log("weights: distance based")
        W = D
    else:
        log("weights: bone heat on voxel proxy")
        lost = W.sum(axis=1) < 0.5
        W[lost] = D[lost]
    # the legs must not pull the crotch plates and the arms must not pull the flanks
    col = {n: k for k, n in enumerate(DEFORM)}
    for s, sign in (("L", 1.0), ("R", -1.0)):
        side = co[:, 0] * sign
        for b in ("thigh.", "shin.", "foot.", "toes."):
            W[side < -0.02, col[b + s]] = 0.0
        for b in ("upperarm.", "forearm.", "hand."):
            W[side < 0.12, col[b + s]] = 0.0
        # below the knee only the leg of this side
        W[(co[:, 2] < 0.62) & (side > 0.02)] *= np.array([1.0 if n.endswith("." + s) and n.split(".")[0] in ("shin", "foot", "toes", "thigh") else 0.0 for n in DEFORM])
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
    W = smooth_weights(me, W, 3, 0.5)
    order = np.argsort(-W, axis=1)
    keep = np.zeros_like(W, dtype=bool)
    np.put_along_axis(keep, order[:, :4], True, axis=1)
    W = np.where(keep & (W > 0.01), W, 0.0)
    bad = W.sum(axis=1) < 1e-6
    W[bad] = D[bad]
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
    obj.vertex_groups.clear()
    for j, name in enumerate(DEFORM):
        vg = obj.vertex_groups.new(name=name)
        idx = np.nonzero(W[:, j] > 0.0)[0]
        for vi in idx:
            vg.add([int(vi)], float(W[vi, j]), "REPLACE")
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    obj.matrix_parent_inverse = Matrix.Identity(4)
    log("skinned: max %d influences" % (W > 0).sum(axis=1).max())


# ------------------------------------------------------------------------------------------------ pose maths
def q_axis(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


def rx(d):
    return q_axis((1, 0, 0), d)


def ry(d):
    return q_axis((0, 1, 0), d)


def rz(d):
    return q_axis((0, 0, 1), d)


def pyr(pitch=0.0, yaw=0.0, roll=0.0):
    """pitch > 0 bends forward, yaw > 0 turns to his left, roll > 0 leans to his left."""
    return rz(yaw) @ rx(pitch) @ ry(roll)


def swing(a, b):
    a = a.normalized()
    b = b.normalized()
    return a.rotation_difference(b)


def frame(y, z):
    y = y.normalized()
    x = y.cross(z)
    if x.length < 1e-6:
        x = y.cross(Vector((0, 0, 1)) if abs(y.z) < 0.9 else Vector((1, 0, 0)))
    x.normalize()
    z = x.cross(y).normalized()
    return Matrix((x, y, z)).transposed()


class Pose:
    def __init__(self):
        self.hips = Vector((0, 0, 0))       # offset of the hips joint
        self.rot = {}                       # trunk, neck, head: delta in parent axes
        self.arm = {}                       # side -> dict(upper=dir, fore=dir, hand=quat, clav=quat), in chest axes
        self.foot = {}                      # side -> world position of the ankle
        self.foot_rot = {}                  # side -> world rotation of the foot
        self.toe = {}                       # side -> toe bend (deg, > 0 bends up)
        self.knee_out = {}                  # side -> how far the knee points outwards (deg)

    def r(self, name, q):
        self.rot[name] = (self.rot.get(name) or Quaternion()) @ q


class Rig:
    def __init__(self, arm):
        self.arm = arm
        self.rest = {}
        self.restq = {}
        for b in arm.data.bones:
            self.rest[b.name] = b.matrix_local.copy()
            self.restq[b.name] = b.matrix_local.to_quaternion()
        self.order = NAMES
        self.over = 0.0

    def solve(self, P):
        Q = {}
        pos = {}
        Q["root"] = Quaternion()
        pos["root"] = HEAD["root"].copy()
        Q["hips"] = P.rot.get("hips", Quaternion())
        pos["hips"] = HEAD["hips"] + P.hips
        for b in ("spine", "chest", "neck", "head"):
            p = PARENT[b]
            pos[b] = pos[p] + Q[p] @ (HEAD[b] - HEAD[p])
            Q[b] = Q[p] @ P.rot.get(b, Quaternion())
        for s in ("L", "R"):
            A = P.arm.get(s, {})
            c = "clavicle." + s
            pos[c] = pos["chest"] + Q["chest"] @ (HEAD[c] - HEAD["chest"])
            Q[c] = Q["chest"] @ A.get("clav", Quaternion())
            u = "upperarm." + s
            pos[u] = pos[c] + Q[c] @ (HEAD[u] - HEAD[c])
            rest_dir = Q[c] @ (TAIL[u] - HEAD[u])
            want = Q["chest"] @ A["upper"] if "upper" in A else rest_dir
            Q[u] = swing(rest_dir, want) @ Q[c]
            f = "forearm." + s
            pos[f] = pos[u] + Q[u] @ (HEAD[f] - HEAD[u])
            rest_dir = Q[u] @ (TAIL[f] - HEAD[f])
            want = Q["chest"] @ A["fore"] if "fore" in A else rest_dir
            Q[f] = swing(rest_dir, want) @ Q[u]
            h = "hand." + s
            pos[h] = pos[f] + Q[f] @ (HEAD[h] - HEAD[f])
            Q[h] = Q[f] @ A.get("hand", Quaternion())
            # leg: two-bone IK from the hip joint to the ankle target
            t = "thigh." + s
            sh = "shin." + s
            ft = "foot." + s
            pos[t] = pos["hips"] + Q["hips"] @ (HEAD[t] - HEAD["hips"])
            l1 = (HEAD[sh] - HEAD[t]).length
            l2 = (HEAD[ft] - HEAD[sh]).length
            target = P.foot.get(s, HEAD[ft].copy())
            d = target - pos[t]
            dist = d.length
            reach = (l1 + l2) * 0.999
            if dist > reach:
                self.over = max(self.over, dist - reach)
                d = d.normalized() * reach
                dist = reach
            dist = max(dist, abs(l1 - l2) + 0.01)
            dn = d.normalized()
            # the knee points forward along the hips' heading, a little outwards
            sign = 1.0 if s == "L" else -1.0
            fwd = Q["hips"] @ Vector((0, -1, 0))
            fwd = rz(sign * P.knee_out.get(s, 8.0)) @ fwd
            pole = (fwd - dn * fwd.dot(dn)).normalized()
            cos_a = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
            a = math.acos(max(-1.0, min(1.0, cos_a)))
            knee = pos[t] + dn * (l1 * math.cos(a)) + pole * (l1 * math.sin(a))
            pos[sh] = knee
            # orientation frames: bone axis along the limb, Z towards the pole (as at rest, near straight)
            rest_pole = Vector((0, -1, 0))
            r_t = frame(HEAD[sh] - HEAD[t], rest_pole)
            n_t = frame(knee - pos[t], pole)
            Q[t] = (n_t @ r_t.inverted()).to_quaternion()
            r_s = frame(HEAD[ft] - HEAD[sh], rest_pole)
            n_s = frame(pos[t] + d - knee, pole)
            Q[sh] = (n_s @ r_s.inverted()).to_quaternion()
            pos[ft] = pos[t] + d
            Q[ft] = P.foot_rot.get(s, Quaternion())
            to = "toes." + s
            pos[to] = pos[ft] + Q[ft] @ (HEAD[to] - HEAD[ft])
            Q[to] = Q[ft] @ rx(-P.toe.get(s, 0.0))
        return Q, pos

    def basis(self, Q, pos):
        rot = {}
        loc = Vector()
        for b in self.order:
            p = PARENT[b]
            qp = Q[p] if p else Quaternion()
            d = qp.inverted() @ Q[b]
            r = self.restq[b]
            rot[b] = r.inverted() @ d @ r
        # hips translation in its parent's (root) rest frame: root is at rest, so armature offset -> hips local
        off = pos["hips"] - HEAD["hips"]
        loc = self.restq["hips"].inverted() @ off
        return rot, loc


# ------------------------------------------------------------------------------------------------ curves
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def sm(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def ramp(t, a, b):
    return sm((t - a) / (b - a)) if b > a else (1.0 if t >= a else 0.0)


def bump(t, a, b):
    """0 -> 1 -> 0 between a and b."""
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a)) ** 2


def key(t, pts):
    """Smooth curve through (time, value) points."""
    if t <= pts[0][0]:
        return pts[0][1]
    for i in range(len(pts) - 1):
        t0, v0 = pts[i]
        t1, v1 = pts[i + 1]
        if t <= t1:
            return v0 + (v1 - v0) * sm((t - t0) / (t1 - t0))
    return pts[-1][1]


def V(x=0.0, y=0.0, z=0.0):
    return Vector((x, y, z))


def lerpv(a, b, t):
    return a.lerp(b, clamp(t))


def stand(P, s, x=0.0, y=0.0, z=0.0, pitch=0.0, yaw=0.0):
    sign = 1.0 if s == "L" else -1.0
    P.foot[s] = HEAD["foot." + s] + V(x * sign, y, z)
    P.foot_rot[s] = rz(yaw * sign) @ rx(-pitch)


ARM_REST = {s: ((TAIL["upperarm." + s] - HEAD["upperarm." + s]).normalized(), (TAIL["forearm." + s] - HEAD["forearm." + s]).normalized()) for s in ("L", "R")}


def arm_dir(s, out, fwd, up):
    """A direction in chest axes, mirrored for the right side: out = to his side, fwd = forward, up = up."""
    sign = 1.0 if s == "L" else -1.0
    return V(out * sign, -fwd, up).normalized()


def set_arm(P, s, upper, fore, hand=None, clav=None):
    P.arm[s] = {"upper": upper, "fore": fore}
    if hand is not None:
        P.arm[s]["hand"] = hand
    if clav is not None:
        P.arm[s]["clav"] = clav


def hang(P, s, swing_fwd=0.0, bend=25.0, out=0.0, lift=0.0):
    """A heavy arm hanging from the shoulder: swing_fwd in degrees, bend at the elbow."""
    sign = 1.0 if s == "L" else -1.0
    up0, fo0 = ARM_REST[s]
    q = rx(-swing_fwd) @ ry(-sign * out)
    u = q @ up0
    f = q @ (rx(-bend) @ fo0)
    set_arm(P, s, u, f, clav=rx(0) @ ry(sign * lift))


def base_stance(P, crouch=0.04, lean=8.0):
    P.hips = V(0, 0.02, -crouch)
    P.r("hips", pyr(pitch=lean * 0.4))
    P.r("spine", pyr(pitch=lean * 0.3))
    P.r("chest", pyr(pitch=lean * 0.3))
    P.r("neck", pyr(pitch=-lean * 0.4))
    P.r("head", pyr(pitch=-lean * 0.3))
    for s in ("L", "R"):
        stand(P, s, 0.03, 0.0)
        hang(P, s, swing_fwd=6.0, bend=22.0, out=4.0)


# ------------------------------------------------------------------------------------------------ the clips
def clip_idle(P, u):
    w = 2 * math.pi * u
    breathe = math.sin(w)
    base_stance(P, crouch=0.05 + 0.008 * breathe, lean=9.0)
    P.r("chest", pyr(pitch=-1.5 * breathe, yaw=1.5 * math.sin(w + 1.0)))
    P.r("neck", pyr(yaw=4.0 * math.sin(w * 1.0 + 0.5), roll=2.0 * math.sin(w)))
    P.r("head", pyr(pitch=2.0 * math.sin(2 * w), yaw=6.0 * math.sin(w + 2.0)))
    for s, ph in (("L", 0.0), ("R", 1.3)):
        hang(P, s, swing_fwd=6.0 + 3.0 * math.sin(w + ph), bend=22.0 + 6.0 * math.sin(w + ph + 0.6), out=4.0 + 2.0 * breathe, lift=2.5 * breathe)


def gait(P, u, speed, period, duty, lift, stride_scale=1.0, sprint=False):
    """Feet on targets: stance slides back with the ground, swing arcs forward."""
    stride = speed * period * duty * stride_scale
    for s, phase in (("L", 0.0), ("R", 0.5)):
        p = (u + phase) % 1.0
        if p < duty:                                   # on the ground
            k = p / duty
            y = -stride * 0.5 + stride * k             # moves backwards (+Y)
            z = 0.0
            pitch = 0.0
            if k > 0.75:                               # heel comes up, toe stays
                pitch = -25.0 * ramp(k, 0.75, 1.0) * (1.4 if sprint else 1.0)
                z = 0.10 * ramp(k, 0.75, 1.0) * (1.4 if sprint else 1.0)
            toe = -pitch
        else:                                          # in the air
            k = (p - duty) / (1.0 - duty)
            y = stride * 0.5 - stride * sm(k)
            z = lift * math.sin(math.pi * k) ** 1.2 + 0.1 * (1 - ramp(k, 0.0, 0.3)) * (1.4 if sprint else 1.0)
            pitch = -25.0 * (1 - ramp(k, 0.0, 0.4)) + 12.0 * bump(k, 0.4, 1.0)
            toe = 10.0 * (1 - ramp(k, 0.0, 0.5))
        stand(P, s, 0.04, y, z, pitch=pitch)
        P.toe[s] = toe


def clip_walk(P, u):
    w = 2 * math.pi * u
    P.hips = V(0, 0.02, -0.07 + 0.035 * math.cos(2 * w))
    P.hips.x = 0.035 * math.sin(w)
    P.r("hips", pyr(pitch=5.0, yaw=-7.0 * math.sin(w), roll=-4.0 * math.sin(w)))
    P.r("spine", pyr(pitch=4.0, yaw=4.0 * math.sin(w), roll=2.0 * math.sin(w)))
    P.r("chest", pyr(pitch=5.0 + 2.0 * math.cos(2 * w), yaw=6.0 * math.sin(w), roll=2.0 * math.sin(w)))
    P.r("neck", pyr(pitch=-4.0, yaw=-4.0 * math.sin(w)))
    P.r("head", pyr(pitch=-3.0 - 2.0 * math.cos(2 * w), yaw=-2.0 * math.sin(w)))
    gait(P, u, WALK_SPEED, 1.1, 0.62, 0.17)
    # arms swing against the legs (left leg forward at u = 0.25 .. -> right arm forward)
    for s, ph in (("L", math.pi), ("R", 0.0)):
        sw = math.sin(w + ph + 0.4)
        hang(P, s, swing_fwd=8.0 + 22.0 * sw, bend=24.0 + 14.0 * max(0.0, sw), out=6.0)


def clip_sprint(P, u):
    w = 2 * math.pi * u
    P.hips = V(0, 0.0, -0.12 + 0.06 * math.cos(2 * w + 0.6))
    P.hips.x = 0.03 * math.sin(w)
    P.r("hips", pyr(pitch=16.0, yaw=-10.0 * math.sin(w), roll=-4.0 * math.sin(w)))
    P.r("spine", pyr(pitch=10.0, yaw=6.0 * math.sin(w)))
    P.r("chest", pyr(pitch=10.0 + 3.0 * math.cos(2 * w), yaw=9.0 * math.sin(w), roll=3.0 * math.sin(w)))
    P.r("neck", pyr(pitch=-14.0))
    P.r("head", pyr(pitch=-12.0 + 3.0 * math.cos(2 * w)))
    gait(P, u, SPRINT_SPEED, 0.62, 0.40, 0.32, sprint=True)
    for s, ph in (("L", math.pi), ("R", 0.0)):
        sw = math.sin(w + ph + 0.3)
        hang(P, s, swing_fwd=15.0 + 48.0 * sw, bend=55.0 + 30.0 * max(0.0, sw), out=10.0)


def clip_rush_wind(P, t):
    """0.9 s: drops low, roars at the target, digs the feet in; ends ready to sprint."""
    k = ramp(t, 0.0, 0.35)
    shake = math.sin(t * 60.0) * bump(t, 0.3, 0.85)
    base_stance(P, crouch=0.05 + 0.20 * k, lean=9.0 + 18.0 * k)
    P.r("chest", pyr(pitch=6.0 * k + 1.5 * shake, roll=1.5 * shake))
    P.r("neck", pyr(pitch=-14.0 * k))
    P.r("head", pyr(pitch=-10.0 * k + 3.0 * shake))
    stand(P, "L", 0.06, -0.22 * k, 0.0)
    stand(P, "R", 0.06, 0.24 * k, 0.04 * k, pitch=-28.0 * k)
    P.toe["R"] = 28.0 * k
    for s in ("L", "R"):
        hang(P, s, swing_fwd=6.0 - 34.0 * k, bend=22.0 + 40.0 * k, out=4.0 + 18.0 * k, lift=10.0 * k)


def clip_punch(P, t):
    """1.2 s: the right arm swings up behind his head and hammers down in front; impact at 0.55 s."""
    up = ramp(t, 0.0, 0.40) * (1 - ramp(t, 0.48, 0.58))
    hit = ramp(t, 0.45, 0.58) * (1 - ramp(t, 0.8, 1.2))
    base_stance(P, crouch=0.05 + 0.13 * hit, lean=9.0)
    P.r("hips", pyr(yaw=14.0 * up - 16.0 * hit, pitch=8.0 * hit))
    P.r("spine", pyr(pitch=-8.0 * up + 14.0 * hit, yaw=10.0 * up - 10.0 * hit))
    P.r("chest", pyr(pitch=-6.0 * up + 16.0 * hit, yaw=12.0 * up - 12.0 * hit, roll=-6.0 * up + 4.0 * hit))
    P.r("neck", pyr(pitch=-8.0 * hit))
    stand(P, "L", 0.05, -0.18 * max(up, hit), 0.0)
    stand(P, "R", 0.05, 0.10 * max(up, hit), 0.0)
    # right arm: raised high behind -> down in front
    upper_up = arm_dir("R", 0.15, -0.15, 1.0)
    fore_up = arm_dir("R", 0.1, -0.7, 0.5)
    upper_hit = arm_dir("R", 0.15, 1.0, -0.55)
    fore_hit = arm_dir("R", 0.05, 0.6, -1.0)
    up0, fo0 = ARM_REST["R"]
    a = up0.lerp(upper_up, up).lerp(upper_hit, hit).normalized()
    b = fo0.lerp(fore_up, up).lerp(fore_hit, hit).normalized()
    set_arm(P, "R", a, b, clav=ry(-12.0 * up))
    hang(P, "L", swing_fwd=-10.0 * up + 20.0 * hit, bend=30.0 + 20.0 * up, out=14.0 * up)


def clip_throw(P, t):
    """1.5 s: reaches down with both hands (0 .. 0.45), heaves up over the head (.. 0.85), hurls forward, release at 0.98 s."""
    down = ramp(t, 0.0, 0.40) * (1 - ramp(t, 0.45, 0.80))
    over = ramp(t, 0.45, 0.82) * (1 - ramp(t, 0.86, 1.02))
    out = ramp(t, 0.86, 1.02) * (1 - ramp(t, 1.15, 1.5))
    base_stance(P, crouch=0.05 + 0.32 * down + 0.06 * out, lean=9.0)
    P.r("hips", pyr(pitch=30.0 * down - 6.0 * over + 10.0 * out))
    P.r("spine", pyr(pitch=22.0 * down - 14.0 * over + 16.0 * out))
    P.r("chest", pyr(pitch=12.0 * down - 12.0 * over + 14.0 * out))
    P.r("neck", pyr(pitch=-20.0 * down + 6.0 * over - 6.0 * out))
    P.r("head", pyr(pitch=-10.0 * down))
    stand(P, "L", 0.10 * down + 0.05, -0.20 * out, 0.0)
    stand(P, "R", 0.10 * down + 0.05, 0.12 * out + 0.06 * down, 0.0)
    for s in ("L", "R"):
        up0, fo0 = ARM_REST[s]
        u_down = arm_dir(s, 0.25, 0.6, -1.0)
        f_down = arm_dir(s, -0.1, 0.4, -1.0)
        u_over = arm_dir(s, 0.25, -0.25, 1.0)
        f_over = arm_dir(s, -0.45, -0.3, 0.6)
        u_out = arm_dir(s, 0.25, 1.0, 0.25)
        f_out = arm_dir(s, -0.05, 1.0, 0.0)
        a = up0.lerp(u_down, down).lerp(u_over, over).lerp(u_out, out).normalized()
        b = fo0.lerp(f_down, down).lerp(f_over, over).lerp(f_out, out).normalized()
        set_arm(P, s, a, b)


def clip_stomp(P, t):
    """1.4 s: the right leg comes up high, the whole weight slams it down at 0.62 s, both fists clenched."""
    lift = ramp(t, 0.05, 0.48) * (1 - ramp(t, 0.52, 0.62))
    slam = ramp(t, 0.55, 0.64) * (1 - ramp(t, 0.95, 1.4))
    base_stance(P, crouch=0.06 + 0.06 * lift + 0.20 * slam, lean=9.0)
    P.hips.x += -0.06 * lift
    P.r("hips", pyr(roll=-6.0 * lift, pitch=6.0 * slam))
    P.r("spine", pyr(pitch=-10.0 * lift + 14.0 * slam, roll=4.0 * lift))
    P.r("chest", pyr(pitch=-8.0 * lift + 12.0 * slam))
    P.r("neck", pyr(pitch=-6.0 * slam))
    stand(P, "L", 0.03, 0.0, 0.0)
    stand(P, "R", 0.06, -0.20 * lift - 0.05 * slam, 0.55 * lift, pitch=10.0 * lift)
    for s in ("L", "R"):
        hang(P, s, swing_fwd=-10.0 * lift + 30.0 * slam, bend=60.0 * lift + 35.0 * slam + 20.0, out=25.0 * lift + 20.0 * slam, lift=15.0 * lift)


def clip_roar(P, t):
    """2.2 s: straightens up, throws the arms wide and the head back, roars with a shaking chest."""
    up = ramp(t, 0.0, 0.5) * (1 - ramp(t, 1.75, 2.2))
    shake = math.sin(t * 55.0) * bump(t, 0.45, 1.8)
    base_stance(P, crouch=0.05 + 0.05 * up, lean=9.0 - 14.0 * up)
    P.r("spine", pyr(pitch=-6.0 * up))
    P.r("chest", pyr(pitch=-10.0 * up + 1.5 * shake, roll=1.2 * shake))
    P.r("neck", pyr(pitch=-14.0 * up))
    P.r("head", pyr(pitch=-16.0 * up + 3.0 * shake, yaw=2.0 * shake))
    stand(P, "L", 0.03 + 0.08 * up, -0.05 * up, 0.0)
    stand(P, "R", 0.03 + 0.08 * up, 0.08 * up, 0.0)
    for s in ("L", "R"):
        up0, fo0 = ARM_REST[s]
        u = arm_dir(s, 1.0, 0.05, 0.25)
        f = arm_dir(s, 0.55, 0.3, 0.75)
        set_arm(P, s, up0.lerp(u, up).normalized(), fo0.lerp(f, up).normalized(), clav=ry((1 if s == "L" else -1) * 14.0 * up))


def clip_laser(P, t):
    """2.6 s: charges (0 .. 0.55), the eyes fire and the head and trunk sweep from his right to his left (0.6 .. 2.1)."""
    charge = ramp(t, 0.0, 0.5) * (1 - ramp(t, 2.1, 2.6))
    sweep = key(t, [(0.0, 0.0), (0.6, -38.0), (2.1, 38.0), (2.6, 0.0)])
    shake = math.sin(t * 70.0) * bump(t, 0.55, 2.15) * 0.6
    base_stance(P, crouch=0.05 + 0.08 * charge, lean=9.0 - 4.0 * charge)
    P.r("hips", pyr(yaw=0.25 * sweep))
    P.r("spine", pyr(yaw=0.25 * sweep))
    P.r("chest", pyr(yaw=0.25 * sweep, pitch=-4.0 * charge + shake))
    P.r("neck", pyr(yaw=0.15 * sweep, pitch=4.0 * charge))
    P.r("head", pyr(yaw=0.10 * sweep, pitch=6.0 * charge + shake))
    stand(P, "L", 0.10 * charge + 0.03, -0.06 * charge, 0.0)
    stand(P, "R", 0.10 * charge + 0.03, 0.06 * charge, 0.0)
    for s in ("L", "R"):
        hang(P, s, swing_fwd=-12.0 * charge, bend=22.0 + 45.0 * charge, out=4.0 + 28.0 * charge, lift=12.0 * charge)


def clip_hit(P, t):
    """0.5 s: a heavy flinch backwards."""
    k = bump(t, 0.0, 0.5)
    base_stance(P, crouch=0.05 + 0.04 * k, lean=9.0)
    P.r("spine", pyr(pitch=-8.0 * k, roll=3.0 * k))
    P.r("chest", pyr(pitch=-10.0 * k, yaw=6.0 * k))
    P.r("neck", pyr(pitch=-10.0 * k))
    P.r("head", pyr(pitch=-12.0 * k, roll=-6.0 * k))
    for s in ("L", "R"):
        hang(P, s, swing_fwd=-15.0 * k, bend=22.0 + 25.0 * k, out=4.0 + 14.0 * k)


def clip_death(P, t):
    """3.2 s: staggers, drops to the knees (1.1 s), topples forward onto the chest (2.1 s), lies still."""
    stag = bump(t, 0.0, 0.8)
    knees = ramp(t, 0.55, 1.15)
    fall = ramp(t, 1.45, 2.1)
    settle = bump(t, 2.05, 2.5)
    base_stance(P, crouch=0.05, lean=9.0)
    P.hips = V(0, 0.02 + 0.10 * stag + 0.12 * knees - 0.35 * fall, -0.05 - 0.55 * knees - 0.42 * fall + 0.04 * settle)
    P.r("hips", pyr(pitch=-10.0 * stag + 10.0 * knees + 60.0 * fall, roll=5.0 * stag))
    P.r("spine", pyr(pitch=-10.0 * stag + 18.0 * knees + 10.0 * fall))
    P.r("chest", pyr(pitch=-12.0 * stag + 10.0 * knees + 6.0 * fall, yaw=8.0 * stag))
    P.r("neck", pyr(pitch=-18.0 * stag - 10.0 * fall))
    P.r("head", pyr(pitch=-14.0 * stag + 20.0 * knees - 25.0 * fall, roll=12.0 * fall))
    # feet: the toes stay, the ankles lie down behind the knees
    for s in ("L", "R"):
        back = 0.10 * stag if s == "R" else 0.0
        stand(P, s, 0.05 + 0.05 * knees, back + 0.30 * knees + 0.15 * fall, 0.0 + 0.04 * knees, pitch=-70.0 * knees - 10.0 * fall)
        P.toe[s] = 50.0 * knees
        P.knee_out[s] = 12.0
        up0, fo0 = ARM_REST[s]
        u = arm_dir(s, 0.5, 0.9, -0.4)
        f = arm_dir(s, 0.3, 1.0, 0.1)
        base = Quaternion()
        hang(P, s, swing_fwd=-25.0 * stag + 30.0 * knees, bend=30.0 + 20.0 * stag, out=10.0 + 10.0 * stag)
        if fall > 0.0:
            a = P.arm[s]["upper"].lerp(u, fall).normalized()
            b = P.arm[s]["fore"].lerp(f, fall).normalized()
            set_arm(P, s, a, b)


def clip_emerge(P, t):
    """3.0 s: wakes hunched in the tank, twitches, rises to full height and spreads the arms (the intro)."""
    rise = ramp(t, 0.9, 2.1)
    twitch = math.sin(t * 40.0) * (bump(t, 0.25, 0.55) + bump(t, 0.6, 0.85))
    spread = ramp(t, 1.9, 2.5) * (1 - ramp(t, 2.6, 3.0) * 0.6)
    crouch = 0.42 * (1 - rise) + 0.05
    base_stance(P, crouch=crouch, lean=9.0 + 30.0 * (1 - rise) - 8.0 * spread)
    P.r("chest", pyr(pitch=6.0 * twitch * (1 - rise), roll=3.0 * twitch))
    P.r("neck", pyr(pitch=25.0 * (1 - rise) - 10.0 * spread))
    P.r("head", pyr(pitch=15.0 * (1 - rise) + 8.0 * twitch - 12.0 * spread, yaw=10.0 * twitch))
    for s in ("L", "R"):
        stand(P, s, 0.06 + 0.04 * spread, 0.0, 0.0)
        up0, fo0 = ARM_REST[s]
        hunched_u = arm_dir(s, 0.2, 0.6, -1.0)
        hunched_f = arm_dir(s, -0.3, 0.8, -0.3)
        wide_u = arm_dir(s, 1.0, 0.1, 0.0)
        wide_f = arm_dir(s, 0.5, 0.6, 0.6)
        a = hunched_u.lerp(up0, rise).lerp(wide_u, spread).normalized()
        b = hunched_f.lerp(fo0, rise).lerp(wide_f, spread).normalized()
        set_arm(P, s, a, b, clav=ry((1 if s == "L" else -1) * 10.0 * spread))


CLIPS = [
    # name, function, seconds, loop
    ("idle", clip_idle, 3.0, True),
    ("walk", clip_walk, 1.1, True),
    ("sprint", clip_sprint, 0.62, True),
    ("rush_wind", clip_rush_wind, 0.9, False),
    ("punch", clip_punch, 1.2, False),
    ("throw", clip_throw, 1.5, False),
    ("stomp", clip_stomp, 1.4, False),
    ("roar", clip_roar, 2.2, False),
    ("laser", clip_laser, 2.6, False),
    ("hit", clip_hit, 0.5, False),
    ("death", clip_death, 3.2, False),
    ("emerge", clip_emerge, 3.0, False),
]


# ------------------------------------------------------------------------------------------------ baking
def bake_action(arm, rig, name, fn, seconds, loop):
    n = max(1, int(round(seconds * FPS)))
    count = n + 1
    quats = {b: np.zeros((count, 4)) for b in rig.order}
    locs = np.zeros((count, 3))
    prev = {}
    rig.over = 0.0
    for f in range(count):
        P = Pose()
        if loop:
            fn(P, (f % n) / float(n))
        else:
            fn(P, f / float(FPS))
        Q, pos = rig.solve(P)
        rot, loc = rig.basis(Q, pos)
        for b in rig.order:
            q = rot[b]
            if b in prev and q.dot(prev[b]) < 0.0:
                q.negate()
            prev[b] = q
            quats[b][f] = q[:]
        locs[f] = loc[:]
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    times = np.arange(count, dtype=np.float64) + 1.0
    for b in rig.order:
        curves = [('pose.bones["%s"].rotation_quaternion' % b, quats[b], 4)]
        if b == "hips":
            curves.append(('pose.bones["%s"].location' % b, locs, 3))
        for path, values, dim in curves:
            for i in range(dim):
                fc = act.fcurve_ensure_for_datablock(arm, path, index=i, group_name=b)
                fc.keyframe_points.add(count)
                co = np.empty(count * 2)
                co[0::2] = times
                co[1::2] = values[:, i]
                fc.keyframe_points.foreach_set("co", co)
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
                fc.update()
    log("clip %-10s %.2f s, %d keys%s" % (name, seconds, count, ", foot out of reach by %.3f" % rig.over if rig.over > 0.005 else ""))
    return act


def stash_actions(arm, actions):
    ad = arm.animation_data
    ad.action = None
    for act in actions:
        track = ad.nla_tracks.new()
        track.name = act.name
        strip = track.strips.new(act.name, 1, act)
        strip.name = act.name
        track.mute = True
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)


def show_action(arm, act, frame_no):
    ad = arm.animation_data
    if ad.action != act:
        ad.action = act
        if act is not None and getattr(ad, "action_slot", None) is None and len(act.slots):
            ad.action_slot = act.slots[0]
    bpy.context.scene.frame_set(frame_no)


# ------------------------------------------------------------------------------------------------ review
def review(arm, actions, folder):
    os.makedirs(folder, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 360
    sc.render.resolution_y = 420
    sc.render.film_transparent = False
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.6
    views = {"front": ((0.0, -6.0, 1.0), (math.radians(90), 0, 0)), "side": ((6.0, 0.0, 1.0), (math.radians(90), 0, math.radians(90)))}
    for act in actions:
        n = int(act.frame_range[1] - act.frame_range[0])
        picks = [1 + int(round(n * k / 5.0)) for k in range(6)]
        for vname, (loc, rot) in views.items():
            cam.location = loc
            cam.rotation_euler = rot
            for i, fr in enumerate(picks):
                show_action(arm, act, fr)
                sc.render.filepath = os.path.join(folder, "%s_%s_%d.png" % (act.name, vname, i))
                bpy.ops.render.render(write_still=True)
    log("review frames in", folder)


# ------------------------------------------------------------------------------------------------ export
def export_glb(obj, arm, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
        export_image_format="JPEG", export_image_quality=92,
        export_skins=True, export_def_bones=False, export_all_influences=False, export_influence_nb=4,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_range=False,
        export_anim_slide_to_zero=True, export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=True,
        export_morph=False, export_cameras=False, export_lights=False,
    )
    log("exported", path, "%.2f MB" % (os.path.getsize(path) / 1e6))


def main():
    parse_args()
    obj = prepare()
    arm = build_armature()
    skin(obj, arm)
    rig = Rig(arm)
    only = set(OPT["only"].split(",")) if OPT["only"] else None
    actions = []
    for name, fn, seconds, loop in CLIPS:
        if only and name not in only:
            continue
        actions.append(bake_action(arm, rig, name, fn, seconds, loop))
    if OPT["review"]:
        review(arm, actions, OPT["review"])
    stash_actions(arm, actions)
    if OPT["out"] and not only:
        export_glb(obj, arm, os.path.abspath(OPT["out"]))


main()
