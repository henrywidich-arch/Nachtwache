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
		"size": Vector2(32.0, 32.0), "levels": [0.0, 4.2, 8.4], "mood": "reactor",
		"staff": ["hive_worker", "hive_worker", "zombie_soldier"],
		"views": [["bild", Vector3(19, 1.8, 31.2), Vector3(15, 4.5, 14)], ["oben", Vector3(2, 11.5, 30), Vector3(20, 0, 10)], ["auge_boden", Vector3(16, 1.62, 29), Vector3(16, 4, 16)], ["ebene_1", Vector3(4, 5.82, 20), Vector3(24, 4.2, 4)], ["ebene_2", Vector3(28, 10, 22), Vector3(4, 5, 8)]],
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
	room("schacht", 0.0, 0, 0, 32, 32, 13.0, "tech", {"look": {"lamp": "cage", "lamp_gap": 10.0, "lamp_every": 1, "energy": 1.1, "reach": 10.0, "light": Color("ffa060")}})
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
	_mood()
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

## The light and the air of the shaft (after the user's picture reaktor.jpeg): the hot
## orange core is the light of the room - it breathes and flutters and throws the shadows
## of its cage and of whoever passes it -, steam round its foot, the shaft around it in a
## deep warm dark, red DANGER signs over the galleries and cyan screens as the only cold.
func _mood() -> void:
	var hot := Color("ff8a3a")
	# The core: a glow inside the glass that breathes, bars before it that cast shadows.
	m._chunk("Kit", false)
	var plasma := frost(Color(1.0, 0.5, 0.18), 0.42, 1.5)
	m.batch.cylinder(plasma, p(16, 1.15, 16), 2.2, 2.2, 10.6, Color.WHITE, 20, Basis.IDENTITY, false)
	pulse_glow(plasma, 0.75, 1.25, 2.4)
	shadow_chunk("Glut")
	for k in range(16):
		var turn := TAU * (k + 0.5) / 16.0
		m._part("plate", p(16.0 + cos(turn) * 3.45, 6.45, 16.0 + sin(turn) * 3.45), Vector3(0.09, 10.7, 0.09), Color("1a1c1d"))
	for high in [3.0, 6.4, 9.8]:
		m.batch.cylinder(m.mats["steel"], p(16, high, 16), 3.52, 3.52, 0.14, Color("1a1c1d"), 20, Basis.IDENTITY, false)
	m._chunk("Kit", false)
	var core := m._light(p(16.0, 5.2, 16.0), hot, 9.0, 27.0, true, 0.0, 2.2, HiveCore.LAMP_FADE + 20.0)
	core.shadow_bias = 0.06
	pulse(core, 7.0, 11.0, 2.4, 0.18)
	var foot := light(Vector3(16.0, 0.9, 16.0), Color("ff7a2a"), 3.0, 12.0, 0.0, 2.6)
	pulse(foot, 2.2, 3.6, 2.4, 0.2)
	var crown := light(Vector3(16.0, 11.0, 16.0), hot, 3.5, 16.0, 0.0, 1.6)
	pulse(crown, 2.6, 4.2, 2.4, 0.15)
	# Steam round its foot, out of the gratings beside it, breathing with it.
	var cloud := mist(Vector3(16.0, 1.4, 16.0), Vector3(13.0, 2.8, 13.0), 0.2, Color(1.0, 0.9, 0.8), true, 0.7)
	var stuff := cloud.material as FogMaterial
	wave(func(phase: float) -> void: stuff.density = 0.14 + 0.1 * (0.5 + 0.5 * sin(phase)), 4.8)
	for turn in range(4):
		var angle := TAU * turn / 4.0
		var grate := Vector3(16.0 + cos(angle) * 5.2, 0.0, 16.0 + sin(angle) * 5.2)
		block("plate", grate + Vector3(0, 0.012, 0), Vector3(1.4, 0.02, 1.4), Color("17191a"), false)
		drift(grate + Vector3(0, 0.15, 0), Vector3(1.0, 0.2, 1.0), 26, Color(0.95, 0.88, 0.82), {"size": 1.0, "life": 5.0, "rise": 0.45, "spread": 0.3, "grow": 4.0, "alpha": 0.2})
	# The ring of warning paint round it on the floor.
	for edge in [-1.0, 1.0]:
		m._hazard(p(9.6, 0.012, 16.0 + edge * 6.4), p(22.4, 0.012, 16.0 + edge * 6.4), Vector3(0.4, 0.012, 0.3), 32)
		m._hazard(p(16.0 + edge * 6.4, 0.012, 9.75), p(16.0 + edge * 6.4, 0.012, 22.25), Vector3(0.3, 0.012, 0.4), 31)
	# Warning paint along the edges of the galleries.
	m._hazard(p(11.1, 4.212, 7.75), p(31.8, 4.212, 7.75), Vector3(0.5, 0.01, 0.12), 41)
	m._hazard(p(7.75, 4.212, 8.2), p(7.75, 4.212, 23.8), Vector3(0.12, 0.01, 0.5), 31)
	m._hazard(p(5.1, 8.412, 24.25), p(24.0, 8.412, 24.25), Vector3(0.5, 0.01, 0.12), 37)
	m._hazard(p(24.25, 8.412, 0.2), p(24.25, 8.412, 23.8), Vector3(0.12, 0.01, 0.5), 47)
	# Under the roof: ducts, fans and a crane beam, all in the dark.
	for x in [9.0, 25.5]:
		block("plate", Vector3(x, 12.4, 16.0), Vector3(2.0, 1.0, 31.4), Color("1e1f1f"), false)
	for spot in [Vector2(13.0, 26.0), Vector2(20.0, 6.0)]:
		m.batch.cylinder(m.mats["steel"], p(spot.x, 12.55, spot.y), 1.6, 1.6, 0.4, Color("161718"), 16)
		m.batch.cylinder(m.mats["plain"], p(spot.x, 12.5, spot.y), 1.3, 1.3, 0.06, Color("070707"), 16)
	block("plate", Vector3(16.0, 12.1, 9.5), Vector3(29.0, 0.6, 0.5), Color("8a6a1c"), false)
	for x in [2.0, 30.0]:
		m._pipe(p(x, 4.5, 0.4), p(x, 4.5, 31.6), 0.25, Color("3c3328"), 10, "steel")
	m._pipe(p(0.4, 9.6, 30.0), p(31.6, 9.6, 30.0), 0.3, Color("3c3328"), 10, "steel")
	# DANGER over the galleries: red, lit.
	var red := Color("ff2a1a")
	lit_sign("schacht", NORTH, 8.0, 6.6, "GEFAHR", red, 110, 2.6, 0.9)
	lit_sign("schacht", NORTH, 22.0, 6.6, "GEFAHR  ·  STRAHLUNG", red, 70, 3.4, 0.9)
	lit_sign("schacht", SOUTH, 24.0, 10.8, "GEFAHR", red, 110, 2.6, 0.9)
	lit_sign("schacht", EAST, 8.0, 10.8, "GEFAHR", red, 110, 2.6, 0.9)
	# The consoles: cyan screens, the only cold light, and the bright table by the way in.
	for spot in [Vector3(11.0, 0, 23.3), Vector3(21.0, 0, 23.3)]:
		block("plate", spot + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 0.7), Color("1d2124"))
		m._screen(Transform3D(Basis.IDENTITY, p(spot.x, 1.18, spot.z - 0.36)), Vector3.ZERO, Vector2(0.5, 0.32), 9, -1.0, 0.0, 180.0)
		m._screen(Transform3D(Basis.IDENTITY, p(spot.x - 0.5, 1.12, spot.z - 0.36)), Vector3.ZERO, Vector2(0.36, 0.24), 12, -1.0, 0.0, 180.0)
		light(spot + Vector3(0, 1.4, -0.9), Color("5fd8ff"), 0.9, 3.5, 0.0, 0.8)
	block("plate", Vector3(26.0, 0.55, 28.6), Vector3(1.8, 1.1, 1.1), Color("1b1e20"))
	glow(Vector3(26.0, 1.115, 28.6), Vector3(1.5, 0.02, 0.85), Color("bfefff"), 6.5)
	light(Vector3(26.0, 1.9, 28.6), Color("9fe6ff"), 1.4, 5.5, 0.0, 0.8)
	glow(Vector3(6.0, 4.2 + 1.13, 1.2), Vector3(2.8, 0.02, 0.5), Color("7fd0ff"), 5.0)
	light(Vector3(6.0, 5.8, 2.0), Color("5fd8ff"), 0.9, 4.0, 0.0, 0.8)
	# Cables over the floor to the core.
	for spot in [Vector3(11.0, 0, 22.8), Vector3(21.0, 0, 22.8), Vector3(26.0, 0, 27.9)]:
		cable(spot, Vector3(16.0 + (spot.x - 16.0) * 0.3, 0.0, 20.0), 0.7)
	cable(Vector3(9.0, 0.0, 9.0), Vector3(12.5, 0.0, 13.0), 0.5)
	cable(Vector3(24.0, 0.0, 10.0), Vector3(20.0, 0.0, 12.8), 0.5)
