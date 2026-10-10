class_name InfectedVisual
extends Node3D
## Presentation shared by every infected: model, glowing eyes and animation.
## The animation clips come from Mixamo and were made for the hazmat Mauler. Each clip is
## sampled once and retargeted to every other skeleton by limb role (hips, spine, arms,
## legs), so all infected share the same set. A thin procedural layer on top adds bullet
## flinches, the Crusher's stoop and the Charger's swelling.
## All models face +Z in their own space; the holder turns them to face -Z like the game.

const FRAME := 1.0 / 30.0
const RIG_SCENE := "res://assets/models/mixamo/mauler_hazmat_rig.fbx"
const CLIP_FOLDER := "res://assets/models/mixamo/"
## Mixamo clips. speed: ground speed of the source character in m/s. strike: the moment a
## blow lands. start/end: the part of the file that is used. travel: movement along the
## facing is taken out of the clip and handed to the body as real motion. fall: the body
## ends on the ground. drift: scales sideways travel. lift: scales how high the hips rise
## above where they stand. rooted: the clip is played on the
## spot, whatever way its source travels (the body does the moving itself). mirror: a
## left/right flipped copy of another clip. set: only skeletons of that set get the clip.
const CLIPS := {
	"idle": {"file": "mauler_hazmat_rig", "loop": true},
	"shamble": {"file": "anim_walk_hunched", "loop": true, "speed": 0.38, "set": "zombie"},
	"drag": {"file": "anim_walk", "loop": true, "speed": 0.37, "set": "zombie"},
	"creep": {"file": "anim_walk_creep", "loop": true, "speed": 0.37, "set": "zombie"},
	"run": {"file": "anim_run", "loop": true, "speed": 2.7, "set": "zombie"},
	"feral": {"file": "anim_run_feral", "loop": true, "speed": 2.95, "set": "zombie"},
	"swipe": {"file": "anim_attack_swipe", "strike": 1.0, "end": 2.1, "set": "zombie"},
	"punch": {"file": "anim_attack_punch", "strike": 0.63, "set": "zombie"},
	"slam": {"file": "anim_attack_overhead", "strike": 1.47, "end": 2.7},
	"kick": {"file": "anim_attack_kick", "strike": 0.87, "end": 2.0, "set": "zombie"},
	"headbutt": {"file": "anim_attack_headbutt", "strike": 0.42, "end": 1.5, "set": "zombie"},
	"swipe_left": {"mirror": "swipe", "set": "zombie"},
	"punch_left": {"mirror": "punch", "set": "zombie"},
	"flinch": {"file": "anim_hit_flinch", "end": 1.3, "set": "zombie"},
	"recoil": {"file": "anim_hit_react_a", "end": 1.4, "set": "zombie"},
	"flinch_left": {"mirror": "flinch", "set": "zombie"},
	"stumble": {"file": "anim_hit_stumble", "travel": true, "set": "zombie"},
	"scream": {"file": "anim_scream", "set": "zombie"},
	"writhe": {"file": "anim_agony", "start": 1.0, "end": 3.4, "set": "zombie"},
	"death_back": {"file": "anim_death_back", "fall": true, "set": "zombie"},
	"death_forward": {"file": "anim_death_forward", "fall": true, "set": "zombie"},
	"death_side": {"file": "anim_death_stumble", "fall": true, "drift": 0.4, "set": "zombie"},
	"death_headshot": {"file": "anim_death_headshot", "fall": true, "set": "zombie"},
	"death_from_back": {"file": "anim_death_from_back", "fall": true, "set": "zombie"},
	"death_from_front": {"file": "anim_death_from_front", "fall": true, "set": "zombie"},
	"death_from_right": {"file": "anim_death_from_right", "fall": true, "set": "zombie"},
	"death_from_left": {"mirror": "death_from_right", "set": "zombie"},
	"death_drop_back": {"file": "anim_death_standing_back", "fall": true, "set": "zombie"},
	"death_drop_left": {"file": "anim_death_standing_left", "fall": true, "set": "zombie"},
	"death_drop_right": {"mirror": "death_drop_left", "set": "zombie"},
	"death_side_left": {"mirror": "death_side", "set": "zombie"},
	"mutant_walk": {"file": "anim_mutant_walk", "loop": true, "speed": 1.05, "set": "mutant"},
	"mutant_run": {"file": "anim_mutant_run", "loop": true, "speed": 2.1, "set": "mutant"},
	"mutant_swipe": {"file": "anim_mutant_swipe", "strike": 1.1, "end": 2.2, "set": "mutant"},
	"mutant_punch": {"file": "anim_mutant_punch", "strike": 0.3, "set": "mutant"},
	# The Crusher's leap. The clip jumps a metre and a half straight up; the body itself flies
	# far and low (Infected.LEAP_FLIGHT), so most of that height is taken out.
	"leap": {"file": "anim_mutant_jump", "strike": 1.63, "end": 2.8, "travel": true, "lift": 0.55, "set": "mutant"},
	"roar": {"file": "anim_mutant_roar", "start": 0.4, "end": 3.3, "set": "mutant"},
	"mutant_death": {"file": "anim_mutant_death", "fall": true, "set": "mutant"}
}
## Falls that were made on another rig, the soldier Scorpion's: a clip is read on the rig it
## was made for and then carried over like every other.
const MORE_RIG := "res://assets/models/mixamo/skorpion_rig.fbx"
const MORE := {
	"death_dying_back": {"file": "anim_death_dying_back", "fall": true, "set": "zombie"},
	"death_fall_back": {"file": "anim_death_fall_back", "fall": true, "set": "zombie"},
	"death_fall_forward": {"file": "anim_death_fall_forward", "fall": true, "set": "zombie"},
	"death_fly_back": {"file": "anim_death_fly_back", "fall": true, "set": "zombie"},
	"death_bow_forward": {"file": "anim_death_bow_forward", "fall": true, "set": "zombie"},
	"death_back_headshot": {"file": "anim_death_back_headshot", "fall": true, "set": "zombie"}
}
## Which death fits which shot. Sides are the infected's own left and right.
const DEATHS := {
	"front": ["death_back", "death_drop_back", "death_from_front", "death_side", "death_side_left", "death_dying_back", "death_fall_back"],
	"head": ["death_headshot", "death_headshot", "death_back", "death_drop_back", "death_fall_back"],
	"behind": ["death_forward", "death_from_back", "death_from_front", "death_fall_forward", "death_bow_forward"],
	"behind_head": ["death_back_headshot", "death_back_headshot", "death_fall_forward", "death_forward"],
	"from_right": ["death_from_right", "death_drop_left"],
	"from_left": ["death_from_left", "death_drop_right"],
	# A hit from the front that was far harder than it took: thrown back.
	"hard": ["death_fly_back", "death_fly_back", "death_fall_back"]
}

## set: which clips the skeleton gets. moves: the clips a kind uses; where several are
## listed every individual picks one. pace: slowest and fastest playback of its gait.
const KINDS := {
	"mauler_hazmat": {
		"scene": preload("res://assets/models/mixamo/mauler_hazmat_rig.fbx"), "source_height": 1.7, "height": 1.78, "set": "zombie",
		"textures": "res://assets/models/meshy_zombie",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.592, "eye_gap": 0.0314, "eye_center": -0.0093, "eye_size": 0.011,
		"metallic": 0.25,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]}
	},
	"mauler_female": {
		"scene": preload("res://assets/models/mauler_female.glb"), "source_height": 1.7, "height": 1.7, "set": "zombie",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.578, "eye_gap": 0.031, "eye_center": 0.0, "eye_size": 0.006,
		"metallic": 0.15,
		"moves": {"run": ["feral", "feral", "run"], "walk": ["shamble", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "headbutt"], "pace": [0.6, 1.5]}
	},
	"striker": {
		"scene": preload("res://assets/models/striker.glb"), "source_height": 1.7, "height": 1.74, "set": "zombie",
		"eye_color": Color(1.0, 0.72, 0.15), "eye_height": 1.56, "eye_gap": 0.0316, "eye_center": -0.0047, "eye_size": 0.01,
		"metallic": 0.15,
		"moves": {"run": ["feral"], "walk": ["creep"], "attacks": ["punch", "swipe", "punch_left", "swipe_left", "kick"], "pace": [0.7, 1.75]}
	},
	# The models below bring their textures as separate files ("maps" is the prefix) and
	# are already at their in-game height. "deaths" lists the falls a build may use: some
	# bodies end up in the floor in some of them.
	"normalzombie": {
		"scene": preload("res://assets/models/normalzombie.glb"), "source_height": 1.78, "height": 1.78, "set": "zombie",
		"maps": "res://assets/models/normalzombie_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.655, "eye_gap": 0.03, "eye_center": 0.042, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]}
	},
	"normalzombie2": {
		"scene": preload("res://assets/models/normalzombie2.glb"), "source_height": 1.78, "height": 1.78, "set": "zombie",
		"maps": "res://assets/models/normalzombie2_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.662, "eye_gap": 0.029, "eye_center": -0.012, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "feral"], "walk": ["drag", "shamble"], "attacks": ["punch", "swipe", "punch_left", "swipe_left", "kick"], "pace": [0.6, 1.5]}
	},
	# The Medic: a soldier-medic gone over, with the tanks of whatever it breathes out on its back.
	"mediczombie": {
		"scene": preload("res://assets/models/mediczombie.glb"), "source_height": 1.8, "height": 1.8, "set": "zombie",
		"maps": "res://assets/models/mediczombie_",
		"eye_color": Color(0.85, 1.0, 0.35), "eye_height": 1.674, "eye_gap": 0.031, "eye_center": -0.011, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]},
		"deaths": ["death_drop_back", "death_forward", "death_from_front", "death_from_left", "death_from_right", "death_bow_forward", "death_back_headshot"]
	},
	"zombiehelm": {
		"scene": preload("res://assets/models/zombiehelm.glb"), "source_height": 1.78, "height": 1.78, "set": "zombie",
		"maps": "res://assets/models/zombiehelm_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.607, "eye_gap": 0.034, "eye_center": -0.005, "eye_size": 0.008,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "headbutt"], "pace": [0.6, 1.5]}
	},
	# [hive] The Hive's staff, turned: ordinary infected in the clothes of the people who worked there, rigged like the
	# [hive] normalzombie (same bones, same clips). boomer2 is the second model of the exploding infected.
	# "mission": 2 - only the second mission brings them (HiveDirector.STAFF), so they are prepared when a night
	# there begins and not at the start of the game (see warm_up). The maps of all eight are imported smaller than
	# they were drawn (process/size_limit in their .import files: normal map 1024, roughness and metallic 512 -
	# 4.3 MB on the graphics card instead of 13.3 each; a close-up shows no difference).
	"hive_nurse": {
		"scene": preload("res://assets/models/hive_nurse.glb"), "mission": 2, "source_height": 1.8, "height": 1.8, "set": "zombie",
		"maps": "res://assets/models/hive_nurse_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.667, "eye_gap": 0.0345, "eye_center": 0.0025, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]},
		"deaths": ["death_back", "death_from_front", "death_side", "death_side_left", "death_dying_back", "death_fall_back", "death_headshot", "death_forward", "death_from_back", "death_fall_forward", "death_bow_forward", "death_from_right", "death_drop_left", "death_from_left", "death_drop_right", "death_fly_back"]
	},
	"hive_worker": {
		"scene": preload("res://assets/models/hive_worker.glb"), "mission": 2, "source_height": 1.72, "height": 1.72, "set": "zombie",
		"maps": "res://assets/models/hive_worker_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.581, "eye_gap": 0.0338, "eye_center": -0.0023, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]}
	},
	"hive_lab": {
		"scene": preload("res://assets/models/hive_lab.glb"), "mission": 2, "source_height": 1.74, "height": 1.74, "set": "zombie",
		"maps": "res://assets/models/hive_lab_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.595, "eye_gap": 0.033, "eye_center": -0.003, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]}
	},
	"hive_security": {
		"scene": preload("res://assets/models/hive_security.glb"), "mission": 2, "source_height": 1.8, "height": 1.8, "set": "zombie",
		"maps": "res://assets/models/hive_security_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.657, "eye_gap": 0.0325, "eye_center": 0.009, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]}
	},
	"hive_scientist": {
		"scene": preload("res://assets/models/hive_scientist.glb"), "mission": 2, "source_height": 1.8, "height": 1.8, "set": "zombie",
		"maps": "res://assets/models/hive_scientist_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.617, "eye_gap": 0.0385, "eye_center": 0.0, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]}
	},
	"hive_scientist2": {
		"scene": preload("res://assets/models/hive_scientist2.glb"), "mission": 2, "source_height": 1.78, "height": 1.78, "set": "zombie",
		"maps": "res://assets/models/hive_scientist2_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.638, "eye_gap": 0.0337, "eye_center": -0.0043, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]},
		"deaths": ["death_back", "death_drop_back", "death_from_front", "death_side", "death_side_left", "death_dying_back", "death_fall_back", "death_headshot", "death_forward", "death_from_back", "death_fall_forward", "death_bow_forward", "death_back_headshot", "death_drop_left", "death_drop_right", "death_fly_back"]
	},
	"hive_civilian": {
		"scene": preload("res://assets/models/hive_civilian.glb"), "mission": 2, "source_height": 1.78, "height": 1.78, "set": "zombie",
		"maps": "res://assets/models/hive_civilian_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.655, "eye_gap": 0.036, "eye_center": -0.001, "eye_size": 0.009,
		"metallic": 1.0,
		"moves": {"run": ["run", "run", "feral"], "walk": ["shamble", "drag", "creep"], "attacks": ["swipe", "punch", "swipe_left", "punch_left", "kick", "headbutt"], "pace": [0.6, 1.5]}
	},
	"boomer2": {
		"scene": preload("res://assets/models/boomer2.glb"), "source_height": 1.85, "height": 1.85, "set": "zombie",
		"maps": "res://assets/models/boomer2_",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.688, "eye_gap": 0.0445, "eye_center": -0.0015, "eye_size": 0.012,
		"metallic": 1.0,
		"moves": {"run": ["run"], "walk": ["shamble"], "attacks": ["punch"], "pace": [0.6, 1.5]},
		# It never lies down: it bursts, like the charger. No fall is allowed (the check of every fall in _arsenal skips such a kind).
		"deaths": []
	},
	"stalker": {
		"scene": preload("res://assets/models/stalker.glb"), "source_height": 2.0, "height": 2.0, "set": "zombie",
		"maps": "res://assets/models/stalker_",
		"eye_color": Color(0.85, 0.95, 1.0), "eye_height": 1.892, "eye_gap": 0.038, "eye_center": -0.002, "eye_size": 0.011,
		"metallic": 1.0,
		"deaths": ["death_back", "death_headshot", "death_forward", "death_from_back", "death_from_left", "death_from_right", "death_drop_left", "death_drop_right", "death_dying_back", "death_fall_back", "death_bow_forward", "death_back_headshot"],
		"moves": {"run": ["feral"], "walk": ["creep"], "attacks": ["swipe", "swipe_left", "punch", "punch_left"], "pace": [0.6, 1.6]}
	},
	"leech": {
		"scene": preload("res://assets/models/smallzombie.glb"), "source_height": 1.15, "height": 1.15, "set": "zombie",
		"maps": "res://assets/models/smallzombie_",
		"eye_color": Color(0.75, 1.0, 0.3), "eye_height": 0.956, "eye_gap": 0.053, "eye_center": 0.003, "eye_size": 0.008,
		"metallic": 1.0,
		"deaths": ["death_back", "death_headshot", "death_from_back", "death_from_left", "death_from_right", "death_drop_left", "death_drop_right", "death_side", "death_side_left", "death_dying_back", "death_fall_back", "death_fly_back"],
		"moves": {"run": ["feral"], "walk": ["creep"], "attacks": ["headbutt", "punch", "swipe"], "pace": [0.7, 2.2]}
	},
	"crusher": {
		"scene": preload("res://assets/models/crusher.glb"), "source_height": 1.7, "height": 2.65, "set": "mutant",
		"eye_color": Color(0.2, 0.55, 1.0), "eye_height": 1.579, "eye_gap": 0.025, "eye_center": 0.0, "eye_size": 0.0065,
		"metallic": 0.18,
		"moves": {"run": ["mutant_run"], "walk": ["mutant_walk"], "attacks": ["slam", "mutant_swipe", "mutant_punch"], "pace": [0.5, 1.5]}
	},
	"charger": {
		"scene": preload("res://assets/models/charger.glb"), "source_height": 1.835, "height": 1.82, "set": "zombie",
		"eye_color": Color(1.0, 0.13, 0.05), "eye_height": 1.669, "eye_gap": 0.045, "eye_center": -0.0055, "eye_size": 0.008,
		"metallic": 0.0,
		"moves": {"run": ["run"], "walk": ["shamble"], "attacks": ["punch"], "pace": [0.6, 1.5]}
	}
}

## Bones generated for the unrigged Charger mesh: name, parent index, model position.
const CHARGER_BONES := [
	["hips", -1, Vector3(0, 0.67, 0)], ["spine", 0, Vector3(0, 0.92, 0)], ["chest", 1, Vector3(0, 1.27, 0)],
	["neck", 2, Vector3(0, 1.5, 0)], ["head", 3, Vector3(0, 1.58, 0)],
	["clav_a", 2, Vector3(-0.2, 1.42, 0)], ["arm_a", 5, Vector3(-0.33, 1.42, 0)], ["fore_a", 6, Vector3(-0.62, 1.42, 0)], ["hand_a", 7, Vector3(-0.88, 1.42, 0)],
	["clav_b", 2, Vector3(0.2, 1.42, 0)], ["arm_b", 9, Vector3(0.33, 1.42, 0)], ["fore_b", 10, Vector3(0.62, 1.42, 0)], ["hand_b", 11, Vector3(0.88, 1.42, 0)],
	["thigh_a", 0, Vector3(-0.17, 0.59, 0)], ["shin_a", 13, Vector3(-0.19, 0.3, 0)], ["foot_a", 14, Vector3(-0.2, 0.08, 0)],
	["thigh_b", 0, Vector3(0.17, 0.59, 0)], ["shin_b", 16, Vector3(0.19, 0.3, 0)], ["foot_b", 17, Vector3(0.2, 0.08, 0)]
]
const CHARGER_LIFT := 0.9192
const LIMBS := ["clav", "upper", "fore", "hand", "thigh", "shin", "foot", "toe"]

static var source: Dictionary = {}
## The clips of MORE, sampled on their own rig.
static var more: Dictionary = {}
static var rigs: Dictionary = {}
static var libraries: Dictionary = {}
static var materials: Dictionary = {}
static var eye_materials: Dictionary = {}
static var eye_offsets: Dictionary = {}
## What shows that a Medic's gas has strengthened a body: eyes of another colour, a green
## sheen that crawls over the skin, and a glow on the arms.
const BUFF_COLOR := Color(0.38, 1.0, 0.18)
const SHEEN_CODE := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.38, 1.0, 0.18);
void fragment() {
	// Bright where the skin turns away from the eye, and in bands that crawl upwards.
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bands = 0.55 + 0.45 * sin(world.y * 16.0 - TIME * 5.0);
	float pulse = 0.8 + 0.2 * sin(TIME * 6.5);
	ALBEDO = tint * (rim * 0.85 + 0.015) * bands * pulse;
}
"""
static var sheen: ShaderMaterial
static var buff_eye: StandardMaterial3D
static var buff_glow: StandardMaterial3D
static var charger_mesh: ArrayMesh
## The Crusher's shell: plates the colour of amber lie over its blue skin and glow at
## their seams and edges, the eyes burn in the same colour, and it lights the ground
## around it - so that it reads at night as well as in the light of the facility.
## SHELL_PLATES: how many plates lie across the skin's texture.
const SHELL_COLOR := Color(1.0, 0.52, 0.08)
const SHELL_PLATES := 60.0
const SHELL_CODE := """shader_type spatial;
render_mode blend_mix, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.52, 0.08);
uniform float plates = 60.0;
uniform float amount = 0.0;
uniform float flare = 0.0;
float plate(vec2 p) {
	// How far from the middle of its six-sided plate a point lies: 0.5 at the seam.
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 c = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - c.xy * s, p - (c.zw + 0.5) * s);
	vec2 q = abs(dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw);
	return max(dot(q, s * 0.5), q.x);
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	float seam = smoothstep(0.38, 0.49, plate(UV * plates));
	ALBEDO = tint * 0.3;
	METALLIC = 0.5;
	ROUGHNESS = 0.4;
	EMISSION = tint * (0.2 + seam * 1.3 + rim * 1.0 + flare * 2.6) * amount;
	ALPHA = clamp(amount * (0.88 + seam * 0.12), 0.0, 1.0);
}
"""
static var shell_code: Shader
## The Crusher's guard (see _raise_guard), in the measures of its skeleton: which arm (0 its
## right, 1 its left), how far before the eyes the forearm lies, where along the forearm
## (0 elbow, 1 wrist) the eyes are behind it, how the forearm lies (across to the other
## side, upwards), where the elbow is kept (out to its own side, down, forward), and how far
## the head is drawn in behind it (radians).
const GUARD_ARM := 1
const GUARD_FRONT := 0.12
const GUARD_ALONG := 0.55
const GUARD_LIE := Vector2(1.0, 0.15)
const GUARD_ELBOW := Vector3(1.0, -0.4, 0.3)
const GUARD_TUCK := 0.16
static var shell_eye: StandardMaterial3D

var kind := "mauler_hazmat"
var config: Dictionary
var moves: Dictionary
var rig: Dictionary
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var player: AnimationPlayer
var holder: Node3D
var eyes: Node3D
var model_scale := 1.0
## How this skeleton's stride compares to the Mixamo source character.
var stride_scale := 1.0
var state := "move"
var gait := ""
var busy_left := 0.0
var phase := 0.0
var clock := 0.0
var move := 0.0
## Metres the current clip wants the body to move along its facing this frame.
var travel := 0.0
var travel_clip := ""
var travel_last := 0.0
var flinch := 0.0
var flinch_side := 1.0
var dying := false
var death_time := 0.0
var dissolving := false
var swell := 0.0
var duck := 0.0
var buffed := false
var buff_marks: Array[Node3D] = []
## The Crusher's shell as it is shown: its state ("", "tell" or "on"), how much of it lies
## over the skin (0 to 1), the seconds it has been in that state, and the flare that
## answers a hit on it.
var shell_state := ""
var shell := 0.0
var shell_for := 0.0
var shell_flare := 0.0
var shell_skin: ShaderMaterial
var shell_lamp: OmniLight3D
## The Crusher's guard: whether its forearm is wanted before its face, and how far up it
## is (0 to 1). It comes down by itself for whatever is no walking: a blow, a leap, a roar.
var guard_on := false
var guard := 0.0

func _ready() -> void:
	config = KINDS[kind]
	# Every individual settles on one walk and one run, so a horde does not move in step.
	moves = (config.moves as Dictionary).duplicate()
	moves["run"] = (moves.run as Array).pick_random()
	moves["walk"] = (moves.walk as Array).pick_random()
	model_scale = float(config.height) / float(config.source_height)
	holder = Node3D.new()
	holder.name = "Model"
	# The source models face +Z; characters in this game face -Z.
	holder.rotation.y = PI
	holder.scale = Vector3.ONE * model_scale
	add_child(holder)
	if kind == "charger":
		_build_charger()
	else:
		var imported := (config.scene as PackedScene).instantiate() as Node3D
		holder.add_child(imported)
		skeleton = _find(imported, "Skeleton3D") as Skeleton3D
		mesh_instance = _find(imported, "MeshInstance3D") as MeshInstance3D
		var bundled := _find(imported, "AnimationPlayer")
		if bundled != null:
			bundled.free()
	if not rigs.has(kind):
		rigs[kind] = _analyse(skeleton)
	rig = rigs[kind]
	if not libraries.has(kind):
		libraries[kind] = _bake(skeleton, rig, str(config.set))
		_add_more(libraries[kind], skeleton, rig, str(config.set))
	stride_scale = float(rig.leg_length) / float(source.leg_length)
	if not materials.has(kind):
		materials[kind] = _material()
	mesh_instance.material_override = materials[kind]
	player = AnimationPlayer.new()
	player.name = "Clips"
	skeleton.get_parent().add_child(player)
	player.add_animation_library("", libraries[kind])
	# Advanced by hand so the procedural layer can be applied right after each step.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_build_eyes()
	phase = randf() * TAU
	player.play("idle")
	player.seek(randf() * player.current_animation_length, true)

static func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for child in node.get_children():
		var found := _find(child, type)
		if found != null:
			return found
	return null

func _material() -> BaseMaterial3D:
	if config.has("maps"):
		# Separate texture files: <prefix>diffuse.jpg, normal.png, roughness.png, metallic.png.
		var prefix: String = config.maps
		var mapped := StandardMaterial3D.new()
		mapped.albedo_texture = load(prefix + "diffuse.jpg")
		mapped.normal_enabled = true
		mapped.normal_texture = load(prefix + "normal.png")
		mapped.roughness_texture = load(prefix + "roughness.png")
		mapped.metallic = float(config.metallic)
		mapped.metallic_texture = load(prefix + "metallic.png")
		return mapped
	if config.has("textures"):
		# The Mixamo export carries no textures; the mesh keeps the UVs of the original model.
		var base: String = config.textures
		var built := StandardMaterial3D.new()
		built.albedo_texture = load(base + "_texture_0.png")
		built.normal_enabled = true
		built.normal_texture = load(base + "_normal.png")
		built.roughness_texture = load(base + "_texture_0_metallic_roughness.png")
		built.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		built.metallic_texture = built.roughness_texture
		built.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		built.metallic = float(config.metallic)
		built.roughness = 1.0
		return built
	var tuned := mesh_instance.mesh.surface_get_material(0).duplicate() as BaseMaterial3D
	tuned.metallic = float(config.metallic)
	tuned.roughness = 1.0
	return tuned

# ---------------------------------------------------------------- rig discovery

static func _entry(skel: Skeleton3D, index: int) -> Dictionary:
	var global := skel.get_bone_global_rest(index).basis.orthonormalized().get_rotation_quaternion()
	return {"index": index, "global": global, "origin": skel.get_bone_global_rest(index).origin}

## Identifies hips, spine, head, arms and legs purely from the bone tree and rest positions,
## so the Mixamo rig and every UniRig export work regardless of how their bones are named.
static func _analyse(skel: Skeleton3D) -> Dictionary:
	var count := skel.get_bone_count()
	var kids: Array = []
	for i in range(count):
		kids.append([])
	var root := 0
	for i in range(count):
		var parent := skel.get_bone_parent(i)
		if parent < 0:
			root = i
		else:
			kids[parent].append(i)
	var lowest := PackedFloat32Array()
	var highest := PackedFloat32Array()
	var widest := PackedFloat32Array()
	var weight := PackedInt32Array()
	var depth := PackedInt32Array()
	for i in range(count):
		var origin := skel.get_bone_global_rest(i).origin
		lowest.append(origin.y)
		highest.append(origin.y)
		widest.append(absf(origin.x))
		weight.append(1)
		var level := 0
		var up := skel.get_bone_parent(i)
		while up >= 0:
			level += 1
			up = skel.get_bone_parent(up)
		depth.append(level)
	# Deepest bones first, so every subtree is complete before its parent reads it.
	var by_depth: Array = range(count)
	by_depth.sort_custom(func(a: int, b: int) -> bool: return depth[a] > depth[b])
	for i in by_depth:
		var parent := skel.get_bone_parent(i)
		if parent >= 0:
			lowest[parent] = minf(lowest[parent], lowest[i])
			highest[parent] = maxf(highest[parent], highest[i])
			widest[parent] = maxf(widest[parent], widest[i])
			weight[parent] += weight[i]
	var chain := func(start: int, length: int) -> Array:
		var result := [start]
		var bone := start
		while result.size() < length and not kids[bone].is_empty():
			var best: int = kids[bone][0]
			for child in kids[bone]:
				if weight[child] > weight[best]:
					best = child
			result.append(best)
			bone = best
		return result
	var pelvis := root
	while kids[pelvis].size() == 1:
		pelvis = kids[pelvis][0]
	var branches: Array = kids[pelvis].duplicate()
	branches.sort_custom(func(a: int, b: int) -> bool: return lowest[a] < lowest[b])
	var leg_roots := [branches[0], branches[1]]
	leg_roots.sort_custom(func(a: int, b: int) -> bool: return skel.get_bone_global_rest(a).origin.x < skel.get_bone_global_rest(b).origin.x)
	var spine_start: int = branches[branches.size() - 1]
	var spine := [spine_start]
	while kids[spine[spine.size() - 1]].size() == 1:
		spine.append(kids[spine[spine.size() - 1]][0])
	var chest: int = spine[spine.size() - 1]
	var upper: Array = kids[chest].duplicate()
	upper.sort_custom(func(a: int, b: int) -> bool: return widest[a] > widest[b])
	var arm_roots := [upper[0], upper[1]]
	var neck_root: int = upper[upper.size() - 1]
	var arm_side := func(bone: int) -> float:
		var links: Array = chain.call(bone, 4)
		return skel.get_bone_global_rest(links[links.size() - 1]).origin.x
	arm_roots.sort_custom(func(a: int, b: int) -> bool: return arm_side.call(a) < arm_side.call(b))
	var result := {"pelvis": _entry(skel, pelvis), "spine": [], "arms": [], "legs": []}
	for bone in spine:
		result.spine.append(_entry(skel, bone))
	var neck: Array = chain.call(neck_root, 2)
	result["neck"] = _entry(skel, neck[0])
	result["head"] = _entry(skel, neck[neck.size() - 1])
	for i in range(2):
		var links: Array = chain.call(arm_roots[i], 4)
		while links.size() < 4:
			links.append(links[links.size() - 1])
		result.arms.append({"clav": _entry(skel, links[0]), "upper": _entry(skel, links[1]), "fore": _entry(skel, links[2]), "hand": _entry(skel, links[3])})
		var leg: Array = chain.call(leg_roots[i], 4)
		var toe: int = leg[3] if leg.size() > 3 else -1
		while leg.size() < 3:
			leg.append(leg[leg.size() - 1])
		result.legs.append({"thigh": _entry(skel, leg[0]), "shin": _entry(skel, leg[1]), "foot": _entry(skel, leg[2]), "toe": toe})
	var first_leg: Dictionary = result.legs[0]
	result["leg_length"] = (first_leg.thigh.origin as Vector3).distance_to(first_leg.shin.origin) + (first_leg.shin.origin as Vector3).distance_to(first_leg.foot.origin)
	return result

## The animated bones as a flat list. key: limb role shared by all skeletons. to: the bone
## whose rest position gives this bone its direction. align: "aim" turns the bone to match
## the source's rest direction, "parent" reuses the alignment of the limb above it.
static func _links(rig: Dictionary) -> Array:
	var links: Array = [{"key": "pelvis", "index": rig.pelvis.index, "to": -1, "align": ""}]
	var spine: Array = rig.spine
	for j in range(spine.size()):
		links.append({"key": "spine", "share": float(j) / maxf(1.0, spine.size() - 1.0), "index": spine[j].index, "to": -1, "align": ""})
	links.append({"key": "neck", "index": rig.neck.index, "to": -1, "align": ""})
	links.append({"key": "head", "index": rig.head.index, "to": -1, "align": ""})
	for i in range(2):
		var arm: Dictionary = rig.arms[i]
		links.append({"key": "clav%d" % i, "index": arm.clav.index, "to": -1, "align": ""})
		links.append({"key": "upper%d" % i, "index": arm.upper.index, "to": arm.fore.index, "align": "aim"})
		links.append({"key": "fore%d" % i, "index": arm.fore.index, "to": arm.hand.index, "align": "aim"})
		links.append({"key": "hand%d" % i, "index": arm.hand.index, "to": -1, "align": "parent"})
		var leg: Dictionary = rig.legs[i]
		links.append({"key": "thigh%d" % i, "index": leg.thigh.index, "to": leg.shin.index, "align": "aim"})
		links.append({"key": "shin%d" % i, "index": leg.shin.index, "to": leg.foot.index, "align": "aim"})
		links.append({"key": "foot%d" % i, "index": leg.foot.index, "to": int(leg.toe), "align": "aim" if int(leg.toe) >= 0 else ""})
		if int(leg.toe) >= 0:
			links.append({"key": "toe%d" % i, "index": int(leg.toe), "to": -1, "align": "parent"})
	# Short limb chains repeat their last bone; keep each bone once.
	var seen := {}
	var unique: Array = []
	for link in links:
		if not seen.has(link.index):
			seen[link.index] = true
			unique.append(link)
	return unique

static func _aim(skel: Skeleton3D, link: Dictionary) -> Vector3:
	if int(link.to) < 0 or int(link.to) == int(link.index):
		return Vector3.ZERO
	var span := skel.get_bone_global_rest(int(link.to)).origin - skel.get_bone_global_rest(int(link.index)).origin
	return span.normalized() if span.length() > 0.0001 else Vector3.ZERO

## Parents-first order of every bone.
static func _order(skel: Skeleton3D) -> Array:
	var depth := {}
	for i in range(skel.get_bone_count()):
		var level := 0
		var up := skel.get_bone_parent(i)
		while up >= 0:
			level += 1
			up = skel.get_bone_parent(up)
		depth[i] = level
	var order: Array = range(skel.get_bone_count())
	order.sort_custom(func(a: int, b: int) -> bool: return depth[a] < depth[b] or (depth[a] == depth[b] and a < b))
	return order

# ---------------------------------------------------------------- clips and retargeting

static func _prepare_source() -> void:
	if source.is_empty():
		source = sample(RIG_SCENE, CLIPS)
		more = sample(MORE_RIG, MORE)

## Adds the clips of MORE to a library that was built for this skeleton.
static func _add_more(library: AnimationLibrary, skel: Skeleton3D, rig: Dictionary, clip_set: String, only: Array = []) -> void:
	_prepare_source()
	var extra := _bake(skel, rig, clip_set, more, only)
	for clip_name in extra.get_animation_list():
		library.add_animation(clip_name, extra.get_animation(clip_name))

## Samples every clip of `table` on the rig it was made for: per limb role, how far the
## bone has turned away from its rest pose in model space, plus the movement of the hips.
static func sample(rig_scene: String, table: Dictionary) -> Dictionary:
	var scene := (load(rig_scene) as PackedScene).instantiate()
	var skel := _find(scene, "Skeleton3D") as Skeleton3D
	var rig := _analyse(skel)
	var links := _links(rig)
	var order := _order(skel)
	var count := skel.get_bone_count()
	var parents := PackedInt32Array()
	var rest_local: Array = []
	var rest_inverse: Array = []
	var by_name := {}
	for i in range(count):
		parents.append(skel.get_bone_parent(i))
		rest_local.append(skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion())
		rest_inverse.append(skel.get_bone_global_rest(i).basis.orthonormalized().get_rotation_quaternion().inverse())
		by_name[skel.get_bone_name(i)] = i
	var keys: Array = []
	var aims := {}
	var spine_count := 0
	for link in links:
		var key: String = link.key
		if key == "spine":
			key = "spine%d" % spine_count
			spine_count += 1
		keys.append(key)
		aims[key] = _aim(skel, link)
	var pelvis: int = rig.pelvis.index
	var pelvis_rest := skel.get_bone_global_rest(pelvis).origin
	var clips := {}
	for clip_name in table:
		var info: Dictionary = table[clip_name]
		if not info.has("file"):
			continue
		var clip_scene := (load(CLIP_FOLDER + str(info.file) + ".fbx") as PackedScene).instantiate()
		var clip_player := _find(clip_scene, "AnimationPlayer") as AnimationPlayer
		var animation := clip_player.get_animation(clip_player.get_animation_list()[0])
		var rotation_track := PackedInt32Array()
		rotation_track.resize(count)
		rotation_track.fill(-1)
		var position_track := -1
		for track in range(animation.get_track_count()):
			var bone: int = by_name.get(animation.track_get_path(track).get_concatenated_subnames(), -1)
			if bone < 0:
				continue
			if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				rotation_track[bone] = track
			elif animation.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == pelvis:
				position_track = track
		var first := float(info.get("start", 0.0))
		var length := minf(animation.length, float(info.get("end", animation.length))) - first
		var frames := int(round(length / FRAME)) + 1
		var turns := {}
		for key in keys:
			turns[key] = []
		var offsets: Array = []
		var travel := PackedFloat32Array()
		var globals: Array = []
		globals.resize(count)
		for frame in range(frames):
			var time := first + minf(length, frame * FRAME)
			for bone in order:
				var local: Quaternion = rest_local[bone]
				if rotation_track[bone] >= 0:
					local = animation.rotation_track_interpolate(rotation_track[bone], time)
				globals[bone] = local if parents[bone] < 0 else (globals[parents[bone]] as Quaternion) * local
			for k in range(links.size()):
				var bone: int = links[k].index
				(turns[keys[k]] as Array).append((globals[bone] as Quaternion) * (rest_inverse[bone] as Quaternion))
			var offset := Vector3.ZERO
			if position_track >= 0:
				offset = animation.position_track_interpolate(position_track, time) - pelvis_rest
			offset.x *= float(info.get("drift", 1.0))
			if offset.y > 0.0:
				offset.y *= float(info.get("lift", 1.0))
			if info.get("travel", false):
				travel.append(offset.z)
				offset.z = 0.0
			if info.get("rooted", false):
				offset.x = 0.0
				offset.z = 0.0
			offsets.append(offset)
		clips[clip_name] = {"length": length, "frames": frames, "loop": bool(info.get("loop", false)), "fall": bool(info.get("fall", false)), "speed": float(info.get("speed", 0.0)), "strike": float(info.get("strike", 0.0)) - first, "set": str(info.get("set", "")), "turns": turns, "offsets": offsets, "travel": travel}
		clip_scene.free()
	for clip_name in table:
		var info: Dictionary = table[clip_name]
		if info.has("mirror"):
			clips[clip_name] = _mirrored(clips[info.mirror], keys, str(info.get("set", "")))
	scene.free()
	return {"clips": clips, "aims": aims, "spine": spine_count, "leg_length": float(rig.leg_length), "hip_height": pelvis_rest.y}

## The same motion with left and right exchanged: limbs trade places and every turn is
## reflected, so one recorded clip gives two different-looking ones.
static func _mirrored(clip: Dictionary, keys: Array, clip_set: String) -> Dictionary:
	var turns := {}
	for key in keys:
		var other: String = key
		for limb in LIMBS:
			if other.begins_with(limb):
				other = limb + ("1" if other.ends_with("0") else "0")
		var flipped: Array = []
		for turn in clip.turns[other]:
			var q: Quaternion = turn
			flipped.append(Quaternion(q.x, -q.y, -q.z, q.w))
		turns[key] = flipped
	var offsets: Array = []
	for offset in clip.offsets:
		offsets.append(Vector3(-(offset as Vector3).x, (offset as Vector3).y, (offset as Vector3).z))
	var copy := clip.duplicate()
	copy["turns"] = turns
	copy["offsets"] = offsets
	copy["set"] = clip_set
	return copy

## Builds this skeleton's own copy of every clip. Limbs are first turned to the source's
## rest direction, then follow the source's motion, so an A-pose rig and a T-pose rig end
## up in the same stance. Feet are put back on the ground afterwards.
## `from` is the sampled clip set to use (the infected's by default), `only` limits the
## result to the named clips and `bones` to tracks for those bones.
static func _bake(skel: Skeleton3D, rig: Dictionary, clip_set: String, from: Dictionary = {}, only: Array = [], bones: Array = []) -> AnimationLibrary:
	_prepare_source()
	var src := source if from.is_empty() else from
	var links := _links(rig)
	var order := _order(skel)
	var count := skel.get_bone_count()
	var parents := PackedInt32Array()
	var rest_local: Array = []
	var rest_origin: Array = []
	for i in range(count):
		parents.append(skel.get_bone_parent(i))
		rest_local.append(skel.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion())
		rest_origin.append(skel.get_bone_rest(i).origin)
	# Per animated bone: which source role it follows and its aligned rest orientation.
	var follows := {}
	var bases := {}
	var spine_total: int = (rig.spine as Array).size()
	var spine_seen := 0
	var parent_align := Quaternion.IDENTITY
	for link in links:
		var key: String = link.key
		if key == "spine":
			key = "spine%d" % int(round(float(spine_seen) / maxf(1.0, spine_total - 1.0) * (int(src.spine) - 1)))
			spine_seen += 1
		var align := Quaternion.IDENTITY
		if str(link.align) == "aim":
			var own := _aim(skel, link)
			var wanted: Vector3 = src.aims.get(key, Vector3.ZERO)
			if own != Vector3.ZERO and wanted != Vector3.ZERO:
				align = Quaternion(own, wanted)
			parent_align = align
		elif str(link.align) == "parent":
			align = parent_align
		follows[int(link.index)] = key
		bases[int(link.index)] = align * skel.get_bone_global_rest(int(link.index)).basis.orthonormalized().get_rotation_quaternion()
	# Only animated bones and their ancestors need to be evaluated.
	var needed := {}
	for bone in follows:
		var up: int = bone
		while up >= 0 and not needed.has(up):
			needed[up] = true
			up = parents[up]
	var chain: Array = []
	for bone in order:
		if needed.has(bone):
			chain.append(bone)
	var pelvis: int = rig.pelvis.index
	var pelvis_rest := skel.get_bone_global_rest(pelvis).origin
	var ratio := pelvis_rest.y / float(src.hip_height)
	var feet: Array = []
	var rest_ground := INF
	for leg in rig.legs:
		for bone in [int(leg.foot.index), int(leg.toe)]:
			if bone >= 0:
				feet.append(bone)
				rest_ground = minf(rest_ground, skel.get_bone_global_rest(bone).origin.y)
	var library := AnimationLibrary.new()
	var globals: Array = []
	var origins: Array = []
	globals.resize(count)
	origins.resize(count)
	for clip_name in src.clips:
		var clip: Dictionary = src.clips[clip_name]
		if (str(clip.set) != "" and str(clip.set) != clip_set) or (not only.is_empty() and not only.has(clip_name)):
			continue
		var animation := Animation.new()
		animation.length = float(clip.length)
		animation.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		var move_track := -1
		if bones.is_empty() or bones.has(pelvis):
			move_track = animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(move_track, NodePath("%s:%s" % [skel.name, skel.get_bone_name(pelvis)]))
		var tracks := {}
		for bone in follows:
			if not bones.is_empty() and not bones.has(bone):
				continue
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath("%s:%s" % [skel.name, skel.get_bone_name(bone)]))
			tracks[bone] = track
		var frames: int = clip.frames
		var placed: Array = []
		var lowest := INF
		var first_low := INF
		for frame in range(frames):
			var time := minf(float(clip.length), frame * FRAME)
			var hips: Vector3 = pelvis_rest + (clip.offsets[frame] as Vector3) * ratio
			var low := INF
			for bone in chain:
				var parent: int = parents[bone]
				var turn: Quaternion
				if follows.has(bone):
					turn = (clip.turns[follows[bone]][frame] as Quaternion) * (bases[bone] as Quaternion)
				elif parent >= 0:
					turn = (globals[parent] as Quaternion) * (rest_local[bone] as Quaternion)
				else:
					turn = rest_local[bone]
				globals[bone] = turn
				if bone == pelvis:
					origins[bone] = hips
				elif parent >= 0:
					origins[bone] = (origins[parent] as Vector3) + (globals[parent] as Quaternion) * (rest_origin[bone] as Vector3)
				else:
					origins[bone] = rest_origin[bone]
				if tracks.has(bone):
					var local: Quaternion = turn if parent < 0 else (globals[parent] as Quaternion).inverse() * turn
					animation.rotation_track_insert_key(tracks[bone], time, local.normalized())
			for bone in feet:
				low = minf(low, (origins[bone] as Vector3).y)
			lowest = minf(lowest, low)
			if frame == 0:
				first_low = low
			var above: int = parents[pelvis]
			if above >= 0:
				placed.append([time, (globals[above] as Quaternion).inverse() * (hips - (origins[above] as Vector3)), (globals[above] as Quaternion).inverse() * Vector3.UP])
			else:
				placed.append([time, hips, Vector3.UP])
		# A falling body is only grounded at its start; everything else by its lowest step.
		var lift := rest_ground - (first_low if clip.fall else lowest)
		if move_track >= 0:
			for entry in placed:
				animation.position_track_insert_key(move_track, entry[0], (entry[1] as Vector3) + (entry[2] as Vector3) * lift)
		library.add_animation(clip_name, animation)
	return library

## Prepares the kinds before the first round so no spawn has to wait for it: at the start
## of the game those of the first mission; with `mission` 2 - when a night of the second
## mission begins - also those that only it brings ("mission" in KINDS). Each of those costs
## an eighth of a second and its maps on the graphics card, which a session on the farm
## never has to pay. (A kind that turns up unprepared is prepared on the spot.)
static func warm_up(parent: Node, mission: int = 1) -> void:
	for kind_name in KINDS:
		if not libraries.has(kind_name) and int((KINDS[kind_name] as Dictionary).get("mission", 1)) <= mission:
			var probe := InfectedVisual.new()
			probe.kind = kind_name
			parent.add_child(probe)
			probe.free()
	if ResourceLoader.exists(RipperVisual.SCENE):
		RipperVisual.model_scene()

# ---------------------------------------------------------------- charger auto-rig

static func _charger_weights(v: Vector3) -> Array:
	var ax := absf(v.x)
	var side := smoothstep(-0.05, 0.05, v.x)
	var arm := smoothstep(0.27, 0.43, ax) * maxf(smoothstep(1.12, 1.24, v.y), smoothstep(0.42, 0.5, ax))
	var fore := smoothstep(0.55, 0.69, ax)
	var hand := smoothstep(0.82, 0.9, ax)
	var leg := (1.0 - smoothstep(0.5, 0.64, v.y)) * (1.0 - smoothstep(0.1, 0.2, v.z) * smoothstep(0.5, 0.58, v.y))
	var shin := 1.0 - smoothstep(0.26, 0.36, v.y)
	var foot := 1.0 - smoothstep(0.07, 0.13, v.y)
	var head := smoothstep(1.5, 1.6, v.y) * (1.0 - smoothstep(0.2, 0.3, ax))
	var torso := (1.0 - arm) * (1.0 - leg) * (1.0 - head)
	var chest := smoothstep(1.0, 1.3, v.y)
	var hips := 1.0 - smoothstep(0.62, 0.9, v.y)
	var arm_base := 10 if v.x > 0.0 else 6
	var pairs := [
		[0, torso * hips], [1, torso * maxf(0.0, 1.0 - chest - hips)], [2, torso * chest],
		[4, (1.0 - arm) * (1.0 - leg) * head],
		[arm_base, arm * (1.0 - fore)], [arm_base + 1, arm * fore * (1.0 - hand)], [arm_base + 2, arm * fore * hand],
		[13, leg * (1.0 - shin) * (1.0 - side)], [14, leg * shin * (1.0 - foot) * (1.0 - side)], [15, leg * shin * foot * (1.0 - side)],
		[16, leg * (1.0 - shin) * side], [17, leg * shin * (1.0 - foot) * side], [18, leg * shin * foot * side]
	]
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return pairs.slice(0, 4)

## The Charger arrives as a bare T-pose mesh. Skin it to a generated skeleton so it can
## share the animation clips of the rigged infected.
func _build_charger() -> void:
	if charger_mesh == null:
		var imported := (config.scene as PackedScene).instantiate()
		var source_mesh := (_find(imported, "MeshInstance3D") as MeshInstance3D).mesh
		var arrays := source_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for i in range(vertices.size()):
			var lifted := vertices[i] + Vector3(0, CHARGER_LIFT, 0)
			vertices[i] = lifted
			var influences := _charger_weights(lifted)
			var total := 0.0
			for pair in influences:
				total += float(pair[1])
			for slot in range(4):
				bones[i * 4 + slot] = int(influences[slot][0])
				weights[i * 4 + slot] = float(influences[slot][1]) / maxf(total, 0.0001)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		charger_mesh = ArrayMesh.new()
		charger_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		charger_mesh.surface_set_material(0, source_mesh.surface_get_material(0))
		imported.free()
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	for bone in CHARGER_BONES:
		skeleton.add_bone(bone[0])
	for i in range(CHARGER_BONES.size()):
		var parent: int = CHARGER_BONES[i][1]
		var origin: Vector3 = CHARGER_BONES[i][2]
		if parent >= 0:
			skeleton.set_bone_parent(i, parent)
			origin -= CHARGER_BONES[parent][2]
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, origin))
	skeleton.reset_bone_poses()
	holder.add_child(skeleton)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = charger_mesh
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.skin = skeleton.create_skin_from_rest_transforms()

# ---------------------------------------------------------------- glowing eyes

func _build_eyes() -> void:
	if not eye_offsets.has(kind):
		# Find where the face surface is at eye level so the glow sits just in front of it.
		var vertices: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var height: float = config.eye_height
		var gap: float = config.eye_gap
		var centre: float = config.eye_center
		var front := -INF
		for v in vertices:
			if absf(v.y - height) < 0.018 and absf(absf(v.x - centre) - gap) < 0.016 and v.z > front:
				front = v.z
		if front == -INF:
			front = 0.1
		var head_rest: Transform3D = skeleton.get_bone_global_rest(rig.head.index)
		var offsets: Array[Vector3] = []
		for side in [-1.0, 1.0]:
			offsets.append(head_rest.affine_inverse() * Vector3(centre + side * gap, height, front + 0.004))
		eye_offsets[kind] = offsets
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = config.eye_color
		glow.emission_enabled = true
		glow.emission = config.eye_color
		glow.emission_energy_multiplier = 3.5
		eye_materials[kind] = glow
	var attachment := BoneAttachment3D.new()
	attachment.name = "Eyes"
	skeleton.add_child(attachment)
	attachment.bone_idx = rig.head.index
	eyes = attachment
	for offset in eye_offsets[kind]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = float(config.eye_size)
		sphere.height = float(config.eye_size) * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		eye.mesh = sphere
		eye.material_override = eye_materials[kind]
		eye.position = offset
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attachment.add_child(eye)

## Shows or takes away the marks of a Medic's gas.
func set_buffed(on: bool) -> void:
	if on == buffed or mesh_instance == null:
		return
	buffed = on
	if sheen == null:
		sheen = ShaderMaterial.new()
		var code := Shader.new()
		code.code = SHEEN_CODE
		sheen.shader = code
		buff_eye = StandardMaterial3D.new()
		buff_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		buff_eye.albedo_color = BUFF_COLOR
		buff_eye.emission_enabled = true
		buff_eye.emission = BUFF_COLOR
		buff_eye.emission_energy_multiplier = 6.0
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 1, 1, 0))
		var soft := GradientTexture2D.new()
		soft.gradient = fade
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(0.5, 0.0)
		buff_glow = StandardMaterial3D.new()
		buff_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		buff_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		buff_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		buff_glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		buff_glow.billboard_keep_scale = true
		buff_glow.albedo_texture = soft
		buff_glow.albedo_color = Color(BUFF_COLOR.r, BUFF_COLOR.g, BUFF_COLOR.b, 0.32)
	_dress()
	for mark in buff_marks:
		mark.queue_free()
	buff_marks.clear()
	if not on or skeleton == null or not rig.has("arms"):
		return
	# A glow on each forearm and hand.
	for arm in rig.arms:
		for part in ["fore", "hand"]:
			var holder_bone := BoneAttachment3D.new()
			skeleton.add_child(holder_bone)
			holder_bone.bone_idx = int(arm[part].index)
			var glow := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE * (0.24 if part == "fore" else 0.2) / model_scale
			glow.mesh = quad
			glow.material_override = buff_glow
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder_bone.add_child(glow)
			buff_marks.append(holder_bone)

## What lies over the skin and burns in the eyes: the Crusher's shell before a Medic's sheen.
func _dress() -> void:
	var shelled := shell_skin != null and (shell_state != "" or shell > 0.01)
	mesh_instance.material_overlay = shell_skin if shelled else (sheen if buffed else null)
	var hard := shell_state == "on"
	for eye in eyes.get_children():
		if eye is MeshInstance3D and eye_materials.has(kind):
			(eye as MeshInstance3D).material_override = shell_eye if hard else (buff_eye if buffed else eye_materials[kind])
			(eye as MeshInstance3D).scale = Vector3.ONE * (2.2 if hard else (1.6 if buffed else 1.0))

## Shows the Crusher's shell: "" takes it away, "tell" lets it creep over the skin in
## fits and starts, "on" shuts it with a flare.
func set_shell(state: String) -> void:
	if state == shell_state or mesh_instance == null:
		return
	shell_state = state
	shell_for = 0.0
	if state == "on":
		shell_flare = 1.0
	if shell_skin == null:
		if shell_code == null:
			shell_code = Shader.new()
			shell_code.code = SHELL_CODE
			shell_eye = StandardMaterial3D.new()
			shell_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			shell_eye.albedo_color = Color(1.0, 0.8, 0.45)
			shell_eye.emission_enabled = true
			shell_eye.emission = SHELL_COLOR
			shell_eye.emission_energy_multiplier = 7.0
		shell_skin = ShaderMaterial.new()
		shell_skin.shader = shell_code
		shell_skin.set_shader_parameter("plates", SHELL_PLATES)
		shell_lamp = OmniLight3D.new()
		shell_lamp.light_color = SHELL_COLOR
		shell_lamp.omni_range = 6.0
		shell_lamp.shadow_enabled = false
		shell_lamp.light_energy = 0.0
		shell_lamp.position = Vector3(0, float(config.height) * 0.6, -1.0)
		add_child(shell_lamp)
	_dress()

## The shell grows, flickers and fades, frame by frame.
func _shell_step(delta: float) -> void:
	shell_for += delta
	var goal := 0.0
	var pace := 2.4
	if shell_state == "on":
		goal = 1.0
		pace = 7.0
	elif shell_state == "tell":
		# It comes in fits and starts, more of it each time.
		goal = clampf(0.15 + shell_for * 0.5, 0.0, 0.62) * (0.6 + 0.4 * sin(clock * 34.0) * sin(clock * 11.0))
		pace = 9.0
	var shown := shell > 0.01
	shell = move_toward(shell, goal, delta * pace)
	shell_flare = maxf(0.0, shell_flare - delta * 3.2)
	shell_skin.set_shader_parameter("amount", shell)
	shell_skin.set_shader_parameter("flare", shell_flare)
	shell_lamp.light_energy = shell * 1.1 + shell_flare * 2.0
	shell_lamp.visible = shell > 0.01
	if shown != (shell > 0.01):
		_dress()

# ---------------------------------------------------------------- animation

func _clip(clip_name: String) -> Dictionary:
	return source.clips[clip_name] if source.clips.has(clip_name) else more.clips[clip_name]

## Advances the animation. `speed` is how fast the body really moves, so the stride
## matches the ground instead of sliding over it.
func animate(delta: float, speed: float) -> void:
	clock += delta
	flinch = maxf(0.0, flinch - delta * 4.5)
	travel = 0.0
	if shell_skin != null:
		_shell_step(delta)
	if guard_on or guard > 0.0:
		var up := guard_on and not dying and state == "move"
		guard = move_toward(guard, 1.0 if up else 0.0, delta * (4.5 if up else 5.5))
	if dying:
		death_time += delta
		if dissolving:
			var shrink := clampf(1.0 - (death_time - 0.5) / 1.3, 0.0, 1.0)
			holder.scale = Vector3.ONE * model_scale * lerpf(0.05, 1.0, shrink)
		if death_time > 0.6 and eyes.visible:
			eyes.hide()
	elif busy_left > 0.0:
		busy_left -= delta
		if busy_left <= 0.0:
			state = "move"
			gait = ""
	if state == "move" and not dying:
		_stride(speed, delta)
	player.advance(delta)
	if travel_clip != "" and state in ["stagger", "attack"]:
		if not (_clip(travel_clip).travel as PackedFloat32Array).is_empty():
			var z := _travel_at(travel_clip, player.current_animation_position)
			travel = (z - travel_last) * model_scale * stride_scale
			travel_last = z
	_overlay()

## Picks idle, walk or run for the current speed and plays it at the matching rate.
func _stride(speed: float, delta: float) -> void:
	var paced := speed / (model_scale * stride_scale)
	move = clampf(paced, 0.0, 1.0)
	var wanted := "idle"
	var rate := 1.0
	if paced > 0.12:
		var walk: Dictionary = _clip(moves.walk)
		var run: Dictionary = _clip(moves.run)
		wanted = str(moves.run) if paced > sqrt(float(walk.speed) * float(run.speed)) else str(moves.walk)
		var pace: Array = moves.pace
		rate = clampf(paced / float(_clip(wanted).speed), float(pace[0]), float(pace[1]))
		phase += TAU * rate * delta / float(_clip(wanted).length)
	if wanted != gait:
		gait = wanted
		player.play(wanted, 0.22)
	player.speed_scale = rate

## Rotates a bone in model space on top of whatever the clip just posed.
func _nudge(index: int, euler: Vector3) -> void:
	var global := skeleton.get_bone_global_pose(index).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * (global.inverse() * Quaternion.from_euler(euler) * global))

func _overlay() -> void:
	if flinch > 0.01:
		var spine: Array = rig.spine
		for bone in spine:
			_nudge(bone.index, Vector3(-0.3 * flinch, flinch_side * 0.42 * flinch, flinch_side * 0.12 * flinch) / spine.size())
		_nudge(rig.head.index, Vector3(-0.32 * flinch, flinch_side * 0.25 * flinch, 0))
	if duck > 0.01:
		# Bend at the knees and lean in, so the giant fits under a door frame.
		var bend := duck * 0.55
		for leg in rig.legs:
			_nudge(leg.thigh.index, Vector3(-bend, 0, 0))
			_nudge(leg.shin.index, Vector3(bend * 2.0, 0, 0))
			_nudge(leg.foot.index, Vector3(-bend, 0, 0))
		for bone in rig.spine:
			_nudge(bone.index, Vector3(duck * 0.5 / (rig.spine as Array).size(), 0, 0))
		var pelvis: int = rig.pelvis.index
		var drop := float(rig.leg_length) * (1.0 - cos(bend))
		var up := Vector3.UP
		var above := skeleton.get_bone_parent(pelvis)
		if above >= 0:
			up = skeleton.get_bone_global_pose(above).basis.inverse() * Vector3.UP
		skeleton.set_bone_pose_position(pelvis, skeleton.get_bone_pose_position(pelvis) - up * drop)
	if guard > 0.01:
		_raise_guard(smoothstep(0.0, 1.0, guard))
	if swell > 0.0:
		var pulse := 1.0 + swell * (0.2 + 0.06 * sin(clock * 34.0))
		holder.scale = Vector3(pulse, 1.0 + swell * 0.04, pulse) * model_scale

## Turns a bone, in model space and on top of whatever it is posed as, so that what points
## along `from` comes to point along `to` - as far as `weight` says.
func _point(index: int, from: Vector3, to: Vector3, weight: float) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var turn := Quaternion.IDENTITY.slerp(Quaternion(from.normalized(), to.normalized()), weight)
	var global := skeleton.get_bone_global_pose(index).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * (global.inverse() * turn * global))

## The Crusher's forearm before its face. No clip does this: shoulder and elbow are turned
## so that the forearm lies across the eyes, a hand's breadth before them, whatever the
## clip does with the arm meanwhile - the legs and the other arm go on walking. The head
## is drawn in behind it a little.
func _raise_guard(weight: float) -> void:
	if not eye_offsets.has(kind) or not rig.has("arms"):
		return
	_nudge(rig.head.index, Vector3(GUARD_TUCK * weight, 0, 0))
	var arm: Dictionary = rig.arms[GUARD_ARM]
	var head := skeleton.get_bone_global_pose(rig.head.index)
	var offsets: Array = eye_offsets[kind]
	var face: Vector3 = head * (((offsets[0] as Vector3) + (offsets[1] as Vector3)) * 0.5)
	# Which way the face looks, and which way the arm's own side lies from it.
	var ahead: Vector3 = (head.basis.orthonormalized() * (skeleton.get_bone_global_rest(rig.head.index).basis.orthonormalized().inverse() * Vector3(0, 0, 1))).normalized()
	var shoulder: Vector3 = skeleton.get_bone_global_pose(arm.upper.index).origin
	var elbow_now: Vector3 = skeleton.get_bone_global_pose(arm.fore.index).origin
	var hand_now: Vector3 = skeleton.get_bone_global_pose(arm.hand.index).origin
	var out := Vector3.UP.cross(ahead).normalized()
	if out.dot(shoulder - face) < 0.0:
		out = -out
	var upper_length := shoulder.distance_to(elbow_now)
	var fore_length := elbow_now.distance_to(hand_now)
	var before := face + ahead * GUARD_FRONT
	var pole := out * GUARD_ELBOW.x + Vector3.DOWN * GUARD_ELBOW.y + ahead * GUARD_ELBOW.z
	# The forearm is to pass before the eyes. Where its wrist has to be for that depends on
	# where the elbow ends up, and that on the wrist: three rounds settle it.
	var lie := (-out * GUARD_LIE.x + Vector3.UP * GUARD_LIE.y).normalized()
	var elbow := elbow_now
	var wrist := hand_now
	for i in range(3):
		wrist = before + lie * fore_length * (1.0 - GUARD_ALONG)
		var reach := wrist - shoulder
		var span := clampf(reach.length(), absf(upper_length - fore_length) + 0.005, upper_length + fore_length - 0.005)
		var along := reach.normalized()
		wrist = shoulder + along * span
		var near := (upper_length * upper_length - fore_length * fore_length + span * span) / (2.0 * span)
		var bend := (pole - along * pole.dot(along)).normalized()
		elbow = shoulder + along * near + bend * sqrt(maxf(0.0, upper_length * upper_length - near * near))
		lie = (wrist - elbow).normalized()
	_point(arm.upper.index, elbow_now - shoulder, elbow - shoulder, weight)
	var fore := skeleton.get_bone_global_pose(arm.fore.index).origin
	_point(arm.fore.index, skeleton.get_bone_global_pose(arm.hand.index).origin - fore, wrist - fore, weight)

func _begin(clip_name: String, blend: float, rate: float, from: float, hold: float, next_state: String) -> void:
	player.speed_scale = 1.0
	player.play(clip_name, blend, rate)
	if from > 0.0:
		player.seek(from)
	state = next_state
	busy_left = hold
	gait = ""

## Starts an attack whose blow lands `strike_at` seconds from now. Returns the clip used.
func attack(duration: float, strike_at: float = 0.36, clip_name: String = "") -> String:
	if dying:
		return ""
	if clip_name == "":
		clip_name = (moves.attacks as Array).pick_random()
	var strike: float = _clip(clip_name).strike
	# Skip the slow start of the clip and speed the wind-up a little, so the hand arrives on time.
	var lead := minf(strike, strike_at * 1.45)
	_begin(clip_name, 0.1, lead / maxf(0.05, strike_at), strike - lead, duration, "attack")
	travel_clip = clip_name
	travel_last = 0.0
	if not (_clip(clip_name).travel as PackedFloat32Array).is_empty():
		travel_last = _travel_at(clip_name, strike - lead)
	return clip_name

func _travel_at(clip_name: String, seconds: float) -> float:
	var curve: PackedFloat32Array = _clip(clip_name).travel
	var at := clampf(seconds / FRAME, 0.0, curve.size() - 1.0)
	var low := int(at)
	return lerpf(curve[low], curve[mini(low + 1, curve.size() - 1)], at - low)

## A bullet jerks the upper body; `strength` is 0..1.
func hit(from_side: float, strength: float = 1.0) -> void:
	if shell_state == "on":
		# It glances off the shell: a flare where a body would flinch.
		shell_flare = maxf(shell_flare, 0.55)
		return
	flinch = clampf(maxf(flinch, 0.45 + strength * 0.55), 0.0, 1.0)
	flinch_side = from_side

## A heavy hit interrupts whatever the infected was doing. Returns how long it is stunned.
func stagger(heavy: bool, clip_name: String = "") -> float:
	if dying:
		return 0.0
	if clip_name == "":
		clip_name = "stumble" if heavy else pick_flinch()
	var rate := 1.4
	var hold := (1.75 if clip_name == "stumble" else 0.85) / rate
	_begin(clip_name, 0.07, rate, 0.0, hold, "stagger")
	travel_clip = clip_name
	travel_last = 0.0
	return hold

func pick_flinch() -> String:
	var options := ["flinch"]
	for clip_name in ["recoil", "flinch_left"]:
		if player.has_animation(clip_name):
			options.append(clip_name)
	return options.pick_random()

## A short halt with a scream, used when an infected notices its prey.
func scream(clip_name: String = "scream") -> float:
	if dying or not player.has_animation(clip_name):
		return 0.0
	match clip_name:
		"roar": _begin(clip_name, 0.2, 1.25, 0.0, 2.2, "scream")
		"writhe": _begin(clip_name, 0.2, 1.3, 0.0, 1.7, "scream")
		_: _begin(clip_name, 0.15, 1.3, 0.35, 1.25, "scream")
	return busy_left

## Which pool of DEATHS fits the shot: `forward` when hit from behind, `side` is where the
## bullet was heading across the body (negative: towards the body's left), `hard` when
## the hit was far more than it took.
static func death_pool(forward: bool, headshot: bool, side: float, hard: bool) -> String:
	if forward:
		return "behind_head" if headshot else "behind"
	if hard and randf() < 0.7:
		return "hard"
	if headshot and randf() < 0.7:
		return "head"
	if absf(side) > 0.55:
		return "from_right" if side < 0.0 else "from_left"
	return "front"

## The falls of a pool that this build can do: some bodies end up in the floor in some.
func _can_do(pool: String) -> Array:
	var options: Array = DEATHS[pool]
	if not config.has("deaths"):
		return options
	var allowed: Array = config.deaths
	return options.filter(func(clip: String) -> bool: return allowed.has(clip))

## The death that fits the shot (see death_pool).
func pick_death(forward: bool, headshot: bool = false, side: float = 0.0, hard: bool = false) -> String:
	if str(config.set) == "mutant":
		return "mutant_death"
	var options := _can_do(death_pool(forward, headshot, side, hard))
	# A build that can do none of them falls the plain way for that side.
	if options.is_empty():
		options = _can_do("behind" if forward else "front")
	if options.is_empty():
		options = config.deaths
	return options.pick_random()

## Falls and stays on the ground.
func die(clip_name: String) -> void:
	dying = true
	state = "dead"
	player.speed_scale = 1.0
	player.play(clip_name, 0.1, randf_range(1.2, 1.4))

## Sinks to its knees and shrinks away; used by the Crusher inside its acid cloud.
func dissolve() -> void:
	set_shell("")
	guard_on = false
	dying = true
	dissolving = true
	state = "dead"
	player.speed_scale = 1.0
	player.play("mutant_death" if player.has_animation("mutant_death") else "death_forward", 0.15, 1.0)

## Tears off the head or an arm: the bones shrink to nothing. Returns a marker on the
## stump that keeps following the body, for blood to pour from.
func sever(part: String) -> Node3D:
	var bone: int = rig.head.index
	if part == "arm0" or part == "arm1":
		bone = rig.arms[0 if part == "arm0" else 1].upper.index
	var stump := BoneAttachment3D.new()
	skeleton.add_child(stump)
	stump.bone_idx = skeleton.get_bone_parent(bone)
	var marker := Node3D.new()
	marker.position = skeleton.get_bone_rest(bone).origin
	stump.add_child(marker)
	skeleton.set_bone_pose_scale(bone, Vector3.ONE * 0.001)
	if part == "head":
		eyes.hide()
	return marker

func pick_attack() -> String:
	return (moves.attacks as Array).pick_random()

## Only the Ripper leaps; everyone else ignores the call.
func pounce() -> void:
	pass

func head_position() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(rig.head.index).origin
