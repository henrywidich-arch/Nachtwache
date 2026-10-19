class_name VillaGuests
extends Node3D
## Two harmless guests up on the villa's gallery (mission two): the user's two plain men
## (SoldierVisual looks "guest_shorts" and "guest_turtleneck", without weapons). Each
## stands about for a long while at one of a few places, looks about now and then and
## turns to the survivor when he comes near; now and again he strolls over to another of
## those places. They say nothing, take no part in the fight and have no body to collide
## with: nobody bumps into them, bullets pass through them, the infected do not see them,
## and they never stand in a doorway or on the stairs (the places are away from both).
## The villa's map (HiveMap) puts one of these into itself; nothing else knows of them.

## Where they stand, on the gallery's floor (x across the hall, z from its back wall,
## 8.24, to the balustrade, 11.5). The flights come up at x = ±4.5 to ±6.5, the two doors
## that stay shut are at x = ±3.2 (and look like doors): every place lies between the
## doors, a metre and more from each of them and well away from the stairs.
const SPOTS: Array[Vector2] = [Vector2(-1.9, 10.6), Vector2(-0.9, 9.3), Vector2(0.0, 10.5), Vector2(1.0, 9.3), Vector2(1.9, 10.6)]
const LOOKS: Array[String] = ["guest_shorts", "guest_turtleneck"]
## Walking pace, in metres a second.
const PACE := 0.85
## How long one of them stands at a place before he may go on, in seconds; and the chance
## that he does go then (otherwise he stands on for another while).
const STAND := Vector2(9.0, 22.0)
const GO_CHANCE := 0.45
## Now and then, standing, he looks somewhere else: every so many seconds, this far.
const GLANCE := Vector2(3.5, 8.0)
const GLANCE_ANGLE := 1.1
## From how near the survivor is noticed (he is turned to, and looked at).
const NOTICE := 5.5
## How fast a body turns, in radians a second.
const TURN_RATE := 2.2
## Beyond this distance from the survivor they are not animated at all.
const AWAKE := 60.0

var guests: Array[Dictionary] = []
var dice := RandomNumberGenerator.new()
## The floor they stand on (HiveMap.STOREY_VILLA).
var floor_y := 4.4

func _ready() -> void:
	name = "VillaGuests"
	# The same dice on both machines of a co-op match: the two start alike.
	dice.seed = 4410
	for i in range(LOOKS.size()):
		var body := SoldierVisual.new()
		body.look = LOOKS[i]
		add_child(body)
		var spot := i * 3
		body.position = _place(spot)
		body.rotation.y = dice.randf_range(-PI, PI)
		guests.append({"body": body, "spot": spot, "target": spot, "wait": dice.randf_range(STAND.x, STAND.y) * 0.5,
			"glance": dice.randf_range(GLANCE.x, GLANCE.y), "facing": body.rotation.y, "turn": 0.0, "nod": 0.0})

func _place(spot: int) -> Vector3:
	return Vector3(SPOTS[spot].x, floor_y, SPOTS[spot].y)

## Where the survivor's eyes are, if there is one to look at.
func _viewer() -> Variant:
	# (The map hangs its parts into zones of its own: the game is further up.)
	var game: Node = get_parent()
	while game != null and not ("player" in game):
		game = game.get_parent()
	if game == null or not is_instance_valid(game.player):
		return null
	return (game.player as Node3D).global_position + Vector3(0, 1.6, 0)

func _process(delta: float) -> void:
	# (The map hides a zone nobody is near: then there is nothing to animate.)
	if not is_visible_in_tree():
		return
	var eye: Variant = _viewer()
	for guest in guests:
		var body: SoldierVisual = guest.body
		if eye != null and (eye as Vector3).distance_to(body.global_position) > AWAKE:
			continue
		var velocity := Vector3.ZERO
		var near := eye != null and Vector2((eye as Vector3).x - body.global_position.x, (eye as Vector3).z - body.global_position.z).length() < NOTICE
		if int(guest.target) != int(guest.spot):
			# Strolling over to another place.
			var goal := _place(int(guest.target))
			var way := goal - body.position
			way.y = 0.0
			if way.length() < 0.06:
				guest.spot = guest.target
				guest.wait = dice.randf_range(STAND.x, STAND.y)
			else:
				velocity = way.normalized() * PACE
				body.position += velocity * minf(delta, way.length() / PACE)
				guest.facing = atan2(-way.x, -way.z)
		else:
			guest.wait = float(guest.wait) - delta
			guest.glance = float(guest.glance) - delta
			if near:
				# He turns to whoever comes up to him.
				var to := (eye as Vector3) - body.global_position
				guest.facing = atan2(-to.x, -to.z)
			elif float(guest.glance) <= 0.0:
				guest.glance = dice.randf_range(GLANCE.x, GLANCE.y)
				guest.facing = wrapf(float(guest.facing) + dice.randf_range(-GLANCE_ANGLE, GLANCE_ANGLE), -PI, PI)
			if float(guest.wait) <= 0.0 and not near:
				guest.wait = dice.randf_range(STAND.x, STAND.y)
				if dice.randf() < GO_CHANCE:
					guest.target = _free_spot(guest)
		body.rotation.y = wrapf(rotate_toward(body.rotation.y, float(guest.facing), TURN_RATE * delta), -PI, PI)
		body.animate(delta, velocity, false, false)
		_look_at(guest, eye if near else null, delta)

## Another place that neither of them stands at or walks to, and whose way does not pass
## the other one (nor where he is going).
func _free_spot(guest: Dictionary) -> int:
	var taken := {}
	var others: Array[Vector2] = []
	for other in guests:
		taken[int(other.spot)] = true
		taken[int(other.target)] = true
		if other != guest:
			var body: SoldierVisual = other.body
			others.append(Vector2(body.position.x, body.position.z))
			others.append(SPOTS[int(other.target)])
	var from := SPOTS[int(guest.spot)]
	var free: Array[int] = []
	for i in range(SPOTS.size()):
		if taken.has(i):
			continue
		var clear := true
		for point in others:
			clear = clear and Geometry2D.get_closest_point_to_segment(point, from, SPOTS[i]).distance_to(point) > 0.8
		if clear:
			free.append(i)
	return int(guest.spot) if free.is_empty() else free[dice.randi_range(0, free.size() - 1)]

## The head follows the survivor on top of the clip, as far as a neck turns.
func _look_at(guest: Dictionary, eye: Variant, delta: float) -> void:
	var body: SoldierVisual = guest.body
	var want_turn := 0.0
	var want_nod := 0.0
	if eye != null:
		var local := body.to_local(eye as Vector3) - Vector3(0, 1.55, 0)
		# (The body faces -z.)
		want_turn = clampf(atan2(-local.x, -local.z), -0.7, 0.7)
		want_nod = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.3, 0.3)
	guest.turn = lerpf(float(guest.turn), want_turn, minf(1.0, delta * 3.0))
	guest.nod = lerpf(float(guest.nod), want_nod, minf(1.0, delta * 3.0))
	var head := int(body.rig.head.index)
	if head < 0 or (absf(float(guest.turn)) < 0.01 and absf(float(guest.nod)) < 0.01):
		return
	var skeleton := body.skeleton
	var pose := skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) * (pose.inverse() * Quaternion.from_euler(Vector3(-float(guest.nod), float(guest.turn), 0)) * pose))
