extends SceneTree
## Pictures of a model from four sides in plain light. Run windowed:
##   Godot --path . --resolution 1200x900 -s res://tools/model_preview.gd -- res://assets/finds/ammo_crate.glb --out=<folder>

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := ""
	var folder := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("res://"):
			path = arg
		elif arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.3, 0.32, 0.35)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	world.environment.ambient_light_energy = 0.6
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.4
	root.add_child(sun)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var box := AABB()
	var first := true
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var part := (item as MeshInstance3D).transform * (item as MeshInstance3D).mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	var camera := Camera3D.new()
	camera.fov = 40
	root.add_child(camera)
	camera.current = true
	var reach := box.size.length() * 1.5
	for i in range(4):
		var turn := i * PI / 2 + 0.6
		camera.position = box.get_center() + Vector3(sin(turn) * reach, box.size.y * 0.6 + reach * 0.3, cos(turn) * reach)
		camera.look_at(box.get_center())
		for k in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("%s_%d.png" % [path.get_file().get_basename(), i]))
	print("size ", box.size)
	quit()
