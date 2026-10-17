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
	# It only comes to open ground: the squad's leader stands in the ring for it.
	game._place_player(hive._point("junction") + Vector3(0, 0.05, 0), 0)
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
	# The last fight, in the hall itself.
	hive._enter("hall")
	game._place_player(hive._point("hall_end") + Vector3(0, 0.05, 0), 0)
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

## What it can do since it learnt more (`--prowler-check --prowler-attacks`): the clips of
## the pin, the charge and the sweep at a telling moment, the pin seen by who lies under it,
## and half a minute against a survivor who stands still: which of its ways it used.
func run_attacks() -> void:
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
	for shot: Array in [["pin", "pin", 0.25], ["wind", "wind", 0.3], ["charge", "charge", 0.2], ["sweep_a", "sweep", 0.34], ["sweep_b", "sweep", 0.52]]:
		body.pinning = str(shot[1]) == "pin"
		body.charging = str(shot[1]) == "charge"
		_pose(body, str(shot[1]), float(shot[2]), 9.0 if str(shot[1]) == "charge" else 0.0)
		await game._capture_from(folder, "attacks_%s.png" % shot[0], at + Vector3(2.8, 1.5, -3.4), at + Vector3(0, 0.6, 0), 45)
	beast._retire()
	beast.queue_free()
	var hunter := game.spawn_enemy("prowler") as Prowler
	hunter.position = Vector3(-1.5, 0.05, 24.0)
	hunter.pin_cooldown = 0.0
	var used := {}
	var pinned := 0.0
	var shot_pin := false
	var hurt := 0.0
	var clock := 0.0
	while clock < 30.0 and is_instance_valid(hunter):
		await get_tree().physics_frame
		var step := get_physics_process_delta_time()
		clock += step
		hurt += 100.0 - game.player.health
		game.player.health = 100.0
		game.player.down = false
		used[hunter.mode] = true
		if hunter.mode == "pin":
			pinned += step
			if not shot_pin and pinned > 0.6:
				shot_pin = true
				await game._capture(folder, "attacks_pinned_view.png")
			if pinned > 2.0:
				hunter.receive_hit(Prowler.PIN_BREAK * hunter.level + 1.0, Vector3.BACK, false)
	print("PROWLER_ATTACKS used=%s pinned=%.1fs hurt=%d landed=%d" % [str(used.keys()), pinned, int(hurt), hunter.landed if is_instance_valid(hunter) else -1])
	print("PROWLER_CAPTURE_COMPLETE")
	get_tree().quit()

## Its spit (`--prowler-check --prowler-spit`): the tell, the glob in the air, the pool
## where it came down - seen from beside it, from inside it and in its last second.
func run_spit() -> void:
	var folder: String = game._capture_dir()
	await get_tree().create_timer(1.5).timeout
	game.start_run()
	game.set_process(false)
	game.hud.banner_left = 0
	game.hud.radio_left = 0
	game._place_player(Vector3(-1.5, 0.05, 13.0), 180)
	var beast := game.spawn_enemy("prowler") as Prowler
	beast.position = Vector3(-1.5, 0.05, 25.0)
	beast.set_physics_process(false)
	beast.model.rotation.y = 0.0
	beast.prey = game.player
	var at := beast.position
	beast._start_spit()
	for i in range(34):
		beast.model.animate(1.0 / 60.0, 0.0)
	await game._capture_from(folder, "spit_tell.png", at + Vector3(2.8, 1.5, -3.4), at + Vector3(0, 0.7, 0), 45)
	for i in range(18):
		beast.model.animate(1.0 / 60.0, 0.0)
	beast.show_cue("spit", [beast.mouth() + beast.facing() * 0.9, game.player.global_position, 0.8, 1.0])
	var glob: ProwlerPool.Glob = ProwlerPool.globs[0]
	glob.set_physics_process(false)
	glob._physics_process(0.4)
	await game._capture_from(folder, "spit_glob.png", Vector3(4.5, 1.8, 19.0), Vector3(-1.5, 1.2, 19.0), 55)
	glob._physics_process(0.5)
	var pool: ProwlerPool = ProwlerPool.pools[0] if not ProwlerPool.pools.is_empty() else null
	await get_tree().create_timer(0.8).timeout
	game.player.health = 100.0
	game.hud.banner_left = 0
	await game._capture(folder, "spit_pool_inside.png")
	var spot := Vector3(-1.5, 0.0, 13.0)
	game._place_player(spot + Vector3(0, 0.05, 3.4), 0, -14.0)
	await get_tree().create_timer(0.4).timeout
	await game._capture(folder, "spit_pool_edge.png")
	await game._capture_from(folder, "spit_pool_above.png", spot + Vector3(4.0, 3.4, 5.5), spot, 55)
	if pool != null:
		pool.left = 0.9
	await get_tree().create_timer(0.45).timeout
	await game._capture_from(folder, "spit_pool_fading.png", spot + Vector3(4.0, 3.4, 5.5), spot, 55)
	print("PROWLER_SPIT pool=%s reach=%.1f" % [str(pool != null), pool.reach() if is_instance_valid(pool) else -1.0])
	print("PROWLER_CAPTURE_COMPLETE")
	get_tree().quit()

## How it turns (`--prowler-check --prowler-moves`): the clips of turning, braking and
## shaking at a telling moment, then a quarter of a minute of it at work with its prey
## behind it at the start, and in numbers how often it came round over its haunches,
## slid to a stand, and how fast it turned at most.
func run_moves() -> void:
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
	for shot: Array in [["turn_a", "turn", 0.1], ["turn_b", "turn", 0.3], ["pivot_a", "pivot", 0.16], ["pivot_b", "pivot", 0.28], ["brake", "brake", 0.2], ["shake", "shake", 0.42]]:
		body.turn_rate = 2.6 if str(shot[1]) == "turn" else 0.0
		_pose(body, str(shot[1]), float(shot[2]), 0.0)
		await game._capture_from(folder, "moves_%s.png" % shot[0], at + Vector3(2.8, 1.5, -3.4), at + Vector3(0, 0.6, 0), 45)
	# A curve at a gallop, frozen: the spine bent, the head ahead, the body leaning in.
	body.turn_rate = 2.4
	_pose(body, "run", 0.5, 7.0)
	await game._capture_from(folder, "moves_curve.png", at + Vector3(0.0, 2.4, -4.6), at + Vector3(0, 0.6, 0), 45)
	await game._capture_from(folder, "moves_curve_top.png", at + Vector3(0.0, 6.0, -0.1), at, 45)
	# (To the left of an animal that looks along -Z is -X: both numbers are above 0 when it bends and leans into a left curve.)
	print("PROWLER_CURVE head_left=%.2f lean_left=%.2f" % [-(body.head_position().x - beast.global_position.x), -body.holder.global_transform.basis.y.x])
	beast._retire()
	beast.queue_free()
	# At work: it starts with its back to its prey.
	var hunter := game.spawn_enemy("prowler") as Prowler
	hunter.position = Vector3(-1.5, 0.05, 22.0)
	hunter.model.rotation.y = PI
	var pivots := 0
	var brakes := 0
	var top := 0.0
	var turns := 0.0
	var last_mode := ""
	var seen := {}
	var clock := 0.0
	while clock < 16.0 and is_instance_valid(hunter):
		await get_tree().physics_frame
		var step := get_physics_process_delta_time()
		clock += step
		game.player.health = 100.0
		game.player.down = false
		top = maxf(top, absf(hunter.turning))
		if (hunter.model as ProwlerVisual).gait.begins_with("turn"):
			turns += step
		if hunter.mode != last_mode:
			last_mode = hunter.mode
			pivots += 1 if hunter.mode == "pivot" else 0
			brakes += 1 if hunter.mode == "brake" else 0
		var run := hunter.get_real_velocity()
		var key := ""
		if hunter.mode == "pivot" and hunter.pivot_clock > 0.2:
			key = "pivot"
		elif hunter.mode == "brake":
			key = "brake"
		elif absf(hunter.turning) > 1.7 and Vector2(run.x, run.z).length() > 5.0:
			key = "curve"
		if key != "" and not seen.has(key):
			seen[key] = true
			var here := hunter.global_position
			await game._capture_from(folder, "moves_live_%s.png" % key, here + Vector3(3.6, 1.7, 2.4), here + Vector3(0, 0.6, 0), 50)
	print("PROWLER_MOVES pivots=%d brakes=%d top_turn=%d deg/s stepping=%.1fs landed=%d seen=%s" % [pivots, brakes, int(rad_to_deg(top)), turns, hunter.landed if is_instance_valid(hunter) else -1, str(seen.keys())])
	print("PROWLER_CAPTURE_COMPLETE")
	get_tree().quit()

## Where it can come (`--prowler-check --prowler-map`, runs headless): for every room of
## mission two the free ground at its best spot and how wide it is there, and for every
## stage's goal whether it would come to somebody standing there.
func run_map() -> void:
	await get_tree().create_timer(1.0).timeout
	game.profile.mission = 2
	game.intro_skipped = true
	game.hive.resume_at = "labs"
	game.start_run()
	await get_tree().create_timer(1.0).timeout
	var hive: HiveDirector = game.hive
	var prowl: HiveProwler = hive.prowl
	for room: Dictionary in hive.map.rooms:
		var outer: Rect2 = room.outer
		var best := 0.0
		var wide := 0.0
		for fx: float in [0.5, 0.25, 0.75]:
			for fz: float in [0.5, 0.25, 0.75]:
				var at := Vector3(outer.position.x + outer.size.x * fx, float(room.y) + 0.1, outer.position.y + outer.size.y * fz)
				var ground := prowl.open_ground(at)
				if ground > best:
					best = ground
					wide = prowl.width_of(at)
		print("PROWLER_ROOM %-16s level=%d size=%4.1fx%4.1f ground=%3d width=%.1f %s" % [str(room.id), int(room.level), outer.size.x, outer.size.y, int(best), wide, "COMES" if best >= HiveProwler.ROOM_MIN else ("stays" if best >= HiveProwler.ROOM_STAY else "never")])
	for stage: String in HiveDirector.ORDER:
		var goal: Vector3 = hive._point(str(HiveDirector.STAGES[stage][2]))
		if goal != Vector3.INF:
			print("PROWLER_STAGE %-10s goal=%-12s ground=%3d width=%.1f away=%s" % [stage, str(HiveDirector.STAGES[stage][2]), int(prowl.open_ground(goal)), prowl.width_of(goal), str(HiveProwler.AWAY.has(stage))])
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
		"turn", "pin", "charge":
			body.animate(0.0, speed)
		"wind":
			body.wind()
		"sweep":
			body.attack(0.9, 0.5, "sweep")
		"pivot":
			body.pivot(true)
		"brake":
			body.brake()
		"shake":
			body.shake()
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

# ---------------------------------------------------------------- the ways it finds

## A stand-in for somebody it hunts: it only stands there.
class Target extends Node3D:
	func is_targetable() -> bool:
		return true

	func receive_damage(_amount: float, _from: Vector3 = Vector3.INF, _kind: String = "", _by: String = "") -> void:
		pass

## How it finds its way (`--prowler-check --prowler-paths`, headless, with --hive-layout=all):
## the Prowler is put into many places of the facility and the areas, its prey somewhere
## else in the same area - in the same room, through doors, on another level - and every
## run says whether it got there, how long it took, how long it stood against something,
## how long it scraped along walls and how often it turned back. A PROWLER_PATHS line sums
## it up. Same pairs every time (the dice are seeded).
func run_paths() -> void:
	await get_tree().create_timer(1.0).timeout
	game.profile.mission = 2
	game.intro_skipped = true
	game.team_enabled = false
	game.hive.resume_at = "labs"
	# (Every area of the pool in its seam: the night the tools call "all".)
	game.hive.seed_wanted = -4
	game.start_run()
	await get_tree().create_timer(1.0).timeout
	var hive: HiveDirector = game.hive
	var map: HiveMap = hive.map
	game.set_process(false)
	hive.set_process(false)
	hive.set_physics_process(false)
	hive.prowl.set_process(false)
	if hive.entries != null:
		hive.entries.set_process(false)
		hive.entries.set_physics_process(false)
	for id in map.areas:
		map.unlock(id, true)
	hive._clear_enemies()
	game.player.global_position = Vector3(0, -400, 0)
	game.player.set_physics_process(false)
	var dice := RandomNumberGenerator.new()
	dice.seed = 1717
	# Places: a free spot near the middle of every room one can walk in.
	var spots: Array[Dictionary] = []
	for room: Dictionary in map.rooms:
		var outer: Rect2 = room.outer
		var middle := Vector3(outer.get_center().x, float(room.y) + 0.1, outer.get_center().y)
		var level: int = int(room.level)
		var cell: Vector2i = map.nearest_cell(middle, level)
		var at := Vector3(cell.x * CabinMap.CELL, map.level_height(level), cell.y * CabinMap.CELL)
		if at.distance_to(middle) > 4.0 or str(room.get("zone", "")) == "" and map.area_of(at) == "":
			continue
		# (The random areas have no area name of their own: their zone tells them apart.)
		var group: String = map.area_of(at) if map.area_of(at) != "" else "~" + str(room.zone)
		# (Only where it comes: the facility from the administration on, and the areas.)
		if group in ["~house", "~terminal", "descent", "station", "~park"]:
			continue
		spots.append({"at": at, "room": str(room.id), "area": group, "level": map.level_of(at)})
	var pairs: Array = []
	for a in spots:
		for b in spots:
			if a == b or a.area != b.area:
				continue
			var gap := Vector2(a.at.x - b.at.x, a.at.z - b.at.z).length()
			if gap >= 6.0 and gap <= 34.0 and map.path_between(a.at, b.at).size() >= 2:
				pairs.append([a, b])
	# A fixed choice of them: as many of other levels as there are, the rest at random.
	var chosen: Array = []
	var other: Array = pairs.filter(func(p: Array) -> bool: return int(p[0].level) != int(p[1].level))
	var same: Array = pairs.filter(func(p: Array) -> bool: return int(p[0].level) == int(p[1].level))
	for list: Array in [other, same]:
		for i in range(list.size() - 1, 0, -1):
			var j := dice.randi_range(0, i)
			var keep: Variant = list[i]
			list[i] = list[j]
			list[j] = keep
	var limit := 96
	for p in other.slice(0, 40):
		chosen.append(p)
	for p in same:
		if chosen.size() >= limit:
			break
		chosen.append(p)
	var trace := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prowler-trace="):
			var ends := arg.trim_prefix("--prowler-trace=").split(":")
			trace = true
			chosen = pairs.filter(func(p: Array) -> bool: return str(p[0].room) == ends[0] and str(p[1].room) == ends[1])
	# Four times as fast, in steps as short as at normal speed (a step of a fifteenth of a
	# second would carry it past the points of its way).
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	var totals := {"open": 0, "open_reached": 0, "tight": 0, "tight_kept_out": 0, "open_time": 0.0, "runs": 0, "reached": 0, "time": 0.0, "stuck": 0.0, "scrape": 0.0, "flips": 0, "levels": 0, "levels_reached": 0, "moved": 0}
	var batch := 6
	for first in range(0, chosen.size(), batch):
		var runs: Array[Dictionary] = []
		for k in range(first, mini(first + batch, chosen.size())):
			var p: Array = chosen[k]
			var target := Target.new()
			game.add_child(target)
			target.global_position = p[1].at
			# (Put in as the director does it: spawn_enemy would send it through a way in.)
			var beast := Prowler.new()
			beast.game = game
			beast.wave = 1
			beast.kind = "prowler"
			beast.uncounted = true
			beast.position = p[0].at + Vector3(0, 0.08, 0)
			game.enemies.add_child(beast)
			beast.prey = target
			beast.nerve = 0.0
			beast.roomy = hive.prowl.may_follow
			beast.width = hive.prowl.width_of
			runs.append({"open": hive.prowl.open_ground(p[1].at) >= HiveProwler.ROOM_STAY, "near": 99.0, "beast": beast, "target": target, "from": p[0], "to": p[1], "t": -1.0, "stuck": 0.0, "scrape": 0.0, "flips": 0, "last": Vector3.ZERO, "modes": {}, "start": beast.position})
		var clock := 0.0
		var feel_left := 0.0
		while clock < 30.0:
			await get_tree().physics_frame
			var step := get_physics_process_delta_time()
			clock += step
			# Doors open for whoever comes near them (the director does this; it is switched off here).
			feel_left -= step
			if feel_left <= 0.0:
				feel_left = 0.12
				var actors := PackedVector3Array()
				for run in runs:
					if is_instance_valid(run.beast):
						actors.append((run.beast as Node3D).global_position)
				map.feel(actors)
			var open := 0
			for run in runs:
				var beast: Prowler = run.beast
				if not is_instance_valid(beast) or float(run.t) >= 0.0:
					continue
				open += 1
				beast.swap_left = 99.0
				beast.prey = run.target
				run.modes[beast.mode] = true
				var at: Vector3 = beast.global_position
				var to: Vector3 = run.to.at
				if beast.collision_layer != 0:
					run.near = minf(float(run.near), at.distance_to(to))
				if Vector2(at.x - to.x, at.z - to.z).length() < 2.6 and absf(at.y - to.y) < 1.5:
					run.t = clock
					continue
				var real := beast.get_real_velocity()
				var going := Vector2(real.x, real.z).length()
				if trace and run == runs[0] and fmod(clock, 0.5) < step:
					var next: Vector3 = beast.path[beast.path_index] if beast.path_index < beast.path.size() else Vector3.INF
					print("PROWLER_TRACE t=%.1f at=(%.1f %.1f %.1f) mode=%s pace=%.1f go=%.1f path=%d/%d next=(%.1f %.1f) hits=%d aim=%s shift=%s tight=%s back=%.1f" % [clock, at.x, at.y, at.z, beast.mode, beast.gait_pace, going, beast.path_index, beast.path.size(), next.x, next.z, beast.get_slide_collision_count(), str(beast.get("aim_point")), str(beast.get("shift_phase")), str(beast.tight), float(beast.get("backup_left")) if "backup_left" in beast else 0.0])
				if beast.mode in ["close", "rush", "flee", "evade"] and beast.gait_pace > 2.0 and going < 0.6:
					run.stuck = float(run.stuck) + step
				for i in range(beast.get_slide_collision_count()):
					var hit := beast.get_slide_collision(i)
					if not (hit.get_collider() is CharacterBody3D) and absf(hit.get_normal().y) < 0.5 and going > 0.5:
						run.scrape = float(run.scrape) + step
						break
				var heading := Vector3(real.x, 0, real.z).normalized()
				if heading.dot(run.last) < -0.5:
					run.flips = int(run.flips) + 1
				if going > 0.5:
					run.last = heading
			if open == 0:
				break
		for run in runs:
			var beast: Prowler = run.beast
			var levels := int(run.from.level) != int(run.to.level)
			var moved := is_instance_valid(beast) and beast.global_position.distance_to(run.start) > 3.0
			print("PROWLER_PATH %s %-10s %-14s -> %-14s %s gap=%4.1f %s t=%4.1f stuck=%4.1f scrape=%4.1f flips=%d end=%s shifts=%d modes=%s" % ["open " if bool(run.open) else "TIGHT", str(run.from.area), str(run.from.room), str(run.to.room), "LEVELS" if levels else "same  ", Vector2(run.from.at.x - run.to.at.x, run.from.at.z - run.to.at.z).length(), "REACHED" if float(run.t) >= 0.0 else "missed ", maxf(0.0, float(run.t)), float(run.stuck), float(run.scrape), int(run.flips), beast.mode if is_instance_valid(beast) else "-", int(beast.get("shifts")) if is_instance_valid(beast) and "shifts" in beast else -1, ",".join(run.modes.keys())])
			totals.runs += 1
			if bool(run.open):
				totals.open += 1
				totals.open_reached += 1 if float(run.t) >= 0.0 else 0
				totals.open_time += maxf(0.0, float(run.t))
			else:
				totals.tight += 1
				totals.tight_kept_out += 1 if float(run.t) < 0.0 and float(run.near) > 3.0 else 0
			totals.reached += 1 if float(run.t) >= 0.0 else 0
			totals.time += maxf(0.0, float(run.t))
			totals.stuck += float(run.stuck)
			totals.scrape += float(run.scrape)
			totals.flips += int(run.flips)
			totals.levels += 1 if levels else 0
			totals.levels_reached += 1 if levels and float(run.t) >= 0.0 else 0
			totals.moved += 1 if moved else 0
			if is_instance_valid(beast):
				beast._retire()
				beast.queue_free()
			(run.target as Node).queue_free()
		await get_tree().physics_frame
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	print("PROWLER_OPEN prey on open ground: reached %d of %d, mean %.1f s | prey somewhere tight: kept out %d of %d" % [totals.open_reached, totals.open, totals.open_time / maxf(1.0, totals.open_reached), totals.tight_kept_out, totals.tight])
	print("PROWLER_PATHS runs=%d reached=%d (other level %d of %d) mean_time=%.1f stuck=%.1f scrape=%.1f flips=%d moved=%d" % [totals.runs, totals.reached, totals.levels_reached, totals.levels, totals.time / maxf(1.0, totals.reached), totals.stuck, totals.scrape, totals.flips, totals.moved])
	print("PROWLER_CAPTURE_COMPLETE")
	get_tree().quit()

## A frame sequence of it on its way (`--prowler-check --prowler-way=<room>:<room>[:<name>]`,
## through the hidden runner): from one room to another of every area's night, seen from
## behind and above it every third of a second, twelve pictures.
func run_way() -> void:
	var folder: String = game._capture_dir()
	var ends: PackedStringArray = []
	var name := "way"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prowler-way="):
			ends = arg.trim_prefix("--prowler-way=").split(":")
	if ends.size() >= 3:
		name = ends[2]
	await get_tree().create_timer(1.0).timeout
	game.profile.mission = 2
	game.intro_skipped = true
	game.team_enabled = false
	game.hive.resume_at = "labs"
	game.hive.seed_wanted = -4
	game.start_run()
	await get_tree().create_timer(1.0).timeout
	var hive: HiveDirector = game.hive
	var map: HiveMap = hive.map
	game.set_process(false)
	hive.set_process(false)
	hive.set_physics_process(false)
	hive.prowl.set_process(false)
	if hive.entries != null:
		hive.entries.set_process(false)
		hive.entries.set_physics_process(false)
	for id in map.areas:
		map.unlock(id, true)
	hive._clear_enemies()
	game.hud.banner_left = 0
	game.hud.radio_left = 0
	var places := {}
	for room: Dictionary in map.rooms:
		if str(room.id) in ends:
			var outer: Rect2 = room.outer
			var middle := Vector3(outer.get_center().x, float(room.y) + 0.1, outer.get_center().y)
			var cell: Vector2i = map.nearest_cell(middle, int(room.level))
			places[str(room.id)] = Vector3(cell.x * CabinMap.CELL, map.level_height(int(room.level)), cell.y * CabinMap.CELL)
	if ends.size() < 2 or not places.has(ends[0]) or not places.has(ends[1]):
		print("PROWLER_WAY no such rooms")
		get_tree().quit()
		return
	game.player.global_position = places[ends[1]] + Vector3(0, 0.05, 0)
	var beast := Prowler.new()
	beast.game = game
	beast.kind = "prowler"
	beast.uncounted = true
	beast.position = places[ends[0]] + Vector3(0, 0.08, 0)
	game.enemies.add_child(beast)
	beast.prey = game.player
	beast.nerve = 0.0
	beast.roomy = hive.prowl.may_follow
	beast.width = hive.prowl.width_of
	beast.ground = hive.prowl.open_ground
	for shot in range(18):
		var clock := 0.0
		while clock < 0.33:
			await get_tree().physics_frame
			clock += get_physics_process_delta_time()
			map.feel(PackedVector3Array([beast.global_position, game.player.global_position]))
			game.player.health = 100.0
			beast.swap_left = 99.0
		var at := beast.global_position
		if beast.shift_phase == "away":
			# Gone: the picture shows where its prey is, where it will come again.
			at = game.player.global_position
		await game._capture_from(folder, "%s_%02d.png" % [name, shot], at - beast.facing() * 5.5 + Vector3(0, 3.6, 0), at + Vector3(0, 0.6, 0), 60)
	print("PROWLER_WAY %s from %s to %s: mode=%s shifts=%d at=%s" % [name, ends[0], ends[1], beast.mode, beast.shifts, str(beast.global_position.snapped(Vector3.ONE * 0.1))])
	print("PROWLER_CAPTURE_COMPLETE")
	get_tree().quit()
