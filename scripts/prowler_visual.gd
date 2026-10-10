class_name ProwlerVisual
extends RipperVisual
## The Prowler's body: the four-legged hunter of mission two. Like the hound it brings its
## own skeleton and clips (idle, stalk, trot, run, leap, slash_l, slash_r, slam, bite,
## flinch, stagger, roar, death, turn_l, turn_r, pivot_l, pivot_r, brake, shake - made in
## Blender by tools/blender_rig_prowler.py).
## It is a RipperVisual so that everything that asks "has it arms to lose?" answers as it
## does for the hound.

const MODEL := "res://assets/models/prowler.glb"
## The model is three metres long; this is how much of that walks into the game.
const SIZE := 0.82
## Ground speed in m/s the gaits are made for at normal playback (the script that makes
## the clips carries the same numbers, there for the model at full size).
const STALK_SPEED := 1.2 * SIZE
const TROT_SPEED := 4.0 * SIZE
const GALLOP_SPEED := 8.5 * SIZE
## Above which speed it trots, and gallops.
const TROT_FROM := 1.9
const RUN_FROM := 4.9
## The one-shot clips: [seconds, when the blow lands].
const BLOWS := {"slash_l": [0.7, 0.31], "slash_r": [0.7, 0.31], "slam": [0.9, 0.47], "bite": [0.6, 0.24]}
## The leap: crouch until LEAP_OFF, in the air until LEAP_DOWN, landed at LEAP_END.
const LEAP_OFF := 0.30
const LEAP_DOWN := 0.80
const LEAP_END := 1.1
const ROAR_SECONDS := 1.9
## Turning on the spot: the clips turn_l and turn_r are made for this many radians a second.
const TURN_SPEED := 2.618
## The half turn over the haunches: the clip's length, the seconds of it in which the body
## comes round, and how far behind the middle of the body the point lies it turns about.
const PIVOT_SECONDS := 0.5
const PIVOT_TURN := 0.44
const HAUNCH := 1.369 * SIZE
const BRAKE_SECONDS := 0.45
const SHAKE_SECONDS := 1.1
## Seconds one gait takes to become another.
const BLEND := 0.2
## In a curve: how far the spine bends (radians, all of it), how far the head goes ahead
## of that, and how far the body leans in.
const BEND := 0.42
const LEAD := 0.3
const LEAN := 0.13
const STAGGER_SECONDS := 1.0
const FLINCH_SECONDS := 0.45
const GLOW_CODE := """shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
uniform sampler2D skin : source_color;
uniform float power = 0.0;
uniform vec3 glow : source_color = vec3(1.0, 0.22, 0.04);
void fragment() {
	vec3 c = texture(skin, UV).rgb;
	// The dark red of the veins in the pale hide.
	float vein = smoothstep(0.17, 0.3, c.r - 0.5 * (c.g + c.b)) * smoothstep(0.7, 0.3, c.g);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float beat = 0.7 + 0.3 * sin(TIME * 7.5 + UV.y * 9.0);
	ALBEDO = glow * (vein * 3.0 * beat + rim * 0.3 + 0.03) * power;
}
"""

static var prowler_scene: PackedScene

## It walks backwards (springing back from its prey): the gait runs the other way round.
var backwards := false
## How far the head is turned towards what it hunts (radians, to the left).
var look_yaw := 0.0
## How fast the body is turning (radians a second, to the left), told by whoever turns it.
var turn_rate := 0.0
var bend := 0.0
var neck_bones: Array[int] = []
var enraged := false
var rage := 0.0
var glow: ShaderMaterial
var steam: CPUParticles3D
var ember: OmniLight3D

static func body_scene() -> PackedScene:
	if prowler_scene == null:
		prowler_scene = load(MODEL) as PackedScene
	return prowler_scene

func _ready() -> void:
	model_scale = SIZE
	holder = Node3D.new()
	holder.name = "Model"
	# The model faces +Z; characters in this game face -Z.
	holder.rotation.y = PI
	holder.scale = Vector3.ONE * SIZE
	add_child(holder)
	var imported := body_scene().instantiate() as Node3D
	holder.add_child(imported)
	skeleton = _find(imported, "Skeleton3D") as Skeleton3D
	mesh_instance = _find(imported, "MeshInstance3D") as MeshInstance3D
	player = _find(imported, "AnimationPlayer") as AnimationPlayer
	# Advanced by hand, like the other infected, so the flinch can be laid on top.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["idle", "stalk", "trot", "run", "turn_l", "turn_r"]:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	head_bone = skeleton.find_bone("Bone_019")
	for bone_name in ["Bone_006", "Bone_005", "Bone_004"]:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			spine_bones.append(index)
	for bone_name in ["Bone_021", "Bone_020", "Bone_019"]:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			neck_bones.append(index)
	# It is long: without room around its box it would vanish at the edge of the view.
	if mesh_instance != null:
		mesh_instance.extra_cull_margin = 2.0
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
		# A gait once taken is kept a little longer, so that it does not flicker between two.
		if speed > (RUN_FROM - 0.6 if gait == "run" else RUN_FROM) and not backwards:
			wanted = "run"
			rate = clampf(speed / GALLOP_SPEED, 0.7, 1.45)
		elif speed > (TROT_FROM - 0.4 if gait == "trot" else TROT_FROM):
			wanted = "trot"
			rate = clampf(speed / TROT_SPEED, 0.6, 2.3)
		elif speed > 0.3:
			wanted = "stalk"
			rate = clampf(speed / STALK_SPEED, 0.5, 2.0)
		elif absf(turn_rate) > (0.35 if gait.begins_with("turn") else 0.7):
			# On the spot it steps round: the clip is made for TURN_SPEED, and played as fast as it turns.
			wanted = "turn_l" if turn_rate > 0.0 else "turn_r"
			rate = clampf(absf(turn_rate) / TURN_SPEED, 0.45, 1.9)
		if wanted != gait:
			gait = wanted
			player.play(wanted, BLEND)
		player.speed_scale = -rate if backwards and wanted in ["stalk", "trot"] else rate
		phase += TAU * rate * delta / maxf(0.1, player.current_animation_length)
	player.advance(delta)
	# Into a curve it bends: the spine along it, the head ahead of it, the body leaning in.
	var curve := clampf(turn_rate / 2.6, -1.0, 1.0) * clampf(speed / 2.5, 0.0, 1.0) if state == "move" and not dying else 0.0
	bend = lerpf(bend, curve, minf(1.0, delta * 7.0))
	holder.rotation.z = -bend * LEAN
	if absf(bend) > 0.01 and not spine_bones.is_empty():
		for bone in spine_bones:
			_nudge(bone, Vector3(0, bend * BEND / spine_bones.size(), 0))
	var head_turn := (look_yaw if state == "move" else 0.0) + bend * LEAD
	if not dying and absf(head_turn) > 0.02:
		# The head keeps to what it hunts while the body goes round it.
		for bone in neck_bones:
			_nudge(bone, Vector3(0, head_turn / neck_bones.size(), 0))
	if flinch > 0.01 and not spine_bones.is_empty():
		# A bullet knocks the body sideways for a moment.
		for bone in spine_bones:
			_nudge(bone, Vector3(0.06 * flinch, flinch_side * 0.16 * flinch, flinch_side * 0.06 * flinch) / spine_bones.size())
	if glow != null:
		rage = move_toward(rage, 1.0 if enraged and not dying else 0.0, delta * (1.2 if enraged else 0.5))
		glow.set_shader_parameter("power", rage)
		ember.light_energy = rage * (1.5 + 0.4 * sin(clock * 7.5))
		steam.emitting = rage > 0.4 and not dying

## A half turn over the haunches (see Prowler: the body is turned and carried round the
## point between the hind paws while this plays).
func pivot(left: bool) -> void:
	if not dying:
		_begin("pivot_l" if left else "pivot_r", 0.07, 1.0, 0.0, PIVOT_SECONDS, "stagger")

## Out of the gallop: braced forelegs, haunches down.
func brake() -> void:
	if not dying:
		_begin("brake", 0.09, 1.0, 0.0, BRAKE_SECONDS, "stagger")

## It shakes itself. Returns how long.
func shake() -> float:
	if dying:
		return 0.0
	_begin("shake", 0.16, 1.0, 0.0, SHAKE_SECONDS, "stagger")
	return busy_left

func pick_attack() -> String:
	return ["slash_l", "slash_r", "slash_l", "slash_r", "slam", "bite"].pick_random()

## The blow of the clip lands `strike_at` seconds from now: the clip is played as fast as
## that takes.
func attack(duration: float, strike_at: float = 0.31, clip_name: String = "") -> String:
	if dying:
		return ""
	var clip := clip_name if BLOWS.has(clip_name) else "slash_l"
	var rate := float(BLOWS[clip][1]) / maxf(0.08, strike_at)
	_begin(clip, 0.07, rate, 0.0, maxf(duration, float(BLOWS[clip][0]) / rate), "attack")
	return clip

## Crouch, leap with the claws stretched out, landing.
func pounce() -> void:
	if not dying:
		_begin("leap", 0.06, 1.0, 0.0, LEAP_END, "attack")

func pick_flinch() -> String:
	return "flinch"

func stagger(heavy: bool, _clip_name: String = "") -> float:
	if dying:
		return 0.0
	if heavy:
		_begin("stagger", 0.06, 1.0, 0.0, STAGGER_SECONDS, "stagger")
	else:
		_begin("flinch", 0.05, 1.0, 0.0, FLINCH_SECONDS, "stagger")
	return busy_left

func scream(_clip_name: String = "scream") -> float:
	if dying:
		return 0.0
	_begin("roar", 0.12, 1.0, 0.0, ROAR_SECONDS, "stagger")
	return busy_left

func pick_death(_forward: bool, _headshot: bool = false, _side: float = 0.0, _hard: bool = false) -> String:
	return "death"

func die(_clip_name: String) -> void:
	dying = true
	state = "dead"
	player.speed_scale = 1.0
	player.play("death", 0.1)

func dissolve() -> void:
	die("death")

func set_buffed(_on: bool) -> void:
	pass

func head_position() -> Vector3:
	if head_bone < 0:
		return global_position + Vector3(0, 1.0, 0)
	# The joint sits at the back of the skull; the skull itself lies in front of it.
	var pose := skeleton.get_bone_global_pose(head_bone)
	return skeleton.global_transform * (pose.origin + Vector3(0, -0.06, 0.12))

## The last fight: its veins glow through the hide, it steams, and the ground under it is lit.
func set_enraged(on: bool) -> void:
	enraged = on
	if not on or glow != null or mesh_instance == null:
		return
	glow = ShaderMaterial.new()
	var code := Shader.new()
	code.code = GLOW_CODE
	glow.shader = code
	var skin := mesh_instance.get_active_material(0) as BaseMaterial3D
	if skin != null:
		glow.set_shader_parameter("skin", skin.albedo_texture)
	glow.set_shader_parameter("power", 0.0)
	mesh_instance.material_overlay = glow
	ember = OmniLight3D.new()
	ember.light_color = Color(1.0, 0.3, 0.1)
	ember.omni_range = 5.0
	ember.light_energy = 0.0
	ember.shadow_enabled = false
	ember.position = Vector3(0, 0.8, 0)
	add_child(ember)
	steam = CPUParticles3D.new()
	steam.amount = 26
	steam.lifetime = 1.3
	steam.emitting = false
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	steam.emission_box_extents = Vector3(0.3, 0.1, 1.0)
	steam.direction = Vector3.UP
	steam.spread = 22.0
	steam.gravity = Vector3(0, 0.6, 0)
	steam.initial_velocity_min = 0.5
	steam.initial_velocity_max = 1.1
	steam.scale_amount_min = 0.5
	steam.scale_amount_max = 1.1
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.albedo_color = Color(0.9, 0.82, 0.78, 0.13)
	smoke.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = fade
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	smoke.albedo_texture = dot
	puff.material = smoke
	steam.mesh = puff
	var thin := Gradient.new()
	thin.set_color(0, Color(1, 1, 1, 1))
	thin.set_color(1, Color(1, 1, 1, 0))
	steam.color_ramp = thin
	steam.position = Vector3(0, 1.0, 0)
	add_child(steam)
