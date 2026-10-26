extends SceneTree
## Checks the third map (scripts/appenweier_map.gd): it is built, every spawn point has a
## way to the house, a night starts on it, the infected come and find the survivor.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/appenweier_check.gd
## Exit code 0 when everything holds, 1 otherwise.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(text: String) -> void:
	failures.append(text)
	print("FAIL  ", text)

func _run() -> void:
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	for i in range(3):
		await process_frame
	game.team_enabled = "--bots" in OS.get_cmdline_user_args()
	game.profile.mission = 3
	game.profile.mode = "story"
	var began := Time.get_ticks_msec()
	game.start_run()
	print("start_run took %d ms" % (Time.get_ticks_msec() - began))
	var map: Node3D = game.cabin
	if map.get_script() != load("res://scripts/appenweier_map.gd"):
		_fail("the map in the world is not Appenweier")
		quit(1)
		return
	print("build: ", map.get("build_times"))
	print("rooms %d, doors %d, stations %d, spawn points %d, footprints %d" % [(map.get("rooms") as Array).size(), (map.get("doors") as Array).size(), (map.get("stations") as Array).size(), (map.get("spawn_points") as Array).size(), (map.get("footprints") as Array).size()])
	var start: Vector3 = map.get("player_start")
	if map.call("is_indoors", start) != true:
		_fail("the player does not start inside the house")
	var spawns: Array = map.get("spawn_points")
	if spawns.size() < 8:
		_fail("only %d spawn points" % spawns.size())
	for spot: Vector3 in spawns:
		var route: PackedVector3Array = map.call("path_between", spot, start)
		if route.size() < 2:
			_fail("no way from the spawn point %s to the house" % spot)
		else:
			var last := route[route.size() - 1]
			if Vector2(last.x - start.x, last.z - start.z).length() > 2.0:
				_fail("the way from %s ends at %s, not in the house" % [spot, last])
	# Rooms of the house and the works that must be reached from the front door.
	for id in ["kitchen", "bath", "office", "study", "music", "bedroom", "pc", "storage", "pantry", "dogroom", "utility", "stube", "lager", "torbuero", "werkhalle"]:
		var room: Dictionary = (map.get("room_of") as Dictionary).get(id, {})
		if room.is_empty():
			_fail("no room " + id)
			continue
		var middle: Vector2 = (room.outer as Rect2).get_center()
		var route: PackedVector3Array = map.call("path_between", Vector3(7.5, 0, 14.0), Vector3(middle.x, 0, middle.y))
		if route.size() < 2:
			_fail("the room %s cannot be reached from the front door" % id)
	# Let the night run: the first rounds, the infected on their way, the survivor kept
	# alive (this is about the map, not about the fight).
	var player: Node3D = game.player
	var seen := 0
	var nearest := INF
	for frame in range(60 * 75):
		player.set("health", 100.0)
		# (A round begins when somebody holds F; here it begins at once.)
		if game.call("can_start_wave"):
			game.call("begin_wave")
		await process_frame
		var alive := 0
		for node in game.get_tree().get_nodes_in_group("infected"):
			var body := node as Node3D
			alive += 1
			nearest = minf(nearest, body.global_position.distance_to(player.global_position))
		seen = maxi(seen, alive)
	print("after 75 s: round %d, phase %s, most infected at once %d, nearest came to %.1f m" % [game.wave, game.phase, seen, nearest])
	if game.wave < 1:
		_fail("no round began")
	if seen == 0:
		_fail("no infected came")
	elif nearest > 25.0:
		_fail("the infected did not come near the house (nearest %.1f m)" % nearest)
	if failures.is_empty():
		print("APPENWEIER CHECK OK")
	game.return_to_menu()
	await process_frame
	quit(0 if failures.is_empty() else 1)
