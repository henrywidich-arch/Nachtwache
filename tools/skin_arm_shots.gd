extends SceneTree
## Pictures of the player's skins from outside, to match the first-person arms to them
## (WeaponView.ARM_LOOKS): each look standing, and a close view of its right forearm and
## hand. Also prints the colours its texture has where the forearm and the hand are (the
## vertices those joints move most, their texels grouped into three colours), which is
## where ARM_LOOKS takes its colours from. Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/skin_arm_shots.gd -- --out=<folder> [--skin=scorpion]

var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://skin_arms"
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--skin="):
			only = arg.trim_prefix("--skin=")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.42, 0.45, 0.5)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.8, 0.82)
	world.environment.ambient_light_energy = 0.7
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	root.add_child(sun)
	stage = Node3D.new()
	root.add_child(stage)
	camera = Camera3D.new()
	camera.near = 0.02
	root.add_child(camera)
	camera.current = true
	var sheet: Array[Image] = []
	for id in Profile.SKINS:
		if only != "" and id != only:
			continue
		var soldier := SoldierVisual.new()
		soldier.look = String(id)
		stage.add_child(soldier)
		for i in range(18):
			soldier.animate(1.0 / 30.0, Vector3.ZERO, false, false)
		var height := float(soldier.config.height)
		camera.fov = 24.0
		camera.position = Vector3(0, height * 0.55, -height * 2.6)
		camera.look_at(Vector3(0, height * 0.52, 0))
		sheet.append(await _save(folder.path_join("%s_ganz.png" % id)))
		# Close to the right forearm and hand (the model faces -z, its right hand at +x).
		var arm: Dictionary = soldier.rig.arms[0]
		var skel := soldier.skeleton
		var hand := skel.global_transform * skel.get_bone_global_pose(arm.hand.index).origin
		var elbow := skel.global_transform * skel.get_bone_global_pose(arm.fore.index).origin
		var middle := (hand + elbow) * 0.5
		camera.fov = 30.0
		camera.position = middle + Vector3(0.4, 0.12, -0.55)
		camera.look_at(middle)
		sheet.append(await _save(folder.path_join("%s_arm.png" % id)))
		camera.position = middle + Vector3(0.6, 0.05, 0.15)
		camera.look_at(middle)
		sheet.append(await _save(folder.path_join("%s_arm_seite.png" % id)))
		_sample(soldier)
		soldier.queue_free()
		await process_frame
	_sheet(sheet, 3, folder.path_join("uebersicht.png"))
	quit()

## The colours of the texture where the forearm and the hand are.
func _sample(soldier: SoldierVisual) -> void:
	var body := soldier.mesh_instance
	var skel := soldier.skeleton
	var material := body.material_override as StandardMaterial3D
	if material == null or body.skin == null:
		print("SAMPLE %s: no material or skin" % soldier.look)
		return
	var picture := material.albedo_texture.get_image()
	if picture.is_compressed():
		picture.decompress()
	var metal_picture: Image = null
	if material.metallic_texture != null:
		metal_picture = material.metallic_texture.get_image()
		if metal_picture.is_compressed():
			metal_picture.decompress()
	# Which joints count as the hand (the hand and its fingers) and the forearm.
	var hands := {}
	var fores := {}
	var uppers := {}
	for arm: Dictionary in soldier.rig.arms:
		fores[int(arm.fore.index)] = true
		uppers[int(arm.upper.index)] = true
		for bone in range(skel.get_bone_count()):
			var up := bone
			while up >= 0 and up != int(arm.hand.index):
				up = skel.get_bone_parent(up)
			if up >= 0:
				hands[bone] = true
	var groups := {"hand": [], "forearm": [], "upper": []}
	var metal := {"hand": [], "forearm": [], "upper": []}
	for surface in range(body.mesh.get_surface_count()):
		var arrays := body.mesh.surface_get_arrays(surface)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if uvs.is_empty() or bones.is_empty():
			continue
		var per := bones.size() / uvs.size()
		var joint_of: Array[int] = []
		for i in range(body.skin.get_bind_count()):
			var which := body.skin.get_bind_bone(i)
			if which < 0:
				which = skel.find_bone(body.skin.get_bind_name(i))
			joint_of.append(which)
		for v in range(uvs.size()):
			var best := -1
			var most := 0.0
			for k in range(per):
				if weights[v * per + k] > most:
					most = weights[v * per + k]
					best = joint_of[bones[v * per + k]]
			if most < 0.6:
				continue
			var group := "hand" if hands.has(best) else ("forearm" if fores.has(best) else ("upper" if uppers.has(best) else ""))
			if group == "":
				continue
			var uv := uvs[v]
			var x := clampi(int(fposmod(uv.x, 1.0) * picture.get_width()), 0, picture.get_width() - 1)
			var y := clampi(int(fposmod(uv.y, 1.0) * picture.get_height()), 0, picture.get_height() - 1)
			(groups[group] as Array).append(picture.get_pixel(x, y))
			if metal_picture != null:
				var mx := clampi(int(fposmod(uv.x, 1.0) * metal_picture.get_width()), 0, metal_picture.get_width() - 1)
				var my := clampi(int(fposmod(uv.y, 1.0) * metal_picture.get_height()), 0, metal_picture.get_height() - 1)
				(metal[group] as Array).append(metal_picture.get_pixel(mx, my).b)
	for group in groups:
		var colours: Array = groups[group]
		var shine := 0.0
		for m: float in metal[group]:
			shine += m
		shine /= maxf((metal[group] as Array).size(), 1.0)
		var line := "SAMPLE %s %s n=%d metal=%.2f:" % [soldier.look, group, colours.size(), shine]
		for cluster in _clusters(colours, 3):
			line += "  #%s %d%%" % [(cluster[0] as Color).to_html(false), int(cluster[1] * 100.0)]
		print(line)

## A few rounds of k-means over the colours: [colour, share], the biggest share first.
func _clusters(colours: Array, k: int) -> Array:
	if colours.is_empty():
		return []
	var centres: Array = []
	var sorted := colours.duplicate()
	sorted.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	for i in range(k):
		centres.append(sorted[int((i + 0.5) / k * sorted.size())])
	var counts: Array = []
	for round in range(12):
		var sums: Array = []
		counts = []
		for i in range(k):
			sums.append(Vector3.ZERO)
			counts.append(0)
		for c: Color in colours:
			var best := 0
			var near := 1e9
			for i in range(k):
				var d := Vector3(c.r, c.g, c.b).distance_squared_to(Vector3(centres[i].r, centres[i].g, centres[i].b))
				if d < near:
					near = d
					best = i
			sums[best] += Vector3(c.r, c.g, c.b)
			counts[best] += 1
		for i in range(k):
			if counts[i] > 0:
				var m: Vector3 = sums[i] / counts[i]
				centres[i] = Color(m.x, m.y, m.z)
	var out: Array = []
	for i in range(k):
		if counts[i] > 0:
			out.append([centres[i], float(counts[i]) / colours.size()])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return out

## The pictures side by side, `across` to a row, each at a third of its size.
static func _sheet(pictures: Array[Image], across: int, path: String) -> void:
	if pictures.is_empty():
		return
	var w := pictures[0].get_width() / 3
	var h := pictures[0].get_height() / 3
	var rows := ceili(float(pictures.size()) / across)
	var out := Image.create(w * across, h * rows, false, Image.FORMAT_RGB8)
	for i in range(pictures.size()):
		var small := pictures[i].duplicate() as Image
		small.convert(Image.FORMAT_RGB8)
		small.resize(w, h, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(0, 0, w, h), Vector2i((i % across) * w, (i / across) * h))
	out.save_png(path)

func _save(path: String) -> Image:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.save_png(path)
	print("saved ", path)
	return shot
