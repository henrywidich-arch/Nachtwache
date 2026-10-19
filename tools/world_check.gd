extends SceneTree
## Checks the open world (scenes/world.tscn): its data loads, the ground that is drawn and
## the ground that is walked on agree, someone set down at the start stands on it and can
## walk, the foliage grows around them and none of it in the water.
##
##   Godot --headless --path . -s res://tools/world_check.gd
##   Godot --path . -s res://tools/world_check.gd -- --shots   (needs graphics: also saves
##       pictures from a few places to tools/ui_review/world/)

const SHOTS := [
	# name, eye, looking at, time of day
	["start", Vector3.INF, Vector3.ZERO, "abend"],
	["start_noon", Vector3.INF, Vector3.ZERO, "mittag"],
	["hills", Vector3(-900, 160, 900), Vector3(200, 40, -200), "mittag"],
	["overview", Vector3(-1500, 420, 1500), Vector3(0, 60, 0), "mittag"],
	["mountains", Vector3(300, 140, -300), Vector3(1000, 160, -1000), "morgen"],
	["forest", Vector3.INF, Vector3.ZERO, "mittag"],
	["river", Vector3.INF, Vector3.ZERO, "abend"],
	["lake", Vector3.INF, Vector3.ZERO, "mittag"],
	["night", Vector3.INF, Vector3.ZERO, "nacht"],
]

var failures := 0
var world: OpenWorld

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok:
		failures += 1

func _run() -> void:
	world = (load("res://scenes/world.tscn") as PackedScene).instantiate() as OpenWorld
	root.add_child(world)
	for i in range(3):
		await process_frame
	var info := world.info
	_check(world.heights.size() == world.samples * world.samples, "the height map has %d x %d samples" % [world.samples, world.samples])
	_check(world.size >= 3000.0, "the world is %.0f m wide" % world.size)
	_check((info.rivers as Array).size() >= 6 and (info.lakes as Array).size() >= 1, "%d rivers and %d lakes" % [(info.rivers as Array).size(), (info.lakes as Array).size()])
	_check(world.trees > 30000, "%d trees" % world.trees)
	_check(world.height_high - world.height_low > 120.0, "hills and mountains rise %.0f m over the lowest land" % (world.height_high - world.height_low))
	# The drawn ground (height_at, as the shader reads it) and the collision agree.
	var space := world.get_world_3d().direct_space_state
	var worst := 0.0
	var dice := RandomNumberGenerator.new()
	dice.seed = 4
	for i in range(200):
		var x := dice.randf_range(-1500, 1500)
		var z := dice.randf_range(-1500, 1500)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 600, z), Vector3(x, -100, z)))
		if hit.is_empty():
			worst = INF
			break
		worst = maxf(worst, absf((hit.position as Vector3).y - world.height_at(x, z)))
	_check(worst < 0.15, "the collision lies on the drawn ground (worst %.3f m)" % worst)
	# Someone at the start stands on the ground and walks off.
	var explorer := world.explorer
	for i in range(30):
		await physics_frame
	var ground := world.height_at(explorer.global_position.x, explorer.global_position.z)
	_check(explorer.is_on_floor() and absf(explorer.global_position.y - ground) < 0.3, "the explorer stands on the ground at the start (%.2f m above)" % (explorer.global_position.y - ground))
	_check(not world.under_water(explorer.global_position.x, explorer.global_position.y, explorer.global_position.z), "the start is on dry land")
	var from := explorer.global_position
	explorer.velocity = Vector3.ZERO
	for i in range(90):
		explorer.velocity.x = 4.0
		explorer.move_and_slide()
		await physics_frame
	_check(explorer.global_position.distance_to(from) > 3.0, "the explorer can walk (%.1f m in 1.5 s)" % explorer.global_position.distance_to(from))
	# Foliage grows all around and nothing of it stands in water.
	for i in range(200):
		await process_frame
	var foliage := world.foliage
	var grown := 0
	var wet := 0
	for cell: Node3D in foliage.cells.values():
		grown += int(cell.get_meta("plants", 0))
		for at: Vector3 in cell.get_meta("probe", PackedVector3Array()):
			if world.under_water(at.x, at.y, at.z):
				wet += 1
	_check(foliage.cells.size() > 60, "%d foliage cells grow around the explorer" % foliage.cells.size())
	_check(grown > 20000, "%d plants, stones and sticks on the ground near the start" % grown)
	_check(wet == 0, "no foliage stands in water (%d found)" % wet)
	# The terrain draws few patches and is detailed near the eye.
	_check(world.terrain.multimesh.visible_instance_count < OpenWorld.MAX_PATCHES, "%d terrain patches are drawn" % world.terrain.multimesh.visible_instance_count)
	if "--shots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _shots()
	print("WORLD_CHECK_RESULT: failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/ui_review/world"))
	var explorer := world.explorer
	explorer.set_physics_process(false)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for shot in SHOTS:
		if only != "" and not (shot[0] as String) in only.split(","):
			continue
		var eye: Vector3 = shot[1]
		var target: Vector3 = shot[2]
		if eye == Vector3.INF:
			var spot := _find_spot(shot[0])
			eye = spot[0]
			target = spot[1]
		if eye.y == 0:
			eye.y = world.height_at(eye.x, eye.z)
		else:
			eye.y = maxf(eye.y, world.height_at(eye.x, eye.z) + 2.0)
		world.set_time(shot[3])
		explorer.global_position = eye
		explorer.velocity = Vector3.ZERO
		var camera := explorer.camera
		camera.global_position = eye + Vector3(0, WorldExplorer.EYE, 0)
		camera.look_at(Vector3(target.x, target.y if target.y != 0 else world.height_at(target.x, target.z) + 1.5, target.z))
		for i in range(90):
			await process_frame
		var picture := root.get_texture().get_image()
		picture.save_png("res://tools/ui_review/world/%s.png" % shot[0])
		print("SHOT %s at %s: %.1f M triangles, %d draw calls, %.1f ms CPU frame" % [shot[0], eye,
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	explorer.camera.position = Vector3.ZERO

## A place in a forest, or on the bank of a river, looking along it.
func _find_spot(kind: String) -> Array:
	if kind in ["start", "start_noon", "night"]:
		var start: Array = world.info.start
		return [Vector3(float(start[0]), 0, float(start[2])), Vector3(float(start[0]) + 250.0, 30.0, float(start[2]) - 250.0)]
	if kind == "lake":
		# On the shore of the biggest lake, looking across it.
		var biggest: Dictionary = {}
		var most := 0.0
		for lake: Dictionary in world.info.lakes:
			var b: Array = lake.bounds
			var area := (float(b[2]) - float(b[0])) * (float(b[3]) - float(b[1]))
			if area > most:
				most = area
				biggest = lake
		var b: Array = biggest.bounds
		var middle := Vector3((float(b[0]) + float(b[2])) * 0.5, float(biggest.level), (float(b[1]) + float(b[3])) * 0.5)
		for i in range(1, 200):
			var at := middle + Vector3(0, 0, i * 3.0)
			if not world.under_water(at.x, world.height_at(at.x, at.z), at.z):
				return [Vector3(at.x, 0, at.z + 6.0), middle + Vector3(-40, 1.0, 0)]
		return [middle + Vector3(0, 0, 200), middle]
	if kind == "river":
		var longest: Array = []
		for river: Array in world.info.rivers:
			if river.size() > longest.size():
				longest = river
		var at: Array = longest[int(longest.size() * 0.6)]
		var ahead: Array = longest[int(longest.size() * 0.6) + 12]
		var along := Vector2(float(ahead[0]) - float(at[0]), float(ahead[1]) - float(at[1])).normalized()
		var side := Vector2(-along.y, along.x)
		var bank := Vector2(float(at[0]), float(at[1])) + side * (float(at[3]) * 0.5 + 4.0) - along * 10.0
		return [Vector3(bank.x, 0, bank.y), Vector3(float(ahead[0]), float(ahead[2]) + 0.5, float(ahead[1]))]
	var dice := RandomNumberGenerator.new()
	dice.seed = 9
	for i in range(4000):
		var x := dice.randf_range(-1300, 1300)
		var z := dice.randf_range(-1300, 1300)
		var ground := world.ground_at(x, z)
		if ground.g > 0.85 and ground.r < 0.1 and not world.under_water(x, world.height_at(x, z), z):
			return [Vector3(x, 0, z), Vector3(x + 30, 0, z - 20)]
	return [Vector3.ZERO, Vector3(10, 0, 10)]
