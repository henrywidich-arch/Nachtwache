class_name Skills
extends RefCounted
## Three trees of abilities, each with a focus of its own: against the mass of the
## infected, against the special ones, and the breacher's - heavy gear, explosives and
## armour: his own, the C.R.U.'s and the Crusher's shell.
##
## Only one tree is in force at a time (chosen): only its abilities count, only its weapon
## is on sale. So a point earned counts in ALL three trees: each tree has the full number
## of points to itself, and what is spent in one takes nothing from the other two. Which
## tree is in force can be changed at once and for nothing - in the menu before a night
## and at the open shop counter during one (Game.may_switch_tree) - and nothing is given
## up for it: each tree keeps its own choices. A tree's choices can be taken back, for
## nothing as well, and made anew.
##
## Finished nights earn experience (from the career totals in the profile), experience
## gives levels, every level after the first one point. A point buys one rank of an
## ability in each tree. The abilities of a tree come in three tiers; a tier opens once
## enough points have gone into that tree. The last level leaves a player with LEVELS - 1
## points for each tree: about enough for every rank of it (the breacher has more ranks
## than that to choose from).
##
## Each tree also has a weapon of its own, which the shop only sells while that tree is in
## force and WEAPON_NEEDS points are in it.
##
## The profile keeps the ranks by ability and the tree in force, as it always did: one that
## was saved while the three trees shared one pool has its points where they were put, and
## as many free in the other two as its level gives.
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
			# The wish (WISHES): one weapon of this tree's list that is found more often and
			# earlier; the second rank opens the heavy ones of the list.
			{"id": "sweeper_wish", "label": "LEIBWAFFE", "tier": 2, "ranks": 2, "gives": {"wish": 1.0}, "note": "Wunschwaffe: öfter, früher – ab Rang 2 auch schwere"},
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
			# The wish (WISHES): one weapon of this tree's list that is found more often and
			# earlier; the second rank opens the heavy ones of the list.
			{"id": "hunter_wish", "label": "HANDVERLESEN", "tier": 2, "ranks": 2, "gives": {"wish": 1.0}, "note": "Wunschwaffe: öfter, früher – ab Rang 2 auch schwere"},
			{"id": "hunter_trophy", "label": "TROPHÄE", "tier": 3, "ranks": 1, "gives": {"trophy": 12.0}, "note": "+%s Leben für jeden erlegten Spezial-Infizierten"}
		]
	},
	"breacher": {
		# The breacher was a tree against the C.R.U. alone, and so the weakest of the three:
		# its soldiers are a small part of a night on the farm and no part of the second
		# mission. Now it is the tree of heavy gear (heavy_gear: the shotguns and whatever
		# is carried as a heavy weapon), of explosives and of armour. What it had against the
		# C.R.U. is one ability (armour and shields); the others keep the ids they had where
		# an ability of that kind was there before, so that a saved profile keeps its points
		# in them, and has those free again that went into abilities which are gone.
		"label": "BRECHER", "focus": "Schweres Gerät, Sprengstoff, Panzerung", "color": Color("74d8ea"), "weapons": ["fifty"],
		"skills": [
			{"id": "breacher_heavy", "label": "SCHWERES GERÄT", "tier": 1, "ranks": 3, "gives": {"damage_heavy": 0.08}, "note": "+%s %% Schaden mit Schrotflinten und schweren Waffen"},
			# His own blasts - a shell from the launcher above all, a grenade, a mine - leave
			# him OWN_BLAST_LEFT of their harm at the last rank; everybody else's (a grenade
			# of the C.R.U., a Charger, a growth) hurt him less as well.
			{"id": "breacher_frag", "label": "SPRENGMEISTER", "tier": 1, "ranks": 3, "gives": {"harm_blast": 0.3, "harm_burst": 0.12}, "note": "Eigene Explosionen schaden dir %s %% weniger, fremde %s %%"},
			{"id": "breacher_plates", "label": "PLATTENTRÄGER", "tier": 1, "ranks": 3, "gives": {"armour_hold": 0.2, "harm_bullet": 0.08}, "note": "Westen fangen %s %% mehr ab, Kugeln schaden %s %% weniger"},
			{"id": "breacher_armour", "label": "PANZERBRECHEND", "tier": 1, "ranks": 3, "gives": {"armour_pierce": 0.25, "shield_pierce": 0.25}, "note": "C.R.U.: Panzerung und Schilde halten %s %% weniger ab"},
			{"id": "breacher_charge", "label": "GROSSE LADUNG", "tier": 2, "ranks": 2, "gives": {"blast_power": 0.15, "blast_reach": 0.1}, "note": "Deine Sprengsätze: +%s %% Schaden, +%s %% Radius"},
			{"id": "breacher_drum", "label": "LADESCHÜTZE", "tier": 2, "ranks": 2, "gives": {"reload_heavy": 0.15, "reserve_heavy": 0.2}, "note": "Schweres Gerät: %s %% schneller geladen, +%s %% Reserve"},
			# (carry: how much of what the rotary gun slows its bearer is taken off.)
			{"id": "breacher_stance", "label": "STANDFEST", "tier": 2, "ranks": 2, "gives": {"brace_heavy": 0.25, "carry": 0.25}, "note": "Schweres Gerät: %s %% weniger Rückstoß und Gewicht"},
			{"id": "breacher_squad", "label": "WACHPOSTEN", "tier": 2, "ranks": 1, "gives": {"squad_guard": 1.0}, "note": "Begleiter halten Stellungen, Generator und Hack"},
			# The wish (WISHES): one weapon of this tree's list that is found more often and
			# earlier; the second rank opens the heavy ones of the list.
			{"id": "breacher_wish", "label": "SONDERBESTELLUNG", "tier": 2, "ranks": 2, "gives": {"wish": 1.0}, "note": "Wunschwaffe: öfter, früher – ab Rang 2 auch schwere"},
			# What no other tree can do: behind its shell the Crusher takes SHELL_SHARE of a
			# hit (Infected) - of the breacher's heavy gear and explosives it takes this much.
			{"id": "breacher_shell", "label": "SCHALENBRECHER", "tier": 3, "ranks": 1, "gives": {"shell_crack": 0.75}, "note": "Crusher-Panzer: schweres Gerät, Sprengsätze %s %% durch"}
		]
	}
}
## What is left of the harm of his own blast to a breacher with every rank of that ability.
const OWN_BLAST_LEFT := 0.1
## The weapons a player may wish for, tree by tree: with the first rank of the tree's
## wish one of "plain", with the second also one of "heavy" (what is carried as a heavy
## weapon). Only weapons that are not simply sold everywhere (HiveCaches.STANDARD) and
## none that is a tree's own. The lists fit their trees - the sweeper's for the crowd at
## close range, the hunter's the precise ones, the breacher's heavy gear - and a weapon
## that fits two is in both.
## What a wish does: in the second mission the night's caches are dealt with it
## (HiveCaches.deal: one cache early on the way holds it for certain); on the farm it
## costs WISH_CUT less and, where the shop has it only from a round on, it is there
## WISH_ROUNDS rounds earlier (Game.shelf, Game.weapon_round). The wish that counts is
## that of the tree in force. It never makes a weapon a rare one.
const WISHES := {
	"sweeper": {"plain": ["p90", "mp7", "shotgun", "hornet"], "heavy": ["autoshotgun", "minigun"]},
	"hunter": {"plain": ["m14", "badger", "revolver"], "heavy": ["sniper", "svd"]},
	"breacher": {"plain": ["g36", "wirbel", "shotgun"], "heavy": ["launcher", "mg", "mg2", "minigun"]}
}
const WISH_CUT := 0.25
const WISH_ROUNDS := 2
## Weapons whose bullets the sweeper's last ability sends through a body.
const RIFLES := ["rifle", "ak", "g36", "badger"]

## Ability id -> rank the player has in it.
var ranks: Dictionary = {}
## The tree that is in force ("" until one is: the first point puts its tree in force).
var chosen := ""
## Tree -> the weapon wished for in it ("" or missing: none). Kept whatever the ranks are;
## what counts is asked through wish().
var wishes: Dictionary = {}
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

## Points a career has earned: each tree has that many to itself.
static func points(totals: Dictionary) -> int:
	return level_of(experience(totals)) - 1

## Points still to be spent in a tree with these career totals.
func points_left(totals: Dictionary, tree: String) -> int:
	return maxi(0, points(totals) - spent(tree))

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
	if points_left(totals, tree) <= 0:
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

## Takes back the points of one tree: its choices can be made anew, and whichever tree is
## in force stays so. Without a tree, every point is taken back, and none is in force.
func reset(tree: String = "") -> void:
	if tree == "":
		ranks.clear()
		chosen = ""
		return
	for id in ranks.keys():
		if tree_of(str(id)) == tree:
			ranks.erase(id)

## The weapons that may be wished for in a tree with the ranks its wish has now.
func wish_list(tree: String) -> Array[String]:
	var out: Array[String] = []
	var have := rank(tree + "_wish")
	if WISHES.has(tree) and have >= 1:
		out.assign(WISHES[tree].plain)
		if have >= 2:
			out.append_array(WISHES[tree].heavy)
	return out

## The weapon wished for that counts: that of the tree in force (or of `tree`), if its
## wish has the rank for it. "" for none.
func wish(tree: String = "") -> String:
	if tree == "":
		tree = chosen
	var id := str(wishes.get(tree, ""))
	return id if active and wish_list(tree).has(id) else ""

## Names the weapon wished for in a tree ("" for none). True if it could be named.
func set_wish(tree: String, id: String) -> bool:
	if not active or not TREES.has(tree) or (id != "" and not wish_list(tree).has(id)):
		return false
	wishes[tree] = id
	return true

## The wish after the one named now, through the list and back to none.
func next_wish(tree: String) -> String:
	var list := wish_list(tree)
	var at := list.find(str(wishes.get(tree, "")))
	return list[at + 1] if at + 1 < list.size() else ""

## Takes over the wishes a profile holds: only for trees and weapons that exist in their
## lists (the rank is asked when the wish is, not here).
func adopt_wishes(stored: Variant) -> void:
	wishes.clear()
	if stored is Dictionary:
		for tree in stored:
			var id := str(stored[tree])
			if WISHES.has(str(tree)) and ((WISHES[str(tree)].plain as Array).has(id) or (WISHES[str(tree)].heavy as Array).has(id)):
				wishes[str(tree)] = id

## The tree a weapon belongs to, or "" for one that anybody may buy.
static func weapon_tree(id: String) -> String:
	for tree in TREES:
		if (TREES[tree].weapons as Array).has(id):
			return tree
	return ""

## Why the shop does not sell a weapon to this player ("" if it does): a tree's own
## weapon wants points in that tree, and that tree in force.
## In the test room every tree's weapon is to be had, whatever the points say.
var open_all := false

func weapon_barred(id: String) -> String:
	var tree := weapon_tree(id)
	if tree == "" or open_all:
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

## The note of an ability for the menu, with the amounts it gives at `at_rank`: one for
## each %s, in the order of `gives`.
static func note(skill: Dictionary, at_rank: int) -> String:
	var text := str(skill.note)
	var given: Array = (skill.gives as Dictionary).values()
	var amounts: Array = []
	for i in range(mini(text.count("%s"), given.size())):
		var amount: float = float(given[i]) * maxi(1, at_rank)
		amounts.append(str(int(round(amount))) if amount > 3.0 else str(int(round(amount * 100.0))))
	return text if amounts.is_empty() else text % amounts

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

## What the breacher's abilities count as heavy gear: the shotguns, and whatever is carried
## as a heavy weapon (Survivor.KINDS: key 3 - the machine guns, the launcher, the rifles of
## the big calibres, a tree's own weapon).
static func heavy_gear(weapon: String) -> bool:
	if not Survivor.WEAPONS.has(weapon):
		return false
	var data: Dictionary = Survivor.WEAPONS[weapon]
	return int(data.slot) == 3 or data.has("pellets")

## Factor on what a survivor's hit does to an enemy. `weapon`: what it was dealt with (""
## for a blow). A guest of a co-op match works this out himself and reports the damage.
func damage_factor(enemy: Infected, headshot: bool, weapon: String = "") -> float:
	if not active:
		return 1.0
	var kind := kind_of(enemy)
	var factor := 1.0
	if kind != "cru":
		factor += value("damage_" + kind)
	if headshot and kind != "special":
		factor += value("head_" + kind)
	if heavy_gear(weapon):
		factor += value("damage_heavy")
		if enemy.hardened():
			factor *= shell_gain()
	return factor

## Factor on what heavy gear and explosives do to a Crusher behind its shell: with the
## breacher's last ability that much more of them arrives than the shell lets through.
func shell_gain() -> float:
	return maxf(1.0, value("shell_crack") / Infected.SHELL_SHARE)

## Share of a bullet's damage that goes through a shield (0: it rings off).
func shield_share(_weapon: String) -> float:
	return clampf(value("shield_pierce"), 0.0, 1.0)

## Share by which a weapon is loaded faster, by which more ammunition for it fits into the
## pockets, and by which it kicks less: what the trees give, the breacher's only for heavy
## gear.
func quicker(weapon: String) -> float:
	return value("reload") + (value("reload_heavy") if heavy_gear(weapon) else 0.0)

func deeper(weapon: String) -> float:
	return value("reserve") + (value("reserve_heavy") if heavy_gear(weapon) else 0.0)

func steadier(weapon: String) -> float:
	return clampf(value("brace_heavy"), 0.0, 0.8) if heavy_gear(weapon) else 0.0

## How much of what a soldier's armour stops is left (1: all of it, 0: none).
func armour_left() -> float:
	return clampf(1.0 - value("armour_pierce"), 0.0, 1.0)

## Factor on harm done to the survivor. `kind`: "bullet", "gas", "acid", "blast" (an
## explosive of the survivors: a shell, a grenade, a mine - his own or his partner's),
## "frag" and "burst" (somebody else's blast: a grenade of the C.R.U., a Charger, a
## growth) or "" for a blow; `from`: what kind of enemy struck the blow ("common",
## "special", "cru" or "").
func harm_factor(kind: String, from: String) -> float:
	if not active:
		return 1.0
	var less := 0.0
	if kind in ["bullet", "gas", "acid", "blast"]:
		less += value("harm_" + kind)
	if kind in ["frag", "burst"]:
		less += value("harm_burst")
	if from in ["common", "special"]:
		less += value("harm_" + from)
	return clampf(1.0 - less, OWN_BLAST_LEFT if kind == "blast" else 0.25, 1.0)
