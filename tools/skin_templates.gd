extends SceneTree
## Plain side pictures of every weapon, as templates for new skin designs: neutral grey
## background, even light, the weapon filling the picture, muzzle to the right (left side)
## and to the left (right side). Run with tools/godot_bg.ps1 -Render -Resolution 2400x1200:
##   -s res://tools/skin_templates.gd -- --out=<folder> [--guns=rifle,ak]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://skin_templates"
	var guns: Array = Survivor.ORDER.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--guns="):
			guns = Array(arg.trim_prefix("--guns=").split(","))
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.82, 0.83, 0.84)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.85, 0.86, 0.88)
	world.environment.ambient_light_energy = 0.7
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(world)
	for angles in [Vector3(-35, 20, 0), Vector3(-35, 200, 0), Vector3(-80, 0, 0)]:
		var lamp := DirectionalLight3D.new()
		lamp.rotation_degrees = angles
		lamp.light_energy = 1.1 if angles.y == 20 else 0.6
		root.add_child(lamp)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.01
	root.add_child(camera)
	camera.current = true
	var aspect := float(root.size.x) / float(root.size.y)
	for id: String in guns:
		if not WeaponView.VIEWS.has(id):
			continue
		var model := WeaponView.display(id)
		root.add_child(model)
		var size: Vector3 = model.get_meta("size", Vector3(0.1, 0.3, 0.8))
		model.rotation = Vector3(0, PI * 0.5, 0)
		# (Orthographic: the weapon fills 88 % of the width, or of the height if it is tall.)
		camera.size = maxf(size.y, size.z / aspect) / 0.88
		for side in [1.0, -1.0]:
			camera.position = Vector3(0, 0, 3.0 * side)
			camera.look_at(Vector3.ZERO)
			await _save(folder.path_join("%s_%s.png" % [id, "links" if side > 0 else "rechts"]))
		model.queue_free()
	quit()

func _save(path: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
