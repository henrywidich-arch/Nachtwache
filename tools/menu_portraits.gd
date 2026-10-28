extends SceneTree
## Head-and-shoulder pictures of every look for the menu (companion tiles on SPIELEN, the
## player card on the login page): the real SoldierVisual, lit like the skins preview, on a
## transparent ground. Writes assets/menu/portraits/<look>.png. Needs graphics:
##   tools\godot_bg.ps1 -Render -GodotArgs "-s res://tools/menu_portraits.gd"

const SIZE := 256

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	var folder := "res://assets/menu/portraits"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var show := WeaponShow.new()
	show.size = Vector2(SIZE, SIZE)
	root.add_child(show)
	await _frames(4)
	for look: String in Profile.SKINS:
		if not SoldierVisual.LOOKS.has(look):
			print("PORTRAIT_SKIP ", look)
			continue
		show.show_soldier(look)
		show.manual = true
		show.yaw = 0.42
		show.pitch = 0.0
		var height := float(SoldierVisual.LOOKS[look].height)
		var head := height * 0.5 - 0.17
		await _frames(3)
		show.camera.fov = 27.0
		show.camera.position = Vector3(1.55, head + 0.06, 0.0)
		show.camera.look_at(Vector3(0, head - 0.06, 0))
		await _frames(12)
		await RenderingServer.frame_post_draw
		var picture := show.stage.get_texture().get_image()
		picture.save_png(ProjectSettings.globalize_path(folder.path_join(look + ".png")))
		print("PORTRAIT ", look)
	quit(0)
