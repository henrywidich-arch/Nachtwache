extends SceneTree
## Checks the way to the goal (PathGuide, middle mouse button) on all three maps: the
## first mission's farm, the second mission from each checkpoint, Appenweier. For every
## start it asks for the way to the goal of the HUD (or, with none, to the stations) and
## prints how long it took, how long the way is and whether it reaches the goal.
##   Godot --headless --path . -s res://tools/path_guide_check.gd
## With pictures (never headless): tools/godot_bg.ps1 -Render -GodotArgs
##   "-s res://tools/path_guide_check.gd -- --out=<folder>"

var out := ""
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	var game := (load(main_scene) as PackedScene).instantiate()
	root.add_child(game)
	for i in range(30):
		await process_frame
	var profile: Profile = game.profile
	profile.stored = false
	game.story_in_checks = false
	var kept := profile.mission
	# --- the farm
	profile.mission = 1
	game.start_run()
	await _frames(40)
	await _try(game, "einsatz1_start")
	# A task of the farm, as the rounds bring them.
	game.mission.prepare()
	await _try(game, "einsatz1_stationen", true)
	# --- the second mission, from each checkpoint
	profile.mission = 2
	for point: String in ["landing", "descent", "terminal", "atrium", "labs"]:
		game.hive.resume_at = point
		game.start_run()
		await _frames(60)
		await _try(game, "einsatz2_" + point)
	# --- Appenweier
	profile.mission = 3
	game.start_run()
	await _frames(60)
	await _try(game, "einsatz3_start", true)
	profile.mission = kept
	print("PATH_GUIDE_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)

## Asks for the way from where the player stands to the goal; `stations`: to the first
## station of the map when there is no marker.
func _try(game: Node3D, tag: String, stations: bool = false) -> void:
	# (No intro in the way.)
	if game.story.intro_left > 0.0:
		game.story._end_intro(true)
	if game.hive.on:
		game.hive._end_intro()
	await _frames(20)
	var guide: PathGuide = game.path_guide
	var from: Vector3 = game.player.global_position
	var to: Vector3 = guide.pick_goal(from, game.markers())
	if to == Vector3.INF and stations and not game.cabin.stations.is_empty():
		var far := 0.0
		for station: Dictionary in game.cabin.stations:
			if from.distance_to(station.pos) > far:
				far = from.distance_to(station.pos)
				to = station.pos
	if to == Vector3.INF:
		print("PATH %s: no goal" % tag)
		return
	var started := Time.get_ticks_usec()
	if not guide.request(from, to):
		print("PATH %s: request refused" % tag)
		failures += 1
		return
	var parsed := (Time.get_ticks_usec() - started) / 1000.0
	var waited := 0
	while guide.state == "baking" and waited < 600:
		await process_frame
		waited += 1
	var took := (Time.get_ticks_usec() - started) / 1000.0
	var ok := guide.shown() and guide.points.size() >= 2
	if not ok:
		failures += 1
	print("PATH %s: ok=%s reaches=%s length=%.1f m straight=%.1f m points=%d parse=%.0f ms total=%.0f ms from=%s to=%s" % [tag, ok, guide.reaches, guide.length(), from.distance_to(to), guide.points.size(), parsed, took, str(from.snapped(Vector3.ONE * 0.1)), str(guide.goal.snapped(Vector3.ONE * 0.1))])
	if ok and out != "":
		# Turned towards the way, as a player who looks for it.
		var look: Vector3 = _along(guide.points, 7.0) - game.player.global_position
		game.player.rotation.y = atan2(-look.x, -look.z)
		game.player.camera.rotation.x = -0.28
		await _frames(20)
		await _save(out.path_join(tag + "_ego.png"))
		# From above and behind, so the whole way can be seen.
		var eye := Camera3D.new()
		game.add_child(eye)
		var start: Vector3 = guide.points[0]
		var ahead: Vector3 = _along(guide.points, 9.0)
		var back := start - ahead
		back.y = 0.0
		eye.global_position = start + back.normalized() * 2.5 + Vector3(0, 3.2, 0)
		eye.look_at(ahead)
		eye.fov = 70.0
		eye.current = true
		await _save(out.path_join(tag + "_hinten.png"))
		eye.queue_free()
		game.player.camera.current = true
	guide.hide_way()

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _save(path: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

## The place `metres` along a way (its end if it is shorter).
func _along(way: PackedVector3Array, metres: float) -> Vector3:
	var run := 0.0
	for i in range(1, way.size()):
		var piece := way[i - 1].distance_to(way[i])
		if run + piece >= metres:
			return way[i - 1].lerp(way[i], (metres - run) / piece)
		run += piece
	return way[way.size() - 1]
