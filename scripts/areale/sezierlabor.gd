extends AreaKit
## Area: the dissection laboratory (pathology). GREYBOX.
##
## 56 x 48 metres of connected rectangles on three walking heights (heights above the
## piece's base; the ports have to lie on the lattice, 0 or 8.4, so the main floor is the
## middle one):
##
##   0.0  KELLER   - partial: the delivery hall in the south-west (way in from the south),
##                   the cold cellar in the south-east (way out to the east), and between
##                   them a basement corridor that runs under the storage room and the hall
##                   into the GRUBE - the sunken middle of the autopsy hall, 4.2 m deep, open
##                   to the hall above - and out of it again to the east.
##   4.2  SAALEBENE - full: the autopsy hall (20 x 20, 8 m high) with the pit in its middle,
##                   two wide passages (6 m) along its west and east sides, and the rooms
##                   that open off them: the morgue with its cold drawers, the scrub room,
##                   the prep room and the x-ray room north of the hall, a small office and
##                   the specimen store in the east, the storage room in the south with a
##                   low crawl tunnel (1.45 m, duck with [C]) into the lab section beside it.
##   8.4  OBERGESCHOSS - the records room (way in from the west), the head office (way out to
##                   the north), two observation rooms that look down into the hall through
##                   windows, an upper corridor over each passage, and a steel gallery along
##                   the hall's south wall that joins them into a ring.
##
## Between the floors: the delivery hall's gurney ramp and the two flights down into the pit
## (Keller - Saalebene); the flight from the hall floor up to its gallery and the two
## stairwells in the north-west and the east (Saalebene - Obergeschoss). Every floor is one
## grid of its own and has loops: around the hall through either passage and the rooms
## north of it, through the storage room and the lab section, round the upper ring.
##
## The crawl tunnel is the survivor's own short cut: nobody else's paths lead through it
## (it is too low for them); they come round by the passages.

## The walking heights.
const KELLER := 0.0
const SAAL := 4.2
const OBEN := 8.4
## The pit in the middle of the hall (x, z, w, d).
const GRUBE := Rect2(23, 19, 10, 10)
## Cold white with a breath of green, as the lamps of the area shine.
const WHITE := Color("e2f4ec")
const GREEN := Color("6fe0a8")
const STEEL := Color("9aa3a6")

func info() -> Dictionary:
	return {
		"id": "sezierlabor", "kind": "area", "label": "SEZIERLABOR", "name": "Sezierlabor (Saal, Grube, zwei Etagen)", "class": "gross",
		"size": Vector2(56.0, 48.0), "levels": [KELLER, SAAL, OBEN], "mood": "cold",
		"staff": ["hive_lab", "hive_lab2", "hive_scientist", "hive_scientist2"],
		"views": [
			["saal_oben", Vector3(19.5, 11.6, 15.5), Vector3(31, 2.0, 28)],
			["saal_auge", Vector3(20.0, 5.82, 31.0), Vector3(31, 4.8, 16)],
			["grube", Vector3(30.0, 1.62, 28.0), Vector3(25, 3.0, 19.5)],
			["westgang", Vector3(15.0, 5.82, 46.0), Vector3(15, 5.4, 2)],
			["ostgang", Vector3(41.0, 5.82, 1.5), Vector3(41, 5.4, 40)],
			["lager", Vector3(19.5, 5.82, 46.5), Vector3(30, 5.0, 41)],
			["kriechgang", Vector3(29.0, 5.32, 41.0), Vector3(36, 5.0, 41)],
			["labor", Vector3(35.0, 5.82, 41.0), Vector3(55, 5.2, 41)],
			["kuehlraum", Vector3(10.5, 5.82, 19.5), Vector3(1, 5.0, 19.5)],
			["praeparate", Vector3(45.5, 5.82, 22.5), Vector3(54, 5.2, 13)],
			["beobachtung", Vector3(20.0, 10.02, 1.5), Vector3(30, 6.0, 24)],
			["steg", Vector3(19.5, 10.02, 32.5), Vector3(36, 7.0, 18)],
			["oberer_gang", Vector3(15.0, 10.02, 33.0), Vector3(15, 9.6, 1)],
			["archiv", Vector3(11.0, 10.02, 25.0), Vector3(1, 9.4, 14)],
			["leitung", Vector3(54.5, 10.02, 11.0), Vector3(45, 9.4, 1)],
			["keller", Vector3(13.0, 1.62, 43.0), Vector3(27, 1.4, 43)],
			["anlieferung", Vector3(10.5, 1.62, 47.0), Vector3(2, 3.0, 36)],
			["kuehlkeller", Vector3(40.0, 1.62, 46.5), Vector3(55, 1.4, 38)]
		],
		"ports": [
			{"side": SOUTH, "at": 6.0, "y": KELLER, "room": "anlieferung", "role": "in"},
			{"side": WEST, "at": 19.5, "y": OBEN, "room": "archiv", "role": "in"},
			{"side": NORTH, "at": 50.0, "y": OBEN, "room": "leitung", "role": "out"},
			{"side": EAST, "at": 42.0, "y": KELLER, "room": "kuehlkeller", "role": "out"}
		],
		"events": [
			{"kind": "collect", "goal": "Gewebeproben aus Präparatelager, Kühlraum, Archiv und Grube einsammeln", "word": "Gewebeprobe", "use": "[E] Probe nehmen", "count": 4},
			{"kind": "hack", "goal": "Die Verriegelung der Kühlkammer überbrücken und halten", "use": "[E] Verriegelung überbrücken", "seconds": 50.0, "progress": "KÜHLKAMMER WIRD ENTRIEGELT", "radius": 13.0},
			{"kind": "restore", "goal": "Den Notstrom für die Rolltore des Sektionstrakts zuschalten", "use": "[E] Notstrom zuschalten", "count": 3, "after": 22.0, "progress": "ROLLTORE FAHREN HOCH"}
		],
		"spots": {
			"goal": Vector3(15.0, SAAL, 17.5),
			"switches": [Vector3(53.0, KELLER, 38.5), Vector3(47.0, OBEN, 2.5), Vector3(9.0, SAAL, 31.0), Vector3(36.0, SAAL, 2.5)],
			"items": [Vector3(52.0, SAAL, 21.5), Vector3(3.0, SAAL, 22.0), Vector3(3.0, OBEN, 16.0), Vector3(35.5, OBEN, 3.0), Vector3(28.0, KELLER, 27.6), Vector3(53.0, SAAL, 45.0), Vector3(14.5, KELLER, 44.5)]
		},
		"crowd": [["mauler", "mauler", "ripper", "striker", "charger", "leech"], 10, 8.5, [2, 4]],
		"posts": [
			["mauler", Vector3(30, SAAL, 15.4)], ["mauler", Vector3(15, SAAL, 30)], ["ripper", Vector3(41, SAAL, 10)], ["striker", Vector3(28, KELLER, 25.6)],
			["mauler", Vector3(15, OBEN, 20)], ["leech", Vector3(33, OBEN, 8)], ["mauler", Vector3(50, SAAL, 18)], ["mauler", Vector3(46, KELLER, 44)],
			["charger", Vector3(40, SAAL, 41)], ["mauler", Vector3(20, KELLER, 43)]
		],
		"strength": 7,
		"lines": {"enter": ["talk:m2_tanks"], "event": ["line:m2_n_work"]},
		"caches": [["praeparate_spind", "praeparate", EAST, 17.5, "spind", "PRÄPARATELAGER"], ["archiv_tresor", "archiv", SOUTH, 6.0, "tresor", "ARCHIV"], ["keller_kiste", "kuehlkeller", NORTH, 50.0, "kiste", "KÜHLKELLER"]],
		"station": ["lager", NORTH, [["cabinet", 22.0], ["bench", 25.6]]],
		"supply": [Vector3(46.5, 0, 47.3), Vector3(0, 0, -1)]
	}

func lay() -> void:
	_rooms()
	_doors()
	_levels()
	_dress()
	_lights()
	_ways()
	point("goal", Vector3(15.0, SAAL, 17.5))
	point("middle", Vector3(28.0, SAAL, 15.2))
	point("grube", Vector3(28.0, KELLER, 27.0))
	point("kriechgang", Vector3(32.0, SAAL, 41.0))

# ---------------------------------------------------------------- the rooms

func _rooms() -> void:
	var hall := {"look": {"lamp": "hang", "lamp_gap": 10.0, "lamp_every": 1, "lamp_height": 5.6, "light": WHITE, "energy": 2.0, "reach": 15.0, "stripe": Color("2f8f6a"), "panel": Color(0.84, 0.88, 0.86)}}
	var lab := {"look": {"light": WHITE, "energy": 2.2, "stripe": Color("2f8f6a"), "lamp_every": 2, "dead": 0.15}}
	var dim := {"look": {"light": WHITE, "energy": 1.8, "stripe": Color("2f8f6a"), "lamp_every": 2, "dead": 0.3}}
	var tiled := {"look": {"light": Color("d8f2ea"), "energy": 2.0, "lamp_every": 2, "dead": 0.25}}
	var cellar := {"look": {"lamp": "cage", "lamp_gap": 5.5, "light": Color("cfe8dc"), "energy": 1.7, "reach": 9.0, "dead": 0.3}}
	# --- Saalebene (4.2): under an upper room a room has no ceiling of its own (the
	# upper room's floor is it); where nothing lies above, it has one.
	room("halle", SAAL, 18, 14, 20, 20, 8.2, "lab", _with(hall, {"pits": [r(GRUBE.position.x, GRUBE.position.y, GRUBE.size.x, GRUBE.size.y)], "walk": walks([
		Rect2(18.65, 14.65, 18.7, 4.0), Rect2(18.65, 29.35, 18.7, 4.0), Rect2(18.65, 18.65, 4.0, 10.7), Rect2(33.35, 18.65, 4.0, 10.7)
	])}))
	room("gang_w", SAAL, 12, 0, 6, 34, 3.9, "lab", _with(lab, {"ceiling": false}))
	room("gang_sw", SAAL, 12, 34, 6, 14, 3.9, "lab", lab)
	room("gang_o", SAAL, 38, 0, 6, 34, 3.9, "lab", _with(lab, {"ceiling": false}))
	room("treppe_nw", SAAL, 0, 0, 12, 13, 8.1, "concrete", cellar)
	room("kuehlraum", SAAL, 0, 13, 12, 13, 3.9, "canteen", _with(tiled, {"ceiling": false, "look": {"light": Color("cfeaf4"), "energy": 1.7, "lamp_every": 2, "dead": 0.35}}))
	room("waschraum", SAAL, 0, 26, 12, 8, 3.9, "canteen", tiled)
	room("vorbereitung", SAAL, 18, 0, 10, 14, 3.9, "canteen", _with(tiled, {"ceiling": false}))
	room("roentgen", SAAL, 28, 0, 10, 14, 3.9, "lab", _with(dim, {"ceiling": false}))
	room("lager", SAAL, 18, 34, 12, 14, 3.9, "concrete", {"look": {"lamp": "cage", "lamp_gap": 5.5, "light": Color("d9efe4"), "energy": 1.8, "dead": 0.25}})
	room("kriechgang", SAAL, 30, 40, 4, 2, 1.45, "tech", {"nav": false, "lamps": "none"})
	room("labor_a", SAAL, 34, 34, 11, 14, 3.9, "lab", lab)
	room("labor_b", SAAL, 45, 34, 11, 14, 3.9, "lab", dim)
	room("buero", SAAL, 44, 0, 12, 12, 3.9, "office", {"ceiling": false, "look": {"energy": 1.8, "dead": 0.3}})
	room("praeparate", SAAL, 44, 12, 12, 12, 3.9, "lab", dim)
	room("treppe_o", SAAL, 44, 24, 12, 10, 8.1, "concrete", cellar)
	# --- Keller (0): the delivery hall reaches up to the Saalebene (its landing), the rest
	# lies under the floors of the rooms above.
	room("anlieferung", KELLER, 0, 34, 12, 14, 8.0, "concrete", cellar)
	room("kg_s", KELLER, 12, 40, 16, 6, 3.9, "tech", _with(cellar, {"ceiling": false}))
	room("kg_m", KELLER, 22, 29, 6, 11, 3.9, "tech", _with(cellar, {"ceiling": false}))
	room("grube", KELLER, GRUBE.position.x, GRUBE.position.y, GRUBE.size.x, GRUBE.size.y, 4.2, "canteen", {"ceiling": false, "lamps": "none"})
	room("kg_o", KELLER, 33, 26, 11, 5, 3.9, "tech", _with(cellar, {"ceiling": false}))
	room("kg_os", KELLER, 39, 31, 5, 5, 3.9, "tech", _with(cellar, {"ceiling": false}))
	room("kuehlkeller", KELLER, 39, 36, 17, 12, 3.9, "tech", _with(cellar, {"ceiling": false, "look": {"lamp": "cage", "lamp_gap": 5.5, "light": Color("bfe6ff"), "energy": 1.6, "dead": 0.35}}))
	# --- Obergeschoss (8.4)
	var upper := {"look": {"light": WHITE, "energy": 1.9, "lamp_every": 2, "dead": 0.2}}
	room("archiv", OBEN, 0, 13, 12, 13, 3.4, "office", upper)
	room("oflur_w", OBEN, 12, 0, 6, 34, 3.4, "lab", upper)
	room("beob_w", OBEN, 18, 0, 10, 14, 3.4, "lab", upper)
	room("beob_o", OBEN, 28, 0, 10, 14, 3.4, "lab", upper)
	room("oflur_o", OBEN, 38, 0, 6, 34, 3.4, "lab", upper)
	room("leitung", OBEN, 44, 0, 12, 12, 3.4, "office", upper)

# ---------------------------------------------------------------- what joins them

func _doors() -> void:
	# Saalebene
	door("gang_w", "gang_sw", 15.0, 5.6, {"kind": "join"})
	door("treppe_nw", "gang_w", 8.0, 2.4, {"kind": "frame"})
	door("kuehlraum", "gang_w", 19.5, 2.4, {"kind": "slide"})
	door("waschraum", "gang_w", 30.0, 1.8, {"kind": "slide"})
	door("gang_w", "vorbereitung", 7.0, 1.8, {"kind": "slide"})
	door("gang_w", "halle", 24.0, 3.6, {"kind": "frame"})
	door("gang_sw", "lager", 41.0, 3.0, {"kind": "frame"})
	door("vorbereitung", "halle", 23.0, 3.0, {"kind": "slide"})
	door("vorbereitung", "roentgen", 4.0, 1.6, {"kind": "frame"})
	door("roentgen", "halle", 33.0, 2.0, {"kind": "slide"})
	door("roentgen", "gang_o", 7.0, 1.8, {"kind": "slide"})
	door("halle", "gang_o", 18.0, 3.6, {"kind": "frame"})
	door("halle", "labor_a", 35.6, 2.4, {"kind": "slide"})
	door("gang_o", "labor_a", 41.0, 3.0, {"kind": "frame"})
	door("labor_a", "labor_b", 41.0, 3.0, {"kind": "frame"})
	door("treppe_o", "labor_b", 46.2, 2.0, {"kind": "slide"})
	door("gang_o", "treppe_o", 27.0, 2.4, {"kind": "frame"})
	door("gang_o", "praeparate", 18.0, 2.0, {"kind": "slide"})
	door("gang_o", "buero", 6.0, 1.8, {"kind": "slide"})
	door("buero", "praeparate", 52.0, 1.6, {"kind": "frame"})
	# The crawl tunnel: low, and no way for the paths (see above).
	door("lager", "kriechgang", 41.0, 1.4, {"kind": "frame", "height": 1.4, "nav": false})
	door("kriechgang", "labor_a", 41.0, 1.4, {"kind": "frame", "height": 1.4, "nav": false})
	# Keller
	door("anlieferung", "kg_s", 43.0, 3.0, {"kind": "frame"})
	door("kg_m", "kg_s", 25.0, 5.6, {"kind": "join"})
	door("grube", "kg_m", 26.4, 2.4, {"kind": "frame"})
	door("grube", "kg_o", 27.6, 2.2, {"kind": "frame"})
	door("kg_o", "kg_os", 41.5, 4.6, {"kind": "join"})
	door("kg_os", "kuehlkeller", 41.5, 4.6, {"kind": "join"})
	# Obergeschoss
	door("archiv", "oflur_w", 22.0, 1.8, {"kind": "slide"})
	door("oflur_w", "beob_w", 7.0, 1.8, {"kind": "slide"})
	door("beob_w", "beob_o", 4.0, 1.8, {"kind": "slide"})
	door("beob_o", "oflur_o", 7.0, 1.8, {"kind": "slide"})
	door("oflur_o", "leitung", 6.0, 1.8, {"kind": "slide"})
	# The observation rooms look down into the hall (bodies stop, shots pass).
	for spec in [["beob_w", 23.0], ["beob_o", 33.0]]:
		pane(str(spec[0]), SOUTH, float(spec[1]), 8.0, 0.9, 2.7, "window")
		cut("halle", NORTH, float(spec[1]), 8.0, OBEN - SAAL + 0.9, OBEN - SAAL + 2.7)

# ---------------------------------------------------------------- galleries, stairs, the ramp

func _levels() -> void:
	# --- the delivery hall: a landing on the Saalebene along its north wall, the gurney
	# ramp up to it along its west wall
	gallery("anl_m", SAAL, Rect2(0, 34, 12, 4), [], [[SOUTH, 2.9, 12.0]], [Vector2(6.5, 37.7), Vector2(11.5, 37.7)], Rect2(0, 34.2, 11.8, 3.8))
	door("waschraum", "anl_m", 6.0, 2.0, {"kind": "frame"})
	cut("anlieferung", NORTH, 6.0, 2.4, SAAL, SAAL + 2.6)
	door("gang_sw", "anl_m", 36.0, 2.4, {"kind": "frame"})
	cut("anlieferung", EAST, 36.0, 2.8, SAAL, SAAL + 2.6)
	_ramp(Vector3(1.6, KELLER, 46.8), Vector3(1.6, SAAL, 38.0), 2.4, Vector3(1.6, KELLER, 47.3), Vector3(1.6, SAAL, 36.4))
	# --- the pit: two flights up its west and east walls to the hall floor north of it,
	# and a railing round its edge
	flight(Vector3(24.2, KELLER, 26.2), Vector3(24.2, SAAL, 19.0), Vector3(24.2, KELLER, 27.6), Vector3(24.2, SAAL, 17.4))
	flight(Vector3(31.8, KELLER, 26.2), Vector3(31.8, SAAL, 19.0), Vector3(31.8, KELLER, 27.6), Vector3(31.8, SAAL, 17.4))
	railing(Vector3(25.4, SAAL, 18.9), Vector3(30.6, SAAL, 18.9))
	railing(Vector3(22.9, SAAL, 29.1), Vector3(33.1, SAAL, 29.1))
	railing(Vector3(22.9, SAAL, 19.0), Vector3(22.9, SAAL, 29.0))
	railing(Vector3(33.1, SAAL, 19.0), Vector3(33.1, SAAL, 29.0))
	# --- the hall's gallery along its south wall, and the flight up to it at the east wall
	gallery("steg_s", OBEN, Rect2(18, 31, 20, 3), [], [[NORTH, 18.0, 35.5], [NORTH, 37.7, 38.0]], [], Rect2(18.2, 31.0, 19.6, 2.8))
	for x in [21.0, 31.0]:
		_post_on(Vector2(x, 31.3), SAAL, OBEN)
	flight(Vector3(36.6, SAAL, 23.6), Vector3(36.6, OBEN, 30.8), Vector3(36.6, SAAL, 22.2), Vector3(36.6, OBEN, 32.6))
	door("oflur_w", "steg_s", 32.5, 2.4, {"kind": "frame"})
	cut("halle", WEST, 32.5, 2.8, OBEN - SAAL, OBEN - SAAL + 2.6)
	door("steg_s", "oflur_o", 32.5, 2.4, {"kind": "frame"})
	cut("halle", EAST, 32.5, 2.8, OBEN - SAAL, OBEN - SAAL + 2.6)
	# --- the stairwell in the north-west: a flight up its west wall to a landing along its
	# north wall and down its east side, out to the upper corridor and the records room
	gallery("tnw_n", OBEN, Rect2(0, 0, 12, 3.6), [], [[SOUTH, 2.5, 8.4]], [], Rect2(0, 0, 11.8, 3.6))
	gallery("tnw_o", OBEN, Rect2(8.4, 3.6, 3.6, 9.4), [], [[WEST, 3.6, 13.0]], [], Rect2(8.4, 3.6, 3.4, 9.2))
	for spot in [Vector2(6.0, 3.3), Vector2(8.7, 8.0), Vector2(8.7, 12.5)]:
		_post_on(spot, SAAL, OBEN)
	door("tnw_n", "tnw_o", 10.2, 3.4, {"kind": "join"})
	flight(Vector3(1.4, SAAL, 10.8), Vector3(1.4, OBEN, 3.6), Vector3(1.4, SAAL, 12.2), Vector3(1.4, OBEN, 1.8))
	door("tnw_o", "oflur_w", 8.5, 2.4, {"kind": "frame"})
	cut("treppe_nw", EAST, 8.5, 2.8, OBEN - SAAL, OBEN - SAAL + 2.6)
	door("archiv", "tnw_o", 10.2, 2.2, {"kind": "frame"})
	cut("treppe_nw", SOUTH, 10.2, 2.6, OBEN - SAAL, OBEN - SAAL + 2.6)
	# --- the stairwell in the east: a flight along its south wall up to a landing at its
	# west wall, out to the upper corridor
	gallery("to_w", OBEN, Rect2(44, 24, 3.2, 10), [], [[EAST, 24.0, 31.3]], [], Rect2(44.2, 24.2, 3.0, 9.6))
	for spot in [Vector2(46.9, 24.6), Vector2(46.9, 30.0)]:
		_post_on(spot, SAAL, OBEN)
	flight(Vector3(54.4, SAAL, 32.4), Vector3(47.2, OBEN, 32.4), Vector3(55.0, SAAL, 32.4), Vector3(45.6, OBEN, 32.4))
	door("oflur_o", "to_w", 29.0, 2.4, {"kind": "frame"})
	cut("treppe_o", WEST, 29.0, 2.8, OBEN - SAAL, OBEN - SAAL + 2.6)

## A steel post from one height of the piece up to another.
func _post_on(spot: Vector2, low: float, high: float, thick: float = 0.26) -> void:
	m._chunk("Kit", false)
	block("plate", Vector3(spot.x, (low + high) * 0.5 - 0.1, spot.y), Vector3(thick, high - low - 0.2, thick), Color("1d2124"))

## A ramp for gurneys: a sloping slab of steel tread on a closed cheek, rails at both sides,
## and the way over it for the paths. Nobody walks under its lower part.
func _ramp(foot: Vector3, head: Vector3, width: float, land_low: Vector3, land_high: Vector3) -> void:
	m._chunk("Stairs", false)
	var a := o + foot
	var b := o + head
	var slope := m._slope_basis(a, b)
	var length := a.distance_to(b)
	var middle := (a + b) * 0.5
	m.batch.box(m.mats["tread"], middle - slope.y * 0.1, Vector3(width, 0.2, length), Color(0.46, 0.48, 0.5), slope)
	m._add_shape(m.body, middle - slope.y * 0.15, Vector3(width, 0.3, length), slope)
	# Its cheek down to the floor, in slices, and yellow edges.
	var slices := maxi(4, roundi(Vector2(b.x - a.x, b.z - a.z).length() / 0.6))
	for i in range(slices):
		var t0 := float(i) / slices
		var t1 := float(i + 1) / slices
		var top := lerpf(a.y, b.y, t0) - 0.18
		if top - a.y < 0.05:
			continue
		var at := a.lerp(b, (t0 + t1) * 0.5)
		var run := Vector2(b.x - a.x, b.z - a.z) * (t1 - t0)
		var size := Vector3(width - 0.04, top - a.y, absf(run.y) + 0.02) if absf(run.y) > absf(run.x) else Vector3(absf(run.x) + 0.02, top - a.y, width - 0.04)
		m._part("formwork", Vector3(at.x, a.y + size.y * 0.5, at.z), size, Color(0.62, 0.64, 0.63))
	for edge in [-1.0, 1.0]:
		m.batch.box(m.mats["plain"], middle - slope.x * (width * 0.5 - 0.08) * edge + slope.y * 0.003, Vector3(0.1, 0.01, length), Color("c9a227"), slope)
	m._handrail(a, b, width * 0.5 - 0.04)
	m._handrail(a, b, -(width * 0.5 - 0.04))
	var low_part := a.lerp(b, 0.3)
	var reach := Vector2(b.x - a.x, b.z - a.z) * 0.6
	m._register(Vector3(low_part.x, a.y + 1.0, low_part.z), Vector3(width if absf(reach.y) > absf(reach.x) else absf(reach.x), 2.0, absf(reach.y) if absf(reach.y) > absf(reach.x) else width))
	m._link(PackedVector3Array([o + land_low, a, b, o + land_high]), width, lv(foot.y), lv(head.y))

# ---------------------------------------------------------------- what stands in it

func _dress() -> void:
	m._chunk("Kit", false)
	# --- the hall: steel tables around the pit, each over its drain, a row of specimen
	# tanks under the gallery, the big table in the pit under its own lamp
	for spec in [[Vector3(20.6, SAAL, 20.0), 0.0], [Vector3(20.6, SAAL, 28.0), 0.0], [Vector3(28.0, SAAL, 16.4), PI / 2], [Vector3(34.5, SAAL, 20.6), 0.0]]:
		_table(spec[0], float(spec[1]))
	_table(Vector3(28.0, KELLER, 23.4), PI / 2, 1.25)
	for x in [20.5, 23.0, 25.5, 28.0, 30.5, 33.0]:
		_tank(Vector3(x, SAAL, 32.7), 2.4, x == 25.5)
	for x in [26.0, 30.0]:
		_tank(Vector3(x, KELLER, 20.0), 2.2, x == 30.0)
	stencil("halle", NORTH, 28.0, 7.4, "SEKTION  S-3", 200, Color(0.2, 0.42, 0.32))
	stencil("halle", SOUTH, 22.0, 2.6, "PATHOLOGIE", 90, Color(0.2, 0.42, 0.32))
	stencil("grube", SOUTH, 30.4, 2.9, "GRUBE  ·  EBENE -1", 70, Color(0.2, 0.42, 0.32))
	# --- the morgue: walls of cold drawers
	_drawers(0.4, 11.6, 13.6, 1.0)
	_drawers(0.4, 11.6, 25.4, -1.0)
	block("plate", Vector3(6.0, SAAL + 0.45, 19.5), Vector3(2.0, 0.9, 0.8), Color(0.62, 0.66, 0.68), false)
	stencil("gang_w", WEST, 19.5, 3.0, "KÜHLKAMMER", 70, Color(0.2, 0.42, 0.55))
	# --- the scrub room: sinks along its north wall; the prep room: sinks and trolleys
	for x in [2.0, 4.6, 7.2, 9.8]:
		_sink(Vector3(x, SAAL, 26.55))
	for x in [20.0, 22.6, 25.2]:
		_sink(Vector3(x, SAAL, 0.55))
	for spot in [Vector3(21.0, SAAL, 9.0), Vector3(25.0, SAAL, 6.0)]:
		block("plate", spot + Vector3(0, 0.5, 0), Vector3(0.7, 0.9, 1.9), STEEL, false)
	# --- the x-ray room: the machine, its table, the light boxes on the wall
	block("plate", Vector3(32.0, SAAL + 1.2, 8.0), Vector3(1.4, 2.4, 1.4), Color(0.78, 0.8, 0.8))
	block("plate", Vector3(32.0, SAAL + 2.2, 9.7), Vector3(0.8, 0.5, 2.2), Color(0.7, 0.72, 0.72), false)
	block("plate", Vector3(32.0, SAAL + 0.45, 10.6), Vector3(0.9, 0.9, 2.2), STEEL, false)
	for x in [30.0, 32.0, 34.0]:
		glow(Vector3(x, SAAL + 1.8, 13.75), Vector3(1.4, 1.0, 0.03), Color("cfe8ff"), 1.4)
	# --- the specimen store: racks of jars
	_rack(Vector3(49.5, SAAL, 23.4), 9.0, true)
	_rack(Vector3(49.5, SAAL, 15.4), 7.0, true)
	stencil("praeparate", NORTH, 47.0, 3.0, "PRÄPARATE", 60, Color(0.2, 0.42, 0.32))
	# --- the storage room: crates and pallets, the mouth of the crawl tunnel
	for spec in [[Vector3(20.5, SAAL, 46.0), 0.0, 1], [Vector3(27.0, SAAL, 46.2), 0.2, 2], [Vector3(20.5, SAAL, 38.5), -0.1, 0]]:
		m._pallet(o + (spec[0] as Vector3), float(spec[1]), int(spec[2]), 1.2)
	stencil("lager", EAST, 41.0, 2.0, "WARTUNGSSCHACHT  ·  DUCKEN [C]", 40, Color(0.6, 0.5, 0.2))
	m._hazard(p(30.05, SAAL + 1.48, 40.3), p(30.05, SAAL + 1.48, 41.7), Vector3(0.02, 0.08, 1.4 / 6.0), 6)
	# --- the lab section: benches in rows
	for spec in [[Vector3(40.0, SAAL, 37.2), 6.0], [Vector3(40.0, SAAL, 44.6), 6.0], [Vector3(50.0, SAAL, 37.6), 6.0], [Vector3(50.0, SAAL, 40.6), 6.0]]:
		_bench(spec[0], float(spec[1]))
	for x in [52.0, 54.5]:
		_tank(Vector3(x, SAAL, 46.9), 2.0, x == 52.0)
	# --- the offices: desks
	m._desk(p(50.0, SAAL, 5.0), PI, 2)
	m._office_chair(p(50.5, SAAL, 6.2), 0.4)
	m._desk(p(47.0, OBEN, 7.4), PI, 4)
	m._office_chair(p(47.4, OBEN, 8.8), 2.0, true)
	# (The console stands at the south wall: the way out is in the north one.)
	block("plate", Vector3(52.5, OBEN + 0.55, 11.2), Vector3(5.0, 1.1, 0.8), Color(0.2, 0.22, 0.24))
	glow(Vector3(52.5, OBEN + 1.12, 11.2), Vector3(4.6, 0.03, 0.5), GREEN, 2.4)
	# --- the observation rooms: a row of desks at the windows
	for x in [21.0, 25.0, 31.0, 35.0]:
		m._desk(p(x, OBEN, 12.4), 0.0, int(x) % 5 + 1)
	# --- the records room: two racks of files
	_rack(Vector3(6.5, OBEN, 16.6), 5.0, false)
	_rack(Vector3(6.5, OBEN, 21.4), 5.0, false)
	# --- the cellar: pipes along the corridors, cold boxes in the cold cellar
	for run in [[Vector3(12.4, 3.2, 40.5), Vector3(27.6, 3.2, 40.5)], [Vector3(22.5, 3.2, 29.5), Vector3(22.5, 3.2, 39.6)], [Vector3(33.5, 3.3, 26.5), Vector3(43.6, 3.3, 26.5)]]:
		m._pipe(p((run[0] as Vector3).x, (run[0] as Vector3).y, (run[0] as Vector3).z), p((run[1] as Vector3).x, (run[1] as Vector3).y, (run[1] as Vector3).z), 0.14, Color("4f6a5e"), 8, "steel")
	for spot in [Vector3(46.0, 0, 40.6), Vector3(50.5, 0, 40.6)]:
		block("steel", spot + Vector3(0, 1.2, 0), Vector3(2.4, 2.4, 1.6), Color(0.7, 0.76, 0.8))
		glow(spot + Vector3(0, 2.0, 0.81), Vector3(0.3, 0.08, 0.02), GREEN, 3.0)
	for spec in [[Vector3(8.5, 0, 44.0), 0.3, 0], [Vector3(9.0, 0, 39.0), -0.2, 3]]:
		m._pallet(o + (spec[0] as Vector3), float(spec[1]), int(spec[2]), 1.2)
	stencil("anlieferung", EAST, 41.0, 6.2, "ANLIEFERUNG  ·  PATHOLOGIE", 70, Color(0.2, 0.42, 0.32))
	stencil("kuehlkeller", WEST, 42.0, 2.8, "KÜHLKELLER", 70, Color(0.2, 0.42, 0.55))
	stencil("treppe_nw", SOUTH, 5.0, 6.6, "OBERGESCHOSS", 60, Color(0.2, 0.42, 0.32))
	stencil("treppe_o", NORTH, 50.0, 6.6, "OBERGESCHOSS", 60, Color(0.2, 0.42, 0.32))
	# Blood where they worked last.
	for spot in [Vector3(20.6, SAAL, 21.4), Vector3(28.0, KELLER, 24.6), Vector3(6.0, SAAL, 20.6), Vector3(15.0, SAAL, 18.4), Vector3(41.0, SAAL, 28.0)]:
		m._blot(p(spot.x, spot.y, spot.z), m.random.randf_range(0.6, 1.2), m.random.randf_range(0.4, 0.8))

## An autopsy table of steel on its pedestal, with the drain under its foot end.
func _table(at: Vector3, yaw: float, scale: float = 1.0) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var centre := p(at.x, at.y, at.z)
	m.batch.box(m.mats["steel"], centre + Vector3(0, 0.88, 0), Vector3(0.85, 0.06, 2.2) * Vector3(scale, 1, scale), STEEL, turn)
	m.batch.box(m.mats["steel"], centre + Vector3(0, 0.93, 0) + turn * Vector3(0.4 * scale, 0, 0), Vector3(0.04, 0.06, 2.2 * scale), STEEL.darkened(0.2), turn)
	m.batch.box(m.mats["steel"], centre + Vector3(0, 0.93, 0) - turn * Vector3(0.4 * scale, 0, 0), Vector3(0.04, 0.06, 2.2 * scale), STEEL.darkened(0.2), turn)
	m.batch.cylinder(m.mats["steel"], centre, 0.22, 0.14, 0.85, Color("5d6466"), 10)
	m.batch.cylinder(m.mats["plate"], centre + turn * Vector3(0, 0.003, 1.5 * scale), 0.2, 0.2, 0.01, Color("15181a"), 12)

## A specimen tank: a cylinder of green light behind glass, on a steel foot, under a lid.
func _tank(at: Vector3, tall: float, broken: bool = false) -> void:
	var base := p(at.x, at.y, at.z)
	m.batch.cylinder(m.mats["steel"], base, 0.56, 0.56, 0.3, Color("39424a"), 14)
	if broken:
		m.batch.cylinder(m.mats["pane"], base + Vector3(0, 0.3, 0), 0.48, 0.48, 0.5, Color.WHITE, 14)
		m._glow_box(base + Vector3(0, 0.45, 0), Vector3(0.6, 0.2, 0.6), GREEN, 1.0)
		m._blot(base + Vector3(0.6, 0, 0.2), 1.2, 0.8, Color(0.1, 0.25, 0.15, 0.7))
	else:
		m.batch.cylinder(m.mats["pane"], base + Vector3(0, 0.3, 0), 0.48, 0.48, tall - 0.6, Color.WHITE, 14)
		m._glow_box(base + Vector3(0, tall * 0.5, 0), Vector3(0.5, tall - 0.8, 0.5), GREEN, 1.6)
	m.batch.cylinder(m.mats["steel"], base + Vector3(0, tall - 0.3, 0), 0.56, 0.5, 0.3, Color("39424a"), 14)
	m._round_solid(base, 0.56, tall)

## A wall of cold drawers along x, its fronts looking along +z (`face` 1) or -z (-1).
func _drawers(x0: float, x1: float, z: float, face: float) -> void:
	block("steel", Vector3((x0 + x1) * 0.5, SAAL + 1.2, z), Vector3(x1 - x0, 2.4, 0.8), Color(0.55, 0.6, 0.62))
	var columns := int((x1 - x0) / 0.95)
	for c in range(columns):
		var x := x0 + (c + 0.5) * (x1 - x0) / columns
		for row in range(3):
			var y0 := SAAL + 0.42 + row * 0.75
			m._part("plate", p(x, y0, z + face * 0.405), Vector3(0.82, 0.66, 0.02), Color(0.78, 0.82, 0.84))
			m._part("plain", p(x, y0 + 0.18, z + face * 0.43), Vector3(0.3, 0.04, 0.03), Color("1d2124"))
			if (c * 3 + row) % 7 == 2:
				m._part("plain", p(x - 0.25, y0 - 0.18, z + face * 0.42), Vector3(0.12, 0.08, 0.01), GREEN.darkened(0.4))

## A scrub sink against a wall (`at`: the middle of its foot).
func _sink(at: Vector3) -> void:
	block("plate", at + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 0.6), Color(0.82, 0.86, 0.86), false)
	block("plate", at + Vector3(0, 0.9, 0), Vector3(1.8, 0.04, 0.42), Color(0.5, 0.55, 0.56), false)

## A rack along x: tall steel shelves, with jars of green (`jars`) or files on them.
func _rack(at: Vector3, long: float, jars: bool) -> void:
	block("plate", at + Vector3(0, 1.1, 0), Vector3(long, 2.2, 0.6), Color("2b3236"))
	for level in [0.5, 1.15, 1.8]:
		var x := at.x - long * 0.5 + 0.35
		while x < at.x + long * 0.5 - 0.3:
			if m.random.randf() < 0.75:
				for side in [-1.0, 1.0]:
					var spot := p(x, at.y + level, at.z + side * 0.31)
					if jars:
						m.batch.cylinder(m.mats["pane"], spot, 0.1, 0.1, 0.32, Color.WHITE, 8)
						m._glow_box(spot + Vector3(0, 0.13, 0), Vector3(0.12, 0.2, 0.12), GREEN.darkened(m.random.randf_range(0.0, 0.5)), 0.9)
					else:
						m._part("panelwood", spot + Vector3(0, 0.16, 0), Vector3(0.28, 0.32, 0.04), m._vary(Color(0.7, 0.62, 0.4), 0.1))
			x += 0.42

## A lab bench along x.
func _bench(at: Vector3, long: float) -> void:
	block("plate", at + Vector3(0, 0.45, 0), Vector3(long, 0.9, 0.9), Color(0.82, 0.86, 0.86), false)
	block("plate", at + Vector3(0, 0.92, 0), Vector3(long + 0.06, 0.05, 0.96), Color(0.22, 0.26, 0.26), false)

# ---------------------------------------------------------------- light

func _lights() -> void:
	# The operating lamp over the table in the pit, green light low in the pit.
	glow(Vector3(28.0, 3.55, 23.4), Vector3(1.2, 0.04, 0.8), WHITE, 6.0)
	m._pipe(p(28.0, 3.6, 23.4), p(28.0, SAAL + 8.2, 23.4), 0.03, Color("1a1a1a"), 6, "steel")
	light(Vector3(28.0, 3.0, 23.4), WHITE, 2.4, 9.0)
	light(Vector3(28.0, 0.8, 27.5), GREEN, 0.9, 6.0, 0.03)
	# The tanks under the gallery and in the lab glow; the light of the gallery itself.
	light(Vector3(26.5, SAAL + 1.6, 31.6), GREEN, 1.4, 9.0)
	light(Vector3(53.2, SAAL + 1.4, 45.8), GREEN, 1.0, 6.0, 0.04)
	light(Vector3(49.5, SAAL + 2.4, 19.4), GREEN, 0.9, 7.0)
	for x in [22.0, 30.0]:
		light(Vector3(x, OBEN + 2.8, 32.5), WHITE, 1.1, 8.0, 0.02)
	# The crawl tunnel: one caged lamp, dim.
	light(Vector3(32.0, SAAL + 1.2, 41.0), Color("ffd59a"), 0.6, 3.5, 0.05)
	m._haze(p(28.0, 1.0, 24.0), Vector3(9.6, 2.0, 9.6), 0.05, Color(0.75, 0.95, 0.85))
	m._haze(p(47.5, 1.0, 42.0), Vector3(16.0, 2.0, 11.0), 0.04, Color(0.75, 0.88, 1.0))

# ---------------------------------------------------------------- ways in

func _ways() -> void:
	# Keller
	hole("anlieferung", EAST, 37.0, "breach")
	drop("anlieferung", 6.0, 41.0, 1, {"shaft": 2.0})
	hole("kg_s", SOUTH, 22.0, "vent")
	hole("grube", WEST, 27.6, "pipes")
	hole("kuehlkeller", SOUTH, 54.0, "vent")
	# Saalebene
	drop("halle", 20.6, 16.6, 1, {"shaft": 2.0})
	drop("halle", 20.6, 24.4, 0, {"shaft": 2.0})
	drop("halle", 26.0, 32.6, 2, {"land": OBEN - SAAL, "shaft": 2.0})
	hole("gang_w", NORTH, 15.0, "vent")
	hole("kuehlraum", WEST, 16.0, "breach")
	hole("waschraum", WEST, 31.0, "pipes")
	drop("waschraum", 6.0, 30.0, 0)
	drop("gang_sw", 15.0, 43.3, 3)
	duct("lager", EAST, 37.0, {"sill": 2.2})
	drop("lager", 24.0, 41.0, 1)
	hole("lager", SOUTH, 23.8, "vent")
	hole("labor_a", SOUTH, 39.5, "breach")
	drop("labor_b", 50.5, 43.3, 2)
	hole("labor_b", SOUTH, 49.0, "vent")
	hole("gang_o", NORTH, 41.0, "breach")
	hole("roentgen", NORTH, 30.5, "vent")
	duct("vorbereitung", NORTH, 23.0)
	hole("buero", NORTH, 47.0, "breach")
	drop("praeparate", 50.0, 18.0, 0)
	hole("praeparate", EAST, 21.0, "vent")
	hole("treppe_o", EAST, 27.0, "vent")
	drop("treppe_o", 45.6, 28.5, 1, {"land": OBEN - SAAL, "shaft": 2.0})
	drop("treppe_nw", 5.0, 1.8, 2, {"land": OBEN - SAAL, "shaft": 2.0})
	# Obergeschoss
	drop("archiv", 10.0, 18.0, 0)
	duct("archiv", WEST, 25.0, {"sill": 1.9})
	drop("oflur_w", 15.0, 4.0, 1)
	drop("oflur_w", 15.0, 29.0, 3)
	drop("beob_w", 23.0, 4.0, 0)
	drop("beob_o", 33.0, 6.0, 2)
	drop("oflur_o", 41.0, 14.6, 1)
	drop("leitung", 50.0, 6.0, 0)
	duct("leitung", EAST, 6.0, {"sill": 1.9})

static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in extra:
		if key == "look" and out.has("look"):
			(out.look as Dictionary).merge(extra.look, true)
		else:
			out[key] = extra[key]
	return out
