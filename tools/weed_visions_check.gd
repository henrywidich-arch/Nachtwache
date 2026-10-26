extends SceneTree
## The gnomes of the Weed high (WeedVisions): the cloud of a Weed infected gets the survivor
## high, a horde of small and big gnomes comes running and hits him, the music goes over to
## "rausch", shots, blows and blasts bring them down, and once they are gone the high wears off.
##   powershell -File tools\godot_bg.ps1 "-s res://tools/weed_visions_check.gd"
##   (with -Render and -- --shot=<folder>: also saves pictures of the horde)

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
	for look in WeedVisions.LOOKS:
		if not InfectedVisual.KINDS.has(look):
			faults.append("no model %s in InfectedVisual.KINDS" % look)
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
	# Nobody else in the way.
	for node in get_nodes_in_group("infected"):
		node.queue_free()
	game.set_physics_process(false)
	var player: Node3D = game.player
	# (With a window the start of the night clears the effects a little later.)
	await _frames(90)

	var stoner: Infected = game.spawn_enemy("mauler", "weedzombie")
	stoner.set_physics_process(false)
	stoner.position = player.global_position - player.global_basis.z * 4.0 + Vector3(0, 0.05, 0)
	await _frames(3)
	var started := Time.get_ticks_msec()
	stoner.receive_hit(99999, Vector3.BACK)
	print("cloud burst and gnomes prepared in %d ms" % (Time.get_ticks_msec() - started))
	var clouds: Array = []
	for i in range(240):
		await physics_frame
		clouds = game.fx.transient.get_children().filter(func(n: Node) -> bool: return n is WeedHaze)
		if not clouds.is_empty():
			print("cloud after %d frames, %.1f s left, %d fps, time scale %.2f" % [i, (clouds[0] as WeedHaze).left, Engine.get_frames_per_second(), Engine.time_scale])
			break
	if clouds.is_empty():
		faults.append("no weed cloud")
		_finish()
		return
	if WeedVisions.of(game) != null:
		faults.append("gnomes before anybody breathed the cloud")
	player.global_position = (clouds[0] as Node3D).global_position + Vector3(0.5, 0.05, 0)
	var health_before: float = player.health
	await _frames(60 * 5)
	print("state %s, high %s" % [game.state, WeedHaze.Screen.of(game).is_high()])
	var visions := WeedVisions.of(game)
	if visions == null:
		var high := WeedHaze.Screen.of(game)
		print("cloud at %s, player at %s, high %.1f s, screen knows the game %s" % [(clouds[0] as Node3D).global_position if is_instance_valid(clouds[0]) else Vector3.ZERO, player.global_position, high.time_left, high.game != null])
		faults.append("no gnomes in the high")
		_finish()
		return
	var small := visions.gnomes.filter(func(g: WeedVisions.Gnome) -> bool: return not g.big).size()
	var big := visions.gnomes.filter(func(g: WeedVisions.Gnome) -> bool: return g.big).size()
	var looks := {}
	for gnome in visions.gnomes:
		looks[gnome.look] = int(looks.get(gnome.look, 0)) + 1
	print("after 6 s: %d small, %d big gnomes %s, music phase %s" % [small, big, looks, game.music.current_phase()])
	if small < int(WeedVisions.SMALL.count[0]) or big < int(WeedVisions.BIG.count[0]):
		faults.append("too few gnomes (%d small, %d big)" % [small, big])
	if game.music.current_phase() != "rausch":
		faults.append("music phase %s in the high" % game.music.current_phase())
	var near := 0
	var spread := 0.0
	for gnome in visions.gnomes:
		var gap: float = gnome.global_position.distance_to(player.global_position)
		spread += gap
		if gap < 2.5:
			near += 1
	print("gnomes within 2.5 m: %d, mean distance %.1f m; health %.0f -> %.0f" % [near, spread / visions.gnomes.size(), health_before, player.health])
	if near < 4:
		faults.append("only %d gnomes reached the player" % near)
	if player.health >= health_before:
		faults.append("the gnomes did no harm (%.0f -> %.0f)" % [health_before, player.health])
	if player.health <= 0.0:
		faults.append("five seconds of gnomes killed the survivor")
	await _shot("gnomes_close")
	# Turn round, to see the rest of the horde.
	player.rotation.y += PI
	await _frames(20)
	await _shot("gnomes_round")
	# Out of the cloud, so that the high can wear off once they are gone.
	var away: Vector3 = player.global_position + Vector3(4, 0, 0)
	player.global_position = game.fx.floor_below(away + Vector3.UP)
	await _frames(30)
	print("health after 6 s with them: %.0f" % player.health)
	if shots != "":
		# Face the horde as it comes after him, looking down at it.
		for i in range(3):
			var middle := Vector3.ZERO
			for gnome in visions.gnomes:
				middle += gnome.global_position
			middle /= visions.gnomes.size()
			var way: Vector3 = middle - player.global_position
			player.rotation.y = atan2(-way.x, -way.z)
			player.camera.rotation.x = -0.45
			await _frames(25)
			await _shot("gnomes_coming_%d" % i)

	# Shots, blows and a blast.
	var target: WeedVisions.Gnome = visions.gnomes[0]
	var hit := WeedVisions.shot(game, target, 9999.0, Vector3.FORWARD, target.global_position + Vector3.UP * 0.5)
	if not hit or not target.dead:
		faults.append("a shot did not bring a gnome down")
	var struck := WeedVisions.melee(game, player.global_position, -player.global_basis.z, 2.5, 9999.0)
	print("one blow struck %d" % struck)
	WeedVisions.blast(game, player.global_position, 30.0, 9999.0)
	var standing := visions.gnomes.filter(func(g: WeedVisions.Gnome) -> bool: return not g.dead).size()
	print("after the blast %d standing" % standing)
	if standing > 0:
		faults.append("%d gnomes stood a blast" % standing)
	await _frames(60 * 3)
	if is_instance_valid(visions) and WeedVisions.of(game) != null:
		faults.append("the visions did not end when the gnomes were down")
	await _frames(60 * 10)
	var screen := WeedHaze.Screen.of(game)
	print("13 s after the last gnome: strength %.2f, music phase %s" % [screen.level, game.music.current_phase()])
	if screen.level > 0.01:
		faults.append("still high after the gnomes were gone (%.2f)" % screen.level)
	_finish()

func _finish() -> void:
	if faults.is_empty():
		print("WEED VISIONS OK")
	else:
		for fault in faults:
			print("FAULT: ", fault)
		print("WEED VISIONS FAILED")
	quit(0 if faults.is_empty() else 1)
