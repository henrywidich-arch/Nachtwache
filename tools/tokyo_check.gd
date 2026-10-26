extends SceneTree
## Builds the map of the simulation hall (mission 4) alone and checks that it can be
## played: paths from every gate and to every station, up onto the footbridge, nobody
## starting inside a wall. Headless is fine:
##   Godot --headless --path . -s res://tools/tokyo_check.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var began := Time.get_ticks_msec()
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	map.name = "Tokio"
	root.add_child(map)
	await process_frame
	var faults: Array[String] = []
	print("built in %d ms: %d spawn points, %d stations, %d floors" % [Time.get_ticks_msec() - began, map.spawn_points.size(), map.stations.size(), map.navigation.size()])
	var start: Vector3 = map.player_start
	var start_cell: Vector2i = map.nearest_cell(start, 0)
	if map.navigation[0].is_point_solid(start_cell):
		faults.append("player start lies in a closed cell")
	for i in range(map.spawn_points.size()):
		var route: PackedVector3Array = map.path_between(map.spawn_points[i], start)
		if route.size() < 2:
			faults.append("no path from spawn %d %s" % [i, map.spawn_points[i]])
	for station in map.stations:
		var route: PackedVector3Array = map.path_between(start, (station.pos as Vector3) + Vector3(0.9, 0, 0))
		if route.size() < 2:
			faults.append("no path to station %s at %s" % [station.kind, station.pos])
	var up: PackedVector3Array = map.path_between(start, map.points.bridge)
	if up.size() < 2:
		faults.append("no path onto the footbridge")
	else:
		print("path onto the bridge: %d points, top at y %.2f" % [up.size(), up[up.size() - 1].y])
	for spot in ["tower", "park", "yokocho", "station", "neo", "ring_north"]:
		if map.path_between(start, map.points[spot]).size() < 2:
			faults.append("no path to " + spot)
	# A ray down at the start must find the street.
	var space := map.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3(0, 2, 0), start + Vector3(0, -2, 0)))
	if hit.is_empty():
		faults.append("no floor under the player start")
	var lights := 0
	var labels := 0
	for node in map.find_children("*", "Light3D", true, false):
		lights += 1
	for node in map.find_children("*", "Label3D", true, false):
		labels += 1
	print("lights %d, labels %d" % [lights, labels])
	if faults.is_empty():
		print("TOKYO CHECK OK")
	else:
		for fault in faults:
			print("FAULT: ", fault)
		print("TOKYO CHECK FAILED (%d)" % faults.size())
	quit(0 if faults.is_empty() else 1)
