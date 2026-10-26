extends SceneTree
## Pictures of the landmark houses of the simulation hall (TokyoLandmarks), each from the
## front and its corner as in the picture it was built after (3/4, from a little above the
## street) and straight from the front. Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/landmark_shots.gd -- --out=<folder> [--only=ramen,tech] [--prefix=runde1_]

const HIGH := {"ramen": 9.0, "shinonome": 20.0, "sakura": 12.0, "tsukimi": 9.0, "tech": 17.0, "yamashita": 10.0, "pachinko": 10.0, "koi": 14.0}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	var only: Array = []
	var prefix := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
	DirAccess.make_dir_recursive_absolute(folder)
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	map.name = "Tokio"
	root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 62
	camera.near = 0.05
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	for i in range(30):
		await process_frame
	var hall: TokyoHall = null
	for node in map.find_children("*", "TokyoHall", true, false):
		hall = node
	if hall == null:
		print("no hall")
		quit()
		return
	for id: String in TokyoLandmarks.HOUSES:
		if not only.is_empty() and not only.has(id):
			continue
		var house: Dictionary = TokyoLandmarks.HOUSES[id]
		var lot: Rect2 = house.lot
		var front := hall._tk_face(lot, int(house.front))
		var side := hall._tk_face(lot, int(house.side))
		var high: float = HIGH.get(id, 10.0)
		var middle := Vector3(lot.get_center().x, high * 0.55, lot.get_center().y) + hall.origin
		var corner: Vector3 = hall._tk_point(front, 0.0, 0.0, 0.0)
		var far_corner: Vector3 = hall._tk_point(front, front.length, 0.0, 0.0)
		# The corner the side face shares with the front.
		var shared := corner if (side.start as Vector3).distance_to(corner) < 0.2 or hall._tk_point(side, side.length, 0, 0).distance_to(corner) < 0.2 else far_corner
		var out: Vector3 = front.out
		var away: Vector3 = side.out
		var reach := maxf(14.0, high * 1.1)
		camera.position = shared + hall.origin + out * reach * 0.8 + away * reach * 0.55 + Vector3(0, 2.6, 0)
		camera.look_at(middle)
		await _save(folder.path_join("%s%s_ecke.png" % [prefix, id]))
		var front_mid: Vector3 = hall._tk_point(front, float(front.length) * 0.5, 0.0, 0.0)
		camera.position = front_mid + hall.origin + out * minf(reach, 9.5) + Vector3(0, 2.2, 0)
		camera.look_at(front_mid + hall.origin + Vector3(0, high * 0.5, 0))
		await _save(folder.path_join("%s%s_front.png" % [prefix, id]))
		camera.position = front_mid + hall.origin + out * 5.5 + Vector3(0, 1.7, 0)
		camera.look_at(front_mid + hall.origin + Vector3(0, 2.6, 0))
		await _save(folder.path_join("%s%s_nah.png" % [prefix, id]))
		# From farther and higher: the whole house and its roof.
		camera.position = shared + hall.origin + out * reach * 1.6 + away * reach * 1.2 + Vector3(0, high * 0.45, 0)
		camera.look_at(middle + Vector3(0, high * 0.3, 0))
		await _save(folder.path_join("%s%s_fern.png" % [prefix, id]))
		var side_mid: Vector3 = hall._tk_point(side, float(side.length) * 0.5, 0.0, 0.0)
		camera.position = side_mid + hall.origin + away * minf(reach, 11.0) + Vector3(0, 2.2, 0)
		camera.look_at(side_mid + hall.origin + Vector3(0, high * 0.45, 0))
		await _save(folder.path_join("%s%s_seite.png" % [prefix, id]))
	quit()

func _save(path: String) -> void:
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
