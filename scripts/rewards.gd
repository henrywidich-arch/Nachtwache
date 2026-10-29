class_name Rewards
extends RefCounted
## Crates and what comes out of them (v0.79). Every won mission gives a crate; it is
## opened in the menu (KISTEN) and gives one thing for 1, 3 or 7 days: a weapon skin
## (WeaponSkins) or a piece of gear. What is held lies in the locker (SPIND): a skin is put
## on its weapon there, and what is ticked to come along is what the survivor starts the
## next mission with (equip). The same thing won again adds its days.
## (v0.86) What a crate gives waits in the locker until it is ACTIVATED - put on, or
## ticked to come along: only from then on do its days run (waiting).
## Stored apart from the profile, as JSON in user://nachtwache_rewards.json. In a co-op
## match each player has his own crates and his own locker.

const PATH := "user://nachtwache_rewards.json"
const DAY := 86400
## The weapons skins come for: the two every survivor starts with, and the favourites.
const SKIN_WEAPONS := ["rifle", "pistol", "ak", "p90", "ump", "g36", "mp7", "shotgun", "deagle"]
## How often a crate gives each skin, and gear: weights.
## (v0.80) By rarity: a rare skin 12, an epic one 8, a legendary one 5.
const SKIN_WEIGHTS := {"toxin": 8, "vektor": 8, "neon": 8, "mondnacht": 5, "sakura": 5, "drache": 5,
	"rotelinie": 5, "eisernerose": 5, "toterwinkel": 5,
	"kintsugi": 8, "horizont": 8, "frostwurm": 8, "tarot": 8, "oni": 8, "pfau": 8, "pharao": 8, "koi": 8, "jade": 8, "feuerzwerg": 8, "vietnam": 8, "fliegenpilz": 8,
	"giftbluete": 12, "sonnenfalke": 12, "cyberbluete": 12, "reaktor": 12, "spielhalle": 12, "zuckerschaedel": 12, "donnertiger": 12, "vulkan": 12, "strassenkunst": 12, "sturmatlas": 12}
const GEAR_WEIGHT := 84
## Gear. icon: the symbol (ShopIcons/UiSymbols). model: what is shown once it exists.
const GEAR := {
	"gasmaske": {"label": "GASMASKE", "icon": "mask", "model": "res://assets/models/gasmaske.glb",
		"note": "Du startest mit Gasmaske (Stufe 2). Ihr Filter hält 50 % länger – auch nach jedem Kauf im Laden."},
	"medpack": {"label": "MEDPACK", "icon": "heal",
		"note": "Zwei Medpacks zum Hinlegen (Taste K): Alle 2 Sekunden heilt es jeden in der Nähe, bis sein Vorrat aufgebraucht ist – dann zerplatzt es."},
	"rucksack": {"label": "RUCKSACK", "icon": "gear",
		"note": "Ein Waffenplatz mehr für jede Art, und eine Waffe mit Skin aus dem Spind kommt mit: Hake sie an, dann startest du mit ihr. Ohne Rucksack findest du Waffen wie gewohnt im Einsatz."}
}
## The filter of the crate's mask lasts this much longer (Survivor.filter_capacity).
const MASK_BONUS := 0.5
const MASK_LEVEL := 2
const MEDPACKS := 2
## Every survivor starts with these anyway. (v0.88, Henry) A skin brings its weapon along
## only with the backpack taken, and then one: else the weapon is found in the mission as
## before, and wears its skin from then on.
const START := ["rifle", "pistol"]

var stored := true
var crates := 0
## Crates opened in all.
var opened := 0
## What is held: item -> until when (unix seconds). Items: "<skin>/<weapon>" or a gear id.
var owned: Dictionary = {}
## Won but not activated yet: item -> how many seconds it will last once it is (v0.86).
var waiting: Dictionary = {}
## Weapon -> the skin it wears.
var worn: Dictionary = {}
## Items ticked to come along.
var taken: Array = []
## Seconds added to the clock (the checks let days pass with it).
var clock_shift := 0
## Skins tried on in the test room, weapon -> skin (never saved; cleared when it is left).
var trial: Dictionary = {}

func now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_shift

func open() -> void:
	if not stored or not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		read(parsed)

func read(parsed: Dictionary) -> void:
	# (A file from before the kinds of crate: what it counted are crates of SCHWER.)
	stock = {"plain": 0, "hard": 0, "nightmare": 0}
	if parsed.get("stock") is Dictionary:
		for tier: String in stock:
			stock[tier] = maxi(0, int(parsed.stock.get(tier, 0)))
	else:
		stock.hard = maxi(0, int(parsed.get("crates", 0)))
	crates = _count()
	opened = maxi(0, int(parsed.get("opened", 0)))
	owned.clear()
	if parsed.get("owned") is Dictionary:
		for id: String in parsed.owned:
			if known(id):
				owned[id] = int(parsed.owned[id])
	waiting.clear()
	if parsed.get("waiting") is Dictionary:
		for id: String in parsed.waiting:
			if known(id) and int(parsed.waiting[id]) > 0:
				waiting[id] = int(parsed.waiting[id])
	worn.clear()
	if parsed.get("worn") is Dictionary:
		for weapon: String in parsed.worn:
			if known("%s/%s" % [parsed.worn[weapon], weapon]):
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
		file.store_string(JSON.stringify({"crates": crates, "stock": stock, "opened": opened, "owned": owned, "waiting": waiting, "worn": worn, "taken": taken}, "\t"))

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

## Whether an item lies in the locker: running, or still waiting to be activated.
func has_item(id: String) -> bool:
	return holds(id) or waiting.has(id)

## Whether an item still waits to be activated.
func dormant(id: String) -> bool:
	return waiting.has(id) and not holds(id)

## Starts the days of an item that waits (v0.86). Nothing happens to one that runs.
func activate(id: String) -> void:
	if not waiting.has(id):
		return
	owned[id] = maxi(now(), int(owned.get(id, 0))) + int(waiting[id])
	waiting.erase(id)
	save()

## The items of the locker: running ones and those that wait.
func items() -> Array:
	var out: Array = owned.keys()
	for id: String in waiting:
		if not out.has(id):
			out.append(id)
	return out

## How long is left, in words: "2 T 5 Std", "3 Std 10 Min".
func left_words(id: String) -> String:
	if dormant(id):
		var days := int(waiting[id]) / DAY
		return "nicht aktiviert  ·  %s" % ("%d %s" % [days, "Tag" if days == 1 else "Tage"] if days > 0 else "%d Std" % (int(waiting[id]) / 3600))
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
	for id: String in waiting.keys():
		if not known(id):
			waiting.erase(id)
	taken = taken.filter(func(id: Variant) -> bool: return holds(str(id)) and not weapon_of(str(id)) in START)
	_trim_weapons()

## Gives an item for `days`. One that runs already gets the days on top; a new one waits
## in the locker and its days start only when it is activated (v0.86: put on or ticked to
## come along, see wear and take).
func add(id: String, days: int) -> void:
	if not known(id):
		return
	if holds(id):
		owned[id] = int(owned[id]) + days * DAY
	else:
		waiting[id] = int(waiting.get(id, 0)) + days * DAY
	save()

# ---------------------------------------------------------------- crates

## (Henry, v0.79) Crates are worth more on the two hard levels: on EASY and NORMAL a won
## mission seldom gives one, and that plain crate gives only things for one day and no
## legendary skin; SCHWER always gives a crate with everything for 1, 3 or 7 days, and
## ALBTRAUM a crate whose prizes last longer. (v0.88) That one is a special crate: it
## gives two prizes (prizes), the second shown under the first.
const CRATE_CHANCE := {"easy": 0.1, "normal": 0.2, "hard": 1.0, "nightmare": 1.0}
const TIER_OF := {"easy": "plain", "normal": "plain", "hard": "hard", "nightmare": "nightmare"}
const TIERS := {
	"plain": {"label": "EINFACHE KISTE", "durations": [[1, 1]], "legendary": false},
	"hard": {"label": "SCHWERE KISTE", "durations": [[1, 62], [3, 28], [7, 10]], "legendary": true},
	"nightmare": {"label": "ALBTRAUM-SPEZIALKISTE", "durations": [[1, 35], [3, 40], [7, 25]], "legendary": true, "prizes": 2}
}
## How many crates of each kind wait (the best is opened first).
var stock := {"plain": 0, "hard": 0, "nightmare": 0}

## A won mission on a level: whether it gives a crate (its chance) - and then which.
func earn(level: String, rng: RandomNumberGenerator = null) -> bool:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if rng.randf() >= float(CRATE_CHANCE.get(level, 0.2)):
		return false
	grant_crate(str(TIER_OF.get(level, "plain")))
	return true

## (v0.88) The second mission's length (HiveLayout.LENGTHS) makes a won night worth more:
##   chance  times the level's CRATE_CHANCE (at most sure), count  crates, up  tiers better.
## KURZ as before, MITTEL twice the chance, LANG a sure crate one tier better, MAXIMAL two
## of them; on ALBTRAUM LANG and MAXIMAL give one crate more.
const LENGTH_CRATES := {
	"short": {"chance": 1.0, "count": 1, "up": 0},
	"medium": {"chance": 2.0, "count": 1, "up": 0},
	"long": {"chance": 99.0, "count": 1, "up": 1},
	"max": {"chance": 99.0, "count": 2, "up": 1}
}
const TIER_UP := {"plain": "hard", "hard": "nightmare", "nightmare": "nightmare"}
## (v0.88) The endless night (on both maps): at each plateau of time survived [seconds,
## tier] a crate - the longer, the better. SCHWER lifts each a tier, ALBTRAUM as well and
## gives two of them.
const ENDLESS_STEPS := [[600.0, "plain"], [1200.0, "hard"], [1800.0, "nightmare"], [2700.0, "nightmare"]]

## A won night of the second mission: the crates it gives (their tiers; none, one or more).
func earn_night(level: String, length: String, rng: RandomNumberGenerator = null) -> Array[String]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var rule: Dictionary = LENGTH_CRATES.get(length, LENGTH_CRATES.medium)
	var out: Array[String] = []
	if rng.randf() >= float(CRATE_CHANCE.get(level, 0.2)) * float(rule.chance):
		return out
	var tier := str(TIER_OF.get(level, "plain"))
	if int(rule.up) > 0:
		tier = str(TIER_UP[tier])
	var count := int(rule.count) + int(int(rule.up) > 0 and level == "nightmare")
	for i in range(count):
		grant_crate(tier)
		out.append(tier)
	return out

## What a plateau of the endless night (an index of ENDLESS_STEPS) gives on a level: its
## crates' tiers.
static func endless_tiers(level: String, step: int) -> Array[String]:
	var tier := str(ENDLESS_STEPS[clampi(step, 0, ENDLESS_STEPS.size() - 1)][1])
	if level in ["hard", "nightmare"]:
		tier = str(TIER_UP[tier])
	var out: Array[String] = [tier]
	if level == "nightmare":
		out.append(tier)
	return out

## What a length of the second mission gives, in words for the play menu.
static func length_words(length: String) -> String:
	match length:
		"short":
			return "2 Areale  ·  Kiste wie gewohnt"
		"long":
			return "5 Areale  ·  sichere Kiste, eine Stufe besser (Albtraum: zwei)"
		"max":
			return "6 Areale  ·  zwei Kisten, eine Stufe besser (Albtraum: drei)"
	return "3–4 Areale  ·  doppelte Kistenchance"

## Tiers in words: "2× ALBTRAUM-KISTE, 1× SCHWERE KISTE".
static func tiers_words(tiers: Array) -> String:
	var said: Array[String] = []
	for tier: String in ["nightmare", "hard", "plain"]:
		var n := tiers.count(tier)
		if n > 0:
			said.append("%d× %s" % [n, str(TIERS[tier].label)])
	return ", ".join(said)

func grant_crate(tier: String = "hard") -> void:
	if not stock.has(tier):
		tier = "hard"
	stock[tier] = int(stock[tier]) + 1
	crates = _count()
	save()

func _count() -> int:
	var all := 0
	for tier: String in stock:
		all += int(stock[tier])
	return all

## The kind of crate that is opened next: the best that waits ("" for none).
func next_tier() -> String:
	for tier: String in ["nightmare", "hard", "plain"]:
		if int(stock.get(tier, 0)) > 0:
			return tier
	return ""

## Everything a crate can give, as [item, weight] (a skin's weight is shared by its weapons).
static func pool(tier: String = "hard") -> Array:
	var out: Array = []
	for skin: String in SKIN_WEIGHTS:
		if WeaponSkins.SKINS[skin].rarity == "legendary" and not bool(TIERS.get(tier, TIERS.hard).legendary):
			continue
		var weapons: Array = WeaponSkins.SKINS[skin].get("weapons", SKIN_WEAPONS)
		for weapon: String in weapons:
			out.append(["%s/%s" % [skin, weapon], float(SKIN_WEIGHTS[skin]) / weapons.size()])
	for id: String in GEAR:
		out.append([id, float(GEAR_WEIGHT) / GEAR.size()])
	return out

static func draw(rng: RandomNumberGenerator, tier: String = "hard") -> Dictionary:
	var entries := pool(tier)
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
	var durations: Array = TIERS.get(tier, TIERS.hard).durations
	var weight := 0
	for step: Array in durations:
		weight += int(step[1])
	var roll := rng.randi() % weight
	var days := 1
	for step: Array in durations:
		roll -= int(step[1])
		if roll < 0:
			days = int(step[0])
			break
	return {"id": id, "days": days}

## Opens a crate (the best that waits): what it gives is held at once. Returns the prize,
## the kind of crate and the strip of things that runs past in the animation (`strip`, the
## prize at `at`). Empty when there is none.
func open_crate(rng: RandomNumberGenerator = null, length: int = 48, at: int = 40) -> Dictionary:
	var tier := next_tier()
	if tier == "":
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	stock[tier] = int(stock[tier]) - 1
	crates = _count()
	opened += 1
	var prize := draw(rng, tier)
	var strip: Array = []
	for i in range(length):
		strip.append(prize if i == at else draw(rng, tier))
	add(str(prize.id), int(prize.days))
	var extra: Array = []
	for i in range(int(TIERS[tier].get("prizes", 1)) - 1):
		var more := draw(rng, tier)
		add(str(more.id), int(more.days))
		extra.append(more)
	return {"prize": prize, "strip": strip, "at": at, "tier": tier, "extra": extra}

# ---------------------------------------------------------------- locker and loadout

## The skin a weapon wears now ("" for none).
func skin_for(weapon: String) -> String:
	# (A skin tried on in the test room comes first while it is on: Sandbox.try_skin.)
	if trial.has(weapon):
		return str(trial[weapon])
	var skin := str(worn.get(weapon, ""))
	return skin if skin != "" and holds("%s/%s" % [skin, weapon]) else ""

## Puts a held skin on its weapon (or takes it off, if it is on).
func wear(id: String) -> void:
	if not "/" in id:
		return
	activate(id)
	if not holds(id):
		return
	if skin_for(weapon_of(id)) == skin_of(id):
		worn.erase(weapon_of(id))
	else:
		worn[weapon_of(id)] = skin_of(id)
	save()

## Whether a weapon skin can be ticked to come along: only with the backpack taken.
func carries_weapon() -> bool:
	return gear_on("rucksack")

## Ticks an item to come along, or unticks it. A weapon skin only with the backpack (one
## weapon: another ticked lets the first go); ticking it puts the skin on.
func take(id: String) -> void:
	if weapon_of(id) in START:
		return
	if "/" in id and not taken.has(id) and not carries_weapon():
		return
	activate(id)
	if not holds(id):
		return
	if taken.has(id):
		taken.erase(id)
	else:
		taken.append(id)
		if "/" in id:
			worn[weapon_of(id)] = skin_of(id)
			for other: Variant in taken.duplicate():
				if str(other) != id and "/" in str(other):
					taken.erase(other)
	_trim_weapons()
	save()

## Without the backpack no weapon skin stays ticked to come along.
func _trim_weapons() -> void:
	if carries_weapon():
		return
	taken = taken.filter(func(other: Variant) -> bool: return not "/" in str(other))

## The weapon that comes along from the locker (with the backpack only), or none.
func weapons_taken() -> Array:
	var out: Array = []
	if not carries_weapon():
		return out
	for id: Variant in taken:
		if "/" in str(id) and holds(str(id)) and not weapon_of(str(id)) in START:
			out.append(weapon_of(str(id)))
	return out.slice(0, 1)

## Whether a piece of gear comes along.
func gear_on(id: String) -> bool:
	return holds(id) and taken.has(id)

## What a skin gives the weapon it is on (Survivor.rare).
func boost(weapon: String, line: String) -> float:
	var skin := skin_for(weapon)
	return float((WeaponSkins.SKINS[skin].boost as Dictionary).get(line, 0.0)) if skin != "" else 0.0

## Gives the survivor what comes along, at the start of a mission (after reset_survivor):
## skins on his weapons, the backpack (and with it the weapon ticked), the mask and
## medpacks. (A weapon found later is painted already: every model gets its skin here.)
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
			player.inventory[weapon] = player.new_record(weapon)
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
