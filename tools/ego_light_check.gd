extends Node
## Pictures of the first-person view, to judge how the weapon in the hands is lit: on the
## farm at night and by day, in the villa, the station, the old facility and two areas of
## the random part. Each place three times: as it is, with the flashlight on, and in the
## frame of a shot (its flash). Started by game.gd with --ego-check --capture-dir=<folder>
## [--ego-tag=<prefix>] [--ego-only=farm|hive] [--ego-fps]: --ego-fps takes no pictures but
## prints the frame time of every place (vsync off), standing and firing.
var game: Node3D

func run(owner_game: Node3D, folder: String) -> void:
	game = owner_game
	var tag := "ego"
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ego-tag="):
			tag = arg.trim_prefix("--ego-tag=")
		if arg.begins_with("--ego-only="):
			only = arg.trim_prefix("--ego-only=")
	var timing := "--ego-fps" in OS.get_cmdline_user_args()
	if timing:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait(1.0)
	if only in ["", "farm"]:
		game.profile.mission = 1
		game.start_run()
		_quiet()
		var points: Dictionary = game.cabin.points
		var views := [
			["farm_hof", (points.yard_south as Vector3), (points.hall as Vector3) + Vector3(0, 1.4, 0)],
			["farm_halle", (points.hall as Vector3), (points.shop as Vector3) + Vector3(0, 1.3, 0)],
			["farm_tuer", (points.front_door_out as Vector3), (points.yard_south as Vector3) + Vector3(0, 1.5, 0)]
		]
		for view in views:
			await _three(folder, "%s_%s_nacht" % [tag, view[0]], view[1], view[2], timing)
		game.cabin.set_daylight(true)
		await _wait(0.5)
		for view in [views[0], views[1]]:
			await _three(folder, "%s_%s_tag" % [tag, view[0]], view[1], view[2], timing)
		game.cabin.set_daylight(false)
	if only in ["", "hive"]:
		game.profile.mission = 2
		game.intro_skipped = true
		# (A night of play, with areas of the random part in its seams; a check gets the classic one.)
		game.hive.seed_wanted = 4242
		game.start_run()
		_quiet()
		game.hive.set_process(false)
		for id in game.hive_map.areas:
			game.hive_map.unlock(str(id), true)
		await _wait(1.5)
		var wanted := ["01_park_from_lz", "06_hall_in", "11_library", "14_kitchen", "23_platform_in", "42b_security", "53_spine", "65_lab_corridor", "69_cryo", "72c_hall_nave"]
		for view in game.hive_map.tour():
			if str(view[0]) in wanted:
				await _three(folder, "%s_m2_%s" % [tag, view[0]], view[1], view[2], timing)
		# Two areas of the random part, from where they are entered.
		var shown := 0
		for piece: Dictionary in game.hive_map.night.pieces:
			if shown >= 2 or str(piece.kind) != "area":
				continue
			var info := HiveLayout.info(str(piece.def))
			var looks: Array = info.get("views", [])
			if looks.is_empty():
				continue
			var origin: Vector3 = piece.origin
			var view: Array = looks[looks.size() - 1]
			var stand: Vector3 = origin + (view[1] as Vector3) - Vector3(0, 1.62, 0)
			await _three(folder, "%s_areal_%s" % [tag, str(piece.def)], stand, origin + (view[2] as Vector3), timing)
			shown += 1
	print("EGO_COMPLETE")
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

## A place as it is, with the flashlight, and in the frame of a shot.
func _three(folder: String, name: String, from: Vector3, target: Vector3, timing: bool) -> void:
	var player: Survivor = game.player
	var line := target - (from + Vector3(0, 1.62, 0))
	# (Looking a little lower than at the target: the weapon then stands against the place.)
	game._place_player(from + Vector3(0, 0.05, 0), rad_to_deg(atan2(-line.x, -line.z)), rad_to_deg(atan2(line.y, Vector2(line.x, line.z).length())) - 4.0)
	player.flashlight.visible = false
	await _wait(0.8)
	if timing:
		print("EGO_FPS %s still=%.2fms firing=%.2fms" % [name, await _frame_ms(false), await _frame_ms(true)])
		return
	await game._capture(folder, name + "_a.png")
	var view_light: Node = player.get("view_light")
	if view_light != null:
		print("EGO_LIGHT %s bounce=%.2f color=%s lit=%.2f strength=%.2f lamps=%d" % [name, float(view_light.target_energy), str(view_light.target_color), float(view_light.lit), float(view_light.strength), (view_light.lamps as Array).size()])
	player.flashlight.visible = true
	await _wait(0.3)
	await game._capture(folder, name + "_b_lampe.png")
	player.flashlight.visible = false
	await _wait(0.3)
	player.ammo = maxi(player.ammo, 5)
	player.shot_cooldown = 0.0
	player.shoot()
	await _grab(folder, name + "_c_schuss.png")
	player.trigger_held = false
	await _wait(0.3)

## The mean frame time over a second, standing or firing.
func _frame_ms(firing: bool) -> float:
	var player: Survivor = game.player
	var total := 0.0
	var frames := 0
	var last := Time.get_ticks_usec()
	while total < 1000.0:
		if firing:
			player.ammo = maxi(player.ammo, 5)
			player.shoot()
		await game.get_tree().process_frame
		var now := Time.get_ticks_usec()
		total += (now - last) / 1000.0
		last = now
		frames += 1
	player.trigger_held = false
	return total / frames

## A picture of the very next drawn frame (the flash of a shot lasts only a few).
func _grab(folder: String, file: String) -> void:
	await game.get_tree().physics_frame
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(folder.path_join(file))

## --finds-check --capture-dir=<folder>: the throwables to be found in a night of play
## (seed 4242): each from a step and a half away, looked at (its prompt on the screen), and
## the map in the corner once they have been seen.
func run_finds(owner_game: Node3D, folder: String) -> void:
	game = owner_game
	await _wait(1.0)
	game.profile.mission = 2
	game.intro_skipped = true
	game.hive.seed_wanted = 4242
	game.start_run()
	_quiet()
	game.hive.set_process(false)
	for id in game.hive_map.areas:
		game.hive_map.unlock(str(id), true)
	await _wait(1.5)
	var finds: Array = game.hive.finds.finds
	print("FINDS count=%d %s" % [finds.size(), str(finds.map(func(f: Dictionary) -> String: return "%s@%s" % [f.kind, f.at]))])
	var k := 0
	for find: Dictionary in finds:
		var at: Vector3 = find.at
		var away := Vector3(sin(float(find.yaw)), 0, cos(float(find.yaw))) * 1.6
		# (From the side that is free: the one farther from the nearest wall.)
		var best := away
		var best_room := -1.0
		for turn in range(8):
			var try := away.rotated(Vector3.UP, turn * PI * 0.25)
			var eye := at + try + Vector3(0, 1.62, 0)
			var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.6, 0), eye, 1))
			var room: float = 9.0 if hit.is_empty() else (hit.position as Vector3).distance_to(at)
			if room > best_room:
				best_room = room
				best = try
		game._place_player(at + best + Vector3(0, 0.05, 0), 0.0)
		await _wait(0.4)
		game.player.camera.look_at(at + Vector3(0, 0.45, 0))
		await _wait(0.5)
		find.seen = true
		print("FIND %d %s prompt=%s" % [k, find.kind, game.interaction_prompt()])
		await game._capture(folder, "fund_%d_%s.png" % [k, find.kind])
		k += 1
	print("FINDS_COMPLETE")
	game.get_tree().quit()

## --throw-anim: the throwables in the hand one after the other, for a recording with the
## movie writer (--write-movie x.avi --fixed-fps 60): key 4 takes each in the hand, the
## trigger throws it; then G and B the old way (held, let go). A MARK line names the frame
## each part begins with.
func run_throws(owner_game: Node3D) -> void:
	game = owner_game
	await _wait(1.0)
	game.profile.mission = 1
	game.start_run()
	_quiet()
	game.cabin.set_daylight(true)
	var player: Survivor = game.player
	game._place_player((game.cabin.points.yard_south as Vector3) + Vector3(0, 0.05, 0), 180.0, -8.0)
	for kind in Survivor.THROWABLES:
		player.items[kind] = 2
	player.last_throw = "grenade"
	await _steps(40)
	for kind in Survivor.THROWABLES:
		print("MARK %s frame=%d" % [kind, Engine.get_frames_drawn()])
		player.select_throwable()
		while player.throw_kind != kind:
			player.select_throwable()
		await _steps(45)
		Input.action_press("fire")
		await _steps(2)
		Input.action_release("fire")
		await _steps(60)
	# (The mine set down last still keeps the hands busy a moment: throw_cooldown.)
	await _steps(40)
	print("MARK key_g frame=%d" % Engine.get_frames_drawn())
	Input.action_press("throw_grenade")
	player.ready_throw("grenade")
	await _steps(30)
	Input.action_release("throw_grenade")
	await _steps(60)
	await _steps(40)
	print("MARK key_b frame=%d" % Engine.get_frames_drawn())
	Input.action_press("place_claymore")
	player.ready_throw("claymore")
	await _steps(30)
	Input.action_release("place_claymore")
	await _steps(60)
	print("MARK end frame=%d" % Engine.get_frames_drawn())
	print("THROWS_COMPLETE items=%s" % str(player.items))
	game.get_tree().quit()

func _steps(count: int) -> void:
	for i in range(count):
		await game.get_tree().physics_frame
