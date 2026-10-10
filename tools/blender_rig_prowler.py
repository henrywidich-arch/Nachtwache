"""The Prowler: the four-legged hunter of mission two.

Takes the rigged but unanimated model (MutantElite.glb: 198,000 triangles, 4096 px textures, a skeleton of
66 joints "Bone_000".."Bone_065" with weights), reduces the mesh, shrinks the textures and authors every clip
on the existing skeleton by script: the trunk is posed by hand-written curves, the four legs follow targets on
the ground (two-bone IK), so that a paw that stands does not slide. One GLB comes out.

  blender --background --factory-startup --python tools/blender_rig_prowler.py -- \
      --src "D:/Games/AI Games/Nachtwache/zombies_otherCHARS/MutantElite.glb" --out assets/models/prowler.glb \
      [--work <folder>]    keeps the reduced model there between runs (prowler_base.blend)
      [--review <folder>]  frame strips of every clip (side and front)
      [--only idle,run]    only these clips (for looking at them; do not export such a run)
      [--tris 30000] [--tex 2048] [--no-export] [--fresh]

The animal looks along -Y in Blender (+Z in the game's file), its left side is +X.
Ground speeds the gaits are made for (scripts/prowler_visual.gd carries the same numbers):
stalk 1.2 m/s, trot 4.0 m/s, run 8.5 m/s.
"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Quaternion

FPS = 60
OPT = {"src": None, "out": None, "work": None, "review": None, "only": None, "tris": "30000", "tex": "2048"}
FLAGS = set()


def log(*a):
    print("[prowler]", *a)
    sys.stdout.flush()


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key in OPT:
            OPT[key] = argv[i + 1]
            i += 2
        else:
            FLAGS.add(key)
            i += 1


# ------------------------------------------------------------------------------------------------ the model
def find_objects():
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    obj = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
    return arm, obj


def prepare(src, tris, tex):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    arm, obj = find_objects()
    for o in list(bpy.data.objects):
        if o not in (arm, obj):
            bpy.data.objects.remove(o, do_unlink=True)
    me = obj.data
    count = sum(len(p.vertices) - 2 for p in me.polygons)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if count > tris:
        mod = obj.modifiers.new("reduce", "DECIMATE")
        mod.ratio = tris / float(count)
        bpy.ops.object.modifier_move_to_index(modifier="reduce", index=0)
        bpy.ops.object.modifier_apply(modifier="reduce")
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except Exception as e:
        log("normals:", e)
    bpy.ops.object.shade_smooth()
    me = obj.data
    log("mesh: %d -> %d triangles, %d vertices" % (count, sum(len(p.vertices) - 2 for p in me.polygons), len(me.vertices)))
    for img in bpy.data.images:
        if img.size[0] > tex or img.size[1] > tex:
            img.scale(tex, tex)
            img.pack()
        log("image", img.name, tuple(img.size))
    obj.name = "Prowler"
    me.name = "Prowler"
    arm.name = "ProwlerRig"
    for m in me.materials:
        if m:
            m.name = "prowler"
    return arm, obj


# ------------------------------------------------------------------------------------------------ the skeleton
def B(n):
    return "Bone_%03d" % n


ROOT = B(0)
TAIL = [B(3), B(2)]
SPINE = [B(6), B(5), B(4)]
CHEST = B(4)
NECK = [B(21), B(20)]
HEAD = B(19)
JAW = B(33)          # the chin: the mouth is modelled shut, so "open" is the chin dropping
THROAT = B(35)
FORE = {
    "L": {"clav": B(31), "upper": B(30), "fore": B(29), "hand": B(27), "claws": [53, 52, 51, 56, 55, 54, 59, 58, 57, 62, 61, 60, 65, 64, 63]},
    "R": {"clav": B(26), "upper": B(25), "fore": B(24), "hand": B(22), "claws": [38, 37, 36, 41, 40, 39, 44, 43, 42, 47, 46, 45, 50, 49, 48]},
}
HIND = {
    "L": {"hip": B(12), "thigh": B(11), "shin": B(10), "meta": B(9), "foot": B(8)},
    "R": {"hip": B(18), "thigh": B(17), "shin": B(16), "meta": B(15), "foot": B(14)},
}
PIVOT = Vector((0.0, 0.1, 1.15))      # middle of the trunk: whole-body moves turn about it


def rx(deg):
    return Quaternion((1.0, 0.0, 0.0), math.radians(deg))


def ry(deg):
    return Quaternion((0.0, 1.0, 0.0), math.radians(deg))


def rz(deg):
    return Quaternion((0.0, 0.0, 1.0), math.radians(deg))


def pyr(pitch=0.0, yaw=0.0, roll=0.0):
    """Nose up, turn to the left, lean to the left (degrees)."""
    return rz(yaw) @ rx(-pitch) @ ry(roll)


def swing(a, b):
    if a.length < 1e-8 or b.length < 1e-8:
        return Quaternion()
    return a.rotation_difference(b)


def two_bone(a, t, l1, l2, pole):
    """Where the middle joint of a two-bone limb from a to t lies, bent towards pole."""
    v = t - a
    d = v.length
    axis = v / d if d > 1e-6 else Vector((0.0, 0.0, -1.0))
    dmax = (l1 + l2) * 0.999
    over = max(0.0, d - dmax)
    d = min(max(d, abs(l1 - l2) + 0.02), dmax)
    x = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
    h = math.sqrt(max(l1 * l1 - x * x, 0.0))
    perp = pole - axis * pole.dot(axis)
    if perp.length < 1e-5:
        perp = Vector((0.0, 1.0, 0.0))
    perp.normalize()
    return a + axis * x + perp * h, over


class Leg:
    def __init__(self):
        self.off = Vector((0.0, 0.0, 0.0))   # from where the paw rests: x outwards, y backwards, z up
        self.plant = 1.0                     # 1: a place on the ground, 0: carried by the body
        self.heel = 0.0                      # the paw folds back (hind: the heel rises)
        self.toe = 0.0                       # hind: the toes against the ground
        self.curl = 0.0                      # fore: the claws close
        self.knee = 0.0                      # the middle joint turns outwards


class Pose:
    def __init__(self):
        self.d = Vector((0.0, 0.0, 0.0))
        self.pitch = self.yaw = self.roll = 0.0
        self.spine = [[0.0, 0.0, 0.0] for _ in range(3)]
        self.neck = [[0.0, 0.0, 0.0] for _ in range(2)]
        self.head = [0.0, 0.0, 0.0]
        self.jaw = 0.0
        self.tail = [[0.0, 0.0], [0.0, 0.0]]     # up, to the right
        self.leg = {k: Leg() for k in ("FL", "FR", "HL", "HR")}


class Rig:
    def __init__(self, arm):
        bones = arm.data.bones
        self.restq = {b.name: b.matrix_local.to_quaternion() for b in bones}
        self.head = {b.name: b.head_local.copy() for b in bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.order = []

        def walk(b):
            self.order.append(b.name)
            for c in b.children:
                walk(c)
        for b in bones:
            if b.parent is None:
                walk(b)
        self.fore = {}
        self.hind = {}
        self.claw_axis = {}
        for side in ("L", "R"):
            c = FORE[side]
            self.fore[c["upper"]] = side
            names = [B(n) for n in c["claws"]]
            for name in names:
                kids = [k for k in bones[name].children]
                tip = kids[0].head_local if kids else bones[name].tail_local
                d = tip - bones[name].head_local
                axis = d.cross(Vector((0.0, 0.0, -1.0)))
                self.claw_axis[name] = (axis.normalized() if axis.length > 1e-5 else Vector((1.0, 0.0, 0.0)), side)
            self.hind[HIND[side]["thigh"]] = side
        self.over = 0.0

    def solve(self, P):
        G, pos = {}, {}
        root = pyr(P.pitch, P.yaw, P.roll)
        G[ROOT] = root
        pos[ROOT] = PIVOT + P.d + root @ (self.head[ROOT] - PIVOT)
        loc = {}
        for i, b in enumerate(SPINE):
            loc[b] = pyr(*P.spine[i])
        for i, b in enumerate(NECK):
            loc[b] = pyr(*P.neck[i])
        loc[HEAD] = pyr(*P.head)
        loc[JAW] = rx(P.jaw)
        loc[THROAT] = rx(-0.4 * P.jaw)
        for i, b in enumerate(TAIL):
            loc[b] = rz(P.tail[i][1]) @ rx(P.tail[i][0])
        for name, (axis, side) in self.claw_axis.items():
            curl = P.leg["F" + side].curl
            if curl != 0.0:
                loc[name] = Quaternion(axis, math.radians(curl))
        preset = {}
        for b in self.order[1:]:
            p = self.parent[b]
            pos[b] = pos[p] + G[p] @ (self.head[b] - self.head[p])
            if b in preset:
                G[b] = preset[b]
            elif b in self.fore:
                self.ik_fore(self.fore[b], P, b, G, pos, preset)
            elif b in self.hind:
                self.ik_hind(self.hind[b], P, b, G, pos, preset)
            else:
                G[b] = G[p] @ loc[b] if b in loc else G[p]
        return G, pos

    def ik_fore(self, side, P, b, G, pos, preset):
        c = FORE[side]
        s = 1.0 if side == "L" else -1.0
        L = P.leg["F" + side]
        base = G[self.parent[b]]
        wrist0 = self.head[c["hand"]]
        elbow0 = self.head[c["fore"]]
        off = Vector((L.off.x * s, L.off.y, L.off.z))
        carried = pos[CHEST] + G[CHEST] @ (wrist0 + off - self.head[CHEST])
        target = carried.lerp(wrist0 + off, L.plant)
        flat = G[CHEST].slerp(Quaternion(), L.plant)
        e0 = elbow0 - self.head[b]
        f0 = wrist0 - elbow0
        axis0 = (wrist0 - self.head[b]).normalized()
        pole = base @ (e0 - axis0 * e0.dot(axis0))
        if L.knee != 0.0:
            pole = Quaternion((target - pos[b]).normalized(), math.radians(L.knee * s)) @ pole
        elbow, over = two_bone(pos[b], target, e0.length, f0.length, pole)
        self.over = max(self.over, over * L.plant)
        gu = swing(base @ e0, elbow - pos[b]) @ base
        gf = swing(gu @ f0, target - elbow) @ gu
        G[b] = gu
        preset[c["fore"]] = gf
        preset[c["hand"]] = flat @ rx(L.heel)

    def ik_hind(self, side, P, b, G, pos, preset):
        c = HIND[side]
        s = 1.0 if side == "L" else -1.0
        L = P.leg["H" + side]
        base = G[self.parent[b]]
        ball0 = self.head[c["foot"]]
        hock0 = self.head[c["meta"]]
        knee0 = self.head[c["shin"]]
        off = Vector((L.off.x * s, L.off.y, L.off.z))
        carried = pos[ROOT] + G[ROOT] @ (ball0 + off - self.head[ROOT])
        ball = carried.lerp(ball0 + off, L.plant)
        flat = G[ROOT].slerp(Quaternion(), L.plant)
        gm = flat @ rx(L.heel)
        hock = ball + gm @ (hock0 - ball0)
        k0 = knee0 - self.head[b]
        s0 = hock0 - knee0
        axis0 = (hock0 - self.head[b]).normalized()
        pole = base @ (k0 - axis0 * k0.dot(axis0))
        if L.knee != 0.0:
            pole = Quaternion((hock - pos[b]).normalized(), math.radians(L.knee * s)) @ pole
        knee, over = two_bone(pos[b], hock, k0.length, s0.length, pole)
        self.over = max(self.over, over * L.plant)
        gt = swing(base @ k0, knee - pos[b]) @ base
        gs = swing(gt @ s0, hock - knee) @ gt
        G[b] = gt
        preset[c["shin"]] = gs
        preset[c["meta"]] = gm
        preset[c["foot"]] = flat @ rx(L.toe)

    def basis(self, G, pos):
        """What to key on every bone: its rotation in its own rest axes (and the root's place)."""
        out = {}
        for b in self.order:
            p = self.parent[b]
            local = G[b] if p is None else G[p].inverted() @ G[b]
            r = self.restq[b]
            out[b] = r.inverted() @ local @ r
        loc = self.restq[ROOT].inverted() @ (pos[ROOT] - self.head[ROOT])
        return out, loc


# ------------------------------------------------------------------------------------------------ curves
def clamp(x, a=0.0, b=1.0):
    return a if x < a else (b if x > b else x)


def sm(x):
    x = clamp(x)
    return x * x * (3.0 - 2.0 * x)


def key(t, pts):
    """Value at t of a curve through the points (time, value), eased between them."""
    if t <= pts[0][0]:
        return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * sm((t - t0) / (t1 - t0))
    return pts[-1][1]


def wave(u, phase=0.0):
    return math.sin(2.0 * math.pi * (u - phase))


def bump(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def hermite(w, y0, m0, y1, m1):
    w2, w3 = w * w, w * w * w
    return (2 * w3 - 3 * w2 + 1) * y0 + (w3 - 2 * w2 + w) * m0 + (-2 * w3 + 3 * w2) * y1 + (w3 - w2) * m1


def step(L, s, duty, stride, lift, y0, x0=0.0, heel0=0.0, fold=50.0, push=0.0, hind=False):
    """One leg of a gait, s = 0 at touchdown. While it stands the paw runs backwards with the ground at an
    even pace (the game moves the body forwards at that pace: no sliding); in the air it swings forwards and
    arrives already moving with the ground."""
    L.plant = 1.0
    if s < duty:
        k = s / duty
        L.off = Vector((x0, y0 - stride * 0.5 + stride * k, 0.0))
        L.heel = heel0 + push * sm((k - 0.55) / 0.45)
        L.toe = 0.0
    else:
        w = (s - duty) / (1.0 - duty)
        m = stride / duty * (1.0 - duty)
        y = hermite(w, y0 + stride * 0.5, m, y0 - stride * 0.5, m)
        z = lift * math.sin(math.pi * w) ** 1.4
        L.off = Vector((x0, y, z))
        L.heel = heel0 + push * (1.0 - sm(w / 0.5)) + fold * math.sin(math.pi * clamp(w * 1.15))
        L.toe = 0.75 * (L.heel - heel0) * math.sin(math.pi * clamp(w * 1.1)) if hind else 0.0


# ------------------------------------------------------------------------------------------------ the clips
STALK_T, STALK_V, STALK_DUTY = 1.2, 1.2, 0.66
TROT_T, TROT_V, TROT_DUTY = 0.5, 4.0, 0.42
RUN_T, RUN_V, RUN_DUTY = 0.4, 8.5, 0.24


def clip_idle(P, u):
    br = wave(2 * u)
    P.d = Vector((0.02 * wave(u), 0.0, 0.012 * br))
    P.roll = 1.2 * wave(u)
    P.spine[2][0] = 1.5 * br
    look = wave(u, 0.1)
    P.neck[0][1] = 11 * look
    P.neck[1][1] = 10 * look
    P.head[1] = 10 * look
    P.neck[0][0] = 3 * wave(2 * u, 0.2)
    P.head[0] = 4 * wave(u, 0.35)
    P.head[2] = 6 * wave(u, 0.2)
    P.jaw = 5 + 3 * br
    P.tail[0][1] = 10 * wave(u, 0.3)
    P.tail[1][1] = 14 * wave(u, 0.45)
    P.tail[0][0] = 3 * br


def clip_stalk(P, u):
    stride = STALK_V * STALK_DUTY * STALK_T
    sway = wave(u, 0.05)
    P.d = Vector((0.035 * wave(u, 0.12), 0.0, -0.11 + 0.012 * wave(2 * u, 0.1)))
    P.pitch = -2.0
    P.roll = 1.5 * wave(u, 0.2)
    P.spine[0][1] = 4 * sway
    P.spine[2][1] = -5 * sway
    for name, ph in (("HL", 0.0), ("FL", 0.22), ("HR", 0.5), ("FR", 0.72)):
        s = (u - ph) % 1.0
        if name[0] == "F":
            step(P.leg[name], s, STALK_DUTY, stride, 0.20, 0.14, fold=40.0)
            P.leg[name].curl = 12 * bump(s, STALK_DUTY, 1.0)
        else:
            step(P.leg[name], s, STALK_DUTY, stride, 0.13, -0.34, heel0=-14.0, fold=30.0, push=22.0, hind=True)
    P.neck[0][0] = -5
    P.neck[0][1] = 3 * sway
    P.head[0] = 7
    P.head[1] = 6 * wave(u, 0.3)
    P.jaw = 6
    P.tail[0][1] = 9 * wave(u, 0.2)
    P.tail[1][1] = 12 * wave(u, 0.35)


def clip_trot(P, u):
    stride = TROT_V * TROT_DUTY * TROT_T
    P.d = Vector((0.0, 0.0, -0.05 + 0.03 * wave(2 * u, 0.33)))
    P.pitch = 1.0 + 1.5 * wave(2 * u, 0.1)
    P.roll = 2.0 * wave(u, 0.1)
    sway = wave(u, 0.1)
    P.spine[0][1] = 3 * sway
    P.spine[2][1] = -4 * sway
    for name, ph in (("FL", 0.0), ("HR", 0.0), ("FR", 0.5), ("HL", 0.5)):
        s = (u - ph) % 1.0
        if name[0] == "F":
            step(P.leg[name], s, TROT_DUTY, stride, 0.26, 0.16, fold=60.0)
        else:
            step(P.leg[name], s, TROT_DUTY, stride, 0.20, -0.38, heel0=-16.0, fold=45.0, push=25.0, hind=True)
    P.neck[0][0] = 4 - 1.5 * wave(2 * u, 0.1)
    P.head[0] = 6
    P.jaw = 8
    P.tail[0][0] = 8
    P.tail[0][1] = 8 * wave(u, 0.2)
    P.tail[1][1] = 12 * wave(u, 0.35)


def clip_run(P, u):
    """A rotary gallop: both hind legs, a stretched flight, both forelegs, a gathered flight."""
    stride = RUN_V * RUN_DUTY * RUN_T
    f = 0.65 * math.cos(2.0 * math.pi * (u - 0.93)) + 0.35      # +1 gathered (back arched), -0.3 stretched
    arch = 9.0
    trunk = 5.0 * math.cos(2.0 * math.pi * (u - 0.2))
    P.pitch = trunk + arch * f
    for i in range(3):
        P.spine[i][0] = -2.0 * arch * f / 3.0
    P.d = Vector((0.0, 0.0, -0.03 + 0.06 * math.cos(2.0 * math.pi * (u - 0.42)) + 0.02 * wave(2 * u, 0.1)))
    for name, ph in (("HL", 0.0), ("HR", 0.07), ("FR", 0.50), ("FL", 0.57)):
        s = (u - ph) % 1.0
        if name[0] == "F":
            step(P.leg[name], s, RUN_DUTY, stride, 0.36, 0.14, fold=80.0)
            P.leg[name].curl = 14 * bump(s, RUN_DUTY, 1.0)
        else:
            step(P.leg[name], s, RUN_DUTY, stride, 0.30, -0.42, heel0=-18.0, fold=60.0, push=30.0, hind=True)
    chest = trunk - arch * f
    P.neck[0][0] = 5 - 0.5 * chest
    P.neck[1][0] = -0.3 * chest
    P.head[0] = 6
    P.jaw = 10 + 4 * wave(u, 0.6)
    P.tail[0][0] = 12 + 8 * wave(u, 0.35)
    P.tail[1][0] = 8 * wave(u, 0.5)


LEAP_T, LEAP_OFF, LEAP_DOWN = 1.1, 0.30, 0.80     # the game's flight lasts from LEAP_OFF to LEAP_DOWN


def clip_leap(P, t):
    cr = key(t, [(0, 0), (0.21, 1), (0.29, 0.7), (0.37, 0)])
    air = key(t, [(0.27, 0), (0.38, 1), (0.72, 1), (0.84, 0)])
    land = key(t, [(0.78, 0), (0.89, 1), (1.1, 0)])
    P.d = Vector((0.0, 0.20 * cr - 0.12 * land, -0.30 * cr - 0.26 * land))
    P.pitch = -8 * cr + key(t, [(0.27, 0), (0.40, 15), (0.60, 3), (0.80, -11), (0.94, -3), (1.1, 0)])
    for i in range(3):
        P.spine[i][0] = -5 * cr + 2.5 * air - 3 * land
    for name in ("FL", "FR"):
        L = P.leg[name]
        L.plant = 1.0 - key(t, [(0.24, 0), (0.31, 1), (0.76, 1), (0.82, 0)])
        reach = key(t, [(0.26, 0), (0.42, 1), (0.66, 1), (0.80, 0.2), (0.86, 0)])
        L.off = Vector((0.10 * reach, -0.28 * reach, 0.50 * reach))
        L.heel = -28 * reach
        L.curl = -18 * reach
    for name in ("HL", "HR"):
        L = P.leg[name]
        L.plant = 1.0 - key(t, [(0.28, 0), (0.34, 1), (0.80, 1), (0.88, 0)])
        trail = key(t, [(0.30, 0), (0.44, 1), (0.60, 1), (0.82, 0)])
        tuck = key(t, [(0.58, 0), (0.78, 1), (0.88, 0)])
        L.off = Vector((0.0, 0.26 * trail - 0.25 * tuck, 0.20 * trail + 0.14 * tuck))
        L.heel = 45 * trail - 14 * (1.0 - trail) * cr
        L.toe = 32 * trail
    P.neck[0][0] = -6 * cr + 9 * air
    P.head[0] = 8 * air - 5 * land
    P.jaw = 6 + 32 * key(t, [(0.3, 0), (0.45, 1), (0.78, 1), (0.95, 0)])
    P.tail[0][0] = 20 * air - 8 * cr
    P.tail[1][0] = 14 * air


SLASH_T, SLASH_AT = 0.7, 0.31


def clip_slash(P, t, side):
    near, far = ("FL", "FR") if side > 0 else ("FR", "FL")
    wind = key(t, [(0, 0), (0.17, 1), (0.25, 0.6), (0.33, 0)])
    hit = key(t, [(0.19, 0), (0.32, 1), (0.42, 1), (0.70, 0)])
    P.pitch = 9 * wind + 2 * hit
    P.yaw = side * (9 * wind - 11 * hit)
    P.roll = side * (-4 * wind + 7 * hit)
    P.d = Vector((side * (0.05 * wind - 0.08 * hit), 0.10 * wind - 0.26 * hit, 0.05 * wind - 0.08 * hit))
    P.spine[2][1] = side * (8 * wind - 10 * hit)
    L = P.leg[near]
    L.plant = 1.0 - key(t, [(0.02, 0), (0.09, 1), (0.50, 1), (0.64, 0)])
    up = key(t, [(0.02, 0), (0.17, 1), (0.29, 0.55), (0.40, 0.12), (0.60, 0)])
    fw = key(t, [(0.17, 0), (0.31, 1), (0.44, 0.8), (0.66, 0)])
    L.off = Vector((0.30 * up - 0.55 * fw, 0.15 * up - 0.45 * fw, 0.85 * up + 0.15 * fw))
    L.heel = -32 * up + 34 * fw
    L.curl = -22 * up + 12 * fw
    P.leg[far].curl = 10 * hit
    P.neck[0][1] = side * (-6 * wind + 8 * hit)
    P.head[0] = 6 * wind - 4 * hit
    P.jaw = 8 + 16 * hit
    P.tail[0][1] = side * (-14 * wind + 18 * hit)
    P.tail[1][1] = side * (-10 * wind + 20 * hit)


SLAM_T, SLAM_AT = 0.9, 0.47


def clip_slam(P, t):
    up = key(t, [(0, 0), (0.27, 1), (0.37, 1), (0.47, 0)])
    hit = key(t, [(0.40, 0), (0.48, 1), (0.60, 0.7), (0.9, 0)])
    P.pitch = 25 * up - 7 * hit
    P.d = Vector((0.0, 0.24 * up - 0.20 * hit, 0.05 * up - 0.17 * hit))
    P.spine[2][0] = 6 * up - 4 * hit
    for name in ("FL", "FR"):
        L = P.leg[name]
        L.plant = 1.0 - key(t, [(0.02, 0), (0.10, 1), (0.40, 1), (0.47, 0)])
        L.off = Vector((0.14 * up, 0.06 * up, 0.30 * up))
        L.heel = -36 * up
        L.curl = -24 * up + 14 * hit
    for name in ("HL", "HR"):
        P.leg[name].heel = -10 * up
    P.neck[0][0] = 8 * up - 8 * hit
    P.head[0] = 8 * up - 6 * hit
    P.jaw = 8 + 28 * key(t, [(0.1, 0), (0.3, 1), (0.5, 1), (0.7, 0)])
    P.tail[0][0] = -12 * up + 16 * hit
    P.tail[1][0] = -8 * up + 10 * hit


BITE_T, BITE_AT = 0.6, 0.24


def clip_bite(P, t):
    back = key(t, [(0, 0), (0.09, 1), (0.16, 0)])
    go = key(t, [(0.10, 0), (0.22, 1), (0.31, 1), (0.6, 0)])
    P.d = Vector((0.0, 0.08 * back - 0.32 * go, -0.04 * back - 0.07 * go))
    P.pitch = -3 * go
    P.spine[2][0] = -3 * go
    P.neck[0][0] = -8 * back + 13 * go
    P.neck[1][0] = 9 * go
    P.head[0] = -6 * back + 11 * go
    shake = key(t, [(0.25, 0), (0.29, 1), (0.42, 1), (0.50, 0)])
    P.head[2] = 9 * math.sin(t * 42.0) * shake
    P.head[1] = 5 * math.sin(t * 42.0 + 1.0) * shake
    P.jaw = 6 + 40 * key(t, [(0.03, 0), (0.15, 1), (0.21, 1), (0.26, 0)]) + 9 * key(t, [(0.30, 0), (0.38, 1), (0.5, 0)])
    P.tail[0][0] = 12 * go


FLINCH_T = 0.45


def clip_flinch(P, t):
    k = key(t, [(0, 0), (0.08, 1), (0.2, 0.7), (0.45, 0)])
    P.d = Vector((-0.06 * k, 0.14 * k, -0.05 * k))
    P.pitch = 5 * k
    P.roll = -6 * k
    P.yaw = -6 * k
    P.spine[2][1] = -6 * k
    P.neck[0][1] = -16 * k
    P.neck[0][0] = 8 * k
    P.head[1] = -14 * k
    P.head[0] = 10 * k
    P.head[2] = -8 * k
    P.jaw = 6 + 22 * k
    P.tail[0][0] = 15 * k
    P.tail[1][1] = 16 * k


STAGGER_T = 1.0


def clip_stagger(P, t):
    k = key(t, [(0, 0), (0.12, 1), (0.45, 0.75), (1.0, 0)])
    P.d = Vector((0.12 * k, 0.30 * k, -0.20 * k))
    P.pitch = 9 * k
    P.roll = 12 * k
    P.yaw = 13 * k
    P.spine[1][1] = 8 * k
    P.spine[2][2] = 8 * k
    P.neck[0][1] = 24 * k
    P.neck[0][0] = 10 * k
    P.head[0] = 16 * k
    P.head[2] = 12 * k
    P.jaw = 6 + 30 * key(t, [(0, 0), (0.1, 1), (0.5, 0.6), (0.9, 0)])
    # the forelegs lose their hold one after the other, step back and come forward again
    for name, late in (("FL", 0.0), ("FR", 0.09)):
        L = P.leg[name]
        back = key(t - late, [(0.02, 0), (0.22, 1), (0.58, 1), (0.84, 0)])
        L.off = Vector((0.08 * back, 0.30 * back, 0.26 * bump(t - late, 0.02, 0.22) + 0.18 * bump(t - late, 0.58, 0.84)))
        L.heel = 40 * bump(t - late, 0.02, 0.22) + 30 * bump(t - late, 0.58, 0.84)
    for name in ("HL", "HR"):
        P.leg[name].heel = -16 * k
    P.tail[0][0] = 18 * k
    P.tail[0][1] = -20 * k
    P.tail[1][1] = -22 * k


ROAR_T = 1.9


def clip_roar(P, t):
    gather = key(t, [(0, 0), (0.27, 1), (0.42, 0)])
    out = key(t, [(0.30, 0), (0.50, 1), (1.45, 1), (1.9, 0)])
    shake = math.sin(t * 2.0 * math.pi * 11.0) * out
    P.d = Vector((0.006 * shake, 0.13 * gather - 0.10 * out, -0.15 * gather + 0.04 * out))
    P.pitch = -6 * gather + 7 * out
    P.spine[2][0] = -3 * gather + 5 * out
    P.neck[0][0] = -10 * gather + 15 * out
    P.neck[1][0] = 13 * out
    P.head[0] = -8 * gather + 13 * out + 1.5 * shake
    P.head[1] = 3 * shake + 12 * math.sin((t - 0.4) * 2.6) * out
    P.head[2] = 2 * shake
    P.jaw = 6 + 46 * key(t, [(0.32, 0), (0.48, 1), (1.4, 1), (1.72, 0)]) + 2 * shake
    for name in ("FL", "FR"):
        P.leg[name].curl = 16 * out
    P.tail[0][0] = 24 * out
    P.tail[1][0] = 18 * out + 6 * shake
    P.tail[1][1] = 14 * math.sin(t * 9.0) * out


DEATH_T = 2.4


def clip_death(P, t):
    hit = key(t, [(0, 0), (0.15, 1), (0.5, 0.45), (0.85, 0)])
    fall = key(t, [(0.42, 0), (1.05, 1)])
    settle = bump(t, 1.05, 1.42)
    P.d = Vector((0.10 * fall, 0.12 * hit + 0.08 * fall, -0.60 * fall + 0.05 * settle))
    P.roll = -6 * hit + 24 * fall - 3 * settle
    P.pitch = 8 * hit - 2 * fall
    P.yaw = 7 * fall
    P.spine[1][1] = 8 * fall
    P.spine[2][0] = -6 * fall
    P.neck[0][0] = 22 * hit - 12 * fall
    P.neck[0][1] = 26 * fall
    P.neck[1][1] = 16 * fall
    P.head[0] = 16 * hit - 8 * fall
    P.head[2] = 18 * fall
    P.jaw = 6 + 38 * hit + 16 * fall
    twitch = bump(t, 1.62, 1.86)
    for name in ("FL", "FR"):
        L = P.leg[name]
        L.off = Vector((0.26 * fall, -0.36 * fall, 0.05 * twitch if name == "FL" else 0.0))
        L.heel = -4 * fall
        L.curl = 14 * fall - 12 * twitch
    for name in ("HL", "HR"):
        L = P.leg[name]
        L.off = Vector((0.24 * fall, 0.22 * fall, 0.0))
        L.heel = 46 * fall
        L.toe = 26 * fall
    P.tail[0][0] = 14 * hit - 22 * fall
    P.tail[1][0] = -12 * fall + 10 * twitch
    P.tail[0][1] = 10 * fall


CLIPS = [
    # name, pose function (of the phase 0..1 for loops, of the time in seconds otherwise), seconds, loop
    ("idle", clip_idle, 3.2, True),
    ("stalk", clip_stalk, STALK_T, True),
    ("trot", clip_trot, TROT_T, True),
    ("run", clip_run, RUN_T, True),
    ("leap", clip_leap, LEAP_T, False),
    ("slash_l", lambda P, t: clip_slash(P, t, 1.0), SLASH_T, False),
    ("slash_r", lambda P, t: clip_slash(P, t, -1.0), SLASH_T, False),
    ("slam", clip_slam, SLAM_T, False),
    ("bite", clip_bite, BITE_T, False),
    ("flinch", clip_flinch, FLINCH_T, False),
    ("stagger", clip_stagger, STAGGER_T, False),
    ("roar", clip_roar, ROAR_T, False),
    ("death", clip_death, DEATH_T, False),
]


# ------------------------------------------------------------------------------------------------ baking
def bake_action(arm, rig, name, fn, seconds, loop):
    n = int(round(seconds * FPS))
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
        G, pos = rig.solve(P)
        rot, loc = rig.basis(G, pos)
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
    times = np.arange(count, dtype=np.float64)
    for b in rig.order:
        curves = [('pose.bones["%s"].rotation_quaternion' % b, quats[b], 4)]
        if b == ROOT:
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
    log("clip %-8s %.2f s, %d keys%s" % (name, seconds, count, ", a standing paw out of reach by %.3f m" % rig.over if rig.over > 0.004 else ""))
    return act, n


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


# ------------------------------------------------------------------------------------------------ review
def load_png(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    return arr.reshape(h, w, 4)[::-1].copy()


def save_png(arr, path):
    h, w = arr.shape[:2]
    img = bpy.data.images.new("sheet", w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).reshape(-1))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


class Review:
    W, H = 440, 330

    def __init__(self, folder):
        self.folder = folder
        os.makedirs(folder, exist_ok=True)
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.film_transparent = False
        scene.view_settings.view_transform = "Standard"
        scene.display.render_aa = "5"
        if scene.world is None:
            scene.world = bpy.data.worlds.new("review_world")
        scene.world.color = (0.16, 0.16, 0.18)
        cam = bpy.data.cameras.new("review_cam")
        self.cam = bpy.data.objects.new("review_cam", cam)
        scene.collection.objects.link(self.cam)
        scene.camera = self.cam
        sh = scene.display.shading
        sh.light = "STUDIO"
        sh.color_type = "TEXTURE"
        sh.show_shadows = False
        sh.show_cavity = True
        sh.cavity_type = "WORLD"
        r = scene.render
        r.resolution_x, r.resolution_y, r.resolution_percentage = self.W, self.H, 100
        r.image_settings.file_format = "PNG"
        self.tmp = os.path.join(folder, "_tmp.png")
        self.rows = []

    def shot(self, pos, target, ortho=None, lens=50, ground=None):
        from mathutils import Matrix
        pos, target = Vector(pos), Vector(target)
        fwd = (target - pos).normalized()
        right = fwd.cross(Vector((0, 0, 1))).normalized()
        up = right.cross(fwd).normalized()
        m = Matrix((right, up, -fwd)).transposed().to_4x4()
        m.translation = pos
        self.cam.matrix_world = m
        cam = self.cam.data
        cam.clip_start, cam.clip_end = 0.05, 100.0
        if ortho:
            cam.type = "ORTHO"
            cam.ortho_scale = ortho
        else:
            cam.type = "PERSP"
            cam.lens = lens
        bpy.context.scene.render.filepath = self.tmp
        bpy.ops.render.render(write_still=True)
        img = load_png(self.tmp)
        if ortho and ground is not None:
            y = int(round(self.H / 2 + (target.z - ground) * self.W / ortho))
            if 0 <= y < self.H:
                img[y, :, :3] = img[y, :, :3] * 0.4 + np.array((1.0, 0.5, 0.2)) * 0.6
        return img

    def clip(self, arm, act, name, n, loop):
        picks = [int(round(k * n / 6.0)) for k in range(6)] if loop else [int(round(k * n / 5.0)) for k in range(6)]
        side, front = [], []
        for f in picks:
            show_action(arm, act, f)
            side.append(self.shot((9.0, -0.15, 0.85), (0.0, -0.15, 0.85), ortho=3.7, ground=0.0))
            front.append(self.shot((2.3, -4.6, 1.5), (0.0, -0.2, 0.75), lens=46))
        self.rows.append((name, side, front))

    def sheets(self, per=3):
        pad = 4
        for start in range(0, len(self.rows), per):
            group = self.rows[start:start + per]
            rows = len(group) * 2
            out = np.zeros((rows * (self.H + pad) + pad, 6 * (self.W + pad) + pad, 4), dtype=np.float32)
            out[..., :3] = 0.02
            out[..., 3] = 1.0
            for g, (name, side, front) in enumerate(group):
                for r, tiles in enumerate((side, front)):
                    for c, tile in enumerate(tiles):
                        y = pad + (g * 2 + r) * (self.H + pad)
                        x = pad + c * (self.W + pad)
                        out[y:y + self.H, x:x + self.W] = tile
            path = os.path.join(self.folder, "clips_%s.png" % "_".join(g[0] for g in group))
            save_png(out, path)
            log("review:", path)
        if os.path.exists(self.tmp):
            os.remove(self.tmp)


# ------------------------------------------------------------------------------------------------ export
def export_glb(obj, arm, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
        export_image_format="JPEG", export_image_quality=93,
        export_skins=True, export_def_bones=False, export_all_influences=False, export_influence_nb=4,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_range=False,
        export_anim_slide_to_zero=True, export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=True,
        export_morph=False, export_cameras=False, export_lights=False,
    )
    log("exported", path, "%.2f MB" % (os.path.getsize(path) / 1e6))


def main():
    parse_args()
    work = OPT["work"]
    base = os.path.join(work, "prowler_base.blend") if work else None
    if base and os.path.exists(base) and "fresh" not in FLAGS:
        bpy.ops.wm.open_mainfile(filepath=base)
        arm, obj = find_objects()
        log("reduced model taken from", base)
    else:
        arm, obj = prepare(OPT["src"], int(OPT["tris"]), int(OPT["tex"]))
        if base:
            os.makedirs(work, exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(base))
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = FPS, 1.0
    co = [obj.matrix_world @ v.co for v in obj.data.vertices]
    log("size: x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (
        min(c.x for c in co), max(c.x for c in co), min(c.y for c in co), max(c.y for c in co), min(c.z for c in co), max(c.z for c in co)))
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    rig = Rig(arm)
    rv = Review(OPT["review"]) if OPT["review"] else None
    if rv and "jawtest" in FLAGS:
        # which joint opens the mouth, and which way: four close views of the head
        tiles = []
        for bone, angle in ((B(35), 40.0), (B(35), -40.0), (B(33), 40.0), (B(33), -40.0)):
            G, pos = rig.solve(Pose())
            rot, loc = rig.basis(G, pos)
            for pb in arm.pose.bones:
                pb.rotation_quaternion = rot[pb.name]
            r = rig.restq[bone]
            arm.pose.bones[bone].rotation_quaternion = r.inverted() @ rx(angle) @ r
            bpy.context.view_layer.update()
            tiles.append(rv.shot((9.0, -1.15, 1.2), (0.0, -1.15, 1.2), ortho=1.3))
            tiles.append(rv.shot((1.6, -3.2, 1.3), (0.0, -1.2, 1.15), lens=70))
        rv.rows.append(("jaw", tiles[0::2] + tiles[0:2], tiles[1::2] + tiles[0:2]))
        rv.sheets()
        return
    only = OPT["only"].split(",") if OPT["only"] else None
    actions = []
    for name, fn, seconds, loop in CLIPS:
        if only and name not in only:
            continue
        act, n = bake_action(arm, rig, name, fn, seconds, loop)
        actions.append(act)
        if rv:
            rv.clip(arm, act, name, n, loop)
    if rv:
        rv.sheets()
    scene.frame_start, scene.frame_end = 0, max([int(a.frame_range[1]) for a in actions] + [1])
    stash_actions(arm, actions)
    scene.frame_set(0)
    if "no-export" not in FLAGS and OPT["out"]:
        export_glb(obj, arm, OPT["out"])
    log("done:", ", ".join("%s %.2fs" % (a.name, a.frame_range[1] / FPS) for a in actions))


if __name__ == "__main__":
    main()
