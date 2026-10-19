class_name Brush
extends RefCounted
## The look of a button: a stroke of paint instead of a box. Its two ends and its edges are
## ragged, like those of a flat brush, and it is a little dry and streaky inside. One picture
## (three, to tell the buttons apart) is made once and tinted for each use; it is cut into
## nine so that the ragged ends keep their size on a button of any width.

const WIDTH := 320
const HEIGHT := 64
## How much of the picture each side keeps as it is.
const CUT_X := 48
const CUT_Y := 12
static var pictures: Array = []

static func picture(variant: int) -> ImageTexture:
	if pictures.is_empty():
		for seed in range(3):
			pictures.append(_bake(seed * 17 + 5))
	return pictures[variant % pictures.size()]

static func _bake(seed: int) -> ImageTexture:
	var bristles := FastNoiseLite.new()
	bristles.seed = seed
	bristles.frequency = 0.55
	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = seed + 1
	edge_noise.frequency = 0.09
	var dry := FastNoiseLite.new()
	dry.seed = seed + 2
	dry.frequency = 0.04
	# The ends: each row of the stroke stops somewhere else, as a bristle does.
	var left: PackedFloat32Array = PackedFloat32Array()
	var right: PackedFloat32Array = PackedFloat32Array()
	for y in range(HEIGHT):
		left.append(24.0 + bristles.get_noise_2d(y, 3.0) * 16.0)
		right.append(float(WIDTH - 1) - (24.0 + bristles.get_noise_2d(y, 91.0) * 16.0))
	var top: PackedFloat32Array = PackedFloat32Array()
	var bottom: PackedFloat32Array = PackedFloat32Array()
	for x in range(WIDTH):
		top.append(3.0 + edge_noise.get_noise_2d(x, 7.0) * 2.0)
		bottom.append(float(HEIGHT - 1) - (3.0 + edge_noise.get_noise_2d(x, 55.0) * 2.0))
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var across := minf(float(x) - left[y], right[y] - float(x)) / 12.0
			var down := minf(float(y) - top[x], bottom[x] - float(y)) / 4.0
			var shape := smoothstep(0.0, 1.0, clampf(minf(across, down), 0.0, 1.0))
			# Streaks along the stroke where the brush ran dry.
			var streak := 0.84 + 0.16 * (dry.get_noise_2d(x * 0.35, y * 5.0) * 0.5 + 0.5)
			image.set_pixel(x, y, Color(1, 1, 1, shape * streak))
	return ImageTexture.create_from_image(image)

## A stroke in `tint` (its alpha is how strongly it shows).
static func style(tint: Color, variant: int = 0, left: float = 48.0, right: float = 36.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = picture(variant)
	box.texture_margin_left = CUT_X
	box.texture_margin_right = CUT_X
	box.texture_margin_top = CUT_Y
	box.texture_margin_bottom = CUT_Y
	box.modulate_color = tint
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
