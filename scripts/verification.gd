extends Node
## Run with Godot --headless --path <project> -- --smoke-test.
var failures := 0
var checks := 0

func expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
		print("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func face(game: Node3D, pos: Vector3, yaw: float) -> void:
	game.player.position = pos
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3(0, yaw, 0)
	game.player.camera.rotation = Vector3.ZERO

## A place to stand in front of a station: one metre from it, towards `room`.
func beside(game: Node3D, kind: String, room: Vector3, index: int = 0) -> Vector3:
	var found := 0
	for station in game.cabin.stations:
		if station.kind == kind:
			if found == index:
				var pos: Vector3 = station.pos
				return pos + pos.direction_to(Vector3(room.x, pos.y, room.z)) + Vector3(0, 0.05, 0)
			found += 1
	return Vector3.ZERO

func run(game: Node3D) -> void:
	# The operators stay out of the older checks, which count what a round brings; the block
	# that is about them lets them in.
	game.operators_enabled = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	game.set_process(false)
	# The rule checks below count exact kills and damage, so they run without the squad -
	# and against the health in Infected.TYPES, without what a level adds to it. (The checks
	# of that toughness switch it on for themselves, see _toughness.)
	game.team_enabled = false
	game.brood_on = false
	# --only=threats runs one of the later blocks on its own (handy while working on it);
	# --only=operators,sandbox runs several, one after the other.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			for block in arg.trim_prefix("--only=").split(","):
				print("BLOCK " + block)
				await call("_" + block, game)
			game.sounds.stop_all()
			await wait(0.2)
			print("INTEGRATION_RESULT: %d checks, %d failures (only %s)" % [checks, failures, arg.trim_prefix("--only=")])
			get_tree().call_deferred("quit", 0 if failures == 0 else 1)
			return
	var cabin: CabinMap = game.cabin
	expect(game.state == "menu", "Project opens on the menu")
	var spots: Dictionary = cabin.points
	var lift := Vector3(0, 0.1, 0)
	var kinds := {}
	for station in cabin.stations:
		kinds[station.kind] = int(kinds.get(station.kind, 0)) + 1
	expect(cabin.stations.size() == 7 and kinds.get("shop") == 1 and kinds.get("upgrade") == 1 and kinds.get("ammo") == 3 and kinds.get("health") == 2 and cabin.level_of(cabin.stations[6].pos) == 1, "Supply stations in the house and the outbuildings, a workbench and a weapon shop exist")
	# --- navigation
	var rooms := ["hall", "lounge", "kitchen", "dining", "supply", "stair_hall", "gallery", "upper_landing", "upper_west", "upper_east", "upper_northwest", "upper_northeast", "balcony", "barn", "garage", "guest_cabin", "shed"]
	for point in cabin.spawn_points:
		var path: PackedVector3Array = cabin.path_between(point, spots.hall)
		expect(path.size() > 2 and path[path.size() - 1].distance_to(spots.hall) < 0.4, "Spawn has a complete path into the house: " + str(point))
	for room in rooms:
		var target: Vector3 = spots[room]
		var path: PackedVector3Array = cabin.path_between(cabin.spawn_points[0], target)
		# A named place may sit next to furniture: the way ends on the nearest free spot.
		expect(path.size() > 2 and path[path.size() - 1].distance_to(target) < 0.8, "The infected can reach the " + room)
	var highest := 0.0
	for step in cabin.path_between(spots.hall, spots.upper_west):
		highest = maxf(highest, step.y)
	expect(absf(highest - CabinMap.STOREY) < 0.1 and cabin.level_of(spots.upper_west) == 1 and cabin.level_of(spots.hall) == 0, "The way to the upper floor leads over a staircase")
	expect(cabin.is_toxic(spots.gas) and not cabin.is_toxic(spots.yard_south) and not cabin.is_toxic(spots.barn) and not cabin.is_toxic(Vector3.ZERO), "Gas lies beyond the fence; the yard and the house are safe")
	# --- the infected come from the side of the yard where the survivor is
	game.player.position = (spots.barn as Vector3) + lift
	var gaps: Array = []
	for point in cabin.spawn_points:
		gaps.append(point.distance_to(spots.barn))
	gaps.sort()
	var near_only := true
	var repeated := false
	for i in range(30):
		var pick: int = game._pick_spawn()
		near_only = near_only and cabin.spawn_points[pick].distance_to(spots.barn) <= float(gaps[6]) + 0.01
		repeated = repeated or pick == game.last_spawn
		game.last_spawn = pick
	expect(near_only and not repeated, "The infected arrive through the nearer gaps in the fence, never twice through the same one")
	# --- movement
	game.start_run()
	await frames(12)
	expect(game.player.is_on_floor(), "Player stands on the floor")
	expect(game.player.health == 100 and game.player.ammo == 30, "Fresh match restores health and weapon")
	var start_z: float = game.player.position.z
	Input.action_press("move_forward")
	await frames(24)
	Input.action_release("move_forward")
	expect(game.player.position.z > start_z + 0.8, "WASD input drives the physical player controller")
	await frames(10)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(8)
	expect(game.player.position.y > 0.3, "Jump lifts the player off the floor")
	await frames(35)
	# --- every infected model is rigged and animated
	game.begin_wave()
	var expected_bones := {"mauler_hazmat": 25, "mauler_female": 68, "striker": 68, "crusher": 28, "charger": 19, "normalzombie": 22, "normalzombie2": 22, "zombiehelm": 22, "leech": 22}
	var owners := {"mauler_hazmat": "mauler", "mauler_female": "mauler", "striker": "striker", "crusher": "crusher", "charger": "charger", "normalzombie": "mauler", "normalzombie2": "mauler", "zombiehelm": "mauler", "leech": "leech"}
	for visual in expected_bones:
		var specimen: Infected = game.spawn_enemy(owners[visual], visual)
		specimen.set_physics_process(false)
		var model: InfectedVisual = specimen.model
		var rig: Dictionary = model.rig
		expect(model.skeleton.get_bone_count() == expected_bones[visual] and rig.arms.size() == 2 and rig.legs.size() == 2 and rig.spine.size() >= 2, "%s has a skeleton with detected spine, arms and legs" % visual)
		var thigh: int = rig.legs[0].thigh.index
		model.animate(0.3, 3.0)
		var before := model.skeleton.get_bone_pose_rotation(thigh)
		model.animate(0.17, 3.0)
		expect(before.angle_to(model.skeleton.get_bone_pose_rotation(thigh)) > 0.05, "%s run cycle moves real skeleton bones" % visual)
		var library: AnimationLibrary = InfectedVisual.libraries[visual]
		var wanted_clips := ["mutant_walk", "slam", "leap", "mutant_death"] if visual == "crusher" else ["run", "stumble", "death_back", "death_from_left", "kick", "swipe_left"]
		var complete := true
		for clip in wanted_clips:
			complete = complete and library.has_animation(clip)
		expect(complete and library.get_animation_list().size() >= 9, "%s carries the retargeted Mixamo clips, mirrored variants included" % visual)
		# Feet stay near the ground through the whole run cycle.
		var lowest := INF
		for step in range(12):
			model.animate(0.07, 3.0)
			for leg in rig.legs:
				lowest = minf(lowest, model.skeleton.get_bone_global_pose(leg.foot.index).origin.y)
		var rest_foot: float = model.skeleton.get_bone_global_rest(rig.legs[0].foot.index).origin.y
		expect(absf(lowest - rest_foot) < 0.08, "%s keeps its feet on the ground while running" % visual)
		specimen.queue_free()
	game.alive_count = 0
	game.boss = null
	await frames(2)
	expect(game.sounds.recorded["shot"] and game.sounds.recorded["badger"] and game.sounds.recorded["growl"] and game.sounds.recorded["rain"] and (game.sounds.clips["growl"] as Array).size() == 3, "Recorded sound effects are loaded, with variants")
	var fresh := true
	for sound in ["shotgun", "autoshotgun", "shotgun_pump", "shell_in", "dog_growl", "dog_bite", "dog_death", "gore_burst", "headpop", "bodyfall", "striker_attack", "crusher_death", "bot_hurt_male", "bot_hurt_female"]:
		fresh = fresh and bool(game.sounds.recorded.get(sound, false))
	expect(fresh, "The recordings for the shotgun, the hound, the squad and the gore are loaded")
	# --- hit reactions: flinch, stumble with knock-back, falling
	face(game, Vector3(0, 0.05, 1.0), PI)
	var lurker: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	lurker.position = Vector3(0, 0.05, 19.0)
	lurker.lurk_left = 30.0
	await wait(1.0)
	expect(not lurker.alert and lurker.position.z > 17.9 and lurker.position.z < 18.9, "A distant Mauler shambles slowly until it notices the survivor")
	lurker.receive_hit(1.0, Vector3.BACK)
	expect(lurker.alert, "A shot wakes a shambling Mauler")
	lurker.position = Vector3(0, 0.05, 7.0)
	# Moved by hand, so its old route is void.
	lurker.repath_left = 0.0
	await wait(0.6)
	var stumble_from: float = lurker.position.z
	expect(stumble_from < 6.6 and lurker.model.gait == str(lurker.model.moves.run), "An alert Mauler runs at the survivor")
	lurker.receive_hit(lurker.max_health * 0.5, Vector3.BACK)
	expect(lurker.held_left > 0.5 and lurker.model.state == "stagger" and lurker.model.flinch > 0.5, "Concentrated fire makes a Mauler stumble")
	await wait(0.8)
	expect(lurker.position.z > stumble_from + 0.2, "The stumble really knocks the body backwards")
	lurker.cooldown = 0.0
	lurker.attack_clock = 0.1
	lurker._stagger(false)
	expect(lurker.attack_clock < 0.0, "A stagger breaks off an attack")
	var lurker_model: InfectedVisual = lurker.model
	lurker.receive_hit(9999, Vector3.BACK)
	await wait(1.9)
	expect(lurker_model.dying and lurker_model.head_position().y < 0.75, "A killed Mauler falls and stays on the ground")
	# --- far from the fight the infected hurry
	var straggler: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	straggler.position = Vector3(0, 0.05, 44.0)
	straggler.receive_hit(1.0, Vector3.BACK)
	await wait(1.6)
	var hurried: float = straggler.get_real_velocity().length()
	straggler.position = Vector3(0, 0.05, 8.0)
	straggler.repath_left = 0.0
	await wait(0.6)
	expect(hurried > straggler.speed * 1.5 and straggler.get_real_velocity().length() < straggler.speed * 1.15, "An infected far from its prey hurries and slows to its own pace when it gets close")
	straggler.receive_hit(9999, Vector3.BACK)
	game.kills = 0
	game.credits = 120
	game.score = 0
	# --- shooting
	face(game, Vector3(0, 0.05, 1.0), PI)
	var enemy: Infected = game.spawn_enemy("mauler")
	enemy.set_physics_process(false)
	enemy.position = Vector3(0, 0.05, 4.0)
	await frames(3)
	game.player.shoot()
	expect(is_equal_approx(enemy.health, enemy.max_health - 28.0 * 2.7), "Real camera raycast scores a headshot with the head multiplier")
	await frames(10)
	game.player.shoot()
	expect(enemy.dead and game.kills == 1, "A second headshot kills the Mauler")
	expect(game.player.ammo == 28 and game.credits == 145 and game.score == 150, "Shots consume ammo; the kill awards supplies and score with headshot bonus")
	game.player.start_reload()
	await wait(1.9)
	expect(game.player.ammo == 30 and game.player.reserve == 178, "Reload transfers exactly the missing rounds from reserve")
	# --- walls and windows
	var blocked: Infected = game.spawn_enemy("mauler")
	blocked.set_physics_process(false)
	blocked.position = (spots.wall_out as Vector3) + Vector3(0, 0.05, 0)
	face(game, (spots.wall_in as Vector3) + Vector3(0, 0.05, 0), PI)
	await frames(3)
	game.player.shoot()
	expect(blocked.health == blocked.max_health, "The house wall blocks rifle fire")
	var health_before: float = game.player.health
	blocked.cooldown = 0
	for i in range(8):
		blocked._physics_process(0.1)
	expect(game.player.health == health_before and blocked.attack_clock < 0.0, "The house wall blocks melee attacks")
	blocked.position = (spots.window_out as Vector3) + Vector3(0, 0.05, 0)
	face(game, (spots.window_in as Vector3) + Vector3(0, 0.05, 0), PI / 2)
	await frames(12)
	game.player.shoot()
	expect(blocked.health < blocked.max_health, "Shots pass through a window opening")
	Input.action_press("move_forward")
	await frames(50)
	Input.action_release("move_forward")
	expect(game.player.position.x > -CabinMap.HX + 0.3 and game.player.position.x < float(spots.window_in.x) - 0.3, "The window sill keeps the player inside")
	blocked.receive_hit(9999, Vector3.FORWARD)
	# --- melee with a wind-up
	face(game, Vector3(0, 0.05, 3.0), PI)
	var mauler: Infected = game.spawn_enemy("mauler")
	mauler.set_physics_process(false)
	mauler.position = Vector3(0, 0.05, 3.9)
	await frames(3)
	health_before = game.player.health
	mauler.cooldown = 0
	mauler._physics_process(0.016)
	expect(mauler.attack_clock >= 0.0 and game.player.health == health_before, "A Mauler winds up before its claws land")
	for i in range(5):
		mauler._physics_process(0.1)
	expect(game.player.health == health_before - 9.0, "The Mauler's strike inflicts real melee damage")
	mauler.receive_hit(9999, Vector3.FORWARD)
	# --- Charger
	game.player.health = 100
	face(game, Vector3(0, 0.05, 1.0), PI)
	var charger: Infected = game.spawn_enemy("charger")
	charger.position = Vector3(0, 0.05, 3.0)
	var alive_before: int = game.alive_count
	var kills_before: int = game.kills
	await wait(1.0)
	expect(not is_instance_valid(charger) and game.player.health < 100 and game.alive_count == alive_before - 1 and game.kills == kills_before, "A Charger that reaches the player detonates and hurts; nobody is credited")
	expect(game.hud.splatter_left > 0.0 and game.fx.decals.size() >= 12, "A Charger bursting nearby covers the room and the screen in blood")
	game.player.health = 100
	face(game, Vector3(0, 0.05, -5.0), PI)
	var bomb: Infected = game.spawn_enemy("charger")
	bomb.set_physics_process(false)
	bomb.position = Vector3(0, 0.05, 4.5)
	var bystander: Infected = game.spawn_enemy("mauler")
	bystander.set_physics_process(false)
	bystander.position = Vector3(1.4, 0.05, 4.5)
	await frames(3)
	bomb.receive_hit(9999, Vector3.BACK)
	expect(bomb.dead and is_instance_valid(bomb), "A shot Charger swells for a moment before it bursts")
	await wait(0.5)
	expect(not is_instance_valid(bomb) and bystander.health < bystander.max_health and game.player.health == 100, "A shot Charger explodes, tears into infected nearby and spares a distant player")
	if not bystander.dead:
		bystander.receive_hit(9999, Vector3.FORWARD)
	# --- Striker
	face(game, Vector3(0, 0.05, 3.0), PI)
	var striker: Infected = game.spawn_enemy("striker")
	striker.set_physics_process(false)
	striker.position = Vector3(0, 0.05, 4.6)
	await frames(3)
	striker.receive_hit(striker.max_health * 0.6, Vector3.BACK)
	expect(game.fx.growths.size() == 1 and not striker.dead, "A wounded Striker sheds one explosive growth")
	striker.receive_hit(9999, Vector3.BACK)
	expect(game.fx.growths.size() == 4, "A killed Striker drops three more growths")
	game.player.health = 100
	# (Counted in steps of the game, as the fuses are: a busy machine must not decide this.)
	await frames(216)
	expect(game.fx.growths.is_empty() and game.player.health < 100, "The growths burst after a short fuse and injure a player who stays close")
	# --- Crusher
	game.player.health = 100
	face(game, Vector3(0, 0.05, 3.0), PI)
	# One that comes before the last round is not yet fully grown.
	var early_round: int = game.wave
	game.wave = 6
	var young: Infected = game.spawn_enemy("crusher")
	young.set_physics_process(false)
	game.wave = game.ROUNDS.size()
	var crusher: Infected = game.spawn_enemy("crusher")
	game.wave = early_round
	crusher.set_physics_process(false)
	crusher.position = Vector3(0, 0.05, 5.2)
	expect(game.boss == crusher and crusher.max_health >= 2000 and young.max_health < crusher.max_health * 0.6 and int(game.ROUNDS[5].get("crusher", 0)) == 1, "The Crusher is tracked as the boss with a deep health pool; an early one is weaker")
	young._retire()
	young.queue_free()
	game.alive_count -= 1
	expect(crusher.is_headshot(crusher.global_position + Vector3(0, 2.3, 0)) and not crusher.is_headshot(crusher.global_position + Vector3(0, 1.7, 0)), "The Crusher's head sits above a normal survivor")
	crusher.set_physics_process(true)
	await frames(6)
	expect(crusher.head_box.global_position.y > 2.1, "The Crusher's head hit zone follows its skull above the body capsule")
	crusher.set_physics_process(false)
	face(game, Vector3(0, 0.05, 3.0), PI)
	game.player.camera.look_at(crusher.head_box.global_position)
	var crusher_health: float = crusher.health
	await frames(8)
	game.player.shoot()
	expect(is_equal_approx(crusher.health, crusher_health - 28.0 * maxf(1.0, 2.7 * 0.55)), "A shot at the Crusher's head counts as a resisted headshot")
	crusher.receive_hit(crusher.max_health * 0.52, Vector3.BACK)
	expect(crusher.enraged and not crusher.dead, "A Crusher that has lost half its health goes berserk")
	crusher.receive_hit(99999, Vector3.BACK)
	expect(crusher.dead and game.boss == null and game.fx.clouds.size() == 1, "A dead Crusher leaves an acid cloud")
	await wait(1.2)
	expect(game.fx.in_acid(game.player.global_position) and game.player.health < 100, "Standing in the acid cloud burns the player")
	# --- stations
	game.start_run()
	game.player.position = beside(game, "ammo", spots.supply)
	game.credits = 60
	game.player.reserve = 0
	game.interact()
	expect(game.player.reserve == 180 and game.credits == 0, "Ammo station refills reserve and charges 60")
	game.player.ammo = 0
	game.player.reserve = 0
	game.interact()
	expect(game.player.reserve == 30 and game.credits == 0, "Emergency reserve prevents an ammunition softlock")
	game.player.position = beside(game, "health", spots.supply)
	game.credits = 100
	game.player.health = 20
	game.interact()
	expect(game.player.health == 70 and game.credits == 0, "Medical station heals 50 and charges 100")
	game.player.position = beside(game, "upgrade", spots.garage)
	game.credits = 1000
	game.interact()
	var at_bench: bool = game.state == "bench" and game.hud.current_menu == "bench"
	for i in range(4): game.buy_upgrade("damage")
	game.resume_run()
	expect(at_bench and game.state == "playing" and game.player.weapon_level == 3 and game.credits == 250, "The workbench opens its menu; its damage line caps at level three without overcharging")
	game.player.position = Vector3(11.5, 0.05, -6.0)
	expect(game.closest_station().kind == "health", "Between two stations the nearer one answers")
	game.player.position = beside(game, "ammo", spots.barn, 1)
	game.credits = 60
	game.player.reserve = 0
	game.interact()
	expect(game.player.reserve == 180 and game.credits == 0, "The barn has a second ammunition station")
	game.player.position = Vector3(0, CabinMap.STOREY + 0.05, -2.2)
	expect(game.closest_station().is_empty(), "A station cannot be used through the floor from the storey above")
	# --- gas
	game.player.position = (spots.gas as Vector3) + lift
	game.player.health = 100
	game.player._update_mist(3.1)
	expect(game.player.health == 94, "Toxic gas damages a player who stays beyond the fence")
	game.player.position = Vector3(0, 0.1, 0)
	game.player._update_mist(0.1)
	expect(game.player.mist_exposure == 0, "Returning to the yard stops the gas exposure")
	# --- pause
	game.pause_run()
	var seconds: float = game.elapsed
	await get_tree().process_frame
	expect(get_tree().paused and not game.player.controlled and game.elapsed == seconds, "Pause freezes gameplay and releases control")
	game.resume_run()
	expect(not get_tree().paused and game.player.controlled, "Resume restores control and simulation")
	game.return_to_menu()
	game.start_run()
	# --- the infected physically walk in through the entrances
	game.begin_wave()
	for entrance in [["front_door", "hall", "the front door"], ["breach", "kitchen", "the breach in the kitchen wall"], ["back_door", "stair_hall", "the back door"], ["side_door", "lounge", "the side door"]]:
		var outside: Vector3 = spots[entrance[0] + "_out"]
		var inside: Vector3 = spots[entrance[0] + "_in"]
		var walker: Infected = game.spawn_enemy("mauler")
		walker.position = outside + lift
		game.player.position = (spots[entrance[1]] as Vector3) + lift
		game.player.health = 100
		await wait(3.2)
		expect(walker.position.distance_to(inside) < walker.position.distance_to(outside) - 1.0, "A Mauler walks in through " + entrance[2] + " using navigation and collision")
		walker.receive_hit(9999, Vector3.FORWARD)
	# --- both staircases carry the infected up, and the survivor too
	for way in [["stairs", "upper_landing", "the staircase in the house"], ["outer_stairs", "balcony", "the outer stairs to the balcony"]]:
		var climber: Infected = game.spawn_enemy("mauler")
		climber.position = (spots[way[0] + "_bottom"] as Vector3) + lift
		game.player.position = (spots[way[1]] as Vector3) + lift
		game.player.health = 100
		climber.receive_hit(1.0, Vector3.BACK)
		await wait(6.0)
		expect(climber.position.y > CabinMap.STOREY - 0.3 and climber.position.distance_to(game.player.position) < 4.0, "A Mauler climbs " + way[2] + " to reach a survivor upstairs")
		climber.receive_hit(9999, Vector3.FORWARD)
	game.player.health = 100
	face(game, (spots.stairs_bottom as Vector3) + lift, PI / 2)
	Input.action_press("move_forward")
	await frames(150)
	Input.action_release("move_forward")
	expect(game.player.position.y > CabinMap.STOREY - 0.2 and game.player.is_on_floor(), "The survivor walks up the stairs to the upper floor")
	face(game, (spots.gallery as Vector3) + lift, PI)
	await frames(20)
	expect(game.player.is_on_floor() and absf(game.player.position.y - CabinMap.STOREY) < 0.15 and cabin.is_indoors(game.player.position), "The gallery above the hall carries the survivor")
	# --- all ten rounds
	game.return_to_menu()
	game.start_run()
	var total := 0
	game.mission.plain()
	for round_index in range(game.ROUNDS.size()):
		game.begin_wave()
		var count: int = game.remaining_to_spawn
		var roster: Dictionary = game.ROUNDS[round_index]
		var planned := 0
		for kind in roster:
			# The last round brings a share of its table only; the Crusher comes whole.
			var share := float(game.FINAL_SHARE) if round_index == game.ROUNDS.size() - 1 and kind != "crusher" else 1.0
			planned += maxi(1, int(round(int(roster[kind]) * share)))
		expect(count == planned, "Round %d has the specified population of %d" % [round_index + 1, planned])
		if round_index == 4:
			expect("striker" in game.spawn_queue, "Strikers join in round five")
		if round_index == game.ROUNDS.size() - 1:
			expect("crusher" in game.spawn_queue, "The Crusher arrives in the final round")
		total += count
		for i in range(count):
			var target: Infected = game.spawn_enemy()
			target.receive_hit(99999, Vector3.FORWARD)
		expect(game.alive_count == 0 and game.remaining_to_spawn == 0, "Round %d can be cleared" % (round_index + 1))
		game.complete_wave()
		if round_index < game.ROUNDS.size() - 1:
			expect(game.phase == "preparing", "A cleared round opens a resupply interval")
	expect(game.state == "win" and game.kills == total, "All ten rounds end in victory with %d kills" % total)
	game.start_run()
	await frames(4)
	expect(game.kills == 0 and game.score == 0 and game.enemies.get_child_count() == 0 and game.player.weapon_level == 0 and game.fx.growths.is_empty(), "Restart clears enemies, hazards, score and upgrades")
	# --- weapon shop: open between rounds, shuttered during them
	expect(cabin.shop_open and game.phase == "preparing", "The weapon shop is open before the first round")
	expect(not game.player.equip_weapon("p90") and game.player.current_weapon == "rifle", "P90 cannot be equipped before purchase")
	game.player.ammo = 7
	game.player.reserve = 17
	game.player.weapon_level = 2
	game.player.position = (spots.shop as Vector3) + lift
	game.credits = 99
	# Three slings: what is bought below is carried beside the carbine, not instead of it.
	game.player.extra_slots = 3
	game.interact()
	expect(game.state == "shop" and get_tree().paused, "E at the open weapon shop opens its menu and pauses combat")
	expect(not game.buy_weapon("p90") and game.credits == 99, "Insufficient funds cannot buy the P90")
	game.credits = 120
	expect(game.buy_weapon("p90") and game.credits == 20, "P90 purchase deducts exactly 100 supplies")
	expect(game.player.current_weapon == "p90" and game.player.ammo == 50 and game.player.reserve == 250, "Purchased P90 is equipped with its own 50-round magazine")
	expect(not game.buy_weapon("p90") and game.credits == 20, "Repeated purchase never charges again")
	game.credits = 349
	expect(not game.buy_weapon("badger") and not game.player.inventory.has("badger"), "The Honey Badger costs more than 349 supplies")
	game.credits = 350
	expect(game.buy_weapon("badger") and game.credits == 0 and game.player.current_weapon == "badger" and game.player.ammo == 30 and game.player.reserve == 210, "Honey Badger purchase deducts 350 and equips it fully loaded")
	game.resume_run()
	game.player.equip_weapon("rifle")
	expect(game.player.ammo == 7 and game.player.reserve == 17 and game.player.weapon_level == 2, "Switching restores the rifle's separate ammo and upgrade")
	game.player._select_slot(1)
	game.player._select_slot(1)
	expect(game.player.current_weapon == "badger", "Key 1 takes the primary weapons in turn: after the P90 the Honey Badger")
	game.player._cycle(1)
	expect(game.player.current_weapon == "rifle", "The mouse wheel cycles through owned weapons")
	game.player._select_slot(2)
	var no_sidearm: bool = game.player.current_weapon == "rifle"
	game.player._select_slot(1)
	expect(no_sidearm and game.player.current_weapon == "p90" and game.player.weapon_level == 0, "P90 has its own upgrade level")
	face(game, Vector3(0, 0.05, 1.0), PI)
	game.begin_wave()
	expect(not cabin.shop_open, "The shop shutter comes down when a round begins")
	game.player.position = (spots.shop as Vector3) + lift
	game.interact()
	expect(game.state == "playing" and "geschlossen" in game.interaction_prompt(), "A closed shop cannot be opened during a round")
	face(game, Vector3(0, 0.05, 1.0), PI)
	var p90_target: Infected = game.spawn_enemy("mauler")
	p90_target.set_physics_process(false)
	p90_target.position = Vector3(0, 0.05, 4.0)
	await frames(20)
	game.player.shoot()
	expect(is_equal_approx(p90_target.health, p90_target.max_health - 23.0 * 3.0) and game.player.ammo == 49, "P90 fires a real damaging shot and consumes its own ammo")
	game.player.equip_weapon("badger")
	p90_target.health = p90_target.max_health
	await frames(20)
	game.player.shoot()
	expect(is_equal_approx(p90_target.health, p90_target.max_health - 34.0 * 2.6) and game.player.ammo == 29, "The suppressed Honey Badger hits harder than the other weapons")
	game.player.equip_weapon("p90")
	game.player.ammo = 1
	game.player.reserve = 2
	game.player.start_reload()
	await wait(2.3)
	expect(game.player.ammo == 3 and game.player.reserve == 0 and game.player.reload_cue == 3, "P90 reload plays its three steps and cannot create ammunition")
	game.player.ammo = 10
	game.player.reserve = 20
	game.player.start_reload()
	game.player.equip_weapon("rifle")
	game.player.equip_weapon("p90")
	expect(game.player.reload_left == 0 and game.player.ammo == 10 and game.player.reserve == 20, "Switching during reload cancels it without transferring rounds")
	game.player.position = beside(game, "ammo", spots.supply)
	game.credits = 60
	game.interact()
	expect(game.player.reserve == 250 and game.credits == 0, "Ammo station uses the equipped P90's reserve capacity")
	game.spawn_queue.clear()
	p90_target.receive_hit(9999, Vector3.FORWARD)
	game.complete_wave()
	expect(cabin.shop_open and game.phase == "preparing", "The shop reopens as soon as the round is survived")
	game.start_run()
	expect(not game.player.inventory.has("p90") and game.player.current_weapon == "rifle", "Restart resets purchased weapons cleanly")
	# --- gear from the shop
	game.start_run()
	game.credits = 2000
	game.player.position = (spots.shop as Vector3) + lift
	game.interact()
	expect(game.item_price("grenade") == 60 and game.buy_item("grenade") and game.buy_item("grenade") and game.player.items.grenade == 2 and game.credits == 1880, "Grenades are bought one at a time")
	for i in range(4):
		game.buy_item("grenade")
	expect(game.player.items.grenade == 4 and game.item_price("grenade") == -1 and game.credits == 1760, "The pockets hold four grenades and no more")
	expect(game.buy_item("vest") and game.player.armor == 50.0 and game.buy_item("armor") and game.player.armor == 100.0 and not game.buy_item("vest") and game.credits == 1310, "A vest gives 50 armour, heavy armour 100")
	expect(game.buy_item("mask") and game.buy_item("mask") and game.player.mask_level == 2 and game.item_price("mask") == 400 and game.credits == 910, "The gas mask is bought level by level")
	# The bigger magazine is the workbench's now: bought there, for the weapon in hand.
	var counter_place: Vector3 = game.player.position
	game.player.position = beside(game, "upgrade", spots.garage)
	var roomy: bool = not game.buy_item("mags") and game.buy_upgrade("mags") and game.player.magazine_size() == 45 and game.player.ammo == 45 and not game.buy_upgrade("mags") and game.credits == 710
	game.player.position = counter_place
	expect(roomy, "A bigger magazine from the workbench holds half as much again")
	expect(game.buy_item("flashbang") and game.buy_item("claymore") and game.buy_item("revive") and not game.buy_item("revive") and game.credits == 275, "Flashbangs, mines and one adrenaline shot are on sale too")
	game.resume_run()
	game.player.receive_damage(20.0, Vector3(0, 0, 5))
	expect(game.player.health == 92.0 and game.player.armor == 88.0, "Armour takes 60 % of a hit")
	# Grenade: the blast, and the throw itself.
	face(game, Vector3(0, 0.05, 0.0), PI)
	var pack: Array[Infected] = []
	for i in range(3):
		var victim: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
		victim.set_physics_process(false)
		victim.position = Vector3(-1.0 + i, 0.05, 7.5)
		pack.append(victim)
	await frames(3)
	var health_then: float = game.player.health
	game.blast(Vector3(0, 0.3, 7.5), Throwable.BLAST[0], Throwable.BLAST[1], Throwable.BLAST[2])
	expect(pack[0].dead and pack[1].dead and pack[2].dead and game.player.health == health_then, "A grenade blast kills the pack around it and spares who keeps away")
	game.player.throw("grenade")
	expect(game.player.items.grenade == 3 and game.ordnance.get_child_count() == 1, "G throws a grenade")
	game.player.throw("grenade")
	expect(game.player.items.grenade == 3, "A second throw has to wait a moment")
	await wait(2.9)
	expect(game.ordnance.get_child_count() == 0, "The grenade goes off when its fuse has burnt down")
	# Flashbang: stuns what can see it.
	var dazed: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	dazed.set_physics_process(false)
	dazed.position = Vector3(1.0, 0.05, 6.0)
	var shielded: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	shielded.set_physics_process(false)
	shielded.position = (spots.wall_out as Vector3) + Vector3(0, 0.05, 0)
	await frames(3)
	game.flash_bang((spots.wall_in as Vector3) + Vector3(0, 1.0, 0))
	var behind_wall: float = shielded.held_left
	game.flash_bang(Vector3(0, 1.0, 3.0))
	expect(dazed.held_left > 3.5 and behind_wall == 0.0, "A flashbang stuns the infected that can see it, not those behind a wall")
	dazed.receive_hit(9999, Vector3.BACK)
	shielded.receive_hit(9999, Vector3.BACK)
	# Claymore.
	face(game, Vector3(0, 0.05, 1.0), PI)
	await frames(4)
	game.player.throw_cooldown = 0.0
	game.player.place_claymore()
	expect(game.player.items.claymore == 0 and game.ordnance.get_child_count() == 1, "B sets a mine down in front of the survivor")
	var walker_in: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	walker_in.position = Vector3(0, 0.05, 8.0)
	walker_in.receive_hit(1.0, Vector3.BACK)
	var tripped := false
	for i in range(360):
		await get_tree().physics_frame
		if game.ordnance.get_child_count() == 0:
			tripped = true
			break
	expect(tripped and walker_in.dead, "The mine goes off when an infected walks in front of it")
	# Adrenaline.
	game.player.health = 30
	game.player.armor = 0.0
	game.player.receive_damage(500.0)
	expect(game.player.health == 50.0 and not game.player.down and game.state == "playing" and game.player.items.revive == 0, "The adrenaline shot saves the survivor once")
	# Gas mask and drifting gas.
	game.player.health = 100
	game.player.position = (spots.gas as Vector3) + lift
	game.player._update_mist(5.0)
	expect(game.player.filter_left == 15.0 and game.player.mist_exposure == 0.0 and game.player.health == 100.0, "A gas mask keeps the air clean while its filter lasts")
	game.player._update_mist(16.0)
	game.player._update_mist(3.1)
	expect(game.player.filter_left == 0.0 and game.player.health == 94.0, "With the filter used up the gas hurts again")
	game.player.position = Vector3(0, 0.1, 0)
	game.player._update_mist(10.0)
	expect(is_equal_approx(game.player.filter_left, 6.0), "In clean air the filter recovers")
	cabin.set_gas("north")
	expect(cabin.is_toxic(spots.yard_north) and not cabin.is_toxic(spots.barn) and not cabin.is_toxic(spots.yard_south) and not cabin.is_toxic(spots.stair_hall), "Drifting gas covers one side of the yard; buildings stay safe")
	cabin.set_gas("")
	expect(not cabin.is_toxic(spots.yard_north), "The gas clears again")
	game.mission.plan[0] = {"wave": "classic", "tasks": [], "gas": "east"}
	game.begin_wave()
	var drifted: String = cabin.gas_zone
	game.spawn_queue.clear()
	game.complete_wave()
	expect(drifted == "east" and cabin.gas_zone == "" and cabin.gas_cloud != null and not cabin.gas_cloud.visible, "A round can bring gas, and it is gone when the round is over")
	# --- missions: round kinds and tasks
	game.start_run()
	var mission: MissionDirector = game.mission
	var plain: bool = mission.plan.size() == game.ROUNDS.size()
	for index in [0, 1, game.ROUNDS.size() - 1]:
		plain = plain and mission.plan[index].wave == "classic" and (mission.plan[index].tasks as Array).is_empty()
	expect(plain, "The night is planned in advance; the first two rounds and the last stay plain")
	mission.plan[0] = {"wave": "horde", "tasks": ["codes"]}
	game.begin_wave()
	expect(mission.wave_kind == "horde" and game.remaining_to_spawn == 11 + 1, "A horde round brings far more Maulers")
	game.spawn_queue.clear()
	var codes: Dictionary = mission.tasks[0]
	var outside := true
	for item in codes.items:
		var place: Vector3 = item.pos
		outside = outside and not (absf(place.x) < CabinMap.HX and absf(place.z) < CabinMap.HZ) and not cabin.is_toxic(place) and cabin.path_between(spots.hall, place).size() > 2
	expect(mission.tasks.size() == 1 and codes.items.size() == 2 and outside and not mission.round_clear() and mission.markers().size() == 2, "Dead Helix researchers lie somewhere on the farm, within reach")
	mission.update(0.1)
	expect(mission.props.size() == 2 and "Zugangscodes bergen  0/2" in mission.summary()[0], "A task shows in the world and on the HUD")
	mission.trickle_left = 0.0
	game.alive_count = 0
	mission.update(0.1)
	expect(game.remaining_to_spawn == 1, "While a task is open, more infected keep coming")
	game.spawn_queue.clear()
	var supplies_before: int = game.credits
	game.player.position = (codes.items[0].pos as Vector3) + Vector3(0.8, 0.1, 0)
	expect("Zugangscode bergen" in game.interaction_prompt(), "Near a task item the prompt says what to do")
	Input.action_press("interact")
	for index in range(2):
		game.player.position = (codes.items[index].pos as Vector3) + Vector3(0.8, 0.1, 0)
		for step in range(4):
			mission.update(0.4)
	Input.action_release("interact")
	expect(codes.state == "done" and mission.round_clear() and game.credits == supplies_before + 150 and game.stats.objectives == 1 and mission.markers().is_empty(), "Holding E at each body recovers the codes; the task pays out")
	# Generator: start it, the infected attack it, it stalls and is restarted.
	game.complete_wave()
	mission.plan[1] = {"wave": "classic", "tasks": ["generator"]}
	game.begin_wave()
	game.spawn_queue.clear()
	var defence: Dictionary = mission.tasks[0]
	var machine: Dictionary = defence.items[0]
	mission.update(0.1)
	var dummy: Node3D = mission.targets.values()[0]
	expect(game.survivors.size() == 2 and not dummy.is_targetable() and "starten" in mission.summary()[0], "A generator waits in the yard to be started")
	game.player.position = (machine.pos as Vector3) + Vector3(1.5, 0.1, 0)
	Input.action_press("interact")
	for step in range(5):
		mission.update(0.4)
	Input.action_release("interact")
	expect(machine.state == "running" and defence.left == MissionDirector.GENERATOR_SECONDS and dummy.is_targetable(), "Holding E starts the generator and its clock")
	game.player.position = (spots.hall as Vector3) + lift
	var raider: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	raider.position = (machine.pos as Vector3) + Vector3(2.4, 0.05, 0.4)
	await wait(3.2)
	expect(float(machine.health) < MissionDirector.GENERATOR_HEALTH and raider.prey == dummy, "The infected go for a running generator and beat on it")
	raider.receive_hit(9999, Vector3.BACK)
	mission.damage_item(machine, 9999.0)
	mission.update(1.0)
	expect(machine.state == "stalled" and defence.left == MissionDirector.GENERATOR_SECONDS and "AUSGEFALLEN" in mission.summary()[0] and not dummy.is_targetable(), "A wrecked generator stalls and its clock stops")
	game.player.position = (machine.pos as Vector3) + Vector3(1.5, 0.1, 0)
	expect("neu starten" in game.interaction_prompt(), "A stalled generator can be restarted")
	Input.action_press("interact")
	for step in range(5):
		mission.update(0.4)
	Input.action_release("interact")
	defence.left = 0.5
	mission.update(1.0)
	expect(machine.state == "done" and defence.state == "done" and game.stats.objectives == 2 and mission.round_clear(), "A generator that has run its time completes the task")
	# Blackout in a mutant round.
	game.complete_wave()
	mission.plan[2] = {"wave": "elite", "tasks": ["power"]}
	game.begin_wave()
	expect(mission.wave_kind == "elite" and game.remaining_to_spawn == 5 + 3 + 3, "A mutant round brings few infected, most of them special")
	game.spawn_queue.clear()
	# The lamps follow on the next drawn frame.
	await wait(0.2)
	var dark := not cabin.powered
	for entry in cabin.flickers:
		if entry.wired:
			dark = dark and (entry.light as Light3D).light_energy == 0.0
	expect(dark and mission.tasks[0].items.size() == 3, "A blackout takes every wired lamp on the farm")
	Input.action_press("interact")
	for breaker in mission.tasks[0].items:
		game.player.position = (breaker.pos as Vector3) + Vector3(0.8, 0.1, 0)
		for step in range(3):
			mission.update(0.4)
	Input.action_release("interact")
	await wait(0.2)
	expect(cabin.powered and mission.tasks[0].state == "done" and game.stats.objectives == 3, "Resetting all three breakers brings the light back")
	# Supply crate, and a second task that runs out of time.
	game.complete_wave()
	mission.plan[3] = {"wave": "classic", "tasks": ["crate", "codes"]}
	game.begin_wave()
	game.spawn_queue.clear()
	var copy := MissionDirector.new()
	copy.game = game
	copy.adopt(mission.export_state())
	expect(copy.tasks.size() == 2 and copy.tasks[0].kind == "crate" and copy.tasks[1].items.size() == 2 and (copy.tasks[1].items[1].pos as Vector3) == (mission.tasks[1].items[1].pos as Vector3), "The tasks reach a co-op guest as the host has them")
	copy.free()
	game.player.position = (mission.tasks[0].items[0].pos as Vector3) + Vector3(1.4, 0.1, 0)
	Input.action_press("interact")
	for step in range(6):
		mission.update(0.4)
	Input.action_release("interact")
	expect(mission.tasks[0].state == "done" and game.pickups.get_child_count() >= 3 and game.stats.objectives == 4, "Opening the supply crate spills ammunition and a dressing")
	mission.tasks[1].left = 0.3
	mission.update(0.5)
	expect(mission.tasks[1].state == "failed" and mission.round_clear() and game.stats.objectives == 4, "A task that runs out of time is lost, and the round can end")
	game.start_run()
	expect(game.mission.tasks.is_empty() and game.mission.props.is_empty() and game.survivors.size() == 1 and cabin.powered, "A new night clears every task away")
	# --- the Leech
	face(game, Vector3(0, 0.05, 1.0), PI)
	var leech: Infected = game.spawn_enemy("leech")
	leech.position = Vector3(0, 0.05, 4.0)
	var clung := false
	for i in range(180):
		await get_tree().physics_frame
		if game.player.clung_by == leech:
			clung = true
			break
	expect(clung and leech.clung_to == game.player and leech.global_position.distance_to(game.player.global_position) < 1.0, "A Leech jumps on the survivor and holds on")
	var health_clung: float = game.player.health
	var from_z: float = game.player.position.z
	Input.action_press("move_forward")
	await frames(45)
	Input.action_release("move_forward")
	var dragged: float = game.player.position.z - from_z
	expect(game.player.health < health_clung and dragged > 0.6 and dragged < 2.3 and "abschütteln" in game.interaction_prompt(), "It gnaws at the survivor, who can still move, but slowly (%.1f m)" % dragged)
	for press in range(7):
		game.interact()
	expect(game.player.clung_by == null and leech.clung_to == null and leech.health == leech.max_health - 15.0 and leech.held_left > 0.5, "Hammering E shakes the Leech off, hurt and dazed")
	leech.cling_cooldown = 0.0
	leech.held_left = 0.0
	clung = false
	for i in range(240):
		await get_tree().physics_frame
		if game.player.clung_by == leech:
			clung = true
			break
	leech.receive_hit(9999, Vector3.BACK)
	expect(clung and leech.dead and game.player.clung_by == null, "A Leech that is shot lets go")
	game.player.health = 100
	# --- the Stalker
	mission = game.mission
	game.begin_wave()
	game.spawn_queue.clear()
	face(game, Vector3(0, 0.05, 16.0), PI)
	await frames(3)
	var watcher: Infected = mission.stage_sighting("watch")
	expect(watcher != null and watcher.kind == "stalker" and watcher.haunt == "watch" and game.alive_count == 0 and watcher.global_position.distance_to(game.player.global_position) > 14.0, "The Stalker appears in the distance and is no part of the round")
	var stood: Vector3 = watcher.global_position
	game.player.rotation.y += PI
	await wait(0.6)
	expect(is_instance_valid(watcher) and not watcher.dead and watcher.global_position.distance_to(stood) < 0.3 and game.player.health == 100.0, "It only stands and watches")
	game.player.look_at(Vector3(stood.x, game.player.global_position.y, stood.z))
	await wait(1.3)
	expect(not is_instance_valid(watcher) or watcher.dead, "Looked at for a moment, it is gone")
	await frames(10)
	var shot_at: Infected = game.spawn_stalker(Vector3(0, 0, 34.0), "watch", game.player)
	var supplies_then: int = game.credits
	var kills_then: int = game.kills
	shot_at.receive_hit(50.0, Vector3.BACK)
	expect(shot_at.dead and game.credits == supplies_then and game.kills == kills_then and mission.stalker_health == 900.0, "Shot while it watches, it vanishes unharmed and nobody is paid")
	await frames(10)
	# Creeping up: it moves while nobody looks and stands still while it is watched.
	face(game, Vector3(0, 0.05, 16.0), 0.0)
	var hunter: Infected = game.spawn_stalker(Vector3(0, 0, 34.0), "hunt", game.player)
	await wait(1.5)
	var crept: float = 34.0 - hunter.global_position.z
	game.player.rotation.y = PI
	await wait(0.4)
	var frozen_at: Vector3 = hunter.global_position
	await wait(1.0)
	expect(crept > 6.0 and hunter.global_position.distance_to(frozen_at) < 0.3, "A hunting Stalker creeps up unseen and freezes when it is looked at (%.1f m)" % crept)
	game.player.rotation.y = 0.0
	var grabbed := false
	for i in range(420):
		await get_tree().physics_frame
		if game.player.health < 100.0:
			grabbed = true
			break
	await wait(1.2)
	expect(grabbed and game.player.health == 70.0 and (not is_instance_valid(hunter) or hunter.dead), "It gets its prey by the throat and is gone again")
	game.player.health = 100
	await frames(10)
	var driven_off: Infected = game.spawn_stalker(Vector3(0, 0, 34.0), "hunt", game.player)
	driven_off.receive_hit(230.0, Vector3.BACK)
	await frames(10)
	var returned: Infected = game.spawn_stalker(Vector3(0, 0, 34.0), "hunt", game.player)
	expect(driven_off.dead and mission.stalker_health == 670.0 and returned.health == 670.0 and not mission.stalker_dead, "Enough fire drives it off, and it comes back wounded")
	returned.vanish()
	await frames(10)
	# Sprinting through the view.
	var runner: Infected = game.spawn_stalker(Vector3(-8.0, 0, 24.0), "dash", game.player)
	runner.dash_to = Vector3(8.0, 0, 24.0)
	await wait(0.6)
	var sprinted: float = runner.global_position.x + 8.0 if is_instance_valid(runner) else 0.0
	await wait(2.5)
	expect(sprinted > 3.5 and (not is_instance_valid(runner) or runner.dead), "It sprints across the view and vanishes (%.1f m in 0.6 s)" % sprinted)
	await frames(10)
	# The rare scare at the shop counter.
	face(game, (spots.shop as Vector3) + lift, 0.0)
	var scare: Infected = mission.shop_scare(true)
	expect(scare != null and game.player.health == 90.0 and scare.global_position.distance_to(game.player.global_position) < 1.2 and mission.scare_done, "Very rarely the Stalker stands right in front of whoever leaves the shop")
	await wait(1.2)
	expect(not is_instance_valid(scare) or scare.dead, "After the scare it is gone")
	await frames(10)
	var last_visit: Infected = game.spawn_stalker(Vector3(0, 0.0, 6.0), "hunt", game.player)
	supplies_then = game.credits
	last_visit.receive_hit(9999.0, Vector3.BACK)
	expect(mission.stalker_dead and game.credits == supplies_then + 500 and mission.stage_sighting("watch") == null and mission.shop_scare(true) == null, "Killed for good, the Stalker does not come back that night")
	game.start_run()
	# --- difficulty: more than tougher skin
	expect(game.rules.label == "NORMAL" and game.price(60) == 60 and not game.profile.stored, "Checks run on normal difficulty and leave the saved profile alone")
	game.profile.difficulty = "hard"
	game.start_run()
	expect(game.rules.label == "SCHWER" and game.price(60) == 70 and game.price(250) == 300 and (cabin.stations[0].label as Label3D).text.ends_with("70 VORRAT"), "A harder night raises the prices, on the signs too")
	game.begin_wave()
	expect(game.remaining_to_spawn == 9 + 2, "A harder night brings more infected, above all special ones")
	game.spawn_queue.clear()
	face(game, Vector3(0, 0.05, 1.0), PI)
	var tough: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	tough.set_physics_process(false)
	tough.position = Vector3(0, 0.05, 4.0)
	expect(tough.max_health == 95.0, "A harder night does not make the infected bullet sponges")
	await frames(3)
	game.player.shoot()
	await frames(10)
	game.player.shoot()
	expect(tough.dead and game.score == 225 and game.stats.kills == 1 and game.stats.special_kills == 0, "A harder night multiplies the score")
	game.player.position = beside(game, "health", spots.supply)
	game.credits = 200
	game.player.health = 20
	game.interact()
	expect(game.player.health == 60 and game.credits == 80, "On hard, first aid costs 120 and restores 40")
	game.player.position = (spots.gas as Vector3) + lift
	game.player._update_mist(2.5)
	expect(is_equal_approx(game.player.health, 60.0 - 9.6), "On hard, the gas bites sooner and deeper")
	game.player.position = Vector3(0, 0.1, 0)
	game.player._update_mist(0.1)
	game.profile.difficulty = "easy"
	game.start_run()
	game.begin_wave()
	expect(game.rules.label == "LEICHT" and game.remaining_to_spawn == 6 + 1 and game.price(100) == 85, "An easy night is smaller and cheaper")
	game.profile.difficulty = "normal"
	game.start_run()
	# --- leaderboard
	var board := Profile.new()
	board.stored = false
	var first: int = board.record("normal", {"score": 500, "round": 3, "seconds": 200, "victory": false, "kills": 20})
	var second: int = board.record("normal", {"score": 900, "round": 10, "seconds": 700, "victory": true, "kills": 250, "revives": 2})
	var third: int = board.record("normal", {"score": 700, "round": 6, "seconds": 400, "victory": false, "kills": 90})
	expect(first == 1 and second == 1 and third == 2 and board.best("normal").size() == 3 and int(board.best("normal")[0].score) == 900 and int(board.best("normal")[2].score) == 500, "Finished runs are ranked by score")
	expect(board.totals.missions == 3 and board.totals.victories == 1 and board.totals.kills == 360 and board.totals.revives == 2, "The career totals add up over all runs")
	for i in range(12):
		board.record("hard", {"score": i * 10, "round": 1, "seconds": 60, "victory": false, "kills": i})
	expect(board.best("hard").size() == Profile.KEEP and int(board.best("hard")[0].score) == 110 and board.record("hard", {"score": 1, "round": 1, "seconds": 60, "victory": false, "kills": 0}) == 0 and board.best("easy").is_empty(), "Each difficulty keeps its own ten best runs")
	game.finish(false)
	expect(game.state == "lose" and game.last_place >= 1 and game.profile.best("normal").size() >= 2, "A finished night is filed on the leaderboard of its difficulty")
	game.start_run()
	# --- shotgun
	game.credits = 250
	game.player.extra_slots = 1
	game.player.position = (spots.shop as Vector3) + lift
	game.interact()
	expect(game.buy_weapon("shotgun") and game.credits == 0 and game.player.current_weapon == "shotgun" and game.player.ammo == 6 and game.player.reserve == 42, "Shotgun purchase deducts 250 and equips it with six shells")
	game.resume_run()
	game.player._select_slot(1)
	var other: String = game.player.current_weapon
	game.player._select_slot(1)
	game.player._select_slot(4)
	expect(other == "rifle" and game.player.current_weapon == "shotgun", "Key 1 takes the carbine and the shotgun in turn; key 4 is no weapon's any more")
	face(game, Vector3(0, 0.05, 1.0), PI)
	var close_target: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	close_target.set_physics_process(false)
	close_target.position = Vector3(0, 0.05, 4.0)
	var far_target: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	far_target.set_physics_process(false)
	far_target.position = Vector3(0, 0.05, 27.0)
	# Enough health to take the shot in the head and still stand.
	far_target.max_health = 400.0
	far_target.health = 400.0
	await frames(20)
	var pitch_before: float = game.player.camera.rotation.x
	game.player.shoot()
	expect(close_target.dead and game.player.ammo == 5, "One shotgun blast at close range kills a Mauler")
	expect(game.player.camera.rotation.x > pitch_before + 0.04 and game.player.pump_clock >= 0.0 and game.player.trauma > 0.2, "The blast kicks the view and the pump has to be worked")
	game.player.shoot()
	expect(game.player.ammo == 5, "The shotgun cannot fire again before the pump stroke is done")
	await wait(1.1)
	face(game, Vector3(0, 0.05, 1.0), PI)
	await frames(3)
	game.player.shoot()
	var far_loss: float = far_target.max_health - far_target.health
	expect(not far_target.dead and far_loss > 0.0 and far_loss < 9 * float(Survivor.WEAPONS.shotgun.damage) * 1.5 * 0.4, "At long range the shot has lost most of its force")
	far_target.receive_hit(9999, Vector3.BACK)
	await wait(1.1)
	game.player.ammo = 2
	var shells_before: int = game.player.reserve
	game.player.start_reload()
	await wait(1.0)
	expect(game.player.ammo == 3 and game.player.loading_shells, "Shells go into the tube one at a time")
	await wait(2.2)
	expect(game.player.ammo == 6 and game.player.reserve == shells_before - 4 and not game.player.loading_shells, "The reload stops when the tube is full and uses exactly four shells")
	game.player.ammo = 1
	game.player.start_reload()
	await wait(1.0)
	game.player.shoot()
	expect(game.player.ammo == 2 and not game.player.loading_shells and game.player.reload_left == 0.0, "Firing breaks off a half-finished shotgun reload")
	# --- a blast from close by throws back whoever it does not kill
	await wait(1.1)
	game.player.ammo = 6
	face(game, Vector3(0, 0.05, 1.0), PI)
	var sturdy: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	sturdy.max_health = 5000.0
	sturdy.health = 5000.0
	sturdy.position = Vector3(0, 0.05, 3.6)
	sturdy.held_left = 30.0
	await frames(12)
	var blast_from: float = sturdy.global_position.z
	game.player.shoot()
	var blast_harm: float = 5000.0 - sturdy.health
	var blast_speed: float = sturdy.knock.length()
	await frames(45)
	var blast_way: float = sturdy.global_position.z - blast_from
	sturdy.receive_hit(99999.0, Vector3.BACK)
	# From further away than a blast reaches, a body is hurt but stays where it is.
	await wait(1.1)
	face(game, Vector3(0, 0.05, 1.0), PI)
	var faraway: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	faraway.max_health = 5000.0
	faraway.health = 5000.0
	faraway.position = Vector3(0, 0.05, 15.0)
	faraway.held_left = 30.0
	await frames(12)
	game.player.shoot()
	var blast_far: bool = faraway.health < 5000.0 and faraway.knock == Vector3.ZERO
	faraway.receive_hit(99999.0, Vector3.BACK)
	var pump_gun: Dictionary = Survivor.WEAPONS.shotgun
	var auto_gun: Dictionary = Survivor.WEAPONS.autoshotgun
	expect(blast_harm >= 9 * float(pump_gun.damage) and float(pump_gun.damage) * int(pump_gun.pellets) > 200.0 and blast_speed > 3.0 and blast_way > 0.3 and blast_far and float(pump_gun.push) > float(auto_gun.push) and str(auto_gun.sound) == "autoshotgun" and bool(game.sounds.recorded.get("autoshotgun", false)) and float(auto_gun.damage) * int(auto_gun.pellets) > 130.0, "A blast from close by does more than 200 damage and throws back whoever is still standing (%.1f m/s, %.2f m); further away it only hurts. The automatic shotgun has a shot of its own" % [blast_speed, blast_way])
	# --- Ripper
	game.player.health = 100
	face(game, Vector3(0, 0.05, 1.0), PI)
	var hound: Infected = game.spawn_enemy("ripper")
	hound.position = Vector3(0, 0.05, 7.5)
	# Its first leap normally waits a random moment; here it must come at once.
	hound.special_cooldown = 0.0
	var hound_model: InfectedVisual = hound.model
	expect(hound_model is RipperVisual and hound_model.skeleton.get_bone_count() == 29, "The Ripper is a four-legged model with its own skeleton")
	var leapt := false
	var peak := 0.0
	for i in range(170):
		await get_tree().physics_frame
		if hound.leap == "air":
			leapt = true
			peak = maxf(peak, hound.global_position.y)
	expect(leapt and peak > 0.3, "A Ripper leaps at its prey from a distance")
	expect(game.player.health < 100, "The Ripper's pounce and bite hurt the survivor")
	hound.receive_hit(9999, Vector3.BACK)
	var hound_dead: bool = hound.dead
	await wait(1.5)
	expect(hound_dead and is_instance_valid(hound_model) and hound_model.dying, "A shot Ripper goes down")
	# --- gore
	game.player.health = 100
	face(game, Vector3(0, 0.05, 1.0), PI)
	var torn: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	torn.set_physics_process(false)
	torn.position = Vector3(0, 0.05, 4.0)
	await frames(3)
	var torn_model: InfectedVisual = torn.model
	var marks: int = game.fx.decals.size()
	torn.receive_hit(9999, Vector3.BACK, true)
	expect(torn_model.skeleton.get_bone_pose_scale(torn_model.rig.head.index).x < 0.01 and not torn_model.eyes.visible, "An overkill headshot tears the head off")
	await wait(1.3)
	expect(game.fx.decals.size() >= mini(marks + 3, CombatEffects.MAX_DECALS) and game.fx.decals.size() <= CombatEffects.MAX_DECALS, "Blood stays on the floor where an infected died, within the decal budget")
	# --- squad
	game.team_enabled = true
	game.start_run()
	await frames(4)
	expect(game.team.size() == 2 and game.survivors.size() == 3 and game.team[0].label == "VIPER" and game.team[1].label == "SCORPION", "Viper and Scorpion join a solo match")
	game.begin_wave()
	expect(game.remaining_to_spawn == int(round(7 * 1.7)) + int(round(1 * 1.7)), "A squad of three draws a bigger horde")
	game.spawn_queue.clear()
	face(game, Vector3(0, 0.05, 1.0), PI)
	var prey: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	prey.position = Vector3(0, 0.05, 7.5)
	var supplies: int = game.credits
	var fell := false
	for i in range(480):
		await get_tree().physics_frame
		if not is_instance_valid(prey) or prey.dead:
			fell = true
			break
	expect(fell and game.kills == 0 and game.team[0].kills + game.team[1].kills == 1 and game.credits == supplies + 25, "The squad shoots infected on its own; the supplies go to the team")
	# --- the squad keeps its distance
	var buddy: Teammate = game.team[1]
	game.player.position = buddy.global_position + Vector3(0.35, 0, 0.1)
	await wait(1.6)
	expect(Vector2(buddy.global_position.x - game.player.position.x, buddy.global_position.z - game.player.position.z).length() > 1.7, "A teammate makes room when the survivor stands right next to it")
	face(game, (spots.front_door_out as Vector3) + Vector3(0, 0.1, 7.0), PI)
	await wait(5.0)
	var nearest := INF
	var furthest := 0.0
	for follower in game.team:
		var space: float = Vector2(follower.global_position.x - game.player.position.x, follower.global_position.z - game.player.position.z).length()
		nearest = minf(nearest, space)
		furthest = maxf(furthest, space)
	expect(furthest < 7.0 and nearest > 1.8, "The squad catches up with the survivor and stops a few steps away (%.1f to %.1f m)" % [nearest, furthest])
	# --- squad orders
	face(game, Vector3(0, 0.05, 1.0), PI)
	for follower in game.team:
		follower.global_position = Vector3(2.4 * signf(follower.slot.x), 0.05, -0.6)
	game.player.camera.rotation.x = deg_to_rad(-25.0)
	await frames(3)
	game.command_squad("hold")
	var post: Vector3 = game.hold_marker.global_position
	expect(game.team[0].order == "hold" and game.squad_order == "hold" and game.hold_marker.visible and absf(post.z - 4.6) < 0.5 and absf(post.x) < 0.3, "The hold order marks the floor under the crosshair")
	await wait(3.0)
	face(game, (spots.front_door_out as Vector3) + Vector3(0, 0.1, 7.0), PI)
	await wait(2.5)
	var held := true
	for follower in game.team:
		held = held and Vector2(follower.global_position.x - post.x, follower.global_position.z - post.z).length() < 2.0
	expect(held, "A squad told to hold stays at its post when the survivor walks away")
	# Standing there, nobody turns with the survivor: one can walk around them.
	var looks: Array = []
	for follower in game.team:
		looks.append(follower.rotation.y)
	game.player.rotation.y += 2.2
	await wait(1.0)
	var steady := true
	for i in range(game.team.size()):
		steady = steady and absf(angle_difference(game.team[i].rotation.y, float(looks[i]))) < 0.05
	expect(steady, "A squad member that stands does not turn when the survivor turns")
	game.command_squad("follow")
	await wait(5.0)
	var back := true
	for follower in game.team:
		back = back and follower.global_position.distance_to(game.player.global_position) < 7.5
	expect(back and not game.hold_marker.visible and game.team[1].order == "follow", "Told to follow, the squad comes back to the survivor")
	var lure: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	lure.set_physics_process(false)
	# Out of sight in the shed, so nobody can simply shoot it from where they stand.
	lure.position = (spots.shed as Vector3) + Vector3(0, 0.05, 0)
	var before: Array = []
	for follower in game.team:
		before.append(follower.global_position.distance_to(lure.position))
	await wait(1.5)
	var stayed: float = absf(game.team[1].global_position.distance_to(lure.position) - float(before[1]))
	game.command_squad("free")
	await wait(3.0)
	expect(stayed < 2.0 and (not is_instance_valid(lure) or lure.dead or game.team[1].global_position.distance_to(lure.position) < float(before[1]) - 5.0), "A squad set free goes after the infected on its own")
	if is_instance_valid(lure) and not lure.dead:
		lure.receive_hit(9999, Vector3.BACK)
	game.command_squad("follow")
	face(game, Vector3(0, 0.05, 1.0), PI)
	for follower in game.team:
		follower.global_position = Vector3(2.4 * signf(follower.slot.x), 0.05, -0.6)
	var mate: Teammate = game.team[0]
	mate.receive_damage(999.0, mate.global_position + Vector3(0, 0, 3))
	expect(mate.down and not mate.is_targetable(), "A teammate without health goes down and is left alone by the infected")
	game.player.position = mate.global_position + Vector3(0.8, 0, 0)
	await frames(3)
	expect(game.fallen_mate() == mate and "aufhelfen" in game.interaction_prompt(), "A fallen teammate can be helped up")
	game.interact()
	expect(not mate.down and mate.health == 60.0 and game.stats.revives == 1, "E helps the teammate back on its feet")
	# --- the squad rescues the player
	game.player.health = 100
	game.player.receive_damage(500.0)
	expect(game.player.down and game.state == "playing" and not game.player.is_targetable() and "Hilfe" in game.interaction_prompt(), "With a squad standing, the survivor goes down instead of dying")
	var rescued := false
	for i in range(720):
		await get_tree().physics_frame
		if not game.player.down:
			rescued = true
			break
	expect(rescued and game.player.health == 50.0 and game.stats.revives == 2, "A teammate runs over and helps the survivor up")
	game.team[1].receive_damage(999.0)
	game.complete_wave()
	expect(not game.team[1].down and game.team[1].health == 100.0, "A survived round puts the whole squad back on its feet")
	for follower in game.team:
		follower.rising_left = 0.0
		follower.receive_damage(999.0)
	game.player.health = 100
	game.player.receive_damage(500.0)
	expect(game.state == "lose", "With the whole squad down, the survivor's fall ends the night")
	game.team_enabled = false
	game.start_run()
	expect(game.team.is_empty() and game.survivors.size() == 1 and game.mates.get_child_count() == 0, "Without a squad the survivor fights alone")
	game.player.receive_damage(150)
	expect(game.state == "lose" and not game.player.controlled, "Zero health ends the run")
	await _newer(game)
	await _story(game)
	await _kit(game)
	await _threats(game)
	await _later(game)
	await _latest(game)
	await _arsenal(game)
	await _loadout(game)
	await _squadwork(game)
	await _overhaul(game)
	await _operators(game)
	await _sandbox(game)
	await _hive(game)
	game.sounds.stop_all()
	await wait(0.2)
	print("INTEGRATION_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().call_deferred("quit", 0 if failures == 0 else 1)

## What came with v0.11: gas that lies over the yard as wide, thin banks and spreads, a
## launcher that lobs its shell, a finer mark in the reflex sight, more calls for the
## squad, and the trees of abilities (which are out of service: the checks switch them on
## for themselves and off again).
func _latest(game: Node3D) -> void:
	var player: Survivor = game.player
	var cabin: CabinMap = game.cabin
	var spots: Dictionary = cabin.points
	game.team_enabled = false
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	game.gas.clear()
	# --- a bank of gas spreads over the yard
	var seed_at: Vector3 = (spots.yard_south as Vector3) + Vector3(6.0, 0, 14.0)
	var bank: Dictionary = game.gas._start_bank(seed_at)
	bank.heading = 0.4
	bank.grow = 5
	var alone: int = game.gas.pockets.size()
	for i in range(5):
		game.gas._spread(bank)
	var patches: int = game.gas.pockets.size()
	var joined := true
	var outdoors := true
	for i in range(1, patches):
		var nearest := INF
		for j in range(i):
			nearest = minf(nearest, (game.gas.pockets[i].pos as Vector3).distance_to(game.gas.pockets[j].pos) - float(game.gas.pockets[j].radius))
		# Each new patch overlaps one that was there before, and none lies under a roof.
		joined = joined and nearest < float(game.gas.pockets[i].radius) * 0.5
		outdoors = outdoors and not cabin.is_indoors(game.gas.pockets[i].pos)
	var material: ShaderMaterial = (game.gas.pockets[0].volume as FogVolume).material as ShaderMaterial
	expect(alone == 1 and patches >= 4 and joined and outdoors and game.gas.covered() > 500.0 and material != null and material.shader.get_mode() == Shader.MODE_FOG and float(GasField.YARD_HAZE) < 0.35, "A bank of gas spreads patch by patch over the yard, as a thin haze (%d patches, %d m2)" % [patches, int(game.gas.covered())])
	for pocket in game.gas.pockets:
		pocket.strength = 1.0
	var middle: Vector3 = game.gas.pockets[patches - 1].pos
	face(game, middle + Vector3(0, 0.05, 0), 0.0)
	player.health = 100.0
	player.mask_level = 2
	player.filter_left = player.filter_capacity()
	await frames(4)
	game.hud._process(0.1)
	var warned: bool = player.in_gas and game.hud.gear_label.text.contains("IM GAS") and player.health == 100.0
	face(game, (spots.hall as Vector3) + Vector3(0, 0.05, 0), 0.0)
	await frames(4)
	game.hud._process(0.1)
	expect(warned and not player.in_gas and not game.hud.gear_label.text.contains("IM GAS") and game.toxic_at(middle + Vector3(0, 0.1, 0)) and not game.toxic_at(spots.hall), "The gas is hard to see, so the mask says when its filter is at work; the house stays clear")
	game.gas.end_round()
	var leaving := true
	for pocket in game.gas.pockets:
		leaving = leaving and bool(pocket.going)
	expect(leaving and game.gas.banks.is_empty(), "When the round is over the bank thins out")
	game.gas.clear()
	player.mask_level = 0
	player.filter_left = 0.0
	# --- the launcher lobs its shell
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.unlock("launcher")
	await frames(3)
	var flight: PackedVector3Array = player.launch_path()
	var top := -INF
	for point in flight:
		top = maxf(top, point.y)
	var landing: Vector3 = flight[flight.size() - 1]
	var reach := Vector2(landing.x - flight[0].x, landing.z - flight[0].z).length()
	Input.action_press("aim")
	await frames(5)
	var shown: bool = game.fx.arc_dots != null and game.fx.arc_dots.visible
	Input.action_release("aim")
	await frames(4)
	player.shot_cooldown = 0.0
	player.shoot()
	await frames(2)
	var shell: Throwable = null
	for node in game.ordnance.get_children():
		if node is Throwable and node.impact:
			shell = node
	var lobbed: bool = shell != null and is_equal_approx(shell.gravity_scale, Throwable.SHELL_PULL) and shell.linear_velocity.y > 1.0 and shell.linear_velocity.length() < 28.0
	if shell != null:
		shell.queue_free()
	expect(top > flight[0].y + 0.2 and landing.y < 0.4 and reach > 14.0 and reach < 30.0 and shown and not game.fx.arc_dots.visible and lobbed, "The launcher lobs its shell in an arc, and aiming shows where it will come down (%.1f m when held level)" % reach)
	# --- the mark of the reflex sight
	player.unlock("ak")
	player.equip_weapon("ak", true)
	var smallest := INF
	for node in (player.weapon.get_node("Mod_reddot") as Node3D).get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is QuadMesh:
			smallest = minf(smallest, ((node as MeshInstance3D).mesh as QuadMesh).size.x)
	expect(smallest < 0.002 and (WeaponView.materials.dot as StandardMaterial3D).albedo_color.r < 2.0, "The dot of the reflex sight is fine and dim (%.1f mm)" % (smallest * 1000.0))
	# --- more calls for the squad
	var rich := true
	for cue in ["reload", "kill", "special", "cru", "grenade", "down", "thanks", "rescue", "stalker", "clear", "leech", "order_follow", "order_hold", "order_free", "round", "hurt", "gas", "idle"]:
		for speaker in ["viper", "scorpion", "raven"]:
			rich = rich and (Radio.BARKS[cue][speaker] as Array).size() >= 3
	for cue in ["medic", "shield", "big_kill"]:
		for speaker in ["viper", "scorpion", "raven"]:
			rich = rich and (Radio.BARKS[cue][speaker] as Array).size() >= 2
	game.round_called = true
	game.phase = "preparing"
	game.begin_wave()
	var fresh: bool = not game.round_called
	game.spawn_queue.clear()
	game.phase = "preparing"
	game.preparation_left = 9999.0
	expect(rich and fresh and (Radio.BARKS.gas.cru as Array).size() == 2 and not game.squad_call("gas", player.global_position, 20.0), "The squad has at least three ways to say most things, and new things to say")
	# --- the trees of abilities
	var skills: Skills = game.skills
	var totals := {"kills": 1697, "special_kills": 635, "cru_kills": 91, "objectives": 28, "revives": 10, "victories": 3}
	var counted := true
	var abilities := 0
	var ids := {}
	for tree in Skills.TREES:
		var ranks := 0
		var tier := 1
		for skill in Skills.TREES[tree].skills:
			ranks += int(skill.ranks)
			counted = counted and str(skill.id).begins_with(tree + "_") and not ids.has(skill.id) and int(skill.tier) >= tier and int(skill.tier) <= 3 and Skills.note(skill, 1) != "" and not Skills.note(skill, 1).contains("%s")
			tier = int(skill.tier)
			ids[skill.id] = true
		counted = counted and ranks >= Skills.LEVELS - 1 and ranks <= Skills.LEVELS and (Skills.TREES[tree].skills as Array).size() >= 7
		abilities += (Skills.TREES[tree].skills as Array).size()
	expect(counted and abilities == 22 and Skills.TREES.size() == 3 and Skills.experience(totals) == 8263 and Skills.level_of(0) == 1 and Skills.level_of(499) == 1 and Skills.level_of(500) == 2 and Skills.level_of(8263) == 6 and Skills.level_of(9999999) == Skills.LEVELS, "Three trees of abilities with seven or eight abilities each, and levels enough for about one tree; a career gives experience and levels")
	game.hud.show_menu("skills")
	var marked := false
	for node in game.hud.modal.find_children("*", "Label", true, false):
		marked = marked or (node as Label).text == "IN WARTUNG"
	# No tree is in force yet: each offers itself, and each takes points.
	var chips := 0
	var picks := 0
	for node in game.hud.modal.find_children("*", "Button", true, false):
		if (node as Button).text == "+":
			chips += 1
		if (node as Button).text == "AKTIVIEREN":
			picks += 1
	var unchosen: bool = skills.chosen == "" and chips == abilities and picks == 3 and skills.barred("sweeper_damage", totals) == "" and skills.value("damage_common") == 0.0
	# One of them is put in force, then another, then the first again: nothing is lost.
	var took: bool = game.choose_tree("sweeper") and skills.chosen == "sweeper" and game.profile.skill_tree == "sweeper" and game.choose_tree("hunter") and game.profile.skill_tree == "hunter" and not game.choose_tree("nonsense") and game.choose_tree("sweeper") and skills.chosen == "sweeper"
	game.hud.show_menu("skills")
	chips = 0
	picks = 0
	var undo := false
	for node in game.hud.modal.find_children("*", "Button", true, false):
		if (node as Button).text == "+":
			chips += 1
		if (node as Button).text == "AKTIVIEREN":
			picks += 1
		undo = undo or (node as Button).text.begins_with("PUNKTE ZURÜCK")
	game.hud.hide_menu()
	var other_way: bool = skills.barred("hunter_damage", totals) == "" and skills.weapon_barred("nitro") == "3 Punkte in JÄGER"
	# With an empty career there is no level, so no point to spend.
	var career: Dictionary = game.profile.totals.duplicate()
	for key in game.profile.totals:
		game.profile.totals[key] = 0
	var pointless: bool = not game.learn_skill("sweeper_damage") and skills.barred("sweeper_damage", game.profile.totals) == "Kein Punkt frei"
	game.profile.totals = career
	game.reset_skills()
	expect(Skills.IN_SERVICE and skills.active and not marked and unchosen and took and chips == abilities and picks == 2 and undo and other_way and pointless and skills.chosen == "" and game.profile.skill_tree == "" and skills.ranks.is_empty() and game.profile.skills.is_empty() and skills.value("damage_common") == 0.0 and skills.harm_factor("bullet", "cru") == 1.0 and skills.shield_share("sniper") == 0.0, "The abilities are in service: every tree takes points, one of the three is in force and another can be put in force at will; without a level nothing can be bought, and without a rank nothing has an effect")
	# --- what they do
	skills.active = true
	skills.chosen = "breacher"
	var early: String = skills.barred("breacher_shield", totals)
	var bought := 0
	for id in ["breacher_armour", "breacher_armour", "breacher_armour", "breacher_shield", "breacher_plates"]:
		if skills.learn(id, totals):
			bought += 1
	var poor: bool = not skills.learn("breacher_plates", totals) and skills.barred("breacher_plates", totals) == "Kein Punkt frei"
	expect(early.begins_with("Erst 3 Punkte") and bought == 5 and poor and skills.spent("breacher") == 5 and skills.spent("sweeper") == 0 and skills.points_left(totals) == 0 and skills.rank("breacher_armour") == 3 and not skills.learn("breacher_armour", {"kills": 999999}), "Points open an ability rank by rank; the higher rows need points in their tree first")
	# A shield and the sniper rifle.
	var bearer := game.spawn_enemy("cru_shield") as CruSoldier
	bearer.set_physics_process(false)
	bearer.position = Vector3(0, 0.05, 30.0)
	bearer.model.rotation.y = 0.0
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.unlock("sniper")
	await frames(3)
	var sound: float = bearer.health
	skills.active = false
	player.climb = 0.0
	player.shot_cooldown = 0.0
	player.shoot()
	await frames(2)
	var stopped: bool = bearer.health == sound and bearer.blocks(Vector3.BACK)
	skills.active = true
	# The kick of the first shot has lifted the muzzle: level it again.
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.climb = 0.0
	player.shot_cooldown = 0.0
	player.bolt_clock = -1.0
	player.shoot()
	await frames(2)
	expect(stopped and bearer.health < sound and not game.blasting and is_equal_approx(skills.shield_share("ak"), 0.0) and skills.shield_share("sniper") == 1.0, "With the ability the sniper rifle shoots through a shield that stops it otherwise")
	bearer.receive_hit(99999.0, Vector3.FORWARD)
	# Armour, and what the survivor takes.
	var elite := game.spawn_enemy("cru_elite") as CruSoldier
	elite.set_physics_process(false)
	elite.position = Vector3(4.0, 0.05, 30.0)
	await frames(2)
	var whole: float = elite.health
	elite.receive_hit(100.0, Vector3.RIGHT)
	var pierced: float = whole - elite.health
	elite.health = whole
	elite.receive_hit(100.0, Vector3.RIGHT, false, player)
	var plain: float = whole - elite.health
	elite.receive_hit(99999.0, Vector3.FORWARD)
	player.health = 100.0
	player.plate_level = 0
	player.armor = 0.0
	player.receive_damage(10.0, Vector3.INF, "bullet", "cru")
	expect(is_equal_approx(pierced, 90.0) and is_equal_approx(plain, 60.0) and is_equal_approx(player.health, 100.0 - 10.0 * 0.92) and is_equal_approx(skills.armour_left(), 0.25), "Armour stops less of the player's fire, and bullets hurt him less")
	# The other two trees, rank by rank.
	skills.reset()
	skills.ranks = {"sweeper_damage": 3, "sweeper_reload": 3, "sweeper_ammo": 2, "sweeper_head": 2, "sweeper_skin": 3, "hunter_filter": 2, "hunter_skin": 3, "hunter_damage": 2, "hunter_acid": 2}
	var mauler: Infected = game.spawn_enemy("mauler")
	mauler.set_physics_process(false)
	mauler.position = Vector3(-4.0, 0.05, 30.0)
	var crusher: Infected = game.spawn_enemy("charger")
	crusher.set_physics_process(false)
	crusher.position = Vector3(-8.0, 0.05, 30.0)
	await frames(2)
	player.mask_level = 2
	skills.chosen = "hunter"
	var filter: float = player.filter_capacity()
	var hunting: bool = is_equal_approx(skills.damage_factor(crusher, true), 1.16) and is_equal_approx(skills.harm_factor("", "special"), 0.7) and is_equal_approx(skills.harm_factor("gas", ""), 0.7) and is_equal_approx(skills.harm_factor("acid", ""), 0.6) and is_equal_approx(filter, 20.0 * 1.5) and is_equal_approx(skills.damage_factor(mauler, false), 1.0) and is_equal_approx(skills.harm_factor("", "common"), 1.0) and player.reserve_cap("rifle") == 180
	skills.chosen = "sweeper"
	player.mask_level = 0
	player.equip_weapon("rifle", true)
	player.ammo = 3
	player.reload_left = 0.0
	player.start_reload()
	var quick: float = player.reload_left
	player.reload_left = 0.0
	player.ammo = int(Survivor.WEAPONS.rifle.magazine)
	expect(hunting and is_equal_approx(skills.damage_factor(mauler, false), 1.24) and is_equal_approx(skills.damage_factor(mauler, true), 1.48) and is_equal_approx(skills.damage_factor(crusher, true), 1.0) and is_equal_approx(skills.harm_factor("", "common"), 0.76) and is_equal_approx(skills.harm_factor("", "special"), 1.0) and is_equal_approx(skills.harm_factor("acid", ""), 1.0) and is_equal_approx(quick, float(Survivor.WEAPONS.rifle.reload_time) * 0.76) and player.reserve_cap("rifle") == 234, "The other abilities count rank by rank, and only those of the tree in force: harder hits, a thicker skin, a longer filter, quicker hands, deeper pockets")
	for foe in [mauler, crusher]:
		foe.receive_hit(99999.0, Vector3.FORWARD)
	# Taken back, with nothing left behind.
	skills.reset()
	skills.active = Skills.IN_SERVICE
	skills.adopt({"sweeper_damage": 9, "nonsense": 2})
	var taken: bool = skills.rank("sweeper_damage") == 3 and not skills.ranks.has("nonsense")
	skills.reset()
	expect(taken and skills.value("reload") == 0.0 and player.reserve_cap("rifle") == 180 and game.profile.skills.is_empty(), "Taken back, the abilities leave no trace; what the profile holds is checked before it is taken in")
	# --- the M4A4 is the starting rifle: a model with a magazine and iron sights of its own
	player.equip_weapon("rifle", true)
	var m4: Node3D = player.weapon
	var m4_gun: Dictionary = WeaponView.GUNS.rifle
	var irons := m4.find_child("Sights", true, false) as Node3D
	var over_irons: Vector3 = WeaponView.VIEWS.rifle.aim
	var lined: bool = is_equal_approx(over_irons.y, -((m4_gun.mount as Vector3).y + float(m4_gun.irons))) and over_irons.x == 0.0
	player.fit("rifle", "reddot")
	var folded: bool = irons != null and not irons.visible and (m4.get_node("Mod_reddot") as Node3D).visible and WeaponView.sight_aim("rifle", "reddot").y < over_irons.y - 0.02
	player.fit("rifle", "reddot")
	expect(str(Survivor.WEAPONS.rifle.label) == "M4A4" and m4.get_node_or_null("Magazine") != null and m4.get_node_or_null("Support") != null and irons != null and irons.visible and lined and folded and (WeaponView.reload_step("rifle", 0.38).magazine as Vector3).length() > 0.2 and Survivor.ATTACHMENTS.has("rifle"), "The starting rifle is the M4A4: its magazine leaves the gun, the eye looks through its iron sights, and they fold away under a fitted sight")
	# --- five kinds of dead bodies, and model trees at the edge of the open yard
	var kinds := {}
	var complete := true
	for x in range(40):
		kinds[MissionDirector.corpse_at(Vector3(x * 0.5, 0, 20.0 + x * 1.5))] = true
	for entry in MissionDirector.CORPSES:
		complete = complete and ResourceLoader.exists(str(entry.scene)) and (entry.back as Vector3).y > 0.2 and (entry.case as Vector3).y > 0.15
	var holder := Node3D.new()
	game.add_child(holder)
	var spot := Vector3.ZERO
	for x in range(200):
		if MissionDirector.CORPSES[MissionDirector.corpse_at(Vector3(x * 0.5, 0, 30.0))].has("loose"):
			spot = Vector3(x * 0.5, 0, 30.0)
	var anchors: Dictionary = game.mission._body(holder, spot)
	var beside: bool = holder.get_node_or_null("Case") != null and anchors.has("loose") and absf((holder.get_node("Case") as Node3D).position.x - (anchors.case as Vector3).x) < 0.001
	holder.queue_free()
	expect(MissionDirector.CORPSES.size() == 5 and kinds.size() == 5 and complete and beside and not CabinMap.OUTER_FENCE and cabin.model_trees >= 60 and cabin.tree_kinds == CabinMap.TREE_MODELS.size() and cabin.tree_kinds >= 7, "Five kinds of dead lie on the farm, the new ones with a case stood beside them; the yard has no fence, and %d trees at its edge are models of %d kinds" % [cabin.model_trees, cabin.tree_kinds])
	# --- the machine gun
	var owned: bool = player.unlock("mg")
	var mg: Node3D = player.weapon
	expect(owned and player.current_weapon == "mg" and player.ammo == 100 and player.max_reserve() == 400 and int(Survivor.WEAPONS.mg.slot) == int(Survivor.WEAPONS.minigun.slot) and Survivor.ORDER.has("mg") and str(Survivor.WEAPONS.mg.group) == "heavy" and mg.get_node_or_null("Magazine") != null and mg.find_child("Feed", true, false) != null and game.sounds.recorded.get("mg", false), "The machine gun carries a hundred rounds in its box and four boxes more, and shares its key with the minigun")
	# --- the M21E, the second machine gun (its id is mg2): its drum has textures of its own
	# and comes off whole. Its front post stands lower than its rear sight, so it is tipped up
	# a little when aimed.
	var mg2_owned: bool = player.unlock("mg2")
	var mg2_full: bool = player.ammo == 75 and player.max_reserve() == 300
	var mg2: Node3D = player.weapon
	var mg2_gun: Dictionary = WeaponView.GUNS.mg2
	var mg2_aim: Vector3 = WeaponView.VIEWS.mg2.aim
	var mg2_lined: bool = absf(mg2_aim.y + (mg2_gun.mount as Vector3).y + float(mg2_gun.irons)) < 0.005 and float((WeaponView.VIEWS.mg2.aim_angles as Vector3).x) > 0.0 and mg2_aim.x == 0.0 and (WeaponView.VIEWS.mg2.muzzle as Vector3).is_equal_approx((mg2_gun.mount as Vector3) + (mg2_gun.muzzle as Vector3))
	var mg2_drum := mg2.get_node_or_null("Magazine") as Node3D
	var mg2_paint := false
	# The drum hangs as a drum does: its own axis along the barrel (so it is wider across the
	# gun than it is deep along it), in the middle under the gun, forward of the pistol grip.
	var mg2_hung := false
	if mg2_drum != null:
		var mg2_body := mg2.find_child("Body", true, false) as MeshInstance3D
		var mg2_shell := mg2_drum.find_child("*", true, false) as MeshInstance3D
		if mg2_body != null and mg2_shell != null:
			var mg2_skin := mg2_shell.get_surface_override_material(0) as BaseMaterial3D
			mg2_paint = mg2_skin != null and mg2_skin.albedo_texture != null and mg2_skin != mg2_body.get_surface_override_material(0)
			var mg2_box: AABB = mg2_shell.transform * mg2_shell.get_aabb()
			mg2_hung = mg2_box.size.x > 0.15 and mg2_box.size.x > mg2_box.size.z * 1.3 and absf(mg2_box.get_center().x) < 0.01 and mg2_box.end.z < (mg2_gun.mount as Vector3).z and mg2_box.end.y < (mg2_gun.mount as Vector3).y + float(mg2_gun.rail)
	# What the player reads of it: its name, in the hand and on the shop's list of heavy
	# weapons, where it stands right after the machine gun.
	var mg2_named: bool = str(Survivor.WEAPONS.mg2.label) == "M21E" and player.weapon_label() == "M21E" and str(Survivor.WEAPONS.mg.label) == "MASCHINENGEWEHR" and Survivor.ORDER.find("mg2") == Survivor.ORDER.find("mg") + 1 and str(Survivor.WEAPONS.mg2.group) == "heavy" and str(SurvivalHUD.SHOP_NOTES.get("mg2", "")).contains("Trommel")
	# The reload: the drum leaves the gun, and a full one comes back.
	player.ammo = 5
	player.start_reload()
	var mg2_away := 0.0
	for i in range(int(float(Survivor.WEAPONS.mg2.reload_time) * 60.0) + 20):
		await get_tree().physics_frame
		if mg2_drum != null:
			mg2_away = maxf(mg2_away, mg2_drum.position.length())
	expect(mg2_owned and player.current_weapon == "mg2" and mg2_full and mg2_named and Survivor.kind_of("mg2") == "heavy" and mg2_drum != null and mg2_lined and mg2_paint and mg2_hung and (WeaponView.reload_step("mg2", 0.38).magazine as Vector3).length() > 0.2 and mg2_away > 0.2 and mg2_drum.position.length() < 0.001 and player.ammo == 75 and bool(game.sounds.recorded.get("mg2", false)) and float(Survivor.WEAPONS.mg2.damage) > float(Survivor.WEAPONS.mg.damage) and int(Survivor.WEAPONS.mg2.magazine) < int(Survivor.WEAPONS.mg.magazine), "The M21E is a second machine gun beside the old one: 75 harder rounds in a drum with textures of its own, which hangs in the middle under the gun with its round faces to the muzzle and to the shooter and comes off when it is reloaded; it is aimed over its iron sights")
	game.team_enabled = true
	game.start_run()

## Puts every attacker of the running round down and takes the rest of it off the list.
## The lowest point of a body's skin as it is posed now (every third vertex).
func _mesh_low(body: InfectedVisual) -> float:
	var skel: Skeleton3D = body.skeleton
	var inst: MeshInstance3D = body.mesh_instance
	if inst == null or inst.skin == null:
		return NAN
	var skin: Skin = inst.skin
	var mats: Array = []
	for bind in range(skin.get_bind_count()):
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(bind))
		mats.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	var low := INF
	var to_world: Transform3D = skel.global_transform
	for surface in range(inst.mesh.get_surface_count()):
		var arrays: Array = inst.mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if verts.is_empty() or bones.is_empty():
			return NAN
		var per: int = bones.size() / verts.size()
		for v in range(0, verts.size(), 3):
			var at := Vector3.ZERO
			for k in range(per):
				var weight: float = weights[v * per + k]
				if weight > 0.0:
					at += ((mats[bones[v * per + k]] as Transform3D) * verts[v]) * weight
			low = minf(low, (to_world * at).y)
	return low

func _wipe(game: Node3D) -> void:
	game.spawn_queue.clear()
	for node in get_tree().get_nodes_in_group("infected"):
		(node as Infected).receive_hit(99999.0, Vector3.FORWARD)

## What came with v0.14: a blow with the weapon, fire, single shots, a weapon for each tree
## of abilities, upgrades for the squad, Nadja's thicker skin, more voices for the C.R.U.,
## soldiers who do not roll into walls, the endless night and the modifiers.
func _arsenal(game: Node3D) -> void:
	var player: Survivor = game.player
	var cabin: CabinMap = game.cabin
	var spots: Dictionary = cabin.points
	var skills: Skills = game.skills
	var stand := Vector3(0, 0.05, 22.0)
	game.profile.mode = "story"
	game.profile.modifiers = false
	game.team_enabled = false
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	game.gas.clear()
	skills.reset()
	# --- a blow with the weapon
	face(game, stand, PI)
	var near: Infected = game.spawn_enemy("mauler")
	near.position = stand + Vector3(0, 0, 1.5)
	var behind: Infected = game.spawn_enemy("mauler")
	behind.position = stand + Vector3(0, 0, -1.5)
	behind.set_physics_process(false)
	await frames(2)
	var sound: float = near.health
	var start: float = near.global_position.z
	player.melee()
	var struck: bool = near.held_left >= Survivor.MELEE_DAZE - 0.01 and near.knock.z > 2.0 and is_equal_approx(near.health, sound - Survivor.MELEE_DAMAGE)
	var spared: bool = behind.health == behind.max_health and behind.knock == Vector3.ZERO
	player.melee()
	var once: bool = player.melee_cooldown > 0.0 and is_equal_approx(near.health, sound - Survivor.MELEE_DAMAGE)
	await frames(24)
	var thrown: float = near.global_position.z - start
	expect(struck and spared and once and thrown > 0.3 and near.held_left > 0.5 and InputMap.has_action("melee"), "A blow with the weapon throws back whoever stands in front and leaves him reeling; the next blow takes a moment (%.1f m)" % thrown)
	# The heavy ones are held up, and nothing moves the Crusher.
	var giant: Infected = game.spawn_enemy("crusher")
	giant.set_physics_process(false)
	giant.position = stand + Vector3(34.0, 0, 6.0)
	await frames(2)
	giant.shove(Vector3.BACK, Survivor.MELEE_PUSH, Survivor.MELEE_DAZE, Survivor.MELEE_DAMAGE)
	giant.blown(Vector3.BACK, float(Survivor.WEAPONS.shotgun.push))
	expect(giant.knock == Vector3.ZERO and giant.held_left > 0.0 and giant.held_left < 1.0 and giant.health < giant.max_health, "The Crusher is only held up for a moment by a blow, and not moved at all: not by a blast of shot either")
	_wipe(game)
	game.boss = null
	await frames(2)
	# --- the Molotov cocktail
	game.credits = 500
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	var sold: bool = game.buy_item("molotov") and int(player.items.molotov) == 1 and game.credits == 430 and game.item_price("squad_armor") == -1 and not game.buy_item("squad_armor")
	game.resume_run()
	face(game, stand, PI)
	await frames(2)
	var flight: PackedVector3Array = player.throw_path("molotov")
	player.throw_cooldown = 0.0
	player.throw("molotov")
	var waited := 0
	while game.fire.fires.is_empty() and waited < 300:
		await get_tree().physics_frame
		waited += 1
	var lit: bool = game.fire.fires.size() == 1 and int(player.items.molotov) == 0
	var center: Vector3 = game.fire.fires[0].pos if lit else stand
	var landed: bool = lit and flight.size() > 4 and Vector2(center.x - flight[flight.size() - 1].x, center.z - flight[flight.size() - 1].z).length() < 2.5
	var walker: Infected = game.spawn_enemy("mauler")
	walker.position = center + Vector3(0.6, 0.05, 0)
	walker.max_health = 400.0
	walker.health = 400.0
	walker.alert = true
	walker.held_left = 60.0
	await frames(40)
	# Two bites of the fire at the least in that time.
	var burnt: bool = walker.health < 370.0 and walker.burn_left > 0.0 and walker.flames != null and walker.flames.emitting
	# The fire bites whoever stands in it, the thrower as well.
	player.health = 100.0
	face(game, center + Vector3(0, 0.05, 0), 0.0)
	await frames(20)
	var scorched: bool = player.health < 100.0 and game.fire.burning_at(player.global_position)
	face(game, stand + Vector3(-20.0, 0, 0), PI)
	var kept: float = player.health
	walker.global_position = center + Vector3(9.0, 0.05, 0)
	var left: float = walker.health
	await frames(45)
	var burns_on: bool = walker.health < left and not game.fire.burning_at(walker.global_position) and player.health == kept
	if lit:
		game.fire.fires[0].left = 0.05
	await frames(8)
	expect(sold and landed and burnt and scorched and burns_on and game.fire.fires.is_empty() and InputMap.has_action("throw_molotov") and game.hud.tiles.has("molotov"), "A Molotov cocktail bursts where it strikes: the ground burns, enemies in it burn and burn on outside it, and the fire spares nobody who stands in it")
	_wipe(game)
	player.health = 100.0
	# --- five more weapons
	var arms := true
	for id in ["m14", "svd", "flamer", "nitro", "fifty"]:
		arms = arms and Survivor.WEAPONS.has(id) and Survivor.ORDER.has(id) and WeaponView.MODELS.has(id) and WeaponView.VIEWS.has(id) and ResourceLoader.exists(str(WeaponView.MODELS[id].scene)) and SurvivalHUD.SHOP_NOTES.has(id) and player.weapon_models.has(id) and game.sounds.clips.has(str(Survivor.WEAPONS[id].sound))
	var scoped: bool = Survivor.WEAPONS.svd.has("scope") and Survivor.WEAPONS.fifty.has("scope") and not Survivor.WEAPONS.m14.has("scope") and not Survivor.WEAPONS.nitro.has("scope")
	var heard := true
	for kind in ["m14", "svd", "fifty", "nitro", "melee", "molotov", "fire", "flamer"]:
		heard = heard and bool(game.sounds.recorded.get(kind, false))
	expect(arms and scoped and heard and (game.sounds.clips.melee as Array).size() == 3 and Survivor.ORDER.size() == Survivor.WEAPONS.size(), "Five more weapons: each has a model, a view, a sound and a line in the shop; their shots, the blow, the bottle and both fires are recordings")
	# A single shot for every pull of the trigger.
	player.unlock("m14")
	await frames(2)
	player.shot_cooldown = 0.0
	var rounds: int = player.ammo
	player.shoot()
	var held: bool = player.trigger_held and not player.trigger_free() and player.ammo == rounds - 1
	player.equip_weapon("rifle", true)
	var automatic: bool = player.trigger_free()
	player.equip_weapon("m14", true)
	await frames(2)
	# The double rifle breaks open while it is loaded.
	player.unlock("nitro")
	var hinge := player.weapon.find_child("Barrels", true, false) as Node3D
	player.ammo = 0
	player.start_reload()
	var dropped := 0.0
	for i in range(int(float(Survivor.WEAPONS.nitro.reload_time) * 60.0) + 12):
		await get_tree().physics_frame
		if hinge != null:
			dropped = minf(dropped, hinge.rotation.x)
	expect(hinge != null and dropped < -0.45 and absf(hinge.rotation.x) < 0.001 and player.ammo == 2 and player.reload_left <= 0.0, "The double rifle breaks open to be loaded and closes again (%d degrees)" % int(round(rad_to_deg(-dropped))))
	player.inventory.erase("nitro")
	player.equip_weapon("m14", true)
	expect(rounds == 20 and held and automatic and player.trigger_free() and not Survivor.WEAPONS.rifle.has("semi") and Survivor.WEAPONS.svd.get("semi", false), "The M14 fires one shot for every pull of the trigger; the carbine keeps firing")
	# --- a weapon for each tree of abilities
	game.credits = 9000
	game.wave = 2
	# Slings, so that what is bought here is carried and not traded in.
	player.extra_slots = 3
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	var shut: bool = not game.buy_weapon("flamer") and not game.buy_weapon("nitro") and not game.buy_weapon("fifty") and skills.weapon_barred("fifty") == "3 Punkte in BRECHER" and skills.weapon_barred("m14") == "" and game.credits == 9000
	skills.chosen = "sweeper"
	var early: bool = not game.buy_weapon("flamer") and skills.weapon_barred("flamer") == "3 Punkte in SÄUBERER"
	skills.ranks = {"sweeper_damage": 3}
	# Points in a tree that is not in force do not open its weapon.
	skills.chosen = "hunter"
	var resting: bool = not game.buy_weapon("flamer") and skills.weapon_barred("flamer") == "SÄUBERER nicht aktiv"
	skills.chosen = "sweeper"
	var first: bool = resting and game.buy_weapon("flamer") and not game.buy_weapon("fifty") and not game.buy_weapon("nitro") and player.current_weapon == "flamer"
	skills.reset()
	skills.chosen = "breacher"
	skills.ranks = {"breacher_armour": 2, "breacher_plates": 1}
	var others: bool = game.buy_weapon("fifty") and not game.buy_weapon("nitro") and game.buy_weapon("svd")
	skills.reset()
	skills.chosen = "hunter"
	skills.ranks = {"hunter_damage": 3}
	others = others and game.buy_weapon("nitro") and not game.buy_weapon("flamer")
	game.resume_run()
	game.wave = 0
	skills.reset()
	expect(shut and early and first and others and Skills.weapon_tree("flamer") == "sweeper" and Skills.weapon_tree("nitro") == "hunter" and Skills.weapon_tree("fifty") == "breacher" and Skills.weapon_tree("svd") == "", "Each tree of abilities has a weapon of its own, which the shop sells only while that tree is in force and three points are in it")
	# The .50 against a shield and against armour, with no ability at all.
	var bearer := game.spawn_enemy("cru_shield") as CruSoldier
	bearer.set_physics_process(false)
	bearer.position = Vector3(0, 0.05, 30.0)
	bearer.model.rotation.y = 0.0
	var elite := game.spawn_enemy("cru_elite") as CruSoldier
	elite.set_physics_process(false)
	elite.position = Vector3(6.0, 0.05, 30.0)
	var charger: Infected = game.spawn_enemy("charger")
	charger.set_physics_process(false)
	charger.position = Vector3(-6.0, 0.05, 30.0)
	var mauler: Infected = game.spawn_enemy("mauler")
	mauler.set_physics_process(false)
	mauler.position = Vector3(-10.0, 0.05, 30.0)
	face(game, stand, PI)
	player.equip_weapon("fifty", true)
	await frames(3)
	var shielded: bool = bearer.blocks(Vector3.BACK)
	var whole: float = bearer.health
	player.climb = 0.0
	player.shot_cooldown = 0.0
	player.shoot()
	await frames(2)
	var through: bool = shielded and (bearer.dead or bearer.health < whole) and game.piercing == 1.0 and not game.blasting
	var sturdy: float = elite.health
	game.piercing = float(Survivor.WEAPONS.fifty.armour)
	elite.receive_hit(50.0, Vector3.RIGHT)
	game.piercing = 1.0
	var bare: float = sturdy - elite.health
	elite.health = sturdy
	elite.receive_hit(50.0, Vector3.RIGHT)
	var stopped: float = sturdy - elite.health
	expect(through and is_equal_approx(bare, 50.0) and is_equal_approx(stopped, 30.0) and is_equal_approx(elite.armour_gain(0.0), 1.0 / 0.6) and is_equal_approx(elite.armour_gain(1.0), 1.0), "The .50 goes through a shield and through armour by itself")
	expect(is_equal_approx(player._bonus(Survivor.WEAPONS.nitro, charger, false), 1.5) and is_equal_approx(player._bonus(Survivor.WEAPONS.nitro, mauler, false), 1.0) and is_equal_approx(player._bonus(Survivor.WEAPONS.fifty, charger, false), 1.0), "The double rifle is made for the special infected: half as much again against them")
	_wipe(game)
	await frames(2)
	# The flamethrower.
	var target: Infected = game.spawn_enemy("mauler")
	target.position = stand + Vector3(0, 0, 6.0)
	var aside: Infected = game.spawn_enemy("mauler")
	aside.position = stand + Vector3(6.0, 0, 1.0)
	for foe in [target, aside]:
		foe.max_health = 500.0
		foe.health = 500.0
		foe.alert = true
		foe.held_left = 60.0
	face(game, stand, PI)
	player.equip_weapon("flamer", true)
	await frames(3)
	var tank: int = player.ammo
	player.shot_cooldown = 0.0
	player.shoot()
	await frames(2)
	var alight: bool = target.health < 500.0 and target.burn_left > 0.0 and aside.health == 500.0 and aside.burn_left <= 0.0 and player.ammo == tank - 1 and player.flame_stream != null and player.flame_stream.emitting
	await frames(16)
	expect(tank == 150 and alight and not player.flame_stream.emitting and not player.flame_voice.playing, "The flamethrower scorches what stands in its stream and sets it alight; what stands beside it is spared, and the stream stops with the trigger")
	_wipe(game)
	# --- Nadja takes more, and is hunted less
	game.story._free_nadja()
	var nadja: Teammate = game.story.nadja
	await frames(2)
	face(game, stand, PI)
	nadja.global_position = stand + Vector3(6.0, 0, 0)
	var between: Vector3 = stand + Vector3(4.0, 0, 0)
	var chosen: Node3D = game.nearest_survivor(between)
	var close: Node3D = game.nearest_survivor(stand + Vector3(5.5, 0, 0))
	nadja.receive_damage(100.0)
	expect(is_equal_approx(nadja.max_health, StoryDirector.NADJA_HEALTH) and float(StoryDirector.NADJA_HEALTH) > 200.0 and chosen == player and close == nadja and not nadja.down and is_equal_approx(nadja.health, StoryDirector.NADJA_HEALTH - 100.0 * Teammate.ARMOUR), "Nadja takes far more than the squad does, and the hunters go for the others first unless she is much nearer")
	game.story.clear()
	# --- more voices for the C.R.U.
	var voices := {}
	for id in range(8):
		var recruit := CruSoldier.new()
		recruit.net_id = id
		voices[recruit.voice()] = true
		recruit.free()
	var written := true
	for cue in ["contact", "frag", "gas", "flank", "cover", "man_down", "retreat", "push", "medic"]:
		for speaker in CruSoldier.VOICES:
			written = written and (Radio.BARKS[cue] as Dictionary).has(speaker) and str(Radio.NAMES[speaker]) == "C.R.U." and str(Radio.bark(speaker, cue).sound) != ""
	# A voice that has not recorded a line leaves it to the first voice of the unit.
	var trooper := game.spawn_enemy("cru_assault") as CruSoldier
	trooper.set_physics_process(false)
	trooper.position = Vector3(0, 0.05, 30.0)
	await frames(2)
	var hidden: Array = []
	for i in range((Radio.BARKS.contact.cru3 as Array).size()):
		hidden.append("%scru3/contact_%d.ogg" % [Radio.VOICE_FOLDER, i + 1])
		Radio.known[hidden[-1]] = false
	game.bark_until.clear()
	var spoken: bool = game.bark(trooper, "cru3", "contact")
	var turn: bool = not game.bark(trooper, "cru", "contact")
	for path in hidden:
		Radio.known.erase(path)
	game.bark_until.clear()
	expect(voices.size() == 4 and CruSoldier.VOICES.size() == 4 and written and spoken and turn, "The soldiers of the C.R.U. have four recorded voices, one for good each; a line a voice has not recorded is left to the first, and they still take turns")
	# --- more ways for a soldier to go down, and each of them ends on the ground
	var falls: Array = SoldierVisual.FALLS + SoldierVisual.DEATHS
	var hips := Vector2(INF, -INF)
	var lowest := INF
	var highest := -INF
	var odd := ""
	var played := 0
	for look in ["cru", "cru2", "cru3", "cru_heavy", "cru_lead", "cruelite"]:
		for clip in falls:
			var body := CruVisual.new()
			body.kind = look
			game.add_child(body)
			body.position = Vector3(60.0, 0.0, 80.0)
			for step in range(6):
				body.animate(1.0 / 30.0, 0.0)
			body.die(str(clip))
			if body.soldier.legs.current_animation.ends_with(str(clip)):
				played += 1
			for step in range(170):
				body.animate(1.0 / 30.0, 0.0)
			var bones: Skeleton3D = body.soldier.skeleton
			var low := INF
			for bone in range(bones.get_bone_count()):
				low = minf(low, (bones.global_transform * bones.get_bone_global_pose(bone).origin).y)
			var hip: float = (bones.global_transform * bones.get_bone_global_pose(int(body.soldier.rig.pelvis.index)).origin).y
			var head: float = body.head_position().y
			hips = Vector2(minf(hips.x, hip), maxf(hips.y, hip))
			lowest = minf(lowest, low)
			highest = maxf(highest, head)
			if low < -0.2 or hip < 0.03 or hip > 0.5 or head > 0.75:
				odd += " %s/%s (lowest %.2f, hips %.2f, head %.2f)" % [look, clip, low, hip, head]
			body.free()
	expect(falls.size() == 18 and played == 108 and odd == "", "A soldier has eighteen ways to go down, and every one of them ends on the ground: hips %.2f to %.2f m up, head at most %.2f m, nothing lower than %.2f m%s" % [hips.x, hips.y, highest, lowest, odd])
	var picked := {}
	var known := true
	for i in range(300):
		var fall: String = (trooper.model as CruVisual).pick_death(i % 4 == 0, i % 3 == 0, [-0.8, 0.0, 0.8][i % 3], i % 5 == 0)
		picked[fall] = true
		known = known and falls.has(fall)
	expect(picked.size() >= 15 and known, "Which fall it is depends on where the shot came from (%d of them turned up)" % picked.size())
	# --- the infected: every fall a build may do ends on the ground, bones and skin
	InfectedVisual._prepare_source()
	var recorded: Array = []
	for table in [InfectedVisual.source.clips, InfectedVisual.more.clips]:
		for clip in table:
			if bool(table[clip].fall) and str(table[clip].set) == "zombie":
				recorded.append(clip)
	var pooled := true
	for pool in InfectedVisual.DEATHS:
		for clip in InfectedVisual.DEATHS[pool]:
			pooled = pooled and recorded.has(clip)
	var sunk := ""
	var deepest := 0.0
	var bodies := 0
	var doable := true
	var flung := 0
	for kind in InfectedVisual.KINDS:
		var build: Dictionary = InfectedVisual.KINDS[kind]
		# The Charger never lies down: it bursts - in either of its two bodies.
		if str(build.set) != "zombie" or kind in ["charger", "boomer2"]:
			continue
		var size: float = float(build.height) / 1.78
		var asked := false
		for clip in recorded:
			if build.has("deaths") and not (build.deaths as Array).has(clip):
				continue
			var body := InfectedVisual.new()
			body.kind = kind
			game.add_child(body)
			body.position = Vector3(60.0, 0.0, 80.0)
			for step in range(6):
				body.animate(1.0 / 30.0, 0.0)
			body.die(str(clip))
			var playing: bool = body.player.current_animation == str(clip)
			for step in range(150):
				body.animate(1.0 / 30.0, 0.0)
			var bones: Skeleton3D = body.skeleton
			var low := INF
			for bone in range(bones.get_bone_count()):
				low = minf(low, (bones.global_transform * bones.get_bone_global_pose(bone).origin).y)
			var hip: float = (bones.global_transform * bones.get_bone_global_pose(int(body.rig.pelvis.index)).origin).y
			var head: float = body.head_position().y
			var skin: float = _mesh_low(body)
			deepest = minf(deepest, skin)
			bodies += 1
			if not playing or low < -0.2 * size or hip < 0.03 * size or hip > 0.5 * size or head > 0.75 * size or not skin >= -0.16:
				sunk += " %s/%s (bones %.2f, hips %.2f, head %.2f, skin %.2f)" % [kind, clip, low, hip, head, skin]
			if not asked:
				asked = true
				# What it picks, it can do; a hit far harder than it took throws it back.
				for i in range(60):
					var fall: String = body.pick_death(i % 4 == 0, i % 3 == 0, [-0.8, 0.0, 0.8][i % 3], i % 5 == 0)
					doable = doable and body.player.has_animation(fall) and (not build.has("deaths") or (build.deaths as Array).has(fall))
				for i in range(20):
					if body.pick_death(false, false, 0.0, true) == "death_fly_back":
						flung += 1
			body.free()
	expect(recorded.size() == 18 and InfectedVisual.MORE.size() == 6 and pooled and bodies > 130 and sunk == "" and doable and flung >= 30, "The infected have eighteen falls, six of them recorded on another rig; every one a build may do ends on the ground (%d bodies, skin at most %.2f m deep)%s, and a hit far harder than it took often throws a body back" % [bodies, -deepest, sunk])
	# --- the roll is played where the body is: the clip itself carries nobody away
	var roller := SoldierVisual.new()
	roller.look = "cru"
	game.add_child(roller)
	roller.position = Vector3(60.0, 0.0, 84.0)
	for step in range(5):
		roller.animate(1.0 / 60.0, Vector3.ZERO, false, false)
	var hip_bone: int = roller.rig.pelvis.index
	var hip_rest: Vector3 = roller.skeleton.global_transform * roller.skeleton.get_bone_global_pose(hip_bone).origin
	roller.roll(CruSoldier.ROLL_SECONDS)
	var carried := 0.0
	for step in range(int(CruSoldier.ROLL_SECONDS * 60.0) - 2):
		roller.animate(1.0 / 60.0, Vector3.ZERO, false, false)
		var hip_now: Vector3 = roller.skeleton.global_transform * roller.skeleton.get_bone_global_pose(hip_bone).origin
		carried = maxf(carried, Vector2(hip_now.x - hip_rest.x, hip_now.z - hip_rest.z).length())
	roller.free()
	expect(carried < 0.15, "The roll is played where the soldier's body is: its clip carries the model no further than %.2f m from it" % carried)
	# --- no roll without room for it
	trooper.prey = player
	face(game, stand, PI)
	var stair: Dictionary = cabin.stairs[0]
	var flight_middle: Vector3 = ((stair.foot as Vector3) + (stair.head as Vector3)) * 0.5
	trooper.global_position = flight_middle
	trooper.threatened(true)
	var stays: bool = cabin.on_stairs(flight_middle) and trooper.roll_left <= 0.0
	trooper.global_position = Vector3(0, 0.05, 30.0)
	await frames(2)
	trooper.threatened(true)
	var rolls: bool = not cabin.on_stairs(trooper.global_position) and trooper.roll_left > 0.0
	# Between two walls that are closer than a roll is long.
	trooper.roll_left = 0.0
	trooper.global_position = (spots.stair_hall as Vector3) + Vector3(0, 0.05, 0)
	await frames(2)
	var room := 0
	for way in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		if trooper._room_to_roll(way):
			room += 1
	expect(stays and rolls and room < 4, "A soldier throws himself aside in the open, never on a flight of stairs and never towards a wall (%d of 4 ways free in the stair hall)" % room)
	_wipe(game)
	# --- upgrades for the squad
	game.team_enabled = true
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	game.credits = 2000
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	var mate: Teammate = game.team[0]
	var price: int = game.item_price("squad_armor")
	var kit: bool = game.buy_item("squad_armor") and game.buy_item("squad_ammo") and game.buy_item("squad_ammo")
	var outfit: bool = is_equal_approx(mate.max_health, 130.0) and is_equal_approx(mate.health, 130.0) and is_equal_approx(mate.damage_factor, 1.4) and is_equal_approx(game.team[1].max_health, 130.0)
	game.buy_item("squad_ammo")
	var full: bool = game.item_price("squad_ammo") == -1 and not game.buy_item("squad_ammo") and int(game.squad_levels.squad_ammo) == 3
	game.resume_run()
	mate.receive_damage(100.0)
	var hurt: float = mate.health
	mate.revive(true)
	expect(price == 180 and kit and outfit and full and game.credits == 2000 - 180 - 180 - 300 - 450 and is_equal_approx(hurt, 130.0 - 100.0 * Teammate.ARMOUR) and is_equal_approx(mate.health, 130.0), "The shop upgrades the squad: more health and harder hits, level by level")
	game.start_run()
	expect(int(game.squad_levels.squad_armor) == 0 and int(game.squad_levels.squad_ammo) == 0 and is_equal_approx(game.team[0].max_health, 100.0) and is_equal_approx(game.team[0].damage_factor, 1.0), "A new night starts with a squad as it was")
	# --- points are spent, kept and taken back
	var career: Dictionary = game.profile.totals.duplicate()
	for key in game.profile.totals:
		game.profile.totals[key] = 0
	game.profile.totals.victories = 3
	var learnt: bool = game.learn_skill("sweeper_damage") and game.profile.skill_tree == "sweeper" and game.learn_skill("hunter_damage") and not game.learn_skill("sweeper_damage") and int(game.profile.skills.get("sweeper_damage", 0)) == 1 and int(game.profile.skills.get("hunter_damage", 0)) == 1 and skills.chosen == "sweeper" and skills.points_left(game.profile.totals) == 0 and game.choose_tree("hunter") and game.profile.skill_tree == "hunter" and skills.spent() == 2
	game.reset_skills()
	var returned: bool = skills.ranks.is_empty() and skills.chosen == "" and game.profile.skills.is_empty() and game.profile.skill_tree == "" and skills.points_left(game.profile.totals) == 2
	game.profile.totals = career
	expect(learnt and returned, "Points are spent on the abilities of any tree (the first puts its tree in force), kept in the profile and taken back for nothing")
	# --- the endless night
	game.team_enabled = false
	game.profile.mode = "endless"
	game.start_run()
	var open: bool = game.endless and not game.story.enabled and game.mission.plan.size() == game.ROUNDS.size() and game.opening_note().begins_with("Endlosmodus")
	# The rounds past the tenth are planned as the night goes; here they are plain ones.
	while game.mission.plan.size() < 12:
		game.mission.plan.append(game.mission._plan_round(game.mission.plan.size(), MissionDirector.NO_END))
	game.mission.plain()
	game.wave = game.ROUNDS.size() + 1
	game.phase = "preparing"
	game.begin_wave()
	var twelfth: Dictionary = game.roster_of(12)
	var beyond: bool = game.wave == 12 and game.phase == "wave" and game.mission.plan.size() >= 12 and int(twelfth.mauler) == 22 and int(twelfth.crusher) == 1 and int(game.roster_of(11).crusher) == 0 and int(game.roster_of(20).crusher) == 2 and game.roster_of(3) == game.ROUNDS[2] and game.spawn_queue.size() >= 50 and game.mission.opening_cue() != "round_final"
	_wipe(game)
	game.boss = null
	game.complete_wave()
	game.hud._process(0.1)
	var goes_on: bool = game.state == "playing" and game.phase == "preparing" and game.hud.wave_label.text == "ENDLOS  ·  RUNDE 12"
	var late: Infected = game.spawn_enemy("mauler")
	var paced: bool = late.max_health > 150.0
	game.wave = 40
	var later: Infected = game.spawn_enemy("mauler")
	paced = paced and later.max_health > late.max_health * 2.0 and later.speed < (2.45 + 0.07 * 19) * 1.09
	game.wave = 12
	_wipe(game)
	var plain_before: int = game.profile.best(game.level).size()
	game.finish(false)
	var filed: bool = game.state == "lose" and game.profile.best(Profile.board(game.level, "endless")).size() == 1 and game.profile.best(game.level).size() == plain_before and int(game.profile.best(Profile.board(game.level, "endless"))[0].round) == 12 and game.last_gain.has("xp")
	game.profile.runs.erase(Profile.board(game.level, "endless"))
	game.profile.mode = "story"
	expect(open and beyond and goes_on and paced and filed, "The endless night has no story and no last round: the rounds grow on past the tenth, and the night is filed under a list of its own")
	# --- modifiers
	game.profile.modifiers = true
	game.start_run()
	game.mission.plain()
	game.phase = "preparing"
	game.begin_wave()
	var plain_first: bool = game.modifiers_on and game.modifier == "" and game.rules == Profile.DIFFICULTIES[game.level]
	_wipe(game)
	game.complete_wave()
	var seen := {}
	var fitting := true
	var twice := false
	var before := ""
	for i in range(7):
		game.phase = "preparing"
		game.begin_wave()
		seen[game.modifier] = true
		twice = twice or game.modifier == before
		before = game.modifier
		game.hud._process(0.1)
		fitting = fitting and game.modifier != "" and game.wave >= int(game.MODIFIERS[game.modifier].from) and game.hud.detail_label.text.begins_with("MODIFIKATION") and game.hud.task_label.text.contains(str(game.MODIFIERS[game.modifier].label)) and game.modifier_note() != "" and not game.modifier_note().contains("%s")
		_wipe(game)
		game.boss = null
		game.complete_wave()
		fitting = fitting and game.modifier == "" and game.rules == Profile.DIFFICULTIES[game.level]
	expect(plain_first and fitting and not twice and seen.size() >= 3 and game.wave == 8, "With modifiers on, every round after the first brings one and says so; none comes twice in a row, and the round's end takes it back (%s)" % str(seen.keys()))
	# What they do.
	var base: Dictionary = Profile.DIFFICULTIES[game.level]
	game._set_modifier("horde")
	var doubled: bool = is_equal_approx(float(game.rules.horde), 2.0 * float(base.horde)) and is_equal_approx(float(game.rules.harm), float(base.harm))
	game._set_modifier("tough")
	var brute: Infected = game.spawn_enemy("mauler")
	var hard: bool = is_equal_approx(brute.max_health, 1.5 * (95.0 + 7.0 * (game.wave - 1)))
	game._set_modifier("fast")
	var quick: bool = is_equal_approx(float(game.rules.pace), 1.22 * float(base.pace))
	game._set_modifier("pack", "ripper")
	var named: bool = game.modifier_note() == "Dreimal so viele Ripper wie sonst."
	game._set_modifier("loot")
	var purse: int = game.credits
	brute.receive_hit(99999.0, Vector3.FORWARD)
	var paid: bool = game.credits == purse + 2 * int(Infected.TYPES.mauler.reward)
	game._set_modifier("nonsense")
	expect(doubled and hard and quick and named and paid and game.modifier == "" and game.rules == base and game.MODIFIERS.size() == 9, "A modifier changes the rules of its round: a bigger horde, tougher or faster enemies, a pack of one kind, richer loot")
	game.profile.modifiers = false
	game.team_enabled = true
	game.start_run()

## What came with v0.15: one weapon of each kind (more with slings) and trading in, keys
## by kind, the syringe, ducking, a round's end that heals and resupplies, and one shield
## bearer at a time.
func _loadout(game: Node3D) -> void:
	var player: Survivor = game.player
	var spots: Dictionary = game.cabin.points
	var stand := Vector3(0, 0.05, 22.0)
	game.profile.mode = "story"
	game.profile.modifiers = false
	game.team_enabled = false
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	game.skills.reset()
	# --- three kinds of weapon
	var keyed := true
	var kinds := {}
	for id in Survivor.ORDER:
		var kind := Survivor.kind_of(id)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		keyed = keyed and int(Survivor.WEAPONS[id].slot) == int(Survivor.KINDS[kind].key)
	expect(keyed and int(kinds.primary) == 9 and int(kinds.secondary) == 2 and int(kinds.heavy) == 10 and Survivor.kind_of("flamer") == "heavy" and Survivor.kind_of("shotgun") == "primary" and Survivor.kind_of("revolver") == "secondary", "Every weapon is a primary, a secondary or a heavy one, and its key is the key of its kind")
	# --- one of each kind; a second one is traded for the first
	game.credits = 1000
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	# (The shop opens on the list it was left on.)
	game.hud.shop_tab = "weapons"
	game.interact()
	# The picture of the weapon that is picked as the shop opens: its camera stands where the
	# weapon fills the picture, although the shop was not laid out yet when it was picked.
	await frames(3)
	var shop_show: WeaponShow = game.hud.counter.stage
	expect(shop_show.shown == "rifle" and shop_show.is_visible_in_tree() and shop_show.size.x > 200.0 and shop_show.camera.position.length() > 0.5 and shop_show.camera.position.length() < 5.0, "The shop shows the picture of the first weapon of its list as it opens (its camera stands %.1f m from it)" % shop_show.camera.position.length())
	var first_cost: int = game.weapon_cost("ak")
	var swapped: bool = game.buy_weapon("ak") and player.inventory.has("ak") and not player.inventory.has("rifle") and player.current_weapon == "ak" and game.credits == 700
	var beside: bool = game.buy_weapon("pistol") and game.buy_weapon("sniper") and player.inventory.size() == 3 and game.credits == 700 - 60 - 450
	var offer: int = game.weapon_cost("p90")
	var goes: String = player.to_replace("p90")
	player.equip_weapon("sniper", true)
	var traded: bool = game.buy_weapon("p90") and not player.inventory.has("ak") and player.inventory.has("sniper") and player.current_weapon == "p90" and game.credits == 190 + 50
	# The carbine everybody starts with can be had back for nothing.
	game.hud._open_tab("weapons")
	var listed := false
	for node in game.hud.counter.row_buttons:
		listed = listed or ((node as Button).text == "M4A4" and str(game.hud.counter.weapon_state("rifle")[0]) == "KOSTENLOS")
	var back: bool = game.buy_weapon("rifle") and player.inventory.has("rifle") and not player.inventory.has("p90") and game.credits == 240 + 50
	expect(first_cost == 300 and swapped and beside and offer == 100 - 150 and goes == "ak" and traded and listed and back and game.trade_in("sniper") == 225 and game.trade_in("rifle") == 0, "A survivor carries one weapon of each kind: a second one takes the place of the first, which is traded in for half its price")
	# The keys.
	player._select_slot(2)
	var sidearm: String = player.current_weapon
	player._select_slot(3)
	var heavy: String = player.current_weapon
	player._select_slot(1)
	var primary: String = player.current_weapon
	player._select_slot(7)
	player._cycle(1)
	expect(sidearm == "pistol" and heavy == "sniper" and primary == "rifle" and player.current_weapon == "pistol", "Keys 1, 2 and 3 take the primary, the secondary and the heavy weapon in hand; the wheel goes through all of them")
	# --- slings make room
	game.credits = 2000
	var sling_price: int = game.item_price("sling")
	var roomy: bool = not player.room_for("ump") and game.buy_item("sling") and player.extra_slots == 1 and player.room_for("ump") and player.to_replace("ump") == ""
	var both: bool = game.buy_weapon("ump") and player.carried("primary") == ["rifle", "ump"] and game.credits == 2000 - 250 - 220
	# The one place more is taken: the next sidearm is traded again.
	var again: bool = not player.room_for("revolver") and game.weapon_cost("revolver") == 220 - 30 and game.buy_weapon("revolver") and not player.inventory.has("pistol") and player.inventory.size() == 4
	game.buy_item("sling")
	game.buy_item("sling")
	var full: bool = player.extra_slots == 3 and game.item_price("sling") == -1 and not game.buy_item("sling")
	game.resume_run()
	expect(sling_price == 250 and roomy and both and again and full, "A sling from the shop makes room for one more weapon of any kind, up to three of them")
	# A new night starts with the carbine alone, also after it was traded in.
	player.unlock("ak")
	player.drop_weapon("rifle")
	var gone: bool = not player.inventory.has("rifle") and player.current_weapon == "ak" and player.extra_slots == 3
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	await frames(3)
	expect(gone and player.current_weapon == "rifle" and player.inventory.size() == 1 and player.inventory.has("rifle") and player.extra_slots == 0 and player.ammo == 30, "A new night starts with the carbine alone and without slings, also after the carbine was traded in")
	# --- the syringe
	player.health = 40.0
	var given: bool = player.inject() and is_equal_approx(player.health, 70.0) and player.syringe_wait > 7.0
	game.hud._process(0.1)
	var counting: bool = (game.hud.tiles.syringe[1] as Label).text == "8"
	var waits: bool = not player.inject() and is_equal_approx(player.health, 70.0)
	player.syringe_wait = 0.0
	player.health = 90.0
	var capped: bool = player.inject() and is_equal_approx(player.health, 100.0)
	player.syringe_wait = 0.0
	var needless: bool = not player.inject() and player.syringe_wait == 0.0
	game.hud._process(0.1)
	expect(given and counting and waits and capped and needless and (game.hud.tiles.syringe[1] as Label).text == "+" and float(Survivor.SYRINGE_HEAL) == 30.0 and float(Survivor.SYRINGE_WAIT) >= 5.0, "The syringe on Q gives 30 health back, up to full health, and has to be made ready again for some seconds")
	# --- ducking
	face(game, stand, PI)
	await frames(3)
	var wall := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.05, 0.1)
	slab.shape = box
	wall.add_child(slab)
	game.add_child(wall)
	wall.global_position = stand + Vector3(0, 0.525, 0.45)
	var watcher := game.spawn_enemy("cru_assault") as CruSoldier
	watcher.set_physics_process(false)
	watcher.position = stand + Vector3(0, 0, 8.0)
	watcher.prey = player
	await frames(3)
	var seen_standing: bool = watcher._sight(player.global_position) and is_equal_approx(player.chest_height(), 1.15)
	player.set_crouched(true)
	await frames(30)
	var low: bool = player.crouched and is_equal_approx((player.body_shape.shape as CapsuleShape3D).height, Survivor.CROUCH_HEIGHT) and player.camera.position.y < 1.2 and player.chest_height() < 0.8
	var hidden: bool = not watcher._sight(player.global_position)
	# The burst he fires anyway goes into the wall.
	player.health = 100.0
	watcher.ammo = 30
	for i in range(12):
		watcher.rounds_left = 1
		watcher._fire(player.global_position, false)
	var covered: bool = player.health == 100.0
	player.set_crouched(false)
	await frames(30)
	var up: bool = not player.crouched and is_equal_approx((player.body_shape.shape as CapsuleShape3D).height, Survivor.STAND_HEIGHT) and player.camera.position.y > 1.5
	wall.queue_free()
	watcher.receive_hit(99999.0, Vector3.FORWARD)
	expect(seen_standing and low and hidden and covered and up, "Ducked, the survivor is lower: a soldier does not see him behind a wall a metre high, and what he fires goes into it")
	# --- a round's end heals and brings half the ammunition back
	game.credits = 500
	player.unlock("pistol")
	player.equip_weapon("rifle", true)
	player.health = 35.0
	player.reserve = 0
	player.inventory.pistol.reserve = 100
	game.phase = "preparing"
	game.begin_wave()
	_wipe(game)
	game.complete_wave()
	expect(is_equal_approx(player.health, 100.0) and player.reserve == 90 and int(player.inventory.pistol.reserve) == 120 and game.hud.detail_label.text.contains("halbe Munition") and float(game.ROUND_HEAL) == 100.0, "A round that is survived heals the survivor and brings half of each weapon's ammunition back")
	# --- one shield bearer at a time
	game.spawn_queue.clear()
	for i in range(3):
		game.spawn_queue.append("cru_shield")
	var came: Array = []
	var bearer: Infected = null
	for i in range(3):
		var soldier: Infected = game.spawn_enemy()
		soldier.set_physics_process(false)
		came.append(soldier.kind)
		if soldier.kind == "cru_shield":
			bearer = soldier
	bearer.receive_hit(99999.0, Vector3.FORWARD)
	bearer.receive_hit(99999.0, Vector3.BACK)
	game.blasting = true
	bearer.receive_hit(99999.0, Vector3.FORWARD)
	game.blasting = false
	game.spawn_queue.append("cru_shield")
	var next: Infected = game.spawn_enemy()
	next.set_physics_process(false)
	var forced: Infected = game.spawn_enemy("cru_shield")
	forced.set_physics_process(false)
	expect(came == ["cru_shield", "cru_assault", "cru_assault"] and bearer.dead and next.kind == "cru_shield" and forced.kind == "cru_shield" and MissionDirector.SQUAD_ORDER.count("cru_shield") == 1 and not MissionDirector.REINFORCEMENTS.has("cru_shield") and int(game.SHIELD_LIMIT) == 1, "Only one shield bearer stands in the yard at a time: while he does, the next one comes without a shield")
	_wipe(game)
	# --- the G36
	game.preparation_left = 9999.0
	game.credits = 2000
	player.extra_slots = 1
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	var got: bool = game.buy_weapon("g36") and player.current_weapon == "g36" and player.inventory.has("rifle") and game.credits == 2000 - 450 and player.ammo == 30 and player.max_reserve() == 240
	var g36: Node3D = player.weapon
	var g36_gun: Dictionary = WeaponView.GUNS.g36
	var g36_view: Dictionary = WeaponView.VIEWS.g36
	# Aimed, the line over rear and front sight goes through the middle of the picture.
	var on_line: bool = is_equal_approx((g36_view.aim as Vector3).y, -((g36_gun.mount as Vector3).y + float(g36_gun.irons))) and (g36_view.aim as Vector3).x == 0.0 and (g36_view.muzzle as Vector3).is_equal_approx((g36_gun.mount as Vector3) + (g36_gun.muzzle as Vector3))
	var plain_sound: String = str(player.gun().sound)
	var heard_g36 := true
	for kind in ["g36", "g36_sil", "g36_mag_out", "g36_mag_in", "g36_bolt"]:
		heard_g36 = heard_g36 and bool(game.sounds.recorded.get(kind, false))
	var sighted: bool = game.buy_part("g36", "reddot") and (g36.get_node("Mod_reddot") as Node3D).visible and game.buy_part("g36", "scope") and (g36.get_node("Mod_scope") as Node3D).visible and not (g36.get_node("Mod_reddot") as Node3D).visible and player.gun().has("scope")
	var hushed: bool = game.buy_part("g36", "silencer") and (g36.get_node("Mod_silencer") as Node3D).visible and str(player.gun().sound) == "g36_sil" and bool(player.gun().quiet) and game.credits == 2000 - 450 - 120 - 260 - 180
	# Every suppressed shot is known as one, also when a co-op guest fires it.
	for id in Survivor.ATTACHMENTS:
		for part in Survivor.ATTACHMENTS[id]:
			var changed: Dictionary = Survivor.ATTACHMENTS[id][part].get("set", {})
			if changed.get("quiet", false):
				hushed = hushed and Survivor.QUIET_SOUNDS.has(str(changed.sound)) and game.sounds.clips.has(str(changed.sound))
	# The list of parts: only for the two rifles that are carried.
	game.hud._open_tab("mods")
	var dots := 0
	for node in game.hud.counter.row_buttons:
		if (node as Button).text.begins_with("ROTPUNKTVISIER"):
			dots += 1
	game.resume_run()
	# The reload: the magazine leaves the weapon and comes back, with sounds of its own.
	player.ammo = 5
	player.start_reload()
	var clip := g36.get_node_or_null("Magazine") as Node3D
	var left_well := 0.0
	for i in range(int(float(Survivor.WEAPONS.g36.reload_time) * 60.0) + 20):
		await get_tree().physics_frame
		if clip != null:
			left_well = maxf(left_well, clip.position.length())
	var cued := true
	for cue in Survivor.WEAPONS.g36.cues:
		cued = cued and str(cue[1]).begins_with("g36_")
	expect(got and on_line and plain_sound == "g36" and heard_g36 and sighted and hushed and dots == 2 and Survivor.ATTACHMENTS.size() == 5 and clip != null and g36.get_node_or_null("Support") != null and left_well > 0.15 and clip.position.length() < 0.001 and player.ammo == 30 and cued and Survivor.kind_of("g36") == "primary" and float(Survivor.WEAPONS.g36.damage) > float(Survivor.WEAPONS.rifle.damage) and float(Survivor.WEAPONS.g36.interval) < float(Survivor.WEAPONS.rifle.interval), "The G36 is a primary weapon with its own shot and reload, a magazine that leaves the gun, a sight line through the middle of the picture and three parts; the list of parts shows only those for what is carried")
	_wipe(game)
	# --- the MP7: its magazine comes out of the pistol grip, and it has no iron sights
	game.preparation_left = 9999.0
	game.credits = 2000
	player.extra_slots = 1
	player.inventory = {"rifle": {"ammo": 30, "reserve": 180, "level": 0}}
	player.equip_weapon("rifle", true)
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	var mp7_got: bool = game.buy_weapon("mp7") and player.current_weapon == "mp7" and player.inventory.has("rifle") and game.credits == 2000 - 280 and player.ammo == 30 and player.max_reserve() == 240
	var mp7: Node3D = player.weapon
	var mp7_gun: Dictionary = WeaponView.GUNS.mp7
	var mp7_view: Dictionary = WeaponView.VIEWS.mp7
	# Aimed, the eye looks along the top of the rail, just above it.
	var mp7_rail: bool = float(mp7_gun.irons) == float(mp7_gun.rail) and (mp7_view.aim as Vector3).y < -((mp7_gun.mount as Vector3).y + float(mp7_gun.rail)) and (mp7_view.aim as Vector3).x == 0.0 and (mp7_view.muzzle as Vector3).is_equal_approx((mp7_gun.mount as Vector3) + (mp7_gun.muzzle as Vector3))
	# The magazine goes straight down out of the grip.
	var mp7_way: Vector3 = WeaponView.reload_step("mp7", 0.38).magazine
	var mp7_down: bool = mp7_way.y < -0.15 and absf(mp7_way.x) < 0.01 and str(mp7_gun.hands) == "grip"
	var mp7_plain: String = str(player.gun().sound)
	# Its three parts: the sights take each other's place on the rail, the suppressor has a
	# shot of its own, which a co-op partner's machine knows as a quiet one.
	var mp7_dot: bool = game.buy_part("mp7", "reddot") and (mp7.get_node("Mod_reddot") as Node3D).visible and player.fitted("sight") == "reddot"
	var mp7_scoped: bool = game.buy_part("mp7", "scope") and (mp7.get_node("Mod_scope") as Node3D).visible and not (mp7.get_node("Mod_reddot") as Node3D).visible and player.gun().has("scope")
	var mp7_hushed: bool = game.buy_part("mp7", "silencer") and (mp7.get_node("Mod_silencer") as Node3D).visible and str(player.gun().sound) == "mp7_sil" and bool(player.gun().quiet) and Survivor.QUIET_SOUNDS.has("mp7_sil") and game.credits == 2000 - 280 - 120 - 260 - 180
	# The list of parts names it, with those of the carbine that is carried beside it.
	game.hud._open_tab("mods")
	var mp7_listed := 0
	for node in game.hud.counter.row_buttons:
		if (node as Button).text.begins_with("SCHALLDÄMPFER"):
			mp7_listed += 1
	var mp7_heard: bool = mp7_plain == "mp7" and bool(game.sounds.recorded.get("mp7", false)) and bool(game.sounds.recorded.get("mp7_sil", false)) and FieldAudio.MIX.has("mp7") and FieldAudio.MIX.has("mp7_sil")
	game.resume_run()
	player.ammo = 3
	player.start_reload()
	var mp7_clip := mp7.get_node_or_null("Magazine") as Node3D
	var mp7_out := 0.0
	for i in range(int(float(Survivor.WEAPONS.mp7.reload_time) * 60.0) + 20):
		await get_tree().physics_frame
		if mp7_clip != null:
			mp7_out = maxf(mp7_out, mp7_clip.position.length())
	expect(mp7_got and mp7_rail and mp7_down and mp7_dot and mp7_scoped and mp7_hushed and mp7_listed == 2 and mp7_heard and mp7_clip != null and mp7.get_node_or_null("Support") != null and mp7_out > 0.12 and mp7_clip.position.length() < 0.001 and player.ammo == 30 and Survivor.kind_of("mp7") == "primary" and str(Survivor.WEAPONS.mp7.label) == "MP7" and Survivor.ORDER.find("mp7") == Survivor.ORDER.find("ump") + 1 and float(Survivor.WEAPONS.mp7.interval) < float(Survivor.WEAPONS.p90.interval) and SurvivalHUD.SHOP_NOTES.has("mp7"), "The MP7 is a quick primary weapon whose magazine comes out of its pistol grip; it has no iron sights and is aimed along its rail or through a fitted sight, and takes a suppressor with a shot of its own")
	_wipe(game)
	# --- the keys
	var bound := {}
	for action in ["syringe", "melee", "crouch", "flashlight", "squad_follow", "squad_free", "squad_hold"]:
		var codes: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				codes.append((event as InputEventKey).physical_keycode)
		bound[action] = codes
	expect(bound.syringe == [KEY_Q] and bound.melee == [KEY_V] and bound.crouch == [KEY_C] and bound.flashlight == [KEY_F] and bound.squad_follow == [KEY_5] and bound.squad_free == [KEY_6] and bound.squad_hold == [KEY_X, KEY_4], "Q is the syringe, V the blow, C ducks; the orders for the squad lie on 4, 5 and 6 (and X still holds)")
	game.team_enabled = true
	game.start_run()

## What came with v0.10: the AK-47 and its parts, the C.R.U. Elite and his gas, grenades
## that are readied and aimed before they fly, music that follows the night, the settings
## and the readouts of the new interface.
func _later(game: Node3D) -> void:
	var player: Survivor = game.player
	var mission: MissionDirector = game.mission
	game.team_enabled = false
	game.start_run()
	mission.plain()
	game.preparation_left = 9999.0
	game.credits = 3000
	# --- the AK-47, bought at the shop
	player.extra_slots = 1
	player.position = (game.cabin.points.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	var bought: bool = game.buy_weapon("ak")
	var view: Node3D = player.weapon
	expect(bought and game.credits == 2700 and player.current_weapon == "ak" and int(Survivor.WEAPONS.ak.slot) == int(Survivor.WEAPONS.rifle.slot) and view.get_node_or_null("Magazine") != null and view.get_node_or_null("Support") != null and not (view.get_node("Mod_reddot") as Node3D).visible and float(Survivor.WEAPONS.ak.damage) > float(Survivor.WEAPONS.rifle.damage), "The AK-47 is a rifle of its own on the carbine's key: it hits harder, and its magazine leaves the gun")
	var purse: int = game.credits
	var glass: Vector3 = WeaponView.sight_aim("ak", "reddot")
	expect(game.buy_part("ak", "reddot") and player.fitted("sight") == "reddot" and (view.get_node("Mod_reddot") as Node3D).visible and game.credits == purse - 120 and float(player.gun().zoom) == 40.0 and glass.y < (WeaponView.VIEWS.ak.aim as Vector3).y - 0.003 and glass.z > -0.2 and (WeaponView.reload_step("ak", 0.38).magazine as Vector3).length() > 0.2, "The AK-47 takes parts like the UMP; through the reflex sight the eye is above the iron sights and close to the glass")
	game.resume_run()
	face(game, Vector3(0, 0.05, 22.0), PI)
	# --- the C.R.U. Elite
	var elite := game.spawn_enemy("cru_elite") as CruSoldier
	elite.set_physics_process(false)
	elite.position = Vector3(3.0, 0.05, 34.0)
	var grunt := game.spawn_enemy("cru_assault") as CruSoldier
	grunt.set_physics_process(false)
	grunt.position = Vector3(-3.0, 0.05, 34.0)
	await frames(2)
	expect(str(elite.spec.role) == "elite" and elite.max_health > grunt.max_health and float(elite.role.damage) > float(grunt.role.damage) and float(elite.role.armour) < float(grunt.role.armour) and elite.grenades == 2 and str(elite.body.soldier.config.weapon) == "ak" and elite.body.find_child("Lenses", true, false) != null and mission.squad(9.0).has("cru_elite"), "The C.R.U. Elite is tougher and hits harder than an ordinary soldier, carries an AK-47 and wears a mask whose lenses glow")
	var clouds: int = game.gas.pockets.size()
	elite.throw_grenade(player.global_position + Vector3(0, 0, 3.0), 12.0, true)
	await wait(0.7)
	var canister: Throwable = null
	for node in game.ordnance.get_children():
		if node is Throwable and str(node.kind) == "gas":
			canister = node
	var thrown: bool = canister != null and canister.hostile and elite.grenades == 1
	if canister != null:
		canister.fuse = 0.0
	await frames(4)
	var cloud: Dictionary = game.gas.pockets[game.gas.pockets.size() - 1] if game.gas.pockets.size() > clouds else {}
	var spreads := false
	if not cloud.is_empty():
		cloud.strength = 1.0
		var middle: Vector3 = cloud.pos
		spreads = bool(cloud.indoors) and bool(cloud.thrown) and float(cloud.radius) < GasField.POCKET_RADIUS and game.gas.toxic_at(middle + Vector3(1.0, 0.1, 0)) and not game.gas.toxic_at(middle + Vector3(6.0, 0.1, 0))
	expect(thrown and spreads, "The Elite throws gas grenades: where one comes to rest, a small cloud spreads that fills a room as well")
	game.gas.clear()
	for foe in [elite, grunt]:
		foe.receive_hit(99999.0, Vector3.BACK)
	# --- a grenade is readied, aimed and thrown
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.health = 100.0
	player.items.grenade = 2
	player.throw_cooldown = 0.0
	var rounds: int = player.ammo
	Input.action_press("throw_grenade")
	player.ready_throw("grenade")
	await wait(0.45)
	player.shoot()
	var path: PackedVector3Array = player.throw_path("grenade")
	var held: bool = player.throw_kind == "grenade" and int(player.items.grenade) == 2 and player.throw_pose > 0.5 and path.size() > 8 and game.fx.arc_dots != null and game.fx.arc_dots.visible and player.ammo == rounds
	Input.action_release("throw_grenade")
	await wait(0.45)
	var flying := false
	for node in game.ordnance.get_children():
		if node is Throwable and str(node.kind) == "grenade" and not node.hostile:
			flying = true
			node.queue_free()
	expect(held and flying and player.throw_kind == "" and int(player.items.grenade) == 1 and not game.fx.arc_dots.visible, "A grenade is taken in the hand, its flight is shown while the key is held, and it is thrown when the key is let go")
	# --- music that follows the night
	var music: MusicDirector = game.music
	var parts := 0
	for key in MusicDirector.PHASES:
		if not music.tracks_for(key).is_empty():
			parts += 1
	var heard: Array = []
	for step in [["preparing", 2], ["wave", 2], ["wave", 6], ["wave", game.ROUNDS.size() - 1], ["wave", game.ROUNDS.size()]]:
		game.phase = str(step[0])
		game.wave = int(step[1])
		heard.append(music.current_phase())
	game.phase = "preparing"
	game.wave = 1
	expect(parts == MusicDirector.PHASES.size() and heard == ["anfang", "welle", "harte_welle", "kurz_vor_ende", "letzte_runde"], "The music follows the night: calm between the rounds, harder as they go on, tracks of its own for the last one (%s)" % str(heard))
	# --- settings and readouts
	game.sounds.set_volume("Music", 0.25)
	var quarter: bool = absf(game.sounds.volume("Music") - 0.25) < 0.01
	game.sounds.set_volume("Music", 0.0)
	var silent: bool = game.sounds.volume("Music") == 0.0
	game.sounds.set_volume("Music", float(FieldAudio.VOLUMES.Music))
	game.hud.show_menu("settings")
	var sliders: int = game.hud.modal.find_children("*", "HSlider", true, false).size()
	game.hud.hide_menu()
	expect(quarter and silent and sliders == 5 and AudioServer.get_bus_index("Voice") > 0 and AudioServer.get_bus_send(AudioServer.get_bus_index("Field")) == &"SFX", "Everything, the music, the effects and the voices can be turned up and down on their own")
	# Every menu and every list of the shop can be built.
	var built := 0
	for mode in ["main", "pause", "win", "lose", "settings", "host", "join", "board", "skins", "skills"]:
		game.hud.show_menu(mode)
		if game.hud.current_menu == mode and game.hud.modal.find_children("*", "Button", true, false).size() > 0:
			built += 1
	for tab in SurvivalHUD.SHOP_TABS:
		game.hud._open_tab(str(tab[0]))
		if game.hud.shop_tab == str(tab[0]) and game.hud.modal.find_children("*", "ScrollContainer", true, false).size() == 1:
			built += 1
	game.hud.hide_menu()
	expect(built == 10 + SurvivalHUD.SHOP_TABS.size(), "Every menu and every list of the shop can be opened (%d)" % built)
	game.hud._process(0.1)
	var tile: Array = game.hud.tiles.grenade
	game.hud.loadout()
	expect((tile[1] as Label).text == "1" and game.hud.loadout_box.get_child_count() >= 2 and game.hud.loadout_left > 0.0, "What is in the pockets shows as tiles beside the weapon, and changing weapons lists what is carried")
	# --- the Prowler, the four-legged hunter of mission two
	game.start_run()
	mission.plain()
	game.preparation_left = 9999.0
	face(game, Vector3(0, 0.05, 22.0), PI)
	var prowl_count: int = game.alive_count
	var prowl_a := game.spawn_enemy("prowler") as Prowler
	prowl_a.position = Vector3(0, 0.08, 34.0)
	var prowl_body := prowl_a.model as ProwlerVisual
	var prowl_clips := 0
	for prowl_clip in ["idle", "stalk", "trot", "run", "leap", "slash_l", "slash_r", "slam", "bite", "flinch", "stagger", "roar", "death"]:
		if prowl_body != null and prowl_body.player.has_animation(prowl_clip):
			prowl_clips += 1
	expect(prowl_body != null and prowl_clips == 13 and prowl_a.flanks.size() == 2 and float(prowl_a.spec.radius) <= float(Infected.TYPES.crusher.radius) and game.boss == prowl_a and prowl_a.gauge() == Vector2(prowl_a.max_health, prowl_a.max_health) and game.fx.get_script() != null, "The Prowler brings its own body with thirteen clips, is no wider than a Crusher (the doors), can be hit at shoulders and haunches too, and has the bar on the HUD")
	var prowl_top := 0.0
	var prowl_modes := {}
	for prowl_step in range(840):
		await get_tree().physics_frame
		player.health = 100.0
		prowl_modes[prowl_a.mode] = true
		var prowl_run: Vector3 = prowl_a.get_real_velocity()
		prowl_top = maxf(prowl_top, Vector2(prowl_run.x, prowl_run.z).length())
		if prowl_a.landed >= 1 and prowl_modes.has("circle") and prowl_modes.has("back"):
			break
	expect(prowl_top > 7.5 and prowl_modes.has("circle") and prowl_modes.has("back") and (prowl_modes.has("strike") or prowl_modes.has("leap")) and prowl_a.landed >= 1, "It comes in at a gallop, goes round its prey, attacks and springs back out of reach (top %.1f m/s, %d landed)" % [prowl_top, prowl_a.landed])
	# A visit: it cannot die, a blast knocks it off its feet, and it breaks off when it has had enough.
	prowl_a.leap = ""
	prowl_a.mode = "circle"
	prowl_a.attack_clock = -1.0
	prowl_a.stagger_cooldown = 0.0
	prowl_a.held_left = 0.0
	prowl_a.nerve = 300.0
	prowl_a.driven = 0.0
	var prowl_health: float = prowl_a.health
	prowl_a.receive_hit(120.0, Vector3.BACK, false)
	var prowl_reeled: bool = prowl_a.mode == "reel" and prowl_a.held_left > 0.2
	var prowl_bar: Vector2 = prowl_a.gauge()
	prowl_a.receive_hit(100.0, Vector3.BACK, true)
	prowl_a.receive_hit(100.0, Vector3.BACK, false)
	var prowl_left: bool = prowl_a.leaving and prowl_a.broke_hurt and not prowl_a.dead and prowl_a.health == prowl_health and not prowl_a.is_targetable() and game.boss != prowl_a
	prowl_a.receive_hit(99999.0, Vector3.BACK, false)
	prowl_left = prowl_left and not prowl_a.dead
	var prowl_gone := false
	for prowl_step in range(600):
		await get_tree().physics_frame
		if not is_instance_valid(prowl_a):
			prowl_gone = true
			break
	expect(prowl_reeled and prowl_bar == Vector2(180.0, 300.0) and prowl_left and prowl_gone and game.alive_count == prowl_count, "On a visit a blast knocks it off its feet, the bar shows what it still takes, and when that is gone it breaks off unhurt, runs and is gone")
	# The last fight: enraged, and now it dies.
	var prowl_b := game.spawn_enemy("prowler") as Prowler
	prowl_b.position = Vector3(0, 0.08, 31.0)
	prowl_b.max_health = HiveProwler.end_health(2)
	prowl_b.health = prowl_b.max_health
	prowl_b.enrage()
	var prowl_rage: bool = prowl_b.enraged and prowl_b.mode == "reel" and prowl_b.held_left > 1.0 and (prowl_b.model as ProwlerVisual).glow != null and prowl_b.nerve == 0.0
	var prowl_purse: int = game.credits
	prowl_b.receive_hit(prowl_b.max_health - 10.0, Vector3.BACK, false)
	var prowl_stands: bool = not prowl_b.dead and prowl_b.gauge().x == 10.0
	prowl_b.flanks[0].receive_hit(50.0, Vector3.BACK, false)
	expect(prowl_rage and prowl_stands and prowl_b.dead and prowl_b.flanks[0].dead and game.credits > prowl_purse and game.alive_count == prowl_count and game.boss == null, "Enraged it roars and glows, its bar is its health, and a hit on its flank is a hit on it: it can be killed, and that pays")
	var prowl_never := true
	for prowl_stage in ["landing", "villa", "mirror", "descent", "station", "nadja", "deal", "power", "hold", "board", "ride", "terminal", "lockdown", "decon", "exit"]:
		prowl_never = prowl_never and not HiveProwler.comes_in(prowl_stage, 99.0)
	var prowl_comes := true
	for prowl_stage in ["admin", "security", "cafe", "atrium", "generator", "labs"]:
		prowl_comes = prowl_comes and HiveProwler.comes_in(prowl_stage, 99.0) and not HiveProwler.comes_in(prowl_stage, 3.0)
	expect(prowl_never and prowl_comes and not HiveProwler.comes_in("hall", 99.0) and HiveProwler.nerve_on(3) > HiveProwler.nerve_on(0) and HiveProwler.stay_on(9) == HiveProwler.stay_on(HiveProwler.BOLD_MOST) and HiveProwler.end_health(2) < HiveProwler.end_health(0) and HiveProwler.end_health(99) == HiveProwler.end_health(HiveProwler.WEAR_MOST) and game.hive.prowl != null and HiveDirector.ORDER.find(HiveProwler.FIRST_STAGE) > HiveDirector.ORDER.find("ride"), "In mission two it comes from the administration on and not during the hold in the canteen, the lock or the first seconds of a stage, takes more with every visit, and comes to the last fight weakened if it was driven off by force")
	# --- where it has room: the map of mission two
	var prowl_mission: int = game.profile.mission
	var prowl_skipped: bool = game.intro_skipped
	game.profile.mission = 2
	game.intro_skipped = true
	game.hive.resume_at = "labs"
	game.start_run()
	await frames(3)
	var prowl_dir: HiveProwler = game.hive.prowl
	var prowl_wide: Vector3 = game.hive._point("junction")
	var prowl_tight: Vector3 = game.hive._point("control")
	expect(prowl_dir.open_ground(prowl_wide) >= HiveProwler.ROOM_MIN and prowl_dir.open_ground(game.hive._point("hall_end")) >= HiveProwler.ROOM_MIN and prowl_dir.open_ground(game.hive._point("cafeteria")) >= HiveProwler.ROOM_MIN and prowl_dir.open_ground(prowl_tight) < HiveProwler.ROOM_STAY and prowl_dir.open_ground(game.hive._point("car_a")) < HiveProwler.ROOM_STAY and prowl_dir.width_of(prowl_wide) >= 6.0 and not prowl_dir.may_follow(prowl_wide, prowl_tight) and not prowl_dir.wide_way(prowl_wide, game.hive._point("car_a")), "The ring, the canteen and the hall are ground it comes to (%d m2 at the junction); the control room and a carriage are not (%d m2), and no wide way leads into them" % [int(prowl_dir.open_ground(prowl_wide)), int(prowl_dir.open_ground(prowl_tight))])
	# In something tight no call comes; in the open it does, and the first time it shows itself.
	face(game, prowl_tight + Vector3(0, 0.05, 0), 0.0)
	prowl_dir.wait_left = 0.0
	for prowl_step in range(150):
		await get_tree().physics_frame
		game.hive.stage_time = 30.0
		player.health = 100.0
	var prowl_quiet: bool = not prowl_dir.visiting and prowl_dir.call_left < 0.0
	prowl_dir.visits = 0
	prowl_dir.shown = false
	face(game, prowl_wide + Vector3(0, 0.05, 0), 0.0)
	for prowl_step in range(600):
		await get_tree().physics_frame
		game.hive.stage_time = 30.0
		player.health = 100.0
		if prowl_dir.visiting:
			break
	var prowl_c: Prowler = prowl_dir.beast
	var prowl_came: bool = prowl_dir.visiting and is_instance_valid(prowl_c) and prowl_c.herald and prowl_c.roomy.is_valid() and prowl_dir.wide_way(prowl_c.global_position, prowl_wide)
	# The squad withdraws into something tight: it does not follow, waits, and goes - undriven.
	var prowl_lurks := false
	var prowl_near := 99.0
	if prowl_came:
		face(game, prowl_tight + Vector3(0, 0.05, 0), 0.0)
		for prowl_step in range(900):
			await get_tree().physics_frame
			game.hive.stage_time = 30.0
			player.health = 100.0
			if not is_instance_valid(prowl_c) or prowl_c.leaving:
				break
			prowl_c.prey = player
			prowl_lurks = prowl_lurks or prowl_c.mode == "lurk"
			prowl_near = minf(prowl_near, prowl_c.global_position.distance_to(player.global_position))
	expect(prowl_quiet and prowl_came and prowl_lurks and prowl_near > 6.0 and (not is_instance_valid(prowl_c) or (prowl_c.leaving and not prowl_c.broke_hurt)) and prowl_dir.wounds == 0, "It does not come to a squad in a tight place; it comes to one in the open, and when they withdraw into something tight it waits outside and goes without having been driven off (never nearer than %.0f m)" % prowl_near)
	game.return_to_menu()
	game.profile.mission = prowl_mission
	game.intro_skipped = prowl_skipped
	game.team_enabled = true
	game.start_run()

## What came with v0.9: the Medic and its cloud, the C.R.U. shield bearer, a Crusher before
## the last round, gas that comes and goes, errands upstairs, a blast worth the name.
func _threats(game: Node3D) -> void:
	var cabin: CabinMap = game.cabin
	var spots: Dictionary = cabin.points
	var player: Survivor = game.player
	var mission: MissionDirector = game.mission
	game.team_enabled = false
	game.start_run()
	mission.plain()
	game.preparation_left = 9999.0
	# --- the Medic
	face(game, Vector3(0, 0.05, 22.0), PI)
	var medic: Infected = game.spawn_enemy("healer")
	medic.position = Vector3(0, 0.05, 29.5)
	var hurt: Infected = game.spawn_enemy("mauler")
	hurt.position = medic.wisp_position(1)
	hurt.health = 40.0
	hurt.alert = false
	var far: Infected = game.spawn_enemy("mauler")
	far.set_physics_process(false)
	far.position = medic.position + Vector3(12.0, 0, 3.0)
	far.health = 40.0
	await wait(1.2)
	expect(medic.cloud != null and medic.cloud.get_child_count() == Infected.WISPS.size() and hurt.health > 44.0 and hurt.warded > 0.0 and hurt.model.buffed and far.health == 40.0 and far.warded <= 0.0 and not far.model.buffed and hurt.get_collision_exceptions().has(medic), "A Medic's gas strengthens every infected it touches, and nobody else: it mends, one sees it, and nobody gets stuck behind the Medic")
	hurt.set_physics_process(false)
	var mended := hurt.health
	hurt.receive_hit(20.0, Vector3.FORWARD)
	expect(is_equal_approx(mended - hurt.health, 20.0 * Infected.CLOUD_WARD) and medic.global_position.distance_to(player.global_position) > 6.5, "Whoever the gas has strengthened takes less harm, and the Medic itself keeps back")
	var beside_medic := medic.wisp_position(3)
	expect(game.toxic_at(beside_medic) and not game.toxic_at(medic.global_position + Vector3(-9.0, 0, 0)) and player.health == 100.0, "The gas poisons the air for survivors inside it")
	# Away from the gas the strength lasts a while and then wears off.
	hurt.set_physics_process(true)
	hurt.position = medic.position + Vector3(14.0, 0, -4.0)
	hurt.warded = 0.4
	await wait(0.7)
	expect(hurt.warded <= 0.0 and not hurt.model.buffed, "Out of the gas the strength wears off again")
	hurt.set_physics_process(false)
	medic.receive_hit(9999.0, Vector3.FORWARD)
	await frames(3)
	expect(medic.dead and medic.cloud == null and not game.toxic_at(beside_medic), "With the Medic dead its gas lifts")
	for foe in [hurt, far]:
		foe.receive_hit(9999.0, Vector3.FORWARD)
	# --- the shield bearer
	var bearer := game.spawn_enemy("cru_shield") as CruSoldier
	bearer.set_physics_process(false)
	bearer.position = Vector3(0, 0.05, 28.0)
	bearer.model.rotation.y = 0.0
	await frames(2)
	var full := bearer.health
	bearer.receive_hit(60.0, Vector3.BACK)
	var after_front := bearer.health
	bearer.receive_hit(60.0, Vector3.RIGHT)
	var after_side := bearer.health
	expect(after_front == full and after_side < full and bearer.blocks(Vector3.BACK) and not bearer.blocks(Vector3.FORWARD) and (bearer.model as CruVisual).shield != null, "A shield stops what comes from the front, and nothing else")
	game.explode(bearer.position + Vector3(0, 0.5, -2.0), 5.0, 0.0, 100.0, "blast")
	expect(bearer.health < after_side and not game.blasting and player.health == 100.0, "A blast goes round the shield")
	# He comes round slowly: whoever runs past him has his back for a while.
	bearer.set_physics_process(true)
	face(game, Vector3(0, 0.05, 34.0), 0.0)
	var yaw_before: float = bearer.model.rotation.y
	await wait(1.0)
	var turned := absf(angle_difference(yaw_before, bearer.model.rotation.y))
	expect(turned > 0.4 and turned < 1.3 and not bearer.blocks((bearer.global_position - player.global_position).normalized()), "The shield bearer turns slowly: a second after being passed his back is still open (%.2f rad)" % turned)
	var behind: Vector3 = bearer.facing()
	bearer.receive_hit(9999.0, behind)
	expect(bearer.dead and MissionDirector.SQUAD_ORDER[1] == "cru_shield", "Shot in the back he falls; every squad of the C.R.U. brings one")
	# --- the Crusher before the last round
	game.wave = 5
	game.begin_wave()
	var early: bool = game.spawn_queue.has("crusher")
	var medics: int = game.spawn_queue.count("healer")
	game.spawn_queue.clear()
	game.wave = 5
	mission.plan[5] = {"wave": "cru", "tasks": []}
	game.begin_wave()
	expect(early and medics == 1 and not game.spawn_queue.has("crusher"), "A Crusher and a Medic come in round six, but no Crusher into a round of the C.R.U.")
	game.spawn_queue.clear()
	mission.wave_kind = "classic"
	game.phase = "preparing"
	game.preparation_left = 9999.0
	game.gas.clear()
	# --- gas that comes and goes
	expect(GasField.pockets_for(1) == 0 and GasField.pockets_for(2) == 1 and GasField.pockets_for(3) == 2 and GasField.pockets_for(5) == 2 and GasField.pockets_for(8) == 3, "Banks of gas come with the rounds")
	var where: Vector3 = (spots.yard_south as Vector3) + Vector3(5.0, 0, 6.0)
	var pocket: Dictionary = game.gas._add(where, 60.0, 1.0)
	expect(game.gas.toxic_at(where + Vector3(2.0, 0.05, 0)) and game.toxic_at(where) and not game.gas.toxic_at(where + Vector3(9.5, 0, 0)) and not game.gas.toxic_at(where + Vector3(0, 3.4, 0)) and (mission.export_state()[2] as Array).size() == 3 and (game.gas.export_state()[1] as Array).size() == 1, "A pocket of gas poisons the yard where it lies, and the other player is told")
	face(game, where + Vector3(1.0, 0.05, 0), 0.0)
	player.health = 100.0
	player.mask_level = 0
	player.filter_left = 0.0
	await wait(4.6)
	expect(player.health < 100.0 and str(game.interaction_prompt()).contains("Raus aus dem Gas"), "Without a mask the pocket hurts after a few breaths")
	player.health = 100.0
	player.mask_level = 2
	player.filter_left = player.filter_capacity()
	await wait(2.0)
	expect(player.health == 100.0 and player.filter_left < player.filter_capacity() - 1.0, "A gas mask keeps its wearer safe while the filter lasts")
	pocket.going = true
	pocket.strength = 0.01
	# Long enough for the last of it to go whatever the frame rate is.
	await wait(0.3)
	expect(game.gas.pockets.is_empty() and not game.toxic_at(where), "A pocket thins out and is gone")
	player.mask_level = 0
	player.filter_left = 0.0
	game.gas._set_flood("on", 30.0)
	game.gas.flood_strength = 1.0
	face(game, (spots.hall as Vector3) + Vector3(0, 0.05, 0), 0.0)
	await frames(6)
	expect(game.toxic_at(player.global_position) and not game.toxic_at(spots.gallery) and not game.toxic_at((spots.barn as Vector3) + Vector3(0, 0.1, 0)) and not game.toxic_at(spots.lab) and str(game.interaction_prompt()).contains("Nach oben"), "Gas on the ground floor leaves the upper floor, the cellar and the outbuildings clear")
	game.gas.end_round()
	await wait(1.8)
	expect(game.gas.flood_state == "" and not game.toxic_at(player.global_position), "When the round is over the gas goes")
	cabin.lock_all()
	var planned := false
	for i in range(30):
		game.gas.begin_round(8)
		planned = planned or game.gas.flood_wait > 0.0
	var barred := planned
	cabin.unlock("upper", true)
	for i in range(40):
		game.gas.begin_round(8)
		planned = planned or game.gas.flood_wait > 0.0
	expect(not barred and planned and game.gas.wanted == 3, "The gas alarm in the house only comes once the upper floor is open")
	game.gas.clear()
	# --- the dead lie on the farm all night
	mission.clear()
	mission._lay_bodies()
	mission._sync_props()
	var lying: int = mission.bodies.size()
	var all_there: bool = mission.body_props.size() == lying
	var loot: Dictionary = mission._start_task("codes")
	var on_the_dead := true
	for item in loot.items:
		var found := false
		for body in mission.bodies:
			if (body.pos as Vector3).is_equal_approx(item.pos) and body.codes:
				found = true
		on_the_dead = on_the_dead and found
	var told: Array = mission.export_state()[2]
	mission._drop_tasks()
	mission._sync_props()
	expect(lying == MissionDirector.BODY_COUNT and all_there and on_the_dead and told.size() == 3 and (told[2] as Array).size() == lying and mission.bodies.size() == lying and mission.body_props.size() == lying and is_instance_valid(mission.body_props[0]), "The dead scientists lie on the farm all night: an errand sends the squad to them, and they stay when it is over")
	# --- errands upstairs
	mission.upstairs_share = 1.0
	var codes: Dictionary = mission._start_task("codes")
	var high: Vector3 = codes.items[0].pos
	expect(cabin.level_of(high) == 1 and cabin.level_of(codes.items[1].pos) == 0 and not cabin.path_between(spots.hall, high).is_empty(), "One of the dead can lie on the upper floor of the farmhouse")
	cabin.lock_all()
	var grounded: Dictionary = mission._start_task("codes")
	expect(cabin.level_of(grounded.items[0].pos) == 0, "While the upper floor is barred nothing is put up there")
	for area in cabin.AREAS:
		cabin.unlock(area, true)
	mission.upstairs_share = 0.0
	mission.clear()
	# --- the blast of a grenade, and the shell that brings it
	game.fx.explosion(Vector3(0, 0.4, 40.0), 6.5, "blast")
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.health = 100.0
	player.unlock("launcher")
	await wait(0.4)
	player.shot_cooldown = 0.0
	player.shoot()
	await frames(2)
	var shell: Throwable = null
	for node in game.ordnance.get_children():
		if node is Throwable and node.impact:
			shell = node
	expect(game.fx.ring_texture != null and game.fx.puff_textures.size() == 3 and shell != null and shell.shell != null and shell.lock_rotation and shell.find_children("*", "CPUParticles3D", false, false).size() == 1, "A grenade's blast throws a ring over the ground, and a shell from the launcher draws smoke behind it")
	await wait(1.6)
	# --- the picture: the 3D resolution from the menu
	var view: Viewport = game.get_viewport()
	game.set_render_scale(0.5, false)
	var halved: bool = is_equal_approx(view.scaling_3d_scale, 0.5) and view.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR
	game.set_render_scale(0.05, false)
	var bounded: bool = is_equal_approx(view.scaling_3d_scale, 0.3)
	game.set_render_scale(1.0, false)
	var first: float = game.default_render_scale()
	expect(halved and bounded and is_equal_approx(view.scaling_3d_scale, 1.0) and view.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR and first >= 0.5 and first <= 1.0, "The 3D picture can be drawn with fewer pixels and is blown up again; at full size it is left alone")
	await _toughness(game)
	await _hit_answer(game)
	await _ding_answer(game)
	await _second_exploder(game)
	await _hive_staff(game)
	game.team_enabled = true
	game.start_run()

## The plain infected of the second mission: many of them wear what the Hive's people wore -
## a few at the villa and the station, most of them in the facility. The farm knows none.
func _hive_staff(game: Node3D) -> void:
	var hive: HiveDirector = game.hive
	var staff_above: Array = HiveDirector.STAFF.above[0]
	var staff_below: Array = HiveDirector.STAFF.below[0]
	# Every look named is a body of its own, built like the plain ones.
	var known := true
	var plain: Dictionary = InfectedVisual.KINDS.normalzombie
	for look in staff_above + staff_below:
		var build: Dictionary = InfectedVisual.KINDS.get(str(look), {})
		known = known and not build.is_empty() and str(build.set) == "zombie" and int(build.get("mission", 1)) == 2 and (build.moves as Dictionary).hash() == (plain.moves as Dictionary).hash() and absf(float(build.height) - 1.76) < 0.06 and not (Infected.TYPES.mauler.visuals as Array).has(look)
	var late := 0
	for kind in InfectedVisual.KINDS:
		if int((InfectedVisual.KINDS[kind] as Dictionary).get("mission", 1)) == 2:
			late += 1
	expect(known and late == 7 and staff_below.size() == 7 and staff_above.size() == 3 and staff_below.has("hive_scientist") and staff_below.has("hive_lab") and staff_below.has("hive_nurse") and not staff_above.has("hive_scientist") and float(HiveDirector.STAFF.above[1]) < 0.5 and float(HiveDirector.STAFF.below[1]) > 0.5 and float(HiveDirector.STAFF.below[1]) < 1.0, "The Hive's staff: seven looks for the plain infected of the second mission, built like the plain ones, prepared when a night there begins")
	# How often the director hands them out, stage by stage; the special kinds keep their looks.
	var stage_before: String = hive.stage
	var shares := {}
	var strays := 0
	var specials := 0
	for stage in ["landing", "villa", "station", "hold", "terminal", "lockdown", "labs", "hall"]:
		hive.stage = stage
		var facility: bool = HiveDirector.ORDER.find(stage) >= HiveDirector.ORDER.find("terminal")
		var worn := 0
		for i in range(1000):
			var look: String = hive.look_for("mauler")
			if look != "":
				worn += 1
				if not (staff_below if facility else staff_above).has(look):
					strays += 1
		shares[stage] = worn / 1000.0
		for kind in ["striker", "ripper", "leech", "charger", "healer", "crusher", "stalker", "cru_assault"]:
			if hive.look_for(kind) != "":
				specials += 1
	var seldom := true
	var mostly := true
	for stage in shares:
		if HiveDirector.ORDER.find(stage) >= HiveDirector.ORDER.find("terminal"):
			mostly = mostly and absf(float(shares[stage]) - float(HiveDirector.STAFF.below[1])) < 0.1
		else:
			seldom = seldom and absf(float(shares[stage]) - float(HiveDirector.STAFF.above[1])) < 0.1
	expect(seldom and mostly and strays == 0 and specials == 0, "At the villa and the station now and then one of the plain infected is a guard, a worker or a civilian (%.0f %%); in the facility most are its staff (%.0f %%); the special kinds keep their looks" % [float(shares.villa) * 100.0, float(shares.labs) * 100.0])
	# What the director spawns in the facility: Maulers in every number, in the staff's clothes.
	_wipe_all(game)
	await wait(0.5)
	hive.stage = "labs"
	game.wave = 8
	var seen := {}
	var maulers := true
	var woman := true
	for i in range(40):
		var one: Infected = hive._spawn("mauler", Vector3(0, 0.05, 30.0 + i * 0.1))
		one.set_physics_process(false)
		seen[one.model.kind] = int(seen.get(one.model.kind, 0)) + 1
		maulers = maulers and one.kind == "mauler" and one.spec == Infected.TYPES.mauler and is_equal_approx(one.max_health, 95.0 + 7.0 * 7.0) and one.model.skeleton.get_bone_count() >= 22 and not one.alert
		if one.model.kind == "hive_lab":
			woman = woman and str(one.voices.death) == "death_female"
		elif one.model.kind != "mauler_female":
			woman = woman and str(one.voices.death) == "death"
		_take_off(game, one)
	var in_staff := 0
	for look in seen:
		if staff_below.has(look):
			in_staff += int(seen[look])
	# One of them falls like any Mauler.
	var fallen: Infected = hive._spawn("mauler", Vector3(0, 0.05, 30.0))
	var tries := 0
	while not staff_below.has(fallen.model.kind) and tries < 40:
		_take_off(game, fallen)
		fallen = hive._spawn("mauler", Vector3(0, 0.05, 30.0))
		tries += 1
	fallen.set_physics_process(false)
	await frames(3)
	var kills_then: int = game.kills
	fallen.receive_hit(9999.0, Vector3.FORWARD, true)
	await frames(3)
	var lies: bool = staff_below.has(fallen.model.kind) and fallen.dead and game.kills == kills_then + 1 and fallen.model.dying and fallen.model.player.current_animation.begins_with("death")
	hive.stage = stage_before
	expect(maulers and woman and in_staff >= 16 and seen.size() >= 5 and lies, "In the facility the director's plain infected are Maulers in every number, %d of 40 in the clothes of the staff (%d looks seen); the woman of the laboratory has a woman's voice, and one of them falls like any other" % [in_staff, seen.size()])
	# On the farm nothing changes: a Mauler there wears one of the five looks it always had.
	var old: Array = Infected.TYPES.mauler.visuals
	var farm := true
	for i in range(40):
		var one: Infected = game.spawn_enemy("mauler")
		one.set_physics_process(false)
		farm = farm and old.has(one.model.kind)
		_take_off(game, one)
	expect(farm and old == ["mauler_hazmat", "mauler_female", "normalzombie", "normalzombie2", "zombiehelm"], "On the farm the plain infected look as they always did")
	_wipe_all(game)
	await wait(0.5)

## Takes an enemy off the field without a death: nothing bursts, nobody is paid.
func _take_off(game: Node3D, enemy: Infected) -> void:
	enemy._retire()
	enemy.queue_free()
	game.alive_count = maxi(0, game.alive_count - 1)

## The second exploding infected: a Charger in another body, with a burst of its own -
## low, wide, the colour of blood orange, and a puddle that lies there for a while.
func _second_exploder(game: Node3D) -> void:
	var player: Survivor = game.player
	var fx: CombatEffects = game.fx
	_wipe_all(game)
	await wait(0.6)
	fx.clear()
	game.wave = 3
	# Roughly every second Charger wears the new body, and it is a Charger in every number.
	var worn := {}
	var same := true
	for i in range(24):
		var one: Infected = game.spawn_enemy("charger")
		one.set_physics_process(false)
		worn[one.model.kind] = int(worn.get(one.model.kind, 0)) + 1
		same = same and one.kind == "charger" and one.spec == Infected.TYPES.charger and is_equal_approx(one.max_health, 85.0 + 4.0 * 2.0) and str(one.voices.voice) == "charger_roar" and one.bursts_wet() == (one.model.kind == "boomer2")
		_take_off(game, one)
	await frames(2)
	var boomer: Infected = game.spawn_enemy("charger", "boomer2")
	boomer.set_physics_process(false)
	boomer.position = Vector3(0, 0.05, 30.0)
	var body: InfectedVisual = boomer.model
	var library: AnimationLibrary = InfectedVisual.libraries["boomer2"]
	var rigged: bool = body.kind == "boomer2" and body.skeleton.get_bone_count() == 22 and library.has_animation("run") and library.has_animation("shamble") and library.has_animation("stumble") and library.has_animation("scream") and body.eyes != null
	body.swell = 1.0
	body.animate(0.05, 0.0)
	var swells: bool = body.holder.scale.x > body.model_scale * 1.1
	body.swell = 0.0
	expect(Infected.TYPES.charger.visuals == ["charger", "boomer2"] and worn.size() == 2 and int(worn.get("boomer2", 0)) >= 3 and int(worn.get("charger", 0)) >= 3 and same and rigged and swells and boomer.bursts_wet() and (game.sounds.clips.boomer_burst as Array).size() == 3 and bool(game.sounds.recorded.boomer_burst), "The second exploding infected is a Charger in another body: about every second one wears it (%d of 24), with the same numbers, the same voice and the same swelling" % int(worn.get("boomer2", 0)))
	# Shot, it bursts like the Charger - and looks nothing like it.
	face(game, Vector3(0, 0.05, 18.0), PI)
	player.health = 100.0
	var bystander: Infected = game.spawn_enemy("mauler")
	bystander.set_physics_process(false)
	bystander.position = Vector3(1.4, 0.05, 30.0)
	await frames(3)
	boomer.receive_hit(9999.0, Vector3.BACK)
	var swollen: bool = boomer.dead and is_instance_valid(boomer) and fx.puddles.is_empty()
	await wait(0.5)
	var orange := 0
	var burnt := 0
	for mark in fx.decals:
		if is_instance_valid(mark) and (mark.modulate == CombatEffects.OOZE or mark.modulate == CombatEffects.OOZE_DARK):
			orange += 1
		elif is_instance_valid(mark) and mark.texture_albedo == fx.soft_texture:
			burnt += 1
	var pool: Decal = fx.puddles[0] if fx.puddles.size() == 1 else null
	var lies: bool = pool != null and pool.texture_albedo == fx.puddle_texture and pool.texture_emission == fx.puddle_texture and pool.emission_energy > 0.0 and Vector2(pool.global_position.x, pool.global_position.z).distance_to(Vector2(0, 30.0)) < 0.3 and absf(pool.global_position.y) < 0.3
	expect(swollen and not is_instance_valid(boomer) and bystander.health < bystander.max_health and player.health == 100.0 and orange >= 16 and burnt == 0 and lies and CombatEffects.OOZE.r > 0.6 and CombatEffects.OOZE.g > CombatEffects.BLOOD.g * 5.0 and CombatEffects.OOZE.g < 0.4, "Shot, it swells and bursts wet: it tears into those around it like the Charger, but leaves no burn - %d splashes the colour of blood orange and one puddle under it" % orange)
	# The puddle does nothing to whoever stands in it; it spreads, lies there and dries away.
	var grown := false
	if pool != null:
		face(game, pool.global_position + Vector3(0.3, 0.05, 0.3), PI)
		var first_size: float = pool.size.x
		await wait(1.7)
		grown = pool.size.x > first_size and is_equal_approx(pool.size.x, CombatEffects.PUDDLE_SIZE) and player.health == 100.0 and is_equal_approx(pool.modulate.a, 1.0)
		var life: Tween = pool.get_meta("life")
		life.custom_step(CombatEffects.PUDDLE_SECONDS + CombatEffects.PUDDLE_FADE * 0.5)
		grown = grown and pool.modulate.a < 0.75 and pool.modulate.a > 0.25 and pool.emission_energy < CombatEffects.PUDDLE_GLOW
		life.custom_step(CombatEffects.PUDDLE_FADE)
		await frames(3)
	expect(grown and fx.puddles.is_empty() and not is_instance_valid(pool) and CombatEffects.PUDDLE_SECONDS >= 8.0, "Its puddle spreads to %.1f m, harms nobody who stands in it, and dries away after a while" % CombatEffects.PUDDLE_SIZE)
	# The Charger itself bursts as it always did: fire, a burn on the floor, no puddle.
	face(game, Vector3(0, 0.05, 18.0), PI)
	var plain: Infected = game.spawn_enemy("charger", "charger")
	plain.set_physics_process(false)
	plain.position = Vector3(6.0, 0.05, 30.0)
	await frames(3)
	var marks_before: int = fx.decals.size()
	plain.receive_hit(9999.0, Vector3.BACK)
	await wait(0.5)
	var charred := 0
	for mark in fx.decals:
		if is_instance_valid(mark) and mark.texture_albedo == fx.soft_texture:
			charred += 1
	var as_ever: bool = not is_instance_valid(plain) and fx.puddles.is_empty() and charred == 1 and fx.decals.size() > marks_before
	# One that reaches a survivor goes off and hurts, in either body; nobody is credited.
	player.health = 100.0
	face(game, Vector3(0, 0.05, 22.0), PI)
	var runner: Infected = game.spawn_enemy("charger", "boomer2")
	runner.position = Vector3(0, 0.05, 24.0)
	var kills_then: int = game.kills
	game.hud.splatter_left = 0.0
	await wait(1.1)
	expect(as_ever and not is_instance_valid(runner) and player.health < 100.0 and game.kills == kills_then and game.hud.splatter_left > 0.0 and fx.puddles.size() == 1, "The Charger bursts as it always did, and the second one that reaches a survivor goes off and hurts like it")
	player.health = 100.0
	_wipe_all(game)
	await wait(0.5)
	fx.clear()

## What a shooter hears when his own bullet lands: a tick for flesh, a brighter one for a
## head, a fuller one on top for a kill - one answer per shot, and none for anybody else.
func _hit_answer(game: Node3D) -> void:
	var player: Survivor = game.player
	var sounds: FieldAudio = game.sounds
	var built := true
	var brief := true
	for kind in ["hit_body", "hit_head", "hit_kill"]:
		built = built and bool(sounds.recorded.get(kind, false)) and (sounds.clips[kind] as Array).size() >= 3 and float(FieldAudio.MIX[kind][0]) <= 0.0 and float(FieldAudio.MIX[kind][0]) >= -9.0 and float(FieldAudio.MIX[kind][1]) > 0.0
		for clip in sounds.clips[kind]:
			brief = brief and (clip as AudioStream).get_length() < 0.3
	expect(built and brief and (sounds.clips.hit_body as Array).size() == 4 and FieldAudio.HIT_FLOOR >= 0.03 and FieldAudio.HIT_FLOOR <= 0.09, "The answers to a hit are built: several takes each for flesh, a head and a kill, none longer than three tenths of a second")
	_wipe_all(game)
	await wait(0.5)
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.health = 100.0
	player.equip_weapon("rifle", true)
	player.ammo = 30
	var target: Infected = game.spawn_enemy("mauler")
	target.set_physics_process(false)
	target.position = Vector3(0, 0.05, 25.0)
	target.max_health = 5000.0
	target.health = 5000.0
	await frames(3)
	# --- hit sounds of the player's own come first for the infected, and only for them
	var own_a := AudioStreamWAV.new()
	var own_b := AudioStreamWAV.new()
	sounds.own_asked = true
	sounds.own_hits = [own_a, own_b]
	sounds.hit_heard = -10.0
	sounds.confirm_hit(false, false, true)
	var own_first: AudioStream = _latest_stream(sounds)
	await wait(FieldAudio.HIT_FLOOR + 0.08)
	sounds.confirm_hit(true, false, true)
	var own_second: AudioStream = _latest_stream(sounds)
	await wait(FieldAudio.HIT_FLOOR + 0.08)
	sounds.confirm_hit(false, false, false)
	var soldier: AudioStream = _latest_stream(sounds)
	expect([own_a, own_b].has(own_first) and [own_a, own_b].has(own_second) and own_first != own_second and (sounds.clips.hit_body as Array).has(soldier), "Hit sounds the player has put into his own folder answer his hits on the infected, never the same twice in a row; a soldier keeps the game's own answer")
	# (From here on the game's own answers are meant: the player's are set aside.)
	sounds.own_hits.clear()
	sounds.hit_landed = -10.0
	sounds.hit_heard = -10.0
	sounds.kill_heard = -10.0
	await wait(0.2)
	# In the chest, and again in the same instant: one tick.
	var heard: Dictionary = sounds.answers.duplicate()
	player.camera.rotation.x = -0.2
	player.shot_cooldown = 0.0
	player.shoot()
	var in_flesh: bool = target.health < 5000.0 and int(sounds.answers.hit_body) == int(heard.hit_body) + 1 and int(sounds.answers.hit_head) == int(heard.hit_head) and int(sounds.answers.hit_kill) == int(heard.hit_kill)
	var playing := false
	for voice in sounds.voices:
		playing = playing or (voice.playing and (sounds.clips[FieldAudio.DING] as Array).has(voice.stream) and voice.bus == "SFX")
	player.shot_cooldown = 0.0
	player.shoot()
	var floored: bool = int(sounds.answers.hit_body) == int(heard.hit_body) + 1
	await wait(FieldAudio.HIT_FLOOR + 0.08)
	# In the head.
	player.camera.rotation.x = 0.0
	player.shot_cooldown = 0.0
	player.shoot()
	var in_head: bool = int(sounds.answers.hit_head) == int(heard.hit_head) + 1 and int(sounds.answers.hit_body) == int(heard.hit_body) + 1 and int(sounds.answers.hit_kill) == int(heard.hit_kill)
	expect(in_flesh and playing and floored and in_head, "A bullet that lands is answered at once and flat, in flesh with one tick and in a head with another; two in the same instant are one")
	# Somebody else's hit is his own business, and so is a blow or a blast.
	var ticks: int = int(sounds.answers.hit_body) + int(sounds.answers.hit_head)
	target.receive_hit(30.0, Vector3.FORWARD, true, game.net.remote if is_instance_valid(game.net.remote) else target)
	game.explode(target.global_position + Vector3(0, 0.5, 0), 3.0, 0.0, 40.0, "blast")
	game.hud.kill_feed("PARTNER · MAULER", 100, false, true)
	game.hud.kill_feed("MAULER", 100, false)
	var others: bool = int(sounds.answers.hit_body) + int(sounds.answers.hit_head) == ticks and int(sounds.answers.hit_kill) == int(heard.hit_kill)
	# The hit that kills.
	await wait(FieldAudio.HIT_FLOOR + 0.08)
	target.health = 1.0
	player.shot_cooldown = 0.0
	player.shoot()
	var felled: bool = target.dead and int(sounds.answers.hit_kill) == int(heard.hit_kill) + 1 and int(sounds.answers.hit_head) == int(heard.hit_head) + 2
	# A kill that a guest of a co-op match is told of: answered if his bullet has only just landed.
	await wait(FieldAudio.KILL_FLOOR + 0.05)
	sounds.confirm_kill()
	var told: bool = int(sounds.answers.hit_kill) == int(heard.hit_kill) + 2
	sounds.hit_landed -= FieldAudio.KILL_WINDOW + 0.1
	await wait(FieldAudio.KILL_FLOOR + 0.05)
	sounds.confirm_kill()
	expect(others and felled and told and int(sounds.answers.hit_kill) == int(heard.hit_kill) + 2, "Nobody hears another's hit, nor a blast; the hit that kills gets the fuller answer, and a guest gets it when the host reports his kill")
	# A blast of shot is one tick, however many pellets land; and a bullet that goes through
	# three and fells them all is one tick and one answer to the kills.
	await wait(0.6)
	player.unlock("shotgun")
	player.equip_weapon("shotgun", true)
	player.ammo = 6
	var sturdy: Infected = game.spawn_enemy("mauler")
	sturdy.set_physics_process(false)
	sturdy.position = Vector3(0, 0.05, 24.5)
	sturdy.max_health = 5000.0
	sturdy.health = 5000.0
	await frames(3)
	heard = sounds.answers.duplicate()
	player.camera.rotation.x = -0.2
	player.shot_cooldown = 0.0
	player.shoot()
	var pellets: bool = sturdy.health < 5000.0 - 2.5 * float(Survivor.WEAPONS.shotgun.damage) and int(sounds.answers.hit_body) == int(heard.hit_body) + 1 and int(sounds.answers.hit_head) == int(heard.hit_head) and int(sounds.answers.hit_kill) == int(heard.hit_kill)
	sturdy.receive_hit(99999.0, Vector3.FORWARD)
	await wait(0.6)
	player.unlock("sniper")
	player.equip_weapon("sniper", true)
	player.ammo = 5
	var row: Array = []
	for i in range(3):
		var one: Infected = game.spawn_enemy("mauler")
		one.set_physics_process(false)
		one.position = Vector3(0, 0.05, 24.3 + i * 0.9)
		one.health = 1.0
		row.append(one)
	await frames(3)
	heard = sounds.answers.duplicate()
	player.camera.rotation.x = -0.2
	player.shot_cooldown = 0.0
	player.shoot()
	var fallen := 0
	for one in row:
		if (one as Infected).dead:
			fallen += 1
	expect(pellets and fallen == 3 and int(sounds.answers.hit_body) + int(sounds.answers.hit_head) == int(heard.hit_body) + int(heard.hit_head) + 1 and int(sounds.answers.hit_kill) == int(heard.hit_kill) + 1, "A blast of shot is one tick, and one bullet through three that fells them all (%d) is one tick and one answer: nothing piles up" % fallen)
	player.camera.rotation.x = 0.0
	player.equip_weapon("rifle", true)
	_wipe_all(game)
	await wait(0.5)

## True if a voice is playing one of the takes of `kind` right now, dry, and at `pitch`.
func _sounding(sounds: FieldAudio, kind: String, pitch: float = 0.0) -> bool:
	for voice in sounds.voices:
		if voice.playing and (sounds.clips[kind] as Array).has(voice.stream) and voice.bus == "SFX" and (pitch <= 0.0 or absf(voice.pitch_scale / pitch - 1.0) < 0.006):
			return true
	return false

## The ding: a hit on an infected is answered with a bell that climbs from hit to hit while
## they follow each other quickly; a head rings twice and higher; the kill brings the chord
## the climb comes to rest on. Soldiers keep the fleshy answer, and the player's own files
## come before all of it.
func _ding_answer(game: Node3D) -> void:
	var player: Survivor = game.player
	var sounds: FieldAudio = game.sounds
	var ding: String = FieldAudio.DING
	var families := ["ding_glas", "ding_messing", "ding_tink", "ding_spiel"]
	var built := true
	for family in families:
		for suffix in ["", "_head", "_kill"]:
			var kind: String = str(family) + str(suffix)
			var takes: Array = sounds.clips.get(kind, [])
			built = built and bool(sounds.recorded.get(kind, false)) and takes.size() == (4 if str(suffix) == "" else 3) and FieldAudio.MIX.has(kind) and float(FieldAudio.MIX[kind][0]) <= -3.0 and float(FieldAudio.MIX[kind][1]) <= 0.006
			for clip in takes:
				var seconds: float = (clip as AudioStream).get_length()
				built = built and seconds > 0.08 and seconds < (0.85 if str(suffix) == "_kill" else 0.6)
	var ladder: Array = FieldAudio.LADDER
	var top: int = ladder.size() - 1
	var rising: bool = ladder.size() >= 4 and ladder.size() <= 7 and float(ladder[0]) == 0.0 and float(ladder[top]) <= 7.0
	for i in range(1, ladder.size()):
		rising = rising and float(ladder[i]) > float(ladder[i - 1]) and float(ladder[i]) - float(ladder[i - 1]) <= 2.0
	expect(built and rising and families.has(ding) and FieldAudio.LADDER_PAUSE >= 0.3 and FieldAudio.LADDER_PAUSE <= 1.5, "Four families of dings are built, with takes for a hit, a head and a kill each, and one of them is played; the ladder climbs in small steps")
	# Hit after hit on an infected: every ding a rung higher, and on the last rung it stays.
	_wipe_all(game)
	await wait(FieldAudio.LADDER_PAUSE + 0.4)
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.health = 100.0
	player.equip_weapon("rifle", true)
	player.ammo = 30
	var target: Infected = game.spawn_enemy("mauler")
	target.set_physics_process(false)
	target.position = Vector3(0, 0.05, 25.0)
	target.max_health = 5000.0
	target.health = 5000.0
	var spare: Infected = game.spawn_enemy("mauler")
	spare.set_physics_process(false)
	spare.position = Vector3(0, 0.05, 26.6)
	spare.max_health = 5000.0
	spare.health = 5000.0
	await frames(3)
	var heard: Dictionary = sounds.answers.duplicate()
	var climbed := true
	player.camera.rotation.x = -0.2
	for i in range(ladder.size() + 2):
		player.shot_cooldown = 0.0
		player.shoot()
		var rung: int = mini(i, top)
		climbed = climbed and sounds.ladder_step == rung and is_equal_approx(sounds.rung(), pow(2.0, float(ladder[rung]) / 12.0)) and _sounding(sounds, ding, sounds.rung()) and sounds.dinged
		await wait(FieldAudio.HIT_FLOOR + 0.06)
	var counted: bool = int(sounds.answers.ding) == int(heard.ding) + ladder.size() + 2 and int(sounds.answers.hit_body) == int(heard.hit_body) + ladder.size() + 2 and int(sounds.answers.ding_head) == int(heard.ding_head) and int(sounds.answers.ding_kill) == int(heard.ding_kill) and not _sounding(sounds, "hit_body")
	# After a pause the next one starts at the bottom again.
	await wait(FieldAudio.LADDER_PAUSE + 0.2)
	player.shot_cooldown = 0.0
	player.shoot()
	var again: bool = sounds.ladder_step == 0 and _sounding(sounds, ding, 1.0)
	expect(climbed and counted and again and target.health < 5000.0 and is_equal_approx(sounds.rung(), 1.0), "A hit on an infected is answered with a ding, and hits that follow each other quickly climb the ladder rung by rung (%d rungs, %d semitones) and stay on the last; after a pause it starts at the bottom" % [ladder.size(), int(ladder[top])])
	# A head: the take for a head, a rung higher. Then the hit that kills: the lower bell on
	# the rung of the ding that killed - and the next hit starts at the bottom at once.
	await wait(FieldAudio.HIT_FLOOR + 0.06)
	player.camera.rotation.x = 0.0
	player.shot_cooldown = 0.0
	player.shoot()
	var head: bool = int(sounds.answers.ding_head) == int(heard.ding_head) + 1 and int(sounds.answers.hit_head) == int(heard.hit_head) + 1 and sounds.ladder_step == 1 and _sounding(sounds, ding + "_head", pow(2.0, float(ladder[1]) / 12.0))
	await wait(FieldAudio.HIT_FLOOR + 0.06)
	target.health = 1.0
	player.camera.rotation.x = -0.2
	player.shot_cooldown = 0.0
	player.shoot()
	var killing: float = pow(2.0, float(ladder[2]) / 12.0)
	var chord: bool = target.dead and int(sounds.answers.ding_kill) == int(heard.ding_kill) + 1 and int(sounds.answers.hit_kill) == int(heard.hit_kill) + 1 and _sounding(sounds, ding + "_kill", killing) and _sounding(sounds, ding, killing) and not _sounding(sounds, "hit_kill")
	await wait(FieldAudio.HIT_FLOOR + 0.06)
	player.shot_cooldown = 0.0
	player.shoot()
	var restarted: bool = spare.health < 5000.0 and sounds.ladder_step == 0 and is_equal_approx(sounds.rung(), 1.0)
	expect(head and chord and restarted, "A head rings with its own take, a rung higher; the hit that kills brings the lower bell on the rung of its ding, and the next hit starts at the bottom")
	# A soldier keeps the fleshy answer, for the hit and for the kill.
	_take_off(game, spare)
	await wait(FieldAudio.LADDER_PAUSE + 0.2)
	var soldier := game.spawn_enemy("cru_assault") as CruSoldier
	soldier.set_physics_process(false)
	soldier.position = Vector3(0, 0.05, 25.0)
	soldier.max_health = 5000.0
	soldier.health = 5000.0
	await frames(3)
	heard = sounds.answers.duplicate()
	player.shot_cooldown = 0.0
	player.shoot()
	var fleshy: bool = soldier.health < 5000.0 and int(sounds.answers.ding) == int(heard.ding) and int(sounds.answers.hit_body) == int(heard.hit_body) + 1 and _sounding(sounds, "hit_body") and not sounds.dinged
	await wait(FieldAudio.HIT_FLOOR + 0.06)
	soldier.health = 1.0
	player.shot_cooldown = 0.0
	player.shoot()
	fleshy = fleshy and soldier.dead and int(sounds.answers.ding_kill) == int(heard.ding_kill) and int(sounds.answers.ding) == int(heard.ding) and int(sounds.answers.hit_kill) == int(heard.hit_kill) + 1 and _sounding(sounds, "hit_kill")
	# Hit sounds of the player's own choosing come before the ding - and then the kill is
	# answered as it was before there were dings.
	await wait(FieldAudio.LADDER_PAUSE + 0.2)
	var own: AudioStream = (sounds.clips.click as Array)[0]
	sounds.own_hits = [own]
	var last: Infected = game.spawn_enemy("mauler")
	last.set_physics_process(false)
	last.position = Vector3(0, 0.05, 25.0)
	last.max_health = 5000.0
	last.health = 5000.0
	await frames(3)
	heard = sounds.answers.duplicate()
	player.shot_cooldown = 0.0
	player.shoot()
	var theirs := false
	for voice in sounds.voices:
		theirs = theirs or (voice.playing and voice.stream == own and voice.bus == "SFX")
	theirs = theirs and int(sounds.answers.ding) == int(heard.ding) and not sounds.dinged
	await wait(FieldAudio.HIT_FLOOR + 0.06)
	last.health = 1.0
	player.shot_cooldown = 0.0
	player.shoot()
	theirs = theirs and last.dead and int(sounds.answers.ding_kill) == int(heard.ding_kill) and int(sounds.answers.hit_kill) == int(heard.hit_kill) + 1 and _sounding(sounds, "hit_kill")
	sounds.own_hits = []
	expect(fleshy and theirs, "A soldier keeps the fleshy answer for the hit and for the kill; and where the player has hit sounds of his own, they come before the ding")
	player.camera.rotation.x = 0.0
	_wipe_all(game)
	await wait(0.5)

## How much the infected take: a ladder over the difficulties. What was tried as the
## difficulty "Zombie-Test" is NORMAL's own now, the easier level asks less, each harder
## one clearly more; and "Zombie-Test" itself is gone from the menu.
func _toughness(game: Node3D) -> void:
	var order: Array = Profile.ORDER
	var climbs: bool = order == ["easy", "normal", "hard", "nightmare"] and Profile.DIFFICULTIES.size() == order.size()
	var before := 1.0
	var steps := ""
	for level in order:
		var brood: float = float((Profile.DIFFICULTIES[level] as Dictionary).get("brood", 0.0))
		# Every step is felt (a quarter of the old health and more), and the hardest is no slog.
		climbs = climbs and brood >= before + 0.25 and brood <= 3.0
		before = brood
		steps += " %.1f" % brood
	expect(climbs and is_equal_approx(float(Profile.DIFFICULTIES.normal.brood), 1.8) and float(Profile.DIFFICULTIES.easy.brood) >= 1.25, "The toughness of the infected is a ladder over the difficulties (%s ): NORMAL has what Zombie-Test had, the easier level asks less, each harder one clearly more" % steps)
	# "Zombie-Test" is gone from the menu; a profile that still has it selected comes up on
	# NORMAL, and the lists of its best runs stay in the file as they were.
	var book := Profile.new()
	book.stored = false
	var labels := ""
	var round_trip := true
	for i in range(order.size()):
		labels += str(book.rules().label) + " "
		round_trip = round_trip and order.has(book.difficulty)
		book.next_difficulty()
	var old := Profile.new()
	old.stored = false
	var its_runs := [{"score": 900.0, "round": 3.0, "seconds": 300.0, "victory": false, "kills": 40.0}]
	var saved := {"difficulty": "zombie_test", "mission": 2.0, "mode": "endless", "totals": {"kills": 12.0},
		"runs": {"zombie_test": its_runs, "villa_zombie_test": its_runs, "endless_zombie_test": its_runs, "normal": [{"score": 500.0, "round": 2.0, "seconds": 200.0, "victory": false, "kills": 20.0}], "nonsense": [1.0]}}
	old.read(saved)
	var came_up: bool = old.difficulty == "normal" and str(old.rules().label) == "NORMAL" and old.mission == 2 and old.mode == "endless" and int(old.totals.kills) == 12 and old.best("normal").size() == 1
	old.record(Profile.board("normal", "story"), {"score": 700, "round": 2, "seconds": 250, "victory": false, "kills": 30})
	var back: Dictionary = old.kept()
	var lists: Dictionary = back.runs
	expect(not order.has("zombie_test") and not Profile.DIFFICULTIES.has("zombie_test") and not labels.contains("ZOMBIE") and round_trip and book.difficulty == "normal" and Profile.RETIRED.has("zombie_test") and came_up and str(back.difficulty) == "normal" and lists.get("zombie_test") == its_runs and lists.get("villa_zombie_test") == its_runs and lists.get("endless_zombie_test") == its_runs and (lists.normal as Array).size() == 2 and not lists.has("nonsense"), "Zombie-Test is gone from the menu (%s); a saved profile that still has it comes up on NORMAL, and the lists of its runs stay in the file untouched" % labels.strip_edges())
	# In a night: the horde takes what its level says; Helix's people and the fights of
	# their own keep their health on every level.
	var level_before: String = game.level
	var took := {}
	for level in ["plain"] + order:
		game.brood_on = str(level) != "plain"
		game.level = "normal" if str(level) == "plain" else str(level)
		game._set_modifier("")
		for kind in Infected.TYPES:
			if str(kind) == "ripper" and not ResourceLoader.exists(RipperVisual.SCENE):
				continue
			# (As a guest's machine builds them: nobody arrives, nothing is counted.)
			var one: Infected = game.body_for(str(kind))
			one.game = game
			one.kind = str(kind)
			one.wave = 4
			one.puppet = true
			game.enemies.add_child(one)
			took["%s/%s" % [level, kind]] = one.max_health
			one._retire()
			one.queue_free()
	var tougher := true
	var untouched := true
	var horde := 0
	var apart := 0
	for kind in Infected.TYPES:
		if not took.has("plain/%s" % kind):
			continue
		var plain: float = took["plain/%s" % kind]
		var own: bool = Infected.TYPES[kind].get("human", false) or str(kind) in Infected.BROOD_APART
		horde += 0 if own else 1
		apart += 1 if own else 0
		for level in order:
			var tested: float = took["%s/%s" % [level, kind]]
			if own:
				untouched = untouched and is_equal_approx(tested, plain)
			else:
				tougher = tougher and is_equal_approx(tested, plain * float(Profile.DIFFICULTIES[level].brood))
	# A night that is played has it switched on by itself.
	game.brood_on = true
	game.level = "normal"
	game._set_modifier("")
	game.wave = 1
	var met: Infected = game.spawn_enemy("mauler")
	met.set_physics_process(false)
	var standard: bool = is_equal_approx(met.max_health, 95.0 * float(Profile.DIFFICULTIES.normal.brood)) and is_equal_approx(met.health, met.max_health)
	_take_off(game, met)
	# The yard: where a level's infected are tougher than it takes at full crowd, fewer of
	# them are let in at once - so few that the crowd weighs less, not more.
	var caps := {}
	game.wave = 9
	for level in order:
		game.level = str(level)
		game._set_modifier("")
		caps[level] = game.alive_cap()
	game.brood_on = false
	game.level = "hard"
	game._set_modifier("")
	var as_before: int = game.alive_cap()
	var weight: float = int(caps.normal) * float(Profile.DIFFICULTIES.normal.brood)
	var thinned: bool = int(caps.normal) == game.MAX_ALIVE and int(caps.easy) < int(caps.normal) and int(caps.hard) < int(caps.normal) and int(caps.nightmare) < int(caps.hard) and int(caps.nightmare) >= 6 and int(caps.hard) * float(Profile.DIFFICULTIES.hard.brood) <= weight and int(caps.nightmare) * float(Profile.DIFFICULTIES.nightmare.brood) <= int(caps.hard) * float(Profile.DIFFICULTIES.hard.brood) and as_before == 20 and float(Profile.DIFFICULTIES.normal.brood) <= game.FULL_CROWD_BROOD
	game.level = level_before
	game._set_modifier("")
	expect(thinned, "The yard takes the full crowd on NORMAL (%d at once late in a night); where the infected are tougher, fewer are let in at once (SCHWER %d, ALBTRAUM %d instead of %d and more), and as many come in all" % [int(caps.normal), int(caps.hard), int(caps.nightmare), as_before])
	expect(tougher and untouched and standard and horde >= 6 and apart >= 14 and Infected.BROOD_APART.has("crusher") and Infected.BROOD_APART.has("stalker") and Infected.BROOD_APART.has("prowler"), "In a night the horde (%d kinds) takes what its level says - a Mauler of the first round %.0f on NORMAL - while the C.R.U., the operators, the Crusher, the Stalker and the Prowler (%d kinds) keep their health on every level" % [horde, 95.0 * float(Profile.DIFFICULTIES.normal.brood), apart])
	await frames(3)

## What came with v0.8: the UMP and the parts for it, ballistic plates, lamps on the C.R.U.
func _kit(game: Node3D) -> void:
	var spots: Dictionary = game.cabin.points
	var player: Survivor = game.player
	game.team_enabled = false
	game.start_run()
	game.mission.plain()
	# --- the UMP at the shop
	game.credits = 3000
	player.extra_slots = 3
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	expect(game.buy_weapon("ump") and player.current_weapon == "ump" and player.magazine_size() == 25 and game.credits == 2780, "The shop sells the UMP")
	var view: Node3D = player.weapon_models["ump"]
	var clip := view.get_node_or_null("Magazine") as Node3D
	var hand := view.get_node_or_null("Support") as Node3D
	expect(clip != null and hand != null and clip.get_child_count() == 1 and not (view.get_node("Mod_reddot") as Node3D).visible and not (view.get_node("Mod_silencer") as Node3D).visible, "The UMP has a magazine and a hand of their own, and nothing fitted when new")
	expect(not game.buy_part("p90", "reddot") and not game.buy_part("ump", "bayonet") and game.credits == 2780, "Parts are only sold for the weapons that take them")
	var plain_kick := float(player.gun().kick)
	var plain_muzzle: Vector3 = player.flash.position
	expect(game.buy_part("ump", "reddot") and player.fitted("sight") == "reddot" and game.credits == 2660 and (view.get_node("Mod_reddot") as Node3D).visible and float(player.gun().zoom) == 40.0 and not Survivor.WEAPONS.ump.has("zoom"), "A red dot is bought, fitted and changes how the UMP aims")
	expect(game.buy_part("ump", "scope") and player.fitted("sight") == "scope" and game.credits == 2400 and player.gun().has("scope") and not player.gun().has("zoom") and (view.get_node("Mod_scope") as Node3D).visible and not (view.get_node("Mod_reddot") as Node3D).visible, "A second sight takes the place of the first")
	expect(game.buy_part("ump", "reddot") and player.fitted("sight") == "reddot" and game.credits == 2400 and game.buy_part("ump", "reddot") and player.fitted("sight") == "" and game.credits == 2400 and not player.gun().has("zoom"), "A part that is owned goes on and comes off for nothing")
	expect(game.buy_part("ump", "silencer") and game.credits == 2220 and str(player.gun().sound) == "ump_sil" and player.gun().quiet and float(player.gun().kick) < plain_kick and absf(player.flash.position.z - (plain_muzzle.z - WeaponView.SILENCER_LENGTH)) < 0.001 and Survivor.QUIET_SOUNDS.has("ump_sil") and str(Survivor.WEAPONS.ump.sound) == "ump", "A suppressor changes the sound, the recoil and where the muzzle is")
	expect(game.sounds.clips.has("ump") and game.sounds.clips.has("ump_sil"), "The UMP has its own shot, with and without suppressor")
	# --- two weapons on one key take turns
	expect(game.buy_weapon("p90") and player.current_weapon == "p90", "The P90 is bought as well")
	player._select_slot(1)
	var second := player.current_weapon
	player._select_slot(1)
	var third := player.current_weapon
	player._select_slot(1)
	expect(second == "ump" and third == "rifle" and player.current_weapon == "p90" and player.fitted("sight") == "" and player.flash.position.is_equal_approx(WeaponView.VIEWS.p90.muzzle), "Weapons of one kind take turns on their key, each with its own muzzle")
	player._select_slot(1)
	game.resume_run()
	# --- the magazine really leaves the weapon
	var half: Dictionary = WeaponView.reload_step("ump", 0.38)
	expect((half.magazine as Vector3).length() > 0.2 and (WeaponView.reload_step("ump", 0.0).magazine as Vector3) == Vector3.ZERO and (WeaponView.reload_step("ump", 1.0).hand as Vector3) == Vector3.ZERO and (WeaponView.reload_step("ump", 0.83).hand as Vector3).length() > 0.05 and (WeaponView.reload_step("p90", 0.4).magazine as Vector3) == Vector3.ZERO, "The magazine change has its steps: out, in, and a slap on the cocking handle")
	player.ammo = 4
	player.start_reload()
	var out_of_well := 0.0
	var moved_hand := 0.0
	for i in range(170):
		await get_tree().physics_frame
		out_of_well = maxf(out_of_well, clip.position.length())
		moved_hand = maxf(moved_hand, hand.position.length())
	expect(out_of_well > 0.2 and moved_hand > 0.2 and player.ammo == 25 and clip.position.length() < 0.001 and hand.position.length() < 0.001, "Reloading the UMP pulls its magazine out and puts a full one in")
	# --- ballistic plates
	game.credits = 1000
	player.position = (spots.shop as Vector3) + Vector3(0, 0.05, 0)
	game.interact()
	expect(game.item_price("plates") == 160 and game.buy_item("plates") and game.buy_item("plates") and player.plate_level == 2 and game.credits == 580 and game.buy_item("plates") and game.item_price("plates") == -1 and not game.buy_item("plates") and game.credits == 180, "Ballistic plates are bought in three levels")
	game.resume_run()
	player.plate_level = 2
	player.health = 100.0
	player.armor = 0.0
	player.receive_damage(40.0, Vector3.ZERO, "bullet")
	var after_bullet := player.health
	player.receive_damage(20.0, Vector3.ZERO, "frag")
	var after_frag := player.health
	player.receive_damage(10.0)
	expect(is_equal_approx(after_bullet, 76.0) and is_equal_approx(after_frag, 64.0) and is_equal_approx(player.health, 54.0), "Plates take 40 % off bullets and fragments, and nothing off a bite")
	player.health = 100.0
	player.armor = 50.0
	player.receive_damage(40.0, Vector3.ZERO, "bullet")
	expect(is_equal_approx(player.health, 90.4) and is_equal_approx(player.armor, 35.6), "Armour takes its share of what the plates let through")
	# --- what the C.R.U. shoot is a bullet, and they can be seen
	player.armor = 0.0
	player.health = 100.0
	player.plate_level = 3
	face(game, Vector3(0, 0.05, 22.0), PI)
	var trooper := game.spawn_enemy("cru_assault") as CruSoldier
	trooper.set_physics_process(false)
	trooper.position = Vector3(0, 0.05, 28.0)
	await frames(3)
	var body := trooper.model as CruVisual
	expect(body.lamp != null and body.lamp.visible and body.lamp.get_parent() == body.soldier.gun and body.beacons.size() == 3, "A C.R.U. soldier carries a weapon lamp and a red marker light")
	trooper.ammo = 60
	for i in range(40):
		if player.health < 100.0:
			break
		trooper.rounds_left = 1
		trooper._fire(player.global_position, false)
	var harm: float = float(trooper.role.damage) * float(game.rules.harm)
	expect(player.health < 100.0 and is_equal_approx(100.0 - player.health, harm * 0.45), "A C.R.U. bullet is stopped by the plates as far as they go")
	trooper.receive_hit(9999.0, Vector3.FORWARD)
	expect(trooper.dead and not body.lamp.visible and not body.beacons[0].visible, "His lamps go out with him")
	# --- nothing in the shop runs off the screen
	var rows := {}
	for id in Survivor.ORDER:
		if int(Survivor.WEAPONS[id].price) > 0:
			var tab := str(Survivor.WEAPONS[id].get("group", "weapons"))
			rows[tab] = int(rows.get(tab, 0)) + 1
	for id in Survivor.GOODS:
		rows[Survivor.GOODS[id].group] = int(rows.get(Survivor.GOODS[id].group, 0)) + 1
	# The list of parts shows those for what is carried: one primary weapon, as a rule.
	var parts := 0
	var most := 0
	for id in Survivor.ATTACHMENTS:
		parts += (Survivor.ATTACHMENTS[id] as Dictionary).size()
		most = maxi(most, (Survivor.ATTACHMENTS[id] as Dictionary).size())
	rows["mods"] = int(rows.get("mods", 0)) + most * Survivor.CARRY
	var widest := 0
	for tab in rows:
		widest = maxi(widest, int(rows[tab]))
	expect(rows.size() == SurvivalHUD.SHOP_TABS.size() and rows.size() == 8 and widest <= 10 and int(rows.weapons) == 8 and int(rows.heavy) == 7 and int(rows.mods) == 3 and not Survivor.GOODS.has("mags") and parts == 15 and int(rows.get("class", 0)) == 3 and int(rows.team) == 2, "The shop has eight lists, and none is longer than can be scrolled through at a glance (%s)" % str(rows))
	game.team_enabled = true
	game.start_run()
	expect(player.plate_level == 0 and not player.inventory.has("ump"), "A new night starts without plates and without the UMP")

## Holds [E] on whatever task item is in reach for a few seconds of mission time.
func _hold(game: Node3D, seconds: float = 3.2) -> void:
	Input.action_press("interact")
	var steps := int(ceil(seconds / 0.4))
	for step in range(steps):
		game.mission.update(0.4)
	Input.action_release("interact")

## Lets a device of the story run until its task is over, restarting it whenever it
## stalls. Returns how often that was.
func _run_device(game: Node3D, task: Dictionary) -> int:
	var stalls := 0
	for step in range(600):
		if task.state != "active":
			break
		if str(task.items[0].state) == "stalled":
			stalls += 1
			_hold(game, 2.4)
		game.mission.update(0.5)
	return stalls

## The story, from the first clue to the helicopter. Only on a map that has the lab.
func _story(game: Node3D) -> void:
	var cabin: CabinMap = game.cabin
	if not cabin.has_method("unlock") or not cabin.points.has("nadja_hack"):
		print("SKIP: this map has no lab, the story is not checked")
		return
	var mission: MissionDirector = game.mission
	var story: StoryDirector = game.story
	var spots: Dictionary = cabin.points
	var lift := Vector3(0, 0.05, 0)
	game.story_in_checks = true
	game.intro_skipped = true
	game.team_enabled = false
	game.start_run()
	mission.plain()
	expect(story.enabled and game.player.global_position.distance_to(spots.landing) < 1.0 and is_instance_valid(story.nadja_npc), "With the story on, the squad starts at the landing zone and Nadja waits in the lab")
	expect(cabin.is_locked("upper") and cabin.is_locked("wing") and cabin.is_locked("cellar") and cabin.path_between(spots.hall, spots.upper_west).is_empty() and cabin.path_between(spots.hall, spots.lab).is_empty() and not cabin.path_between(spots.landing, spots.hall).is_empty(), "At first the upper floor, a wing and the cellar are closed")
	# Rounds one to three: the house opens up.
	game.begin_wave()
	game.spawn_queue.clear()
	game.complete_wave()
	expect(not cabin.is_locked("wing") and cabin.is_locked("upper") and not cabin.path_between(spots.hall, spots.wing).is_empty(), "After the first round more rooms open")
	for i in range(2):
		game.begin_wave()
		game.spawn_queue.clear()
		game.complete_wave()
	expect(not cabin.is_locked("upper") and not cabin.path_between(spots.hall, spots.upper_west).is_empty() and cabin.is_locked("cellar"), "After the third round the stairs are free")
	# Finished errands are clues.
	for i in range(3):
		mission._finish(mission._start_task("crate"), true)
	expect(story.intel == 3 and story.contact and story.errand("codes") == "samples", "Three finished errands give Nadja away, and she takes over the errands")
	# Round four: the hack module comes by helicopter.
	game.begin_wave()
	game.spawn_queue.clear()
	var drop: Dictionary = mission.task_of("module")
	expect(story.stage == "module" and not drop.is_empty() and str(drop.items[0].state) == "falling", "The helicopter drops the hack module")
	mission.update(0.1)
	expect(is_instance_valid(story.heli) and story.heli_job == "pass" and mission.nearest_item().is_empty(), "The crate hangs on its parachute while the helicopter passes")
	for step in range(40):
		mission.update(0.5)
	face(game, (drop.items[0].pos as Vector3) + Vector3(1.2, 0.05, 0), 0.0)
	expect(str(drop.items[0].state) == "" and not mission.nearest_item().is_empty(), "The crate lands and can be opened")
	_hold(game)
	mission.update(0.1)
	var hack: Dictionary = mission.task_of("hack")
	expect(drop.state == "done" and not hack.is_empty() and str(hack.items[0].state) == "", "With the module in hand, the cellar door asks for it")
	face(game, (spots.cellar_door as Vector3) + lift, 0.0)
	expect((spots.cellar_door as Vector3).distance_to(spots.cellar_hack) < MissionDirector.USE_RANGE and not mission.targets.is_empty(), "The module is put on from where one stands at the door")
	_hold(game)
	expect(str(hack.items[0].state) == "running" and float(hack.left) > 60.0 and mission.targets.values()[0].is_targetable(), "The module runs once it is clamped on, and draws the infected")
	var stalls := _run_device(game, hack)
	expect(hack.state == "done" and stalls >= 1 and not cabin.is_locked("cellar") and story.stage == "lab" and not cabin.path_between(spots.hall, spots.lab).is_empty(), "The hack jams, is restarted and opens the cellar")
	game.complete_wave()
	# Round five: down into the lab.
	game.begin_wave()
	game.spawn_queue.clear()
	var drives: Dictionary = mission.task_of("drives")
	# They are the drives of servers that stand in the lab from the start: three different
	# racks, each with a spot in front of it that can be walked to.
	var racks := {}
	for item in drives.get("items", []):
		var rack: int = mission._server_at(item.pos)
		var way: PackedVector3Array = cabin.path_between(spots.lab, item.pos)
		if rack >= 0 and not way.is_empty() and way[way.size() - 1].distance_to(item.pos) < 0.6 and (cabin.servers[rack].drive as Node3D).visible:
			racks[rack] = cabin.servers[rack].drive
	expect(not drives.is_empty() and drives.items.size() == 3 and cabin.level_of(drives.items[0].pos) == 2 and racks.size() == 3, "Nadja asks for the drives in the lab: those of three of the servers that stand there (%s of %d)" % [str(racks.keys()), cabin.servers.size()])
	face(game, (spots.lab_glass as Vector3) + lift, 0.0)
	mission.update(0.2)
	mission.update(0.2)
	expect(story.entered and story.met and cabin.is_locked("lab_room"), "Down in the lab the squad finds Nadja behind glass")
	for item in drives.items:
		face(game, (item.pos as Vector3) + Vector3(0, 0.05, 0), 0.0)
		_hold(game)
	var gone := 0
	for rack in racks:
		if not (racks[rack] as Node3D).visible:
			gone += 1
	expect(drives.state == "done" and gone == 3, "The drives are pulled, and gone from their bays")
	game.complete_wave()
	# Round six: her door.
	game.begin_wave()
	game.spawn_queue.clear()
	var rescue: Dictionary = mission.task_of("rescue")
	expect(story.stage == "rescue" and mission.wave_kind == "mixed" and not rescue.is_empty(), "Two rounds after the cellar, her door is next and Helix sends everything")
	face(game, (spots.nadja_door as Vector3) + lift, 0.0)
	expect((spots.nadja_door as Vector3).distance_to(spots.nadja_hack) < MissionDirector.USE_RANGE, "The module reaches her door from where one stands")
	_hold(game)
	var jams := _run_device(game, rescue)
	game.spawn_queue.clear()
	expect(rescue.state == "done" and jams >= 2 and not cabin.is_locked("tunnel") and not cabin.is_locked("lab_room") and story.stage == "escort", "Her door opens after two jams, and the C.R.U. has blown the tunnel")
	expect(is_instance_valid(story.nadja) and story.nadja.unarmed and not is_instance_valid(story.nadja_npc) and game.survivors.has(story.nadja) and not game.team.has(story.nadja), "Nadja is out and follows the squad, unarmed")
	game.complete_wave()
	# The last round: to the helicopter.
	game.begin_wave()
	game.spawn_queue.clear()
	var evac: Dictionary = mission.task_of("evac")
	expect(game.wave == game.ROUNDS.size() and story.stage == "evac" and not evac.is_empty(), "With Nadja out, the next round is the last")
	mission.update(0.1)
	expect(is_instance_valid(story.heli) and story.heli_job == "evac" and not story.everyone_aboard(spots.landing), "The helicopter is on its way to the landing zone")
	for step in range(90):
		mission.update(1.0)
	expect(str(evac.items[0].state) == "landed" and game.state == "playing", "The helicopter lands and waits")
	story.nadja.global_position = (spots.landing as Vector3) + Vector3(1.5, 0.05, 0)
	face(game, (spots.landing as Vector3) + Vector3(-1.0, 0.05, 0), 0.0)
	mission.update(0.5)
	expect(game.state == "win" and story.stage == "done", "With everyone at the helicopter the night is won")
	# --- the arrival is filmed from outside, without the weapon in the survivor's hands
	game.intro_skipped = false
	game.start_run()
	await frames(3)
	var filmed: bool = story.intro_left > 0.0 and is_instance_valid(story.intro_camera) and story.intro_camera.current and not game.player.controlled and not game.player.flashlight.visible
	var hands_hidden := true
	var cameras := 0
	for node in get_tree().root.find_children("*", "Camera3D", true, false):
		if node != game.player.camera:
			cameras += 1
			hands_hidden = hands_hidden and ((node as Camera3D).cull_mask & 2) == 0
	story._end_intro(true)
	await frames(2)
	expect(filmed and cameras >= 3 and hands_hidden and (game.player.camera.cull_mask & 2) != 0 and game.player.camera.current and game.player.controlled and game.player.flashlight.visible, "The arrival is filmed by a camera of its own; like every camera but the survivor's, it does not show the weapon in his hands, and his lamp stays dark until he is down")
	game.story_in_checks = false
	game.intro_skipped = false
	game.start_run()
	expect(not game.story.enabled and not cabin.is_locked("cellar") and not is_instance_valid(game.story.nadja), "A night without the story has every door open")
	await _spoken(game)

## Lets the director of the second mission take its next turn: what is said there runs
## with the picture, and under load several steps of the physics pass between two pictures.
func _turn(hive: HiveDirector) -> void:
	var before := hive.clock
	# (Nobody of the squad is in the middle of a call the director would wait for.)
	hive.game.bark_until.clear()
	for i in range(40):
		await get_tree().process_frame
		if hive.clock != before:
			return

## What is said in the second mission (v0.24): its own lines instead of stand-ins, one
## queue for the radio and the squad, the taken channel until the station.
func _spoken(game: Node3D) -> void:
	var hive: HiveDirector = game.hive
	var hud: SurvivalHUD = game.hud
	var profile: Profile = game.profile
	var kept_mission: int = profile.mission
	# --- everything the director says is written, and everything written for it is said
	var source := FileAccess.get_file_as_string("res://scripts/hive.gd")
	var finder := RegEx.new()
	finder.compile("(line|face|talk|radio)\\(\"(m2_[a-z_0-9]+)\"")
	var used := {}
	var unknown: Array[String] = []
	var said_at: Array = finder.search_all(source)
	# (What is said when it is settled who goes on stands in a table: ["face", "m2_..."].)
	finder.compile("\\[\"(line|face|talk)\", \"(m2_[a-z_0-9]+)\"")
	said_at.append_array(finder.search_all(source))
	for found: RegExMatch in said_at:
		var cue := found.get_string(2)
		used[found.get_string(1) + ":" + cue] = true
		if (found.get_string(1) == "talk" and not Radio.BARKS.has(cue)) or (found.get_string(1) != "talk" and not Radio.LINES.has(cue)):
			unknown.append(cue)
	var later: Array[String] = []
	var unsaid: Array[String] = []
	for cue: String in Radio.LINES:
		if cue.begins_with("m2_") and not later.has(cue) and not (used.has("line:" + cue) or used.has("face:" + cue) or used.has("radio:" + cue)):
			unsaid.append(cue)
	for cue: String in Radio.BARKS:
		if cue.begins_with("m2_") and not later.has(cue) and not used.has("talk:" + cue):
			unsaid.append(cue)
	expect(unknown.is_empty() and unsaid.is_empty() and not source.contains("say(\""), "Every line written for the second mission is said somewhere in it, and nothing is said there that is not written%s" % ("" if unknown.is_empty() and unsaid.is_empty() else " - unknown: %s, never said: %s" % [str(unknown), str(unsaid)]))
	# --- a night of the second mission
	game.return_to_menu()
	await frames(2)
	profile.mission = 2
	game.team_enabled = true
	game.radio_queue.clear()
	game.radio_busy = 0.0
	game.start_run()
	await frames(3)
	await _turn(hive)
	if not hive.on:
		expect(false, "The second mission starts for the check of what is said in it")
		profile.mission = kept_mission
		return
	# Command's first words: over the radio, and not in a voice that can be trusted.
	var first: String = hud.radio_label.text
	var taken: bool = hive.channel_taken() and Radio.hijacked and first.begins_with("COLEMAN:") and first.contains("#") and hive.line_left > 2.0
	var fake_sound: bool = str(Radio.pick("m2_arrival").sound) == "" or is_equal_approx(game.sounds.radio_voice.pitch_scale, game.sounds.FAKE_PITCH)
	# A line of the game's own takes its turn in the same queue.
	game.radio("mate_down", 5.0)
	var one_queue: bool = game.radio_queue.is_empty() and hive.lines.size() == 1 and str(hive.lines[0].kind) == "game" and hud.radio_label.text == first
	hive.lines.clear()
	# --- the squad among itself: who is there and on his feet, in the order written
	var viper: Teammate = null
	var scorpion: Teammate = null
	for mate: Teammate in game.team:
		if mate.look == "viper":
			viper = mate
		elif mate.look == "scorpion":
			scorpion = mate
	if viper == null or scorpion == null:
		expect(false, "Viper and Scorpion are the squad of the check")
	else:
		var said: Array[String] = []
		var shown := hud.radio_label.text
		hive.talk("m2_colonel")
		var parts: int = hive.lines.size()
		for turn in range(8):
			hive.line_left = 0.0
			game.bark_until.clear()
			await _turn(hive)
			if hud.radio_label.text != shown:
				shown = hud.radio_label.text
				said.append(shown.get_slice(":", 0))
		# While one of them says his line the other keeps small talk to himself - but not a cry for help.
		hive.talk("m2_train")
		hive.line_left = 0.0
		await _turn(hive)
		var busy: bool = shown != hud.radio_label.text and hud.radio_label.text.begins_with("SCORPION:") and hive.line_left > 0.5
		var hushed: bool = not game.bark(viper, "viper", "kill") and game.bark(viper, "viper", "down")
		hive.lines.clear()
		game.bark_until.clear()
		# Down, he says nothing; and a word that waited too long is not said at all.
		viper._go_down(Vector3.INF)
		shown = hud.radio_label.text
		hive.talk("m2_colonel")
		var alone: Array[String] = []
		for turn in range(8):
			hive.line_left = 0.0
			await _turn(hive)
			if hud.radio_label.text != shown:
				shown = hud.radio_label.text
				alone.append(shown.get_slice(":", 0))
		viper.revive(true)
		hive.talk("m2_station")
		hive.clock += HiveDirector.STALE + 1.0
		hive.line_left = 0.0
		await _turn(hive)
		var stale: bool = hive.lines.is_empty() and hud.radio_label.text == shown
		# A line of the mission waits for a call somebody of the squad is in the middle of.
		game.talk_until = 0
		var calling: bool = game.bark(scorpion, "scorpion", "reload") and hive._squad_calling()
		hive.line("m2_depot")
		hive.line_left = 0.0
		var clock_before: float = hive.clock
		for step in range(40):
			await get_tree().process_frame
			if hive.clock != clock_before:
				break
		var waited: bool = calling and hive.lines.size() == 1 and hive.call_wait > 0.0 and hud.radio_label.text == shown
		hive.lines.clear()
		stale = stale and waited
		if not (parts == 3 and said == ["VIPER", "SCORPION"] and alone == ["SCORPION"] and busy and hushed and stale):
			print("SPOKEN_SQUAD parts=%d busy=%s hushed=%s stale=%s scorpion: down=%s visible=%s health=%.0f rising=%.2f at=%s  viper: down=%s  player at=%s stage=%s alive=%d" % [parts, busy, hushed, stale, scorpion.down, scorpion.visible, scorpion.health, scorpion.rising_left, str(scorpion.global_position.snapped(Vector3.ONE * 0.1)), viper.down, str(game.player.global_position.snapped(Vector3.ONE * 0.1)), hive.stage, game.alive_count])
		expect(parts == 3 and said == ["VIPER", "SCORPION"] and alone == ["SCORPION"] and busy and hushed and stale, "The squad talks among itself in the order its lines are written; who is not there or is down says nothing, small talk waits while a line is said, a line waits for a call that is being made, and a word that comes too late is dropped (%s / %s)" % [str(said), str(alone)])
	# --- once the channel is cleared, command's words come through whole
	hive.lines.clear()
	hive.done["radio_clear"] = true
	hive.line("m2_power")
	hive.line_left = 0.0
	await _turn(hive)
	var whole: String = hud.radio_label.text
	var clean_sound: bool = str(Radio.pick("m2_power").sound) == "" or is_equal_approx(game.sounds.radio_voice.pitch_scale, 1.0)
	# Nadja over the loudspeakers, in her own ink; and nothing of all this in the game's own queue.
	hive.line("m2_n_lock")
	hive.line_left = 0.0
	await _turn(hive)
	var speakers: bool = hud.radio_label.text.begins_with("NADJA:") and hud.radio_label.get_theme_color("font_color").is_equal_approx(HiveDirector.INK.nadja)
	if not (taken and fake_sound and one_queue and clean_sound and speakers and game.radio_queue.is_empty()):
		print("SPOKEN taken=%s fake_sound=%s one_queue=%s clean_sound=%s speakers=%s queue=%d first=%s whole=%s now=%s" % [taken, fake_sound, one_queue, clean_sound, speakers, game.radio_queue.size(), first, whole, hud.radio_label.text])
	expect(taken and fake_sound and one_queue and not hive.channel_taken() and whole.begins_with("COLEMAN:") and not whole.contains("#") and clean_sound and speakers and game.radio_queue.is_empty(), "Until the channel is cleared at the station command's lines come through a taken channel, after it whole; the game's own radio lines wait in the same queue, and Nadja speaks over the loudspeakers")
	# --- the new calls of the squad: a word for a good shot, the leader down, a pack
	if viper != null and scorpion != null:
		var player: Survivor = game.player
		var map := game.cabin as HiveMap
		hive.set_process(false)
		hive.lines.clear()
		_wipe_all(game)
		await frames(2)
		game.talk_until = 0
		game.round_called = true
		# Scorpion stands by the survivor, Viper has been sent far off.
		viper.order = "hold"
		viper.hold_point = map.points.forecourt
		viper.global_position = map.points.forecourt
		scorpion.global_position = player.global_position + Vector3(1.5, 0, 1.0)
		var beast: Infected = game.spawn_enemy("mauler")
		beast.position = player.global_position + Vector3(0, 0.08, -9.0)
		var freak: Infected = game.spawn_enemy("striker")
		freak.position = player.global_position + Vector3(2.0, 0.08, -9.0)
		game.bark_until.clear()
		var plain: bool = not game.praise(beast, false, true)
		var praised: bool = game.praise(beast, true, true) and game.bark_until.has("call_praise")
		var again: bool = not game.praise(beast, true, true)
		game.bark_until.clear()
		var special: bool = game.praise(freak, false, true)
		game.bark_until.clear()
		scorpion.down = true
		var nobody: bool = not game.praise(freak, true, true)
		scorpion.down = false
		_wipe_all(game)
		await frames(2)
		expect(plain and praised and again and special and nobody and Radio.bark("phantom", "praise").size() > 0 and Radio.bark("main", "praise").is_empty(), "Whoever of the squad stands near has a word for a shot to the head or a special infected brought down by the survivor - not for an ordinary kill, not twice in a row, and nobody from far off")
		# The survivor goes down: the one who comes for him says so, once.
		game.bark_until.clear()
		player.go_down()
		for turn in range(40):
			await get_tree().physics_frame
			if game.bark_until.has("call_leader_down"):
				break
		var coming: bool = game.bark_until.has("call_leader_down") and scorpion.leader_called and not viper.leader_called and game.rescuer() == scorpion
		player.get_up()
		player.health = 100.0
		await get_tree().physics_frame
		await get_tree().physics_frame
		# A pack around one of the squad: he says so, and the squad not again for a while.
		game.bark_until.clear()
		for index in range(Teammate.HORDE_COUNT):
			var one: Infected = game.spawn_enemy("mauler")
			one.position = scorpion.global_position + Vector3(cos(index * 1.05) * 4.0, 0.08, sin(index * 1.05) * 4.0)
		for turn in range(120):
			await get_tree().physics_frame
			if game.bark_until.has("call_horde"):
				break
		var packed: bool = game.bark_until.has("call_horde") and scorpion.crowd >= Teammate.HORDE_COUNT and not game.squad_says(scorpion, "horde", Teammate.HORDE_PAUSE)
		_wipe_all(game)
		viper.order = "follow"
		expect(coming and not scorpion.leader_called and packed and Radio.BARKS.has("low_ammo") and Radio.BARKS.leader_down.has("ghost"), "When the survivor goes down the one who comes for him calls it out, once; a pack around one of the squad is called out, and not again right away")
		hive.set_process(true)
	# --- the arrival is filmed: what command says meanwhile is read on the lower bar
	game.story_in_checks = true
	game.radio_queue.clear()
	game.radio_busy = 0.0
	game.start_run()
	await frames(3)
	await _turn(hive)
	await _turn(hive)
	var filmed: bool = hive.intro_left > 0.0 and not hud.play_ui.visible and is_instance_valid(hive.caption) and hive.caption.text.begins_with("COLEMAN:") and hive.caption.text == hud.radio_label.text
	hive._end_intro()
	await frames(2)
	expect(filmed and not is_instance_valid(hive.caption) and hud.play_ui.visible and hud.radio_left >= 3.0 and game.player.controlled, "While the arrival at the villa is filmed, command's first words are read on the lower bar of the picture, and after it on the radio's panel for long enough")
	game.story_in_checks = false
	Radio.hijacked = false
	await _company(game)
	game.return_to_menu()
	await frames(2)
	profile.mission = kept_mission
	game.team_enabled = false
	game.start_run()
	await frames(2)

## Who goes on from the station of the second mission (v0.29): the squad, or two of the
## three operators, chosen in the main menu. Whoever stays or goes says why.
func _company(game: Node3D) -> void:
	var hive: HiveDirector = game.hive
	var hud: SurvivalHUD = game.hud
	var profile: Profile = game.profile
	var kept: String = profile.company
	var kept_squad: Array = profile.squad.duplicate()
	# --- the switch: only for the second mission, four choices, and the menu still fits
	profile.company = "fireteam"
	profile.mission = 2
	game.return_to_menu()
	await frames(2)
	var labels: Array[String] = []
	var widest := 0.0
	var bottom := 0.0
	for step in range(5):
		var button: Button = null
		for node in hud.modal.find_children("*", "Button", true, false):
			if (node as Button).text.begins_with("BEGLEITER AB BAHNHOF"):
				button = node as Button
		if button == null:
			break
		labels.append(button.text.trim_prefix("BEGLEITER AB BAHNHOF  ·  "))
		widest = maxf(widest, button.get_combined_minimum_size().x)
		for node in hud.modal.get_children():
			if node is VBoxContainer:
				bottom = maxf(bottom, (node as VBoxContainer).position.y + (node as VBoxContainer).get_combined_minimum_size().y)
		hud._next_company()
	profile.mission = 1
	hud.show_menu("main")
	var absent := true
	for node in hud.modal.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("BEGLEITER"):
			absent = false
	profile.mission = 2
	var understood: bool = Profile.known_company("operators") == "phantom_havoc" and Profile.known_company("") == "fireteam" and Profile.known_company("havoc_ghost") == "havoc_ghost" and Profile.pair_of("havoc_ghost") == ["havoc", "ghost"] and Profile.pair_of("fireteam").is_empty()
	expect(labels == ["FIRETEAM", "PHANTOM + HAVOC", "PHANTOM + GHOST", "HAVOC + GHOST", "FIRETEAM"] and absent and understood and profile.company == "phantom_havoc" and bottom > 300.0 and bottom <= 720.0 and widest <= 430.0, "For the second mission the main menu asks who goes on from the station: the squad, or two of the three operators; the first mission is not asked, a choice kept by an older version is understood, and the menu still fits the screen (it ends at %d of 720, the switch is %d wide, %s)" % [int(bottom), int(widest), str(labels)])
	# --- the squad goes on: the three operators say why they stay, and Ghost keeps the relay
	var read: Array[String] = await _settle(game, "fireteam", ["viper", "scorpion"])
	var plain: bool = _tail(read, [["viper", "m2_colonel"], ["scorpion", "m2_colonel"], ["phantom", "m2_p_tunnel"], ["havoc", "m2_a_havoc"], ["ghost", "m2_a_ghost"], ["viper", "m2_a_viper"], ["scorpion", "m2_a_scorpion"], ["coleman", "m2_a_coleman"]])
	plain = plain and _looks(game.team) == ["viper", "scorpion"] and hive.puppets.is_empty() and hive.stayed.is_empty() and _posts(hive) == ["ghost:relay"]
	# --- Phantom and Havoc go: Ghost stays on the relay, the squad says why it holds the station
	read = await _settle(game, "phantom_havoc", ["viper", "scorpion"])
	var first: bool = _tail(read, [["viper", "m2_colonel"], ["scorpion", "m2_colonel"], ["phantom", "m2_p_join"], ["phantom", "m2_b_phantom"], ["havoc", "m2_b_havoc"], ["ghost", "m2_a_ghost"], ["viper", "m2_b_viper"], ["scorpion", "m2_b_scorpion"], ["coleman", "m2_b_coleman"]])
	var armed := true
	for mate: Teammate in game.team:
		armed = armed and not mate.unarmed and game.survivors.has(mate) and mate.label == str(Radio.NAMES[mate.look]) and mate.name_tag.visible
	var out_of_it := true
	for leaver: Dictionary in hive.leavers:
		var stayer: Teammate = leaver.node
		out_of_it = out_of_it and stayer.unarmed and not game.team.has(stayer) and not game.survivors.has(stayer) and str(stayer.order) == "hold" and not stayer.name_tag.visible
	first = first and _looks(game.team) == ["phantom", "havoc"] and armed and out_of_it and game.team[1].gun == Teammate.GUNS.shotgun and game.extra_guns() == 2 and hive.stayed == ["viper", "scorpion"] and _posts(hive) == ["viper:tunnel", "scorpion:tunnel", "ghost:relay"] and hive.puppets.is_empty()
	# Later only the one who stayed calls over the radio.
	hive.lines.clear()
	var before_calls: String = hud.radio_label.text
	hive.line("m2_p_alive")
	hive.line("m2_h_tunnel")
	hive.line_left = 0.0
	await _turn(hive)
	var silent: bool = hud.radio_label.text == before_calls and hive.lines.is_empty()
	hive.line("m2_g_list")
	hive.line_left = 0.0
	await _turn(hive)
	silent = silent and hud.radio_label.text == _words("ghost", "m2_g_list")
	# The squad is gone once it has reached the tunnel; when the doors of the train open
	# Viper calls a last word over from there; and once the train has left nobody is seen.
	for leaver: Dictionary in hive.leavers:
		(leaver.node as Teammate).global_position = (leaver.node as Teammate).hold_point
	hive.line_left = 0.0
	await _turn(hive)
	await _turn(hive)
	var gone: bool = _posts(hive) == ["ghost:relay"]
	hive.lines.clear()
	hive._enter("board")
	read.clear()
	var shown: String = hud.radio_label.text
	for turn in range(6):
		hive.line_left = 0.0
		await _turn(hive)
		if hud.radio_label.text != shown:
			shown = hud.radio_label.text
			read.append(shown)
	var parting: bool = read == [_words("coleman", "m2_board"), _words("viper", "m2_stay")]
	hive._station_left()
	await frames(2)
	gone = gone and hive.leavers.is_empty() and hive.puppets.is_empty()
	# A companion who goes down gets up again by himself: none of them dies.
	var rises := false
	if game.team.size() == 2:
		var fallen: Teammate = game.team[1]
		fallen._go_down(Vector3.INF)
		fallen.down_left = 0.05
		for turn in range(30):
			await get_tree().physics_frame
			if not fallen.down:
				break
		rises = not fallen.down and fallen.health > 0.0
	if not (plain and first and silent and gone and parting and rises):
		print("COMPANY plain=%s first=%s silent=%s gone=%s parting=%s rises=%s posts=%s read=%s" % [plain, first, silent, gone, parting, rises, str(_posts(hive)), str(read)])
	expect(plain and first and silent and gone and parting and rises, "When the squad goes on, the three operators say why they stay and Ghost keeps the relay; when Phantom and Havoc go, they are the survivor's two companions, armed like the squad, Ghost stays on the relay and is the only one who calls later, the squad says why it holds the station, leaves the fight, and Viper calls a last word when the doors of the train open")
	# --- the other two pairs, with Raven in the squad: she keeps the relay when Ghost goes
	read = await _settle(game, "phantom_ghost", ["scorpion", "raven"])
	var second: bool = _tail(read, [["scorpion", "m2_colonel"], ["raven", "m2_colonel"], ["phantom", "m2_p_join"], ["phantom", "m2_b_phantom"], ["ghost", "m2_b_ghost"], ["havoc", "m2_a_havoc"], ["scorpion", "m2_b_scorpion"], ["raven", "m2_b_raven"], ["coleman", "m2_b_coleman"]])
	second = second and _looks(game.team) == ["phantom", "ghost"] and _posts(hive) == ["scorpion:tunnel", "raven:relay"] and hive.puppets.is_empty()
	read = await _settle(game, "havoc_ghost", ["viper", "scorpion"])
	var third: bool = _tail(read, [["viper", "m2_colonel"], ["scorpion", "m2_colonel"], ["havoc", "m2_c_havoc"], ["ghost", "m2_b_ghost"], ["havoc", "m2_b_havoc"], ["phantom", "m2_c_phantom"], ["viper", "m2_b_viper"], ["scorpion", "m2_b_scorpion"], ["coleman", "m2_b_coleman"]])
	third = third and _looks(game.team) == ["havoc", "ghost"] and _posts(hive) == ["viper:tunnel", "scorpion:tunnel"] and hive.puppets.is_empty()
	# When Ghost keeps the relay himself, Raven has her other word for staying.
	read = await _settle(game, "phantom_havoc", ["viper", "raven"])
	var other: bool = _tail(read, [["viper", "m2_colonel"], ["raven", "m2_colonel"], ["phantom", "m2_p_join"], ["phantom", "m2_b_phantom"], ["havoc", "m2_b_havoc"], ["ghost", "m2_a_ghost"], ["viper", "m2_b_viper"], ["raven", "m2_stay"], ["coleman", "m2_b_coleman"]])
	other = other and _posts(hive) == ["viper:tunnel", "raven:tunnel", "ghost:relay"]
	if not (second and third and other):
		print("COMPANY second=%s third=%s other=%s posts=%s read=%s" % [second, third, other, str(_posts(hive)), str(read)])
	expect(second and third and other, "Whichever two of the operators go, the talk fits: Phantom and Ghost go and Havoc stays for the tunnel, Havoc and Ghost go and Phantom stays for it, and Raven keeps the relay when Ghost goes - or has another word when he keeps it himself")
	# --- the train is brought up while they are still talking: command's word about it
	# comes first, they talk on over it, and nobody is gone before he has said his part
	profile.company = "fireteam"
	profile.squad = ["viper", "scorpion"]
	game.radio_queue.clear()
	game.radio_busy = 0.0
	game.start_run()
	await frames(3)
	await _turn(hive)
	hive.lines.clear()
	hive._enter("deal")
	for turn in range(120):
		if hive.stage == "power":
			break
		hive.line_left = 0.0
		hive.hold_left = 0.0
		await _turn(hive)
	var waiting: int = hive.lines.size()
	hive._enter("hold")
	var at_once: bool = hive.stage == "hold" and hive.done.has("parted") and waiting >= 8 and str(hive.lines[0].get("cue", "")) == "m2_power" and hive.puppets.size() == 2 and _posts(hive) == ["ghost:relay"]
	for puppet: Dictionary in hive.puppets:
		(puppet.node as Node3D).global_position = puppet.goal
	hive.line_left = 0.0
	await _turn(hive)
	var power_first: bool = hud.radio_label.text == _words("coleman", "m2_power") and hive.puppets.size() == 2
	read.clear()
	shown = hud.radio_label.text
	for turn in range(60):
		if hive.lines.is_empty() and hive.puppets.is_empty():
			break
		hive.line_left = 0.0
		await _turn(hive)
		if hud.radio_label.text != shown:
			shown = hud.radio_label.text
			read.append(shown)
	var talked_on: bool = _tail(read, [["phantom", "m2_p_tunnel"], ["havoc", "m2_a_havoc"], ["ghost", "m2_a_ghost"], ["viper", "m2_a_viper"], ["scorpion", "m2_a_scorpion"], ["coleman", "m2_a_coleman"]]) and hive.puppets.is_empty() and hive.stage == "hold"
	if not (at_once and power_first and talked_on):
		print("COMPANY at_once=%s power_first=%s talked_on=%s waiting=%d read=%s" % [at_once, power_first, talked_on, waiting, str(read)])
	expect(at_once and power_first and talked_on, "The train can be brought up while they are still talking it over: the roads part at once, command's word about the train is the next thing said, the talk goes on over the fight, and the two who walk into the tunnel are not gone before they have said their part")
	# --- a night taken up behind the station begins with the chosen two, before it with the squad
	profile.company = "havoc_ghost"
	hive.resume_at = "terminal"
	game.start_run()
	await frames(3)
	var resumed: Array[String] = _looks(game.team)
	var counted: bool = game.team.size() == 2 and game.survivors.has(game.team[0]) and hive.leavers.is_empty()
	# (A choice kept by v0.25 to v0.28, when all three came along, is Phantom and Havoc.)
	profile.company = "operators"
	hive.resume_at = "descent"
	game.start_run()
	await frames(3)
	expect(resumed == ["havoc", "ghost"] and counted and _looks(game.team) == ["viper", "scorpion"] and hive.company == "phantom_havoc" and hive.pair == ["phantom", "havoc"], "Taken up behind the station the night begins with the two chosen operators at the survivor's side, taken up before it with the squad")
	profile.company = kept
	profile.squad = kept_squad
	Radio.hijacked = false

## A night of the second mission in which the talk at the station is played for one choice
## of company and one squad, every line over as soon as it has begun, until the roads have
## parted. Returns what was read on the radio's panel, in its order.
func _settle(game: Node3D, company: String, squad: Array) -> Array[String]:
	var hive: HiveDirector = game.hive
	var hud: SurvivalHUD = game.hud
	game.profile.company = company
	game.profile.squad = squad
	game.team_enabled = true
	game.radio_queue.clear()
	game.radio_busy = 0.0
	game.start_run()
	await frames(3)
	await _turn(hive)
	hive.lines.clear()
	hive._enter("deal")
	var read: Array[String] = []
	var shown: String = hud.radio_label.text
	for turn in range(240):
		if hive.done.has("parted") and hive.lines.is_empty() and hive.puppets.is_empty():
			break
		hive.line_left = 0.0
		hive.hold_left = 0.0
		for puppet: Dictionary in hive.puppets:
			if bool(puppet.leaving) and is_instance_valid(puppet.node):
				(puppet.node as Node3D).global_position = puppet.goal
		await _turn(hive)
		if hud.radio_label.text != shown:
			shown = hud.radio_label.text
			read.append(shown)
	return read

## What stands on the radio's panel when a speaker says the first variant of a line.
func _words(speaker: String, cue: String) -> String:
	var variants: Array = Radio.BARKS[cue][speaker] if Radio.BARKS.has(cue) and (Radio.BARKS[cue] as Dictionary).has(speaker) else Radio.LINES[cue][1]
	return "%s:  %s" % [Radio.NAMES[speaker], variants[0]]

## Whether what was read ends with these lines ([speaker, cue] each), in this order.
func _tail(read: Array[String], parts: Array) -> bool:
	if read.size() < parts.size():
		return false
	for index in range(parts.size()):
		if read[read.size() - parts.size() + index] != _words(str(parts[index][0]), str(parts[index][1])):
			return false
	return true

func _looks(team: Array) -> Array[String]:
	var looks: Array[String] = []
	for mate: Teammate in team:
		looks.append(mate.look)
	return looks

## Who stays at the station and where his post is: "look:relay" or "look:tunnel".
func _posts(hive: HiveDirector) -> Array[String]:
	var posts: Array[String] = []
	for leaver: Dictionary in hive.leavers:
		if is_instance_valid(leaver.node):
			var stayer: Teammate = leaver.node
			var relay: bool = stayer.hold_point.distance_to(hive._point("radio")) < 0.5
			posts.append("%s:%s" % [stayer.look, "relay" if relay and bool(leaver.keep) else ("tunnel" if stayer.hold_point.distance_to(hive._point("ops_from")) < 3.0 and not bool(leaver.keep) else "?")])
	return posts


func map_point(game: Node3D, id: String) -> Vector3:
	return (game.cabin as HiveMap).points[id]

## What came with v0.7: voices, the C.R.U., six more weapons, more errands, skins.
func _newer(game: Node3D) -> void:
	var cabin: CabinMap = game.cabin
	var mission: MissionDirector = game.mission
	# --- voices
	var opening := Radio.pick("mission_start")
	expect(str(opening.sound) != "" and ResourceLoader.exists(str(opening.sound)) and opening.name == "COLEMAN", "Coleman's radio lines are recorded")
	# For this check only the first variant of the cue counts as recorded.
	var horde: Array = Radio.LINES.round_horde[1]
	var hidden: Array = []
	for i in range(1, horde.size()):
		hidden.append("%s%s/round_horde_%d.ogg" % [Radio.VOICE_FOLDER, str(Radio.LINES.round_horde[0]), i + 1])
		Radio.known[hidden[-1]] = false
	var same := true
	for i in range(8):
		same = same and str(Radio.pick("round_horde").text) == str(horde[0])
	for path in hidden:
		Radio.known.erase(path)
	expect(horde.size() > 1 and same, "A cue with one recorded variant is never read from another one")
	expect(str(Radio.bark("viper", "reload").sound) != "" and str(Radio.bark("scorpion", "kill").sound) != "" and str(Radio.bark("cru", "contact").sound) != "" and Radio.bark("main", "reload").is_empty(), "The squad and the C.R.U. have recorded calls")
	game.start_run()
	game.radio_queue.clear()
	game.radio_busy = 0.0
	game._say("round_begin")
	game._say("round_clear")
	expect(game.radio_queue.size() == 1 and game.radio_busy > 1.0, "A radio line waits until the one before is over")
	game._run_radio(60.0)
	expect(game.radio_queue.is_empty(), "A waiting radio line follows when the channel is free")
	expect(game.bark(game.player, "viper", "reload") and not game.bark(game.player, "viper", "kill"), "Nobody calls out two things at once")
	# --- the C.R.U.
	face(game, Vector3(0, 0.05, 22.0), PI)
	var trooper := game.spawn_enemy("cru_assault") as CruSoldier
	# It keeps its grenade until the check asks for it.
	trooper.grenades = 0
	expect(trooper != null and trooper.model is CruVisual and trooper.spec.human, "A C.R.U. soldier is an armed human")
	trooper.position = Vector3(0, 0.05, 35.0)
	await wait(4.5)
	expect(trooper.ammo < int(trooper.role.magazine) and game.player.health < 100.0, "A C.R.U. soldier shoots at a survivor it can see")
	trooper.roll_wait = 0.0
	trooper.threatened(true)
	expect(trooper.roll_left > 0.0, "A near miss makes a C.R.U. soldier throw itself aside")
	await wait(1.0)
	trooper.grenades = 1
	var bombs_before: int = game.ordnance.get_child_count()
	trooper.throw_grenade(game.player.global_position, 13.0, true)
	await wait(0.7)
	var thrown: Throwable = null
	for node in game.ordnance.get_children():
		if node is Throwable and node.hostile:
			thrown = node
	expect(thrown != null and game.ordnance.get_child_count() == bombs_before + 1 and trooper.grenades == 0, "A C.R.U. soldier throws a grenade")
	if thrown != null:
		thrown.queue_free()
	var cru_before: int = game.stats.cru_kills
	trooper.receive_hit(9999.0, Vector3.FORWARD)
	expect(trooper.dead and game.stats.cru_kills == cru_before + 1, "A fallen C.R.U. soldier is counted on its own")
	game.wave = 6
	mission.wave_kind = "cru"
	var squad := mission.squad()
	expect(squad.size() == 5 and squad.has("cru_elite") and squad.has("cru_marksman") and game.mission.squad(9.0).has("cru_commander"), "A C.R.U. squad grows with the rounds and brings specialists")
	mission.plan[6] = {"wave": "cru", "tasks": []}
	game.spawn_queue.clear()
	game.begin_wave()
	var soldiers := 0
	for kind in game.spawn_queue:
		if kind.begins_with("cru_"):
			soldiers += 1
	expect(mission.wave_kind == "cru" and soldiers == 6 and game.spawn_queue.size() - soldiers <= 3, "A C.R.U. round brings a squad and hardly any infected")
	game.spawn_queue.clear()
	mission.wave_kind = "classic"
	expect(float(Profile.DIFFICULTIES.hard.tactics) > float(Profile.DIFFICULTIES.easy.tactics), "A harder night makes the C.R.U. sharper")
	# --- the newer weapons
	game.start_run()
	face(game, Vector3(0, 0.05, 22.0), PI)
	var first: Infected = game.spawn_enemy("mauler")
	var second: Infected = game.spawn_enemy("mauler")
	first.position = Vector3(0, 0.05, 30.0)
	second.position = Vector3(0, 0.05, 33.0)
	first.set_physics_process(false)
	second.set_physics_process(false)
	await frames(4)
	var player: Survivor = game.player
	expect(player.unlock("sniper") and player.current_weapon == "sniper" and player.ammo == 5, "The sniper rifle can be taken in hand")
	player.shot_cooldown = 0.0
	player.shoot()
	expect(first.dead and second.dead and player.ammo == 4 and player.bolt_clock >= 0.0, "A sniper bullet goes through two bodies, then the bolt is worked")
	player.unlock("launcher")
	player.shot_cooldown = 0.0
	var shells_before: int = game.ordnance.get_child_count()
	player.shoot()
	var shell: Throwable = game.ordnance.get_child(game.ordnance.get_child_count() - 1) as Throwable
	expect(game.ordnance.get_child_count() == shells_before + 1 and shell != null and shell.impact and player.ammo == 5, "The launcher fires a grenade that goes off on impact")
	if shell != null:
		shell.queue_free()
	player.unlock("minigun")
	var cold: bool = player.spin < 1.0
	player._spin(0.3, true)
	player._spin(0.3, true)
	player.shot_cooldown = 0.0
	player.shoot()
	expect(cold and player.spin >= 1.0 and player.ammo == 199, "The rotary gun fires once its barrels are up to speed")
	player.unlock("autoshotgun")
	player.shot_cooldown = 0.0
	player.shoot()
	expect(player.ammo == 7 and player.pump_clock < 0.0, "The automatic shotgun needs no pump stroke")
	expect(player.unlock("pistol") and player.ammo == 15 and player.unlock("revolver") and player.ammo == 6 and int(Survivor.WEAPONS.minigun.from_round) > int(Survivor.WEAPONS.launcher.from_round), "Two handguns are on sale, the heaviest weapons only late in the night")
	# --- holding a position
	game.start_run()
	var hold: Dictionary = mission._start_task("zone")
	var ground: Vector3 = hold.items[0].pos
	face(game, Vector3(0, 0.05, 2.5), PI)
	mission.update(1.0)
	expect(float(hold.items[0].use) == 0.0 and "Position halten" in mission.summary()[0], "A position waits for somebody to stand on it")
	face(game, ground + Vector3(1.0, 0.05, 0), 0.0)
	for step in range(100):
		if hold.state == "active":
			mission.update(0.5)
	expect(hold.state == "done" and game.stats.objectives == 1, "Standing on the marked ground long enough holds the position")
	# --- skins
	var profile: Profile = game.profile
	var wins: int = profile.totals.victories
	profile.totals.victories = 0
	var locked: bool = not profile.unlocked("raven")
	profile.enlist("raven")
	var kept: bool = not profile.squad.has("raven")
	profile.totals.victories = 1
	profile.enlist("raven")
	profile.wear("raven")
	expect(locked and kept and profile.squad.has("raven") and profile.skin == "raven" and profile.squad.size() == 2, "Finishing a night unlocks Raven for the squad, and wearing her skin does not take her out of it")
	game.team_enabled = true
	game.start_run()
	var looks: Array = []
	for mate in game.team:
		looks.append(mate.look)
	expect(looks.has("raven") and looks.size() == 2, "The chosen squad comes along")
	game.team_enabled = false
	profile.totals.victories = wins
	profile.skin = "main"
	profile.squad = ["viper", "scorpion"]
	game.start_run()

## Below this much health the bot of --bot-check is healed at once.
const BOT_FLOOR := 70.0

## The enemies within reach of the survivor, nearest first, for the bot's log.
func _near(game: Node3D, reach: float) -> String:
	var found: Array = []
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		var distance := enemy.global_position.distance_to(game.player.global_position)
		if distance <= reach and not enemy.dead:
			found.append([distance, "%s %.1fm %s" % [enemy.kind, distance, enemy.model.state]])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var names: Array = []
	for entry in found.slice(0, 6):
		names.append(entry[1])
	return "[" + ", ".join(PackedStringArray(names)) + "]"

## Run with -- --bot-check [--bot-seconds=180] [--bot-pos=x,z] [--bot-round=1]
## [--bot-speed=4] [--bot-mode=endless] [--bot-level=hard] [--bot-duel=ghost]
## [--bot-company=phantom_havoc|phantom_ghost|havoc_ghost] [--bot-weapon=mp7 or
## mp7:silencer,reddot: the weapon the bot fights the night with, and what is fitted to
## it]. With a window (no --headless)
## it also reports the frame rate; use
## --bot-speed=1 for numbers that match real play. A simple aim-bot holds a
## position while the real spawner runs, which exercises navigation, special infected and
## round flow over a long stretch and reports infected that get stuck on the way.
func bot(game: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var limit := 180.0
	var post := Vector3(0, 0.05, 2.6)
	var first_round := 1
	var pace := 4.0
	var frames_seen := 0
	var frame_time := 0.0
	var slowest := 0.0
	var hitches := 0
	# --bot-duel=ghost: no round, only this one operator of round --bot-round against the bot.
	var duel := ""
	var hunter: Operator = null
	var harm := 0.0
	var next_look := 2.0
	var next_grenade := 0.0
	# --bot-weapon=mg2 or --bot-weapon=mp7:silencer,reddot: what the bot shoots with.
	var arm := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bot-weapon="):
			arm = arg.trim_prefix("--bot-weapon=")
		if arg.begins_with("--bot-round="):
			first_round = int(arg.trim_prefix("--bot-round="))
		if arg.begins_with("--bot-seconds="):
			limit = float(arg.trim_prefix("--bot-seconds="))
		if arg.begins_with("--bot-pos="):
			var parts := arg.trim_prefix("--bot-pos=").split(",")
			post = Vector3(float(parts[0]), 0.05, float(parts[1]))
		if arg.begins_with("--bot-speed="):
			pace = maxf(0.25, float(arg.trim_prefix("--bot-speed=")))
		# Only for this run: nothing of it is saved.
		if arg.begins_with("--bot-duel="):
			duel = arg.trim_prefix("--bot-duel=")
		if arg.begins_with("--bot-mode="):
			game.profile.mode = arg.trim_prefix("--bot-mode=")
			# --bot-mode=villa: the second mission.
			if game.profile.mode == "villa":
				game.profile.mode = "story"
				game.profile.mission = 2
		if arg.begins_with("--bot-level="):
			game.profile.difficulty = arg.trim_prefix("--bot-level=")
		# --bot-company=phantom_ghost: in the second mission those two operators go on from the
		# station (also phantom_havoc, havoc_ghost; "operators" is understood as phantom_havoc).
		if arg.begins_with("--bot-company="):
			game.profile.company = arg.trim_prefix("--bot-company=")
	Engine.time_scale = pace
	await wait(1.0)
	game.start_run()
	# On the map of the second mission the bot walks instead (--bot-mode=villa).
	if game.hive.on:
		await _hive_bot(game, limit)
		return
	# The bot holds one spot and cannot do tasks: plain rounds, unless asked otherwise.
	if not "--bot-tasks" in OS.get_cmdline_user_args():
		game.mission.plain()
	game.wave = first_round - 1
	game.player.position = post
	# The bot does not run from gas in the house, so it gets the best mask there is.
	game.player.mask_level = 4
	game.player.filter_left = game.player.filter_capacity()
	if arm != "":
		var wanted: PackedStringArray = arm.split(":")
		if Survivor.WEAPONS.has(wanted[0]):
			game.player.unlock(wanted[0])
			if wanted.size() > 1 and Survivor.ATTACHMENTS.has(wanted[0]):
				for part in wanted[1].split(","):
					if (Survivor.ATTACHMENTS[wanted[0]] as Dictionary).has(part):
						game.player.fit(wanted[0], part)
		print("BOT_WEAPON %s label=%s sound=%s fitted=%s" % [game.player.current_weapon, game.player.weapon_label(), str(game.player.gun().sound), str(game.player.inventory[game.player.current_weapon].get("fitted", {}))])
	var heals := 0
	var blasts := 0
	var watched := {}
	var stuck := {}
	var next_report := 15.0
	var seen := {"mauler": 0, "charger": 0, "striker": 0, "ripper": 0, "crusher": 0}
	var counted := {}
	var last_phase := "preparing"
	var wave_began := 0.0
	var durations: Array[String] = []
	var last_tick := Time.get_ticks_usec()
	var last_frame := Engine.get_process_frames()
	if duel != "":
		game.preparation_left = 99999.0
		game.wave = first_round
		hunter = game.spawn_enemy(duel) as Operator
	var health_before: float = game.player.health
	var was_down := false
	var blows := 0
	while game.state == "playing" and game.elapsed < limit:
		await get_tree().physics_frame
		# What hits hard, and what takes the survivor off his feet.
		var lost: float = health_before - game.player.health
		harm += maxf(0.0, lost)
		if duel != "":
			if not is_instance_valid(hunter):
				print("BOT_DUEL over at t=%.1f harm=%.0f driven_off=%d" % [game.elapsed, harm, int(game.stats.get(duel, 0))])
				break
			if game.elapsed >= next_look:
				next_look += 2.0
				print("BOT_DUEL t=%05.1f gap=%4.1f bar=%.2f absent=%s leaving=%s aiming=%s state=%s at=%s harm=%.0f mates_up=%d" % [game.elapsed, hunter.global_position.distance_to(game.player.global_position), hunter.health / hunter.max_health, str(hunter.absent), str(hunter.leaving), str((hunter.model as CruVisual).aiming), hunter.model.state, str(hunter.global_position.snapped(Vector3.ONE * 0.1)), harm, game.team.filter(func(mate: Teammate) -> bool: return not mate.down).size()])
		if (lost >= 30.0 and blows < 40) or (game.player.down and not was_down) or game.state != "playing":
			blows += 1
			print("BOT_BLOW -%.0f at t=%.1f round=%d left=%.0f down=%s state=%s mates_up=%d near=%s" % [lost, game.elapsed, game.wave, game.player.health, str(game.player.down), game.state, game.team.filter(func(mate: Teammate) -> bool: return not mate.down).size(), _near(game, 7.0)])
		was_down = game.player.down
		# Frame times of rendered frames, once the first second of loading is over.
		if Engine.get_process_frames() != last_frame:
			var now := Time.get_ticks_usec()
			var spent := (now - last_tick) / 1000.0 / float(Engine.get_process_frames() - last_frame)
			last_tick = now
			last_frame = Engine.get_process_frames()
			if game.elapsed > 0.5:
				frames_seen += 1
				frame_time += spent
				slowest = maxf(slowest, spent)
				if spent > 60.0 and hitches < 12:
					hitches += 1
					var newest := "-"
					if game.enemies.get_child_count() > 0:
						var last_one := game.enemies.get_child(game.enemies.get_child_count() - 1) as Infected
						newest = "%s/%s" % [last_one.kind, last_one.visual_kind]
					print("BOT_HITCH %.0f ms at t=%.1f round=%d alive=%d spawned=%d growths=%d clouds=%d decals=%d flash=%.2f brownout=%.2f newest=%s process=%.1f ms physics=%.1f ms" % [spent, game.elapsed, game.wave, game.alive_count, game.spawned_this_wave, game.fx.growths.size(), game.fx.clouds.size(), game.fx.decals.size(), game.cabin.flash_left, game.cabin.brownout_left, newest, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		if game.phase == "preparing" and duel == "":
			game.preparation_left = minf(game.preparation_left, 1.0)
		if game.phase != last_phase:
			if game.phase == "wave":
				wave_began = game.elapsed
			else:
				durations.append("%d:%ds" % [game.wave, int(game.elapsed - wave_began)])
			last_phase = game.phase
		# The bot is here to see the whole night, not to survive it: nothing that hits takes
		# more than BOT_FLOOR at once (the Crusher's blow with its quake comes to 62).
		if game.player.health < BOT_FLOOR:
			game.player.health = 100
			heals += 1
		health_before = game.player.health
		if game.player.reserve == 0:
			game.player.reserve = game.player.max_reserve()
		blasts = maxi(blasts, game.fx.growths.size())
		var best: Infected = null
		var best_distance := 2000.0
		for node in get_tree().get_nodes_in_group("infected"):
			var enemy := node as Infected
			var id := enemy.get_instance_id()
			if not counted.has(id):
				counted[id] = true
				seen[enemy.kind] = int(seen.get(enemy.kind, 0)) + 1
			var distance := enemy.global_position.distance_to(game.player.global_position)
			# An infected that barely moves for a long while, far from its target, is stuck.
			# (Soldiers and operators hold a post and shoot from it: they do not count.)
			var record: Dictionary = watched.get(id, {"pos": enemy.global_position, "since": game.elapsed})
			if record.pos.distance_to(enemy.global_position) > 0.6:
				record = {"pos": enemy.global_position, "since": game.elapsed}
			elif game.elapsed - float(record.since) > 7.0 and distance > 3.5 and not stuck.has(id) and enemy.kind != "stalker" and not enemy.spec.get("human", false) and not (enemy.kind == "healer" and distance < Infected.CLOUD_KEEP + 1.0):
				stuck[id] = "%s at %s (player %.1f m away) state=%s alert=%s held=%.1f attack=%.1f path=%d/%d floor=%s speed=%.2f" % [enemy.kind, enemy.global_position.snapped(Vector3.ONE * 0.1), distance, enemy.model.state, str(enemy.alert), enemy.held_left, enemy.attack_clock, enemy.path_index, enemy.path.size(), str(enemy.is_on_floor()), enemy.get_real_velocity().length()]
				for i in range(enemy.get_slide_collision_count()):
					var other: Object = enemy.get_slide_collision(i).get_collider()
					if other is Infected:
						var blocker := other as Infected
						stuck[id] += " | blocked by %s at %s dead=%s state=%s held=%.1f attack=%.1f cd=%.1f hp=%d dist=%.1f fuse=%.1f" % [blocker.kind, blocker.global_position.snapped(Vector3.ONE * 0.1), str(blocker.dead), blocker.model.state, blocker.held_left, blocker.attack_clock, blocker.cooldown, int(blocker.health), blocker.global_position.distance_to(game.player.global_position), blocker.fuse_left]
					elif other != null:
						stuck[id] += " | touching %s (%s)" % [str(other.get("name")), other.get_class()]
			watched[id] = record
			var eye: Vector3 = game.player.camera.global_position
			var aim: Vector3 = enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.62, 0)
			var query := PhysicsRayQueryParameters3D.create(eye, aim, 1)
			# Behind a shield that faces the bot: anybody else comes first.
			var rank := distance + (1000.0 if enemy.blocks(enemy.global_position - game.player.global_position) else 0.0)
			if distance < 40.0 and rank < best_distance and get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty():
				best = enemy
				best_distance = rank
		if best != null:
			var to: Vector3 = best.global_position + Vector3(0, float(best.spec.height) * 0.62, 0) - game.player.camera.global_position
			game.player.rotation.y = atan2(-to.x, -to.z)
			game.player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
			if best_distance < 1000.0:
				game.player.shoot()
			elif game.elapsed >= next_grenade:
				# Only he is left, and the bot cannot walk round him: a grenade does.
				next_grenade = game.elapsed + 3.0
				game.player.items.grenade = 1
				game.player.throw_cooldown = 0.0
				game.player.throw("grenade")
		game.player.position.x = post.x
		game.player.position.z = post.z
		if game.elapsed >= next_report:
			next_report += 15.0
			print("BOT t=%03d round=%d alive=%d queued=%d kills=%d score=%d hp=%d heals=%d" % [int(game.elapsed), game.wave, game.alive_count, game.remaining_to_spawn, game.kills, game.score, int(game.player.health), heals])
	# Rain and wind are short loops; after minutes of play they must still be running.
	var squad_kills := 0
	for mate in game.team:
		squad_kills += mate.kills
	print("BOT_RESULT state=%s round=%d kills=%d squad_kills=%d score=%d heals=%d seen=%s stuck=%d weather_loops=%s" % [game.state, game.wave, game.kills, squad_kills, game.score, heals, str(seen), stuck.size(), str(game.sounds.rain.playing and game.sounds.ambience.playing)])
	print("BOT_ROUNDS ", " ".join(PackedStringArray(durations)))
	if frames_seen > 0 and DisplayServer.get_name() != "headless":
		print("BOT_FRAMES speed=%.1f average=%.1f ms (%.0f fps) slowest=%.0f ms frames=%d draw_calls=%d" % [pace, frame_time / frames_seen, 1000.0 * frames_seen / frame_time, slowest, frames_seen, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	for id in stuck:
		print("BOT_STUCK ", stuck[id])
	game.sounds.stop_all()
	Engine.time_scale = 1.0
	await wait(0.2)
	get_tree().call_deferred("quit", 0)

## Shoots the nearest infected in sight, like the bot run does. Returns true if it fired.
func _snap_shot(game: Node3D) -> bool:
	var best: Infected = null
	var best_distance := 45.0
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead:
			continue
		var distance := enemy.global_position.distance_to(game.player.global_position)
		var aim: Vector3 = enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.62, 0)
		var query := PhysicsRayQueryParameters3D.create(game.player.camera.global_position, aim, 1)
		if distance < best_distance and get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty():
			best = enemy
			best_distance = distance
	if best == null:
		return false
	var to: Vector3 = best.global_position + Vector3(0, float(best.spec.height) * 0.62, 0) - game.player.camera.global_position
	game.player.rotation.y = atan2(-to.x, -to.z)
	game.player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	game.player.shoot()
	return true

## Nobody is to attack while the story is walked through.
func _sweep(game: Node3D) -> void:
	game.spawn_queue.clear()
	game.mission.ambush_left = -1.0
	for foe in game.enemies.get_children():
		if foe is Infected and not foe.dead:
			foe.receive_hit(99999, Vector3.BACK)

## A quiet round for the story walk: begun, and over at once.
func _quiet_round(game: Node3D, finish: bool) -> void:
	game.begin_wave()
	game.spawn_queue.clear()
	await wait(0.5)
	if finish:
		for task in game.mission.tasks:
			if task.state == "active":
				task.state = "done"
		game.complete_wave()
		game.preparation_left = 9999.0

## The story in a co-op match. The host walks through its stations without a fight, the
## guest reports what of it arrived. Run both instances with --mp-story added.
func coop_story(game: Node3D, as_host: bool, tag: String) -> void:
	var cabin: CabinMap = game.cabin
	var story: StoryDirector = game.story
	var pad: Vector3 = cabin.points.landing
	if not as_host:
		var stages: Array = []
		var kinds: Array = []
		var puppet := false
		var machine := false
		var shut_at_first := false
		var first := true
		var patience := 0.0
		while game.state == "playing" and patience < 70.0:
			await wait(0.1)
			patience += 0.1
			if first and story.enabled:
				first = false
				shut_at_first = cabin.is_locked("upper") and cabin.is_locked("wing") and cabin.is_locked("cellar")
			if story.enabled and not stages.has(story.stage):
				stages.append(story.stage)
			for task in game.mission.tasks:
				if not kinds.has(task.kind):
					kinds.append(task.kind)
			puppet = puppet or is_instance_valid(story.nadja_puppet)
			machine = machine or is_instance_valid(story.heli)
			# The helicopter does not leave without the guest.
			if story.stage == "evac":
				game.player.position = pad + Vector3(2.0, 0.05, 2.5)
		await wait(0.5)
		print("%s_STORY state=%s enabled=%s shut_at_first=%s stages=%s tasks=%s open=%s nadja_seen=%s helicopter_seen=%s start=%s" % [tag, game.state, str(story.enabled), str(shut_at_first), str(stages), str(kinds), str(story.export_state()[3]), str(puppet), str(machine), str(game.player.position.distance_to(pad) < 12.0)])
		game.sounds.stop_all()
		await wait(0.3)
		get_tree().call_deferred("quit", 0)
		return
	var mission: MissionDirector = game.mission
	mission.plain()
	game.preparation_left = 9999.0
	await wait(1.5)
	print("%s story enabled=%s cellar_shut=%s" % [tag, str(story.enabled), str(cabin.is_locked("cellar"))])
	# Three rounds open the house, three errands give Nadja away.
	for i in range(3):
		await _quiet_round(game, true)
	for i in range(3):
		mission._finish(mission._start_task("crate"), true)
	await wait(0.6)
	# The module comes down, goes onto the cellar door and opens it.
	await _quiet_round(game, false)
	var drop: Dictionary = mission.task_of("module")
	drop.items[0].health = 0.2
	await wait(0.8)
	mission.apply_use(int(drop.id), 0, 99.0)
	await wait(0.6)
	var hack: Dictionary = mission.task_of("hack")
	mission.apply_use(int(hack.id), 0, 99.0)
	hack.jams = []
	hack.left = 0.3
	await wait(1.2)
	print("%s cellar open=%s stage=%s" % [tag, str(not cabin.is_locked("cellar")), story.stage])
	game.complete_wave()
	game.preparation_left = 9999.0
	# The drives, then her door: the tunnel is blown on the way, and she comes out.
	await _quiet_round(game, true)
	await _quiet_round(game, false)
	var rescue: Dictionary = mission.task_of("rescue")
	mission.apply_use(int(rescue.id), 0, 99.0)
	rescue.jams = []
	rescue.left = float(rescue.total) * 0.702
	await wait(0.8)
	_sweep(game)
	rescue.left = 0.3
	await wait(1.2)
	_sweep(game)
	print("%s rescue stage=%s nadja=%s tunnel_open=%s" % [tag, story.stage, str(is_instance_valid(story.nadja)), str(not cabin.is_locked("tunnel"))])
	await wait(2.0)
	# The last round: everybody to the helicopter. The host waits in the house until it
	# has landed and the guest stands beside it.
	game.player.position = (cabin.points.hall as Vector3) + Vector3(0, 0.05, 0)
	game.complete_wave()
	await _quiet_round(game, false)
	var evac: Dictionary = mission.task_of("evac")
	await wait(0.5)
	if not evac.is_empty():
		evac.left = 1.0
	await wait(2.2)
	var waiting: bool = game.state == "playing" and not evac.is_empty() and str(evac.items[0].state) == "landed"
	var guest_there: bool = is_instance_valid(game.net.remote) and game.net.remote.global_position.distance_to(pad) < 9.0
	print("%s helicopter waits=%s guest_at_pad=%s" % [tag, str(waiting), str(guest_there)])
	game.player.position = pad + Vector3(-2.0, 0.05, 2.0)
	if is_instance_valid(story.nadja):
		story.nadja.global_position = pad + Vector3(1.5, 0.05, -2.0)
	var patience := 0.0
	while game.state == "playing" and patience < 12.0:
		await wait(0.1)
		patience += 0.1
		_sweep(game)
	await wait(0.5)
	print("%s_STORY state=%s stage=%s wave=%d open=%s partner_aboard=%s" % [tag, game.state, story.stage, game.wave, str(story.export_state()[3]), str(guest_there)])
	game.sounds.stop_all()
	await wait(0.3)
	get_tree().call_deferred("quit", 0)

## Run two instances: one with -- --mp-host-test, one with -- --mp-join-test.
## Each plays the first rounds with a simple aim-bot and prints what it saw of the other.
func coop(game: Node3D, as_host: bool) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tag := "MP_HOST" if as_host else "MP_GUEST"
	# With --mp-story the two play the story instead of a fight.
	var story_run := "--mp-story" in OS.get_cmdline_user_args()
	if story_run:
		game.story_in_checks = true
		game.intro_skipped = true
	var seconds := 26.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mp-seconds="):
			seconds = float(arg.trim_prefix("--mp-seconds="))
	await wait(0.5)
	if as_host:
		game.host_match()
	else:
		# --mp-address=<address> joins a host somewhere else than on this machine (or this
		# machine by the router's address, which tells whether the router lets a guest in).
		var address := "127.0.0.1"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--mp-address="):
				address = arg.trim_prefix("--mp-address=")
		game.join_match(address)
	if "--mp-clash" in OS.get_cmdline_user_args():
		# One of the two was started as another version (--mp-version=): neither may get
		# into a match, and whoever can know why has to be told.
		var told := 0.0
		var met := false
		# (The side that plays an old version - "none" - is told nothing: it waits as long
		# as the other needs to find out.)
		while told < 14.0 and game.net.clash == "" and not (met and told > 6.0):
			await wait(0.25)
			told += 0.25
			met = met or game.net.partner != 0
		await wait(0.5)
		# What the lobby says, and whether a match could be started from it.
		var lobby := ""
		for node in game.hud.modal.find_children("*", "Label", true, false):
			if (node as Label).text.contains("VERSIONEN"):
				lobby = "shown"
		var start_open := false
		for node in game.hud.modal.find_children("*", "Button", true, false):
			if (node as Button).text.contains("EINSATZ ZU ZWEIT") and not (node as Button).disabled:
				start_open = true
		print("%s_CLASH after %.1fs met=%s phase=%s partner=%d matched=%s state=%s menu=%s lobby=%s start_open=%s clash=%s" % [tag, told, str(met), game.net.phase, game.net.partner, str(game.net.matched()), game.state, game.hud.current_menu, lobby, str(start_open), game.net.clash])
		# The host waits a moment longer, so that the guest is not cut off before it has printed.
		if as_host:
			await wait(2.5)
		get_tree().call_deferred("quit", 0)
		return
	var waited := 0.0
	while waited < 45.0 and (game.net.partner == 0 if as_host else game.state != "playing"):
		await wait(0.25)
		waited += 0.25
	print("%s connected=%s after %.1fs phase=%s" % [tag, str(game.net.partner != 0), waited, game.net.phase])
	if game.net.partner == 0:
		print("%s_RESULT no partner" % tag)
		get_tree().call_deferred("quit", 1)
		return
	if as_host:
		await wait(0.6)
		game.start_run()
		await wait(1.0)
		if not story_run:
			game.mission.plan[0] = {"wave": "classic", "tasks": ["codes"]}
			game.begin_wave()
			# A modifier, as a later round would draw one: the guest has to hear of it.
			game._set_modifier("strong")
			game.net.send_round("begin", game.wave)
	if story_run:
		await coop_story(game, as_host, tag)
		return
	var post := Vector3(-0.8, 0.05, 2.6) if as_host else Vector3(0.9, 0.05, 2.6)
	var home := post
	var working := false
	game.player.position = post
	var clock := 0.0
	var seen_peak := 0
	var shots := 0
	var lowest_health := 100.0
	var partner_moved := false
	var skipped := false
	var partner_downed := false
	var revived := false
	var bought := false
	var soldier_sent := false
	# The second exploding infected: what the host sent, the look of every Charger each side
	# saw (by its number, which both sides share), and the puddles that lay about.
	var wet_step := 0
	var wet_one: Infected = null
	var charger_looks := {}
	var wet_puddles := 0
	var cru_seen := false
	var cru_fired := false
	var cru_walked := 0.0
	var cru_last := Vector3.INF
	# What came with v0.14: on the host, enemies thrown back and set alight by the guest;
	# on the guest, the blows struck and the flames seen; on both, the bottle's fire.
	var shoved := false
	var alight := false
	var fire_seen := false
	var bottle_thrown := false
	var ducked := false
	var blows := 0
	var modifier_seen := ""
	# The newer weapons: for the last quarter of the fight the host takes the M21E in hand
	# and the guest the MP7, with its suppressor on for the last seconds; each side has to
	# hear the other's like any weapon (see RemoteSurvivor.shots_shown). volley: shots still
	# to be fired with what was just taken in hand, whether or not anything stands before it.
	var rearmed := 0
	var volley := 0
	# --mp-operator: an operator comes into the fight (see below).
	var op_run := "--mp-operator" in OS.get_cmdline_user_args()
	var op: Operator = null
	var op_step := 0
	var op_seen := false
	var op_away := false
	var op_bar := 1.0
	var op_blind := 0.0
	var op_voice := false
	var op_left := false
	while clock < seconds and game.state == "playing":
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		seen_peak = maxi(seen_peak, get_tree().get_nodes_in_group("infected").size())
		lowest_health = minf(lowest_health, game.player.health)
		if game.player.reserve == 0:
			game.player.reserve = game.player.max_reserve()
		if _snap_shot(game):
			shots += 1
		game.player.position.x = post.x
		game.player.position.z = post.z
		if is_instance_valid(game.net.remote):
			partner_moved = partner_moved or game.net.remote.global_position.distance_to(Vector3.ZERO) > 0.5
			partner_downed = partner_downed or game.net.remote.down
		fire_seen = fire_seen or not game.fire.fires.is_empty()
		# The guest ducks for a while early on; the host has to see its partner lower.
		if as_host:
			ducked = ducked or (is_instance_valid(game.net.remote) and game.net.remote.crouched)
		elif clock > seconds * 0.1 and not ducked:
			ducked = true
			game.player.set_crouched(true)
		elif clock > seconds * 0.2 and game.player.crouched:
			game.player.set_crouched(false)
		if game.modifier != "":
			modifier_seen = "%s harm=%.2f" % [game.modifier, float(game.rules.harm)]
		if rearmed == 0 and clock > seconds * 0.75 and not game.player.down:
			rearmed = 1
			game.player.unlock("mg2" if as_host else "mp7")
			volley = 5
		elif rearmed == 1 and not as_host and clock > seconds * 0.88 and game.player.current_weapon == "mp7":
			rearmed = 2
			game.player.fit("mp7", "silencer")
			volley = 5
		if volley > 0 and not game.player.down:
			var loaded: int = game.player.ammo
			game.player.shoot()
			if game.player.ammo < loaded:
				volley -= 1
		var within: Infected = null
		for foe in game.enemies.get_children():
			if not foe is Infected or foe.dead:
				continue
			if as_host:
				shoved = shoved or foe.knock.length() > 0.5
				alight = alight or foe.burn_left > 0.0
			else:
				alight = alight or (foe.flames != null and foe.flames.emitting)
				# The nearest one; a blow only reaches it when it stands close enough, but what
				# is reported to the host can be tried on any of them.
				if within == null or foe.global_position.distance_to(game.player.global_position) < within.global_position.distance_to(game.player.global_position):
					within = foe
		if op_run:
			# This run is about what both sides see of him, not about surviving him: whoever
			# is on his feet stays there.
			if not game.player.down and game.player.health > 0.0:
				game.player.health = maxf(game.player.health, 70.0)
			if as_host:
				# He comes in by the front door, is hurt after a while and driven off in the end.
				if op_step == 0 and clock > 4.0:
					op_step = 1
					op = game.spawn_enemy("ghost") as Operator
					op.position = Vector3(0.0, 0.05, 6.4)
					op.flash_wait = 1.5
				elif op_step == 1 and clock > 15.0 and is_instance_valid(op) and not op.absent:
					op_step = 2
					op.health = op.max_health * 0.8
				elif op_step == 2 and clock > 26.0 and is_instance_valid(op) and not op.absent:
					op_step = 3
					op.receive_hit(999999.0, Vector3.BACK)
			var here := false
			for foe in game.enemies.get_children():
				if foe is Operator and not (foe as Operator).dead:
					here = true
					op_seen = true
					op_away = op_away or (foe as Operator).absent
					op_bar = minf(op_bar, (foe as Operator).health / (foe as Operator).max_health)
			op_left = op_seen and not here
			op_blind = maxf(op_blind, game.hud.blind_left)
			op_voice = op_voice or game.hud.radio_label.text.begins_with("GHOST:")
		if not as_host and clock > seconds * 0.25 and not game.player.down:
			if not bottle_thrown:
				bottle_thrown = true
				game.fire_burst((game.cabin.points.front_door_out as Vector3) + Vector3(0, 0.3, 3.0))
			if within != null and game.player.melee_cooldown <= 0.0 and blows < 3:
				var to: Vector3 = within.global_position - game.player.global_position
				game.player.rotation.y = atan2(-to.x, -to.z)
				game.player.melee()
				if to.length() > 2.0:
					game.player.melee_cooldown = 1.0
					game.net.report_shove(within, to.normalized(), Survivor.MELEE_DAMAGE)
				game.net.report_burn(within, 12.0)
				blows += 1
		# Early on the guest buys ammunition: the team's supplies are kept by the host.
		if not as_host and clock > seconds * 0.2 and not bought:
			bought = true
			var before: int = game.credits
			game.player.position = beside(game, "ammo", game.cabin.points.supply)
			game.player.reserve = 0
			game.interact()
			print("MP_GUEST bought ammunition: credits %d -> %d reserve=%d" % [before, game.credits, game.player.reserve])
		# Later the guest walks out to the first dead researcher and holds [E] there.
		if not as_host and clock > seconds * 0.64 and clock < seconds * 0.64 + 3.0 and not game.mission.tasks.is_empty() and not game.player.down:
			post = (game.mission.tasks[0].items[0].pos as Vector3) + Vector3(0.8, 0.05, 0)
			game.player.health = 100
			Input.action_press("interact")
			working = true
		elif working:
			working = false
			Input.action_release("interact")
			post = home
		# Halfway through, the guest lets itself be struck down to try the help-up path.
		if not as_host and clock > seconds * 0.45 and not skipped:
			skipped = true
			game.player.receive_damage(500.0)
			print("MP_GUEST down=%s health=%.0f" % [str(game.player.down), game.player.health])
		# Past the middle the host lets a C.R.U. soldier in at the front door; both sides
		# note what they see of it.
		if as_host and clock > seconds * 0.55 and not soldier_sent:
			soldier_sent = true
			var soldier: Infected = game.spawn_enemy("cru_assault")
			soldier.position = (game.cabin.points.front_door_out as Vector3) + Vector3(0, 0.05, 2.0)
			soldier.health = 700.0
		# A third of the way in the host puts the second exploding infected into the yard and
		# sets it off two seconds later (harmlessly: this is about what both sides see of it).
		if as_host and clock > seconds * 0.3 and wet_step == 0:
			wet_step = 1
			wet_one = game.spawn_enemy("charger", "boomer2")
			wet_one.set_physics_process(false)
			wet_one.position = (game.cabin.points.front_door_out as Vector3) + Vector3(4.0, 0.05, 7.0)
			wet_one.burn_tame = true
		elif as_host and clock > seconds * 0.3 + 2.0 and wet_step == 1:
			wet_step = 2
			if is_instance_valid(wet_one) and not wet_one.dead:
				wet_one.receive_hit(9999.0, Vector3.BACK)
		for foe in game.enemies.get_children():
			if foe is Infected and (foe as Infected).kind == "charger" and (foe as Infected).model != null:
				charger_looks[(foe as Infected).net_id] = str((foe as Infected).model.kind)
		wet_puddles = maxi(wet_puddles, game.fx.puddles.size())
		for foe in game.enemies.get_children():
			if foe is CruSoldier and not foe.dead:
				cru_seen = true
				cru_fired = cru_fired or foe.volley > 0
				if cru_last != Vector3.INF:
					cru_walked += foe.global_position.distance_to(cru_last)
				cru_last = foe.global_position
		if as_host and game.partner_needs_help() and not revived:
			revived = true
			game.interact()
			print("MP_HOST helped the partner up")
	# The host calls the night off; the guest has to hear about it.
	if as_host:
		game.finish(false)
	else:
		var patience := 0.0
		while game.state == "playing" and patience < 6.0:
			await wait(0.1)
			patience += 0.1
	await wait(0.5)
	var items_done := 0
	var items_total := 0
	for task in game.mission.tasks:
		for item in task.items:
			items_total += 1
			if item.done:
				items_done += 1
	print("%s_TASKS tasks=%d items=%d done=%d props=%d" % [tag, game.mission.tasks.size(), items_total, items_done, game.mission.props.size()])
	# What this side heard of its own hits: never more ticks than shots fired here, never
	# more answers to a kill than kills made here.
	print("%s_ANSWERS shots=%d ticks=%d kill_answers=%d own_kills=%d dings=%d ding_kills=%d" % [tag, shots, int(game.sounds.answers.hit_body) + int(game.sounds.answers.hit_head), int(game.sounds.answers.hit_kill), game.kills, int(game.sounds.answers.ding) + int(game.sounds.answers.ding_head), int(game.sounds.answers.ding_kill)])
	# Both sides must name the same look for the same Charger, and both must have seen the
	# puddle of the one the host set off.
	var seen_looks: Array = []
	var numbers: Array = charger_looks.keys()
	numbers.sort()
	for number in numbers:
		seen_looks.append("%d:%s" % [int(number), str(charger_looks[number])])
	print("%s_CHARGERS looks=%s puddles=%d" % [tag, ",".join(PackedStringArray(seen_looks)), wet_puddles])
	# The weapon this side ended with, and which weapons of the partner it was shown shots
	# of (by their sound, as they come across) and how many.
	var partner_shots: Array = []
	if is_instance_valid(game.net.remote):
		var sounds_shown: Array = game.net.remote.shots_shown.keys()
		sounds_shown.sort()
		for sound in sounds_shown:
			partner_shots.append("%s:%d" % [str(sound), int(game.net.remote.shots_shown[sound])])
	print("%s_WEAPONS own=%s sound=%s partner=%s" % [tag, game.player.current_weapon, str(game.player.gun().sound), ",".join(PackedStringArray(partner_shots))])
	var partner_at := Vector3.ZERO
	var partner_health := -1.0
	if is_instance_valid(game.net.remote):
		partner_at = game.net.remote.global_position
		partner_health = game.net.remote.health
	if op_run:
		print("%s_OPERATOR seen=%s away=%s bar=%.2f blind=%.1f voice=%s left=%s driven_off=%d" % [tag, str(op_seen), str(op_away), op_bar, op_blind, str(op_voice), str(op_left), int(game.stats.ghost)])
	print("%s_RESULT state=%s wave=%d phase=%s infected_peak=%d shots=%d kills=%d credits=%d score=%d own_health=%.0f lowest=%.0f down=%s partner_at=%s partner_health=%.0f partner_seen_down=%s partner_moved=%s pickups=%d" % [tag, game.state, game.wave, game.phase, seen_peak, shots, game.kills, game.credits, game.score, game.player.health, lowest_health, str(game.player.down), str(partner_at.snapped(Vector3.ONE * 0.1)), partner_health, str(partner_downed), str(partner_moved), game.pickups.get_child_count()])
	print("%s_CRU seen=%s fired=%s walked=%.1f team_kills=%d team_cru_kills=%d" % [tag, str(cru_seen), str(cru_fired), cru_walked, int(game.stats.kills), int(game.stats.cru_kills)])
	print("%s_V14 %s=%s alight=%s fire=%s modifier=%s ducked=%s" % [tag, "shoved" if as_host else "blows", str(shoved) if as_host else str(blows), str(alight), str(fire_seen), modifier_seen, str(ducked)])
	game.sounds.stop_all()
	await wait(0.3)
	get_tree().call_deferred("quit", 0)

## Lets the night run for a while with the mission director at work, as it is in a game.
func _work(game: Node3D, seconds: float, until: Callable = Callable()) -> void:
	for i in range(int(seconds * 60.0)):
		game.mission.update(1.0 / 60.0)
		await get_tree().physics_frame
		if until.is_valid() and until.call():
			return

## One task of a kind with its things laid out at `places`.
func _task_at(game: Node3D, kind: String, item: String, places: Array) -> Dictionary:
	var task: Dictionary = game.mission._start_task(kind)
	task.items.clear()
	for place in places:
		task.items.append(game.mission._item(item, place))
	task.brief = 0.0
	return task

## What came with v0.17: a squad that takes over tasks (one ability in each tree), shotguns
## through shields, a squad that finds its feet over the first rounds, a fuller last round.
func _squadwork(game: Node3D) -> void:
	var player: Survivor = game.player
	var mission: MissionDirector = game.mission
	var skills: Skills = game.skills
	var stand := Vector3(0, 0.05, 22.0)
	game.profile.mode = "story"
	game.profile.modifiers = false
	game.team_enabled = true
	game.start_run()
	mission.plain()
	mission.sighting_left = 99999.0
	game.preparation_left = 9999.0
	skills.reset()
	skills.active = true
	face(game, stand, PI)
	var team: Array = game.team
	for i in range(team.size()):
		(team[i] as Teammate).global_position = stand + Vector3(-1.8 + i * 3.6, 0, -2.0)
		(team[i] as Teammate).velocity = Vector3.ZERO
	await frames(5)
	# --- one such ability in each tree
	var trees := {}
	for tree in Skills.TREES:
		for skill in Skills.TREES[tree].skills:
			for key in skill.gives:
				if MissionDirector.SQUAD_JOBS.has(key) and int(skill.ranks) == 1:
					trees[tree] = key
	var kinds := {}
	for key in MissionDirector.SQUAD_JOBS:
		for kind in MissionDirector.SQUAD_JOBS[key]:
			kinds[kind] = int(kinds.get(kind, 0)) + 1
	expect(team.size() == 2 and trees.size() == 3 and trees.sweeper == "squad_search" and trees.hunter == "squad_switch" and trees.breacher == "squad_guard" and kinds.size() == 9 and kinds.values().max() == 1, "Each tree has an ability that lets the squad take over tasks, and each a different kind of them")
	# --- without it the squad leaves the tasks to the player
	skills.chosen = "sweeper"
	var codes := _task_at(game, "codes", "corpse", [stand + Vector3(6.0, 0, -3.0), stand + Vector3(-6.0, 0, -3.0)])
	await _work(game, 2.5)
	var idle: bool = mission._open_items(codes) == 2 and (team[0] as Teammate).job.is_empty() and (team[1] as Teammate).job.is_empty()
	# --- with it they search the dead by themselves
	skills.ranks = {"sweeper_squad": 1}
	var done_before: int = game.stats.objectives
	var named := [false]
	await _work(game, 14.0, func() -> bool:
		named[0] = named[0] or "\n".join(mission.summary()).contains("hilft")
		return str(codes.state) == "done")
	expect(idle and str(codes.state) == "done" and game.stats.objectives == done_before + 1 and named[0] and player.global_position.distance_to(stand) < 0.5, "Without the ability the squad leaves the dead alone; with it the two search them for the codes while the player stands by")
	# --- somebody told to hold a place stays there
	for mate in team:
		(mate as Teammate).order = "hold"
		(mate as Teammate).hold_point = (mate as Teammate).global_position
	var more := _task_at(game, "codes", "corpse", [stand + Vector3(5.0, 0, -4.0)])
	await _work(game, 2.5)
	var held: bool = mission._open_items(more) == 1 and (team[0] as Teammate).job.is_empty() and (team[1] as Teammate).job.is_empty()
	for mate in team:
		(mate as Teammate).order = "follow"
	await _work(game, 12.0, func() -> bool: return str(more.state) == "done")
	expect(held and str(more.state) == "done", "Somebody who was told to hold a place takes no job; sent on again, the job gets done")
	# --- the hunter's squad switches things on, and leaves the dead alone
	skills.chosen = "hunter"
	skills.ranks = {"hunter_squad": 1}
	var power := _task_at(game, "power", "breaker", [stand + Vector3(5.0, 0, -3.0), stand + Vector3(-5.0, 0, -3.0)])
	var dark: bool = not game.cabin.powered
	var left_alone := _task_at(game, "codes", "corpse", [stand + Vector3(0.0, 0, -6.0)])
	await _work(game, 14.0, func() -> bool: return str(power.state) == "done")
	expect(dark and str(power.state) == "done" and game.cabin.powered and mission._open_items(left_alone) == 1, "The hunter's squad throws the breakers and the light is back; searching the dead is not what it has learnt")
	left_alone.state = "done"
	# --- the breacher's squad stands guard and starts what stands still
	skills.chosen = "breacher"
	skills.ranks = {"breacher_squad": 1}
	var zone := _task_at(game, "zone", "zone", [stand + Vector3(13.0, 0, -2.0)])
	await _work(game, 7.0, func() -> bool: return float(zone.items[0].use) > 0.02)
	var guarded: bool = float(zone.items[0].use) > 0.02 and str(zone.items[0].state) == "held" and player.global_position.distance_to(zone.items[0].pos) > MissionDirector.ZONE_RADIUS
	zone.state = "done"
	var engine := _task_at(game, "generator", "generator", [stand + Vector3(-7.0, 0, -3.0)])
	engine.left = -1.0
	await _work(game, 12.0, func() -> bool: return str(engine.items[0].state) == "running")
	var started: bool = str(engine.items[0].state) == "running"
	mission._stall(engine, engine.items[0])
	var stalled: bool = str(engine.items[0].state) == "stalled"
	await _work(game, 10.0, func() -> bool: return str(engine.items[0].state) == "running")
	var module := {"kind": "hack", "done": false, "state": "", "use": 0.0}
	var theirs: bool = not mission._squad_item({"state": "active"}, module)
	module.state = "stalled"
	theirs = theirs and mission._squad_item({"state": "active"}, module)
	expect(guarded and started and stalled and str(engine.items[0].state) == "running" and theirs, "The breacher's squad holds a marked position, starts the generator and starts it again when it stands still; the hack module it only starts again")
	engine.state = "done"
	skills.reset()
	# --- shotguns go through a shield with the breacher's last ability
	skills.chosen = "breacher"
	var bounced: bool = skills.shield_share("shotgun") == 0.0 and skills.shield_share("autoshotgun") == 0.0
	var bearer := game.spawn_enemy("cru_shield") as CruSoldier
	bearer.set_physics_process(false)
	bearer.position = Vector3(0, 0.05, 27.0)
	bearer.model.rotation.y = 0.0
	face(game, stand, PI)
	player.unlock("shotgun")
	await frames(3)
	var sound: float = bearer.health
	player.shot_cooldown = 0.0
	player.shoot()
	await frames(2)
	var stopped: bool = bearer.health == sound and bearer.blocks(Vector3.BACK)
	skills.ranks = {"breacher_shield2": 1}
	face(game, stand, PI)
	player.climb = 0.0
	player.shot_cooldown = 0.0
	player.pump_clock = -1.0
	player.shoot()
	await frames(2)
	var through: float = sound - bearer.health
	expect(bounced and stopped and through > 0.0 and through <= 9 * float(Survivor.WEAPONS.shotgun.damage) * 1.5 * 0.5 + 0.01 and bearer.knock == Vector3.ZERO and skills.shield_share("shotgun") == 0.5 and skills.shield_share("autoshotgun") == 0.5 and skills.shield_share("rifle") == 0.0, "With the breacher's last ability both shotguns shoot through a shield with half their force (%.0f), and it throws nobody back" % through)
	bearer.receive_hit(99999.0, Vector3.FORWARD)
	skills.reset()
	# --- the squad finds its feet over the first rounds
	var mate := team[0] as Teammate
	for other in team:
		# The one with a rifle: one bullet a shot.
		if int((other as Teammate).gun.pellets) == 1:
			mate = other
	var by_round := {}
	for number in [1, 4, 7, 12]:
		game.wave = number
		by_round[number] = lerpf(Teammate.GREEN_DAMAGE, 1.0, mate.seasoned())
	# On open ground beside the player, where the jobs before have not left it.
	mate.order = "hold"
	mate.hold_point = stand + Vector3(0.9, 0, 0.6)
	mate.global_position = mate.hold_point
	mate.velocity = Vector3.ZERO
	var dummy: Infected = game.spawn_enemy("mauler", "mauler_hazmat")
	dummy.set_physics_process(false)
	dummy.max_health = 50000.0
	dummy.health = 50000.0
	dummy.position = mate.global_position + Vector3(0, 0, 5.0)
	await frames(3)
	var least := {}
	for number in [1, 7]:
		game.wave = number
		var low := INF
		for shot in range(8):
			var before: float = dummy.health
			mate.ammo = 30
			mate._shoot(dummy.global_position + Vector3(0, 0.9, 0), false)
			if before - dummy.health > 0.01:
				low = minf(low, before - dummy.health)
		least[number] = low
	game.wave = 1
	mate.target = null
	mate.think_left = 0.0
	mate.hold_fire = 0.0
	mate.global_position = mate.hold_point
	dummy.position = mate.global_position + Vector3(0, 0, 6.0)
	await frames(8)
	var waits: bool = mate.target == dummy and mate.hold_fire > 0.3
	dummy.receive_hit(999999.0, Vector3.BACK)
	game.wave = 0
	var body_shot: float = float(mate.gun.damage)
	expect(is_equal_approx(by_round[1], Teammate.GREEN_DAMAGE) and by_round[4] > by_round[1] and by_round[4] < 1.0 and by_round[7] == 1.0 and by_round[12] == 1.0 and is_equal_approx(least[1], body_shot * Teammate.GREEN_DAMAGE) and is_equal_approx(least[7], body_shot) and waits and Teammate.GREEN_DAMAGE < 0.6, "In the first round the squad's shots do %d %% of what they do from round %d on, and it holds its fire for a moment on somebody new (%s, %s, %s, factor %.2f)" % [int(Teammate.GREEN_DAMAGE * 100.0), Teammate.SEASONED_ROUND, str(least), str(by_round), str(waits), mate.damage_factor])
	# --- the last round
	expect(float(game.FINAL_SHARE) > 0.7 and float(game.FINAL_SHARE) < 0.9, "The last round brings a little more than it did, and still less than its table says")
	_wipe(game)
	game.team_enabled = false
	game.start_run()

## What came with v0.18: a Crusher that is a danger, a harder M14, a shell that can be
## watched on its way, points for all three trees with one of them in force, fire that
## lets a Charger and a Striker's growths go off harmlessly, a map in the corner, a shop
## that sells and takes back, a workbench with five lines, the holographic sight, a
## lobby that says what the router said.
func _overhaul(game: Node3D) -> void:
	var player: Survivor = game.player
	var skills: Skills = game.skills
	game.profile.mode = "survival"
	game.profile.modifiers = false
	game.team_enabled = false
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	skills.reset()
	skills.active = true
	_wipe(game)
	await frames(4)
	# --- the Crusher leaps far and low, and lands next to its prey
	face(game, Vector3(0, 0.05, 14.0), PI)
	player.health = 100.0
	var giant: Infected = game.spawn_enemy("crusher")
	giant.position = Vector3(0, 0.05, 24.0)
	giant.alert = true
	giant.special_cooldown = 0.0
	var took_off := Vector3.ZERO
	var flew := false
	var rose := 0.0
	for i in range(60 * 7):
		await get_tree().physics_frame
		if giant.jump == "air" and not flew:
			flew = true
			took_off = giant.global_position
		rose = maxf(rose, giant.global_position.y)
		if flew and giant.jump == "":
			break
	var came_down: Vector3 = giant.global_position
	var short := Vector2(came_down.x - player.global_position.x, came_down.z - player.global_position.z).length()
	giant.set_physics_process(false)
	expect(flew and took_off.distance_to(came_down) > 6.5 and short < 3.0 and rose < 0.6 and player.health < 100.0 and float(Infected.LEAP_RANGE.y) >= 11.0, "The Crusher leaps at prey ten metres away and comes down next to it (%.1f m flown, %.1f m short of it)" % [took_off.distance_to(came_down), short])
	# --- where it lands the ground shakes
	face(game, came_down + Vector3(2.0, 0, 0), PI)
	player.health = 100.0
	giant._quake(null)
	var shaken: float = 100.0 - player.health
	player.health = 100.0
	giant._quake(player)
	var spared: bool = player.health == 100.0
	face(game, came_down + Vector3(Infected.QUAKE_REACH + 1.0, 0, 0), PI)
	giant._quake(null)
	var kind: Dictionary = Infected.TYPES.crusher
	expect(shaken > 5.0 and shaken < float(Infected.QUAKE_HARM) and spared and player.health == 100.0 and float(kind.speed) >= 2.5 and float(kind.damage) >= 40.0, "Its landing hurts whoever stands near (%.0f at two metres), but not twice whom it struck, and nobody further off" % shaken)
	giant._retire()
	giant.queue_free()
	game.alive_count -= 1
	game.boss = null
	await frames(3)
	# --- the M14 hits hard and goes through a body
	face(game, Vector3(0, 0.05, 14.0), PI)
	player.health = 100.0
	var row: Array = []
	for i in range(2):
		var body: Infected = game.spawn_enemy("mauler")
		body.set_physics_process(false)
		body.position = Vector3(0, 0.05, 19.0 + i * 1.4)
		body.health = 1000.0
		row.append(body)
	await frames(3)
	player.unlock("m14")
	player.equip_weapon("m14", true)
	player.camera.look_at((row[0] as Infected).global_position + Vector3(0, 1.1, 0))
	await frames(8)
	player.shot_cooldown = 0.0
	player.shoot()
	var first_loss: float = 1000.0 - (row[0] as Infected).health
	var second_loss: float = 1000.0 - (row[1] as Infected).health
	var rifle: Dictionary = Survivor.WEAPONS.m14
	expect(first_loss >= 99.0 and second_loss > 20.0 and int(rifle.pierce) == 1 and float(rifle.damage) * 1.0 / float(rifle.interval) > float(Survivor.WEAPONS.rifle.damage) / float(Survivor.WEAPONS.rifle.interval), "The M14 hits hard and its bullet goes on through a body (%.0f and %.0f)" % [first_loss, second_loss])
	for body in row:
		(body as Infected)._retire()
		(body as Infected).queue_free()
		game.alive_count -= 1
	await frames(2)
	# --- the launcher's shell takes its time
	face(game, Vector3(0, 0.05, 22.0), PI)
	player.unlock("launcher")
	player.equip_weapon("launcher", true)
	await frames(3)
	var flight: PackedVector3Array = player.launch_path()
	var landing: Vector3 = flight[flight.size() - 1]
	var reach := Vector2(landing.x - flight[0].x, landing.z - flight[0].z).length()
	var seconds := (flight.size() - 1) * 0.05
	expect(reach > 14.0 and reach < 30.0 and seconds > 1.0 and reach / seconds < 18.5 and float(Survivor.LAUNCH_SPEED) < 20.0 and float(Survivor.LAUNCH_SHOWN) >= seconds, "The launcher's shell can be watched on its way: %.1f m in %.2f seconds when held level" % [reach, seconds])
	# --- the launcher is an M32: one shell a second from a drum that is loaded shell by shell
	player.ammo = 6
	await frames(3)
	var m32_view: Node3D = player.weapon_models["launcher"]
	var m32_full_drum: int = m32_view.find_children("Round*", "", true, false).filter(func(node: Node) -> bool: return (node as Node3D).visible).size()
	player.shot_cooldown = 0.0
	var m32_turned := player.drum_turn
	player.shoot()
	var m32_once: bool = player.ammo == 5 and is_equal_approx(player.shot_cooldown, 1.0) and player.drum_shot >= 0.0
	await wait(0.3)
	m32_once = m32_once and player.drum_turn == m32_turned + 1
	player.shot_cooldown = 0.0
	player.trigger_held = false
	player.start_reload()
	var m32_opened: bool = player.drum_phase == "open" and player.loading_shells and player.reload_left > 1.0
	player._work_drum(player.drum_time("open"))
	var m32_filling: bool = player.drum_phase == "load" and player.ammo == 5
	WeaponView.pose_drum(m32_view, player.drum_turn, player.ammo, "load", 0.3, 1.0)
	var m32_swung: float = absf((m32_view.find_child("Front", true, false) as Node3D).rotation.z)
	var m32_carried: bool = (m32_view.get_node("Held") as Node3D).visible
	var m32_stock := player.reserve
	player._work_drum(player.drum_time("load"))
	var m32_loaded: bool = player.ammo == 6 and player.reserve == m32_stock - 1 and player.drum_phase == "close"
	player._work_drum(player.drum_time("close"))
	var m32_shut: bool = player.drum_phase == "" and not player.loading_shells and player.reload_left == 0.0
	# One more shot, then the trigger breaks the reload off: the drum is closed first.
	player.shot_cooldown = 0.0
	player.shoot()
	player.trigger_held = false
	player.start_reload()
	player._work_drum(player.drum_time("open"))
	player.trigger_held = false
	player.shoot()
	var m32_broken: bool = player.drum_phase == "close" and player.ammo == 5
	player._work_drum(player.drum_time("close"))
	expect(str(Survivor.WEAPONS.launcher.label) == "M32 GRANATWERFER" and not Survivor.WEAPONS.has("m32") and str(WeaponView.MODELS.launcher.scene).ends_with("m32.glb") and m32_full_drum == 6 and m32_once and m32_opened and m32_filling and m32_swung > 0.8 and m32_carried and m32_loaded and m32_shut and m32_broken and not Survivor.upgrade_fits("launcher", "mags"), "The launcher is the M32: it fires a shell a second and turns its drum on; its drum swings open, is filled shell by shell and closed, and the trigger closes it early")
	# --- points are spread over the trees, and one tree is in force
	player.inventory.erase("launcher")
	player.equip_weapon("rifle", true)
	var career: Dictionary = game.profile.totals.duplicate()
	for key in game.profile.totals:
		game.profile.totals[key] = 0
	game.profile.totals.victories = 40
	game.reset_skills()
	var spread := true
	for id in ["sweeper_damage", "sweeper_damage", "sweeper_damage", "sweeper_fire", "hunter_damage", "hunter_damage", "hunter_damage", "hunter_squad"]:
		spread = spread and game.learn_skill(id)
	var all_in: bool = Skills.level_of(Skills.experience(game.profile.totals)) == 9 and skills.points_left(game.profile.totals) == 0 and skills.spent("sweeper") == 4 and skills.spent("hunter") == 4 and not game.learn_skill("breacher_armour")
	var sweeping: bool = skills.chosen == "sweeper" and is_equal_approx(skills.value("damage_common"), 0.24) and skills.value("fire_tame") == 1.0 and skills.value("damage_special") == 0.0 and skills.value("squad_switch") == 0.0
	var switched: bool = game.choose_tree("hunter")
	var hunting: bool = skills.chosen == "hunter" and is_equal_approx(skills.value("damage_special"), 0.24) and skills.value("squad_switch") == 1.0 and skills.value("damage_common") == 0.0 and skills.value("fire_tame") == 0.0 and skills.spent() == 8
	# A row of a tree opens by the points in that tree, however many are in the others.
	var rows: bool = skills.barred("breacher_shield", {"victories": 9999}).begins_with("Erst 3 Punkte") and skills.barred("sweeper_pierce", {"victories": 9999}).begins_with("Erst 7 Punkte")
	game.hud.show_menu("main")
	var named := ""
	for node in game.hud.modal.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("FÄHIGKEITEN"):
			named = (node as Button).text
	game.hud.show_menu("skills")
	var marks := 0
	for node in game.hud.modal.find_children("*", "Label", true, false):
		if (node as Label).text == "AKTIV":
			marks += 1
	game.hud.hide_menu()
	# The profile keeps the ranks of every tree and the tree in force.
	var kept := Skills.new()
	kept.adopt(game.profile.skills, game.profile.skill_tree)
	var stored: bool = game.profile.skill_tree == "hunter" and kept.chosen == "hunter" and kept.spent("sweeper") == 4 and kept.spent("hunter") == 4 and kept.rank("sweeper_fire") == 1
	game.profile.totals = career
	game.reset_skills()
	expect(spread and all_in and sweeping and switched and hunting and rows and named.ends_with("JÄGER") and marks == 1 and stored and skills.spent() == 0, "Points go into any of the trees; only the tree in force counts, another can be put in force without losing a point, and the profile keeps all of it")
	# --- what the sweeper's flamethrower sets alight goes off without harm
	var post := Vector3(0, 0.05, 22.0)
	skills.chosen = "sweeper"
	skills.ranks = {"sweeper_damage": 3, "sweeper_fire": 1}
	player.unlock("flamer")
	player.equip_weapon("flamer", true)
	var harms: Array = []
	var torn: Array = []
	for tame in [true, false]:
		if not tame:
			skills.ranks.erase("sweeper_fire")
		_wipe(game)
		await frames(3)
		face(game, post, PI)
		player.health = 100.0
		var bomb: Infected = game.spawn_enemy("charger")
		bomb.set_physics_process(false)
		bomb.position = post + Vector3(0, 0, 2.2)
		bomb.health = 1.0
		var near_it: Infected = game.spawn_enemy("mauler")
		near_it.set_physics_process(false)
		near_it.position = post + Vector3(2.4, 0, 3.4)
		near_it.health = 2000.0
		await frames(3)
		player.shot_cooldown = 0.0
		player.shoot()
		await wait(0.5)
		harms.append(100.0 - player.health)
		torn.append(2000.0 - near_it.health)
	expect(harms[0] == 0.0 and harms[1] > 10.0 and torn[0] > 20.0 and torn[1] > 20.0, "A Charger the sweeper's flamethrower set alight bursts without harming him (%.0f; without the ability %.0f), and still tears the infected beside it apart" % [harms[0], harms[1]])
	# A Striker's growths: charred, and they only fizzle out.
	skills.ranks = {"sweeper_damage": 3, "sweeper_fire": 1}
	_wipe(game)
	await frames(3)
	face(game, post, PI)
	player.health = 100.0
	var runner: Infected = game.spawn_enemy("striker")
	runner.set_physics_process(false)
	runner.position = post + Vector3(0, 0, 2.0)
	runner.shed = true
	runner.health = 1.0
	await frames(3)
	player.shot_cooldown = 0.0
	player.shoot()
	await frames(3)
	var charred := 0
	for growth in game.fx.growths:
		if growth.spent:
			charred += 1
	await wait(3.6)
	var fizzled: bool = charred == 3 and game.fx.growths.is_empty() and player.health == 100.0
	# The fire has to be burning: once it is out, a Charger is as dangerous as ever.
	var late: Infected = game.spawn_enemy("charger")
	late.set_physics_process(false)
	late.position = post + Vector3(0, 0, 2.2)
	await frames(2)
	game.scorch(late, 1.0, Vector3.FORWARD, null, 0.2, true)
	var lit: bool = late.burn_tame and late.burn_left > 0.0
	late._burn(0.3)
	var out: bool = not late.burn_tame and late.burn_left <= 0.0
	late.receive_hit(99999.0, Vector3.FORWARD)
	await wait(0.5)
	expect(fizzled and lit and out and player.health < 100.0 and Skills.tree_of("sweeper_fire") == "sweeper" and int(Skills.find("sweeper_fire").tier) == 2, "The growths of a Striker that burnt come off charred and only fizzle out; once the fire is out a Charger is as dangerous as before")
	_wipe(game)
	await wait(0.5)
	skills.reset()
	player.health = 100.0
	player.inventory.erase("flamer")
	player.equip_weapon("rifle", true)
	# --- the map in the corner
	_wipe(game)
	await frames(3)
	var map: Minimap = game.hud.minimap
	map._draw_plans()
	var drawn: bool = map.plans.size() == 3
	for level in range(map.plans.size()):
		drawn = drawn and Vector2i((map.plans[level] as Texture2D).get_size()) == game.cabin.navigation[level].region.size
	face(game, post, 0.0)
	var shown := {}
	for entry in [["mauler", Vector3(0, 0, -8.0)], ["cru_assault", Vector3(8.0, 0, 0)], ["charger", Vector3(-8.0, 0, 0)], ["mauler", Vector3(0, 0, 70.0)]]:
		var body: Infected = game.spawn_enemy(str(entry[0]))
		body.set_physics_process(false)
		body.position = post + (entry[1] as Vector3)
		shown[body] = true
	var ghost: Infected = game.spawn_stalker(post + Vector3(3.0, 0, -3.0), "watch", player)
	ghost.set_physics_process(false)
	await frames(3)
	var spots: Array = map.marks()
	var reds: Array = spots.filter(func(mark: Dictionary) -> bool: return mark.color == Minimap.COMMON)
	var blues: Array = spots.filter(func(mark: Dictionary) -> bool: return mark.color == Minimap.SOLDIER)
	var ambers: Array = spots.filter(func(mark: Dictionary) -> bool: return mark.color == Minimap.SPECIAL)
	var placed: bool = spots.size() == 4 and reds.size() == 2 and blues.size() == 1 and ambers.size() == 1
	if placed:
		var near_red: Dictionary = reds[0] if not reds[0].rim else reds[1]
		var far_red: Dictionary = reds[1] if not reds[0].rim else reds[0]
		# Ahead is up, right is right; what is too far off sits on the rim, behind is down.
		placed = (near_red.at as Vector2).y < -15.0 and absf((near_red.at as Vector2).x) < 2.0 and (blues[0].at as Vector2).x > 15.0 and absf((blues[0].at as Vector2).y) < 2.0 and (ambers[0].at as Vector2).x < -15.0
		placed = placed and far_red.rim and is_equal_approx((far_red.at as Vector2).y, Minimap.SIZE * 0.5 - Minimap.RIM) and not near_red.rim and str(blues[0].shape) == "square" and str(ambers[0].shape) == "ring" and str(near_red.shape) == "dot"
	# Turned a quarter to the left, what stood on the left is ahead.
	face(game, post, PI * 0.5)
	var turned: Array = map.marks().filter(func(mark: Dictionary) -> bool: return mark.color == Minimap.SPECIAL)
	var follows: bool = turned.size() == 1 and (turned[0].at as Vector2).y < -15.0 and absf((turned[0].at as Vector2).x) < 2.0
	# Somebody on another floor is pale.
	face(game, post, 0.0)
	for body in shown:
		if (body as Infected).kind == "cru_assault":
			(body as Infected).position = (game.cabin.points.gallery as Vector3) + Vector3(0, 0.05, 0)
	await frames(2)
	var pale := false
	for mark in map.marks():
		pale = pale or (is_equal_approx((mark.color as Color).a, Minimap.ELSEWHERE) and (mark.color as Color).is_equal_approx(Color(Minimap.SOLDIER, Minimap.ELSEWHERE)))
	var corner: bool = map.get_parent() == game.hud.play_ui and map.offset_right == -32.0 and map.offset_top == 22.0 and is_equal_approx(map.offset_right - map.offset_left, Minimap.SIZE)
	expect(drawn and placed and follows and pale and corner and Minimap.COMMON != Minimap.SPECIAL and Minimap.SPECIAL != Minimap.SOLDIER and Minimap.COMMON != Minimap.SOLDIER, "A map in the top right corner: walls of each level, ahead is up; common infected, special ones and soldiers each in a colour of their own, the far ones on its rim, those on another floor pale, the Stalker never")
	ghost._retire()
	ghost.queue_free()
	for body in shown:
		(body as Infected)._retire()
		(body as Infected).queue_free()
		game.alive_count -= 1
	await frames(2)
	# --- the shop: a weapon can be sold, and what goes for a new one can be chosen
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	skills.reset()
	var hud: SurvivalHUD = game.hud
	var shelf: Vector3 = game.cabin.points.shop
	var bench := Vector3.ZERO
	for station in game.cabin.stations:
		if station.kind == "upgrade":
			bench = (station.pos as Vector3) + Vector3(0, 0.05, 1.0)
	game.wave = 3
	game.credits = 3000
	player.position = shelf + Vector3(0, 0.05, 0.6)
	game.interact()
	var screen: ShopScreen = hud.counter
	var opened: bool = game.state == "shop" and screen != null and screen.mode == "shop"
	var lone: bool = not game.sell_weapon("rifle") and player.inventory.has("rifle")
	var armed: bool = game.buy_weapon("pistol") and game.sell_weapon("rifle") and not player.inventory.has("rifle") and player.current_weapon == "pistol" and game.credits == 3000 - 60
	var back: bool = game.buy_weapon("ak") and game.sell_weapon("ak") and player.current_weapon == "pistol" and game.credits == 3000 - 60 - 300 + 150
	# With a sling there are two rifles; a third takes the place of the one the buyer names.
	var two: bool = game.buy_item("sling") and game.buy_weapon("g36") and game.buy_weapon("m14") and player.carried("primary").size() == 2 and game.credits == 2790 - 250 - 450 - 320
	var choices: Array = player.replaceable("ak")
	var usual: String = game.outgoing("ak")
	var picks_one: bool = choices.size() == 2 and usual == "m14" and choices[0] == "m14" and choices.has("g36") and game.weapon_cost("ak") == 300 - 160 and game.weapon_cost("ak", "g36") == 300 - 225 and game.outgoing("ak", "pistol") == "m14"
	var chosen: bool = game.buy_weapon("ak", "g36") and player.inventory.has("ak") and player.inventory.has("m14") and not player.inventory.has("g36") and game.credits == 1770 - 75
	expect(opened and lone and armed and back and two and picks_one and chosen and hud.counter == screen, "The shop takes a weapon back for half its price (never the last one), and the buyer chooses which weapon goes for a new one")
	# --- its screen: a list, the weapon picked in it turning in a picture, one button
	hud._open_tab("weapons")
	screen.pick("weapon", "g36")
	var rifles := 0
	for id in Survivor.ORDER:
		if str(Survivor.WEAPONS[id].get("group", "weapons")) == "weapons":
			rifles += 1
	var shown_gun: Node3D = screen.stage.models.get("g36")
	var bare := shown_gun != null
	if bare:
		for node in shown_gun.find_children("*", "", true, false):
			bare = bare and not str(node.name).begins_with("Hand") and str(node.name) != "Support"
		bare = bare and (shown_gun.get_meta("size") as Vector3).z > 0.6 and shown_gun.find_child("Magazine", true, false) != null and shown_gun.find_child("Mod_reddot", true, false) != null
	var offered: bool = screen.row_buttons.size() == rifles and screen.stage.shown == "g36" and screen.stage.visible and screen.action != null and screen.action.text.begins_with("TAUSCHEN") and not screen.action.disabled
	screen.pick("weapon", "ak")
	var mine: bool = screen.action.text.begins_with("VERKAUFEN") and str(screen.weapon_state("ak")[0]).begins_with("DABEI")
	# A part is shown on its weapon before it is bought.
	hud._open_tab("mods")
	screen.pick("part", "ak", "scope")
	var tried: bool = (screen.stage.models.ak as Node3D).find_child("Mod_scope", true, false).visible and not player.owns_part("ak", "scope") and screen.action.text.begins_with("KAUFEN")
	# What gets used up is bought from its line.
	hud._open_tab("use")
	var quick: Button = null
	for shelf_row in screen.row_buttons:
		if (shelf_row as Button).text == str(Survivor.GOODS.grenade.label):
			for child in (shelf_row as Button).get_children():
				if child is Button:
					quick = child
	var before_buy: int = game.credits
	if quick != null:
		quick.pressed.emit()
	expect(bare and offered and mine and tried and quick != null and int(player.items.grenade) == 1 and game.credits == before_buy - 60 and hud.counter == screen and screen.stock("grenade").begins_with("●○"), "The shop's screen lists what is on sale, shows the picked weapon by itself (no hands) with a part tried on, and stays as it is when something is bought")
	game.resume_run()
	# --- the workbench: five lines to choose from, each for one weapon
	player.position = bench
	player.equip_weapon("ak", true)
	game.credits = 3000
	game.interact()
	screen = hud.counter
	var benched: bool = game.state == "bench" and screen.mode == "bench" and screen.row_buttons.size() == player.inventory.size() and str(screen.picked.get("id", "")) == "ak"
	var plain_kick: float = float(player.gun().kick)
	var plain_cap: int = player.reserve_cap("ak")
	var plain_reload: float = player.reload_of("ak")
	var pockets: int = player.reserve
	var raised := true
	for line in ["damage", "mags", "pouch", "drill", "brace"]:
		raised = raised and game.upgrade_price("ak", line) == game.price(int(Survivor.UPGRADES[line].prices[0])) and game.buy_upgrade(line)
	var worked: bool = is_equal_approx(player.damage_of("ak"), float(Survivor.WEAPONS.ak.damage) + 10.0) and player.magazine_size() == 45 and player.ammo == 45 and player.reserve_cap("ak") == int(round(plain_cap * 1.25)) and player.reserve == pockets + player.reserve_cap("ak") - plain_cap and is_equal_approx(player.reload_of("ak"), plain_reload * 0.88) and is_equal_approx(float(player.gun().kick), plain_kick * 0.85)
	var paid: bool = game.credits == 3000 - 250 - 200 - 150 - 180 - 150 and game.upgrade_price("ak", "mags") == -1 and not game.buy_upgrade("mags") and game.upgrade_price("ak", "pouch") == 220
	# Another weapon has lines of its own; not every line is for every weapon.
	var own_lines: bool = player.upgrade("m14", "damage") == 0 and game.buy_upgrade("damage", "m14") and player.upgrade("m14", "damage") == 1 and player.upgrade("ak", "damage") == 1
	var fitting: bool = not Survivor.upgrade_fits("nitro", "mags") and not Survivor.upgrade_fits("flamer", "brace") and Survivor.upgrade_fits("flamer", "damage") and screen.line_effect("ak", "damage").contains("→")
	game.resume_run()
	# What was done to a weapon goes with it.
	player.position = shelf + Vector3(0, 0.05, 0.6)
	game.interact()
	player.equip_weapon("pistol", true)
	var gone: bool = game.sell_weapon("ak") and game.buy_weapon("ak") and player.upgrade("ak", "damage") == 0 and player.magazine_of("ak") == 30
	game.resume_run()
	expect(benched and raised and worked and paid and own_lines and fitting and gone and game.state == "playing", "The workbench has five lines to choose from (damage, magazine, pockets, reload, steadiness), each for one weapon and each with its price; they go with the weapon")
	# --- the reflex sight is the holographic sight, on every gun that takes one
	var sights := 0
	var seated := true
	for id in Survivor.ATTACHMENTS:
		var gun_view: Node3D = player.weapon_models[id]
		var spec: Dictionary = WeaponView.GUNS[id]
		var part := gun_view.get_node_or_null("Mod_reddot") as Node3D
		if part == null:
			seated = false
			continue
		var bodies := 0
		var panes := 0
		var finest := INF
		var mark_z := 0.0
		for node in part.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh is QuadMesh:
				panes += 1
				if (mesh.mesh as QuadMesh).size.x < finest:
					finest = (mesh.mesh as QuadMesh).size.x
					mark_z = mesh.position.z
			elif mesh.get_surface_override_material(0) == WeaponView.holo_material and mesh.layers == 2:
				bodies += 1
		var rail_y: float = (spec.mount as Vector3).y + float(spec.rail)
		# On the G36 the sight is a little smaller, and the eye that much closer to it.
		var small: float = WeaponView.holo_size(id)
		var face_z: float = (spec.mount as Vector3).z + float(spec.optic) + WeaponView.HOLO_BACK
		var eye: Vector3 = WeaponView.sight_aim(id, "reddot")
		# One body from the model and three panes (glass, ring, dot); the dot sits inside the
		# tunnel, in the middle of the window; the eye is behind the face that looks at it.
		seated = seated and bodies == 1 and panes == 3 and finest < 0.002 and mark_z < face_z + WeaponView.HOLO_TUNNEL.x * small and mark_z > face_z + WeaponView.HOLO_TUNNEL.y * small
		seated = seated and is_equal_approx(-eye.y, rail_y + WeaponView.HOLO_AXIS * small) and is_equal_approx(-eye.z, face_z + WeaponView.HOLO_EYE * small) and rail_y + (WeaponView.HOLO_AXIS - WeaponView.HOLO_GLASS.y * 0.5) * small > (spec.mount as Vector3).y + float(spec.irons)
		sights += 1
	expect(sights == 5 and seated and WeaponView.holo_size("g36") < 0.9 and WeaponView.holo_size("rifle") == 1.0 and ResourceLoader.exists(WeaponView.HOLO_SCENE) and WeaponView.holo_material != null and WeaponView.holo_material.use_fov_override, "The reflex sight is the holographic sight on all five guns that take one: its window stands clear above the iron sights, with the dot inside its tunnel")
	# --- the lobby says what the router said
	var link: NetLink = game.net
	var sorted: bool = NetLink.reachable("203.0.113.7") and NetLink.reachable("172.32.1.1") and not NetLink.reachable("192.168.178.27") and not NetLink.reachable("10.0.0.5") and not NetLink.reachable("172.20.1.1") and not NetLink.reachable("100.72.3.4") and not NetLink.reachable("192.0.0.2") and not NetLink.reachable("")
	var said := {}
	for outcome in ["open", "refused", "walled", "none"]:
		link.hosting = true
		link._forwarded("203.0.113.7", outcome)
		game.hud.show_menu("host")
		var words := ""
		for node in game.hud.modal.find_children("*", "Label", true, false):
			words += (node as Label).text + "\n"
		said[outcome] = words
		link.close()
	game.hud.hide_menu()
	var truthful: bool = str(said.open).contains("geöffnet") and str(said.open).contains("203.0.113.7") and str(said.refused).contains("NICHT von selbst") and not str(said.refused).contains("geöffnet") and str(said.walled).contains("nicht direkt erreichbar") and not str(said.walled).contains("203.0.113.7") and str(said.none).contains("keine automatische Freigabe")
	# An answer that comes after the match was closed changes nothing.
	link._forwarded("203.0.113.7", "open")
	expect(sorted and truthful and link.forward == "" and link.public_address == "" and link.router == null and not link.hosting, "The host's lobby says what the router said to the request for the port - opened, refused, or no address of its own - and nothing of it outlasts the match")

## What came with v0.19: the operators Phantom, Havoc and Ghost - tough, never killed, gone
## behind a flashbang and back from somewhere else, loud on the Fireteam's radio -, their
## looks as skins, and a voice of command that is not Coleman's once Nadja is out.
func _operators(game: Node3D) -> void:
	var player: Survivor = game.player
	var hud: SurvivalHUD = game.hud
	game.operators_enabled = true
	game.profile.mode = "survival"
	game.profile.modifiers = false
	game.team_enabled = false
	game.start_run()
	game.mission.plain()
	game.preparation_left = 9999.0
	game.skills.reset()
	_wipe(game)
	await frames(4)
	# --- three of a kind
	var complete := true
	for kind in Operator.KINDS:
		var spec: Dictionary = Infected.TYPES[kind]
		complete = complete and bool(spec.get("operator", false)) and bool(spec.human) and CruSoldier.ROLES.has(str(spec.role)) and bool(CruSoldier.ROLES[str(spec.role)].get("operator", false)) and float(spec.health) >= 1200.0
		complete = complete and SoldierVisual.LOOKS.has(kind) and SoldierVisual.LOOKS[kind].has("eyes") and Radio.NAMES.has(kind) and Profile.SKINS.has(kind) and str(Profile.SKINS[kind].need) == kind
		for cue in ["op_arrive", "op_taunt", "op_flash", "op_hurt", "op_down", "op_leave", "contact", "cover", "flank"]:
			complete = complete and not Radio.bark(kind, cue).is_empty()
	expect(complete and Operator.KINDS.size() == 3 and Radio.LINES.has("operator_seen"), "Three operators - Phantom, Havoc, Ghost - each with a body, a role, a look with eyes that glow, a skin to earn and a line for everything he has to say")
	# --- one of them on the field: a soldier with a bar who is told from the rest
	var open := Vector3(0, 0.05, 24.0)
	face(game, open, 0.0)
	player.health = 100.0
	var purse: int = game.credits
	game.radio_queue.clear()
	game.radio_busy = 0.0
	var hunter: Infected = game.spawn_enemy("phantom")
	hunter.set_physics_process(false)
	hunter.position = open + Vector3(0, 0, -10.0)
	await frames(3)
	hud._process(0.05)
	var bar_shown: bool = (hud.operator_rows[0][2] as Control).visible and (hud.operator_rows[0][0] as Label).text == "PHANTOM" and not (hud.operator_rows[1][2] as Control).visible
	var marks: Array = hud.minimap.marks().filter(func(mark: Dictionary) -> bool: return mark.color == Minimap.SOLDIER)
	var glowing := hunter.model.find_child("Eyes", true, false)
	var talked: bool = hud.radio_label.text.begins_with("PHANTOM:") and hud.radio_label.get_theme_color("font_color") == Operator.TINT
	expect(hunter is Operator and game.operators.has(hunter) and Skills.kind_of(hunter) == "cru" and bar_shown and marks.size() == 1 and float(marks[0].size) == 4.0 and glowing != null and glowing.find_child("Light", false, false) != null and (hunter.model as CruVisual).soldier.eyes_glow() and talked and game.alive_count == 1, "An operator is a soldier with a bar on the screen, a big mark on the map, eyes that glow, and a word for the Fireteam on its own radio")
	# --- he cannot be killed: with his bar empty he breaks off, and the Fireteam is paid
	var whole: float = hunter.max_health
	hunter.receive_hit(whole * 0.2, Vector3.BACK, false)
	var hurts: bool = hunter.health < whole and hunter.health > whole * 0.8
	hunter.receive_hit(99999.0, Vector3.BACK, false)
	var off: bool = (hunter as Operator).leaving and hunter.absent and not hunter.model.visible and int(game.stats.phantom) == 1 and game.credits == purse + int(Infected.TYPES.phantom.reward) and game.alive_count == 0 and int(game.stats.cru_kills) == 0
	await wait(1.2)
	hud._process(0.05)
	expect(hurts and off and not is_instance_valid(hunter) and game.operators.is_empty() and not (hud.operator_rows[0][2] as Control).visible and hud.radio_label.text.begins_with("PHANTOM:"), "With his bar empty an operator does not die: he breaks off and is gone, and the Fireteam gets what he was worth")
	# --- a flashbang, and he is somewhere else
	face(game, open, 0.0)
	player.health = 5000.0
	hud.blind_left = 0.0
	var ghost: Operator = game.spawn_enemy("ghost") as Operator
	ghost.position = open + Vector3(0, 0, -10.0)
	await frames(3)
	var stood: Vector3 = ghost.global_position
	ghost.flash_wait = 0.0
	var thrown := false
	var gone := false
	var blinded := 0.0
	for i in range(60 * 3):
		await get_tree().physics_frame
		for node in game.ordnance.get_children():
			thrown = thrown or (node is Throwable and (node as Throwable).kind == "flashbang" and (node as Throwable).hostile)
		blinded = maxf(blinded, hud.blind_left)
		if ghost.absent:
			gone = true
			break
	var unreachable: bool = gone and ghost.collision_layer == 0 and hud.minimap.marks().filter(func(mark: Dictionary) -> bool: return mark.color == Minimap.SOLDIER).is_empty()
	var before_hit: float = ghost.health
	ghost.receive_hit(500.0, Vector3.BACK, false)
	unreachable = unreachable and ghost.health == before_hit
	var back := false
	for i in range(60 * 4):
		await get_tree().physics_frame
		blinded = maxf(blinded, hud.blind_left)
		if not ghost.absent:
			back = true
			break
	var moved: float = ghost.global_position.distance_to(stood)
	var from_prey: float = Vector2(ghost.global_position.x - player.global_position.x, ghost.global_position.z - player.global_position.z).length()
	expect(thrown and gone and unreachable and blinded > 0.5 and back and ghost.model.visible and ghost.collision_layer == 4 and moved > 2.0 and from_prey > Operator.BACK.x - 1.0 and from_prey < Operator.BACK.y + 1.0, "An operator throws a flashbang that blinds the player, is gone behind it - out of reach and off the map - and comes back somewhere else (%.1f m away from where he stood, blind for %.1f s)" % [moved, blinded])
	# Badly hit he breaks contact at once, whatever his clock says.
	ghost.set_physics_process(true)
	ghost.flash_wait = 999.0
	ghost.health = ghost.max_health * 0.5
	var fled := false
	for i in range(60 * 4):
		await get_tree().physics_frame
		if ghost.absent:
			fled = true
			break
	expect(fled and ghost.breaks_done >= 1 and not ghost.leaving, "Hit hard, an operator breaks contact at once")
	# A hunter does not wait outside for somebody who stays in the house. (With others in
	# the yard: alone he comes at once.)
	game.alive_count += 5
	ghost.unseen_for = 0.0
	var far_reach: Vector2 = ghost._reach()
	ghost.unseen_for = Operator.CLOSE_AFTER + Operator.CLOSE_OVER * 0.5
	var nearing: Vector2 = ghost._reach()
	ghost.unseen_for = Operator.CLOSE_AFTER + Operator.CLOSE_OVER
	var close_reach: Vector2 = ghost._reach()
	ghost.unseen_for = 0.0
	game.alive_count -= 5
	var last_reach: Vector2 = ghost._reach()
	expect(far_reach == Vector2(20.0, 34.0) and nearing.y < far_reach.y and nearing.y > close_reach.y and close_reach == Operator.CLOSE_REACH and last_reach == Operator.CLOSE_REACH, "An operator who has lost sight of his prey comes nearer, whatever his weapon would like (%s, then %s, then %s) - and so does the last one left of a round" % [str(far_reach), str(nearing), str(close_reach)])
	ghost.set_physics_process(false)
	ghost._retire()
	ghost.queue_free()
	game.alive_count = 0
	player.health = 100.0
	hud.blind_left = 0.0
	await frames(3)
	# --- what a flashbang does to whoever looks at it
	face(game, open, 0.0)
	game.show_blind(open + Vector3(0, 1.2, -4.0))
	var faced: float = hud.blind_left
	hud.blind_left = 0.0
	hud.blind_peak = 0.0
	face(game, open, PI)
	await frames(2)
	game.show_blind(open + Vector3(0, 1.2, -4.0))
	var turned_away: float = hud.blind_left
	hud.blind_left = 0.0
	face(game, open, 0.0)
	await frames(2)
	game.show_blind(open + Vector3(0, 1.2, -40.0))
	var far_off: float = hud.blind_left
	expect(faced > 2.0 and turned_away > 0.5 and turned_away < faced and far_off == 0.0 and game.sounds.clips.has("ring") and game.sounds.clips.has("glitch"), "A flashbang blinds longer the straighter one looks at it (%.1f s against %.1f s), and not at all from far off" % [faced, turned_away])
	hud.blind_left = 0.0
	# --- who comes when
	var mode_before: String = game.mode
	var counts := {}
	var apart := true
	for level in Profile.ORDER:
		game.level = level
		game.mode = "story"
		game.plan_operators()
		counts[level] = game.operators_due.size()
		var rounds := {}
		var kinds := {}
		for entry in game.operators_due:
			rounds[int(entry[0])] = true
			kinds[str(entry[1])] = true
			apart = apart and int(entry[0]) < game.ROUNDS.size() and Operator.KINDS.has(str(entry[1]))
		apart = apart and rounds.size() == game.operators_due.size() and kinds.size() == game.operators_due.size()
	game.level = "hard"
	game.plan_operators()
	var first_round: int = int(game.operators_due[0][0])
	var early: bool = game.operators_for(first_round - 1, false).is_empty() and game.operators_due.size() == 3
	var beside_boss: bool = game.operators_for(first_round, true).is_empty() and game.operators_due.size() == 3
	var came: Array = game.operators_for(first_round, false)
	var never_last: bool = game.operators_for(game.ROUNDS.size(), false).is_empty()
	game.mode = "endless"
	var endless_counts := {}
	for number in [4, 5, 6, 9, 13, 21, 25, 26, 29]:
		endless_counts[number] = game.operators_for(number, false).size()
	game.mode = mode_before
	game.level = game.profile.difficulty
	game.operators_due.clear()
	expect(int(counts.easy) == 1 and int(counts.normal) == 2 and int(counts.hard) == 3 and int(counts.nightmare) == 3 and apart and early and beside_boss and came.size() == 1 and never_last and endless_counts == {4: 0, 5: 1, 6: 0, 9: 1, 13: 2, 21: 2, 25: 3, 26: 0, 29: 3}, "The harder the night, the more operators come - one, two, three - each in a round of his own, never beside a Crusher, never in the last; the endless night brings one, later two, in the end all three at once (%s)" % str(endless_counts))
	# --- their looks are skins for whoever drove them off
	var book := Profile.new()
	book.stored = false
	var locked: bool = not book.unlocked("phantom") and not book.unlocked("havoc") and not book.unlocked("ghost")
	book.record("normal", {"victory": false, "score": 10, "seconds": 60, "kills": 3, "havoc": 1})
	expect(locked and book.unlocked("havoc") and not book.unlocked("ghost") and int(book.totals.havoc) == 1 and book.progress("ghost").contains("0 / 1"), "An operator's look is a skin for whoever has driven him off once")
	# --- once Nadja is out, the voice of command is not Coleman's
	var story: StoryDirector = game.story
	var was_on: bool = story.enabled
	var was_at: String = story.stage
	story.enabled = true
	story.stage = "lab"
	game.radio_queue.clear()
	game.radio_busy = 0.0
	game._say("round_clear")
	var honest: bool = not Radio.hijacked and not hud.radio_label.text.contains("#")
	story.stage = "escort"
	game.radio_busy = 0.0
	game._say("round_clear")
	var taken: bool = Radio.hijacked and hud.radio_label.text.begins_with("COLEMAN:") and hud.radio_label.text.contains("#")
	var said: Dictionary = Radio.pick("evac_start")
	var nadja_line: Dictionary = Radio.pick("nadja_static")
	story.stage = was_at
	story.enabled = was_on
	game.radio_busy = 0.0
	game._say("round_clear")
	expect(honest and taken and bool(said.fake) and str(said.sound) != "" and not bool(nadja_line.fake) and not Radio.hijacked and is_equal_approx(float(game.sounds.FAKE_PITCH), 0.955) and Radio.LINES.has("nadja_channel"), "From the moment Nadja is out of her cell the lines of command come over a taken-over channel: lower, breaking up, a letter lost here and there - and only command's")
	game.radio_queue.clear()
	game.radio_busy = 0.0
	# --- two versions of the game cannot play together, and both are told so
	# (In the lobby, that is: with a match running it would also end the match.)
	var net: NetLink = game.net
	var state_before: String = game.state
	game.state = "menu"
	net.close()
	net.clash = ""
	net.partner = 7
	net._on_hello(net.version)
	var same: bool = net.matched() and net.clash == ""
	hud.show_menu("join")
	net._on_hello("0.18")
	var other: bool = not net.matched() and net.partner == 7 and net.clash.contains("v0.18") and net.clash.contains("v" + NetLink.VERSION)
	# Such a host starts nothing here.
	var run_before: int = game.wave
	game.wave = 77
	net._begin("hard")
	other = other and game.wave == 77 and game.state == "menu"
	game.wave = run_before
	var written := ""
	for node in hud.modal.find_children("*", "Label", true, false):
		written += (node as Label).text + " "
	# One that never says its version is one from before the greeting.
	net.clash = ""
	net.partner_version = ""
	net.hello_left = 0.05
	net._process(0.1)
	var silent: bool = net.clash.contains("ältere") and not net.matched()
	net.close()
	net.clash = ""
	game.state = state_before
	hud.show_menu("main")
	var stamp := ""
	for node in hud.modal.find_children("*", "Label", true, false):
		stamp += (node as Label).text + " "
	expect(same and other and silent and written.contains("VERSIONEN PASSEN NICHT") and written.contains("v0.18") and stamp.contains("v" + NetLink.VERSION) and net.hello != null and net.hello.name == "Hello", "Two players with different versions of the game are told so in the lobby instead of getting into a match that cannot work; one that never says its version counts as an older one")
	hud.hide_menu()

## What came with v0.20: the test room - the farm without a night, where every enemy can
## be called, nothing can kill, every weapon is to be had and every recorded line can be
## played, and of which nothing is kept.
func _sandbox(game: Node3D) -> void:
	var player: Survivor = game.player
	var hud: SurvivalHUD = game.hud
	var room: Sandbox = game.sandbox
	var cabin: CabinMap = game.cabin
	var runs_before: int = game.profile.best(Profile.board(game.profile.difficulty, "endless")).size()
	var kept_mode: String = game.profile.mode
	# As it is reached in play: from the main menu.
	game.return_to_menu()
	await frames(2)
	game.team_enabled = true
	game.start_run(true)
	await frames(3)
	var yard: Vector3 = cabin.points.yard_south
	expect(room.on and game.mode == "endless" and not game.story.enabled and game.team.is_empty() and game.state == "playing" and game.phase == "preparing" and game.credits == Sandbox.SUPPLY and game.wave == 5 and player.global_position.distance_to(yard) < 1.0 and game.profile.mode == kept_mode, "The test room is a match of its own: no story, no squad, no bill, the survivor in the yard - and the mode chosen for the next night is left alone")
	expect(cabin.daylight and not cabin.environment.fog_enabled and not cabin.environment.volumetric_fog_enabled and not cabin.rain.visible and cabin.sun != null and cabin.sun.visible and game.sounds.dry, "It begins by daylight: no fog, no rain, a sun")
	# No round comes by itself.
	game.set_process(true)
	game.preparation_left = 0.4
	await wait(1.2)
	game.set_process(false)
	expect(game.phase == "preparing" and game.wave == 5 and game.alive_count == 0 and game.preparation_left > 1000.0, "No round begins by itself in the test room")
	# --- every kind of enemy, where he looks
	var kinds: Array = []
	for group in [Sandbox.INFECTED, Sandbox.SOLDIERS, Sandbox.OPERATORS]:
		for entry in group:
			kinds.append(str(entry[0]))
	var all_there := kinds.size() == Infected.TYPES.size()
	for kind in Infected.TYPES:
		all_there = all_there and kinds.has(str(kind))
	room.frozen = true
	var placed := true
	var told := ""
	for kind in kinds:
		var made: Array = room.spawn(kind)
		var good: bool = made.size() == 1
		if good:
			var one: Infected = made[0]
			var gap: float = Vector2(one.global_position.x - player.global_position.x, one.global_position.z - player.global_position.z).length()
			# In front of him (he looks north, towards the house), at about the distance asked for.
			good = one.kind == kind and one.wave == 5 and gap > 3.0 and gap < Sandbox.GAP + 6.0 and one.global_position.z < player.global_position.z - 2.0 and not one.is_physics_processing()
		if not good:
			placed = false
			told += kind + " "
		room.clear()
		await frames(2)
	expect(all_there and placed and room.alive() == 0 and game.alive_count == 0 and game.operators.is_empty(), "Every kind of enemy the game has - %d of them - can be put in front of the survivor and taken away again %s" % [kinds.size(), told])
	# Several at once, and a whole C.R.U. squad.
	room.count = 5
	var pack: Array = room.spawn("mauler")
	var apart := pack.size() == 5
	for i in range(pack.size()):
		for j in range(i):
			apart = apart and (pack[i] as Infected).global_position.distance_to((pack[j] as Infected).global_position) > 1.0
	room.clear()
	await frames(2)
	room.count = 1
	var squad: Array = room.spawn("squad")
	var squad_kinds := {}
	for soldier in squad:
		squad_kinds[(soldier as Infected).kind] = true
	expect(apart and squad.size() == Sandbox.SQUAD.size() and squad_kinds.has("cru_shield") and squad_kinds.has("cru_elite") and squad_kinds.has("cru_commander"), "Five at a click stand side by side, and a whole C.R.U. squad comes at one")
	room.clear()
	await frames(2)
	# Frozen, they stand; set free, they come.
	room.frozen = true
	var walker: Infected = room.spawn("mauler")[0]
	var stood: Vector3 = walker.global_position
	await frames(50)
	var still: bool = walker.global_position.distance_to(stood) < 0.05 and not walker.is_physics_processing()
	room.frozen = false
	await frames(150)
	expect(still and is_instance_valid(walker) and walker.is_physics_processing() and walker.global_position.distance_to(stood) > 0.5, "Frozen enemies stand where they were put; set free, they come for him")
	room.clear()
	await frames(2)
	# --- nothing kills
	player.health = 100.0
	player.armor = 50.0
	player.receive_damage(500.0)
	var unhurt: bool = player.health == 100.0 and player.armor == 50.0 and not player.down and game.state == "playing"
	room.god = false
	player.receive_damage(60.0)
	var hurt: bool = player.health < 100.0
	player.receive_damage(5000.0)
	expect(unhurt and hurt and player.health == 100.0 and not player.down and game.state == "playing" and hud.banner_label.text == "GEFALLEN", "With endless health nothing takes anything; without it he can be hurt, and stands again at once when he falls")
	room.god = true
	player.armor = 0.0
	# --- ammunition
	player.inventory[player.current_weapon].reserve = 0
	player.inventory[player.current_weapon].ammo = 3
	player.items.grenade = 0
	await frames(3)
	var pockets: bool = player.reserve == player.max_reserve() and player.ammo == 3 and int(player.items.grenade) == int(Survivor.GOODS.grenade.max)
	room.ammo = "magazine"
	await frames(3)
	var magazine: bool = player.ammo == player.magazine_size()
	room.ammo = "off"
	player.inventory[player.current_weapon].reserve = 7
	player.inventory[player.current_weapon].ammo = 2
	await frames(3)
	expect(pockets and magazine and player.reserve == 7 and player.ammo == 2, "Ammunition as he likes it: pockets that never empty, a magazine that never empties, or as in a mission")
	room.ammo = "reserve"
	# --- every weapon, and the counter wherever he stands
	room.arsenal()
	room.kit()
	var armed: bool = player.inventory.size() == player.weapon_models.size() and player.inventory.has("minigun") and player.inventory.has("nitro") and player.armor == 100.0 and player.mask_level == 4 and int(player.items.claymore) == 4
	player.inventory = {"rifle": {"ammo": 30, "reserve": 180, "level": 0}}
	player.equip_weapon("rifle", true)
	game.open_shop()
	var counter: bool = game.state == "shop" and game.closest_station().is_empty()
	# One that only comes late in a night, and one of a tree of abilities he may not have.
	var late: bool = game.buy_weapon("minigun")
	var classy: bool = game.buy_weapon("nitro") and player.inventory.has("nitro")
	player.items.grenade = 0
	var sold: bool = game.buy_item("grenade") and int(player.items.grenade) == 1
	game.resume_run()
	game.open_bench()
	var benched: bool = game.state == "bench" and game.buy_upgrade("damage") and player.upgrade(player.current_weapon, "damage") == 1
	game.resume_run()
	expect(armed and counter and late and classy and sold and benched and game.credits > 900000, "Every weapon at a click, and shop and workbench wherever he stands, with everything on offer and nothing to pay")
	# --- the voices
	var spoken := 0
	var recorded := 0
	for entry in Sandbox.SPEAKERS:
		for line in room.lines_of(str(entry[0])):
			spoken += 1
			if str(line.sound) != "":
				recorded += 1
	var written := 0
	for cue in Radio.LINES:
		written += (Radio.LINES[cue][1] as Array).size()
	for cue in Radio.BARKS:
		for who in Radio.BARKS[cue]:
			written += (Radio.BARKS[cue][who] as Array).size()
	room.say("phantom", "op_taunt", 1)
	var taunt: bool = room.now_playing.begins_with("PHANTOM:") and room.voice_left > 0.5 and hud.radio_label.text.begins_with("PHANTOM:") and game.sounds.radio_voice.playing
	room.say("ghost", "contact", 0)
	var call_heard: bool = room.now_playing.begins_with("GHOST:") and not hud.radio_label.text.begins_with("GHOST:")
	room.hijack = true
	room.say("coleman", "round_clear", 0)
	var taken: bool = hud.radio_label.text.begins_with("COLEMAN:") and hud.radio_label.text.contains("#") and is_equal_approx(game.sounds.radio_voice.pitch_scale, game.sounds.FAKE_PITCH)
	room.hijack = false
	room.say("coleman", "round_clear", 0)
	var honest: bool = not hud.radio_label.text.contains("#") and is_equal_approx(game.sounds.radio_voice.pitch_scale, 1.0)
	# All of one speaker, one after the other.
	room.say_all("shop")
	var queued: int = room.queue.size()
	await wait(0.3)
	var first_of_all: bool = room.now_playing.begins_with("HÄNDLERIN:") and room.queue.size() == queued - 1
	room.hush()
	expect(spoken == written and recorded == spoken and room.lines_of("phantom").size() == 85 and taunt and call_heard and taken and honest and queued == 6 and first_of_all and room.now_playing == "" and room.queue.is_empty(), "Every line of every speaker (%d, all recorded) can be played from the test room - Coleman on the taken-over channel too - one by one or all of a speaker in a row" % spoken)
	# --- the menu
	game.open_test()
	var pages := {}
	for page in ["enemies", "player", "voices", "world"]:
		room.tab = page
		hud.show_menu("test")
		var words := ""
		for node in hud.modal.find_children("*", "Button", true, false):
			words += (node as Button).text + " | "
		pages[page] = words
	var opened: bool = game.overlay == "test" and hud.current_menu == "test" and player.menu_open and not get_tree().paused
	# A click on a page: the Crusher from the first, the light from the last.
	hud._test_spawn("crusher")
	var called: bool = room.alive() == 1 and is_instance_valid(game.boss)
	hud._test_do("clear")
	hud._test_set("daylight", false)
	var dark: bool = not cabin.daylight and cabin.environment.fog_enabled and cabin.rain.visible and not cabin.sun.visible
	hud._test_set("daylight", true)
	hud._test_do("jump", "lab")
	var jumped: bool = game.overlay == "" and player.global_position.y < CabinMap.CELLAR + 0.5 and absf(player.global_position.z - (cabin.points.lab as Vector3).z) < 1.0
	room.jump("yard_south")
	expect(opened and str(pages.enemies).contains("CRUSHER") and str(pages.enemies).contains("PHANTOM") and str(pages.enemies).contains("GANZER TRUPP") and str(pages.player).contains("UNENDLICH LEBEN") and str(pages.player).contains("ALLE WAFFEN") and str(pages.voices).contains("ALLE NACHEINANDER") and str(pages.voices).contains("HAVOC") and str(pages.world).contains("TAGESLICHT") and called and room.alive() == 0 and dark and cabin.daylight and jumped, "The test room's menu has a page for enemies, one for the survivor, one for the voices and one for the world, and the room goes on behind it")
	# --- a real round on request, and none of it is kept
	room.strength = 3
	room.start_round()
	await frames(5)
	var began: bool = game.phase == "wave" and game.wave == 3 and game.spawn_queue.size() + game.alive_count > 0
	room.clear()
	await frames(3)
	var over: bool = game.phase == "preparing" and game.alive_count == 0 and game.state == "playing"
	game.finish(false)
	expect(began and over and game.state == "menu" and not room.on and not cabin.daylight and cabin.environment.fog_enabled and not game.sounds.dry and not game.skills.open_all and is_equal_approx(Engine.time_scale, 1.0) and game.profile.best(Profile.board(game.profile.difficulty, "endless")).size() == runs_before, "A real round can be started and ended from the test room, and leaving it brings the night back as it was - with nothing on the leaderboard")
	game.team_enabled = false
	game.start_run()
	expect(not room.on and game.mode == kept_mode and game.credits == 120 and cabin.environment.fog_enabled and not game.skills.open_all and game.team.is_empty(), "The next night is an ordinary one again")

## Takes every enemy off the field, also those a shot from the front would not (a shield).
## What the voice that was started last is playing (see FieldAudio._start).
func _latest_stream(sounds: Node) -> AudioStream:
	var latest: Node = null
	for voice in sounds.voices:
		if voice.has_meta("started") and (latest == null or int(voice.get_meta("started")) >= int(latest.get_meta("started"))):
			latest = voice
	return null if latest == null else latest.stream

func _wipe_all(game: Node3D) -> void:
	_wipe(game)
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if not enemy.dead:
			enemy._die(Vector3.FORWARD, false)

## The second mission (v0.21): its own map beside the farm, a night without rounds that
## goes from stage to stage, doors that open with the mission, checkpoints.
func _hive(game: Node3D) -> void:
	var player: Survivor = game.player
	var hive: HiveDirector = game.hive
	var profile: Profile = game.profile
	var kept_mode: String = profile.mode
	var farm: CabinMap = game.farm
	# --- the mission is chosen in the main menu, and what a night is filed under
	var kept_mission: int = profile.mission
	var hud: SurvivalHUD = game.hud
	profile.mode = "story"
	profile.mission = 1
	game.return_to_menu()
	await frames(2)
	var words := ""
	var mode_button: Button = null
	for node in hud.modal.find_children("*", "Button", true, false):
		words += (node as Button).text + " | "
	var first_play: String = profile.play()
	hud._choose_mission(2)
	for node in hud.modal.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("MODUS"):
			mode_button = node as Button
	expect(words.contains("MISSION 1") and words.contains("MISSION 2") and words.contains("EINSATZ STARTEN") and first_play == "story" and profile.mission == 2 and profile.play() == "villa" and profile.mode == "story" and words.contains("MODUS") and mode_button == null and Profile.board("normal", "villa") == "villa_normal" and Profile.board("normal", "story") == "normal", "Both missions are chosen in the main menu; the second has leaderboards of its own and neither an endless night nor modifiers")
	profile.mode = "endless"
	hud._next_board()
	var after_villa: String = profile.play()
	hud._next_board()
	var after_story: String = profile.play()
	hud._next_board()
	expect(after_villa == "story" and after_story == "endless" and profile.play() == "villa" and profile.mission == 2, "The list of the best goes from the story to the endless night to the second mission and round again")
	profile.mode = "story"
	# --- a night on the other map
	game.return_to_menu()
	await frames(2)
	game.team_enabled = true
	# (As after a night on the farm whose last C.R.U. squad came through its last gap: the
	# other map has fewer places to come in by.)
	game.cru_gate = farm.spawn_points.size() - 1
	game.cru_gate_uses = 1
	game.start_run()
	await frames(3)
	var map := game.cabin as HiveMap
	if map == null:
		expect(false, "The second mission has a map of its own")
		profile.mode = kept_mode
		profile.mission = kept_mission
		return
	var landing: Vector3 = map.points.landing_out
	expect(hive.on and game.mode == "villa" and not game.story.enabled and game.cabin != farm and not farm.is_inside_tree() and map.is_inside_tree() and game.state == "playing" and game.phase == "preparing" and hive.stage == "landing" and player.global_position.distance_to(landing) < 1.5 and game.team.size() == 2 and is_instance_valid(hive.nadja) and game.credits == 120, "The second mission is a night on its own map: the farm is out of the world, the squad and Nadja stand on the landing ground, no story of the farm runs")
	var shops := 0
	var benches := 0
	for station in map.stations:
		shops += 1 if str(station.kind) == "shop" else 0
		benches += 1 if str(station.kind) == "upgrade" else 0
	expect(map.floors.size() == 5 and map.navigation.size() == 5 and map.rooms.size() >= 50 and shops == 4 and benches == 4 and map.plans().size() == 5 and map.level_label(map.under) == "BAHNHOF" and map.abyss() < HiveMap.UNDER - 5.0, "The map has five floors, more than fifty rooms and four supply points, each with ammunition, first aid, a workbench and a weapon locker (%d rooms, %d doors)" % [map.rooms.size(), map.doors.size()])
	# --- no round comes by itself; the guards of the house come out when the squad nears it
	var quiet: bool = game.alive_count == 0
	player.global_position = Vector3(0, 0.05, 50)
	game.set_process(true)
	game.preparation_left = 0.3
	await wait(0.8)
	game.set_process(false)
	expect(quiet and game.phase == "preparing" and game.preparation_left > 1000.0 and game.alive_count >= 4 and game.wave == 2, "No round ever begins here: the mission posts its own enemies (%d at the villa)" % game.alive_count)
	_wipe_all(game)
	hive.set_process(false)
	await frames(3)
	# --- every area is shut at the start, and every way is there once it is open
	var shut: bool = map.is_locked("descent") and map.is_locked("station") and map.is_locked("admin") and map.is_locked("hall") and map.path_between(map.points.dining, map.points.vestibule).is_empty() and not map.door_open("car_a")
	for id in map.areas:
		map.unlock(str(id), true)
	var legs := [
		["landing", "front_door"], ["front_door", "hall"], ["hall", "gallery"], ["hall", "salon"], ["hall", "galerie"], ["hall", "library"], ["hall", "kitchen"], ["hall", "dining"],
		["dining", "vestibule"], ["vestibule", "lobby"], ["lobby", "platform"], ["platform", "booth"], ["platform", "depot"], ["platform", "supply_station"],
		["terminal", "control"], ["terminal", "gate_admin"], ["gate_admin", "checkpoint"], ["checkpoint", "supply_checkpoint"], ["checkpoint", "junction"], ["junction", "office"],
		["junction", "security"], ["junction", "server"], ["junction", "spine"], ["spine", "cafeteria"], ["cafeteria", "atrium"], ["atrium", "supply_atrium"], ["atrium", "maint"],
		["maint", "pump"], ["maint", "generator"], ["atrium", "decon"], ["decon", "labs"], ["labs", "cross"], ["cross", "hall_end"], ["hall_end", "lift"]
	]
	var broken: Array[String] = []
	var longest := 0.0
	for leg in legs:
		var route: PackedVector3Array = map.path_between(map.points[leg[0]], map.points[leg[1]])
		if route.is_empty() or route[route.size() - 1].distance_to(map.points[leg[1]]) > 2.5:
			broken.append("%s > %s" % [leg[0], leg[1]])
		longest = maxf(longest, map._length(route))
	expect(shut and broken.is_empty(), "Every way of the mission can be walked once its door is open, and none before%s" % ("" if broken.is_empty() else " - broken: " + ", ".join(PackedStringArray(broken))))
	# Every room can be reached from where its part of the map is entered.
	var cut_off: Array[String] = []
	for id in ["car_a", "car_b", "nadja"]:
		map.set_door(id, true, true)
	for room in map.rooms:
		if room.get("nav", true) == false or bool(room.outdoor):
			continue
		var level: int = room.level
		var from: Vector3 = map.points.landing if level in [map.ground, map.upper] else (map.points.platform if level == map.under else map.points.terminal)
		var middle: Rect2 = room.outer
		var cell: Vector2i = map._free_near(level, middle.get_center(), 12)
		if room.has("walk"):
			cell = map._free_near(level, (room.walk[0] as Rect2).get_center(), 12)
		if cell.x > 99999 or map.path_between(from, Vector3(cell.x * CabinMap.CELL, map.level_height(level), cell.y * CabinMap.CELL)).is_empty():
			cut_off.append(str(room.id))
	expect(cut_off.is_empty(), "No room is cut off from the rest%s" % ("" if cut_off.is_empty() else ": " + ", ".join(PackedStringArray(cut_off))))
	# --- on foot, with real steps: down the stairwell, and up to two galleries
	var climbs: Array[String] = []
	for walk in [["down the stairwell", Vector3(0, 0.05, -7.4), 9.0, HiveMap.UNDER, -28.0], ["up to the gallery of the hall", Vector3(5.5, 0.05, 20.4), 3.2, HiveMap.STOREY_VILLA, 11.8], ["up to the gallery of the terminal", Vector3(-26, HiveMap.UNDER + 0.05, -332.8), 3.2, HiveMap.DECK, -340.6]]:
		face(game, walk[1], 0.0)
		await frames(4)
		Input.action_press("move_forward")
		await frames(int(float(walk[2]) * 60.0))
		Input.action_release("move_forward")
		await frames(6)
		if absf(player.global_position.y - float(walk[3])) > 0.35 or player.global_position.z > float(walk[4]):
			climbs.append("%s: at %s" % [walk[0], str(player.global_position.snapped(Vector3.ONE * 0.1))])
	# Through a door that slides open for whoever comes: from the platform into the control room.
	face(game, Vector3(26.5, HiveMap.UNDER + 0.05, -38.4), PI)
	await frames(10)
	Input.action_press("move_forward")
	await frames(100)
	Input.action_release("move_forward")
	await frames(6)
	if str(map.room_at(player.global_position).get("id", "")) != "booth":
		climbs.append("through the sliding door of the control room: at %s" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	expect(climbs.is_empty(), "The stairs can be walked on foot: down the stairwell behind the mirror, up to the gallery of the hall and up to the gallery of the terminal%s" % ("" if climbs.is_empty() else " - not: " + ", ".join(PackedStringArray(climbs))))
	map.reset()
	map.lock_all()
	# --- the stages, one after the other (the survivor is set down where each one ends)
	hive.set_process(true)
	var reached: Array[String] = []
	var step := func(place: String, wanted: String) -> void:
		player.global_position = (map.points[place] as Vector3) + Vector3(0, 0.05, 0)
		for mate in game.team:
			mate.global_position = player.global_position + Vector3(1.2, 0, 0.8)
		await frames(8)
		reached.append(hive.stage)
		if hive.stage != wanted:
			print("HIVE_STEP %s: stage is %s, wanted %s" % [place, hive.stage, wanted])
	await step.call("front_door", "villa")
	_wipe_all(game)
	await step.call("dining", "mirror")
	hive.nadja.global_position = (map.points.keypad as Vector3) + Vector3(0, 0.05, 0.4)
	await frames(10)
	var working: bool = hive.progress >= 0.0 and hive.stage == "mirror" and map.is_locked("descent")
	hive.progress = 0.995
	await frames(30)
	var opened: bool = hive.stage == "descent" and not map.is_locked("descent") and hive.checkpoint == "descent" and not map.path_between(map.points.dining, map.points.vestibule).is_empty()
	expect(reached == ["villa", "mirror"] and working and opened, "Reaching the villa and its dining room moves the mission on; Nadja works the lock by the mirror, and when she is done the way down is open and a checkpoint is set (%s)" % str(reached))
	_wipe_all(game)
	reached.clear()
	await step.call("lobby", "station")
	var guarded: int = hive._guards_left()
	_wipe_all(game)
	await frames(4)
	hive.stage_time = 5.0
	await frames(6)
	var leaving: bool = hive.stage == "nadja" and map.door_open("nadja") and not game.survivors.has(hive.nadja)
	hive.stage_time = 12.5
	await frames(12)
	var locked_in: bool = not map.door_open("nadja") and hive.channel_taken()
	# What is said carries the rest of the scene. Here every line is over as soon as it
	# has begun, and nobody has to walk anywhere: who spoke, in which order?
	var dealt := false
	var early := false
	var heard: Array[String] = []
	var shown := ""
	for turn in range(300):
		if hive.stage == "power" and hive.puppets.is_empty() and hive.lines.is_empty():
			break
		hive.line_left = 0.0
		hive.hold_left = 0.0
		game.bark_until.clear()
		for puppet: Dictionary in hive.puppets:
			if bool(puppet.leaving) and is_instance_valid(puppet.node):
				(puppet.node as Node3D).global_position = puppet.goal
		await _turn(hive)
		if hive.stage == "deal" and not dealt:
			dealt = hive.nadja_gone and not is_instance_valid(hive.nadja) and hive.puppets.size() == 3
		# (The control room can be used while the last words are still being said.)
		early = early or (hive.stage == "power" and not hive.lines.is_empty())
		if hud.radio_label.text != shown:
			shown = hud.radio_label.text
			heard.append(("~" if shown.contains("#") else "") + shown.get_slice(":", 0))
	var order := ",".join(PackedStringArray(heard))
	# (What was said on the way here is still being said: it comes first. A "~" marks words that came through a taken channel.)
	var told: bool = order.ends_with("NADJA,NADJA,NADJA,SCORPION,VIPER,SCORPION,VIPER,PHANTOM,HAVOC,GHOST,GHOST,COLEMAN,COLEMAN,VIPER,SCORPION,PHANTOM,HAVOC,GHOST,VIPER,SCORPION,COLEMAN") and order.contains("~COLEMAN") and order.rfind("~COLEMAN") < order.find("PHANTOM") and not hive.channel_taken()
	if not told:
		print("HIVE_STATION heard: ", order)
	expect(reached == ["station"] and guarded >= 6 and leaving and locked_in and dealt and early and hive.stage == "power" and hive.puppets.is_empty(), "At the station the guards have to fall; then Nadja leaves through a door that shuts behind her, the three operators come and go, and the train can be started while the last words are still being said (%d guards)" % guarded)
	var relay_kept: bool = hive.leavers.size() == 1 and bool(hive.leavers[0].keep) and str((hive.leavers[0].node as Teammate).look) == "ghost" and game.team.size() == 2
	expect(told and relay_kept, "What is said at the station comes in its order, nobody talking over anybody: Nadja through the glass, the squad about her, the three operators, - once Ghost has cleared the channel - a Coleman whose words come through whole, and then who stays and who goes, each with his reason; Ghost stays at the relay")
	player.global_position = (map.points.booth as Vector3) + Vector3(0, 0.05, 0)
	await frames(4)
	var asked: bool = hive.prompt() != "" and game.interaction_prompt() == hive.prompt()
	game.interact()
	await frames(4)
	var holding: bool = hive.stage == "hold" and hive.progress >= 0.0
	hive.progress = 0.999
	await frames(20)
	var boarding: bool = hive.stage == "board" and map.door_open("car_a")
	_wipe_all(game)
	player.global_position = (map.points.car_a as Vector3) + Vector3(0, 0.05, 0)
	await frames(110)
	var rolling: bool = hive.stage == "ride" and not map.door_open("car_a")
	hive.stage_time = 1.7
	await frames(6)
	var moved: bool = player.global_position.distance_to(map.points.car_b) < 2.0 and map.riding and map.room_at(game.team[0].global_position).get("id", "") == "car_b" and hive.leavers.is_empty() and hive.puppets.is_empty()
	hive.stage_time = HiveDirector.RIDE_SECONDS + 0.1
	await frames(6)
	expect(asked and holding and boarding and rolling and moved and hive.stage == "terminal" and not map.riding and map.door_open("car_b") and hive.checkpoint == "terminal", "The train is brought up from the control room while the platform is held; then the squad boards, the doors close, and the car is the one at the terminal")
	_wipe_all(game)
	reached.clear()
	player.global_position = (map.points.control as Vector3) + Vector3(0, 0.05, 0)
	await frames(4)
	game.interact()
	await frames(4)
	reached.append(hive.stage)
	var gate_up: bool = not map.is_locked("admin")
	_wipe_all(game)
	await step.call("junction", "security")
	player.global_position = (map.points.security as Vector3) + Vector3(0, 0.05, 0)
	await frames(4)
	game.interact()
	await frames(4)
	reached.append(hive.stage)
	_wipe_all(game)
	await step.call("cafeteria", "lockdown")
	var sealed: bool = map.is_locked("cafe") and map.path_between(map.points.cafeteria, map.points.junction).is_empty() and not map.path_between(map.points.cafeteria, (map.points.cafeteria as Vector3) + Vector3(6, 0, 4)).is_empty()
	hive.progress = 0.999
	await frames(20)
	reached.append(hive.stage)
	expect(reached == ["admin", "security", "cafe", "lockdown", "atrium"] and gate_up and sealed and not map.is_locked("cafe") and not map.is_locked("atrium") and hive.checkpoint == "atrium", "The gate of the terminal opens from the control room, the way north from the security centre; the canteen shuts the squad in for a while and then lets it on (%s)" % str(reached))
	_wipe_all(game)
	reached.clear()
	await step.call("atrium", "generator")
	player.global_position = (map.points.generator as Vector3) + Vector3(0, 0.05, 0)
	await frames(4)
	game.interact()
	await frames(4)
	reached.append(hive.stage)
	_wipe_all(game)
	player.global_position = (map.points.decon as Vector3) + Vector3(0, 0.05, 0)
	await frames(6)
	hive.progress = 0.999
	await frames(20)
	reached.append(hive.stage)
	_wipe_all(game)
	await step.call("cross", "hall")
	_wipe_all(game)
	player.global_position = (map.points.hall_end as Vector3) + Vector3(0, 0.05, 0)
	await frames(6)
	hive.progress = 0.999
	await frames(20)
	reached.append(hive.stage)
	_wipe_all(game)
	player.global_position = (map.points.lift as Vector3) + Vector3(0, 0.05, 0)
	await frames(8)
	var last_word: bool = (not game.radio_queue.is_empty() and str(game.radio_queue[-1][0]) == "m2_end") or hud.radio_label.text.contains("losing your signal")
	expect(reached == ["generator", "decon", "labs", "hall", "exit"] and game.state == "win" and hive.on and hive.checkpoint == "labs" and last_word and hive.lines.is_empty(), "Power for the sluice, the sluice, the laboratories, the containment hall and the freight lift end the mission, and the last word is Coleman's (%s, state %s)" % [str(reached), game.state])
	# --- taking it up again at a checkpoint
	hive.resume_at = "terminal"
	game.start_run()
	await frames(4)
	expect(hive.on and hive.stage == "terminal" and hive.checkpoint == "terminal" and player.global_position.distance_to(map.points.car_b) < 1.5 and not is_instance_valid(hive.nadja) and not map.is_locked("station") and map.is_locked("admin") and map.door_open("car_b") and game.credits >= 900 and game.cabin == map, "A defeat can be taken up at the last checkpoint: the squad stands in the car at the terminal, what lies behind it is open, what lies ahead is shut")
	# --- what the passes over the map's design added: the plan of the Hive on its walls,
	# the lockdown's light and horn with the lock of the canteen, the flooded stretch of
	# the laboratory corridor, the voices of the place
	# (A screen is known by what it shows: two of a name under one node lose theirs.)
	var plans_shown := 0
	var wet := false
	for node in map.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null or drawn.mesh.get_surface_count() == 0:
			continue
		var shows: Material = drawn.mesh.surface_get_material(0)
		if shows == map.plan.get("material"):
			plans_shown += 1
		elif shows == map.mats["flood"] and drawn.get_aabb().grow(0.3).has_point(Vector3(0, HiveMap.UNDER + 0.3, -558.0)):
			wet = true
	expect(plans_shown >= 12, "The plan of the Hive is shown in at least twelve places of the map (%d screens)" % plans_shown)
	map.unlock("cafe", true)
	await frames(2)
	var alarm_off: bool = not map.alarm_on and not map.alarm_node.visible
	map.lock("cafe", true)
	await frames(2)
	var alarm_seen: bool = map.alarm_on and map.alarm_node.visible and map.sound != null and bool(map.sound.get("alarm_on"))
	map.unlock("cafe", true)
	await frames(2)
	var alarm_gone: bool = not map.alarm_on and not map.alarm_node.visible and not bool(map.sound.get("alarm_on"))
	map.lock("cafe", true)
	map.set_alarm(false)
	var voices: Vector2i = map.sound.call("count")
	expect(alarm_off and alarm_seen and alarm_gone and not map.alarm_on, "The lockdown's red light and its horn come with the lock of the canteen and go when it opens")
	expect(wet and map.room_of.has("flooded") and map.drip_mesh != null and map.spark_mesh != null and voices.x >= 12 and voices.x == voices.y, "Water stands in the laboratory corridor under drips and sparks, and every voice of the map has its sound (%d of %d)" % [voices.y, voices.x])
	# --- the tower hall: the house's towers in ranks with room for the Prowler between
	# them, one torn open; and the terminals in the walls of the facility - two films for all
	# their screens, and none of them played in a run without a window
	var hall_room: Dictionary = map.room_of.get("containment", {})
	var towers_all := 0
	for tower_kind in map.tower_count:
		towers_all += int(map.tower_count[tower_kind])
	var hall_ground: float = hive.prowl.open_ground(map.points.hall_end)
	var hall_wide: float = hive.prowl.width_of(map.points.hall_end)
	var hall_ways: bool = not map.path_between(map.points.hall_end, map.points.lift).is_empty() and not map.path_between(map.points.hall_end, map.points.hall_end + Vector3(-26.0, 0, 22.0)).is_empty()
	expect(not hall_room.is_empty() and float(hall_room.height) >= 14.0 and int(map.tower_count.get("shaft", 0)) == 4 and int(map.tower_count.get("burst", 0)) == 1 and int(map.tower_count.get("cage", 0)) >= 8 and int(map.tower_count.get("tank", 0)) >= 8 and hall_ground >= HiveProwler.ROOM_MIN and hall_wide >= HiveProwler.WIDE and hall_ways and map.hall_life != null, "The containment hall is the tower hall: %d towers and pumps in ranks, one of them torn open, ways from its middle to the lift and into its corners, and room for the Prowler in its middle (%d m2, %.1f m wide)" % [towers_all, int(hall_ground), hall_wide])
	var term_screens: int = map.terminals.call("count")
	var term_films: Vector2i = map.terminals.call("players")
	var term_shared: bool = map.terminals.call("shared")
	var term_both: bool = int(map.terminals.call("count", "specimen")) >= 5 and int(map.terminals.call("count", "crucible")) >= 5
	var term_still: bool = DisplayServer.get_name() != "headless" or (term_films == Vector2i.ZERO and not bool(map.terminals.get("films")))
	var term_tags: int = map.find_children("*TerminalTag*", "Label3D", true, false).size()
	expect(term_screens >= 12 and term_screens == map.terminal_places.size() and term_tags == term_screens - 1 and term_both and term_shared and term_films.x <= 2 and term_still, "Terminals in the walls of the facility: %d screens show two loops, every loop on one surface for all its screens, and no film is played in a run without a window (%d players)" % [term_screens, term_films.x])
	# --- the ways in: holes in ceilings and walls, windows, the edge of the platform - where
	# they are, that somebody who comes through one stands on free ground from which he gets
	# at the survivor, that the director uses them to flank, and what camping brings
	var ways: HiveEntries = hive.entries
	hive.set_process(false)
	hive.prowl.set_process(false)
	_wipe_all(game)
	for id in map.areas:
		map.unlock(str(id), true)
	for mate in game.team:
		mate.set_physics_process(false)
		mate.global_position = (map.points.landing as Vector3) + Vector3(2, 0.05, 0)
	await frames(3)
	var way_rooms := {}
	var way_kinds := {}
	var way_faults: Array[String] = []
	for entry in map.entries:
		way_rooms[str(entry.room)] = int(way_rooms.get(str(entry.room), 0)) + 1
		way_kinds[str(entry.kind)] = int(way_kinds.get(str(entry.kind), 0)) + 1
		var way_land: Vector3 = entry.land
		if way_land == Vector3.INF:
			way_faults.append("%s: no ground" % entry.id)
			continue
		var way_level: int = map.level_of(way_land + Vector3(0, 0.3, 0))
		var way_from: Vector3 = map.points.landing if way_level in [map.ground, map.upper] else (map.points.platform if way_level == map.under else map.points.terminal)
		var way_cell := Vector2i(roundi(way_land.x / CabinMap.CELL), roundi(way_land.z / CabinMap.CELL))
		if not bool(entry.get("fixed", false)) and map.navigation[way_level].is_point_solid(way_cell):
			way_faults.append("%s: its ground is closed" % entry.id)
		elif map.path_between(way_land, way_from).is_empty():
			way_faults.append("%s: no way from it" % entry.id)
		elif is_instance_valid(entry.node) == (str(entry.kind) == "edge"):
			way_faults.append("%s: nothing to rattle" % entry.id)
	expect(map.entries.size() >= 100 and way_faults.is_empty() and way_kinds.size() == 6 and int(way_kinds.get("drop", 0)) >= 30 and int(way_kinds.get("hole", 0)) >= 30 and int(way_kinds.get("duct", 0)) >= 10 and int(way_kinds.get("window", 0)) >= 8, "The map has more than a hundred ways in through ceilings, walls, windows and over the edge of the platforms, each leading to free ground that is joined to the rest (%d: %s)%s" % [map.entries.size(), str(way_kinds), "" if way_faults.is_empty() else " - " + ", ".join(PackedStringArray(way_faults.slice(0, 6)))])
	var thin: Array[String] = []
	for need in [["ring_s", 8], ["spine", 4], ["lab_corridor", 5], ["cross", 4], ["maint", 4], ["platform", 7], ["stairs", 1], ["stair_lobby", 1], ["terminal", 6], ["cafeteria", 6], ["atrium", 6], ["containment", 6], ["dining", 2], ["checkpoint", 2]]:
		if int(way_rooms.get(str(need[0]), 0)) < int(need[1]):
			thin.append("%s has %d" % [need[0], int(way_rooms.get(str(need[0]), 0))])
	expect(thin.is_empty(), "Every long passage - the ring, the spine, the laboratory corridor, the crossing, the plant passage, the stairs, the platform - and every hall that is held has its ways in%s" % ("" if thin.is_empty() else ": " + ", ".join(PackedStringArray(thin))))
	# Where a squad could sit tight: every room with a single door, and every supply point
	# under a roof. (Nadja's lock is hers alone, and nobody stays in the car of a train.)
	var snug: Array[String] = []
	for room in map.rooms:
		if bool(room.outdoor) or room.get("nav", true) == false or room.get("walls", true) == false or (room.doors as Array).size() != 1 or str(room.id) == "airlock":
			continue
		if not way_rooms.has(str(room.id)):
			snug.append(str(room.id))
	var far_supply := 0
	for station in map.stations:
		if str(station.kind) != "shop" or not map.is_indoors(station.pos):
			continue
		var nearest_way := INF
		for entry in map.entries:
			nearest_way = minf(nearest_way, (entry.land as Vector3).distance_to(station.pos))
		if nearest_way > 14.0:
			far_supply += 1
	expect(snug.is_empty() and far_supply == 0 and way_rooms.has("booth") and way_rooms.has("control") and way_rooms.has("guard") and way_rooms.has("generator") and way_rooms.has("security"), "Every room with a single door has a way in of its own, every room the mission sends the squad into, and every supply point under a roof has one near%s" % ("" if snug.is_empty() else " - without: " + ", ".join(PackedStringArray(snug))))
	# --- somebody comes through each kind of them
	hive.stage = "admin"
	hive.stage_time = 30.0
	var through: Array[String] = []
	var longest_way := 0.0
	for trial in [["ring_s_drop", Vector3(-33, 0, -365)], ["ring_s_hole", Vector3(-27, 0, -365)], ["ring_s_duct", Vector3(-15, 0, -365)], ["dining_window", Vector3(0, 0, 5.6)], ["kitchen_cellar", Vector3(17, 0, 5)], ["platform_edge", Vector3(-18, 0, -45)]]:
		var way_index := -1
		for k in range(map.entries.size()):
			if way_index < 0 and str(map.entries[k].id).begins_with(str(trial[0])):
				way_index = k
		if way_index < 0:
			through.append("%s: missing" % trial[0])
			continue
		var way: Dictionary = map.entries[way_index]
		var goal: Vector3 = way.land
		face(game, Vector3((trial[1] as Vector3).x, goal.y + 0.05, (trial[1] as Vector3).z), 0.0)
		await frames(2)
		var comer: Infected = ways.come(way_index, "mauler")
		if comer == null:
			through.append("%s: nobody came" % way.id)
			continue
		var began_at := comer.global_position
		var carried: bool = comer.entering == ways and began_at.distance_to(goal) > 0.6
		var steps := 0
		while is_instance_valid(comer) and comer.entering != null and steps < 150:
			await frames(1)
			steps += 1
		longest_way = maxf(longest_way, steps / 60.0)
		var stands: bool = is_instance_valid(comer) and not comer.dead and Vector2(comer.global_position.x - goal.x, comer.global_position.z - goal.z).length() < 0.5 and absf(comer.global_position.y - goal.y) < 0.3
		var gap_before: float = comer.global_position.distance_to(player.global_position) if stands else 0.0
		var reaches: bool = stands and not map.path_between(comer.global_position, player.global_position).is_empty()
		await frames(80)
		var nearer: bool = is_instance_valid(comer) and (comer.dead or comer.global_position.distance_to(player.global_position) < gap_before - 0.5)
		if not (carried and stands and reaches and nearer and steps < 80 and absf(steps / 60.0 - ways.seconds(way_index)) < 0.2):
			through.append("%s: carried %s stands %s reaches %s nearer %s after %d steps (meant %.2f s)" % [way.id, str(carried), str(stands), str(reaches), str(nearer), steps, ways.seconds(way_index)])
		_wipe_all(game)
		await frames(2)
	expect(through.is_empty() and longest_way < 1.25, "Out of a ceiling, out of a hole in a wall, out of a duct, through a window, out of the cellar and up from the track: whoever comes through is carried to free ground within about a second and goes for the survivor from there (the longest took %.2f s)%s" % [longest_way, "" if through.is_empty() else " - " + "; ".join(PackedStringArray(through))])
	# Shot on the way down, the body still comes down; and not everybody fits through.
	var drop_way := -1
	for k in range(map.entries.size()):
		if drop_way < 0 and str(map.entries[k].id).begins_with("office_drop"):
			drop_way = k
	face(game, (map.points.office as Vector3) + Vector3(-6, 0.05, 6), 0.0)
	var faller: Infected = ways.come(drop_way, "striker")
	await frames(8)
	var in_the_air: bool = faller.global_position.y > HiveMap.UNDER + 1.0 and faller.entering == ways
	faller.receive_hit(99999.0, Vector3.FORWARD)
	await frames(50)
	var came_down: bool = faller.dead and faller.entering == null and absf(faller.global_position.y - HiveMap.UNDER) < 0.2
	var size_matters: bool = not ways.send("crusher") and not ways.send("prowler") and not ways.send("cru_assault") and not ways.send("cru_shield") and ways.due.is_empty()
	expect(in_the_air and came_down and size_matters, "An infected shot on its way out of a ceiling falls to the floor like any other; the Crusher, the Prowler and the soldiers cannot use a way in at all")
	_wipe_all(game)
	await frames(2)
	# --- the director: not in the first seconds of a stage, never where nobody keeps coming,
	# and mostly from behind and from the side
	var truce := true
	for id in ["station", "nadja", "deal", "power", "board", "ride"]:
		truce = truce and not HiveDirector.PRESSURE.has(id)
	face(game, Vector3(0, HiveMap.UNDER + 0.05, -365), -PI / 2)
	await frames(2)
	hive.stage_time = 2.0
	var too_soon: bool = not ways.send("mauler")
	hive.stage_time = 30.0
	ways.camp_time = 0.0
	var sides := {"behind": 0, "beside": 0, "ahead": 0}
	var near_ones := 0
	var looks := -player.global_basis.z
	for k in range(240):
		var pick := ways.choose()
		if pick < 0:
			continue
		var to_way: Vector3 = (map.entries[pick].land as Vector3) - player.global_position
		var side := Vector2(looks.x, looks.z).normalized().dot(Vector2(to_way.x, to_way.z).normalized())
		sides["behind" if side < -0.25 else ("beside" if side < 0.55 else "ahead")] += 1
		if to_way.length() < HiveEntries.KEEP:
			near_ones += 1
	expect(truce and too_soon and near_ones == 0 and int(sides.behind) > int(sides.ahead) * 1.5 and int(sides.behind) + int(sides.beside) + int(sides.ahead) >= 200, "Nobody comes through a way in during the first seconds of a stage or while there is a truce; in a passage they come mostly behind the survivor's back, never on top of him (behind %d, beside %d, ahead %d)" % [int(sides.behind), int(sides.beside), int(sides.ahead)])
	# --- a stage runs: most of those who keep coming take a way in, with a warning first
	hive.stage = "lockdown"
	ways.came = 0
	ways.passed = 0
	ways.used.clear()
	ways.told.clear()
	hud.banner_left = 0.0
	var warned := 0
	for k in range(600):
		hive.stage_time += 0.05
		hive._run_pressure(0.05)
		warned = maxi(warned, ways.coming())
		ways.camp_time = 0.0
		ways._process(0.05)
		if game.alive_count >= 6:
			_wipe_all(game)
	var open_share: float = float(ways.came) / maxf(1.0, ways.came + ways.passed)
	expect(ways.came >= 4 and warned >= 1 and open_share > 0.4 and ways.told.has("hole"), "While a stage runs, most of those who keep coming are announced at a way in and come through it - the first time the survivor is told what the noise means -; the others come as before, from where nobody looks (%d of %d)" % [ways.came, ways.came + ways.passed])
	_wipe_all(game)
	await frames(2)
	# --- camping: staying put is noticed, and answered from the nearest ways in - the one
	# in the survivor's own room among them -, sooner and with more
	face(game, Vector3(27.5, HiveMap.UNDER + 0.05, -410.0), 0.0)
	hive.stage = "lockdown"
	hive.stage_time = 30.0
	ways.camp_at = Vector3.INF
	await frames(30)
	var counting: bool = ways.camp_time > 0.3 and ways.camp_time < 0.8 and ways.heat() == 0.0 and ways.haste() == 1.0 and ways.more() == 0
	face(game, Vector3(27.5, HiveMap.UNDER + 0.05, -420.0), 0.0)
	await frames(6)
	var moved_on: bool = ways.camp_time < 0.2
	face(game, Vector3(27.5, HiveMap.UNDER + 0.05, -410.0), 0.0)
	await frames(6)
	ways.camp_time = HiveEntries.CAMP_AFTER + HiveEntries.CAMP_FULL + 1.0
	var hot: bool = ways.heat() == 1.0 and is_equal_approx(ways.haste(), HiveEntries.CAMP_HASTE) and ways.more() == HiveEntries.CAMP_MORE
	var nearest_three: Array = ways.found(player.global_position).slice(0, HiveEntries.CAMP_NEAREST)
	var own_room := 0
	var strays := 0
	ways.came = 0
	ways.passed = 0
	ways.used.clear()
	for k in range(600):
		hive.stage_time += 0.05
		hive._run_pressure(0.05)
		ways.camp_time = HiveEntries.CAMP_AFTER + HiveEntries.CAMP_FULL + 1.0
		ways._process(0.05)
		if game.alive_count >= 10:
			_wipe_all(game)
	for index in ways.used:
		var close := false
		for item: Array in nearest_three:
			close = close or int(item[1]) == index
		if str(map.entries[index].room) == "kitchen_f":
			own_room += 1
		elif not close and (map.entries[index].land as Vector3).distance_to(player.global_position) > 22.0:
			strays += 1
	expect(counting and moved_on and hot and ways.used.size() >= 12 and ways.passed == 0 and own_room >= 3 and strays == 0, "A survivor who stays in one place is noticed after a while: then everybody comes through the ways in nearest to him - also the one in his own room -, sooner than the stage says and a few more at once (%d in half a minute, %d of them in his room)" % [ways.used.size(), own_room])
	_wipe_all(game)
	for mate in game.team:
		mate.set_physics_process(true)
	hive.prowl.set_process(true)
	hive.set_process(true)
	await frames(3)
	# --- and back to the farm
	game.return_to_menu()
	await frames(3)
	profile.mode = "story"
	profile.mission = 1
	var home: bool = game.cabin == farm and farm.is_inside_tree() and not map.is_inside_tree() and not hive.on and game.state == "menu" and not game.sounds.dry
	game.team_enabled = false
	game.start_run()
	await frames(3)
	expect(home and game.cabin == farm and game.mode == "story" and not hive.on and game.phase == "preparing" and game.credits == 120 and player.global_position.y > -1.0 and not farm.path_between(farm.points.yard_south, farm.points.hall).is_empty(), "Back in the menu the farm is in the world again, and the next night there is an ordinary one")
	profile.mode = kept_mode
	profile.mission = kept_mission
	# --- nothing stands in a doorway of the map: no wall, no plinth or wainscot that runs
	# on through it, no rib, no model. A second map is built for this, apart from the tree
	# and with every one of its boxes noted (see HiveCore.doorway_faults, which
	# tools/door_check.gd prints in full).
	MeshBatch.watched.clear()
	MeshBatch.watching = true
	var probe := HiveMap.new()
	probe._ready()
	MeshBatch.watching = false
	var in_doorways: Array = probe.doorway_faults(MeshBatch.watched)
	var doorways: int = probe.doorways_tried().size()
	MeshBatch.watched.clear()
	probe.free()
	var first_find := "" if in_doorways.is_empty() else ", the first: %s in %s" % [in_doorways[0].what, in_doorways[0].door]
	expect(doorways >= 50 and in_doorways.is_empty(), "No doorway of the second mission's map has anything standing in it (%d doorways tried, %d finds%s)" % [doorways, in_doorways.size(), first_find])

## The bot of --bot-check on the map of the second mission (--bot-mode=villa): it follows
## the marker along the map's paths, shoots what it sees, uses what the mission wants
## used, and reports how long every stage took, where it could not go on and what the
## path finding cost.
func _hive_bot(game: Node3D, limit: float) -> void:
	var hive: HiveDirector = game.hive
	var map := game.cabin as HiveMap
	var player: Survivor = game.player
	var last_stage := hive.stage
	var stage_began := 0.0
	var stages: Array[String] = []
	var heals := 0
	var route := PackedVector3Array()
	var route_at := 0
	var repath := 0.0
	var waited := 0.0
	var lost: Array[String] = []
	var seen := {}
	var counted := {}
	var next_report := 20.0
	var most_alive := 0
	var next_grenade := 0.0
	# (A physics step lasts longer in game time while the bot runs faster than real time.)
	var step := Engine.time_scale / float(Engine.physics_ticks_per_second)
	while game.state == "playing" and game.elapsed < limit:
		await get_tree().physics_frame
		if hive.stage != last_stage:
			stages.append("%s:%ds" % [last_stage, int(game.elapsed - stage_began)])
			print("BOT_STAGE %s after %ds at t=%d kills=%d alive=%d" % [last_stage, int(game.elapsed - stage_began), int(game.elapsed), game.kills, game.alive_count])
			last_stage = hive.stage
			stage_began = game.elapsed
			waited = 0.0
			repath = 0.0
		if player.health < BOT_FLOOR:
			player.health = 100
			heals += 1
		if player.reserve == 0:
			player.reserve = player.max_reserve()
		most_alive = maxi(most_alive, game.alive_count)
		# --- shoot the nearest enemy in sight
		var best: Infected = null
		var best_distance := 2000.0
		var nearest_any: Infected = null
		var nearest_gap := INF
		for node in get_tree().get_nodes_in_group("infected"):
			var enemy := node as Infected
			if enemy.dead:
				continue
			var id := enemy.get_instance_id()
			if not counted.has(id):
				counted[id] = true
				seen[enemy.kind] = int(seen.get(enemy.kind, 0)) + 1
			var distance := enemy.global_position.distance_to(player.global_position)
			if distance < nearest_gap:
				nearest_gap = distance
				nearest_any = enemy
			var aim: Vector3 = enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.62, 0)
			var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, aim, 1)
			# Behind a shield that faces the bot: anybody else comes first.
			var rank := distance + (1000.0 if enemy.blocks(enemy.global_position - player.global_position) else 0.0)
			if distance < 45.0 and rank < best_distance and get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty():
				best = enemy
				best_distance = rank
		if best != null:
			var to: Vector3 = best.global_position + Vector3(0, float(best.spec.height) * 0.62, 0) - player.camera.global_position
			player.rotation.y = atan2(-to.x, -to.z)
			player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
			if best_distance < 1000.0:
				player.shoot()
			elif game.elapsed >= next_grenade:
				# Only he is left in sight: a grenade goes round his shield.
				next_grenade = game.elapsed + 3.0
				player.items.grenade = 1
				player.throw_cooldown = 0.0
				player.throw("grenade")
			best_distance = fmod(best_distance, 1000.0)
		# --- use what is to be used
		if hive.prompt() != "":
			game.interact()
		# --- where to: the marker; guards that hide are looked for
		var goal := Vector3.INF
		var marks: Array = hive.markers()
		if not marks.is_empty():
			goal = (marks[0].pos as Vector3) - Vector3(0, 1.4, 0)
		if hive.stage == "station" and hive._guards_left() > 0 and best == null:
			for guard in hive.guards:
				if is_instance_valid(guard) and not (guard as Infected).dead:
					goal = (guard as Infected).global_position
					break
		# Standing and shooting while somebody is close; otherwise on towards the goal.
		var fighting := best != null and best_distance < 9.0
		if goal != Vector3.INF and not fighting and hive.intro_left <= 0.0:
			repath -= step
			if repath <= 0.0:
				repath = 0.8
				route = map.path_between(player.global_position, goal)
				route_at = 0
			var here := player.global_position
			var budget := 5.2 * step
			while budget > 0.0 and route_at < route.size():
				var to_point := route[route_at] + Vector3(0, 0.05, 0) - here
				var gap := to_point.length()
				if gap <= budget:
					here = route[route_at] + Vector3(0, 0.05, 0)
					route_at += 1
					budget -= gap
				else:
					here += to_point / gap * budget
					budget = 0.0
			if best == null and here.distance_to(player.global_position) > 0.001:
				var ahead := here - player.global_position
				player.rotation.y = atan2(-ahead.x, -ahead.z)
			player.global_position = here
			player.velocity = Vector3.ZERO
			# No way to a goal that is not reached yet: something is wrong with the map.
			if route.is_empty() and player.global_position.distance_to(goal) > 3.0:
				waited += step
				if waited > 12.0 and lost.size() < 12:
					waited = 0.0
					lost.append("%s: no way from %s to %s" % [hive.stage, str(player.global_position.snapped(Vector3.ONE * 0.1)), str(goal.snapped(Vector3.ONE * 0.1))])
		if game.elapsed >= next_report:
			next_report += 20.0
			print("BOT t=%04d stage=%s alive=%d kills=%d hp=%d heals=%d at=%s progress=%.2f nearest=%s" % [int(game.elapsed), hive.stage, game.alive_count, game.kills, int(player.health), heals, str(player.global_position.snapped(Vector3.ONE * 0.1)), hive.progress, ("%s %.0fm" % [nearest_any.kind, nearest_gap]) if nearest_any != null else "-"])
	stages.append("%s:%ds" % [last_stage, int(game.elapsed - stage_began)])
	var squad_kills := 0
	for mate in game.team:
		squad_kills += mate.kills
	print("BOT_RESULT state=%s stage=%s t=%d kills=%d squad_kills=%d score=%d heals=%d most_alive=%d seen=%s lost=%d paths=%d path_ms_each=%.3f" % [game.state, hive.stage, int(game.elapsed), game.kills, squad_kills, game.score, heals, most_alive, str(seen), lost.size(), map.path_calls, (map.path_usec / 1000.0) / maxf(1.0, float(map.path_calls))])
	print("BOT_STAGES ", " ".join(PackedStringArray(stages)))
	var company: Array[String] = []
	for mate in game.team:
		company.append("%s:%d" % [mate.look, mate.kills])
	print("BOT_COMPANY ", " ".join(PackedStringArray(company)))
	for entry in lost:
		print("BOT_LOST ", entry)
	game.sounds.stop_all()
	Engine.time_scale = 1.0
	await wait(0.2)
	get_tree().call_deferred("quit", 0)
