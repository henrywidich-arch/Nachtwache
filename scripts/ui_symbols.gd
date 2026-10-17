extends RefCounted
## One currency mark everywhere; vector tab icons remain sharp at every UI scale.
const TOKEN := "◈"
const PATHS := {
	"play": '<path d="M7 3l14 9-14 9z"/>',
	"settings": '<circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2"/>',
	"keyboard": '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h1M11 9h1M16 9h2M6 12h1M11 12h1M16 12h2M7 16h10"/>',
	"board": '<path d="M7 3h10v7a5 5 0 01-10 0zM7 5H3v3a4 4 0 004 4M17 5h4v3a4 4 0 01-4 4M12 15v5M7 21h10"/>',
	"exit": '<path d="M10 3H4v18h6M11 12h11M18 8l4 4-4 4"/>',
	"close": '<path d="M5 5l14 14M19 5L5 19"/>',
	"back": '<path d="M14 4l-8 8 8 8M6 12h16"/>',
	"test": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 1v4M12 19v4M1 12h4M19 12h4"/>',
	"notes": '<path d="M5 3h14v18H5zM8 8h8M8 12h8M8 16h5"/>',
	"skins": '<circle cx="12" cy="7" r="4"/><path d="M4 22v-4a8 8 0 0116 0v4M8 12l4 4 4-4"/>',
	"weapons": '<path d="M3 10h15l3 2-2 2h-7l-2 5H7l1-5H3zM14 8h4v2"/>',
	"sidearms": '<path d="M4 7h16v5H12l-2 7H6l2-9H4zM14 12v3h-4"/>',
	"heavy": '<path d="M2 8h20v6H10l-2 5H5l1-5H2zM12 14v5h7v-5M3 5v3M19 5v3"/>',
	"melee": '<path d="M5 20l5-5M8 13l3 3M10 14C17 12 20 8 20 3c-5 1-9 4-10 11z"/>',
	"class": '<path d="M12 3l3 6 6 1-4 5 1 6-6-3-6 3 1-6-4-5 6-1z"/>',
	"mods": '<circle cx="12" cy="12" r="5"/><path d="M12 2v5M12 17v5M2 12h5M17 12h5"/>',
	"kill": '<circle cx="12" cy="12" r="7"/><path d="M12 2v6M12 16v6M2 12h6M16 12h6"/>',
	"headshot": '<path d="M7 14V8a5 5 0 0110 0v6l-2 3v4H9v-4zM12 5v4M5 11h5M14 11h5"/><circle cx="12" cy="11" r="4"/>',
	"downed": '<circle cx="7" cy="6" r="3"/><path d="M6 10l4 4H5l-3 6M10 14l2 6M16 7h4M18 5v4M18 13v8M15 18l3 3 3-3"/>',
	"gear": '<path d="M8 3H5l-2 6 3 3v9h12v-9l3-3-2-6h-3l-1 5H9zM8 13h8M8 17h8"/>',
	"use": '<path d="M10 3h6v4h-6zM10 7l-3 4v7l4 3h5l4-4-1-7-3-3M16 4h5v4"/>',
	"team": '<circle cx="8" cy="7" r="3"/><circle cx="17" cy="8" r="2.5"/><path d="M2 21v-5a6 6 0 0112 0v5M15 14a5 5 0 017 4v3"/>',
	"syringe": '<path d="M6 3l5 5M3 6l5 5M8 8l9 9M6 10l4-4 10 10-4 4zM19 19l3 3"/>',
	"heal": '<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>',
	"flashbang": '<path d="M9 7h7l3 14H7zM9 3h8v4M3 5L1 3M21 6l2-2M4 11H1"/>',
	"molotov": '<path d="M11 3h4v7l5 10-3 2H7l-2-2 6-10zM15 5l5-3 2 3"/>',
	"claymore": '<path d="M3 7h18v9H3zM7 16l-2 6M17 16l2 6M12 7V2M8 11h8"/>'
}
static var textures: Dictionary = {}

static func money(amount: int) -> String:
	return "%d %s" % [amount, TOKEN]

static func icon(kind: String) -> Texture2D:
	if not textures.has(kind):
		var picture := Image.new()
		var path: String = PATHS.get(kind, PATHS.use)
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#eef4f6" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % path, 2.0)
		textures[kind] = ImageTexture.create_from_image(picture)
	return textures[kind]
