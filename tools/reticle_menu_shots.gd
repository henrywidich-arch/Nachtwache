extends SceneTree
## Pictures of the settings page and the reticle workshop (VISIER-WERKSTATT) in the real
## menu, in the default red and in two other set-ups (chosen here without being saved).
## Run with tools/godot_bg.ps1 -Render (never headless):
##   -s res://tools/reticle_menu_shots.gd -- --out=<folder> --no-warm-up

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://reticle_menu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	var game := (load(main_scene) as PackedScene).instantiate()
	root.add_child(game)
	for i in range(30):
		await process_frame
	# (Nothing chosen here goes into the player's settings file.)
	game.profile.stored = false
	var before := [Reticle.color, Reticle.size, Reticle.thick, Reticle.glow]
	Reticle.reset()
	game.hud._open_settings("main")
	await _save(folder.path_join("einstellungen.png"))
	game.hud.show_menu("reticle")
	await _save(folder.path_join("werkstatt_rot.png"))
	Reticle.choose(Color(0.15, 1.0, 0.2), 1.4, 1.6, 1.2)
	game.hud.show_menu("reticle")
	await _save(folder.path_join("werkstatt_gruen.png"))
	Reticle.choose(Color.from_hsv(0.55, 0.92, 1.0), 0.8, 0.7, 0.8)
	game.hud.show_menu("reticle")
	await _save(folder.path_join("werkstatt_eigener_farbton.png"))
	Reticle.choose(before[0], before[1], before[2], before[3])
	quit()

func _save(path: String) -> void:
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
