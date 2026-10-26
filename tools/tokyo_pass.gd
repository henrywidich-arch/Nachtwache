extends SceneTree
## A slow pass along shop fronts, to look for flicker: the camera walks from --from to --to
## (x,z in the hall) at --speed m/s, at eye height, looking along --look (x,z direction).
## Record it with the Movie Maker:
##   godot --resolution 1280x720 --write-movie <file.avi> --fixed-fps 30 -s res://tools/tokyo_pass.gd -- --from=-36,-9 --to=-12,-9 --look=0.3,-1 [--speed=1.2]

func _init() -> void:
	_run.call_deferred()

func _v(text: String) -> Vector2:
	var p := text.split(",")
	return Vector2(float(p[0]), float(p[1]))

func _run() -> void:
	var from := Vector2(-36, -9)
	var to := Vector2(-12, -9)
	var look := Vector2(0, -1)
	var speed := 1.2
	var high := 1.7
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			from = _v(arg.trim_prefix("--from="))
		elif arg.begins_with("--to="):
			to = _v(arg.trim_prefix("--to="))
		elif arg.begins_with("--look="):
			look = _v(arg.trim_prefix("--look=")).normalized()
		elif arg.begins_with("--speed="):
			speed = float(arg.trim_prefix("--speed="))
		elif arg.begins_with("--high="):
			high = float(arg.trim_prefix("--high="))
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 74
	camera.near = 0.05
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	for i in range(30):
		camera.position = Vector3(from.x, high, from.y)
		camera.look_at(camera.position + Vector3(look.x, 0.05, look.y))
		await process_frame
	var length := from.distance_to(to)
	var gone := 0.0
	while gone <= length:
		var at := from.lerp(to, gone / length)
		camera.position = Vector3(at.x, high, at.y)
		camera.look_at(camera.position + Vector3(look.x, 0.05, look.y))
		await process_frame
		gone += speed / 30.0
	quit()
