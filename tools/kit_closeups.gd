extends SceneTree
## Close pictures of the facade parts in the simulation hall, like a player sees them: a
## front with a roller-shutter shop seen from below, balconies from below, vending machines
## from in front. Finds the first parts of each kind the hall put up. Run with
## tools/godot_bg.ps1 -Render:
##   -s res://tools/kit_closeups.gd -- --out=<folder> [--no-kit] [--prefix=name_]

const SHOTS := [
	# kind, how far out, eye height above the street, where to look (height up the part)
	["shop_facade", 3.2, 1.7, 7.0],
	["balcony", 3.0, 1.7, 1.2],
	["vending", 2.3, 1.6, 1.0],
	["window_a", 3.5, 1.7, 1.0],
	["shop_facade", 8.0, 1.7, 3.4, "shop_front"],
	["cc_bin_0", 2.4, 1.6, 0.5],
	["cc_aircon_0", 3.0, 1.7, 0.5],
	["cc_utility_a", 2.5, 1.6, 0.8],
	["cc_bag", 2.2, 1.5, 0.2],
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	var prefix := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
	DirAccess.make_dir_recursive_absolute(folder)
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	map.name = "Tokio"
	root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 70
	camera.near = 0.05
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	for i in range(20):
		await process_frame
	for shot in SHOTS:
		var kind: String = shot[0]
		var at := _find(map, kind)
		if at == Transform3D():
			print("no ", kind)
			continue
		var out := at.basis.z.normalized()
		var eye := at.origin + out * float(shot[1])
		eye.y = float(shot[2])
		if kind == "balcony":
			# (From below, near the wall: the eye on the street, the balcony above.)
			eye = at.origin + out * float(shot[1])
			eye.y = 1.7
		camera.position = eye
		camera.look_at(at.origin + Vector3(0, float(shot[3]), 0) + out * 0.3)
		for i in range(40):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(prefix + (str(shot[4]) if shot.size() > 4 else kind) + ".png"))
		print("saved ", kind, " at ", at.origin)
	quit()

## The place of a part of this kind: the one nearest the middle of the city that has another
## of its kind beside it (for the vending machines: a pair).
func _find(map: Node, kind: String) -> Transform3D:
	var best := Transform3D()
	var best_d := INF
	for node in map.find_children("Kit_*", "MultiMeshInstance3D", true, false):
		if not str(node.name).ends_with("_" + kind):
			continue
		var many: MultiMesh = (node as MultiMeshInstance3D).multimesh
		for i in range(many.instance_count):
			var xf := (node as Node3D).global_transform * many.get_instance_transform(i)
			var d := Vector2(xf.origin.x, xf.origin.z).length()
			if d < best_d:
				best_d = d
				best = xf
	return best
