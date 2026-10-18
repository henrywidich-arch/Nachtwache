extends RefCounted
## Side profiles for individual weapons, and pictograms for each piece of equipment.
const WEAPONS := {
	"rifle": 'M5 21h9l7-6h34l5 3h29v5H61l-8 6H39l-5 12h-7l3-13H14L5 34zM29 15v-4h16v4M47 29l6 12h8l-6-14M67 18v8',
	"ak": 'M4 23l14-5h38l6 3h29v4H62l-8 6H39l-4 10h-7l2-13H18L4 35zM41 31c2 10 7 13 14 14l4-6c-6-3-9-6-10-11M63 18h14v3M83 17v8',
	"g36": 'M5 23l12-6h46l5 4h22v5H65l-8 5H40l-5 11h-7l2-13H17L5 35zM24 17v-7h34v7M29 12h22M47 31v11h10V28',
	"wirbel": 'M4 24l16-4h40l5 4h27v5H63l-8 6H40l-5 11h-7l2-15H18L4 36zM33 19a11 5 0 1022 0 11 5 0 00-22 0M30 13h31v3M47 31l5 11h8l-4-13M66 29l-2 9h6l1-9',
	"p90": 'M8 18h52l7 5h19v5H65l-6 11H39l-3-7H21l-3 7H8zM20 12h36v6M37 25h14v7H37zM12 23h11',
	"ump": 'M5 20h52l6 3h21v5H56l-6 5H35l-4 10h-7l3-15H15L5 34zM36 33v12h7V31M20 20v-5h25v5',
	"mp7": 'M13 19h40l8 4h20v5H56l-5 6H38l-3 10H24l3-16H13zM35 32v14h8V31M10 20H4v15h9M28 14h20v5',
	"badger": 'M5 22l12-6h37l7 4h16v-3h16v12H76v-4H59l-8 6H38l-3 11h-7l2-14H16L5 34zM42 31l3 10h9l-4-13M25 16v-5h22v5',
	"m14": 'M4 26l17-4h39l4-4h28v5H66l-9 7H37L22 40H8l5-10H4zM37 30l-1 10h10l3-12M24 18h29v4',
	"shotgun": 'M4 25l17-4h67v5H41l-4 6H25L12 40H4l7-10H4zM44 26h23v8H43zM72 17h15v4',
	"pistol": 'M22 11h48v12H51l-8 19H28l7-22H22zM49 23v8H39M60 11V8h7v3',
	"revolver": 'M18 14h27l4-4h29v9H53l-5 10H34L28 42H15l8-20H18zM33 14h14v13H33zM38 17v7M46 29v5H33',
	"autoshotgun": 'M4 22l12-6h44l7 6h24v6H61l-9 6H36l-5 11h-7l2-16H15L4 34zM45 34v10h13V30M65 17h22v5',
	"sniper": 'M3 26l18-4h39l4-3h29v5H65l-10 6H35L20 40H7l5-10H3zM31 15h26v6H31zM34 12h19v3M64 25l-5 16M70 25l7 16M39 30v9h9v-9',
	"svd": 'M4 24l18-4h37l6 2h28v4H62l-8 6H38L25 42H12l8-15H4zM32 13h24v7H32zM41 32l3 13h11l-5-16M68 17h17v5',
	"launcher": 'M7 21l16-5h32l8 5h25v9H61l-5 7H37l-5 7h-8l3-15H18L7 35zM39 25a11 11 0 1022 0 11 11 0 00-22 0M48 19h5v15h-5z',
	"mg": 'M3 21l15-4h42l6 4h27v6H60l-8 5H35l-4 11h-7l2-15H16L3 34zM39 31h20v14H39zM69 27l-5 15M75 27l7 15M25 13h28v4',
	"mg2": 'M3 22l17-5h43l5 5h24v5H61l-9 6H34l-4 10h-7l3-16H17L3 34zM39 34a10 10 0 1020 0 10 10 0 00-20 0M43 34h12M70 27l8 15M69 27l-6 15',
	"minigun": 'M6 17h27v18H6zM33 14h49v23H33zM39 20h50M39 26h50M39 32h50M18 12V7h19v7M18 35v10h10V35M72 14v23',
	"flamer": 'M5 21l15-5h31l7 6h23v8H55l-9 6H32l-5 9h-7l2-17H13L5 34zM34 36c-8 8-19-1-19-9M38 13V5h13v17M85 27c-5-5 6-10 4-17 12 12 8 20-4 17',
	"nitro": 'M4 25l18-4h66v9H41l-8 5H24L13 42H4l9-13H4zM39 21v9M47 25h41M28 31l3 7h7l3-9',
	"fifty": 'M3 22l16-5h36l6 4h24v-3h10v10H84v-3H60l-9 7H34l-5 12h-7l3-16H15L3 34zM28 12h28v6H28zM39 32v11h15V30M68 25l-5 17M74 25l9 17',
	"usp": 'M20 12h50v12H51l-7 18H28l7-21H20zM48 24v8H39M58 12v-3h10v3M24 17h42',
	"hornet": 'M16 11h52v12H50l-6 16H29l6-16H16zM68 13h8v8h-8M31 39l-3 8h12l3-8M50 23v8H41M57 23h9v4M20 14v6M24 14v6M60 14v6',
	"g18": 'M22 11h49v12H52l-6 19H29l6-21H22zM34 36l-4 11h12l4-11M49 23v8H41M27 15h7M61 15h6',
	"deagle": 'M18 11h57l5 6-3 9H54l-8 18H28l8-21H18zM49 26v9H38M27 16h45M59 11V7h11v4'
}
const MELEE := {
	"bash": 'M3 9h14l4 3-3 3h-7l-2 6H5l2-9H3zM17 3l4 3-4 3M13 6h8',
	"knife": 'M5 21l5-6M8 13l4 3M10 14l2-6 8-6c0 6-3 10-10 12z',
	"machete": 'M3 22l5-6M6 14l4 3M8 15L15 3l7-1c-1 7-6 12-14 13z',
	"axe": 'M5 22L16 3M11 6l5-3 6 2-1 8-8-2z',
	"bat": 'M3 22l8-10c0-4 7-12 10-10s-2 11-6 12L5 24M2 21l4 3',
	"crowbar": 'M4 22L15 5c4-6 10-1 6 3M3 20l3 2M18 5l2 2',
	"hammer": 'M6 22L17 5M11 3l4-2 8 6-4 5-8-6z'
}
const ITEMS := {
	"grenade": 'M9 7h6l4 6-2 8H7l-2-8zM9 7V3h7v4M14 3h6v6M7 12h10M7 17h10M12 8v12',
	"flashbang": 'M9 7h7l3 14H7zM9 3h8v4M3 5L1 3M21 6l2-2M4 11H1M11 10v7M15 10v7',
	"molotov": 'M10 4h5v6l5 11H5l5-11zM14 4l3-2 4 2M11 13h5M17 7c1-2 4-3 3-6',
	"claymore": 'M3 7h18v9H3zM7 16l-2 6M17 16l2 6M12 7V2M7 11h10M7 13h10',
	"revive": 'M4 3l5 5M2 5l5 5M7 8l3-3 11 11-5 5L5 10zM19 20l3 3M12 9l3 3M11 13l3-3',
	"heal": 'M9 5h6l4 7-2 9H7l-2-9zM10 2h7v3M9 13h6M12 10v6',
	"heal_kit": 'M8 4h8v4h5v13H3V8h5zM9 13h6M12 10v6M8 4v4h8V4',
	"vest": 'M8 3H5L2 9l4 3v9h12v-9l4-3-3-6h-3l-1 5H9zM8 13h8M8 17h8',
	"armor": 'M7 2H4L1 9l4 4v9h14v-9l4-4-3-7h-3l-2 6H9zM8 11h8v9H8zM3 10l3-3M18 7l3 3',
	"plates": 'M6 2h12l3 5-2 15H5L3 7zM7 6h10M8 10h8M8 14h8M8 18h8',
	"sling": 'M5 2h5l9 20h-5zM6 7l8-4 3 7-8 4zM13 16l4-2',
	"mask": 'M4 3h16l2 11-5 8H7l-5-8zM5 7h6v5H5zM13 7h6v5h-6zM9 17a3 3 0 106 0 3 3 0 00-6 0M2 14h4v5H2M18 14h4v5h-4',
	"squad_armor": 'M3 4l7-2 7 2v7c0 6-7 11-7 11S3 17 3 11zM7 9h6M10 6v6M18 7h4v9l-4 4',
	"squad_ammo": 'M3 21V8l3-5 3 5v13zM10 21V8l3-5 3 5v13zM17 21V8l3-5 3 5v13zM3 16h20',
	"reddot": 'M4 21v-3h16v3M6 18V7l3-4h7l3 4v11zM8 12h8M12 8v8',
	"scope": 'M2 7h4v10H2zM6 9h11v6H6zM17 5h5v14h-5zM9 15v5M15 15v5',
	"silencer": 'M2 8h20v8H2zM5 8v8M18 8v8M8 11h7M8 14h7',
	"akimbo": 'M2 5h9v5H7l-2 9H1l2-10H2zM13 5h9v5h-4l-2 9h-4l2-10h-1z'
}
static var textures: Dictionary = {}

static func for_entry(kind: String, id: String, part: String = "") -> Texture2D:
	var key := "%s/%s/%s" % [kind, id, part]
	if not textures.has(key):
		var wide := kind in ["weapon", "bench"]
		var shape: String = WEAPONS.get(id, WEAPONS.rifle) if wide else (MELEE.get(id, MELEE.knife) if kind == "melee" else ITEMS.get(part if kind == "part" else id, ITEMS.grenade))
		var picture := Image.new()
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="48" viewBox="%s"><g fill="none" stroke="#eef4f6" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></g></svg>' % ["0 0 96 48" if wide else "0 0 24 24", "2.3" if wide else "1.6", shape], 2.0)
		textures[key] = ImageTexture.create_from_image(picture)
	return textures[key]
