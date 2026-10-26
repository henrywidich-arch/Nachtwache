class_name WeedVisions
extends Node3D
## What the high of the Weed cloud (WeedHaze) brings: a horde of garden gnomes - many small
## weak ones and a few big ones - that come running out of puffs of green smoke and go for
## whoever breathed it in. They exist only on the machine of that player: nobody else sees
## them, they attack nobody else, and nothing about them goes over the network. While they
## are about, the high holds and its own track plays (MusicDirector phase "rausch"); once
## the last one is down, or after MAX_SECONDS, the high wears off and those left go up in
## smoke.

## The two Meshy gnomes, rigged like the figures (InfectedVisual.KINDS "gnome", "gnome2").
const LOOKS := ["gnome", "gnome2"]
## How many come, and how tough, fast and hard-hitting each sort is. size: how tall it is
## against the model's one metre.
const SMALL := {"count": [12, 16], "size": [0.78, 0.95], "health": 28.0, "speed": [4.4, 5.6], "damage": 1.5, "every": 1.1, "reach": 1.05}
const BIG := {"count": [2, 3], "size": [1.55, 1.8], "health": 240.0, "speed": [3.3, 3.8], "damage": 7.0, "every": 1.7, "reach": 1.7}
## How many of the small ones may hit at the same time; the others crowd round and wait.
const SWINGERS := 5
## Seconds over which they appear, how far from the player, and how long the visions last at most.
const ARRIVAL := 3.5
const NEAR := 6.0
const FAR := 14.0
const MAX_SECONDS := 40.0
## The high is held this many seconds ahead while any of them is still on its feet.
const HOLD := 3.5
## Collision layer of their bodies: only this machine's shots look for it (Player.shoot).
const LAYER := 32

var game: Node
var gnomes: Array[Gnome] = []
var queue: Array[Dictionary] = []
var clock := 0.0
var ending := false
## The small gnomes that are hitting right now (at most SWINGERS).
var swinging: Array[Gnome] = []

## The visions of this game while they last, or null.
static func of(at_game: Node) -> WeedVisions:
	return at_game.get_node_or_null("WeedVisions") as WeedVisions

## Whether this machine's player is seeing them right now (for the music).
static func tripping(at_game: Node) -> bool:
	var visions := of(at_game)
	return visions != null and not visions.ending

## Prepares the gnomes' clips (an eighth of a second each) while the cloud bursts, so the
## high does not have to wait for them.
static func warm_up(parent: Node) -> void:
	for look in LOOKS:
		if not InfectedVisual.libraries.has(look):
			var probe := InfectedVisual.new()
			probe.kind = look
			parent.add_child(probe)
			probe.free()

## Sends the horde, unless one is already on its way. Called when the high begins.
static func start(at_game: Node) -> void:
	if of(at_game) != null or at_game.player == null:
		return
	var visions := WeedVisions.new()
	visions.name = "WeedVisions"
	visions.game = at_game
	at_game.add_child(visions)

func _ready() -> void:
	# Who comes when: the small ones in a stream, the big ones among the last.
	var small := randi_range(int(SMALL.count[0]), int(SMALL.count[1]))
	var big := randi_range(int(BIG.count[0]), int(BIG.count[1]))
	for i in range(small):
		queue.append({"at": randf_range(0.2, ARRIVAL), "big": false})
	for i in range(big):
		queue.append({"at": randf_range(ARRIVAL * 0.45, ARRIVAL + 1.0), "big": true})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))

func _process(delta: float) -> void:
	if not is_instance_valid(game.player):
		queue_free()
		return
	clock += delta
	var screen := WeedHaze.Screen.of(game)
	var player: Node3D = game.player
	if not ending and (clock > MAX_SECONDS or not player.is_targetable() or (queue.is_empty() and _standing() == 0)):
		_end()
	if ending:
		if gnomes.is_empty():
			queue_free()
		return
	screen.time_left = maxf(screen.time_left, HOLD)
	while not queue.is_empty() and float(queue[0].at) <= clock:
		_spawn(bool(queue.pop_front().big))

func _standing() -> int:
	var count := 0
	for gnome in gnomes:
		if not gnome.dead:
			count += 1
	return count

## The high wears off: whoever is left goes up in smoke.
func _end() -> void:
	ending = true
	queue.clear()
	for gnome in gnomes:
		if not gnome.dead:
			gnome.vanish()

func _spawn(big: bool) -> void:
	var sort: Dictionary = BIG if big else SMALL
	var at := _place()
	var gnome := Gnome.new()
	gnome.visions = self
	gnome.look = LOOKS.pick_random()
	gnome.big = big
	gnome.size = randf_range(float(sort.size[0]), float(sort.size[1]))
	gnome.health = float(sort.health)
	gnome.speed = randf_range(float(sort.speed[0]), float(sort.speed[1]))
	gnome.damage = float(sort.damage)
	gnome.every = float(sort.every)
	gnome.reach = float(sort.reach)
	add_child(gnome)
	gnome.global_position = at
	gnome.look_at_flat(game.player.global_position)
	gnomes.append(gnome)
	# A puff of green smoke where it comes from.
	game.fx.explosion(at + Vector3.UP * 0.4 * gnome.size, 0.6 * gnome.size, "growth")
	game.sounds.play_at("pop", at, -6.0 if not big else 0.0, randf_range(1.3, 1.7) if not big else 0.9)

## Somewhere on the player's floor, not behind a wall from them, that can be walked to.
func _place() -> Vector3:
	var player: Node3D = game.player
	var from: Vector3 = player.global_position
	var eye := from + Vector3.UP * 1.2
	var space := get_world_3d().direct_space_state
	for attempt in range(48):
		var reach := randf_range(NEAR, FAR) if attempt < 32 else randf_range(2.5, NEAR)
		var angle := randf() * TAU
		var spot := from + Vector3(cos(angle), 0, sin(angle)) * reach
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.6, spot + Vector3.DOWN * 2.5, 1))
		if hit.is_empty():
			continue
		var ground: Vector3 = hit.position
		if absf(ground.y - from.y) > 1.0:
			continue
		# Room to stand and nothing between it and the player.
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, ground + Vector3.UP * 0.6, 1)).is_empty():
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 0.2, ground + Vector3.UP * 1.9, 1)).is_empty():
			continue
		return ground
	var behind: Vector3 = from + player.global_basis.z * 2.5
	return game.fx.floor_below(behind + Vector3.UP * 1.0)

# ---------------------------------------------------------------- what this machine does to them

## A shot from this machine's player struck `body` (Player.shoot). Returns whether it was one of them.
static func shot(at_game: Node, body: Object, damage: float, direction: Vector3, point: Vector3) -> bool:
	var gnome := body as Gnome
	if gnome == null or gnome.dead:
		return false
	at_game.fx.blood(point, direction, false)
	gnome.hurt(damage, direction)
	at_game.hud.hit_marker(false, false, false, false, gnome.dead)
	return true

## A blow of this machine's player's melee weapon. Returns how many it struck.
static func melee(at_game: Node, from: Vector3, ahead: Vector3, reach: float, damage: float) -> int:
	var visions := of(at_game)
	if visions == null:
		return 0
	var struck := 0
	for gnome in visions.gnomes:
		if gnome.dead:
			continue
		var to := gnome.global_position - from
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() - 0.3 * gnome.size > reach or absf(to.y) > 1.6:
			continue
		if flat.length() > 0.8 and flat.normalized().dot(ahead) < 0.5:
			continue
		at_game.fx.blood(gnome.global_position + Vector3.UP * 0.5 * gnome.size, flat.normalized(), true)
		gnome.hurt(damage, flat.normalized())
		struck += 1
	return struck

## A blast on this machine (Game.explode / Game.blast).
static func blast(at_game: Node, center: Vector3, radius: float, damage: float) -> void:
	var visions := of(at_game)
	if visions == null or damage <= 0.0:
		return
	for gnome in visions.gnomes:
		var gap := (gnome.global_position + Vector3.UP * 0.4).distance_to(center)
		if not gnome.dead and gap < radius:
			gnome.hurt(damage * (1.0 - 0.6 * gap / radius), (gnome.global_position - center).normalized())

# ---------------------------------------------------------------- one gnome

class Gnome extends CharacterBody3D:
	const GRAVITY := 18.0
	## The shimmer over their skin: they are not quite there.
	const SHIMMER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform float fade = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 hue = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + TIME * 0.35 + rim * 0.8));
	ALBEDO = mix(vec3(0.35, 1.0, 0.3), hue, 0.6) * rim * 0.45 * fade;
}
"""
	static var shimmer: ShaderMaterial

	var visions: WeedVisions
	var look := "gnome"
	var big := false
	var size := 1.0
	var health := 30.0
	var speed := 5.0
	var damage := 3.0
	var every := 1.0
	var reach := 1.0
	var dead := false
	var visual: InfectedVisual
	var path := PackedVector3Array()
	var path_index := 0
	var repath_left := 0.0
	var swing_left := 0.0
	var strike_left := -1.0
	var stun_left := 0.0
	var gone_left := 0.0
	var growl_left := 0.0
	var skin: ShaderMaterial

	func _ready() -> void:
		collision_layer = WeedVisions.LAYER
		collision_mask = 1 | 16
		floor_snap_length = 0.3
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.24 * size
		capsule.height = maxf(0.95 * size, capsule.radius * 2.0 + 0.01)
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		shape.position.y = capsule.height * 0.5
		add_child(shape)
		visual = InfectedVisual.new()
		visual.kind = look
		visual.scale = Vector3.ONE * size
		add_child(visual)
		if shimmer == null:
			shimmer = ShaderMaterial.new()
			var code := Shader.new()
			code.code = SHIMMER
			shimmer.shader = code
		skin = shimmer.duplicate() as ShaderMaterial
		visual.mesh_instance.material_overlay = skin
		growl_left = randf_range(0.5, 3.0)
		repath_left = randf() * 0.3

	func look_at_flat(target: Vector3) -> void:
		var way := Vector2(target.x - global_position.x, target.z - global_position.z)
		if way.length() > 0.01:
			rotation.y = atan2(-way.x, -way.y)

	func _physics_process(delta: float) -> void:
		var game: Node = visions.game
		var player: Node3D = game.player
		if dead:
			gone_left -= delta
			if skin != null:
				skin.set_shader_parameter("fade", clampf(gone_left, 0.0, 1.0))
			visual.animate(delta, 0.0)
			if gone_left <= 0.0:
				visions.gnomes.erase(self)
				queue_free()
			return
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = -0.5
		var offset := player.global_position - global_position
		var flat := Vector2(offset.x, offset.z)
		var wanted := Vector3.ZERO
		swing_left -= delta
		stun_left -= delta
		if strike_left >= 0.0:
			strike_left -= delta
			if strike_left < 0.0 and flat.length() < reach + 0.5 and absf(offset.y) < 1.6 and player.is_targetable():
				player.receive_damage(damage, global_position, "melee", "gnome")
		if stun_left <= 0.0 and visual.state == "move":
			if flat.length() > reach * 0.85:
				wanted = _toward(player.global_position) * speed
				visions.swinging.erase(self)
			else:
				look_at_flat(player.global_position)
				if swing_left <= 0.0 and player.is_targetable() and _may_swing():
					swing_left = every * randf_range(0.9, 1.15)
					strike_left = 0.32 if not big else 0.5
					visual.attack(every * 0.9, strike_left)
					game.sounds.play_at("attack", global_position, -8.0 if not big else -2.0, randf_range(1.6, 1.9) if not big else 1.05)
		# Keep a little apart from the others, so they come as a crowd and not as one.
		for other in visions.gnomes:
			if other == self or other.dead:
				continue
			var apart := global_position - other.global_position
			apart.y = 0.0
			var room := 0.45 * (size + other.size) * 0.5
			if apart.length() < room and apart.length() > 0.001:
				wanted += apart.normalized() * (room - apart.length()) * 6.0
		velocity.x = wanted.x
		velocity.z = wanted.z
		if Vector2(wanted.x, wanted.z).length() > 0.3:
			var facing := atan2(-wanted.x, -wanted.z)
			rotation.y = lerp_angle(rotation.y, facing, minf(1.0, delta * 10.0))
		move_and_slide()
		var ground_speed := Vector2(velocity.x, velocity.z).length()
		visual.animate(delta, ground_speed / size)
		growl_left -= delta
		if growl_left <= 0.0:
			growl_left = randf_range(2.5, 6.0)
			game.sounds.play_at("growl", global_position, -12.0 if not big else -4.0, randf_range(1.7, 2.1) if not big else 1.2)

	## Whether it gets a turn at the player: the big ones always, the small ones in turns.
	func _may_swing() -> bool:
		if big or visions.swinging.has(self):
			return true
		if visions.swinging.size() >= WeedVisions.SWINGERS:
			return false
		visions.swinging.append(self)
		return true

	## Which way to run: along the map's paths if it knows one, straight on otherwise.
	func _toward(target: Vector3) -> Vector3:
		var cabin = visions.game.cabin
		repath_left -= get_physics_process_delta_time()
		if repath_left <= 0.0:
			repath_left = 0.45 + randf() * 0.2
			path = cabin.path_between(global_position, target) if cabin != null and cabin.has_method("path_between") else PackedVector3Array()
			path_index = 1 if path.size() > 1 else 0
		while path_index < path.size():
			var point := Vector2(path[path_index].x - global_position.x, path[path_index].z - global_position.z)
			if point.length() < 0.35:
				path_index += 1
				continue
			return Vector3(point.x, 0, point.y).normalized()
		var way := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		return way.normalized() if way.length() > 0.01 else Vector3.ZERO

	func hurt(amount: float, direction: Vector3) -> void:
		if dead:
			return
		health -= amount
		var side := signf(global_basis.x.dot(direction))
		visual.hit(side, clampf(amount / 40.0, 0.3, 1.0))
		if health <= 0.0:
			_fall(direction)
		elif big and amount > 60.0 and stun_left <= 0.0:
			stun_left = visual.stagger(false)
			strike_left = -1.0

	func _fall(direction: Vector3) -> void:
		dead = true
		visions.swinging.erase(self)
		strike_left = -1.0
		collision_layer = 0
		velocity = Vector3.ZERO
		var forward := (-global_basis.z).dot(direction) > 0.2
		var side := global_basis.x.dot(direction)
		visual.die(visual.pick_death(forward, false, side, false))
		# It shrinks into nothing as it falls: it was never there.
		visual.dissolving = true
		gone_left = 1.9
		var game: Node = visions.game
		game.sounds.play_at("screech" if not big else "pain", global_position, -8.0 if not big else -2.0, randf_range(1.8, 2.2) if not big else 1.15)
		game.fx.explosion(global_position + Vector3.UP * 0.4 * size, 0.5 * size, "growth")

	## Gone without a fall, when the high wears off.
	func vanish() -> void:
		dead = true
		visions.swinging.erase(self)
		collision_layer = 0
		visual.dissolve()
		gone_left = 1.6
		visions.game.fx.explosion(global_position + Vector3.UP * 0.4 * size, 0.5 * size, "growth")
