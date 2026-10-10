class_name HiveEntriesCheck
extends Node
## Picture check of the ways in of the second mission (see HiveEntries):
##   --entries-check --capture-dir=<folder>
##       a picture of every way in, as the survivor sees it from a few metres away
##       (--entries-part=<text>: only those whose name contains it), and a line ENTRY for each
##   --entries-check --entries-film=<name or number>[,<more>] [--entries-kind=mauler[,<more>]]
##       somebody comes through that way in: pictures from the warning to the first steps
##       (with several kinds, the first film shows the first of them, and so on;
##       --entries-eyes: as the survivor sees it, his weapon in the picture)
##   --entries-check --entries-sweep   (runs --headless too)
##       no pictures: somebody comes through every way in in turn, of every kind that
##       can, the survivor a few metres off. A line SWEEP for each that did not get going
##       afterwards, and a line ENTRIES_SWEEP with the numbers. (--entries-shift=<n>:
##       the kinds are dealt out n places further on, so that other pairs meet.)
## Nothing attacks otherwise, every door stands open, the squad is out of the picture.

var entries: HiveEntries
var game: Node3D
var map: HiveMap

func run() -> void:
	game = entries.game
	var folder: String = game._capture_dir()
	var part := ""
	var films: PackedStringArray = []
	var kinds: PackedStringArray = ["mauler"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--entries-part="):
			part = arg.trim_prefix("--entries-part=")
		elif arg.begins_with("--entries-film="):
			films = arg.trim_prefix("--entries-film=").split(",")
		elif arg.begins_with("--entries-kind="):
			kinds = arg.trim_prefix("--entries-kind=").split(",")
	await get_tree().create_timer(1.0).timeout
	game.profile.mission = 2
	game.intro_skipped = true
	game.start_run()
	map = game.cabin as HiveMap
	var hive: HiveDirector = game.hive
	hive.set_process(false)
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
	await get_tree().create_timer(1.2).timeout
	game.hud.play_ui.hide()
	game.hud.banner_left = 0
	game.hud.radio_left = 0
	for index in range(map.entries.size()):
		var entry: Dictionary = map.entries[index]
		print("ENTRY %d %s kind=%s at=%s land=%s seconds=%.2f" % [index, entry.id, entry.kind, str((entry.at as Vector3).snapped(Vector3.ONE * 0.01)), str(entry.land), entries.seconds(index) if entry.land != Vector3.INF else -1.0])
	if "--entries-sweep" in OS.get_cmdline_user_args():
		await _sweep(part)
		get_tree().quit()
		return
	if films.is_empty():
		for index in range(map.entries.size()):
			var entry: Dictionary = map.entries[index]
			if part != "" and not str(entry.id).contains(part):
				continue
			var view := _view(entry, 4.6, 1.5)
			await game._shot_at(folder, "way_%03d_%s.png" % [index, entry.id], view[0], view[1], 0.35)
	for number in range(films.size()):
		var index := _index(films[number])
		if index < 0:
			print("ENTRIES no way in called ", films[number])
			continue
		await _film(folder, index, kinds[number % kinds.size()])
	print("ENTRIES_CAPTURE_COMPLETE ways=%d" % map.entries.size())
	get_tree().quit()

## Somebody comes through every way in (whose name contains `part`), each of another
## kind than the one before; two and a half seconds later he has to be on his way to the
## survivor or at him.
func _sweep(part: String) -> void:
	var player: Survivor = game.player
	var tried := 0
	var stuck := 0
	var longest := 0.0
	var shift := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--entries-shift="):
			shift = int(arg.trim_prefix("--entries-shift="))
	Engine.time_scale = 3.0
	for index in range(map.entries.size()):
		var entry: Dictionary = map.entries[index]
		if part != "" and not str(entry.id).contains(part):
			continue
		tried += 1
		if entry.land == Vector3.INF:
			stuck += 1
			print("SWEEP %s: no ground to come down on" % entry.id)
			continue
		var stand: Vector3 = _view(entry, 7.5, 2.5)[0]
		game._place_player(stand + Vector3(0, 0.05, 0), 0.0)
		player.health = 100.0
		await get_tree().physics_frame
		await get_tree().physics_frame
		var kind: String = HiveEntries.KINDS[(index + shift) % HiveEntries.KINDS.size()]
		var comer: Infected = entries.come(index, kind)
		if comer == null:
			stuck += 1
			print("SWEEP %s: nobody came" % entry.id)
			continue
		var steps := 0
		while is_instance_valid(comer) and comer.entering != null and steps < 300:
			await get_tree().physics_frame
			steps += 1
		longest = maxf(longest, steps / 60.0 * Engine.time_scale)
		var from: Vector3 = comer.global_position if is_instance_valid(comer) else entry.land
		var off: float = from.distance_to(entry.land)
		await get_tree().create_timer(2.5).timeout
		# (One that blew itself up at him, or hangs on him, got there.)
		var got_going := not is_instance_valid(comer) or comer.dead or comer.clung_to != null
		if not got_going:
			got_going = comer.global_position.distance_to(from) > 1.5 or comer.global_position.distance_to(player.global_position) < 3.0
		# (A Medic that sees him stops a good way off and lets its gas work: that is where it wants to be.)
		if not got_going and kind == "healer":
			got_going = comer.global_position.distance_to(player.global_position) < Infected.CLOUD_KEEP
		if steps >= 300 or off > 0.6 or not got_going:
			stuck += 1
			print("SWEEP %s (%s): carried for %d steps, let go %.1f m from its ground, %s" % [entry.id, kind, steps, off, "then on its way" if got_going else "then stood where it was, %.1f m from the survivor at %s" % [comer.global_position.distance_to(player.global_position), str(stand.snapped(Vector3.ONE * 0.1))]])
		for node in game.enemies.get_children():
			node.queue_free()
		game.alive_count = 0
		player.health = 100.0
		await get_tree().physics_frame
	Engine.time_scale = 1.0
	print("ENTRIES_SWEEP ways=%d stuck=%d longest=%.2f state=%s" % [tried, stuck, longest, game.state])

func _index(text: String) -> int:
	if text.is_valid_int():
		return int(text) if int(text) < map.entries.size() else -1
	for index in range(map.entries.size()):
		if str(map.entries[index].id) == text:
			return index
	for index in range(map.entries.size()):
		if str(map.entries[index].id).contains(text):
			return index
	return -1

## What the eye is drawn to at a way in.
func _mark(entry: Dictionary) -> Vector3:
	var at: Vector3 = entry.at
	match str(entry.kind):
		"drop":
			return at + Vector3(0, -0.5, 0)
		"hole":
			return at + Vector3(0, 0.75, 0)
		"duct":
			return at + Vector3(0, 0.3, 0)
		"window":
			return at + Vector3(0, 0.9, 0)
	return at + Vector3(0, 0.2, 0)

## Where to stand to look at a way in: free ground about `far` metres before it and
## `aside` to its side, from which it can be seen. Returns [feet, what to look at].
func _view(entry: Dictionary, far: float, aside: float) -> Array:
	var land: Vector3 = entry.land if entry.land != Vector3.INF else entry.wish
	var out: Vector3 = entry.out
	var mark := _mark(entry)
	if entry.has("view"):
		return [entry.view, mark]
	if out == Vector3.ZERO:
		var room: Dictionary = map.room_of.get(str(entry.room), {})
		var middle := land + Vector3(0, 0, 1)
		if not room.is_empty():
			middle = Vector3((room.outer as Rect2).get_center().x, land.y, (room.outer as Rect2).get_center().y)
		out = Vector3(middle.x - land.x, 0, middle.z - land.z)
		out = Vector3(0, 0, 1) if out.length() < 0.5 else out.normalized()
		# (A passage: along it.)
		if not room.is_empty() and absf((room.outer as Rect2).size.x - (room.outer as Rect2).size.y) > 12.0:
			out = Vector3(1, 0, 0) if (room.outer as Rect2).size.x > (room.outer as Rect2).size.y else Vector3(0, 0, 1)
	var level: int = map.level_of(land + Vector3(0, 0.3, 0))
	var space := map.get_world_3d().direct_space_state
	var best := land + out * 2.0
	for step in range(12):
		var reach := far - step * 0.3
		for turn in [1.0, -1.0, 0.0]:
			var wanted: Vector3 = land + out * reach + out.cross(Vector3.UP) * aside * float(turn)
			var cell: Vector2i = map._free_near(level, Vector2(wanted.x, wanted.z), 2)
			if cell.x > 99999:
				continue
			var feet := Vector3(cell.x * CabinMap.CELL, land.y, cell.y * CabinMap.CELL)
			var query := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.62, 0), mark + (feet - mark).normalized() * 0.4, 1)
			if space.intersect_ray(query).is_empty():
				return [feet, mark]
			best = feet
	return [best, mark]

## Somebody comes through: a picture before, one in the warning, then every tenth of a second.
func _film(folder: String, index: int, kind: String) -> void:
	var entry: Dictionary = map.entries[index]
	var view := _view(entry, 4.4, 1.6)
	var from: Vector3 = view[0]
	var aim: Vector3 = (view[1] as Vector3) + Vector3(0, 0.2, 0)
	if str(entry.kind) in ["drop", "duct"] and entry.land != Vector3.INF:
		aim.y = ((entry.at as Vector3).y + (entry.land as Vector3).y) * 0.5 + 0.2
	var line: Vector3 = aim - (from + Vector3(0, 1.62, 0))
	game._place_player(from + Vector3(0, 0.05, 0), rad_to_deg(atan2(-line.x, -line.z)), rad_to_deg(atan2(line.y, Vector2(line.x, line.z).length())))
	game.player.set_physics_process(false)
	# A camera of its own where his eyes are: a little nearer, and without his weapon in the way.
	var eye: Camera3D = null
	if not "--entries-eyes" in OS.get_cmdline_user_args():
		eye = Camera3D.new()
		eye.cull_mask = 1
		eye.fov = 48.0
		game.add_child(eye)
		eye.global_position = from + Vector3(0, 1.62, 0)
		eye.look_at(aim)
		eye.current = true
	await get_tree().create_timer(0.8).timeout
	# Slowly, so that the pictures are taken when they are meant to be.
	Engine.time_scale = 0.2
	var tag := "film_%s_%s" % [entry.id, kind]
	await game._capture(folder, "%s_0.png" % tag)
	entries.announce(index, kind)
	var took := 0.0
	var shot := 1
	for wait in [0.4, 0.34, 0.1, 0.1, 0.1, 0.1, 0.1, 0.12, 0.14, 0.2, 0.3]:
		await get_tree().create_timer(float(wait)).timeout
		took += float(wait)
		await game._capture(folder, "%s_%d.png" % [tag, shot])
		var body: Infected = null
		for node in game.enemies.get_children():
			if node is Infected and not (node as Infected).dead:
				body = node
		print("FILM %s shot %d at %.2f body=%s carried=%s" % [tag, shot, took, str(body.global_position.snapped(Vector3.ONE * 0.01)) if body != null else "-", str(body.entering != null) if body != null else "-"])
		shot += 1
	Engine.time_scale = 1.0
	for node in game.enemies.get_children():
		node.queue_free()
	game.alive_count = 0
	game.player.set_physics_process(true)
	if eye != null:
		game.player.camera.current = true
		eye.queue_free()
	await get_tree().create_timer(0.3).timeout
