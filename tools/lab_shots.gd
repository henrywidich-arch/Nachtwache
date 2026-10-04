extends SceneTree
## Screenshots of the places added for the Helix story (basement laboratory, barricades,
## landing zone, radio mast), from a free camera with a flashlight like the player's.
## Run with a window (not headless):
##   Godot --path <project> --resolution 1600x900 -s res://tools/lab_shots.gd -- --out=<folder> [--shots=a,b,c]
## Extra views can be given on the command line:
##   --view=name:x,y,z:x,y,z[:fov[:state]]   (camera position, target, field of view, state)
## A state is a list of words joined by "+":
##   locked      every area closed (default: everything open)
##   open=a,b    with "locked": these areas are opened again
##   dark        everything that shines in the basement is switched off, and the sky's
##               ambient light with it: what is still lit has leaked in from outside
##   moon=6      the moonlight is made this many times stronger (to look for leaks)
##   notorch     without the flashlight
##   storm       lightning strikes while the picture is taken
##   blackout    the farm's power is cut
##   gas=north   gas drifts over that side of the yard
##   beacon      the beacon of the radio mast is on
##   rain        the rain is drawn as thick red streaks (to see where roofs keep it out)
##   near=12     everything closer to the camera than this is cut away
##   plan        looking straight down in flat light, without fog, rain and roofs
##   cut=-0.7    with "plan": everything above this height is cut away
## Nadja's model stands at points.nadja in every picture, so that one can judge how well
## she is seen through the glass.

const VIEWS := {
	"cellar_door_sealed": [Vector3(-4.75, 1.62, -6.2), Vector3(-2.4, 1.25, -7.7), 68, "locked"],
	"cellar_door_open": [Vector3(-4.75, 1.62, -6.2), Vector3(-2.4, 1.25, -7.7), 68, ""],
	"cellar_panel": [Vector3(-1.2, 1.62, -4.4), Vector3(-2.2, 1.3, -6.95), 60, "locked"],
	"cellar_stairs_down": [Vector3(-2.9, 1.62, -7.9), Vector3(3.0, -3.0, -7.9), 74, ""],
	"cellar_stairs_up": [Vector3(4.6, -1.98, -7.9), Vector3(-2.0, 0.6, -7.9), 74, ""],
	"corridor": [Vector3(4.5, -1.98, -8.6), Vector3(4.5, -2.2, -16.0), 74, ""],
	"lab_from_entry": [Vector3(4.5, -1.98, -14.6), Vector3(-4.0, -2.6, -22.0), 80, ""],
	"lab_from_north": [Vector3(0.0, -1.98, -24.2), Vector3(1.5, -2.6, -14.0), 80, ""],
	"lab_from_west": [Vector3(-7.4, -1.98, -15.0), Vector3(5.0, -2.7, -23.5), 80, ""],
	"lab_no_torch": [Vector3(4.5, -1.98, -14.6), Vector3(-4.0, -2.6, -22.0), 80, "notorch"],
	"lab_tanks": [Vector3(0.5, -1.98, -19.5), Vector3(4.6, -2.3, -24.6), 70, ""],
	"lab_tank_close": [Vector3(-4.6, -1.98, -22.2), Vector3(-5.6, -2.2, -24.1), 60, ""],
	"nadja_glass": [Vector3(-4.6, -1.98, -20.2), Vector3(-9.8, -2.55, -20.5), 66, "locked+open=cellar"],
	"nadja_glass_far": [Vector3(3.0, -1.98, -16.2), Vector3(-9.8, -2.6, -20.5), 60, "locked+open=cellar+notorch"],
	"nadja_door_sealed": [Vector3(-5.0, -1.98, -15.6), Vector3(-8.2, -2.5, -17.6), 66, "locked+open=cellar"],
	"nadja_door_open": [Vector3(-5.0, -1.98, -15.6), Vector3(-8.2, -2.5, -17.6), 66, ""],
	"nadja_room": [Vector3(-12.6, -1.98, -17.2), Vector3(-9.0, -2.8, -21.5), 80, ""],
	"blast_door_sealed": [Vector3(0.8, -1.98, -20.4), Vector3(0.0, -2.4, -25.2), 66, "locked+open=cellar"],
	"blast_door_open": [Vector3(0.8, -1.98, -20.4), Vector3(0.0, -2.4, -25.2), 66, ""],
	"tunnel": [Vector3(0.0, -1.98, -25.9), Vector3(-0.2, -2.3, -31.0), 78, ""],
	"tunnel_stairs": [Vector3(0.3, -1.98, -30.0), Vector3(-6.8, 0.9, -30.0), 74, ""],
	"bunker_inside": [Vector3(-8.3, 1.62, -30.4), Vector3(-2.0, -2.6, -30.0), 80, ""],
	"hatch_sealed": [Vector3(-5.0, 1.62, -21.5), Vector3(-7.4, 1.5, -28.8), 62, "locked"],
	"hatch_open": [Vector3(-5.0, 1.62, -21.5), Vector3(-7.4, 1.5, -28.8), 62, ""],
	"hatch_far": [Vector3(-3.5, 1.62, -11.2), Vector3(-7.4, 1.4, -28.8), 55, "locked"],
	"yard_over_lab": [Vector3(9.0, 2.6, -11.5), Vector3(-3.0, 0.0, -21.0), 70, ""],
	"upper_gate": [Vector3(5.9, 1.62, -5.6), Vector3(2.6, 1.2, -8.0), 66, "locked"],
	"upper_gate_open": [Vector3(5.9, 1.62, -5.6), Vector3(2.6, 1.2, -8.0), 66, ""],
	"outer_gate": [Vector3(17.2, 1.62, -12.4), Vector3(14.1, 1.3, -8.4), 62, "locked"],
	"outer_gate_open": [Vector3(17.2, 1.62, -12.4), Vector3(14.1, 1.3, -8.4), 62, ""],
	"wing_hall": [Vector3(0.6, 1.62, 5.6), Vector3(5.0, 1.3, 3.2), 70, "locked"],
	"wing_hall_open": [Vector3(0.6, 1.62, 5.6), Vector3(5.0, 1.3, 3.2), 70, ""],
	"wing_supply": [Vector3(8.6, 1.62, -6.9), Vector3(8.8, 1.2, -3.0), 70, "locked"],
	"wing_side_door": [Vector3(18.4, 1.62, -3.2), Vector3(13.1, 1.3, -1.5), 60, "locked"],
	"landing_zone": [Vector3(-3.5, 2.4, 20.5), Vector3(-16.0, 0.0, 31.0), 62, "notorch"],
	"landing_zone_high": [Vector3(-16.0, 13.6, 31.0), Vector3(-9.0, 0.0, 22.0), 80, "notorch"],
	"landing_zone_ground": [Vector3(-22.5, 1.62, 36.5), Vector3(-14.0, 0.6, 28.0), 70, ""],
	"mast": [Vector3(26.5, 1.62, 27.5), Vector3(34.6, 8.2, 33.0), 70, "beacon"],
	"mast_foot": [Vector3(31.3, 1.62, 28.4), Vector3(34.2, 1.4, 32.4), 66, ""],
	"mast_from_porch": [Vector3(3.0, 1.62, 11.4), Vector3(35.0, 8.0, 33.0), 55, "notorch+beacon"],
	"leak_lab": [Vector3(4.5, -1.98, -14.6), Vector3(-4.0, -2.6, -22.0), 80, "dark+notorch+moon=8"],
	"leak_lab_storm": [Vector3(0.0, -1.98, -24.2), Vector3(1.5, -2.6, -14.0), 80, "dark+notorch+storm"],
	"leak_corridor": [Vector3(4.5, -1.98, -13.0), Vector3(4.3, -2.2, -7.0), 80, "dark+notorch+moon=8"],
	"leak_tunnel": [Vector3(0.0, -1.98, -25.9), Vector3(-0.4, -2.0, -31.0), 80, "dark+notorch+moon=8+locked+open=cellar"],
	"lab_gas": [Vector3(0.0, -1.98, -24.2), Vector3(1.5, -1.6, -14.0), 80, "gas=north"],
	"lab_blackout": [Vector3(4.5, -1.98, -14.6), Vector3(-4.0, -2.6, -22.0), 80, "blackout+notorch"],
	"rain_yard": [Vector3(0.0, 1.62, 20.0), Vector3(0.0, 1.6, 30.0), 74, "rain"],
	"rain_hall": [Vector3(-5.0, 1.62, 4.0), Vector3(4.0, 2.4, -1.0), 80, "rain"],
	"rain_porch": [Vector3(-6.4, 1.62, 10.6), Vector3(6.0, 1.5, 10.6), 74, "rain"],
	"rain_barn": [Vector3(29.0, 1.62, -27.0), Vector3(29.0, 2.2, -13.0), 80, "rain"],
	"rain_garage": [Vector3(-35.0, 1.62, -22.4), Vector3(-27.0, 1.4, -22.4), 80, "rain"],
	"rain_guest": [Vector3(-33.2, 1.62, 23.25), Vector3(-27.0, 1.4, 23.25), 80, "rain"],
	"rain_shed": [Vector3(27.25, 1.5, 22.3), Vector3(27.25, 1.2, 25.6), 80, "rain"],
	"rain_bunker": [Vector3(-8.3, 1.62, -30.4), Vector3(-2.0, -2.6, -30.0), 80, "rain"],
	"rain_bunker_door": [Vector3(-5.2, 1.62, -30.6), Vector3(-7.9, 1.3, -28.4), 80, "rain"],
	"rain_bunker_cut": [Vector3(-6.0, 1.5, -17.0), Vector3(-6.0, 1.5, -30.0), 40, "rain+notorch+near=11.95"],
	"rain_house_cut": [Vector3(0.0, 2.5, 11.5), Vector3(0.0, 2.5, 0.0), 100, "rain+notorch+near=2.8"],
	"plan_cellar": [Vector3(-2.5, 24.0, -19.0), Vector3(-2.5, 0.0, -19.0), 64, "plan+cut=-0.75"],
	"plan_yard": [Vector3(0.0, 95.0, 4.5), Vector3(0.0, 0.0, 4.0), 60, "plan"],
	"plan_north_yard": [Vector3(-3.0, 40.0, -22.0), Vector3(-3.0, 0.0, -22.0), 60, "plan+locked"],
	"plan_landing": [Vector3(-16.0, 34.0, 31.0), Vector3(-16.0, 0.0, 31.0), 60, "plan"]
}

var map: Node3D
var camera: Camera3D
var torch: SpotLight3D
var energies: Dictionary = {}
var switched_off: Array = []

func _initialize() -> void:
	# A script run with -s never quits by itself when it runs into an error.
	create_timer(540.0).timeout.connect(func() -> void:
		print("SHOTS_WATCHDOG")
		quit(1))
	_run.call_deferred()

func _vector(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

## The value of a state word such as "gas=north", or `fallback` when it is not there.
func _value(words: Array, key: String, fallback: String) -> String:
	for word in words:
		if str(word).begins_with(key + "="):
			return str(word).trim_prefix(key + "=")
	return fallback

## Switches everything that shines in the basement off (or on again): its lamps, the lamp
## glass, the glowing fluid in the tanks. What is still lit then has come in from outside.
## Switching on again comes before the locks of a picture are set (they decide what of the
## basement is shown), switching off after them.
func _darken(dark: bool) -> void:
	for entry in map.flickers:
		if entry.light in map.lab_parts:
			if not energies.has(entry.light):
				energies[entry.light] = entry.energy
			entry.energy = 0.0 if dark else float(energies[entry.light])
			(entry.light as Light3D).light_energy = entry.energy
	(map.mats["steady"] as StandardMaterial3D).albedo_color = Color(0.0, 0.0, 0.0) if dark else Color(2.42, 2.42, 2.42)
	(map.mats["fluid"] as StandardMaterial3D).albedo_color = Color(0.0, 0.0, 0.0, 0.4) if dark else Color(0.16, 0.85, 0.26, 0.4)
	if dark:
		for part in map.lab_parts:
			if part is OmniLight3D and not energies.has(part) and part.visible:
				part.visible = false
				switched_off.append(part)
		for child in map.get_children():
			if child is Label3D and child.visible:
				child.visible = false
				switched_off.append(child)
	else:
		for node in switched_off:
			(node as Node3D).visible = true
		switched_off.clear()

## The rain as it is, or ("rain") every drop as a thick red streak and ten times as many
## of them, to see where roofs really keep it out.
func _rain_look(red: bool) -> void:
	var drops := 30000 if red else 3000
	if map.rain.amount != drops:
		map.rain.amount = drops
	var streak := map.rain.draw_pass_1 as QuadMesh
	streak.size = Vector2(0.03, 0.6) if red else Vector2(0.009, 0.42)
	(streak.material as StandardMaterial3D).albedo_color = Color(1.0, 0.12, 0.08, 1.0) if red else Color(0.62, 0.7, 0.8, 0.13)

func _run() -> void:
	var folder := "user://"
	var views: Dictionary = VIEWS.duplicate()
	var wanted: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			wanted.append_array(Array(arg.trim_prefix("--shots=").split(",")))
		elif arg.begins_with("--view="):
			var parts := arg.trim_prefix("--view=").split(":")
			views[parts[0]] = [_vector(parts[1]), _vector(parts[2]), float(parts[3]) if parts.size() > 3 else 74.0, parts[4] if parts.size() > 4 else ""]
			wanted.append(parts[0])
	if wanted.is_empty():
		wanted = VIEWS.keys()
	DirAccess.make_dir_recursive_absolute(folder)
	# Vsync off: with it this tool has hung for minutes at times, presumably whenever its
	# window was covered by another one and had to wait for the screen.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	map = load("res://scripts/cabin.gd").new()
	map.name = "Waldposten"
	root.add_child(map)
	# Nadja in her room. Her model looks along +Z, the facing is meant for a front of -Z.
	if SoldierVisual.LOOKS.has("nadja"):
		var nadja := NpcVisual.new()
		nadja.look = "nadja"
		root.add_child(nadja)
		nadja.position = map.points.nadja
		nadja.rotation.y = float(map.facings.nadja) + PI
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 240
	root.add_child(camera)
	camera.current = true
	torch = SpotLight3D.new()
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
	for i in range(40):
		await process_frame
	var env: Environment = map.environment
	for name in wanted:
		if not views.has(name):
			print("unknown view ", name)
			continue
		var view: Array = views[name]
		var words: Array = Array(str(view[3]).split("+", false))
		var plan: bool = "plan" in words
		var dark: bool = "dark" in words
		# --- the state of the map for this picture
		var open: Array = [] if "locked" in words else map.AREAS.duplicate()
		if _value(words, "open", "") != "":
			open = Array(_value(words, "open", "").split(","))
		_darken(false)
		# (Puts back what an earlier picture changed: the rain, the light of the sky.)
		map._sink(map.below)
		map.lock_all()
		for area in open:
			map.unlock(area, true)
		map.set_power(not "blackout" in words)
		map.set_gas(_value(words, "gas", ""))
		map.set_beacon("beacon" in words)
		map.set_process(true)
		map.moon.light_energy = map.MOONLIGHT
		map.storm_left = 999.0
		map.flash_left = 0.0
		_rain_look("rain" in words)
		torch.visible = not plan and not "notorch" in words
		env.fog_enabled = not plan
		env.volumetric_fog_enabled = not plan
		for child in map.get_children():
			if child is MeshInstance3D and String(child.name).begins_with("Roof"):
				child.visible = not plan
			elif child is MultiMeshInstance3D:
				child.visible = not plan
		camera.fov = float(view[2])
		camera.position = view[0]
		camera.near = 0.05
		if plan:
			camera.rotation = Vector3(-PI / 2, 0, 0)
			if _value(words, "cut", "") != "":
				camera.near = camera.position.y - float(_value(words, "cut", "0"))
		else:
			camera.look_at(view[1])
			# "near=11.9": everything closer than this is cut away (to look into a building).
			camera.near = float(_value(words, "near", "0.05"))
		# The map notices by itself where the viewer is: below the ground it stops the rain,
		# thins the haze out and draws the hall of the laboratory.
		for i in range(4):
			await process_frame
		if plan:
			# Seen from high above, the hall would not be drawn, and rain would be.
			for part in map.hall_parts:
				(part as Node3D).visible = bool(map.area_open.cellar)
			map.rain.visible = false
			env.ambient_light_energy = 12.0
		if dark:
			_darken(true)
			env.ambient_light_energy = 0.0
		# With a stronger moon the map's own weather is stopped: it would set the moonlight
		# back in every frame.
		var moon := float(_value(words, "moon", "0"))
		if moon > 0.0:
			map.set_process(false)
			map.moon.light_energy = map.MOONLIGHT * moon
		for i in range(30):
			await process_frame
		if "rain" in words:
			# The rain follows the camera; it takes a second until it falls at a new place.
			await create_timer(1.6).timeout
		if "storm" in words:
			# The strike: wait until it is at its brightest.
			map.flash_left = 0.6
			for i in range(3):
				await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
		print("saved ", name)
	if "--fps" in OS.get_cmdline_user_args():
		# Frame rate and draw calls at a few busy places, vsync off, everything open, with
		# the flashlight on as in the game.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		_darken(false)
		map.lock_all()
		for area in map.AREAS:
			map.unlock(area, true)
		map.set_process(true)
		map.moon.light_energy = map.MOONLIGHT
		map._sink(map.below)
		map.set_power(true)
		map.set_gas("")
		_rain_look(false)
		env.fog_enabled = true
		env.volumetric_fog_enabled = true
		torch.visible = true
		camera.near = 0.05
		for child in map.get_children():
			if child is MeshInstance3D and String(child.name).begins_with("Roof"):
				child.visible = true
			elif child is MultiMeshInstance3D:
				child.visible = true
		for name in ["lab_from_entry", "lab_from_north", "nadja_glass_far", "corridor", "cellar_door_open", "hatch_far", "yard_over_lab", "wing_hall_open", "landing_zone_ground"]:
			var view: Array = VIEWS[name]
			camera.fov = float(view[2])
			camera.position = view[0]
			camera.look_at(view[1])
			var until := Time.get_ticks_msec() + 3000
			var frames := 0
			var began := 0
			while Time.get_ticks_msec() < until:
				await process_frame
				# The first second lets the frame rate settle.
				if began == 0 and Time.get_ticks_msec() > until - 2000:
					began = Time.get_ticks_msec()
					frames = 0
				frames += 1
			print("PERF %s: %d FPS, %d draw calls, %d primitives" % [name, roundi(frames * 1000.0 / maxf(1.0, Time.get_ticks_msec() - began)), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	print("SHOTS_COMPLETE")
	quit()
