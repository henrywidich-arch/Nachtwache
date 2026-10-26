extends SceneTree
## Each facade part twice, side by side in the same light: left the original as it came
## (read from the source folder, not changed), right the part of the game
## (assets/tokyo/kit). One picture per part. Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/kit_compare.gd -- --out=<folder> [--src=<source folder>]

const PARTS := {
	"window_a": "Meshy_AI_SciFi_Window_Frame_1024151034_image-to-3d-texture",
	"window_b": "fensteralt",
	"window_shutter": "Meshy_AI_Industrial_Rolling_Sh_1024152806_texture",
	"door_frame": "Meshy_AI_Industrial_Portal_Fra_1024152640_texture",
	"shop_roller": "Meshy_AI_Storefront_Roller_Shu_1024165320_image-to-3d-texture",
	"shop_sliding": "ladenfront",
	"shop_window": "storefront",
	"balcony": "Meshy_AI_Tokyo_Balcony_Module_1024175402_image-to-3d-texture",
	"vending": "Meshy_AI_Tokyo_Vending_Machine_1025043334_image-to-3d-texture",
	"fence": "zaun",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	var source := "D:/Games/AI Games/Nachtwache/tokyo"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--src="):
			source = arg.trim_prefix("--src=")
	DirAccess.make_dir_recursive_absolute(folder)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.2, 0.22, 0.25)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	world.environment.ambient_light_energy = 0.6
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30
	root.add_child(camera)
	camera.current = true
	for part in PARTS:
		var mine := (load("res://assets/tokyo/kit/%s.glb" % part) as PackedScene).instantiate() as Node3D
		var box := _box(mine)
		var original := _load_original(source.path_join(PARTS[part] + "_low.glb"))
		if original == null:
			original = _load_original(source.path_join(PARTS[part] + ".glb"))
		if original == null:
			print("no original for ", part)
			mine.free()
			continue
		root.add_child(original)
		root.add_child(mine)
		# The original to the same width, its foot on the floor, left of the game's part.
		var raw := _box(original)
		var k := box.size.x / raw.size.x
		original.scale = Vector3.ONE * k
		var gap := box.size.x * 0.15
		original.position = Vector3(-gap * 0.5 - box.size.x * 0.5 - (raw.position.x + raw.size.x * 0.5) * k, -raw.position.y * k, -(raw.position.z + raw.size.z * 0.5) * k)
		mine.position = Vector3(gap * 0.5 + box.size.x * 0.5 - (box.position.x + box.size.x * 0.5), -box.position.y, -(box.position.z + box.size.z * 0.5))
		var wide := box.size.x * 2.0 + gap
		var high := maxf(box.size.y, raw.size.y * k)
		var span := maxf(wide / 1.78, high) * 1.15
		camera.position = Vector3(0, high * 0.5 + span * 0.12, span / tan(deg_to_rad(15.0)) * 0.5 + box.size.z)
		camera.look_at(Vector3(0, high * 0.5, 0))
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("vergleich_%s.png" % part))
		print("saved ", part, ": original ", _triangles(original), " triangles, game ", _triangles(mine))
		original.queue_free()
		mine.queue_free()
		await process_frame
	quit()

func _load_original(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D

func _box(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var part := (item as MeshInstance3D).transform * (item as MeshInstance3D).mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box

func _triangles(model: Node3D) -> int:
	var count := 0
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (item as MeshInstance3D).mesh
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			count += index.size() / 3 if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count
