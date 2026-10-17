extends SceneTree
## Walks a body of a companion's size (Teammate: a capsule 0.3 m round, 1.75 m tall) up and
## down every flight of the map of mission two, along the way the path finder knows over
## it (HiveCore.stairs: from the landing below, over the steps, to the landing above), as a
## companion moves: straight at the next point, with nothing but its capsule to get it over
## an edge. Lines:
##   FLIGHT <index> <up|down> stuck at <point> (<k> of <n>) ...   it got no further
##   STAIRS flights=<n> walked=<n> stuck=<n>
##   Godot --headless --path <project> -s res://tools/stair_walk.gd [-- --hive-layout=all|<seed>|classic] [--assist]
## --assist: with the step-up of the companions (Teammate.step_up), to see what it mends.

const SPEED := 4.6
const GRAVITY := 22.0

func _initialize() -> void:
	create_timer(900.0).timeout.connect(func() -> void: quit(2))
	var map := HiveMap.new()
	map.night = HiveAreale.wanted_from_args()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	for id in map.areas:
		map.unlock(str(id), true)
	for door in map.doors:
		if str(door.kind) == "script":
			map.set_door(str(door.name), true, true)
	for name in map.areal_signs:
		map.set_port(str(name), true, true)
	await physics_frame
	await physics_frame
	var assist := "--assist" in OS.get_cmdline_user_args()
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1 | 4 | 16
	body.floor_snap_length = 0.3
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.88
	body.add_child(shape)
	root.add_child(body)
	var stuck := 0
	var walked := 0
	for index in range(map.stairs.size()):
		var stair: Dictionary = map.stairs[index]
		var points: PackedVector3Array = stair.points
		if points.size() < 2:
			continue
		for way in ["up", "down"]:
			var route := points.duplicate()
			if way == "down":
				route.reverse()
			walked += 1
			body.global_position = route[0] + Vector3(0, 0.05, 0)
			body.velocity = Vector3.ZERO
			var at := 1
			var still := 0.0
			var last := body.global_position
			var frames := 0
			while at < route.size() and frames < 60 * 30:
				await physics_frame
				frames += 1
				var to := route[at] - body.global_position
				var flat := Vector2(to.x, to.z)
				if flat.length() < 0.35:
					at += 1
					continue
				var dir := Vector3(flat.x, 0, flat.y).normalized()
				body.velocity.x = dir.x * SPEED
				body.velocity.z = dir.z * SPEED
				body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - GRAVITY / 60.0
				body.move_and_slide()
				if assist:
					Teammate.step_up(body, dir)
				if body.global_position.distance_to(last) > 0.25:
					last = body.global_position
					still = 0.0
				else:
					still += 1.0 / 60.0
				if still > 1.0:
					break
			if at < route.size():
				stuck += 1
				print("FLIGHT %d %s stuck at %s (%d of %d) foot=%s head=%s" % [index, way, str(body.global_position.snapped(Vector3.ONE * 0.01)), at, route.size(), str((stair.foot as Vector3).snapped(Vector3.ONE * 0.1)), str((stair.head as Vector3).snapped(Vector3.ONE * 0.1))])
	print("STAIRS flights=%d walked=%d stuck=%d" % [map.stairs.size(), walked, stuck])
	quit(0 if stuck == 0 else 1)
