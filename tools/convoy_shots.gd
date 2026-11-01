extends SceneTree
## (v0.91) Pictures of the rocket launcher's job in the Tokyo hall (TokyoConvoy), in the
## real game (the test room's visit): the launcher parked, at its firing place with the
## launcher raised, the rocket in flight, and the steel door blown open.
## Run with -Render (tools/godot_bg.ps1), never headless:
##   -s res://tools/convoy_shots.gd -- --out=C:/shots

var folder := "user://"
var camera: Camera3D

func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void: quit(1))
	_run.call_deferred()

func _shot(name: String, from: Vector3, to: Vector3, frames := 20) -> void:
	camera.global_position = from
	camera.look_at(to, Vector3.UP)
	for i in range(frames):
		await process_frame
	var path := folder.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	for i in range(10):
		await process_frame
	game.start_run(true)
	for i in range(10):
		await process_frame
	game.sandbox.visit(Sandbox.TOKYO_CONVOY)
	for i in range(30):
		await process_frame
	game.sandbox.set_daylight(false)
	game.sandbox.bare = true
	var c: TokyoConvoy = game.sandbox.convoy
	if c == null:
		print("NO CONVOY")
		quit(1)
		return
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 300.0
	game.add_child(camera)
	camera.current = true
	game.player.global_position = c.truck.global_position + Vector3(30, 0, 0)
	var o: Vector3 = c.hall.origin
	var t := c.truck
	await _shot("convoy_parked", t.to_global(Vector3(6.5, 2.0, -9.5)), t.to_global(Vector3(0, 2.0, -1.0)), 60)
	c.phase = "drive"
	c.travelled = c.length * 0.45
	for i in range(10):
		c.display(0.05)
		await process_frame
	await _shot("convoy_drive", t.to_global(Vector3(-6.0, 2.0, -15.0)), t.to_global(Vector3(0, 2.2, 0)))
	await _shot("convoy_ring", t.to_global(Vector3(4.0, 14.0, 22.0)), t.to_global(Vector3(0, 0, -4.0)))
	c.travelled = c.length
	c.phase = "aim"
	c.aim_time = 99.0
	for i in range(220):
		c.display(0.05)
		if i % 10 == 0:
			await process_frame
	await _shot("convoy_aim", o + Vector3(-28.0, 3.0, -38.5), t.to_global(Vector3(0, 3.2, -2.0)))
	await _shot("convoy_door", o + Vector3(-58.0, 1.8, -36.5), c.door_at(), 30)
	c.phase = "fire"
	c._launch(false)
	for i in range(12):
		c.display(0.05)
		await process_frame
	await _shot("convoy_rocket", o + Vector3(-40.0, 3.0, -30.5), (c.rocket.global_position if is_instance_valid(c.rocket) else c.door_at()), 1)
	for i in range(60):
		c.display(0.05)
		await process_frame
	c.phase = "open"
	c._show_open()
	await _shot("convoy_open", o + Vector3(-60.0, 1.8, -36.0), c.door_at() + Vector3(-3, -0.5, 0), 40)
	await _shot("convoy_passage", o + Vector3(-70.5, 1.7, -34.0), o + Vector3(-80.0, 1.4, -26.0), 30)
	quit(0)
