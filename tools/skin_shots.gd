extends SceneTree
## Pictures of the weapon skins (WeaponSkins): each weapon from the side in each skin, and
## one in the first-person view. Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/skin_shots.gd -- --out=<folder> [--guns=rifle,ak] [--skins=drache,orbital]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://skins"
	var guns: Array = ["rifle", "pistol", "ak", "p90"]
	var skins: Array = WeaponSkins.SKINS.keys()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--guns="):
			guns = Array(arg.trim_prefix("--guns=").split(","))
		elif arg.begins_with("--skins="):
			skins = Array(arg.trim_prefix("--skins=").split(","))
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.13, 0.15, 0.17)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.7, 0.72, 0.76)
	world.environment.ambient_light_energy = 0.6
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.6
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 200, 0)
	fill.light_energy = 0.5
	root.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 30
	camera.near = 0.02
	root.add_child(camera)
	camera.current = true
	for id: String in guns:
		var model := WeaponView.display(id)
		root.add_child(model)
		var size: Vector3 = model.get_meta("size", Vector3(0.1, 0.3, 0.8))
		model.rotation = Vector3(0, PI * 0.5, 0)
		var far := maxf(size.z, size.y * 1.6) * 2.0
		for skin: String in [""] + skins:
			WeaponSkins.apply(model, skin)
			for side in [1.0, -1.0]:
				camera.position = Vector3(0, 0.02, far * side)
				camera.look_at(Vector3.ZERO)
				await _save(folder.path_join("%s_%s_%s.png" % [id, skin if skin != "" else "plain", "links" if side > 0 else "rechts"]))
		model.queue_free()
	# One in the hand, as the player sees it.
	camera.fov = Survivor.BASE_FOV
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	for skin: String in skins:
		var gun := WeaponView.build(str(guns[0]))
		camera.add_child(gun)
		var view: Dictionary = WeaponView.VIEWS[str(guns[0])]
		gun.position = view.hip
		gun.rotation = (view.hip_angles as Vector3) * (PI / 180.0)
		WeaponSkins.apply(gun, skin)
		await _save(folder.path_join("hand_%s_%s.png" % [guns[0], skin]))
		gun.queue_free()
	quit()

func _save(path: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
