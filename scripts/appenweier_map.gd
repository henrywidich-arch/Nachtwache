extends HiveCore
## The third map: the edge of Appenweier (Baden) along the Sander Straße, from the house
## Sander Straße 13a and the gate works beside it, past the fire station, the market and
## the garden centre, to the roundabout on the B 3. Streets, buildings, fields, trees and
## lamps come from OpenStreetMap (data/appenweier.json, made by tools/make_appenweier.js;
## (c) OpenStreetMap contributors, ODbL); every business has a made-up name.
##
## The map is turned so that 13a stands square to the axes: x runs along the street
## (east), z away from it (the street lies at z = 43, the house at the origin). The house
## can be walked through on its ground floor - the rooms after the owner's video: the
## checkered hall with the spiral stair, the kitchen, the bath, the office, the study, the
## blue music room to the garden, the annex with its rooms, and through the painted door
## the rustic room and the hall of the gate works. Nothing else can be entered.
##
## The rounds are those of the farm (plain waves, no tasks): see game.gd, start_run.
## No class_name: the game reaches it by its path (see enter), so that it runs without an
## editor having scanned the project first.

const SELF_PATH := "res://scripts/appenweier_map.gd"
const DATA := "res://data/appenweier.json"
const OPENING := "Appenweier, Sander Straße. Haltet das Haus 13a und den Torbau – sie kommen über die Felder, die Straße und vom Kreisverkehr."
## Top of the house's walls, the walls of the works, where its flat roof lies.
const EAVES := 3.2
const WORKS_TOP := 6.8
const HOUSE := Rect2(-10, -10.5, 20, 21)
const WORKS := Rect2(-30, -12.6, 20, 23.2)
const ROOM_TALL := 2.6
const PITCH := 30.0
const WALL_COLORS := [Color(0.86, 0.83, 0.74), Color(0.9, 0.9, 0.88), Color(0.82, 0.76, 0.62), Color(0.74, 0.75, 0.74), Color(0.88, 0.8, 0.7)]
const ROOF_COLORS := [Color(0.42, 0.2, 0.15), Color(0.3, 0.17, 0.13), Color(0.2, 0.21, 0.23), Color(0.5, 0.26, 0.18)]

var town: Dictionary = {}
var ground := 0
## Footprints of the buildings nobody enters: closed on the ground's grid (see _close_pockets).
var footprints: Array[PackedVector2Array] = []
var map_bounds := Rect2()

## Whether the game holds the map already (built the first time it is played).
static func built(game: Node) -> bool:
	return game.has_meta("appenweier") and is_instance_valid(game.get_meta("appenweier"))

## Puts the map into the world in place of the one there (game.use_map takes the farm
## back when the menu is shown again).
static func enter(game: Node) -> void:
	var map: Node3D = game.get_meta("appenweier") if built(game) else null
	if map == null:
		map = (load(SELF_PATH) as GDScript).new()
		map.name = "Appenweier"
		game.set_meta("appenweier", map)
	var current: Node3D = game.cabin
	if current != map or not map.is_inside_tree():
		if current.is_inside_tree():
			game.remove_child(current)
		game.cabin = map
		game.add_child(map)
		game.move_child(map, 0)
	map.call("reset")
	game.shopkeeper.visible = false
	game.call("_aim_shop_camera", map.get("shop_view"))

func _ready() -> void:
	var began := Time.get_ticks_msec()
	var text := FileAccess.get_file_as_string(DATA)
	town = JSON.parse_string(text) if text != "" else {}
	if town == null or town.is_empty():
		push_error("AppenweierMap: no map data at " + DATA)
		town = {"bounds": [-95, -55, 395, 180]}
	var b: Array = town.bounds
	map_bounds = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
	_begin_build()
	_noise_material("asphalt", 5150, 0.8, Vector3.ONE * 0.3, 0.86, 0.7, 0.62)
	_build_environment()
	_build_styles()
	ground = _floor("ground", "APPENWEIER", 0.0, map_bounds)
	var shop_sign := Label3D.new()
	shop_sign.name = "WeaponShopLabel"
	add_child(shop_sign)
	_lay_town()
	_lay_house()
	_lay_works()
	# The doors of the house and the works stand open without wings folded against the wall.
	for door in doors:
		door["wings"] = false
	_compile()
	_commit()
	_after_build()
	build_times["all"] = Time.get_ticks_msec() - began

func _build_styles() -> void:
	var plaster := Color(0.9, 0.88, 0.84)
	var light := Color("ffd9a8")
	styles = {
		"none": {"family": "villa", "dress": "", "floor": ["plain", Color.WHITE], "ceiling": ["plain", Color.WHITE], "core": ["plain", Color.WHITE], "lamp": "none"},
		# The hall: black and white tiles, a painted sky above.
		"entry": {"family": "villa", "dress": "", "floor": ["checker", Color(0.95, 0.95, 0.95)], "ceiling": ["plaster", Color(0.42, 0.6, 0.86)], "core": ["plaster", Color(0.95, 0.94, 0.9)], "lamp": "cage", "light": light, "energy": 1.8, "reach": 9.0, "lamp_gap": 4.0},
		"parquet": {"family": "villa", "dress": "", "floor": ["parquet", Color(0.86, 0.74, 0.6)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.94, 0.93, 0.9)], "lamp": "cage", "light": light, "energy": 1.4, "reach": 7.0, "lamp_gap": 4.5},
		"study": {"family": "villa", "dress": "", "floor": ["parquet", Color(0.8, 0.68, 0.55)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.86, 0.8, 0.68)], "lamp": "cage", "light": light, "energy": 1.4, "reach": 7.0, "lamp_gap": 4.0},
		"kitchen": {"family": "villa", "dress": "tiles", "floor": ["tiles", Color(0.9, 0.9, 0.88)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.93, 0.89, 0.78)], "tile": Color(0.93, 0.92, 0.88), "trim": Color(0.7, 0.68, 0.62), "lamp": "cage", "light": Color("fff0d8"), "energy": 1.6, "reach": 8.0, "lamp_gap": 4.0},
		"bath": {"family": "villa", "dress": "tiles", "floor": ["tiles", Color(0.6, 0.58, 0.55)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.95, 0.95, 0.93)], "tile": Color(0.96, 0.96, 0.95), "trim": Color(0.8, 0.8, 0.78), "lamp": "cage", "light": Color("fff4e4"), "energy": 1.5, "reach": 7.0, "lamp_gap": 4.0},
		"office": {"family": "villa", "dress": "", "floor": ["parquet", Color(0.7, 0.55, 0.42)], "ceiling": ["plaster", plaster], "core": ["wallpaper", Color(0.78, 0.7, 0.58)], "lamp": "cage", "light": light, "energy": 1.4, "reach": 7.0, "lamp_gap": 4.0},
		"music": {"family": "villa", "dress": "", "floor": ["parquet", Color(0.82, 0.7, 0.56)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.28, 0.66, 0.68)], "lamp": "chandelier", "lamp_model": "Chandelier_01", "lamp_size": 0.9, "lamp_drop": 0.3, "light": light, "energy": 1.9, "reach": 10.0, "lamp_gap": 6.0},
		# The annex: speckled linoleum, plain white walls.
		"annex": {"family": "villa", "dress": "", "floor": ["granite", Color(0.86, 0.8, 0.68)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.92, 0.92, 0.9)], "lamp": "tube", "light": Color("eef2f4"), "energy": 1.3, "reach": 7.0, "lamp_gap": 4.5},
		"green": {"family": "villa", "dress": "", "floor": ["granite", Color(0.86, 0.8, 0.68)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.46, 0.68, 0.42)], "lamp": "tube", "light": Color("eef2f4"), "energy": 1.3, "reach": 7.0, "lamp_gap": 4.0},
		"yellow": {"family": "villa", "dress": "", "floor": ["parquet", Color(0.84, 0.72, 0.58)], "ceiling": ["plaster", plaster], "core": ["plaster", Color(0.95, 0.82, 0.48)], "lamp": "cage", "light": light, "energy": 1.4, "reach": 7.5, "lamp_gap": 4.5},
		"stube": {"family": "villa", "dress": "", "floor": ["tiles", Color(0.78, 0.42, 0.28)], "ceiling": ["panelwood", Color(0.38, 0.28, 0.2)], "core": ["plaster", Color(0.9, 0.85, 0.74)], "lamp": "cage", "light": Color("ffc88a"), "energy": 1.6, "reach": 8.0, "lamp_gap": 4.0, "flicker": 0.04},
		"works": {"family": "bunker", "dress": "concrete", "floor": ["betonfloor", Color(0.75, 0.75, 0.74)], "ceiling": ["beton", Color(0.66, 0.66, 0.66)], "core": ["plaster", Color(0.9, 0.9, 0.88)], "lamp": "hang", "lamp_height": 4.6, "light": Color("ffe7c0"), "energy": 1.6, "reach": 12.0, "lamp_gap": 7.0},
		"store": {"family": "bunker", "dress": "", "floor": ["betonfloor", Color(0.72, 0.72, 0.72)], "ceiling": ["beton", Color(0.62, 0.62, 0.62)], "core": ["plaster", Color(0.86, 0.86, 0.84)], "lamp": "cage", "light": Color("ffe7c0"), "energy": 1.3, "reach": 7.0, "lamp_gap": 4.0},
	}

## The village is not as dark as the farm in the wood: street lamps, windows, the glow
## of the town over the fields.
func _apply_mood() -> void:
	super._apply_mood()
	if Sandbox.holding_flat or environment == null:
		return
	environment.ambient_light_energy = float(mood_now.energy) * 1.45
	moon.light_energy = float(mood_now.moon) * 1.25

# ---------------------------------------------------------------- helpers

func _v2(point: Variant) -> Vector2:
	return Vector2(float(point[0]), float(point[1]))

func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(_v2(point))
	return out

func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in poly:
		sum += point
	return sum / maxf(1.0, poly.size())

## The 40 m tile of the town a spot belongs to (culling and shadows stay cheap).
func _town_chunk(at: Vector2, kind: String = "T") -> void:
	_chunk("%s_%d_%d" % [kind, floori(at.x / 40.0), floori(at.y / 40.0)])

## A flat polygon lying on the ground, its top at `top`.
func _flat(poly: PackedVector2Array, top: float, material: String, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(poly)
	for i in range(0, indices.size(), 3):
		var a := Vector3(poly[indices[i]].x, top, poly[indices[i]].y)
		var b := Vector3(poly[indices[i + 1]].x, top, poly[indices[i + 1]].y)
		var c := Vector3(poly[indices[i + 2]].x, top, poly[indices[i + 2]].y)
		if (b - a).cross(c - a).y < 0.0:
			batch.triangle(mats[material], a, c, b, color)
		else:
			batch.triangle(mats[material], a, b, c, color)

## A face of a wall from `p` to `q` (plan), between two heights, seen from the side `out`.
func _face(p: Vector2, q: Vector2, y0: float, y1: float, out: Vector2, material: String, color: Color) -> void:
	var a := Vector3(p.x, y0, p.y)
	var b := Vector3(q.x, y0, q.y)
	var c := Vector3(q.x, y1, q.y)
	var d := Vector3(p.x, y1, p.y)
	if (b - a).cross(d - a).dot(Vector3(out.x, 0, out.y)) < 0.0:
		batch.quad(mats[material], a, d, c, b, color)
	else:
		batch.quad(mats[material], a, b, c, d, color)

## Which way the side from poly[i] to poly[i + 1] looks out of the polygon.
func _outward(poly: PackedVector2Array, i: int) -> Vector2:
	var p := poly[i]
	var q := poly[(i + 1) % poly.size()]
	var normal := Vector2(q.y - p.y, p.x - q.x).normalized()
	if Geometry2D.is_point_in_polygon((p + q) * 0.5 + normal * 0.05, poly):
		normal = -normal
	return normal

## A box lying along a line in the plan (a stretch of road, a wall, a hedge).
func _along(material: String, p: Vector2, q: Vector2, wide: float, y0: float, y1: float, color: Color, solid: bool = false) -> void:
	var span := q - p
	var long := span.length()
	if long < 0.01:
		return
	var yaw := atan2(-span.y, span.x)
	var mid := (p + q) * 0.5
	var centre := Vector3(mid.x, (y0 + y1) * 0.5, mid.y)
	var size := Vector3(long, y1 - y0, wide)
	batch.box(mats[material], centre, size, color, Basis(Vector3.UP, yaw))
	if solid:
		_solid(centre, size, true, yaw)

## Collision for a building that nobody enters: its footprint cut into convex pieces.
func _solid_footprint(poly: PackedVector2Array, tall: float) -> void:
	for piece in Geometry2D.decompose_polygon_in_convex(poly):
		var points := PackedVector3Array()
		for point in piece:
			points.append(Vector3(point.x, 0.0, point.y))
			points.append(Vector3(point.x, tall, point.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	footprints.append(poly)

## Before the open ground is searched for pockets nobody reaches, the footprints of the
## buildings are closed on it (they are no rectangles, so _register cannot do it).
func _close_pockets(room: Dictionary) -> void:
	if str(room.id) == "town":
		_paint_footprints()
	super._close_pockets(room)

func _paint_footprints() -> void:
	var grid := navigation[ground]
	var region: Rect2i = grid.region
	for poly in footprints:
		var grown: Array = Geometry2D.offset_polygon(poly, NAV_MARGIN)
		for shape: PackedVector2Array in grown:
			var box := Rect2(shape[0], Vector2.ZERO)
			for point in shape:
				box = box.expand(point)
			var cells := _cells(ground, box)
			for x in range(cells.position.x, cells.end.x):
				for z in range(cells.position.y, cells.end.y):
					if Geometry2D.is_point_in_polygon(Vector2(x * CELL, z * CELL), shape):
						grid.set_point_solid(Vector2i(x, z), true)
						plan_pictures[ground].set_pixelv(Vector2i(x, z) - region.position, Color(1, 0, 0))

# ---------------------------------------------------------------- the town

func _lay_town() -> void:
	_begin_zone("town", "out")
	area = ""
	_own_dice(30813)
	_room("town", ground, map_bounds, 0.0, "none", {"outdoor": true, "seed": Vector2(0, 30)})
	_lay_ground()
	_lay_areas()
	_lay_roads()
	_lay_buildings()
	_lay_walls()
	_lay_trees()
	_lay_lamps()
	_lay_rails()
	_lay_yard()
	_lay_fire_station()
	_lay_cars()
	_shared_dice()
	_end_zone()

func _lay_ground() -> void:
	_chunk("Ground", false)
	var holes := [HOUSE, WORKS]
	for tile in _tiles(map_bounds, holes):
		for piece in _split(tile, 20.0):
			_part("lawn", Vector3(piece.get_center().x, -0.25, piece.get_center().y), Vector3(piece.size.x, 0.5, piece.size.y), Color(0.36, 0.42, 0.3))
			_solid(Vector3(piece.get_center().x, -0.25, piece.get_center().y), Vector3(piece.size.x, 0.5, piece.size.y), false)
	# The land beyond, dark, and the limits nobody sees.
	for tile in _tiles(map_bounds.grow(260.0), [map_bounds]):
		_part("ground", Vector3(tile.get_center().x, -0.3, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), Color("1a1f15"))
	var r := map_bounds
	for edge in [
		[Vector3(r.position.x - 0.3, 4, r.get_center().y), Vector3(0.6, 8, r.size.y + 1)], [Vector3(r.end.x + 0.3, 4, r.get_center().y), Vector3(0.6, 8, r.size.y + 1)],
		[Vector3(r.get_center().x, 4, r.position.y - 0.3), Vector3(r.size.x + 1, 8, 0.6)], [Vector3(r.get_center().x, 4, r.end.y + 0.3), Vector3(r.size.x + 1, 8, 0.6)]
	]:
		_add_shape(body, edge[0], edge[1])
	# A wood around it all, out of reach.
	for i in range(80):
		var side := i % 4
		var along := random.randf()
		var off := random.randf_range(6.0, 34.0)
		var spot: Vector2
		match side:
			0:
				spot = Vector2(lerpf(r.position.x, r.end.x, along), r.position.y - off)
			1:
				spot = Vector2(r.end.x + off, lerpf(r.position.y, r.end.y, along))
			2:
				spot = Vector2(lerpf(r.position.x, r.end.x, along), r.end.y + off)
			_:
				spot = Vector2(r.position.x - off, lerpf(r.position.y, r.end.y, along))
		_tree(Vector3(spot.x, 0, spot.y), random.randf_range(10.0, 17.0), false)

func _lay_areas() -> void:
	for entry in town.get("areas", []):
		var poly := _poly(entry.points)
		if poly.size() < 3:
			continue
		_town_chunk(_centroid(poly), "A")
		match str(entry.kind):
			"grass", "garden", "meadow", "orchard":
				_flat(poly, 0.012, "lawn", Color(0.33, 0.44, 0.27) if str(entry.kind) != "meadow" else Color(0.42, 0.44, 0.28))
			"scrub", "wood":
				_flat(poly, 0.012, "lawn", Color(0.26, 0.33, 0.21))
				_scrub(poly)
			"farmland":
				_flat(poly, 0.016, "ground", Color(0.46, 0.38, 0.27))
				_maize(poly)
			"flowerbed":
				_flat(poly, 0.02, "ground", Color(0.3, 0.23, 0.17))
			"parking":
				_flat(poly, 0.03, "asphalt", Color(0.34, 0.34, 0.35))
			"area_highway_footway", "area_highway_path":
				_flat(poly, 0.034, "cobble", Color(0.62, 0.6, 0.57))

## Maize, as the fields stood in late September: rows of dry stalks one walks through.
func _maize(poly: PackedVector2Array) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		box = box.expand(point)
	var row := box.position.y + 0.6
	while row < box.end.y:
		var crossings: Array[float] = []
		for i in range(poly.size()):
			var p := poly[i]
			var q := poly[(i + 1) % poly.size()]
			if (p.y <= row and q.y > row) or (q.y <= row and p.y > row):
				crossings.append(p.x + (row - p.y) / (q.y - p.y) * (q.x - p.x))
		crossings.sort()
		for k in range(0, crossings.size() - 1, 2):
			# The leaves of a row stand close: a dense band, broken every few metres, with
			# the tassels of single stalks over it.
			var x := crossings[k] + 0.4
			while x < crossings[k + 1] - 0.6:
				var long := minf(random.randf_range(2.5, 5.0), crossings[k + 1] - 0.4 - x)
				if long < 0.6:
					break
				_town_chunk(Vector2(x, row), "M")
				var tall := random.randf_range(1.5, 1.9)
				var tint := _vary(Color(0.6, 0.5, 0.28), 0.05)
				_part("lawn", Vector3(x + long * 0.5, tall * 0.5, row), Vector3(long, tall, 0.42), tint)
				_part("lawn", Vector3(x + long * 0.5, tall * 0.85, row), Vector3(long * 0.96, tall * 0.3, 0.62), tint.darkened(0.12))
				var stalk := x + 0.2
				while stalk < x + long - 0.1:
					var high := tall + random.randf_range(0.25, 0.7)
					_part("lawn", Vector3(stalk, high * 0.5, row + random.randf_range(-0.12, 0.12)), Vector3(0.05, high, 0.05), tint.lightened(0.1))
					_part("lawn", Vector3(stalk, high - 0.1, row), Vector3(0.04, 0.3, 0.16), Color(0.74, 0.64, 0.38), Vector3(random.randf_range(-20, 20), random.randf_range(0, 180), 0))
					stalk += random.randf_range(0.5, 0.9)
				x += long + random.randf_range(0.5, 0.9)
		row += 1.05

func _scrub(poly: PackedVector2Array) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		box = box.expand(point)
	var count := mini(60, int(box.get_area() / 30.0))
	for i in range(count):
		var spot := Vector2(random.randf_range(box.position.x, box.end.x), random.randf_range(box.position.y, box.end.y))
		if not Geometry2D.is_point_in_polygon(spot, poly):
			continue
		var wide := random.randf_range(0.8, 1.8)
		batch.ellipsoid(mats["lawn"], Vector3(spot.x, wide * 0.4, spot.y), Vector3(wide, wide * 0.7, wide), _vary(Color(0.24, 0.32, 0.19), 0.04), Basis.IDENTITY, 7, 4)

const ROAD_TOP := {"primary": 0.05, "unclassified": 0.046, "residential": 0.044, "service": 0.04, "track": 0.038, "footway": 0.036, "path": 0.036}

func _lay_roads() -> void:
	for road in town.get("roads", []):
		var kind := str(road.type)
		var top := float(ROAD_TOP.get(kind, 0.04))
		var wide := float(road.width)
		var material := "asphalt"
		var color := Color(0.3, 0.3, 0.31)
		if kind == "track":
			material = "gravel"
			color = Color(0.6, 0.57, 0.52)
		elif kind in ["footway", "path"]:
			material = "cobble"
			color = Color(0.58, 0.56, 0.53)
			wide = minf(wide, 2.2)
		var points: Array = road.points
		for i in range(points.size() - 1):
			var p := _v2(points[i])
			var q := _v2(points[i + 1])
			_town_chunk((p + q) * 0.5, "R")
			_along(material, p, q, wide, top - 0.08, top, color)
			batch.cylinder(mats[material], Vector3(q.x, top - 0.08, q.y), wide * 0.5, wide * 0.5, 0.08, color, 14)
			if i == 0:
				batch.cylinder(mats[material], Vector3(p.x, top - 0.08, p.y), wide * 0.5, wide * 0.5, 0.08, color, 14)
			# The street's markings: a dashed middle line, and the red cycle lanes of the
			# Sander Straße.
			if kind in ["primary", "unclassified"] and not bool(road.ring) and wide >= 5.5:
				_dashes(p, q, top)
				if str(road.name) == "Sander Straße":
					var side := Vector2(-(q - p).y, (q - p).x).normalized() * (wide * 0.5 - 0.9)
					for s in [-1.0, 1.0]:
						_along("asphalt", p + side * s, q + side * s, 1.2, top - 0.02, top + 0.004, Color(0.55, 0.16, 0.13))
	var ring: Dictionary = town.get("roundabout", {})
	if not ring.is_empty():
		var centre := _v2(ring.centre)
		var radius := float(ring.radius)
		_town_chunk(centre, "R")
		batch.cylinder(mats["asphalt"], Vector3(centre.x, -0.02, centre.y), radius + 4.2, radius + 4.2, 0.072, Color(0.3, 0.3, 0.31), 40)
		batch.cylinder(mats["granite"], Vector3(centre.x, 0, centre.y), radius - 3.4, radius - 3.4, 0.22, Color(0.7, 0.7, 0.68), 36)
		batch.cylinder(mats["lawn"], Vector3(centre.x, 0, centre.y), radius - 3.8, radius - 3.8, 0.26, Color(0.32, 0.42, 0.26), 36)
		# What stands in the middle: a big stone and three young trees.
		_part("stonewall", Vector3(centre.x, 1.0, centre.y), Vector3(2.4, 2.0, 1.6), Color(0.6, 0.58, 0.54), Vector3(0, 30, 6))
		for k in range(3):
			var turn := TAU * k / 3.0 + 0.4
			_tree(Vector3(centre.x + cos(turn) * 7.0, 0.26, centre.y + sin(turn) * 7.0), random.randf_range(7.0, 9.0))
		_round_solid(Vector3(centre.x, 0, centre.y), radius - 3.4, 0.6)

func _dashes(p: Vector2, q: Vector2, top: float) -> void:
	var span := q - p
	var long := span.length()
	if long < 4.0:
		return
	var step := span / long
	var at := 1.0
	while at + 3.0 < long:
		_along("plain", p + step * at, p + step * (at + 3.0), 0.12, top - 0.01, top + 0.006, Color(0.85, 0.85, 0.8))
		at += 9.0

# ---------------------------------------------------------------- buildings

func _lay_buildings() -> void:
	var index := 0
	for entry in town.get("buildings", []):
		index += 1
		var role := str(entry.role)
		if role in ["house", "works"]:
			continue
		var poly := _poly(entry.points)
		if poly.size() < 3:
			continue
		var kind := str(entry.kind)
		var levels := int(entry.levels)
		var number := str(entry.number)
		var wall_color: Color = WALL_COLORS[index % WALL_COLORS.size()]
		var roof_color: Color = ROOF_COLORS[index % ROOF_COLORS.size()]
		var tall := 6.0
		var roof := "gable"
		match kind:
			"retail":
				tall = 5.2
				roof = "flat"
				wall_color = Color(0.78, 0.78, 0.76)
			"fire_station":
				tall = 7.0
				roof = "flat"
				wall_color = Color(0.93, 0.93, 0.91)
			"apartments":
				tall = 3.0 * maxi(levels, 3) + 0.6
				roof = "flat"
			"garage":
				tall = 2.8
				roof = "flat"
			"roof":
				roof = "canopy"
			_:
				if levels > 0:
					tall = 2.9 * levels + 0.4
		if number == "13d":
			# The double garage before 13a, flat-roofed and white.
			tall = 2.9
			roof = "flat"
			wall_color = Color(0.92, 0.92, 0.9)
		if poly.size() != 4 and roof == "gable":
			roof = "flat"
		_town_chunk(_centroid(poly), "B")
		if roof == "canopy":
			_canopy(poly)
			continue
		_house_shell(poly, tall, roof, wall_color, roof_color, kind in ["retail", "fire_station"] or str(entry.name) != "")
		if number == "13d":
			_garage_doors(poly)
		if str(entry.name) != "" and kind != "fire_station":
			_sign(poly, str(entry.name).to_upper(), tall)
		elif number != "" and str(entry.street) != "":
			_house_number(poly, number)

## Walls, windows, a roof and a body for a building nobody enters.
func _house_shell(poly: PackedVector2Array, tall: float, roof: String, wall_color: Color, roof_color: Color, shop: bool) -> void:
	var n := poly.size()
	for i in range(n):
		var p := poly[i]
		var q := poly[(i + 1) % n]
		var out := _outward(poly, i)
		_face(p, q, 0.0, tall, out, "plaster", _vary(wall_color, 0.015))
		# A plinth, and the windows of every storey.
		_face(p + out * 0.03, q + out * 0.03, 0.0, 0.45, out, "beton", wall_color.darkened(0.35))
		var long := p.distance_to(q)
		# (A garage has no windows.)
		if long < 2.5 or tall < 3.2:
			continue
		var step := (q - p) / long
		var storeys := maxi(1, floori((tall - 0.6) / 2.9))
		var count := floori(long / (5.0 if shop else 3.2))
		for k in range(count):
			var at := (k + 0.5) * long / count
			for s in range(storeys):
				var base := 0.9 + s * 2.9
				var mid := p + step * at + out * 0.04
				var yaw := atan2(-step.y, step.x)
				var wide := 2.8 if shop and s == 0 else 1.15
				var high := 2.2 if shop and s == 0 else 1.3
				if shop and s == 0:
					base = 0.5
				var centre := Vector3(mid.x, base + high * 0.5, mid.y)
				if random.randf() < (0.22 if shop else 0.12):
					_glow_box(centre, Vector3(wide, high, 0.05), Color("ffcf8f") if not shop else Color("dff0ff"), 2.2 if not shop else 3.0, Basis(Vector3.UP, yaw))
				else:
					batch.box(mats["plain"], centre, Vector3(wide, high, 0.05), Color(0.06, 0.07, 0.09), Basis(Vector3.UP, yaw))
				# Shutters half down on the houses.
				if not shop and random.randf() < 0.5:
					batch.box(mats["plain"], centre + Vector3(0, high * 0.3, 0) + Vector3(out.x, 0, out.y) * 0.02, Vector3(wide, high * 0.4, 0.05), Color(0.55, 0.55, 0.53), Basis(Vector3.UP, yaw))
	match roof:
		"gable":
			_gable_roof(poly, tall, wall_color, roof_color)
		_:
			_flat(poly, tall + 0.02, "beton", Color(0.36, 0.36, 0.37))
			for i in range(n):
				var out := _outward(poly, i)
				_face(poly[i], poly[(i + 1) % n], tall, tall + 0.5, out, "plaster", wall_color.darkened(0.08))
				_face(poly[i] - out * 0.25, poly[(i + 1) % n] - out * 0.25, tall, tall + 0.5, -out, "plaster", wall_color.darkened(0.2))
	_solid_footprint(poly, tall + 0.5)

## A saddle roof over four corners: the ridge along the longer sides.
func _gable_roof(poly: PackedVector2Array, tall: float, wall_color: Color, roof_color: Color) -> void:
	var start := 0 if poly[0].distance_to(poly[1]) >= poly[1].distance_to(poly[2]) else 1
	var a := poly[start]
	var b := poly[(start + 1) % 4]
	var c := poly[(start + 2) % 4]
	var d := poly[(start + 3) % 4]
	var m1 := (a + d) * 0.5
	var m2 := (b + c) * 0.5
	var rise := a.distance_to(d) * 0.5 * tan(deg_to_rad(PITCH))
	_roof(a, b, m2, m1, tall, rise, roof_color)
	_roof(c, d, m1, m2, tall, rise, roof_color)
	for gable in [[a, d, m1], [b, c, m2]]:
		var p: Vector2 = gable[0]
		var q: Vector2 = gable[1]
		var top: Vector2 = gable[2]
		var out := (top - ((m1 if top == m2 else m2))).normalized()
		var pa := Vector3(p.x, tall, p.y)
		var pb := Vector3(q.x, tall, q.y)
		var pt := Vector3(top.x, tall + rise, top.y)
		if (pb - pa).cross(pt - pa).dot(Vector3(out.x, 0, out.y)) < 0.0:
			batch.triangle(mats["plaster"], pa, pt, pb, wall_color)
		else:
			batch.triangle(mats["plaster"], pa, pb, pt, wall_color)

## One plane of a saddle roof from its eave (p, q) up to the ridge (r_q, r_p), a little
## beyond the walls all round, as a slab with an underside.
func _roof(p: Vector2, q: Vector2, r_q: Vector2, r_p: Vector2, tall: float, rise: float, color: Color) -> void:
	var down := (p - r_p).normalized()
	var along := (q - p).normalized()
	var over := 0.45
	var e0 := Vector3(p.x, tall, p.y) + Vector3(down.x, 0, down.y) * over - Vector3(along.x, 0, along.y) * 0.3 - Vector3(0, over * tan(deg_to_rad(PITCH)), 0)
	var e1 := Vector3(q.x, tall, q.y) + Vector3(down.x, 0, down.y) * over + Vector3(along.x, 0, along.y) * 0.3 - Vector3(0, over * tan(deg_to_rad(PITCH)), 0)
	var t1 := Vector3(r_q.x, tall + rise, r_q.y) + Vector3(along.x, 0, along.y) * 0.3
	var t0 := Vector3(r_p.x, tall + rise, r_p.y) - Vector3(along.x, 0, along.y) * 0.3
	var up := (e1 - e0).cross(t0 - e0)
	if up.y < 0.0:
		batch.quad(mats["slate"], e0, t0, t1, e1, color)
		batch.quad(mats["slate"], e0 - Vector3(0, 0.12, 0), e1 - Vector3(0, 0.12, 0), t1 - Vector3(0, 0.12, 0), t0 - Vector3(0, 0.12, 0), color.darkened(0.4))
	else:
		batch.quad(mats["slate"], e0, e1, t1, t0, color)
		batch.quad(mats["slate"], e0 - Vector3(0, 0.12, 0), t0 - Vector3(0, 0.12, 0), t1 - Vector3(0, 0.12, 0), e1 - Vector3(0, 0.12, 0), color.darkened(0.4))
	# The red-brown board along the eave.
	_along("panelwood", Vector2(e0.x, e0.z), Vector2(e1.x, e1.z), 0.06, e0.y - 0.22, e0.y + 0.02, Color(0.45, 0.16, 0.12))

## A roof on posts (over the trolleys of the market).
func _canopy(poly: PackedVector2Array) -> void:
	_flat(poly, 3.6, "plate", Color(0.5, 0.52, 0.54))
	var under := poly.duplicate()
	under.reverse()
	_flat(under, 3.5, "plate", Color(0.3, 0.32, 0.33))
	for point in poly:
		var inward := (_centroid(poly) - point).normalized() * 0.3
		batch.cylinder(mats["metal"], Vector3(point.x + inward.x, 0, point.y + inward.y), 0.08, 0.08, 3.5, Color(0.25, 0.27, 0.28), 8)
		_round_solid(Vector3(point.x + inward.x, 0, point.y + inward.y), 0.1, 3.5)

func _street_side(poly: PackedVector2Array) -> int:
	# The side that looks most towards the Sander Straße.
	var middle := _centroid(poly)
	var want := Vector2(0, 1) if middle.y < 43.0 else Vector2(0, -1)
	var best := 0
	var score := -INF
	for i in range(poly.size()):
		var long := poly[i].distance_to(poly[(i + 1) % poly.size()])
		var value := _outward(poly, i).dot(want) * 2.0 + minf(long, 20.0) * 0.05
		if value > score:
			score = value
			best = i
	return best

func _sign(poly: PackedVector2Array, title: String, tall: float) -> void:
	var i := _street_side(poly)
	var out := _outward(poly, i)
	var mid := (poly[i] + poly[(i + 1) % poly.size()]) * 0.5 + out * 0.12
	var plate_yaw := atan2(-(poly[(i + 1) % poly.size()] - poly[i]).y, (poly[(i + 1) % poly.size()] - poly[i]).x)
	var high := minf(tall - 0.7, 4.2)
	batch.box(mats["plain"], Vector3(mid.x, high, mid.y), Vector3(minf(title.length() * 0.42 + 0.8, 14.0), 0.9, 0.06), Color(0.12, 0.14, 0.16), Basis(Vector3.UP, plate_yaw))
	var label := lettering(title, Vector3(mid.x + out.x * 0.05, high, mid.y + out.y * 0.05), 96, Color("f2e6c4"))
	label.rotation.y = atan2(out.x, out.y)
	_light(Vector3(mid.x + out.x * 1.2, high + 0.6, mid.y + out.y * 1.2), Color("ffe2b0"), 0.9, 6.0, false, 0.0, 0.4, 80.0)

func _house_number(poly: PackedVector2Array, number: String) -> void:
	var i := _street_side(poly)
	var out := _outward(poly, i)
	var mid := (poly[i] + poly[(i + 1) % poly.size()]) * 0.5 + out * 0.08
	var label := lettering(number, Vector3(mid.x, 2.4, mid.y), 60, Color("e8e2d0"))
	label.rotation.y = atan2(out.x, out.y)

func _garage_doors(poly: PackedVector2Array) -> void:
	# Two up-and-over doors on the side towards the house.
	var best := 0
	var score := -INF
	for i in range(4):
		var value := _outward(poly, i).dot(Vector2(0, -1))
		if value > score:
			score = value
			best = i
	var p := poly[best]
	var q := poly[(best + 1) % 4]
	var out := _outward(poly, best)
	for k in range(2):
		var a := p.lerp(q, 0.08 + k * 0.47)
		var b := p.lerp(q, 0.47 + k * 0.47)
		_face(a + out * 0.03, b + out * 0.03, 0.0, 2.2, out, "shutter", Color(0.86, 0.86, 0.84))

func _lay_walls() -> void:
	for entry in town.get("walls", []):
		var points: Array = entry.points
		for i in range(points.size() - 1):
			var p := _v2(points[i])
			var q := _v2(points[i + 1])
			_town_chunk((p + q) * 0.5, "W")
			match str(entry.kind):
				"hedge":
					_along("lawn", p, q, 0.9, 0.0, 1.7, Color(0.2, 0.3, 0.18), true)
				"tree_row":
					var long := p.distance_to(q)
					for k in range(maxi(1, floori(long / 8.0))):
						var spot := p.lerp(q, (k + 0.5) / maxf(1.0, floorf(long / 8.0)))
						_tree(Vector3(spot.x, 0, spot.y), random.randf_range(9.0, 13.0))
				_:
					_along("stonewall", p, q, 0.35, 0.0, 1.3, Color(0.66, 0.64, 0.6), true)

func _tree(pos: Vector3, tall: float, trunk: bool = true) -> void:
	# (Not the dead ones: these are the trees of a village street.)
	var id: String = TREE_MODELS[random.randi() % 7]
	_model(id, pos, random.randf() * TAU, {"height": tall, "solid": false, "tint": TREE_TINT, "far": 170.0, "shadows": trunk})
	if trunk:
		_round_solid(pos, 0.3, 3.0)

func _lay_trees() -> void:
	for point in town.get("trees", []):
		var spot := _v2(point)
		if HOUSE.grow(1.0).has_point(spot) or WORKS.grow(1.0).has_point(spot):
			continue
		_tree(Vector3(spot.x, 0, spot.y), random.randf_range(9.0, 14.0))

## The street lamps of the map, and more of them along the Sander Straße.
func _lay_lamps() -> void:
	var spots: Array[Vector2] = []
	for point in town.get("lamps", []):
		spots.append(_v2(point))
	var x := map_bounds.position.x + 12.0
	while x < 225.0:
		spots.append(Vector2(x, 38.6))
		x += 34.0
	for spot in spots:
		_town_chunk(spot, "L")
		_street_lamp(Vector3(spot.x, 0, spot.y))

func _street_lamp(pos: Vector3) -> void:
	batch.cylinder(mats["metal"], pos, 0.1, 0.07, 6.2, Color("4a4f52"), 8)
	_part("metal", pos + Vector3(0.6, 6.15, 0), Vector3(1.3, 0.1, 0.18), Color("4a4f52"))
	_part("metal", pos + Vector3(1.2, 6.05, 0), Vector3(0.55, 0.12, 0.26), Color("2c3033"))
	_glow_box(pos + Vector3(1.2, 5.98, 0), Vector3(0.45, 0.03, 0.2), Color("ffc27a"), 5.0)
	var lamp := _spot(pos + Vector3(1.2, 5.9, 0), Vector3.DOWN, Color("ffb866"), 9.0, 15.0, 70.0, 0.02, 1.4, 110.0)
	lamp.spot_attenuation = 0.8
	_round_solid(pos, 0.14, 6.2)

func _lay_rails() -> void:
	for entry in town.get("rails", []):
		var points: Array = entry.points
		for i in range(points.size() - 1):
			var p := _v2(points[i])
			var q := _v2(points[i + 1])
			_town_chunk((p + q) * 0.5, "R")
			_along("gravel", p, q, 3.2, -0.05, 0.25, Color(0.45, 0.42, 0.4))
			var side := Vector2(-(q - p).y, (q - p).x).normalized() * 0.72
			for s in [-1.0, 1.0]:
				_along("metal", p + side * s, q + side * s, 0.08, 0.25, 0.4, Color(0.45, 0.43, 0.42))

## Cars: before the house as in the owner's photos, in the car parks, one left in the street.
func _lay_cars() -> void:
	_car(Vector3(-7.0, 0, 15.5), PI / 2 + 0.1, Color(0.38, 0.4, 0.44))
	_car(Vector3(-16.0, 0, 17.5), PI / 2, Color(0.1, 0.11, 0.13), 4.8)
	_car(Vector3(-23.5, 0, 18.5), PI / 2 - 0.08, Color(0.62, 0.1, 0.08), 5.2, 2.2)
	_car(Vector3(38.0, 0, 44.5), 0.35, Color(0.18, 0.28, 0.6))
	_car(Vector3(118.0, 0, 41.0), PI + 0.2, Color(0.7, 0.7, 0.68))
	var placed := 0
	for entry in town.get("areas", []):
		if str(entry.kind) != "parking" or placed >= 10:
			continue
		var poly := _poly(entry.points)
		var middle := _centroid(poly)
		for k in range(2):
			var spot := middle + Vector2(k * 3.0 - 1.5, 0)
			if Geometry2D.is_point_in_polygon(spot, poly):
				_car(Vector3(spot.x, 0, spot.y), PI / 2 if k == 0 else PI / 2 + 0.05, [Color(0.5, 0.5, 0.5), Color(0.15, 0.2, 0.3), Color(0.75, 0.74, 0.7), Color(0.3, 0.06, 0.06)][placed % 4])
				placed += 1

func _car(pos: Vector3, yaw: float, paint: Color, long: float = 4.3, high: float = 1.45) -> void:
	_town_chunk(Vector2(pos.x, pos.z), "C")
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_placed(frame, "metal", Vector3(0, 0.6, 0), Vector3(long, 0.62, 1.8), paint)
	_placed(frame, "metal", Vector3(-0.15 if high < 2.0 else 0.2, 0.9 + high * 0.28, 0), Vector3(long * (0.55 if high < 2.0 else 0.8), high * 0.5, 1.62), paint.darkened(0.05))
	_placed(frame, "plain", Vector3(-0.15 if high < 2.0 else 0.2, 0.9 + high * 0.3, 0), Vector3(long * (0.55 if high < 2.0 else 0.8) + 0.02, high * 0.34, 1.64), Color(0.05, 0.07, 0.09))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			batch.cylinder(mats["metal"], frame * Vector3(x * long * 0.32, 0.33, z * 0.92 - z * 0.1), 0.33, 0.33, 0.22, Color(0.06, 0.06, 0.06), 12, frame.basis * Basis(Vector3.RIGHT, PI / 2))
	_glow_box(frame * Vector3(-long * 0.5, 0.72, 0.6), Vector3(0.04, 0.1, 0.25), Color("ff3020"), 1.0, frame.basis)
	_glow_box(frame * Vector3(-long * 0.5, 0.72, -0.6), Vector3(0.04, 0.1, 0.25), Color("ff3020"), 1.0, frame.basis)
	_solid(pos + Vector3(0, 0.8, 0), Vector3(long, 1.6, 1.8), true, yaw)

# ---------------------------------------------------------------- the yard of 13a

## The gravel before the house, the garden behind it: terrace, pergola, fountain, shed.
func _lay_yard() -> void:
	_chunk("Yard")
	_part("gravel", Vector3(-6, 0.01, 21.15), Vector3(42, 0.04, 20.7), Color(0.62, 0.6, 0.55))
	# The garden (north of the music room) with its picket fence.
	_part("lawn", Vector3(3.0, 0.014, -19.0), Vector3(24, 0.03, 17), Color(0.34, 0.46, 0.28))
	_part("cobble", Vector3(5.0, 0.03, -13.4), Vector3(10, 0.05, 5.2), Color(0.56, 0.56, 0.54))
	for x in [0.4, 9.6]:
		for z in [-11.4, -15.4]:
			_part("panelwood", Vector3(x, 1.25, z), Vector3(0.14, 2.5, 0.14), Color(0.45, 0.33, 0.22))
			_solid(Vector3(x, 1.25, z), Vector3(0.14, 2.5, 0.14))
	for z in [-11.4, -13.4, -15.4]:
		_part("panelwood", Vector3(5.0, 2.55, z), Vector3(9.8, 0.14, 0.12), Color(0.45, 0.33, 0.22))
	for x in range(6):
		_part("panelwood", Vector3(0.5 + x * 1.8, 2.66, -13.4), Vector3(0.1, 0.1, 4.6), Color(0.42, 0.31, 0.2))
	# The grill and the table under the pergola.
	_part("metal", Vector3(1.6, 0.5, -14.2), Vector3(1.4, 1.0, 0.7), Color(0.12, 0.12, 0.13))
	_part("metal", Vector3(1.6, 1.15, -14.2), Vector3(1.4, 0.3, 0.7), Color(0.16, 0.16, 0.17))
	_solid(Vector3(1.6, 0.6, -14.2), Vector3(1.4, 1.2, 0.7))
	_table(Vector3(6.0, 0, -13.2), Vector3(2.0, 0.76, 1.0), Color(0.45, 0.33, 0.22))
	for x in [5.3, 6.7]:
		_chair(Vector3(x, 0, -12.4), PI, Color(0.3, 0.3, 0.3))
		_chair(Vector3(x, 0, -14.0), 0.0, Color(0.3, 0.3, 0.3))
	# The stone basin on its gravel ring, the bench, the shed at the back.
	batch.cylinder(mats["gravel"], Vector3(4.0, 0.0, -21.0), 2.6, 2.6, 0.05, Color(0.66, 0.64, 0.6), 20)
	batch.cylinder(mats["stonewall"], Vector3(4.0, 0.0, -21.0), 1.2, 1.1, 0.6, Color(0.62, 0.6, 0.56), 16)
	batch.cylinder(mats["water"], Vector3(4.0, 0.52, -21.0), 1.0, 1.0, 0.02, Color.WHITE, 16)
	batch.cylinder(mats["stonewall"], Vector3(4.0, 0.0, -21.0), 0.25, 0.2, 1.2, Color(0.62, 0.6, 0.56), 10)
	_round_solid(Vector3(4.0, 0, -21.0), 1.2, 0.7)
	_part("panelwood", Vector3(8.5, 0.45, -24.0), Vector3(2.2, 0.08, 0.5), Color(0.45, 0.33, 0.22))
	_part("stonewall", Vector3(8.5, 0.2, -24.0), Vector3(1.8, 0.4, 0.35), Color(0.6, 0.58, 0.55))
	_prop("plaster", Vector3(12.5, 1.2, -24.5), Vector3(3.0, 2.4, 2.6), Color(0.92, 0.92, 0.9))
	_part("slate", Vector3(12.5, 2.5, -24.5), Vector3(3.4, 0.2, 3.0), Color(0.3, 0.17, 0.13))
	_part("panelwood", Vector3(12.5, 1.0, -23.18), Vector3(0.9, 2.0, 0.04), Color(0.4, 0.42, 0.45))
	for x in range(-9, 16):
		_part("panelwood", Vector3(x + 0.5, 0.5, -27.5), Vector3(0.09, 1.0, 0.04), Color(0.86, 0.84, 0.78))
	_part("panelwood", Vector3(3.5, 0.75, -27.52), Vector3(25.0, 0.08, 0.03), Color(0.86, 0.84, 0.78))
	_solid(Vector3(3.5, 0.5, -27.5), Vector3(25.0, 1.0, 0.1))
	# Garden lanterns along the house.
	for x in [-6.0, 1.0, 11.5]:
		_part("metal", Vector3(x, 0.45, -11.2), Vector3(0.12, 0.9, 0.12), Color(0.1, 0.1, 0.1))
		_glow_box(Vector3(x, 0.95, -11.2), Vector3(0.16, 0.2, 0.16), Color("ffd08a"), 4.0)
	_light(Vector3(5.0, 2.3, -13.0), Color("ffcf90"), 1.2, 9.0, false, 0.05, 0.6, 80.0)
	# The lamp over the front door and its canopy with the sun.
	_part("plate", Vector3(7.5, 2.75, 11.1), Vector3(2.4, 0.08, 1.2), Color(0.25, 0.3, 0.4), Vector3(-12, 0, 0))
	_glow_box(Vector3(7.5, 2.86, 10.75), Vector3(0.7, 0.3, 0.02), Color("ffcf5a"), 3.0)
	_light(Vector3(7.5, 2.4, 11.6), Color("ffd29a"), 1.6, 9.0, false, 0.03, 0.8, 90.0)
	# Lamps on the walls over the gravel: the yard is where the night is fought.
	for spot in [Vector3(-5.0, 2.9, 10.9), Vector3(1.5, 2.9, 10.9), Vector3(-25.0, 3.4, 10.95)]:
		_wall_lamp(spot, Vector3(0, 0, 1), Color("ffd29a"), 1.4, 10.0, 0.02)

## The fire station: red gates on the side of the street, the tower for the hoses, and the
## supply of the map on the forecourt.
func _lay_fire_station() -> void:
	_chunk("Fire")
	_flat(PackedVector2Array([Vector2(-45.0, 79.0), Vector2(-46.0, 47.5), Vector2(-2.0, 47.5), Vector2(-3.6, 66.6), Vector2(-12.6, 67.6), Vector2(-21.4, 67.0), Vector2(-20.6, 76.8)]), 0.04, "betonfloor", Color(0.66, 0.66, 0.64))
	# Gates in the long side (-20.5, 77) - (-45.4, 79.6), facing the street.
	var p := Vector2(-20.5, 77.0)
	var q := Vector2(-45.4, 79.6)
	var out := Vector2(-(q - p).y, (q - p).x).normalized()
	if out.y > 0.0:
		out = -out
	for k in range(5):
		var a := p.lerp(q, 0.04 + k * 0.193)
		var b := p.lerp(q, 0.19 + k * 0.193)
		_face(a + out * 0.05, b + out * 0.05, 0.0, 4.2, out, "shutter", Color(0.7, 0.1, 0.08))
		_face(a + out * 0.06, b + out * 0.06, 4.2, 4.5, out, "plain", Color(0.1, 0.1, 0.1))
		_light(Vector3((a.x + b.x) * 0.5 + out.x * 1.5, 4.9, (a.y + b.y) * 0.5 + out.y * 1.5), Color("fff0d0"), 1.0, 8.0, false, 0.0, 0.5, 90.0)
	# The tower.
	var foot := Vector3(-16.0, 0, 70.5)
	_part("plaster", foot + Vector3(0, 8.5, 0), Vector3(3.6, 17.0, 3.6), Color(0.94, 0.94, 0.92))
	for k in range(3):
		_part("plain", foot + Vector3(0, 14.0 + k * 0.9, 0), Vector3(3.66, 0.4, 3.66), Color(0.72, 0.1, 0.08))
	_part("beton", foot + Vector3(0, 17.15, 0), Vector3(4.0, 0.3, 4.0), Color(0.4, 0.4, 0.4))
	_glow_ball(foot + Vector3(0, 17.6, 0), 0.18, Color("ff2a1a"), 6.0)
	_solid(foot + Vector3(0, 8.5, 0), Vector3(3.6, 17.0, 3.6))
	var title := lettering("FEUERWEHR", foot + Vector3(0, 12.0, -1.85), 140, Color("f2f2f2"))
	title.rotation.y = PI
	var over := lettering("FEUERWEHR", Vector3(-33.0, 5.4, 78.0) + Vector3(out.x, 0, out.y) * 0.1, 120, Color("c21a12"))
	over.rotation.y = atan2(out.x, out.y)
	# The supply of the map: ammunition and first aid on the forecourt.
	_station("ammo", "MUNITION", "60", Vector3(-30.0, 0, 60.0), PI / 2, Color("84d4c2"))
	_station("health", "ERSTE HILFE", "100", Vector3(-26.0, 0, 60.0), PI / 2, Color("f5b68e"))
	_light(Vector3(-28.0, 3.0, 59.0), Color("dff0ff"), 1.4, 9.0, false, 0.0, 0.5, 90.0)

# ---------------------------------------------------------------- the house 13a

## The ground floor after the owner's video: the front (south) to the street, the garden
## behind the music room (north), the annex to the west, through it into the works.
func _lay_house() -> void:
	_begin_zone("house", "villa", ["town"])
	area = ""
	_own_dice(41313)
	var t := ROOM_TALL
	var skin := {"skin_top": EAVES, "skin_mat": "plaster", "skin_tint": Color(0.93, 0.89, 0.76)}
	_room("hall", ground, Rect2(3, 3, 7, 7.5), t, "entry", _with(skin, {"skin": [EAST, SOUTH]}))
	_room("kitchen", ground, Rect2(-3.5, 4.8, 6.5, 5.7), t, "kitchen", _with(skin, {"skin": [SOUTH]}))
	_room("utility", ground, Rect2(-10, 4.8, 6.5, 5.7), t, "store", _with(skin, {"skin": [SOUTH]}))
	_room("side_hall", ground, Rect2(-10, 3, 13, 1.8), t, "parquet")
	_room("corridor", ground, Rect2(5, -4, 1.8, 7), t, "parquet")
	_room("study", ground, Rect2(6.8, -4, 3.2, 7), t, "study", _with(skin, {"skin": [EAST]}))
	_room("bath", ground, Rect2(-0.5, -1, 5.5, 4), t, "bath")
	_room("office", ground, Rect2(-5, -1, 4.5, 4), t, "office")
	_room("dogroom", ground, Rect2(-8.2, -1, 3.2, 4), t, "green")
	_room("annex", ground, Rect2(-10, -10.5, 1.8, 13.5), t, "annex", _with(skin, {"skin": [NORTH]}))
	_room("bedroom", ground, Rect2(-8.2, -5.5, 7.7, 4.5), t, "yellow")
	_room("pc", ground, Rect2(-8.2, -10.5, 4.7, 5), t, "parquet", _with(skin, {"skin": [NORTH]}))
	_room("storage", ground, Rect2(-3.5, -10.5, 3, 5), t, "green", _with(skin, {"skin": [NORTH]}))
	_room("pantry", ground, Rect2(-0.5, -4, 5.5, 3), t, "store")
	_room("music", ground, Rect2(-0.5, -10.5, 10.5, 6.5), t, "music", _with(skin, {"skin": [NORTH, EAST]}))
	# Ways out: the front door under its canopy, the garden door with its iron grille.
	_opening("hall", SOUTH, 7.5, 1.3)
	_opening("music", NORTH, 4.5, 1.3)
	_door("side_hall", "hall", 3.9, 1.2)
	_door("hall", "corridor", 5.9, 1.2)
	_door("side_hall", "kitchen", 0.0, 1.1)
	_door("side_hall", "utility", -6.5, 1.0)
	_door("bath", "side_hall", 1.8, 1.0)
	_door("office", "side_hall", -2.8, 1.0)
	_door("annex", "side_hall", -9.1, 1.1)
	_door("corridor", "study", 0.0, 1.0)
	_door("music", "corridor", 5.9, 1.2)
	_door("pantry", "corridor", -2.5, 1.0)
	_door("annex", "dogroom", 1.0, 1.0)
	_door("annex", "bedroom", -3.2, 1.0)
	_door("annex", "pc", -8.0, 1.0)
	_door("pc", "storage", -8.0, 1.0)
	_door("dogroom", "bedroom", -6.6, 1.0)
	for spec in [
		["hall", SOUTH, 4.6], ["hall", EAST, 6.8], ["kitchen", SOUTH, -1.6], ["kitchen", SOUTH, 1.4], ["utility", SOUTH, -7.0],
		["study", EAST, -0.5], ["music", NORTH, 0.8], ["music", NORTH, 8.2], ["music", EAST, -5.4], ["pc", NORTH, -6.0], ["storage", NORTH, -2.0]
	]:
		_pane(str(spec[0]), int(spec[1]), float(spec[2]), 1.2, 0.95, 2.15, "window")
	_dress_house()
	_house_roof()
	_shared_dice()
	_end_zone()

func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	out.merge(extra, true)
	return out

## The roof of 13a: a saddle with the gables to the street and to the garden, the
## murals' frieze under the eaves.
func _house_roof() -> void:
	_chunk("Roof")
	var rise := HOUSE.size.x * 0.5 * tan(deg_to_rad(PITCH))
	var color := Color(0.4, 0.2, 0.15)
	var cream := Color(0.93, 0.89, 0.76)
	var z0 := HOUSE.position.y - 0.25
	var z1 := HOUSE.end.y + 0.25
	# East half, down to an eave beyond the wall; the west half meets the wall of the works.
	_roof(Vector2(HOUSE.end.x + 0.25, z1), Vector2(HOUSE.end.x + 0.25, z0), Vector2(0, z0), Vector2(0, z1), EAVES, rise, color)
	_roof(Vector2(HOUSE.position.x - 0.1, z0 + 0.3), Vector2(HOUSE.position.x - 0.1, z1 - 0.3), Vector2(0, z1 - 0.3), Vector2(0, z0 + 0.3), EAVES, rise, color)
	for z in [HOUSE.end.y + 0.25, HOUSE.position.y - 0.25]:
		var out := 1.0 if z > 0.0 else -1.0
		var a := Vector3(HOUSE.position.x, EAVES, z)
		var b := Vector3(HOUSE.end.x + 0.25, EAVES, z)
		var top := Vector3(0, EAVES + rise, z)
		if (b - a).cross(top - a).z * out < 0.0:
			batch.triangle(mats["plaster"], a, top, b, cream)
		else:
			batch.triangle(mats["plaster"], a, b, top, cream)
		# The painted frieze and two of the pictures on the gable.
		batch.box(mats["plaster"], Vector3(0, EAVES + 0.35, z + out * 0.02), Vector3(16.0, 0.35, 0.03), Color(0.72, 0.6, 0.38))
		for x in [-5.0, 4.5]:
			batch.box(mats["plaster"], Vector3(x, EAVES + 1.5, z + out * 0.02), Vector3(3.6, 1.6, 0.03), Color(0.66, 0.56, 0.42))
			batch.box(mats["plaster"], Vector3(x + 0.4, EAVES + 1.6, z + out * 0.03), Vector3(1.6, 0.9, 0.03), Color(0.55, 0.42, 0.3))
	# The attic floor seen from nowhere, and a body for the roof.
	_part_shape(Vector3(0, EAVES + 0.1, 0), Vector3(HOUSE.size.x, 0.2, HOUSE.size.y))

func _dress_house() -> void:
	_chunk("Rooms")
	# --- the hall: the spiral stair by the front door, the sofas, the cabinet between the
	# green columns, the weapon locker, ammunition and first aid.
	var stair := Vector3(4.2, 0, 9.6)
	batch.cylinder(mats["chrome"], stair, 0.06, 0.06, ROOM_TALL, Color(0.92, 0.92, 0.92), 10)
	for k in range(14):
		var turn := k * 0.42
		var step := stair + Vector3(cos(turn) * 0.42, 0.18 * (k + 1), sin(turn) * 0.42)
		batch.box(mats["parquet"], step, Vector3(0.8, 0.04, 0.32), Color(0.85, 0.72, 0.52), Basis(Vector3.UP, -turn))
	_round_solid(stair, 0.85, ROOM_TALL)
	_sofa(Vector3(6.5, 0, 8.2), PI, Color(0.42, 0.48, 0.58), 1.8)
	_rug(Vector3(6.5, 0.012, 6.8), Vector2(2.6, 1.8), Color(0.72, 0.2, 0.18))
	for z in [6.0, 8.2]:
		batch.cylinder(mats["marble"], Vector3(3.35, 0, z), 0.16, 0.14, ROOM_TALL, Color(0.16, 0.36, 0.26), 12)
		_part("plaster", Vector3(3.35, ROOM_TALL - 0.12, z), Vector3(0.42, 0.18, 0.42), Color(0.8, 0.66, 0.3))
	_model("GothicCabinet_01", Vector3(3.5, 0, 7.1), PI / 2, {"height": 2.0})
	_part("plaster", Vector3(6.5, ROOM_TALL - 0.02, 6.75), Vector3(1.2, 0.02, 1.2), Color(0.9, 0.75, 0.3))
	_glow_ball(Vector3(6.5, ROOM_TALL - 0.08, 6.75), 0.18, Color("ffd060"), 4.0)
	_locker(Vector3(8.4, 0, 3.55), Vector3(0, 0, 1))
	_station("ammo", "MUNITION", "60", Vector3(9.42, 0, 5.0), PI, Color("84d4c2"))
	_station("health", "ERSTE HILFE", "100", Vector3(9.42, 0, 8.4), PI, Color("f5b68e"))
	# --- the kitchen: white units along the window wall, the fridge, table and chairs.
	for x in [-2.6, -1.0, 0.6, 2.2]:
		_prop("plain", Vector3(x, 0.45, 9.8), Vector3(1.55, 0.9, 0.62), Color(0.94, 0.94, 0.93))
	_part("granite", Vector3(-0.2, 0.93, 9.8), Vector3(6.3, 0.05, 0.66), Color(0.3, 0.3, 0.31))
	_prop("steel", Vector3(-2.85, 0.95, 5.45), Vector3(0.75, 1.9, 0.75), Color(0.7, 0.72, 0.74))
	_prop("plain", Vector3(2.45, 1.1, 5.5), Vector3(0.6, 2.2, 0.62), Color(0.94, 0.94, 0.93))
	_table(Vector3(0.0, 0, 7.2), Vector3(1.6, 0.76, 0.9), Color(0.55, 0.4, 0.28))
	for x in [-0.45, 0.45]:
		_chair(Vector3(x, 0, 6.4), 0.0, Color(0.5, 0.5, 0.52))
		_chair(Vector3(x, 0, 8.0), PI, Color(0.5, 0.5, 0.52))
	# --- the utility room: washing machine, shelves, boots.
	_prop("plain", Vector3(-9.3, 0.45, 9.8), Vector3(0.6, 0.9, 0.6), Color(0.92, 0.92, 0.92))
	_model("steel_frame_shelves_01", Vector3(-5.0, 0, 9.9), PI, {"height": 2.0})
	# --- the bath: the tub in the corner, the shower, the basin, the WC.
	batch.ellipsoid(mats["plain"], Vector3(3.8, 0.35, 0.0), Vector3(0.85, 0.35, 0.45), Color(0.96, 0.96, 0.95), Basis.IDENTITY, 10, 5)
	_solid(Vector3(3.8, 0.3, 0.0), Vector3(1.7, 0.6, 0.9))
	_part("pane", Vector3(2.4, 1.1, -0.2), Vector3(0.02, 2.0, 1.2), Color.WHITE)
	_prop("panelwood", Vector3(-0.05, 0.42, 1.0), Vector3(0.5, 0.84, 1.2), Color(0.72, 0.58, 0.4))
	batch.cylinder(mats["plain"], Vector3(-0.05, 0.86, 1.0), 0.2, 0.17, 0.14, Color(0.97, 0.97, 0.97), 12)
	_model("ornate_mirror_01", Vector3(-0.27, 1.1, 1.0), PI / 2, {"height": 1.0, "solid": false})
	_part("plain", Vector3(-0.05, 0.22, -0.5), Vector3(0.5, 0.4, 0.38), Color(0.96, 0.96, 0.96))
	# --- the office: the long desk with printers, the globe, the red rug.
	_model("metal_office_desk", Vector3(-2.8, 0, -0.45), 0.0, {"width": 1.6})
	_model("modern_arm_chair_01", Vector3(-2.8, 0, 0.5), PI, {"height": 0.9})
	batch.ellipsoid(mats["plain"], Vector3(-4.4, 1.0, 2.4), Vector3.ONE * 0.28, Color(0.35, 0.5, 0.6), Basis.IDENTITY, 10, 6)
	_part("metal", Vector3(-4.4, 0.36, 2.4), Vector3(0.08, 0.72, 0.08), Color(0.3, 0.24, 0.16))
	_rug(Vector3(-2.8, 0.012, 1.4), Vector2(2.4, 1.6), Color(0.62, 0.14, 0.12))
	# --- the study: book wall, desk, the television, the treadmill.
	for z in [-3.3, -2.3]:
		_model("Shelf_01", Vector3(9.55, 0, z), -PI / 2, {"height": 2.2})
	_model("WoodenTable_02", Vector3(8.6, 0, 2.2), 0.0, {"width": 1.4})
	_model("Television_01", Vector3(7.25, 0.6, -2.4), PI / 2, {"width": 1.0, "solid": false})
	_prop("plain", Vector3(7.3, 0.3, -2.4), Vector3(0.45, 0.6, 1.4), Color(0.2, 0.17, 0.15))
	_prop("metal", Vector3(8.5, 0.2, 0.2), Vector3(0.8, 0.4, 1.7), Color(0.12, 0.12, 0.13))
	_part("metal", Vector3(8.5, 0.9, -0.55), Vector3(0.7, 1.0, 0.08), Color(0.18, 0.18, 0.2))
	# --- the pantry: shelves of jars.
	_model("steel_frame_shelves_01", Vector3(2.2, 0, -3.6), 0.0, {"height": 2.0})
	# --- the music room: the navy shelf wall, the piano, the red rug, the ladder up.
	_part("panelwood", Vector3(-0.09, 1.25, -7.6), Vector3(0.42, 2.5, 5.0), Color(0.12, 0.16, 0.3))
	_solid(Vector3(-0.09, 1.25, -7.6), Vector3(0.42, 2.5, 5.0))
	for k in range(4):
		_part("plain", Vector3(0.13, 0.5 + k * 0.55, -7.6), Vector3(0.02, 0.04, 4.8), Color(0.7, 0.6, 0.4))
	_prop("plain", Vector3(0.75, 0.65, -7.6), Vector3(0.6, 1.3, 1.5), Color(0.04, 0.04, 0.05))
	_part("plain", Vector3(1.1, 0.75, -7.6), Vector3(0.25, 0.06, 1.4), Color(0.92, 0.92, 0.9))
	_rug(Vector3(4.5, 0.012, -7.0), Vector2(3.4, 2.4), Color(0.68, 0.12, 0.12))
	_model("modern_arm_chair_01", Vector3(2.2, 0, -7.2), PI / 2, {"height": 0.85})
	for k in range(8):
		_part("panelwood", Vector3(9.4, 0.3 + k * 0.3, -9.0 + k * 0.18), Vector3(0.7, 0.04, 0.2), Color(0.55, 0.4, 0.26))
	for z in [-9.0, -7.6]:
		_part("panelwood", Vector3(9.4, 1.25, z), Vector3(0.06, 2.5, 0.06), Color(0.5, 0.36, 0.24))
	_solid(Vector3(9.4, 1.25, -8.3), Vector3(0.8, 2.5, 1.6))
	# --- the green room: the dog's pen, desks with a computer.
	for k in range(6):
		_part("metal", Vector3(-7.9 + k * 0.28, 0.45, 1.8), Vector3(0.02, 0.9, 0.02), Color(0.3, 0.3, 0.32))
	_part("metal", Vector3(-7.2, 0.9, 1.8), Vector3(1.5, 0.03, 0.03), Color(0.3, 0.3, 0.32))
	_part("cloth", Vector3(-7.2, 0.03, 2.4), Vector3(1.4, 0.06, 1.0), Color(0.2, 0.3, 0.6))
	_prop("plain", Vector3(-5.55, 0.37, 1.2), Vector3(0.7, 0.74, 1.6), Color(0.9, 0.9, 0.88))
	_part("plain", Vector3(-5.4, 0.95, 1.2), Vector3(0.05, 0.4, 0.6), Color(0.05, 0.05, 0.06))
	# --- the bedroom: the bed, the mirrored wardrobe, the case of figures.
	_bed(Vector3(-4.0, 0, -3.3), PI / 2, Color(0.55, 0.56, 0.6), 1.6)
	_prop("plain", Vector3(-7.3, 1.05, -5.0), Vector3(1.6, 2.1, 0.6), Color(0.94, 0.94, 0.92))
	_part("pane", Vector3(-7.3, 1.1, -4.69), Vector3(0.6, 1.6, 0.02), Color.WHITE)
	_prop("plain", Vector3(-1.0, 0.9, -5.1), Vector3(0.8, 1.8, 0.4), Color(0.06, 0.06, 0.07))
	# --- the young man's room: shelves as walls, the desk with the computer, a bed.
	_model("Shelf_01", Vector3(-5.8, 0, -5.95), PI, {"height": 1.8})
	_prop("plain", Vector3(-4.3, 0.37, -9.9), Vector3(1.4, 0.74, 0.7), Color(0.3, 0.22, 0.16))
	_part("plain", Vector3(-4.3, 1.0, -10.05), Vector3(0.7, 0.42, 0.05), Color(0.05, 0.06, 0.08))
	_glow_box(Vector3(-4.3, 1.0, -10.02), Vector3(0.64, 0.36, 0.01), Color("7fb0ff"), 1.2)
	_bed(Vector3(-7.2, 0, -9.3), 0.0, Color(0.28, 0.3, 0.36), 1.0)
	# --- the store room: ladder and shelves.
	_model("steel_frame_shelves_01", Vector3(-2.0, 0, -10.0), 0.0, {"height": 2.0})
	_part("metal", Vector3(-1.0, 1.0, -6.3), Vector3(0.45, 2.0, 0.06), Color(0.7, 0.72, 0.72), Vector3(-12, 0, 0))
	# --- the side corridor: the dresser, the soldier beside the annex door.
	_prop("plain", Vector3(-6.5, 0.45, 3.42), Vector3(1.2, 0.9, 0.42), Color(0.9, 0.86, 0.74))
	_part("plain", Vector3(-8.0, 0.9, 3.4), Vector3(0.4, 1.8, 0.3), Color(0.28, 0.32, 0.22))
	batch.ellipsoid(mats["plain"], Vector3(-8.0, 1.92, 3.4), Vector3(0.12, 0.14, 0.12), Color(0.8, 0.66, 0.54), Basis.IDENTITY, 8, 5)
	# --- the annex: cork board, pictures.
	_part("panelwood", Vector3(-9.78, 1.5, -6.5), Vector3(0.04, 0.9, 1.4), Color(0.62, 0.46, 0.3))
	# The painted door into the works: a red curtain, and its words.
	for z in [-4.0, -2.0]:
		_part("velvet", Vector3(-9.78, 1.25, z), Vector3(0.03, 2.3, 0.4), Color(0.6, 0.06, 0.06))
	var words := lettering("Der Vorhang\nhat sich geöffnet!", Vector3(-9.76, 1.6, -5.0), 22, Color("f0d890"))
	words.rotation.y = PI / 2

## The weapon locker of the map, looking the way `facing` points (see HiveMap._supply).
func _locker(at: Vector3, facing: Vector3) -> void:
	var yaw := atan2(-facing.z, facing.x)
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	_placed(frame, "steel", Vector3(-0.1, 1.05, 0), Vector3(0.6, 2.1, 1.7), Color("2c3236"))
	_placed(frame, "plain", Vector3(0.21, 1.1, 0), Vector3(0.02, 1.8, 0.02), Color("0d0f10"))
	for row in range(3):
		_placed(frame, "plain", Vector3(0.21, 0.5 + row * 0.6, 0), Vector3(0.02, 0.04, 1.5), Color("0d0f10"))
	_glow_box(frame * Vector3(0.22, 2.0, 0), Vector3(0.02, 0.05, 1.5), Color("e8bd79"), 2.2, frame.basis)
	var label := lettering("WAFFENSCHRANK", frame * Vector3(0.25, 2.3, 0), 30, Color("e8bd79"))
	label.rotation.y = yaw + PI / 2
	_solid(at + Vector3(0, 1.05, 0) + frame.basis * Vector3(-0.1, 0, 0), Vector3(0.6, 2.1, 1.7), true, yaw)
	stations.append({"kind": "shop", "title": "WAFFENSCHRANK", "pos": at, "view": {"position": at + facing * 2.3 + Vector3(0, 1.55, 0), "target": at + Vector3(0, 1.2, 0)}})
	shop_view = {"position": at + facing * 2.3 + Vector3(0, 1.55, 0), "target": at + Vector3(0, 1.2, 0)}
	points["shop"] = at + facing * 0.9

# ---------------------------------------------------------------- the gate works

## The works beside the house (a gate maker, made-up): the rustic room behind the
## painted door, the store, the office with the way in from the yard, and the hall.
func _lay_works() -> void:
	_begin_zone("works", "plant", ["town", "house"])
	area = ""
	_own_dice(41314)
	var skin := {"skin_top": WORKS_TOP, "skin_mat": "plaster", "skin_tint": Color(0.88, 0.88, 0.86)}
	_room("stube", ground, Rect2(-17, -6.5, 7, 7), 2.8, "stube")
	_room("lager", ground, Rect2(-17, -12.6, 7, 6.1), 3.0, "store", _with(skin, {"skin": [NORTH]}))
	_room("torbuero", ground, Rect2(-17, 0.5, 7, 10.1), 2.8, "annex", _with(skin, {"skin": [SOUTH]}))
	_room("werkhalle", ground, Rect2(-30, -12.6, 13, 23.2), 6.5, "works", _with(skin, {"skin": [NORTH, WEST, SOUTH]}))
	_door("stube", "annex", -3.0, 1.1)
	_door("werkhalle", "stube", -3.0, 1.3)
	_door("lager", "stube", -13.5, 1.0)
	_door("werkhalle", "lager", -9.5, 1.3)
	_door("stube", "torbuero", -13.5, 1.0)
	_door("werkhalle", "torbuero", 5.0, 1.3)
	_opening("torbuero", SOUTH, -12.5, 1.2)
	_opening("werkhalle", SOUTH, -23.5, 4.4, {"height": 4.2})
	_opening("werkhalle", WEST, 0.0, 1.2)
	_opening("werkhalle", NORTH, -25.5, 1.2)
	for x in [-28.0, -21.5, -19.0]:
		_pane("werkhalle", NORTH, x, 2.2, 4.3, 5.6, "glass")
	for z in [-8.0, -3.0, 5.0]:
		_pane("werkhalle", WEST, z, 2.2, 4.3, 5.6, "glass")
	_pane("torbuero", SOUTH, -15.3, 1.4, 0.95, 2.15, "window")
	_dress_works()
	_works_roof()
	_shared_dice()
	_end_zone()

func _works_roof() -> void:
	_chunk("Roof")
	_part("beton", Vector3(WORKS.get_center().x, WORKS_TOP + 0.15, WORKS.get_center().y), Vector3(WORKS.size.x + 0.5, 0.3, WORKS.size.y + 0.5), Color(0.35, 0.35, 0.36))
	_part_shape(Vector3(WORKS.get_center().x, WORKS_TOP + 0.15, WORKS.get_center().y), Vector3(WORKS.size.x + 0.5, 0.3, WORKS.size.y + 0.5))
	# The wall of the works above the roof of the house.
	_part("plaster", Vector3(WORKS.end.x + 0.12, (ROOM_TALL + WORKS_TOP) * 0.5, WORKS.get_center().y), Vector3(0.24, WORKS_TOP - ROOM_TALL, WORKS.size.y + 0.4), Color(0.88, 0.88, 0.86))
	# Above the low rooms the works' walls go on up to the roof (inside nobody sees it).
	_part("plaster", Vector3(-13.5, 4.8, WORKS.position.y - 0.12), Vector3(7.4, 4.0, 0.24), Color(0.88, 0.88, 0.86))
	_part("plaster", Vector3(-13.5, 4.8, WORKS.end.y + 0.12), Vector3(7.4, 4.0, 0.24), Color(0.88, 0.88, 0.86))
	var plate := lettering("BRETTNER TORBAU", Vector3(-20.0, 5.6, WORKS.end.y + 0.3), 150, Color("e7eef3"))
	plate.rotation.y = 0.0
	_part("plain", Vector3(-20.0, 5.6, WORKS.end.y + 0.27), Vector3(9.5, 1.1, 0.05), Color(0.12, 0.24, 0.42))
	_light(Vector3(-23.5, 4.8, WORKS.end.y + 1.2), Color("fff0d0"), 1.4, 10.0, false, 0.0, 0.5, 90.0)

func _dress_works() -> void:
	_chunk("Rooms")
	# --- the rustic room: the stone wall, the round table, the counter, the lantern.
	for z in [-5.0, -1.0]:
		_part("stonewall", Vector3(-16.75, 1.4, z), Vector3(0.12, 2.8, 2.6), Color(0.7, 0.66, 0.6))
	batch.cylinder(mats["furniture_wood"], Vector3(-13.5, 0, -3.2), 0.08, 0.08, 0.72, Color(0.4, 0.28, 0.18), 8)
	batch.cylinder(mats["furniture_wood"], Vector3(-13.5, 0.72, -3.2), 0.65, 0.65, 0.05, Color(0.5, 0.34, 0.2), 18)
	_round_solid(Vector3(-13.5, 0, -3.2), 0.65, 0.78)
	for k in range(4):
		var turn := TAU * k / 4.0
		_chair(Vector3(-13.5 + cos(turn) * 1.0, 0, -3.2 + sin(turn) * 1.0), -turn + PI / 2, Color(0.45, 0.32, 0.2))
	_prop("panelwood", Vector3(-10.9, 0.55, -5.4), Vector3(1.2, 1.1, 1.6), Color(0.4, 0.28, 0.18))
	for x in [-15.5, -12.5]:
		_part("panelwood", Vector3(x, 2.7, -3.0), Vector3(0.2, 0.18, 7.0), Color(0.3, 0.2, 0.13))
	# --- the store: shelves and boxes.
	for x in [-15.8, -13.4]:
		_model("steel_frame_shelves_01", Vector3(x, 0, -12.1), 0.0, {"height": 2.2})
	_model("cardboard_box_01", Vector3(-11.2, 0, -8.0), 0.3, {"width": 0.6})
	# --- the office of the works: the counter, a desk, the samples.
	_prop("panelwood", Vector3(-13.5, 0.55, 4.8), Vector3(3.2, 1.1, 0.6), Color(0.3, 0.32, 0.36))
	_model("metal_office_desk", Vector3(-15.0, 0, 2.0), PI / 2, {"width": 1.5})
	_model("modern_arm_chair_01", Vector3(-14.0, 0, 2.0), -PI / 2, {"height": 0.9})
	for k in range(3):
		_part("shutter", Vector3(-10.35, 1.2, 6.0 + k * 1.3), Vector3(0.05, 2.0, 1.1), [Color(0.85, 0.85, 0.83), Color(0.32, 0.34, 0.36), Color(0.55, 0.36, 0.22)][k])
	var title := lettering("BRETTNER TORBAU\nTore · Antriebe · Service", Vector3(-13.5, 1.95, 0.75), 34, Color("cfe0f0"))
	title.rotation.y = 0.0
	# --- the hall: shelves along the walls, the scaffold, gate panels, the gallery shelf.
	for z in [-11.0, -7.5, -4.0]:
		_model("steel_frame_shelves_01", Vector3(-29.3, 0, z), PI / 2, {"height": 2.4})
	for x in [-27.5, -24.0]:
		_model("steel_frame_shelves_01", Vector3(x, 0, -12.0), 0.0, {"height": 2.4})
	for k in range(6):
		_part("shutter", Vector3(-19.0, 1.4, 2.0 + k * 0.18), Vector3(3.2, 2.6, 0.05), [Color(0.85, 0.85, 0.83), Color(0.32, 0.34, 0.36)][k % 2], Vector3(0, 0, 4))
	_solid(Vector3(-19.0, 1.4, 2.45), Vector3(3.3, 2.8, 1.2))
	# The scaffold tower.
	var foot := Vector3(-24.5, 0, -4.5)
	for x in [-0.7, 0.7]:
		for z in [-0.7, 0.7]:
			_part("metal", foot + Vector3(x, 1.9, z), Vector3(0.05, 3.8, 0.05), Color(0.6, 0.62, 0.64))
	for y in [1.2, 2.4, 3.6]:
		_part("panelwood", foot + Vector3(0, y, 0), Vector3(1.5, 0.05, 1.5), Color(0.55, 0.42, 0.28))
	_solid(foot + Vector3(0, 1.9, 0), Vector3(1.5, 3.8, 1.5))
	# The gallery shelf along the north wall, on posts, with paintings and boxes on it.
	_part("panelwood", Vector3(-23.5, 3.0, -11.6), Vector3(12.6, 0.12, 1.6), Color(0.5, 0.38, 0.26))
	for x in [-29.4, -23.5, -20.5, -17.6]:
		_part("metal", Vector3(x, 1.5, -10.9), Vector3(0.1, 3.0, 0.1), Color(0.3, 0.3, 0.32))
		_solid(Vector3(x, 1.5, -10.9), Vector3(0.14, 3.0, 0.14))
	for x in [-28.0, -23.0, -19.5]:
		_model("cardboard_box_01", Vector3(x, 3.06, -11.7), 0.2, {"width": 0.7, "solid": false})
	_model("hand_truck", Vector3(-21.0, 0, -2.0), 0.6, {"height": 1.2})
	_model("barrel_03", Vector3(-28.6, 0, 8.6), 0.0, {"height": 0.95})
	# Ammunition and first aid for whoever holds the hall.
	_station("ammo", "MUNITION", "60", Vector3(-29.4, 0, 2.4), 0.0, Color("84d4c2"))
	_station("health", "ERSTE HILFE", "100", Vector3(-29.4, 0, 5.4), 0.0, Color("f5b68e"))

# ---------------------------------------------------------------- after the build

func _after_build() -> void:
	points.merge({
		"menu_camera": Vector3(16.0, 2.2, 30.0), "menu_target": Vector3(0.0, 3.0, 6.0),
		"yard_south": Vector3(0, 0, 22.0), "hall": Vector3(6.5, 0, 7.0), "street": Vector3(0, 0, 43.0),
		"fire_station": Vector3(-28.0, 0, 56.0), "works": Vector3(-23.5, 0, 0.0), "garden": Vector3(4.0, 0, -17.0),
		"roundabout": Vector3(272.0, 0, 50.0), "market": Vector3(150.0, 0, 25.0)
	}, false)
	player_start = Vector3(6.5, 0.05, 7.0)
	# Where the infected come from: the fields north and south, the ends of the street,
	# the roundabout, and nearer, the yards around the house.
	var wanted := [
		Vector2(-90, 45), Vector2(-88, -40), Vector2(-40, -50), Vector2(30, -50), Vector2(100, -45), Vector2(170, -50),
		Vector2(295, -30), Vector2(295, 50), Vector2(290, 115), Vector2(200, 118), Vector2(110, 118), Vector2(40, 118),
		Vector2(-60, 115), Vector2(-88, 90), Vector2(-60, -25), Vector2(40, 25), Vector2(-55, 40), Vector2(25, -30)
	]
	spawn_points.clear()
	for spot: Vector2 in wanted:
		var cell := _free_near(ground, spot, 12)
		if cell.x < 999999:
			spawn_points.append(Vector3(cell.x * CELL, 0, cell.y * CELL))
	if spawn_points.is_empty():
		push_error("AppenweierMap: no free spawn point")
		spawn_points.append(Vector3(0, 0, 30))
