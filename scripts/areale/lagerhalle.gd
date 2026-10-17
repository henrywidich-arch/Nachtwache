extends AreaKit
## Area: the storage hall. GREYBOX.
##
## 52 x 40 metres of concrete, 11 high: four rows of high racks with lanes between them and
## a wide lane down the middle, a crane on its gantry over all of it with a container on
## the hook, and along the west wall a gallery at 4.2 with the store's office on it,
## reached by a stair at its south end.

## The rows of racks: their middle line (local z), and the two stretches along x.
const ROWS := [9.0, 15.0, 25.0, 31.0]
const STRETCHES := [[9.0, 22.0], [30.0, 44.0]]
const RACK_TALL := 6.0
const RACK_DEEP := 1.4

func info() -> Dictionary:
	return {
		"id": "lagerhalle", "kind": "area", "label": "LAGERHALLE", "name": "Lagerhalle (Hochregale, Kran)", "class": "gross",
		"size": Vector2(52.0, 40.0), "levels": [0.0, 4.2], "mood": "store",
		"staff": ["hive_worker", "hive_office"],
		"views": [["bild", Vector3(50, 1.9, 21.5), Vector3(4, 5.6, 10)], ["gasse", Vector3(49, 1.8, 37.5), Vector3(6, 4.5, 8)], ["oben_sw", Vector3(2, 9.8, 38), Vector3(30, 0, 14)], ["oben_no", Vector3(50, 9.8, 2), Vector3(20, 0, 28)], ["auge", Vector3(26, 1.62, 38), Vector3(26, 2, 4)], ["galerie", Vector3(4, 5.82, 30), Vector3(30, 2, 20)]],
		"ports": [
			{"side": SOUTH, "at": 26.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": WEST, "at": 20.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": NORTH, "at": 26.0, "y": 0.0, "room": "halle", "role": "out"},
			{"side": EAST, "at": 20.0, "y": 0.0, "room": "halle", "role": "out"}
		],
		"events": [
			{"kind": "restore", "goal": "Den Kran freischalten, damit er den Container vom Tor hebt", "use": "[E] Kransteuerung freischalten", "count": 2, "after": 25.0, "progress": "KRAN HEBT DEN CONTAINER"},
			{"kind": "collect", "goal": "Die Zugangskarten für das Tor finden", "word": "Zugangskarte", "use": "[E] Karte nehmen", "count": 3},
			{"kind": "hold", "goal": "Halten, bis der Lastenaufzug das Tor freigibt", "seconds": 55.0, "progress": "LASTENAUFZUG FÄHRT", "radius": 15.0}
		],
		"spots": {
			"goal": Vector3(26.0, 0, 20.0),
			"switches": [Vector3(48.0, 0, 2.2), Vector3(6.5, 4.2, 5.2), Vector3(48.0, 0, 37.8)],
			"items": [Vector3(12.0, 0, 12.0), Vector3(40.0, 0, 28.0), Vector3(2.0, 4.2, 30.0), Vector3(26.0, 0, 36.0), Vector3(48.0, 0, 20.0), Vector3(2.0, 4.2, 12.6)]
		},
		"crowd": [["mauler", "mauler", "striker", "ripper", "charger"], 10, 8.5, [2, 4]],
		"posts": [["mauler", Vector3(15, 0, 12)], ["mauler", Vector3(37, 0, 20)], ["ripper", Vector3(48, 0, 30)], ["charger", Vector3(26, 0, 6)], ["mauler", Vector3(2, 4.2, 24)], ["striker", Vector3(15, 0, 28)]],
		"strength": 7,
		"lines": {"enter": ["talk:m2_offices"], "event": []},
		"caches": [["buero_tresor", "buero", NORTH, 4.0, "tresor", "LAGERBÜRO"], ["regal_kiste", "halle", EAST, 31.0, "kiste", "LAGERHALLE"]],
		"station": ["halle", SOUTH, [["cabinet", 36.0], ["bench", 39.6]]],
		"supply": [Vector3(19.0, 0, 39.3), Vector3(0, 0, -1)]
	}

func lay() -> void:
	room("halle", 0.0, 0, 0, 52, 40, 11.0, "concrete", {"lamps": "none", "look": {"stripe": Color("b8961e")}})
	# --- the gallery with the office on it, and the stair up at its south end
	room("buero", 4.2, 0.2, 4, 7.8, 10, 3.2, "office", {"bare": [WEST], "look": {"light": Color("e6f4ff"), "energy": 2.8}})
	pane("buero", EAST, 9.0, 7.0, 1.0, 2.6, "glass")
	gallery("steg", 4.2, Rect2(0, 14, 8, 24.6), [], [[EAST, 14.0, 36.4], [SOUTH, 0.0, 8.0]], [Vector2(7.7, 22), Vector2(7.7, 30), Vector2(7.7, 38.7)])
	door("buero", "steg", 4.0, 1.8, {"kind": "slide"})
	for z in [4.3, 13.7]:
		post(Vector2(7.7, z), 4.2)
	flight(Vector3(15.2, 0, 37.5), Vector3(8.0, 4.2, 37.5), Vector3(16.6, 0, 37.5), Vector3(4.0, 4.2, 37.5))
	m._desk(p(3.0, 4.2, 10.0), PI / 2, 2)
	m._office_chair(p(4.6, 4.2, 9.0), 1.2)
	# --- the racks: uprights, beams, what is stored
	m._chunk("Kit", false)
	for z in ROWS:
		for stretch: Array in STRETCHES:
			var from := float(stretch[0])
			var to := float(stretch[1])
			var middle := Vector3((from + to) * 0.5, RACK_TALL * 0.5, float(z))
			m._solid(o + middle, Vector3(to - from, RACK_TALL, RACK_DEEP))
			var x := from
			while x <= to + 0.01:
				for edge in [-0.6, 0.6]:
					m._part("plate", p(x, RACK_TALL * 0.5, float(z) + edge), Vector3(0.1, RACK_TALL, 0.1), Color("2f4f7a"))
				x += 2.6
			for level in [0.15, 1.6, 3.1, 4.6]:
				m._part("plate", p((from + to) * 0.5, level, float(z) - 0.6), Vector3(to - from, 0.12, 0.08), Color("c26a1a"))
				m._part("plate", p((from + to) * 0.5, level, float(z) + 0.6), Vector3(to - from, 0.12, 0.08), Color("c26a1a"))
				var at := from + 0.8
				while at < to - 0.8:
					if m.random.randf() < 0.75:
						var size := Vector3(m.random.randf_range(0.9, 1.4), m.random.randf_range(0.6, 1.2), 1.1)
						m._part("panelwood", p(at, level + 0.1 + size.y * 0.5, float(z)), size, m._vary(Color(0.55, 0.45, 0.3), 0.06))
					at += 1.6
	# --- the crane: its rails along the walls, the gantry over the middle, a container
	for x in [0.6, 51.4]:
		m._part("plate", p(x, 9.4, 20.0), Vector3(0.4, 0.5, 39.5), Color("3a3d40"))
	m._part("plate", p(26.0, 9.9, 20.0), Vector3(50.4, 0.8, 1.2), Color("c9a227"))
	m._hazard(p(0.8, 9.48, 20.6), p(51.2, 9.48, 20.6), Vector3(0.8, 0.02, 0.02), 32)
	m._pipe(p(40.0, 9.5, 20.0), p(40.0, 7.6, 20.0), 0.03, Color("1a1a1a"), 6, "steel")
	m._part("plate", p(40.0, 6.3, 20.0), Vector3(6.0, 2.6, 2.4), Color("2f6f8a"))
	stencil("halle", NORTH, 40.0, 8.0, "LAGER  L-2", 240, Color(0.45, 0.4, 0.2))
	_mood()
	m._stripe(p(22.5, 0, 1.0), p(22.5, 0, 39.0), 0.14, Color("c9a227"))
	m._stripe(p(29.5, 0, 1.0), p(29.5, 0, 39.0), 0.14, Color("c9a227"))
	for spot in [Vector3(48, 0, 12), Vector3(4, 0, 30), Vector3(36, 0, 36)]:
		m._pallet(o + spot, m.random.randf_range(-0.2, 0.2), m.random.randi_range(0, 3), 1.2)
	# --- ways in: from the roof into the lanes, out of the walls, into the office
	drop("halle", 26.0, 12.0, 1, {"shaft": 2.0})
	drop("halle", 15.0, 23.0, 0, {"shaft": 2.0})
	drop("halle", 40.0, 34.0, 2, {"shaft": 2.0})
	drop("halle", 3.0, 26.0, 3, {"land": 4.2, "shaft": 2.0})
	drop("buero", 4.1, 6.0, 0)
	hole("halle", EAST, 9.0, "breach")
	hole("halle", NORTH, 12.0, "vent")
	hole("halle", SOUTH, 46.0, "pipes")
	duct("halle", WEST, 30.0, {"sill": 2.6, "trunk": 4.0})
	point("goal", Vector3(26.0, 0, 20.0))
	point("middle", Vector3(26.0, 0, 20.0))

## The light and the air of the hall (after the user's picture lager.jpeg): warm sodium
## lamps under the roof throw cones through dusty air on to the lanes, a few cold tubes
## hang between them, the office up on the gallery is the brightest window of the hall,
## the aisles between the racks stay dark, and a small work lamp burns on the floor.
func _mood() -> void:
	m._chunk("Kit", false)
	var sodium := Color("ffb055")
	# The sodium lamps: a cone each through the dust, on the lanes and the aisles' ends.
	var spots := [
		Vector2(6, 18), Vector2(16, 18), Vector2(26, 18), Vector2(36, 18.4), Vector2(46, 18),
		Vector2(15, 12), Vector2(37, 12), Vector2(15, 28), Vector2(37, 28),
		Vector2(18, 4), Vector2(34, 4), Vector2(48, 4), Vector2(18, 35.5), Vector2(34, 35.5), Vector2(48, 35.5),
		Vector2(26, 8), Vector2(26, 30)
	]
	for spot: Vector2 in spots:
		m.batch.cylinder(m.mats["steel"], p(spot.x, 10.62, spot.y), 0.22, 0.32, 0.38, Color("1c1d1d"), 10)
		glow(Vector3(spot.x, 10.6, spot.y), Vector3(0.5, 0.02, 0.5), Color("ffd090"), 7.0)
		m._pipe(p(spot.x, 11.0, spot.y), p(spot.x, 10.98, spot.y), 0.02, Color("101010"), 4, "plain")
		var beam := cone(Vector3(spot.x, 10.5, spot.y), Vector3.DOWN, sodium, 14.0, 17.0, 32.0, 2.6)
		beam.spot_attenuation = 0.7
		beam.spot_angle_attenuation = 2.2
	# A little warm light from the walls keeps the hall's shape (no shadows).
	for spot in [Vector3(26.0, 8.0, 1.0), Vector3(26.0, 8.0, 39.0), Vector3(51.0, 8.0, 12.0), Vector3(51.0, 8.0, 30.0), Vector3(9.0, 8.5, 20.0), Vector3(40.0, 3.0, 20.0)]:
		light(spot, Color("ffc890"), 1.2, 16.0, 0.0, 0.05)
	# A few cold tubes hanging from the roof.
	for spot in [Vector3(10.0, 8.2, 20.0), Vector3(30.0, 8.2, 4.5), Vector3(44.0, 8.2, 28.0), Vector3(22.0, 8.2, 35.5)]:
		strip(spot, 2.6, true, Color("dff0ff"), 6.5)
		for edge in [-1.1, 1.1]:
			m._pipe(p(spot.x + edge, spot.y + 0.1, spot.z), p(spot.x + edge, 11.0, spot.z), 0.012, Color("121212"), 4, "plain")
		light(spot - Vector3(0, 0.5, 0), Color("dff0ff"), 1.1, 8.0, 0.0, 0.6)
	# The office up on the gallery: bright behind its glass.
	light(Vector3(4.2, 7.0, 9.0), Color("e6f4ff"), 1.6, 6.0, 0.0, 0.3)
	glow(Vector3(0.45, 6.0, 9.0), Vector3(0.04, 1.2, 4.0), Color("cfe8ff"), 2.4)
	for z in [6.0, 8.2, 10.4]:
		m._screen(Transform3D(Basis(Vector3.UP, PI / 2), p(0.5, 5.6, z)), Vector3.ZERO, Vector2(0.9, 0.55), 5 + int(z) % 4)
	# The work lamp on the floor by the racks: small, warm, a little unsteady.
	m._pipe(p(24.6, 0.0, 26.6), p(24.6, 0.9, 26.6), 0.03, Color("2a2a2a"), 6, "steel")
	m._part("plate", p(24.6, 0.02, 26.6), Vector3(0.5, 0.04, 0.5), Color("2a2a2a"))
	m.batch.cylinder(m.mats["steel"], p(24.6, 0.86, 26.6), 0.16, 0.08, 0.18, Color("3a2a1a"), 10)
	m._glow_ball(p(24.6, 0.86, 26.6), 0.07, Color("ffb050"), 7.0)
	light(Vector3(24.6, 0.95, 26.0), Color("ff9a3a"), 2.4, 7.0, 0.07, 1.6)
	cable(Vector3(24.6, 0.0, 26.6), Vector3(22.6, 0.0, 33.0), 0.6)
	# Dust in the air, which the cones catch.
	drift(Vector3(26.0, 5.0, 20.0), Vector3(48.0, 9.0, 36.0), 420, Color(1.0, 0.9, 0.75), {"size": 0.035, "life": 14.0, "rise": -0.01, "spread": 0.06, "alpha": 0.8})
	# Under the roof: ducts, cables that sag, and chains with hooks from the crane.
	for z in [8.0, 32.0]:
		block("plate", Vector3(30.0, 10.5, z), Vector3(42.0, 0.7, 1.2), Color("2a2c2d"), false)
	for k in range(4):
		var z := 6.0 + k * 9.0
		cables(Vector3(2.0, 10.8, z), Vector3(50.0, 10.8, z + 1.0), 3, 1.4)
	for spot in [Vector3(36.0, 9.5, 20.2), Vector3(44.5, 9.5, 20.2), Vector3(14.0, 9.5, 20.2)]:
		chain(spot, m.random.randf_range(2.4, 3.6))
	# A floor wet in places down the middle lane.
	wet_floor(Rect2(22.8, 0.6, 6.4, 38.8), 0.0, Color(0.3, 0.29, 0.27), 1.4)
