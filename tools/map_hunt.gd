extends SceneTree
## Integration check with the real game: the survivor is parked at one named place after
## another (upper rooms, balcony, outbuildings ...) and real infected of every type are
## released from the spawn points. Reports each one that does not reach the survivor.
##   Godot --headless --path <project> -s res://tools/map_hunt.gd > out.txt 2>&1
## The railing layer (16) is added to the masks here in case the game scripts lack it.

const PLACES := ["upper_west", "upper_east", "balcony", "gallery", "upper_northeast", "kitchen", "supply", "barn", "garage", "guest_cabin", "shed"]
const KINDS := ["mauler", "crusher", "charger", "striker", "mauler", "crusher", "striker"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	game.check_mode = true
	game.start_run()
	game.set_process(false)
	game.player.controlled = false
	game.player.collision_mask |= 16
	var map: Node3D = game.cabin
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 24
	var failures := 0
	var round_index := 0
	var places: Array = PLACES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--places="):
			places = Array(arg.trim_prefix("--places=").split(","))
	for place in places:
		var target: Vector3 = map.points[place]
		var foes: Array = []
		for i in range(KINDS.size()):
			var enemy = game.spawn_enemy(KINDS[i])
			var spawn: Vector3 = map.spawn_points[(i * 3 + round_index * 5) % map.spawn_points.size()]
			enemy.position = spawn + Vector3(0, 0.08, 0)
			enemy.collision_mask |= 16
			enemy.alert = true
			foes.append({"node": enemy, "kind": KINDS[i], "from": spawn, "arrived": false, "last": spawn, "time": 0.0})
		round_index += 1
		var elapsed := 0.0
		var waiting := foes.size()
		while elapsed < 130.0 and waiting > 0:
			await physics_frame
			elapsed += 1.0 / 60.0
			game.player.position = target + Vector3(0, 0.05, 0)
			game.player.velocity = Vector3.ZERO
			game.player.health = 100
			waiting = 0
			for foe in foes:
				if foe.arrived:
					continue
				var node = foe.node
				if not is_instance_valid(node) or node.dead:
					# A Charger that blew up next to the survivor has arrived as well.
					foe.arrived = true
					if (foe.last as Vector3).distance_to(target) > 6.0:
						foe.arrived = false
						foe.time = -1.0
					continue
				foe.last = node.global_position
				var gap := Vector2(node.global_position.x - target.x, node.global_position.z - target.z).length()
				if gap < 2.6 and absf(node.global_position.y - target.y) < 1.4:
					foe.arrived = true
					foe.time = elapsed
				else:
					waiting += 1
		var slowest := 0.0
		for foe in foes:
			slowest = maxf(slowest, float(foe.time))
			if not foe.arrived:
				failures += 1
				var node = foe.node
				var detail := "gone at %s" % str((foe.last as Vector3).snapped(Vector3.ONE * 0.1))
				if is_instance_valid(node) and not node.dead:
					detail = "stands at %s floor=%s path %d/%d speed %.2f" % [str(node.global_position.snapped(Vector3.ONE * 0.1)), str(node.is_on_floor()), node.path_index, node.path.size(), node.get_real_velocity().length()]
					for i in range(node.get_slide_collision_count()):
						var other: Object = node.get_slide_collision(i).get_collider()
						if other != null:
							detail += " | touching %s" % str(other.get("name"))
				print("HUNT_FAIL %s: %s from %s did not reach the survivor: %s" % [place, foe.kind, str(foe.from), detail])
		print("HUNT %s: %d of %d infected arrived, the last after %.0f s" % [place, foes.filter(func(foe: Dictionary) -> bool: return foe.arrived).size(), foes.size(), slowest])
		for node in get_nodes_in_group("infected"):
			node.queue_free()
		for node in game.enemies.get_children():
			node.queue_free()
		game.alive_count = 0
		game.boss = null
		game.fx.clear()
		await physics_frame
	Engine.time_scale = 1.0
	game.sounds.stop_all()
	print("HUNT_RESULT: %d failures" % failures)
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
