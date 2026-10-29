class_name Profile
extends RefCounted
## What survives between sessions: the chosen difficulty, the best runs on each
## difficulty and the career totals. Stored as JSON in user://nachtwache_profile.json.

const PATH := "user://nachtwache_profile.json"
## Runs kept per difficulty.
const KEEP := 10
const ORDER := ["easy", "normal", "hard", "nightmare"]
## Difficulties that were on the menu once and are gone. "zombie_test" was a night as on
## NORMAL whose infected took more: that toughness is NORMAL's own now (see "brood" below).
## A saved profile that still has one of them selected comes up on NORMAL; the lists of
## their best runs are shown nowhere, but they are read and written back as they are.
const RETIRED := ["zombie_test"]
## A harder night is not simply tougher skin. horde: how many come. specials: how many of
## them are special infected. pace: how fast they move and strike. harm: what a hit does
## to a survivor. drops: how often the dead leave supplies. prices: cost of stations and
## weapons. healing: what medicine restores. gas: how quickly and badly the gas hurts.
## hack: how long devices take. events: how often something unplanned happens.
## tactics: how sharp the C.R.U. is - how fast it reacts, how well it aims, how often it
## dodges, flanks and throws grenades. score: multiplier on everything earned.
## brood: what the infected take, as a factor on the health in Infected.TYPES - a ladder
## over the levels, each clearly tougher than the one before. (Helix's soldiers and
## operators are no infected, and the Crusher, the Stalker and the Prowler are fights of
## their own: those keep their health, see Infected.BROOD_APART.)
const DIFFICULTIES := {
	"easy": {"label": "LEICHT", "horde": 0.8, "specials": 0.75, "pace": 0.95, "harm": 0.7, "drops": 1.5, "prices": 0.85, "healing": 1.25, "gas": 0.6, "hack": 0.85, "events": 0.7, "tactics": 0.75, "score": 0.7, "brood": 1.4},
	"normal": {"label": "NORMAL", "horde": 1.0, "specials": 1.0, "pace": 1.0, "harm": 1.0, "drops": 1.0, "prices": 1.0, "healing": 1.0, "gas": 1.0, "hack": 1.0, "events": 1.0, "tactics": 1.0, "score": 1.0, "brood": 1.8},
	"hard": {"label": "SCHWER", "horde": 1.25, "specials": 1.4, "pace": 1.07, "harm": 1.25, "drops": 0.7, "prices": 1.2, "healing": 0.8, "gas": 1.6, "hack": 1.25, "events": 1.3, "tactics": 1.2, "score": 1.5, "brood": 2.2},
	"nightmare": {"label": "ALBTRAUM", "horde": 1.5, "specials": 1.8, "pace": 1.14, "harm": 1.5, "drops": 0.5, "prices": 1.4, "healing": 0.65, "gas": 2.4, "hack": 1.5, "events": 1.6, "tactics": 1.4, "score": 2.2, "brood": 2.6}
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
	"ghost": {"label": "GHOST", "need": "ghost", "count": 1, "note": "Ghost in die Flucht schlagen", "bot": false},
	# The user's two plain men: open from the start, for the player and for the squad
	# (where they keep quiet: they have no lines of their own).
	"dude_shorts": {"label": "STRANDTYP", "need": "", "count": 0, "note": "von Anfang an  ·  als Begleiter ohne Funksprüche", "bot": true},
	"dude_turtleneck": {"label": "ROLLKRAGEN", "need": "", "count": 0, "note": "von Anfang an  ·  als Begleiter ohne Funksprüche", "bot": true}
}

## Off during automatic checks: nothing is read from or written to the player's file.
var stored := true
var difficulty := "normal"
## Which mission the next night is: 1 the farm, 2 the villa and what lies under it.
var mission := 1
## What a night on the farm is: "story" or "endless", and whether its rounds bring
## modifiers (see Game.MODIFIERS). The second mission has neither.
var mode := "story"
## The room the second mission surely has (HiveLayout.rooms(): "" leaves it to chance,
## "tokio" the simulation hall, else an area of HiveLayout.POOL). Chosen in the play menu.
var room := ""
## (v0.88) How long the second mission's night is (HiveLayout.LENGTHS), chosen in the play menu.
var length := "medium"
## (v0.88) What a night of the second mission is: "mission" or "endless" (HiveDirector.endless).
var hive_mode := "mission"
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
## Tree -> the weapon wished for in it (see Skills.WISHES); checked by Skills.adopt_wishes.
var wishes: Dictionary = {}
## Who goes on with the survivor from the station of the second mission: "fireteam", the
## two who came with him, or two of the three operators, named by their looks - while the
## squad and the third of them stay behind at the station. Since v0.79 also one operator
## alone ("havoc"): he takes the place of the one of the squad who was not picked, and the
## one who was picked goes on beside him.
const COMPANIES := ["fireteam", "phantom_havoc", "phantom_ghost", "havoc_ghost", "phantom", "havoc", "ghost"]
var company := "fireteam"
## Who comes along (v0.79, ticked on the page before a mission): two of CANDIDATES. The
## squad and the two plain men come from the start; an operator only in the second mission,
## where he joins at the station - until then one of the squad who was not picked walks in
## his place and stays behind there. `squad` (who starts) and `company` (who goes on from
## the station) are worked out from these two (settle_picks).
const CANDIDATES := ["viper", "scorpion", "raven", "phantom", "havoc", "ghost", "dude_shorts", "dude_turtleneck"]
const OPERATORS := ["phantom", "havoc", "ghost"]
var picks: Array = ["viper", "scorpion"]

func open() -> void:
	if not stored or not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		read(parsed)

## Takes over what a saved profile holds. A difficulty that is no longer on the menu is
## not taken over: the profile comes up on NORMAL.
func read(parsed: Dictionary) -> void:
	if str(parsed.get("difficulty", "")) in ORDER:
		difficulty = str(parsed.difficulty)
	if str(parsed.get("mode", "")) in ["story", "endless"]:
		mode = str(parsed.mode)
	var saved_mission := int(parsed.get("mission", 1))
	if saved_mission in [1, 2, 3]:
		mission = saved_mission
	elif saved_mission == 4:
		# (Mission 4, the simulation hall, is a part of the second mission now.)
		mission = 2
	modifiers = bool(parsed.get("modifiers", false))
	if str(parsed.get("room", "")) in HiveLayout.rooms():
		room = str(parsed.get("room", ""))
	if str(parsed.get("hive_mode", "")) in ["mission", "endless"]:
		hive_mode = str(parsed.get("hive_mode", ""))
	if HiveLayout.LENGTHS.has(str(parsed.get("length", ""))):
		length = str(parsed.get("length", ""))
	if parsed.get("runs") is Dictionary:
		# (Also the lists of the levels that are gone: they stay in the file.)
		for level in ORDER + RETIRED:
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
	if parsed.get("wishes") is Dictionary:
		wishes = parsed.wishes
	company = known_company(str(parsed.get("company", "")))
	# (A file from before v0.79 has no picks: the operators of its company, else its squad.)
	var saved: Variant = parsed.get("picks")
	if saved is Array and (saved as Array).size() == 2 and str(saved[0]) != str(saved[1]) and may_pick(str(saved[0])) and may_pick(str(saved[1])):
		picks = [str(saved[0]), str(saved[1])]
	elif company != "fireteam" and pair_of(company).size() == 2:
		picks = pair_of(company)
	else:
		picks = squad.duplicate()
	settle_picks()

func save() -> void:
	if not stored:
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(kept(), "\t"))

## What is written to the file.
func kept() -> Dictionary:
	var out := {"difficulty": difficulty, "mission": mission, "mode": mode, "modifiers": modifiers, "runs": runs, "totals": totals, "skin": skin, "squad": squad, "picks": picks, "room": room, "length": length, "hive_mode": hive_mode}
	if not skills.is_empty():
		out["skills"] = skills
	if skill_tree != "":
		out["skill_tree"] = skill_tree
	if not wishes.is_empty():
		out["wishes"] = wishes
	if company != "fireteam":
		out["company"] = company
	return out

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
	if SKINS.has(id) and bool(SKINS[id].bot) and unlocked(id) and not picks.has(id):
		pick(id)

## Whether somebody can be ticked to come along: the operators always, the others once
## their look is unlocked.
func may_pick(id: String) -> bool:
	return id in CANDIDATES and SKINS.has(id) and (id in OPERATORS or unlocked(id))

## Ticks one more to come along; the one that was ticked longest ago makes room.
func pick(id: String) -> void:
	if not may_pick(id) or picks.has(id):
		return
	picks = [picks[picks.size() - 1], id] if not picks.is_empty() else [id]
	settle_picks()
	save()

## Sets both at once (the start option --squad=, the checks). Unknown or twice the same:
## nothing changes.
func set_picks(first: String, second: String) -> bool:
	if first == second or not (first in CANDIDATES and second in CANDIDATES):
		return false
	picks = [first, second]
	settle_picks()
	return true

## Works out from the picks who starts (`squad`: those of them who are not operators, and
## for each operator one of the squad who was not picked - the ones there were before
## first) and who goes on from the station (`company`: the operators among them, or
## "fireteam").
func settle_picks() -> void:
	var starters: Array = []
	for id in picks:
		if not str(id) in OPERATORS:
			starters.append(str(id))
	for id in squad + ["viper", "scorpion", "raven"]:
		if starters.size() >= 2:
			break
		if not starters.has(id) and not picks.has(id) and SKINS.has(id) and bool(SKINS[id].bot) and unlocked(id):
			starters.append(id)
	if starters.size() == 2:
		squad = starters
	var operators: Array[String] = []
	for id in OPERATORS:
		if picks.has(id):
			operators.append(id)
	company = "fireteam" if operators.is_empty() else "_".join(PackedStringArray(operators))

## Who of the squad goes on from the station beside one operator alone: the one who was
## picked ("" when both or none of the squad were).
func goer() -> String:
	var mine: Array = picks.filter(func(id: String) -> bool: return not id in OPERATORS)
	return str(mine[0]) if mine.size() == 1 else ""

func rules() -> Dictionary:
	return DIFFICULTIES[difficulty]

func next_difficulty() -> void:
	difficulty = ORDER[(ORDER.find(difficulty) + 1) % ORDER.size()]
	save()

func next_mode() -> void:
	mode = "endless" if mode == "story" else "story"
	save()

func next_company() -> void:
	company = COMPANIES[(COMPANIES.find(known_company(company)) + 1) % COMPANIES.size()]
	save()

## A choice of company as it is understood today: "operators" (kept by v0.25 to v0.28,
## when all three came along) is Phantom and Havoc; anything unknown is the squad.
static func known_company(value: String) -> String:
	if value == "operators":
		return "phantom_havoc"
	return value if value in COMPANIES else "fireteam"

## The looks of the two operators a choice of company names (none for the squad).
static func pair_of(value: String) -> Array[String]:
	var looks: Array[String] = []
	if value != "fireteam" and value in COMPANIES:
		for look in value.split("_"):
			looks.append(look)
	return looks

func choose_mission(number: int) -> void:
	if number in [1, 2, 3]:
		mission = number
		save()

## What a night is filed under and called for the list of the best: "story" or "endless"
## on the farm, "villa" for the second mission.
func play() -> String:
	return "villa" if mission == 2 else mode

## The next room in the list of HiveLayout.rooms() (after the last: chance again).
func next_room() -> void:
	var list := HiveLayout.rooms()
	room = list[(list.find(room) + 1) % list.size()]
	save()

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
