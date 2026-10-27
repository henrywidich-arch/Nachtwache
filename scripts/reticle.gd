class_name Reticle
extends RefCounted
## What the player made of the aiming marks in the reticle workshop (reticle_menu.gd): the
## colour, size, line strength and brightness of the dot in every reflex sight, of the ring
## in the P90's sight and of the laser module's dot. The marks are the quads WeaponView
## builds with the meta "reticle" ("core": the bright middle, "halo": the soft glow round
## it, "ring": the P90's ring); their materials are WeaponView's. Kept in the settings
## file, section "reticle" (Game.keep_setting; read back by Game when it starts).

## The red the sights came with.
const DEFAULT_COLOR := Color(1.0, 0.09, 0.045)
## The colours the workshop offers first: [name, colour].
const PRESETS := [
	["ROT", Color(1.0, 0.09, 0.045)], ["GRÜN", Color(0.15, 1.0, 0.2)], ["GELB", Color(1.0, 0.85, 0.1)],
	["CYAN", Color(0.1, 0.9, 1.0)], ["MAGENTA", Color(1.0, 0.15, 0.8)], ["WEISS", Color(1.0, 1.0, 1.0)]
]
const SIZE_RANGE := Vector2(0.5, 1.8)
const THICK_RANGE := Vector2(0.5, 2.0)
const GLOW_RANGE := Vector2(0.4, 1.6)

static var color := DEFAULT_COLOR
static var size := 1.0
static var thick := 1.0
static var glow := 1.0
## The quads of the marks in the views built so far (weak: views come and go).
static var nodes: Array = []
## The band of the P90's ring (WeaponView._view_ring): the line strength widens it.
static var ring_band: Gradient

## Takes the player's choice and shows it on every mark at once.
static func choose(new_color: Color, new_size: float, new_thick: float, new_glow: float) -> void:
	color = Color(new_color.r, new_color.g, new_color.b, 1.0)
	size = clampf(new_size, SIZE_RANGE.x, SIZE_RANGE.y)
	thick = clampf(new_thick, THICK_RANGE.x, THICK_RANGE.y)
	glow = clampf(new_glow, GLOW_RANGE.x, GLOW_RANGE.y)
	paint()
	var kept: Array = []
	for ref: WeakRef in nodes:
		var node := ref.get_ref() as Node3D
		if node != null:
			fit(node)
			kept.append(ref)
	nodes = kept

static func reset() -> void:
	choose(DEFAULT_COLOR, 1.0, 1.0, 1.0)

## A mark's quad at the size the player chose; the bright middle also grows with the line
## strength.
static func fit(node: Node3D) -> void:
	node.scale = Vector3.ONE * size * (thick if str(node.get_meta("reticle", "")) == "core" else 1.0)

## Notes the marks of a view just built and sets them to the player's size.
static func register(root: Node) -> void:
	paint()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("reticle"):
			nodes.append(weakref(node))
			fit(node as Node3D)

## The marks' materials in the player's colour: a bright middle and a faint halo in the
## reflex sight, the ring (a shade lighter) and its dot in the P90's. The copies the shop
## shows (WeaponView._plain) follow.
static func paint() -> void:
	var ring := color.lerp(Color.WHITE, 0.12)
	var tints := {
		"dot_bright": Color(color.r * 1.85 * glow, color.g * 1.85 * glow, color.b * 1.85 * glow, 1.0),
		"dot_halo": Color(color.r, color.g, color.b, 0.32 * glow),
		"ring_reticle": Color(ring.r * glow, ring.g * glow, ring.b * glow, 0.9),
		"ring_dot": Color(color.r * 1.6 * glow, color.g * 1.6 * glow, color.b * 1.6 * glow, 1.0)
	}
	for key: String in tints:
		if WeaponView.materials.has(key):
			var paint_of := WeaponView.materials[key] as BaseMaterial3D
			paint_of.albedo_color = tints[key]
			if WeaponView.plain_materials.has(paint_of):
				(WeaponView.plain_materials[paint_of] as BaseMaterial3D).albedo_color = tints[key]
	if ring_band != null:
		var half := 0.045 * thick
		ring_band.offsets = PackedFloat32Array([0.0, 0.895 - half, 0.895, minf(0.895 + half, 0.995), 1.0])

## The laser's dot and beam: the colour, a little brighter.
static func laser_color(strength: float = 1.0) -> Color:
	return Color(color.r * strength * glow, color.g * strength * glow, color.b * strength * glow, 1.0)

## What the settings file keeps.
static func save(game: Node) -> void:
	game.keep_setting("reticle", "color", color)
	game.keep_setting("reticle", "size", size)
	game.keep_setting("reticle", "thick", thick)
	game.keep_setting("reticle", "glow", glow)

static func load_from(settings: ConfigFile) -> void:
	choose(settings.get_value("reticle", "color", DEFAULT_COLOR), float(settings.get_value("reticle", "size", 1.0)), float(settings.get_value("reticle", "thick", 1.0)), float(settings.get_value("reticle", "glow", 1.0)))
