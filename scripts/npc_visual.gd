class_name NpcVisual
extends Node3D
## Somebody who only stands there: the shopkeeper behind her counter, Nadja behind the
## glass. The body plays one of three standing clips (breathing, talking, looking about
## nervously); on top of that the head follows whoever comes near. The model faces +Z.

## Recorded on Scorpion's rig, like the soldiers' newer moves.
const CLIPS := {
	"idle": {"file": "npc_idle", "loop": true},
	"talk": {"file": "npc_talk", "loop": true},
	"nervous": {"file": "npc_nervous", "loop": true}
}
## How far the head turns towards a visitor, and from how far away it notices one.
const HEAD_TURN := 0.75
const HEAD_NOD := 0.3
const NOTICE := 7.0

static var sampled: Dictionary = {}
static var libraries: Dictionary = {}

var game: Node3D
## A look from SoldierVisual.LOOKS: model, textures and height.
var look := "shopkeeper"
## The clip it plays; change it with act().
var clip := "idle"
var skeleton: Skeleton3D
var player: AnimationPlayer
var head := -1
var turn := 0.0
var nod := 0.0

func _ready() -> void:
	var config: Dictionary = SoldierVisual.LOOKS[look]
	var model := (config.scene as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * (float(config.height) / float(config.source_height))
	add_child(model)
	skeleton = InfectedVisual._find(model, "Skeleton3D") as Skeleton3D
	var mesh := InfectedVisual._find(model, "MeshInstance3D") as MeshInstance3D
	var bundled := InfectedVisual._find(model, "AnimationPlayer")
	if bundled != null:
		bundled.free()
	var base: String = config.textures
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = load(base + ("diffuse.png" if ResourceLoader.exists(base + "diffuse.png") else "diffuse.jpg"))
	skin.normal_enabled = true
	skin.normal_texture = load(base + "normal.png")
	skin.roughness_texture = load(base + "roughness.png")
	skin.metallic = 1.0
	skin.metallic_texture = load(base + "metallic.png")
	mesh.material_override = skin
	if sampled.is_empty():
		sampled = InfectedVisual.sample(SoldierVisual.SCORPION_RIG, CLIPS)
	if not libraries.has(look):
		libraries[look] = InfectedVisual._bake(skeleton, InfectedVisual._analyse(skeleton), "", sampled)
	player = AnimationPlayer.new()
	player.name = "Body"
	skeleton.get_parent().add_child(player)
	# Advanced by hand, so that the head can be turned on top of the clip.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("", libraries[look])
	player.play(clip)
	player.seek(randf() * player.current_animation_length, true)
	head = skeleton.find_bone("head")

## Changes what the body does: "idle", "talk" or "nervous".
func act(what: String) -> void:
	if what != clip and CLIPS.has(what):
		clip = what
		player.play(what, 0.5)

func _process(delta: float) -> void:
	player.advance(delta)
	# Where to look: at the nearest visitor, otherwise wherever the clip looks.
	var want_turn := 0.0
	var want_nod := 0.0
	if game != null and is_instance_valid(game.player):
		var eye: Vector3 = game.player.camera.global_position
		var local := to_local(eye) - Vector3(0, 1.5, 0)
		if local.length() < NOTICE and local.z > -0.3:
			want_turn = clampf(atan2(local.x, local.z), -HEAD_TURN, HEAD_TURN)
			want_nod = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -HEAD_NOD, HEAD_NOD)
	turn = lerpf(turn, want_turn, minf(1.0, delta * 3.0))
	nod = lerpf(nod, want_nod, minf(1.0, delta * 3.0))
	if head >= 0 and (absf(turn) > 0.01 or absf(nod) > 0.01):
		# Turned in model space, on top of whatever the clip just posed.
		var pose := skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) * (pose.inverse() * Quaternion.from_euler(Vector3(nod, turn, 0)) * pose))
