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
## Who sleeps in the pods: his sleeper (assets/hive/user/cryo_sleeper.glb, 6,000 triangles),
## all of them drawn at once (one MultiMesh); this share of the pods is empty. How tall he
## stands in the glass, and how far he may be turned off upright (radians) or float.
const SLEEPER := "res://assets/hive/user/cryo_sleeper.glb"
const EMPTY := 0.3
const SLEEPER_TALL := 1.5
const SLEEPER_LEAN := 0.03
const SLEEPER_FLOAT := 0.08
## Seen through the frost he is a cold shape: his colours darkened and turned blue.
const SLEEPER_TINT := Color(0.16, 0.22, 0.28)

## Where the sleepers stand (filled by _pod, drawn by _sleepers).
var sleepers: Array[Transform3D] = []

func info() -> Dictionary:
	return {
		"id": "kryoarchiv", "kind": "area", "label": "KRYOARCHIV", "name": "Kryoarchiv (Kapseln, Laufstege)", "class": "mittel",
		"size": Vector2(36.0, 44.0), "levels": [0.0, 4.2], "mood": "cryo",
		"staff": ["hive_lab2", "hive_lab", "hive_nurse"],
		"views": [["bild", Vector3(18, 2.4, 43.0), Vector3(18, 2.4, 0)], ["oben", Vector3(2, 8, 42), Vector3(24, 0, 14)], ["auge", Vector3(18, 1.62, 42), Vector3(18, 1, 8)], ["steg", Vector3(2, 5.82, 38), Vector3(30, 2, 6)]],
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
	room("halle", 0.0, 0, 0, 36, 44, 9.0, "lab", {"lamps": "none", "look": {"stripe": Color("2f6fb0"), "panel": Color(0.62, 0.68, 0.74)}})
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
	var own := ResourceLoader.exists(SLEEPER)
	for x in ROWS:
		var z := POD_FROM
		while z <= POD_TO + 0.01:
			_pod(Vector3(float(x), 0.0, z), own)
			z += POD_STEP
	if own:
		_sleepers()
	for x in [11.0, 25.0]:
		block("plate", Vector3(x, 0.02, (POD_FROM + POD_TO) * 0.5), Vector3(4.2, 0.04, POD_TO - POD_FROM + 1.6), Color(0.2, 0.22, 0.25), false)
		m._pipe(p(x, 3.6, POD_FROM - 0.8), p(x, 3.6, POD_TO + 0.8), 0.16, Color("6d8ea8"), 8, "steel")
	stencil("halle", NORTH, 18.0, 7.0, "KRYOARCHIV  K-1", 200, Color(0.25, 0.42, 0.55))
	_mood()
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

## A cryo pod: a frosted capsule on its base that glows pale cyan from inside, with the
## dark shape of somebody in it, and a ring of light at its foot.
func _pod(at: Vector3, own: bool = false) -> void:
	var base := p(at.x, at.y + 0.3, at.z)
	m.batch.cylinder(m.mats["steel"], base - Vector3(0, 0.3, 0), 0.66, 0.62, 0.3, Color("2a3036"), 12)
	m.batch.cylinder(m.mats["steel"], base, 0.62, 0.62, 0.3, Color("39424a"), 12)
	m._glow_box(base + Vector3(0, 0.31, 0), Vector3(0.9, 0.025, 0.9), Color("8fe6ff"), 5.0)
	# Who sleeps in it: his sleeper, turned any way, a little off upright and afloat - or
	# nobody (EMPTY). Without his model: a shape against the frost.
	if own:
		if m.random.randf() >= EMPTY:
			var turn := Basis(Vector3.UP, m.random.randf() * TAU)
			var tilt := Basis(Vector3(m.random.randf_range(-1.0, 1.0), 0, m.random.randf_range(-1.0, 1.0)).normalized(), m.random.randf_range(0.0, SLEEPER_LEAN))
			var lift := m.random.randf_range(0.02, SLEEPER_FLOAT)
			sleepers.append(Transform3D(tilt * turn, base + Vector3(0, 0.3 + lift, 0)))
	else:
		var dark := Color("0b1418")
		var lean := m.random.randf_range(-0.12, 0.12)
		var turn := Basis(Vector3.UP, m.random.randf() * TAU)
		m.batch.box(m.mats["plain"], base + Vector3(0, 1.32, 0), Vector3(0.36, 0.62, 0.2), dark, turn * Basis(Vector3.FORWARD, lean))
		m.batch.ellipsoid(m.mats["plain"], base + Vector3(lean * -0.6, 1.8, 0), Vector3(0.11, 0.14, 0.12), dark, Basis.IDENTITY, 8, 5)
		m.batch.box(m.mats["plain"], base + Vector3(0, 0.72, 0), Vector3(0.3, 0.62, 0.16), dark, turn)
	m.batch.cylinder(frost(Color(0.5, 0.85, 1.0), 0.4, 1.7), base + Vector3(0, 0.3, 0), 0.5, 0.5, 1.9, Color.WHITE, 14, Basis.IDENTITY, false)
	m.batch.cylinder(m.mats["pane"], base + Vector3(0, 0.3, 0), 0.53, 0.53, 1.9, Color.WHITE, 14, Basis.IDENTITY, false)
	m.batch.cylinder(m.mats["steel"], base + Vector3(0, 2.2, 0), 0.62, 0.55, 0.3, Color("39424a"), 12)
	m.batch.cylinder(m.mats["steel"], base + Vector3(0, 2.5, 0), 0.3, 0.22, 0.25, Color("2a3036"), 8)
	m._round_solid(base - Vector3(0, 0.3, 0), 0.62, 2.8)

## All the sleepers at once: one MultiMesh of his model, its colours cold and dark behind
## the frost. (No shadows: the pods glow from inside, and the glass would catch them.)
func _sleepers() -> void:
	if sleepers.is_empty():
		return
	var scene := load(SLEEPER) as PackedScene
	var probe := scene.instantiate()
	var found := probe.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		probe.free()
		return
	var body := found[0] as MeshInstance3D
	var mesh := body.mesh
	var skin := mesh.surface_get_material(0) as BaseMaterial3D
	probe.free()
	var bounds := mesh.get_aabb()
	var fit := SLEEPER_TALL / maxf(0.01, bounds.size.y)
	var foot := Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * fit
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = mesh
	many.instance_count = sleepers.size()
	for i in range(sleepers.size()):
		var place: Transform3D = sleepers[i]
		many.set_instance_transform(i, Transform3D(place.basis.scaled(Vector3.ONE * fit), place.origin + place.basis * foot))
	var all := MultiMeshInstance3D.new()
	all.name = "Sleepers"
	all.multimesh = many
	all.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	all.visibility_range_end = 60.0
	if skin != null:
		var cold := skin.duplicate() as BaseMaterial3D
		cold.albedo_color = SLEEPER_TINT
		cold.roughness = 0.9
		all.material_override = cold
	m.add_child(all)

## The light and the air of the archive (after the user's picture kryo.jpeg): rows of cold
## strip lights under trusses, pods glowing from inside, cold mist creeping from their
## feet over a wet dark floor, the catwalks in shadow with small red and green lamps.
func _mood() -> void:
	m._chunk("Kit", false)
	var cold := Color("cfe8ff")
	# Trusses across the hall under the roof, clear of the shafts of the ways in.
	for z in [5.0, 11.0, 18.0, 25.5, 33.0, 39.5]:
		truss(Vector3(0.3, 8.85, z), Vector3(35.7, 8.85, z), 0.7)
	# Rows of strip lights along the hall; every second one throws a cone.
	var k := 0
	for x in [6.0, 16.0, 20.0, 30.0]:
		var z := 5.6
		while z < 40.0:
			strip(Vector3(x, 8.05, z), 2.4, false, cold, 6.5)
			m._pipe(p(x, 8.1, z - 1.0), p(x, 8.85, z - 1.0), 0.012, Color("15181a"), 4, "plain")
			m._pipe(p(x, 8.1, z + 1.0), p(x, 8.85, z + 1.0), 0.012, Color("15181a"), 4, "plain")
			if k % 2 == 0:
				cone(Vector3(x, 7.95, z), Vector3.DOWN, cold, 5.5, 15.0, 70.0, 2.0)
				light(Vector3(x, 7.4, z), cold, 0.7, 6.0, 0.0, 0.0)
			k += 1
			z += 4.4
	# Light strips along the walls under the catwalks, and the glow over the north door.
	for side in [WEST, EAST]:
		wall_glow(side, 6.0, 38.0, 2.7, Color("9fe0ff"), 3.4)
	glow(Vector3(18.0, 6.3, 0.25), Vector3(9.0, 0.05, 0.04), Color("9fe0ff"), 3.0)
	glow(Vector3(18.0, 4.9, 0.3), Vector3(0.5, 0.18, 0.06), Color("ff2a1e"), 6.0)
	light(Vector3(18.0, 4.6, 1.0), Color("ff3a2a"), 0.8, 4.0, 0.0, 0.8)
	# The pods: a low light at every third along each row, toward its lane, lights the mist.
	for x in ROWS:
		var toward := 1.0 if x == 12.5 or x == 26.5 else -1.0
		var z := POD_FROM + POD_STEP
		while z <= POD_TO:
			light(Vector3(float(x) + toward * 1.1, 0.7, z), Color("8fdcff"), 1.1, 5.0, 0.04, 2.6)
			z += POD_STEP * 3.0
	# Cold mist from their feet, and the vapour that drifts off it.
	for x in [11.0, 25.0]:
		mist(Vector3(x, 0.6, 21.0), Vector3(8.0, 1.3, 30.0), 0.55, Color(0.8, 0.92, 1.0), false, 0.6)
		drift(Vector3(x, 0.25, 21.0), Vector3(6.5, 0.3, 27.0), 70, Color(0.75, 0.88, 1.0), {"size": 1.3, "life": 7.0, "rise": 0.03, "spread": 0.3, "grow": 2.4, "alpha": 0.32})
	mist(Vector3(18.0, 0.35, 22.0), Vector3(34.0, 0.7, 42.0), 0.06, Color(0.8, 0.9, 1.0), false, 0.5)
	# A wet dark floor that mirrors the pods and the lamps; white lines along the lane.
	wet_floor(Rect2(0.2, 0.2, 35.6, 43.6), 0.0, Color(0.2, 0.22, 0.25))
	for x in [14.6, 21.4]:
		var z := 6.0
		while z < 38.0:
			m._stripe(p(x, 0.014, z), p(x, 0.014, z + 1.6), 0.14, Color(0.55, 0.58, 0.6))
			z += 3.2
	# The catwalks stay in shadow: only small panels with red and green lamps on the walls.
	for z in [9.0, 17.0, 27.0, 35.0]:
		panel(Vector3(0.3, 5.6, z), Vector3.RIGHT, 2 + int(z) % 5)
		panel(Vector3(35.7, 5.6, z + 2.0), Vector3.LEFT, 1 + int(z) % 6)
		light(Vector3(0.9, 5.6, z), Color("ff4a3a"), 0.35, 2.6, 0.0, 0.5)
		light(Vector3(35.1, 5.6, z + 2.0), Color("5aff8a"), 0.3, 2.6, 0.0, 0.5)
	for x in [8.0, 28.0]:
		panel(Vector3(x, 5.6, 0.3), Vector3.BACK, 4)
	# A little cold light along the walls over the catwalks, so their railings read.
	for z in [10.0, 22.0, 34.0]:
		strip(Vector3(1.2, 8.3, z), 2.0, false, cold, 4.0)
		strip(Vector3(34.8, 8.3, z), 2.0, false, cold, 4.0)
		light(Vector3(1.4, 7.6, z), cold, 1.0, 8.0, 0.0, 0.3)
		light(Vector3(34.6, 7.6, z), cold, 1.0, 8.0, 0.0, 0.3)
	# Chains from the roof over the lanes, cables over the floor from the pods.
	for spot in [Vector3(16.6, 8.2, 9.0), Vector3(19.4, 8.2, 16.4), Vector3(17.2, 8.2, 27.0), Vector3(7.5, 8.2, 20.0), Vector3(28.8, 8.2, 31.0)]:
		chain(spot, m.random.randf_range(3.0, 4.6))
	for x in [12.5, 23.5]:
		var lane := 14.2 if x == 12.5 else 21.8
		var z := POD_FROM + 1.1
		while z < POD_TO:
			if m.random.randf() < 0.6:
				cable(Vector3(x + (0.6 if x == 12.5 else -0.6), 0.0, z), Vector3(lane, 0.0, z + m.random.randf_range(2.0, 6.0)), 0.4)
			z += POD_STEP
	for z in [12.0, 22.0, 30.0]:
		cable(Vector3(14.4, 0.0, z), Vector3(17.0, 0.0, z + 5.0), 0.8)
		cable(Vector3(21.6, 0.0, z + 1.0), Vector3(19.2, 0.0, z + 6.5), 0.8)
