class_name Skills
extends RefCounted
## Three trees of abilities, each with a focus of its own: against the mass of the
## infected, against the special ones, and against the soldiers of the C.R.U.
##
## UNDER MAINTENANCE. The trees can be looked at in the menu, but no points can be spent
## and nothing here changes a night yet (IN_SERVICE). Everything below is wired into the
## game and covered by the checks all the same, so that putting it into service is this
## one constant and a round of balancing.
##
## How it is meant to work: finished nights earn experience (from the career totals in
## the profile), experience gives levels, every level after the first one point. A point
## buys one rank of an ability. The abilities of a tree come in three tiers; a tier opens
## once enough points have gone into its tree. Not every point can be had: the last level
## leaves a player with LEVELS - 1 points for 42 ranks, so a focus has to be chosen.

const IN_SERVICE := false
## Points that must be in a tree before its second and third tier open.
const TIER_NEEDS := [0, 3, 7]
const LEVELS := 20
## Experience for the career totals of the profile.
const WORTH := {"kills": 1, "special_kills": 4, "cru_kills": 6, "objectives": 60, "revives": 30, "victories": 500}

## id -> tree. Each ability: ranks it has, tier it belongs to, what one rank gives (`gives`:
## key -> amount per rank; game code asks for the keys through value()), and its note for
## the menu, in which %s stands for the amount at the rank shown.
## `weapons`: reserved for weapons that only this tree may buy (none yet).
const TREES := {
	"sweeper": {
		"label": "SÄUBERER", "focus": "Gegen die Masse der Infizierten", "color": Color("7fe3b4"), "weapons": [],
		"skills": [
			{"id": "sweeper_damage", "label": "DAUERFEUER", "tier": 1, "ranks": 3, "gives": {"damage_common": 0.08}, "note": "+%s %% Schaden gegen gewöhnliche Infizierte"},
			{"id": "sweeper_reload", "label": "SCHNELLE HÄNDE", "tier": 1, "ranks": 3, "gives": {"reload": 0.08}, "note": "Nachladen %s %% schneller"},
			{"id": "sweeper_skin", "label": "DICKES FELL", "tier": 2, "ranks": 3, "gives": {"harm_common": 0.08}, "note": "%s %% weniger Schaden durch gewöhnliche Infizierte"},
			{"id": "sweeper_ammo", "label": "VOLLE TASCHEN", "tier": 2, "ranks": 2, "gives": {"reserve": 0.15}, "note": "+%s %% Reservemunition"},
			{"id": "sweeper_head", "label": "KOPFJÄGER", "tier": 2, "ranks": 2, "gives": {"head_common": 0.12}, "note": "+%s %% Kopfschuss-Schaden gegen gewöhnliche Infizierte"},
			{"id": "sweeper_pierce", "label": "DURCHSCHLAG", "tier": 3, "ranks": 1, "gives": {"pierce_common": 1.0}, "note": "Gewehrkugeln durchschlagen einen gewöhnlichen Infizierten und treffen den dahinter"}
		]
	},
	"hunter": {
		"label": "JÄGER", "focus": "Gegen Spezial-Infizierte", "color": Color("ffc34d"), "weapons": [],
		"skills": [
			{"id": "hunter_damage", "label": "SCHWACHSTELLEN", "tier": 1, "ranks": 3, "gives": {"damage_special": 0.08}, "note": "+%s %% Schaden gegen Spezial-Infizierte"},
			{"id": "hunter_skin", "label": "ABGEHÄRTET", "tier": 1, "ranks": 3, "gives": {"harm_special": 0.1}, "note": "%s %% weniger Schaden durch Spezial-Infizierte"},
			{"id": "hunter_filter", "label": "FILTERTRAINING", "tier": 2, "ranks": 2, "gives": {"filter": 0.25, "harm_gas": 0.15}, "note": "Der Maskenfilter hält %s %% länger, Gas schadet weniger"},
			{"id": "hunter_acid", "label": "SÄUREFEST", "tier": 2, "ranks": 3, "gives": {"harm_acid": 0.2}, "note": "%s %% weniger Schaden durch Säure"},
			{"id": "hunter_grip", "label": "LOSREISSEN", "tier": 2, "ranks": 2, "gives": {"shake": 0.3}, "note": "Einen Leech %s %% schneller abschütteln"},
			{"id": "hunter_trophy", "label": "TROPHÄE", "tier": 3, "ranks": 1, "gives": {"trophy": 12.0}, "note": "Jeder erlegte Spezial-Infizierte gibt %s Lebenspunkte zurück"}
		]
	},
	"breacher": {
		"label": "BRECHER", "focus": "Gegen die Soldaten der C.R.U.", "color": Color("74d8ea"), "weapons": [],
		"skills": [
			{"id": "breacher_armour", "label": "PANZERBRECHEND", "tier": 1, "ranks": 3, "gives": {"armour_pierce": 0.25}, "note": "Die Panzerung der C.R.U. hält %s %% weniger ab"},
			{"id": "breacher_plates", "label": "PLATTENTRÄGER", "tier": 1, "ranks": 3, "gives": {"harm_bullet": 0.08}, "note": "%s %% weniger Schaden durch Kugeln"},
			{"id": "breacher_frag", "label": "SPLITTERSCHUTZ", "tier": 2, "ranks": 3, "gives": {"harm_frag": 0.12}, "note": "%s %% weniger Schaden durch Granaten"},
			{"id": "breacher_shield", "label": "SCHILDBRECHER", "tier": 2, "ranks": 1, "gives": {"shield_sniper": 1.0}, "note": "Das Scharfschützengewehr schießt durch den Schild"},
			{"id": "breacher_head", "label": "SAUBERER SCHUSS", "tier": 2, "ranks": 3, "gives": {"head_cru": 0.12}, "note": "+%s %% Kopfschuss-Schaden gegen die C.R.U."},
			{"id": "breacher_shield2", "label": "SCHILDBRECHER II", "tier": 3, "ranks": 1, "gives": {"shield_heavy": 0.5}, "note": "Auch Magnum und AK-47 schießen durch den Schild, mit halbem Schaden"}
		]
	}
}
## Weapons that the second shield ability counts as heavy enough.
const HEAVY := ["revolver", "ak"]
## Weapons whose bullets the sweeper's last ability sends through a body.
const RIFLES := ["rifle", "ak", "badger"]

## Ability id -> rank the player has in it.
var ranks: Dictionary = {}
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
	if rank(id) >= int(skill.ranks):
		return "Voll ausgebaut"
	var tree := tree_of(id)
	var need: int = TIER_NEEDS[int(skill.tier) - 1]
	if spent(tree) < need:
		return "Erst %d Punkte in %s" % [need, TREES[tree].label]
	if points_left(totals) <= 0:
		return "Kein Punkt frei"
	return ""

## Raises an ability by one rank. True if it did.
func learn(id: String, totals: Dictionary) -> bool:
	if barred(id, totals) != "":
		return false
	ranks[id] = rank(id) + 1
	return true

## Takes back every point.
func reset() -> void:
	ranks.clear()

## What is kept in the profile; only ranks that exist and fit are taken back in.
func adopt(stored: Variant) -> void:
	ranks.clear()
	if not stored is Dictionary:
		return
	for id in stored:
		var skill := find(str(id))
		if not skill.is_empty():
			ranks[str(id)] = clampi(int(stored[id]), 0, int(skill.ranks))

## The note of an ability for the menu, with the amount it gives at `at_rank`.
static func note(skill: Dictionary, at_rank: int) -> String:
	var text := str(skill.note)
	if not text.contains("%s"):
		return text
	var amount: float = float((skill.gives as Dictionary).values()[0]) * maxi(1, at_rank)
	return text % (str(int(round(amount))) if amount > 3.0 else str(int(round(amount * 100.0))))

# ---------------------------------------------------------------- what the game asks

## The sum of what the learnt abilities give under a key; 0 while out of service.
func value(key: String) -> float:
	if not active:
		return 0.0
	var sum := 0.0
	for id in ranks:
		var gives: Dictionary = find(str(id)).get("gives", {})
		sum += float(gives.get(key, 0.0)) * int(ranks[id])
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
