extends SceneTree
## Pictures of the objectives of the simulation hall (TokyoTasks): the three terminals - in
## the pachinko hall, the Yamashita market and the Shinsekai Tech lobby - and the data core
## under the control room. The hall alone (TokyoMap). Run with tools/godot_bg.ps1 -Render:
##   -s res://tools/tasks_shots.gd -- --out=<folder>

class Owner extends Node:
	var game: Node3D

const VIEWS := {
	"terminal_pachinko": [Vector3(-20.5, 1.7, 46.5), "pachinko"],
	"terminal_yamashita": [Vector3(14.5, 1.7, 47.0), "yamashita"],
	"terminal_tech": [Vector3(49.0, 1.9, -6.5), "tech"],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var map: CabinMap = load("res://scripts/tokyo_map.gd").new()
	root.add_child(map)
	var owner := Owner.new()
	owner.game = Node3D.new()
	root.add_child(owner.game)
	var hall: TokyoHall = map.hall
	var tasks := TokyoTasks.new(owner, hall)
	tasks.setup()
	var camera := Camera3D.new()
	camera.fov = 70
	camera.near = 0.05
	root.add_child(camera)
	camera.current = true
	for i in range(30):
		await process_frame
	for name: String in VIEWS:
		var id: String = VIEWS[name][1]
		var target: Vector3 = hall.places["tokyo_task_" + id] + Vector3(0, 1.0, 0)
		camera.position = VIEWS[name][0]
		camera.look_at(target)
		await _save(folder.path_join(name + ".png"))
	# The core: locked, and open once the terminals run.
	camera.position = tasks.core.at + Vector3(-3.5, 2.0, -5.0)
	camera.look_at(tasks.core.at + Vector3(0, 1.0, 0))
	tasks._paint(tasks.core.light, Color("2ff3ff"))
	await _save(folder.path_join("datenkern.png"))
	quit()

func _save(path: String) -> void:
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
