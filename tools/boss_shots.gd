extends SceneTree
## The end boss of mission two, as the test room shows it (F1 > MISSION 2 · AREALE >
## ENDBOSS-RAUM): the anteroom, the intro, the fight with every trap, the boss's attacks,
## the victory and the outro - a picture of each. Prints what it finds wrong. Run windowed
## (tools/godot_bg.ps1 -Render):
##   Godot --path . --resolution 1600x900 -s res://tools/boss_shots.gd -- --out=<folder>

var game: Node3D
var folder := "user://boss_shots"
var problems: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.profile.mission = 2
	game.start_run(true)
	await _frames(20)
	game.sandbox.visit(Sandbox.BOSS_VISIT)
	await _frames(90)
	var map := game.cabin as HiveMap
	if map == null or map.boss_arena == null:
		print("PROBLEM: no reactor hall on the map")
		quit(1)
		return
	var arena: BossArena = map.boss_arena
	var fight: BossFight = game.hive.boss
	print("visit: player at %s, fight state %s" % [game.player.global_position, fight.state])
	game.sandbox.set_daylight(false)
	await _frames(10)
	await _shot("01_vorraum", 0.0, -4.0)
	# Down the corridor to the gate.
	game.player.global_position = (map.points.boss_door as Vector3) + Vector3(0, 0.1, 4.6)
	game.player.rotation.y = 0.0
	await _frames(30)
	await _shot("02_gang", 0.0, 2.0)
	game.player.global_position = (map.points.boss_door as Vector3) + Vector3(0, 0.1, 0.5)
	await _frames(10)
	_check(fight.state == "intro", "standing at the gate starts the intro (state %s)" % fight.state)
	for mark: Array in [[2.0, "03_intro_halle"], [6.5, "04_intro_nadja"], [10.0, "05_intro_tank"], [11.6, "06_intro_ausbruch"], [14.0, "07_intro_bruellen"]]:
		while fight.scene_t < float(mark[0]) and fight.state == "intro":
			await process_frame
		await _grab(str(mark[1]))
	while fight.state == "intro":
		await process_frame
	await _frames(20)
	var boss: BossMutant = fight.boss
	_check(boss != null and boss.awake and not boss.dead, "the boss is awake after the intro")
	_check(game.boss == boss, "its bar is shown")
	_check(not map.door_open("boss_gate"), "the gate is shut behind the squad")
	# The fight: look at it from a little way off.
	await _face(boss, 12.0)
	await _shot("08_kampf", -1.0, 6.0)
	# Its attacks, one after the other.
	for attack: Array in [["rush", 0.6, "09_rush_ansage"], ["stomp", 0.75, "10_stampfer"], ["throw", 1.6, "11_wurf_saeure"], ["laser", 1.3, "12_laser"], ["punch", 0.5, "13_schlag"], ["roar", 1.4, "14_bruellen_zombies"]]:
		await _face(boss, 11.0 if attack[0] != "punch" else 5.5)
		boss.act = ""
		boss.stunned = 0.0
		boss._start(str(attack[0]))
		await create_timer(float(attack[1])).timeout
		await _grab(str(attack[2]))
		while boss.act != "":
			await process_frame
		await _frames(10)
	# The traps of the hall.
	for node in game.enemies.get_children():
		if node is Infected and not node is BossMutant and not (node as Infected).dead:
			(node as Infected).receive_hit(99999.0, Vector3.UP)
	boss.set_physics_process(false)
	fight.on_trap(["sweep", "high", true, false, 0.0])
	game.player.global_position = arena.origin + Vector3(6.0, 0.1, 8.0)
	game.player.rotation.y = deg_to_rad(60.0)
	await create_timer(1.2).timeout
	await _shot("15_lasergitter_hoch", -1.0, -6.0)
	fight.on_trap(["sweep", "gap", false, false, 4.0])
	await create_timer(1.6).timeout
	await _shot("16_lasergitter_luecke", 90.0, -4.0)
	fight.on_trap(["hatch", range(arena.hatch_count())])
	game.player.global_position = arena.origin + Vector3(0.0, 0.1, 9.0)
	await create_timer(1.0).timeout
	await _shot("17_luken_warnung", 180.0, -26.0)
	await create_timer(1.8).timeout
	await _shot("18_luken_lava", 180.0, -26.0)
	_check(arena.hatches_busy(), "the hatches open")
	fight.on_trap(["gas", 1])
	game.player.global_position = arena.origin + Vector3(0.0, 0.1, 0.0)
	await create_timer(4.0).timeout
	game.player.rotation.y = deg_to_rad(-135.0)
	await _shot("19_giftgas", -1.0, -6.0)
	var in_gas := arena.origin + Vector3(cos(arena.nozzles[1].angle) * 13.0, 0.5, sin(arena.nozzles[1].angle) * 13.0)
	_check(game.toxic_at(in_gas), "the gas poisons its quarter")
	_check(not game.toxic_at(arena.origin + Vector3(0, 0.5, 0)), "the middle stays clear")
	# Phases and the end.
	boss.set_physics_process(true)
	boss.receive_hit(boss.max_health * 0.4, Vector3.FORWARD)
	await _frames(30)
	_check(boss.phase == 2, "phase 2 at 66 %% (phase %d)" % boss.phase)
	boss.receive_hit(boss.max_health * 0.3, Vector3.FORWARD)
	await _frames(30)
	_check(boss.phase == 3, "phase 3 at 33 %% (phase %d)" % boss.phase)
	await _face(boss, 10.0)
	await _shot("20_phase3_wut", -1.0, 6.0)
	boss.receive_hit(boss.max_health * 2.0, Vector3.FORWARD)
	await create_timer(1.5).timeout
	await _shot("21_tod", -1.0, -6.0)
	_check(fight.state == "won", "its death ends the fight (state %s)" % fight.state)
	while fight.state == "won":
		await process_frame
	for mark: Array in [[1.5, "22_outro_leiche"], [4.6, "23_outro_tuer"], [7.0, "24_outro_nadja_gefasst"], [12.0, "25_outro_abgefuehrt"], [17.5, "26_outro_dach_heli"], [22.0, "27_outro_abflug"]]:
		while fight.scene_t < float(mark[0]) and fight.state == "outro":
			await process_frame
		await _grab(str(mark[1]))
	while fight.state == "outro":
		await process_frame
	_check(fight.state == "done", "the outro ends")
	print("problems: %d" % problems.size())
	for p in problems:
		print("PROBLEM: ", p)
	quit(0 if problems.is_empty() else 1)

func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		problems.append(what)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

## The player stands `gap` metres from the boss and looks at it.
func _face(target: Node3D, gap: float) -> void:
	var arena: BossArena = (game.cabin as HiveMap).boss_arena
	var from := target.global_position - arena.origin
	var way := Vector3(-from.x, 0, -from.z).normalized() if Vector2(from.x, from.z).length() > 2.0 else Vector3(0, 0, 1)
	var stand := target.global_position + way * gap
	game.player.global_position = Vector3(stand.x, arena.origin.y + 0.1, stand.z)
	var to := target.global_position - stand
	game.player.rotation.y = atan2(-to.x, -to.z)
	await _frames(4)

func _shot(file: String, yaw_degrees: float, pitch_degrees: float) -> void:
	if yaw_degrees > -0.5:
		game.player.rotation.y = deg_to_rad(yaw_degrees)
	game.player.camera.rotation.x = deg_to_rad(pitch_degrees)
	await _frames(12)
	await _grab(file)

func _grab(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(file + ".png"))
	print("saved ", file)
