extends SceneTree
## Pictures of the counters that sell first aid and ammunition (CabinMap._shop_station):
## each table of a map from before and from the side, with a lamp on the camera like the
## player's flashlight. The map is built on its own, without the game. Needs graphics:
##   tools\godot_bg.ps1 -Render "-s res://tools/shop_shots.gd -- --map=farm|hive|appenweier --out=C:/shots [--max=4]"

const MAPS := {"farm": "res://scripts/cabin.gd", "hive": "res://scripts/hive_map.gd", "appenweier": "res://scripts/appenweier_map.gd"}

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	var folder := "user://shop_shots"
	var which := "farm"
	var most := 6
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--map="):
			which = arg.trim_prefix("--map=")
		elif arg.begins_with("--max="):
			most = int(arg.trim_prefix("--max="))
	DirAccess.make_dir_recursive_absolute(folder)
	var map: Node3D = load(MAPS[which]).new()
	root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 60
	camera.near = 0.05
	root.add_child(camera)
	camera.current = true
	var torch := SpotLight3D.new()
	torch.position = Vector3(0.12, -0.12, -0.1)
	torch.light_color = Color("e6ecd8")
	torch.light_energy = 3.2
	torch.spot_range = 30
	torch.spot_angle = 40
	torch.shadow_enabled = true
	camera.add_child(torch)
	for i in range(1200):
		if not "build_times" in map or (map.get("build_times") as Dictionary).has("all"):
			break
		await process_frame
	await _frames(40)
	var tables: Array = []
	for child in map.find_children("*", "Node3D", true, false):
		if child is Node3D and child.scene_file_path == CabinMap.SHOP_TABLE:
			tables.append(child)
	print("%s: %d shop tables, %d stations" % [which, tables.size(), map.stations.size()])
	var count := 0
	for station: Dictionary in map.stations:
		if not CabinMap.SHOP_GOODS.has(str(station.kind)) or count >= most:
			continue
		var pos: Vector3 = station.pos
		var table: Node3D = null
		for candidate: Node3D in tables:
			if candidate.global_position.distance_to(pos) < 0.05:
				table = candidate
		if table == null:
			print("PROBLEM: no table at ", pos)
			continue
		var front: Vector3 = table.global_transform.basis.z.normalized()
		var side: Vector3 = table.global_transform.basis.x.normalized()
		var target := pos + Vector3(0, 0.85, 0)
		var name := "%s_%02d_%s" % [which, count, station.kind]
		for view: Array in [["front", pos + front * 2.3 + Vector3(0, 1.65, 0)], ["side", pos + front * 1.4 + side * 1.5 + Vector3(0, 1.4, 0)]]:
			camera.global_position = view[1]
			camera.look_at(target)
			await _frames(24)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("%s_%s.png" % [name, view[0]]))
			print("shot ", name, " ", view[0], " at ", pos)
		count += 1
	quit(0)

func _initialize() -> void:
	_run.call_deferred()
