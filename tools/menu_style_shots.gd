extends SceneTree
## Pictures of the menus in the look of v0.79: login, main menu, SPIELEN (first and second
## mission, with companions), the weapon shop (a weapon to buy, one carried with its
## attachments, the attachment editor, gear) and the workbench. Nothing is saved to the
## player's file. Needs graphics:
##   tools\godot_bg.ps1 -Render -GodotArgs "-s res://tools/menu_style_shots.gd -- --out=C:/shots --no-warm-up [--only=login,main,play,shop]"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://menu_style"
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(folder)
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	var game := (load(main_scene) as PackedScene).instantiate()
	root.add_child(game)
	for i in range(30):
		await process_frame
	var profile: Profile = game.profile
	profile.stored = false
	var hud: SurvivalHUD = game.hud
	var wanted := func(name: String) -> bool: return only.is_empty() or only.has(name)
	if wanted.call("login"):
		hud.show_menu("login")
		await _save(folder.path_join("login.png"))
	if wanted.call("main"):
		hud.show_menu("main")
		await _save(folder.path_join("hauptmenue.png"))
	if wanted.call("play"):
		game.team_enabled = true
		profile.mission = 1
		hud.show_menu("play")
		await _save(folder.path_join("spielen_einsatz1.png"))
		profile.mission = 2
		hud.show_menu("play")
		await _save(folder.path_join("spielen_einsatz2.png"))
		game.team_enabled = false
		profile.mission = 3
		hud.show_menu("play")
		await _save(folder.path_join("spielen_einsatz3_ohne_bots.png"))
		profile.mission = 1
	if wanted.call("shop"):
		game.team_enabled = false
		profile.mission = 1
		game.intro_skipped = true
		game.start_run()
		game.set_process(false)
		game.player.global_position = game.cabin.points.shop + Vector3(0, 0.05, 0)
		game.credits = 1240
		game.open_shop()
		hud.counter.pick("weapon", "ak")
		await _save(folder.path_join("shop_kaufen.png"))
		hud.counter.pick("weapon", str(game.player.inventory.keys()[0]))
		await _save(folder.path_join("shop_dabei.png"))
		game.credits = 5000
		game.buy_weapon("g18")
		hud.counter.open_tab("sidearms")
		hud.counter.pick("weapon", "g18")
		var slot: Button = hud.counter.detail.find_child("Slot_sight", true, false)
		if slot != null:
			slot.pressed.emit()
			var scope: Button = hud.counter.detail.find_child("Attachment_scope", true, false)
			if scope != null:
				scope.pressed.emit()
		await _save(folder.path_join("shop_aufsaetze.png"))
		hud.counter.open_tab("gear")
		await _save(folder.path_join("shop_ausruestung.png"))
		hud.counter.open_tab("melee")
		await _save(folder.path_join("shop_nahkampf.png"))
		game.resume_run()
		var benches: Array = game.cabin.stations.filter(func(station: Dictionary) -> bool: return str(station.kind) == "upgrade")
		game.player.global_position = (benches[0].pos as Vector3) + Vector3(0, 0.05, 0)
		game.open_bench()
		await _save(folder.path_join("werkbank.png"))
	quit()

func _save(path: String) -> void:
	for i in range(14):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
