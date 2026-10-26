extends SceneTree
## A walk through the simulation hall at walking-to-running pace, to look for flicker,
## popping and smearing in motion. Record it with the Movie Maker:
##   godot --resolution 1280x720 --write-movie <file.avi> --fixed-fps 30 -s res://tools/tokyo_walk.gd
## From the HOTEL KOI square over the crossing and the street west of it into the cherry park.

const PATH := [
	Vector3(-6.0, 1.7, -36.0), Vector3(-5.0, 1.7, -18.0), Vector3(-7.0, 1.7, -4.0),
	Vector3(-16.0, 1.7, 0.0), Vector3(-30.0, 1.7, 2.0), Vector3(-30.0, 1.7, 20.0), Vector3(-44.0, 1.7, 19.0),
]
const SPEED := 5.0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 74
	camera.near = 0.05
	camera.far = 400
	root.add_child(camera)
	camera.current = true
	camera.position = PATH[0]
	camera.look_at(PATH[1])
	for i in range(20):
		await process_frame
	var curve := Curve3D.new()
	for p in PATH:
		curve.add_point(p)
	# Smooth corners: handles a third of the way to the neighbours.
	for i in range(1, PATH.size() - 1):
		var d: Vector3 = (PATH[i + 1] - PATH[i - 1]) / 6.0
		curve.set_point_in(i, -d)
		curve.set_point_out(i, d)
	var length := curve.get_baked_length()
	var gone := 0.0
	while gone < length:
		var at := curve.sample_baked(gone)
		var ahead := curve.sample_baked(minf(gone + 6.0, length + 0.01))
		if ahead.distance_to(at) < 0.5:
			ahead = at + (at - curve.sample_baked(gone - 1.0))
		camera.position = at + Vector3(0, sin(gone * 1.6) * 0.03, 0)
		camera.look_at(ahead + Vector3(0, 0.6, 0))
		await process_frame
		gone += SPEED / 30.0
	quit()
