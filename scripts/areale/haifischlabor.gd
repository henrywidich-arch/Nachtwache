extends AreaKit
## Area: the flooded shark laboratory (after the user's concept pictures in
## D:\Games\AI Games\Nachtwache\pepepe\Nachtwache_Haifischlabor_2026-10-12). GREYBOX: the
## playable layout only; another helper builds its looks and its sharks later.
##
## A hall of 56 x 48 metres and 12 high whose floor is one deep basin. The way over it is
## low walkways of steel and concrete, their tops 20 cm over the water (SURFACE): along
## the south wall where one comes in, along the west wall, under the observation rooms
## along the north wall to the exit, and a causeway down the east side whose middle lies
## a few centimetres under water. From the west walkway a narrow connector (1.4 m) leads
## to an island in the middle with the pumps, and on to the causeway. In the north-east
## corner the pump platform lies before the way out, and a steel stair leads from it up
## to three observation rooms behind glass (level 4.2) that look down on the basin.
##
## The water: whoever leaves a walkway stands in deep water (HiveAreale: he wades slowly,
## after a moment it hurts, a jump at the edge pulls him back up). No railing keeps him
## from it - as in the pictures, most of them are gone; stumps show where they were.
## The infected never walk into it; one that is pushed in is gone (the sharks).
##
## For the helper who builds it in detail: the walkways are WALKS (rectangles of the
## frame) and slabs; the water is one basin (water()); the observation rooms are rooms
## on the level 4.2 of this piece; ports, spots, posts, caches and the stop are in info().

const SURFACE := -0.2
const BOTTOM := -1.6
## The walkways, in the frame of the piece (x, z, w, d).
const WALKS := [
	Rect2(0.2, 44.6, 55.6, 3.2),    # south, where one comes in
	Rect2(0.2, 3.2, 3.0, 41.4),     # west, along the wall
	Rect2(0.2, 0.2, 36.0, 3.0),     # north, under the observation rooms
	Rect2(36.2, 0.2, 19.6, 9.0),    # the pump platform before the way out
	Rect2(3.2, 25.2, 16.8, 1.6),    # the narrow connector to the island
	Rect2(20.0, 20.0, 14.0, 12.0),  # the island with the pumps
	Rect2(34.0, 25.2, 14.0, 1.6),   # from the island to the causeway
	Rect2(48.0, 9.2, 2.4, 35.4)     # the causeway down the east side
]
## Where the causeway lies under water (z from, to).
const SUNKEN := [20.0, 31.0]

func info() -> Dictionary:
	return {
		"id": "haifischlabor", "kind": "area", "label": "HAIFISCHLABOR", "name": "Haifischlabor (geflutet)", "class": "gross",
		"size": Vector2(56.0, 48.0), "levels": [0.0, 4.2], "mood": "water",
		"ports": [
			{"side": SOUTH, "at": 8.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": WEST, "at": 20.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": NORTH, "at": 48.0, "y": 0.0, "room": "halle", "role": "out"},
			{"side": EAST, "at": 46.2, "y": 0.0, "room": "halle", "role": "out"}
		],
		"events": [
			{"kind": "restore", "goal": "Die Pumpen anwerfen, damit das Schott aufgeht", "use": "[E] Pumpe anwerfen", "count": 2, "after": 20.0, "progress": "PUMPEN LAUFEN AN"},
			{"kind": "collect", "goal": "Die Sicherungen für das Schott finden", "word": "Sicherung", "use": "[E] Sicherung nehmen", "count": 3},
			{"kind": "hack", "goal": "Das Schott an der Pumpenplattform knacken lassen", "use": "[E] Schott überbrücken", "seconds": 45.0, "progress": "SCHOTT WIRD GEKNACKT", "radius": 12.0}
		],
		"spots": {
			"goal": Vector3(51.0, 0, 6.6),
			"switches": [Vector3(24.5, 0, 22.5), Vector3(31.0, 0, 29.5), Vector3(53.5, 0, 7.6)],
			"items": [Vector3(26.0, 0, 30.4), Vector3(49.2, 0, 38.0), Vector3(18.0, 4.2, 3.5), Vector3(1.7, 0, 32.0), Vector3(53.8, 0, 2.0), Vector3(6.0, 4.2, 3.0)]
		},
		"crowd": [["mauler", "mauler", "striker", "ripper", "leech"], 9, 9.0, [2, 4]],
		"posts": [["mauler", Vector3(30, 0, 46)], ["mauler", Vector3(1.7, 0, 30)], ["striker", Vector3(27, 0, 26)], ["mauler", Vector3(49.2, 0, 20)], ["ripper", Vector3(44, 0, 5)], ["mauler", Vector3(14, 0, 1.7)]],
		"strength": 7,
		"lines": {"enter": ["talk:m2_water"], "event": ["line:m2_n_taunt"]},
		"caches": [["beob_spind", "beob_w", EAST, 4.6, "spind", "BEOBACHTUNGSRAUM"], ["pumpen_kiste", "halle", EAST, 4.2, "kiste", "PUMPENPLATTFORM"]],
		"station": ["halle", SOUTH, [["cabinet", 30.0], ["bench", 33.6]]],
		"supply": [Vector3(18.0, 0, 47.2), Vector3(0, 0, -1)]
	}

func lay() -> void:
	var dark := Color(0.32, 0.34, 0.34)
	room("halle", 0.0, 0, 0, 56, 48, 12.0, "tech", {
		"floor": false, "walk": walks(_walk_inner()), "seed": Vector2(o.x + 8.0, o.z + 46.0),
		"look": {"lamp": "hang", "lamp_gap": 18.0, "lamp_every": 1, "lamp_height": 6.5, "light": Color("a8e0e8"), "energy": 2.0, "reach": 20.0}
	})
	# --- the basin and the walkways over it
	water(Rect2(0.2, 0.2, 55.6, 47.6), SURFACE, BOTTOM)
	m._chunk("Kit", false)
	for walk: Rect2 in WALKS:
		slab(walk, 0.0, "betonfloor", Color(0.56, 0.56, 0.54))
		_edges(walk)
	# The middle of the causeway lies a hand's breadth under water.
	var sunk := Rect2(48.0, float(SUNKEN[0]), 2.4, float(SUNKEN[1]) - float(SUNKEN[0]))
	m._areal_wet(r(sunk.position.x, sunk.position.y, sunk.size.x, sunk.size.y), y(0.06), y(0.0))
	# --- the island: two pumps, their housings, the console of the basin
	for spot in [Vector3(24.5, 0, 24.0), Vector3(31.0, 0, 28.0)]:
		block("plate", spot + Vector3(0, 0.9, 0), Vector3(2.6, 1.8, 1.8), Color(0.24, 0.27, 0.28))
		m._pipe(p(spot.x, 1.8, spot.z), p(spot.x, 12.0, spot.z), 0.35, Color(0.2, 0.22, 0.23), 10, "steel")
		glow(spot + Vector3(-1.32, 1.4, 0), Vector3(0.02, 0.1, 0.1), Color("ffb347"), 4.0)
	block("plate", Vector3(27.0, 0.6, 21.2), Vector3(3.0, 1.2, 0.8), Color(0.2, 0.22, 0.24))
	light(Vector3(27.0, 3.0, 26.0), Color("ffcf8a"), 2.2, 11.0, 0.05)
	# --- the pump platform: the big pump, its console, a short rail before the machine
	block("plate", Vector3(41.0, 1.0, 7.4), Vector3(5.0, 2.0, 2.4), Color(0.22, 0.24, 0.25))
	block("plate", Vector3(51.0, 0.6, 8.6), Vector3(3.0, 1.2, 0.8), Color(0.2, 0.22, 0.24))
	railing(Vector3(38.2, 0, 8.9), Vector3(43.8, 0, 8.9))
	light(Vector3(46.0, 3.4, 5.0), Color("ffcf8a"), 2.4, 12.0, 0.03)
	# --- the observation rooms over the north strip, behind glass, and the stair up to them
	var looks := {"look": {"light": Color("d6f0f0"), "energy": 1.6}}
	room("beob_w", 4.2, 0, 0, 12, 7, 3.2, "lab", _with(looks, {"bare": [NORTH, WEST]}))
	room("beob_m", 4.2, 12, 0, 12, 7, 3.2, "lab", _with(looks, {"bare": [NORTH]}))
	room("beob_o", 4.2, 24, 0, 12, 7, 3.2, "lab", _with(looks, {"bare": [NORTH]}))
	door("beob_w", "beob_m", 1.8, 1.8, {"kind": "slide"})
	door("beob_m", "beob_o", 1.8, 1.8, {"kind": "slide"})
	opening("beob_o", EAST, 1.7, 2.0, {"kind": "frame"})
	for name in ["beob_w", "beob_m", "beob_o"]:
		var room_x := {"beob_w": 0.0, "beob_m": 12.0, "beob_o": 24.0}[name] as float
		pane(name, SOUTH, room_x + 6.0, 10.0, 0.9, 2.7, "glass")
	m._chunk("Kit", false)
	m._deck_stairs(p(44.0, 0, 1.7), p(36.8, 4.2, 1.7), lv(0.0), lv(4.2), p(45.2, 0, 1.7), p(35.0, 4.2, 1.7))
	slab(Rect2(36.0, 0.4, 0.9, 2.6), 4.2, "tread", Color(0.42, 0.44, 0.46), 0.2)
	for x in [3.0, 15.0, 27.0, 35.4]:
		post(Vector2(x, 6.7), 4.2, 0.4)
	for name in ["beob_w", "beob_m", "beob_o"]:
		var middle: Vector2 = (m.room_of[n(name)].outer as Rect2).get_center()
		m._desk(Vector3(middle.x - 2.0, y(4.2), middle.y - 1.2), PI, m.random.randi_range(1, 5))
		m._office_chair(Vector3(middle.x + 1.5, y(4.2), middle.y), m.random.randf() * TAU, m.random.randf() < 0.5)
	# --- light at the walkways: warm lamps on the walls, low
	for spot in [Vector3(10, 2.4, 47.7), Vector3(30, 2.4, 47.7), Vector3(46, 2.4, 47.7), Vector3(0.3, 2.4, 12), Vector3(0.3, 2.4, 36), Vector3(55.7, 2.4, 20), Vector3(55.7, 2.4, 36)]:
		var into := Vector3(-0.5 if spot.x > 50 else (0.5 if spot.x < 1 else 0.0), 0, -0.5 if spot.z > 47 else 0.0)
		glow(spot, Vector3(0.2, 0.26, 0.2), Color("ffc27a"), 5.0)
		light(spot + into * 1.6, Color("ffc27a"), 1.4, 9.0, 0.04)
	m._haze(p(28.0, 1.0, 24.0), Vector3(54.0, 2.0, 46.0), 0.03, Color(0.6, 0.85, 0.85))
	stencil("halle", NORTH, 48.0, 5.0, "AUSGANG", 110, Color(0.6, 0.5, 0.2))
	stencil("halle", SOUTH, 30.0, 6.5, "BECKEN  B-7", 260, Color(0.42, 0.5, 0.5))
	stencil("halle", WEST, 24.0, 6.5, "VORSICHT  ·  TIEFES WASSER", 90, Color(0.6, 0.5, 0.2))
	# --- ways in: out of the walls at the walkways, from the roof on to them
	hole("halle", SOUTH, 40.0, "pipes")
	hole("halle", WEST, 38.0, "breach")
	hole("halle", WEST, 9.0, "vent")
	duct("halle", SOUTH, 50.0, {"sill": 2.6, "trunk": 5.0})
	drop("halle", 12.0, 46.2, 1, {"shaft": 2.0})
	drop("halle", 1.7, 14.0, 2, {"shaft": 2.0})
	drop("halle", 27.0, 30.5, 3, {"shaft": 2.0})
	drop("halle", 49.2, 40.0, 0, {"shaft": 2.0})
	drop("beob_m", 18.0, 3.0, 1)
	drop("beob_o", 30.0, 4.0, 0)
	point("goal", Vector3(51.0, 0, 6.6))
	point("middle", Vector3(27.0, 0, 26.0))

## The walkways as walk rectangles: a quarter of a metre inside their edges (nobody is led
## along the very edge of the water), a little longer at their ends so that they reach
## into the walkways they meet, and never into a wall.
func _walk_inner() -> Array:
	var out: Array = []
	var hall := Rect2(0.45, 0.45, 55.1, 47.1)
	for walk: Rect2 in WALKS:
		var nav := walk.grow(-0.25)
		if walk.size.x >= walk.size.y * 2.0:
			nav = Rect2(walk.position.x - 0.5, walk.position.y + 0.25, walk.size.x + 1.0, walk.size.y - 0.5)
		elif walk.size.y >= walk.size.x * 2.0:
			nav = Rect2(walk.position.x + 0.25, walk.position.y - 0.5, walk.size.x - 0.5, walk.size.y + 1.0)
		out.append(nav.intersection(hall))
	return out

## The edge of a walkway: a yellow line, and a few stumps of the railing that was there.
func _edges(walk: Rect2) -> void:
	var long_x := walk.size.x >= walk.size.y
	for side in [-1.0, 1.0]:
		var a := p(walk.position.x, 0.0, walk.get_center().y + side * (walk.size.y * 0.5 - 0.06)) if long_x else p(walk.get_center().x + side * (walk.size.x * 0.5 - 0.06), 0.0, walk.position.y)
		var b := p(walk.end.x, 0.0, walk.get_center().y + side * (walk.size.y * 0.5 - 0.06)) if long_x else p(walk.get_center().x + side * (walk.size.x * 0.5 - 0.06), 0.0, walk.end.y)
		m._stripe(a, b, 0.08, Color("b8961e"))
		var count := int(a.distance_to(b) / 7.0)
		for k in range(count):
			if m.random.randf() < 0.55:
				continue
			var at := a.lerp(b, (k + 0.5) / maxf(1.0, count))
			var tall := m.random.randf_range(0.2, 0.9)
			m._part("plate", at + Vector3(0, tall * 0.5, 0), Vector3(0.06, tall, 0.06), Color("4a4030"))

static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	out.merge(extra, true)
	return out
