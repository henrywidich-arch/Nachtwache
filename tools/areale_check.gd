extends SceneTree
## Checks the random part of mission two (HiveLayout, HiveAreale).
##   Godot --headless --path <project> -s res://tools/areale_check.gd -- [--seeds=200] [--build=showcase|<seed>]
## --seeds: lays out so many nights (seeds 1..n) and prints a line SEED for every one that
## has a fault (HiveLayout.faults) or comes out differently the second time, and AREALE
## with the numbers (how many areas, which arrivals, which transitions, tries).
## --build: builds the map of that night and walks it: from the arrival to the lock at the
## end with every door open, and through every area from its way in to its way out; every
## spot of an objective reached. Lines WAY for what cannot be walked, BUILT with numbers.
## The exit code is 1 if anything was found.

func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void: quit(2))
	var seeds := 0
	var build := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.trim_prefix("--seeds="))
		elif arg.begins_with("--build="):
			build = arg.trim_prefix("--build=")
	var bad := 0
	if seeds > 0:
		bad += _plans(seeds)
	if build != "":
		bad += await _build(build)
	quit(0 if bad == 0 else 1)

func _plans(count: int) -> int:
	var bad := 0
	var areas := {}
	var arrivals := {}
	var kinds := {}
	var defs := {}
	var objectives := {}
	var tries := 0
	var most_tries := 0
	var fallback := 0
	var started := Time.get_ticks_msec()
	for seed_value in range(1, count + 1):
		var night := HiveLayout.plan(seed_value)
		var again := HiveLayout.plan(seed_value)
		var faults := HiveLayout.faults(night)
		if HiveLayout.describe(night) != HiveLayout.describe(again) or str(_origins(night)) != str(_origins(again)):
			faults.append("not the same the second time")
		if not faults.is_empty():
			bad += 1
			print("SEED %d %s: %s" % [seed_value, HiveLayout.describe(night), "; ".join(PackedStringArray(faults))])
		var n: int = (night.areas as Array).size()
		areas[n] = int(areas.get(n, 0)) + 1
		arrivals[night.arrival] = int(arrivals.get(night.arrival, 0)) + 1
		tries += int(night.tries)
		most_tries = maxi(most_tries, int(night.tries))
		if int(night.tries) > HiveLayout.ATTEMPTS:
			fallback += 1
		for piece: Dictionary in night.pieces:
			if str(piece.kind) == "transition":
				kinds[piece.def] = int(kinds.get(piece.def, 0)) + 1
			elif str(piece.kind) == "area":
				defs[piece.def] = int(defs.get(piece.def, 0)) + 1
				var kind := str(piece.get("event", {}).get("kind", "-"))
				objectives[kind] = int(objectives.get(kind, 0)) + 1
	print("AREALE seeds=%d bad=%d areas=%s arrivals=%s transitions=%s pool=%s objectives=%s tries_avg=%.2f tries_most=%d fallback=%d ms=%d" % [count, bad, str(areas), str(arrivals), str(kinds), str(defs), str(objectives), float(tries) / count, most_tries, fallback, Time.get_ticks_msec() - started])
	return bad

func _origins(night: Dictionary) -> Array:
	var out: Array = []
	for piece: Dictionary in night.pieces:
		out.append([piece.def, (piece.origin as Vector3).snapped(Vector3.ONE * 0.01), piece.get("event", {}).get("kind", "")])
	return out

func _build(what: String) -> int:
	var night := HiveLayout.showcase() if what == "showcase" else HiveLayout.plan(int(what))
	var map := HiveMap.new()
	map.night = night
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	print("BUILT %s rooms=%d doors=%d floors=%d entries=%d caches=%d ms=%s" % [HiveLayout.describe(night), map.rooms.size(), map.doors.size(), map.floors.size(), map.entries.size(), map.caches.size(), str(map.build_times.get("areale", -1))])
	for id in map.areas:
		map.unlock(str(id), true)
	for door in map.doors:
		if str(door.kind) == "script":
			map.set_door(str(door.name), true, true)
	var bad := 0
	for piece: Dictionary in night.pieces:
		var p_info := HiveLayout.info(str(piece.def))
		var points: Dictionary = piece.points
		# Through the piece: from where one comes in to where one goes out.
		var from: Vector3 = map.points.get("%s_in" % piece.id, Vector3.INF)
		var to: Vector3 = map.points.get("%s_out" % piece.id, Vector3.INF)
		if str(piece.kind) != "transition":
			if not (piece["in"] as Dictionary).is_empty():
				from = AreaKit.port_inside(piece.origin, piece.size, piece["in"])
			if not (piece.out as Dictionary).is_empty():
				to = AreaKit.port_inside(piece.origin, piece.size, piece.out)
		var legs: Array = []
		if from != Vector3.INF and to != Vector3.INF:
			legs.append(["through", from, to])
		if from == Vector3.INF:
			from = to
		# Every spot of its objective, reached from where one comes in.
		var event: Dictionary = piece.get("event", {})
		var spots: Dictionary = p_info.get("spots", {})
		for key in ["goal"]:
			if spots.has(key):
				legs.append([key, from, piece.origin + (spots[key] as Vector3)])
		for index: int in event.get("switches", []):
			legs.append(["switch %d" % index, from, piece.origin + (spots.switches[index] as Vector3)])
		for index: int in event.get("items", []):
			legs.append(["item %d" % index, from, piece.origin + (spots.items[index] as Vector3)])
		for post: Array in p_info.get("posts", []):
			legs.append(["post %s" % str(post[0]), from, piece.origin + (post[1] as Vector3)])
		for leg: Array in legs:
			if leg[1] == Vector3.INF:
				continue
			var route: PackedVector3Array = map.path_between(leg[1], leg[2])
			if route.is_empty() or route[route.size() - 1].distance_to(leg[2]) > 2.0:
				bad += 1
				print("WAY %s %s %s: from %s to %s%s" % [piece.id, piece.def, str(leg[0]), str((leg[1] as Vector3).snapped(Vector3.ONE * 0.1)), str((leg[2] as Vector3).snapped(Vector3.ONE * 0.1)), " (none)" if route.is_empty() else " (ends %.1f m off)" % route[route.size() - 1].distance_to(leg[2])])
	# The whole way of each chain: from the car of its arrival to its lock.
	for chain in [0, 1]:
		var members: Array = (night.pieces as Array).filter(func(piece: Dictionary) -> bool: return int(piece.get("chain", 0)) == chain)
		if members.is_empty():
			continue
		var first: Vector3 = map.points.get("%s_in" % members[0].id, Vector3.INF)
		var last: Vector3 = map.points.get("%s_mid" % members[members.size() - 1].id, Vector3.INF)
		var route: PackedVector3Array = map.path_between(first, last)
		var long := map._length(route)
		if route.is_empty() or route[route.size() - 1].distance_to(last) > 2.0:
			bad += 1
			print("WAY chain %d: no way from the arrival %s to the lock %s" % [chain, str(first.snapped(Vector3.ONE * 0.1)), str(last.snapped(Vector3.ONE * 0.1))])
		else:
			print("CHAIN %d walkable, %.0f m" % [chain, long])
	if "--probe" in OS.get_cmdline_user_args():
		for piece: Dictionary in night.pieces:
			if str(piece.def) != "haifischlabor":
				continue
			var o: Vector3 = piece.origin
			var level := map.level_of(o + Vector3(27, 0.3, 26))
			var grid: AStarGrid2D = map.navigation[level]
			for z in range(18, 34):
				var row := ""
				for x in range(0, 40):
					var cell := Vector2i(roundi((o.x + x) / 0.5), roundi((o.z + z) / 0.5))
					row += "?" if not grid.is_in_boundsv(cell) else ("#" if grid.is_point_solid(cell) else ".")
				print("ROW %02d %s" % [z, row])
	print("BUILT_RESULT faults=%d" % bad)
	return bad
