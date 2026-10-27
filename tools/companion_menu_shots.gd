extends SceneTree
## Pictures of the page that starts a game with the companions to tick (v0.79): the first
## mission with Viper and Scorpion, the second with Raven and Havoc (Havoc joins at the
## station), and the first again with that choice (Havoc greyed out, one of the squad comes
## for him). Nothing is saved. Run with tools/godot_bg.ps1 -Render (never headless):
##   -s res://tools/companion_menu_shots.gd -- --out=<folder> --no-warm-up

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://companion_menu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	var game := (load(main_scene) as PackedScene).instantiate()
	root.add_child(game)
	for i in range(30):
		await process_frame
	var profile: Profile = game.profile
	profile.stored = false
	game.team_enabled = true
	var kept := [profile.mission, profile.picks.duplicate(), profile.squad.duplicate(), profile.company]
	profile.mission = 1
	profile.set_picks("viper", "scorpion")
	game.hud.show_menu("play")
	await _save(folder.path_join("begleiter_einsatz1.png"))
	profile.mission = 2
	profile.set_picks("raven" if profile.unlocked("raven") else "viper", "havoc")
	game.hud.show_menu("play")
	await _save(folder.path_join("begleiter_einsatz2_mit_havoc.png"))
	profile.mission = 1
	game.hud.show_menu("play")
	await _save(folder.path_join("begleiter_einsatz1_havoc_ausgegraut.png"))
	profile.mission = kept[0]
	profile.picks = kept[1]
	profile.squad = kept[2]
	profile.company = kept[3]
	quit()

func _save(path: String) -> void:
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
