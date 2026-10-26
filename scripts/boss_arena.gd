class_name BossArena
extends Node3D
## The end of mission two: the reactor hall of the Umbra research level, nine floors under the
## containment hall. A round hall of 46 m under a ceiling of 24 m - wet dark steel that the
## red warning lamps shine in, a ring with a grating in its middle, a reactor that hangs
## over it on its cables, glass tanks with what Helix grew along the walls, an observation
## room behind armoured glass in the north wall (Nadja watches from there), steel gates
## with warning stripes in the east and the west (the infected come through them) and the
## gate in the south, at the end of the last corridor from the freight lift.
##
## Built into the map of the second mission like the simulation hall (HiveMap ->
## BossArena.build): around its own middle, the map told the offset. It also owns what the
## hall does in the fight (BossFight says when): laser grids that run across it, gas from
## the nozzles in the wall, the hatches of the floor that glow and then open over the lava,
## the shock waves, the acid of what the boss throws.
##
## Damage of all that is reckoned on every machine for the survivors that machine moves
## (its player; on the host also the squad's bots): a guest dodges what he sees.

## Where its middle is, on the floor. Far from everything else of the map.
const AT := Vector3(-300.0, -61.6, -800.0)
## The roof with the helicopter pad (the end of the outro), on the ground of the map, far off.
const ROOF := Vector3(-300.0, 0.0, -930.0)
const ZONE := "boss"
const RADIUS := 23.0
const CEILING := 24.0
const WALL_SEGMENTS := 48
## The cells of the floor (3 m), and the ones that are hatches over the lava.
const CELL := 3.0
const HATCHES := [
	Vector2(13.5, 4.5), Vector2(13.5, -4.5), Vector2(-13.5, 4.5), Vector2(-13.5, -4.5),
	Vector2(4.5, 13.5), Vector2(-4.5, 13.5), Vector2(4.5, -13.5), Vector2(-4.5, -13.5),
	Vector2(10.5, 10.5), Vector2(-10.5, 10.5), Vector2(10.5, -10.5), Vector2(-10.5, -10.5)
]
const PIT_DEPTH := 0.62
const LAVA_DPS := 42.0
## A laser grid: how fast it crosses, how much a touch takes, and how high its beams are.
const GRID_SPEED := 5.2
const GRID_HARM := 28.0
const GRID_LOW := 0.42
const GRID_HIGH := 1.32
## The gas: a quarter of the hall, so long; what it takes a second beyond the mask's job.
const GAS_HARM := 9.0
const ACID_DPS := 16.0
## The gate of the south and the window of the observation room.
const GATE_WIDTH := 4.4
const WINDOW := Vector4(-7.0, 7.0, 7.6, 11.2)
const OBS_FLOOR := 7.0
const RED := Color(1.0, 0.12, 0.08)
const STEEL := Color(0.6, 0.62, 0.66)
const DARK := Color(0.2, 0.22, 0.25)
const HAZARD := Color("e0b020")

var map: HiveMap
## The game (BossFight hands it over): for sounds, the HUD and the survivors.
var game: Node
var origin := AT
var level := 0
var roof_level := -1
## Named places of the hall, in the map's coordinates (BossFight and the director use them).
var places: Dictionary = {}
var lamps: Array[OmniLight3D] = []
var beacons: Array[Node3D] = []
var reactor: Node3D
var reactor_ring: Node3D
var reactor_core: StandardMaterial3D
var hatch_nodes: Array = []
## Each hatch: {cell, state ("shut", "warn", "open", "closing"), left, panels, glow, light, bodies}
var hatches: Array = []
var sweeps: Array = []
var gas_sectors: Array = []
var acids: Array = []
var waves: Array = []
var nozzles: Array = []
var gates: Dictionary = {}
var tank_glass: Node3D
var tank_fluid: MeshInstance3D
var tank_broken := false
var nadja_spot := Vector3.ZERO
var lava_material: ShaderMaterial
var beam_material: StandardMaterial3D
var gas_material: StandardMaterial3D
var clock := 0.0
var hurt_wait: Dictionary = {}

const LAVA_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float heat = 1.0;
void fragment() {
	vec2 p = UV * 6.0;
	float t = TIME * 0.35;
	float a = sin(p.x * 1.7 + t * 2.0) * cos(p.y * 1.3 - t * 1.4);
	float b = sin((p.x + p.y) * 2.3 - t * 3.0) * 0.5;
	float c = sin(length(p - vec2(3.0)) * 3.1 - t * 4.0) * 0.35;
	float v = clamp(0.5 + 0.5 * (a + b + c) * 0.7, 0.0, 1.0);
	vec3 crust = vec3(0.18, 0.03, 0.01);
	vec3 hot = vec3(1.0, 0.36, 0.04);
	vec3 white = vec3(1.0, 0.85, 0.4);
	vec3 col = mix(crust, hot, smoothstep(0.25, 0.65, v));
	col = mix(col, white, smoothstep(0.82, 0.98, v));
	ALBEDO = col * (1.2 + heat * 2.2);
}
"""

static func build(into: HiveMap, at_level: int, roof_at: int = -1) -> BossArena:
	var hall := BossArena.new()
	hall.name = "BossArena"
	hall.map = into
	hall.level = at_level
	hall.roof_level = roof_at
	# (Its own nodes - lamps, hatches, traps - stand in its frame: the middle of the hall.)
	hall.position = AT
	into.add_child(hall)
	hall._build()
	return hall

## The plan the hall and its corridor need on their floor.
static func plan() -> Rect2:
	return Rect2(AT.x - 26.0, AT.z - 32.0, 52.0, 94.0)

static func roof_plan() -> Rect2:
	return Rect2(ROOF.x - 20.0, ROOF.z - 20.0, 40.0, 40.0)

func _w(local: Vector3) -> Vector3:
	return origin + local

func _build() -> void:
	_materials()
	var kept_zone := map.zone
	var kept_area := map.area
	# The corridor from the lift: three rooms of the map's own kind, built by the map in its
	# coordinates (a zone of their own, whose node stays where the map is).
	map._begin_zone("boss_gang", "cold")
	map._room("boss_lift", level, Rect2(origin.x - 2.5, origin.z + 44.0, 5.0, 15.0), 4.0, "tech", {"look": {"stripe": HAZARD}})
	map._room("boss_vorraum", level, Rect2(origin.x - 8.0, origin.z + 31.0, 16.0, 13.0), 4.6, "panel", {"look": {"stripe": HAZARD}})
	map._room("boss_gang", level, Rect2(origin.x - 2.5, origin.z + RADIUS + 0.2, 5.0, 31.0 - RADIUS - 0.2), 5.0, "tech", {"look": {"stripe": Color("b02020")}})
	map._door("boss_lift", "boss_vorraum", origin.x, 2.4, {"kind": "frame", "height": 2.6})
	map._door("boss_vorraum", "boss_gang", origin.x, 3.0, {"kind": "frame", "height": 3.2})
	map._end_zone()
	map._begin_zone(ZONE, "cold")
	(map.zones[ZONE].node as Node3D).position = origin
	map.area = ""
	map.nav_shift = origin
	map._own_dice(70707)
	# The hall is one open room (everything in it is built here); the corridor from the lift
	# is three rooms of the map's own kind.
	var walk: Array = []
	for band in range(-7, 8):
		var z := band * 3.0
		var half := sqrt(maxf(0.0, (RADIUS - 1.2) * (RADIUS - 1.2) - (absf(z) + 1.5) * (absf(z) + 1.5)))
		if half > 1.0:
			walk.append(Rect2(origin.x - half, origin.z + z - 1.5, half * 2.0, 3.0))
	map._room("boss_arena", level, Rect2(origin.x - RADIUS - 0.2, origin.z - RADIUS - 0.2, (RADIUS + 0.2) * 2.0, (RADIUS + 0.2) * 2.0), CEILING, "none", {"outdoor": true, "walk": walk, "seed": Vector2(origin.x, origin.z)})
	map._door("boss_gang", "boss_arena", origin.x, 3.6, {"kind": "script", "name": "boss_gate", "height": 4.6})
	map._chunk("Boss")
	_floor()
	_walls()
	_ceiling()
	_observation()
	_gates()
	_reactor()
	_tank()
	_side_tanks()
	_dress()
	_corridor()
	_details()
	_lights()
	map.nav_shift = Vector3.ZERO
	map._end_zone()
	if roof_level >= 0:
		_roof()
	map.zone = kept_zone
	map.area = kept_area
	places = {
		"boss_start": _w(Vector3(0, 0, 56.0)), "boss_locker": _w(Vector3(5.6, 0, 37.5)), "boss_door": _w(Vector3(0, 0, 25.5)),
		"boss_gate": _w(Vector3(0, 0, 23.0)), "boss_middle": _w(Vector3(0, 0, 0)), "boss_tank": _w(Vector3(0, 0, -14.5)),
		"boss_nadja": nadja_spot, "boss_east": _w(Vector3(21.0, 0, 0)), "boss_west": _w(Vector3(-21.0, 0, 0)),
		"boss_roof": ROOF + Vector3(0, 0.02, 0), "boss_vorraum": _w(Vector3(0, 0, 37.5))
	}

## A round, soft puff for steam and gas (no square edges).
static var puff_texture: GradientTexture2D

static func soft_puff() -> GradientTexture2D:
	if puff_texture == null:
		puff_texture = GradientTexture2D.new()
		puff_texture.fill = GradientTexture2D.FILL_RADIAL
		puff_texture.fill_from = Vector2(0.5, 0.5)
		puff_texture.fill_to = Vector2(1.0, 0.5)
		puff_texture.width = 64
		puff_texture.height = 64
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		puff_texture.gradient = ramp
	return puff_texture

func _materials() -> void:
	lava_material = ShaderMaterial.new()
	lava_material.shader = Shader.new()
	lava_material.shader.code = LAVA_SHADER
	beam_material = StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(1.0, 0.1, 0.06)
	beam_material.emission_enabled = true
	beam_material.emission = Color(1.0, 0.1, 0.06)
	beam_material.emission_energy_multiplier = 8.0
	gas_material = StandardMaterial3D.new()
	gas_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gas_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gas_material.albedo_color = Color(0.55, 0.95, 0.25, 0.16)
	gas_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	gas_material.vertex_color_use_as_albedo = true
	gas_material.proximity_fade_enabled = true
	gas_material.proximity_fade_distance = 1.2
	gas_material.albedo_texture = soft_puff()

# ---------------------------------------------------------------- the floor

func _is_hatch(cell: Vector2) -> bool:
	for h: Vector2 in HATCHES:
		if h.distance_to(cell) < 0.1:
			return true
	return false

func _floor() -> void:
	var steps := int(round(RADIUS * 2.0 / CELL)) + 2
	var first := -CELL * (steps / 2) + CELL * 0.5
	for ix in range(steps):
		for iz in range(steps):
			var cell := Vector2(first + ix * CELL, first + iz * CELL)
			if cell.length() > RADIUS + 1.5 or _is_hatch(cell):
				continue
			var r := cell.length()
			var tint := Color(0.46, 0.48, 0.52) if (ix + iz) % 2 == 0 else Color(0.42, 0.44, 0.48)
			var mat := "gloss"
			if r < 7.0:
				# The grating of the ring in the middle.
				mat = "tread"
				tint = Color(0.5, 0.52, 0.55)
			map._part(mat, Vector3(cell.x, -0.15, cell.y), Vector3(CELL, 0.3, CELL), tint)
			map._firm_solid(Vector3(cell.x, -0.25, cell.y), Vector3(CELL, 0.5, CELL), false)
	# Seams between the plates, a ring of light around the grating and its warning band.
	for i in range(64):
		var a := TAU * i / 64.0
		var b := TAU * (i + 1) / 64.0
		for ring: Array in [[7.0, 0.16, RED, 4.5], [7.55, 0.42, HAZARD, 0.0], [16.8, 0.12, Color(0.9, 0.3, 0.2), 2.5]]:
			var rad := float(ring[0])
			var p := Vector2(cos((a + b) * 0.5), sin((a + b) * 0.5)) * rad
			var length := 2.0 * rad * sin((b - a) * 0.5) + 0.03
			var basis := Basis(Vector3.UP, -(a + b) * 0.5 + PI * 0.5)
			if float(ring[3]) > 0.0:
				map._glow_box(Vector3(p.x, 0.012, p.y), Vector3(length, 0.02, float(ring[1])), ring[2], float(ring[3]), basis)
			else:
				var stripe: Color = HAZARD if i % 2 == 0 else Color("141414")
				map.batch.box(map.mats["plain"], Vector3(p.x, 0.008, p.y), Vector3(length, 0.016, float(ring[1])), stripe, basis)
	# The grating's rings and spokes.
	for i in range(12):
		var a := TAU * i / 12.0
		map.batch.box(map.mats["plate"], Vector3(cos(a) * 3.5, 0.02, sin(a) * 3.5), Vector3(7.0, 0.04, 0.18), Color(0.18, 0.19, 0.21), Basis(Vector3.UP, -a))
	map.batch.cylinder(map.mats["plate"], Vector3(0, 0.0, 0), 1.6, 1.6, 0.06, Color(0.2, 0.21, 0.23), 32)
	map._glow_box(Vector3(0, 0.07, 0), Vector3(1.2, 0.02, 1.2), RED, 3.0)
	map._floor_text("SUBJEKT  0", Vector3(0, 0.0, 5.4), 120, Color(0.75, 0.12, 0.1), 0.0)
	# The pits under the hatches: walls, a floor to stand on and the lava.
	for cell: Vector2 in HATCHES:
		_hatch(cell)

func _hatch(cell: Vector2) -> void:
	var c := Vector3(cell.x, 0, cell.y)
	var half := CELL * 0.5
	# The pit: four walls and a floor under the lava's skin (collision as well).
	for side in range(4):
		var along_x := side % 2 == 0
		var off := Vector3(0, -PIT_DEPTH * 0.5, half * (1 if side == 0 else -1)) if along_x else Vector3(half * (1 if side == 1 else -1), -PIT_DEPTH * 0.5, 0)
		var size := Vector3(CELL, PIT_DEPTH, 0.2) if along_x else Vector3(0.2, PIT_DEPTH, CELL)
		map._part("beton", c + off, size, Color(0.24, 0.16, 0.12))
		map._firm_solid(c + off, size, false)
	map._firm_solid(c + Vector3(0, -PIT_DEPTH - 0.2, 0), Vector3(CELL, 0.4, CELL), false)
	var lava := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CELL - 0.2, CELL - 0.2)
	lava.mesh = plane
	lava.material_override = lava_material
	lava.position = c + Vector3(0, -PIT_DEPTH + 0.12, 0)
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lava)
	# The two leaves of the hatch slide apart; under them lies the lava.
	var panels: Array = []
	var bodies: Array = []
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.28, 0.29, 0.31)
	glow.metallic = 0.7
	glow.roughness = 0.35
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.35, 0.05)
	glow.emission_energy_multiplier = 0.0
	for way in [-1.0, 1.0]:
		var leaf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(CELL * 0.5 - 0.02, 0.16, CELL - 0.04)
		leaf.mesh = box
		leaf.material_override = glow
		leaf.position = c + Vector3(way * CELL * 0.25, -0.08, 0)
		add_child(leaf)
		# Warning chevrons on it.
		var stripe := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.18, 0.02, CELL - 0.3)
		stripe.mesh = strip
		var paint := StandardMaterial3D.new()
		paint.albedo_color = HAZARD
		stripe.material_override = paint
		stripe.position = Vector3(-way * (CELL * 0.25 - 0.2), 0.085, 0)
		leaf.add_child(stripe)
		panels.append(leaf)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = Vector3(CELL * 0.5, 0.3, CELL)
		shape.shape = cube
		body.add_child(shape)
		body.position = origin + c + Vector3(way * CELL * 0.25, -0.15, 0)
		map.body.add_child.call_deferred(body)
		bodies.append(shape)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.42, 0.1)
	light.light_energy = 0.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = c + Vector3(0, 0.6, 0)
	add_child(light)
	hatches.append({"cell": cell, "state": "shut", "left": 0.0, "panels": panels, "glow": glow, "light": light, "shapes": bodies, "open": 0.0})

# ---------------------------------------------------------------- the walls

## The angle of the wall that stands at local (x, z); 0 = east, PI/2 = south.
static func _angle(x: float, z: float) -> float:
	return atan2(z, x)

func _walls() -> void:
	var r := RADIUS + 0.3
	for i in range(WALL_SEGMENTS):
		var a := TAU * (i + 0.5) / WALL_SEGMENTS
		var dir := Vector2(cos(a), sin(a))
		var p := dir * r
		var width := 2.0 * r * sin(PI / WALL_SEGMENTS) + 0.08
		var basis := Basis(Vector3.UP, -a + PI * 0.5)
		var south_gate := absf(p.x) < GATE_WIDTH * 0.5 + 0.9 and p.y > 0.0
		var side_gate := absf(p.y) < 3.2 and absf(p.x) > 10.0
		var window := absf(p.x) < WINDOW.y + 0.6 and p.y < 0.0
		var spans: Array = [[0.0, CEILING]]
		if south_gate:
			spans = [[5.0, CEILING]]
		elif side_gate:
			spans = [[5.6, CEILING]]
		elif window:
			spans = [[0.0, WINDOW.z], [WINDOW.w, 12.6], [15.4, CEILING]]
		for span: Array in spans:
			var y0 := float(span[0])
			var y1 := float(span[1])
			# The lower row is darker and painted; above it the panels of the hall.
			if y0 < 0.5:
				map.batch.box(map.mats["plate"], Vector3(p.x, 1.4, p.y), Vector3(width, 2.8, 0.6), Color(0.38, 0.39, 0.42), basis)
				map.batch.box(map.mats["plain"], Vector3(p.x, 2.86, p.y) - Vector3(dir.x, 0, dir.y) * 0.31, Vector3(width, 0.12, 0.02), Color(0.7, 0.1, 0.08), basis)
				y0 = 2.8
			if y1 > y0:
				var shade := STEEL if i % 2 == 0 else STEEL.darkened(0.08)
				map.batch.box(map.mats["shutter"], Vector3(p.x, (y0 + y1) * 0.5, p.y), Vector3(width, y1 - y0, 0.5), shade, basis)
		if not south_gate:
			map._solid(Vector3(p.x, 3.0, p.y), Vector3(width, 6.0, 0.6), true, -a + PI * 0.5)
		# Ribs between the panels, every second one with a red warning lamp.
		var rib := Vector2(cos(TAU * i / WALL_SEGMENTS), sin(TAU * i / WALL_SEGMENTS)) * (RADIUS - 0.05)
		var rib_basis := Basis(Vector3.UP, -TAU * i / WALL_SEGMENTS + PI * 0.5)
		var in_gap := (absf(rib.x) < GATE_WIDTH * 0.5 + 0.6 and rib.y > 0.0) or (absf(rib.y) < 3.0 and absf(rib.x) > 10.0) or (absf(rib.x) < WINDOW.y + 0.4 and rib.y < 0.0)
		if not in_gap:
			map.batch.box(map.mats["plate"], Vector3(rib.x, CEILING * 0.5, rib.y), Vector3(0.36, CEILING, 0.5), DARK, rib_basis)
			if i % 4 == 0:
				var lamp_at := Vector3(rib.x, 4.6, rib.y) - Vector3(cos(TAU * i / WALL_SEGMENTS), 0, sin(TAU * i / WALL_SEGMENTS)) * 0.35
				map._glow_box(lamp_at, Vector3(0.22, 0.34, 0.22), RED, 7.0)
				lamps.append(map._light(lamp_at - Vector3(cos(TAU * i / WALL_SEGMENTS), 0, sin(TAU * i / WALL_SEGMENTS)) * 0.4, RED, 2.4, 11.0, false, 0.0, 0.6, 140.0))
	# The catwalk round the hall at the height of the observation window, its railing,
	# and a second ring of pipes above it.
	for i in range(WALL_SEGMENTS):
		var a := TAU * (i + 0.5) / WALL_SEGMENTS
		var dir := Vector2(cos(a), sin(a))
		var basis := Basis(Vector3.UP, -a + PI * 0.5)
		var walk_r := RADIUS - 1.0
		var p := dir * walk_r
		var width := 2.0 * walk_r * sin(PI / WALL_SEGMENTS) + 0.06
		if absf(p.x) < WINDOW.y + 0.5 and p.y < 0.0:
			continue
		# (The two containment columns stand where the catwalk would run.)
		var deg := fposmod(rad_to_deg(a), 360.0)
		if absf(deg - 208.0) < 8.0 or absf(deg - 332.0) < 8.0:
			continue
		map.batch.box(map.mats["tread"], Vector3(p.x, 6.4, p.y), Vector3(width, 0.12, 1.8), Color(0.42, 0.44, 0.46), basis)
		var rail := dir * (RADIUS - 1.85)
		map.batch.box(map.mats["plate"], Vector3(rail.x, 7.45, rail.y), Vector3(width, 0.06, 0.06), HAZARD, basis)
		map.batch.box(map.mats["plate"], Vector3(rail.x, 6.95, rail.y), Vector3(width, 0.04, 0.04), Color(0.3, 0.31, 0.33), basis)
		if i % 2 == 0:
			map.batch.box(map.mats["plate"], Vector3(rail.x, 6.95, rail.y), Vector3(0.05, 1.0, 0.05), Color(0.3, 0.31, 0.33), basis)
		for pipe: Array in [[RADIUS - 0.45, 9.4, 0.22, Color(0.36, 0.4, 0.42)], [RADIUS - 0.42, 9.95, 0.15, Color(0.55, 0.2, 0.15)], [RADIUS - 0.45, 3.6, 0.16, Color(0.4, 0.42, 0.38)]]:
			var pr := dir * float(pipe[0])
			if float(pipe[1]) < 5.0 and ((absf(pr.x) < GATE_WIDTH * 0.5 + 0.8 and pr.y > 0.0) or (absf(pr.y) < 3.4 and absf(pr.x) > 10.0)):
				continue
			if float(pipe[1]) > 9.0 and absf(pr.x) < WINDOW.y + 0.6 and pr.y < 0.0:
				continue
			map.batch.cylinder(map.mats["steel"], Vector3(pr.x, float(pipe[1]), pr.y) - Vector3(-dir.y, 0, dir.x) * width * 0.5, float(pipe[2]), float(pipe[2]), width + 0.02, pipe[3], 10, Basis(Quaternion(Vector3.UP, Vector3(-dir.y, 0, dir.x))))

func _ceiling() -> void:
	map._part("plate", Vector3(0, CEILING + 0.25, 0), Vector3(RADIUS * 2.0 + 2.0, 0.5, RADIUS * 2.0 + 2.0), Color(0.16, 0.17, 0.19))
	map._part_shape(Vector3(0, CEILING + 0.25, 0), Vector3(RADIUS * 2.0 + 2.0, 0.5, RADIUS * 2.0 + 2.0))
	# Girders like the spokes of a wheel, and a ring of lamps between them.
	for i in range(8):
		var a := TAU * i / 8.0
		map.batch.box(map.mats["plate"], Vector3(cos(a) * RADIUS * 0.5, CEILING - 0.5, sin(a) * RADIUS * 0.5), Vector3(RADIUS, 1.0, 0.5), DARK, Basis(Vector3.UP, -a))
		var lamp := Vector3(cos(a + PI / 8.0) * 12.0, CEILING - 0.3, sin(a + PI / 8.0) * 12.0)
		map._glow_box(lamp, Vector3(1.4, 0.15, 1.4), Color(0.95, 0.97, 1.0), 7.0)

# ---------------------------------------------------------------- the observation room

func _observation() -> void:
	var z := -RADIUS - 0.3
	var deep := 6.5
	var y := OBS_FLOOR
	# Its floor, walls, ceiling: a lit box behind the glass.
	map._part("tread", Vector3(0, y - 0.2, z - deep * 0.5), Vector3(16.0, 0.4, deep), Color(0.42, 0.44, 0.46))
	map._part("shutter", Vector3(0, y + 2.5, z - deep - 0.2), Vector3(16.0, 5.4, 0.4), Color(0.66, 0.68, 0.7))
	for x: float in [-8.2, 8.2]:
		map._part("shutter", Vector3(x, y + 2.5, z - deep * 0.5), Vector3(0.4, 5.4, deep), Color(0.6, 0.62, 0.64))
	map._part("plate", Vector3(0, y + 5.0, z - deep * 0.5), Vector3(16.0, 0.3, deep), Color(0.3, 0.31, 0.33))
	# The armoured glass in a heavy frame, and a second, dark storey above it.
	map.batch.box(map.mats["glass"], Vector3(0, (WINDOW.z + WINDOW.w) * 0.5, z + 0.05), Vector3(WINDOW.y - WINDOW.x, WINDOW.w - WINDOW.z, 0.12), Color.WHITE)
	map._solid(Vector3(0, (WINDOW.z + WINDOW.w) * 0.5, z + 0.05), Vector3(WINDOW.y - WINDOW.x, WINDOW.w - WINDOW.z, 0.3), false)
	for x in range(-6, 7, 3):
		map._part("plate", Vector3(x, (WINDOW.z + WINDOW.w) * 0.5, z + 0.18), Vector3(0.22, WINDOW.w - WINDOW.z, 0.22), DARK)
	map._part("plate", Vector3(0, WINDOW.z - 0.15, z + 0.25), Vector3(WINDOW.y - WINDOW.x + 0.8, 0.4, 0.6), DARK)
	map._part("plate", Vector3(0, WINDOW.w + 0.15, z + 0.25), Vector3(WINDOW.y - WINDOW.x + 0.8, 0.4, 0.6), DARK)
	map.batch.box(map.mats["glass"], Vector3(0, 14.0, z + 0.05), Vector3(WINDOW.y - WINDOW.x, 2.8, 0.12), Color(0.6, 0.65, 0.7))
	map._part("plate", Vector3(0, 14.0, z - 1.0), Vector3(WINDOW.y - WINDOW.x, 2.8, 0.2), Color(0.08, 0.09, 0.1))
	for line: Array in [["OBSERVATION  A-1", WINDOW.w + 0.62, 64], ["OBSERVATION  A-2", 15.85, 52]]:
		map._wall_sign(str(line[0]), Vector3(0, float(line[1]), z + 0.42), int(line[2]), Color(0.92, 0.94, 0.96), 0.0)
	# Desks with screens under the window, a chair, the light.
	map._part("plate", Vector3(0, y + 0.45, z - 1.3), Vector3(11.0, 0.9, 0.9), Color(0.24, 0.25, 0.27))
	for x in [-4.5, -1.5, 1.5, 4.5]:
		map._screen(Transform3D(Basis(Vector3.UP, PI), Vector3(x, y, z - 1.6)), Vector3(0, 1.25, 0), Vector2(1.1, 0.65), [1, 3, 5, 7][int(x + 4.5) % 4], -1.0, 10.0)
	for x in [-6.0, -2.0, 2.0, 6.0]:
		map._glow_box(Vector3(x, y + 4.82, z - deep * 0.5), Vector3(2.2, 0.06, 0.4), Color(1.0, 0.97, 0.92), 6.0)
	map._light(Vector3(-3.5, y + 3.6, z - 2.4), Color(1.0, 0.95, 0.88), 5.0, 10.0, false, 0.0, 0.4, 140.0)
	map._light(Vector3(3.5, y + 3.6, z - 2.4), Color(1.0, 0.95, 0.88), 5.0, 10.0, false, 0.0, 0.4, 140.0)
	nadja_spot = _w(Vector3(0.6, y, z - 2.4))
	map.points["boss_nadja"] = nadja_spot

# ---------------------------------------------------------------- the gates

func _gates() -> void:
	# The south gate: the map's own door (BossFight opens it); here only its frame and stripes.
	var z := RADIUS + 0.2
	var half := GATE_WIDTH * 0.5
	for x: float in [-half - 0.45, half + 0.45]:
		map._part("plate", Vector3(x, 2.6, z - 0.2), Vector3(0.9, 5.2, 0.9), DARK)
		map._hazard(Vector3(x, 0.3, z - 0.66), Vector3(x, 4.9, z - 0.66), Vector3(0.92, 0.38, 0.02), 12)
	map._part("plate", Vector3(0, 5.3, z - 0.2), Vector3(GATE_WIDTH + 1.8, 0.6, 0.9), DARK)
	map._hazard(Vector3(-half - 0.9, 5.3, z - 0.66), Vector3(half + 0.9, 5.3, z - 0.66), Vector3(0.5, 0.5, 0.02), 12)
	map._wall_sign("SCHLEUSE  U9", Vector3(0, 6.2, z - 0.7), 64, HAZARD, PI)
	# East and west: big shutters the infected come through.
	for way: float in [1.0, -1.0]:
		var x := way * (RADIUS - 0.1)
		var basis := Basis(Vector3.UP, PI * 0.5 * way)
		for zz: float in [-3.3, 3.3]:
			map._part("plate", Vector3(x, 2.9, zz), Vector3(0.9, 5.8, 0.9), DARK)
			map._hazard(Vector3(x - way * 0.46, 0.3, zz), Vector3(x - way * 0.46, 5.4, zz), Vector3(0.02, 0.42, 0.92), 12)
		map._part("plate", Vector3(x, 5.9, 0), Vector3(0.9, 0.7, 7.5), DARK)
		map._hazard(Vector3(x - way * 0.46, 5.9, -3.4), Vector3(x - way * 0.46, 5.9, 3.4), Vector3(0.02, 0.55, 0.55), 12)
		# Behind the shutter: a dark passage.
		map._part("plate", Vector3(x + way * 3.0, 2.8, 0), Vector3(5.0, 5.6, 6.0), Color(0.05, 0.05, 0.06))
		var shutter := Node3D.new()
		shutter.position = Vector3(x, 0, 0)
		add_child(shutter)
		var leaf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 5.6, 5.8)
		leaf.mesh = box
		var steel := StandardMaterial3D.new()
		steel.albedo_texture = (map.mats["shutter"] as StandardMaterial3D).albedo_texture
		steel.normal_enabled = true
		steel.normal_texture = (map.mats["shutter"] as StandardMaterial3D).normal_texture
		steel.uv1_triplanar = true
		steel.uv1_scale = Vector3.ONE * 0.5
		steel.albedo_color = Color(0.5, 0.52, 0.54)
		steel.metallic = 0.5
		steel.roughness = 0.45
		leaf.material_override = steel
		leaf.position = Vector3(0, 2.8, 0)
		shutter.add_child(leaf)
		for k in range(6):
			var stripe := MeshInstance3D.new()
			var s := BoxMesh.new()
			s.size = Vector3(0.32, 0.4, 5.8)
			stripe.mesh = s
			var paint := StandardMaterial3D.new()
			paint.albedo_color = HAZARD if k % 2 == 0 else Color("161616")
			stripe.material_override = paint
			stripe.position = Vector3(0, 0.3 + k * 0.4, 0)
			leaf.add_child(stripe)
		var beacon := _beacon(Vector3(x - way * 0.6, 6.5, 0))
		gates["east" if way > 0.0 else "west"] = {"node": leaf, "open": 0.0, "want": 0.0, "beacon": beacon}
		map._solid(Vector3(x, 2.8, 0), Vector3(0.6, 5.6, 6.0), false)

func _beacon(at: Vector3) -> Node3D:
	map._glow_box(at, Vector3(0.3, 0.3, 0.3), Color(1.0, 0.45, 0.1), 6.0)
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.4, 0.1)
	beam.light_energy = 0.0
	beam.spot_range = 14.0
	beam.spot_angle = 22.0
	beam.shadow_enabled = false
	beam.rotation_degrees = Vector3(-20, 0, 0)
	pivot.add_child(beam)
	beacons.append(pivot)
	return pivot

# ---------------------------------------------------------------- the reactor

func _reactor() -> void:
	reactor = Node3D.new()
	reactor.name = "Reactor"
	reactor.position = Vector3(0, 0, 0)
	add_child(reactor)
	var y0 := 13.5
	var y1 := 21.0
	map.batch.cylinder(map.mats["plate"], Vector3(0, y0, 0), 3.4, 3.4, y1 - y0, Color(0.3, 0.31, 0.34), 24)
	map.batch.cylinder(map.mats["plate"], Vector3(0, y0 - 1.6, 0), 1.6, 3.2, 1.6, Color(0.24, 0.25, 0.27), 24)
	map.batch.cylinder(map.mats["plate"], Vector3(0, y1, 0), 3.4, 2.0, 1.2, Color(0.24, 0.25, 0.27), 24)
	map.batch.cylinder(map.mats["plate"], Vector3(0, y1 + 1.2, 0), 1.2, 1.2, CEILING - y1 - 1.2, Color(0.2, 0.21, 0.23), 16)
	# Bands of red light round it, and the core seen through slots.
	for band: float in [y0 + 0.6, y0 + 3.6, y1 - 0.8]:
		map.batch.cylinder(map.mats["steady"], Vector3(0, band, 0), 3.46, 3.46, 0.22, Color(0.9, 0.08, 0.05), 24)
	reactor_core = StandardMaterial3D.new()
	reactor_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reactor_core.albedo_color = Color(1.0, 0.25, 0.08)
	for i in range(8):
		var a := TAU * i / 8.0
		var slot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 2.0, 0.1)
		slot.mesh = box
		slot.material_override = reactor_core
		slot.position = Vector3(cos(a) * 3.42, y0 + 2.1, sin(a) * 3.42)
		slot.rotation.y = -a + PI * 0.5
		reactor.add_child(slot)
	# The ring that turns slowly round its belly, with lamps on it.
	reactor_ring = Node3D.new()
	reactor_ring.position = Vector3(0, y0 + 5.2, 0)
	reactor.add_child(reactor_ring)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.6
	torus.outer_radius = 4.1
	torus.rings = 48
	ring.mesh = torus
	var ring_steel := StandardMaterial3D.new()
	ring_steel.albedo_color = Color(0.35, 0.36, 0.38)
	ring_steel.metallic = 0.8
	ring_steel.roughness = 0.35
	ring.material_override = ring_steel
	reactor_ring.add_child(ring)
	for i in range(6):
		var a := TAU * i / 6.0
		var bulb := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		bulb.mesh = ball
		bulb.material_override = beam_material
		bulb.position = Vector3(cos(a) * 3.85, -0.25, sin(a) * 3.85)
		reactor_ring.add_child(bulb)
	# Cables: from the reactor out to the wall and up to the ceiling, sagging.
	for i in range(10):
		var a := TAU * i / 10.0 + 0.2
		var from := Vector3(cos(a) * 3.3, y1 - 1.0 - (i % 3) * 1.6, sin(a) * 3.3)
		var to := Vector3(cos(a) * (RADIUS - 0.6), 15.0 + (i % 4) * 1.6, sin(a) * (RADIUS - 0.6))
		map._hose(from, to, 0.11 + (i % 2) * 0.05, Color(0.1, 0.1, 0.11), 3.5 + (i % 3), Vector3.ZERO, 10, "plain")
	for i in range(6):
		var a := TAU * i / 6.0
		map._hose(Vector3(cos(a) * 2.6, y1 + 0.8, sin(a) * 2.6), Vector3(cos(a) * 6.0, CEILING, sin(a) * 6.0), 0.09, Color(0.16, 0.06, 0.05), 0.8, Vector3.ZERO, 6, "plain")
	# Chains holding it.
	for i in range(4):
		var a := TAU * i / 4.0 + PI / 4.0
		map._pipe(Vector3(cos(a) * 3.0, y1 + 0.6, sin(a) * 3.0), Vector3(cos(a) * 8.0, CEILING, sin(a) * 8.0), 0.07, Color(0.35, 0.36, 0.38), 6, "steel")
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.1)
	glow.light_energy = 3.0
	glow.omni_range = 14.0
	glow.shadow_enabled = false
	glow.position = Vector3(0, y0 - 1.0, 0)
	reactor.add_child(glow)
	lamps.append(glow)

# ---------------------------------------------------------------- the tank of the boss

func _tank() -> void:
	var c := Vector3(0, 0, -14.5)
	map.batch.cylinder(map.mats["plate"], c, 3.0, 3.2, 0.5, Color(0.22, 0.23, 0.25), 32)
	map.batch.cylinder(map.mats["steady"], c + Vector3(0, 0.5, 0), 2.9, 2.9, 0.06, Color(0.2, 0.9, 0.6), 32)
	map.batch.cylinder(map.mats["plate"], c + Vector3(0, 6.6, 0), 3.0, 2.6, 0.8, Color(0.22, 0.23, 0.25), 32)
	map.batch.cylinder(map.mats["plate"], c + Vector3(0, 7.4, 0), 1.0, 1.0, CEILING - 7.4, Color(0.2, 0.21, 0.23), 12)
	for i in range(6):
		var a := TAU * i / 6.0
		map._hose(c + Vector3(cos(a) * 2.4, 7.2, sin(a) * 2.4), c + Vector3(cos(a) * 5.0, CEILING, sin(a) * 5.0 - 2.0), 0.08, Color(0.1, 0.12, 0.11), 0.6, Vector3.ZERO, 6, "plain")
	map._part("plate", c + Vector3(0, 0.6, -3.2), Vector3(2.2, 1.2, 0.8), DARK)
	map._glow_box(c + Vector3(0, 1.05, -2.78), Vector3(1.6, 0.4, 0.04), Color(0.3, 1.0, 0.6), 3.0)
	map._wall_sign("SUBJEKT  NULL  ·  PROJEKT  UMBRA", c + Vector3(0, 7.4, 2.75), 40, Color(0.85, 0.9, 0.9), PI)
	tank_glass = Node3D.new()
	tank_glass.position = c
	add_child(tank_glass)
	var glass := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 2.6
	tube.bottom_radius = 2.6
	tube.height = 6.1
	tube.radial_segments = 40
	tube.cap_top = false
	tube.cap_bottom = false
	glass.mesh = tube
	glass.material_override = map.mats["glass"]
	glass.position.y = 3.55
	tank_glass.add_child(glass)
	tank_fluid = MeshInstance3D.new()
	var fluid := CylinderMesh.new()
	fluid.top_radius = 2.55
	fluid.bottom_radius = 2.55
	fluid.height = 5.6
	fluid.radial_segments = 32
	tank_fluid.mesh = fluid
	var water := StandardMaterial3D.new()
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color = Color(0.25, 0.85, 0.6, 0.22)
	water.emission_enabled = true
	water.emission = Color(0.1, 0.5, 0.32)
	water.emission_energy_multiplier = 0.6
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	tank_fluid.material_override = water
	tank_fluid.position.y = 3.35
	tank_glass.add_child(tank_fluid)
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.65)
	light.light_energy = 2.2
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = Vector3(0, 2.0, 2.4)
	tank_glass.add_child(light)
	map._solid(c + Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 1.0), false)

## The glass bursts: shards, fluid on the floor, a bang.
func break_tank() -> void:
	if tank_broken:
		return
	tank_broken = true
	var c := _w(Vector3(0, 0, -14.5))
	if is_instance_valid(tank_glass):
		for child in tank_glass.get_children():
			if child is MeshInstance3D:
				child.hide()
	if game != null:
		for i in range(14):
			var a := TAU * i / 14.0
			game.fx.dust(c + Vector3(cos(a) * 2.6, randf_range(0.6, 5.5), sin(a) * 2.6), Vector3(cos(a), 0.3, sin(a)))
		game.sounds.play_at("glass_break" if game.sounds.has_method("has_sound") and game.sounds.has_sound("glass_break") else "explosion", c + Vector3(0, 2.0, 0), 4.0, 0.7)
	# Shards stand round the foot, the fluid lies on the floor.
	var shard_mat: Material = map.mats["glass"]
	for i in range(22):
		var a := randf() * TAU
		var shard := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(randf_range(0.2, 0.6), randf_range(0.3, 1.4), 0.04)
		shard.mesh = prism
		shard.material_override = shard_mat
		shard.position = Vector3(cos(a) * randf_range(2.4, 4.8), 0.2, -14.5 + sin(a) * randf_range(2.4, 4.8))
		shard.rotation = Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-0.6, 0.6))
		add_child(shard)
	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 5.2
	disc.bottom_radius = 5.2
	disc.height = 0.01
	puddle.mesh = disc
	var wet := StandardMaterial3D.new()
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color = Color(0.2, 0.7, 0.45, 0.35)
	wet.roughness = 0.05
	wet.metallic = 0.3
	puddle.material_override = wet
	puddle.position = Vector3(0, 0.012, -13.5)
	add_child(puddle)

## Lab tanks with what Helix grew, round the walls (the map's own kind, see CabinMap._tank).
func _side_tanks() -> void:
	var kinds := ["leech", "striker", "normalzombie", "stalker", "striker", "normalzombie", "leech", "stalker"]
	var poses := ["curled", "adrift", "reaching", "adrift", "curled", "reaching", "adrift", "curled"]
	var angles := [deg_to_rad(28.0), deg_to_rad(52.0), deg_to_rad(128.0), deg_to_rad(152.0), deg_to_rad(232.0), deg_to_rad(308.0)]
	for i in range(angles.size()):
		var a: float = angles[i]
		var at := Vector3(cos(a) * (RADIUS - 2.6), 0, sin(a) * (RADIUS - 2.6))
		map._chunk("Boss")
		map._tank(at, "U-%02d" % (i + 1), kinds[i], poses[i], rad_to_deg(-a) + 90.0, 0.6, i % 2 == 0, 0.15)
		map._chunk("Boss")
		map._solid(at + Vector3(0, 1.5, 0), Vector3(1.5, 3.0, 1.5), true)
		map._hose(at + Vector3(0, 3.0, 0), Vector3(cos(a) * (RADIUS - 0.4), 6.0, sin(a) * (RADIUS - 0.4)), 0.07, Color(0.12, 0.14, 0.13), 0.5, Vector3.ZERO, 6, "plain")

# ---------------------------------------------------------------- dressing

func _dress() -> void:
	# Consoles along the wall either side of the gates, with screens.
	for spot: Array in [[deg_to_rad(75.0), 0], [deg_to_rad(105.0), 1], [deg_to_rad(255.0), 2], [deg_to_rad(285.0), 3], [deg_to_rad(165.0), 4], [deg_to_rad(15.0), 5]]:
		var a: float = spot[0]
		var at := Vector3(cos(a) * (RADIUS - 1.4), 0, sin(a) * (RADIUS - 1.4))
		var yaw := -a - PI * 0.5
		map._part("plate", at + Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 1.0), Color(0.26, 0.27, 0.3), Vector3(0, rad_to_deg(yaw), 0))
		map._solid(at + Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 1.0), true, yaw)
		map._screen(Transform3D(Basis(Vector3.UP, yaw), at), Vector3(0, 1.4, 0.2), Vector2(1.6, 0.8), [1, 3, 5, 7, 9, 11][int(spot[1]) % 6], -1.0, 12.0)
		map._glow_box(at + Vector3(0, 1.02, 0), Vector3(1.8, 0.04, 0.5), Color(0.3, 0.8, 1.0), 2.0, Basis(Vector3.UP, yaw))
	# Cover: armoured crates and a few low barriers in the ring (laser and rush break on them).
	for spot: Vector3 in [Vector3(8.5, 0, 3.2), Vector3(-8.5, 0, -3.2), Vector3(3.0, 0, 9.0), Vector3(-3.0, 0, -9.0), Vector3(17.0, 0, -9.0), Vector3(-17.0, 0, 9.0)]:
		var yaw := atan2(spot.x, spot.z)
		map._part("plate", spot + Vector3(0, 0.65, 0), Vector3(2.4, 1.3, 0.9), Color(0.3, 0.32, 0.34), Vector3(0, rad_to_deg(yaw), 0))
		map._hazard(spot + Vector3(-1.1, 1.32, 0).rotated(Vector3.UP, yaw), spot + Vector3(1.1, 1.32, 0).rotated(Vector3.UP, yaw), Vector3(0.22, 0.03, 0.92), 8)
		map._solid(spot + Vector3(0, 0.65, 0), Vector3(2.4, 1.3, 0.9), true, yaw)
	# Banners of the firm on the wall: long red cloths with its name.
	for spot: Array in [[deg_to_rad(240.0), "UMBRA  BIOSYSTEMS"], [deg_to_rad(300.0), "PROJEKT  NULL"], [deg_to_rad(45.0), "HELIX  ·  EBENE  U9"], [deg_to_rad(135.0), "UMBRA  BIOSYSTEMS"]]:
		var a: float = spot[0]
		var at := Vector3(cos(a) * (RADIUS - 0.4), 15.5, sin(a) * (RADIUS - 0.4))
		var yaw := -a - PI * 0.5
		map._part("plain", at, Vector3(2.4, 7.0, 0.04), Color(0.5, 0.06, 0.05), Vector3(0, rad_to_deg(yaw), 0))
		var sign := map._wall_sign(str(spot[1]).replace("  ", "\n"), at + Vector3(-cos(a), 0, -sin(a)) * 0.05 + Vector3(0, 1.0, 0), 44, Color(0.95, 0.92, 0.88), yaw)
		if sign != null:
			sign.rotation = Vector3(0, yaw, 0)
		map._glow_box(at + Vector3(0, -2.8, 0) + Vector3(-cos(a), 0, -sin(a)) * 0.04, Vector3(1.6, 0.4, 0.02), Color(0.95, 0.85, 0.75), 1.4, Basis(Vector3.UP, yaw))
	map._wall_sign("UMBRA  RESEARCH  FACILITY", Vector3(0, 19.5, -RADIUS + 0.2), 110, Color(0.9, 0.92, 0.94), 0.0)
	# Nozzles of the gas in the wall (four quarters), with their pipes.
	for q in range(4):
		var a := TAU * q / 4.0 + PI * 0.25
		var at := Vector3(cos(a) * (RADIUS - 0.5), 2.2, sin(a) * (RADIUS - 0.5))
		map.batch.cylinder(map.mats["steel"], at, 0.35, 0.25, 0.6, Color(0.45, 0.48, 0.42), 12, Basis(Quaternion(Vector3.UP, -Vector3(cos(a), 0, sin(a)))))
		map._pipe(at + Vector3(0, 0.3, 0), at + Vector3(0, 6.0, 0), 0.16, Color(0.4, 0.45, 0.3), 8, "steel")
		var warn := OmniLight3D.new()
		warn.light_color = Color(0.7, 1.0, 0.2)
		warn.light_energy = 0.0
		warn.omni_range = 6.0
		warn.position = at - Vector3(cos(a), 0, sin(a)) * 0.6
		add_child(warn)
		var bulb := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.18
		ball.height = 0.36
		bulb.mesh = ball
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = Color(0.25, 0.32, 0.1)
		bulb.material_override = paint
		bulb.position = at + Vector3(0, 0.75, 0) - Vector3(cos(a), 0, sin(a)) * 0.2
		add_child(bulb)
		nozzles.append({"at": at, "angle": a, "light": warn, "bulb": paint})
	# Steam that rises from grates in the floor.
	for spot: Vector3 in [Vector3(6.0, 0, -18.0), Vector3(-6.5, 0, 17.0), Vector3(19.0, 0, 5.0), Vector3(-19.0, 0, -6.0)]:
		map._part("tread", spot + Vector3(0, 0.01, 0), Vector3(1.2, 0.02, 1.2), Color(0.15, 0.15, 0.16))
		var steam := CPUParticles3D.new()
		steam.position = spot
		steam.amount = 24
		steam.lifetime = 4.0
		steam.direction = Vector3.UP
		steam.spread = 12.0
		steam.initial_velocity_min = 0.8
		steam.initial_velocity_max = 1.6
		steam.gravity = Vector3(0, 0.15, 0)
		steam.scale_amount_min = 1.0
		steam.scale_amount_max = 2.6
		var puff := QuadMesh.new()
		puff.size = Vector2(1.2, 1.2)
		var smoke := StandardMaterial3D.new()
		smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke.albedo_color = Color(0.85, 0.88, 0.92, 0.07)
		smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		smoke.proximity_fade_enabled = true
		smoke.albedo_texture = soft_puff()
		puff.material = smoke
		steam.mesh = puff
		add_child(steam)
	# Haze in the whole hall, thicker under the reactor.
	map._haze(Vector3(0, 6.0, 0), Vector3(RADIUS * 2.0, 12.0, RADIUS * 2.0), 0.012, Color(0.75, 0.78, 0.85), true)
	map._haze(Vector3(0, 11.0, 0), Vector3(14.0, 10.0, 14.0), 0.02, Color(0.9, 0.5, 0.45), true)

# ---------------------------------------------------------------- the corridor from the lift

func _corridor() -> void:
	# The lift's platform at the south end, the locker with the gas masks in the anteroom.
	map._part("tread", Vector3(0, 0.03, 55.5), Vector3(4.6, 0.06, 4.6), Color(0.45, 0.46, 0.48))
	map._hazard(Vector3(-2.3, 0.065, 53.1), Vector3(2.3, 0.065, 53.1), Vector3(0.38, 0.01, 0.3), 12)
	map._wall_sign("FRACHTAUFZUG  ·  EBENE  U9", Vector3(0, 3.0, 58.75), 40, HAZARD, PI)
	var locker := Vector3(6.9, 0, 37.5)
	map._part("plate", locker + Vector3(0, 1.1, 0), Vector3(1.0, 2.2, 2.6), Color(0.3, 0.42, 0.34))
	map._solid(locker + Vector3(0, 1.1, 0), Vector3(1.0, 2.2, 2.6), true)
	for k in range(3):
		map._part("plate", locker + Vector3(-0.52, 1.1, -0.85 + k * 0.85), Vector3(0.04, 2.0, 0.78), Color(0.38, 0.52, 0.42))
		map._glow_box(locker + Vector3(-0.55, 1.75, -0.85 + k * 0.85), Vector3(0.02, 0.12, 0.3), Color(0.3, 1.0, 0.4), 3.0)
	map._wall_sign("GASMASKEN  ·  NOTFALL", locker + Vector3(-0.55, 2.55, 0), 30, Color(0.9, 0.95, 0.9), -PI * 0.5)
	map._part("plate", Vector3(-6.4, 0.5, 38.0), Vector3(1.2, 1.0, 2.4), Color(0.3, 0.32, 0.3))
	map._wall_sign("NUR  FÜR  BEFUGTE  ·  STUFE  5", Vector3(0, 3.4, 31.25), 34, Color(0.9, 0.2, 0.15), 0.0)
	map._wall_sign("REAKTORHALLE", Vector3(0, 3.9, RADIUS + 0.45), 46, Color(0.95, 0.25, 0.2), 0.0)
	var lamp := map._light(Vector3(0, 3.2, 26.5), RED, 2.0, 7.0, false, 0.25, 0.8)
	lamps.append(lamp)

# ---------------------------------------------------------------- the roof

## The roof of the shaft house, where the helicopter takes Nadja away: a pad with its H
## and lights, a stair house, the night over it.
func _roof() -> void:
	map._begin_zone("boss_roof", "out")
	var node := map.zones["boss_roof"].node as Node3D
	node.position = ROOF
	map.nav_shift = ROOF
	var plan := roof_plan().grow(-2.0)
	map._room("boss_roof", roof_level, plan, 12.0, "none", {"outdoor": true})
	map._chunk("Roof")
	map._part("beton", Vector3(0, -0.3, 0), Vector3(34.0, 0.6, 34.0), Color(0.5, 0.5, 0.52))
	map._firm_solid(Vector3(0, -0.3, 0), Vector3(34.0, 0.6, 34.0), false)
	for side in range(4):
		var along_x := side % 2 == 0
		var off := 16.8 * (1.0 if side < 2 else -1.0)
		var at := Vector3(0, 0.5, off) if along_x else Vector3(off, 0.5, 0)
		var size := Vector3(34.0, 1.0, 0.4) if along_x else Vector3(0.4, 1.0, 34.0)
		map._part("beton", at, size, Color(0.42, 0.42, 0.44))
		map._firm_solid(at, size, false)
	# The pad: a dark circle, its yellow ring and H, lamps round it.
	map.batch.cylinder(map.mats["darkfloor"], Vector3(0, 0.0, 0), 8.0, 8.0, 0.04, Color(0.22, 0.24, 0.26), 40)
	for i in range(48):
		var a := TAU * i / 48.0
		map.batch.box(map.mats["plain"], Vector3(cos(a) * 7.4, 0.05, sin(a) * 7.4), Vector3(1.0, 0.02, 0.32), HAZARD, Basis(Vector3.UP, -a + PI * 0.5))
	map._part("plain", Vector3(-1.6, 0.05, 0), Vector3(0.6, 0.02, 5.0), Color(0.95, 0.95, 0.92))
	map._part("plain", Vector3(1.6, 0.05, 0), Vector3(0.6, 0.02, 5.0), Color(0.95, 0.95, 0.92))
	map._part("plain", Vector3(0, 0.05, 0), Vector3(3.2, 0.02, 0.6), Color(0.95, 0.95, 0.92))
	for i in range(12):
		var a := TAU * i / 12.0
		map._glow_box(Vector3(cos(a) * 8.6, 0.12, sin(a) * 8.6), Vector3(0.24, 0.2, 0.24), Color(0.4, 1.0, 0.45) if i % 2 == 0 else Color(1.0, 0.85, 0.3), 6.0)
	# The stair house the squad comes out of, an antenna, ventilators.
	map._part("beton", Vector3(-11.0, 1.6, 11.0), Vector3(5.0, 3.2, 4.0), Color(0.55, 0.55, 0.56))
	map._firm_solid(Vector3(-11.0, 1.6, 11.0), Vector3(5.0, 3.2, 4.0), true)
	map._part("shutter", Vector3(-11.0, 1.15, 8.98), Vector3(1.4, 2.3, 0.06), Color(0.4, 0.42, 0.45))
	map._glow_box(Vector3(-11.0, 2.55, 8.94), Vector3(0.6, 0.12, 0.08), Color(1.0, 0.95, 0.85), 5.0)
	map._pipe(Vector3(12.0, 0, -12.0), Vector3(12.0, 14.0, -12.0), 0.12, Color(0.5, 0.5, 0.52), 8, "steel")
	map._glow_box(Vector3(12.0, 14.2, -12.0), Vector3(0.3, 0.3, 0.3), RED, 7.0)
	for spot: Vector3 in [Vector3(11.0, 0, 8.0), Vector3(13.0, 0, 8.0), Vector3(-12.0, 0, -10.0)]:
		map._part("plate", spot + Vector3(0, 0.7, 0), Vector3(1.6, 1.4, 1.6), Color(0.5, 0.52, 0.54))
		map._firm_solid(spot + Vector3(0, 0.7, 0), Vector3(1.6, 1.4, 1.6), true)
	map._wall_sign("UMBRA  BIOSYSTEMS  ·  SCHACHTHAUS  9", Vector3(-11.0, 3.6, 8.95), 34, Color(0.9, 0.92, 0.94), PI)
	for corner: Vector3 in [Vector3(-14.0, 4.0, -14.0), Vector3(14.0, 4.0, 14.0)]:
		var flood := SpotLight3D.new()
		flood.light_color = Color(0.95, 0.96, 1.0)
		flood.light_energy = 5.0
		flood.spot_range = 30.0
		flood.spot_angle = 40.0
		flood.position = corner
		flood.basis = Basis.looking_at((Vector3(0, 0, 0) - corner).normalized(), Vector3.UP)
		map.add_child(flood)
		map._pipe(corner - Vector3(0, 4.0, 0), corner, 0.08, Color(0.4, 0.4, 0.42), 6, "steel")
	map.nav_shift = Vector3.ZERO
	map._end_zone()

# ---------------------------------------------------------------- light

func _lights() -> void:
	# White light from above, hard and clear: a ring of spots and one on the middle.
	var spots := [Vector3(0, CEILING - 0.6, 0)]
	for i in range(8):
		var a := TAU * i / 8.0 + PI / 8.0
		spots.append(Vector3(cos(a) * 12.0, CEILING - 0.6, sin(a) * 12.0))
	for i in range(spots.size()):
		var at: Vector3 = spots[i]
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.95, 0.97, 1.0)
		spot.light_energy = 9.0 if i == 0 else 7.0
		spot.spot_range = 34.0
		spot.spot_angle = 26.0 if i == 0 else 30.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = i == 0 or i % 3 == 1
		spot.light_volumetric_fog_energy = 0.6
		spot.position = at
		var aim := Vector3(at.x * 0.15, -1.0, at.z * 0.15).normalized()
		spot.basis = Basis.looking_at(aim, Vector3.RIGHT)
		add_child(spot)
	# A cool fill from the walls, so that steel and faces are never black.
	for i in range(4):
		var a := TAU * i / 4.0
		var fill := OmniLight3D.new()
		fill.light_color = Color(0.7, 0.78, 0.9)
		fill.light_energy = 2.4
		fill.omni_range = 30.0
		fill.omni_attenuation = 0.8
		fill.shadow_enabled = false
		fill.light_volumetric_fog_energy = 0.2
		fill.position = Vector3(cos(a) * 10.0, 9.0, sin(a) * 10.0)
		add_child(fill)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(RADIUS * 2.0 + 2.0, CEILING + 1.0, RADIUS * 2.0 + 2.0)
	probe.position = Vector3(0, 2.0, 0)
	probe.origin_offset = Vector3(0, CEILING * 0.5 - 2.0, 0)
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 0.9
	add_child(probe)

# ---------------------------------------------------------------- what the hall does

func _process(delta: float) -> void:
	clock += delta
	# Drawn (and its lamps lit) only while the map draws its zone.
	if map.zones.has(ZONE):
		visible = (map.zones[ZONE].node as Node3D).visible
	if not visible:
		return
	if is_instance_valid(reactor_ring):
		reactor_ring.rotation.y += delta * 0.25
	if reactor_core != null:
		var beat := 0.6 + 0.4 * sin(clock * 2.4)
		reactor_core.albedo_color = Color(1.0, 0.18 + 0.15 * beat, 0.06)
	for pivot in beacons:
		pivot.rotation.y += delta * 3.2
	for name in gates:
		var gate: Dictionary = gates[name]
		gate.open = move_toward(float(gate.open), float(gate.want), delta * 0.8)
		(gate.node as Node3D).position.y = 2.8 + float(gate.open) * 5.4
		var beam := (gate.beacon as Node3D).get_child(0) as SpotLight3D
		beam.light_energy = 6.0 if float(gate.want) > 0.0 or float(gate.open) > 0.01 else 0.0
	_run_hatches(delta)
	_run_sweeps(delta)
	_run_gas(delta)
	_run_acid(delta)
	_run_waves(delta)
	var keys := hurt_wait.keys()
	for k in keys:
		hurt_wait[k] = float(hurt_wait[k]) - delta
		if float(hurt_wait[k]) <= 0.0:
			hurt_wait.erase(k)

## The survivors this machine moves: its player, and on the host the bots of the squad.
func _locals() -> Array:
	var out: Array = []
	if game == null:
		return out
	if is_instance_valid(game.player) and not game.player.down and game.player.health > 0:
		out.append(game.player)
	if not game.net.joined:
		for mate in game.team:
			if is_instance_valid(mate) and not mate.down:
				out.append(mate)
	return out

func _hurt(who: Node3D, amount: float, from: Vector3, key: String, every: float) -> bool:
	var id := "%d|%s" % [who.get_instance_id(), key]
	if hurt_wait.has(id):
		return false
	hurt_wait[id] = every
	who.receive_damage(amount, from)
	return true

func local_of(pos: Vector3) -> Vector3:
	return pos - origin

# --- the hatches

## The hatches glow `warn` seconds, then open over the lava for `open_for`.
func open_hatches(indices: Array, warn: float = 2.2, open_for: float = 6.0) -> void:
	for i in indices:
		var h: Dictionary = hatches[int(i) % hatches.size()]
		if str(h.state) != "shut":
			continue
		h.state = "warn"
		h.left = warn
		h.hold = open_for
	if game != null:
		game.sounds.play_at("beep", _w(Vector3(0, 2.0, 0)), 2.0, 0.6)

func _run_hatches(delta: float) -> void:
	for h: Dictionary in hatches:
		var glow: StandardMaterial3D = h.glow
		var light: OmniLight3D = h.light
		match str(h.state):
			"shut":
				glow.emission_energy_multiplier = 0.0
				light.light_energy = 0.0
			"warn":
				h.left = float(h.left) - delta
				var blink := 0.5 + 0.5 * sin(clock * (10.0 + 10.0 * (1.0 - clampf(float(h.left) / 2.2, 0.0, 1.0))))
				glow.emission_energy_multiplier = 2.5 * blink
				light.light_energy = 2.2 * blink
				if float(h.left) <= 0.0:
					h.state = "open"
					h.left = float(h.get("hold", 6.0))
					for shape: CollisionShape3D in h.shapes:
						shape.set_deferred("disabled", true)
					if game != null:
						game.sounds.play_at("shutter_open", origin + Vector3(h.cell.x, 0.3, h.cell.y), -2.0, 1.3)
			"open":
				h.left = float(h.left) - delta
				h.open = minf(1.0, float(h.open) + delta * 3.0)
				glow.emission_energy_multiplier = 0.0
				light.light_energy = 3.5 + 0.6 * sin(clock * 7.0)
				if float(h.left) <= 0.0:
					h.state = "closing"
			"closing":
				h.open = maxf(0.0, float(h.open) - delta * 1.6)
				light.light_energy = 2.5 * float(h.open)
				if float(h.open) <= 0.0:
					h.state = "shut"
					for shape: CollisionShape3D in h.shapes:
						shape.set_deferred("disabled", false)
		var cell: Vector2 = h.cell
		var panels: Array = h.panels
		for k in range(panels.size()):
			var way := -1.0 if k == 0 else 1.0
			(panels[k] as Node3D).position = Vector3(cell.x + way * CELL * (0.25 + 0.5 * float(h.open)), -0.08 - 0.14 * float(h.open), cell.y)
		if float(h.open) > 0.5:
			for who: Node3D in _locals():
				var at := local_of(who.global_position)
				if absf(at.x - cell.x) < CELL * 0.5 and absf(at.z - cell.y) < CELL * 0.5 and at.y < 0.25:
					if _hurt(who, LAVA_DPS * 0.25, who.global_position + Vector3.DOWN, "lava", 0.25) and who == game.player:
						game.hud.flash(Color(1.0, 0.35, 0.0), 0.25)
						game.player.velocity.y = maxf(game.player.velocity.y, 4.5)
			if game != null and not game.net.joined:
				for node in get_tree().get_nodes_in_group("infected"):
					var foe := node as Infected
					if foe == null or foe.dead or foe is BossMutant:
						continue
					var at := local_of(foe.global_position)
					if absf(at.x - cell.x) < CELL * 0.5 and absf(at.z - cell.y) < CELL * 0.5 and at.y < 0.25:
						foe.receive_hit(LAVA_DPS * delta * 2.0, Vector3.UP)

## How many hatches there are.
func hatch_count() -> int:
	return hatches.size()

func hatches_busy() -> bool:
	for h: Dictionary in hatches:
		if str(h.state) != "shut":
			return true
	return false

# --- the laser grids

## A grid runs across the hall: "low" (jump over it), "high" (duck under it), "gap" (a
## wall of beams with one gap at `gap`). `along_x`: it runs from west to east (or back
## when `back`), else from north to south.
func laser_sweep(kind: String, along_x: bool, back: bool, gap: float = 0.0) -> void:
	var node := Node3D.new()
	add_child(node)
	var beams: Array = []
	var heights: Array = []
	match kind:
		"low":
			heights = [GRID_LOW]
		"high":
			heights = [GRID_HIGH, GRID_HIGH + 0.45, GRID_HIGH + 0.9]
		_:
			heights = [0.35, 0.9, 1.45, 2.0, 2.55]
	for y: float in heights:
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.05, 0.05)
		beam.mesh = box
		beam.material_override = beam_material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(beam)
		beams.append({"node": beam, "y": y})
	var light := OmniLight3D.new()
	light.light_color = RED
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.shadow_enabled = false
	node.add_child(light)
	var start := -RADIUS + 0.6
	sweeps.append({"node": node, "beams": beams, "kind": kind, "along_x": along_x, "dir": -1.0 if back else 1.0, "pos": -start if back else start, "gap": gap, "light": light, "hit": {}})
	if game != null:
		game.sounds.play_at("beep", _w(Vector3(0, 2.0, 0)), 3.0, 1.6)

func _run_sweeps(delta: float) -> void:
	for i in range(sweeps.size() - 1, -1, -1):
		var s: Dictionary = sweeps[i]
		var before := float(s.pos)
		s.pos = before + float(s.dir) * GRID_SPEED * delta
		var pos := float(s.pos)
		if absf(pos) > RADIUS - 0.4:
			(s.node as Node3D).queue_free()
			sweeps.remove_at(i)
			continue
		var chord := sqrt(maxf(0.0, (RADIUS - 0.3) * (RADIUS - 0.3) - pos * pos))
		var node := s.node as Node3D
		node.position = Vector3(pos, 0, 0) if bool(s.along_x) else Vector3(0, 0, pos)
		node.rotation.y = PI * 0.5 if bool(s.along_x) else 0.0
		(s.light as OmniLight3D).position = Vector3(0, 1.0, 0)
		for b: Dictionary in s.beams:
			var beam := b.node as MeshInstance3D
			var y := float(b.y)
			if str(s.kind) == "gap":
				# Two pieces either side of the gap (beams run along local x: across the hall).
				var gap := float(s.gap)
				var left := -chord
				var right := chord
				beam.position = Vector3((left + (gap - 1.5)) * 0.5, y, 0)
				beam.scale = Vector3(maxf(0.01, (gap - 1.5) - left), 1.0, 1.0)
				var twin: MeshInstance3D = beam.get_meta("twin") if beam.has_meta("twin") else null
				if twin == null:
					twin = MeshInstance3D.new()
					twin.mesh = beam.mesh
					twin.material_override = beam_material
					node.add_child(twin)
					beam.set_meta("twin", twin)
				twin.position = Vector3(((gap + 1.5) + right) * 0.5, y, 0)
				twin.scale = Vector3(maxf(0.01, right - (gap + 1.5)), 1.0, 1.0)
			else:
				beam.position = Vector3(0, y, 0)
				beam.scale = Vector3(chord * 2.0, 1.0, 1.0)
		# Who it touches (on this machine).
		for who: Node3D in _locals():
			var at := local_of(who.global_position)
			var cross := at.x if bool(s.along_x) else at.z
			var along := at.z if bool(s.along_x) else at.x
			if (cross - before) * (cross - pos) > 0.0 and absf(cross - pos) > 0.3:
				continue
			if (s.hit as Dictionary).has(who.get_instance_id()):
				continue
			var low := at.y
			var tall: float = Survivor.CROUCH_HEIGHT if ("crouched" in who and who.crouched) else Survivor.STAND_HEIGHT
			var touched := false
			# (In the grid's frame its beams run across the hall: in that frame "along" is
			# the place across, and the gap is measured there.)
			var across := -along if bool(s.along_x) else along
			for b: Dictionary in s.beams:
				var y := float(b.y)
				if y > low - 0.02 and y < low + tall:
					if str(s.kind) == "gap" and absf(across - float(s.gap)) < 1.3:
						continue
					touched = true
			if touched:
				s.hit[who.get_instance_id()] = true
				who.receive_damage(GRID_HARM, who.global_position + Vector3(0, 1, 0))
				if who == game.player:
					game.hud.flash(Color(1.0, 0.1, 0.05), 0.3)
					game.sounds.play_at("bolt", who.global_position + Vector3(0, 1, 0), 2.0, 1.8)

# --- the gas

## Gas comes from the nozzle of a quarter of the hall: `warn` seconds of hiss, then so long.
func release_gas(quarter: int, seconds: float = 11.0, warn: float = 2.0) -> void:
	var n: Dictionary = nozzles[quarter % nozzles.size()]
	var cloud := CPUParticles3D.new()
	cloud.amount = 90
	cloud.lifetime = 5.0
	cloud.emitting = false
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var a := float(n.angle)
	var centre := Vector3(cos(a) * 13.0, 1.2, sin(a) * 13.0)
	cloud.position = centre
	cloud.emission_box_extents = Vector3(7.5, 1.0, 7.5)
	cloud.direction = Vector3.UP
	cloud.spread = 180.0
	cloud.initial_velocity_min = 0.2
	cloud.initial_velocity_max = 0.7
	cloud.gravity = Vector3.ZERO
	cloud.scale_amount_min = 2.5
	cloud.scale_amount_max = 4.5
	cloud.color = Color(0.6, 1.0, 0.3, 0.22)
	var puff := QuadMesh.new()
	puff.size = Vector2(1.6, 1.6)
	puff.material = gas_material
	cloud.mesh = puff
	add_child(cloud)
	var fog := FogVolume.new()
	fog.size = Vector3(16.0, 3.2, 16.0)
	fog.position = centre + Vector3(0, 0.4, 0)
	var mist := FogMaterial.new()
	mist.density = 0.0
	mist.albedo = Color(0.55, 0.9, 0.3)
	mist.emission = Color(0.05, 0.12, 0.02)
	mist.edge_fade = 0.4
	fog.material = mist
	add_child(fog)
	gas_sectors.append({"quarter": quarter, "angle": a, "warn": warn, "left": seconds, "cloud": cloud, "fog": fog, "nozzle": n, "strength": 0.0})
	if game != null:
		game.sounds.play_at("hiss", origin + n.at, 6.0, 0.7)

func _run_gas(delta: float) -> void:
	for n: Dictionary in nozzles:
		(n.light as OmniLight3D).light_energy = 0.0
		(n.bulb as StandardMaterial3D).albedo_color = Color(0.25, 0.32, 0.1)
	for i in range(gas_sectors.size() - 1, -1, -1):
		var g: Dictionary = gas_sectors[i]
		var n: Dictionary = g.nozzle
		if float(g.warn) > 0.0:
			g.warn = float(g.warn) - delta
			var blink := 0.5 + 0.5 * sin(clock * 16.0)
			(n.light as OmniLight3D).light_energy = 4.0 * blink
			(n.bulb as StandardMaterial3D).albedo_color = Color(0.7, 1.0, 0.2).lerp(Color(0.25, 0.32, 0.1), 1.0 - blink)
			if float(g.warn) <= 0.0:
				(g.cloud as CPUParticles3D).emitting = true
				if game != null:
					game.sounds.play_at("hiss", origin + n.at, 8.0, 0.5)
			continue
		g.left = float(g.left) - delta
		g.strength = clampf(float(g.strength) + delta * (0.8 if float(g.left) > 0.0 else -0.5), 0.0, 1.0)
		(n.light as OmniLight3D).light_energy = 2.0
		((g.fog as FogVolume).material as FogMaterial).density = 0.22 * float(g.strength)
		if float(g.left) <= 0.0:
			(g.cloud as CPUParticles3D).emitting = false
			if float(g.strength) <= 0.0:
				(g.cloud as Node).queue_free()
				(g.fog as Node).queue_free()
				gas_sectors.remove_at(i)
				continue
		# Beyond the mask's job (Survivor._update_mist): it bites harder down here.
		if game != null and float(g.strength) > 0.5 and _in_sector(local_of(game.player.global_position), g):
			if game.player.filter_left <= 0.0:
				_hurt(game.player, GAS_HARM, Vector3.INF, "gas", 1.0)

func _in_sector(local: Vector3, g: Dictionary) -> bool:
	if local.y > 4.0 or local.y < -1.0:
		return false
	var flat := Vector2(local.x, local.z)
	if flat.length() > RADIUS:
		return false
	var a := float(g.angle)
	var centre := Vector2(cos(a), sin(a)) * 13.0
	return absf(flat.x - centre.x) < 8.0 and absf(flat.y - centre.y) < 8.0

## True where the gas of the hall is in the air (the map asks: HiveMap.is_toxic).
func toxic_at(pos: Vector3) -> bool:
	var local := local_of(pos)
	if absf(local.x) > RADIUS + 1.0 or absf(local.z) > RADIUS + 1.0:
		return false
	for g: Dictionary in gas_sectors:
		if float(g.warn) <= 0.0 and float(g.strength) > 0.35 and _in_sector(local, g):
			return true
	return false

# --- acid and shock waves

## Acid where a canister burst: a green pool that burns whoever stands in it.
func acid(at: Vector3, seconds: float = 7.0, radius: float = 2.6) -> void:
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 24
	pool.mesh = disc
	var goo := StandardMaterial3D.new()
	goo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	goo.albedo_color = Color(0.26, 0.6, 0.08, 0.4)
	goo.emission_enabled = true
	goo.emission = Color(0.3, 0.9, 0.1)
	goo.emission_energy_multiplier = 0.35
	goo.roughness = 0.1
	pool.material_override = goo
	pool.position = local_of(at) + Vector3(0, 0.03, 0)
	add_child(pool)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.2)
	light.light_energy = 0.8
	light.omni_range = radius * 1.6
	light.position = Vector3(0, 0.5, 0)
	pool.add_child(light)
	acids.append({"node": pool, "left": seconds, "radius": radius, "mat": goo})

func _run_acid(delta: float) -> void:
	for i in range(acids.size() - 1, -1, -1):
		var a: Dictionary = acids[i]
		a.left = float(a.left) - delta
		var node := a.node as MeshInstance3D
		if float(a.left) <= 0.0:
			node.queue_free()
			acids.remove_at(i)
			continue
		(a.mat as StandardMaterial3D).albedo_color.a = 0.42 * clampf(float(a.left), 0.0, 1.0)
		for who: Node3D in _locals():
			var at := local_of(who.global_position)
			if Vector2(at.x - node.position.x, at.z - node.position.z).length() < float(a.radius) and at.y < 0.5:
				_hurt(who, ACID_DPS * 0.5, who.global_position, "acid", 0.5)

## A shock wave runs out from `at` over the floor: whoever is on the floor where its front
## passes is struck (jump over it).
func shock_wave(at: Vector3, reach: float = 15.0, harm: float = 24.0) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.3, 0.8)
	ring.material_override = mat
	ring.position = local_of(at) + Vector3(0, 0.2, 0)
	ring.scale = Vector3(0.5, 0.6, 0.5)
	add_child(ring)
	waves.append({"node": ring, "r": 0.5, "reach": reach, "harm": harm, "mat": mat, "hit": {}})

func _run_waves(delta: float) -> void:
	for i in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		var before := float(w.r)
		w.r = before + delta * 14.0
		var node := w.node as MeshInstance3D
		node.scale = Vector3(float(w.r), 0.6, float(w.r))
		(w.mat as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - float(w.r) / float(w.reach))
		if float(w.r) >= float(w.reach):
			node.queue_free()
			waves.remove_at(i)
			continue
		var centre := node.position
		for who: Node3D in _locals():
			var at := local_of(who.global_position)
			var d := Vector2(at.x - centre.x, at.z - centre.z).length()
			if d < before - 0.5 or d > float(w.r) + 0.5 or (w.hit as Dictionary).has(who.get_instance_id()):
				continue
			# In the air it passes underneath.
			if at.y > 0.45 or (who is CharacterBody3D and not (who as CharacterBody3D).is_on_floor() and at.y > 0.2):
				continue
			w.hit[who.get_instance_id()] = true
			who.receive_damage(float(w.harm), origin + centre)
			if who is CharacterBody3D:
				var way := Vector3(at.x - centre.x, 0, at.z - centre.z).normalized()
				(who as CharacterBody3D).velocity += way * 7.0 + Vector3(0, 3.0, 0)
			if who == game.player:
				game.player.trauma = 1.0

## The infected's gates: open (they come through) or shut.
func set_gate(name: String, open: bool) -> void:
	if gates.has(name):
		gates[name].want = 1.0 if open else 0.0
		if open and game != null:
			game.sounds.play_at("shutter_open", origin + Vector3((RADIUS if name == "east" else -RADIUS), 2.0, 0), 3.0, 0.8)

## Everything the hall does stops (end of the fight, a defeat).
func calm() -> void:
	for s: Dictionary in sweeps:
		(s.node as Node).queue_free()
	sweeps.clear()
	for g: Dictionary in gas_sectors:
		(g.cloud as Node).queue_free()
		(g.fog as Node).queue_free()
	gas_sectors.clear()
	for a: Dictionary in acids:
		(a.node as Node).queue_free()
	acids.clear()
	for w: Dictionary in waves:
		(w.node as Node).queue_free()
	waves.clear()
	for h: Dictionary in hatches:
		if str(h.state) in ["warn", "open"]:
			h.state = "closing"
	for name in gates:
		gates[name].want = 0.0

# ---------------------------------------------------------------- after the picture

## What Henry's picture of the hall has besides: legs that carry the reactor, two great
## containment columns built into the wall, bands of white light along the panels, the
## upper storey of the observation room lit, and the signs of the sectors.
func _details() -> void:
	map._chunk("Boss")
	# Four legs from the ceiling ring down to the reactor's belly.
	for i in range(4):
		var a := TAU * i / 4.0 + PI * 0.25
		var top := Vector3(cos(a) * 11.0, CEILING - 0.5, sin(a) * 11.0)
		var low := Vector3(cos(a) * 3.6, 15.0, sin(a) * 3.6)
		map._pipe(low, top, 0.38, Color(0.34, 0.35, 0.38), 8, "plate")
		map._glow_box(low.lerp(top, 0.35), Vector3(0.3, 0.3, 0.3), RED, 6.0)
	# The containment columns: steel drums with a lit glass belt and something inside.
	for spot: Array in [[deg_to_rad(208.0), "B-3"], [deg_to_rad(332.0), "C-1"]]:
		var a: float = spot[0]
		var c := Vector3(cos(a) * (RADIUS - 2.2), 0, sin(a) * (RADIUS - 2.2))
		map.batch.cylinder(map.mats["plate"], c, 2.1, 2.1, 6.5, Color(0.36, 0.37, 0.4), 24)
		map.batch.cylinder(map.mats["glass"], c + Vector3(0, 6.5, 0), 2.0, 2.0, 4.5, Color(0.7, 1.0, 0.9), 24, Basis.IDENTITY, false)
		map.batch.cylinder(map.mats["steady"], c + Vector3(0, 6.6, 0), 1.85, 1.85, 4.3, Color(0.12, 0.45, 0.36), 24, Basis.IDENTITY, false)
		map.batch.cylinder(map.mats["plate"], c + Vector3(0, 11.0, 0), 2.1, 1.6, 1.4, Color(0.3, 0.31, 0.34), 24)
		map._hazard(c + Vector3(-1.4, 6.3, 0).rotated(Vector3.UP, -a + PI * 0.5) - Vector3(cos(a), 0, sin(a)) * 1.9, c + Vector3(1.4, 6.3, 0).rotated(Vector3.UP, -a + PI * 0.5) - Vector3(cos(a), 0, sin(a)) * 1.9, Vector3(0.25, 0.3, 0.05), 10)
		var sign := map._wall_sign("%s\nBIO-CONTAINMENT\nLIFE SUPPORT" % str(spot[1]), c - Vector3(cos(a), 0, sin(a)) * 2.15 + Vector3(0, 4.2, 0), 46, Color(0.9, 0.92, 0.94), -a - PI * 0.5)
		if sign != null:
			sign.rotation = Vector3(0, -a - PI * 0.5, 0)
		map._solid(c + Vector3(0, 3.0, 0), Vector3(3.6, 6.0, 3.6), true)
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.45, 1.0, 0.8)
		glow.light_energy = 2.5
		glow.omni_range = 9.0
		glow.shadow_enabled = false
		glow.distance_fade_enabled = false
		glow.position = c - Vector3(cos(a), 0, sin(a)) * 2.6 + Vector3(0, 8.5, 0)
		add_child(glow)
		if not Engine.is_editor_hint():
			var body := LabSpecimen.create(["stalker", "striker"][int(a) % 2], "adrift", 1.6, 4.0, 0.6, a)
			body.position = c + Vector3(0, 6.6, 0)
			add_child(body)
	# Bands of white light along the wall, above the dark lower row and under the catwalk.
	for i in range(WALL_SEGMENTS):
		var a := TAU * (i + 0.5) / WALL_SEGMENTS
		var dir := Vector2(cos(a), sin(a))
		var p := dir * (RADIUS - 0.02)
		if (absf(p.x) < GATE_WIDTH * 0.5 + 0.9 and p.y > 0.0) or (absf(p.y) < 3.4 and absf(p.x) > 10.0) or i % 2 == 1:
			continue
		var basis := Basis(Vector3.UP, -a + PI * 0.5)
		map.batch.box(map.mats["steady"], Vector3(p.x, 5.6, p.y), Vector3(1.8, 0.1, 0.06), Color(0.95, 0.96, 1.0), basis)
		if absf(p.x) < WINDOW.y + 0.6 and p.y < 0.0:
			continue
		map.batch.box(map.mats["steady"], Vector3(p.x, 12.4, p.y), Vector3(1.8, 0.1, 0.06), Color(0.9, 0.93, 1.0), basis)
	# Light that washes the panels upwards from the catwalk (the walls stay steel, not black).
	for i in range(12):
		var a := TAU * (i + 0.5) / 12.0
		var at := Vector3(cos(a) * (RADIUS - 1.6), 6.6, sin(a) * (RADIUS - 1.6))
		if absf(at.x) < WINDOW.y + 1.0 and at.z < 0.0:
			continue
		var wash := SpotLight3D.new()
		wash.light_color = Color(0.85, 0.9, 1.0) if i % 3 != 0 else Color(1.0, 0.35, 0.25)
		wash.light_energy = 3.0
		wash.spot_range = 14.0
		wash.spot_angle = 38.0
		wash.shadow_enabled = false
		wash.light_volumetric_fog_energy = 0.3
		wash.position = at
		wash.basis = Basis.looking_at(Vector3(cos(a) * 0.9, 0.45, sin(a) * 0.9).normalized(), Vector3.UP)
		add_child(wash)
	# The upper storey of the observation room: red light behind its glass.
	map._glow_box(Vector3(0, 14.0, -RADIUS - 0.8), Vector3(WINDOW.y - WINDOW.x - 0.4, 2.4, 0.05), Color(0.55, 0.06, 0.04), 2.0)
	for x: float in [-4.0, 0.0, 4.0]:
		map._glow_box(Vector3(x, 15.1, -RADIUS - 0.6), Vector3(1.6, 0.08, 0.3), Color(1.0, 0.25, 0.18), 6.0)
	# Signs of the sectors.
	map._wall_sign("SECTOR  A  ·  RESTRICTED  AREA", Vector3(0, 7.0, RADIUS - 0.5), 56, Color(0.92, 0.92, 0.9), PI)
	for way: float in [1.0, -1.0]:
		map._wall_sign("EMERGENCY  BLAST  DOOR  %s" % ("A" if way > 0.0 else "B"), Vector3(way * (RADIUS - 0.6), 7.0, 0), 44, Color(0.92, 0.92, 0.9), -way * PI * 0.5)
