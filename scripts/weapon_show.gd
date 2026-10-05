class_name WeaponShow
extends SubViewportContainer
## A weapon shown by itself, turning a little to and fro: the picture in the shop and at
## the workbench. It has a small world of its own (a camera, three lamps, a pale sky for
## the metal to mirror), so nothing of the night gets into the picture. The models come
## from WeaponView.display() and are kept, so that leafing through the list costs nothing.

## Field of view of its camera: narrow, so that a long weapon is not distorted.
const FOV := 22.0
## How much of the picture's width a long weapon fills, and a handgun.
const FILL := Vector2(0.5, 0.84)
## The swing to both sides (radians) and how fast it goes.
const SWING := 0.5
const PACE := 0.55

var stage: SubViewport
var pivot: Node3D
var camera: Camera3D
var models: Dictionary = {}
var shown := ""
var clock := 0.0

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = SubViewport.new()
	stage.own_world_3d = true
	stage.transparent_bg = true
	stage.msaa_3d = Viewport.MSAA_4X
	stage.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(stage)
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color(0.74, 0.78, 0.84)
	sky_paint.sky_horizon_color = Color(0.5, 0.52, 0.55)
	sky_paint.ground_horizon_color = Color(0.3, 0.3, 0.31)
	sky_paint.ground_bottom_color = Color(0.1, 0.1, 0.11)
	var sky := Sky.new()
	sky.sky_material = sky_paint
	var air := Environment.new()
	air.background_mode = Environment.BG_CLEAR_COLOR
	air.sky = sky
	air.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	air.ambient_light_energy = 0.85
	air.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	air.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = air
	stage.add_child(world)
	# A key light from the front above, a cooler one from the other side, one from behind.
	# (The camera stands on +x; a lamp shines along its own -z.)
	for lamp in [[Vector3(-35, 73, 0), 1.7, Color(1.0, 0.96, 0.9)], [Vector3(-10, 117, 0), 0.55, Color(0.75, 0.84, 1.0)], [Vector3(-50, -90, 0), 0.9, Color(1.0, 1.0, 1.0)]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = lamp[0]
		sun.light_energy = lamp[1]
		sun.light_color = lamp[2]
		sun.shadow_enabled = false
		stage.add_child(sun)
	pivot = Node3D.new()
	stage.add_child(pivot)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.02
	camera.far = 20.0
	stage.add_child(camera)
	camera.current = true

func _process(delta: float) -> void:
	if not is_visible_in_tree() or shown == "":
		return
	clock += delta
	pivot.rotation.y = sin(clock * PACE) * SWING

## Shows a weapon, with these parts on it ("reddot", "scope", "silencer"). "" shows none.
func show_weapon(id: String, parts: Array = []) -> void:
	for other in models:
		(models[other] as Node3D).visible = other == id
	shown = id
	if id == "":
		return
	if not models.has(id):
		models[id] = WeaponView.display(id)
		pivot.add_child(models[id])
		clock = 0.0
	var model: Node3D = models[id]
	var sighted := false
	for node in model.find_children("Mod_*", "Node3D", true, false):
		var part := str(node.name).trim_prefix("Mod_")
		(node as Node3D).visible = parts.has(part)
		sighted = sighted or (parts.has(part) and part in ["reddot", "scope"])
	# Iron sights that fold lie down under a fitted sight, as in the hand.
	var irons := model.find_child("Sights", true, false) as Node3D
	if irons != null and WeaponView.GUNS.has(id) and WeaponView.GUNS[id].get("folding", false):
		irons.visible = not sighted
	_frame(model.get_meta("size", Vector3(0.1, 0.3, 0.8)))

## Puts the camera where the weapon fills the picture: beside it, a little above, the
## muzzle to the right.
func _frame(extent: Vector3) -> void:
	var shape := maxf(size.x, 1.0) / maxf(size.y, 1.0)
	var half := tan(deg_to_rad(FOV) * 0.5)
	var fill := lerpf(FILL.x, FILL.y, clampf((extent.z - 0.2) / 0.6, 0.0, 1.0))
	# Room for a sight on top and for the swing.
	var away := maxf(extent.z / (fill * 2.0 * half * shape), (extent.y + 0.05) / (0.84 * 2.0 * half))
	camera.position = Vector3(away, away * 0.1, 0.0)
	camera.look_at(Vector3.ZERO)
