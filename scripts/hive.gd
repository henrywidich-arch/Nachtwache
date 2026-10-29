class_name HiveDirector
extends Node
## Runs the second mission on its own map (HiveMap): from the landing in the park of the
## villa, through the house and down behind the mirror, to the hidden station, by train
## to the facility and through it to the containment hall.
##
## There are no rounds here. The night is a row of stages; each has a goal on the HUD and
## a marker, its own enemies - some wait in the rooms ahead, more keep coming from where
## nobody looks - and ends when its goal is reached. Three times a place has to be held
## for a while. To the game this is a night that never begins (as in the test room): the
## director keeps the next round from ever starting and spawns by itself.
##
## What is said is the mission's own dialogue (Radio, the cues m2_...): command over the
## radio - until the channel is cleared at the station that is not Coleman's voice -, Nadja
## and the operators where they stand, Nadja over the loudspeakers of the facility, and
## the squad among itself. All of it waits its turn in one queue (see "what is said").

## The stages in their order: what the HUD calls the place, the goal, the place the marker
## points at, and how strong the enemies are there (as a round of the first mission).
const ORDER := ["landing", "villa", "mirror", "descent", "station", "nadja", "deal", "power", "hold", "board", "ride", "terminal", "admin", "security", "cafe", "lockdown", "atrium", "generator", "decon", "labs", "hall", "exit"]
const STAGES := {
	"landing": ["DER PARK", "Zur Villa vordringen", "front_door", 2],
	"villa": ["DIE VILLA", "Den Speisesaal finden", "dining", 3],
	"mirror": ["DIE VILLA", "Nadja decken, bis der Zugang offen ist", "keypad", 3],
	"descent": ["DER ABSTIEG", "Die Treppe hinunter zum Stahltor", "lobby", 4],
	"station": ["DER BAHNHOF", "Den Bahnsteig von den Infizierten säubern", "platform", 4],
	"nadja": ["DER BAHNHOF", "Bei Nadja bleiben", "nadja_door", 4],
	"deal": ["DER BAHNHOF", "Im Stellwerk den Zug hochfahren  ·  nebenbei Sicherungen und Benzin", "booth", 4],
	"power": ["DER BAHNHOF", "Im Stellwerk den Zug hochfahren", "booth", 5],
	"hold": ["DER BAHNHOF", "Den Bahnsteig halten, bis der Zug bereit ist", "platform", 5],
	"board": ["DER BAHNHOF", "In den Zug einsteigen", "car_a", 5],
	"ride": ["IM TUNNEL", "Festhalten", "", 5],
	"terminal": ["DAS TERMINAL", "Im Leitstand das Tor zur Anlage öffnen", "control", 5],
	"admin": ["DIE VERWALTUNG", "Durch die Kontrolle in die Anlage", "junction", 6],
	"security": ["DIE VERWALTUNG", "In der Sicherheitszentrale die Sperre aufheben", "security", 6],
	"cafe": ["DIE VERWALTUNG", "Durch die Kantine nach Norden", "cafeteria", 6],
	"lockdown": ["DIE KANTINE", "Die Abriegelung überstehen", "cafeteria", 7],
	"atrium": ["ZENTRALRAUM B2", "Zum Zentralraum vorstoßen", "atrium", 7],
	"generator": ["DIE TECHNIK", "Im Generatorraum den Notstrom der Schleuse einschalten", "generator", 7],
	"decon": ["DIE SCHLEUSE", "Durch die Dekontamination in den Forschungstrakt", "decon", 7],
	"labs": ["DIE FORSCHUNG", "Durch den Laborgang zur Eindämmungshalle", "cross", 8],
	"hall": ["DIE EINDÄMMUNG", "Die Halle freikämpfen", "hall_end", 9],
	"exit": ["DIE EINDÄMMUNG", "Zum Frachtaufzug", "lift", 9],
	# (v0.88) The endless night of the second mission (see endless): not in ORDER.
	"endless": ["TOKIO-SIMULATION", "Überlebt so lange wie möglich", "", 5]
}
## Whether this night is the endless one (the host's choice, Profile.hive_mode; it goes to a
## co-op guest with the night).
var endless: bool:
	get: return on and bool(night.get("endless", false))

## Where a defeat can be taken up again: the stage, the place the squad stands at then,
## the areas that are open by then, and what there is to spend at the supply point there.
const CHECKPOINTS := {
	"landing": {"at": "landing_out", "open": [], "credits": 120},
	"descent": {"at": "dining", "open": ["descent"], "credits": 500},
	"terminal": {"at": "car_b", "open": ["descent", "station"], "credits": 900},
	"atrium": {"at": "atrium_south", "open": ["descent", "station", "admin", "cafe", "atrium"], "credits": 1300},
	"labs": {"at": "labs_south", "open": ["descent", "station", "admin", "cafe", "atrium", "decon", "research"], "credits": 1700}
}
## Who keeps coming while a stage lasts: the kinds (drawn at random), how many may be alive
## at once, the seconds between two deliveries, where they come from ("park": over the
## park's wall; "hidden": anywhere near that the squad cannot see), and how many a
## delivery through a way in brings, at the least and at the most. Under a roof nearly
## every delivery is such a pack: it pours out of a hole in a ceiling or a wall, out of a
## duct, through a window, one behind the other (see HiveEntries) - the next pack out of
## another one, so that a stage that lasts has the squad under attack from several sides.
## A delivery that finds no way in is one body, as it always was, and the next is sooner
## (LONE of the time). The numbers are those of NORMAL: see _crowd for the other levels.
const PRESSURE := {
	# (The first stages are gentle: the squad has only what it landed with.)
	"landing": [["mauler", "mauler", "mauler", "striker"], 3, 7.0, "park", [1, 1]],
	"villa": [["mauler", "mauler", "mauler", "striker"], 5, 8.0, "hidden", [2, 2]],
	# (Where the squad holds a place - the dining room, the platform, the canteen, the hall
	# of towers - they come faster than three guns put them down: it fills up.)
	"mirror": [["mauler", "mauler", "striker", "ripper"], 7, 5.5, "hidden", [2, 3]],
	"descent": [["mauler", "ripper"], 4, 8.0, "hidden", [2, 2]],
	"hold": [["mauler", "mauler", "striker", "ripper", "charger", "leech"], 12, 5.5, "hidden", [3, 4]],
	# (Where it is on its way they come in packs it can fight down and walk on from.
	# The terminal had nobody coming at all: once its hall was cleared it stayed empty.)
	"terminal": [["mauler", "mauler", "striker", "ripper", "leech"], 8, 10.0, "hidden", [2, 4]],
	"admin": [["mauler", "mauler", "striker", "ripper"], 8, 10.0, "hidden", [2, 3]],
	"security": [["mauler", "striker", "ripper", "leech"], 8, 10.0, "hidden", [2, 4]],
	"cafe": [["mauler", "striker", "ripper"], 8, 10.0, "hidden", [2, 3]],
	"lockdown": [["mauler", "mauler", "striker", "ripper", "charger", "leech", "healer"], 13, 5.5, "hidden", [3, 4]],
	"atrium": [["mauler", "striker", "ripper", "leech"], 8, 10.0, "hidden", [2, 4]],
	"generator": [["ripper", "ripper", "leech", "mauler", "striker"], 9, 9.0, "hidden", [2, 4]],
	"labs": [["mauler", "striker", "ripper", "leech", "healer"], 9, 9.5, "hidden", [2, 4]],
	"hall": [["mauler", "striker", "ripper", "charger", "leech", "cru_assault", "cru_shotgunner"], 10, 6.5, "hidden", [3, 4]],
	# (The endless night begins here and gets worse with every minute: _endless_plan.)
	"endless": [["mauler", "mauler", "mauler", "striker", "ripper"], 8, 7.0, "hidden", [2, 3]]
}
## (v0.88) The endless night of the second mission (Henry): the squad is set down in the
## simulation hall and holds out there as long as it can, no goal, no end but its fall.
## Every ENDLESS_RAMP seconds it gets worse: more alive at once, deliveries sooner, bigger
## packs, tougher kinds (ENDLESS_KINDS, one list more each step) and stronger infected
## (game.wave). Crates come at plateaus of the time survived (Rewards.ENDLESS_STEPS).
const ENDLESS_RAMP := 120.0
const ENDLESS_KINDS := [["charger", "leech"], ["healer", "ripper"], ["cru_assault", "charger"], ["cru_shotgunner", "leech", "ripper"], ["cru_elite", "charger"]]
const ENDLESS_CREDITS := 1500
## (For the checks: the next night is the endless one whatever the profile says.)
var endless_wanted := false
const LONE := 0.5
## How often a kind that the dice chose really comes; a Mauler comes in its place the
## other times. (The Striker stands in nearly every list above and left its growths
## everywhere; the Charger only a little too often.)
const THIN := {"striker": 0.35, "charger": 0.88}
## How many may be alive at once in this mission whatever a stage and a level say (the
## squad's guns and the answer to camping come on top): what the frame rate was measured
## with.
const CROWD_LIMIT := 24
## (v0.90, Henry: the simulation hall felt empty.) While the squad is in it, this many more
## may be alive at once, and they come this much sooner (its streets are wide and open).
const TOKYO_MORE := 4
const TOKYO_HASTE := 0.75
## Who the plain infected of this mission were. Besides the looks they have everywhere, a
## share of them wears what the people here wore: "above" (the villa and the station) now
## and then somebody of the guard, a worker or a civilian; "below" (the facility, from the
## terminal on) mostly its staff - scientists, laboratory people, nurses, workers, guards.
## Each: the looks (a look listed twice turns up twice as often), and the share of the
## plain infected that wear one of them.
const STAFF := {
	"above": [["hive_security", "hive_worker", "hive_civilian", "zombie_soldier"], 0.3],
	"below": [["hive_scientist", "hive_scientist2", "hive_lab", "hive_nurse", "hive_worker", "hive_security", "hive_civilian", "hive_office", "hive_office2", "hive_lab2", "zombie_soldier"], 0.75]
}
## Where a stage is the place of some of these people, their looks come there more often:
## every look listed here is one more draw beside STAFF's own (the others stay in the mix).
## The administration is offices, the security centre and the station were guarded by
## soldiers, the laboratories are the scientists'.
const STAFF_PLACES := {
	"station": ["zombie_soldier", "zombie_soldier"],
	"admin": ["hive_office", "hive_office2", "hive_office", "hive_office2", "hive_office", "hive_office2"],
	"security": ["zombie_soldier", "zombie_soldier", "zombie_soldier", "hive_security", "hive_security"],
	"cafe": ["hive_office", "hive_office2"],
	"labs": ["hive_lab2", "hive_lab2", "hive_lab2", "hive_lab", "hive_lab", "hive_scientist", "hive_scientist2"],
	"generator": ["hive_lab2", "hive_worker"],
	"decon": ["hive_lab2", "hive_lab", "hive_nurse"]
}
## The seconds the train takes to come up with all three fuses of the platform on (see
## "the fuses": with fewer it takes longer, every canister of fuel already in it makes it
## shorter). It was 80 with nothing to do meanwhile, then 45.
const HOLD_STATION := 30.0
const HOLD_CAFE := 70.0
const HOLD_HALL := 60.0
const KEYPAD_SECONDS := 20.0
const RIDE_SECONDS := 15.0
const NADJA_HEALTH := 260.0
const INTRO_SECONDS := 6.5
const START_ARMOUR := 50.0
## The ink of a speaker's words on the radio's panel (command's is the panel's own).
const INK := {"nadja": Color("f2a9c4"), "phantom": Color("69c8ff"), "havoc": Color("69c8ff"), "ghost": Color("69c8ff"), "viper": Color("cfe6d2"), "scorpion": Color("cfe6d2"), "raven": Color("cfe6d2")}
## A word of the squad that has waited this long for its turn is about something long over.
const STALE := 45.0
## From this far a line said in person is heard at its full level.
const VOICE_REACH := 11.0
## The rooms of the research wing that stand full of what Nadja has made.
const LAB_ROOMS := ["lab_corridor", "lab_a", "lab_b", "lab_c", "quarantine", "cryo", "flooded"]
## The emergency power of the station: three fuse boxes on pillars of the platform (x, z of
## the box, and which way along z it faces). While Nadja leaves and the operators talk the
## squad can switch them on; the train comes up the faster the more of them are on
## (FUSE_PACE by how many: all three is HOLD_STATION). While it comes up one of them trips
## once (FUSE_TRIPS: the share of the way at which it may) and has to be switched on again.
## Every switch is loud: a few infected come to see (FUSE_DRAW).
const FUSES := [[-16.0, -48.52, 1.0], [-8.0, -41.48, -1.0], [24.0, -48.52, 1.0]]
const FUSE_PACE := [0.25, 0.4, 0.6, 1.0]
const FUSE_TRIPS := [[0.35, 0.7]]
const FUSE_REACH := 2.2
const FUSE_DRAW := [["mauler", "striker"], ["mauler", "mauler", "ripper"]]
## The stages in which the fuses are there to be switched.
const FUSE_STAGES := ["nadja", "deal", "power", "hold"]
## The train runs dry: canisters of fuel stand about the station (x, z on the floor of the
## platform's level: the workshop, the depot, both ends of the platform). A human carries
## one at a time ([E]) and fills it into the train at its tank beside the car (TANK: where
## one stands for it). The train only leaves with FUEL_NEEDED of them in it; every one that
## is filled also brings it FUEL_BOOST of the way up. They can be taken up as soon as the
## platform is reached (FUEL_STAGES); the companions leave them to the humans.
const FUEL := [[-43.5, -38.0], [50.0, -47.5], [-28.0, -52.3], [33.0, -37.6]]
const FUEL_NEEDED := 3
const FUEL_BOOST := 0.12
const FUEL_REACH := 1.8
const TANK := [-5.0, -54.2]
const TANK_REACH := 2.2
const FUEL_STAGES := ["station", "nadja", "deal", "power", "hold"]
## How the train is got going (v0.79), drawn by the host when a night begins and kept in
## `done` ("station_kind"), so that a guest sees the same: "fuses" - it comes up on the
## emergency power, and leaves only with all three fuses on (no fuel); "fuel" - its tank is
## dry, FUEL_NEEDED canisters go into it (no fuses, the full pace); "ready" - the operators
## have brought it up already: it is started in the control room, and those who stay hold
## the platform for the few seconds it takes (HOLD_READY) and say so over the radio. "both"
## is the station of v0.78 (fuses and fuel): the classic night of the checks, and
## --station=both. --station=fuses|fuel|ready|both forces one.
const STATION_KINDS := ["fuses", "fuel", "ready"]
const HOLD_READY := 14.0
## What command says when the train comes up, by the kind of the station.
const POWER_LINES := {"fuses": "m2_power_fuses", "fuel": "m2_power_fuel", "ready": "m2_power_ready"}
## The goal while the control room waits, by the kind of the station.
const DEAL_GOALS := {"fuses": "Im Stellwerk den Zug hochfahren  ·  nebenbei die Sicherungen einschalten", "fuel": "Im Stellwerk den Zug hochfahren  ·  nebenbei Benzin suchen", "ready": "Im Stellwerk den Zug starten"}
## What an operator who stays says in person when the roads part (one operator goes on):
## Phantom and Havoc hold the tunnel, Ghost the relay.
const STAYING_WORDS := {"phantom": "m2_p_tunnel", "havoc": "m2_a_havoc", "ghost": "m2_a_ghost"}
## ... and what the one who goes says (in person).
const JOIN_WORDS := {"phantom": "m2_d_phantom", "havoc": "m2_d_havoc", "ghost": "m2_d_ghost"}
## What is the matter with the train, by the kind of the station: the operator's word for
## it (in person), and the squad's answer (one of it).
const TRAIN_NEWS := {"fuses": ["m2_s_fuses", "m2_s_fuses_t"], "fuel": ["m2_s_fuel", "m2_s_fuel_t"], "ready": ["m2_s_ready", "m2_s_ready_t"]}
## Who calls over the radio that they hold the platform when the train stood ready.
const READY_CALLS := {"viper": "m2_r_viper", "scorpion": "m2_r_scorpion", "raven": "m2_r_raven", "phantom": "m2_r_phantom", "havoc": "m2_r_havoc", "ghost": "m2_r_ghost"}
## For a test: the kind the next night takes ("" draws one).
var station_wanted := ""
## Quiet at a counter: where a supply point, a workbench or an equipment station stands,
## nobody new comes while one of the humans stands within SAFE_REACH of it - or anywhere
## in its room, if that room is a small one (SAFE_ROOM square metres at the most). While a
## place has to be held they come all the same, only slower (SAFE_HOLD: the share of
## their pace). Whoever is already on his way still comes; a sealed cache that is being
## opened is still heard.
const SAFE_REACH := 6.0
const SAFE_ROOM := 160.0
const SAFE_HOLD := 0.4
## The squad has no money, but now and then one of it goes over to a counter or an opened
## cache nearby and comes back with another weapon - for its looks (Teammate.take_up):
## how far it goes for it, the share of the counters it goes to, and what it may come back
## with by the family of the weapon it started with (later in the night the better ones
## come more often: the second list is added from the terminal on).
const SHOP_REACH := 16.0
const SHOP_CHANCE := 0.55
const SHOP_GUNS := {
	"rifle": [["rifle", "ak", "badger", "m14"], ["m14", "ak", "svd"]],
	"shotgun": [["shotgun", "autoshotgun"], ["autoshotgun"]]
}
## What is said at the station when it is settled who goes on with the survivor, for each
## choice of company (Profile.COMPANIES), in its order. Whoever stays or goes says why.
## Each: how it is said - "face" in person, "talk" by somebody of the squad, "line" over
## the radio - and its cue; a third entry names the one of the squad who alone says it.
## Who is not there is passed over.
const SETTLED := {
	"fireteam": [["face", "m2_p_tunnel"], ["face", "m2_a_havoc"], ["face", "m2_a_ghost"], ["talk", "m2_a_viper"], ["talk", "m2_a_scorpion"], ["talk", "m2_a_raven"], ["line", "m2_a_coleman"]],
	# (Ghost keeps the relay himself here: Raven has her other word for it.)
	"phantom_havoc": [["face", "m2_p_join"], ["face", "m2_b_phantom"], ["face", "m2_b_havoc"], ["face", "m2_a_ghost"], ["talk", "m2_b_viper"], ["talk", "m2_b_scorpion"], ["talk", "m2_stay", "raven"], ["line", "m2_b_coleman"]],
	"phantom_ghost": [["face", "m2_p_join"], ["face", "m2_b_phantom"], ["face", "m2_b_ghost"], ["face", "m2_a_havoc"], ["talk", "m2_b_viper"], ["talk", "m2_b_scorpion"], ["talk", "m2_b_raven"], ["line", "m2_b_coleman"]],
	"havoc_ghost": [["face", "m2_c_havoc"], ["face", "m2_b_ghost"], ["face", "m2_b_havoc"], ["face", "m2_c_phantom"], ["talk", "m2_b_viper"], ["talk", "m2_b_scorpion"], ["talk", "m2_b_raven"], ["line", "m2_b_coleman"]]
}

var game: Node3D
const COOP_SCRIPT := preload("res://scripts/hive_coop.gd")
var coop: RefCounted
var on := false
var map: HiveMap
var stage := ""
var stage_time := 0.0
var clock := 0.0
## Set before a night starts to take it up at a checkpoint; start_run reads and clears it.
var resume_at := ""
var checkpoint := "landing"
var done: Dictionary = {}
var nadja: Teammate
var nadja_down := 0.0
var nadja_gone := false
var heli: Helicopter
var heli_clock := -1.0
var intro_left := 0.0
var intro_camera: Camera3D
var bars: Array[ColorRect] = []
## What is said while the arrival is filmed, to be read on the lower bar of the picture
## (the radio's panel is out of it with the rest of the HUD).
var caption: Label
## The goal shown on the HUD, the place its marker points at, and what can be used there.
var goal := ""
var marker := Vector3.INF
var use_at := Vector3.INF
var use_text := ""
var use_key := ""
## Something that takes time (0..1, or below 0 for nothing), and what the HUD calls it.
var progress := -1.0
var progress_text := ""
var pressure_left := 0.0
var feel_left := 0.0
## Enemies of the stage that have to fall before it is over.
var guards: Array = []
## The last guards of the villa and the infected that are on each of them: {guard, pack}.
var doomed: Array = []
## What is still to be said, in its order: {kind, cue, ...} (see "what is said").
var lines: Array = []
## Seconds until the next of them may follow; below zero for as long as nobody has spoken.
var line_left := 0.0
## What the lines wait for before they go on (see until), and for how long at most.
var hold_id := ""
var hold_left := 0.0
## The voice of whoever says a line in person, and who that is.
var voice: AudioStreamPlayer3D
var talker: Node3D
## When Nadja turned away behind her door.
var walk_clock := 0.0
## Seconds the next line has waited for a call of the squad to be over.
var call_wait := 0.0
## Seconds until somebody of the squad may make small talk again.
var idle_left := 45.0
var puppets: Array = []
## How far an operator at the station shoots, and what one of his shots does (v0.86).
const PUPPET_REACH := 32.0
## The goal of the terminal while the simulation hall still holds its gate (v0.86).
const TOKYO_GOAL := "Erst die Tokio-Simulation stabilisieren  ·  der Leitstand ist bis dahin gesperrt"
const PUPPET_DAMAGE := 14.0
## Who goes on with the survivor from the station: "fireteam", or two of the three
## operators (Profile.COMPANIES; read from the profile when the night begins) - and the
## looks of those two (none with the squad).
var company := "fireteam"
var pair: Array[String] = []
## Those who stay at the station when the roads part, on their way to where they said they
## would be: {node, left, keep}. keep: he stands at the relay until the train has left;
## the others are gone once they have reached the tunnel.
var leavers: Array = []
## The looks of those of the squad who stayed.
var stayed: Array[String] = []
var stalker_sent := false
## The Prowler's comings and goings (a node of its own).
var prowl: HiveProwler
## The ways in through ceilings, walls and windows, and who comes through them (a node of its own).
var entries: HiveEntries
## The weapon caches off the way, and what was found in them (a node of its own).
var caches: HiveCaches
## The throwables to be found in a night (hive_finds.gd).
var finds: HiveFinds
var board_time := 0.0
## The random part of the night after the station (HiveLayout; a node of its own that
## runs its stages), the night it is built from, and this night's tables: its order of
## stages, what each is called, who keeps coming, where a defeat is taken up again (the
## classic ones - ORDER, STAGES, PRESSURE, CHECKPOINTS - when there is no random part).
var run: HiveAreaRun
## The end after the containment hall: the last corridor and the reactor hall (BossFight).
var boss: BossFight
var night: Dictionary = {}
var night_fresh := false
## Which night comes next: -2 the director decides (a new seed for every night in play,
## the classic night in a check), -1 the classic night, -3 the showcase, a seed otherwise.
var seed_wanted := -2
## Whether the night has the simulation hall: -1 as its seed says (HiveLayout.tokyo_of; the
## classic night never), 0 never, 1 always. The start options --tokyo and --no-tokyo set it.
var tokyo_wanted := -1
## The objectives of the simulation hall in a night that has it (TokyoTasks), else null.
var tokyo_tasks: TokyoTasks
var order: Array = ORDER
var stages: Dictionary = STAGES
var pressure: Dictionary = PRESSURE
var checkpoints: Dictionary = CHECKPOINTS
## The fuse boxes of the station as they are seen (built on the host and on a guest alike,
## their state read from `done`): {node, lamp, at, stand}.
var fuse_boxes: Array = []
## The canisters of fuel as they are seen (built on the host and on a guest alike, their
## state read from `done`: "can_N" is "host" or "guest" while one of the two carries it,
## "in" once it is in the train), and the tank beside the car: {node, gauge}.
var fuel_cans: Array = []
var fuel_tank: Dictionary = {}
## Where the canisters stand: on the free floor nearest to FUEL (found once a night).
var fuel_spots: Array = []
## The counters that make a quiet place: {pos, room} (see SAFE_REACH), and whether one of
## the humans stands at one right now (looked at a few times a second).
var safe_spots: Array = []
var safe_now := false
var safe_left := 0.0
## Which companion has been to which counter tonight ("look@place"), and when it is next
## looked whether one goes.
var shopped: Dictionary = {}
var shop_left := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	coop = COOP_SCRIPT.new(self)
	prowl = HiveProwler.new()
	prowl.director = self
	add_child(prowl)
	entries = HiveEntries.new()
	entries.director = self
	add_child(entries)
	finds = HiveFinds.new()
	finds.director = self
	finds.game = game
	add_child(finds)
	caches = HiveCaches.new()
	caches.director = self
	add_child(caches)
	run = HiveAreaRun.new()
	run.director = self
	add_child(run)
	boss = BossFight.new()
	boss.director = self
	boss.game = game
	add_child(boss)

## The night the next start builds its map for (Game.start_run asks before the map is put
## into the world): the same one again when a defeat is taken up at a checkpoint, a new one
## otherwise. Asking twice before the night begins gives the same answer.
func prepare_night() -> Dictionary:
	if night_fresh and not night.is_empty():
		return night
	if resume_at == "" or night.is_empty():
		var wanted := _seed_for_night()
		# (For the checks: -4 a chain in every seam with every area, -3 the showcase of the
		# test room, below that the classic night.)
		if wanted == -4:
			night = HiveLayout.every_seam()
		elif wanted == -3:
			night = HiveLayout.showcase()
		else:
			night = HiveLayout.classic() if wanted < 0 else HiveLayout.plan(wanted, _room_wanted(), _length_wanted())
		var hall := tokyo_wanted
		if "--tokyo" in OS.get_cmdline_user_args():
			hall = 1
		elif "--no-tokyo" in OS.get_cmdline_user_args():
			hall = 0
		if hall >= 0:
			night = HiveLayout.with_tokyo(night, hall == 1)
		# (v0.88) The endless night is held in the simulation hall: it is always there.
		if _endless_wanted():
			night = HiveLayout.with_tokyo(night, true)
			night["endless"] = true
			night["key"] = str(night.key).trim_suffix("+tokio") + "+endlos+tokio"
	night_fresh = true
	return night

## Whether the night is to be the endless one: --hive-endless, else the play menu's choice.
func _endless_wanted() -> bool:
	if endless_wanted or "--hive-endless" in OS.get_cmdline_user_args():
		return true
	return not game.check_mode and str(game.profile.hive_mode) == "endless"

## The room the night must have: --hive-room= on the command line, else the one chosen in
## the play menu (Profile.room; not in a check, so that the checks keep their nights).
func _room_wanted() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hive-room="):
			return arg.trim_prefix("--hive-room=")
	return "" if game.check_mode else str(game.profile.room)

## How long the night is (HiveLayout.LENGTHS): --hive-length= on the command line, else the
## one chosen in the play menu (Profile.length; not in a check: "" keeps the old dice).
func _length_wanted() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hive-length="):
			return arg.trim_prefix("--hive-length=")
	return "" if game.check_mode else str(game.profile.length)

func _seed_for_night() -> int:
	if seed_wanted != -2:
		return seed_wanted
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hive-seed="):
			return int(arg.trim_prefix("--hive-seed="))
		if arg == "--hive-classic":
			return -1
	if game.check_mode:
		return -1
	return randi_range(1, 999999)

# ---------------------------------------------------------------- begin and end

## Called when a night starts on the map of the second mission.
func begin() -> void:
	on = true
	HiveVoice.reset()
	map = game.cabin as HiveMap
	done.clear()
	guards.clear()
	doomed.clear()
	lines.clear()
	line_left = 0.0
	hold_id = ""
	talker = null
	walk_clock = 0.0
	call_wait = 0.0
	idle_left = 45.0
	game.talk_until = 0
	game.round_called = false
	clock = 0.0
	nadja_down = 0.0
	nadja_gone = false
	# The Prowler has taken the Stalker's place in the laboratories: none is sent any more.
	stalker_sent = true
	board_time = 0.0
	progress = -1.0
	heli_clock = -1.0
	intro_left = 0.0
	leavers.clear()
	stayed.clear()
	company = Profile.known_company(str(game.profile.company))
	if game.net.joined:
		company = Profile.known_company(game.net.match_company)
	pair = Profile.pair_of(company)
	# (The guest takes the station's kind from the host's snapshots of `done`.)
	if not game.net.joined:
		done["station_kind"] = _draw_station()
	night_fresh = false
	_clear_fuses()
	_clear_fuel()
	fuel_spots.clear()
	_find_safe_spots()
	shopped.clear()
	shop_left = 20.0
	run.setup()
	# (The stages of the end, after the containment hall: see BossFight.)
	boss.game = game
	boss.extend_night()
	var from := resume_at if checkpoints.has(resume_at) else "landing"
	resume_at = ""
	checkpoint = from
	if not game.net.joined:
		prowl.begin(from)
	caches.begin(from)
	# (The throwables to be found: dealt from the same night as the caches.)
	finds.begin(caches.night ^ 0x6E4A)
	# (The simulation hall's side job, in a night that has the hall.)
	if tokyo_tasks != null:
		tokyo_tasks.clear()
	tokyo_tasks = null
	if is_instance_valid(map.tokyo):
		tokyo_tasks = TokyoTasks.new(self, map.tokyo)
		tokyo_tasks.setup()
	var start: Dictionary = checkpoints[from]
	map.lock_all()
	for id in start.open:
		map.unlock(str(id), true)
	game.credits = int(start.credits)
	if bool(night.get("endless", false)) and is_instance_valid(map.tokyo):
		_begin_endless()
		return
	# Nobody lands at a Helix site in a shirt: half a vest from the start.
	game.player.armor = maxf(game.player.armor, START_ARMOUR)
	game.preparation_left = 99999.0
	game.sounds.dry = true
	var at: Vector3 = map.points.get(str(start.at), map.player_start)
	if game.net.joined:
		_place_squad(at + Vector3(1.4, 0, 0.6), float(map.facings.get(str(start.at), 0.0)))
		stage = from
		goal = str(stages[from][1])
		if from == "landing":
			_arrive()
		return
	# Taken up behind the station, the two operators are already at the survivor's side.
	if not pair.is_empty() and order.find(from) > order.find("deal"):
		_part(true)
	_place_squad(at, float(map.facings.get(str(start.at), 0.0)))
	if order.find(from) < order.find("nadja"):
		_spawn_nadja(at + Vector3(1.4, 0, 2.6))
	else:
		nadja_gone = true
	if from == "terminal":
		map.set_door("car_b", true, true)
	run.resume(from)
	_enter(from)
	if from == "landing":
		_arrive()
	else:
		game.hud.announce("KONTROLLPUNKT", "%s  ·  %s" % [stages[from][0], stages[from][1]], 6)

## (v0.88) The endless night: set down in the simulation hall, nobody else but the squad,
## straight into the stage that never ends.
func _begin_endless() -> void:
	game.player.armor = maxf(game.player.armor, START_ARMOUR)
	game.preparation_left = 99999.0
	game.sounds.dry = true
	nadja_gone = true
	checkpoint = "landing"
	game.credits = ENDLESS_CREDITS
	var at: Vector3 = map.points.get("tokyo_start", map.player_start)
	if game.net.joined:
		_place_squad(at + Vector3(1.4, 0, 0.6), 0.0)
		stage = "endless"
		goal = str(stages.endless[1])
		return
	_place_squad(at, 0.0)
	_enter("endless")
	game.hud.announce("ENDLOS  ·  TOKIO-SIMULATION", "Haltet durch, solange ihr könnt. Je länger ihr überlebt, desto besser die Kisten.", 7)

## Who keeps coming in the endless night now: the base plan, worse with every ENDLESS_RAMP.
func _endless_plan() -> Array:
	var base: Array = PRESSURE.endless
	var step := int(stage_time / ENDLESS_RAMP)
	var kinds: Array = (base[0] as Array).duplicate()
	for k in range(mini(step, ENDLESS_KINDS.size())):
		kinds.append_array(ENDLESS_KINDS[k])
	var alive := mini(CROWD_LIMIT, int(base[1]) + step * 2)
	var every := maxf(2.2, float(base[2]) * pow(0.88, step))
	var low := mini(5, 2 + step / 3)
	return [kinds, alive, every, base[3], [low, low + 1 + mini(2, step / 4)]]

## The plan of who keeps coming in the stage that runs ([] for none).
func _plan_now() -> Array:
	if stage == "endless":
		return _endless_plan()
	return pressure.get(stage, [])

## Called when the night is over or left.
func end() -> void:
	if not on:
		return
	on = false
	coop.clear()
	prowl.end()
	boss.end()
	caches.end()
	finds.end()
	if tokyo_tasks != null:
		tokyo_tasks.clear()
	tokyo_tasks = null
	run.clear_things()
	_clear_fuses()
	_clear_fuel()
	safe_spots.clear()
	safe_now = false
	_end_intro()
	for puppet in puppets:
		if is_instance_valid(puppet.node):
			puppet.node.queue_free()
	puppets.clear()
	leavers.clear()
	if is_instance_valid(heli):
		heli.queue_free()
	heli = null
	nadja = null
	game.story.nadja = null
	game.sounds.dry = false
	lines.clear()
	hold_id = ""
	talker = null
	if voice != null:
		voice.stop()
	guards.clear()
	stage = ""
	goal = ""
	marker = Vector3.INF
	use_at = Vector3.INF
	progress = -1.0

func _place_squad(at: Vector3, yaw: float) -> void:
	var player: Survivor = game.player
	player.global_position = at + Vector3(0, 0.05, 0)
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	for mate in game.team:
		mate.global_position = at + Basis(Vector3.UP, yaw) * (mate.slot as Vector3)
		mate.facing = yaw

func _spawn_nadja(at: Vector3) -> void:
	nadja = Teammate.new()
	nadja.game = game
	nadja.look = "nadja"
	nadja.slot = Vector3(-1.1, 0, 2.8)
	nadja.facing = game.player.rotation.y
	game.mates.add_child(nadja)
	nadja.max_health = NADJA_HEALTH
	nadja.health = NADJA_HEALTH
	nadja.overlooked = 2.5
	nadja.global_position = at
	game.survivors.append(nadja)
	# (The game looks here for somebody who can be helped up besides the squad.)
	game.story.nadja = nadja

# ---------------------------------------------------------------- the arrival

## The helicopter sets the squad down on the gravel before the house and leaves. A few
## seconds seen from outside; a key or a click ends them.
func _arrive() -> void:
	var pad: Vector3 = map.points.landing
	heli = Helicopter.new()
	heli.game = game
	add_child(heli)
	heli.rotation.y = -PI / 2
	heli.light_up()
	heli_clock = 0.0
	line("m2_arrival")
	if (game.check_mode and not game.story_in_checks) or game.intro_skipped:
		heli.global_position = pad + Vector3(0, 0.1, 0)
		heli_clock = INTRO_SECONDS
		game.hud.announce("MISSION 2  ·  DIE VILLA", "Die letzten Wachen der Villa werden gerade überrannt. Folgt der Markierung.", 8)
		return
	heli.global_position = pad + Vector3(0, 13.0, 0)
	intro_left = INTRO_SECONDS
	# Nobody stands on the gravel before the wheels are down.
	for mate in game.mates.get_children():
		(mate as Node3D).hide()
		mate.set_physics_process(false)
	intro_camera = Camera3D.new()
	intro_camera.fov = 54.0
	intro_camera.cull_mask = 1
	add_child(intro_camera)
	intro_camera.global_position = pad + Vector3(-12.0, 1.5, 13.0)
	intro_camera.look_at(pad + Vector3(0, 6.0, 0), Vector3.UP)
	intro_camera.current = true
	game.player.controlled = false
	game.hud.play_ui.hide()
	for edge in [0, 1]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if edge == 0 else 0.88
		bar.anchor_bottom = 0.12 if edge == 0 else 1.0
		game.hud.root.add_child(bar)
		bars.append(bar)
	caption = (game.hud as SurvivalHUD).label("", 17, SurvivalHUD.RADIO_INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.anchor_left = 0.12
	caption.anchor_right = 0.88
	caption.anchor_top = 0.88
	caption.anchor_bottom = 1.0
	game.hud.root.add_child(caption)

func _end_intro() -> void:
	if intro_left <= 0.0 and bars.is_empty() and not is_instance_valid(intro_camera):
		return
	intro_left = 0.0
	for bar in bars:
		if is_instance_valid(bar):
			bar.queue_free()
	bars.clear()
	if is_instance_valid(caption):
		caption.queue_free()
	caption = null
	if is_instance_valid(intro_camera):
		intro_camera.queue_free()
	intro_camera = null
	if not on:
		return
	# What was being said goes on on the radio's panel, long enough to be read.
	if game.hud.radio_left > 0.0:
		game.hud.radio_left = maxf(game.hud.radio_left, 3.5)
	if is_instance_valid(heli):
		heli.global_position = (map.points.landing as Vector3) + Vector3(0, 0.1, 0)
	heli_clock = maxf(heli_clock, INTRO_SECONDS)
	for mate in game.mates.get_children():
		(mate as Node3D).show()
		mate.set_physics_process(true)
	game.player.camera.current = true
	game.player.controlled = true
	game.hud.play_ui.show()
	game.hud.announce("MISSION 2  ·  DIE VILLA", "Die letzten Wachen der Villa werden gerade überrannt. Folgt der Markierung.", 8)

func _unhandled_input(event: InputEvent) -> void:
	if intro_left <= 0.0 or INTRO_SECONDS - intro_left < 0.7 or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if (key != null and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (button != null and button.button_index == MOUSE_BUTTON_LEFT):
		_end_intro()
		get_viewport().set_input_as_handled()

func _run_heli(delta: float) -> void:
	if not is_instance_valid(heli) or heli_clock < 0.0:
		return
	var pad: Vector3 = map.points.landing
	heli_clock += delta
	if intro_left > 0.0:
		intro_left -= delta
		if is_instance_valid(caption):
			caption.text = game.hud.radio_label.text if game.hud.radio_left > 0.0 else ""
		var down := clampf(heli_clock / (INTRO_SECONDS - 1.2), 0.0, 1.0)
		heli.global_position = pad + Vector3(0, lerpf(13.0, 0.1, ease(down, -1.8)), 0)
		intro_camera.look_at(heli.global_position + Vector3(0, 1.6, 0), Vector3.UP)
		if intro_left <= 0.0:
			_end_intro()
		return
	# It stays on the ground for a moment, then climbs away over the wall to the east.
	var gone := heli_clock - INTRO_SECONDS - 2.5
	if gone > 0.0:
		heli.global_position = pad + Vector3(gone * gone * 1.1, 0.1 + gone * gone * 1.4, 0)
		heli.rotation.x = -minf(0.2, gone * 0.05)
		if gone > 11.0:
			heli.queue_free()
			heli = null

# ---------------------------------------------------------------- stages

func _point(id: String) -> Vector3:
	return map.points.get(id, Vector3.INF)

func _once(key: String) -> bool:
	if done.has(key):
		return false
	done[key] = true
	return true

## The squad is past a point of no return: everybody is patched up and what there is to
## spend grows. A defeat is taken up again from here.
func _checkpoint(id: String, bonus: int) -> void:
	checkpoint = id
	var player: Survivor = game.player
	if player.down:
		player.get_up()
	player.health = minf(100.0, player.health + game.healing(50.0))
	player.resupply(Survivor.ROUND_AMMO)
	game.net.supply_partner()
	for mate in game.team:
		mate.revive(true)
	game.earn_tokens(bonus)
	game.score += int(round(400 * float(game.rules.score)))
	game.sounds.play_sound("clear")
	game.hud.announce("KONTROLLPUNKT", "+%d ◈  ·  Trupp versorgt  ·  halbe Munition zurück" % bonus, 5)
	# (What was found in the caches by now is kept for a defeat taken up again from here.)
	caches.keep(id)

func _enter(id: String) -> void:
	# (On a night with areas in the seams of the old route, a chain of them may come first.)
	id = run.redirect(id)
	stage = id
	stage_time = 0.0
	progress = -1.0
	use_at = Vector3.INF
	use_key = ""
	guards.clear()
	var info: Array = stages[id]
	goal = str(info[1])
	marker = _point(str(info[2]))
	game.wave = int(info[3])
	pressure_left = 3.0
	match id:
		"landing":
			pressure_left = 7.0
		"villa":
			line("m2_villa")
			talk("m2_villa")
			_post(["mauler", "mauler", "striker"], [Vector3(-14, 0, 12), Vector3(-19, 0, 19), Vector3(-10, 0, 17)], false)
			_post(["ripper"], [Vector3(16, 0, 15)], false)
			_post(["mauler", "leech"], [Vector3(-13, 0, 5), Vector3(-20, 0, -1)], false)
			_post(["mauler"], [Vector3(17, 0, 2)], false)
		"mirror":
			face("m2_n_mirror")
			talk("m2_mirror")
			if is_instance_valid(nadja):
				nadja.order = "hold"
				nadja.hold_point = _point("keypad")
		"descent":
			face("m2_n_open")
			talk("m2_stairs")
			if is_instance_valid(nadja):
				nadja.order = "follow"
			_post(["mauler", "ripper"], [_point("lobby") + Vector3(-1.2, 0, -2.0), _point("lobby") + Vector3(1.2, 0, -2.4)], false)
		"station":
			map.unlock("station")
			game.sounds.play_at("shutter_open", _point("lobby"))
			line("m2_platform")
			talk("m2_station")
			var middle := _point("platform")
			_post(["mauler", "mauler", "striker", "mauler", "mauler", "ripper", "mauler", "charger"], [middle + Vector3(-14, 0, -5), middle + Vector3(12, 0, -6), middle + Vector3(-6, 0, -8), middle + Vector3(18, 0, -3), middle + Vector3(-24, 0, -2), middle + Vector3(27, 0, -7), middle + Vector3(3, 0, -3), middle + Vector3(-30, 0, -8)], true)
		"nadja":
			_nadja_leaves()
			_fuses_begin()
		"deal":
			# (Begun as soon as Nadja's door has shut: the operators come while she still
			# talks through the glass, and the train can be brought up from the control room
			# at once - what is said goes on over whatever the squad does meanwhile.)
			if _once("dealt"):
				_deal()
			_fuses_begin()
			goal = str(DEAL_GOALS.get(station_kind(), goal))
			_use("booth", "booth", "[E] Zug starten" if station_kind() == "ready" else "[E] Zug hochfahren")
		"power":
			if station_kind() == "ready":
				goal = str(DEAL_GOALS.ready)
			_use("booth", "booth", "[E] Zug starten" if station_kind() == "ready" else "[E] Zug hochfahren")
		"hold":
			# (Fuel that is in the train already has brought it part of the way.)
			progress = minf(0.6, FUEL_BOOST * _fuel_in())
			progress_text = _hold_text()
			game.round_called = false
			# Whoever goes on with the survivor is at his side when the infected come, and
			# whoever stays is on his way - what they still have to say to each other they
			# say meanwhile, after command's word about the train. (Brought up before command
			# has got to the train, the roads part when he has.)
			if done.has("power_said"):
				_part(false)
			game.sounds.play_sound("wave")
			_command(str(POWER_LINES.get(station_kind(), "m2_power")))
		"board":
			map.set_door("car_a", true)
			game.sounds.play_at("shutter_open", _point("car_a"))
			_command("m2_board")
			# (Whoever stays has gone to his post by the time the doors open.)
			_part(false)
			_goodbye()
		"ride":
			_start_ride()
		"terminal":
			map.set_door("car_b", true)
			_checkpoint("terminal", 300)
			talk("m2_arrived")
			# (v0.86) On a night with the simulation hall it is the way on: the control room
			# stays locked until its data core has been taken (see _tokyo_gate).
			if _tokyo_pending():
				goal = TOKYO_GOAL
				marker = _point("tokyo_lock")
				game.hud.announce("LEITSTAND GESPERRT", "Die Tokio-Simulation hält das Tor zur Anlage zu. Stabilisiert sie und bergt den Datenkern - dann öffnet der Leitstand.", 7)
			else:
				goal = map.control_goal()
				_use("control", "control", "[E] Tor zur Anlage öffnen")
			var hall := _point("terminal")
			_post(["mauler", "mauler", "striker", "mauler", "charger"], [hall + Vector3(-14, 0, -8), hall + Vector3(12, 0, -10), hall + Vector3(0, 0, -14), hall + Vector3(18, 0, -4), hall + Vector3(-22, 0, -3)], false)
			# (On the gallery, wherever the gate is opened from this night: see HiveMap.old_route.)
			_post(["striker", "mauler"], [Vector3(17.0, HiveMap.DECK, -339.9), Vector3(7.0, HiveMap.DECK, -339.9)], false)
		"admin":
			map.unlock("admin")
			game.sounds.play_at("shutter_open", _point("gate_admin"))
			line("m2_terminal")
			_post(["mauler", "mauler", "mauler", "striker"], [_point("checkpoint") + Vector3(-2, 0, -6), _point("checkpoint") + Vector3(2, 0, -8), _point("junction") + Vector3(-8, 0, 0), _point("junction") + Vector3(9, 0, 0)], false)
		"security":
			goal = map.lock_goal()
			_use("security", "security", "[E] Sperre aufheben")
			line("m2_security")
			talk("m2_offices")
			_post(["mauler", "mauler", "striker", "ripper", "ripper"], [_point("office") + Vector3(-6, 0, -4), _point("office") + Vector3(5, 0, 3), _point("office") + Vector3(0, 0, -8), Vector3(17.0, HiveMap.UNDER, -386.3), _point("server") + Vector3(0, 0, -6)], false)
		"cafe":
			map.unlock("cafe")
			game.sounds.play_at("shutter_open", _point("junction"))
			line("m2_p_alive")
			_post(["mauler", "mauler", "striker", "leech"], [_point("cafeteria") + Vector3(-10, 0, -6), _point("cafeteria") + Vector3(9, 0, -8), _point("cafeteria") + Vector3(0, 0, -11), _point("cafeteria") + Vector3(-15, 0, 4)], false)
		"lockdown":
			coop.gather("cafeteria")
			map.lock("cafe")
			progress = 0.0
			progress_text = "ABRIEGELUNG"
			game.round_called = false
			game.sounds.play_sound("wave")
			game.sounds.play_at("shutter_close", _point("cafeteria"))
			line("m2_n_lock")
			line("m2_lockdown")
			talk("m2_locked")
		"atrium":
			map.unlock("cafe")
			map.unlock("atrium")
			game.sounds.play_at("shutter_open", _point("cafeteria"))
			_checkpoint("atrium", 350)
			line("m2_n_cru")
			line("m2_cru")
			line("m2_g_list")
			talk("m2_bought")
			_post(["cru_elite", "cru_assault", "cru_assault", "cru_marksman"], [_point("atrium") + Vector3(-12, 0, -10), _point("atrium") + Vector3(12, 0, -8), _point("atrium") + Vector3(0, 0, -16), _point("atrium") + Vector3(-15, 0, 6)], false)
		"generator":
			_use("generator", "generator", "[E] Notstrom einschalten")
			talk("m2_atrium")
			line("m2_generator")
			_post(["ripper", "ripper", "leech", "mauler", "striker"], [_point("maint") + Vector3(6, 0, 0), _point("maint") + Vector3(14, 0, 0), _point("pump") + Vector3(0, 0, -4), _point("generator") + Vector3(-4, 0, -4), _point("generator") + Vector3(4, 0, -6)], false)
		"decon":
			map.unlock("decon")
			game.sounds.play_sound("beep")
			line("m2_power_on")
		"labs":
			map.unlock("decon", run.on and run.passed.size() > 0)
			map.unlock("research")
			_checkpoint("labs", 350)
			line("m2_labs")
			_post(["mauler", "striker", "ripper", "leech", "healer", "mauler"], [_point("labs") + Vector3(0, 0, 8), _point("labs") + Vector3(-12, 0, 0), _point("labs") + Vector3(12, 0, -4), _point("labs") + Vector3(0, 0, -14), _point("labs") + Vector3(-14, 0, -24), _point("labs") + Vector3(14, 0, -26)], false)
		"hall":
			map.unlock("hall")
			game.sounds.play_at("shutter_open", _point("cross"))
			progress = 0.0
			progress_text = "FRACHTAUFZUG KOMMT"
			game.round_called = false
			line("m2_hall")
			talk("m2_stand")
			var floor_spot := _point("hall_end")
			_post(["cru_elite", "cru_elite", "cru_heavy", "cru_shield", "cru_medic"], [floor_spot + Vector3(-12, 0, -8), floor_spot + Vector3(12, 0, -8), floor_spot + Vector3(0, 0, -14), floor_spot + Vector3(-6, 0, -4), floor_spot + Vector3(8, 0, -16)], false)
		"exit":
			line("m2_lift")
			talk("m2_down")
		_:
			if run.owns(id):
				run.enter(id)
	HiveVoice.entered(self, id)

## Whether the night has the simulation hall and its data core has not been taken yet.
func _tokyo_pending() -> bool:
	return tokyo_tasks != null and not tokyo_tasks.terminals.is_empty() and str(tokyo_tasks.core.get("state", "")) != "taken"

## The control room of the terminal opens once the simulation hall is done (v0.86).
func _tokyo_gate() -> void:
	if stage != "terminal" or use_key != "" or _tokyo_pending():
		return
	goal = map.control_goal()
	marker = _point("control")
	_use("control", "control", "[E] Tor zur Anlage öffnen")
	game.hud.announce("LEITSTAND FREI", "Die Simulation hält. Zurück zum Leitstand im Terminal: das Tor zur Anlage öffnen.", 6)

func _update(delta: float) -> void:
	var player: Survivor = game.player
	if tokyo_tasks != null:
		tokyo_tasks.update(delta)
		_tokyo_gate()
	var here: Vector3 = coop.position_near(marker)
	var room: Dictionary = map.room_at(here)
	var room_id := "" if room.is_empty() else str(room.id)
	# From the tunnel they hold the operators report once, when nobody else is talking.
	if not pair.has("havoc") and stage in ["generator", "decon"] and stage_time > 16.0 and not done.has("h_tunnel") and _silent_for(2.0):
		done["h_tunnel"] = true
		line("m2_h_tunnel")
	# A little after the guards have been talked over, Nadja has a word about the house.
	if stage in ["landing", "villa"] and done.has("terrace_guards") and not done.has("n_house") and _silent_for(2.5):
		done["n_house"] = true
		face("m2_n_house")
	# When it has been quiet for a while, somebody of the squad has something to say.
	idle_left -= delta
	if idle_left <= 0.0 and game.alive_count == 0 and _silent_for(6.0) and not stage in ["nadja", "deal", "ride"]:
		idle_left = randf_range(150.0, 220.0)
		var chatter: Teammate = game.squad_voice()
		if chatter != null:
			game.bark(chatter, chatter.look, "idle")
	if room_id == "flooded" and _once("water"):
		talk("m2_water")
	# A canister the other human carried when he left stands where it stood again.
	if stage in FUEL_STAGES:
		var lost := _fuel_carried("guest")
		if lost >= 0 and not (game.net.hosting and is_instance_valid(game.net.remote)):
			done.erase("can_%d" % lost)
	match stage:
		"landing":
			# The last guards of the house show themselves once the squad comes up the drive.
			if here.z < 56.0 and _once("terrace_guards"):
				_overrun([Vector3(-9, 0, 27.0), Vector3(8, 0, 27.5), Vector3(-1, 0, 29.5)], ["cru_assault", "cru_shotgunner", "cru_assault"])
				line("m2_guards")
				talk("m2_land")
			if here.distance_to(_point("front_door")) < 7.0 or bool(map.is_indoors(here)):
				_enter("villa")
		"villa":
			if room_id == "dining":
				_enter("mirror")
		"mirror":
			if not is_instance_valid(nadja) or nadja_gone:
				_open_mirror()
			elif not nadja.down and nadja.global_position.distance_to(_point("keypad")) < 1.8:
				if _once("keypad_started"):
					progress = 0.0
					progress_text = "NADJA ÖFFNET DEN ZUGANG"
					game.sounds.play_at("beep", _point("keypad") + Vector3(0, 1.4, 0))
				progress = minf(1.0, progress + delta / KEYPAD_SECONDS)
				if progress >= 1.0:
					_open_mirror()
		"descent":
			if room_id == "stair_lobby":
				_enter("station")
		"station":
			var left := _guards_left()
			# The last of the guards are pointed out; and should one of them be out of reach
			# for minutes, the two that are left give the platform up.
			if left > 0 and left <= 3 and stage_time > 20.0:
				marker = _nearest_guard()
			if left > 0 and left <= 2 and stage_time > 150.0:
				_dismiss_guards()
				left = 0
			if left == 0 and stage_time > 4.0:
				_all_clear()
				_enter("nadja" if is_instance_valid(nadja) and not nadja_gone else "deal")
		"nadja":
			_run_nadja_leaving()
		"deal":
			# What is said carries this stage (see _deal). Should it ever stall, the mission goes on.
			if stage_time > 150.0:
				lines.clear()
				hold_id = ""
				done["radio_clear"] = true
				done["power_said"] = true
				if is_instance_valid(nadja):
					_nadja_is_gone()
				_part(false)
				_enter("power")
		"hold":
			# (The pace: by the fuses where there are any; a train that stood ready only has
			# to pull out of its siding.)
			var kind := station_kind()
			var pace := float(FUSE_PACE[_fuses_on()]) if _uses_fuses() else 1.0
			progress = minf(1.0, progress + delta / (HOLD_READY if kind == "ready" else HOLD_STATION) * pace)
			progress_text = _hold_text()
			var short := _uses_fuel() and _fuel_in() < FUEL_NEEDED
			# (On the emergency power alone the train leaves only with every fuse on.)
			var unfused := kind == "fuses" and _fuses_on() < FUSES.size()
			goal = str(stages["hold"][1])
			if short:
				goal = "Den Bahnsteig halten  ·  Benzin in den Zug füllen (%d / %d)" % [_fuel_in(), FUEL_NEEDED]
			elif unfused:
				goal = "Den Bahnsteig halten  ·  Sicherungen einschalten (%d / %d)" % [_fuses_on(), FUSES.size()]
			elif kind == "ready":
				goal = "Der Zug fährt an  ·  die anderen halten den Bahnsteig"
			marker = _fuel_goal() if short and progress >= 1.0 else (_fuse_goal() if unfused and progress >= 1.0 else _point("platform"))
			if short and progress >= 1.0 and kind != "both" and _once("short_said"):
				line("m2_fuel_short")
			if _uses_fuses():
				for trip in range(FUSE_TRIPS.size()):
					var window: Array = FUSE_TRIPS[trip]
					if progress > float(window[0]) and progress < float(window[1]) and not done.has("trip_%d" % trip):
						if _trip_fuse():
							done["trip_%d" % trip] = true
							if kind == "fuses":
								line("m2_fuse_trip")
								var caller := _squad_look()
								if caller != "":
									talk("m2_fuse_out", caller)
			if progress > 0.45 and kind != "ready" and _once("hold_squad"):
				_command("m2_depot")
				_post(["mauler", "striker", "ripper", "ripper", "charger"], [_point("depot") + Vector3(-2, 0, -2), _point("depot") + Vector3(2, 0, 0), _point("depot") + Vector3(-1, 0, 3), _point("depot") + Vector3(3, 0, 2), _point("depot") + Vector3(0, 0, -4)], false)
			# (The train only leaves with fuel in it - or with its fuses on.)
			if progress >= 1.0 and not short and not unfused:
				_all_clear()
				_enter("board")
		"board":
			# Whoever of the squad is not in the car yet is pulled in when the doors close.
			board_time = board_time + delta if room_id == "car_a" else 0.0
			if board_time > 1.4:
				_enter("ride")
		"ride":
			_run_ride(delta)
		"admin":
			if here.distance_to(_point("junction")) < 5.0:
				_enter("security")
		"cafe":
			if room_id == "cafeteria" and here.distance_to(_point("cafeteria")) < 9.0:
				_enter("lockdown")
		"lockdown":
			progress = minf(1.0, progress + delta / HOLD_CAFE)
			if progress > 0.45 and _once("lockdown_taunt"):
				_taunt()
			if progress > 0.6 and _once("lockdown_crusher"):
				_post(["crusher"], [_point("cafeteria") + Vector3(0, 0, -12)], false)
			if progress >= 1.0:
				_all_clear()
				_enter("atrium")
		"atrium":
			if here.distance_to(_point("atrium")) < 8.0:
				_enter("generator")
		"decon":
			if room_id == "decon":
				if _once("decon_spray"):
					game.hud.announce("DEKONTAMINATION", "Bleibt in der Schleuse. Das Tor nach Norden öffnet gleich.", 4)
					game.sounds.play_sound("beep")
					progress = 0.0
					progress_text = "DEKONTAMINATION"
				progress = minf(1.0, progress + delta / 5.0)
				if progress >= 1.0:
					_enter("labs")
		"labs":
			# Half-way up the corridor a squad comes in through the lock behind them.
			if here.z < -532.0 and _once("labs_squad"):
				game.sounds.play_at("shutter_open", _point("decon"))
				line("m2_behind")
				_post(["cru_assault", "cru_assault", "cru_shotgunner", "cru_marksman"], [_point("decon") + Vector3(-1.5, 0, 2.0), _point("decon") + Vector3(1.5, 0, 3.0), _point("decon") + Vector3(0, 0, 5.0), _point("decon") + Vector3(0, 0, 8.0)], false)
			# In among the laboratories Nadja speaks of what stands in them.
			if stage_time > 9.0 and room_id in LAB_ROOMS and _once("n_tanks"):
				line("m2_n_tanks")
				talk("m2_tanks")
			if not stalker_sent and stage_time > 14.0:
				stalker_sent = true
				var lair := _hidden_spot(16.0, 30.0)
				if lair != Vector3.INF:
					game.mission.stalker_dead = false
					game.mission.stalker_health = -1.0
					game.mission.stalker = game.spawn_stalker(lair, "hunt", player)
			if here.distance_to(_point("cross")) < 6.0:
				_enter("hall")
		"endless":
			# Stronger with every step (the infected: game.wave); the clock stands in the goal.
			game.wave = mini(14, int(stages.endless[3]) + int(stage_time / ENDLESS_RAMP))
			goal = "Überlebt so lange wie möglich  ·  %s" % game.time_string()
		"hall":
			if room_id == "containment":
				progress = minf(1.0, progress + delta / HOLD_HALL)
				if progress > 0.16 and _once("n_work"):
					line("m2_n_work")
				if progress > 0.5 and _once("hall_crusher"):
					_post(["crusher"], [_point("hall_end") + Vector3(0, 0, -16)], false)
				if progress > 0.75 and _once("hall_taunt"):
					_taunt()
			if progress >= 1.0:
				_enter("exit")
		"exit":
			if here.distance_to(_point("lift")) < 3.2:
				# Down to the reactor hall (BossFight); without it the night ends here.
				if not boss.lift_reached():
					_win()
		_:
			if run.owns(stage):
				run.update(delta)

func _open_mirror() -> void:
	_all_clear()
	map.unlock("descent")
	game.sounds.play_at("shutter_open", _point("mirror") + Vector3(0, 1.5, 0))
	_checkpoint("descent", 250)
	_enter("descent")

## Something to use with [E] at a named place; when it is used, _used runs.
func _use(point: String, key: String, text: String) -> void:
	use_at = _point(point)
	use_key = key
	use_text = text

## The same at a place given as a position.
func _use_spot(at: Vector3, key: String, text: String) -> void:
	use_at = at
	use_key = key
	use_text = text

func prompt() -> String:
	var end_hint: String = boss.prompt() if boss != null else ""
	if end_hint != "":
		return end_hint
	var nearby: Dictionary = coop.nearby_use()
	if not nearby.is_empty():
		return str(nearby.text)
	if tokyo_tasks != null and tokyo_tasks.prompt() != "":
		return tokyo_tasks.prompt()
	if _fuse_near(game.player.global_position) >= 0:
		return "[E] Sicherung einschalten  ·  Notstrom für den Zug"
	if _tank_near(game.player.global_position, _my_tag()):
		return "[E] Benzin in den Zug füllen  ·  %d / %d" % [_fuel_in() + 1, FUEL_NEEDED]
	if _can_near(game.player.global_position, _my_tag()) >= 0:
		return "[E] Benzinkanister aufheben"
	# (What the stage wants used comes first; then a throwable or a weapon cache one stands
	# before.)
	var found := finds.prompt()
	return found if found != "" else caches.prompt()

## [E] was pressed. True if that was for the mission.
func use(who: Node3D = null, requested: String = "", at: Vector3 = Vector3.INF) -> bool:
	if game.net.joined:
		var nearby: Dictionary = coop.nearby_use()
		if nearby.is_empty() and tokyo_tasks != null:
			nearby = tokyo_tasks.near_use(game.player.global_position)
		if nearby.is_empty():
			var fuse := _fuse_near(game.player.global_position)
			if fuse >= 0:
				game.net.request_hive_use("fuse", fuse_stand(fuse))
				return true
			if _tank_near(game.player.global_position, "guest"):
				game.net.request_hive_use("tank", tank_at())
				return true
			var can := _can_near(game.player.global_position, "guest")
			if can >= 0:
				game.net.request_hive_use("can", fuel_at(can))
				return true
			return _side_use()
		game.net.request_hive_use(str(nearby.key), nearby.at)
		return true
	if who == null:
		who = game.player
	if requested == "fuse":
		var asked := _fuse_near(at)
		if asked < 0 or who.global_position.distance_to(fuse_stand(asked)) >= FUSE_REACH + 0.8:
			return false
		return _switch_fuse(asked)
	if requested in ["can", "tank"]:
		return _use_fuel(who, requested)
	if requested in ["tk_term", "tk_core"]:
		return tokyo_tasks != null and tokyo_tasks.use(who, requested, at)
	if who == game.player and requested == "" and tokyo_tasks != null and (use_at == Vector3.INF or who.global_position.distance_to(use_at) >= 2.9):
		var asked_tk := tokyo_tasks.near_use(who.global_position)
		if not asked_tk.is_empty():
			return tokyo_tasks.use(who, str(asked_tk.key), asked_tk.at)
	var key := use_key if requested == "" else requested
	if who == game.player and requested == "":
		var focused: Dictionary = run.focused_use()
		if not focused.is_empty():
			key = str(focused.key)
			at = focused.at
			requested = key
		elif key in ["g_item", "g_switch", "g_slot", "g_hack"]:
			return _side_use()
		var device: Node3D = map.interaction_devices.get(key)
		if device != null and not game.aims_at_object(device):
			return _side_use()
	if key in ["g_item", "g_switch"] and requested != "":
		if who.global_position.distance_to(at) >= 2.9:
			return false
		var used: bool = run.use(key, who, at)
		if used:
			game.stats.objectives += 1
		return used
	if use_at == Vector3.INF or who.global_position.distance_to(use_at) >= 2.9 or (requested != "" and (key != use_key or at.distance_to(use_at) > 0.2)):
		return _side_use() if who == game.player else false
	use_at = Vector3.INF
	use_key = ""
	game.sounds.play_sound("beep")
	game.stats.objectives += 1
	match key:
		"booth":
			_enter("hold")
		"control":
			_enter("admin")
		"security":
			_enter("cafe")
		"generator":
			_enter("decon")
		_:
			run.use(key, who)
	return true

## [E] for what lies off the way: a throwable that is aimed at, else a weapon cache.
func _side_use() -> bool:
	if not game.net.joined:
		var fuse := _fuse_near(game.player.global_position)
		if fuse >= 0:
			return _switch_fuse(fuse)
		if _use_fuel(game.player, ""):
			return true
	return finds.use() or caches.use(true)

## What [E] would be for off the way (for the outline).
func side_focus() -> Node3D:
	var found := finds.focused_object()
	return found if found != null else caches.focused_object()

# ---------------------------------------------------------------- Nadja and the operators

func _watch_nadja(delta: float) -> void:
	if not is_instance_valid(nadja) or nadja_gone:
		return
	if nadja.down:
		if nadja_down == 0.0:
			game.hud.announce("NADJA IST AM BODEN", "Hilf ihr auf [E], bevor es zu spät ist.", 4)
		nadja_down += delta
		if nadja_down > 30.0:
			game.hud.announce("NADJA IST TOT", "Ohne sie öffnet sich kein Zugang.", 4)
			game.finish(false)
	else:
		nadja_down = 0.0

## At the station Nadja runs for a door that only opens for her.
func _nadja_leaves() -> void:
	# What the squad still had to say about the way here is not said any more.
	lines = lines.filter(func(entry: Dictionary) -> bool: return str(entry.kind) != "squad")
	face("m2_n_wait")
	map.set_door("nadja", true)
	game.sounds.play_at("shutter_open", _point("nadja_door"))
	nadja.order = "hold"
	nadja.hold_point = _point("nadja_door")
	# Nobody shoots at her any more, and nothing bites her on the way.
	game.survivors.erase(nadja)
	nadja.health = nadja.max_health

func _run_nadja_leaving() -> void:
	if not is_instance_valid(nadja):
		_enter("deal")
		return
	if done.has("nadja_inside"):
		return
	var inside := _point("nadja_inside")
	# To the door along the platform first, then straight through it.
	if nadja.global_position.distance_to(_point("nadja_door")) < 1.6 or stage_time > 7.0:
		nadja.hold_point = inside
	if stage_time > 12.0:
		nadja.global_position = inside
	if nadja.global_position.distance_to(inside) < 1.4 and _once("nadja_inside"):
		map.set_door("nadja", false)
		game.sounds.play_at("shutter_close", _point("nadja_door"))
		face("m2_n_sorry")
		face("m2_n_home")
		beat("nadja_walks")
		talk("m2_betrayed")
		until("nadja_off", 6.0)
		beat("deal")
		# What she says through the glass, what the squad makes of it and her going are
		# carried by the lines (see _beat) - but nobody waits for them: the operators come
		# out of the tunnel meanwhile and the train can be brought up (see "deal").
		_enter("deal")

func _nadja_is_gone() -> void:
	nadja_gone = true
	game.story.nadja = null
	if is_instance_valid(nadja):
		game.team.erase(nadja)
		nadja.queue_free()
	nadja = null

## Three operators step out of the tunnel with their weapons down, one of them clears the
## radio channel, and then it is settled who goes on with the survivor: the squad, or two
## of the three (see SETTLED and _part). Nobody has to stand still for it: what is said
## carries it along (see _beat), and the control room can be used as soon as command is
## back, while they are still talking it over.
func _deal() -> void:
	var from := _point("ops_from")
	var stand := _point("ops_stand")
	var looks := ["phantom", "havoc", "ghost"]
	for index in range(3):
		var body := SoldierVisual.new()
		body.look = looks[index]
		add_child(body)
		body.global_position = from + Vector3(0, 0, (index - 1) * 1.4)
		puppets.append({"node": body, "goal": stand + Vector3(0, 0, (index - 1) * 2.0), "look": looks[index], "leaving": false, "left": 0.0, "work": false})
	talk("m2_operators")
	until("ops_there", 7.0)
	face("m2_p_truce")
	face("m2_h_used")
	# What is the matter with the train (v0.79): one of them knows, and the squad has its
	# word for it. (The station of v0.78 has only the HUD's.)
	var kind := station_kind()
	if kind != "both":
		face(str(TRAIN_NEWS[kind][0]))
		var reply := _squad_look()
		if reply != "":
			talk(str(TRAIN_NEWS[kind][1]), reply)
	face("m2_g_radio")
	beat("ghost_radio")
	until("ops_there", 7.0)
	beat("radio_clear")
	face("m2_g_clear")
	line("m2_back")
	line("m2_truth")
	beat("power")
	talk("m2_colonel")
	for part: Array in _settled_parts():
		match str(part[0]):
			"face":
				face(str(part[1]))
			"talk":
				talk(str(part[1]), str(part[2]) if part.size() > 2 else "")
			"line":
				line(str(part[1]))
	beat("part")

## The operators at the station walk to where they are wanted, stand there turned to the
## survivor, and are gone once they have left the way they came.
func _run_puppets(delta: float) -> void:
	if puppets.is_empty():
		return
	var gone: Array = []
	for puppet: Dictionary in puppets:
		if not is_instance_valid(puppet.node):
			gone.append(puppet)
			continue
		var body: SoldierVisual = puppet.node
		var gap: Vector3 = (puppet.goal as Vector3) - body.global_position
		gap.y = 0.0
		var speed := Vector3.ZERO
		if gap.length() > 0.25:
			speed = gap.normalized() * 2.6
			body.global_position += speed * delta
			body.rotation.y = atan2(-speed.x, -speed.z)
		var aiming := false
		if not bool(puppet.leaving):
			aiming = _puppet_fight(puppet, body, delta, gap.length() <= 0.25)
		if not aiming and gap.length() <= 0.25 and not bool(puppet.leaving) and not bool(puppet.work):
			var to: Vector3 = game.player.global_position - body.global_position
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 4.0))
		body.animate(delta, speed, aiming, aiming)
		if bool(puppet.leaving):
			puppet.left = float(puppet.left) + delta
			# (He is not gone while he still has something to say.)
			if (gap.length() <= 0.3 or float(puppet.left) > 12.0) and (not _to_say(str(puppet.look)) or float(puppet.left) > 120.0):
				body.queue_free()
				gone.append(puppet)
	for puppet: Dictionary in gone:
		puppets.erase(puppet)

## An operator standing at the station (v0.86) does not watch the infected come: he turns
## to the nearest one he can see and shoots it in short bursts, as a companion would.
## True while he has somebody in his sights.
func _puppet_fight(puppet: Dictionary, body: SoldierVisual, delta: float, standing: bool) -> bool:
	puppet.look_wait = float(puppet.get("look_wait", 0.0)) - delta
	puppet.shot_wait = float(puppet.get("shot_wait", 0.0)) - delta
	var foe: Infected = puppet.get("foe") as Infected if is_instance_valid(puppet.get("foe")) else null
	if foe != null and (foe.dead or foe.absent):
		foe = null
	var eye := body.global_position + Vector3(0, 1.5, 0)
	if float(puppet.look_wait) <= 0.0:
		puppet.look_wait = 0.3
		foe = null
		var best := PUPPET_REACH
		for node in get_tree().get_nodes_in_group("infected"):
			var enemy := node as Infected
			if enemy == null or enemy.dead or enemy.absent:
				continue
			var gap := enemy.global_position.distance_to(body.global_position)
			if gap >= best:
				continue
			var query := PhysicsRayQueryParameters3D.create(eye, enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.6, 0), 1)
			if body.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				best = gap
				foe = enemy
	puppet.foe = foe
	if foe == null:
		return false
	var aim_point := foe.global_position + Vector3(0, float(foe.spec.height) * 0.6, 0)
	var to := aim_point - body.global_position
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 8.0))
	if standing and float(puppet.shot_wait) <= 0.0:
		var burst := int(puppet.get("burst", 0)) - 1
		if burst <= 0:
			burst = randi_range(3, 7)
			puppet.shot_wait = randf_range(0.25, 0.6)
		else:
			puppet.shot_wait = 0.14
		puppet.burst = burst
		_puppet_shot(body, aim_point)
	return true

## One shot of an operator at the station (see _puppet_fight).
func _puppet_shot(body: SoldierVisual, aim_point: Vector3) -> void:
	var muzzle := body.muzzle_position()
	var direction := ((aim_point - muzzle).normalized() + Vector3(randf_range(-0.022, 0.022), randf_range(-0.022, 0.022), randf_range(-0.022, 0.022))).normalized()
	var endpoint := muzzle + direction * 80.0
	var hit := body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, endpoint, 1 | 4 | 8))
	if not hit.is_empty():
		endpoint = hit.position
		var struck: Object = hit.collider
		var head_zone: bool = struck.has_meta("infected")
		if head_zone:
			struck = struck.get_meta("infected")
		if struck is Infected:
			var enemy := struck as Infected
			var headshot := enemy.head_struck(head_zone, hit.position)
			game.fx.blood(endpoint, direction, headshot)
			enemy.receive_hit(PUPPET_DAMAGE * (maxf(1.0, 2.0 * float(enemy.spec.head_factor)) if headshot else 1.0), direction, headshot, null)
		elif not struck is CharacterBody3D:
			game.holes.add(hit.position, hit.normal)
	game.fx.tracer(muzzle, endpoint)
	body.shot()
	game.sounds.play_at(body.shot_sound, muzzle, -7.0)

## The roads part at the station. Whoever goes on with the survivor is at his side from
## here on: the squad as it was, or two of the operators in its two places - companions
## like any other, with their own weapons and their own calls. Whoever stays goes where he
## said he would: into the tunnel the operators came out of, or to the relay, which Ghost
## keeps, or Raven when he is one of the two who go. `instant`: nobody walks anywhere (a
## night that is taken up behind the station).
func _part(instant: bool) -> void:
	if not _once("parted"):
		return
	var player: Survivor = game.player
	var slots := [Vector3(-2.0, 0, 2.3), Vector3(2.2, 0, 2.6)]
	# (With one operator alone, the one of the squad who was picked goes on beside him, and
	# the operator takes the place of the one who stays.)
	var goer := _goer() if pair.size() == 1 else ""
	if not pair.is_empty():
		var freed: Array = []
		for mate: Teammate in game.team.duplicate():
			if mate.look == goer or mate == nadja:
				continue
			freed.append(mate.slot)
			game.team.erase(mate)
			game.survivors.erase(mate)
			stayed.append(mate.look)
			if instant:
				mate.queue_free()
			else:
				_stay(mate, mate.look == "raven" and pair.has("ghost"))
		if pair.size() == 1 and not freed.is_empty():
			slots = [freed[0], freed[0]]
	var walking: Array = []
	for look: String in ["phantom", "havoc", "ghost"]:
		var puppet: Dictionary = {}
		for entry: Dictionary in puppets:
			if str(entry.look) == look and is_instance_valid(entry.node):
				puppet = entry
		var goes: bool = game.team_enabled and pair.has(look)
		if not goes and (instant or puppet.is_empty()):
			continue
		if not goes and look != "ghost":
			# Back into the tunnel, on foot.
			puppet.goal = _point("ops_from")
			puppet.leaving = true
			walking.append(puppet)
			continue
		# A body that walks by itself takes the place of the one that stood here.
		var slot: Vector3 = slots[pair.find(look)] if goes else Vector3(0.3, 0, 3.9)
		var at: Vector3 = player.global_position + Basis(Vector3.UP, player.rotation.y) * slot
		var yaw: float = player.rotation.y
		if not puppet.is_empty():
			at = (puppet.node as Node3D).global_position
			yaw = (puppet.node as Node3D).rotation.y
			(puppet.node as Node3D).queue_free()
		var mate := Teammate.new()
		mate.game = game
		mate.look = look
		mate.slot = slot
		mate.facing = yaw
		game.mates.add_child(mate)
		mate.global_position = at
		if goes:
			mate.outfit(int(game.squad_levels.squad_armor), int(game.squad_levels.squad_ammo))
			game.team.append(mate)
			game.survivors.append(mate)
		else:
			_stay(mate, true)
	puppets = walking
	# A train that stood ready (v0.79): whoever stays tells the survivor over the radio that
	# they hold the platform and see to the rest.
	if not instant and station_kind() == "ready":
		var caller := _ready_caller()
		if caller != "":
			line(str(READY_CALLS[caller]))

## Who of those who stay calls the train's leaving over the radio: one of the squad who
## stays, else the first of the operators who do.
func _ready_caller() -> String:
	for look in stayed:
		if READY_CALLS.has(look):
			return look
	for look in ["phantom", "havoc", "ghost"]:
		if not pair.has(look):
			return look
	return ""

## The one of the squad who goes on beside one operator alone: the one who was picked
## (Profile.goer) if he is there, else the first of the squad.
func _goer() -> String:
	var wanted: String = game.profile.goer()
	var first := ""
	for mate: Teammate in game.team:
		if mate == nadja or not mate.look in HiveVoice.SQUAD + ["dude_shorts", "dude_turtleneck"]:
			continue
		if mate.look == wanted:
			return wanted
		if first == "":
			first = mate.look
	return first

## One of the squad who is with the survivor and on his feet, at random ("" if none).
func _squad_look() -> String:
	var looks: Array = []
	for mate: Teammate in game.team:
		if is_instance_valid(mate) and not mate.down and mate.look in HiveVoice.SQUAD:
			looks.append(mate.look)
	return "" if looks.is_empty() else str(looks.pick_random())

## What is said when it is settled who goes on (see SETTLED). With one operator alone
## (v0.79) it is put together here: he says he comes along, the two others say why they
## stay, the one of the squad who stays says so - Raven of the relay, when Ghost goes - the
## one who was picked has a word for him, and command one for all of it.
func _settled_parts() -> Array:
	if SETTLED.has(company):
		return SETTLED[company]
	var parts: Array = []
	if pair.size() != 1:
		return parts
	var joiner := pair[0]
	parts.append(["face", str(JOIN_WORDS[joiner])])
	for look: String in ["phantom", "havoc", "ghost"]:
		if look != joiner:
			parts.append(["face", str(STAYING_WORDS[look])])
	var goer := _goer()
	for mate: Teammate in game.team:
		if mate == nadja or mate.look == goer or not mate.look in HiveVoice.SQUAD:
			continue
		if mate.look == "raven" and joiner == "ghost":
			parts.append(["talk", "m2_b_raven", "raven"])
		else:
			parts.append(["talk", "m2_d_stay", mate.look])
	if goer in HiveVoice.SQUAD:
		parts.append(["talk", "m2_d_go", goer])
	parts.append(["line", "m2_d_coleman"])
	return parts

## Somebody stays at the station. He is out of the fight from here on - nothing about how
## hard the platform is to hold changes with who stays - and goes to his post: the relay,
## where he is seen until the train has left, or the tunnel, where he is gone.
func _stay(mate: Teammate, relay: bool) -> void:
	if mate.down:
		mate.revive(true)
	# (Ghost at the relay stays on the platform and keeps shooting; who goes into the
	# tunnel has his weapon down.)
	mate.unarmed = not relay
	mate.target = null
	mate.name_tag.hide()
	var post := _point("radio") if relay else _point("ops_from") + Vector3(0, 0, 1.4 * (leavers.size() % 3 - 1))
	# (Sent off: who has something to see to is not called back to the survivor's side.)
	mate.job = {"kind": "post", "pos": post}
	mate.order = "hold"
	mate.hold_point = post
	leavers.append({"node": mate, "left": 0.0, "keep": relay})

## Those who went to hold the tunnel are gone once they have reached it - but not while
## they still have something to say.
func _run_leavers(delta: float) -> void:
	if leavers.is_empty():
		return
	var gone: Array = []
	for leaver: Dictionary in leavers:
		if not is_instance_valid(leaver.node):
			gone.append(leaver)
			continue
		if bool(leaver.keep):
			continue
		var mate: Teammate = leaver.node
		leaver.left = float(leaver.left) + delta
		var there: bool = mate.global_position.distance_to(mate.hold_point) < 1.6 or float(leaver.left) > 25.0
		if there and (not _to_say(mate.look) or float(leaver.left) > 120.0):
			mate.queue_free()
			gone.append(leaver)
	for leaver: Dictionary in gone:
		leavers.erase(leaver)

## The train has left: nobody who stayed at the station is seen again.
func _station_left() -> void:
	_clear_fuses()
	_clear_fuel()
	if is_instance_valid(nadja) and done.has("nadja_inside"):
		_nadja_is_gone()
	for leaver: Dictionary in leavers:
		if is_instance_valid(leaver.node):
			(leaver.node as Node).queue_free()
	leavers.clear()
	for puppet: Dictionary in puppets:
		if is_instance_valid(puppet.node):
			(puppet.node as Node).queue_free()
	puppets.clear()

## The doors of the train are open. Whoever of the squad stays behind has a last word for
## the survivor, called over from the tunnel he holds (or said at the relay).
func _goodbye() -> void:
	for look: String in ["viper", "raven"]:
		# (Raven has said hers already when Ghost was the one who stayed.)
		if stayed.has(look) and not (look == "raven" and company == "phantom_havoc"):
			lines.append({"kind": "squad", "cue": "m2_stay", "who": look, "at": clock, "from": _point("ops_from")})


## Something that happens when the lines have come to it.
func _beat(id: String) -> void:
	match id:
		"nadja_walks":
			walk_clock = clock
			if is_instance_valid(nadja):
				nadja.hold_point = _point("nadja_far")
		"deal":
			# (She has said what she had to say: whatever the squad is at by now.)
			if is_instance_valid(nadja) and done.has("nadja_inside"):
				_nadja_is_gone()
			if stage == "nadja":
				_enter("deal")
		"ghost_radio":
			for puppet: Dictionary in puppets:
				if str(puppet.look) == "ghost":
					puppet.goal = _point("radio")
					puppet.work = true
		"radio_clear":
			# From here on the voice of command is Coleman's own.
			done["radio_clear"] = true
			game.sounds.play_sound("glitch", -6.0)
		"power":
			done["power_said"] = true
			if stage == "deal":
				_enter("power")
			elif stage == "hold":
				# (The train was brought up before command got to it.)
				_part(false)
		"part":
			_part(false)

## Whether what the lines wait for (see until) has come about.
func _come(id: String) -> bool:
	match id:
		"nadja_off":
			return not is_instance_valid(nadja) or clock - walk_clock > 5.0
		"ops_there":
			for puppet: Dictionary in puppets:
				if not is_instance_valid(puppet.node):
					continue
				var gap: Vector3 = (puppet.goal as Vector3) - (puppet.node as Node3D).global_position
				if Vector2(gap.x, gap.z).length() > 0.6:
					return false
	return true

## The squad is in the lift: the mission is won. The last word is command's, and it is
## heard over the summary of the night.
func _win() -> void:
	lines.clear()
	hold_id = ""
	game.radio_busy = maxf(game.radio_busy, line_left)
	game.finish(true)
	game.radio("m2_end", 9.0)


# ---------------------------------------------------------------- the train

func _start_ride() -> void:
	coop.gather("car_a")
	map.set_door("car_a", false)
	game.sounds.play_at("shutter_close", _point("car_a"))
	line("m2_ride")
	talk("m2_train")

func _run_ride(_delta: float) -> void:
	if stage_time > 1.6 and _once("ride_jump"):
		# The car at the terminal is the same car: everybody in it is simply there now.
		_clear_enemies()
		_station_left()
		var player: Survivor = game.player
		# (Whoever stood in the doorway when it shut is inside the car now.)
		var car: Vector3 = _point("car_a")
		# The car the ride ends in: the terminal's, or that of the random part's arrival.
		var shift := HiveMap.RIDE if run.car() == Vector3.INF else run.car() - car
		player.global_position = Vector3(clampf(player.global_position.x, car.x - 6.4, car.x + 6.4), car.y + 0.05, clampf(player.global_position.z, car.z - 1.4, car.z + 1.4))
		player.global_position += shift
		game.net.place_partner(car + shift + Vector3(1.4, 0.05, 0.0))
		for mate in game.team:
			if mate.down:
				mate.revive(true)
			var room: Dictionary = map.room_at(mate.global_position)
			if room.is_empty() or str(room.id) != "car_a":
				mate.global_position = player.global_position - shift + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-0.6, 0.6))
			mate.global_position += shift
			mate.velocity = Vector3.ZERO
		if run.crashes():
			map.ride_areal(run.crash_id(), true)
		else:
			map.ride(true)
		game.hud.flash(Color.BLACK, 1.0)
	# Derailed: a blow, darkness, and the car stands in the tunnel.
	if run.crashes() and stage_time > HiveAreaRun.CRASH_AT and done.has("ride_jump"):
		map.ride_areal(run.crash_id(), false)
		game.hud.flash(Color.WHITE, 0.4)
		game.hud.flash(Color.BLACK, 1.6)
		game.player.trauma = 1.0
		game.sounds.play_sound("explosion", 2.0)
		_enter("g_crash")
		return
	if stage_time > RIDE_SECONDS:
		map.ride(false)
		_enter("terminal")

# ---------------------------------------------------------------- the fuses

## The fuses are there to be switched from the moment Nadja leaves (see FUSES).
func _fuses_begin() -> void:
	var kind := station_kind()
	# (That the train stands ready is news the operators bring: not before they are there.)
	if kind == "ready" and stage != "deal":
		return
	if not _once("fuses_out"):
		return
	match kind:
		"fuses":
			game.hud.announce("NOTSTROM", "Drei Sicherungen am Bahnsteig: je mehr an sind, desto schneller kommt der Zug hoch – abfahren kann er nur mit allen dreien.", 6)
		"fuel":
			game.hud.announce("BENZIN", "Der Zug ist trocken: sucht %d Kanister am Bahnhof und füllt sie am Tank ein." % FUEL_NEEDED, 6)
		"ready":
			game.hud.announce("DER ZUG STEHT BEREIT", "Die Operatoren haben ihn schon hochgefahren. Im Stellwerk nur noch starten.", 5)
		_:
			game.hud.announce("NOTSTROM UND BENZIN", "Drei Sicherungen am Bahnsteig bringen den Zug schneller hoch. Und er braucht %d Kanister Benzin: sucht sie und füllt sie am Tank ein." % FUEL_NEEDED, 6)

## The station's kind this night (see STATION_KINDS).
func station_kind() -> String:
	return str(done.get("station_kind", "both"))

func _uses_fuses() -> bool:
	return station_kind() in ["fuses", "both"]

func _uses_fuel() -> bool:
	return station_kind() in ["fuel", "both"]

## The host draws the station's kind for a night: forced (--station=, a test), the one of
## v0.78 in the checks, else one of the three at random.
func _draw_station() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--station=") and arg.trim_prefix("--station=") in STATION_KINDS + ["both"]:
			return arg.trim_prefix("--station=")
	if station_wanted in STATION_KINDS + ["both"]:
		return station_wanted
	return "both" if game.check_mode else str(STATION_KINDS.pick_random())

## The nearest fuse that is off (for the marker), else the platform.
func _fuse_goal() -> Vector3:
	var here: Vector3 = game.player.global_position
	var best := _point("platform")
	var gap := INF
	for index in range(FUSES.size()):
		if not done.has("fuse_%d" % index) and fuse_at(index).distance_squared_to(here) < gap:
			gap = fuse_at(index).distance_squared_to(here)
			best = fuse_at(index)
	return best

## How many of the fuses are on.
func _fuses_on() -> int:
	var count := 0
	for index in range(FUSES.size()):
		if done.has("fuse_%d" % index):
			count += 1
	return count

## What the HUD says while the train comes up.
func _hold_text() -> String:
	var on_now := _fuses_on()
	var fuel := _fuel_in()
	if station_kind() == "ready":
		return "ZUG FÄHRT AN"
	if progress >= 1.0 and _uses_fuel() and fuel < FUEL_NEEDED:
		return "ZUG BEREIT  ·  ES FEHLT BENZIN: %d / %d KANISTER" % [fuel, FUEL_NEEDED]
	if progress >= 1.0 and station_kind() == "fuses" and on_now < FUSES.size():
		return "ZUG BEREIT  ·  ES FEHLEN SICHERUNGEN: %d / %d AN" % [on_now, FUSES.size()]
	var text := "ZUG FÄHRT HOCH"
	if _uses_fuses() and on_now < FUSES.size():
		text += "  ·  NUR %d / %d SICHERUNGEN – SCHALTET SIE EIN" % [on_now, FUSES.size()]
	if _uses_fuel() and fuel < FUEL_NEEDED:
		text += "  ·  BENZIN %d / %d" % [fuel, FUEL_NEEDED]
	return text

## Where the box of a fuse hangs (on the floor below it), and where one stands to use it.
func fuse_at(index: int) -> Vector3:
	var spec: Array = FUSES[index]
	return Vector3(float(spec[0]), _point("platform").y, float(spec[1]))

func fuse_stand(index: int) -> Vector3:
	return fuse_at(index) + Vector3(0, 0, float(FUSES[index][2]) * 0.8)

## The fuse that is off and can be switched from `here`, or -1.
func _fuse_near(here: Vector3) -> int:
	if not on or not stage in FUSE_STAGES or here == Vector3.INF or not _uses_fuses():
		return -1
	for index in range(FUSES.size()):
		if done.has("fuse_%d" % index):
			continue
		var stand := fuse_stand(index)
		if absf(here.y - stand.y) < 1.6 and Vector2(here.x - stand.x, here.z - stand.z).length() < FUSE_REACH:
			return index
	return -1

## A fuse is switched on: the train comes up faster, and the noise draws a few of them.
func _switch_fuse(index: int) -> bool:
	if done.has("fuse_%d" % index):
		return false
	done["fuse_%d" % index] = true
	var box := fuse_at(index) + Vector3(0, 1.3, 0)
	game.sounds.play_at("click", box, 4.0, 0.7)
	game.sounds.play_at("beep", box, 2.0, 1.2)
	game.stats.objectives += 1
	var count := _fuses_on()
	if stage == "hold":
		game.hud.announce("SICHERUNG WIEDER DRIN", "Der Zug zieht wieder an.", 2.5)
	elif count == FUSES.size():
		game.hud.announce("NOTSTROM STEHT", "Alle Sicherungen an: der Zug kommt so schnell hoch, wie er kann.", 4)
		if stage == "deal":
			goal = str(stages["power"][1] if station_kind() == "fuses" else stages["deal"][1])
	else:
		game.hud.announce("SICHERUNG %d / %d" % [count, FUSES.size()], "Das hat man gehört. Augen auf.", 2.5)
	# (Not on the platform's floor in sight of the squad: from where nobody looks.)
	var kinds: Array = FUSE_DRAW[mini(count - 1, FUSE_DRAW.size() - 1)] if stage != "hold" else ["mauler", "striker"]
	var crowd := int(game.alive_count)
	for kind in kinds:
		if crowd >= _crowd_cap():
			break
		var spot := _hidden_spot(12.0, 26.0)
		if spot != Vector3.INF and _spawn(str(kind), spot) != null:
			crowd += 1
	return true

## How many may be alive when a fuse draws them (the station's own number of the hold).
func _crowd_cap() -> int:
	return mini(CROWD_LIMIT, roundi(int(PRESSURE.hold[1]) * _horde())) + game.extra_guns()

## While the train comes up one of the fuses trips: the one furthest from the humans. True
## if one did.
func _trip_fuse() -> bool:
	var best := -1
	var best_gap := -1.0
	var here: Vector3 = game.player.global_position
	for index in range(FUSES.size()):
		if not done.has("fuse_%d" % index):
			continue
		var gap := fuse_at(index).distance_to(here)
		if game.net.hosting and is_instance_valid(game.net.remote):
			gap = minf(gap, fuse_at(index).distance_to(game.net.remote.global_position))
		if gap > best_gap:
			best_gap = gap
			best = index
	if best < 0:
		return false
	done.erase("fuse_%d" % best)
	var box := fuse_at(best) + Vector3(0, 1.3, 0)
	game.sounds.play_at("glitch", box, 4.0, 0.8)
	game.hud.announce("SICHERUNG RAUSGEFLOGEN", "Der Zug fährt nur noch langsam hoch. Schaltet sie wieder ein!", 4)
	return true

## The boxes as they are seen: built when the fuses are there, their lamps red or green.
func _show_fuses() -> void:
	if not on or map == null:
		return
	if not stage in FUSE_STAGES or not _uses_fuses():
		if not fuse_boxes.is_empty() and stage != "board":
			_clear_fuses()
		return
	if fuse_boxes.is_empty():
		_build_fuses()
	for index in range(fuse_boxes.size()):
		var box: Dictionary = fuse_boxes[index]
		var lit := done.has("fuse_%d" % index)
		var lamp: StandardMaterial3D = box.lamp
		lamp.albedo_color = Color(0.3, 1.0, 0.45) if lit else Color(1.0, 0.25, 0.15)
		lamp.emission = lamp.albedo_color
		lamp.emission_energy_multiplier = 3.0 if lit else 2.0 + 2.0 * sin(clock * 9.0)
		(box.lever as Node3D).rotation.x = -0.7 if lit else 0.7

func _build_fuses() -> void:
	for index in range(FUSES.size()):
		var spec: Array = FUSES[index]
		var facing := float(spec[2])
		var root := Node3D.new()
		root.name = "Fuse%d" % index
		add_child(root)
		root.global_position = fuse_at(index)
		# (The box's front looks along +z or -z.)
		root.rotation.y = 0.0 if facing > 0.0 else PI
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color("3a4146")
		steel.roughness = 0.55
		steel.metallic = 0.6
		var housing := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.62, 0.82, 0.22)
		housing.mesh = shape
		housing.material_override = steel
		housing.position = Vector3(0, 1.3, 0.0)
		root.add_child(housing)
		var stripe := MeshInstance3D.new()
		var band := BoxMesh.new()
		band.size = Vector3(0.62, 0.06, 0.012)
		stripe.mesh = band
		var yellow := StandardMaterial3D.new()
		yellow.albedo_color = Color("c9a227")
		stripe.material_override = yellow
		stripe.position = Vector3(0, 1.66, 0.116)
		root.add_child(stripe)
		var lamp_mat := StandardMaterial3D.new()
		lamp_mat.emission_enabled = true
		lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var lamp := MeshInstance3D.new()
		var bulb := BoxMesh.new()
		bulb.size = Vector3(0.1, 0.1, 0.04)
		lamp.mesh = bulb
		lamp.material_override = lamp_mat
		lamp.position = Vector3(0.18, 1.52, 0.12)
		root.add_child(lamp)
		var lever := Node3D.new()
		lever.position = Vector3(-0.08, 1.2, 0.12)
		root.add_child(lever)
		var handle := MeshInstance3D.new()
		var grip := BoxMesh.new()
		grip.size = Vector3(0.06, 0.24, 0.05)
		handle.mesh = grip
		var red := StandardMaterial3D.new()
		red.albedo_color = Color("8f1d18")
		handle.material_override = red
		handle.position = Vector3(0, 0.1, 0.03)
		lever.add_child(handle)
		var word := Label3D.new()
		word.text = "NOTSTROM  F%d" % (index + 1)
		word.font_size = 30
		word.pixel_size = 0.004
		word.modulate = Color("e8d9a0")
		word.outline_size = 6
		word.outline_modulate = Color(0, 0, 0, 0.85)
		word.position = Vector3(0, 1.82, 0.12)
		root.add_child(word)
		fuse_boxes.append({"node": root, "lamp": lamp_mat, "lever": lever})

func _clear_fuses() -> void:
	for box: Dictionary in fuse_boxes:
		if is_instance_valid(box.node):
			(box.node as Node).queue_free()
	fuse_boxes.clear()

# ---------------------------------------------------------------- the fuel

## Where a canister of fuel stands (on the free floor nearest to its place in FUEL).
func fuel_at(index: int) -> Vector3:
	if fuel_spots.size() != FUEL.size():
		fuel_spots.clear()
		for spec: Array in FUEL:
			var spot := Vector3(float(spec[0]), _point("platform").y, float(spec[1]))
			var level := map.level_of(spot + Vector3(0, 0.3, 0))
			var cell := map._free_near(level, Vector2(spot.x, spot.z), 4)
			if cell.x < 99999:
				spot = Vector3(cell.x * CabinMap.CELL, map.level_height(level), cell.y * CabinMap.CELL)
			fuel_spots.append(spot)
	return fuel_spots[index]

## Where one stands to fill the train.
func tank_at() -> Vector3:
	return Vector3(float(TANK[0]), _point("platform").y, float(TANK[1]))

## Who of the two humans "host"/"guest" is as seen here: this machine's own player is "host"
## on the host (and alone), "guest" on a guest.
func _my_tag() -> String:
	return "guest" if game.net.joined else "host"

func _tag_of(who: Node3D) -> String:
	return "host" if who == game.player else "guest"

## The body of whoever carries under that tag, as seen here (null if he is not there).
func _carrier(tag: String) -> Node3D:
	if tag == _my_tag():
		return game.player
	return game.net.remote if is_instance_valid(game.net.remote) else null

## How many canisters are in the train.
func _fuel_in() -> int:
	var count := 0
	for index in range(FUEL.size()):
		if str(done.get("can_%d" % index, "")) == "in":
			count += 1
	return count

## The canister that one carries, or -1.
func _fuel_carried(tag: String) -> int:
	for index in range(FUEL.size()):
		if str(done.get("can_%d" % index, "")) == tag:
			return index
	return -1

## How many are being carried right now.
func _fuel_on_way() -> int:
	var count := 0
	for index in range(FUEL.size()):
		if str(done.get("can_%d" % index, "")) in ["host", "guest"]:
			count += 1
	return count

## The canister that stands within reach of `here` for one who carries none, or -1.
func _can_near(here: Vector3, tag: String) -> int:
	if not on or not stage in FUEL_STAGES or here == Vector3.INF or map == null or _fuel_carried(tag) >= 0 or not _uses_fuel():
		return -1
	for index in range(FUEL.size()):
		if done.has("can_%d" % index):
			continue
		var at := fuel_at(index)
		if absf(here.y - at.y) < 1.6 and Vector2(here.x - at.x, here.z - at.z).length() < FUEL_REACH:
			return index
	return -1

## Whether one who carries a canister stands at the train's tank.
func _tank_near(here: Vector3, tag: String) -> bool:
	if not on or not stage in FUEL_STAGES or here == Vector3.INF or map == null or _fuel_carried(tag) < 0 or not _uses_fuel():
		return false
	var at := tank_at()
	return absf(here.y - at.y) < 1.6 and Vector2(here.x - at.x, here.z - at.z).length() < TANK_REACH

## [E] for the fuel (on the host, for either human): a canister taken up, or one filled
## into the train. `requested` "" is the host's own player, at whatever is in reach.
func _use_fuel(who: Node3D, requested: String) -> bool:
	if who == null or (who is Survivor and (who as Survivor).down):
		return false
	var tag := _tag_of(who)
	var here := who.global_position
	if requested in ["", "tank"] and _tank_near(here, tag):
		var index := _fuel_carried(tag)
		done["can_%d" % index] = "in"
		game.stats.objectives += 1
		var count := _fuel_in()
		game.sounds.play_at("click", tank_at() + Vector3(0, 1.0, 0), 2.0, 0.6)
		game.sounds.play_at("beep", tank_at() + Vector3(0, 1.2, 0), 0.0, 0.9)
		if stage == "hold":
			progress = minf(1.0, progress + FUEL_BOOST)
			progress_text = _hold_text()
		if count >= FUEL_NEEDED:
			game.hud.announce("TANK VOLL", "Genug Benzin im Zug: er kann fahren, sobald er oben ist.", 3.5)
		else:
			game.hud.announce("BENZIN %d / %d" % [count, FUEL_NEEDED], "Noch %d Kanister in den Zug." % (FUEL_NEEDED - count), 2.5)
		return true
	if requested in ["", "can"]:
		var index := _can_near(here, tag)
		if index < 0:
			return false
		done["can_%d" % index] = tag
		game.sounds.play_at("click", fuel_at(index) + Vector3(0, 0.4, 0), 0.0, 1.3)
		if tag == "host":
			game.hud.announce("BENZINKANISTER", "Zum Tank am Zug bringen  ·  [E] dort einfüllen", 2.5)
		return true
	return false

## Where the fuel wants somebody: the tank while a canister is carried, else the nearest
## canister that still stands.
func _fuel_goal() -> Vector3:
	if _fuel_on_way() > 0:
		return tank_at()
	var here: Vector3 = game.player.global_position
	var best := tank_at()
	var gap := INF
	for index in range(FUEL.size()):
		if not done.has("can_%d" % index) and fuel_at(index).distance_squared_to(here) < gap:
			gap = fuel_at(index).distance_squared_to(here)
			best = fuel_at(index)
	return best

## The canisters and the tank as they are seen: where they stand, in the hands of whoever
## carries them, or gone into the train.
func _show_fuel() -> void:
	if not on or map == null:
		return
	if not stage in FUEL_STAGES or not _uses_fuel():
		if not fuel_cans.is_empty() and stage != "board":
			_clear_fuel()
		return
	if fuel_cans.is_empty():
		_build_fuel()
	for index in range(fuel_cans.size()):
		var node: Node3D = fuel_cans[index].node
		var state := str(done.get("can_%d" % index, ""))
		if state == "":
			node.visible = true
			node.global_position = fuel_at(index)
			node.rotation.y = float(index) * 1.3
			continue
		var carrier: Node3D = _carrier(state) if state != "in" else null
		# (In one's own hands it is not seen: the HUD says so.)
		node.visible = carrier != null and carrier != game.player
		if node.visible:
			node.global_position = carrier.global_position + carrier.global_basis * Vector3(0.32, 0.38, 0.05)
			node.rotation.y = carrier.global_rotation.y
	var gauge: Label3D = fuel_tank.gauge
	gauge.text = "BENZIN  %d / %d" % [_fuel_in(), FUEL_NEEDED]
	gauge.modulate = Color("7cff9a") if _fuel_in() >= FUEL_NEEDED else Color("ffcf5a")

## One canister: a red jerrycan with its handle, its spout and a word on it.
func _jerrycan() -> Node3D:
	var root := Node3D.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("b3241b")
	red.roughness = 0.45
	red.metallic = 0.25
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a2b2c")
	dark.roughness = 0.6
	var body := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.34, 0.44, 0.17)
	body.mesh = shape
	body.material_override = red
	body.position = Vector3(0, 0.22, 0)
	root.add_child(body)
	# The pressed cross on its flank.
	for turn in [0.62, -0.62]:
		var rib := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.04, 0.42, 0.012)
		rib.mesh = bar
		rib.material_override = red
		rib.position = Vector3(0, 0.22, 0.09)
		rib.rotation.z = turn
		root.add_child(rib)
	for x in [-0.08, 0.0, 0.08]:
		var grip := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.035, 0.07, 0.11)
		grip.mesh = bar
		grip.material_override = red
		grip.position = Vector3(x, 0.47, 0)
		root.add_child(grip)
	var handle := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(0.22, 0.03, 0.11)
	handle.mesh = top
	handle.material_override = red
	handle.position = Vector3(0, 0.515, 0)
	root.add_child(handle)
	var spout := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.028
	cap.bottom_radius = 0.034
	cap.height = 0.07
	spout.mesh = cap
	spout.material_override = dark
	spout.position = Vector3(0.13, 0.47, 0)
	spout.rotation.z = -0.5
	root.add_child(spout)
	var word := Label3D.new()
	word.text = "BENZIN"
	word.font_size = 22
	word.pixel_size = 0.004
	word.modulate = Color("ffd76a")
	word.outline_size = 6
	word.outline_modulate = Color(0, 0, 0, 0.85)
	word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	word.position = Vector3(0, 0.78, 0)
	root.add_child(word)
	return root

func _build_fuel() -> void:
	for index in range(FUEL.size()):
		var can := _jerrycan()
		can.name = "Fuel%d" % index
		add_child(can)
		can.global_position = fuel_at(index)
		fuel_cans.append({"node": can})
	# The tank: a filler on the edge of the platform beside the car, and what is in it.
	var root := Node3D.new()
	root.name = "FuelTank"
	add_child(root)
	root.global_position = tank_at() + Vector3(0, 0, -0.55)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("3a4146")
	steel.metallic = 0.6
	steel.roughness = 0.5
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color("c9a227")
	var pipe := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.07
	tube.bottom_radius = 0.07
	tube.height = 1.0
	pipe.mesh = tube
	pipe.material_override = steel
	pipe.position = Vector3(0, 0.5, 0)
	root.add_child(pipe)
	var mouth := MeshInstance3D.new()
	var rim := CylinderMesh.new()
	rim.top_radius = 0.11
	rim.bottom_radius = 0.11
	rim.height = 0.08
	mouth.mesh = rim
	mouth.material_override = yellow
	mouth.position = Vector3(0, 1.02, 0)
	root.add_child(mouth)
	var word := Label3D.new()
	word.text = "TANK"
	word.font_size = 34
	word.pixel_size = 0.004
	word.modulate = Color("e8d9a0")
	word.outline_size = 6
	word.outline_modulate = Color(0, 0, 0, 0.85)
	word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	word.position = Vector3(0, 1.55, 0)
	root.add_child(word)
	var gauge := Label3D.new()
	gauge.font_size = 28
	gauge.pixel_size = 0.004
	gauge.outline_size = 6
	gauge.outline_modulate = Color(0, 0, 0, 0.85)
	gauge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gauge.position = Vector3(0, 1.32, 0)
	root.add_child(gauge)
	fuel_tank = {"node": root, "gauge": gauge}

func _clear_fuel() -> void:
	for can: Dictionary in fuel_cans:
		if is_instance_valid(can.node):
			(can.node as Node).queue_free()
	fuel_cans.clear()
	if not fuel_tank.is_empty() and is_instance_valid(fuel_tank.node):
		(fuel_tank.node as Node).queue_free()
	fuel_tank = {}

# ---------------------------------------------------------------- quiet at a counter

## The counters of the map that make a quiet place (see SAFE_REACH).
func _find_safe_spots() -> void:
	safe_spots.clear()
	safe_now = false
	for station: Dictionary in map.stations:
		if not station.has("pos"):
			continue
		var at: Vector3 = station.pos
		var room: Dictionary = map.room_at(at + Vector3(0, 0.3, 0))
		var small := ""
		if not room.is_empty() and not bool(room.get("outdoor", false)):
			var rect: Rect2 = room.outer
			if rect.get_area() <= SAFE_ROOM:
				small = str(room.id)
		safe_spots.append({"pos": at, "room": small})

## Whether this place is quiet.
func is_safe(pos: Vector3) -> bool:
	if safe_spots.is_empty():
		return false
	var room_id := ""
	var asked_room := false
	for spot: Dictionary in safe_spots:
		var at: Vector3 = spot.pos
		if absf(pos.y - at.y) > 2.4:
			continue
		if Vector2(pos.x - at.x, pos.z - at.z).length() < SAFE_REACH:
			return true
		if str(spot.room) != "":
			if not asked_room:
				asked_room = true
				room_id = str(map.room_at(pos).get("id", ""))
			if room_id == str(spot.room):
				return true
	return false

## Whether one of the humans on his feet stands in a quiet place.
func _anybody_safe() -> bool:
	if intro_left > 0.0:
		return false
	var player: Survivor = game.player
	if not player.down and is_safe(player.global_position):
		return true
	if game.net.hosting and is_instance_valid(game.net.remote) and not game.net.remote.down:
		return is_safe(game.net.remote.global_position)
	return false

## Now and then a companion goes over to a counter or an opened cache near it and takes
## up another weapon there (see SHOP_GUNS). Not while there is fighting, not while a place
## is held, and every one of them to every place once a night at the most.
func _send_shopping() -> void:
	if intro_left > 0.0 or _holding() or stage in ["ride", "board", "exit", "nadja", "deal"] or (game.alive_count > 2 and not safe_now):
		return
	var places: Array = []
	for index in range(safe_spots.size()):
		places.append(["s%d" % index, safe_spots[index].pos])
	for index in range(caches.sites.size()):
		var site: Dictionary = caches.sites[index]
		if str(site.get("state", "none")) in ["open", "empty"]:
			places.append(["c%d" % index, site.stand])
	for mate: Teammate in game.team:
		if not is_instance_valid(mate) or mate.down or mate.unarmed or mate.errand != Vector3.INF or mate.target != null or not mate.job.is_empty() or mate.order != "follow":
			continue
		var family := "shotgun" if str(mate.visual.config.weapon) == "shotgun" else "rifle"
		for place: Array in places:
			var key := "%s@%s" % [mate.look, place[0]]
			var at: Vector3 = place[1]
			if shopped.has(key) or absf(at.y - mate.global_position.y) > 1.5 or at.distance_to(mate.global_position) > SHOP_REACH:
				continue
			shopped[key] = true
			if randf() > SHOP_CHANCE:
				continue
			var lists: Array = SHOP_GUNS[family]
			var pool: Array = (lists[0] as Array).duplicate()
			if order.find(stage) > order.find("ride") or run.owns(stage):
				pool.append_array(lists[1])
			var carried: String = mate.visual.weapon_id
			pool = pool.filter(func(id: String) -> bool: return id != carried)
			if pool.is_empty():
				continue
			mate.errand = at
			mate.errand_gun = str(pool.pick_random())
			mate.errand_left = 12.0
			# (One at a time: the other stays with the survivor.)
			return

## A place has to be held right now.
func _holding() -> bool:
	return stage in ["hold", "lockdown", "hall", "mirror"] or run.holding()

func _clear_enemies() -> void:
	for node in game.enemies.get_children():
		var enemy := node as Infected
		if enemy != null and not enemy.dead:
			enemy._retire()
		node.queue_free()
	game.alive_count = 0
	game.boss = null
	loiterers.clear()
	loiter_left = 8.0

# ---------------------------------------------------------------- enemies

## (v0.87, after Henry) Somewhere ahead on the way, where the squad is not yet and does not
## look, a few infected already stand about (Infected.loiter): the place is not empty when
## it gets there. Every LOITER_EVERY seconds a group of LOITER_GROUP comes, as long as fewer
## than LOITER_MOST stand about and the stage has room left; who still stands about far
## behind the squad is taken off again.
const LOITER_EVERY := Vector2(10.0, 18.0)
const LOITER_GROUP := Vector2i(1, 3)
const LOITER_MOST := 6
const LOITER_AHEAD := Vector2(24.0, 42.0)
const LOITER_FORGET := 60.0
const LOITER_KINDS := ["mauler", "mauler", "mauler", "striker"]
var loiterers: Array = []
var loiter_left := 8.0

func _run_loiterers(delta: float) -> void:
	var standing := 0
	var kept: Array = []
	var here: Vector3 = game.player.global_position
	for enemy: Variant in loiterers:
		if not is_instance_valid(enemy) or (enemy as Infected).dead or not (enemy as Infected).loiter:
			continue
		var body := enemy as Infected
		if body.global_position.distance_to(here) > LOITER_FORGET and not _sees(here + Vector3(0, 1.6, 0), body.global_position + Vector3(0, 1.3, 0)):
			body._retire()
			body.queue_free()
			game.alive_count = maxi(0, game.alive_count - 1)
			continue
		kept.append(body)
		standing += 1
	loiterers = kept
	# (Not in the checks, whose numbers of enemies are counted, unless one asks: --loiter.)
	if game.check_mode and not "--loiter" in OS.get_cmdline_user_args():
		return
	loiter_left -= delta
	if loiter_left > 0.0:
		return
	loiter_left = randf_range(LOITER_EVERY.x, LOITER_EVERY.y)
	if _plan_now().is_empty() or _holding() or safe_now or stage in ["ride", "board", "nadja", "deal", "exit"] or standing >= LOITER_MOST:
		return
	var room: int = _crowd() - int(game.alive_count) - entries.coming() - 2
	if room <= 0:
		return
	var spot := _loiter_spot()
	if spot == Vector3.INF:
		return
	for index in range(mini(room, randi_range(LOITER_GROUP.x, LOITER_GROUP.y))):
		var enemy := _place(pick(LOITER_KINDS), spot + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0)))
		if enemy == null:
			continue
		enemy.loiter = true
		enemy.loiter_moan = randf_range(2.0, 10.0)
		# (Turned any way: they are not waiting for the squad.)
		enemy.model.rotation.y = randf() * TAU
		loiterers.append(enemy)

## A place on the way to the marker, LOITER_AHEAD along it, that the survivor does not see;
## else one somewhere around that he does not see either.
func _loiter_spot() -> Vector3:
	var here: Vector3 = game.player.global_position
	var eye := here + Vector3(0, 1.6, 0)
	var goal := use_at if use_at != Vector3.INF else marker
	if goal != Vector3.INF:
		var way: PackedVector3Array = map.path_between(here, goal)
		var walked := 0.0
		var wanted := randf_range(LOITER_AHEAD.x, LOITER_AHEAD.y)
		for index in range(1, way.size()):
			walked += way[index - 1].distance_to(way[index])
			if walked < wanted:
				continue
			var spot: Vector3 = way[index]
			if spot.distance_to(goal) < 6.0 or _sees(eye, spot + Vector3(0, 1.3, 0)):
				continue
			return spot
	return _hidden_spot(LOITER_AHEAD.x, LOITER_AHEAD.y)

## The look of an infected of the stage that runs: for a plain one, as often as STAFF
## says, one of the people who worked here; otherwise "" - one of the looks its kind has
## everywhere. The special kinds keep theirs.
func look_for(kind: String) -> String:
	if kind != "mauler":
		return ""
	var staff: Array = STAFF["below" if order.find(stage) > order.find("ride") else "above"]
	if randf() >= float(staff[1]):
		return ""
	# (Who worked in a place of the random part: what its area says, see HiveAreaRun.staff.)
	return str(((staff[0] as Array) + (STAFF_PLACES.get(stage, []) as Array) + run.staff(stage)).pick_random())

func _spawn(kind: String, at: Vector3) -> Infected:
	var enemy: Infected = game.spawn_enemy(kind, look_for(kind))
	if not is_instance_valid(enemy):
		return null
	enemy.position = at + Vector3(0, 0.08, 0)
	var to: Vector3 = game.player.global_position - at
	enemy.model.rotation.y = atan2(-to.x, -to.z)
	return enemy

## Puts enemies at given places, each on the free ground nearest to its place. With `keep`
## they are the stage's guards: it is over when they have fallen.
func _post(kinds: Array, places: Array, keep: bool) -> void:
	for index in range(kinds.size()):
		var enemy := _place(str(kinds[index]), places[index % places.size()])
		if keep and enemy != null:
			guards.append(enemy)

## One enemy on the free ground nearest to a place (null if there is none).
func _place(kind: String, place: Vector3) -> Infected:
	if place == Vector3.INF or not is_finite(place.x):
		return null
	var level := map.level_of(place + Vector3(0, 0.3, 0))
	var cell := map._free_near(level, Vector2(place.x, place.z), 6)
	if cell.x > 99999:
		return null
	return _spawn(kind, Vector3(cell.x * CabinMap.CELL, map.level_height(level), cell.y * CabinMap.CELL))

## The last guards of the villa: each of them already has infected on him, and they
## fight each other before either looks at the squad. (Their aerosol is used up - what
## kept the infected off them in the first mission.)
func _overrun(places: Array, kinds: Array) -> void:
	for index in range(places.size()):
		var spot: Vector3 = places[index]
		var guard := _place(str(kinds[index % kinds.size()]), spot)
		if guard == null:
			continue
		guard.health = guard.max_health * 0.7
		var pack: Array = []
		for k in range(2):
			var beast := _place("mauler" if k == 0 else "striker", spot + Vector3(randf_range(-5.0, 5.0), 0, randf_range(4.0, 8.0)))
			if beast != null:
				beast.quarry = guard
				beast.alert = true
				pack.append(beast)
		doomed.append({"guard": guard, "pack": pack})

## Keeps every such guard busy with whatever of his pack still stands.
func _run_overrun() -> void:
	for entry in doomed:
		var guard: Infected = entry.guard if is_instance_valid(entry.guard) else null
		if guard == null or guard.dead:
			continue
		if is_instance_valid(guard.quarry) and guard.quarry.is_targetable():
			continue
		guard.quarry = null
		for beast in entry.pack:
			if is_instance_valid(beast) and not (beast as Infected).dead:
				guard.quarry = beast
				break

## Where the guard nearest to the survivor stands (the platform if none is left).
func _nearest_guard() -> Vector3:
	var here: Vector3 = game.player.global_position
	var best := _point("platform")
	var best_gap := INF
	for enemy in guards:
		if is_instance_valid(enemy) and not (enemy as Infected).dead:
			var gap := (enemy as Infected).global_position.distance_squared_to(here)
			if gap < best_gap:
				best_gap = gap
				best = (enemy as Infected).global_position
	return best

## Takes the guards that are left off the field without a kill being counted.
func _dismiss_guards() -> void:
	for enemy in guards:
		if is_instance_valid(enemy) and not (enemy as Infected).dead:
			(enemy as Infected)._retire()
			(enemy as Infected).queue_free()
			game.alive_count = maxi(0, game.alive_count - 1)
	guards.clear()

func _guards_left() -> int:
	var left := 0
	for enemy in guards:
		if is_instance_valid(enemy) and not (enemy as Infected).dead:
			left += 1
	return left

func _sees(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return map.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## A place near the squad that nobody of it can see and that it can be walked to from.
func _hidden_spot(nearest: float, furthest: float) -> Vector3:
	var player: Survivor = game.player
	var here: Vector3 = player.global_position
	var level := map.level_of(here)
	var grid: AStarGrid2D = map.navigation[level]
	var height := map.level_height(level)
	var eye := here + Vector3(0, 1.6, 0)
	for attempt in range(12):
		var turn := randf() * TAU
		var far := randf_range(nearest, furthest)
		var cell := Vector2i(roundi((here.x + cos(turn) * far) / CabinMap.CELL), roundi((here.z + sin(turn) * far) / CabinMap.CELL))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
			continue
		var spot := Vector3(cell.x * CabinMap.CELL, height, cell.y * CabinMap.CELL)
		if _sees(eye, spot + Vector3(0, 1.3, 0)):
			continue
		if map.path_between(spot, here).is_empty():
			continue
		return spot
	return Vector3.INF

## Where somebody comes over the park's wall: one of the three breaches nearest to the squad.
func _park_spot() -> Vector3:
	var here: Vector3 = game.player.global_position
	var order: Array = range(map.spawn_points.size())
	order.sort_custom(func(a: int, b: int) -> bool: return map.spawn_points[a].distance_squared_to(here) < map.spawn_points[b].distance_squared_to(here))
	if order.is_empty():
		return Vector3.INF
	return map.spawn_points[order[randi() % mini(3, order.size())]] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))

## What the level makes of a stage's numbers (the rule "horde": 0.8 on LEICHT, 1.25 on
## SCHWER, 1.5 on ALBTRAUM): so many more may be alive at once, and so much bigger is a
## pack. (Game.alive_cap, which thins the crowd of the farm where the infected are
## tougher, does not reach down here: they do not come through three doors but out of the
## walls all around, and nothing piles up.)
func _horde() -> float:
	return float(game.rules.get("horde", 1.0))

## One of `kinds` by the dice, thinned by THIN.
static func pick(kinds: Array) -> String:
	var kind := str(kinds[randi() % kinds.size()])
	return "mauler" if THIN.has(kind) and randf() > float(THIN[kind]) else kind

## How many may be alive at once in the stage that runs. (Whoever digs himself in gets a
## few more: see HiveEntries.)
func _crowd() -> int:
	var plan := _plan_now()
	if plan.is_empty():
		return 0
	var in_hall := map.in_tokyo(game.player.global_position)
	return mini(CROWD_LIMIT, roundi(int(plan[1]) * _horde())) + game.extra_guns() + entries.more() + run.more() + (tokyo_tasks.more() if tokyo_tasks != null else 0) + (TOKYO_MORE if in_hall else 0)

func _run_pressure(delta: float) -> void:
	var plan := _plan_now()
	if plan.is_empty() or intro_left > 0.0:
		return
	# (At a counter it is quiet: nothing new comes, or while a place is held only slower.)
	if safe_now:
		if not _holding():
			return
		pressure_left -= delta * SAFE_HOLD
	else:
		pressure_left -= delta
	var room: int = _crowd() - int(game.alive_count) - entries.coming()
	if pressure_left > 0.0 or room <= 0:
		return
	# (Whoever digs himself in gets them sooner.)
	pressure_left = float(plan[2]) * randf_range(0.8, 1.25) * entries.haste() * run.haste() * (tokyo_tasks.haste() if tokyo_tasks != null else 1.0) * (TOKYO_HASTE if map.in_tokyo(game.player.global_position) else 1.0)
	var kinds: Array = plan[0]
	var kind := pick(kinds)
	# Nearly all of them come through a way in near the squad - out of a ceiling, out of a
	# wall -, also in plain sight, and a pack of them; the others as they always did, one
	# at a time from where nobody looks.
	var sizes: Array = plan[4]
	var pack := mini(room, randi_range(int(sizes[0]), int(sizes[1])))
	if entries.send(kind, pack, kinds):
		return
	if int(sizes[1]) > 1:
		pressure_left *= LONE
	var at := _park_spot() if str(plan[3]) == "park" or (map.level_of(game.player.global_position) == map.ground and not map.is_indoors(game.player.global_position)) else _hidden_spot(13.0, 30.0)
	if at != Vector3.INF:
		_spawn(kind, at)

# ---------------------------------------------------------------- what is said

## Everything that is said in this mission waits its turn in one queue - the radio, Nadja
## and the operators where they stand, the squad - so that nobody talks over anybody.
## What is not a line but happens between two (see beat and until) waits in it as well.

## A line over the radio - or, Nadja's once she has the facility, over its loudspeakers.
## `first`: it is the next thing said, before whatever else waits (command's word about
## what happens right now does not wait for a talk to be over).
func line(cue: String, first: bool = false) -> void:
	if first:
		lines.push_front({"kind": "radio", "cue": cue})
		return
	# (Before the small talk of the companions that still waits (SquadBanter): what command
	# has to say does not wait for it.)
	for index in range(lines.size()):
		if bool(lines[index].get("banter", false)):
			lines.insert(index, {"kind": "radio", "cue": cue})
			return
	lines.append({"kind": "radio", "cue": cue})

## Command's word about what happens at the station right now: the next thing said - but
## not before command is back on the channel, if he is not yet (then right after his
## first words of his own, or after what is already waiting).
func _command(cue: String) -> void:
	if done.has("radio_clear"):
		line(cue, true)
		return
	for index in range(lines.size()):
		if str(lines[index].get("cue", "")) == "m2_truth":
			lines.insert(index + 1, {"kind": "radio", "cue": cue})
			return
	line(cue)

## A line of somebody who stands there: Nadja while she is with the squad, an operator
## at the station.
func face(cue: String) -> void:
	lines.append({"kind": "person", "cue": cue})

## A short exchange of the squad: whoever of it has a line for this says it, in the order
## the lines are written (Radio.BARKS). Who is not there or is down is passed over.
## `only`: just that one of them.
func talk(cue: String, only: String = "") -> void:
	var parts: Dictionary = Radio.BARKS.get(cue, {})
	for look: String in parts:
		if only == "" or look == only:
			lines.append({"kind": "squad", "cue": cue, "who": look, "at": clock})

## Somebody of the squad calls something out in his turn (one of its calls, as in a fight:
## heard, not read).
func shout(cue: String) -> void:
	lines.append({"kind": "call", "cue": cue})

## A place that was fought for is clear: more often than not somebody says so.
func _all_clear() -> void:
	if randf() < 0.6:
		shout("clear")

## Something that is to happen when the lines have come this far (see _beat).
func beat(id: String) -> void:
	lines.append({"kind": "beat", "id": id})

## The lines go on when something has come about (see _come), or after so many seconds.
func until(id: String, seconds: float) -> void:
	lines.append({"kind": "until", "id": id, "seconds": seconds})

## A radio line of the game's own - somebody is down, a new kind of enemy is seen - takes
## its turn here too (Game._say). While the mission has more to say it is left out.
func heard(cue: String, seconds: float, speaker: String = "") -> void:
	if lines.size() < 2:
		lines.append({"kind": "game", "cue": cue, "seconds": seconds, "who": speaker})

## Until the channel is cleared at the station the voice of command is not Coleman's: his
## lines sound as in the last hours of the first mission (Radio.hijacked).
func channel_taken() -> bool:
	# (The train may be brought up while the operators are still at it.)
	return on and not done.has("radio_clear") and order.find(stage) <= order.find("board")

## Nobody has said anything for so many seconds, and nothing waits to be said.
func _silent_for(seconds: float) -> bool:
	return lines.is_empty() and hold_id == "" and line_left <= -seconds

## Nadja has a word for the squad over the loudspeakers, if nobody else is talking.
func _taunt() -> void:
	if _silent_for(0.0):
		line("m2_n_taunt")

func _run_lines(delta: float) -> void:
	line_left -= delta
	if voice != null and voice.playing and is_instance_valid(talker):
		voice.global_position = talker.global_position + Vector3(0, 1.6, 0)
	if hold_id != "":
		hold_left -= delta
		if hold_left > 0.0 and not _come(hold_id):
			return
		hold_id = ""
	var turns := 0
	while line_left <= 0.0 and hold_id == "" and not lines.is_empty() and turns < 30:
		turns += 1
		var entry: Dictionary = lines.pop_front()
		line_left = _speak(entry)

## Says what has come to its turn. Returns the seconds until the next may follow (none
## for what is passed over, and for what is not a line).
func _speak(entry: Dictionary) -> float:
	var cue := str(entry.get("cue", ""))
	if str(entry.kind) in ["radio", "person", "squad", "game"]:
		# A call somebody of the squad is in the middle of is let out first (but nobody waits long).
		if call_wait < 2.5 and _squad_calling():
			call_wait += 0.15
			lines.push_front(entry)
			return 0.15
		call_wait = 0.0
	match str(entry.kind):
		"beat":
			_beat(str(entry.id))
		"until":
			hold_id = str(entry.id)
			hold_left = float(entry.seconds)
		"call":
			var caller: Teammate = game.squad_voice()
			game.talk_until = 0
			# (v0.86) A call is small talk like the squad's own: it is rationed (Game.bark).
			if caller == null or not game.bark(caller, caller.look, cue, 0.0, false):
				return 0.0
			return maxf(0.0, (int(game.bark_until.get(caller.get_instance_id(), 0)) - Time.get_ticks_msec()) / 1000.0)
		"game":
			return _quiet(game.speak_radio(cue, float(entry.seconds), str(entry.who)))
		"radio":
			var speaker := _speaker_of(cue)
			# An operator who walks at the survivor's side does not call him on the radio:
			# such a line comes from whoever stayed behind, and only from him.
			if pair.has(speaker):
				return 0.0
			var wait: float = game.speak_radio(cue, _reading(cue), "", INK.get(speaker, Color(0, 0, 0, 0)))
			# A line that is only read gets the time it takes to read it.
			if wait > 0.0 and not _recorded(speaker, cue, cue):
				wait = _reading(cue)
			return _quiet(wait)
		"person":
			var speaker := _speaker_of(cue)
			var body := _body_of(speaker)
			# Nadja says it only while she is there. (An operator who has gone is still heard.)
			if body == null and speaker == "nadja":
				return 0.0
			return _quiet(_voice(Radio.pick(cue), body))
		"squad":
			var who := str(entry.who)
			var mate := _squad_member(who)
			if clock - float(entry.at) > STALE:
				return 0.0
			if mate == null:
				# Somebody who is out of sight calls it over from where he is.
				if not entry.has("from"):
					return 0.0
				return _quiet(_voice(Radio.bark(who, cue), null, entry.from))
			return _quiet(_voice(Radio.bark(who, cue), mate))
	return 0.0

## Somebody who stands there says a line: it is heard from where he stands, and read on
## the radio's panel (without the click of a channel). Returns the seconds it takes.
func _voice(said: Dictionary, body: Node3D, from: Vector3 = Vector3.INF) -> float:
	if said.is_empty():
		return 0.0
	if game.net.hosting:
		game.net.hive_voice(said, body.global_position if is_instance_valid(body) else from)
	var length := 0.0
	var path := str(said.sound)
	talker = body
	if path != "" and not game.sounds.hush:
		if voice == null:
			voice = AudioStreamPlayer3D.new()
			voice.bus = "Voice"
			voice.unit_size = VOICE_REACH
			voice.attenuation_filter_cutoff_hz = 9000
			voice.volume_db = 1.0
			add_child(voice)
		voice.stream = load(path)
		# (From where he stands; from where he is known to be; or, if neither, from close by.)
		var where: Vector3 = game.player.global_position
		if is_instance_valid(body):
			where = body.global_position
		elif from != Vector3.INF:
			where = from
		voice.global_position = where + Vector3(0, 1.6, 0)
		voice.play()
		length = voice.stream.get_length()
	var words := str(said.text)
	var seconds := length + 0.7 if length > 0.0 else read_seconds(words.length())
	var hud: SurvivalHUD = game.hud
	hud.radio_label.text = "%s:  %s" % [said.name, words]
	hud.radio_label.add_theme_color_override("font_color", INK.get(str(said.speaker), SurvivalHUD.RADIO_INK))
	hud.radio_left = seconds
	return length + 0.35 if length > 0.0 else seconds

## While a line of the mission is heard the squad keeps its small talk to itself
## (Game.bark) - and for the breath between two lines too, if another is waiting.
func _quiet(seconds: float) -> float:
	if seconds > 0.0:
		game.talk_until = Time.get_ticks_msec() + int((seconds + (0.0 if lines.is_empty() else 0.5)) * 1000.0)
	return seconds

## Somebody of the squad is in the middle of a call.
func _squad_calling() -> bool:
	var now := Time.get_ticks_msec()
	for mate: Teammate in game.team:
		if now < int(game.bark_until.get(mate.get_instance_id(), 0)) - 450:
			return true
	return false

func _speaker_of(cue: String) -> String:
	return str(Radio.LINES[cue][0]) if Radio.LINES.has(cue) else "coleman"

## Whether the variant of a line that was picked last has been recorded.
func _recorded(speaker: String, cue: String, key: String) -> bool:
	return Radio._sound(speaker, cue, int(Radio.last.get(key, 0))) != ""

## The seconds it takes to read a radio line (its longest variant).
func _reading(cue: String) -> float:
	var longest := 0
	if Radio.LINES.has(cue):
		for variant: String in Radio.LINES[cue][1]:
			longest = maxi(longest, variant.length())
	return read_seconds(longest)

static func read_seconds(letters: int) -> float:
	return clampf(1.8 + letters / 15.0, 3.0, 9.5)

## Whether somebody still has a line waiting to be said.
func _to_say(look: String) -> bool:
	for entry: Dictionary in lines:
		if (str(entry.kind) == "squad" and str(entry.who) == look) or (str(entry.kind) == "person" and _speaker_of(str(entry.cue)) == look):
			return true
	return false

## Who of the squad has that look, is there and on his feet - also one who stays at the
## station and is on his way to his post there.
func _squad_member(look: String) -> Teammate:
	for mate: Teammate in game.team:
		if is_instance_valid(mate) and mate.look == look and not mate.down and mate.visible:
			return mate
	for leaver: Dictionary in leavers:
		if is_instance_valid(leaver.node) and str((leaver.node as Teammate).look) == look and not (leaver.node as Teammate).down:
			return leaver.node
	return null

## Where a speaker stands: Nadja, an operator at the station (null if he is not there).
func _body_of(speaker: String) -> Node3D:
	if speaker == "nadja":
		return nadja if is_instance_valid(nadja) and not nadja_gone else null
	for puppet: Dictionary in puppets:
		if str(puppet.look) == speaker and is_instance_valid(puppet.node):
			return puppet.node
	return _squad_member(speaker)


# ---------------------------------------------------------------- the HUD

func title() -> String:
	return str(stages[stage][0]) if stages.has(stage) else ""

## `mine`: with what concerns this machine's own player (not in what the host sends).
func summary(mine: bool = true) -> Array[String]:
	var carrying := mine and stage in FUEL_STAGES and _fuel_carried(_my_tag()) >= 0
	if game.net.joined:
		if not carrying:
			return coop.summary
		var theirs: Array[String] = coop.summary.duplicate()
		theirs.append("Du trägst einen Benzinkanister  ·  zum Tank am Zug")
		return theirs
	var out: Array[String] = []
	if goal != "":
		out.append("▸  " + goal)
	if carrying:
		out.append("Du trägst einen Benzinkanister  ·  zum Tank am Zug")
	if progress >= 0.0:
		out.append(progress_text)
	if stage == "station" and _guards_left() > 0:
		out.append("Wachen auf dem Bahnsteig:  %d" % _guards_left())
	if stage in FUSE_STAGES:
		out.append("Notstrom:  %d / %d Sicherungen an%s" % [_fuses_on(), FUSES.size(), "" if _fuses_on() == FUSES.size() else "  ·  der Zug fährt langsamer hoch"])
		var fuel := _fuel_in()
		var moving := _fuel_on_way()
		out.append("Benzin:  %d / %d Kanister im Zug%s%s" % [fuel, FUEL_NEEDED, "  ·  %d unterwegs" % moving if moving > 0 else "", "" if fuel >= FUEL_NEEDED else "  ·  ohne Benzin fährt er nicht"])
	if safe_now:
		out.append("◆  RUHIGE ZONE  ·  " + ("weniger Nachschub" if _holding() else "hier kommt nichts Neues"))
	out.append_array(run.summary())
	if tokyo_tasks != null:
		out.append_array(tokyo_tasks.summary())
	# (Side goals: a cache that is being opened, the nearest one the survivor knows of.)
	out.append_array(caches.summary())
	return out

func markers() -> Array:
	if game.net.joined:
		return coop.markers
	var at := use_at if use_at != Vector3.INF else marker
	var hall_marks: Array = tokyo_tasks.markers() if tokyo_tasks != null and intro_left <= 0.0 else []
	if at == Vector3.INF or intro_left > 0.0:
		return hall_marks
	# (Inside the simulation hall its own marks lead; the way in is not marked any more.)
	if stage == "terminal" and _tokyo_pending() and tokyo_tasks.told:
		return run.markers() + hall_marks
	var fuses: Array = []
	if stage in FUSE_STAGES:
		for index in range(FUSES.size()):
			if not done.has("fuse_%d" % index):
				fuses.append({"pos": fuse_at(index) + Vector3(0, 0.9, 0), "text": "SICHERUNG"})
		# The fuel: what still stands, and the tank while some of it is carried.
		# (While the survivor carries one, only the tank is marked.)
		var hands_full := _fuel_carried(_my_tag()) >= 0
		if _fuel_in() < FUEL_NEEDED:
			for index in range(FUEL.size()):
				if hands_full:
					break
				if not done.has("can_%d" % index):
					fuses.append({"pos": fuel_at(index) + Vector3(0, 0.9, 0), "text": "BENZIN"})
			if _fuel_on_way() > 0:
				fuses.append({"pos": tank_at() + Vector3(0, 1.4, 0), "text": "TANK"})
	return [{"pos": at + Vector3(0, 1.4, 0), "text": "ZIEL"}] + fuses + run.markers() + hall_marks

## Which music fits: none of the first mission's rounds, so the director says.
func music_phase() -> String:
	if stage in ["hold", "lockdown", "mirror"] or run.holding():
		return "auftrag"
	if stage in ["hall", "exit"]:
		return "letzte_runde"
	if game.alive_count >= 6:
		return "harte_welle"
	return "welle" if game.alive_count > 0 else "anfang"

# ---------------------------------------------------------------- every frame

func _physics_process(delta: float) -> void:
	if not on or not game.is_playing():
		return
	# No round ever comes by itself here.
	if game.phase == "preparing":
		game.preparation_left = 99999.0
	feel_left -= delta
	if feel_left <= 0.0:
		feel_left = 0.12
		var actors := PackedVector3Array()
		for body in game.survivors:
			if is_instance_valid(body):
				actors.append((body as Node3D).global_position)
		for node in game.enemies.get_children():
			actors.append((node as Node3D).global_position)
		map.feel(actors)

func _process(delta: float) -> void:
	if not on or not game.is_playing():
		return
	clock += delta
	stage_time += delta
	_run_heli(delta)
	_show_fuses()
	_show_fuel()
	if game.net.joined:
		coop.move_friends(delta)
		return
	safe_left -= delta
	if safe_left <= 0.0:
		safe_left = 0.25
		safe_now = _anybody_safe()
	shop_left -= delta
	if shop_left <= 0.0:
		shop_left = 2.0
		_send_shopping()
	_run_lines(delta)
	if intro_left > 0.0:
		return
	_watch_nadja(delta)
	_update(delta)
	HiveVoice.watch(self, delta)
	_run_puppets(delta)
	_run_leavers(delta)
	_run_overrun()
	_run_pressure(delta)
	_run_loiterers(delta)
