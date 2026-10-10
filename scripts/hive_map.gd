class_name HiveMap
extends HiveCore
## The map of the second mission. A villa in a walled park, where the helicopter sets the
## squad down; behind a mirror in its dining room a concrete stairwell leads down to a
## hidden railway station; a train runs from there to the terminal of a research facility
## deep under the ground - offices, a canteen, a central hall, laboratories, the plant
## rooms, a containment hall. (HiveCore has the machinery, HiveDirector runs the mission.)
##
## North is -z. The park and the villa lie around the origin on the floor `ground`, the
## station under them on `under`; the facility, 260 m further north, has the floors `deep`
## and `deck` (its galleries). Rooms are declared and furnished zone by zone; _compile
## then builds them.

## Walking height of the station and of the facility, and of the facility's galleries.
const UNDER := -9.6
const DECK := -5.4
## Height of the villa's rooms and of its eaves.
const STOREY_VILLA := 4.4
const EAVES := 9.6
const OCHRE := Color(0.82, 0.63, 0.36)
const TRIM := Color(0.9, 0.87, 0.8)
## How far the train travels: the terminal's car stands this far north of the station's.
const RIDE := Vector3(0, 0, -260)

var ground := 0
var upper := 0
var under := 0
var deep := 0
var deck := 0
## What passes the windows of the car while the train runs (see ride).
var ride_lamps: Array[MeshInstance3D] = []
var riding := false
var ride_speed := 0.0
var ride_way := 0.0
## What draws the plan of the Hive for the displays (a HiveDisplay).
const PLAN_SCRIPT := preload("res://scripts/hive_display.gd")
var plan: Node
## What drips and what sparks share their looks.
var drip_look: StandardMaterial3D
var drip_mesh: QuadMesh
var spark_look: StandardMaterial3D
var spark_mesh: QuadMesh
var spark_fade: GradientTexture1D
## The red light of the lockdown in the canteen (see set_alarm).
var alarm_node: Node3D
var alarm_lamps: Array[OmniLight3D] = []
var alarm_on := false
## Keeps the red light on whatever happens (the pictures of a check: --hive-alarm).
var alarm_hold := false
## How far each of the house's props has to be turned so that its front looks along +z.
const PROP_TURN := {}

func _ready() -> void:
	var began := Time.get_ticks_msec()
	_begin_build()
	_build_environment()
	_build_styles()
	ground = _floor("ground", "", 0.0, Rect2(-72, -34, 144, 130))
	upper = _floor("gallery", "GALERIE", STOREY_VILLA, Rect2(-8, 7, 16, 16))
	under = _floor("station", "BAHNHOF", UNDER, Rect2(-66, -76, 132, 52))
	deep = _floor("facility", "ANLAGE", UNDER, Rect2(-60, -626, 132, 322))
	deck = _floor("deck", "GALERIE", DECK, Rect2(-60, -626, 132, 322))
	areas = ["descent", "station", "nadja", "admin", "cafe", "atrium", "decon", "research", "hall"]
	var shop_sign := Label3D.new()
	shop_sign.name = "WeaponShopLabel"
	add_child(shop_sign)
	plan = PLAN_SCRIPT.new()
	add_child(plan)
	build_times["setup"] = Time.get_ticks_msec() - began
	for part in [_lay_grounds, _lay_villa, _lay_descent, _lay_station, _lay_terminal, _lay_admin, _lay_canteen, _lay_atrium, _lay_research]:
		var from := Time.get_ticks_msec()
		(part as Callable).call()
		build_times[str((part as Callable).get_method())] = Time.get_ticks_msec() - from
	var mark := Time.get_ticks_msec()
	_compile()
	build_times["compile"] = Time.get_ticks_msec() - mark
	mark = Time.get_ticks_msec()
	_commit()
	build_times["commit"] = Time.get_ticks_msec() - mark
	_after_build()
	build_times["all"] = Time.get_ticks_msec() - began

func _build_styles() -> void:
	var plaster := Color(0.84, 0.81, 0.74)
	styles = {
		"none": {"family": "villa", "dress": "", "floor": ["plain", Color.WHITE], "ceiling": ["plain", Color.WHITE], "core": ["plain", Color.WHITE], "lamp": "none"},
		"hall": {
			"family": "villa", "dress": "hall", "floor": ["checker", Color(0.92, 0.92, 0.9)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.88, 0.85, 0.77)],
			"lamp": "chandelier", "lamp_gap": 14.0, "lamp_model": "Chandelier_03", "lamp_size": 2.4, "lamp_drop": 1.4, "light": Color("ffd7a3"), "energy": 3.4, "reach": 17.0
		},
		"wood": {
			"family": "villa", "dress": "wood", "floor": ["parquet", Color(0.82, 0.76, 0.7)], "ceiling": ["plaster", plaster], "core": ["wallpaper", Color(0.66, 0.28, 0.23)], "wood": Color(0.82, 0.74, 0.66),
			"lamp": "chandelier", "lamp_gap": 12.0, "lamp_size": 1.3, "lamp_drop": 0.5, "light": Color("ffcd96"), "energy": 3.6, "reach": 15.0
		},
		"scullery": {
			"family": "villa", "dress": "tiles", "floor": ["tiles", Color(0.62, 0.62, 0.6)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.8, 0.78, 0.72)],
			"lamp": "cage", "lamp_gap": 6.0, "light": Color("ffe2b8"), "energy": 1.7, "reach": 9.0
		},
		"concrete": {
			"family": "bunker", "dress": "concrete", "floor": ["betonfloor", Color(0.72, 0.72, 0.72)], "ceiling": ["beton", Color(0.58, 0.58, 0.58)], "core": ["formwork", Color(0.76, 0.76, 0.74)],
			"lamp": "cage", "lamp_gap": 5.5, "light": Color("ffe7c0"), "energy": 2.1, "reach": 9.5
		},
		# The facility: cream panels in dark steel over a dark lower row, a polished dark floor
		# that the lamps stand in. (Of the tubes of a room only every second one is a light.)
		"panel": {
			"family": "tech", "dress": "panel", "floor": ["gloss", Color(0.62, 0.64, 0.68)], "ceiling": ["plate", Color("25282b")], "core": ["plate", Color("1f2326")], "panel": Color(0.82, 0.8, 0.74),
			"lamp": "tube", "lamp_gap": 4.8, "lamp_every": 2, "light": Color("d6e8ff"), "energy": 2.6, "reach": 10.5
		},
		"office": {
			"family": "tech", "dress": "panel", "floor": ["darkfloor", Color(0.46, 0.52, 0.64)], "ceiling": ["cladding", Color(0.44, 0.46, 0.47)], "core": ["plate", Color("23272a")], "panel": Color(0.8, 0.79, 0.74), "wainscot": Color(0.3, 0.33, 0.37), "strip": false,
			"lamp": "tube", "lamp_gap": 4.8, "lamp_every": 2, "light": Color("e6ecf2"), "energy": 2.5, "reach": 10.5
		},
		"lab": {
			"family": "tech", "dress": "panel", "floor": ["gloss", Color(0.66, 0.72, 0.72)], "ceiling": ["cladding", Color(0.42, 0.45, 0.47)], "core": ["plate", Color("1f2326")], "panel": Color(0.84, 0.88, 0.86), "wainscot": Color(0.22, 0.3, 0.3), "stripe": Color("2f8f8a"), "strip_color": Color("9fe8e0"),
			"lamp": "tube", "lamp_gap": 4.8, "lamp_every": 2, "light": Color("d6f5e6"), "energy": 2.5, "reach": 10.5
		},
		"canteen": {
			"family": "tech", "dress": "tiles", "floor": ["tiles", Color(0.7, 0.72, 0.72)], "ceiling": ["cladding", Color(0.4, 0.42, 0.43)], "core": ["cladding", Color(0.72, 0.74, 0.74)], "tile": Color(0.9, 0.92, 0.9),
			"lamp": "tube", "lamp_gap": 5.0, "lamp_every": 3, "light": Color("eaf0f2"), "energy": 3.0, "reach": 13.0
		},
		"tech": {
			"family": "bunker", "dress": "tech", "floor": ["darkfloor", Color(0.56, 0.56, 0.56)], "ceiling": ["beton", Color(0.36, 0.36, 0.36)], "core": ["beton", Color(0.5, 0.5, 0.5)],
			"lamp": "cage", "lamp_gap": 5.5, "light": Color("ffb36b"), "energy": 3.0, "reach": 11.0
		},
		"station": {
			"family": "bunker", "dress": "concrete", "floor": ["betonfloor", Color(0.7, 0.7, 0.7)], "ceiling": ["beton", Color(0.46, 0.46, 0.46)], "core": ["formwork", Color(0.74, 0.74, 0.72)], "stripe": Color("b8961e"),
			"lamp": "hang", "lamp_gap": 9.0, "lamp_every": 2, "lamp_height": 5.6, "light": Color("ffbf70"), "energy": 2.3, "reach": 16.0
		},
		"bighall": {
			"family": "tech", "dress": "panel", "floor": ["gloss", Color(0.56, 0.58, 0.62)], "ceiling": ["plate", Color("202326")], "core": ["plate", Color("1f2326")], "panel": Color(0.8, 0.79, 0.74),
			"lamp": "hang", "lamp_gap": 10.0, "lamp_every": 2, "lamp_height": 6.4, "light": Color("dfeaff"), "energy": 2.3, "reach": 18.0
		},
		"car": {"family": "tech", "dress": "", "floor": ["tread", Color.WHITE], "ceiling": ["plate", Color.WHITE], "core": ["plate", Color.WHITE], "lamp": "none"}
	}

func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(extra, true)
	return out

# ---------------------------------------------------------------- pieces of the kit

## Yaw of a model (their fronts look along +z) that stands with its back to a side.
func _model_yaw(side: int) -> float:
	return _face_yaw(side) + PI

## A model with its back against a side of a room, `a` along that wall. `gap` is the
## room left behind it.
func _against(room_id: String, side: int, a: float, id: String, options: Dictionary = {}, gap: float = 0.04) -> Node3D:
	var room: Dictionary = room_of[room_id]
	var entry := _model_entry(id)
	var bounds: AABB = entry.bounds
	var factor := float(options.get("scale", 1.0))
	if options.has("height"):
		factor = float(options.height) / maxf(0.001, bounds.size.y)
	elif options.has("width"):
		factor = float(options.width) / maxf(0.001, maxf(bounds.size.x, bounds.size.z))
	var deep_half := bounds.size.z * factor * 0.5
	return _model(id, _face_point(room, side, a, 0.0, -(deep_half + gap)), _model_yaw(side), options)

## A picture in its frame on a wall of a room: `wide` metres, its middle `high` above the floor.
func _painting(room_id: String, side: int, a: float, wide: float = 1.3, high: float = 2.1, id: String = "fancy_picture_frame_01") -> void:
	var room: Dictionary = room_of[room_id]
	var size := _model_size(id)
	var tall := wide * size.y / maxf(0.001, size.x)
	_model(id, _face_point(room, side, a, high - tall * 0.5, -0.045), _model_yaw(side), {"width": wide, "solid": false, "far": 40.0})

## A stone plinth with something on it (a bust, a vase, a statue).
func _plinth(pos: Vector3, tall: float, id: String, model_tall: float, yaw: float = 0.0, wide: float = 0.5) -> void:
	_part("marble", pos + Vector3(0, tall * 0.5, 0), Vector3(wide, tall, wide), Color(0.8, 0.79, 0.76))
	_part("marble", pos + Vector3(0, 0.04, 0), Vector3(wide + 0.12, 0.08, wide + 0.12), Color(0.7, 0.69, 0.66))
	_part("marble", pos + Vector3(0, tall - 0.025, 0), Vector3(wide + 0.08, 0.07, wide + 0.08), Color(0.74, 0.73, 0.7))
	_solid(pos + Vector3(0, tall * 0.5, 0), Vector3(wide, tall, wide))
	if id != "":
		_model(id, pos + Vector3(0, tall, 0), yaw, {"height": model_tall, "solid": false})

## A carpet: cloth on the floor of a room, nothing to stumble over.
func _carpet(centre: Vector3, size: Vector2, color: Color) -> void:
	_part("velvet", centre + Vector3(0, 0.008, 0), Vector3(size.x, 0.016, size.y), color)
	_part("velvet", centre + Vector3(0, 0.006, 0), Vector3(size.x + 0.16, 0.012, size.y + 0.16), color.darkened(0.45))

## Bookcases along a side of a room from `a` to `b`, full of books.
func _bookcase(room_id: String, side: int, a: float, b: float, tall: float = 2.9) -> void:
	var room: Dictionary = room_of[room_id]
	var wood := Color(0.3, 0.23, 0.18)
	var count := maxi(1, roundi((b - a) / 1.4))
	var wide := (b - a) / count
	var spines := [Color("5a1f1c"), Color("23382c"), Color("2a2f4a"), Color("6a5a34"), Color("3d2a1c"), Color("1e1e20"), Color("6d4a2a")]
	for i in range(count):
		var from := a + i * wide
		var to := from + wide
		_face_box(room, side, "panelwood", from, to, 0.0, tall, -0.42, -0.36, wood.darkened(0.2))
		_face_box(room, side, "panelwood", from, from + 0.05, 0.0, tall, -0.36, 0.0, wood)
		_face_box(room, side, "panelwood", to - 0.05, to, 0.0, tall, -0.36, 0.0, wood)
		_face_box(room, side, "panelwood", from, to, tall - 0.07, tall + 0.05, -0.44, 0.0, wood)
		var shelves := 6
		for row in range(shelves):
			var y := 0.12 + row * (tall - 0.2) / shelves
			_face_box(room, side, "panelwood", from, to, y - 0.04, y, -0.36, 0.0, wood)
			var at := from + 0.07
			while at < to - 0.14:
				var thick := random.randf_range(0.05, 0.2)
				if at + thick > to - 0.07:
					break
				if random.randf() < 0.9:
					var high := random.randf_range(0.24, 0.36)
					_face_box(room, side, "plain", at, at + thick - 0.008, y, y + high, -0.33 + random.randf_range(0.0, 0.05), -0.08, _vary(spines[random.randi() % spines.size()], 0.03))
				at += thick
	var centre := _face_centre(room, side, a, b, 0.0, tall, -0.44, 0.0)
	_solid(centre, _face_size(side, a, b, 0.0, tall, -0.44, 0.0))

## A counter with a top along a side of a room.
func _counter(room_id: String, side: int, a: float, b: float, base: Color, top: Color, deep_m: float = 0.65) -> void:
	var room: Dictionary = room_of[room_id]
	_face_box(room, side, "panelwood", a, b, 0.0, 0.86, -deep_m + 0.04, 0.0, base)
	_face_box(room, side, "marble", a - 0.02, b + 0.02, 0.86, 0.92, -deep_m, 0.0, top)
	var count := maxi(1, roundi((b - a) / 0.7))
	for i in range(count):
		_face_box(room, side, "plain", a + (i + 0.5) * (b - a) / count - 0.06, a + (i + 0.5) * (b - a) / count + 0.06, 0.6, 0.63, -deep_m + 0.02, -deep_m + 0.04, Color("8a8478"))
	_solid(_face_centre(room, side, a, b, 0.0, 0.92, -deep_m, 0.0), _face_size(side, a, b, 0.0, 0.92, -deep_m, 0.0))

## A fireplace on a side of a room, with embers that glow.
func _fireplace(room_id: String, side: int, a: float) -> void:
	var room: Dictionary = room_of[room_id]
	var stone := Color(0.78, 0.76, 0.72)
	_face_box(room, side, "marble", a - 1.25, a - 0.75, 0.0, 1.5, -0.42, 0.0, stone)
	_face_box(room, side, "marble", a + 0.75, a + 1.25, 0.0, 1.5, -0.42, 0.0, stone)
	_face_box(room, side, "marble", a - 1.4, a + 1.4, 1.5, 1.72, -0.5, 0.0, stone)
	_face_box(room, side, "plain", a - 0.75, a + 0.75, 0.0, 1.5, -0.12, 0.0, Color("0b0a09"))
	_face_box(room, side, "marble", a - 1.3, a + 1.3, 1.72, float(room.height) - 0.25, -0.2, 0.0, Color(0.84, 0.81, 0.74))
	_face_glow(room, side, a - 0.4, a + 0.4, 0.05, 0.16, -0.3, -0.14, Color("ff7a2a"), 3.2)
	_face_box(room, side, "plain", a - 0.55, a + 0.55, 0.0, 0.1, -0.36, -0.12, Color("17120e"))
	var ember := _light(_face_point(room, side, a, 0.5, -0.7), Color("ff8a3c"), 1.5, 5.5, false, 0.35, 0.6, LAMP_FADE)
	ember.omni_attenuation = 1.6
	_solid(_face_centre(room, side, a - 1.4, a + 1.4, 0.0, 1.72, -0.5, 0.0), _face_size(side, a - 1.4, a + 1.4, 0.0, 1.72, -0.5, 0.0))
	_model("mantel_clock_01", _face_point(room, side, a, 1.72, -0.25), _model_yaw(side), {"height": 0.3, "solid": false, "far": 30.0})

## A door of the facility that stays shut (the user's model: two wings in a frame), with
## its back against a side of a room, and a red lamp over it. False if the model is not
## there.
func _sealed_door(room_id: String, side: int, a: float) -> bool:
	if not ResourceLoader.exists("res://assets/hive/user/door.glb"):
		return false
	var room: Dictionary = room_of[room_id]
	_against(room_id, side, a, "hive/user/door.glb", {"far": 60.0}, 0.0)
	_face_glow(room, side, a - 0.2, a + 0.2, 2.34, 2.4, -0.33, -0.3, Color("ff3a2a"), 3.0)
	return true

## A hedge over a rectangle of the park.
func _hedge(plan: Rect2, tall: float = 1.25) -> void:
	var centre := Vector3(plan.get_center().x, tall * 0.5, plan.get_center().y)
	_part("lawn", centre, Vector3(plan.size.x, tall, plan.size.y), Color(0.2, 0.3, 0.19))
	_solid(centre, Vector3(plan.size.x, tall, plan.size.y))

## A lantern on an iron post.
func _park_lamp(pos: Vector3, energy: float = 2.6) -> void:
	batch.cylinder(mats["metal"], pos, 0.09, 0.06, 3.5, Color("15171a"), 8)
	batch.cylinder(mats["metal"], pos, 0.18, 0.12, 0.4, Color("15171a"), 8)
	_part("metal", pos + Vector3(0, 3.92, 0), Vector3(0.44, 0.06, 0.44), Color("15171a"))
	_glow_box(pos + Vector3(0, 3.7, 0), Vector3(0.28, 0.38, 0.28), Color("ffd08a"), 5.0)
	_light(pos + Vector3(0, 3.6, 0), Color("ffc884"), energy, 14.0, false, 0.04, 1.4, 90.0)
	_round_solid(pos, 0.14, 3.6)

## A stretch of the park's wall along x or z, with `gaps` ([from, to] along it) left open.
func _park_wall(from: Vector2, to: Vector2, gaps: Array = []) -> void:
	var along_x := absf(to.x - from.x) > absf(to.y - from.y)
	var start := from.x if along_x else from.y
	var finish := to.x if along_x else to.y
	var fixed := from.y if along_x else from.x
	var edges: Array = [start]
	for gap in gaps:
		edges.append(float(gap[0]))
		edges.append(float(gap[1]))
	edges.append(finish)
	for i in range(0, edges.size(), 2):
		var a := float(edges[i])
		var b := float(edges[i + 1])
		if b - a < 0.2:
			continue
		var mid := (a + b) * 0.5
		var centre := Vector3(mid, 1.6, fixed) if along_x else Vector3(fixed, 1.6, mid)
		var size := Vector3(b - a, 3.2, 0.6) if along_x else Vector3(0.6, 3.2, b - a)
		_part("stonewall", centre, size, Color(0.62, 0.62, 0.6))
		_part("stonewall", centre + Vector3(0, 1.68, 0), size * Vector3(1, 0, 1) + Vector3(0.16, 0.16, 0.16), Color(0.5, 0.5, 0.48))
		_solid(centre, size)
	# Where the wall has come down: rubble that is in nobody's way.
	for gap in gaps:
		if bool(gap[2]) if gap.size() > 2 else true:
			var mid := (float(gap[0]) + float(gap[1])) * 0.5
			for k in range(7):
				var off := random.randf_range(-2.4, 2.4)
				var out := random.randf_range(-1.6, 1.6)
				var spot := Vector3(mid + off, 0.12, fixed + out) if along_x else Vector3(fixed + out, 0.12, mid + off)
				_part("stonewall", spot, Vector3(random.randf_range(0.4, 0.9), random.randf_range(0.2, 0.4), random.randf_range(0.4, 0.8)), _vary(Color(0.55, 0.55, 0.53), 0.04), Vector3(random.randf_range(-12, 12), random.randf_range(0, 180), random.randf_range(-12, 12)))
			# The broken ends of the wall beside it (they reach a little into the standing wall),
			# and slabs of it that lie in the grass.
			for end in [[float(gap[0]), 1.0], [float(gap[1]), -1.0]]:
				var at := float(end[0]) + float(end[1]) * 0.26
				var tall := random.randf_range(1.2, 2.1)
				var stub := Vector3(at, tall * 0.5, fixed) if along_x else Vector3(fixed, tall * 0.5, at)
				var stub_size := Vector3(0.72, tall, 0.58) if along_x else Vector3(0.58, tall, 0.72)
				_part("stonewall", stub, stub_size, Color(0.56, 0.56, 0.54))
				_solid(stub, stub_size)
				var out := random.randf_range(1.0, 1.5) * (1.0 if random.randf() < 0.5 else -1.0)
				var lying := float(end[0]) + float(end[1]) * random.randf_range(0.3, 0.9)
				var slab := Vector3(lying, 0.2, fixed + out) if along_x else Vector3(fixed + out, 0.2, lying)
				_part("stonewall", slab, Vector3(1.5, 0.32, 1.0), _vary(Color(0.52, 0.52, 0.5), 0.03), Vector3(random.randf_range(5, 14), random.randf_range(0, 180), random.randf_range(-6, 6)))

## A tree of the farm's kinds; in the park it has a trunk to bump into.
func _tree(pos: Vector3, tall: float, trunk: bool = true) -> void:
	var id: String = TREE_MODELS[random.randi() % TREE_MODELS.size()]
	_model(id, pos, random.randf() * TAU, {"height": tall, "solid": false, "tint": TREE_TINT, "far": 170.0, "shadows": trunk})
	if trunk:
		_round_solid(pos, 0.3, 3.0)

## A round column from a floor up.
func _column(base: Vector3, radius: float, tall: float, material: String, color: Color, solid: bool = true) -> void:
	batch.cylinder(mats[material], base, radius, radius * 0.88, tall, color, 14)
	batch.cylinder(mats[material], base, radius * 1.3, radius * 1.2, 0.22, color.darkened(0.08), 14)
	_part(material, base + Vector3(0, tall - 0.1, 0), Vector3(radius * 2.5, 0.2, radius * 2.5), color.darkened(0.05))
	if solid:
		_round_solid(base, radius * 1.15, tall)

## The four things a supply point offers, side by side, looking the way `facing` points:
## ammunition, first aid, a workbench and a weapon locker.
func _supply(centre: Vector3, facing: Vector3, title: String) -> void:
	var yaw := atan2(-facing.z, facing.x)
	var along := Vector3(-facing.z, 0, facing.x)
	_station("ammo", "MUNITION", "60", centre + along * -3.3, yaw, Color("84d4c2"))
	_station("health", "ERSTE HILFE", "100", centre + along * -1.1, yaw, Color("f5b68e"))
	_station("upgrade", "WERKBANK", "250", centre + along * 1.1, yaw, Color("e8bd79"))
	var at := centre + along * 3.4
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	_placed(frame, "steel", Vector3(-0.1, 1.05, 0), Vector3(0.6, 2.1, 1.7), Color("2c3236"))
	_placed(frame, "plain", Vector3(0.21, 1.1, 0), Vector3(0.02, 1.8, 0.02), Color("0d0f10"))
	for row in range(3):
		_placed(frame, "plain", Vector3(0.21, 0.5 + row * 0.6, 0), Vector3(0.02, 0.04, 1.5), Color("0d0f10"))
	_glow_box(frame * Vector3(0.22, 2.0, 0), Vector3(0.02, 0.05, 1.5), Color("e8bd79"), 2.2, frame.basis)
	var label := lettering("WAFFENSCHRANK", frame * Vector3(0.25, 2.35, 0), 30, Color("e8bd79"))
	label.rotation.y = yaw + PI / 2
	_solid(at + Vector3(0, 1.05, 0) + frame.basis * Vector3(-0.1, 0, 0), Vector3(0.6, 2.1, 1.7), true, yaw)
	stations.append({"kind": "shop", "title": "WAFFENSCHRANK", "pos": at, "view": {"position": at + facing * 2.3 + Vector3(0, 1.55, 0), "target": at + Vector3(0, 1.2, 0)}})
	var head := lettering(title, centre + Vector3(0, 2.75, 0) - facing * 0.2, 44, Color("cfe6ff"))
	head.rotation.y = yaw + PI / 2
	_light(centre + facing * 1.4 + Vector3(0, 2.6, 0), Color("dff0ff"), 1.3, 8.0, false, 0.0, 0.4, 60.0)

# ---------------------------------------------------------------- the park

func _lay_grounds() -> void:
	_begin_zone("park", "out")
	area = ""
	_own_dice(71001)
	_room("grounds", ground, Rect2(-70, -32, 140, 126), 0.0, "none", {"outdoor": true, "seed": Vector2(0, 66)})
	_chunk("Ground", false)
	# The lawn, open where the stairs of the annex go down behind the villa.
	for tile in _tiles(Rect2(-70, -32, 140, 126), [Rect2(-2.5, -9, 5, 5), Rect2(-1.6, -15.2, 3.2, 6.2), Rect2(-24, -4, 48, 26)]):
		_part("lawn", Vector3(tile.get_center().x, -0.25, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), Color(0.4, 0.48, 0.35))
		for piece in _split(tile, 15.0):
			_solid(Vector3(piece.get_center().x, -0.25, piece.get_center().y), Vector3(piece.size.x, 0.5, piece.size.y), false)
	# The dark land beyond, and limits nobody sees.
	# (Open over the stairs too: seen from the park it used to lie across the way down.)
	for tile in _tiles(Rect2(-280, -250, 560, 560), [Rect2(-2.5, -9, 5, 5), Rect2(-1.6, -15.2, 3.2, 6.2)]):
		_part("ground", Vector3(tile.get_center().x, -0.34, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), Color("12160f"))
	for edge in [[Vector3(-70.3, 3, 31), Vector3(0.6, 8, 127)], [Vector3(70.3, 3, 31), Vector3(0.6, 8, 127)], [Vector3(0, 3, -32.3), Vector3(141, 8, 0.6)], [Vector3(0, 3, 94.3), Vector3(141, 8, 0.6)]]:
		_add_shape(body, edge[0], edge[1])
	# --- gravel: the drive from the gate, the landing ground, the round before the house
	_part("gravel", Vector3(0, -0.035, 74), Vector3(7, 0.1, 30), Color(0.62, 0.6, 0.56))
	batch.cylinder(mats["gravel"], Vector3(0, -0.084, 68), 10.5, 10.5, 0.1, Color(0.62, 0.6, 0.56), 28)
	batch.cylinder(mats["gravel"], Vector3(0, -0.083, 44), 12.5, 12.5, 0.1, Color(0.62, 0.6, 0.56), 32)
	_part("gravel", Vector3(0, -0.034, 31), Vector3(16, 0.1, 6), Color(0.62, 0.6, 0.56))
	_part("gravel", Vector3(38, -0.036, 31), Vector3(40, 0.1, 3.2), Color(0.58, 0.56, 0.52))
	_part("gravel", Vector3(-30, -0.036, 31), Vector3(28, 0.1, 3.2), Color(0.58, 0.56, 0.52))
	# --- the fountain in the round
	var basin := Vector3(0, 0, 44)
	batch.cylinder(mats["marble"], basin, 3.5, 3.4, 0.7, Color(0.7, 0.69, 0.66), 24)
	batch.cylinder(mats["water"], basin + Vector3(0, 0.56, 0), 3.15, 3.15, 0.02, Color.WHITE, 24)
	batch.cylinder(mats["marble"], basin, 0.7, 0.55, 1.7, Color(0.74, 0.73, 0.7), 12)
	batch.cylinder(mats["marble"], basin + Vector3(0, 1.7, 0), 1.3, 0.2, 0.3, Color(0.74, 0.73, 0.7), 16)
	_model("horse_statue_01", basin + Vector3(0, 2.0, 0), PI, {"height": 1.7, "solid": false, "far": 120.0, "tint": Color(0.55, 0.6, 0.56)})
	_round_solid(basin, 3.5, 0.9)
	_light(basin + Vector3(0, 1.2, 2.2), Color("9fd0e8"), 1.0, 7.0, false, 0.1, 0.8, 80.0)
	# --- the wall around the park, the gate, and where the wall has come down
	_park_wall(Vector2(-62, -26), Vector2(62, -26))
	_park_wall(Vector2(-62, 88), Vector2(62, 88), [[-38.0, -33.0], [-4.9, 4.9, false], [28.0, 33.0]])
	_park_wall(Vector2(-62, -26), Vector2(-62, 88), [[-2.0, 3.0], [38.0, 43.0]])
	_park_wall(Vector2(62, -26), Vector2(62, 88), [[2.0, 7.0], [50.0, 55.0]])
	for side in [-1.0, 1.0]:
		_part("stonewall", Vector3(side * 4.9, 2.0, 88), Vector3(1.0, 4.0, 1.0), Color(0.6, 0.6, 0.58))
		_part("stonewall", Vector3(side * 4.9, 4.1, 88), Vector3(1.3, 0.2, 1.3), Color(0.5, 0.5, 0.48))
		_glow_box(Vector3(side * 4.9, 4.45, 88), Vector3(0.3, 0.4, 0.3), Color("ffd08a"), 4.5)
		_light(Vector3(side * 4.9, 4.4, 87.2), Color("ffc884"), 2.0, 11.0, false, 0.05, 1.3, 90.0)
		_solid(Vector3(side * 4.9, 2.0, 88), Vector3(1.0, 4.0, 1.0))
	for i in range(23):
		var x := -4.2 + i * 0.38
		_part("metal", Vector3(x, 1.5, 88), Vector3(0.05, 3.0, 0.05), Color("101214"))
	for y in [0.35, 2.7]:
		_part("metal", Vector3(0, y, 88), Vector3(8.8, 0.07, 0.07), Color("101214"))
	_rail_solid(Vector3(0, 1.5, 88), Vector3(8.8, 3.0, 0.2))
	# --- lanterns
	for spot in [Vector2(-11.5, 84), Vector2(11.5, 84), Vector2(-12.5, 58), Vector2(12.5, 58), Vector2(-14, 38), Vector2(14, 38), Vector2(-34, 34), Vector2(34, 34), Vector2(-48, 60), Vector2(48, 60), Vector2(-48, 12), Vector2(50, 10)]:
		_park_lamp(Vector3(spot.x, 0, spot.y))
	# --- hedges: two gardens beside the drive, each a frame with ways in
	for side in [-1.0, 1.0]:
		_hedge(_span(side * 16 - 0.5, 54, side * 16 + 0.5, 82))
		_hedge(_span(minf(side * 16, side * 44), 82, maxf(side * 16, side * 44), 83))
		_hedge(_span(minf(side * 22, side * 44), 54, maxf(side * 22, side * 44), 55))
		_hedge(_span(side * 44 - 0.5, 62, side * 44 + 0.5, 76))
		_hedge(_span(minf(side * 24, side * 36), 67.5, maxf(side * 24, side * 36), 68.5), 1.0)
		_plinth(Vector3(side * 30, 0, 61), 1.2, "marble_bust_01", 0.8, PI if side > 0 else PI)
		_plinth(Vector3(side * 30, 0, 75), 1.2, "antique_ceramic_vase_01", 0.7)
	# --- trees: along the wall inside the park, and the dark wood outside it
	for spot in [
		Vector2(-55, 82), Vector2(-50, 70), Vector2(-56, 56), Vector2(-54, 46), Vector2(-56, 30), Vector2(-52, 20), Vector2(-56, 8), Vector2(-50, -8), Vector2(-56, -18), Vector2(-40, -20),
		Vector2(-28, -21), Vector2(-14, -20), Vector2(16, -21), Vector2(30, -20), Vector2(44, -19), Vector2(56, -16), Vector2(55, -2), Vector2(56, 18), Vector2(54, 32), Vector2(56, 44),
		Vector2(55, 64), Vector2(54, 78), Vector2(42, 84), Vector2(22, 85), Vector2(-22, 85), Vector2(-44, 84), Vector2(-40, 44), Vector2(40, 46), Vector2(-36, 8), Vector2(38, -6)
	]:
		_tree(Vector3(spot.x + random.randf_range(-1.5, 1.5), 0, spot.y + random.randf_range(-1.5, 1.5)), random.randf_range(11.0, 16.0))
	for i in range(64):
		var turn := TAU * i / 64.0 + random.randf_range(-0.04, 0.04)
		var far := random.randf_range(0.0, 1.0)
		var spot := Vector2(cos(turn) * (76 + far * 34), 28 + sin(turn) * (72 + far * 34))
		_tree(Vector3(spot.x, 0, spot.y), random.randf_range(13.0, 19.0), false)
	_dress_grounds(basin)
	# --- the supply drop beside the landing ground
	_supply(Vector3(-13.5, 0, 70), Vector3(1, 0, 0), "ABWURFZONE")
	for spot in [Vector3(7.5, 0, 75.5), Vector3(-7.5, 0, 75.5), Vector3(7.5, 0, 60.5), Vector3(-7.5, 0, 60.5)]:
		_glow_ball(spot + Vector3(0, 0.08, 0), 0.09, Color("ff4a2a"), 5.0)
		_light(spot + Vector3(0, 0.4, 0), Color("ff5030"), 0.7, 4.0, false, 0.3, 1.5, 80.0)
	_shared_dice()
	_end_zone()

# ---------------------------------------------------------------- the villa

func _lay_villa() -> void:
	_begin_zone("house", "villa", ["park"])
	area = ""
	_own_dice(71002)
	var shell := {"skin_top": EAVES, "skin_tint": OCHRE, "skin_depth": 0.25}
	_room("hall", ground, Rect2(-7, 8, 14, 14), 8.6, "hall", _with(shell, {"skin": [SOUTH]}))
	_room("salon", ground, Rect2(-24, 8, 17, 14), STOREY_VILLA, "wood", _with(shell, {"skin": [SOUTH, WEST]}))
	_room("galerie", ground, Rect2(7, 8, 17, 14), STOREY_VILLA, "wood", _with(shell, {"skin": [SOUTH, EAST], "look": {"core": ["plaster", Color(0.34, 0.5, 0.42)]}}))
	_room("dining", ground, Rect2(-10, -4, 20, 12), STOREY_VILLA, "wood", _with(shell, {"skin": [NORTH], "skin_skip": [[-2.5, 2.5]], "look": {"core": ["wallpaper", Color(0.56, 0.2, 0.18)], "wood": Color(0.7, 0.62, 0.56)}}))
	_room("library", ground, Rect2(-24, -4, 14, 12), STOREY_VILLA, "wood", _with(shell, {"skin": [NORTH, WEST], "look": {"core": ["plaster", Color(0.4, 0.42, 0.6)]}}))
	_room("kitchen", ground, Rect2(10, -4, 14, 12), STOREY_VILLA, "scullery", _with(shell, {"skin": [NORTH, EAST]}))
	# The gallery over the north end of the hall.
	_room("gallery", upper, Rect2(-7, 8, 14, 3.8), 4.0, "hall", {"walls": false, "floor": false, "ceiling": false, "lamps": "none"})
	# --- ways through the house
	_opening("hall", SOUTH, 0.0, 2.6, {"height": 3.2, "wings": false})
	_door("hall", "dining", 0.0, 2.4, {"height": 3.0})
	_door("hall", "salon", 20.5, 1.8)
	_door("hall", "galerie", 20.5, 1.8)
	_door("salon", "library", -17.0, 1.8)
	_door("dining", "library", 2.0, 1.8)
	_door("dining", "kitchen", 2.0, 1.8)
	_door("galerie", "kitchen", 17.0, 1.8)
	for at in [-19.5, -12.0]:
		_opening("salon", SOUTH, at, 1.8, {"height": 3.0, "wings": false})
	for at in [12.0, 19.5]:
		_opening("galerie", SOUTH, at, 1.8, {"height": 3.0, "wings": false})
	_opening("library", NORTH, -17.0, 1.6, {"wings": false})
	_opening("kitchen", EAST, 2.0, 1.6, {"wings": false})
	# --- windows
	for at in [-4.3, 4.3]:
		_pane("hall", SOUTH, at, 1.4, 0.9, 3.4, "window")
		_pane("hall", SOUTH, at, 1.4, 5.2, 7.8, "window")
	_pane("hall", SOUTH, 0.0, 2.0, 5.2, 7.8, "window")
	_pane("salon", WEST, 11.5, 1.5, 0.9, 3.4, "window")
	for at in [-1.0, 5.0]:
		_pane("library", WEST, at, 1.5, 0.9, 3.4, "window")
	for at in [-21.0, -13.0]:
		_pane("library", NORTH, at, 1.5, 0.9, 3.4, "window")
	for at in [-6.5, 6.5]:
		_pane("dining", NORTH, at, 1.5, 0.9, 3.4, "window")
	for at in [14.0, 20.0]:
		_pane("kitchen", NORTH, at, 1.5, 1.1, 3.2, "window")
	_pane("kitchen", EAST, 5.6, 1.4, 1.1, 3.2, "window")
	for at in [12.0, 18.0]:
		_pane("galerie", EAST, at, 1.5, 0.9, 3.4, "window")
	_villa_outside()
	_villa_hall()
	_villa_rooms()
	_shared_dice()
	_end_zone()

## A window of the upper storey, which nobody can enter: dark or lit glass in a frame on
## the outside of a wall.
func _upper_window(room_id: String, side: int, at: float, lit: bool) -> void:
	var room: Dictionary = room_of[room_id]
	var depth := HALF + 0.25
	_face_box(room, side, "plaster", at - 0.95, at + 0.95, 5.3, 8.1, depth, depth + 0.06, TRIM)
	_face_box(room, side, "plaster", at - 1.1, at + 1.1, 8.1, 8.3, depth, depth + 0.14, TRIM)
	_face_box(room, side, "plaster", at - 1.05, at + 1.05, 5.15, 5.3, depth, depth + 0.16, TRIM)
	if lit:
		_face_glow(room, side, at - 0.7, at + 0.7, 5.5, 7.9, depth + 0.06, depth + 0.075, Color("ffcf8f"), 1.3)
	else:
		_face_box(room, side, "plain", at - 0.7, at + 0.7, 5.5, 7.9, depth + 0.06, depth + 0.075, Color("0a0d12"))
	_face_box(room, side, "panelwood", at - 0.03, at + 0.03, 5.5, 7.9, depth + 0.075, depth + 0.1, Color(0.3, 0.24, 0.2))
	_face_box(room, side, "panelwood", at - 0.7, at + 0.7, 6.9, 6.96, depth + 0.075, depth + 0.1, Color(0.3, 0.24, 0.2))
	# Shutters folded back against the wall.
	var shutter := Color(0.13, 0.2, 0.17)
	for edge in [-1.0, 1.0]:
		var mid: float = at + float(edge) * 1.03
		_face_box(room, side, "plain", mid - 0.3, mid + 0.3, 5.42, 7.98, depth + 0.07, depth + 0.11, shutter)
		for k in range(8):
			_face_box(room, side, "plain", mid - 0.25, mid + 0.25, 5.56 + k * 0.3, 5.63 + k * 0.3, depth + 0.1, depth + 0.125, shutter.darkened(0.4))

func _villa_outside() -> void:
	_chunk("Outside")
	# The roof, the cornice under it and a parapet around it.
	_part("slate", Vector3(0, EAVES + 0.15, 9), Vector3(49.4, 0.3, 27.4), Color(0.42, 0.44, 0.46))
	for edge in [[Vector3(0, EAVES - 0.15, 22.75), Vector3(50.2, 0.5, 0.9)], [Vector3(0, EAVES - 0.15, -4.75), Vector3(50.2, 0.5, 0.9)], [Vector3(-24.75, EAVES - 0.15, 9), Vector3(0.9, 0.5, 27.4)], [Vector3(24.75, EAVES - 0.15, 9), Vector3(0.9, 0.5, 27.4)]]:
		var cornice: Vector3 = edge[1]
		_part("plaster", edge[0], cornice, TRIM)
		var parapet := Vector3(cornice.x - 0.5, 0.9, 0.35) if cornice.x > 2.0 else Vector3(0.35, 0.9, cornice.z - 0.5)
		_part("plaster", (edge[0] as Vector3) + Vector3(0, 0.7, 0), parapet, TRIM.darkened(0.06))
	# A band between the storeys and pilasters on the corners.
	for wall in [["salon", SOUTH, -24.4, -7.0], ["hall", SOUTH, -7.0, 7.0], ["galerie", SOUTH, 7.0, 24.4], ["salon", WEST, 8.0, 22.4], ["library", WEST, -4.4, 8.0], ["library", NORTH, -24.4, -10.0], ["dining", NORTH, -10.0, 10.0], ["kitchen", NORTH, 10.0, 24.4], ["kitchen", EAST, -4.4, 8.0], ["galerie", EAST, 8.0, 22.4]]:
		var room: Dictionary = room_of[wall[0]]
		_face_box(room, int(wall[1]), "plaster", float(wall[2]), float(wall[3]), 4.55, 4.85, HALF + 0.25, HALF + 0.37, TRIM)
		_face_box(room, int(wall[1]), "plaster", float(wall[2]), float(wall[3]), 0.0, 0.7, HALF + 0.25, HALF + 0.33, TRIM.darkened(0.2))
		# A frieze under the cornice and a row of dentils in it.
		_face_box(room, int(wall[1]), "plaster", float(wall[2]), float(wall[3]), EAVES - 1.0, EAVES - 0.39, HALF + 0.22, HALF + 0.3, TRIM.darkened(0.05))
		var teeth := maxi(1, roundi((float(wall[3]) - float(wall[2])) / 0.5))
		for i in range(teeth):
			var tooth := float(wall[2]) + (i + 0.5) * (float(wall[3]) - float(wall[2])) / teeth
			_face_box(room, int(wall[1]), "plaster", tooth - 0.11, tooth + 0.11, EAVES - 0.63, EAVES - 0.395, HALF + 0.22, HALF + 0.45, TRIM)
	for corner in [["salon", SOUTH, -24.3, -23.5], ["galerie", SOUTH, 23.5, 24.3], ["hall", SOUTH, -7.4, -6.6], ["hall", SOUTH, 6.6, 7.4], ["library", NORTH, -24.3, -23.5], ["kitchen", NORTH, 23.5, 24.3], ["salon", WEST, 21.5, 22.3], ["library", WEST, -4.3, -3.5], ["galerie", EAST, 21.5, 22.3], ["kitchen", EAST, -4.3, -3.5]]:
		_face_box(room_of[corner[0]], int(corner[1]), "plaster", float(corner[2]), float(corner[3]), 0.7, EAVES - 0.4, HALF + 0.25, HALF + 0.34, TRIM)
	# The upper storey: nobody gets up there, but somebody has left lamps burning.
	for entry in [["salon", SOUTH, -19.5, true], ["salon", SOUTH, -12.0, false], ["galerie", SOUTH, 12.0, false], ["galerie", SOUTH, 19.5, true], ["salon", WEST, 11.5, false], ["library", WEST, -1.0, true], ["library", WEST, 5.0, false], ["library", NORTH, -21.0, false], ["library", NORTH, -13.0, false], ["dining", NORTH, -6.5, false], ["dining", NORTH, 6.5, true], ["kitchen", NORTH, 14.0, false], ["kitchen", NORTH, 20.0, false], ["kitchen", EAST, 0.0, false], ["kitchen", EAST, 5.6, true], ["galerie", EAST, 12.0, false], ["galerie", EAST, 18.0, false]]:
		_upper_window(str(entry[0]), int(entry[1]), float(entry[2]), bool(entry[3]))
	# --- the terrace before the house with its balustrade, and the porch
	_part("cobble", Vector3(0, -0.03, 25.5), Vector3(53, 0.1, 6.1), Color(0.7, 0.68, 0.64))
	for piece in [[-26.0, -16.0], [-12.0, -4.5], [4.5, 12.0], [16.0, 26.0]]:
		var mid := (float(piece[0]) + float(piece[1])) * 0.5
		var long := float(piece[1]) - float(piece[0])
		_balustrade(Vector3(mid - long * 0.5, 0, 28.6), Vector3(mid + long * 0.5, 0, 28.6))
	for x in [-3.9, -1.8, 1.8, 3.9]:
		_column(Vector3(x, 0, 24.9), 0.3, 4.4, "marble", Color(0.84, 0.82, 0.78))
	_part("plaster", Vector3(0, 4.65, 23.75), Vector3(9.2, 0.5, 3.0), TRIM)
	_front_dress()
	# Light on the front: lanterns beside the doors and a wash from below.
	for x in [-22.0, -15.7, -8.6, 8.6, 15.7, 22.0]:
		var at := Vector3(x, 3.0, 22.52)
		_model("street_lamp_02", at + Vector3(0, -1.2, 0), 0.0, {"height": 1.3, "solid": false, "far": 90.0})
		_light(at + Vector3(0, 0.1, 0.9), Color("ffc27a"), 2.0, 9.5, false, 0.05, 1.2, 100.0)
	for x in [-21.0, -15.0, -9.0, 9.0, 15.0, 21.0]:
		_spot(Vector3(x, 0.3, 27.4), Vector3(0, 1.0, -0.62), Color("ffd9a8"), 9.0, 18.0, 50.0, 0.0, 0.3, 140.0)
	# --- the pergola along the east end of the terrace
	_part("cobble", Vector3(41.25, -0.032, 25), Vector3(29.5, 0.1, 5.2), Color(0.66, 0.64, 0.6))
	for i in range(8):
		for z in [23.1, 26.9]:
			_column(Vector3(28.5 + i * 3.7, 0, z), 0.24, 3.7, "plaster", TRIM)
	for z in [23.1, 26.9]:
		_part("panelwood", Vector3(41.4, 3.82, z), Vector3(27.6, 0.24, 0.3), Color(0.36, 0.29, 0.23))
	for i in range(15):
		_part("panelwood", Vector3(28.0 + i * 1.9, 4.0, 25), Vector3(0.16, 0.14, 4.6), Color(0.33, 0.27, 0.21))
	_park_lamp(Vector3(57, 0, 25))
	# --- the tower on the west corner: a drum, a look-out with columns, a copper dome
	var foot := Vector3(-28.5, 0, 18.2)
	batch.cylinder(mats["plaster"], foot, 4.1, 4.0, 13.0, OCHRE, 24)
	batch.cylinder(mats["plaster"], foot, 4.3, 4.2, 0.8, TRIM.darkened(0.2), 24)
	for y in [4.6, 9.2, 12.7]:
		batch.cylinder(mats["plaster"], foot + Vector3(0, y, 0), 4.22, 4.22, 0.3, TRIM, 24)
	batch.cylinder(mats["plaster"], foot + Vector3(0, 13.0, 0), 4.5, 4.4, 0.3, TRIM, 24)
	for i in range(8):
		var turn := TAU * i / 8.0
		_column(foot + Vector3(cos(turn) * 3.7, 13.3, sin(turn) * 3.7), 0.22, 3.0, "plaster", TRIM, false)
	batch.cylinder(mats["plaster"], foot + Vector3(0, 16.3, 0), 4.3, 4.3, 0.45, TRIM, 24)
	batch.ellipsoid(mats["metal"], foot + Vector3(0, 16.7, 0), Vector3(3.9, 2.6, 3.9), Color(0.24, 0.42, 0.36), Basis.IDENTITY, 20, 8)
	batch.cylinder(mats["metal"], foot + Vector3(0, 19.2, 0), 0.12, 0.04, 1.6, Color(0.24, 0.42, 0.36), 6)
	for entry in [[0.6, 3.0], [2.2, 7.2], [3.9, 10.8], [5.3, 6.4]]:
		var turn := float(entry[0])
		var at := foot + Vector3(cos(turn) * 4.07, float(entry[1]), sin(turn) * 4.07)
		_glow_box(at, Vector3(0.5, 1.3, 0.12), Color("ffcf8f"), 1.2, Basis(Vector3.UP, PI / 2 - turn))
	_light(foot + Vector3(0, 14.6, 0), Color("ffd29a"), 1.6, 8.0, false, 0.0, 0.6, 160.0)
	_round_solid(foot, 4.1, 14.0)
	# --- behind the house: the concrete annex over the hidden stairs
	_part("gravel", Vector3(-17, -0.035, -6), Vector3(4, 0.1, 3), Color(0.58, 0.56, 0.52))
	_part("gravel", Vector3(27, -0.035, 2), Vector3(5, 0.1, 3), Color(0.58, 0.56, 0.52))
	# Two floodlights of the guards on the terrace: their beams stand in the haze of the park.
	_floodlight(Vector3(-13.6, 0, 27.3), Vector3(-3.0, 0.5, 54.0))
	_floodlight(Vector3(13.6, 0, 27.3), Vector3(3.0, 0.5, 54.0))

func _villa_hall() -> void:
	var hall: Dictionary = room_of["hall"]
	_chunk("Hall")
	var marble := Color(0.86, 0.84, 0.8)
	# The gallery: a floor on four columns, a balustrade, two flights up to it.
	_part("marble", Vector3(0, STOREY_VILLA - 0.15, 9.9), Vector3(13.6, 0.3, 3.4), marble)
	_part("parquet", Vector3(0, STOREY_VILLA + 0.006, 9.9), Vector3(13.6, 0.012, 3.4), Color(0.8, 0.74, 0.68))
	_solid(Vector3(0, STOREY_VILLA - 0.15, 9.9), Vector3(13.6, 0.3, 3.4), false)
	for x in [-4.4, -1.9, 1.9, 4.4]:
		_column(Vector3(x, 0, 11.35), 0.22, STOREY_VILLA - 0.3, "marble", marble)
	_guard_rail(Vector3(-4.5, STOREY_VILLA, 11.5), Vector3(4.5, STOREY_VILLA, 11.5), Color(0.3, 0.24, 0.2))
	for side in [-1.0, 1.0]:
		var foot := Vector3(side * 5.6, 0, 19.2)
		var head := Vector3(side * 5.6, STOREY_VILLA, 11.6)
		_steps(foot, head, 2.0, "marble", marble, 0.0)
		_handrail(foot, head, -side * 0.97, Color(0.3, 0.24, 0.2))
		_register(Vector3(side * 5.6, 1.0, 15.4), Vector3(2.0, 2.0, 7.6))
		_link(PackedVector3Array([Vector3(side * 5.5, 0, 20.0), Vector3(side * 5.5, 0, 19.2), Vector3(side * 5.5, STOREY_VILLA, 11.6), Vector3(side * 5.5, STOREY_VILLA, 11.0)]), 2.0, ground, upper)
		# Doors up there that stay shut.
		_part("panelwood", Vector3(side * 3.2, STOREY_VILLA + 1.2, 8.24), Vector3(1.1, 2.4, 0.08), Color(0.36, 0.28, 0.22))
		_part("panelwood", Vector3(side * 3.2, STOREY_VILLA + 2.5, 8.25), Vector3(1.4, 0.16, 0.1), Color(0.3, 0.23, 0.18))
		# Beside the way in: a console with a vase, a bust on a plinth.
		_against("hall", EAST if side > 0 else WEST, 15.0, "ClassicConsole_01", {"solid": true})
		_model("antique_ceramic_vase_01", _face_point(hall, EAST if side > 0 else WEST, 15.0, 0.95, -0.34), 0.0, {"height": 0.55, "solid": false, "far": 30.0})
		_plinth(Vector3(side * 2.4, 0, 9.0), 1.2, "marble_bust_01", 0.75, 0.0)
		_painting("hall", EAST if side > 0 else WEST, 15.0, 2.0, 2.6)
	_carpet(Vector3(0, 0, 15.2), Vector2(2.4, 12.6), Color(0.42, 0.08, 0.08))
	_painting("hall", NORTH, 0.0, 2.6, 6.4)
	_light(Vector3(0, 3.4, 9.6), Color("ffd7a3"), 1.2, 7.0, false, 0.0, 0.3, LAMP_FADE)
	_light(Vector3(0, STOREY_VILLA + 2.6, 9.8), Color("ffd7a3"), 1.2, 8.0, false, 0.0, 0.3, LAMP_FADE)

func _villa_rooms() -> void:
	_chunk("Rooms")
	var salon: Dictionary = room_of["salon"]
	var dining: Dictionary = room_of["dining"]
	var kitchen: Dictionary = room_of["kitchen"]
	# --- the salon: seats around the fire
	_fireplace("salon", WEST, 16.0)
	_carpet(Vector3(-19.4, 0, 16.0), Vector2(6.4, 5.0), Color(0.2, 0.26, 0.3))
	_model("sofa_03", Vector3(-17.2, 0, 16.0), -PI / 2, {})
	_model("sofa_02", Vector3(-20.4, 0, 19.3), PI, {})
	_model("ArmChair_01", Vector3(-20.6, 0, 12.8), 0.0, {})
	_model("WoodenTable_02", Vector3(-20.4, 0, 16.0), 0.0, {"height": 0.5})
	_against("salon", NORTH, -21.6, "GothicCabinet_01")
	_against("salon", NORTH, -11.0, "ClassicConsole_01")
	_model("brass_candleholders", _face_point(salon, NORTH, -11.0, 0.95, -0.34), 0.0, {"width": 0.8, "solid": false, "far": 30.0})
	_painting("salon", NORTH, -11.0, 1.6, 2.5)
	_painting("salon", WEST, 16.0, 1.5, 3.2, "fancy_picture_frame_02")
	_painting("salon", EAST, 13.0, 2.0, 2.4)
	# --- the gallery of pictures
	for at in [9.5, 12.5, 20.5, 22.6]:
		_painting("galerie", NORTH, at, 1.5, 2.3)
	_painting("galerie", EAST, 15.0, 1.9, 2.4)
	for at in [15.75]:
		_painting("galerie", SOUTH, at, 1.7, 2.4)
	_painting("galerie", WEST, 12.0, 2.2, 2.4)
	for spot in [Vector3(11.5, 0, 15.0), Vector3(19.5, 0, 15.0)]:
		_plinth(spot, 1.15, "marble_bust_01", 0.75, PI / 2)
	_plinth(Vector3(15.5, 0, 15.0), 0.9, "horse_statue_01", 1.3, 0.0, 1.1)
	_carpet(Vector3(15.5, 0, 15.0), Vector2(11.0, 3.4), Color(0.18, 0.22, 0.18))
	_against("galerie", EAST, 20.6, "vintage_cabinet_01")
	_against("galerie", SOUTH, 15.75, "sofa_02", {"solid": "low"}, 0.1)
	# --- the library
	_bookcase("library", WEST, 0.4, 3.6)
	_bookcase("library", WEST, 6.2, 7.6)
	_bookcase("library", WEST, -3.6, -2.2)
	_bookcase("library", NORTH, -11.9, -10.4)
	_bookcase("library", SOUTH, -23.6, -18.2)
	_bookcase("library", SOUTH, -15.8, -10.4)
	_carpet(Vector3(-17.5, 0, 2.2), Vector2(6.0, 4.4), Color(0.3, 0.12, 0.1))
	_table(Vector3(-17.5, 0, 2.2), Vector3(2.6, 0.78, 1.2), Color(0.3, 0.22, 0.17))
	_model("dining_chair_02", Vector3(-17.5, 0, 3.3), PI, {"solid": false})
	_model("ArmChair_01", Vector3(-21.8, 0, 5.4), PI * 0.75, {})
	_model("desk_lamp_arm_01", Vector3(-18.3, 0.78, 2.1), 1.0, {"height": 0.6, "solid": false, "far": 25.0})
	_light(Vector3(-18.0, 1.5, 2.2), Color("ffd29a"), 0.9, 4.5, false, 0.0, 0.4, LAMP_FADE)
	# --- the dining room: the long table, and the mirror on the north wall
	_carpet(Vector3(0, 0, 2.4), Vector2(11.0, 5.2), Color(0.28, 0.1, 0.1))
	_part("panelwood", Vector3(0, 0.76, 2.4), Vector3(8.4, 0.08, 1.6), Color(0.34, 0.25, 0.19))
	for x in [-3.6, 0.0, 3.6]:
		_part("panelwood", Vector3(x, 0.36, 2.4), Vector3(0.5, 0.72, 0.9), Color(0.28, 0.2, 0.15))
	for x in [-3.2, -1.6, 0.0, 1.6, 3.2]:
		_model("dining_chair_02", Vector3(x, 0, 1.25), 0.0, {"solid": false, "far": 40.0})
		_model("dining_chair_02", Vector3(x, 0, 3.55), PI, {"solid": false, "far": 40.0})
	_solid(Vector3(0, 0.45, 2.4), Vector3(8.6, 0.9, 3.1))
	for x in [-2.2, 2.2]:
		_model("brass_candleholders", Vector3(x, 0.8, 2.4), 0.0, {"width": 0.7, "solid": false, "far": 30.0})
		_light(Vector3(x, 1.5, 2.4), Color("ffbd75"), 0.8, 4.0, false, 0.25, 0.4, LAMP_FADE)
	_against("dining", SOUTH, -6.0, "GothicCommode_01")
	_against("dining", SOUTH, 6.0, "GothicCommode_01")
	_painting("dining", SOUTH, -6.0, 1.6, 2.5)
	_painting("dining", SOUTH, 6.0, 1.6, 2.5)
	_painting("dining", WEST, 5.6, 1.8, 2.4)
	_painting("dining", EAST, 5.6, 1.8, 2.4)
	# The lock that opens the mirror: a small panel beside it.
	_face_box(dining, NORTH, "plate", 1.55, 1.85, 1.2, 1.6, -0.04, 0.0, Color("16191b"))
	_face_glow(dining, NORTH, 1.6, 1.8, 1.42, 1.55, -0.046, -0.04, Color("ff5a3c"), 2.4)
	# --- the kitchen
	_counter("kitchen", NORTH, 10.6, 23.4, Color(0.42, 0.36, 0.3), Color(0.7, 0.69, 0.66))
	_counter("kitchen", WEST, 4.2, 7.4, Color(0.42, 0.36, 0.3), Color(0.7, 0.69, 0.66))
	_table(Vector3(17.0, 0, 2.0), Vector3(3.4, 0.86, 1.3), Color(0.36, 0.3, 0.24))
	_against("kitchen", SOUTH, 21.5, "steel_frame_shelves_01", {"height": 2.1})
	_against("kitchen", SOUTH, 12.6, "Shelf_01")
	_model("Barrel_01", Vector3(22.6, 0, -2.6), 0.4, {})
	_model("barrel_03", Vector3(22.7, 0, -1.6), 1.3, {})
	_model("plastic_crate_02", Vector3(21.6, 0, -3.0), 0.2, {"scale": 1.4})
	_face_box(kitchen, NORTH, "steel", 16.2, 17.8, 0.92, 0.98, -0.6, -0.05, Color("3a3d3f"))
	_face_box(kitchen, NORTH, "plain", 16.4, 17.6, 2.0, 2.5, -0.5, 0.0, Color("2a2c2d"))
	_dress_villa()

## Curtains drawn back at a window of a room, under a wooden pelmet.
func _curtains(room_id: String, side: int, at: float, wide: float, head: float, cloth: Color) -> void:
	var room: Dictionary = room_of[room_id]
	for edge in [-1.0, 1.0]:
		var a: float = at + edge * (wide * 0.5 + 0.22)
		_face_box(room, side, "velvet", a - 0.24, a + 0.24, 0.06, head + 0.22, -0.16, -0.07, _vary(cloth, 0.02))
		_face_box(room, side, "velvet", a - 0.15, a + 0.15, 0.4, head, -0.2, -0.16, cloth.darkened(0.14))
	_face_box(room, side, "panelwood", at - wide * 0.5 - 0.56, at + wide * 0.5 + 0.56, head + 0.2, head + 0.4, -0.22, 0.0, Color(0.3, 0.23, 0.18))

## A lamp on a wall of the house: a brass arm, a shade that glows, a little warm light.
func _sconce(room_id: String, side: int, a: float, high: float = 2.3) -> void:
	var room: Dictionary = room_of[room_id]
	_face_box(room, side, "metal", a - 0.045, a + 0.045, high - 0.18, high + 0.02, -0.13, 0.0, Color(0.5, 0.4, 0.2))
	_face_glow(room, side, a - 0.075, a + 0.075, high + 0.02, high + 0.2, -0.21, -0.07, Color("ffcf8f"), 4.4)
	var lamp := _light(_face_point(room, side, a, high + 0.1, -0.55), Color("ffc27a"), 1.0, 5.5, false, 0.08, 0.5, LAMP_FADE)
	lamp.omni_attenuation = 1.4

## A floodlight on a stand, aimed at `target`: its beam stands in the haze of the park.
func _floodlight(pos: Vector3, target: Vector3) -> void:
	var head := pos + Vector3(0, 2.5, 0)
	for k in range(3):
		var turn := TAU * k / 3.0 + 0.4
		_pipe(pos + Vector3(cos(turn) * 0.6, 0, sin(turn) * 0.6), pos + Vector3(0, 1.5, 0), 0.025, Color("15171a"), 6)
	_pipe(pos + Vector3(0, 1.5, 0), head, 0.03, Color("15171a"), 6)
	var aim := (target - head).normalized()
	var turn_to := Basis.looking_at(aim, Vector3.UP)
	batch.box(mats["metal"], head, Vector3(0.5, 0.36, 0.24), Color("17191b"), turn_to)
	batch.box(mats["glow"], head + aim * 0.125, Vector3(0.42, 0.28, 0.012), Color(1.0, 0.95, 0.84), turn_to)
	_spot(head + aim * 0.2, aim, Color("fff1d6"), 16.0, 52.0, 24.0, 0.03, 2.4, 160.0)
	_round_solid(pos, 0.3, 2.6)

## What makes the house a house somebody lived in, and one the guards held until tonight.
func _dress_villa() -> void:
	var red := Color(0.36, 0.08, 0.08)
	var green := Color(0.1, 0.24, 0.17)
	for at in [-4.3, 4.3]:
		_curtains("hall", SOUTH, at, 1.4, 3.4, red)
	_curtains("salon", WEST, 11.5, 1.5, 3.4, green)
	for at in [-6.5, 6.5]:
		_curtains("dining", NORTH, at, 1.5, 3.4, red)
	for at in [12.0, 18.0]:
		_curtains("galerie", EAST, at, 1.5, 3.4, green)
	for entry in [["hall", EAST, 18.2, 2.5], ["hall", WEST, 18.2, 2.5], ["hall", SOUTH, -2.45, 2.5], ["hall", SOUTH, 2.45, 2.5], ["salon", NORTH, -14.4, 2.3], ["salon", SOUTH, -15.75, 2.3], ["salon", EAST, 17.0, 2.3],
			["galerie", NORTH, 15.0, 2.3], ["galerie", NORTH, 18.7, 2.3], ["galerie", WEST, 16.6, 2.3], ["library", NORTH, -15.0, 2.3], ["dining", SOUTH, -3.2, 2.3], ["dining", SOUTH, 3.2, 2.3], ["dining", NORTH, -4.4, 2.3]]:
		_sconce(str(entry[0]), int(entry[1]), float(entry[2]), float(entry[3]))
	_fireplace("library", EAST, 5.6)
	# --- more places to sit: a second round in the salon, two chairs at the library's fire,
	# benches before the pictures
	_carpet(Vector3(-11.6, 0, 13.6), Vector2(5.4, 4.6), Color(0.3, 0.1, 0.1))
	_model("sofa_02", Vector3(-11.6, 0, 11.7), 0.0, {})
	_model("ArmChair_01", Vector3(-13.8, 0, 14.2), PI / 2, {})
	_model("ArmChair_01", Vector3(-9.4, 0, 14.2), -PI / 2, {})
	_model("WoodenTable_02", Vector3(-11.6, 0, 13.9), 0.0, {"height": 0.5})
	_model("antique_ceramic_vase_01", Vector3(-11.6, 0.5, 13.9), 0.0, {"height": 0.4, "solid": false, "far": 30.0})
	_against("salon", EAST, 10.4, "GothicCommode_01")
	_plant(Vector3(-23.0, 0, 21.0), 1.6)
	_plant(Vector3(-8.0, 0, 9.0), 1.5)
	_model("ArmChair_01", Vector3(-12.6, 0, 4.2), PI / 2, {})
	_model("ArmChair_01", Vector3(-12.6, 0, 6.6), PI / 2, {})
	_model("WoodenTable_02", Vector3(-13.2, 0, 5.4), 0.0, {"height": 0.5})
	_model("sofa_02", Vector3(11.0, 0, 11.4), PI, {})
	_model("sofa_02", Vector3(20.4, 0, 11.4), PI, {})
	_plant(Vector3(8.0, 0, 21.0), 1.6)
	_plant(Vector3(23.0, 0, 9.0), 1.6)
	# --- the post of the guards under the gallery: a table with their radio, what they had left
	_table(Vector3(-5.2, 0, 9.4), Vector3(1.8, 0.78, 0.8), Color(0.24, 0.26, 0.2))
	_model("vintage_radio_transceiver", Vector3(-5.6, 0.78, 9.3), 0.2, {"width": 0.6, "solid": false, "far": 30.0})
	_papers(Transform3D(Basis(Vector3.UP, 0.3), Vector3(-4.8, 0.79, 9.45)), Vector3.ZERO, 5, 0.3)
	_glow_box(Vector3(-4.5, 0.86, 9.2), Vector3(0.08, 0.14, 0.08), Color("ffd08a"), 4.5)
	_light(Vector3(-4.5, 1.1, 9.4), Color("ffc884"), 0.9, 4.5, false, 0.1, 0.5, LAMP_FADE)
	_crate(Vector3(5.0, 0, 9.3), Vector3(1.1, 0.7, 0.8), Color("4d5a46"), 0.1)
	_crate(Vector3(5.1, 0.72, 9.3), Vector3(0.7, 0.45, 0.6), Color("56624a"), 0.4, false)
	_crate(Vector3(6.1, 0, 10.1), Vector3(0.8, 0.55, 0.6), Color("5a4a36"), 1.0)
	for k in range(3):
		_model("ammo_box", Vector3(4.2 + k * 0.24, 0, 10.4 + k * 0.1), 0.4 * k, {"scale": 1.6, "solid": false, "far": 25.0})
	# --- what happened here
	_blot(Vector3(-11.0, 0, 18.6), 1.0, 0.7)
	_smear(Vector3(-10.6, 0, 18.9), Vector3(-7.6, 0, 20.4), 0.28)
	_blot(Vector3(13.0, 0, 20.2), 0.9, 0.6)
	_blot(Vector3(2.4, 0, -1.5), 0.8, 0.6)
	_chair(Vector3(4.6, 0, 4.6), 2.2, Color(0.3, 0.22, 0.17), true)
	_litter(Vector3(-16.4, 0.016, 3.6), 1.2, 9)
	_litter(Vector3(4.2, 0, 17.2), 0.9, 6)

# ---------------------------------------------------------------- the park and the front, second pass

## A clipped cone of yew on a short stem, in a stone tub if `tub`: the dark shapes before
## the lit front.
func _topiary(pos: Vector3, tall: float = 3.0, radius: float = 0.8, tub: bool = false) -> void:
	var foot := pos
	if tub:
		_part("marble", pos + Vector3(0, 0.27, 0), Vector3(0.86, 0.58, 0.86), Color(0.6, 0.59, 0.56))
		_part("marble", pos + Vector3(0, 0.56, 0), Vector3(0.96, 0.08, 0.96), Color(0.68, 0.67, 0.64))
		_solid(pos + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9))
		foot = pos + Vector3(0, 0.55, 0)
	else:
		_round_solid(pos, radius * 0.6, 2.0)
	batch.cylinder(mats["panelwood"], foot, 0.07, 0.07, 0.5, Color(0.3, 0.24, 0.2), 6)
	batch.cylinder(mats["lawn"], foot + Vector3(0, 0.35, 0), radius, 0.05, tall - 0.35, Color(0.15, 0.23, 0.15), 12)

## A bench of the park: wooden slats on iron ends. The seat faces local +z.
func _park_bench(pos: Vector3, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	var iron := Color("15171a")
	var wood := Color(0.44, 0.36, 0.28)
	for edge in [-1.0, 1.0]:
		var x: float = float(edge) * 0.82
		_placed(frame, "metal", Vector3(x, 0.21, 0.0), Vector3(0.06, 0.46, 0.5), iron)
		_placed(frame, "metal", Vector3(x, 0.66, -0.24), Vector3(0.05, 0.5, 0.05), iron)
		_placed(frame, "metal", Vector3(x, 0.62, 0.02), Vector3(0.07, 0.04, 0.5), iron)
	for k in range(4):
		_placed(frame, "panelwood", Vector3(0, 0.45, -0.17 + k * 0.125), Vector3(1.8, 0.035, 0.1), wood)
	for k in range(3):
		_placed(frame, "panelwood", Vector3(0, 0.58 + k * 0.13, -0.225), Vector3(1.8, 0.1, 0.03), wood)
	_solid(pos + Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.5), true, yaw)

## A stone balustrade from one spot to another (along x or along z): piers, balusters and a
## rail. `first` and `last` say whether a pier stands at either end.
func _balustrade(from: Vector3, to: Vector3, solid: bool = true, first: bool = true, last: bool = true) -> void:
	var stone := Color(0.76, 0.75, 0.72)
	var span := to - from
	var long := span.length()
	var dir := span / long
	var mid := (from + to) * 0.5
	var along := Vector3(absf(dir.x), 0, absf(dir.z))
	var across := Vector3(absf(dir.z), 0, absf(dir.x))
	_part("marble", mid + Vector3(0, 0.08, 0), along * long + across * 0.34 + Vector3(0, 0.2, 0), stone.darkened(0.1))
	_part("marble", mid + Vector3(0, 0.9, 0), along * (long + 0.08) + across * 0.42 + Vector3(0, 0.12, 0), stone)
	var bays := maxi(1, roundi(long / 3.4))
	var piers: Array[float] = []
	for i in range(bays + 1):
		if (i == 0 and not first) or (i == bays and not last):
			continue
		piers.append(long * i / bays)
		var at := from + dir * (long * i / bays)
		_part("marble", at + Vector3(0, 0.49, 0), Vector3(0.4, 1.02, 0.4), stone.darkened(0.04))
		_part("marble", at + Vector3(0, 1.03, 0), Vector3(0.5, 0.08, 0.5), stone)
	var count := maxi(1, roundi(long / 0.3))
	for i in range(count):
		var way := long * (i + 0.5) / count
		var free := true
		for pier in piers:
			if absf(pier - way) < 0.3:
				free = false
		if free:
			_part("marble", from + dir * way + Vector3(0, 0.51, 0), Vector3(0.12, 0.68, 0.12), stone)
	if solid:
		_solid(mid + Vector3(0, 0.5, 0), along * long + across * 0.36 + Vector3(0, 1.0, 0))

## What a window of the house has on its outside: a stone surround with a sill and a small
## cornice, and shutters folded back. (Everything reaches a little into the wall, so that
## no back lies in the wall's own plane.)
func _window_dress(room_id: String, side: int, at: float, wide: float, sill: float, head: float, shutters: bool = true) -> void:
	var room: Dictionary = room_of[room_id]
	var skin := HALF + 0.25
	var back := skin - 0.03
	var half := wide * 0.5
	var green := Color(0.13, 0.2, 0.17)
	for edge in [-1.0, 1.0]:
		var e: float = edge
		var a0: float = at + e * (half + 0.03)
		var a1: float = at + e * (half + 0.3)
		_face_box(room, side, "plaster", minf(a0, a1), maxf(a0, a1), sill - 0.1, head + 0.12, back, skin + 0.1, TRIM)
		if shutters:
			var mid: float = at + e * (half + 0.63)
			_face_box(room, side, "plain", mid - 0.3, mid + 0.3, sill - 0.02, head + 0.02, skin + 0.012, skin + 0.05, green)
			var slats := maxi(2, roundi((head - sill) / 0.3))
			for k in range(slats):
				var y: float = sill + 0.1 + k * (head - sill - 0.2) / slats
				_face_box(room, side, "plain", mid - 0.25, mid + 0.25, y, y + 0.07, skin + 0.04, skin + 0.065, green.darkened(0.4))
	_face_box(room, side, "plaster", at - half - 0.31, at + half + 0.31, head + 0.03, head + 0.34, back, skin + 0.11, TRIM)
	_face_box(room, side, "plaster", at - half - 0.44, at + half + 0.44, head + 0.32, head + 0.46, back, skin + 0.24, TRIM.darkened(0.04))
	_face_box(room, side, "plaster", at - half - 0.44, at + half + 0.44, sill - 0.19, sill - 0.03, back, skin + 0.16, TRIM.darkened(0.04))

## The same for a door of the house: pilaster strips beside it, a frieze and a cornice.
func _door_dress(room_id: String, side: int, at: float, wide: float, head: float) -> void:
	var room: Dictionary = room_of[room_id]
	var skin := HALF + 0.25
	var back := skin - 0.03
	var half := wide * 0.5
	for edge in [-1.0, 1.0]:
		var e: float = edge
		var a0: float = at + e * (half + 0.1)
		var a1: float = at + e * (half + 0.42)
		_face_box(room, side, "plaster", minf(a0, a1), maxf(a0, a1), -0.05, head + 0.14, back, skin + 0.1, TRIM)
	_face_box(room, side, "plaster", at - half - 0.43, at + half + 0.43, head + 0.1, head + 0.38, back, skin + 0.11, TRIM)
	_face_box(room, side, "plaster", at - half - 0.58, at + half + 0.58, head + 0.36, head + 0.52, back, skin + 0.28, TRIM.darkened(0.04))

## The front of the house, second pass: the balcony over the porch, a gable with a lit
## round window, chimneys, and stone around every window and door.
func _front_dress() -> void:
	# --- the balcony on the porch: a balustrade, urns on its corners, a lantern under it
	_balustrade(Vector3(-4.36, 4.9, 25.0), Vector3(4.36, 4.9, 25.0), false)
	for x in [-4.36, 4.36]:
		_balustrade(Vector3(float(x), 4.9, 22.3), Vector3(float(x), 4.9, 25.0), false, false, false)
		batch.ellipsoid(mats["marble"], Vector3(float(x), 6.22, 25.0), Vector3(0.27, 0.27, 0.27), Color(0.78, 0.77, 0.74), Basis.IDENTITY, 12, 8)
	batch.cylinder(mats["metal"], Vector3(0, 3.75, 24.0), 0.02, 0.02, 0.66, Color("15171a"), 6)
	_part("metal", Vector3(0, 3.74, 24.0), Vector3(0.36, 0.05, 0.36), Color("15171a"))
	_glow_box(Vector3(0, 3.5, 24.0), Vector3(0.26, 0.42, 0.26), Color("ffd08a"), 5.5)
	_part("metal", Vector3(0, 3.262, 24.0), Vector3(0.32, 0.04, 0.32), Color("15171a"))
	_light(Vector3(0, 3.3, 24.2), Color("ffc884"), 2.2, 9.0, false, 0.04, 1.0, 110.0)
	# --- the gable over the middle of the front, with a round window somebody has left lit
	var plaster: Material = mats["plaster"]
	var low := EAVES + 0.1
	var rise := 2.7
	var reach := 7.8
	var face := 22.96
	batch.quad(plaster, Vector3(-reach, low, face), Vector3(reach, low, face), Vector3(0, low + rise, face), Vector3(0, low + rise, face), OCHRE)
	batch.quad(plaster, Vector3(reach, low, face - 0.44), Vector3(-reach, low, face - 0.44), Vector3(0, low + rise, face - 0.44), Vector3(0, low + rise, face - 0.44), OCHRE.darkened(0.4))
	var slope := atan2(rise, reach)
	var rake := Vector2(reach, rise).length() + 0.7
	for edge in [-1.0, 1.0]:
		var e: float = edge
		_part("plaster", Vector3(e * reach * 0.5, low + rise * 0.5 + 0.12, 22.9 + e * 0.006), Vector3(rake, 0.3, 0.84), TRIM, Vector3(0, 0, -e * rad_to_deg(slope)))
	var window := Vector3(0, low + 1.05, 0)
	var turned := Basis(Vector3.RIGHT, PI / 2)
	batch.cylinder(plaster, window + Vector3(0, 0, 22.9), 0.84, 0.84, 0.075, TRIM, 20, turned)
	batch.cylinder(mats[glow_key], window + Vector3(0, 0, 22.9), 0.64, 0.64, 0.09, Color(0.52, 0.42, 0.29), 20, turned)
	_part("plain", window + Vector3(0, 0, 23.006), Vector3(1.3, 0.05, 0.02), Color(0.2, 0.16, 0.13))
	_part("plain", window + Vector3(0, 0, 23.008), Vector3(0.05, 1.3, 0.02), Color(0.2, 0.16, 0.13))
	# --- chimneys over the fireplaces
	for spot in [Vector3(-22.4, 0, 16.0), Vector3(22.4, 0, 16.0), Vector3(-10.6, 0, 5.6), Vector3(10.6, 0, 5.6)]:
		var at: Vector3 = spot
		_part("plaster", at + Vector3(0, EAVES + 1.65, 0), Vector3(1.0, 3.2, 1.6), OCHRE.darkened(0.15))
		_part("plaster", at + Vector3(0, EAVES + 3.3, 0), Vector3(1.24, 0.2, 1.84), TRIM.darkened(0.1))
		for z in [-0.42, 0.42]:
			batch.cylinder(mats["metal"], at + Vector3(0, EAVES + 3.38, float(z)), 0.17, 0.14, 0.5, Color(0.3, 0.2, 0.16), 8)
	# --- stone around the windows and the doors of the ground floor, and shutters
	for entry in [["hall", SOUTH, -4.3, 1.4, 0.9, 3.4], ["hall", SOUTH, 4.3, 1.4, 0.9, 3.4], ["salon", WEST, 11.5, 1.5, 0.9, 3.4], ["library", WEST, -1.0, 1.5, 0.9, 3.4], ["library", WEST, 5.0, 1.5, 0.9, 3.4],
			["library", NORTH, -21.0, 1.5, 0.9, 3.4], ["library", NORTH, -13.0, 1.5, 0.9, 3.4], ["dining", NORTH, -6.5, 1.5, 0.9, 3.4], ["dining", NORTH, 6.5, 1.5, 0.9, 3.4], ["kitchen", NORTH, 14.0, 1.5, 1.1, 3.2],
			["kitchen", NORTH, 20.0, 1.5, 1.1, 3.2], ["kitchen", EAST, 5.6, 1.4, 1.1, 3.2], ["galerie", EAST, 12.0, 1.5, 0.9, 3.4], ["galerie", EAST, 18.0, 1.5, 0.9, 3.4]]:
		_window_dress(str(entry[0]), int(entry[1]), float(entry[2]), float(entry[3]), float(entry[4]), float(entry[5]))
	for entry in [["hall", SOUTH, -4.3, 1.4], ["hall", SOUTH, 4.3, 1.4], ["hall", SOUTH, 0.0, 2.0]]:
		_window_dress(str(entry[0]), int(entry[1]), float(entry[2]), float(entry[3]), 5.2, 7.8, false)
	for entry in [["hall", SOUTH, 0.0, 2.6, 3.2], ["salon", SOUTH, -19.5, 1.8, 3.0], ["salon", SOUTH, -12.0, 1.8, 3.0], ["galerie", SOUTH, 12.0, 1.8, 3.0], ["galerie", SOUTH, 19.5, 1.8, 3.0],
			["library", NORTH, -17.0, 1.6, DOOR_TALL], ["kitchen", EAST, 2.0, 1.6, DOOR_TALL]]:
		_door_dress(str(entry[0]), int(entry[1]), float(entry[2]), float(entry[3]), float(entry[4]))
	# --- yew in stone tubs on the terrace
	for x in [-18.0, -6.2, 6.2, 18.0]:
		_topiary(Vector3(float(x), 0.02, 27.9), 2.9, 0.62, true)

## A clipped hedge along an arc around a spot of the park (degrees: 0 is east, 90 south).
func _hedge_arc(centre: Vector3, radius: float, from_deg: float, to_deg: float, tall: float = 0.95, thick: float = 0.9) -> void:
	var count := maxi(1, roundi(absf(to_deg - from_deg) / 11.0))
	var step := deg_to_rad(to_deg - from_deg) / count
	var long := 2.0 * (radius + thick * 0.5) * tan(absf(step) * 0.5) + 0.04
	for i in range(count):
		var turn := deg_to_rad(from_deg) + step * (i + 0.5)
		var high := tall + (0.014 if i % 2 == 1 else 0.0)
		var at := centre + Vector3(cos(turn) * radius, high * 0.5 - 0.02, sin(turn) * radius)
		var yaw := atan2(-cos(turn), -sin(turn))
		batch.box(mats["lawn"], at, Vector3(long, high, thick), Color(0.2, 0.3, 0.19), Basis(Vector3.UP, yaw))
		_solid(at, Vector3(long, high, thick), true, yaw)

## The post of the guards at the gate: a hut with its lamp on, a barrier that stands open,
## sandbags, and nobody.
func _guard_post(at: Vector3) -> void:
	var wall := Color(0.62, 0.63, 0.6)
	var dark := Color("1b1e20")
	_part("plaster", at + Vector3(0, 0.49, 0), Vector3(2.6, 1.02, 3.0), wall)
	_part("plaster", at + Vector3(0, 2.25, 0), Vector3(2.6, 0.52, 3.0), wall)
	_glow_box(at + Vector3(0, 1.5, 0), Vector3(2.5, 1.04, 2.9), Color("ffcf8f"), 1.5)
	for x in [-1.24, 1.24]:
		for z in [-1.44, 0.0, 1.44]:
			_part("plain", at + Vector3(float(x), 1.5, float(z)), Vector3(0.14, 1.02, 0.14), dark)
	for z in [-1.44, 1.44]:
		_part("plain", at + Vector3(0, 1.5, float(z)), Vector3(0.12, 1.02, 0.14), dark)
	_part("slate", at + Vector3(-0.3, 2.57, 0), Vector3(3.8, 0.14, 3.6), Color(0.3, 0.31, 0.33))
	_part("plain", at + Vector3(-1.31, 0.985, 0.72), Vector3(0.04, 2.0, 0.9), Color("23282b"))
	_glow_box(at + Vector3(-1.33, 1.55, 0.72), Vector3(0.02, 0.5, 0.5), Color("ffcf8f"), 2.2)
	var label := lettering("WACHE", at + Vector3(-1.32, 2.27, -0.3), 34, Color("d8dde0"))
	label.rotation.y = -PI / 2
	_solid(at + Vector3(0, 1.3, 0), Vector3(2.6, 2.6, 3.0))
	_glow_box(at + Vector3(-1.9, 2.46, 0), Vector3(0.5, 0.06, 0.16), Color("fff1d6"), 6.0)
	_light(at + Vector3(-2.1, 2.2, 0), Color("ffe2b8"), 2.0, 9.0, false, 0.03, 1.2, 100.0)
	# The barrier: its post beside the drive, the boom up.
	var pivot := at + Vector3(-4.0, 1.0, -0.6)
	_part("metal", pivot + Vector3(0, -0.47, 0), Vector3(0.26, 1.1, 0.26), Color("2a2e31"))
	_solid(pivot + Vector3(0, -0.45, 0), Vector3(0.26, 1.1, 0.26))
	var lean := deg_to_rad(112.0)
	for k in range(5):
		var along := 0.2 + k * 0.92
		_part("plain", pivot + Vector3(cos(lean) * along, sin(lean) * along, 0.14), Vector3(0.92, 0.1, 0.08), Color(0.8, 0.12, 0.1) if k % 2 == 0 else Color(0.86, 0.86, 0.82), Vector3(0, 0, 112.0))
	# Sandbags towards the house, a crate of theirs, and what is left of one of them.
	var bags := at + Vector3(-1.6, 0, -3.0)
	for row in range(3):
		for k in range(4 - row % 2):
			_part("cloth", bags + Vector3(-0.9 + k * 0.6 + (0.3 if row % 2 == 1 else 0.0), 0.11 + row * 0.19, random.randf_range(-0.02, 0.02)), Vector3(0.57, 0.2, 0.34), _vary(Color(0.42, 0.39, 0.3), 0.03), Vector3(0, random.randf_range(-5, 5), 0))
	_solid(bags + Vector3(0, 0.3, 0), Vector3(2.4, 0.6, 0.36))
	_crate(at + Vector3(0.6, 0, -2.3), Vector3(0.9, 0.6, 0.6), Color("4d5a46"), 0.3)
	_blot(at + Vector3(-2.6, 0, 1.6), 0.9, 0.6)
	_smear(at + Vector3(-2.4, 0, 1.9), at + Vector3(-1.2, 0, 3.4), 0.26)
	_litter(at + Vector3(-2.4, 0.004, -1.2), 0.8, 5)

## The park, second pass: the landing ground marked and lit, the round with its hedge and
## benches, statues, the guards' post at the gate.
func _dress_grounds(basin: Vector3) -> void:
	# --- the landing ground: a broken ring and an H in paint, lamps in the gravel, a floodlight
	var pad := Vector3(0, 0, 68)
	var paint := Color(0.8, 0.78, 0.7)
	for i in range(24):
		var turn := TAU * (i + 0.5) / 24.0
		_part("plain", pad + Vector3(cos(turn) * 8.8, 0.034, sin(turn) * 8.8), Vector3(1.4, 0.012, 0.24), paint, Vector3(0, rad_to_deg(atan2(-cos(turn), -sin(turn))), 0))
	for x in [-1.2, 1.2]:
		_part("plain", pad + Vector3(float(x), 0.034, 0), Vector3(0.5, 0.012, 3.6), paint)
	_part("plain", pad + Vector3(0, 0.034, 0), Vector3(1.88, 0.012, 0.5), paint)
	for i in range(8):
		var turn := TAU * i / 8.0 + PI / 8.0
		_glow_box(pad + Vector3(cos(turn) * 9.9, 0.056, sin(turn) * 9.9), Vector3(0.2, 0.07, 0.2), Color("ffb04a"), 5.5)
	_floodlight(Vector3(10.6, 0, 77.4), Vector3(0, 0.3, 68))
	# --- the round: a step around the basin, a low hedge in two arcs, urns where they end,
	# benches that look at the water
	batch.cylinder(mats["marble"], basin + Vector3(0, -0.02, 0), 4.5, 4.5, 0.14, Color(0.6, 0.59, 0.56), 28)
	_hedge_arc(basin, 13.7, -52.0, 52.0)
	_hedge_arc(basin, 13.7, 128.0, 232.0)
	for deg in [-58.0, 58.0, 122.0, 238.0]:
		var turn := deg_to_rad(float(deg))
		_plinth(basin + Vector3(cos(turn) * 13.7, 0, sin(turn) * 13.7), 1.1, "", 0.0, 0.0, 0.62)
		batch.ellipsoid(mats["marble"], basin + Vector3(cos(turn) * 13.7, 1.44, sin(turn) * 13.7), Vector3(0.33, 0.33, 0.33), Color(0.78, 0.77, 0.74), Basis.IDENTITY, 12, 8)
	for deg in [-30.0, 30.0, 150.0, 210.0]:
		var turn := deg_to_rad(float(deg))
		_park_bench(basin + Vector3(cos(turn) * 11.4, 0, sin(turn) * 11.4), atan2(-cos(turn), -sin(turn)))
	for side in [-1.0, 1.0]:
		_plinth(Vector3(float(side) * 19.5, 0, 41.0), 1.5, "marble_bust_01", 1.1, -float(side) * PI / 2, 0.7)
	# --- yew along the drive between the gate and the landing ground
	for z in [80.0, 84.5]:
		_topiary(Vector3(-5.2, 0, float(z)), 3.4, 0.9)
	_topiary(Vector3(5.2, 0, 80.0), 3.4, 0.9)
	_guard_post(Vector3(8.4, 0, 84.8))

# ---------------------------------------------------------------- more of the kit

## A square concrete pillar with a warning band at its foot.
func _pillar(base: Vector3, wide: float, tall: float, color: Color = Color(0.72, 0.72, 0.7)) -> void:
	_part("formwork", base + Vector3(0, tall * 0.5, 0), Vector3(wide, tall, wide), color)
	_hazard(base + Vector3(-wide * 0.5 - 0.004, 0.0, 0), base + Vector3(-wide * 0.5 - 0.004, 1.2, 0), Vector3(0.008, 0.3, wide), 4)
	_hazard(base + Vector3(wide * 0.5 + 0.004, 0.0, 0), base + Vector3(wide * 0.5 + 0.004, 1.2, 0), Vector3(0.008, 0.3, wide), 4)
	_hazard(base + Vector3(0, 0.0, -wide * 0.5 - 0.004), base + Vector3(0, 1.2, -wide * 0.5 - 0.004), Vector3(wide, 0.3, 0.008), 4)
	_hazard(base + Vector3(0, 0.0, wide * 0.5 + 0.004), base + Vector3(0, 1.2, wide * 0.5 + 0.004), Vector3(wide, 0.3, 0.008), 4)
	_solid(base + Vector3(0, tall * 0.5, 0), Vector3(wide, tall, wide))

## A strip of paint on a floor between two points (along x or along z).
func _stripe(from: Vector3, to: Vector3, wide: float, color: Color) -> void:
	var span := (to - from).abs()
	_part("plain", (from + to) * 0.5 + Vector3(0, 0.004, 0), Vector3(maxf(span.x, wide), 0.008, maxf(span.z, wide)), color)

## A desk with a screen on it and a chair before it; its user looks along `yaw` (the
## front of a node, -z).
func _desk(pos: Vector3, yaw: float, picture: int = 1) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "steel", Vector3(0, 0.74, -0.2), Vector3(1.6, 0.05, 0.8), Color("5d6468"))
	_placed(frame, "steel", Vector3(-0.72, 0.36, -0.2), Vector3(0.06, 0.72, 0.74), Color("3a4044"))
	_placed(frame, "steel", Vector3(0.72, 0.36, -0.2), Vector3(0.06, 0.72, 0.74), Color("3a4044"))
	_placed(frame, "steel", Vector3(0.42, 0.4, -0.2), Vector3(0.5, 0.6, 0.7), Color("454b4f"))
	_monitor(frame, Vector3(-0.1, 0.765, -0.4), picture, 0.0)
	_placed(frame, "plain", Vector3(-0.1, 0.775, -0.08), Vector3(0.42, 0.02, 0.15), Color("15181a"))
	_placed(frame, "cloth", Vector3(0, 0.46, 0.55), Vector3(0.48, 0.08, 0.46), Color("23292d"))
	_placed(frame, "cloth", Vector3(0, 0.78, 0.76), Vector3(0.46, 0.56, 0.07), Color("23292d"))
	_placed(frame, "plain", Vector3(0, 0.22, 0.55), Vector3(0.06, 0.44, 0.06), Color("15181a"))
	_solid(frame * Vector3(0, 0.4, 0.0), Vector3(1.6, 0.8, 1.5), true, yaw)

## A control desk along a side of a room from `a` to `b`: a slanted board of screens and
## lamps over a steel foot.
func _console(room_id: String, side: int, a: float, b: float, pictures: Array = [1, 3, 5]) -> void:
	var room: Dictionary = room_of[room_id]
	_face_box(room, side, "steel", a, b, 0.0, 0.8, -0.7, 0.0, Color("2f3539"))
	_face_box(room, side, "plain", a, b, 0.0, 0.1, -0.74, 0.0, Color("0d0f10"))
	_face_box(room, side, "steel", a, b, 0.8, 0.86, -0.76, 0.0, Color("454c51"))
	_face_box(room, side, "steel", a, b, 0.86, 1.36, -0.22, 0.0, Color("272c30"))
	var count := maxi(1, roundi((b - a) / 0.9))
	var yaw := _face_yaw(side)
	for i in range(count):
		var at := a + (i + 0.5) * (b - a) / count
		var frame := Transform3D(Basis(Vector3.UP, yaw + PI), _face_point(room, side, at, 1.1, -0.23))
		_screen(frame, Vector3(0, 0, 0.006), Vector2(0.66, 0.4), int(pictures[i % pictures.size()]))
		for k in range(4):
			_led(_face_point(room, side, at - 0.24 + k * 0.16, 0.875, -0.5), Vector3(0.05, 0.012, 0.05), [Color("5ee07a"), Color("ffb347"), Color("5ee07a"), Color("ff3a2a")][k], 3.0, [1.0, 0.7, 1.0, 0.4][k])
	_solid(_face_centre(room, side, a, b, 0.0, 1.36, -0.76, 0.0), _face_size(side, a, b, 0.0, 1.36, -0.76, 0.0))

## Steel lockers along a side of a room.
func _lockers(room_id: String, side: int, a: float, b: float, color: Color = Color("4a5a66")) -> void:
	var room: Dictionary = room_of[room_id]
	var count := maxi(1, roundi((b - a) / 0.45))
	var wide := (b - a) / count
	for i in range(count):
		_face_box(room, side, "steel", a + i * wide + 0.01, a + (i + 1) * wide - 0.01, 0.06, 1.96, -0.5, 0.0, _vary(color, 0.02))
		_face_box(room, side, "plain", a + i * wide + 0.08, a + (i + 1) * wide - 0.08, 1.6, 1.74, -0.506, -0.5, Color("15181a"))
	_solid(_face_centre(room, side, a, b, 0.0, 1.96, -0.5, 0.0), _face_size(side, a, b, 0.0, 1.96, -0.5, 0.0))

## A canteen table with a bench on either side, along x.
func _mess_table(pos: Vector3, long: float = 2.4) -> void:
	_part("steel", pos + Vector3(0, 0.74, 0), Vector3(long, 0.05, 0.8), Color("8a8f8c"))
	for x in [-long * 0.5 + 0.2, long * 0.5 - 0.2]:
		_part("steel", pos + Vector3(x, 0.36, 0), Vector3(0.08, 0.72, 0.7), Color("3f4548"))
	for z in [-0.72, 0.72]:
		_part("cloth", pos + Vector3(0, 0.44, z), Vector3(long - 0.2, 0.06, 0.34), Color("27343c"))
		_part("steel", pos + Vector3(0, 0.2, z), Vector3(long - 0.4, 0.4, 0.06), Color("3f4548"))
	_solid(pos + Vector3(0, 0.4, 0), Vector3(long, 0.8, 1.8))

## Crates and drums stood together; nothing two of them have in common.
func _stores(pos: Vector3, count: int = 4) -> void:
	for i in range(count):
		var at := pos + Vector3(random.randf_range(-1.1, 1.1), 0, random.randf_range(-1.1, 1.1))
		var pick := random.randi() % 4
		if pick == 0:
			_model("Barrel_01", at, random.randf() * TAU, {"far": 45.0})
		elif pick == 1:
			_model("barrel_03", at, random.randf() * TAU, {"far": 45.0})
		else:
			var size := Vector3(random.randf_range(0.7, 1.2), random.randf_range(0.6, 1.0), random.randf_range(0.7, 1.1))
			_crate(at, size, _vary(Color("4d5a46") if pick == 2 else Color("5a4a36"), 0.04), random.randf() * 0.6)

## A great tank of a containment hall: steel, glass and something that glows in it.
func _vessel(base: Vector3, radius: float, tall: float, glow: Color) -> void:
	batch.cylinder(mats["steel"], base, radius + 0.5, radius + 0.4, 1.1, Color("2c3236"), 24)
	batch.cylinder(mats["steel"], base + Vector3(0, tall - 1.2, 0), radius + 0.4, radius + 0.5, 1.2, Color("2c3236"), 24)
	batch.cylinder(mats["steel"], base + Vector3(0, 1.1, 0), radius * 0.36, radius * 0.3, tall - 2.3, Color("15181a"), 12)
	for ring in range(5):
		batch.cylinder(mats["steady"], base + Vector3(0, 1.6 + ring * (tall - 3.4) / 4.0, 0), radius * 0.62, radius * 0.62, 0.16, Color(glow.r * 0.6, glow.g * 0.6, glow.b * 0.6), 16)
	_chunk("Glass", false)
	batch.cylinder(mats["pane"], base + Vector3(0, 1.1, 0), radius, radius, tall - 2.3, Color.WHITE, 24, Basis.IDENTITY, false)
	_chunk("Kit")
	for y in [1.1, tall * 0.5, tall - 1.2]:
		batch.cylinder(mats["steel"], base + Vector3(0, y - 0.08, 0), radius + 0.12, radius + 0.12, 0.16, Color("1c2023"), 24)
	for i in range(6):
		var turn := TAU * i / 6.0
		_pipe(base + Vector3(cos(turn) * (radius + 0.3), 0.0, sin(turn) * (radius + 0.3)), base + Vector3(cos(turn) * (radius + 0.3), tall, sin(turn) * (radius + 0.3)), 0.09, Color("3d4347"), 8, "steel")
	_light(base + Vector3(0, tall * 0.5, radius + 1.6), glow, 2.2, radius * 3.2, false, 0.12, 0.8, LAMP_FADE + 14.0)
	_light(base + Vector3(0, tall * 0.5, -radius - 1.6), glow, 2.2, radius * 3.2, false, 0.12, 0.8, LAMP_FADE + 14.0)
	_round_solid(base, radius + 0.5, tall)

## A gallery floor at `y` over a plan rectangle, on posts, with a railing along the given
## sides ([side, from, to] along that side).
func _deck_floor(plan: Rect2, y: float, _floor_y: float, rails_at: Array) -> void:
	var middle := plan.get_center()
	_part("tread", Vector3(middle.x, y - 0.1, middle.y), Vector3(plan.size.x, 0.2, plan.size.y), Color(0.42, 0.44, 0.46))
	_part("plate", Vector3(middle.x, y - 0.26, middle.y), Vector3(plan.size.x, 0.12, plan.size.y), Color("1d2124"))
	for tile in _split(plan, 15.0):
		_solid(Vector3(tile.get_center().x, y - 0.16, tile.get_center().y), Vector3(tile.size.x, 0.32, tile.size.y), false)
	for entry in rails_at:
		var side := int(entry[0])
		var a := float(entry[1])
		var b := float(entry[2])
		match side:
			NORTH:
				_guard_rail(Vector3(a, y, plan.position.y + 0.08), Vector3(b, y, plan.position.y + 0.08))
			SOUTH:
				_guard_rail(Vector3(a, y, plan.end.y - 0.08), Vector3(b, y, plan.end.y - 0.08))
			WEST:
				_guard_rail(Vector3(plan.position.x + 0.08, y, a), Vector3(plan.position.x + 0.08, y, b))
			EAST:
				_guard_rail(Vector3(plan.end.x - 0.08, y, a), Vector3(plan.end.x - 0.08, y, b))

## A steel flight from a floor up to a gallery, with rails, and the path over it.
func _deck_stairs(foot: Vector3, head: Vector3, low: int, high: int, land_low: Vector3, land_high: Vector3) -> void:
	_steps(foot, head, 2.0, "tread", Color(0.42, 0.44, 0.46))
	_handrail(foot, head, 0.98)
	_handrail(foot, head, -0.98)
	var run := Vector2(head.x - foot.x, head.z - foot.z)
	# Nobody walks through under its lower half.
	var low_half := foot.lerp(head, 0.25)
	_register(Vector3(low_half.x, foot.y + 1.0, low_half.z), Vector3(2.0 if absf(run.y) > absf(run.x) else absf(run.x) * 0.5, 2.0, absf(run.y) * 0.5 if absf(run.y) > absf(run.x) else 2.0))
	_link(PackedVector3Array([land_low, foot, head, land_high]), 2.0, low, high)

## The pit of a railway line through a room that is `long` metres along x: its floor, the
## rails, the wall under the platform's edge (which lies at `edge_z`, the platform on the
## side `toward` of it: +1 south, -1 north), and a stub of dark tunnel at either end.
func _track(room_id: String, edge_z: float, toward: float) -> void:
	var room: Dictionary = room_of[room_id]
	var outer: Rect2 = room.outer
	var y := float(room.y)
	var pit := y - 1.1
	var mid_z := outer.get_center().y
	_part("darkfloor", Vector3(0, pit - 0.15, mid_z), Vector3(outer.size.x + 30.0, 0.3, outer.size.y), Color(0.5, 0.5, 0.5))
	_solid(Vector3(0, pit - 0.25, mid_z), Vector3(outer.size.x, 0.5, outer.size.y), false)
	# Under the platform's edge, and under the far wall.
	_part("formwork", Vector3(0, y - 0.55, edge_z + toward * 0.1), Vector3(outer.size.x, 1.1, 0.2), Color(0.6, 0.6, 0.58))
	var far_z := outer.position.y if toward > 0.0 else outer.end.y
	_part("formwork", Vector3(0, y - 0.55, far_z + toward * 0.1), Vector3(outer.size.x, 1.1, 0.2), Color(0.6, 0.6, 0.58))
	# The line the car stands on runs 2 m from the platform's edge.
	var line := edge_z - toward * 2.0
	for rail in [-0.75, 0.75]:
		_part("steel", Vector3(0, pit + 0.09, line + rail), Vector3(outer.size.x + 30.0, 0.18, 0.09), Color("3b3d3e"))
	for i in range(int((outer.size.x + 30.0) / 1.5)):
		_part("formwork", Vector3(-outer.size.x * 0.5 - 15.0 + i * 1.5 + 0.75, pit + 0.04, line), Vector3(0.34, 0.08, 2.5), Color(0.42, 0.42, 0.4))
	# The yellow line along the edge of the platform.
	_stripe(Vector3(outer.position.x, y, edge_z + toward * 0.75), Vector3(outer.end.x, y, edge_z + toward * 0.75), 0.18, Color("c9a227"))
	# The tunnel at either end: black after a few metres.
	for end in [-1.0, 1.0]:
		var x: float = end * (outer.size.x * 0.5 + 7.5)
		_part("beton", Vector3(x, y + 4.75, line), Vector3(15.0, 0.3, 5.6), Color(0.3, 0.3, 0.3))
		for wall in [-1.0, 1.0]:
			_part("beton", Vector3(x, y + 1.75, line + wall * 2.65), Vector3(15.0, 5.9, 0.3), Color(0.34, 0.34, 0.34))
		_part("plain", Vector3(end * (outer.size.x * 0.5 + 15.0), y + 1.75, line), Vector3(0.2, 6.0, 5.6), Color("030303"))
		_glow_box(Vector3(end * (outer.size.x * 0.5 + 9.0), y + 3.2, line + 2.4), Vector3(0.16, 0.16, 0.05), Color("ff3a2a"), 4.0)
		_light(Vector3(end * (outer.size.x * 0.5 + 8.0), y + 3.0, line + 1.8), Color("ff4030"), 1.2, 7.0, false, 0.0, 0.8, 70.0)
		_add_shape(body, Vector3(end * (outer.size.x * 0.5 + 0.2), y + 2.0, line), Vector3(0.3, 6.5, 6.0))

## A car of the train, 14 m long and 4 m wide, around `centre` on its floor: its body
## with windows, benches, grab rails and lamps. `open` is the side its doors work on (the
## other one stays shut); the doorways themselves are declared with the room.
func _train_car(centre: Vector3, open: int) -> void:
	var yellow := Color(0.78, 0.6, 0.12)
	var dark := Color("17191b")
	_chunk("Car")
	_part("tread", centre + Vector3(0, -0.1, 0), Vector3(14.0, 0.2, 4.0), Color(0.36, 0.38, 0.4))
	_solid(centre + Vector3(0, -0.25, 0), Vector3(14.0, 0.5, 4.0), false)
	_part("plate", centre + Vector3(0, 2.7, 0), Vector3(14.2, 0.2, 4.1), dark)
	_add_shape(body, centre + Vector3(0, 2.7, 0), Vector3(14.2, 0.2, 4.1))
	_part("plate", centre + Vector3(0, -0.75, 0), Vector3(13.0, 0.7, 2.6), dark)
	for x in [-4.6, -3.4, 3.4, 4.6]:
		for z in [-0.75, 0.75]:
			batch.cylinder(mats["steel"], centre + Vector3(x, -0.72, z - 0.07), 0.42, 0.42, 0.14, Color("26282a"), 14, Basis(Vector3.RIGHT, PI / 2))
	for side in [-1.0, 1.0]:
		var z: float = side * 1.93
		# Between the doorway and each end: a sill, a band of windows, a band above.
		for half in [-1.0, 1.0]:
			var x0 := 1.2 if half > 0.0 else -7.0
			var x1 := 7.0 if half > 0.0 else -1.2
			var mid := (x0 + x1) * 0.5
			var long := x1 - x0
			_part("plate", centre + Vector3(mid, 0.5, z), Vector3(long, 1.0, 0.14), yellow)
			_part("plain", centre + Vector3(mid, 0.14, z + side * 0.072), Vector3(long, 0.2, 0.004), dark)
			_part("plate", centre + Vector3(mid, 2.3, z), Vector3(long, 0.6, 0.14), yellow.darkened(0.1))
			for post in range(4):
				_part("plate", centre + Vector3(x0 + post * long / 3.0, 1.5, z), Vector3(0.14, 1.0, 0.14), dark)
			_chunk("Glass", false)
			batch.box(mats["pane"], centre + Vector3(mid, 1.5, z), Vector3(long, 1.0, 0.03), Color.WHITE)
			_chunk("Car")
			_add_shape(body, centre + Vector3(mid, 1.3, z), Vector3(long, 2.6, 0.16))
			# A bench under the windows.
			_part("cloth", centre + Vector3(mid, 0.46, z - side * 0.3), Vector3(long - 0.5, 0.08, 0.44), Color("2c3a44"))
			_part("steel", centre + Vector3(mid, 0.22, z - side * 0.3), Vector3(long - 0.7, 0.44, 0.06), Color("3a3f43"))
			_add_shape(body, centre + Vector3(mid, 0.25, z - side * 0.3), Vector3(long - 0.5, 0.5, 0.44))
		# The side whose doors do not work: two wings, shut.
		var shut: bool = (side < 0.0) == (open == SOUTH)
		if shut:
			for wing in [-1.0, 1.0]:
				_part("cladding", centre + Vector3(wing * 0.6, 1.1, z), Vector3(1.18, 2.2, 0.09), Color(0.5, 0.53, 0.55))
				_part("plain", centre + Vector3(wing * 0.6, 1.4, z), Vector3(0.5, 0.42, 0.1), Color("0d1114"))
			_part("plate", centre + Vector3(0, 2.4, z), Vector3(2.4, 0.4, 0.14), yellow.darkened(0.1))
			_add_shape(body, centre + Vector3(0, 1.3, z), Vector3(2.4, 2.6, 0.16))
		else:
			_part("plate", centre + Vector3(0, 2.4, z), Vector3(2.4, 0.4, 0.14), yellow.darkened(0.1))
		_pipe(centre + Vector3(-6.6, 2.1, side * 1.2), centre + Vector3(6.6, 2.1, side * 1.2), 0.025, Color("9a9c98"), 6, "steel")
	for end in [-1.0, 1.0]:
		_part("plate", centre + Vector3(end * 6.93, 0.5, 0), Vector3(0.14, 1.0, 3.8), yellow)
		_part("plate", centre + Vector3(end * 6.93, 2.3, 0), Vector3(0.14, 0.6, 3.8), yellow.darkened(0.1))
		for post in [-1.86, 0.0, 1.86]:
			_part("plate", centre + Vector3(end * 6.93, 1.5, post), Vector3(0.14, 1.0, 0.14), dark)
		_chunk("Glass", false)
		batch.box(mats["pane"], centre + Vector3(end * 6.93, 1.5, 0), Vector3(0.03, 1.0, 3.7), Color.WHITE)
		_chunk("Car")
		_add_shape(body, centre + Vector3(end * 6.93, 1.3, 0), Vector3(0.16, 2.6, 3.8))
		_hazard(centre + Vector3(end * 7.004, 0.25, -1.9), centre + Vector3(end * 7.004, 0.25, 1.9), Vector3(0.008, 0.3, 0.475), 8)
	for x in [-4.2, 4.2]:
		_part("plate", centre + Vector3(x, 2.57, 0), Vector3(1.3, 0.06, 0.3), dark)
		_glow_box(centre + Vector3(x, 2.53, 0), Vector3(1.2, 0.03, 0.22), Color("dfeaff"), 5.0)
		_light(centre + Vector3(x, 2.1, 0), Color("dfeaff"), 2.0, 7.0, false, 0.05, 0.3, 60.0)
	_stripe(centre + Vector3(-1.2, 0.0, -1.7), centre + Vector3(1.2, 0.0, -1.7), 0.14, Color("c9a227"))
	_stripe(centre + Vector3(-1.2, 0.0, 1.7), centre + Vector3(1.2, 0.0, 1.7), 0.14, Color("c9a227"))

## The locomotive at the east end of the train and a flat car with freight at the west
## end, standing on the same line as the car around `centre`.
func _train_ends(centre: Vector3) -> void:
	var yellow := Color(0.78, 0.6, 0.12)
	var dark := Color("17191b")
	_chunk("Train")
	var loco := centre + Vector3(13.2, 0, 0)
	_part("plate", loco + Vector3(0, 1.2, 0), Vector3(11.0, 2.6, 3.6), yellow)
	_part("plate", loco + Vector3(-1.0, 2.9, 0), Vector3(7.5, 0.8, 3.2), dark)
	_part("plate", loco + Vector3(4.2, 2.75, 0), Vector3(2.4, 0.5, 3.4), yellow.darkened(0.15))
	_part("plate", loco + Vector3(0, -0.6, 0), Vector3(10.4, 1.0, 2.6), dark)
	_hazard(loco + Vector3(-5.5, 0.4, 1.81), loco + Vector3(5.5, 0.4, 1.81), Vector3(0.6875, 0.5, 0.01), 16)
	_hazard(loco + Vector3(-5.5, 0.4, -1.81), loco + Vector3(5.5, 0.4, -1.81), Vector3(0.6875, 0.5, 0.01), 16)
	_glow_box(loco + Vector3(4.2, 2.15, 1.82), Vector3(1.6, 0.6, 0.02), Color("ffd9a0"), 1.6)
	_glow_box(loco + Vector3(4.2, 2.15, -1.82), Vector3(1.6, 0.6, 0.02), Color("ffd9a0"), 1.6)
	for z in [-1.1, 1.1]:
		_glow_box(loco + Vector3(5.52, 0.9, z), Vector3(0.03, 0.3, 0.3), Color("fff2cf"), 6.0)
	_spot(loco + Vector3(5.7, 0.9, 0), Vector3(1, -0.08, 0), Color("fff2cf"), 6.0, 26.0, 34.0, 0.0, 1.5, 70.0)
	var name_south := lettering("N-01", loco + Vector3(-2.6, 2.0, 1.83), 110, Color("15171a"))
	name_south.outline_size = 0
	var name_north := lettering("N-01", loco + Vector3(-2.6, 2.0, -1.83), 110, Color("15171a"))
	name_north.rotation.y = PI
	name_north.outline_size = 0
	_add_shape(body, loco + Vector3(0, 1.3, 0), Vector3(11.0, 4.0, 3.6))
	var flat := centre + Vector3(-12.6, 0, 0)
	_part("plate", flat + Vector3(0, -0.2, 0), Vector3(10.6, 0.4, 3.4), dark)
	_part("tread", flat + Vector3(0, 0.02, 0), Vector3(10.6, 0.05, 3.4), Color(0.34, 0.36, 0.38))
	for spot in [Vector3(-3.4, 0.05, 0.4), Vector3(-1.2, 0.05, -0.5), Vector3(1.4, 0.05, 0.3), Vector3(3.6, 0.05, -0.2)]:
		_crate(flat + spot, Vector3(random.randf_range(1.2, 1.8), random.randf_range(1.0, 1.5), random.randf_range(1.2, 1.7)), _vary(Color("56624a"), 0.05), random.randf() * 0.3, false)
	_add_shape(body, flat + Vector3(0, 0.8, 0), Vector3(10.6, 2.4, 3.4))

# ---------------------------------------------------------------- passages and signs

## The colours that lead through the facility: lines on the floor, bands on the walls and
## the cells of the plan on the displays (see HiveDisplay) agree on them.
const GUIDE := {
	"terminal": Color("c9a227"), "admin": Color("2f6fb0"), "security": Color("b8452f"), "cafe": Color("d8b13a"), "core": Color("cfe6ff"),
	"med": Color("3fb8c8"), "tech": Color("d9772a"), "research": Color("2f8f8a"), "hall": Color("a8322c"), "flood": Color("3a8fd0")
}

## True if nothing is cut into a side of a room between two places along it.
func _wall_free(room: Dictionary, side: int, a: float, b: float) -> bool:
	for gap in room.open[side]:
		if b > float(gap[0]) - 0.12 and a < float(gap[1]) + 0.12:
			return false
	return true

## Gives a passage its rhythm: ribs on both walls with a beam under the ceiling between
## its bays, a light coffer in every bay, lines on the floor and a tray of cables under
## the ceiling. Options: step (the length of a bay), light / energy / reach / flicker (of
## its lamps), lit (every so many coffers one is a lamp that lights; the others only
## glow), dead (the bays whose coffer is dark), fail (the bays whose lamp is giving up),
## lines ([place across the passage, colour, width]), tray (the side its cables run
## along; -1 for none), ribs (false for none), glow (the name of a lamp glass of its own).
func _passage(room_id: String, options: Dictionary = {}) -> void:
	var room: Dictionary = room_of[room_id]
	var inner: Rect2 = room.inner
	var along_x := inner.size.x >= inner.size.y
	var from := inner.position.x if along_x else inner.position.y
	var to := inner.end.x if along_x else inner.end.y
	var wide := inner.size.y if along_x else inner.size.x
	var mid := inner.get_center().y if along_x else inner.get_center().x
	var y := float(room.y)
	var tall := float(room.height)
	var count := maxi(1, roundi((to - from) / float(options.get("step", 6.0))))
	var bay := (to - from) / count
	var steel := Color("1c2023")
	var sides := [NORTH, SOUTH] if along_x else [WEST, EAST]
	# A place in the passage: along it, across it (from its middle), above its floor.
	var spot := func(along: float, across: float, height: float) -> Vector3:
		return Vector3(along, y + height, mid + across) if along_x else Vector3(mid + across, y + height, along)
	var box := func(long: float, high: float, across: float) -> Vector3:
		return Vector3(long, high, across) if along_x else Vector3(across, high, long)
	if bool(options.get("ribs", true)):
		for i in range(1, count):
			var at := from + i * bay
			for side in sides:
				if _wall_free(room, side, at - 0.3, at + 0.3):
					_face_box(room, side, "plate", at - 0.16, at + 0.16, 0.0, tall, -0.2, -0.05, steel)
			_part("plate", spot.call(at, 0.0, tall - 0.16), box.call(0.3, 0.32, wide), steel)
	var color: Color = options.get("light", Color("d6e8ff"))
	var energy := float(options.get("energy", 2.4))
	var reach := float(options.get("reach", maxf(9.0, bay * 1.6)))
	var lit := maxi(1, int(options.get("lit", 1)))
	var dead: Array = options.get("dead", [])
	var fail: Array = options.get("fail", [])
	var long := minf(2.4, bay - 1.4)
	var across := clampf(wide * 0.3, 1.0, 2.4)
	var kept := glow_key
	if options.has("glow"):
		_own_glow(str(options.glow))
		glow_key = str(options.glow)
	for i in range(count):
		var at := from + (i + 0.5) * bay
		_part("plate", spot.call(at, 0.0, tall - 0.05), box.call(long + 0.24, 0.1, across + 0.24), Color("0e1012"))
		for edge in [-1.0, 1.0]:
			var tube: Vector3 = spot.call(at, edge * across * 0.28, tall - 0.115)
			if dead.has(i):
				_part("plain", tube, box.call(long, 0.03, 0.14), Color("34383a"))
			else:
				_glow_box(tube, box.call(long, 0.03, 0.14), color, 2.4 if fail.has(i) else 5.5)
		if not dead.has(i) and (i % lit == 0 or fail.has(i)):
			var lamp := _light(spot.call(at, 0.0, tall - minf(1.0, tall * 0.2)), color, energy * (0.75 if fail.has(i) else 1.0), reach, false, 0.8 if fail.has(i) else float(options.get("flicker", 0.0)), 0.35, LAMP_FADE)
			lamp.omni_attenuation = 0.9
	glow_key = kept
	for line in options.get("lines", []):
		_stripe(spot.call(from + 0.1, float(line[0]), 0.0), spot.call(to - 0.1, float(line[0]), 0.0), float(line[2]) if line.size() > 2 else 0.12, line[1])
	var tray := int(options.get("tray", sides[0]))
	if tray >= 0:
		var off := (1.0 if tray == sides[1] else -1.0) * (wide * 0.5 - 0.55)
		_part("plate", spot.call((from + to) * 0.5, off, tall - 0.63), box.call(to - from, 0.05, 0.46), Color("2b2f31"))
		for k in range(3):
			_pipe(spot.call(from, off + (k - 1) * 0.13, tall - 0.56), spot.call(to, off + (k - 1) * 0.13, tall - 0.56), 0.035, [Color("17191b"), Color("5d2f22"), Color("2b3a4a")][k], 6)
		for i in range(count):
			_part("plate", spot.call(from + (i + 0.5) * bay + long * 0.5 + 0.5, off, tall - 0.33), box.call(0.04, 0.55, 0.5), Color("2b2f31"))

## Big stencilled lettering on a side of a room, its middle `high` above the floor.
func _stencil(room_id: String, side: int, a: float, high: float, text: String, size: int = 150, color: Color = Color(0.11, 0.13, 0.14)) -> Label3D:
	return _wall_sign(text, _face_point(room_of[room_id], side, a, high, -0.058), size, color, _model_yaw(side))

## Lettering painted on a floor; `yaw` 0 is read by somebody who looks north.
func _floor_text(text: String, pos: Vector3, size: int, color: Color, yaw: float = 0.0) -> Label3D:
	var label := lettering(text, pos + Vector3(0, 0.012, 0), size, color)
	label.rotation = Vector3(-PI / 2, yaw, 0)
	label.shaded = true
	label.outline_size = 0
	return label

## An arrow of paint on a floor, pointing along `yaw` (0 points north).
func _floor_arrow(pos: Vector3, yaw: float, color: Color, long: float = 1.1) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, 0.004, 0))
	_placed(frame, "plain", Vector3(0, 0, long * 0.12), Vector3(0.16, 0.008, long * 0.76), color)
	for edge in [-1.0, 1.0]:
		_placed(frame, "plain", Vector3(edge * 0.2, 0, -long * 0.28), Vector3(0.16, 0.008, 0.62), color, Vector3(0, edge * 42.0, 0))

## A plate beside a doorway that says what lies behind it: a number and a name.
func _door_tag(room_id: String, side: int, at: float, code: String, title: String, color: Color = Color("cfe6ff")) -> void:
	var room: Dictionary = room_of[room_id]
	_face_box(room, side, "plate", at - 0.36, at + 0.36, 1.46, 1.94, -0.052, -0.04, Color("121416"))
	_face_box(room, side, "plain", at - 0.36, at + 0.36, 1.9, 1.94, -0.058, -0.052, color.darkened(0.2))
	var number := _wall_sign(code, _face_point(room, side, at, 1.74, -0.06), 26, color, _model_yaw(side))
	number.name = "DoorTag"
	_wall_sign(title, _face_point(room, side, at, 1.56, -0.06), 13, Color(0.75, 0.78, 0.8), _model_yaw(side))

## Corner posts where a passage runs into another without a wall between them: the walls
## of the two meet in a point there, and behind it is nothing.
func _corner_post(pos: Vector3, tall: float) -> void:
	_part("plate", pos + Vector3(0, tall * 0.5, 0), Vector3(0.56, tall, 0.56), Color("1c2023"))
	_solid(pos + Vector3(0, tall * 0.5, 0), Vector3(0.56, tall, 0.56), false)

## A display with the plan of the Hive (see HiveDisplay), `wide` metres across, on which
## the cell `here` is marked. Kinds: "wall" (`pos` is the middle of the screen on the face
## of a wall, which looks along `yaw`), "stele" (`pos` is where it stands on a floor) and
## "hang" (`pos` is the middle of the screen, hung `drop` metres under a ceiling; it can be
## read from both sides).
func _display(pos: Vector3, yaw: float, wide: float, here: String, kind: String = "wall", drop: float = 0.5) -> void:
	var tall := wide * 9.0 / 16.0
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	var steel := Color("14171a")
	var front := 0.096
	match kind:
		"stele":
			frame = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, 1.05 + tall * 0.5, 0))
			front = 0.106
			_placed(frame, "plate", Vector3.ZERO, Vector3(wide + 0.2, tall + 0.2, 0.2), steel)
			for edge in [-1.0, 1.0]:
				_placed(frame, "plate", Vector3(edge * wide * 0.36, -(tall * 0.5 + 0.575), 0), Vector3(0.14, 0.95, 0.14), steel)
			_placed(frame, "plate", Vector3(0, -(tall * 0.5 + 1.02), 0), Vector3(wide * 0.9, 0.06, 0.7), steel)
			_solid(pos + Vector3(0, (1.15 + tall) * 0.5, 0), Vector3(wide + 0.2, 1.15 + tall, 0.3), true, yaw)
		"hang":
			front = 0.106
			_placed(frame, "plate", Vector3.ZERO, Vector3(wide + 0.2, tall + 0.2, 0.2), steel)
			for edge in [-1.0, 1.0]:
				_placed(frame, "plate", Vector3(edge * wide * 0.4, tall * 0.5 + 0.1 + drop * 0.5, 0), Vector3(0.06, drop, 0.06), steel)
		_:
			_placed(frame, "plate", Vector3(0, 0, 0.045), Vector3(wide + 0.16, tall + 0.16, 0.09), steel)
	var faces := [0.0, PI] if kind == "hang" else [0.0]
	for turn in faces:
		var side := frame * Transform3D(Basis(Vector3.UP, turn), Vector3.ZERO)
		var screen: MeshInstance3D = plan.call("screen", here, wide)
		screen.transform = side * Transform3D(Basis.IDENTITY, Vector3(0, 0, front))
		add_child(screen)
		_glow_box(side * Vector3(0, -(tall * 0.5 + 0.05), front - 0.003), Vector3(wide * 0.6, 0.014, 0.012), Color("59d8e6"), 2.2, side.basis)
		_light(side * Vector3(0, 0, front + 0.8), Color("6fd0e2"), 0.22 * wide, 2.6 + wide, false, 0.0, 0.2, LAMP_FADE)

## A board of directions on a side of a room: dark, one line for every way, each with a
## chip in the colour that leads there ([text, colour]).
func _sign_board(room_id: String, side: int, a: float, high: float, lines: Array, wide: float = 3.6, size: int = 30) -> void:
	var room: Dictionary = room_of[room_id]
	var row := size * 0.0125
	var tall := lines.size() * row + 0.14
	# (Along a south or a west wall the numbers grow to the reader's left.)
	var left := 1.0 if side == SOUTH or side == WEST else -1.0
	_face_box(room, side, "plate", a - wide * 0.5, a + wide * 0.5, high - tall * 0.5, high + tall * 0.5, -0.06, -0.04, Color("101214"))
	for i in range(lines.size()):
		var y := high + tall * 0.5 - 0.07 - (i + 0.5) * row
		var chip := a + left * (wide * 0.5 - 0.15)
		_face_box(room, side, "plain", chip - 0.06, chip + 0.06, y - row * 0.32, y + row * 0.32, -0.066, -0.06, lines[i][1])
		_wall_sign(str(lines[i][0]), _face_point(room, side, a - left * 0.1, y, -0.068), size, Color(0.86, 0.9, 0.94), _model_yaw(side))

## A cubicle wall between two points of a floor.
func _partition(from: Vector3, to: Vector3, tall: float = 1.3, cloth: Color = Color(0.36, 0.4, 0.45)) -> void:
	var span := to - from
	var long := span.length()
	var yaw := atan2(-span.z, span.x)
	var frame := Transform3D(Basis(Vector3.UP, yaw), (from + to) * 0.5)
	_placed(frame, "cloth", Vector3(0, tall * 0.5 + 0.03, 0), Vector3(long, tall - 0.06, 0.05), _vary(cloth, 0.02))
	_placed(frame, "steel", Vector3(0, tall + 0.015, 0), Vector3(long + 0.02, 0.03, 0.07), Color("8a9094"))
	for edge in [-1.0, 1.0]:
		_placed(frame, "steel", Vector3(edge * (long * 0.5 - 0.03), 0.03, 0), Vector3(0.06, 0.06, 0.4), Color("2a2e31"))
	_solid((from + to) * 0.5 + Vector3(0, tall * 0.5, 0), Vector3(long, tall, 0.08), true, yaw)

## Paper strewn over a floor around a spot.
func _litter(centre: Vector3, spread: float, count: int) -> void:
	_papers(Transform3D(Basis(Vector3.UP, random.randf() * TAU), centre + Vector3(0, 0.005, 0)), Vector3.ZERO, count, spread)

## A blot on a floor: old blood, soot. `long` and `wide` are its half axes, along `yaw`.
func _blot(pos: Vector3, long: float, wide: float, color: Color = Color(0.2, 0.015, 0.012, 0.76), yaw: float = 0.0) -> void:
	var kept := batch
	_chunk("Stains", false)
	batch.ellipsoid(mats["stain"], pos + Vector3(0, 0.012, 0), Vector3(long, 0.002, wide), color, Basis(Vector3.UP, yaw), 12, 3)
	for i in range(3):
		var turn := random.randf() * TAU
		var off := Vector3(cos(turn) * long * random.randf_range(0.5, 1.2), 0.013 + i * 0.002, sin(turn) * wide * random.randf_range(0.5, 1.2))
		batch.ellipsoid(mats["stain"], pos + Basis(Vector3.UP, yaw) * off, Vector3(long, 0.002, wide) * random.randf_range(0.2, 0.45), Color(color.r, color.g, color.b, color.a * 0.8), Basis(Vector3.UP, random.randf() * TAU), 10, 3)
	batch = kept

## Old blood dragged over a floor from one spot to another.
func _smear(from: Vector3, to: Vector3, wide: float = 0.3) -> void:
	var span := to - from
	var yaw := atan2(-span.z, span.x)
	var steps := maxi(2, roundi(span.length() / 0.9))
	for i in range(steps):
		var at := from.lerp(to, (i + 0.5) / steps) + Vector3(random.randf_range(-0.12, 0.12), 0, random.randf_range(-0.12, 0.12))
		_blot(at, span.length() / steps * random.randf_range(0.5, 0.75), wide * random.randf_range(0.6, 1.1), Color(0.2, 0.015, 0.012, random.randf_range(0.45, 0.75)), yaw)

## A steel bench whose seat faces local +z.
func _bench(pos: Vector3, yaw: float, long: float = 1.8) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "steel", Vector3(0, 0.44, 0), Vector3(long, 0.05, 0.42), Color("7d8488"))
	_placed(frame, "steel", Vector3(0, 0.8, -0.2), Vector3(long, 0.3, 0.04), Color("7d8488"))
	for edge in [-1.0, 1.0]:
		_placed(frame, "steel", Vector3(edge * (long * 0.5 - 0.12), 0.2075, 0), Vector3(0.05, 0.415, 0.4), Color("2a2e31"))
		_placed(frame, "steel", Vector3(edge * (long * 0.5 - 0.12), 0.56, -0.228), Vector3(0.05, 0.7, 0.03), Color("2a2e31"))
	_solid(pos + Vector3(0, 0.45, 0), Vector3(long, 0.9, 0.46), true, yaw)

## Furniture thrown together to stop something: `long` metres of it around a spot.
func _barricade(centre: Vector3, yaw: float, long: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), centre)
	var count := maxi(2, roundi(long / 1.5))
	for i in range(count):
		var x := -long * 0.5 + (i + 0.5) * long / count
		match i % 3:
			0:
				# A table on its edge, its legs towards whoever built this.
				_placed(frame, "steel", Vector3(x, 0.41, 0.1), Vector3(1.45, 0.8, 0.06), _vary(Color("5d6468"), 0.03), Vector3(random.randf_range(-7, 7), random.randf_range(-6, 6), 0))
				for leg in [-0.6, 0.6]:
					_placed(frame, "steel", Vector3(x + leg, 0.42, -0.25), Vector3(0.05, 0.05, 0.7), Color("3a4044"))
			1:
				# A cabinet on its back, another thing on top.
				_placed(frame, "steel", Vector3(x, 0.27, 0), Vector3(1.4, 0.52, 0.56), _vary(Color("4a5a66"), 0.03), Vector3(0, random.randf_range(-9, 9), 0))
				_placed(frame, "cloth", Vector3(x + 0.1, 0.72, 0.02), Vector3(0.9, 0.36, 0.44), _vary(Color("5a4a36"), 0.04), Vector3(0, random.randf_range(-20, 20), random.randf_range(-6, 6)))
			_:
				_placed(frame, "siding", Vector3(x, 0.36, -0.05), Vector3(1.0, 0.72, 0.8), _vary(Color("4d5a46"), 0.04), Vector3(0, random.randf_range(-14, 14), 0))
				_placed(frame, "steel", Vector3(x - 0.1, 0.95, 0.0), Vector3(0.5, 0.45, 0.5), _vary(Color("3c4246"), 0.03), Vector3(random.randf_range(-12, 12), random.randf_range(-30, 30), 0))
	_solid(centre + Vector3(0, 0.55, 0), Vector3(long, 1.1, 0.8), true, yaw)

## A plant in a pot (somebody watered them until a few days ago).
func _plant(pos: Vector3, tall: float = 1.3) -> void:
	_model("potted_plant_04" if random.randf() < 0.6 else "potted_plant_02", pos, random.randf() * TAU, {"height": tall, "solid": false, "far": 40.0})
	_round_solid(pos, 0.22, 0.8)

## An office machine against a side of a room: a copier, a printer, a water cooler.
func _machine(room_id: String, side: int, a: float, kind: String = "copier") -> void:
	var room: Dictionary = room_of[room_id]
	match kind:
		"cooler":
			_face_box(room, side, "plain", a - 0.18, a + 0.18, 0.0, 1.0, -0.42, -0.06, Color("c9ccc8"))
			_face_box(room, side, "plain", a - 0.13, a + 0.13, 1.0, 1.42, -0.37, -0.11, Color(0.5, 0.68, 0.8))
			_face_box(room, side, "plain", a - 0.08, a + 0.08, 0.62, 0.74, -0.44, -0.42, Color("1b1d1f"))
			_solid(_face_centre(room, side, a - 0.2, a + 0.2, 0.0, 1.4, -0.44, 0.0), _face_size(side, a - 0.2, a + 0.2, 0.0, 1.4, -0.44, 0.0))
		_:
			_face_box(room, side, "plain", a - 0.5, a + 0.5, 0.0, 0.96, -0.72, -0.06, Color("b9bcb6"))
			_face_box(room, side, "plain", a - 0.53, a + 0.53, 0.96, 1.06, -0.76, -0.04, Color("2a2d30"))
			_face_box(room, side, "plain", a - 0.44, a + 0.3, 0.3, 0.42, -0.9, -0.72, Color("a8aba5"))
			_face_glow(room, side, a + 0.1, a + 0.42, 1.062, 1.068, -0.6, -0.5, Color("7fe0a0"), 2.6)
			_solid(_face_centre(room, side, a - 0.53, a + 0.53, 0.0, 1.06, -0.76, 0.0), _face_size(side, a - 0.53, a + 0.53, 0.0, 1.06, -0.76, 0.0))

## A board on a side of a room: white with what was written on it last, or cork.
func _board(room_id: String, side: int, a: float, wide: float = 2.4, cork: bool = false) -> void:
	var room: Dictionary = room_of[room_id]
	_face_box(room, side, "steel", a - wide * 0.5 - 0.04, a + wide * 0.5 + 0.04, 0.96, 2.24, -0.058, -0.04, Color("8a9094"))
	_face_box(room, side, "plain", a - wide * 0.5, a + wide * 0.5, 1.0, 2.2, -0.066, -0.058, Color(0.52, 0.4, 0.26) if cork else Color(0.9, 0.91, 0.9))
	var slots := 5 if cork else 3
	for i in range(slots):
		var at := a - wide * 0.42 + (i + 0.5) * wide * 0.84 / slots
		var y := random.randf_range(1.3, 1.9) if cork else 1.3 + i * 0.28
		if cork:
			_face_box(room, side, "plain", at - 0.105, at + 0.105, y - 0.148, y + 0.148, -0.072, -0.066, _vary(Color("d8d5c8"), 0.06))
		else:
			_face_box(room, side, "plain", at - random.randf_range(0.1, 0.3), at + 0.3, y - 0.012, y + 0.012, -0.072, -0.066, [Color("1c3f8a"), Color("a02a22"), Color("1b1d1f")][i % 3])

# ---------------------------------------------------------------- the way down

func _lay_descent() -> void:
	_begin_zone("descent", "under", ["house"])
	area = "descent"
	_own_dice(71003)
	_room("vestibule", ground, Rect2(-2.5, -9, 5, 5), 3.2, "concrete")
	_door("dining", "vestibule", 0.0, 2.0, {"kind": "gate", "area": "descent", "name": "mirror", "leaf": "panel", "height": 2.6})
	_opening("vestibule", NORTH, 0.0, 2.4, {"kind": "join", "height": 2.9, "nav": false})
	_room("stair_lobby", under, Rect2(-3, -35, 6, 6.2), 3.2, "concrete")
	_opening("stair_lobby", SOUTH, 0.0, 2.4, {"kind": "join", "height": 2.9, "nav": false})
	_chunk("Stairs", false)
	var top := Vector3(0, 0, -9.4)
	var rest_a := Vector3(0, UNDER * 0.5, -17.7)
	var rest_b := Vector3(0, UNDER * 0.5, -20.3)
	var bottom := Vector3(0, UNDER, -28.6)
	var grey := Color(0.7, 0.7, 0.68)
	var wall := Color(0.62, 0.62, 0.6)
	_steps(rest_a, top, 2.4, "betonfloor", grey)
	_steps(bottom, rest_b, 2.4, "betonfloor", grey)
	_part("betonfloor", Vector3(0, UNDER * 0.5 - 0.3, -19.0), Vector3(2.4, 0.6, 2.6), grey)
	_solid(Vector3(0, UNDER * 0.5 - 0.3, -19.0), Vector3(2.4, 0.6, 2.6), false)
	# The floors of the two rooms reach the first and the last step.
	for sill in [Vector3(0, -0.15, -9.225), Vector3(0, UNDER - 0.15, -28.625)]:
		_part("betonfloor", sill, Vector3(2.4, 0.3, 0.45 if sill.y > -1.0 else 0.35), grey)
		_solid(sill, Vector3(2.4, 0.3, 0.5), false)
	for side in [-1.0, 1.0]:
		# Above the ground the annex behind the house; below it the shaft.
		_part("formwork", Vector3(side * 1.4, 0.05, -12.1), Vector3(0.4, 6.5, 6.2), wall)
		_solid(Vector3(side * 1.4, 0.05, -12.1), Vector3(0.4, 6.5, 6.2), false)
		_part("formwork", Vector3(side * 1.4, -5.35, -22.0), Vector3(0.4, 10.1, 13.6), wall)
		_solid(Vector3(side * 1.4, -5.35, -22.0), Vector3(0.4, 10.1, 13.6), false)
		_handrail(rest_a, top, side * 1.05)
		_handrail(bottom, rest_b, side * 1.05)
		_register(Vector3(side * 1.4, 1.5, -12.1), Vector3(0.4, 3.0, 6.2))
	# Nobody walks over the stairwell on the lawn.
	_register(Vector3(0, 0.5, -12.2), Vector3(2.4, 1.0, 6.0))
	_part("formwork", Vector3(0, 1.5, -15.35), Vector3(3.2, 3.6, 0.3), wall)
	_solid(Vector3(0, 1.5, -15.35), Vector3(3.2, 3.6, 0.3))
	_part("beton", Vector3(0, 3.4, -12.1), Vector3(3.5, 0.2, 6.6), Color(0.5, 0.5, 0.5))
	# The ceilings follow the flights.
	for flight in [[rest_a, top], [bottom, rest_b]]:
		var low: Vector3 = flight[0]
		var high: Vector3 = flight[1]
		var slope := _slope_basis(low, high)
		batch.box(mats["beton"], (low + high) * 0.5 + Vector3(0, 2.75, 0), Vector3(3.2, 0.3, low.distance_to(high) + 0.7), Color(0.5, 0.5, 0.5), slope)
		_add_shape(body, (low + high) * 0.5 + Vector3(0, 2.75, 0), Vector3(3.2, 0.3, low.distance_to(high) + 0.7), slope)
	_part("beton", Vector3(0, UNDER * 0.5 + 2.75, -19.0), Vector3(3.2, 0.3, 3.4), Color(0.5, 0.5, 0.5))
	for spot in [[Vector3(1.16, 0.55, -11.6), 0.0], [Vector3(-1.16, -1.3, -14.2), 0.0], [Vector3(-1.16, -2.6, -16.6), 0.0], [Vector3(1.16, -2.8, -19.0), 0.25], [Vector3(-1.16, -5.6, -23.0), 0.0], [Vector3(1.16, -7.6, -27.0), 0.0]]:
		var at: Vector3 = spot[0]
		_part("plate", at, Vector3(0.1, 0.24, 0.2), Color("1b1c1b"))
		_glow_box(at - Vector3(signf(at.x) * 0.07, 0, 0), Vector3(0.06, 0.16, 0.12), Color("ffe2b0"), 4.5)
		_light(at - Vector3(signf(at.x) * 0.5, 0, 0), Color("ffe2b0"), 1.3, 7.0, false, float(spot[1]), 0.5, LAMP_FADE)
	# Whose stairs these are: the name on the wall, where they lead, and the cables that
	# run down with them.
	_wall_sign("HELIX", Vector3(-1.192, -0.45, -13.0), 120, Color(0.17, 0.18, 0.19), PI / 2)
	_wall_sign("▼   BAHNHOF  U1", Vector3(-1.192, -5.55, -24.4), 84, Color(0.5, 0.4, 0.1), PI / 2)
	for run in [[0.0, Color("17191b"), 0.035], [0.11, Color("5d2f22"), 0.025]]:
		var lift := Vector3(1.13, 2.25 + float(run[0]), 0)
		for leg in [[top, rest_a], [rest_a, rest_b], [rest_b, bottom]]:
			_pipe((leg[0] as Vector3) + lift, (leg[1] as Vector3) + lift, float(run[2]), run[1], 6)
	_link(PackedVector3Array([Vector3(0, UNDER, -29.5), bottom, rest_b, rest_a, top, Vector3(0, 0, -8.0)]), 2.4, under, ground, "descent")
	_wall_sign("HELIX  ·  ZUTRITT NUR MIT FREIGABE", Vector3(0, 3.04, -8.78), 14, Color("c9a227"))
	var plate := _wall_sign("EBENE  U1  ·  BAHNHOF", Vector3(0, UNDER + 2.88, -34.78), 16, Color("c9a227"))
	plate.name = "LevelSign"
	_shared_dice()
	_end_zone()

# ---------------------------------------------------------------- the station

func _lay_station() -> void:
	_own_dice(71004)
	_begin_zone("train_a", "sodium")
	area = "station"
	_room("car_a", under, Rect2(-7, -59, 14, 4), 2.6, "car", {"walls": false, "floor": false, "ceiling": false, "lamps": "none"})
	_train_car(Vector3(0, UNDER, -57), SOUTH)
	_end_zone()
	_begin_zone("station", "sodium", ["descent", "train_a"])
	_room("platform", under, Rect2(-40, -55, 80, 20), 7.5, "station", {"bare": [NORTH]})
	_door("stair_lobby", "platform", 0.0, 2.2, {"kind": "gate", "area": "station", "name": "steel"})
	_door("car_a", "platform", 0.0, 2.4, {"kind": "script", "name": "car_a", "height": 2.2})
	_room("track_a", under, Rect2(-40, -62, 80, 7), 7.5, "station", {"bare": [SOUTH], "nav": false, "floor": false, "lamps": "none"})
	for side in [WEST, EAST]:
		_opening("track_a", side, -57.0, 5.4, {"kind": "join", "height": 4.6, "nav": false})
	_room("booth", under, Rect2(24, -35, 12, 7), 3.2, "panel")
	_door("platform", "booth", 26.5, 2.0, {"kind": "slide"})
	_pane("platform", SOUTH, 31.5, 6.0, 1.0, 2.4, "glass", "booth")
	_room("depot", under, Rect2(40, -55, 14, 14), 4.5, "concrete")
	_door("platform", "depot", -48.0, 3.0)
	_room("workshop", under, Rect2(-54, -45, 14, 10), 4.0, "concrete")
	_door("platform", "workshop", -40.0, 2.4)
	area = "nadja"
	_room("airlock", under, Rect2(-54, -52, 14, 5), 3.0, "panel")
	_door("platform", "airlock", -49.5, 1.8, {"kind": "script", "name": "nadja"})
	for at in [-51.3, -47.7]:
		_pane("platform", WEST, at, 0.9, 0.9, 2.3, "glass", "airlock")
	area = "station"
	_chunk("Kit", false)
	_track("track_a", -55.0, 1.0)
	_train_ends(Vector3(0, UNDER, -57))
	# The edge of the platform stops everybody but where the car's doors are.
	for piece in [[-40.0, -1.4], [1.4, 40.0]]:
		_add_shape(rails, Vector3((float(piece[0]) + float(piece[1])) * 0.5, UNDER + 0.6, -54.9), Vector3(float(piece[1]) - float(piece[0]), 1.2, 0.1))
	for row in [-41.0, -49.0]:
		for i in range(9):
			var x := -32.0 + i * 8.0
			if absf(x) < 3.0 and row > -45.0:
				continue
			_pillar(Vector3(x, UNDER, row), 0.8, 7.5)
	var platform: Dictionary = room_of["platform"]
	for entry in [[-22.0, "GLEIS 1"], [22.0, "GLEIS 1"], [0.0, "HELIX TRANSIT  ·  N-01"]]:
		_part("plate", Vector3(float(entry[0]), UNDER + 5.2, -50.0), Vector3(5.0, 0.9, 0.12), Color("15181a"))
		var board := lettering(str(entry[1]), Vector3(float(entry[0]), UNDER + 5.2, -49.93), 60, Color("e8d9a0"))
		board.outline_size = 0
		_part("plain", Vector3(float(entry[0]) - 2.3, UNDER + 6.4, -50.0), Vector3(0.04, 1.6, 0.04), Color("101010"))
		_part("plain", Vector3(float(entry[0]) + 2.3, UNDER + 6.4, -50.0), Vector3(0.04, 1.6, 0.04), Color("101010"))
	_supply(Vector3(-14.0, UNDER, -35.7), Vector3(0, 0, -1), "DEPOT  ·  BAHNSTEIG")
	# The radio set of the station, beside the control room.
	_face_box(platform, SOUTH, "steel", 19.6, 22.4, 0.0, 2.0, -0.6, 0.0, Color("2c3236"))
	_model("vintage_radio_transceiver", Vector3(21.0, UNDER + 2.0, -35.5), PI, {"width": 0.9, "solid": false, "far": 40.0})
	_solid(Vector3(21.0, UNDER + 1.0, -35.5), Vector3(2.8, 2.0, 0.6))
	for k in range(5):
		_led(Vector3(19.9 + k * 0.5, UNDER + 1.6, -35.81), Vector3(0.06, 0.06, 0.01), [Color("5ee07a"), Color("ffb347"), Color("ff3a2a")][k % 3], 3.0, 0.4 + k * 0.1)
	_display(Vector3(5.2, UNDER, -40.4), 0.0, 2.4, "station", "stele")
	_stores(Vector3(-30.0, UNDER, -38.0), 5)
	_stores(Vector3(12.0, UNDER, -38.2), 4)
	_stores(Vector3(33.0, UNDER, -52.0), 3)
	_model("hand_truck", Vector3(8.5, UNDER, -37.0), 0.6, {"far": 40.0})
	_model("industrial_storage_cart", Vector3(-24.0, UNDER, -46.0), 0.3, {"far": 50.0})
	_dress_station()
	# --- the control room: the desk that brings the train up
	_console("booth", NORTH, 28.6, 34.4, [1, 3, 5])
	_lockers("booth", EAST, -33.6, -29.2)
	_desk(Vector3(27.0, UNDER, -29.4), 0.0, 4)
	# --- the depot, the workshop, the way Nadja takes
	_stores(Vector3(44.0, UNDER, -44.0), 5)
	_stores(Vector3(50.5, UNDER, -51.0), 5)
	_stores(Vector3(51.0, UNDER, -44.0), 3)
	_against("depot", EAST, -47.0, "steel_frame_shelves_01", {"height": 2.3})
	_against("workshop", WEST, -40.0, "steel_frame_shelves_01", {"height": 2.3})
	_against("workshop", NORTH, -47.0, "metal_tool_chest", {"scale": 1.5})
	_table(Vector3(-46.0, UNDER, -37.0), Vector3(2.6, 0.9, 0.9), Color("3c4246"))
	_stores(Vector3(-50.5, UNDER, -42.5), 3)
	var airlock: Dictionary = room_of["airlock"]
	if not _sealed_door("airlock", WEST, -49.5):
		_face_box(airlock, WEST, "cladding", -50.5, -48.5, 0.0, 2.3, -0.06, 0.0, Color(0.5, 0.53, 0.55))
		_face_glow(airlock, WEST, -49.7, -49.3, 2.36, 2.42, -0.03, 0.0, Color("ff3a2a"), 3.0)
	_shared_dice()
	_end_zone()

# ---------------------------------------------------------------- the terminal

func _lay_terminal() -> void:
	_own_dice(71005)
	_begin_zone("train_b", "cold")
	area = ""
	_room("car_b", deep, Rect2(-7, -319, 14, 4), 2.6, "car", {"walls": false, "floor": false, "ceiling": false, "lamps": "none"})
	_train_car(Vector3(0, UNDER, -317), NORTH)
	_end_zone()
	_begin_zone("terminal", "cold", ["train_b"])
	_room("terminal", deep, Rect2(-40, -345, 80, 26), 9.5, "bighall", {"bare": [SOUTH]})
	_door("car_b", "terminal", 0.0, 2.4, {"kind": "script", "name": "car_b", "height": 2.2})
	_room("track_b", deep, Rect2(-40, -319, 80, 7), 9.5, "bighall", {"bare": [NORTH], "nav": false, "floor": false, "lamps": "none"})
	for side in [WEST, EAST]:
		_opening("track_b", side, -317.0, 5.4, {"kind": "join", "height": 4.6, "nav": false})
	_room("term_deck", deck, Rect2(-40, -345, 62, 4), 4.0, "bighall", {"walls": false, "floor": false, "ceiling": false, "lamps": "none"})
	_room("control", deck, Rect2(22, -345, 18, 6), 3.0, "panel", {"bare": [NORTH, EAST]})
	_door("term_deck", "control", -343.0, 1.6, {"kind": "slide"})
	_pane("control", SOUTH, 31.0, 15.0, 0.9, 2.5, "glass")
	_chunk("Kit", false)
	_track("track_b", -319.0, -1.0)
	_train_ends(Vector3(0, UNDER, -317))
	for piece in [[-40.0, -1.4], [1.4, 40.0]]:
		_add_shape(rails, Vector3((float(piece[0]) + float(piece[1])) * 0.5, UNDER + 0.6, -319.1), Vector3(float(piece[1]) - float(piece[0]), 1.2, 0.1))
	_deck_floor(Rect2(-39.8, -344.8, 61.8, 3.8), DECK, UNDER, [[SOUTH, -39.8, -27.1], [SOUTH, -24.9, 22.0]])
	for x in [-36.0, -18.0, -8.0, 8.0, 18.0]:
		_part("plate", Vector3(x, UNDER + 1.95, -341.2), Vector3(0.24, 3.9, 0.24), Color("1d2124"))
		_solid(Vector3(x, UNDER + 1.95, -341.2), Vector3(0.24, 3.9, 0.24))
	for x in [24.0, 38.0]:
		_part("plate", Vector3(x, UNDER + 1.95, -339.3), Vector3(0.3, 3.9, 0.3), Color("1d2124"))
		_solid(Vector3(x, UNDER + 1.95, -339.3), Vector3(0.3, 3.9, 0.3))
	_deck_stairs(Vector3(-26, UNDER, -333.7), Vector3(-26, DECK, -341.0), deep, deck, Vector3(-26, UNDER, -333.0), Vector3(-26, DECK, -342.0))
	_console("control", SOUTH, 25.0, 37.0, [3, 1, 5, 4])
	_desk(Vector3(36.5, DECK, -343.0), PI / 2, 2)
	for row in [-326.0, -334.0]:
		for x in [-30.0, -15.0, 15.0, 30.0]:
			_pillar(Vector3(x, UNDER, row), 0.9, 9.5)
	_stores(Vector3(-33.0, UNDER, -324.0), 5)
	_stores(Vector3(22.0, UNDER, -326.0), 5)
	_stores(Vector3(34.0, UNDER, -336.0), 4)
	_stores(Vector3(-10.0, UNDER, -338.0), 3)
	_display(Vector3(-5.6, UNDER, -336.0), 0.0, 3.0, "terminal", "stele")
	_dress_terminal()
	_model("industrial_storage_cart", Vector3(9.0, UNDER, -330.0), 1.2, {"far": 50.0})
	_part("plate", Vector3(0, UNDER + 4.6, -344.6), Vector3(10.0, 1.1, 0.12), Color("15181a"))
	var head := lettering("FORSCHUNGSTERMINAL  ·  SEKTOR  B", Vector3(0, UNDER + 4.6, -344.52), 54, Color("cfe6ff"))
	head.outline_size = 0
	_stripe(Vector3(-3.0, UNDER, -344.0), Vector3(-3.0, UNDER, -322.0), 0.16, Color("c9a227"))
	_stripe(Vector3(3.0, UNDER, -344.0), Vector3(3.0, UNDER, -322.0), 0.16, Color("c9a227"))
	_shared_dice()
	_end_zone()
	# --- what passes the windows on the way: a tunnel that is only there during the ride
	_begin_zone("tunnel", "under")
	_chunk("Tube", false)
	for wall in [-1.0, 1.0]:
		_part("beton", Vector3(0, UNDER + 1.4, -317.0 + wall * 3.0), Vector3(70.0, 5.2, 0.3), Color(0.2, 0.2, 0.2))
	_part("beton", Vector3(0, UNDER + 4.1, -317.0), Vector3(70.0, 0.3, 6.4), Color(0.18, 0.18, 0.18))
	for index in range(8):
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 1.4, 0.06)
		bar.mesh = mesh
		bar.material_override = _glow_material(Color("ffd9a0"), 5.0)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.position = Vector3(-35.0 + index * 8.75, UNDER + 1.9, -317.0 + (2.8 if index % 2 == 0 else -2.8))
		var glow := OmniLight3D.new()
		glow.light_color = Color("ffd9a0")
		glow.light_energy = 2.4
		glow.omni_range = 7.0
		glow.position = Vector3(0, 0, -0.4 if index % 2 == 0 else 0.4)
		bar.add_child(glow)
		add_child(bar)
		ride_lamps.append(bar)
	_end_zone()

# ---------------------------------------------------------------- offices and corridors

func _lay_admin() -> void:
	_own_dice(71006)
	_begin_zone("admin", "cold", ["terminal"])
	area = "admin"
	var blue: Color = GUIDE.admin
	var red: Color = GUIDE.security
	var gold: Color = GUIDE.cafe
	_room("checkpoint", deep, Rect2(-6, -361, 12, 16), 5.0, "panel", {"lamps": "none", "look": {"stripe": GUIDE.terminal}})
	_door("terminal", "checkpoint", 0.0, 6.0, {"kind": "gate", "area": "admin", "height": 3.6, "name": "gate_admin"})
	_room("guard", deep, Rect2(6, -361, 9, 12), 3.4, "panel", {"look": {"stripe": red}})
	_door("checkpoint", "guard", -358.5, 1.6, {"kind": "slide"})
	_pane("checkpoint", EAST, -353.5, 5.0, 1.0, 2.4, "glass", "guard")
	_room("scanner", deep, Rect2(-15, -361, 9, 12), 3.4, "panel", {"look": {"stripe": GUIDE.terminal}})
	_door("checkpoint", "scanner", -355.0, 2.0, {"kind": "slide"})
	# The ring: the main street of the administration, eight metres wide.
	_room("ring_s", deep, Rect2(-44, -369, 88, 8), 4.6, "panel", {"lamps": "none", "look": {"stripe": blue}})
	_door("checkpoint", "ring_s", 0.0, 4.0, {"kind": "slide", "leaf": "double"})
	_room("office", deep, Rect2(-44, -393, 28, 24), 3.6, "office", {"look": {"dead": 0.2, "stripe": blue}})
	_door("ring_s", "office", -38.0, 2.0, {"kind": "slide"})
	_door("ring_s", "office", -22.0, 2.0, {"kind": "slide"})
	_room("meeting", deep, Rect2(-16, -381, 12, 12), 3.6, "office", {"look": {"stripe": blue}})
	_door("ring_s", "meeting", -12.0, 2.0, {"kind": "slide"})
	_pane("ring_s", NORTH, -7.5, 4.0, 1.0, 2.4, "glass", "meeting")
	_room("copy", deep, Rect2(4, -385, 8, 16), 3.6, "office", {"look": {"stripe": red}})
	_door("ring_s", "copy", 8.0, 2.0, {"kind": "slide"})
	_room("security", deep, Rect2(12, -385, 18, 16), 3.8, "panel", {"look": {"light": Color("bcd2ff"), "energy": 1.1, "strip_color": Color("7fb0ff"), "stripe": red, "panel": Color(0.5, 0.53, 0.57)}})
	_door("ring_s", "security", 21.0, 2.0, {"kind": "slide"})
	_room("server", deep, Rect2(30, -393, 14, 24), 3.8, "panel", {"look": {"light": Color("7fb2ff"), "energy": 1.0, "floor": ["darkfloor", Color(0.5, 0.52, 0.56)], "stripe": red, "panel": Color(0.42, 0.45, 0.5), "strip_color": Color("5a9cff"), "strip_glow": 3.0}})
	_door("ring_s", "server", 37.0, 2.0, {"kind": "slide"})
	_door("security", "server", -377.0, 2.0, {"kind": "slide"})
	_room("archive", deep, Rect2(-44, -409, 20, 16), 3.6, "office", {"look": {"energy": 1.0, "dead": 0.34, "flicker": 0.25, "stripe": blue}})
	_door("office", "archive", -34.0, 2.0, {"kind": "slide"})
	_room("staff", deep, Rect2(-24, -405, 20, 12), 3.6, "office", {"look": {"stripe": blue}})
	_door("office", "staff", -20.0, 2.0, {"kind": "slide"})
	area = "cafe"
	_room("spine", deep, Rect2(-4, -405, 8, 36), 5.0, "panel", {"lamps": "none", "look": {"stripe": gold}})
	_door("ring_s", "spine", 0.0, 4.0, {"kind": "gate", "area": "cafe", "name": "gate_cafe", "height": 3.0})
	area = "admin"
	_chunk("Kit", false)
	# --- the way in: two lanes through scanner arches, a booth between them, a belt for
	# what people carried at either wall
	_passage("checkpoint", {"step": 5.2, "ribs": false, "tray": -1, "energy": 3.2, "reach": 11.0})
	for lane in [-2.9, 2.9]:
		for edge in [-1.4, 1.4]:
			var post := Vector3(lane + edge, UNDER, -350.0)
			_part("plate", post + Vector3(0, 1.25, 0), Vector3(0.3, 2.5, 0.9), Color("23282b"))
			_solid(post + Vector3(0, 1.25, 0), Vector3(0.3, 2.5, 0.9))
			_glow_box(post + Vector3(-signf(edge) * 0.155, 1.3, 0), Vector3(0.012, 1.7, 0.04), Color("7fe0a0"), 1.1)
		_part("plate", Vector3(lane, UNDER + 2.62, -350.0), Vector3(3.1, 0.26, 0.9), Color("23282b"))
		_glow_box(Vector3(lane, UNDER + 2.48, -350.0), Vector3(2.3, 0.03, 0.2), Color("7fe0a0"), 3.0)
		_floor_arrow(Vector3(lane, UNDER, -347.9), 0.0, Color("c9a227"))
	_desk(Vector3(0, UNDER, -350.3), PI, 4)
	for side in [-1.0, 1.0]:
		var belt := Vector3(side * 5.15, UNDER, -349.4)
		_part("steel", belt + Vector3(0, 0.42, 0), Vector3(0.9, 0.84, 3.2), Color("3a4146"))
		_part("plain", belt + Vector3(0, 0.85, 0), Vector3(0.74, 0.02, 3.1), Color("0e0f10"))
		_part("steel", belt + Vector3(0, 1.3, 0), Vector3(0.96, 0.9, 1.3), Color("4a5258"))
		for end in [-1.0, 1.0]:
			_part("plain", belt + Vector3(0, 1.17, end * 0.656), Vector3(0.7, 0.6, 0.012), Color("050606"))
		_led(belt + Vector3(-side * 0.485, 1.6, 0.4), Vector3(0.012, 0.05, 0.05), Color("5ee07a"), 3.0, 0.4)
		_solid(belt + Vector3(0, 0.9, 0), Vector3(0.96, 1.8, 3.2))
		_model("plastic_crate_02", belt + Vector3(0, 0.86, 1.15), 0.3 * side, {"scale": 1.1, "solid": false, "far": 30.0})
	_stripe(Vector3(-5.6, UNDER, -347.0), Vector3(5.6, UNDER, -347.0), 0.3, Color("c9a227"))
	_floor_text("KONTROLLE", Vector3(0, UNDER, -346.15), 110, Color("c9a227"))
	_sign_board("checkpoint", WEST, -348.4, 3.5, [["KONTROLLE  ·  AUSWEIS  BEREITHALTEN", GUIDE.terminal], ["VERWALTUNG  ·  KANTINE   ►", blue]], 4.8, 28)
	_stencil("checkpoint", EAST, -353.5, 3.75, "KONTROLLE", 120)
	_display(_face_point(room_of["checkpoint"], WEST, -352.4, 1.85, 0.0), _model_yaw(WEST), 2.0, "checkpoint")
	_model("cardboard_box_01", Vector3(-3.4, UNDER, -354.6), 0.7, {"scale": 1.3, "far": 30.0})
	_litter(Vector3(1.6, UNDER, -353.4), 1.3, 9)
	_smear(Vector3(2.9, UNDER, -352.0), Vector3(1.2, UNDER, -359.0), 0.3)
	# --- the guard room with the second supply point, and the room where bags were searched
	_supply(Vector3(14.3, UNDER, -355.0), Vector3(-1, 0, 0), "WACHRAUM")
	_desk(Vector3(8.0, UNDER, -352.4), -PI / 2, 4)
	_lockers("guard", NORTH, 9.0, 12.2, Color("3d4a54"))
	_lockers("scanner", WEST, -360.4, -356.0)
	_table(Vector3(-10.5, UNDER, -352.0), Vector3(3.0, 0.9, 1.0), Color("3c4246"))
	_model("plastic_crate_02", Vector3(-10.9, UNDER + 0.9, -352.0), 0.3, {"scale": 1.3, "solid": false, "far": 30.0})
	_model("plastic_crate_02", Vector3(-9.9, UNDER + 0.9, -352.1), 1.1, {"scale": 1.3, "solid": false, "far": 30.0})
	_shelf(Vector3(-10.6, UNDER, -360.5), 0.0, 4.0, 0.5, 2.0, 4, Color("4a5258"), 0.8)
	# --- the ring: a coffer of light in every bay, a line on the floor to every wing, a
	# plate at every door
	_passage("ring_s", {"step": 5.84, "energy": 2.3, "reach": 10.0, "dead": [3, 11], "fail": [12], "tray": SOUTH})
	for x in [-0.9, 0.9]:
		_stripe(Vector3(x, UNDER, -368.9), Vector3(x, UNDER, -361.1), 0.12, gold)
	_stripe(Vector3(-1.7, UNDER, -366.9), Vector3(-1.7, UNDER, -361.1), 0.12, blue)
	_stripe(Vector3(-42.5, UNDER, -366.9), Vector3(-1.7, UNDER, -366.9), 0.12, blue)
	_stripe(Vector3(1.7, UNDER, -366.9), Vector3(1.7, UNDER, -361.1), 0.12, red)
	_stripe(Vector3(1.7, UNDER, -366.9), Vector3(42.5, UNDER, -366.9), 0.12, red)
	for stub in [[-38.0, blue, "A-01", "BÜRO  WEST", 1.0], [-22.0, blue, "A-02", "BÜRO  OST", -1.0], [-12.0, blue, "A-03", "BESPRECHUNG", 1.0], [8.0, red, "A-04", "POSTSTELLE", 1.0], [21.0, red, "S-01", "SICHERHEIT", 1.0], [37.0, red, "S-02", "SERVER", 1.0]]:
		var door_x := float(stub[0])
		var tone: Color = stub[1]
		_stripe(Vector3(door_x, UNDER, -368.7), Vector3(door_x, UNDER, -366.9), 0.12, tone)
		_door_tag("ring_s", NORTH, door_x + 1.55 * float(stub[4]), str(stub[2]), str(stub[3]), tone.lightened(0.45))
	_sign_board("ring_s", NORTH, 0.0, 3.62, [["▲   KANTINE  ·  ZENTRALRAUM  B2", gold], ["◄   BÜROS  ·  ARCHIV  ·  PERSONAL", blue], ["SICHERHEIT  ·  SERVER   ►", red]], 5.4, 30)
	_stencil("ring_s", SOUTH, -11.7, 3.25, "B2", 220)
	_stencil("ring_s", SOUTH, 11.7, 3.25, "VERWALTUNG", 104)
	_floor_arrow(Vector3(-20.0, UNDER, -365.2), PI / 2, blue)
	_floor_arrow(Vector3(20.0, UNDER, -365.2), -PI / 2, red)
	_sealed_door("ring_s", WEST, -365.0)
	_sealed_door("ring_s", EAST, -365.0)
	_model("wheelchair_01", Vector3(-28.0, UNDER, -363.4), 2.2, {"far": 40.0})
	_model("metal_trash_can", Vector3(27.0, UNDER, -361.9), 0.0, {"height": 0.9, "far": 40.0})
	_plant(Vector3(-3.3, UNDER, -361.75), 1.3)
	_plant(Vector3(3.3, UNDER, -361.75), 1.3)
	_bench(Vector3(-17.5, UNDER, -361.55), PI, 2.4)
	_bench(Vector3(17.5, UNDER, -361.55), PI, 2.4)
	# Somebody tried to hold the east wing.
	_barricade(Vector3(30.5, UNDER, -366.3), PI / 2, 4.6)
	_blot(Vector3(28.6, UNDER, -364.2), 1.0, 0.7)
	_smear(Vector3(28.4, UNDER, -364.0), Vector3(22.4, UNDER, -367.6), 0.3)
	_blot(Vector3(32.2, UNDER, -366.0), 1.3, 0.9, Color(0.02, 0.02, 0.02, 0.7))
	_litter(Vector3(-9.0, UNDER, -364.5), 1.6, 8)
	_litter(Vector3(33.0, UNDER, -363.4), 1.4, 7)
	# --- the open office: desks in bays of cloth walls, some of them pushed over
	var office: Dictionary = room_of["office"]
	for row in range(3):
		var z := -374.0 - row * 6.0
		var away := 1.0 if row != 1 else -1.0
		for piece in [[-43.0, -32.6], [-29.9, -19.4]]:
			_partition(Vector3(float(piece[0]), UNDER, z + away * 0.72), Vector3(float(piece[1]), UNDER, z + away * 0.72))
		for wing in [-37.3, -24.5]:
			_partition(Vector3(wing, UNDER, z + away * 0.69), Vector3(wing, UNDER, z - away * 0.9), 1.2)
		for column in range(4):
			var at := Vector3(-40.5 + column * 6.4, UNDER, z)
			if (row * 4 + column) % 5 == 3:
				_table(at + Vector3(0.3, 0, -away * 0.5), Vector3(1.6, 0.76, 0.8), Color("5d6468"), 0.5)
				_office_chair(at + Vector3(-0.7, 0, -away * 1.7), 2.1 + column, true)
				_litter(at + Vector3(0.6, 0, -away * 1.5), 0.9, 7)
			else:
				_desk(at, PI if row != 1 else 0.0, 1 + (row + column) % 3)
	_lockers("office", WEST, -391.5, -385.0, Color("5d6468"))
	_model("modern_arm_chair_01", Vector3(-18.5, UNDER, -390.5), -0.8, {"far": 40.0})
	_machine("office", SOUTH, -30.0, "cooler")
	_machine("office", EAST, -374.5)
	_board("office", EAST, -388.0, 2.6)
	_board("office", WEST, -378.0, 2.2, true)
	_door_tag("office", NORTH, -32.45, "A-05", "ARCHIV", blue.lightened(0.45))
	_door_tag("office", NORTH, -21.55, "A-06", "PERSONAL", blue.lightened(0.45))
	_face_box(office, WEST, "plate", -372.6, -369.9, 1.25, 2.55, -0.06, -0.04, Color("0c0e0f"))
	_screen(Transform3D(Basis(Vector3.UP, PI / 2), _face_point(office, WEST, -371.25, 1.9, -0.066)), Vector3.ZERO, Vector2(2.5, 1.1), 2, 0.4)
	_plant(Vector3(-17.0, UNDER, -370.1), 1.4)
	_plant(Vector3(-43.0, UNDER, -392.0), 1.5)
	_office_chair(Vector3(-31.4, UNDER, -378.4), 0.6, true)
	_litter(Vector3(-31.2, UNDER, -376.0), 1.2, 9)
	_litter(Vector3(-22.0, UNDER, -389.5), 1.4, 9)
	_blot(Vector3(-27.5, UNDER, -390.2), 0.9, 0.6)
	_smear(Vector3(-28.4, UNDER, -390.4), Vector3(-33.4, UNDER, -392.2), 0.28)
	# --- the meeting room
	_carpet(Vector3(-10.0, UNDER, -375.5), Vector2(8.6, 4.8), Color(0.14, 0.18, 0.28))
	_table(Vector3(-10.0, UNDER, -375.5), Vector3(6.0, 0.76, 1.8), Color("3a3f44"))
	for i in range(4):
		_chair(Vector3(-12.3 + i * 1.5, UNDER, -374.2), PI, Color("23292d"))
		_chair(Vector3(-12.3 + i * 1.5, UNDER, -376.8), 0.0, Color("23292d"), i == 2)
	var meeting: Dictionary = room_of["meeting"]
	_face_box(meeting, NORTH, "plate", -11.45, -8.55, 1.12, 2.68, -0.054, -0.04, Color("0c0e0f"))
	_screen(Transform3D(Basis(Vector3.UP, 0.0), _face_point(meeting, NORTH, -10.0, 1.9, -0.06)), Vector3.ZERO, Vector2(2.6, 1.4), 8, 0.3)
	_board("meeting", WEST, -376.0, 2.6)
	_counter("meeting", EAST, -379.8, -377.2, Color(0.3, 0.33, 0.36), Color(0.6, 0.62, 0.63), 0.5)
	_plant(Vector3(-15.0, UNDER, -380.0), 1.5)
	_litter(Vector3(-10.0, UNDER + 0.77, -375.5), 0.8, 8)
	# --- the post room: copiers, pigeonholes, parcels nobody fetched
	_against("copy", EAST, -372.0, "steel_frame_shelves_01", {"height": 2.2})
	_against("copy", EAST, -375.0, "steel_frame_shelves_01", {"height": 2.2})
	_machine("copy", WEST, -372.4)
	_machine("copy", WEST, -374.6)
	_table(Vector3(8.0, UNDER, -380.4), Vector3(2.6, 0.95, 1.2), Color("787d80"))
	_shelf(Vector3(8.0, UNDER, -384.5), 0.0, 5.2, 0.5, 2.1, 5, Color("5d6468"), 0.9)
	_model("cardboard_box_01", Vector3(9.3, UNDER, -382.6), 0.4, {"scale": 1.4, "far": 30.0})
	_model("cardboard_box_01", Vector3(7.6, UNDER + 0.95, -380.3), 1.3, {"scale": 1.2, "solid": false, "far": 30.0})
	_litter(Vector3(6.6, UNDER, -376.8), 1.2, 10)
	# --- the security centre: a wall of screens and the desk that lifts the lockdown
	var security: Dictionary = room_of["security"]
	for row in range(2):
		for column in range(6):
			_screen(Transform3D(Basis(Vector3.UP, 0.0), _face_point(security, NORTH, 14.5 + column * 2.6, 1.75 + row * 0.85, -0.07)), Vector3.ZERO, Vector2(1.3, 0.75), [4, 1, 9, 5, 3, 8][(row * 2 + column) % 6], -1.0)
	_face_box(security, NORTH, "plate", 13.4, 28.6, 1.3, 3.1, -0.06, 0.0, Color("101214"))
	_console("security", NORTH, 16.0, 26.0, [5, 3, 1, 4])
	_desk(Vector3(15.0, UNDER, -374.0), PI / 2, 4)
	_desk(Vector3(27.0, UNDER, -374.0), -PI / 2, 5)
	_lockers("security", WEST, -384.0, -380.0, Color("3d4a54"))
	_lockers("security", EAST, -383.8, -380.2, Color("2c3236"))
	_door_tag("security", EAST, -375.45, "S-02", "SERVER", red.lightened(0.45))
	_display(_face_point(security, WEST, -374.4, 1.98, 0.0), _model_yaw(WEST), 2.6, "security")
	_office_chair(Vector3(22.6, UNDER, -379.6), 1.1, true)
	_blot(Vector3(19.6, UNDER, -379.0), 1.0, 0.7)
	_litter(Vector3(24.0, UNDER, -377.4), 1.2, 8)
	# --- the servers: two rows of racks under a cold light, the cooling at the far end
	for row in range(2):
		for i in range(8):
			_server_rack(Vector3(33.5 + row * 6.0, UNDER, -374.0 - i * 2.1), PI / 2 if row == 0 else -PI / 2, ["compute", "storage", "network"][(i + row) % 3], "S-%02d" % (row * 8 + i + 1))
	_chunk("Kit", false)
	var server: Dictionary = room_of["server"]
	for x in [35.0, 38.0]:
		_glow_box(Vector3(x, UNDER + 0.012, -381.35), Vector3(0.05, 0.012, 17.4), Color("3f8cff"), 3.2)
	for x in [33.4, 39.6]:
		_part("plate", Vector3(x, UNDER + 2.9, -381.35), Vector3(0.5, 0.05, 17.4), Color("2b2f31"))
		_pipe(Vector3(x - 0.12, UNDER + 2.96, -390.0), Vector3(x - 0.12, UNDER + 2.96, -372.7), 0.04, Color("17191b"), 6)
		_pipe(Vector3(x + 0.1, UNDER + 2.96, -390.0), Vector3(x + 0.1, UNDER + 2.96, -372.7), 0.03, Color("2b3a4a"), 6)
	_face_box(server, NORTH, "steel", 32.6, 41.4, 0.0, 2.5, -0.9, 0.0, Color("59626a"))
	for k in range(4):
		_face_box(server, NORTH, "plain", 33.0 + k * 2.15, 34.75 + k * 2.15, 0.5, 2.0, -0.912, -0.9, Color("15181a"))
		_led(_face_point(server, NORTH, 33.2 + k * 2.15, 2.25, -0.906), Vector3(0.08, 0.05, 0.012), Color("5ee07a") if k != 2 else Color("ff3a2a"), 3.0, 1.0 if k != 2 else 0.4)
	_solid(_face_centre(server, NORTH, 32.6, 41.4, 0.0, 2.5, -0.9, 0.0), _face_size(NORTH, 32.6, 41.4, 0.0, 2.5, -0.9, 0.0))
	_desk(Vector3(42.0, UNDER, -371.4), -PI / 2, 5)
	# --- the archive: shelves of files, half in the dark
	for i in range(4):
		_shelf(Vector3(-40.0 + i * 4.2, UNDER, -401.5), PI / 2, 9.0, 0.6, 2.4, 5, Color("4a5258"), 0.85)
	_chunk("Kit", false)
	_model("cardboard_box_01", Vector3(-27.0, UNDER, -396.0), 1.0, {"scale": 1.5, "far": 30.0})
	_model("cardboard_box_01", Vector3(-33.6, UNDER, -407.6), 0.2, {"scale": 1.5, "far": 30.0})
	_model("hand_truck", Vector3(-26.0, UNDER, -406.0), 2.4, {"far": 40.0})
	_desk(Vector3(-25.6, UNDER, -395.0), -PI / 2, 0)
	_litter(Vector3(-33.8, UNDER, -398.0), 1.3, 12)
	_litter(Vector3(-37.8, UNDER, -404.0), 1.0, 9)
	_office_chair(Vector3(-29.6, UNDER, -404.6), 2.6, true)
	# --- the staff room: lockers, a kitchenette, a place to sit
	_lockers("staff", NORTH, -22.6, -14.0)
	_sofa(Vector3(-8.5, UNDER, -394.1), PI, Color("2a3a46"), 2.4)
	_table(Vector3(-8.5, UNDER, -395.9), Vector3(1.4, 0.5, 0.8), Color("3c4246"))
	_counter("staff", EAST, -403.6, -399.4, Color(0.3, 0.33, 0.36), Color(0.6, 0.62, 0.63))
	var staff: Dictionary = room_of["staff"]
	_face_box(staff, EAST, "plain", -403.2, -402.6, 0.92, 1.24, -0.5, -0.1, Color("d8d8d2"))
	_face_box(staff, EAST, "plain", -400.6, -400.2, 0.92, 1.3, -0.42, -0.14, Color("1b1d1f"))
	_face_box(staff, EAST, "steel", -398.9, -398.1, 0.0, 1.9, -0.72, -0.05, Color("c4c8c4"))
	_solid(_face_centre(staff, EAST, -398.9, -398.1, 0.0, 1.9, -0.72, 0.0), _face_size(EAST, -398.9, -398.1, 0.0, 1.9, -0.72, 0.0))
	_mess_table(Vector3(-17.0, UNDER, -399.2))
	_mess_table(Vector3(-11.6, UNDER, -401.4))
	_board("staff", SOUTH, -13.0, 2.2, true)
	_plant(Vector3(-5.0, UNDER, -394.0), 1.3)
	_litter(Vector3(-14.0, UNDER, -396.4), 1.0, 6)
	# --- the spine to the canteen: somebody built a barricade here, and it did not hold
	_passage("spine", {"step": 5.93, "energy": 2.4, "reach": 10.0, "lines": [[-0.9, gold], [0.9, gold]], "tray": WEST, "fail": [3]})
	_stencil("spine", WEST, -384.05, 3.1, "KANTINE", 170)
	_stencil("spine", EAST, -389.97, 3.1, "B2  ▲", 170)
	_display(_face_point(room_of["spine"], EAST, -378.1, 1.98, 0.0), _model_yaw(EAST), 2.6, "admin")
	for z in [-374.0, -386.5, -401.5]:
		_floor_arrow(Vector3(0, UNDER, z), 0.0, gold)
	_bench(Vector3(3.3, UNDER, -372.2), -PI / 2, 2.2)
	_barricade(Vector3(-1.5, UNDER, -397.4), 0.0, 4.2)
	_stores(Vector3(-2.4, UNDER, -399.6), 2)
	_blot(Vector3(2.0, UNDER, -396.4), 1.1, 0.8)
	_smear(Vector3(2.1, UNDER, -396.8), Vector3(1.5, UNDER, -403.6), 0.3)
	_blot(Vector3(-0.6, UNDER, -395.6), 1.5, 1.0, Color(0.02, 0.02, 0.02, 0.66))
	_litter(Vector3(1.4, UNDER, -392.5), 1.2, 7)
	_shared_dice()
	_end_zone()

## An office chair on wheels; one that has fallen over lies in the way.
func _office_chair(pos: Vector3, yaw: float, fallen: bool = false) -> void:
	_lab_chair(pos, yaw, fallen)
	if fallen:
		_solid(pos + Vector3(0, 0.25, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.4), Vector3(0.56, 0.5, 0.95), true, yaw)
	else:
		_solid(pos + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5), true, yaw)

# ---------------------------------------------------------------- the canteen

func _lay_canteen() -> void:
	_own_dice(71007)
	_begin_zone("cafe", "cold", ["admin"])
	area = "cafe"
	# (The glass of the canteen's lamps is its own: it goes dark when the facility locks down.)
	_room("cafeteria", deep, Rect2(-24, -435, 48, 30), 6.0, "canteen", {"glow": "glow_cafe"})
	_door("spine", "cafeteria", 0.0, 4.0)
	_room("kitchen_f", deep, Rect2(24, -423, 14, 18), 3.6, "canteen", {"glow": "glow_cafe"})
	_door("cafeteria", "kitchen_f", -409.0, 2.0, {"kind": "slide"})
	_pane("cafeteria", EAST, -416.5, 7.0, 1.0, 2.3, "hatch", "kitchen_f")
	_room("cafe_store", deep, Rect2(-38, -425, 14, 16), 3.6, "concrete")
	_door("cafeteria", "cafe_store", -417.0, 2.4)
	area = "atrium"
	_room("north_link", deep, Rect2(-4, -445, 8, 10), 5.0, "panel", {"lamps": "none", "look": {"stripe": GUIDE.core}})
	_door("cafeteria", "north_link", 0.0, 4.0, {"kind": "gate", "area": "atrium", "name": "gate_atrium", "height": 3.0})
	area = "cafe"
	_chunk("Kit", false)
	var white: Color = GUIDE.core
	_passage("north_link", {"step": 4.8, "ribs": false, "tray": -1, "energy": 2.4, "reach": 10.0, "lines": [[-0.9, white], [0.9, white]]})
	_stencil("north_link", WEST, -440.0, 3.2, "B2", 200)
	_stencil("north_link", EAST, -440.0, 3.2, "ZENTRALRAUM", 84)
	var cafe: Dictionary = room_of["cafeteria"]
	# --- tables in rows, the way through the middle kept free; near the gate somebody
	# turned tables into cover
	for x in [-0.9, 0.9]:
		_stripe(Vector3(x, UNDER, -434.7), Vector3(x, UNDER, -405.3), 0.12, white)
	for z in [-410.0, -420.5, -430.0]:
		_floor_arrow(Vector3(0, UNDER, z), 0.0, white)
	for row in range(3):
		for column in range(5):
			if column == 2 or (row == 2 and (column == 1 or column == 3)):
				continue
			var table := Vector3(-18.0 + column * 9.0, UNDER, -412.0 - row * 7.0)
			_mess_table(table, 3.2)
			# What was left on it.
			for k in range(4):
				if random.randf() < 0.45:
					continue
				var tray := table + Vector3(-1.2 + k * 0.8 + random.randf_range(-0.12, 0.12), 0.77, random.randf_range(-0.2, 0.2))
				_part("plain", tray, Vector3(0.42, 0.016, 0.3), _vary(Color("8a7f6a"), 0.05), Vector3(0, random.randf_range(-20, 20), 0))
				_part("plain", tray + Vector3(0.05, 0.03, 0.02), Vector3(0.2, 0.04, 0.2), _vary(Color("d6d3c8"), 0.04), Vector3(0, random.randf_range(0, 90), 0))
	_barricade(Vector3(-8.4, UNDER, -428.4), 0.12, 6.0)
	_barricade(Vector3(8.6, UNDER, -428.8), -0.1, 6.0)
	_bench(Vector3(-13.0, UNDER, -431.5), 0.4, 2.4)
	_blot(Vector3(-5.0, UNDER, -430.0), 1.3, 0.9)
	_blot(Vector3(6.2, UNDER, -431.4), 1.0, 0.8)
	_smear(Vector3(6.0, UNDER, -431.0), Vector3(1.6, UNDER, -434.2), 0.3)
	_blot(Vector3(3.0, UNDER, -426.6), 1.6, 1.1, Color(0.02, 0.02, 0.02, 0.6))
	_litter(Vector3(-3.0, UNDER, -424.0), 1.6, 8)
	_litter(Vector3(12.0, UNDER, -421.5), 1.4, 7)
	for x in [-12.0, 12.0]:
		for z in [-414.0, -426.0]:
			_pillar(Vector3(x, UNDER, z + 0.5), 0.7, 6.0, Color(0.8, 0.8, 0.78))
	# --- the counter: a rail for the trays, glass over the food, lamps that keep it warm
	_face_box(cafe, EAST, "steel", -420.0, -413.0, 0.0, 0.92, -1.0, -0.25, Color("6c7275"))
	_face_box(cafe, EAST, "plain", -419.98, -413.02, 0.0, 0.1, -1.04, -0.3, Color("0d0f10"))
	for k in range(6):
		_face_box(cafe, EAST, "plain", -419.6 + k * 1.14, -418.7 + k * 1.14, 0.92, 0.932, -0.9, -0.42, Color("151515") if k % 2 == 0 else Color("3b2a1c"))
	for rail in [-1.16, -1.26, -1.36]:
		_pipe(_face_point(cafe, EAST, -420.0, 0.84, rail), _face_point(cafe, EAST, -413.0, 0.84, rail), 0.018, Color("9aa0a3"), 6, "steel")
	for bracket in [-419.8, -416.5, -413.2]:
		_face_box(cafe, EAST, "steel", bracket - 0.02, bracket + 0.02, 0.78, 0.82, -1.4, -1.0, Color("3f4548"))
		_face_box(cafe, EAST, "steel", bracket - 0.015, bracket + 0.015, 0.92, 1.56, -0.97, -0.94, Color("3f4548"))
	_chunk("Glass", false)
	batch.box(mats["pane"], _face_centre(cafe, EAST, -420.0, -413.0, 1.12, 1.52, -0.965, -0.945), _face_size(EAST, -420.0, -413.0, 1.12, 1.52, -0.965, -0.945), Color.WHITE)
	_chunk("Kit", false)
	_face_box(cafe, EAST, "steel", -420.0, -413.0, 1.56, 1.62, -1.0, -0.3, Color("3f4548"))
	_face_glow(cafe, EAST, -419.7, -413.3, 1.545, 1.56, -0.86, -0.5, Color("ffb066"), 3.4)
	_light(_face_point(cafe, EAST, -416.5, 1.3, -0.7), Color("ffb066"), 1.0, 5.0, false, 0.0, 0.4, LAMP_FADE)
	_solid(_face_centre(cafe, EAST, -420.0, -413.0, 0.0, 0.92, -1.4, -0.25), _face_size(EAST, -420.0, -413.0, 0.0, 0.92, -1.4, -0.25))
	_face_box(cafe, EAST, "plate", -420.2, -412.8, 2.62, 3.6, -0.06, -0.04, Color("101214"))
	for k in range(3):
		_screen(Transform3D(Basis(Vector3.UP, -PI / 2), _face_point(cafe, EAST, -418.8 + k * 2.3, 3.11, -0.066)), Vector3.ZERO, Vector2(2.1, 0.82), 0 if k != 1 else 2, 0.2 + k * 0.3)
	_wall_sign("AUSGABE", _face_point(cafe, EAST, -416.5, 4.0, -0.05), 40, Color("1c555b"), -PI / 2)
	_sign_board("cafeteria", NORTH, 0.0, 4.15, [["▲   ZENTRALRAUM  B2  ·  FORSCHUNG", white], ["◄   LAGER", GUIDE.cafe], ["KÜCHE  ·  AUSGABE   ►", GUIDE.cafe]], 5.6, 30)
	_display(_face_point(cafe, NORTH, -7.0, 2.0, 0.0), _model_yaw(NORTH), 3.2, "cafe")
	_stencil("cafeteria", SOUTH, -12.0, 3.6, "KANTINE", 200)
	_door_tag("cafeteria", EAST, -407.45, "K-01", "KÜCHE", Color("f0d68a"))
	_door_tag("cafeteria", WEST, -415.2, "K-02", "LAGER", Color("f0d68a"))
	_stencil("cafeteria", SOUTH, 12.5, 3.6, "B2 · 04", 200)
	# --- machines along the west wall, a bucket somebody left
	for z in [-426.4, -428.4, -430.4]:
		_house_prop("vending_machine", _face_point(cafe, WEST, z, 0.0, -0.62), PI / 2, {"far": 50.0})
	_face_box(cafe, WEST, "steel", -424.9, -423.9, 0.0, 1.95, -0.7, -0.04, Color("2c3236"))
	_face_glow(cafe, WEST, -424.8, -424.0, 0.3, 1.8, -0.71, -0.7, Color("9fe0ff"), 2.4)
	_solid(_face_centre(cafe, WEST, -424.9, -423.9, 0.0, 1.95, -0.7, 0.0), _face_size(WEST, -424.9, -423.9, 0.0, 1.95, -0.7, 0.0))
	_light(_face_point(cafe, WEST, -427.0, 1.4, -1.6), Color("bfe8ff"), 0.9, 6.0, false, 0.1, 0.4, LAMP_FADE)
	_model("metal_trash_can", Vector3(-22.0, UNDER, -407.0), PI / 2, {"height": 0.9, "far": 40.0})
	_house_prop("mop_trolley", Vector3(-15.6, UNDER, -407.6), 0.7, {"far": 40.0})
	_blot(Vector3(-14.6, UNDER, -408.4), 1.1, 0.8, Color(0.5, 0.6, 0.62, 0.22))
	for lean in [-1.0, 1.0]:
		_part("plain", Vector3(-13.4, UNDER + 0.3, -409.6 + lean * 0.11), Vector3(0.3, 0.62, 0.02), Color("d2b21e"), Vector3(lean * 20.0, 0, 0))
	_plant(Vector3(21.5, UNDER, -433.0), 1.4)
	_plant(Vector3(-21.5, UNDER, -433.0), 1.4)
	_plant(Vector3(21.8, UNDER, -406.6), 1.3)
	# --- the kitchen: a stove under a hood, cold stores, the hatch to the counter
	var kitchen: Dictionary = room_of["kitchen_f"]
	_counter("kitchen_f", NORTH, 25.0, 37.0, Color(0.34, 0.36, 0.38), Color(0.66, 0.68, 0.69))
	_counter("kitchen_f", EAST, -420.0, -408.0, Color(0.34, 0.36, 0.38), Color(0.66, 0.68, 0.69))
	_table(Vector3(29.6, UNDER, -412.4), Vector3(3.0, 0.9, 1.2), Color("787d80"))
	var stove := Vector3(31.0, UNDER, -418.0)
	_part("steel", stove + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 1.2), Color("5a6064"))
	for k in range(4):
		batch.cylinder(mats["plain"], stove + Vector3(-1.2 + k * 0.8, 0.9, 0.0), 0.2, 0.2, 0.02, Color("101010"), 12)
	_part("plain", stove + Vector3(0, 0.6, 0.606), Vector3(2.9, 0.08, 0.012), Color("151515"))
	_part("steel", stove + Vector3(0, 2.4, 0), Vector3(3.4, 0.5, 1.4), Color("7d8488"))
	_pipe(stove + Vector3(0, 2.65, 0), stove + Vector3(0, 3.6, 0), 0.22, Color("6d7276"), 10, "steel")
	_solid(stove + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 1.2))
	for k in range(2):
		_face_box(kitchen, SOUTH, "steel", 29.0 + k * 2.6, 31.4 + k * 2.6, 0.0, 2.05, -0.8, -0.04, Color("c4c8c4"))
		_face_box(kitchen, SOUTH, "plain", 30.16 + k * 2.6, 30.24 + k * 2.6, 0.1, 1.95, -0.812, -0.8, Color("2a2d30"))
		_face_box(kitchen, SOUTH, "steel", 30.0 + k * 2.6, 30.06 + k * 2.6, 0.9, 1.3, -0.85, -0.8, Color("3a3d40"))
	_solid(_face_centre(kitchen, SOUTH, 29.0, 34.0, 0.0, 2.05, -0.8, 0.0), _face_size(SOUTH, 29.0, 34.0, 0.0, 2.05, -0.8, 0.0))
	_house_prop("gas_cylinder", Vector3(25.2, UNDER, -406.2), 0.5, {"far": 35.0})
	_blot(Vector3(27.6, UNDER, -409.6), 1.0, 0.7)
	_smear(Vector3(27.0, UNDER, -409.4), Vector3(24.6, UNDER, -409.0), 0.3)
	# --- the store
	_stores(Vector3(-33.0, UNDER, -414.0), 5)
	_stores(Vector3(-34.0, UNDER, -421.0), 5)
	_against("cafe_store", WEST, -417.0, "steel_frame_shelves_01", {"height": 2.3})
	_shelf(Vector3(-31.0, UNDER, -409.55), PI, 9.0, 0.5, 2.2, 4, Color("4a5258"), 0.8)
	_shelf(Vector3(-31.0, UNDER, -424.45), 0.0, 9.0, 0.5, 2.2, 4, Color("4a5258"), 0.75)
	_model("hand_truck", Vector3(-26.4, UNDER, -421.6), 1.1, {"far": 40.0})
	# --- what the lockdown switches on: red lamps that beat, turning nothing else
	alarm_node = Node3D.new()
	alarm_node.name = "Alarm"
	alarm_node.visible = false
	add_child(alarm_node)
	var red := _glow_material(Color("ff2a1a"), 6.0)
	for spot in [Vector3(-23.6, 4.3, -413.0), Vector3(-23.6, 4.3, -428.0), Vector3(23.6, 4.3, -411.0), Vector3(23.6, 4.3, -428.0), Vector3(-9.0, 4.6, -434.6), Vector3(9.0, 4.6, -434.6), Vector3(-9.0, 4.6, -405.4), Vector3(9.0, 4.6, -405.4), Vector3(-11.48, 4.6, -413.5), Vector3(11.48, 4.6, -413.5), Vector3(-11.48, 4.6, -425.5), Vector3(11.48, 4.6, -425.5)]:
		var bulb := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.36, 0.2, 0.36)
		bulb.mesh = shape
		bulb.material_override = red
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.position = Vector3(spot.x, UNDER + spot.y, spot.z)
		alarm_node.add_child(bulb)
	for spot in [Vector3(-14.0, 4.6, -413.0), Vector3(14.0, 4.6, -413.0), Vector3(0.0, 5.0, -420.0), Vector3(-14.0, 4.6, -428.0), Vector3(14.0, 4.6, -428.0), Vector3(0.0, 4.2, -432.5), Vector3(31.0, 2.9, -414.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ff3222")
		lamp.light_energy = 3.2
		lamp.omni_range = 16.0
		lamp.omni_attenuation = 1.0
		lamp.shadow_enabled = false
		lamp.light_volumetric_fog_energy = 1.6
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = LAMP_FADE + 10.0
		lamp.distance_fade_length = 14.0
		lamp.position = Vector3(spot.x, UNDER + spot.y, spot.z)
		alarm_node.add_child(lamp)
		alarm_lamps.append(lamp)
	_shared_dice()
	_end_zone()

## A prop of the house (the user's models in assets/hive/user), if it is there: standing
## at `pos`, its front looking along `yaw` as a model's does.
func _house_prop(id: String, pos: Vector3, yaw: float = 0.0, options: Dictionary = {}) -> Node3D:
	var path := "res://assets/hive/user/%s.glb" % id
	if not ResourceLoader.exists(path):
		return null
	return _model("hive/user/%s.glb" % id, pos, yaw + float(PROP_TURN.get(id, 0.0)), options)

## Switches the lockdown's light in the canteen on or off: its lamps go nearly dark, red
## ones beat, the air turns red.
func set_alarm(on: bool) -> void:
	if alarm_on == on or alarm_node == null or (alarm_hold and not on):
		return
	alarm_on = on
	alarm_node.visible = on
	set_zone_mood("cafe", "alarm" if on else "cold")
	if mats.has("glow_cafe"):
		var dim := 0.1 if on else 1.0
		(mats["glow_cafe"] as StandardMaterial3D).albedo_color = Color(2.42 * dim, 2.42 * dim, 2.42 * dim)
	for id in ["cafeteria", "kitchen_f"]:
		var span: Array = room_of[id].get("lights", [0, 0])
		for index in range(int(span[0]), int(span[1])):
			var entry: Dictionary = flickers[index]
			if not entry.has("full"):
				entry["full"] = float(entry.energy)
			entry.energy = float(entry.full) * (0.16 if on else 1.0)
			(entry.light as Light3D).light_energy = float(entry.energy)

func lock(id: String, instant: bool = false) -> void:
	var was_open := locked.has(id) and not bool(locked[id])
	super.lock(id, instant)
	# The canteen is shut behind the squad once: that is the lockdown.
	if id == "cafe" and was_open:
		set_alarm(true)

func unlock(id: String, instant: bool = false) -> void:
	super.unlock(id, instant)
	if id == "cafe":
		set_alarm(false)

func lock_all() -> void:
	super.lock_all()
	set_alarm(false)

# ---------------------------------------------------------------- the central hall and the plant rooms

func _lay_atrium() -> void:
	_own_dice(71008)
	_begin_zone("atrium", "core", ["cafe"])
	area = "atrium"
	_room("atrium", deep, Rect2(-24, -489, 48, 44), 12.0, "bighall")
	_door("north_link", "atrium", 0.0, 4.0, {"height": 3.2})
	_room("atrium_deck", deck, Rect2(-24, -489, 48, 44), 5.0, "bighall", {
		"walls": false, "floor": false, "ceiling": false, "lamps": "none",
		"walk": [Rect2(-23.3, -448.4, 46.6, 2.75), Rect2(-23.3, -488.3, 46.6, 2.75), Rect2(-23.3, -488.3, 2.75, 42.6), Rect2(20.55, -488.3, 2.75, 42.6)]
	})
	_room("med", deep, Rect2(-48, -479, 24, 20), 3.6, "canteen", {"look": {"trim": Color("2f6f8a")}})
	_door("atrium", "med", -469.0, 2.0, {"kind": "slide"})
	_chunk("Kit", false)
	# The gallery around the hall, on posts, and two flights up to it.
	_deck_floor(Rect2(-23.8, -449.0, 47.6, 3.8), DECK, UNDER, [[NORTH, -23.8, 13.0], [NORTH, 15.0, 23.8]])
	_deck_floor(Rect2(-23.8, -488.8, 47.6, 3.8), DECK, UNDER, [[SOUTH, -20.0, 20.0]])
	_deck_floor(Rect2(-23.8, -485.0, 3.8, 36.0), DECK, UNDER, [[EAST, -485.0, -449.0]])
	_deck_floor(Rect2(20.0, -485.0, 3.8, 36.0), DECK, UNDER, [[WEST, -485.0, -449.0]])
	for x in [-20.2, -10.0, 10.0, 20.2]:
		for z in [-449.2, -484.8]:
			_part("plate", Vector3(x, UNDER + 1.95, z), Vector3(0.26, 3.9, 0.26), Color("1d2124"))
			_solid(Vector3(x, UNDER + 1.95, z), Vector3(0.26, 3.9, 0.26))
	for z in [-461.0, -473.0]:
		for x in [-20.2, 20.2]:
			_part("plate", Vector3(x, UNDER + 1.95, z), Vector3(0.26, 3.9, 0.26), Color("1d2124"))
			_solid(Vector3(x, UNDER + 1.95, z), Vector3(0.26, 3.9, 0.26))
	_deck_stairs(Vector3(14, UNDER, -456.3), Vector3(14, DECK, -449.0), deep, deck, Vector3(14, UNDER, -457.0), Vector3(14, DECK, -447.5))
	# The core of the hall: a shaft of glass and light through every storey.
	_vessel(Vector3(0, UNDER, -467.0), 3.2, 12.0, Color(0.5, 0.86, 1.0))
	for turn_index in range(8):
		var turn := TAU * turn_index / 8.0
		_stripe(Vector3(cos(turn) * 4.4, UNDER, -467.0 + sin(turn) * 4.4), Vector3(cos(turn) * 4.4 + 0.01, UNDER, -467.0 + sin(turn) * 4.4 + 0.01), 0.5, Color("c9a227"))
	var hall: Dictionary = room_of["atrium"]
	_wall_sign("ZENTRALRAUM  B2", _face_point(hall, NORTH, 0.0, 10.8, -0.05), 64, Color("cfe6ff"))
	_display(_face_point(hall, NORTH, 0.0, 7.6, 0.0), _model_yaw(NORTH), 8.0, "core")
	_display(Vector3(5.4, UNDER, -451.4), 0.0, 2.6, "core", "stele")
	_wall_sign("FORSCHUNG  ▲", _face_point(hall, NORTH, 0.0, 3.4, -0.05), 26, Color("c9a227"))
	_wall_sign("◄  KRANKENSTATION", _face_point(hall, WEST, -469.0, 3.0, -0.05), 22, Color("1c555b"), PI / 2)
	_wall_sign("TECHNIK  ►", _face_point(hall, EAST, -469.0, 3.0, -0.05), 22, Color("1c555b"), -PI / 2)
	_supply(Vector3(-12.0, UNDER, -445.7), Vector3(0, 0, -1), "ZENTRALRAUM  B2")
	for spot in [Vector3(-14, UNDER, -476), Vector3(14, UNDER, -478), Vector3(-14.0, UNDER, -462.0), Vector3(10, UNDER, -482)]:
		_stores(spot, 3)
	for spot in [Vector3(-8.5, UNDER, -453.0), Vector3(8.5, UNDER, -453.0)]:
		_model("modern_arm_chair_01", spot, 0.4, {"far": 40.0})
	# --- the sick bay: beds behind curtains, and first aid for whoever needs it
	for i in range(4):
		_bed(Vector3(-44.5, UNDER, -476.0 + i * 4.4), 0.0, Color("9fb4b8"))
		_part("cloth", Vector3(-43.6, UNDER + 1.2, -473.9 + i * 4.4), Vector3(3.2, 2.0, 0.03), Color("8fa9a6"))
	_station("health", "KRANKENSTATION", "100", Vector3(-25.0, UNDER, -463.0), PI, Color("f5b68e"))
	_model("wheelchair_01", Vector3(-31.0, UNDER, -474.0), 0.9, {"far": 40.0})
	_lockers("med", NORTH, -40.0, -34.0, Color("9aa6a8"))
	_table(Vector3(-32.0, UNDER, -462.0), Vector3(2.4, 0.9, 0.9), Color("8a9092"))
	_model("medical_box", Vector3(-32.0, UNDER + 0.9, -462.0), 0.3, {"scale": 1.2, "solid": false, "far": 25.0})
	_dress_atrium()
	_dress_med()
	_shared_dice()
	_end_zone()
	# --- the plant rooms east of the hall
	_own_dice(71009)
	_begin_zone("tech", "plant", ["atrium"])
	_room("maint", deep, Rect2(24, -472, 36, 6), 4.2, "tech", {"lamps": "none"})
	_door("atrium", "maint", -469.0, 3.0, {"kind": "slide"})
	_room("generator", deep, Rect2(40, -466, 20, 21), 6.0, "tech")
	_door("maint", "generator", 50.0, 3.0)
	_room("pump", deep, Rect2(40, -491, 20, 19), 6.0, "tech", {"look": {"light": Color("9fd0c0"), "energy": 3.2}})
	_door("maint", "pump", 50.0, 3.0)
	_chunk("Kit", false)
	# The generators: two sets on plinths, the switchboard on the south wall.
	for x in [45.0, 55.0]:
		var set_at := Vector3(x, UNDER, -457.0)
		_part("formwork", set_at + Vector3(0, 0.15, 0), Vector3(3.4, 0.3, 7.0), Color(0.5, 0.5, 0.48))
		_part("steel", set_at + Vector3(0, 1.3, 0.6), Vector3(2.6, 2.0, 4.6), Color("36505a"))
		batch.cylinder(mats["steel"], set_at + Vector3(0, 1.3, -2.9), 0.9, 0.9, 1.6, Color("2c3236"), 16, Basis(Vector3.RIGHT, PI / 2))
		_pipe(set_at + Vector3(0.8, 2.3, 1.6), set_at + Vector3(0.8, 5.9, 1.6), 0.18, Color("5a5d5e"), 10, "steel")
		_hazard(set_at + Vector3(-1.7, 0.31, -3.5), set_at + Vector3(1.7, 0.31, -3.5), Vector3(0.425, 0.01, 0.2), 8)
		_solid(set_at + Vector3(0, 1.2, 0), Vector3(3.4, 2.4, 7.0))
		_light(set_at + Vector3(0, 3.6, 0), Color("ffb36b"), 1.2, 8.0, false, 0.2, 0.6, LAMP_FADE)
	var generator: Dictionary = room_of["generator"]
	_face_box(generator, SOUTH, "steel", 46.5, 53.5, 0.0, 2.3, -0.5, 0.0, Color("2c3236"))
	for k in range(6):
		_face_box(generator, SOUTH, "plain", 46.9 + k * 1.1, 47.7 + k * 1.1, 0.5, 1.9, -0.51, -0.5, Color("1b1f22"))
		_led(_face_point(generator, SOUTH, 47.3 + k * 1.1, 2.05, -0.51), Vector3(0.08, 0.08, 0.01), Color("ff3a2a") if k < 4 else Color("ffb347"), 3.0, 0.4)
	_solid(_face_centre(generator, SOUTH, 46.5, 53.5, 0.0, 2.3, -0.5, 0.0), _face_size(SOUTH, 46.5, 53.5, 0.0, 2.3, -0.5, 0.0))
	_wall_sign("NOTSTROM  ·  SCHLEUSE", _face_point(generator, SOUTH, 50.0, 2.75, -0.05), 24, Color("c9a227"), PI)
	_stores(Vector3(43.0, UNDER, -448.5), 3)
	# The pumps: tanks, pipes, water on the floor.
	for x in [44.5, 55.5]:
		for z in [-476.5, -486.0]:
			var tank_at := Vector3(x, UNDER, z)
			batch.cylinder(mats["steel"], tank_at, 1.5, 1.5, 3.6, Color("3d5a56"), 18)
			batch.cylinder(mats["steel"], tank_at + Vector3(0, 3.6, 0), 1.5, 0.5, 0.6, Color("35504c"), 18)
			_pipe(tank_at + Vector3(0, 4.2, 0), tank_at + Vector3(0, 5.9, 0), 0.16, Color("6d6f6c"), 10, "steel")
			_round_solid(tank_at, 1.5, 3.8)
	for z in [-476.5, -486.0]:
		_pipe(Vector3(44.5, UNDER + 1.2, z), Vector3(55.5, UNDER + 1.2, z), 0.14, Color("8a5a2c"), 10, "steel")
	_pipe(Vector3(50.0, UNDER + 1.2, -486.0), Vector3(50.0, UNDER + 1.2, -476.5), 0.14, Color("8a5a2c"), 10, "steel")
	_solid(Vector3(50.0, UNDER + 0.7, -481.25), Vector3(0.4, 1.4, 9.5))
	_passage("maint", {"step": 5.93, "light": Color("ffb36b"), "energy": 2.1, "reach": 9.5, "dead": [1], "fail": [4], "lines": [[0.0, GUIDE.tech, 0.16]], "tray": NORTH})
	_sign_board("maint", NORTH, 44.5, 2.2, [["▲   PUMPEN  ·  WASSER", GUIDE.tech], ["▼   GENERATOR  ·  NOTSTROM", GUIDE.tech]], 4.2, 26)
	_stencil("maint", SOUTH, 32.9, 2.4, "TECHNIK", 150, Color(0.78, 0.6, 0.2))
	_display(_face_point(room_of["maint"], SOUTH, 27.2, 1.75, 0.0), _model_yaw(SOUTH), 2.0, "tech")
	# The end of the passage: the house's own steel door, shut for good.
	if _house_prop("steel_door", _face_point(room_of["maint"], EAST, -469.0, 0.0, -0.56), _model_yaw(EAST), {"far": 60.0}) == null:
		_sealed_door("maint", EAST, -469.0)
	_face_glow(room_of["maint"], EAST, -469.3, -468.7, 2.5, 2.56, -0.2, -0.17, Color("ff3a2a"), 3.0)
	_stores(Vector3(33.0, UNDER, -470.8), 2)
	_blot(Vector3(38.0, UNDER, -468.6), 1.4, 0.9, Color(0.03, 0.03, 0.025, 0.7))
	_dress_tech()
	_shared_dice()
	_end_zone()

# ---------------------------------------------------------------- the research wing

func _lay_research() -> void:
	_own_dice(71010)
	_begin_zone("research", "sick", ["atrium"])
	area = "decon"
	_room("decon", deep, Rect2(-4, -501, 8, 12), 4.2, "lab", {"look": {"light": Color("bfe8ff"), "strip_color": Color("7fe0ff")}})
	_door("atrium", "decon", 0.0, 3.0, {"kind": "gate", "area": "decon", "name": "gate_decon"})
	area = "research"
	_room("lab_corridor", deep, Rect2(-4, -569, 8, 68), 5.0, "lab", {"lamps": "none", "look": {"tide": 1.6, "tide_sides": [EAST, WEST], "tide_span": [-569.0, -539.5]}})
	_door("decon", "lab_corridor", 0.0, 3.0, {"kind": "gate", "area": "research", "name": "gate_research"})
	_room("lab_a", deep, Rect2(-28, -519, 24, 18), 3.8, "lab")
	_room("lab_b", deep, Rect2(-28, -537, 24, 18), 3.8, "lab")
	_room("quarantine", deep, Rect2(-28, -565, 24, 28), 4.6, "lab", {"look": {"stripe": Color("b8452f"), "light": Color("ffd9c8")}})
	_room("lab_c", deep, Rect2(4, -519, 24, 18), 3.8, "lab")
	_room("cryo", deep, Rect2(4, -541, 24, 22), 3.8, "lab", {"look": {"light": Color("a8d8ff"), "energy": 1.2, "stripe": Color("2f6fb0")}})
	# North of the cold store the wing stands under water: one laboratory is still full
	# behind its glass, the glass of the next has burst into the corridor.
	_room("sunken", deep, Rect2(4, -555, 28, 14), 4.6, "lab", {"nav": false, "lamps": "none", "look": {"panel": Color(0.56, 0.64, 0.62), "strip": false}})
	_room("flooded", deep, Rect2(4, -569, 28, 14), 4.6, "lab", {"look": {"light": Color("9fd8cc"), "energy": 2.4, "flicker": 0.4, "dead": 0.3, "tide": 1.6, "panel": Color(0.66, 0.72, 0.68), "strip": false, "stripe": GUIDE.flood}})
	for entry in [["lab_a", -510.0], ["lab_b", -528.0], ["quarantine", -551.0], ["lab_c", -510.0], ["cryo", -530.0]]:
		_door("lab_corridor", str(entry[0]), float(entry[1]), 2.0, {"kind": "slide"})
	_door("lab_corridor", "flooded", -562.0, 9.0, {"kind": "join"})
	for at in [-551.5, -544.5]:
		_pane("lab_corridor", EAST, at, 6.0, 0.6, 3.4, "glass", "sunken")
	for entry in [["lab_a", WEST, -504.5, 5.0], ["lab_a", WEST, -515.0, 6.0], ["lab_b", WEST, -522.5, 5.0], ["lab_b", WEST, -533.0, 6.0], ["quarantine", WEST, -543.0, 8.0], ["quarantine", WEST, -559.0, 8.0], ["lab_c", EAST, -504.5, 5.0], ["lab_c", EAST, -515.0, 6.0], ["cryo", EAST, -524.0, 6.0], ["cryo", EAST, -536.0, 6.0]]:
		_pane("lab_corridor", int(entry[1]), float(entry[2]), float(entry[3]), 0.9, 2.6, "glass", str(entry[0]))
	# The corridor runs into the crossing without a wall between them.
	_room("cross", deep, Rect2(-30, -577, 60, 8), 5.0, "panel", {"lamps": "none", "look": {"stripe": GUIDE.hall, "panel": Color(0.62, 0.62, 0.6), "tide": 1.6, "tide_span": [-10.0, 10.0]}})
	_door("lab_corridor", "cross", 0.0, 8.0, {"kind": "join"})
	_chunk("Kit", false)
	# The sluice: nozzles and a grating.
	for z in [-492.0, -495.0, -498.0]:
		for x in [-3.3, 3.3]:
			_part("steel", Vector3(x, UNDER + 2.4, z), Vector3(0.2, 0.2, 0.2), Color("7d8284"))
			_pipe(Vector3(x, UNDER + 2.4, z), Vector3(x, UNDER + 3.6, z), 0.04, Color("7d8284"), 6, "steel")
	_part("tread", Vector3(0, UNDER + 0.006, -495.0), Vector3(5.0, 0.012, 9.0), Color(0.3, 0.32, 0.34))
	var corridor: Dictionary = room_of["lab_corridor"]
	_wall_sign("FORSCHUNGSTRAKT  ·  SCHUTZSTUFE  3", _face_point(corridor, WEST, -503.0, 3.3, -0.05), 20, Color("b8452f"), PI / 2)
	# (Its bays are counted from the north: the first five stand in the water.)
	_passage("lab_corridor", {"step": 5.63, "light": Color("d6f5e6"), "energy": 2.3, "reach": 10.0, "dead": [1, 3], "fail": [0, 2, 4, 8], "lines": [[-0.9, GUIDE.research], [0.9, GUIDE.research]], "tray": -1})
	for z in [-506.0, -524.0]:
		_floor_arrow(Vector3(0, UNDER, z), 0.0, GUIDE.research)
	_display(Vector3(0, UNDER + 3.55, -512.47), 0.0, 3.0, "research", "hang", 0.3)
	for tag in [[WEST, -510.0, "L-01", "LABOR  A"], [EAST, -510.0, "L-03", "LABOR  C"], [WEST, -528.0, "L-02", "LABOR  B"], [EAST, -530.0, "L-04", "KRYOLAGER"], [WEST, -551.0, "Q-01", "QUARANTÄNE"]]:
		_door_tag("lab_corridor", int(tag[0]), float(tag[1]) + 1.55, str(tag[2]), str(tag[3]), Color("9fe8e0") if str(tag[2]) != "Q-01" else Color("ff8a7a"))
	for entry in [[-510.0, "LABOR  A", "LABOR  C"], [-528.0, "LABOR  B", "KRYOLAGER"], [-553.0, "QUARANTÄNE", ""]]:
		_wall_sign(str(entry[1]), _face_point(corridor, WEST, float(entry[0]) + 2.0, 3.1, -0.058), 18, Color("1c555b"), PI / 2)
		if str(entry[2]) != "":
			_wall_sign(str(entry[2]), _face_point(corridor, EAST, float(entry[0]) + 2.0, 3.1, -0.058), 18, Color("1c555b"), -PI / 2)
	# --- the laboratories: benches in rows, the tables and microscopes of the house
	for lab in [["lab_a", -17.0, -510.0], ["lab_b", -17.0, -528.0], ["lab_c", 15.0, -510.0]]:
		var mid := Vector3(float(lab[1]), UNDER, float(lab[2]))
		# The house's own furniture (the user's models): two benches with a canopy stand free
		# in the middle of each laboratory, back to back, and two long work places along the
		# wall opposite the corridor.
		var own := ResourceLoader.exists("res://assets/hive/user/lab_table_a.glb") and ResourceLoader.exists("res://assets/hive/user/lab_table_b.glb")
		if own:
			for offset in [-4.6, 4.6]:
				_against(str(lab[0]), WEST if mid.x < 0.0 else EAST, mid.z + float(offset), "hive/user/lab_table_b.glb", {"far": 45.0})
		for row in range(3):
			var at := mid + Vector3(0, 0, -5.0 + row * 5.0)
			if own and row == 1:
				_model("hive/user/lab_table_a.glb", at + Vector3(-3.2, 0, 0), 0.0, {"far": 45.0})
				_model("hive/user/lab_table_a.glb", at + Vector3(3.2, 0, 0), PI, {"far": 45.0})
			else:
				_lab_bench(at + Vector3(-4.0, 0, 0), 5.0, 0.0, row)
				_lab_bench(at + Vector3(4.0, 0, 0), 5.0, 0.0, row + 2)
		_lockers(str(lab[0]), NORTH if str(lab[0]) != "lab_b" else SOUTH, float(lab[1]) - 9.0, float(lab[1]) - 4.0, Color("c2c8c6"))
	if ResourceLoader.exists("res://assets/hive/user/microscope_a.glb"):
		for spot in [Vector3(-21.6, UNDER + 1.05, -515.0), Vector3(-12.4, UNDER + 1.05, -505.0), Vector3(11.0, UNDER + 1.05, -515.0)]:
			_model("hive/user/microscope_a.glb", spot, random.randf() * TAU, {"solid": false, "far": 25.0})
		for spot in [Vector3(-20.0, UNDER + 1.05, -533.0), Vector3(19.4, UNDER + 1.05, -505.0)]:
			_model("hive/user/microscope_b.glb", spot, random.randf() * TAU, {"solid": false, "far": 25.0})
	# --- quarantine: a cell of glass in the middle of the room, tanks along the wall
	for i in range(5):
		_tank(Vector3(-26.4, UNDER, -541.0 - i * 5.0), "Q-%02d" % (i + 1), ["leech", "striker", "normalzombie", "stalker", "striker"][i], ["curled", "reaching", "adrift", "adrift", "curled"][i], 90.0 + i * 11.0, [0.6, 1.0, 0.45, 0.5, 0.8][i], i == 1, 0.1 + 0.1 * (i % 2))
	_burst_tank(Vector3(-26.4, UNDER, -563.0), "Q-06")
	for side_x in [-20.0, -10.0]:
		_part("plate", Vector3(side_x, UNDER + 1.6, -551.0), Vector3(0.12, 3.2, 0.12), Color("1c2023"))
	_chunk("Glass", false)
	for wall in [[Vector3(-15.0, UNDER + 1.6, -546.0), Vector3(10.0, 3.2, 0.06)], [Vector3(-15.0, UNDER + 1.6, -556.0), Vector3(10.0, 3.2, 0.06)], [Vector3(-20.0, UNDER + 1.6, -551.0), Vector3(0.06, 3.2, 10.0)]]:
		batch.box(mats["pane"], wall[0], wall[1], Color.WHITE)
		_solid(wall[0], wall[1])
	_chunk("Kit", false)
	_bed(Vector3(-15.0, UNDER, -551.0), 0.0, Color("b8c2c0"))
	_light(Vector3(-15.0, UNDER + 3.0, -551.0), Color("ff5a4a"), 1.4, 7.0, false, 0.3, 0.8, LAMP_FADE)
	# --- the cold store
	for i in range(12):
		_cold_store(Vector3(27.45, UNDER, -522.0 - i * 0.9), -PI / 2, i)
	for i in range(8):
		_cold_store(Vector3(8.0 + i * 0.9, UNDER, -540.45), 0.0, i + 12)
	_stores(Vector3(14.0, UNDER, -528.0), 3)
	_lay_flood()
	_dress_labs()
	_chunk("Kit", false)
	# --- the crossing before the containment hall
	_passage("cross", {"step": 5.96, "light": Color("ffd9c8"), "energy": 2.0, "reach": 10.0, "dead": [2, 7], "fail": [4], "tray": SOUTH})
	for x in [-4.0, 4.0]:
		_corner_post(Vector3(x, UNDER, -569.0), 5.0)
	_sign_board("cross", NORTH, 0.0, 4.15, [["EINDÄMMUNG  ·  NUR  MIT  SCHUTZAUSRÜSTUNG", GUIDE.hall]], 6.4, 30)
	_stencil("cross", NORTH, -10.0, 3.2, "E-01", 200, Color(0.5, 0.12, 0.1))
	_stencil("cross", NORTH, 10.0, 3.2, "STUFE  4", 130, Color(0.5, 0.12, 0.1))
	_hazard(Vector3(-4.0, UNDER + 0.008, -576.2), Vector3(4.0, UNDER + 0.008, -576.2), Vector3(0.5, 0.016, 0.4), 16)
	_sealed_door("cross", WEST, -573.0)
	_sealed_door("cross", EAST, -573.0)
	_stores(Vector3(-22.0, UNDER, -574.0), 3)
	_stores(Vector3(22.0, UNDER, -574.6), 3)
	_shared_dice()
	_end_zone()
	# --- the containment hall
	_own_dice(71011)
	_begin_zone("hall", "deep", ["research"])
	area = "hall"
	_room("containment", deep, Rect2(-30, -619, 60, 42), 14.0, "bighall", {"look": {"light": Color("ffe1c8"), "energy": 1.7, "lamp_gap": 12.0}})
	_door("cross", "containment", 0.0, 5.0, {"kind": "gate", "area": "hall", "name": "gate_hall", "height": 3.6})
	_chunk("Kit", false)
	for spot in [Vector3(-16, UNDER, -588), Vector3(16, UNDER, -588), Vector3(-16, UNDER, -606), Vector3(16, UNDER, -606)]:
		_vessel(spot, 3.4, 11.0, Color(1.0, 0.42, 0.3) if spot.x * (spot.z + 597.0) > 0.0 else Color(0.5, 1.0, 0.62))
	for spot in [Vector3(-6, UNDER, -584), Vector3(7, UNDER, -598), Vector3(-7, UNDER, -600), Vector3(0, UNDER, -590), Vector3(24, UNDER, -597), Vector3(-25, UNDER, -596), Vector3(-24, UNDER, -581), Vector3(24, UNDER, -581)]:
		_stores(spot, 3)
	for x in [-9.0, 9.0]:
		_pillar(Vector3(x, UNDER, -582.0), 0.9, 14.0)
		_pillar(Vector3(x, UNDER, -611.0), 0.9, 14.0)
	# The freight lift at the far end: a platform in a frame, lamps turning.
	var lift := Vector3(0, UNDER, -615.0)
	_part("tread", lift + Vector3(0, 0.03, 0), Vector3(6.0, 0.06, 6.0), Color(0.4, 0.42, 0.44))
	_hazard(lift + Vector3(-3.0, 0.065, 3.0), lift + Vector3(3.0, 0.065, 3.0), Vector3(0.5, 0.01, 0.3), 12)
	for corner in [Vector3(-3.1, 0, -3.1), Vector3(3.1, 0, -3.1), Vector3(-3.1, 0, 3.1), Vector3(3.1, 0, 3.1)]:
		_part("plate", lift + corner + Vector3(0, 3.0, 0), Vector3(0.3, 6.0, 0.3), Color("c9a227"))
		_add_shape(body, lift + corner + Vector3(0, 3.0, 0), Vector3(0.3, 6.0, 0.3))
	_part("plate", lift + Vector3(0, 6.1, 0), Vector3(6.5, 0.3, 6.5), Color("1c2023"))
	for x in [-2.6, 2.6]:
		_glow_box(lift + Vector3(x, 5.9, 3.1), Vector3(0.3, 0.2, 0.3), Color("ffb347"), 5.0)
		_light(lift + Vector3(x, 5.4, 3.3), Color("ffb347"), 1.6, 9.0, false, 0.5, 1.0, 70.0)
	var hall: Dictionary = room_of["containment"]
	_wall_sign("FRACHTAUFZUG  ·  EBENE  U3", _face_point(hall, NORTH, 0.0, 7.2, -0.05), 48, Color("c9a227"))
	_display(_face_point(hall, NORTH, 9.2, 2.3, 0.0), _model_yaw(NORTH), 3.4, "hall")
	_display(Vector3(6.4, UNDER, -583.6), 0.0, 2.6, "hall", "stele")
	_dress_hall()
	_wall_sign("EINDÄMMUNGSHALLE", _face_point(hall, SOUTH, 0.0, 6.2, -0.05), 56, Color("cfe6ff"), PI)
	_shared_dice()
	_end_zone()

## A sheet of standing water over a rectangle of a floor at `y`, `depth` metres deep. With
## `shore` (a side) it runs out to nothing along that edge of the rectangle, as on a
## beach. It is only there to be seen: everybody walks on the floor under it.
func _flood(plan: Rect2, y: float, depth: float, shore: int = -1) -> void:
	var kept := batch
	_chunk("Water", false)
	var high := y + depth
	var low := y - 0.02
	var north_west := Vector3(plan.position.x, low if shore == NORTH or shore == WEST else high, plan.position.y)
	var south_west := Vector3(plan.position.x, low if shore == SOUTH or shore == WEST else high, plan.end.y)
	var south_east := Vector3(plan.end.x, low if shore == SOUTH or shore == EAST else high, plan.end.y)
	var north_east := Vector3(plan.end.x, low if shore == NORTH or shore == EAST else high, plan.position.y)
	batch.quad(mats["flood"], north_west, south_west, south_east, north_east, Color.WHITE)
	batch = kept

## Water that drips from `pos` and falls `fall` metres.
func _drips(pos: Vector3, fall: float, amount: int = 5) -> void:
	if drip_look == null:
		drip_look = StandardMaterial3D.new()
		drip_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drip_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		drip_look.albedo_color = Color(0.72, 0.9, 0.95, 0.5)
		drip_mesh = QuadMesh.new()
		drip_mesh.size = Vector2(0.014, 0.16)
		drip_mesh.material = drip_look
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.1, 0.0, 0.1)
	process.direction = Vector3.DOWN
	process.spread = 2.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0, -9.8, 0)
	var drops := GPUParticles3D.new()
	drops.name = "Drips"
	drops.amount = amount
	drops.lifetime = sqrt(2.0 * fall / 9.8)
	drops.randomness = 1.0
	drops.process_material = process
	drops.draw_pass_1 = drip_mesh
	drops.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drops.visibility_aabb = AABB(Vector3(-0.6, -fall - 0.4, -0.6), Vector3(1.2, fall + 0.8, 1.2))
	drops.visibility_range_end = 45.0
	drops.position = pos
	add_child(drops)

## Sparks from something that is still live: a burst of them every `every` seconds, and
## a light that jumps.
func _sparks(pos: Vector3, every: float = 2.7) -> void:
	if spark_look == null:
		spark_look = StandardMaterial3D.new()
		spark_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark_look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		spark_look.vertex_color_use_as_albedo = true
		spark_look.albedo_color = Color(3.0, 2.2, 1.0)
		spark_mesh = QuadMesh.new()
		spark_mesh.size = Vector2(0.022, 0.07)
		spark_mesh.material = spark_look
		# A spark is gone long before the next burst.
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.16, 0.3, 1.0])
		fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.8, 0.45, 1), Color(1, 0.4, 0.1, 0), Color(1, 0.4, 0.1, 0)])
		spark_fade = GradientTexture1D.new()
		spark_fade.gradient = fade
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, -0.4, 0)
	process.spread = 75.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 3.6
	process.gravity = Vector3(0, -9.8, 0)
	process.color_ramp = spark_fade
	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 16
	sparks.lifetime = every
	sparks.explosiveness = 0.93
	sparks.randomness = 0.6
	sparks.process_material = process
	sparks.draw_pass_1 = spark_mesh
	sparks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.visibility_aabb = AABB(Vector3(-2.5, -4.5, -2.5), Vector3(5, 5.5, 5))
	sparks.visibility_range_end = 45.0
	sparks.position = pos
	add_child(sparks)
	_light(pos + Vector3(0, -0.2, 0), Color(1.0, 0.72, 0.4), 1.5, 5.0, false, 1.0, 0.6, LAMP_FADE)

## The flooded end of the research wing: water in the corridor from the cold store on, a
## laboratory whose glass front has burst into it, and one that still stands full behind
## its glass. (Built in the zone of the research wing, after its rooms.)
func _lay_flood() -> void:
	var depth := 0.3
	var surface := UNDER + depth
	var corridor: Dictionary = room_of["lab_corridor"]
	# --- the water: it runs out on the floor of the corridor like on a beach, stands in
	# the burst laboratory and in the crossing, and creeps under two doors
	_flood(Rect2(-3.8, -547.0, 7.6, 9.0), UNDER, depth, SOUTH)
	_flood(Rect2(-3.8, -568.8, 7.6, 21.8), UNDER, depth)
	_flood(Rect2(3.8, -568.8, 28.0, 13.6), UNDER, depth)
	_flood(Rect2(-8.0, -576.8, 16.0, 8.0), UNDER, depth)
	_flood(Rect2(-17.0, -576.8, 9.0, 7.6), UNDER, depth, WEST)
	_flood(Rect2(8.0, -576.8, 9.0, 7.6), UNDER, depth, EAST)
	_flood(Rect2(-2.5, -577.25, 5.0, 0.45), UNDER, depth)
	_flood(Rect2(-6.0, -585.0, 12.0, 7.75), UNDER, depth, NORTH)
	_flood(Rect2(-4.25, -552.0, 0.45, 2.0), UNDER, depth)
	_flood(Rect2(-8.5, -553.5, 4.25, 5.0), UNDER, depth, WEST)
	# --- the burst front: two posts, a rail under the lintel, and what is left of the glass
	for z in [-563.5, -560.5]:
		_part("plate", Vector3(4.0, UNDER + 2.18, z), Vector3(0.3, 4.36, 0.14), Color("1c2023"))
		_solid(Vector3(4.0, UNDER + 2.18, z), Vector3(0.3, 4.36, 0.14))
	_part("plate", Vector3(4.0, UNDER + 4.48, -562.0), Vector3(0.36, 0.24, 9.0), Color("1c2023"))
	_chunk("Shards", false)
	for i in range(15):
		var along := -566.3 + i * 0.62 + random.randf_range(-0.1, 0.1)
		var long := random.randf_range(0.2, 1.1)
		batch.triangle(mats["shard"], Vector3(4.0, UNDER + 4.36, along - 0.26), Vector3(4.0, UNDER + 4.36, along + 0.26), Vector3(4.0 + random.randf_range(-0.04, 0.04), UNDER + 4.36 - long, along + random.randf_range(-0.2, 0.2)))
	for foot in [-566.4, -563.7, -563.3, -560.7, -560.3, -557.6]:
		var lean := random.randf_range(-0.45, 0.45)
		batch.triangle(mats["shard"], Vector3(4.0, surface - 0.05, foot - 0.3), Vector3(4.0, surface - 0.05, foot + 0.3), Vector3(4.0, surface + random.randf_range(0.3, 1.0), foot + lean))
	_chunk("Kit", false)
	# --- the laboratory the water came out of: benches standing in it, what floats
	_lab_bench(Vector3(12.0, UNDER, -560.2), 5.0, 0.0, 1)
	_lab_bench(Vector3(22.5, UNDER, -564.6), 5.0, 0.0, 2)
	_lab_bench(Vector3(23.5, UNDER, -558.4), 5.0, 0.0, 3)
	_burst_tank(Vector3(30.2, UNDER, -560.4), "N-11")
	_burst_tank(Vector3(30.2, UNDER, -564.6), "N-12")
	_chunk("Kit", false)
	_lockers("flooded", NORTH, 6.0, 9.6, Color("9aa6a8"))
	for spot in [Vector3(7.5, 0, -561.5), Vector3(1.2, 0, -563.0), Vector3(-1.6, 0, -556.0), Vector3(15.5, 0, -557.4), Vector3(2.0, 0, -572.5), Vector3(-5.0, 0, -574.0), Vector3(19.0, 0, -566.8), Vector3(0.6, 0, -549.5)]:
		_papers(Transform3D(Basis(Vector3.UP, random.randf() * TAU), Vector3(spot.x, surface + 0.005, spot.z)), Vector3.ZERO, 6, 0.9)
	for entry in [[Vector3(9.0, 0, -565.0), 0.4], [Vector3(-2.3, 0, -560.6), 1.9], [Vector3(17.2, 0, -561.8), 2.7], [Vector3(3.2, 0, -574.6), 0.9]]:
		var at: Vector3 = entry[0]
		_model("cardboard_box_01", Vector3(at.x, surface - 0.2, at.z), float(entry[1]), {"scale": 1.5, "solid": false, "far": 35.0})
	for entry in [[Vector3(5.6, 0, -566.0), 0.3], [Vector3(-0.4, 0, -570.4), 2.2], [Vector3(27.0, 0, -561.5), 1.2]]:
		var at: Vector3 = entry[0]
		_model("plastic_crate_02", Vector3(at.x, surface - 0.13, at.z), float(entry[1]), {"scale": 1.5, "solid": false, "far": 35.0})
	_office_chair(Vector3(6.4, UNDER, -558.4), 0.8, true)
	_office_chair(Vector3(16.5, UNDER, -565.6), 2.4, true)
	_stool(Vector3(14.2, UNDER, -562.9), 1.2, true)
	_stool(Vector3(-0.8, UNDER, -566.2), 2.5, true)
	# Two chem lights somebody threw in.
	for entry in [[Vector3(10.6, 0, -557.2), 0.7], [Vector3(-1.8, 0, -571.6), 2.0]]:
		var at: Vector3 = entry[0]
		_glow_box(Vector3(at.x, surface + 0.02, at.z), Vector3(0.17, 0.026, 0.026), Color("7dff9a"), 4.6, Basis(Vector3.UP, float(entry[1])))
		_light(Vector3(at.x, surface + 0.4, at.z), Color(0.45, 1.0, 0.6), 1.0, 5.0, false, 0.0, 0.8, LAMP_FADE)
	# What still has power, and what comes through the ceiling.
	_hose(Vector3(4.3, UNDER + 4.36, -558.4), Vector3(4.7, UNDER + 2.7, -558.8), 0.02, Color("0d0d0d"), 0.35)
	_sparks(Vector3(4.7, UNDER + 2.68, -558.8))
	_hose(Vector3(-1.4, UNDER + 4.86, -549.4), Vector3(-1.7, UNDER + 3.5, -549.0), 0.02, Color("0d0d0d"), 0.3)
	_sparks(Vector3(-1.7, UNDER + 3.48, -549.0), 3.4)
	for entry in [[Vector3(0.9, 4.95, -553.2), 5], [Vector3(-2.1, 4.95, -562.2), 6], [Vector3(1.6, 4.95, -566.6), 4], [Vector3(10.0, 4.55, -563.4), 6], [Vector3(21.0, 4.55, -559.6), 5], [Vector3(3.4, 4.95, -573.2), 5]]:
		var at: Vector3 = entry[0]
		_drips(Vector3(at.x, UNDER + at.y, at.z), at.y - depth, int(entry[1]))
	# A pipe that has come apart in the north wall still runs.
	_pipe(Vector3(18.0, UNDER + 3.5, -568.75), Vector3(18.0, UNDER + 3.5, -568.1), 0.1, Color("6d6f6c"), 10, "steel")
	_drips(Vector3(18.0, UNDER + 3.42, -568.05), 3.1, 26)
	_blot(Vector3(18.0, surface - 0.006, -567.6), 0.7, 0.5, Color(0.7, 0.85, 0.85, 0.22))
	# --- the laboratory that is still full: water to above one's head behind the glass
	var level := 2.5
	_chunk("Glass", false)
	for at in [-551.5, -544.5]:
		_face_box(corridor, EAST, "stain", at - 2.95, at + 2.95, 0.62, level, 0.25, 0.27, Color(0.07, 0.5, 0.45, 0.2))
		_face_glow(corridor, EAST, at - 2.95, at + 2.95, level - 0.012, level + 0.012, 0.24, 0.28, Color("bff5ec"), 2.6)
	batch.quad(mats["skin"], Vector3(4.4, UNDER + level, -554.8), Vector3(4.4, UNDER + level, -541.2), Vector3(31.8, UNDER + level, -541.2), Vector3(31.8, UNDER + level, -554.8), Color.WHITE)
	# A crack in the southern pane, and what comes through it.
	for k in range(6):
		var turn := k * 1.05 + random.randf_range(-0.3, 0.3)
		var long := random.randf_range(0.25, 0.7)
		batch.box(mats["shard"], Vector3(3.97, UNDER + 1.9 + sin(turn) * long * 0.5, -545.2 + cos(turn) * long * 0.5), Vector3(0.004, 0.012, long), Color.WHITE, Basis(Vector3.RIGHT, -turn))
	_chunk("Kit", false)
	_face_box(corridor, EAST, "stain", -545.5, -544.9, 0.3, 0.6, -0.066, -0.064, Color(0.05, 0.2, 0.18, 0.5))
	_drips(Vector3(3.74, UNDER + 1.86, -545.2), 1.5, 7)
	var murk := FogVolume.new()
	murk.name = "Murk"
	murk.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	murk.size = Vector3(27.2, level, 13.2)
	var haze := FogMaterial.new()
	haze.density = 0.15
	haze.albedo = Color(0.25, 0.78, 0.72)
	haze.emission = Color(0.008, 0.06, 0.055)
	haze.edge_fade = 0.02
	murk.material = haze
	murk.position = Vector3(18.0, UNDER + level * 0.5, -548.0)
	add_child(murk)
	for x in [9.0, 18.5, 27.5]:
		_light(Vector3(x, UNDER + 1.3, -548.0), Color(0.3, 0.95, 0.85), 2.4, 9.5, false, 0.12, 2.0, LAMP_FADE + 8.0)
	_light(Vector3(14.0, UNDER + 4.0, -548.0), Color("cfe8e0"), 1.2, 8.0, false, 0.7, 0.5, LAMP_FADE)
	_lab_bench(Vector3(10.5, UNDER, -550.6), 5.0, 0.0, 1)
	_lab_bench(Vector3(20.0, UNDER, -545.4), 5.0, 0.0, 2)
	_lab_bench(Vector3(26.5, UNDER, -551.0), 5.0, 0.0, 3)
	_chunk("Kit", false)
	_shelf(Vector3(16.0, UNDER, -541.5), PI, 6.0, 0.5, 2.2, 4, Color("5d6468"), 0.5)
	# What the water carries: chairs that hang in it, boxes under its skin, a body.
	_stool(Vector3(13.0, UNDER + 1.2, -548.6), 0.6, true)
	_stool(Vector3(22.4, UNDER + 0.7, -550.2), 2.0, true)
	_lab_chair(Vector3(7.4, UNDER + 1.5, -545.6), 1.3, true)
	_lab_chair(Vector3(24.0, UNDER + 1.7, -546.4), 2.9, true)
	for entry in [[Vector3(6.6, level - 0.24, -552.4), 0.5], [Vector3(11.8, level - 0.24, -544.4), 1.8], [Vector3(19.6, level - 0.24, -551.6), 2.6]]:
		var at: Vector3 = entry[0]
		_model("cardboard_box_01", Vector3(at.x, UNDER + at.y, at.z), float(entry[1]), {"scale": 1.5, "solid": false, "far": 35.0})
	for entry in [[Vector3(8.0, 1.9, -547.0), 20.0], [Vector3(15.0, 1.1, -551.0), -35.0], [Vector3(17.5, 2.1, -545.0), 60.0], [Vector3(23.0, 1.4, -549.0), 15.0], [Vector3(11.0, 0.8, -546.5), -70.0]]:
		var at: Vector3 = entry[0]
		_papers(Transform3D(Basis.from_euler(Vector3(deg_to_rad(float(entry[1])), random.randf() * TAU, deg_to_rad(float(entry[1]) * 0.5))), Vector3(at.x, UNDER + at.y, at.z)), Vector3.ZERO, 4, 0.7)
	if not Engine.is_editor_hint():
		var body := LabSpecimen.create("normalzombie", "adrift", 0.9, 2.2, 0.0, 3.1)
		body.position = Vector3(7.6, UNDER + 0.3, -549.2)
		body.rotation.y = deg_to_rad(80.0)
		add_child(body)
	_sign_board("lab_corridor", EAST, -556.0, 3.6, [["NASSLABOR  ·  WASSEREINBRUCH", GUIDE.flood]], 2.9, 22)

# ---------------------------------------------------------------- what stands in the rooms

## A patch of haze in the air: mist over a floor, a halo around something that shines.
func _haze(centre: Vector3, size: Vector3, density: float, tint: Color = Color(0.78, 0.86, 0.95), drum: bool = false) -> void:
	var cloud := FogVolume.new()
	cloud.name = "Haze"
	cloud.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER if drum else RenderingServer.FOG_VOLUME_SHAPE_BOX
	cloud.size = size
	var mist := FogMaterial.new()
	mist.density = density
	mist.albedo = tint
	mist.edge_fade = 0.25
	cloud.material = mist
	cloud.position = centre
	add_child(cloud)

## The terminal: numbers on its pillars, a place to wait, freight nobody fetched.
func _dress_terminal() -> void:
	_chunk("Kit", false)
	var hall: Dictionary = room_of["terminal"]
	var gold := Color("c9a227")
	var number := 1
	for row in [-326.0, -334.0]:
		for x in [-30.0, -15.0, 15.0, 30.0]:
			_wall_sign("B%d" % number, Vector3(x, UNDER + 3.3, row + 0.458), 150, Color(0.13, 0.14, 0.15))
			number += 1
	_floor_text("SEKTOR  B", Vector3(0, UNDER, -325.4), 76, gold)
	for z in [-329.5, -337.0]:
		_floor_arrow(Vector3(0, UNDER, z), 0.0, gold, 1.4)
	for z in [-332.6, -329.4]:
		_bench(Vector3(-39.3, UNDER, z), PI / 2, 2.4)
	_house_prop("vending_machine", _face_point(hall, WEST, -336.4, 0.0, -0.62), PI / 2, {"far": 55.0})
	_light(_face_point(hall, WEST, -336.4, 1.5, -1.7), Color("bfe8ff"), 0.8, 5.0, false, 0.15, 0.4, LAMP_FADE)
	_plant(Vector3(-39.0, UNDER, -327.4), 1.5)
	_house_prop("gas_cylinder", Vector3(-35.6, UNDER, -327.4), 0.5, {"far": 45.0})
	_house_prop("gas_cylinder", Vector3(-34.5, UNDER, -328.3), 1.4, {"far": 45.0})
	_house_prop("generator", Vector3(18.5, UNDER, -338.4), 0.3, {"far": 45.0})
	_hose(Vector3(18.9, UNDER + 0.3, -338.7), Vector3(23.6, UNDER + 0.04, -339.3), 0.02, Color("0d0d0d"), 0.12)
	_house_prop("mop_trolley", Vector3(37.6, UNDER, -322.6), 2.2, {"far": 40.0})
	_barricade(Vector3(11.0, UNDER, -339.4), 0.15, 5.0)
	_blot(Vector3(8.0, UNDER, -337.6), 1.2, 0.8)
	_smear(Vector3(7.6, UNDER, -337.8), Vector3(2.4, UNDER, -343.6), 0.3)
	_litter(Vector3(-4.6, UNDER, -328.0), 1.8, 9)

## The station: benches, a machine that still glows, numbers on the pillars.
func _dress_station() -> void:
	_chunk("Kit", false)
	var platform: Dictionary = room_of["platform"]
	for x in [-25.5, -6.0]:
		_bench(Vector3(x, UNDER, -35.66), PI, 2.4)
	_house_prop("vending_machine", _face_point(platform, SOUTH, -21.8, 0.0, -0.62), PI, {"far": 55.0})
	_light(_face_point(platform, SOUTH, -21.8, 1.5, -1.7), Color("ffe2b0"), 0.9, 5.0, false, 0.2, 0.5, LAMP_FADE)
	_house_prop("mop_trolley", Vector3(16.6, UNDER, -36.3), 0.9, {"far": 40.0})
	for x in [-14.0, 16.0]:
		_floor_text("GLEIS  1", Vector3(x, UNDER, -52.7), 96, Color("c9a227"))
	for i in range(9):
		if i % 2 == 0:
			_wall_sign("A%d" % (i / 2 + 1), Vector3(-32.0 + i * 8.0, UNDER + 2.7, -48.592), 130, Color(0.13, 0.13, 0.12))
	_house_prop("generator", Vector3(-51.6, UNDER, -36.9), 0.4, {"far": 40.0})
	_house_prop("gas_cylinder", Vector3(-52.9, UNDER, -44.2), 0.9, {"far": 40.0})
	_litter(Vector3(4.0, UNDER, -46.0), 2.0, 8)
	_blot(Vector3(-3.0, UNDER, -44.4), 1.2, 0.8)
	_smear(Vector3(-3.4, UNDER, -44.8), Vector3(-8.6, UNDER, -53.6), 0.3)

## The central hall: lines on the floor to the three ways out, a desk before the core,
## plants and benches under the gallery, a halo around the shaft of light.
func _dress_atrium() -> void:
	_chunk("Kit", false)
	var teal: Color = GUIDE.research
	var cyan: Color = GUIDE.med
	var orange: Color = GUIDE.tech
	var routes := [
		[teal, [Vector2(-1.2, -445.4), Vector2(-1.2, -458.0), Vector2(-7.0, -458.0), Vector2(-7.0, -478.0), Vector2(-1.2, -478.0), Vector2(-1.2, -488.6)]],
		[cyan, [Vector2(-2.4, -445.4), Vector2(-2.4, -456.6), Vector2(-8.4, -456.6), Vector2(-8.4, -469.0), Vector2(-23.6, -469.0)]],
		[orange, [Vector2(1.2, -445.4), Vector2(1.2, -458.0), Vector2(8.4, -458.0), Vector2(8.4, -469.0), Vector2(23.6, -469.0)]]
	]
	for route in routes:
		var points: Array = route[1]
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			_stripe(Vector3(a.x, UNDER, a.y), Vector3(b.x, UNDER, b.y), 0.14, route[0])
	_floor_arrow(Vector3(-1.2, UNDER, -486.6), 0.0, teal)
	_floor_text("FORSCHUNG", Vector3(-3.6, UNDER, -486.4), 56, teal)
	_floor_arrow(Vector3(-21.6, UNDER, -469.0), PI / 2, cyan)
	_floor_text("KRANKENSTATION", Vector3(-17.4, UNDER, -468.2), 50, cyan)
	_floor_arrow(Vector3(21.6, UNDER, -469.0), -PI / 2, orange)
	_floor_text("TECHNIK", Vector3(18.4, UNDER, -468.2), 56, orange)
	# The desk before the core.
	var desk := Vector3(0, UNDER, -460.4)
	_part("steel", desk + Vector3(0, 0.52, 0), Vector3(5.2, 1.04, 0.7), Color("3a4146"))
	_part("plain", desk + Vector3(0, 1.065, 0), Vector3(5.4, 0.05, 0.9), Color("c9ccc8"))
	_part("plain", desk + Vector3(0, 0.6, 0.356), Vector3(5.0, 0.5, 0.012), Color("0d1114"))
	_glow_box(desk + Vector3(0, 0.1, 0.356), Vector3(5.0, 0.03, 0.014), Color("9fe0ff"), 2.6)
	_solid(desk + Vector3(0, 0.53, 0), Vector3(5.2, 1.06, 0.9))
	_wall_sign("INFORMATION", desk + Vector3(0, 0.6, 0.372), 34, Color("cfe6ff"))
	_monitor(Transform3D(Basis(Vector3.UP, PI), desk), Vector3(1.4, 1.09, 0.0), 8)
	_house_prop("crt_computer", desk + Vector3(1.5, 1.09, 0.05), PI, {"solid": false, "far": 30.0})
	_office_chair(desk + Vector3(0.7, 0, -1.2), 0.3, true)
	_litter(desk + Vector3(-1.6, 0, 1.6), 1.4, 8)
	for spot in [Vector2(-22.4, -455.0), Vector2(22.4, -455.0), Vector2(-22.4, -481.0), Vector2(22.4, -481.0)]:
		var at := Vector3(spot.x, UNDER, spot.y)
		_part("plate", at + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 3.0), Color("23282b"))
		_part("plain", at + Vector3(0, 0.585, 0), Vector3(0.84, 0.05, 2.84), Color("2a2118"))
		_solid(at + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 3.0))
		for k in [-0.7, 0.7]:
			_model("potted_plant_04", at + Vector3(0, 0.4, k), random.randf() * TAU, {"height": 1.2, "solid": false, "far": 40.0})
		_bench(at + Vector3(-signf(spot.x) * 1.0, 0, 0), -signf(spot.x) * PI / 2, 2.4)
	_door_tag("atrium", WEST, -467.45, "M-01", "KRANKENSTATION", cyan.lightened(0.3))
	_door_tag("atrium", EAST, -466.9, "T-01", "TECHNIK", orange.lightened(0.3))
	# Cover the C.R.U. left behind when it took the hall.
	_barricade(Vector3(-9.6, UNDER, -464.4), PI / 2, 4.0)
	_barricade(Vector3(10.6, UNDER, -473.8), PI / 2, 4.0)
	_blot(Vector3(-11.0, UNDER, -466.0), 1.1, 0.8)
	_blot(Vector3(4.0, UNDER, -474.0), 1.4, 1.0, Color(0.02, 0.02, 0.02, 0.66))
	_stencil("atrium", WEST, -467.0, 8.6, "B2", 400)
	_stencil("atrium", EAST, -467.0, 8.6, "B2", 400)
	_haze(Vector3(0, UNDER + 6.0, -467.0), Vector3(13.0, 12.0, 13.0), 0.03, Color(0.7, 0.88, 1.0), true)

## The sick bay: a screen at every bed, most of them a flat line; a table under a lamp.
func _dress_med() -> void:
	_chunk("Kit", false)
	for i in range(4):
		var z := -476.0 + i * 4.4
		var stand := Vector3(-47.1, UNDER, z - 0.85)
		_pipe(stand, stand + Vector3(0, 1.45, 0), 0.02, Color("9aa0a3"), 6, "steel")
		batch.cylinder(mats["steel"], stand, 0.18, 0.16, 0.04, Color("3a3f42"), 10)
		_part("plain", stand + Vector3(0.02, 1.5, 0), Vector3(0.06, 0.34, 0.46), Color("0c0e0f"))
		_screen(Transform3D(Basis(Vector3.UP, PI / 2), stand + Vector3(0.056, 1.5, 0)), Vector3.ZERO, Vector2(0.4, 0.28), 1, 0.2 if i == 2 else 0.6 + i * 0.1)
		var drip := Vector3(-46.9, UNDER, z + 0.75)
		_pipe(drip, drip + Vector3(0, 1.9, 0), 0.015, Color("9aa0a3"), 6, "steel")
		_part("plain", drip + Vector3(0.08, 1.7, 0), Vector3(0.1, 0.24, 0.14), Color(0.75, 0.82, 0.8))
	_bed(Vector3(-35.0, UNDER, -470.6), PI / 2, Color("b8c2c0"))
	_blot(Vector3(-35.0, UNDER, -469.0), 0.9, 0.7)
	_smear(Vector3(-34.2, UNDER, -468.8), Vector3(-25.4, UNDER, -468.9), 0.3)
	batch.cylinder(mats["steel"], Vector3(-35.0, UNDER + 2.9, -470.6), 0.5, 0.42, 0.14, Color("c4c8c4"), 14)
	_pipe(Vector3(-35.0, UNDER + 3.04, -470.6), Vector3(-35.0, UNDER + 3.6, -470.6), 0.03, Color("9aa0a3"), 6, "steel")
	_glow_box(Vector3(-35.0, UNDER + 2.895, -470.6), Vector3(0.6, 0.012, 0.6), Color("f2fbff"), 5.0)
	_spot(Vector3(-35.0, UNDER + 2.85, -470.6), Vector3.DOWN, Color("f2fbff"), 6.0, 5.0, 50.0, 0.25, 0.9, LAMP_FADE)
	_lockers("med", SOUTH, -40.0, -36.0, Color("d0d6d4"))
	_table(Vector3(-25.4, UNDER, -474.6), Vector3(0.9, 0.78, 2.2), Color("8a9092"))
	_house_prop("crt_computer", Vector3(-25.3, UNDER + 0.78, -474.9), -PI / 2, {"solid": false, "far": 30.0})
	_office_chair(Vector3(-26.7, UNDER, -474.4), PI / 2)
	_house_prop("mop_trolley", Vector3(-29.0, UNDER, -460.6), 1.9, {"far": 40.0})
	_litter(Vector3(-37.0, UNDER, -464.0), 1.4, 7)
	_board("med", NORTH, -29.0, 2.2)

## The plant rooms: valves, a small generator somebody carried in, water under the pumps.
func _dress_tech() -> void:
	_chunk("Kit", false)
	var orange: Color = GUIDE.tech
	_house_prop("pipe_valve", Vector3(40.75, UNDER, -449.6), PI / 2, {"far": 40.0})
	_house_prop("pipe_valve", Vector3(59.25, UNDER, -462.0), -PI / 2, {"far": 40.0})
	_house_prop("generator", Vector3(53.2, UNDER, -448.4), 2.6, {"far": 40.0})
	_hose(Vector3(52.8, UNDER + 0.35, -448.1), Vector3(51.6, UNDER + 0.9, -445.8), 0.022, Color("0d0d0d"), 0.25)
	for k in range(2):
		_part("plain", Vector3(54.6 + k * 0.5, UNDER + 0.2, -447.0), Vector3(0.3, 0.4, 0.2), Color("a02a22"), Vector3(0, 20.0 + k * 35.0, 0))
	_house_prop("gas_cylinder", Vector3(41.1, UNDER, -463.6), 0.4, {"far": 40.0})
	_house_prop("gas_cylinder", Vector3(42.1, UNDER, -464.6), 1.9, {"far": 40.0})
	_part("plate", Vector3(50.0, UNDER + 5.3, -451.0), Vector3(19.4, 0.5, 1.1), Color("3a3f42"))
	for x in [42.0, 50.0, 58.0]:
		_part("plate", Vector3(x, UNDER + 5.775, -451.0), Vector3(0.08, 0.45, 1.2), Color("1d2124"))
	_floor_text("NOTSTROM", Vector3(50.0, UNDER, -450.6), 80, orange)
	_stencil("generator", WEST, -456.0, 3.4, "G-01", 180, Color(0.8, 0.62, 0.2))
	_stencil("generator", EAST, -456.0, 3.4, "G-02", 180, Color(0.8, 0.62, 0.2))
	_blot(Vector3(47.6, UNDER, -451.8), 1.4, 1.0, Color(0.03, 0.03, 0.02, 0.72))
	# The pump room: the water that stands in it runs out at the door.
	_flood(Rect2(40.2, -475.2, 19.6, 3.0), UNDER, 0.08, SOUTH)
	_flood(Rect2(40.2, -490.8, 19.6, 15.6), UNDER, 0.08)
	_house_prop("pipe_valve", Vector3(50.0, UNDER, -490.2), 0.0, {"far": 40.0})
	_house_prop("pipe_valve", Vector3(59.25, UNDER, -481.2), -PI / 2, {"far": 40.0})
	_stencil("pump", WEST, -481.2, 3.4, "P-01", 180, Color(0.5, 0.75, 0.68))
	_drips(Vector3(47.2, UNDER + 5.9, -480.4), 5.8, 6)
	_drips(Vector3(54.0, UNDER + 5.9, -484.4), 5.8, 5)
	var pump: Dictionary = room_of["pump"]
	_face_box(pump, EAST, "steel", -476.8, -474.6, 0.0, 2.0, -0.4, 0.0, Color("2c3236"))
	for k in range(4):
		_face_box(pump, EAST, "plain", -476.6 + k * 0.5, -476.3 + k * 0.5, 0.9, 1.7, -0.412, -0.4, Color("1b1f22"))
		_led(_face_point(pump, EAST, -476.45 + k * 0.5, 1.85, -0.406), Vector3(0.012, 0.07, 0.07), Color("5ee07a") if k % 2 == 0 else Color("ffb347"), 3.0, 0.4 + k * 0.15)
	_solid(_face_centre(pump, EAST, -476.8, -474.6, 0.0, 2.0, -0.4, 0.0), _face_size(EAST, -476.8, -474.6, 0.0, 2.0, -0.4, 0.0))

## The laboratories: a fume hood in each, the house's own computers and microscopes,
## two more tanks; frost in the cold store; warning paint in quarantine and sluice.
func _dress_labs() -> void:
	_chunk("Kit", false)
	for lab in [["lab_a", -17.0, -510.0, WEST], ["lab_b", -17.0, -528.0, WEST], ["lab_c", 15.0, -510.0, EAST]]:
		var room: Dictionary = room_of[lab[0]]
		var mid := Vector3(float(lab[1]), UNDER, float(lab[2]))
		var side: int = lab[3]
		var out := 1.0 if side == WEST else -1.0
		_face_box(room, side, "steel", mid.z - 1.1, mid.z + 1.1, 0.0, 0.92, -0.85, -0.05, Color("c6cac3"))
		_face_box(room, side, "steel", mid.z - 1.1, mid.z + 1.1, 2.0, 2.5, -0.85, -0.05, Color("c6cac3"))
		for edge in [-1.0, 1.0]:
			_face_box(room, side, "steel", mid.z + edge * 1.05 - 0.05, mid.z + edge * 1.05 + 0.05, 0.92, 2.0, -0.85, -0.05, Color("b4b9b4"))
		_face_box(room, side, "plain", mid.z - 1.0, mid.z + 1.0, 0.92, 2.0, -0.1, -0.05, Color("1a1d1f"))
		_face_glow(room, side, mid.z - 0.9, mid.z + 0.9, 1.97, 2.0, -0.7, -0.3, Color("c8ffe0"), 3.4)
		_chunk("Glass", false)
		batch.box(mats["pane"], _face_centre(room, side, mid.z - 1.0, mid.z + 1.0, 1.35, 2.0, -0.83, -0.81), _face_size(side, mid.z - 1.0, mid.z + 1.0, 1.35, 2.0, -0.83, -0.81), Color.WHITE)
		_chunk("Kit", false)
		_solid(_face_centre(room, side, mid.z - 1.1, mid.z + 1.1, 0.0, 2.5, -0.85, 0.0), _face_size(side, mid.z - 1.1, mid.z + 1.1, 0.0, 2.5, -0.85, 0.0))
		_light(_face_point(room, side, mid.z, 1.6, -0.6), Color(0.7, 1.0, 0.85), 0.8, 4.0, false, 0.0, 0.4, LAMP_FADE)
		_house_prop("crt_computer", mid + Vector3(-5.6, 1.05, -5.0), 0.0, {"solid": false, "far": 30.0})
		_house_prop("microscope_c", mid + Vector3(2.6, 1.05, 5.0), 2.1, {"solid": false, "far": 25.0})
		_house_prop("gas_cylinder", mid + Vector3(10.2 * out, 0, 8.2), 0.6, {"far": 35.0})
		_stool(mid + Vector3(-1.2, 0, -3.4), 0.7, true)
		_litter(mid + Vector3(0.6, 0, 2.4), 1.2, 7)
	_blot(Vector3(-10.6, UNDER, -512.6), 1.0, 0.7)
	_smear(Vector3(-10.0, UNDER, -512.2), Vector3(-5.0, UNDER, -510.2), 0.3)
	_tank(Vector3(-14.0, UNDER, -535.8), "B-01", "striker", "curled", 40.0, 0.5, false, 0.15)
	_tank(Vector3(-11.2, UNDER, -535.8), "B-02", "leech", "adrift", 200.0, 0.7, true, 0.1)
	_chunk("Kit", false)
	# --- the cold store: frost over the floor, a light along the cabinets, vessels of nitrogen
	_haze(Vector3(16.0, UNDER + 0.45, -530.0), Vector3(23.4, 0.9, 21.4), 0.09, Color(0.8, 0.92, 1.0))
	_glow_box(Vector3(26.9, UNDER + 0.012, -526.95), Vector3(0.05, 0.012, 10.7), Color("7fd0ff"), 3.0)
	_glow_box(Vector3(11.15, UNDER + 0.012, -539.9), Vector3(7.1, 0.012, 0.05), Color("7fd0ff"), 3.0)
	for spot in [Vector2(18.4, -539.3), Vector2(19.6, -539.6), Vector2(21.0, -539.2), Vector2(5.2, -522.4)]:
		var base := Vector3(spot.x, UNDER, spot.y)
		batch.cylinder(mats["steel"], base, 0.3, 0.3, 0.86, Color("c4c8c4"), 14)
		batch.cylinder(mats["steel"], base + Vector3(0, 0.86, 0), 0.3, 0.12, 0.14, Color("b4b9b4"), 14)
		batch.cylinder(mats["plain"], base + Vector3(0, 1.0, 0), 0.12, 0.12, 0.08, Color("23282b"), 10)
		_round_solid(base, 0.3, 1.0)
	_house_prop("gas_cylinder", Vector3(5.1, UNDER, -520.3), 0.9, {"far": 35.0})
	_stencil("cryo", NORTH, 20.4, 3.0, "-196 °C", 150, Color(0.2, 0.42, 0.62))
	# --- quarantine: paint around the cell
	_hazard(Vector3(-20.6, UNDER + 0.008, -545.45), Vector3(-9.6, UNDER + 0.008, -545.45), Vector3(0.5, 0.016, 0.3), 22)
	_hazard(Vector3(-20.6, UNDER + 0.008, -556.55), Vector3(-9.6, UNDER + 0.008, -556.55), Vector3(0.5, 0.016, 0.3), 22)
	_hazard(Vector3(-20.6, UNDER + 0.008, -556.2), Vector3(-20.6, UNDER + 0.008, -545.8), Vector3(0.3, 0.016, 0.47), 22)
	_stencil("quarantine", NORTH, -16.0, 3.5, "QUARANTÄNE", 150, Color(0.5, 0.12, 0.1))
	# --- the sluice: light that kills, haze, a word on the wall
	var decon: Dictionary = room_of["decon"]
	for side in [WEST, EAST]:
		for high in [0.5, 2.2]:
			_face_glow(decon, side, -500.4, -489.6, high, high + 0.04, -0.06, -0.047, Color("b08cff"), 3.0)
	_stencil("decon", WEST, -495.0, 3.25, "DEKONTAMINATION", 76, Color(0.2, 0.42, 0.44))
	_stencil("decon", EAST, -495.0, 3.25, "SCHLEUSE  B2 · 06", 76, Color(0.2, 0.42, 0.44))
	_haze(Vector3(0, UNDER + 1.4, -495.0), Vector3(7.4, 2.8, 11.4), 0.04, Color(0.8, 0.82, 1.0))

## The containment hall: a service bridge hung from the roof and a walk around every
## vessel (nobody gets up there), a desk before each of them, mist over the floor.
func _dress_hall() -> void:
	_chunk("Kit", false)
	var steel := Color("23282b")
	var top := UNDER + 7.0
	var across := -596.4
	_part("tread", Vector3(0, top - 0.06, across), Vector3(59.4, 0.12, 1.8), Color(0.34, 0.36, 0.38))
	for edge in [-1.0, 1.0]:
		_part("plate", Vector3(0, top + 1.0, across + edge * 0.88), Vector3(59.4, 0.05, 0.05), steel)
		_part("plate", Vector3(0, top + 0.5, across + edge * 0.88), Vector3(59.4, 0.035, 0.035), steel)
		for i in range(11):
			var x := -27.0 + i * 5.4
			_part("plate", Vector3(x, top + 0.5, across + edge * 0.88), Vector3(0.05, 1.0, 0.05), steel)
			_part("plate", Vector3(x, top + 4.0, across + edge * 0.88), Vector3(0.045, 6.0, 0.045), steel)
	var number := 1
	for spot in [Vector2(-16, -588), Vector2(16, -588), Vector2(-16, -606), Vector2(16, -606)]:
		var out := signf(spot.x)
		var near := 1.0 if spot.y > across else -1.0
		for edge in [-1.0, 1.0]:
			_part("tread", Vector3(spot.x, top - 0.06, spot.y + edge * 4.28), Vector3(9.2, 0.12, 0.64), Color(0.34, 0.36, 0.38))
			_part("tread", Vector3(spot.x + edge * 4.28, top - 0.06, spot.y), Vector3(0.64, 0.12, 7.92), Color(0.34, 0.36, 0.38))
			_part("plate", Vector3(spot.x, top + 1.0, spot.y + edge * 4.57), Vector3(9.2, 0.05, 0.05), steel)
			_part("plate", Vector3(spot.x + edge * 4.57, top + 1.0, spot.y), Vector3(0.05, 0.05, 9.2), steel)
			for corner in [-1.0, 1.0]:
				_part("plate", Vector3(spot.x + corner * 4.57, top + 0.5, spot.y + edge * 4.57), Vector3(0.05, 1.0, 0.05), steel)
		# The way from the walk to the bridge.
		var from: float = spot.y - near * 4.6
		var to := across + near * 0.9
		_part("tread", Vector3(spot.x, top - 0.06, (from + to) * 0.5), Vector3(1.2, 0.12, absf(from - to)), Color(0.34, 0.36, 0.38))
		# A desk that watches the vessel, a hose to it, its number on the floor.
		var desk := Vector3(spot.x - out * 6.2, UNDER, spot.y)
		var frame := Transform3D(Basis(Vector3.UP, -out * PI / 2), desk)
		_placed(frame, "steel", Vector3(0, 0.5, 0), Vector3(1.1, 1.0, 0.5), Color("2f3539"))
		_placed(frame, "steel", Vector3(0, 1.06, 0.0), Vector3(1.14, 0.12, 0.54), Color("454c51"))
		_placed(frame, "plain", Vector3(0, 1.2215, 0.0102), Vector3(0.92, 0.46, 0.03), Color("0c0e0f"), Vector3(-62, 0, 0))
		_screen(frame, Vector3(0, 1.24, 0.02), Vector2(0.86, 0.4), 9 if number % 2 == 0 else 1, 0.1 + number * 0.08, 62.0)
		for k in range(4):
			_led(frame * Vector3(-0.36 + k * 0.24, 0.84, 0.256), Vector3(0.05, 0.05, 0.012), [Color("5ee07a"), Color("ffb347"), Color("ff3a2a"), Color("5ee07a")][k], 3.0, [1.0, 0.7, 0.4, 0.3][k], frame.basis)
		_solid(desk + Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 1.2))
		_hose(Vector3(spot.x - out * 3.8, UNDER + 0.07, spot.y + 0.6), desk + Vector3(out * 0.3, 0.07, 0.3), 0.06, Color("15171a"), 0.0, Vector3(0, 0, 1.1), 7)
		_floor_text("V-0%d" % number, Vector3(spot.x - out * 8.6, UNDER, spot.y), 96, Color("c9a227"), -out * PI / 2)
		number += 1
	for x in [-9.0, 9.0]:
		for z in [-582.0, -611.0]:
			for face in [-1.0, 1.0]:
				_glow_box(Vector3(x + face * 0.456, UNDER + 4.2, z), Vector3(0.012, 0.5, 0.2), Color("ff3a2a"), 3.4)
	_haze(Vector3(0, UNDER + 0.7, -598.0), Vector3(59.0, 1.4, 41.0), 0.05, Color(0.76, 0.8, 0.9))
	var hall: Dictionary = room_of["containment"]
	for side in [WEST, EAST]:
		if _house_prop("steel_door", _face_point(hall, side, -586.0, 0.0, -0.56), _model_yaw(side), {"far": 70.0}) != null:
			_face_glow(hall, side, -586.3, -585.7, 2.5, 2.56, -0.2, -0.17, Color("ff3a2a"), 3.0)
			_stencil("containment", side, -586.0, 3.5, "LAGER  U3", 96, Color(0.5, 0.12, 0.1))

# ---------------------------------------------------------------- after the build

## Views for the pictures of a check: [name, where the survivor stands, what he looks at],
## or with a fourth entry true: seen from a free camera at the second place.
func tour() -> Array:
	return [
		["01_park_from_lz", Vector3(0, 0, 80), Vector3(0, 6, 22)],
		["02_park_air", Vector3(52, 46, 112), Vector3(0, 0, 30), true],
		["03_forecourt", Vector3(6, 0, 36), Vector3(-4, 5, 22)],
		["04_terrace_east", Vector3(22, 0, 31), Vector3(44, 2, 25)],
		["05_tower", Vector3(-22, 0, 38), Vector3(-28, 9, 18)],
		["06_hall_in", Vector3(0, 0, 20.5), Vector3(0, 3.2, 9)],
		["07_hall_back", Vector3(0, 0, 10.5), Vector3(0, 2.5, 22)],
		["08_gallery", Vector3(0, STOREY_VILLA, 10), Vector3(0, 1.5, 20)],
		["09_salon", Vector3(-9, 0, 20.5), Vector3(-22, 1.2, 13)],
		["10_galerie", Vector3(9, 0, 20.5), Vector3(22, 1.4, 12)],
		["11_library", Vector3(-11.4, 0, 0.2), Vector3(-22, 1.3, 5.5)],
		["12_dining", Vector3(-8, 0, 6.6), Vector3(6, 1.2, -3.5)],
		["13_dining_mirror", Vector3(0, 0, 6.5), Vector3(0, 1.6, -3.8)],
		["14_kitchen", Vector3(11.5, 0, 6.5), Vector3(22, 1.2, -3)],
		["15_rear", Vector3(-12, 0, -16), Vector3(0, 3, -4)],
		["16_supply", Vector3(-7, 0, 66), Vector3(-13.5, 1.2, 70)],
		["16b_gate_post", Vector3(-3.5, 0, 76.5), Vector3(7.5, 1.6, 85.5)],
		["16c_round", Vector3(-8.5, 0, 55.5), Vector3(5, 1.0, 40)],
		["16d_porch", Vector3(6.5, 0, 31.5), Vector3(-1, 4.6, 22)],
		["16e_breach", Vector3(-27, 0, 78), Vector3(-36, 0.8, 88)],
		["20_vestibule", Vector3(0, 0, -5.0), Vector3(0, -3.0, -18.0)],
		["20b_stairs_top", Vector3(0, -1.2, -11.5), Vector3(0, -4.4, -17.6)],
		["20c_stairs_upper", Vector3(0, -3.3, -15.1), Vector3(0, -4.2, -19.5)],
		["21_stairs_down", Vector3(0, UNDER * 0.5, -19.0), Vector3(0, UNDER + 1.2, -34.0)],
		["22_stairs_up", Vector3(0, UNDER, -31.5), Vector3(0, -3.0, -17.0)],
		["23_platform_in", Vector3(0, UNDER, -37.5), Vector3(4, UNDER + 2.0, -57.0)],
		["24_platform_east", Vector3(-30, UNDER, -44.0), Vector3(30, UNDER + 2.4, -50.0)],
		["25_platform_west", Vector3(32, UNDER, -46.0), Vector3(-30, UNDER + 2.0, -48.0)],
		["26_train", Vector3(-9, UNDER, -47.0), Vector3(8, UNDER + 1.4, -57.0)],
		["27_car_inside", Vector3(-5.5, UNDER, -57.0), Vector3(6.5, UNDER + 1.4, -57.2)],
		["28_booth", Vector3(26.5, UNDER, -30.0), Vector3(33.0, UNDER + 1.2, -35.0)],
		["29_supply_station", Vector3(-12, UNDER, -42.0), Vector3(-14, UNDER + 1.2, -35.5)],
		["30_airlock", Vector3(-34, UNDER, -46.5), Vector3(-41, UNDER + 1.4, -49.5)],
		["31_depot", Vector3(42, UNDER, -53.0), Vector3(52, UNDER + 1.2, -44.0)],
		["40_terminal_arrive", Vector3(0, UNDER, -320.5), Vector3(0, UNDER + 3.0, -345.0)],
		["41_terminal_west", Vector3(30, UNDER, -324.0), Vector3(-25, UNDER + 3.0, -340.0)],
		["42_terminal_deck", Vector3(-10, DECK, -343.0), Vector3(20, UNDER + 1.0, -322.0)],
		["43_control", Vector3(24.0, DECK, -343.0), Vector3(36.0, DECK + 1.2, -339.5)],
		["44_checkpoint", Vector3(0, UNDER, -346.5), Vector3(0, UNDER + 1.6, -366.0)],
		["45_guard", Vector3(7.5, UNDER, -358.5), Vector3(14.0, UNDER + 1.2, -353.0)],
		["46_ring_east", Vector3(-40, UNDER, -365.0), Vector3(40, UNDER + 1.6, -365.0)],
		["46b_ring_junction", Vector3(-9, UNDER, -362.5), Vector3(4, UNDER + 2.2, -369.0)],
		["47_office", Vector3(-31.2, UNDER, -370.4), Vector3(-37.0, UNDER + 0.7, -389.0)],
		["48_meeting", Vector3(-14.5, UNDER, -370.5), Vector3(-6, UNDER + 1.2, -380.0)],
		["49_security", Vector3(14, UNDER, -371.0), Vector3(22, UNDER + 1.8, -385.0)],
		["50_server", Vector3(36.5, UNDER, -370.5), Vector3(36.5, UNDER + 1.4, -392.0)],
		["51_archive", Vector3(-25.5, UNDER, -394.5), Vector3(-42, UNDER + 1.2, -407.0)],
		["52_staff", Vector3(-6, UNDER, -394.5), Vector3(-20, UNDER + 1.0, -404.0)],
		["53_spine", Vector3(0, UNDER, -371.0), Vector3(0, UNDER + 1.6, -405.0)],
		["54_canteen", Vector3(0, UNDER, -406.5), Vector3(8, UNDER + 1.6, -434.0)],
		["55_canteen_back", Vector3(-19.5, UNDER, -431.5), Vector3(20, UNDER + 1.4, -408.0)],
		["56_kitchen", Vector3(25.5, UNDER, -409.0), Vector3(36, UNDER + 1.0, -421.0)],
		["57_atrium_in", Vector3(0, UNDER, -447.0), Vector3(0, UNDER + 4.5, -470.0)],
		["58_atrium_deck", Vector3(-21.5, DECK, -447.2), Vector3(6, UNDER + 2.0, -470.0)],
		["59_atrium_supply", Vector3(-10, UNDER, -451.0), Vector3(-12, UNDER + 1.2, -445.5)],
		["60_med", Vector3(-26, UNDER, -469.0), Vector3(-45, UNDER + 1.0, -474.0)],
		["61_maint", Vector3(26, UNDER, -469.0), Vector3(58, UNDER + 1.6, -469.0)],
		["62_generator", Vector3(50, UNDER, -464.0), Vector3(48, UNDER + 1.6, -446.0)],
		["63_pump", Vector3(50, UNDER, -474.0), Vector3(52, UNDER + 1.6, -490.0)],
		["64_decon", Vector3(0, UNDER, -490.5), Vector3(0, UNDER + 1.6, -501.0)],
		["65_lab_corridor", Vector3(0, UNDER, -502.5), Vector3(0, UNDER + 1.6, -569.0)],
		["66_lab_a", Vector3(-6, UNDER, -510.0), Vector3(-24, UNDER + 1.0, -512.0)],
		["67_lab_glass", Vector3(1.5, UNDER, -520.0), Vector3(-18, UNDER + 1.2, -529.0)],
		["68_quarantine", Vector3(-6, UNDER, -551.0), Vector3(-26, UNDER + 1.4, -548.0)],
		["69_cryo", Vector3(6, UNDER, -530.0), Vector3(26, UNDER + 1.2, -527.0)],
		["70_flooded", Vector3(0.6, UNDER, -548.5), Vector3(3.2, UNDER + 1.0, -566.0)],
		["70b_sunken", Vector3(-2.7, UNDER, -547.0), Vector3(12.0, UNDER + 1.6, -548.6)],
		["70c_wet_lab", Vector3(5.6, UNDER, -562.0), Vector3(28.0, UNDER + 1.2, -562.6)],
		["70d_shore", Vector3(0, UNDER, -532.5), Vector3(0, UNDER + 0.9, -560.0)],
		["70e_front", Vector3(-2.8, UNDER, -565.5), Vector3(8.0, UNDER + 1.5, -560.0)],
		["71_cross", Vector3(0, UNDER, -566.0), Vector3(0, UNDER + 1.8, -577.0)],
		["71b_cross_east", Vector3(-20, UNDER, -573.0), Vector3(20, UNDER + 1.8, -573.4)],
		["72_hall_in", Vector3(0, UNDER, -579.0), Vector3(0, UNDER + 5.0, -612.0)],
		["73_hall_side", Vector3(-27, UNDER, -598.0), Vector3(14, UNDER + 4.0, -600.0)],
		["74_lift", Vector3(0, UNDER, -604.0), Vector3(0, UNDER + 2.5, -616.0)],
		["75_lab_tables", Vector3(-9.0, UNDER, -514.5), Vector3(-22.0, UNDER + 1.0, -508.5)],
		["76_work_place", Vector3(-21.0, UNDER, -511.5), Vector3(-27.4, UNDER + 1.1, -514.6)],
		["77_microscope", Vector3(-20.7, UNDER, -513.5), Vector3(-21.6, UNDER + 1.2, -515.0)],
		["78_sealed_door", Vector3(37.5, UNDER, -365.0), Vector3(44.0, UNDER + 1.2, -365.0)],
		["80_plan_terminal", Vector3(-5.6, UNDER, -331.6), Vector3(-5.6, UNDER + 1.9, -336.0)],
		["81_plan_atrium", Vector3(0, UNDER, -474.0), Vector3(0, UNDER + 7.4, -489.0)],
		["82_plan_labs", Vector3(0, UNDER, -505.0), Vector3(0, UNDER + 3.4, -512.5)],
		["83_plan_spine", Vector3(-2.2, UNDER, -379.4), Vector3(3.8, UNDER + 1.9, -378.1)],
		["84_plan_station", Vector3(2.0, UNDER, -37.0), Vector3(5.2, UNDER + 1.7, -40.4)],
		["85_terminal_wait", Vector3(-30.0, UNDER, -331.0), Vector3(-40.0, UNDER + 1.0, -333.5)],
		["86_reception", Vector3(-3.5, UNDER, -453.0), Vector3(1.0, UNDER + 1.0, -462.0)],
		["87_hall_bridge", Vector3(-4.0, UNDER, -590.0), Vector3(-18.0, UNDER + 6.0, -604.0)],
		["88_cold_frost", Vector3(6.5, UNDER, -527.0), Vector3(22.0, UNDER + 0.8, -536.0)],
		["89_hood", Vector3(-12.0, UNDER, -506.5), Vector3(-27.5, UNDER + 1.3, -510.0)],
		["17_post", Vector3(-1.0, 0, 14.5), Vector3(-5.2, 0.9, 9.4)],
		["18_beams", Vector3(0, 0, 62.0), Vector3(0, 3.0, 26.0)]
	]

## Starts or ends what is seen from the car while the train runs: the terminal is not
## drawn, a tunnel with lamps is, and the lamps pass by.
func ride(on: bool) -> void:
	riding = on
	ride_speed = 26.0 if on else 0.0
	force_zone("tunnel", "show" if on else "")
	force_zone("terminal", "hide" if on else "")

func reset() -> void:
	super.reset()
	riding = false
	set_alarm(false)

func _process(delta: float) -> void:
	super._process(delta)
	if alarm_on:
		var beat := 0.7 + 0.3 * sin(clock * 5.4)
		for lamp in alarm_lamps:
			lamp.light_energy = 3.4 * beat
	if riding:
		ride_way += ride_speed * delta
		for index in range(ride_lamps.size()):
			ride_lamps[index].position.x = 35.0 - fposmod(index * 8.75 + ride_way, 70.0)

func _after_build() -> void:
	# The fluid of the tanks stands on the floor of the facility here, not of a cellar.
	(mats["fluid"] as ShaderMaterial).set_shader_parameter("low", UNDER + TANK_LOW)
	(mats["wet"] as ShaderMaterial).set_shader_parameter("low", UNDER + TANK_LOW)
	# The mirror hangs on the piece of wall that slides aside.
	if door_of.has("mirror") and not (door_of["mirror"].leaves as Array).is_empty():
		var leaf: Node3D = door_of["mirror"].leaves[0]
		var mirror := _model("ornate_mirror_01", Vector3.ZERO, 0.0, {"height": 2.3, "solid": false, "far": 40.0})
		mirror.get_parent().remove_child(mirror)
		leaf.add_child(mirror)
		mirror.position = Vector3(0, 0.25, HALF + 0.13)
	points = {
		"landing": Vector3(0, 0, 68), "landing_out": Vector3(0, 0, 61.5), "supply_lz": Vector3(-11.5, 0, 70), "forecourt": Vector3(0, 0, 32), "front_door": Vector3(0, 0, 23.6),
		"hall": Vector3(0, 0, 16), "gallery": Vector3(0, STOREY_VILLA, 10), "salon": Vector3(-14, 0, 14), "galerie": Vector3(15.5, 0, 12),
		"library": Vector3(-14, 0, 5.5), "kitchen": Vector3(17, 0, 5), "dining": Vector3(0, 0, 5.6), "mirror": Vector3(0, 0, -2.4), "keypad": Vector3(2.4, 0, -2.6),
		"vestibule": Vector3(0, 0, -6.5), "lobby": Vector3(0, UNDER, -32.0), "platform": Vector3(0, UNDER, -45.0), "supply_station": Vector3(-14, UNDER, -38.0),
		"booth": Vector3(31.5, UNDER, -33.6), "radio": Vector3(21.0, UNDER, -37.0), "depot": Vector3(47.0, UNDER, -48.0), "ops_from": Vector3(43.5, UNDER, -48.0), "ops_stand": Vector3(30.0, UNDER, -44.0),
		"nadja_door": Vector3(-38.5, UNDER, -49.5), "nadja_inside": Vector3(-43.5, UNDER, -49.5), "nadja_far": Vector3(-52.0, UNDER, -49.5), "car_a": Vector3(0, UNDER, -57.0),
		"car_b": Vector3(0, UNDER, -317.0), "terminal": Vector3(0, UNDER, -330.0), "control": Vector3(31.0, DECK, -340.4), "gate_admin": Vector3(0, UNDER, -343.0),
		"checkpoint": Vector3(0, UNDER, -354.0), "supply_checkpoint": Vector3(12.0, UNDER, -355.0), "junction": Vector3(0, UNDER, -365.0), "office": Vector3(-31.2, UNDER, -382.6),
		"security": Vector3(21.0, UNDER, -383.3), "server": Vector3(37.0, UNDER, -381.0), "spine": Vector3(0, UNDER, -387.0), "cafeteria": Vector3(0, UNDER, -420.0),
		"atrium_south": Vector3(0, UNDER, -448.5), "atrium": Vector3(0, UNDER, -457.0), "supply_atrium": Vector3(-12.0, UNDER, -448.0), "maint": Vector3(30.0, UNDER, -469.0),
		"pump": Vector3(50.0, UNDER, -481.0), "generator": Vector3(50.0, UNDER, -446.7), "decon": Vector3(0, UNDER, -495.0), "labs_south": Vector3(0, UNDER, -505.0),
		"labs": Vector3(0, UNDER, -535.0), "cross": Vector3(0, UNDER, -573.0), "hall_end": Vector3(0, UNDER, -596.0), "lift": Vector3(0, UNDER, -615.0)
	}
	facings = {"landing": 0.0, "landing_out": 0.0}
	player_start = Vector3(0, 0.05, 61.5)
	if "--hive-alarm" in OS.get_cmdline_user_args():
		set_alarm(true)
		alarm_hold = true
	spawn_points = [
		Vector3(-66, 0, 0.5), Vector3(-66, 0, 40.5), Vector3(66, 0, 4.5), Vector3(66, 0, 52.5), Vector3(-35.5, 0, 91.5), Vector3(30.5, 0, 91.5)
	]
	shop_view = {"position": Vector3(-9.2, 1.55, 73.4), "target": Vector3(-13.5, 1.2, 73.4)}
