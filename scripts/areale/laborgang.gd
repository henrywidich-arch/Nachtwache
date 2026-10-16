extends "res://scripts/areale/gang.gd"
## Transition: a corridor of the research wing with laboratories at its sides, seen
## through glass, some with a door (a cache may stand in one of them).

func info() -> Dictionary:
	return {
		"id": "laborgang", "kind": "transition", "label": "LABORGANG", "name": "Laborgang", "mood": "sick",
		"width": 6.0, "height": 4.2, "lengths": [14.0, 30.0], "bends": true, "beside": 8.0, "beside_long": 9.0
	}

func dress_beside(beside: Dictionary) -> void:
	var rect: Rect2 = beside.rect
	var middle := rect.get_center()
	var long_x := rect.size.x >= rect.size.y
	m._chunk("Kit", false)
	# Two benches along the room, and lockers at its far wall.
	for k in [-1.0, 1.0]:
		var at := Vector3(middle.x + (0.0 if long_x else k * rect.size.x * 0.22), o.y, middle.y + (k * rect.size.y * 0.22 if long_x else 0.0))
		m._lab_bench(at, minf(4.0, maxf(rect.size.x, rect.size.y) - 3.0), 0.0 if long_x else PI / 2, m.random.randi_range(0, 4))
