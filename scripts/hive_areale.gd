class_name HiveAreale
extends RefCounted
## Builds the random part of a night of mission two (HiveLayout) into the map (HiveMap)
## and runs what it needs while it is played: its floors, its pieces and the doorways
## between them, its caches and stops, the tunnel the train seems to run through on the
## way to it, and its deep water.
##
## Its floors: every height of the lattice (HiveLayout.shared_height) is one floor that
## all pieces standing at it share - a corridor and the area it leads into are one grid,
## and the infected follow the squad from one to the next. A storey between two of those
## (a gallery, a catwalk) is a floor of its piece alone.
##
##   --hive-layout=showcase | <seed> | classic   which night a map built by a tool shows

## How much a body in deep water moves, how long until it hurts, and how much.
const WADE := 0.4
const WATER_GRACE := 1.5
const WATER_HARM := 6.0
## Infected that end up in deep water are gone after this long; companions are pulled
## out on to the nearest walkway after this long.
const DROWN := 3.0
const PULL_OUT := 1.0
## How far from a body a walkway may be to climb out on to it.
const CLIMB_REACH := 2.4

## The night a map is built with when nobody has set one (a tool, a picture run).
static func wanted_from_args() -> Dictionary:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hive-layout="):
			var what := arg.trim_prefix("--hive-layout=")
			if what == "showcase":
				return HiveLayout.showcase()
			if what.is_valid_int():
				return HiveLayout.plan(int(what))
	return HiveLayout.classic()

static func random_part(map: HiveMap) -> bool:
	return not map.night.is_empty() and not bool(map.night.get("classic", true))

# ---------------------------------------------------------------- floors

## Declares the floors of the random part (after the map's own).
static func declare_floors(map: HiveMap) -> void:
	if not random_part(map):
		return
	var heights := HiveLayout.heights_of(map.night)
	var keys: Array = heights.keys()
	keys.sort()
	keys.reverse()
	var shared_count := 0
	for h in keys:
		if HiveLayout.shared_height(float(h)):
			shared_count += 1
	var shared_index := 0
	for h in keys:
		var pieces: Array = heights[h]
		if HiveLayout.shared_height(float(h)):
			var bounds := Rect2()
			for piece: Dictionary in pieces:
				for part: Rect2 in piece.parts:
					bounds = part if bounds.size == Vector2.ZERO else bounds.merge(part)
			shared_index += 1
			var label := "SEKTOR C" if shared_count == 1 else "SEKTOR C · %d" % shared_index
			map.area_floors["%.2f" % float(h)] = map._floor("areal_%d" % shared_index, label, float(h), bounds.grow(3.0))
		else:
			for piece: Dictionary in pieces:
				var bounds := Rect2()
				for part: Rect2 in piece.parts:
					bounds = part if bounds.size == Vector2.ZERO else bounds.merge(part)
				var label := str(HiveLayout.info(str(piece.def)).get("label", "SEKTOR C"))
				map.area_floors["%s|%.2f" % [str(piece.id), float(h)]] = map._floor("areal_%s_%d" % [str(piece.id), int(round(float(h) * 10.0))], label + " · OBEN", float(h), bounds.grow(1.0))

## The floor a height of a piece stands on.
static func area_floor(map: HiveMap, h: float, piece: Dictionary) -> int:
	var key := "%.2f" % snappedf(h, 0.01)
	if map.area_floors.has(key):
		return int(map.area_floors[key])
	var own := "%s|%.2f" % [str(piece.get("id", "")), snappedf(h, 0.01)]
	if map.area_floors.has(own):
		return int(map.area_floors[own])
	push_error("HiveAreale: no floor at %.2f for %s" % [h, str(piece.get("id", "?"))])
	return 0

# ---------------------------------------------------------------- building

## Builds every piece of the night and the doorways that join them.
static func lay(map: HiveMap) -> void:
	if not random_part(map):
		return
	map._own_dice(71200 + int(map.night.get("seed", 0)) % 1000)
	for piece: Dictionary in map.night.pieces:
		piece.rooms = []
		piece.points = {}
		var made := HiveLayout.kit(str(piece.def))
		made.m = map
		made.piece = piece
		made.o = piece.origin
		var piece_info := HiveLayout.info(str(piece.def))
		map.area = ""
		map._begin_zone(str(piece.id), str(piece_info.get("mood", "cold")))
		made.lay()
		# A supply point where a defeat is taken up again in the middle of the night.
		if int(piece.get("area_index", -1)) >= 0 and int(piece.area_index) == int(map.night.get("checkpoint", -1)) and piece_info.has("supply"):
			var spot: Array = piece_info.supply
			map._chunk("Kit", false)
			map._supply(made.p((spot[0] as Vector3).x, 0.0, (spot[0] as Vector3).z), spot[1], str(piece_info.label))
		map._end_zone()
		map.areal_kits[str(piece.id)] = made
	# The doorways between the pieces: every one a gate of the facility, shut or open by
	# the night (HiveDirector); the way out of an area says so over it.
	for link: Dictionary in map.night.links:
		var a := "%s_%s" % [str(link.a), str(link.a_room)]
		var b := "%s_%s" % [str(link.b), str(link.b_room)]
		if not map.room_of.has(a) or not map.room_of.has(b):
			push_error("HiveAreale: doorway %s between rooms that are not there (%s, %s)" % [str(link.name), a, b])
			continue
		var spot: Vector3 = link.spot
		var side := int(link.side)
		var at := spot.x if side == HiveCore.NORTH or side == HiveCore.SOUTH else spot.z
		map._begin_zone(str(map.room_of[a].zone))
		var door := map._door(a, b, at, AreaKit.PORT_WIDE, {"kind": "script", "name": str(link.name), "starts_open": bool(link.open), "height": AreaKit.PORT_TALL})
		map.areal_points[str(link.name)] = spot
		if str(link.name).ends_with("_out") and not door.is_empty():
			_sign(map, str(link.name), door)
		map._end_zone()
	map._shared_dice()

## A word over a way out: shut or open, on both faces of its wall.
static func _sign(map: HiveMap, name: String, door: Dictionary) -> void:
	var out: Vector2 = HiveCore.OUT[int(door.side)]
	var pos: Vector3 = door.pos
	var labels: Array = []
	for face in [-1.0, 1.0]:
		var label := map.lettering("VERRIEGELT", pos + Vector3(out.x * face * 0.42, float(door.height) + 0.62, out.y * face * 0.42), 40, Color("ff5a44"))
		label.rotation.y = atan2(out.x * face, out.y * face)
		label.outline_size = 10
		label.outline_modulate = Color(0, 0, 0, 0.9)
		labels.append(label)
	map.areal_signs[name] = labels

## Opens or shuts a way of the random part, and what is written over it.
static func set_port(map: HiveMap, name: String, open: bool, instant: bool = false) -> void:
	map.set_door(name, open, instant)
	for label: Label3D in map.areal_signs.get(name, []):
		label.text = "OFFEN" if open else "VERRIEGELT"
		label.modulate = Color("6ef08a") if open else Color("ff5a44")

## The cache sites of the pieces, as HiveCaches.SITES (in the world).
static func cache_sites(map: HiveMap) -> Array:
	var out: Array = []
	if not random_part(map):
		return out
	var areas: int = (map.night.get("areas", []) as Array).size()
	for piece: Dictionary in map.night.pieces:
		var piece_info := HiveLayout.info(str(piece.def))
		var depth := 3 if int(piece.get("area_index", 0)) * 2 >= areas else 2
		for spec: Array in piece_info.get("caches", []):
			var side := int(spec[2])
			var origin: Vector3 = piece.origin
			var along := (origin.x if side == HiveCore.NORTH or side == HiveCore.SOUTH else origin.z) + float(spec[3])
			out.append(["%s_%s" % [str(piece.id), str(spec[0])], "%s_%s" % [str(piece.id), str(spec[1])], side, along, str(spec[4]), str(spec[5]), depth, "areal_%s" % str(piece.id), ""])
	return out

## The stops (workbench and equipment station) of the areas, as HiveStations.SITES.
static func station_sites(map: HiveMap) -> Array:
	var out: Array = []
	if not random_part(map):
		return out
	for piece: Dictionary in map.night.pieces:
		var piece_info := HiveLayout.info(str(piece.def))
		if not piece_info.has("station") or int(piece.get("area_index", -1)) % 2 == 1:
			continue
		var spec: Array = piece_info.station
		var side := int(spec[1])
		var origin: Vector3 = piece.origin
		var units: Array = []
		for unit: Array in spec[2]:
			units.append([str(unit[0]), (origin.x if side == HiveCore.NORTH or side == HiveCore.SOUTH else origin.z) + float(unit[1])])
		out.append(["%s_stop" % str(piece.id), "%s_%s" % [str(piece.id), str(spec[0])], side, units])
	return out

# ---------------------------------------------------------------- the train

## The pit of a railway line through a room (as HiveMap._track, for a room anywhere):
## its floor, the rails, the wall under the platform's edge at `edge_z` (the platform on
## the side `toward`: +1 south, -1 north) and dark tunnel stubs at both ends.
static func track(map: HiveMap, room_id: String, edge_z: float, toward: float, stubs: bool = true) -> void:
	var room: Dictionary = map.room_of[room_id]
	var outer: Rect2 = room.outer
	var y := float(room.y)
	var pit := y - 1.1
	var mid := outer.get_center()
	var reach := outer.size.x + (30.0 if stubs else 0.0)
	map._part("darkfloor", Vector3(mid.x, pit - 0.15, mid.y), Vector3(reach, 0.3, outer.size.y), Color(0.5, 0.5, 0.5))
	map._solid(Vector3(mid.x, pit - 0.25, mid.y), Vector3(outer.size.x, 0.5, outer.size.y), false)
	map._part("formwork", Vector3(mid.x, y - 0.55, edge_z + toward * 0.1), Vector3(outer.size.x, 1.1, 0.2), Color(0.6, 0.6, 0.58))
	var far_z := outer.position.y if toward > 0.0 else outer.end.y
	map._part("formwork", Vector3(mid.x, y - 0.55, far_z + toward * 0.1), Vector3(outer.size.x, 1.1, 0.2), Color(0.6, 0.6, 0.58))
	var line := edge_z - toward * 2.0
	for rail in [-0.75, 0.75]:
		map._part("steel", Vector3(mid.x, pit + 0.09, line + rail), Vector3(reach, 0.18, 0.09), Color("3b3d3e"))
	for i in range(int(reach / 1.5)):
		map._part("formwork", Vector3(mid.x - reach * 0.5 + i * 1.5 + 0.75, pit + 0.04, line), Vector3(0.34, 0.08, 2.5), Color(0.42, 0.42, 0.4))
	map._stripe(Vector3(outer.position.x, y, edge_z + toward * 0.75), Vector3(outer.end.x, y, edge_z + toward * 0.75), 0.18, Color("c9a227"))
	if not stubs:
		return
	for end in [-1.0, 1.0]:
		var x: float = mid.x + end * (outer.size.x * 0.5 + 7.5)
		map._part("beton", Vector3(x, y + 4.75, line), Vector3(15.0, 0.3, 5.6), Color(0.3, 0.3, 0.3))
		for wall in [-1.0, 1.0]:
			map._part("beton", Vector3(x, y + 1.75, line + wall * 2.65), Vector3(15.0, 5.9, 0.3), Color(0.34, 0.34, 0.34))
		map._part("plain", Vector3(mid.x + end * (outer.size.x * 0.5 + 15.0), y + 1.75, line), Vector3(0.2, 6.0, 5.6), Color("030303"))
		map._glow_box(Vector3(mid.x + end * (outer.size.x * 0.5 + 9.0), y + 3.2, line + 2.4), Vector3(0.16, 0.16, 0.05), Color("ff3a2a"), 4.0)
		map._add_shape(map.body, Vector3(mid.x + end * (outer.size.x * 0.5 + 0.2), y + 2.0, line), Vector3(0.3, 6.5, 6.0))

## The tunnel that passes the windows of a car of the random part while the train runs:
## a zone of its own around the car (`centre`), only drawn during the ride. Returns its
## lamps, which run past (HiveMap._process).
static func ride_tunnel(map: HiveMap, zone_id: String, centre: Vector3) -> Array:
	map._begin_zone(zone_id, "under")
	map._chunk("Tube", false)
	for wall in [-1.0, 1.0]:
		map._part("beton", centre + Vector3(0, 1.4, wall * 3.0), Vector3(70.0, 5.2, 0.3), Color(0.2, 0.2, 0.2))
	map._part("beton", centre + Vector3(0, 4.1, 0), Vector3(70.0, 0.3, 6.4), Color(0.18, 0.18, 0.18))
	var holder := Node3D.new()
	holder.name = "RideLamps"
	holder.position = centre
	map.add_child(holder)
	var lamps: Array = []
	for index in range(8):
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 1.4, 0.06)
		bar.mesh = mesh
		bar.material_override = map._glow_material(Color("ffd9a0"), 5.0)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.position = Vector3(-35.0 + index * 8.75, 1.9, 2.8 if index % 2 == 0 else -2.8)
		var glow := OmniLight3D.new()
		glow.light_color = Color("ffd9a0")
		glow.light_energy = 2.4
		glow.omni_range = 7.0
		glow.position = Vector3(0, 0, -0.4 if index % 2 == 0 else 0.4)
		bar.add_child(glow)
		holder.add_child(bar)
		lamps.append(bar)
	map._end_zone()
	return lamps

# ---------------------------------------------------------------- water

## A basin: its floor (a pit nobody walks in on purpose), the walls that close it under
## the floor of the room around it, and the water in it.
static func water(map: HiveMap, rect: Rect2, surface: float, bottom: float, deep: bool) -> void:
	var kept := map.batch
	map._chunk("Basin", false)
	var middle := rect.get_center()
	map._part("darkfloor", Vector3(middle.x, bottom - 0.15, middle.y), Vector3(rect.size.x, 0.3, rect.size.y), Color(0.18, 0.22, 0.22))
	map._part_shape(Vector3(middle.x, bottom - 0.15, middle.y), Vector3(rect.size.x, 0.3, rect.size.y))
	var high := surface + 0.12
	for edge in [[Vector3(middle.x, 0, rect.position.y - 0.15), Vector3(rect.size.x + 0.6, 0, 0.3)], [Vector3(middle.x, 0, rect.end.y + 0.15), Vector3(rect.size.x + 0.6, 0, 0.3)], [Vector3(rect.position.x - 0.15, 0, middle.y), Vector3(0.3, 0, rect.size.y)], [Vector3(rect.end.x + 0.15, 0, middle.y), Vector3(0.3, 0, rect.size.y)]]:
		var centre: Vector3 = edge[0]
		var size: Vector3 = edge[1]
		centre.y = (bottom + high) * 0.5
		size.y = high - bottom
		map._part("beton", centre, size, Color(0.3, 0.33, 0.33))
		map._part_shape(centre, size)
	# (The water's own material: it is drawn where it stands above the floor of the basin.)
	var key := "flood_%.2f" % bottom
	if not map.mats.has(key):
		var copy := (map.mats["flood"] as ShaderMaterial).duplicate() as ShaderMaterial
		copy.set_shader_parameter("floor_y", bottom)
		map.mats[key] = copy
	map._chunk("Water", false)
	map.batch.quad(map.mats[key], Vector3(rect.position.x, surface, rect.position.y), Vector3(rect.position.x, surface, rect.end.y), Vector3(rect.end.x, surface, rect.end.y), Vector3(rect.end.x, surface, rect.position.y), Color.WHITE)
	map.batch = kept
	map.waters.append({"rect": rect, "surface": surface, "bottom": bottom, "deep": deep})

## A sheet of water over a floor one walks on (it is only seen).
static func wet(map: HiveMap, rect: Rect2, top: float, floor_y: float) -> void:
	var kept := map.batch
	var key := "flood_%.2f" % floor_y
	if not map.mats.has(key):
		var copy := (map.mats["flood"] as ShaderMaterial).duplicate() as ShaderMaterial
		copy.set_shader_parameter("floor_y", floor_y)
		map.mats[key] = copy
	map._chunk("Water", false)
	map.batch.quad(map.mats[key], Vector3(rect.position.x, top, rect.position.y), Vector3(rect.position.x, top, rect.end.y), Vector3(rect.end.x, top, rect.end.y), Vector3(rect.end.x, top, rect.position.y), Color.WHITE)
	map.batch = kept

## The basin a body stands in the deep water of, or {}.
static func deep_at(map: HiveMap, pos: Vector3) -> Dictionary:
	for basin: Dictionary in map.waters:
		if bool(basin.deep) and (basin.rect as Rect2).has_point(Vector2(pos.x, pos.z)) and pos.y < float(basin.surface) - 0.35 and pos.y > float(basin.bottom) - 1.0:
			return basin
	return {}

## Where somebody in deep water at `pos` climbs out: the nearest free ground of the floor
## around the basin within reach, or INF.
static func climb_out(map: HiveMap, pos: Vector3) -> Vector3:
	var basin := deep_at(map, pos)
	if basin.is_empty():
		return Vector3.INF
	var level := map.level_of(Vector3(pos.x, float(basin.surface) + 0.6, pos.z))
	var cell := map._free_near(level, Vector2(pos.x, pos.z), int(ceil(CLIMB_REACH / CabinMap.CELL)))
	if cell.x > 99999:
		return Vector3.INF
	return Vector3(cell.x * CabinMap.CELL, map.level_height(level) + 0.08, cell.y * CabinMap.CELL)

## What deep water does, every physics step: the survivor wades slowly, it hurts him after
## a moment, and he climbs out with a jump at the edge (Survivor); a companion is pulled
## out; an infected that ends up in it is gone.
static func run_waters(map: HiveMap, delta: float) -> void:
	if map.waters.is_empty():
		return
	var game: Node = map.get_parent()
	if game == null or not ("player" in game):
		return
	var player: Survivor = game.player
	if is_instance_valid(player):
		var in_deep := not deep_at(map, player.global_position).is_empty()
		player.wade = WADE if in_deep else 1.0
		map.water_time = map.water_time + delta if in_deep else 0.0
		if in_deep and map.water_time > WATER_GRACE and not player.down and not (game.sandbox.on and game.sandbox.god):
			player.receive_damage(WATER_HARM * delta, Vector3.INF, "water")
		if in_deep and map.water_time > 0.3 and map.water_told < 0.0:
			map.water_told = 6.0
			game.hud.announce("TIEFES WASSER", "Am Rand mit [Leertaste] auf den Steg ziehen.", 3)
		map.water_told -= delta
	for mate in game.team:
		if not is_instance_valid(mate):
			continue
		var key: int = mate.get_instance_id()
		if deep_at(map, mate.global_position).is_empty():
			map.water_bodies.erase(key)
			continue
		map.water_bodies[key] = float(map.water_bodies.get(key, 0.0)) + delta
		if float(map.water_bodies[key]) > PULL_OUT:
			var out := climb_out(map, mate.global_position)
			if out != Vector3.INF:
				mate.global_position = out
			map.water_bodies.erase(key)
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy == null or enemy.dead:
			continue
		var key := enemy.get_instance_id()
		if deep_at(map, enemy.global_position).is_empty():
			map.water_bodies.erase(key)
			continue
		map.water_bodies[key] = float(map.water_bodies.get(key, 0.0)) + delta
		if float(map.water_bodies[key]) > DROWN:
			map.water_bodies.erase(key)
			enemy._retire()
			enemy.queue_free()
			game.alive_count = maxi(0, game.alive_count - 1)

# ---------------------------------------------------------------- where things are

## The piece of the random part a position lies in ({} for none).
static func piece_at(map: HiveMap, pos: Vector3) -> Dictionary:
	if not random_part(map):
		return {}
	var flat := Vector2(pos.x, pos.z)
	for piece: Dictionary in map.night.pieces:
		var low := 99999.0
		var high := -99999.0
		for h in piece.heights:
			low = minf(low, float(h))
			high = maxf(high, float(h))
		if pos.y < low - 2.0 or pos.y > high + 12.0:
			continue
		for part: Rect2 in piece.parts:
			if part.has_point(flat):
				return piece
	return {}

## A piece of the night by its id ({} if there is none).
static func piece(map: HiveMap, id: String) -> Dictionary:
	for entry: Dictionary in map.night.get("pieces", []):
		if str(entry.id) == id:
			return entry
	return {}

# ---------------------------------------------------------------- stairs

## A stairwell between two floors two storeys apart: from the wall line at `from` (where
## a room on the height `y_first` ends) it runs RUN metres the way `side` looks to the wall
## line of a room on `y_second` - a flight, a landing, a flight - between walls of
## concrete, under a ceiling, with caged lamps. The rooms at its ends need an opening
## (a join without paths) of FLIGHT metres in those walls. Makes the way for the paths too.
const RUN := 18.0
const FLIGHT := 2.6

static func stair_shaft(map: HiveMap, from: Vector2, side: int, wide: float, y_first: float, y_second: float, tall: float, first_level: int, second_level: int) -> void:
	var dir: Vector2 = HiveCore.OUT[side]
	var mid := (y_first + y_second) * 0.5
	var low := minf(y_first, y_second)
	var high := maxf(y_first, y_second)
	var at := func(t: float, height: float) -> Vector3:
		return Vector3(from.x + dir.x * t, height, from.y + dir.y * t)
	var grey := Color(0.7, 0.7, 0.68)
	var across := Vector2(absf(dir.y), absf(dir.x))
	map._chunk("Stairs", false)
	for flight: Array in [[at.call(0.4, y_first), at.call(7.6, mid)], [at.call(10.4, mid), at.call(17.6, y_second)]]:
		var a: Vector3 = flight[0]
		var b: Vector3 = flight[1]
		var foot := a if a.y < b.y else b
		var head := b if a.y < b.y else a
		map._steps(foot, head, FLIGHT, "betonfloor", grey)
		map._handrail(foot, head, FLIGHT * 0.5 - 0.05)
		map._handrail(foot, head, -(FLIGHT * 0.5 - 0.05))
	for slab: Array in [[7.6, 10.4, mid], [-0.3, 0.4, y_first], [17.6, 18.3, y_second]]:
		var centre: Vector3 = at.call((float(slab[0]) + float(slab[1])) * 0.5, float(slab[2]) - 0.15)
		var long := float(slab[1]) - float(slab[0])
		var size := Vector3(FLIGHT * across.x + long * absf(dir.x), 0.3, FLIGHT * across.y + long * absf(dir.y))
		map._part("betonfloor", centre, size, grey)
		map._solid(centre, size, false)
	var bottom := low - 0.4
	var top := high + tall + 0.3
	for flank in [-1.0, 1.0]:
		var centre: Vector3 = at.call(RUN * 0.5, (bottom + top) * 0.5) + Vector3(across.x, 0, across.y) * (wide * 0.5 + 0.15) * flank
		var size := Vector3(0.3 * across.x + RUN * absf(dir.x), top - bottom, 0.3 * across.y + RUN * absf(dir.y))
		map._part("formwork", centre, size, Color(0.62, 0.62, 0.6))
		map._part_shape(centre, size)
	for end: Array in [[-0.15, y_first], [RUN + 0.15, y_second]]:
		var floor_y := float(end[1])
		for band: Array in [[bottom, floor_y - 0.3], [floor_y + tall + 0.3, top]]:
			if float(band[1]) - float(band[0]) < 0.05:
				continue
			var centre: Vector3 = at.call(float(end[0]), (float(band[0]) + float(band[1])) * 0.5)
			var size := Vector3((wide + 0.6) * across.x + 0.3 * absf(dir.x), float(band[1]) - float(band[0]), (wide + 0.6) * across.y + 0.3 * absf(dir.y))
			map._part("formwork", centre, size, Color(0.6, 0.6, 0.58))
			map._part_shape(centre, size)
	var middle: Vector3 = at.call(RUN * 0.5, 0.0)
	var floor_size := Vector3(wide * across.x + RUN * absf(dir.x), 0.3, wide * across.y + RUN * absf(dir.y))
	map._part("betonfloor", Vector3(middle.x, bottom + 0.25, middle.z), floor_size, Color(0.5, 0.5, 0.5))
	map._part_shape(Vector3(middle.x, bottom + 0.25, middle.z), floor_size)
	map._part("beton", Vector3(middle.x, top - 0.15, middle.z), floor_size, Color(0.45, 0.45, 0.45))
	map._part_shape(Vector3(middle.x, top - 0.15, middle.z), floor_size)
	for t in [4.0, 9.0, 14.0]:
		var height: float = lerpf(y_first, mid, t / 7.6) if t < 7.6 else (mid if t < 10.4 else lerpf(mid, y_second, (t - 10.4) / 7.2))
		var lamp_at: Vector3 = at.call(t, height + 2.6) + Vector3(across.x, 0, across.y) * (wide * 0.5 - 0.1)
		map._part("plate", lamp_at, Vector3(0.22, 0.22, 0.22), Color("1b1c1b"))
		map._glow_box(lamp_at - Vector3(across.x, 0, across.y) * 0.08, Vector3(0.12, 0.12, 0.12), Color("ffcf8a"), 4.5)
		map._light(lamp_at - Vector3(across.x, 0, across.y) * 0.6, Color("ffcf8a"), 1.6, 8.0, false, 0.05 if t == 9.0 else 0.0, 0.5, HiveCore.LAMP_FADE)
	map._wall_sign("▲  EBENE  %+d" % int(round((high - HiveLayout.BASE) / HiveLayout.STOREY)), at.call(9.0, mid + 1.6) + Vector3(across.x, 0, across.y) * (wide * 0.5 - 0.02), 60, Color(0.5, 0.4, 0.1), atan2(-across.x, -across.y))
	var route := PackedVector3Array([at.call(-2.0, y_first), at.call(0.4, y_first), at.call(7.6, mid), at.call(10.4, mid), at.call(17.6, y_second), at.call(RUN + 2.0, y_second)])
	if y_first > y_second:
		route.reverse()
	map._link(route, FLIGHT, first_level if y_first < y_second else second_level, second_level if y_first < y_second else first_level)
