extends "res://scripts/areale/gang.gd"
## Transition: a stairwell that changes the level by two storeys (HiveLayout.LIFT): a
## short corridor, two flights of concrete stairs in a line with a landing between them
## (HiveAreale.stair_shaft), a short corridor again. The infected follow up and down.

func info() -> Dictionary:
	return {
		"id": "treppenhaus", "kind": "transition", "label": "TREPPENHAUS", "name": "Treppenhaus", "mood": "plant",
		"width": 4.6, "height": 3.6, "lengths": [12.0, 22.0], "bends": false, "rise": HiveLayout.LIFT, "shaft": HiveAreale.RUN, "shaft_wide": 4.6
	}

func style() -> String:
	return "concrete"

func lay() -> void:
	var shape: Dictionary = piece.shape
	var legs: Array = shape.legs
	var shaft: Dictionary = shape.shaft
	var s1 := int(shaft.side)
	for leg: Dictionary in legs:
		var rect: Rect2 = leg.rect
		room(str(leg.name), float(leg.y) - o.y, rect.position.x, rect.position.y, rect.size.x, rect.size.y, 3.6, "concrete", {"look": {"stripe": Color("b8961e")}})
	var first: Dictionary = legs[0]
	var second: Dictionary = legs[1]
	opening(str(first.name), s1, _middle_across(first), HiveAreale.FLIGHT, {"kind": "join", "height": 3.0, "nav": false})
	opening(str(second.name), HiveLayout.opposite(s1), _middle_across(second), HiveAreale.FLIGHT, {"kind": "join", "height": 3.0, "nav": false})
	HiveAreale.stair_shaft(m, shaft.from, s1, float(HiveLayout.info("treppenhaus").shaft_wide), float(first.y), float(second.y), 3.6, lv(float(first.y) - o.y), lv(float(second.y) - o.y))
	m._chunk("Kit", false)
	var from: Vector2 = shaft.from
	var dir: Vector2 = HiveCore.OUT[s1]
	var mid := (float(first.y) + float(second.y)) * 0.5
	var land := Vector3(from.x + dir.x * 9.0, mid - o.y, from.y + dir.y * 9.0)
	hang(land + Vector3(0, maxf(float(first.y), float(second.y)) - mid + 3.6, 0), land, 0)
	var across := Vector2(absf(dir.y), absf(dir.x))
	for leg: Dictionary in legs:
		var c: Vector2 = (leg.rect as Rect2).get_center()
		drop(str(leg.name), c.x + across.x * 1.2, c.y + across.y * 1.2, 1)
	point("in", _inside(first, true))
	point("out", _inside(second, false))
	point("middle", land)
