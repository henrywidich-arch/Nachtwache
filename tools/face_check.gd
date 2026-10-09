extends SceneTree
## Finds what flickers on the map of mission two: faces of boxes that lie in one plane (or
## within a few millimetres of it), look the same way, overlap and do not look alike. The
## graphics card cannot decide which of the two is in front, and the choice changes with
## every step of the viewer.
##   Godot --headless --path <project> -s res://tools/face_check.gd > out.txt 2>&1
## Optional user args after "--": --gap=3 (millimetres that still count as one plane),
## --list=40 (groups to print), --all (also faces that another box covers).

const CELL := 4.0

var boxes: Array = []
var grid: Dictionary = {}

func _initialize() -> void:
	var gap := 0.003
	var most := 40
	var buried_too := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gap="):
			gap = float(arg.substr(6)) / 1000.0
		elif arg.begins_with("--list="):
			most = int(arg.substr(7))
		elif arg == "--all":
			buried_too = true
	MeshBatch.watching = true
	MeshBatch.watched.clear()
	var map := HiveMap.new()
	root.add_child(map)
	while not map.build_times.has("all"):
		await process_frame
	MeshBatch.watching = false
	var names := {}
	for key in map.mats:
		names[map.mats[key]] = str(key)
	# Upright boxes only: [low corner, high corner, material, colour, chunk, space]. A batch
	# without a name is a part of its own (the leaf of a door), built around its own origin:
	# it is only compared with itself.
	var turned := 0
	for entry in MeshBatch.watched:
		var basis: Basis = entry[5]
		# (Quarter turns count as upright: a door frame in a wall that runs north.)
		var square := true
		for column in [basis.x, basis.y, basis.z]:
			if maxf(absf(column.x), maxf(absf(column.y), absf(column.z))) < 0.9999:
				square = false
		if not square:
			turned += 1
			continue
		var centre: Vector3 = entry[2]
		var size: Vector3 = entry[3]
		var half := (basis.x.abs() * size.x + basis.y.abs() * size.y + basis.z.abs() * size.z) * 0.5
		var label := str((entry[0] as MeshBatch).label)
		boxes.append([centre - half, centre + half, entry[1], entry[4], label, 0 if label != "" else (entry[0] as MeshBatch).get_instance_id()])
	for index in range(boxes.size()):
		var low: Vector3 = boxes[index][0]
		var high: Vector3 = boxes[index][1]
		for x in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
			for z in range(floori(low.z / CELL), floori(high.z / CELL) + 1):
				var key := Vector2i(x, z)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(index)
	print("FACES boxes=", boxes.size(), " turned=", turned)
	var groups := {}
	var found := 0
	for axis in range(3):
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for way in [-1.0, 1.0]:
			var faces: Array = []
			for index in range(boxes.size()):
				var low: Vector3 = boxes[index][0]
				var high: Vector3 = boxes[index][1]
				if high[u] - low[u] < 0.02 or high[v] - low[v] < 0.02:
					continue
				faces.append([high[axis] if way > 0.0 else low[axis], index])
			faces.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			for i in range(faces.size()):
				var first: Array = boxes[int(faces[i][1])]
				for j in range(i + 1, faces.size()):
					if float(faces[j][0]) - float(faces[i][0]) > gap:
						break
					var second: Array = boxes[int(faces[j][1])]
					var from_u := maxf(float(first[0][u]), float(second[0][u]))
					var to_u := minf(float(first[1][u]), float(second[1][u]))
					var from_v := maxf(float(first[0][v]), float(second[0][v]))
					var to_v := minf(float(first[1][v]), float(second[1][v]))
					if to_u - from_u < 0.02 or to_v - from_v < 0.02 or first[5] != second[5]:
						continue
					if first[2] == second[2] and (first[3] as Color).is_equal_approx(second[3]):
						continue
					var spot := Vector3.ZERO
					spot[axis] = float(faces[j][0]) + way * 0.012
					spot[u] = (from_u + to_u) * 0.5
					spot[v] = (from_v + to_v) * 0.5
					if not buried_too and _inside(spot, int(faces[i][1]), int(faces[j][1])):
						continue
					found += 1
					var apart := roundi((float(faces[j][0]) - float(faces[i][0])) * 1000.0)
					var key := "%s + %s  axis %s%s  %d mm  [%s | %s]" % [str(names.get(first[2], "?")), str(names.get(second[2], "?")), "xyz"[axis], "+" if way > 0.0 else "-", apart, first[4], second[4]]
					if not groups.has(key):
						groups[key] = {"count": 0, "area": 0.0, "spots": []}
					var group: Dictionary = groups[key]
					group.count += 1
					group.area += (to_u - from_u) * (to_v - from_v)
					if (group.spots as Array).size() < 3:
						(group.spots as Array).append(spot.snappedf(0.01))
	var order: Array = groups.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return float(groups[a].area) > float(groups[b].area))
	print("FACES pairs=", found, " groups=", order.size())
	for index in range(mini(most, order.size())):
		var group: Dictionary = groups[order[index]]
		print("  %4d  %7.2f m2  %s  %s" % [int(group.count), float(group.area), order[index], str(group.spots)])
	quit(0)

## Is the point inside a box other than the two that share the face?
func _inside(spot: Vector3, a: int, b: int) -> bool:
	var key := Vector2i(floori(spot.x / CELL), floori(spot.z / CELL))
	for index in grid.get(key, []):
		if index == a or index == b or boxes[index][5] != boxes[a][5]:
			continue
		var low: Vector3 = boxes[index][0]
		var high: Vector3 = boxes[index][1]
		if spot.x > low.x and spot.x < high.x and spot.y > low.y and spot.y < high.y and spot.z > low.z and spot.z < high.z:
			return true
	return false
