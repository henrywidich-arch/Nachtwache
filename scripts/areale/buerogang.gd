extends "res://scripts/areale/gang.gd"
## Transition: a corridor of the administration with offices at its sides, behind
## windows that stop bodies but not shots, some with a door.

func info() -> Dictionary:
	return {
		"id": "buerogang", "kind": "transition", "label": "BÜROGANG", "name": "Bürogang", "mood": "cold",
		"width": 6.0, "height": 3.6, "lengths": [14.0, 28.0], "bends": true, "beside": 6.5, "beside_long": 7.0
	}

func style() -> String:
	return "office"

func beside_style() -> String:
	return "office"

func lines() -> Array:
	return [[0.0, Color("2f6fb0"), 0.1]]

func join_beside(beside: Dictionary) -> void:
	var leg: Dictionary = _leg_named(str(beside.leg))
	var side := int(beside.side)
	var rect: Rect2 = beside.rect
	var from := rect.position.x if side in [NORTH, SOUTH] else rect.position.y
	var long := rect.size.x if side in [NORTH, SOUTH] else rect.size.y
	door(str(leg.name), str(beside.name), from + long * 0.25, 1.8, {"kind": "slide"})
	pane(str(leg.name), side, from + long * 0.66, minf(3.6, long * 0.42), 1.0, 2.3, "window", str(beside.name))

func bay_step() -> float:
	return 5.0

func dress_leg(leg: Dictionary) -> void:
	m._chunk("Kit", false)
	m._passage(n(str(leg.name)), {"step": 5.0, "light": Color("e6ecf2"), "energy": 2.1, "reach": 9.5, "lines": lines(), "tray": -1, "ribs": false, "dead": [m.random.randi_range(0, 3)]})

## The desks stand towards the office's outer wall; the way in from above is on the
## corridor's side of it, clear of its lamp in the middle.
func _across(beside: Dictionary) -> Array:
	var rect: Rect2 = beside.rect
	var out: Vector2 = HiveCore.OUT[int(beside.side)]
	var along := Vector2(absf(out.y), absf(out.x))
	return [rect.get_center(), out, along]

func beside_drop(beside: Dictionary) -> Vector2:
	var frame := _across(beside)
	return (frame[0] as Vector2) - (frame[1] as Vector2) * 1.2 + (frame[2] as Vector2) * 2.2

func dress_beside(beside: Dictionary) -> void:
	var frame := _across(beside)
	var middle: Vector2 = frame[0]
	var out: Vector2 = frame[1]
	var along: Vector2 = frame[2]
	m._chunk("Kit", false)
	for k in [-1.0, 1.0]:
		var at: Vector2 = middle + out * 1.4 + along * (1.6 * k)
		m._desk(Vector3(at.x, o.y, at.y), atan2(out.x, out.y) + m.random.randf_range(-0.3, 0.3), m.random.randi_range(1, 5))
	var seat: Vector2 = middle + out * 0.2 - along * 0.8
	m._office_chair(Vector3(seat.x, o.y, seat.y), m.random.randf() * TAU, m.random.randf() < 0.4)
