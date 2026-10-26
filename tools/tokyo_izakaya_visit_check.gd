extends SceneTree
## The test room's jump before the TOKYO RAMEN IZAKAYA (Sandbox.visit "tokyo_izakaya"): the map of the
## second mission is built with the hall, the survivor stands at the crossing; back on the
## farm, a visit of another area is built without it again.
##   Godot --headless --path . -s res://tools/tokyo_izakaya_visit_check.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.start_run(true)
	await process_frame
	game.sandbox.visit(Sandbox.TOKYO_IZAKAYA)
	for i in range(20):
		await process_frame
	var faults: Array[String] = []
	var map := game.cabin as HiveMap
	if map == null or not is_instance_valid(map.tokyo):
		faults.append("the visit has no hall")
	elif game.player.global_position.distance_to(map.points.tokyo_izakaya) > 2.0:
		faults.append("the survivor stands at %s, not before the izakaya" % game.player.global_position)
	else:
		print("visit: at %s in zone %s" % [game.player.global_position, map.here_zone])
	game.sandbox.visit(HiveLayout.POOL[0])
	for i in range(20):
		await process_frame
	map = game.cabin as HiveMap
	if map != null and is_instance_valid(map.tokyo):
		faults.append("a visit of %s still has the hall" % HiveLayout.POOL[0])
	print("TOKYO VISIT %s" % ("OK" if faults.is_empty() else "FAILED: " + "; ".join(faults)))
	quit(0 if faults.is_empty() else 1)
