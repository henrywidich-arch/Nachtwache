class_name WeaponSkins
extends RefCounted
## Paint jobs for weapons (v0.79): won from crates (Rewards), each lies over the whole
## body of one weapon - the parts on it (sights, lights, the hands) keep their own look.
## The pattern is projected from three sides in the weapon's own space (triplanar), so it
## needs no unwrapped model and fits every weapon of the game, the first-person view, the
## showroom and the crate alike. The weave of the weapon (its normal and roughness maps)
## stays under the paint.
##
## boost: what a skin gives the weapon it is on, as shares in the lines of a rare weapon
## (Survivor.rare: damage, reload, steady, mags, reserve). Kept small: a skin is a look first.

const SKINS := {
	"drache": {"label": "ROTER DRACHE", "rarity": "legendary", "note": "Roter Lack, goldener Drache und Wolken.",
		"boost": {"damage": 0.06, "steady": 0.05}, "metal": 0.25, "rough": 0.38, "scale": 0.95, "accent": Color("d8a83a"), "base": Color("9b1418")},
	"orbital": {"label": "ORBITAL", "rarity": "epic", "note": "Weiß-orange Raumfahrt-Lackierung mit Plattenfugen.",
		"boost": {"reload": 0.1, "steady": 0.06}, "metal": 0.1, "rough": 0.5, "scale": 1.0, "accent": Color("f2701d"), "base": Color("e9e6df")},
	"tiefsee": {"label": "TIEFSEE", "rarity": "rare", "note": "Nachtblau mit leuchtenden Höhenlinien.",
		"boost": {"mags": 0.1, "reserve": 0.15}, "metal": 0.3, "rough": 0.45, "scale": 1.6, "accent": Color("35d0e0"), "base": Color("0f2747")},
	# A painted picture of one weapon from its left side (tools/skin_templates.gd shows the
	# view): it is laid on exactly that weapon, edge to edge (image, weapons). flip: which of
	# the picture's axes run against the weapon's.
	"mondnacht": {"label": "MONDNACHT", "rarity": "legendary", "note": "Schwarz und Gold: Vollmond, Kiefer und Wolken.",
		"boost": {"damage": 0.05, "reload": 0.06}, "metal": 0.45, "rough": 0.35, "accent": Color("d9b05a"), "base": Color("15130f"),
		"image": "res://assets/skins/mondnacht_rifle.png", "weapons": ["rifle"], "flip": Vector2(-1, 1)}
}
const RARITIES := {
	"rare": {"label": "SELTEN", "color": Color("4f8dff")},
	"epic": {"label": "EPISCH", "color": Color("b05cff")},
	"legendary": {"label": "LEGENDÄR", "color": Color("ffb43a")},
	"gear": {"label": "AUSRÜSTUNG", "color": Color("5fd48a")}
}
## What each line of a boost is called.
const BOOST_WORDS := {"damage": "+%d %% Schaden", "reload": "%d %% schneller nachladen", "steady": "+%d %% Stabilität", "mags": "+%d %% Magazin", "reserve": "+%d %% Reserve"}

## The middle band of a pattern lies this share of its height above the middle of the
## weapon: on the receiver and the slide, not on the grip and the magazine below.
const UPPER := 0.2

static var textures: Dictionary = {}
static var painted: Dictionary = {}

static func boost_words(skin: String) -> String:
	var said: Array[String] = []
	var boost: Dictionary = SKINS.get(skin, {}).get("boost", {})
	for line in boost:
		said.append(str(BOOST_WORDS[line]) % int(round(float(boost[line]) * 100.0)))
	return "  ·  ".join(said)

## The pattern of a skin as a texture (drawn once from its SVG).
static func texture(skin: String) -> Texture2D:
	if textures.has(skin):
		return textures[skin]
	var image := Image.new()
	if SKINS.has(skin) and SKINS[skin].has("image"):
		textures[skin] = _picture(str(SKINS[skin].image))
		return textures[skin]
	var code: String = {"drache": _dragon(), "orbital": _orbital(), "tiefsee": _deep()}.get(skin, "")
	if code == "" or image.load_svg_from_string(code, 1.0) != OK:
		image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.MAGENTA)
	image.generate_mipmaps()
	textures[skin] = ImageTexture.create_from_image(image)
	return textures[skin]

## Puts a skin on a weapon model (as WeaponView builds it, for the hand or the showroom),
## or takes it off again with "". What it paints: the body of the weapon. What it leaves:
## the hands and arms, fitted parts (Mod_*), glass, glowing and see-through things.
## The pattern is fitted to the weapon: `scale` tiles of it over the length of the body,
## centred on it (so the dragon runs along the side of a pistol as of a rifle).
static func apply(view: Node, skin: String) -> void:
	if view == null:
		return
	var parts: Array = []
	var box := AABB()
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or _spared(mesh, view):
			continue
		var frame := _frame_in(mesh, view)
		parts.append([mesh, frame])
		var part: AABB = frame * mesh.mesh.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	var tiles := float(SKINS.get(skin, {}).get("scale", 1.0)) / maxf(box.size.z, 0.15)
	# A picture of the weapon lies on it edge to edge: its width over the length, its height
	# over the height, the middle on the middle.
	var picture: bool = SKINS.has(skin) and SKINS[skin].has("image")
	if picture:
		# (The picture shows the whole weapon, its iron sights too: so is it measured.)
		box = _whole(view)
	var flip: Vector2 = SKINS.get(skin, {}).get("flip", Vector2.ONE)
	var fit := Vector3(1.0 / maxf(box.size.z, 0.01), flip.y / maxf(box.size.y, 0.01), flip.x / maxf(box.size.z, 0.01))
	for entry: Array in parts:
		var mesh: MeshInstance3D = entry[0]
		var frame: Transform3D = entry[1]
		for surface in range(mesh.mesh.get_surface_count()):
			var key := "skin_base_%d" % surface
			if not mesh.has_meta(key):
				mesh.set_meta(key, mesh.get_surface_override_material(surface))
			var base: Material = mesh.get_meta(key)
			if skin == "" or not SKINS.has(skin):
				mesh.set_surface_override_material(surface, base)
				continue
			var source := (base if base != null else mesh.mesh.surface_get_material(surface)) as BaseMaterial3D
			if source == null or not _paintable(source):
				continue
			# (In the part's own space: its units, and where the middle of the weapon lies.)
			if picture:
				var across: Vector3 = fit * frame.basis.get_scale().x
				var centre: Vector3 = frame.affine_inverse() * box.get_center()
				mesh.set_surface_override_material(surface, painted_from(source, skin, across, Vector3(0.5, 0.5, 0.5) - centre * across))
				continue
			var size := frame.basis.get_scale().x * tiles
			var middle: Vector3 = frame.affine_inverse() * (box.get_center() + Vector3(0, box.size.y * UPPER, 0))
			mesh.set_surface_override_material(surface, painted_from(source, skin, Vector3.ONE * size, Vector3(0.5, 0.5, 0.5) - middle * size))
	view.set_meta("skin", skin)

## The painted twin of a material (made once for each size and place of the pattern).
static func painted_from(source: BaseMaterial3D, skin: String, size: Vector3 = Vector3.ONE, offset: Vector3 = Vector3.ZERO) -> BaseMaterial3D:
	var slot := "%d|%s|%.3v|%.2v" % [source.get_instance_id(), skin, size, offset]
	if painted.has(slot):
		return painted[slot]
	var data: Dictionary = SKINS[skin]
	var paint := source.duplicate() as BaseMaterial3D
	paint.detail_enabled = true
	paint.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	paint.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	paint.detail_albedo = texture(skin)
	paint.uv2_triplanar = true
	paint.uv2_world_triplanar = false
	paint.uv2_triplanar_sharpness = 4.0
	paint.uv2_scale = size
	# (A picture covers the weapon once; a sharper blend keeps the sides from smearing.)
	if data.has("image"):
		paint.uv2_triplanar_sharpness = 12.0
	paint.uv2_offset = offset
	# (What colours the vertices of a built weapon would tint the paint: it lies on top.)
	paint.vertex_color_use_as_albedo = false
	paint.albedo_color = Color.WHITE
	paint.metallic = float(data.metal)
	paint.metallic_texture = null
	paint.roughness = float(data.rough)
	paint.roughness_texture = null
	painted[slot] = paint
	return paint

static func _paintable(material: BaseMaterial3D) -> bool:
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return false
	if material.emission_enabled or material.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		return false
	# The hands and arms share materials of their own (WeaponView.ARM_PARTS).
	for key in WeaponView.ARM_PARTS:
		if WeaponView.materials.get(key) == material or WeaponView.materials.get(key + "_world") == material:
			return false
	return true

## Hands, arms, fitted parts, the muzzle flash and the reticles keep their look.
static func _spared(mesh: Node, view: Node) -> bool:
	var at: Node = mesh
	while at != null and at != view:
		var title := str(at.name)
		if title == "Support" or title.begins_with("Hand") or title.begins_with("Mod_") or title in ["Flash", "LeftFlash", "Sights"] or bool(at.get_meta("view_hand", false)) or title.begins_with("Reticle") or title.begins_with("Laser"):
			return true
		if title.begins_with("Part") and at.get_parent() == view:
			return true
		at = at.get_parent()
	return false

# ---------------------------------------------------------------- the patterns

## Red lacquer: clouds in a darker red and a gold dragon that winds along the weapon, its
## head toward the muzzle (the texture's right; the middle band is the side of the weapon).
static func _dragon() -> String:
	var body := "M30 540 C 90 450, 150 630, 220 540 S 330 440, 400 520 S 480 600, 560 500"
	var scales := ""
	for i in range(3):
		scales += '<path d="%s" fill="none" stroke="#7a4c0c" stroke-width="%d" stroke-dasharray="10 16" stroke-dashoffset="%d" stroke-linecap="round" opacity="0.75"/>' % [body, 52 - i * 16, i * 13]
	var clouds := ""
	for spot: Vector2 in [Vector2(30, 130), Vector2(300, 60), Vector2(560, 150), Vector2(820, 70), Vector2(160, 300), Vector2(700, 300),
			Vector2(60, 760), Vector2(330, 830), Vector2(600, 740), Vector2(860, 820), Vector2(200, 940), Vector2(720, 950), Vector2(430, 300), Vector2(470, 720)]:
		clouds += '<use href="#cloud" x="%d" y="%d"/>' % [int(spot.x), int(spot.y)]
	return """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7d0c0e"/><stop offset="0.5" stop-color="#a5161a"/><stop offset="1" stop-color="#7d0c0e"/></linearGradient>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe7a0"/><stop offset="0.45" stop-color="#e2ad3c"/><stop offset="1" stop-color="#94640f"/></linearGradient>
<g id="cloud" fill="none" stroke-linecap="round">
<path d="M0 40 q30 -40 60 0 q20 -30 45 -5 q25 -35 55 0 q30 30 0 50 q-25 15 -40 -5 M60 40 q10 25 35 20 M20 70 q-20 10 -10 30" stroke-width="10"/>
</g>
</defs>
<rect width="1024" height="1024" fill="url(#bg)"/>
<g stroke="#5a0608" opacity="0.7">%s</g>
<g stroke="#e3b24a" opacity="0.5" transform="translate(40 30)"><use href="#cloud" x="880" y="380"/><use href="#cloud" x="0" y="620"/></g>
<path d="M0 420 H1024 M0 660 H1024" stroke="#d9a83a" stroke-width="5" opacity="0.6"/>
<path d="M0 404 H1024 M0 676 H1024" stroke="#d9a83a" stroke-width="2" opacity="0.5" stroke-dasharray="18 10"/>
<path d="%s" fill="none" stroke="#3a0905" stroke-width="84" stroke-linecap="round"/>
<path d="%s" fill="none" stroke="url(#gold)" stroke-width="70" stroke-linecap="round"/>
%s
<path d="%s" fill="none" stroke="#fff0b8" stroke-width="10" stroke-dasharray="30 14" opacity="0.85" transform="translate(0 -18)"/>
<path d="%s" fill="none" stroke="#c7302a" stroke-width="16" stroke-dasharray="4 22" opacity="0.95" transform="translate(0 -40)"/>
<g fill="url(#gold)" stroke="#3a0905" stroke-width="5" stroke-linejoin="round">
<path d="M140 570 l-26 54 l16 -6 l-6 28 l18 -20 l6 26 l8 -34 z"/>
<path d="M300 470 l-22 -52 l18 8 l-4 -28 l16 20 l12 -24 l2 38 z"/>
<path d="M450 565 l24 50 l4 -18 l22 16 l-10 -24 l28 0 l-34 -20 z"/>
</g>
<g transform="translate(575 495)" stroke="#3a0905" stroke-width="6" stroke-linejoin="round">
<path d="M-30 -46 L56 -56 L118 -30 L156 -12 L114 2 L156 18 L108 32 L58 50 L-30 44 Z" fill="url(#gold)"/>
<path d="M6 -48 L-30 -110 L30 -62 Z M38 -54 L26 -120 L68 -60 Z" fill="#ffd56e"/>
<circle cx="64" cy="-22" r="12" fill="#fff4c8"/><circle cx="67" cy="-22" r="6" fill="#2a0603"/>
<path d="M120 -26 C 170 -60, 150 -120, 210 -130" fill="none" stroke="#ffd56e" stroke-width="5"/>
<path d="M118 24 C 168 56, 150 118, 210 126" fill="none" stroke="#ffd56e" stroke-width="5"/>
<path d="M-30 -40 L-70 -76 L-58 -30 L-100 -28 L-58 0 L-100 28 L-58 30 L-70 72 L-30 40" fill="#c7302a"/>
<path d="M156 -12 L176 -6 L156 0 M156 18 L178 14" fill="none" stroke="#ff9a2e" stroke-width="6"/>
</g>
<g fill="#ff9a2e" opacity="0.9" transform="translate(860 500)"><circle cx="0" cy="0" r="26" fill="#fff0b8" stroke="#e2ad3c" stroke-width="6"/>
<path d="M30 0 q24 -18 10 -50 q-2 18 -16 22 q4 -26 -14 -40 q2 30 -12 36 q4 22 32 32z M-30 0 q-24 18 -10 50 q2 -18 16 -22 q-4 26 14 40 q-2 -30 12 -36 q-4 -22 -32 -32z"/>
</g>
</svg>""" % [clouds, body, body, scales, body, body]

## White and orange of a spacecraft: panels with their seams, a black band, warning stripes
## and small print.
static func _orbital() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
<pattern id="haz" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="40" height="40" fill="#f2701d"/><rect width="20" height="40" fill="#1c1f22"/></pattern>
</defs>
<rect width="1024" height="1024" fill="#e9e6df"/>
<polygon points="0,560 600,560 700,460 1024,460 1024,700 0,700" fill="#f2701d"/>
<polygon points="0,526 590,526 690,426 1024,426 1024,444 698,444 598,544 0,544" fill="#1c1f22"/>
<polygon points="0,498 580,498 680,398 1024,398 1024,406 684,406 584,506 0,506" fill="#f2701d"/><polygon points="0,720 1024,720 1024,736 0,736" fill="#1c1f22"/>
<rect x="60" y="60" width="240" height="70" fill="#1c1f22"/>
<rect x="72" y="72" width="216" height="46" fill="#f2701d"/>
<text x="84" y="108" font-family="sans-serif" font-weight="bold" font-size="34" fill="#1c1f22">ORBITAL</text>
<text x="120" y="470" font-family="sans-serif" font-weight="bold" font-size="56" fill="#1c1f22">NW-79</text>
<text x="760" y="640" font-family="monospace" font-size="22" fill="#1c1f22">MK.II  //  LOT 0451</text>
<rect x="720" y="860" width="240" height="60" fill="url(#haz)"/>
<rect x="60" y="880" width="320" height="16" fill="#1c1f22"/>
<g fill="none" stroke="#9a978f" stroke-width="4">
<path d="M0 160 H1024 M0 860 H700 M340 0 V160 M820 0 V160 M180 860 V1024 M520 860 V1024 M860 560 V860 M420 540 L700 860"/>
<rect x="400" y="600" width="300" height="180" rx="16"/>
</g>
<g fill="#6f6c66">
<circle cx="360" cy="20" r="9"/><circle cx="360" cy="140" r="9"/><circle cx="800" cy="20" r="9"/><circle cx="800" cy="140" r="9"/>
<circle cx="420" cy="620" r="8"/><circle cx="680" cy="620" r="8"/><circle cx="420" cy="760" r="8"/><circle cx="680" cy="760" r="8"/>
<circle cx="200" cy="880" r="8"/><circle cx="500" cy="1000" r="8"/>
</g>
<g fill="#1c1f22"><polygon points="450,660 480,660 465,690"/><rect x="500" y="666" width="160" height="10"/><rect x="500" y="690" width="110" height="10"/></g>
<circle cx="900" cy="760" r="44" fill="none" stroke="#f2701d" stroke-width="12"/>
<circle cx="900" cy="760" r="14" fill="#1c1f22"/>
</svg>"""

## Night blue with glowing contour lines, as on a chart of the deep sea.
static func _deep() -> String:
	var lines := ""
	for i in range(14):
		var y := 40 + i * 72
		var a := 26 + (i % 4) * 10
		lines += '<path d="M-20 %d C 160 %d, 320 %d, 512 %d S 860 %d, 1044 %d" />' % [y, y - a, y + a, y, y - a, y]
	var rings := ""
	for r in [40, 80, 120, 160]:
		rings += '<ellipse cx="300" cy="420" rx="%d" ry="%d"/><ellipse cx="780" cy="760" rx="%d" ry="%d"/>' % [r, int(r * 0.7), int(r * 0.8), int(r * 0.55)]
	return """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><radialGradient id="g" cx="0.5" cy="0.5" r="0.7"><stop offset="0" stop-color="#16345e"/><stop offset="1" stop-color="#091a33"/></radialGradient></defs>
<rect width="1024" height="1024" fill="url(#g)"/>
<g fill="none" stroke="#35d0e0" stroke-width="5" opacity="0.75">%s</g>
<g fill="none" stroke="#7ff0ff" stroke-width="4" opacity="0.6">%s</g>
<g fill="#7ff0ff" opacity="0.8"><circle cx="120" cy="200" r="6"/><circle cx="640" cy="120" r="5"/><circle cx="920" cy="420" r="6"/><circle cx="460" cy="900" r="5"/><circle cx="200" cy="760" r="4"/></g>
<text x="40" y="990" font-family="monospace" font-size="26" fill="#35d0e0" opacity="0.8">-4120 m</text>
</svg>""" % [lines, rings]

## Where a part lies in the weapon (models come in other units and places).
static func _frame_in(mesh: Node3D, view: Node) -> Transform3D:
	var frame := Transform3D.IDENTITY
	var at: Node = mesh
	while at != null and at != view:
		if at is Node3D:
			frame = (at as Node3D).transform * frame
		at = at.get_parent()
	return frame

## A painted picture of a weapon as a skin: cut to the weapon (the background, the colour
## of its corners, is cut away round it and darkened where it shows between the parts).
static func _picture(path: String) -> Texture2D:
	var source := load(path) as Texture2D
	if source == null:
		var blank := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		blank.fill(Color.MAGENTA)
		return ImageTexture.create_from_image(blank)
	var image := source.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var back := image.get_pixel(2, 2)
	var w := image.get_width()
	var h := image.get_height()
	var low := Vector2i(w, h)
	var high := Vector2i(-1, -1)
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if _apart(image.get_pixel(x, y), back):
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x <= low.x or high.y <= low.y:
		return source
	var cut := image.get_region(Rect2i(low, high - low + Vector2i.ONE))
	var dark := Color(0.08, 0.075, 0.065)
	for y in range(cut.get_height()):
		for x in range(cut.get_width()):
			if not _apart(cut.get_pixel(x, y), back):
				cut.set_pixel(x, y, dark)
	cut.generate_mipmaps()
	return ImageTexture.create_from_image(cut)

static func _apart(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.09

## What the whole weapon takes up, as a picture of it shows it: every part that is shown,
## but not the hands and arms.
static func _whole(view: Node) -> AABB:
	var box := AABB()
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var shown := true
		var hand := false
		var at: Node = mesh
		while at != null and at != view:
			var title := str(at.name)
			hand = hand or title == "Support" or title.begins_with("Hand") or bool(at.get_meta("view_hand", false)) or (title.begins_with("Part") and at.get_parent() == view) or title in ["Flash", "LeftFlash"]
			shown = shown and (not (at is Node3D) or (at as Node3D).visible)
			at = at.get_parent()
		if hand or not shown:
			continue
		var part: AABB = _frame_in(mesh, view) * mesh.mesh.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	return box
