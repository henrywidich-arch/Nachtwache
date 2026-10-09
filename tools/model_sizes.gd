extends SceneTree
## Prints the size of every model of mission two as it comes out of its file:
##   godot --headless --path . -s res://tools/model_sizes.gd
## One line each: name, size in metres (x, y, z), lowest point, triangles, surfaces.

func _init() -> void:
	var folders := ["res://assets/hive/models", "res://assets/hive/user"]
	for folder in folders:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		var files: Array[String] = []
		for entry in dir.get_directories():
			files.append("%s/%s/%s.gltf" % [folder, entry, entry])
		for entry in dir.get_files():
			if entry.ends_with(".glb"):
				files.append(folder + "/" + entry)
		files.sort()
		for file in files:
			if not ResourceLoader.exists(file):
				print("MODEL %s missing" % file)
				continue
			var scene: PackedScene = load(file)
			var node: Node = scene.instantiate()
			var found: Array = []
			var counts := [0, 0]
			_measure(node, Transform3D.IDENTITY, found, counts)
			var box: AABB = found[0] if not found.is_empty() else AABB()
			print("MODEL %-32s size %6.2f %6.2f %6.2f  low %6.2f  centre %6.2f %6.2f  tris %6d  surfaces %d" % [file.get_file().get_basename(), box.size.x, box.size.y, box.size.z, box.position.y, box.get_center().x, box.get_center().z, counts[0], counts[1]])
			node.free()
	quit()

func _measure(node: Node, frame: Transform3D, found: Array, counts: Array) -> void:
	var here := frame
	if node is Node3D:
		here = frame * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		var box: AABB = here * mesh.get_aabb()
		if found.is_empty():
			found.append(box)
		else:
			found[0] = (found[0] as AABB).merge(box)
		for surface in range(mesh.get_surface_count()):
			counts[1] += 1
			var arrays := mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			if indices != null and (indices as PackedInt32Array).size() > 0:
				counts[0] += (indices as PackedInt32Array).size() / 3
			else:
				counts[0] += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for child in node.get_children():
		_measure(child, here, found, counts)
