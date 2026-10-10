class_name HiveProwler
extends Node
## When and where the Prowler shows itself in mission two (its body and mind: Prowler).
## A node of the mission's director: it reads the stage that runs and uses the director's
## places out of sight.
##
## It belongs to the facility: its first visit comes once the squad is inside it (the
## administration and what follows), in a place with room, and it shows itself there
## before it attacks. After that it comes again at no beat one could count: its call from
## somewhere the squad does not look, a moment later the animal itself. It attacks for a
## short while, breaks off when it has taken enough or been there long enough, runs and
## is gone - and comes back later, bolder each time. On these visits it cannot die. In
## the containment hall it comes for good: enraged, with all its health on the bar, and
## now it can be killed. The mission does not wait for that: when the lift is there and
## it still lives, it lets go one last time.
##
## It is a three-metre animal and keeps to where it has room. It only comes when the
## squad stands on open ground (ROOM_MIN), from a lair whose way to them has no tight
## stretch longer than a doorway (WIDE, TIGHT_RUN), and when they withdraw into
## something tight it does not squeeze after them: it prowls where it is, in sight if it
## can, and after a while it goes (Prowler.LURK_SECONDS) - which is not being driven off.

## Stages in which it never comes: everything before the facility, the hold in the
## canteen (hard enough as it is), the lock, the way out.
const AWAY := ["landing", "villa", "mirror", "descent", "station", "nadja", "deal", "power", "hold", "board", "ride", "terminal", "lockdown", "decon", "exit"]
## The first stage it may come in.
const FIRST_STAGE := "admin"
## Free ground in square metres, within ROOM_REACH metres of walking around the survivor,
## that a place needs for it to come there - and the less that is enough for it to stay
## once it is there. (A passage two metres wide has about 24, one of six metres 70, one
## of eight 95, the middle of a hall 110. Rooms of nine by twelve metres with furniture
## come to 60-80: it follows the squad into those, but does not begin a visit there.)
const ROOM_REACH := 6.0
const ROOM_MIN := 70.0
const ROOM_STAY := 55.0
## A passage narrower than this is tight (the door ways and side passages of two metres
## are; a lane between two rows of tables is not); it goes through no more than
## TIGHT_RUN metres of that in a row (a doorway, not a corridor).
const WIDE := 2.5
const TIGHT_RUN := 3.0
## Seconds at the start of a stage in which it stays away.
const STAGE_QUIET := 12.0
## Seconds between two visits, picked anew each time, and by how much of that every
## visit made shortens the wait (down to GAP_LEAST of it).
const GAP := Vector2(70.0, 140.0)
const GAP_BOLDER := 0.08
const GAP_LEAST := 0.6
## The wait before its first visit, once the squad is inside the facility.
const FIRST_GAP := Vector2(6.0, 20.0)
## Its call is heard this many seconds before it is there.
const CALL_LEAD := Vector2(2.2, 3.4)
## How far from the squad it comes out of the dark, and how far off it runs to.
const LAIR := Vector2(13.0, 26.0)
const WAY_OUT := Vector2(18.0, 36.0)
## What it takes on a visit before it breaks off, and the seconds it stays at most:
## x on its first visit, y more with every visit after that (up to BOLD_MOST of them).
const NERVE := Vector2(2200.0, 600.0)
const STAY := Vector2(26.0, 5.0)
const BOLD_MOST := 4
## The last fight (stage "hall"): its health, less by WEAR for every visit on which the
## squad drove it off by force (at most WEAR_MOST of them), and how many seconds into
## the stage its call is heard.
const END_HEALTH := 4800.0
const WEAR := 0.06
const WEAR_MOST := 4
const END_AFTER := 5.0
## While the last fight is on, the horde comes slower: this share of every second is
## added to the director's wait for its next one.
const END_HUSH := 0.6
## Nearer than this to the survivor it has to have come for a visit to count as one.
const REACHED := 10.0

var director: HiveDirector
var game: Node3D
var beast: Prowler
## A visit is on. (Not "beast != null": a body that has been freed counts as null, and it
## is freed when it has run far enough - in a bot run at four times the speed within one frame.)
var visiting := false
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
## It has shown itself once (the first visit begins with that).
var shown := false
## How near it came to the survivor on this visit (for the logs of automatic runs).
var nearest := 99.0

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
	visiting = false
	call_left = -1.0
	final_sent = false
	killed = false
	wounds = 0
	search_for = 0.0
	# Taken up again further down, it is as bold as it would be by then.
	var behind: int = HiveDirector.ORDER.find(from) - HiveDirector.ORDER.find(FIRST_STAGE)
	visits = maxi(0, behind / 3)
	told_squad = behind > 0
	told_command = behind > 0
	shown = behind > 0
	wait_left = randf_range(FIRST_GAP.x, FIRST_GAP.y) if behind <= 0 else randf_range(15.0, 40.0)

func end() -> void:
	beast = null
	visiting = false
	call_left = -1.0

func _process(delta: float) -> void:
	if director == null or not director.on or game == null or not game.is_playing() or director.intro_left > 0.0:
		return
	var stage := director.stage
	if visiting:
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
		# Only where the squad stands in the open, and from where it has room to come.
		lair = _behind(LAIR.x, LAIR.y) if open_ground(game.player.global_position) >= ROOM_MIN else Vector3.INF
		if lair == Vector3.INF:
			# Not here: a little later, a little further on.
			wait_left = 1.5
		else:
			_call()

## A place out of sight to come from: of a few, the one most behind the survivor's back.
func _behind(nearest: float, furthest: float) -> Vector3:
	var here: Vector3 = game.player.global_position
	var ahead: Vector3 = -game.player.camera.global_basis.z
	var best := Vector3.INF
	var best_side := 2.0
	for attempt in range(4):
		var spot := director._hidden_spot(nearest, furthest)
		if spot == Vector3.INF or not wide_way(spot, here):
			continue
		var to := spot - here
		var side := Vector2(ahead.x, ahead.z).normalized().dot(Vector2(to.x, to.z).normalized())
		if side < best_side:
			best_side = side
			best = spot
	return best

## The sound the squad learns to fear: from where it will come, a moment before it does.
func _call() -> void:
	call_left = randf_range(CALL_LEAD.x, CALL_LEAD.y)
	game.sounds.play_at("prowler_call", lair + Vector3(0, 1.2, 0), 5.0)

func _end_fight(delta: float) -> void:
	if final_sent or director.stage_time < END_AFTER:
		return
	if call_left < 0.0:
		search_for += delta
		lair = _behind(13.0, 28.0)
		if lair == Vector3.INF and search_for > 3.0:
			# The hall hides nothing: then it comes in plain view.
			lair = _open_spot(16.0, 26.0)
		if lair == Vector3.INF and search_for > 8.0:
			# The squad has backed into a corner of it: the last fight comes all the same.
			lair = director._hidden_spot(13.0, 28.0)
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
		if way.size() >= 2 and way[way.size() - 1].distance_to(here) >= nearest * 0.7 and wide_way(way[way.size() - 1], here):
			return way[way.size() - 1]
	return Vector3.INF

func _arrive(for_good: bool) -> void:
	call_left = -1.0
	# The squad has moved on since the call and would see it appear: then from somewhere else.
	if director._sees(game.player.camera.global_position, lair + Vector3(0, 1.3, 0)):
		var other := _behind(LAIR.x, LAIR.y)
		if other != Vector3.INF:
			lair = other
	visiting = true
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
	beast.roomy = may_follow
	beast.width = width_of
	# The first time it shows itself before it attacks.
	beast.herald = visits == 0 and not for_good and not shown
	shown = true
	beast.bold = mini(visits, BOLD_MOST)
	var tough := float(game.rules.get("health", 1.0))
	last = for_good
	present_for = 0.0
	nearest = 99.0
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
		print("PROWLER_VISIT n=%d stage=%s final=%s nerve=%d health=%d gap=%.1f room=%s ground=%d" % [visits, director.stage, str(for_good), int(beast.nerve), int(beast.max_health), lair.distance_to(game.player.global_position), str(director.map.room_at(game.player.global_position).get("id", "?")), int(open_ground(game.player.global_position))])
	# The first time somebody of the squad says what everybody saw, and command says it once
	# its channel is its own. Both wait their turn in the mission's one queue of lines.
	if not told_squad:
		told_squad = true
		director.shout("stalker")
	if not told_command and not director.channel_taken():
		told_command = true
		director.line("stalker_seen")

## Where it runs to when it breaks off.
func _way_out() -> Vector3:
	var fallback := Vector3.INF
	for attempt in range(3):
		var spot := director._hidden_spot(WAY_OUT.x, WAY_OUT.y)
		if spot == Vector3.INF:
			continue
		if is_instance_valid(beast) and wide_way(beast.global_position, spot):
			return spot
		fallback = spot
	return fallback

# ---------------------------------------------------------------- room to move

func _grid(pos: Vector3) -> AStarGrid2D:
	return director.map.navigation[director.map.level_of(pos)]

static func _cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CabinMap.CELL), roundi(pos.z / CabinMap.CELL))

## Free ground in square metres that can be walked to from a place without going further
## than ROOM_REACH from it: what there is to circle in.
func open_ground(pos: Vector3) -> float:
	var grid := _grid(pos)
	var start := _cell(pos)
	if not grid.is_in_boundsv(start) or grid.is_point_solid(start):
		return 0.0
	var reach := ROOM_REACH / CabinMap.CELL
	var seen := {start: true}
	var open: Array[Vector2i] = [start]
	var at := 0
	while at < open.size():
		var cell := open[at]
		at += 1
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + step
			if seen.has(next) or Vector2(next - start).length() > reach or not grid.is_in_boundsv(next) or grid.is_point_solid(next):
				continue
			seen[next] = true
			open.append(next)
	return open.size() * CabinMap.CELL * CabinMap.CELL

## How wide the passage is at a place: the shorter of the free stretches across it
## (east to west, north to south), in metres, up to 8.5.
func width_of(pos: Vector3) -> float:
	var grid := _grid(pos)
	var cell := _cell(pos)
	if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
		return 0.0
	var least := 99.0
	for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var run := 1
		for side: int in [1, -1]:
			for step in range(1, 9):
				var next := cell + axis * side * step
				if not grid.is_in_boundsv(next) or grid.is_point_solid(next):
					break
				run += 1
		least = minf(least, run * CabinMap.CELL)
	return least

## True when the way between two places has no tight stretch longer than a doorway.
func wide_way(from: Vector3, to: Vector3) -> bool:
	if director.map.level_of(from) != director.map.level_of(to):
		return false
	var way: PackedVector3Array = director.map.path_between(from, to)
	if way.size() < 2:
		return false
	var tight := 0.0
	for i in range(1, way.size()):
		var piece := way[i - 1].distance_to(way[i])
		var parts := maxi(1, ceili(piece / CabinMap.CELL))
		for part in range(parts):
			if width_of(way[i - 1].lerp(way[i], (part + 0.5) / parts)) < WIDE:
				tight += piece / parts
				if tight > TIGHT_RUN:
					return false
			else:
				tight = 0.0
	return true

## Whether it goes for somebody from where it stands: he is on open ground, and the way to
## him is wide. (What the Prowler asks while it hunts.)
func may_follow(from: Vector3, to: Vector3) -> bool:
	return open_ground(to) >= ROOM_STAY and wide_way(from, to)

func _attend(delta: float, stage: String) -> void:
	present_for += delta
	nearest = minf(nearest, beast.global_position.distance_to(game.player.global_position))
	# The bar is its own while it is there, whoever else turns up.
	game.boss = beast
	if last:
		director.pressure_left += delta * END_HUSH
		if stage != "hall":
			# The lift is there: it lets go one last time.
			beast.break_off(false)
	elif present_for > stay or not comes_in(stage, STAGE_QUIET):
		beast.break_off(false)

## The visit is over: it runs (`hurt`: because it had taken enough), or it is dead.
func _close(hurt: bool, died: bool) -> void:
	var lurked: bool = is_instance_valid(beast) and beast.lurked > 0.0
	if game.check_mode:
		print("PROWLER_GONE n=%d stage=%s after=%.1f hurt=%s died=%s landed=%d nearest=%.1f lurked=%.1f" % [visits, director.stage, present_for, str(hurt), str(died), beast.landed if is_instance_valid(beast) else -1, nearest, beast.lurked if is_instance_valid(beast) else -1.0])
	beast = null
	visiting = false
	if not last:
		if nearest > REACHED and not hurt and not lurked:
			# It never got to them (a door shut between them): that was no visit, and it tries again soon.
			wait_left = randf_range(8.0, 20.0)
		else:
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
	director.line("stalker_dead")
