extends SceneTree
## Pictures of the third map (needs graphics, never headless):
##   Godot --path . -s res://tools/appenweier_shots.gd -- --capture-dir=<folder> [--only=a,b]

const VIEWS := [
	["01_house_front", Vector3(14.0, 3.0, 30.0), Vector3(0.0, 3.0, 5.0)],
	["02_house_air", Vector3(35.0, 28.0, 45.0), Vector3(-8.0, 0.0, 0.0)],
	["03_street_west", Vector3(30.0, 2.2, 44.0), Vector3(-40.0, 3.0, 44.0)],
	["04_fire_station", Vector3(-30.0, 3.0, 38.0), Vector3(-30.0, 4.0, 76.0)],
	["05_market", Vector3(110.0, 3.0, 47.0), Vector3(150.0, 3.0, 10.0)],
	["06_roundabout", Vector3(235.0, 6.0, 44.0), Vector3(272.0, 0.0, 50.0)],
	["07_overview", Vector3(110.0, 140.0, 190.0), Vector3(110.0, 0.0, 30.0)],
	["08_hall", Vector3(8.8, 1.7, 9.8), Vector3(4.0, 1.2, 4.0)],
	["09_kitchen", Vector3(-3.0, 1.7, 5.4), Vector3(1.5, 1.0, 9.5)],
	["10_music", Vector3(8.5, 1.7, -5.0), Vector3(1.0, 1.0, -9.0)],
	["11_annex", Vector3(-9.1, 1.7, 2.4), Vector3(-9.1, 1.2, -9.0)],
	["12_stube", Vector3(-10.8, 1.7, -0.8), Vector3(-15.5, 1.0, -5.0)],
	["13_werkhalle", Vector3(-17.8, 3.0, 9.5), Vector3(-28.0, 1.5, -10.0)],
	["14_garden", Vector3(12.0, 2.5, -24.0), Vector3(3.0, 1.0, -11.0)],
	["15_maize", Vector3(20.0, 1.7, 50.0), Vector3(40.0, 1.0, 70.0)],
	["16_bedroom", Vector3(-1.4, 1.7, -1.6), Vector3(-6.0, 0.8, -4.5)],
	["17_bath", Vector3(4.4, 1.7, 2.4), Vector3(0.0, 0.8, 0.0)],
	["18_study", Vector3(7.2, 1.7, 2.6), Vector3(9.0, 1.0, -3.0)],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder := ""
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(folder)
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	for i in range(3):
		await process_frame
	game.team_enabled = false
	game.profile.mission = 3
	game.start_run()
	for i in range(30):
		await process_frame
	for view in VIEWS:
		if not only.is_empty() and not only.has(str(view[0]).substr(0, 2)):
			continue
		game.player.position = view[1] + Vector3(0, -1.6, 0)
		for i in range(8):
			await process_frame
		await game.call("_capture_from", folder, str(view[0]) + ".png", view[1], view[2], 70.0)
	game.player.position = game.cabin.player_start
	await game.call("_capture", folder, "00_ego.png")
	if "--menu-picture" in OS.get_cmdline_user_args():
		# The picture on the map's card in the menu (assets/menu/appenweier.png).
		game.hud.root.hide()
		var camera := Camera3D.new()
		camera.fov = 57.0
		camera.cull_mask = 1
		game.add_child(camera)
		camera.global_position = Vector3(18.0, 6.5, 34.0)
		camera.look_at(Vector3(-4.0, 2.5, 6.0))
		camera.current = true
		for i in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.resize(1100, 619, Image.INTERPOLATE_LANCZOS)
		picture.save_png("res://assets/menu/appenweier.png")
		game.hud.root.show()
		game.return_to_menu()
		game.hud.show_menu("play")
		for i in range(8):
			await process_frame
		await game.call("_capture", folder, "99_menu_play.png")
	quit(0)
