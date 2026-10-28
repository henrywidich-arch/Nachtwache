class_name MedpackField
extends Node3D
## Medpacks set down on the floor (v0.79, from a crate: Rewards "medpack", key K). A white
## case with a red cross and a soft green ring: every PULSE seconds it heals whoever of the
## survivors stands at it - the player, a co-op partner, a companion. Each pulse that heals
## somebody uses one of its CHARGES; when they are used up (or after LIFE seconds) the case
## bursts and is gone.
## In a co-op match the host sets it down for both; each machine heals its own player, the
## host the companions. Both count its charges from what they see.

const RADIUS := 2.6
const PULSE := 2.0
const HEAL := 12.0
## Of a companion's full health, per pulse.
const MATE_SHARE := 0.12
const CHARGES := 10
const LIFE := 120.0
const COLOR := Color(0.36, 1.0, 0.55)

var game: Node3D
## Each pack: {pos, node, ring, lamp, charges, left, wait}.
var packs: Array = []

func drop(at: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Medpack"
	add_child(node)
	node.global_position = at
	var case := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.16, 0.3)
	case.mesh = box
	case.material_override = _paint(Color("e9e7e1"), 0.45)
	case.position.y = 0.08
	node.add_child(case)
	for size in [Vector3(0.2, 0.004, 0.06), Vector3(0.06, 0.004, 0.2)]:
		var bar := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = size
		bar.mesh = plate
		bar.material_override = _paint(Color("d42a2a"), 0.6)
		bar.position.y = 0.162
		node.add_child(bar)
	var handle := MeshInstance3D.new()
	var grip := BoxMesh.new()
	grip.size = Vector3(0.14, 0.03, 0.04)
	handle.mesh = grip
	handle.material_override = _paint(Color("2a2c2e"), 0.7)
	handle.position = Vector3(0, 0.17, 0.11)
	node.add_child(handle)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.05
	torus.outer_radius = RADIUS
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = COLOR * 1.6
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.04
	node.add_child(ring)
	var lamp := OmniLight3D.new()
	lamp.light_color = COLOR
	lamp.light_energy = 0.8
	lamp.omni_range = RADIUS * 1.3
	lamp.position.y = 0.5
	node.add_child(lamp)
	packs.append({"pos": at, "node": node, "ring": ring, "lamp": lamp, "charges": CHARGES, "left": LIFE, "wait": 0.6})
	if game.sounds != null:
		game.sounds.play_at("syringe", at + Vector3(0, 0.3, 0), -2.0, 1.2)

static func _paint(color: Color, rough: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = rough
	return paint

func clear() -> void:
	for pack in packs:
		if is_instance_valid(pack.node):
			(pack.node as Node3D).queue_free()
	packs.clear()

func _physics_process(delta: float) -> void:
	if packs.is_empty() or game == null or not game.is_playing():
		return
	step(delta)

## Lets `delta` seconds pass for every pack (the checks call it themselves).
func step(delta: float) -> void:
	for i in range(packs.size() - 1, -1, -1):
		var pack: Dictionary = packs[i]
		pack.left = float(pack.left) - delta
		pack.wait = float(pack.wait) - delta
		var share := float(pack.charges) / CHARGES
		(pack.lamp as OmniLight3D).light_energy = 0.3 + 0.6 * share + 0.4 * maxf(0.0, 0.4 - fmod(float(pack.left), PULSE))
		if float(pack.wait) <= 0.0:
			pack.wait = PULSE
			if _pulse(pack):
				pack.charges = int(pack.charges) - 1
		if int(pack.charges) <= 0 or float(pack.left) <= 0.0:
			_burst(pack)
			packs.remove_at(i)

## One pulse: heals the survivors in reach (this machine's player; the companions on the
## host or alone). True if anybody in reach needed it.
func _pulse(pack: Dictionary) -> bool:
	var used := false
	var player: Survivor = game.player
	if _near(pack, player.global_position) and not player.down and player.health > 0.0 and player.health < 100.0:
		player.health = minf(100.0, player.health + float(game.healing(HEAL)))
		used = true
	for other in game.survivors:
		if other == player or not is_instance_valid(other) or not _near(pack, (other as Node3D).global_position):
			continue
		if other is Teammate:
			var mate := other as Teammate
			if not mate.down and mate.health < mate.max_health:
				used = true
				if not game.net.joined:
					mate.health = minf(mate.max_health, mate.health + mate.max_health * MATE_SHARE)
		elif other is RemoteSurvivor:
			if not (other as RemoteSurvivor).down and (other as RemoteSurvivor).health < 100.0:
				used = true
	if used:
		_flash(pack)
	return used

func _near(pack: Dictionary, at: Vector3) -> bool:
	var center: Vector3 = pack.pos
	var rise := at.y - center.y
	return rise > -1.0 and rise < 2.2 and Vector2(at.x - center.x, at.z - center.z).length() < RADIUS

## A pulse that heals: the ring lights up and a few crosses rise.
func _flash(pack: Dictionary) -> void:
	var ring := pack.ring as MeshInstance3D
	ring.scale = Vector3.ONE * 0.6
	var grow := ring.create_tween()
	grow.tween_property(ring, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if game.sounds != null and (pack.pos as Vector3).distance_to(game.player.global_position) < 12.0:
		game.sounds.play_at("syringe", (pack.pos as Vector3) + Vector3(0, 0.3, 0), -12.0, 1.5)

## Used up: the case bursts - a puff of white and green, and it is gone.
func _burst(pack: Dictionary) -> void:
	var node := pack.node as Node3D
	if not is_instance_valid(node):
		return
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.amount = 24
	puff.lifetime = 0.8
	puff.explosiveness = 1.0
	var dot := SphereMesh.new()
	dot.radius = 0.04
	dot.height = 0.08
	puff.mesh = dot
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	dot.material = paint
	puff.color = COLOR
	puff.direction = Vector3.UP
	puff.spread = 70.0
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 3.5
	puff.gravity = Vector3(0, -4.0, 0)
	puff.position.y = 0.15
	add_child(puff)
	puff.global_position = node.global_position + Vector3(0, 0.15, 0)
	puff.emitting = true
	get_tree().create_timer(1.5).timeout.connect(puff.queue_free)
	if game.sounds != null:
		game.sounds.play_at("hiss", node.global_position + Vector3(0, 0.2, 0), -2.0, 1.4)
	node.queue_free()
