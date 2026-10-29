extends SceneTree
## Pictures of the second mission's map from free viewpoints (with a torch on the camera).
## Run with -Render (tools/godot_bg.ps1), never headless:
##   -s res://tools/hive_view_shots.gd -- --out=C:/shots --layout=classic|<seed> [--tokyo]
##       --view=name:x,y,z:x,y,z[:fov]  (as many as wanted; the doors of the map are open)

func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("SHOTS_WATCHDOG")
		quit(1))
	_run.call_deferred()

func _vector(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

func _run() -> void:
	var folder := "user://"
	var layout := "classic"
	var hall := false
	var views: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--layout="):
			layout = arg.trim_prefix("--layout=")
		elif arg == "--tokyo":
			hall = true
		elif arg.begins_with("--view="):
			views.append(arg.trim_prefix("--view=").split(":"))
	var night: Dictionary = HiveLayout.classic() if not layout.is_valid_int() else HiveLayout.plan(int(layout))
	if hall:
		night = HiveLayout.with_tokyo(night, true)
	var map := HiveMap.new()
	map.night = night
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	for id in map.areas:
		map.unlock(str(id), true)
	for id in map.door_of:
		if map.has_method("set_door"):
			map.set_door(str(id), true)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.far = 400.0
	var torch := SpotLight3D.new()
	torch.spot_range = 30.0
	torch.spot_angle = 30.0
	torch.light_energy = 2.0
	camera.add_child(torch)
	for view: PackedStringArray in views:
		camera.position = _vector(view[1])
		camera.fov = float(view[3]) if view.size() > 3 else 75.0
		camera.look_at(_vector(view[2]), Vector3.UP)
		for i in range(40):
			map.feel(PackedVector3Array([camera.position]))
			await process_frame
		var image := root.get_texture().get_image()
		var path := folder.path_join(str(view[0]) + ".png")
		image.save_png(path)
		print("SHOT ", path)
	quit(0)
