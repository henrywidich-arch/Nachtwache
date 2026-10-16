extends AreaKit
## Area: the cryo archive. GREYBOX.
##
## A cold hall of 36 x 44 metres, 9 high, full of mist: two blocks of cryo pods in rows
## (frosted cylinders that glow), lanes between them, and a catwalk at 4.2 along the west
## and east walls and across the north end, with a stair up at each side in the south.

## Where the pods stand: two rows in each of two blocks (local x), every POD_STEP from
## POD_FROM to POD_TO along z.
const ROWS := [9.5, 12.5, 23.5, 26.5]
const POD_FROM := 8.0
const POD_TO := 34.0
const POD_STEP := 2.2

func info() -> Dictionary:
	return {
		"id": "kryoarchiv", "kind": "area", "label": "KRYOARCHIV", "name": "Kryoarchiv (Kapseln, Laufstege)", "class": "mittel",
		"size": Vector2(36.0, 44.0), "levels": [0.0, 4.2], "mood": "cryo",
		"views": [["oben", Vector3(2, 8, 42), Vector3(24, 0, 14)], ["auge", Vector3(18, 1.62, 42), Vector3(18, 1, 8)], ["steg", Vector3(2, 5.82, 38), Vector3(30, 2, 6)]],
		"ports": [
			{"side": SOUTH, "at": 18.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": WEST, "at": 20.0, "y": 0.0, "room": "halle", "role": "in"},
			{"side": NORTH, "at": 18.0, "y": 0.0, "room": "halle", "role": "out"},
			{"side": EAST, "at": 24.0, "y": 0.0, "room": "halle", "role": "out"}
		],
		"events": [
			{"kind": "clear", "goal": "Die Kapselhalle säubern, bis die Sperre fällt"},
			{"kind": "collect", "goal": "Die Probenbehälter für die Freigabe einsammeln", "word": "Probenbehälter", "use": "[E] Behälter nehmen", "count": 3},
			{"kind": "hold", "goal": "Halten, bis die Kammern verriegelt sind", "seconds": 50.0, "progress": "KAMMERN VERRIEGELN", "radius": 14.0}
		],
		"spots": {
			"goal": Vector3(18.0, 0, 22.0),
			"items": [Vector3(6.0, 0, 30.0), Vector3(30.0, 0, 12.0), Vector3(18.0, 4.2, 2.0), Vector3(2.0, 4.2, 20.0), Vector3(34.0, 4.2, 30.0), Vector3(18.0, 0, 38.0)]
		},
		"crowd": [["mauler", "mauler", "ripper", "leech", "striker"], 9, 9.0, [2, 4]],
		"posts": [["mauler", Vector3(18, 0, 14)], ["mauler", Vector3(6, 0, 24)], ["ripper", Vector3(30, 0, 30)], ["mauler", Vector3(2, 4.2, 12)], ["leech", Vector3(18, 0, 30)], ["mauler", Vector3(34, 4.2, 18)], ["striker", Vector3(18, 4.2, 2)]],
		"strength": 7,
		"lines": {"enter": ["talk:m2_tanks"], "event": ["line:m2_n_tanks"]},
		"caches": [["steg_kiste", "steg_n", NORTH, 26.0, "kiste", "LAUFSTEG"], ["archiv_tresor", "halle", WEST, 34.0, "tresor", "KRYOARCHIV"]],
		"station": ["halle", SOUTH, [["rack", 8.0]]],
		"supply": [Vector3(28.0, 0, 43.3), Vector3(0, 0, -1)]
	}

func lay() -> void:
	room("halle", 0.0, 0, 0, 36, 44, 9.0, "lab", {"look": {"light": Color("a8d8ff"), "energy": 1.6, "stripe": Color("2f6fb0"), "panel": Color(0.78, 0.84, 0.88), "lamp_gap": 7.0, "lamp_every": 3}})
	# --- the catwalks
	gallery("steg_w", 4.2, Rect2(0, 4, 4, 36), [], [[EAST, 4.0, 36.9], [EAST, 39.1, 40.0]], [Vector2(3.7, 14), Vector2(3.7, 26), Vector2(3.7, 39.7)])
	gallery("steg_o", 4.2, Rect2(32, 4, 4, 36), [], [[WEST, 4.0, 36.9], [WEST, 39.1, 40.0]], [Vector2(32.3, 14), Vector2(32.3, 26), Vector2(32.3, 39.7)])
	gallery("steg_n", 4.2, Rect2(0, 0, 36, 4), [], [[SOUTH, 4.0, 32.0]], [Vector2(12, 3.7), Vector2(24, 3.7)])
	door("steg_n", "steg_w", 2.0, 4.0, {"kind": "join"})
	door("steg_n", "steg_o", 34.0, 4.0, {"kind": "join"})
	# Up at the south end: a flight out to each side catwalk.
	flight(Vector3(11.2, 0, 38.0), Vector3(4.0, 4.2, 38.0), Vector3(12.6, 0, 38.0), Vector3(2.0, 4.2, 38.0))
	flight(Vector3(24.8, 0, 38.0), Vector3(32.0, 4.2, 38.0), Vector3(23.4, 0, 38.0), Vector3(34.0, 4.2, 38.0))
	# --- the pods
	m._chunk("Kit", false)
	for x in ROWS:
		var z := POD_FROM
		while z <= POD_TO + 0.01:
			_pod(Vector3(float(x), 0.0, z))
			z += POD_STEP
	for x in [11.0, 25.0]:
		block("plate", Vector3(x, 0.02, (POD_FROM + POD_TO) * 0.5), Vector3(4.2, 0.04, POD_TO - POD_FROM + 1.6), Color(0.3, 0.33, 0.36), false)
		m._pipe(p(x, 3.6, POD_FROM - 0.8), p(x, 3.6, POD_TO + 0.8), 0.16, Color("6d8ea8"), 8, "steel")
	m._haze(p(18.0, 0.7, 22.0), Vector3(34.0, 1.4, 42.0), 0.09, Color(0.8, 0.9, 1.0))
	stencil("halle", NORTH, 18.0, 7.0, "KRYOARCHIV  K-1", 200, Color(0.25, 0.42, 0.55))
	for z in [12.0, 24.0, 36.0]:
		light(Vector3(18.0, 3.4, z), Color("bfe4ff"), 1.6, 10.0, 0.05)
	# --- ways in
	hole("halle", WEST, 10.0, "vent")
	hole("halle", EAST, 32.0, "breach")
	hole("halle", NORTH, 10.0, "pipes")
	# (Between the lamps of the ceiling.)
	drop("halle", 14.4, 14.7, 1, {"shaft": 2.0})
	drop("halle", 21.5, 29.2, 3, {"shaft": 2.0})
	drop("halle", 2.0, 22.0, 0, {"land": 4.2, "shaft": 2.0})
	drop("halle", 34.0, 14.0, 2, {"land": 4.2, "shaft": 2.0})
	point("goal", Vector3(18.0, 0, 22.0))
	point("middle", Vector3(18.0, 0, 22.0))

## A cryo pod: a frosted capsule on its base that glows from inside.
func _pod(at: Vector3) -> void:
	var base := p(at.x, at.y + 0.3, at.z)
	m.batch.cylinder(m.mats["steel"], base, 0.62, 0.62, 0.3, Color("39424a"), 12)
	m.batch.cylinder(m.mats["pane"], base + Vector3(0, 0.3, 0), 0.52, 0.52, 1.9, Color.WHITE, 12)
	m._glow_box(base + Vector3(0, 1.1, 0), Vector3(0.5, 1.5, 0.5), Color("9fd8ff"), 1.4)
	m.batch.cylinder(m.mats["steel"], base + Vector3(0, 2.2, 0), 0.62, 0.55, 0.3, Color("39424a"), 12)
	m._round_solid(base - Vector3(0, 0.3, 0), 0.62, 2.8)
