class_name WeaponView
extends RefCounted
## First-person weapon models with gloved hands, authored in weapon space
## (-Z forward, +Y up, metres). Their materials use a narrow viewmodel field of view
## and a depth scale, so the weapon keeps its shape and never pokes through walls.

const VIEW_FOV := 52.0
## The Honey Badger model is 1.9 units long; this makes it a 72 cm carbine.
const BADGER_SCALE := 0.379
const SHOTGUN_SCENE := "res://assets/models/shotgun.glb"
## Where the shotgun's pistol grip (its origin) sits in weapon space.
const SHOTGUN_MOUNT := Vector3(0, -0.09, 0.07)
## The UMP45 built by tools/blender_make_ump.py (which prints its places); the supplied
## ump.glb it replaced stays in the folder unused.
const UMP_SCENE := "res://assets/models/ump_built.glb"
## Where the UMP's pistol grip (its origin) sits in weapon space.
const UMP_MOUNT := Vector3(0, -0.105, 0.075)
## Places on the UMP in metres from the middle of its grip: muzzle and half the width of
## its muzzle nut, top of the rail and where it begins and ends, where the second hand
## holds, the cocking handle, the way the magazine comes out and where its foot is.
const UMP := {
	"muzzle": Vector3(0, 0.1133, -0.3864), "bore": 0.0112, "rail": 0.1587, "rail_front": -0.302, "rail_back": 0.052,
	"support": Vector3(0, 0.1133, -0.29), "handle": Vector3(-0.0207, 0.1346, -0.2553),
	"magazine_out": Vector3(0, -0.995, -0.1), "magazine_foot": Vector3(0, -0.112, -0.186)
}
## The AK-47 (an AKM) built by tools/blender_make_ak47.py; the supplied ak47.glb it replaced
## stays in the folder unused.
const AK_SCENE := "res://assets/models/ak47_built.glb"
## Where the AK's pistol grip (its origin) sits in weapon space.
const AK_MOUNT := Vector3(0, -0.07, 0.08)
## Guns that come as a model with a magazine of their own and take parts from the shop.
## Places are in metres from the middle of the pistol grip (the model's SPEC.json): the
## muzzle and half the barrel's width; rail: the top of what a sight is clamped to, optic:
## how far forward a sight sits there, irons: how high the iron sights stand; where the
## second hand holds (hands: "grip" if it closes round a foregrip there instead of lying
## under a handguard); the cocking handle; the way the magazine comes out and where its
## foot is.
const GUNS := {
	# The UMP45 (see UMP): aimed through the rotary drum at the back of the rail over the
	# hooded post at its front (irons: the middle of the aperture, level with the tip of the
	# post); its sight line runs level with the bore. The straight magazine of translucent
	# polymer (its "Shell") drops out downwards.
	"ump": {
		"scene": UMP_SCENE, "mount": UMP_MOUNT, "muzzle": Vector3(0, 0.1133, -0.3864), "bore": 0.0112,
		"rail": 0.1587, "optic": -0.075, "irons": 0.1866,
		"support": Vector3(0, 0.1133, -0.29), "handle": Vector3(-0.0207, 0.1346, -0.2553),
		"magazine_out": Vector3(0, -0.995, -0.1), "magazine_foot": Vector3(0, -0.112, -0.186)
	},
	# The AK (tools/blender_make_ak47.py, which prints these places): a sight is clamped over
	# the top cover (rail: its top); irons: the line from the bottom of the rear notch to the
	# tip of the front post, level. handle: the knob of the bolt carrier on the right, which
	# runs back with every shot (bolt_travel); eject: its port.
	"ak": {
		"scene": AK_SCENE, "mount": AK_MOUNT, "muzzle": Vector3(0, 0.0764, -0.6253), "bore": 0.0102,
		"rail": 0.1185, "optic": -0.105, "irons": 0.1285,
		"support": Vector3(0, 0.079, -0.33), "handle": Vector3(0.0398, 0.0905, -0.2084), "bolt_travel": 0.095,
		"magazine_out": Vector3(0, -0.94, -0.34), "magazine_foot": Vector3(0, -0.1183, -0.2356),
		"eject": Vector3(0.016, 0.09, -0.16)
	},
	# The M4A4, the starting rifle (tools/blender_make_m4a4.py, which prints these places):
	# built by us, flat-top upper and quad-rail handguard. Its flip-up iron sights are a node
	# of their own ("Sights"; their low bases stay on the rails); folding: they are laid
	# down (hidden) when a sight is fitted, which then sits low on the rail instead of above
	# them. irons: the middle of the rear aperture, level with the tip of the front post.
	# The hand works the bolt catch on the left of the lower.
	"rifle": {
		"scene": "res://assets/models/m4a4_built.glb", "mount": Vector3(0, -0.08, 0.08), "muzzle": Vector3(0, 0.13, -0.607), "bore": 0.0112,
		"rail": 0.16, "optic": -0.125, "irons": 0.1958, "folding": true,
		"support": Vector3(0, 0.119, -0.3251), "handle": Vector3(-0.017, 0.087, -0.108),
		"magazine_out": Vector3(0, -0.985, -0.17), "magazine_foot": Vector3(0, -0.076, -0.174)
	},
	# The G36 (tools/blender_make_g36.py, which prints these places): built by us after
	# Henry's picture, a G36K-style carbine (the user's g36.glb stays unused). Its iron
	# sights sit inside the carry handle (node "Sights"): a ghost ring in the window at the
	# handle's back, a post in the hood of its front strut (irons: the line through both,
	# under the handle). A sight clamps to the rail on top of the handle and looks over
	# them, so they stay where they are (not folding). The left hand holds the vertical grip
	# (hands: "grip"); the translucent magazine drops out along its own slant. handle: the
	# charging handle on top, under the carry handle, folded out to the left; eject: the
	# port on the right.
	"g36": {
		"scene": "res://assets/models/g36_built.glb", "mount": Vector3(0, -0.08, 0.08), "muzzle": Vector3(0, 0.0608, -0.5096), "bore": 0.0108,
		"rail": 0.133, "optic": -0.09, "irons": 0.104, "hands": "grip",
		"support": Vector3(0, 0.008, -0.3), "handle": Vector3(-0.022, 0.0975, -0.173),
		"magazine_out": Vector3(0, -0.9833, -0.1819), "magazine_foot": Vector3(0, -0.1613, -0.1424),
		"eject": Vector3(0.0215, 0.0725, -0.117)
	},
	# The MP7 (tools/blender_make_mp7.py): its magazine sits in the pistol grip and comes out
	# of its foot; the left hand holds the foregrip (hands: "grip"). No iron sights: irons is
	# the top of the rail, which a sight clamps to. magazine_out is shorter than on the
	# others: the short magazine needs only 16 cm to clear the grip, and stays in the picture.
	# The HORNISSE (tools/blender_make_hornet.py), a machine pistol: held like the pistol,
	# the left hand round the right (hands: "cup"); its magazine runs down the grip and well
	# below it and comes out along the grip. rail and irons: the slide's top and the tip of
	# its front sight; a sight sits on the slide just before the rear sight.
	"hornet": {
		"scene": "res://assets/models/hornet.glb", "mount": Vector3(0, -0.075, 0.076), "muzzle": Vector3(0, 0.06, -0.15), "bore": 0.0046,
		"rail": 0.081, "optic": 0.012, "irons": 0.0868, "hands": "cup", "holo": 0.62, "metal": 0.65,
		"support": Vector3(-0.014, -0.012, 0.004), "handle": Vector3(-0.02, 0.02, -0.01),
		"magazine_out": Vector3(0, -0.9563, 0.2924), "magazine_foot": Vector3(0, -0.1212, 0.0453),
		# slide: how far the slide ("Breech" in the model) runs back with a shot; port: where
		# the empty cases leave it (right side, before the rear sight). A red dot does not ride
		# the slide (it came back into the eye with every shot): it stays where it is fitted.
		"slide": 0.026, "port": Vector3(0.0128, 0.068, -0.022)
	},
	"mp7": {
		"scene": "res://assets/models/mp7.glb", "mount": Vector3(0, -0.08, 0.08), "muzzle": Vector3(0, 0.1238, -0.315), "bore": 0.0115,
		"rail": 0.1814, "optic": -0.045, "irons": 0.1814, "hands": "grip",
		"support": Vector3(0, 0.035, -0.2142), "handle": Vector3(0, 0.1694, 0.1022),
		"magazine_out": Vector3(0, -0.6477, 0.0545), "magazine_foot": Vector3(0, -0.0448, 0.0014)
	},
	# The machine gun (tools/blender_make_mg.py, which prints these places; the supplied
	# mg.glb it replaced stays in the folder unused): fed by a belt from a box that hangs
	# under it on the left, which comes off sideways with its belt; the feed tray ("Feed")
	# stays. The cocking handle is on the right; rail: the top of the rail on the feed cover;
	# irons: the middle of the rear aperture ("Sights"), level with the tip of the front post.
	"mg": {
		"scene": "res://assets/models/mg_built.glb", "mount": Vector3(0, -0.085, 0.085), "muzzle": Vector3(0, 0.1217, -0.6683), "bore": 0.0118,
		"rail": 0.17, "optic": -0.15, "irons": 0.1897,
		"support": Vector3(0, 0.0907, -0.3539), "handle": Vector3(0.0377, 0.1327, -0.1011),
		"magazine_out": Vector3(-0.4512, -0.8924, 0.0), "magazine_foot": Vector3(-0.009, -0.052, -0.176)
	},
	# The M21E, the second machine gun (its id is mg2; tools/blender_make_mg2_built.py, which
	# prints these places): built by us after the model it replaced (mg2.glb, made from two
	# of the user's models), whose places it keeps; the drum has textures of its own. It hangs in
	# the middle under the magazine well, in front of the trigger guard: its own axis lies
	# along the barrel, the face with the winding key looks at the shooter, and the box of
	# its feed tower goes up into the back of the well. It comes off downwards, and the hand
	# takes it from below (magazine_foot: the lowest point of its rim). Aimed over the notch
	# of its rear sight and its hooded front post (irons: the tip of the post).
	"mg2": {
		"scene": "res://assets/models/mg2_built.glb", "mount": Vector3(0, -0.085, 0.085), "muzzle": Vector3(0, 0.1165, -0.7094), "bore": 0.0133,
		"rail": 0.1519, "optic": -0.15, "irons": 0.1754,
		"support": Vector3(0, 0.1093, -0.4104), "handle": Vector3(-0.03, 0.133, -0.52),
		"magazine_out": Vector3(-0.1, -0.99, 0.0), "magazine_foot": Vector3(0, -0.147, -0.172)
	},
	# The WIRBEL (tools/blender_make_wirbel.py, which prints these places): its magazine is
	# a drum on top, between two towers that carry the rail. The trough it lies in is open
	# on the left, and that is where it comes out, sideways and a little up, under the
	# rail's edge and over the trough's lip; the hand takes it by its left side. The left
	# hand holds the foregrip (hands: "grip"). Aimed through the ghost ring at the back of
	# the rail over the post at its front (irons: the middle of the ring, level with the
	# tip of the post; folding: they are laid down under a fitted sight, else its post fills
	# a scope). handle: the charging handle on the left, which runs back with every
	# shot (bolt_travel). eject: the port on the right where its cases come out.
	"wirbel": {
		"scene": "res://assets/models/wirbel.glb", "mount": Vector3(0, -0.08, 0.08), "muzzle": Vector3(0, 0.072, -0.6), "bore": 0.0062,
		"rail": 0.2, "optic": -0.1, "irons": 0.213, "hands": "grip", "folding": true,
		"support": Vector3(0, 0.012, -0.355), "handle": Vector3(-0.026, 0.078, -0.112), "bolt_travel": 0.075,
		"magazine_out": Vector3(-0.6, 0.183, 0.0), "magazine_foot": Vector3(-0.045, 0.116, -0.148),
		"eject": Vector3(0.026, 0.075, -0.057)
	},
	# The FALKE (tools/blender_make_falke.py, which prints these places): its rail runs the
	# whole length of the upper, the folding sights stand at both ends of it (irons: the
	# middle of the rear aperture, level with the tip of the front post). Its box magazine
	# drops out below and a little forward. handle: the charging handle on the left, which
	# runs back with the bolt at every shot (bolt_travel). eject: the port on the right.
	"falke": {
		"scene": "res://assets/models/falke.glb", "mount": Vector3(0, -0.08, 0.08), "muzzle": Vector3(0, 0.072, -0.605), "bore": 0.0072,
		"rail": 0.12, "optic": -0.03, "irons": 0.137, "folding": true,
		"support": Vector3(0, 0.018, -0.33), "handle": Vector3(-0.029, 0.091, -0.208), "bolt_travel": 0.1,
		"magazine_out": Vector3(0, -0.99, -0.1), "magazine_foot": Vector3(0, -0.118, -0.082),
		"eject": Vector3(0.02, 0.074, -0.062)
	},
	# The P90 (tools/blender_make_p90.py, which prints these places): built by us, a bullpup.
	# The right hand holds the bar between its two holes, the left one the front bar of the
	# trigger loop (hands: "grip"). Its translucent magazine lies on top, the rounds across;
	# it comes off up and to the left, and the hand takes it by its middle, from the left. It is
	# aimed through the ring sight in the housing at the front of the top (irons: the axis of
	# its tunnel; ring: where its glowing ring hangs, at the front of the tunnel). rail and
	# optic only place the parts of other guns, which it does not take. The handle is the
	# charging handle on the left under the sight; eject: the chute under the butt.
	"p90": {
		"scene": "res://assets/models/p90_built.glb", "mount": Vector3(0, -0.08, 0.08), "muzzle": Vector3(0, 0.026, -0.205), "bore": 0.0036,
		"rail": 0.124, "optic": -0.07, "irons": 0.101, "hands": "grip", "ring": Vector3(0, 0.101, -0.098),
		"support": Vector3(0, -0.008, -0.119), "handle": Vector3(-0.031, 0.034, -0.118),
		"magazine_out": Vector3(-0.38, 0.3, -0.04), "magazine_foot": Vector3(-0.036, 0.028, 0.04),
		# The empty one is taken down and to the left, out of the picture, before a full one
		# comes back up (see reload_step).
		"magazine_away": Vector3(-0.3, -0.45, 0.12),
		"eject": Vector3(0, -0.075, 0.199)
	}
}
## The reflex sight is the user's model of a holographic sight: a hood with a tunnel to
## look through, on a lever clamp (prepared in Nachtwache-Modelle/rotpunkt; the numbers
## are those of its SPEC.json). Its origin lies on the rail, in the plane of the face that
## looks at the shooter. AXIS: the middle of its window above the rail. TUNNEL: where the
## tunnel begins and ends ahead of that face. GLASS: a pane half way through it, a little
## bigger than the opening there, so that its edges lie in the walls. BACK: how far behind `optic` (the middle of where a sight sits) that face is. EYE:
## how far behind that face the eye is when aiming.
const HOLO_SCENE := "res://assets/models/holo.glb"
const HOLO_AXIS := 0.0699
const HOLO_TUNNEL := Vector2(-0.0085, -0.0428)
const HOLO_GLASS := Vector2(0.04, 0.03)
const HOLO_BACK := 0.04
const HOLO_EYE := 0.096
## How much of the metal its textures claim is kept, and what its paint is multiplied
## with: darker, and a shade cooler against the warm light on the weapon (see _gun_mods).
const HOLO_METAL := 0.15
const HOLO_PAINT := Color(0.3, 0.32, 0.36)
## The red dot (see _gun_mods): a short round tube on a low mount, sized for a rifle (the
## sidearms and the HORNISSE carry a smaller one, dot_size). DOT_RADIUS is its lens,
## DOT_WALL the tube's wall, DOT_AXIS how high the middle of the lens stands over the rail
## at the least (more where iron sights stand that must stay below the lens), DOT_EYE how
## far behind the tube's rear face the eye is when aiming.
const DOT_RADIUS := 0.0158
const DOT_WALL := 0.0028
const DOT_LENGTH := 0.03
const DOT_AXIS := 0.03
const DOT_EYE := 0.125
## The mark in its window was drawn for a glass this far from the eye; it keeps the size
## it had to the eye (see _gun_mods).
const MARK_EYE := 0.165
## How far behind the eyepiece of the telescopic sight the eye is.
const SCOPE_EYE := 0.07
## How far a suppressor moves the muzzle forward.
const SILENCER_LENGTH := 0.15
const GLOVE := Color("2a2c2b")
const GLOVE_PAD := Color("323534")
## The hard guard over the knuckles and the tab of the glove's cuff.
const KNUCKLE := Color("1c1e1e")
const SLEEVE := Color("3a412f")
const SLEEVE_CUFF := Color("2c3125")
## (These colours stay in the shapes as they are: the baked hands in assets/hands are named
## after their shapes, colours included. What the arms really look like is the material's
## business: ARM_LOOKS, measured against these.)

## What the first-person arms are made of: the three surfaces of the baked hands (glove,
## pad, sleeve) and the pieces worn over them, each a material of its own that is dressed
## as the worn skin (wear). arm_skin: a bare forearm, smooth, in place of the sleeve; arm_roll: a sleeve rolled or pushed up to the elbow; arm_guard:
## a hard shell over the forearm; arm_straps: two straps round the forearm; arm_laces and
## arm_cord: the laced opening of an arm warmer; arm_seams: the seams down the fingers of a
## glove; arm_nails: fingernails, on a bare hand.
const ARM_PARTS := ["glove", "pad", "sleeve", "arm_skin", "arm_roll", "arm_guard", "arm_straps", "arm_laces", "arm_cord", "arm_seams", "arm_nails"]
## How each kind of surface is drawn: its texture (assets/surfaces/farm, laid on in the
## weapon's own space so that it moves with it; "" for none), how often it repeats, how
## strong its relief is, how rough it is, what share of the light the texture keeps on
## average (so that the colour in ARM_LOOKS is the colour seen; on skin, the shading the
## textures of the looks have painted in, which the bare surface here has not), and coat: a clear glossy
## layer; rim: the soft sheen of cloth at a grazing angle; sss: light through skin.
## A bare hand is drawn a little slimmer than the glove its shapes were made for (THIN).
const ARM_FINISH := {
	"glove": {"texture": "glove", "scale": 22.0, "normal": 0.65, "rough": 1.0, "mean": 0.58},
	"leather": {"texture": "glove", "scale": 13.0, "normal": 0.35, "rough": 0.6, "mean": 0.58, "coat": 0.2},
	"gloss": {"texture": "glove", "scale": 7.0, "normal": 0.18, "rough": 0.34, "mean": 0.58, "coat": 0.7},
	"rubber": {"texture": "glove", "scale": 12.0, "normal": 0.3, "rough": 0.62, "mean": 0.58},
	"fabric": {"texture": "fabric", "scale": 9.0, "normal": 0.9, "rough": 1.0, "mean": 0.69, "rim": 0.3},
	"knit": {"texture": "fabric", "scale": 4.5, "normal": 1.3, "rough": 1.0, "mean": 0.69, "rim": 0.5},
	"skin": {"texture": "", "scale": 16.0, "normal": 0.3, "rough": 0.55, "mean": 1.2, "sss": 0.15},
	"nail": {"texture": "", "scale": 16.0, "normal": 0.0, "rough": 0.4, "mean": 1.2}
}
## Each skin of Profile.SKINS as its arms: [finish, colour] for each part it has (a part
## left out is not there - no knuckle guards on a bare hand). The colours were sampled with
## tools/skin_arm_shots.gd from the textures of the looks (SoldierVisual.LOOKS) where their
## forearms and hands are. Gloved hands get seams, bare ones nails (see _dress).
const ARM_LOOKS := {
	# Fireteam: black gloves with a cuff, the camouflage sleeves rolled up over the elbow,
	# pale bare forearms.
	"main": {"glove": ["glove", "1c1e1d"], "pad": ["rubber", "141615"], "arm_skin": ["skin", "c2a397"], "arm_roll": ["fabric", "3c3b39"]},
	# Viper: a black catsuit with a faint sheen, black gloves.
	"viper": {"glove": ["glove", "1b1d1c"], "pad": ["rubber", "121413"], "sleeve": ["leather", "222423"]},
	# Scorpion: black from head to foot - glossy padded armour, a shell over the forearm.
	"scorpion": {"glove": ["leather", "0b0c0c"], "pad": ["gloss", "0a0b0b"], "sleeve": ["gloss", "0f1011"], "arm_guard": ["gloss", "0c0d0e"], "arm_straps": ["rubber", "0b0c0c"]},
	# Raven: black leather arm warmers laced down the outside, the skin showing through.
	"raven": {"glove": ["glove", "161713"], "pad": ["rubber", "101110"], "sleeve": ["leather", "1e1d19"], "arm_laces": ["skin", "d9b59c"], "arm_cord": ["leather", "2b2925"]},
	# The C.R.U.: charcoal uniform, grey-black gloves.
	"cru": {"glove": ["glove", "2a2d2f"], "pad": ["rubber", "1b1e1f"], "sleeve": ["fabric", "2c2f31"]},
	# The Breacher: black jacket, black gloves, straps on the forearms.
	"cru2": {"glove": ["glove", "141717"], "pad": ["rubber", "0c0e0e"], "sleeve": ["fabric", "1e2022"], "arm_straps": ["rubber", "2c2d2e"]},
	# Phantom: grey camouflage, a dark guard over the forearm, black gloves.
	"phantom": {"glove": ["glove", "2c2d2d"], "pad": ["rubber", "171918"], "sleeve": ["fabric", "4a4b4b"], "arm_guard": ["leather", "1e201e"], "arm_straps": ["rubber", "161716"]},
	# Havoc: heavy slate-grey padded sleeves and gloves.
	"havoc": {"glove": ["glove", "2b2c2c"], "pad": ["rubber", "18191a"], "sleeve": ["fabric", "2e3033"], "arm_straps": ["rubber", "1a1c1c"]},
	# Ghost: dark leather gloves with hard knuckles, straps round the wrist.
	"ghost": {"glove": ["leather", "262827"], "pad": ["gloss", "141615"], "sleeve": ["fabric", "262827"], "arm_straps": ["leather", "1a1c1b"]},
	# The beach guy: bare arms and hands, tanned.
	"dude_shorts": {"glove": ["skin", "b07a69"], "arm_skin": ["skin", "b47f6e"]},
	# The man in the turtleneck: black knit sleeves pushed up to the elbow, bare forearms.
	"dude_turtleneck": {"glove": ["skin", "d39380"], "arm_skin": ["skin", "d69886"], "arm_roll": ["knit", "151615"]}
}
## The skin the arms are dressed as (wear).
static var worn := "main"
## How much thinner a bare hand is than the glove (metres off every surface).
const THIN := 0.0018
static var skin_relief: Texture2D
static var skin_tone: Texture2D

## Dresses the first-person arms as `look` (an id of Profile.SKINS): every hand and arm
## already built takes it on at once, since they share their materials.
static func wear(look: String) -> void:
	worn = look if ARM_LOOKS.has(look) else "main"
	for key in ARM_PARTS:
		for slot in [key, key + "_world"]:
			if materials.has(slot):
				_dress(materials[slot], key)

## One part of the arms as the worn skin has it, or hidden when it has none.
static func _dress(target: StandardMaterial3D, key: String) -> void:
	var look: Dictionary = ARM_LOOKS[worn]
	var part: Array = look.get(key, [])
	var bare := str((look.glove as Array)[0]) == "skin"
	# Seams on a glove, nails on a bare hand: in the colour of the hand.
	if key == "arm_seams" and not bare:
		part = ["rubber", Color(str(look.glove[1])).darkened(0.45).to_html(false)]
	elif key == "arm_nails" and bare:
		part = ["nail", Color(str(look.glove[1])).lerp(Color("e9c9bd"), 0.3).to_html(false)]
	target.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	target.albedo_color = Color.WHITE
	if part.is_empty():
		# Not worn: cut away entirely (the alpha is never above the threshold).
		target.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		target.alpha_scissor_threshold = 0.5
		target.albedo_color = Color(0, 0, 0, 0)
		return
	var finish: Dictionary = ARM_FINISH[part[0]]
	var colour := Color(str(part[1]))
	var texture := str(finish.texture)
	if texture != "":
		var base := "res://assets/surfaces/farm/" + texture
		target.albedo_texture = load(base + "_albedo.jpg")
		target.normal_texture = load(base + "_normal.jpg")
		target.roughness_texture = load(base + "_roughness.jpg")
	else:
		# Skin: a faint blotchiness in its colour and fine pores, made here.
		if skin_relief == null:
			var pores := FastNoiseLite.new()
			pores.frequency = 0.09
			pores.fractal_octaves = 3
			var relief := NoiseTexture2D.new()
			relief.width = 512
			relief.height = 512
			relief.seamless = true
			relief.as_normal_map = true
			relief.bump_strength = 3.0
			relief.noise = pores
			skin_relief = relief
			var blotches := FastNoiseLite.new()
			blotches.frequency = 0.012
			var ramp := Gradient.new()
			ramp.set_color(0, Color(0.9, 0.86, 0.86))
			ramp.set_color(1, Color(1.0, 1.0, 0.98))
			var tone := NoiseTexture2D.new()
			tone.width = 256
			tone.height = 256
			tone.seamless = true
			tone.noise = blotches
			tone.color_ramp = ramp
			skin_tone = tone
		target.albedo_texture = skin_tone if key != "arm_nails" else null
		target.normal_texture = skin_relief
		target.roughness_texture = null
	target.normal_enabled = float(finish.normal) > 0.0
	target.normal_scale = float(finish.normal)
	target.roughness = float(finish.rough)
	target.uv1_triplanar = true
	target.uv1_triplanar_sharpness = 4.0
	target.uv1_scale = Vector3.ONE * float(finish.scale)
	target.clearcoat_enabled = finish.has("coat")
	target.clearcoat = float(finish.get("coat", 0.0))
	target.clearcoat_roughness = 0.25
	target.rim_enabled = finish.has("rim")
	target.rim = float(finish.get("rim", 0.0))
	target.rim_tint = 0.6
	target.subsurf_scatter_enabled = finish.has("sss")
	target.subsurf_scatter_strength = float(finish.get("sss", 0.0))
	target.subsurf_scatter_skin_mode = true
	target.grow = key == "glove" and str(part[0]) == "skin"
	target.grow_amount = -THIN
	# The baked surfaces carry the colours of their shapes (darker cuffs and folds, the
	# lighter knuckles): kept as shading, measured against the colour they were made in.
	# Bare skin is one colour: there those shades would read as bruises.
	var reference: Variant = {"glove": GLOVE, "pad": KNUCKLE, "sleeve": SLEEVE}.get(key)
	target.vertex_color_use_as_albedo = reference != null and str(part[0]) != "skin"
	var seen := colour.srgb_to_linear()
	var keep := float(finish.mean)
	if target.vertex_color_use_as_albedo:
		var under := (reference as Color).srgb_to_linear()
		target.albedo_color = Color(seen.r / (under.r * keep), seen.g / (under.g * keep), seen.b / (under.b * keep)).linear_to_srgb()
	else:
		target.albedo_color = Color(seen.r / keep, seen.g / keep, seen.b / keep).linear_to_srgb()

## Hip and aimed positions are in camera space; angles are degrees.
const VIEWS := {
	"usp": {"hip": Vector3(0.11, -0.13, -0.5), "hip_angles": Vector3(0.5, 5.0, -2.0), "aim": Vector3(0, -0.05, -0.47), "muzzle": Vector3(0, 0.015, -0.145)},
	"g18": {"hip": Vector3(0.11, -0.13, -0.5), "hip_angles": Vector3(0.5, 5.0, -2.0), "aim": Vector3(0, -0.045, -0.47), "muzzle": Vector3(0, 0.01, -0.13)},
	"deagle": {"hip": Vector3(0.11, -0.14, -0.48), "hip_angles": Vector3(0.5, 5.0, -2.0), "aim": Vector3(0, -0.06, -0.45), "muzzle": Vector3(0, 0.025, -0.185)},
	# The M4A4 (build_gun): aimed, the eye is on the line through its aperture and its front
	# post, 13 cm behind the aperture.
	"rifle": {
		"hip": Vector3(0.12, -0.155, -0.35), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.1158, -0.1915), "muzzle": Vector3(0, 0.05, -0.527),
		"reload_low": Vector3(-0.02, 0.05, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	},
	# The G36 (build_gun): aimed through the ghost ring at the back of its carry handle at
	# the post in the handle's front, the eye 14 cm behind the ring.
	"g36": {
		"hip": Vector3(0.12, -0.152, -0.37), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0, -0.024, -0.2366), "muzzle": Vector3(0, -0.0192, -0.4296),
		"reload_low": Vector3(-0.05, 0.19, -0.12), "reload_turn": Vector3(0.12, 0.8, 0.1)
	},
	# The machine gun (build_gun), aimed through its rear aperture at the post between the
	# ears of its front sight, the eye 10 cm behind the aperture (a ghost ring: looked through
	# from close by, it is a ring round the post).
	"mg": {
		"hip": Vector3(0.13, -0.17, -0.33), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.1047, -0.18), "muzzle": Vector3(0, 0.0367, -0.5833),
		"reload_low": Vector3(-0.02, 0.06, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	},
	# The M21E (build_gun): the eye on the line over the notch of its rear sight and the tip
	# of its front post, 14 cm behind the notch; the notch stands 4.6 mm higher than the post,
	# so the gun is tipped up by that line's slope (both printed by blender_make_mg2_built.py).
	"mg2": {
		"hip": Vector3(0.13, -0.17, -0.33), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.0943, -0.225), "aim_angles": Vector3(0.458, 0.0, 0.0), "muzzle": Vector3(0, 0.0315, -0.6244),
		"reload_low": Vector3(-0.02, 0.06, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	},
	# The P90 (build_gun): aimed through its ring sight, the eye 22 cm behind the hood of its
	# housing (after Henry: at 16 cm the housing round the deep tunnel covered too much of the
	# picture; further back it covers far less, and the window shrinks only a little). For a
	# reload it is raised and rolled to the left, so that the magazine on top faces the eye
	# as it comes off.
	"p90": {
		"hip": Vector3(0.12, -0.098, -0.37), "hip_angles": Vector3(1.5, 9.0, -3.0),
		"aim": Vector3(0.0, -0.021, -0.284), "muzzle": Vector3(0, -0.054, -0.125),
		"reload_low": Vector3(-0.07, 0.05, -0.1), "reload_turn": Vector3(0.35, 0.3, 0.25)
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
	# The launcher (an M32, see build_m32) is not aimed over its sight: it stays beside the
	# line of sight, so that the arc of its shell can be seen (see Survivor.launch_path).
	# While its drum is loaded it is held lower and rolled over to the left, muzzle down a
	# little, so that the open front of the drum shows and the empty cases slide out.
	"launcher": {
		"hip": Vector3(0.125, -0.195, -0.39), "hip_angles": Vector3(1.0, 6.5, -2.5),
		"aim": Vector3(0.11, -0.185, -0.42), "aim_angles": Vector3(0.5, 5.0, -2.0), "muzzle": Vector3(0, 0.092, -0.456),
		# The M32 is lowered while its front swings open, then stood on its butt, muzzle up,
		# for the shells to be pushed into the drum one by one (load_low, load_turn).
		"reload_low": Vector3(-0.03, -0.03, 0.0), "reload_turn": Vector3(-0.3, 0.3, 0.3),
		"load_low": Vector3(-0.12, 0.0, -0.03), "load_turn": Vector3(1.1, 0.2, 0.35)
	},
	# The minigun is not aimed: held low at the right hip and tipped up, so that its housing
	# sits in the lower right corner and the long barrel cluster runs diagonally into the
	# middle of the picture; the hand on the carry handle stays small in the corner (Henry's
	# first-person reference). Aimed it only comes in a little towards the middle.
	"minigun": {
		"hip": Vector3(0.48, -0.24, -0.24), "hip_angles": Vector3(20.0, 25.0, -6.0),
		"aim": Vector3(0.45, -0.22, -0.26), "aim_angles": Vector3(18.0, 22.0, -5.0), "muzzle": Vector3(0, -0.2, -0.88)
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
	# The UMP (build_gun): aimed, the eye is on the line through its rear drum and its front
	# post, 14 cm behind the drum (its sight line runs level with the bore: no tip).
	# reload_low and reload_turn: how the weapon is held while its magazine is changed -
	# raised and rolled over, so that the magazine well can be seen.
	"ump": {
		"hip": Vector3(0.13, -0.162, -0.4), "hip_angles": Vector3(0.5, 6.5, -2.5),
		"aim": Vector3(0.0, -0.0816, -0.259), "muzzle": Vector3(0, 0.0083, -0.3114),
		"reload_low": Vector3(-0.02, 0.07, 0.03), "reload_turn": Vector3(0.4, 0.28, -0.87)
	},
	# The AK-47 (build_gun). Its rear sight stands on the block before the top cover, its front
	# post between two ears near the muzzle; their line is level, the eye on it 19 cm behind
	# the gun's origin (35 cm behind the rear notch).
	"ak": {
		"hip": Vector3(0.115, -0.148, -0.33), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.0585, -0.19), "muzzle": Vector3(0, 0.0064, -0.5453),
		"reload_low": Vector3(-0.02, 0.05, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	},
	# The WIRBEL (build_gun): held lower than the others, its drum and rail standing high;
	# aimed through its ghost ring, 15 cm before the eye. For a reload it is tipped up and
	# turned a little, so that its open left side and the drum sliding out of it face the
	# eye, but hardly rolled (rolled like the others, the drum flew up into the picture).
	"wirbel": {
		"hip": Vector3(0.12, -0.19, -0.36), "hip_angles": Vector3(0.5, 6.0, -2.5),
		"aim": Vector3(0.0, -0.133, -0.24), "muzzle": Vector3(0, -0.008, -0.52),
		"reload_low": Vector3(-0.03, 0.0, 0.03), "reload_turn": Vector3(0.3, 0.35, -0.3)
	},
	# The FALKE (build_gun): aimed through its rear aperture, 13 cm before the eye, the butt
	# at the shoulder. For a reload it is tipped and rolled to the left like the AK, so that
	# the well and the magazine dropping out of it can be seen.
	# (After Henry: from the hip it sat too low and far right; it is held higher and nearer
	# the middle now, like the AK. Aimed, the eye is 16 cm behind the rear aperture.)
	"falke": {
		"hip": Vector3(0.11, -0.122, -0.3), "hip_angles": Vector3(0.5, 5.0, -2.0),
		"aim": Vector3(0.0, -0.057, -0.33), "muzzle": Vector3(0, -0.008, -0.555),
		"reload_low": Vector3(-0.02, 0.05, 0.04), "reload_turn": Vector3(0.35, 0.25, -0.8)
	},
	# The MP7 (build_gun): no iron sights, so aimed along the top of its rail, 2.5 cm above it
	# and 16 cm behind its end. For a reload it is raised high and rolled far over to the
	# left, so that the foot of the grip and the magazine that comes out of it can be seen.
	# The HORNISSE (build_gun): held as the pistol is, aimed over its sights.
	"hornet": {
		"hip": Vector3(0.11, -0.13, -0.47), "hip_angles": Vector3(0.5, 5.0, -2.0),
		"aim": Vector3(0.0, -0.0118, -0.43), "muzzle": Vector3(0, -0.015, -0.074),
		"reload_low": Vector3(-0.03, 0.06, 0.02), "reload_turn": Vector3(0.35, 0.3, -0.7)
	},
	"mp7": {
		"hip": Vector3(0.12, -0.16, -0.42), "hip_angles": Vector3(0.5, 6.5, -2.5),
		"aim": Vector3(0.0, -0.1264, -0.3254), "muzzle": Vector3(0, 0.0438, -0.235),
		"reload_low": Vector3(-0.1, 0.17, -0.02), "reload_turn": Vector3(0.25, 0.25, -1.1)
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
	# The launcher is the M32 (tools/blender_make_m32.py), with a view of its own: see build_m32.
	"launcher": {"scene": "res://assets/models/m32.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.078, -0.322), "hands": "grip", "drum": true},
	# The minigun (tools/blender_make_minigun.py, which prints these places): its origin is the
	# middle of the rear grip, which rises at the back and leans forward (grip_lean: the right
	# hand is turned with it by that many degrees; grip: where it closes, from the origin). The
	# left hand holds the carry handle on top (hands: "bar", rolled by bar_roll degrees). baked:
	# it keeps its own textures (model_scene). Its
	# node "Barrels" spins about its own z, the axis of the barrel cluster (Survivor._spin).
	"minigun": {"scene": "res://assets/models/minigun_built.glb", "mount": Vector3(0, -0.12, 0.05), "support": Vector3(0, 0.059, -0.33), "hands": "bar",
		"bar_roll": -60.0, "bar_reach": Vector3(-0.12, -0.32, 0.06), "grip_lean": -15.0, "grip": Vector3(0, -0.008, 0.002), "baked": true},
	"m14": {"scene": "res://assets/models/m14.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0811, -0.341), "hands": "cradle"},
	"svd": {"scene": "res://assets/models/svd.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0928, -0.438), "hands": "cradle"},
	"flamer": {"scene": "res://assets/models/flamethrower.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.007, -0.437), "hands": "grip"},
	# open: the double rifle breaks open to be loaded; its barrels turn about their hinge
	# (the node "Barrels") by this many degrees.
	"nitro": {"scene": "res://assets/models/double_rifle.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0829, -0.308), "hands": "cradle", "open": -28.0},
	"fifty": {"scene": "res://assets/models/heavy_sniper.glb", "mount": Vector3(0, -0.09, 0.07), "support": Vector3(0, 0.0895, -0.378), "hands": "cradle"}
}

## The M32's moving parts, measured on its model (from the middle of the pistol grip): the
## mouth of the chamber a shell is pushed into (upper left of the drum, the drum then winds
## it up to the top), the latch of the front frame, how far that frame swings out (degrees
## about its hinge), and where the left hand is while it fetches the next shell (from
## where it holds the foregrip).
const M32 := {
	"mouth": Vector3(-0.0433, 0.157, -0.196), "latch": Vector3(-0.035, 0.197, -0.214), "open": -58.0,
	"away": Vector3(-0.05, -0.17, 0.17), "shell": 0.105
}

static var materials: Dictionary = {}
static var holo_material: BaseMaterial3D
static var badger_material: BaseMaterial3D
static var gun_materials: Dictionary = {}
## The AK-47 as soldiers carry it: a light copy of the model (tools/blender_make_ak47.py
## writes both). Loaded once and kept.
const AK_LOW_SCENE := "res://assets/models/ak47_low_built.glb"
static var ak_low: PackedScene
static var shotgun_materials: Dictionary = {}
static var grain: NoiseTexture2D

static func tune(target: BaseMaterial3D) -> BaseMaterial3D:
	# (Seen at a slant, as the long faces of a turning drum are, a texture stays sharp only
	# with anisotropic filtering: plain mipmaps blurred them to mush.)
	target.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
	elif key in ARM_PARTS:
		# The hands, the arms and what is worn on them: dressed as the skin the player
		# wears (see ARM_LOOKS), and dressed again in place when that changes (wear).
		_dress(result, key)
	if not world:
		tune(result)
	materials[slot] = result
	return result

## The hands and arms are noted as shapes on their batch: when it is committed, a smooth
## surface baked from exactly those shapes takes their place (assets/hands, made by
## tools/bake_hands.gd); a pose without one is drawn in the plain pieces. With
## `smooth_hands` off they are drawn in pieces straight away; while `dumping`, every set
## of shapes is kept in `dumped` for the bake.
static var smooth_hands := true
static var dumping := false
static var dumped: Array = []
const HAND_FOLDER := "res://assets/hands/"

static func _shape(batch: MeshBatch, shape: Array) -> void:
	if smooth_hands:
		if not MeshBatch.shape_maker.is_valid():
			MeshBatch.shape_maker = WeaponView._make_shapes
		batch.shapes.append(shape)
	else:
		_draw_shape(batch, shape)

static func _draw_shape(batch: MeshBatch, shape: Array) -> void:
	var key: String = shape[1]
	var color: Color = shape[2]
	match String(shape[0]):
		"cone":
			var from: Vector3 = shape[3]
			var span: Vector3 = (shape[4] as Vector3) - from
			batch.cylinder(shared(key), from, shape[5], shape[6], span.length(), color, shape[7], Basis(Quaternion(Vector3.UP, span.normalized())))
			batch.ellipsoid(shared(key), from, Vector3.ONE * float(shape[5]), color, Basis.IDENTITY, shape[7], 5)
		"tube":
			batch.cylinder(shared(key), shape[3], shape[4], shape[5], shape[6], color, shape[7], shape[8], shape[9])
		"egg":
			batch.ellipsoid(shared(key), shape[3], shape[4], color, shape[5], shape[6], shape[7])
		"block":
			batch.box(shared(key), shape[3], shape[4], color, shape[5])

## The shapes as the bake reads them: everything a round cone, an ellipsoid or a box.
static func _shape_data(shape: Array) -> Dictionary:
	var colour: Color = shape[2]
	var data := {"k": shape[1], "c": [colour.r, colour.g, colour.b]}
	var flat := func(v: Vector3) -> Array: return [v.x, v.y, v.z]
	var frame := func(b: Basis) -> Array: return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]
	match String(shape[0]):
		"cone":
			data.merge({"t": "cone", "a": flat.call(shape[3]), "b": flat.call(shape[4]), "r0": shape[5], "r1": shape[6]})
		"tube":
			var turn: Basis = shape[8]
			var widen := (turn.x.length() + turn.z.length()) * 0.5
			var top: Vector3 = (shape[3] as Vector3) + turn.y * float(shape[6])
			data.merge({"t": "cone", "a": flat.call(shape[3]), "b": flat.call(top), "r0": float(shape[4]) * widen, "r1": float(shape[5]) * widen})
		"egg":
			data.merge({"t": "egg", "center": flat.call(shape[3]), "radii": flat.call(shape[4]), "basis": frame.call(shape[5])})
		"block":
			data.merge({"t": "block", "center": flat.call(shape[3]), "size": flat.call(shape[4]), "basis": frame.call(shape[5])})
	return data

## MeshBatch.shape_maker: the baked surface for these shapes, or the pieces.
static func _make_shapes(batch: MeshBatch, parent: Node3D, prefix: String) -> Array:
	var data: Array = []
	for shape: Array in batch.shapes:
		data.append(_shape_data(shape))
	var text := JSON.stringify(data)
	var key := text.md5_text().substr(0, 16)
	if dumping:
		dumped.append({"key": key, "shapes": data})
	var path := HAND_FOLDER + key + ".res"
	if ResourceLoader.exists(path):
		var mesh := load(path) as ArrayMesh
		var instance := MeshInstance3D.new()
		instance.name = prefix + "Smooth"
		instance.mesh = mesh
		for surface in range(mesh.get_surface_count()):
			instance.set_surface_override_material(surface, shared(mesh.surface_get_name(surface)))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		return [instance]
	for shape: Array in batch.shapes:
		_draw_shape(batch, shape)
	return []

## Tapered limb segment between two points, with a rounded joint at its start.
static func _segment(batch: MeshBatch, key: String, from: Vector3, to: Vector3, start_radius: float, end_radius: float, color: Color, sides: int = 8) -> void:
	_shape(batch, ["cone", key, color, from, to, start_radius, end_radius, sides])

static func _egg(batch: MeshBatch, key: String, center: Vector3, radii: Vector3, color: Color, turn: Basis = Basis.IDENTITY, segments: int = 10, rings: int = 6) -> void:
	_shape(batch, ["egg", key, color, center, radii, turn, segments, rings])

static func _tube(batch: MeshBatch, key: String, base: Vector3, r0: float, r1: float, tall: float, color: Color, sides: int, turn: Basis, capped: bool = false) -> void:
	_shape(batch, ["tube", key, color, base, r0, r1, tall, sides, turn, capped])

## A finger in three joints from the knuckle over `joint` to the tip, its middle joint a
## little proud of the line, a padded tip.
static func _finger(batch: MeshBatch, knuckle: Vector3, joint: Vector3, tip: Vector3) -> void:
	var line := (tip - joint)
	var mid := joint + line * 0.52 + (joint - knuckle).normalized() * line.length() * 0.12
	_segment(batch, "glove", knuckle, joint, 0.0112, 0.0102, GLOVE, 10)
	_segment(batch, "glove", joint, mid, 0.0104, 0.0095, GLOVE, 10)
	_segment(batch, "glove", mid, tip, 0.0097, 0.0088, GLOVE, 10)
	_egg(batch, "glove", tip, Vector3.ONE * 0.0092, GLOVE, Basis.IDENTITY, 10, 6)
	_egg(batch, "glove", knuckle, Vector3(0.0128, 0.0122, 0.0128), GLOVE_PAD, Basis.IDENTITY, 10, 6)
	# What only some skins show (see ARM_PARTS): drawn as plain pieces over the baked
	# surface. The finger bends about `bend`; its back (the nail's side) is where the
	# middle joint stands out of the line from knuckle to tip.
	var bend := (joint - knuckle).cross(tip - joint)
	if bend.length() < 1e-6:
		return
	bend = bend.normalized()
	# A glove's seams, down both sides of the finger.
	for s: float in [-1.0, 1.0]:
		var points := [knuckle + bend * s * 0.0113, joint + bend * s * 0.0104, mid + bend * s * 0.0096, tip + bend * s * 0.0086]
		for i in range(3):
			_gear_line(batch, "arm_seams", points[i], points[i + 1], 0.0008)
	var along := (tip - mid).normalized()
	var back := joint - (knuckle + tip) * 0.5
	back = (back - along * back.dot(along))
	if back.length() < 1e-4:
		return
	back = back.normalized()
	# A bare hand's nail, flat on the back of the tip.
	batch.ellipsoid(shared("arm_nails"), tip - along * 0.0035 + back * 0.0074, Vector3(0.0066, 0.0024, 0.0078), Color.WHITE, Basis(bend, back, along), 10, 5)

## A smooth oval tube along `axis` from `base`, `length` long: `profile` gives its half widths
## [share of the length, across, up] at a few places, eased in between. Normals come from
## the oval itself, so that it shades round where the pieces of MeshBatch would show facets.
static func _loft(batch: MeshBatch, key: String, base: Vector3, axis: Vector3, across: Vector3, lift: Vector3, length: float, profile: Array, rings: int = 18, sides: int = 22) -> void:
	var surface := batch._surface(shared(key))
	var first := surface.vertices.size()
	var size_at := func(t: float) -> Vector2:
		for i in range(profile.size() - 1):
			var a: Array = profile[i]
			var b: Array = profile[i + 1]
			if t <= float(b[0]) or i == profile.size() - 2:
				var w := smoothstep(float(a[0]), float(b[0]), t)
				return Vector2(lerpf(a[1], b[1], w), lerpf(a[2], b[2], w))
		return Vector2(profile[0][1], profile[0][2])
	for ring in range(rings + 1):
		var t := float(ring) / rings
		var size: Vector2 = size_at.call(t)
		var ahead: Vector2 = size_at.call(minf(t + 0.02, 1.0)) - size_at.call(maxf(t - 0.02, 0.0))
		var slope := (ahead.x + ahead.y) * 0.5 / (0.04 * length)
		var centre := base + axis * (length * t)
		for i in range(sides + 1):
			var angle := TAU * float(i) / sides
			var c := cos(angle)
			var s := sin(angle)
			surface.vertices.append(centre + across * (c * size.x) + lift * (s * size.y))
			var facing := across * (c / size.x) + lift * (s / size.y)
			surface.normals.append((facing.normalized() - axis * slope).normalized())
			surface.colors.append(Color.WHITE)
	for ring in range(rings):
		for i in range(sides):
			var a := first + ring * (sides + 1) + i
			var b := a + sides + 1
			for index in [a, a + 1, b, a + 1, b + 1, b]:
				surface.indices.append(index)

## A thin round piece from `from` to `to` (seams, laces).
static func _gear_line(batch: MeshBatch, key: String, from: Vector3, to: Vector3, radius: float) -> void:
	var span := to - from
	if span.length() < 1e-5:
		return
	batch.cylinder(shared(key), from, radius, radius, span.length(), Color.WHITE, 5, Basis(Quaternion(Vector3.UP, span.normalized())), false)

## Small numbers that are the same every time for the same place (folds of a sleeve).
static func _jitter(at: Vector3, salt: float) -> float:
	var v := sin(at.dot(Vector3(127.1, 311.7, 74.7)) + salt * 17.13) * 43758.5453
	return (v - floor(v)) * 2.0 - 1.0

## The glove's cuff with its strap, then the sleeve up to the elbow: a ribbed cuff, an
## oval forearm in uneven pieces with folds round it and a seam underneath; over it what
## some skins wear on their forearms (_arm_gear).
static func _forearm(batch: MeshBatch, palm: Vector3, wrist: Vector3, reach: Vector3) -> void:
	var axis := reach.normalized()
	var across := axis.cross(Vector3.UP).normalized()
	if across.length() < 0.5:
		across = Vector3.RIGHT
	var lift := across.cross(axis).normalized()
	_segment(batch, "glove", palm, wrist, 0.03, 0.034, GLOVE, 12)
	_segment(batch, "glove", wrist - axis * 0.004, wrist + reach * 0.075, 0.038, 0.041, GLOVE_PAD, 14)
	# The strap that closes the cuff, across its back.
	_shape(batch, ["block", "pad", KNUCKLE, wrist + reach * 0.04 + lift * 0.039, Vector3(0.026, 0.006, 0.05), Basis(across, lift, -axis)])
	var start := wrist + reach * 0.07
	# (On past the edge of the picture: seen down the arm, its end must never show.)
	var length := reach.length() * 1.35
	# Ribbed cuff of the sleeve.
	for k in range(3):
		_tube(batch, "sleeve", start + axis * (k * 0.008), 0.0465, 0.0465, 0.007, SLEEVE_CUFF, 16, Basis(across, axis, lift), false)
	# The sleeve: oval, a little wider towards the elbow, in pieces that are not quite in line.
	var pieces := 5
	var from := start + axis * 0.024
	var radius := 0.045
	for k in range(pieces):
		var t := float(k + 1) / pieces
		var to := start + axis * (0.024 + (length - 0.024) * t) + (across * _jitter(start, k) + lift * _jitter(start, k + 9.0)) * 0.0025
		var next := lerpf(0.045, 0.057, t) * (1.0 + _jitter(start, k + 3.0) * 0.04)
		var span := to - from
		var dir := span.normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var up := side.cross(dir).normalized()
		_tube(batch, "sleeve", from, radius, next, span.length(), SLEEVE.lightened(_jitter(start, k + 5.0) * 0.03), 16, Basis(side * 1.1, dir, up * 0.92), false)
		_egg(batch, "sleeve", from, Vector3(radius * 1.1, radius, radius * 0.92), SLEEVE, Basis(side, up, -dir), 14, 6)
		from = to
		radius = next
	# Folds where the sleeve gathers above the wrist and at the crook of the arm.
	for t: float in [0.09, 0.16, 0.25, 0.44, 0.58]:
		var at := start + axis * (0.024 + (length - 0.024) * t)
		var r := lerpf(0.045, 0.057, t) * 1.045
		var tilt := Basis(across, deg_to_rad(_jitter(at, 1.0) * 18.0)) * Basis(lift, deg_to_rad(_jitter(at, 2.0) * 10.0))
		_tube(batch, "sleeve", at, r, r * 0.99, 0.009, SLEEVE.darkened(0.06), 16, tilt * Basis(across * 1.08, axis, lift * 0.9), false)
	# The seam down the underside.
	_segment(batch, "sleeve", start + axis * 0.03 - lift * 0.0425, start + axis * length - lift * 0.054, 0.0022, 0.0022, SLEEVE_CUFF, 4)
	_arm_gear(batch, start, axis, across, lift, length)

## What some skins wear over the forearm (ARM_PARTS), for every skin alike: what the worn
## one has not is cut away by its material (_dress), so that changing the skin needs no
## new arms. `start`, `axis`, `across`, `lift` and `length` are the sleeve's (_forearm).
static func _arm_gear(batch: MeshBatch, start: Vector3, axis: Vector3, across: Vector3, lift: Vector3, length: float) -> void:
	# Where the sleeve's surface is, a share `t` of the way up the arm, and its radius there.
	var at := func(t: float) -> Vector3: return start + axis * (0.024 + (length - 0.024) * t)
	var radius := func(t: float) -> float: return lerpf(0.045, 0.057, t)
	var oval := Basis(across * 1.1, axis, lift * 0.92)
	# A bare forearm: slim at the wrist (where the cuff of the glove, or the bare wrist,
	# ends), fuller where the muscles are, smooth all the way (the sleeve's folds would
	# show on skin as creases).
	_loft(batch, "arm_skin", start - axis * 0.012, axis, across, lift, length + 0.012, [[0.0, 0.04, 0.035], [0.1, 0.041, 0.036], [0.3, 0.048, 0.042], [0.5, 0.053, 0.046], [0.7, 0.054, 0.047], [1.0, 0.053, 0.047]])
	# A sleeve rolled (or pushed) up: the bunched fabric half way to the elbow, the sleeve
	# going on from there.
	var roll: Vector3 = at.call(0.5)
	var thick: float = radius.call(0.5)
	for k in range(3):
		var tilt := Basis(across, deg_to_rad(_jitter(roll, k) * 7.0)) * Basis(lift, deg_to_rad(_jitter(roll, k + 4.0) * 5.0))
		batch.cylinder(shared("arm_roll"), roll + axis * (k * 0.013 - 0.02), thick * (1.2 + 0.03 * _jitter(roll, k + 7.0)), thick * (1.17 + 0.03 * _jitter(roll, k + 2.0)), 0.017, Color.WHITE, 18, tilt * oval, true)
	batch.cylinder(shared("arm_roll"), roll + axis * 0.012, thick * 1.1, radius.call(1.0) * 1.1, length * 0.5, Color.WHITE, 18, oval, false)
	# A hard shell over the top of the forearm, with a ridge along it.
	var shell: Vector3 = at.call(0.25)
	batch.ellipsoid(shared("arm_guard"), shell + lift * 0.02, Vector3(0.054, 0.036, 0.1), Color.WHITE, Basis(across, lift, axis), 18, 9)
	batch.ellipsoid(shared("arm_guard"), shell + lift * 0.05, Vector3(0.013, 0.009, 0.088), Color.WHITE, Basis(across, lift, axis), 12, 6)
	# Two straps round the forearm, each with its buckle on top.
	for t: float in [0.06, 0.2]:
		var band: Vector3 = at.call(t)
		var wide: float = radius.call(t) * 1.07
		batch.cylinder(shared("arm_straps"), band, wide, wide, 0.012, Color.WHITE, 18, oval, false)
		batch.box(shared("arm_straps"), band + axis * 0.006 + lift * (wide * 0.92 + 0.002), Vector3(0.017, 0.005, 0.018), Color.WHITE, Basis(across, lift, axis))
	# An arm warmer's laced opening along the top: the skin in the gap, the cord across it.
	var count := 8
	for k in range(count):
		var t0 := 0.03 + 0.42 * k / count
		var t1 := 0.03 + 0.42 * (k + 1) / count
		var a: Vector3 = at.call(t0) + lift * (radius.call(t0) * 0.92 + 0.0004)
		var b: Vector3 = at.call(t1) + lift * (radius.call(t1) * 0.92 + 0.0004)
		var span := b - a
		var dir := span.normalized()
		var up := across.cross(dir).normalized()
		batch.box(shared("arm_laces"), (a + b) * 0.5, Vector3(0.015, 0.003, span.length() + 0.001), Color.WHITE, Basis(across, up, dir))
		_gear_line(batch, "arm_cord", a - across * 0.0095 + up * 0.002, b + across * 0.0095 + up * 0.002, 0.0011)
		_gear_line(batch, "arm_cord", a + across * 0.0095 + up * 0.002, b - across * 0.0095 + up * 0.002, 0.0011)

## Gloved hand gripping a post-shaped grip around `grip`. `side` is +1 for the right hand.
static func _grip_hand(batch: MeshBatch, grip: Vector3, side: float, trigger_finger: bool, reach: Vector3) -> void:
	# Back of the hand lies along the outside of the grip.
	_egg(batch, "glove", grip + Vector3(side * 0.03, -0.004, 0.008), Vector3(0.017, 0.045, 0.04), GLOVE, Basis.from_euler(Vector3(0.12, 0, side * -0.1)), 10, 6)
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
	_egg(batch, "glove", thumb_tip, Vector3.ONE * 0.0098, GLOVE, Basis.IDENTITY, 8, 5)
	# The ball of the thumb, and the hard guard over the knuckles.
	_egg(batch, "glove", grip + Vector3(side * 0.018, 0.026, 0.03), Vector3(0.016, 0.02, 0.02), GLOVE, Basis.from_euler(Vector3(0.3, 0, side * 0.2)), 10, 6)
	_egg(batch, "pad", grip + Vector3(side * 0.041, -0.001, -0.02), Vector3(0.0075, 0.046, 0.016), KNUCKLE, Basis.from_euler(Vector3(0.1, side * 0.25, 0)), 12, 6)
	for finger in range(4):
		_egg(batch, "pad", grip + Vector3(side * 0.044, 0.03 - finger * 0.021, -0.02), Vector3(0.006, 0.008, 0.009), KNUCKLE.lightened(0.04), Basis.IDENTITY, 8, 5)
	_forearm(batch, grip + Vector3(side * 0.031, -0.02, 0.03), grip + Vector3(side * 0.036, -0.048, 0.052), reach)

## Support hand cradling a round handguard from below.
static func _cradle_hand(batch: MeshBatch, grip: Vector3, reach: Vector3) -> void:
	_egg(batch, "glove", grip + Vector3(-0.004, -0.042, 0.0), Vector3(0.04, 0.014, 0.046), GLOVE, Basis.from_euler(Vector3(0, 0, 0.12)), 10, 6)
	for finger in range(4):
		var along := -0.036 + finger * 0.023
		_finger(batch, grip + Vector3(0.032, -0.034, along), grip + Vector3(0.043, -0.004, along - 0.003), grip + Vector3(0.03, 0.022, along - 0.004))
	var thumb_joint := grip + Vector3(-0.043, -0.002, 0.0)
	var thumb_tip := grip + Vector3(-0.034, 0.02, -0.02)
	_segment(batch, "glove", grip + Vector3(-0.034, -0.03, 0.018), thumb_joint, 0.0125, 0.011, GLOVE)
	_segment(batch, "glove", thumb_joint, thumb_tip, 0.011, 0.0095, GLOVE)
	_egg(batch, "glove", thumb_tip, Vector3.ONE * 0.0098, GLOVE, Basis.IDENTITY, 8, 5)
	_egg(batch, "pad", grip + Vector3(0.036, -0.052, 0.0), Vector3(0.014, 0.0075, 0.046), KNUCKLE, Basis.from_euler(Vector3(0, 0, 0.5)), 12, 6)
	_forearm(batch, grip + Vector3(-0.006, -0.046, 0.036), grip + Vector3(-0.018, -0.052, 0.07), reach)

static func _finish(view: Node3D, batch: MeshBatch) -> void:
	for mesh in batch.commit(view, "Part", false):
		mesh.layers = 2
		mesh.set_meta("view_hand", true)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = VIEWS[String(view.name)].muzzle
	view.add_child(muzzle)

## The P90 is one of GUNS now (the model built by tools/blender_make_p90.py).
static func build_p90() -> Node3D:
	return build_gun("p90")

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
			var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if MODELS[id].get("baked", false) and source != null and source.albedo_texture != null:
				# A model built with baked textures of its own (the minigun) keeps them: the
				# grain laid on the plain models is mapped from the sides and would smear them.
				var slot := id + "/" + source.resource_name + ("_view" if view else "")
				if not gun_materials.has(slot):
					gun_materials[slot] = tune(source.duplicate() as BaseMaterial3D) if view else source
				mesh.set_surface_override_material(surface, gun_materials[slot])
			else:
				mesh.set_surface_override_material(surface, shotgun_material(source, view, id + "/"))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if view:
			mesh.layers = 2
	return model

## The first-person view of a weapon from MODELS: the model and the hands that hold it.
static func build_model(id: String) -> Node3D:
	var info: Dictionary = MODELS[id]
	if info.has("drum"):
		return build_m32()
	var view := Node3D.new()
	view.name = id
	var mount: Vector3 = info.mount
	var model := model_scene(id, true)
	model.position = mount
	view.add_child(model)
	var batch := MeshBatch.new()
	if info.has("grip_lean"):
		# A grip that leans otherwise than a pistol grip (the minigun's rises at the back,
		# leaning forward): the right hand is drawn as on an upright grip, under a node of its
		# own that leans it with the grip, all fingers closed round it.
		var lean := Node3D.new()
		lean.name = "HandGrip"
		lean.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(float(info.grip_lean))), mount + (info.get("grip", Vector3.ZERO) as Vector3))
		view.add_child(lean)
		var right := MeshBatch.new()
		_grip_hand(right, Vector3.ZERO, 1.0, false, lean.basis.inverse() * Vector3(0.1, -0.24, 0.22))
		for mesh in right.commit(lean, "Hand", false):
			mesh.layers = 2
			mesh.set_meta("view_hand", true)
	else:
		_grip_hand(batch, mount, 1.0, true, Vector3(0.1, -0.24, 0.22))
	var hold: Vector3 = mount + (info.support as Vector3)
	match str(info.hands):
		"bar":
			# A carry handle on top, along the gun: the hand over it, the back of the hand up
			# and out, the fingers round its far side and under it - the hand of an upright
			# grip laid onto the bar (its post along the barrel, the wrist behind) and rolled
			# by bar_roll degrees, under a node of its own.
			var turn := Basis(Vector3.BACK, deg_to_rad(float(info.get("bar_roll", -50.0)))) * Basis(Vector3.RIGHT, -PI / 2)
			var over := Node3D.new()
			over.name = "HandBar"
			over.transform = Transform3D(turn, hold)
			view.add_child(over)
			var hand := MeshBatch.new()
			# bar_reach: the way the forearm goes from the hand (out to the left, so that it
			# does not lie across the gun in the picture).
			_grip_hand(hand, Vector3.ZERO, -1.0, false, turn.inverse() * (info.get("bar_reach", Vector3(-0.17, -0.2, 0.22)) as Vector3))
			for mesh in hand.commit(over, "Hand", false):
				mesh.layers = 2
				mesh.set_meta("view_hand", true)
		"cup":
			var support := Node3D.new()
			support.name = "HandSupport"
			view.add_child(support)
			var hand := MeshBatch.new()
			_grip_hand(hand, mount + Vector3(-0.014, -0.012, 0.004), -1.0, false, Vector3(-0.16, -0.22, 0.2))
			for mesh in hand.commit(support, "Hand", false):
				mesh.layers = 2
		"cradle":
			_cradle_hand(batch, hold, Vector3(-0.13, -0.27, 0.17))
		_:
			_grip_hand(batch, hold, -1.0, false, Vector3(-0.15, -0.24, 0.2))
	_finish(view, batch)
	if MOD_MOUNTS.has(id):
		_sidearm_parts(view, id)
	return view

## The M32: model, the right hand on the pistol grip and the left one on the foregrip. The
## left hand hangs under a node of its own ("Support") that the player moves while the
## drum is loaded, and with it comes a shell ("Held") that it pushes into the drum.
static func build_m32() -> Node3D:
	var info: Dictionary = MODELS["launcher"]
	var mount: Vector3 = info.mount
	var view := Node3D.new()
	view.name = "launcher"
	var model := model_scene("launcher", true)
	model.position = mount
	view.add_child(model)
	var hand := Node3D.new()
	hand.name = "Support"
	view.add_child(hand)
	var support := MeshBatch.new()
	_grip_hand(support, mount + (info.support as Vector3), -1.0, false, Vector3(-0.15, -0.24, 0.2))
	for mesh in support.commit(hand, "Hand", false):
		mesh.layers = 2
	var held := Node3D.new()
	held.name = "Held"
	held.visible = false
	view.add_child(held)
	var shell := MeshBatch.new()
	var forward := Basis(Vector3.RIGHT, -PI / 2)
	var length: float = M32.shell
	shell.cylinder(shared("steel"), Vector3.ZERO, 0.0205, 0.0205, 0.045, Color("8c8f93"), 16, forward)
	shell.cylinder(shared("polymer"), Vector3(0, 0, -0.045), 0.0195, 0.0195, 0.03, Color("4e563a"), 16, forward)
	shell.cylinder(shared("steel"), Vector3(0, 0, -0.06), 0.0198, 0.0198, 0.008, Color("d8b24a"), 16, forward)
	shell.cylinder(shared("polymer"), Vector3(0, 0, -0.075), 0.0195, 0.006, length - 0.075, Color("4e563a"), 16, forward)
	for mesh in shell.commit(held, "Shell", false):
		mesh.layers = 2
	var batch := MeshBatch.new()
	_grip_hand(batch, mount, 1.0, true, Vector3(0.1, -0.24, 0.22))
	_finish(view, batch)
	return view

## Where, in the M32's view, the shell goes into the drum.
static func drum_mouth() -> Vector3:
	return (MODELS["launcher"].mount as Vector3) + (M32.mouth as Vector3)

## Moves the M32's parts: the drum `turn` chambers on (60 degrees each), the grenades in the
## `loaded` chambers from there on shown, the front frame swung out and the left hand at
## work while the drum is loaded (`phase`, see Survivor.DRUM, `done` 0 to 1 of it).
static func pose_drum(view: Node3D, turn: float, loaded: int, phase: String, done: float, delta: float) -> void:
	var drum := view.find_child("Drum", true, false) as Node3D
	var front := view.find_child("Front", true, false) as Node3D
	if drum == null or front == null:
		return
	var aim := deg_to_rad(60.0 * turn)
	drum.rotation.z = move_toward(drum.rotation.z, aim, delta * 16.0) if absf(drum.rotation.z - aim) < 2.2 else aim
	var top := int(floor(turn + 0.5))
	for i in range(6):
		var grenade := drum.get_node_or_null("Round%d" % i) as Node3D
		if grenade != null:
			grenade.visible = posmod(i - top, 6) < loaded
	var opened := 0.0
	match phase:
		"open":
			opened = smoothstep(0.1, 0.34, done)
		"load":
			opened = 1.0
		"close":
			opened = 1.0 - smoothstep(0.06, 0.3, done)
	front.rotation.z = deg_to_rad(float(M32.open)) * opened
	var info: Dictionary = MODELS["launcher"]
	var rest: Vector3 = info.support
	var latch: Vector3 = (M32.latch as Vector3) - rest + Vector3(-0.012, -0.02, 0.0)
	var away: Vector3 = M32.away
	var mouth: Vector3 = (M32.mouth as Vector3) - rest
	var length: float = M32.shell
	var hand := Vector3.ZERO
	var carrying := false
	match phase:
		"open":
			# To the latch, push the frame out, then down to the pouch for a shell.
			var reach := smoothstep(0.0, 0.1, done)
			var swing := smoothstep(0.1, 0.34, done)
			var fetch := smoothstep(0.4, 0.8, done)
			hand = (latch * reach + Vector3(0.06, -0.03, -0.02) * swing).lerp(away, fetch)
		"load":
			# Up with a shell in front of the drum, push it home by its nose, back for the
			# next. The shell counts (and turns up in the drum) when it is home.
			var lift := smoothstep(0.0, 0.24, done)
			var push := smoothstep(0.25, 0.4, done)
			var back := smoothstep(0.45, 0.95, done)
			var depth := lerpf(-0.02, length, push)
			var at := mouth + Vector3(0.0, -0.025, depth - length - 0.01)
			hand = away.lerp(at, lift).lerp(away, back)
			carrying = done < 0.4
		"close":
			# Swing the frame shut and take the foregrip again.
			var reach := smoothstep(0.0, 0.08, done)
			var shut := smoothstep(0.06, 0.3, done)
			var home := smoothstep(0.32, 0.8, done)
			hand = away.lerp(Vector3(0.09, -0.06, -0.06), reach).lerp(latch, shut).lerp(Vector3.ZERO, home)
	(view.get_node("Support") as Node3D).position = hand
	var held := view.get_node_or_null("Held") as Node3D
	if held != null:
		held.visible = carrying
		held.position = (info.mount as Vector3) + rest + hand + Vector3(0.0, 0.025, length + 0.01)

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
			# the other models. A magazine with textures of its own (the drum of the M21E)
			# keeps them: each textured material of the model becomes one of the view.
			if source.albedo_texture != null:
				var slot := id + "/" + source.resource_name
				if not gun_materials.has(slot):
					gun_materials[slot] = tune(source.duplicate() as BaseMaterial3D)
					# A gun whose paint came out like polished chrome is taken down a little.
					if gun.has("metal"):
						(gun_materials[slot] as BaseMaterial3D).metallic = float(gun.metal)
					if gun.has("rough"):
						(gun_materials[slot] as BaseMaterial3D).roughness_texture = null
						(gun_materials[slot] as BaseMaterial3D).roughness = float(gun.rough)
				mesh.set_surface_override_material(surface, gun_materials[slot])
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
	# A slide that runs with the shots: the model's "Breech" under a holder of its own.
	var slide := model.find_child("Breech", true, false) as Node3D
	if slide != null:
		var holder := Node3D.new()
		holder.name = "Breech"
		view.add_child(holder)
		slide.owner = null
		slide.get_parent().remove_child(slide)
		holder.add_child(slide)
		slide.position += mount
	# Where the empty cases leave it (brass.gd): "port" on a pistol, "eject" on the WIRBEL.
	if gun.has("port") or gun.has("eject"):
		var port := Node3D.new()
		port.name = "Port"
		port.position = mount + (gun.get("port", gun.get("eject")) as Vector3)
		view.add_child(port)
	var hand := Node3D.new()
	hand.name = "Support"
	view.add_child(hand)
	var support := MeshBatch.new()
	# hands: "grip" closes the hand round a foregrip instead of laying it under the handguard.
	if str(gun.get("hands", "")) == "grip":
		_grip_hand(support, mount + (gun.support as Vector3), -1.0, false, Vector3(-0.15, -0.24, 0.2))
	elif str(gun.get("hands", "")) == "cup":
		# A pistol's: the left hand closed round the right one (as build_model does).
		_grip_hand(support, mount + (gun.support as Vector3), -1.0, false, Vector3(-0.16, -0.22, 0.2))
	else:
		_cradle_hand(support, mount + (gun.support as Vector3), Vector3(-0.13, -0.27, 0.17))
	for mesh in support.commit(hand, "Hand", false):
		mesh.layers = 2
	_gun_mods(view, id)
	if gun.has("ring"):
		_ring_reticle(view, mount + (gun.ring as Vector3))
	var batch := MeshBatch.new()
	_grip_hand(batch, mount, 1.0, true, Vector3(0.1, -0.24, 0.22))
	_finish(view, batch)
	Reticle.register(view)
	return view

## The reticle of a built-in ring sight (the P90's): a thin glowing ring with a dot in its
## middle, hung in the front of its tunnel. Lit like tritium: faint, warm, seen by day and
## by night.
static func _ring_reticle(view: Node3D, at: Vector3) -> void:
	var reticle := Node3D.new()
	reticle.name = "Reticle"
	view.add_child(reticle)
	# (Colour, size and line strength are the player's: see Reticle.)
	_view_quad(reticle, at, Vector2(0.0175, 0.0175), _view_ring("ring_reticle", Color(1.0, 0.32, 0.12, 0.9))).set_meta("reticle", "ring")
	_view_quad(reticle, at + Vector3(0, 0, 0.0002), Vector2(0.0042, 0.0042), _view_glow("ring_dot", Color(1.6, 0.3, 0.1, 1.0), true)).set_meta("reticle", "core")

static func build_ump() -> Node3D:
	return build_gun("ump")

## The first-person view of any weapon: the model and the hands that hold it.
static func build_sidearm(id: String) -> Node3D:
	var view := Node3D.new()
	view.name = id
	var batch := MeshBatch.new()
	var steel := shared("steel")
	var dark := Color("23282b")
	var slide := Color("9da8ac") if id == "deagle" else Color("424a4f")
	var length := 0.25 if id == "deagle" else (0.2 if id == "usp" else 0.18)
	var width := 0.047 if id == "deagle" else 0.035
	batch.box(steel, Vector3(0, 0.014, -length * 0.3), Vector3(width, 0.052, length), slide)
	batch.box(steel, Vector3(0, -0.018, -0.035), Vector3(width * 0.92, 0.026, length * 0.7), dark)
	batch.box(steel, Vector3(0, -0.067, 0.025), Vector3(0.033, 0.105, 0.047), Color("302e29"), Basis(Vector3.RIGHT, -0.15))
	batch.box(steel, Vector3(0, -0.045, -0.04), Vector3(0.027, 0.008, 0.052), dark)
	batch.box(steel, Vector3(0, -0.029, -0.065), Vector3(0.027, 0.035, 0.008), dark)
	batch.box(steel, Vector3(0, 0.046 if id == "deagle" else 0.038, -length * 0.65), Vector3(0.008, 0.012, 0.009), dark)
	for x in [-0.014, 0.014]:
		batch.box(steel, Vector3(x, 0.043, length * 0.15), Vector3(0.008, 0.012, 0.012), dark)
	for z in [0.0, 0.009, 0.018, 0.027]:
		batch.box(steel, Vector3(width * 0.51, 0.014, z), Vector3(0.003, 0.034, 0.004), dark)
	if id == "g18":
		batch.box(steel, Vector3(0, -0.141, 0.02), Vector3(0.029, 0.072, 0.036), dark)
		batch.box(steel, Vector3(-0.021, 0.008, 0.018), Vector3(0.007, 0.017, 0.012), slide)
	for mesh in batch.commit(view, "Body", false):
		mesh.layers = 2
	batch = MeshBatch.new()
	_grip_hand(batch, Vector3(0, -0.045, 0.035), 1.0, true, Vector3(0.12, -0.25, 0.24))
	_finish(view, batch)
	var support := Node3D.new()
	support.name = "HandSupport"
	view.add_child(support)
	batch = MeshBatch.new()
	_grip_hand(batch, Vector3(-0.015, -0.06, 0.04), -1.0, false, Vector3(-0.16, -0.23, 0.23))
	for mesh in batch.commit(support, "Hand", false):
		mesh.layers = 2
	_sidearm_parts(view, id)
	return view

static func _sidearm_parts(view: Node3D, id: String) -> void:
	_gun_mods(view, id)
	var twin := view.duplicate() as Node3D
	twin.name = "Mod_akimbo"
	var support := twin.get_node_or_null("HandSupport")
	if support != null:
		twin.remove_child(support)
		support.free()
	twin.position.x = -0.28
	twin.scale.x = -1.0
	twin.hide()
	view.add_child(twin)
	Reticle.register(view)

static func build(id: String) -> Node3D:
	if id in ["usp", "g18", "deagle"]:
		return build_sidearm(id)
	match id:
		"badger":
			return build_badger()
		"shotgun":
			return build_shotgun()
	return build_gun(id) if GUNS.has(id) else build_model(id)

## A weapon by itself, to be looked at (the shop, the workbench): the model of the view
## without the hands, its middle at the origin, the muzzle towards -z. The parts that can
## be fitted are in it under "Mod_...", hidden. The materials are the view's without what
## only that view wants, so that any camera shows it right. Metadata "size": its extent.
static func display(id: String) -> Node3D:
	var view := build(id)
	for node in view.find_children("*", "", true, false):
		# Freed with what held it (the hands under "Support").
		if not is_instance_valid(node):
			continue
		var title := str(node.name)
		# Hands and arms: what the builders commit as "Part" straight under the view, as
		# "Hand" under the forend, and the hand that changes the magazine.
		if title == "Support" or title.begins_with("Hand") or bool(node.get_meta("view_hand", false)) or (title.begins_with("Part") and node.get_parent() == view and node is MeshInstance3D):
			node.get_parent().remove_child(node)
			node.free()
	var box := AABB()
	var first := true
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.layers = 1
		if mesh.material_override != null:
			mesh.material_override = _plain(mesh.material_override)
		elif mesh.mesh != null:
			for surface in range(mesh.mesh.get_surface_count()):
				mesh.set_surface_override_material(surface, _plain(mesh.get_active_material(surface)))
		# What is hidden (a part not fitted, the shell of the shotgun) does not count.
		var shown := true
		var frame := Transform3D.IDENTITY
		var at: Node = mesh
		while at != view and at != null:
			if at is Node3D:
				shown = shown and (at as Node3D).visible
				frame = (at as Node3D).transform * frame
			at = at.get_parent()
		if shown and mesh.mesh != null:
			var part: AABB = frame * mesh.mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
	var holder := Node3D.new()
	holder.name = "Display"
	holder.add_child(view)
	view.position = -box.get_center()
	holder.set_meta("size", box.size)
	return holder

static var plain_materials: Dictionary = {}

## A material of the first-person view without that view's own field of view and its
## squeezed depth.
static func _plain(material: Material) -> Material:
	var source := material as BaseMaterial3D
	if source == null or not (source.use_fov_override or source.use_z_clip_scale):
		return material
	if not plain_materials.has(source):
		var copy := source.duplicate() as BaseMaterial3D
		copy.use_fov_override = false
		copy.use_z_clip_scale = false
		plain_materials[source] = copy
	return plain_materials[source]

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

static func _view_quad(parent: Node3D, at: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.position = at
	node.layers = 2
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

## A round lens: faintly tinted glass in a disc that ends at its rim.
static func _view_disc(key: String, color: Color) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.albedo_color = color
	var edge := Gradient.new()
	edge.colors = PackedColorArray([Color(1, 1, 1, 0.6), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	edge.offsets = PackedFloat32Array([0.0, 0.96, 0.99])
	var disc := GradientTexture2D.new()
	disc.gradient = edge
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(0.5, 0.0)
	disc.width = 96
	disc.height = 96
	result.albedo_texture = disc
	materials[key] = tune(result)
	return result

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
	# (The player's line strength widens the band: Reticle.paint.)
	Reticle.ring_band = band
	var circle := GradientTexture2D.new()
	circle.gradient = band
	circle.fill = GradientTexture2D.FILL_RADIAL
	circle.fill_from = Vector2(0.5, 0.5)
	circle.fill_to = Vector2(0.5, 0.0)
	circle.width = 192
	circle.height = 192
	result.albedo_texture = circle
	materials[key] = tune(result)
	return result

## How high the middle of a sight's glass stands above the gun's origin. The reflex sight
## brings its height with it (its window stands well above any iron sights); the telescopic
## sight is set just clear of them, so that they do not stand in the picture.
const MOD_MOUNTS := {
	"pistol": {"mount": Vector3.ZERO, "rail": 0.0122, "optic": -0.02, "irons": 0.027, "holo": 0.45, "muzzle": Vector3(0, 0.005, -0.1035)},
	# (Measured on the models with rays from above: the revolver's frame is flat on top over
	# the cylinder at 3.25 cm, from 1 cm before to 5 cm behind the middle of its grip, its
	# rear sight 3.7 cm high; the pistol's slide is flat at 1.2 cm from 5 cm before to 1 cm
	# behind it, its front sight 2.7 cm high.)
	"revolver": {"mount": Vector3.ZERO, "rail": 0.0325, "optic": 0.02, "irons": 0.0372, "holo": 0.45, "muzzle": Vector3(0, 0.011, -0.161)},
	"usp": {"mount": Vector3.ZERO, "rail": 0.05, "optic": -0.04, "irons": 0.05, "holo": 0.45, "muzzle": Vector3(0, 0.015, -0.145)},
	"g18": {"mount": Vector3.ZERO, "rail": 0.045, "optic": -0.04, "irons": 0.045, "holo": 0.45, "muzzle": Vector3(0, 0.01, -0.13)},
	"deagle": {"mount": Vector3.ZERO, "rail": 0.06, "optic": -0.05, "irons": 0.06, "holo": 0.5, "muzzle": Vector3(0, 0.025, -0.185)}
}

static func mod_mount(id: String) -> Dictionary:
	return GUNS[id] if GUNS.has(id) else MOD_MOUNTS[id]

static func sight_height(id: String, sight: String) -> float:
	var gun: Dictionary = mod_mount(id)
	if sight == "reddot":
		var size := dot_size(id)
		var low := DOT_AXIS * size
		if not gun.get("folding", false):
			low = maxf(low, float(gun.irons) - float(gun.rail) + (DOT_RADIUS + 0.003) * size)
		else:
			# Over iron sights that fold away it stands at their height, as a red dot on a riser
			# does (the eye where it was over the irons).
			low = maxf(low, float(gun.irons) - float(gun.rail))
		return float(gun.rail) + low
	# Iron sights that fold away leave nothing for a sight to clear.
	var clear := (0.0 if gun.get("folding", false) else maxf(float(gun.irons) - float(gun.rail), 0.0)) + 0.006
	return float(gun.rail) + clear + 0.0195

## How big the holographic sight is on a gun (1: as it was made).
static func holo_size(id: String) -> float:
	return float(mod_mount(id).get("holo", 1.0))

## How big the red dot is on a gun: smaller on the sidearms and the machine pistol.
static func dot_size(id: String) -> float:
	return 0.72 if MOD_MOUNTS.has(id) or id == "hornet" else 1.0

## Where the weapon sits when the eye is behind a fitted sight.
static func sight_aim(id: String, sight: String) -> Vector3:
	var gun: Dictionary = mod_mount(id)
	var mount: Vector3 = gun.mount
	var along := mount.z + float(gun.optic)
	if sight == "reddot":
		# A smaller sight is looked through from closer by: the picture stays the same.
		var size := dot_size(id)
		return Vector3(0.0, -(mount.y + sight_height(id, sight)), -DOT_EYE * size - (along + DOT_LENGTH * size * 0.5))
	return Vector3(0.0, -(mount.y + sight_height(id, sight)), -SCOPE_EYE - (along + 0.066))

## The parts the shop sells for a gun, each under a node of its own.
static func _gun_mods(view: Node3D, id: String) -> void:
	var gun: Dictionary = mod_mount(id)
	var mount: Vector3 = gun.mount
	var rail := mount.y + float(gun.rail)
	var z := mount.z + float(gun.optic)
	var dark := Color("15171a")
	var metal := Color("23262a")
	var steel := shared("steel")
	var ahead := Basis(Quaternion(Vector3.UP, Vector3.FORWARD))
	# --- Red dot: a short round tube of black anodised aluminium on a low mount, a clear
	# round lens, a bright dot with a soft glow in its middle. Where iron sights stand
	# (not folding ones) the mount lifts it until they are below the lens.
	var reflex := Node3D.new()
	reflex.name = "Mod_reddot"
	view.add_child(reflex)
	var size := dot_size(id)
	var centre := mount.y + sight_height(id, "reddot")
	if holo_material == null:
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.085, 0.09, 0.095)
		paint.roughness = 0.5
		paint.metallic = 0.35
		paint.metallic_specular = 0.4
		holo_material = tune(paint)
	var inner := DOT_RADIUS * size
	var outer := inner + DOT_WALL * size
	var length := DOT_LENGTH * size
	var body := MeshBatch.new()
	var hoop := func(radius: float, thick: float, at_z: float, long: float) -> void:
		var pieces := 28
		for k in range(pieces):
			var angle := TAU * k / pieces
			var mid := radius + thick * 0.5
			var chord := TAU * mid / pieces * 1.1
			body.box(holo_material, Vector3(cos(angle) * mid, centre + sin(angle) * mid, at_z), Vector3(chord, thick, long), Color.WHITE, Basis(Vector3.BACK, angle - PI / 2))
	hoop.call(inner, DOT_WALL * size, z, length)
	# Lips at both ends, a little proud of the tube.
	hoop.call(inner - 0.0006 * size, (DOT_WALL + 0.0016) * size, z + length * 0.5 - 0.002 * size, 0.004 * size)
	hoop.call(inner - 0.0004 * size, (DOT_WALL + 0.0012) * size, z - length * 0.5 + 0.0015 * size, 0.003 * size)
	# The mount down to the rail with its clamp, and the knob for the brightness.
	var rail_top := mount.y + float(gun.rail)
	var stand := centre - outer + 0.001 - rail_top
	if stand > 0.0:
		body.box(holo_material, Vector3(0, rail_top + stand * 0.5, z), Vector3(0.017 * size, stand, length * 0.8), Color.WHITE)
	body.box(holo_material, Vector3(0, rail_top + 0.0035 * size, z), Vector3(0.026 * size, 0.007 * size, length * 0.9), Color.WHITE)
	body.cylinder(holo_material, Vector3(0.013 * size, rail_top + 0.0035 * size, z), 0.0025 * size, 0.0025 * size, 0.004 * size, Color.WHITE, 8, Basis(Vector3.BACK, -PI / 2))
	body.cylinder(holo_material, Vector3(outer, centre - inner * 0.35, z - length * 0.1), 0.0055 * size, 0.0055 * size, 0.0035 * size, Color.WHITE, 14, Basis(Vector3.BACK, -PI / 2))
	for mesh in body.commit(reflex, "Part", false):
		mesh.layers = 2
		mesh.set_surface_override_material(0, holo_material)
	# The lens sits near the front; the dot keeps the size it has to the eye, whatever the
	# distance of the lens: far easier to see than the old fine mark.
	var lens_z := z - length * 0.2
	var seen := (DOT_EYE * size + length * 0.7) / MARK_EYE
	_view_quad(reflex, Vector3(0, centre, lens_z), Vector2(inner, inner) * 2.0, _view_disc("lens_round", Color(0.45, 0.72, 0.78, 0.06)))
	# (Colour, size and line strength are the player's: see Reticle.)
	_view_quad(reflex, Vector3(0, centre, lens_z + 0.0002), Vector2(0.02, 0.02) * seen, _view_glow("dot_halo", Color(1.0, 0.1, 0.05, 0.32), true)).set_meta("reticle", "halo")
	_view_quad(reflex, Vector3(0, centre, lens_z + 0.0003), Vector2(0.0055, 0.0055) * seen, _view_glow("dot_bright", Color(1.85, 0.16, 0.08, 1.0), true)).set_meta("reticle", "core")
	# --- Telescopic sight, four times: tube, bell and eyepiece on two rings.
	var scope := Node3D.new()
	scope.name = "Mod_scope"
	view.add_child(scope)
	var axis := mount.y + sight_height(id, "scope")
	var batch := MeshBatch.new()
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
	# --- Laser module: on the right side of the handguard (the guns of GUNS only).
	if GUNS.has(id):
		LaserSight.fit_module(view, id)

## Where the magazine and the hand that changes it are at a moment of the reload (0 to 1),
## as offsets from where they rest.
static func reload_step(id: String, done: float) -> Dictionary:
	if not GUNS.has(id) or done <= 0.0 or done >= 1.0:
		return {"magazine": Vector3.ZERO, "hand": Vector3.ZERO}
	var gun: Dictionary = GUNS[id]
	var out: Vector3 = (gun.magazine_out as Vector3) * 0.25
	# Where the hand takes the empty one: out of the picture (after Henry: when the same
	# magazine only went off and straight back on, it did not read as a change). Unless the
	# gun names a place (magazine_away), on along the way it came out, a metre from the well.
	var away: Vector3 = gun.get("magazine_away", gun.magazine_out)
	var rest: Vector3 = gun.support
	var foot: Vector3 = (gun.magazine_foot as Vector3) + Vector3(0.0, 0.035, 0.004) - rest
	var handle: Vector3 = (gun.handle as Vector3) + Vector3(-0.016, 0.034, 0.0) - rest
	# The hand lets go of the handguard and takes the magazine by its foot, pulls it out,
	# carries it away out of the picture, comes back with a full one and seats it ...
	var grab := smoothstep(0.0, 0.13, done) * (1.0 - smoothstep(0.66, 0.8, done))
	var pull := smoothstep(0.14, 0.26, done) * (1.0 - smoothstep(0.55, 0.62, done))
	var gone := smoothstep(0.27, 0.4, done) * (1.0 - smoothstep(0.43, 0.55, done))
	var magazine := out * pull + (away - out) * gone
	# ... and slaps the cocking handle on its way back to the handguard.
	var up := smoothstep(0.66, 0.8, done) * (1.0 - smoothstep(0.9, 1.0, done))
	var slap := smoothstep(0.8, 0.86, done) * (1.0 - smoothstep(0.86, 0.94, done))
	return {"magazine": magazine, "hand": foot * grab + magazine + handle * up + Vector3(0.0, -0.022, 0.05) * slap, "away": gone}

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
