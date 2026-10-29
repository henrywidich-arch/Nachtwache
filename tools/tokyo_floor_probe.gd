extends SceneTree
## Looks for holes in the floor on the way into the simulation hall (the passage from the
## terminal, the lock and the first metres of the hall): casts rays straight down on a grid
## and names every spot without a floor right under it. Headless is fine:
##   Godot --headless --path . -s res://tools/tokyo_floor_probe.gd [-- --night=6]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var night: Dictionary = HiveLayout.classic()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--night="):
			night = HiveLayout.plan(int(arg.trim_prefix("--night=")))
	var map := HiveMap.new()
	map.night = HiveLayout.with_tokyo(night, true)
	root.add_child(map)
	await physics_frame
	await physics_frame
	await physics_frame
	var space := map.get_world_3d().direct_space_state
	var z0 := HiveMap.TOKYO_AT.z
	var holes := 0
	var x := 36.07
	while x <= 90.0:
		var line := ""
		var z := z0 - 1.53
		while z <= z0 + 1.6:
			var from := Vector3(x, HiveMap.UNDER + 1.2, z)
			var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -3.0, 0), 1 | 16)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				line += "#"
				holes += 1
			elif absf(float(hit.position.y) - HiveMap.UNDER) > 0.3:
				line += "~"
			else:
				line += "."
			z += 0.4
		print("x %6.1f  %s" % [x, line])
		x += 0.5
	print("TOKYO FLOOR PROBE: %d holes" % holes)
	quit(0 if holes == 0 else 1)
