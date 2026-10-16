extends "res://scripts/areale/gang.gd"
## Transition: a lock - a short corridor, a chamber between two doors that slide open for
## whoever comes, with the nozzles and the violet light of the facility's decontamination,
## and a short corridor again. It does not bend.

func info() -> Dictionary:
	return {
		"id": "schleuse", "kind": "transition", "label": "SCHLEUSE", "name": "Schleuse", "mood": "cold",
		"width": 6.0, "height": 4.2, "lengths": [20.0, 30.0], "bends": false, "chamber": 9.0
	}

func dress_leg(leg: Dictionary) -> void:
	m._chunk("Kit", false)
	if str(leg.name) != "kammer":
		m._passage(n(str(leg.name)), {"step": 5.0, "light": Color("d6e8ff"), "energy": 2.2, "reach": 9.0, "lines": [[0.0, Color("c9a227"), 0.14]], "tray": -1})
		return
	var lock: Dictionary = m.room_of[n("kammer")]
	var rect: Rect2 = leg.rect
	var long_x := rect.size.x >= rect.size.y
	var sides := [NORTH, SOUTH] if long_x else [WEST, EAST]
	var a := rect.position.x if long_x else rect.position.y
	var b := rect.end.x if long_x else rect.end.y
	for side in sides:
		for high in [0.5, 2.2]:
			m._face_glow(lock, side, a + 0.6, b - 0.6, high, high + 0.04, -0.06, -0.047, Color("b08cff"), 3.0)
		m._stencil(n("kammer"), side, (a + b) * 0.5, 3.25, "SCHLEUSE", 70, Color(0.2, 0.42, 0.44))
	var middle := rect.get_center()
	for k in range(3):
		var t := (k + 0.5) / 3.0
		for across in [-1.0, 1.0]:
			var at := Vector3(lerpf(rect.position.x, rect.end.x, t), o.y + 2.4, middle.y + across * (rect.size.y * 0.5 - 0.6)) if long_x else Vector3(middle.x + across * (rect.size.x * 0.5 - 0.6), o.y + 2.4, lerpf(rect.position.y, rect.end.y, t))
			m._part("steel", at, Vector3(0.2, 0.2, 0.2), Color("7d8284"))
			m._pipe(at, at + Vector3(0, 1.2, 0), 0.04, Color("7d8284"), 6, "steel")
	m._part("tread", Vector3(middle.x, o.y + 0.006, middle.y), Vector3(rect.size.x - 1.0, 0.012, rect.size.y - 1.0), Color(0.3, 0.32, 0.34))
	m._light(Vector3(middle.x, o.y + 3.4, middle.y), Color("bfe8ff"), 2.4, 9.0, false, 0.0, 0.3, HiveCore.LAMP_FADE)
	m._haze(Vector3(middle.x, o.y + 1.4, middle.y), Vector3(rect.size.x - 0.6, 2.8, rect.size.y - 0.6), 0.04, Color(0.8, 0.82, 1.0))

func leg_options(leg: Dictionary) -> Dictionary:
	return {"lamps": "none"} if str(leg.name) != "kammer" else {"look": {"light": Color("bfe8ff"), "strip_color": Color("7fe0ff")}}

func join_options(_before: Dictionary, _leg: Dictionary) -> Dictionary:
	return {"kind": "slide", "leaf": "double", "height": 3.0}

func ways(shape: Dictionary) -> void:
	for leg: Dictionary in shape.legs:
		if str(leg.name) == "kammer":
			continue
		var middle: Vector2 = (leg.rect as Rect2).get_center()
		drop(str(leg.name), middle.x + (2.0 if (leg.rect as Rect2).size.y > (leg.rect as Rect2).size.x else 0.0), middle.y + (2.0 if (leg.rect as Rect2).size.x >= (leg.rect as Rect2).size.y else 0.0), 1)
