extends SceneTree
## The flashlight at night: the same places with the lamp as it was (v0.76) and as it is now.
## Tokyo (the alley by the SAKURA apartments), the villa, the old facility and the farm.
##   godot --resolution 1600x900 -s res://tools/torch_shots.gd -- --out=<folder> [--only=hive|farm]

var folder := "user://"
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(folder)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await _frames(5)
	game.profile.stored = false
	if only in ["", "hive"]:
		game.profile.mission = 2
		game.intro_skipped = true
		game.hive.resume_at = "terminal"
		game.hive.tokyo_wanted = 1
		game.start_run()
		_quiet()
		game.hive.set_process(false)
		await _frames(90)
		var map: HiveMap = game.cabin
		if map.tokyo != null:
			var o: Vector3 = map.tokyo.origin
			await _pair("tokio_sakura_gasse", o + Vector3(-38.5, 0, 33.0), o + Vector3(-40.5, 0.6, 50.0))
			await _pair("tokio_sakura_nah", o + Vector3(-38.5, 0, 38.0), o + Vector3(-41.5, 0.8, 46.0))
			await _wall("tokio_sakura_wand", o + Vector3(-38.5, 0, 38.0), o + Vector3(-42.0, 1.4, 44.0))
		for view in map.tour():
			if str(view[0]) in ["06_hall_in", "11_library", "53_spine", "65_lab_corridor"]:
				await _pair(("villa_" if str(view[0]) < "50" else "anlage_") + str(view[0]), view[1], view[2])
				await _wall(("villa_" if str(view[0]) < "50" else "anlage_") + str(view[0]) + "_wand", view[1], view[2])
	if only in ["", "farm"]:
		game.profile.mission = 1
		game.start_run()
		_quiet()
		await _frames(60)
		var points: Dictionary = game.cabin.points
		await _pair("hof_nacht", points.yard_south, (points.hall as Vector3) + Vector3(0, 0.6, 0))
		await _pair("hof_halle", points.hall, (points.shop as Vector3) + Vector3(0, 0.8, 0))
	print("TORCH_DONE")
	quit()

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _quiet() -> void:
	game.set_process(false)
	game.preparation_left = 9999.0
	for node in game.enemies.get_children():
		node.queue_free()
	for mate in game.team:
		mate.hide()
		mate.set_physics_process(false)
	game.hud.banner_left = 0
	game.hud.radio_left = 0
	if game.hud.get("play_ui") != null:
		game.hud.play_ui.hide()

## One place: the lamp of v0.76 (energy 5.8, 60 m, 31 degrees, attenuation 0.9), then now.
func _pair(name: String, from: Vector3, target: Vector3) -> void:
	var player = game.player
	var line: Vector3 = target - (from + Vector3(0, 1.62, 0))
	game._place_player(from + Vector3(0, 0.05, 0), rad_to_deg(atan2(-line.x, -line.z)), rad_to_deg(atan2(line.y, Vector2(line.x, line.z).length())))
	var lamp: SpotLight3D = player.flashlight
	lamp.visible = true
	player.set_physics_process(false)
	player.set_process(false)
	lamp.light_energy = 5.8
	lamp.spot_range = 60
	lamp.spot_angle = 31
	lamp.spot_attenuation = 0.9
	lamp.spot_angle_attenuation = 0.7
	lamp.shadow_blur = 1.0
	lamp.light_color = Color("e6ecd8")
	await _frames(30)
	await _save(name + "_vorher")
	player.set_physics_process(true)
	player.set_process(true)
	lamp.spot_range = 42
	lamp.spot_angle = 36
	lamp.spot_attenuation = 0.42
	lamp.spot_angle_attenuation = 1.35
	lamp.shadow_blur = 1.6
	lamp.light_color = Color("eef0e2")
	await _frames(30)
	await _save(name + "_nachher")
	print("%s: torch energy now %.2f" % [name, lamp.light_energy])

## Up close: 1.2 m before the first wall on the way from `from` to `target`.
func _wall(name: String, from: Vector3, target: Vector3) -> void:
	var eye := from + Vector3(0, 1.62, 0)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + (target - eye).normalized() * 40.0, 1))
	if hit.is_empty():
		return
	var flat := Vector3(target.x - from.x, 0, target.z - from.z).normalized()
	var stand: Vector3 = Vector3(hit.position.x, from.y, hit.position.z) - flat * 1.2
	await _pair(name, stand, Vector3(hit.position.x, from.y + 1.3, hit.position.z))

func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(file + ".png"))
