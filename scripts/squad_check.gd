extends Node
## Measures how the squad (the two companions, Teammate) keeps up with the survivor where a
## place has several levels: the areas of the random part of mission two (all seven, the
## dissection laboratory first), the transitions, the freight lifts, the galleries and
## stairs of the old facility and the floors of the villa.
##   Godot --headless --path <project> -- --squad-check [--squad-region=sezierlabor,villa]
##        [--squad-order=follow,free,hold,fight] [--squad-speed=3] > out.txt 2>&1
## The survivor is walked (not steered by physics) along the path finder's ways from spot
## to spot - on every height of a place, back and forth between them - and waits at each
## spot; the companions do what they do in a night. Nobody attacks unless a fight is the
## point. Lines:
##   SQUAD_REGION <region> <order> <mate> ...   the numbers of one companion in one place
##   SQUAD_EVENT <kind> <region> <mate> at <pos> ...   every incident, where it happened
##   SQUAD_TOTAL <order> ...   all places together
## Numbers: legs (spots walked to), rejoin_avg / rejoin_max (seconds after the survivor
## stops until the companion is near him on his level), never (legs it did not come within
## WAIT seconds), wrong_level (seconds on another level than the survivor while he stands),
## stuck (it wants to move and does not), circles (it moves a lot and gets nowhere),
## blocks (two of them on one flight, neither getting on), drops (fell more than a storey
## off a gallery or an edge), teleports (put next to him by the game; seen: in his sight),
## lift_left (outside the cabin when its door shut), behind (seconds more than 14 m away
## while he walks), hold_miss (did not get to a hold point on another level), cross_shots
## (shots at somebody on another level), strayed (lost him while fighting).

const WAIT := 12.0
const NEAR := 6.0
const WALK := 4.6
const SAMPLE := 1.0

var game: Node3D
var map: HiveMap
var player: Survivor
var mates: Array = []
var stats: Dictionary = {}
var totals: Dictionary = {}
var region := ""
var order_now := "follow"
var walking := false
var waited := 0.0
var still_for := 0.0
var clock := 0.0
## The way the survivor walks: points, and how far along it he is.
var route := PackedVector3Array()
var route_at := 0
## Teleports the check itself does (a lift's ride) are no fault of anybody's.
var own_move := false
var events := 0
var feel_left := 0.0

func run(owner_game: Node3D) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10
	var wanted_regions: Array = []
	var wanted_orders: Array = ["follow", "free", "hold", "fight"]
	var speed := 3.0
	for arg in OS.get_cmdline_user_args():
		# (--squad-seed=N: other dice for the companions, e.g. when they turn to look.)
		if arg.begins_with("--squad-seed="):
			seed(int(arg.trim_prefix("--squad-seed=")))
		if arg.begins_with("--squad-region="):
			wanted_regions = Array(arg.trim_prefix("--squad-region=").split(","))
		if arg.begins_with("--squad-order="):
			wanted_orders = Array(arg.trim_prefix("--squad-order=").split(","))
		if arg.begins_with("--squad-speed="):
			speed = float(arg.trim_prefix("--squad-speed="))
	game.profile.mode = "story"
	game.profile.mission = 2
	game.team_enabled = true
	game.hive.seed_wanted = -4
	game.hive.night = {}
	game.hive.night_fresh = false
	game.hive.resume_at = "labs"
	game.start_run()
	await _frames(10)
	map = game.cabin as HiveMap
	player = game.player
	mates = game.team.duplicate()
	# --squad-solo: one companion only (the other stands aside, out of everything).
	if "--squad-solo" in OS.get_cmdline_user_args() and mates.size() > 1:
		var aside: Teammate = mates.pop_back()
		aside.set_physics_process(false)
		aside.global_position = Vector3(0, -200, 0)
	if mates.is_empty():
		print("SQUAD_ERROR no companions")
		get_tree().quit(1)
		return
	# Nobody runs the night: no stages, nobody comes, every door stands open.
	game.hive.set_physics_process(false)
	# (Nor does the Prowler hunt: it would knock the squad down.)
	game.hive.prowl.end()
	game.hive.prowl.set_process(false)
	for mate: Teammate in mates:
		if mate.down:
			mate.revive(true)
	game.hive.set_process(false)
	player.set_physics_process(false)
	for id in map.areas:
		map.unlock(str(id), true)
	for door in map.doors:
		if str(door.kind) == "script":
			map.set_door(str(door.name), true, true)
	for name in map.areal_signs:
		map.set_port(str(name), true, true)
	Engine.time_scale = speed
	var regions := _regions()
	for entry: Dictionary in regions:
		if not wanted_regions.is_empty() and not wanted_regions.has(str(entry.name)) and not wanted_regions.has(str(entry.group)):
			continue
		for order in wanted_orders:
			await _region(entry, str(order))
	for order in wanted_orders:
		if totals.has(order):
			print("SQUAD_TOTAL %s %s" % [order, _line(totals[order])])
	print("SQUAD_DONE events=%d" % events)
	Engine.time_scale = 1.0
	get_tree().quit()

# ---------------------------------------------------------------- the places

## Every place with several levels: {name, group, spots (in the order he walks to them),
## lift (a lift id to ride at the end)}.
func _regions() -> Array:
	var out: Array = []
	var areas: Array = (map.night.pieces as Array).filter(func(piece: Dictionary) -> bool: return str(piece.kind) == "area")
	# (The dissection laboratory first: it is where he saw them lose him.)
	areas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (0 if str(a.def) == "sezierlabor" else 1) < (0 if str(b.def) == "sezierlabor" else 1))
	for piece: Dictionary in areas:
		out.append({"name": str(piece.def), "group": "areas", "spots": _piece_spots(piece)})
	for piece: Dictionary in map.night.pieces:
		if str(piece.kind) == "transition" and str(piece.def) == "treppenhaus":
			var from: Vector3 = map.points.get("%s_in" % piece.id, Vector3.INF)
			var to: Vector3 = map.points.get("%s_out" % piece.id, Vector3.INF)
			if from != Vector3.INF and to != Vector3.INF:
				out.append({"name": "treppenhaus_%s" % piece.id, "group": "transitions", "spots": [_inside(from, to), _inside(to, from), _inside(from, to)]})
	# The lifts: from the old room into the cabin, a ride, out of the twin.
	for chain: Dictionary in map.night.chains:
		if str(chain.out) != "" and map.points.has("lift_%s_mid" % chain.out):
			out.append({"name": "lift_%s" % chain.out, "group": "lifts", "lift": str(chain.out), "spots": []})
	# The villa: its hall and its gallery; the facility: its galleries over the floor.
	out.append({"name": "villa", "group": "old", "spots": _level_spots(Rect2(-24, -4, 48, 27), [0.0, HiveMap.STOREY_VILLA], 3)})
	out.append({"name": "terminal", "group": "old", "spots": _level_spots(Rect2(-60, -350, 120, 40), [HiveMap.UNDER, HiveMap.DECK], 3)})
	out.append({"name": "atrium", "group": "old", "spots": _level_spots(Rect2(-30, -500, 60, 60), [HiveMap.UNDER, HiveMap.DECK], 3)})
	out.append({"name": "research", "group": "old", "spots": _level_spots(Rect2(-60, -644, 132, 100), [HiveMap.UNDER, HiveMap.DECK], 3)})
	return out

## The spots of an area: its way in, places on every height of it (spread out), the
## places of its objectives, its way out - in an order that goes up and down.
func _piece_spots(piece: Dictionary) -> Array:
	var spots: Array = []
	if map.points.has("%s_entry" % piece.id):
		spots.append(map.points["%s_entry" % piece.id])
	var bounds := Rect2()
	for part: Rect2 in piece.parts:
		bounds = part if bounds.size == Vector2.ZERO else bounds.merge(part)
	var heights: Array = (piece.heights as Array).duplicate()
	var by_height := _level_spots(bounds, heights, 3)
	spots.append_array(by_height)
	var info := HiveLayout.info(str(piece.def))
	var own: Dictionary = info.get("spots", {})
	if own.has("goal"):
		spots.append(HiveAreaRun.free_spot(map, (piece.origin as Vector3) + (own.goal as Vector3)))
	for local: Vector3 in own.get("items", []):
		spots.append(HiveAreaRun.free_spot(map, (piece.origin as Vector3) + local))
	if map.points.has("%s_leave" % piece.id):
		spots.append(map.points["%s_leave" % piece.id])
	return spots

## A few spots on every one of `heights` within `bounds`, far apart, the heights taken in
## turn (low, high, low, high ...), each reachable from the first.
func _level_spots(bounds: Rect2, heights: Array, per: int) -> Array:
	var lists: Array = []
	for h in heights:
		var level := -1
		for index in range(map.floors.size()):
			if absf(float(map.floors[index].y) - float(h)) < 0.3 and (map.floors[index].bounds as Rect2).intersects(bounds):
				level = index
		if level < 0:
			continue
		var grid: AStarGrid2D = map.navigation[level]
		var open: Array = []
		var x := bounds.position.x + 1.0
		while x < bounds.end.x - 1.0:
			var z := bounds.position.y + 1.0
			while z < bounds.end.y - 1.0:
				var cell := Vector2i(roundi(x / CabinMap.CELL), roundi(z / CabinMap.CELL))
				if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and map.level_of(Vector3(x, float(h) + 0.3, z)) == level:
					open.append(Vector3(cell.x * CabinMap.CELL, float(h), cell.y * CabinMap.CELL))
				z += 2.0
			x += 2.0
		# Far apart: each next one the farthest from those taken.
		var taken: Array = []
		if not open.is_empty():
			taken.append(open[open.size() / 2])
		while taken.size() < per and taken.size() < open.size():
			var best: Vector3 = open[0]
			var best_gap := -1.0
			for spot: Vector3 in open:
				var gap := INF
				for other: Vector3 in taken:
					gap = minf(gap, spot.distance_to(other))
				if gap > best_gap:
					best_gap = gap
					best = spot
			taken.append(best)
		lists.append(taken)
	var out: Array = []
	for k in range(per):
		for list: Array in lists:
			if k < list.size():
				out.append(list[k])
	# Only what can be walked to from the first.
	if out.is_empty():
		return out
	var first: Vector3 = out[0]
	return out.filter(func(spot: Vector3) -> bool: return spot == first or not map.path_between(first, spot).is_empty())

func _inside(port: Vector3, toward: Vector3) -> Vector3:
	return port + (toward - port).normalized() * 1.5

# ---------------------------------------------------------------- one place, one order

func _region(entry: Dictionary, order: String) -> void:
	region = str(entry.name)
	order_now = order
	stats.clear()
	for mate: Teammate in mates:
		stats[mate.label] = _fresh()
	if entry.has("lift"):
		if order != "follow":
			return
		await _lift(str(entry.lift))
		_report(entry, order)
		return
	var spots: Array = entry.spots
	if spots.size() < 2:
		return
	_calm()
	# Everybody starts together at the first spot.
	_put_all(spots[0])
	for mate: Teammate in mates:
		mate.order = "follow" if order == "fight" else ("free" if order == "free" else "follow")
		mate.repath_left = 0.0
	await _wait_for(2.0)
	match order:
		"follow", "free":
			for k in range(1, spots.size()):
				await _walk_to(spots[k])
				await _stand()
		"hold":
			# Each in turn is sent to a spot on another level than its own, as the player's
			# order puts it under the crosshair; the survivor stays.
			for k in range(1, spots.size()):
				for i in range(mates.size()):
					var mate: Teammate = mates[i]
					var post: Vector3 = spots[k]
					if map.level_of(post + Vector3(0, 0.3, 0)) == map.level_of(mate.global_position + Vector3(0, 0.3, 0)):
						continue
					mate.order = "hold"
					mate.hold_point = post + Vector3(0.9 * (i * 2 - 1), 0, 0)
					var cell := map.nearest_cell(mate.hold_point)
					mate.hold_point = Vector3(cell.x * CabinMap.CELL, game.floor_height(map.level_of(post + Vector3(0, 0.3, 0))), cell.y * CabinMap.CELL)
					mate.repath_left = 0.0
					var s: Dictionary = stats[mate.label]
					s.holds += 1
					var reached := false
					var spent := 0.0
					while spent < 30.0:
						await get_tree().physics_frame
						spent += get_physics_process_delta_time()
						_watch(get_physics_process_delta_time())
						var off := mate.hold_point - mate.global_position
						if Vector2(off.x, off.z).length() < 1.3 and absf(off.y) < 1.2:
							reached = true
							break
					if reached:
						s.hold_time += spent
					else:
						s.hold_miss += 1
						_event("hold_miss", mate, "to %s" % str(mate.hold_point.snapped(Vector3.ONE * 0.1)))
					mate.order = "follow"
				await _stand()
		"fight":
			# He stands on one height; a few infected come at him from another one.
			for k in range(1, spots.size()):
				var here: Vector3 = spots[k - 1]
				var there: Vector3 = spots[k]
				if map.level_of(here + Vector3(0, 0.3, 0)) == map.level_of(there + Vector3(0, 0.3, 0)):
					continue
				await _walk_to(here)
				await _stand()
				var foes: Array = []
				for n in range(3):
					var foe: Infected = game.hive._place("mauler", there + Vector3(n * 1.2, 0, 0))
					if foe != null:
						foes.append(foe)
				var shots_before := {}
				for mate: Teammate in mates:
					shots_before[mate.label] = mate.kills
				var spent := 0.0
				while spent < 20.0 and foes.any(func(foe: Infected) -> bool: return is_instance_valid(foe) and not foe.dead):
					await get_tree().physics_frame
					spent += get_physics_process_delta_time()
					_watch(get_physics_process_delta_time())
					_fight_watch()
				_calm()
				await _stand()
	_report(entry, order)

func _fresh() -> Dictionary:
	return {"legs": 0, "rejoin_sum": 0.0, "rejoin_max": 0.0, "never": 0, "wrong_level": 0.0, "stuck": 0, "circles": 0,
		"blocks": 0, "drops": 0, "teleports": 0, "seen": 0, "lift_left": 0, "behind": 0.0, "holds": 0, "hold_time": 0.0,
		"hold_miss": 0, "cross_shots": 0, "strayed": 0.0, "trail": [], "stuck_on": false, "circle_on": false,
		"last": Vector3.INF, "falling_from": INF, "block_on": false, "away": 0.0}

# ---------------------------------------------------------------- the survivor

func _put_all(at: Vector3) -> void:
	own_move = true
	player.global_position = at + Vector3(0, 0.05, 0)
	for i in range(mates.size()):
		var mate: Teammate = mates[i]
		var cell := map.nearest_cell(at + Vector3(1.2 * (i * 2 - 1), 0, 1.0), map.level_of(at + Vector3(0, 0.3, 0)))
		mate.global_position = Vector3(cell.x * CabinMap.CELL, at.y + 0.05, cell.y * CabinMap.CELL)
		mate.velocity = Vector3.ZERO
		mate.path = PackedVector3Array()
		var s: Dictionary = stats[mate.label]
		s.last = mate.global_position
		s.trail = []

## He walks there along the path finder's way, at a run.
func _walk_to(goal: Vector3) -> void:
	route = map.path_between(player.global_position, goal)
	route_at = 0
	if route.is_empty():
		_event("no_way_for_him", null, "to %s" % str(goal.snapped(Vector3.ONE * 0.1)))
		return
	walking = true
	var spent := 0.0
	while route_at < route.size() and spent < 120.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		spent += dt
		var step := WALK * dt
		while step > 0.0 and route_at < route.size():
			var to := route[route_at] - player.global_position
			var flat := Vector2(to.x, to.z)
			if flat.length() <= step:
				player.global_position = route[route_at] + Vector3(0, 0.05, 0)
				step -= flat.length()
				route_at += 1
			else:
				var dir := Vector3(flat.x, 0, flat.y).normalized()
				player.global_position += dir * step
				player.global_position.y = lerpf(player.global_position.y, route[route_at].y + 0.05, clampf(step / maxf(0.01, flat.length()), 0.0, 1.0))
				player.rotation.y = atan2(-dir.x, -dir.z)
				step = 0.0
		_watch(dt)
	walking = false

## He stands; how long until each of them is near him again, on his level.
func _stand() -> void:
	var back := {}
	var spent := 0.0
	while spent < WAIT:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		spent += dt
		_watch(dt)
		for mate: Teammate in mates:
			if back.has(mate.label):
				continue
			if _near(mate):
				back[mate.label] = spent
		if back.size() == mates.size() and spent > 2.0:
			break
	for mate: Teammate in mates:
		var s: Dictionary = stats[mate.label]
		s.legs += 1
		if back.has(mate.label):
			s.rejoin_sum += float(back[mate.label])
			s.rejoin_max = maxf(float(s.rejoin_max), float(back[mate.label]))
		else:
			s.never += 1
			_event("never_back", mate, "%.1f m away, level %d against %d" % [mate.global_position.distance_to(player.global_position), map.level_of(mate.global_position + Vector3(0, 0.3, 0)), map.level_of(player.global_position + Vector3(0, 0.3, 0))])

func _near(mate: Teammate) -> bool:
	var gap := mate.global_position - player.global_position
	return Vector2(gap.x, gap.z).length() < NEAR and absf(gap.y) < 1.2

func _wait_for(seconds: float) -> void:
	var spent := 0.0
	while spent < seconds:
		await get_tree().physics_frame
		spent += get_physics_process_delta_time()

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func _calm() -> void:
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy != null and not enemy.dead:
			enemy._retire()
		node.queue_free()
	game.alive_count = 0

# ---------------------------------------------------------------- what they do

## Every physics frame: what each of them does that is worth counting.
func _watch(dt: float) -> void:
	clock += dt
	if not walking and order_now != "fight":
		_calm()
	# The sliding doors open for whoever comes near, as the director has them do in a night
	# (HiveDirector._physics_process, which does not run here).
	feel_left -= dt
	if feel_left <= 0.0:
		feel_left = 0.12
		var actors := PackedVector3Array([player.global_position])
		for mate: Teammate in mates:
			actors.append(mate.global_position)
		for node in game.enemies.get_children():
			actors.append((node as Node3D).global_position)
		map.feel(actors)
	var here := player.global_position
	var my_level := map.level_of(here + Vector3(0, 0.3, 0))
	var stairs_of := {}
	for mate: Teammate in mates:
		var s: Dictionary = stats[mate.label]
		var pos := mate.global_position
		var flight: int = int(map._on_flight(pos)[0])
		stairs_of[mate.label] = flight
		# Put somewhere by the game: more than 4 m in one frame.
		if s.last != Vector3.INF and pos.distance_to(s.last) > 4.0 and not own_move:
			s.teleports += 1
			var seen := _in_sight(s.last) or _in_sight(pos)
			if seen:
				s.seen += 1
			_event("teleport", mate, "from %s%s" % [str((s.last as Vector3).snapped(Vector3.ONE * 0.1)), " in his sight" if seen else ""])
		# Off an edge: falling more than a storey, not on a flight.
		if flight < 0 and mate.velocity.y < -4.0:
			if s.falling_from == INF:
				s.falling_from = pos.y
		elif s.falling_from != INF:
			if float(s.falling_from) - pos.y > 2.2:
				s.drops += 1
				_event("drop", mate, "%.1f m down" % (float(s.falling_from) - pos.y))
			s.falling_from = INF
		s.last = pos
		# Far behind while he walks.
		if walking and pos.distance_to(here) > 14.0:
			s.behind += dt
		# On another level while he stands.
		var level := map.level_of(pos + Vector3(0, 0.3, 0))
		if not walking and level != my_level and flight < 0 and mate.order != "hold":
			s.wrong_level += dt
		# A trail: one point every SAMPLE seconds, for being stuck and running in circles.
		var trail: Array = s.trail
		if trail.is_empty() or clock - float(trail[trail.size() - 1][0]) >= SAMPLE:
			trail.append([clock, pos])
			if trail.size() > 6:
				trail.pop_front()
		var wants := (not _near(mate) and mate.order != "hold") or (mate.order == "hold" and mate.hold_point.distance_to(pos) > 1.3)
		if trail.size() >= 3 and wants:
			var two_back: Vector3 = trail[trail.size() - 3][1]
			var stuck := pos.distance_to(two_back) < 0.4
			if stuck and not bool(s.stuck_on):
				s.stuck += 1
				_event("stuck", mate, "%s - path %d at %d to %s, he at %s level %d" % [_where(pos), mate.path.size(), mate.path_index, str(mate.path[mate.path.size() - 1].snapped(Vector3.ONE * 0.1)) if mate.path.size() > 0 else "-", str(here.snapped(Vector3.ONE * 0.1)), my_level])
			# (One episode until it has really got going again.)
			if stuck:
				s.stuck_on = true
			elif pos.distance_to(two_back) > 1.2:
				s.stuck_on = false
		else:
			s.stuck_on = false
		if trail.size() >= 5 and wants:
			var run_length := 0.0
			for k in range(trail.size() - 4, trail.size()):
				run_length += (trail[k][1] as Vector3).distance_to(trail[k - 1][1])
			var circling := run_length > 7.0 and pos.distance_to(trail[trail.size() - 5][1]) < 1.8
			if circling and not bool(s.circle_on):
				s.circles += 1
				_event("circles", mate, _where(pos))
			s.circle_on = circling
	# Two on one flight, close together, neither getting on.
	if mates.size() >= 2:
		var a: Teammate = mates[0]
		var b: Teammate = mates[1]
		var on_one := int(stairs_of[a.label]) >= 0 and int(stairs_of[a.label]) == int(stairs_of[b.label])
		var blocking: bool = on_one and a.global_position.distance_to(b.global_position) < 1.1 and bool(stats[a.label].stuck_on) and bool(stats[b.label].stuck_on)
		if blocking and not bool(stats[a.label].block_on):
			stats[a.label].blocks += 1
			_event("block", a, "with %s on flight %d" % [b.label, int(stairs_of[a.label])])
		stats[a.label].block_on = blocking
	own_move = false

## In a fight: shots at somebody on another level, and losing him.
func _fight_watch() -> void:
	var my_level := map.level_of(player.global_position + Vector3(0, 0.3, 0))
	for mate: Teammate in mates:
		var s: Dictionary = stats[mate.label]
		var level := map.level_of(mate.global_position + Vector3(0, 0.3, 0))
		if mate.firing and is_instance_valid(mate.target) and map.level_of(mate.target.global_position + Vector3(0, 0.3, 0)) != level:
			s.cross_shots += 1
		if level != my_level and int(map._on_flight(mate.global_position)[0]) < 0:
			s.strayed += get_physics_process_delta_time()

func _in_sight(at: Vector3) -> bool:
	var eye := player.global_position + Vector3(0, 1.6, 0)
	var ahead := Vector3(-sin(player.rotation.y), 0, -cos(player.rotation.y))
	var to := at + Vector3(0, 1.0, 0) - eye
	if to.length() > 40.0 or Vector3(to.x, 0, to.z).normalized().dot(ahead) < 0.35:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, at + Vector3(0, 1.0, 0), 1)
	return get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty()

## What is at a spot: a flight (its foot or head), a doorway, or open floor.
func _where(pos: Vector3) -> String:
	var flight: Array = map._on_flight(pos)
	if int(flight[0]) >= 0:
		return "on flight %d (step %d) at %s" % [int(flight[0]), int(flight[1]), str(pos.snapped(Vector3.ONE * 0.1))]
	for stair in map.stairs:
		if (stair.foot as Vector3).distance_to(pos) < 2.2:
			return "at the foot of a flight at %s" % str(pos.snapped(Vector3.ONE * 0.1))
		if (stair.head as Vector3).distance_to(pos) < 2.2:
			return "at the head of a flight at %s" % str(pos.snapped(Vector3.ONE * 0.1))
	for door in map.doors:
		if (door.strip as Rect2).grow(0.6).has_point(Vector2(pos.x, pos.z)) and absf(float(door.pos.y) - pos.y) < 1.5:
			return "in a doorway (%s) at %s" % [str(door.kind), str(pos.snapped(Vector3.ONE * 0.1))]
	return "on open floor at %s (level %d)" % [str(pos.snapped(Vector3.ONE * 0.1)), map.level_of(pos + Vector3(0, 0.3, 0))]

func _event(kind: String, mate: Teammate, detail: String) -> void:
	events += 1
	print("SQUAD_EVENT %s %s %s %s %s" % [kind, region, order_now, mate.label if mate != null else "-", detail])

# ---------------------------------------------------------------- a lift

## He walks from the old room into a real freight lift and it rides; how many of them were
## in the cabin when its door shut, and how they come out of the twin with him.
func _lift(id: String) -> void:
	var mid: Vector3 = map.points["lift_%s_mid" % id]
	var room: Dictionary = map.room_of["lift_%s" % id]
	var spec: Dictionary = HiveLayout.LIFTS[id]
	var out: Vector2 = HiveCore.OUT[int(spec.door)]
	var before := mid + Vector3(out.x, 0, out.y) * 9.0
	var cell := map.nearest_cell(before, map.level_of(mid + Vector3(0, 0.3, 0)))
	before = Vector3(cell.x * CabinMap.CELL, mid.y, cell.y * CabinMap.CELL)
	_calm()
	_put_all(before)
	for mate: Teammate in mates:
		mate.order = "follow"
	await _wait_for(2.0)
	# The run's own ride: the night's chain whose lift this is.
	var run: HiveAreaRun = game.hive.run
	var index := -1
	for k in range((map.night.chains as Array).size()):
		if str(map.night.chains[k].out) == id:
			index = k
	game.hive.stage = "c%d_lift" % index
	run.enter("c%d_lift" % index)
	await _walk_to(mid)
	# The run's own ride (HiveAreaRun._run_ride): whoever is outside the cabin when its door
	# shuts was left outside (it is brought along, a teleport the game does).
	var cabin: Rect2 = room.outer
	var spent := 0.0
	var outside: Array = []
	while not run.ride.is_empty() and spent < 30.0:
		var was := str(run.ride.get("phase", ""))
		outside = mates.filter(func(mate: Teammate) -> bool: return not cabin.grow(0.3).has_point(Vector2(mate.global_position.x, mate.global_position.z)))
		run.update(get_physics_process_delta_time())
		if was == "wait" and str(run.ride.get("phase", "")) == "ride":
			for mate: Teammate in outside:
				stats[mate.label].lift_left += 1
				_event("lift_left", mate, "%.1f m from the cabin" % Vector2(mate.global_position.x - mid.x, mate.global_position.z - mid.z).length())
			print("SQUAD_LIFT %s boarded after %.1f s, %d of %d in" % [id, spent, mates.size() - outside.size(), mates.size()])
		own_move = str(run.ride.get("phase", "")) == "ride" or was == "ride"
		await get_tree().physics_frame
		spent += get_physics_process_delta_time()
		_watch(get_physics_process_delta_time())
	await _stand()

# ---------------------------------------------------------------- the numbers

const COUNTED := ["legs", "rejoin_sum", "never", "wrong_level", "stuck", "circles", "blocks", "drops", "teleports", "seen", "lift_left", "behind", "holds", "hold_time", "hold_miss", "cross_shots", "strayed"]

func _report(entry: Dictionary, order: String) -> void:
	if not totals.has(order):
		totals[order] = {"rejoin_max": 0.0}
		for key in COUNTED:
			totals[order][key] = 0.0
	for mate: Teammate in mates:
		var s: Dictionary = stats[mate.label]
		print("SQUAD_REGION %s %s %s %s" % [str(entry.name), order, mate.label, _line(s)])
		for key in COUNTED:
			totals[order][key] = float(totals[order][key]) + float(s[key])
		totals[order].rejoin_max = maxf(float(totals[order].rejoin_max), float(s.rejoin_max))

func _line(s: Dictionary) -> String:
	var legs := maxf(1.0, float(s.legs) - float(s.never))
	return "legs=%d rejoin_avg=%.1f rejoin_max=%.1f never=%d wrong_level=%.1f stuck=%d circles=%d blocks=%d drops=%d teleports=%d seen=%d lift_left=%d behind=%.1f holds=%d hold_avg=%.1f hold_miss=%d cross_shots=%d strayed=%.1f" % [
		int(s.legs), float(s.rejoin_sum) / legs, float(s.rejoin_max), int(s.never), float(s.wrong_level), int(s.stuck), int(s.circles),
		int(s.blocks), int(s.drops), int(s.teleports), int(s.seen), int(s.lift_left), float(s.behind), int(s.holds),
		float(s.hold_time) / maxf(1.0, float(s.holds) - float(s.hold_miss)), int(s.hold_miss), int(s.cross_shots), float(s.strayed)]
