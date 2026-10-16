extends AreaKit
## Arrival (the train is derailed): the car the squad rode in stands in the dark tunnel
## where the ride ended with a crash (the ride ends in this car: HiveMap.ride_areal); the
## locomotive lies wrecked against the tunnel wall ahead of it and burns. Along the narrow
## walkway beside the track it is a short way to an emergency exit, and behind it a stair
## leads two storeys up (HiveAreale.stair_shaft) to a landing whose door opens on the
## sector. Its floor is two storeys below the sector's: the way out lies at 8.4.

func info() -> Dictionary:
	return {
		"id": "absturz", "kind": "arrival", "label": "IM TUNNEL", "name": "Ankunft · Zugunglück im Tunnel", "class": "mittel",
		"size": Vector2(74.0, 38.0), "levels": [0.0, 8.4], "mood": "deep",
		"reach": [Rect2(-15.0, 32.0, 15.0, 6.0), Rect2(74.0, 32.0, 15.0, 6.0)],
		"ports": [{"side": NORTH, "at": 60.0, "y": 8.4, "room": "oben", "role": "out", "open": true}],
		"goal": "Durch den Tunnel zum Notausstieg", "goal_up": "Den Notweg hinauf in den Sektor",
		"crowd": [["mauler", "mauler", "ripper", "striker"], 6, 10.0, [2, 3]],
		"posts": [["mauler", Vector3(30, 0, 30.5)], ["mauler", Vector3(52, 0, 30.5)], ["ripper", Vector3(66, 0, 30.5)]],
		"strength": 5
	}

func lay() -> void:
	room("bankett", 0.0, 0, 29, 74, 3, 5.5, "concrete", {"bare": [SOUTH], "lamps": "none", "look": {"stripe": Color("b8961e")}})
	room("gleis", 0.0, 0, 32, 74, 6, 5.5, "concrete", {"bare": [NORTH], "nav": false, "floor": false, "lamps": "none"})
	for side in [WEST, EAST]:
		opening("gleis", side, 35.0, 5.4, {"kind": "join", "height": 4.6, "nav": false})
	in_zone("wagen", "cold", func() -> void:
		room("wagen", 0.0, 6, 32, 14, 4, 2.6, "car", {"walls": false, "floor": false, "ceiling": false, "lamps": "none"})
		m._train_car(p(13, 0, 34), NORTH))
	door("wagen", "bankett", 13.0, 2.4, {"kind": "script", "name": "%s_car" % str(piece.id), "height": 2.2})
	room("notgang", 0.0, 56, 24, 8, 5, 3.2, "concrete", {"look": {"light": Color("ff8a6a"), "energy": 1.2}})
	door("bankett", "notgang", 60.0, 1.8, {"kind": "frame"})
	room("oben", 8.4, 52, 0, 16, 6, 3.2, "concrete", {"look": {"light": Color("ffd0a0"), "energy": 1.6}})
	opening("oben", SOUTH, 60.0, HiveAreale.FLIGHT, {"kind": "join", "height": 3.0, "nav": false})
	opening("notgang", NORTH, 60.0, HiveAreale.FLIGHT, {"kind": "join", "height": 3.0, "nav": false})
	HiveAreale.stair_shaft(m, Vector2(o.x + 60.0, o.z + 6.0), SOUTH, 4.6, y(8.4), y(0.0), 3.2, lv(8.4), lv(0.0))
	m._chunk("Kit", false)
	HiveAreale.track(m, n("gleis"), o.z + 32.0, -1.0)
	m._chunk("Kit", false)
	# The edge of the walkway stops everybody but at the car's doors.
	for piece_x in [[0.0, 11.6], [14.4, 74.0]]:
		m._add_shape(m.rails, p((float(piece_x[0]) + float(piece_x[1])) * 0.5, 0.6, 31.9), Vector3(float(piece_x[1]) - float(piece_x[0]), 1.2, 0.1))
	# The wreck: the locomotive torn off the rails and thrown against the south wall, the
	# flat car across the track behind it, burning, sparks from a torn cable.
	var yellow := Color(0.78, 0.6, 0.12)
	m._part("plate", p(46.0, 0.2, 35.6), Vector3(11.0, 2.8, 3.4), yellow, Vector3(14.0, 9.0, 0.0))
	m._part("plate", p(45.0, 2.1, 35.8), Vector3(7.0, 0.8, 3.0), Color("17191b"), Vector3(14.0, 9.0, 0.0))
	m._add_shape(m.body, p(46.0, 0.6, 35.4), Vector3(11.0, 3.6, 3.4), Basis.from_euler(Vector3(deg_to_rad(14.0), deg_to_rad(9.0), 0.0)))
	m._part("plate", p(34.0, -0.4, 34.6), Vector3(10.0, 0.6, 3.2), Color("17191b"), Vector3(0.0, 18.0, 6.0))
	m._add_shape(m.body, p(34.0, -0.2, 34.6), Vector3(10.0, 1.2, 3.2), Basis.from_euler(Vector3(0.0, deg_to_rad(18.0), deg_to_rad(6.0))))
	for k in range(9):
		var at := p(m.random.randf_range(30.0, 56.0), 0.05, m.random.randf_range(29.4, 31.6))
		m._part("beton", at, Vector3(m.random.randf_range(0.2, 0.5), 0.1, m.random.randf_range(0.2, 0.4)), Color(0.4, 0.4, 0.38), Vector3(0, m.random.randf_range(0, 180), 0))
	var fire := light(Vector3(44.0, 1.4, 34.0), Color("ff7a2a"), 3.4, 12.0, 0.6)
	fire.omni_attenuation = 1.2
	glow(Vector3(43.0, 0.9, 34.4), Vector3(1.6, 0.3, 1.0), Color("ff6a1a"), 5.0)
	m._sparks(p(50.0, 4.6, 33.0), 2.1)
	# The emergency lamps along the walkway, red; the green sign of the exit.
	for x in [6.0, 22.0, 38.0, 54.0, 70.0]:
		glow(Vector3(x, 3.2, 29.25), Vector3(0.3, 0.12, 0.06), Color("ff3a2a"), 4.5)
		light(Vector3(x, 3.0, 30.0), Color("ff4a3a"), 1.2, 7.5, 0.05)
	glow(Vector3(60.0, 2.95, 29.22), Vector3(1.4, 0.32, 0.04), Color("5ee07a"), 5.0)
	m._wall_sign("NOTAUSSTIEG", p(60.0, 2.95, 29.15), 40, Color("0b2a14"))
	light(Vector3(60.0, 2.6, 30.6), Color("6ef08a"), 1.4, 6.0)
	stencil("bankett", NORTH, 20.0, 3.6, "N-01  ·  KM 4,2", 90, Color(0.5, 0.45, 0.3))
	m._supply(p(30.0, 0, 29.7), Vector3(0, 0, 1), "NOTFALLDEPOT")
	# Ways in: up out of the track, out of the tunnel wall, from the shaft overhead.
	for x in [26.0, 58.0, 68.0]:
		edge("bankett", Vector3(x, 0, 32.0), Vector3(0, 0, -1))
	hole("bankett", NORTH, 44.0, "breach")
	hole("bankett", NORTH, 10.0, "vent")
	drop("notgang", 58.0, 26.5, 1)
	drop("oben", 55.0, 3.0, 0)
	ride_tunnel(Vector3(13, 0, 34))
	point("car", Vector3(13, 0, 34))
	point("in", Vector3(13, 0, 30.5))
	point("exit", Vector3(60, 0, 30.3))
	point("route", Vector3(60, 0, 26.5))
	point("top", Vector3(60, 8.4, 3.0))
