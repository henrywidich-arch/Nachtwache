extends AreaKit
## Area: the isolation ward. GREYBOX.
##
## 40 x 40 metres: a ring corridor, 8 m high, around a tower in the middle - a guard room
## below, an observation room of glass on top of it (4.2) that looks over the whole ring,
## reached by a steel stair from the east side of the ring. Along the outer walls the
## cells, four to a side, each with a door and a barred window on the ring; in the middle
## of each side a passage instead of a cell, where the ward is entered and left.

const BAND := 6.0
const CELL_LONG := 5.6
const RING := 6.0

func info() -> Dictionary:
	return {
		"id": "isolationstrakt", "kind": "area", "label": "ISOLATIONSTRAKT", "name": "Isolationstrakt (Zellen, Turm)", "class": "mittel",
		"size": Vector2(40.0, 40.0), "levels": [0.0, 4.2], "mood": "cold",
		"staff": ["hive_nurse", "hive_security", "zombie_soldier"],
		"views": [["ring", Vector3(7, 7, 9), Vector3(33, 0, 9)], ["auge_turm", Vector3(20, 1.62, 33), Vector3(20, 2, 12)], ["kanzel", Vector3(20, 5.82, 26), Vector3(20, 4, 2)], ["zelle", Vector3(8.8, 1.62, 1.5), Vector3(8.8, 1.2, 9)]],
		"ports": [
			{"side": SOUTH, "at": 20.0, "y": 0.0, "room": "zugang_s", "role": "in"},
			{"side": WEST, "at": 20.0, "y": 0.0, "room": "zugang_w", "role": "in"},
			{"side": NORTH, "at": 20.0, "y": 0.0, "room": "zugang_n", "role": "out"},
			{"side": EAST, "at": 20.0, "y": 0.0, "room": "zugang_o", "role": "out"}
		],
		"events": [
			{"kind": "lockdown", "goal": "Das Isolationsprotokoll überstehen", "seconds": 50.0, "progress": "ISOLATIONSPROTOKOLL"},
			{"kind": "clear", "goal": "Den Trakt von den Ausgebrochenen säubern"},
			{"kind": "hack", "goal": "In der Kanzel die Türsteuerung überbrücken", "use": "[E] Türsteuerung überbrücken", "seconds": 45.0, "progress": "TÜRSTEUERUNG WIRD ÜBERBRÜCKT", "radius": 14.0}
		],
		"spots": {"goal": Vector3(20.0, 4.2, 14.4)},
		"crowd": [["mauler", "mauler", "striker", "ripper", "leech", "charger"], 9, 9.0, [2, 4]],
		"posts": [["mauler", Vector3(9, 0, 9)], ["mauler", Vector3(31, 0, 31)], ["striker", Vector3(20, 0, 31)], ["ripper", Vector3(9, 0, 22)], ["mauler", Vector3(14, 0, 2.5)], ["mauler", Vector3(37, 0, 26)], ["leech", Vector3(31, 0, 9)]],
		"strength": 7,
		"lines": {"enter": [], "event": []},
		"caches": [["zelle_spind", "zelle_n0", WEST, 3.0, "spind", "ZELLE N-1"], ["kanzel_tresor", "kanzel", WEST, 20.0, "tresor", "BEOBACHTUNGSKANZEL"]],
		"station": ["turm", WEST, [["bench", 20.0]]],
		"supply": [Vector3(27.3, 0, 20.0), Vector3(-1, 0, 0)]
	}

func lay() -> void:
	var look := {"look": {"stripe": Color("b8452f"), "light": Color("e6eef2"), "lamp_every": 2}}
	room("ring_n", 0.0, 6, 6, 28, 6, 8.0, "lab", look)
	room("ring_s", 0.0, 6, 28, 28, 6, 8.0, "lab", look)
	room("ring_w", 0.0, 6, 12, 6, 16, 8.0, "lab", look)
	room("ring_o", 0.0, 28, 12, 6, 16, 8.0, "lab", look)
	door("ring_n", "ring_w", 9.0, RING - 0.4, {"kind": "join"})
	door("ring_n", "ring_o", 31.0, RING - 0.4, {"kind": "join"})
	door("ring_s", "ring_w", 9.0, RING - 0.4, {"kind": "join"})
	door("ring_s", "ring_o", 31.0, RING - 0.4, {"kind": "join"})
	# --- the tower: the guard room, and the observation room of glass on top of it
	# (Its walls end under the floor of the observation room on top of it.)
	room("turm", 0.0, 12, 12, 16, 16, 3.9, "panel", {"ceiling": false, "look": {"stripe": Color("b8452f")}})
	door("ring_n", "turm", 20.0, 2.4, {"kind": "slide"})
	door("ring_s", "turm", 20.0, 2.4, {"kind": "slide"})
	room("kanzel", 4.2, 12, 12, 16, 16, 3.8, "lab", {"look": {"light": Color("d6e8ff"), "energy": 1.6}})
	for entry in [["ring_n", NORTH, SOUTH], ["ring_s", SOUTH, NORTH], ["ring_w", WEST, EAST], ["ring_o", EAST, WEST]]:
		for at in [16.0, 24.0]:
			if str(entry[0]) == "ring_o" and at == 16.0:
				continue
			pane("kanzel", int(entry[1]), at, 6.0, 0.9, 2.9, "glass")
			cut(str(entry[0]), int(entry[2]), at, 6.0, 4.2 + 0.9, 4.2 + 2.9)
	# The way up: a stair in the east side of the ring to a landing at the tower's door.
	gallery("steg", 4.2, Rect2(28, 14, 6, 4.8), [], [[SOUTH, 28.0, 29.9], [SOUTH, 32.1, 34.0], [NORTH, 28.0, 34.0]], [Vector2(33.6, 14.4)], Rect2(28.2, 14, 5.6, 4.8))
	door("kanzel", "steg", 16.4, 1.8, {"kind": "slide"})
	cut("ring_o", WEST, 16.4, 2.0, 4.2, 4.2 + HiveCore.DOOR_TALL + 0.1)
	flight(Vector3(31, 0, 26.0), Vector3(31, 4.2, 18.8), Vector3(31, 0, 27.2), Vector3(31, 4.2, 16.4))
	# --- the cells, and the passages in the middle of each side
	for side in [NORTH, SOUTH, WEST, EAST]:
		for i in range(5):
			var a := RING + CELL_LONG * i
			var rect := Rect2(a, 0, CELL_LONG, BAND)
			match side:
				SOUTH:
					rect = Rect2(a, 40.0 - BAND, CELL_LONG, BAND)
				WEST:
					rect = Rect2(0, a, BAND, CELL_LONG)
				EAST:
					rect = Rect2(40.0 - BAND, a, BAND, CELL_LONG)
			var tag: String = ["n", "o", "s", "w"][side]
			var name := "zugang_%s" % tag if i == 2 else "zelle_%s%d" % [tag, i if i < 2 else i - 1]
			room(name, 0.0, rect.position.x, rect.position.y, rect.size.x, rect.size.y, 3.4, "canteen", {"look": {"trim": Color("8f2a22"), "energy": 1.4 if i != 2 else 2.2, "dead": 0.3, "lamp_every": 1}})
			var ring := _ring_of(rect)
			if i == 2:
				door(name, ring, a + CELL_LONG * 0.5, AreaKit.PORT_WIDE, {"kind": "slide"})
				continue
			door(name, ring, a + 1.5, 1.3, {"kind": "frame" if (i + side) % 3 != 0 else "slide"})
			pane(name, HiveLayout.opposite(side), a + 3.9, 1.6, 1.0, 2.2, "window", ring)
			var middle := rect.get_center()
			m._bed(p(middle.x, 0, middle.y), 0.0 if side in [WEST, EAST] else PI / 2, Color("9fb4b8"))
	m._chunk("Kit", false)
	block("plate", Vector3(20.0, 4.2 + 0.55, 13.0), Vector3(4.0, 1.1, 0.8), Color(0.2, 0.22, 0.24))
	glow(Vector3(20.0, 4.2 + 1.12, 13.0), Vector3(3.6, 0.03, 0.5), Color("ff8a7a"), 3.0)
	m._desk(p(17.0, 0, 20.0), PI / 2, 3)
	stencil("ring_n", NORTH, 26.0, 5.5, "ISOLATION  I-4", 160, Color(0.5, 0.15, 0.12))
	stencil("ring_s", SOUTH, 14.0, 5.5, "ZUTRITT NUR STUFE 4", 90, Color(0.5, 0.15, 0.12))
	# --- ways in: from the ceilings of the ring, out of the cells' walls
	# (Between the lamps of the ring.)
	drop("ring_n", 15.4, 10.6, 1, {"shaft": 2.0})
	drop("ring_s", 15.4, 29.4, 3, {"shaft": 2.0})
	drop("ring_w", 10.6, 22.6, 0, {"shaft": 2.0})
	drop("ring_o", 28.9, 22.6, 2, {"shaft": 2.0})
	drop("kanzel", 24.0, 24.0, 0)
	hole("zelle_n0", NORTH, 10.0, "breach")
	hole("zelle_s1", SOUTH, 15.0, "vent")
	hole("zelle_w2", WEST, 27.0, "pipes")
	hole("zelle_o0", EAST, 9.0, "breach")
	point("goal", Vector3(20.0, 4.2, 14.4))
	point("middle", Vector3(20.0, 0, 9.0))

## The room of the ring a cell or passage opens on.
func _ring_of(rect: Rect2) -> String:
	var middle := rect.get_center()
	if middle.y < BAND:
		return "ring_n"
	if middle.y > 40.0 - BAND:
		return "ring_s"
	if middle.y < RING * 2.0:
		return "ring_n"
	if middle.y > 40.0 - RING * 2.0:
		return "ring_s"
	return "ring_w" if middle.x < 20.0 else "ring_o"
