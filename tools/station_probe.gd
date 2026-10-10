extends SceneTree
## Prints the plan of rooms of mission two's map as text, to find a free wall for something
## new: '#' closed to walking, '.' free, D a door, E where the infected land, C where one
## stands at a weapon cache, S a station, P a named point of the map.
##   Godot --headless --path <project> -s res://tools/station_probe.gd -- --rooms=spine,cross

func _initialize() -> void:
	var wanted: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rooms="):
			wanted = Array(arg.substr(8).split(","))
	create_timer(240.0).timeout.connect(func() -> void: quit(2))
	var map := HiveMap.new()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	for id: String in wanted:
		if not map.room_of.has(id):
			print("NO ROOM ", id)
			continue
		var room: Dictionary = map.room_of[id]
		var inner: Rect2 = room.inner
		var y := float(room.y)
		var level: int = map.level_of(Vector3(inner.get_center().x, y + 0.1, inner.get_center().y))
		print("ROOM %s inner x %.1f..%.1f z %.1f..%.1f y %.2f height %.1f level %d style %s" % [id, inner.position.x, inner.end.x, inner.position.y, inner.end.y, y, float(room.height), level, str(room.get("style", ""))])
		var grid: AStarGrid2D = map.navigation[level]
		var region: Rect2i = grid.region
		var x0 := int(floor((inner.position.x - 1.0) / CabinMap.CELL))
		var x1 := int(ceil((inner.end.x + 1.0) / CabinMap.CELL))
		var z0 := int(floor((inner.position.y - 1.0) / CabinMap.CELL))
		var z1 := int(ceil((inner.end.y + 1.0) / CabinMap.CELL))
		var marks := {}
		var notes: Array[String] = []
		for door in map.doors:
			var p: Vector3 = door.pos
			if absf(p.y - y) < 2.0 and inner.grow(1.0).has_point(Vector2(p.x, p.z)):
				marks[Vector2i(roundi(p.x / CabinMap.CELL), roundi(p.z / CabinMap.CELL))] = "D"
				notes.append("door %s-%s side %d at (%.1f, %.1f) wide %.1f %s" % [door.a, door.b, int(door.side), p.x, p.z, float(door.width), str(door.kind)])
		for entry in map.entries:
			var p: Vector3 = entry.land
			if p != Vector3.INF and absf(p.y - y) < 2.5 and inner.grow(1.0).has_point(Vector2(p.x, p.z)):
				marks[Vector2i(roundi(p.x / CabinMap.CELL), roundi(p.z / CabinMap.CELL))] = "E"
				notes.append("entry %s land (%.1f, %.1f) at (%.1f, %.1f)" % [entry.id, p.x, p.z, (entry.at as Vector3).x, (entry.at as Vector3).z])
		for site in map.caches:
			var p: Vector3 = site.stand
			if absf(p.y - y) < 2.5 and inner.grow(1.0).has_point(Vector2(p.x, p.z)):
				marks[Vector2i(roundi(p.x / CabinMap.CELL), roundi(p.z / CabinMap.CELL))] = "C"
				notes.append("cache %s stand (%.1f, %.1f)" % [str(site.get("id", "")), p.x, p.z])
		for station in map.stations:
			var p: Vector3 = station.pos
			if absf(p.y - y) < 2.5 and inner.grow(1.0).has_point(Vector2(p.x, p.z)):
				marks[Vector2i(roundi(p.x / CabinMap.CELL), roundi(p.z / CabinMap.CELL))] = "S"
				notes.append("station %s (%.1f, %.1f)" % [station.kind, p.x, p.z])
		for name: String in map.points:
			var p: Vector3 = map.points[name]
			if absf(p.y - y) < 2.5 and inner.grow(1.0).has_point(Vector2(p.x, p.z)):
				marks[Vector2i(roundi(p.x / CabinMap.CELL), roundi(p.z / CabinMap.CELL))] = "P"
				notes.append("point %s (%.1f, %.1f)" % [name, p.x, p.z])
		print("      x from %.1f, one sign = %.1f m; first row z %.1f" % [x0 * CabinMap.CELL, CabinMap.CELL, z0 * CabinMap.CELL])
		for z in range(z0, z1 + 1):
			var line := "%7.1f " % (z * CabinMap.CELL)
			for x in range(x0, x1 + 1):
				var cell := Vector2i(x, z)
				if marks.has(cell):
					line += str(marks[cell])
				elif not region.has_point(cell) or grid.is_point_solid(cell):
					line += "#"
				else:
					line += "."
			print(line)
		for note in notes:
			print("   ", note)
	quit(0)
