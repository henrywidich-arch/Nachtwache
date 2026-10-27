extends SceneTree
## The first-person arms in every skin (WeaponView.ARM_LOOKS): each weapon from the hip and
## rolled over to the left as if looked over, so that both arms show, per skin one sheet
## (<skin>.png, the weapons side by side, hip above, turned below) and each picture on
## its own. The views are built once and dressed again for each
## skin, as in the game when the skin changes. In daylight on a field unless --hall (the
## simulation hall's neon). Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/arm_shots.gd -- --out=<folder> [--skins=main,scorpion] [--guns=rifle,usp] [--hall]

## The pose looked over in: moved by TURN_AT, turned by TURN (degrees).
static var TURN_AT := Vector3(-0.12, 0.1, 0.06)
static var TURN := Vector3(35.0, 10.0, 60.0)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://arm_shots"
	var skins: Array = Profile.SKINS.keys()
	var guns: Array = ["rifle", "usp", "shotgun"]
	var hall := "--hall" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--skins="):
			skins = Array(arg.trim_prefix("--skins=").split(","))
		elif arg.begins_with("--turn="):
			var n := arg.trim_prefix("--turn=").split_floats(",")
			TURN_AT = Vector3(n[0], n[1], n[2])
			TURN = Vector3(n[3], n[4], n[5])
		elif arg.begins_with("--guns="):
			guns = Array(arg.trim_prefix("--guns=").split(","))
	DirAccess.make_dir_recursive_absolute(folder)
	var camera := Camera3D.new()
	camera.fov = Survivor.BASE_FOV
	camera.near = 0.02
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	if hall:
		var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
		map.name = "Tokio"
		root.add_child(map)
		camera.position = Vector3(-6.0, 1.65, 16.0)
		camera.look_at(Vector3(-12.0, 1.4, 17.5))
	else:
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.55, 0.66, 0.8)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.75, 0.78, 0.82)
		world.environment.ambient_light_energy = 0.8
		world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
		camera.position = Vector3(0, 1.65, 0)
		camera.rotation_degrees = Vector3(-8, 0, 0)
	var views := {}
	for id in guns:
		var view: Node3D = WeaponView.build(String(id))
		camera.add_child(view)
		view.hide()
		views[id] = view
	for i in range(30):
		await process_frame
	for skin in skins:
		WeaponView.wear(String(skin))
		var tiles: Array[Image] = []
		var turned: Array[Image] = []
		for id in guns:
			var view: Node3D = views[id]
			var place: Dictionary = WeaponView.VIEWS[id]
			view.show()
			view.position = place.hip
			view.rotation = (place.hip_angles as Vector3) * (PI / 180.0)
			var shot := await _shot()
			shot.save_png(folder.path_join("%s_%s_huefte.png" % [skin, id]))
			tiles.append(shot)
			# Looked over: raised, drawn in and turned, the arms toward the eye.
			view.position = (place.hip as Vector3) + TURN_AT
			view.rotation = TURN * (PI / 180.0)
			var over := await _shot()
			over.save_png(folder.path_join("%s_%s_gedreht.png" % [skin, id]))
			turned.append(over)
			view.hide()
		tiles.append_array(turned)
		(load("res://tools/skin_arm_shots.gd") as GDScript)._sheet(tiles, guns.size(), folder.path_join("%s.png" % skin))
		print("dressed ", skin)
	quit()

func _shot() -> Image:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
