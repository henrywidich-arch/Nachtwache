class_name HiveLayout
extends RefCounted
## The random part of mission two: what comes after the station, laid out anew for every
## night from one number, its seed (the only thing a co-op host would have to send).
##
## Up to the station the night is what it always was. Then either the train comes in at a
## platform of its own ("ankunft"), or it is derailed in the tunnel ("absturz") and the
## squad goes the last stretch on foot and up an emergency stair. From there it goes
## through two to four AREAS ("Areale") of a pool (POOL; never one twice in a night), each
## joined to the next by a TRANSITION (TRANSITIONS: a corridor with laboratories at its
## sides, one with offices, a lock, a stairwell that changes the level). At the end a lock
## like the decontamination lock of the facility ("schleuse_ende") leads into the
## facility's research wing - the laboratory corridor, the hall of towers, the lift - which
## stays as it is (the end of the mission is fixed).
##
## Every piece is a script of scripts/areale (see AreaKit for what a piece says about
## itself). This class reads what they say, places them in the world - far east of the
## rest of the map, never two of them on top of each other, every way joined - and hands
## the result to HiveMap (which builds it) and HiveDirector (which runs it). Pieces are
## never turned: an area says on which sides it can be entered and left, and the corridors
## between them bend to fit.
##
## A night: {seed, key, classic, arrival, areas, pieces, links, checkpoint, transitions}.
## Each piece: {id, def, kind, index, origin, size, in, out, parts, heights, chain,
## room_in, room_out, shape, area_index, rooms, points}. The classic night (no random part,
## the facility as it was) is {"classic": true, "key": "classic"}.

## The heights the random part is built on: its floors lie one storey (STOREY) or two
## (LIFT) apart, starting at the walking height of the station.
const STOREY := 4.2
const LIFT := 8.4
const BASE := -9.6
## The heights a piece may stand on (its floor); its levels may reach up to TOP.
const LOWEST := -26.4
const HIGHEST := -9.6
const TOP := -1.2
## Where the way out of the arrival lies; nothing of the random part lies west of WEST.
const START := Vector3(320.0, -9.6, 0.0)
const WEST := 150.0
## Pieces that are not joined keep this far apart (metres, in the plan).
const APART := 6.0
## How many areas a night has: count -> weight.
const COUNTS := {2: 3, 3: 5, 4: 3}
## How often a night tries to lay itself out before it falls back to a straight way.
const ATTEMPTS := 60
const STEP_TRIES := 24

## The pieces: what they are called and where their scripts are.
const POOL := ["haifischlabor", "gartenlabor", "reaktorschacht", "kryoarchiv", "isolationstrakt", "lagerhalle", "sezierlabor"]
const TRANSITIONS := ["laborgang", "buerogang", "schleuse", "treppenhaus"]
const ARRIVALS := ["ankunft", "absturz"]
const END := "schleuse_ende"
const SCRIPTS := {
	"haifischlabor": "res://scripts/areale/haifischlabor.gd",
	"gartenlabor": "res://scripts/areale/gartenlabor.gd",
	"reaktorschacht": "res://scripts/areale/reaktorschacht.gd",
	"kryoarchiv": "res://scripts/areale/kryoarchiv.gd",
	"isolationstrakt": "res://scripts/areale/isolationstrakt.gd",
	"lagerhalle": "res://scripts/areale/lagerhalle.gd",
	"sezierlabor": "res://scripts/areale/sezierlabor.gd",
	"laborgang": "res://scripts/areale/laborgang.gd",
	"buerogang": "res://scripts/areale/buerogang.gd",
	"schleuse": "res://scripts/areale/schleuse.gd",
	"treppenhaus": "res://scripts/areale/treppenhaus.gd",
	"ankunft": "res://scripts/areale/ankunft.gd",
	"absturz": "res://scripts/areale/absturz.gd",
	"schleuse_ende": "res://scripts/areale/schleuse_ende.gd"
}

static var infos: Dictionary = {}

## The kit of a piece (a new one: it is built with it).
static func kit(def: String) -> AreaKit:
	var script: GDScript = load(str(SCRIPTS[def]))
	return script.new() as AreaKit

## What a piece says about itself (see AreaKit).
static func info(def: String) -> Dictionary:
	if not infos.has(def):
		infos[def] = kit(def).info()
	return infos[def]

## The pieces that can be built at all (those whose script is there).
static func pool() -> Array[String]:
	var out: Array[String] = []
	for id: String in POOL:
		if ResourceLoader.exists(str(SCRIPTS[id])):
			out.append(id)
	return out

static func transitions() -> Array[String]:
	var out: Array[String] = []
	for id: String in TRANSITIONS:
		if ResourceLoader.exists(str(SCRIPTS[id])):
			out.append(id)
	return out

static func classic() -> Dictionary:
	return {"classic": true, "key": "classic", "seed": 0, "pieces": [], "links": []}

static func opposite(side: int) -> int:
	return (side + 2) % 4

static func heading(side: int) -> Vector2:
	return HiveCore.OUT[side]

## The night of a seed.
static func plan(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hive-areale-%d" % seed_value)
	var want := {}
	var arrival: String = ARRIVALS[rng.randi() % ARRIVALS.size()]
	var count := _weighted(rng, COUNTS)
	var order := pool()
	_shuffle(rng, order)
	want = {"arrival": arrival, "count": mini(count, order.size()), "order": order}
	for attempt in range(ATTEMPTS):
		var night := _attempt(rng, want, seed_value)
		if not night.is_empty():
			night.tries = attempt + 1
			return night
	# What can always be laid: a straight way north, each area entered from the south.
	var straight := _attempt(rng, want, seed_value, true)
	straight.tries = ATTEMPTS + 1
	return straight

## Every area and every transition in one night, for the test room and the checks: the
## crash and its emergency stair, all areas in the order of the pool, and between them
## every kind of transition; beside it a second, short way from the arrival platform to
## a lock of its own.
static func showcase() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var kinds: Array = []
	var all := transitions()
	for i in range(pool().size() + 1):
		kinds.append(all[i % all.size()])
	var want := {"arrival": "absturz", "count": pool().size(), "order": pool(), "kinds": kinds, "keep_order": true}
	var night := {}
	for attempt in range(ATTEMPTS):
		night = _attempt(rng, want, -1)
		if not night.is_empty():
			break
	if night.is_empty():
		night = _attempt(rng, want, -1, true)
	# The second way: the platform, a corridor, a lock.
	var second := {"arrival": "ankunft", "count": 0, "order": [], "kinds": ["buerogang"], "keep_order": true, "start": START + Vector3(0, 0, 230.0), "first": night.pieces.size()}
	var more := {}
	for attempt in range(ATTEMPTS):
		more = _attempt(rng, second, -1, attempt == ATTEMPTS - 1)
		if not more.is_empty():
			break
	for piece: Dictionary in more.pieces:
		piece.chain = 1
		night.pieces.append(piece)
	night.links.append_array(more.links)
	night.key = "showcase"
	night.showcase = true
	night.checkpoint = -1
	return night

static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> int:
	var total := 0
	for key in weights:
		total += int(weights[key])
	var roll := rng.randi_range(1, total)
	for key in weights:
		roll -= int(weights[key])
		if roll <= 0:
			return int(key)
	return int(weights.keys()[0])

static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for k in range(list.size() - 1, 0, -1):
		var other := rng.randi_range(0, k)
		var swap: Variant = list[k]
		list[k] = list[other]
		list[other] = swap

# ---------------------------------------------------------------- laying a night out

## One try at a night. Returns {} if it got stuck. `straight`: only the way that always
## fits (every corridor straight on, every area entered from the south and left to the
## north, no stairs).
static func _attempt(rng: RandomNumberGenerator, want: Dictionary, seed_value: int, straight: bool = false) -> Dictionary:
	var first := int(want.get("first", 0))
	var pieces: Array = []
	var links: Array = []
	var start: Vector3 = want.get("start", START)
	# --- the arrival: its way out lies on START
	var arrival := str(want.arrival)
	var a_info := info(arrival)
	var a_port: Dictionary = _ports(a_info, "out")[0]
	var a_origin := start - Vector3(_port_xz(a_info, a_port).x, float(a_port.y), _port_xz(a_info, a_port).y)
	var head := _piece(first + pieces.size(), arrival, a_info, a_origin, {}, a_port)
	pieces.append(head)
	var order: Array = (want.order as Array).duplicate()
	var count := int(want.count)
	var kinds: Array = want.get("kinds", [])
	var keep_order := bool(want.get("keep_order", false))
	var last_kind := ""
	var stairs_used := 0
	var areas: Array[String] = []
	var cursor: Dictionary = head
	var placed_areas := 0
	var step := 0
	while true:
		var final := placed_areas >= count
		var choices: Array = [END] if final else (order.slice(0, 1) if keep_order else order.duplicate())
		var done := false
		for tries in range(STEP_TRIES):
			if choices.is_empty():
				break
			var def: String = str(choices[0]) if keep_order or final else str(choices[rng.randi() % choices.size()])
			var kind: String = str(kinds[step]) if step < kinds.size() else _pick_kind(rng, last_kind, stairs_used, straight)
			var made := _join(rng, pieces, cursor, kind, def, first, straight)
			if made.is_empty():
				continue
			pieces.append(made.transition)
			pieces.append(made.piece)
			links.append_array(made.links)
			last_kind = kind
			if kind == "treppenhaus":
				stairs_used += 1
			cursor = made.piece
			done = true
			if not final:
				order.erase(def)
				areas.append(def)
				made.piece.area_index = placed_areas
				placed_areas += 1
			break
		if not done:
			return {}
		step += 1
		if final:
			break
	var key := "s%d" % seed_value if seed_value >= 0 else "showcase"
	return {
		"classic": false, "seed": seed_value, "key": key, "arrival": arrival, "areas": areas, "pieces": pieces, "links": links,
		"checkpoint": int(areas.size() / 2) if areas.size() >= 3 else -1, "tries": 0
	}

static func _pick_kind(rng: RandomNumberGenerator, last: String, stairs_used: int, straight: bool) -> String:
	var options: Array[String] = []
	for id in transitions():
		if id == last:
			continue
		if id == "treppenhaus" and (stairs_used >= 2 or straight):
			continue
		options.append(id)
	if options.is_empty():
		options = transitions()
	return options[rng.randi() % options.size()]

## The ports of a piece of one role ("in" or "out"; "both" counts for either).
static func _ports(piece_info: Dictionary, role: String) -> Array:
	var out: Array = []
	for port: Dictionary in piece_info.get("ports", []):
		if str(port.role) == role or str(port.role) == "both":
			out.append(port)
	return out

static func _port_xz(piece_info: Dictionary, port: Dictionary) -> Vector2:
	var spot := AreaKit.port_spot(Vector3.ZERO, piece_info.size, port)
	return Vector2(spot.x, spot.z)

static func _piece(index: int, def: String, piece_info: Dictionary, origin: Vector3, in_port: Dictionary, out_port: Dictionary) -> Dictionary:
	var size: Vector2 = piece_info.size
	var heights: Array = []
	for level in piece_info.get("levels", [0.0]):
		heights.append(snappedf(origin.y + float(level), 0.01))
	var parts: Array = [Rect2(origin.x, origin.z, size.x, size.y)]
	for extra: Rect2 in piece_info.get("reach", []):
		parts.append(Rect2(origin.x + extra.position.x, origin.z + extra.position.y, extra.size.x, extra.size.y))
	return {
		"id": "p%d" % index, "def": def, "kind": str(piece_info.kind), "index": index, "origin": origin, "size": size,
		"in": in_port, "out": out_port, "parts": parts, "heights": heights, "chain": 0, "area_index": -1,
		"rooms": [], "points": {}, "shape": {}
	}

## Joins the next piece (`def`) to `cursor` through a transition of `kind`: the
## transition and the piece in their places and the doorways between them, or {} where
## nothing fits.
static func _join(rng: RandomNumberGenerator, pieces: Array, cursor: Dictionary, kind: String, def: String, first: int, straight: bool) -> Dictionary:
	var cursor_info := info(str(cursor.def))
	var next_info := info(def)
	var t_info := info(kind)
	# Which way out of the cursor: a port of its own (an arrival's is given).
	var outs: Array = [cursor.out] if not (cursor.out as Dictionary).is_empty() else _ports(cursor_info, "out")
	if (cursor.out as Dictionary).is_empty():
		var used_in: Dictionary = cursor["in"]
		outs = outs.filter(func(port: Dictionary) -> bool: return not (int(port.side) == int(used_in.get("side", -1)) and absf(float(port.at) - float(used_in.get("at", -99.0))) < 0.01 and absf(float(port.y) - float(used_in.get("y", -99.0))) < 0.01))
		if straight:
			outs = outs.filter(func(port: Dictionary) -> bool: return int(port.side) == HiveCore.NORTH)
	if outs.is_empty():
		return {}
	var out_port: Dictionary = outs[rng.randi() % outs.size()]
	var from := AreaKit.port_spot(cursor.origin, cursor.size, out_port)
	var s1 := int(out_port.side)
	# Never back south: the way goes on north, east or west.
	if s1 == HiveCore.SOUTH and not straight:
		return {}
	var ins: Array = _ports(next_info, "in")
	if straight:
		ins = ins.filter(func(port: Dictionary) -> bool: return int(port.side) == HiveCore.SOUTH)
	if ins.is_empty():
		return {}
	var in_port: Dictionary = ins[rng.randi() % ins.size()]
	var end_side := opposite(int(in_port.side))
	var bend := end_side != s1
	if bend and (straight or not bool(t_info.get("bends", true)) or end_side == opposite(s1)):
		return {}
	# The height on the far side of the transition.
	var rise := 0.0
	if float(t_info.get("rise", 0.0)) > 0.0:
		var up := from.y + LIFT
		var down := from.y - LIFT
		var can_up := up <= HIGHEST + 0.01
		var can_down := down >= LOWEST - 0.01
		if can_up and can_down:
			rise = LIFT if rng.randf() < 0.5 else -LIFT
		elif can_up:
			rise = LIFT
		elif can_down:
			rise = -LIFT
		else:
			return {}
	var lengths: Array = t_info.get("lengths", [10.0, 24.0])
	var l1 := rng.randf_range(float(lengths[0]), float(lengths[1]))
	var l2 := rng.randf_range(float(lengths[0]), float(lengths[1]))
	if bend:
		l1 = maxf(l1, float(t_info.width) + 8.0)
	var shape := shape_of(kind, t_info, Vector2(from.x, from.z), from.y, s1, end_side if bend else -1, snappedf(l1, 0.5), snappedf(l2, 0.5), rise)
	var end_xz: Vector2 = shape.end
	var end_y := from.y + rise
	var base := end_y - float(in_port.y)
	if base < LOWEST - 0.01 or base > HIGHEST + 0.01:
		return {}
	var top := base
	for level in next_info.get("levels", [0.0]):
		top = maxf(top, base + float(level))
	if top > TOP + 0.01:
		return {}
	var port_xz := _port_xz(next_info, in_port)
	var origin := Vector3(end_xz.x - port_xz.x, base, end_xz.y - port_xz.y)
	var transition := {
		"id": "p%d" % (first + pieces.size()), "def": kind, "kind": "transition", "index": first + pieces.size(), "origin": Vector3(0, from.y, 0), "size": Vector2.ZERO,
		"in": {}, "out": {}, "parts": shape.parts, "heights": [snappedf(from.y, 0.01), snappedf(end_y, 0.01)], "chain": 0, "area_index": -1,
		"rooms": [], "points": {}, "shape": shape, "room_in": str(shape.room_in), "room_out": str(shape.room_out)
	}
	var piece := _piece(first + pieces.size() + 1, def, next_info, origin, in_port, {})
	piece.event = choose_event(rng, next_info)
	# Does it fit: not on anything that is there, and nothing of it too far west.
	for part: Rect2 in (transition.parts as Array) + (piece.parts as Array):
		if part.position.x < WEST:
			return {}
	for part: Rect2 in transition.parts:
		for other: Dictionary in pieces:
			var joined: bool = other == cursor
			if _clashes(part, other.parts, 0.0 if joined else APART):
				return {}
	for part: Rect2 in piece.parts:
		for other: Dictionary in pieces:
			if _clashes(part, other.parts, APART):
				return {}
		for mine: Rect2 in transition.parts:
			# (The transition's own rooms touch the piece where they meet; nothing else does.)
			if part.grow(-0.05).intersects(mine):
				return {}
	cursor.out = out_port
	var links: Array = []
	# The doorway from the cursor into the transition, and from the transition into the piece.
	var out_room := str(cursor.get("room_out", "")) if str(cursor.kind) == "transition" else str(out_port.room)
	links.append({"a": cursor.id, "a_room": out_room, "b": transition.id, "b_room": str(transition.room_in), "side": s1, "spot": from, "name": "%s_out" % cursor.id, "open": bool(out_port.get("open", false))})
	links.append({"a": transition.id, "a_room": str(transition.room_out), "b": piece.id, "b_room": str(in_port.room), "side": end_side, "spot": Vector3(end_xz.x, end_y, end_xz.y), "name": "%s_in" % piece.id, "open": true})
	return {"transition": transition, "piece": piece, "links": links}

static func _clashes(part: Rect2, others: Array, gap: float) -> bool:
	for other: Rect2 in others:
		if gap <= 0.0:
			if part.grow(-0.05).intersects(other.grow(-0.05)):
				return true
		elif part.grow(gap * 0.5).intersects(other.grow(gap * 0.5)):
			return true
	return false

# ---------------------------------------------------------------- what is to be done in an area

## The kinds of objective an area can have (see HiveDirector: what each wants done). No
## area is only walked through: each has a reason to stay and fight before its way out
## opens.
##   collect   find and pick up so many things that lie about the area (spots.items)
##   hack      a door is opened from a terminal: [E] there, then hold near it while it
##             works and more of them come (spots.goal)
##   restore   switch on two or three things (pumps, breakers) at their places
##             (spots.switches), then a short hold while it comes up
##   hold      stay at a place until the progress is full (spots.goal)
##   lockdown  the doors shut behind the squad, hold until they open again (spots.goal)
##   clear     every one of its guards has to fall (posts)
const OBJECTIVES := ["collect", "hack", "restore", "hold", "lockdown", "clear"]

## One of the objectives an area allows (its "events"), for the night of `rng`; which of
## its spots are used is diced too.
static func choose_event(rng: RandomNumberGenerator, piece_info: Dictionary) -> Dictionary:
	var events: Array = piece_info.get("events", [])
	if events.is_empty():
		return {}
	var event: Dictionary = (events[rng.randi() % events.size()] as Dictionary).duplicate(true)
	var spots: Dictionary = piece_info.get("spots", {})
	match str(event.kind):
		"collect":
			var places: Array = range((spots.get("items", []) as Array).size())
			_shuffle(rng, places)
			event.items = places.slice(0, mini(int(event.get("count", 3)), places.size()))
		"restore":
			var places: Array = range((spots.get("switches", []) as Array).size())
			_shuffle(rng, places)
			event.switches = places.slice(0, mini(int(event.get("count", 2)), places.size()))
	return event

## What is wrong with the objective of an area (empty: it can be done): its kind is
## known, and what it needs is there and lies inside the area.
static func event_faults(piece_info: Dictionary, event: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var kind := str(event.get("kind", ""))
	if not OBJECTIVES.has(kind):
		out.append("unknown objective '%s'" % kind)
		return out
	var spots: Dictionary = piece_info.get("spots", {})
	var size: Vector2 = piece_info.size
	match kind:
		"collect":
			if (event.get("items", []) as Array).size() < 2:
				out.append("collect without two things to find")
			for index: int in event.get("items", []):
				if not _inside(spots.items[index], size):
					out.append("a thing to find lies outside")
		"restore":
			if (event.get("switches", []) as Array).size() < 2:
				out.append("restore without two places")
			for index: int in event.get("switches", []):
				if not _inside(spots.switches[index], size):
					out.append("a switch lies outside")
		"clear":
			if (piece_info.get("posts", []) as Array).size() < 3:
				out.append("clear without guards")
		_:
			if not spots.has("goal") or not _inside(spots.goal, size):
				out.append("%s without a place" % kind)
			if float(event.get("seconds", 0.0)) <= 0.0:
				out.append("%s without seconds" % kind)
	return out

static func _inside(spot: Vector3, size: Vector2) -> bool:
	return spot.x > 0.5 and spot.z > 0.5 and spot.x < size.x - 0.5 and spot.z < size.y - 0.5

# ---------------------------------------------------------------- the shape of a transition

## The rooms of a transition between a doorway at `from` (on the wall line of the piece
## behind it, which it leaves heading `s1`) and the piece ahead: one leg straight on, or
## two with a bend towards `s2`. A stairwell is three: a flat stretch, the stairs, a flat
## stretch. Returns {legs: [{name, rect, along}], rooms beside them ({name, rect, side,
## leg}), shaft, end (where its last doorway is), end_side, room_in, room_out, parts}.
static func shape_of(kind: String, t_info: Dictionary, from: Vector2, height: float, s1: int, s2: int, l1: float, l2: float, rise: float) -> Dictionary:
	var wide := float(t_info.width)
	var legs: Array = []
	var shaft := {}
	var end := Vector2.ZERO
	var end_side := s1
	var h1 := heading(s1)
	if rise != 0.0:
		# Flat, the stairs, flat: all in one line.
		var run := float(t_info.get("shaft", 18.0))
		var a := maxf(6.0, l1 * 0.5)
		var b := maxf(6.0, l2 * 0.5)
		legs.append({"name": "unten" if rise > 0.0 else "oben", "rect": _leg(from, s1, a, wide), "side": s1, "y": height, "length": a, "start": from})
		shaft = {"rect": _leg(from + h1 * a, s1, run, float(t_info.get("shaft_wide", wide))), "side": s1, "from": from + h1 * a, "run": run, "low": height if rise > 0.0 else height + rise, "high": height + rise if rise > 0.0 else height, "rise": rise}
		legs.append({"name": "oben" if rise > 0.0 else "unten", "rect": _leg(from + h1 * (a + run), s1, b, wide), "side": s1, "y": height + rise, "length": b, "start": from + h1 * (a + run)})
		end = from + h1 * (a + run + b)
	elif s2 < 0 and t_info.has("chamber"):
		# A lock: a stretch of corridor, the chamber between its two doors, a stretch.
		var room_long := float(t_info.chamber)
		var a := maxf(5.0, snappedf((l1 - room_long) * 0.5, 0.5))
		legs.append({"name": "gang1", "rect": _leg(from, s1, a, wide), "side": s1, "y": height, "length": a, "start": from})
		legs.append({"name": "kammer", "rect": _leg(from + h1 * a, s1, room_long, wide), "side": s1, "y": height, "length": room_long, "start": from + h1 * a})
		legs.append({"name": "gang2", "rect": _leg(from + h1 * (a + room_long), s1, a, wide), "side": s1, "y": height, "length": a, "start": from + h1 * (a + room_long)})
		end = from + h1 * (a * 2.0 + room_long)
	elif s2 < 0:
		legs.append({"name": "gang1", "rect": _leg(from, s1, l1, wide), "side": s1, "y": height, "length": l1, "start": from})
		end = from + h1 * l1
	else:
		var h2 := heading(s2)
		var corner := from + h1 * (l1 - wide * 0.5)
		var second := corner + h2 * (wide * 0.5)
		legs.append({"name": "gang1", "rect": _leg(from, s1, l1, wide), "side": s1, "y": height, "length": l1, "corner": corner, "turn": s2, "start": from})
		legs.append({"name": "gang2", "rect": _leg(second, s2, l2, wide), "side": s2, "y": height, "length": l2, "start": second})
		end = second + h2 * l2
		end_side = s2
	# The rooms beside the legs (laboratories, offices): not near either end of a leg nor
	# near a bend, where the next leg's rooms would be.
	var beside: Array = []
	var deep := float(t_info.get("beside", 0.0))
	if deep > 0.0 and rise == 0.0:
		for index in range(legs.size()):
			var leg: Dictionary = legs[index]
			var lead := 3.0 + (deep + 1.0 if index > 0 else 0.0)
			var tail := 3.0 + (wide + deep + 1.0 if leg.has("corner") else 0.0)
			var usable := float(leg.length) - lead - tail
			var cells := int(floor(usable / float(t_info.get("beside_long", 8.0))))
			if cells < 1:
				continue
			var long := usable / cells
			for cell in range(cells):
				for flank in [-1, 1]:
					var rect := _beside_rect(leg, leg.start, lead + cell * long, long, wide, deep, flank)
					beside.append({"name": "%s_%s%d" % [str(leg.name), "l" if flank < 0 else "r", cell], "rect": rect, "leg": str(leg.name), "flank": flank, "side": _flank_side(int(leg.side), flank)})
	var parts: Array = []
	for leg: Dictionary in legs:
		parts.append(leg.rect)
	if not shaft.is_empty():
		parts.append(shaft.rect)
	for room: Dictionary in beside:
		parts.append(room.rect)
	return {
		"kind": kind, "legs": legs, "beside": beside, "shaft": shaft, "end": end, "end_side": end_side, "width": wide,
		"room_in": str(legs[0].name), "room_out": str(legs[legs.size() - 1].name), "parts": parts, "from": from, "y": height, "rise": rise
	}

## A straight piece of corridor that starts on a wall line at `from` and runs `long`
## metres the way `side` looks, `wide` across.
static func _leg(from: Vector2, side: int, long: float, wide: float) -> Rect2:
	match side:
		HiveCore.NORTH:
			return Rect2(from.x - wide * 0.5, from.y - long, wide, long)
		HiveCore.SOUTH:
			return Rect2(from.x - wide * 0.5, from.y, wide, long)
		HiveCore.EAST:
			return Rect2(from.x, from.y - wide * 0.5, long, wide)
	return Rect2(from.x - long, from.y - wide * 0.5, long, wide)

## The side of a leg on its left (-1) or right (+1), looking the way it runs.
static func _flank_side(side: int, flank: int) -> int:
	return (side + (1 if flank > 0 else 3)) % 4

static func _beside_rect(leg: Dictionary, start: Vector2, offset: float, long: float, wide: float, deep: float, flank: int) -> Rect2:
	var side := int(leg.side)
	var dir := heading(side)
	var across := heading(_flank_side(side, flank))
	var a := start + dir * offset + across * (wide * 0.5)
	var b := start + dir * (offset + long) + across * (wide * 0.5 + deep)
	return Rect2(minf(a.x, b.x), minf(a.y, b.y), absf(b.x - a.x), absf(b.y - a.y))

# ---------------------------------------------------------------- what a night is

## Every height the pieces of a night have floors at, and for each the pieces on it.
static func heights_of(night: Dictionary) -> Dictionary:
	var out := {}
	for piece: Dictionary in night.get("pieces", []):
		for h in piece.heights:
			var key := snappedf(float(h), 0.01)
			if not out.has(key):
				out[key] = []
			(out[key] as Array).append(piece)
	return out

## True for a height of the lattice the pieces are joined on (their floors at BASE and
## LIFT steps from it): a floor there is shared by all pieces; the storeys between are a
## piece's own.
static func shared_height(h: float) -> bool:
	var steps := (BASE - h) / LIFT
	return absf(steps - roundf(steps)) < 0.01

## What a night says about itself, in one line (for the checks and the bot).
static func describe(night: Dictionary) -> String:
	if bool(night.get("classic", false)):
		return "classic"
	var parts: Array[String] = []
	for piece: Dictionary in night.pieces:
		if int(piece.get("chain", 0)) != 0:
			continue
		parts.append("%s@%d" % [str(piece.def), int(round(float((piece.origin as Vector3).y)))] if str(piece.kind) != "transition" else "(%s)" % str(piece.def))
	return "seed=%d %s" % [int(night.seed), " ".join(PackedStringArray(parts))]

## The problems of a night, as words (an empty list: it is a good one). Checks the plan
## only, not a map: pieces that lie on each other, a part too far west, heights out of
## range, a way that is not joined from the arrival to the end.
static func faults(night: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if bool(night.get("classic", false)):
		return out
	var pieces: Array = night.pieces
	if pieces.is_empty():
		out.append("no pieces")
		return out
	var by_id := {}
	for piece: Dictionary in pieces:
		by_id[piece.id] = piece
	var joined := {}
	for link: Dictionary in night.links:
		joined["%s|%s" % [link.a, link.b]] = true
		joined["%s|%s" % [link.b, link.a]] = true
		if not by_id.has(link.a) or not by_id.has(link.b):
			out.append("link to a piece that is not there: %s" % str(link.name))
	for i in range(pieces.size()):
		var first: Dictionary = pieces[i]
		for part: Rect2 in first.parts:
			if part.position.x < WEST:
				out.append("%s lies too far west" % str(first.id))
		for h in first.heights:
			if float(h) < LOWEST - 0.01 or float(h) > TOP + 0.01:
				out.append("%s has a floor at %.1f" % [str(first.id), float(h)])
		for j in range(i + 1, pieces.size()):
			var second: Dictionary = pieces[j]
			var gap := 0.0 if joined.has("%s|%s" % [first.id, second.id]) else APART - 0.01
			for part: Rect2 in first.parts:
				if _clashes(part, second.parts, gap):
					out.append("%s and %s lie on each other" % [str(first.id), str(second.id)])
					break
	# One way from the first piece of each chain to its last: every piece once, in order.
	for chain in [0, 1]:
		var members: Array = pieces.filter(func(piece: Dictionary) -> bool: return int(piece.get("chain", 0)) == chain)
		if members.is_empty():
			continue
		if str(members[0].kind) != "arrival":
			out.append("chain %d does not begin with an arrival" % chain)
		if str(members[members.size() - 1].def) != END:
			out.append("chain %d does not end in the lock" % chain)
		for k in range(members.size() - 1):
			if not joined.has("%s|%s" % [members[k].id, members[k + 1].id]):
				out.append("%s and %s are not joined" % [str(members[k].id), str(members[k + 1].id)])
	# Every area has something to be done there, and it can be done.
	for piece: Dictionary in pieces:
		if str(piece.kind) == "area":
			for fault in event_faults(info(str(piece.def)), piece.get("event", {})):
				out.append("%s (%s): %s" % [str(piece.id), str(piece.def), fault])
	var seen := {}
	for def: String in night.get("areas", []):
		if seen.has(def):
			out.append("%s twice" % def)
		seen[def] = true
	return out
