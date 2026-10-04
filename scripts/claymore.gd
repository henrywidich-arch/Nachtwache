class_name Claymore
extends Node3D
## A directional mine. Once armed it goes off as soon as an infected walks in front of it.

## Seconds until it is live, how far it watches, and half the width of its view as a cosine.
const ARM_SECONDS := 1.2
const REACH := 3.6
const SPREAD := 0.45
## Blast: radius, damage to survivors at the centre, damage to infected.
const BLAST := [5.2, 20.0, 340.0]

var game: Node3D
## Where it points, flat on the ground.
var facing := Vector3.FORWARD
var arming := ARM_SECONDS
var lamp: OmniLight3D

func _ready() -> void:
	rotation.y = atan2(-facing.x, -facing.z)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("46503a")
	paint.roughness = 0.8
	for part in [[Vector3(0.26, 0.14, 0.05), Vector3(0, 0.17, 0)], [Vector3(0.02, 0.12, 0.02), Vector3(-0.09, 0.05, 0)], [Vector3(0.02, 0.12, 0.02), Vector3(0.09, 0.05, 0)]]:
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		piece.mesh = mesh
		piece.material_override = paint
		piece.position = part[1]
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
	lamp = OmniLight3D.new()
	lamp.light_color = Color("ffb23c")
	lamp.light_energy = 0.4
	lamp.omni_range = 1.4
	lamp.position = Vector3(0, 0.3, -0.1)
	add_child(lamp)

func _physics_process(delta: float) -> void:
	if arming > 0.0:
		arming -= delta
		if arming <= 0.0:
			lamp.light_color = Color("ff3c2e")
		return
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead or enemy.kind == "stalker":
			continue
		var to := enemy.global_position - global_position
		if absf(to.y) > 1.6:
			continue
		to.y = 0.0
		if to.length() < REACH and to.normalized().dot(facing) > SPREAD:
			game.blast(global_position + facing * 1.3 + Vector3(0, 0.45, 0), BLAST[0], BLAST[1], BLAST[2])
			queue_free()
			return
