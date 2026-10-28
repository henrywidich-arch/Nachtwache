extends SceneTree
## Cuts a painted skin picture (a weapon from the side on a studio backdrop) free for
## WeaponSkins: the backdrop - also a shaded one with a floor and a soft shadow - and
## anything cut off at the picture's edge (a stray part of another weapon) become flat
## magenta, and the picture is trimmed to the weapon. Headless:
##   tools\godot_bg.ps1 "-s res://tools/skin_prepare.gd -- --in=C:/a.png --out=res://assets/skins/x.png [--rect=x,y,w,h]"
## Several at once: --list=<file> with one "in|out[|x,y,w,h]" per line.

## Neighbouring backdrop pixels differ by less than this (sum of the three channels, 0-255).
const STEP := 10
## ...and lie near the backdrop at the picture's edges in that row: at most this much
## lighter (pale parts of a weapon stay), or this much darker (soft shadows go).
const LIGHTER := 24
const DARKER := 150
## The backdrop is grey: its channels lie this close together.
const GREY := 34
const WIDEST := 1800
## Below this row (of the source picture) lies a studio floor: a shadow there may be as
## dark as it likes (a fourth field of a --list line; -1: no floor).
static var floor_at := -1
## Boxes painted over with the backdrop first, in the cut-out's pixels (a fifth field:
## "x,y,w,h;x,y,w,h"): stray parts of something else that touch the weapon.
static var erase := ""
const BACK := Color(1, 0, 1)

func _initialize() -> void:
	var jobs: Array = []
	var one := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--in="):
			one["in"] = arg.trim_prefix("--in=")
		elif arg.begins_with("--out="):
			one["out"] = arg.trim_prefix("--out=")
		elif arg.begins_with("--rect="):
			one["rect"] = arg.trim_prefix("--rect=")
		elif arg.begins_with("--list="):
			for line in FileAccess.get_file_as_string(arg.trim_prefix("--list=")).split("\n"):
				var parts := line.strip_edges().split("|")
				if parts.size() >= 2:
					jobs.append({"in": parts[0], "out": parts[1], "rect": parts[2] if parts.size() > 2 else "", "floor": int(parts[3]) if parts.size() > 3 and parts[3] != "" else -1, "erase": parts[4] if parts.size() > 4 else ""})
	if one.has("in"):
		jobs.append(one)
	for job: Dictionary in jobs:
		floor_at = int(job.get("floor", -1))
		erase = str(job.get("erase", ""))
		_prepare(str(job.in), str(job.out), str(job.get("rect", "")))
	quit()

func _prepare(source: String, target: String, rect: String) -> void:
	var image := Image.load_from_file(source)
	if image == null:
		printerr("cannot read ", source)
		return
	image.convert(Image.FORMAT_RGBA8)
	if rect != "":
		var n := rect.split(",")
		image = image.get_region(Rect2i(int(n[0]), int(n[1]), int(n[2]), int(n[3])))
	for box in erase.split(";", false):
		var n := box.split(",")
		image.fill_rect(Rect2i(int(n[0]), int(n[1]), int(n[2]), int(n[3])), image.get_pixel(2, image.get_height() / 2))
	if image.get_width() > WIDEST:
		if floor_at >= 0:
			floor_at = int(floor_at * float(WIDEST) / image.get_width())
		image.resize(WIDEST, int(image.get_height() * float(WIDEST) / image.get_width()), Image.INTERPOLATE_LANCZOS)
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	# The backdrop: everything grey reached from the edge in small steps.
	var back := PackedByteArray()
	back.resize(w * h)
	var stack := PackedInt32Array()
	for x in range(w):
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in range(h):
		stack.append(y * w)
		stack.append(y * w + w - 1)
	for at in stack:
		back[at] = 1
	while not stack.is_empty():
		var at: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := at % w
		var y := at / w
		for next: int in [at - 1 if x > 0 else -1, at + 1 if x < w - 1 else -1, at - w if y > 0 else -1, at + w if y < h - 1 else -1]:
			if next < 0 or back[next] == 1:
				continue
			if _near(data, at, next) and _grey(data, next) and _like_edge(data, next, w):
				back[next] = 1
				stack.append(next)
	# The parts that are left: only those not cut off by the picture's edge count.
	var group := PackedInt32Array()
	group.resize(w * h)
	var low := Vector2i(w, h)
	var high := Vector2i(-1, -1)
	var keep := PackedByteArray()
	keep.resize(w * h)
	var parts: Array = []
	for start in range(w * h):
		if back[start] == 1 or group[start] != 0:
			continue
		var members := PackedInt32Array([start])
		group[start] = 1
		var edge := false
		var i := 0
		while i < members.size():
			var at: int = members[i]
			i += 1
			var x := at % w
			var y := at / w
			# (Where the stray parts are painted over, the weapon may reach the edge itself.)
			if erase == "" and (x <= 1 or y <= 1 or x >= w - 2 or y >= h - 2):
				edge = true
			for next: int in [at - 1 if x > 0 else -1, at + 1 if x < w - 1 else -1, at - w if y > 0 else -1, at + w if y < h - 1 else -1]:
				if next >= 0 and back[next] == 0 and group[next] == 0:
					group[next] = 1
					members.append(next)
		if edge:
			# (Cut off by the edge: part of another weapon in the same picture.)
			for at in members:
				group[at] = 2
		elif members.size() >= 60:
			parts.append(members)
	# The weapon: the biggest part, and what is not much smaller (noise in the backdrop is).
	var biggest := 0
	for members: PackedInt32Array in parts:
		biggest = maxi(biggest, members.size())
	for members: PackedInt32Array in parts:
		if members.size() < biggest / 20:
			continue
		for at in members:
			keep[at] = 1
			var x := at % w
			var y := at / w
			low = Vector2i(mini(low.x, x), mini(low.y, y))
			high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x < 0:
		printerr("no weapon in ", source)
		return
	for at in range(w * h):
		if back[at] == 1 or group[at] == 2:
			data[at * 4] = 255
			data[at * 4 + 1] = 0
			data[at * 4 + 2] = 255
	var cleaned := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	low = Vector2i(maxi(0, low.x - 3), maxi(0, low.y - 3))
	high = Vector2i(mini(w - 1, high.x + 3), mini(h - 1, high.y + 3))
	var cut := cleaned.get_region(Rect2i(low, high - low + Vector2i.ONE))
	cut.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(target)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	cut.save_png(path)
	print("prepared %s -> %s (%dx%d)" % [source.get_file(), target, cut.get_width(), cut.get_height()])

static func _near(data: PackedByteArray, a: int, b: int) -> bool:
	return absi(data[a * 4] - data[b * 4]) + absi(data[a * 4 + 1] - data[b * 4 + 1]) + absi(data[a * 4 + 2] - data[b * 4 + 2]) < STEP

## Near what the backdrop is at the brighter of the two edges of this row (a vignette
## darkens the other).
static func _like_edge(data: PackedByteArray, a: int, w: int) -> bool:
	var x := a % w
	var row := a - x
	var d := 0.0
	for c in range(3):
		d += float(data[a * 4 + c]) - maxf(float(data[row * 4 + c]), float(data[(row + w - 1) * 4 + c]))
	if floor_at >= 0 and a / w >= floor_at:
		return d < LIGHTER
	return d < LIGHTER and d > -DARKER

static func _grey(data: PackedByteArray, a: int) -> bool:
	var r: int = data[a * 4]
	var g: int = data[a * 4 + 1]
	var b: int = data[a * 4 + 2]
	return maxi(r, maxi(g, b)) - mini(r, mini(g, b)) < GREY
