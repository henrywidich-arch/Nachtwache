extends SceneTree
## Makes the villa's pictures (VillaPictures.CATALOG) from his originals: each one at most
## 1024 px on its longer side, as a lossy WebP (the originals are PNGs of up to 8 MB), into
## assets/villa/pictures/<id>.webp. His folder is only read.
##   Godot --headless --path <project> -s res://tools/villa_pictures_import.gd -- --from="D:/Games/AI Games/Nachtwache/bilde"
## Then --import, so that the engine compresses them for the video card (see their .import).

const LONGEST := 1024
const QUALITY := 0.84

func _initialize() -> void:
	var from := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			from = arg.trim_prefix("--from=").trim_suffix("/")
	if from == "":
		print("VILLA_PICTURES give --from=<his folder>")
		quit(1)
		return
	var out := ProjectSettings.globalize_path(VillaPictures.FOLDER)
	DirAccess.make_dir_recursive_absolute(out)
	var made := 0
	var total := 0
	for entry: Array in VillaPictures.CATALOG:
		var image := Image.load_from_file(from + "/" + str(entry[1]))
		if image == null or image.is_empty():
			print("VILLA_PICTURES missing %s" % str(entry[1]))
			continue
		image.convert(Image.FORMAT_RGB8)
		var longest := maxi(image.get_width(), image.get_height())
		if longest > LONGEST:
			var share := float(LONGEST) / longest
			image.resize(roundi(image.get_width() * share), roundi(image.get_height() * share), Image.INTERPOLATE_LANCZOS)
		var path := out.path_join(str(entry[0]) + ".webp")
		image.save_webp(path, true, QUALITY)
		var size := FileAccess.get_file_as_bytes(path).size()
		total += size
		made += 1
		print("VILLA_PICTURE %s %dx%d %d KB" % [str(entry[0]), image.get_width(), image.get_height(), size / 1024])
	print("VILLA_PICTURES made=%d of %d total=%d KB" % [made, VillaPictures.CATALOG.size(), total / 1024])
	quit(0 if made == VillaPictures.CATALOG.size() else 1)
