class_name HiveCore
extends CabinMap
## The machinery of the second map (see HiveMap): floors at any height, rooms that build
## their own floor, ceiling, walls and lamps from a style, doorways and panes between them,
## zones that are only drawn while the viewer is near, and path finding over all of it.
##
## A map is declared first and built afterwards. Declared are floors (_floor), rooms
## (_room), what joins two rooms (_door) or opens one to the outside (_opening), panes in
## walls (_pane) and flights of stairs (_link). A room is given by the middle lines of its
## walls: two rooms that share such a line share that wall, each builds its own half of
## it. _compile then builds everything and lays out the navigation.
##
## It is a CabinMap so that the game, the infected and the squad can use it like the
## farm; nothing of the farm itself is built (HiveMap._ready does not call the farm's).

const WALL := 0.4
const HALF := 0.2
const DOOR_TALL := 2.5
const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3
## Which way each side of a room looks, in the plan (x, z).
const OUT := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
## Distance at which the lamps of the rooms begin to fade for the viewer.
const LAMP_FADE := 36.0
## Rooms of other zones are drawn from this far away, so that nothing appears or goes at
## the door one is walking through.
const ZONE_SIGHT := 64.0
## The light that is everywhere, the haze and the sky, by where the viewer is: in the
## park, in the villa, or under the ground.
## ("tint" is the colour of the haze far away. Every mood has every value: the light
## glides from one to the next as the viewer walks from zone to zone.)
const MOODS := {
	"out": {"ambient": Color(0.34, 0.44, 0.6), "energy": 0.56, "fog": 0.0055, "haze": 0.011, "glow": 0.8, "sky": 1.0, "moon": 1.0, "tint": Color(0.16, 0.2, 0.26)},
	"villa": {"ambient": Color(0.5, 0.43, 0.38), "energy": 0.36, "fog": 0.003, "haze": 0.008, "glow": 0.25, "sky": 1.0, "moon": 1.0, "tint": Color(0.2, 0.17, 0.13)},
	"under": {"ambient": Color(0.52, 0.57, 0.63), "energy": 0.62, "fog": 0.0012, "haze": 0.006, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.16, 0.2, 0.26)},
	# The station: sodium light on concrete, dust in the air.
	"sodium": {"ambient": Color(0.62, 0.5, 0.36), "energy": 0.46, "fog": 0.003, "haze": 0.013, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.22, 0.16, 0.09)},
	# The terminal, the offices, the canteen: cold and white.
	"cold": {"ambient": Color(0.5, 0.57, 0.66), "energy": 0.52, "fog": 0.0024, "haze": 0.008, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.14, 0.19, 0.26)},
	# Where the facility has locked itself down: red, and nothing else.
	"alarm": {"ambient": Color(0.74, 0.2, 0.15), "energy": 0.52, "fog": 0.004, "haze": 0.015, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.3, 0.05, 0.04)},
	# The central hall.
	"core": {"ambient": Color(0.42, 0.52, 0.66), "energy": 0.36, "fog": 0.003, "haze": 0.011, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.1, 0.17, 0.24)},
	# The plant rooms: dim, warm, oily.
	"plant": {"ambient": Color(0.56, 0.45, 0.32), "energy": 0.44, "fog": 0.004, "haze": 0.014, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.2, 0.14, 0.08)},
	# The research wing: a sick green.
	"sick": {"ambient": Color(0.38, 0.56, 0.52), "energy": 0.44, "fog": 0.005, "haze": 0.01, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.08, 0.2, 0.18)},
	# The containment hall, the tower hall: darker and colder than anywhere else in the
	# facility, with what glows in it and a haze the lamps stand in.
	"deep": {"ambient": Color(0.28, 0.36, 0.5), "energy": 0.3, "fog": 0.006, "haze": 0.022, "glow": 0.0, "sky": 0.0, "moon": 0.0, "tint": Color(0.07, 0.1, 0.14)}
}
## The moods of places under the ground (no moon, no shadows of it).
const BELOW := ["under", "sodium", "cold", "alarm", "core", "plant", "sick", "deep"]
## Water that stands in a room: dark, smooth, with a slow swell that bends what is
## mirrored in it. It is drawn where it stands deeper than a few millimetres over the
## floor `floor_y`, so that a sheet of it may rise out of the floor like a shore.
const FLOOD := """shader_type spatial;
render_mode cull_back, shadows_disabled;
uniform sampler2D ripples : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.012, 0.05, 0.055);
uniform float floor_y = -9.6;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float depth = world.y - floor_y;
	if (depth < 0.006) {
		discard;
	}
	vec3 a = texture(ripples, world.xz * 0.19 + vec2(TIME * 0.011, TIME * 0.016)).rgb * 2.0 - 1.0;
	vec3 b = texture(ripples, world.xz * 0.43 + vec2(-TIME * 0.019, TIME * 0.008)).rgb * 2.0 - 1.0;
	vec2 tilt = (a.xy + b.xy) * 0.05;
	vec3 up = normalize(vec3(tilt.x, 1.0, tilt.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	float shore = smoothstep(0.006, 0.08, depth);
	ALBEDO = mix(vec3(0.045, 0.06, 0.06), deep, shore);
	ROUGHNESS = mix(0.22, 0.03, shore);
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
"""

## The floors: {id, label, y, bounds (metres), region (cells), rooms}. Its index is the
## level a navigation grid has.
var floors: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var room_of: Dictionary = {}
var doors: Array[Dictionary] = []
var door_of: Dictionary = {}
var panes: Array[Dictionary] = []
## Parts of the map that can be closed (see lock, unlock). A gate belongs to the area
## behind it.
var areas: Array[String] = []
## What is being declared or built right now belongs to this zone and this area.
var zone := ""
var area := ""
## Zone -> {node, sees, mood, flickers, shadows, box}. A zone is drawn while the viewer is
## in it, in one that sees it, or nearer to its rooms than ZONE_SIGHT.
var zones: Dictionary = {}
var zone_child := 0
var zone_flicker := 0
## Zone -> shown or hidden whatever the viewer sees (the train during its ride).
var forced: Dictionary = {}
var here_zone := ""
## Where the viewer is, and where the zones were last chosen from.
var here_at := Vector3.ZERO
var shown_at := Vector3(INF, INF, INF)
var styles: Dictionary = {}
var model_cache: Dictionary = {}
var tinted: Dictionary = {}
var hubs: Array[Vector2i] = []
## The closed cells of every level as a picture, for the map in the corner of the screen.
var plan_pictures: Array[Image] = []
var plan_textures: Array = []
var plan_stamp := 0
var plan_made := -1
var mood := "out"
var mood_now: Dictionary = {}
## Lamp glass that is a material of its own (see _own_glow).
var lone_glows: Array = []
## How long the parts of the build took (milliseconds), and the time spent on finding
## paths, for the checks.
var build_times: Dictionary = {}
var path_usec := 0
var path_calls := 0
var door_wait := 0.0

# ---------------------------------------------------------------- declaring

func _floor(id: String, label: String, height: float, bounds: Rect2) -> int:
	var first := Vector2i(floori(bounds.position.x / CELL), floori(bounds.position.y / CELL))
	var last := Vector2i(ceili(bounds.end.x / CELL), ceili(bounds.end.y / CELL))
	floors.append({"id": id, "label": label, "y": height, "bounds": bounds, "region": Rect2i(first, last - first + Vector2i.ONE), "rooms": []})
	obstacles.append([])
	return floors.size() - 1

## Everything declared or built until _end_zone belongs to this zone. `sees` are zones
## that are drawn together with it; `mood` is the light there (see MOODS).
func _begin_zone(id: String, mood_id: String = "", sees: Array = []) -> void:
	zone = id
	if not zones.has(id):
		var node := Node3D.new()
		node.name = "Zone_" + id
		add_child(node)
		zones[id] = {"node": node, "sees": [], "mood": "under", "flickers": [], "shadows": false}
	var entry: Dictionary = zones[id]
	if mood_id != "":
		entry.mood = mood_id
		entry.shadows = not BELOW.has(mood_id)
	for other in sees:
		_zones_see(id, str(other))
	zone_child = get_child_count()
	zone_flicker = flickers.size()

func _end_zone() -> void:
	var entry: Dictionary = zones[zone]
	var node: Node3D = entry.node
	var moved: Array = []
	for index in range(zone_child, get_child_count()):
		moved.append(get_child(index))
	for child in moved:
		remove_child(child)
		node.add_child(child)
	for index in range(zone_flicker, flickers.size()):
		if float(flickers[index].amount) > 0.0:
			(entry.flickers as Array).append(flickers[index])
	zone_child = get_child_count()
	zone_flicker = flickers.size()

func _zones_see(a: String, b: String) -> void:
	if a == b or not zones.has(a) or not zones.has(b):
		return
	if not (zones[a].sees as Array).has(b):
		(zones[a].sees as Array).append(b)
	if not (zones[b].sees as Array).has(a):
		(zones[b].sees as Array).append(a)

## Every chunk belongs to the zone it is built in, whatever the helper that names it.
func _chunk(id: String, shadows: bool = true) -> void:
	var key := zone + "|" + id
	if not chunks.has(key):
		chunks[key] = MeshBatch.new()
		(chunks[key] as MeshBatch).label = key
		chunk_shadows[key] = shadows and bool(zones[zone].shadows) if zones.has(zone) else shadows
	batch = chunks[key]

## A room on a floor. `outer` runs along the middle lines of its walls, `height` is the
## clear height. Options: outdoor (open ground, no shell), walls / floor / ceiling (false
## leaves that part out), bare (sides without a wall), lamps ("none" or a kind of lamp),
## nav (false: nobody walks here), walk (rectangles to walk on instead of the whole room),
## look (changes to its style), skin (sides that are outside walls) and whatever the
## dressing wants to remember.
func _room(id: String, level: int, outer: Rect2, height: float, style: String, options: Dictionary = {}) -> Dictionary:
	var room := {
		"id": id, "level": level, "outer": outer, "inner": outer.grow(-HALF), "y": float(floors[level].y),
		"height": height, "style": style, "zone": zone, "area": area, "outdoor": false,
		"open": [[], [], [], []], "doors": [], "bare": [], "skin": []
	}
	room.merge(options, true)
	rooms.append(room)
	room_of[id] = room
	(floors[level].rooms as Array).append(room)
	return room

## The side of `first` that it shares with `second`, or -1.
func _shared_side(first: Dictionary, second: Dictionary) -> int:
	var a: Rect2 = first.outer
	var b: Rect2 = second.outer
	var over_x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x) > 0.5
	var over_z := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y) > 0.5
	if over_x and absf(a.position.y - b.end.y) < 0.01:
		return NORTH
	if over_x and absf(a.end.y - b.position.y) < 0.01:
		return SOUTH
	if over_z and absf(a.end.x - b.position.x) < 0.01:
		return EAST
	if over_z and absf(a.position.x - b.end.x) < 0.01:
		return WEST
	return -1

func _wall_line(room: Dictionary, side: int) -> float:
	var outer: Rect2 = room.outer
	match side:
		NORTH:
			return outer.position.y
		SOUTH:
			return outer.end.y
		WEST:
			return outer.position.x
	return outer.end.x

## A doorway between two rooms that share a wall. `at` is where its middle lies along
## that wall (x for a wall that runs east-west, z otherwise). Kinds: "frame" (always
## open), "join" (no wall at all over that width), "slide" (opens for whoever comes near),
## "gate" (shut while its area is locked), "script" (opened and shut by set_door only).
## Options: kind, height, name (for set_door and door_of), area (of a gate; left out, the
## area of the second room), leaf (how it looks), plus what the builder of a leaf reads.
func _door(a: String, b: String, at: float, width: float = 2.0, options: Dictionary = {}) -> Dictionary:
	var first: Dictionary = room_of[a]
	var second: Dictionary = room_of[b]
	var side := _shared_side(first, second)
	if side < 0:
		push_error("HiveCore._door: '%s' and '%s' share no wall" % [a, b])
		return {}
	var kind := str(options.get("kind", "frame"))
	var height := float(options.get("height", DOOR_TALL))
	if kind == "join":
		height = minf(float(first.height), float(second.height))
	var gap := [at - width * 0.5, at + width * 0.5, 0.0, height, kind]
	(first.open[side] as Array).append(gap)
	(second.open[(side + 2) % 4] as Array).append(gap)
	var door := _door_entry(first, side, at, width, height, kind, options)
	door.b = b
	if kind == "gate" and not options.has("area"):
		door.area = str(second.area)
	(second.doors as Array).append(door)
	_zones_see(str(first.zone), str(second.zone))
	return door

## A doorway from a room to the outside (or to stairs): the same, on one `side` of it.
func _opening(a: String, side: int, at: float, width: float = 2.0, options: Dictionary = {}) -> Dictionary:
	var first: Dictionary = room_of[a]
	var kind := str(options.get("kind", "frame"))
	var height := float(options.get("height", DOOR_TALL))
	(first.open[side] as Array).append([at - width * 0.5, at + width * 0.5, 0.0, height, kind])
	return _door_entry(first, side, at, width, height, kind, options)

func _door_entry(first: Dictionary, side: int, at: float, width: float, height: float, kind: String, options: Dictionary) -> Dictionary:
	var along_x := side == NORTH or side == SOUTH
	var line := _wall_line(first, side)
	var door := {
		"a": str(first.id), "b": "", "side": side, "along_x": along_x, "width": width, "height": height, "kind": kind,
		"pos": Vector3(at, float(first.y), line) if along_x else Vector3(line, float(first.y), at),
		"area": "", "name": "", "zone": str(first.zone), "level": int(first.level), "leaf": "",
		"amount": 0.0, "target": 0.0, "shut": false, "leaves": [], "slides": [], "shape": null, "lamp": null
	}
	door.merge(options, true)
	door.kind = kind
	# Through the wall and a little into both rooms, clear of the jambs.
	var half := maxf(0.26, width * 0.5 - 0.4)
	var reach := HALF + 0.8 + _skin_of(first, side) * 1.2
	door["strip"] = Rect2(at - half, line - reach, half * 2.0, reach * 2.0) if along_x else Rect2(line - reach, at - half, reach * 2.0, half * 2.0)
	doors.append(door)
	(first.doors as Array).append(door)
	if str(door.name) != "":
		door_of[str(door.name)] = door
	return door

## A pane in one side of a room, from `sill` to `head` above the floor. Kinds: "glass"
## (armoured: nothing gets through, nobody sees a target through it), "window" (bodies
## stop, shots pass), "hatch" (an open counter). With `through` (the room on the other
## side) it is cut into that room's wall as well.
func _pane(a: String, side: int, at: float, width: float, sill: float, head: float, kind: String = "glass", through: String = "") -> void:
	var first: Dictionary = room_of[a]
	var gap := [at - width * 0.5, at + width * 0.5, sill, head, kind]
	(first.open[side] as Array).append(gap)
	if through != "":
		((room_of[through] as Dictionary).open[(side + 2) % 4] as Array).append(gap)
	panes.append({"room": first, "side": side, "at": at, "width": width, "sill": sill, "head": head, "kind": kind, "through": through, "zone": str(first.zone)})

## Makes a way between two floors usable for path finding: `route` is its middle line
## from a free cell of the floor `low` to a free cell of the floor `high`, with the height
## of the tread at every point (stairs, landings between them). What is walked on - steps
## and a ramp - is built by the caller (see _steps).
func _link(route: PackedVector3Array, width: float, low: int, high: int, area_id: String = "") -> void:
	var samples := PackedVector3Array()
	var total := 0.0
	for index in range(route.size() - 1):
		var from := route[index]
		var to := route[index + 1]
		var span := Vector2(to.x - from.x, to.z - from.z).length()
		total += from.distance_to(to)
		var count := maxi(1, roundi(span / CELL))
		for k in range(count):
			if index == 0 and k == 0:
				continue
			samples.append(from.lerp(to, float(k) / count))
	var box := Rect2(Vector2(route[0].x, route[0].z), Vector2.ZERO)
	for point in route:
		box = box.expand(Vector2(point.x, point.z))
	var foot := route[0]
	var head := route[route.size() - 1]
	stairs.append({
		"foot": foot, "head": head, "rect": box.grow(width * 0.5 + 0.3), "width": width,
		"bottom": Vector2i(roundi(foot.x / CELL), roundi(foot.z / CELL)), "top": Vector2i(roundi(head.x / CELL), roundi(head.z / CELL)),
		"points": samples, "length": total * 1.15, "low": low, "high": high, "area": area_id, "gate": "both", "pit": false, "zone": zone
	})

# ---------------------------------------------------------------- surfaces and models

## A surface from assets/hive/tex: colour, relief and (where there is one) the map of
## roughness, laid over the world in metres so that it needs no unwrapping. The colour of
## a box tints it.
func _surface(key: String, id: String, metres: float, roughness: float = 1.0, metallic: float = 0.0, relief: float = 1.0) -> StandardMaterial3D:
	var base := "res://assets/hive/tex/" + id
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.albedo_texture = load(base + "_diff.jpg")
	result.normal_enabled = true
	result.normal_texture = load(base + "_nor.jpg")
	result.normal_scale = relief
	if ResourceLoader.exists(base + "_arm.jpg"):
		var packed: Texture2D = load(base + "_arm.jpg")
		result.roughness_texture = packed
		result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		result.ao_enabled = true
		result.ao_texture = packed
		result.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	elif ResourceLoader.exists(base + "_rough.jpg"):
		result.roughness_texture = load(base + "_rough.jpg")
		result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	result.roughness = roughness
	result.metallic = metallic
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_triplanar_sharpness = 6.0
	result.uv1_scale = Vector3.ONE / metres
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats[key] = result
	return result

func _build_surfaces() -> void:
	_surface("plaster", "painted_plaster_wall", 2.4)
	_surface("slate", "roof_slates_03", 2.0)
	_surface("stonewall", "old_stone_wall", 2.2)
	_surface("lawn", "leafy_grass", 3.0)
	_surface("gravel", "gravel_concrete", 2.4)
	_surface("cobble", "cobblestone_floor_04", 2.4)
	_surface("checker", "floor_tiles_06", 2.0, 0.55)
	_surface("marble", "marble_01", 2.2, 0.45)
	_surface("parquet", "herringbone_parquet", 1.6, 0.7)
	_surface("panelwood", "dark_paneled_wood", 2.0, 0.8)
	_surface("wallpaper", "quatrefoil_jacquard_fabric", 1.1)
	_surface("velvet", "velour_velvet", 1.2)
	_surface("beton", "concrete_wall_008", 3.0)
	_surface("formwork", "concrete_slab_wall_02", 3.0)
	_surface("betonfloor", "concrete_floor_worn_001", 3.0, 0.85)
	_surface("darkfloor", "concrete_floor_painted", 3.0, 0.5)
	_surface("tread", "metal_plate", 1.2, 0.75, 0.6)
	_surface("plate", "metal_plate_02", 2.0, 0.7, 0.55)
	_surface("shutter", "painted_metal_shutter", 2.0, 0.8, 0.4)
	_surface("granite", "granite_tile", 2.0, 0.32)
	# The same stone, polished: the lamps of a corridor stand in it.
	_surface("gloss", "granite_tile", 2.0, 0.17)
	_surface("tiles", "interior_tiles", 1.6, 0.6)
	_surface("cladding", "exterior_wall_cladding_03", 2.4, 0.75)
	# Armoured glass: a little more to see of it than of the farm's.
	var pane := StandardMaterial3D.new()
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.albedo_color = Color(0.2, 0.3, 0.32, 0.12)
	pane.roughness = 0.04
	pane.metallic_specular = 0.9
	mats["pane"] = pane
	# Standing water.
	var water := StandardMaterial3D.new()
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color = Color(0.05, 0.1, 0.11, 0.78)
	water.roughness = 0.03
	water.metallic = 0.3
	mats["water"] = water
	# What a flood leaves on a wall: the colour of a box is its colour and how much it covers.
	var stain := StandardMaterial3D.new()
	stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stain.vertex_color_use_as_albedo = true
	stain.vertex_color_is_srgb = true
	stain.roughness = 0.3
	mats["stain"] = stain
	# The skin of deep water seen from below: bright, from either side.
	var skin := StandardMaterial3D.new()
	skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.albedo_color = Color(0.3, 0.8, 0.74, 0.4)
	mats["skin"] = skin
	# Water one wades through (see FLOOD): not see-through, so that the room is mirrored in it.
	var swell := FastNoiseLite.new()
	swell.seed = 77
	swell.frequency = 0.012
	swell.fractal_octaves = 3
	var ripples := NoiseTexture2D.new()
	ripples.width = 256
	ripples.height = 256
	ripples.seamless = true
	ripples.noise = swell
	ripples.as_normal_map = true
	ripples.bump_strength = 5.0
	var flood_shader := Shader.new()
	flood_shader.code = FLOOD
	var flood := ShaderMaterial.new()
	flood.shader = flood_shader
	flood.set_shader_parameter("ripples", ripples)
	mats["flood"] = flood

## The file of a model: one of assets/hive/models by its name, or a path below assets/.
func _model_path(id: String) -> String:
	if id.begins_with("res://"):
		return id
	if id.contains("/"):
		return "res://assets/" + id
	return "res://assets/hive/models/%s/%s.gltf" % [id, id]

static func _model_bounds(node: Node, frame: Transform3D, found: Array) -> void:
	var here := frame
	if node is Node3D:
		here = frame * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box: AABB = here * (node as MeshInstance3D).mesh.get_aabb()
		if found.is_empty():
			found.append(box)
		else:
			found[0] = (found[0] as AABB).merge(box)
	for child in node.get_children():
		_model_bounds(child, here, found)

## Size of a model as it comes out of its file (metres; see _model for the options).
func _model_size(id: String) -> Vector3:
	return (_model_entry(id).bounds as AABB).size

func _model_entry(id: String) -> Dictionary:
	if not model_cache.has(id):
		var scene: PackedScene = load(_model_path(id))
		var bounds := AABB(Vector3.ZERO, Vector3.ONE)
		if scene != null:
			var probe: Node = scene.instantiate()
			var found: Array = []
			_model_bounds(probe, Transform3D.IDENTITY, found)
			if not found.is_empty():
				bounds = found[0]
			probe.free()
		else:
			push_error("HiveCore: no model '%s'" % id)
		model_cache[id] = {"scene": scene, "bounds": bounds}
	return model_cache[id]

## Puts a model into the world: the middle of its footprint on `pos`, turned by `yaw`.
## Options: height / width / scale (its size; left out, as it comes), solid (true: a box
## to bump into that paths go around; "low": only its lower 1.1 m; false: none), tint (a
## colour its surfaces are multiplied with), lift (metres above `pos`), far (the distance
## it is drawn up to), shadows.
func _model(id: String, pos: Vector3, yaw: float = 0.0, options: Dictionary = {}) -> Node3D:
	var entry := _model_entry(id)
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, float(options.get("lift", 0.0)), 0)
	holder.rotation.y = yaw
	add_child(holder)
	if entry.scene == null:
		return holder
	var bounds: AABB = entry.bounds
	var factor := float(options.get("scale", 1.0))
	if options.has("height"):
		factor = float(options.height) / maxf(0.001, bounds.size.y)
	elif options.has("width"):
		factor = float(options.width) / maxf(0.001, maxf(bounds.size.x, bounds.size.z))
	var node: Node3D = (entry.scene as PackedScene).instantiate()
	var centre := bounds.get_center()
	node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), -Vector3(centre.x, bounds.position.y, centre.z) * factor) * node.transform
	holder.add_child(node)
	var cast: bool = bool(options.get("shadows", zones.has(zone) and bool(zones[zone].shadows)))
	var far := float(options.get("far", 70.0))
	var tint: Variant = options.get("tint", null)
	for part in holder.find_children("*", "MeshInstance3D", true, false):
		var piece := part as MeshInstance3D
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.visibility_range_end = far
		piece.visibility_range_end_margin = 6.0
		piece.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if tint is Color:
			for surface in range(piece.mesh.get_surface_count()):
				piece.set_surface_override_material(surface, _tinted(piece.mesh.surface_get_material(surface), tint))
	var solid: Variant = options.get("solid", true)
	if not (solid is bool and solid == false):
		var size := bounds.size * factor
		if solid is String and str(solid) == "low":
			size.y = minf(size.y, 1.1)
		_solid(holder.position + Vector3(0, size.y * 0.5, 0), size, true, yaw)
	return holder

func _tinted(source: Material, tint: Color) -> Material:
	if not source is BaseMaterial3D:
		return source
	var key := "%d %s" % [source.get_instance_id(), tint.to_html()]
	if not tinted.has(key):
		var copy := source.duplicate() as BaseMaterial3D
		copy.albedo_color = (source as BaseMaterial3D).albedo_color * tint
		tinted[key] = copy
	return tinted[key]

# ---------------------------------------------------------------- walls

## A box on one side of a room: from `a` to `b` along the wall, between two heights above
## the floor, and from `d0` to `d1` metres behind the face of the wall (less than 0 stands
## out into the room).
func _face_centre(room: Dictionary, side: int, a: float, b: float, y0: float, y1: float, d0: float, d1: float) -> Vector3:
	var inner: Rect2 = room.inner
	var out: Vector2 = OUT[side]
	var depth := (d0 + d1) * 0.5
	var y := float(room.y) + (y0 + y1) * 0.5
	match side:
		NORTH:
			return Vector3((a + b) * 0.5, y, inner.position.y + out.y * depth)
		SOUTH:
			return Vector3((a + b) * 0.5, y, inner.end.y + out.y * depth)
		WEST:
			return Vector3(inner.position.x + out.x * depth, y, (a + b) * 0.5)
	return Vector3(inner.end.x + out.x * depth, y, (a + b) * 0.5)

func _face_size(side: int, a: float, b: float, y0: float, y1: float, d0: float, d1: float) -> Vector3:
	if side == NORTH or side == SOUTH:
		return Vector3(b - a, y1 - y0, absf(d1 - d0))
	return Vector3(absf(d1 - d0), y1 - y0, b - a)

func _face_box(room: Dictionary, side: int, material: String, a: float, b: float, y0: float, y1: float, d0: float, d1: float, color: Color) -> void:
	if b - a < 0.005 or y1 - y0 < 0.005:
		return
	_part(material, _face_centre(room, side, a, b, y0, y1, d0, d1), _face_size(side, a, b, y0, y1, d0, d1), color)

func _face_glow(room: Dictionary, side: int, a: float, b: float, y0: float, y1: float, d0: float, d1: float, color: Color, strength: float) -> void:
	if b - a < 0.005 or y1 - y0 < 0.005:
		return
	_glow_box(_face_centre(room, side, a, b, y0, y1, d0, d1), _face_size(side, a, b, y0, y1, d0, d1), color, strength)

## A spot on a side of a room: `a` along the wall, `y` above the floor, `d` behind its face.
func _face_point(room: Dictionary, side: int, a: float, y: float, d: float) -> Vector3:
	return _face_centre(room, side, a, a, y, y, d, d)

## Yaw of something that stands with its back to this side of a room (its front, -z,
## looks into the room).
func _face_yaw(side: int) -> float:
	return [PI, PI / 2, 0.0, -PI / 2][side]

## What a room looks like: its style with the room's own changes.
func _look(room: Dictionary) -> Dictionary:
	var look: Dictionary = (styles[room.style] as Dictionary).duplicate()
	look.merge(room.get("look", {}), true)
	return look

func _skin_of(room: Dictionary, side: int) -> float:
	return float(room.get("skin_depth", 0.25)) if (room.skin as Array).has(side) else 0.0

func _build_side(room: Dictionary, side: int, look: Dictionary) -> void:
	var outer: Rect2 = room.outer
	var inner: Rect2 = room.inner
	var tall := float(room.height)
	var along_x := side == NORTH or side == SOUTH
	var a0 := outer.position.x if along_x else inner.position.y
	var a1 := outer.end.x if along_x else inner.end.y
	var clip0 := inner.position.x if along_x else inner.position.y
	var clip1 := inner.end.x if along_x else inner.end.y
	var gaps: Array = room.open[side]
	# Openings may lie above one another or overlap. Between two places where one begins
	# or ends, the wall is cut the same way from the floor to the ceiling.
	var edges: Array[float] = [a0, a1]
	for gap in gaps:
		for value in [float(gap[0]), float(gap[1])]:
			if value > a0 + 0.01 and value < a1 - 0.01:
				edges.append(value)
	edges.sort()
	var runs: Array = []
	for index in range(edges.size() - 1):
		var from := edges[index]
		var to := edges[index + 1]
		if to - from < 0.01:
			continue
		var mid := (from + to) * 0.5
		var cuts: Array = []
		for gap in gaps:
			if mid > float(gap[0]) and mid < float(gap[1]):
				cuts.append([float(gap[2]), float(gap[3])])
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		if not runs.is_empty() and runs[runs.size() - 1][2] == cuts and absf(float(runs[runs.size() - 1][1]) - from) < 0.01:
			runs[runs.size() - 1][1] = to
		else:
			runs.append([from, to, cuts])
	for run in runs:
		var height := 0.0
		for cut in run[2]:
			if float(cut[0]) - height > 0.05:
				_wall_piece(room, side, look, float(run[0]), float(run[1]), height, float(cut[0]), clip0, clip1)
			height = maxf(height, float(cut[1]))
		if tall - height > 0.05:
			_wall_piece(room, side, look, float(run[0]), float(run[1]), height, tall, clip0, clip1)
	# An outside wall goes on above the room, up to the eaves.
	var skin := _skin_of(room, side)
	if skin > 0.0 and float(room.get("skin_top", tall)) > tall + 0.01:
		var ends := _skin_ends(room, side, a0, a1)
		_face_box(room, side, str(room.get("skin_mat", "plaster")), ends[0], ends[1], tall, float(room.skin_top), 0.0, HALF + skin, room.get("skin_tint", Color.WHITE))
		_part_shape(_face_centre(room, side, ends[0], ends[1], tall, float(room.skin_top), 0.0, HALF + skin), _face_size(side, ends[0], ends[1], tall, float(room.skin_top), 0.0, HALF + skin))

## Where the outside skin of a side begins and ends: around the corner where the next
## side is an outside wall too.
func _skin_ends(room: Dictionary, side: int, a0: float, a1: float) -> Array:
	var depth := float(room.get("skin_depth", 0.25))
	var skins: Array = room.skin
	if side == NORTH or side == SOUTH:
		return [a0 - (depth if skins.has(WEST) else 0.0), a1 + (depth if skins.has(EAST) else 0.0)]
	return [a0 - HALF, a1 + HALF]

func _part_shape(centre: Vector3, size: Vector3) -> void:
	_add_shape(body, centre, size)

func _wall_piece(room: Dictionary, side: int, look: Dictionary, a: float, b: float, y0: float, y1: float, clip0: float, clip1: float) -> void:
	var skin := _skin_of(room, side)
	var core: Array = look.core
	_face_box(room, side, str(core[0]), a, b, y0, y1, 0.0, HALF, core[1])
	_part_shape(_face_centre(room, side, a, b, y0, y1, 0.0, HALF + skin), _face_size(side, a, b, y0, y1, 0.0, HALF + skin))
	if skin > 0.0:
		var from := a
		var to := b
		var whole := _skin_ends(room, side, a, b)
		var along_x := side == NORTH or side == SOUTH
		var edge0 := float(room.outer.position.x) if along_x else float(room.inner.position.y)
		var edge1 := float(room.outer.end.x) if along_x else float(room.inner.end.y)
		if absf(a - edge0) < 0.01:
			from = whole[0]
		if absf(b - edge1) < 0.01:
			to = whole[1]
		# Not where something is built on to the wall (`skin_skip`: [from, to] along it).
		var cursor := from
		for skip in room.get("skin_skip", []):
			if float(skip[0]) > cursor:
				_face_box(room, side, str(room.get("skin_mat", "plaster")), cursor, minf(to, float(skip[0])), y0, y1, HALF, HALF + skin, room.get("skin_tint", Color.WHITE))
			cursor = maxf(cursor, float(skip[1]))
		_face_box(room, side, str(room.get("skin_mat", "plaster")), cursor, to, y0, y1, HALF, HALF + skin, room.get("skin_tint", Color.WHITE))
	var c0 := maxf(a, clip0)
	var c1 := minf(b, clip1)
	if c1 - c0 > 0.05:
		_dress(room, side, look, c0, c1, y0, y1)

## The finish of a piece of wall, by the style of the room.
func _dress(room: Dictionary, side: int, look: Dictionary, a: float, b: float, y0: float, y1: float) -> void:
	var tall := float(room.height)
	var low := y0 < 0.05
	var high := y1 > tall - 0.05
	match str(look.get("dress", "")):
		"panel":
			# Dark steel at the foot, a dark lower row, a band in the colour of the sector, light
			# panels above it and a seam of light over those.
			var light: Color = look.get("panel", Color(0.8, 0.83, 0.85))
			var dark: Color = look.get("wainscot", Color(0.36, 0.39, 0.43))
			if low:
				_face_box(room, side, "plate", a, b, 0.0, minf(0.2, y1), -0.045, 0.0, Color("15181a"))
			var count := maxi(1, roundi((b - a) / 1.5))
			var wide := (b - a) / count
			var bands: Array = [[0.26, 0.98, dark]]
			var row := 1.14
			while row + 0.7 < tall:
				var top := minf(row + (1.56 if row < 1.2 else 2.44), tall - 0.3)
				bands.append([row, top, light if row < 1.2 else light.darkened(0.06)])
				row = top + 0.08
			for band in bands:
				var p0 := maxf(float(band[0]), y0 + (0.0 if low else 0.05))
				var p1 := minf(float(band[1]), y1 - (0.0 if high else 0.05))
				if p1 - p0 > 0.2:
					for i in range(count):
						_face_box(room, side, "cladding", a + i * wide + 0.03, a + (i + 1) * wide - 0.03, p0, p1, -0.035, 0.0, _vary(band[2], 0.012))
			# Louvres in every third panel of the lower row: where the air of the facility comes from.
			if low and y1 > 1.03 and wide > 0.9:
				for i in range(1, count, 3):
					for k in range(4):
						_face_box(room, side, "plain", a + i * wide + 0.16, a + (i + 1) * wide - 0.16, 0.36 + k * 0.15, 0.42 + k * 0.15, -0.05, -0.035, Color("0c0e0f"))
			if low and y1 > 1.12:
				_face_box(room, side, "plain", a, b, 1.02, 1.1, -0.026, 0.0, look.get("stripe", Color("2b3034")))
			if low and y1 > 2.8 and tall > 3.1 and bool(look.get("strip", true)):
				_face_glow(room, side, a, b, 2.72, 2.76, -0.014, 0.0, look.get("strip_color", Color("bfe0ff")), float(look.get("strip_glow", 2.0)))
			_tide(room, side, look, a, b, y0, y1)
		"wood":
			var wood: Color = look.get("wood", Color(0.62, 0.56, 0.5))
			var dark := wood.darkened(0.3)
			if low:
				_face_box(room, side, "panelwood", a, b, 0.0, minf(1.25, y1), -0.03, 0.0, wood)
				_face_box(room, side, "panelwood", a, b, 0.0, minf(0.16, y1), -0.05, 0.0, dark)
				if y1 > 1.33:
					_face_box(room, side, "panelwood", a, b, 1.25, 1.33, -0.055, 0.0, dark)
			if high:
				_face_box(room, side, "plaster", a, b, maxf(y0, tall - 0.2), tall, -0.1, 0.0, Color(0.86, 0.82, 0.74))
				if y0 < tall - 0.95:
					_face_box(room, side, "panelwood", a, b, tall - 0.95, tall - 0.89, -0.03, 0.0, dark)
		"hall":
			var stone: Color = look.get("stone", Color(0.86, 0.84, 0.8))
			if low:
				_face_box(room, side, "marble", a, b, 0.0, minf(0.4, y1), -0.035, 0.0, stone)
				if y1 > 1.2:
					_face_box(room, side, "marble", a, b, 1.1, 1.17, -0.03, 0.0, stone.darkened(0.12))
			if high:
				_face_box(room, side, "plaster", a, b, maxf(y0, tall - 0.3), tall, -0.14, 0.0, Color(0.9, 0.88, 0.82))
				_face_box(room, side, "plaster", a, b, maxf(y0, tall - 0.42), tall - 0.3, -0.07, 0.0, Color(0.84, 0.82, 0.76))
		"tiles":
			var tile: Color = look.get("tile", Color(0.86, 0.88, 0.86))
			if low:
				_face_box(room, side, "tiles", a, b, 0.0, minf(2.2, y1), -0.014, 0.0, tile)
				if y1 > 2.26:
					_face_box(room, side, "plain", a, b, 2.2, 2.26, -0.02, 0.0, look.get("trim", Color("3d5a5c")))
		"tech":
			if low:
				_face_box(room, side, "plain", a, b, 0.0, minf(0.14, y1), -0.02, 0.0, Color("3a3214"))
			if low and high and b - a > 1.2:
				var runs := [[0.5, 0.07, Color("6d6f6c")], [0.74, 0.05, Color("8a5a2c")], [0.94, 0.04, Color("4d5357")]]
				for run in runs:
					_pipe(_face_point(room, side, a, tall - float(run[0]), -0.16), _face_point(room, side, b, tall - float(run[0]), -0.16), float(run[1]), run[2], 8)
				_face_box(room, side, "plate", a, b, tall - 1.34, tall - 1.26, -0.3, 0.0, Color("2b2f31"))
			_tide(room, side, look, a, b, y0, y1)
		"concrete":
			if look.has("stripe") and low and y1 > 1.2:
				_face_box(room, side, "plain", a, b, 1.0, 1.1, -0.006, 0.0, look.stripe)

## The mark a flood has left on a piece of wall: a look with "tide" (how high the water
## stood) has it, on the sides "tide_sides" (left out: all) and between the two places
## "tide_span" along the wall (left out: everywhere).
func _tide(room: Dictionary, side: int, look: Dictionary, a: float, b: float, y0: float, y1: float) -> void:
	if not look.has("tide") or y0 > 0.05 or not (look.get("tide_sides", [NORTH, EAST, SOUTH, WEST]) as Array).has(side):
		return
	var mark := minf(float(look.tide), y1)
	var span: Array = look.get("tide_span", [-INF, INF])
	var from := maxf(a, float(span[0]))
	var to := minf(b, float(span[1]))
	if to - from < 0.1 or mark < 0.4:
		return
	_face_box(room, side, "stain", from, to, 0.21, mark, -0.054, -0.052, Color(0.09, 0.15, 0.11, 0.46))
	if y1 > float(look.tide) + 0.05:
		_face_box(room, side, "plain", from, to, mark, mark + 0.03, -0.06, -0.047, Color(0.12, 0.16, 0.11))

# ---------------------------------------------------------------- rooms

## Rectangles of at most `most` metres a side that cover `rect`.
func _split(rect: Rect2, most: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var nx := maxi(1, ceili(rect.size.x / most))
	var nz := maxi(1, ceili(rect.size.y / most))
	for ix in range(nx):
		for iz in range(nz):
			out.append(Rect2(rect.position.x + rect.size.x * ix / nx, rect.position.y + rect.size.y * iz / nz, rect.size.x / nx, rect.size.y / nz))
	return out

func _build_room(room: Dictionary) -> void:
	if bool(room.outdoor):
		return
	var look := _look(room)
	var outer: Rect2 = room.outer
	var y := float(room.y)
	var tall := float(room.height)
	var middle := outer.get_center()
	_chunk("Shell")
	if room.get("floor", true):
		var ground: Array = look.floor
		_part(str(ground[0]), Vector3(middle.x, y - 0.15, middle.y), Vector3(outer.size.x, 0.3, outer.size.y), ground[1])
		for tile in _split(outer, 15.0):
			_solid(Vector3(tile.get_center().x, y - 0.25, tile.get_center().y), Vector3(tile.size.x, 0.5, tile.size.y), false)
	if room.get("ceiling", true):
		var cover: Array = look.ceiling
		_part(str(cover[0]), Vector3(middle.x, y + tall + 0.15, middle.y), Vector3(outer.size.x, 0.3, outer.size.y), cover[1])
		_part_shape(Vector3(middle.x, y + tall + 0.15, middle.y), Vector3(outer.size.x, 0.3, outer.size.y))
	if room.get("walls", true):
		for side in range(4):
			if not (room.bare as Array).has(side):
				_build_side(room, side, look)
	# (`glow`: the glass of its lamps is a material of its own, which can be dimmed alone.)
	var kept := glow_key
	if room.has("glow"):
		_own_glow(str(room.glow))
		glow_key = str(room.glow)
	_light_room(room, look)
	glow_key = kept

## The lamps of a room: a grid under its ceiling, as wide-meshed as its style says.
func _light_room(room: Dictionary, look: Dictionary) -> void:
	var kind := str(room.get("lamps", look.get("lamp", "tube")))
	if kind == "none":
		return
	var inner: Rect2 = room.inner
	var gap := float(look.get("lamp_gap", 6.0))
	var nx := maxi(1, roundi(inner.size.x / gap))
	var nz := maxi(1, roundi(inner.size.y / gap))
	# `lamp_every`: only every so many of them is a lamp that lights, the others only glow
	# (a light costs time, a glowing tube none); `dead`: the share that is dark.
	var every := maxi(1, int(look.get("lamp_every", 1)))
	# (A room with a handful of lamps needs every one of them.)
	if nx * nz <= 4:
		every = 1
	var dead := float(look.get("dead", 0.0))
	var before := flickers.size()
	for ix in range(nx):
		for iz in range(nz):
			var at := Vector3(inner.position.x + (ix + 0.5) * inner.size.x / nx, float(room.y) + float(room.height), inner.position.y + (iz + 0.5) * inner.size.y / nz)
			var how := "lit" if (ix + iz) % every == 0 else "glow"
			if dead > 0.0 and random.randf() < dead:
				how = "dead"
			_lamp(kind, at, look, inner.size.x >= inner.size.y, float(room.height), how)
	room["lights"] = [before, flickers.size()]

## A lamp of a kind under a ceiling at `at`. Returns its light.
## (`how`: "lit", or "glow" for one that only glows, or "dead" for a dark one - a tube or
## a caged lamp; the others always light.)
func _lamp(kind: String, at: Vector3, look: Dictionary, along_x: bool, tall: float, how: String = "lit") -> Light3D:
	var color: Color = look.get("light", Color("d6e8ff"))
	var energy := float(look.get("energy", 1.5))
	var reach := float(look.get("reach", maxf(7.0, float(look.get("lamp_gap", 6.0)) * 1.3)))
	var flicker := float(look.get("flicker", 0.0))
	var lamp: Light3D
	match kind:
		"tube":
			# Two tubes in a housing.
			var size := Vector3(1.5, 0.07, 0.5) if along_x else Vector3(0.5, 0.07, 1.5)
			var tube := Vector3(1.36, 0.03, 0.1) if along_x else Vector3(0.1, 0.03, 1.36)
			var apart := Vector3(0, 0, 0.12) if along_x else Vector3(0.12, 0, 0)
			_part("plate", at - Vector3(0, 0.035, 0), size, Color("1d2022"))
			for edge in [-1.0, 1.0]:
				if how == "dead":
					_part("plain", at - Vector3(0, 0.085, 0) + apart * edge, tube, Color("3a3e40"))
				else:
					_glow_box(at - Vector3(0, 0.085, 0) + apart * edge, tube, color, 5.5)
			if how == "lit":
				lamp = _light(at - Vector3(0, minf(0.9, tall * 0.2), 0), color, energy, reach, false, flicker, 0.35, LAMP_FADE)
				(lamp as OmniLight3D).omni_attenuation = 0.9
		"cage":
			_part("plate", at - Vector3(0, 0.04, 0), Vector3(0.26, 0.08, 0.26), Color("1b1c1b"))
			if how == "dead":
				batch.ellipsoid(mats["plain"], at - Vector3(0, 0.14, 0), Vector3.ONE * 0.08, Color("3a3e40"), Basis.IDENTITY, 8, 5)
			else:
				_glow_ball(at - Vector3(0, 0.14, 0), 0.08, color, 5.0)
			if how == "lit":
				lamp = _light(at - Vector3(0, 0.6, 0), color, energy, reach, false, flicker, 0.5, LAMP_FADE)
		"hang":
			var drop := maxf(1.0, tall - float(look.get("lamp_height", 5.2)))
			_part("plain", at - Vector3(0, drop * 0.5, 0), Vector3(0.03, drop, 0.03), Color("101010"))
			batch.cylinder(mats["plate"], at - Vector3(0, drop + 0.2, 0), 0.34, 0.1, 0.22, Color("202326"), 12)
			_glow_box(at - Vector3(0, drop + 0.21, 0), Vector3(0.36, 0.02, 0.36), color, 6.0)
			_light(at - Vector3(0, drop + 0.6, 0), color, energy * 1.5, reach, false, flicker, 0.2, LAMP_FADE + 12.0)
			lamp = _spot(at - Vector3(0, drop + 0.25, 0), Vector3.DOWN, color, energy * 7.0, tall - drop + 4.0, 66.0, flicker, 1.6, LAMP_FADE + 12.0)
			(lamp as SpotLight3D).spot_attenuation = 0.7
		"chandelier":
			var hang := float(look.get("lamp_drop", 0.5))
			_part("plain", at - Vector3(0, hang * 0.5, 0), Vector3(0.03, hang, 0.03), Color("2a2118"))
			_model(str(look.get("lamp_model", "Chandelier_01")), at - Vector3(0, hang + float(look.get("lamp_size", 1.1)), 0), 0.0, {"height": float(look.get("lamp_size", 1.1)), "solid": false, "shadows": false})
			lamp = _light(at - Vector3(0, hang + float(look.get("lamp_size", 1.1)) * 0.6, 0), color, energy, reach, bool(look.get("lamp_shadows", false)), flicker, 0.5, LAMP_FADE + 10.0)
		_:
			lamp = _light(at - Vector3(0, 0.5, 0), color, energy, reach, false, flicker, 0.4, LAMP_FADE)
	return lamp

# ---------------------------------------------------------------- doors and panes

## The leaf of a door, as a node of its own that can be slid aside: boxes given in the
## frame of the doorway (x along the wall, y up, z through it), around its middle on the
## floor.
func _leaf(door: Dictionary, boxes: Array, slide: Vector3) -> Node3D:
	var turn := Basis.IDENTITY if bool(door.along_x) else Basis(Vector3.UP, PI / 2)
	var node := Node3D.new()
	node.name = "Leaf"
	node.transform = Transform3D(turn, door.pos)
	add_child(node)
	var pieces := MeshBatch.new()
	for entry in boxes:
		pieces.box(mats[str(entry[0])], entry[1], entry[2], entry[3])
	pieces.commit(node, "Leaf", false)
	(door.leaves as Array).append(node)
	(door.slides as Array).append(turn * slide)
	(door["homes"] as Array).append(door.pos)
	return node

func _build_door(door: Dictionary) -> void:
	var kind := str(door.kind)
	if kind == "join":
		return
	var room: Dictionary = room_of[door.a]
	var look := _look(room)
	var family := str(look.get("family", "tech"))
	var wide := float(door.width)
	var tall := float(door.height)
	var turn := Basis.IDENTITY if bool(door.along_x) else Basis(Vector3.UP, PI / 2)
	var frame := Transform3D(turn, door.pos)
	door["homes"] = []
	_chunk("Doors")
	var deep := WALL + 0.14
	if family == "villa":
		var wood := Color(0.34, 0.27, 0.21)
		for edge in [-1.0, 1.0]:
		# (Jambs and lintel reach two centimetres into the opening: flush with the cut faces of
		# the wall they would lie in one plane with them, and that flickers.)
			_placed(frame, "panelwood", Vector3(edge * (wide * 0.5 + 0.06), tall * 0.5, 0), Vector3(0.16, tall, deep), wood)
		_placed(frame, "panelwood", Vector3(0, tall + 0.08, 0), Vector3(wide + 0.36, 0.2, deep + 0.04), wood)
		_placed(frame, "panelwood", Vector3(0, 0.012, 0), Vector3(wide, 0.024, WALL), wood.darkened(0.35))
	else:
		var steel := Color("1c2023") if family == "tech" else Color("2c3033")
		for edge in [-1.0, 1.0]:
			_placed(frame, "plate", Vector3(edge * (wide * 0.5 + 0.07), tall * 0.5, 0), Vector3(0.18, tall, deep), steel)
		_placed(frame, "plate", Vector3(0, tall + 0.09, 0), Vector3(wide + 0.32, 0.22, deep), steel)
		_placed(frame, "tread", Vector3(0, 0.012, 0), Vector3(wide, 0.024, WALL + 0.3), Color("3a3d3f"))
		if kind in ["gate", "script"] or wide >= 3.0:
			# Warning stripes on both faces of the lintel.
			var blocks := maxi(4, roundi(wide / 0.3))
			for face in [-1.0, 1.0]:
				for i in range(blocks):
					_placed(frame, "plain", Vector3(-wide * 0.5 + (i + 0.5) * wide / blocks, tall + 0.1, face * (deep * 0.5 + 0.004)), Vector3(wide / blocks, 0.14, 0.008), Color("c9a227") if i % 2 == 0 else Color("141414"))
	if kind == "frame":
		if family == "villa" and wide < 3.2 and bool(door.get("wings", true)):
			# Its two wings stand open, folded back against the wall of the second room.
			var out: Vector2 = OUT[int(door.side)]
			var sign_z := -1.0 if (out.x + out.y) < 0.0 else 1.0
			for edge in [-1.0, 1.0]:
				var hinge := Vector3(edge * wide * 0.5, tall * 0.5, sign_z * (HALF + 0.03))
				_placed(frame, "panelwood", hinge + Vector3(edge * 0.03, 0, sign_z * wide * 0.25), Vector3(0.05, tall - 0.04, wide * 0.5 - 0.02), Color(0.4, 0.31, 0.24))
		return
	# --- a leaf that moves, and what keeps bodies and shots out while it is shut
	var leaf_look := str(door.get("leaf", ""))
	if leaf_look == "":
		leaf_look = "shutter" if wide >= 3.4 else "double"
	var plate := Color(0.5, 0.53, 0.55) if kind == "slide" else Color(0.3, 0.33, 0.35)
	match leaf_look:
		"double":
			for edge in [-1.0, 1.0]:
				var boxes := [
					["cladding" if kind == "slide" else "plate", Vector3(edge * wide * 0.25, tall * 0.5, 0), Vector3(wide * 0.5 - 0.01, tall, 0.09), plate],
					["plain", Vector3(edge * (wide * 0.25 + 0.02), tall * 0.62, 0), Vector3(wide * 0.2, 0.42, 0.1), Color("0d1114")],
					["plain", Vector3(edge * 0.03, tall * 0.5, 0), Vector3(0.03, tall, 0.11), Color("111315")]
				]
				if kind != "slide":
					boxes.append(["plain", Vector3(edge * wide * 0.25, 0.22, 0), Vector3(wide * 0.5 - 0.02, 0.18, 0.1), Color("c9a227")])
				_leaf(door, boxes, Vector3(edge * (wide * 0.5 - 0.04), 0, 0))
		"shutter":
			var slats: Array = []
			var rows := maxi(6, roundi(tall / 0.28))
			for i in range(rows):
				slats.append(["shutter", Vector3(0, (i + 0.5) * tall / rows, 0), Vector3(wide, tall / rows - 0.012, 0.1), Color(0.55, 0.57, 0.56) if i % 2 == 0 else Color(0.47, 0.49, 0.48)])
			slats.append(["plain", Vector3(0, 0.12, 0), Vector3(wide, 0.24, 0.12), Color("c9a227")])
			_leaf(door, slats, Vector3(0, tall - 0.1, 0))
		"panel":
			# A piece of panelled wall that slides aside in front of the wall (the mirror).
			var out: Vector2 = OUT[int(door.side)]
			var front := 1.0 if (out.x + out.y) < 0.0 else -1.0
			_leaf(door, [["panelwood", Vector3(0, tall * 0.5, front * (HALF + 0.06)), Vector3(wide + 0.3, tall + 0.2, 0.1), Color(0.5, 0.42, 0.36)]], Vector3(wide + 0.36, 0, 0))
	var shape := BoxShape3D.new()
	shape.size = Vector3(wide, tall, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(turn, (door.pos as Vector3) + Vector3(0, tall * 0.5, 0))
	body.add_child(collision)
	door.shape = collision
	# A small lamp over the doorway says whether it is open to pass.
	if family != "villa":
		for face in [-1.0, 1.0]:
			var lamp := MeshInstance3D.new()
			var bulb := BoxMesh.new()
			bulb.size = Vector3(0.22, 0.05, 0.02)
			lamp.mesh = bulb
			lamp.material_override = _glow_material(Color("5ee07a"), 3.0)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lamp.transform = Transform3D(turn, frame * Vector3(0, tall + 0.26, face * (deep * 0.5 + 0.012)))
			add_child(lamp)
			if door.lamp == null:
				door.lamp = []
			(door.lamp as Array).append(lamp)

func _build_pane(pane: Dictionary) -> void:
	var room: Dictionary = pane.room
	var side: int = pane.side
	var look := _look(room)
	var family := str(look.get("family", "tech"))
	var a := float(pane.at) - float(pane.width) * 0.5
	var b := float(pane.at) + float(pane.width) * 0.5
	var sill := float(pane.sill)
	var head := float(pane.head)
	var skin := _skin_of(room, side)
	var depth := (WALL if str(pane.through) != "" else HALF) + skin
	var kind := str(pane.kind)
	_chunk("Doors")
	var trim := Color(0.34, 0.27, 0.21) if family == "villa" else Color("1c2023")
	var trim_mat := "panelwood" if family == "villa" else "plate"
	# The reveal: a frame as deep as the wall.
	# (It reaches a good centimetre into the opening, see the door frames.)
	_face_box(room, side, trim_mat, a, b, sill - 0.05, sill + 0.014, -0.044, depth + 0.044, trim)
	_face_box(room, side, trim_mat, a, b, head - 0.014, head + 0.05, -0.044, depth + 0.044, trim)
	_face_box(room, side, trim_mat, a - 0.05, a + 0.014, sill - 0.05, head + 0.05, -0.044, depth + 0.044, trim)
	_face_box(room, side, trim_mat, b - 0.014, b + 0.05, sill - 0.05, head + 0.05, -0.044, depth + 0.044, trim)
	var middle := depth * 0.5
	match kind:
		"glass":
			_chunk("Glass", false)
			batch.box(mats["pane"], _face_centre(room, side, a, b, sill, head, middle - 0.02, middle + 0.02), _face_size(side, a, b, sill, head, middle - 0.02, middle + 0.02), Color.WHITE)
			_part_shape(_face_centre(room, side, a, b, sill, head, middle - 0.05, middle + 0.05), _face_size(side, a, b, sill, head, middle - 0.05, middle + 0.05))
			# Posts every metre and a half or so.
			_chunk("Doors")
			var posts := maxi(0, roundi((b - a) / 1.8) - 1)
			for i in range(posts):
				var at := a + (i + 1) * (b - a) / (posts + 1)
				_face_box(room, side, "plate", at - 0.025, at + 0.025, sill, head, middle - 0.04, middle + 0.04, trim)
		"window":
			# A cross of glazing bars; the glass itself stops nobody's shot.
			_face_box(room, side, trim_mat, (a + b) * 0.5 - 0.025, (a + b) * 0.5 + 0.025, sill, head, middle - 0.03, middle + 0.03, trim)
			var bars := maxi(1, roundi((head - sill) / 0.9))
			for i in range(1, bars):
				_face_box(room, side, trim_mat, a, b, sill + i * (head - sill) / bars - 0.02, sill + i * (head - sill) / bars + 0.02, middle - 0.03, middle + 0.03, trim)
			if not bool(pane.get("broken", false)):
				_chunk("Glass", false)
				batch.box(mats["pane"], _face_centre(room, side, a, b, sill, head, middle - 0.008, middle + 0.008), _face_size(side, a, b, sill, head, middle - 0.008, middle + 0.008), Color.WHITE)
			_add_shape(rails, _face_centre(room, side, a, b, sill, head, middle - 0.05, middle + 0.05), _face_size(side, a, b, sill, head, middle - 0.05, middle + 0.05))
		"hatch":
			_face_box(room, side, "plate", a, b, sill - 0.09, sill - 0.05, -0.25, depth + 0.25, Color("585d60"))
			_add_shape(rails, _face_centre(room, side, a, b, sill, head, middle - 0.05, middle + 0.05), _face_size(side, a, b, sill, head, middle - 0.05, middle + 0.05))

# ---------------------------------------------------------------- stairs

## Steps from `foot` up to `head` (the line through their edges) with a ramp to walk on.
## With `down_to` the mass under them reaches to that height: a closed flank.
func _steps(foot: Vector3, head: Vector3, width: float, material: String, tint: Color, down_to: float = INF) -> void:
	var run := Vector3(head.x - foot.x, 0, head.z - foot.z)
	var forward := run.normalized()
	var side := forward.cross(Vector3.UP)
	var count := maxi(2, roundi((head.y - foot.y) / 0.175))
	var tread := run.length() / count
	var riser := (head.y - foot.y) / count
	var turn := Basis(side, Vector3.UP, -forward)
	# (As on the farm: the line from foot to head runs through the edges of the steps, and
	# the last step is the upper floor itself.)
	for k in range(1, count):
		var top := foot.y + k * riser
		var bottom := top - 0.6 if down_to == INF else down_to
		var centre := foot + forward * ((k + 0.5) * tread)
		batch.box(mats[material], Vector3(centre.x, (top + bottom) * 0.5, centre.z), Vector3(width, top - bottom, tread), _vary(tint, 0.012), turn)
		var edge := foot + forward * (k * tread + 0.03)
		batch.box(mats["plain"], Vector3(edge.x, top + 0.002, edge.z), Vector3(width - 0.02, 0.006, 0.06), Color("1d1e1d"), turn)
	var slope := _slope_basis(foot, head)
	_add_shape(body, (foot + head) * 0.5 - slope.y * 0.15, Vector3(width, 0.3, foot.distance_to(head)), slope)

## A steel handrail along a flight, `offset` metres beside its middle line.
func _handrail(foot: Vector3, head: Vector3, offset: float, tint: Color = Color("2a2d2f")) -> void:
	var slope := _slope_basis(foot, head)
	var shift := -slope.x * offset
	var length := foot.distance_to(head)
	var mid := (foot + head) * 0.5 + shift
	batch.box(mats["plate"], mid + Vector3.UP * 1.0, Vector3(0.05, 0.05, length + 0.2), tint, slope)
	batch.box(mats["plate"], mid + Vector3.UP * 0.55, Vector3(0.035, 0.035, length), tint, slope)
	var posts := maxi(2, roundi(length / 1.4))
	for k in range(posts + 1):
		var at := foot.lerp(head, float(k) / posts) + shift
		_part("plate", at + Vector3(0, 0.5, 0), Vector3(0.045, 1.0, 0.045), tint)
	var forward := Vector3(slope.z.x, 0, slope.z.z).normalized()
	var pieces := maxi(1, roundi(Vector2(head.x - foot.x, head.z - foot.z).length() / 0.6))
	for i in range(pieces):
		var low := foot.lerp(head, float(i) / pieces) + shift
		var high := foot.lerp(head, float(i + 1) / pieces) + shift
		var bottom := minf(low.y, high.y) - 0.25
		var top := maxf(low.y, high.y) + 1.05
		_add_shape(rails, Vector3((low.x + high.x) * 0.5, (bottom + top) * 0.5, (low.z + high.z) * 0.5), Vector3(0.08, top - bottom, Vector2(high.x - low.x, high.z - low.z).length()), Basis(slope.x, Vector3.UP, forward))

## A level steel railing between two points on a floor; bodies stop, shots pass.
func _guard_rail(from: Vector3, to: Vector3, tint: Color = Color("2a2d2f"), height: float = 1.05) -> void:
	var span := to - from
	var length := span.length()
	var yaw := atan2(-span.z, span.x)
	var turn := Basis(Vector3.UP, yaw)
	var mid := (from + to) * 0.5
	batch.box(mats["plate"], mid + Vector3(0, height, 0), Vector3(length, 0.05, 0.05), tint, turn)
	batch.box(mats["plate"], mid + Vector3(0, height * 0.52, 0), Vector3(length, 0.035, 0.035), tint, turn)
	batch.box(mats["plate"], mid + Vector3(0, 0.08, 0), Vector3(length, 0.1, 0.02), tint, turn)
	var posts := maxi(1, roundi(length / 1.6))
	for i in range(posts + 1):
		batch.box(mats["plate"], from.lerp(to, float(i) / posts) + Vector3(0, height * 0.5, 0), Vector3(0.05, height, 0.05), tint, turn)
	_rail_solid(mid + Vector3(0, height * 0.5, 0), Vector3(length, height, 0.1), true, yaw)

# ---------------------------------------------------------------- building

func _begin_build() -> void:
	random.seed = 60931
	flicker_noise.frequency = 0.9
	obstacles.clear()
	navigation.clear()
	spawn_points.clear()
	body = StaticBody3D.new()
	body.name = "World"
	add_child(body)
	rails = StaticBody3D.new()
	rails.name = "Railings"
	rails.collision_layer = RAIL_LAYER
	rails.collision_mask = 0
	add_child(rails)
	_build_materials()
	_build_surfaces()

func _cells(level: int, rect: Rect2) -> Rect2i:
	var region: Rect2i = navigation[level].region
	var first := Vector2i(maxi(ceili(rect.position.x / CELL - 0.001), region.position.x), maxi(ceili(rect.position.y / CELL - 0.001), region.position.y))
	var last := Vector2i(mini(floori(rect.end.x / CELL + 0.001), region.end.x - 1), mini(floori(rect.end.y / CELL + 0.001), region.end.y - 1))
	if last.x < first.x or last.y < first.y:
		return Rect2i()
	return Rect2i(first, last - first + Vector2i.ONE)

## Closes or opens every cell of a level whose middle lies in `rect`, in the grid and in
## the picture of it.
func _paint(level: int, rect: Rect2, solid: bool) -> void:
	var cells := _cells(level, rect)
	if cells.size.x <= 0:
		return
	navigation[level].fill_solid_region(cells, solid)
	plan_pictures[level].fill_rect(Rect2i(cells.position - (navigation[level].region as Rect2i).position, cells.size), Color(1.0 if solid else 0.0, 0, 0))

func _room_walk(room: Dictionary) -> Array:
	if room.has("walk"):
		return room.walk
	return [(room.inner as Rect2).grow(-NAV_MARGIN + 0.01)]

## Builds everything that was declared and lays out the navigation.
func _compile() -> void:
	for index in range(floors.size()):
		var region: Rect2i = floors[index].region
		var grid := _grid(region)
		grid.fill_solid_region(region, true)
		navigation.append(grid)
		var picture := Image.create(region.size.x, region.size.y, false, Image.FORMAT_R8)
		picture.fill(Color(1, 0, 0))
		plan_pictures.append(picture)
	# Open ground first; then every room with walls closes the ground it stands on, with a
	# margin around its outside; then the rooms open what can be walked on inside them.
	for step in range(3):
		for room in rooms:
			if room.get("nav", true) == false and step != 1:
				continue
			if step == 0 and bool(room.outdoor):
				for rect in _room_walk(room):
					_paint(int(room.level), rect, false)
			elif step == 1 and not bool(room.outdoor) and room.get("walls", true):
				_paint(int(room.level), (room.outer as Rect2).grow(0.7), true)
			elif step == 2 and not bool(room.outdoor):
				for rect in _room_walk(room):
					_paint(int(room.level), rect, false)
	for room in rooms:
		zone = str(room.zone)
		_begin_zone(zone)
		_build_room(room)
		_end_zone()
	for door in doors:
		_begin_zone(str(door.zone))
		_build_door(door)
		_end_zone()
		if bool(door.get("nav", true)):
			_paint(int(door.level), door.strip, false)
	for pane in panes:
		_begin_zone(str(pane.zone))
		_build_pane(pane)
		_end_zone()
	for index in range(floors.size()):
		for rect in obstacles[index]:
			_paint(index, rect, true)
	hubs.resize(floors.size())
	for index in range(floors.size()):
		hubs[index] = (floors[index].region as Rect2i).position
	for room in rooms:
		_close_pockets(room)
	for id in areas:
		locked[id] = false
		area_open[id] = true
	_apply_locks(true)
	# A scripted door is shut until somebody opens it.
	for door in doors:
		if str(door.kind) == "script":
			_shut_door(door, not bool(door.get("starts_open", false)), true)

## The free cell of a level nearest to a spot, looking no further than a few cells.
func _free_near(level: int, spot: Vector2, reach: int = 4) -> Vector2i:
	var grid := navigation[level]
	var cell := Vector2i(roundi(spot.x / CELL), roundi(spot.y / CELL))
	var best := Vector2i(999999, 999999)
	var best_gap := INF
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var other := cell + Vector2i(dx, dz)
			if grid.is_in_boundsv(other) and not grid.is_point_solid(other):
				var gap := Vector2(other.x * CELL - spot.x, other.y * CELL - spot.y).length_squared()
				if gap < best_gap:
					best_gap = gap
					best = other
	return best

## Closes the free cells of a room that cannot be walked to from any of its doorways
## (behind furniture, between a crate and a wall), so that no path ever ends in one.
func _close_pockets(room: Dictionary) -> void:
	if room.get("nav", true) == false:
		return
	var level: int = room.level
	var grid := navigation[level]
	var box := _cells(level, room.outer)
	if box.size.x <= 0:
		return
	var seeds: Array[Vector2i] = []
	for door in room.doors:
		var pos: Vector3 = door.pos
		var out: Vector2 = OUT[int(door.side)]
		# Into this room: the first room of a doorway lies behind its side, the second before it.
		var inward := -out if str(door.a) == str(room.id) else out
		var seed_cell := _free_near(level, Vector2(pos.x, pos.z) + inward * 1.2, 2)
		if seed_cell.x < 999999:
			seeds.append(seed_cell)
	for stair in stairs:
		for pair in [[stair.low, stair.bottom], [stair.high, stair.top]]:
			if int(pair[0]) == level and box.has_point(pair[1]) and not grid.is_point_solid(pair[1]):
				seeds.append(pair[1])
	if room.has("seed"):
		var given := _free_near(level, room.seed, 6)
		if given.x < 999999:
			seeds.append(given)
	if seeds.is_empty():
		var middle := _free_near(level, (room.outer as Rect2).get_center(), 8)
		if middle.x < 999999:
			seeds.append(middle)
	if seeds.is_empty():
		return
	if hubs[level] == (floors[level].region as Rect2i).position:
		hubs[level] = seeds[0]
	# Nothing in the way in this room: nothing to close.
	var cluttered := false
	for rect in obstacles[level]:
		if (rect as Rect2).intersects(room.outer):
			cluttered = true
			break
	if not cluttered:
		return
	var width := box.size.x
	var total := width * box.size.y
	var state := PackedByteArray()
	state.resize(total)
	for index in range(total):
		if grid.is_point_solid(box.position + Vector2i(index % width, index / width)):
			state[index] = 2
	var queue := PackedInt32Array()
	queue.resize(total)
	var tail := 0
	for seed_cell in seeds:
		if not box.has_point(seed_cell):
			continue
		var start := (seed_cell.y - box.position.y) * width + seed_cell.x - box.position.x
		if state[start] == 0:
			state[start] = 1
			queue[tail] = start
			tail += 1
	var head := 0
	while head < tail:
		var index := queue[head]
		head += 1
		var x := index % width
		for next in [index - 1 if x > 0 else -1, index + 1 if x < width - 1 else -1, index - width, index + width]:
			if next >= 0 and next < total and state[next] == 0:
				state[next] = 1
				queue[tail] = next
				tail += 1
	var region: Rect2i = grid.region
	for index in range(total):
		if state[index] == 0:
			var cell := box.position + Vector2i(index % width, index / width)
			grid.set_point_solid(cell, true)
			plan_pictures[level].set_pixelv(cell - region.position, Color(1, 0, 0))

## Turns the collected geometry into meshes, each in the node of its zone.
func _commit() -> void:
	# What the rooms of every zone take up, for choosing the zones to draw.
	for room in rooms:
		if not zones.has(room.zone):
			continue
		var outer: Rect2 = room.outer
		var tall := maxf(float(room.height), 12.0 if bool(room.outdoor) else 3.0)
		var box := AABB(Vector3(outer.position.x, float(room.y) - 0.5, outer.position.y), Vector3(outer.size.x, tall + 1.0, outer.size.y))
		var entry: Dictionary = zones[room.zone]
		entry["box"] = (entry.box as AABB).merge(box) if entry.has("box") else box
	for key in chunks:
		var zone_id := str(key).get_slice("|", 0)
		var parent: Node3D = zones[zone_id].node if zones.has(zone_id) else self
		for instance in (chunks[key] as MeshBatch).commit(parent, str(key).get_slice("|", 1), chunk_shadows[key]):
			var made: Material = instance.mesh.surface_get_material(0)
			if made in [mats["glow"], mats["steady"], mats["blink"], mats["screen"], mats["pane"], mats["glass"], mats["flood"], mats["stain"]] or lone_glows.has(made):
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunks.clear()

# ---------------------------------------------------------------- the sky and the air

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "Air"
	environment = Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.018, 0.028, 0.05)
	sky_material.sky_horizon_color = Color(0.085, 0.11, 0.15)
	sky_material.ground_bottom_color = Color(0.01, 0.013, 0.017)
	sky_material.ground_horizon_color = Color(0.085, 0.11, 0.15)
	sky_material.sky_curve = 0.1
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 2.2
	environment.ssr_enabled = true
	environment.ssr_max_steps = 40
	environment.ssr_fade_in = 0.12
	environment.ssr_fade_out = 1.6
	environment.ssr_depth_tolerance = 0.25
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 0.95
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.16, 0.2, 0.26)
	environment.fog_light_energy = 1.0
	environment.fog_sky_affect = 0.8
	environment.fog_sun_scatter = 0.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_albedo = Color(0.8, 0.86, 0.92)
	environment.volumetric_fog_emission = Color(0.03, 0.042, 0.06)
	environment.volumetric_fog_anisotropy = 0.5
	environment.volumetric_fog_length = 72.0
	environment.volumetric_fog_detail_spread = 2.2
	environment.volumetric_fog_ambient_inject = 0.3
	environment.volumetric_fog_sky_affect = 0.9
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.9
	environment.adjustment_contrast = 1.05
	world.environment = environment
	add_child(world)
	moon = DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.6, 0.72, 0.95)
	moon.rotation_degrees = Vector3(-34, 152, 0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.05
	moon.shadow_normal_bias = 1.4
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.directional_shadow_max_distance = 110
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.light_volumetric_fog_energy = 0.8
	add_child(moon)
	mood_now = (MOODS[mood] as Dictionary).duplicate()
	_apply_mood()

func _apply_mood() -> void:
	environment.ambient_light_color = mood_now.ambient
	environment.ambient_light_energy = float(mood_now.energy)
	environment.fog_density = float(mood_now.fog)
	environment.fog_light_color = mood_now.tint
	environment.volumetric_fog_density = float(mood_now.haze)
	environment.volumetric_fog_emission_energy = float(mood_now.glow)
	environment.background_energy_multiplier = float(mood_now.sky)
	moon.light_energy = float(mood_now.moon)
	moon.visible = float(mood_now.moon) > 0.02

# ---------------------------------------------------------------- runtime

func level_height(level: int) -> float:
	return float(floors[level].y) if level >= 0 and level < floors.size() else 0.0

func abyss() -> float:
	var lowest := 0.0
	for entry in floors:
		lowest = minf(lowest, float(entry.y))
	return lowest - 8.0

## What a level is called on the map in the corner ("" for the ground outside).
func level_label(level: int) -> String:
	return str(floors[level].label) if level >= 0 and level < floors.size() else ""

## The floor a position stands on: the highest one below it (a body on its way up a
## flight belongs to the upper floor from 1.3 m below it, as on the farm).
func level_of(pos: Vector3) -> int:
	var flat := Vector2(pos.x, pos.z)
	var best := -1
	var best_y := -INF
	var nearest := 0
	var nearest_gap := INF
	for index in range(floors.size()):
		var entry: Dictionary = floors[index]
		if not (entry.bounds as Rect2).has_point(flat):
			continue
		var y := float(entry.y)
		if pos.y > y - 1.3 and y > best_y:
			best = index
			best_y = y
		if absf(pos.y - y) < nearest_gap:
			nearest_gap = absf(pos.y - y)
			nearest = index
	return best if best >= 0 else nearest

## The room a position is in, or {} between rooms.
func room_at(pos: Vector3) -> Dictionary:
	var flat := Vector2(pos.x, pos.z)
	var open_ground := {}
	for room in floors[level_of(pos)].rooms:
		# (Not far above a room or below it: stairs run under the lawn of the park.)
		var base := float(room.y)
		if pos.y < base - 1.5 or pos.y > base + maxf(float(room.height), 3.0) + 1.2:
			continue
		if (room.outer as Rect2).has_point(flat):
			# A room comes before the open ground it stands on.
			if not bool(room.outdoor):
				return room
			open_ground = room
	return open_ground

## The zone a position is in. On a flight between two floors that is the zone the flight
## was built in, whatever lies above it (the way down behind the mirror runs under the
## lawn of the park, and no room reaches around it).
func zone_at(pos: Vector3) -> String:
	var flat := Vector2(pos.x, pos.z)
	for stair in stairs:
		if not stair.has("zone") or not (stair.rect as Rect2).has_point(flat):
			continue
		var samples: PackedVector3Array = stair.points
		var nearest := INF
		var tread := 0.0
		for sample in samples:
			var gap := Vector2(sample.x - pos.x, sample.z - pos.z).length_squared()
			if gap < nearest:
				nearest = gap
				tread = sample.y
		# (From the feet of somebody lying on the steps to the eyes of somebody jumping.)
		if nearest < INF and pos.y > tread - 0.9 and pos.y < tread + 3.0:
			return str(stair.zone)
	var room := room_at(pos)
	return "" if room.is_empty() else str(room.zone)

func is_indoors(pos: Vector3) -> bool:
	var room := room_at(pos)
	if room.is_empty():
		# Between rooms: a stairwell under the ground is indoors too.
		var id := zone_at(pos)
		return id != "" and BELOW.has(str(zones[id].mood))
	return not bool(room.outdoor)

func is_toxic(_pos: Vector3) -> bool:
	return false

func is_reserved(_pos: Vector3) -> bool:
	return false

func set_gas(_zone: String) -> void:
	gas_zone = ""

func set_power(on: bool) -> void:
	powered = on

func set_beacon(_on: bool) -> void:
	pass

func set_shop_open(open: bool, _instant: bool = false) -> void:
	shop_open = open

func set_daylight(_bright: bool) -> void:
	pass

## The picture a shop's counter is seen from, for the one nearest to `pos`.
func shop_view_at(pos: Vector3) -> Dictionary:
	var best := shop_view
	var best_gap := INF
	for station in stations:
		if str(station.kind) == "shop" and station.has("view"):
			var gap := (station.pos as Vector3).distance_squared_to(pos)
			if gap < best_gap:
				best_gap = gap
				best = station.view
	return best

# --- areas and gates

func lock_all() -> void:
	for id in areas:
		locked[id] = true
	_apply_locks(true)

## Closes an area again: its gate shuts, and no path leads in or out of it.
func lock(id: String, instant: bool = false) -> void:
	if locked.has(id) and not bool(locked[id]):
		locked[id] = true
		_apply_locks(instant)

func unlock(id: String, instant: bool = false) -> void:
	# (The story's clean-up asks for the farm's areas on whatever map there is.)
	if not locked.has(id) or not bool(locked[id]):
		return
	locked[id] = false
	_apply_locks(instant)

func _apply_locks(instant: bool = false) -> void:
	for id in areas:
		area_open[id] = not bool(locked[id])
	for door in doors:
		if str(door.kind) == "gate":
			_shut_door(door, bool(locked.get(door.area, false)), instant)
	route_cache.clear()
	plan_stamp += 1

## Shuts or opens a doorway for bodies, shots and paths; its leaf follows.
func _shut_door(door: Dictionary, shut: bool, instant: bool = false) -> void:
	door.shut = shut
	door.target = 0.0 if shut else 1.0
	if navigation.size() > int(door.level) and bool(door.get("nav", true)):
		_paint(int(door.level), door.strip, shut)
		# What stands in a doorway stays in the way when it opens.
		if not shut:
			for rect in obstacles[int(door.level)]:
				if (rect as Rect2).intersects(door.strip):
					_paint(int(door.level), rect, true)
	if door.shape != null:
		(door.shape as CollisionShape3D).set_deferred("disabled", not shut)
	if door.lamp != null:
		for lamp in door.lamp:
			var glass := (lamp as MeshInstance3D).material_override as StandardMaterial3D
			glass.albedo_color = Color("e2503c") if shut else Color("5ee07a")
			glass.emission = glass.albedo_color
	if instant:
		door.amount = float(door.target)
		_place_leaves(door)

## The map as it was built, for another night on it: every area open, every scripted
## door shut, nothing shown or hidden by force.
func reset() -> void:
	forced.clear()
	here_zone = ""
	shown_at = Vector3(INF, INF, INF)
	powered = true
	for id in areas:
		locked[id] = false
	_apply_locks(true)
	for door in doors:
		if str(door.kind) == "script":
			_shut_door(door, not bool(door.get("starts_open", false)), true)
		elif str(door.kind) == "slide":
			door.amount = 0.0
			door.target = 0.0
			_place_leaves(door)
	route_cache.clear()

## Opens or shuts a named doorway (a gate's own area is not asked: for scripted doors).
func set_door(id: String, open: bool, instant: bool = false) -> void:
	if door_of.has(id):
		_shut_door(door_of[id], not open, instant)
		route_cache.clear()
		plan_stamp += 1

func door_open(id: String) -> bool:
	return door_of.has(id) and not bool(door_of[id].shut)

func _place_leaves(door: Dictionary) -> void:
	var leaves: Array = door.leaves
	for index in range(leaves.size()):
		(leaves[index] as Node3D).position = (door.homes[index] as Vector3) + (door.slides[index] as Vector3) * float(door.amount)

## Tells the sliding doors who is about (the middle of every body): each opens for
## whoever is within reach of it and closes behind them.
func feel(actors: PackedVector3Array) -> void:
	for door in doors:
		if str(door.kind) != "slide":
			continue
		var pos: Vector3 = door.pos
		var near := false
		for actor in actors:
			if absf(actor.y - pos.y) < 2.6 and Vector2(actor.x - pos.x, actor.z - pos.z).length_squared() < 10.5:
				near = true
				break
		door.target = 1.0 if near else 0.0
		if door.shape != null:
			(door.shape as CollisionShape3D).disabled = near or float(door.amount) > 0.3

func _run_doors(delta: float) -> void:
	for door in doors:
		var amount := float(door.amount)
		var target := float(door.target)
		if amount == target or (door.leaves as Array).is_empty():
			continue
		door.amount = move_toward(amount, target, delta * (3.2 if str(door.kind) == "slide" else 1.1))
		_place_leaves(door)

# --- zones and light

## Draws the zone the viewer is in and those that can be seen from it, hides the others,
## and sets the light of the place.
func _look_from(pos: Vector3) -> void:
	here_at = pos
	var id := zone_at(pos)
	if id != "" and id != here_zone:
		here_zone = id
		mood = str(zones[id].mood)
		_show_zones()
	elif pos.distance_squared_to(shown_at) > 4.0:
		_show_zones()

## Gives a zone another mood (the red of a lockdown), at once if the viewer is in it.
func set_zone_mood(id: String, mood_id: String) -> void:
	if not zones.has(id) or not MOODS.has(mood_id):
		return
	zones[id].mood = mood_id
	if here_zone == id:
		mood = mood_id

## Lamp glass that can be dimmed without touching any other: a copy of the map's, under
## its own name (for the room option `glow`, or for glow_key while something is built).
func _own_glow(key: String) -> StandardMaterial3D:
	if not mats.has(key):
		mats[key] = (mats["glow"] as StandardMaterial3D).duplicate()
		lone_glows.append(mats[key])
	return mats[key]

func _show_zones() -> void:
	if not zones.has(here_zone):
		return
	shown_at = here_at
	var seen: Array = zones[here_zone].sees
	var flat := Vector2(here_at.x, here_at.z)
	for id in zones:
		var entry: Dictionary = zones[id]
		var shown: bool = id == here_zone or seen.has(id)
		if not shown and entry.has("box"):
			# Near enough, and not a storey above or below (lamps shine through floors).
			var box: AABB = entry.box
			if here_at.y > box.position.y - 3.0 and here_at.y < box.end.y + 3.0:
				var plan := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
				var gap := Vector2(maxf(0.0, maxf(plan.position.x - flat.x, flat.x - plan.end.x)), maxf(0.0, maxf(plan.position.y - flat.y, flat.y - plan.end.y)))
				shown = gap.length() < ZONE_SIGHT
		if forced.has(id):
			shown = bool(forced[id])
		(entry.node as Node3D).visible = shown

## Shows or hides a zone whatever the viewer sees; "" as `how` hands it back.
func force_zone(id: String, how: String) -> void:
	if how == "":
		forced.erase(id)
	else:
		forced[id] = how == "show"
	_show_zones()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock += delta
	var viewer := get_viewport().get_camera_3d()
	if viewer != null:
		_look_from(viewer.global_position)
	var aim: Dictionary = MOODS[mood]
	var step := minf(1.0, delta * 2.2)
	for key in aim:
		if aim[key] is Color:
			mood_now[key] = (mood_now[key] as Color).lerp(aim[key], step)
		else:
			mood_now[key] = lerpf(float(mood_now[key]), float(aim[key]), step)
	_apply_mood()
	_run_doors(delta)
	for id in zones:
		if not (zones[id].node as Node3D).visible:
			continue
		for entry in zones[id].flickers:
			var wobble := flicker_noise.get_noise_1d(clock * 9.0 + float(entry.offset))
			var energy: float = float(entry.energy) * (1.0 + wobble * float(entry.amount))
			if not powered and bool(entry.wired):
				energy = 0.0
			(entry.light as Light3D).light_energy = energy

# --- the map in the corner

## One picture of closed ground for every level, kept until a lock changes.
func plans() -> Array:
	if plan_made != plan_stamp:
		plan_made = plan_stamp
		plan_textures.clear()
		for picture in plan_pictures:
			plan_textures.append(ImageTexture.create_from_image(picture))
	return plan_textures

# ---------------------------------------------------------------- obstacles

func _register(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var extent := Vector2(size.x, size.z)
	if yaw != 0.0:
		var c := absf(cos(yaw))
		var s := absf(sin(yaw))
		extent = Vector2(size.x * c + size.z * s, size.x * s + size.z * c)
	var rect := Rect2(Vector2(center.x, center.z) - extent * 0.5, extent).grow(NAV_MARGIN)
	var bottom := center.y - size.y * 0.5
	var top := center.y + size.y * 0.5
	for level in range(floors.size()):
		var floor_y := float(floors[level].y)
		if top > floor_y + 0.12 and bottom < floor_y + 1.9 and (floors[level].bounds as Rect2).intersects(rect):
			obstacles[level].append(rect)

func _solid(center: Vector3, size: Vector3, blocks_path: bool = true, yaw: float = 0.0) -> void:
	_add_shape(body, center, size, Basis(Vector3.UP, yaw))
	if not blocks_path:
		return
	_register(center, size, yaw)
	var top := center.y + size.y * 0.5
	var flat := Vector2(center.x, center.z)
	for level in range(floors.size()):
		var floor_y := float(floors[level].y)
		if (floors[level].bounds as Rect2).has_point(flat) and top > floor_y + 0.12 and top < floor_y + 1.2 and center.y - size.y * 0.5 < floor_y + 0.5:
			var cap := floor_y + 1.3 - top
			_add_shape(rails, Vector3(center.x, top + cap * 0.5, center.z), Vector3(size.x, cap, size.z), Basis(Vector3.UP, yaw))

# ---------------------------------------------------------------- paths

func nearest_cell(pos: Vector3, level: int = -1) -> Vector2i:
	if level < 0:
		level = level_of(pos)
	var grid := navigation[level]
	var region := grid.region
	var cell := Vector2i(clampi(roundi(pos.x / CELL), region.position.x, region.end.x - 1), clampi(roundi(pos.z / CELL), region.position.y, region.end.y - 1))
	if not grid.is_point_solid(cell):
		return cell
	var hidden := cell
	var hidden_distance := INF
	for radius in range(1, 11):
		var best := cell
		var best_distance := INF
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var nearby := cell + Vector2i(dx, dz)
				if not grid.is_in_boundsv(nearby) or grid.is_point_solid(nearby):
					continue
				var distance := Vector2(nearby.x * CELL - pos.x, nearby.y * CELL - pos.z).length_squared()
				if distance >= best_distance:
					continue
				if _reachable(pos, nearby, level):
					best_distance = distance
					best = nearby
				elif distance < hidden_distance:
					hidden_distance = distance
					hidden = nearby
		if best_distance < INF:
			return best
	if hidden_distance < INF:
		return hidden
	return hubs[level]

## The flight a position is on (its index in `stairs`) and the sample of its middle line
## nearest to it, or [-1, 0]. Flights may lie above one another: the height decides.
func _on_flight(pos: Vector3) -> Array:
	var flat := Vector2(pos.x, pos.z)
	for i in range(stairs.size()):
		var stair: Dictionary = stairs[i]
		if not (stair.rect as Rect2).has_point(flat):
			continue
		var samples: PackedVector3Array = stair.points
		var nearest := -1
		var gap := INF
		for k in range(samples.size()):
			var rise := samples[k].y - pos.y
			var distance := Vector2(samples[k].x - pos.x, samples[k].z - pos.z).length_squared() + rise * rise * 4.0
			if distance < gap:
				gap = distance
				nearest = k
		if nearest < 0:
			continue
		var reach := float(stair.width) * 0.5 + 0.45
		if absf(samples[nearest].y - pos.y) < 0.9 and Vector2(samples[nearest].x - pos.x, samples[nearest].z - pos.z).length_squared() < reach * reach:
			return [i, nearest]
	return [-1, 0]

func on_stairs(pos: Vector3) -> bool:
	return int(_on_flight(pos)[0]) >= 0

func _locate(pos: Vector3) -> Dictionary:
	var found := _on_flight(pos)
	if int(found[0]) >= 0:
		return {"stair": int(found[0]), "index": int(found[1]), "level": 0, "cell": Vector2i.ZERO}
	var level := level_of(pos)
	return {"stair": -1, "index": 0, "level": level, "cell": nearest_cell(pos, level)}

func area_of(pos: Vector3) -> String:
	var found := _on_flight(pos)
	if int(found[0]) >= 0:
		return str(stairs[int(found[0])].area)
	var room := room_at(pos)
	return "" if room.is_empty() else str(room.area)

## Chains of flights that lead from one level to another, as lists of indices into
## `stairs`; no level is passed twice.
func _routes(from_level: int, to_level: int) -> Array:
	var key := from_level * 100 + to_level
	if not route_cache.has(key):
		var found: Array = []
		_chains(from_level, to_level, [], [from_level], found)
		route_cache[key] = found
	return route_cache[key]

func _chains(at: int, goal: int, chain: Array, seen: Array, found: Array) -> void:
	if chain.size() >= 4:
		return
	for i in range(stairs.size()):
		var stair: Dictionary = stairs[i]
		if int(stair.low) != at and int(stair.high) != at:
			continue
		var next: int = int(stair.high) if int(stair.low) == at else int(stair.low)
		if seen.has(next):
			continue
		if next == goal:
			found.append(chain + [i])
		else:
			_chains(next, goal, chain + [i], seen + [next], found)

## As on the farm, with one difference: a closed area is a place of its own. No way leads
## into it or out of it, but whoever is inside finds his way about in there.
func path_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	var from_area := area_of(from)
	var to_area := area_of(to)
	if from_area != to_area and (not bool(area_open.get(from_area, true)) or not bool(area_open.get(to_area, true))):
		return PackedVector3Array()
	var started := Time.get_ticks_usec()
	var result := _path(from, to)
	path_usec += Time.get_ticks_usec() - started
	path_calls += 1
	return result

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := _locate(from)
	var b := _locate(to)
	if a.stair >= 0 and a.stair == b.stair:
		var samples: PackedVector3Array = stairs[a.stair].points
		var direct := PackedVector3Array()
		var step := 1 if b.index >= a.index else -1
		for i in range(a.index, b.index + step, step):
			direct.append(samples[i])
		return direct
	var best := PackedVector3Array()
	var best_cost := INF
	for start in _approaches(a):
		for goal in _approaches(b):
			var lead: PackedVector3Array = start.lead
			var tail: PackedVector3Array = (goal.lead as PackedVector3Array).duplicate()
			tail.reverse()
			var base: float = float(start.cost) + float(goal.cost)
			var start_cell: Vector2i = start.cell
			var goal_cell: Vector2i = goal.cell
			if start.level == goal.level:
				if base + _gap(start_cell, goal_cell) >= best_cost:
					continue
				var route := _grid_path(start.level, start_cell, goal_cell)
				if route.is_empty():
					continue
				var cost := base + _length(route)
				if cost < best_cost:
					best_cost = cost
					best = lead + route + tail
				continue
			var options: Array = []
			for chain in _routes(start.level, goal.level):
				var bound := base
				var at := start_cell
				var level: int = start.level
				for index in chain:
					var stair: Dictionary = stairs[index]
					if _stair_shut(stair):
						bound = INF
						break
					var up: bool = stair.low == level
					bound += float(stair.length) + _gap(at, stair.bottom if up else stair.top)
					at = stair.top if up else stair.bottom
					level = stair.high if up else stair.low
				if bound < INF:
					options.append([bound + _gap(at, goal_cell), chain])
			options.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
			for option in options:
				if float(option[0]) >= best_cost:
					break
				var route := lead.duplicate()
				var cost := base
				var at := start_cell
				var level: int = start.level
				for index in option[1]:
					var stair: Dictionary = stairs[index]
					var up: bool = stair.low == level
					var leg := _grid_path(level, at, stair.bottom if up else stair.top)
					cost += _length(leg) + float(stair.length)
					if leg.is_empty() or cost >= best_cost:
						cost = INF
						break
					var steps: PackedVector3Array = (stair.points as PackedVector3Array).duplicate()
					if not up:
						steps.reverse()
					route += leg + steps
					at = stair.top if up else stair.bottom
					level = stair.high if up else stair.low
				if cost == INF:
					continue
				var last := _grid_path(level, at, goal_cell)
				if last.is_empty():
					continue
				cost += _length(last)
				if cost < best_cost:
					best_cost = cost
					best = route + last + tail
	return best
