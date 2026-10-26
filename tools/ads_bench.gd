extends SceneTree
## How long each programme of TokyoAds takes to be drawn: 60 frames each at full speed,
## the time and the draw calls of a frame. Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/ads_bench.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in range(10):
		await process_frame
	var from := Time.get_ticks_usec()
	for i in range(120):
		await process_frame
	var base := (Time.get_ticks_usec() - from) / 120.0
	print("BENCH empty frame %.2f ms" % (base / 1000.0))
	for program: String in TokyoAds.PROGRAMS:
		var view := SubViewport.new()
		view.size = Vector2i(384, 300)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var spot := TokyoAds.new()
		spot.setup(program, view.size)
		view.add_child(spot)
		for i in range(5):
			await process_frame
		from = Time.get_ticks_usec()
		var calls := 0
		for i in range(120):
			spot.step(1.0 / 60.0)
			await process_frame
			calls = maxi(calls, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var took := (Time.get_ticks_usec() - from) / 120.0 - base
		print("BENCH %s %.2f ms, %d draw calls" % [program, took / 1000.0, calls])
		view.queue_free()
		await process_frame
	quit()
