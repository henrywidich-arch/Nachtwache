class_name RipperVisual
extends InfectedVisual
## The mutant hound. It brings its own skeleton and clips (idle, walk, run, pounce, bite,
## flinch and two deaths, made in Blender by tools/blender_rig_ripper.py) instead of the
## retargeted Mixamo set that the two-legged infected share.

const SCENE := "res://assets/models/ripper.glb"
## Ground speed in m/s that the walk and the gallop are made for at normal playback.
const WALK_SPEED := 1.3
const RUN_SPEED := 5.2

## Loaded once and kept: without it the model would be read from disk again every time
## the last hound has gone, which stalls the game for a moment.
static var scene: PackedScene

var head_bone := -1
var spine_bones: Array[int] = []

static func model_scene() -> PackedScene:
	if scene == null:
		scene = load(SCENE) as PackedScene
	return scene

func _ready() -> void:
	holder = Node3D.new()
	holder.name = "Model"
	# The model faces +Z; characters in this game face -Z.
	holder.rotation.y = PI
	add_child(holder)
	var imported := model_scene().instantiate() as Node3D
	holder.add_child(imported)
	skeleton = _find(imported, "Skeleton3D") as Skeleton3D
	mesh_instance = _find(imported, "MeshInstance3D") as MeshInstance3D
	player = _find(imported, "AnimationPlayer") as AnimationPlayer
	# Advanced by hand, like the other infected, so the flinch can be laid on top.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["idle", "walk", "run"]:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	head_bone = skeleton.find_bone("head")
	for bone_name in ["spine1", "spine2", "chest"]:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			spine_bones.append(index)
	eyes = Node3D.new()
	add_child(eyes)
	phase = randf() * TAU
	player.play("idle")
	player.seek(randf() * player.current_animation_length, true)

func animate(delta: float, speed: float) -> void:
	clock += delta
	flinch = maxf(0.0, flinch - delta * 5.0)
	travel = 0.0
	if dying:
		death_time += delta
	elif busy_left > 0.0:
		busy_left -= delta
		if busy_left <= 0.0:
			state = "move"
			gait = ""
	if state == "move" and not dying:
		var wanted := "idle"
		var rate := 1.0
		if speed > 2.6:
			wanted = "run"
			rate = clampf(speed / RUN_SPEED, 0.6, 1.5)
		elif speed > 0.15:
			wanted = "walk"
			rate = clampf(speed / WALK_SPEED, 0.6, 1.9)
		if wanted != gait:
			gait = wanted
			player.play(wanted, 0.15)
		player.speed_scale = rate
		phase += TAU * rate * delta / maxf(0.1, player.current_animation_length)
	player.advance(delta)
	if flinch > 0.01 and not spine_bones.is_empty():
		# A bullet knocks the body sideways for a moment.
		for bone in spine_bones:
			_nudge(bone, Vector3(0.1 * flinch, flinch_side * 0.3 * flinch, flinch_side * 0.1 * flinch) / spine_bones.size())

func pick_attack() -> String:
	return "bite"

func attack(duration: float, _strike_at: float = 0.36, _clip_name: String = "") -> String:
	if dying:
		return ""
	_begin("bite", 0.06, 1.0, 0.0, duration, "attack")
	return "bite"

## Crouch, leap with the forelegs stretched out, landing.
func pounce() -> void:
	if not dying:
		_begin("pounce", 0.05, 1.0, 0.0, 1.0, "attack")

func pick_flinch() -> String:
	return "flinch"

func stagger(_heavy: bool, _clip_name: String = "") -> float:
	if dying:
		return 0.0
	_begin("flinch", 0.05, 1.0, 0.0, 0.4, "stagger")
	return busy_left

func scream(_clip_name: String = "scream") -> float:
	return 0.0

func pick_death(_forward: bool, _headshot: bool = false, _side: float = 0.0, _hard: bool = false) -> String:
	return ["death_side", "death_roll"].pick_random()

func die(clip_name: String) -> void:
	dying = true
	state = "dead"
	player.speed_scale = 1.0
	player.play(clip_name if player.has_animation(clip_name) else "death_side", 0.08)

func dissolve() -> void:
	die("death_side")

func sever(_part: String) -> Node3D:
	return null

func head_position() -> Vector3:
	if head_bone < 0:
		return global_position + Vector3(0, 0.8, 0)
	return skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin
