extends SceneTree
## Side pictures of every firearm for the lines of the weapon shop (ShopIcons falls back to
## the drawn outline without one): the real model from the side, lit like the shop's
## picture, on a transparent ground. Writes assets/menu/weapons/<id>.png. Needs graphics:
##   tools\godot_bg.ps1 -Render -GodotArgs "-s res://tools/menu_weapon_thumbs.gd"

const SIZE := Vector2(320, 150)

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	var folder := "res://assets/menu/weapons"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var show := WeaponShow.new()
	show.size = SIZE
	root.add_child(show)
	await _frames(4)
	for id: String in Survivor.ORDER:
		show.show_weapon(id)
		show.manual = true
		show.yaw = 0.0
		show.pitch = 0.0
		show._reframe()
		await _frames(10)
		await RenderingServer.frame_post_draw
		show.stage.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id + ".png")))
		print("THUMB ", id)
	quit(0)
