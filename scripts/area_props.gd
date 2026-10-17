class_name AreaProps
extends Node3D
## The things the objective of an area is done with (HiveAreaRun), in greybox but each
## kind recognisable at a glance, the same for every area:
##   collect   key cards on a desk or in an open locker, fuses in a crate (and the fuse box
##             at the area's goal they are slotted into), sample jars on a shelf or in a
##             specimen fridge
##   restore   a pump valve with a handwheel, a gauge and a lamp (a lever cabinet where it
##             is no pump or cooling loop)
##   hack      a terminal whose screen shows the progress
##   hold      a hold point: a ring painted on the floor, a beacon, cells that light up
##   lockdown  red rotating lights at the goal and over the way in, and a shutter in it
## Nothing of it is solid (it stands where the area's own spots are, which are walked to),
## nothing casts a shadow. One of these hangs under the map while a night runs; it is
## emptied when the next area's objective begins and when the night ends.

const STEEL := Color("2c3236")
const PAINT := Color("5b6168")
const DESK := Color("464c52")
const PALE := Color("c9cdd0")
const CARD := Color("ffcf4a")
const FUSE := Color("ff9a3a")
const SAMPLE := Color("7dff8a")
const RED := Color("ff3a2a")
const AMBER := Color("ffb02e")
const GREEN := Color("5ee07a")
const SCREEN_RED := Color("ff5a44")
const MARKING := Color("f2c230")
## How far the ring of a hold point lies from its middle, and its cells of progress.
const RING := 2.4
const CELLS := 12

var director: HiveDirector
var clock := 0.0
var mats: Dictionary = {}
## What moves: beacons that turn while on, wheels and levers that are being worked, the
## shutters of a lockdown, the terminal's screen, the cells of a hold point.
var beacons: Array[Dictionary] = []
var turning: Array[Dictionary] = []
var shutters: Array[Dictionary] = []
var screen: Dictionary = {}
var ring_cells: Array[MeshInstance3D] = []
var ring_lamp: OmniLight3D
var fuse_box: Dictionary = {}
## The objective is done: everything shows it.
var finished := false

func _init(owner_director: HiveDirector) -> void:
	name = "Objectives"
	director = owner_director

## Away with everything of the last objective.
func clear() -> void:
	for child in get_children():
		child.queue_free()
	beacons.clear()
	turning.clear()
	shutters.clear()
	screen = {}
	ring_cells.clear()
	ring_lamp = null
	fuse_box = {}
	finished = false

## What a thing to find or a place to work looks like, from its objective: the word of
## the things and the line of its prompt (an objective may also name a "look").
static func look_of(event: Dictionary) -> String:
	if event.has("look"):
		return str(event.look)
	var words := ("%s %s %s" % [event.get("word", ""), event.get("use", ""), event.get("goal", "")]).to_lower()
	match str(event.get("kind", "")):
		"collect":
			if "karte" in words:
				return "card"
			if "sicherung" in words:
				return "fuse"
			if "probe" in words or "behälter" in words:
				return "jar"
			return "crate"
		"restore":
			if "pumpe" in words or "kühl" in words or "ventil" in words or "wasser" in words:
				return "valve"
			return "lever"
	return str(event.get("kind", ""))

# ---------------------------------------------------------------- building

func _mat(color: Color, glow: float = 0.0, see_through: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [color.to_html(), glow, str(see_through)]
	if not mats.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = color
		made.roughness = 0.55
		if glow > 0.0:
			made.emission_enabled = true
			made.emission = color
			made.emission_energy_multiplier = glow
		if see_through:
			made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			made.albedo_color.a = 0.28
			made.metallic_specular = 0.9
			made.roughness = 0.08
		mats[key] = made
	return mats[key]

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(parent, mesh, at, material)

func _cylinder(parent: Node3D, at: Vector3, radius: float, tall: float, material: Material, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = tall
	mesh.radial_segments = 14
	mesh.rings = 1
	var made := _put(parent, mesh, at, material)
	made.rotation = turn
	return made

func _put(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.mesh = mesh
	made.material_override = material
	made.position = at
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(made)
	return made

func _light(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	lamp.position = at
	parent.add_child(lamp)
	return lamp

func _words(parent: Node3D, text: String, at: Vector3, size: int, color: Color) -> Label3D:
	var line := Label3D.new()
	line.text = text
	line.font_size = size
	line.pixel_size = 0.0012
	line.outline_size = 6
	line.outline_modulate = Color(0, 0.02, 0.03, 0.95)
	line.modulate = color
	line.double_sided = false
	line.position = at
	line.visibility_range_end = 28.0
	parent.add_child(line)
	return line

## A thing standing at `at` (on the floor), its front (+z) towards `toward`.
func _stand(at: Vector3, toward: Vector3, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	add_child(node)
	node.global_position = at
	var look := Vector2(toward.x - at.x, toward.z - at.z)
	if look.length() > 0.1:
		node.rotation.y = atan2(look.x, look.y)
	return node

## A thing to find: {base (what it lies in or on, stays), item (what is picked up)}.
func item(look: String, at: Vector3, toward: Vector3, index: int) -> Dictionary:
	var base := _stand(at, toward, "Fundort")
	var item_node := Node3D.new()
	item_node.name = "Fundstueck"
	base.add_child(item_node)
	match look:
		"card":
			if index % 2 == 0:
				_desk(base, Vector3(0.9, 0.74, 0.55))
				item_node.position = Vector3(0.1, 0.77, 0.05)
			else:
				_locker(base)
				item_node.position = Vector3(0, 1.13, 0.02)
				item_node.rotation.x = -1.2
			_box(item_node, Vector3.ZERO, Vector3(0.16, 0.012, 0.10), _mat(CARD, 2.2))
			_box(item_node, Vector3(-0.03, 0.008, 0.0), Vector3(0.05, 0.006, 0.04), _mat(PALE, 0.6))
			_light(item_node, Vector3(0, 0.25, 0.1), CARD, 0.45, 2.0)
		"fuse":
			if index % 2 == 0:
				_box(base, Vector3(0, 0.2, 0), Vector3(0.62, 0.4, 0.46), _mat(Color("5a4a32")))
				_box(base, Vector3(0, 0.41, 0), Vector3(0.56, 0.02, 0.4), _mat(Color("2a241a")))
				item_node.position = Vector3(0, 0.47, 0)
			else:
				_shelf(base, [0.95])
				item_node.position = Vector3(0, 1.01, 0)
			_cylinder(item_node, Vector3.ZERO, 0.045, 0.2, _mat(FUSE, 2.0), Vector3(0, 0, PI * 0.5))
			for end in [-0.11, 0.11]:
				_cylinder(item_node, Vector3(end, 0, 0), 0.052, 0.035, _mat(PALE), Vector3(0, 0, PI * 0.5))
			_light(item_node, Vector3(0, 0.25, 0.1), FUSE, 0.45, 2.0)
		"jar":
			if index % 2 == 0:
				_shelf(base, [0.55, 1.05])
				for x in [-0.3, 0.3]:
					_jar(base, Vector3(x, 1.06, 0), false)
				_jar(base, Vector3(-0.15, 0.56, 0), false)
				item_node.position = Vector3(0.05, 1.06, 0)
			else:
				_fridge(base)
				_jar(base, Vector3(-0.17, 0.66, 0), false)
				_jar(base, Vector3(0.17, 1.16, 0), false)
				item_node.position = Vector3(0.0, 1.16, 0.02)
			_jar(item_node, Vector3.ZERO, true)
			_light(item_node, Vector3(0, 0.3, 0.25), SAMPLE, 0.45, 2.0)
		_:
			_box(base, Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.5), _mat(PAINT))
			item_node.position = Vector3(0, 0.6, 0)
			_box(item_node, Vector3.ZERO, Vector3(0.3, 0.16, 0.22), _mat(CARD, 2.5))
			_light(item_node, Vector3(0, 0.3, 0), CARD, 0.8, 2.4)
	return {"base": base, "item": item_node}

func _desk(parent: Node3D, size: Vector3) -> void:
	_box(parent, Vector3(0, size.y, 0), Vector3(size.x, 0.05, size.z), _mat(DESK))
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			_box(parent, Vector3(x * (size.x - 0.08), size.y * 0.5, z * (size.z - 0.08)), Vector3(0.05, size.y, 0.05), _mat(STEEL))

func _locker(parent: Node3D) -> void:
	var steel := _mat(Color("4d5a62"))
	_box(parent, Vector3(0, 0.92, -0.24), Vector3(0.6, 1.84, 0.03), steel)
	for x in [-0.29, 0.29]:
		_box(parent, Vector3(x, 0.92, 0), Vector3(0.03, 1.84, 0.5), steel)
	_box(parent, Vector3(0, 1.83, 0), Vector3(0.6, 0.03, 0.5), steel)
	_box(parent, Vector3(0, 0.02, 0), Vector3(0.6, 0.04, 0.5), steel)
	_box(parent, Vector3(0, 1.08, 0), Vector3(0.56, 0.02, 0.46), steel)
	# (Its door stands open, swung out to one side.)
	var door := _box(parent, Vector3(0.5, 0.92, 0.38), Vector3(0.03, 1.8, 0.58), steel)
	door.rotation.y = -0.45
	for k in range(3):
		_box(parent, Vector3(0.52, 1.5 - k * 0.05, 0.36), Vector3(0.035, 0.012, 0.3), _mat(STEEL))

func _shelf(parent: Node3D, boards: Array) -> void:
	for x in [-0.42, 0.42]:
		_box(parent, Vector3(x, 0.65, 0), Vector3(0.04, 1.3, 0.36), _mat(STEEL))
	for y: float in boards:
		_box(parent, Vector3(0, y - 0.02, 0), Vector3(0.88, 0.03, 0.36), _mat(PAINT))

func _fridge(parent: Node3D) -> void:
	var white := _mat(Color("9aa2a6"))
	_box(parent, Vector3(0, 0.82, -0.27), Vector3(0.72, 1.64, 0.04), white)
	for x in [-0.34, 0.34]:
		_box(parent, Vector3(x, 0.82, 0), Vector3(0.04, 1.64, 0.58), white)
	_box(parent, Vector3(0, 1.62, 0), Vector3(0.72, 0.04, 0.58), white)
	_box(parent, Vector3(0, 0.22, 0), Vector3(0.72, 0.44, 0.58), white)
	for y in [0.64, 1.14]:
		_box(parent, Vector3(0, y - 0.02, 0), Vector3(0.64, 0.02, 0.5), _mat(Color("6f7a80")))
	_box(parent, Vector3(0, 1.03, 0.29), Vector3(0.66, 1.16, 0.02), _mat(Color(0.75, 0.9, 1.0), 0.0, true))
	_box(parent, Vector3(0, 1.5, 0.3), Vector3(0.3, 0.05, 0.01), _mat(Color("8fd8ff"), 2.0))
	_light(parent, Vector3(0, 1.45, 0.05), Color("bfe8ff"), 0.25, 1.1)

func _jar(parent: Node3D, at: Vector3, lit: bool) -> void:
	_cylinder(parent, at + Vector3(0, 0.11, 0), 0.075, 0.22, _mat(Color(0.8, 0.95, 1.0), 0.0, true))
	_cylinder(parent, at + Vector3(0, 0.08, 0), 0.06, 0.15, _mat(SAMPLE if lit else Color("6b7a5a"), 1.8 if lit else 0.0))
	_cylinder(parent, at + Vector3(0, 0.235, 0), 0.08, 0.03, _mat(STEEL))

## A place to switch on: a pump valve or a lever cabinet. Its "done" shows on it.
func place(look: String, at: Vector3, toward: Vector3) -> Node3D:
	var node := _stand(at, toward, "Schaltstelle")
	var lamp_at := Vector3.ZERO
	if look == "valve":
		_cylinder(node, Vector3(0, 0.04, -0.25), 0.2, 0.08, _mat(STEEL))
		_cylinder(node, Vector3(0, 0.75, -0.25), 0.09, 1.5, _mat(Color("6a5d48")))
		_cylinder(node, Vector3(0, 1.5, -0.25), 0.13, 0.08, _mat(STEEL))
		_box(node, Vector3(0, 1.0, -0.12), Vector3(0.28, 0.3, 0.28), _mat(Color("8a2f24")))
		_cylinder(node, Vector3(0, 1.0, 0.05), 0.03, 0.14, _mat(STEEL), Vector3(PI * 0.5, 0, 0))
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 1.0, 0.13)
		node.add_child(wheel)
		var rim := TorusMesh.new()
		rim.inner_radius = 0.17
		rim.outer_radius = 0.21
		rim.rings = 18
		rim.ring_segments = 6
		var ring_mesh := _put(wheel, rim, Vector3.ZERO, _mat(Color("c23a2a")))
		ring_mesh.rotation.x = PI * 0.5
		for turn in [0.0, PI * 0.5]:
			var spoke := _box(wheel, Vector3.ZERO, Vector3(0.36, 0.025, 0.025), _mat(Color("c23a2a")))
			spoke.rotation.z = turn
		# The gauge: its needle leans to the red until the place is on.
		_cylinder(node, Vector3(0.2, 1.42, -0.18), 0.1, 0.04, _mat(PALE, 0.5), Vector3(PI * 0.5, 0, 0))
		var needle := Node3D.new()
		needle.position = Vector3(0.2, 1.42, -0.15)
		needle.rotation.z = 1.0
		node.add_child(needle)
		_box(needle, Vector3(0, 0.04, 0), Vector3(0.012, 0.08, 0.008), _mat(RED, 1.0))
		lamp_at = Vector3(-0.22, 1.42, -0.15)
		# (Gauge and lamp sit on a bracket clamped to the pipe.)
		_box(node, Vector3(0, 1.42, -0.2), Vector3(0.62, 0.24, 0.03), _mat(PAINT))
		node.set_meta("wheel", wheel)
		node.set_meta("needle", needle)
	else:
		_box(node, Vector3(0, 0.62, -0.05), Vector3(0.62, 1.24, 0.3), _mat(Color("566070")))
		_box(node, Vector3(0, 0.95, 0.105), Vector3(0.5, 0.36, 0.01), _mat(Color("1e2428")))
		var lever := Node3D.new()
		lever.position = Vector3(0.1, 0.95, 0.12)
		lever.rotation.x = 0.9
		node.add_child(lever)
		_box(lever, Vector3(0, 0.15, 0), Vector3(0.035, 0.3, 0.035), _mat(STEEL))
		_box(lever, Vector3(0, 0.31, 0), Vector3(0.07, 0.07, 0.07), _mat(Color("c23a2a")))
		lamp_at = Vector3(-0.16, 1.05, 0.12)
		node.set_meta("lever", lever)
	var lamp := _box(node, lamp_at, Vector3(0.07, 0.07, 0.04), _mat(RED, 3.0))
	var shine := _light(node, lamp_at + Vector3(0, 0, 0.2), RED, 0.6, 2.2)
	node.set_meta("lamp", lamp)
	node.set_meta("shine", shine)
	return node

## A place was switched on: its wheel turns (or its lever goes up), its needle and its lamp
## go to the green.
func place_done(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	turning.append({"node": node, "left": 1.2})
	(node.get_meta("lamp") as MeshInstance3D).material_override = _mat(GREEN, 3.0)
	(node.get_meta("shine") as OmniLight3D).light_color = GREEN

## The terminal of a hack, its screen towards `toward`.
func terminal(at: Vector3, toward: Vector3) -> Node3D:
	var node := _stand(at, toward, "Terminal")
	_desk(node, Vector3(1.1, 0.76, 0.62))
	_box(node, Vector3(0, 0.79, 0.12), Vector3(0.5, 0.02, 0.18), _mat(Color("1a1e22")))
	_box(node, Vector3(0, 0.92, -0.12), Vector3(0.06, 0.28, 0.06), _mat(STEEL))
	var monitor := Node3D.new()
	monitor.position = Vector3(0, 1.2, -0.1)
	monitor.rotation.x = -0.12
	node.add_child(monitor)
	_box(monitor, Vector3.ZERO, Vector3(0.72, 0.48, 0.06), _mat(Color("15191c")))
	var face := _box(monitor, Vector3(0, 0, 0.032), Vector3(0.66, 0.42, 0.005), _mat(SCREEN_RED.darkened(0.78), 0.5))
	var line := _words(monitor, "GESPERRT", Vector3(0, 0.07, 0.04), 44, SCREEN_RED.lightened(0.45))
	_box(monitor, Vector3(0, -0.12, 0.036), Vector3(0.56, 0.05, 0.004), _mat(Color("101418")))
	var fill_hold := Node3D.new()
	fill_hold.position = Vector3(-0.27, -0.12, 0.04)
	monitor.add_child(fill_hold)
	var fill := _box(fill_hold, Vector3(0.27, 0, 0), Vector3(0.54, 0.035, 0.004), _mat(AMBER, 2.5))
	fill_hold.scale.x = 0.001
	var shine := _light(node, Vector3(0, 1.3, 0.5), SCREEN_RED, 0.8, 3.0)
	screen = {"node": node, "face": face, "line": line, "fill": fill_hold, "shine": shine, "bar": fill}
	return node

## The hold point: a ring on the floor around its middle, a beacon in it, cells of the
## ring that light up as the progress fills.
func hold_point(at: Vector3, lockdown_point: bool = false) -> Node3D:
	var node := _stand(at, at + Vector3(0, 0, 1), "Haltepunkt")
	for k in range(36):
		if k % 3 == 2:
			continue
		var angle := TAU * k / 36.0
		var dash := _box(node, Vector3(sin(angle) * RING, 0.012, cos(angle) * RING), Vector3(0.36, 0.01, 0.14), _mat(MARKING, 0.4))
		dash.rotation.y = angle
	for k in range(CELLS):
		var angle := TAU * (k + 0.5) / CELLS
		var cell := _box(node, Vector3(sin(angle) * (RING - 0.45), 0.014, cos(angle) * (RING - 0.45)), Vector3(0.42, 0.012, 0.22), _mat(Color("39342a")))
		cell.rotation.y = angle
		ring_cells.append(cell)
	# (A lockdown has its red rotating light there instead, see beacon.)
	if not lockdown_point:
		_cylinder(node, Vector3(0, 1.1, 0), 0.05, 2.2, _mat(STEEL))
		_cylinder(node, Vector3(0, 2.25, 0), 0.12, 0.14, _mat(AMBER, 3.0))
		ring_lamp = _light(node, Vector3(0, 2.4, 0), AMBER, 1.6, 7.0)
	var words := _words(node, "HALTEPUNKT", Vector3(0, 0.03, RING + 0.55), 64, MARKING)
	words.pixel_size = 0.0045
	words.rotation.x = -PI * 0.5
	return node

## A red rotating light on a post (`tall` over the floor), or over a doorway; it turns
## while the lockdown holds.
func beacon(at: Vector3, tall: float) -> Node3D:
	var node := _stand(at, at + Vector3(0, 0, 1), "Rundumleuchte")
	if tall > 0.5:
		_cylinder(node, Vector3(0, tall * 0.5, 0), 0.05, tall, _mat(STEEL))
	_cylinder(node, Vector3(0, tall + 0.05, 0), 0.12, 0.1, _mat(STEEL))
	var dome := _cylinder(node, Vector3(0, tall + 0.18, 0), 0.1, 0.18, _mat(Color("5a1410"), 0.4))
	var head := Node3D.new()
	head.position = Vector3(0, tall + 0.18, 0)
	node.add_child(head)
	var beams: Array[SpotLight3D] = []
	for turn in [0.0, PI]:
		var beam := SpotLight3D.new()
		beam.light_color = RED
		beam.light_energy = 0.0
		beam.spot_range = 14.0
		beam.spot_angle = 24.0
		beam.shadow_enabled = false
		beam.rotation.y = turn
		head.add_child(beam)
		beams.append(beam)
	beacons.append({"head": head, "beams": beams, "dome": dome, "on": false})
	return node

## A shutter in the way in of a lockdown (door: the way in, as HiveCore keeps it; `inward`:
## which way the area lies from it). Rolled up until the lockdown begins.
func shutter(door: Dictionary, inward: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Rolltor"
	add_child(node)
	var width := float(door.width)
	var tall := minf(float(door.height), 3.2)
	node.global_position = (door.pos as Vector3) + inward * 0.42 + Vector3(0, tall, 0)
	node.rotation.y = 0.0 if bool(door.along_x) else PI * 0.5
	var slats := Node3D.new()
	node.add_child(slats)
	_box(slats, Vector3(0, -tall * 0.5, 0), Vector3(width, tall, 0.06), _mat(Color("7a7f84")))
	for k in range(int(tall / 0.3)):
		_box(slats, Vector3(0, -0.15 - k * 0.3, 0.035), Vector3(width, 0.035, 0.012), _mat(Color("4a4f54")))
	for k in range(6):
		_box(slats, Vector3(-width * 0.5 + (k + 0.5) * width / 6.0, -tall + 0.18, 0.04), Vector3(width / 12.0, 0.2, 0.01), _mat(MARKING if k % 2 == 0 else Color("1a1a1a")))
	_box(node, Vector3(0, 0.12, 0), Vector3(width + 0.2, 0.26, 0.3), _mat(STEEL))
	slats.scale.y = 0.02
	shutters.append({"slats": slats, "down": false})

## The lockdown begins (true) or is over (false): the shutters come down, the lights turn.
func lockdown(on: bool) -> void:
	for entry in shutters:
		entry.down = on
	for entry in beacons:
		entry.on = on
		for beam: SpotLight3D in entry.beams:
			beam.light_energy = 5.0 if on else 0.0
		(entry.dome as MeshInstance3D).material_override = _mat(RED, 3.0) if on else _mat(Color("5a1410"), 0.4)

## The fuse box at the goal of an objective with fuses: they are slotted into it.
func fuses_box(at: Vector3, toward: Vector3, count: int) -> Node3D:
	var node := _stand(at, toward, "Sicherungskasten")
	_box(node, Vector3(0, 0.6, -0.1), Vector3(0.08, 1.2, 0.08), _mat(STEEL))
	_box(node, Vector3(0, 1.35, -0.06), Vector3(0.62, 0.72, 0.16), _mat(Color("8a8f3a")))
	_box(node, Vector3(0, 1.35, 0.025), Vector3(0.54, 0.62, 0.01), _mat(Color("22262a")))
	var door := _box(node, Vector3(0.48, 1.35, 0.16), Vector3(0.02, 0.66, 0.4), _mat(Color("8a8f3a")))
	door.rotation.y = -0.6
	_words(node, "SICHERUNGEN", Vector3(0, 1.79, 0.03), 28, MARKING)
	var slots: Array[Node3D] = []
	for k in range(count):
		var x := (k - (count - 1) * 0.5) * 0.15
		_box(node, Vector3(x, 1.35, 0.035), Vector3(0.08, 0.32, 0.02), _mat(Color("0e1012")))
		var fuse := Node3D.new()
		fuse.position = Vector3(x, 1.35, 0.06)
		fuse.visible = false
		node.add_child(fuse)
		_cylinder(fuse, Vector3.ZERO, 0.045, 0.2, _mat(FUSE, 2.0))
		slots.append(fuse)
	var lamp := _box(node, Vector3(0, 1.62, 0.04), Vector3(0.06, 0.04, 0.02), _mat(RED, 3.0))
	var shine := _light(node, Vector3(0, 1.5, 0.4), RED, 0.6, 2.2)
	fuse_box = {"node": node, "slots": slots, "lamp": lamp, "shine": shine}
	return node

## The fuses are in: they glow in their slots, the lamp goes green.
func fuses_in() -> void:
	if fuse_box.is_empty():
		return
	for fuse: Node3D in fuse_box.slots:
		fuse.visible = true
	(fuse_box.lamp as MeshInstance3D).material_override = _mat(GREEN, 3.0)
	(fuse_box.shine as OmniLight3D).light_color = GREEN

## The objective is done: the screen says so, the cells are all lit, the lights stop.
func done() -> void:
	finished = true
	lockdown(false)
	if not screen.is_empty():
		_screen("OFFEN", GREEN, 1.0)
	for cell in ring_cells:
		cell.material_override = _mat(GREEN, 2.2)
	if ring_lamp != null:
		ring_lamp.light_color = GREEN

func _screen(text: String, color: Color, amount: float) -> void:
	(screen.line as Label3D).text = text
	# (A dark screen in the colour of its state, the words bright on it.)
	(screen.face as MeshInstance3D).material_override = _mat(color.darkened(0.78), 0.5)
	(screen.line as Label3D).modulate = color.lightened(0.45)
	(screen.shine as OmniLight3D).light_color = color
	(screen.fill as Node3D).scale.x = maxf(0.001, amount)

# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	clock += delta
	for entry in beacons:
		if bool(entry.on):
			(entry.head as Node3D).rotation.y += delta * 5.2
	for entry in shutters:
		var slats: Node3D = entry.slats
		slats.scale.y = move_toward(slats.scale.y, 1.0 if bool(entry.down) else 0.02, delta * 0.9)
	for k in range(turning.size() - 1, -1, -1):
		var entry: Dictionary = turning[k]
		var node: Node3D = entry.node
		entry.left = float(entry.left) - delta
		if not is_instance_valid(node):
			turning.remove_at(k)
			continue
		var share := clampf(1.0 - float(entry.left) / 1.2, 0.0, 1.0)
		if node.has_meta("wheel"):
			(node.get_meta("wheel") as Node3D).rotation.z = -share * TAU * 1.5
			(node.get_meta("needle") as Node3D).rotation.z = lerpf(1.0, -0.9, share)
		if node.has_meta("lever"):
			(node.get_meta("lever") as Node3D).rotation.x = lerpf(0.9, -0.9, share)
		if float(entry.left) <= 0.0:
			turning.remove_at(k)
	if finished:
		return
	var run: HiveAreaRun = director.run
	var state := str(run.task.get("state", ""))
	if not screen.is_empty():
		if state == "hacking":
			var share := clampf(director.progress, 0.0, 1.0)
			var blink := "" if int(clock * 2.0) % 2 == 0 else " _"
			_screen("ÜBERBRÜCKUNG  %d %%%s" % [int(share * 100.0), blink], AMBER, share)
		else:
			_screen("GESPERRT", SCREEN_RED, 0.001)
	if not ring_cells.is_empty():
		var lit := int(floor(clampf(director.progress, 0.0, 1.0) * CELLS)) if state == "holding" else 0
		for k in range(ring_cells.size()):
			ring_cells[k].material_override = _mat(AMBER, 2.4) if k < lit else _mat(Color("39342a"))
		if ring_lamp != null:
			ring_lamp.light_energy = 1.6 + (0.8 * sin(clock * 6.0) if state == "holding" else 0.0)

## How many cells of the hold point's ring are lit (for the checks).
func lit_cells() -> int:
	var lit := 0
	for cell in ring_cells:
		if (cell.material_override as StandardMaterial3D).emission_enabled:
			lit += 1
	return lit
