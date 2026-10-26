class_name HiveFinds
extends Node
## Throwables to be found in the second mission: now and then a frag grenade, a Molotov
## cocktail, a flashbang - more rarely a heal grenade or a mine - lies in a crate of throwables in
## a room of the old facility or of an area of the random part, because hardly anybody
## buys grenades. A handful a night (COUNT), at least SPACING apart, never in a doorway;
## where, and what, is dealt from the night like the caches (the same for both players in
## co-op; each takes his own). A find glints softly, is taken with [E] while it is aimed at
## (as everything since v0.68), and only while there is room for it in the pockets
## (Survivor.GOODS[kind].max). Once seen it is a small mark on the map in the corner.
## A defeat taken up at a checkpoint keeps what was taken before.

## How many finds a night, how far apart at the least, and what they are (weights).
const COUNT := 7
const SPACING := 24.0
const KINDS := {"grenade": 34, "molotov": 24, "flashbang": 22, "heal": 11, "claymore": 9}
## How near the survivor has to be to take one, to see one (for the map) and to be told.
const REACH := 2.4
const SEEN := 14.0
const MARK_REACH := 40.0

var director: Node
var game: Node3D
var map: Node3D
var on := false
var night := 0
## Each find: kind, at (where it lies), node, taken, seen.
var finds: Array[Dictionary] = []
## What was taken, by night (for a defeat taken up at a checkpoint).
var taken_of: Dictionary = {}
var look_left := 0.0
## The night is laid out a moment after it begins (the map's walls must be in the world
## for the spots to be tried): seconds until then.
var lay_left := -1.0

func begin(seed_value: int) -> void:
	end()
	on = true
	map = director.map
	night = seed_value
	lay_left = 0.3

## Lays the night's finds out (begin asks for it).
func lay() -> void:
	lay_left = -1.0
	var gone: Dictionary = taken_of.get(night, {})
	taken_of.clear()
	taken_of[night] = gone
	for spot: Dictionary in deal(map, night):
		var find := {"kind": str(spot.kind), "at": spot.at, "yaw": float(spot.yaw), "taken": gone.has(_key(spot.at)), "seen": false, "node": null}
		if not bool(find.taken):
			find.node = build(str(find.kind))
			map.add_child(find.node)
			(find.node as Node3D).global_position = spot.at
			(find.node as Node3D).rotation.y = float(spot.yaw)
		finds.append(find)

func end() -> void:
	lay_left = -1.0
	for find in finds:
		if is_instance_valid(find.node):
			(find.node as Node).queue_free()
	finds.clear()
	on = false

static func _key(at: Vector3) -> String:
	return "%d:%d:%d" % [roundi(at.x * 10.0), roundi(at.y * 10.0), roundi(at.z * 10.0)]

## Where the finds of a night lie and what they are: rooms drawn from the map (not outdoors,
## nor where nobody walks), a spot by one of their walls that is free and not in a doorway.
static func deal(where: Node3D, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rooms: Array = []
	for room: Dictionary in where.rooms:
		var outer: Rect2 = room.outer
		if bool(room.get("outdoor", false)) or not bool(room.get("nav", true)) or room.has("walk") or outer.size.x < 4.0 or outer.size.y < 4.0 or float(room.height) < 2.2:
			continue
		rooms.append(room)
	# (Shuffled by the night's dice; the order of the map decides nothing.)
	for i in range(rooms.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = rooms[i]
		rooms[i] = rooms[j]
		rooms[j] = swap
	var out: Array = []
	var space: PhysicsDirectSpaceState3D = where.get_world_3d().direct_space_state if where.is_inside_tree() else null
	for room: Dictionary in rooms:
		if out.size() >= COUNT:
			break
		var spot := _spot(where, room, rng, space)
		if spot == Vector3.INF:
			continue
		var apart := true
		for other: Dictionary in out:
			apart = apart and (other.at as Vector3).distance_to(spot) >= SPACING
		if not apart:
			continue
		out.append({"at": spot, "kind": _draw(rng), "yaw": rng.randf() * TAU, "room": str(room.id)})
	return out

static func _draw(rng: RandomNumberGenerator) -> String:
	var total := 0
	for kind: String in KINDS:
		total += int(KINDS[kind])
	var roll := rng.randi_range(1, total)
	for kind: String in KINDS:
		roll -= int(KINDS[kind])
		if roll <= 0:
			return kind
	return "grenade"

## A free spot half a metre from one of a room's walls, a metre and a half clear of its
## corners and of every doorway; INF if none of a few tries is free.
static func _spot(where: Node3D, room: Dictionary, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D) -> Vector3:
	var outer: Rect2 = room.outer
	var inner: Rect2 = outer.grow(-0.75)
	var y := float(room.y)
	for attempt in range(6):
		var side := rng.randi_range(0, 3)
		var along := rng.randf_range(0.2, 0.8)
		var at := Vector3.ZERO
		match side:
			0:
				at = Vector3(lerpf(inner.position.x, inner.end.x, along), y, inner.position.y)
			1:
				at = Vector3(inner.end.x, y, lerpf(inner.position.y, inner.end.y, along))
			2:
				at = Vector3(lerpf(inner.position.x, inner.end.x, along), y, inner.end.y)
			_:
				at = Vector3(inner.position.x, y, lerpf(inner.position.y, inner.end.y, along))
		var clear := true
		for door: Dictionary in where.doors:
			if int(door.level) == int(room.level) and Vector2((door.pos as Vector3).x - at.x, (door.pos as Vector3).z - at.z).length() < 2.2:
				clear = false
		if not clear:
			continue
		if space != null:
			# Nothing stands there (the crate is half a metre each way), and the floor is there.
			var box := BoxShape3D.new()
			box.size = Vector3(0.6, 0.7, 0.6)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = box
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.45, 0))
			query.collision_mask = 1
			if not space.intersect_shape(query, 1).is_empty():
				continue
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.6, 0), at + Vector3(0, -0.6, 0), 1))
			if ground.is_empty():
				continue
			at.y = (ground.position as Vector3).y
		return at
	return Vector3.INF

## A find as it lies: the crate of throwables (GrenadeFinds' model), the picture of what it
## holds glowing on it. A mine is not painted on the crate: it lies on top.
static func build(kind: String) -> Node3D:
	var root := GrenadeFinds.build_view(kind if GrenadeFinds.SPOTS.has(kind) else "")
	root.name = "Find_" + kind
	root.set_meta("kind", kind)
	if not GrenadeFinds.SPOTS.has(kind):
		var thing := Node3D.new()
		thing.name = "Thing"
		thing.position = Vector3(-0.1, 0.345, 0.04)
		root.add_child(thing)
		_thing(thing, kind)
	return root

## The throwable lying on the crate, at its true size.
static func _thing(parent: Node3D, kind: String) -> void:
	var paint: Color = Throwable.KINDS[kind].color if Throwable.KINDS.has(kind) else Color("4c5a3a")
	match kind:
		"grenade":
			var egg := SphereMesh.new()
			egg.radius = 0.034
			egg.height = 0.078
			Throwable._part(parent, egg, Vector3(0, 0.034, 0), paint, 0.2).rotation.z = PI * 0.5
			var fuse := CylinderMesh.new()
			fuse.top_radius = 0.011
			fuse.bottom_radius = 0.012
			fuse.height = 0.02
			Throwable._part(parent, fuse, Vector3(0.045, 0.034, 0), Color("545b50"), 0.6).rotation.z = PI * 0.5
		"flashbang":
			var tube := CylinderMesh.new()
			tube.top_radius = 0.022
			tube.bottom_radius = 0.022
			tube.height = 0.11
			Throwable._part(parent, tube, Vector3(0, 0.022, 0), paint, 0.55).rotation.z = PI * 0.5
		"heal":
			var can := CylinderMesh.new()
			can.top_radius = 0.026
			can.bottom_radius = 0.026
			can.height = 0.115
			Throwable._part(parent, can, Vector3(0, 0.058, 0), paint, 0.1)
			var cap := CylinderMesh.new()
			cap.top_radius = 0.02
			cap.bottom_radius = 0.026
			cap.height = 0.016
			Throwable._part(parent, cap, Vector3(0, 0.123, 0), Color("318fa6"), 0.2)
		"molotov":
			var bottle := CapsuleMesh.new()
			bottle.radius = 0.034
			bottle.height = 0.22
			Throwable._part(parent, bottle, Vector3(0, 0.11, 0), paint, 0.25)
			var cloth := BoxMesh.new()
			cloth.size = Vector3(0.022, 0.07, 0.018)
			Throwable._part(parent, cloth, Vector3(0, 0.25, 0), Color("c9ad7e"), 0.0)
		"claymore":
			var mine := BoxMesh.new()
			mine.size = Vector3(0.15, 0.08, 0.035)
			Throwable._part(parent, mine, Vector3(0, 0.04, 0), Color("4c5a3a"), 0.1)

func _process(delta: float) -> void:
	if not on:
		return
	if lay_left >= 0.0:
		lay_left -= delta
		if lay_left < 0.0:
			lay()
		return
	look_left -= delta
	if look_left > 0.0:
		return
	look_left = 0.3
	var here: Vector3 = game.player.global_position
	for find in finds:
		if not bool(find.taken) and not bool(find.seen) and here.distance_to(find.at) < SEEN and absf(here.y - (find.at as Vector3).y) < 2.5:
			# (Seen: nothing stands between the eye and it.)
			var eye: Vector3 = game.player.camera.global_position
			var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, (find.at as Vector3) + Vector3(0, 0.5, 0), 1))
			if hit.is_empty():
				find.seen = true

## The find the survivor stands at and looks at; -1 for none.
func _at_hand() -> int:
	if not on:
		return -1
	var here: Vector3 = game.player.global_position
	var best := -1
	var best_gap := REACH
	for index in range(finds.size()):
		var find := finds[index]
		if bool(find.taken) or not is_instance_valid(find.node):
			continue
		var gap := Vector2(here.x - (find.at as Vector3).x, here.z - (find.at as Vector3).z).length()
		if gap < best_gap and absf(here.y - (find.at as Vector3).y) < 1.8 and game.aims_at_object(find.node):
			best_gap = gap
			best = index
	return best

func focused_object() -> Node3D:
	var index := _at_hand()
	return null if index < 0 else finds[index].node

func _full(kind: String) -> bool:
	return int(game.player.items[kind]) >= int(Survivor.GOODS[kind].max)

func prompt() -> String:
	var index := _at_hand()
	if index < 0:
		return ""
	var kind := str(finds[index].kind)
	var title := str(Survivor.GOODS[kind].label)
	if _full(kind):
		return "%s  ·  kein Platz mehr (%d / %d)" % [title, int(game.player.items[kind]), int(Survivor.GOODS[kind].max)]
	return "[E] %s nehmen" % title

## [E]: takes the find that is aimed at, if there is room for it. True if it was for a find.
func use() -> bool:
	var index := _at_hand()
	if index < 0:
		return false
	var find := finds[index]
	var kind := str(find.kind)
	if _full(kind):
		game.sounds.play_sound("click")
		return true
	take(index)
	return true

func take(index: int) -> void:
	var find := finds[index]
	var kind := str(find.kind)
	game.player.items[kind] = int(game.player.items[kind]) + 1
	find.taken = true
	(taken_of[night] as Dictionary)[_key(find.at)] = true
	if is_instance_valid(find.node):
		(find.node as Node).queue_free()
	find.node = null
	game.sounds.play_sound("pickup")
	game.hud.kill_feed(str(Survivor.GOODS[kind].label), 0, false)
	game.hud.gained(kind)
	game.hud.loadout()

## The finds that have been seen and still lie there (for the map in the corner).
func seen_spots() -> Array:
	var out: Array = []
	if not on:
		return out
	var here: Vector3 = game.player.global_position
	for find in finds:
		if bool(find.seen) and not bool(find.taken) and here.distance_to(find.at) < MARK_REACH:
			out.append(find.at)
	return out
