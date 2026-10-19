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
