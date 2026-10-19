class_name BulletHoles
extends Node3D
## Holes where bullets have struck a wall, a floor or a prop. Only so many stay at once
## (`limit`): the oldest one is taken for the next, so that nothing piles up and the cost
## stays the same however long the night. Each is a small decal on the surface that was hit.

## What the graphics page offers: the name and the number kept.
const LEVELS := [["AUS", 0], ["WENIGE", 24], ["NORMAL", 64], ["VIELE", 160]]
const DEFAULT_LEVEL := 2
const SIZE := 0.17
## Far from the eye they fade away instead of being drawn for nothing.
const FADE_FROM := 26.0

var game: Node3D
var limit := 64
var pool: Array[Decal] = []
var next := 0
var textures: Array[ImageTexture] = []
var random := RandomNumberGenerator.new()

func _ready() -> void:
	name = "BulletHoles"
	random.seed = 4417
	for variant in range(3):
		textures.append(_make_texture(variant))

## The picture of a hole: a dark middle with a torn edge, a ring of chipped paint or wood
## around it, and a faint dusting beyond. Alpha says where it covers the surface.
func _make_texture(variant: int) -> ImageTexture:
	var size := 64
	var noise := FastNoiseLite.new()
	noise.seed = 90 + variant * 31
	noise.frequency = 0.16
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := Vector2(size - 1, size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var offset := (Vector2(x, y) - middle) / (size * 0.5)
			var torn := offset.length() + noise.get_noise_2d(x, y) * 0.22
			var color := Color(0, 0, 0, 0)
			if torn < 0.17:
				color = Color(0.01, 0.01, 0.012, 1.0)
			elif torn < 0.3:
				var edge := 1.0 - (torn - 0.17) / 0.13
				color = Color(0.05, 0.04, 0.035, 0.35 + 0.6 * edge)
			elif torn < 0.62:
				var spread := 1.0 - (torn - 0.3) / 0.32
				var chips := noise.get_noise_2d(x * 2.3 + 40.0, y * 2.3) * 0.5 + 0.5
				color = Color(0.5, 0.46, 0.4, spread * spread * 0.32 * chips)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

## Chooses how many holes are kept (BulletHoles.LEVELS); fewer than are there removes the oldest.
func set_limit(count: int) -> void:
	limit = maxi(0, count)
	while pool.size() > limit:
		var gone: Decal = pool.pop_back()
		gone.queue_free()
	next = next % maxi(1, pool.size())

func add(point: Vector3, normal: Vector3) -> void:
	if limit <= 0 or textures.is_empty():
		return
	var mark: Decal
	if pool.size() < limit:
		mark = Decal.new()
		mark.cull_mask = 1
		mark.distance_fade_enabled = true
		mark.distance_fade_begin = FADE_FROM
		mark.distance_fade_length = 6.0
		mark.upper_fade = 0.4
		mark.lower_fade = 0.4
		add_child(mark)
		pool.append(mark)
		next = pool.size() % limit
	else:
		mark = pool[next]
		next = (next + 1) % pool.size()
	var scale := random.randf_range(0.8, 1.3)
	mark.texture_albedo = textures[random.randi() % textures.size()]
	mark.size = Vector3(SIZE * scale, 0.16, SIZE * scale)
	# The decal looks along its own -Y into the surface: Y is the normal, turned about it.
	var up := normal.normalized()
	var across := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var basis := Basis(across, up, across.cross(up)).rotated(up, random.randf() * TAU)
	mark.global_transform = Transform3D(basis, point + up * 0.01)
	mark.visible = true

func clear() -> void:
	for mark in pool:
		mark.queue_free()
	pool.clear()
	next = 0
