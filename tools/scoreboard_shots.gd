extends SceneTree
## Pictures of the scoreboard (Tab) and of the screen that ends a night, alone and with the
## squad, as host and as guest of a co-op match, with made-up figures.
## Needs graphics (never headless):
##   Godot --path . -s res://tools/scoreboard_shots.gd -- --out=<folder>

var game: Node3D
var folder := "res://tools/ui_review/scoreboard"

func _initialize() -> void:
	_run.call_deferred()

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_viewport().get_texture().get_image()
	var path := folder + "/" + name + ".png"
	picture.save_png(path)
	print("SHOT " + ProjectSettings.globalize_path(path))

func _start(bots: bool) -> void:
	game.hud.hide_menu()
	game.team_enabled = bots
	game.profile.mission = 1
	game.intro_skipped = true
	game.start_run()
	game.set_process(false)
	game.preparation_left = 9999.0
	await _wait(0.6)

func _figures(bots: bool) -> void:
	game.kills = 31
	game.score = 18450
	game.wave = 4
	game.elapsed = 612.0
	game.income_total = 3120
	game.tally = {"headshots": 11, "damage": 5230, "shots": 212, "hits": 118, "downs": 1, "revives": 2}
	if bots:
		var look := 0
		for mate: Teammate in game.team:
			mate.set_physics_process(false)
			mate.kills = 17 - look * 9
			mate.tally = {"headshots": 5 - look * 3, "damage": 3300 - look * 1900, "shots": 260 - look * 100, "hits": 140 - look * 70, "downs": look, "revives": 1 - look}
			mate.down = look == 1
			look += 1

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await _wait(1.0)
	game.hud.show_menu("main")
	await _wait(0.6)
	await _shot("menu_main")
	game.hud._open_settings("main")
	await _wait(0.4)
	await _shot("menu_settings")
	game.hud.show_menu("graphics")
	await _wait(0.4)
	await _shot("menu_graphics")
	game.hud.show_menu("career")
	await _wait(0.4)
	await _shot("menu_career")
	await _start(false)
	game.player.global_position = game.cabin.points.shop + Vector3(0, 0.05, 0)
	game.credits = 5000
	game.open_shop()
	await _wait(0.8)
	game.hud.counter.pick("weapon", "ak")
	await _wait(0.8)
	await _shot("shop_weapon")
	var sheet_ids: Array = Survivor.WEAPONS.keys()
	print("SHEET ", sheet_ids)
	var sheet := Image.create(1600, 118 * int(ceil(sheet_ids.size() / 4.0)), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	var at := 0
	for id: String in sheet_ids:
		var kind := Survivor.kind_of(id)
		game.hud.counter.open_tab("sidearms" if kind == "secondary" else ("heavy" if kind == "heavy" else "weapons"))
		game.hud.counter.pick("weapon", id)
		await _wait(0.25)
		await process_frame
		await RenderingServer.frame_post_draw
		var crop := root.get_viewport().get_texture().get_image().get_region(Rect2i(630, 200, 860, 230))
		crop.resize(400, 107)
		crop.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(crop, Rect2i(0, 0, 400, 107), Vector2i((at % 4) * 400, (at / 4) * 118))
		at += 1
	sheet.save_png(folder + "/shop_all_weapons.png")
	game.hud.counter.open_tab("melee")
	var melee_sheet := Image.create(1590, 495, false, Image.FORMAT_RGBA8)
	melee_sheet.fill(Color.BLACK)
	var melee_at := 0
	for id: String in Survivor.MELEE_WEAPONS.keys():
		game.hud.counter.pick("melee", id)
		await _wait(0.25)
		await process_frame
		await RenderingServer.frame_post_draw
		var crop2 := root.get_viewport().get_texture().get_image().get_region(Rect2i(630, 200, 860, 260))
		crop2.resize(530, 160)
		crop2.convert(Image.FORMAT_RGBA8)
		melee_sheet.blit_rect(crop2, Rect2i(0, 0, 530, 160), Vector2i((melee_at % 3) * 530, (melee_at / 3) * 165))
		melee_at += 1
	melee_sheet.save_png(folder + "/shop_melee.png")
	var turned := Image.create(1590, 330, false, Image.FORMAT_RGBA8)
	turned.fill(Color.BLACK)
	var cell := 0
	for id in ["hammer", "axe", "knife", "machete"]:
		game.hud.counter.pick("melee", id)
		await _wait(0.4)
		for turn in [0.0, PI * 0.5]:
			var mdl2: Node3D = game.hud.counter.stage.models["melee_" + id]
			mdl2.rotation.y = turn
			game.hud.counter.stage.manual = true
			game.hud.counter.stage.yaw = 0.0
			game.hud.counter.stage.pitch = 0.0
			await _wait(0.3)
			await process_frame
			await RenderingServer.frame_post_draw
			var c3 := root.get_viewport().get_texture().get_image().get_region(Rect2i(830, 200, 460, 260))
			c3.resize(265, 150)
			c3.convert(Image.FORMAT_RGBA8)
			turned.blit_rect(c3, Rect2i(0, 0, 265, 150), Vector2i((cell % 6) * 265, (cell / 6) * 160))
			cell += 1
	turned.save_png(folder + "/shop_melee_turns.png")
	game.hud.counter.pick("melee", "axe")
	await _wait(0.4)
	await _shot("shop_melee_axe")
	# A drag turns it.
	var stage: WeaponShow = game.hud.counter.stage
	stage.manual = false
	stage._gui_input(_click(true))
	stage._gui_input(_motion(Vector2(90, -30)))
	stage._gui_input(_click(false))
	await _wait(0.3)
	await _shot("shop_melee_axe_dragged")
	game.resume_run()
	# Alone, without bots.
	await _start(false)
	_figures(false)
	game.player.scatter_in_checks = true
	game.player.rotation.y += PI * 0.5
	game.player.global_position += Vector3(0, 0, -1.5)
	for i in range(14):
		game.player.shot_cooldown = 0.0
		game.player.ammo = 30
		game.player.shoot()
	game.player.camera.rotation.x = 0.0
	await _wait(2.5)
	await _shot("bullet_holes")
	var crop := root.get_viewport().get_texture().get_image().get_region(Rect2i(560, 300, 480, 300))
	crop.resize(960, 600)
	crop.save_png(folder + "/bullet_holes_zoom.png")
	print("HOLES ", game.holes.pool.size())
	Input.action_press("scoreboard")
	game.hud._process(0.05)
	await _shot("solo_tab")
	Input.action_release("scoreboard")
	game.hud._process(0.05)
	# Alone with the squad.
	await _start(true)
	_figures(true)
	Input.action_press("scoreboard")
	game.hud._process(0.05)
	await _shot("squad_tab")
	Input.action_release("scoreboard")
	game.player.items.grenade = 2
	game.player.items.flashbang = 1
	game.player.items.heal = 3
	game.hud._process(0.05)
	await _wait(1.0)
	print("ROWS ", game.hud.team_rows.size(), " ", game.team.size(), " ", game.team[0].down if game.team.size() > 0 else "-", " ", game.team[1].down if game.team.size() > 1 else "-", " ", game.hud.team_box.get_global_rect(), " ", game.hud.team_box.visible)
	await _shot("hud_squad_down")
	game.state = "lose"
	game.hud.play_ui.hide()
	game.hud.show_menu("lose")
	await _shot("squad_end_instant")
	# The same night as a co-op host with a partner: the partner's figures come from his machine.
	await _start(true)
	_figures(true)
	var partner := RemoteSurvivor.new()
	partner.game = game
	game.mates.add_child(partner)
	partner.label = "FALKE-417"
	partner.kills = 22
	partner.tally = {"headshots": 7, "damage": 4100, "shots": 180, "hits": 99, "downs": 0, "revives": 3}
	game.net.remote = partner
	game.net.player_name = "WOLF-212"
	game.net.partner_name = "FALKE-417"
	Input.action_press("scoreboard")
	game.hud._process(0.05)
	await _shot("coop_host_tab")
	Input.action_release("scoreboard")
	game.hud._process(0.05)
	# The same table on the guest's machine.
	var rows: Array = preload("res://scripts/scoreboard.gd").roster(game)
	game.net.remote = null
	partner.queue_free()
	game.net.joined = true
	game.net.roster = rows
	game.net.player_name = "FALKE-417"
	game.net.partner_name = "WOLF-212"
	game.team.clear()
	game.kills = 22
	game.tally = {"headshots": 7, "damage": 4100, "shots": 180, "hits": 99, "downs": 0, "revives": 3}
	Input.action_press("scoreboard")
	game.hud._process(0.05)
	await _shot("coop_guest_tab")
	Input.action_release("scoreboard")
	game.hud._process(0.05)
	game.net.joined = false
	# The ending, played out: lost.
	game.net.roster = []
	await _start(true)
	_figures(true)
	game.state = "lose"
	game.hud.play_ui.hide()
	game.hud.end_reveal = true
	game.hud.show_menu("lose")
	var clock := 0.0
	for stamp in [0.5, 2.0, 3.4, 5.0, 6.0, 7.5]:
		await _wait(stamp - clock)
		clock = stamp
		await _shot("lose_%04.1f" % stamp)
	# Won, alone without bots, played out.
	await _start(false)
	_figures(false)
	game.state = "win"
	game.hud.play_ui.hide()
	game.hud.end_reveal = true
	game.hud.show_menu("win")
	clock = 0.0
	for stamp in [3.0, 7.5]:
		await _wait(stamp - clock)
		clock = stamp
		await _shot("win_%04.1f" % stamp)
	print("SCOREBOARD_SHOTS_DONE")
	quit()

func _click(down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	return event

func _motion(by: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = by
	return event
