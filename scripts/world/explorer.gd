class_name WorldExplorer
extends CharacterBody3D
## Someone to walk the open world with: WASD, Shift to run, Space to jump. F flies (Space
## and Ctrl up and down, Shift fast), M shows the map, T changes the time of day, Esc goes
## back to the main menu.

const WALK := 4.6
const RUN := 8.0
const FLY := 28.0
const FLY_FAST := 140.0
const JUMP := 5.0
const GRAVITY := 14.0
const EYE := 1.65

var world: OpenWorld
var camera: Camera3D
var head: Node3D
var flying := false
var sensitivity := 0.0022
var bob := 0.0
var hud: CanvasLayer
var info: Label
var map: TextureRect
var marker: Control
var frames: Array[float] = []

func _ready() -> void:
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body.shape = capsule
	body.position.y = 0.9
	add_child(body)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.08
	camera.far = 4000.0
	head.add_child(camera)
	camera.make_current()
	_build_hud()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func look_toward(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotation.y -= motion.relative.x * sensitivity
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * sensitivity, -1.5, 1.5)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).physical_keycode:
			KEY_F:
				flying = not flying
				velocity = Vector3.ZERO
			KEY_M:
				map.visible = not map.visible
			KEY_T:
				world.next_time()
			KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					get_tree().change_scene_to_file("res://scenes/main.tscn")

func _physics_process(delta: float) -> void:
	var wish := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var fast := Input.is_physical_key_pressed(KEY_SHIFT)
	if flying:
		var forward := -camera.global_basis.z
		var right := camera.global_basis.x
		var move := (right * wish.x - forward * wish.y)
		move.y += float(Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_Q))
		var speed := FLY_FAST if fast else FLY
		velocity = velocity.lerp(move.normalized() * speed if move.length() > 0.01 else Vector3.ZERO, 1.0 - exp(-delta * 6.0))
		global_position += velocity * delta
		var ground := world.height_at(global_position.x, global_position.z)
		global_position.y = maxf(global_position.y, ground + 0.2)
		var limit := world.size * 0.5 - 1.0
		global_position.x = clampf(global_position.x, -limit, limit)
		global_position.z = clampf(global_position.z, -limit, limit)
		return
	var flat := (global_basis * Vector3(wish.x, 0, wish.y))
	flat.y = 0
	flat = flat.normalized() * (RUN if fast else WALK)
	var grip := 10.0 if is_on_floor() else 2.0
	velocity.x = lerpf(velocity.x, flat.x, 1.0 - exp(-delta * grip))
	velocity.z = lerpf(velocity.z, flat.z, 1.0 - exp(-delta * grip))
	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	# Wading slows down.
	if world.under_water(global_position.x, global_position.y + 0.5, global_position.z):
		velocity.x *= 0.92
		velocity.z *= 0.92
	move_and_slide()
	var limit := world.size * 0.5 - 1.0
	global_position.x = clampf(global_position.x, -limit, limit)
	global_position.z = clampf(global_position.z, -limit, limit)
	# Never under the ground.
	var ground := world.height_at(global_position.x, global_position.z)
	if global_position.y < ground - 0.5:
		global_position.y = ground + 0.1
		velocity.y = 0
	var pace := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and pace > 0.5:
		bob += delta * pace * 1.6
	head.position.y = EYE + sin(bob) * 0.035 * clampf(pace / RUN, 0.0, 1.0)

func _process(delta: float) -> void:
	frames.append(delta)
	if frames.size() > 60:
		frames.pop_front()
	var average := 0.0
	for f in frames:
		average += f
	average /= frames.size()
	var p := global_position
	info.text = "%d FPS   ·   %.0f / %.0f m   ·   Höhe %.0f m   ·   %s%s\nWASD gehen · Shift rennen · Leertaste springen · F fliegen · M Karte · T Tageszeit · Esc Menü" % [
		roundi(1.0 / maxf(average, 0.0001)), p.x, p.z, p.y, world.time_name.to_upper(), "   ·   FLUG" if flying else ""]
	if map.visible:
		var size := map.size
		marker.position = Vector2((p.x / world.size + 0.5) * size.x, (p.z / world.size + 0.5) * size.y) - marker.size * 0.5
		marker.rotation = -rotation.y

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	info = Label.new()
	info.position = Vector2(18, 14)
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	info.add_theme_constant_override("shadow_offset_x", 1)
	info.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(info)
	map = TextureRect.new()
	map.texture = load(OpenWorld.FOLDER + "map.png")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.set_anchors_preset(Control.PRESET_CENTER)
	map.offset_left = -380
	map.offset_top = -380
	map.offset_right = 380
	map.offset_bottom = 380
	map.visible = false
	hud.add_child(map)
	marker = Control.new()
	marker.size = Vector2(18, 18)
	marker.pivot_offset = Vector2(9, 9)
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(9, 0), Vector2(17, 17), Vector2(9, 12), Vector2(1, 17)])
	arrow.color = Color(1.0, 0.3, 0.2)
	marker.add_child(arrow)
	map.add_child(marker)
