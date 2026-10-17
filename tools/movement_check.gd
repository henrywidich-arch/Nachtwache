extends Node
## Exercise real player input and collision against props, rails and landing surfaces.
var checks := 0
var failures := 0
var game: Node3D
var player: CharacterBody3D
var floor_y := 12.0
var origin := Vector3(0, 12, 25)
var fixtures: Node3D

func expect(ok: bool, message: String) -> void:
	checks += 1
	failures += int(not ok)
	print("%s: %s" % ["PASS" if ok else "FAIL", message])

func ticks(count: int = 3) -> void:
	for i in range(count):
		await get_tree().physics_frame

func box(at: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	fixtures.add_child(body)
	body.global_position = at
	return body

func stand(at: Vector3 = Vector3.INF) -> void:
	for key in ["jump", "move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "aim"]:
		Input.action_release(key)
	player.movement.reset()
	player.crouched = false
	player.crouch_from_input = false
	player.body_shape.shape.height = player.STAND_HEIGHT
	player.body_shape.position.y = player.STAND_HEIGHT * 0.5
	player.global_position = (origin if at == Vector3.INF else at) + Vector3.UP * 0.04
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await ticks(8)

func press_jump() -> void:
	Input.action_press("jump")
	await ticks(3)
	Input.action_release("jump")
	await ticks(1)

func run(owner_game: Node3D) -> void:
	game = owner_game
	game.profile.mission = 1
	game.team_enabled = false
	game.intro_skipped = true
	game.start_run()
	game.set_process(false)
	player = game.player
	fixtures = Node3D.new()
	game.add_child(fixtures)
	box(Vector3(0, floor_y - 0.15, 22), Vector3(12, 0.3, 16))
	await stand()
	var base: float = player.global_position.y
	await press_jump()
	var peak := base
	for i in range(65):
		peak = maxf(peak, player.global_position.y)
		await ticks(1)
	expect(peak - base > 1.25 and peak - base < 1.45 and player.is_on_floor(), "A normal jump reaches about 1.3 metres and lands cleanly")
	await stand()
	Input.action_press("jump")
	await ticks(85)
	expect(player.is_on_floor() and absf(player.velocity.y) < 0.1, "Holding Space does not repeatedly jump after landing")
	Input.action_release("jump")
	await stand()
	player.global_position.y = floor_y + 0.25
	player.velocity.y = -2.0
	await ticks(1)
	await press_jump()
	var buffered := false
	for i in range(16):
		buffered = buffered or player.velocity.y > 5.0
		await ticks(1)
	expect(buffered, "A jump pressed just before landing is buffered and fires on contact")
	await stand(Vector3(5.5, floor_y, 22))
	player.rotation.y = -PI / 2
	Input.action_press("move_forward")
	for i in range(30):
		await ticks(1)
		if not player.is_on_floor():
			break
	Input.action_release("move_forward")
	await press_jump()
	if player.velocity.y <= 5.0:
		print("COYOTE at=%s velocity=%s ground=%s grace=%f" % [player.global_position, player.velocity, player.is_on_floor(), float(player.movement.coyote)])
	expect(player.velocity.y > 5.0, "A late press just after leaving an edge still jumps within the grace period")
	await stand()
	Input.action_press("move_forward")
	await ticks(20)
	var walk: float = Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	await ticks(9)
	var stopped: bool = player.velocity.length() < 0.1
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await ticks(20)
	var sprint: float = Vector2(player.velocity.x, player.velocity.z).length()
	expect(is_equal_approx(walk, 4.3) and is_equal_approx(sprint, 6.6) and stopped, "Ground movement responds quickly and stops promptly, with the same walking and sprinting speeds")
	await stand()
	var crate := box(Vector3(0, floor_y + 0.6, 23.4), Vector3(1.4, 1.2, 1.4))
	await ticks()
	Input.action_press("move_forward")
	await press_jump()
	var climbed: bool = player.movement.active()
	expect(climbed and player.global_position.y > floor_y + 0.02 and player.global_position.distance_to(player.movement.finish) > 0.3, "A climb moves through its wind-up instead of teleporting to the top")
	var ammunition: int = player.ammo
	player.shoot()
	expect(player.ammo == ammunition, "The lowered weapon cannot fire during a climb")
	Input.action_release("move_forward")
	await ticks(45)
	expect(climbed and not player.movement.active() and player.is_on_floor() and absf(player.global_position.y - floor_y - 1.2) < 0.06, "Forward plus Space smoothly climbs onto a crate and leaves the player standing on its top")
	crate.queue_free()
	await ticks()
	await stand()
	var fence := box(Vector3(0, floor_y + 0.65, 23.95), Vector3(3, 1.3, 0.14), 16)
	await ticks()
	Input.action_press("move_forward")
	await press_jump()
	var vaulted: bool = player.movement.active()
	Input.action_release("move_forward")
	await ticks(45)
	expect(vaulted and player.global_position.z < 23.6 and player.is_on_floor() and absf(player.global_position.y - floor_y) < 0.06, "The same input vaults a low fence on the railing layer and lands beyond it")
	fence.queue_free()
	await ticks()
	await stand()
	var wall := box(Vector3(0, floor_y + 1.2, 23.95), Vector3(3, 2.4, 0.25))
	expect(player.movement.plan(Vector3.FORWARD).is_empty(), "High walls and closed doors cannot be vaulted")
	wall.queue_free()
	await ticks()
	crate = box(Vector3(0, floor_y + 0.6, 23.4), Vector3(1.4, 1.2, 1.4))
	var ceiling := box(Vector3(0, floor_y + 2.1, 23.5), Vector3(4, 0.2, 4))
	await ticks()
	expect(player.movement.plan(Vector3.FORWARD).is_empty(), "A low ceiling prevents a climb when the full body would not fit")
	crate.queue_free()
	ceiling.queue_free()
	await ticks()
	await stand()
	crate = box(Vector3(0, floor_y + 0.6, 23.4), Vector3(1.4, 1.2, 1.4))
	await ticks()
	Input.action_press("move_forward")
	await press_jump()
	climbed = player.movement.active()
	Input.action_release("move_forward")
	wall = box(Vector3(0, floor_y + 1.2, 23.6), Vector3(3, 2.4, 0.2))
	await ticks(45)
	expect(climbed and not player.movement.active() and player.global_position.z > 23.95, "An obstacle entering the route interrupts the climb without moving through it")
	wall.queue_free()
	crate.queue_free()
	await ticks()
	await stand()
	crate = box(Vector3(0, floor_y + 0.6, 23.4), Vector3(1.4, 1.2, 1.4))
	await ticks()
	Input.action_press("move_forward")
	await press_jump()
	climbed = player.movement.active()
	Input.action_release("move_forward")
	var arrival := origin + Vector3(3, 0.04, 0)
	player.global_position = arrival
	player.velocity = Vector3.ZERO
	await ticks(5)
	expect(climbed and not player.movement.active() and player.global_position.distance_to(arrival) < 0.1, "A teleport during a climb cancels the old route and keeps the player at the arrival point")
	crate.queue_free()
	await ticks()
	# Sample the actual farm collision on the same layers the player uses.
	var top := func(at: Vector3) -> float:
		var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.UP * 0.1, 1 | 16))
		return -100.0 if hit.is_empty() else hit.position.y - at.y
	expect(absf(top.call(Vector3(4.45, 0, -0.4)) - 0.92) < 0.02 and absf(top.call(Vector3(8.8, 0, 8.45)) - 0.5) < 0.02 and absf(top.call(Vector3(4.35, 0, 7.5)) - 1.52) < 0.02, "Actual barrels and low and stacked crates have solid visible tops, without invisible collision caps")
	fixtures.queue_free()
	await ticks()
	game.profile.mission = 2
	var seed_was: int = game.hive.seed_wanted
	game.hive.seed_wanted = 6
	game.start_run()
	game.set_process(false)
	game.hive.set_process(false)
	floor_y = 24.0
	origin = Vector3(0, floor_y, 45)
	fixtures = Node3D.new()
	game.add_child(fixtures)
	box(origin + Vector3(0, -0.15, -3), Vector3(12, 0.3, 16))
	box(origin + Vector3(0, 0.65, -1.05), Vector3(3, 1.3, 0.14), 16)
	await stand()
	Input.action_press("move_forward")
	await press_jump()
	vaulted = player.movement.active()
	Input.action_release("move_forward")
	await ticks(45)
	expect(vaulted and player.is_on_floor() and player.global_position.z < origin.z - 1.4, "Vaulting uses real collision in Mission 2 as well as on the farm")
	fixtures.queue_free()
	await ticks()
	game.profile.mission = 1
	game.hive.seed_wanted = seed_was
	game.hive.set_process(true)
	game.start_run()
	game.set_process(false)
	game.return_to_menu()
	print("MOVEMENT_RESULT: %d checks, %d failures" % [checks, failures])
