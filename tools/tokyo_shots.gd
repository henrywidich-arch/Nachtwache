extends SceneTree
## Pictures of the simulation hall (TokyoHall, built alone by TokyoMap) from fixed
## viewpoints. Run windowed:
##   Godot --path . --resolution 1600x900 -s res://tools/tokyo_shots.gd -- --out=<folder> [--shots=a,b] [--fps]
## --fps prints the frame rate at a few busy viewpoints (vsync off).

const VIEWS := {
	"overview": [Vector3(58, 40, 66), Vector3(0, 0, -8)],
	"crossing": [Vector3(-2, 1.7, 24), Vector3(0, 6, -30)],
	"crossing_neo": [Vector3(-6, 1.7, 5), Vector3(14, 9, -15)],
	"model": [Vector3(-2, 1.7, -2), Vector3(-19, 12, -19)],
	"model_far": [Vector3(6, 7.1, -24.5), Vector3(-19, 14, -19)],
	"model_close": [Vector3(-9.5, 1.7, -9.5), Vector3(-16, 4, -14)],
	# The TOKYO RAMEN IZAKAYA (TokyoHall._tk_izakaya): from the front and its right, as in the
	# picture it was built after; straight from the front; its entrance from close by.
	"izakaya": [Vector3(6.0, 2.2, 2.0), Vector3(15.0, 4.6, 13.5)],
	"izakaya_front": [Vector3(15.3, 2.0, 0.5), Vector3(15.3, 4.6, 11.5)],
	"izakaya_near": [Vector3(13.6, 1.7, 7.2), Vector3(16.6, 2.0, 11.5)],
	"spawn": [Vector3(-4.0, 1.7, 17.0), Vector3(-4.0, 1.7, 7.0)],
	"spawn_right": [Vector3(-4.0, 1.7, 17.0), Vector3(6.0, 2.5, 15.0)],
	"izakaya_jump": [Vector3(15.3, 1.7, 5.5), Vector3(15.3, 2.4, 15.5)],
	"front_a": [Vector3(-22.86, 1.7, -4.5), Vector3(-22.86, 5.5, -11.5)],
	"front_b": [Vector3(-45.5, 1.7, -34.0), Vector3(-44.67, 6.0, -27.0)],
	"front_c": [Vector3(46.0, 1.7, 21.0), Vector3(45.0, 6.5, 27.0)],
	"task_pachinko": [Vector3(-20.0, 1.7, 47.0), Vector3(-24.8, 1.2, 48.0)],
	"task_yamashita": [Vector3(14.0, 1.7, 47.0), Vector3(18.1, 1.0, 48.6)],
	"task_tech": [Vector3(48.8, 1.7, -6.0), Vector3(49.8, 1.0, -11.0)],
	"task_core": [Vector3(12.0, 1.7, 63.0), Vector3(12.0, 1.0, 69.0)],
	"sakura_close": [Vector3(-36.0, 1.7, 26.0), Vector3(-42.0, 4.5, 20.0)],
	"koi_street": [Vector3(-28.5, 1.7, -8.0), Vector3(-26.0, 5.0, -45.0)],
	"pachinko_front": [Vector3(-3.0, 1.7, 43.0), Vector3(-11.5, 7.0, 47.0)],
	"koi_lobby": [Vector3(-20.6, 1.6, -45.5), Vector3(-26.2, 1.4, -45.5)],
	"koi_plaza": [Vector3(-6.0, 1.8, -36.0), Vector3(-23.0, 9.0, -46.0)],
	"izakaya_ref": [Vector3(9.6, 3.6, 3.6), Vector3(15.2, 4.4, 13.0)],
	"izakaya_door": [Vector3(16.6, 1.6, 9.0), Vector3(16.6, 2.0, 12.5)],
	"neo_screen": [Vector3(3, 1.7, -3), Vector3(16, 16, -16)],
	"yokocho": [Vector3(20.6, 1.7, 28.5), Vector3(20.6, 3.2, 10)],
	"side_street": [Vector3(34, 1.7, 58), Vector3(34, 5, 10)],
	"alley": [Vector3(-34, 1.7, -52), Vector3(-34, 4, -12)],
	"park": [Vector3(-37, 1.7, 22), Vector3(-55, 3, 17)],
	"bridge": [Vector3(6, 7.1, -24.5), Vector3(-4, 5, 20)],
	"tower": [Vector3(6, 1.7, -24), Vector3(0, 22, -51)],
	"control": [Vector3(4, 1.7, 44), Vector3(0, 19, 70)],
	"supply": [Vector3(-5, 1.7, 15.5), Vector3(-11, 1.3, 17.5)],
	"edge": [Vector3(28, 1.7, 66), Vector3(62, 6, 71)],
	"lock": [Vector3(-60, 1.7, 0), Vector3(-72, 2, 0)],
	"top": [Vector3(0, 46, 0.01), Vector3(0, 0, 0)]
}
const FPS_VIEWS := ["crossing", "model", "side_street", "overview"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	var wanted: Array = VIEWS.keys()
	var measure := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			wanted = Array(arg.trim_prefix("--shots=").split(","))
		elif arg == "--fps":
			measure = true
	DirAccess.make_dir_recursive_absolute(folder)
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	map.name = "Tokio"
	root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 74
	camera.near = 0.05
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	for i in range(30):
		await process_frame
	for name in wanted:
		if not VIEWS.has(name):
			print("unknown view ", name)
			continue
		_aim(camera, name)
		for i in range(40):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
		print("saved ", name)
	if measure:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		for name in FPS_VIEWS:
			_aim(camera, name)
			for i in range(30):
				await process_frame
			var from := Time.get_ticks_usec()
			var frames := 0
			while Time.get_ticks_usec() - from < 2000000:
				await process_frame
				frames += 1
			print("FPS %s: %.0f  (draw calls %d, primitives %d)" % [name, frames / ((Time.get_ticks_usec() - from) / 1000000.0), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()

func _aim(camera: Camera3D, name: String) -> void:
	var view: Array = VIEWS[name]
	camera.fov = 110 if name == "top" else 74
	camera.position = view[0]
	if name == "top":
		camera.rotation = Vector3(-PI / 2, 0, 0)
	else:
		camera.look_at(view[1])
