extends "res://scripts/areale/gang.gd"
## Transition: a corridor of the administration with offices at its sides, behind
## windows that stop bodies but not shots, some with a door.

func info() -> Dictionary:
	return {
		"id": "buerogang", "kind": "transition", "label": "BÜROGANG", "name": "Bürogang", "mood": "cold",
		"width": 5.0, "height": 3.6, "lengths": [14.0, 28.0], "bends": true, "beside": 6.5, "beside_long": 7.0
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

func dress_leg(leg: Dictionary) -> void:
	m._chunk("Kit", false)
	m._passage(n(str(leg.name)), {"step": 5.0, "light": Color("e6ecf2"), "energy": 2.1, "reach": 9.5, "lines": lines(), "tray": -1, "ribs": false, "dead": [m.random.randi_range(0, 3)]})

func dress_beside(beside: Dictionary) -> void:
	var rect: Rect2 = beside.rect
	var middle := rect.get_center()
	m._chunk("Kit", false)
	m._desk(Vector3(middle.x - 1.0, o.y, middle.y - 0.8), m.random.randf() * TAU, m.random.randi_range(1, 5))
	m._desk(Vector3(middle.x + 1.2, o.y, middle.y + 1.0), m.random.randf() * TAU, m.random.randi_range(1, 5))
	m._office_chair(Vector3(middle.x + 0.2, o.y, middle.y - 1.6), m.random.randf() * TAU, m.random.randf() < 0.4)
