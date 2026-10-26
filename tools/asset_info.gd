extends SceneTree
## What an imported model is: its size, its meshes, triangles and materials.
##   Godot --headless --path . -s res://tools/asset_info.gd -- res://assets/tokyo/building.glb

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("res://"):
			continue
		var scene := load(arg) as PackedScene
		if scene == null:
			print("cannot load ", arg)
			continue
		var node := scene.instantiate() as Node3D
		root.add_child(node)
		var box := AABB()
		var first := true
		var triangles := 0
		var meshes := 0
		var materials := {}
		for item in node.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := item as MeshInstance3D
			if mesh_node.mesh == null:
				continue
			meshes += 1
			var shape: AABB = mesh_node.global_transform * mesh_node.mesh.get_aabb()
			box = shape if first else box.merge(shape)
			first = false
			for s in range(mesh_node.mesh.get_surface_count()):
				var arrays := mesh_node.mesh.surface_get_arrays(s)
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += index.size() / 3 if index.size() > 0 else verts.size() / 3
				var mat := mesh_node.mesh.surface_get_material(s)
				if mat != null:
					materials[mat.resource_name if mat.resource_name != "" else str(mat)] = mat.get_class()
		print("%s: %d meshes, %d triangles, size %s, from %s" % [arg, meshes, triangles, box.size, box.position])
		for key in materials:
			print("  material ", key, " (", materials[key], ")")
		for child in node.get_children():
			print("  child ", child.name, " ", child.get_class())
		node.queue_free()
	quit()
