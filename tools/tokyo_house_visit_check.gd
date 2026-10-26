extends SceneTree
## The test room's buttons before the landmark houses of the simulation hall
## (Sandbox.TOKYO_HOUSE + id, TokyoLandmarks.HOUSES): each one builds the map of the second
## mission with the hall and puts the survivor on the street before its house, looking at it.
##   Godot --headless --path . -s res://tools/tokyo_house_visit_check.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.start_run(true)
	await process_frame
	var faults: Array[String] = []
	for house: String in TokyoLandmarks.HOUSES:
		game.sandbox.visit(Sandbox.TOKYO_HOUSE + house)
		for i in range(20):
			await process_frame
		var map := game.cabin as HiveMap
		if map == null or not is_instance_valid(map.tokyo):
			faults.append("%s: no hall" % house)
			continue
		var stand: Vector3 = map.points.get("tokyo_lm_" + house, Vector3.INF)
		var lot: Rect2 = TokyoLandmarks.HOUSES[house].lot
		var middle := Vector3(lot.get_center().x, 0, lot.get_center().y) + map.tokyo.origin
		var ahead: Vector3 = -game.player.global_basis.z
		var to: Vector3 = middle - game.player.global_position
		to.y = 0.0
		if stand == Vector3.INF or game.player.global_position.distance_to(stand) > 2.0:
			faults.append("%s: stands at %s, not before the house" % [house, game.player.global_position])
		elif ahead.dot(to.normalized()) < 0.6:
			faults.append("%s: does not look at the house" % house)
		else:
			print("visit %s: at %s" % [house, game.player.global_position])
	print("TOKYO HOUSES %s" % ("OK" if faults.is_empty() else "FAILED: " + "; ".join(faults)))
	quit(0 if faults.is_empty() else 1)
