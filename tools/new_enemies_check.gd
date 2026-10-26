extends SceneTree
## The heavier Striker (striker2) and the Weed infected (weedzombie):
## how often they come, what the heavy growths do, and that the Weed infected's cloud gets
## the survivor high.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/new_enemies_check.gd
##   (windowed, with --shot=<folder>: also saves pictures of the cloud and of the high)

var game: Node3D
var faults: Array[String] = []
var shots := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shots = arg.trim_prefix("--shot=")
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _shot(name: String) -> void:
	if shots == "":
		return
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("saved ", name)

func _run() -> void:
	# How often the looks come.
	var heavy := 0
	var weed := 0
	for i in range(4000):
		if Infected.pick_look(Infected.TYPES.striker) == "striker2":
			heavy += 1
		if Infected.pick_look(Infected.TYPES.mauler) == "weedzombie":
			weed += 1
	print("looks: striker2 %d of 4000, weedzombie %d of 4000" % [heavy, weed])
	if heavy < 800 or heavy > 1200:
		faults.append("striker2 share %d of 4000" % heavy)
	if weed < 100 or weed > 320:
		faults.append("weedzombie share %d of 4000" % weed)
	var thin := 0
	for i in range(4000):
		if HiveDirector.pick(["striker"]) == "striker":
			thin += 1
	print("hive: a drawn striker comes %d of 4000 times" % thin)

	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.profile.mission = 1
	game.team_enabled = false
	game.start_run()
	await physics_frame
	game.begin_wave()
	var player: Node3D = game.player
	var front: Vector3 = player.global_position - player.global_basis.z * 5.0

	# The plain and the heavy Striker.
	var plain: Infected = game.spawn_enemy("striker", "striker")
	var big: Infected = game.spawn_enemy("striker", "striker2")
	for one in [plain, big]:
		one.set_physics_process(false)
	plain.position = front + Vector3(-1.5, 0.05, 0)
	big.position = front + Vector3(1.5, 0.05, 0)
	await _frames(3)
	print("health: striker %.0f, striker2 %.0f" % [plain.max_health, big.max_health])
	if not big.heavy_growths() or plain.heavy_growths() or big.max_health <= plain.max_health * 1.2:
		faults.append("the heavy Striker is not heavier (%s, %.0f vs %.0f)" % [big.heavy_growths(), big.max_health, plain.max_health])
	await _shot("strikers")
	game.fx.growths.clear()
	big.receive_hit(big.max_health * 0.6, Vector3.BACK)
	var first: int = game.fx.growths.size()
	big.receive_hit(99999, Vector3.BACK)
	var heavy_ones: int = game.fx.growths.filter(func(g: Dictionary) -> bool: return bool(g.get("heavy", false))).size()
	print("striker2 shed %d when wounded, %d in all; heavy %d" % [first, game.fx.growths.size(), heavy_ones])
	if first != 2 or game.fx.growths.size() != 6 or heavy_ones != 6:
		faults.append("striker2 shed %d then %d growths (%d heavy)" % [first, game.fx.growths.size(), heavy_ones])
	# Keep the survivor out of the blasts.
	player.global_position = front + player.global_basis.z * 30.0
	await _frames(240)
	# (The plain Striker may have been killed by the blasts and shed its own meanwhile.)
	var unburst: int = game.fx.growths.filter(func(g: Dictionary) -> bool: return bool(g.get("heavy", false))).size()
	print("plain Striker killed by the blasts: %s" % plain.dead)
	if unburst > 0:
		faults.append("%d heavy growths never burst" % unburst)

	# The Weed infected.
	if not InfectedVisual.KINDS.has("weedzombie"):
		faults.append("no model weedzombie in InfectedVisual.KINDS")
	else:
		player.global_position = front + player.global_basis.z * 5.0
		await _frames(2)
		var stoner: Infected = game.spawn_enemy("mauler", "weedzombie")
		stoner.set_physics_process(false)
		stoner.position = player.global_position - player.global_basis.z * 4.0 + Vector3(0, 0.05, 0)
		await _frames(3)
		await _shot("weedzombie")
		stoner.receive_hit(99999, Vector3.BACK)
		await _frames(30)
		var clouds: Array = game.fx.transient.get_children().filter(func(n: Node) -> bool: return n is WeedHaze)
		if clouds.size() != 1:
			faults.append("%d weed clouds after the Weed infected died" % clouds.size())
		await _shot("weed_cloud")
		var screen := WeedHaze.Screen.of(game)
		if screen.is_high():
			faults.append("high before walking into the cloud")
		if not clouds.is_empty():
			player.global_position = (clouds[0] as Node3D).global_position + Vector3(0.5, 0.05, 0)
		await _frames(150)
		print("in the cloud: high %s, strength %.2f" % [screen.is_high(), screen.level])
		if not screen.is_high() or screen.level < 0.9:
			faults.append("not high in the cloud (level %.2f)" % screen.level)
		await _shot("high")
		player.global_position += Vector3(20, 0, 0)
		# The gnomes of the high hold it while they stand (WeedVisions, its own check): gone with them.
		WeedVisions.blast(game, player.global_position, 1000.0, 99999.0)
		await _frames(40)
		await _shot("high_outside")
		await _frames(60 * 12 - 40)
		print("12 s out of the cloud: strength %.2f" % screen.level)
		if screen.level > 0.01:
			faults.append("still high 12 s after leaving the cloud (%.2f)" % screen.level)
	if faults.is_empty():
		print("NEW ENEMIES OK")
	else:
		for fault in faults:
			print("FAULT: ", fault)
		print("NEW ENEMIES FAILED")
	quit(0 if faults.is_empty() else 1)
