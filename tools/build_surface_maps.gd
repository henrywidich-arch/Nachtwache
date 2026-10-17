extends SceneTree
## Offline PBR preparation; no per-frame texture generation or extra geometry.
func _initialize() -> void:
	for kind: String in ["wood", "concrete", "earth"]:
		var base := "res://assets/surfaces/" + kind
		var image := Image.load_from_file(base + "_albedo.png")
		if image == null:
			quit(1)
			return
		image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		image.save_png(base + "_albedo.png")
		var normal := image.duplicate()
		normal.bump_map_to_normal_map(2.0 if kind == "wood" else 2.6)
		normal.save_png(base + "_normal.png")
		var roughness := Image.create(1024, 1024, false, Image.FORMAT_L8)
		for y in range(1024):
			for x in range(1024):
				var luminance := image.get_pixel(x, y).get_luminance()
				var value := (0.7 if kind == "wood" else 0.82) + luminance * 0.16
				roughness.set_pixel(x, y, Color(value, value, value))
		roughness.save_png(base + "_roughness.png")
		print("SURFACE_READY: %s 1024px albedo, normal, roughness" % kind)
	quit()
