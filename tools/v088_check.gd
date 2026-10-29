extends SceneTree
## Checks the rules of v0.88 without the game: the lengths of the second mission's nights,
## the crates a won night and the endless night give, the special crate with two prizes,
## the paces of the plain infected and the rule of the backpack. Headless is fine:
##   Godot --headless --path . -s res://tools/v088_check.gd

func _initialize() -> void:
	_run.call_deferred()

func _areas(night: Dictionary) -> int:
	var n := 0
	for piece: Dictionary in night.get("pieces", []):
		n += 1 if str(piece.get("kind", "")) == "area" else 0
	return n

func _run() -> void:
	var faults: Array[String] = []
	# --- lengths: the number of areas, the key, the default dice unchanged
	for length: String in HiveLayout.LENGTH_ORDER:
		var counts := {}
		for s in range(1, 41):
			var night := HiveLayout.plan(s, "", length)
			var n := _areas(night)
			counts[n] = int(counts.get(n, 0)) + 1
			if str(night.get("length", "")) != length or not str(night.key).contains("+" + length):
				faults.append("%s: night %d does not keep its length" % [length, s])
		var wanted: Dictionary = HiveLayout.LENGTHS[length].counts
		for n: int in counts:
			if not wanted.has(n):
				faults.append("%s gives %d areas" % [length, n])
		print("length %s: areas %s" % [length, counts])
	if HiveLayout.plan(7).key != HiveLayout.plan(7, "", "").key:
		faults.append("a night without a length is not as before")
	var hall := HiveLayout.plan(9, HiveLayout.ROOM_TOKYO, "short")
	if not bool(hall.get("tokyo", false)) or not str(hall.key).ends_with("+short+tokio"):
		faults.append("a chosen hall with a length: " + str(hall.key))
	# --- crates of a won night by length
	var rewards := Rewards.new()
	rewards.stored = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var table := {}
	for level: String in ["easy", "normal", "hard", "nightmare"]:
		for length: String in HiveLayout.LENGTH_ORDER:
			var got := 0
			var kinds := {}
			for i in range(400):
				var tiers := rewards.earn_night(level, length, rng)
				got += tiers.size()
				for t: String in tiers:
					kinds[t] = int(kinds.get(t, 0)) + 1
			table["%s/%s" % [level, length]] = [got, kinds]
	print("crates per 400 won nights: ", table)
	if int(table["easy/medium"][0]) <= int(table["easy/short"][0]):
		faults.append("MITTEL is not worth more than KURZ on easy")
	if int(table["easy/long"][0]) != 400 or not (table["easy/long"][1] as Dictionary).has("hard"):
		faults.append("LANG is not a sure crate a tier better")
	if int(table["hard/max"][0]) != 800 or int(table["nightmare/max"][0]) != 1200 or int(table["nightmare/long"][0]) != 800:
		faults.append("MAXIMAL does not give two (three on ALBTRAUM)")
	if int(table["nightmare/short"][0]) != 400 or not (table["nightmare/short"][1] as Dictionary).has("nightmare"):
		faults.append("ALBTRAUM KURZ is not a sure special crate")
	# --- the endless night: plateaus, better with time, two on ALBTRAUM
	var said: Array = []
	for level: String in ["normal", "hard", "nightmare"]:
		var steps: Array = []
		for k in range(Rewards.ENDLESS_STEPS.size()):
			steps.append(Rewards.endless_tiers(level, k))
		said.append("%s %s" % [level, steps])
	print("endless: ", said)
	if Rewards.endless_tiers("normal", 0) != ["plain"] or Rewards.endless_tiers("normal", 2) != ["nightmare"] or Rewards.endless_tiers("hard", 0) != ["hard"] or Rewards.endless_tiers("nightmare", 0).size() != 2:
		faults.append("the endless plateaus are wrong")
	# --- a special crate gives two prizes
	rewards.stock = {"plain": 0, "hard": 0, "nightmare": 0}
	rewards.grant_crate("nightmare")
	rewards.grant_crate("plain")
	var special := rewards.open_crate(rng)
	var plain := rewards.open_crate(rng)
	if str(special.tier) != "nightmare" or (special.extra as Array).size() != 1 or not (plain.extra as Array).is_empty():
		faults.append("the special crate does not give two prizes")
	# --- the backpack: a weapon skin comes along only with it, and one
	rewards.owned.clear()
	rewards.waiting.clear()
	rewards.taken.clear()
	rewards.worn.clear()
	for id in ["neon/wirbel", "pfau/nitro", "rucksack"]:
		rewards.add(id, 3)
	rewards.take("neon/wirbel")
	var without := rewards.weapons_taken().is_empty() and not rewards.taken.has("neon/wirbel")
	rewards.take("rucksack")
	rewards.take("neon/wirbel")
	rewards.take("pfau/nitro")
	var with := rewards.weapons_taken() == ["nitro"]
	rewards.take("rucksack")
	var dropped := rewards.weapons_taken().is_empty() and not rewards.taken.has("pfau/nitro")
	if not (without and with and dropped):
		faults.append("backpack rule: without %s with %s dropped %s" % [without, with, dropped])
	# --- the paces of the plain infected
	var paces := {}
	for i in range(1000):
		var f := Infected.gait_factor(i / 1000.0)
		paces[f] = int(paces.get(f, 0)) + 1
	print("mauler paces per 1000: ", paces)
	if paces.size() != 3 or int(paces.get(1.0, 0)) < 500:
		faults.append("the paces are wrong")
	if faults.is_empty():
		print("V088 CHECK OK")
	else:
		for fault in faults:
			print("FAULT: ", fault)
		print("V088 CHECK FAILED (%d)" % faults.size())
	quit(0 if faults.is_empty() else 1)
