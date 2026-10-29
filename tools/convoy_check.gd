extends SceneTree
## (v0.91) The rocket launcher's night of the simulation hall (TokyoConvoy): builds HiveMap
## for a few nights with that job and checks the barred steel door and the passage behind
## it, that the launcher's road round the hall is free for a truck as wide and tall as it,
## and that the way from the hall to the administration opens with the door. Headless:
##   Godot --headless --path . -s res://tools/convoy_check.gd [-- --nights=classic,6,11]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nights: Array = ["classic", "6", "11", "all"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nights="):
			nights = Array(arg.trim_prefix("--nights=").split(","))
	var faults: Array[String] = []
	var convoys := 0
	var halls := 0
	for s in range(1, 1001):
		var plan := HiveLayout.plan(s)
		if bool(plan.get("tokyo", false)):
			halls += 1
			convoys += 1 if TokyoTasks.job_of(plan) == TokyoTasks.CONVOY else 0
	print("seeds 1..1000: %d nights with the hall, %d of them with the rocket launcher" % [halls, convoys])
	if halls > 0 and (convoys < halls * 0.35 or convoys > halls * 0.65):
		faults.append("the rocket launcher comes in %d of %d hall nights" % [convoys, halls])
	var endless := HiveLayout.with_tokyo(HiveLayout.classic(), true)
	endless["endless"] = true
	if TokyoTasks.job_of(endless) != TokyoTasks.STABLE:
		faults.append("the endless night has the rocket launcher")
	for which in nights:
		var night: Dictionary = HiveLayout.classic()
		if which == "all":
			night = HiveLayout.every_seam()
		elif str(which).is_valid_int():
			night = HiveLayout.plan(int(which))
		night = HiveLayout.with_tokyo(night, true)
		night["tokyo_job"] = TokyoTasks.CONVOY
		var map := HiveMap.new()
		map.night = night
		root.add_child(map)
		await process_frame
		for i in range(3):
			await physics_frame
		var prefix := "night %s: " % which
		if map.tokyo == null or not is_finite(map.tokyo.breach_z):
			faults.append(prefix + "no hall with a steel door")
			continue
		if not map.room_of.has("tokyo_breach") or not map.door_of.has(TokyoConvoy.DOOR) or not map.door_of.has("tk_breach_guard"):
			faults.append(prefix + "the passage or its doors are missing")
			continue
		# The road: rays across the truck's width and along it, at three heights.
		var space := map.get_world_3d().direct_space_state
		var convoy := TokyoConvoy.new(null, map.tokyo, map, null)
		convoy._lay_path()
		var hits := 0
		var s := 0.0
		while s <= convoy.length:
			var pose := convoy._pose(s)
			var at: Vector3 = pose[0]
			var yaw := float(pose[1])
			var side := Vector3(cos(yaw), 0, -sin(yaw)) * 1.5
			var ahead := Vector3(-sin(yaw), 0, -cos(yaw)) * 5.0
			for h in [0.5, 1.8, 3.2, 4.6]:
				for q in [PhysicsRayQueryParameters3D.create(at - side + Vector3(0, h, 0), at + side + Vector3(0, h, 0)), PhysicsRayQueryParameters3D.create(at - ahead * 0.9 + Vector3(0, h, 0), at + ahead + Vector3(0, h, 0))]:
					var hit := space.intersect_ray(q)
					if not hit.is_empty():
						hits += 1
						if hits <= 6:
							print("%sroad blocked at s=%.0f (%s, h=%.1f) by %s" % [prefix, s, (hit.position as Vector3) - map.tokyo.origin, h, hit.collider])
			s += 1.0
		if hits > 0:
			faults.append(prefix + "%d blocked samples on the road" % hits)
		# The door is shut at first; with it and the administration open the passage leads on.
		map.lock_all()
		var start: Vector3 = map.points.tokyo_start
		var guard_side := Vector3(14.0, HiveMap.UNDER, map.tokyo.origin.z + map.tokyo.breach_z)
		if map.door_open(TokyoConvoy.DOOR):
			faults.append(prefix + "the steel door starts open")
		map.set_door(TokyoConvoy.DOOR, true, true)
		map.unlock("admin", true)
		await physics_frame
		var route: PackedVector3Array = map.path_between(start, map.points.junction)
		# (From the middle of the passage the checkpoint is a short walk west, not round by the hall.)
		var mid := Vector3(40.0, HiveMap.UNDER, guard_side.z)
		var on: PackedVector3Array = map.path_between(mid, map.points.junction)
		var through := on.size() > 1 and on.size() < 160 and map.path_between(start, mid).size() > 1
		print("%sroad %.0f m, path to the junction %d points%s" % [prefix, convoy.length, route.size(), " through the passage" if through else ""])
		if route.size() < 2 or not through:
			faults.append(prefix + "no way through the blown door to the junction")
		map.queue_free()
		await process_frame
	if faults.is_empty():
		print("CONVOY_CHECK OK")
	else:
		for f in faults:
			print("FAULT ", f)
		print("CONVOY_CHECK FAILED %d" % faults.size())
	quit(0 if faults.is_empty() else 1)
