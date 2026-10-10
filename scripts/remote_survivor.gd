class_name RemoteSurvivor
extends CharacterBody3D
## The other player of a co-op match as this machine sees them: a soldier that goes
## where the partner's machine says it is. On the host the infected hunt it like any
## survivor; the damage they do is passed on to the partner's own machine.

var game: Node3D
var look := "viper"
var label := "MITSPIELER"
var visual: SoldierVisual
var name_tag: Label3D
var health := 100.0
var down := false
## The Leech hanging on to the partner, as the host sees it.
var clung_by: Infected
var aiming := false
var reloading := false
var firing_left := 0.0
var rising_left := 0.0
var net_position := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var net_velocity := Vector3.ZERO
## The partner's flamethrower: seconds its stream keeps showing, and where it points.
var flame_left := 0.0
var flame_to := Vector3.ZERO
var flame_stream: CPUParticles3D
var flame_voice: AudioStreamPlayer3D
## The partner ducks: a lower body, also for whoever shoots at it on this machine.
var crouched := false
var body_shape: CollisionShape3D
## What was shown of the partner's shots here: the sound of the weapon -> how many of
## them (the co-op checks read which weapons came across).
var shots_shown: Dictionary = {}

func _ready() -> void:
	# The infected bump into it; nothing pushes it around.
	collision_layer = 2
	collision_mask = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	body_shape = shape
	visual = SoldierVisual.new()
	visual.look = look
	add_child(visual)
	name_tag = Label3D.new()
	name_tag.text = label
	name_tag.font_size = 22
	name_tag.pixel_size = 0.004
	name_tag.modulate = Color("9fe4ef")
	name_tag.outline_size = 5
	name_tag.outline_modulate = Color(0, 0, 0, 0.8)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position.y = 2.05
	add_child(name_tag)

func is_targetable() -> bool:
	return health > 0.0 and not down

## Its owner's machine applies hazards; this one only passes on what the infected do.
func takes_local_damage() -> bool:
	return false

func shake_from(_source: Vector3, _strength: float, _reach: float) -> void:
	pass

func receive_damage(amount: float, from: Vector3 = Vector3.INF, kind: String = "", by: String = "") -> void:
	if is_targetable():
		game.net.send_hurt(amount, from if from != Vector3.INF else global_position, kind, by)

## The stream of the partner's flamethrower and its roar, for as long as it fires.
func _show_flame(on: bool) -> void:
	if flame_stream == null:
		if not on:
			return
		flame_stream = game.fx.flame_stream()
		add_child(flame_stream)
		flame_voice = AudioStreamPlayer3D.new()
		var roar := (game.sounds.clips["flamer"][0] as AudioStreamWAV).duplicate() as AudioStreamWAV
		roar.loop_mode = AudioStreamWAV.LOOP_FORWARD
		roar.loop_begin = 0
		roar.loop_end = int(roar.get_length() * roar.mix_rate)
		flame_voice.stream = roar
		flame_voice.unit_size = 6.0
		flame_voice.max_distance = 60.0
		flame_voice.bus = "Field"
		flame_voice.volume_db = float(FieldAudio.MIX["flamer"][0])
		flame_voice.position.y = 1.3
		add_child(flame_voice)
	if on:
		var muzzle := visual.muzzle_position()
		flame_stream.global_position = muzzle
		if muzzle.distance_to(flame_to) > 0.5:
			flame_stream.look_at(flame_to)
	flame_stream.emitting = on
	if on and not flame_voice.playing:
		flame_voice.play()
	elif not on and flame_voice.playing:
		flame_voice.stop()

func _physics_process(delta: float) -> void:
	firing_left -= delta
	flame_left -= delta
	_show_flame(flame_left > 0.0)
	global_position = global_position.lerp(net_position, minf(1.0, delta * 14.0))
	rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, delta * 14.0))
	visual.pitch = lerpf(visual.pitch, net_pitch, minf(1.0, delta * 12.0))
	visual.animate(delta, net_velocity, aiming or firing_left > 0.0, firing_left > 0.0)
	if rising_left > 0.0:
		rising_left -= delta
		if rising_left <= 0.0:
			visual.settle()

func set_reloading(now: bool) -> void:
	if now and not reloading:
		visual.reload(1.9)
	reloading = now

func set_crouched(now: bool) -> void:
	if now == crouched:
		return
	crouched = now
	visual.crouched = now
	var capsule := body_shape.shape as CapsuleShape3D
	capsule.height = Survivor.CROUCH_HEIGHT if now else Survivor.STAND_HEIGHT
	body_shape.position.y = capsule.height * 0.5

func chest_height() -> float:
	return 0.72 if crouched else 1.15

func set_down(now: bool) -> void:
	if now == down:
		return
	down = now
	collision_layer = 0 if down else 2
	name_tag.text = label + ("  ·  AM BODEN" if down else "")
	name_tag.modulate = Color("ff8c6e") if down else Color("9fe4ef")
	if down:
		rising_left = 0.0
		if visual.mode == "rising":
			visual.settle()
		visual.fall()
		game.hud.announce("DEIN MITSPIELER IST AM BODEN", "Hilf mit [E] auf.", 3.0)
	else:
		rising_left = visual.rise()

## The partner fired: flash, tracer and the sound of their weapon from where they stand.
func show_shot(to: Vector3, sound: String) -> void:
	firing_left = 0.2
	shots_shown[sound] = int(shots_shown.get(sound, 0)) + 1
	if sound == "flamer":
		# No shot but a stream of fire, for as long as these keep coming.
		flame_left = 0.3
		flame_to = to
		return
	visual.shot()
	game.fx.tracer(visual.muzzle_position(), to)
	game.sounds.play_at(sound, visual.muzzle_position(), -3.0)
