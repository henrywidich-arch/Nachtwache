extends SceneTree
## The simulation hall's side job (TokyoTasks) in a real night of the second mission with
## the hall: it is told on entering the hall, three terminals are started with [E] and run
## while the survivor stays by them (and stop while he does not), then the data core comes
## up under the control room and is taken for the reward; the list and the map show it.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/tokyo_tasks_check.gd

var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.profile.mission = 2
	game.hive.resume_at = "terminal"
	game.hive.tokyo_wanted = 1
	game.start_run()
	for i in range(60):
		await physics_frame
	var faults: Array[String] = []
	var tasks: TokyoTasks = game.hive.tokyo_tasks
	if tasks == null or tasks.terminals.size() != 3 or str(tasks.core.state) != "locked":
		print("TOKYO TASKS FAILED: no objectives in a night with the hall")
		quit(1)
		return
	# (v0.86) The hall is the way on: the control room stays locked and the marker leads to it.
	var hive: HiveDirector = game.hive
	if hive.stage == "terminal" and (hive.use_key == "control" or hive.marker.distance_to(hive._point("tokyo_lock")) > 0.5):
		faults.append("the control room was open before the hall was done (key %s)" % hive.use_key)
	for mate: Teammate in game.team:
		mate.set_physics_process(false)
		mate.set_process(false)
	var player: Survivor = game.player
	# Into the hall: the job is told.
	player.global_position = game.cabin.points.tokyo_start + Vector3(0, 0.05, 0)
	for i in range(10):
		await physics_frame
	if not tasks.told or tasks.summary().is_empty() or tasks.markers().size() != 3:
		faults.append("not told on entering the hall (told %s, %d lines, %d marks)" % [tasks.told, tasks.summary().size(), tasks.markers().size()])
	var credits: int = game.credits
	for index in range(3):
		var t: Dictionary = tasks.terminals[index]
		player.global_position = (t.at as Vector3) + Vector3(0.0, 0.05, 1.2)
		await physics_frame
		var asked := tasks.prompt()
		var started: bool = game.hive.use()
		if not started or str(t.state) != "run" or not asked.begins_with("[E]"):
			faults.append("terminal %s did not start (prompt '%s', state %s)" % [t.id, asked, t.state])
			continue
		# Away from it, it stops; back by it, it runs on until it is done.
		player.global_position = (t.at as Vector3) + Vector3(0, 0.05, 14.0)
		var held: float = t.progress
		for i in range(60):
			await physics_frame
		if float(t.progress) > held + 0.01:
			faults.append("terminal %s ran on with nobody by it" % t.id)
		player.global_position = (t.at as Vector3) + Vector3(0.0, 0.05, 1.2)
		var frames := 0
		while str(t.state) != "done" and frames < int(TokyoTasks.HACK_SECONDS * 60.0) + 120:
			await physics_frame
			frames += 1
			player.health = 100.0
			if player.down:
				player.get_up()
			for enemy in game.enemies.get_children():
				enemy.queue_free()
		if str(t.state) != "done":
			faults.append("terminal %s never finished (%.0f %%)" % [t.id, float(t.progress) * 100.0])
	if str(tasks.core.state) != "open":
		faults.append("the core did not come up (%s)" % tasks.core.state)
	player.global_position = (tasks.core.at as Vector3) + Vector3(0, 0.05, -1.4)
	await physics_frame
	var taken: bool = game.hive.use()
	var gained: int = game.credits - credits
	if not taken or str(tasks.core.state) != "taken" or gained < TokyoTasks.REWARD + 3 * TokyoTasks.STEP_REWARD:
		faults.append("the core was not taken for its reward (taken %s, state %s, +%d)" % [taken, tasks.core.state, gained])
	for i in range(5):
		await physics_frame
	if hive.stage == "terminal" and hive.use_key != "control":
		faults.append("the control room did not open once the core was taken (key %s)" % hive.use_key)
	var state := tasks.export()
	if str(state.core) != "taken" or (state.terms as Array).size() != 3:
		faults.append("the snapshot for the partner is wrong: %s" % state)
	print("TOKYO TASKS %s" % ("OK: 3 terminals, the core, +%d credits" % gained if faults.is_empty() else "FAILED: " + "; ".join(faults)))
	quit(0 if faults.is_empty() else 1)
