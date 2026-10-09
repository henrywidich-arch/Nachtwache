@tool
class_name MeshBatch
extends RefCounted
## Collects tinted boxes, cylinders and quads per material and commits one mesh
## per material, so a whole building costs a handful of draw calls.

class Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

# Each face: outward normal followed by two tangents with u x v = normal.
const FACES := [
	[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]
]

var surfaces: Dictionary = {}
## What the batch is called by whoever fills it (a chunk of a map).
var label := ""
## For tools/face_check.gd: while `watching`, every box that is built is noted here as
## [batch, material, centre, size, colour, basis].
static var watching := false
static var watched: Array = []

func _surface(material: Material) -> Surface:
	if not surfaces.has(material):
		surfaces[material] = Surface.new()
	return surfaces[material]

func box(material: Material, center: Vector3, size: Vector3, color: Color = Color.WHITE, basis: Basis = Basis.IDENTITY) -> void:
	if watching:
		watched.append([self, material, center, size, color, basis])
	var surface := _surface(material)
	var half := size * 0.5
	for face in FACES:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var start := surface.vertices.size()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var local: Vector3 = (normal + u * corner.x + v * corner.y) * half
			surface.vertices.append(center + basis * local)
			surface.normals.append(basis * normal)
			surface.colors.append(color)
		# Godot treats clockwise triangles as front faces.
		for offset in [0, 2, 1, 0, 3, 2]:
			surface.indices.append(start + offset)

## Corners are given counter-clockwise as seen from the visible side.
func quad(material: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color = Color.WHITE) -> void:
	var surface := _surface(material)
	var normal := (b - a).cross(d - a).normalized()
	var start := surface.vertices.size()
	for point in [a, b, c, d]:
		surface.vertices.append(point)
		surface.normals.append(normal)
		surface.colors.append(color)
	for offset in [0, 2, 1, 0, 3, 2]:
		surface.indices.append(start + offset)

## The same with a colour of its own for every corner, in the order of the corners. A
## material with a programme of its own may read anything out of them, e.g. where on the
## quad a point lies.
func quad_tinted(material: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colors: Array) -> void:
	var surface := _surface(material)
	var normal := (b - a).cross(d - a).normalized()
	var start := surface.vertices.size()
	var corners := [a, b, c, d]
	for i in range(4):
		surface.vertices.append(corners[i])
		surface.normals.append(normal)
		surface.colors.append(colors[i])
	for offset in [0, 2, 1, 0, 3, 2]:
		surface.indices.append(start + offset)

func triangle(material: Material, a: Vector3, b: Vector3, c: Vector3, color: Color = Color.WHITE) -> void:
	var surface := _surface(material)
	var normal := (b - a).cross(c - a).normalized()
	var start := surface.vertices.size()
	for point in [a, b, c]:
		surface.vertices.append(point)
		surface.normals.append(normal)
		surface.colors.append(color)
	for offset in [0, 2, 1]:
		surface.indices.append(start + offset)

## Tapered cylinder standing on `base`; `basis` tilts it around the base point.
func cylinder(material: Material, base: Vector3, bottom_radius: float, top_radius: float, height: float, color: Color = Color.WHITE, sides: int = 8, basis: Basis = Basis.IDENTITY, capped: bool = true) -> void:
	var surface := _surface(material)
	var start := surface.vertices.size()
	var slope := (bottom_radius - top_radius) / maxf(height, 0.001)
	for i in range(sides + 1):
		var angle := TAU * float(i) / float(sides)
		var around := Vector3(cos(angle), 0, sin(angle))
		var normal := (around + Vector3.UP * slope).normalized()
		surface.vertices.append(base + basis * (around * bottom_radius))
		surface.vertices.append(base + basis * (around * top_radius + Vector3.UP * height))
		for n in range(2):
			surface.normals.append(basis * normal)
			surface.colors.append(color)
	for i in range(sides):
		var index := start + i * 2
		for offset in [0, 2, 1, 2, 3, 1]:
			surface.indices.append(index + offset)
	if not capped:
		return
	for cap in range(2):
		var radius := top_radius if cap == 1 else bottom_radius
		if radius <= 0.001:
			continue
		var level := Vector3.UP * (height if cap == 1 else 0.0)
		var centre_index := surface.vertices.size()
		var cap_normal := basis * (Vector3.UP if cap == 1 else Vector3.DOWN)
		surface.vertices.append(base + basis * level)
		surface.normals.append(cap_normal)
		surface.colors.append(color)
		for i in range(sides + 1):
			var angle := TAU * float(i) / float(sides)
			surface.vertices.append(base + basis * (Vector3(cos(angle), 0, sin(angle)) * radius + level))
			surface.normals.append(cap_normal)
			surface.colors.append(color)
		for i in range(sides):
			surface.indices.append(centre_index)
			if cap == 1:
				surface.indices.append(centre_index + 1 + i)
				surface.indices.append(centre_index + 2 + i)
			else:
				surface.indices.append(centre_index + 2 + i)
				surface.indices.append(centre_index + 1 + i)

## Low-poly ellipsoid, used for rounded shapes such as knuckles and palms.
func ellipsoid(material: Material, center: Vector3, radii: Vector3, color: Color = Color.WHITE, basis: Basis = Basis.IDENTITY, segments: int = 8, rings: int = 6) -> void:
	var surface := _surface(material)
	var start := surface.vertices.size()
	for ring in range(rings + 1):
		var polar := PI * float(ring) / float(rings)
		for segment in range(segments + 1):
			var azimuth := TAU * float(segment) / float(segments)
			var unit := Vector3(sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth))
			surface.vertices.append(center + basis * (unit * radii))
			surface.normals.append((basis * (unit / radii)).normalized())
			surface.colors.append(color)
	for ring in range(rings):
		for segment in range(segments):
			var a := start + ring * (segments + 1) + segment
			var b := a + segments + 1
			for index in [a, b, a + 1, a + 1, b, b + 1]:
				surface.indices.append(index)

func commit(parent: Node3D, prefix: String, shadows: bool = true) -> Array[MeshInstance3D]:
	var created: Array[MeshInstance3D] = []
	var index := 0
	for material in surfaces:
		var surface: Surface = surfaces[material]
		if surface.vertices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_COLOR] = surface.colors
		arrays[Mesh.ARRAY_INDEX] = surface.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		var instance := MeshInstance3D.new()
		instance.name = "%s%02d" % [prefix, index]
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		created.append(instance)
		index += 1
	surfaces.clear()
	return created
