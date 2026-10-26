extends SceneTree
## A picture of the play HUD with the hold ring (HoldRing) low in the middle, and a crate of
## throwables (GrenadeFinds) put down in front of the survivor. Run drawing:
##   tools\godot_bg.ps1 -Render "-s res://tools/hud_ring_shot.gd -- --out=C:/shots"

var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# (No story intro over the picture.)
	game.check_mode = true
	root.add_child(game)
	await process_frame
	game.profile.stored = false
	game.profile.mission = 1
	game.team_enabled = false
	game.start_run()
	for i in range(30):
		await physics_frame
	var player: Node3D = game.player
	var ahead := -player.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	for extra in ["molotov", "heal", "flashbang"]:
		var id := 0
		for k in range(1, 200):
			if GrenadeFinds.extra_of(k + 9000) == extra:
				id = k + 9000
				break
		for crate in game.pickups.get_children():
			if crate.get_meta("kind") == GrenadeFinds.KIND:
				crate.queue_free()
		game.drop_pickup(player.global_position + ahead * 1.9, GrenadeFinds.KIND, id)
		player.camera.rotation.x = -0.55
		# Two of them with their open side to the survivor, one as it happens to lie.
		if extra != "heal":
			for crate in game.pickups.get_children():
				if crate.get_meta("kind") == GrenadeFinds.KIND:
					crate.rotation.y = atan2(-ahead.x, -ahead.z) + 0.35
		for i in range(40):
			await process_frame
		# The ring as it shows while something takes its time, two thirds along.
		game.hud.set_process(false)
		game.hud.hold_bar.visible = true
		game.hud.hold_bar.value = 0.66
		game.hud.interaction_label.text = "[E] halten  ·  Nächste Runde starten"
		for i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var path := folder.path_join("hud_ring_%s.png" % extra)
		root.get_texture().get_image().save_png(path)
		print("shot ", path)
		game.hud.set_process(true)
	quit()
