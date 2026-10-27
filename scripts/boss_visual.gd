class_name BossVisual
extends InfectedVisual
## The end boss of mission two ("Subjekt Null"): Meshy's biomechanical mutant on Mixamo's
## skeleton, with Mixamo's motions baked by tools/blender_mixamo_boss.py (idle, walk, sprint, rush_wind, punch,
## throw, stomp, roar, laser, hit, death, emerge). On top of the clips a thin layer of its
## own: a bullet jerks the trunk, the head follows the prey a little (no glowing eyes since
## v0.78).

const SCENE := "res://assets/models/boss/boss_mutant.glb"
## The model is 1.9 m tall in its file; the game shows it at this scale (3.3 m).
const SCALE := 1.75
## Ground speeds the gaits are made for at normal playback (model units * SCALE).
const WALK_SPEED := 1.43 * SCALE
const SPRINT_SPEED := 2.6 * SCALE
## Where the eyes sit, in the model's own space (glTF: +Z forward, Y up), before SCALE.
const EYES := [Vector3(0.042, 1.775, 0.118), Vector3(-0.042, 1.775, 0.118)]
const LOOPS := ["idle", "walk", "sprint"]

static var scene: PackedScene

var head_bone := -1
var neck_bone := -1
var spine_bones: Array[int] = []
## The one-shot clip that plays (punch, throw, ...), "" while it walks.
var action := ""
## 0..1: how hard the eyes burn (rage of the last phase, the laser's charge).
var glare := 0.0
var rage := 0.0
## Where the head turns towards (world), INF for straight ahead.
var look_at_point := Vector3.INF
var look_yaw := 0.0
var eye_nodes: Array[Node3D] = []
var attach: BoneAttachment3D

static func model_scene() -> PackedScene:
	if scene == null:
		scene = load(SCENE) as PackedScene
	return scene

func _ready() -> void:
	model_scale = SCALE
	holder = Node3D.new()
	holder.name = "Model"
	# The model faces +Z; characters in this game face -Z.
	holder.rotation.y = PI
	holder.scale = Vector3.ONE * SCALE
	add_child(holder)
	var imported := model_scene().instantiate() as Node3D
	holder.add_child(imported)
	skeleton = _find(imported, "Skeleton3D") as Skeleton3D
	mesh_instance = _find(imported, "MeshInstance3D") as MeshInstance3D
	player = _find(imported, "AnimationPlayer") as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in LOOPS:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# (It is big: its shadow is part of the picture, and it never leaves the sight of anybody.)
	if mesh_instance != null:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.extra_cull_margin = 2.0
	head_bone = skeleton.find_bone("Head")
	neck_bone = skeleton.find_bone("Neck")
	for bone_name in ["Spine1", "Spine2"]:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			spine_bones.append(index)
	eyes = Node3D.new()
	eyes.name = "Eyes"
	add_child(eyes)
	_build_eyes_glow()
	phase = randf() * TAU
	player.play("idle")
	player.seek(randf() * player.current_animation_length, true)

## Two markers where the eyes sit, carried by the head: the laser starts between them.
## (v0.78, Henry: the glowing red eyes and their light looked odd on this face - it needs
## none. The markers stay unseen, nothing glows or lights any more.)
func _build_eyes_glow() -> void:
	if head_bone < 0:
		return
	attach = BoneAttachment3D.new()
	attach.bone_idx = head_bone
	skeleton.add_child(attach)
	var rest := skeleton.get_bone_global_rest(head_bone)
	for spot: Vector3 in EYES:
		var eye := Node3D.new()
		eye.position = rest.affine_inverse() * spot
		attach.add_child(eye)
		eye_nodes.append(eye)

## Where the eyes are in the world: the laser starts there.
func eye_position() -> Vector3:
	if eye_nodes.is_empty():
		return global_position + Vector3(0, 3.1, 0)
	return (eye_nodes[0].global_position + eye_nodes[1].global_position) * 0.5

func animate(delta: float, speed: float) -> void:
	clock += delta
	flinch = maxf(0.0, flinch - delta * 4.0)
	travel = 0.0
	if dying:
		death_time += delta
		glare = maxf(0.0, glare - delta * 0.5)
	elif busy_left > 0.0:
		busy_left -= delta
		if busy_left <= 0.0:
			state = "move"
			action = ""
			gait = ""
	if state == "move" and not dying:
		var wanted := "idle"
		var rate := 1.0
		if speed > WALK_SPEED * 1.7:
			wanted = "sprint"
			rate = clampf(speed / SPRINT_SPEED, 0.7, 1.5)
		elif speed > 0.2:
			wanted = "walk"
			rate = clampf(speed / WALK_SPEED, 0.6, 1.8)
		if wanted != gait:
			player.play(wanted, 0.25 if gait != "" else 0.0)
			gait = wanted
		player.speed_scale = rate
	player.advance(delta)
	_layer(delta)

## The procedural layer over the clip: the flinch, the head after the prey.
func _layer(delta: float) -> void:
	if skeleton == null:
		return
	if flinch > 0.01 and not dying:
		for bone in spine_bones:
			_nudge(bone, Vector3(-0.12 * flinch, flinch_side * 0.18 * flinch, flinch_side * 0.06 * flinch) / spine_bones.size())
	# The head turns after its prey, as far as a neck turns, while it walks or stands.
	var want := 0.0
	if look_at_point != Vector3.INF and state == "move" and not dying:
		var to := look_at_point - global_position
		var forward := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
		want = clampf(forward.signed_angle_to(Vector3(to.x, 0, to.z).normalized(), Vector3.UP), -0.7, 0.7)
	look_yaw = lerpf(look_yaw, want, minf(1.0, delta * 4.0))
	if absf(look_yaw) > 0.01 and neck_bone >= 0 and head_bone >= 0:
		_nudge(neck_bone, Vector3(0, look_yaw * 0.45, 0))
		_nudge(head_bone, Vector3(0, look_yaw * 0.55, 0))

## Plays a one-shot clip of its own, `hold` seconds long (then it walks again).
func act(clip: String, hold: float = -1.0, rate: float = 1.0) -> void:
	if dying or not player.has_animation(clip):
		return
	var length := player.get_animation(clip).length / maxf(0.1, rate)
	_begin(clip, 0.12, rate, 0.0, hold if hold > 0.0 else length, "attack")
	action = clip

func pick_attack() -> String:
	return "punch"

func attack(duration: float, _strike_at: float = 0.55, clip_name: String = "") -> String:
	act(clip_name if clip_name != "" else "punch", duration)
	return action

func pounce() -> void:
	pass

func pick_flinch() -> String:
	return "hit"

## A heavy hit: a short flinch of the whole body (it does not break off what it does).
func stagger(_heavy: bool, _clip_name: String = "") -> float:
	if dying or action != "":
		flinch = 1.0
		return 0.0
	act("hit", 0.5)
	return busy_left

func scream(_clip_name: String = "scream") -> float:
	act("roar")
	return busy_left

func pick_death(_forward: bool, _headshot: bool = false, _side: float = 0.0, _hard: bool = false) -> String:
	return "death"

func die(_clip_name: String) -> void:
	dying = true
	state = "dead"
	action = "death"
	player.speed_scale = 1.0
	player.play("death", 0.15)

func dissolve() -> void:
	die("death")

func sever(_part: String) -> Node3D:
	return null

func topple(_fling: Vector3, _headshot: bool = false) -> bool:
	return false

func set_buffed(_on: bool) -> void:
	pass

func set_shell(_state: String) -> void:
	pass

func set_enraged(on: bool) -> void:
	rage = 1.0 if on else 0.0

func head_position() -> Vector3:
	if head_bone < 0:
		return global_position + Vector3(0, 3.0, 0)
	return skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin

func skull_position() -> Vector3:
	return head_position() + Vector3(0, 0.12, 0)
