class_name LaserSight
extends Node3D
## The laser module's dot (Survivor.LASER_PART): a bright point with a soft glow where the
## beam meets the first thing in its way, a faint beam from the module to it and a small
## light that tints what is round the dot in the dark. In the colour of the reticle
## workshop (Reticle). One for the player in hand (Survivor._update_laser) and one for the
## co-op partner whose laser is on (RemoteSurvivor).
## The module itself is part of the weapon's view: fit_module puts it on a gun of WeaponView.GUNS.

## What the beam stops at: the world, the infected and their heads (as a shot does).
const MASK := 1 | 4 | 8
const REACH := 150.0
## How big the dot is (metres for every metre away, and at the least): it keeps a size the
## eye can find at any distance.
const DOT_SPREAD := 0.006
const DOT_LEAST := 0.006

var dot: MeshInstance3D
var halo: MeshInstance3D
var beam: MeshInstance3D
var glow: OmniLight3D
var dot_paint: StandardMaterial3D
var halo_paint: StandardMaterial3D
var beam_paint: StandardMaterial3D
## Whether a faint beam is drawn from the module (the partner's is seen from outside).
var show_beam := true
## Where the dot was last put, and whether on something (tests and pictures read it).
var spot := Vector3.ZERO
var hit_something := false
## The physics frame of the last aim: a dot that is no longer aimed (its owner gone) goes out.
var aimed_at := -10
## (Off for pictures, whose dot is put once and stays.)
var auto_off := true

func _physics_process(_delta: float) -> void:
	if auto_off and visible and Engine.get_physics_frames() - aimed_at > 3:
		hide()

func _ready() -> void:
	dot_paint = _paint(0.5)
	halo_paint = _paint(0.0)
	dot = _quad(dot_paint)
	halo = _quad(halo_paint)
	beam_paint = StandardMaterial3D.new()
	beam_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var line := CylinderMesh.new()
	line.top_radius = 0.0012
	line.bottom_radius = 0.0012
	line.height = 1.0
	line.radial_segments = 6
	line.rings = 1
	beam = MeshInstance3D.new()
	beam.mesh = line
	beam.material_override = beam_paint
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	glow = OmniLight3D.new()
	glow.omni_range = 0.22
	glow.light_energy = 0.12
	glow.shadow_enabled = false
	glow.light_specular = 0.2
	add_child(glow)
	hide()

## A round glow, unshaded and added to what is behind it; drawn over the surface it lies on.
func _paint(core: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.render_priority = 2
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9 if core > 0.0 else 0.35), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, maxf(core, 0.05), 1.0])
	var spot_texture := GradientTexture2D.new()
	spot_texture.gradient = ramp
	spot_texture.fill = GradientTexture2D.FILL_RADIAL
	spot_texture.fill_from = Vector2(0.5, 0.5)
	spot_texture.fill_to = Vector2(0.5, 0.0)
	spot_texture.width = 64
	spot_texture.height = 64
	paint.albedo_texture = spot_texture
	return paint

func _quad(paint: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

## Puts the dot where a beam from `from` along `direction` first strikes (leaving out
## `exclude`), and the beam from `emitter` to it. `eye`: where it is looked at from, to keep
## the dot's size.
func aim(from: Vector3, direction: Vector3, emitter: Vector3, eye: Vector3, exclude: Array[RID] = []) -> void:
	show()
	aimed_at = Engine.get_physics_frames()
	var colour := Reticle.laser_color()
	dot_paint.albedo_color = Color(colour.r * 2.4, colour.g * 2.4, colour.b * 2.4, 1.0)
	halo_paint.albedo_color = Color(colour.r, colour.g, colour.b, 0.28)
	beam_paint.albedo_color = Color(colour.r, colour.g, colour.b, 0.07)
	glow.light_color = colour
	var query := PhysicsRayQueryParameters3D.create(from, from + direction.normalized() * REACH, MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	hit_something = not hit.is_empty()
	var normal := -direction.normalized()
	spot = from + direction.normalized() * REACH
	if hit_something:
		spot = hit.position
		normal = (hit.normal as Vector3).normalized()
	# A dot lies on the surface, a hair proud of it; in the air (nothing hit) it is not seen.
	dot.visible = hit_something
	halo.visible = hit_something
	glow.visible = hit_something
	var away := eye.distance_to(spot)
	var size := maxf(DOT_LEAST, away * DOT_SPREAD) * Reticle.size
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var face := Basis.looking_at(-normal, up)
	var at := spot + normal * 0.006
	dot.global_transform = Transform3D(face.scaled(Vector3(size, size, 1.0)), at)
	halo.global_transform = Transform3D(face.scaled(Vector3(size * 3.0, size * 3.0, 1.0)), at + normal * 0.001)
	glow.global_position = spot + normal * 0.05
	# The beam: a thin glowing line from the module's mouth to the dot.
	var span := spot - emitter
	beam.visible = show_beam and span.length() > 0.05
	if beam.visible:
		var along := span.normalized()
		var side := along.cross(Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
		var frame := Basis(side, along * span.length(), along.cross(side) * -1.0)
		beam.global_transform = Transform3D(frame, emitter + span * 0.5)

# ---------------------------------------------------------------- the module on the gun

## The laser module's model (tools/blender_make_laser.py) and its mouth (the SPEC the
## script prints, from the face that touches the gun).
const MODULE_SCENE := "res://assets/models/laser.glb"
const EMITTER := Vector3(0.0125, 0.0042, -0.0253)
static var places: Dictionary = {}

## The module on a gun of WeaponView.GUNS that takes it, hidden as the other parts are
## ("Mod_laser"): clamped to the gun's left side just ahead of where the support hand holds,
## at the height of the bore - the side the player sees, and where the support hand's thumb
## finds its switch. (It is built for the right side: mirrored.) Its mouth is "LaserEmitter".
static func fit_module(view: Node3D, id: String) -> void:
	if not (Survivor.ATTACHMENTS.get(id, {}) as Dictionary).has("laser"):
		return
	var place := place_on(view, id)
	var module := Node3D.new()
	module.name = "Mod_laser"
	view.add_child(module)
	var model := (load(MODULE_SCENE) as PackedScene).instantiate() as Node3D
	model.position = place
	model.scale.x = -1.0
	module.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(surface, WeaponView.shotgun_material(mesh.mesh.surface_get_material(surface), true, "laser/"))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = 2
	var mouth := Marker3D.new()
	mouth.name = "LaserEmitter"
	mouth.position = place + Vector3(-EMITTER.x, EMITTER.y, EMITTER.z)
	module.add_child(mouth)
	module.hide()

## Where it sits on a gun whose side is not plain at the bore: (height, along) from the
## middle of the grip. The P90: on the side of the bridge under the sight, over the charging
## handle and behind the front of the body.
const SPOTS := {"p90": Vector2(0.062, -0.1)}

## Where the module's face on the gun is, in the view's space: the outermost point of the
## gun's left side in a slice a module long, at the bore's height - measured on the model
## itself, so that it sits right on every gun, also on one that is rebuilt. Once per gun.
static func place_on(view: Node3D, id: String) -> Vector3:
	if places.has(id):
		return places[id]
	var gun: Dictionary = WeaponView.GUNS[id]
	var mount: Vector3 = gun.mount
	var muzzle: Vector3 = mount + (gun.muzzle as Vector3)
	var hold: Vector3 = mount + (gun.support as Vector3)
	# Clear ahead of the hand (its thumb lies along the side), behind the muzzle.
	var z := maxf(hold.z - 0.065, muzzle.z + 0.035)
	var y := muzzle.y
	if SPOTS.has(id):
		y = mount.y + (SPOTS[id] as Vector2).x
		z = mount.z + (SPOTS[id] as Vector2).y
	var slab := AABB(Vector3(-1.0, y - 0.013, z - 0.026), Vector3(2.0, 0.026, 0.052))
	var side := 0.0
	var model := view.get_child(0) as Node3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var frame := Transform3D.IDENTITY
		var at: Node = mesh
		while at != view and at != null:
			if at is Node3D:
				frame = (at as Node3D).transform * frame
			at = at.get_parent()
		if not (frame * mesh.mesh.get_aabb()).intersects(slab):
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p := frame * point
				if p.x < side and absf(p.z - z) < 0.026 and absf(p.y - y) < 0.013:
					side = p.x
	if side >= 0.0 or side < -0.06:
		side = -0.024
	places[id] = Vector3(side, y, z)
	return places[id]
