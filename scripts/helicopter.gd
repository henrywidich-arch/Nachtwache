class_name Helicopter
extends Node3D
## The transport helicopter: brings the squad in, drops the hack module and takes everyone
## out again. It is moved by whoever owns it (the story); here are only the machine, its
## rotors, lights, ropes and sound. The model's nose points along -Z, its wheels stand on
## the node's origin.

const SCENE := "res://assets/models/helicopter.glb"
## Where the fast ropes are attached, in the model's own space.
const ROPE_POINTS := [Vector3(-0.99, 2.5, -0.85), Vector3(0.99, 2.5, -0.85)]

static var scene: PackedScene

var game: Node3D
var main_rotor: Node3D
var tail_rotor: Node3D
var beam: SpotLight3D
var beacon: OmniLight3D
## Shines straight down from the cabin: on for the ropes and for landing.
var work_light: SpotLight3D
## Switched on for standing on the ground: see light_up.
var ground_lights: Array[OmniLight3D] = []
var cabin_glow: OmniLight3D
var lit := false
var engine: AudioStreamPlayer3D
var ropes: Array[MeshInstance3D] = []
var clock := 0.0

func _ready() -> void:
	if scene == null:
		scene = load(SCENE)
	var model := scene.instantiate() as Node3D
	add_child(model)
	main_rotor = model.find_child("MainRotor", true, false) as Node3D
	tail_rotor = model.find_child("TailRotor", true, false) as Node3D
	# A searchlight under the nose, a red beacon on the tail and the glow of the cabin.
	beam = SpotLight3D.new()
	beam.position = Vector3(0, 1.0, -3.6)
	beam.rotation_degrees = Vector3(-62, 0, 0)
	beam.light_color = Color("dfe9ff")
	beam.light_energy = 9.0
	beam.spot_range = 46.0
	beam.spot_angle = 17.0
	beam.shadow_enabled = false
	beam.light_volumetric_fog_energy = 2.2
	add_child(beam)
	work_light = SpotLight3D.new()
	work_light.position = Vector3(0, 1.0, -0.8)
	work_light.rotation_degrees = Vector3(-90, 0, 0)
	work_light.light_color = Color("cfe0ff")
	work_light.light_energy = 12.0
	work_light.spot_range = 34.0
	work_light.spot_angle = 36.0
	work_light.shadow_enabled = false
	work_light.light_volumetric_fog_energy = 0.7
	work_light.hide()
	add_child(work_light)
	beacon = OmniLight3D.new()
	beacon.position = Vector3(0, 4.4, 8.6)
	beacon.light_color = Color("ff3020")
	beacon.omni_range = 9.0
	add_child(beacon)
	cabin_glow = OmniLight3D.new()
	cabin_glow.position = Vector3(0, 2.0, -0.6)
	cabin_glow.light_color = Color("ff5a3c")
	cabin_glow.light_energy = 0.7
	cabin_glow.omni_range = 3.2
	add_child(cabin_glow)
	# A lamp over each door, for the ground beside the machine.
	for side in [-1.0, 1.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(2.5 * side, 2.7, -0.7)
		lamp.light_color = Color("ffe6c4")
		lamp.light_energy = 1.7
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		lamp.light_volumetric_fog_energy = 0.5
		lamp.hide()
		add_child(lamp)
		ground_lights.append(lamp)
	engine = AudioStreamPlayer3D.new()
	engine.position = Vector3(0, 3.0, 0)
	engine.unit_size = 26.0
	engine.max_distance = 260.0
	engine.max_db = 6.0
	engine.attenuation_filter_cutoff_hz = 12000
	if game != null:
		var loop := game.sounds.clips["heli"][0] as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		engine.stream = loop
	add_child(engine)
	if engine.stream != null and (game == null or not game.sounds.hush):
		engine.play()

func _process(delta: float) -> void:
	clock += delta
	if main_rotor != null:
		main_rotor.rotate_y(delta * 27.0)
	if tail_rotor != null:
		tail_rotor.rotate_x(delta * 70.0)
	beacon.light_energy = 3.0 if fmod(clock, 1.1) < 0.12 else 0.0

## The machine is about to stand on the ground: the cabin is lit, a lamp burns over each
## door and the searchlight looks ahead instead of down.
func light_up() -> void:
	if lit:
		return
	lit = true
	for lamp in ground_lights:
		lamp.show()
	cabin_glow.light_energy = 2.2
	cabin_glow.omni_range = 5.5
	var turn := create_tween()
	turn.tween_property(beam, "rotation_degrees:x", -10.0, 1.6)

## Lets a rope down from each door, `length` metres long.
func drop_ropes(length: float) -> void:
	for point in ROPE_POINTS:
		var rope := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.022
		mesh.bottom_radius = 0.022
		mesh.height = 1.0
		mesh.radial_segments = 6
		rope.mesh = mesh
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("2a2620")
		paint.roughness = 1.0
		rope.material_override = paint
		rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rope)
		rope.position = point
		rope.scale.y = 0.01
		ropes.append(rope)
		# The rope unrolls downwards from its hook.
		var unroll := create_tween()
		unroll.tween_method(func(done: float) -> void:
			rope.scale.y = maxf(0.01, length * done)
			rope.position = point - Vector3(0, length * done * 0.5, 0), 0.0, 1.0, 0.9)

func pull_ropes() -> void:
	for rope in ropes:
		rope.queue_free()
	ropes.clear()

## Where somebody hangs who is `down` metres below the hook of rope `index`.
func rope_position(index: int, down: float) -> Vector3:
	return global_transform * (ROPE_POINTS[index] as Vector3) - Vector3(0, down, 0)
