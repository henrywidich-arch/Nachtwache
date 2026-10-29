extends SceneTree
## (v0.90) Close pictures of the machine gun's belt and the G36's own red dot, the weapon on
## its own in daylight (WeaponView.display, so without the view's squeezed depth). The belt
## is shown full and settled, half-way through moving on after a shot, and with few rounds
## left in the box; the red dot from behind, both sides, ahead and above. Run with
## tools/godot_bg.ps1 -Render:
##   -s res://tools/part_closeups.gd -- --out=<folder> [--prefix=name_] [--only=belt|dot]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	var prefix := ""
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.55, 0.66, 0.8)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75, 0.78, 0.82)
	world.environment.ambient_light_energy = 0.7
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.5
	root.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.near = 0.005
	camera.far = 50
	root.add_child(camera)
	camera.current = true
	if only != "dot":
		var mg := WeaponView.display("mg")
		root.add_child(mg)
		var view := mg.get_child(0) as Node3D
		var belt := view.find_child("Belt", true, false) as Node3D
		var at := _middle(belt)
		var shots := [["voll", 100, 1.0], ["schuss_halb", 100, 0.02], ["schuss_frisch", 100, 0.0], ["noch_6", 6, 1.0], ["noch_6_schuss", 6, 0.025], ["noch_2", 2, 1.0], ["leer", 0, 1.0]]
		for shot in shots:
			WeaponView.pose_belt(view, int(shot[1]), float(shot[2]))
			for eye in [["links", Vector3(-0.32, 0.06, 0.05)], ["vorn", Vector3(-0.22, 0.1, -0.22)]]:
				camera.position = at + (eye[1] as Vector3)
				camera.look_at(at)
				await _save(folder.path_join("%sgurt_%s_%s.png" % [prefix, shot[0], eye[0]]))
		mg.queue_free()
	if only != "belt":
		var g36 := WeaponView.display("g36")
		root.add_child(g36)
		var dot := g36.find_child("Mod_reddot", true, false) as Node3D
		dot.visible = true
		var sights := g36.find_child("Sights", true, false) as Node3D
		await process_frame
		var at := _middle(dot)
		for eye in [["hinten", Vector3(-0.05, 0.035, 0.16)], ["links", Vector3(-0.17, 0.04, 0.02)], ["rechts", Vector3(0.17, 0.04, -0.02)], ["vorn", Vector3(0.06, 0.05, -0.17)], ["oben", Vector3(-0.07, 0.15, 0.06)], ["weit", Vector3(-0.32, 0.12, 0.3)]]:
			camera.position = at + (eye[1] as Vector3)
			camera.look_at(at)
			await _save(folder.path_join("%srotpunkt_%s.png" % [prefix, eye[0]]))
	quit()

## The middle of what is shown under a node, in the world.
func _middle(node: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var part: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box.get_center()

func _save(path: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
