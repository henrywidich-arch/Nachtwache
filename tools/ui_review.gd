extends Node
## Render the actual maps for their menu cards, then capture the revised interface.
## Godot --path <project> -- --ui-review-check --no-warm-up
var game: Node3D
var directory := "res://tools/ui_review"

func wait_frames(count: int = 6) -> void:
	for i in range(count):
		await get_tree().process_frame

func capture(path: String, small: bool = false) -> void:
	await wait_frames()
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	if small:
		picture.resize(1100, 619, Image.INTERPOLATE_LANCZOS)
	picture.save_png(path)
	print("UI_CAPTURE " + ProjectSettings.globalize_path(path))

func run(owner_game: Node3D) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/menu"))
	game.set_render_scale(1.0, false)
	game.team_enabled = false
	game.intro_skipped = true
	game.profile.mission = 1
	game.start_run()
	game.set_process(false)
	game.hud.root.hide()
	var camera := Camera3D.new()
	camera.fov = 57.0
	camera.cull_mask = 1
	game.add_child(camera)
	camera.global_position = Vector3(0, 5, 26)
	camera.look_at(Vector3(0, 2.6, 0))
	camera.current = true
	await capture("res://assets/menu/hof19.png", true)
	camera.global_position = Vector3(0.65, 1.5, 1.4)
	camera.look_at(game.shopkeeper.global_position + Vector3(0, 0.9, 0))
	await capture(directory + "/shopkeeper.png")
	game.profile.mission = 2
	game.hive.seed_wanted = -1
	game.start_run()
	game.set_process(false)
	game.hive.set_process(false)
	game.hud.root.hide()
	camera.global_position = Vector3(24, 8, 48)
	camera.look_at(Vector3(-3, 4.5, 14))
	camera.current = true
	await capture("res://assets/menu/villa.png", true)
	camera.global_position = Vector3(1.6, 2.6, 15)
	camera.look_at(Vector3(6.84, 2.6, 15))
	await capture(directory + "/photo.png")
	camera.queue_free()
	game.return_to_menu()
	game.hud.root.show()
	await capture(directory + "/main.png")
	game.hud._open_settings("main")
	await capture(directory + "/settings.png")
	game.hud.show_menu("graphics")
	await capture(directory + "/settings_graphics.png")
	(game.hud.modal.find_child("FPSCounterButton", true, false) as Button).pressed.emit()
	await capture(directory + "/settings_fps.png")
	(game.hud.modal.find_child("FPSCounterButton", true, false) as Button).pressed.emit()
	game.hud.controls_tab = "combat"
	game.hud.show_menu("controls")
	await capture(directory + "/controls.png")
	game.hud.show_menu("career")
	await capture(directory + "/career.png")
	game.hud.show_menu("skins")
	await capture(directory + "/skins.png")
	game.hud.show_menu("changelog")
	await capture(directory + "/patchnotes.png")
	game.hud.show_menu("play")
	await capture(directory + "/play.png")
	game.profile.mission = 1
	game.start_run()
	game.set_process(false)
	game.player.global_position = Vector3(0, 0.05, 22)
	game.player.rotation.y = 0
	game.player.camera.rotation = Vector3.ZERO
	game.hud.radio_left = 0
	game.hud.banner_left = 0
	game.hud._process(0.1)
	await capture(directory + "/hud.png")
	game.hud.kill_feed("MAULER", 100, false)
	game.hud.kill_feed("SCORPION · RAVAGER", 200, false, true)
	game.hud.kill_feed("MAULER", 150, true)
	game.hud.teammate_down("VIPER")
	await capture(directory + "/events.png")
	game.hud.clear_feed()
	game.player.health = 20
	game.hud.damage_from(game.player.global_position + Vector3(10, 0, 0))
	game.hud.damage_from(game.player.global_position + Vector3(0, 0, 10))
	game.hud._process(0.01)
	await capture(directory + "/wounded.png")
	game.player.health = 100
	Input.action_press("aim")
	await wait_frames(20)
	await capture(directory + "/aim.png")
	Input.action_release("aim")
	game.hud.hurt_events.clear()
	game.player.items.grenade = 2
	Input.action_press("throw_grenade")
	game.player.ready_throw("grenade")
	await wait_frames(12)
	await capture(directory + "/throw_ready.png")
	game.player.set_physics_process(false)
	game.player.throw_swing = game.player.THROW_SWING * 0.55
	game.player._animate_throw(0.0)
	await capture(directory + "/throw_windup.png")
	game.player.throw_swing = game.player.THROW_SWING * 0.05
	game.player._animate_throw(0.0)
	await capture(directory + "/throw_forward.png")
	game.player._hold_throw(game.player.THROW_SWING)
	game.player._animate_throw(0.0)
	game.fx.hide_arc()
	await capture(directory + "/throw_release.png")
	game.player._animate_throw(game.player.THROW_RECOVER * 0.5)
	await capture(directory + "/throw_recovery.png")
	Input.action_release("throw_grenade")
	game.player.put_away()
	game.player.throw_recover = 0
	game.player.set_physics_process(true)
	game.player.global_position = game.cabin.points.shop + Vector3(0, 0.05, 0)
	game.credits = 1240
	game.open_shop()
	await capture(directory + "/shop.png")
	game.hud.counter.open_tab("melee")
	game.hud.counter.pick("melee", "axe")
	await capture(directory + "/melee.png")
	game.credits = 5000
	game.buy_weapon("g18")
	game.hud.counter.open_tab("sidearms")
	game.hud.counter.pick("weapon", "g18")
	(game.hud.counter.detail.find_child("Slot_sight", true, false) as Button).pressed.emit()
	(game.hud.counter.detail.find_child("Attachment_scope", true, false) as Button).pressed.emit()
	await capture(directory + "/weapon_editor.png")
	game.hud.counter.action.pressed.emit()
	(game.hud.counter.detail.find_child("Slot_style", true, false) as Button).pressed.emit()
	(game.hud.counter.detail.find_child("Attachment_akimbo", true, false) as Button).pressed.emit()
	await capture(directory + "/akimbo_preview.png")
	game.hud.counter.action.pressed.emit()
	game.resume_run()
	var benches: Array = game.cabin.stations.filter(func(station: Dictionary) -> bool: return str(station.kind) == "upgrade")
	game.player.global_position = (benches[0].pos as Vector3) + Vector3(0, 0.05, 0)
	game.open_bench()
	game.hud.counter.pick("bench", "rifle")
	await capture(directory + "/workbench.png")
	(game.hud.counter.detail.find_child("Upgrade_damage", true, false) as Button).mouse_entered.emit()
	await capture(directory + "/workbench_preview.png")
	(game.hud.counter.detail.find_child("Upgrade_damage", true, false) as Button).mouse_exited.emit()
	game.buy_upgrade("damage", "rifle")
	await get_tree().create_timer(0.7).timeout
	await capture(directory + "/workbench_upgraded.png")
	game.resume_run()
	game.player.global_position = Vector3(0, 0.05, 22)
	game.player.rotation.y = 0
	game.player.camera.rotation = Vector3.ZERO
	var mate := RemoteSurvivor.new()
	mate.game = game
	mate.look = "viper"
	game.mates.add_child(mate)
	mate.global_position = game.player.global_position + Vector3(0, 0, -6)
	mate.net_position = mate.global_position
	mate.label = "VIPER"
	mate.kills = 18
	game.net.remote = mate
	game.kills = 24
	Input.action_press("scoreboard")
	await capture(directory + "/scoreboard.png")
	Input.action_release("scoreboard")
	# Match actual world geometry: visual-only meshes cannot enable the world gate.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = Vector3(3, 2.5, 0.25)
	shape.shape = solid
	blocker.add_child(shape)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = solid.size
	wall.mesh = box
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("313a3d")
	wall.material_override = paint
	blocker.add_child(wall)
	game.add_child(blocker)
	blocker.global_position = game.player.global_position + Vector3(0, 1.25, -4)
	await wait_frames(12)
	await capture(directory + "/outline_occluded.png")
	wall.hide()
	blocker.collision_layer = 0
	await wait_frames(12)
	await capture(directory + "/outline_visible.png")
	Input.action_press("aim")
	await wait_frames(20)
	await capture(directory + "/outline_aim_from_behind.png")
	Input.action_release("aim")
	print("UI_REVIEW_DONE")
	get_tree().quit()
