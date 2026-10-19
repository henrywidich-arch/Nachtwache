extends Node
## Pictures of bodies thrown by what killed them: a pistol, the sniper rifle, the .50, a
## 40 mm grenade and the sledgehammer, on the farm's yard and in a hall of the second
## mission. Each kill is taken from the side a moment after the blow, mid-flight and where
## the body lies; the distance each body was thrown is printed (RAGDOLL lines). Last a
## dozen die at once, to see the cap on loose bodies at work.
## Started by game.gd with --ragdoll-check --capture-dir=<folder> [--ragdoll-only=farm|hive].
var game: Node3D

const KILLS := ["pistol", "rifle", "sniper", "fifty", "launcher", "hammer", "knife"]

func run(owner_game: Node3D, folder: String) -> void:
	game = owner_game
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ragdoll-only="):
			only = arg.trim_prefix("--ragdoll-only=")
	await _wait(1.0)
	if only in ["", "farm"]:
		game.profile.mission = 1
		game.start_run()
		_quiet()
		game.cabin.set_daylight(true)
		await _wait(0.5)
		var yard: Vector3 = game.cabin.points.front_door_out + Vector3(0, 0, 5.0)
		for weapon in KILLS:
			await _kill(folder, "farm", weapon, yard, Vector3(1, 0, 0))
		await _crowd(folder, "farm", yard, Vector3(1, 0, 0))
	if only in ["", "hive"]:
		game.profile.mission = 2
		game.intro_skipped = true
		game.hive.seed_wanted = 4242
		game.start_run()
		_quiet()
		game.hive.set_process(false)
		await _wait(1.5)
		for view in game.hive_map.tour():
			if str(view[0]) == "06_hall_in":
				var from: Vector3 = view[1]
				var ahead: Vector3 = (view[2] as Vector3) - from
				ahead.y = 0.0
				from = game.fx.floor_below(from + Vector3.UP * 0.5)
				for weapon in KILLS:
					await _kill(folder, "m2", weapon, from, ahead.normalized())
				await _crowd(folder, "m2", from, ahead.normalized())
	print("RAGDOLL_COMPLETE")
	game.get_tree().quit()

func _wait(seconds: float) -> Signal:
	return game.get_tree().create_timer(seconds).timeout

## Nobody attacks, nobody else is in the picture, nothing is said over it.
func _quiet() -> void:
	game.set_process(false)
	game.preparation_left = 9999.0
	for node in game.enemies.get_children():
		node.queue_free()
	game.alive_count = 0
	for mate in game.team:
		mate.hide()
		mate.set_physics_process(false)
	game.hud.banner_left = 0
	game.hud.radio_left = 0
	if game.hud.get("play_ui") != null:
		game.hud.play_ui.hide()

## One infected `ahead` of a survivor at `from` killed by `weapon` as the game does it.
func _kill(folder: String, place: String, weapon: String, from: Vector3, ahead: Vector3) -> void:
	game.fx.clear()
	var shooter: Vector3 = from - ahead * 4.0
	game._place_player(shooter + Vector3(0, 0.05, 0), rad_to_deg(atan2(-ahead.x, -ahead.z)), -6.0)
	game.player.flashlight.visible = place == "m2"
	var enemy: Infected = game.spawn_enemy("mauler")
	enemy.global_position = from + Vector3(0, 0.05, 0)
	enemy.look_at(shooter, Vector3.UP, true)
	enemy.set_physics_process(true)
	enemy.alert = false
	await _wait(0.5)
	var start := enemy.global_position
	var lamp_side := ahead.cross(Vector3.UP).normalized()
	var reach := 4.0 if weapon == "launcher" else 1.5
	var eye := from + ahead * reach + lamp_side * (5.5 if weapon == "launcher" else 3.6) + Vector3(0, 1.3, 0)
	var aim := from + ahead * reach + Vector3(0, 0.6, 0)
	var head := weapon in ["sniper", "fifty"]
	match weapon:
		"launcher":
			game.explode(enemy.global_position - ahead * 0.9 + Vector3(0, 0.15, 0), 6.5, 0.0, 280.0, "blast")
		"hammer", "knife":
			var blade: Dictionary = Survivor.MELEE_WEAPONS[weapon]
			enemy.set_meta("melee_blow", [float(Survivor.MELEE_MOTION[weapon].weight), bool(Survivor.MELEE_MOTION[weapon].edged)])
			enemy.shove(ahead, float(blade.push), float(blade.daze), 9999.0)
			enemy.remove_meta("melee_blow")
		_:
			var data: Dictionary = Survivor.WEAPONS[weapon]
			var throw := Infected.throw_for(float(data.damage))
			enemy.hit_hard(9999.0, (ahead + Vector3(0, -0.05, 0)).normalized(), head, null, throw)
	var loose: bool = enemy.model.loose_body
	await _wait(0.15)
	await game._capture_from(folder, "ragdoll_%s_%s_1_treffer.png" % [place, weapon], eye, aim)
	await _wait(0.35)
	await game._capture_from(folder, "ragdoll_%s_%s_2_flug.png" % [place, weapon], eye, aim)
	await _wait(2.5)
	await game._capture_from(folder, "ragdoll_%s_%s_3_liegt.png" % [place, weapon], eye, aim)
	if not is_instance_valid(enemy):
		print("RAGDOLL %s %-8s gone before it could be measured" % [place, weapon])
		return
	var model: InfectedVisual = enemy.model
	var lowest := INF
	for bone in range(model.skeleton.get_bone_count()):
		lowest = minf(lowest, (model.skeleton.global_transform * model.skeleton.get_bone_global_pose(bone).origin).y)
	var hips: Vector3 = model.skeleton.global_transform * model.skeleton.get_bone_global_pose(int(model.rig.pelvis.index)).origin
	var ground: Vector3 = game.fx.floor_below(hips + Vector3.UP * 0.5)
	var flat := Vector3(hips.x - start.x, 0, hips.z - start.z)
	await game._capture_from(folder, "ragdoll_%s_%s_4_nah.png" % [place, weapon], hips + lamp_side * 1.6 - ahead * 0.6 + Vector3(0, 1.5, 0), hips, 55.0)
	print("RAGDOLL %s %-8s loose=%s thrown=%.2f m along=%.2f hips=%.2f above ground, lowest bone %.2f, parts left %d, cut %s" % [place, weapon, loose, flat.length(), flat.dot(ahead), hips.y - ground.y, lowest - ground.y, model.limbs.size(), str(model.cut_bones)])
	enemy.queue_free()
	await _wait(0.2)

## A dozen at once: as many fall loose as may, the rest by their clips, and nothing stalls.
func _crowd(folder: String, place: String, from: Vector3, ahead: Vector3) -> void:
	game.fx.clear()
	var shooter: Vector3 = from - ahead * 5.0
	game._place_player(shooter + Vector3(0, 0.05, 0), rad_to_deg(atan2(-ahead.x, -ahead.z)), -10.0)
	var side := ahead.cross(Vector3.UP).normalized()
	var crowd: Array = []
	for i in range(12):
		var enemy: Infected = game.spawn_enemy("mauler")
		enemy.global_position = from + side * (float(i % 4) - 1.5) * 0.9 + ahead * float(i / 4) * 0.9 + Vector3(0, 0.05, 0)
		enemy.look_at(shooter, Vector3.UP, true)
		enemy.alert = false
		crowd.append(enemy)
	await _wait(0.5)
	var ticks := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	game.explode(from + ahead * 0.6 + Vector3(0, 0.15, 0), 6.5, 0.0, 280.0, "blast")
	var loose := 0
	for enemy in crowd:
		loose += 1 if (enemy as Infected).model.loose_body else 0
	await _wait(0.3)
	var busy := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	await game._capture(folder, "ragdoll_%s_haufen_1.png" % place)
	await _wait(3.0)
	await game._capture(folder, "ragdoll_%s_haufen_2.png" % place)
	print("RAGDOLL %s crowd: %d of %d loose, physics step %.1f ms before, %.1f ms after" % [place, loose, crowd.size(), ticks * 1000.0, busy * 1000.0])
	for enemy in crowd:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await _wait(0.2)
