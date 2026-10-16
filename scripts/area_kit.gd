class_name AreaKit
extends RefCounted
## The building kit of a piece of the random part of mission two (see HiveLayout): an
## area ("Areal"), a transition between two areas, the arrival after the train ride or the
## lock at the end. Every piece is a script of its own in scripts/areale that extends this
## kit and says two things:
##
##   info()  what the piece is - its CONTRACT, read without any map (see below);
##   lay()   builds it into the map (HiveMap) where HiveLayout has placed it.
##
## A piece is built in its own frame: x and z in metres from the north-west corner of its
## footprint (x east, z south, as everywhere: north is -z), y in metres above its floor
## (its base). The kit turns that into the world: p(), r(), along(). Pieces are never
## turned, only moved, so the sides of a room stay what they are (HiveCore.NORTH ...).
##
## THE CONTRACT of an area (info()):
##   id, kind      "area" (also "transition", "arrival", "end")
##   label         what the HUD calls the place (German), name: the button of the test room
##   size          Vector2(w, d): its footprint, x by z (nothing of it reaches out of it)
##   class         "klein", "mittel" or "gross"
##   levels        heights of its floors above its base: 0.0, and 4.2 / 8.4 for the levels
##                 above (HiveLayout.STOREY); 8.4 is a level the next piece can go on from
##   ports         where the squad comes in and goes out, each {side, at, y, room, role}:
##                 a doorway (PORT_WIDE x PORT_TALL, like the gates of the facility) in the
##                 wall of `room` on `side` (`at` along it), `y` its height (0.0 or 8.4),
##                 role "in", "out" or "both". The way from every "in" port to every "out"
##                 port must be walkable (the checks walk it).
##   mood          the light and haze of the place (HiveCore.MOODS)
##   events        what may have to be done there before its way out opens - one of them
##                 is diced for a night (HiveLayout.choose_event, OBJECTIVES; no area is
##                 only walked through): {kind, goal (the HUD's words), ...}
##                   collect  {count, word, use}: pick up `count` of spots.items
##                   hack     {use, seconds, progress, radius}: [E] at spots.goal, hold near it
##                   restore  {count, use, after, progress}: [E] at `count` of spots.switches
##                   hold     {seconds, progress, radius}: stay near spots.goal
##                   lockdown {seconds, progress}: doors shut behind, hold near spots.goal
##                   clear    {}: every one of `posts` falls
##   spots         where its objectives happen (local): goal, switches [...], items [...]
##   crowd         who keeps coming while the squad is there (as HiveDirector.PRESSURE:
##                 kinds, alive at once, seconds between, pack size [least, most])
##   posts         who waits in it: [[kind, local point], ...]
##   strength      how strong its infected are (as a round of the first mission)
##   lines         what is said on entering it and at its event (cues that exist in Radio):
##                 {"enter": ["talk:m2_water"], "event": ["line:m2_lockdown"]}
##   caches        cache sites as HiveCaches.SITES, but local: [name, room, side, at, look,
##                 title] (at along that wall, local)
##   station       an optional stop (workbench and equipment): [room, side, [[look, at], ...]]
##   supply        an optional supply point: [local point on the floor, facing (Vector3)]
## lay() builds its rooms (room()), what joins them (door(), pane(), stairs()), its ways
## in (the map's _way_* builders), names its points (point()), and may add water
## (water()). The doorways of its ports are made by HiveLayout, not by lay().
##
## A transition says the same and more (see HiveLayout.shape): its corridor width and
## height, how long its legs may be, whether it may bend, and its rise (stairs).

const NORTH := HiveCore.NORTH
const EAST := HiveCore.EAST
const SOUTH := HiveCore.SOUTH
const WEST := HiveCore.WEST
## The doorway of every port: as wide and as tall as the gates of the facility's locks.
const PORT_WIDE := 3.0
const PORT_TALL := HiveCore.DOOR_TALL

var m: HiveMap
## The piece as HiveLayout has placed it: id, def, origin, size, in / out ports, ...
var piece: Dictionary = {}
## Its north-west corner on its base.
var o := Vector3.ZERO

## What the piece is (see above). The kit's own answer is a plain empty room.
func info() -> Dictionary:
	return {}

## Builds the piece into the map.
func lay() -> void:
	pass

# ---------------------------------------------------------------- the frame

func p(x: float, y: float, z: float) -> Vector3:
	return o + Vector3(x, y, z)

func r(x: float, z: float, w: float, d: float) -> Rect2:
	return Rect2(o.x + x, o.z + z, w, d)

## A place along a wall of a side: x for a wall that runs east-west, z otherwise.
func along(side: int, local: float) -> float:
	return (o.x if side == NORTH or side == SOUTH else o.z) + local

## The name a room of this piece has in the map.
func n(name: String) -> String:
	return "%s_%s" % [str(piece.id), name]

## The floor of the map that a height of this piece stands on.
func lv(height: float) -> int:
	return m.area_floor(o.y + height, piece)

func y(height: float) -> float:
	return o.y + height

# ---------------------------------------------------------------- rooms and what joins them

## A room of the piece: its rectangle in the piece's frame, at a height of it.
func room(name: String, height: float, x: float, z: float, w: float, d: float, tall: float, style: String, options: Dictionary = {}) -> Dictionary:
	var made := m._room(n(name), lv(height), r(x, z, w, d), tall, style, options)
	(piece.rooms as Array).append(n(name))
	return made

## Rectangles of the piece's frame as walk rectangles of a room (the option "walk").
func walks(rects: Array) -> Array:
	var out: Array = []
	for rect: Rect2 in rects:
		out.append(Rect2(rect.position + Vector2(o.x, o.z), rect.size))
	return out

func door(a: String, b: String, at: float, width: float = 2.0, options: Dictionary = {}) -> Dictionary:
	var first: Dictionary = m.room_of[n(a)]
	var side := m._shared_side(first, m.room_of[n(b)])
	return m._door(n(a), n(b), along(side, at), width, options)

func opening(a: String, side: int, at: float, width: float = 2.0, options: Dictionary = {}) -> Dictionary:
	return m._opening(n(a), side, along(side, at), width, options)

func pane(a: String, side: int, at: float, width: float, sill: float, head: float, kind: String = "glass", through: String = "") -> void:
	m._pane(n(a), side, along(side, at), width, sill, head, kind, n(through) if through != "" else "")

## Steps from `foot` up to `head` (local points on their treads), with rails at both
## sides, and the way over them for the paths (from `land_low` on the lower floor to
## `land_high` on the upper one).
func stairs(foot: Vector3, head: Vector3, width: float, land_low: Vector3, land_high: Vector3, rails: bool = true) -> void:
	m._chunk("Stairs", false)
	m._steps(o + foot, o + head, width, "tread", Color(0.42, 0.44, 0.46))
	if rails:
		m._handrail(o + foot, o + head, width * 0.5 - 0.02)
		m._handrail(o + foot, o + head, -(width * 0.5 - 0.02))
	m._link(PackedVector3Array([o + land_low, o + foot, o + head, o + land_high]), width, lv(land_low.y), lv(land_high.y))

## A floor of steel on posts at a level above the base (a gallery, a catwalk, a bridge)
## over a rectangle of the piece, with railings along the given sides ([side, from, to]
## in the frame of the piece). Its posts stand on the base floor where it says.
func deck(rect: Rect2, height: float, rails_at: Array = [], posts: Array = []) -> void:
	var world_rails: Array = []
	for entry: Array in rails_at:
		var side := int(entry[0])
		world_rails.append([side, along(side, float(entry[1])), along(side, float(entry[2]))])
	m._chunk("Kit", false)
	m._deck_floor(r(rect.position.x, rect.position.y, rect.size.x, rect.size.y), y(height), y(0.0), world_rails)
	for spot: Vector2 in posts:
		post(spot, height)

## A steel post from the base floor up to a level.
func post(spot: Vector2, height: float, thick: float = 0.26) -> void:
	var middle := p(spot.x, height * 0.5 - 0.1, spot.y)
	m._part("plate", middle, Vector3(thick, height - 0.2, thick), Color("1d2124"))
	m._solid(middle, Vector3(thick, height - 0.2, thick))

## A railing along a line of the piece (bodies stop, shots pass).
func railing(from: Vector3, to: Vector3) -> void:
	m._chunk("Kit", false)
	m._guard_rail(o + from, o + to)

## A box to look at and to bump into, in the frame of the piece (middle and size).
func block(material: String, centre: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	m._part(material, o + centre, size, color)
	if solid:
		m._solid(o + centre, size)

## A box that only glows.
func glow(centre: Vector3, size: Vector3, color: Color, strength: float = 4.0) -> void:
	m._glow_box(o + centre, size, color, strength)

func light(at: Vector3, color: Color, energy: float, reach: float, flicker: float = 0.0) -> OmniLight3D:
	return m._light(o + at, color, energy, reach, false, flicker, 0.4, HiveCore.LAMP_FADE)

## Lettering on a wall of a room of the piece.
func stencil(room_name: String, side: int, at: float, high: float, text: String, size: int = 120, color: Color = Color(0.2, 0.22, 0.24)) -> void:
	m._stencil(n(room_name), side, along(side, at), high, text, size, color)

## A named place of the piece (local); its key in the map's points is "<piece>_<key>".
func point(key: String, at: Vector3, yaw: float = 0.0) -> void:
	var world := o + at
	(piece.points as Dictionary)[key] = world
	m.areal_points["%s_%s" % [str(piece.id), key]] = world
	m.areal_facings["%s_%s" % [str(piece.id), key]] = yaw

## Water in a basin of the piece: its surface lies `surface` above the base (below 0: a
## pool beside walkways), its floor `bottom` above the base. `deep`: whoever stands on
## its floor is in deep water (HiveCore.waters: slow, it hurts, [Leertaste] climbs out on
## to the nearest walkway). A basin is a pit: what lies under the water is not walked on.
func water(rect: Rect2, surface: float, bottom: float, deep: bool = true) -> void:
	m._areal_water(r(rect.position.x, rect.position.y, rect.size.x, rect.size.y), y(surface), y(bottom), deep)

# ---------------------------------------------------------------- ways in

## The map's builders of ways in open and close the zone of their room themselves; while
## a piece is built its zone is open, so it is closed around them and opened again (or
## what was built before them would be left outside the zone).
func _around(build: Callable) -> void:
	m._end_zone()
	build.call()
	m._begin_zone(str(piece.id))
	m._chunk("Kit", false)

## A hole in the ceiling of a room (local x, z); `land`: the height above the room's
## floor they come down on (a gallery).
func drop(room_name: String, x: float, z: float, turn: int = 0, options: Dictionary = {}) -> void:
	_around(func() -> void: m._way_drop(n(room_name), o.x + x, o.z + z, turn, options))

## A hole at the foot of a wall ("breach", "vent", "pipes"): only where nothing lies behind.
func hole(room_name: String, side: int, at: float, skin: String = "breach") -> void:
	_around(func() -> void: m._way_hole(n(room_name), side, along(side, at), skin))

## The mouth of a duct high in a wall.
func duct(room_name: String, side: int, at: float, options: Dictionary = {}) -> void:
	_around(func() -> void: m._way_duct(n(room_name), side, along(side, at), options))

## A torn-open wall with a cavity behind it.
func breach(room_name: String, side: int, at: float, turn: float = 1.0) -> void:
	_around(func() -> void: m._way_breach(n(room_name), side, along(side, at), turn))

## A pit in the floor they crawl out of.
func trench(room_name: String, x: float, z: float, turn: int = 0) -> void:
	_around(func() -> void: m._way_trench(n(room_name), o.x + x, o.z + z, turn))

## An edge they climb over (`at` on it, `into` the way on to the floor; `deep` below).
func edge(room_name: String, at: Vector3, into: Vector3, deep: float = 1.1) -> void:
	_around(func() -> void: m._way_edge(n(room_name), o + at, into, deep))

## A housing under whatever is overhead at `at` (no room's ceiling): they land on `land`.
func hang(at: Vector3, land: Vector3, turn: int = 0) -> void:
	_around(func() -> void: m._way_hang(str(piece.id), o + at, o + land, turn, o + land + Vector3(3.0, 1.6, 3.0)))

## Builds something in a zone of its own beside the piece's (the car the train ride ends
## in: it stays drawn while the piece around it is not, see HiveMap.ride_areal).
func in_zone(suffix: String, mood: String, build: Callable) -> void:
	m._end_zone()
	m._begin_zone("%s_%s" % [str(piece.id), suffix], mood)
	build.call()
	m._end_zone()
	m._begin_zone(str(piece.id))
	m._chunk("Kit", false)

## The tunnel the train seems to run through on the way to this piece's car (`centre`,
## local): drawn only during the ride (HiveMap.ride_areal).
func ride_tunnel(centre: Vector3) -> void:
	m._end_zone()
	var lamps := HiveAreale.ride_tunnel(m, "%s_ride" % str(piece.id), o + centre)
	m.areal_rides[str(piece.id)] = {"zone": "%s_ride" % str(piece.id), "lamps": lamps, "car": o + centre}
	m._begin_zone(str(piece.id))
	m._chunk("Kit", false)

## A cache site, a stop, a supply point (built by HiveAreale from info(); nothing to do
## here) - and a slab to walk on that is no room's floor: a walkway, a landing.
func slab(rect: Rect2, height: float, material: String = "tread", color: Color = Color(0.42, 0.44, 0.46), thick: float = 0.3) -> void:
	var centre := p(rect.get_center().x, height - thick * 0.5, rect.get_center().y)
	var size := Vector3(rect.size.x, thick, rect.size.y)
	m._part(material, centre, size, color)
	m._solid(centre, size, false)

# ---------------------------------------------------------------- what the generator reads

## The ports of the piece in the world, as HiveLayout places them: its doorway's middle
## on the wall line, its height, and the way it looks out.
static func port_spot(origin: Vector3, size: Vector2, port: Dictionary) -> Vector3:
	var at := float(port.at)
	match int(port.side):
		NORTH:
			return origin + Vector3(at, float(port.y), 0.0)
		SOUTH:
			return origin + Vector3(at, float(port.y), size.y)
		WEST:
			return origin + Vector3(0.0, float(port.y), at)
	return origin + Vector3(size.x, float(port.y), at)

## A step into the piece from a port: where somebody who has just come through it stands.
static func port_inside(origin: Vector3, size: Vector2, port: Dictionary, depth: float = 2.6) -> Vector3:
	var out: Vector2 = HiveCore.OUT[int(port.side)]
	return port_spot(origin, size, port) - Vector3(out.x, 0.0, out.y) * depth
