class_name ViewLight
extends Node3D
## The light of the weapon in the hands (the first-person view, render layer 2). The lamps
## of the room light it as they light everything; what the eye misses then is the light
## that comes back from the walls and the floor, and that is what this adds - in the colour
## and the strength of the lamps nearby, not one cold fill everywhere (that made the gun
## look pasted on: as bright in the dark yard as in the lit hall, and grey-blue in the warm
## villa). Besides:
## - a faint rim from beyond the weapon, so that its outline still reads in the dark;
## - the flashlight's beam, bounced back from what it falls on (the lamp itself does not
##   light the view: it sits right beside the weapon and would burn it white);
## - the flash of a shot on the weapon and the hands (flash_light(), on each muzzle flash).
## Every light here lights the view only and casts no shadow. The lamps of the level are
## gathered once, and each new one as it is added; they are looked at five times a second.

## How much of the room's light comes back from its walls: in the dark and in a lit room.
const BOUNCE_MIN := 0.12
const BOUNCE_MAX := 0.72
## The light that arrives (lamps by how near they are, and the ambient) in a dark and in a
## brightly lit place.
## What the sun or the moon counts for under the open sky (times its energy squared).
const SKY := 8.0
const DIM := 3.0
const BRIGHT := 35.0
## The light from ahead and above (the top of the weapon and its edges catch it, as metal
## does: it shows only where it is mirrored towards the eye): in the dark a faint cool rim,
## in a lit room its colour and more of it.
const RIM := 0.3
const TOP := 0.55
## A weak light from the eye, in the room's colour: the weapon never goes quite black.
const EYE := 0.12
## The flash of a shot on the weapon (times the weapon's flash), and how far it reaches.
const FLASH := 1.6
const FLASH_RANGE := 0.9
## A lamp counts this far beyond its own range (the light it throws onto the walls).
const REACH := 1.25

var player: Node3D
var bounce: OmniLight3D
var rim: OmniLight3D
var spill: OmniLight3D
var eye_fill: OmniLight3D
var lamps: Array[Light3D] = []
## Lights added since the last look (taken in then: what they are is set after they enter).
var pending: Array[Node] = []
## The sun and the moon: they count where the sky is open above the eye.
var skies: Array[DirectionalLight3D] = []
var gathered := false
var look_left := 0.0
## What the last look found: the colour and strength the bounce goes to, and how lit the
## place is (0..1, for the rim).
var target_color := Color(0.62, 0.66, 0.72)
var target_energy := 0.12
var lit := 0.0
## The raw sum of what arrives (for the pictures of the check).
var strength := 0.0

static func view_light(title: String, energy: float, reach: float, color: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = title
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.light_color = color
	light.light_cull_mask = 2
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	light.light_specular = 0.6
	return light

## The light of a muzzle flash on the weapon and the hands (a child of the flash).
static func flash_light() -> OmniLight3D:
	var light := view_light("ViewFlash", FLASH, FLASH_RANGE, Color("ffc98a"))
	light.light_specular = 1.0
	return light

func _ready() -> void:
	# From the left, a little low: the wall and the floor beside give the light back, from the
	# side so that the weapon keeps its shape (from the eye it looked flat).
	bounce = view_light("Bounce", 0.12, 1.6, target_color)
	bounce.position = Vector3(-0.4, -0.15, -0.3)
	add_child(bounce)
	# From beyond the weapon, high: its top and the edges facing away catch it.
	rim = view_light("Rim", RIM, 1.5, Color(0.72, 0.8, 0.95))
	rim.position = Vector3(0.15, 0.45, -1.0)
	rim.light_specular = 1.0
	add_child(rim)
	eye_fill = view_light("Eye", EYE, 1.2, target_color)
	eye_fill.position = Vector3(0.0, 0.1, 0.1)
	eye_fill.light_specular = 0.2
	add_child(eye_fill)
	spill = view_light("Spill", 0.0, 1.3, Color("e6ecd8"))
	spill.position = Vector3(0.05, -0.25, -0.9)
	add_child(spill)

## The lamps of the level; after that, each new one as it is added.
func gather(root: Node) -> void:
	lamps.clear()
	for node in root.find_children("*", "Light3D", true, false):
		_take(node)
	if not gathered:
		gathered = true
		get_tree().node_added.connect(_added)

func _added(node: Node) -> void:
	if node is Light3D:
		pending.append(node)

func _take(node: Node) -> void:
	if not is_instance_valid(node) or not node is Light3D:
		return
	if node is DirectionalLight3D:
		skies.append(node)
		return
	var light := node as Light3D
	# (Not the view's own lights, nor the flashlight and the muzzle flash beside them.)
	if (light.light_cull_mask & 1) == 0 or light.get_parent() == self or light.get_parent() == get_parent():
		return
	lamps.append(light)

func update(delta: float, eye: Vector3, flashlight: SpotLight3D, ambient: Color) -> void:
	if not gathered and player != null:
		gather(get_tree().root)
	look_left -= delta
	if look_left <= 0.0:
		look_left = 0.2
		_look(eye, ambient)
	var k := minf(1.0, delta * 3.0)
	bounce.light_color = bounce.light_color.lerp(target_color, k)
	bounce.light_energy = lerpf(bounce.light_energy, target_energy, k)
	rim.light_energy = lerpf(rim.light_energy, RIM * (1.0 - lit) + TOP * lit, k)
	rim.light_color = rim.light_color.lerp(Color(0.72, 0.8, 0.95).lerp(target_color.lightened(0.25), lit), k)
	eye_fill.light_color = bounce.light_color
	# The beam comes back from what it falls on: the nearer, the more.
	var beam := 0.0
	if flashlight != null and flashlight.is_visible_in_tree():
		var from := flashlight.global_position
		var ahead := -flashlight.global_basis.z
		var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + ahead * 12.0, 1))
		var gap: float = 12.0 if hit.is_empty() else from.distance_to(hit.position)
		beam = clampf(1.0 - gap / 12.0, 0.0, 1.0) * 0.4 + 0.1
	spill.light_energy = lerpf(spill.light_energy, beam, minf(1.0, delta * 8.0))

## How the lamps near the eye light the place: their colour, weighted by how much of each
## arrives, and the room's own ambient light under it.
func _look(eye: Vector3, ambient: Color) -> void:
	if not pending.is_empty():
		# (One that was freed again before the look is handed to nobody.)
		for node: Variant in pending:
			if is_instance_valid(node):
				_take(node)
		pending.clear()
	var sum := Color(0, 0, 0)
	var weight := 0.0
	var gone := 0
	for light in lamps:
		if not is_instance_valid(light):
			gone += 1
			continue
		# (A map taken out of the world keeps its lamps; they light nothing there.)
		if not light.is_inside_tree() or not light.is_visible_in_tree():
			continue
		var reach := 0.0
		if light is OmniLight3D:
			reach = (light as OmniLight3D).omni_range
		elif light is SpotLight3D:
			reach = (light as SpotLight3D).spot_range
		var gap := light.global_position.distance_to(eye)
		if gap > reach * REACH:
			continue
		var share := light.light_energy * pow(1.0 - gap / (reach * REACH), 2.0)
		if light is SpotLight3D:
			# A spot gives back only what falls near its cone.
			var axis := -light.global_basis.z
			var cone := cos(deg_to_rad((light as SpotLight3D).spot_angle) * 1.6)
			if axis.dot((eye - light.global_position).normalized()) < cone:
				share *= 0.25
		sum += light.light_color * share
		weight += share
	# (Lamps of a level that was taken down are let go.)
	if gone > 0:
		# (By hand: a freed lamp cannot be handed to a typed function.)
		var kept: Array[Light3D] = []
		for one: Variant in lamps:
			if is_instance_valid(one):
				kept.append(one)
		lamps = kept
	# Under the open sky the sun (or the moon) comes back from the ground as well.
	var open_sky := false
	for sky: Variant in skies:
		if not is_instance_valid(sky) or not (sky as Light3D).is_inside_tree() or not (sky as Light3D).is_visible_in_tree() or (sky as Light3D).light_energy <= 0.0:
			continue
		if not open_sky:
			open_sky = player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + Vector3.UP * 40.0, 1)).is_empty()
			if not open_sky:
				break
		# (Squared: the sun of the day counts fully, the dim moon of the night hardly.)
		var share := pow((sky as Light3D).light_energy, 2.0) * SKY
		sum += (sky as Light3D).light_color * share
		weight += share
	var base := Color(ambient.r, ambient.g, ambient.b) * 0.6
	var mixed := base
	if weight > 0.001:
		mixed = (sum / weight).lerp(base, 0.15)
	target_color = Color(maxf(mixed.r, 0.05), maxf(mixed.g, 0.05), maxf(mixed.b, 0.05)).lightened(0.1)
	strength = weight + (ambient.r + ambient.g + ambient.b) / 3.0 * ambient.a
	# What arrives runs from about 4 (the farm's yard at night) to 35 (a lit hall): how lit
	# the place is goes with its logarithm, between DIM and BRIGHT.
	lit = clampf((log(maxf(strength, 0.01)) - log(DIM)) / (log(BRIGHT) - log(DIM)), 0.0, 1.0)
	target_energy = lerpf(BOUNCE_MIN, BOUNCE_MAX, lit)
