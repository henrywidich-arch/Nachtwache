class_name HealField
extends Node3D
## The field a heal grenade leaves where it goes off: for some seconds whoever of the
## survivors stands in it - the player, a co-op partner, a companion - is healed. The
## infected get nothing from it. With the improvement from the equipment shop
## (Survivor.heal_level) it also puts back on his feet whoever lies in it, without
## anybody holding [E], and whoever gets up like that is strengthened for a while.
## In a co-op match every machine has the field and looks after its own player; the
## host looks after the companions.
##
## It must not be mistaken for gas (green haze), fire (orange) or anything that harms: it
## is a bright ring of cold blue on the ground with a clear edge, light inside, and small
## crosses that rise in it.

## How wide a field is and how long it lasts; how often it works.
const RADIUS := 3.6
const SECONDS := 9.0
const TICK := 0.5
## What it gives back a second: to the player in points of health (before the level's
## factor on healing), to a companion as a share of its full health.
const HEAL_PER_SECOND := 10.0
const MATE_SHARE_PER_SECOND := 0.1
## With the improvement: how long somebody has to lie in it before he is up again.
const RAISE_SECONDS := 1.5
## Whoever it puts back on his feet is strengthened for so long: he takes this share of
## every hit and his shots do this much more.
const BUFF_SECONDS := 12.0
const BUFF_WARD := 0.7
const BUFF_DAMAGE := 1.25
## The price of it: whoever stands in a field does only this share of his damage.
const INSIDE_DAMAGE := 0.7
## The last seconds of a field: it fades and does nothing any more.
const DYING := 1.0
const COLOR := Color(0.32, 0.82, 1.0)

var game: Node3D
## Each field: {pos, left, level, node, lamp, motes, lying (who lies in it: seconds)}.
var fields: Array = []
var tick := 0.0
static var cross: ImageTexture

## Opens a field on the ground at `at`. `level`: 1 if it also raises the fallen.
func open(at: Vector3, level: int = 0) -> void:
	var node := Node3D.new()
	add_child(node)
	node.global_position = at
	# The edge: a thin bright ring on the ground. One that raises the fallen has a second,
	# white one inside it.
	_ring(node, RADIUS, COLOR, 2.6)
	if level > 0:
		_ring(node, RADIUS * 0.55, Color(0.9, 0.98, 1.0), 1.8)
	# Inside: a breath of light on the floor.
	var floor_light := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.02
	disc.radial_segments = 40
	floor_light.mesh = disc
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.07)
	floor_light.material_override = haze
	floor_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_light.position.y = 0.05
	node.add_child(floor_light)
	# Small crosses rise in it.
	if cross == null:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(16):
			for x in range(16):
				var on: bool = (x >= 6 and x <= 9 and y >= 2 and y <= 13) or (y >= 6 and y <= 9 and x >= 2 and x <= 13)
				image.set_pixel(x, y, Color(1, 1, 1, 1.0 if on else 0.0))
		cross = ImageTexture.create_from_image(image)
	var plus := QuadMesh.new()
	plus.size = Vector2(0.16, 0.16)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	paint.billboard_keep_scale = true
	paint.vertex_color_use_as_albedo = true
	paint.albedo_texture = cross
	paint.albedo_color = Color(COLOR.r * 1.6, COLOR.g * 1.5, COLOR.b * 1.4)
	plus.material = paint
	var motes := CPUParticles3D.new()
	motes.mesh = plus
	motes.amount = 28
	motes.lifetime = 1.7
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(RADIUS * 0.66, 0.05, RADIUS * 0.66)
	motes.direction = Vector3.UP
	motes.spread = 8.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.5
	motes.initial_velocity_max = 0.95
	motes.scale_amount_min = 0.7
	motes.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	motes.color_ramp = fade
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.position.y = 0.15
	node.add_child(motes)
	var lamp := OmniLight3D.new()
	lamp.light_color = COLOR
	lamp.light_energy = 1.5
	lamp.omni_range = RADIUS * 1.5
	lamp.shadow_enabled = false
	lamp.position.y = 1.1
	node.add_child(lamp)
	fields.append({"pos": at, "left": SECONDS, "level": level, "node": node, "lamp": lamp, "motes": motes, "lying": {}})
	game.sounds.play_at("hiss", at + Vector3(0, 0.3, 0), -3.0, 1.7)
	game.sounds.play_at("syringe", at + Vector3(0, 0.3, 0), 2.0, 0.8)

func _ring(node: Node3D, radius: float, color: Color, glow: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.07
	torus.outer_radius = radius
	torus.rings = 56
	torus.ring_segments = 6
	ring.mesh = torus
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(color.r * glow, color.g * glow, color.b * glow)
	ring.material_override = paint
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.05
	node.add_child(ring)

## The field that works at a place, if any ({} otherwise).
func field_at(pos: Vector3) -> Dictionary:
	for field in fields:
		var center: Vector3 = field.pos
		var rise := pos.y - center.y
		if float(field.left) > DYING and rise > -1.0 and rise < 2.2 and Vector2(pos.x - center.x, pos.z - center.z).length() < RADIUS:
			return field
	return {}

## The factor on the damage of somebody who stands at `pos` (INSIDE_DAMAGE in a field).
func aim_at(pos: Vector3) -> float:
	return 1.0 if field_at(pos).is_empty() else INSIDE_DAMAGE

func clear() -> void:
	for field in fields:
		if is_instance_valid(field.node):
			(field.node as Node3D).queue_free()
	fields.clear()

func _physics_process(delta: float) -> void:
	if fields.is_empty() or game == null or not game.is_playing():
		return
	step(delta)

## Lets `delta` seconds pass for every field. (The checks call it themselves.)
func step(delta: float) -> void:
	for i in range(fields.size() - 1, -1, -1):
		var field: Dictionary = fields[i]
		field.left = float(field.left) - delta
		var strength := clampf(float(field.left) / DYING, 0.0, 1.0)
		(field.lamp as OmniLight3D).light_energy = 1.5 * strength
		(field.motes as CPUParticles3D).emitting = float(field.left) > DYING
		(field.node as Node3D).scale = Vector3(1.0, 1.0, 1.0) * lerpf(0.6, 1.0, strength)
		if float(field.left) <= 0.0:
			(field.node as Node3D).queue_free()
			fields.remove_at(i)
	tick -= delta
	while tick <= 0.0:
		tick += TICK
		_work(TICK)

## What the fields do in `seconds`: to the player of this machine, and (on the host or
## alone) to the companions.
func _work(seconds: float) -> void:
	var player: Survivor = game.player
	var around := field_at(player.global_position)
	if not around.is_empty():
		if player.down:
			if int(around.level) > 0 and _lies(around, player, seconds):
				player.get_up()
				player.strengthen(BUFF_SECONDS)
		elif player.health > 0.0 and player.health < 100.0:
			player.health = minf(100.0, player.health + float(game.healing(HEAL_PER_SECOND * seconds)))
	if game.net.joined:
		return
	for other in game.survivors:
		var mate := other as Teammate
		if mate == null or not is_instance_valid(mate):
			continue
		var field := field_at(mate.global_position)
		if field.is_empty():
			continue
		if mate.down:
			if int(field.level) > 0 and _lies(field, mate, seconds):
				mate.revive()
				mate.strengthen(BUFF_SECONDS)
				game.hud.kill_feed("%s  ·  vom Heilfeld aufgerichtet" % mate.label, 0, false, true)
		elif mate.rising_left <= 0.0:
			mate.health = minf(mate.max_health, mate.health + mate.max_health * MATE_SHARE_PER_SECOND * seconds)

## Counts how long somebody has been lying in a field; true when it has been long enough.
func _lies(field: Dictionary, who: Node, seconds: float) -> bool:
	var lying: Dictionary = field.lying
	lying[who] = float(lying.get(who, 0.0)) + seconds
	if float(lying[who]) < RAISE_SECONDS:
		return false
	lying.erase(who)
	return true
