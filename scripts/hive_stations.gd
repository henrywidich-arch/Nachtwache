class_name HiveStations
extends RefCounted
## The workbenches and the equipment stations of the second mission.
##
## Most weapons of that mission are found in caches off the way (HiveCaches), and the four
## supply points lie far apart. So there are a few stops in between - where a place is
## held next, where a defeat is taken up again and no supply point follows, and before the
## last fight. A stop is a workbench and an equipment station together:
##   a workbench    improves the weapons that are carried (the workbench's own screen), and
##   an equipment station sells attachments, gear, what is used up and what the squad
##                  wears (the shop's lists TABS) - no weapons, and no tree of abilities is
##                  changed there: those stay with the weapon lockers of the supply points.
## Neither offers ammunition or first aid: a station is no supply point.
##
## Each is one of four models of the project's own (LOOKS; prepared with
## tools/blender_station.py). The workbench of a supply point is one of the two upgrade
## models too (HiveMap._supply). Everything a station does is the game's: a workbench is
## a station of the kind "upgrade" like any other, an equipment station one of the kind
## "gear" that opens the shop's screen cut down (Game.gear_only, ShopScreen).
##
##   --stations-check --capture-dir=<folder>   pictures of all of it (see pictures)

## The four models: the file below assets/, the kind of station it is, and for an
## equipment station the list its screen opens with (what its own sign promises).
const LOOKS := {
	"bay": {"model": "hive/user/upgrade_bay.glb", "kind": "upgrade"},
	"bench": {"model": "hive/user/upgrade_bench.glb", "kind": "upgrade"},
	"cabinet": {"model": "hive/user/gear_cabinet.glb", "kind": "gear", "tab": "gear"},
	"rack": {"model": "hive/user/gear_rack.glb", "kind": "gear", "tab": "mods"}
}
## The lists of the shop an equipment station has (SurvivalHUD.SHOP_TABS).
const TABS := ["mods", "gear", "use", "team"]
const BENCH_WORD := "WERKBANK"
const GEAR_WORD := "AUSRÜSTUNG"
const AMBER := Color("e8bd79")
const BLUE := Color("9fd0ff")
## Clear of what the walls wear.
const GAP := 0.08
## The places: a name, the room, the side of the room they stand against, what stands
## there - each a look and where along that wall its middle is - and, where the wall one
## sees is not the room's own, how far before that it stands.
##   spine      behind the caches of the administration, the stop before the canteen is held
##   labs_...   at the head of the laboratory corridor, where a defeat is taken up again
##              and no supply point follows any more (between its windows: the rack in the
##              pier beside laboratory A, the bay before the cryo store)
##   cross      the last stop before the hall of towers
## They come at a distance: together with the supply points, a workbench and a counter
## that sells about every hundred metres of the squad's way, never two of a kind nearer
## than MIN_APART on foot, and one of each within BEFORE_FIGHT of every place that is held
## (tools/station_stock.gd lists them all; Verification._hive_stations holds it to that).
## There were seven such places once (v0.44): the ones that doubled a supply point one
## room on - in the depot, in the terminal hall, in the security centre, in the plant
## corridor - are gone again.
const SITES := [
	["spine", "spine", HiveCore.WEST, [["cabinet", -393.6], ["bench", -390.4]]],
	["labs_gear", "lab_corridor", HiveCore.WEST, [["rack", -507.95]]],
	["labs_bench", "lab_corridor", HiveCore.EAST, [["bay", -519.5]]],
	["cross", "cross", HiveCore.NORTH, [["cabinet", -17.4], ["bench", -14.2]]]
]
## How far apart on foot two workbenches, or two counters that sell, are at the least, and
## how near the last of each is to a place that is held.
const MIN_APART := 40.0
const BEFORE_FIGHT := 50.0

static func size_of(map: HiveMap, look: String) -> Vector3:
	return map._model_size(str(LOOKS[look].model))

## How tall a look is (without its model: a plain counter).
static func tall(map: HiveMap, look: String) -> float:
	return size_of(map, look).y if ResourceLoader.exists(map._model_path(str(LOOKS[look].model))) else 0.92

## How much of a wall a look takes (without its model: what a plain counter takes).
static func wide(map: HiveMap, look: String) -> float:
	return size_of(map, look).x if ResourceLoader.exists(map._model_path(str(LOOKS[look].model))) else 1.45

## Puts one station into the map: its back on `back` (a point on the floor), looking the
## way `facing` points, its word above it. Returns the station as the game knows it
## (CabinMap.stations): besides what every station has, its look, where one stands before
## it, and for an equipment station the picture its screen is seen from.
static func put(map: HiveMap, look: String, back: Vector3, facing: Vector3, more: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = LOOKS[look]
	var id := str(spec.model)
	var kind := str(spec.kind)
	var bench := kind == "upgrade"
	var yaw := atan2(facing.x, facing.z)
	if not ResourceLoader.exists(map._model_path(id)):
		# (Without the model: the plain counter a workbench always was; no equipment.)
		if bench:
			map._station("upgrade", BENCH_WORD, "250", back + facing * 0.39, atan2(-facing.z, facing.x), AMBER)
			return map.stations[map.stations.size() - 1]
		return {}
	var size := size_of(map, look)
	var middle := back + facing * (size.z * 0.5)
	var front := back + facing * size.z
	map._model(id, middle, yaw, {"far": 64.0})
	var color := AMBER if bench else BLUE
	var word := map.lettering(BENCH_WORD if bench else GEAR_WORD, front + Vector3(0, size.y + 0.17, 0) - facing * 0.06, 30, color)
	word.rotation.y = yaw
	# (Before a bright wall of panels the word needs a dark rim to be read.)
	word.outline_size = 12
	word.outline_modulate = Color(0.02, 0.025, 0.03, 0.95)
	var station := {
		"kind": kind, "title": BENCH_WORD if bench else GEAR_WORD, "pos": front, "color": color, "sign": word,
		"look": look, "stand": front + facing * 0.85, "facing": facing, "outpost": false
	}
	if not bench:
		station["tab"] = str(spec.tab)
		station["view"] = {"position": front + facing * 1.75 + Vector3(0, 1.5, 0), "target": middle + Vector3(0, size.y * 0.56, 0)}
	station.merge(more, true)
	map.stations.append(station)
	return station

## The stations between the supply points, into the finished rooms of the map.
static func furnish(map: HiveMap) -> void:
	var kept_state := map.random.state
	var kept_batch: MeshBatch = map.batch
	for spec: Array in SITES:
		if not map.room_of.has(str(spec[1])):
			continue
		var room: Dictionary = map.room_of[str(spec[1])]
		var side: int = spec[2]
		var into := Vector3(-HiveCore.OUT[side].x, 0, -HiveCore.OUT[side].y)
		map._begin_zone(str(room.zone))
		map._chunk("Stations", false)
		var sum := Vector3.ZERO
		var count := 0
		for unit: Array in spec[3]:
			var back := map._face_point(room, side, float(unit[1]), 0.0, -(float(spec[4]) if spec.size() > 4 else GAP))
			var made := put(map, str(unit[0]), back, into, {"site": str(spec[0]), "room": str(spec[1]), "side": side, "along": float(unit[1]), "outpost": true})
			if not made.is_empty() and not wall_free(map, made):
				push_warning("HiveStations: no plain wall behind '%s' in '%s' at %.1f" % [unit[0], spec[1], float(unit[1])])
			if not made.is_empty():
				sum += back
				count += 1
		# A lamp of its own, so that one finds it.
		if count > 0:
			var lamp := map._light(sum / count + into * 1.6 + Vector3(0, minf(2.7, float(room.height) - 0.5), 0), Color("e9f1ff"), 1.25, 7.5, false, 0.0, 0.3, 60.0)
			lamp.omni_attenuation = 1.1
		map._end_zone()
	map.batch = kept_batch
	map.random.state = kept_state

## Whether the wall behind a station between the supply points is wall: no door, no
## window and no terminal is in it.
static func wall_free(map: HiveMap, station: Dictionary) -> bool:
	if not station.has("side") or not map.room_of.has(str(station.get("room", ""))):
		return true
	var half := size_of(map, str(station.look)).x * 0.5
	return map._wall_free(map.room_of[str(station.room)], int(station.side), float(station.along) - half + 0.12, float(station.along) + half - 0.12)

## The stations between the supply points, as the game knows them.
static func outposts(map: CabinMap) -> Array:
	var out: Array = []
	for station in map.stations:
		if station.get("outpost", false):
			out.append(station)
	return out

# ---------------------------------------------------------------- pictures

## --stations-check: every station between the supply points in its room (place_...), the
## workbench of each supply point (supply_...), and the screens: an equipment station's
## lists, and the workbench with a rare weapon in hand (screen_...).
## --stations-part=<text>[,<more>]: only the places whose name contains one of them.
static func pictures(game: Node3D) -> void:
	var folder: String = game._capture_dir()
	var tree: SceneTree = game.get_tree()
	var part := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stations-part="):
			part = arg.trim_prefix("--stations-part=")
	await tree.create_timer(1.0).timeout
	game.profile.mission = 2
	game.intro_skipped = true
	game.start_run()
	var hive: HiveDirector = game.hive
	var map: HiveMap = hive.map
	hive.set_process(false)
	hive.prowl.set_process(false)
	hive.caches.set_process(false)
	for node in game.enemies.get_children():
		node.queue_free()
	game.alive_count = 0
	for id in map.areas:
		map.unlock(str(id), true)
	for mate in game.team:
		mate.hide()
		mate.set_physics_process(false)
		mate.global_position = Vector3(0, 0.05, 80)
	if is_instance_valid(hive.nadja):
		hive.nadja.hide()
		hive.nadja.set_physics_process(false)
		hive.nadja.global_position = Vector3(2, 0.05, 80)
	if is_instance_valid(hive.heli):
		hive.heli.hide()
	hive._end_intro()
	await tree.create_timer(1.2).timeout
	game.hud.play_ui.hide()
	var index := 0
	var seen := {}
	for station in map.stations:
		var name := str(station.get("site", ""))
		var kind := str(station.kind)
		if kind not in ["upgrade", "gear"] or seen.has(name):
			continue
		var asked := part == ""
		for text in part.split(",", false):
			asked = asked or name.contains(text) or (name == "" and "supply".contains(text))
		var facing: Vector3 = station.get("facing", Vector3.ZERO)
		if facing == Vector3.ZERO:
			continue
		index += 1
		if name != "":
			seen[name] = true
		if not asked:
			continue
		# The middle of everything that stands at this place.
		var middle: Vector3 = station.pos
		var others := 1
		for other in map.stations:
			if other != station and name != "" and str(other.get("site", "")) == name:
				middle += other.pos
				others += 1
		middle /= others
		var along := Vector3(-facing.z, 0, facing.x)
		var title := "place_%02d_%s" % [index, name] if name != "" else "supply_%02d" % index
		print("STATION %s kind=%s look=%s at=%s room=%s" % [title, kind, str(station.look), str((station.pos as Vector3).snappedf(0.01)), str(map.room_at(middle + facing * 0.8 + Vector3(0, 0.3, 0)).get("id", ""))])
		var from := _free_spot(map, middle + facing * 4.4 + along * 1.6, middle + facing * 1.0)
		await game._shot_at(folder, title + ".png", from, middle + Vector3(0, 1.25, 0), 0.5)
		# --stations-above: and from under the ceiling, to see how it stands in its room.
		if "--stations-above" in OS.get_cmdline_user_args():
			var high := minf(3.6, float(map.room_at(middle + facing * 0.8 + Vector3(0, 0.3, 0)).get("height", 4.0)) - 0.3)
			await game._capture_from(folder, title + "_above.png", middle + facing * 3.2 + Vector3(0, high, 0), middle + Vector3(0, 0.6, 0), 80.0)
			await game._capture_from(folder, title + "_along.png", middle + facing * 1.9 - along * 2.4 + Vector3(0, 1.7, 0), middle + Vector3(0, 1.0, 0) - facing * 0.3, 80.0)
		# And as one comes upon it: from further off, along the wall.
		if name != "":
			from = _free_spot(map, middle + facing * 3.0 + along * -7.5, middle + facing * 1.0)
			await game._shot_at(folder, title + "_far.png", from, middle + Vector3(0, 1.3, 0), 0.4)
	if part == "" or part.contains("screen"):
		await _screens(game, map, folder)
	print("STATIONS_CHECK COMPLETE places=%d" % SITES.size())
	tree.quit()

## A spot one can stand on near `wish`: that, or what the way from `anchor` to it reaches.
static func _free_spot(map: HiveMap, wish: Vector3, anchor: Vector3) -> Vector3:
	var level := map.level_of(anchor + Vector3(0, 0.3, 0))
	var grid: AStarGrid2D = map.navigation[level]
	var from := wish
	for step in range(12):
		var spot := anchor.lerp(wish, 1.0 - step / 12.0)
		var cell := Vector2i(roundi(spot.x / CabinMap.CELL), roundi(spot.z / CabinMap.CELL))
		if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
			from = spot
			break
	return from

static func _screens(game: Node3D, map: HiveMap, folder: String) -> void:
	var tree: SceneTree = game.get_tree()
	var player: Survivor = game.player
	game.hud.play_ui.show()
	game.credits = 2400
	game.wave = 6
	player.unlock("g36")
	game.hive.caches.make_rare("g36", {"damage": 0.12, "parts": ["reddot"]})
	player.equip_weapon("g36", true)
	var taken := {}
	for station in outposts(map):
		var look := str(station.look)
		if taken.has(look):
			continue
		taken[look] = true
		var stand: Vector3 = station.stand
		var facing: Vector3 = station.facing
		game._place_player(stand + Vector3(0, 0.05, 0), rad_to_deg(atan2(facing.x, facing.z)), -4.0)
		await tree.create_timer(0.5).timeout
		game.hud.banner_left = 0
		game.hud.radio_left = 0
		await game._capture(folder, "screen_%s_0_prompt.png" % look)
		game.interact()
		await tree.create_timer(0.9).timeout
		if str(station.kind) == "upgrade":
			game.hud.counter.pick("bench", "g36")
			await tree.create_timer(0.5).timeout
		await game._capture(folder, "screen_%s_1_open.png" % look)
		if look == "cabinet":
			game.hud._open_tab("use")
			await tree.create_timer(0.5).timeout
			await game._capture(folder, "screen_%s_2_use.png" % look)
		game.resume_run()
		await tree.create_timer(0.3).timeout
