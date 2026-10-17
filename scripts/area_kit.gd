class_name AreaKit
extends RefCounted
## The building kit of a piece of the random part of mission two (see HiveLayout): an
## area ("Areal"), a transition between two areas, the arrival after the train ride or the
## lock at the end. Every piece is a script of its own in scripts/areale that extends this
## kit and says two things:
##
##   info()  what the piece is - its CONTRACT, read without any map (see below);
##   lay()   builds it into the map (HiveMap) where HiveLayout has placed it.
##
## A piece is built in its own frame: x and z in metres from the north-west corner of its
## footprint (x east, z south, as everywhere: north is -z), y in metres above its floor
## (its base). The kit turns that into the world: p(), r(), along(). Pieces are never
## turned, only moved, so the sides of a room stay what they are (HiveCore.NORTH ...).
##
## THE CONTRACT of an area (info()):
##   id, kind      "area" (also "transition", "arrival", "end")
##   label         what the HUD calls the place (German), name: the button of the test room
##   size          Vector2(w, d): its footprint, x by z (nothing of it reaches out of it)
##   class         "klein", "mittel" or "gross"
##   levels        heights of its floors above its base: 0.0, and 4.2 / 8.4 for the levels
##                 above (HiveLayout.STOREY); 8.4 is a level the next piece can go on from
##   ports         where the squad comes in and goes out, each {side, at, y, room, role}:
##                 a doorway (PORT_WIDE x PORT_TALL, like the gates of the facility) in the
##                 wall of `room` on `side` (`at` along it), `y` its height (0.0 or 8.4),
##                 role "in", "out" or "both". The way from every "in" port to every "out"
##                 port must be walkable (the checks walk it).
##   mood          the light and haze of the place (HiveCore.MOODS)
##   events        what may have to be done there before its way out opens - one of them
##                 is diced for a night (HiveLayout.choose_event, OBJECTIVES; no area is
##                 only walked through): {kind, goal (the HUD's words), ...}
##                   collect  {count, word, use}: pick up `count` of spots.items
##                   hack     {use, seconds, progress, radius}: [E] at spots.goal, hold near it
##                   restore  {count, use, after, progress}: [E] at `count` of spots.switches
##                   hold     {seconds, progress, radius}: stay near spots.goal
##                   lockdown {seconds, progress}: doors shut behind, hold near spots.goal
##                   clear    {}: every one of `posts` falls
##   spots         where its objectives happen (local): goal, switches [...], items [...]
##   crowd         who keeps coming while the squad is there (as HiveDirector.PRESSURE:
##                 kinds, alive at once, seconds between, pack size [least, most])
##   posts         who waits in it: [[kind, local point], ...]
##   strength      how strong its infected are (as a round of the first mission)
##   lines         what is said on entering it and at its event (cues that exist in Radio):
##                 {"enter": ["talk:m2_water"], "event": ["line:m2_lockdown"]}
##   caches        cache sites as HiveCaches.SITES, but local: [name, room, side, at, look,
##                 title] (at along that wall, local)
##   station       an optional stop (workbench and equipment): [room, side, [[look, at], ...]]
##   supply        an optional supply point: [local point on the floor, facing (Vector3)]
##   staff         looks of the plain infected there besides the facility's own
##                 (HiveDirector.STAFF, look_for), e.g. ["hive_lab2", "hive_worker"]
##   sharks        how many sharks (Shark) swim in its deep water while its stage runs
##                 (and in the test room); its water for them is sharks() (SharkWater)
## lay() builds its rooms (room()), what joins them (door(), pane(), stairs()), its ways
## in (the map's _way_* builders), names its points (point()), and may add water
## (water()). The doorways of its ports are made by HiveLayout, not by lay().
##
## A transition says the same and more (see HiveLayout.shape): its corridor width and
## height, how long its legs may be, whether it may bend, and its rise (stairs).

const NORTH := HiveCore.NORTH
const EAST := HiveCore.EAST
const SOUTH := HiveCore.SOUTH
const WEST := HiveCore.WEST
## The doorway of every port: as wide and as tall as the gates of the facility's locks.
const PORT_WIDE := 3.0
const PORT_TALL := HiveCore.DOOR_TALL

var m: HiveMap
## The piece as HiveLayout has placed it: id, def, origin, size, in / out ports, ...
var piece: Dictionary = {}
## Its north-west corner on its base.
var o := Vector3.ZERO

## What the piece is (see above). The kit's own answer is a plain empty room.
func info() -> Dictionary:
	return {}

## Builds the piece into the map.
func lay() -> void:
	pass

# ---------------------------------------------------------------- the frame

func p(x: float, y: float, z: float) -> Vector3:
	return o + Vector3(x, y, z)

func r(x: float, z: float, w: float, d: float) -> Rect2:
	return Rect2(o.x + x, o.z + z, w, d)

## A place along a wall of a side: x for a wall that runs east-west, z otherwise.
func along(side: int, local: float) -> float:
	return (o.x if side == NORTH or side == SOUTH else o.z) + local

## The name a room of this piece has in the map.
func n(name: String) -> String:
	return "%s_%s" % [str(piece.id), name]

## The floor of the map that a height of this piece stands on.
func lv(height: float) -> int:
	return m.area_floor(o.y + height, piece)

func y(height: float) -> float:
	return o.y + height

# ---------------------------------------------------------------- rooms and what joins them

## A room of the piece: its rectangle in the piece's frame, at a height of it.
func room(name: String, height: float, x: float, z: float, w: float, d: float, tall: float, style: String, options: Dictionary = {}) -> Dictionary:
	var made := m._room(n(name), lv(height), r(x, z, w, d), tall, style, options)
	(piece.rooms as Array).append(n(name))
	return made

## Rectangles of the piece's frame as walk rectangles of a room (the option "walk").
func walks(rects: Array) -> Array:
	var out: Array = []
	for rect: Rect2 in rects:
		out.append(Rect2(rect.position + Vector2(o.x, o.z), rect.size))
	return out

func door(a: String, b: String, at: float, width: float = 2.0, options: Dictionary = {}) -> Dictionary:
	var first: Dictionary = m.room_of[n(a)]
	var side := m._shared_side(first, m.room_of[n(b)])
	return m._door(n(a), n(b), along(side, at), width, options)

func opening(a: String, side: int, at: float, width: float = 2.0, options: Dictionary = {}) -> Dictionary:
	return m._opening(n(a), side, along(side, at), width, options)

func pane(a: String, side: int, at: float, width: float, sill: float, head: float, kind: String = "glass", through: String = "") -> void:
	m._pane(n(a), side, along(side, at), width, sill, head, kind, n(through) if through != "" else "")

## Cuts a gap into a wall of a room without a door of its own: where a port of an upper
## level (its room a gallery without walls) goes through the wall of the tall room around
## it. `low` and `high` above that room's floor.
func cut(room_name: String, side: int, at: float, width: float, low: float, high: float) -> void:
	var a := along(side, at)
	((m.room_of[n(room_name)] as Dictionary).open[side] as Array).append([a - width * 0.5, a + width * 0.5, low, high, "frame"])

## A gallery, catwalk or landing: a room of a level above the base without walls, floor or
## ceiling of its own (the tall room around it has them), walked on where `walks_at` say,
## its floor of steel on posts (deck()).
## (`slab_rect`: where its floor of steel lies, if not over all of it - clear of a wall it
## meets inside the piece.)
func gallery(name: String, height: float, rect: Rect2, walks_at: Array = [], rails_at: Array = [], posts: Array = [], slab_rect: Rect2 = Rect2()) -> Dictionary:
	var made := room(name, height, rect.position.x, rect.position.y, rect.size.x, rect.size.y, 3.0, "bighall", {
		"walls": false, "floor": false, "ceiling": false, "lamps": "none", "walk": walks([rect.grow(-0.65)] if walks_at.is_empty() else walks_at)
	})
	deck(rect if slab_rect.size == Vector2.ZERO else slab_rect, height, rails_at, posts)
	return made

## A flight of steel stairs between two levels of the piece (as the facility's galleries
## have: two metres wide, rails, the lower half kept clear), foot and head local, with
## where one stands below and above.
func flight(foot: Vector3, head: Vector3, land_low: Vector3, land_high: Vector3) -> void:
	m._chunk("Kit", false)
	m._deck_stairs(o + foot, o + head, lv(foot.y), lv(head.y), o + land_low, o + land_high)

## Steps from `foot` up to `head` (local points on their treads), with rails at both
## sides, and the way over them for the paths (from `land_low` on the lower floor to
## `land_high` on the upper one).
func stairs(foot: Vector3, head: Vector3, width: float, land_low: Vector3, land_high: Vector3, rails: bool = true) -> void:
	m._chunk("Stairs", false)
	m._steps(o + foot, o + head, width, "tread", Color(0.42, 0.44, 0.46))
	if rails:
		m._handrail(o + foot, o + head, width * 0.5 - 0.02)
		m._handrail(o + foot, o + head, -(width * 0.5 - 0.02))
	m._link(PackedVector3Array([o + land_low, o + foot, o + head, o + land_high]), width, lv(land_low.y), lv(land_high.y))

## A floor of steel on posts at a level above the base (a gallery, a catwalk, a bridge)
## over a rectangle of the piece, with railings along the given sides ([side, from, to]
## in the frame of the piece). Its posts stand on the base floor where it says.
func deck(rect: Rect2, height: float, rails_at: Array = [], posts: Array = []) -> void:
	var world_rails: Array = []
	for entry: Array in rails_at:
		var side := int(entry[0])
		world_rails.append([side, along(side, float(entry[1])), along(side, float(entry[2]))])
	# (Where it meets an outer wall of the piece it stops at the wall's face: a floor that
	# runs on into the wall to its outer line would lie in one plane with it there.)
	var plan := rect
	var size: Vector2 = piece.get("size", Vector2.ZERO)
	if size != Vector2.ZERO:
		var x0 := rect.position.x + (0.21 if rect.position.x <= 0.01 else 0.0)
		var z0 := rect.position.y + (0.21 if rect.position.y <= 0.01 else 0.0)
		var x1 := rect.end.x - (0.21 if rect.end.x >= size.x - 0.01 else 0.0)
		var z1 := rect.end.y - (0.21 if rect.end.y >= size.y - 0.01 else 0.0)
		plan = Rect2(x0, z0, x1 - x0, z1 - z0)
	m._chunk("Kit", false)
	m._deck_floor(r(plan.position.x, plan.position.y, plan.size.x, plan.size.y), y(height), y(0.0), world_rails)
	for spot: Vector2 in posts:
		post(spot, height)

## A steel post from the base floor up to a level.
func post(spot: Vector2, height: float, thick: float = 0.26) -> void:
	var middle := p(spot.x, height * 0.5 - 0.1, spot.y)
	m._part("plate", middle, Vector3(thick, height - 0.2, thick), Color("1d2124"))
	m._solid(middle, Vector3(thick, height - 0.2, thick))

## A railing along a line of the piece (bodies stop, shots pass).
func railing(from: Vector3, to: Vector3) -> void:
	m._chunk("Kit", false)
	m._guard_rail(o + from, o + to)

## A box to look at and to bump into, in the frame of the piece (middle and size).
func block(material: String, centre: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	m._part(material, o + centre, size, color)
	if solid:
		m._solid(o + centre, size)

## A box that only glows.
func glow(centre: Vector3, size: Vector3, color: Color, strength: float = 4.0) -> void:
	m._glow_box(o + centre, size, color, strength)

## A light without shadows (`fog`: how much of it the haze takes up).
func light(at: Vector3, color: Color, energy: float, reach: float, flicker: float = 0.0, fog: float = 0.4) -> OmniLight3D:
	return m._light(o + at, color, energy, reach, false, flicker, fog, HiveCore.LAMP_FADE)

## Lettering on a wall of a room of the piece.
func stencil(room_name: String, side: int, at: float, high: float, text: String, size: int = 120, color: Color = Color(0.2, 0.22, 0.24)) -> void:
	m._stencil(n(room_name), side, along(side, at), high, text, size, color)

## A named place of the piece (local); its key in the map's points is "<piece>_<key>".
func point(key: String, at: Vector3, yaw: float = 0.0) -> void:
	var world := o + at
	(piece.points as Dictionary)[key] = world
	m.areal_points["%s_%s" % [str(piece.id), key]] = world
	m.areal_facings["%s_%s" % [str(piece.id), key]] = yaw

## Water in a basin of the piece: its surface lies `surface` above the base (below 0: a
## pool beside walkways), its floor `bottom` above the base. `deep`: whoever stands on
## its floor is in deep water (HiveCore.waters: slow, it hurts, [Leertaste] climbs out on
## to the nearest walkway). A basin is a pit: what lies under the water is not walked on.
func water(rect: Rect2, surface: float, bottom: float, deep: bool = true, sharks: bool = false) -> void:
	m._areal_water(r(rect.position.x, rect.position.y, rect.size.x, rect.size.y), y(surface), y(bottom), deep, sharks)

## The water the sharks of the piece swim in: the open parts of its basins as boxes of the
## piece's frame (x, z, w, d), from the bottom to the surface; HiveAreaRun puts the sharks
## into it. Where somebody walks (a walkway, steps) is no part of it.
func shark_water(surface: float, bottom: float, open: Array) -> void:
	var boxes: Array = []
	for rect: Rect2 in open:
		boxes.append(AABB(p(rect.position.x, bottom, rect.position.y), Vector3(rect.size.x, surface - bottom, rect.size.y)))
	m.shark_waters[str(piece.id)] = SharkWater.from_boxes(y(surface), boxes)

# ---------------------------------------------------------------- light and air
## What gives an area its mood besides HiveCore.MOODS: lamps whose cones stand in the
## haze, strips that glow, mist, things that drift in the air, light that pulses or turns,
## and the cheap dressing that carries it (trusses, chains, cables on the floor). None of
## it is solid (CabinMap.snag_kind stays clean) and no light of it casts a shadow unless
## it says so. Mist is volumetric fog and what drifts is hidden while the fog is switched
## off (the test room's SCHATTEN & NEBEL AUS).

## What drifts in the air (see drift()) and what moves (pulse(), sweep()), started and
## watched by one timer of the piece.
var airs: Array = []
var motions: Array[Callable] = []
var watcher: Timer

## A lamp that shines in a cone and casts no shadow (aimed down it cannot leak through a
## floor above). `fog`: how much of it the haze takes up - 0 none, 2 to 4 a cone one sees.
func cone(at: Vector3, aim: Vector3, color: Color, energy: float, reach: float, angle: float, fog: float = 1.5, flicker: float = 0.0) -> SpotLight3D:
	return m._spot(o + at, aim, color, energy, reach, angle, flicker, fog, HiveCore.LAMP_FADE + 14.0)

## A strip light: a dark housing with a glowing tube, `long` metres along x or z.
func strip(at: Vector3, long: float, along_x: bool, color: Color, strength: float = 6.0, housing: bool = true) -> void:
	var size := Vector3(long, 0.05, 0.11) if along_x else Vector3(0.11, 0.05, long)
	if housing:
		m._part("plate", o + at + Vector3(0, 0.05, 0), size + Vector3(0.08, 0.05, 0.12) if along_x else size + Vector3(0.12, 0.05, 0.08), Color("191c1e"))
	m._glow_box(o + at, size, color, strength)

## A truss under a roof, from `from` to `to` (both on its upper chord, along x or along
## z): two chords and the struts between them. Only seen.
func truss(from: Vector3, to: Vector3, deep: float = 0.8, color: Color = Color("24282b")) -> void:
	var along := to - from
	var long := along.length()
	var axis := along / maxf(0.01, long)
	var chord := Vector3(long, 0.14, 0.14) if absf(axis.x) > 0.5 else Vector3(0.14, 0.14, long)
	var middle := (from + to) * 0.5
	m._part("plate", o + middle, chord, color)
	m._part("plate", o + middle - Vector3(0, deep, 0), chord, color)
	var count := maxi(1, roundi(long / deep))
	for k in range(count):
		var a := from + axis * (long * k / count)
		var b := from + axis * (long * (k + 1) / count)
		m._pipe(o + a, o + b - Vector3(0, deep, 0), 0.035, color, 5, "steel")
		m._pipe(o + b, o + b - Vector3(0, deep, 0), 0.035, color, 5, "steel")

## A chain hanging from `top` down `long` metres, a hook at its end. Only seen.
func chain(top: Vector3, long: float, hook: bool = true, color: Color = Color("2b2b29")) -> void:
	var links := maxi(2, int(long / 0.11))
	for k in range(links):
		var turn := Basis(Vector3.UP, PI / 2) if k % 2 == 1 else Basis.IDENTITY
		m.batch.box(m.mats["steel"], o + top - Vector3(0, 0.055 + k * 0.11, 0), Vector3(0.06, 0.13, 0.016), color, turn)
	if hook:
		var end := o + top - Vector3(0, links * 0.11 + 0.12, 0)
		m._part("plate", end, Vector3(0.05, 0.22, 0.05), color)
		m._part("plate", end + Vector3(0.07, -0.11, 0), Vector3(0.18, 0.05, 0.05), color)
		m._part("plate", end + Vector3(0.14, -0.05, 0), Vector3(0.05, 0.12, 0.05), color)

## A cable lying on the floor from `from` to `to` (local, at their height), winding to
## the sides by `wind`. Thin and only seen: nothing to stumble over.
func cable(from: Vector3, to: Vector3, wind: float = 0.6, color: Color = Color("0f1112"), radius: float = 0.03) -> void:
	var along := to - from
	var side := Vector3(-along.z, 0, along.x).normalized()
	var pieces := maxi(4, int(along.length() / 0.7))
	var phase := m.random.randf() * TAU
	var lift := Vector3(0, radius, 0)
	var last := o + from + lift
	for k in range(1, pieces + 1):
		var t := float(k) / pieces
		var bend := sin(t * PI * 2.2 + phase) * wind * sin(t * PI)
		var point := o + from + along * t + side * bend + lift
		m._pipe(last, point, radius, color, 5, "plain")
		last = point

## A bundle of cables hanging between two points under a roof, sagging.
func cables(from: Vector3, to: Vector3, count: int = 3, sag: float = 1.2, color: Color = Color("101213")) -> void:
	for k in range(count):
		var shift := Vector3(0, 0, 0.09 * k) if absf(to.x - from.x) > absf(to.z - from.z) else Vector3(0.09 * k, 0, 0)
		m._hose(o + from + shift, o + to + shift, 0.025, color, sag + 0.25 * k, Vector3.ZERO, 8)

## A patch of mist: volumetric fog of its own (`drum`: a standing cylinder).
func mist(centre: Vector3, size: Vector3, density: float, tint: Color = Color(0.78, 0.86, 0.95), drum: bool = false, fade: float = 0.25) -> FogVolume:
	var cloud := FogVolume.new()
	cloud.name = "Mist"
	cloud.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER if drum else RenderingServer.FOG_VOLUME_SHAPE_BOX
	cloud.size = size
	var stuff := FogMaterial.new()
	stuff.density = density
	stuff.albedo = tint
	stuff.edge_fade = fade
	cloud.material = stuff
	cloud.position = o + centre
	m.add_child(cloud)
	return cloud

## What drifts in the air of a box (local centre and size): spores, dust, steam. Options:
## size (of a speck, metres), life (seconds), rise (metres a second up; below 0 it sinks),
## spread (sideways speed), glow (it shines by itself), grow (it swells as it goes: steam),
## alpha. Hidden while the fog is off.
func drift(centre: Vector3, box: Vector3, amount: int, color: Color, options: Dictionary = {}) -> GPUParticles3D:
	var life := float(options.get("life", 8.0))
	var speck := float(options.get("size", 0.04))
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flow.emission_box_extents = box * 0.5
	flow.direction = Vector3.UP
	flow.spread = 180.0 if float(options.get("rise", 0.0)) == 0.0 else 25.0
	flow.gravity = Vector3(0, float(options.get("rise", 0.0)), 0)
	flow.initial_velocity_min = 0.0
	flow.initial_velocity_max = float(options.get("spread", 0.15))
	flow.damping_min = 0.02
	flow.damping_max = 0.08
	flow.scale_min = 0.6
	flow.scale_max = 1.4
	if options.has("grow"):
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.3))
		curve.add_point(Vector2(1, float(options.grow)))
		var swell := CurveTexture.new()
		swell.curve = curve
		flow.scale_curve = swell
	# It comes and goes softly.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	flow.color_ramp = ramp
	flow.color = color
	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_texture = _soft_dot()
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	if bool(options.get("glow", false)):
		look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		look.albedo_color = Color(2.2, 2.2, 2.2, float(options.get("alpha", 1.0)))
	else:
		look.albedo_color = Color(1, 1, 1, float(options.get("alpha", 1.0)))
		look.roughness = 1.0
	var card := QuadMesh.new()
	card.size = Vector2(speck, speck)
	card.material = look
	var cloud := GPUParticles3D.new()
	cloud.name = "Drift"
	cloud.amount = amount
	cloud.lifetime = life
	cloud.preprocess = life
	cloud.process_material = flow
	cloud.draw_pass_1 = card
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := maxf(4.0, absf(float(options.get("rise", 0.0))) * life + speck * 3.0)
	cloud.visibility_aabb = AABB(-box * 0.5 - Vector3(2, reach, 2), box + Vector3(4, reach * 2.0, 4))
	cloud.position = o + centre
	m.add_child(cloud)
	airs.append(cloud)
	_watch()
	return cloud

## A soft round speck, shared by everything that drifts.
static var soft_dot: Texture2D

func _soft_dot() -> Texture2D:
	if soft_dot == null:
		var shade := Gradient.new()
		shade.set_color(0, Color(1, 1, 1, 1))
		shade.set_color(1, Color(1, 1, 1, 0))
		var dot := GradientTexture2D.new()
		dot.gradient = shade
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(0.5, 0.0)
		dot.width = 64
		dot.height = 64
		soft_dot = dot
	return soft_dot

## A light whose energy breathes between `low` and `high` every `seconds`, with an
## unsteady flutter on top (`flutter`: its share) - a core that burns.
func pulse(lamp: Light3D, low: float, high: float, seconds: float, flutter: float = 0.0) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = m.random.randi()
	noise.frequency = 0.9
	var clock := [m.random.randf() * 50.0]
	motions.append(func() -> void:
		var breathe := func(phase: float) -> void:
			clock[0] += 0.016
			var energy := lerpf(low, high, 0.5 + 0.5 * sin(phase))
			lamp.light_energy = energy * (1.0 + noise.get_noise_1d(float(clock[0]) * 12.0) * flutter)
		lamp.create_tween().set_loops().tween_method(breathe, 0.0, TAU, seconds))
	_watch()

## The same for the glow of a material (its albedo, which sets how bright it shines).
func pulse_glow(material: StandardMaterial3D, low: float, high: float, seconds: float) -> void:
	motions.append(func() -> void:
		var breathe := func(phase: float) -> void:
			var value := lerpf(low, high, 0.5 + 0.5 * sin(phase))
			material.albedo_color = Color(value, value, value)
		watcher.create_tween().set_loops().tween_method(breathe, 0.0, TAU, seconds))
	_watch()

## A pivot at `at` that turns about the vertical once every `seconds` (a beacon: what is
## hung on it turns with it). Returns the pivot.
func sweep(at: Vector3, seconds: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Sweep"
	pivot.position = o + at
	m.add_child(pivot)
	motions.append(func() -> void:
		pivot.create_tween().set_loops().tween_property(pivot, "rotation:y", TAU, seconds).from(0.0))
	_watch()
	return pivot

## A floor that shines wet: a skin over it, dark and smooth in patches (`rect` local, at
## `height`), which mirrors the lamps.
func wet_floor(rect: Rect2, height: float, color: Color = Color(0.06, 0.07, 0.08), patchy: float = 1.0) -> void:
	var key := "areal_wet_%s" % color.to_html()
	if not m.mats.has(key):
		var noise := FastNoiseLite.new()
		noise.seed = 4711
		noise.frequency = 0.05
		var patches := NoiseTexture2D.new()
		patches.width = 256
		patches.height = 256
		patches.seamless = true
		patches.noise = noise
		var skin := StandardMaterial3D.new()
		skin.albedo_color = color
		skin.roughness = 0.5
		skin.roughness_texture = patches
		skin.metallic_specular = 0.75
		skin.uv1_triplanar = true
		skin.uv1_world_triplanar = true
		skin.uv1_scale = Vector3.ONE * 0.06 * patchy
		m.mats[key] = skin
	var y0 := y(height) + 0.012
	m.batch.quad(m.mats[key], Vector3(o.x + rect.position.x, y0, o.z + rect.position.y), Vector3(o.x + rect.position.x, y0, o.z + rect.end.y), Vector3(o.x + rect.end.x, y0, o.z + rect.end.y), Vector3(o.x + rect.end.x, y0, o.z + rect.position.y))

## Frosted glass lit from inside (a cryo pod, a grow dome): see-through in part, it
## shines by itself and lets a shape behind it show dark.
func frost(color: Color, alpha: float = 0.62, energy: float = 2.4) -> StandardMaterial3D:
	var key := "areal_frost_%s_%.2f_%.1f" % [color.to_html(), alpha, energy]
	if not m.mats.has(key):
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, alpha)
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.render_priority = 1
		m.mats[key] = glass
	return m.mats[key]

## A small panel on a wall with lamps that blink red and green and a screen (the
## consoles along a catwalk): `at` its middle on the wall's face, `out` the way it faces.
func panel(at: Vector3, out: Vector3, picture: int = 3) -> void:
	var side := Vector3(-out.z, 0, out.x)
	var turn := Basis(Vector3.UP, atan2(out.x, out.z))
	m.batch.box(m.mats["steel"], o + at + out * 0.06, Vector3(0.7, 0.55, 0.12), Color("22272a"), turn)
	m._screen(Transform3D(turn, o + at + out * 0.125 + Vector3(0, 0.06, 0)), Vector3.ZERO, Vector2(0.36, 0.24), picture)
	for k in range(3):
		var tint := Color("ff2a1e") if k != 1 else Color("38ff6a")
		m._led(o + at + out * 0.13 + side * (0.26) + Vector3(0, 0.16 - k * 0.12, 0), Vector3(0.05, 0.05, 0.05), tint, 6.0, [1.0, 0.4, 0.7][k])

## One timer of the piece: it starts what moves once the map stands, and hides what
## drifts in the air while the fog is off.
func _watch() -> void:
	if watcher != null:
		return
	watcher = Timer.new()
	watcher.name = "AirWatch"
	watcher.wait_time = 0.5
	watcher.autostart = true
	var started := [false]
	watcher.timeout.connect(func() -> void:
		if not started[0]:
			started[0] = true
			for start in motions:
				start.call()
		var on: bool = m.environment == null or m.environment.volumetric_fog_enabled
		for cloud in airs:
			if is_instance_valid(cloud):
				(cloud as Node3D).visible = on)
	m.add_child(watcher)

# ---------------------------------------------------------------- ways in

## The map's builders of ways in open and close the zone of their room themselves; while
## a piece is built its zone is open, so it is closed around them and opened again (or
## what was built before them would be left outside the zone).
func _around(build: Callable) -> void:
	m._end_zone()
	build.call()
	m._begin_zone(str(piece.id))
	m._chunk("Kit", false)

## A hole in the ceiling of a room (local x, z); `land`: the height above the room's
## floor they come down on (a gallery).
func drop(room_name: String, x: float, z: float, turn: int = 0, options: Dictionary = {}) -> void:
	_around(func() -> void: m._way_drop(n(room_name), o.x + x, o.z + z, turn, options))

## A hole at the foot of a wall ("breach", "vent", "pipes"): only where nothing lies behind.
func hole(room_name: String, side: int, at: float, skin: String = "breach") -> void:
	_around(func() -> void: m._way_hole(n(room_name), side, along(side, at), skin))

## The mouth of a duct high in a wall.
func duct(room_name: String, side: int, at: float, options: Dictionary = {}) -> void:
	_around(func() -> void: m._way_duct(n(room_name), side, along(side, at), options))

## A torn-open wall with a cavity behind it.
func breach(room_name: String, side: int, at: float, turn: float = 1.0) -> void:
	_around(func() -> void: m._way_breach(n(room_name), side, along(side, at), turn))

## A pit in the floor they crawl out of.
func trench(room_name: String, x: float, z: float, turn: int = 0) -> void:
	_around(func() -> void: m._way_trench(n(room_name), o.x + x, o.z + z, turn))

## An edge they climb over (`at` on it, `into` the way on to the floor; `deep` below).
func edge(room_name: String, at: Vector3, into: Vector3, deep: float = 1.1) -> void:
	_around(func() -> void: m._way_edge(n(room_name), o + at, into, deep))

## A housing under whatever is overhead at `at` (no room's ceiling): they land on `land`.
func hang(at: Vector3, land: Vector3, turn: int = 0) -> void:
	_around(func() -> void: m._way_hang(str(piece.id), o + at, o + land, turn, o + land + Vector3(3.0, 1.6, 3.0)))

## Builds something in a zone of its own beside the piece's (the car the train ride ends
## in: it stays drawn while the piece around it is not, see HiveMap.ride_areal).
func in_zone(suffix: String, mood: String, build: Callable) -> void:
	m._end_zone()
	m._begin_zone("%s_%s" % [str(piece.id), suffix], mood)
	build.call()
	m._end_zone()
	m._begin_zone(str(piece.id))
	m._chunk("Kit", false)

## The tunnel the train seems to run through on the way to this piece's car (`centre`,
## local): drawn only during the ride (HiveMap.ride_areal).
func ride_tunnel(centre: Vector3) -> void:
	m._end_zone()
	var lamps := HiveAreale.ride_tunnel(m, "%s_ride" % str(piece.id), o + centre)
	m.areal_rides[str(piece.id)] = {"zone": "%s_ride" % str(piece.id), "lamps": lamps, "car": o + centre}
	m._begin_zone(str(piece.id))
	m._chunk("Kit", false)

## A cache site, a stop, a supply point (built by HiveAreale from info(); nothing to do
## here) - and a slab to walk on that is no room's floor: a walkway, a landing.
func slab(rect: Rect2, height: float, material: String = "tread", color: Color = Color(0.42, 0.44, 0.46), thick: float = 0.3) -> void:
	var centre := p(rect.get_center().x, height - thick * 0.5, rect.get_center().y)
	var size := Vector3(rect.size.x, thick, rect.size.y)
	m._part(material, centre, size, color)
	m._solid(centre, size, false)

# ---------------------------------------------------------------- what the generator reads

## The ports of the piece in the world, as HiveLayout places them: its doorway's middle
## on the wall line, its height, and the way it looks out.
static func port_spot(origin: Vector3, size: Vector2, port: Dictionary) -> Vector3:
	var at := float(port.at)
	match int(port.side):
		NORTH:
			return origin + Vector3(at, float(port.y), 0.0)
		SOUTH:
			return origin + Vector3(at, float(port.y), size.y)
		WEST:
			return origin + Vector3(0.0, float(port.y), at)
	return origin + Vector3(size.x, float(port.y), at)

## A step into the piece from a port: where somebody who has just come through it stands.
static func port_inside(origin: Vector3, size: Vector2, port: Dictionary, depth: float = 2.6) -> Vector3:
	var out: Vector2 = HiveCore.OUT[int(port.side)]
	return port_spot(origin, size, port) - Vector3(out.x, 0.0, out.y) * depth
