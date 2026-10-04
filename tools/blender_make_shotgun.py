# Builds the pump-action shotgun for Nachtwache from nothing: the geometry and the
# game-ready GLB (nodes Shotgun > Body / Pump / Shell) with one plain PBR material per
# surface type (steel, aluminium, polymer, rubber, brass, hull ...). The fine surface
# grain is added by the game's own materials, so no textures are baked here.
#
# Run (a few seconds), from the project folder:
#   blender --background --factory-startup --python tools/blender_make_shotgun.py -- [--out <shotgun.glb>]
#       [--stage full|geo] [--blend <file.blend>]
#
#   --out      target GLB (default: ../assets/models/shotgun.glb next to this script's folder)
#   --stage    "geo" stops after the geometry (for shape work), "full" also exports the GLB
#   --blend    when given, the scene is saved as a .blend for inspection
#
# Modelling space used below: x = right, y = forward (muzzle), z = up, metres, bore axis at
# z = 0 and y = 0 at the rear face of the receiver.  Everything is shifted at the end so the
# origin is the middle of the pistol grip.  The glTF exporter turns this into Godot space:
# barrel along -Z, up +Y, ejection port on +X.
import bpy, bmesh, sys, os, math, time, tempfile
import numpy as np
from math import sin, cos, tan, pi, radians, sqrt, atan2, ceil
from mathutils import Vector

T_START = time.time()
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGV and ARGV.index(name) + 1 < len(ARGV):
        return ARGV[ARGV.index(name) + 1]
    return default


HERE = os.path.dirname(os.path.abspath(__file__))
OUT_GLB = os.path.abspath(arg("--out", os.path.join(HERE, "..", "assets", "models", "shotgun.glb")))
WORK = os.path.abspath(arg("--work", os.path.join(tempfile.gettempdir(), "shotgun_bake")))
TEX = int(arg("--tex", "2048"))
STAGE = arg("--stage", "full")
BLEND = arg("--blend")
os.makedirs(WORK, exist_ok=True)

# ----------------------------------------------------------------------------- dimensions
ZT = -0.030                 # magazine tube axis, below the bore
RCV_L = 0.220               # receiver length
RCV_W = 0.0205              # receiver half width
RCV_TOP, RCV_BOT = 0.017, -0.046
RAIL_TOP = 0.0260
BARREL_R = 0.0110
MUZZLE_Y = 0.673
SIGHT_Z = 0.0375            # sight line above the bore
REAR_SIGHT_Y = 0.048
FRONT_SIGHT_Y = 0.647
FOREND_Y0, FOREND_Y1 = 0.325, 0.515
PUMP_TRAVEL = 0.090
EJECT = (0.106, 0.190, -0.0120, 0.0125)      # ejection port y0, y1, z0, z1
LOAD = (0.104, 0.206, 0.0118)                # loading port y0, y1, half width
SHELL_L, SHELL_R = 0.070, 0.0100
ORIGIN = Vector((0.0, -0.030, -0.105))       # middle of the pistol grip in modelling space


def srgb(r, g, b):
    return tuple(((c / 255.0 + 0.055) / 1.055) ** 2.4 if c / 255.0 > 0.04045 else c / 255.0 / 12.92 for c in (r, g, b))


# wear: 0 none, 1 coated metal (edges go to bare steel), 2 polymer, 3 rubber, 4 bare metal, 5 hull plastic
# bump: 0 fine metal grain, 1 polymer grain, 2 grip stipple, 3 rubber, 4 hull ribs, 5 none
MATS = {
    "steel":   dict(col=srgb(50, 52, 56), metal=1.00, rough=0.52, wear=1, bump=0),
    "alu":     dict(col=srgb(68, 70, 75), metal=1.00, rough=0.44, wear=1, bump=0),
    "inside":  dict(col=srgb(26, 26, 28), metal=0.60, rough=0.62, wear=0, bump=0),
    "polymer": dict(col=srgb(37, 38, 40), metal=0.00, rough=0.66, wear=2, bump=1),
    "grip":    dict(col=srgb(31, 32, 34), metal=0.00, rough=0.80, wear=2, bump=2),
    "rubber":  dict(col=srgb(23, 23, 24), metal=0.00, rough=0.90, wear=3, bump=3),
    "brass":   dict(col=srgb(212, 168, 86), metal=1.00, rough=0.30, wear=4, bump=5),
    "bright":  dict(col=srgb(150, 152, 157), metal=1.00, rough=0.32, wear=4, bump=0),
    "hull":    dict(col=srgb(158, 22, 20), metal=0.00, rough=0.40, wear=5, bump=4),
    "void":    dict(col=srgb(10, 10, 11), metal=0.00, rough=0.90, wear=0, bump=5),
    "white":   dict(col=srgb(232, 232, 220), metal=0.00, rough=0.50, wear=0, bump=5),
    "red":     dict(col=srgb(200, 26, 20), metal=0.00, rough=0.45, wear=0, bump=5),
}


# ----------------------------------------------------------------------------- 2D helpers
def fillet_path(pts, closed=True, step=radians(12.0)):
    """Polyline through (a, b[, radius]) points with rounded corners."""
    out = []
    n = len(pts)
    P = [Vector((p[0], p[1])) for p in pts]
    R = [(p[2] if len(p) > 2 else 0.0) for p in pts]
    for i in range(n):
        p, r = P[i], R[i]
        if r <= 0.0 or (not closed and (i == 0 or i == n - 1)):
            out.append(p.copy())
            continue
        a, b = P[(i - 1) % n], P[(i + 1) % n]
        v_in, v_out = p - a, b - p
        l_in, l_out = v_in.length, v_out.length
        v_in.normalize()
        v_out.normalize()
        crossz = v_in.x * v_out.y - v_in.y * v_out.x
        phi = math.acos(max(-1.0, min(1.0, v_in.dot(v_out))))
        if phi < 1e-4 or abs(crossz) < 1e-9:
            out.append(p.copy())
            continue
        t = r * tan(phi / 2)
        tmax = 0.49 * min(l_in, l_out)
        if t > tmax:
            t = tmax
            r = t / tan(phi / 2)
        s = p - v_in * t
        sign = 1.0 if crossz > 0 else -1.0
        c = s + Vector((-v_in.y, v_in.x)) * sign * r
        a0 = atan2(s.y - c.y, s.x - c.x)
        k = max(1, int(ceil(phi / step)))
        for j in range(k + 1):
            ang = a0 + sign * phi * j / k
            out.append(Vector((c.x + r * cos(ang), c.y + r * sin(ang))))
    return out


def arc(cx, cy, r, a0, a1, n, ry=None):
    ry = r if ry is None else ry
    return [Vector((cx + r * cos(a0 + (a1 - a0) * k / n), cy + ry * sin(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def rrect(w, h, r, n=3):
    pts = []
    hw, hh = w / 2, h / 2
    for cx, cy, a0 in ((hw - r, hh - r, 0), (-hw + r, hh - r, 90), (-hw + r, -hh + r, 180), (hw - r, -hh + r, 270)):
        for k in range(n + 1):
            a = radians(a0 + 90.0 * k / n)
            pts.append((cx + r * cos(a), cy + r * sin(a)))
    return pts


# ----------------------------------------------------------------------------- mesh helpers
def prism(pts, lo, hi, axis="x"):
    """Extrudes a closed outline.  axis x: outline is (y, z); axis y: (x, z); axis z: (x, y)."""
    bm = bmesh.new()

    def P(a, b, t):
        if axis == "x":
            return (t, a, b)
        if axis == "y":
            return (a, t, b)
        return (a, b, t)

    v0 = [bm.verts.new(P(p[0], p[1], lo)) for p in pts]
    v1 = [bm.verts.new(P(p[0], p[1], hi)) for p in pts]
    n = len(pts)
    bm.faces.new(v0)
    bm.faces.new(list(reversed(v1)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((v0[i], v1[i], v1[j], v0[j]))
    return bm


def box(x0, x1, y0, y1, z0, z1):
    return prism([(y0, z0), (y1, z0), (y1, z1), (y0, z1)], x0, x1, "x")


def lathe(profile, seg=24, axis="y", c=(0.0, 0.0), phase=0.0, radial=None, cap=True):
    """Surface of revolution.  profile [(t, r)], r = 0 makes a pole.  axis y: c = (x, z);
    axis x: c = (y, z); axis z: c = (x, y)."""
    bm = bmesh.new()

    def P(t, r, a):
        ca, sa = cos(a), sin(a)
        if axis == "y":
            return (c[0] + r * ca, t, c[1] + r * sa)
        if axis == "x":
            return (t, c[0] + r * ca, c[1] + r * sa)
        return (c[0] + r * ca, c[1] + r * sa, t)

    rings = []
    for (t, r) in profile:
        if r <= 1e-9:
            rings.append([bm.verts.new(P(t, 0.0, 0.0))])
        else:
            rings.append([bm.verts.new(P(t, r if radial is None else radial(k, t, r), phase + 2 * pi * k / seg)) for k in range(seg)])
    for a, b in zip(rings[:-1], rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for k in range(seg):
            k2 = (k + 1) % seg
            if len(a) == 1:
                bm.faces.new((a[0], b[k], b[k2]))
            elif len(b) == 1:
                bm.faces.new((a[k], b[0], a[k2]))
            else:
                bm.faces.new((a[k], b[k], b[k2], a[k2]))
    if cap and len(rings[0]) > 1:
        bm.faces.new(rings[0])
    if cap and len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    return bm


def cyl(axis, c, t0, t1, r, ch=0.0003, seg=16):
    return lathe([(t0, r - ch), (t0 + (ch if t1 > t0 else -ch), r), (t1 - (ch if t1 > t0 else -ch), r), (t1, r - ch)], seg, axis, c)


def screw(axis, c, t_base, t_top, r, socket=0.55, depth=0.0010, ch=0.0003, seg=14):
    """Button head with a round recess; the top is at t_top."""
    s = 1.0 if t_top > t_base else -1.0
    rs = r * socket
    prof = [(t_base, r), (t_top - s * ch, r), (t_top, r - ch), (t_top, rs), (t_top - s * depth, rs * 0.8), (t_top - s * depth, 0.0)]
    return lathe(prof, seg, axis, c)


def loft(rings, cap=True, closed=True):
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vr[:-1], vr[1:]):
        for k in range(n if closed else n - 1):
            k2 = (k + 1) % n
            bm.faces.new((a[k], b[k], b[k2], a[k2]))
    if cap:
        bm.faces.new(vr[0])
        bm.faces.new(list(reversed(vr[-1])))
    return bm


def sweep(path, section):
    """Sweeps a section [(x, s)] along a path of (y, z) points; s is measured along the path normal."""
    rings = []
    n = len(path)
    for i, p in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, n - 1)]
        t = (Vector(b) - Vector(a)).normalized()
        nx, ny = -t.y, t.x
        rings.append([(x, p[0] + s * nx, p[1] + s * ny) for (x, s) in section])
    return loft(rings)


def tube(path, r, seg=8, normal=(0.0, 1.0, 0.0)):
    """Round wire along a closed planar path of 3D points."""
    N = Vector(normal).normalized()
    n = len(path)
    bm = bmesh.new()
    vr = []
    for i in range(n):
        p, a, b = Vector(path[i]), Vector(path[i - 1]), Vector(path[(i + 1) % n])
        t = (b - a).normalized()
        B = N.cross(t).normalized()
        vr.append([bm.verts.new(p + (B * cos(2 * pi * k / seg) + N * sin(2 * pi * k / seg)) * r) for k in range(seg)])
    for i in range(n):
        a, b = vr[i], vr[(i + 1) % n]
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((a[k], b[k], b[k2], a[k2]))
    return bm


def bm_object(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def fix_normals(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bm.calc_volume(signed=True) < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.normal_update()


def bisect(bm, co, no):
    return bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-7, plane_co=co, plane_no=no)


def boolean(bm, cutters, op="DIFFERENCE"):
    fix_normals(bm)
    ob = bm_object(bm, "bool_base")
    tools = []
    for cut in cutters:
        fix_normals(cut)
        oc = bm_object(cut, "bool_cut")
        tools.append(oc)
        m = ob.modifiers.new("b", "BOOLEAN")
        m.object = oc
        m.operation = op
        m.solver = "EXACT"
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = bmesh.new()
    out.from_mesh(me)
    for o in tools + [ob]:
        data = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(data)
    bpy.data.meshes.remove(me)
    return out


# ----------------------------------------------------------------------------- nodes and parts
class Node:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.l_base = self.bm.loops.layers.float_color.new("p_base")
        self.l_surf = self.bm.loops.layers.float_color.new("p_surf")
        self.l_misc = self.bm.loops.layers.float_color.new("p_misc")
        self.l_nrm = self.bm.loops.layers.float_vector.new("p_nrm")
        self.parts = 0
        self.log = []


PART_SEED = [0]


def add(node, bm, mat, bevel=0.0, seg=1, bevel_angle=radians(30.0), sharp=radians(50.0), power=2.0,
        wear=0.0016, dens=1.0, edges=None, clamp=True, profile=0.5, name="", radial=None, drop=None):
    """Finishes a part (bevel, shading normals, surface data) and appends it to a node.
    mat: material name or function(face) -> name.  wear: distance used for the edge-wear mask
    (keep it below half the wall thickness).  dens: relative texel density.
    drop: function(face) -> True for faces that are never visible and can be left out."""
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges[:])
    fix_normals(bm)
    if bevel > 0.0:
        if edges is None:
            es = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > bevel_angle]
        else:
            es = edges(bm)
        if es:
            bmesh.ops.bevel(bm, geom=es, offset=bevel, offset_type="OFFSET", segments=seg, profile=profile,
                            affect="EDGES", clamp_overlap=clamp)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges[:])
        bm.normal_update()
    # sharp edges
    for e in bm.edges:
        e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(0.0) < sharp
    # face weighted normals per smoothing fan
    weight = {f: max(f.calc_area(), 1e-12) ** power for f in bm.faces}
    cn = {}
    for v in bm.verts:
        loops = list(v.link_loops)
        done = set()
        for l in loops:
            if l in done:
                continue
            fan = [l]
            done.add(l)
            stack = [l]
            while stack:
                cur = stack.pop()
                for e in (cur.edge, cur.link_loop_prev.edge):
                    if not e.smooth:
                        continue
                    for f2 in e.link_faces:
                        if f2 is cur.face:
                            continue
                        for l2 in f2.loops:
                            if l2.vert is v and l2 not in done:
                                done.add(l2)
                                fan.append(l2)
                                stack.append(l2)
            nrm = Vector((0.0, 0.0, 0.0))
            for fl in fan:
                nrm += fl.face.normal * weight[fl.face]
            if nrm.length < 1e-12:
                nrm = l.face.normal.copy()
            nrm.normalize()
            for fl in fan:
                cn[fl] = nrm
    if radial is not None:      # snap normals of cylindrical sheets to the exact radial direction
        x0, z0 = radial
        for f in bm.faces:
            for l in f.loops:
                rdir = Vector((l.vert.co.x - x0, 0.0, l.vert.co.z - z0))
                if rdir.length < 1e-9:
                    continue
                rdir.normalize()
                d = f.normal.dot(rdir)
                if d > 0.8:
                    cn[l] = rdir
                elif d < -0.8:
                    cn[l] = -rdir
    # append
    PART_SEED[0] += 1
    rnd = (PART_SEED[0] * 0.6180339887) % 1.0
    dst = node.bm
    vmap = {}
    tris = 0
    for f in bm.faces:
        if drop is not None and drop(f):
            continue
        m = MATS[mat(f) if callable(mat) else mat]
        for v in f.verts:
            if v not in vmap:
                vmap[v] = dst.verts.new(v.co)
        try:
            nf = dst.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        nf.smooth = True
        tris += len(f.verts) - 2
        base = (m["col"][0], m["col"][1], m["col"][2], 1.0)
        surf = (m["metal"], m["rough"], m["wear"] / 8.0, m["bump"] / 8.0)
        misc = (wear, dens, rnd, 1.0)
        for ls, ld in zip(f.loops, nf.loops):
            ld[node.l_base] = base
            ld[node.l_surf] = surf
            ld[node.l_misc] = misc
            ld[node.l_nrm] = cn[ls]
    for e in bm.edges:
        if e.verts[0] in vmap and e.verts[1] in vmap:
            de = dst.edges.get((vmap[e.verts[0]], vmap[e.verts[1]]))
            if de is not None:
                de.smooth = e.smooth
    node.parts += 1
    node.log.append((name, tris))
    bm.free()
    return tris


def faces_in_box(lo, hi, eps=0.00012):
    def test(f):
        for v in f.verts:
            c = v.co
            if not (lo[0] - eps <= c.x <= hi[0] + eps and lo[1] - eps <= c.y <= hi[1] + eps and lo[2] - eps <= c.z <= hi[2] + eps):
                return False
        return True
    return test


def socket_mat(axis, c, r, outer="steel"):
    """Material function for screw heads: dark inside the recess."""
    def mat(f):
        for v in f.verts:
            co = v.co
            if axis == "x":
                d = sqrt((co.y - c[0]) ** 2 + (co.z - c[1]) ** 2)
            elif axis == "y":
                d = sqrt((co.x - c[0]) ** 2 + (co.z - c[1]) ** 2)
            else:
                d = sqrt((co.x - c[0]) ** 2 + (co.y - c[1]) ** 2)
            if d > r:
                return outer
        return "void"
    return mat


# ----------------------------------------------------------------------------- shell
def shell_bm(axis="y", c=(0.0, 0.0), t0=0.0, flip=False, seg=20, length=SHELL_L):
    """12 gauge shell, base (brass) at t0, crimp at t0 + length (or the other way round when flipped)."""
    r, L = SHELL_R, length
    prof = [(0.0006, 0.0), (0.0006, 0.0030), (0.0, 0.0033), (0.0, 0.0106), (0.0003, 0.01125), (0.0014, 0.01125),
            (0.0019, r + 0.0003), (0.0160, r + 0.0003), (0.0163, r), (L - 0.0032, r), (L - 0.0012, r - 0.0007),
            (L, r - 0.0022), (L - 0.0005, 0.0050), (L - 0.0010, 0.0)]
    s = -1.0 if flip else 1.0
    base = t0 + (L if flip else 0.0)
    prof = [(base + s * t, rr) for (t, rr) in prof]
    bm = lathe(prof, seg, axis, c)
    ax = {"x": 0, "y": 1, "z": 2}[axis]

    def mat(f):
        t = max((v.co[ax] - base) * s for v in f.verts)
        rad = 0.0
        for v in f.verts:
            co = v.co
            if axis == "y":
                d = sqrt((co.x - c[0]) ** 2 + (co.z - c[1]) ** 2)
            elif axis == "x":
                d = sqrt((co.y - c[0]) ** 2 + (co.z - c[1]) ** 2)
            else:
                d = sqrt((co.x - c[0]) ** 2 + (co.y - c[1]) ** 2)
            rad = max(rad, d)
        if t < 0.0008 and rad < 0.0031:
            return "bright"
        if t < 0.0162:
            return "brass"
        return "hull"
    return bm, mat


# ----------------------------------------------------------------------------- the gun
def build_shotgun():
    body, pump, shell = Node("Body"), Node("Pump"), Node("Shell")
    W = RCV_W

    # ================= receiver =================
    zb = -0.0190                    # belt line: the upper part is slightly narrower
    Wu = W - 0.0009
    sec = fillet_path([(-W, RCV_BOT, 0.003), (W, RCV_BOT, 0.003), (W, zb), (Wu, zb + 0.0009), (Wu, RCV_TOP, 0.010),
                       (-Wu, RCV_TOP, 0.010), (-Wu, zb + 0.0009), (-W, zb)], step=radians(11.25))
    rcv = prism(sec, 0.0, RCV_L, "y")
    bisect(rcv, (0.0, 0.150, 0.0), (0.0, 1.0, 0.0))        # keeps the ports from making faces with holes
    ey0, ey1, ez0, ez1 = EJECT
    ej = prism(fillet_path([(ey0, ez0, 0.004), (ey1, ez0, 0.004), (ey1, ez1, 0.004), (ey0, ez1, 0.004)]), -0.0010, 0.030, "x")
    ly0, ly1, lw = LOAD
    ld = prism(fillet_path([(-lw, ly0, 0.003), (lw, ly0, 0.003), (lw, ly1, 0.003), (-lw, ly1, 0.003)]), -0.060, -0.022, "z")
    hz, hy = -0.0385, 0.1015                               # cut for the trigger housing
    hc = box(-0.03, 0.03, -0.01, hy, -0.07, hz)
    rcv = boolean(rcv, [ej, ld, hc])
    in_ej = faces_in_box((-0.0012, ey0, ez0), (W - 0.0012, ey1, ez1))
    in_ld = faces_in_box((-lw, ly0, -0.0222), (lw, ly1, RCV_BOT + 0.0012))

    def rcv_drop(f):
        if f.normal.z < -0.5 and all(v.co.z > hz - 0.0006 and v.co.y < hy + 0.0005 for v in f.verts):
            return True
        if f.normal.y < -0.5 and all(abs(v.co.y - hy) < 0.0008 and v.co.z < hz + 0.0008 for v in f.verts):
            return True
        return False
    add(body, rcv, lambda f: "inside" if (in_ej(f) or in_ld(f)) else "alu", bevel=0.0007, name="receiver", dens=1.25, drop=rcv_drop)

    # bolt seen through the ejection port
    add(body, cyl("y", (0.0, 0.0), 0.099, 0.197, 0.0108, 0.0004, 28), "bright", name="bolt", dens=0.9)
    add(body, box(0.0098, 0.0120, 0.166, 0.1885, -0.0030, 0.0032), "steel", bevel=0.0004, name="extractor")
    add(body, box(0.0030, 0.0118, 0.118, 0.150, 0.0085, 0.0112), "steel", bevel=0.0004, name="bolt lug")
    # elevator and magazine mouth inside the loading port
    add(body, box(-0.0106, 0.0106, 0.108, 0.198, -0.0415, -0.0398), "bright", bevel=0.0004, name="elevator", dens=0.7)
    add(body, lathe([(0.2030, 0.0101), (0.2030, 0.0116), (0.2066, 0.0116), (0.2066, 0.0101)], 24, "y", (0.0, ZT)), "steel", name="mag mouth", dens=0.6, wear=0.0005)

    # trigger housing, guard, trigger
    hous = prism([(-0.0005, -0.0380), (0.1012, -0.0380), (0.1012, -0.0462), (0.0975, -0.0492), (0.0100, -0.0492), (-0.0005, -0.0470)], -W + 0.0006, W - 0.0006, "x")
    add(body, hous, "polymer", bevel=0.0007, name="trigger housing", drop=lambda f: f.normal.z > 0.5)
    gpath = fillet_path([(0.0985, -0.0460), (0.0880, -0.0815, 0.010), (0.0130, -0.0815, 0.010), (0.0040, -0.0580)], closed=False, step=radians(10))
    add(body, sweep([(p.x, p.y) for p in gpath], rrect(0.0160, 0.0045, 0.0014, 3)), "polymer", sharp=radians(40), name="trigger guard")
    tpath = fillet_path([(0.0420, -0.0460), (0.0375, -0.0580, 0.012), (0.0368, -0.0670, 0.012), (0.0400, -0.0760)], closed=False, step=radians(8))
    add(body, sweep([(p.x, p.y) for p in tpath], rrect(0.0080, 0.0045, 0.0015, 2)), "steel", sharp=radians(40), name="trigger", wear=0.0012)
    # slide release, left front of the guard
    rel = prism([(0.0860, -0.0470), (0.0980, -0.0470), (0.0980, -0.0550), (0.0955, -0.0585), (0.0885, -0.0585), (0.0860, -0.0550)], -0.0138, -0.0092, "x")
    add(body, rel, "steel", bevel=0.0005, name="slide release")

    # pins and bolts on the receiver sides
    add(body, cyl("x", (0.0200, -0.0310), -W - 0.0004, W + 0.0004, 0.0021, 0.0003, 12), "steel", name="pin rear", wear=0.0008)
    add(body, cyl("x", (0.0600, -0.0320), -W - 0.0002, W + 0.0002, 0.0029, 0.0003, 14), "steel", name="pin trigger", wear=0.0008)
    for (py, pz) in ((0.0600, -0.0320), (0.1960, -0.0340)):
        add(body, screw("x", (py, pz), W - 0.001, W + 0.0015, 0.0043), socket_mat("x", (py, pz), 0.0025), name="side bolt", wear=0.0008)

    # tang safety on top of the receiver rear
    add(body, prism(fillet_path([(-0.0058, 0.0040, 0.002), (0.0058, 0.0040, 0.002), (0.0058, 0.0270, 0.002), (-0.0058, 0.0270, 0.002)]), RCV_TOP - 0.0005, RCV_TOP + 0.0006, "z"), "steel", bevel=0.0003, name="safety plate", wear=0.0005)
    sb_pts = [(0.0150, RCV_TOP + 0.0004)]
    for k in range(5):
        y = 0.0150 + k * 0.0020
        sb_pts += [(y + 0.0003, RCV_TOP + 0.0030), (y + 0.0014, RCV_TOP + 0.0030), (y + 0.0020, RCV_TOP + 0.0020)]
    sb_pts[-1] = (0.0250, RCV_TOP + 0.0004)
    add(body, prism(sb_pts, -0.0046, 0.0046, "x"), "steel", bevel=0.0003, name="safety button", wear=0.0006)
    add(body, cyl("z", (0.0, 0.0095), RCV_TOP + 0.0004, RCV_TOP + 0.0009, 0.0017, 0.0002, 12), "red", name="safety dot")

    # sling plate between receiver and stock, loop on the left
    plate = fillet_path([(-0.0213, -0.0478, 0.003), (0.0213, -0.0478, 0.003), (0.0213, 0.0178, 0.0105), (-0.0213, 0.0178, 0.0105)], step=radians(11.25))
    add(body, prism(plate, -0.0030, 0.0003, "y"), "steel", bevel=0.0005, name="sling plate")
    lp = fillet_path([(-0.0195, -0.0230, 0.004), (-0.0195, 0.0070, 0.004), (-0.0350, 0.0070, 0.0055), (-0.0350, -0.0230, 0.0055)], step=radians(22.5))
    add(body, tube([(p.x, -0.00135, p.y) for p in lp], 0.0017, 8), "steel", name="sling loop", sharp=radians(60), wear=0.0006)

    # ================= picatinny rail =================
    z0 = RCV_TOP - 0.0005
    zf = z0 + 0.0065
    base = [(-0.0078, z0), (0.0078, z0), (0.0078, z0 + 0.0030), (0.0106, z0 + 0.0058), (0.0106, zf), (-0.0106, zf), (-0.0106, z0 + 0.0058), (-0.0078, z0 + 0.0030)]
    add(body, prism(base, 0.0300, 0.2048, "y"), "alu", bevel=0.0004, name="rail base", dens=1.3, wear=0.0012, drop=lambda f: f.normal.z < -0.9)
    tooth = [(-0.0106, zf - 0.0004), (0.0106, zf - 0.0004), (0.0106, zf + 0.0018), (0.0094, zf + 0.0030), (-0.0094, zf + 0.0030), (-0.0106, zf + 0.0018)]
    for k in range(18):
        y = 0.0300 + k * 0.0100
        if 0.0335 < y + 0.0024 < 0.0625:      # hidden inside the rear sight base
            continue
        add(body, prism(tooth, y, y + 0.0048, "y"), "alu", bevel=0.0003, name="rail tooth", dens=1.3, wear=0.0012, drop=lambda f: f.normal.z < -0.9)
    for y in (0.0874, 0.1474, 0.1874):
        add(body, screw("z", (0.0, y), zf - 0.0004, zf + 0.0009, 0.0021, 0.6, 0.0008, 0.0002, 10), socket_mat("z", (0.0, y), 0.0014), name="rail screw", wear=0.0005)

    # ================= ghost ring rear sight =================
    y0, y1 = 0.0340, 0.0620
    sbase = prism([(y0, 0.0195), (y1, 0.0195), (y1, 0.0285), (y1 - 0.0015, 0.0300), (y0 + 0.0015, 0.0300), (y0, 0.0285)], -0.0135, 0.0135, "x")
    add(body, sbase, "steel", bevel=0.0005, name="rear sight base", dens=1.5)
    wing = fillet_path([(y0 + 0.002, 0.0290), (y1 - 0.002, 0.0290), (y1 - 0.002, 0.0400, 0.003), (y1 - 0.0085, 0.0470, 0.004), (y0 + 0.0085, 0.0470, 0.004), (y0 + 0.002, 0.0400, 0.003)], step=radians(15))
    add(body, prism(wing, 0.0100, 0.0130, "x"), "steel", bevel=0.0005, name="rear sight wing", dens=1.5, wear=0.0011)
    add(body, prism(wing, -0.0130, -0.0100, "x"), "steel", bevel=0.0005, name="rear sight wing", dens=1.5, wear=0.0011)
    ry = REAR_SIGHT_Y
    ring = lathe([(ry - 0.0008, 0.0040), (ry - 0.0012, 0.0044), (ry - 0.0012, 0.0055), (ry - 0.0009, 0.0058), (ry + 0.0009, 0.0058),
                  (ry + 0.0012, 0.0055), (ry + 0.0012, 0.0044), (ry + 0.0008, 0.0040), (ry - 0.0008, 0.0040)], 32, "y", (0.0, SIGHT_Z), cap=False)
    add(body, ring, "steel", name="ghost ring", dens=1.6, wear=0.0005)
    add(body, box(-0.0050, 0.0050, ry - 0.0016, ry + 0.0016, 0.0295, 0.0328), "steel", bevel=0.0004, name="ring carrier", dens=1.5, wear=0.0008)
    add(body, cyl("x", (ry, 0.0314), -0.0142, 0.0150, 0.0014, 0.0002, 10), "steel", name="windage screw", wear=0.0005)
    knob = lathe([(0.0138, 0.0030), (0.0142, 0.0040), (0.0166, 0.0040), (0.0170, 0.0034), (0.0170, 0.0)], 20, "x", (ry, 0.0314),
                 radial=lambda k, t, r: r * (0.93 if (k % 2 and r > 0.0038) else 1.0))
    add(body, knob, "steel", name="windage knob", wear=0.0006, dens=1.3)
    add(body, cyl("x", (0.0560, 0.0235), -0.0150, 0.0150, 0.0030, 0.0004, 6), "steel", name="sight clamp bolt", wear=0.0008)

    # ================= barrel, magazine tube =================
    R = BARREL_R
    barrel = lathe([(0.2000, 0.0118), (0.2180, 0.0118), (0.2180, 0.0131), (0.2290, 0.0131), (0.2305, 0.0117), (0.3300, R), (MUZZLE_Y - 0.0006, R),
                    (MUZZLE_Y, R - 0.0006), (MUZZLE_Y, 0.0098), (MUZZLE_Y - 0.0008, 0.00925), (MUZZLE_Y - 0.060, 0.00925), (MUZZLE_Y - 0.060, 0.0)], 40, "y", (0.0, 0.0))
    add(body, barrel, lambda f: "void" if all(sqrt(v.co.x ** 2 + v.co.z ** 2) < 0.0094 for v in f.verts) else "steel", name="barrel", sharp=radians(40),
        drop=lambda f: all(v.co.y < 0.2185 for v in f.verts))
    tube_m = lathe([(0.2140, 0.0125), (0.2200, 0.0125), (0.2200, 0.0137), (0.2262, 0.0137), (0.2270, 0.0125), (0.6260, 0.0125)], 32, "y", (0.0, ZT))
    add(body, tube_m, "steel", name="magazine tube", sharp=radians(40), drop=lambda f: all(v.co.y < 0.2195 for v in f.verts) or all(v.co.y > 0.6255 for v in f.verts))

    def cap_radial(k, t, r):
        return r * (0.955 if (k % 2 and 0.6275 < t < 0.6465 and r > 0.0135) else 1.0)
    cap = lathe([(0.6240, 0.0128), (0.6248, 0.0140), (0.6265, 0.0140), (0.6275, 0.0143), (0.6465, 0.0143), (0.6475, 0.0140), (0.6500, 0.0136), (0.6535, 0.0112), (0.6535, 0.0)], 48, "y", (0.0, ZT), radial=cap_radial)
    add(body, cap, "steel", name="magazine cap", sharp=radians(40), wear=0.0010, drop=lambda f: all(v.co.y < 0.6241 for v in f.verts))
    add(body, lathe([(0.6525, 0.0050), (0.6590, 0.0050), (0.6600, 0.0042), (0.6600, 0.0)], 14, "y", (0.0, ZT)), "steel", name="swivel stud", wear=0.0008)
    add(body, cyl("x", (0.6565, ZT), -0.0056, 0.0056, 0.0016, 0.0002, 8), "void", name="swivel hole")

    # barrel clamp
    r1, r2, nx = 0.0138, 0.0153, 0.0068
    zc1 = -sqrt(r1 * r1 - nx * nx)
    zc2 = ZT + sqrt(r2 * r2 - nx * nx)
    a_s = atan2(zc1, nx)
    b_s = atan2(zc2 - ZT, -nx)
    b_e = atan2(zc2 - ZT, nx) + 2 * pi
    cl = arc(0, 0, r1, a_s, pi - a_s, 30) + arc(0, ZT, r2, b_s, b_e, 32)
    add(body, prism(cl, 0.6040, 0.6180, "y"), "steel", bevel=0.0006, name="barrel clamp", sharp=radians(40))
    add(body, cyl("x", (0.6110, -0.0146), -0.0098, 0.0098, 0.0032, 0.0004, 6), "steel", name="clamp bolt", wear=0.0008)

    # ================= heat shield =================
    add(body, heat_shield(), "steel", name="heat shield", sharp=radians(60), wear=0.0004, radial=(0.0, 0.0), dens=1.2)
    for ty in (0.250, 0.416, 0.585):
        for sx in (1, -1):
            tab = box(sx * 0.0141, sx * 0.0153, ty - 0.0060, ty + 0.0060, -0.0056, -0.0005)
            add(body, tab, "steel", bevel=0.0003, name="shield tab", wear=0.0004)
            sc = screw("x", (ty, -0.0030), sx * 0.0150, sx * 0.0164, 0.0020, 0.55, 0.0006, 0.0002, 10)
            add(body, sc, socket_mat("x", (ty, -0.0030), 0.0012), name="shield screw", wear=0.0005)

    # ================= front sight =================
    add(body, lathe([(0.6300, 0.0108), (0.6300, 0.0128), (0.6308, 0.0135), (0.6612, 0.0135), (0.6620, 0.0128), (0.6620, 0.0108)], 36, "y", (0.0, 0.0), cap=False), "steel", name="front sight band", sharp=radians(40))
    tower = prism([(0.6310, 0.0060), (0.6610, 0.0060), (0.6610, 0.0170), (0.6570, 0.0290), (0.6370, 0.0290), (0.6310, 0.0170)], -0.0085, 0.0085, "x")
    add(body, tower, "steel", bevel=0.0006, name="front sight tower", dens=1.3, drop=lambda f: f.normal.z < -0.9)
    fw = fillet_path([(0.6375, 0.0280), (0.6565, 0.0280), (0.6565, 0.0365, 0.002), (0.6525, 0.0420, 0.003), (0.6415, 0.0420, 0.003), (0.6375, 0.0365, 0.002)], step=radians(15))
    add(body, prism(fw, 0.0060, 0.0085, "x"), "steel", bevel=0.0005, name="front sight wing", dens=1.4, wear=0.0010)
    add(body, prism(fw, -0.0085, -0.0060, "x"), "steel", bevel=0.0005, name="front sight wing", dens=1.4, wear=0.0010)
    add(body, box(-0.0012, 0.0012, FRONT_SIGHT_Y - 0.0015, FRONT_SIGHT_Y + 0.0015, 0.0280, SIGHT_Z), "steel", bevel=0.0002, name="front sight post", dens=1.6, wear=0.0004)
    add(body, cyl("y", (0.0, SIGHT_Z - 0.0019), FRONT_SIGHT_Y - 0.0017, FRONT_SIGHT_Y - 0.0010, 0.0009, 0.0001, 10), "white", name="front sight dot", dens=1.6)

    # ================= stock with pistol grip and butt pad =================
    add_stock(body)

    # ================= side saddle (left) =================
    add_saddle(body)

    # ================= pump =================
    add_forend(pump)

    # ================= loose shell =================
    sbm, smat = shell_bm("y", (0.0, 0.0), -SHELL_L / 2)
    add(shell, sbm, smat, name="shell", sharp=radians(40), wear=0.0008)

    return body, pump, shell


def heat_shield():
    R1, R0 = 0.0153, 0.0143
    y0, y1 = 0.2330, 0.5990
    hy, rh = 0.00475, 0.0040
    ni = int((y1 - y0 - 0.020) / (2 * hy))
    ys = y0 + ((y1 - y0) - ni * 2 * hy) / 2
    ylines = [y0] + [ys + 2 * hy * i for i in range(ni + 1)] + [y1]
    alines = [radians(a) for a in (-98, -90, -72, -54, -36, -18, 0, 18, 36, 54, 72, 90, 98)]
    bm = bmesh.new()

    def P(y, a, R):
        return (R * sin(a), y, R * cos(a))

    grid = {}

    def gv(i, j, layer):
        key = (i, j, layer)
        if key not in grid:
            grid[key] = bm.verts.new(P(ylines[i], alines[j], R1 if layer else R0))
        return grid[key]

    hole_rings = {}
    for layer in (1, 0):
        R = R1 if layer else R0
        for i in range(len(ylines) - 1):
            for j in (0, 11):
                bm.faces.new((gv(i, j, layer), gv(i + 1, j, layer), gv(i + 1, j + 1, layer), gv(i, j + 1, layer)))
            for row in range(5):
                j0 = 1 + 2 * row
                cell = i - 1
                is_hole = 0 <= cell < ni and (cell + row) % 2 == 0
                if not is_hole:
                    for j in (j0, j0 + 1):
                        bm.faces.new((gv(i, j, layer), gv(i + 1, j, layer), gv(i + 1, j + 1, layer), gv(i, j + 1, layer)))
                    continue
                yc = (ylines[i] + ylines[i + 1]) / 2
                ac = alines[j0 + 1]
                h = [bm.verts.new(P(yc + rh * cos(radians(30 * k)), ac + rh * sin(radians(30 * k)) / R1, R)) for k in range(12)]
                hole_rings[(i, row, layer)] = h
                c0, m0, c1 = gv(i, j0, layer), gv(i, j0 + 1, layer), gv(i, j0 + 2, layer)
                c3, m1, c2 = gv(i + 1, j0, layer), gv(i + 1, j0 + 1, layer), gv(i + 1, j0 + 2, layer)
                tris = [(h[0], m1, c2), (h[0], c2, h[1]), (h[1], c2, h[2]), (h[2], c2, h[3]), (h[3], c2, c1),
                        (h[3], c1, h[4]), (h[4], c1, h[5]), (h[5], c1, h[6]), (h[6], c1, m0),
                        (h[6], m0, c0), (h[6], c0, h[7]), (h[7], c0, h[8]), (h[8], c0, h[9]), (h[9], c0, c3),
                        (h[9], c3, h[10]), (h[10], c3, h[11]), (h[11], c3, h[0]), (h[0], c3, m1)]
                for t in tris:
                    bm.faces.new(t)
    for (i, row, layer), h in hole_rings.items():
        if layer == 1:
            hi = hole_rings[(i, row, 0)]
            for k in range(12):
                k2 = (k + 1) % 12
                bm.faces.new((h[k], h[k2], hi[k2], hi[k]))
    ny, na = len(ylines), len(alines)
    for i in range(ny - 1):
        for j in (0, na - 1):
            bm.faces.new((gv(i, j, 1), gv(i + 1, j, 1), gv(i + 1, j, 0), gv(i, j, 0)))
    for j in range(na - 1):
        for i in (0, ny - 1):
            bm.faces.new((gv(i, j, 1), gv(i, j + 1, 1), gv(i, j + 1, 0), gv(i, j, 0)))
    return bm


STOCK_REAR = ((-0.307, -0.007), (-0.302, -0.134))     # heel and toe of the butt
GRIP_AXIS = Vector((0.0, -0.280, -0.960)).normalized()
GRIP_BAND = (Vector((0.0, -0.016, -0.080)), Vector((0.0, -0.040, -0.128)))    # textured part of the grip


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def stock_halfwidth(y, z):
    return 0.0190 - 0.0064751 * y + 0.020317 * (z - 0.012)


def stock_rim(y, z):
    """Radius of the rounded edge around the stock outline: fuller on the pistol grip."""
    grip = smooth((-0.052 - z) / 0.025) * smooth((y + 0.088) / 0.015)
    foot = smooth((-0.122 - z) / 0.018)
    r = 0.0090 + 0.0040 * grip * (1.0 - foot)
    hidden = smooth((y - 0.004) / 0.008)
    return r * (1.0 - hidden) + 0.0012 * hidden


def resample(path, max_len):
    out = []
    n = len(path)
    for i in range(n):
        a, b = Vector(path[i]), Vector(path[(i + 1) % n])
        k = max(1, int(ceil((b - a).length / max_len)))
        for j in range(k):
            out.append(a.lerp(b, j / k))
    return out


def rounded_slab(outline, hw_fn, rim_fn, K=4):
    """Flat-sided body with a rounded rim, from a counter-clockwise (y, z) outline."""
    n = len(outline)
    pts = [Vector((p[0], p[1])) for p in outline]
    nrm = []
    for i in range(n):
        t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        nrm.append(Vector((-t.y, t.x)))
    bm = bmesh.new()
    rings = {}
    for sx in (1, -1):
        rs = []
        for k in range(K + 1):
            th = (pi / 2) * k / K
            ring = []
            for i in range(n):
                r = rim_fn(pts[i].x, pts[i].y)
                q = pts[i] + nrm[i] * (r * (1.0 - cos(th)))
                ring.append(bm.verts.new((sx * (hw_fn(q.x, q.y) - r + r * sin(th)), q.x, q.y)))
            rs.append(ring)
        rings[sx] = rs
        for k in range(K):
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((rs[k][i], rs[k][j], rs[k + 1][j], rs[k + 1][i]))
        bm.faces.new(rs[K])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((rings[1][0][i], rings[1][0][j], rings[-1][0][j], rings[-1][0][i]))
    return bm, rings


def add_stock(body):
    heel, toe = STOCK_REAR
    pts = [(0.012, 0.0125), (-0.016, 0.0125, 0.012), (-0.064, 0.0050, 0.045), (heel[0], heel[1], 0.011), (toe[0], toe[1], 0.011),
           (-0.165, -0.074, 0.25), (-0.036, -0.044, 0.016), (-0.052, -0.095, 0.08), (-0.064, -0.150, 0.010), (-0.021, -0.143, 0.011),
           (0.007, -0.056, 0.004), (0.014, -0.052)]
    outline = resample(fillet_path(pts, step=radians(10)), 0.008)
    if sum(outline[i - 1].x * outline[i].y - outline[i].x * outline[i - 1].y for i in range(len(outline))) < 0:
        outline.reverse()
    K = 4
    bm, rings = rounded_slab(outline, stock_halfwidth, stock_rim, K)

    # the pistol grip gets its own side faces and a textured band around it
    def nearest(ring, y, z):
        return min(ring, key=lambda v: (v.co.y - y) ** 2 + (v.co.z - z) ** 2)
    la = lb = None
    for sx in (1, -1):
        va, vb = nearest(rings[sx][K], -0.050, -0.058), nearest(rings[sx][K], -0.002, -0.064)
        face = next(f for f in va.link_faces if len(f.verts) > 4 and vb in f.verts)
        bmesh.utils.face_split(face, va, vb)
        la, lb = Vector((va.co.y, va.co.z)), Vector((vb.co.y, vb.co.z))

    def in_grip(co):
        return co.y > -0.075 and (lb.x - la.x) * (co.z - la.y) - (lb.y - la.y) * (co.y - la.x) < 1e-7
    for co in GRIP_BAND:
        fs = [f for f in bm.faces if all(in_grip(v.co) for v in f.verts)]
        geom = list({v for f in fs for v in f.verts}) + list({e for f in fs for e in f.edges}) + fs
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=co, plane_no=GRIP_AXIS)

    # recessed panels in the sides of the butt
    pocket = fillet_path([(-0.085, -0.012, 0.006), (-0.262, -0.0208, 0.006), (-0.258, -0.097, 0.006), (-0.165, -0.0575, 0.03), (-0.085, -0.039, 0.006)], step=radians(15))
    bisect(bm, (0.0, -0.170, 0.0), (0.0, 1.0, 0.0))
    cutters = []
    for sx in (1, -1):
        cb = prism(pocket, 1.0, 2.0, "x")
        for v in cb.verts:
            h = stock_halfwidth(v.co.y, v.co.z)
            v.co.x = sx * (h - 0.0015 if v.co.x < 1.5 else h + 0.02)
        cutters.append(cb)
    bm = boolean(bm, cutters)
    bm.normal_update()

    def in_pocket(e):
        for v in e.verts:
            if not (-0.2635 < v.co.y < -0.0835 and -0.0985 < v.co.z < -0.0105):
                return False
            if abs(v.co.x) < stock_halfwidth(v.co.y, v.co.z) - 0.0017:
                return False
        return True
    es = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > radians(30) and in_pocket(e)]
    bmesh.ops.bevel(bm, geom=es, offset=0.0006, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)

    # butt pad: cut a groove where the rubber starts
    d = Vector((0.0, toe[0] - heel[0], toe[1] - heel[1])).normalized()
    n = Vector((0.0, -d.z, d.y))
    if n.y < 0:
        n = -n
    p0 = Vector((0.0, heel[0], heel[1]))
    cuts = []
    for off in (0.0236, 0.0228, 0.0220):
        res = bisect(bm, p0 + n * off, n)
        cuts.append([g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMVert)])
    bm.normal_update()
    for v in cuts[1]:
        v.co -= v.normal * 0.0006
    mid = p0 + n * 0.0228

    def mat(f):
        c = f.calc_center_median()
        if (c - mid).dot(n) < 0:
            return "rubber"
        if in_grip(c) and (c - GRIP_BAND[0]).dot(GRIP_AXIS) > 0 and (c - GRIP_BAND[1]).dot(GRIP_AXIS) < 0:
            return "grip"
        return "polymer"
    add(body, bm, mat, name="stock", dens=0.8, wear=0.0030, drop=lambda f: all(v.co.y > 0.0005 and v.co.z > -0.036 for v in f.verts))


def add_saddle(body):
    W = RCV_W
    plate = fillet_path([(0.040, -0.0345, 0.003), (0.196, -0.0345, 0.003), (0.196, 0.0065, 0.003), (0.040, 0.0065, 0.003)], step=radians(15))
    add(body, prism(plate, -W - 0.0030, -W + 0.0014, "x"), "alu", bevel=0.0005, name="saddle plate", drop=lambda f: f.normal.x > 0.9)
    n_sh, pitch, y_first = 6, 0.0235, 0.0595
    xc = -W - 0.0030 - 0.0118
    rr = 0.0123
    # carrier outline in (x, y): flat against the plate, scalloped outside
    half = pitch / 2
    dip = sqrt(rr * rr - half * half)
    pts = [Vector((-W - 0.0028, y_first - 0.0135)), Vector((-W - 0.0028, y_first + (n_sh - 1) * pitch + 0.0135))]
    for i in reversed(range(n_sh)):
        yc = y_first + i * pitch
        a0 = atan2(half, -dip) if i < n_sh - 1 else radians(100)
        a1 = atan2(-half, -dip) + 2 * pi if i > 0 else radians(260)
        pts += arc(xc, yc, rr, a0, a1, 10)
    add(body, prism(pts, -0.0285, 0.0005, "z"), "polymer", bevel=0.0006, name="saddle carrier")
    sl = 0.060      # unfired, crimped length
    for i in range(n_sh):
        yc = y_first + i * pitch
        sbm, smat = shell_bm("z", (xc, yc), -0.0460, flip=i >= 4, seg=18, length=sl)
        add(body, sbm, smat, name="saddle shell", sharp=radians(40), wear=0.0008, dens=0.9)
    for (sy, sz) in ((0.046, 0.0035), (0.190, 0.0035), (0.046, -0.0315), (0.190, -0.0315)):
        sc = screw("x", (sy, sz), -W - 0.0025, -W - 0.0042, 0.0021, 0.55, 0.0006, 0.0002, 10)
        add(body, sc, socket_mat("x", (sy, sz), 0.0013), name="saddle screw", wear=0.0005)


def add_forend(pump):
    top = -0.0066
    rc = sqrt(0.0112 ** 2 + top ** 2)
    a = 0.0240
    b = 0.0272
    zc = -0.0280
    right = fillet_path([(0.0112, top), (0.0222, top, 0.0028), (a, zc)], closed=False, step=radians(15))
    pts = [p for p in right[:-1]]
    pts += arc(0.0, zc, a, 0.0, -pi, 26, ry=b)
    left = [Vector((-p.x, p.y)) for p in reversed(right[:-1])]
    pts += left
    ang0 = atan2(top, -0.0112)
    ang1 = atan2(top, 0.0112)
    ch = arc(0.0, 0.0, rc, ang0 + 2 * pi, ang1 + 2 * pi, 8)
    pts += ch[1:-1]
    weights = []
    for p in pts:
        on_channel = abs(sqrt(p.x * p.x + p.y * p.y) - rc) < 1e-5 and abs(p.x) < 0.0112
        w = 0.0 if on_channel else max(0.0, min(1.0, (top - 0.001 - p.y) / 0.008))
        weights.append(w * w * (3 - 2 * w))
    prof = [(FOREND_Y0, 1.035), (FOREND_Y0 + 0.0016, 1.095), (FOREND_Y0 + 0.0125, 1.095), (FOREND_Y0 + 0.0175, 1.0)]
    for k in range(10):
        y = 0.3480 + k * 0.0145
        prof += [(y, 1.0), (y + 0.0018, 1.07), (y + 0.0092, 1.07), (y + 0.0110, 1.0)]
    prof += [(FOREND_Y1 - 0.0195, 1.0), (FOREND_Y1 - 0.0140, 1.105), (FOREND_Y1 - 0.0016, 1.105), (FOREND_Y1, 1.045)]
    rings = []
    for (y, s) in prof:
        ring = []
        for p, w in zip(pts, weights):
            k = 1.0 + (s - 1.0) * w
            ring.append((p.x * k, y, ZT + (p.y - ZT) * k))
        rings.append(ring)
    add(pump, loft(rings), "polymer", name="forend", sharp=radians(45), dens=1.1, wear=0.0022)
    for sx in (1, -1):
        bar = box(sx * 0.0131, sx * 0.0155, 0.190, FOREND_Y0 + 0.012, ZT - 0.0050, ZT + 0.0050)
        add(pump, bar, "steel", bevel=0.0005, name="action bar", wear=0.0008, dens=0.8)
    add(pump, lathe([(FOREND_Y1 - 0.002, 0.0150), (FOREND_Y1 + 0.0022, 0.0150), (FOREND_Y1 + 0.0030, 0.0142), (FOREND_Y1 + 0.0030, 0.0127), (FOREND_Y1 - 0.002, 0.0127)], 28, "y", (0.0, ZT), cap=False), "steel", name="forend nut", sharp=radians(40), wear=0.0006)
    add(pump, lathe([(FOREND_Y0 + 0.002, 0.0150), (FOREND_Y0 - 0.0022, 0.0150), (FOREND_Y0 - 0.0030, 0.0142), (FOREND_Y0 - 0.0030, 0.0127), (FOREND_Y0 + 0.002, 0.0127)], 28, "y", (0.0, ZT), cap=False), "steel", name="forend tube", sharp=radians(40), wear=0.0006)


# ----------------------------------------------------------------------------- objects
def node_object(node, shift):
    bm = node.bm
    for v in bm.verts:
        v.co -= shift
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    me = bpy.data.meshes.new(node.name)
    bm.to_mesh(me)
    bm.free()
    attr = me.attributes["p_nrm"]
    nrm = np.zeros(len(me.loops) * 3, dtype=np.float32)
    attr.data.foreach_get("vector", nrm)
    me.attributes.remove(attr)
    me.normals_split_custom_set(nrm.reshape(-1, 3).tolist())
    ob = bpy.data.objects.new(node.name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def bounds(ob):
    co = np.zeros(len(ob.data.vertices) * 3, dtype=np.float32)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) + np.array(ob.location, dtype=np.float32)
    return co.min(axis=0), co.max(axis=0)


def godot(v):
    """Blender (x, y, z) -> Godot (x, z, -y)."""
    return (round(v[0], 4), round(v[2], 4), round(-v[1], 4))


def preview_material():
    mat = bpy.data.materials.new("Preview")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    a1 = nt.nodes.new("ShaderNodeAttribute")
    a1.attribute_name = "p_base"
    a2 = nt.nodes.new("ShaderNodeAttribute")
    a2.attribute_name = "p_surf"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(a1.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(a2.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Red"], bsdf.inputs["Metallic"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def export(obs):
    """One glTF material per entry of MATS; every face goes to the entry it was built with."""
    names = list(MATS.keys())
    mats = []
    for key in names:
        m = MATS[key]
        mat = bpy.data.materials.new(key)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (m["col"][0], m["col"][1], m["col"][2], 1.0)
        bsdf.inputs["Metallic"].default_value = m["metal"]
        bsdf.inputs["Roughness"].default_value = m["rough"]
        mats.append(mat)
    table = np.array([[*MATS[k]["col"], MATS[k]["metal"], MATS[k]["rough"]] for k in names], dtype=np.float32)
    used = {}
    for ob in obs:
        me = ob.data
        for mat in mats:
            me.materials.append(mat)
        base = np.zeros(len(me.loops) * 4, dtype=np.float32)
        surf = np.zeros(len(me.loops) * 4, dtype=np.float32)
        me.attributes["p_base"].data.foreach_get("color", base)
        me.attributes["p_surf"].data.foreach_get("color", surf)
        base = base.reshape(-1, 4)
        surf = surf.reshape(-1, 4)
        for poly in me.polygons:
            first = poly.loop_start
            value = np.array([base[first, 0], base[first, 1], base[first, 2], surf[first, 0], surf[first, 1]], dtype=np.float32)
            index = int(((table - value) ** 2).sum(axis=1).argmin())
            poly.material_index = index
            used[names[index]] = used.get(names[index], 0) + 1
        for helper in ("p_base", "p_surf", "p_misc"):
            me.attributes.remove(me.attributes[helper])
    print("MATERIALS", used)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=False, export_yup=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False)
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB), "bytes")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body, pump, shell = build_shotgun()
    for node in (body, pump, shell):
        agg = {}
        for name, tris in node.log:
            agg[name] = agg.get(name, 0) + tris
        print("NODE", node.name, "parts", node.parts, "tris", sum(agg.values()))
        for name, tris in sorted(agg.items(), key=lambda kv: -kv[1]):
            print("   %-22s %6d" % (name, tris))
    shell_pos = Vector((0.0, (LOAD[0] + LOAD[1]) / 2, RCV_BOT - SHELL_R - 0.006))
    root = bpy.data.objects.new("Shotgun", None)
    bpy.context.scene.collection.objects.link(root)
    obs = []
    zero = Vector((0.0, 0.0, 0.0))
    for node, shift, loc in ((body, ORIGIN, zero), (pump, ORIGIN, zero), (shell, zero, shell_pos - ORIGIN)):
        ob = node_object(node, shift)
        ob.location = loc
        ob.parent = root
        obs.append(ob)
    bpy.context.view_layer.update()
    total = 0
    for ob in obs:
        lo, hi = bounds(ob)
        total += len(ob.data.polygons)
        print("OBJECT", ob.name, "tris", len(ob.data.polygons), "verts", len(ob.data.vertices), "min", lo.round(4), "max", hi.round(4))
    print("TOTAL_TRIS", total)

    def pt(x, y, z):
        return godot(Vector((x, y, z)) - ORIGIN)
    print("POINT muzzle", pt(0, MUZZLE_Y, 0))
    print("POINT rear_sight_aperture", pt(0, REAR_SIGHT_Y, SIGHT_Z))
    print("POINT front_sight_tip", pt(0, FRONT_SIGHT_Y, SIGHT_Z))
    print("POINT forend_centre", pt(0, (FOREND_Y0 + FOREND_Y1) / 2, ZT))
    print("POINT forend_bottom", pt(0, (FOREND_Y0 + FOREND_Y1) / 2, -0.0590))
    print("POINT ejection_port", pt(RCV_W, (EJECT[0] + EJECT[1]) / 2, (EJECT[2] + EJECT[3]) / 2))
    print("POINT loading_port", pt(0, (LOAD[0] + LOAD[1]) / 2, RCV_BOT))
    print("POINT shell_node", godot(shell_pos - ORIGIN))

    if STAGE == "geo":
        mat = preview_material()
        for ob in obs:
            ob.data.materials.append(mat)
    else:
        export(obs)
    if BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
    print("DONE in %.1f s" % (time.time() - T_START))


if __name__ == "__main__":
    main()
