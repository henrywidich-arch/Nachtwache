class_name CruVisual
extends InfectedVisual
## The body of a C.R.U. soldier. It wraps the armed-human model the squad uses
## (SoldierVisual), so that the rules in Infected can treat a soldier like any other enemy.
## `kind` is the look in SoldierVisual.LOOKS.

var soldier: SoldierVisual
## Set by the soldier's behaviour: weapon raised, and the recoil of a shot showing.
var aiming := false
var firing := false
var last_position := Vector3.INF
## What makes a soldier stand out in the dark: the lamp under his barrel and its glowing
## lens, the red marker on his chest and the light it throws on him.
var lamp: SpotLight3D
var beacons: Array[Node3D] = []
## The shield of a shield bearer, standing in front of him.
var shield: Node3D

func _ready() -> void:
	soldier = SoldierVisual.new()
	soldier.look = kind
	soldier.mortal = true
	add_child(soldier)
	skeleton = soldier.skeleton
	mesh_instance = soldier.mesh_instance
	eyes = Node3D.new()
	add_child(eyes)
	_fit_lamps()
	if kind == "cruelite":
		_fit_lenses()
	var bearer := get_parent() as Infected
	if bearer != null and str(bearer.spec.get("role", "")) == "shield":
		_fit_shield()

## A man-high ballistic shield with a window, carried in front of the body (the body
## looks along -Z here).
func _fit_shield() -> void:
	shield = Node3D.new()
	shield.name = "Shield"
	shield.position = Vector3(-0.05, 0.0, -0.52)
	add_child(shield)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("30353a")
	steel.metallic = 0.35
	steel.roughness = 0.5
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.18, 0.3, 0.38, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(3.0, 0.22, 0.16)
	# [size, place, turn about the upright in degrees, material]: the main plate, two
	# wings angled back, the frame of the window, the window, a red bar and the grip.
	var parts := [
		[Vector3(0.46, 1.08, 0.03), Vector3(0, 0.8, 0), 0.0, steel],
		[Vector3(0.46, 0.1, 0.03), Vector3(0, 1.69, 0), 0.0, steel],
		[Vector3(0.1, 0.26, 0.03), Vector3(-0.18, 1.51, 0), 0.0, steel],
		[Vector3(0.1, 0.26, 0.03), Vector3(0.18, 1.51, 0), 0.0, steel],
		[Vector3(0.26, 0.26, 0.012), Vector3(0, 1.51, 0), 0.0, glass],
		[Vector3(0.16, 1.48, 0.03), Vector3(-0.3, 1.0, 0.035), 28.0, steel],
		[Vector3(0.16, 1.48, 0.03), Vector3(0.3, 1.0, 0.035), -28.0, steel],
		[Vector3(0.34, 0.035, 0.012), Vector3(0, 1.3, -0.022), 0.0, red],
		[Vector3(0.05, 0.3, 0.07), Vector3(0.0, 1.05, 0.05), 0.0, steel]
	]
	for part in parts:
		var box := BoxMesh.new()
		box.size = part[0]
		var node := MeshInstance3D.new()
		node.mesh = box
		node.material_override = part[3]
		node.position = part[1]
		node.rotation.y = deg_to_rad(float(part[2]))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shield.add_child(node)

## The Elite's gas mask: its two round lenses glow, so that he can be told from the
## others at a glance. Measured on the model: 5.7 cm either side of the middle, 1.735 m
## up, the glass 18 cm in front of the head bone.
func _fit_lenses() -> void:
	var head := skeleton.find_bone("head")
	if head < 0:
		return
	var holder_bone := BoneAttachment3D.new()
	holder_bone.name = "Lenses"
	skeleton.add_child(holder_bone)
	holder_bone.bone_idx = head
	var rest := skeleton.get_bone_global_rest(head).affine_inverse()
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(3.0, 1.5, 0.25)
	for side in [-1.0, 1.0]:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.03
		disc.bottom_radius = 0.03
		disc.height = 0.004
		disc.radial_segments = 14
		var lens := MeshInstance3D.new()
		lens.mesh = disc
		lens.material_override = paint
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder_bone.add_child(lens)
		# The disc lies flat; stand it up so that it faces forward.
		lens.transform = rest * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(side * 0.057, 1.735, 0.184))
		beacons.append(lens)

## A weapon light whose beam shows in the haze, and a red marker light on the chest.
func _fit_lamps() -> void:
	if soldier.gun == null or skeleton == null:
		return
	var at: Vector3 = soldier.flash.position + Vector3(0, -0.04, 0.16)
	lamp = SpotLight3D.new()
	lamp.position = at
	lamp.light_color = Color("dbe6ff")
	lamp.light_energy = 2.6
	lamp.spot_range = 18.0
	lamp.spot_angle = 17.0
	lamp.spot_angle_attenuation = 0.8
	lamp.shadow_enabled = false
	lamp.light_volumetric_fog_energy = 1.7
	soldier.gun.add_child(lamp)
	soldier.gun.add_child(_bead(at + Vector3(0, 0, -0.012), 0.016, Color(2.6, 2.8, 3.2)))
	# An operator is told by his eyes; the red marker is the C.R.U.'s.
	if Operator.KINDS.has(kind):
		return
	# The marker rides on the top of the spine, a hand's breadth in front of the chest.
	var spine: Array = soldier.rig.spine
	var bone: int = spine[spine.size() - 1].index
	var mount := BoneAttachment3D.new()
	mount.name = "Marker"
	skeleton.add_child(mount)
	mount.bone_idx = bone
	var rest := skeleton.get_bone_global_rest(bone)
	var reach := 1.0 / maxf(0.01, soldier.model_scale)
	var place := Node3D.new()
	place.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin + Vector3(0.09, 0.1, 0.17) * reach)
	mount.add_child(place)
	place.add_child(_bead(Vector3.ZERO, 0.02 * reach, Color(3.2, 0.25, 0.18)))
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff3a2a")
	glow.light_energy = 1.1
	glow.omni_range = 2.6 * reach
	glow.shadow_enabled = false
	glow.light_volumetric_fog_energy = 0.4
	place.add_child(glow)
	beacons.append(glow)

## A small ball that glows: a lens or a marker light.
func _bead(at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = color
	var bead := MeshInstance3D.new()
	bead.mesh = ball
	bead.material_override = paint
	bead.position = at
	bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacons.append(bead)
	return bead

## The real movement of the body picks the clip: standing, walking, running, backing off.
func animate(delta: float, _speed: float) -> void:
	busy_left = maxf(0.0, busy_left - delta)
	travel = 0.0
	var here := global_position
	var velocity := Vector3.ZERO
	if last_position != Vector3.INF and delta > 0.0:
		velocity = (here - last_position) / delta
	last_position = here
	soldier.animate(delta, Vector3.ZERO if dying else velocity, aiming and not dying, firing and not dying)

func muzzle_position() -> Vector3:
	return soldier.muzzle_position()

func head_position() -> Vector3:
	return soldier.head_position()

func pick_attack() -> String:
	return ""

func attack(_duration: float, _strike_at: float = 0.36, _clip_name: String = "") -> String:
	return ""

func pounce() -> void:
	pass

func hit(from_side: float, _strength: float = 1.0) -> void:
	soldier.hit(from_side)

func pick_flinch() -> String:
	return "flinch"

func stagger(_heavy: bool, _clip_name: String = "") -> float:
	soldier.hit(1.0 if randf() < 0.5 else -1.0)
	busy_left = 0.3
	return busy_left

func scream(_clip_name: String = "scream") -> float:
	return 0.0

## The fall that fits the shot, picked as the infected pick theirs: `forward` when hit
## from behind, `side` is where the bullet was heading across the body.
func pick_death(forward: bool, headshot: bool = false, side: float = 0.0, hard: bool = false) -> String:
	return str((InfectedVisual.DEATHS[InfectedVisual.death_pool(forward, headshot, side, hard)] as Array).pick_random())

func die(clip_name: String) -> void:
	dying = true
	state = "dead"
	soldier.fall(clip_name == "forward", clip_name)
	# The lamps go out with him.
	if lamp != null:
		lamp.hide()
	for node in beacons:
		node.hide()
	# The shield tips forward and lies where he fell.
	if shield != null:
		var drop := shield.create_tween().set_parallel(true)
		drop.tween_property(shield, "rotation:x", -PI / 2 + 0.04, 0.45).set_ease(Tween.EASE_IN)
		drop.tween_property(shield, "position", shield.position + Vector3(0.1, 0.03, -0.25), 0.45)

func dissolve() -> void:
	die("back")

func sever(_part: String) -> Node3D:
	return null
