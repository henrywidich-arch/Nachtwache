extends SceneTree
## Finds what one gets stuck on while walking a map: small things on the floor that are
## solid. It goes through every collider of the map of mission two (or of the farm with
## --farm) and lists
##   SNAG   those the rule of the builders calls small (CabinMap.snag_kind: low, thin or
##          small) and that are solid all the same - after the builders have had their
##          say there should be none, and the test run expects none;
##   HANG   where a body of the player's size, pushed from one free cell of the floor to
##          the next, is stopped by something the paths do not know of (a rim, a step, a
##          post without a place in the grid);
##   ELSEWHERE  small colliders that stand on no floor (a landing, a bridge, a table):
##          the rule does not judge them;
##   GONE   what the builders let go by that rule: things that kept their look and have
##          no collider;
##   KIND   with --kinds, every kind of solid thing that stands on a floor, by who built
##          it, with its sizes - to see what the rule keeps and what it lets go.
##   Godot --headless --path <project> -s res://tools/snag_check.gd [-- --farm --kinds --rule=old --list=60] > out.txt 2>&1
## --rule=old judges the colliders as if the builders had no rule (for a map built
## before it: what would go). The exit code is 1 if there is a SNAG.

const RADIUS := 0.32
const TALL := 1.75
## What a body gets over by itself: the round foot of its capsule.
const STEP := 0.1
const MASK := 1 | 16

class HiveSpy extends HiveMap:
	var made: Dictionary = {}
	var model_now := ""
	func _who(on_rails: bool) -> Array:
		var names: Array[String] = []
		var cap := false
		var stack: Array = get_stack()
		for index in range(stack.size()):
			var fn := str(stack[index].function)
			if fn == "_solid" and on_rails:
				cap = true
			if fn in ["_who", "_gone", "_add_shape", "_round_solid", "_solid", "_firm_solid", "_rail_solid", "_part_shape", "_model", "_prop", "_house_prop", "_against"]:
				continue
			names.append(fn if not names.is_empty() else "%s:%d" % [fn, int(stack[index].line)])
			if names.size() >= 2:
				break
		var tag := " < ".join(PackedStringArray(names))
		if model_now != "":
			tag = "model %s < %s" % [model_now.get_file().get_basename(), tag]
		return [tag, cap]
	func _add_shape(owner_body: StaticBody3D, center: Vector3, size: Vector3, orientation: Basis = Basis.IDENTITY) -> void:
		var before := owner_body.get_child_count()
		super._add_shape(owner_body, center, size, orientation)
		if owner_body.get_child_count() > before:
			made[owner_body.get_child(owner_body.get_child_count() - 1)] = _who(owner_body == rails)
	func _round_solid(base: Vector3, radius: float, height: float) -> void:
		var before := body.get_child_count()
		var let_go := _let_go()
		super._round_solid(base, radius, height)
		if body.get_child_count() > before:
			made[body.get_child(body.get_child_count() - 1)] = _who(false)
		elif _let_go() > let_go:
			_gone(Vector3(radius * 2.0, height, radius * 2.0), snag_kind(base + Vector3(0, height * 0.5, 0), Vector3(radius * 2.0, height, radius * 2.0)), base)
	func _solid(center: Vector3, size: Vector3, blocks_path: bool = true, yaw: float = 0.0) -> void:
		var let_go := _let_go()
		super._solid(center, size, blocks_path, yaw)
		if _let_go() > let_go:
			_gone(size, snag_kind(center, size), center)
	var gone: Dictionary = {}
	func _let_go() -> int:
		return int(snag_dropped.low) + int(snag_dropped.thin) + int(snag_dropped.small)
	func _gone(size: Vector3, kind: String, at: Vector3) -> void:
		var key := "%s  %s" % [kind, str(_who(false)[0])]
		if not gone.has(key):
			gone[key] = {"count": 0, "size": size, "at": at}
		gone[key].count += 1
	func _model(id: String, pos: Vector3, yaw: float = 0.0, options: Dictionary = {}) -> Node3D:
		var kept := model_now
		model_now = id
		var node := super._model(id, pos, yaw, options)
		model_now = kept
		return node

class FarmSpy extends CabinMap:
	var made: Dictionary = {}
	func _who(on_rails: bool) -> Array:
		var names: Array[String] = []
		var cap := false
		var stack: Array = get_stack()
		for index in range(stack.size()):
			var fn := str(stack[index].function)
			if fn == "_solid" and on_rails:
				cap = true
			if fn in ["_who", "_gone", "_add_shape", "_round_solid", "_solid", "_firm_solid", "_rail_solid", "_prop"]:
				continue
			names.append(fn if not names.is_empty() else "%s:%d" % [fn, int(stack[index].line)])
			if names.size() >= 2:
				break
		return [" < ".join(PackedStringArray(names)), cap]
	func _add_shape(owner_body: StaticBody3D, center: Vector3, size: Vector3, orientation: Basis = Basis.IDENTITY) -> void:
		var before := owner_body.get_child_count()
		super._add_shape(owner_body, center, size, orientation)
		if owner_body.get_child_count() > before:
			made[owner_body.get_child(owner_body.get_child_count() - 1)] = _who(owner_body == rails)
	func _round_solid(base: Vector3, radius: float, height: float) -> void:
		var before := body.get_child_count()
		var let_go := _let_go()
		super._round_solid(base, radius, height)
		if body.get_child_count() > before:
			made[body.get_child(body.get_child_count() - 1)] = _who(false)
		elif _let_go() > let_go:
			_gone(Vector3(radius * 2.0, height, radius * 2.0), snag_kind(base + Vector3(0, height * 0.5, 0), Vector3(radius * 2.0, height, radius * 2.0)), base)
	func _solid(center: Vector3, size: Vector3, blocks_path: bool = true, yaw: float = 0.0) -> void:
		var let_go := _let_go()
		super._solid(center, size, blocks_path, yaw)
		if _let_go() > let_go:
			_gone(size, snag_kind(center, size), center)
	var gone: Dictionary = {}
	func _let_go() -> int:
		return int(snag_dropped.low) + int(snag_dropped.thin) + int(snag_dropped.small)
	func _gone(size: Vector3, kind: String, at: Vector3) -> void:
		var key := "%s  %s" % [kind, str(_who(false)[0])]
		if not gone.has(key):
			gone[key] = {"count": 0, "size": size, "at": at}
		gone[key].count += 1

var map: CabinMap
var made: Dictionary = {}
var gone: Dictionary = {}

func _tag(shape: Node) -> String:
	if made.has(shape):
		return str(made[shape][0])
	return "(%s)" % shape.get_parent().name

func _initialize() -> void:
	var farm := false
	var kinds := false
	var old_rule := false
	var most := 60
	for arg in OS.get_cmdline_user_args():
		if arg == "--farm":
			farm = true
		elif arg == "--kinds":
			kinds = true
		elif arg == "--rule=old":
			old_rule = true
		elif arg.begins_with("--list="):
			most = int(arg.substr(7))
	# (A script that fails never quits by itself.)
	create_timer(280.0).timeout.connect(func() -> void: quit(2))
	if farm:
		var spy := FarmSpy.new()
		map = spy
		made = spy.made
		gone = spy.gone
	else:
		var spy := HiveSpy.new()
		map = spy
		made = spy.made
		gone = spy.gone
	# (--rule=old: built as before the rule, so that what it would let go is still there.)
	map.snag_rule = not old_rule
	root.add_child(map)
	if not farm:
		while not (map as HiveMap).build_times.has("all"):
			await process_frame
	for i in range(3):
		await physics_frame
	var space := root.get_world_3d().direct_space_state

	# --- every collider that stands on a floor, and what the rule says of it
	var doors := {}
	if not farm:
		for door in (map as HiveMap).doors:
			if door.shape != null:
				doors[door.shape] = true
	var snags: Array = map.snags()
	var by_kind := {}
	for entry in snags:
		var tag := _tag(entry.shape)
		var key := "%s  %s" % [entry.kind, tag]
		if not by_kind.has(key):
			by_kind[key] = {"count": 0, "open": 0, "first": entry}
		by_kind[key].count += 1
		if _in_the_open(entry):
			by_kind[key].open += 1
	var order: Array = by_kind.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return int(by_kind[a].count) > int(by_kind[b].count))
	print("SNAGS map=%s colliders=%d small_and_solid=%d kinds=%d rule=%s" % ["farm" if farm else "hive", _count_shapes(), snags.size(), order.size(), "old" if old_rule else "now"])
	for index in range(mini(most, order.size())):
		var group: Dictionary = by_kind[order[index]]
		var first: Dictionary = group.first
		var size: Vector3 = first.size
		print("  SNAG %3d (in the open %3d)  %-46s  %.2f x %.2f x %.2f  top %.2f over the floor  e.g. at %s" % [int(group.count), int(group.open), order[index], size.x, size.y, size.z, float(first.over), str((first.at as Vector3).snappedf(0.1))])

	# --- small colliders that stand on no floor of the map - on a landing, a bridge, the
	# deck of a tower, a table. The rule knows floors by their height and says nothing
	# of these: they are listed to be looked at.
	var on_floor := {}
	for entry in map.floor_solids():
		on_floor[entry.shape] = true
	var elsewhere := {}
	var elsewhere_count := 0
	for owner_body in [map.body, map.rails]:
		for child in owner_body.get_children():
			var node := child as CollisionShape3D
			if node == null or on_floor.has(node) or doors.has(node) or node.has_meta("firm"):
				continue
			if absf(node.transform.basis.y.y) < 0.999:
				continue
			var info := _shape_info(node)
			var size: Vector3 = info.size
			var wide := maxf(size.x, size.z)
			var narrow := minf(size.x, size.z)
			if not ((narrow <= 0.301 and wide <= 0.601) or (wide <= 0.701 and size.y <= 0.851) or (size.y < 0.59 and wide <= 1.701)):
				continue
			elsewhere_count += 1
			var key := "%s  %.2f x %.2f x %.2f" % [_tag(node), size.x, size.y, size.z]
			if not elsewhere.has(key):
				elsewhere[key] = {"count": 0, "at": node.transform.origin}
			elsewhere[key].count += 1
	var elsewhere_order: Array = elsewhere.keys()
	elsewhere_order.sort_custom(func(a: String, b: String) -> bool: return int(elsewhere[a].count) > int(elsewhere[b].count))
	print("ELSEWHERE %d small colliders of %d kinds stand on no floor of the map (not judged)" % [elsewhere_count, elsewhere_order.size()])
	for index in range(mini(most, elsewhere_order.size())):
		print("  ELSEWHERE %3d  %-70s  e.g. at %s" % [int(elsewhere[elsewhere_order[index]].count), elsewhere_order[index], str((elsewhere[elsewhere_order[index]].at as Vector3).snappedf(0.1))])
	# --- what the builders let go by the rule: a look without a collider
	var gone_order: Array = gone.keys()
	gone_order.sort_custom(func(a: String, b: String) -> bool: return int(gone[a].count) > int(gone[b].count))
	print("GONE low=%d thin=%d small=%d in %d kinds (things that kept their look and lost their collider)" % [int(map.snag_dropped.low), int(map.snag_dropped.thin), int(map.snag_dropped.small), gone_order.size()])
	for index in range(mini(most, gone_order.size())):
		var group: Dictionary = gone[gone_order[index]]
		var size: Vector3 = group.size
		print("  GONE %3d  %-52s  %.2f x %.2f x %.2f  e.g. at %s" % [int(group.count), gone_order[index], size.x, size.y, size.z, str((group.at as Vector3).snappedf(0.1))])
	# --- with --kinds: everything solid that stands on a floor, by who built it
	if kinds:
		var all: Array = map.floor_solids()
		var groups := {}
		for entry in all:
			if doors.has(entry.shape):
				continue
			var cap: bool = made.has(entry.shape) and bool(made[entry.shape][1])
			if cap:
				continue
			var key := _tag(entry.shape)
			if not groups.has(key):
				groups[key] = {"count": 0, "low": INF, "high": 0.0, "narrow": INF, "wide": 0.0, "gone": 0}
			var group: Dictionary = groups[key]
			group.count += 1
			group.low = minf(float(group.low), float(entry.over))
			group.high = maxf(float(group.high), float(entry.over))
			group.narrow = minf(float(group.narrow), float(entry.narrow))
			group.wide = maxf(float(group.wide), float(entry.wide))
		var names: Array = groups.keys()
		names.sort()
		print("KINDS %d of solid things on a floor (%d colliders)" % [names.size(), all.size()])
		for key in names:
			var group: Dictionary = groups[key]
			print("  KIND %4d  %-50s  top %.2f..%.2f  narrow %.2f  wide %.2f" % [int(group.count), key, float(group.low), float(group.high), float(group.narrow), float(group.wide)])

	# --- a body of the player's size from every free cell of the floor to the next
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = TALL - STEP
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = MASK
	query.margin = 0.0
	var hangs := {}
	var tried := 0
	var stopped := 0
	for level in range(map.navigation.size()):
		var grid := map.navigation[level]
		var region := grid.region
		var floor_y := map.level_height(level)
		for cx in range(region.position.x, region.end.x):
			for cz in range(region.position.y, region.end.y):
				var cell := Vector2i(cx, cz)
				if grid.is_point_solid(cell):
					continue
				var from := Vector3(cx * CabinMap.CELL, floor_y + STEP + capsule.height * 0.5, cz * CabinMap.CELL)
				for step in [Vector2i(1, 0), Vector2i(0, 1)]:
					var next: Vector2i = cell + step
					if not region.has_point(next) or grid.is_point_solid(next):
						continue
					tried += 1
					query.transform = Transform3D(Basis.IDENTITY, from)
					query.motion = Vector3(step.x, 0, step.y) * CabinMap.CELL
					var reach := space.cast_motion(query)
					if reach[0] >= 0.98:
						continue
					# What stops it: what it touches a little further on.
					query.transform = Transform3D(Basis.IDENTITY, from + query.motion * minf(1.0, reach[1] + 0.04))
					query.motion = Vector3.ZERO
					var blocker: Node = null
					for hit in space.intersect_shape(query, 6):
						var owner_body := hit.collider as CollisionObject3D
						if owner_body == null:
							continue
						var shape := owner_body.shape_owner_get_owner(owner_body.shape_find_owner(int(hit.shape))) as Node
						if shape != null and not doors.has(shape):
							blocker = shape
							break
					if blocker == null:
						continue
					stopped += 1
					if not hangs.has(blocker):
						hangs[blocker] = {"count": 0, "at": from - Vector3(0, STEP + capsule.height * 0.5, 0)}
					hangs[blocker].count += 1
	var by_tag := {}
	for shape in hangs:
		var info := _shape_info(shape)
		var key := "%s  %.2f x %.2f x %.2f" % [_tag(shape), info.size.x, info.size.y, info.size.z]
		if not by_tag.has(key):
			by_tag[key] = {"shapes": 0, "steps": 0, "at": hangs[shape].at, "top": info.top}
		by_tag[key].shapes += 1
		by_tag[key].steps += int(hangs[shape].count)
	var hang_order: Array = by_tag.keys()
	hang_order.sort_custom(func(a: String, b: String) -> bool: return int(by_tag[a].steps) > int(by_tag[b].steps))
	print("HANGS steps_tried=%d stopped=%d by=%d colliders of %d kinds" % [tried, stopped, hangs.size(), hang_order.size()])
	for index in range(mini(most, hang_order.size())):
		var group: Dictionary = by_tag[hang_order[index]]
		print("  HANG %4d steps, %3d colliders  %-64s  top at y %.2f  e.g. standing at %s" % [int(group.steps), int(group.shapes), hang_order[index], float(group.top), str((group.at as Vector3).snappedf(0.1))])
	quit(1 if not snags.is_empty() else 0)

func _count_shapes() -> int:
	var count := 0
	for owner_body in [map.body, map.rails]:
		count += owner_body.get_child_count()
	return count

func _shape_info(shape: Node) -> Dictionary:
	var node := shape as CollisionShape3D
	var size := Vector3.ZERO
	if node.shape is BoxShape3D:
		size = (node.shape as BoxShape3D).size
	elif node.shape is CylinderShape3D:
		var drum := node.shape as CylinderShape3D
		size = Vector3(drum.radius * 2.0, drum.height, drum.radius * 2.0)
	var basis := node.transform.basis
	var half := (basis.x.abs() * size.x + basis.y.abs() * size.y + basis.z.abs() * size.z) * 0.5
	return {"size": size, "top": node.transform.origin.y + half.y}

## Whether somebody can pass a small thing on two sides: free cells of the floor it
## stands on lie to its left and right or before and behind it.
func _in_the_open(entry: Dictionary) -> bool:
	var grid := map.navigation[int(entry.level)]
	var region := grid.region
	var low: Vector3 = entry.low
	var high: Vector3 = entry.high
	var reach := CabinMap.NAV_MARGIN + CabinMap.CELL
	var free := [false, false, false, false]
	var x0 := floori((low.x - reach) / CabinMap.CELL)
	var x1 := ceili((high.x + reach) / CabinMap.CELL)
	var z0 := floori((low.z - reach) / CabinMap.CELL)
	var z1 := ceili((high.z + reach) / CabinMap.CELL)
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var cell := Vector2i(cx, cz)
			if not region.has_point(cell) or grid.is_point_solid(cell):
				continue
			var x := cx * CabinMap.CELL
			var z := cz * CabinMap.CELL
			if x < low.x:
				free[0] = true
			if x > high.x:
				free[1] = true
			if z < low.z:
				free[2] = true
			if z > high.z:
				free[3] = true
	return (free[0] and free[1]) or (free[2] and free[3])
