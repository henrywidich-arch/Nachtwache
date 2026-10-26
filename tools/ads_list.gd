extends SceneTree
## Lists the LED walls of the simulation hall (TokyoHall.ad_screens): programme, size, where.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	root.add_child(map)
	await process_frame
	var hall: TokyoHall = map.hall
	for s: Dictionary in hall.ad_screens:
		var size: Vector2 = s.size
		var at: Vector3 = (s.node as Node3D).global_position
		print("ADWALL %s %.1f x %.1f at %.0f %.0f %.0f" % [s.program, size.x, size.y, at.x, at.y, at.z])
	for e: Dictionary in hall.ad_views:
		print("ADVIEW %s %s %s" % [e.key, (e.view as SubViewport).size, "film" if e.has("film") else "live"])
	quit()
