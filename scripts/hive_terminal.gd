extends Node3D
## The screens of the terminals let into the walls of the facility (HiveMap._terminal
## builds the niche around each of them): every one of them plays one of two loops - what
## the laboratory watches, and where in the earth the facility lies.
##
## However many screens show a loop, its film is played once: one player for every loop,
## and all the screens of that loop share one surface with one picture. A loop only runs
## while the viewer is near a screen that shows it and that screen is drawn at all (the
## map hides zones that are far away); otherwise it stands still. Where no film can be
## played - an automatic run without a window, a film that is missing - the screens show
## a still of it instead.

## The films (Ogg Theora, 640 x 360, without sound) and a still of each.
const LOOPS := {
	"specimen": {"film": "res://assets/hive/video/terminal_specimen.ogv", "still": "res://assets/hive/video/terminal_specimen.jpg"},
	"crucible": {"film": "res://assets/hive/video/terminal_crucible.ogv", "still": "res://assets/hive/video/terminal_crucible.jpg"}
}
## A loop runs while the viewer is nearer than this to one of its screens (metres).
const REACH := 34.0
## How bright a screen is: a little more than white, so that it glows without being a lamp.
const SHINE := 1.7
## Seconds between two looks at where the viewer is.
const LOOK_EVERY := 0.25

## Loop -> {surface, still, screens, player, live, near}.
var loops: Dictionary = {}
## Where the players sit: a viewport that is never drawn, so that no film shows on the screen itself.
var booth: SubViewport
var look_left := 0.0
## False where no film is played at all: a run without a window.
var films := true

func _init() -> void:
	name = "Terminals"
	films = DisplayServer.get_name() != "headless"

## The surface all screens of a loop share.
func _loop(id: String) -> Dictionary:
	if loops.has(id):
		return loops[id]
	var files: Dictionary = LOOPS.get(id, {})
	var still: Texture2D = null
	if ResourceLoader.exists(str(files.get("still", ""))):
		still = load(str(files.still)) as Texture2D
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.albedo_color = Color(SHINE, SHINE, SHINE) if still != null else Color(0.02, 0.09, 0.11)
	surface.albedo_texture = still
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	surface.disable_fog = false
	loops[id] = {"surface": surface, "still": still, "screens": [], "player": null, "live": false, "near": false, "broken": false}
	return loops[id]

## A screen that shows a loop: a pane of `size` metres, seen from its +z. The caller puts
## it into the world.
func screen(id: String, size: Vector2) -> MeshInstance3D:
	var entry := _loop(id)
	var pane := QuadMesh.new()
	pane.size = size
	pane.material = entry.surface
	var instance := MeshInstance3D.new()
	instance.name = "TerminalScreen"
	instance.mesh = pane
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 70.0
	(entry.screens as Array).append(instance)
	return instance

## How many screens show a loop.
func count(id: String = "") -> int:
	var all := 0
	for key in loops:
		if id == "" or id == key:
			all += (loops[key].screens as Array).size()
	return all

## How many films there are a player for, and how many of those run right now.
func players() -> Vector2i:
	var made := 0
	var running := 0
	for key in loops:
		var player: VideoStreamPlayer = loops[key].player
		if player != null:
			made += 1
			if player.is_playing() and not player.paused:
				running += 1
	return Vector2i(made, running)

## True when every screen of every loop shows that loop's one surface.
func shared() -> bool:
	for key in loops:
		for instance in loops[key].screens:
			if not is_instance_valid(instance) or ((instance as MeshInstance3D).mesh as QuadMesh).material != loops[key].surface:
				return false
	return true

func _process(delta: float) -> void:
	if not films:
		return
	look_left -= delta
	if look_left > 0.0:
		return
	look_left = LOOK_EVERY
	var viewer := get_viewport().get_camera_3d()
	if viewer == null:
		return
	var eye := viewer.global_position
	for key in loops:
		var entry: Dictionary = loops[key]
		var near := false
		for instance in entry.screens:
			var pane := instance as MeshInstance3D
			if is_instance_valid(pane) and pane.is_inside_tree() and pane.is_visible_in_tree() and pane.global_position.distance_squared_to(eye) < REACH * REACH:
				near = true
				break
		entry.near = near
		_run(str(key), entry, near)

## Starts, holds or carries on the film of a loop.
func _run(id: String, entry: Dictionary, near: bool) -> void:
	var player: VideoStreamPlayer = entry.player
	if player == null:
		if not near or bool(entry.broken):
			return
		var film: VideoStream = null
		var path := str(LOOPS[id].film)
		if ResourceLoader.exists(path):
			film = load(path) as VideoStream
		if film == null:
			entry.broken = true
			return
		if booth == null:
			booth = SubViewport.new()
			booth.name = "Booth"
			booth.size = Vector2i(2, 2)
			booth.render_target_update_mode = SubViewport.UPDATE_DISABLED
			booth.disable_3d = true
			add_child(booth)
		player = VideoStreamPlayer.new()
		player.name = "Film_" + id
		player.stream = film
		player.loop = true
		player.volume_db = -80.0
		player.expand = false
		booth.add_child(player)
		player.play()
		entry.player = player
	elif near and player.paused:
		player.paused = false
	elif not near and not player.paused:
		player.paused = true
	# Its picture replaces the still as soon as there is one.
	if not bool(entry.live) and player.is_playing():
		var picture := player.get_video_texture()
		if picture != null and picture.get_width() > 0:
			(entry.surface as StandardMaterial3D).albedo_texture = picture
			entry.live = true
