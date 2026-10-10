class_name HiveCaches
extends Node
## The weapon caches of the second mission: what makes its way more than a tube.
##
## The weapon lockers of the supply points sell a short list only (STANDARD): the carbine
## a night begins with, one plain rifle, one plain submachine gun, the sidearm and the
## weapon of the tree of abilities that is in force. Every other weapon has to be FOUND.
## It lies in a cache that stands in a room off the main way - a locker, a crate, a gun
## cabinet; a safe, an armoury cage, a containment locker - and each night only a random
## share of all the places there are (SITES) holds one. What is in it is drawn from the
## weapons that are not standard, the dearer ones deeper in the facility and behind a
## lock.
##
## A plain cache is searched: [E], then a few seconds beside it. A sealed one has to be
## earned: [E] sets a tool to its lock, and the survivor has to stay near it until it is
## open (SEALED_SECONDS). It is loud, and the infected answer: for as long as it lasts
## packs come through the ways in nearest to that place (HiveEntries), whatever the stage
## says. Whoever leaves the place stops the opening; it goes on when he is back. (Held
## down beside it or on the ground he has not left: the tool works on.)
##
## Nobody is led there. A cache is known - a side goal on the HUD, a small mark on the map
## in the corner - once the survivor has come near it, has read one of the honeycomb
## displays (it marks the sectors that hold one tonight) or has stood before a terminal
## in a wall (its last line names the nearest one).
##
## A found weapon is the survivor's for the night like a bought one. Where he has no
## place for it, the one it replaces stays in the cache and can be taken back. A defeat
## that is taken up again at a checkpoint keeps what had been found before that
## checkpoint: the same places, the caches opened by then still open, and the found
## weapons he carried then in his hands again.
##
## The furniture of every place is built once with the map (furnish, called by HiveMap);
## this node, a child of the director, deals the night and runs it.
##   --caches-check --capture-dir=<folder>   pictures of all of it (see _pictures)

## What the weapon lockers of this mission sell. (The three weapons of the trees stay
## what they were: only for somebody with points in that tree, and that tree in force.)
const STANDARD := ["rifle", "ak", "ump", "pistol", "flamer", "nitro", "fifty"]
## The share of the places of each part of the map that holds a cache in a night.
const SHARE := 0.45
## Seconds beside a plain cache until it is searched, beside a sealed one until it is open.
const PLAIN_SECONDS := 3.0
const SEALED_SECONDS := 25.0
## How near the survivor has to stay for that (metres), and from how far it is used.
const PLAIN_RADIUS := 3.5
const HOLD_RADIUS := 6.5
const USE_REACH := 2.3
## A cache is noticed from this far, its mark is on the HUD from this far, a display is
## read from this far (a wide one from further), a terminal from this far.
const NEAR := 13.0
const MARK_REACH := 34.0
const HINT_REACH := 6.0
const TERMINAL_REACH := 3.2
## The answer to a sealed cache that is being opened: seconds until the first pack and
## between two, and by the depth of the place (0 the villa, 1 the station, 2 the offices
## and the canteen, 3 from the central hall on) how many a pack has at the least and at
## the most, and how many may be alive at once for it (on NORMAL; the level's horde counts).
const ANSWER_FIRST := 2.5
const ANSWER_GAP := 6.5
const ANSWER_PACK := [[2, 2], [2, 3], [2, 3], [3, 4]]
const ANSWER_CROWD := [5, 7, 9, 11]
const ANSWER_KINDS := [["mauler", "mauler", "striker"], ["mauler", "mauler", "striker", "ripper"], ["mauler", "mauler", "striker", "ripper", "leech"], ["mauler", "striker", "ripper", "ripper", "leech"]]
## What a cache holds, by the depth of its place: the prices (Survivor.WEAPONS) between
## which its weapon is drawn - a plain one, and a sealed one.
const PLAIN_WORTH := [[0, 260], [200, 330], [270, 460], [440, 660]]
const SEALED_WORTH := [[270, 360], [340, 460], [490, 810], [790, 99999]]
## Score for a sealed cache that was opened (times the level's factor).
const SEALED_SCORE := 150
## The colours of a cache's lamp and of its words.
const MINT := Color(0.5, 0.95, 0.72)
const RED := Color(1.0, 0.3, 0.22)
const AMBER := Color(1.0, 0.72, 0.2)
const GREEN := Color(0.35, 1.0, 0.45)
## The looks: whether it is sealed, what the HUD calls it, what [E] does to it, its
## outside (wide, tall, deep), and whether its weapon is seen before it is open.
const LOOKS := {
	"spind": {"sealed": false, "word": "SPIND", "use": "Spind durchsuchen", "size": Vector3(1.2, 1.9, 0.56), "shows": false},
	"kiste": {"sealed": false, "word": "WAFFENKISTE", "use": "Waffenkiste aufhebeln", "size": Vector3(1.5, 0.5, 0.86), "shows": false},
	"schrank": {"sealed": false, "word": "JAGDSCHRANK", "use": "Jagdschrank öffnen", "size": Vector3(1.3, 2.1, 0.5), "shows": false},
	"tresor": {"sealed": true, "word": "WAFFENTRESOR", "use": "Waffentresor aufbohren", "size": Vector3(1.1, 1.7, 0.78), "shows": false},
	"kaefig": {"sealed": true, "word": "WAFFENKÄFIG", "use": "Schloss des Waffenkäfigs aufschneiden", "size": Vector3(1.6, 2.1, 0.87), "shows": true},
	"schleuse": {"sealed": true, "word": "SICHERHEITSSCHRANK", "use": "Verriegelung des Sicherheitsschranks überbrücken", "size": Vector3(1.2, 2.0, 0.74), "shows": false}
}
## The places: its name, the room, the side of that room it stands against and where
## along that wall, its look, what the HUD calls the room, how deep in the mission it
## lies, the part of the map it is dealt with (and whose displays tell of it), and its
## cell on the honeycomb display ("" where there is no display). None of them stands on
## the main way: each is at least five metres beside it, and all but one - at the dead
## end of the terminal's gallery - in a room it does not lead through (see the checks).
const SITES := [
	["salon", "salon", HiveCore.NORTH, -14.0, "schrank", "SALON", 0, "villa", ""],
	["galerie", "galerie", HiveCore.NORTH, 20.0, "tresor", "GEMÄLDEGALERIE", 0, "villa", ""],
	["kueche", "kitchen", HiveCore.SOUTH, 19.5, "kiste", "KÜCHE DER VILLA", 0, "villa", ""],
	["empore", "gallery", HiveCore.EAST, 10.0, "kiste", "EMPORE", 0, "villa", ""],
	["depot", "depot", HiveCore.EAST, -51.75, "kaefig", "DEPOT", 1, "station", "station"],
	["depot_kiste", "depot", HiveCore.SOUTH, 47.5, "kiste", "DEPOT", 1, "station", "station"],
	["werkstatt", "workshop", HiveCore.SOUTH, -49.25, "spind", "WERKSTATT", 1, "station", "station"],
	["terminal_galerie", "term_deck", HiveCore.SOUTH, -34.0, "kiste", "GALERIE DES TERMINALS", 2, "admin", "terminal"],
	["scanner", "scanner", HiveCore.WEST, -352.5, "spind", "SCANNERRAUM", 2, "admin", "checkpoint"],
	["besprechung", "meeting", HiveCore.NORTH, -12.9, "tresor", "BESPRECHUNGSRAUM", 2, "admin", "admin"],
	["kopierraum", "copy", HiveCore.EAST, -379.0, "kiste", "KOPIERRAUM", 2, "admin", "admin"],
	["buero", "office", HiveCore.NORTH, -27.0, "spind", "GROSSRAUMBÜRO", 2, "admin", "office"],
	["archiv", "archive", HiveCore.WEST, -405.5, "tresor", "ARCHIV", 2, "admin", "office"],
	["personal", "staff", HiveCore.WEST, -399.0, "spind", "PERSONALRAUM", 2, "admin", "admin"],
	["server", "server", HiveCore.EAST, -388.0, "kaefig", "SERVERRAUM", 2, "admin", "security"],
	["kantinenkueche", "kitchen_f", HiveCore.SOUTH, 35.75, "kiste", "KÜCHE DER KANTINE", 2, "cafe", "cafe"],
	["kantinenlager", "cafe_store", HiveCore.WEST, -413.0, "kaefig", "LAGER DER KANTINE", 2, "cafe", "cafe"],
	["krankenstation", "med", HiveCore.SOUTH, -44.0, "spind", "KRANKENSTATION", 3, "core", "med"],
	["zentral_galerie", "atrium_deck", HiveCore.SOUTH, 18.5, "kiste", "GALERIE DES ZENTRALRAUMS", 3, "core", "core"],
	["pumpenraum", "pump", HiveCore.NORTH, 55.0, "kaefig", "PUMPENRAUM", 3, "core", "tech"],
	["labor_a", "lab_a", HiveCore.SOUTH, -23.0, "schleuse", "LABOR A", 3, "research", "labs_west"],
	["labor_b", "lab_b", HiveCore.NORTH, -20.0, "spind", "LABOR B", 3, "research", "labs_west"],
	["labor_c", "lab_c", HiveCore.NORTH, 22.0, "schleuse", "LABOR C", 3, "research", "labs_east"],
	["kryolager", "cryo", HiveCore.SOUTH, 23.0, "schleuse", "KRYOLAGER", 3, "research", "labs_east"],
	["quarantaene", "quarantine", HiveCore.WEST, -548.5, "schleuse", "QUARANTÄNE", 3, "research", "quarantine"],
	["nasslabor", "flooded", HiveCore.EAST, -557.5, "kiste", "NASSLABOR", 3, "research", "wet"]
]

var director: HiveDirector
var game: Node3D
var map: HiveMap
var on := false
## What the night was dealt from (a night taken up again is dealt from the same).
var night := 0
## The places of the map (HiveMap.caches): what was built there, and for the night its
## state ("none" nothing tonight, "shut", "opening", "open", "empty"), what it holds, the
## seconds still to stay, and whether the survivor knows of it.
var sites: Array[Dictionary] = []
## Checkpoint -> what was found by then (see keep).
var kept: Dictionary = {}
## Found weapon -> the place it came from.
var origin: Dictionary = {}
## The places whose doors are moving.
var moving: Array[int] = []
## The displays and the terminals of the map: {node, at, reach, group, read, ...}.
var boards: Array[Dictionary] = []
var screens: Array[Dictionary] = []
var hints: Node3D
var told: Dictionary = {}
var look_left := 0.0
var clock := 0.0
## The tool at the lock of a sealed cache: what is heard and what flies.
var noise: AudioStreamPlayer3D
var sparks: CPUParticles3D
var noisy := -1
## For the checks: how many came because of a cache, how many caches were opened.
var answered := 0
var opened := 0
## The bot of the checks has been to this many (see bot_goal).
var bot_visits := 0

static var grind: AudioStreamWAV

func _ready() -> void:
	name = "Caches"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	game = director.game
	if "--caches-check" in OS.get_cmdline_user_args():
		game.check_mode = true
		call_deferred("_pictures")

# ---------------------------------------------------------------- what the lockers sell

## True if the weapon lockers of this mission sell a weapon.
static func sells(id: String) -> bool:
	return STANDARD.has(id)

## The weapons that are only found, in the order of the shop.
static func found_only() -> Array[String]:
	var out: Array[String] = []
	for id: String in Survivor.ORDER:
		if not STANDARD.has(id):
			out.append(id)
	return out

## The part of the map a place lies in, as the places are dealt (the groups of SITES): a
## display tells of the caches of the part it hangs in.
static func part_of(at: Vector3) -> String:
	if at.z > -200.0:
		return "station" if at.y < -4.0 else "villa"
	if at.z > -405.0:
		return "admin"
	if at.z > -445.0:
		return "cafe"
	return "core" if at.z > -501.0 else "research"

# ---------------------------------------------------------------- dealing a night

## Which places hold a cache in the night of a seed, and what: index of the place ->
## weapon. Of every part of the map SHARE of its places (at least one), at random; the
## weapons by depth and lock, each only once for as long as there are enough.
static func deal(seed_value: int, places: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var groups: Dictionary = {}
	var order: Array[String] = []
	for index in range(places.size()):
		var group := str(places[index].group)
		if not groups.has(group):
			groups[group] = []
			order.append(group)
		(groups[group] as Array).append(index)
	var live: Array[int] = []
	for group in order:
		var members: Array = groups[group]
		for k in range(members.size() - 1, 0, -1):
			var other := rng.randi_range(0, k)
			var swap: int = members[k]
			members[k] = members[other]
			members[other] = swap
		var wanted := members.size() * SHARE
		var count := clampi(int(floor(wanted)) + (1 if rng.randf() < wanted - floor(wanted) else 0), 1, members.size())
		for k in range(count):
			live.append(int(members[k]))
	# The shallow ones choose first, the plain before the sealed: what is left for the
	# depth is what belongs there.
	var earlier := func(a: int, b: int) -> bool:
		var da := int(places[a].depth) * 2 + (1 if bool(places[a].sealed) else 0)
		var db := int(places[b].depth) * 2 + (1 if bool(places[b].sealed) else 0)
		return da < db if da != db else a < b
	live.sort_custom(earlier)
	var pool := found_only()
	var taken: Dictionary = {}
	var out: Dictionary = {}
	for index in live:
		var window: Array = (SEALED_WORTH if bool(places[index].sealed) else PLAIN_WORTH)[clampi(int(places[index].depth), 0, 3)]
		var fitting: Array[String] = []
		var free: Array[String] = []
		for id in pool:
			var worth := int(Survivor.WEAPONS[id].price)
			if worth >= int(window[0]) and worth <= int(window[1]):
				fitting.append(id)
				if not taken.has(id):
					free.append(id)
		var pick := ""
		if not free.is_empty():
			pick = free[rng.randi() % free.size()]
		else:
			# Nothing of that worth is left: the one nearest to it that nobody has yet.
			var middle := (int(window[0]) + mini(int(window[1]), 1600)) * 0.5
			var best_gap := INF
			for id in pool:
				var gap := absf(int(Survivor.WEAPONS[id].price) - middle)
				if not taken.has(id) and gap < best_gap:
					best_gap = gap
					pick = id
			if pick == "" and not fitting.is_empty():
				pick = fitting[rng.randi() % fitting.size()]
		if pick != "":
			taken[pick] = true
			out[index] = pick
	return out

# ---------------------------------------------------------------- a night begins and ends

## A night begins at a checkpoint (the director says so). At "landing" it is a new night;
## anywhere else it is the night that was lost, taken up again.
func begin(from: String) -> void:
	on = true
	map = director.map
	sites = map.caches
	var saved: Dictionary = kept.get(from, {}) if from != "landing" else {}
	if saved.is_empty():
		kept.clear()
		night = randi()
	else:
		night = int(saved.night)
	told.clear()
	origin.clear()
	moving.clear()
	answered = 0
	opened = 0
	bot_visits = 0
	clock = 0.0
	look_left = 0.0
	_quiet()
	var dealt := deal(night, sites)
	for index in range(sites.size()):
		var site := sites[index]
		site.holds = str(dealt.get(index, ""))
		site.state = "shut" if dealt.has(index) else "none"
		site.record = {}
		site.left = _seconds(site)
		site.known = false
		site.near = false
		site.answer = ANSWER_FIRST
	_find_hints()
	if not saved.is_empty():
		_take_up(saved)
	for index in range(sites.size()):
		_show(index, true)
	_post_hints()

func end() -> void:
	on = false
	_quiet()

func _seconds(site: Dictionary) -> float:
	return SEALED_SECONDS if bool(site.sealed) else PLAIN_SECONDS

## The squad is past a point of no return: what has been found by now is kept for a
## defeat that is taken up again from here.
func keep(id: String) -> void:
	if not on:
		return
	var states: Dictionary = {}
	for site in sites:
		states[str(site.id)] = {"state": site.state, "holds": site.holds, "record": (site.record as Dictionary).duplicate(true), "left": site.left, "known": site.known}
	var found: Array[String] = []
	for weapon in found_only():
		if game.player.inventory.has(weapon):
			found.append(weapon)
	var read: Array[int] = []
	for index in range(boards.size()):
		if bool(boards[index].read):
			read.append(index)
	kept[id] = {"night": night, "sites": states, "found": found, "origin": origin.duplicate(), "read": read, "told": told.duplicate()}

## The night as it was at a checkpoint: the caches as they stood then, and the found
## weapons the survivor carried then in his hands again, with a full load. (Whatever he
## had bought is gone, as it always was: the checkpoint's supply pays for that.)
func _take_up(saved: Dictionary) -> void:
	var states: Dictionary = saved.sites
	for site in sites:
		var was: Dictionary = states.get(str(site.id), {})
		if was.is_empty():
			continue
		site.state = str(was.state)
		site.holds = str(was.holds)
		site.record = (was.record as Dictionary).duplicate(true)
		site.left = float(was.left)
		site.known = bool(was.known)
	for index: int in saved.read:
		if index < boards.size():
			boards[index].read = true
	told = (saved.told as Dictionary).duplicate()
	origin = (saved.origin as Dictionary).duplicate()
	var player: Survivor = game.player
	var first := str(player.current_weapon)
	for weapon: String in saved.found:
		if player.inventory.has(weapon) or not Survivor.WEAPONS.has(weapon):
			continue
		var old := player.to_replace(weapon)
		# It takes the place of the carbine he would otherwise begin with; where it has
		# no place even so (a sling is gone), it lies in its cache again.
		if old != "" and not STANDARD.has(old):
			var back := int(origin.get(weapon, -1))
			if back >= 0 and back < sites.size() and str(sites[back].holds) == "":
				sites[back].holds = weapon
				sites[back].record = {}
				sites[back].state = "open"
			continue
		player.unlock(weapon)
		if old != "":
			player.drop_weapon(old)
	if player.inventory.has(first):
		player.equip_weapon(first, true)

# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	if not on or not director.on or not game.is_playing():
		if noisy >= 0:
			_quiet()
		return
	clock += delta
	var index := 0
	while index < moving.size():
		var site := sites[moving[index]]
		site.swing = move_toward(float(site.swing), float(site.swing_to), delta * (1.1 if bool(site.sealed) else 2.2))
		_pose(site)
		if is_equal_approx(float(site.swing), float(site.swing_to)):
			moving.remove_at(index)
		else:
			index += 1
	if director.intro_left > 0.0:
		return
	var player: Survivor = game.player
	var here := player.global_position
	var busy := -1
	for number in range(sites.size()):
		var site := sites[number]
		if str(site.state) != "opening":
			continue
		var stand: Vector3 = site.stand
		# (Whoever is held down beside it, or lies there, has not left: the tool works on.)
		var near := absf(here.y - stand.y) < 2.5 and Vector2(here.x - stand.x, here.z - stand.z).length() < (HOLD_RADIUS if bool(site.sealed) else PLAIN_RADIUS)
		site.near = near
		# The lamp says what happens: quick while it goes on, slow while it waits.
		var beat := 0.5 + 0.5 * sin(clock * (11.0 if near else 3.0))
		_tint(site, AMBER * (0.35 + 0.65 * beat))
		if not near:
			continue
		site.left = float(site.left) - delta
		if bool(site.sealed):
			busy = number
			_answer(number, delta)
		if float(site.left) <= 0.0:
			_opened(number)
	_sound(busy)
	look_left -= delta
	if look_left <= 0.0:
		look_left = 0.3
		_notice(here)

## Whether a cache is worth going to: something is in it, or it is still shut.
func _wanted(site: Dictionary) -> bool:
	var state := str(site.state)
	return state == "shut" or state == "opening" or (state == "open" and str(site.holds) != "")

## Whether the survivor can get there at all right now: its part of the map is open, and
## it lies on his side of the tunnel.
func _reachable(site: Dictionary, here: Vector3) -> bool:
	if bool(map.locked.get(str(site.area), false)):
		return false
	return (int(site.level) >= map.deep) == (map.level_of(here + Vector3(0, 0.3, 0)) >= map.deep)

# ---------------------------------------------------------------- using one

## The cache the survivor stands before, or -1.
func _at_hand() -> int:
	if not on or director.intro_left > 0.0:
		return -1
	var here: Vector3 = game.player.global_position
	var best := -1
	var best_gap := USE_REACH
	for index in range(sites.size()):
		var site := sites[index]
		var state := str(site.state)
		if not (state == "shut" or (state == "open" and str(site.holds) != "")):
			continue
		var stand: Vector3 = site.stand
		var gap := Vector2(here.x - stand.x, here.z - stand.z).length()
		if absf(here.y - stand.y) < 1.6 and gap < best_gap:
			best_gap = gap
			best = index
	return best

func prompt() -> String:
	var index := _at_hand()
	if index < 0:
		return ""
	var site := sites[index]
	var look: Dictionary = LOOKS[site.look]
	if str(site.state) == "shut":
		if bool(site.sealed):
			return "[E] %s  ·  %d s in der Nähe bleiben – das lockt sie an" % [look.use, int(SEALED_SECONDS)]
		return "[E] %s" % look.use
	var id := str(site.holds)
	var player: Survivor = game.player
	var label := str(Survivor.WEAPONS[id].label)
	if player.inventory.has(id):
		return "[E] Munition für %s mitnehmen" % label
	var old := player.to_replace(id)
	return "[E] %s nehmen" % label if old == "" else "[E] %s nehmen  ·  %s bleibt hier" % [label, Survivor.WEAPONS[old].label]

## [E] was pressed. True if that was for a cache.
func use() -> bool:
	var index := _at_hand()
	if index < 0:
		return false
	var site := sites[index]
	site.known = true
	if str(site.state) == "shut":
		site.state = "opening"
		site.near = true
		site.answer = ANSWER_FIRST
		game.sounds.play_at("click", site.at, 4.0, 0.8)
		if bool(site.sealed):
			game.sounds.play_at("beep", site.at, 4.0, 0.7)
			game.hud.announce("%s  ·  WIRD GEÖFFNET" % LOOKS[site.look].word, "Bleib in der Nähe: %d Sekunden, und es ist nicht zu überhören. Gehst du weg, steht es still." % int(SEALED_SECONDS), 4.5)
		_show(index)
		return true
	_take(index)
	return true

## The survivor takes what an open cache holds. Without a place for it, the weapon it
## replaces stays here, as it is, and can be taken back.
func _take(index: int) -> void:
	var site := sites[index]
	var id := str(site.holds)
	var player: Survivor = game.player
	var label := str(Survivor.WEAPONS[id].label)
	if player.inventory.has(id):
		player.inventory[id].reserve = player.reserve_cap(id)
		site.holds = ""
		site.record = {}
		site.state = "empty"
		game.sounds.play_sound("pickup")
		game.hud.announce("MUNITION", "%s  ·  Reserve aufgefüllt." % label, 2.5)
		_show(index)
		_post_hints()
		return
	var old := player.to_replace(id)
	var was: Dictionary = site.record
	player.unlock(id)
	if not was.is_empty():
		player.inventory[id] = was.duplicate(true)
		player._show_parts()
	origin[id] = index
	if old != "":
		site.holds = old
		site.record = (player.inventory[old] as Dictionary).duplicate(true)
		player.drop_weapon(old)
	else:
		site.holds = ""
		site.record = {}
		site.state = "empty"
	game.sounds.play_sound("pickup")
	if game.hud != null:
		game.hud.loadout()
	var note := "Gehört dir für diese Nacht – Munition, Werkbank und Aufsätze wie bei jeder anderen."
	if old != "":
		note = "%s bleibt im Lager und kann zurückgetauscht werden." % Survivor.WEAPONS[old].label
	game.hud.announce("%s  ·  GEFUNDEN" % label, note, 4.0)
	_show(index)
	_post_hints()

func _opened(index: int) -> void:
	var site := sites[index]
	site.state = "open"
	site.left = 0.0
	site.near = false
	opened += 1
	var label := str(Survivor.WEAPONS[str(site.holds)].label) if str(site.holds) != "" else ""
	if bool(site.sealed):
		game.sounds.play_at("shutter_open", site.at, 0.0, 1.5)
		game.stats.objectives += 1
		game.score += int(round(SEALED_SCORE * float(game.rules.score)))
		game.hud.announce("%s  ·  OFFEN" % LOOKS[site.look].word, "%s liegt bereit." % label, 3.5)
	else:
		game.sounds.play_at("equip", site.at, 3.0, 0.8)
	_show(index)

# ---------------------------------------------------------------- the answer

## While a sealed cache is being opened: a pack through one of the ways in nearest to it,
## again and again - in a stage in which nobody comes by himself as well.
func _answer(index: int, delta: float) -> void:
	var site := sites[index]
	site.answer = float(site.answer) - delta
	if float(site.answer) > 0.0:
		return
	site.answer = ANSWER_GAP * randf_range(0.85, 1.15)
	var depth := clampi(int(site.depth), 0, 3)
	var cap: int = mini(HiveDirector.CROWD_LIMIT, roundi(int(ANSWER_CROWD[depth]) * director._horde())) + int(game.extra_guns())
	var ways: HiveEntries = director.entries
	var room: int = cap - int(game.alive_count) - ways.coming()
	if room <= 0:
		return
	var sizes: Array = ANSWER_PACK[depth]
	var count := mini(room, randi_range(int(sizes[0]), int(sizes[1])))
	var kinds: Array = ANSWER_KINDS[depth]
	var pack: Array[String] = []
	var rare := false
	for k in range(count):
		var kind := str(kinds[randi() % kinds.size()])
		if HiveEntries.RARE.has(kind):
			kind = "mauler" if rare else kind
			rare = true
		pack.append(kind)
	var options: Array = ways.found(site.stand) if ways.on else []
	if not options.is_empty():
		var pick: Array = options[randi() % mini(3, options.size())]
		var before := ways.due.size()
		ways.announce(int(pick[1]), pack[0], pack)
		# (They come whatever the stage says: see HiveEntries._process.)
		for k in range(before, ways.due.size()):
			ways.due[k]["cache"] = true
		answered += pack.size()
		return
	# No way in near that place: from where nobody looks, as the director does it.
	for kind in pack:
		var at := director._hidden_spot(12.0, 28.0)
		if at != Vector3.INF and director._spawn(kind, at) != null:
			answered += 1

# ---------------------------------------------------------------- knowing of them

func _notice(here: Vector3) -> void:
	for index in range(sites.size()):
		var site := sites[index]
		if bool(site.known) or not _wanted(site) or not _reachable(site, here):
			continue
		var at: Vector3 = site.stand
		if absf(at.y - here.y) < 2.5 and Vector2(at.x - here.x, at.z - here.z).length() < NEAR:
			_learn([index], "near")
	var below := map.level_of(here + Vector3(0, 0.3, 0)) >= map.deep
	for board in boards:
		if bool(board.read):
			continue
		var at: Vector3 = board.at
		if (at.y < HiveMap.UNDER + 20.0 and at.z < -200.0) != below or Vector2(at.x - here.x, at.z - here.z).length() > float(board.reach):
			continue
		board.read = true
		var found: Array = []
		for index in range(sites.size()):
			if str(sites[index].group) == str(board.group) and _wanted(sites[index]) and not bool(sites[index].known):
				found.append(index)
		_learn(found, "board")
	for screen in screens:
		if bool(screen.read):
			continue
		var at: Vector3 = screen.at
		if absf(at.y - here.y) > 2.5 or Vector2(at.x - here.x, at.z - here.z).length() > TERMINAL_REACH:
			continue
		screen.read = true
		var index := int(screen.names)
		if index >= 0 and _wanted(sites[index]) and not bool(sites[index].known):
			_learn([index], "screen")

## The survivor learns of caches: they are side goals from now on.
func _learn(found: Array, how: String) -> void:
	if found.is_empty():
		return
	var names: Array[String] = []
	for index: int in found:
		sites[index].known = true
		names.append("%s (%s)" % [sites[index].title, str(LOOKS[sites[index].look].word).capitalize()])
	var first := not told.has("first")
	told["first"] = true
	var more := "  Was kein Waffenschrank verkauft, liegt in solchen Lagern." if first else ""
	match how:
		"board":
			# (A banner has one line: the first two by name, the others counted.)
			var listed := ", ".join(PackedStringArray(names.slice(0, 2)))
			if names.size() > 2:
				listed += " und %d weitere%s" % [names.size() - 2, "s" if names.size() == 3 else ""]
			game.hud.announce("LAGEPLAN  ·  WAFFENLAGER", "In diesem Sektor: %s.%s" % [listed, more], 7.0 if first else 5.0)
		"screen":
			game.hud.announce("TERMINAL  ·  LAGERLISTE", "Nächstes Waffenlager: %s.%s" % [names[0], more], 7.0 if first else 4.5)
		_:
			game.hud.announce("NEBENZIEL  ·  WAFFENLAGER", "%s, ganz in der Nähe.%s" % [names[0], more], 7.0 if first else 3.5)
	game.sounds.play_sound("radio")

## What the HUD says under the goal of the stage.
func summary() -> Array[String]:
	var out: Array[String] = []
	if not on or director.intro_left > 0.0:
		return out
	var here: Vector3 = game.player.global_position
	var best := -1
	var best_gap := INF
	for index in range(sites.size()):
		var site := sites[index]
		if str(site.state) == "opening":
			var word := str(LOOKS[site.look].word)
			var share := int(clampf(1.0 - float(site.left) / _seconds(site), 0.0, 1.0) * 100.0)
			if bool(site.near):
				out.append("◆  %s  ·  WIRD GEÖFFNET   %d %%" % [word, share])
			elif _reachable(site, here):
				out.append("◆  %s  ·  UNTERBROCHEN   %d %%  ·  zurück in den Raum: %s" % [word, share, site.title])
			continue
		if not bool(site.known) or not _wanted(site) or not _reachable(site, here):
			continue
		var gap := here.distance_to(site.at)
		if gap < best_gap:
			best_gap = gap
			best = index
	if best >= 0 and out.is_empty():
		var site := sites[best]
		var what := str(LOOKS[site.look].word) if str(site.state) == "shut" else "%s LIEGT BEREIT" % Survivor.WEAPONS[str(site.holds)].label
		out.append("◇  NEBENZIEL  ·  WAFFENLAGER  ·  %s  ·  %s  ·  %d m" % [site.title, what, int(best_gap)])
	return out

## The marks of the side goals: small ones, beside the stage's own (`side`).
func markers() -> Array:
	var out: Array = []
	if not on or director.intro_left > 0.0:
		return out
	var here: Vector3 = game.player.global_position
	for site in sites:
		if not bool(site.known) or not _wanted(site) or not _reachable(site, here):
			continue
		if str(site.state) == "opening" or here.distance_to(site.stand) < MARK_REACH:
			out.append({"pos": (site.at as Vector3) + Vector3(0, 0.5, 0), "text": "LAGER", "side": true})
	return out

# ---------------------------------------------------------------- the bot of the checks

## Where the walking bot of the checks turns off to: a plain cache near its way that is
## still shut (two a night at the most) or holds something it has a hand free for;
## Vector3.INF if there is none.
## Never while a place has to be held.
func bot_goal(here: Vector3) -> Vector3:
	if not on or director.stage in ["mirror", "hold", "lockdown", "hall", "ride", "nadja", "deal", "board", "exit"]:
		return Vector3.INF
	var best := Vector3.INF
	var best_gap := 30.0
	for site in sites:
		if bool(site.sealed) or not _reachable(site, here) or absf((site.stand as Vector3).y - here.y) > 2.5:
			continue
		var state := str(site.state)
		var takes: bool = state == "open" and str(site.holds) != "" and not game.player.inventory.has(str(site.holds)) and game.player.to_replace(str(site.holds)) == ""
		if not ((state == "shut" and bot_visits < 2) or state == "opening" or takes):
			continue
		var gap := here.distance_to(site.stand)
		if gap < best_gap and not map.path_between(here, site.stand).is_empty():
			best_gap = gap
			best = site.stand
	return best

## The bot stands before a cache: it opens it, takes what it has a hand free for and
## goes on with the weapon it had. True if it did anything.
func bot_use() -> bool:
	var index := _at_hand()
	if index < 0 or bool(sites[index].sealed):
		return false
	var site := sites[index]
	var player: Survivor = game.player
	if str(site.state) == "open":
		var id := str(site.holds)
		if player.inventory.has(id) or player.to_replace(id) != "":
			return false
		var had := str(player.current_weapon)
		use()
		player.equip_weapon(had, true)
		return true
	if str(site.state) != "shut" or not use():
		return false
	bot_visits += 1
	return true

# ---------------------------------------------------------------- what is seen and heard

## Puts a place into the look of its state.
func _show(index: int, instant: bool = false) -> void:
	var site := sites[index]
	var state := str(site.state)
	var sealed := bool(site.sealed)
	site.swing_to = 1.0 if state in ["none", "open", "empty"] else 0.0
	if instant:
		site.swing = site.swing_to
		_pose(site)
	elif not moving.has(index):
		moving.append(index)
	var live := _wanted(site)
	var tone := (RED if sealed else MINT) if state == "shut" else (AMBER if state == "opening" else GREEN)
	(site.tag as Label3D).visible = live
	(site.tag as Label3D).modulate = tone
	(site.glow as OmniLight3D).visible = live
	(site.glow as OmniLight3D).light_color = tone
	_tint(site, tone if live else Color(0.05, 0.055, 0.06))
	if site.tool != null:
		(site.tool as Node3D).visible = state == "opening"
	var shown := ""
	if state == "open" or (bool(LOOKS[site.look].shows) and state in ["shut", "opening"]):
		shown = str(site.holds)
	_stock(site, shown)

func _tint(site: Dictionary, color: Color) -> void:
	(site.lamp as StandardMaterial3D).albedo_color = color

func _pose(site: Dictionary) -> void:
	var share := smoothstep(0.0, 1.0, float(site.swing))
	for door: Array in site.doors:
		(door[0] as Node3D).basis = Basis(door[1], float(door[2]) * share)

## The weapon that is seen in a cache ("" for none).
func _stock(site: Dictionary, id: String) -> void:
	if str(site.shown) == id:
		return
	site.shown = id
	var rack: Node3D = site.rack
	for child in rack.get_children():
		rack.remove_child(child)
		child.queue_free()
	(site.shine as OmniLight3D).visible = id != "" and Survivor.WEAPONS.has(id)
	if id == "" or not Survivor.WEAPONS.has(id):
		return
	var model := WeaponView.display(id)
	var size: Vector3 = model.get_meta("size", Vector3(0.1, 0.2, 0.8))
	var fit := minf(1.0, float(site.space) / maxf(0.1, size.z))
	match str(site.hang):
		"up":
			# The muzzle up, its side to whoever looks in.
			model.transform = Transform3D((Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, PI / 2)).scaled(Vector3.ONE * fit), Vector3(0, size.z * fit * 0.5, 0))
		"flat":
			# Lying on its side.
			model.transform = Transform3D((Basis(Vector3.UP, PI / 2) * Basis(Vector3.BACK, PI / 2)).scaled(Vector3.ONE * fit), Vector3(0, size.x * fit * 0.5, 0))
		_:
			# Across, on hooks.
			model.transform = Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * fit), Vector3.ZERO)
	rack.add_child(model)

## The tool at the lock of the sealed cache that is being opened right now (-1: none).
func _sound(index: int) -> void:
	if index == noisy:
		return
	if index < 0:
		_quiet()
		return
	noisy = index
	var site := sites[index]
	if noise == null:
		noise = AudioStreamPlayer3D.new()
		noise.name = "Tool"
		noise.stream = _grind()
		noise.unit_size = 9.0
		noise.max_distance = 70.0
		noise.volume_db = -5.0
		noise.bus = "Field" if AudioServer.get_bus_index("Field") >= 0 else "Master"
		add_child(noise)
		sparks = CPUParticles3D.new()
		sparks.name = "Sparks"
		sparks.amount = 18
		sparks.lifetime = 0.4
		sparks.explosiveness = 0.1
		sparks.direction = Vector3(0, 0.3, 1)
		sparks.spread = 38.0
		sparks.initial_velocity_min = 1.6
		sparks.initial_velocity_max = 3.6
		sparks.gravity = Vector3(0, -7.0, 0)
		var grain := BoxMesh.new()
		grain.size = Vector3(0.018, 0.018, 0.05)
		var fire := StandardMaterial3D.new()
		fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fire.albedo_color = Color(1.0, 0.72, 0.3)
		grain.material = fire
		sparks.mesh = grain
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sparks)
	noise.global_position = site.at
	sparks.global_transform = (site.node as Node3D).global_transform * Transform3D(Basis.IDENTITY, site.spark)
	sparks.emitting = true
	if not noise.playing:
		noise.play()

func _quiet() -> void:
	noisy = -1
	if noise != null:
		noise.stop()
		sparks.emitting = false

## What a tool at a lock sounds like: a motor that bites and lets go, a rattle, and the
## cache's own alarm - two seconds that go round.
static func _grind() -> AudioStreamWAV:
	if grind != null:
		return grind
	var rate := 22050
	var count := rate * 2
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for i in range(count):
		var t := float(i) / rate
		low = low * 0.8 + rng.randf_range(-1.0, 1.0) * 0.2
		var whine := fmod(t * 172.0, 1.0) * 2.0 - 1.0
		var bite := 0.55 + 0.45 * sin(t * TAU * 6.0)
		var beep := sin(t * TAU * 1480.0) * (1.0 if fmod(t, 0.5) < 0.09 else 0.0)
		data.encode_s16(i * 2, int(clampf((whine * 0.2 + low * 0.55) * bite + beep * 0.2, -1.0, 1.0) * 26000.0))
	grind = AudioStreamWAV.new()
	grind.format = AudioStreamWAV.FORMAT_16_BITS
	grind.mix_rate = rate
	grind.stereo = false
	grind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	grind.loop_begin = 0
	grind.loop_end = count
	grind.data = data
	return grind

# ---------------------------------------------------------------- hints on displays and terminals

## Finds the displays and the terminals of the map, once.
func _find_hints() -> void:
	if is_instance_valid(hints):
		for board in boards:
			board.read = false
		for screen in screens:
			screen.read = false
		return
	hints = Node3D.new()
	hints.name = "CacheHints"
	map.add_child(hints)
	boards.clear()
	screens.clear()
	# (Every display of the plan wears the plan's one material: that is what they are known by.)
	var glass: Variant = map.plan.get("material")
	for node in map.find_children("*", "MeshInstance3D", true, false):
		var pane := node as MeshInstance3D
		if pane.mesh == null or pane.mesh.get_surface_count() != 1 or pane.mesh.surface_get_material(0) != glass:
			continue
		var wide := maxf(1.0, pane.get_aabb().size.x)
		boards.append({"node": pane, "wide": wide, "at": pane.global_position, "reach": maxf(HINT_REACH, wide * 1.5), "group": part_of(pane.global_position), "read": false, "marks": null, "words": null})
	for place: Array in map.terminal_places:
		var room: Dictionary = map.room_of[str(place[0])]
		var line := Label3D.new()
		line.font_size = 32
		line.pixel_size = 0.0011
		line.outline_size = 8
		line.outline_modulate = Color(0, 0.03, 0.03, 0.95)
		line.modulate = MINT
		line.double_sided = false
		line.position = map._face_point(room, int(place[1]), float(place[2]), 1.475, 0.07)
		line.rotation.y = map._model_yaw(int(place[1]))
		line.visibility_range_end = 30.0
		hints.add_child(line)
		screens.append({"at": map._face_point(room, int(place[1]), float(place[2]), 0.0, -0.8), "line": line, "names": -1, "read": false})

## Writes tonight's caches on the displays and the terminals: a mark that beats on every
## cell of the plan that holds one, and on a terminal the name of the nearest.
func _post_hints() -> void:
	var by_cell: Dictionary = {}
	for site in sites:
		if _wanted(site) and str(site.cell) != "":
			by_cell[str(site.cell)] = int(by_cell.get(str(site.cell), 0)) + 1
	for board in boards:
		var pane: MeshInstance3D = board.node
		if not is_instance_valid(pane):
			continue
		if board.marks == null:
			var marks := MeshInstance3D.new()
			marks.name = "CacheMarks"
			marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marks.position = Vector3(0, 0, 0.004)
			# (Drawn after the plan it lies on: both are glass.)
			marks.sorting_offset = 1.0
			pane.add_child(marks)
			board.marks = marks
			var words := Label3D.new()
			words.text = "WAFFENLAGER"
			words.font_size = 32
			words.pixel_size = float(board.wide) * 0.00042
			words.modulate = MINT
			words.outline_size = 6
			words.outline_modulate = Color(0, 0.03, 0.03, 0.9)
			words.double_sided = false
			words.sorting_offset = 1.0
			words.render_priority = 1
			pane.add_child(words)
			board.words = words
		var wide := float(board.wide)
		var tall := wide * HiveDisplay.PLAN.y / HiveDisplay.PLAN.x
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var patch: Vector2 = HiveDisplay.PATCH.get_center() / Vector2(HiveDisplay.SHEET)
		var spots: Array = []
		for cell: String in by_cell:
			var entry: Array = HiveDisplay.CELLS[cell]
			spots.append([HiveDisplay.middle(int(entry[0]), int(entry[1])) + Vector2(0, -HiveDisplay.RADIUS * 0.62), 15.0, 0.25])
		if not spots.is_empty():
			# (What the mark means, in the row of the plan that explains its signs.)
			spots.append([Vector2(578, 836), 9.0, 1.0])
		for spot: Array in spots:
			var at: Vector2 = spot[0]
			var half := float(spot[1])
			for corner: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0)]:
				var point := at + corner * half
				vertices.append(Vector3((point.x / HiveDisplay.PLAN.x - 0.5) * wide, (0.5 - point.y / HiveDisplay.PLAN.y) * tall, 0))
				uvs.append(patch)
				colors.append(Color(0.25, 1.0, 0.6, float(spot[2])))
		var marks: MeshInstance3D = board.marks
		var words: Label3D = board.words
		words.visible = not spots.is_empty()
		words.position = Vector3((684.0 / HiveDisplay.PLAN.x - 0.5) * wide, (0.5 - 836.0 / HiveDisplay.PLAN.y) * tall, 0.006)
		if spots.is_empty():
			marks.mesh = null
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, map.plan.get("material"))
		marks.mesh = mesh
	for screen in screens:
		var at: Vector3 = screen.at
		var below := at.z < -200.0
		var best := -1
		var best_gap := 90.0
		for index in range(sites.size()):
			var site := sites[index]
			if not _wanted(site) or (int(site.level) >= map.deep) != below:
				continue
			var gap := at.distance_to(site.stand)
			if gap < best_gap:
				best_gap = gap
				best = index
		screen.names = best
		var line: Label3D = screen.line
		line.visible = best >= 0
		if best >= 0:
			line.text = "◆ WAFFENLAGER  ·  %s" % sites[best].title

# ---------------------------------------------------------------- building the places

## Builds the furniture of every place into a map that is being laid out (before it is
## compiled) and notes the places in HiveMap.caches. What stands still goes into the
## map's meshes and its path grid; what moves - doors, a lid, the lamp - is a node of the
## place's zone.
static func furnish(map: HiveMap) -> void:
	var kept_state := map.random.state
	var kept_batch: MeshBatch = map.batch
	for spec: Array in SITES:
		if not map.room_of.has(str(spec[1])) or not LOOKS.has(str(spec[4])):
			continue
		var room: Dictionary = map.room_of[str(spec[1])]
		var side: int = spec[2]
		var look: Dictionary = LOOKS[str(spec[4])]
		var into := Vector3(-HiveCore.OUT[side].x, 0, -HiveCore.OUT[side].y)
		# (Clear of what the walls wear: the wainscot of the villa's rooms, the panels below.)
		var gap := 0.13 if str(room.style) in ["wood", "hall"] else 0.065
		var frame := Transform3D(Basis(Vector3.UP.cross(into), Vector3.UP, into), map._face_point(room, side, float(spec[3]), 0.0, -gap))
		var size: Vector3 = look.size
		var site := {
			"id": str(spec[0]), "room": str(spec[1]), "look": str(spec[4]), "title": str(spec[5]), "depth": int(spec[6]), "group": str(spec[7]), "cell": str(spec[8]),
			"sealed": bool(look.sealed), "level": int(room.level), "zone": str(room.zone), "area": str(room.area), "frame": frame,
			"at": frame * Vector3(0, minf(size.y, 1.5) * 0.7, size.z * 0.5), "stand": frame * Vector3(0, 0, size.z + 0.75),
			"side": side, "doors": [], "tool": null, "hang": "up", "space": 1.4, "spark": Vector3(0, 1.0, size.z),
			"state": "none", "holds": "", "record": {}, "left": 0.0, "known": false, "near": false, "answer": 0.0, "swing": 1.0, "swing_to": 1.0, "shown": ""
		}
		map._begin_zone(str(room.zone))
		map._chunk("Caches", false)
		var node := Node3D.new()
		node.name = "Cache_" + str(spec[0])
		node.transform = frame
		map.add_child(node)
		site.node = node
		var rack := Node3D.new()
		rack.name = "Rack"
		node.add_child(rack)
		site.rack = rack
		var lamp := StandardMaterial3D.new()
		lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp.albedo_color = Color(0.05, 0.055, 0.06)
		site.lamp = lamp
		_build(map, site)
		var tag := Label3D.new()
		tag.name = "Tag"
		tag.text = str(look.word)
		tag.font_size = 34
		tag.pixel_size = 0.0034
		tag.outline_size = 8
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.double_sided = false
		tag.position = Vector3(0, size.y + 0.17, size.z * 0.5)
		tag.visibility_range_end = 26.0
		tag.hide()
		node.add_child(tag)
		site.tag = tag
		var glow := OmniLight3D.new()
		glow.name = "Glow"
		glow.position = Vector3(0, minf(size.y + 0.35, 2.2), size.z + 0.5)
		glow.light_energy = 0.55
		glow.omni_range = 3.4
		glow.omni_attenuation = 1.4
		glow.shadow_enabled = false
		glow.light_volumetric_fog_energy = 0.2
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = 30.0
		glow.distance_fade_length = 8.0
		glow.hide()
		node.add_child(glow)
		site.glow = glow
		# What lights the weapon in it, once it can be seen.
		var shine := OmniLight3D.new()
		shine.name = "Shine"
		shine.light_color = Color(1.0, 0.95, 0.86)
		shine.light_energy = 1.2
		shine.omni_range = 1.8
		shine.shadow_enabled = false
		shine.light_volumetric_fog_energy = 0.0
		shine.distance_fade_enabled = true
		shine.distance_fade_begin = 22.0
		shine.distance_fade_length = 6.0
		shine.position = rack.position + {"up": Vector3(0, 0.9, 0.32), "flat": Vector3(0, 0.5, 0.1), "side": Vector3(0, 0.25, 0.4)}[str(site.hang)]
		shine.hide()
		node.add_child(shine)
		site.shine = shine
		var yaw := atan2(-frame.basis.x.z, frame.basis.x.x)
		map._solid(frame * Vector3(0, size.y * 0.5, (size.z + (0.22 if str(spec[4]) == "kiste" else 0.0)) * 0.5), Vector3(size.x, size.y, size.z - (0.22 if str(spec[4]) == "kiste" else 0.0)), true, yaw)
		map._end_zone()
		map.caches.append(site)
	map.batch = kept_batch
	map.random.state = kept_state

## A part of a place that moves: boxes ([material, middle, size, colour], around `pivot`)
## as one node that turns about `axis` by `angle` when the place is open.
static func _leaf(map: HiveMap, site: Dictionary, pivot: Vector3, boxes: Array, axis: Vector3, angle: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Leaf"
	node.position = pivot
	(site.node as Node3D).add_child(node)
	var pieces := MeshBatch.new()
	for entry: Array in boxes:
		pieces.box(map.mats[str(entry[0])], entry[1], entry[2], entry[3])
	pieces.commit(node, "Leaf", false)
	if axis != Vector3.ZERO:
		(site.doors as Array).append([node, axis, angle])
	return node

## The lamp of a place: a small bar of light whose colour says what state it is in.
static func _lamp(site: Dictionary, parent: Node3D, at: Vector3, size: Vector3) -> void:
	var bar := MeshInstance3D.new()
	bar.name = "Lamp"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = site.lamp
	bar.mesh = mesh
	bar.position = at
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bar)

## The tool that hangs at a sealed lock while it is being opened: a yellow box with a
## dark head, hidden otherwise.
static func _tool(map: HiveMap, site: Dictionary, parent: Node3D, at: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Tool"
	node.position = at
	parent.add_child(node)
	var pieces := MeshBatch.new()
	pieces.box(map.mats["steel"], Vector3(0, 0, 0.06), Vector3(0.16, 0.12, 0.12), Color("c79a1c"))
	pieces.box(map.mats["plain"], Vector3(0, 0, 0.0), Vector3(0.07, 0.07, 0.04), Color("17191b"))
	pieces.box(map.mats["plain"], Vector3(0, -0.13, 0.07), Vector3(0.05, 0.16, 0.05), Color("17191b"))
	pieces.commit(node, "Tool", false)
	node.hide()
	site.tool = node

static func _build(map: HiveMap, site: Dictionary) -> void:
	var frame: Transform3D = site.frame
	var node: Node3D = site.node
	var rack: Node3D = site.rack
	var put := func(material: String, at: Vector3, size: Vector3, color: Color) -> void:
		map._placed(frame, material, at, size, color)
	match str(site.look):
		"spind":
			var steel := Color("46525c")
			var dark := Color("23282c")
			put.call("steel", Vector3(0, 0.95, 0.03), Vector3(1.2, 1.9, 0.02), steel)
			for edge: float in [-1.0, 1.0]:
				put.call("steel", Vector3(edge * 0.59, 0.95, 0.29), Vector3(0.02, 1.9, 0.5), steel)
				put.call("steel", Vector3(edge * 0.295, 1.62, 0.28), Vector3(0.56, 0.016, 0.44), dark)
			put.call("steel", Vector3(0, 1.908, 0.29), Vector3(1.22, 0.02, 0.52), steel)
			put.call("steel", Vector3(0, 0.05, 0.28), Vector3(1.14, 0.1, 0.46), dark)
			put.call("steel", Vector3(0, 0.99, 0.28), Vector3(0.02, 1.78, 0.46), dark)
			put.call("steel", Vector3(0, 0.108, 0.28), Vector3(1.14, 0.016, 0.46), dark)
			for edge: float in [-1.0, 1.0]:
				var boxes := [
					["steel", Vector3(-edge * 0.29, 0, 0), Vector3(0.575, 1.76, 0.018), steel],
					["plain", Vector3(-edge * 0.52, 0, 0.02), Vector3(0.02, 0.13, 0.02), Color("9aa4ab")],
					["plain", Vector3(-edge * 0.29, 0.43, 0.011), Vector3(0.13, 0.05, 0.004), Color("d8d6c8")]
				]
				for slit in range(4):
					boxes.append(["plain", Vector3(-edge * 0.29, 0.62 + slit * 0.045, 0.011), Vector3(0.3, 0.012, 0.004), dark])
				_leaf(map, site, Vector3(edge * 0.58, 1.0, 0.55), boxes, Vector3.UP, edge * 1.9)
			_lamp(site, node, Vector3(0, 1.94, 0.5), Vector3(0.22, 0.03, 0.03))
			rack.position = Vector3(0.295, 0.13, 0.27)
			site.space = 1.42
		"kiste":
			var olive := Color("4d563a")
			var dark := Color("1b1e1a")
			for edge: float in [-1.0, 1.0]:
				put.call("panelwood", Vector3(edge * 0.5, 0.05, 0.54), Vector3(0.14, 0.1, 0.62), Color("4a3b2a"))
				put.call("steel", Vector3(edge * 0.735, 0.29, 0.54), Vector3(0.03, 0.3, 0.56), olive)
				put.call("plain", Vector3(edge * 0.45, 0.29, 0.858), Vector3(0.06, 0.3, 0.008), dark)
			put.call("steel", Vector3(0, 0.12, 0.54), Vector3(1.5, 0.04, 0.62), olive)
			put.call("steel", Vector3(0, 0.29, 0.837), Vector3(1.5, 0.3, 0.03), olive)
			put.call("steel", Vector3(0, 0.29, 0.243), Vector3(1.5, 0.3, 0.03), olive)
			put.call("plain", Vector3(0, 0.22, 0.54), Vector3(1.43, 0.16, 0.55), Color("15181a"))
			var lid := [["steel", Vector3(0, 0.022, 0.31), Vector3(1.52, 0.04, 0.64), olive]]
			for edge: float in [-1.0, 1.0]:
				lid.append(["plain", Vector3(edge * 0.45, 0.045, 0.31), Vector3(0.06, 0.008, 0.64), dark])
				lid.append(["plain", Vector3(edge * 0.45, -0.04, 0.637), Vector3(0.07, 0.1, 0.012), Color("8a8f86")])
			_leaf(map, site, Vector3(0, 0.44, 0.228), lid, Vector3.RIGHT, -1.75)
			_lamp(site, node, Vector3(0, 0.39, 0.858), Vector3(0.3, 0.025, 0.012))
			var stencil := Label3D.new()
			stencil.text = "HELIX  ·  WAFFEN"
			stencil.font_size = 30
			stencil.pixel_size = 0.0028
			stencil.modulate = Color(0.86, 0.82, 0.6)
			stencil.outline_size = 0
			stencil.double_sided = false
			stencil.position = Vector3(0, 0.26, 0.856)
			stencil.visibility_range_end = 18.0
			node.add_child(stencil)
			rack.position = Vector3(0, 0.3, 0.54)
			site.hang = "flat"
			site.space = 1.36
			site.spark = Vector3(0, 0.44, 0.86)
		"schrank":
			var wood := Color("3b2a1d")
			var pale := Color("5c4431")
			put.call("panelwood", Vector3(0, 1.05, 0.02), Vector3(1.3, 2.1, 0.03), wood)
			for edge: float in [-1.0, 1.0]:
				put.call("panelwood", Vector3(edge * 0.635, 1.05, 0.25), Vector3(0.03, 2.1, 0.43), wood)
			put.call("panelwood", Vector3(0, 2.135, 0.27), Vector3(1.4, 0.07, 0.54), pale)
			put.call("panelwood", Vector3(0, 0.1, 0.25), Vector3(1.24, 0.2, 0.43), wood)
			put.call("panelwood", Vector3(0, 0.03, 0.27), Vector3(1.36, 0.06, 0.5), pale)
			put.call("velvet", Vector3(0, 1.14, 0.042), Vector3(1.22, 1.84, 0.012), Color("1e3a2b"))
			put.call("panelwood", Vector3(0, 0.66, 0.11), Vector3(1.2, 0.04, 0.1), pale)
			for edge: float in [-1.0, 1.0]:
				_leaf(map, site, Vector3(edge * 0.625, 1.14, 0.485), [
					["panelwood", Vector3(-edge * 0.31, 0, 0), Vector3(0.615, 1.84, 0.03), wood],
					["panelwood", Vector3(-edge * 0.31, 0.38, 0.018), Vector3(0.45, 0.9, 0.012), pale],
					["panelwood", Vector3(-edge * 0.31, -0.57, 0.018), Vector3(0.45, 0.52, 0.012), pale],
					["plain", Vector3(-edge * 0.565, -0.06, 0.035), Vector3(0.035, 0.035, 0.04), Color("b08a3c")]
				], Vector3.UP, edge * 1.85)
			# (The seal over the seam of its doors.)
			_lamp(site, node, Vector3(0, 1.2, 0.512), Vector3(0.07, 0.07, 0.016))
			rack.position = Vector3(0, 0.22, 0.2)
			site.space = 1.75
			site.spark = Vector3(0, 1.1, 0.52)
		"tresor":
			var body := Color("262b30")
			var face := Color("30363c")
			put.call("steel", Vector3(0, 0.85, 0.045), Vector3(1.1, 1.7, 0.07), body)
			for edge: float in [-1.0, 1.0]:
				put.call("steel", Vector3(edge * 0.51, 0.85, 0.4), Vector3(0.08, 1.7, 0.64), body)
			put.call("steel", Vector3(0, 1.664, 0.4), Vector3(0.94, 0.08, 0.64), body)
			put.call("steel", Vector3(0, 0.07, 0.4), Vector3(0.94, 0.14, 0.64), body)
			put.call("plain", Vector3(0, 0.88, 0.086), Vector3(0.94, 1.48, 0.01), Color("3a4046"))
			var door := _leaf(map, site, Vector3(-0.47, 0.88, 0.72), [
				["steel", Vector3(0.47, 0, 0.03), Vector3(0.94, 1.48, 0.07), face],
				["steel", Vector3(0.47, 0, 0.07), Vector3(0.8, 1.34, 0.012), body],
				["plain", Vector3(0.44, 0.25, 0.1), Vector3(0.32, 0.035, 0.03), Color("9aa4ab")],
				["plain", Vector3(0.44, 0.25, 0.1), Vector3(0.035, 0.32, 0.028), Color("9aa4ab")],
				["plain", Vector3(0.44, 0.25, 0.085), Vector3(0.16, 0.16, 0.02), Color("15171a")],
				["plain", Vector3(0.74, 0.25, 0.082), Vector3(0.13, 0.2, 0.014), Color("0e1012")],
				["steel", Vector3(0.0, 0.5, 0.03), Vector3(0.05, 0.18, 0.1), body],
				["steel", Vector3(0.0, -0.5, 0.03), Vector3(0.05, 0.18, 0.1), body]
			], Vector3.UP, -1.75)
			_lamp(site, door, Vector3(0.74, 0.37, 0.092), Vector3(0.09, 0.03, 0.01))
			_tool(map, site, door, Vector3(0.6, -0.08, 0.08))
			rack.position = Vector3(0.06, 0.15, 0.36)
			site.space = 1.42
			site.spark = Vector3(0.13, 0.8, 0.86)
		"kaefig":
			var post := Color("2e353a")
			var bar := Color("3d464c")
			for edge: float in [-1.0, 1.0]:
				for deep_at: float in [0.045, 0.845]:
					put.call("steel", Vector3(edge * 0.775, 1.05, deep_at), Vector3(0.05, 2.1, 0.05), post)
				put.call("steel", Vector3(edge * 0.775, 2.077, 0.445), Vector3(0.046, 0.046, 0.75), post)
				put.call("steel", Vector3(edge * 0.775, 0.04, 0.445), Vector3(0.046, 0.08, 0.75), post)
				put.call("steel", Vector3(edge * 0.775, 1.05, 0.445), Vector3(0.02, 0.04, 0.75), bar)
				for deep_at: float in [0.17, 0.31, 0.445, 0.58, 0.72]:
					put.call("steel", Vector3(edge * 0.775, 1.05, deep_at), Vector3(0.016, 2.0, 0.016), bar)
				put.call("steel", Vector3(edge * 0.35, 1.25, 0.08), Vector3(0.03, 0.03, 0.1), bar)
			for deep_at: float in [0.045, 0.845]:
				put.call("steel", Vector3(0, 2.077, deep_at), Vector3(1.5, 0.046, 0.046), post)
			put.call("steel", Vector3(0, 0.04, 0.045), Vector3(1.5, 0.08, 0.046), post)
			put.call("steel", Vector3(-0.4, 0.04, 0.845), Vector3(0.7, 0.08, 0.046), post)
			put.call("plate", Vector3(0, 2.108, 0.445), Vector3(1.6, 0.012, 0.85), Color("1d2124"))
			put.call("plate", Vector3(0, 1.1, 0.028), Vector3(1.5, 1.9, 0.012), Color("1d2124"))
			put.call("steel", Vector3(-0.02, 1.05, 0.845), Vector3(0.04, 2.0, 0.04), post)
			put.call("steel", Vector3(-0.385, 1.05, 0.845), Vector3(0.69, 0.04, 0.02), bar)
			for along: float in [-0.63, -0.5, -0.37, -0.24, -0.12]:
				put.call("steel", Vector3(along, 1.05, 0.845), Vector3(0.016, 2.0, 0.016), bar)
			put.call("steel", Vector3(-0.42, 0.5, 0.33), Vector3(0.62, 0.03, 0.45), bar)
			put.call("steel", Vector3(-0.56, 0.6, 0.33), Vector3(0.2, 0.17, 0.3), Color("4d563a"))
			put.call("steel", Vector3(-0.3, 0.58, 0.33), Vector3(0.2, 0.13, 0.3), Color("3f4a36"))
			var boxes := [
				["steel", Vector3(-0.37, 0.98, 0), Vector3(0.74, 0.04, 0.03), post],
				["steel", Vector3(-0.37, -0.98, 0), Vector3(0.74, 0.04, 0.03), post],
				["steel", Vector3(-0.015, 0, 0), Vector3(0.03, 1.92, 0.03), post],
				["steel", Vector3(-0.725, 0, 0), Vector3(0.03, 1.92, 0.03), post],
				["steel", Vector3(-0.37, 0.02, 0), Vector3(0.68, 0.04, 0.02), bar],
				["plain", Vector3(-0.69, 0, 0.035), Vector3(0.11, 0.17, 0.05), Color("15171a")],
				["plain", Vector3(-0.69, -0.15, 0.04), Vector3(0.07, 0.09, 0.03), Color("b08a3c")]
			]
			for along: float in [-0.13, -0.25, -0.37, -0.49, -0.61]:
				boxes.append(["steel", Vector3(along, 0, 0), Vector3(0.016, 1.92, 0.016), bar])
			var door := _leaf(map, site, Vector3(0.75, 1.05, 0.845), boxes, Vector3.UP, 1.85)
			_lamp(site, door, Vector3(-0.69, 0.12, 0.062), Vector3(0.07, 0.025, 0.012))
			_tool(map, site, door, Vector3(-0.69, -0.02, 0.07))
			rack.position = Vector3(0.05, 1.32, 0.16)
			site.hang = "side"
			site.space = 1.4
			site.spark = Vector3(0.06, 1.0, 0.95)
		"schleuse":
			var shell := Color("c2ccca")
			var dark := Color("1f2a2a")
			put.call("steel", Vector3(0, 1.0, 0.035), Vector3(1.2, 2.0, 0.05), shell)
			for edge: float in [-1.0, 1.0]:
				put.call("steel", Vector3(edge * 0.56, 1.0, 0.39), Vector3(0.08, 2.0, 0.66), shell)
			put.call("steel", Vector3(0, 1.9, 0.39), Vector3(1.04, 0.2, 0.66), shell)
			put.call("steel", Vector3(0, 0.09, 0.39), Vector3(1.04, 0.18, 0.66), dark)
			put.call("plain", Vector3(0, 0.99, 0.066), Vector3(1.04, 1.62, 0.01), Color("0e1414"))
			put.call("plain", Vector3(0, 1.79, 0.727), Vector3(1.04, 0.035, 0.012), Color("d6b21e"))
			put.call("plain", Vector3(0, 0.19, 0.727), Vector3(1.04, 0.035, 0.012), Color("d6b21e"))
			var door := _leaf(map, site, Vector3(0.52, 0.99, 0.72), [
				["steel", Vector3(-0.52, 0, 0), Vector3(1.03, 1.56, 0.06), shell],
				["plain", Vector3(-0.52, 0.36, 0.034), Vector3(0.5, 0.4, 0.008), Color("0b1a1c")],
				["plain", Vector3(-0.52, -0.3, 0.033), Vector3(1.03, 0.08, 0.006), Color("2f8f8a")],
				["plain", Vector3(-0.95, 0, 0.06), Vector3(0.04, 0.5, 0.04), Color("8d979c")]
			], Vector3.UP, 1.75)
			var words := Label3D.new()
			words.text = "EINDÄMMUNG  ·  KLASSE 3"
			words.font_size = 30
			words.pixel_size = 0.0019
			words.modulate = Color("16302f")
			words.outline_size = 0
			words.double_sided = false
			words.position = Vector3(-0.52, -0.06, 0.036)
			words.visibility_range_end = 16.0
			door.add_child(words)
			_lamp(site, node, Vector3(0, 1.9, 0.727), Vector3(0.7, 0.05, 0.012))
			_tool(map, site, door, Vector3(-0.88, -0.4, 0.05))
			rack.position = Vector3(-0.05, 0.2, 0.37)
			site.space = 1.5
			site.spark = Vector3(-0.4, 0.6, 0.86)

# ---------------------------------------------------------------- pictures

## For the pictures and the checks: every place holds something, as a night could deal
## it at the most (`weapons`: place -> weapon instead of what the depth would give).
func fill_all(weapons: Dictionary = {}) -> void:
	var pool := found_only()
	for index in range(sites.size()):
		var site := sites[index]
		var window: Array = (SEALED_WORTH if bool(site.sealed) else PLAIN_WORTH)[clampi(int(site.depth), 0, 3)]
		var pick := str(weapons.get(str(site.id), ""))
		for id in pool:
			var worth := int(Survivor.WEAPONS[id].price)
			if pick == "" and worth >= int(window[0]) and worth <= int(window[1]) and (index + pool.find(id)) % 2 == 0:
				pick = id
		site.holds = pick if pick != "" else "p90"
		site.state = "shut"
		site.record = {}
		site.left = _seconds(site)
		site.known = false
		site.near = false
		_show(index, true)
	_post_hints()

func _index_of(id: String) -> int:
	for index in range(sites.size()):
		if str(sites[index].id) == id:
			return index
	return -1

## --caches-check: every place as it stands when it holds something (cache_<nn>_<name>),
## one of each look open with its weapon (look_...), a sealed one being opened with what
## comes for it (seal_...), the side goal on the HUD and on the map in the corner, a
## display and a terminal that tell of caches, and the lockers' short list.
## --caches-part=<text>[,<more>]: only the places whose name contains one of them.
func _pictures() -> void:
	var folder: String = game._capture_dir()
	var part := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--caches-part="):
			part = arg.trim_prefix("--caches-part=")
	await get_tree().create_timer(1.0).timeout
	game.profile.mission = 2
	game.intro_skipped = true
	game.start_run()
	director.set_process(false)
	director.prowl.set_process(false)
	for node in game.enemies.get_children():
		node.queue_free()
	game.alive_count = 0
	for id in map.areas:
		map.unlock(str(id), true)
	for mate in game.team:
		mate.hide()
		mate.set_physics_process(false)
		mate.global_position = Vector3(0, 0.05, 80)
	if is_instance_valid(director.nadja):
		director.nadja.hide()
		director.nadja.set_physics_process(false)
		director.nadja.global_position = Vector3(2, 0.05, 80)
	if is_instance_valid(director.heli):
		director.heli.hide()
	director._end_intro()
	await get_tree().create_timer(1.2).timeout
	fill_all({"depot": "mg", "server": "minigun", "archiv": "svd", "labor_a": "launcher", "salon": "shotgun", "werkstatt": "mp7", "depot_kiste": "m14"})
	set_process(false)
	game.hud.play_ui.hide()
	for index in range(sites.size()):
		var site := sites[index]
		print("CACHE %d %s look=%s room=%s at=%s stand=%s holds=%s" % [index, site.id, site.look, site.room, str((site.at as Vector3).snappedf(0.01)), str((site.stand as Vector3).snappedf(0.01)), site.holds])
		var asked := part == ""
		for text in part.split(",", false):
			asked = asked or str(site.id).contains(text)
		if not asked:
			continue
		var frame: Transform3D = site.frame
		# From before it, a little to the side - or, where no ground is there (a gallery),
		# from the way that leads to it, a few steps before it.
		var from: Vector3 = frame * Vector3(1.5, 0, 3.9)
		var cell := Vector2i(roundi(from.x / CabinMap.CELL), roundi(from.z / CabinMap.CELL))
		var grid: AStarGrid2D = map.navigation[int(site.level)]
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell) or str(map.room_at(from + Vector3(0, 0.3, 0)).get("id", "")) != str(site.room):
			var anchor: Vector3 = map.points.terminal if int(site.level) >= map.deep else (map.points.platform if int(site.level) == map.under else map.points.hall)
			var path := map.path_between(anchor, site.stand)
			var walked := 0.0
			for k in range(path.size() - 1, 0, -1):
				walked += path[k].distance_to(path[k - 1])
				if walked >= 3.8:
					from = path[k - 1]
					break
		await game._shot_at(folder, "cache_%02d_%s.png" % [index, site.id], from, site.at, 0.45)
	if part == "":
		# One of each look, open, with what it holds.
		for id: String in ["werkstatt", "depot_kiste", "salon", "archiv", "server", "labor_a"]:
			var index := _index_of(id)
			var site := sites[index]
			site.state = "open"
			_show(index, true)
			var frame: Transform3D = site.frame
			await game._shot_at(folder, "look_%s_%s.png" % [site.look, id], frame * Vector3(0.9, 0, 2.7), site.at, 0.5)
		# A sealed one being opened, with the HUD: the start, the middle with those who
		# come for it, the pause when the survivor walks off, and what it gives.
		game.hud.play_ui.show()
		set_process(true)
		var cage := _index_of("depot")
		var site := sites[cage]
		site.known = true
		var frame: Transform3D = site.frame
		game._place_player(frame * Vector3(0.5, 0.05, 2.4), 0.0)
		var line: Vector3 = (site.at as Vector3) - (game.player.global_position + Vector3(0, 1.6, 0))
		game.player.rotation.y = atan2(-line.x, -line.z)
		game.player.camera.rotation.x = -0.12
		await get_tree().create_timer(0.5).timeout
		await game._capture(folder, "seal_1_prompt.png")
		use()
		await get_tree().create_timer(5.0).timeout
		game.hud.banner_left = 0
		await game._capture(folder, "seal_2_opening.png")
		game.player.rotation.y += PI * 0.75
		await get_tree().create_timer(2.6).timeout
		await game._capture(folder, "seal_3_answer.png")
		print("CACHES answered=%d alive=%d" % [answered, game.alive_count])
		for node in game.enemies.get_children():
			node.queue_free()
		game.alive_count = 0
		game._place_player(frame * Vector3(0.5, 0.05, 9.5), 0.0)
		line = (site.at as Vector3) - (game.player.global_position + Vector3(0, 1.6, 0))
		game.player.rotation.y = atan2(-line.x, -line.z)
		await get_tree().create_timer(0.8).timeout
		for node in game.enemies.get_children():
			node.queue_free()
		game.alive_count = 0
		game.hud.banner_left = 0
		await game._capture(folder, "seal_4_paused.png")
		site.left = 0.4
		site.answer = 99.0
		game._place_player(frame * Vector3(0.5, 0.05, 2.4), 0.0)
		game.player.rotation.y = atan2(-line.x, -line.z)
		game.player.camera.rotation.x = -0.1
		await get_tree().create_timer(2.4).timeout
		for node in game.enemies.get_children():
			node.queue_free()
		game.alive_count = 0
		await game._capture(folder, "seal_5_open.png")
		use()
		await get_tree().create_timer(0.8).timeout
		await game._capture(folder, "seal_6_taken.png")
		# The side goal: a cache the survivor has come near, on the HUD and on the map.
		game.hud.banner_left = 0
		var side := sites[_index_of("werkstatt")]
		side.state = "shut"
		_show(_index_of("werkstatt"), true)
		frame = side.frame
		game._place_player(frame * Vector3(4.5, 0.05, 6.0), 0.0)
		line = (side.at as Vector3) - (game.player.global_position + Vector3(0, 1.6, 0))
		game.player.rotation.y = atan2(-line.x, -line.z) + 0.5
		await get_tree().create_timer(1.0).timeout
		await game._capture(folder, "goal_1_near.png")
		game.hud.banner_left = 0
		await get_tree().create_timer(0.3).timeout
		await game._capture(folder, "goal_2_hud.png")
		# A display that tells of them, and a terminal.
		for board in boards:
			board.read = false
		for wanted: String in ["station", "admin", "core"]:
			for board in boards:
				if str(board.group) != wanted or bool(board.read):
					continue
				var pane: MeshInstance3D = board.node
				var from: Vector3 = pane.global_position + pane.global_basis.z * (float(board.wide) * 0.95 + 0.6)
				from.y = HiveMap.UNDER
				await game._shot_at(folder, "hint_display_%s.png" % wanted, from, pane.global_position, 1.2, false)
				break
		if not screens.is_empty():
			var screen := screens[mini(3, screens.size() - 1)]
			var label: Label3D = screen.line
			await game._shot_at(folder, "hint_terminal.png", (screen.at as Vector3) + label.global_basis.z * 0.5, label.global_position + Vector3(0, 0.2, 0), 1.2, false)
		# The lockers' short list.
		game.credits = 2000
		game.wave = 6
		var locker: Vector3 = map.points.supply_station
		for station in map.stations:
			if str(station.kind) == "shop" and (station.pos as Vector3).distance_to(locker) < 12.0:
				game._place_player((station.view.position as Vector3) - Vector3(0, 1.5, 0), 0.0)
		await get_tree().create_timer(0.4).timeout
		game.open_shop()
		for tab: String in ["weapons", "heavy"]:
			game.hud._open_tab(tab)
			await get_tree().create_timer(0.6).timeout
			await game._capture(folder, "shop_%s.png" % tab)
	print("CACHES_CHECK COMPLETE sites=%d" % sites.size())
	get_tree().quit()
