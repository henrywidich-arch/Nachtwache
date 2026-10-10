class_name ProwlerCheck
extends Node
## Picture check of the Prowler (`--prowler-check --capture-dir=<folder>`): every clip at a
## telling moment, the look of the last fight, then half a minute of it at work against a
## survivor who does not shoot, and what it did in numbers (a line PROWLER ...).

var game: Node3D

func run() -> void:
	var folder: String = game._capture_dir()
	await get_tree().create_timer(1.5).timeout
	game.start_run()
	game.set_process(false)
	game.hud.banner_left = 0
	game.hud.radio_left = 0
	game._place_player(Vector3(-1.5, 0.05, 13.0), 180)
	var beast := game.spawn_enemy("prowler") as Prowler
	beast.position = Vector3(-0.5, 0.05, 17.5)
	beast.set_physics_process(false)
	beast.model.rotation.y = 0.0
	var body := beast.model as ProwlerVisual
	var at := beast.position
	# [file, clip, seconds into it, ground speed for a gait]
	var look_only := "--prowler-look" in OS.get_cmdline_user_args()
	var shots := [] if look_only else [
		["idle", "idle", 0.6, 0.0], ["stalk", "stalk", 0.5, 1.0], ["trot", "trot", 0.33, 3.3], ["run_a", "run", 0.31, 7.0], ["run_b", "run", 0.47, 7.0],
		["leap_crouch", "leap", 0.24, 0.0], ["leap_air", "leap", 0.55, 0.0], ["leap_land", "leap", 0.9, 0.0], ["slash", "slash_l", 0.31, 0.0], ["slam", "slam", 0.47, 0.0],
		["bite", "bite", 0.24, 0.0], ["stagger", "stagger", 0.3, 0.0], ["roar", "roar", 0.95, 0.0]
	]
	for shot: Array in shots:
		_pose(body, str(shot[1]), float(shot[2]), float(shot[3]))
		await game._capture_from(folder, "prowler_%s.png" % shot[0], at + Vector3(4.4, 1.15, -0.2), at + Vector3(0, 0.62, -0.1), 45)
	_pose(body, "idle", 0.5, 0.0)
	await game._capture_from(folder, "prowler_front.png", at + Vector3(1.6, 1.0, -3.6), at + Vector3(0, 0.65, 0), 45)
	body.set_enraged(true)
	_pose(body, "roar", 1.6, 0.0)
	_pose(body, "roar", 0.95, 0.0)
	await game._capture_from(folder, "prowler_rage.png", at + Vector3(1.9, 1.1, -3.4), at + Vector3(0, 0.7, 0), 45)
	await game._capture_from(folder, "prowler_rage_side.png", at + Vector3(4.4, 1.15, -0.2), at + Vector3(0, 0.62, -0.1), 45)
	if look_only:
		print("PROWLER_CAPTURE_COMPLETE")
		get_tree().quit()
		return
	body.set_enraged(false)
	body.die("death")
	for i in range(140):
		body.animate(1.0 / 60.0, 0.0)
	await game._capture_from(folder, "prowler_dead.png", at + Vector3(3.6, 1.6, -1.6), at + Vector3(0, 0.3, 0), 45)
	beast._retire()
	beast.queue_free()
	# At work: released a good way off, it comes in, goes round, leaps and strikes.
	var hunter := game.spawn_enemy("prowler") as Prowler
	hunter.position = Vector3(-1.5, 0.05, 30.0)
	var modes := {}
	var leaps := 0
	var top := 0.0
	var nearest := 99.0
	var was_leap := false
	var seen := {}
	var clock := 0.0
	var hurt := 0.0
	var strikes := 0
	var last_mode := ""
	var trail := ""
	while clock < 26.0 and is_instance_valid(hunter):
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		hurt += 100.0 - game.player.health
		game.player.health = 100.0
		game.player.down = false
		modes[hunter.mode] = float(modes.get(hunter.mode, 0.0)) + get_physics_process_delta_time()
		var run := hunter.get_real_velocity()
		top = maxf(top, Vector2(run.x, run.z).length())
		nearest = minf(nearest, hunter.global_position.distance_to(game.player.global_position))
		if hunter.leap == "air" and not was_leap:
			leaps += 1
		was_leap = hunter.leap == "air"
		if hunter.mode != last_mode:
			last_mode = hunter.mode
			trail += " %.1f:%s@%.1f" % [clock, hunter.mode, hunter.global_position.distance_to(game.player.global_position)]
			if hunter.mode == "strike":
				strikes += 1
		var key := "leap" if hunter.leap == "air" else hunter.mode
		if key in ["leap", "circle", "strike", "back"] and not seen.has(key) and clock > 1.0:
			seen[key] = true
			var to: Vector3 = hunter.global_position - game.player.global_position
			game._place_player(game.player.global_position, rad_to_deg(atan2(-to.x, -to.z)), -4.0)
			await game._capture(folder, "prowler_live_%s.png" % key)
	print("PROWLER_TRAIL", trail)
	var report := "PROWLER modes=%s leaps=%d strikes=%d landed=%d top=%.1f nearest=%.1f hurt=%d" % [str(modes.keys()), leaps, strikes, hunter.landed, top, nearest, int(hurt)]
	# A blast knocks it off its feet; enough of them and it breaks off and is gone.
	hunter.nerve = 400.0
	hunter.receive_hit(180.0, Vector3.BACK, false)
	var reeled := hunter.mode == "reel"
	await get_tree().create_timer(1.4).timeout
	hunter.receive_hit(300.0, Vector3.BACK, false)
	var left := hunter.leaving
	var gone := -1.0
	clock = 0.0
	while clock < 9.0:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		if not is_instance_valid(hunter):
			gone = clock
			break
	print("%s reeled=%s broke_off=%s gone_after=%.1f" % [report, str(reeled), str(left), gone])
	print("PROWLER_CAPTURE_COMPLETE")
	get_tree().quit()

## The same in mission two (`--prowler-check --prowler-hive`): taken up at the laboratories,
## a visit is called for, driven off, then the last fight in the hall.
func run_hive() -> void:
	var folder: String = game._capture_dir()
	await get_tree().create_timer(1.0).timeout
	game.profile.mission = 2
	game.intro_skipped = true
	game.hive.resume_at = "labs"
	game.start_run()
	await get_tree().create_timer(1.5).timeout
	var hive: HiveDirector = game.hive
	var prowl: HiveProwler = hive.prowl
	var player: Survivor = game.player
	hive.stage_time = 20.0
	prowl.wait_left = 0.0
	var called := false
	var clock := 0.0
	while clock < 12.0 and prowl.beast == null:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		called = called or prowl.call_left >= 0.0
		player.health = 100.0
	var beast: Prowler = prowl.beast
	if beast == null:
		print("PROWLER_HIVE no visit came (stage=%s time=%.1f wait=%.1f)" % [hive.stage, hive.stage_time, prowl.wait_left])
		get_tree().quit()
		return
	var from_gap := beast.global_position.distance_to(player.global_position)
	var hidden: bool = not hive._sees(player.camera.global_position, beast.global_position + Vector3(0, 1.3, 0))
	var bar: bool = game.boss == beast
	var shots := 0
	clock = 0.0
	while clock < 9.0 and is_instance_valid(beast) and not beast.leaving:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		player.health = 100.0
		player.down = false
		if shots < 3 and clock > 1.2 + shots * 2.2 and hive._sees(player.camera.global_position, beast.global_position + Vector3(0, 0.9, 0)):
			var to: Vector3 = beast.global_position - player.global_position
			game._place_player(player.global_position, rad_to_deg(atan2(-to.x, -to.z)), -3.0)
			await game._capture(folder, "hive_visit_%d.png" % shots)
			shots += 1
	var landed := beast.landed if is_instance_valid(beast) else -1
	var nerve := beast.nerve if is_instance_valid(beast) else -1.0
	if is_instance_valid(beast):
		beast.receive_hit(beast.nerve, Vector3.BACK, false)
	clock = 0.0
	while clock < 10.0 and is_instance_valid(beast):
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		player.health = 100.0
	print("PROWLER_HIVE visit called=%s from=%.1f hidden=%s bar=%s nerve=%d landed=%d gone_after=%.1f visits=%d wounds=%d stalker=%s" % [str(called), from_gap, str(hidden), str(bar), int(nerve), landed, clock, prowl.visits, prowl.wounds, str(is_instance_valid(game.mission.stalker))])
	# The last fight.
	hive._enter("hall")
	clock = 0.0
	while clock < 20.0 and prowl.beast == null:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		player.health = 100.0
	beast = prowl.beast
	if beast == null:
		print("PROWLER_HIVE no last fight came")
		get_tree().quit()
		return
	var came_after := clock
	var full := beast.max_health
	shots = 0
	clock = 0.0
	while clock < 12.0 and is_instance_valid(beast) and not beast.dead:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		player.health = 100.0
		player.down = false
		if shots < 4 and clock > 0.8 + shots * 2.0 and hive._sees(player.camera.global_position, beast.global_position + Vector3(0, 0.9, 0)):
			var to: Vector3 = beast.global_position - player.global_position
			game._place_player(player.global_position, rad_to_deg(atan2(-to.x, -to.z)), -3.0)
			await game._capture(folder, "hive_rage_%d.png" % shots)
			shots += 1
	var purse: int = game.credits
	var rage: bool = is_instance_valid(beast) and beast.enraged and beast.nerve == 0.0
	if is_instance_valid(beast):
		beast.receive_hit(99999.0, Vector3.BACK, false)
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(beast):
		var to: Vector3 = beast.global_position - player.global_position
		game._place_player(player.global_position, rad_to_deg(atan2(-to.x, -to.z)), -8.0)
	await game._capture(folder, "hive_dead.png")
	print("PROWLER_HIVE last came_after=%.1f health=%d enraged=%s killed=%s paid=%d armor=%d" % [came_after, int(full), str(rage), str(prowl.killed), game.credits - purse, int(player.armor)])
	print("PROWLER_CAPTURE_COMPLETE")
	get_tree().quit()

## Freezes the body `seconds` into a clip (for a gait: that long at a ground speed).
func _pose(body: ProwlerVisual, clip: String, seconds: float, speed: float) -> void:
	body.busy_left = 0.0
	body.state = "move"
	body.gait = ""
	body.backwards = false
	match clip:
		"idle", "stalk", "trot", "run":
			body.animate(0.0, speed)
			body.player.seek(0.0, true)
		"leap":
			body.pounce()
		"roar":
			body.scream()
		"stagger":
			body.stagger(true)
		_:
			body.attack(float(ProwlerVisual.BLOWS[clip][0]), float(ProwlerVisual.BLOWS[clip][1]), clip)
	var steps := int(round(seconds * 120.0))
	for i in range(steps):
		body.animate(1.0 / 120.0, speed)
