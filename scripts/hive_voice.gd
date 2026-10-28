class_name HiveVoice
extends RefCounted
## What is said in the random part of the second mission while the squad goes through it:
## the arrival, the crash, every area and its objective, the freight lifts and the lock at
## the end. The director calls it in three places (entered, watch, reset); it only queues
## cues into the director's own queue of speech (line / talk / shout) and reads the state of
## HiveAreaRun. A cue that is not written (Radio.LINES / Radio.BARKS) is left out, so the
## hooks are harmless while takes are missing.

## Radio cues (Radio.LINES) said from here, and the calls / talks of the squad (Radio.BARKS).
## (The cues of an area are named after its definition: AREA_LINES, AREA_BARKS.)
const LINE_CUES: Array[String] = [
	"m2_sector", "m2_n_sector", "m2_derail", "m2_n_lift", "m2_n_decon", "m2_lock_done",
	"obj_collect_start", "obj_collect_1", "obj_collect_2", "obj_collect_3", "obj_collect_done",
	"obj_hack_start", "obj_hack_half", "obj_hack_done", "m2_n_obj_hack",
	"obj_restore_start", "obj_restore_switch", "obj_restore_rising", "obj_restore_done", "m2_n_obj_restore",
	"obj_hold_start", "obj_hold_half", "obj_hold_done", "m2_n_obj_hold",
	"obj_lock_done", "obj_clear_start", "obj_clear_few", "obj_clear_done",
]
const BARK_CUES: Array[String] = [
	"m2_sector_c", "m2_crash", "m2_crash_after", "m2_lift_in", "m2_lift_out", "m2_decon",
	"obj_found", "obj_hack", "obj_switch", "obj_done",
]
## The areas of the random part (HiveLayout.POOL); each has m2_area_<def> as a radio line and
## as a talk of the squad, and m2_n_area_<def> as a line of Nadja.
const AREAS: Array[String] = ["haifischlabor", "gartenlabor", "reaktorschacht", "kryoarchiv", "isolationstrakt", "lagerhalle", "sezierlabor"]
## What the companions say of their own actions (Teammate, Game.buy_item): barks of the six.
const MATE_CUES: Array[String] = ["frag", "molotov", "heal", "mate_rescue", "arms_up", "gear_up"]
## The line that ends an objective, by its kind.
const DONE_LINES := {"collect": "obj_collect_done", "hack": "obj_hack_done", "restore": "obj_restore_done", "hold": "obj_hold_done", "lockdown": "obj_lock_done", "clear": "obj_clear_done"}
## The queue holds this many entries or more: optional words are left out / all words are.
const OPTIONAL_LIMIT := 3
const QUEUE_LIMIT := 7

## For the checks: 0..1 makes every dice roll pass (p > roll) or fail; below 0 it is random.
static var roll := -1.0
## What was seen the last time: the stage, the objective of it, and how far it has come.
static var _stage := ""
static var _key := ""
static var _state := ""
static var _taken := 0
static var _done_places := 0
static var _guards := -1
static var _half := false
static var _ride := ""
static var _lock := 0.0

## Who has a take of the calls and talks of the squad, and of the companions' own actions.
const SQUAD: Array[String] = ["viper", "scorpion", "raven"]
const MATES: Array[String] = ["viper", "scorpion", "raven", "phantom", "havoc", "ghost"]

## Everything the hooks name that has to be written: [kind ("line" or "bark"), cue, speakers].
## (For the checks: whether it is there, and stand-ins while it is not.)
static func needs() -> Array:
	var out: Array = []
	for cue in LINE_CUES:
		out.append(["line", cue, ["nadja" if cue.begins_with("m2_n_") else "coleman"]])
	for cue in BARK_CUES:
		out.append(["bark", cue, SQUAD])
	for def in AREAS:
		out.append(["line", "m2_area_" + def, ["coleman"]])
		out.append(["line", "m2_n_area_" + def, ["nadja"]])
		out.append(["bark", "m2_area_" + def, SQUAD])
	for cue in MATE_CUES:
		out.append(["bark", cue, MATES])
	return out

## The cues the hooks name (everything above): for the checks.
static func all_cues() -> Array:
	var out: Array = []
	for cue in LINE_CUES:
		out.append(cue)
	for cue in BARK_CUES:
		out.append(cue)
	for def in AREAS:
		out.append_array(["m2_area_" + def, "m2_n_area_" + def])
	return out

static func reset() -> void:
	_stage = ""
	_forget()
	_ride = ""
	_lock = 0.0

static func _forget() -> void:
	_key = ""
	_state = ""
	_taken = 0
	_done_places = 0
	_guards = -1
	_half = false

static func _chance(p: float) -> bool:
	return randf() < p if roll < 0.0 else roll < p

## How much waits in the director's queue, a talk of several voices counting once.
static func _pending(d: HiveDirector) -> int:
	var count := 0
	var before := ""
	for entry: Dictionary in d.lines:
		# (The companions' small talk gives way: it does not count.)
		if bool(entry.get("banter", false)):
			continue
		var tag := "%s:%s" % [entry.get("kind", ""), entry.get("cue", entry.get("id", ""))]
		if tag != before:
			count += 1
		before = tag
	return count

## Queues a radio line if it is written and the queue is not full; `first`: it is the next
## thing said.
static func _line(d: HiveDirector, cue: String, first: bool = false, optional: bool = false) -> void:
	if Radio.LINES.has(cue) and _pending(d) < (OPTIONAL_LIMIT if optional else QUEUE_LIMIT):
		d.line(cue, first)

static func _talk(d: HiveDirector, cue: String, optional: bool = false) -> void:
	if Radio.BARKS.has(cue) and _pending(d) < (OPTIONAL_LIMIT if optional else QUEUE_LIMIT):
		d.talk(cue)

static func _shout(d: HiveDirector, cue: String) -> void:
	if Radio.BARKS.has(cue) and _pending(d) < OPTIONAL_LIMIT:
		d.shout(cue)

# ---------------------------------------------------------------- a stage begins

## Called at the end of HiveDirector._enter.
static func entered(d: HiveDirector, id: String) -> void:
	if d.run == null or not d.run.on:
		_stage = id
		return
	var from := _stage
	_stage = id
	_forget()
	# (A lift that has brought the squad here: its word comes before the area's.)
	_lift_end(d)
	var piece: Dictionary = d.run.piece_of.get(id, {})
	if id == "g_arrive":
		_line(d, "m2_sector")
		_talk(d, "m2_sector_c")
		_line(d, "m2_n_sector", false, true)
	elif id == "g_crash":
		_crash(d)
	elif id == "labs" and from == "g_lock":
		_line(d, "m2_lock_done", true)
	elif id.ends_with("_out") and not piece.is_empty():
		_ended(d, piece)
	elif not piece.is_empty() and str(piece.get("kind", "")) == "area":
		_area(d, str(piece.def))

## The train has derailed: the shouts of the squad, Coleman, and what comes after - before
## the words about the arrival that HiveAreaRun.enter has queued already.
static func _crash(d: HiveDirector) -> void:
	var saved: Array = d.lines
	d.lines = []
	_talk(d, "m2_crash")
	_line(d, "m2_derail")
	_talk(d, "m2_crash_after")
	var mine: Array = d.lines
	d.lines = saved
	var at := d.lines.size()
	for index in range(d.lines.size()):
		if str(d.lines[index].get("cue", "")) in ["m2_arrived", "m2_terminal"]:
			at = index
			break
	for entry: Dictionary in mine:
		d.lines.insert(at, entry)
		at += 1

## An area: Coleman says where they are, then Nadja or the squad has a word (not both).
static func _area(d: HiveDirector, def: String) -> void:
	_line(d, "m2_area_" + def)
	if _pending(d) >= OPTIONAL_LIMIT:
		return
	# (v0.86) Often nobody has a word of his own for the area: the squad talked too much.
	var roll_area := randf() if roll < 0.0 else roll
	if roll_area < 0.45:
		_line(d, "m2_n_area_" + def, false, true)
	elif roll_area >= 0.7:
		_talk(d, "m2_area_" + def, true)

## The objective of an area is done (its stage is "<stage>_out" now).
static func _ended(d: HiveDirector, piece: Dictionary) -> void:
	var kind := str((piece.get("event", {}) as Dictionary).get("kind", "hold"))
	if not DONE_LINES.has(kind):
		return
	_line(d, str(DONE_LINES[kind]), true)
	if _chance(0.6) and not d.lines.any(func(entry: Dictionary) -> bool: return str(entry.kind) == "call"):
		_shout(d, "obj_done")

# ---------------------------------------------------------------- every frame

## Called after HiveDirector._update: what has changed in the objective, the lifts, the lock.
static func watch(d: HiveDirector, _delta: float) -> void:
	if d.run == null or not d.run.on:
		return
	_watch_task(d)
	_watch_ride(d)
	_watch_lock(d)

static func _watch_task(d: HiveDirector) -> void:
	var task: Dictionary = d.run.task
	if task.is_empty():
		if _key != "":
			_forget()
		return
	if _key != d.stage:
		_forget()
		_key = d.stage
		_guards = d._guards_left()
	var state := str(task.state)
	var began := state != _state
	_state = state
	match str(task.kind):
		"collect":
			if began and state == "work":
				_line(d, "obj_collect_start")
			var taken := (task.get("items", []) as Array).filter(func(item: Dictionary) -> bool: return bool(item.taken)).size()
			if taken > _taken:
				var left := (task.items as Array).size() - taken
				if left >= 1 and left <= 3:
					_line(d, "obj_collect_%d" % left, false, true)
					if _chance(0.5):
						_shout(d, "obj_found")
			_taken = taken
		"hack":
			if began and state == "hacking":
				_line(d, "obj_hack_start")
				_shout(d, "obj_hack")
				if _chance(0.4):
					_line(d, "m2_n_obj_hack", false, true)
			if state == "hacking" and not _half and d.progress > 0.5:
				_half = true
				_line(d, "obj_hack_half", false, true)
		"restore":
			if began and state == "work":
				_line(d, "obj_restore_start")
				if _chance(0.4):
					_line(d, "m2_n_obj_restore", false, true)
			var thrown := (task.get("places", []) as Array).filter(func(place: Dictionary) -> bool: return bool(place.done)).size()
			if thrown > _done_places:
				if thrown < (task.places as Array).size():
					_line(d, "obj_restore_switch", false, true)
					if _chance(0.5):
						_shout(d, "obj_switch")
			_done_places = thrown
			if began and state == "rising":
				_line(d, "obj_restore_rising")
		"hold":
			if began and state == "holding":
				_line(d, "obj_hold_start")
				if _chance(0.4):
					_line(d, "m2_n_obj_hold", false, true)
			if state == "holding" and not _half and d.progress > 0.5:
				_half = true
				_line(d, "obj_hold_half", false, true)
		"clear":
			if began and state == "work":
				_line(d, "obj_clear_start")
			var guards: int = d._guards_left()
			if state == "work" and _guards > OPTIONAL_LIMIT and guards <= OPTIONAL_LIMIT and guards > 0:
				_line(d, "obj_clear_few", false, true)
			_guards = guards

static func _watch_ride(d: HiveDirector) -> void:
	var phase := str(d.run.ride.get("phase", ""))
	if phase == "ride":
		if _ride != "ride":
			_ride = "ride"
			_talk(d, "m2_lift_in")
			if _chance(0.4):
				_line(d, "m2_n_lift", false, true)
	else:
		_lift_end(d)

## The ride of a freight lift is over (after it the ride dictionary is empty again).
static func _lift_end(d: HiveDirector) -> void:
	if _ride == "ride" and str(d.run.ride.get("phase", "")) != "ride":
		_ride = ""
		_talk(d, "m2_lift_out")

static func _watch_lock(d: HiveDirector) -> void:
	if d.stage != "g_lock":
		_lock = 0.0
		return
	var left: float = d.run.lock_left
	if _lock < 0.0 and left > 0.0:
		_line(d, "m2_n_decon", false, true)
		_talk(d, "m2_decon")
	_lock = left
