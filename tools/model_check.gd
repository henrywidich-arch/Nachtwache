extends SceneTree
## Model check: shows each new model playing clips the game really uses and saves
## one contact sheet per model (made for the pipeline that turns generated models into rigged ones; used for the Hive zombies).
## Run windowed (not headless):
##   Godot --path <project> --resolution 1000x700 -s res://tools/model_check.gd -- --out=<folder> [--kinds=a,b] [--looks=c,d] [--close] [--heads]
## --heads writes one sheet with a close-up of every listed model's head and chest instead (eyes, textures).
## --lineup writes lineup.png: all listed models side by side in their idle pose, with a line at 1 m and 2 m.
## --scan renders nothing: it steps through EVERY clip of the listed models ten times a second and prints how far
## the lowest point of the skinned mesh is from the ground (CHECKSCAN lines).
## Every tile is labelled with the clip, and with the lowest and highest point of the skinned
## mesh in metres (feet on the ground: lowest close to 0.00).
## --warm times InfectedVisual.warm_up (every kind of KINDS baked once, as the game does before its first round).
## --columns=N sets the number of tiles per row of a sheet (default 4).
## Phase 5: --plan=clip@0.5:view,clip@s:view,... replaces the clips shown for the listed kinds (position as a share
## of the clip's length, or "s" for the moment of the strike) and writes check_<kind>_plan.png. Views: front, side,
## back, high, low, and new: front_left, left (the character's left side, which front and side never show).

const TILE := Vector2i(500, 620)
var columns := 4

var viewport: SubViewport
var camera: Camera3D
var stage: Node3D
var caption: Label
var bar: MeshInstance3D
var out := "user://"
var cache := {}
var plan_override: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var kinds: Array = []
	var looks: Array = []
	var close := false
	var heads := false
	var scan := false
	var lineup := false
	var warm := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(",", false))
		elif arg.begins_with("--looks="):
			looks = Array(arg.trim_prefix("--looks=").split(",", false))
		elif arg.begins_with("--columns="):
			columns = int(arg.trim_prefix("--columns="))
		elif arg == "--warm":
			warm = true
		elif arg == "--close":
			close = true
		elif arg == "--heads":
			heads = true
		elif arg == "--scan":
			scan = true
		elif arg == "--lineup":
			lineup = true
		elif arg.begins_with("--plan="):
			for item in arg.trim_prefix("--plan=").split(",", false):
				var view := "front"
				var spot := "0.5"
				var clip: String = item
				if clip.contains(":"):
					view = clip.get_slice(":", 1)
					clip = clip.get_slice(":", 0)
				if clip.contains("@"):
					spot = clip.get_slice("@", 1)
					clip = clip.get_slice("@", 0)
				plan_override.append([clip, -1.0 if spot == "s" else float(spot), view])
	DirAccess.make_dir_recursive_absolute(out)
	_build_stage()
	for i in range(6):
		await process_frame
	if warm:
		# what the game does once before its first round: every kind gets its clips baked
		var started := Time.get_ticks_msec()
		InfectedVisual.warm_up(stage)
		print("CHECKWARM %d kinds, %d ms" % [InfectedVisual.KINDS.size(), Time.get_ticks_msec() - started])
		print("CHECK_COMPLETE")
		quit()
		return
	if lineup:
		await _lineup(kinds, looks)
		print("CHECK_COMPLETE")
		quit()
		return
	if scan:
		_scan(kinds, looks)
		print("CHECK_COMPLETE")
		quit()
		return
	if heads:
		await _check_heads(kinds, looks)
		print("CHECK_COMPLETE")
		quit()
		return
	for kind in kinds:
		if not InfectedVisual.KINDS.has(kind):
			print("CHECK unknown kind ", kind)
			continue
		await _check_infected(kind, close)
	for look in looks:
		if not SoldierVisual.LOOKS.has(look):
			print("CHECK unknown look ", look)
			continue
		await _check_soldier(look, close)
	print("CHECK_COMPLETE")
	quit()

# ---------------------------------------------------------------- stage

func _build_stage() -> void:
	viewport = SubViewport.new()
	viewport.size = TILE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.40, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 150, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -40, 0)
	fill.light_energy = 0.45
	stage.add_child(fill)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(9, 9)
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nvarying vec3 at;\nvoid vertex() { at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() { float c = mod(floor(at.x * 2.0) + floor(at.z * 2.0), 2.0); ALBEDO = mix(vec3(0.20, 0.21, 0.22), vec3(0.29, 0.30, 0.31), c); ROUGHNESS = 0.95; }\n"
	var floor_material := ShaderMaterial.new()
	floor_material.shader = shader
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.material_override = floor_material
	stage.add_child(ground)
	# A pole with a mark every half metre, and a bar at the height the model should have.
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.95, 0.85, 0.2)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.012, 2.5, 0.012)
		pole.mesh = box
		pole.material_override = paint
		pole.position = Vector3(side * 0.95, 1.25, 0)
		stage.add_child(pole)
		for step in range(1, 6):
			var mark := MeshInstance3D.new()
			var tick := BoxMesh.new()
			tick.size = Vector3(0.12 if step % 2 == 0 else 0.07, 0.008, 0.012)
			mark.mesh = tick
			mark.material_override = paint
			mark.position = Vector3(side * 0.95, step * 0.5, 0)
			stage.add_child(mark)
	bar = MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(1.9, 0.006, 0.006)
	bar.mesh = beam
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.25, 0.2)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar.material_override = red
	stage.add_child(bar)
	camera = Camera3D.new()
	camera.fov = 38
	camera.near = 0.05
	camera.far = 60
	stage.add_child(camera)
	camera.current = true
	caption = Label.new()
	caption.position = Vector2(8, 6)
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color(1, 1, 0.45))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption.add_theme_constant_override("outline_size", 5)
	viewport.add_child(caption)

func _view(name: String, height: float, close: bool, focus: Vector3 = Vector3.ZERO) -> void:
	var s := height / 1.8
	var target := Vector3(focus.x, 0.95 * s, focus.z)
	var distance := 4.0 * s
	if close:
		target = Vector3(0, 1.3 * s, 0)
		distance = 2.2 * s
	match name:
		"front":
			camera.position = target + Vector3(1.0, 0.35, -2.6).normalized() * distance
		"side":
			camera.position = target + Vector3(2.7, 0.2, -0.25).normalized() * distance
		"back":
			camera.position = target + Vector3(-1.1, 0.5, 2.5).normalized() * distance
		"front_left":
			camera.position = target + Vector3(-1.3, 0.35, -2.4).normalized() * distance
		"left":
			camera.position = target + Vector3(-2.7, 0.2, -0.25).normalized() * distance
		"high":
			target = Vector3(focus.x, 0.35 * s, focus.z)
			camera.position = target + Vector3(1.4, 2.2, -1.9).normalized() * distance * 1.05
		"low":
			target = Vector3(0, 0.3 * s, 0)
			camera.position = target + Vector3(1.8, 1.3, -2.0).normalized() * distance
	camera.look_at(target)

# ---------------------------------------------------------------- measuring

## Lowest and highest point of the skinned mesh in world space.
func _bounds(skeleton: Skeleton3D, mesh_instance: MeshInstance3D) -> Vector2:
	var key := mesh_instance.mesh.get_instance_id()
	if not cache.has(key):
		var arrays := mesh_instance.mesh.surface_get_arrays(0)
		cache[key] = [arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS]]
	var vertices: PackedVector3Array = cache[key][0]
	var bones: PackedInt32Array = cache[key][1]
	var weights: PackedFloat32Array = cache[key][2]
	var per := bones.size() / vertices.size()
	var skin := mesh_instance.skin
	var matrices: Array[Transform3D] = []
	for bind in range(skin.get_bind_count()):
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		matrices.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	var low := INF
	var high := -INF
	for i in range(0, vertices.size(), 2):
		var y := 0.0
		var total := 0.0
		for slot in range(per):
			var w := weights[i * per + slot]
			if w > 0.0:
				y += w * (matrices[bones[i * per + slot]] * vertices[i]).y
				total += w
		if total > 0.0:
			y /= total
			low = minf(low, y)
			high = maxf(high, y)
	return Vector2(low, high)

func _shot(text: String, skeleton: Skeleton3D, mesh_instance: MeshInstance3D, tiles: Array, tag: String) -> void:
	var span := _bounds(skeleton, mesh_instance)
	caption.text = "%s\nlowest %.2f  highest %.2f" % [text, span.x, span.y]
	print("CHECK %s | %s | lowest %.3f highest %.3f" % [tag, text, span.x, span.y])
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	tiles.append(image)

func _sheet(tiles: Array, file: String) -> void:
	var rows := int(ceil(tiles.size() / float(columns)))
	var sheet := Image.create(columns * TILE.x, rows * TILE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.05, 0.06))
	for i in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, TILE), Vector2i((i % columns) * TILE.x, (i / columns) * TILE.y))
	sheet.save_png(out.path_join(file))
	print("CHECK saved ", out.path_join(file))

func _describe(tag: String, skeleton: Skeleton3D, rig: Dictionary) -> void:
	var names := func(entries: Array) -> Array: return entries.map(func(e: Dictionary) -> String: return skeleton.get_bone_name(e.index))
	print("CHECK %s | bones %d | pelvis %s | spine %s | neck %s | head %s" % [tag, skeleton.get_bone_count(), skeleton.get_bone_name(rig.pelvis.index), names.call(rig.spine), skeleton.get_bone_name(rig.neck.index), skeleton.get_bone_name(rig.head.index)])
	for i in range(2):
		var arm: Dictionary = rig.arms[i]
		var leg: Dictionary = rig.legs[i]
		print("CHECK %s | arm%d %s | leg%d %s toe %s" % [tag, i, names.call([arm.clav, arm.upper, arm.fore, arm.hand]), i, names.call([leg.thigh, leg.shin, leg.foot]), skeleton.get_bone_name(int(leg.toe)) if int(leg.toe) >= 0 else "-"])
	print("CHECK %s | leg_length %.4f | hip height %.4f" % [tag, float(rig.leg_length), (rig.pelvis.origin as Vector3).y])

# ---------------------------------------------------------------- all models side by side

func _lineup(kinds: Array, looks: Array) -> void:
	var count := kinds.size() + looks.size()
	var spacing := 1.15
	var width := spacing * count
	viewport.size = Vector2i(2600, 640)
	bar.hide()
	caption.text = ""
	var at := -width * 0.5 + spacing * 0.5
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(1.0, 0.3, 0.2)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for level in [1.0, 2.0]:
		var rail := MeshInstance3D.new()
		var beam := BoxMesh.new()
		beam.size = Vector3(width + 1.0, 0.006, 0.006)
		rail.mesh = beam
		rail.material_override = paint
		rail.position = Vector3(0, level, 0.45)
		stage.add_child(rail)
	var names: Array = []
	for kind in kinds:
		var visual := InfectedVisual.new()
		visual.kind = kind
		visual.position = Vector3(-at, 0, 0)
		stage.add_child(visual)
		visual.player.play("idle")
		visual.player.seek(0.0, true)
		visual.player.advance(0.0)
		names.append([kind, -at, float(visual.config.height)])
		at += spacing
	for look in looks:
		var soldier := SoldierVisual.new()
		soldier.look = look
		soldier.position = Vector3(-at, 0, 0)
		stage.add_child(soldier)
		_advance(soldier, 0.5, Vector3.ZERO, false, false)
		names.append([look, -at, float(soldier.config.height)])
		at += spacing
	for entry in names:
		var tag := Label3D.new()
		tag.text = "%s\n%.2f m" % [entry[0], entry[2]]
		tag.font_size = 40
		tag.pixel_size = 0.0025
		tag.modulate = Color(1, 1, 0.5)
		tag.outline_size = 10
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.position = Vector3(entry[1], 2.3, 0)
		stage.add_child(tag)
	camera.fov = 22
	var half := deg_to_rad(11.0)
	var reach := (width * 0.5 + 0.5) / (tan(half) * 2600.0 / 640.0)
	# Phase 5: with fewer than about seven models that distance is so short that heads and labels are cut off;
	# stay far enough away to show 2.7 m of height.
	reach = maxf(reach, 1.35 / tan(half))
	camera.position = Vector3(0, 1.3, -reach)
	camera.look_at(Vector3(0, 1.18, 0))
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(out.path_join("lineup.png"))
	print("CHECK saved ", out.path_join("lineup.png"))

# ---------------------------------------------------------------- ground contact of every clip

func _scan_player(tag: String, player: AnimationPlayer, skeleton: Skeleton3D, mesh_instance: MeshInstance3D) -> void:
	var names := Array(player.get_animation_list())
	names.sort()
	for clip in names:
		var length := player.get_animation(clip).length
		player.play(clip)
		var low_min := INF
		var low_max := -INF
		var last := 0.0
		var steps := maxi(1, int(ceil(length / 0.1)))
		for i in range(steps + 1):
			var at := minf(length - 0.001, i * 0.1)
			player.seek(maxf(at, 0.0), true)
			player.advance(0.0)
			last = _bounds(skeleton, mesh_instance).x
			low_min = minf(low_min, last)
			low_max = maxf(low_max, last)
		print("CHECKSCAN %-14s %-22s length %5.2f  lowest point: min %+.3f  max %+.3f  at the end %+.3f" % [tag, clip, length, low_min, low_max, last])
		player.stop()

func _scan(kinds: Array, looks: Array) -> void:
	for kind in kinds:
		var visual := InfectedVisual.new()
		visual.kind = kind
		stage.add_child(visual)
		_scan_player(kind, visual.player, visual.skeleton, visual.mesh_instance)
		# which falls the kind really picks, for every kind of shot
		var picked := {}
		for round in range(400):
			for shot in [[false, false, 0.0], [true, false, 0.0], [false, true, 0.0], [false, false, -1.0], [false, false, 1.0]]:
				picked[visual.pick_death(shot[0], shot[1], shot[2])] = true
		var falls := picked.keys()
		falls.sort()
		var missing := falls.filter(func(clip: String) -> bool: return not visual.player.has_animation(clip))
		print("CHECKDEATHS %-14s picks %s%s" % [kind, falls, "" if missing.is_empty() else "  MISSING CLIPS %s" % [missing]])
		visual.free()
	for look in looks:
		var soldier := SoldierVisual.new()
		soldier.look = look
		stage.add_child(soldier)
		_scan_player(look, soldier.legs, soldier.skeleton, soldier.mesh_instance)
		soldier.free()

# ---------------------------------------------------------------- heads

func _check_heads(kinds: Array, looks: Array) -> void:
	var tiles: Array = []
	bar.hide()
	for kind in kinds:
		var visual := InfectedVisual.new()
		visual.kind = kind
		stage.add_child(visual)
		visual.player.play("idle")
		visual.player.seek(0.0, true)
		visual.player.advance(0.0)
		var head := visual.head_position()
		var size := float(visual.config.height) / 1.8
		for view in [Vector3(0.12, 0.05, -1.0), Vector3(0.85, 0.1, -0.6)]:
			camera.position = head + Vector3(0, 0.03, 0) * size + (view as Vector3).normalized() * 0.95 * size
			camera.look_at(head + Vector3(0, 0.03, 0) * size)
			await _shot("%s  head" % kind, visual.skeleton, visual.mesh_instance, tiles, kind)
		visual.queue_free()
		await process_frame
	for look in looks:
		var soldier := SoldierVisual.new()
		soldier.look = look
		stage.add_child(soldier)
		_advance(soldier, 0.5, Vector3.ZERO, false, false)
		var top := soldier.head_position()
		var scale := float(soldier.config.height) / 1.8
		for view in [Vector3(0.12, 0.05, -1.0), Vector3(0.85, 0.1, -0.6)]:
			camera.position = top + Vector3(0, -0.08, 0) * scale + (view as Vector3).normalized() * 1.25 * scale
			camera.look_at(top + Vector3(0, -0.08, 0) * scale)
			await _shot("%s  head and chest" % look, soldier.skeleton, soldier.mesh_instance, tiles, look)
		soldier.queue_free()
		await process_frame
	_sheet(tiles, "check_heads.png")

# ---------------------------------------------------------------- infected

func _check_infected(kind: String, close: bool) -> void:
	var visual := InfectedVisual.new()
	visual.kind = kind
	stage.add_child(visual)
	var config: Dictionary = visual.config
	var height := float(config.height)
	bar.position = Vector3(0, height, 0)
	_describe(kind, visual.skeleton, visual.rig)
	print("CHECK %s | model_scale %.4f stride_scale %.4f | clips %d" % [kind, visual.model_scale, visual.stride_scale, visual.player.get_animation_list().size()])
	var moves: Dictionary = config.moves
	var walk: String = moves.walk[0]
	var run: String = moves.run[0]
	var attacks: Array = moves.attacks
	var death := "mutant_death" if str(config.set) == "mutant" else "death_back"
	var death2 := "mutant_death" if str(config.set) == "mutant" else "death_forward"
	# [clip, position as a share of its length (or -1: the strike), view]
	var plan := [
		["idle", 0.0, "front"], ["idle", 0.5, "side"],
		[walk, 0.3, "side"], [run, 0.22, "front"], [run, 0.62, "side"],
		[attacks[0], -1.0, "front"], [attacks[mini(1, attacks.size() - 1)], -1.0, "side"],
		[death, 0.45, "side"], [death, 1.0, "high"], [death2, 1.0, "high"],
		["flinch" if visual.player.has_animation("flinch") else attacks[0], 0.4, "back"], [run, 0.85, "back"]
	]
	if not plan_override.is_empty():
		plan = plan_override
	var tiles: Array = []
	for entry in plan:
		var clip: String = entry[0]
		if not visual.player.has_animation(clip):
			print("CHECK %s | clip %s missing" % [kind, clip])
			continue
		var info: Dictionary = visual._clip(clip)
		var at := float(info.strike) if float(entry[1]) < 0.0 else float(entry[1]) * float(info.length)
		visual.player.play(clip)
		visual.player.seek(clampf(at, 0.0, float(info.length) - 0.001), true)
		visual.player.advance(0.0)
		var focus := Vector3.ZERO
		if str(entry[2]) == "high":
			focus = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(visual.rig.pelvis.index).origin
		_view(entry[2], height, close, focus)
		await _shot("%s  %s @ %.2fs  (%s)" % [kind, clip, at, entry[2]], visual.skeleton, visual.mesh_instance, tiles, kind)
	if not plan_override.is_empty():
		_sheet(tiles, "check_%s_plan%s.png" % [kind, "_close" if close else ""])
		visual.queue_free()
		await process_frame
		return
	# The game tears off arms and heads by shrinking the bone (InfectedVisual.sever).
	visual.player.play("idle")
	visual.player.seek(0.0, true)
	visual.player.advance(0.0)
	visual.sever("arm1")
	_view("front", height, close)
	await _shot("%s  left arm torn off (sever)" % kind, visual.skeleton, visual.mesh_instance, tiles, kind)
	visual.sever("head")
	await _shot("%s  head torn off (sever)" % kind, visual.skeleton, visual.mesh_instance, tiles, kind)
	_sheet(tiles, "check_%s%s.png" % [kind, "_close" if close else ""])
	visual.queue_free()
	await process_frame

# ---------------------------------------------------------------- soldiers

func _advance(visual: SoldierVisual, seconds: float, velocity: Vector3, aim: bool, shooting: bool) -> void:
	var steps := int(round(seconds * 30.0))
	for i in range(steps):
		visual.animate(1.0 / 30.0, velocity, aim, shooting)

func _check_soldier(look: String, close: bool) -> void:
	var visual := SoldierVisual.new()
	visual.look = look
	stage.add_child(visual)
	var config: Dictionary = visual.config
	var height := float(config.height)
	bar.position = Vector3(0, height, 0)
	_describe(look, visual.skeleton, visual.rig)
	print("CHECK %s | model_scale %.4f stride_scale %.4f" % [look, visual.model_scale, visual.stride_scale])
	var ahead := Vector3(0, 0, -1)
	var tiles: Array = []
	var tag := look
	_advance(visual, 0.6, Vector3.ZERO, false, false)
	_view("front", height, close)
	await _shot("%s  idle (front)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_view("side", height, close)
	await _shot("%s  idle (side)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_advance(visual, 0.75, ahead * 4.6, false, false)
	_view("front", height, close)
	await _shot("%s  run 4.6 m/s (front)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_advance(visual, 0.2, ahead * 4.6, false, false)
	_view("side", height, close)
	await _shot("%s  run, 0.2 s later (side)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_advance(visual, 0.8, Vector3.ZERO, true, false)
	_view("front", height, close)
	await _shot("%s  aim, standing (front)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_view("side", height, close)
	await _shot("%s  aim, standing (side)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_view("back", height, close)
	await _shot("%s  aim, standing (back)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_advance(visual, 0.5, ahead * 1.9, true, true)
	visual.shot()
	visual.animate(1.0 / 30.0, ahead * 1.9, true, true)
	_view("front", height, close)
	await _shot("%s  walk + fire (front)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	visual.reload(2.2)
	_advance(visual, 1.1, Vector3.ZERO, false, false)
	_view("front", height, close)
	await _shot("%s  reload, half way (front)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_advance(visual, 1.4, -ahead * 1.5, false, false)
	_view("side", height, close)
	await _shot("%s  walking backwards (side)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	visual.fall(false)
	_advance(visual, 0.5, Vector3.ZERO, false, false)
	_view("side", height, close)
	await _shot("%s  going down, 0.5 s (side)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_advance(visual, 2.5, Vector3.ZERO, false, false)
	_view("high", height, close, visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(visual.rig.pelvis.index).origin)
	await _shot("%s  down (from above)" % look, visual.skeleton, visual.mesh_instance, tiles, tag)
	_sheet(tiles, "check_%s%s.png" % [look, "_close" if close else ""])
	visual.queue_free()
	await process_frame
