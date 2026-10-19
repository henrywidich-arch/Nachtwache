extends SceneTree
## Bakes the smooth hands and arms of the first-person view (see WeaponView._make_shapes):
##   Godot --headless --path <project> -s res://tools/bake_hands.gd
## Builds every weapon of the view and every throwing hand, notes the shapes of their hands,
## has tools/bake_hands.py melt each set into a surface, and saves it as a mesh in
## assets/hands (named after the shapes, so a pose that changes needs a new bake; until
## then it is drawn in the plain pieces). Meshes no pose uses any more are removed.
## Needs python3 with numpy and scikit-image.

func _initialize() -> void:
	WeaponView.dumping = true
	WeaponView.dumped.clear()
	for id in WeaponView.VIEWS:
		var view: Node3D = WeaponView.build(String(id))
		view.free()
	for kind in Throwable.KINDS:
		var hand: Node3D = (load("res://scripts/throw_view.gd") as GDScript).build(String(kind))
		hand.free()
	WeaponView.dumping = false
	var folder := ProjectSettings.globalize_path("user://hand_bake")
	DirAccess.make_dir_recursive_absolute(folder)
	var source := folder.path_join("shapes.json")
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_string(JSON.stringify(WeaponView.dumped))
	file.close()
	var output: Array = []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/bake_hands.py"), source, folder], output, true)
	print("".join(output))
	if code != 0:
		print("HAND_BAKE_FAILED")
		quit(1)
		return
	var target := ProjectSettings.globalize_path(WeaponView.HAND_FOLDER)
	DirAccess.make_dir_recursive_absolute(target)
	var kept := {}
	for entry: Dictionary in WeaponView.dumped:
		var key := String(entry.key)
		if kept.has(key):
			continue
		kept[key] = true
		var mesh := _read(folder.path_join(key + ".bin"))
		if mesh == null:
			continue
		ResourceSaver.save(mesh, WeaponView.HAND_FOLDER + key + ".res", ResourceSaver.FLAG_COMPRESS)
	for name in DirAccess.get_files_at(target):
		if name.ends_with(".res") and not kept.has(name.get_basename()):
			DirAccess.remove_absolute(target.path_join(name))
	print("HAND_BAKE_DONE %d" % kept.size())
	quit()

func _read(path: String) -> ArrayMesh:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var mesh := ArrayMesh.new()
	var groups := file.get_32()
	for g in range(groups):
		var name := file.get_buffer(file.get_32()).get_string_from_utf8()
		var verts := file.get_32()
		var count := file.get_32()
		var positions := file.get_buffer(verts * 12).to_float32_array()
		var normals := file.get_buffer(verts * 12).to_float32_array()
		var colours := file.get_buffer(verts * 12).to_float32_array()
		var indices := file.get_buffer(count * 4).to_int32_array()
		var points := PackedVector3Array()
		var facing := PackedVector3Array()
		var paint := PackedColorArray()
		points.resize(verts)
		facing.resize(verts)
		paint.resize(verts)
		for i in range(verts):
			points[i] = Vector3(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2])
			facing[i] = Vector3(normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2])
			paint[i] = Color(colours[i * 3], colours[i * 3 + 1], colours[i * 3 + 2])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = facing
		arrays[Mesh.ARRAY_COLOR] = paint
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, name)
	return mesh
