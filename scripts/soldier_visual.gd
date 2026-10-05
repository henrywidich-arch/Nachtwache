class_name SoldierVisual
extends Node3D
## A soldier seen from outside: the teammates Viper and Scorpion, and the other player of
## a co-op match. Both models were rigged by Mixamo. The rifle clips were made for Viper
## and are carried over to Scorpion the same way the infected share theirs.
## Legs and upper body are animated in two layers, so a soldier can keep walking while
## firing or reloading. The weapon rides in the right hand, lined up on the left one.

const VIPER_RIG := "res://assets/models/mixamo/viper_rig.fbx"
## speed: ground speed of the source character in m/s.
const CLIPS := {
	"idle": {"file": "viper_rig", "loop": true},
	"run": {"file": "soldier_run", "loop": true, "speed": 3.4},
	"walk": {"file": "soldier_walk", "loop": true, "speed": 1.1},
	"back": {"file": "soldier_walk_back", "loop": true, "speed": 0.85},
	"fire": {"file": "soldier_fire", "loop": true},
	# The first moment of the firing clip, held: the aimed stance.
	"aim": {"file": "soldier_fire", "loop": true, "end": 0.07},
	"reload": {"file": "soldier_reload"},
	"get_up": {"file": "soldier_get_up", "start": 0.4, "travel": true}
}
const UPPER_CLIPS := ["idle", "run", "walk", "back", "fire", "aim", "reload"]
## Clips recorded on Scorpion's rig: sidesteps, the crouch, the dodge roll, the throw of a
## grenade (mirrored, so that the weapon stays in the hand that holds it), hanging on a
## rope and coming down hard. They live in the animation library "move".
const SCORPION_RIG := "res://assets/models/mixamo/skorpion_rig.fbx"
const MOVES := {
	"strafe_right": {"file": "soldier_strafe", "loop": true, "speed": 1.9, "drift": 0.0},
	"strafe_left": {"mirror": "strafe_right"},
	"crouch": {"file": "soldier_crouch", "loop": true},
	"crouch_run": {"file": "soldier_crouch_run", "loop": true, "speed": 2.4},
	# The soldier's body moves through the roll by itself (CruSoldier.ROLL_SPEED): the clip
	# must not carry the model on top of that, or it jumps back when the roll is over.
	"roll": {"file": "soldier_roll", "rooted": true},
	"throw_right": {"file": "soldier_throw"},
	"throw": {"mirror": "throw_right"},
	"rope": {"file": "soldier_rope", "loop": true},
	"land": {"file": "soldier_land"},
	# Arms hanging at rest: the upper body of somebody who carries no weapon.
	"calm": {"file": "npc_idle", "loop": true}
}
const UPPER_MOVES := ["throw", "calm"]
## The throw is played from this share of the clip on, at this rate: wind-up and release.
const THROW_FROM := 0.22
const THROW_RATE := 1.5
## The falls every body can do, and gets up from again.
const FALLS := ["death_back", "death_forward"]
## More ways to go down, for somebody who stays there (see mortal): the falls of the
## infected (InfectedVisual.DEATHS says which fits which shot).
const DEATHS := ["death_side", "death_side_left", "death_headshot", "death_from_back", "death_from_front", "death_from_right", "death_from_left", "death_drop_back", "death_drop_left", "death_drop_right", "death_dying_back", "death_fall_back", "death_fall_forward", "death_fly_back", "death_bow_forward", "death_back_headshot"]
const RISE_RATE := 2.3
## weapon: what is carried. grip-relative points of each weapon are listed in WEAPONS.
const LOOKS := {
	"viper": {
		"label": "VIPER", "scene": preload("res://assets/models/mixamo/viper_rig.fbx"), "textures": "res://assets/models/viper_",
		"source_height": 1.7, "height": 1.7, "weapon": "badger", "shot": "badger", "voice": "bot_hurt_female"
	},
	"scorpion": {
		"label": "SCORPION", "scene": preload("res://assets/models/mixamo/skorpion_rig.fbx"), "textures": "res://assets/models/skorpion_",
		"source_height": 1.8, "height": 1.84, "weapon": "shotgun", "shot": "shotgun", "voice": "bot_hurt_male"
	},
	# The player's own model: what the co-op partner sees.
	"main": {
		"label": "FIRETEAM", "scene": preload("res://assets/models/main.glb"), "textures": "res://assets/models/main_",
		"source_height": 1.8, "height": 1.8, "weapon": "rifle", "shot": "shot", "voice": "bot_hurt_male"
	},
	"raven": {
		"label": "RAVEN", "scene": preload("res://assets/models/raven.glb"), "textures": "res://assets/models/raven_",
		"source_height": 1.82, "height": 1.82, "weapon": "badger", "shot": "badger", "voice": "bot_hurt_female"
	},
	# Helix's Containment Response Unit.
	"cru": {
		"label": "C.R.U.", "scene": preload("res://assets/models/cru.glb"), "textures": "res://assets/models/cru_",
		"source_height": 1.85, "height": 1.85, "weapon": "rifle", "shot": "shot", "voice": "bot_hurt_male"
	},
	"cru2": {
		"label": "C.R.U.", "scene": preload("res://assets/models/cru2.glb"), "textures": "res://assets/models/cru2_",
		"source_height": 1.85, "height": 1.85, "weapon": "shotgun", "shot": "shotgun", "voice": "bot_hurt_male"
	},
	# A third body, for variety in the ranks.
	"cru3": {
		"label": "C.R.U.", "scene": preload("res://assets/models/cru3.glb"), "textures": "res://assets/models/cru3_",
		"source_height": 1.85, "height": 1.85, "weapon": "rifle", "shot": "shot", "voice": "bot_hurt_male"
	},
	# The Elite: hood and gas mask, a plate carrier full of magazines, and an AK-47.
	"cruelite": {
		"label": "C.R.U. ELITE", "scene": preload("res://assets/models/cruelite.glb"), "textures": "res://assets/models/cruelite_",
		"source_height": 1.89, "height": 1.89, "weapon": "ak", "shot": "ak", "voice": "bot_hurt_male"
	},
	# The same two bodies with other kit: the squad leader and marksman carry rifles, the
	# heavy is a head taller than the rest.
	"cru_lead": {
		"label": "C.R.U.", "scene": preload("res://assets/models/cru2.glb"), "textures": "res://assets/models/cru2_",
		"source_height": 1.85, "height": 1.88, "weapon": "rifle", "shot": "shot", "voice": "bot_hurt_male"
	},
	"cru_heavy": {
		"label": "C.R.U.", "scene": preload("res://assets/models/cru.glb"), "textures": "res://assets/models/cru_",
		"source_height": 1.85, "height": 1.99, "weapon": "rifle", "shot": "shot", "voice": "bot_hurt_male"
	},
	# The three operators (see Operator), who are also looks the player can earn. eyes: where
	# their eyes glow, on the model as it stands at rest (x across, y up, z to its front),
	# and how big each is.
	"phantom": {
		"label": "PHANTOM", "scene": preload("res://assets/models/cruelite.glb"), "textures": "res://assets/models/cruelite_",
		"source_height": 1.89, "height": 1.9, "weapon": "badger", "shot": "badger", "voice": "bot_hurt_male",
		"eyes": {"at": [Vector3(-0.057, 1.735, 0.184), Vector3(0.057, 1.735, 0.184)], "size": 0.02}
	},
	"havoc": {
		"label": "HAVOC", "scene": preload("res://assets/models/cruelite.glb"), "textures": "res://assets/models/cruelite_",
		"source_height": 1.89, "height": 1.95, "weapon": "shotgun", "shot": "shotgun", "voice": "bot_hurt_male",
		"eyes": {"at": [Vector3(-0.057, 1.735, 0.184), Vector3(0.057, 1.735, 0.184)], "size": 0.02}
	},
	"ghost": {
		"label": "GHOST", "scene": preload("res://assets/models/cruelite.glb"), "textures": "res://assets/models/cruelite_",
		"source_height": 1.89, "height": 1.88, "weapon": "rifle", "shot": "shot", "voice": "bot_hurt_male",
		"eyes": {"at": [Vector3(-0.057, 1.735, 0.184), Vector3(0.057, 1.735, 0.184)], "size": 0.02}
	},
	"nadja": {
		"label": "NADJA", "scene": preload("res://assets/models/nadja.glb"), "textures": "res://assets/models/nadja_",
		"source_height": 1.68, "height": 1.68, "weapon": "", "shot": "badger", "voice": "bot_hurt_female"
	},
	"shopkeeper": {
		"label": "HÄNDLERIN", "scene": preload("res://assets/models/shopkeeper.glb"), "textures": "res://assets/models/shopkeeper_",
		"source_height": 1.66, "height": 1.66, "weapon": "badger", "shot": "badger", "voice": "bot_hurt_female"
	}
}
## Points of each weapon measured from where the firing hand holds it (-Z is forward).
const WEAPONS := {
	"badger": {"mount": Vector3(0, -0.0697, -0.1251), "support": Vector3(0, 0.102, -0.226), "muzzle": Vector3(0, 0.102, -0.488)},
	"rifle": {"mount": Vector3(0, 0.075, -0.076), "support": Vector3(0, 0.087, -0.326), "muzzle": Vector3(0, 0.081, -0.756)},
	"shotgun": {"mount": Vector3.ZERO, "support": Vector3(0, 0.05, -0.43), "muzzle": Vector3(0, 0.105, -0.703)},
	"ak": {"mount": Vector3.ZERO, "support": Vector3(0, 0.055, -0.325), "muzzle": Vector3(0, 0.0764, -0.6253)}
}

static var sampled: Dictionary = {}
static var rigs: Dictionary = {}
static var full: Dictionary = {}
static var upper: Dictionary = {}
static var moves: Dictionary = {}
static var full_moves: Dictionary = {}
static var upper_moves: Dictionary = {}
static var falls: Dictionary = {}
static var materials: Dictionary = {}
static var grips: Dictionary = {}

var look := "viper"
var config: Dictionary
var rig: Dictionary
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var legs: AnimationPlayer
var arms: AnimationPlayer
var shift: Node3D
var holder: Node3D
var gun: Node3D
var flash: Node3D
var flash_left := 0.0
var model_scale := 1.0
var stride_scale := 1.0
## Set before the body enters the tree: it also gets the falls of DEATHS.
var mortal := false
## look -> the library of those falls.
static var deaths: Dictionary = {}
## "stand", "down", "rising", "roll", "rope" or "landing".
var mode := "stand"
## Seconds until a roll or a landing is over.
var busy_left := 0.0
## Kept low: behind cover, or while the weapon is being reloaded under fire.
var crouched := false
var throw_left := 0.0
var reload_left := 0.0
var reload_rate := 1.0
## Looking up (positive) or down, in radians; bends the spine.
var pitch := 0.0
var flinch := 0.0
var flinch_side := 1.0

func _ready() -> void:
	config = LOOKS[look]
	model_scale = float(config.height) / float(config.source_height)
	# Getting up starts where the body fell; `shift` carries that offset.
	shift = Node3D.new()
	shift.name = "Shift"
	add_child(shift)
	holder = Node3D.new()
	holder.name = "Model"
	# The source models face +Z; characters in this game face -Z.
	holder.rotation.y = PI
	holder.scale = Vector3.ONE * model_scale
	shift.add_child(holder)
	var imported := (config.scene as PackedScene).instantiate() as Node3D
	holder.add_child(imported)
	skeleton = InfectedVisual._find(imported, "Skeleton3D") as Skeleton3D
	mesh_instance = InfectedVisual._find(imported, "MeshInstance3D") as MeshInstance3D
	var bundled := InfectedVisual._find(imported, "AnimationPlayer")
	if bundled != null:
		bundled.free()
	if sampled.is_empty():
		sampled = InfectedVisual.sample(VIPER_RIG, CLIPS)
		moves = InfectedVisual.sample(SCORPION_RIG, MOVES)
	if not rigs.has(look):
		rigs[look] = InfectedVisual._analyse(skeleton)
		var layer: Array = [rigs[look].neck.index, rigs[look].head.index]
		for bone in rigs[look].spine:
			layer.append(bone.index)
		for arm in rigs[look].arms:
			for part in ["clav", "upper", "fore", "hand"]:
				layer.append(arm[part].index)
		full[look] = InfectedVisual._bake(skeleton, rigs[look], "", sampled)
		upper[look] = InfectedVisual._bake(skeleton, rigs[look], "", sampled, UPPER_CLIPS, layer)
		falls[look] = InfectedVisual._bake(skeleton, rigs[look], "zombie", {}, FALLS)
		full_moves[look] = InfectedVisual._bake(skeleton, rigs[look], "", moves)
		upper_moves[look] = InfectedVisual._bake(skeleton, rigs[look], "", moves, UPPER_MOVES, layer)
		materials[look] = _material()
	rig = rigs[look]
	stride_scale = float(rig.leg_length) / float(sampled.leg_length)
	mesh_instance.material_override = materials[look]
	legs = _player("Legs")
	legs.add_animation_library("", full[look])
	legs.add_animation_library("fall", falls[look])
	if mortal:
		if not deaths.has(look):
			deaths[look] = InfectedVisual._bake(skeleton, rig, "zombie", {}, DEATHS)
			InfectedVisual._add_more(deaths[look], skeleton, rig, "zombie", DEATHS)
		legs.add_animation_library("death", deaths[look])
	legs.add_animation_library("move", full_moves[look])
	arms = _player("Arms")
	arms.add_animation_library("", upper[look])
	arms.add_animation_library("move", upper_moves[look])
	_build_weapon()
	_fit_eyes()
	legs.play("idle")
	legs.seek(randf() * legs.current_animation_length, true)
	arms.play("idle")

## What the eyes of the operators glow with (see LOOKS, "eyes").
const EYE_GLOW := Color(0.45, 1.5, 3.4)

## Eyes that glow: a small bright ball at each, fixed to the head, and a faint light of the
## same colour on the face. Only for looks that say where their eyes are.
func _fit_eyes() -> void:
	if not config.has("eyes") or skeleton == null:
		return
	var head: int = rig.head.index
	var mount := BoneAttachment3D.new()
	mount.name = "Eyes"
	skeleton.add_child(mount)
	mount.bone_idx = head
	var rest := skeleton.get_bone_global_rest(head).affine_inverse()
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = EYE_GLOW
	var size := float(config.eyes.size)
	var middle := Vector3.ZERO
	for at in config.eyes.at:
		var ball := SphereMesh.new()
		ball.radius = size
		ball.height = size * 2.0
		ball.radial_segments = 10
		ball.rings = 5
		var eye := MeshInstance3D.new()
		eye.mesh = ball
		eye.material_override = paint
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mount.add_child(eye)
		# Flat against the face rather than a ball standing out of it.
		eye.transform = rest * Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.45)), at)
		middle += (at as Vector3) / float((config.eyes.at as Array).size())
	var glow := OmniLight3D.new()
	glow.light_color = Color("58b8ff")
	glow.light_energy = 0.55
	glow.omni_range = 0.7
	glow.shadow_enabled = false
	mount.add_child(glow)
	glow.transform = rest * Transform3D(Basis.IDENTITY, middle + Vector3(0, 0, 0.1))

func _player(title: String) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = title
	skeleton.get_parent().add_child(player)
	# Advanced by hand: first the legs, then the upper body on top, then the aim.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return player

func _material() -> StandardMaterial3D:
	# The Mixamo export carries no textures; the mesh keeps the UVs of the original model.
	var base: String = config.textures
	var built := StandardMaterial3D.new()
	# The newer models bring their colour map as a JPEG.
	built.albedo_texture = load(base + ("diffuse.png" if ResourceLoader.exists(base + "diffuse.png") else "diffuse.jpg"))
	built.normal_enabled = true
	built.normal_texture = load(base + "normal.png")
	built.roughness_texture = load(base + "roughness.png")
	built.metallic = 1.0
	built.metallic_texture = load(base + "metallic.png")
	return built

## Puts the weapon into the right hand so that, in the firing stance, it runs through
## both palms. The stance is the same for every clip, so it is worked out once per look.
func _build_weapon() -> void:
	if str(config.weapon) == "":
		# Empty hands: there is nothing to hold, only a place where a muzzle would be.
		flash = Node3D.new()
		flash.hide()
		add_child(flash)
		return
	var data: Dictionary = WEAPONS[config.weapon]
	var right_hand: int = rig.arms[0].hand.index
	var left_hand: int = rig.arms[1].hand.index
	# Arms are sorted by x; the model faces +Z, so its right hand is the one at -x.
	if not grips.has(look):
		legs.play("fire")
		legs.advance(0.0)
		var palms: Array[Vector3] = []
		for arm in rig.arms:
			var wrist := skeleton.get_bone_global_pose(arm.hand.index)
			var rest := skeleton.get_bone_global_rest(arm.hand.index)
			var reach := (rest.origin - skeleton.get_bone_global_rest(arm.fore.index).origin).normalized() * 0.085 / model_scale
			palms.append(wrist.origin + wrist.basis * (rest.basis.inverse() * reach))
		var along := (palms[1] - palms[0]).normalized()
		var aimed := Basis.looking_at(along, Vector3.UP) * Basis(Quaternion((data.support as Vector3).normalized(), Vector3.FORWARD))
		grips[look] = skeleton.get_bone_global_pose(right_hand).affine_inverse() * Transform3D(aimed, palms[0])
		legs.stop()
	var hand := BoneAttachment3D.new()
	hand.name = "RightHand"
	skeleton.add_child(hand)
	hand.bone_idx = right_hand
	gun = Node3D.new()
	gun.name = "Weapon"
	gun.transform = grips[look]
	hand.add_child(gun)
	var model: Node3D
	if config.weapon == "badger":
		model = BadgerVisual.create()
		model.scale = Vector3.ONE * WeaponView.BADGER_SCALE
	elif config.weapon == "shotgun":
		model = WeaponView.shotgun_model(false)
		(model.find_child("Shell", true, false) as Node3D).hide()
	elif config.weapon == "ak":
		model = WeaponView.build_ak_world()
	else:
		model = WeaponView.build_rifle_world()
	model.position = data.mount
	gun.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash = Node3D.new()
	flash.position = data.muzzle
	flash.add_child(WeaponView.build_flash(true))
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffd39b")
	glow.light_energy = 2.2
	glow.omni_range = 5.0
	flash.add_child(glow)
	flash.hide()
	gun.add_child(flash)

func muzzle_position() -> Vector3:
	return flash.global_position

func head_position() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(rig.head.index).origin

func _play(player: AnimationPlayer, clip: String, blend: float) -> void:
	if player.current_animation != clip:
		player.play(clip, blend)

## `velocity` is the real movement in world space. `aim` raises the weapon, `shooting`
## plays the recoil.
func animate(delta: float, velocity: Vector3, aim: bool, shooting: bool) -> void:
	flash_left -= delta
	flash.visible = flash_left > 0.0
	flinch = maxf(0.0, flinch - delta * 4.0)
	if mode == "roll" or mode == "landing":
		busy_left -= delta
		if busy_left <= 0.0:
			mode = "stand"
			legs.play("idle", 0.15)
			arms.play("idle", 0.15)
	if mode == "stand":
		var speed := Vector2(velocity.x, velocity.z).length()
		var forward := Vector3(-sin(global_rotation.y), 0, -cos(global_rotation.y))
		var paced := speed / (model_scale * stride_scale)
		var wanted := "idle"
		var rate := 1.0
		if speed > 0.25:
			var side := velocity.dot(Vector3(cos(global_rotation.y), 0, -sin(global_rotation.y)))
			if absf(side) > 0.75 * speed:
				wanted = "move/strafe_right" if side > 0.0 else "move/strafe_left"
			elif velocity.dot(forward) < -0.35 * speed:
				wanted = "back"
			elif crouched:
				wanted = "move/crouch_run"
			elif paced > 2.2 and not aim:
				wanted = "run"
			else:
				wanted = "walk"
			rate = clampf(paced / _clip_speed(wanted), 0.6, 1.9)
		elif crouched:
			wanted = "move/crouch"
		_play(legs, wanted, 0.2)
		legs.speed_scale = rate
		# Upper body: reloading beats throwing beats firing beats aiming beats whatever the
		# legs do. The sidestep and crouch clips have no weapon in them, so the weapon is
		# carried by the walking clip's upper body.
		var above := wanted
		var above_rate := rate
		if wanted.begins_with("move/"):
			above = "aim" if aim or crouched else "walk"
			above_rate = 1.0
		reload_left -= delta
		throw_left -= delta
		if throw_left > 0.0:
			above = "move/throw"
			above_rate = THROW_RATE
		elif reload_left > 0.0:
			above = "reload"
			above_rate = reload_rate
		elif shooting:
			above = "fire"
			above_rate = 1.0
		elif aim:
			above = "aim"
			above_rate = 1.0
		if str(config.weapon) == "":
			above = "move/calm"
			above_rate = 1.0
		_play(arms, above, 0.14)
		arms.speed_scale = above_rate
	legs.advance(delta)
	if mode != "stand":
		return
	arms.advance(delta)
	var bend := pitch + 0.25 * flinch
	if absf(bend) > 0.01 or flinch > 0.01:
		var spine: Array = rig.spine
		for bone in spine:
			_nudge(bone.index, Vector3(-bend, flinch_side * 0.3 * flinch, 0) / spine.size())

func _clip_speed(clip: String) -> float:
	if clip.begins_with("move/"):
		return float(moves.clips[clip.trim_prefix("move/")].speed)
	return float(sampled.clips[clip].speed)

## Throws itself forward into a roll that is over after `seconds`.
func roll(seconds: float) -> void:
	if mode != "stand":
		return
	mode = "roll"
	busy_left = seconds
	throw_left = 0.0
	flash.hide()
	legs.speed_scale = 1.0
	legs.play("move/roll", 0.06, float(moves.clips.roll.length) / maxf(0.2, seconds))

## The arm that does not hold the weapon lobs a grenade. Returns the seconds until it
## leaves the hand.
func throw() -> float:
	var length := float(moves.clips.throw.length)
	throw_left = length * (1.0 - THROW_FROM) / THROW_RATE
	arms.play("move/throw", 0.1, THROW_RATE)
	arms.seek(length * THROW_FROM, true)
	return length * (0.52 - THROW_FROM) / THROW_RATE

## Hangs on a rope, hand over hand, until land() is called.
func hang() -> void:
	mode = "rope"
	flash.hide()
	legs.speed_scale = 1.0
	legs.play("move/rope", 0.0)
	legs.seek(randf() * legs.current_animation_length, true)

## Lets go of the rope and takes the fall in the knees. Returns how long that takes.
func land() -> float:
	mode = "landing"
	busy_left = float(moves.clips.land.length) / 1.3
	legs.speed_scale = 1.0
	legs.play("move/land", 0.1, 1.3)
	return busy_left

## Rotates a bone in model space on top of whatever the clips just posed.
func _nudge(index: int, euler: Vector3) -> void:
	var global := skeleton.get_bone_global_pose(index).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * (global.inverse() * Quaternion.from_euler(euler) * global))

func shot() -> void:
	flash_left = 0.05
	flash.rotation.z = randf() * TAU

func hit(from_side: float) -> void:
	flinch = 1.0
	flinch_side = from_side

func reload(seconds: float) -> void:
	reload_left = seconds
	reload_rate = float(sampled.clips.reload.length) / maxf(0.3, seconds)

## Goes down and stays there until rise() is called. `clip`: one of FALLS or DEATHS; left
## out or unknown to this body, it falls on its face (`forward`) or on its back.
func fall(forward: bool = false, clip: String = "") -> void:
	mode = "down"
	reload_left = 0.0
	flash.hide()
	legs.speed_scale = 1.0
	var wanted := "fall/death_forward" if forward else "fall/death_back"
	for library in ["fall/", "death/"]:
		if clip != "" and legs.has_animation(library + clip):
			wanted = library + clip
	legs.play(wanted, 0.12, 1.25)

func _pelvis() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(rig.pelvis.index).origin

## Stands up where the body lies. Returns how long it takes; call settle() afterwards.
func rise() -> float:
	var before := _pelvis()
	mode = "rising"
	legs.speed_scale = 1.0
	legs.play("get_up", 0.0, RISE_RATE)
	legs.advance(0.0)
	var after := _pelvis()
	shift.global_position += Vector3(before.x - after.x, 0.0, before.z - after.z)
	return float(sampled.clips.get_up.length) / RISE_RATE

## Back on its feet: returns how far the body has to be moved so that it stands where
## the model is, and puts the model back onto the body.
func settle() -> Vector3:
	var offset := shift.global_position - global_position
	shift.position = Vector3.ZERO
	mode = "stand"
	legs.play("idle", 0.25)
	arms.play("idle", 0.25)
	return offset
