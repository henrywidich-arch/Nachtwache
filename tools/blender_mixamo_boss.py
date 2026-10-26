"""The end boss of mission two ("Subjekt Null") with Mixamo's skeleton and Mixamo's motions.

Mixamo's auto-rigger got the boss (exported from assets/models/boss/boss_mutant.glb in its rest pose);
the clips below were downloaded from mixamo.com as "FBX Binary, With Skin, 30 fps, no keyframe reduction"
onto that character. This script keeps the game's own mesh and material, takes Mixamo's skeleton and
skin weights, and bakes every clip under the name and the timing the game expects (scripts/boss_mutant.gd
CLIPS, scripts/boss_visual.gd): the walk and the run lose their travel (the game moves the body), the
jump slam loses its leap forward, the laser gets the sweep of its beam on the spine.

  blender --background --factory-startup --python tools/blender_mixamo_boss.py -- \
      --mixamo <folder with the FBX files> --base assets/models/boss/boss_mutant.glb \
      --out assets/models/boss/boss_mutant.glb [--review <folder>]

Bone names lose Mixamo's "mixamorig:" prefix (Hips, Spine, Spine1, Spine2, Neck, Head, ...).
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix, Quaternion

FPS = 30
OPT = {"mixamo": None, "base": None, "out": None, "review": None}

# name, Mixamo file, retiming knots [(seconds in the game, frame in the Mixamo clip)], loop, travel
#   travel: "keep" leaves the hips where Mixamo has them, "loop" takes out the even travel of a gait,
#   "flat" takes out every horizontal move of the hips (it stays on its spot, it may still rise).
CLIPS = [
    ("idle", "Mutant Breathing Idle", [(0.0, 1), (121 / 30.0, 122)], True, "keep"),
    ("walk", "Mutant Walking", [(0.0, 1), (43 / 30.0, 44)], True, "loop"),
    ("sprint", "Mutant Run", [(0.0, 1), (26 / 30.0, 27)], True, "loop"),
    # gathers itself: the arms go up, it drops into a crouch, ready to run
    ("rush_wind", "Mutant Jump Attack", [(0.0, 1), (0.9, 15)], False, "flat"),
    # a wide swipe of the left claw: the blow lands at 0.75 s
    ("punch", "Mutant Swiping", [(0.0, 1), (0.75, 41), (1.6, 79)], False, "keep"),
    # picks something up, heaves it back, hurls it: release at 1.25 s
    ("throw", "Throw Object", [(0.0, 8), (0.5, 31), (1.25, 74), (2.1, 128)], False, "keep"),
    # crouches, leaps, slams both fists into the floor at 1.15 s
    ("stomp", "Mutant Jump Attack", [(0.0, 1), (0.45, 14), (1.15, 52), (2.2, 100)], False, "flat"),
    ("roar", "Mutant Roaring", [(0.0, 1), (3.0, 163)], False, "keep"),
    # breathing on the spot, the sweep of the beam comes on top (see laser_sweep)
    ("laser", "Mutant Breathing Idle", [(0.0, 1), (2.6, 79)], False, "keep"),
    ("hit", "Zombie Reaction Hit", [(0.0, 1), (1.5, 61)], False, "keep"),
    ("death", "Mutant Dying", [(0.0, 1), (138 / 30.0, 139)], False, "keep"),
    # wakes in the tank, flexes and rises (the intro)
    ("emerge", "Mutant Flexing Muscles", [(0.0, 1), (3.9, 141)], False, "keep"),
]
# The laser: the yaw of the head over the clip (scripts/boss_mutant.gd _run_beam: 0.6 s -38 degrees,
# 2.1 s +38 degrees), shared out over the trunk so that it adds up to the sweep at the head.
LASER_KEYS = [(0.0, 0.0), (0.6, -38.0), (2.1, 38.0), (2.6, 0.0)]
LASER_SHARE = {"Spine": 0.3, "Spine1": 0.25, "Spine2": 0.2, "Neck": 0.15, "Head": 0.1}
PREFIX = "mixamorig:"
# How much of a leap upwards stays (Mixamo's jump slam goes 1.8 m up; in the hall half of that is plenty).
RISE = {"stomp": 0.5}


def log(*a):
    print("[mixamo]", *a)
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


def smooth_key(t, keys):
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            k = 0.0 if t1 <= t0 else max(0.0, min(1.0, (t - t0) / (t1 - t0)))
            k = k * k * (3 - 2 * k)
            return v0 + (v1 - v0) * k
    return keys[-1][1]


def source_frame(t, knots):
    for (t0, f0), (t1, f1) in zip(knots, knots[1:]):
        if t <= t1 + 1e-9:
            k = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
            return f0 + (f1 - f0) * k
    return knots[-1][1]


def mesh_bounds(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def import_fbx(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(OPT["mixamo"], name + ".fbx"))
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    return arm, new


# ------------------------------------------------------------------------------------------------ the rig
def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # the game's mesh and material, without the old skeleton
    bpy.ops.import_scene.gltf(filepath=OPT["base"])
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    mw = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = mw
    body.vertex_groups.clear()
    for o in list(bpy.data.objects):
        if o != body:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = mesh_bounds(body)
    log("game mesh: %d vertices, height %.3f" % (len(body.data.vertices), hi.z - lo.z))

    # Mixamo's skeleton and skin, brought onto the game's mesh
    arm, new = import_fbx(CLIPS[0][1])
    skin = next(o for o in new if o.type == "MESH")
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()
    mlo, mhi = mesh_bounds(skin)
    k = (hi.z - lo.z) / (mhi.z - mlo.z)
    centre = Vector(((mlo.x + mhi.x) * 0.5, (mlo.y + mhi.y) * 0.5, mlo.z))
    goal = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    align = Matrix.Translation(goal) @ Matrix.Scale(k, 4) @ Matrix.Translation(-centre)
    unit = arm.matrix_world.to_scale()[0] * k
    log("Mixamo mesh: %d vertices, height %.3f -> scale %.4f, bone units %.5f" % (len(skin.data.vertices), mhi.z - mlo.z, k, unit))
    for o in (arm, skin):
        w = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = align @ w
    bpy.ops.object.select_all(action="DESELECT")
    for o in (arm, skin):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in new:
        if o not in (arm, skin):
            bpy.data.objects.remove(o, do_unlink=True)
    nlo, nhi = mesh_bounds(skin)
    log("aligned: %s .. %s (game %s .. %s)" % (tuple(round(x, 3) for x in nlo), tuple(round(x, 3) for x in nhi), tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi)))

    # weights: the nearest point of Mixamo's skin
    for vg in skin.vertex_groups:
        body.vertex_groups.new(name=vg.name)
    mod = body.modifiers.new("weights", "DATA_TRANSFER")
    mod.object = skin
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.data.objects.remove(skin, do_unlink=True)

    # plain bone names
    for b in arm.data.bones:
        if b.name.startswith(PREFIX):
            b.name = b.name[len(PREFIX):]
    for vg in body.vertex_groups:
        if vg.name.startswith(PREFIX):
            vg.name = vg.name[len(PREFIX):]
    arm.name = "Armature"
    arm.data.name = "Armature"
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    log("skeleton: %d bones" % len(arm.data.bones))
    return body, arm, unit


# ------------------------------------------------------------------------------------------------ the clips
def bake(arm, unit, name, src_name, knots, loop, travel):
    src, new = import_fbx(src_name)
    for o in new:
        if o.type == "MESH":
            o.hide_render = True
    sc = bpy.context.scene
    seconds = knots[-1][0]
    n = max(1, int(round(seconds * FPS)))
    hips = src.pose.bones[PREFIX + "Hips"]

    def at(t):
        f = source_frame(t, knots)
        sc.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
        return {pb.name[len(PREFIX):]: pb.matrix_basis.copy() for pb in src.pose.bones}, (src.matrix_world @ hips.head)

    first, h0 = at(0.0)
    _, h1 = at(seconds)
    drift = (h1 - h0)
    drift.z = 0.0
    if travel == "loop":
        log("  %s: travel %.3f m per cycle in model units -> %.3f m/s" % (name, drift.length * unit / src.matrix_world.to_scale()[0], drift.length * unit / src.matrix_world.to_scale()[0] / seconds))
    hips_rest = arm.data.bones["Hips"].matrix_local.to_3x3()
    world_to_hips = hips_rest.inverted()
    src_scale = src.matrix_world.to_scale()[0]
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    count = n + 1
    rows = {b.name: [] for b in arm.pose.bones}
    for i in range(count):
        t = seconds * i / n
        pose, h = at(t if not (loop and i == n) else 0.0)
        for bname, m in pose.items():
            loc, rot, _ = m.decompose()
            loc = loc * unit
            if bname == "Hips":
                shift = Vector((0, 0, 0))
                if travel == "loop":
                    shift = drift * (i / n) if not (loop and i == n) else Vector((0, 0, 0))
                elif travel == "flat":
                    shift = Vector((h.x - h0.x, h.y - h0.y, max(0.0, h.z - h0.z) * (1.0 - RISE.get(name, 1.0))))
                if shift.length > 0.0:
                    # world (Mixamo units) -> the hips' own frame in the game's units
                    loc = loc - world_to_hips @ (shift * (unit / src_scale))
            if name == "laser" and bname in LASER_SHARE:
                yaw = math.radians(smooth_key(t, LASER_KEYS)) * LASER_SHARE[bname]
                rest = arm.data.bones[bname].matrix_local.to_3x3()
                axis = (rest.inverted() @ Vector((0, 0, 1))).normalized()
                rot = Quaternion(axis, yaw) @ rot
            rows[bname].append((loc, rot))
    for bname, keys in rows.items():
        if not keys:
            continue
        prev = None
        quats = []
        for loc, q in keys:
            if prev is not None and q.dot(prev) < 0.0:
                q = -q
            prev = q
            quats.append(q)
        moves = max(abs(c) for loc, _ in keys for c in loc) > 1e-4
        group = bname
        for idx in range(4):
            fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["%s"].rotation_quaternion' % bname, index=idx, group_name=group)
            fc.keyframe_points.add(count)
            for j in range(count):
                kp = fc.keyframe_points[j]
                kp.co = (j + 1, quats[j][idx])
                kp.interpolation = "LINEAR"
            fc.update()
        if moves:
            for idx in range(3):
                fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["%s"].location' % bname, index=idx, group_name=group)
                fc.keyframe_points.add(count)
                for j in range(count):
                    kp = fc.keyframe_points[j]
                    kp.co = (j + 1, keys[j][0][idx])
                    kp.interpolation = "LINEAR"
                fc.update()
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a != act and not a.use_fake_user:
            bpy.data.actions.remove(a)
    log("clip %-10s %.2f s from %s" % (name, seconds, src_name))
    return act


def stash(arm, actions):
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


def show(arm, act, frame_no):
    ad = arm.animation_data
    if ad.action != act:
        ad.action = act
        if act is not None and getattr(ad, "action_slot", None) is None and len(act.slots):
            ad.action_slot = act.slots[0]
    bpy.context.scene.frame_set(frame_no)


def review(arm, actions, folder):
    os.makedirs(folder, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 300
    sc.render.resolution_y = 380
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.4
    cam.location = (3.2, -5.5, 1.3)
    cam.rotation_euler = (math.radians(88), 0, math.radians(30))
    for act in actions:
        n = int(act.frame_range[1] - act.frame_range[0])
        for i in range(6):
            show(arm, act, 1 + int(round(n * i / 5.0)))
            sc.render.filepath = os.path.join(folder, "%s_%d.png" % (act.name, i))
            bpy.ops.render.render(write_still=True)
    show(arm, None, 1)
    log("review frames in", folder)


def export_glb(body, arm, path):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
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
    body, arm, unit = build()
    actions = [bake(arm, unit, *clip) for clip in CLIPS]
    if OPT["review"]:
        review(arm, actions, OPT["review"])
    stash(arm, actions)
    if OPT["out"]:
        export_glb(body, arm, os.path.abspath(OPT["out"]))


main()
