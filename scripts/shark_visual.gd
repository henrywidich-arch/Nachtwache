class_name SharkVisual
extends InfectedVisual
## An infected shark's body. It brings its own skeleton (a chain from the snout to the
## tail and a jaw) and its clips: swim, swim_fast, turn_l, turn_r, lunge, bite, thrash and
## death - made in Blender by tools/blender_rig_shark.py. Its origin lies on the body's axis
## (not at its feet): the Shark holds that at the depth it swims at.

## Per look: the file; how far the tip of the dorsal fin stands above the axis, how far the
## snout lies ahead of the origin and the tail behind it (metres, in the game); the head's
## hit zone (along the axis ahead of the origin, above the axis, radius); and the half
## height of the trunk (belly below the axis).
const LOOKS := {
	"shark1": {"scene": "res://assets/models/shark1.glb", "fin": 0.89, "nose": 1.60, "tail": 2.2, "head": Vector3(1.22, 0.06, 0.36), "belly": 0.4},
	"shark2": {"scene": "res://assets/models/shark2.glb", "fin": 0.72, "nose": 1.60, "tail": 2.2, "head": Vector3(1.22, 0.04, 0.34), "belly": 0.36}
}
## Ground speed (m/s) of the slow and the fast tail beat at normal playback.
const SWIM_SPEED := 1.8
const FAST_SPEED := 5.0
const LUNGE_SECONDS := 1.1
const BITE_SECONDS := 0.6
const BITE_AT := 0.26
const BLEND := 0.25

static var scenes: Dictionary = {}

var look: Dictionary
var head_bone := -1
var spine_bones: Array[int] = []
## How fast the body is turning (radians a second, to the left), told by the Shark.
var turn_rate := 0.0
## It holds somebody and tears at him.
var thrashing := false
## Leaning into the water as it rises and dives (radians, nose up), told by the Shark.
var pitch := 0.0

static func body_scene(look_name: String) -> PackedScene:
	if not scenes.has(look_name):
		scenes[look_name] = load(str(LOOKS[look_name].scene)) as PackedScene
	return scenes[look_name]

func _ready() -> void:
	look = LOOKS.get(kind, LOOKS.shark1)
	holder = Node3D.new()
	holder.name = "Model"
	# The model faces +Z; characters in this game face -Z.
	holder.rotation.y = PI
	add_child(holder)
	var imported := body_scene(kind if LOOKS.has(kind) else "shark1").instantiate() as Node3D
	holder.add_child(imported)
	skeleton = _find(imported, "Skeleton3D") as Skeleton3D
	mesh_instance = _find(imported, "MeshInstance3D") as MeshInstance3D
	player = _find(imported, "AnimationPlayer") as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["swim", "swim_fast", "turn_l", "turn_r", "thrash"]:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	head_bone = skeleton.find_bone("head")
	if head_bone >= 0:
		var rest := skeleton.get_bone_global_rest(head_bone)
		snout = rest.affine_inverse() * Vector3(0, rest.origin.y, float(look.nose))
	for bone_name in ["spine1", "spine2", "spine3"]:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			spine_bones.append(index)
	if mesh_instance != null:
		mesh_instance.extra_cull_margin = 2.5
	eyes = Node3D.new()
	add_child(eyes)
	phase = randf() * TAU
	player.play("swim")
	player.seek(randf() * player.current_animation_length, true)

func animate(delta: float, speed: float) -> void:
	clock += delta
	flinch = maxf(0.0, flinch - delta * 5.0)
	if dying:
		death_time += delta
	elif busy_left > 0.0:
		busy_left -= delta
		if busy_left <= 0.0:
			state = "move"
			gait = ""
	if state == "move" and not dying:
		var wanted := "swim"
		var rate := clampf(speed / SWIM_SPEED, 0.5, 1.6)
		if thrashing:
			wanted = "thrash"
			rate = 1.0
		elif speed > 3.2:
			wanted = "swim_fast"
			rate = clampf(speed / FAST_SPEED, 0.7, 1.5)
		elif absf(turn_rate) > (0.5 if gait.begins_with("turn") else 0.8):
			wanted = "turn_l" if turn_rate > 0.0 else "turn_r"
			rate = clampf(0.7 + speed / SWIM_SPEED * 0.4, 0.7, 1.4)
		if wanted != gait:
			gait = wanted
			player.play(wanted, BLEND)
		player.speed_scale = rate
		phase += TAU * rate * delta / maxf(0.1, player.current_animation_length)
	player.advance(delta)
	holder.rotation.x = lerpf(holder.rotation.x, -pitch if not dying else 0.0, minf(1.0, delta * 4.0))
	if flinch > 0.01 and not spine_bones.is_empty():
		for bone in spine_bones:
			_nudge(bone, Vector3(0.05 * flinch, flinch_side * 0.2 * flinch, 0.0) / spine_bones.size())

## Up out of the water with the jaws wide (the Shark carries the body).
func lunge() -> void:
	if not dying:
		_begin("lunge", 0.08, 1.0, 0.0, LUNGE_SECONDS, "attack")

func attack(duration: float, _strike_at: float = BITE_AT, _clip_name: String = "") -> String:
	if dying:
		return ""
	_begin("bite", 0.06, 1.0, 0.0, maxf(duration, BITE_SECONDS), "attack")
	return "bite"

func pick_attack() -> String:
	return "bite"

func pick_flinch() -> String:
	return "thrash"

func stagger(_heavy: bool, _clip_name: String = "") -> float:
	if dying:
		return 0.0
	_begin("thrash", 0.1, 1.4, 0.0, 0.6, "stagger")
	return busy_left

func scream(_clip_name: String = "scream") -> float:
	return 0.0

func pick_death(_forward: bool, _headshot: bool = false, _side: float = 0.0, _hard: bool = false) -> String:
	return "death"

func die(_clip_name: String) -> void:
	dying = true
	thrashing = false
	state = "dead"
	player.speed_scale = 1.0
	player.play("death", 0.15)

func dissolve() -> void:
	die("death")

func set_buffed(_on: bool) -> void:
	pass

func sever(_part: String) -> Node3D:
	return null

## The middle of its head, where the hit zone of the head lies.
func head_position() -> Vector3:
	if head_bone < 0:
		return global_position + global_basis * Vector3(0, 0, -float((look.head as Vector3).x))
	var pose := skeleton.get_bone_global_pose(head_bone)
	return skeleton.global_transform * (pose * (snout * 0.45))

func skull_position() -> Vector3:
	return head_position()

## The tip of the snout in the head bone's own space (set in _ready from the look).
var snout := Vector3(0, 0.85, 0)

## Where the jaws are, in the world: a little behind the snout.
func mouth_position() -> Vector3:
	if head_bone < 0:
		return global_position + global_basis * Vector3(0, 0, -float(look.nose))
	var pose := skeleton.get_bone_global_pose(head_bone)
	return skeleton.global_transform * (pose * (snout * 0.8))
