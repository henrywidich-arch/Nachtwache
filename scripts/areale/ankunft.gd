extends AreaKit
## Arrival (the train comes in): a platform of the facility's sector C, like the terminal -
## the car the squad rides in stands at its edge (the ride ends in this car, HiveMap
## .ride_areal), a supply point at its north wall, a control room up a few steps beside
## it whose desk opens the gate to the sector.

func info() -> Dictionary:
	return {
		"id": "ankunft", "kind": "arrival", "label": "BAHNSTEIG C", "name": "Ankunft · Bahnsteig", "class": "gross",
		"size": Vector2(56.0, 31.0), "levels": [0.0], "mood": "cold",
		"views": [["oben", Vector3(4, 8, 22), Vector3(40, 0, 8)], ["auge", Vector3(28, 1.62, 21), Vector3(14, 2, 0)], ["leitstand", Vector3(48, 1.62, -6), Vector3(40, 1, 10)]],
		"reach": [Rect2(-15.0, 24.0, 15.0, 7.0), Rect2(56.0, 24.0, 15.0, 7.0), Rect2(40.0, -9.0, 16.0, 9.0)],
		"ports": [{"side": NORTH, "at": 14.0, "y": 0.0, "room": "bahnsteig", "role": "out"}],
		"goal": "Im Leitstand das Tor zum Sektor öffnen", "use": "[E] Tor zum Sektor öffnen",
		"crowd": [["mauler", "mauler", "striker", "ripper", "leech"], 8, 10.0, [2, 4]],
		"posts": [["mauler", Vector3(14, 0, 8)], ["mauler", Vector3(34, 0, 12)], ["striker", Vector3(44, 0, 6)], ["mauler", Vector3(6, 0, 16)], ["charger", Vector3(50, 0, 16)]],
		"strength": 5
	}

func lay() -> void:
	room("bahnsteig", 0.0, 0, 0, 56, 24, 9.5, "bighall", {"bare": [SOUTH]})
	room("gleis", 0.0, 0, 24, 56, 7, 9.5, "bighall", {"bare": [NORTH], "nav": false, "floor": false, "lamps": "none"})
	for side in [WEST, EAST]:
		opening("gleis", side, 26.0, 5.4, {"kind": "join", "height": 4.6, "nav": false})
	# The car: its room is only a place (the car builds itself), its doorway the station's.
	in_zone("wagen", "cold", func() -> void:
		room("wagen", 0.0, 21, 24, 14, 4, 2.6, "car", {"walls": false, "floor": false, "ceiling": false, "lamps": "none"})
		m._train_car(p(28, 0, 26), NORTH))
	door("wagen", "bahnsteig", 28.0, 2.4, {"kind": "script", "name": "%s_car" % str(piece.id), "height": 2.2})
	m._chunk("Kit", false)
	HiveAreale.track(m, n("gleis"), o.z + 24.0, -1.0)
	m._train_ends(p(28, 0, 26))
	m._chunk("Kit", false)
	for piece_x in [[0.0, 26.6], [29.4, 56.0]]:
		m._add_shape(m.rails, p((float(piece_x[0]) + float(piece_x[1])) * 0.5, 0.6, 23.9), Vector3(float(piece_x[1]) - float(piece_x[0]), 1.2, 0.1))
	# The control room, a few steps up behind glass at the north-east corner.
	room("leitstand", 0.0, 40, -9, 16, 9, 3.2, "panel", {"look": {"light": Color("bcd2ff"), "energy": 1.4}})
	door("bahnsteig", "leitstand", 44.0, 1.8, {"kind": "slide"})
	pane("bahnsteig", NORTH, 50.5, 7.0, 0.95, 2.6, "glass", "leitstand")
	m._console(n("leitstand"), NORTH, o.x + 43.0, o.x + 54.0, [3, 1, 5, 4])
	m._chunk("Kit", false)
	# Pillars in two rows, clear of the way from the car to the gate.
	for z in [8.0, 16.0]:
		for x in [7.0, 21.0, 35.0, 49.0]:
			m._pillar(p(x, 0, z), 0.9, 9.5)
	# The way: yellow lines from the car's doors to the gate, its name over the gate.
	m._stripe(p(12.5, 0, 22.0), p(12.5, 0, 1.0), 0.14, Color("c9a227"))
	m._stripe(p(15.5, 0, 22.0), p(15.5, 0, 1.0), 0.14, Color("c9a227"))
	m._stripe(p(15.5, 0, 22.0), p(27.0, 0, 22.0), 0.14, Color("c9a227"))
	stencil("bahnsteig", NORTH, 14.0, 5.6, "SEKTOR  C", 220, Color(0.62, 0.66, 0.72))
	stencil("bahnsteig", WEST, 12.0, 4.0, "C-1", 300, Color(0.62, 0.5, 0.2))
	m._hang_sign(p(28.0, 5.4, 18.0), 0.0, 7.0, "SEKTOR C  ·  FORSCHUNG", 1.6, Color("e8d9a0"), 90, 1.0)
	for spot in [Vector3(4, 0, 4), Vector3(52, 0, 20), Vector3(24, 0, 3)]:
		m._stores(o + spot, 3)
	m._luggage(p(33.0, 0, 20.0), 4, 1.0)
	m._barricade(p(6.0, 0, 11.0), PI / 2, 3.6)
	m._blot(p(9.0, 0, 13.0), 1.0, 0.7)
	# Ways in: up from the track, out of the walls, from the roof.
	for x in [8.0, 40.0, 50.0]:
		edge("bahnsteig", Vector3(x, 0, 24.0), Vector3(0, 0, -1))
	duct("bahnsteig", WEST, 6.0, {"sill": 2.6, "trunk": 5.4})
	duct("bahnsteig", EAST, 10.0, {"sill": 2.6, "trunk": 5.4})
	hole("bahnsteig", NORTH, 28.0, "breach")
	drop("bahnsteig", 20.0, 12.0, 1)
	drop("bahnsteig", 40.0, 10.0, 3)
	drop("leitstand", 42.5, -4.5, 0, {"shaft": 2.2})
	ride_tunnel(Vector3(28, 0, 26))
	point("car", Vector3(28, 0, 26))
	point("in", Vector3(28, 0, 21))
	point("control", Vector3(48.5, 0, -6.4))
	point("hall", Vector3(28, 0, 12))
	point("out", Vector3(14, 0, 2.6))
