extends SceneTree
## Each programme of the LED walls of the simulation hall (TokyoAds) as a picture, at a few
## moments of its loop. Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/ads_sheet.gd -- --out=<folder>

const SHAPES := {"sim_warning": Vector2i(384, 220), "ticker": Vector2i(384, 200), "karaoke": Vector2i(256, 384), "anime_night": Vector2i(160, 384), "anime_sakura": Vector2i(160, 384), "sakura_band": Vector2i(384, 170), "anime_tech": Vector2i(190, 384), "anime_pachinko": Vector2i(384, 300), "anime_pachinko_b": Vector2i(150, 384)}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	for program: String in TokyoAds.PROGRAMS:
		var view := SubViewport.new()
		var px: Vector2i = SHAPES[program] * 2
		view.size = px
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var spot := TokyoAds.new()
		spot.setup(program, px)
		view.add_child(spot)
		for moment in [1.0, 4.5, 8.0]:
			spot.clock = moment
			spot.step(0.0)
			for i in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png(folder.path_join("%s_%02d.png" % [program, int(moment * 10)]))
		view.queue_free()
		print("saved ", program)
	quit()
