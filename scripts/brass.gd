class_name BrassCasings
extends MultiMeshInstance3D
## Empty cases thrown out of a weapon's ejection port. A fixed pool of small brass
## cylinders drawn as one MultiMesh and moved by hand - no physics bodies, one ray when a
## case is thrown (where the floor is, and a wall right beside the port) -, so that 1200
## shots a minute cost next to nothing. A case flies out to the right and up with a spin,
## falls, bounces twice with a small tink (not every case: at that rate it would rattle),
## lies there and shrinks away after a few seconds. The oldest case is reused when the
## pool runs out.
##
## Any weapon can use it: WEAPONS[id].casing names the kind of case ("9mm" for now), the
## weapon's view a "Port" node (WeaponView.GUNS[id].port). A partner's shots in co-op throw
## them too (remote_survivor.gd, by the sound of the shot: SOUNDS).

const POOL := 96
## Seconds a case lies on the floor, and how long it takes to shrink away.
const LIE := 6.0
const FADE := 0.8
const GRAVITY := 9.8
## No two tinks closer together than this (seconds), and how loud (dB on its mix).
const TINK_GAP := 0.09
## The kinds of case: radius and length (metres), how hard they are thrown, and how far
## behind a partner's muzzle the port is (co-op). The pool's mesh is the 9 mm case; another
## kind is that case stretched.
const KINDS := {"9mm": [0.0049, 0.0192, 1.0, 0.13], "rifle": [0.0056, 0.039, 1.25, 0.5]}
## Shots of a co-op partner that throw a case, by their sound, and the kind of case.
const SOUNDS := {"hornet": "9mm", "hornet_sil": "9mm", "wirbel": "rifle", "wirbel_sil": "rifle", "falke": "rifle", "falke_sil": "rifle", "ak": "rifle", "ak_sil": "rifle", "g36": "rifle", "g36_sil": "rifle"}

var game: Node3D
var spots := PackedVector3Array()
var speeds := PackedVector3Array()
var axes := PackedVector3Array()
var rates := PackedFloat32Array()
var floors := PackedFloat32Array()
var ages := PackedFloat32Array()
var bounces := PackedInt32Array()
var turns: Array[Basis] = []
var sizes := PackedVector3Array()
var next := 0
var live := 0
var tink_left := 0.0
## How many cases were thrown and how many tinks were heard (for the checks).
var thrown := 0
var tinks := 0
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.seed = 7319
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape := CylinderMesh.new()
	var size: Array = KINDS["9mm"]
	shape.top_radius = float(size[0]) * 0.97
	shape.bottom_radius = float(size[0])
	shape.height = float(size[1])
	shape.radial_segments = 8
	shape.rings = 0
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.74, 0.53, 0.24)
	brass.metallic = 0.85
	brass.roughness = 0.38
	shape.material = brass
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = shape
	multimesh.instance_count = POOL
	spots.resize(POOL)
	speeds.resize(POOL)
	axes.resize(POOL)
	rates.resize(POOL)
	floors.resize(POOL)
	ages.resize(POOL)
	bounces.resize(POOL)
	turns.resize(POOL)
	sizes.resize(POOL)
	clear()

## Every case gone (a new match, a new level).
func clear() -> void:
	for i in range(POOL):
		ages[i] = -1.0
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	live = 0

## Throws a case from `from`: `frame` gives right (x), up (y) and back (z) of the weapon,
## `carry` the shooter's own speed, which the case keeps.
func eject(from: Vector3, frame: Basis, carry: Vector3 = Vector3.ZERO, kind: String = "9mm") -> void:
	var shape: Array = KINDS.get(kind, KINDS["9mm"])
	var base: Array = KINDS["9mm"]
	var i := next
	next = (next + 1) % POOL
	if ages[i] < 0.0:
		live += 1
	thrown += 1
	var right := frame.x.normalized()
	var up := frame.y.normalized()
	var back := frame.z.normalized()
	var speed := (right * random.randf_range(1.5, 2.3) + up * random.randf_range(1.3, 2.0) + back * random.randf_range(0.1, 0.5)) * float(shape[2]) + carry
	var floor_y := from.y - 1.6
	var world := get_world_3d()
	if world != null:
		var space := world.direct_space_state
		# A wall right beside the port: the case comes off it.
		var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + speed * 0.3, 1))
		if not side.is_empty():
			speed = speed.bounce((side.normal as Vector3).normalized()) * 0.4
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1))
		if not below.is_empty():
			floor_y = (below.position as Vector3).y
	spots[i] = from
	speeds[i] = speed
	axes[i] = Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1)).normalized()
	rates[i] = random.randf_range(14.0, 28.0)
	floors[i] = floor_y
	ages[i] = 0.0
	bounces[i] = 0
	sizes[i] = Vector3(float(shape[0]) / float(base[0]), float(shape[1]) / float(base[1]), float(shape[0]) / float(base[0]))
	# Thrown sideways: the case's length lies across the bore.
	turns[i] = frame.orthonormalized() * Basis(Vector3.FORWARD, PI / 2)
	_place(i, 1.0)

func _physics_process(delta: float) -> void:
	if live == 0:
		return
	tink_left = maxf(0.0, tink_left - delta)
	var radius: float = float(KINDS["9mm"][0])
	for i in range(POOL):
		var age := ages[i]
		if age < 0.0:
			continue
		age += delta
		ages[i] = age
		if bounces[i] < 3:
			var speed := speeds[i]
			speed.y -= GRAVITY * delta
			var spot := spots[i] + speed * delta
			turns[i] = Basis(axes[i], rates[i] * delta) * turns[i]
			if spot.y <= floors[i] + radius and speed.y < 0.0:
				spot.y = floors[i] + radius
				if bounces[i] == 0 and tink_left <= 0.0 and game != null and game.get("sounds") != null:
					game.sounds.play_at("brass", spot, 0.0, random.randf_range(0.92, 1.1))
					tink_left = TINK_GAP
					tinks += 1
				speed.y = -speed.y * 0.32
				speed.x *= 0.5
				speed.z *= 0.5
				rates[i] *= 0.45
				bounces[i] += 1
				if absf(speed.y) < 0.3:
					bounces[i] = 3
				if bounces[i] >= 3:
					# At rest: on its side, turned any way.
					turns[i] = Basis(Vector3.UP, random.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2)
			speeds[i] = speed
			spots[i] = spot
			_place(i, 1.0)
		elif age > LIE:
			var left := 1.0 - (age - LIE) / FADE
			if left <= 0.0:
				ages[i] = -1.0
				live -= 1
				multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			else:
				_place(i, left)

func _place(i: int, size: float) -> void:
	# (The case's own stretch along its axis, then the turn it has.)
	multimesh.set_instance_transform(i, Transform3D(turns[i] * Basis.from_scale(sizes[i] * size), spots[i]))

## How many cases are about (for the checks).
func count() -> int:
	return live
