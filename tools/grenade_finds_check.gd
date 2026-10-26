extends SceneTree
## The crates of throwables (GrenadeFinds): on the farm one comes with the second round and
## can be walked to and taken; in the second mission the night has its crates, and one
## appears when the survivor comes near its place.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/grenade_finds_check.gd

var game: Node3D
var faults: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _crates() -> Array:
	return game.pickups.get_children().filter(func(crate: Node) -> bool: return crate.get_meta("kind") == GrenadeFinds.KIND)

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.profile.mission = 1
	game.team_enabled = false
	game.start_run()
	await physics_frame
	game.begin_wave()
	if not _crates().is_empty():
		faults.append("a crate in the first round")
	game.complete_wave()
	game.begin_wave()
	var crates := _crates()
	if crates.size() != 1:
		faults.append("round %d brought %d crates, not one" % [game.wave, crates.size()])
	else:
		var crate: Node3D = crates[0]
		var lies: Vector3 = crate.global_position
		if game.cabin.path_between(game.cabin.player_start, crate.global_position).size() < 2:
			faults.append("the crate at %s cannot be walked to" % crate.global_position)
		var before: int = int(game.player.items["grenade"])
		# The throwable it holds glows on it, and it is the one it gives.
		var extra: String = GrenadeFinds.extra_of(int(crate.get_meta("id")))
		if str(crate.get_meta("extra", "")) != extra or crate.get_node_or_null("Highlight") == null:
			faults.append("the crate holds %s but shows %s" % [extra, crate.get_meta("extra", "nothing")])
		var extra_before: int = int(game.player.items[extra])
		game.player.global_position = crate.global_position + Vector3(0, 0.05, 0)
		for i in range(10):
			await process_frame
		if int(game.player.items["grenade"]) != before + 1 or not _crates().is_empty():
			faults.append("walking over the crate gave %d grenades (had %d), %d crates left" % [int(game.player.items["grenade"]), before, _crates().size()])
		elif int(game.player.items[extra]) != extra_before + 1:
			faults.append("the crate showed %s but gave %d of it (had %d)" % [extra, int(game.player.items[extra]), extra_before])
		elif float(game.hud.gain_left.get("grenade", 0.0)) <= 0.0 or float(game.hud.gain_left.get(extra, 0.0)) <= 0.0 or not (game.hud.tiles[extra][3] as Label).visible:
			faults.append("the HUD did not light up grenade and %s after the crate" % extra)
		else:
			print("farm: crate at %s taken, grenades %d -> %d, %s %d -> %d" % [lies, before, int(game.player.items["grenade"]), extra, extra_before, int(game.player.items[extra])])
	# The single finds of the second mission lie in the same crate, their throwable lit on it.
	for kind: String in HiveFinds.KINDS:
		var find := HiveFinds.build(kind)
		var lit: bool = not GrenadeFinds.SPOTS.has(kind) or (find.get_node_or_null("Highlight") != null and str(find.get_meta("extra", "")) == kind)
		if find.get_node_or_null("Glint") == null or find.get_child_count() < 3 or not lit:
			faults.append("the find of %s is not the crate of throwables" % kind)
		find.free()
	game.return_to_menu()
	await process_frame
	game.profile.mission = 2
	game.hive.resume_at = "terminal"
	game.hive.tokyo_wanted = 1
	game.start_run()
	for i in range(30):
		await physics_frame
	var places: Array = game.finds.hidden.duplicate()
	var map: HiveMap = game.cabin
	var in_hall := 0
	for spot: Vector3 in places:
		if TokyoHall.plan_of(map.tokyo.origin).has_point(Vector2(spot.x, spot.z)):
			in_hall += 1
	print("hive: %d crates hidden, %d of them in the hall" % [places.size(), in_hall])
	if places.size() < 5 or in_hall < 1:
		faults.append("the night has %d crates, %d in the hall" % [places.size(), in_hall])
	if not places.is_empty():
		var spot: Vector3 = places[places.size() - 1]
		game.player.global_position = spot + Vector3(6, 0.05, 0)
		for i in range(10):
			await process_frame
		var near := _crates().filter(func(crate: Node3D) -> bool: return crate.global_position.distance_to(spot) < 1.0)
		if near.is_empty():
			faults.append("no crate appeared at %s when the survivor came near" % spot)
	if faults.is_empty():
		print("GRENADE FINDS OK")
	else:
		for fault in faults:
			print("FAULT: ", fault)
		print("GRENADE FINDS FAILED")
	quit(0 if faults.is_empty() else 1)
