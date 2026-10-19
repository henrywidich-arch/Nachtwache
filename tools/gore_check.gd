extends Node
## Pictures of blood and gore where it is shed: in the farmhouse hall and out on the wet
## yard, at night (with and without the flashlight) and by day, and in a hall of the second
## mission. At each place two infected die in front of the camera, one of them torn apart,
## with a few more hits into the wall behind. Each place is taken three times: in the
## moment of the hits, a second later, and once the pools have spread.
## Started by game.gd with --gore-check --capture-dir=<folder> [--gore-only=farm|hive].
var game: Node3D

func run(owner_game: Node3D, folder: String) -> void:
	game = owner_game
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gore-only="):
			only = arg.trim_prefix("--gore-only=")
	await _wait(1.0)
	if only in ["", "farm"]:
		game.profile.mission = 1
		game.start_run()
		_quiet()
		var points: Dictionary = game.cabin.points
		var hall: Vector3 = points.hall
		var yard: Vector3 = points.front_door_out + Vector3(0, 0, 4.0)
		await _scene(folder, "gore_farm_halle_nacht", hall + Vector3(-1.0, 0, -2.6), Vector3(0, 0, 1), true)
		await _scene(folder, "gore_farm_hof_nacht", yard, Vector3(0, 0, 1), true)
		game.cabin.set_daylight(true)
		await _wait(0.4)
		await _scene(folder, "gore_farm_halle_tag", hall + Vector3(-1.0, 0, -2.6), Vector3(0, 0, 1), false)
		await _scene(folder, "gore_farm_hof_tag", yard, Vector3(0, 0, 1), false)
		game.cabin.set_daylight(false)
	if only in ["melee"]:
		game.profile.mission = 1
		game.start_run()
		_quiet()
		game.cabin.set_daylight("--gore-night" not in OS.get_cmdline_user_args())
		await _wait(0.5)
		await _melee_poses(folder)
		await _melee_kills(folder)
	if only in ["", "hive"]:
		game.profile.mission = 2
		game.intro_skipped = true
		game.hive.seed_wanted = 4242
		game.start_run()
		_quiet()
		game.hive.set_process(false)
		await _wait(1.5)
		for view in game.hive_map.tour():
			if str(view[0]) == "06_hall_in":
				var from: Vector3 = view[1]
				var ahead: Vector3 = (view[2] as Vector3) - from
				ahead.y = 0.0
				await _scene(folder, "gore_m2_halle", from, ahead.normalized(), true)
	print("GORE_COMPLETE")
	game.get_tree().quit()

func _wait(seconds: float) -> Signal:
	return game.get_tree().create_timer(seconds).timeout

## Nobody attacks, nobody else is in the picture, nothing is said over it.
func _quiet() -> void:
	game.set_process(false)
	game.preparation_left = 9999.0
	for node in game.enemies.get_children():
		node.queue_free()
	game.alive_count = 0
	for mate in game.team:
		mate.hide()
		mate.set_physics_process(false)
	game.hud.banner_left = 0
	game.hud.radio_left = 0
	if game.hud.get("play_ui") != null:
		game.hud.play_ui.hide()

## Two infected die `ahead` of a survivor standing at `from`.
func _scene(folder: String, name: String, from: Vector3, ahead: Vector3, lamp: bool) -> void:
	var fx: CombatEffects = game.fx
	fx.clear()
	var player: Survivor = game.player
	game._place_player(from + Vector3(0, 0.05, 0), rad_to_deg(atan2(-ahead.x, -ahead.z)), -16.0)
	player.flashlight.visible = lamp
	var side := ahead.cross(Vector3.UP).normalized()
	var victims: Array = []
	for offset in [Vector3.ZERO + ahead * 3.4 - side * 0.7, ahead * 4.6 + side * 1.0]:
		var enemy: Infected = game.spawn_enemy("mauler")
		enemy.set_physics_process(false)
		enemy.global_position = from + offset + Vector3(0, 0.05, 0)
		enemy.look_at(from, Vector3.UP, true)
		victims.append(enemy)
	await _wait(0.6)
	var eye := from + Vector3(0, 1.6, 0)
	for i in range(4):
		var target: Vector3 = (victims[1] as Infected).global_position + Vector3(fx.random.randf_range(-0.2, 0.2), fx.random.randf_range(0.9, 1.5), 0)
		fx.blood(target, (target - eye).normalized(), i % 2 == 0)
	(victims[0] as Infected).receive_hit(9999.0, ahead, true)
	(victims[1] as Infected).receive_hit(9999.0, ahead, false)
	for enemy in victims:
		(enemy as Infected).set_physics_process(true)
	await _wait(0.12)
	await game._capture(folder, name + "_1_treffer.png")
	await _wait(1.4)
	await game._capture(folder, name + "_2_danach.png")
	await _wait(5.0)
	await game._capture(folder, name + "_3_lachen.png")
	var close: Vector3 = from + ahead * 3.4
	game._place_player(from + ahead * 1.6 + Vector3(0, 0.05, 0), rad_to_deg(atan2(-ahead.x, -ahead.z)), -42.0)
	await _wait(0.3)
	await game._capture(folder, name + "_4_nah.png")
	# A wall ahead: shots that went through, a splash running down it, a drip.
	var wall := _solid_wall(from + Vector3(0, 1.4, 0), [ahead, -ahead, side, -side])
	if not wall.is_empty():
		var spot: Vector3 = wall.position
		var normal: Vector3 = wall.normal
		var across := normal.cross(Vector3.UP).normalized()
		fx.blood_mark(spot + across * 0.5, 0.9, normal, "run")
		fx.drip(spot + across * 0.5 + Vector3.DOWN * 0.1, normal, 0.7)
		fx.blood_mark(spot - across * 0.6 + Vector3.UP * 0.3, 0.9, normal, "spray", across, 1.4)
		fx.blood_mark(spot - across * 0.2 + Vector3.DOWN * 0.6, 0.5, normal, "splat")
		var stand := spot + normal * 2.2
		game._place_player(Vector3(stand.x, from.y + 0.05, stand.z), rad_to_deg(atan2(normal.x, normal.z)), -8.0)
		await _wait(4.0)
		await game._capture(folder, name + "_5_wand.png")
	print("GORE %s decals=%d near=%s" % [name, fx.decals.size(), str(close)])
	for enemy in victims:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await _wait(0.2)

## The first of `ways` from `eye` that meets an even wall, a metre wide, within 9 m.
func _solid_wall(eye: Vector3, ways: Array) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for way: Vector3 in ways:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + way * 9.0, 1))
		if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.2 or eye.distance_to(hit.position) < 2.5:
			continue
		var across := (hit.normal as Vector3).cross(Vector3.UP).normalized()
		var even := true
		for shift in [-0.9, 0.9, Vector3.DOWN.y * 0.8]:
			var offset: Vector3 = across * shift if absf(shift) > 0.85 else Vector3(0, shift, 0)
			var other := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye + offset, eye + offset + way * 9.0, 1))
			if other.is_empty() or absf(eye.distance_to(hit.position) - (eye + offset).distance_to(other.position)) > 0.15:
				even = false
		if even:
			return hit
	return {}

## Each melee weapon in the hands, held at five moments of its blow: drawn back, coming
## round, landing, followed through, on its way back.
func _melee_poses(folder: String) -> void:
	var player: Survivor = game.player
	var points: Dictionary = game.cabin.points
	game._place_player((points.hall as Vector3) + Vector3(0, 0.05, -2.0), 180.0, 0.0)
	player.flashlight.visible = false
	await _wait(0.5)
	for id: String in Survivor.MELEE_WEAPONS:
		if id == "bash":
			continue
		player.melee_weapon = id
		player.melee_cooldown = 0.0
		player.melee()
		# Held still: the blow sticks for as long as the pictures take, and never lands.
		player.melee_pending = false
		player.melee_stop = 99.0
		var motion: Dictionary = Survivor.MELEE_MOTION[id]
		var windup := float(motion.windup)
		var land := windup + float(motion.strike)
		var moments := [["1_ausholen", windup], ["2_schwung", windup + float(motion.strike) * 0.6], ["3_treffer", land], ["4_durch", land + float(motion.follow)], ["5_zurueck", land + float(motion.follow) + float(motion.recover) * 0.5]]
		for moment: Array in moments:
			player.melee_time = float(moment[1])
			await _wait(0.12)
			await game._capture(folder, "melee_%s_%s.png" % [id, moment[0]])
		player.melee_stop = 0.0
		player.melee_time = 99.0
		await _wait(0.3)

## A real blow of each weapon into an infected: the moment it lands, and a second after.
func _melee_kills(folder: String) -> void:
	var player: Survivor = game.player
	var points: Dictionary = game.cabin.points
	var stand := (points.hall as Vector3) + Vector3(0, 0.05, -2.0)
	for id: String in ["knife", "machete", "bat", "hammer", "axe"]:
		game.fx.clear()
		game._place_player(stand, 180.0, -6.0)
		var enemy: Infected = game.spawn_enemy("mauler")
		enemy.set_physics_process(false)
		enemy.global_position = stand + Vector3(0, 0, 1.5)
		enemy.look_at(stand, Vector3.UP, true)
		await _wait(0.5)
		enemy.set_physics_process(true)
		player.melee_weapon = id
		player.melee_cooldown = 0.0
		player.melee()
		await _wait(player.melee_windup(id) + 0.03)
		await game._capture(folder, "kill_%s_1_treffer.png" % id)
		await _wait(1.4)
		await game._capture(folder, "kill_%s_2_danach.png" % id)
		print("MELEE %s dead=%s decals=%d" % [id, str(enemy.dead), game.fx.decals.size()])
		if is_instance_valid(enemy):
			enemy.queue_free()
		await _wait(0.3)
