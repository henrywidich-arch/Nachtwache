extends SceneTree
## Every building part of assets/tokyo/kit side by side, seen from the street (+z), against
## a wall at z = 0 (where their backs should be), and once from above: is the front in
## front, does the back sit on the wall? Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/kit_sheet.gd -- --out=<folder> [--cc0]   (--cc0: the free models of assets/tokyo/cc0/models)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.25, 0.27, 0.3)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	world.environment.ambient_light_energy = 0.7
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var x := 0.0
	var paths: Array[String] = []
	if "--cc0" in OS.get_cmdline_user_args():
		for dir in DirAccess.get_directories_at("res://assets/tokyo/cc0/models"):
			paths.append("res://assets/tokyo/cc0/models/%s/%s_1k.gltf" % [dir, dir])
	else:
		for name in DirAccess.get_files_at("res://assets/tokyo/kit"):
			if name.ends_with(".glb"):
				paths.append("res://assets/tokyo/kit/" + name)
	for path in paths:
		var file := path.get_file()
		var model := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var box := AABB()
		var first := true
		for item in model.find_children("*", "MeshInstance3D", true, false):
			var part := (item as MeshInstance3D).transform * (item as MeshInstance3D).mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		model.position = Vector3(x - box.position.x, 0, 0)
		print("%s: size %s, from x %.2f z %.2f to %.2f, foot y %.2f" % [file, box.size, box.position.x, box.position.z, box.end.z, box.position.y])
		var label := Label3D.new()
		label.text = file.get_basename()
		label.font_size = 64
		label.pixel_size = 0.004
		label.position = Vector3(x + box.size.x * 0.5, -0.4, 0.5)
		root.add_child(label)
		x += box.size.x + 0.8
	var wall := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(x + 2.0, 7.0, 0.05)
	wall.mesh = plane
	wall.position = Vector3(x * 0.5, 3.0, -0.03)
	root.add_child(wall)
	var camera := Camera3D.new()
	camera.fov = 30
	root.add_child(camera)
	camera.current = true
	camera.position = Vector3(x * 0.5, 2.6, x * 1.05)
	camera.look_at(Vector3(x * 0.5, 2.0, 0))
	for k in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("kit_front.png"))
	camera.position = Vector3(x * 0.5, x * 0.9, 4.0)
	camera.look_at(Vector3(x * 0.5, 0, 0.5))
	for k in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("kit_top.png"))
	quit()
