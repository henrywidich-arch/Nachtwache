class_name FireField
extends Node3D
## Burning petrol on the ground, from Molotov cocktails. An enemy that stands in it is
## hurt and set alight; the survivor who stands in it burns as well. In a co-op match the
## host works out what a fire does to the enemies, and every machine looks after its own
## player. The squad's bots do not know how to walk round a fire, so it spares them.

## How wide a fire is, how long it burns, how often it bites, what it does a second to an
## enemy and to a survivor, and how long an enemy burns on once it has left the fire.
const RADIUS := 3.4
const SECONDS := 9.0
const TICK := 0.25
const ENEMY_DPS := 70.0
const SURVIVOR_DPS := 14.0
const BURN_SECONDS := 3.0
## The last seconds of a fire: it burns down and hurts nobody any more.
const DYING := 1.5

var game: Node3D
## Each fire: {pos, left, parts (what Effects.fire_pool built), voice, by (who threw the
## bottle: empty for the player of this machine)}.
var fires: Array = []
var tick := 0.0

## Sets the ground around `at` on fire. `by`: the co-op partner, if the bottle was his.
func ignite(at: Vector3, by: Node = null) -> void:
	var parts: Dictionary = game.fx.fire_pool(at, RADIUS)
	var voice := AudioStreamPlayer3D.new()
	var crackle := (game.sounds.clips["fire"][0] as AudioStreamWAV).duplicate() as AudioStreamWAV
	crackle.loop_mode = AudioStreamWAV.LOOP_FORWARD
	crackle.loop_begin = 0
	crackle.loop_end = int(crackle.get_length() * crackle.mix_rate)
	voice.stream = crackle
	voice.unit_size = 6.0
	voice.max_distance = 45.0
	voice.bus = "Field"
	voice.volume_db = float(FieldAudio.MIX["fire"][0])
	(parts.node as Node3D).add_child(voice)
	if not game.sounds.hush:
		voice.play()
	fires.append({"pos": at, "left": SECONDS, "parts": parts, "voice": voice, "by": by})
	game.sounds.play_at("molotov", at + Vector3(0, 0.3, 0), 2.0)
	game.player.shake_from(at, 0.35, 12.0)

## True where a fire still burns hot enough to hurt.
func burning_at(pos: Vector3) -> bool:
	return not _fire_at(pos).is_empty()

func _fire_at(pos: Vector3) -> Dictionary:
	for fire in fires:
		var center: Vector3 = fire.pos
		var rise := pos.y - center.y
		if float(fire.left) > DYING and rise > -1.0 and rise < 2.2 and Vector2(pos.x - center.x, pos.z - center.z).length() < RADIUS:
			return fire
	return {}

func clear() -> void:
	for fire in fires:
		if is_instance_valid(fire.parts.node):
			(fire.parts.node as Node3D).queue_free()
	fires.clear()

func _physics_process(delta: float) -> void:
	if fires.is_empty() or game == null or not game.is_playing():
		return
	for i in range(fires.size() - 1, -1, -1):
		var fire: Dictionary = fires[i]
		fire.left = float(fire.left) - delta
		var parts: Dictionary = fire.parts
		# It burns down: the light fades, the flames stop coming and the crackle dies away.
		var strength := clampf(float(fire.left) / DYING, 0.0, 1.0)
		(parts.light as OmniLight3D).light_energy = (2.4 + randf() * 1.2) * strength
		(parts.flames as CPUParticles3D).emitting = float(fire.left) > 0.8
		(parts.smoke as CPUParticles3D).emitting = float(fire.left) > 0.8
		(fire.voice as AudioStreamPlayer3D).volume_db = float(FieldAudio.MIX["fire"][0]) - 30.0 * (1.0 - strength)
		if float(fire.left) <= 0.0:
			(parts.node as Node3D).queue_free()
			fires.remove_at(i)
	tick -= delta
	if tick > 0.0:
		return
	tick = TICK
	var player: Survivor = game.player
	if player.is_targetable() and burning_at(player.global_position):
		player.receive_damage(SURVIVOR_DPS * TICK * float(game.rules.harm), Vector3.INF, "fire")
	if game.net.joined:
		return
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead:
			continue
		var fire := _fire_at(enemy.global_position)
		if not fire.is_empty():
			var by: Node = fire.by if is_instance_valid(fire.by) else null
			game.scorch(enemy, ENEMY_DPS * TICK, Vector3(0, 0.2, 0) - enemy.facing(), by, BURN_SECONDS)
