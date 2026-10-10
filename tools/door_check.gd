extends SceneTree
## Finds what stands in the doorways of the map of mission two: for every door and every
## opening the map declares, the boxes and models that reach into its clear opening - a
## wainscot that runs on through it, a wall that was never cut, a cabinet set before it.
## The door's own frame, threshold and leaves do not count (see HiveCore.doorway_faults).
##   Godot --headless --path <project> -s res://tools/door_check.gd > out.txt 2>&1
## Optional user args after "--": --reach=25 (centimetres before the faces of the wall
## that still belong to the doorway), --list=400 (finds to print), --doors (also print
## every doorway that was tried). Exit code 1 if anything was found.

func _initialize() -> void:
	var reach := 0.25
	var most := 400
	var every := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reach="):
			reach = float(arg.substr(8)) / 100.0
		elif arg.begins_with("--list="):
			most = int(arg.substr(7))
		elif arg == "--doors":
			every = true
	# (A script that fails never quits by itself.)
	create_timer(240.0).timeout.connect(func() -> void: quit(2))
	MeshBatch.watching = true
	MeshBatch.watched.clear()
	var map := HiveMap.new()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	MeshBatch.watching = false
	var faults: Array = map.doorway_faults(MeshBatch.watched, reach)
	var by_door := {}
	for fault in faults:
		if not by_door.has(fault.door):
			by_door[fault.door] = []
		(by_door[fault.door] as Array).append(fault)
	print("DOORWAYS doors=", map.doors.size(), " tried=", map.doorways_tried().size(), " boxes=", MeshBatch.watched.size(), " models=", map.model_spots.size(), " faults=", faults.size(), " in=", by_door.size(), " build_ms=", map.build_times.get("all", 0))
	if every:
		for door in map.doorways_tried():
			print("  DOOR ", map.doorway_label(door), "  ", "clean" if not by_door.has(map.doorway_label(door)) else "%d" % (by_door[map.doorway_label(door)] as Array).size())
	var printed := 0
	for door in by_door:
		print("  ", door)
		for fault in by_door[door]:
			if printed >= most:
				break
			printed += 1
			var low: Vector3 = fault.low
			var high: Vector3 = fault.high
			print("      %-6s %-34s  y %.2f..%.2f  takes %.2f x %.2f x %.2f at (%.2f, %.2f)" % [fault.kind, fault.what, low.y, high.y, high.x - low.x, high.y - low.y, high.z - low.z, (low.x + high.x) * 0.5, (low.z + high.z) * 0.5])
	# (The exit code says whether anything was found.)
	quit(0 if faults.is_empty() else 1)
