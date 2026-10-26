extends SceneTree
## Pictures of the crate of throwables (GrenadeFinds): its model straight from the sides and
## from above (to find where which throwable is shown), then the crate as it lies with each
## throwable lit on it. Run drawing:
##   tools\godot_bg.ps1 -Render "-s res://tools/grenade_crate_shots.gd -- --out=C:/shots [--sides]"

func _initialize() -> void:
	_run.call_deferred()

func _shoot(folder: String, name: String) -> void:
	for k in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("shot ", folder.path_join(name + ".png"))

func _run() -> void:
	var folder := "user://grenade_crate"
	var sides := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg == "--sides":
			sides = true
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.08, 0.09, 0.1) if not sides else Color(0.3, 0.32, 0.35)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	world.environment.ambient_light_energy = 0.9 if sides else 0.25
	world.environment.glow_enabled = not sides
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2 if sides else 0.35
	root.add_child(sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	if sides:
		var model := (load(GrenadeFinds.MODEL) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 0.72
		var views := {"front_+z": Vector3(0, 0.25, 2), "back_-z": Vector3(0, 0.25, -2), "right_+x": Vector3(2, 0.25, 0), "left_-x": Vector3(-2, 0.25, 0), "top": Vector3(0, 2, 0.001)}
		for view in views:
			camera.position = views[view]
			camera.look_at(Vector3(0, 0.25, 0))
			await _shoot(folder, "side_" + view)
		quit()
		return
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	(floor.mesh as PlaneMesh).size = Vector2(6, 6)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.22, 0.22, 0.21)
	floor.material_override = concrete
	root.add_child(floor)
	camera.fov = 40
	for extra in GrenadeFinds.EXTRAS:
		var crate := GrenadeFinds.build_view(str(extra))
		root.add_child(crate)
		# Where a survivor walking up to it looks from.
		camera.position = Vector3(0.35, 1.25, 1.1)
		camera.look_at(Vector3(0, 0.25, 0))
		await _shoot(folder, "crate_" + str(extra))
		camera.position = Vector3(0, 1.4, 0.35)
		camera.look_at(Vector3(0, 0.3, 0.02))
		await _shoot(folder, "crate_%s_above" % extra)
		camera.fov = 40
		crate.queue_free()
		await process_frame
	quit()
