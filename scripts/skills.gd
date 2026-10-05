class_name Skills
extends RefCounted
## Three trees of abilities, each with a focus of its own: against the mass of the
## infected, against the special ones, and against the soldiers of the C.R.U.
##
## A player has ONE pool of points and spreads it over the three trees as he likes, but
## only one tree is in force at a time (chosen): only its abilities count, only its weapon
## is on sale. Which one that is can be changed in the menu at any time, for nothing; the
## points stay where they were put. They can also all be taken back, for nothing as well.
##
## Finished nights earn experience (from the career totals in the profile), experience
## gives levels, every level after the first one point. A point buys one rank of an
## ability. The abilities of a tree come in three tiers; a tier opens once enough points
## have gone into that tree. The last level leaves a player with LEVELS - 1 points: about
## enough for every rank of one tree, or for the better part of two.
##
## Each tree also has a weapon of its own, which the shop only sells while that tree is in
## force and WEAPON_NEEDS points are in it.
##
## IN_SERVICE false puts all of it out of service again: the trees can then still be looked
## at, but no points can be spent and nothing here changes a night.

const IN_SERVICE := true
## Points that must be in a tree before its second and third tier open.
const TIER_NEEDS := [0, 3, 7]
## Points that must be in a tree before the shop sells its weapon.
const WEAPON_NEEDS := 3
const LEVELS := 16
## Experience for the career totals of the profile.
const WORTH := {"kills": 1, "special_kills": 4, "cru_kills": 6, "objectives": 60, "revives": 30, "victories": 500}

## id -> tree. Each ability: ranks it has, tier it belongs to, what one rank gives (`gives`:
## key -> amount per rank; game code asks for the keys through value()), and its note for
## the menu, in which %s stands for the amount at the rank shown.
## `weapons`: what only somebody with points in this tree may buy (see Survivor.WEAPONS).
const TREES := {
	"sweeper": {
		"label": "SÄUBERER", "focus": "Gegen die Masse der Infizierten", "color": Color("7fe3b4"), "weapons": ["flamer"],
		"skills": [
			{"id": "sweeper_damage", "label": "DAUERFEUER", "tier": 1, "ranks": 3, "gives": {"damage_common": 0.08}, "note": "+%s %% Schaden gegen gewöhnliche Infizierte"},
			{"id": "sweeper_reload", "label": "SCHNELLE HÄNDE", "tier": 1, "ranks": 3, "gives": {"reload": 0.08}, "note": "Nachladen %s %% schneller"},
			{"id": "sweeper_skin", "label": "DICKES FELL", "tier": 2, "ranks": 3, "gives": {"harm_common": 0.08}, "note": "%s %% weniger Schaden durch gewöhnliche Infizierte"},
			{"id": "sweeper_ammo", "label": "VOLLE TASCHEN", "tier": 2, "ranks": 2, "gives": {"reserve": 0.15}, "note": "+%s %% Reservemunition"},
			{"id": "sweeper_head", "label": "KOPFJÄGER", "tier": 2, "ranks": 2, "gives": {"head_common": 0.12}, "note": "+%s %% Kopfschuss-Schaden gegen gewöhnliche Infizierte"},
			# What the squad takes over by itself: see MissionDirector.SQUAD_JOBS. Each tree has one.
			{"id": "sweeper_squad", "label": "SPÜRTRUPP", "tier": 2, "ranks": 1, "gives": {"squad_search": 1.0}, "note": "Begleiter bergen Codes, Koffer und Festplatten"},
			# The flamethrower is this tree's weapon. What it sets alight goes off without harm to
			# the survivors (Infected.burn_tame): a Charger's blast, a Striker's growths.
			{"id": "sweeper_fire", "label": "AUSGEBRANNT", "tier": 2, "ranks": 1, "gives": {"fire_tame": 1.0}, "note": "Flammenwerfer entschärft Charger und Wucherungen"},
			{"id": "sweeper_pierce", "label": "DURCHSCHLAG", "tier": 3, "ranks": 1, "gives": {"pierce_common": 1.0}, "note": "Gewehrkugeln durchschlagen gewöhnliche Infizierte"}
		]
	},
	"hunter": {
		"label": "JÄGER", "focus": "Gegen Spezial-Infizierte", "color": Color("ffc34d"), "weapons": ["nitro"],
		"skills": [
			{"id": "hunter_damage", "label": "SCHWACHSTELLEN", "tier": 1, "ranks": 3, "gives": {"damage_special": 0.08}, "note": "+%s %% Schaden gegen Spezial-Infizierte"},
			{"id": "hunter_skin", "label": "ABGEHÄRTET", "tier": 1, "ranks": 3, "gives": {"harm_special": 0.1}, "note": "%s %% weniger Schaden durch Spezial-Infizierte"},
			{"id": "hunter_filter", "label": "FILTERTRAINING", "tier": 2, "ranks": 2, "gives": {"filter": 0.25, "harm_gas": 0.15}, "note": "Der Maskenfilter hält %s %% länger, Gas schadet weniger"},
			{"id": "hunter_acid", "label": "SÄUREFEST", "tier": 2, "ranks": 3, "gives": {"harm_acid": 0.2}, "note": "%s %% weniger Schaden durch Säure"},
			{"id": "hunter_grip", "label": "LOSREISSEN", "tier": 2, "ranks": 2, "gives": {"shake": 0.3}, "note": "Einen Leech %s %% schneller abschütteln"},
			{"id": "hunter_squad", "label": "TECHNIKER", "tier": 2, "ranks": 1, "gives": {"squad_switch": 1.0}, "note": "Begleiter bedienen Sicherungen, Funkmast und Kisten"},
			{"id": "hunter_trophy", "label": "TROPHÄE", "tier": 3, "ranks": 1, "gives": {"trophy": 12.0}, "note": "+%s Leben für jeden erlegten Spezial-Infizierten"}
		]
	},
	"breacher": {
		"label": "BRECHER", "focus": "Gegen die Soldaten der C.R.U.", "color": Color("74d8ea"), "weapons": ["fifty"],
		"skills": [
			{"id": "breacher_armour", "label": "PANZERBRECHEND", "tier": 1, "ranks": 3, "gives": {"armour_pierce": 0.25}, "note": "Die Panzerung der C.R.U. hält %s %% weniger ab"},
			{"id": "breacher_plates", "label": "PLATTENTRÄGER", "tier": 1, "ranks": 3, "gives": {"harm_bullet": 0.08}, "note": "%s %% weniger Schaden durch Kugeln"},
			{"id": "breacher_frag", "label": "SPLITTERSCHUTZ", "tier": 2, "ranks": 3, "gives": {"harm_frag": 0.12}, "note": "%s %% weniger Schaden durch Granaten"},
			{"id": "breacher_shield", "label": "SCHILDBRECHER", "tier": 2, "ranks": 1, "gives": {"shield_sniper": 1.0}, "note": "Das Scharfschützengewehr schießt durch den Schild"},
			{"id": "breacher_head", "label": "SAUBERER SCHUSS", "tier": 2, "ranks": 3, "gives": {"head_cru": 0.12}, "note": "+%s %% Kopfschuss-Schaden gegen die C.R.U."},
			{"id": "breacher_squad", "label": "WACHPOSTEN", "tier": 2, "ranks": 1, "gives": {"squad_guard": 1.0}, "note": "Begleiter halten Stellungen, Generator und Hack"},
			{"id": "breacher_shield2", "label": "SCHILDBRECHER II", "tier": 3, "ranks": 1, "gives": {"shield_heavy": 0.5}, "note": "Magnum, AK-47 und Schrotflinten: 50 % durch Schilde"}
		]
	}
}
## Weapons that the second shield ability counts as heavy enough.
const HEAVY := ["revolver", "ak", "shotgun", "autoshotgun"]
## Weapons whose bullets the sweeper's last ability sends through a body.
const RIFLES := ["rifle", "ak", "g36", "badger"]

## Ability id -> rank the player has in it.
var ranks: Dictionary = {}
## The tree that is in force ("" until one is: the first point puts its tree in force).
var chosen := ""
## While false, nothing here has any effect. The checks switch it on for themselves.
var active := IN_SERVICE

# ---------------------------------------------------------------- experience

## Experience a career is worth.
static func experience(totals: Dictionary) -> int:
	var sum := 0
	for key in WORTH:
		sum += int(totals.get(key, 0)) * int(WORTH[key])
	return sum

## Experience it takes to be at a level (the first costs nothing).
static func needed(level: int) -> int:
	return 250 * (level - 1) * level

static func level_of(amount: int) -> int:
	var level := 1
	while level < LEVELS and amount >= needed(level + 1):
		level += 1
	return level

# ---------------------------------------------------------------- the trees

static func find(id: String) -> Dictionary:
	for tree in TREES:
		for skill in TREES[tree].skills:
			if str(skill.id) == id:
				return skill
	return {}

static func tree_of(id: String) -> String:
	for tree in TREES:
		for skill in TREES[tree].skills:
			if str(skill.id) == id:
				return tree
	return ""

func rank(id: String) -> int:
	return int(ranks.get(id, 0))

## Points that have gone into a tree, or into all of them.
func spent(tree: String = "") -> int:
	var sum := 0
	for id in ranks:
		if tree == "" or tree_of(str(id)) == tree:
			sum += int(ranks[id])
	return sum

## Points still to be spent with these career totals.
func points_left(totals: Dictionary) -> int:
	return maxi(0, level_of(experience(totals)) - 1 - spent())

## Why an ability cannot be raised right now ("" if it can).
func barred(id: String, totals: Dictionary) -> String:
	var skill := find(id)
	if skill.is_empty():
		return "Unbekannt"
	if not active:
		return "In Wartung"
	var tree := tree_of(id)
	if rank(id) >= int(skill.ranks):
		return "Voll ausgebaut"
	var need: int = TIER_NEEDS[int(skill.tier) - 1]
	if spent(tree) < need:
		return "Erst %d Punkte in %s" % [need, TREES[tree].label]
	if points_left(totals) <= 0:
		return "Kein Punkt frei"
	return ""

## Raises an ability by one rank. True if it did. The very first point also puts its tree
## in force.
func learn(id: String, totals: Dictionary) -> bool:
	if barred(id, totals) != "":
		return false
	ranks[id] = rank(id) + 1
	if chosen == "":
		chosen = tree_of(id)
	return true

## Puts a tree in force, whichever was before. True if it did.
func choose(tree: String) -> bool:
	if not active or not TREES.has(tree):
		return false
	chosen = tree
	return true

## Takes back every point; with none spent, no tree is in force either.
func reset() -> void:
	ranks.clear()
	chosen = ""

## The tree a weapon belongs to, or "" for one that anybody may buy.
static func weapon_tree(id: String) -> String:
	for tree in TREES:
		if (TREES[tree].weapons as Array).has(id):
			return tree
	return ""

## Why the shop does not sell a weapon to this player ("" if it does): a tree's own
## weapon wants points in that tree, and that tree in force.
func weapon_barred(id: String) -> String:
	var tree := weapon_tree(id)
	if tree == "":
		return ""
	if not active:
		return "In Wartung"
	if spent(tree) < WEAPON_NEEDS:
		return "%d Punkte in %s" % [WEAPON_NEEDS, TREES[tree].label]
	return "" if tree == chosen else "%s nicht aktiv" % TREES[tree].label

## What is kept in the profile: the ranks and the tree in force. Only ranks that exist and
## fit are taken back in. A profile that has ranks but names no tree: the tree with the
## most points is in force.
func adopt(stored: Variant, tree: String = "") -> void:
	ranks.clear()
	chosen = tree if TREES.has(tree) else ""
	if stored is Dictionary:
		for id in stored:
			var skill := find(str(id))
			if not skill.is_empty() and int(stored[id]) > 0:
				ranks[str(id)] = clampi(int(stored[id]), 0, int(skill.ranks))
	if chosen == "":
		var most := 0
		for id in TREES:
			if spent(id) > most:
				most = spent(id)
				chosen = id

## The note of an ability for the menu, with the amount it gives at `at_rank`.
static func note(skill: Dictionary, at_rank: int) -> String:
	var text := str(skill.note)
	if not text.contains("%s"):
		return text
	var amount: float = float((skill.gives as Dictionary).values()[0]) * maxi(1, at_rank)
	return text % (str(int(round(amount))) if amount > 3.0 else str(int(round(amount * 100.0))))

# ---------------------------------------------------------------- what the game asks

## The sum of what the abilities of the tree in force give under a key; 0 while out of
## service. Ranks in the other trees rest until theirs is put in force.
func value(key: String) -> float:
	if not active or not TREES.has(chosen):
		return 0.0
	var sum := 0.0
	for skill in TREES[chosen].skills:
		var have := rank(str(skill.id))
		if have > 0:
			sum += float((skill.gives as Dictionary).get(key, 0.0)) * have
	return sum

## "common", "special" or "cru": what kind of enemy this is to the trees.
static func kind_of(enemy: Infected) -> String:
	if enemy.spec.get("human", false):
		return "cru"
	return "common" if enemy.kind == "mauler" else "special"

## Factor on what a survivor's bullet does to an enemy.
func damage_factor(enemy: Infected, headshot: bool) -> float:
	if not active:
		return 1.0
	var kind := kind_of(enemy)
	var factor := 1.0
	if kind != "cru":
		factor += value("damage_" + kind)
	if headshot and kind != "special":
		factor += value("head_" + kind)
	return factor

## Share of a bullet's damage that goes through a shield (0: it rings off).
func shield_share(weapon: String) -> float:
	if not active:
		return 0.0
	if weapon == "sniper" and value("shield_sniper") > 0.0:
		return 1.0
	if weapon in HEAVY:
		return value("shield_heavy")
	return 0.0

## How much of what a soldier's armour stops is left (1: all of it, 0: none).
func armour_left() -> float:
	return clampf(1.0 - value("armour_pierce"), 0.0, 1.0)

## Factor on harm done to the survivor. `kind`: "bullet", "frag", "gas", "acid" or "" for
## a blow; `from`: what kind of enemy struck the blow ("common", "special", "cru" or "").
func harm_factor(kind: String, from: String) -> float:
	if not active:
		return 1.0
	var less := 0.0
	if kind in ["bullet", "frag", "gas", "acid"]:
		less += value("harm_" + kind)
	if from in ["common", "special"]:
		less += value("harm_" + from)
	return clampf(1.0 - less, 0.25, 1.0)
