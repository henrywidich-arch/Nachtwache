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
		"views": [["oben_sw", Vector3(3, 8.8, 41), Vector3(28, 0, 18)], ["oben_no", Vector3(45, 8.8, 3), Vector3(20, 0, 30)], ["auge_einstieg", Vector3(24, 1.62, 41), Vector3(24, 1.5, 20)], ["steg", Vector3(40, 5.82, 2), Vector3(20, 1, 24)], ["bruecke", Vector3(30, 5.82, 19.5), Vector3(10, 2, 30)]],
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

## The raised beds (local x, z, w, d).
const BEDS := [Rect2(6, 26, 7, 3), Rect2(6, 33, 7, 3), Rect2(30, 34, 9, 3), Rect2(29, 8, 6, 4), Rect2(10, 8, 5, 6), Rect2(36, 24, 3, 7)]

func lay() -> void:
	room("halle", 0.0, 0, 0, 48, 44, 10.0, "lab", {
		"lamps": "none",
		"look": {"floor": ["lawn", Color(0.5, 0.6, 0.42)], "ceiling": ["plate", Color("1b2420")], "panel": Color(0.72, 0.78, 0.7), "stripe": Color("4f8f3a")}
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
	for x in [8.0, 24.0, 40.0]:
		for z in [8.0, 22.0, 36.0]:
			glow(Vector3(x, 9.86, z), Vector3(6.0, 0.05, 0.5), Color("f0b8ff"), 5.0)
			m._spot(p(x, 9.5, z), Vector3.DOWN, Color("f0dcff"), 16.0, 16.0, 78.0, 0.0, 0.8, HiveCore.LAMP_FADE + 10.0)
			light(Vector3(x, 4.0, z), Color("e6ffd8"), 1.8, 13.0)
	# --- paths of gravel, the beds, the trees, what grew
	for path in [Rect2(22.5, 4, 3, 39.8), Rect2(0.2, 29, 47.6, 2.6), Rect2(25.5, 11, 18.5, 2.4)]:
		m._part("gravel", p(path.get_center().x, 0.01, path.get_center().y), Vector3(path.size.x, 0.02, path.size.y), Color(0.6, 0.58, 0.52))
	for bed: Rect2 in BEDS:
		var middle := bed.get_center()
		block("formwork", Vector3(middle.x, 0.4, middle.y), Vector3(bed.size.x, 0.8, bed.size.y), Color(0.55, 0.55, 0.52))
		m._part("lawn", p(middle.x, 0.82, middle.y), Vector3(bed.size.x - 0.3, 0.06, bed.size.y - 0.3), Color(0.24, 0.3, 0.16))
		for k in range(3):
			_bulb(Vector3(bed.position.x + bed.size.x * (k + 0.5) / 3.0, 0.85, middle.y), m.random.randf_range(0.25, 0.55))
	for spot in [Vector2(6, 18), Vector2(16, 37), Vector2(34, 18), Vector2(40, 36), Vector2(28, 26), Vector2(10, 40), Vector2(38, 6)]:
		m._tree(p(spot.x, 0, spot.y), m.random.randf_range(6.0, 8.5))
	for spot in [Vector3(0.3, 0, 16), Vector3(0.3, 0, 38), Vector3(47.7, 0, 30), Vector3(30, 0, 43.7)]:
		for k in range(4):
			var start := p(spot.x, 0.2, spot.z)
			m._hose(start, start + Vector3(m.random.randf_range(-0.6, 0.6), m.random.randf_range(4.0, 8.0), m.random.randf_range(-0.6, 0.6)), 0.07, Color("2f4a1c"), 0.6, Vector3(0.3, 0, 0.3), 8)
	_bulb(Vector3(24.0, 0.0, 24.0), 1.2)
	light(Vector3(24.0, 2.0, 24.0), Color("9cff6a"), 1.6, 9.0, 0.3)
	m._haze(p(24.0, 0.8, 22.0), Vector3(46.0, 1.6, 42.0), 0.05, Color(0.7, 0.9, 0.6))
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
