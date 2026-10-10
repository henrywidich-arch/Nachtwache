extends SceneTree
## Lists the boxes of mission two's map that hold a point: -- --at=x,y,z[;x,y,z...]
func _initialize() -> void:
	var points: Array[Vector3] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			for text in arg.substr(5).split(";"):
				var p := text.split(",")
				points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	create_timer(240.0).timeout.connect(func() -> void: quit(2))
	MeshBatch.watching = true
	MeshBatch.watched.clear()
	var map := HiveMap.new()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	MeshBatch.watching = false
	for point in points:
		print("POINT ", point)
		for entry in MeshBatch.watched:
			var basis: Basis = entry[5]
			var size: Vector3 = entry[3]
			var centre: Vector3 = entry[2]
			var local := basis.inverse() * (point - centre)
			if absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5:
				print("   %s  centre %s size %s colour %s" % [str((entry[0] as MeshBatch).label), str(centre.snappedf(0.01)), str(size.snappedf(0.01)), str(entry[4])])
	quit(0)
