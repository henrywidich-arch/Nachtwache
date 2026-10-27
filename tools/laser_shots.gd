extends SceneTree
## Pictures of the laser module and of the reticle workshop's marks: guns from GUNS held
## from the hip in a dark room, the laser's dot on the plastered wall ahead (as the player
## sees it, the beam from the module's mouth); the module up close on the gun by itself;
## aimed through the red dot and the P90's ring in the default red and in other colours.
## Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/laser_shots.gd -- --out=<folder> [--guns=p90,ump,g36]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://laser"
	var guns: Array = ["p90", "ump", "g36", "rifle", "ak", "mp7", "wirbel", "falke"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--guns="):
			guns = Array(arg.trim_prefix("--guns=").split(","))
	DirAccess.make_dir_recursive_absolute(folder)
	# A dark room: a plastered wall four metres ahead, a floor, a dim cold light from above.
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.01, 0.012, 0.016)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.25, 0.28, 0.34)
	world.environment.ambient_light_energy = 0.3
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.glow_enabled = true
	root.add_child(world)
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.55, 0.53, 0.5)
	plaster.roughness = 0.95
	var floor_paint := StandardMaterial3D.new()
	floor_paint.albedo_color = Color(0.2, 0.2, 0.21)
	_block(Vector3(0, 1.5, -4.2), Vector3(8, 3, 0.2), plaster)
	_block(Vector3(0, -0.05, 0), Vector3(8, 0.1, 10), floor_paint)
	_block(Vector3(-2.6, 1.5, -2), Vector3(0.2, 3, 5), plaster)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1.5, 2.8, -1.0)
	lamp.light_color = Color(0.6, 0.7, 1.0)
	lamp.light_energy = 0.35
	lamp.omni_range = 7.0
	root.add_child(lamp)
	var camera := Camera3D.new()
	camera.fov = Survivor.BASE_FOV
	camera.near = 0.02
	camera.position = Vector3(0, 1.62, 0.5)
	root.add_child(camera)
	camera.current = true
	var laser := LaserSight.new()
	laser.auto_off = false
	root.add_child(laser)
	for i in range(10):
		await process_frame
	for id: String in guns:
		var gun := WeaponView.build(id)
		camera.add_child(gun)
		var view: Dictionary = WeaponView.VIEWS[id]
		gun.position = view.hip
		gun.rotation = (view.hip_angles as Vector3) * (PI / 180.0)
		var module := gun.get_node_or_null("Mod_laser") as Node3D
		if module == null:
			print("no laser on ", id)
			gun.queue_free()
			continue
		module.show()
		# Slightly off the middle of the wall, as a player would hold it.
		camera.rotation = Vector3(deg_to_rad(-3.0), deg_to_rad(4.0), 0)
		await _aim(laser, camera, gun, 0)
		await _save(folder.path_join("laser_huefte_%s.png" % id))
		if id in ["ump", "p90"]:
			# Aimed: through the red dot (the P90 through its ring), the dot on the wall.
			var sight := gun.get_node_or_null("Mod_reddot") as Node3D
			if id != "p90" and sight != null:
				sight.show()
				gun.position = WeaponView.sight_aim(id, "reddot")
				gun.rotation = Vector3.ZERO
			else:
				gun.position = view.aim
				gun.rotation = (view.get("aim_angles", Vector3.ZERO) as Vector3) * (PI / 180.0)
			await _aim(laser, camera, gun, 0)
			await _save(folder.path_join("laser_zielen_%s.png" % id))
			# The same with the workshop's marks in other colours and sizes.
			for look: Array in [["gruen", Color(0.15, 1.0, 0.2), 1.4, 1.6], ["cyan", Color(0.1, 0.9, 1.0), 0.8, 0.7]]:
				Reticle.choose(look[1], look[2], look[3], 1.0)
				await _aim(laser, camera, gun, 0)
				await _save(folder.path_join("werkstatt_%s_%s.png" % [id, look[0]]))
			Reticle.reset()
			if sight != null:
				sight.hide()
		gun.queue_free()
		await process_frame
	laser.hide()
	# --- the module up close on a gun by itself (the shop's model), in a plain light
	world.environment.background_color = Color(0.32, 0.34, 0.37)
	world.environment.ambient_light_energy = 1.0
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	root.add_child(sun)
	camera.rotation = Vector3.ZERO
	camera.fov = 30.0
	for id: String in ["p90", "ump", "g36"]:
		var shown := WeaponView.display(id)
		shown.position = Vector3(0, 1.4, -0.9)
		root.add_child(shown)
		var module := shown.find_child("Mod_laser", true, false) as Node3D
		if module == null:
			shown.queue_free()
			continue
		module.show()
		await process_frame
		var mouth := module.find_child("LaserEmitter", true, false) as Node3D
		var at := mouth.global_position + Vector3(0.0, -0.004, 0.03)
		camera.position = at + Vector3(-0.26, 0.12, 0.2)
		camera.look_at(at)
		await _save(folder.path_join("laser_nah_%s.png" % id))
		shown.queue_free()
		await process_frame
	quit()

func _block(at: Vector3, extent: Vector3, paint: Material) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extent
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = extent
	mesh.mesh = cube
	mesh.material_override = paint
	body.add_child(mesh)
	root.add_child(body)

## Puts the dot as Survivor._update_laser does: along the view, the beam from the module's
## mouth (placed where the eye sees it in the view's own field of view).
func _aim(laser: LaserSight, camera: Camera3D, gun: Node3D, _rest: int) -> void:
	await process_frame
	var mouth := gun.find_child("LaserEmitter", true, false) as Node3D
	var local := camera.to_local(mouth.global_position)
	var ratio := tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(WeaponView.VIEW_FOV) * 0.5)
	var emitter := camera.to_global(Vector3(local.x * ratio, local.y * ratio, local.z))
	for i in range(4):
		laser.aim(camera.global_position, -camera.global_basis.z, emitter, camera.global_position)
		await physics_frame

func _save(path: String) -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
