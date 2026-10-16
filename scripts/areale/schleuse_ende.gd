extends AreaKit
## The end of the random part: a lock that is the twin of the facility's decontamination
## lock (HiveMap._lay_research, "decon") - the same room, the same light, the same
## nozzles, gates and hole in its ceiling. Once the squad is in it and its gate is shut,
## the director moves everybody into the real lock (HiveDirector, stage "g_lock"): nobody
## sees a difference, and the gate ahead opens on the laboratory corridor.

## The north-west corner of the real lock on its floor: where this one's corner is moved to.
const REAL := Vector3(-4.0, -9.6, -501.0)

func info() -> Dictionary:
	return {
		"id": "schleuse_ende", "kind": "end", "label": "DIE SCHLEUSE", "name": "Ende · Schleuse zum Forschungstrakt", "class": "klein",
		"size": Vector2(8.0, 12.0), "levels": [0.0], "mood": "sick",
		"ports": [{"side": SOUTH, "at": 4.0, "y": 0.0, "room": "kammer", "role": "in"}],
		"goal": "Durch die Dekontamination in den Forschungstrakt"
	}

func lay() -> void:
	room("kammer", 0.0, 0, 0, 8, 12, 4.2, "lab", {"look": {"light": Color("bfe8ff"), "strip_color": Color("7fe0ff")}})
	# Its gate to the north never opens: the real one does.
	opening("kammer", NORTH, 4.0, 3.0, {"kind": "script", "name": "%s_nord" % str(piece.id)})
	m._chunk("Kit", false)
	for z in [9.0, 6.0, 3.0]:
		for x in [0.7, 7.3]:
			m._part("steel", p(x, 2.4, z), Vector3(0.2, 0.2, 0.2), Color("7d8284"))
			m._pipe(p(x, 2.4, z), p(x, 3.6, z), 0.04, Color("7d8284"), 6, "steel")
	m._part("tread", p(4.0, 0.006, 6.0), Vector3(5.0, 0.012, 9.0), Color(0.3, 0.32, 0.34))
	var lock: Dictionary = m.room_of[n("kammer")]
	for side in [WEST, EAST]:
		for high in [0.5, 2.2]:
			m._face_glow(lock, side, along(side, 0.6), along(side, 11.4), high, high + 0.04, -0.06, -0.047, Color("b08cff"), 3.0)
	stencil("kammer", WEST, 6.0, 3.25, "DEKONTAMINATION", 76, Color(0.2, 0.42, 0.44))
	stencil("kammer", EAST, 6.0, 3.25, "SCHLEUSE  B2 · 06", 76, Color(0.2, 0.42, 0.44))
	m._haze(p(4.0, 1.4, 6.0), Vector3(7.4, 2.8, 11.4), 0.04, Color(0.8, 0.82, 1.0))
	drop("kammer", 1.5, 1.5, 0)
	point("mid", Vector3(4.0, 0, 6.0))
	point("in", Vector3(4.0, 0, 10.0))

## How far everybody in this lock is moved to stand in the real one.
func shift() -> Vector3:
	return REAL - o
