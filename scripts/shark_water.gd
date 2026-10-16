class_name SharkWater
extends RefCounted
## The water a Shark lives in: one surface height and the deep parts below it, given as
## boxes (AABB: x and z are the extent of the deep water, y from the bottom to the surface)
## or as one flat outline (a polygon in x/z with one bottom). Whoever builds a place with
## water makes one of these and hands it to Shark.spawn_in; the shark never leaves it.
##   SharkWater.from_boxes(surface, [AABB(...), ...])
##   SharkWater.from_outline(surface, bottom, PackedVector2Array([...]))
## Shallow water (a walkway a hand below the surface) is no part of it: what is not deep
## enough for the animal is dry land to it.

## Height of the surface (world y).
var surface := 0.0
## The deep water as boxes (empty when an outline is used).
var boxes: Array[AABB] = []
## The deep water as one outline in x/z, and its bottom.
var outline := PackedVector2Array()
var bottom := -2.0

static func from_boxes(at_surface: float, deep: Array) -> SharkWater:
	var water := SharkWater.new()
	water.surface = at_surface
	for box in deep:
		water.boxes.append(box as AABB)
	water.bottom = at_surface
	for box in water.boxes:
		water.bottom = minf(water.bottom, box.position.y)
	return water

static func from_outline(at_surface: float, at_bottom: float, points: PackedVector2Array) -> SharkWater:
	var water := SharkWater.new()
	water.surface = at_surface
	water.bottom = at_bottom
	water.outline = points
	return water

## True if the point (x, z) lies over deep water.
func over(point: Vector3) -> bool:
	if not outline.is_empty():
		return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), outline)
	for box in boxes:
		if point.x >= box.position.x and point.x <= box.end.x and point.z >= box.position.z and point.z <= box.end.z:
			return true
	return false

## The bottom under (x, z) (the surface itself where there is no deep water).
func floor_at(point: Vector3) -> float:
	if not outline.is_empty():
		return bottom if over(point) else surface
	var lowest := surface
	for box in boxes:
		if point.x >= box.position.x and point.x <= box.end.x and point.z >= box.position.z and point.z <= box.end.z:
			lowest = minf(lowest, box.position.y)
	return lowest

## True if the point lies in the water: over deep water and below the surface.
func holds(point: Vector3, slack: float = 0.0) -> bool:
	return over(point) and point.y <= surface + slack and point.y >= floor_at(point) - slack

## The nearest point (x, z) over deep water at least `margin` metres inside its edge (the
## point itself when it is that far inside already); y is kept.
func inside(point: Vector3, margin: float = 0.0) -> Vector3:
	if edge_inside(point) >= margin:
		return point
	var best := point
	var best_d := INF
	if not outline.is_empty():
		var centre := Vector2.ZERO
		for p in outline:
			centre += p
		centre /= float(outline.size())
		# Walk towards the middle until the margin is met (an outline is meant to be simple).
		var p2 := Vector2(point.x, point.z)
		for i in range(1, 41):
			var q := p2.lerp(centre, i / 40.0)
			var candidate := Vector3(q.x, point.y, q.y)
			if edge_inside(candidate) >= margin:
				return candidate
		return Vector3(centre.x, point.y, centre.y)
	for box in boxes:
		var lo := Vector2(box.position.x + margin, box.position.z + margin)
		var hi := Vector2(box.end.x - margin, box.end.z - margin)
		if lo.x > hi.x:
			lo.x = (box.position.x + box.end.x) * 0.5
			hi.x = lo.x
		if lo.y > hi.y:
			lo.y = (box.position.z + box.end.z) * 0.5
			hi.y = lo.y
		var c := Vector3(clampf(point.x, lo.x, hi.x), point.y, clampf(point.z, lo.y, hi.y))
		var d := Vector2(c.x - point.x, c.z - point.z).length()
		if d < best_d:
			best_d = d
			best = c
	return best

## How far the point (x, z) lies inside the deep water (0 or less: outside it).
func edge_inside(point: Vector3) -> float:
	if not outline.is_empty():
		if not over(point):
			return -edge_distance(point)
		var p := Vector2(point.x, point.z)
		var least := INF
		for i in range(outline.size()):
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			least = minf(least, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
		return least
	var deepest := -INF
	for box in boxes:
		var d := minf(minf(point.x - box.position.x, box.end.x - point.x), minf(point.z - box.position.z, box.end.z - point.z))
		deepest = maxf(deepest, d)
	# Where two boxes touch, a point near their shared side is further inside than either box
	# says: what counts is the distance to the nearest point that is not deep water.
	if deepest > 0.0 and boxes.size() > 1:
		deepest = minf(_dry_distance(point, deepest + 3.0), maxf(deepest, 0.0) + 3.0)
	return deepest

## Horizontal distance from (x, z) to the nearest deep water (0 inside it).
func edge_distance(point: Vector3) -> float:
	if over(point):
		return 0.0
	var p := Vector2(point.x, point.z)
	var least := INF
	if not outline.is_empty():
		for i in range(outline.size()):
			least = minf(least, p.distance_to(Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % outline.size()])))
		return least
	for box in boxes:
		var c := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.z, box.end.z))
		least = minf(least, p.distance_to(c))
	return least

## The nearest place over deep water to (x, z), on its edge (the point itself inside it).
func nearest(point: Vector3) -> Vector3:
	if over(point):
		return point
	var p := Vector2(point.x, point.z)
	var best := p
	var least := INF
	if not outline.is_empty():
		for i in range(outline.size()):
			var c := Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % outline.size()])
			if p.distance_to(c) < least:
				least = p.distance_to(c)
				best = c
	else:
		for box in boxes:
			var c := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.z, box.end.z))
			if p.distance_to(c) < least:
				least = p.distance_to(c)
				best = c
	return Vector3(best.x, point.y, best.y)

## A random place over deep water at least `margin` inside its edge.
func random_point(margin: float = 1.0) -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	if not outline.is_empty():
		for p in outline:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	else:
		for box in boxes:
			lo = Vector2(minf(lo.x, box.position.x), minf(lo.y, box.position.z))
			hi = Vector2(maxf(hi.x, box.end.x), maxf(hi.y, box.end.z))
	for attempt in range(40):
		var p := Vector3(randf_range(lo.x, hi.x), surface, randf_range(lo.y, hi.y))
		if edge_inside(p) >= margin:
			return p
	return inside(Vector3((lo.x + hi.x) * 0.5, surface, (lo.y + hi.y) * 0.5), margin)

func _dry_distance(point: Vector3, reach: float) -> float:
	# Rings of probes: the first one that is not over deep water gives the distance.
	var step := 0.1
	var r := step
	while r <= reach:
		for i in range(16):
			var a := TAU * i / 16.0
			if not over(point + Vector3(cos(a) * r, 0, sin(a) * r)):
				return r
		r += step
	return reach
