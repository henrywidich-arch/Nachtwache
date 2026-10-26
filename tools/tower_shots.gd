extends SceneTree
## The NEO-108 tower taking turns (TokyoHall._tower_turn): pictures of its video wall at
## times through one round - Henry's film, the fade, NEO KICK!, the fade back.
##   godot --resolution 1280x720 -s res://tools/tower_shots.gd -- --out=<folder>
## Also prints whose turn it is every half second.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 50
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	camera.position = Vector3(3, 1.7, -3)
	camera.look_at(Vector3(16, 16, -16))
	var hall: Node = null
	for node in map.find_children("*", "", true, false):
		if node.get("tower_clock") != null:
			hall = node
			break
	var shots := [2.0, 12.6, 13.2, 20.0, 28.4, 29.0, 33.0]
	var from := Time.get_ticks_msec()
	var next := 0
	var said := 0.0
	while next < shots.size():
		await process_frame
		var t := (Time.get_ticks_msec() - from) / 1000.0
		if hall != null and t - said >= 0.5:
			said = t
			print("t=%.1f clock=%.2f spot=%s alpha=%.2f film_paused=%s" % [t, hall.tower_clock, hall.ad_spot.visible, hall.ad_spot.modulate.a, hall.video.paused if hall.video else "-"])
		if t >= shots[next]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("tower_%04.1f.png" % shots[next]))
			next += 1
	quit()
