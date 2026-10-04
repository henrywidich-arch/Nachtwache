extends SceneTree
## Screenshots of the map from fixed viewpoints, with a flashlight on the camera like the
## player's. Run windowed (not headless):
##   Godot --path <project> --resolution 1280x720 -s res://tools/map_shots.gd -- --out=<folder> [--shots=a,b,c] [--fps]
## Without --shots every view is rendered. --fps prints frame rate and draw calls at
## three busy viewpoints (vsync off).

const VIEWS := {
	"top": [Vector3(0, 95, 4.5), Vector3(0, 0, 4)],
	"top_house": [Vector3(1.5, 30, 0.5), Vector3(1.5, 0, 0)],
	"top_upper": [Vector3(1.5, 30, 0.5), Vector3(1.5, 0, 0)],
	"menu": [Vector3(9.0, 2.2, 25.0), Vector3(-1.0, 3.8, 9.0)],
	"house_front": [Vector3(-7, 1.62, 26), Vector3(0, 4, 9)],
	"house_back": [Vector3(4, 1.62, -24), Vector3(0, 3.5, -9)],
	"house_west": [Vector3(-27, 1.62, 3), Vector3(-13, 3, -3)],
	"house_east": [Vector3(27, 1.62, 2), Vector3(13, 3, -3)],
	"hall": [Vector3(0, 1.62, 8.2), Vector3(0, 2.3, -2)],
	"hall_up": [Vector3(-2.2, 1.62, 7.6), Vector3(1.5, 5.2, 1.5)],
	"hall_south": [Vector3(0, 1.62, -1.8), Vector3(0, 1.8, 9)],
	"shop": [Vector3(0, 1.6, -0.4), Vector3(0, 1.45, -2.55)],
	"lounge": [Vector3(5.8, 1.62, -2.2), Vector3(11.5, 1.0, 5.5)],
	"kitchen": [Vector3(-5.8, 1.62, -1.8), Vector3(-12, 1.2, -6)],
	"dining": [Vector3(-5.8, 1.62, 0.0), Vector3(-10.5, 1.0, 6.5)],
	"supply": [Vector3(5.9, 1.62, -4.2), Vector3(12.5, 1.2, -7)],
	"stair_hall": [Vector3(4.2, 1.62, -3.9), Vector3(-1.0, 1.6, -8.5)],
	"stairs_up": [Vector3(4.2, 1.62, -8.0), Vector3(-2, 3.2, -8.0)],
	"gallery_down": [Vector3(-4.0, 4.92, 7.6), Vector3(2, 0.6, 1)],
	"landing": [Vector3(-4.2, 4.92, -3.6), Vector3(4, 4.3, -1.5)],
	"stairs_down": [Vector3(-3.6, 4.92, -8.0), Vector3(3, 1.2, -8.0)],
	"upper_west": [Vector3(-5.8, 4.92, -0.2), Vector3(-11, 4.2, 5.5)],
	"upper_northwest": [Vector3(-5.8, 4.92, -1.8), Vector3(-11, 4.2, -7)],
	"upper_east": [Vector3(5.8, 4.92, 7.8), Vector3(12, 4.3, -1.5)],
	"upper_northeast": [Vector3(5.8, 4.92, -3.8), Vector3(12, 4.2, -8)],
	"balcony": [Vector3(14.4, 4.92, 0.9), Vector3(17, 3.0, -9)],
	"outer_stairs": [Vector3(18.5, 1.62, -11.5), Vector3(14, 2.6, -4)],
	"side_door": [Vector3(19.5, 1.62, 1.5), Vector3(13, 1.6, -1.5)],
	"breach": [Vector3(-19, 1.62, -1.5), Vector3(-13, 1.4, -4.8)],
	"yard_to_barn": [Vector3(14.5, 1.62, -9), Vector3(29, 3, -18)],
	"barn_out": [Vector3(26, 1.62, 0), Vector3(29, 3.5, -12)],
	"barn_in": [Vector3(29, 1.62, -12.8), Vector3(29, 2.2, -27)],
	"barn_in_back": [Vector3(27.5, 1.62, -26.5), Vector3(31, 1.8, -13)],
	"garage_out": [Vector3(-23, 1.62, -9.5), Vector3(-31, 1.6, -22)],
	"garage_in": [Vector3(-27.2, 1.62, -19.8), Vector3(-33.5, 1.2, -25)],
	"guest_out": [Vector3(-17, 1.62, 15), Vector3(-30, 1.6, 23)],
	"guest_in": [Vector3(-26.8, 1.62, 23.6), Vector3(-32, 1.1, 24.6)],
	"shed_out": [Vector3(21, 1.62, 14.5), Vector3(27.5, 1.3, 23)],
	"shed_in": [Vector3(27.5, 1.62, 22.3), Vector3(27.0, 1.2, 25.4)],
	"yard_gate": [Vector3(0.5, 1.62, 45), Vector3(0, 3, 9)],
	"yard_from_porch": [Vector3(0, 1.62, 11.2), Vector3(1, 1.6, 40)],
	"yard_north": [Vector3(-2, 1.62, -12), Vector3(8, 1.5, -24)],
	"yard_southeast": [Vector3(8, 1.62, 18), Vector3(24, 1.2, 34)],
	"yard_west": [Vector3(-15.5, 1.62, 12), Vector3(-32, 2, -20)],
	"paddock": [Vector3(20, 1.62, 4), Vector3(36, 1.2, 2)],
	"fence_gas": [Vector3(-36, 1.62, 6), Vector3(-52, 1.5, 4)]
}
const FPS_VIEWS := ["hall", "house_front", "yard_to_barn"]

var map: Node3D
var camera: Camera3D

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
	map = load("res://scripts/cabin.gd").new()
	map.name = "Waldposten"
	root.add_child(map)
	camera = Camera3D.new()
	camera.fov = 74
	camera.near = 0.05
	camera.far = 240
	root.add_child(camera)
	camera.current = true
	var torch := SpotLight3D.new()
	torch.position = Vector3(0.12, -0.12, -0.1)
	torch.light_color = Color("e6ecd8")
	torch.light_energy = 3.2
	torch.spot_range = 30
	torch.spot_angle = 27
	torch.spot_attenuation = 1.1
	torch.spot_angle_attenuation = 0.7
	torch.shadow_enabled = true
	torch.shadow_bias = 0.06
	torch.light_volumetric_fog_energy = 0.3
	camera.add_child(torch)
	# The title screen lights the house with a cold spot from beside the camera.
	var menu_light := SpotLight3D.new()
	menu_light.light_color = Color(0.62, 0.74, 1.0)
	menu_light.light_energy = 6.0
	menu_light.spot_range = 48
	menu_light.spot_angle = 38
	menu_light.spot_attenuation = 0.6
	menu_light.shadow_enabled = true
	menu_light.light_volumetric_fog_energy = 0.12
	menu_light.position = Vector3(3.0, 5.0, 0)
	menu_light.visible = false
	camera.add_child(menu_light)
	for i in range(40):
		await process_frame
	var env: Environment = map.environment
	for name in wanted:
		if not VIEWS.has(name):
			print("unknown view ", name)
			continue
		var view: Array = VIEWS[name]
		var plan: bool = name.begins_with("top")
		camera.fov = 58 if name == "menu" else (60 if plan else 74)
		camera.position = view[0]
		if plan:
			# Plan views: looking straight down in flat light, without fog, rain and roofs.
			camera.rotation = Vector3(-PI / 2, 0, 0)
		else:
			camera.look_at(view[1])
		torch.visible = not plan and name != "menu"
		menu_light.visible = name == "menu"
		env.fog_enabled = not plan
		env.volumetric_fog_enabled = not plan
		env.ambient_light_energy = 6.0 if plan else 0.3
		map.rain.visible = not plan
		for child in map.get_children():
			if child is MeshInstance3D:
				var id := String(child.name)
				if id.begins_with("Roof"):
					child.visible = not plan
				elif id.begins_with("HouseUp"):
					child.visible = name != "top_house"
			elif child is MultiMeshInstance3D:
				child.visible = not plan
		camera.near = 27.2 if name == "top_house" else (23.9 if name == "top_upper" else 0.05)
		for i in range(24):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
		print("saved ", name)
	if measure:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		torch.visible = true
		menu_light.visible = false
		env.fog_enabled = true
		env.volumetric_fog_enabled = true
		env.ambient_light_energy = 0.3
		map.rain.visible = true
		for child in map.get_children():
			if child is VisualInstance3D:
				child.visible = true
		# Fourteen bodies wandering through the house and the yard make every lamp near
		# them redraw its shadows, as a fight would.
		var centres := [Vector3(0, 0.9, 3.2), Vector3(0.5, 0.9, 3.0), Vector3(-0.5, 0.9, 3.6), Vector3(0, 0.9, 2.6), Vector3(-9, 0.9, -4), Vector3(-9, 0.9, 4), Vector3(9, 0.9, 3), Vector3(0, 0.9, -5), Vector3(0, 4.2, -4.5), Vector3(-9, 4.2, 3), Vector3(9, 4.2, 2), Vector3(-9, 4.2, -5), Vector3(0, 0.9, 13), Vector3(29, 0.9, -19)]
		var movers: Array[MeshInstance3D] = []
		for centre in centres:
			var dummy := MeshInstance3D.new()
			var shape := BoxMesh.new()
			shape.size = Vector3(0.6, 1.8, 0.6)
			dummy.mesh = shape
			dummy.position = centre
			dummy.visible = false
			root.add_child(dummy)
			movers.append(dummy)
		for name in FPS_VIEWS:
			camera.fov = 74
			camera.near = 0.05
			camera.position = VIEWS[name][0]
			camera.look_at(VIEWS[name][1])
			for moving in [false, true]:
				for dummy in movers:
					dummy.visible = moving
				var until := Time.get_ticks_msec() + 3500
				while Time.get_ticks_msec() < until:
					if moving:
						var t := Time.get_ticks_msec() * 0.001
						for i in range(movers.size()):
							movers[i].position = (centres[i] as Vector3) + Vector3(cos(t * 1.3 + i), 0, sin(t * 1.3 + i)) * (1.2 + (i % 3) * 0.6)
					await process_frame
				print("PERF %s%s: %d FPS, %d draw calls, %d primitives" % [name, " with 14 moving bodies" if moving else "", Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	print("SHOTS_COMPLETE")
	quit()
