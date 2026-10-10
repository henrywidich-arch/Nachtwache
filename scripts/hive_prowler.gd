class_name HiveProwler
extends Node
## When and where the Prowler shows itself in mission two (its body and mind: Prowler).
## A node of the mission's director: it reads the stage that runs and uses the director's
## places out of sight.
##
## From the way down behind the mirror on it comes again and again, at no beat one could
## count: its call from somewhere the squad does not look, a moment later the animal
## itself. It attacks for a short while, breaks off when it has taken enough or been there
## long enough, runs and is gone - and comes back later, a little bolder each time. On
## these visits it cannot die. In the containment hall it comes for good: enraged, with
## all its health on the bar, and now it can be killed. The mission does not wait for
## that: when the lift is there and it still lives, it lets go one last time.

## Stages in which it never comes: above ground (it lives below), the truce at the
## station, boarding and the ride, the lock, the way out.
const AWAY := ["landing", "villa", "mirror", "nadja", "deal", "board", "ride", "decon", "exit"]
## Seconds at the start of a stage in which it stays away.
const STAGE_QUIET := 12.0
## Seconds between two visits, picked anew each time, and by how much of that every
## visit made shortens the wait (down to GAP_LEAST of it).
const GAP := Vector2(50.0, 105.0)
const GAP_BOLDER := 0.08
const GAP_LEAST := 0.55
## The wait before its first visit, once the squad is on the way down.
const FIRST_GAP := Vector2(4.0, 12.0)
## Its call is heard this many seconds before it is there.
const CALL_LEAD := Vector2(2.2, 3.4)
## How far from the squad it comes out of the dark, and how far off it runs to.
const LAIR := Vector2(13.0, 26.0)
const WAY_OUT := Vector2(18.0, 36.0)
## What it takes on a visit before it breaks off, and the seconds it stays at most:
## x on its first visit, y more with every visit after that (up to BOLD_MOST of them).
const NERVE := Vector2(2200.0, 450.0)
const STAY := Vector2(26.0, 4.0)
const BOLD_MOST := 5
## The last fight (stage "hall"): its health, less by WEAR for every visit on which the
## squad drove it off by force (at most WEAR_MOST of them), and how many seconds into
## the stage its call is heard.
const END_HEALTH := 6000.0
const WEAR := 0.05
const WEAR_MOST := 5
const END_AFTER := 5.0

var director: HiveDirector
var game: Node3D
var beast: Prowler
## Visits made, and how many of them ended because it had taken enough.
var visits := 0
var wounds := 0
var wait_left := 0.0
## Seconds until it is there (its call has been heard); below 0: no call is out.
var call_left := -1.0
var lair := Vector3.INF
var present_for := 0.0
var stay := 0.0
var last := false
var final_sent := false
var killed := false
var told_squad := false
var told_command := false
var search_for := 0.0

## True when it may come: the stage is one of its own and has run for a while.
static func comes_in(stage: String, stage_time: float) -> bool:
	return stage != "" and stage != "hall" and not AWAY.has(stage) and stage_time >= STAGE_QUIET

static func nerve_on(visit: int) -> float:
	return NERVE.x + NERVE.y * mini(visit, BOLD_MOST)

static func stay_on(visit: int) -> float:
	return STAY.x + STAY.y * mini(visit, BOLD_MOST)

static func gap_after(visit: int) -> float:
	return randf_range(GAP.x, GAP.y) * maxf(GAP_LEAST, 1.0 - GAP_BOLDER * visit)

static func end_health(wounds_taken: int) -> float:
	return END_HEALTH * (1.0 - WEAR * mini(wounds_taken, WEAR_MOST))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

## A night on the map of mission two begins, at the stage `from` (a checkpoint).
func begin(from: String) -> void:
	game = director.game
	beast = null
	call_left = -1.0
	final_sent = false
	killed = false
	wounds = 0
	search_for = 0.0
	# Taken up again further down, it is as bold as it would be by then.
	var behind: int = HiveDirector.ORDER.find(from) - HiveDirector.ORDER.find("descent")
	visits = maxi(0, behind / 4)
	told_squad = behind > 0
	told_command = behind > 0
	wait_left = randf_range(FIRST_GAP.x, FIRST_GAP.y) if behind <= 0 else randf_range(15.0, 40.0)

func end() -> void:
	beast = null
	call_left = -1.0

func _process(delta: float) -> void:
	if director == null or not director.on or game == null or not game.is_playing() or director.intro_left > 0.0:
		return
	var stage := director.stage
	if beast != null:
		if not is_instance_valid(beast):
			# Taken off the field with everybody else (the ride).
			_close(false, false)
		elif beast.leaving:
			_close(beast.broke_hurt, false)
		elif beast.dead:
			_close(false, true)
		else:
			_attend(delta, stage)
		return
	if killed:
		return
	if stage == "hall":
		_end_fight(delta)
		return
	if AWAY.has(stage):
		call_left = -1.0
		return
	# (The wait goes on through the first seconds of a stage; only its coming is put off.)
	if call_left < 0.0:
		wait_left -= delta
	if not comes_in(stage, director.stage_time):
		call_left = -1.0
		return
	if call_left >= 0.0:
		call_left -= delta
		if call_left <= 0.0:
			_arrive(false)
		return
	if wait_left <= 0.0:
		lair = director._hidden_spot(LAIR.x, LAIR.y)
		if lair == Vector3.INF:
			# Nowhere to come from here: a little later, a little further on.
			wait_left = 3.0
		else:
			_call()

## The sound the squad learns to fear: from where it will come, a moment before it does.
func _call() -> void:
	call_left = randf_range(CALL_LEAD.x, CALL_LEAD.y)
	game.sounds.play_at("prowler_call", lair + Vector3(0, 1.2, 0), 5.0)

func _end_fight(delta: float) -> void:
	if final_sent or director.stage_time < END_AFTER:
		return
	if call_left < 0.0:
		search_for += delta
		lair = director._hidden_spot(13.0, 28.0)
		if lair == Vector3.INF and search_for > 3.0:
			# The hall hides nothing: then it comes in plain view.
			lair = _open_spot(16.0, 26.0)
		if lair != Vector3.INF:
			_call()
		return
	call_left -= delta
	if call_left <= 0.0:
		final_sent = true
		_arrive(true)

## A place that can be walked to from the squad, seen or not.
func _open_spot(nearest: float, furthest: float) -> Vector3:
	var here: Vector3 = game.player.global_position
	for attempt in range(12):
		var turn := randf() * TAU
		var spot := here + Vector3(cos(turn), 0, sin(turn)) * randf_range(nearest, furthest)
		var way: PackedVector3Array = director.map.path_between(here, spot)
		if way.size() >= 2 and way[way.size() - 1].distance_to(here) >= nearest * 0.7:
			return way[way.size() - 1]
	return Vector3.INF

func _arrive(for_good: bool) -> void:
	call_left = -1.0
	beast = Prowler.new()
	beast.game = game
	beast.wave = maxi(1, game.wave)
	beast.kind = "prowler"
	beast.uncounted = true
	beast.position = lair + Vector3(0, 0.08, 0)
	beast.net_id = game.next_net_id
	game.next_net_id += 1
	game.enemies.add_child(beast)
	var to: Vector3 = game.player.global_position - lair
	beast.model.rotation.y = atan2(-to.x, -to.z)
	beast.lair = _way_out
	beast.bold = mini(visits, BOLD_MOST)
	var tough := float(game.rules.get("health", 1.0))
	last = for_good
	present_for = 0.0
	if for_good:
		beast.max_health = end_health(wounds) * tough
		beast.health = beast.max_health
		beast.nerve = 0.0
		beast.enrage()
		game.hud.announce("DER PROWLER RAST", "Diesmal geht er nicht mehr. Bringt ihn zu Fall!", 4.5)
	else:
		beast.nerve = nerve_on(visits) * tough
		stay = stay_on(visits)
	game.boss = beast
	if game.check_mode:
		print("PROWLER_VISIT n=%d stage=%s final=%s nerve=%d health=%d gap=%.1f" % [visits, director.stage, str(for_good), int(beast.nerve), int(beast.max_health), lair.distance_to(game.player.global_position)])
	# The first time somebody says what everybody saw; command says it once its channel is its own.
	if not told_squad:
		told_squad = true
		var speaker: Teammate = game.squad_voice()
		if speaker != null:
			game.bark(speaker, speaker.look, "stalker")
	if not told_command and (director.done.has("radio_clear") or HiveDirector.ORDER.find(director.stage) > HiveDirector.ORDER.find("deal")):
		told_command = true
		game.radio("stalker_seen", 8.0)

## Where it runs to when it breaks off.
func _way_out() -> Vector3:
	return director._hidden_spot(WAY_OUT.x, WAY_OUT.y)

func _attend(delta: float, stage: String) -> void:
	present_for += delta
	# The bar is its own while it is there, whoever else turns up.
	game.boss = beast
	if last:
		if stage != "hall":
			# The lift is there: it lets go one last time.
			beast.break_off(false)
	elif present_for > stay or not comes_in(stage, STAGE_QUIET):
		beast.break_off(false)

## The visit is over: it runs (`hurt`: because it had taken enough), or it is dead.
func _close(hurt: bool, died: bool) -> void:
	if game.check_mode:
		print("PROWLER_GONE n=%d stage=%s after=%.1f hurt=%s died=%s landed=%d" % [visits, director.stage, present_for, str(hurt), str(died), beast.landed if is_instance_valid(beast) else -1])
	beast = null
	if not last:
		visits += 1
		if hurt:
			wounds += 1
		wait_left = gap_after(visits)
	# A Crusher that is still on the field has the bar back.
	for node in game.enemies.get_children():
		var other := node as Infected
		if other != null and other.kind == "crusher" and not other.dead:
			game.boss = other
	if died:
		killed = true
		_reward()

## It is dead: the squad is patched up, its vests are whole again, and command has a word.
func _reward() -> void:
	var player: Survivor = game.player
	if player.down:
		player.get_up()
	player.health = 100.0
	player.armor = maxf(player.armor, 100.0)
	player.resupply(Survivor.ROUND_AMMO)
	for mate in game.team:
		mate.revive(true)
	game.sounds.play_sound("clear")
	game.hud.announce("DER PROWLER IST TOT", "+%d Vorrat  ·  Trupp versorgt  ·  Westen geflickt" % int(Infected.TYPES.prowler.reward), 5)
	game.radio("stalker_dead", 8.0)
