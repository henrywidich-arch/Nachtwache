class_name Tally
extends RefCounted
## What one fighter - the player, the co-op partner or a squad bot - has done tonight, for
## the scoreboard (scoreboard.gd). Kills are kept where they always were (Game.kills,
## RemoteSurvivor.kills, Teammate.kills); these are the rest. A plain Dictionary, so it
## crosses the network as it is.

const KEYS := ["headshots", "damage", "shots", "hits", "downs", "revives"]

static func blank() -> Dictionary:
	var empty := {}
	for key in KEYS:
		empty[key] = 0
	return empty

## One trigger pull: `struck` maps each infected the shot hit to {damage, headshot, ...}
## (the blast of a shotgun lands as a single entry per body, as it is dealt).
static func shot(tally: Dictionary, struck: Dictionary) -> void:
	tally.shots = int(tally.shots) + 1
	if struck.is_empty():
		return
	tally.hits = int(tally.hits) + 1
	var dealt := 0.0
	for enemy: Variant in struck:
		var entry: Dictionary = struck[enemy]
		if bool(entry.get("headshot", false)):
			tally.headshots = int(tally.headshots) + 1
		var damage := float(entry.damage)
		# Nothing counts for more than the body had left in it.
		if is_instance_valid(enemy) and enemy is Infected:
			damage = minf(damage, maxf(0.0, (enemy as Infected).health))
		dealt += damage
	tally.damage = int(tally.damage) + int(round(dealt))

## Hits in a hundred shots; -1 for someone who has not fired.
static func accuracy(tally: Dictionary) -> int:
	var shots := int(tally.get("shots", 0))
	if shots <= 0:
		return -1
	return int(round(100.0 * float(int(tally.get("hits", 0))) / float(shots)))

## The keys of `from` that belong in a tally, as whole numbers (what a partner reports).
static func clean(from: Dictionary) -> Dictionary:
	var out := blank()
	for key in KEYS:
		out[key] = maxi(0, int(from.get(key, 0)))
	return out
