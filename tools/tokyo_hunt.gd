extends SceneTree
## The ways in the simulation hall, walked by real infected and bots: a night of the second
## mission from the terminal, the survivor parked at one place of the hall after another
## (nothing hurts him), infected of several kinds released 25 to 60 m away on free ground
## of the hall. Reports every one that does not get to him, and whether the bots follow.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/tokyo_hunt.gd

const PLACES := ["tokyo_crossing", "tokyo_park", "tokyo_yokocho", "tokyo_tower", "tokyo_bridge", "tokyo_station", "tokyo_ring_north", "tokyo_supply", "tokyo_task_pachinko", "tokyo_task_yamashita", "tokyo_task_tech", "tokyo_task_koi"]
const KINDS := ["mauler", "mauler", "striker", "ripper", "charger", "mauler"]
const REACH := 2.6
const SECONDS := 50.0

var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.profile.mission = 2
	game.hive.resume_at = "terminal"
	game.hive.tokyo_wanted = 1
	game.start_run()
	for i in range(60):
		await physics_frame
	var map: HiveMap = game.cabin
	var dice := RandomNumberGenerator.new()
	dice.seed = 1907
	var lost := 0
	var released := 0
	var plan := TokyoHall.plan_of(map.tokyo.origin).grow(-3.0)
	# (The bots would shoot what is sent: they wait at the terminal meanwhile.)
	for mate: Teammate in game.team:
		mate.set_physics_process(false)
		mate.set_process(false)
	for place in PLACES:
		for enemy in game.enemies.get_children():
			enemy.queue_free()
		var spot: Vector3 = map.points[place]
		game.player.global_position = spot + Vector3(0, 0.05, 0)
		game.player.velocity = Vector3.ZERO
		await physics_frame
		var hunters: Array = []
		var tries := 0
		while hunters.size() < KINDS.size() and tries < 400:
			tries += 1
			var turn := dice.randf() * TAU
			var far := dice.randf_range(25.0, 60.0)
			var at := Vector3(spot.x + cos(turn) * far, map.tokyo.origin.y, spot.z + sin(turn) * far)
			if not plan.has_point(Vector2(at.x, at.z)):
				continue
			var cell := Vector2i(roundi(at.x / CabinMap.CELL), roundi(at.z / CabinMap.CELL))
			var grid: AStarGrid2D = map.navigation[map.deep]
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
				continue
			at = Vector3(cell.x * CabinMap.CELL, map.tokyo.origin.y, cell.y * CabinMap.CELL)
			if map.path_between(at, spot).size() < 2:
				continue
			var enemy: Infected = game.hive._spawn(KINDS[hunters.size()], at)
			if enemy != null:
				hunters.append([enemy, at])
		released += hunters.size()
		var left := SECONDS
		var arrived := {}
		while left > 0.0 and arrived.size() < hunters.size():
			await physics_frame
			left -= 1.0 / 60.0
			game.player.ward_left = 10.0
			game.player.health = 100.0
			game.player.global_position = Vector3(spot.x, game.player.global_position.y, spot.z)
			for i in range(hunters.size()):
				var enemy: Variant = hunters[i][0]
				if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(game.player.global_position) < REACH:
					arrived[i] = true
		for i in range(hunters.size()):
			if not arrived.has(i):
				lost += 1
				var enemy: Variant = hunters[i][0]
				print("STUCK %s: %s from %s still at %s (%.1f m away)" % [place, enemy.kind if is_instance_valid(enemy) else "?", hunters[i][1], enemy.global_position if is_instance_valid(enemy) else Vector3.INF, enemy.global_position.distance_to(spot) if is_instance_valid(enemy) else -1.0])
		print("PLACE %s: %d of %d got there in %.0f s" % [place, arrived.size(), hunters.size(), SECONDS - left])
	# The bots, left at the terminal, come over to the survivor at the crossing.
	for enemy in game.enemies.get_children():
		enemy.queue_free()
	for mate: Teammate in game.team:
		mate.set_physics_process(true)
		mate.set_process(true)
		mate.global_position = map.points.terminal + Vector3(20, 0.1, -3)
	var crossing: Vector3 = map.points.tokyo_crossing
	game.player.global_position = crossing + Vector3(0, 0.05, 0)
	var waited := 0.0
	var near := 0
	while waited < 60.0:
		await physics_frame
		waited += 1.0 / 60.0
		game.player.ward_left = 10.0
		near = 0
		for mate: Teammate in game.team:
			if mate.global_position.distance_to(crossing) < 9.0:
				near += 1
		if near == game.team.size():
			break
	print("BOTS %d of %d at the crossing after %.0f s" % [near, game.team.size(), waited])
	print("TOKYO HUNT %s: %d of %d infected got there" % ["OK" if lost == 0 and near == game.team.size() else "FAILED", released - lost, released])
	quit(0 if lost == 0 else 1)
