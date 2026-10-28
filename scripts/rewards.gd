class_name Rewards
extends RefCounted
## Crates and what comes out of them (v0.79). Every won mission gives a crate; it is
## opened in the menu (KISTEN) and gives one thing for 1, 3 or 7 days: a weapon skin
## (WeaponSkins) or a piece of gear. What is held lies in the locker (SPIND): a skin is put
## on its weapon there, and what is ticked to come along is what the survivor starts the
## next mission with (equip). The same thing won again adds its days.
## Stored apart from the profile, as JSON in user://nachtwache_rewards.json. In a co-op
## match each player has his own crates and his own locker.

const PATH := "user://nachtwache_rewards.json"
const DAY := 86400
## How long a prize lasts, and how often each comes: [days, weight].
const DURATIONS := [[1, 62], [3, 28], [7, 10]]
## The weapons skins come for: the two every survivor starts with, and the favourites.
const SKIN_WEAPONS := ["rifle", "pistol", "ak", "p90", "ump", "g36", "mp7", "shotgun", "deagle"]
## How often a crate gives each skin, and gear: weights.
const SKIN_WEIGHTS := {"tiefsee": 34, "orbital": 22, "drache": 12, "mondnacht": 6}
const GEAR_WEIGHT := 32
## Gear. icon: the symbol (ShopIcons/UiSymbols). model: what is shown once it exists.
const GEAR := {
	"gasmaske": {"label": "GASMASKE", "icon": "mask", "model": "res://assets/models/gasmaske.glb",
		"note": "Du startest mit Gasmaske (Stufe 2). Ihr Filter hält 50 % länger – auch nach jedem Kauf im Laden."},
	"medpack": {"label": "MEDPACK", "icon": "heal",
		"note": "Zwei Medpacks zum Hinlegen (Taste K): Alle 2 Sekunden heilt es jeden in der Nähe, bis sein Vorrat aufgebraucht ist – dann zerplatzt es."},
	"rucksack": {"label": "RUCKSACK", "icon": "gear",
		"note": "Ein Waffenplatz mehr für jede Art: Du kannst zwei Waffen aus dem Spind mitnehmen und Funde aufheben, ohne etwas fallen zu lassen."}
}
## The filter of the crate's mask lasts this much longer (Survivor.filter_capacity).
const MASK_BONUS := 0.5
const MASK_LEVEL := 2
const MEDPACKS := 2
## Weapons from the locker a survivor may take along: one, two with the backpack.
const WEAPON_SLOTS := 1
## Every survivor starts with these anyway: their skins need no place, only to be put on.
const START := ["rifle", "pistol"]

var stored := true
var crates := 0
## Crates opened in all.
var opened := 0
## What is held: item -> until when (unix seconds). Items: "<skin>/<weapon>" or a gear id.
var owned: Dictionary = {}
## Weapon -> the skin it wears.
var worn: Dictionary = {}
## Items ticked to come along.
var taken: Array = []
## Seconds added to the clock (the checks let days pass with it).
var clock_shift := 0

func now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_shift

func open() -> void:
	if not stored or not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		read(parsed)

func read(parsed: Dictionary) -> void:
	crates = maxi(0, int(parsed.get("crates", 0)))
	opened = maxi(0, int(parsed.get("opened", 0)))
	owned.clear()
	if parsed.get("owned") is Dictionary:
		for id: String in parsed.owned:
			if known(id):
				owned[id] = int(parsed.owned[id])
	worn.clear()
	if parsed.get("worn") is Dictionary:
		for weapon: String in parsed.worn:
			if WeaponSkins.SKINS.has(str(parsed.worn[weapon])) and weapon in SKIN_WEAPONS:
				worn[weapon] = str(parsed.worn[weapon])
	taken.clear()
	if parsed.get("taken") is Array:
		for id in parsed.taken:
			if known(str(id)) and not taken.has(str(id)):
				taken.append(str(id))
	prune()

func save() -> void:
	if not stored:
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"crates": crates, "opened": opened, "owned": owned, "worn": worn, "taken": taken}, "\t"))

# ---------------------------------------------------------------- items

static func known(id: String) -> bool:
	if GEAR.has(id):
		return true
	var parts := id.split("/")
	return parts.size() == 2 and WeaponSkins.SKINS.has(parts[0]) and parts[1] in WeaponSkins.SKINS[parts[0]].get("weapons", SKIN_WEAPONS)

static func skin_of(id: String) -> String:
	return id.split("/")[0] if "/" in id else ""

static func weapon_of(id: String) -> String:
	return id.split("/")[1] if "/" in id else ""

static func rarity(id: String) -> String:
	return str(WeaponSkins.SKINS[skin_of(id)].rarity) if "/" in id else "gear"

static func title(id: String) -> String:
	if GEAR.has(id):
		return str(GEAR[id].label)
	return "%s  |  %s" % [Survivor.WEAPONS[weapon_of(id)].label, WeaponSkins.SKINS[skin_of(id)].label]

static func note(id: String) -> String:
	if GEAR.has(id):
		return str(GEAR[id].note)
	return "%s  %s" % [WeaponSkins.SKINS[skin_of(id)].note, WeaponSkins.boost_words(skin_of(id))]

## Seconds an item still lasts (0 when it is not held or has run out).
func left(id: String) -> int:
	return maxi(0, int(owned.get(id, 0)) - now())

func holds(id: String) -> bool:
	return left(id) > 0

## How long is left, in words: "2 T 5 Std", "3 Std 10 Min".
func left_words(id: String) -> String:
	var seconds := left(id)
	if seconds <= 0:
		return "abgelaufen"
	var days := seconds / DAY
	var hours := (seconds % DAY) / 3600
	if days > 0:
		return "%d T %d Std" % [days, hours]
	return "%d Std %d Min" % [hours, (seconds % 3600) / 60]

## Forgets what has run out.
func prune() -> void:
	for id: String in owned.keys():
		if not holds(id):
			owned.erase(id)
	for weapon: String in worn.keys():
		if not holds("%s/%s" % [worn[weapon], weapon]):
			worn.erase(weapon)
	taken = taken.filter(func(id: Variant) -> bool: return holds(str(id)) and not weapon_of(str(id)) in START)
	if taken.filter(func(id: Variant) -> bool: return "/" in str(id)).size() > weapon_slots():
		_trim_weapons()

## Gives an item for `days` (more days if it is held already). A new skin goes on its
## weapon at once if that weapon wears none; new gear and the first weapon come along.
func add(id: String, days: int) -> void:
	if not known(id):
		return
	var fresh := not holds(id)
	owned[id] = maxi(now(), int(owned.get(id, 0))) + days * DAY
	if fresh:
		if "/" in id and not worn.has(weapon_of(id)):
			worn[weapon_of(id)] = skin_of(id)
		if GEAR.has(id) and not taken.has(id):
			taken.append(id)
	save()

# ---------------------------------------------------------------- crates

func grant_crate() -> void:
	crates += 1
	save()

## Everything a crate can give, as [item, weight] (a skin's weight is shared by its weapons).
static func pool() -> Array:
	var out: Array = []
	for skin: String in SKIN_WEIGHTS:
		var weapons: Array = WeaponSkins.SKINS[skin].get("weapons", SKIN_WEAPONS)
		for weapon: String in weapons:
			out.append(["%s/%s" % [skin, weapon], float(SKIN_WEIGHTS[skin]) / weapons.size()])
	for id: String in GEAR:
		out.append([id, float(GEAR_WEIGHT) / GEAR.size()])
	return out

static func draw(rng: RandomNumberGenerator) -> Dictionary:
	var entries := pool()
	var total := 0.0
	for entry: Array in entries:
		total += float(entry[1])
	var pick := rng.randf() * total
	var id := str(entries[entries.size() - 1][0])
	for entry: Array in entries:
		pick -= float(entry[1])
		if pick <= 0.0:
			id = str(entry[0])
			break
	var weight := 0
	for step: Array in DURATIONS:
		weight += int(step[1])
	var roll := rng.randi() % weight
	var days := 1
	for step: Array in DURATIONS:
		roll -= int(step[1])
		if roll < 0:
			days = int(step[0])
			break
	return {"id": id, "days": days}

## Opens a crate: what it gives is held at once. Returns the prize and the strip of things
## that runs past in the animation (`strip`, the prize at `at`). Empty when there is none.
func open_crate(rng: RandomNumberGenerator = null, length: int = 48, at: int = 40) -> Dictionary:
	if crates <= 0:
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	crates -= 1
	opened += 1
	var prize := draw(rng)
	var strip: Array = []
	for i in range(length):
		strip.append(prize if i == at else draw(rng))
	add(str(prize.id), int(prize.days))
	return {"prize": prize, "strip": strip, "at": at}

# ---------------------------------------------------------------- locker and loadout

## The skin a weapon wears now ("" for none).
func skin_for(weapon: String) -> String:
	var skin := str(worn.get(weapon, ""))
	return skin if skin != "" and holds("%s/%s" % [skin, weapon]) else ""

## Puts a held skin on its weapon (or takes it off, if it is on).
func wear(id: String) -> void:
	if not holds(id) or not "/" in id:
		return
	if skin_for(weapon_of(id)) == skin_of(id):
		worn.erase(weapon_of(id))
	else:
		worn[weapon_of(id)] = skin_of(id)
	save()

func weapon_slots() -> int:
	return WEAPON_SLOTS + int(holds("rucksack") and taken.has("rucksack"))

## Ticks an item to come along, or unticks it. A third weapon (a second without the
## backpack) lets the one ticked longest ago go. Taking a weapon puts the skin on it.
func take(id: String) -> void:
	if not holds(id) or weapon_of(id) in START:
		return
	if taken.has(id):
		taken.erase(id)
		if id == "rucksack":
			_trim_weapons()
	else:
		taken.append(id)
		if "/" in id:
			worn[weapon_of(id)] = skin_of(id)
			for other: Variant in taken.duplicate():
				if str(other) != id and "/" in str(other) and weapon_of(str(other)) == weapon_of(id):
					taken.erase(other)
			_trim_weapons()
	save()

func _trim_weapons() -> void:
	var weapons: Array = taken.filter(func(other: Variant) -> bool: return "/" in str(other))
	while weapons.size() > weapon_slots():
		taken.erase(weapons.pop_front())

## Whether a piece of gear comes along.
func gear_on(id: String) -> bool:
	return holds(id) and taken.has(id)

## The weapons that come along from the locker.
func weapons_taken() -> Array:
	var out: Array = []
	for id: Variant in taken:
		if "/" in str(id) and holds(str(id)) and not weapon_of(str(id)) in START:
			out.append(weapon_of(str(id)))
	return out

## What a skin gives the weapon it is on (Survivor.rare).
func boost(weapon: String, line: String) -> float:
	var skin := skin_for(weapon)
	return float((WeaponSkins.SKINS[skin].boost as Dictionary).get(line, 0.0)) if skin != "" else 0.0

## Gives the survivor what comes along, at the start of a mission (after reset_survivor):
## skins on his weapons, the weapons from the locker, the backpack, the mask and medpacks.
func equip(player: Survivor) -> void:
	prune()
	player.backpack = gear_on("rucksack")
	for weapon: String in player.weapon_models:
		WeaponSkins.apply(player.weapon_models[weapon], skin_for(weapon))
	var first := ""
	for weapon: String in weapons_taken():
		if not player.inventory.has(weapon):
			if not player.room_for(weapon):
				continue
			player.inventory[weapon] = {"ammo": 0, "reserve": 0, "level": 0}
			player.inventory[weapon].ammo = player.magazine_of(weapon)
			player.inventory[weapon].reserve = player.reserve_cap(weapon)
		if first == "":
			first = weapon
	if gear_on("gasmaske"):
		player.mask_level = maxi(player.mask_level, MASK_LEVEL)
		player.mask_bonus = MASK_BONUS
		player.filter_left = player.filter_capacity()
	if gear_on("medpack"):
		player.items["medpack"] = MEDPACKS
	if first != "" and first != player.current_weapon:
		player.equip_weapon(first, true)
