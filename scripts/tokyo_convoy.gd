class_name TokyoConvoy
extends RefCounted
## (v0.91) The other job the simulation hall can have in a night (TokyoTasks.job_of): the
## rocket launcher. The gate from the terminal into the facility is jammed this night; the
## way on is the barred steel door in the hall's west wall, north of the lock (HiveMap.
## _lay_tokyo_breach), and only a rocket opens it.
##
##   parked  the launcher (RocketTruck) stands in the east of the hall, its driver at the
##           wheel. [E] at it sends it off.
##   drive   it rolls along the ring road round the hall - south, west, north - to its
##           firing place before the lock, at walking pace and only while one of the humans
##           is near it (ESCORT). What stands in front of it is run over (the big ones and
##           the humans stop it, it hoots); the infected that crowd round it wear it down
##           (HARM). Worn down it breaks down: smoke and fire, [E] mends it (FIX_SECONDS
##           while somebody stays at it).
##   aim     at its place it raises its launcher and turns it on the door; the squad holds
##           it AIM_SECONDS while the hall throws everything it has at them.
##   fire    a rocket leaves the left pod, arcs over the ring and strikes the door.
##   open    the door is torn out; the way to the administration is free (the director
##           goes on to its next stage, Hive._convoy_open).
##
## The host runs it (update, from TokyoTasks); both machines show it (display). The guest
## follows the host's snapshot (export / adopt in TokyoTasks) and asks with [E] (keys
## "tk_truck" and "tk_fix"). In the test room (Sandbox, "tokyo_konvoi") it runs without a
## director.

## The steel door: its name in the map, and where it lies along the west wall (hall's z).
const DOOR := "tk_breach"
const DOOR_Z := -25.4
## The road of the launcher in the hall's own plan (x, z), its corners rounded (CORNER).
const ROUTE := [Vector2(66.0, 24.0), Vector2(66.0, 66.0), Vector2(-66.0, 66.0), Vector2(-66.0, 9.0)]
const CORNER := 8.0
const SPEED := 3.3
const ACCEL := 1.1
## How near a human has to be for it to roll on; how near to mend it or send it off.
const ESCORT := 20.0
const REACH := 3.2
## Its strength, and what each infected at its flanks takes from it each second.
const ARMOUR := 100.0
const HARM := 1.5
const FIX_SECONDS := 8.0
const FIXED_TO := 55.0
const RAISE_SECONDS := 7.0
const AIM_SECONDS := 60.0
const FLIGHT := 1.35
## More of them, sooner, while it is on the way and while it aims.
const HASTE := 0.6
const MORE := 4
const REWARD := 500
## Kinds that the truck does not run over: they stop it.
const STOPPERS := ["crusher", "prowler", "prowler_elite", "boss", "stalker", "cru_shield"]

var game: Node3D
var hall: TokyoHall
var map: HiveCore
## The director of the night (null in the test room).
var director: Node
var truck: RocketTruck
var door_node: Node3D
var wreck: Node3D
var rocket: Node3D
var rocket_from := Vector3.ZERO
var rocket_bend := Vector3.ZERO
var rocket_to := Vector3.ZERO
var rocket_time := -1.0
## The road: points (global, on the floor) and how far along it each lies.
var path: PackedVector3Array = PackedVector3Array()
var along: PackedFloat32Array = PackedFloat32Array()
var length := 0.0

# What the host decides (and sends).
var phase := "parked"
var travelled := 0.0
var speed := 0.0
var armour := ARMOUR
var broken := false
var fixing := false
var fix := 0.0
var aim := 0.0
var aim_time := 0.0
var told := false
var stalled := ""
# What is shown.
var shown := 0.0
var raise_shown := 0.0
var yaw_shown := 0.0
var shown_phase := "parked"
var hoot_left := 0.0
var harm_left := 0.0
var posted := {}

func _init(the_game: Node3D, the_hall: TokyoHall, the_map: HiveCore, the_director: Node) -> void:
	game = the_game
	hall = the_hall
	map = the_map
	director = the_director

# ---------------------------------------------------------------- building

func setup() -> void:
	clear()
	_lay_path()
	truck = RocketTruck.new()
	truck.name = "RocketTruck"
	truck.fx = game.get("fx")
	game.add_child(truck)
	_place_truck(0.0, 0.0)
	_build_door()
	map.set_door(DOOR, false, true)

func clear() -> void:
	for node in [truck, door_node, wreck, rocket]:
		if is_instance_valid(node):
			(node as Node3D).queue_free()
	truck = null
	door_node = null
	wreck = null
	rocket = null
	phase = "parked"
	shown_phase = "parked"
	travelled = 0.0
	shown = 0.0
	speed = 0.0
	armour = ARMOUR
	broken = false
	fixing = false
	fix = 0.0
	aim = 0.0
	aim_time = 0.0
	told = false
	stalled = ""
	posted.clear()
	rocket_time = -1.0

func _lay_path() -> void:
	path = PackedVector3Array()
	var points: Array[Vector2] = []
	points.append(ROUTE[0])
	for i in range(1, ROUTE.size() - 1):
		var corner: Vector2 = ROUTE[i]
		var before: Vector2 = corner + ((ROUTE[i - 1] as Vector2) - corner).normalized() * CORNER
		var after: Vector2 = corner + ((ROUTE[i + 1] as Vector2) - corner).normalized() * CORNER
		for k in range(0, 11):
			var t := k / 10.0
			points.append(before.lerp(corner, t).lerp(corner.lerp(after, t), t))
	points.append(ROUTE[ROUTE.size() - 1])
	var floor_y := hall.origin.y
	along = PackedFloat32Array()
	length = 0.0
	for i in range(points.size()):
		var at := Vector3(points[i].x + hall.origin.x, floor_y, points[i].y + hall.origin.z)
		if i > 0:
			length += at.distance_to(path[i - 1])
		path.append(at)
		along.append(length)

## Where on the road `s` lies, which way it goes there and how hard it turns.
func _pose(s: float) -> Array:
	s = clampf(s, 0.0, length)
	var i := 1
	while i < along.size() - 1 and along[i] < s:
		i += 1
	var a := path[i - 1]
	var b := path[i]
	var span := maxf(0.001, along[i] - along[i - 1])
	var at := a.lerp(b, clampf((s - along[i - 1]) / span, 0.0, 1.0))
	var ahead := _heading(s + 1.5)
	var back := _heading(s - 1.5)
	var turn := wrapf(ahead - back, -PI, PI) / 3.0
	return [at, _heading(s), turn]

func _heading(s: float) -> float:
	s = clampf(s, 0.0, length - 0.01)
	var i := 1
	while i < along.size() - 1 and along[i] < s:
		i += 1
	var d := path[i] - path[i - 1]
	return atan2(-d.x, -d.z)

func _place_truck(s: float, moved: float) -> void:
	var pose := _pose(s)
	truck.global_position = pose[0]
	truck.rotation.y = float(pose[1])
	truck.drive(moved, float(pose[2]), 0.016)

## The heavy door before the lock, on the hall's side of the map's own shutter: plates of
## steel welded together, a cross of girders, warning stripes, a red lamp.
func _build_door() -> void:
	door_node = Node3D.new()
	door_node.name = "TokyoBreachDoor"
	game.add_child(door_node)
	door_node.global_position = door_at() + Vector3(0, -1.6, 0)
	door_node.rotation.y = -PI / 2
	var b := MeshBatch.new()
	var plate := StandardMaterial3D.new()
	plate.vertex_color_use_as_albedo = true
	plate.metallic = 0.7
	plate.roughness = 0.5
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.12, 0.08)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.1, 0.05)
	glow.emission_energy_multiplier = 3.0
	var steel := Color(0.24, 0.25, 0.26)
	for k in range(4):
		b.box(plate, Vector3(-1.35 + k * 0.9, 1.7, 0.0), Vector3(0.88, 3.4, 0.16), steel.darkened(0.1 * (k % 2)))
	for y in [0.15, 1.1, 2.3, 3.3]:
		b.box(plate, Vector3(0, y, -0.12), Vector3(3.7, 0.18, 0.1), Color(0.18, 0.19, 0.2))
	for side in [-1.0, 1.0]:
		b.box(plate, Vector3(0, 1.7, -0.22), Vector3(4.4, 0.28, 0.14), Color(0.32, 0.27, 0.2), Basis(Vector3(0, 0, 1), side * 0.72))
		b.box(plate, Vector3(side * 1.95, 1.7, -0.1), Vector3(0.3, 3.6, 0.3), Color(0.18, 0.19, 0.2))
	for i in range(10):
		b.box(plate, Vector3(-1.62 + i * 0.36, 0.5, -0.18), Vector3(0.36, 0.3, 0.02), Color(0.85, 0.66, 0.08) if i % 2 == 0 else Color(0.05, 0.05, 0.05), Basis(Vector3(0, 0, 1), 0.0))
	for x in range(-8, 9):
		for y in [0.3, 3.1]:
			b.box(plate, Vector3(x * 0.2, y, -0.09), Vector3(0.05, 0.05, 0.04), Color(0.15, 0.15, 0.15))
	b.box(glow, Vector3(0, 3.7, -0.15), Vector3(0.3, 0.14, 0.14), Color.WHITE)
	b.commit(door_node, "Door")
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1, 0.15, 0.1)
	lamp.light_energy = 1.2
	lamp.omni_range = 6.0
	lamp.position = Vector3(0, 3.7, -0.6)
	door_node.add_child(lamp)
	var words := Label3D.new()
	words.text = "SCHLEUSE W-2  ·  GESPERRT\nZUGANG VERWALTUNG"
	words.font_size = 56
	words.pixel_size = 0.005
	words.modulate = Color("ffcf8a")
	words.position = Vector3(0, 4.25, -0.25)
	words.rotation.y = PI
	door_node.add_child(words)

## The middle of the door, on the hall's side.
func door_at() -> Vector3:
	return hall.origin + Vector3(-TokyoHall.TK_HALL + 0.15, 1.6, DOOR_Z)

func truck_at() -> Vector3:
	return truck.global_position if is_instance_valid(truck) else Vector3.INF

# ---------------------------------------------------------------- who is about

func _humans() -> Array:
	var out: Array = [game.player]
	if game.net.hosting and is_instance_valid(game.net.remote) and not game.net.remote.down:
		out.append(game.net.remote)
	return out

## How far `pos` is from the truck's flank (0 inside it).
func _off_hull(pos: Vector3) -> float:
	if not is_instance_valid(truck):
		return INF
	var local := truck.to_local(pos)
	var dx := maxf(0.0, absf(local.x) - 1.35)
	var dz := maxf(0.0, maxf(local.z - 4.3, -5.0 - local.z))
	return Vector2(dx, dz).length()

func _nearest_human() -> float:
	var best := INF
	for who: Node3D in _humans():
		if not bool(who.get("down")):
			best = minf(best, _off_hull(who.global_position))
	return best

# ---------------------------------------------------------------- the host, each frame

func update(delta: float) -> void:
	if not is_instance_valid(truck):
		return
	if not told:
		for who: Node3D in _humans():
			if TokyoHall.plan_of(hall.origin).has_point(Vector2(who.global_position.x, who.global_position.z)):
				told = true
				game.hud.announce("RAKETENWERFER", "Der Weg zur Anlage ist zu. Bringt den Raketenwerfer im Osten der Halle zur Stahltür an der Westwand – er sprengt sie auf.", 8)
				game.sounds.play_sound("beep")
				break
	if broken and fixing:
		if _nearest_human() < REACH + 0.8:
			fix = minf(1.0, fix + delta / FIX_SECONDS)
		if fix >= 1.0:
			broken = false
			fixing = false
			fix = 0.0
			armour = FIXED_TO
			game.sounds.play_at("clear", truck.global_position)
			game.hud.announce("WIEDER FAHRBEREIT", "Der Motor läuft. Bleibt bei ihm.", 4)
	match phase:
		"drive":
			_drive(delta)
		"aim":
			_aim(delta)
		"fire":
			pass
	if phase in ["drive", "aim"] and not broken:
		_wear(delta)

func _drive(delta: float) -> void:
	stalled = ""
	if broken:
		stalled = "broken"
	elif _nearest_human() > ESCORT:
		stalled = "alone"
	else:
		var block := _in_front()
		if block != "":
			stalled = block
	var wanted := 0.0 if stalled != "" else SPEED
	speed = move_toward(speed, wanted, ACCEL * delta * (3.0 if wanted < speed else 1.0))
	travelled = minf(length, travelled + speed * delta)
	# Ambushes along the way (once each), ahead of it on the road.
	for mark: float in [0.02, 0.3, 0.55, 0.8]:
		var key := "drive_%d" % int(mark * 100.0)
		if travelled >= mark * length and not posted.has(key):
			posted[key] = true
			_ambush(travelled + 34.0, 5 if mark > 0.25 else 3)
	if travelled >= length - 0.05:
		phase = "aim"
		speed = 0.0
		aim = 0.0
		aim_time = 0.0
		game.sounds.play_at("wave", truck.global_position, 2.0)
		game.hud.announce("FEUERSTELLUNG", "Der Werfer richtet sich auf die Stahltür. Haltet ihn %d Sekunden – die Halle schickt alles, was sie hat." % int(AIM_SECONDS), 7)

## What stands before the bumper: the humans and the big ones stop it ("person", "heavy");
## the others it runs down.
func _in_front() -> String:
	for body in game.survivors:
		if is_instance_valid(body) and _ahead(body.global_position):
			if hoot_left <= 0.0:
				hoot_left = 3.0
				_hoot()
			return "person"
	for node in game.get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy == null or enemy.dead or not _ahead(enemy.global_position):
			continue
		if enemy.kind in STOPPERS:
			return "heavy"
		if speed > 0.8:
			var away := (-truck.global_basis.z + truck.global_basis.x * signf(truck.to_local(enemy.global_position).x + 0.01) * 0.7).normalized()
			enemy.hit_hard(enemy.max_health * 3.0 + 400.0, away, false, null, 7.0, 0.5)
			game.sounds.play_at("thud", enemy.global_position, 3.0)
		else:
			return "crowd"
	return ""

func _ahead(pos: Vector3) -> bool:
	var local := truck.to_local(pos)
	return absf(local.x) < 1.7 and local.z < -4.4 and local.z > -7.2 and absf(local.y) < 2.5

func _hoot() -> void:
	var horn := load("res://assets/sounds/truck_horn.wav") as AudioStream
	if horn == null or not is_instance_valid(truck):
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = horn
	voice.bus = "Field"
	voice.unit_size = 8.0
	voice.position = Vector3(0, 1.6, -4.8)
	truck.add_child(voice)
	voice.play()
	voice.finished.connect(voice.queue_free)

## The infected at its flanks wear it down; worn down it breaks down.
func _wear(delta: float) -> void:
	harm_left -= delta
	if harm_left > 0.0:
		return
	harm_left = 0.25
	var at_it := 0
	for node in game.get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy != null and not enemy.dead and _off_hull(enemy.global_position) < 1.1:
			at_it += 3 if enemy.kind in STOPPERS else 1
	if at_it == 0:
		return
	armour = maxf(0.0, armour - HARM * at_it * 0.25)
	if armour <= 0.0:
		broken = true
		fixing = false
		fix = 0.0
		speed = 0.0
		game.sounds.play_at("explosion", truck.global_position + Vector3(0, 1.5, -4.0), -6.0)
		game.hud.announce("RAKETENWERFER LIEGT FEST", "Der Motor brennt. [E] am Fahrzeug: reparieren – und dabei bleiben.", 6)

func _aim(delta: float) -> void:
	aim_time += delta
	if not broken and _nearest_human() < ESCORT * 1.5 and aim_time > RAISE_SECONDS:
		aim = minf(1.0, aim + delta / AIM_SECONDS)
	for mark: float in [0.0, 0.35, 0.7]:
		var key := "aim_%d" % int(mark * 100.0)
		if aim >= mark and aim_time > 2.0 and not posted.has(key):
			posted[key] = true
			_ambush(-1.0, 6)
	if aim >= 1.0:
		phase = "fire"
		_launch(true)

## A pack of them: ahead on the road (`s`), or round the firing place (s < 0).
func _ambush(s: float, count: int) -> void:
	var kinds := ["mauler", "mauler", "striker", "mauler", "charger", "ripper", "mauler", "striker"]
	var places: Array = []
	if s >= 0.0:
		var pose := _pose(minf(s, length))
		var at: Vector3 = pose[0]
		for k in range(count):
			places.append(at + Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0)))
	else:
		var base := truck.global_position
		for k in range(count):
			var side := (k % 3) - 1
			places.append(base + Vector3(randf_range(4.0, 7.0) if side >= 0 else randf_range(-3.0, -1.0), 0, side * randf_range(14.0, 22.0)))
	for k in range(count):
		_place(str(kinds[(k + posted.size()) % kinds.size()]), places[k])

func _place(kind: String, place: Vector3) -> void:
	if director != null and director.has_method("_place"):
		director._place(kind, place)
		return
	var level := map.level_of(place + Vector3(0, 0.3, 0))
	var cell := map._free_near(level, Vector2(place.x, place.z), 6)
	if cell.x > 99999:
		return
	var enemy: Infected = game.spawn_enemy(kind)
	if is_instance_valid(enemy):
		enemy.position = Vector3(cell.x * CabinMap.CELL, map.level_height(level), cell.y * CabinMap.CELL) + Vector3(0, 0.08, 0)

## The rocket leaves (on both machines; the host's blows the door when it lands).
func _launch(host: bool) -> void:
	if not is_instance_valid(truck):
		return
	rocket_from = truck.fire_point()
	rocket_bend = rocket_from + truck.fire_direction() * 16.0 + Vector3(0, 4.0, 0)
	rocket_to = door_at()
	rocket_time = 0.0
	truck.spend()
	rocket = Node3D.new()
	rocket.name = "ConvoyRocket"
	game.add_child(rocket)
	var body := MeshInstance3D.new()
	body.mesh = RocketTruck.rocket()
	rocket.add_child(body)
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.6, 0.25)
	flame.light_energy = 4.0
	flame.omni_range = 10.0
	flame.position = Vector3(0, 0, 3.0)
	rocket.add_child(flame)
	var trail := CPUParticles3D.new()
	trail.amount = 90
	trail.lifetime = 1.4
	trail.local_coords = false
	var puff := QuadMesh.new()
	puff.size = Vector2(0.8, 0.8)
	var grey := StandardMaterial3D.new()
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	grey.vertex_color_use_as_albedo = true
	puff.material = grey
	trail.mesh = puff
	trail.gravity = Vector3(0, 0.6, 0)
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.6
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.8
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(1.0, 0.75, 0.35, 0.9), Color(1.0, 0.5, 0.2, 0.7), Color(0.55, 0.53, 0.5, 0.45), Color(0.5, 0.5, 0.5, 0.0)])
	trail.color_ramp = fade
	trail.position = Vector3(0, 0, 3.0)
	rocket.add_child(trail)
	rocket.global_position = rocket_from
	game.sounds.play_at("launcher", rocket_from, 8.0, 0.6)
	game.sounds.play_on("shell_flight", rocket, 6.0)
	var back := truck.pitch.to_global(Vector3(0, 0, 0.6))
	game.fx.launch_smoke(rocket_from, truck.fire_direction())
	game.fx.launch_smoke(back, -truck.fire_direction())
	if host:
		game.hud.announce("RAKETE LOS", "In Deckung!", 3)

func _fly(delta: float, host: bool) -> void:
	if rocket_time < 0.0 or not is_instance_valid(rocket):
		return
	rocket_time += delta
	var t := minf(1.0, rocket_time / FLIGHT)
	var u := 1.0 - t
	var pos := rocket_from * u * u + rocket_bend * 2.0 * u * t + rocket_to * t * t
	var way := (rocket_bend - rocket_from) * 2.0 * u + (rocket_to - rocket_bend) * 2.0 * t
	rocket.global_position = pos
	if way.length() > 0.01:
		rocket.look_at(pos + way, Vector3.UP)
	if t >= 1.0:
		rocket_time = -1.0
		rocket.queue_free()
		rocket = null
		if host:
			_blow()

## The rocket strikes: the door is torn out (host; the guest sees it in the snapshot).
func _blow() -> void:
	game.explode(door_at(), 9.0, 45.0, 1500.0, "blast")
	phase = "open"
	_show_open()
	game.earn_tokens(REWARD)
	game.stats.objectives += 1
	game.sounds.play_sound("clear")
	game.hud.announce("WEG FREI", "+%d ◈  ·  Die Stahltür ist weg. Durch die Schleuse zum Kontrollpunkt der Verwaltung." % REWARD, 7)
	if director != null and director.has_method("_convoy_open"):
		director._convoy_open()

func _show_open() -> void:
	map.set_door(DOOR, true, true)
	if is_instance_valid(door_node):
		door_node.queue_free()
	door_node = null
	if is_instance_valid(wreck):
		return
	wreck = Node3D.new()
	wreck.name = "TokyoBreachWreck"
	game.add_child(wreck)
	wreck.global_position = hall.origin + Vector3(-TokyoHall.TK_HALL, 0, DOOR_Z)
	var b := MeshBatch.new()
	var plate := StandardMaterial3D.new()
	plate.vertex_color_use_as_albedo = true
	plate.metallic = 0.6
	plate.roughness = 0.65
	# Torn plates lying in the hall, bent girders, the frame black with soot.
	b.box(plate, Vector3(4.5, 0.12, 1.2), Vector3(1.8, 0.14, 0.9), Color(0.16, 0.15, 0.14), Basis(Vector3(0, 1, 0), 0.6) * Basis(Vector3(1, 0, 0), 0.15))
	b.box(plate, Vector3(6.2, 0.1, -1.6), Vector3(0.9, 0.12, 1.6), Color(0.2, 0.19, 0.17), Basis(Vector3(0, 1, 0), -0.9))
	b.box(plate, Vector3(3.0, 0.35, -0.5), Vector3(3.6, 0.22, 0.22), Color(0.28, 0.22, 0.16), Basis(Vector3(0, 1, 0), 0.3) * Basis(Vector3(0, 0, 1), 0.2))
	b.box(plate, Vector3(8.0, 0.1, 0.8), Vector3(0.7, 0.1, 0.7), Color(0.18, 0.18, 0.17), Basis(Vector3(0, 1, 0), 1.2))
	for side in [-1.0, 1.0]:
		b.box(plate, Vector3(0.08, 1.8, side * 2.0), Vector3(0.12, 3.8, 0.5), Color(0.05, 0.05, 0.05))
	b.box(plate, Vector3(0.08, 3.6, 0), Vector3(0.12, 0.5, 4.4), Color(0.05, 0.05, 0.05))
	b.commit(wreck, "Wreck")
	var ember := OmniLight3D.new()
	ember.light_color = Color(1.0, 0.45, 0.15)
	ember.light_energy = 1.5
	ember.omni_range = 5.0
	ember.position = Vector3(3.0, 0.8, 0)
	wreck.add_child(ember)
	if game.get("fx") != null:
		var fire: CPUParticles3D = game.fx.body_flames(0.5, 0.7)
		fire.position = Vector3(4.5, 0.1, 1.2)
		wreck.add_child(fire)

# ---------------------------------------------------------------- both machines, each frame

func display(delta: float) -> void:
	if not is_instance_valid(truck):
		return
	hoot_left -= delta
	var before := shown
	if game.net.joined:
		shown = lerpf(shown, travelled, minf(1.0, delta * 3.0))
	else:
		shown = travelled
	var pose := _pose(shown)
	truck.global_position = pose[0]
	truck.rotation.y = float(pose[1])
	truck.drive(shown - before, float(pose[2]), delta)
	# The launcher goes up at its place and turns on the door.
	var want_raise := 0.0
	var want_yaw := 0.0
	if phase in ["aim", "fire", "open"]:
		want_raise = 1.0
		var local := truck.to_local(door_at()) - RocketTruck.TURRET_AT
		want_yaw = clampf(atan2(-local.x, -local.z), -0.6, 0.6)
	var rate := delta / RAISE_SECONDS
	raise_shown = move_toward(raise_shown, want_raise, rate)
	yaw_shown = move_toward(yaw_shown, want_yaw, rate * 0.8)
	truck.set_launcher(raise_shown, yaw_shown)
	if want_raise > 0.0 and raise_shown < 1.0 and raise_shown > 0.0 and not posted.has("_hiss"):
		posted["_hiss"] = true
		var hiss := load("res://assets/sounds/truck_hydraulic.wav") as AudioStream
		if hiss != null:
			var voice := AudioStreamPlayer3D.new()
			voice.stream = hiss
			voice.bus = "Field"
			voice.unit_size = 6.0
			voice.position = RocketTruck.TURRET_AT
			truck.add_child(voice)
			voice.play()
			voice.finished.connect(voice.queue_free)
	truck.display(delta, phase != "parked", phase in ["drive", "aim"], 1.0 - armour / ARMOUR, broken)
	# What the guest learns from the snapshot: the rocket and the open door.
	if shown_phase != phase:
		if game.net.joined and phase == "fire" and rocket_time < 0.0 and not is_instance_valid(rocket):
			_launch(false)
		if phase == "open" and game.net.joined:
			_show_open()
			if is_instance_valid(truck):
				truck.spend()
		shown_phase = phase
	_fly(delta, not game.net.joined)

# ---------------------------------------------------------------- [E], the screen

func near_use(at: Vector3) -> Dictionary:
	if not is_instance_valid(truck) or _off_hull(at) > REACH:
		return {}
	if phase == "parked":
		return {"key": "tk_truck", "at": truck.global_position, "text": "[E]  Raketenwerfer losschicken  ·  zur Stahltür an der Westwand"}
	if broken and not fixing:
		return {"key": "tk_fix", "at": truck.global_position, "text": "[E]  Raketenwerfer reparieren  ·  %d s, dabei bleiben" % int(FIX_SECONDS)}
	return {}

func use(who: Node3D, key: String) -> bool:
	# (The guest's body on the host lags a little behind where he stands.)
	var slack := 0.8 if who == game.player else 2.0
	if not is_instance_valid(truck) or _off_hull(who.global_position) > REACH + slack:
		return false
	if key == "tk_truck" and phase == "parked":
		phase = "drive"
		told = true
		game.stats.objectives += 1
		game.sounds.play_sound("beep")
		_hoot()
		game.hud.announce("KONVOI", "Der Werfer fährt den Ring entlang zur Stahltür. Er rollt nur, solange ihr bei ihm seid – und was vor ihm steht, wird überfahren.", 7)
		return true
	if key == "tk_fix" and broken and not fixing:
		fixing = true
		game.sounds.play_sound("beep")
		game.hud.announce("REPARATUR", "Bleibt am Fahrzeug, bis der Motor wieder läuft.", 4)
		return true
	return false

func summary() -> Array[String]:
	var out: Array[String] = []
	if not told or phase == "open":
		return out
	var state := "  ·  Panzerung %d %%" % int(round(armour / ARMOUR * 100.0))
	match phase:
		"parked":
			out.append("▸  TOKIO: Den Raketenwerfer im Osten der Halle losschicken")
		"drive":
			out.append("▸  TOKIO: Raketenwerfer zur Stahltür begleiten  ·  %d %%%s" % [int(travelled / maxf(1.0, length) * 100.0), state])
		"aim", "fire":
			out.append("▸  TOKIO: Feuerstellung halten  ·  Zielerfassung %d %%%s" % [int(aim * 100.0), state])
	if broken:
		out.append("   LIEGT FEST  ·  " + ("Reparatur %d %%" % int(fix * 100.0) if fixing else "[E] am Fahrzeug reparieren"))
	elif phase == "drive":
		match stalled:
			"alone":
				out.append("   wartet auf euch  ·  bleibt in der Nähe")
			"person":
				out.append("   ihr steht ihm im Weg")
			"heavy", "crowd":
				out.append("   der Weg ist versperrt")
	elif phase == "aim" and aim_time > RAISE_SECONDS and _nearest_human() >= ESCORT * 1.5:
		out.append("   bleibt beim Werfer!")
	return out

func markers() -> Array:
	var out: Array = []
	if not told or not is_instance_valid(truck) or phase == "open":
		return out
	if phase in ["parked", "drive"] or broken:
		out.append({"pos": truck.global_position + Vector3(0, 4.2, 0), "text": "RAKETENWERFER"})
	if phase in ["drive", "aim", "fire"]:
		out.append({"pos": door_at() + Vector3(0, 2.4, 0), "text": "STAHLTÜR"})
	return out

func haste() -> float:
	return HASTE if phase in ["drive", "aim"] else 1.0

func more() -> int:
	return MORE if phase in ["drive", "aim"] else 0

func pending() -> bool:
	return phase != "open"

# ---------------------------------------------------------------- co-op

func export() -> Dictionary:
	return {"ph": phase, "s": travelled, "ar": armour, "br": broken, "fx": fixing, "fp": fix, "aim": aim, "at": aim_time, "told": told, "st": stalled}

func adopt(state: Dictionary) -> void:
	if state.is_empty():
		return
	phase = str(state.get("ph", phase))
	travelled = float(state.get("s", travelled))
	armour = float(state.get("ar", armour))
	broken = bool(state.get("br", broken))
	fixing = bool(state.get("fx", fixing))
	fix = float(state.get("fp", fix))
	aim = float(state.get("aim", aim))
	aim_time = float(state.get("at", aim_time))
	told = bool(state.get("told", told))
	stalled = str(state.get("st", stalled))
