extends AreaKit
## Area: the laboratory with a garden ("Labor mit Garten und Fauna"). GREYBOX.
##
## A biotope hall of 48 x 44 metres under a roof of glass panels and grow lights, 10 m
## high: soil and gravel paths, raised beds, trees and what grew out of the experiments -
## swollen bulbs, tendrils up the walls. A walkway of steel runs along the north and east
## walls at 4.2 m and crosses the hall on a bridge to a platform in the trees; stairs at
## the west end and at the platform. The infected also crawl up out of the beds.

func info() -> Dictionary:
	return {
		"id": "gartenlabor", "kind": "area", "label": "BIOTOP", "name": "Gartenlabor (Biotop)", "class": "gross",
		"size": Vector2(48.0, 44.0), "levels": [0.0, 4.2], "mood": "bio",
		"staff": ["hive_lab2", "hive_scientist", "hive_scientist2"],
		"views": [["bild", Vector3(44, 1.8, 42), Vector3(18, 3.0, 16)], ["oben_sw", Vector3(3, 8.8, 41), Vector3(28, 0, 18)], ["oben_no", Vector3(45, 8.8, 3), Vector3(20, 0, 30)], ["auge_einstieg", Vector3(24, 1.62, 41), Vector3(24, 1.5, 20)], ["steg", Vector3(40, 5.82, 2), Vector3(20, 1, 24)], ["bruecke", Vector3(30, 5.82, 19.5), Vector3(10, 2, 30)]],
		"ports": [
			{"side": SOUTH, "at": 24.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": WEST, "at": 30.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": NORTH, "at": 36.0, "y": 0.0, "room": "halle", "role": "out"},
			{"side": EAST, "at": 12.0, "y": 0.0, "room": "halle", "role": "out"}
		],
		"events": [
			{"kind": "hold", "goal": "Halten, bis die Biosicherung das Tor freigibt", "seconds": 55.0, "progress": "BIOSICHERUNG GIBT FREI", "radius": 14.0},
			{"kind": "collect", "goal": "Pflanzenproben für die Freigabe einsammeln", "word": "Probe", "use": "[E] Probe nehmen", "count": 3},
			{"kind": "lockdown", "goal": "Die Abriegelung der Biosphäre überstehen", "seconds": 50.0, "progress": "BIOSPHÄRE VERRIEGELT"}
		],
		"spots": {
			"goal": Vector3(22.0, 0, 24.0),
			"items": [Vector3(9.0, 0, 37.0), Vector3(38.0, 0, 30.0), Vector3(30.0, 4.2, 2.0), Vector3(15.0, 4.2, 21.5), Vector3(42.0, 0, 6.0), Vector3(8.5, 0, 8.0)]
		},
		"crowd": [["mauler", "mauler", "ripper", "leech", "healer", "striker"], 9, 9.0, [2, 4]],
		"posts": [["mauler", Vector3(12, 0, 30)], ["leech", Vector3(30, 0, 14)], ["mauler", Vector3(36, 0, 34)], ["ripper", Vector3(24, 4.2, 2)], ["healer", Vector3(18, 0, 10)], ["mauler", Vector3(40, 0, 22)]],
		"strength": 7,
		"lines": {"enter": ["talk:m2_tanks"], "event": []},
		"caches": [["galerie_kiste", "galerie_n", NORTH, 20.0, "kiste", "STEG IM BIOTOP"], ["geraete_spind", "halle", WEST, 8.0, "spind", "GERÄTESCHUPPEN"]],
		"station": ["halle", SOUTH, [["cabinet", 8.0], ["bench", 11.6]]],
		"supply": [Vector3(36.0, 0, 43.3), Vector3(0, 0, -1)]
	}

## The trees (local x, z).
const TREES := [Vector2(6, 18), Vector2(16, 37), Vector2(34, 18), Vector2(40, 36), Vector2(28, 26), Vector2(10, 40), Vector2(38, 6)]
## The raised beds (local x, z, w, d).
const BEDS := [Rect2(6, 26, 7, 3), Rect2(6, 33, 7, 3), Rect2(30, 34, 9, 3), Rect2(29, 8, 6, 4), Rect2(10, 8, 5, 6), Rect2(36, 24, 3, 7)]

func lay() -> void:
	room("halle", 0.0, 0, 0, 48, 44, 10.0, "lab", {
		"lamps": "none",
		"look": {"floor": ["lawn", Color(0.3, 0.38, 0.24)], "ceiling": ["plate", Color("1b2420")], "panel": Color(0.52, 0.56, 0.54), "stripe": Color("4f8f3a")}
	})
	# --- the galleries and the bridge to the platform in the trees
	gallery("galerie_n", 4.2, Rect2(0, 0, 48, 4), [], [[SOUTH, 0.0, 3.9], [SOUTH, 6.1, 44.0]], [Vector2(8, 3.8), Vector2(20, 3.8), Vector2(32, 3.8)])
	gallery("galerie_o", 4.2, Rect2(44, 4, 4, 36), [], [[WEST, 4.0, 18.5], [WEST, 21.5, 40.0]], [Vector2(44.2, 14), Vector2(44.2, 28), Vector2(44.2, 39.5)])
	gallery("bruecke", 4.2, Rect2(18, 18, 26, 3), [], [[NORTH, 18.0, 44.0], [SOUTH, 18.0, 44.0]], [Vector2(26, 19.5), Vector2(36, 19.5)])
	gallery("plattform", 4.2, Rect2(12, 16, 6, 7), [], [[WEST, 16.0, 23.0], [NORTH, 12.0, 18.0], [EAST, 16.0, 17.9], [EAST, 21.1, 23.0], [SOUTH, 12.0, 13.9], [SOUTH, 16.1, 18.0]], [Vector2(12.3, 16.3), Vector2(12.3, 22.7)])
	door("galerie_n", "galerie_o", 46.0, 4.0, {"kind": "join"})
	door("galerie_o", "bruecke", 19.5, 3.0, {"kind": "join"})
	door("bruecke", "plattform", 19.5, 3.0, {"kind": "join"})
	flight(Vector3(5, 0, 11.2), Vector3(5, 4.2, 4.0), Vector3(5, 0, 12.6), Vector3(5, 4.2, 2.0))
	flight(Vector3(15, 0, 30.2), Vector3(15, 4.2, 23.0), Vector3(15, 0, 31.6), Vector3(15, 4.2, 20.5))
	# --- the roof: a grid of beams under glass, and the grow lights in it
	m._chunk("Kit", false)
	for x in range(4, 48, 8):
		block("plate", Vector3(x, 9.7, 22.0), Vector3(0.25, 0.4, 43.6), Color("1c2420"), false)
	for z in range(4, 44, 8):
		block("plate", Vector3(24.0, 9.7, z), Vector3(47.6, 0.4, 0.25), Color("1c2420"), false)
	# The grow lights: long violet bars hanging under the roof, each with its cone.
	for x in [8.0, 24.0, 40.0]:
		for z in [8.0, 22.0, 36.0]:
			strip(Vector3(x, 8.2, z), 7.0, true, Color("c27aff"), 7.0)
			for edge in [-3.0, 3.0]:
				m._pipe(p(x + edge, 8.3, z), p(x + edge, 9.5, z), 0.012, Color("111111"), 4, "plain")
			var beam := cone(Vector3(x, 8.1, z), Vector3.DOWN, Color("b98cff"), 9.5, 15.0, 76.0, 1.7)
			beam.spot_attenuation = 0.8
	# --- paths of gravel, the beds, the trees, what grew
	for path in [Rect2(22.5, 4, 3, 39.8), Rect2(0.2, 29, 47.6, 2.6), Rect2(25.5, 11, 18.5, 2.4)]:
		m._part("gravel", p(path.get_center().x, 0.01, path.get_center().y), Vector3(path.size.x, 0.02, path.size.y), Color(0.6, 0.58, 0.52))
	for bed: Rect2 in BEDS:
		var middle := bed.get_center()
		block("formwork", Vector3(middle.x, 0.4, middle.y), Vector3(bed.size.x, 0.8, bed.size.y), Color(0.55, 0.55, 0.52))
		m._part("lawn", p(middle.x, 0.82, middle.y), Vector3(bed.size.x - 0.3, 0.06, bed.size.y - 0.3), Color(0.24, 0.3, 0.16))
		for k in range(3):
			_bulb(Vector3(bed.position.x + bed.size.x * (k + 0.5) / 3.0, 0.85, middle.y), m.random.randf_range(0.25, 0.55))
	for spot: Vector2 in TREES:
		m._tree(p(spot.x, 0, spot.y), m.random.randf_range(6.0, 8.5))
	for spot in [Vector3(0.3, 0, 16), Vector3(0.3, 0, 38), Vector3(47.7, 0, 30), Vector3(30, 0, 43.7)]:
		for k in range(4):
			var start := p(spot.x, 0.2, spot.z)
			m._hose(start, start + Vector3(m.random.randf_range(-0.6, 0.6), m.random.randf_range(4.0, 8.0), m.random.randf_range(-0.6, 0.6)), 0.07, Color("2f4a1c"), 0.6, Vector3(0.3, 0, 0.3), 8)
	_bulb(Vector3(24.0, 0.0, 24.0), 1.2)
	light(Vector3(24.0, 2.0, 24.0), Color("9cff6a"), 2.4, 9.0, 0.3, 2.0)
	_mood()
	stencil("halle", NORTH, 12.0, 6.5, "BIOTOP  G-3", 200, Color(0.3, 0.45, 0.25))
	# --- ways in: out of the soil, out of the walls, from the roof on to the paths
	trench("halle", 24.0, 34.0, 1)
	trench("halle", 42.0, 24.0, 0)
	hole("halle", WEST, 20.0, "pipes")
	hole("halle", SOUTH, 16.0, "breach")
	hole("halle", EAST, 34.0, "vent")
	# (Between the beams of the roof and clear of its lights.)
	drop("halle", 16.0, 8.0, 1, {"shaft": 2.0})
	drop("halle", 8.0, 24.0, 0, {"shaft": 2.0})
	drop("halle", 32.0, 32.0, 2, {"shaft": 2.0})
	point("goal", Vector3(22.0, 0, 24.0))
	point("middle", Vector3(24.0, 0, 22.0))

## A swollen bulb of a plant that should not be: glowing, on a stalk.
func _bulb(at: Vector3, size: float) -> void:
	m._part("lawn", p(at.x, at.y + size * 0.6, at.z), Vector3(0.12, size * 1.2, 0.12), Color(0.2, 0.3, 0.12))
	m._glow_ball(p(at.x, at.y + size * 1.3, at.z), size * 0.5, Color("b6ff6a"), 2.4)

## The light and the air of the biotope (after the user's picture pflanze.jpeg): violet
## grow light from above, green glowing bulbs under glass domes on the beds, roots over
## the floor with veins that glow, spores floating in a violet haze, dark walls with
## green tubes on them.
func _mood() -> void:
	m._chunk("Kit", false)
	var green := Color("7dff5a")
	# The beds: a dome of glass over every bulb, and a green light over each bed.
	for bed: Rect2 in BEDS:
		var middle := bed.get_center()
		for k in range(3):
			var at := p(bed.position.x + bed.size.x * (k + 0.5) / 3.0, 0.85, middle.y)
			m.batch.ellipsoid(frost(Color(0.55, 1.0, 0.45), 0.22, 1.2), at, Vector3(0.55, 0.75, 0.55), Color.WHITE, Basis.IDENTITY, 12, 6)
		light(Vector3(middle.x, 1.9, middle.y), green, 1.6, 6.0, 0.0, 2.2)
	# Roots over the floor from the trees, with veins that glow green and red.
	for tree: Vector2 in TREES:
		for k in range(5):
			var turn := TAU * (k + m.random.randf() * 0.6) / 5.0
			var long := m.random.randf_range(2.4, 4.2)
			var from := Vector3(tree.x, 0.12, tree.y) + Vector3(cos(turn), 0, sin(turn)) * 0.35
			var to := Vector3(tree.x, 0.05, tree.y) + Vector3(cos(turn), 0, sin(turn)) * long
			var bow := Vector3(-sin(turn), 0, cos(turn)) * m.random.randf_range(-0.6, 0.6)
			m._hose(o + from, o + to, 0.13, Color("2a2218"), -0.08, bow, 7, "plain")
			var vein := Color("8cff4a") if k % 3 != 2 else Color("ff5a2a")
			var factor := pow(5.5 / 7.0, 1.0 / 2.2)
			m._hose(o + from + Vector3(0, 0.12, 0), o + to + Vector3(0, 0.06, 0), 0.025, Color(vein.r * factor, vein.g * factor, vein.b * factor), -0.08, bow, 7, "steady")
		light(Vector3(tree.x, 0.5, tree.y), Color("7dff5a"), 0.8, 4.5, 0.0, 1.2)
	# Dark walls with green tubes on them, and a thin green line along their foot.
	for spot in [Vector3(0.28, 1.8, 10.0), Vector3(0.28, 1.8, 26.0), Vector3(0.28, 1.8, 40.0), Vector3(47.72, 1.8, 6.0), Vector3(47.72, 1.8, 22.0), Vector3(47.72, 1.8, 38.0), Vector3(8.0, 1.8, 43.72), Vector3(40.0, 1.8, 43.72), Vector3(16.0, 6.4, 0.28), Vector3(30.0, 6.4, 0.28)]:
		var into := Vector3(0.5 if spot.x < 1.0 else (-0.5 if spot.x > 47.0 else 0.0), 0, 0.5 if spot.z < 1.0 else (-0.5 if spot.z > 43.0 else 0.0))
		m._part("plate", o + spot + into * 0.08, Vector3(0.16, 1.7, 0.16), Color("1a1d1c"))
		glow(spot + into * 0.2, Vector3(0.08, 1.5, 0.08), green, 6.5)
		light(spot + into * 0.8, green, 0.9, 4.5, 0.0, 1.0)
	for side in [[Vector3(0.24, 0.45, 22.0), Vector3(0.03, 0.04, 43.0)], [Vector3(47.76, 0.45, 22.0), Vector3(0.03, 0.04, 43.0)], [Vector3(24.0, 0.45, 43.76), Vector3(47.0, 0.04, 0.03)]]:
		glow(side[0], side[1], green, 4.5)
	# Spores in the air, green and violet, and the haze they float in.
	drift(Vector3(24.0, 4.5, 22.0), Vector3(44.0, 8.0, 40.0), 260, Color(0.55, 1.0, 0.45), {"size": 0.06, "life": 14.0, "rise": 0.02, "spread": 0.12, "glow": true, "alpha": 0.9})
	drift(Vector3(24.0, 6.0, 22.0), Vector3(44.0, 6.0, 40.0), 160, Color(0.85, 0.6, 1.0), {"size": 0.05, "life": 14.0, "rise": -0.01, "spread": 0.1, "glow": true, "alpha": 0.8})
	mist(Vector3(24.0, 0.8, 22.0), Vector3(46.0, 1.6, 42.0), 0.05, Color(0.75, 0.9, 0.7), false, 0.4)
	mist(Vector3(24.0, 6.5, 22.0), Vector3(46.0, 5.0, 42.0), 0.02, Color(0.85, 0.75, 1.0), false, 0.4)
	# Puddles that mirror the grow light, and cables over the soil.
	for spot in [Rect2(17.0, 38.0, 3.0, 1.6), Rect2(31.0, 20.5, 2.4, 1.4), Rect2(9.0, 21.0, 2.0, 2.2), Rect2(38.5, 14.5, 2.6, 1.2)]:
		wet_floor(spot, 0.0, Color(0.08, 0.08, 0.1), 3.0)
	for pair in [[Vector3(13.0, 0.0, 27.5), Vector3(20.0, 0.0, 26.0)], [Vector3(13.0, 0.0, 34.5), Vector3(19.0, 0.0, 39.0)], [Vector3(30.0, 0.0, 35.5), Vector3(26.0, 0.0, 39.0)], [Vector3(29.0, 0.0, 10.0), Vector3(27.0, 0.0, 15.0)], [Vector3(36.0, 0.0, 27.0), Vector3(31.5, 0.0, 24.0)]]:
		cable(pair[0], pair[1], 0.7)
