extends SceneTree
## (v0.89) The old route after the ride, laid out differently every night (HiveLayout
## old_route): builds the second mission's map for every room of the lockdown desk, every
## caved-in stretch, both ways to the canteen and every place of the gate's desk, and checks
## that every desk can be walked to, that a cave-in really closes the corridor (the way goes
## round), that a jammed gate sends the squad through the staff room, and how often seeds
## give each layout. Headless:
##   Godot --headless --path . -s res://tools/old_route_check.gd

func _initialize() -> void:
	create_timer(1200.0).timeout.connect(func() -> void:
		print("OLD_ROUTE_WATCHDOG")
		quit(1))
	_run.call_deferred()

func _length(route: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	return total

func _run() -> void:
	var faults: Array[String] = []
	var counts := {}
	var same_as_ever := 0
	for s in range(1, 1001):
		var plan := HiveLayout.old_route(HiveLayout.plan(s))
		for key in plan:
			var tag := "%s=%s" % [key, plan[key]]
			counts[tag] = int(counts.get(tag, 0)) + 1
		if plan.desk == "security" and plan.block == "" and plan.cafe == "ring":
			same_as_ever += 1
	print("seeds 1..1000: ", counts)
	if same_as_ever > 0:
		faults.append("%d seeds give the old layout of the administration" % same_as_ever)
	if HiveLayout.old_route(HiveLayout.classic()).desk != "security" or HiveLayout.old_route(HiveLayout.plan(7)) != HiveLayout.old_route(HiveLayout.plan(7)):
		faults.append("the classic night is not the old route, or a seed does not give the same route twice")
	var cases := [
		["security", "east", "ring", "deck"], ["security", "west", "staff", "west"], ["archive", "", "ring", "east"],
		["archive", "west", "staff", "deck"], ["server", "east", "staff", "west"], ["server", "", "ring", "deck"],
		["staff", "west", "ring", "east"], ["staff", "east", "staff", "deck"], ["security", "", "ring", "deck"]
	]
	for case: Array in cases:
		var map := HiveMap.new()
		map.night = HiveLayout.classic()
		map.old_route = {"desk": case[0], "block": case[1], "cafe": case[2], "control": case[3]}
		root.add_child(map)
		while not map.build_times.has("all"):
			await process_frame
		for id in map.areas:
			map.unlock(str(id), true)
		var name := ",".join(case)
		var junction: Vector3 = map.points.junction
		var desk: Vector3 = map.points.security
		var to_desk := map.path_between(junction, desk)
		var to_control := map.path_between(map.points.terminal, map.points.control)
		var to_cafe := map.path_between(junction, map.points.cafeteria)
		var across := map.path_between(Vector3(10.0, HiveMap.UNDER, -365.0), Vector3(22.0, HiveMap.UNDER, -365.0)) if case[1] == "east" else map.path_between(Vector3(-11.0, HiveMap.UNDER, -365.0), Vector3(-23.0, HiveMap.UNDER, -365.0))
		print("%-28s desk %5.1f m  control %5.1f m  canteen %5.1f m  across the corridor %5.1f m" % [name, _length(to_desk), _length(to_control), _length(to_cafe), _length(across)])
		if to_desk.size() < 2:
			faults.append(name + ": no way to the lockdown desk")
		if to_control.size() < 2:
			faults.append(name + ": no way to the gate's desk")
		if to_cafe.size() < 2:
			faults.append(name + ": no way to the canteen")
		if case[1] != "" and (across.size() < 2 or _length(across) < 25.0):
			faults.append(name + ": the cave-in does not close the corridor (%.1f m)" % _length(across))
		if case[2] == "staff" and _length(to_cafe) < 75.0:
			faults.append(name + ": the jammed gate lets the squad through (%.1f m)" % _length(to_cafe))
		if not map.interaction_devices.has("security") or not map.interaction_devices.has("control"):
			faults.append(name + ": a desk has nothing to aim at")
		if desk.distance_to(map.points.junction) < 1.0:
			faults.append(name + ": no desk point")
		map.queue_free()
		await process_frame
	if faults.is_empty():
		print("OLD_ROUTE_OK")
		quit(0)
	else:
		for fault in faults:
			print("FAULT ", fault)
		quit(1)
