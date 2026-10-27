extends RefCounted
## Mission two is simulated on the host. The guest builds the same layout and displays
## snapshots of its doors, objectives and friendly characters, without running another
## director or spawning another set of enemies.

var director: Node
var game: Node3D
var friends: Dictionary = {}
var task_stage := ""
var summary: Array[String] = []
var markers: Array = []

## Before a mission seals an arena, bring the human left outside to the one inside.
func gather(room_id: String = "", piece_id: String = "") -> void:
	if not game.net.hosting or not is_instance_valid(game.net.remote):
		return
	var inside := func(at: Vector3) -> bool:
		return str(director.map.room_at(at).get("id", "")) == room_id if room_id != "" else str(director.map.piece_at(at).get("id", "")) == piece_id
	var host_in: bool = inside.call(game.player.global_position)
	var guest_in: bool = inside.call(game.net.remote.global_position)
	if host_in == guest_in:
		return
	if host_in:
		game.net.place_partner(game.net.safe_near(game.player.global_position, room_id, piece_id))
	else:
		game.player.global_position = game.net.safe_near(game.net.remote.global_position, room_id, piece_id)
		game.player.velocity = Vector3.ZERO
		game.hud.flash(Color.BLACK, 0.5)

func _init(owner_director: Node) -> void:
	director = owner_director
	game = director.game

func clear() -> void:
	for entry: Dictionary in friends.values():
		if is_instance_valid(entry.body):
			entry.body.queue_free()
	friends.clear()
	task_stage = ""
	summary.clear()
	markers.clear()

## Either human can lead the way to the current objective. NPCs cannot trigger it.
func position_near(at: Vector3) -> Vector3:
	var here: Vector3 = game.player.global_position
	if game.net.hosting and is_instance_valid(game.net.remote) and not game.net.remote.down:
		var other: Vector3 = game.net.remote.global_position
		if game.player.down or (at != Vector3.INF and other.distance_squared_to(at) < here.distance_squared_to(at)):
			return other
	return here

func export_friends() -> Array:
	var bodies: Array = []
	for node in game.mates.get_children():
		if node is Teammate and not node.is_queued_for_deletion():
			bodies.append([str(node.get_instance_id()), node.look, node.global_position, node.rotation.y, node.velocity, node.down, node.lifted, node.health, node.max_health, game.team.has(node), node.visual.weapon_id if node.visual != null else ""])
	for entry: Dictionary in director.puppets:
		if is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion():
			bodies.append([str(entry.node.get_instance_id()), str(entry.look), entry.node.global_position, entry.node.rotation.y, Vector3.ZERO, false, 0.0])
	return bodies

func export_state() -> Dictionary:
	var map: HiveMap = director.map
	var doors := {}
	for id: String in map.door_of:
		var door: Dictionary = map.door_of[id]
		if str(door.kind) != "slide":
			doors[id] = not bool(door.shut)
	var moods := {}
	for id: String in map.zones:
		moods[id] = str(map.zones[id].mood)
	var bodies := export_friends()
	var task := {}
	var source: Dictionary = director.run.task
	if not source.is_empty():
		for key in ["kind", "state", "time", "event", "piece", "slot"]:
			if source.has(key):
				task[key] = source[key]
		for key in ["items", "places"]:
			var things: Array = []
			for item: Dictionary in source.get(key, []):
				things.append([item.pos, bool(item.get("taken", item.get("done", false))), bool(item.known)])
			task[key] = things
	return {"stage": director.stage, "time": director.stage_time, "checkpoint": director.checkpoint,
		"goal": director.goal, "marker": director.marker, "use_at": director.use_at,
		"use_key": director.use_key, "use_text": director.use_text,
		"progress": director.progress, "progress_text": director.progress_text,
		"summary": director.summary(false),"markers": director.markers(), "done": director.done,
		"doors": doors, "locked": map.locked, "moods": moods, "alarm": map.alarm_on,
		"forced": map.forced, "riding": map.riding, "crash": director.run.crash_id(),
		"friends": bodies, "task": task, "tokyo": director.tokyo_tasks.export() if director.tokyo_tasks != null else {}}

func adopt(state: Dictionary) -> void:
	if not game.net.joined or not director.on:
		return
	var map: HiveMap = director.map
	director.stage = str(state.stage)
	director.stage_time = float(state.time)
	if director.checkpoint != str(state.checkpoint):
		director.caches.keep(str(state.checkpoint))
	director.checkpoint = str(state.checkpoint)
	director.goal = str(state.goal)
	director.marker = state.marker
	director.use_at = state.use_at
	director.use_key = str(state.use_key)
	director.use_text = str(state.use_text)
	director.progress = float(state.progress)
	director.progress_text = str(state.progress_text)
	director.done = state.done
	summary.assign(state.summary)
	markers = state.markers
	for id: String in state.locked:
		if bool(map.locked.get(id, false)) != bool(state.locked[id]):
			if bool(state.locked[id]):
				map.lock(id)
			else:
				map.unlock(id)
	for id: String in state.doors:
		if map.door_open(id) != bool(state.doors[id]):
			if map.areal_signs.has(id):
				map.set_port(id, bool(state.doors[id]))
			else:
				map.set_door(id, bool(state.doors[id]))
	for id: String in state.moods:
		if map.zones.has(id) and str(map.zones[id].mood) != str(state.moods[id]):
			map.set_zone_mood(id, str(state.moods[id]))
	if map.alarm_on != bool(state.alarm):
		map.set_alarm(bool(state.alarm))
	if map.riding != bool(state.riding):
		if str(state.crash) != "":
			map.ride_areal(str(state.crash), bool(state.riding))
		else:
			map.ride(bool(state.riding))
	if map.forced != state.forced:
		map.forced = state.forced.duplicate()
		map._show_zones()
	_adopt_friends(state.friends)
	_adopt_task(state.task)
	if director.tokyo_tasks != null and state.has("tokyo"):
		director.tokyo_tasks.adopt(state.tokyo)

func _adopt_friends(bodies: Array) -> void:
	var seen := {}
	for data: Array in bodies:
		var id := str(data[0])
		seen[id] = true
		if not friends.has(id):
			var body := SoldierVisual.new()
			body.look = str(data[1])
			game.mates.add_child(body)
			body.ally_outline()
			body.global_position = data[2]
			friends[id] = {"body": body, "at": data[2], "yaw": data[3], "velocity": data[4], "down": false}
		var entry: Dictionary = friends[id]
		(entry.body as SoldierVisual).visible = director.intro_left <= 0.0 and game.story.intro_left <= 0.0
		entry.at = data[2]
		entry.yaw = float(data[3])
		entry.velocity = data[4]
		entry.lifted = float(data[6])
		entry.health = float(data[7]) if data.size() > 7 else 100.0
		entry.maximum = float(data[8]) if data.size() > 8 else 100.0
		entry.in_team = bool(data[9]) if data.size() > 9 else false
		# (A companion that took up another weapon at a counter carries it here too.)
		if data.size() > 10 and str(data[10]) != "" and str(data[10]) != (entry.body as SoldierVisual).weapon_id:
			(entry.body as SoldierVisual).swap_weapon(str(data[10]))
		if bool(data[5]) != bool(entry.down):
			entry.down = bool(data[5])
			(entry.body as SoldierVisual).ally_outline(bool(entry.down))
			if entry.down:
				(entry.body as SoldierVisual).fall()
				game.hud.teammate_down(str((entry.body as SoldierVisual).config.label))
			else:
				(entry.body as SoldierVisual).settle()
	for id: String in friends.keys():
		if not seen.has(id):
			(friends[id].body as Node).queue_free()
			friends.erase(id)

func move_friends(delta: float) -> void:
	for entry: Dictionary in friends.values():
		var body: SoldierVisual = entry.body
		# A train/lift changes rooms instantly; walking is interpolated.
		if body.global_position.distance_to(entry.at) > 12.0:
			body.global_position = entry.at
		else:
			body.global_position = body.global_position.lerp(entry.at, minf(1.0, delta * 12.0))
		body.rotation.y = lerp_angle(body.rotation.y, float(entry.yaw), minf(1.0, delta * 12.0))
		body.animate(delta, entry.velocity, false, false)

func _adopt_task(task: Dictionary) -> void:
	var run: HiveAreaRun = director.run
	if task.is_empty():
		if not run.task.is_empty():
			run.props.clear()
		run.task = {}
		task_stage = ""
		return
	if task_stage != director.stage or (str(run.task.get("state", "reach")) == "reach" and str(task.state) != "reach"):
		run.props.clear()
		run.task = task.duplicate(true)
		if str(task.state) != "reach":
			var laid := HiveAreaRun.lay_props(run.props, director.map, task.piece, task.event)
			run.task.items = laid.items
			run.task.places = laid.places
		else:
			run.task.items = []
			run.task.places = []
		task_stage = director.stage
	run.task.state = str(task.state)
	for key in ["items", "places"]:
		var local: Array = run.task.get(key, [])
		var states: Array = task.get(key, [])
		for index in range(mini(local.size(), states.size())):
			var item: Dictionary = local[index]
			item.known = bool(states[index][2])
			var flag := "taken" if key == "items" else "done"
			if bool(states[index][1]) and not bool(item.get(flag, false)):
				item[flag] = true
				if key == "items" and is_instance_valid(item.node):
					(item.node as Node).queue_free()
				elif key == "places":
					run.props.place_done(item.node)

## On the guest, find the item beside that player, even if the host is at another one.
func nearby_use() -> Dictionary:
	var here: Vector3 = game.player.global_position
	var focused: Dictionary = director.run.focused_use()
	if not focused.is_empty():
		return focused
	if director.use_key in ["g_item", "g_switch", "g_slot", "g_hack"]:
		return {}
	if director.use_at != Vector3.INF and here.distance_to(director.use_at) < 2.6:
		var device: Node3D = director.map.interaction_devices.get(director.use_key)
		if device != null:
			if not game.aims_at_object(device):
				return {}
			return {"key": director.use_key, "at": director.use_at, "text": director.use_text, "node": device}
		return {"key": director.use_key, "at": director.use_at, "text": director.use_text}
	return {}

func fallen_nearby() -> Dictionary:
	if not game.net.joined:
		return {}
	for entry: Dictionary in friends.values():
		if bool(entry.down) and game.player.global_position.distance_to(entry.at) < 2.8:
			return entry
	return {}

func help_from_partner(delta: float) -> void:
	if not is_instance_valid(game.net.remote):
		return
	for node in game.mates.get_children():
		if node is Teammate and node.down and node.global_position.distance_to(game.net.remote.global_position) < 2.8:
			if node.lift(delta):
				game.stats.revives += 1
				game.net.remote.assisted += 1
			return
