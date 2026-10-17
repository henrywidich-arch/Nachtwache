extends AreaKit
## Area: the reactor shaft. GREYBOX.
##
## A square shaft of 32 metres, 13 high, around the glowing core of the reactor. Steel
## galleries run round it on two levels - the north and west sides at 4.2, the south and
## east sides at 8.4 - joined by two flights of stairs, so the chase goes round and up (or
## down: it can be entered at the bottom or at the top, and left at the other end or at
## the bottom again). Its upper way in and out lie at 8.4, two storeys over its floor.

func info() -> Dictionary:
	return {
		"id": "reaktorschacht", "kind": "area", "label": "REAKTORSCHACHT", "name": "Reaktorschacht (drei Ebenen)", "class": "mittel",
		"size": Vector2(32.0, 32.0), "levels": [0.0, 4.2, 8.4], "mood": "plant",
		"staff": ["hive_worker", "hive_worker", "zombie_soldier"],
		"views": [["bild", Vector3(22, 1.8, 31), Vector3(14.5, 4.0, 14)], ["oben", Vector3(2, 11.5, 30), Vector3(20, 0, 10)], ["auge_boden", Vector3(16, 1.62, 29), Vector3(16, 4, 16)], ["ebene_1", Vector3(4, 5.82, 20), Vector3(24, 4.2, 4)], ["ebene_2", Vector3(28, 10, 22), Vector3(4, 5, 8)]],
		"ports": [
			{"side": SOUTH, "at": 16.0, "y": 0.0, "room": "schacht", "role": "in"},
			{"side": WEST, "at": 16.0, "y": 0.0, "room": "schacht", "role": "in"},
			{"side": WEST, "at": 28.0, "y": 8.4, "room": "umlauf_s", "role": "in"},
			{"side": NORTH, "at": 28.0, "y": 8.4, "room": "umlauf_o", "role": "out"},
			{"side": EAST, "at": 28.0, "y": 0.0, "room": "schacht", "role": "out"}
		],
		"events": [
			{"kind": "restore", "goal": "Die drei Kühlkreisläufe des Reaktors einschalten", "use": "[E] Kühlkreislauf einschalten", "count": 3, "after": 20.0, "progress": "KÜHLUNG FÄHRT HOCH"},
			{"kind": "hack", "goal": "Die Notabschaltung am Leitpult einleiten", "use": "[E] Notabschaltung einleiten", "seconds": 45.0, "progress": "REAKTOR WIRD ABGESCHALTET", "radius": 13.0},
			{"kind": "hold", "goal": "Halten, bis der Reaktor heruntergefahren ist", "seconds": 50.0, "progress": "REAKTOR FÄHRT HERUNTER", "radius": 15.0}
		],
		"spots": {
			"goal": Vector3(6.0, 4.2, 3.4),
			"switches": [Vector3(3.0, 0, 28.0), Vector3(20.0, 4.2, 3.4), Vector3(28.0, 8.4, 29.0)]
		},
		"crowd": [["mauler", "mauler", "ripper", "striker", "charger", "leech"], 9, 8.5, [2, 4]],
		"posts": [["mauler", Vector3(24, 0, 26)], ["ripper", Vector3(4, 4.2, 14)], ["mauler", Vector3(20, 4.2, 4)], ["striker", Vector3(10, 8.4, 28)], ["mauler", Vector3(28, 8.4, 10)], ["mauler", Vector3(6, 0, 6)]],
		"strength": 7,
		"lines": {"enter": [], "event": ["talk:m2_locked"]},
		"caches": [["umlauf_kiste", "umlauf_s", SOUTH, 12.0, "kiste", "OBERER UMLAUF"], ["schacht_spind", "schacht", EAST, 12.0, "spind", "REAKTORSCHACHT"]],
		"station": ["schacht", SOUTH, [["bench", 8.0]]],
		"supply": [Vector3(23.0, 0, 31.3), Vector3(0, 0, -1)]
	}

func lay() -> void:
	room("schacht", 0.0, 0, 0, 32, 32, 13.0, "tech", {"look": {"lamp": "cage", "lamp_gap": 10.0, "energy": 3.4, "reach": 16.0, "light": Color("ffb36b")}})
	# --- the galleries: north and west at 4.2, south and east at 8.4
	gallery("umlauf_n", 4.2, Rect2(0, 0, 32, 8), [], [[SOUTH, 8.0, 8.9], [SOUTH, 11.1, 32.0]], [Vector2(14, 7.7), Vector2(24, 7.7), Vector2(31.7, 7.7)])
	gallery("umlauf_w", 4.2, Rect2(0, 8, 8, 16), [], [[EAST, 8.0, 24.0], [SOUTH, 0.0, 8.0]], [Vector2(7.7, 16), Vector2(7.7, 23.7)])
	gallery("umlauf_s", 8.4, Rect2(0, 24, 32, 8), [], [[NORTH, 0.0, 2.9], [NORTH, 5.1, 24.0]], [Vector2(12, 24.3), Vector2(20, 24.3)])
	gallery("umlauf_o", 8.4, Rect2(24, 0, 8, 24), [], [[WEST, 0.0, 24.0]], [Vector2(24.3, 12)])
	door("umlauf_n", "umlauf_w", 4.0, 8.0, {"kind": "join"})
	door("umlauf_o", "umlauf_s", 28.0, 8.0, {"kind": "join"})
	flight(Vector3(10, 0, 15.2), Vector3(10, 4.2, 8.0), Vector3(10, 0, 16.6), Vector3(10, 4.2, 6.0))
	flight(Vector3(4, 4.2, 16.8), Vector3(4, 8.4, 24.0), Vector3(4, 4.2, 15.4), Vector3(4, 8.4, 26.0))
	# The ways in and out at 8.4 go through the shaft's wall where they are used.
	for port: Dictionary in [piece.get("in", {}), piece.get("out", {})]:
		if not port.is_empty() and float(port.y) > 0.1:
			cut("schacht", int(port.side), float(port.at), AreaKit.PORT_WIDE + 0.6, float(port.y), float(port.y) + AreaKit.PORT_TALL + 0.35)
	# --- the core: glass and light through every level, and the pipes that cool it
	m._chunk("Kit", false)
	m._vessel(p(16, 0, 16), 3.2, 13.0, Color(1.0, 0.62, 0.3))
	for turn in range(4):
		var angle := TAU * turn / 4.0 + PI / 4.0
		var foot := p(16.0 + cos(angle) * 4.6, 0.0, 16.0 + sin(angle) * 4.6)
		m._pipe(foot, foot + Vector3(0, 13.0, 0), 0.22, Color("4a4f52"), 10, "steel")
	# The control desks: one on the lower gallery, one beside the floor's switch.
	block("plate", Vector3(6.0, 4.2 + 0.55, 1.2), Vector3(3.2, 1.1, 0.8), Color(0.2, 0.22, 0.24))
	glow(Vector3(6.0, 4.2 + 1.12, 1.2), Vector3(2.8, 0.03, 0.5), Color("7fd0ff"), 3.0)
	for spot in [Vector3(4.0, 3.0, 4.0), Vector3(20.0, 3.0, 4.0), Vector3(4.0, 3.0, 20.0)]:
		light(spot + Vector3(0, 4.2, 0), Color("ffcf8a"), 1.4, 9.0, 0.03)
	for spot in [Vector3(10.0, 3.0, 28.0), Vector3(28.0, 3.0, 10.0), Vector3(28.0, 3.0, 28.0)]:
		light(spot + Vector3(0, 8.4, 0), Color("ffcf8a"), 1.4, 9.0, 0.03)
	m._haze(p(16.0, 1.0, 16.0), Vector3(30.0, 2.0, 30.0), 0.035, Color(1.0, 0.82, 0.6))
	stencil("schacht", NORTH, 16.0, 11.0, "REAKTOR  R-2", 240, Color(0.5, 0.36, 0.16))
	stencil("schacht", SOUTH, 16.0, 6.4, "EBENE 0", 120, Color(0.5, 0.36, 0.16))
	# --- ways in: at every level
	hole("schacht", NORTH, 20.0, "pipes")
	hole("schacht", WEST, 6.0, "vent")
	duct("schacht", SOUTH, 4.0, {"sill": 2.6, "trunk": 4.0})
	drop("schacht", 16.0, 4.0, 1, {"land": 4.2, "shaft": 2.0})
	drop("schacht", 4.0, 12.0, 0, {"land": 4.2, "shaft": 2.0})
	drop("schacht", 16.0, 28.0, 2, {"land": 8.4, "shaft": 2.0})
	drop("schacht", 28.0, 16.0, 3, {"land": 8.4, "shaft": 2.0})
	drop("schacht", 22.0, 22.0, 0, {"shaft": 2.0})
	point("goal", Vector3(6.0, 4.2, 3.4))
	point("middle", Vector3(16.0, 0, 24.0))
