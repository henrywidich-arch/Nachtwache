extends SceneTree
## The infected that stand about ahead in the second mission (v0.87, Infected.loiter): one
## stands still while the survivor is far, wakes when he comes close, and wakes those of
## its kind close by; the director puts some ahead on the way. Headless:
##   Godot --headless --fixed-fps 60 --path . -s res://tools/loiter_check.gd -- --loiter

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
	game.start_run()
	for i in range(60):
		await physics_frame
	var faults: Array[String] = []
	var hive: HiveDirector = game.hive
	hive._clear_enemies()
	for mate: Teammate in game.team:
		mate.set_physics_process(false)
	var player: Survivor = game.player
	var here: Vector3 = player.global_position
	var first := hive._place("mauler", here + Vector3(0, 0, -20))
	var second := hive._place("mauler", (first.global_position if first != null else here) + Vector3(2, 0, 0))
	if first == null or second == null:
		print("LOITER FAILED: nobody could be placed")
		quit(1)
		return
	first.loiter = true
	second.loiter = true
	# (Far enough that neither sees nor hears him.)
	player.global_position = first.global_position + Vector3(0, 0, 40)
	var start := first.global_position
	for i in range(120):
		await physics_frame
	if not first.loiter or first.global_position.distance_to(start) > 0.3:
		faults.append("it moved or woke with nobody near (%.2f m, loiter %s)" % [first.global_position.distance_to(start), first.loiter])
	player.global_position = first.global_position + Vector3(0, 0.05, 3.0)
	for i in range(30):
		await physics_frame
	if first.loiter or second.loiter:
		faults.append("close by it did not wake, or its neighbour did not (%s, %s)" % [first.loiter, second.loiter])
	# The director puts a group ahead on the way.
	hive._clear_enemies()
	player.global_position = here
	hive.loiter_left = 0.0
	for i in range(30):
		await physics_frame
	if hive.stage != "terminal" or hive.loiterers.is_empty():
		faults.append("the director put nobody ahead (stage %s, %d standing)" % [hive.stage, hive.loiterers.size()])
	print("LOITER %s" % ("OK: stands, wakes near, wakes its group, %d put ahead" % hive.loiterers.size() if faults.is_empty() else "FAILED: " + "; ".join(faults)))
	quit(0 if faults.is_empty() else 1)
