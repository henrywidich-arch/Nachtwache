extends SceneTree
## Looks at every way in of the map of mission two (HiveMap.entries) and says what is in
## its way: something that hangs or stands where its mouth is, a room behind the wall it
## is cut into, no free ground to come down on.
##   Godot --headless --path <project> -s res://tools/way_check.gd > out.txt 2>&1
## It prints a line WAY for every way in that has something to say and a line WAYS with
## the numbers. (It knows the boxes, pipes, models and lettering of the map; what is made
## of other shapes it does not see - look at the pictures of --entries-check as well.)

class Spy extends HiveMap:
	var cut := -1
	var models: Array = []
	var pipes: Array = []
	var lamp_spans: Array = []
	func _lamp(kind: String, at: Vector3, look: Dictionary, along_x: bool, tall: float, how: String = "lit") -> Light3D:
		var from := MeshBatch.watched.size()
		var made := super._lamp(kind, at, look, along_x, tall, how)
		lamp_spans.append([from, MeshBatch.watched.size()])
		return made
	func _compile() -> void:
		cut = MeshBatch.watched.size()
		super._compile()
	func _model(id: String, pos: Vector3, yaw: float = 0.0, options: Dictionary = {}) -> Node3D:
		var entry := _model_entry(id)
		var bounds: AABB = entry.bounds
		var factor := float(options.get("scale", 1.0))
		if options.has("height"):
			factor = float(options.height) / maxf(0.001, bounds.size.y)
		elif options.has("width"):
			factor = float(options.width) / maxf(0.001, maxf(bounds.size.x, bounds.size.z))
		var size := bounds.size * factor
		var c := absf(cos(yaw))
		var s := absf(sin(yaw))
		var flat := Vector3(size.x * c + size.z * s, size.y, size.x * s + size.z * c)
		var base := pos + Vector3(0, float(options.get("lift", 0.0)), 0)
		models.append([base - Vector3(flat.x * 0.5, 0, flat.z * 0.5), base + Vector3(flat.x * 0.5, flat.y, flat.z * 0.5), id])
		return super._model(id, pos, yaw, options)
	func _pipe(from: Vector3, to: Vector3, radius: float, color: Color, sides: int = 8, material: String = "metal") -> void:
		# (Not those of the ways in themselves.)
		if batch != null and not str(batch.label).ends_with("|Ways"):
			var low := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z)) - Vector3.ONE * radius
			var high := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z)) + Vector3.ONE * radius
			pipes.append([low, high, "pipe"])
		super._pipe(from, to, radius, color, sides, material)

const G := 4.0

var things: Array = []
var grid: Dictionary = {}

func _add(low: Vector3, high: Vector3, tag: String) -> void:
	var index := things.size()
	things.append([low, high, tag])
	for x in range(floori(low.x / G), floori(high.x / G) + 1):
		for z in range(floori(low.z / G), floori(high.z / G) + 1):
			var key := Vector2i(x, z)
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(index)

## What reaches into a box, as text ("" if nothing does).
func _hits(low: Vector3, high: Vector3) -> String:
	var seen := {}
	var out := ""
	for x in range(floori(low.x / G), floori(high.x / G) + 1):
		for z in range(floori(low.z / G), floori(high.z / G) + 1):
			for index: int in grid.get(Vector2i(x, z), []):
				if seen.has(index):
					continue
				var a: Vector3 = things[index][0]
				var b: Vector3 = things[index][1]
				if a.x < high.x and b.x > low.x and a.y < high.y and b.y > low.y and a.z < high.z and b.z > low.z:
					seen[index] = true
					if seen.size() <= 3:
						out += "%s at %s size %s; " % [things[index][2], str(((a + b) * 0.5).snappedf(0.01)), str((b - a).snappedf(0.01))]
	if seen.size() > 3:
		out += "and %d more" % (seen.size() - 3)
	return out

## The box between two corners given in the frame of a way in: `across` along its wall,
## up, and `out` into the room.
func _span(at: Vector3, out: Vector3, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> Array:
	var across := Vector3(absf(out.z), 0, absf(out.x))
	var a := at + across * x0 + Vector3.UP * y0 + out * z0
	var b := at + across * x1 + Vector3.UP * y1 + out * z1
	return [Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)), Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))]

func _initialize() -> void:
	MeshBatch.watching = true
	MeshBatch.watched.clear()
	var map := Spy.new()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	MeshBatch.watching = false
	var is_lamp := {}
	for span in map.lamp_spans:
		for k in range(int(span[0]), int(span[1])):
			is_lamp[k] = true
	for index in range(MeshBatch.watched.size()):
		var entry: Array = MeshBatch.watched[index]
		var label := str((entry[0] as MeshBatch).label)
		# What a room is made of is not in the way (its lamps are), nor stains, nor the
		# ways in themselves, nor what is a node of its own (the leaf of a door).
		if label == "" or label.ends_with("|Stains") or label.ends_with("|Ways"):
			continue
		if label.ends_with("|Shell") and index >= map.cut and not is_lamp.has(index):
			continue
		var basis: Basis = entry[5]
		var size: Vector3 = entry[3]
		var half := (basis.x.abs() * size.x + basis.y.abs() * size.y + basis.z.abs() * size.z) * 0.5
		if half.y < 0.012:
			continue
		var centre: Vector3 = entry[2]
		_add(centre - half, centre + half, label.get_slice("|", 1))
	for entry in map.models:
		_add(entry[0], entry[1], "model " + str(entry[2]))
	for entry in map.pipes:
		_add(entry[0], entry[1], "pipe")
	for node in map.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		var wide := maxf(0.3, label.text.length() * label.font_size * label.pixel_size * 0.5)
		var high := label.font_size * label.pixel_size * 1.1
		var at := label.global_position
		# (Flat on its wall or floor: as wide as its words along the way it is read.)
		var reach := (label.global_basis.x.abs() * wide + label.global_basis.y.abs() * high) * 0.5 + Vector3.ONE * 0.03
		_add(at - reach, at + reach, "text '%s'" % label.text.left(14))
	var bad := 0
	var kinds := {}
	for entry in map.entries:
		var kind := str(entry.kind)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		var at: Vector3 = entry.at
		var out: Vector3 = entry.out
		var room: Dictionary = map.room_of.get(str(entry.room), {})
		var said: Array[String] = []
		var land: Vector3 = entry.land
		if land == Vector3.INF:
			said.append("no free ground near %s" % str(entry.wish))
		elif Vector2(land.x - (entry.wish as Vector3).x, land.z - (entry.wish as Vector3).z).length() > (1.2 if kind == "window" else 0.8):
			said.append("comes down %.1f m from where it was meant to" % Vector2(land.x - (entry.wish as Vector3).x, land.z - (entry.wish as Vector3).z).length())
		var pocket := Rect2()
		match kind:
			"drop":
				if not bool(entry.get("fixed", false)):
					var mouth := _hits(at + Vector3(-0.7, -1.14, -0.7), at + Vector3(0.7, -0.01, 0.7))
					if mouth != "":
						said.append("under the ceiling: " + mouth)
					var column := _hits(Vector3(at.x - 0.34, float(room.y) + 0.12, at.z - 0.34), Vector3(at.x + 0.34, at.y - 1.1, at.z + 0.34))
					if column != "":
						said.append("below it: " + column)
			"hole":
				var box := _span(at, out, -0.72, 0.72, 0.06, 1.75, -0.03, 1.25)
				var mouth := _hits(box[0], box[1])
				if mouth != "":
					said.append("before it: " + mouth)
				var back := _span(at, out, -0.7, 0.7, 0.0, 1.5, -1.6, -0.25)
				pocket = Rect2(Vector2((back[0] as Vector3).x, (back[0] as Vector3).z), Vector2((back[1] as Vector3).x - (back[0] as Vector3).x, (back[1] as Vector3).z - (back[0] as Vector3).z))
			"duct":
				var sill := at.y - float(room.y)
				var floor_at := Vector3(at.x, float(room.y), at.z)
				var box := _span(floor_at, out, -0.72, 0.72, sill - 1.0, sill + 1.05, -0.03, 0.45)
				var mouth := _hits(box[0], box[1])
				if mouth != "":
					said.append("before it: " + mouth)
				var back := _span(floor_at, out, -0.65, 0.65, 0.0, 1.5, -1.45, -0.25)
				pocket = Rect2(Vector2((back[0] as Vector3).x, (back[0] as Vector3).z), Vector2((back[1] as Vector3).x - (back[0] as Vector3).x, (back[1] as Vector3).z - (back[0] as Vector3).z))
			"cellar":
				var box := _span(at - out * 0.6 - Vector3(0, 0.5, 0), out, -0.7, 0.7, 0.06, 1.9, -0.7, 0.7)
				var mouth := _hits(box[0], box[1])
				if mouth != "":
					said.append("where it stands: " + mouth)
		if pocket.size.x > 0.0:
			for other in map.rooms:
				if str(other.id) == str(entry.room):
					continue
				if absf(float(other.y) - float(room.y)) > 4.0 and not bool(other.outdoor):
					continue
				if bool(other.outdoor) and absf(float(other.y) - float(room.y)) > 1.0:
					continue
				if (other.outer as Rect2).intersects(pocket):
					said.append("the space behind it lies in '%s'" % other.id)
			for stair in map.stairs:
				if (stair.rect as Rect2).intersects(pocket):
					said.append("the space behind it lies in a stairwell")
		if not said.is_empty():
			bad += 1
			print("WAY %s: %s" % [entry.id, " | ".join(PackedStringArray(said))])
	print("WAYS all=%d with something in the way=%d kinds=%s" % [map.entries.size(), bad, str(kinds)])
	quit(0)
