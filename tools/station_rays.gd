extends SceneTree
## Measures how the stations of mission two's map stand: for each, rays from the room
## towards the wall beside it and through its middle - how far before the back of the
## station the first thing is that they hit (the wall's face, or what stands there).
func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void: quit(2))
	var map := HiveMap.new()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	for i in range(4):
		await physics_frame
	var space := map.get_world_3d().direct_space_state
	for station in map.stations:
		if not station.has("facing"):
			continue
		var facing: Vector3 = station.facing
		var along := Vector3(-facing.z, 0, facing.x)
		var size: Vector3 = HiveStations.size_of(map, str(station.look))
		var front: Vector3 = station.pos
		var back := front - facing * size.z
		var line := "%-10s %-8s %-8s front %s  " % [str(station.get("site", "supply")), station.kind, station.look, str(front.snappedf(0.01))]
		for off: float in [-(size.x * 0.5 + 0.3), 0.0, size.x * 0.5 + 0.3]:
			var text := ""
			for high: float in [0.4, 1.3, 2.1]:
				var from := front + facing * 2.2 + along * off + Vector3(0, high, 0)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - facing * 5.0, 1))
				text += " %5.2f" % ((hit.position as Vector3 - back).dot(facing) if not hit.is_empty() else -9.0)
			line += " [%+.2f:%s]" % [off, text]
		print(line)
	quit(0)
