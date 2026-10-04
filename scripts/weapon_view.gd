class_name WeaponView
extends RefCounted
## First-person weapon models with gloved hands, authored in weapon space
## (-Z forward, +Y up, metres). Their materials use a narrow viewmodel field of view
## and a depth scale, so the weapon keeps its shape and never pokes through walls.

const VIEW_FOV := 52.0
const P90_SCALE := 0.2654
## The Honey Badger model is 1.9 units long; this makes it a 72 cm carbine.
const BADGER_SCALE := 0.379
const SHOTGUN_SCENE := "res://assets/models/shotgun.glb"
## Where the shotgun's pistol grip (its origin) sits in weapon space.
const SHOTGUN_MOUNT := Vector3(0, -0.09, 0.07)
const UMP_SCENE := "res://assets/models/ump.glb"
## Where the UMP's pistol grip (its origin) sits in weapon space.
const UMP_MOUNT := Vector3(0, -0.105, 0.075)
## Places on the UMP in metres from the middle of its grip (the model's SPEC.json):
## muzzle and half the barrel's width, top of the rail and where it begins and ends,
## where the second hand holds, the cocking handle, the way the magazine comes out and
## where its foot is.
const UMP := {
	"muzzle": Vector3(0, 0.1133, -0.3864), "bore": 0.0114, "rail": 0.1587, "rail_front": -0.1966, "rail_back": -0.0207,
	"support": Vector3(0, 0.1133, -0.29), "handle": Vector3(-0.0207, 0.1346, -0.2553),
	"magazine_out": Vector3(0, -0.9945, -0.1045), "magazine_foot": Vector3(0, -0.1202, -0.1984)
}
const AK_SCENE := "res://assets/models/ak47.glb"
## Where the AK's pistol grip (its origin) sits in weapon space.
const AK_MOUNT := Vector3(0, -0.07, 0.08)
## Guns that come as a model with a magazine of their own and take parts from the shop.
## Places are in metres from the middle of the pistol grip (the model's SPEC.json): the
## muzzle and half the barrel's width; rail: the top of what a sight is clamped to, optic:
## how far forward a sight sits there, irons: how high the iron sights stand; where the
## second hand holds; the cocking handle; the way the magazine comes out and where its
## foot is.
const GUNS := {
	"ump": {
		"scene": UMP_SCENE, "mount": UMP_MOUNT, "muzzle": Vector3(0, 0.1133, -0.3864), "bore": 0.0114,
		"rail": 0.1587, "optic": -0.075, "irons": 0.1866,
		"support": Vector3(0, 0.1133, -0.29), "handle": Vector3(-0.0207, 0.1346, -0.2553),
		"magazine_out": Vector3(0, -0.9945, -0.1045), "magazine_foot": Vector3(0, -0.1202, -0.1984)
	},
	"ak": {
		"scene": AK_SCENE, "mount": AK_MOUNT, "muzzle": Vector3(0, 0.0764, -0.6253), "bore": 0.0074,
		"rail": 0.1186, "optic": -0.105, "irons": 0.1339,
		"support": Vector3(0, 0.079, -0.33), "handle": Vector3(0.0398, 0.0926, -0.2084),
		"magazine_out": Vector3(0, -0.94, -0.34), "magazine_foot": Vector3(0, -0.1416, -0.2486)
	},
	# The M4A4, the starting rifle. Its iron sights are a node of their own ("Sights");
	# folding: they are laid down (hidden) when a sight is fitted, which then sits low on
	# the rail instead of above them. The hand works the bolt catch on the left.
	"rifle": {
		"scene": "res://assets/models/m4a4.glb", "mount": Vector3(0, -0.08, 0.08), "muzzle": Vector3(0, 0.13, -0.6123), "bore": 0.0125,
		"rail": 0.1747, "optic": -0.125, "irons": 0.2105, "folding": true,
		"support": Vector3(0, 0.119, -0.3251), "handle": Vector3(-0.022, 0.1697, -0.0066),
		"magazine_out": Vector3(0, -0.9724, -0.2334), "magazine_foot": Vector3(0.0016, -0.0745, -0.2086)
	},
	# The machine gun: fed from a box that hangs under it on the left, which comes off
	# sideways; the cocking handle is on the right.
	"mg": {
		"scene": "res://assets/models/mg.glb", "mount": Vector3(0, -0.085, 0.085), "muzzle": Vector3(0.0005, 0.1217, -0.6683), "bore": 0.0109,
		"rail": 0.17, "optic": -0.15, "irons": 0.1897, "metal": 0.85, "rough": 0.5,
		"support": Vector3(0, 0.0907, -0.3539), "handle": Vector3(0.0377, 0.1327, -0.1011),
		"magazine_out": Vector3(-0.4512, -0.8924, 0.0), "magazine_foot": Vector3(-0.008, -0.053, -0.18)
	}
}
## The glass of the reflex sight (width, height) and how far behind it the eye is when
## aiming; how far behind the eyepiece of the telescopic sight.
const REFLEX_GLASS := Vector2(0.05, 0.04)
const REFLEX_EYE := 0.165
const SCOPE_EYE := 0.07
## How far a suppressor moves the muzzle forward.
const SILENCER_LENGTH := 0.15
const GLOVE := Color("272a29")
const GLOVE_PAD := Color("2e3130")
const SLEEVE := Color("343b2c")

## Hip and aimed positions are in camera space; angles are degrees.
const VIEWS := {
	# The M4A4 (build_gun): aimed, the eye is on the line through its aperture and its front
	# post, 13 cm behind the aperture.
	"rifle": {
		"hip": Vector3(0.12, -0.155, -0.35), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.1305, -0.1735), "muzzle": Vector3(0, 0.05, -0.5323),
		"reload_low": Vector3(-0.02, 0.05, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	},
	# The machine gun (build_gun), aimed over its aperture and ringed front post.
	"mg": {
		"hip": Vector3(0.13, -0.17, -0.33), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.1047, -0.207), "muzzle": Vector3(0.0005, 0.0367, -0.5833),
		"reload_low": Vector3(-0.02, 0.06, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	},
	"p90": {
		"hip": Vector3(0.135, -0.15, -0.38), "hip_angles": Vector3(1.0, 7.5, -2.5),
		"aim": Vector3(0.0, -0.0725, -0.4), "muzzle": Vector3(0, 0.0154, -0.262)
	},
	"badger": {
		"hip": Vector3(0.13, -0.158, -0.5), "hip_angles": Vector3(0.5, 6.5, -2.5),
		"aim": Vector3(0.0, -0.062, -0.25), "muzzle": Vector3(0, 0.012, -0.412)
	},
	"shotgun": {
		"hip": Vector3(0.13, -0.165, -0.4), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.0525, -0.31), "muzzle": Vector3(0, 0.015, -0.633)
	},
	# The six below come as finished models (see MODELS): aim puts the model's sight line
	# on the middle of the screen, muzzle is mount + the model's muzzle.
	"pistol": {
		"hip": Vector3(0.11, -0.13, -0.5), "hip_angles": Vector3(0.5, 5.0, -2.0),
		"aim": Vector3(0.0, -0.0258, -0.511), "muzzle": Vector3(0, 0.005, -0.1035)
	},
	"revolver": {
		"hip": Vector3(0.11, -0.13, -0.5), "hip_angles": Vector3(0.5, 5.0, -2.0),
		"aim": Vector3(0.0, -0.0395, -0.4875), "muzzle": Vector3(0, 0.011, -0.161)
	},
	"autoshotgun": {
		"hip": Vector3(0.13, -0.165, -0.38), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.0562, -0.34), "muzzle": Vector3(0, 0.008, -0.428)
	},
	"sniper": {
		"hip": Vector3(0.13, -0.17, -0.36), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.046, -0.115), "muzzle": Vector3(0, -0.01, -0.687)
	},
	# The launcher is not aimed over its sight: it stays beside the line of sight, so that
	# the arc of its shell can be seen (see Survivor.launch_path).
	"launcher": {
		"hip": Vector3(0.14, -0.2, -0.36), "hip_angles": Vector3(1.0, 6.5, -2.5),
		"aim": Vector3(0.115, -0.185, -0.4), "aim_angles": Vector3(0.5, 5.0, -2.0), "muzzle": Vector3(0, 0.06, -0.348)
	},
	"minigun": {
		"hip": Vector3(0.2, -0.3, -0.46), "hip_angles": Vector3(2.0, 8.0, -3.0),
		"aim": Vector3(0.1, -0.28, -0.46), "muzzle": Vector3(0, -0.005, -0.782)
	},
	# The five below are models from MODELS as well. The M14 and the double rifle are aimed
	# over their iron sights: the eye is on the line through rear and front sight, 12 cm
	# behind the M14's aperture and 33 cm behind the double rifle's V, which stands far out
	# on its rib. The SVD and the .50 are looked through; the flamethrower is not aimed at
	# all and stays beside the line of sight, like the launcher.
	"m14": {
		"hip": Vector3(0.125, -0.135, -0.36), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.044, -0.0948), "muzzle": Vector3(0, 0.01, -0.676)
	},
	"svd": {
		"hip": Vector3(0.13, -0.18, -0.35), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.074, -0.152), "muzzle": Vector3(0, 0.002, -0.808)
	},
	"flamer": {
		"hip": Vector3(0.15, -0.18, -0.32), "hip_angles": Vector3(1.0, 6.5, -2.5),
		"aim": Vector3(0.1, -0.17, -0.34), "aim_angles": Vector3(0.5, 4.0, -2.0), "muzzle": Vector3(0, -0.008, -0.704)
	},
	"nitro": {
		"hip": Vector3(0.125, -0.135, -0.36), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.0325, -0.131), "muzzle": Vector3(0, 0.004, -0.688),
		# Held level and rolled a little while it is loaded, so that the open breech shows.
		"reload_low": Vector3(-0.03, -0.03, 0.05), "reload_turn": Vector3(0.08, 0.3, -0.45)
	},
	"fifty": {
		"hip": Vector3(0.14, -0.2, -0.34), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.1286, -0.132), "muzzle": Vector3(0, 0.027, -0.868)
	},
	# The UMP has a view of its own (build_ump). aim_angles: its sight line climbs a little
	# towards the muzzle, so the weapon is tipped by that much when aiming over the irons.
	# reload_low and reload_turn: how the weapon is held while its magazine is changed -
	# raised and rolled over, so that the magazine well can be seen.
	"ump": {
		"hip": Vector3(0.13, -0.162, -0.4), "hip_angles": Vector3(0.5, 6.5, -2.5),
		"aim": Vector3(0.0, -0.0702, -0.3), "aim_angles": Vector3(-0.76, 0.0, 0.0), "muzzle": Vector3(0, 0.0083, -0.3114),
		"reload_low": Vector3(-0.02, 0.07, 0.03), "reload_turn": Vector3(0.4, 0.28, -0.87)
	},
	# The AK-47 (build_gun). Its iron sights stand on the handguard block and at the muzzle;
	# the eye looks along the top of the receiver.
	"ak": {
		"hip": Vector3(0.115, -0.148, -0.33), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.0612, -0.19), "aim_angles": Vector3(-0.73, 0.0, 0.0), "muzzle": Vector3(0, 0.0064, -0.5453),
		"reload_low": Vector3(-0.02, 0.05, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	}
}
## Weapons that come as finished models. mount: where the model's origin (the middle of
## its pistol grip) sits in weapon space. support: where the second hand holds, measured
## on the model. hands: "cup" wraps it round the firing hand, "cradle" lays it under a
## handguard, "grip" closes it round a foregrip or handle.
const MODELS := {
	"pistol": {"scene": "res://assets/models/pistol.glb", "mount": Vector3(0, -0.075, 0.076), "support": Vector3(-0.004, -0.033, 0.0145), "hands": "cup"},
	"revolver": {"scene": "res://assets/models/revolver.glb", "mount": Vector3(0, -0.075, 0.076), "support": Vector3(-0.004, -0.04, 0.0), "hands": "cup"},
	"autoshotgun": {"scene": "res://assets/models/autoshotgun.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.056, -0.273), "hands": "cradle"},
	"sniper": {"scene": "res://assets/models/sniper.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.034, -0.355), "hands": "cradle"},
	"launcher": {"scene": "res://assets/models/launcher.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, -0.026, -0.2045), "hands": "grip"},
	"minigun": {"scene": "res://assets/models/minigun.glb", "mount": Vector3(0, -0.12, 0.05), "support": Vector3(0, 0.251, -0.142), "hands": "grip"},
	"m14": {"scene": "res://assets/models/m14.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0811, -0.341), "hands": "cradle"},
	"svd": {"scene": "res://assets/models/svd.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0928, -0.438), "hands": "cradle"},
	"flamer": {"scene": "res://assets/models/flamethrower.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.007, -0.437), "hands": "grip"},
	# open: the double rifle breaks open to be loaded; its barrels turn about their hinge
	# (the node "Barrels") by this many degrees.
	"nitro": {"scene": "res://assets/models/double_rifle.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0829, -0.308), "hands": "cradle", "open": -28.0},
	"fifty": {"scene": "res://assets/models/heavy_sniper.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0895, -0.378), "hands": "cradle"}
}

static var materials: Dictionary = {}
static var p90_material: BaseMaterial3D
static var badger_material: BaseMaterial3D
static var gun_materials: Dictionary = {}
## The AK-47 as soldiers carry it: a small copy of the model. Loaded once and kept.
const AK_LOW_SCENE := "res://assets/models/ak47_low.glb"
static var ak_low: PackedScene
static var shotgun_materials: Dictionary = {}
static var grain: NoiseTexture2D

static func tune(target: BaseMaterial3D) -> BaseMaterial3D:
	target.use_fov_override = true
	target.fov_override = VIEW_FOV
	target.use_z_clip_scale = true
	target.z_clip_scale = 0.3
	return target

## `world` materials are for weapons seen from outside: no viewmodel projection.
static func shared(key: String, world: bool = false) -> StandardMaterial3D:
	var slot := key + ("_world" if world else "")
	if materials.has(slot):
		return materials[slot]
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.85
	if key == "steel":
		result.roughness = 0.48
		result.metallic = 0.35
	elif key == "polymer":
		result.roughness = 0.62
	if not world:
		tune(result)
	materials[slot] = result
	return result

## Tapered limb segment between two points, with a rounded joint at its start.
static func _segment(batch: MeshBatch, key: String, from: Vector3, to: Vector3, start_radius: float, end_radius: float, color: Color, sides: int = 8) -> void:
	var span := to - from
	batch.cylinder(shared(key), from, start_radius, end_radius, span.length(), color, sides, Basis(Quaternion(Vector3.UP, span.normalized())))
	batch.ellipsoid(shared(key), from, Vector3.ONE * start_radius, color, Basis.IDENTITY, sides, 5)

static func _finger(batch: MeshBatch, knuckle: Vector3, joint: Vector3, tip: Vector3) -> void:
	_segment(batch, "glove", knuckle, joint, 0.0108, 0.0098, GLOVE)
	_segment(batch, "glove", joint, tip, 0.0098, 0.0086, GLOVE)
	batch.ellipsoid(shared("glove"), tip, Vector3.ONE * 0.0088, GLOVE, Basis.IDENTITY, 8, 5)
	batch.ellipsoid(shared("glove"), knuckle, Vector3(0.0125, 0.012, 0.0125), GLOVE_PAD, Basis.IDENTITY, 8, 5)

static func _forearm(batch: MeshBatch, palm: Vector3, wrist: Vector3, reach: Vector3) -> void:
	_segment(batch, "glove", palm, wrist, 0.03, 0.033, GLOVE)
	_segment(batch, "glove", wrist, wrist + reach * 0.09, 0.037, 0.039, GLOVE_PAD)
	_segment(batch, "sleeve", wrist + reach * 0.07, wrist + reach, 0.04, 0.052, SLEEVE, 10)

## Gloved hand gripping a post-shaped grip around `grip`. `side` is +1 for the right hand.
static func _grip_hand(batch: MeshBatch, grip: Vector3, side: float, trigger_finger: bool, reach: Vector3) -> void:
	# Back of the hand lies along the outside of the grip.
	batch.ellipsoid(shared("glove"), grip + Vector3(side * 0.03, -0.004, 0.008), Vector3(0.017, 0.045, 0.04), GLOVE, Basis.from_euler(Vector3(0.12, 0, side * -0.1)), 10, 6)
	for finger in range(4):
		var drop := 0.03 - finger * 0.021
		var knuckle := grip + Vector3(side * 0.028, drop, -0.024)
		var joint := grip + Vector3(side * 0.006, drop - 0.002, -0.043)
		var tip := grip + Vector3(side * -0.021, drop - 0.003, -0.03)
		if finger == 0 and trigger_finger:
			# The index finger rests along the frame towards the trigger.
			joint = grip + Vector3(side * 0.027, drop + 0.004, -0.05)
			tip = grip + Vector3(side * 0.02, drop + 0.003, -0.074)
		_finger(batch, knuckle, joint, tip)
	var thumb_base := grip + Vector3(side * 0.024, 0.036, 0.026)
	var thumb_joint := grip + Vector3(side * 0.002, 0.044, 0.02)
	var thumb_tip := grip + Vector3(side * -0.02, 0.04, 0.008)
	_segment(batch, "glove", thumb_base, thumb_joint, 0.0125, 0.011, GLOVE)
	_segment(batch, "glove", thumb_joint, thumb_tip, 0.011, 0.0095, GLOVE)
	batch.ellipsoid(shared("glove"), thumb_tip, Vector3.ONE * 0.0098, GLOVE, Basis.IDENTITY, 8, 5)
	_forearm(batch, grip + Vector3(side * 0.031, -0.02, 0.03), grip + Vector3(side * 0.036, -0.048, 0.052), reach)

## Support hand cradling a round handguard from below.
static func _cradle_hand(batch: MeshBatch, grip: Vector3, reach: Vector3) -> void:
	batch.ellipsoid(shared("glove"), grip + Vector3(-0.004, -0.042, 0.0), Vector3(0.04, 0.014, 0.046), GLOVE, Basis.from_euler(Vector3(0, 0, 0.12)), 10, 6)
	for finger in range(4):
		var along := -0.036 + finger * 0.023
		_finger(batch, grip + Vector3(0.032, -0.034, along), grip + Vector3(0.043, -0.004, along - 0.003), grip + Vector3(0.03, 0.022, along - 0.004))
	var thumb_joint := grip + Vector3(-0.043, -0.002, 0.0)
	var thumb_tip := grip + Vector3(-0.034, 0.02, -0.02)
	_segment(batch, "glove", grip + Vector3(-0.034, -0.03, 0.018), thumb_joint, 0.0125, 0.011, GLOVE)
	_segment(batch, "glove", thumb_joint, thumb_tip, 0.011, 0.0095, GLOVE)
	batch.ellipsoid(shared("glove"), thumb_tip, Vector3.ONE * 0.0098, GLOVE, Basis.IDENTITY, 8, 5)
	_forearm(batch, grip + Vector3(-0.006, -0.046, 0.036), grip + Vector3(-0.018, -0.052, 0.07), reach)

static func _finish(view: Node3D, batch: MeshBatch) -> void:
	for mesh in batch.commit(view, "Part", false):
		mesh.layers = 2
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = VIEWS[String(view.name)].muzzle
	view.add_child(muzzle)

static func build_p90() -> Node3D:
	var view := Node3D.new()
	view.name = "p90"
	var mount := P90Visual.create()
	mount.scale = Vector3.ONE * (P90_SCALE / 0.34)
	view.add_child(mount)
	for node in mount.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if p90_material == null:
			p90_material = tune(mesh.mesh.surface_get_material(0).duplicate() as BaseMaterial3D)
		mesh.material_override = p90_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = 2
	var batch := MeshBatch.new()
	# Firing hand on the grip behind the trigger, support hand on the front grip.
	_grip_hand(batch, Vector3(0.0, -0.046, -0.036), 1.0, true, Vector3(0.1, -0.24, 0.24))
	_grip_hand(batch, Vector3(0.0, -0.056, -0.129), -1.0, false, Vector3(-0.15, -0.24, 0.2))
	_finish(view, batch)
	return view

## Suppressed carbine: pistol grip in the firing hand, the support hand under the handguard.
static func build_badger() -> Node3D:
	var view := Node3D.new()
	view.name = "badger"
	var mount := BadgerVisual.create()
	mount.scale = Vector3.ONE * BADGER_SCALE
	# Puts the barrel axis and the pistol grip where the rifle has them.
	mount.position = Vector3(0, -0.1597, -0.0491)
	view.add_child(mount)
	if badger_material == null:
		badger_material = tune(BadgerVisual.material().duplicate() as BaseMaterial3D)
	for node in mount.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = badger_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = 2
	var batch := MeshBatch.new()
	_grip_hand(batch, Vector3(0.0, -0.09, 0.076), 1.0, true, Vector3(0.1, -0.24, 0.22))
	_cradle_hand(batch, Vector3(0.0, 0.012, -0.15), Vector3(-0.13, -0.27, 0.17))
	_finish(view, batch)
	return view

## The shotgun's surfaces are plain colours; a fine grain keeps them from looking like
## plastic toys. `view` materials are for the first-person weapon.
static func shotgun_material(source: Material, view: bool, family: String = "") -> BaseMaterial3D:
	var slot := family + source.resource_name + ("_view" if view else "")
	if shotgun_materials.has(slot):
		return shotgun_materials[slot]
	if grain == null:
		var noise := FastNoiseLite.new()
		noise.seed = 41
		noise.frequency = 0.09
		noise.fractal_octaves = 3
		grain = NoiseTexture2D.new()
		grain.width = 256
		grain.height = 256
		grain.seamless = true
		grain.as_normal_map = true
		grain.bump_strength = 1.6
		grain.noise = noise
	var result := source.duplicate() as BaseMaterial3D
	result.normal_enabled = true
	result.normal_texture = grain
	result.normal_scale = 0.3 if result.metallic > 0.5 else 0.22
	result.uv1_triplanar = true
	result.uv1_scale = Vector3.ONE * 14.0
	if view:
		tune(result)
	shotgun_materials[slot] = result
	return result

## The shotgun as a scene: nodes Body, Pump and Shell under "Shotgun".
static func shotgun_model(view: bool) -> Node3D:
	var model := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Node3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(surface, shotgun_material(mesh.mesh.surface_get_material(surface), view, "shotgun/"))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if view:
			mesh.layers = 2
	return model

## Pump-action shotgun. The forend and the hand on it sit under "Slide", which the
## player moves back and forth to work the action.
static func build_shotgun() -> Node3D:
	var view := Node3D.new()
	view.name = "shotgun"
	var model := shotgun_model(true)
	model.position = SHOTGUN_MOUNT
	view.add_child(model)
	(model.find_child("Shell", true, false) as Node3D).hide()
	var slide := Node3D.new()
	slide.name = "Slide"
	view.add_child(slide)
	var pump := model.find_child("Pump", true, false) as Node3D
	pump.owner = null
	pump.get_parent().remove_child(pump)
	slide.add_child(pump)
	pump.position += SHOTGUN_MOUNT
	var support := MeshBatch.new()
	_cradle_hand(support, SHOTGUN_MOUNT + Vector3(0, 0.075, -0.45), Vector3(-0.13, -0.27, 0.17))
	for mesh in support.commit(slide, "Hand", false):
		mesh.layers = 2
	var batch := MeshBatch.new()
	_grip_hand(batch, SHOTGUN_MOUNT, 1.0, true, Vector3(0.1, -0.24, 0.22))
	_finish(view, batch)
	return view

## A weapon from MODELS as a scene, with the game's materials on it.
static func model_scene(id: String, view: bool) -> Node3D:
	var model := (load(str(MODELS[id].scene)) as PackedScene).instantiate() as Node3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(surface, shotgun_material(mesh.mesh.surface_get_material(surface), view, id + "/"))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if view:
			mesh.layers = 2
	return model

## The first-person view of a weapon from MODELS: the model and the hands that hold it.
static func build_model(id: String) -> Node3D:
	var info: Dictionary = MODELS[id]
	var view := Node3D.new()
	view.name = id
	var mount: Vector3 = info.mount
	var model := model_scene(id, true)
	model.position = mount
	view.add_child(model)
	var batch := MeshBatch.new()
	_grip_hand(batch, mount, 1.0, true, Vector3(0.1, -0.24, 0.22))
	var hold: Vector3 = mount + (info.support as Vector3)
	match str(info.hands):
		"cup":
			_grip_hand(batch, mount + Vector3(-0.014, -0.012, 0.004), -1.0, false, Vector3(-0.16, -0.22, 0.2))
		"cradle":
			_cradle_hand(batch, hold, Vector3(-0.13, -0.27, 0.17))
		_:
			_grip_hand(batch, hold, -1.0, false, Vector3(-0.15, -0.24, 0.2))
	_finish(view, batch)
	return view

## A gun from GUNS. Its magazine really leaves the weapon: the magazine and the hand that
## changes it hang under nodes of their own ("Magazine", "Support"), which the player moves
## during a reload (see reload_step). The parts that can be fitted are built here as
## "Mod_reddot", "Mod_scope" and "Mod_silencer" and stay hidden until they are bought.
static func build_gun(id: String) -> Node3D:
	var gun: Dictionary = GUNS[id]
	var mount: Vector3 = gun.mount
	var view := Node3D.new()
	view.name = id
	var model := (load(str(gun.scene)) as PackedScene).instantiate() as Node3D
	model.position = mount
	view.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			# The gun brings its own textures; the magazine is plain and gets the grain of
			# the other models.
			if source.albedo_texture != null:
				if not gun_materials.has(id):
					gun_materials[id] = tune(source.duplicate() as BaseMaterial3D)
					# A gun whose paint came out like polished chrome is taken down a little.
					if gun.has("metal"):
						(gun_materials[id] as BaseMaterial3D).metallic = float(gun.metal)
					if gun.has("rough"):
						(gun_materials[id] as BaseMaterial3D).roughness_texture = null
						(gun_materials[id] as BaseMaterial3D).roughness = float(gun.rough)
				mesh.set_surface_override_material(surface, gun_materials[id])
			else:
				mesh.set_surface_override_material(surface, shotgun_material(source, true, id + "/"))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = 2
	var clip := Node3D.new()
	clip.name = "Magazine"
	view.add_child(clip)
	var magazine := model.find_child("Magazine", true, false) as Node3D
	magazine.owner = null
	magazine.get_parent().remove_child(magazine)
	clip.add_child(magazine)
	magazine.position += mount
	var hand := Node3D.new()
	hand.name = "Support"
	view.add_child(hand)
	var support := MeshBatch.new()
	_cradle_hand(support, mount + (gun.support as Vector3), Vector3(-0.13, -0.27, 0.17))
	for mesh in support.commit(hand, "Hand", false):
		mesh.layers = 2
	_gun_mods(view, id)
	var batch := MeshBatch.new()
	_grip_hand(batch, mount, 1.0, true, Vector3(0.1, -0.24, 0.22))
	_finish(view, batch)
	return view

static func build_ump() -> Node3D:
	return build_gun("ump")

static func build_ak_world() -> Node3D:
	if ak_low == null:
		ak_low = load(AK_LOW_SCENE) as PackedScene
	return ak_low.instantiate() as Node3D

## A material for small things that shine or let light through on the viewmodel.
static func _view_glow(key: String, color: Color, additive: bool) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.albedo_color = color
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		var spot := GradientTexture2D.new()
		spot.gradient = ramp
		spot.fill = GradientTexture2D.FILL_RADIAL
		spot.fill_from = Vector2(0.5, 0.5)
		spot.fill_to = Vector2(0.5, 0.0)
		spot.width = 32
		spot.height = 32
		result.albedo_texture = spot
	materials[key] = tune(result)
	return result

static func _view_quad(parent: Node3D, at: Vector3, size: Vector2, material: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.position = at
	node.layers = 2
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

## A thin glowing ring for the reflex sight.
static func _view_ring(key: String, color: Color) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.albedo_color = color
	var band := Gradient.new()
	band.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	band.offsets = PackedFloat32Array([0.0, 0.85, 0.895, 0.94, 1.0])
	var circle := GradientTexture2D.new()
	circle.gradient = band
	circle.fill = GradientTexture2D.FILL_RADIAL
	circle.fill_from = Vector2(0.5, 0.5)
	circle.fill_to = Vector2(0.5, 0.0)
	circle.width = 96
	circle.height = 96
	result.albedo_texture = circle
	materials[key] = tune(result)
	return result

## How high the middle of a sight's glass stands above the gun's origin: clear of the iron
## sights, so that they do not stand in the picture.
static func sight_height(id: String, sight: String) -> float:
	var gun: Dictionary = GUNS[id]
	# Iron sights that fold away leave nothing for a sight to clear.
	var clear := (0.0 if gun.get("folding", false) else maxf(float(gun.irons) - float(gun.rail), 0.0)) + 0.006
	return float(gun.rail) + clear + (REFLEX_GLASS.y * 0.5 if sight == "reddot" else 0.0195)

## Where the weapon sits when the eye is behind a fitted sight.
static func sight_aim(id: String, sight: String) -> Vector3:
	var gun: Dictionary = GUNS[id]
	var mount: Vector3 = gun.mount
	var along := mount.z + float(gun.optic)
	if sight == "reddot":
		return Vector3(0.0, -(mount.y + sight_height(id, sight)), -REFLEX_EYE - (along - 0.019))
	return Vector3(0.0, -(mount.y + sight_height(id, sight)), -SCOPE_EYE - (along + 0.066))

## The parts the shop sells for a gun, each under a node of its own.
static func _gun_mods(view: Node3D, id: String) -> void:
	var gun: Dictionary = GUNS[id]
	var mount: Vector3 = gun.mount
	var rail := mount.y + float(gun.rail)
	var z := mount.z + float(gun.optic)
	var dark := Color("15171a")
	var metal := Color("23262a")
	var steel := shared("steel")
	var ahead := Basis(Quaternion(Vector3.UP, Vector3.FORWARD))
	# --- Reflex sight: a wide glass in a thin frame on a riser, close to the eye. A dot in
	# a ring sits in the middle of the glass.
	var reflex := Node3D.new()
	reflex.name = "Mod_reddot"
	view.add_child(reflex)
	var dot := mount.y + sight_height(id, "reddot")
	var half := REFLEX_GLASS * 0.5
	var sill := dot - half.y - 0.002
	var batch := MeshBatch.new()
	var black := Color("0b0c0e")
	batch.box(steel, Vector3(0, rail + 0.005, z), Vector3(0.03, 0.01, 0.046), black)
	batch.box(steel, Vector3(0, (rail + 0.01 + sill) * 0.5, z - 0.004), Vector3(0.016, maxf(0.004, sill - rail - 0.01), 0.022), black)
	batch.box(steel, Vector3(0, sill, z - 0.015), Vector3(REFLEX_GLASS.x + 0.0054, 0.003, 0.014), black)
	for side in [-1.0, 1.0]:
		batch.box(steel, Vector3(side * (half.x + 0.0014), dot, z - 0.019), Vector3(0.0018, REFLEX_GLASS.y + 0.002, 0.005), black)
	batch.box(steel, Vector3(0, dot + half.y + 0.0009, z - 0.019), Vector3(REFLEX_GLASS.x + 0.0046, 0.0018, 0.005), black)
	for mesh in batch.commit(reflex, "Part", false):
		mesh.layers = 2
	_view_quad(reflex, Vector3(0, dot, z - 0.019), REFLEX_GLASS, _view_glow("lens", Color(0.55, 0.75, 0.8, 0.045), false))
	# The mark is small and dim on purpose: a fine dot that does not cover the target, in a
	# hair-thin ring that is only just there.
	_view_quad(reflex, Vector3(0, dot, z - 0.0188), Vector2(0.0082, 0.0082), _view_ring("ring", Color(1.0, 0.1, 0.06, 0.22)))
	_view_quad(reflex, Vector3(0, dot, z - 0.0187), Vector2(0.0015, 0.0015), _view_glow("dot", Color(1.35, 0.12, 0.07, 1.0), true))
	# --- Telescopic sight, four times: tube, bell and eyepiece on two rings.
	var scope := Node3D.new()
	scope.name = "Mod_scope"
	view.add_child(scope)
	var axis := mount.y + sight_height(id, "scope")
	batch = MeshBatch.new()
	batch.cylinder(steel, Vector3(0, axis, z + 0.05), 0.0165, 0.0165, 0.032, dark, 14, ahead)
	batch.cylinder(steel, Vector3(0, axis, z + 0.018), 0.0165, 0.0125, 0.008, dark, 14, ahead)
	batch.cylinder(steel, Vector3(0, axis, z + 0.012), 0.0125, 0.0125, 0.1, metal, 14, ahead)
	batch.cylinder(steel, Vector3(0, axis, z - 0.088), 0.0125, 0.019, 0.022, dark, 14, ahead)
	batch.cylinder(steel, Vector3(0, axis, z - 0.11), 0.019, 0.019, 0.03, dark, 14, ahead)
	# Turrets on top and on the right, and the two rings that clamp it to the rail.
	batch.cylinder(steel, Vector3(0, axis + 0.011, z - 0.03), 0.0085, 0.0085, 0.014, metal, 10)
	batch.cylinder(steel, Vector3(0.011, axis, z - 0.03), 0.0085, 0.0085, 0.014, metal, 10, Basis(Quaternion(Vector3.UP, Vector3.RIGHT)))
	for along in [-0.064, 0.0]:
		batch.box(steel, Vector3(0, rail + (axis - rail) * 0.5 - 0.004, z + along), Vector3(0.016, axis - rail, 0.014), metal)
		batch.box(steel, Vector3(0, axis, z + along), Vector3(0.031, 0.031, 0.012), dark)
		batch.box(steel, Vector3(0, rail + 0.004, z + along), Vector3(0.036, 0.01, 0.018), dark)
	# Dark glass at both ends.
	batch.cylinder(steel, Vector3(0, axis, z + 0.0495), 0.0145, 0.0145, 0.001, Color("05080c"), 14, ahead)
	batch.cylinder(steel, Vector3(0, axis, z - 0.1385), 0.017, 0.017, 0.001, Color("0a1422"), 14, ahead)
	for mesh in batch.commit(scope, "Part", false):
		mesh.layers = 2
	# --- Suppressor: screwed on over the muzzle.
	var can := Node3D.new()
	can.name = "Mod_silencer"
	view.add_child(can)
	var muzzle: Vector3 = mount + (gun.muzzle as Vector3)
	batch = MeshBatch.new()
	batch.cylinder(steel, muzzle + Vector3(0, 0, 0.02), 0.0145, 0.0145, 0.022, metal, 14, ahead)
	batch.cylinder(steel, muzzle + Vector3(0, 0, 0.002), 0.0192, 0.0192, SILENCER_LENGTH, dark, 14, ahead)
	for ring in [0.03, 0.06, 0.09, 0.12]:
		batch.cylinder(steel, muzzle + Vector3(0, 0, -float(ring)), 0.0198, 0.0198, 0.004, metal, 14, ahead)
	batch.cylinder(steel, muzzle + Vector3(0, 0, 0.002 - SILENCER_LENGTH), 0.0192, 0.016, 0.006, metal, 14, ahead)
	batch.cylinder(steel, muzzle + Vector3(0, 0, -0.0045 - SILENCER_LENGTH), 0.0062, 0.0062, 0.001, Color("020202"), 10, ahead)
	for mesh in batch.commit(can, "Part", false):
		mesh.layers = 2
	for part in [reflex, scope, can]:
		(part as Node3D).hide()

## Where the magazine and the hand that changes it are at a moment of the reload (0 to 1),
## as offsets from where they rest.
static func reload_step(id: String, done: float) -> Dictionary:
	if not GUNS.has(id) or done <= 0.0 or done >= 1.0:
		return {"magazine": Vector3.ZERO, "hand": Vector3.ZERO}
	var gun: Dictionary = GUNS[id]
	var out: Vector3 = (gun.magazine_out as Vector3) * 0.25
	var rest: Vector3 = gun.support
	var foot: Vector3 = (gun.magazine_foot as Vector3) + Vector3(0.0, 0.035, 0.004) - rest
	var handle: Vector3 = (gun.handle as Vector3) + Vector3(-0.016, 0.034, 0.0) - rest
	# The hand lets go of the handguard and takes the magazine by its foot, pulls it out
	# and down, comes back with a full one ...
	var grab := smoothstep(0.0, 0.13, done) * (1.0 - smoothstep(0.66, 0.8, done))
	var pull := smoothstep(0.14, 0.3, done) * (1.0 - smoothstep(0.46, 0.64, done))
	# ... and slaps the cocking handle on its way back to the handguard.
	var up := smoothstep(0.66, 0.8, done) * (1.0 - smoothstep(0.9, 1.0, done))
	var slap := smoothstep(0.8, 0.86, done) * (1.0 - smoothstep(0.86, 0.94, done))
	return {"magazine": out * pull, "hand": foot * grab + out * pull + handle * up + Vector3(0.0, -0.022, 0.05) * slap}

## The starting carbine is built from primitives until it gets a model of its own.
static func build_rifle() -> Node3D:
	var view := Node3D.new()
	view.name = "rifle"
	var batch := MeshBatch.new()
	_rifle_parts(batch, false)
	_grip_hand(batch, Vector3(0.0, -0.075, 0.076), 1.0, true, Vector3(0.1, -0.24, 0.22))
	_cradle_hand(batch, Vector3(0.0, 0.012, -0.25), Vector3(-0.13, -0.27, 0.17))
	_finish(view, batch)
	return view

## The same carbine without hands, as carried by a soldier seen from outside.
static func build_rifle_world() -> Node3D:
	var view := Node3D.new()
	view.name = "RifleModel"
	var batch := MeshBatch.new()
	_rifle_parts(batch, true)
	batch.commit(view, "Part", false)
	return view

static func _rifle_parts(batch: MeshBatch, world: bool) -> void:
	var metal := shared("steel", world)
	var plastic := shared("polymer", world)
	var steel := Color("202326")
	var worn := Color("2d3134")
	var polymer := Color("191b1c")
	var dark := Color("0d0e0f")
	var forward := Basis(Vector3.RIGHT, -PI / 2)
	# Upper and lower receiver with a flat-top rail.
	batch.box(metal, Vector3(0, 0.012, -0.02), Vector3(0.04, 0.05, 0.23), steel)
	batch.box(metal, Vector3(0, -0.028, 0.0), Vector3(0.036, 0.034, 0.17), worn)
	batch.box(metal, Vector3(0, 0.043, -0.03), Vector3(0.022, 0.012, 0.22), steel)
	for notch in range(14):
		batch.box(metal, Vector3(0, 0.0515, -0.133 + notch * 0.0158), Vector3(0.024, 0.005, 0.008), worn)
	batch.box(metal, Vector3(0.0215, 0.012, -0.05), Vector3(0.003, 0.02, 0.062), dark)
	batch.box(metal, Vector3(-0.022, 0.0, -0.085), Vector3(0.005, 0.03, 0.012), worn)
	batch.cylinder(metal, Vector3(-0.024, 0.016, 0.03), 0.006, 0.006, 0.02, worn, 6, Basis(Vector3.BACK, PI / 2))
	# Rear aperture sight and charging handle.
	batch.box(metal, Vector3(0, 0.062, 0.058), Vector3(0.028, 0.018, 0.02), steel)
	for post in [-0.0105, 0.0105]:
		batch.box(metal, Vector3(post, 0.08, 0.058), Vector3(0.006, 0.022, 0.018), steel)
	batch.box(metal, Vector3(0, 0.073, 0.058), Vector3(0.015, 0.006, 0.01), worn)
	batch.box(metal, Vector3(0, 0.034, 0.1), Vector3(0.046, 0.01, 0.024), worn)
	# Free-float handguard with vents, barrel, gas block, front sight and flash hider.
	batch.cylinder(plastic, Vector3(0, 0.012, -0.135), 0.0285, 0.027, 0.275, polymer, 12, forward)
	batch.box(metal, Vector3(0, 0.042, -0.27), Vector3(0.02, 0.008, 0.27), steel)
	for vent in range(7):
		for side in [-1.0, 1.0]:
			batch.box(metal, Vector3(side * 0.0272, 0.014, -0.165 - vent * 0.034), Vector3(0.005, 0.009, 0.02), dark)
	batch.cylinder(metal, Vector3(0, 0.012, -0.41), 0.0105, 0.0105, 0.2, worn, 10, forward)
	batch.cylinder(metal, Vector3(0, 0.012, -0.425), 0.016, 0.016, 0.03, steel, 10, forward)
	batch.box(metal, Vector3(0, 0.036, -0.44), Vector3(0.012, 0.04, 0.02), steel)
	batch.box(metal, Vector3(0, 0.07, -0.44), Vector3(0.004, 0.034, 0.008), worn)
	for wing in [-0.009, 0.009]:
		batch.box(metal, Vector3(wing, 0.062, -0.44), Vector3(0.003, 0.024, 0.02), steel)
	batch.cylinder(metal, Vector3(0, 0.012, -0.61), 0.0145, 0.0135, 0.058, dark, 10, forward)
	# Curved magazine, pistol grip, trigger guard, buffer tube and stock.
	batch.box(metal, Vector3(0, -0.085, -0.064), Vector3(0.024, 0.09, 0.056), worn, Basis(Vector3.RIGHT, 0.14))
	batch.box(metal, Vector3(0, -0.158, -0.082), Vector3(0.024, 0.075, 0.055), worn, Basis(Vector3.RIGHT, 0.3))
	batch.box(plastic, Vector3(0, -0.084, 0.079), Vector3(0.03, 0.1, 0.04), polymer, Basis(Vector3.RIGHT, -0.33))
	batch.box(metal, Vector3(0, -0.056, 0.022), Vector3(0.01, 0.004, 0.07), steel)
	batch.cylinder(metal, Vector3(0, 0.014, 0.095), 0.0165, 0.0165, 0.21, steel, 10, Basis(Vector3.RIGHT, PI / 2))
	batch.box(plastic, Vector3(0, -0.004, 0.28), Vector3(0.038, 0.1, 0.14), polymer)
	batch.box(plastic, Vector3(0, 0.014, 0.2), Vector3(0.034, 0.046, 0.05), polymer)

## Additive star that flickers at the muzzle for one frame per shot.
static func build_flash(world: bool = false) -> MeshInstance3D:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 0.95, 0.8, 1), Color(1, 0.7, 0.3, 0.55), Color(1, 0.45, 0.1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_texture = texture
	glow.albedo_color = Color(2.0, 1.6, 1.1)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not world:
		tune(glow)
	# Three stretched quads crossing at the muzzle read as a star from any angle.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var shapes := [[Vector3(0.055, 0, 0), Vector3(0, 0.055, 0)], [Vector3(0.026, 0, 0), Vector3(0, 0, -0.09)], [Vector3(0, 0.026, 0), Vector3(0, 0, -0.09)]]
	for shape in shapes:
		var u: Vector3 = shape[0]
		var v: Vector3 = shape[1]
		var centre := Vector3.ZERO if v.z == 0.0 else Vector3(0, 0, -0.045)
		var start := vertices.size()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			vertices.append(centre + u * corner.x + v * corner.y)
			uvs.append(corner * 0.5 + Vector2(0.5, 0.5))
		for offset in [0, 1, 2, 0, 2, 3]:
			indices.append(start + offset)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, glow)
	var flash := MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	flash.mesh = mesh
	flash.layers = 1 if world else 2
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return flash
