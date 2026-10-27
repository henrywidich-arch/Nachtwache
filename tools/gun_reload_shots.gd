extends SceneTree
## Pictures of a weapon from GUNS as the player sees it while it is reloaded: from the hip,
## aimed, and five moments of the magazine change, posed as Survivor._animate_weapon poses
## them (raised and rolled by reload_low / reload_turn, magazine and hand by
## WeaponView.reload_step). In the simulation hall's light, like tools/gun_shots.gd.
## Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/gun_reload_shots.gd -- --gun=p90 --out=<folder> [--prefix=p90_] [--day] [--moments=0.1,0.3,0.5]
## (--day: a bright field and a sun instead of the hall, as tools/gun_shots.gd has it.
## --moments: the moments of the reload (0 to 1) to show instead of the five usual ones.)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	var id := "p90"
	var prefix := ""
	var moments: Array = [0.12, 0.3, 0.45, 0.62, 0.85]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--moments="):
			moments = Array(arg.trim_prefix("--moments=").split(",")).map(func(t: String) -> float: return t.to_float())
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--gun="):
			id = arg.trim_prefix("--gun=")
		elif arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
	DirAccess.make_dir_recursive_absolute(folder)
	if "--day" in OS.get_cmdline_user_args():
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.55, 0.66, 0.8)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.75, 0.78, 0.82)
		world.environment.ambient_light_energy = 0.8
		root.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, 30, 0)
		root.add_child(sun)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(200, 200)
		ground.mesh = plane
		var grass := StandardMaterial3D.new()
		grass.albedo_color = Color(0.32, 0.42, 0.22)
		ground.material_override = grass
		root.add_child(ground)
	else:
		var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
		map.name = "Tokio"
		root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = Survivor.BASE_FOV
	camera.near = 0.02
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	var gun := WeaponView.build(id)
	camera.add_child(gun)
	var view: Dictionary = WeaponView.VIEWS[id]
	camera.position = Vector3(-2.0, 1.65, 20.0)
	camera.look_at(Vector3(0.0, 2.6, -20.0))
	for i in range(30):
		await process_frame
	var hip_angles: Vector3 = (view.hip_angles as Vector3) * (PI / 180.0)
	gun.position = view.hip
	gun.rotation = hip_angles
	await _save(folder.path_join(prefix + "huefte.png"))
	gun.position = view.aim
	gun.rotation = (view.get("aim_angles", Vector3.ZERO) as Vector3) * (PI / 180.0)
	await _save(folder.path_join(prefix + "zielen.png"))
	var clip := gun.get_node_or_null("Magazine") as Node3D
	var hand := gun.get_node_or_null("Support") as Node3D
	var low: Vector3 = view.get("reload_low", Vector3(0.025, -0.12, 0.03))
	var turn: Vector3 = view.get("reload_turn", Vector3(0.55, 0.25, -0.6))
	var k := 0
	for done: float in moments:
		k += 1
		var pose := sin(done * PI)
		gun.position = (view.hip as Vector3) + low * pose
		gun.rotation = hip_angles + turn * pose
		var step := WeaponView.reload_step(id, done)
		if clip != null:
			clip.position = step.magazine
		if hand != null:
			hand.position = step.hand
		await _save(folder.path_join(prefix + "nachladen_%d.png" % k))
	quit()

func _save(path: String) -> void:
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
