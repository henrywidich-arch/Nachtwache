extends SceneTree
## Pictures of one weapon of the game as the player sees it, in the simulation hall's light
## (TokyoHall at the crossing): from the hip, aimed over its sights, and from the side
## (the model on its own in front of a lit shop). Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/gun_shots.gd -- --gun=falke --out=<folder> [--prefix=runde1_] [--skin=scorpion]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	var id := "falke"
	var prefix := ""
	var day := "--day" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--gun="):
			id = arg.trim_prefix("--gun=")
		elif arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
		elif arg.begins_with("--skin="):
			# The arms as that skin wears them (Profile.SKINS).
			WeaponView.wear(arg.trim_prefix("--skin="))
	DirAccess.make_dir_recursive_absolute(folder)
	# (--day: a bright field instead of the hall, as on the farm: size and place read better.)
	if day:
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
	# (build: any weapon of the view, those of MODELS too - the minigun.)
	var gun := WeaponView.build(id)
	camera.add_child(gun)
	var view: Dictionary = WeaponView.VIEWS[id]
	# Standing at the crossing, looking up the avenue at the tower and the screens.
	camera.position = Vector3(-2.0, 1.65, 20.0)
	camera.look_at(Vector3(0.0, 2.6, -20.0))
	for i in range(30):
		await process_frame
	gun.position = view.hip
	gun.rotation = (view.hip_angles as Vector3) * (PI / 180.0)
	await _save(folder.path_join(prefix + "spieler_huefte.png"))
	gun.position = view.aim
	gun.rotation = (view.get("aim_angles", Vector3.ZERO) as Vector3) * (PI / 180.0)
	await _save(folder.path_join(prefix + "spieler_zielen.png"))
	# Aimed through each sight it takes (its iron sights laid down, as in the game).
	var irons := gun.find_child("Sights", true, false) as Node3D
	for sight in ["reddot", "scope"]:
		var part := gun.find_child("Mod_" + sight, true, false) as Node3D
		if part == null:
			continue
		part.visible = true
		if irons != null and bool(WeaponView.GUNS.get(id, {}).get("folding", false)):
			irons.visible = false
		gun.position = WeaponView.sight_aim(id, sight)
		gun.rotation = Vector3.ZERO
		camera.fov = 40.0 if sight == "reddot" else 30.0
		await _save(folder.path_join(prefix + "spieler_zielen_" + sight + ".png"))
		part.visible = false
		if irons != null:
			irons.visible = true
	camera.fov = Survivor.BASE_FOV
	# The same, turned toward a lit shop front (light from the side on the weapon).
	camera.position = Vector3(-6.0, 1.65, 16.0)
	camera.look_at(Vector3(-12.0, 1.4, 17.5))
	gun.position = view.hip
	gun.rotation = (view.hip_angles as Vector3) * (PI / 180.0)
	await _save(folder.path_join(prefix + "spieler_laden.png"))
	gun.position = view.aim
	gun.rotation = (view.get("aim_angles", Vector3.ZERO) as Vector3) * (PI / 180.0)
	await _save(folder.path_join(prefix + "spieler_laden_zielen.png"))
	# From the side: the weapon alone, held in the air before the supply point's lamps.
	camera.remove_child(gun)
	root.add_child(gun)
	gun.position = Vector3(-8.0, 1.3, 16.0)
	gun.rotation = Vector3(0, PI * 0.5, 0)
	var support := gun.get_node_or_null("Support") as Node3D
	if support != null:
		support.visible = false
	camera.fov = 40
	camera.position = Vector3(-8.0, 1.36, 17.35)
	camera.look_at(Vector3(-8.0, 1.33, 16.0))
	await _save(folder.path_join(prefix + "seite_links.png"))
	camera.position = Vector3(-8.0, 1.36, 14.65)
	camera.look_at(Vector3(-8.0, 1.33, 16.0))
	await _save(folder.path_join(prefix + "seite_rechts.png"))
	quit()

func _save(path: String) -> void:
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
