extends SceneTree
## The simulation hall inside the second mission's map: builds HiveMap for a few nights
## (the classic one and random ones) and checks that the hall is reached on foot from the
## terminal, that every station and place in it can be walked to, and that no floor of the
## random part lies over it. Headless is fine:
##   Godot --headless --path . -s res://tools/tokyo_hive_check.gd [-- --nights=classic,6,11]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nights: Array = ["classic", "6", "11", "all"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nights="):
			nights = Array(arg.trim_prefix("--nights=").split(","))
	var faults: Array[String] = []
	# How often the seeds give a night the hall (HiveLayout.TOKYO_CHANCE).
	var with_hall := 0
	for s in range(1, 1001):
		with_hall += 1 if HiveLayout.plan(s).get("tokyo", false) else 0
	print("seeds 1..1000: %d nights with the hall" % with_hall)
	if with_hall < 300 or with_hall > 500:
		faults.append("%d of 1000 nights have the hall" % with_hall)
	# A night without it builds nothing of it, and the terminal's east wall is whole.
	var began_plain := Time.get_ticks_msec()
	var plain := HiveMap.new()
	plain.night = HiveLayout.with_tokyo(HiveLayout.classic(), false)
	root.add_child(plain)
	await process_frame
	print("night classic without the hall: built in %d ms, %d floors" % [Time.get_ticks_msec() - began_plain, plain.floors.size()])
	# (Five floors of the map, and two of the reactor hall at the end: its level and its roof, BossArena.)
	if plain.tokyo != null or plain.room_of.has("tokyo_gang") or plain.room_of.has("tk_streets") or plain.zones.has(TokyoHall.ZONE) or plain.floors.size() != 7:
		faults.append("a night without the hall has some of it")
	plain.queue_free()
	await process_frame
	for which in nights:
		var night: Dictionary = HiveLayout.classic()
		if which == "all":
			night = HiveLayout.every_seam()
		elif str(which).is_valid_int():
			night = HiveLayout.plan(int(which))
		night = HiveLayout.with_tokyo(night, true)
		var began := Time.get_ticks_msec()
		var map := HiveMap.new()
		map.night = night
		root.add_child(map)
		await process_frame
		var took := Time.get_ticks_msec() - began
		var prefix := "night %s: " % which
		if map.tokyo == null:
			faults.append(prefix + "no hall")
			continue
		print("%sbuilt in %d ms (hall %s), %d floors, deep grid %s" % [prefix, took, map.tokyo.origin, map.floors.size(), (map.navigation[map.deep] as AStarGrid2D).region.size])
		var terminal: Vector3 = map.points.terminal
		for key in ["tokyo_start", "tokyo_crossing", "tokyo_tower", "tokyo_park", "tokyo_yokocho", "tokyo_bridge", "tokyo_station", "tokyo_ring_north", "tokyo_ring_south"]:
			var route: PackedVector3Array = map.path_between(terminal, map.points[key])
			if route.size() < 2:
				faults.append(prefix + "no path from the terminal to " + key)
		for station in map.stations:
			var at: Vector3 = station.pos
			if not TokyoHall.plan_of(map.tokyo.origin).has_point(Vector2(at.x, at.z)):
				continue
			var route: PackedVector3Array = map.path_between(map.points.tokyo_start, at + Vector3(0.9, 0, 0))
			if route.size() < 2:
				route = map.path_between(map.points.tokyo_start, at + Vector3(-0.9, 0, 0))
			if route.size() < 2:
				faults.append(prefix + "no path to the %s at %s" % [station.kind, at])
		# Nothing else at the hall's height may lie over it.
		var plan := TokyoHall.plan_of(map.tokyo.origin)
		for index in range(map.floors.size()):
			# (The facility's galleries, 4 m up, end over the hall's west wall: nothing to walk there.)
			if index == map.deep or index == map.tokyo_deck or index == map.deck:
				continue
			var entry: Dictionary = map.floors[index]
			if absf(float(entry.y) - map.tokyo.origin.y) < 6.0 and (entry.bounds as Rect2).intersects(plan):
				faults.append(prefix + "floor %s lies over the hall" % entry.id)
		var length := 0.0
		var way: PackedVector3Array = map.path_between(terminal, map.points.tokyo_crossing)
		for i in range(way.size() - 1):
			length += way[i].distance_to(way[i + 1])
		print("%sway from the terminal to the crossing: %.0f m" % [prefix, length])
		map.queue_free()
		await process_frame
	if faults.is_empty():
		print("TOKYO HIVE CHECK OK")
	else:
		for fault in faults:
			print("FAULT: ", fault)
		print("TOKYO HIVE CHECK FAILED (%d)" % faults.size())
	quit(0 if faults.is_empty() else 1)
