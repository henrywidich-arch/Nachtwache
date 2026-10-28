class_name WeaponSkins
extends RefCounted
## Paint jobs for weapons (v0.79): won from crates (Rewards), each lies over the whole
## body of one weapon - the parts on it (sights, lights, the hands) keep their own look.
## Each skin is a painted picture of one weapon from the side, projected on it in its own
## space (triplanar), so it needs no unwrapped model and works in the first-person view, the
## showroom and the crate alike. The weave of the weapon (its normal and roughness maps)
## stays under the paint.
##
## boost: what a skin gives the weapon it is on, as shares in the lines of a rare weapon
## (Survivor.rare: damage, reload, steady, mags, reserve). Kept small: a skin is a look first.

const SKINS := {
	# A painted picture of one weapon from its left side (tools/skin_templates.gd shows the
	# view): it is laid on exactly that weapon, edge to edge (image, weapons). flip: which of
	# the picture's axes run against the weapon's.
	"mondnacht": {"label": "MONDNACHT", "rarity": "legendary", "note": "Schwarz und Gold: Vollmond, Kiefer und Wolken.",
		"boost": {"damage": 0.05, "reload": 0.06}, "metal": 0.45, "rough": 0.35, "accent": Color("d9b05a"), "base": Color("15130f"),
		"image": "res://assets/skins/mondnacht_rifle.png", "weapons": ["rifle"], "flip": Vector2(-1, 1)},
	"toxin": {"label": "TOXIN", "rarity": "epic", "note": "Biogefahr: Warnstreifen und Giftgrün auf schmutzigem Schwarz.",
		"boost": {"steady": 0.08, "reserve": 0.1}, "metal": 0.3, "rough": 0.55, "accent": Color("c8e021"), "base": Color("1d1d16"),
		"image": "res://assets/skins/toxin_rifle.png", "weapons": ["rifle"], "flip": Vector2(-1, 1)},
	"sakura": {"label": "SAKURA", "rarity": "legendary", "note": "Weiß, Schwarz und Pink: Kirschblüten und ein gemaltes Gesicht auf dem Gehäuse.",
		"boost": {"damage": 0.04, "steady": 0.06}, "metal": 0.2, "rough": 0.4, "accent": Color("ff4fa3"), "base": Color("e9e3e6"),
		"image": "res://assets/skins/sakura_rifle.png", "weapons": ["rifle"], "flip": Vector2(-1, 1)},
	"vektor": {"label": "VEKTOR", "rarity": "epic", "note": "Weiß mit orangen und schwarzen Schrägbalken.",
		"boost": {"reload": 0.08, "mags": 0.1}, "metal": 0.15, "rough": 0.45, "accent": Color("f2701d"), "base": Color("e6e2da"),
		"image": "res://assets/skins/vektor_rifle.png", "weapons": ["rifle"], "flip": Vector2(-1, 1)},
	# (These two were painted on the pictures of the right side: there the muzzle points right.)
	"drache": {"label": "ROTER DRACHE", "rarity": "legendary", "note": "Schwarz und Rot: ein Drache windet sich über das Gehäuse, dazu Wolken und Streifen.",
		"boost": {"damage": 0.05, "mags": 0.1}, "metal": 0.3, "rough": 0.45, "accent": Color("d8262b"), "base": Color("151213"),
		"image": "res://assets/skins/drache_p90.png", "weapons": ["p90"], "flip": Vector2(1, 1)},
	"neon": {"label": "NEONPULS", "rarity": "epic", "note": "Schwarz und Grau mit leuchtenden Cyan- und Magenta-Streifen.",
		"boost": {"reload": 0.08, "steady": 0.06}, "metal": 0.35, "rough": 0.4, "accent": Color("2fe6f0"), "base": Color("17191c"),
		"image": "res://assets/skins/neon_wirbel.png", "weapons": ["wirbel"], "flip": Vector2(1, 1)}
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

## The picture of a skin as a texture (cut once from its image; magenta for an unknown one).
static func texture(skin: String) -> Texture2D:
	if not textures.has(skin):
		textures[skin] = _picture(str(SKINS[skin].image) if SKINS.has(skin) else "")
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
	var source: Texture2D = (load(path) as Texture2D) if path != "" and ResourceLoader.exists(path) else null
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
