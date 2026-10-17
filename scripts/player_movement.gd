extends RefCounted
## Grounded jump forgiveness and short, collision-checked climbs over low obstacles.
const GRAVITY := 22.0
const JUMP_SPEED := 7.8
const JUMP_BUFFER := 0.14
const COYOTE_TIME := 0.12
const VAULT_HEIGHT := 1.55
const WORLD := 1 | 16

var player: CharacterBody3D
var buffered := 0.0
var jump_held := false
var coyote := 0.0
var pose := 0.0
var duration := 0.0
var elapsed := 0.0
var start := Vector3.ZERO
var finish := Vector3.ZERO
var crest := 0.0
var last_position := Vector3.ZERO

func _init(body: CharacterBody3D) -> void:
	player = body

func active() -> bool:
	return duration > 0.0

func queue_jump() -> void:
	if not active():
		buffered = JUMP_BUFFER
	jump_held = true

func reset() -> void:
	buffered = 0.0
	jump_held = false
	coyote = 0.0
	pose = 0.0
	duration = 0.0
	elapsed = 0.0

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query)

func _clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.body_shape.shape
	query.transform = Transform3D(player.global_basis, from) * player.body_shape.transform
	query.motion = to - from
	query.collision_mask = WORLD
	query.exclude = [player.get_rid()]
	query.margin = 0.005
	var space := player.get_world_3d().direct_space_state
	var travel := space.cast_motion(query)
	if travel[0] < 0.999:
		return false
	query.transform.origin += query.motion
	query.motion = Vector3.ZERO
	return space.intersect_shape(query, 1).is_empty()

func plan(direction: Vector3) -> Dictionary:
	var ahead := direction.normalized()
	if ahead.dot(-player.global_basis.z) < 0.4:
		return {}
	var feet := player.global_position
	var wall := _ray(feet + Vector3.UP * 0.45, feet + Vector3.UP * 0.45 + ahead * 1.2)
	if wall.is_empty() or absf(wall.normal.y) > 0.2:
		return {}
	var edge: Vector3 = wall.position
	var top_at := edge + ahead * 0.08
	var top := _ray(Vector3(top_at.x, feet.y + VAULT_HEIGHT + 0.12, top_at.z), Vector3(top_at.x, feet.y + 0.2, top_at.z))
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var rise: float = top.position.y - feet.y
	if rise < 0.35 or rise > VAULT_HEIGHT:
		return {}
	# A broad surface is a place to land. A thin rail is crossed to the ground beyond.
	var landing_at := edge + ahead * 0.43
	var support := _ray(Vector3(landing_at.x, feet.y + VAULT_HEIGHT + 0.12, landing_at.z), Vector3(landing_at.x, feet.y - 0.5, landing_at.z))
	if support.is_empty():
		return {}
	if absf(support.position.y - top.position.y) > 0.15:
		landing_at = edge + ahead * 0.9
		support = _ray(Vector3(landing_at.x, feet.y + VAULT_HEIGHT + 0.12, landing_at.z), Vector3(landing_at.x, feet.y - 0.5, landing_at.z))
	if support.is_empty() or support.normal.y < 0.7 or support.position.y > feet.y + VAULT_HEIGHT:
		return {}
	var end: Vector3 = support.position + Vector3.UP * 0.04
	var high: float = maxf(top.position.y, end.y) + 0.08
	var up := Vector3(feet.x, high, feet.z)
	var across := Vector3(end.x, high, end.z)
	if not _clear(feet, up) or not _clear(up, across) or not _clear(across, end):
		return {}
	return {"start": feet, "end": end, "crest": high, "seconds": 0.36 + rise * 0.10}

func _begin(direction: Vector3) -> bool:
	var route := plan(direction)
	if route.is_empty():
		return false
	start = route.start
	last_position = start
	finish = route.end
	crest = float(route.crest)
	duration = float(route.seconds)
	elapsed = 0.0
	buffered = 0.0
	coyote = 0.0
	player.airborne = true
	player.velocity = Vector3.ZERO
	return true

func _advance(delta: float) -> void:
	var shift := player.global_position - last_position
	if shift.length_squared() > 0.25 * 0.25:
		# Arena gathering and partner teleports take precedence over an old climb route.
		duration = 0.0
		player.velocity = Vector3.ZERO
		return
	start += shift
	finish += shift
	crest += shift.y
	elapsed = minf(duration, elapsed + delta)
	var share := elapsed / duration
	var up := Vector3(start.x, crest, start.z)
	var across := Vector3(finish.x, crest, finish.z)
	var next: Vector3
	if share < 0.38:
		next = start.lerp(up, smoothstep(0.0, 0.38, share))
	elif share < 0.82:
		next = up.lerp(across, smoothstep(0.38, 0.82, share))
	else:
		next = across.lerp(finish, smoothstep(0.82, 1.0, share))
	var motion := next - player.global_position
	player.velocity = motion / maxf(delta, 0.001)
	# Recheck the actual motion: a body entering the route interrupts the climb safely.
	var collision := player.move_and_collide(motion)
	last_position = player.global_position
	if collision != null or elapsed >= duration:
		duration = 0.0
		player.velocity = Vector3.ZERO

func step(delta: float, direction: Vector3, speed: float, blocked: bool) -> bool:
	pose = move_toward(pose, 1.0 if active() else 0.0, delta * 9.0)
	buffered = maxf(0.0, buffered - delta)
	var pressed := Input.is_action_pressed("jump")
	if not blocked and pressed and not jump_held:
		buffered = JUMP_BUFFER
	jump_held = pressed
	if active():
		buffered = 0.0
		if player.down:
			reset()
		else:
			_advance(delta)
			return true
	var grounded := player.is_on_floor()
	coyote = COYOTE_TIME if grounded else maxf(0.0, coyote - delta)
	if blocked or player.clung_by != null:
		buffered = 0.0
		coyote = 0.0
	var acceleration := (56.0 if direction.is_zero_approx() else 42.0) if grounded else 18.0
	player.velocity.x = move_toward(player.velocity.x, direction.x * speed, delta * acceleration)
	player.velocity.z = move_toward(player.velocity.z, direction.z * speed, delta * acceleration)
	if grounded and player.airborne:
		player.airborne = false
		player.landing = 1.0
		player._footstep(4.0)
	if not grounded:
		player.velocity.y -= GRAVITY * delta
		player.airborne = true
	else:
		player.velocity.y = 0.0
	if buffered > 0.0 and coyote > 0.0:
		buffered = 0.0
		coyote = 0.0
		if player.wade < 1.0 and player.game.cabin.has_method("climb_out") and player.game.cabin.climb_out(player.global_position) != Vector3.INF:
			player.global_position = player.game.cabin.climb_out(player.global_position)
			player.velocity = Vector3.ZERO
			player.wade = 1.0
		elif player.crouched:
			player.set_crouched(false)
		elif not direction.is_zero_approx() and _begin(direction):
			_advance(delta)
			return true
		else:
			player.velocity.y = JUMP_SPEED
			player.airborne = true
	player.move_and_slide()
	return false
