class_name Profile
extends RefCounted
## What survives between sessions: the chosen difficulty, the best runs on each
## difficulty and the career totals. Stored as JSON in user://nachtwache_profile.json.

const PATH := "user://nachtwache_profile.json"
## Runs kept per difficulty.
const KEEP := 10
const ORDER := ["easy", "normal", "hard", "nightmare"]
## A harder night is not simply tougher skin. horde: how many come. specials: how many of
## them are special infected. pace: how fast they move and strike. harm: what a hit does
## to a survivor. drops: how often the dead leave supplies. prices: cost of stations and
## weapons. healing: what medicine restores. gas: how quickly and badly the gas hurts.
## hack: how long devices take. events: how often something unplanned happens.
## tactics: how sharp the C.R.U. is - how fast it reacts, how well it aims, how often it
## dodges, flanks and throws grenades. score: multiplier on everything earned.
const DIFFICULTIES := {
	"easy": {"label": "LEICHT", "horde": 0.8, "specials": 0.75, "pace": 0.95, "harm": 0.7, "drops": 1.5, "prices": 0.85, "healing": 1.25, "gas": 0.6, "hack": 0.85, "events": 0.7, "tactics": 0.75, "score": 0.7},
	"normal": {"label": "NORMAL", "horde": 1.0, "specials": 1.0, "pace": 1.0, "harm": 1.0, "drops": 1.0, "prices": 1.0, "healing": 1.0, "gas": 1.0, "hack": 1.0, "events": 1.0, "tactics": 1.0, "score": 1.0},
	"hard": {"label": "SCHWER", "horde": 1.25, "specials": 1.4, "pace": 1.07, "harm": 1.25, "drops": 0.7, "prices": 1.2, "healing": 0.8, "gas": 1.6, "hack": 1.25, "events": 1.3, "tactics": 1.2, "score": 1.5},
	"nightmare": {"label": "ALBTRAUM", "horde": 1.5, "specials": 1.8, "pace": 1.14, "harm": 1.5, "drops": 0.5, "prices": 1.4, "healing": 0.65, "gas": 2.4, "hack": 1.5, "events": 1.6, "tactics": 1.4, "score": 2.2}
}

## Looks for the player and for the squad. need/count: the career total that unlocks it
## ("" = from the start). bot: it can also be sent into the field as a squad member. A
## skin the player wears stays available for the squad.
const SKINS := {
	"main": {"label": "FIRETEAM", "need": "", "count": 0, "note": "von Anfang an", "bot": false},
	"viper": {"label": "VIPER", "need": "", "count": 0, "note": "von Anfang an", "bot": true},
	"scorpion": {"label": "SCORPION", "need": "", "count": 0, "note": "von Anfang an", "bot": true},
	"raven": {"label": "RAVEN", "need": "victories", "count": 1, "note": "Einsatz einmal abschließen", "bot": true},
	"cru": {"label": "C.R.U.-RÜSTUNG", "need": "cru_kills", "count": 40, "note": "C.R.U.-Soldaten ausschalten", "bot": false},
	"cru2": {"label": "BREACHER-RÜSTUNG", "need": "kills", "count": 500, "note": "Gegner ausschalten", "bot": false},
	# The operators: whoever has driven one of them off may wear his kit.
	"phantom": {"label": "PHANTOM", "need": "phantom", "count": 1, "note": "Phantom in die Flucht schlagen", "bot": false},
	"havoc": {"label": "HAVOC", "need": "havoc", "count": 1, "note": "Havoc in die Flucht schlagen", "bot": false},
	"ghost": {"label": "GHOST", "need": "ghost", "count": 1, "note": "Ghost in die Flucht schlagen", "bot": false}
}

## Off during automatic checks: nothing is read from or written to the player's file.
var stored := true
var difficulty := "normal"
## Which mission the next night is: 1 the farm, 2 the villa and what lies under it.
var mission := 1
## What a night on the farm is: "story" or "endless", and whether its rounds bring
## modifiers (see Game.MODIFIERS). The second mission has neither.
var mode := "story"
var modifiers := false
## Difficulty -> finished runs, best first.
var runs: Dictionary = {}
var totals := {"missions": 0, "victories": 0, "kills": 0, "special_kills": 0, "cru_kills": 0, "revives": 0, "objectives": 0, "seconds": 0, "phantom": 0, "havoc": 0, "ghost": 0}
## What the player wears (seen by a co-op partner and in the arrival), and the two who
## come along.
var skin := "main"
var squad: Array = ["viper", "scorpion"]
## Ranks bought in the trees of abilities (see Skills); empty while those are out of
## service, and then it is not written to the file at all.
var skills: Dictionary = {}
## The tree of abilities the player has specialised in ("" for none).
var skill_tree := ""

func open() -> void:
	if not stored or not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		return
	if str(parsed.get("difficulty", "")) in ORDER:
		difficulty = str(parsed.difficulty)
	if str(parsed.get("mode", "")) in ["story", "endless"]:
		mode = str(parsed.mode)
	if int(parsed.get("mission", 1)) in [1, 2]:
		mission = int(parsed.mission)
	modifiers = bool(parsed.get("modifiers", false))
	if parsed.get("runs") is Dictionary:
		for level in ORDER:
			for list in [level, board(level, "endless"), board(level, "villa")]:
				if parsed.runs.get(list) is Array:
					runs[list] = parsed.runs[list]
	if parsed.get("totals") is Dictionary:
		for key in totals:
			totals[key] = int(parsed.totals.get(key, 0))
	if SKINS.has(str(parsed.get("skin", ""))) and unlocked(str(parsed.skin)):
		skin = str(parsed.skin)
	if parsed.get("squad") is Array and (parsed.squad as Array).size() == 2:
		var both := true
		for id in parsed.squad:
			both = both and SKINS.has(str(id)) and bool(SKINS[str(id)].bot) and unlocked(str(id))
		if both and str(parsed.squad[0]) != str(parsed.squad[1]):
			squad = [str(parsed.squad[0]), str(parsed.squad[1])]
	if parsed.get("skills") is Dictionary:
		skills = parsed.skills
	skill_tree = str(parsed.get("skill_tree", ""))

func save() -> void:
	if not stored:
		return
	var kept := {"difficulty": difficulty, "mission": mission, "mode": mode, "modifiers": modifiers, "runs": runs, "totals": totals, "skin": skin, "squad": squad}
	if not skills.is_empty():
		kept["skills"] = skills
	if skill_tree != "":
		kept["skill_tree"] = skill_tree
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(kept, "\t"))

func unlocked(id: String) -> bool:
	var data: Dictionary = SKINS[id]
	return str(data.need) == "" or int(totals.get(data.need, 0)) >= int(data.count)

## What it takes, and how far along the player is.
func progress(id: String) -> String:
	var data: Dictionary = SKINS[id]
	if str(data.need) == "":
		return str(data.note)
	return "%s  ·  %d / %d" % [data.note, mini(int(totals.get(data.need, 0)), int(data.count)), int(data.count)]

func wear(id: String) -> void:
	if SKINS.has(id) and unlocked(id):
		skin = id
		save()

## Puts a look into the squad; the one that has been in it longest makes room.
func enlist(id: String) -> void:
	if SKINS.has(id) and bool(SKINS[id].bot) and unlocked(id) and not squad.has(id):
		squad = [squad[1], id]
		save()

func rules() -> Dictionary:
	return DIFFICULTIES[difficulty]

func next_difficulty() -> void:
	difficulty = ORDER[(ORDER.find(difficulty) + 1) % ORDER.size()]
	save()

func next_mode() -> void:
	mode = "endless" if mode == "story" else "story"
	save()

func choose_mission(number: int) -> void:
	if number in [1, 2]:
		mission = number
		save()

## What a night is filed under and called for the list of the best: "story" or "endless"
## on the farm, "villa" for the second mission.
func play() -> String:
	return "villa" if mission == 2 else mode

func toggle_modifiers() -> void:
	modifiers = not modifiers
	save()

## The list a night is filed under: one per difficulty for the story, one more per
## difficulty for the endless mode, and one for the second mission.
static func board(level: String, play: String) -> String:
	if play == "villa":
		return "villa_" + level
	return "endless_" + level if play == "endless" else level

## The best nights of a list (see board).
func best(level: String) -> Array:
	return runs.get(level, [])

static func _better(a: Dictionary, b: Dictionary) -> bool:
	if float(a.score) != float(b.score):
		return float(a.score) > float(b.score)
	return float(a.seconds) < float(b.seconds)

## Files a finished run under its difficulty and adds it to the career totals. Returns
## its place on the list (1 is the best) or 0 if it did not make the list.
func record(level: String, run: Dictionary) -> int:
	totals.missions += 1
	if run.victory:
		totals.victories += 1
	for key in ["kills", "special_kills", "cru_kills", "revives", "objectives", "seconds", "phantom", "havoc", "ghost"]:
		totals[key] += int(run.get(key, 0))
	var list: Array = runs.get(level, [])
	list.append(run)
	list.sort_custom(_better)
	if list.size() > KEEP:
		list.resize(KEEP)
	runs[level] = list
	save()
	return list.find(run) + 1
