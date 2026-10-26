extends SceneTree
## The simulation hall in a real night of the second mission: starts at the terminal's
## checkpoint, walks the way over into the hall (pictures on the way), measures the frame
## rate in the terminal and in the hall, and watches whether the bots follow and the
## infected get to the survivor in there. Run windowed:
##   Godot --path . --resolution 1600x900 -s res://tools/tokyo_play_shots.gd -- --out=<folder> [--no-warm-up]

var game: Node3D
var folder := "user://"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.profile.mission = 2
	game.hive.resume_at = "terminal"
	game.hive.tokyo_wanted = 1
	var began := Time.get_ticks_msec()
	game.start_run()
	print("mission 2 from the terminal: started in %d ms, map %s, team %d" % [Time.get_ticks_msec() - began, game.cabin.name, game.team.size()])
	await _frames(90)
	var map: HiveMap = game.cabin
	var terminal: Vector3 = map.points.terminal
	game.player.global_position = terminal + Vector3(30, 0.05, -3.4)
	await _shot("hive_terminal_east", 90.0, -2.0)
	var fps_terminal := await _fps()
	# Along the way: the lock, then out on to the crossing.
	var way: PackedVector3Array = map.path_between(game.player.global_position, map.points.tokyo_crossing)
	print("way to the crossing: %d points" % way.size())
	var walked := 0.0
	var shots := {18.0: "hive_passage", 33.0: "hive_lock"}
	for i in range(1, way.size()):
		walked += way[i - 1].distance_to(way[i])
		game.player.global_position = way[i] + Vector3(0, 0.05, 0)
		var step := way[i] - way[i - 1]
		if step.length() > 0.01:
			game.player.rotation.y = atan2(-step.x, -step.z)
		await _frames(2)
		for mark in shots.keys():
			if walked >= float(mark):
				await _shot(str(shots[mark]), -1.0, 2.0)
				shots.erase(mark)
	print("walked %.0f m, now at %s (zone %s)" % [walked, game.player.global_position, map.here_zone])
	await _shot("hive_tokyo_crossing", 0.0, 4.0)
	var fps_hall := await _fps()
	print("FPS terminal %.0f, hall %.0f" % [fps_terminal, fps_hall])
	# Henry's building and the video wall, from the corner of the crossing.
	var o: Vector3 = map.tokyo.origin
	game.player.global_position = o + Vector3(-3, 0.05, -3)
	await _shot("hive_tokyo_model", 225.0 - 180.0, 18.0)
	game.player.global_position = o + Vector3(2, 0.05, -2)
	await _shot("hive_tokyo_neo", 315.0, 20.0)
	# A crate of throwables of this night in the hall, put down as one comes near.
	var crate_spots: Array = game.finds.hidden.duplicate()
	for crate in game.pickups.get_children():
		if crate.get_meta("kind") == GrenadeFinds.KIND:
			crate_spots.append((crate as Node3D).global_position)
	for spot: Vector3 in crate_spots:
		if TokyoHall.plan_of(o).has_point(Vector2(spot.x, spot.z)):
			game.player.global_position = spot + Vector3(1.6, 0.05, 1.6)
			await _frames(10)
			game.player.rotation.y = atan2(1.6, 1.6)
			await _shot("hive_tokyo_crate", -1.0, -28.0)
			break
	# Do the bots come over, do the infected find the survivor in here?
	var watch := 0.0
	var closest := INF
	while watch < 45.0:
		await create_timer(1.0).timeout
		watch += 1.0
		for enemy in game.enemies.get_children():
			if enemy is Infected and not enemy.dead:
				closest = minf(closest, enemy.global_position.distance_to(game.player.global_position))
	var mates := PackedStringArray()
	for mate: Teammate in game.team:
		mates.append("%.0f m" % mate.global_position.distance_to(game.player.global_position))
	print("after %ds: bots at %s from the survivor, nearest infected %.1f m, alive %d" % [int(watch), ", ".join(mates), closest, game.enemies.get_child_count()])
	await _shot("hive_tokyo_fight", 200.0, 0.0)
	print("TOKYO HIVE PLAY DONE")
	quit()

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

## Frames per second over three seconds, vsync off.
func _fps() -> float:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _frames(30)
	var from := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - from < 3000000:
		await process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - from) / 1000000.0)

func _shot(file: String, yaw_degrees: float, pitch_degrees: float) -> void:
	if yaw_degrees > -0.5:
		game.player.rotation.y = deg_to_rad(yaw_degrees)
	game.player.camera.rotation.x = deg_to_rad(pitch_degrees)
	await _frames(25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(file + ".png"))
	print("saved ", file)
