class_name Throwable
extends RigidBody3D
## A hand grenade, a flashbang or a Molotov cocktail in flight. A grenade bounces off the
## world, and when its fuse runs out it asks the game for the blast; a bottle bursts on
## the first thing it strikes. What happens then is, in a co-op match, the host's to decide.

const KINDS := {
	"grenade": {"fuse": 2.3, "color": Color("3d4a34"), "glow": Color("ff5a3c")},
	"flashbang": {"fuse": 1.7, "color": Color("8e9496"), "glow": Color("d8f2ff")},
	# Thrown by the C.R.U. Elite: no blast, but a cloud of gas where it comes to rest.
	"gas": {"fuse": 2.0, "color": Color("5d6a3c"), "glow": Color("8dff5a")},
	# breaks: it does not bounce; the first thing it strikes ends its flight.
	"molotov": {"fuse": 5.0, "color": Color("4a3a1e"), "glow": Color("ff8a2e"), "breaks": true}
}
## Blast of the grenade: radius, damage to survivors at the centre, damage to infected.
const BLAST := [6.5, 45.0, 280.0]
## A shell from the launcher: its share of gravity and the drag of the air on it.
const SHELL_PULL := 0.548
const SHELL_DAMP := 0.074

var game: Node3D
var kind := "grenade"
var fuse := 2.3
## Thrown by the C.R.U.: meant for the survivors, and it glows so that they can see it.
var hostile := false
## Fired from the launcher: goes off at the first thing it touches, once it is armed.
var impact := false
## Factor on what its blast does to the infected (the launcher's shell, by the workbench).
var boost := 1.0
var armed_in := 0.1
## The shell's body, turned along its flight.
var shell: Node3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 16
	mass = 0.4
	linear_damp = 0.3
	angular_damp = 2.0
	continuous_cd = true
	fuse = float(KINDS[kind].fuse)
	if impact:
		# It also strikes bodies, and reports what it runs into.
		collision_mask = 1 | 4 | 16
		contact_monitor = true
		max_contacts_reported = 2
		gravity_scale = SHELL_PULL
		linear_damp = SHELL_DAMP
		lock_rotation = true
		fuse = 4.0
		body_entered.connect(func(_body: Node) -> void:
			if armed_in <= 0.0:
				fuse = 0.0)
	if KINDS[kind].get("breaks", false):
		# A body stops it as well as a wall.
		collision_mask = 1 | 4 | 16
		contact_monitor = true
		max_contacts_reported = 2
		body_entered.connect(func(_body: Node) -> void:
			if armed_in <= 0.0:
				fuse = 0.0)
	var bounce := PhysicsMaterial.new()
	bounce.bounce = 0.32
	bounce.friction = 0.95
	physics_material_override = bounce
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.07
	shape.shape = ball
	add_child(shape)
	# A small light so the thrower can follow it in the dark.
	var spark := OmniLight3D.new()
	spark.light_color = KINDS[kind].glow
	spark.light_energy = 1.6 if hostile else 0.5
	spark.omni_range = 3.2 if hostile else 1.6
	add_child(spark)
	if kind == "molotov":
		# The rag in its neck burns.
		spark.light_energy = 1.3
		spark.omni_range = 2.6
		var rag: CPUParticles3D = game.fx.rag_flame()
		rag.position.y = 0.12
		add_child(rag)
		rag.emitting = true
	if hostile and not impact:
		# One of the squad who stands near where it lands shouts a warning.
		get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_instance_valid(self) and kind != "gas":
				game.squad_call("grenade", global_position, 13.0))
	if impact:
		_build_shell(spark)
		return
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.045 if kind == "grenade" else 0.035
	mesh.height = 0.13 if kind == "grenade" else (0.22 if kind == "molotov" else 0.15)
	mesh.radial_segments = 10
	mesh.rings = 4
	body.mesh = mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = KINDS[kind].color
	paint.metallic = 0.4
	paint.roughness = 0.6
	body.material_override = paint
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)

static func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, metallic: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = metallic
	paint.roughness = 0.35
	part.material_override = paint
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

## A 40 mm shell from the launcher: a brass case, an olive body with a gold band and a
## blunt nose, pointing along its flight; a thin line of smoke and a dim glow behind it.
func _build_shell(spark: OmniLight3D) -> void:
	spark.light_color = Color(1.0, 0.72, 0.4)
	spark.light_energy = 0.9
	spark.omni_range = 2.4
	shell = Node3D.new()
	shell.name = "Shell"
	add_child(shell)
	# Built along +Y and laid down so that the nose points along the node's -Z.
	var lying := Node3D.new()
	lying.rotation.x = -PI / 2
	shell.add_child(lying)
	var case_mesh := CylinderMesh.new()
	case_mesh.top_radius = 0.033
	case_mesh.bottom_radius = 0.035
	case_mesh.height = 0.07
	case_mesh.radial_segments = 14
	_part(lying, case_mesh, Vector3(0, -0.05, 0), Color("b08a3c"), 0.9)
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.033
	body_mesh.bottom_radius = 0.033
	body_mesh.height = 0.06
	body_mesh.radial_segments = 14
	_part(lying, body_mesh, Vector3(0, 0.015, 0), Color("3c4630"), 0.3)
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.0345
	band_mesh.bottom_radius = 0.0345
	band_mesh.height = 0.012
	band_mesh.radial_segments = 14
	_part(lying, band_mesh, Vector3(0, 0.04, 0), Color("d8b24a"), 0.9)
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.011
	nose_mesh.bottom_radius = 0.033
	nose_mesh.height = 0.05
	nose_mesh.radial_segments = 14
	_part(lying, nose_mesh, Vector3(0, 0.07, 0), Color("c9a441"), 0.85)
	# The smoke it draws.
	var puff := QuadMesh.new()
	puff.size = Vector2(1.0, 1.0)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.7, 0.68, 0.64, 0.4)
	grey.albedo_texture = game.fx.puff_textures[0]
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	grey.billboard_keep_scale = true
	grey.vertex_color_use_as_albedo = true
	puff.material = grey
	var trail := CPUParticles3D.new()
	trail.mesh = puff
	trail.amount = 44
	trail.lifetime = 0.7
	trail.local_coords = false
	trail.gravity = Vector3(0, 0.3, 0)
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	trail.spread = 180.0
	trail.angle_max = 360.0
	trail.scale_amount_min = 0.09
	trail.scale_amount_max = 0.16
	var widen := Curve.new()
	widen.add_point(Vector2(0.0, 0.6))
	widen.add_point(Vector2(1.0, 2.2))
	trail.scale_amount_curve = widen
	var thin := Gradient.new()
	thin.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	trail.color_ramp = thin
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)

func _physics_process(delta: float) -> void:
	if shell != null and linear_velocity.length() > 1.0:
		var ahead := linear_velocity.normalized()
		shell.look_at(global_position + ahead, Vector3.RIGHT if absf(ahead.y) > 0.98 else Vector3.UP)
		# It spins as it flies.
		shell.rotate_object_local(Vector3.FORWARD, fuse * 30.0)
	fuse -= delta
	armed_in -= delta
	if fuse > 0.0:
		return
	if kind == "gas":
		game.gas_burst(global_position)
	elif kind == "molotov":
		game.fire_burst(global_position)
	elif kind == "grenade" and hostile:
		game.blast(global_position + Vector3(0, 0.15, 0), 6.0, 70.0, 110.0, "frag")
	elif kind == "grenade":
		game.blast(global_position + Vector3(0, 0.15, 0), BLAST[0], BLAST[1], BLAST[2] * boost)
	elif hostile:
		# Thrown at the survivors (an operator's): it blinds them, not the infected.
		game.blind(global_position + Vector3(0, 0.2, 0))
	else:
		game.flash_bang(global_position + Vector3(0, 0.2, 0))
	queue_free()
