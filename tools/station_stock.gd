extends SceneTree
## Takes stock of every place of mission two where one improves a weapon (W), buys
## equipment (E) or buys weapons (S): where each lies along the squad's way, how far off
## that way it stands, and how far one walks from each to the next of the same function.
## A workbench and an equipment station that stand together are one stop.
##   Godot --headless --path <project> -s res://tools/station_stock.gd > out.txt 2>&1
## The way is the one the stages lead along (HiveDirector.ORDER, their goals); the train
## ride between the station and the terminal is not walked and counts as nothing.

func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for k in range(1, path.size()):
		total += path[k].distance_to(path[k - 1])
	return total

func _initialize() -> void:
	create_timer(280.0).timeout.connect(func() -> void: quit(2))
	var map := HiveMap.new()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	for id in map.areas:
		map.unlock(str(id), true)
	for door in map.doors:
		map._shut_door(door, false, true)
	map.route_cache.clear()
	# --- the way: its points, how far along each lies, and the stage that walks there
	var stops: Array = [["landing_out", "landing"]]
	for id: String in HiveDirector.ORDER:
		var stop := str(HiveDirector.STAGES[id][2])
		if id == "ride":
			stops.append(["car_b", "ride"])
		elif stop != "" and map.points.has(stop):
			stops.append([stop, id])
	var way: Array[Vector3] = []
	var along: Array[float] = []
	var stage_of: Array[String] = []
	var walked := 0.0
	for k in range(stops.size() - 1):
		var from: Vector3 = map.points[stops[k][0]]
		var to: Vector3 = map.points[stops[k + 1][0]]
		var leg := map.path_between(from, to)
		if str(stops[k + 1][1]) == "ride" or leg.is_empty():
			continue
		var last := from
		for point in leg:
			walked += point.distance_to(last)
			last = point
			way.append(point)
			along.append(walked)
			stage_of.append(str(stops[k + 1][1]))
	print("WAY %d points, %.0f m on foot (the train ride apart)" % [way.size(), walked])
	# --- the stops: stations that stand together
	var stops_found: Array[Dictionary] = []
	for station in map.stations:
		var kind := str(station.kind)
		if kind not in ["upgrade", "gear", "shop"]:
			continue
		var pos: Vector3 = station.pos
		var joined := false
		for stop in stops_found:
			if (stop.pos as Vector3).distance_to(pos) < 6.0:
				(stop.kinds as Array).append(kind)
				(stop.looks as Array).append(str(station.get("look", "locker")))
				joined = true
		if not joined:
			var room := map.room_at(pos + Vector3(0, 0.3, 0))
			if room.is_empty() and station.has("facing"):
				room = map.room_at(pos + (station.facing as Vector3) * 1.0 + Vector3(0, 0.3, 0))
			var stand: Vector3 = station.get("stand", pos)
			if not station.has("stand"):
				stand = map.points.get({"grounds": "supply_lz", "platform": "supply_station", "guard": "supply_checkpoint", "atrium": "supply_atrium"}.get(str(room.get("id", "")), ""), pos)
			stops_found.append({"pos": pos, "stand": stand, "kinds": [kind], "looks": [str(station.get("look", "locker"))], "room": str(room.get("id", "?")), "site": str(station.get("site", "supply")), "level": map.level_of(pos + Vector3(0, 0.3, 0))})
	# Where the way passes each: the point of the way from which it is the shortest walk.
	for stop in stops_found:
		var best := INF
		var best_at := -1
		for k in range(0, way.size(), 3):
			if absf(way[k].y - (stop.stand as Vector3).y) > 3.0 or way[k].distance_to(stop.stand) > 70.0:
				continue
			var steps := map.path_between(way[k], stop.stand)
			if steps.is_empty():
				continue
			var off := _length(steps)
			if off < best - 0.5:
				best = off
				best_at = k
		stop["off"] = best
		stop["along"] = along[best_at] if best_at >= 0 else -1.0
		stop["stage"] = stage_of[best_at] if best_at >= 0 else "?"
	stops_found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.along) < float(b.along))
	# --- the table, and from each to the next of the same function
	var words := {"upgrade": "W", "gear": "E", "shop": "S+E"}
	var before := {}
	print("%-11s %-13s %-10s %-22s %7s %6s   %s" % ["site", "room", "stage", "offers", "along", "off", "from the last of the same: W / E / S (m on foot; 'ride' = the train between)"])
	for stop in stops_found:
		var offers: Array[String] = []
		for k in range((stop.kinds as Array).size()):
			offers.append("%s(%s)" % [words[stop.kinds[k]], stop.looks[k]])
		var gaps: Array[String] = []
		for function: String in ["W", "E", "S"]:
			var has := false
			for kind: String in stop.kinds:
				has = has or (function == "W" and kind == "upgrade") or (function == "E" and kind in ["gear", "shop"]) or (function == "S" and kind == "shop")
			if not has:
				gaps.append("  -  ")
				continue
			if before.has(function):
				var steps := map.path_between(before[function].stand, stop.stand)
				gaps.append("ride " if steps.is_empty() else "%4.0f " % _length(steps))
			else:
				gaps.append("first")
			before[function] = stop
		print("%-11s %-13s %-10s %-22s %7.0f %6.0f   %s" % [stop.site, stop.room, stop.stage, " ".join(PackedStringArray(offers)), float(stop.along), float(stop.off), " / ".join(PackedStringArray(gaps))])
	# The fights a stop should come before: how far back the last W and the last E lie.
	for fight: Array in [["platform", "platform"], ["cafeteria", "canteen lockdown"], ["hall_end", "hall of towers"]]:
		var spot: Vector3 = map.points[fight[0]]
		var line := "BEFORE %-17s" % str(fight[1])
		for function: String in ["W", "E"]:
			var nearest := INF
			var which := "-"
			for stop in stops_found:
				var has := false
				for kind: String in stop.kinds:
					has = has or (function == "W" and kind == "upgrade") or (function == "E" and kind in ["gear", "shop"])
				if not has:
					continue
				var steps := map.path_between(stop.stand, spot)
				if not steps.is_empty() and _length(steps) < nearest:
					nearest = _length(steps)
					which = "%s/%s" % [stop.site, stop.room]
			line += "  nearest %s: %s %.0f m" % [function, which, nearest]
		print(line)
	quit(0)
