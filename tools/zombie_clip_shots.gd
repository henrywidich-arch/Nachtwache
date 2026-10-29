extends SceneTree
## Pictures of one infected look playing clips, for checking new or mirrored animation.
## Needs graphics (tools\godot_bg.ps1 -Render):
##   -s res://tools/zombie_clip_shots.gd -- --kind=normalzombie --clips=feed,shamble_left --out=C:/shots
## With --trail it also walks the body sideways in the dark, to show the eyes' streaks.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var kind := "normalzombie"
	var clips: PackedStringArray = ["idle"]
	var folder := "user://clip_shots"
	var trail := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			kind = arg.substr(7)
		elif arg.begins_with("--clips="):
			clips = arg.substr(8).split(",")
		elif arg.begins_with("--out="):
			folder = arg.substr(6)
		elif arg == "--trail":
			trail = true
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.02, 0.02, 0.03) if trail else Color(0.3, 0.32, 0.35)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	world.environment.ambient_light_energy = 0.08 if trail else 0.6
	world.environment.glow_enabled = true
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 0.08 if trail else 1.4
	root.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.fov = 40
	root.add_child(camera)
	camera.current = true
	camera.position = Vector3(2.6, 1.5, -3.2)
	camera.look_at(Vector3(0, 0.9, 0))
	var body := InfectedVisual.new()
	body.kind = kind
	root.add_child(body)
	await process_frame
	if trail:
		# Sideways across the view, then a quick turn of the head: the streaks follow.
		body.rotation.y = -0.68
		var shot := 0
		for frame in range(150):
			var t := frame / 60.0
			body.position = Vector3(sin(t * 2.2) * 1.4, 0, sin(t * 2.2) * 1.1)
			body.animate(1.0 / 60.0, 2.5)
			await process_frame
			if frame in [40, 75, 110, 140]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder.path_join("%s_trail_%d.png" % [kind, shot]))
				shot += 1
		quit()
		return
	for clip_name in clips:
		if not body.player.has_animation(clip_name):
			print("no clip ", clip_name)
			continue
		body.state = "attack"
		body.player.play(clip_name, 0.0)
		var length := body.player.current_animation_length
		for i in range(4):
			body.player.seek(length * (i + 0.5) / 4.0, true)
			body.animate(0.0, 0.0)
			body.trail_points.clear()
			for k in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("%s_%s_%d.png" % [kind, clip_name, i]))
		print("%s: %.2f s" % [clip_name, length])
	quit()
