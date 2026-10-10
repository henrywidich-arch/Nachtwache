class_name Infected
extends CharacterBody3D
## One infected of any type. InfectedVisual handles the model; the rules live here.
##   Mauler  – common, claws at close range. Shambles out of the fog, then runs.
##   Charger – bloated; rushes in and detonates, also when shot.
##   Striker – fast and slim; sheds explosive growths when wounded and when killed.
##   Ripper  – mutant hound; sprints, leaps at its prey from a distance, then bites.
##   Leech   – small and very fast; jumps on a survivor and holds on until it is shaken
##             or shot off.
##   Stalker – not part of any round. Watches, sprints past or creeps up unseen; see _haunt.
##   Medic   – keeps back and lets its gas work: every infected that touches it is
##             strengthened for a while (it mends, takes less harm and is faster), and
##             survivors without a mask are poisoned. Kill it first.
##   Crusher – slow giant with a long reach; goes berserk when half dead, leaps at
##             prey that keeps its distance and dissolves into an acid cloud.
##   C.R.U.  – Helix's soldiers. They are no infected at all, but they are met, shot and
##             counted the same way; how they think and fight is in CruSoldier.
## Bullets leave a mark: every hit jerks the body, concentrated fire makes it stumble
## back and breaks off its attack.
## Everything that can be seen or heard goes through cue(), so a co-op host can pass it
## on to the other player's copy of the same infected.

## voice: growl when hunting. idle: sound while it has not noticed anyone. strike: sound
## of an attack. stagger: how it reacts to concentrated fire.
const TYPES := {
	"mauler": {
		"label": "MAULER", "visuals": ["mauler_hazmat", "mauler_female", "normalzombie", "normalzombie2", "zombiehelm"],
		"voice": "growl", "idle": "moan", "strike": "attack", "pain": "pain", "death": "death",
		"health": 95.0, "health_per_round": 7.0, "speed": 2.45, "speed_per_round": 0.07,
		"damage": 9.0, "reach": 1.25, "attack_time": 0.7, "attack_gap": 1.15, "strike_at": 0.36,
		"radius": 0.3, "height": 1.75, "head": 1.42, "head_size": 0.17, "head_factor": 1.0, "reward": 25, "score": 100,
		"stagger": "stumble"
	},
	"charger": {
		# Two bodies, one enemy: the second ("boomer2") bursts wet and wide, see bursts_wet.
		"label": "CHARGER", "visuals": ["charger", "boomer2"],
		"voice": "charger_roar", "idle": "gurgle", "strike": "", "pain": "", "death": "",
		"health": 85.0, "health_per_round": 4.0, "speed": 3.6, "speed_per_round": 0.05,
		"damage": 50.0, "reach": 2.3, "attack_time": 0.55, "attack_gap": 9.0, "strike_at": 9.0,
		"radius": 0.42, "height": 1.8, "head": 1.5, "head_size": 0.2, "head_factor": 1.0, "reward": 35, "score": 150,
		"stagger": "stumble"
	},
	"striker": {
		"label": "STRIKER", "visuals": ["striker"],
		"voice": "screech", "idle": "striker_idle", "strike": "striker_attack", "pain": "striker_attack", "death": "striker_death",
		"health": 120.0, "health_per_round": 6.0, "speed": 4.5, "speed_per_round": 0.04,
		"damage": 12.0, "reach": 1.3, "attack_time": 0.42, "attack_gap": 0.68, "strike_at": 0.2,
		"radius": 0.28, "height": 1.72, "head": 1.4, "head_size": 0.17, "head_factor": 0.7, "reward": 45, "score": 200,
		"stagger": "flinch"
	},
	"ripper": {
		"label": "RIPPER", "visuals": ["ripper"],
		"voice": "dog_growl", "idle": "dog_growl", "strike": "dog_bite", "pain": "", "death": "dog_death",
		"health": 70.0, "health_per_round": 5.0, "speed": 6.0, "speed_per_round": 0.05,
		"damage": 8.0, "reach": 1.35, "attack_time": 0.5, "attack_gap": 0.95, "strike_at": 0.2,
		"radius": 0.34, "height": 0.95, "head": 0.7, "head_size": 0.2, "head_factor": 0.8, "reward": 30, "score": 150,
		"stagger": "flinch", "pounce_damage": 16.0
	},
	"leech": {
		"label": "LEECH", "visuals": ["leech"],
		"voice": "screech", "idle": "striker_idle", "strike": "striker_attack", "pain": "striker_attack", "death": "striker_death",
		"health": 45.0, "health_per_round": 3.0, "speed": 6.4, "speed_per_round": 0.05,
		"damage": 6.0, "reach": 1.2, "attack_time": 0.4, "attack_gap": 0.8, "strike_at": 0.2,
		"radius": 0.26, "height": 1.1, "head": 0.86, "head_size": 0.16, "head_factor": 1.0, "reward": 30, "score": 150,
		"stagger": "flinch", "cling_damage": 7.0
	},
	"stalker": {
		"label": "STALKER", "visuals": ["stalker"],
		"voice": "screech", "idle": "screech", "strike": "striker_attack", "pain": "striker_attack", "death": "striker_death",
		"health": 900.0, "health_per_round": 0.0, "speed": 6.5, "speed_per_round": 0.0,
		"damage": 30.0, "reach": 1.5, "attack_time": 0.5, "attack_gap": 3.0, "strike_at": 0.25,
		"radius": 0.3, "height": 2.0, "head": 1.8, "head_size": 0.2, "head_factor": 0.6, "reward": 500, "score": 2500,
		"stagger": ""
	},
	# The four-legged hunter of mission two. `prowler`: it has a mind of its own (see Prowler).
	"prowler": {
		"label": "PROWLER", "visuals": ["prowler"], "prowler": true,
		"voice": "prowler_growl", "idle": "prowler_growl", "strike": "prowler_strike", "pain": "prowler_pain", "death": "prowler_death",
		"health": 3000.0, "health_per_round": 0.0, "speed": 8.6, "speed_per_round": 0.0,
		"damage": 14.0, "reach": 2.2, "attack_time": 0.7, "attack_gap": 1.0, "strike_at": 0.31,
		"radius": 0.5, "height": 1.3, "head": 1.0, "head_size": 0.3, "head_factor": 0.8, "reward": 800, "score": 4000,
		"stagger": ""
	},
	# Helix's Containment Response Unit: `visuals` are looks of SoldierVisual, `role` is
	# what CruSoldier makes of them.
	"cru_assault": {
		"label": "C.R.U. ASSAULT", "visuals": ["cru", "cru3"], "human": true, "role": "assault",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 150.0, "health_per_round": 5.0, "speed": 3.3, "speed_per_round": 0.03,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.3, "height": 1.8, "head": 1.52, "head_size": 0.16, "head_factor": 1.0, "reward": 45, "score": 200,
		"stagger": "flinch"
	},
	"cru_shotgunner": {
		"label": "C.R.U. BREACHER", "visuals": ["cru2"], "human": true, "role": "shotgunner",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 160.0, "health_per_round": 5.0, "speed": 3.6, "speed_per_round": 0.03,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.3, "height": 1.8, "head": 1.52, "head_size": 0.16, "head_factor": 1.0, "reward": 50, "score": 220,
		"stagger": "flinch"
	},
	"cru_heavy": {
		"label": "C.R.U. HEAVY", "visuals": ["cru_heavy"], "human": true, "role": "heavy",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 320.0, "health_per_round": 5.0, "speed": 2.3, "speed_per_round": 0.03,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.3, "height": 1.95, "head": 1.64, "head_size": 0.16, "head_factor": 0.6, "reward": 80, "score": 400,
		"stagger": ""
	},
	"cru_marksman": {
		"label": "C.R.U. MARKSMAN", "visuals": ["cru_lead"], "human": true, "role": "marksman",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 120.0, "health_per_round": 5.0, "speed": 3.1, "speed_per_round": 0.03,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.3, "height": 1.8, "head": 1.55, "head_size": 0.16, "head_factor": 1.0, "reward": 60, "score": 260,
		"stagger": "flinch"
	},
	"cru_medic": {
		"label": "C.R.U. MEDIC", "visuals": ["cru3", "cru"], "human": true, "role": "medic",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 140.0, "health_per_round": 5.0, "speed": 3.5, "speed_per_round": 0.03,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.3, "height": 1.8, "head": 1.52, "head_size": 0.16, "head_factor": 1.0, "reward": 60, "score": 260,
		"stagger": "flinch"
	},
	"cru_commander": {
		"label": "C.R.U. COMMANDER", "visuals": ["cru_lead"], "human": true, "role": "commander",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 240.0, "health_per_round": 5.0, "speed": 3.2, "speed_per_round": 0.03,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.3, "height": 1.8, "head": 1.55, "head_size": 0.16, "head_factor": 0.8, "reward": 90, "score": 450,
		"stagger": ""
	},
	# The shield bearer: nothing gets through from the front (see CruSoldier.blocks).
	"cru_elite": {
		"label": "C.R.U. ELITE", "visuals": ["cruelite"], "human": true, "role": "elite",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 260.0, "health_per_round": 6.0, "speed": 3.5, "speed_per_round": 0.03,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.31, "height": 1.89, "head": 1.6, "head_size": 0.16, "head_factor": 1.0, "reward": 110, "score": 450,
		"stagger": "flinch"
	},
	# The three operators (see Operator): hunters of Helix who are driven off, never killed.
	# operator: true makes the game build an Operator for them.
	"phantom": {
		"label": "PHANTOM", "visuals": ["phantom"], "human": true, "role": "phantom", "operator": true,
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 1500.0, "health_per_round": 40.0, "speed": 4.0, "speed_per_round": 0.02,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.32, "height": 1.9, "head": 1.62, "head_size": 0.16, "head_factor": 0.6, "reward": 350, "score": 1500,
		"stagger": ""
	},
	"havoc": {
		"label": "HAVOC", "visuals": ["havoc"], "human": true, "role": "havoc", "operator": true,
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 2100.0, "health_per_round": 55.0, "speed": 3.6, "speed_per_round": 0.02,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.34, "height": 1.95, "head": 1.66, "head_size": 0.17, "head_factor": 0.6, "reward": 400, "score": 1700,
		"stagger": ""
	},
	"ghost": {
		"label": "GHOST", "visuals": ["ghost"], "human": true, "role": "ghost", "operator": true,
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 1250.0, "health_per_round": 35.0, "speed": 3.9, "speed_per_round": 0.02,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.31, "height": 1.88, "head": 1.6, "head_size": 0.16, "head_factor": 0.6, "reward": 350, "score": 1500,
		"stagger": ""
	},
	"cru_shield": {
		"label": "C.R.U. SHIELD", "visuals": ["cru2", "cru3"], "human": true, "role": "shield",
		"voice": "", "idle": "", "strike": "", "pain": "bot_hurt_male", "death": "bot_hurt_male",
		"health": 190.0, "health_per_round": 5.0, "speed": 1.9, "speed_per_round": 0.02,
		"damage": 0.0, "reach": 1.2, "attack_time": 0.5, "attack_gap": 1.0, "strike_at": 0.2,
		"radius": 0.32, "height": 1.8, "head": 1.52, "head_size": 0.16, "head_factor": 1.0, "reward": 70, "score": 320,
		"stagger": ""
	},
	"healer": {
		"label": "MEDIC", "visuals": ["mediczombie"],
		"voice": "gurgle", "idle": "gurgle", "strike": "attack", "pain": "pain", "death": "death",
		"health": 230.0, "health_per_round": 12.0, "speed": 2.1, "speed_per_round": 0.04,
		"damage": 8.0, "reach": 1.25, "attack_time": 0.7, "attack_gap": 1.6, "strike_at": 0.36,
		"radius": 0.32, "height": 1.8, "head": 1.45, "head_size": 0.17, "head_factor": 0.9, "reward": 90, "score": 450,
		"stagger": "flinch"
	},
	"crusher": {
		"label": "CRUSHER", "visuals": ["crusher"],
		"voice": "roar", "idle": "roar", "strike": "crusher_attack", "pain": "crusher_pain", "death": "crusher_death",
		"health": 2400.0, "health_per_round": 0.0, "speed": 2.9, "speed_per_round": 0.0,
		"damage": 44.0, "reach": 2.6, "attack_time": 1.15, "attack_gap": 1.7, "strike_at": 0.5,
		"radius": 0.5, "height": 2.0, "head": 1.9, "head_size": 0.28, "head_factor": 0.55, "reward": 400, "score": 2000,
		"stagger": ""
	}
}
const CHARGER_BLAST := 4.3
## Infected that are fights of their own: what a difficulty does to the health of the horde
## (the rule "brood", see Profile) leaves them as they are.
const BROOD_APART := ["crusher", "stalker", "prowler"]
## Looks of the plain infected that are women: they get the female voices.
const FEMALE_LOOKS := ["mauler_female", "hive_lab"]
## The Medic's gas: how far it reaches at most, the health it gives back per second to
## an infected it has strengthened, the share of a hit that still gets through to them,
## and how close the Medic comes to its prey before it stops and lets the gas work.
const CLOUD_RADIUS := 6.5
const CLOUD_HEAL := 9.0
const CLOUD_WARD := 0.55
const CLOUD_KEEP := 9.0
## Seconds an infected stays strengthened after it last touched the gas, and how much
## faster it is meanwhile.
const BUFF_SECONDS := 8.0
const BUFF_PACE := 1.15
## The gas is no dome but wisps that creep round the Medic. Each: the angle it starts at,
## its distance from the Medic, its radius, and how fast it circles (radians a second).
const WISPS := [
	[0.0, 0.0, 1.7, 0.0],
	[0.4, 3.2, 2.6, 0.2],
	[2.3, 3.7, 2.3, -0.16],
	[4.1, 3.0, 2.8, 0.11],
	[5.3, 4.4, 2.0, -0.24]
]
## Share of its health an infected must lose in one burst of fire to be staggered.
const STAGGER_SHARE := 0.45
const LURK_SPEED := 0.6
const NOTICE_RANGE := 13.0
## On the long way in from the fence the infected hurry: beyond HURRY_FROM metres from
## their prey they speed up by up to HURRY_BOOST, but never beyond HURRY_TOP m/s.
const HURRY_FROM := 17.0
const HURRY_BOOST := 0.8
const HURRY_TOP := 6.4
## The Stalker: cosine of half the angle in which a survivor counts as looking at it, how
## near a survivor may come before it is gone, its sprint, and the damage that drives it
## off while it hunts.
const STALKER_VIEW := 0.8
const STALKER_FLEE := 9.0
const STALKER_DASH := 11.0
const STALKER_DRIVE_OFF := 220.0
## The Leech: what one press of [E] does towards shaking it off, and how fast that fades.
const SHAKE_STEP := 0.17
const SHAKE_FADE := 0.3
## A hit that takes this share of the full health in one go tears the body apart.
const OVERKILL_SHARE := 0.6
## The Ripper leaps from this far away (metres), the Crusher from here.
const POUNCE_RANGE := Vector2(3.2, 8.5)
const LEAP_RANGE := Vector2(5.0, 12.0)
## The Crusher's leap: how long the whole of it takes and when it lands; the seconds of
## it during which the body is in the air; how far in front of its prey it comes down and
## how far ahead of a running one it aims (seconds of the prey's way); the seconds until
## the next leap; and the quake where it lands (reach in metres, harm in its middle).
const LEAP_SECONDS := 2.3
const LEAP_STRIKE := 1.5
const LEAP_FLIGHT := Vector2(0.5, 1.38)
const LEAP_SHORT := 1.3
const LEAP_LEAD := 0.45
const LEAP_WAIT := 6.5
const QUAKE_REACH := 4.5
const QUAKE_HARM := 26.0
const POUNCE_FLIGHT := 0.46
const ENRAGE_PACE := 1.6
const GRAVITY := 22.0
## The round after which nobody gets any faster (they still get tougher): past it the
## endless night would outrun the survivors.
const SPEED_ROUNDS := 20
## Fire on a body: what it does a second, and how often it bites.
const BURN_DPS := 22.0
const BURN_TICK := 0.5

var game: Node3D
var kind := "mauler"
var visual_kind := ""
var wave := 1
## Number that identifies this infected to both players of a co-op match.
var net_id := 0
## A puppet only shows what the host's infected does; it has no will of its own.
var puppet := false
## Nowhere for the moment (an operator between two places): nobody aims at it, nothing
## reaches it, the map does not show it.
var absent := false
var net_position := Vector3.ZERO
var net_yaw := 0.0
var spec: Dictionary
var health := 100.0
var max_health := 100.0
var speed := 2.0
var dead := false
var path := PackedVector3Array()
var path_index := 0
var repath_left := 0.0
## The survivor this infected is after right now.
var prey: Node3D
## Somebody who is not of the squad and is gone for first, as long as he stands (mission
## two: the last guards of the villa and what overruns them). Set by whoever stages it.
var quarry: Node3D = null
## Set while another enemy hurts this one: nobody is paid for such a death.
var uncredited := false
var cooldown := 0.5
var attack_clock := -1.0
var attack_length := 0.7
var strike_time := 0.36
var attack_reach := 1.25
var attack_damage := 9.0
var struck := false
var fuse_left := -1.0
var shed := false
var growl_left := 3.0
var last_step := 0
## Maulers shamble until they notice a survivor, get shot or lose patience.
var alert := true
var lurk_left := 0.0
## Seconds the infected cannot act: staggered by gunfire or screaming.
var held_left := 0.0
var stagger_cooldown := 0.0
## The speed a blow has given the body; it wears off within a step or two.
var knock := Vector3.ZERO
## Seconds it goes on burning, the time to the fire's next bite, and who lit it.
var burn_left := 0.0
var burn_tick := 0.0
var burn_source: Node
## Lit by somebody with the sweeper's ability: while it burns, what it does when it bursts
## does the survivors no harm (a Charger's blast, a Striker's growths).
var burn_tame := false
var flames: CPUParticles3D
var flame_lamp: OmniLight3D
## Seconds a body that fell burning burns on.
var ember_left := 0.0
var burst := 0.0
var burst_left := 0.0
var pain_left := 0.0
## Squeezing past another infected that stands in the way.
var blocked_for := 0.0
var dodge_left := 0.0
var dodge_side := 1.0
## Leaps: the Ripper's pounce runs through "crouch", "air" and "land".
var leap := ""
var leap_left := 0.0
var leap_hit := false
var special_cooldown := 2.0
var enraged := false
## Seconds this one stays strengthened by a Medic's gas.
var warded := 0.0
## The Medic's gas as it is seen, how long it has been creeping, and when it next works
## on those who touch it.
var cloud: Node3D
var cloud_lamp: OmniLight3D
var cloud_clock := 0.0
var cloud_tick := 0.0
## The Stalker's mode: "watch" stands and stares, "dash" sprints to dash_to, "hunt" creeps
## up on its prey whenever nobody looks.
var haunt := "watch"
var haunt_left := 7.0
var watched_for := 0.0
var driven := 0.0
var grabbing := 0.0
var dash_to := Vector3.ZERO
## The Crusher's leap: "" (none), "crouch" before it takes off, "air", "down" once landed.
var jump := ""
var jump_from := Vector3.ZERO
var jump_to := Vector3.ZERO
## The survivor a Leech is hanging on to, and how close that survivor is to shaking it off.
var clung_to: Node3D
var shaken := 0.0
var cling_cooldown := 0.0
var cling_tick := 0.0
var voices: Dictionary = {}
## Set while it comes through a way in of the second mission (a ceiling, a hole in a
## wall): that has the body until it stands on the floor. See HiveEntries.carry.
var entering: HiveEntries = null
var model: InfectedVisual
var head_box: StaticBody3D

func _ready() -> void:
	spec = TYPES[kind]
	# A Medic stands still to let its gas work, also in a doorway. So that nobody gets stuck
	# behind it, the others walk through it.
	for node in get_tree().get_nodes_in_group("infected"):
		var other := node as Infected
		if other != null and (kind == "healer" or other.kind == "healer"):
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)
	add_to_group("infected")
	collision_layer = 4
	# World, survivors, other infected and railings.
	collision_mask = 1 | 2 | 4 | 16
	floor_snap_length = 0.3
	# A modifier of the round may make everybody tougher.
	max_health = (float(spec.health) + float(spec.health_per_round) * (wave - 1)) * float(game.rules.get("health", 1.0))
	# A difficulty may make the horde alone tougher (Profile.ZOMBIE_TEST_HEALTH).
	if not spec.get("human", false) and not kind in BROOD_APART:
		max_health *= float(game.rules.get("brood", 1.0))
	health = max_health
	# A Crusher that turns up before the last round is not yet fully grown.
	if kind == "crusher" and wave < int(game.ROUNDS.size()):
		max_health *= 0.55 if wave <= 6 else 0.75
		health = max_health
	speed = (float(spec.speed) + float(spec.speed_per_round) * (mini(wave, SPEED_ROUNDS) - 1)) * randf_range(0.93, 1.08) * float(game.rules.pace)
	var capsule := CapsuleShape3D.new()
	capsule.radius = spec.radius
	capsule.height = spec.height
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = float(spec.height) * 0.5
	add_child(shape)
	var look: String = visual_kind if visual_kind != "" else str(spec.visuals.pick_random())
	if look == "ripper":
		model = RipperVisual.new()
	elif look == "prowler":
		model = ProwlerVisual.new()
	elif spec.get("human", false):
		model = CruVisual.new()
	else:
		model = InfectedVisual.new()
	model.kind = look
	add_child(model)
	for role in ["voice", "idle", "strike", "pain", "death"]:
		voices[role] = str(spec[role])
	if kind == "stalker":
		haunt_left = {"watch": randf_range(5.0, 9.0), "dash": 6.0, "hunt": 45.0}.get(haunt, 7.0)
	if look in FEMALE_LOOKS:
		voices = {"voice": "growl_female", "idle": "growl_female", "strike": "growl_female", "pain": "pain_female", "death": "death_female"}
	# The head gets its own hit zone that follows the animated skull, so hunched and
	# oversized infected can be shot where their head really is.
	head_box = StaticBody3D.new()
	head_box.name = "Head"
	head_box.collision_layer = 8
	head_box.collision_mask = 0
	head_box.set_meta("infected", self)
	var skull := SphereShape3D.new()
	skull.radius = spec.head_size
	var skull_shape := CollisionShape3D.new()
	skull_shape.shape = skull
	head_box.add_child(skull_shape)
	add_child(head_box)
	head_box.position.y = float(spec.head) + 0.15
	repath_left = randf() * 0.4
	growl_left = randf_range(1.0, 6.0)
	# The hound leaps as soon as it is close enough; the Crusher holds its jump back a while.
	special_cooldown = randf_range(0.2, 0.7) if kind == "ripper" else randf_range(1.0, 3.0)
	net_position = position
	if kind == "mauler":
		alert = false
		lurk_left = randf_range(1.5, 4.0)
	if kind == "healer":
		_build_cloud()

## The Medic's gas: low wisps that creep over the ground around it, each with a faint
## green stain under it. It stays below the chest, so the Medic itself is in plain view.
func _build_cloud() -> void:
	cloud = Node3D.new()
	cloud.name = "Cloud"
	# Not carried along as a child: the wisps lie in the world and are moved by hand.
	cloud.top_level = true
	add_child(cloud)
	for i in range(WISPS.size()):
		var reach := float(WISPS[i][2])
		var wisp := Node3D.new()
		wisp.name = "Wisp%d" % i
		cloud.add_child(wisp)
		var gas := FogMaterial.new()
		# Thin around the Medic itself, thicker where the gas has pooled.
		gas.density = 0.16 if i == 0 else 0.34
		gas.albedo = Color(0.5, 0.74, 0.34)
		gas.emission = Color(0.012, 0.045, 0.01)
		gas.height_falloff = 1.4
		gas.edge_fade = 0.75
		var haze := FogVolume.new()
		haze.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		haze.size = Vector3(reach * 2.0, 1.7, reach * 2.0)
		haze.material = gas
		haze.position.y = 0.5
		wisp.add_child(haze)
		var stain := Decal.new()
		stain.texture_albedo = game.fx.soft_texture
		stain.modulate = Color(0.34, 0.95, 0.22, 0.34)
		stain.size = Vector3(reach * 2.1, 1.2, reach * 2.1)
		stain.cull_mask = 1
		stain.upper_fade = 0.3
		stain.lower_fade = 0.3
		wisp.add_child(stain)
	# A dim light of the same colour on the Medic itself, so that it stands out in the dark.
	cloud_lamp = OmniLight3D.new()
	cloud_lamp.light_color = Color(0.6, 1.0, 0.45)
	cloud_lamp.light_energy = 0.9
	cloud_lamp.omni_range = 3.2
	cloud_lamp.shadow_enabled = false
	cloud_lamp.position = Vector3(0, 1.5, -0.5)
	add_child(cloud_lamp)
	_drift(0.0)
	if game.hud != null and game.is_playing() and game.medic_round != wave:
		game.medic_round = wave
		game.hud.announce("MEDIC", "Sein Gas stärkt jeden Infizierten, den es berührt: grüne Augen, grüner Schein. Schalte ihn zuerst aus.", 4.5)
		if not puppet:
			game.tell_once("medic", "medic_seen")

## Where wisp `index` of this Medic's gas lies right now.
func wisp_position(index: int) -> Vector3:
	var wisp: Array = WISPS[index]
	var angle := float(wisp[0]) + float(wisp[3]) * cloud_clock
	var away := float(wisp[1]) * (0.88 + 0.12 * sin(cloud_clock * 0.6 + index * 1.7))
	return global_position + Vector3(cos(angle), 0.0, sin(angle)) * away

## Lets the gas creep on.
func _drift(delta: float) -> void:
	cloud_clock += delta
	for i in range(WISPS.size()):
		(cloud.get_child(i) as Node3D).global_position = wisp_position(i)

## True for a place in the gas of this living Medic.
func in_cloud(pos: Vector3) -> bool:
	if kind != "healer" or dead or absf(pos.y - global_position.y) > 2.0:
		return false
	var spot := Vector2(pos.x, pos.z)
	if spot.distance_to(Vector2(global_position.x, global_position.z)) > CLOUD_RADIUS:
		return false
	for i in range(WISPS.size()):
		var centre := wisp_position(i)
		if spot.distance_to(Vector2(centre.x, centre.z)) < float(WISPS[i][2]):
			return true
	return false

## The gas strengthens every infected it touches. Soldiers and other Medics get nothing
## from it.
func _tend(delta: float) -> void:
	cloud_tick -= delta
	if cloud_tick > 0.0:
		return
	cloud_tick = 0.25
	for node in get_tree().get_nodes_in_group("infected"):
		var other := node as Infected
		if other == self or other.dead or other.kind == "healer" or other.spec.get("human", false) or not in_cloud(other.global_position):
			continue
		other.soak()

## Touched by a Medic's gas: strengthened at once, and for a while after leaving it.
func soak() -> void:
	if warded <= 0.0:
		cue("buff", [true])
	warded = BUFF_SECONDS

## The gas thins out and is gone.
func _lift_cloud() -> void:
	var fading := cloud
	cloud = null
	if cloud_lamp != null:
		cloud_lamp.create_tween().tween_property(cloud_lamp, "light_energy", 0.0, 1.0)
	for wisp in fading.get_children():
		for child in wisp.get_children():
			if child is Decal:
				fading.create_tween().tween_property(child, "modulate:a", 0.0, 1.2)
			elif child is FogVolume:
				fading.create_tween().tween_property((child as FogVolume).material, "density", 0.0, 1.4)
	get_tree().create_timer(1.5, false).timeout.connect(fading.queue_free)

## True if something flying along `direction` would be stopped before it reaches the
## body (the shield of a C.R.U. shield bearer).
func blocks(_direction: Vector3) -> bool:
	return false

func is_headshot(point: Vector3) -> bool:
	return point.y - global_position.y > float(spec.head)

func facing() -> Vector3:
	return Vector3(-sin(model.rotation.y), 0, -cos(model.rotation.y))

func mouth() -> Vector3:
	return global_position + Vector3.UP * minf(1.5, float(spec.height) * 0.85)

func _low_ceiling(at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.UP * 2.85, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## With `bodies` the line also ends at what stops bodies but not bullets or claws:
## railings, fences and window sills.
func _clear_line(target: Vector3, bodies: bool = false) -> bool:
	var eye := minf(1.1, float(spec.height) * 0.6)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * eye, target + Vector3.UP * 1.1, 17 if bodies else 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# ---------------------------------------------------------------- what others see and hear

## Shows an action here and, when hosting a co-op match, on the other player's copy.
func cue(action: String, args: Array = []) -> void:
	show_cue(action, args)
	if game.net != null and game.net.hosting:
		game.net.send_cue(self, action, args)

func show_cue(action: String, args: Array) -> void:
	match action:
		"notice":
			alert = true
			if str(args[0]) != "":
				model.scream(str(args[0]))
				game.sounds.play_at(str(voices.voice), mouth(), 3.0, 1.15)
		"attack":
			model.attack(float(args[1]), float(args[2]), str(args[0]))
			game.sounds.play_at("swipe", global_position + Vector3.UP * 1.2, 0.0, 0.7 if kind == "crusher" else 1.0)
			if str(voices.strike) != "" and (kind != "mauler" or randf() < 0.6):
				game.sounds.play_at(str(voices.strike), mouth(), 0.0, 1.2 if voices.strike == "growl_female" else 1.0)
		"hit":
			model.hit(float(args[0]), float(args[1]))
		"buff":
			model.set_buffed(bool(args[0]))
			if bool(args[0]):
				game.sounds.play_at("hiss", global_position + Vector3.UP, -6.0, 1.5)
		"stagger":
			model.stagger(str(args[0]) == "stumble", str(args[0]))
		"pain":
			game.sounds.play_at(str(voices.pain), mouth(), 0.0, 1.25 if voices.pain == "striker_attack" else 1.0)
		"fuse":
			fuse_left = maxf(fuse_left, 0.0)
			game.sounds.play_at("fuse", global_position + Vector3.UP)
		"swell":
			model.swell = 1.0
		"burst":
			model.hide()
			if bursts_wet():
				game.fx.boomer_burst(global_position + Vector3(0, 0.9, 0))
			else:
				game.fx.charger_burst(global_position + Vector3(0, 0.9, 0))
		"shed":
			game.fx.drop_growths(global_position + Vector3(0, 1.0, 0), int(args[0]), puppet, args.size() > 1 and bool(args[1]))
		"enrage":
			enraged = true
			model.scream("roar")
			game.sounds.play_at("roar", mouth(), 4.0, 0.85)
			game.player.shake_from(global_position, 0.8, 22.0)
			game.hud.announce("DER CRUSHER RAST", "Er ist schneller geworden – bleib in Bewegung!", 3.5)
		"pounce":
			model.pounce()
			game.sounds.play_at("dog_bark", mouth())
		"bite":
			game.sounds.play_at("dog_bite", mouth(), 1.0)
		"die":
			model.set_buffed(false)
			model.die(str(args[0]))
			game.fx.death(self, bool(args[1]), args[2] as Vector3, bool(args[3]))
			if str(voices.death) != "":
				game.sounds.play_at(str(voices.death), mouth())
			_remove_after(6.0 if kind == "striker" else 8.0)
		"cling":
			game.sounds.play_at("striker_attack", mouth(), 3.0, 1.35)
			# On a guest's machine: the host says whether it is this player it jumped on.
			if puppet and bool(args[0]):
				clung_to = game.player
				game.player.clung_by = self
				add_collision_exception_with(game.player)
		"release":
			if puppet and clung_to != null:
				game.player.clung_by = null
				remove_collision_exception_with(game.player)
				clung_to = null
		"vanish":
			model.hide()
			game.fx.vanish(global_position + Vector3(0, 1.0, 0))
			game.sounds.play_at("screech", global_position + Vector3.UP, -7.0, 0.55)
			dead = true
			_remove_after(0.1)
		"grab":
			game.sounds.play_at("striker_attack", mouth(), 6.0, 0.7)
			game.sounds.play_at("screech", mouth(), 2.0, 0.8)
			if global_position.distance_to(game.player.global_position) < 3.0:
				game.player.trauma = 1.0
				game.hud.flash(Color(0.35, 0.0, 0.0), 0.7)
		"say":
			game.bark(self, voice(), str(args[0]), 2.0)
		"burn":
			_show_flames(bool(args[0]))
		"dissolve":
			model.dissolve()
			game.fx.acid_cloud(global_position, puppet)
			game.sounds.play_at(str(voices.death), mouth())
			_remove_after(3.4)

# ---------------------------------------------------------------- behaviour

func _physics_process(delta: float) -> void:
	if entering != null and entering.carry(self, delta):
		return
	if dead:
		if cloud != null:
			_lift_cloud()
		_smoulder(delta)
		model.animate(delta, 0.0)
		return
	if cloud != null:
		_drift(delta)
	if puppet:
		_follow(delta)
		return
	if not game.is_playing():
		return
	_burn(delta)
	if dead:
		return
	if kind == "stalker":
		_haunt(delta)
		return
	# Animate first: a clip that carries the body reports how far it moves this frame.
	var moved := get_real_velocity()
	model.animate(delta, Vector2(moved.x, moved.z).length())
	cooldown -= delta
	repath_left -= delta
	pain_left -= delta
	if warded > 0.0:
		# Strengthened by a Medic's gas: it mends until the gas has worn off.
		warded -= delta
		health = minf(max_health, health + CLOUD_HEAL * delta)
		if warded <= 0.0:
			cue("buff", [false])
	if kind == "healer":
		_tend(delta)
	stagger_cooldown -= delta
	special_cooldown -= delta
	burst_left -= delta
	if burst_left <= 0.0:
		burst = 0.0
	if is_instance_valid(quarry) and quarry.is_targetable():
		prey = quarry
	elif repath_left <= 0 or not is_instance_valid(prey) or not prey.is_targetable():
		prey = game.nearest_survivor(global_position, prey)
	var target: Vector3 = prey.global_position
	var offset := Vector2(target.x - global_position.x, target.z - global_position.z)
	var distance := offset.length()
	# A survivor on the storey above or below is out of reach however close it looks.
	var same_floor := absf(target.y - global_position.y) < 1.4
	if not alert:
		lurk_left -= delta
		if lurk_left <= 0.0 or (distance < NOTICE_RANGE and same_floor):
			_notice(distance)
	if kind == "leech" and _cling(delta, target, distance, same_floor):
		return
	if kind == "ripper" and _pounce(delta, target, distance, same_floor):
		_ambient(delta, Vector3(offset.x, 0, offset.y).normalized(), leap == "crouch")
		return
	if repath_left <= 0:
		path = game.cabin.path_between(global_position, target)
		path_index = 1 if path.size() > 1 else 0
		repath_left = 0.4 + randf() * 0.25
	var direction := Vector3.ZERO
	while path_index < path.size():
		var point := Vector2(path[path_index].x - global_position.x, path[path_index].z - global_position.z)
		if point.length() < 0.35:
			path_index += 1
		else:
			direction = Vector3(point.x, 0, point.y).normalized()
			break
	# Up close, head straight for the survivor instead of zig-zagging between cells.
	if distance > 0.5 and same_floor and (direction == Vector3.ZERO or (distance < 3.0 and _clear_line(target, true))):
		direction = Vector3(offset.x, 0, offset.y).normalized()
	var pace := speed if alert else LURK_SPEED
	if alert and warded > 0.0:
		pace *= BUFF_PACE
	if alert and distance > HURRY_FROM:
		pace = minf(pace * (1.0 + minf((distance - HURRY_FROM) / 18.0, 1.0) * HURRY_BOOST), maxf(pace, HURRY_TOP))
	if enraged:
		pace *= ENRAGE_PACE
	var reach: float = spec.reach
	# The Medic leaves the fighting to the others: with its prey in sight it stops a good
	# way off and lets its cloud work.
	if kind == "healer" and same_floor and distance < CLOUD_KEEP and distance > reach * 1.6 and _clear_line(target):
		pace = 0.0
	# Clips that carry the body (a stumble, a leap) hand their travel over as real motion.
	var push := facing() * (model.travel / maxf(delta, 0.001))
	if held_left > 0.0:
		# Stunned or screaming: no steering.
		held_left -= delta
		pace = 0.0
	elif kind == "charger":
		if fuse_left < 0.0 and distance < reach and same_floor and _clear_line(target):
			fuse_left = spec.attack_time
			cue("fuse")
		if fuse_left >= 0.0:
			fuse_left -= delta
			model.swell = 1.0 - maxf(0.0, fuse_left) / float(spec.attack_time)
			pace *= 0.55
			if fuse_left <= 0.0:
				detonate()
				return
	elif attack_clock >= 0.0:
		var before := attack_clock
		attack_clock += delta
		pace *= 0.35 if kind == "striker" else 0.0
		if jump != "":
			# The clip stays on the spot; the body does the flying.
			push = Vector3.ZERO
			if jump == "crouch" and attack_clock >= LEAP_FLIGHT.x:
				# It takes off for where its prey will be when it comes down, and lands just
				# short of it.
				jump = "air"
				var ahead := target
				if prey is CharacterBody3D:
					var run: Vector3 = (prey as CharacterBody3D).velocity
					ahead += Vector3(run.x, 0, run.z) * LEAP_LEAD
				var way := Vector3(ahead.x - global_position.x, 0, ahead.z - global_position.z)
				jump_from = global_position
				jump_to = global_position + way.normalized() * clampf(way.length() - LEAP_SHORT, 1.0, LEAP_RANGE.y)
			if jump == "air":
				var span := jump_to - jump_from
				push = Vector3(span.x, 0, span.z) * (smoothstep(LEAP_FLIGHT.x, LEAP_FLIGHT.y, attack_clock) - smoothstep(LEAP_FLIGHT.x, LEAP_FLIGHT.y, before)) / maxf(delta, 0.001)
				if attack_clock >= LEAP_FLIGHT.y:
					jump = "down"
		if not struck and attack_clock >= strike_time:
			struck = true
			var hit := distance < attack_reach * 1.25 and same_floor and _clear_line(target)
			if hit:
				prey.receive_damage(attack_damage * float(game.rules.harm), global_position, "", Skills.kind_of(self))
			if kind == "crusher":
				game.sounds.play_at("thud", global_position, 6.0 if jump != "" else 4.0)
				game.player.shake_from(global_position, 1.3 if jump != "" else 0.9, 18.0 if jump != "" else 14.0)
				if jump != "":
					_quake(prey if hit else null)
		if attack_clock >= attack_length:
			attack_clock = -1.0
			jump = ""
			cooldown = (float(spec.attack_gap) - float(spec.attack_time)) / float(game.rules.pace)
	elif kind == "crusher" and special_cooldown <= 0.0 and same_floor and distance > LEAP_RANGE.x and distance < LEAP_RANGE.y and _clear_line(target, true):
		# Prey that keeps its distance gets jumped: a crouch, then a long, low leap.
		special_cooldown = LEAP_WAIT
		jump = "crouch"
		_begin_attack("leap", LEAP_SECONDS, LEAP_STRIKE, reach * 1.2, float(spec.damage) * 1.4)
	elif distance < reach and same_floor:
		pace = 0.0
		if cooldown <= 0.0 and _clear_line(target):
			_begin_attack(model.pick_attack(), float(spec.attack_time), float(spec.strike_at), reach, float(spec.damage))
	# An infected stuck behind another one steps around it instead of queueing.
	if pace > 0.5 and Vector2(moved.x, moved.z).length() < pace * 0.25:
		blocked_for += delta
	else:
		blocked_for = 0.0
	dodge_left -= delta
	var right := Vector3(-direction.z, 0, direction.x)
	if blocked_for > 0.35 and dodge_left <= 0.0:
		blocked_for = 0.0
		dodge_left = 0.7
		dodge_side = -dodge_side
		for i in range(get_slide_collision_count()):
			var other := get_slide_collision(i).get_collider() as Infected
			if other != null:
				dodge_side = -1.0 if (other.global_position - global_position).dot(right) > 0.0 else 1.0
	if dodge_left > 0.0 and pace > 0.5:
		direction = (direction + right * dodge_side * 1.5).normalized()
	knock = knock.move_toward(Vector3.ZERO, delta * 16.0)
	velocity.x = direction.x * pace + push.x + knock.x
	velocity.z = direction.z * pace + push.z + knock.z
	if not is_on_floor():
		velocity.y -= delta * GRAVITY
	else:
		velocity.y = 0
	move_and_slide()
	var look := direction if pace > 0.1 and direction.length() > 0.1 else Vector3(offset.x, 0, offset.y).normalized()
	_ambient(delta, look, distance > 0.05 and held_left <= 0.0)

## The Leech jumps on a human survivor and holds on. Returns true while it hangs there.
func _cling(delta: float, target: Vector3, distance: float, same_floor: bool) -> bool:
	cling_cooldown -= delta
	if clung_to == null:
		var human: bool = prey is Survivor or prey is RemoteSurvivor
		if not human or cling_cooldown > 0.0 or held_left > 0.0 or distance > float(spec.reach) or not same_floor or prey.clung_by != null or not _clear_line(target):
			return false
		clung_to = prey
		prey.clung_by = self
		shaken = 0.0
		if prey == game.player:
			game.squad_call("leech", global_position, 18.0)
		cling_tick = 0.4
		# Hanging on, nothing in the world gets in its way and it does not shove its
		# victim about; it can still be shot.
		collision_mask = 0
		add_collision_exception_with(prey)
		cue("cling", [prey is RemoteSurvivor])
	if not is_instance_valid(clung_to) or not clung_to.is_targetable():
		release(false)
		return false
	var ahead := Vector3(-sin(clung_to.rotation.y), 0, -cos(clung_to.rotation.y))
	# It hangs on the chest, its face just below the survivor's line of sight.
	global_position = clung_to.global_position + ahead * 0.52 + Vector3(0, 0.62, 0)
	velocity = Vector3.ZERO
	model.rotation.y = atan2(ahead.x, ahead.z)
	head_box.global_position = model.head_position()
	shaken = maxf(0.0, shaken - delta * SHAKE_FADE)
	cling_tick -= delta
	if cling_tick <= 0.0:
		cling_tick = 0.5
		clung_to.receive_damage(float(spec.cling_damage) * 0.5 * float(game.rules.harm), global_position, "", "special")
		cue("attack", ["punch" if randf() < 0.5 else "punch_left", 0.45, 0.2])
	return true

## One press of [E] by the survivor it hangs on.
func shake() -> void:
	if clung_to == null or dead:
		return
	# An ability of the player it hangs on makes every press count for more.
	shaken += SHAKE_STEP * (1.0 + (game.skills.value("shake") if clung_to == game.player else 0.0))
	if shaken >= 1.0:
		release(true)

## Lets go. Thrown off, it lands a step away, hurt and dazed.
func release(thrown: bool) -> void:
	var victim := clung_to
	clung_to = null
	if is_instance_valid(victim):
		victim.clung_by = null
		remove_collision_exception_with(victim)
	cue("release")
	if dead:
		return
	collision_mask = 1 | 2 | 4 | 16
	cling_cooldown = 3.5
	if thrown and is_instance_valid(victim):
		var ahead := Vector3(-sin(victim.rotation.y), 0, -cos(victim.rotation.y))
		global_position = victim.global_position + ahead * 1.3
		receive_hit(15.0, ahead)
		if not dead:
			_stagger(true)
			held_left = maxf(held_left, 1.2)

## Whether a human survivor is looking this way with nothing in between.
func _observed() -> bool:
	var chest := global_position + Vector3(0, 1.2, 0)
	for watcher in [game.player, game.net.remote]:
		if not is_instance_valid(watcher):
			continue
		var eye: Vector3 = watcher.global_position + Vector3(0, 1.6, 0)
		var forward := Vector3(-sin(watcher.rotation.y), 0, -cos(watcher.rotation.y))
		if watcher == game.player:
			eye = game.player.camera.global_position
			forward = -game.player.camera.global_basis.z
		var line := chest - eye
		if line.length() > 50.0 or forward.dot(line.normalized()) < STALKER_VIEW:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, chest, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false

## Direction along the walkable way to a place.
func _steer(to: Vector3, delta: float) -> Vector3:
	repath_left -= delta
	if repath_left <= 0.0:
		path = game.cabin.path_between(global_position, to)
		path_index = 1 if path.size() > 1 else 0
		repath_left = 0.4
	while path_index < path.size():
		var point := Vector2(path[path_index].x - global_position.x, path[path_index].z - global_position.z)
		if point.length() < 0.35:
			path_index += 1
		else:
			return Vector3(point.x, 0, point.y).normalized()
	var last := Vector2(to.x - global_position.x, to.z - global_position.z)
	return Vector3(last.x, 0, last.y).normalized() if last.length() > 0.3 else Vector3.ZERO

## The Stalker does not hunt like the others. It stands and watches until somebody looks
## at it or comes near, sprints through the edge of the view, or creeps up on its prey:
## then it only moves while nobody looks, and stands like a statue when it is seen.
func _haunt(delta: float) -> void:
	if not is_instance_valid(prey) or not prey.is_targetable():
		prey = game.net.remote if is_instance_valid(game.net.remote) and game.net.remote.is_targetable() and not game.player.is_targetable() else game.player
	var target: Vector3 = prey.global_position
	var offset := Vector2(target.x - global_position.x, target.z - global_position.z)
	var distance := offset.length()
	var seen := _observed()
	var direction := Vector3.ZERO
	var pace := 0.0
	haunt_left -= delta
	if grabbing > 0.0:
		grabbing -= delta
		if grabbing <= 0.0:
			vanish()
		return
	match haunt:
		"dash":
			direction = _steer(dash_to, delta)
			pace = STALKER_DASH
			if direction == Vector3.ZERO or haunt_left <= 0.0:
				vanish()
				return
		"hunt":
			if haunt_left <= 0.0:
				vanish()
				return
			if distance < float(spec.reach) and absf(target.y - global_position.y) < 1.4:
				grab()
				return
			if not seen:
				direction = _steer(target, delta)
				pace = speed
		_:
			if seen:
				watched_for += delta
			if watched_for > 0.8 or distance < STALKER_FLEE or haunt_left <= 0.0:
				vanish()
				return
	velocity.x = direction.x * pace
	velocity.z = direction.z * pace
	if not is_on_floor():
		velocity.y -= delta * GRAVITY
	else:
		velocity.y = 0
	move_and_slide()
	var look := direction if pace > 0.1 else Vector3(offset.x, 0, offset.y).normalized()
	if look.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-look.x, -look.z), minf(delta * 10.0, 1.0))
	head_box.global_position = model.head_position()
	# Caught in the open while it hunts, it does not move a muscle.
	model.animate(0.0 if haunt == "hunt" and seen else delta, pace)

## It has its prey by the throat for a moment, then it is gone.
func grab(scare: bool = false) -> void:
	cue("grab")
	prey.receive_damage((10.0 if scare else float(spec.damage)) * float(game.rules.harm), global_position, "", Skills.kind_of(self))
	grabbing = 0.8

## Gone in a puff of smoke, without a kill for anyone.
func vanish() -> void:
	if dead:
		return
	game.mission.stalker_health = health
	_retire()
	cue("vanish")

## Turning, the head's hit zone, idle sounds and the Crusher's heavy steps.
func _ambient(delta: float, look: Vector3, turn: bool) -> void:
	if turn and look.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-look.x, -look.z), minf(delta * 8, 1))
	head_box.global_position = model.head_position()
	growl_left -= delta
	if growl_left <= 0.0:
		growl_left = randf_range(3.5, 9.0)
		if kind == "crusher":
			game.sounds.play_at("roar", mouth(), -5.0)
		elif kind == "charger" and (not alert or randf() < 0.5):
			game.sounds.play_at("gurgle", mouth())
		else:
			game.sounds.play_at(str(voices.voice if alert else voices.idle), mouth(), 0.0 if alert else -3.0)
	if kind == "crusher":
		# The giant stoops under door frames instead of getting wedged in them.
		var low := _low_ceiling(global_position) or _low_ceiling(global_position + look * 0.8)
		model.duck = move_toward(model.duck, 1.0 if low else 0.0, delta * 3.5)
		var step := int(model.phase / PI)
		if step != last_step:
			last_step = step
			game.sounds.play_at("thud", global_position)
			game.player.shake_from(global_position, 0.3, 12.0)

## Where the Crusher comes down the ground shakes: everybody near is hurt, less the further
## away, except `spared`, who took the blow itself.
func _quake(spared: Node3D) -> void:
	for body in game.survivors:
		var survivor := body as Node3D
		if not is_instance_valid(survivor) or survivor == spared or not survivor.has_method("receive_damage"):
			continue
		var off: Vector3 = survivor.global_position - global_position
		var gap := Vector2(off.x, off.z).length()
		if gap < QUAKE_REACH and absf(off.y) < 1.5:
			survivor.call("receive_damage", QUAKE_HARM * (1.0 - gap / QUAKE_REACH) * float(game.rules.harm), global_position, "", Skills.kind_of(self))
	for i in range(10):
		var around := Vector3(cos(i * TAU / 10.0), 0, sin(i * TAU / 10.0))
		game.fx.dust(global_position + around * randf_range(0.8, 2.2) + Vector3(0, 0.05, 0), Vector3.UP)

func _begin_attack(clip: String, duration: float, strike_at: float, reach: float, damage: float) -> void:
	attack_clock = 0.0
	# A leap that was broken off is over.
	if clip != "leap":
		jump = ""
	struck = false
	attack_length = duration
	strike_time = strike_at
	attack_reach = reach
	attack_damage = damage
	cue("attack", [clip, duration, strike_at])

## The Ripper's pounce: a short crouch, a flat leap at the prey, a skidding landing.
## Returns true while the leap is in charge of the body.
func _pounce(delta: float, target: Vector3, distance: float, same_floor: bool) -> bool:
	var toward := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	match leap:
		"":
			if not alert or held_left > 0.0 or attack_clock >= 0.0 or special_cooldown > 0.0 or not same_floor:
				return false
			if distance < POUNCE_RANGE.x or distance > POUNCE_RANGE.y or not is_on_floor() or not _clear_line(target, true):
				return false
			leap = "crouch"
			leap_left = 0.26
			cue("pounce")
		"crouch":
			leap_left -= delta
			velocity = Vector3.ZERO if is_on_floor() else Vector3(0, velocity.y - delta * GRAVITY, 0)
			move_and_slide()
			if leap_left <= 0.0:
				var reach := clampf(toward.length() + 0.3, 2.0, POUNCE_RANGE.y + 1.0)
				velocity = toward.normalized() * (reach / POUNCE_FLIGHT)
				velocity.y = GRAVITY * POUNCE_FLIGHT * 0.5
				leap = "air"
				leap_left = 0.0
				leap_hit = false
		"air":
			leap_left += delta
			velocity.y -= delta * GRAVITY
			move_and_slide()
			var chest: Vector3 = prey.global_position + Vector3(0, 0.9, 0)
			if not leap_hit and chest.distance_to(global_position + Vector3(0, 0.5, 0)) < 1.25:
				leap_hit = true
				prey.receive_damage(float(spec.pounce_damage) * float(game.rules.harm), global_position, "", Skills.kind_of(self))
				cue("bite")
				velocity.x *= 0.15
				velocity.z *= 0.15
			if leap_left > 0.12 and is_on_floor():
				leap = "land"
				leap_left = 0.22 if leap_hit else 0.38
		"land":
			leap_left -= delta
			velocity.x = move_toward(velocity.x, 0.0, delta * 40.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 40.0)
			velocity.y = 0.0 if is_on_floor() else velocity.y - delta * GRAVITY
			move_and_slide()
			if leap_left <= 0.0:
				leap = ""
				special_cooldown = randf_range(3.0, 5.0)
				cooldown = 0.15
				repath_left = 0.0
	return true

## The shambling ends: the infected has seen a survivor or been shot.
func _notice(distance: float) -> void:
	growl_left = randf_range(1.5, 5.0)
	# Some announce it with a scream before they charge.
	var show := ""
	if distance > 8.0 and randf() < 0.3:
		show = "writhe" if randf() < 0.3 else "scream"
	cue("notice", [show])
	if show != "":
		held_left = model.busy_left

## `source` is the teammate who fired; leave it empty for the player.
## Enemies can be the quarry of other enemies: these two make one look like a survivor to
## whoever hunts it.
func is_targetable() -> bool:
	return not dead

func receive_damage(amount: float, from: Vector3, _cause: String = "", _by: String = "") -> void:
	if dead:
		return
	var way := Vector3(global_position.x - from.x, 0, global_position.z - from.z).normalized()
	uncredited = true
	receive_hit(amount, way, false, self)
	if not dead:
		uncredited = false

func receive_hit(amount: float, direction: Vector3, headshot: bool = false, source: Node = null) -> void:
	if dead:
		return
	if kind == "stalker":
		# Shot while it watches or sprints, it is simply gone. While it hunts it can be
		# driven off, and worn down over the night.
		if haunt != "hunt":
			vanish()
			return
		driven += amount
		if driven >= STALKER_DRIVE_OFF and health - amount > 0.0:
			health -= amount
			vanish()
			return
	# Strengthened by a Medic's gas, it takes less.
	if warded > 0.0:
		amount *= CLOUD_WARD
	health -= amount
	# Which way the shot twists the body depends on the side it came from.
	var side := 1.0 if facing().cross(direction).y > 0.0 else -1.0
	cue("hit", [side, amount / max_health * 2.5])
	burst += amount
	burst_left = 0.7
	if kind == "striker" and not shed and health > 0.0 and health <= max_health * 0.5:
		shed = true
		cue("shed", [1, burn_tame])
	if health <= 0.0:
		_die(direction, headshot, source, amount >= max_health * OVERKILL_SHARE)
		return
	if not alert:
		_notice(0.0)
	if kind == "crusher":
		if not enraged and health <= max_health * 0.5:
			cue("enrage")
			held_left = model.busy_left
			attack_clock = -1.0
		elif pain_left <= 0.0 and burst > max_health * 0.03:
			pain_left = 1.6
			cue("pain")
	elif pain_left <= 0.0 and str(voices.pain) != "" and randf() < 0.5:
		pain_left = 0.5
		cue("pain")
	var reaction: String = spec.stagger
	if reaction != "" and stagger_cooldown <= 0.0 and fuse_left < 0.0 and leap == "":
		var heavy := burst >= max_health * STAGGER_SHARE
		if heavy or (headshot and amount >= max_health * 0.2):
			_stagger(heavy and reaction == "stumble")

func _stagger(heavy: bool) -> void:
	cue("stagger", ["stumble" if heavy else model.pick_flinch()])
	held_left = model.busy_left
	stagger_cooldown = held_left + 2.2
	burst = 0.0
	# Being knocked off balance breaks off an attack that has not landed yet.
	attack_clock = -1.0
	cooldown = maxf(cooldown, held_left + 0.25)

## A blast of shot from close by: whoever is still standing is thrown back at `speed`. A
## shield takes it, the heavy ones give way half as far, and nothing moves the Crusher.
## What a body does when it is knocked off balance decides how far it goes.
func blown(direction: Vector3, speed: float) -> void:
	if dead or kind in ["crusher", "stalker"] or leap != "" or blocks(direction):
		return
	if clung_to != null:
		release(true)
	var back := Vector3(direction.x, 0, direction.z).normalized()
	var reaction := str(spec.stagger)
	# A stumble carries the body back by itself.
	knock = back * speed * (0.5 if reaction == "" else (0.6 if reaction == "stumble" else 0.75))

## A blow with a rifle butt: it hurts a little, throws the body back a step and leaves it
## reeling for `seconds`. A shield takes the blow; the heavy ones are only held up for a
## moment, and nothing moves the Crusher.
func shove(direction: Vector3, speed: float, seconds: float, damage: float, source: Node = null) -> void:
	if dead:
		return
	var shielded := blocks(direction)
	receive_hit(damage, direction, false, source)
	if dead or shielded or kind == "stalker" or leap != "":
		return
	var back := Vector3(direction.x, 0, direction.z).normalized()
	var reaction := str(spec.stagger)
	if reaction == "":
		held_left = maxf(held_left, seconds * 0.3)
		if kind != "crusher":
			knock = back * speed * 0.5
		return
	if clung_to != null:
		release(true)
	# A stumble carries the body back by itself.
	knock = back * speed * (0.6 if reaction == "stumble" else 1.0)
	_stagger(reaction == "stumble")
	held_left = maxf(held_left, seconds)
	cooldown = maxf(cooldown, held_left + 0.3)

## Set alight: it burns for `seconds`, which hurts it every half second; whoever lit it
## gets the credit (`source`: a teammate or the co-op partner, empty for the player).
func ignite(seconds: float, source: Node = null, tame: bool = false) -> void:
	if dead:
		return
	if burn_left <= 0.0:
		burn_tick = BURN_TICK
		cue("burn", [true])
	burn_left = maxf(burn_left, seconds)
	burn_source = source
	burn_tame = burn_tame or tame

func _burn(delta: float) -> void:
	if burn_left <= 0.0:
		return
	burn_left -= delta
	burn_tick -= delta
	if burn_tick <= 0.0:
		burn_tick += BURN_TICK
		# Fire goes round a shield.
		game.blasting = true
		receive_hit(BURN_DPS * BURN_TICK, Vector3(0, 0.2, 0) - facing(), false, burn_source if is_instance_valid(burn_source) else null)
		game.blasting = false
	if burn_left <= 0.0 and not dead:
		cue("burn", [false])
		burn_tame = false

## Flames on the body while it burns.
func _show_flames(on: bool) -> void:
	if flames == null:
		if not on:
			return
		flames = game.fx.body_flames(float(spec.height), float(spec.radius))
		add_child(flames)
		flame_lamp = OmniLight3D.new()
		flame_lamp.light_color = Color(1.0, 0.55, 0.2)
		flame_lamp.light_energy = 1.3
		flame_lamp.omni_range = 4.5
		flame_lamp.position.y = float(spec.height) * 0.6
		add_child(flame_lamp)
	flames.emitting = on
	flame_lamp.visible = on
	ember_left = 2.5

## A body that fell burning burns on for a moment, down where it lies.
func _smoulder(delta: float) -> void:
	if flames == null or not flames.emitting:
		return
	flames.position.y = move_toward(flames.position.y, 0.3, delta * 1.6)
	flame_lamp.position.y = flames.position.y + 0.2
	ember_left -= delta
	if ember_left <= 0.0:
		_show_flames(false)

## The voice a soldier shouts with (see Radio.BARKS); nothing the infected have.
func voice() -> String:
	return "cru"

## Blinded by a flashbang: reels on the spot for a few seconds.
func stun(seconds: float) -> void:
	if dead or seconds <= 0.0:
		return
	var reels: bool = str(spec.stagger) != ""
	if reels:
		_stagger(true)
	else:
		attack_clock = -1.0
	# The Crusher only shakes it off faster.
	held_left = maxf(held_left, seconds if reels else seconds * 0.35)
	cooldown = maxf(cooldown, held_left + 0.3)

func _retire() -> void:
	dead = true
	if clung_to != null:
		release(false)
	collision_layer = 0
	collision_mask = 0
	head_box.collision_layer = 0
	if is_in_group("infected"):
		remove_from_group("infected")

func _die(direction: Vector3, headshot: bool, source: Node = null, overkill: bool = false) -> void:
	_retire()
	game.enemy_defeated(self, not uncredited, headshot, source)
	match kind:
		"charger":
			# Shooting a Charger sets it off; the short delay lets chain reactions ripple.
			cue("swell")
			create_tween().tween_callback(_explode).set_delay(0.12)
		"crusher":
			cue("dissolve")
		_:
			var across := direction.dot(Vector3(-facing().z, 0, facing().x))
			cue("die", [model.pick_death(_shot_from_behind(direction), headshot, across, overkill), headshot, direction, overkill])
			if kind == "striker":
				cue("shed", [3, burn_tame])

## The Charger reached its victim and blows itself up; nobody is credited.
func detonate() -> void:
	_retire()
	game.enemy_defeated(self, false, false)
	_explode()

func _explode() -> void:
	var centre := global_position + Vector3(0, 0.9, 0)
	cue("burst")
	# One that burnt out (the sweeper's ability) still tears the infected around it apart,
	# but does the survivors nothing.
	game.explode(centre, CHARGER_BLAST, 0.0 if burn_tame else float(spec.damage), 110.0, "boomer" if bursts_wet() else "charger", self)
	queue_free()

## True for the second exploding infected: a Charger in another body. It is the same enemy
## in every number and in all it does; only its burst looks and sounds different - low,
## wide and the colour of blood orange, with a puddle left behind. (The look is what the
## host of a co-op match tells the guest about every spawn, so both see the same one.)
func bursts_wet() -> bool:
	return kind == "charger" and model != null and model.kind == "boomer2"

func _shot_from_behind(direction: Vector3) -> bool:
	return facing().dot(direction) > 0.2

## Called on host and puppet alike once the body is down for good.
func _remove_after(seconds: float) -> void:
	_retire()
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds - 1.2))
	# (From wherever it lies by then: a body shot on its way out of a ceiling falls first.)
	tween.tween_property(self, "position:y", -0.6, 1.2).as_relative()
	tween.tween_callback(queue_free)

# ---------------------------------------------------------------- co-op puppet

## Follows the host's infected: glides to its last reported place and turns like it.
func _follow(delta: float) -> void:
	var before := global_position
	global_position = global_position.lerp(net_position, minf(1.0, delta * 12.0))
	var moved := (global_position - before) / maxf(delta, 0.001)
	model.rotation.y = lerp_angle(model.rotation.y, net_yaw, minf(1.0, delta * 10.0))
	model.animate(delta, Vector2(moved.x, moved.z).length())
	if fuse_left >= 0.0:
		fuse_left += delta
		model.swell = minf(1.0, fuse_left / float(spec.attack_time))
	_ambient(delta, Vector3.ZERO, false)
