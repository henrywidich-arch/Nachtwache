extends SceneTree
## Mission one: can a player who stands by a body or a server and looks at what blinks
## there take the access code / drive with [E]? (Since v0.68 [E] has to be aimed.)
##   Godot --headless --path <project> -s res://tools/pickup_aim_check.gd
## It also shows how the same looks would have fared with the old, empty aim boxes.

const Focus = preload("res://scripts/interaction_focus.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _aimed(game: Node3D, prop: Node3D, eye_from: Vector3, look_at: Vector3) -> bool:
	game.player.position = eye_from
	game.player.velocity = Vector3.ZERO
	await _frames(8)
	game.player.camera.look_at(look_at)
	return game.aims_at_object(prop)

## Aims from `stands` at each of `looks`; returns [hits now, hits with the old box, tries].
func _tries(game: Node3D, prop: Node3D, stands: Array, looks: Array) -> Array:
	var now := 0
	var old := 0
	var tries := 0
	var kept: AABB = prop.get_meta("interaction_bounds")
	for stand in stands:
		for look in looks:
			tries += 1
			prop.set_meta("interaction_bounds", kept)
			if await _aimed(game, prop, stand, look):
				now += 1
			prop.remove_meta("interaction_bounds")
			if game.aims_at_object(prop):
				old += 1
	prop.set_meta("interaction_bounds", kept)
	return [now, old, tries]

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.check_mode = true
	root.add_child(game)
	game.profile.mission = 1
	game.profile.mode = "story"
	await _frames(5)
	game.start_run()
	game.mission.plain()
	game.mission.sighting_left = 99999.0
	game.preparation_left = 9999.0
	await _frames(10)
	var mission: MissionDirector = game.mission
	# --- the dead in the yard and upstairs
	var codes: Dictionary = mission._start_task("codes")
	codes.brief = 0.0
	mission.update(0.05)
	for i in range(codes.items.size()):
		var item: Dictionary = codes.items[i]
		var prop: Node3D = mission.props["%d:%d" % [int(codes.id), i]]
		var pos: Vector3 = item.pos
		var tag: Vector3 = (prop.get_node("Tag") as Node3D).global_position
		var stands: Array = []
		for turn in range(4):
			stands.append(pos + Vector3(1.4, 0.3, 0).rotated(Vector3.UP, turn * PI * 0.5 + 0.4))
		var result: Array = await _tries(game, prop, stands, [tag, pos + Vector3(0, 0.2, 0)])
		print("BODY %d at %s: aimed %d/%d now, %d/%d before" % [i, str(pos), result[0], result[2], result[1], result[2]])
		if int(result[0]) < int(result[2]) - 1:
			failures += 1
		# And taken with one press.
		game.player.position = stands[0]
		await _frames(8)
		game.player.camera.look_at(tag)
		var took: bool = mission.interact()
		print("  [E] takes it: %s (%s)" % [str(took and bool(item.done)), mission.prompt()])
		if not (took and bool(item.done)):
			failures += 1
	# --- the servers down in the lab
	var drives: Dictionary = mission._start_task("drives")
	drives.brief = 0.0
	mission.update(0.05)
	for i in range(drives.items.size()):
		var item: Dictionary = drives.items[i]
		var prop: Node3D = mission.props["%d:%d" % [int(drives.id), i]]
		var server := int(prop.get_meta("server", -1))
		var pos: Vector3 = item.pos
		var bay: Vector3 = game.cabin.servers[server].bay if server >= 0 else pos + Vector3(0, 1.2, 0)
		var tag: Vector3 = (prop.get_node("Tag") as Node3D).global_position
		var back := Vector3(0, 0, 0.6).rotated(Vector3.UP, float(item.yaw))
		var stands: Array = [pos + Vector3(0, 0.05, 0), pos + back + Vector3(0, 0.05, 0), pos + back + back.rotated(Vector3.UP, PI * 0.5) * 0.6 + Vector3(0, 0.05, 0)]
		var result: Array = await _tries(game, prop, stands, [bay, tag])
		print("SERVER %d (rack %d) at %s: aimed %d/%d now, %d/%d before" % [i, server, str(pos), result[0], result[2], result[1], result[2]])
		if int(result[0]) < int(result[2]) - 1:
			failures += 1
		game.player.position = stands[0]
		await _frames(8)
		game.player.camera.look_at(bay)
		var near: Array = mission.nearest_item(true)
		print("  [E] would act on it: %s (%s)" % [str(not near.is_empty() and near[0] == drives and int(near[1]) == i), mission.prompt()])
		if near.is_empty():
			failures += 1
	print("PICKUP_AIM_RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
