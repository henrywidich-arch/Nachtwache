extends AreaKit
## What every transition between two areas is built from (see HiveLayout.shape_of): its
## legs - straight stretches of corridor, one or two, joined without a wall at a bend, or
## three in a line through a lock chamber -, the rooms beside them, and its ways in. A
## kind of transition says how wide and how high it is and dresses its legs and the rooms
## beside them (dress_leg, dress_beside); the corridor itself is the facility's (the
## passages of HiveMap: ribs, light coffers, lines on the floor).
##
## A transition stands in the world's own frame: its origin is (0, height, 0), so its
## local x and z are the world's.

## What it looks like inside; its own kind says more (see the scripts that extend this).
func style() -> String:
	return "lab"

func lines() -> Array:
	return [[-1.2, Color("2f8f8a")], [1.2, Color("2f8f8a")]]

func lay() -> void:
	var shape: Dictionary = piece.shape
	var t_info := HiveLayout.info(str(piece.def))
	var tall := float(t_info.get("height", 4.2))
	var legs: Array = shape.legs
	for leg: Dictionary in legs:
		var rect: Rect2 = leg.rect
		room(str(leg.name), float(leg.y) - o.y, rect.position.x, rect.position.y, rect.size.x, rect.size.y, tall, style(), leg_options(leg))
	for index in range(1, legs.size()):
		var before: Dictionary = legs[index - 1]
		var leg: Dictionary = legs[index]
		if int(leg.side) == int(before.side):
			door(str(before.name), str(leg.name), _middle_across(leg), float(shape.width) - 2.0, join_options(before, leg))
		else:
			# A bend: no wall at all where the second leg leaves the first.
			var corner: Vector2 = before.corner
			door(str(before.name), str(leg.name), corner.y if int(leg.side) in [EAST, WEST] else corner.x, float(shape.width) - 0.4, {"kind": "join"})
	for beside: Dictionary in shape.beside:
		var rect: Rect2 = beside.rect
		room(str(beside.name), 0.0, rect.position.x, rect.position.y, rect.size.x, rect.size.y, minf(tall, 3.8), beside_style(), beside_options())
	for leg: Dictionary in legs:
		dress_leg(leg)
	for beside: Dictionary in shape.beside:
		join_beside(beside)
		dress_beside(beside)
	ways(shape)
	# Where the transition begins and ends (for the director and the test room).
	var first: Dictionary = legs[0]
	var last: Dictionary = legs[legs.size() - 1]
	point("in", _inside(first, true))
	point("out", _inside(last, false))
	point("middle", _centre(legs[mini(1, legs.size() - 1)]))

func leg_options(_leg: Dictionary) -> Dictionary:
	return {"lamps": "none"}

func join_options(_before: Dictionary, _leg: Dictionary) -> Dictionary:
	return {"kind": "slide", "leaf": "double"}

func beside_style() -> String:
	return "lab"

func beside_options() -> Dictionary:
	return {}

## The room beside a leg is seen from the corridor: by default a pane of glass in each half
## of it, and in every second one a sliding door.
func join_beside(beside: Dictionary) -> void:
	var leg: Dictionary = _leg_named(str(beside.leg))
	var side := int(beside.side)
	var rect: Rect2 = beside.rect
	var from := rect.position.x if side in [NORTH, SOUTH] else rect.position.y
	var long := rect.size.x if side in [NORTH, SOUTH] else rect.size.y
	var number := int(str(beside.name).right(1))
	if number % 2 == 0:
		door(str(leg.name), str(beside.name), from + long * 0.3, 2.0, {"kind": "slide"})
		pane(str(leg.name), side, from + long * 0.72, minf(4.0, long * 0.4), 0.9, 2.5, "glass", str(beside.name))
	else:
		pane(str(leg.name), side, from + long * 0.5, minf(6.0, long * 0.7), 0.9, 2.5, "glass", str(beside.name))

func dress_leg(leg: Dictionary) -> void:
	m._chunk("Kit", false)
	m._passage(n(str(leg.name)), {"step": 5.5, "light": Color("d6f5e6"), "energy": 2.3, "reach": 10.0, "lines": lines(), "tray": -1, "fail": [1] if m.random.randi_range(0, 2) == 0 else []})

func dress_beside(_beside: Dictionary) -> void:
	pass

## Ways in: a hole in the ceiling every so many metres of corridor, and one in every
## second room beside it.
## The length of a bay of the passage (see HiveMap._passage): the ways in from above sit
## in the middle of a bay, beside its coffer of light and between its beams.
func bay_step() -> float:
	return 5.5

func ways(shape: Dictionary) -> void:
	var step := 0
	for leg: Dictionary in shape.legs:
		var rect: Rect2 = leg.rect
		var long := maxf(rect.size.x, rect.size.y)
		var bays := maxi(1, roundi((long - 0.4) / bay_step()))
		var bay := (long - 0.4) / bays
		for k in range(0, bays, 2):
			var t := (0.2 + (k + 0.5) * bay) / long
			var spot := rect.position + rect.size * Vector2(t if rect.size.x >= rect.size.y else 0.5, 0.5 if rect.size.x >= rect.size.y else t)
			var aside := (float(shape.width) * 0.5 - 1.0) * (1.0 if step % 2 == 0 else -1.0)
			if rect.size.x >= rect.size.y:
				spot.y += aside
			else:
				spot.x += aside
			drop(str(leg.name), spot.x, spot.y, step % 4)
			step += 1
	var k := 0
	for beside: Dictionary in shape.beside:
		if k % 2 == 1:
			var spot := beside_drop(beside)
			drop(str(beside.name), spot.x, spot.y, k % 4)
		k += 1

## Where the way in from above of a room beside the corridor is: in its middle, between
## its lamps and between the benches of a laboratory.
func beside_drop(beside: Dictionary) -> Vector2:
	return (beside.rect as Rect2).get_center()

# ---------------------------------------------------------------- helpers

func _leg_named(name: String) -> Dictionary:
	for leg: Dictionary in piece.shape.legs:
		if str(leg.name) == name:
			return leg
	return {}

func _centre(leg: Dictionary) -> Vector3:
	var middle: Vector2 = (leg.rect as Rect2).get_center()
	return Vector3(middle.x, float(leg.y) - o.y, middle.y)

## Where along the wall between two legs in a line their doorway lies: the middle of the
## corridor across.
func _middle_across(leg: Dictionary) -> float:
	var middle: Vector2 = (leg.rect as Rect2).get_center()
	return middle.x if int(leg.side) in [NORTH, SOUTH] else middle.y

## A spot two and a half metres into a leg from its first (or last) end.
func _inside(leg: Dictionary, first: bool) -> Vector3:
	var rect: Rect2 = leg.rect
	var dir: Vector2 = HiveCore.OUT[int(leg.side)]
	var middle := rect.get_center()
	var half := (rect.size.x if int(leg.side) in [EAST, WEST] else rect.size.y) * 0.5
	var spot := middle + dir * (-(half - 2.5) if first else (half - 2.5))
	return Vector3(spot.x, float(leg.y) - o.y, spot.y)
