class_name Survivor
extends CharacterBody3D
## Input and local weapon behaviour. Damage and rewards are resolved by Game.

const BASE_FOV := 74.0
## slot: number key, the one of the weapon's kind (KINDS). price: cost in the weapon shop.
## flash: size of the muzzle flash.
const WEAPONS := {
	"rifle": {"label": "M4A4", "slot": 1, "price": 0, "sound": "shot", "magazine": 30, "reserve_max": 180, "reload_time": 1.75, "interval": 0.115, "damage": 28.0, "head_multiplier": 2.7, "spread": 0.011, "kick": 0.011, "flash": 1.0, "cues": [[0.15, "mag_out"], [0.62, "mag_in"], [0.85, "bolt"]]},
	# The AK-47: harder hits, more kick. Parts: see ATTACHMENTS.
	"ak": {"label": "AK-47", "slot": 1, "price": 300, "sound": "ak", "magazine": 30, "reserve_max": 180, "reload_time": 2.5, "interval": 0.1, "damage": 36.0, "head_multiplier": 2.6, "spread": 0.014, "kick": 0.014, "flash": 1.1, "cues": [[0.15, "mag_out"], [0.62, "mag_in"], [0.85, "bolt"]]},
	# The G36: the quickest and steadiest of the rifles, with a reload that sounds like no
	# other's. Parts: see ATTACHMENTS.
	"g36": {"label": "G36", "slot": 1, "price": 450, "sound": "g36", "magazine": 30, "reserve_max": 240, "reload_time": 2.2, "interval": 0.08, "damage": 35.0, "head_multiplier": 2.7, "spread": 0.0085, "kick": 0.009, "flash": 1.0, "cues": [[0.15, "g36_mag_out"], [0.62, "g36_mag_in"], [0.85, "g36_bolt"]]},
	"p90": {"label": "P90", "slot": 1, "price": 100, "sound": "p90", "magazine": 50, "reserve_max": 250, "reload_time": 2.15, "interval": 0.075, "damage": 23.0, "head_multiplier": 3.0, "spread": 0.016, "kick": 0.0072, "flash": 0.85},
	# cues: when in its reload each step is heard. Parts for it: see ATTACHMENTS.
	"ump": {"label": "UMP45", "slot": 1, "price": 220, "sound": "ump", "magazine": 25, "reserve_max": 200, "reload_time": 2.3, "interval": 0.1, "damage": 31.0, "head_multiplier": 2.8, "spread": 0.013, "kick": 0.0095, "flash": 0.9, "cues": [[0.15, "mag_out"], [0.62, "mag_in"], [0.85, "bolt"]]},
	# quiet: a suppressed shot gives nobody the direction it came from.
	"badger": {"label": "HONEY BADGER", "slot": 1, "price": 350, "quiet": true, "sound": "badger", "magazine": 30, "reserve_max": 210, "reload_time": 1.9, "interval": 0.082, "damage": 34.0, "head_multiplier": 2.6, "spread": 0.008, "kick": 0.0085, "flash": 0.4},
	# pellets: shots per blast, each doing `damage`. shells: loaded one at a time, `reload_time`
	# each. punch: how hard the weapon slams back. settle: share of the muzzle climb that
	# comes back down by itself. push: how fast a blast from close by throws back whoever
	# it does not kill, in metres a second with every pellet on the body.
	"shotgun": {"label": "SCHROTFLINTE", "slot": 1, "price": 250, "sound": "shotgun", "magazine": 6, "reserve_max": 42, "reload_time": 0.52, "interval": 0.95, "damage": 24.0, "head_multiplier": 1.5, "spread": 0.05, "kick": 0.066, "flash": 2.2, "pellets": 9, "shells": true, "punch": 3.1, "settle": 0.72, "push": 8.5},
	# group: the shop tab it is sold on. from_round: the round after which the shop has it.
	"pistol": {"label": "M9 PISTOLE", "slot": 2, "price": 60, "group": "sidearms", "sound": "pistol", "magazine": 15, "reserve_max": 120, "reload_time": 1.35, "interval": 0.15, "damage": 26.0, "head_multiplier": 3.0, "spread": 0.012, "kick": 0.014, "flash": 0.8},
	"revolver": {"label": ".44 MAGNUM", "slot": 2, "price": 220, "group": "sidearms", "sound": "revolver", "magazine": 6, "reserve_max": 60, "reload_time": 2.4, "interval": 0.5, "damage": 110.0, "head_multiplier": 2.4, "spread": 0.006, "kick": 0.05, "flash": 1.5, "punch": 2.0, "settle": 0.8},
	"autoshotgun": {"label": "AUTO-SCHROTFLINTE", "slot": 3, "price": 500, "group": "heavy", "sound": "autoshotgun", "magazine": 8, "reserve_max": 56, "reload_time": 2.3, "interval": 0.3, "damage": 17.0, "head_multiplier": 1.5, "spread": 0.06, "kick": 0.038, "flash": 2.0, "pellets": 8, "punch": 2.1, "settle": 0.7, "push": 4.5},
	# scope: field of view through the sight. pierce: how many more bodies a bullet goes
	# through. bolt: the action is worked by hand after every shot.
	"sniper": {"label": "SCHARFSCHÜTZENGEWEHR", "slot": 3, "price": 450, "group": "heavy", "sound": "sniper", "magazine": 5, "reserve_max": 40, "reload_time": 2.6, "interval": 1.2, "damage": 260.0, "head_multiplier": 2.5, "spread": 0.03, "kick": 0.06, "flash": 1.6, "punch": 2.4, "settle": 0.85, "scope": 13.0, "pierce": 3, "bolt": true},
	# grenade: fires 40 mm shells that go off where they land.
	"launcher": {"label": "GRANATWERFER", "slot": 3, "price": 900, "group": "heavy", "from_round": 4, "sound": "launcher", "magazine": 6, "reserve_max": 18, "reload_time": 3.4, "interval": 0.75, "damage": 0.0, "head_multiplier": 1.0, "spread": 0.0, "kick": 0.05, "flash": 0.9, "punch": 2.2, "settle": 0.8, "grenade": true},
	# spin: seconds the barrels need to come up to speed before the first shot.
	# The machine gun: a hundred rounds in the box and four boxes more. Shares its key with
	# the minigun.
	"mg": {"label": "MASCHINENGEWEHR", "slot": 3, "price": 800, "group": "heavy", "from_round": 3, "sound": "mg", "magazine": 100, "reserve_max": 400, "reload_time": 4.2, "interval": 0.085, "damage": 30.0, "head_multiplier": 2.2, "spread": 0.022, "kick": 0.0085, "flash": 1.2, "cues": [[0.14, "mag_out"], [0.6, "mag_in"], [0.86, "bolt"]]},
	"minigun": {"label": "MINIGUN", "slot": 3, "price": 1500, "group": "heavy", "from_round": 6, "sound": "minigun", "magazine": 200, "reserve_max": 600, "reload_time": 4.5, "interval": 0.045, "damage": 21.0, "head_multiplier": 1.8, "spread": 0.03, "kick": 0.0035, "flash": 1.1, "spin": 0.55},
	# semi: one shot for every pull of the trigger. zoom and aim_spread: see ATTACHMENTS.
	"m14": {"label": "M14", "slot": 1, "price": 320, "sound": "m14", "semi": true, "magazine": 20, "reserve_max": 140, "reload_time": 2.3, "interval": 0.2, "damage": 100.0, "head_multiplier": 2.6, "spread": 0.006, "kick": 0.028, "flash": 1.3, "punch": 1.6, "settle": 0.6, "zoom": 38.0, "aim_spread": 0.3, "pierce": 1},
	"svd": {"label": "SVD DRAGUNOW", "slot": 3, "price": 650, "group": "heavy", "from_round": 2, "sound": "svd", "semi": true, "magazine": 10, "reserve_max": 60, "reload_time": 2.7, "interval": 0.38, "damage": 165.0, "head_multiplier": 2.4, "spread": 0.02, "kick": 0.04, "flash": 1.4, "punch": 1.8, "settle": 0.85, "scope": 15.0, "pierce": 1},
	# The three below belong to a tree of abilities each (Skills.TREES, weapons): the shop
	# sells them only to somebody who has put points into that tree.
	# flame: no bullets but a stream of fire (see _flame); its magazine is its tank.
	"flamer": {"label": "FLAMMENWERFER", "slot": 3, "price": 700, "group": "class", "sound": "flamer", "magazine": 150, "reserve_max": 300, "reload_time": 3.2, "interval": 0.06, "damage": 9.0, "head_multiplier": 1.0, "spread": 0.0, "kick": 0.0, "flash": 0.0, "flame": true},
	# special: factor on what it does to special infected.
	"nitro": {"label": "DOPPELBÜCHSE .600", "slot": 3, "price": 650, "group": "class", "sound": "nitro", "semi": true, "magazine": 2, "reserve_max": 36, "reload_time": 2.5, "interval": 0.25, "damage": 430.0, "head_multiplier": 1.8, "spread": 0.012, "kick": 0.085, "flash": 1.9, "punch": 3.0, "settle": 0.85, "zoom": 42.0, "aim_spread": 0.3, "special": 1.5, "pierce": 1},
	# shield: share of its damage that goes through a shield. armour: share of what a
	# soldier's armour stops that it still stops against this weapon.
	"fifty": {"label": "M107 KALIBER .50", "slot": 3, "price": 900, "group": "class", "sound": "fifty", "semi": true, "magazine": 5, "reserve_max": 30, "reload_time": 3.4, "interval": 0.7, "damage": 520.0, "head_multiplier": 2.0, "spread": 0.03, "kick": 0.075, "flash": 2.0, "punch": 3.0, "settle": 0.9, "scope": 11.0, "pierce": 4, "shield": 1.0, "armour": 0.0}
}
## Shots with these sounds are suppressed (what a co-op guest's shot is known by).
const QUIET_SOUNDS := ["badger", "ump_sil", "ak_sil", "g36_sil"]
const ORDER := ["rifle", "ak", "g36", "p90", "ump", "badger", "m14", "shotgun", "pistol", "revolver", "autoshotgun", "sniper", "svd", "launcher", "mg", "minigun", "flamer", "nitro", "fifty"]
## The three kinds of weapon: the key that takes one in hand, what the interface calls
## it, and the shop lists whose weapons are of that kind. A survivor carries CARRY of each
## kind, and as many more of any kind as slings were bought (extra_slots).
const KINDS := {
	"primary": {"key": 1, "label": "PRIMÄRWAFFE", "groups": ["weapons"]},
	"secondary": {"key": 2, "label": "SEKUNDÄRWAFFE", "groups": ["sidearms"]},
	"heavy": {"key": 3, "label": "SCHWERE WAFFE", "groups": ["heavy", "class"]}
}
const CARRY := 1
## What the workbench does to a weapon, line by line. key: where the weapon's record keeps
## the level of the line ("level" is the damage, as it always was). prices: one for each
## level, before the difficulty's factor. step: what one level gives (damage: per shot;
## the others: a share).
const UPGRADES := {
	"damage": {"label": "SCHADEN", "key": "level", "prices": [250, 250, 250], "step": 10.0},
	"mags": {"label": "MAGAZIN", "key": "mags", "prices": [200], "step": 0.5},
	"pouch": {"label": "MUNITION", "key": "pouch", "prices": [150, 220], "step": 0.25},
	"drill": {"label": "NACHLADEN", "key": "drill", "prices": [180, 260], "step": 0.12},
	"brace": {"label": "STABILITÄT", "key": "brace", "prices": [150, 220], "step": 0.15}
}
## What a level of damage gives a weapon that fires no bullets (flame, shells): a share.
const UPGRADE_SHARE := 0.15
## Parts the shop sells for a weapon. slot: only one part per slot is on the weapon at a
## time. set: values of the weapon's table that the part replaces (aim_spread: how much of
## the scatter is left when aiming; zoom: field of view when aiming; scope: field of view
## through a telescopic sight; scope_turn: how much slower the view turns through it).
## scale: values it multiplies.
const ATTACHMENTS := {
	"rifle": {
		"reddot": {"label": "ROTPUNKTVISIER", "price": 120, "slot": "sight", "note": "Holografisches Visier: Leuchtpunkt im Ring statt Kimme und Korn, genauer beim Zielen", "set": {"zoom": 40.0, "aim_spread": 0.55}},
		"scope": {"label": "ZIELFERNROHR 4×", "price": 260, "slot": "sight", "note": "Vierfache Vergrößerung für Schüsse quer über den Hof", "set": {"scope": 18.0, "scope_turn": 0.36, "aim_spread": 0.35}},
		"silencer": {"label": "SCHALLDÄMPFER", "price": 180, "slot": "muzzle", "note": "Leise, wenig Mündungsfeuer – die C.R.U. weicht nicht mehr aus", "set": {"sound": "badger", "flash": 0.35, "quiet": true}, "scale": {"kick": 0.8, "spread": 0.92, "damage": 0.95}}
	},
	"g36": {
		"reddot": {"label": "ROTPUNKTVISIER", "price": 120, "slot": "sight", "note": "Holografisches Visier: Leuchtpunkt im Ring über Kimme und Korn, genauer beim Zielen", "set": {"zoom": 40.0, "aim_spread": 0.55}},
		"scope": {"label": "ZIELFERNROHR 4×", "price": 260, "slot": "sight", "note": "Vierfache Vergrößerung für Schüsse quer über den Hof", "set": {"scope": 18.0, "scope_turn": 0.36, "aim_spread": 0.35}},
		"silencer": {"label": "SCHALLDÄMPFER", "price": 180, "slot": "muzzle", "note": "Leise, wenig Mündungsfeuer – die C.R.U. weicht nicht mehr aus", "set": {"sound": "g36_sil", "flash": 0.35, "quiet": true}, "scale": {"kick": 0.8, "spread": 0.92, "damage": 0.95}}
	},
	"ump": {
		"reddot": {"label": "ROTPUNKTVISIER", "price": 120, "slot": "sight", "note": "Holografisches Visier: Leuchtpunkt im Ring, freie Sicht aufs Ziel, genauer beim Zielen", "set": {"zoom": 40.0, "aim_spread": 0.55}},
		"scope": {"label": "ZIELFERNROHR 4×", "price": 260, "slot": "sight", "note": "Vierfache Vergrößerung für Schüsse quer über den Hof", "set": {"scope": 18.0, "scope_turn": 0.36, "aim_spread": 0.35}},
		"silencer": {"label": "SCHALLDÄMPFER", "price": 180, "slot": "muzzle", "note": "Leise, wenig Mündungsfeuer – die C.R.U. weicht nicht mehr aus", "set": {"sound": "ump_sil", "flash": 0.32, "quiet": true}, "scale": {"kick": 0.75, "spread": 0.9, "damage": 0.95}}
	},
	"ak": {
		"reddot": {"label": "ROTPUNKTVISIER", "price": 120, "slot": "sight", "note": "Holografisches Visier: Leuchtpunkt im Ring, freie Sicht aufs Ziel, genauer beim Zielen", "set": {"zoom": 40.0, "aim_spread": 0.55}},
		"scope": {"label": "ZIELFERNROHR 4×", "price": 260, "slot": "sight", "note": "Vierfache Vergrößerung: macht die AK zum Gewehr für die Distanz", "set": {"scope": 18.0, "scope_turn": 0.36, "aim_spread": 0.35}},
		"silencer": {"label": "SCHALLDÄMPFER", "price": 200, "slot": "muzzle", "note": "Leise, wenig Mündungsfeuer – die C.R.U. weicht nicht mehr aus", "set": {"sound": "ak_sil", "flash": 0.35, "quiet": true}, "scale": {"kick": 0.8, "spread": 0.92, "damage": 0.95}}
	}
}
## What the shop sells besides weapons. group: its tab in the shop. max: how many fit in
## the pockets. The mask is bought level by level.
const GOODS := {
	"grenade": {"label": "SPLITTERGRANATE", "price": 60, "max": 4, "group": "use", "note": "Taste G. Reißt alles im Umkreis mit – auch dich."},
	"flashbang": {"label": "BLENDGRANATE", "price": 45, "max": 4, "group": "use", "note": "Taste T. Betäubt Infizierte für einige Sekunden."},
	"molotov": {"label": "MOLOTOWCOCKTAIL", "price": 70, "max": 3, "group": "use", "note": "Taste H. Zerplatzt beim Aufschlag: Der Boden brennt einige Sekunden, und wer hindurchläuft, brennt weiter."},
	"claymore": {"label": "CLAYMORE", "price": 90, "max": 4, "group": "use", "note": "Taste B. Zündet, sobald etwas davor läuft."},
	"revive": {"label": "ADRENALINSPRITZE", "price": 300, "max": 1, "group": "use", "note": "Rettet dich einmal, wenn dein Leben auf null fällt."},
	"vest": {"label": "SCHUTZWESTE", "price": 150, "group": "gear", "note": "50 Rüstung. Rüstung fängt 60 % jedes Treffers ab."},
	"armor": {"label": "SCHWERE RÜSTUNG", "price": 300, "group": "gear", "note": "100 Rüstung."},
	"plates": {"label": "BALLISTISCHE WESTE", "prices": [160, 260, 400], "group": "gear", "note": "C.R.U.-Kugeln und -Granaten: 25 / 40 / 55 % weniger Schaden"},
	"sling": {"label": "WAFFENGURT", "prices": [250, 400, 600], "group": "gear", "note": "Platz für eine Waffe mehr, egal welcher Art. Ohne Gurt trägst du je eine Primär-, eine Sekundär- und eine schwere Waffe."},
	"mask": {"label": "GASMASKE", "prices": [150, 250, 400, 600], "group": "gear", "note": "Vier Stufen: Filter für 8, 20, 45 und 120 Sekunden im Giftgas."},
	# For the two who come along (Game.squad_levels); nothing the survivor carries.
	"squad_armor": {"label": "TEAM: SCHUTZPLATTEN", "prices": [180, 300, 450], "group": "team", "note": "Deine Begleiter halten mehr aus: +30 % Leben je Stufe."},
	"squad_ammo": {"label": "TEAM: SCHARFE MUNITION", "prices": [180, 300, 450], "group": "team", "note": "Deine Begleiter treffen härter: +20 % Schaden je Stufe."}
}
## Seconds of clean air a mask of each level holds.
const MASK_SECONDS := [0.0, 8.0, 20.0, 45.0, 120.0]
## Share of a hit that armour takes instead of the body.
const ARMOR_SHARE := 0.6
## Share of what the C.R.U. shoot and throw that ballistic plates of each level take away.
const PLATE_SHARES := [0.0, 0.25, 0.4, 0.55]
## Moments of the shotgun's pump stroke after a shot, in seconds: back, then forward again.
const PUMP_BACK := 0.26
const PUMP_DONE := 0.56
const PUMP_TRAVEL := 0.09
## Moments of a reload, as a share of its duration, and the sound each one makes.
const RELOAD_CUES := [[0.07, "mag_out"], [0.56, "mag_in"], [0.84, "bolt"]]
var current_weapon := "rifle"
var inventory: Dictionary = {"rifle": {"ammo": 30, "reserve": 180, "level": 0}}
var weapon_models: Dictionary = {}
var game: Node3D
var camera: Camera3D
var weapon: Node3D
var flash: Node3D
var flash_light: OmniLight3D
var flash_mesh: MeshInstance3D
var flashlight: SpotLight3D
var health := 100.0
var ammo: int:
	get: return int(inventory[current_weapon].ammo)
	set(value): inventory[current_weapon].ammo = value
var reserve: int:
	get: return int(inventory[current_weapon].reserve)
	set(value): inventory[current_weapon].reserve = value
var weapon_level: int:
	get: return int(inventory[current_weapon].level)
	set(value): inventory[current_weapon].level = value
var sensitivity := 0.0022
var controlled := false
## A menu lies over a running co-op match: no input, but the world goes on.
var menu_open := false
## Co-op: out of the fight until the partner helps or the round ends.
var down := false
var items := {"grenade": 0, "flashbang": 0, "molotov": 0, "claymore": 0, "revive": 0}
var armor := 0.0
## Level of the ballistic plates, 0 to 3.
var plate_level := 0
var mask_level := 0
var filter_left := 0.0
## True while the survivor stands in gas, with or without a mask.
var in_gas := false
var throw_cooldown := 0.0
## A grenade held ready ("grenade" or "flashbang", "" for none), how long it has been
## held, the seconds left until it leaves the hand once the key is let go (-1: still
## held), and how far the weapon has dipped out of the way (0 to 1).
## A shell from the launcher: how fast it leaves, and how much it is lobbed upwards. Slow
## enough to be watched on its way, and it comes down in an arc instead of going straight.
## (Speed and lift times 0.74 and Throwable.SHELL_PULL times 0.74 squared keep the arc.)
const LAUNCH_SPEED := 18.5
const LAUNCH_LIFT := 1.92
## Seconds of flight the aiming arc shows.
const LAUNCH_SHOWN := 4.8
const THROW_SWING := 0.16
const THROW_AIM_AFTER := 0.2
## The key that readies and throws each thing.
const THROW_KEYS := {"grenade": "throw_grenade", "flashbang": "throw_flash", "molotov": "throw_molotov"}
## A blow with the weapon (key V): how far it reaches and how wide (the cosine of half its
## angle), what it does, how fast whoever is struck is thrown back and for how long he
## reels, and the seconds until the next blow.
const MELEE_REACH := 2.4
const MELEE_CONE := 0.4
const MELEE_DAMAGE := 30.0
const MELEE_PUSH := 6.5
const MELEE_DAZE := 1.7
const MELEE_GAP := 0.85
## A blast of shot throws a body back with its full force up to PUSH_NEAR metres and not
## at all beyond PUSH_FAR; slower than PUSH_LEAST it moves nobody.
const PUSH_NEAR := 3.0
const PUSH_FAR := 12.0
const PUSH_LEAST := 0.8
## The syringe every survivor carries (key Q): the health it gives back, the seconds until
## it is ready again, and how long the hands are busy with it.
const SYRINGE_HEAL := 30.0
const SYRINGE_WAIT := 8.0
const SYRINGE_TIME := 0.75
## Ducked (key C, on and off): how high the eyes and the body are then, how fast the
## survivor moves, and the share of a weapon's scatter and kick that is left.
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.2
const CROUCH_EYE := 1.12
const CROUCH_SPEED := 2.4
const CROUCH_STEADY := 0.7
## Share of each weapon's full reserve that comes back when a round is over.
const ROUND_AMMO := 0.5
## The stream of the flamethrower: how far it reaches and how narrow it is (the cosine of
## half its angle).
const FLAME_REACH := 10.0
const FLAME_CONE := 0.962
var throw_kind := ""
var throw_held := 0.0
var throw_swing := -1.0
var throw_pose := 0.0
## The Leech that is hanging on to this survivor, if any.
var clung_by: Infected
var reload_left := 0.0
var reload_cue := 0
var shot_cooldown := 0.0
## The trigger has not been let go since the last shot: a weapon that fires single shots
## waits for that.
var trigger_held := false
var melee_cooldown := 0.0
## The swing of a blow with the weapon, 1 when it starts to 0 when it is over.
var melee_pose := 0.0
## Seconds until the syringe is ready again, and seconds the hands are still busy with it.
var syringe_wait := 0.0
var syringe_left := 0.0
## Slings bought this night: places for further weapons of any kind.
var extra_slots := 0
var crouched := false
var body_shape: CollisionShape3D
## Seconds the flamethrower's stream keeps showing after its last tick, and the seconds
## until its next hit marker.
var flame_left := 0.0
var flame_mark := 0.0
var flame_stream: CPUParticles3D
var flame_light: OmniLight3D
var flame_voice: AudioStreamPlayer
## Co-op guest: what the flamethrower did since the last report to the host (enemy ->
## damage), and the seconds until the next report.
var burn_report: Dictionary = {}
var burn_wait := 0.0
var recoil := 0.0
## Muzzle climb that still has to settle back down.
var climb := 0.0
## Shotgun: seconds since the last blast while the pump is being worked; negative when idle.
var pump_clock := -1.0
var pump_cued := false
## Sniper rifle: seconds since the shot while the bolt is still to be worked.
var bolt_clock := -1.0
## Rotary gun: 0 at rest, 1 when the barrels are up to speed. Other weapons stay at 1.
var spin := 1.0
var spin_voice: AudioStreamPlayer
## Shell-by-shell reload: the chamber was empty, so the reload ends with a pump stroke.
var chamber_empty := false
var loading_shells := false
var jolt := 0.0
var reload_pose := 0.0
var hurt_amount := 0.0
var acid_amount := 0.0
var bob_time := 0.0
var step_time := 0.0
var flash_left := 0.0
var mist_exposure := 0.0
var mist_damage_left := 0.0
var trauma := 0.0
var shake_clock := 0.0
var aim_blend := 0.0
var sprint_blend := 0.0
var look_delta := Vector2.ZERO
var sway := Vector2.ZERO
var landing := 0.0
var airborne := false
var shake_noise := FastNoiseLite.new()

func _ready() -> void:
	collision_layer = 2
	# World, infected and railings.
	collision_mask = 1 | 4 | 16
	floor_snap_length = 0.25
	shake_noise.frequency = 1.6
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	body_shape = shape
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = 1.62
	camera.near = 0.05
	camera.far = 240
	camera.fov = BASE_FOV
	add_child(camera)
	_build_weapon()
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.position = Vector3(0.12, -0.12, -0.1)
	flashlight.light_color = Color("e6ecd8")
	flashlight.light_energy = 3.2
	flashlight.spot_range = 30
	flashlight.spot_angle = 27
	flashlight.spot_attenuation = 1.1
	flashlight.spot_angle_attenuation = 0.7
	flashlight.shadow_enabled = true
	flashlight.shadow_bias = 0.06
	flashlight.light_volumetric_fog_energy = 0.3
	# The beam sits just beside the weapon, so it must not light the viewmodel itself.
	flashlight.light_cull_mask = 1
	camera.add_child(flashlight)
	var fill := OmniLight3D.new()
	fill.name = "ViewmodelFill"
	fill.position = Vector3(-0.1, 0.12, 0.05)
	fill.light_color = Color("aebdd0")
	fill.light_energy = 0.9
	fill.omni_range = 2.0
	fill.light_cull_mask = 2
	fill.light_volumetric_fog_energy = 0.0
	camera.add_child(fill)

func _build_weapon() -> void:
	weapon_models["rifle"] = WeaponView.build_gun("rifle")
	weapon_models["mg"] = WeaponView.build_gun("mg")
	weapon_models["g36"] = WeaponView.build_gun("g36")
	weapon_models["p90"] = WeaponView.build_p90()
	weapon_models["badger"] = WeaponView.build_badger()
	weapon_models["shotgun"] = WeaponView.build_shotgun()
	weapon_models["ump"] = WeaponView.build_gun("ump")
	weapon_models["ak"] = WeaponView.build_gun("ak")
	for id in WeaponView.MODELS:
		weapon_models[id] = WeaponView.build_model(id)
	for id in weapon_models:
		var view: Node3D = weapon_models[id]
		camera.add_child(view)
		view.position = WeaponView.VIEWS[id].hip
		view.hide()
	weapon = weapon_models["rifle"]
	weapon.show()
	flash = Node3D.new()
	flash.name = "Flash"
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color("ffd39b")
	flash_light.light_energy = 3.5
	flash_light.omni_range = 7
	flash_light.light_cull_mask = 1
	flash.add_child(flash_light)
	flash_mesh = WeaponView.build_flash()
	flash.add_child(flash_mesh)
	flash.visible = false
	weapon.add_child(flash)
	flash.position = WeaponView.VIEWS["rifle"].muzzle

## The infected only chase survivors who are still on their feet.
func is_targetable() -> bool:
	return health > 0.0

## Hazards hurt the survivors of the machine they run on; a co-op partner checks their own.
func takes_local_damage() -> bool:
	return true

func magazine_size() -> int:
	return magazine_of(current_weapon)

## What the magazine of a weapon holds: more with the workbench's bigger magazine.
func magazine_of(id: String) -> int:
	var size := int(WEAPONS[id].magazine)
	return size * 3 / 2 if upgrade(id, "mags") > 0 else size

# ---------------------------------------------------------------- the workbench

## The level a line of the workbench has on a weapon.
func upgrade(id: String, line: String) -> int:
	return int(inventory[id].get(UPGRADES[line].key, 0)) if inventory.has(id) else 0

## Whether a line of the workbench does anything for a weapon: nothing to steady on one
## that does not kick, no bigger magazine for two barrels.
static func upgrade_fits(id: String, line: String) -> bool:
	match line:
		"brace":
			return float(WEAPONS[id].kick) > 0.0
		"mags":
			return int(WEAPONS[id].magazine) >= 4
	return UPGRADES.has(line)

## Raises a line of the workbench on a weapon by one level. What is bigger is filled at
## once: the magazine, the pockets.
func raise(id: String, line: String) -> void:
	var record: Dictionary = inventory[id]
	var before := reserve_cap(id)
	record[UPGRADES[line].key] = upgrade(id, line) + 1
	record.erase("tuned")
	match line:
		"mags":
			record.ammo = magazine_of(id)
		"pouch":
			record.reserve = int(record.reserve) + reserve_cap(id) - before

## What a weapon does with each shot as it is now, the workbench counted in (for lists).
func damage_of(id: String) -> float:
	var data: Dictionary = WEAPONS[id]
	if data.has("flame") or data.has("grenade"):
		return float(data.damage) * (1.0 + UPGRADE_SHARE * upgrade(id, "damage"))
	return float(data.damage) + float(UPGRADES.damage.step) * upgrade(id, "damage") / int(data.get("pellets", 1))

## Seconds a reload of a weapon takes: quicker with the sweeper's hands and the workbench.
func reload_of(id: String) -> float:
	return float(WEAPONS[id].reload_time) * (1.0 - minf(0.6, game.skills.value("reload") + float(UPGRADES.drill.step) * upgrade(id, "drill")))

func filter_capacity() -> float:
	return MASK_SECONDS[mask_level] * (1.0 + game.skills.value("filter"))

## Takes what was bought at the shop counter.
func take_item(id: String) -> void:
	match id:
		"vest":
			armor = maxf(armor, 50.0)
		"armor":
			armor = 100.0
		"plates":
			plate_level = mini(PLATE_SHARES.size() - 1, plate_level + 1)
		"mask":
			mask_level = mini(4, mask_level + 1)
			filter_left = filter_capacity()
		"sling":
			extra_slots = mini((GOODS.sling.prices as Array).size(), extra_slots + 1)
		_:
			items[id] = int(items[id]) + 1

## Takes a grenade, a flashbang or a Molotov cocktail in the hand. It is thrown when the
## key is let go; while it is held, a line shows where it will fly.
func ready_throw(kind: String) -> void:
	if down or int(items[kind]) <= 0 or throw_cooldown > 0.0 or throw_kind != "":
		return
	throw_kind = kind
	throw_held = 0.0
	throw_swing = -1.0
	game.sounds.play_sound("equip", -6.0, 1.5)

## The points of a flight that starts at `at` with `speed`, up to the first thing it strikes
## or until `seconds` have passed. `pull` is the share of gravity, `damp` the drag of the air.
func _flight(at: Vector3, speed: Vector3, seconds: float, pull: float, damp: float, mask: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var space := get_world_3d().direct_space_state
	var step := 0.05
	points.append(at)
	for i in range(int(seconds / step)):
		speed += Vector3.DOWN * 9.8 * pull * step
		speed *= 1.0 - damp * step
		var next := at + speed * step
		var query := PhysicsRayQueryParameters3D.create(at, next, mask)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			points.append(hit.position)
			break
		points.append(next)
		at = next
	return points

## What a grenade thrown now would do: the points of its flight up to the first thing it
## strikes (or until its fuse runs out).
func throw_path(kind: String) -> PackedVector3Array:
	# A bottle bursts on the first body it strikes; a grenade flies past them.
	var mask := (1 | 4 | 16) if Throwable.KINDS[kind].get("breaks", false) else (1 | 16)
	return _flight(camera.global_position - camera.global_basis.z * 0.5 - camera.global_basis.y * 0.15, -camera.global_basis.z * 14.0 + Vector3.UP * 3.2 + velocity * 0.5, float(Throwable.KINDS[kind].fuse), 1.0, 0.3, mask)

## Where a shell fired from the launcher now would fly: a shallow arc, a little above the
## line of sight at first and then falling under it.
func launch_path() -> PackedVector3Array:
	return _flight(camera.global_position - camera.global_basis.z * 0.7 - camera.global_basis.y * 0.12, -camera.global_basis.z * LAUNCH_SPEED + Vector3.UP * LAUNCH_LIFT, LAUNCH_SHOWN, Throwable.SHELL_PULL, Throwable.SHELL_DAMP, 1 | 4 | 16)

func _hold_throw(delta: float) -> void:
	if throw_kind == "":
		return
	if down:
		throw_kind = ""
		return
	throw_held += delta
	if throw_swing < 0.0 and not Input.is_action_pressed(str(THROW_KEYS[throw_kind])):
		throw_swing = THROW_SWING
	if throw_swing >= 0.0:
		throw_swing -= delta
		if throw_swing <= 0.0:
			var kind := throw_kind
			throw_kind = ""
			throw_swing = -1.0
			throw(kind)

## Throws a grenade, a flashbang or a Molotov cocktail where the survivor looks.
func throw(kind: String) -> void:
	if down or int(items[kind]) <= 0 or throw_cooldown > 0.0:
		return
	items[kind] = int(items[kind]) - 1
	throw_cooldown = 0.7
	var body := Throwable.new()
	body.game = game
	body.kind = kind
	game.ordnance.add_child(body)
	body.global_position = camera.global_position - camera.global_basis.z * 0.5 - camera.global_basis.y * 0.15
	body.linear_velocity = -camera.global_basis.z * 14.0 + Vector3.UP * 3.2 + velocity * 0.5
	body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	recoil = 0.6
	game.sounds.play_sound("swipe", -3.0, 1.5)

## A blow with the weapon: whoever stands right in front is hurt a little, thrown back a
## step and reels for a moment. In a co-op match the host works out what it does.
func melee() -> void:
	if down or melee_cooldown > 0.0 or throw_kind != "":
		return
	melee_cooldown = MELEE_GAP
	melee_pose = 1.0
	shot_cooldown = maxf(shot_cooldown, 0.35)
	game.sounds.play_sound("swipe", -1.0, 0.85)
	var origin := camera.global_position
	var ahead := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	var space := get_world_3d().direct_space_state
	var struck := 0
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead:
			continue
		var to := enemy.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		var gap := flat.length() - float(enemy.spec.radius)
		if gap > MELEE_REACH or absf(to.y) > 1.6:
			continue
		# Whoever is close enough to touch is struck wherever he stands in front.
		if gap > 0.5 and flat.normalized().dot(ahead) < MELEE_CONE:
			continue
		var chest := enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.55, 0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, chest, 1)).is_empty():
			continue
		struck += 1
		var push := flat.normalized() if flat.length() > 0.05 else ahead
		var damage: float = MELEE_DAMAGE * game.skills.damage_factor(enemy, false)
		if game.net.joined:
			game.net.report_shove(enemy, push, damage)
			enemy.show_cue("hit", [1.0, 0.5])
		else:
			enemy.shove(push, MELEE_PUSH, MELEE_DAZE, damage)
	if struck > 0:
		game.sounds.play_sound("melee")
		game.hud.hit_marker(false)
		trauma = minf(1.0, trauma + 0.2)

## Sets a mine down a step ahead, pointing where the survivor faces.
func place_claymore() -> void:
	if down or int(items.claymore) <= 0 or throw_cooldown > 0.0 or not is_on_floor():
		return
	items.claymore = int(items.claymore) - 1
	throw_cooldown = 0.7
	# The weapon dips while the mine is set down.
	throw_pose = 1.0
	var mine := Claymore.new()
	mine.game = game
	mine.facing = Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	game.ordnance.add_child(mine)
	mine.global_position = global_position + mine.facing * 0.9
	game.sounds.play_sound("bolt", -2.0)

func max_reserve() -> int:
	return reserve_cap(current_weapon)

## How much ammunition for a weapon fits into the pockets; an ability makes them deeper.
func reserve_cap(id: String) -> int:
	return int(round(int(WEAPONS[id].reserve_max) * (1.0 + game.skills.value("reserve") + float(UPGRADES.pouch.step) * upgrade(id, "pouch"))))

## The weapon in hand as it shoots now: its values from the table, changed by whatever is
## fitted to it.
func gun() -> Dictionary:
	var record: Dictionary = inventory[current_weapon]
	var on: Dictionary = record.get("fitted", {})
	var steadied := upgrade(current_weapon, "brace")
	if on.is_empty() and steadied == 0:
		return WEAPONS[current_weapon]
	if not record.has("tuned"):
		var data: Dictionary = (WEAPONS[current_weapon] as Dictionary).duplicate()
		data["kick"] = float(data.kick) * (1.0 - float(UPGRADES.brace.step) * steadied)
		for slot in on:
			var part: Dictionary = ATTACHMENTS[current_weapon][on[slot]]
			var replaced: Dictionary = part.get("set", {})
			for key in replaced:
				data[key] = replaced[key]
			var scaled: Dictionary = part.get("scale", {})
			for key in scaled:
				data[key] = float(data[key]) * float(scaled[key])
		record["tuned"] = data
	return record.tuned

## The part in a slot ("sight", "muzzle") of the weapon in hand, or "".
func fitted(slot: String) -> String:
	return str((inventory[current_weapon].get("fitted", {}) as Dictionary).get(slot, ""))

func owns_part(id: String, part: String) -> bool:
	return inventory.has(id) and (inventory[id].get("mods", []) as Array).has(part)

## Puts a part on a weapon the survivor owns, in place of what sat in its slot; a part
## that is on already comes off again.
func fit(id: String, part: String) -> void:
	var record: Dictionary = inventory[id]
	var owned: Array = record.get("mods", [])
	if not owned.has(part):
		owned.append(part)
	record["mods"] = owned
	var on: Dictionary = record.get("fitted", {})
	var slot := str(ATTACHMENTS[id][part].slot)
	if str(on.get(slot, "")) == part:
		on.erase(slot)
	else:
		on[slot] = part
	record["fitted"] = on
	record.erase("tuned")
	if id == current_weapon:
		_show_parts()

## Shows what is fitted to the weapon in hand and puts the muzzle flash at its muzzle.
func _show_parts() -> void:
	var on: Array = (inventory[current_weapon].get("fitted", {}) as Dictionary).values()
	for node in weapon.get_children():
		if str(node.name).begins_with("Mod_"):
			(node as Node3D).visible = on.has(str(node.name).trim_prefix("Mod_"))
	# Iron sights that fold lie down when a sight is fitted.
	var irons := weapon.find_child("Sights", true, false) as Node3D
	if irons != null and WeaponView.GUNS.has(current_weapon) and WeaponView.GUNS[current_weapon].get("folding", false):
		irons.visible = fitted("sight") == ""
	var muzzle: Vector3 = WeaponView.VIEWS[current_weapon].muzzle
	if on.has("silencer"):
		muzzle.z -= WeaponView.SILENCER_LENGTH
	flash.position = muzzle

func weapon_label() -> String:
	return WEAPONS[current_weapon].label

## "primary", "secondary" or "heavy": the kind a weapon is of.
static func kind_of(id: String) -> String:
	var group := str(WEAPONS[id].get("group", "weapons"))
	for kind in KINDS:
		if (KINDS[kind].groups as Array).has(group):
			return kind
	return "primary"

## The weapons of a kind the survivor carries, in the order of ORDER.
func carried(kind: String) -> Array:
	return ORDER.filter(func(id: String) -> bool: return inventory.has(id) and kind_of(id) == kind)

## How many weapons are carried beyond one of each kind; `with`: counting this one in.
func _beyond(with: String = "") -> int:
	var over := 0
	for kind in KINDS:
		var count := carried(kind).size() + (1 if with != "" and not inventory.has(with) and kind_of(with) == kind else 0)
		over += maxi(0, count - CARRY)
	return over

## True if another weapon can be carried beside what is carried already.
func room_for(id: String) -> bool:
	return _beyond(id) <= extra_slots

## The weapon that has to go to make room for another one of its kind: the one in hand
## if it is of that kind, otherwise the first of them. "" if there is room anyway.
func to_replace(id: String) -> String:
	if room_for(id):
		return ""
	var same := carried(kind_of(id))
	return current_weapon if same.has(current_weapon) else str(same[0])

## Every weapon that could go to make room for another one: those of its kind, and of the
## other kinds any that a sling carries. The one to_replace() names comes first; empty if
## there is room anyway.
func replaceable(id: String) -> Array:
	var first := to_replace(id)
	if first == "":
		return []
	var out: Array = [first]
	for kind in KINDS:
		var same := carried(kind)
		if kind == kind_of(id) or same.size() > CARRY:
			for other in same:
				if not out.has(other):
					out.append(other)
	return out

## The weapon to take in hand when `id` goes: one of its kind if there is one, otherwise
## the first that is carried. "" if it is the only one.
func other_weapon(id: String) -> String:
	for other in carried(kind_of(id)):
		if other != id:
			return str(other)
	for other in ORDER:
		if other != id and inventory.has(other):
			return str(other)
	return ""

## Lays a weapon down for good, with whatever was fitted to it. Not the one in hand.
func drop_weapon(id: String) -> void:
	if id != current_weapon:
		inventory.erase(id)

## Ammunition comes back when a round is over: for every weapon carried, `share` of what
## its pockets hold.
func resupply(share: float) -> void:
	for id in inventory:
		var cap := reserve_cap(id)
		inventory[id].reserve = mini(cap, int(inventory[id].reserve) + int(ceil(cap * share)))

## The syringe: some health back at once, then it has to be made ready again. Nothing
## happens at full health.
func inject() -> bool:
	if down or health <= 0.0 or health >= 100.0 or syringe_wait > 0.0 or throw_kind != "":
		return false
	syringe_wait = SYRINGE_WAIT
	syringe_left = SYRINGE_TIME
	shot_cooldown = maxf(shot_cooldown, SYRINGE_TIME)
	health = minf(100.0, health + game.healing(SYRINGE_HEAL))
	hurt_amount = 0.0
	game.sounds.play_sound("syringe")
	game.hud.flash(Color(0.45, 1.0, 0.75), 0.1)
	return true

## Ducks or stands up again. Standing up needs room above; ducking needs ground below.
func set_crouched(low: bool) -> void:
	if low == crouched or (low and (down or not is_on_floor())):
		return
	if not low:
		var top := global_position + Vector3(0, CROUCH_HEIGHT, 0)
		var query := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, STAND_HEIGHT - CROUCH_HEIGHT + 0.05, 0), 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return
	crouched = low
	var capsule := body_shape.shape as CapsuleShape3D
	capsule.height = CROUCH_HEIGHT if low else STAND_HEIGHT
	body_shape.position.y = capsule.height * 0.5

## How high above the feet a shot at this survivor is aimed, and where he is looked for.
func chest_height() -> float:
	return 0.72 if crouched else 1.15

## Adds a bought weapon with a full load and takes it in hand.
func unlock(id: String) -> bool:
	if inventory.has(id) or not WEAPONS.has(id): return false
	inventory[id] = {"ammo": int(WEAPONS[id].magazine), "reserve": reserve_cap(id), "level": 0}
	equip_weapon(id)
	return true

func equip_weapon(id: String, silent: bool = false) -> bool:
	if not inventory.has(id): return false
	if id == current_weapon: return true
	# Cancelling a reload never transfers rounds; each weapon owns its ammo.
	reload_left = 0
	loading_shells = false
	pump_clock = -1.0
	bolt_clock = -1.0
	spin = 0.0
	flash_left = 0
	recoil = 0
	shot_cooldown = 0.25
	weapon.hide()
	current_weapon = id
	weapon = weapon_models[id]
	weapon.show()
	# The new weapon rises into view from below.
	weapon.position = (WeaponView.VIEWS[id].hip as Vector3) + Vector3(0.02, -0.2, 0.06)
	weapon.rotation = Vector3(0.6, 0.2, 0)
	flash.reparent(weapon, false)
	_show_parts()
	throw_kind = ""
	if not silent:
		game.sounds.play_sound("equip")
		if game.hud != null:
			game.hud.loadout()
	return true

## Number keys 1 to 3: the weapon of that kind, or a hint where to get one. Several
## weapons of a kind (carried with slings) take turns.
func _select_slot(slot: int) -> void:
	for kind in KINDS:
		if int(KINDS[kind].key) != slot:
			continue
		var owned := carried(kind)
		if owned.is_empty():
			game.hud.announce("KEINE %s" % KINDS[kind].label, "Im Waffenshop im Hauptraum neben dem Flur · offen zwischen den Runden", 2.5)
			return
		equip_weapon(owned[(owned.find(current_weapon) + 1) % owned.size()])

## Mouse wheel: the next weapon the survivor owns.
func _cycle(step: int) -> void:
	var owned: Array = ORDER.filter(func(id: String) -> bool: return inventory.has(id))
	if owned.size() > 1:
		equip_weapon(owned[posmod(owned.find(current_weapon) + step, owned.size())])

func _unhandled_input(event: InputEvent) -> void:
	if not controlled or menu_open:
		return
	if down:
		# Looking around is all that is left.
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * sensitivity)
			camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -0.6, 1.0)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var factor := 1.0
		if Input.is_action_pressed("aim"):
			factor = float(gun().get("scope_turn", 0.2)) if gun().has("scope") else 0.6
		rotate_y(-event.relative.x * sensitivity * factor)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity * factor, -1.35, 1.35)
		look_delta += event.relative
	if event.is_action_pressed("reload"):
		start_reload()
	if event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		game.sounds.play_sound("click", -6.0, 1.5)
	if event.is_action_pressed("interact"):
		game.interact()
	for slot in range(10):
		if event.is_action_pressed("weapon_%d" % slot):
			_select_slot(slot)
	if event.is_action_pressed("throw_grenade"):
		ready_throw("grenade")
	if event.is_action_pressed("throw_flash"):
		ready_throw("flashbang")
	if event.is_action_pressed("throw_molotov"):
		ready_throw("molotov")
	if event.is_action_pressed("melee"):
		melee()
	if event.is_action_pressed("syringe"):
		inject()
	if event.is_action_pressed("crouch"):
		set_crouched(not crouched)
	if event.is_action_pressed("place_claymore"):
		place_claymore()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_cycle(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)

func _physics_process(delta: float) -> void:
	shot_cooldown = maxf(0, shot_cooldown - delta)
	throw_cooldown = maxf(0, throw_cooldown - delta)
	melee_cooldown = maxf(0, melee_cooldown - delta)
	melee_pose = move_toward(melee_pose, 0.0, delta * 3.4)
	syringe_wait = maxf(0.0, syringe_wait - delta)
	syringe_left = maxf(0.0, syringe_left - delta)
	flame_left = maxf(0.0, flame_left - delta)
	flame_mark = maxf(0.0, flame_mark - delta)
	_show_flame(flame_left > 0.0)
	if not burn_report.is_empty():
		burn_wait -= delta
		if burn_wait <= 0.0:
			burn_wait = 0.2
			for enemy in burn_report:
				if is_instance_valid(enemy):
					game.net.report_burn(enemy, float(burn_report[enemy]), game.skills.value("fire_tame") > 0.0)
			burn_report.clear()
	_hold_throw(delta)
	throw_pose = move_toward(throw_pose, 1.0 if throw_kind != "" else 0.0, delta * (9.0 if throw_kind != "" else 4.5))
	# The line of the throw, once the key has been held for a moment.
	if throw_kind != "" and throw_swing < 0.0 and throw_held > THROW_AIM_AFTER and controlled:
		game.fx.show_arc(throw_path(throw_kind))
	elif controlled and not down and not menu_open and WEAPONS[current_weapon].has("grenade") and ammo > 0 and reload_left <= 0.0 and Input.is_action_pressed("aim"):
		# Aiming with the launcher shows the arc of its shell.
		# The first points lie right in front of the eye and would only be in the way.
		game.fx.show_arc(launch_path().slice(5))
	else:
		game.fx.hide_arc()
	flash_left = maxf(0, flash_left - delta)
	flash.visible = flash_left > 0
	hurt_amount = move_toward(hurt_amount, 0, delta * 1.5)
	acid_amount = move_toward(acid_amount, 0, delta * 1.2)
	recoil = move_toward(recoil, 0, delta * 9)
	jolt = move_toward(jolt, 0, delta * 7)
	landing = move_toward(landing, 0, delta * 5)
	_shake(delta)
	if not controlled:
		return
	# The muzzle comes back down after a heavy kick.
	if climb > 0.0:
		var back := minf(climb, delta * (0.12 + climb * 4.0))
		camera.rotation.x -= back
		climb -= back
	if pump_clock >= 0.0:
		pump_clock += delta
		if not pump_cued and pump_clock >= PUMP_BACK - 0.06:
			pump_cued = true
			game.sounds.play_sound("shotgun_pump")
			game.fx.spent_shell(camera.global_transform * Vector3(0.16, -0.1, -0.35), global_basis.x * 2.2 + Vector3.UP * 1.6 + velocity)
		if pump_clock >= PUMP_DONE:
			pump_clock = -1.0
	if bolt_clock >= 0.0:
		bolt_clock += delta
		if bolt_clock >= 0.4:
			bolt_clock = -1.0
			jolt = 1.0
			game.sounds.play_sound("bolt")
	if reload_left > 0 and loading_shells:
		reload_left = maxf(0, reload_left - delta)
		if reload_left == 0:
			# One shell slides into the tube; carry on until it is full.
			ammo += 1
			reserve -= 1
			jolt = 1.0
			game.sounds.play_sound("shell_in")
			if ammo < magazine_size() and reserve > 0:
				# The workbench's drill makes every shell quicker.
				reload_left = float(WEAPONS[current_weapon].reload_time) * (1.0 - float(UPGRADES.drill.step) * upgrade(current_weapon, "drill"))
			else:
				loading_shells = false
				if chamber_empty:
					pump_clock = PUMP_BACK - 0.1
					pump_cued = false
					shot_cooldown = 0.4
	elif reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		# Magazine out, magazine in, bolt: each step is heard and nudges the weapon.
		var done := 1.0 - reload_left / float(WEAPONS[current_weapon].reload_time)
		var cues: Array = WEAPONS[current_weapon].get("cues", RELOAD_CUES)
		while reload_cue < cues.size() and done >= float(cues[reload_cue][0]):
			game.sounds.play_sound(cues[reload_cue][1])
			jolt = 1.0
			reload_cue += 1
		if reload_left == 0:
			var count := mini(magazine_size() - ammo, reserve)
			ammo += count
			reserve -= count
	var blocked := menu_open or down
	camera.position.y = lerpf(camera.position.y, 0.42 if down else (CROUCH_EYE if crouched else 1.62), minf(1.0, delta * 6.0 if down else delta * 10.0))
	weapon.visible = not down
	var input := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := transform.basis * Vector3(input.x, 0, input.y)
	var aiming := Input.is_action_pressed("aim") and reload_left <= 0 and not blocked
	var sprint := Input.is_action_pressed("sprint") and not aiming and input.y < -0.1 and clung_by == null
	# Whoever starts to run stands up for it (if there is room to).
	if sprint and crouched:
		set_crouched(false)
		sprint = not crouched
	var speed := 6.6 if sprint else 4.3
	if aiming:
		speed = 2.6
	if crouched:
		speed = minf(speed, CROUCH_SPEED)
	if WEAPONS[current_weapon].has("spin"):
		# The rotary gun weighs as much as a small child.
		speed *= 0.72
	if clung_by != null:
		# With a Leech hanging on, every step is a struggle.
		speed *= 0.55
		trauma = maxf(trauma, 0.28)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 30)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 30)
	if not is_on_floor():
		velocity.y -= 22 * delta
		airborne = true
	elif Input.is_action_just_pressed("jump") and not blocked and crouched:
		# Out of a crouch the key only gets the survivor back on his feet.
		set_crouched(false)
		velocity.y = 0
	elif Input.is_action_just_pressed("jump") and not blocked:
		velocity.y = 5.5
	else:
		velocity.y = 0
		if airborne:
			airborne = false
			landing = 1.0
			_footstep(4.0)
	move_and_slide()
	_update_mist(delta)
	if position.y < -10:
		position = game.cabin.player_start
	var firing: bool = Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not blocked and not (sprint and input.length() > 0.1)
	# A weapon that fires single shots wants the trigger let go before the next one.
	if not Input.is_action_pressed("fire"):
		trigger_held = false
	_spin(delta, firing)
	if firing and spin >= 1.0 and trigger_free():
		shoot()
	var moving := input.length() > 0.1 and is_on_floor()
	if moving:
		bob_time += delta * (12.5 if sprint else 8.5)
		step_time -= delta
		if step_time <= 0:
			_footstep(2.0 if sprint else 0.0)
			step_time = 0.3 if sprint else 0.45
	_animate_weapon(delta, aiming, sprint and moving, moving)
	# Through the telescopic sight only the picture in the lens is left.
	var sights: Dictionary = gun()
	var scoped := smoothstep(0.7, 1.0, aim_blend) if sights.has("scope") else 0.0
	game.hud.scope(scoped)
	if scoped > 0.6:
		weapon.hide()
	var zoom := float(sights.get("scope", sights.get("zoom", 50.0))) if aiming else (BASE_FOV + 5.0 if sprint and moving else BASE_FOV)
	camera.fov = lerpf(camera.fov, zoom, minf(1, delta * 11))

## False while a weapon that fires single shots waits for the trigger to be let go.
func trigger_free() -> bool:
	return not (trigger_held and WEAPONS[current_weapon].get("semi", false))

## The rotary gun has to come up to speed before it fires; every other weapon is ready.
func _spin(delta: float, firing: bool) -> void:
	var data: Dictionary = WEAPONS[current_weapon]
	if not data.has("spin"):
		spin = 1.0
		if spin_voice != null and spin_voice.playing:
			spin_voice.stop()
		return
	spin = move_toward(spin, 1.0 if firing and ammo > 0 and reload_left <= 0 else 0.0, delta / float(data.spin))
	var barrels := weapon.find_child("Barrels", true, false) as Node3D
	if barrels != null:
		barrels.rotation.z -= spin * 34.0 * delta
	if spin_voice == null:
		spin_voice = AudioStreamPlayer.new()
		var whir := game.sounds.clips["minigun_spin"][0] as AudioStreamWAV
		whir.loop_mode = AudioStreamWAV.LOOP_FORWARD
		whir.loop_begin = 0
		whir.loop_end = int(whir.get_length() * whir.mix_rate)
		spin_voice.stream = whir
		add_child(spin_voice)
	if spin > 0.02 and not game.sounds.hush:
		if not spin_voice.playing:
			spin_voice.play()
		spin_voice.pitch_scale = 0.45 + spin * 0.75
		spin_voice.volume_db = -24.0 + spin * 12.0
	elif spin_voice.playing:
		spin_voice.stop()

## Fires a 40 mm shell that goes off where it lands.
func _launch(data: Dictionary) -> void:
	var shell := Throwable.new()
	shell.game = game
	shell.kind = "grenade"
	shell.impact = true
	shell.boost = 1.0 + UPGRADE_SHARE * weapon_level
	game.ordnance.add_child(shell)
	shell.global_position = camera.global_position - camera.global_basis.z * 0.7 - camera.global_basis.y * 0.12
	shell.linear_velocity = -camera.global_basis.z * LAUNCH_SPEED + Vector3.UP * LAUNCH_LIFT
	game.fx.launch_smoke(shell.global_position, -camera.global_basis.z)
	var kick: float = float(data.kick)
	camera.rotation.x = minf(1.35, camera.rotation.x + kick)
	climb += kick * float(data.get("settle", 0.0))
	if game.net.active:
		game.net.send_shot(camera.global_position, camera.global_position - camera.global_basis.z * 30.0, str(data.sound))

## The flamethrower: a stream of fire as far as FLAME_REACH. Whatever stands in its cone
## and in sight is scorched, and keeps burning.
func _flame(data: Dictionary) -> void:
	flame_left = 0.16
	var origin := camera.global_position
	var ahead := -camera.global_basis.z
	var space := get_world_3d().direct_space_state
	var touched := false
	for node in get_tree().get_nodes_in_group("infected"):
		var enemy := node as Infected
		if enemy.dead:
			continue
		var chest := enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.55, 0)
		var to := chest - origin
		var gap := to.length()
		# Up close the stream is as wide as whoever stands in front of the nozzle.
		if gap > FLAME_REACH or to.normalized().dot(ahead) < (FLAME_CONE if gap > 2.5 else 0.7):
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, chest, 1)).is_empty():
			continue
		touched = true
		var damage: float = damage_of(current_weapon) * _bonus(data, enemy, false)
		if game.net.joined:
			# The host works out what the fire does; a guest reports it a few times a second.
			burn_report[enemy] = float(burn_report.get(enemy, 0.0)) + damage
		else:
			game.scorch(enemy, damage, to.normalized(), null, 2.5, game.skills.value("fire_tame") > 0.0)
	if touched and flame_mark <= 0.0:
		flame_mark = 0.3
		game.hud.hit_marker(false)
	if game.net.active:
		game.net.send_shot(origin, origin + ahead * FLAME_REACH, str(data.sound))

## The stream of the flamethrower, its glow and its roar: on while it fires.
func _show_flame(on: bool) -> void:
	if flame_stream == null:
		if not on:
			return
		flame_stream = game.fx.flame_stream()
		camera.add_child(flame_stream)
		flame_light = OmniLight3D.new()
		flame_light.light_color = Color(1.0, 0.55, 0.2)
		flame_light.omni_range = 9.0
		flame_light.position = Vector3(0, -0.1, -3.2)
		flame_light.light_cull_mask = 1
		camera.add_child(flame_light)
		flame_voice = AudioStreamPlayer.new()
		var roar := (game.sounds.clips["flamer"][0] as AudioStreamWAV).duplicate() as AudioStreamWAV
		roar.loop_mode = AudioStreamWAV.LOOP_FORWARD
		roar.loop_begin = 0
		roar.loop_end = int(roar.get_length() * roar.mix_rate)
		flame_voice.stream = roar
		flame_voice.bus = "Field"
		flame_voice.volume_db = float(FieldAudio.MIX["flamer"][0])
		add_child(flame_voice)
	if on:
		flame_stream.global_position = _visible_muzzle()
		flame_stream.global_basis = camera.global_basis
		flame_light.light_energy = 2.2 + randf() * 0.9
	flame_stream.emitting = on
	flame_light.visible = on
	if on and not flame_voice.playing and not game.sounds.hush:
		flame_voice.play()
	elif not on and flame_voice.playing:
		flame_voice.stop()

## What a hit of this weapon is worth against this enemy beyond its plain damage: what
## the abilities add and what the weapon itself is made for. A guest of a co-op match,
## whose hits the host works out, also reports here what his weapon and his abilities
## take off a soldier's armour.
func _bonus(data: Dictionary, enemy: Infected, headshot: bool) -> float:
	var factor: float = game.skills.damage_factor(enemy, headshot)
	if Skills.kind_of(enemy) == "special":
		factor *= float(data.get("special", 1.0))
	if game.net.joined and enemy is CruSoldier:
		factor *= (enemy as CruSoldier).armour_gain(float(data.get("armour", 1.0)) * game.skills.armour_left())
	return factor

## A heavy bullet goes on through the body it hit: whoever stands behind is struck too,
## a little less hard each time. Returns where the bullet finally stops.
func _pierce(data: Dictionary, passes: int, direction: Vector3, first: Infected, struck: Dictionary, from: Vector3) -> Vector3:
	var through: Array[RID] = [get_rid(), first.get_rid(), first.head_box.get_rid()]
	var force := 0.75
	var stop := from
	for i in range(passes):
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * 60.0, 1 | 4 | 8, through)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return from + direction * 60.0
		stop = hit.position
		var target: Object = hit.collider
		var head_zone: bool = target.has_meta("infected")
		if head_zone:
			target = target.get_meta("infected")
		if not target is Infected:
			game.fx.dust(stop, hit.normal)
			return stop
		var enemy := target as Infected
		var headshot := head_zone or enemy.is_headshot(stop)
		var damage: float = float(data.damage) * force
		if headshot:
			damage *= maxf(1.0, float(data.head_multiplier) * float(enemy.spec.head_factor))
		damage *= _bonus(data, enemy, headshot)
		var entry: Dictionary = struck.get(enemy, {"damage": 0.0, "headshot": false, "direction": direction})
		entry.damage += damage
		entry.headshot = entry.headshot or headshot
		struck[enemy] = entry
		game.fx.blood(stop, direction, true)
		through.append(enemy.get_rid())
		through.append(enemy.head_box.get_rid())
		force *= 0.75
	return stop

## Floorboards inside the house, wet grass in the yard.
func _footstep(volume: float) -> void:
	game.sounds.play_sound("step_wood" if game.cabin.is_indoors(position) else "step_grass", volume)

func _shake(delta: float) -> void:
	trauma = maxf(0, trauma - delta * 1.7)
	shake_clock += delta * 28.0
	var power := trauma * trauma
	camera.h_offset = shake_noise.get_noise_1d(shake_clock) * power * 0.06
	camera.v_offset = shake_noise.get_noise_1d(shake_clock + 50.0) * power * 0.06
	camera.rotation.z = shake_noise.get_noise_1d(shake_clock + 100.0) * power * 0.05

func _animate_weapon(delta: float, aiming: bool, sprinting: bool, moving: bool) -> void:
	var view: Dictionary = WeaponView.VIEWS[current_weapon]
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 7.5)
	sprint_blend = move_toward(sprint_blend, 1.0 if sprinting else 0.0, delta * 6.0)
	var aimed := smoothstep(0.0, 1.0, aim_blend)
	var loose := 1.0 - aimed * 0.85
	# A sight that was fitted has its own place for the eye.
	var sight := fitted("sight")
	var aim_at: Vector3 = WeaponView.sight_aim(current_weapon, sight) if sight != "" else view.aim
	var target: Vector3 = (view.hip as Vector3).lerp(aim_at, aimed)
	var angles: Vector3 = (view.hip_angles as Vector3) * (PI / 180.0) * (1.0 - aimed)
	if not inventory[current_weapon].get("fitted", {}).has("sight"):
		angles += (view.get("aim_angles", Vector3.ZERO) as Vector3) * (PI / 180.0) * aimed
	target += Vector3(0.012, -0.04, 0.035) * sprint_blend
	angles += Vector3(-0.22, 0.45, -0.14) * sprint_blend
	if moving:
		var stride := 1.7 if sprinting else 1.0
		target += Vector3(sin(bob_time) * 0.0065, -absf(cos(bob_time)) * 0.0065 + 0.003, 0) * loose * stride
		angles.z += sin(bob_time) * 0.012 * loose * stride
	target.y += sin(Time.get_ticks_msec() * 0.0017) * 0.0013 * loose
	# The weapon lags slightly behind the view when turning.
	sway = sway.lerp((look_delta * 0.0003).limit_length(0.03), minf(1, delta * 9))
	look_delta = Vector2.ZERO
	target += Vector3(-sway.x, sway.y, 0) * loose
	angles += Vector3(sway.y * 1.4, -sway.x * 1.8, -sway.x * 1.4) * loose
	target += Vector3(0, -velocity.y * 0.0035 - landing * 0.018, recoil * (0.018 if aiming else 0.03))
	angles.x += recoil * (0.018 if aiming else 0.045)
	if loading_shells:
		# Held low and tilted while the shells go in, one nudge per shell.
		reload_pose = move_toward(reload_pose, 1.0, delta * 5.0)
	elif reload_left > 0:
		reload_pose = sin((1.0 - reload_left / float(WEAPONS[current_weapon].reload_time)) * PI)
	else:
		reload_pose = move_toward(reload_pose, 0.0, delta * 5.0)
	if reload_pose > 0.0:
		var low := Vector3(0.02, -0.075, 0.02) if loading_shells or WEAPONS[current_weapon].has("shells") else Vector3(0.025, -0.12, 0.03)
		var turn := Vector3(0.3, 0.2, -0.75) if loading_shells or WEAPONS[current_weapon].has("shells") else Vector3(0.55, 0.25, -0.6)
		target += (view.get("reload_low", low) as Vector3) * reload_pose
		angles += (view.get("reload_turn", turn) as Vector3) * reload_pose
	# A magazine that really leaves the weapon, and the hand that changes it.
	var clip := weapon.get_node_or_null("Magazine") as Node3D
	if clip != null:
		var done := 1.0
		if reload_left > 0.0 and not loading_shells:
			done = 1.0 - reload_left / float(WEAPONS[current_weapon].reload_time)
		var step: Dictionary = WeaponView.reload_step(current_weapon, done)
		clip.position = step.magazine
		(weapon.get_node("Support") as Node3D).position = step.hand
	# A double rifle breaks open while it is loaded: the barrels drop and come up again.
	if WeaponView.MODELS.has(current_weapon) and WeaponView.MODELS[current_weapon].has("open"):
		var barrels := weapon.find_child("Barrels", true, false) as Node3D
		if barrels != null:
			var done := 1.0 - reload_left / float(WEAPONS[current_weapon].reload_time) if reload_left > 0.0 else 1.0
			barrels.rotation.x = deg_to_rad(float(WeaponView.MODELS[current_weapon].open)) * smoothstep(0.08, 0.24, done) * (1.0 - smoothstep(0.72, 0.9, done))
	# The pump hand drags the forend back and shoves it forward again.
	var slide := weapon.get_node_or_null("Slide") as Node3D
	if slide != null:
		var stroke := 0.0
		if pump_clock >= 0.0:
			stroke = smoothstep(PUMP_BACK - 0.14, PUMP_BACK, pump_clock) * (1.0 - smoothstep(PUMP_BACK + 0.06, PUMP_DONE - 0.04, pump_clock))
			target += Vector3(0.0, -0.012, 0.012) * stroke
			angles += Vector3(0.06, 0.03, -0.12) * stroke
		slide.position.z = stroke * PUMP_TRAVEL
	# A blow with the weapon: it is thrust forward and across, and comes back.
	if melee_pose > 0.0:
		var swing := sin(melee_pose * PI)
		target += Vector3(-0.08, 0.035, -0.2) * swing
		angles += Vector3(-0.3, 0.75, 0.55) * swing
	# The syringe: the weapon is let down for as long as the hands are busy with it.
	if syringe_left > 0.0:
		var busy := sin(clampf(syringe_left / SYRINGE_TIME, 0.0, 1.0) * PI)
		target += Vector3(0.02, -0.15, 0.05) * busy
		angles += Vector3(0.4, 0.3, -0.3) * busy
	# A grenade in the other hand: the weapon dips out of the way.
	if throw_pose > 0.0:
		var dip := smoothstep(0.0, 1.0, throw_pose)
		target += Vector3(0.03, -0.17, 0.06) * dip
		angles += Vector3(0.45, 0.2, -0.25) * dip
	# Each reload step knocks the weapon for a moment.
	target += Vector3(0.0, -0.014, 0.008) * jolt
	angles += Vector3(0.05, 0.0, -0.09) * jolt
	weapon.position = weapon.position.lerp(target, minf(1, delta * 18))
	weapon.rotation = weapon.rotation.lerp(angles, minf(1, delta * 16))

func _update_mist(delta: float) -> void:
	mist_damage_left = maxf(0, mist_damage_left - delta)
	var breathing: bool = game.toxic_at(position)
	if breathing and not in_gas and controlled and not game.sounds.hush:
		# The gas is hard to see: the first breath of it is heard.
		game.sounds.play_sound("hiss", -9.0, 1.25)
	in_gas = breathing
	if breathing:
		if filter_left > 0.0:
			# A gas mask keeps the air clean for as long as its filter lasts.
			filter_left = maxf(0.0, filter_left - delta)
			mist_exposure = 0
			return
		mist_exposure += delta
		# A harder night: the gas bites sooner and deeper.
		var gas: float = game.rules.gas
		if mist_exposure > 3.0 / sqrt(gas) and mist_damage_left <= 0:
			receive_damage(6.0 * gas, Vector3.INF, "gas")
			mist_damage_left = 1.0
	else:
		mist_exposure = 0
		# In clean air the filter slowly recovers.
		filter_left = minf(filter_capacity(), filter_left + delta * 0.6)

## Where the muzzle appears on screen, expressed as a world position for tracers.
func _visible_muzzle() -> Vector3:
	var local := camera.to_local(flash.global_position)
	var ratio := tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(WeaponView.VIEW_FOV) * 0.5)
	return camera.to_global(Vector3(local.x * ratio, local.y * ratio, local.z))

func shoot() -> void:
	var data: Dictionary = gun()
	if loading_shells and ammo > 0 and shot_cooldown <= 0:
		# A half-loaded shotgun can fire at once: the reload is simply broken off.
		loading_shells = false
		reload_left = 0.0
		shot_cooldown = 0.25
		return
	# No shooting with a grenade in the hand.
	if throw_kind != "":
		return
	if shot_cooldown > 0 or reload_left > 0:
		return
	if ammo <= 0:
		if reserve > 0:
			start_reload()
		else:
			shot_cooldown = 0.4
			game.sounds.play_sound("click")
		return
	var aiming := Input.is_action_pressed("aim")
	ammo -= 1
	trigger_held = true
	shot_cooldown = float(data.interval)
	if data.has("flame"):
		_flame(data)
		return
	# A suppressor leaves only a small, dim flash; a shotgun lights up the room.
	var blaze: float = data.flash
	flash_left = 0.03 if blaze < 0.5 else (0.075 if blaze > 1.5 else 0.045)
	flash_mesh.rotation.z = randf() * TAU
	flash_mesh.scale = Vector3.ONE * randf_range(0.75, 1.3) * blaze
	flash_light.light_energy = 3.5 * blaze
	var punch: float = data.get("punch", 1.0)
	recoil = punch
	game.sounds.play_sound(data.sound)
	if data.has("pellets"):
		# The blast shoves the whole view; a pump gun has to be worked before the next shot.
		trauma = minf(1.0, trauma + (0.44 if data.has("shells") else 0.24))
		camera.fov += 4.4 if data.has("shells") else 2.3
		if data.has("shells"):
			pump_clock = 0.0
			pump_cued = false
	if data.has("bolt"):
		bolt_clock = 0.0
	if data.has("grenade"):
		_launch(data)
		return
	var origin := camera.global_position
	var muzzle := _visible_muzzle()
	var pellets := int(data.get("pellets", 1))
	# Scripted checks fire dead centre; live fire scatters from the hip.
	var spread := 0.0 if game.check_mode else float(data.spread) * ((0.6 if pellets > 1 else 0.25) * float(data.get("aim_spread", 1.0)) if aiming else 1.0) * (CROUCH_STEADY if crouched else 1.0)
	# Everything one blast does to the same infected is added up and lands as a single hit.
	var struck := {}
	var endpoint := origin - camera.global_basis.z * 90
	var marks := 0
	for pellet in range(pellets):
		var direction := (-camera.global_basis.z + camera.global_basis.x * randf_range(-spread, spread) + camera.global_basis.y * randf_range(-spread, spread)).normalized()
		endpoint = origin + direction * 90
		var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 1 | 4 | 8, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			endpoint = hit.position
			var target: Object = hit.collider
			var head_zone: bool = target.has_meta("infected")
			if head_zone:
				target = target.get_meta("infected")
			var shielded: bool = target is Infected and (target as Infected).blocks(direction)
			# A shield stops a bullet, unless an ability lets this weapon shoot through it.
			# A few weapons do so by themselves.
			var share: float = maxf(game.skills.shield_share(current_weapon), float(data.get("shield", 0.0))) if shielded else 1.0
			if shielded and share <= 0.0:
				# It rings off a shield: no blood, no harm, and the bullet stops there.
				if marks < 4:
					game.fx.dust(endpoint, hit.normal)
					game.sounds.play_at("bolt", endpoint, 0.0, randf_range(1.5, 1.9))
			elif target is Infected:
				var enemy := target as Infected
				var headshot := head_zone or enemy.is_headshot(hit.position)
				var damage: float = float(data.damage) + weapon_level * (10.0 / pellets)
				if pellets > 1:
					# Shot spreads and slows: full force up close, a third of it at long range.
					damage *= clampf(1.0 - (origin.distance_to(endpoint) - 8.0) / 18.0, 0.33, 1.0)
				if headshot:
					damage *= maxf(1.0, float(data.head_multiplier) * float(enemy.spec.head_factor))
				damage *= share * _bonus(data, enemy, headshot)
				var entry: Dictionary = struck.get(enemy, {"damage": 0.0, "headshot": false, "direction": direction, "through": false, "pellets": 0, "near": origin.distance_to(endpoint)})
				entry.damage += damage
				entry.pellets += 1
				entry.headshot = entry.headshot or headshot
				entry.through = entry.through or shielded
				struck[enemy] = entry
				if marks < 4:
					game.fx.blood(endpoint, direction, headshot or pellets > 1)
			elif marks < 4:
				game.fx.dust(endpoint, hit.normal)
			marks += 1
			var passes := int(data.get("pierce", 0))
			if passes == 0 and target is Infected and current_weapon in Skills.RIFLES and Skills.kind_of(target as Infected) == "common" and game.skills.value("pierce_common") > 0.0:
				passes = 1
			if passes > 0 and target is Infected and (not shielded or share > 0.0):
				endpoint = _pierce(data, passes, direction, target as Infected, struck, endpoint)
		if pellet < 8:
			game.fx.tracer(muzzle, endpoint)
	var any_head := false
	for enemy in struck:
		var entry: Dictionary = struck[enemy]
		any_head = any_head or entry.headshot
		# A blast of shot from close by throws back whoever is still standing after it.
		var push := 0.0
		if data.has("push") and not bool(entry.get("through", false)):
			push = float(data.push) * float(entry.pellets) / pellets * clampf(1.0 - (float(entry.near) - PUSH_NEAR) / (PUSH_FAR - PUSH_NEAR), 0.0, 1.0)
		if game.net.joined:
			# The host decides what the hit does; show the flinch right away.
			game.net.report_hit(enemy, entry.damage, entry.direction, entry.headshot, bool(entry.get("through", false)), push)
			(enemy as Infected).show_cue("hit", [1.0, float(entry.damage) / (enemy as Infected).max_health * 2.5])
		else:
			# A bullet that went through a shield is not stopped by it a second time.
			game.blasting = bool(entry.get("through", false))
			game.piercing = float(data.get("armour", 1.0))
			(enemy as Infected).receive_hit(entry.damage, entry.direction, entry.headshot)
			game.blasting = false
			game.piercing = 1.0
			if push >= PUSH_LEAST:
				(enemy as Infected).blown(entry.direction, push)
	if not struck.is_empty():
		game.hud.hit_marker(any_head)
	# A suppressed shot gives nobody the direction it came from.
	if not data.get("quiet", false):
		game.alarm(origin, -camera.global_basis.z)
	if game.net.active:
		game.net.send_shot(origin, endpoint, str(data.sound))
	var kick: float = float(data.kick) * (0.55 if aiming and pellets == 1 else 1.0) * (CROUCH_STEADY if crouched else 1.0)
	camera.rotation.x = minf(1.35, camera.rotation.x + kick)
	climb += kick * float(data.get("settle", 0.0))
	rotate_y(randf_range(-kick, kick) * 0.35)

func start_reload() -> void:
	if reload_left <= 0 and ammo < magazine_size() and reserve > 0:
		reload_left = reload_of(current_weapon)
		reload_cue = 0
		loading_shells = WEAPONS[current_weapon].has("shells")
		chamber_empty = ammo == 0
		if loading_shells:
			# The first shell takes a moment longer: the weapon has to be turned over.
			reload_left += 0.25

## `kind`: "bullet" and "frag" (the C.R.U.'s), "gas", "acid", or "" for a blow. `by`: what
## kind of enemy dealt it ("common", "special", "cru"), where that is known.
func receive_damage(amount: float, from: Vector3 = Vector3.INF, kind: String = "", by: String = "") -> void:
	if not controlled or health <= 0:
		return
	amount *= game.skills.harm_factor(kind, by)
	# Ballistic plates take the edge off whatever the C.R.U. shoot and throw.
	var hostile := kind in ["bullet", "frag"]
	if hostile:
		amount *= 1.0 - float(PLATE_SHARES[plate_level])
		kind = ""
	if armor > 0.0 and kind == "":
		var absorbed := minf(armor, amount * ARMOR_SHARE)
		armor -= absorbed
		amount -= absorbed
	health = maxf(0, health - amount)
	hurt_amount = minf(1.0, hurt_amount + 0.45 + amount * 0.02)
	if kind == "acid":
		acid_amount = 1.0
	else:
		trauma = minf(1.0, trauma + 0.3 + amount * 0.012)
	game.sounds.play_sound("hurt")
	if from != Vector3.INF and kind == "":
		game.hud.damage_from(from)
	if health <= 0:
		if int(items.revive) > 0:
			# The adrenaline shot keeps the survivor standing, once.
			items.revive = int(items.revive) - 1
			health = 50.0
			hurt_amount = 0.3
			game.hud.announce("ADRENALIN", "Die Spritze hält dich auf den Beinen.", 2.5)
			game.sounds.play_sound("equip")
		# With a partner or a standing squad the survivor goes down and can be helped up.
		elif (game.net.active and game.net.partner != 0) or game.rescuer() != null:
			go_down()
		else:
			game.finish(false)

## Co-op: out of the fight, but the match goes on while the partner still stands.
func go_down() -> void:
	down = true
	reload_left = 0.0
	crouched = false
	(body_shape.shape as CapsuleShape3D).height = STAND_HEIGHT
	body_shape.position.y = STAND_HEIGHT * 0.5
	var helper: Teammate = game.rescuer()
	if helper != null and not game.net.active:
		game.hud.announce("DU BIST AM BODEN", "%s kommt dir zu Hilfe." % helper.label, 5.0)
	else:
		game.hud.announce("DU BIST AM BODEN", "Dein Mitspieler kann dir aufhelfen. Nach der Runde stehst du wieder.", 5.0)

func get_up() -> void:
	down = false
	health = 50.0
	hurt_amount = 0.0
	game.hud.announce("WIEDER AUF DEN BEINEN", "", 2.0)

## Camera shake that fades with distance from its source.
func shake_from(source: Vector3, strength: float, reach: float) -> void:
	trauma = minf(1.0, trauma + strength * clampf(1.0 - global_position.distance_to(source) / reach, 0.0, 1.0))

func reset_survivor() -> void:
	position = game.cabin.player_start
	rotation = Vector3(0, PI, 0)
	camera.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	health = 100
	# The carbine first: it may have been traded in during the last night.
	inventory = {"rifle": {"ammo": int(WEAPONS.rifle.magazine), "reserve": reserve_cap("rifle"), "level": 0}}
	equip_weapon("rifle", true)
	_show_parts()
	reload_left = 0
	loading_shells = false
	pump_clock = -1.0
	climb = 0.0
	shot_cooldown = 0
	hurt_amount = 0
	acid_amount = 0
	trauma = 0
	mist_exposure = 0
	mist_damage_left = 0
	items = {"grenade": 0, "flashbang": 0, "molotov": 0, "claymore": 0, "revive": 0}
	trigger_held = false
	crouched = false
	(body_shape.shape as CapsuleShape3D).height = STAND_HEIGHT
	body_shape.position.y = STAND_HEIGHT * 0.5
	syringe_wait = 0.0
	syringe_left = 0.0
	extra_slots = 0
	melee_cooldown = 0.0
	melee_pose = 0.0
	flame_left = 0.0
	burn_report.clear()
	armor = 0.0
	plate_level = 0
	clung_by = null
	mask_level = 0
	filter_left = 0.0
	in_gas = false
	down = false
	menu_open = false
	flashlight.visible = true
