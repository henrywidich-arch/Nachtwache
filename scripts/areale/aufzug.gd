extends AreaKit
## The twin of a freight lift of the old map (HiveLayout.LIFTS) at the head or the end of a
## chain of areas: the same cabin (HiveAreale.lift_cabin), its door on the same side and
## with the same lettering. Whoever rides the real lift steps out of this one, and the
## other way round (HiveAreaRun). Which lift it is the twin of is the piece's "lift".

func info() -> Dictionary:
	var half := HiveLayout.CABIN * 0.5
	return {
		"id": "aufzug", "kind": "lift", "label": "LASTENAUFZUG", "name": "Lastenaufzug (Zwilling)", "class": "klein",
		"size": Vector2(HiveLayout.CABIN, HiveLayout.CABIN), "levels": [0.0], "mood": "cold",
		"ports": [
			{"side": NORTH, "at": half, "y": 0.0, "room": "kabine", "role": "both"},
			{"side": EAST, "at": half, "y": 0.0, "room": "kabine", "role": "both"},
			{"side": SOUTH, "at": half, "y": 0.0, "room": "kabine", "role": "both"},
			{"side": WEST, "at": half, "y": 0.0, "room": "kabine", "role": "both"}
		],
		"views": [["kabine", Vector3(half, 1.62, half), Vector3(half, 1.4, 0.0)]]
	}

func lay() -> void:
	var port: Dictionary = piece.get("out", {}) if not (piece.get("out", {}) as Dictionary).is_empty() else piece.get("in", {})
	var lift := str(piece.get("lift", ""))
	var title := str(HiveLayout.LIFTS[lift].title) if HiveLayout.LIFTS.has(lift) else "LASTENAUFZUG"
	HiveAreale.lift_cabin(m, n("kabine"), r(0, 0, HiveLayout.CABIN, HiveLayout.CABIN), int(port.get("side", NORTH)), lv(0.0), title)
	var half := HiveLayout.CABIN * 0.5
	point("mid", Vector3(half, 0, half))
	point("in", Vector3(half, 0, half))
