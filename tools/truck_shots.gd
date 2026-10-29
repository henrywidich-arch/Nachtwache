extends SceneTree
## Pictures of the rocket launcher truck of the simulation hall (RocketTruck), on a plain
## floor in an even light. Run with -Render (tools/godot_bg.ps1), never headless:
##   -s res://tools/truck_shots.gd -- --out=C:/shots

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(1))
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.37)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.7, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.25, 0.25, 0.26)
	floor.material_override = grey
	world.add_child(floor)
	var truck := RocketTruck.new()
	world.add_child(truck)
	var camera := Camera3D.new()
	camera.fov = 45.0
	world.add_child(camera)
	camera.current = true
	var views := [
		["truck_front34", Vector3(-8.5, 2.6, -10.5), Vector3(0, 2.2, -0.8), 0.0],
		["truck_side", Vector3(-15, 2.4, 0.3), Vector3(0, 1.8, 0.3), 0.0],
		["truck_rear34", Vector3(9, 4.5, 11), Vector3(0, 2.2, -1), 0.0],
		["truck_front", Vector3(0, 2.2, -10.5), Vector3(0, 1.9, -4), 0.0],
		["truck_raised", Vector3(-11, 4.0, -8), Vector3(0, 2.8, -1), 1.0],
		["truck_pods", Vector3(-2.5, 5.2, -9.5), Vector3(-0.3, 4.4, -2.6), 0.0]]
	for view: Array in views:
		truck.set_launcher(float(view[3]), 0.0)
		truck.display(0.016, true, true, 0.0, false)
		camera.position = view[1]
		camera.look_at(view[2], Vector3.UP)
		for i in range(12):
			await process_frame
		var image := root.get_texture().get_image()
		var path := folder.path_join(str(view[0]) + ".png")
		image.save_png(path)
		print("SHOT ", path)
	quit(0)
