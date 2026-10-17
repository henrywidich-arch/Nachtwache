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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--describe="):
			for seed_value in range(1, int(arg.trim_prefix("--describe=")) + 1):
				var night := HiveLayout.plan(seed_value)
				var events: Array[String] = []
				for piece: Dictionary in night.pieces:
					if str(piece.kind) == "area":
						events.append("%s:%s" % [piece.def, piece.event.kind])
				print("NIGHT %s | %s" % [HiveLayout.describe(night), " ".join(PackedStringArray(events))])
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
	var seams := {}
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
		for chain: Dictionary in night.get("chains", []):
			seams[chain.seam] = int(seams.get(chain.seam, 0)) + 1
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
	print("AREALE seeds=%d bad=%d areas=%s arrivals=%s seams=%s transitions=%s pool=%s objectives=%s tries_avg=%.2f tries_most=%d fallback=%d ms=%d" % [count, bad, str(areas), str(arrivals), str(seams), str(kinds), str(defs), str(objectives), float(tries) / count, most_tries, fallback, Time.get_ticks_msec() - started])
	return bad

func _origins(night: Dictionary) -> Array:
	var out: Array = []
	for piece: Dictionary in night.pieces:
		out.append([piece.def, (piece.origin as Vector3).snapped(Vector3.ONE * 0.01), piece.get("event", {}).get("kind", "")])
	return out

func _build(what: String) -> int:
	var night := HiveLayout.showcase() if what == "showcase" else (HiveLayout.every_seam() if what == "all" else HiveLayout.plan(int(what)))
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
	# The way from piece to piece: from where one leaves a piece (or the car of the arrival)
	# through the transition to where one comes into the next (the path finder does not
	# go down a level and up again to come back to its own, so the way is walked as the
	# squad walks it, one stretch after the other).
	var most := 0
	for piece: Dictionary in night.pieces:
		most = maxi(most, int(piece.get("chain", 0)))
	for chain in range(most + 1):
		var members: Array = (night.pieces as Array).filter(func(piece: Dictionary) -> bool: return int(piece.get("chain", 0)) == chain and str(piece.kind) != "transition")
		var total := 0.0
		for k in range(members.size() - 1):
			var from: Vector3 = map.points.get("%s_leave" % members[k].id, Vector3.INF)
			var to: Vector3 = map.points.get("%s_entry" % members[k + 1].id, Vector3.INF)
			var route: PackedVector3Array = map.path_between(from, to)
			if route.is_empty() or route[route.size() - 1].distance_to(to) > 2.0:
				bad += 1
				print("WAY chain %d: no way from %s %s to %s %s" % [chain, members[k].def, str(from.snapped(Vector3.ONE * 0.1)), members[k + 1].def, str(to.snapped(Vector3.ONE * 0.1))])
			else:
				total += map._length(route)
		print("CHAIN %d: %d stretches between pieces, %.0f m" % [chain, members.size() - 1, total])
	# --long: the whole way of a chain in one ask of the path finder, from its first piece to
	# its last and to every place of an objective - what a squad member or a hunter that
	# follows from far behind asks for (LONG lines; not counted as faults).
	if "--long" in OS.get_cmdline_user_args():
		for chain in range(most + 1):
			var members: Array = (night.pieces as Array).filter(func(piece: Dictionary) -> bool: return int(piece.get("chain", 0)) == chain)
			var start: Vector3 = map.points.get("%s_mid" % members[0].id, map.points.get("%s_car" % members[0].id, Vector3.INF))
			var asked := 0
			var found := 0
			var missed: Array[String] = []
			for piece: Dictionary in members:
				var targets: Array = []
				if map.points.has("%s_entry" % piece.id):
					targets.append(map.points["%s_entry" % piece.id])
				var spots: Dictionary = HiveLayout.info(str(piece.def)).get("spots", {})
				if spots.has("goal"):
					targets.append(HiveAreaRun.free_spot(map, piece.origin + (spots.goal as Vector3)))
				for target: Vector3 in targets:
					asked += 1
					var route: PackedVector3Array = map.path_between(start, target)
					if not route.is_empty() and route[route.size() - 1].distance_to(target) < 2.0:
						found += 1
					else:
						missed.append("%s %s (%.0f m below the start)" % [piece.id, piece.def, start.y - target.y])
			print("LONG chain %d: %d of %d found from its start%s" % [chain, found, asked, "" if missed.is_empty() else " - not: " + ", ".join(PackedStringArray(missed))])
	if "--stairs" in OS.get_cmdline_user_args():
		for stair in map.stairs:
			var foot: Vector3 = stair.foot
			if foot.x < 150.0:
				continue
			var low_grid: AStarGrid2D = map.navigation[int(stair.low)]
			var high_grid: AStarGrid2D = map.navigation[int(stair.high)]
			print("STAIR foot=%s head=%s low=%d(%s y=%.1f) high=%d(%s y=%.1f) bottom_free=%s top_free=%s" % [str(foot.snapped(Vector3.ONE * 0.1)), str((stair.head as Vector3).snapped(Vector3.ONE * 0.1)), int(stair.low), map.floors[int(stair.low)].id, float(map.floors[int(stair.low)].y), int(stair.high), map.floors[int(stair.high)].id, float(map.floors[int(stair.high)].y), str(low_grid.is_in_boundsv(stair.bottom) and not low_grid.is_point_solid(stair.bottom)), str(high_grid.is_in_boundsv(stair.top) and not high_grid.is_point_solid(stair.top))])
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
	# The real lifts: from the room of the old route into the cabin.
	for id: String in night.get("lifts", []):
		var spec: Dictionary = HiveLayout.LIFTS[id]
		var cabin: Vector3 = map.points.get("lift_%s_mid" % id, Vector3.INF)
		var old: Dictionary = map.room_of[str(spec.room)]
		var door := Vector3(spec.rect.get_center().x, HiveMap.UNDER, spec.rect.get_center().y) - Vector3(HiveCore.OUT[int(spec.door)].x, 0, HiveCore.OUT[int(spec.door)].y) * 4.5
		var route: PackedVector3Array = map.path_between(door, cabin)
		if route.is_empty() or route[route.size() - 1].distance_to(cabin) > 1.5:
			bad += 1
			print("WAY lift %s: no way from %s into its cabin" % [id, str(old.id)])
		else:
			print("LIFT %s walkable from %s" % [id, str(old.id)])
	print("BUILT_RESULT faults=%d" % bad)
	return bad
