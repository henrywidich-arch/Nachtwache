extends SceneTree
## Headless verification of the map on its own (no game scene needed):
##   Godot --headless --path <project> -s res://tools/map_check.gd > out.txt 2>&1
## Checks paths from every spawn to every room and station, classification functions,
## rays through windows/walls/railings, the lockable areas (upper floor, wing, cellar,
## containment room, tunnel) in every state the mission can bring them into, and
## physically walks capsules along path_between routes the way the infected do
## (re-planning twice a second).
## Optional user args after "--": --quick (skip the long walks), --scale=8 (time scale).

const BIG := {"radius": 0.5, "height": 2.0, "speed": 1.6, "tag": "big"}
const SMALL := {"radius": 0.3, "height": 1.75, "speed": 4.5, "tag": "small"}
const BODY_MASK := 1 | 16
## Named places in the basement, and those that are a device on a wall, not a place to stand.
const BASEMENT := ["lab_entry", "lab", "lab_glass", "nadja", "nadja_door", "nadja_hack", "tunnel_door", "tunnel_in"]
const MOUNTS := ["cellar_hack", "nadja_hack"]
## Named places behind the barrier of each lockable area.
const AREA_POINTS := {
	"upper": ["gallery", "upper_landing", "upper_west", "upper_east", "upper_northwest", "upper_northeast", "balcony", "stairs_top", "outer_stairs_top"],
	"wing": ["wing", "lounge", "side_door_in"],
	"cellar": ["lab_entry", "lab", "lab_glass", "nadja_door", "tunnel_door"],
	"lab_room": ["nadja"],
	"tunnel": ["tunnel_in"]
}
## A line through every barrier at chest height: blocked while its area is closed, clear
## once it is open. Heights are above the floor of the barrier's level.
const CROSSINGS := {
	"upper": [[Vector3(3.7, 1.0, -7.9), Vector3(2.3, 1.0, -7.9)], [Vector3(14.1, 1.0, -9.5), Vector3(14.1, 1.0, -8.0)]],
	"wing": [[Vector3(4.2, 1.0, 3.25), Vector3(5.8, 1.0, 3.25)], [Vector3(8.75, 1.0, -3.8), Vector3(8.75, 1.0, -2.2)], [Vector3(13.8, 1.0, -1.5), Vector3(12.2, 1.0, -1.5)]],
	"cellar": [[Vector3(-3.2, 1.0, -7.9), Vector3(-2.0, 0.7, -7.9)]],
	"lab_room": [[Vector3(-7.4, -2.6, -17.45), Vector3(-8.9, -2.6, -17.45)]],
	"tunnel": [[Vector3(0, -2.6, -24.4), Vector3(0, -2.6, -26.0)], [Vector3(-7.9, 1.0, -27.8), Vector3(-7.9, 1.0, -29.6)]]
}

var map: Node3D
var space: PhysicsDirectSpaceState3D
var failures := 0
var checks := 0
var walkers: Array = []
var random := RandomNumberGenerator.new()

## A capsule that follows path_between like an infected: steer to the next waypoint,
## count it as reached within 0.35 m, re-plan every half second, head straight for a
## goal that is close and in plain sight, and step aside when there is no headway.
## (The side step is the one of infected.gd. Without it a body that heads straight for
## a goal just behind a door jamb stops for good: CharacterBody3D does not slide along
## a wall it pushes into at less than 15 degrees, see wall_min_slide_angle.)
class Walker extends CharacterBody3D:
	var map: Node3D
	var route: Array = []
	var names: Array = []
	var leg := 1
	var speed := 1.6
	var label := ""
	var path := PackedVector3Array()
	var path_index := 0
	var repath_left := 0.0
	var leg_time := 0.0
	var leg_budget := 0.0
	var total_time := 0.0
	var done := false
	var failure := ""
	var anchor := Vector3.ZERO
	var anchor_time := 0.0
	var radius := 0.3
	var blocked_for := 0.0
	var dodge_left := 0.0
	var dodge_side := 1.0
	var dodges := 0

	func setup(spec: Dictionary) -> void:
		radius = spec.radius
		speed = spec.speed
		collision_layer = 0
		collision_mask = 1 | 16
		floor_snap_length = 0.3
		var capsule := CapsuleShape3D.new()
		capsule.radius = spec.radius
		capsule.height = spec.height
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		shape.position.y = float(spec.height) * 0.5
		add_child(shape)

	func _budget(target: Vector3) -> float:
		var way: PackedVector3Array = map.path_between(global_position, target)
		var length := 0.0
		for i in range(1, way.size()):
			length += way[i - 1].distance_to(way[i])
		return maxf(12.0, length / speed * 1.7 + 8.0)

	func _clear(target: Vector3) -> bool:
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, target + Vector3.UP * 1.1, 1 | 16)
		return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

	func _fail(reason: String) -> void:
		done = true
		var touching := ""
		for i in range(get_slide_collision_count()):
			var hit := get_slide_collision(i)
			touching += " hit(%s n=%s at %s)" % [str(hit.get_collider().name), str(hit.get_normal().snapped(Vector3.ONE * 0.01)), str(hit.get_position().snapped(Vector3.ONE * 0.01))]
		var next := "-"
		if path_index < path.size():
			next = str(path[path_index].snapped(Vector3.ONE * 0.01))
		failure = "%s: %s on the way to '%s' %s | stands at %s floor=%s path %d/%d next=%s%s" % [label, reason, names[leg], str((route[leg] as Vector3).snapped(Vector3.ONE * 0.01)), str(global_position.snapped(Vector3.ONE * 0.01)), str(is_on_floor()), path_index, path.size(), next, touching]

	func _physics_process(delta: float) -> void:
		if done:
			return
		total_time += delta
		leg_time += delta
		var target: Vector3 = route[leg]
		var offset := Vector2(target.x - global_position.x, target.z - global_position.z)
		var distance := offset.length()
		var same_floor := absf(target.y - global_position.y) < 1.4
		if distance < 0.6 and absf(target.y - global_position.y) < 0.7:
			leg += 1
			if leg >= route.size():
				done = true
				return
			leg_time = 0.0
			leg_budget = _budget(route[leg])
			repath_left = 0.0
			anchor = global_position
			anchor_time = 0.0
			return
		if leg_budget <= 0.0:
			leg_budget = _budget(target)
		if leg_time > leg_budget:
			_fail("did not arrive within %.0f s" % leg_budget)
			return
		# Barely moving for a long while means stuck.
		anchor_time += delta
		if anchor.distance_to(global_position) > 0.5:
			anchor = global_position
			anchor_time = 0.0
		elif anchor_time > 7.0:
			_fail("stuck for 7 s")
			return
		if global_position.y < map.CELLAR - 2.0:
			_fail("fell through the world")
			return
		repath_left -= delta
		if repath_left <= 0.0:
			path = map.path_between(global_position, target)
			path_index = 1 if path.size() > 1 else 0
			repath_left = 0.5
		var direction := Vector3.ZERO
		while path_index < path.size():
			var point := Vector2(path[path_index].x - global_position.x, path[path_index].z - global_position.z)
			if point.length() < 0.35:
				path_index += 1
			else:
				direction = Vector3(point.x, 0, point.y).normalized()
				break
		if distance > 0.05 and same_floor and (direction == Vector3.ZERO or (distance < 3.0 and _clear(target))):
			direction = Vector3(offset.x, 0, offset.y).normalized()
		# No headway: step to the side for a moment, like the infected.
		var moved := get_real_velocity()
		if Vector2(moved.x, moved.z).length() < speed * 0.25:
			blocked_for += delta
		else:
			blocked_for = 0.0
		dodge_left -= delta
		if blocked_for > 0.35 and dodge_left <= 0.0:
			blocked_for = 0.0
			dodge_left = 0.7
			dodge_side = -dodge_side
			dodges += 1
		if dodge_left > 0.0:
			direction = (direction + Vector3(-direction.z, 0, direction.x) * dodge_side * 1.5).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not is_on_floor():
			velocity.y -= delta * 22.0
		else:
			velocity.y = 0.0
		move_and_slide()

func _initialize() -> void:
	# A script run with -s that runs into an error never quits by itself.
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("MAP_CHECK_WATCHDOG: gave up after 15 minutes")
		quit(2))
	_run.call_deferred()

func expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + text)

func note(text: String) -> void:
	print(text)

func _has_arg(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()

func _run() -> void:
	random.seed = 4242
	var started := Time.get_ticks_msec()
	map = load("res://scripts/cabin.gd").new()
	map.name = "Waldposten"
	root.add_child(map)
	await process_frame
	note("map built in %d ms" % (Time.get_ticks_msec() - started))
	for i in range(3):
		await physics_frame
	space = root.get_world_3d().direct_space_state
	_check_interface()
	_check_classification()
	_check_paths()
	_check_rays()
	_check_new_places()
	_check_random_spots()
	_check_areas()
	await _check_animation()
	_time_paths()
	if not _has_arg("--quick"):
		await _check_bodies()
		await _check_walkers()
	print("MAP_CHECK_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- helpers

func point(name: String) -> Vector3:
	return map.points[name]

func ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask))

## True when a standing capsule of the given size fits at `pos` (feet on the floor there).
func fits(pos: Vector3, radius: float, height: float) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, height * 0.5 + 0.06, 0))
	query.collision_mask = BODY_MASK
	return space.intersect_shape(query, 1).is_empty()

func path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

## A usable path: starts near `from`, ends near `to` on the right floor, has no jumps.
func path_problem(from: Vector3, to: Vector3, path: PackedVector3Array, reach: float = 1.3) -> String:
	if path.is_empty():
		return "no path"
	var first := path[0]
	var last := path[path.size() - 1]
	if Vector2(first.x - from.x, first.z - from.z).length() > 1.6:
		return "starts %.1f m from its origin" % Vector2(first.x - from.x, first.z - from.z).length()
	if Vector2(last.x - to.x, last.z - to.z).length() > reach:
		return "ends %.1f m from its goal at %s" % [Vector2(last.x - to.x, last.z - to.z).length(), str(last)]
	if absf(last.y - to.y) > 0.9:
		return "ends on the wrong height %.1f" % last.y
	for i in range(1, path.size()):
		var step := Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
		if step > 0.75:
			return "jumps %.2f m at waypoint %d %s -> %s" % [step, i, str(path[i - 1]), str(path[i])]
		if absf(path[i].y - path[i - 1].y) > 0.45:
			return "height jumps at waypoint %d %s -> %s" % [i, str(path[i - 1]), str(path[i])]
	return ""

func uses_stair(path: PackedVector3Array, x_min: float, x_max: float) -> bool:
	for p in path:
		if p.y > 0.3 and p.y < map.STOREY - 0.3 and p.x >= x_min and p.x <= x_max:
			return true
	return false

## Whether a path goes down (or up) the cellar stairs in the house or the tunnel's stairs.
func uses_cellar_stairs(path: PackedVector3Array) -> bool:
	for p in path:
		if p.y < -0.3 and p.y > map.CELLAR + 0.3 and p.z > -9.5:
			return true
	return false

func uses_tunnel_stairs(path: PackedVector3Array) -> bool:
	for p in path:
		if p.y < -0.3 and p.y > map.CELLAR + 0.3 and p.z < -28.0:
			return true
	return false

# ---------------------------------------------------------------- static checks

func _check_interface() -> void:
	expect(map.has_signal("thunder"), "signal thunder exists")
	for method in ["path_between", "level_of", "level_height", "is_toxic", "is_indoors", "set_shop_open", "lettering", "nearest_cell", "lock_all", "unlock", "is_locked", "area_of", "set_beacon", "set_power", "set_gas"]:
		expect(map.has_method(method), "method %s exists" % method)
	expect(map.get_node_or_null("WeaponShopLabel") is Label3D, "WeaponShopLabel is a Label3D")
	expect(map.spawn_points.size() >= 12 and map.spawn_points.size() <= 14, "12-14 spawn points (%d)" % map.spawn_points.size())
	var kinds := {}
	for station in map.stations:
		kinds[station.kind] = int(kinds.get(station.kind, 0)) + 1
		expect(station.has("pos") and station.has("title") and station.has("kind"), "station has kind/title/pos")
	expect(kinds.get("ammo", 0) == 3 and kinds.get("health", 0) == 2 and kinds.get("upgrade", 0) == 1 and kinds.get("shop", 0) == 1, "3 ammo, 2 first aid, 1 workbench, 1 shop: %s" % str(kinds))
	expect(map.shop_view.has("position") and map.shop_view.has("target"), "shop_view has position and target")
	var needed := ["menu_camera", "menu_target", "hall", "lounge", "kitchen", "dining", "supply", "stair_hall", "gallery", "upper_west", "upper_east", "balcony", "barn", "garage", "guest_cabin", "shed", "yard_south", "gas", "front_door_out", "front_door_in", "back_door_out", "back_door_in", "breach_out", "breach_in", "side_door_out", "side_door_in", "window_in", "window_out", "wall_in", "wall_out", "stairs_bottom", "stairs_top", "outer_stairs_bottom", "outer_stairs_top",
		"cellar_door", "cellar_hack", "lab_entry", "lab", "lab_glass", "nadja", "nadja_door", "nadja_hack", "tunnel_in", "tunnel_out", "landing", "antenna", "upper_gate", "outer_gate", "wing"]
	for name in needed:
		expect(map.points.has(name), "points has '%s'" % name)
	for name in ["cellar_hack", "nadja_hack", "nadja", "landing", "antenna"]:
		expect(map.facings.has(name) and map.facings[name] is float, "facings has a yaw for '%s'" % name)
	expect(map.AREAS == ["upper", "wing", "cellar", "lab_room", "tunnel"], "AREAS names the five lockable areas")
	expect(map.navigation.size() == 3 and map.obstacles.size() == 3, "three navigation levels: ground, upper floor, basement")
	expect(map.level_height(0) == 0.0 and map.level_height(1) == map.STOREY and map.level_height(2) == map.CELLAR and map.CELLAR < -3.0, "level_height gives 0, STOREY and CELLAR (%.1f)" % map.CELLAR)
	for area in map.AREAS:
		expect(not map.is_locked(area) and map.locked.get(area) == false, "after _ready the area '%s' is open" % area)
	for spawn in map.spawn_points:
		expect(map.is_toxic(spawn), "spawn %s lies in the gas" % str(spawn))
		expect(fits(spawn, 0.5, 2.0), "spawn %s is free of obstacles" % str(spawn))
	expect(not map.is_toxic(map.player_start) and map.is_indoors(map.player_start) and fits(map.player_start, 0.32, 1.75), "player_start is a free spot inside the house")
	var open_seen: bool = map.shop_open
	map.set_shop_open(false, true)
	expect(open_seen and not map.shop_open and map.shop_label.text.contains("GESCHLOSSEN"), "set_shop_open closes the shop")
	map.set_shop_open(true, true)
	expect(map.stairs.size() == 4, "four flights of stairs: two up, two down (%d)" % map.stairs.size())
	for stair in map.stairs:
		var foot: Vector3 = stair.foot
		var head: Vector3 = stair.head
		var slope := rad_to_deg(atan2(head.y - foot.y, Vector2(head.x - foot.x, head.z - foot.z).length()))
		expect(slope <= 35.0, "stair slope %.1f deg is at most 35" % slope)
		for sample in stair.points:
			var above := ray(sample + Vector3(0, 0.3, 0), sample + Vector3(0, 2.6, 0), 1)
			expect(above.is_empty(), "2.6 m headroom on the stairs at %s" % str(sample))
		# Along the flight the body of the stairs carries a walker: something lies right below.
		for sample in stair.points:
			var below := ray(sample + Vector3(0, 0.5, 0), sample + Vector3(0, -0.6, 0), 1)
			expect(not below.is_empty() and absf(below.position.y - sample.y) < 0.25, "the stairs carry a body at %s" % str(sample))

func _check_classification() -> void:
	var indoors := ["hall", "lounge", "kitchen", "dining", "supply", "stair_hall", "gallery", "upper_west", "upper_east", "upper_landing", "barn", "garage", "guest_cabin", "shed", "front_door_in", "back_door_in", "breach_in", "side_door_in", "stairs_top", "cellar_door", "upper_gate", "wing"] + BASEMENT
	var outdoors := ["yard_south", "gas", "front_door_out", "back_door_out", "breach_out", "side_door_out", "balcony", "outer_stairs_bottom", "window_out", "wall_out", "porch", "tunnel_out", "landing", "antenna", "outer_gate"]
	for name in indoors:
		expect(map.is_indoors(point(name)), "is_indoors is true at " + name)
	for name in outdoors:
		expect(not map.is_indoors(point(name)), "is_indoors is false at " + name)
	var upstairs := ["gallery", "upper_west", "upper_east", "upper_landing", "balcony", "stairs_top", "outer_stairs_top", "upper_northwest", "upper_northeast"]
	for name in map.points:
		if name in ["menu_camera", "menu_target"]:
			continue
		var expected := 1 if name in upstairs else (2 if name in BASEMENT else 0)
		expect(map.level_of(point(name)) == expected, "level_of is %d at %s" % [expected, name])
		expect(absf(point(name).y - map.level_height(expected)) < 0.001, "%s lies at the height of its floor" % name)
		expect(map.is_toxic(point(name)) == (name == "gas"), "is_toxic is right at " + name)
	expect(map.level_of(Vector3(-4, 0, 3)) == 0 and map.level_of(Vector3(-4, 0.7, 3)) == 0, "the ground below the gallery is level 0, also in a jump")
	expect(map.level_of(Vector3(29, 2.6, -20)) == 0, "high up in the barn still counts as level 0")
	expect(map.level_of(point("lab") + Vector3(0, 0.8, 0)) == 2 and map.level_of(Vector3(0, 0, -19.5)) == 0, "a jump in the laboratory stays on level 2, the yard above it is level 0")
	expect(map.is_toxic(Vector3(0, 0, 51)) and map.is_toxic(Vector3(47, 0, 0)) and map.is_toxic(Vector3(-47, 0, 0)) and map.is_toxic(Vector3(0, 0, -43)), "beyond every fence it is toxic")
	expect(not map.is_toxic(Vector3(42, 0, 46)) and not map.is_toxic(Vector3(-42, 0, -38)), "the corners of the yard are safe")
	# Gas that drifts over the north yard does not reach the laboratory below it.
	map.set_gas("north")
	expect(map.is_toxic(Vector3(0, 0, -19.5)) and map.is_toxic(point("tunnel_out")), "drifting gas lies over the north yard")
	for name in BASEMENT:
		expect(not map.is_toxic(point(name)), "no gas at %s while it drifts over the yard above" % name)
	expect(not map.is_toxic(Vector3(-7.9, 0, -30.0)), "the bunker over the tunnel stairs keeps the gas out")
	map.set_gas("")
	# area_of names the area of every place behind a barrier, locked or not.
	for area in AREA_POINTS:
		for name in AREA_POINTS[area]:
			expect(map.area_of(point(name)) == area, "area_of is '%s' at %s (%s)" % [area, name, map.area_of(point(name))])
	for name in ["hall", "kitchen", "dining", "supply", "stair_hall", "shop", "barn", "yard_south", "tunnel_out", "landing", "antenna", "cellar_door", "upper_gate", "outer_gate", "side_door_out", "stairs_bottom", "outer_stairs_bottom"]:
		expect(map.area_of(point(name)) == "", "area_of is empty at %s (%s)" % [name, map.area_of(point(name))])
	var on_stairs := {0: "upper", 1: "upper", 2: "cellar", 3: "tunnel"}
	for index in on_stairs:
		var samples: PackedVector3Array = map.stairs[index].points
		expect(map.area_of(samples[samples.size() / 2]) == on_stairs[index], "area_of is '%s' on flight %d" % [on_stairs[index], index])
	expect(map.area_of(Vector3(-7.9, 0, -30.0)) == "tunnel", "the inside of the bunker belongs to the tunnel")

func _check_paths() -> void:
	var targets := {}
	for name in map.points:
		if name in ["menu_camera", "menu_target", "gas", "window_out", "wall_out", "wall_in"]:
			continue
		targets[name] = point(name)
	var count := 0
	for spawn in map.spawn_points:
		for name in targets:
			var path: PackedVector3Array = map.path_between(spawn, targets[name])
			var problem := path_problem(spawn, targets[name], path)
			expect(problem == "", "path from spawn %s to %s: %s" % [str(spawn), name, problem])
			count += 1
		for station in map.stations:
			var path: PackedVector3Array = map.path_between(spawn, station.pos)
			var problem := path_problem(spawn, station.pos, path, 2.0)
			expect(problem == "", "path from spawn %s to station %s at %s: %s" % [str(spawn), station.kind, str(station.pos), problem])
			count += 1
	note("checked %d spawn paths" % count)
	# Between all named places, in both directions.
	var names: Array = targets.keys()
	for a in names:
		for b in names:
			if a == b:
				continue
			var problem := path_problem(targets[a], targets[b], map.path_between(targets[a], targets[b]))
			expect(problem == "", "path %s -> %s: %s" % [a, b, problem])
	# Every named place is itself a free navigation spot: a path ends right on it. (A device
	# on a wall is not; the way to it ends on the nearest free cell in front of it.)
	for name in names:
		var arrival: PackedVector3Array = map.path_between(point("yard_south") if name != "yard_south" else point("hall"), targets[name])
		var miss := 9.0
		if not arrival.is_empty():
			miss = Vector2(arrival[arrival.size() - 1].x - targets[name].x, arrival[arrival.size() - 1].z - targets[name].z).length()
		if name in MOUNTS:
			expect(miss < 1.0, "the device at %s can be walked up to (path ends %.2f m away)" % [name, miss])
			continue
		expect(miss < 0.36, "the named place %s lies on a free navigation cell (path ends %.2f m away)" % [name, miss])
		var level: int = map.level_of(targets[name])
		var cell: Vector2i = map.nearest_cell(targets[name], level)
		expect(not map.navigation[level].is_point_solid(cell) and Vector2(cell.x * map.CELL - targets[name].x, cell.y * map.CELL - targets[name].z).length() < 0.36, "%s lies on a free cell of level %d" % [name, level])
	# The shorter staircase is taken.
	var inner_x := [-2.5, 3.1]
	var outer_x := [13.0, 15.2]
	expect(uses_stair(map.path_between(point("stair_hall"), point("upper_landing")), inner_x[0], inner_x[1]), "stair hall -> landing takes the interior stairs")
	expect(uses_stair(map.path_between(point("outer_stairs_bottom"), point("balcony")), outer_x[0], outer_x[1]), "yard -> balcony takes the outside stairs")
	expect(uses_stair(map.path_between(point("balcony"), point("side_door_out")), outer_x[0], outer_x[1]), "balcony -> side door takes the outside stairs down")
	expect(uses_stair(map.path_between(point("upper_west"), point("kitchen")), inner_x[0], inner_x[1]), "upper west -> kitchen takes the interior stairs down")
	# Down into the basement: by the cellar stairs from the house, by the tunnel from the north yard.
	var down: PackedVector3Array = map.path_between(point("hall"), point("lab"))
	expect(uses_cellar_stairs(down) and not uses_tunnel_stairs(down), "hall -> laboratory takes the cellar stairs")
	var lowest := 0.0
	var steps := 0
	var falling := true
	for i in range(down.size()):
		lowest = minf(lowest, down[i].y)
		if down[i].y < -0.05 and down[i].y > map.CELLAR + 0.05:
			steps += 1
		if i > 0 and down[i].y > down[i - 1].y + 0.001:
			falling = false
	expect(absf(lowest - map.CELLAR) < 0.001 and steps >= 8 and falling and absf(down[down.size() - 1].y - map.CELLAR) < 0.001, "the heights on the cellar stairs go down step by step to CELLAR (%d waypoints on the flight, lowest %.2f)" % [steps, lowest])
	var around: PackedVector3Array = map.path_between(point("tunnel_out"), point("tunnel_in"))
	expect(uses_tunnel_stairs(around) and not uses_cellar_stairs(around), "bunker -> tunnel takes the tunnel's stairs")
	expect(uses_tunnel_stairs(map.path_between(map.spawn_points[1], point("lab"))), "from the north spawn the shorter way into the laboratory is the tunnel")
	# Basement <-> upper floor leads over the ground floor.
	for pair in [["lab", "upper_west"], ["nadja", "balcony"], ["upper_east", "tunnel_in"], ["gallery", "lab_entry"]]:
		var path: PackedVector3Array = map.path_between(point(pair[0]), point(pair[1]))
		var ground := false
		for p in path:
			if absf(p.y) < 0.001:
				ground = true
		expect(path_problem(point(pair[0]), point(pair[1]), path) == "" and ground, "%s -> %s leads over the ground floor" % [pair[0], pair[1]])
	# From the middle of each staircase, and from the ground right below the gallery.
	for stair in map.stairs:
		var samples: PackedVector3Array = stair.points
		var middle := samples[samples.size() / 2]
		for name in ["hall", "upper_east", "yard_south", "upper_west", "balcony", "lab", "tunnel_in"]:
			var path: PackedVector3Array = map.path_between(middle, point(name))
			var problem := path_problem(middle, point(name), path)
			expect(problem == "", "path from the middle of a staircase %s to %s: %s" % [str(middle), name, problem])
		var back: PackedVector3Array = map.path_between(point("hall"), middle)
		expect(path_problem(point("hall"), middle, back) == "", "path from the hall onto the middle of a staircase %s: %s" % [str(middle), path_problem(point("hall"), middle, back)])
		var along: PackedVector3Array = map.path_between(samples[1], samples[samples.size() - 2])
		expect(along.size() == samples.size() - 2, "path along the flight at %s stays on it (%d of %d waypoints)" % [str(middle), along.size(), samples.size() - 2])
	var below := Vector3(-4, 0, 3)
	var up: PackedVector3Array = map.path_between(below, point("gallery"))
	expect(path_problem(below, point("gallery"), up) == "" and path_length(up) > 10.0, "from the ground below the gallery the path goes round by the stairs (%.1f m)" % path_length(up))
	var jump: PackedVector3Array = map.path_between(point("gallery") + Vector3(1.6, 0, 0), point("hall"))
	expect(path_problem(point("gallery") + Vector3(1.6, 0, 0), point("hall"), jump, 1.3) == "", "from above the open hall a path still leads down")

func _check_rays() -> void:
	var eye := Vector3(0, 1.5, 0)
	expect(ray(point("window_in") + eye, point("window_out") + eye, 1).is_empty(), "the window pair is clear for bullets (layer 1)")
	expect(not ray(point("window_in") + eye, point("window_out") + eye, 16).is_empty(), "the window opening stops bodies (layer 16)")
	expect(not ray(point("wall_in") + eye, point("wall_out") + eye, 1).is_empty(), "the wall pair is blocked")
	expect(point("wall_in").distance_to(point("wall_out")) < 1.3 and fits(point("wall_in"), 0.32, 1.75) and fits(point("wall_out"), 0.32, 1.75), "both sides of the wall pair are free standing spots about 1.1 m apart")
	expect(fits(point("window_in"), 0.32, 1.75) and fits(point("window_out"), 0.32, 1.75), "both ends of the window pair are free standing spots")
	var chest := Vector3(0, 0.6, 0)
	var gallery := point("gallery")
	expect(ray(gallery + chest, gallery + chest + Vector3(2.2, 0, 0), 1).is_empty(), "a shot passes the gallery railing")
	expect(not ray(gallery + chest, gallery + chest + Vector3(2.2, 0, 0), 16).is_empty(), "the gallery railing stops a body")
	var balcony := point("balcony")
	expect(ray(balcony + chest, balcony + chest + Vector3(2.5, 0, 0), 1).is_empty() and not ray(balcony + chest, balcony + chest + Vector3(2.5, 0, 0), 16).is_empty(), "the balcony railing stops bodies but not shots")
	var rail_top := ray(gallery + Vector3(1.0, 1.6, 0), gallery + Vector3(1.0, 0.1, 0), 16)
	expect(not rail_top.is_empty() and rail_top.position.y - gallery.y >= 1.05, "the gallery railing is at least 1.05 m high (%.2f)" % (rail_top.position.y - gallery.y if not rail_top.is_empty() else 0.0))
	# Doors and archways: clear to 2.3 m, at least 1.6 m wide.
	var doors := {"front door": [Vector3(0, 0, 9), Vector3(1, 0, 0)], "back door": [Vector3(-3.5, 0, -9), Vector3(1, 0, 0)], "breach": [Vector3(-13, 0, -4.75), Vector3(0, 0, 1)], "side door": [Vector3(13, 0, -1.5), Vector3(0, 0, 1)], "balcony door": [Vector3(13, map.STOREY, -1.0), Vector3(0, 0, 1)], "barn south": [Vector3(29, 0, -12), Vector3(1, 0, 0)], "barn north": [Vector3(29, 0, -28), Vector3(1, 0, 0)], "barn side": [Vector3(23, 0, -20), Vector3(0, 0, 1)], "garage side": [Vector3(-26, 0, -22.5), Vector3(0, 0, 1)], "guest east": [Vector3(-26, 0, 23.5), Vector3(0, 0, 1)], "guest north": [Vector3(-31.5, 0, 20), Vector3(1, 0, 0)], "shed": [Vector3(27.5, 0, 22), Vector3(1, 0, 0)],
		"security door of the cellar": [Vector3(-2.5, 0, -7.9), Vector3(0, 0, 1)], "doorway into the laboratory": [Vector3(4.5, map.CELLAR, -13.8), Vector3(1, 0, 0)], "door of the containment room": [Vector3(-8.15, map.CELLAR, -17.45), Vector3(0, 0, 1)], "blast door of the tunnel": [Vector3(0, map.CELLAR, -25.2), Vector3(1, 0, 0)], "door of the bunker": [Vector3(-7.9, 0, -28.7), Vector3(1, 0, 0)]}
	for name in doors:
		var centre: Vector3 = doors[name][0]
		var across: Vector3 = doors[name][1]
		var clear := true
		for offset in [-0.78, 0.0, 0.78]:
			if not ray(centre + across * offset + Vector3(0, 0.15, 0), centre + across * offset + Vector3(0, 2.3, 0), BODY_MASK).is_empty():
				clear = false
		expect(clear, "%s is at least 1.6 m wide and 2.3 m high" % name)
	# Every station can be used from a free standing spot within 2.1 m.
	for station in map.stations:
		var pos: Vector3 = station.pos
		var usable := false
		for angle in range(0, 360, 15):
			var stand := pos + Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * 1.5
			if fits(stand, 0.32, 1.75) and not map.path_between(point("yard_south"), stand).is_empty():
				usable = true
		expect(usable, "station %s at %s has a free spot within reach" % [station.kind, str(pos)])

## The places added for the Helix story.
func _check_new_places() -> void:
	var cellar: float = map.CELLAR
	# --- the basement is closed all round: floor below, ceiling above, and the yard on top of it carries.
	for name in BASEMENT:
		if name in MOUNTS:
			continue
		var pos := point(name)
		expect(fits(pos, 0.32, 1.75), "%s is a free standing spot" % name)
		var floor_hit := ray(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -0.5, 0), 1)
		expect(not floor_hit.is_empty() and absf(floor_hit.position.y - cellar) < 0.02, "the floor of the basement lies at CELLAR below %s" % name)
		var roof := ray(pos + Vector3(0, 0.5, 0), pos + Vector3(0, 6.0, 0), 1)
		expect(not roof.is_empty() and roof.position.y - cellar > 2.5 and roof.position.y < -0.3, "a ceiling closes the basement above %s (%.2f m of headroom)" % [name, (roof.position.y - cellar) if not roof.is_empty() else 0.0])
		var yard := ray(Vector3(pos.x, 3.0, pos.z), Vector3(pos.x, -1.0, pos.z), 1)
		expect(not yard.is_empty() and yard.position.y > -0.01, "the ground above %s is closed" % name)
	for name in ["cellar_door", "tunnel_out", "landing", "antenna", "upper_gate", "outer_gate", "wing"]:
		expect(fits(point(name), 0.32, 1.75), "%s is a free standing spot" % name)
	# The ground only opens under the interior staircase and inside the bunker.
	var holes := 0
	for x in range(-43, 44, 2):
		for z in range(-39, 48, 2):
			if ray(Vector3(x + 0.25, 30.0, z + 0.25), Vector3(x + 0.25, -0.2, z + 0.25), 1).is_empty():
				holes += 1
	expect(holes == 0, "nowhere in the yard a hole shows in the ground (%d found)" % holes)
	expect(ray(Vector3(0.0, 0.3, -7.9), Vector3(0.0, -2.0, -7.9), 1).position.y < -1.0, "under the interior staircase the floor is open for the cellar stairs")
	# --- the bulletproof glass stops bodies and bullets; Nadja stands right behind it.
	var eye := Vector3(0, 1.5, 0)
	var pane := ray(point("lab_glass") + eye, point("nadja") + eye, 1)
	expect(not pane.is_empty() and absf(pane.position.x + 8.15) < 0.1, "a shot from the hall at Nadja's place stops at the glass (x %.2f)" % (pane.position.x if not pane.is_empty() else 0.0))
	expect(point("lab_glass").distance_to(point("nadja")) < 4.5 and absf(point("lab_glass").z - point("nadja").z) < 0.6, "lab_glass and nadja face each other through the glass")
	var facing: float = map.facings.nadja
	var look := Vector3(-sin(facing), 0, -cos(facing))
	expect(look.dot((point("lab_glass") - point("nadja")).normalized()) > 0.95, "Nadja's facing looks through the glass into the hall")
	# --- the two devices: on a wall, their front away from it, a place to stand in front.
	for name in MOUNTS:
		var pos := point(name) + Vector3(0, 1.15, 0)
		var yaw: float = map.facings[name]
		var front := Vector3(-sin(yaw), 0, -cos(yaw))
		var behind := ray(pos + front * 0.3, pos - front * 0.5, 1)
		expect(not behind.is_empty() and pos.distance_to(behind.position) < 0.2, "the device at %s hangs on a wall (%.2f m behind it)" % [name, pos.distance_to(behind.position) if not behind.is_empty() else 9.0])
		expect(ray(pos, pos + front * 1.0, BODY_MASK).is_empty() and fits(point(name) + front * 0.75, 0.32, 1.75), "there is room to stand in front of the device at %s" % name)
	expect(point("cellar_hack").distance_to(point("cellar_door")) < 2.4 and point("nadja_hack").distance_to(point("nadja_door")) < 2.4, "each device is within reach of the spot in front of its door")
	# --- the landing zone
	var landing := point("landing")
	var gap := landing.distance_to(point("front_door_out"))
	expect(gap >= 20.0 and gap <= 35.0, "the landing zone lies 20-35 m from the front door (%.1f m)" % gap)
	var clear := true
	for x in range(-16, 17):
		for z in range(-16, 17):
			var offset := Vector2(x, z) * 0.5
			if offset.length() <= 8.0 and map.navigation[0].is_point_solid(Vector2i(roundi(landing.x / 0.5) + x, roundi(landing.z / 0.5) + z)):
				clear = false
	expect(clear, "every navigation cell within 8 m of the landing zone is free")
	var column := CylinderShape3D.new()
	column.radius = 8.0
	column.height = 16.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = column
	query.transform = Transform3D(Basis.IDENTITY, landing + Vector3(0, 8.3, 0))
	query.collision_mask = BODY_MASK
	expect(space.intersect_shape(query, 1).is_empty(), "nothing solid stands within 8 m of the landing zone, up to 16 m high")
	expect((map.YARD as Rect2).grow(-8.0).has_point(Vector2(landing.x, landing.z)), "the landing zone keeps 8 m from the fence")
	var nose: float = map.facings.landing
	expect(Vector3(-sin(nose), 0, -cos(nose)).dot((point("front_door_out") - landing).normalized()) > 0.99, "the helicopter's nose points at the front door")
	expect(map.is_reserved(landing) and map.is_reserved(point("tunnel_out")) and map.is_reserved(point("antenna")) and not map.is_reserved(point("yard_south")), "is_reserved covers the landing zone, the bunker's door and the mast")
	# --- the radio mast
	var antenna := point("antenna")
	var turn: float = map.facings.antenna
	var ahead := Vector3(-sin(turn), 0, -cos(turn))
	var box := ray(antenna + Vector3(0, 1.0, 0), antenna + Vector3(0, 1.0, 0) + ahead * 2.0, 1)
	expect(not box.is_empty() and antenna.distance_to(box.position - Vector3(0, 1.0, 0)) < 1.4, "the control box of the mast stands right in front of points.antenna")
	expect(absf(float(map.MAST_HEIGHT) - 14.0) < 1.5, "the mast is about 14 m high")
	expect(not ray(antenna + Vector3(0, 1.0, 0), antenna + Vector3(4.5, 1.0, 0), 16).is_empty(), "the lattice of the mast stops bodies")
	expect(not map.beacon_on and not map.beacon_light.visible, "the beacon is off until set_beacon is called")
	map.set_beacon(true)
	expect(map.beacon_on and map.beacon_light.visible and map.beacon_light.global_position.y > 14.0, "set_beacon(true) lights the beacon on top of the mast")
	map.set_beacon(false)
	expect(not map.beacon_light.visible, "set_beacon(false) puts it out again")
	# --- the laboratory has its own power: a blackout of the farm leaves its lamps alone.
	var own := 0
	var farm := 0
	for entry in map.flickers:
		if entry.light in map.lab_parts:
			own += 1
			expect(not entry.wired, "a lamp of the laboratory at %s is not on the farm's circuit" % str((entry.light as Node3D).position))
		elif entry.wired:
			farm += 1
	expect(own >= 12 and farm >= 20, "the laboratory has its own lamps (%d), the farm keeps its wired ones (%d)" % [own, farm])
	var casting := 0
	for part in map.lab_parts:
		if part is Light3D and part.shadow_enabled:
			casting += 1
	expect(casting <= 3 and map.lab_shadow_lamps.size() == casting, "at most three lamps of the laboratory cast shadows (%d)" % casting)

## Random free spots everywhere a survivor can stand, for teammates that follow the
## player with path_between: every pair must be connected.
func _free_spots(amount: int) -> Array:
	var areas := [
		[Rect2(-13, -9, 26, 18), 0.0, 5], [Rect2(-13, -9, 26, 18), map.STOREY, 5], [Rect2(13.2, -3.2, 2.8, 4.8), map.STOREY, 1],
		[map.BARN, 0.0, 2], [map.GARAGE, 0.0, 1], [map.GUEST, 0.0, 1], [map.SHED, 0.0, 1], [Rect2(-44, -40, 88, 88), 0.0, 6],
		[map.LAB, map.CELLAR, 4], [map.LAB_ROOM, map.CELLAR, 1], [Rect2(3.55, -13.6, 1.9, 6.6), map.CELLAR, 1], [Rect2(-1.1, -31.1, 2.2, 5.7), map.CELLAR, 1]
	]
	var spots: Array = []
	var guard := 0
	while spots.size() < amount and guard < amount * 60:
		guard += 1
		var area: Array = areas[random.randi() % areas.size()]
		if random.randi() % 6 >= int(area[2]):
			continue
		var rect: Rect2 = area[0]
		var pos := Vector3(random.randf_range(rect.position.x, rect.end.x), area[1], random.randf_range(rect.position.y, rect.end.y))
		if not fits(pos, 0.3, 1.75):
			continue
		# It has to stand on something.
		var ground := ray(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -0.4, 0), 1)
		if ground.is_empty() or absf(ground.position.y - pos.y) > 0.05:
			continue
		spots.append(pos)
	return spots

func _check_random_spots() -> void:
	var spots := _free_spots(320)
	var bad := 0
	var hub := point("hall")
	var levels := [0, 0, 0]
	for spot in spots:
		levels[map.level_of(spot)] += 1
		var there: PackedVector3Array = map.path_between(hub, spot)
		var back: PackedVector3Array = map.path_between(spot, hub)
		var problem := path_problem(hub, spot, there, 1.0)
		if problem == "":
			problem = path_problem(spot, hub, back, 1.0)
		if problem == "" and there.size() > 0 and not ray(there[there.size() - 1] + Vector3(0, 0.4, 0), spot + Vector3(0, 0.4, 0), 1).is_empty():
			problem = "last waypoint %s is behind a wall" % str(there[there.size() - 1])
		if problem != "":
			bad += 1
			if bad <= 12:
				print("FAIL: random spot %s: %s" % [str(spot.snapped(Vector3.ONE * 0.01)), problem])
	checks += 1
	if bad > 0:
		failures += 1
	note("random free spots: %d tested (%d on the ground, %d upstairs, %d in the basement), %d with a path problem" % [spots.size(), levels[0], levels[1], levels[2], bad])
	expect(levels[2] >= 30, "enough random spots lie in the basement (%d)" % levels[2])
	for i in range(0, spots.size() - 1, 2):
		var problem := path_problem(spots[i], spots[i + 1], map.path_between(spots[i], spots[i + 1]), 1.0)
		expect(problem == "", "path between random spots %s and %s: %s" % [str((spots[i] as Vector3).snapped(Vector3.ONE * 0.1)), str((spots[i + 1] as Vector3).snapped(Vector3.ONE * 0.1)), problem])

# ---------------------------------------------------------------- lockable areas

## Which areas a walker can get into, as the locks stand: the basement has two ways in.
func _reachable_areas() -> Dictionary:
	var way_down: bool = not map.is_locked("cellar") or not map.is_locked("tunnel")
	return {"upper": not map.is_locked("upper"), "wing": not map.is_locked("wing"), "tunnel": not map.is_locked("tunnel"), "cellar": way_down, "lab_room": way_down and not map.is_locked("lab_room")}

## Everything the map promises about the present state of the locks.
func _check_state(title: String) -> void:
	var open := _reachable_areas()
	var origins: Array = [point("hall"), map.spawn_points[1], map.spawn_points[8], point("barn")]
	for area in AREA_POINTS:
		for name in AREA_POINTS[area]:
			var goal := point(name)
			for origin in origins:
				var path: PackedVector3Array = map.path_between(origin, goal)
				if open[area]:
					expect(path_problem(origin, goal, path) == "", "%s: a way leads from %s to %s: %s" % [title, str(origin), name, path_problem(origin, goal, path)])
				else:
					expect(path.is_empty(), "%s: no way leads from %s to %s (%d waypoints)" % [title, str(origin), name, path.size()])
			var back: PackedVector3Array = map.path_between(goal, point("hall"))
			expect(back.is_empty() != bool(open[area]), "%s: the way back from %s to the hall is %s" % [title, name, "open" if open[area] else "closed"])
	# Whatever is locked, the infected get from every gap in the fence to the survivors.
	for spawn in map.spawn_points:
		for name in ["hall", "kitchen", "supply", "shop", "dining", "stair_hall", "barn", "garage", "guest_cabin", "shed", "tunnel_out", "landing", "antenna", "cellar_door", "upper_gate", "outer_gate"]:
			var problem := path_problem(spawn, point(name), map.path_between(spawn, point(name)))
			expect(problem == "", "%s: spawn %s reaches %s: %s" % [title, str(spawn), name, problem])
		for station in map.stations:
			# A station in a part of the house that is closed cannot be reached, and need not be.
			var area: String = map.area_of(station.pos)
			if area != "" and map.is_locked(area):
				continue
			expect(path_problem(spawn, station.pos, map.path_between(spawn, station.pos), 2.0) == "", "%s: spawn %s reaches the station %s" % [title, str(spawn), station.kind])
	# The barriers stand while their area is locked, and are out of the way afterwards.
	for area in CROSSINGS:
		for line in CROSSINGS[area]:
			var hit := ray(line[0], line[1], 1)
			if map.is_locked(area):
				expect(not hit.is_empty(), "%s: a barrier of '%s' stands on the world layer between %s and %s" % [title, area, str(line[0]), str(line[1])])
			else:
				expect(ray(line[0], line[1], BODY_MASK).is_empty(), "%s: the way through '%s' is clear between %s and %s" % [title, area, str(line[0]), str(line[1])])
		for gate in map.gates[area]:
			expect((gate.body as StaticBody3D).collision_layer == (1 if map.is_locked(area) else 0), "%s: the collider of a barrier of '%s' is %s" % [title, area, "on" if map.is_locked(area) else "off"])
	# No free cell is left inside an area nobody can get into; an open area has all of its own.
	for area in map.AREAS:
		var free := 0
		for entry in map.area_cells[area]:
			if not map.navigation[int(entry[0])].is_point_solid(entry[1]):
				free += 1
		var total: int = map.area_cells[area].size()
		expect(total > 6 and free == (total if open[area] else 0), "%s: %d of the %d cells of '%s' are free" % [title, free, total, area])
	# nearest_cell never leads from outside into an area that is closed.
	var dice := RandomNumberGenerator.new()
	dice.seed = 99
	var wrong := 0
	var tried := 0
	var zones := [[Rect2(-14, -10, 30, 20), 0.0], [Rect2(-14, -10, 30, 20), map.STOREY], [Rect2(-14.5, -32.5, 24, 27), map.CELLAR], [Rect2(-12, -34, 14, 9), 0.0]]
	for i in range(700):
		var zone: Array = zones[i % zones.size()]
		var rect: Rect2 = zone[0]
		var pos := Vector3(dice.randf_range(rect.position.x, rect.end.x), zone[1], dice.randf_range(rect.position.y, rect.end.y))
		var own: String = map.area_of(pos)
		if own != "" and not open[own]:
			continue
		tried += 1
		var level: int = map.level_of(pos)
		var cell: Vector2i = map.nearest_cell(pos)
		var found: String = map.area_of(Vector3(cell.x * map.CELL, map.level_height(level), cell.y * map.CELL))
		if map.navigation[level].is_point_solid(cell) or (found != "" and not open[found]):
			# On a level that is closed altogether there is no free cell to return.
			if level != 0 and not open[["", "upper", "cellar"][level]]:
				continue
			wrong += 1
			if wrong <= 5:
				print("FAIL: %s: nearest_cell(%s) leads to %s in the closed area '%s'" % [title, str(pos.snapped(Vector3.ONE * 0.01)), str(cell), found])
	expect(wrong == 0 and tried > 200, "%s: nearest_cell never leads into a closed area (%d places tried, %d wrong)" % [title, tried, wrong])

func _check_areas() -> void:
	_check_state("everything open")
	map.lock_all()
	for area in map.AREAS:
		expect(map.is_locked(area) and map.locked[area] == true, "lock_all closes '%s'" % area)
	_check_state("everything locked")
	# A path that ends just outside a barrier does not slip through it.
	for name in ["cellar_door", "upper_gate", "outer_gate"]:
		expect(path_problem(point("yard_south"), point(name), map.path_between(point("yard_south"), point(name))) == "", "the spot in front of the barrier at %s stays reachable" % name)
	# Each area alone, from the closed state.
	for area in map.AREAS:
		map.lock_all()
		map.unlock(area, true)
		expect(not map.is_locked(area), "unlock('%s') opens it" % area)
		for other in map.AREAS:
			if other != area:
				expect(map.is_locked(other), "unlock('%s') leaves '%s' closed" % [area, other])
		_check_state("only '%s' open" % area)
		if area == "tunnel":
			var path: PackedVector3Array = map.path_between(point("hall"), point("lab"))
			expect(uses_tunnel_stairs(path) and not uses_cellar_stairs(path), "with only the tunnel open the way from the hall into the laboratory leads through the bunker")
			var stuck: PackedVector3Array = map.path_between(point("lab"), point("cellar_door"))
			expect(uses_tunnel_stairs(stuck) and not uses_cellar_stairs(stuck), "and the way back out as well: the security door is still shut")
			var samples: PackedVector3Array = map.stairs[2].points
			var middle := samples[samples.size() / 2]
			var out: PackedVector3Array = map.path_between(middle, point("hall"))
			expect(path_problem(middle, point("hall"), out) == "" and uses_tunnel_stairs(out), "from the middle of the cellar stairs the only way out is down and through the tunnel")
	# The order of the story: cellar, containment room, tunnel; then the house.
	map.lock_all()
	for area in ["cellar", "lab_room", "tunnel", "upper", "wing"]:
		map.unlock(area, true)
		_check_state("opened up to '%s'" % area)
	# Closing everything again brings the closed state back, however often it is called.
	map.lock_all()
	map.lock_all()
	_check_state("locked again")
	map.unlock("upper", true)
	map.unlock("upper", true)
	map.unlock("no such area")
	_check_state("'upper' opened twice")
	for area in map.AREAS:
		map.unlock(area, true)
	_check_state("everything open again")

## The barriers get out of the way within about 0.6 s; the navigation opens at once.
func _check_animation() -> void:
	map.lock_all()
	var shut := {}
	# (The doors down in the laboratory are hidden with it for as long as it is sealed.)
	for area in map.AREAS:
		for gate in map.gates[area]:
			var node: Node3D = gate.node
			shut[node] = node.transform
			expect((node.visible or node in map.lab_parts) and node.transform.is_equal_approx(gate.shut), "a barrier of '%s' stands in its closed place" % area)
	for area in map.AREAS:
		map.unlock(area)
	expect(not map.path_between(point("hall"), point("nadja")).is_empty() and not map.path_between(point("hall"), point("upper_west")).is_empty() and not map.path_between(point("hall"), point("wing")).is_empty(), "the navigation is open the moment unlock is called")
	await create_timer(0.3).timeout
	var moving := 0
	for node in shut:
		if not (node as Node3D).transform.is_equal_approx(shut[node]):
			moving += 1
	expect(moving == shut.size(), "0.3 s after unlock every barrier is on its way (%d of %d)" % [moving, shut.size()])
	await create_timer(0.6).timeout
	for area in map.AREAS:
		for gate in map.gates[area]:
			var node: Node3D = gate.node
			# (The doors in the hall of the laboratory are only drawn for a viewer below ground.)
			expect(node.transform.is_equal_approx(gate.open) and (node.visible != bool(gate.vanish) or node in map.hall_parts), "0.9 s after unlock a barrier of '%s' has %s" % [area, "vanished" if gate.vanish else "reached its open place"])
	# Locking in the middle of the movement puts everything back at once.
	map.lock_all()
	map.unlock("upper")
	map.unlock("cellar")
	await create_timer(0.2).timeout
	map.lock_all()
	await create_timer(0.7).timeout
	var back := true
	for node in shut:
		if not ((node as Node3D).visible or node in map.lab_parts) or not (node as Node3D).transform.is_equal_approx(shut[node]):
			back = false
	expect(back and map.path_between(point("hall"), point("upper_west")).is_empty(), "lock_all in the middle of an opening puts every barrier back")
	# The lamps on the doors show the state.
	var red := 0
	for area in map.gate_lamps:
		for entry in map.gate_lamps[area]:
			if (entry.light as OmniLight3D).light_color.r > (entry.light as OmniLight3D).light_color.g:
				red += 1
	map.unlock("cellar", true)
	var green := 0
	for entry in map.gate_lamps["cellar"]:
		if (entry.light as OmniLight3D).light_color.g > (entry.light as OmniLight3D).light_color.r:
			green += 1
	expect(red >= 5 and green == map.gate_lamps["cellar"].size() and green >= 1, "door lamps are red while sealed (%d) and green once open (%d at the cellar door)" % [red, green])
	# The basement is only shown while there is a way into it, and the hall of the
	# laboratory only to a viewer who is below ground. Down there the weather is gone.
	var eye := Camera3D.new()
	root.add_child(eye)
	eye.current = true
	eye.global_position = point("yard_south") + Vector3(0, 1.6, 0)
	map.lock_all()
	await process_frame
	await process_frame
	var hidden := true
	for part in map.lab_parts:
		if (part as Node3D).visible:
			hidden = false
	map.unlock("tunnel", true)
	var shown := 0
	var hall_shown := 0
	for part in map.lab_parts:
		if (part as Node3D).visible:
			shown += 1
			if part in map.hall_parts:
				hall_shown += 1
	expect(hidden and hall_shown == 0 and shown == map.lab_parts.size() - map.hall_parts.size() and map.hall_parts.size() > 10, "the basement is hidden while sealed; once a way in is open its stairs and passages show (%d parts), the hall not yet (%d parts)" % [shown, map.hall_parts.size()])
	expect(map.below == 0.0 and map.rain.visible, "above ground the rain falls")
	eye.global_position = point("lab") + Vector3(0, 1.6, 0)
	await process_frame
	await process_frame
	hall_shown = 0
	for part in map.hall_parts:
		if (part as Node3D).visible:
			hall_shown += 1
	expect(map.below == 1.0 and hall_shown == map.hall_parts.size() and not map.rain.visible, "below ground the hall is shown and the rain is gone (%d of %d parts)" % [hall_shown, map.hall_parts.size()])
	var density: float = map.environment.fog_density
	map.flash_left = 0.5
	await process_frame
	expect(is_equal_approx(map.moon.light_energy, map.MOONLIGHT) and is_equal_approx(map.environment.background_energy_multiplier, 1.0) and density < 0.012, "lightning does not flash below ground, and the night's haze is thin there")
	expect(map.environment.ambient_light_energy < 0.2 and map.environment.ambient_light_color.is_equal_approx(map.CELLAR_AMBIENT), "the blue light of the night sky does not reach below ground")
	map.lock_all()
	hall_shown = 0
	for part in map.lab_parts:
		if (part as Node3D).visible:
			hall_shown += 1
	expect(hall_shown == 0, "locking everything hides the basement even from a viewer inside it")
	eye.global_position = point("yard_south") + Vector3(0, 1.6, 0)
	await process_frame
	await process_frame
	expect(map.below == 0.0 and map.rain.visible and is_equal_approx(map.environment.fog_density, 0.024) and is_equal_approx(map.environment.ambient_light_energy, 0.3) and map.environment.ambient_light_color.is_equal_approx(map.NIGHT_AMBIENT), "back above ground the weather and the light are as they were")
	map.flash_left = 0.0
	eye.queue_free()
	for area in map.AREAS:
		map.unlock(area, true)

func _time_paths() -> void:
	var cases := {"spawn -> hall": ["", "hall"], "spawn -> upper west": ["", "upper_west"], "spawn -> barn": ["", "barn"], "spawn -> laboratory": ["", "lab"], "upper west -> Nadja": ["upper_west", "nadja"]}
	for title in cases:
		var started := Time.get_ticks_usec()
		for i in range(140):
			var from: Vector3 = map.spawn_points[i % map.spawn_points.size()] if cases[title][0] == "" else point(cases[title][0]) + Vector3((i % 5) * 0.4, 0, 0)
			map.path_between(from, point(cases[title][1]))
		note("path timing %s: %.2f ms each" % [title, (Time.get_ticks_usec() - started) / 140000.0])
	var began := Time.get_ticks_usec()
	for i in range(10):
		map.lock_all()
		for area in map.AREAS:
			map.unlock(area, true)
	note("lock_all plus five unlocks: %.2f ms" % ((Time.get_ticks_usec() - began) / 10000.0))

# ---------------------------------------------------------------- physical checks

func _spawn(spec: Dictionary, names: Array, title: String) -> Walker:
	var walker := Walker.new()
	walker.map = map
	walker.setup(spec)
	walker.names = names
	for name in names:
		walker.route.append(name if name is Vector3 else point(name))
	walker.label = "%s %s" % [spec.tag, title]
	root.add_child(walker)
	walker.global_position = (walker.route[0] as Vector3) + Vector3(0, 0.1, 0)
	walkers.append(walker)
	return walker

## Bodies dropped at every named place come to rest on its floor, and neither a window,
## a railing, a fence, the bulletproof glass nor a barrier lets a body through.
func _check_bodies() -> void:
	var bodies := {}
	for name in map.points:
		if name in ["menu_camera", "menu_target"] or name in MOUNTS:
			continue
		var body := Walker.new()
		body.map = map
		body.setup(SMALL)
		body.done = true
		root.add_child(body)
		body.global_position = point(name) + Vector3(0, 0.3, 0)
		bodies[name] = body
	var pushes := {
		"through a window": [point("window_in"), Vector3(-1, 0, 0), 3.5],
		"over the gallery railing": [point("gallery"), Vector3(1, 0, 0), 3.5],
		"over the balcony railing": [point("balcony"), Vector3(1, 0, 0), 3.5],
		"through the yard fence": [Vector3(-42.0, 0, 15.0), Vector3(-1, 0, 0), 4.0],
		"over the stair rail": [point("stairs_bottom") + Vector3(-2.0, 0.9, 0.3), Vector3(0, 0, 1), 3.0],
		"through the bulletproof glass": [point("lab_glass"), Vector3(-1, 0, 0), 2.0],
		"into the lattice of the mast": [point("antenna") + Vector3(0, 0, 0.9), Vector3(1, 0, 0), 2.4]
	}
	var pushed := {}
	for title in pushes:
		var body := Walker.new()
		body.map = map
		body.setup(SMALL)
		body.done = true
		root.add_child(body)
		body.global_position = (pushes[title][0] as Vector3) + Vector3(0, 0.1, 0)
		pushed[title] = body
	for frame in range(150):
		await physics_frame
		for name in bodies:
			var body: Walker = bodies[name]
			body.velocity = Vector3(0, body.velocity.y - 22.0 / 60.0 if not body.is_on_floor() else 0.0, 0)
			body.move_and_slide()
		for title in pushed:
			var body: Walker = pushed[title]
			var push: Vector3 = pushes[title][1]
			body.velocity = Vector3(push.x * 4.5, body.velocity.y - 22.0 / 60.0 if not body.is_on_floor() else 0.0, push.z * 4.5)
			body.move_and_slide()
	for name in bodies:
		var body: Walker = bodies[name]
		expect(absf(body.global_position.y - point(name).y) < 0.06 and body.is_on_floor(), "a body rests on the floor at %s (y %.2f, expected %.2f)" % [name, body.global_position.y, point(name).y])
		body.queue_free()
	for title in pushed:
		var body: Walker = pushed[title]
		var start: Vector3 = pushes[title][0]
		var moved := Vector2(body.global_position.x - start.x, body.global_position.z - start.z).length()
		expect(moved < float(pushes[title][2]) and absf(body.global_position.y - start.y) < 1.0, "a body pushed %s is held back (moved %.2f m, y %.2f)" % [title, moved, body.global_position.y])
		body.queue_free()
	# Every barrier holds a body while its area is locked and lets it pass afterwards.
	var gates := {
		"upper": [[point("upper_gate"), Vector3(-1, 0, 0)], [point("outer_gate"), Vector3(0, 0, 1)]],
		"wing": [[Vector3(3.6, 0, 3.25), Vector3(1, 0, 0)], [Vector3(8.75, 0, -4.4), Vector3(0, 0, 1)], [Vector3(14.4, 0, -1.5), Vector3(-1, 0, 0)]],
		"cellar": [[point("cellar_door"), Vector3(1, 0, 0)]],
		"lab_room": [[point("nadja_door"), Vector3(-1, 0, 0)]],
		"tunnel": [[point("tunnel_door"), Vector3(0, 0, -1)], [point("tunnel_out"), Vector3(0, 0, -1)]]
	}
	for closed in [true, false]:
		if closed:
			map.lock_all()
		else:
			for area in map.AREAS:
				map.unlock(area, true)
		await physics_frame
		var runners: Array = []
		for area in gates:
			for gate in gates[area]:
				var body := Walker.new()
				body.map = map
				body.setup(SMALL)
				body.done = true
				root.add_child(body)
				body.global_position = (gate[0] as Vector3) + Vector3(0, 0.1, 0)
				runners.append([body, gate[0], gate[1], area])
		for frame in range(60):
			await physics_frame
			for runner in runners:
				var body: Walker = runner[0]
				var push: Vector3 = runner[2]
				body.velocity = Vector3(push.x * 3.0, body.velocity.y - 22.0 / 60.0 if not body.is_on_floor() else 0.0, push.z * 3.0)
				body.move_and_slide()
		for runner in runners:
			var body: Walker = runner[0]
			var start: Vector3 = runner[1]
			var moved := Vector2(body.global_position.x - start.x, body.global_position.z - start.z).length()
			if closed:
				expect(moved < 1.6, "a body pushed against a barrier of '%s' from %s is held back (moved %.2f m)" % [runner[3], str(start), moved])
			else:
				expect(moved > 2.0, "with '%s' open a body walks on from %s (moved %.2f m)" % [runner[3], str(start), moved])
			body.queue_free()

func _check_walkers() -> void:
	var scale := 8.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scale="):
			scale = float(arg.trim_prefix("--scale="))
	var tours := {
		"ground floor round": ["front_door_out", "front_door_in", "hall", "lounge", "supply", "stair_hall", "kitchen", "dining", "hall"],
		"back door, inner stairs, upper floor, outer stairs, side door": ["back_door_out", "back_door_in", "stair_hall", "stairs_bottom", "stairs_top", "upper_landing", "gallery", "upper_west", "upper_northwest", "upper_landing", "upper_northeast", "upper_east", "balcony", "outer_stairs_top", "outer_stairs_bottom", "side_door_out", "side_door_in", "lounge"],
		"breach to front door": ["breach_out", "breach_in", "kitchen", "hall", "front_door_in", "front_door_out", "yard_south"],
		"side door": ["side_door_out", "side_door_in", "hall"],
		"outer stairs up, inner stairs down": ["outer_stairs_bottom", "balcony", "upper_east", "gallery", "upper_west", "stairs_top", "stairs_bottom", "back_door_in", "back_door_out"],
		"yard to the far upper rooms and back": ["yard_south", "upper_northwest", "yard_south", "upper_northeast", "barn"],
		"all outbuildings": ["hall", "barn", "garage", "guest_cabin", "shed", "hall"],
		"upper rooms to the workshop and the cabin": ["upper_west", "garage", "upper_east", "guest_cabin", "gallery"],
		"down the cellar stairs, through the laboratory, out by the tunnel": ["hall", "cellar_door", "lab_entry", "lab", "nadja_door", "nadja", "lab_glass", "tunnel_door", "tunnel_in", "tunnel_out", "back_door_out"],
		"in by the bunker, up the cellar stairs to the upper floor": ["tunnel_out", "tunnel_in", "lab", "lab_entry", "cellar_door", "upper_gate", "upper_landing", "nadja"],
		"new places in the yard": ["front_door_out", "landing", "antenna", "outer_gate", "tunnel_out", "wing"]
	}
	for spec in [BIG, SMALL]:
		for title in tours:
			_spawn(spec, tours[title], title)
		for i in range(map.spawn_points.size()):
			var goal: String = ["hall", "upper_west", "upper_east", "supply", "kitchen", "gallery", "barn", "lab", "nadja", "lab_entry"][i % 10]
			_spawn(spec, [map.spawn_points[i], goal], "spawn %d to %s" % [i, goal])
	# Teammate-style walks between random free spots, with the small capsule.
	var spots := _free_spots(60)
	for i in range(0, spots.size() - 2, 3):
		_spawn(SMALL, [spots[i], spots[i + 1], spots[i + 2]], "random spots %s > %s > %s" % [str((spots[i] as Vector3).snapped(Vector3.ONE * 0.1)), str((spots[i + 1] as Vector3).snapped(Vector3.ONE * 0.1)), str((spots[i + 2] as Vector3).snapped(Vector3.ONE * 0.1))])
	note("walking %d capsules at time scale %.0f ..." % [walkers.size(), scale])
	Engine.time_scale = scale
	Engine.max_physics_steps_per_frame = 24
	var began := Time.get_ticks_msec()
	var running := walkers.size()
	while running > 0 and Time.get_ticks_msec() - began < 300000:
		await physics_frame
		running = 0
		for walker in walkers:
			if not walker.done:
				running += 1
	Engine.time_scale = 1.0
	var slowest := 0.0
	var side_steps := 0
	for walker in walkers:
		slowest = maxf(slowest, walker.total_time)
		side_steps += walker.dodges
		if walker.dodges >= 3:
			note("walker %s needed %d side steps" % [walker.label, walker.dodges])
		if not walker.done:
			walker._fail("still walking when the check ran out of time")
		expect(walker.failure == "", "walker " + walker.failure)
	note("walkers finished: %d, longest tour %.0f s of game time, %.0f s real, %d side steps in all" % [walkers.size(), slowest, (Time.get_ticks_msec() - began) / 1000.0, side_steps])
