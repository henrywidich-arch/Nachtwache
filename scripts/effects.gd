class_name CombatEffects
extends Node3D
## Short-lived combat visuals and hazards: blood and gore, impacts, tracers, explosions,
## gibs, the Striker's explosive growths and the Crusher's acid cloud.

const MAX_DECALS := 150
const GROWTH_RADIUS := 3.1
const ACID_RADIUS := 4.3
const ACID_SECONDS := 9.0
const ACID_DENSITY := 0.42
const ACID_GLOW := 1.6
const BLOOD := Color(0.26, 0.012, 0.01, 0.95)
const BLOOD_DARK := Color(0.16, 0.006, 0.006, 0.95)

var game: Node3D
var transient: Node3D
var blood_pool: Array[CPUParticles3D] = []
var mist_pool: Array[CPUParticles3D] = []
var dust_pool: Array[CPUParticles3D] = []
var tracer_pool: Array[MeshInstance3D] = []
var tracer_left: PackedFloat32Array = []
var blood_next := 0
var mist_next := 0
var dust_next := 0
var tracer_next := 0
var decals: Array[Decal] = []
var growths: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var soft_texture: GradientTexture2D
## A bright band with nothing inside and nothing outside: the shock ring of a blast.
var ring_texture: GradientTexture2D
## Torn clouds for fire and smoke: a round sprite reads as a ball, a ragged one as a blast.
var puff_textures: Array[ImageTexture] = []
var splat_textures: Array[ImageTexture] = []
var drop_mesh: SphereMesh
var mist_mesh: QuadMesh
var gib_mesh: SphereMesh
var gib_materials: Array[StandardMaterial3D] = []
var growth_mesh: SphereMesh
var acid_tick := 0.0
var splat_sound_left := 0.0
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.seed = 9041
	transient = Node3D.new()
	transient.name = "Transient"
	add_child(transient)
	soft_texture = _radial(Color.WHITE, Color(1, 1, 1, 0))
	for variant in range(3):
		puff_textures.append(_puff_texture(variant))
	for variant in range(5):
		splat_textures.append(_splat_texture(variant))
	# Godot packs the textures of all decals in use into one atlas and rebuilds it whenever
	# a texture comes or goes, which stalls the game for a moment. One hidden decal per
	# texture, far below the map, keeps the atlas the same for the whole session.
	var marks: Array = [soft_texture]
	marks.append_array(splat_textures)
	for texture in marks:
		var anchor := Decal.new()
		anchor.texture_albedo = texture
		anchor.size = Vector3(0.1, 0.1, 0.1)
		anchor.position = Vector3(0, -60, 0)
		add_child(anchor)
	gib_mesh = SphereMesh.new()
	gib_mesh.radius = 0.5
	gib_mesh.height = 1.0
	gib_mesh.radial_segments = 7
	gib_mesh.rings = 4
	for color in [Color("4a0d0b"), Color("6b2f28"), Color("2e0807"), Color("7a1512"), Color("5a4a40")]:
		var flesh := StandardMaterial3D.new()
		flesh.albedo_color = color
		flesh.roughness = 0.35
		gib_materials.append(flesh)
	growth_mesh = SphereMesh.new()
	growth_mesh.radius = 0.15
	growth_mesh.height = 0.3
	growth_mesh.radial_segments = 12
	growth_mesh.rings = 6
	drop_mesh = SphereMesh.new()
	drop_mesh.radius = 0.5
	drop_mesh.height = 1.0
	drop_mesh.radial_segments = 5
	drop_mesh.rings = 3
	var blood_material := StandardMaterial3D.new()
	blood_material.albedo_color = Color("7a0c0a")
	blood_material.roughness = 0.3
	blood_material.emission_enabled = true
	blood_material.emission = Color("3a0504")
	drop_mesh.material = blood_material
	for i in range(12):
		blood_pool.append(_burst(drop_mesh, 30, 0.6, Vector3(0, -11, 0), 1.8, 5.6, 0.014, 0.045, 48.0))
	# A fine red haze hangs in the air for a moment where a bullet went through.
	mist_mesh = QuadMesh.new()
	mist_mesh.size = Vector2(1.0, 1.0)
	var mist_material := StandardMaterial3D.new()
	mist_material.albedo_color = Color(0.5, 0.02, 0.02, 0.55)
	mist_material.albedo_texture = soft_texture
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mist_material.vertex_color_use_as_albedo = true
	mist_mesh.material = mist_material
	for i in range(8):
		var mist := _burst(mist_mesh, 5, 0.55, Vector3(0, -0.6, 0), 0.3, 1.3, 0.22, 0.5, 70.0)
		mist.color_ramp = _fade()
		mist_pool.append(mist)
	var puff := QuadMesh.new()
	puff.size = Vector2(0.22, 0.22)
	var puff_material := StandardMaterial3D.new()
	puff_material.albedo_color = Color(0.55, 0.52, 0.47, 0.55)
	puff_material.albedo_texture = soft_texture
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_material.vertex_color_use_as_albedo = true
	puff.material = puff_material
	for i in range(8):
		var dust := _burst(puff, 7, 0.55, Vector3(0, 0.4, 0), 0.4, 1.5, 0.6, 1.3, 50.0)
		dust.color_ramp = _fade()
		dust_pool.append(dust)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.012, 0.012, 1.0)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.albedo_color = Color(1.0, 0.86, 0.55)
	streak_material.emission_enabled = true
	streak_material.emission = Color(1.0, 0.8, 0.45)
	streak_material.emission_energy_multiplier = 2.5
	streak.material = streak_material
	for i in range(20):
		var tracer := MeshInstance3D.new()
		tracer.mesh = streak
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracer.hide()
		add_child(tracer)
		tracer_pool.append(tracer)
		tracer_left.append(0.0)

func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([inner, outer])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture

func _fade() -> Gradient:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	return ramp

## A cloud with a ragged edge and darker pockets inside, for fire and smoke.
func _puff_texture(variant: int) -> ImageTexture:
	var size := 96
	var noise := FastNoiseLite.new()
	noise.seed = 4711 + variant * 97
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.034
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var away := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var lump := clampf(noise.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
			# Where the noise is low the edge is eaten away.
			var cover := clampf((1.0 - away - (1.0 - lump) * 0.55) * 3.2, 0.0, 1.0)
			var shade := 0.7 + 0.3 * lump
			image.set_pixel(x, y, Color(shade, shade, shade, cover * cover * (3.0 - 2.0 * cover)))
	return ImageTexture.create_from_image(image)

## A blood splat as an alpha mask: one ragged pool, satellites flung outward and thin
## streaks. Later variants are more scattered.
func _splat_texture(variant: int) -> ImageTexture:
	var size := 128
	var mask := PackedFloat32Array()
	mask.resize(size * size)
	var blobs: Array = []
	var core := 0.2 - variant * 0.02
	for i in range(7):
		blobs.append([Vector2(0.5, 0.5) + Vector2.from_angle(random.randf() * TAU) * random.randf_range(0.0, 0.1), random.randf_range(core * 0.6, core)])
	for i in range(16 + variant * 9):
		var angle := random.randf() * TAU
		var reach := random.randf_range(0.14, 0.46)
		blobs.append([Vector2(0.5, 0.5) + Vector2.from_angle(angle) * reach, random.randf_range(0.008, 0.05) * (1.15 - reach)])
		if random.randf() < 0.45:
			# A streak: a row of shrinking drops pointing away from the centre.
			for step in range(1, 6):
				blobs.append([Vector2(0.5, 0.5) + Vector2.from_angle(angle) * minf(0.48, reach + step * 0.022), 0.014 - step * 0.002])
	for blob in blobs:
		var centre: Vector2 = (blob[0] as Vector2) * size
		var radius: float = maxf(1.0, float(blob[1]) * size)
		for y in range(maxi(0, int(centre.y - radius - 1)), mini(size, int(centre.y + radius + 2))):
			for x in range(maxi(0, int(centre.x - radius - 1)), mini(size, int(centre.x + radius + 2))):
				var gap := Vector2(x + 0.5, y + 0.5).distance_to(centre)
				var cover := clampf((radius - gap) / maxf(1.0, radius * 0.3) + 0.5, 0.0, 1.0)
				mask[y * size + x] = maxf(mask[y * size + x], cover)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			image.set_pixel(x, y, Color(1, 1, 1, mask[y * size + x]))
	return ImageTexture.create_from_image(image)

func _burst(mesh: Mesh, amount: int, lifetime: float, gravity: Vector3, slow: float, fast: float, small: float, large: float, spread: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.mesh = mesh
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.emitting = false
	emitter.gravity = gravity
	emitter.spread = spread
	emitter.initial_velocity_min = slow
	emitter.initial_velocity_max = fast
	emitter.scale_amount_min = small
	emitter.scale_amount_max = large
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	return emitter

func clear() -> void:
	for child in transient.get_children():
		transient.remove_child(child)
		child.queue_free()
	decals.clear()
	growths.clear()
	clouds.clear()
	for tracer in tracer_pool:
		tracer.hide()

## A knot of black smoke where the Stalker stood a moment ago.
func vanish(center: Vector3) -> void:
	var cloud_mesh := QuadMesh.new()
	cloud_mesh.size = Vector2(1.0, 1.0)
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.02, 0.02, 0.03, 0.85)
	cloud_material.albedo_texture = soft_texture
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cloud_material.vertex_color_use_as_albedo = true
	cloud_mesh.material = cloud_material
	var smoke := _one_shot(cloud_mesh, 18, 1.0, Vector3(0, 0.7, 0), 0.3, 1.7, 0.8, 1.9, 180.0)
	smoke.color_ramp = _fade()
	smoke.global_position = center

## Shows one of every effect at `center`. Called once at start behind a black curtain.
func warm_up(center: Vector3) -> void:
	for style in ["growth", "charger", "blast"]:
		explosion(center, 2.0, style)
	charger_burst(center)
	drop_growths(center, 1, true)
	acid_cloud(center, true)
	blood(center + Vector3.UP, Vector3.FORWARD, true)
	blood(center + Vector3.UP, Vector3.FORWARD)
	blood_pool_at(center, 1.0)
	dust(center, Vector3.UP)
	tracer(center, center + Vector3(1, 1, 0))
	chunks(center, 3, 0.5)
	spent_shell(center + Vector3.UP, Vector3.UP)
	vanish(center)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))

## The floor below a point, or the point dropped to ground level if there is none.
func floor_below(point: Vector3, reach: float = 4.0) -> Vector3:
	var hit := _ray(point + Vector3.UP * 0.1, point + Vector3.DOWN * reach)
	return hit.position if not hit.is_empty() else Vector3(point.x, 0.0, point.z)

# ---------------------------------------------------------------- small hits

## A bullet goes through flesh: spray back towards the shooter, a red haze, and blood on
## the floor and on whatever stands behind the body.
func blood(point: Vector3, shot_direction: Vector3, heavy: bool = false) -> void:
	var emitter := blood_pool[blood_next]
	blood_next = (blood_next + 1) % blood_pool.size()
	emitter.global_position = point
	emitter.direction = (-shot_direction + Vector3.UP * 0.5).normalized()
	emitter.amount = 46 if heavy else 26
	emitter.restart()
	emitter.emitting = true
	var mist := mist_pool[mist_next]
	mist_next = (mist_next + 1) % mist_pool.size()
	mist.global_position = point
	mist.direction = shot_direction
	mist.restart()
	mist.emitting = true
	if heavy or random.randf() < 0.55:
		var floor_hit := _ray(point, point + Vector3.DOWN * 2.6 + shot_direction * 0.9)
		if not floor_hit.is_empty():
			decal(floor_hit.position, random.randf_range(0.35, 0.7) * (1.5 if heavy else 1.0), BLOOD, floor_hit.normal)
	if heavy or random.randf() < 0.5:
		# The exit spray lands on the wall behind.
		var wall_hit := _ray(point, point + shot_direction * 3.6 + Vector3.DOWN * 0.3)
		if not wall_hit.is_empty():
			decal(wall_hit.position, random.randf_range(0.45, 0.95) * (1.4 if heavy else 1.0), BLOOD, wall_hit.normal)

func dust(point: Vector3, normal: Vector3) -> void:
	var emitter := dust_pool[dust_next]
	dust_next = (dust_next + 1) % dust_pool.size()
	emitter.global_position = point + normal * 0.05
	emitter.direction = normal
	emitter.restart()
	emitter.emitting = true

func tracer(from: Vector3, to: Vector3) -> void:
	var span := to - from
	if span.length() < 1.5:
		return
	var line := tracer_pool[tracer_next]
	tracer_left[tracer_next] = 0.045
	tracer_next = (tracer_next + 1) % tracer_pool.size()
	# Only the far two thirds are drawn so the streak never sits inside the weapon.
	var start := from + span * 0.3
	var visible_span := to - start
	line.global_transform = Transform3D(Basis.looking_at(visible_span.normalized(), Vector3.UP if absf(visible_span.normalized().y) < 0.95 else Vector3.RIGHT), (start + to) * 0.5)
	line.scale = Vector3(1, 1, visible_span.length())
	line.show()

## Projects a splat onto the surface at `point`; `normal` is that surface's normal.
func decal(point: Vector3, size: float, color: Color, normal: Vector3 = Vector3.UP, soft: bool = false) -> Decal:
	var mark := Decal.new()
	mark.texture_albedo = soft_texture if soft else splat_textures[random.randi() % splat_textures.size()]
	mark.modulate = color
	mark.size = Vector3(size, 0.5, size * random.randf_range(0.75, 1.2))
	mark.cull_mask = 1
	mark.normal_fade = 0.35
	mark.upper_fade = 0.02
	mark.lower_fade = 0.02
	transient.add_child(mark)
	var up := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var spin := Basis(up, random.randf() * TAU)
	var tilt := Basis.IDENTITY
	if up.dot(Vector3.UP) < -0.999:
		tilt = Basis(Vector3.RIGHT, PI)
	elif up.dot(Vector3.UP) < 0.999:
		tilt = Basis(Quaternion(Vector3.UP, up))
	mark.global_transform = Transform3D(spin * tilt, point + up * 0.08)
	decals.append(mark)
	if decals.size() > MAX_DECALS:
		var oldest: Decal = decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	return mark

## A pool that slowly spreads under a body.
func blood_pool_at(point: Vector3, size: float) -> void:
	var ground := floor_below(point + Vector3.UP * 0.5)
	var pool := decal(ground, size, BLOOD_DARK)
	var full := pool.size
	pool.size = Vector3(full.x * 0.25, full.y, full.z * 0.25)
	pool.create_tween().tween_property(pool, "size", full, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _splat_sound(at: Vector3, kind: String = "splat") -> void:
	if splat_sound_left <= 0.0:
		splat_sound_left = 0.12
		game.sounds.play_at(kind, at)

# ---------------------------------------------------------------- deaths

## Blood for a kill. A headshot can take the head clean off; a hit far stronger than
## needed tears off an arm as well.
func death(enemy: Infected, headshot: bool, direction: Vector3, overkill: bool) -> void:
	var model := enemy.model
	var chest := enemy.global_position + Vector3(0, float(enemy.spec.height) * 0.6, 0)
	blood(model.head_position() if headshot else chest, direction, true)
	# Hounds have no arms to lose, and the soldiers' bodies stay in one piece.
	var two_legged := not (model is RipperVisual) and not (model is CruVisual)
	if two_legged and headshot and (overkill or random.randf() < 0.5):
		var neck := model.sever("head")
		_spurt(neck)
		chunks(neck.global_position, 5, 0.45, direction * 2.5 + Vector3.UP * 2.0)
		game.sounds.play_at("headpop", neck.global_position)
	if two_legged and overkill:
		_spurt(model.sever("arm0" if random.randf() < 0.5 else "arm1"))
		chunks(chest, 7, 0.7, direction * 3.0 + Vector3.UP * 1.5)
		for i in range(3):
			var at := floor_below(chest + Vector3(random.randf_range(-1.2, 1.2), 0, random.randf_range(-1.2, 1.2)) + direction * 0.8)
			decal(at, random.randf_range(0.6, 1.2), BLOOD)
	# The body hits the floor a moment later and starts to bleed out.
	var timer := enemy.create_tween()
	timer.tween_interval(0.85)
	timer.tween_callback(_body_landed.bind(enemy))

func _body_landed(enemy: Infected) -> void:
	if not is_instance_valid(enemy):
		return
	var at := enemy.model.head_position()
	at = at.lerp(enemy.global_position, 0.45)
	game.sounds.play_at("bodyfall", at)
	blood_pool_at(at, random.randf_range(1.0, 1.7))

## Blood pumping from a stump for a second or two; it follows the falling body.
func _spurt(stump: Node3D) -> void:
	var jet := CPUParticles3D.new()
	jet.mesh = drop_mesh
	jet.amount = 46
	jet.lifetime = 0.7
	jet.explosiveness = 0.0
	jet.randomness = 0.6
	jet.local_coords = false
	jet.direction = Vector3.UP
	jet.spread = 24.0
	jet.gravity = Vector3(0, -11, 0)
	jet.initial_velocity_min = 2.2
	jet.initial_velocity_max = 4.6
	jet.scale_amount_min = 0.014
	jet.scale_amount_max = 0.04
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stump.add_child(jet)
	var life := jet.create_tween()
	life.tween_interval(1.3)
	life.tween_callback(func() -> void: jet.emitting = false)
	life.tween_interval(0.9)
	life.tween_callback(jet.queue_free)
	decal(floor_below(stump.global_position), random.randf_range(0.7, 1.1), BLOOD)

## A spent shotgun shell flips out of the ejection port and rolls away.
func spent_shell(at: Vector3, velocity: Vector3) -> void:
	var shell := RigidBody3D.new()
	shell.collision_layer = 0
	shell.collision_mask = 1
	shell.mass = 0.05
	var shape := CollisionShape3D.new()
	var tube := CylinderShape3D.new()
	tube.radius = 0.011
	tube.height = 0.065
	shape.shape = tube
	shell.add_child(shape)
	for part in [[0.011, 0.05, Color("9e1614"), 0.008], [0.0115, 0.015, Color("c9a04e"), -0.025]]:
		var piece := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[0]
		mesh.height = part[1]
		mesh.radial_segments = 10
		mesh.rings = 1
		var paint := StandardMaterial3D.new()
		paint.albedo_color = part[2]
		paint.metallic = 1.0 if part[3] < 0.0 else 0.0
		paint.roughness = 0.4
		mesh.material = paint
		piece.mesh = mesh
		piece.position.y = part[3]
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.add_child(piece)
	transient.add_child(shell)
	shell.global_position = at
	shell.linear_velocity = velocity
	shell.angular_velocity = Vector3(random.randf_range(-20, 20), random.randf_range(-6, 6), random.randf_range(-20, 20))
	var life := shell.create_tween()
	life.tween_interval(5.0)
	life.tween_callback(shell.queue_free)

## Bits of flesh and bone that fly off, bounce and leave a mark where they come to rest.
func chunks(center: Vector3, count: int, spread: float, push: Vector3 = Vector3.ZERO) -> void:
	for i in range(count):
		var chunk := RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = 1
		chunk.mass = 0.6
		var bounce := PhysicsMaterial.new()
		bounce.bounce = 0.2
		bounce.friction = 0.9
		chunk.physics_material_override = bounce
		var shape := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.06
		shape.shape = ball
		chunk.add_child(shape)
		var piece := MeshInstance3D.new()
		piece.mesh = gib_mesh
		piece.material_override = gib_materials[random.randi() % gib_materials.size()]
		# Mostly small scraps, now and then a long strip or a heavy lump.
		var bulk := random.randf_range(0.06, 0.16) * (1.9 if random.randf() < 0.18 else 1.0)
		piece.scale = Vector3(bulk, bulk * random.randf_range(0.4, 0.8), bulk * random.randf_range(0.7, 2.4))
		chunk.add_child(piece)
		transient.add_child(chunk)
		var direction := Vector3(random.randf_range(-1, 1), random.randf_range(0.2, 1.1), random.randf_range(-1, 1)).normalized()
		chunk.global_position = center + direction * 0.25 * spread
		chunk.linear_velocity = direction * random.randf_range(2.5, 8.5) * spread + push
		chunk.angular_velocity = Vector3(random.randf_range(-9, 9), random.randf_range(-9, 9), random.randf_range(-9, 9))
		var life := chunk.create_tween()
		life.tween_interval(random.randf_range(0.5, 1.0))
		life.tween_callback(_chunk_landed.bind(chunk, i < 3))
		life.tween_interval(random.randf_range(5.0, 7.0))
		life.tween_property(piece, "scale", Vector3.ZERO, 0.4)
		life.tween_callback(chunk.queue_free)

func _chunk_landed(chunk: RigidBody3D, audible: bool) -> void:
	var hit := _ray(chunk.global_position + Vector3.UP * 0.1, chunk.global_position + Vector3.DOWN * 0.6)
	if not hit.is_empty():
		decal(hit.position, random.randf_range(0.2, 0.42), BLOOD, hit.normal)
		if audible:
			_splat_sound(hit.position, "gib")

# ---------------------------------------------------------------- explosions

func explosion(center: Vector3, radius: float, style: String) -> void:
	var tint := Color(1.0, 0.62, 0.25)
	var smoke_tint := Color(0.2, 0.19, 0.18, 0.7)
	if style == "growth":
		tint = Color(1.0, 0.93, 0.55)
		smoke_tint = Color(0.5, 0.52, 0.25, 0.55)
	elif style == "charger":
		tint = Color(1.0, 0.45, 0.2)
		smoke_tint = Color(0.28, 0.1, 0.09, 0.7)
	elif style in ["blast", "frag"]:
		_detonation(center, radius)
		return
	var flash := OmniLight3D.new()
	flash.light_color = tint
	flash.light_energy = 6.0
	flash.omni_range = radius * 2.2
	flash.light_volumetric_fog_energy = 0.35
	transient.add_child(flash)
	flash.global_position = center
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.26)
	fade.tween_callback(flash.queue_free)
	# A soft additive sprite reads as a fireball without any hard silhouette.
	var ball := MeshInstance3D.new()
	var sprite := QuadMesh.new()
	sprite.size = Vector2(2.0, 2.0)
	ball.mesh = sprite
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire.billboard_keep_scale = true
	fire.albedo_texture = soft_texture
	fire.albedo_color = Color(tint.r * 1.9, tint.g * 1.5, tint.b * 1.2, 0.95)
	ball.material_override = fire
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	transient.add_child(ball)
	ball.global_position = center
	ball.scale = Vector3.ONE * 0.4
	var swell := ball.create_tween()
	swell.set_parallel(true)
	swell.tween_property(ball, "scale", Vector3.ONE * radius * 0.8, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	swell.tween_property(fire, "albedo_color:a", 0.0, 0.24)
	swell.chain().tween_callback(ball.queue_free)
	var ember_mesh := QuadMesh.new()
	ember_mesh.size = Vector2(1.0, 1.0)
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	ember_material.vertex_color_use_as_albedo = true
	ember_material.albedo_texture = soft_texture
	ember_material.albedo_color = Color(tint.r * 1.5, tint.g * 1.1, tint.b * 0.8, 0.8)
	ember_mesh.material = ember_material
	var embers := _one_shot(ember_mesh, 12, 0.42, Vector3(0, 1.6, 0), 1.5, 5.5, radius * 0.22, radius * 0.48, 180.0)
	embers.color_ramp = _fade()
	embers.global_position = center
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.5
	spark_mesh.height = 1.0
	spark_mesh.radial_segments = 4
	spark_mesh.rings = 2
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(tint.r * 2.0, tint.g * 1.6, tint.b)
	spark_mesh.material = spark_material
	var sparks := _one_shot(spark_mesh, 30, 0.7, Vector3(0, -13, 0), 4.0, 11.0, 0.03, 0.07, 180.0)
	sparks.global_position = center
	var cloud_mesh := QuadMesh.new()
	cloud_mesh.size = Vector2(1.0, 1.0)
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = smoke_tint
	cloud_material.albedo_texture = soft_texture
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cloud_material.vertex_color_use_as_albedo = true
	cloud_mesh.material = cloud_material
	var smoke := _one_shot(cloud_mesh, 14, 1.9, Vector3(0, 0.9, 0), 0.5, 2.4, radius * 0.35, radius * 0.7, 180.0)
	smoke.color_ramp = _fade()
	smoke.global_position = center
	decal(floor_below(center), radius * 0.9, Color(0.02, 0.02, 0.02, 0.8), Vector3.UP, true)

## A glowing sprite that always faces the viewer.
func _glow_sprite(texture: Texture2D, color: Color, flat: bool = false) -> MeshInstance3D:
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	sprite.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_texture = texture
	paint.albedo_color = color
	if not flat:
		paint.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		paint.billboard_keep_scale = true
	sprite.material_override = paint
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	transient.add_child(sprite)
	return sprite

## Torn clouds thrown out at once: fire (added to the picture, so it glows) or smoke.
func _cloud_burst(glowing: bool, amount: int, lifetime: float, gravity: Vector3, slow: float, fast: float, small: float, large: float, brake: float) -> CPUParticles3D:
	var sheet := QuadMesh.new()
	sheet.size = Vector2(1.0, 1.0)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_texture = puff_textures[random.randi() % puff_textures.size()]
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glowing:
		paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this every particle is drawn at the size of the mesh, whatever its own scale.
	paint.billboard_keep_scale = true
	paint.vertex_color_use_as_albedo = true
	sheet.material = paint
	var clouds := _one_shot(sheet, amount, lifetime, gravity, slow, fast, small, large, 180.0)
	clouds.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	clouds.emission_sphere_radius = small * 0.35
	clouds.lifetime_randomness = 0.35
	clouds.damping_min = brake
	clouds.damping_max = brake * 1.6
	clouds.angle_min = 0.0
	clouds.angle_max = 360.0
	clouds.angular_velocity_min = -70.0
	clouds.angular_velocity_max = 70.0
	# Every cloud swells as it burns out.
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.35))
	swell.add_point(Vector2(0.22, 0.85))
	swell.add_point(Vector2(1.0, 1.3))
	clouds.scale_amount_curve = swell
	return clouds

## The blast of a grenade or of a shell from the launcher: a white flash, torn fire that
## boils up and turns into black smoke, sparks thrown far, earth and stones, a ring that
## races over the ground, a patch that keeps glowing and a burnt mark that stays.
func _detonation(center: Vector3, radius: float) -> void:
	var ground := floor_below(center)
	var size := radius / 6.5
	if ring_texture == null:
		var band := Gradient.new()
		band.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		band.offsets = PackedFloat32Array([0.0, 0.7, 0.9, 1.0])
		ring_texture = GradientTexture2D.new()
		ring_texture.gradient = band
		ring_texture.fill = GradientTexture2D.FILL_RADIAL
		ring_texture.fill_from = Vector2(0.5, 0.5)
		ring_texture.fill_to = Vector2(0.5, 0.0)
		ring_texture.width = 128
		ring_texture.height = 128
	# The light: blinding for a moment, then the glow of what still burns.
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.56)
	flash.light_energy = 16.0
	flash.omni_range = radius * 2.6
	flash.light_volumetric_fog_energy = 0.6
	transient.add_child(flash)
	flash.global_position = center + Vector3(0, 0.5, 0)
	var dim := flash.create_tween()
	dim.tween_property(flash, "light_energy", 2.4, 0.12)
	dim.parallel().tween_property(flash, "light_color", Color(1.0, 0.45, 0.16), 0.3)
	dim.tween_property(flash, "light_energy", 0.0, 1.0).set_ease(Tween.EASE_IN)
	dim.tween_callback(flash.queue_free)
	# The core: white, and over in a tenth of a second.
	var core := _glow_sprite(soft_texture, Color(4.0, 3.6, 2.8, 1.0))
	core.global_position = center
	core.scale = Vector3.ONE * 0.9 * size
	var burn := core.create_tween().set_parallel(true)
	burn.tween_property(core, "scale", Vector3.ONE * 2.1 * size, 0.07).set_ease(Tween.EASE_OUT)
	burn.tween_property(core.material_override, "albedo_color:a", 0.0, 0.11)
	burn.chain().tween_callback(core.queue_free)
	# Fire: torn clouds that shoot out, brake hard and boil upwards.
	var heat := Gradient.new()
	heat.offsets = PackedFloat32Array([0.0, 0.1, 0.36, 0.7, 1.0])
	# Dim enough that thirty clouds on top of each other burn orange, not white.
	heat.colors = PackedColorArray([Color(1.5, 1.1, 0.55, 1.0), Color(1.3, 0.55, 0.1, 1.0), Color(0.8, 0.18, 0.03, 0.9), Color(0.22, 0.05, 0.015, 0.5), Color(0.03, 0.012, 0.006, 0.0)])
	var fire := _cloud_burst(true, 30, 0.8, Vector3(0, 2.6, 0), 2.0 * size, 7.0 * size, 1.1 * size, 2.3 * size, 9.0)
	fire.color_ramp = heat
	fire.global_position = center + Vector3(0, 0.2, 0)
	# A ball of flame that stays where it went off.
	var heart := _cloud_burst(true, 10, 0.6, Vector3(0, 1.8, 0), 0.4 * size, 2.0 * size, 1.6 * size, 2.6 * size, 5.0)
	heart.color_ramp = heat
	heart.global_position = center + Vector3(0, 0.5, 0)
	# Smoke: comes out of the fire, black at first, and stands over the place.
	var smoke := _cloud_burst(false, 20, 3.6, Vector3(0, 1.1, 0), 0.8 * size, 3.6 * size, 1.3 * size, 2.6 * size, 1.4)
	var soot := Gradient.new()
	soot.offsets = PackedFloat32Array([0.0, 0.1, 0.5, 1.0])
	soot.colors = PackedColorArray([Color(0.06, 0.05, 0.045, 0.0), Color(0.07, 0.065, 0.06, 0.9), Color(0.17, 0.165, 0.16, 0.6), Color(0.3, 0.3, 0.3, 0.0)])
	smoke.color_ramp = soot
	smoke.global_position = center + Vector3(0, 0.5, 0)
	# Sparks: thin glowing streaks that fly far and fall.
	var streak := BoxMesh.new()
	streak.size = Vector3(0.018, 0.34, 0.018)
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.vertex_color_use_as_albedo = true
	hot.albedo_color = Color(3.2, 2.0, 0.8)
	streak.material = hot
	var sparks := _one_shot(streak, 48, 0.7, Vector3(0, -16, 0), 8.0 * sqrt(size), 23.0 * sqrt(size), 0.6, 1.3, 115.0)
	sparks.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	sparks.lifetime_randomness = 0.5
	var thin := Curve.new()
	thin.add_point(Vector2(0.0, 1.0))
	thin.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = thin
	sparks.global_position = center + Vector3(0, 0.15, 0)
	# Embers that drift up after it.
	var mote := QuadMesh.new()
	mote.size = Vector2(1.0, 1.0)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	glow.billboard_keep_scale = true
	glow.vertex_color_use_as_albedo = true
	glow.albedo_texture = soft_texture
	glow.albedo_color = Color(3.0, 1.4, 0.45, 0.95)
	mote.material = glow
	var embers := _one_shot(mote, 26, 2.2, Vector3(0, 1.1, 0), 0.8, 4.2, 0.05, 0.12, 180.0)
	embers.color_ramp = _fade()
	embers.lifetime_randomness = 0.5
	embers.global_position = center + Vector3(0, 0.6, 0)
	# Earth and stones go up and rain down again.
	var clod := SphereMesh.new()
	clod.radius = 0.5
	clod.height = 1.0
	clod.radial_segments = 5
	clod.rings = 3
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.11, 0.085, 0.06)
	soil.roughness = 1.0
	clod.material = soil
	var earth := _one_shot(clod, 40, 1.3, Vector3(0, -15, 0), 5.0, 13.0, 0.035, 0.14, 58.0)
	earth.global_position = ground + Vector3(0, 0.15, 0)
	# Dust that is driven low over the ground.
	var dust := _cloud_burst(false, 16, 1.5, Vector3(0, 0.3, 0), 4.0 * size, 9.0 * size, 1.0 * size, 2.0 * size, 4.5)
	var dirt := Gradient.new()
	dirt.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	dirt.colors = PackedColorArray([Color(0.3, 0.26, 0.21, 0.0), Color(0.3, 0.26, 0.21, 0.5), Color(0.34, 0.31, 0.27, 0.0)])
	dust.color_ramp = dirt
	dust.flatness = 0.92
	dust.global_position = ground + Vector3(0, 0.35, 0)
	# The shock runs over the ground as a thin ring.
	var ring := _glow_sprite(ring_texture, Color(1.5, 1.25, 1.0, 0.55), true)
	ring.global_position = ground + Vector3(0, 0.07, 0)
	ring.rotation.x = -PI / 2
	ring.scale = Vector3.ONE * 0.4
	var wave := ring.create_tween().set_parallel(true)
	wave.tween_property(ring, "scale", Vector3.ONE * radius * 1.15, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	wave.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.28)
	wave.chain().tween_callback(ring.queue_free)
	# The ground keeps glowing where it went off, and stays burnt.
	var crater := _glow_sprite(soft_texture, Color(1.7, 0.5, 0.12, 0.75), true)
	crater.global_position = ground + Vector3(0, 0.05, 0)
	crater.rotation.x = -PI / 2
	crater.scale = Vector3.ONE * radius * 0.26
	var cool := crater.create_tween()
	cool.tween_property(crater.material_override, "albedo_color:a", 0.0, 1.8).set_ease(Tween.EASE_IN)
	cool.tween_callback(crater.queue_free)
	decal(ground, radius * 0.9, Color(0.02, 0.02, 0.02, 0.8), Vector3.UP, true)
	decal(ground, radius * 0.5, Color(0.012, 0.01, 0.01, 0.92))

## The line a grenade would fly, as a row of dots, and a ring where it would strike.
var arc_dots: MultiMeshInstance3D
var arc_ring: MeshInstance3D

func show_arc(points: PackedVector3Array) -> void:
	if arc_dots == null:
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = Color(1.0, 0.78, 0.3, 0.85)
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var dot := SphereMesh.new()
		dot.radius = 0.035
		dot.height = 0.07
		dot.radial_segments = 6
		dot.rings = 3
		dot.material = paint
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.mesh = dot
		many.instance_count = 64
		arc_dots = MultiMeshInstance3D.new()
		arc_dots.multimesh = many
		arc_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arc_dots)
		var band := TorusMesh.new()
		band.inner_radius = 0.42
		band.outer_radius = 0.5
		band.rings = 28
		band.ring_segments = 4
		band.material = paint
		arc_ring = MeshInstance3D.new()
		arc_ring.mesh = band
		arc_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arc_ring)
	var shown := mini(points.size(), arc_dots.multimesh.instance_count)
	arc_dots.multimesh.visible_instance_count = shown
	for i in range(shown):
		arc_dots.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
	arc_dots.show()
	arc_ring.visible = shown > 1
	if shown > 1:
		arc_ring.global_position = points[shown - 1] + Vector3(0, 0.04, 0)

func hide_arc() -> void:
	if arc_dots != null and arc_dots.visible:
		arc_dots.hide()
		arc_ring.hide()

## The puff of smoke a launcher leaves at its muzzle.
func launch_smoke(at: Vector3, along: Vector3) -> void:
	var puff := _cloud_burst(false, 9, 0.7, Vector3(0, 0.5, 0), 0.6, 3.2, 0.12, 0.3, 5.0)
	var grey := Gradient.new()
	grey.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grey.colors = PackedColorArray([Color(0.7, 0.68, 0.64, 0.0), Color(0.62, 0.6, 0.56, 0.55), Color(0.5, 0.5, 0.5, 0.0)])
	puff.color_ramp = grey
	puff.direction = along
	puff.spread = 24.0
	puff.global_position = at

func _one_shot(mesh: Mesh, amount: int, lifetime: float, gravity: Vector3, slow: float, fast: float, small: float, large: float, spread: float) -> CPUParticles3D:
	var emitter := _burst(mesh, amount, lifetime, gravity, slow, fast, small, large, spread)
	remove_child(emitter)
	transient.add_child(emitter)
	emitter.direction = Vector3.UP
	# Not at once: an emitter throws its particles out the moment it is switched on, and the
	# caller has yet to put it in its place. At the end of the frame it is where it belongs.
	emitter.set_deferred("emitting", true)
	var cleanup := emitter.create_tween()
	cleanup.tween_interval(lifetime + 0.3)
	cleanup.tween_callback(emitter.queue_free)
	return emitter

## The Charger goes off like a sack of offal: chunks in every direction, a red cloud, and
## blood across the floor, the walls and the ceiling around the blast.
func charger_burst(center: Vector3) -> void:
	chunks(center, 34, 1.0)
	chunks(center + Vector3.UP * 0.3, 8, 1.6)
	var spray := _one_shot(drop_mesh, 170, 1.1, Vector3(0, -10, 0), 3.0, 10.5, 0.03, 0.1, 180.0)
	spray.global_position = center
	var globs := _one_shot(drop_mesh, 46, 1.5, Vector3(0, -8, 0), 1.5, 5.5, 0.07, 0.17, 180.0)
	globs.global_position = center
	var cloud := _one_shot(mist_mesh, 22, 1.5, Vector3(0, -0.4, 0), 1.0, 4.5, 1.2, 2.6, 180.0)
	cloud.color_ramp = _fade()
	cloud.global_position = center
	var ground := floor_below(center)
	decal(ground, 3.6, BLOOD_DARK)
	decal(ground, 2.4, BLOOD)
	for i in range(14):
		var reach := random.randf_range(0.9, 4.6)
		var around := random.randf() * TAU
		decal(floor_below(center + Vector3(cos(around), 0, sin(around)) * reach), random.randf_range(0.5, 1.5), BLOOD)
	# Whatever stands around the blast gets painted.
	for i in range(12):
		var angle := TAU * i / 12.0 + random.randf_range(-0.2, 0.2)
		var out := Vector3(cos(angle), random.randf_range(-0.15, 0.45), sin(angle)).normalized()
		var hit := _ray(center, center + out * 5.5)
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7:
			decal(hit.position, random.randf_range(0.9, 1.9), BLOOD, hit.normal)
			# It runs down the wall.
			var drip := decal((hit.position as Vector3) + Vector3.DOWN * random.randf_range(0.4, 0.8), random.randf_range(0.35, 0.6), BLOOD_DARK, hit.normal)
			drip.size.z *= 2.4
			var out_of_wall: Vector3 = hit.normal
			drip.global_basis = Basis(out_of_wall.cross(Vector3.DOWN), out_of_wall, Vector3.DOWN).orthonormalized()
	var above := _ray(center, center + Vector3.UP * 3.6)
	if not above.is_empty():
		decal(above.position, random.randf_range(1.6, 2.4), BLOOD, above.normal)
	game.sounds.play_at("gore_burst", center)
	var gap: float = game.player.global_position.distance_to(center)
	if gap < 7.0:
		game.hud.splatter(1.0 - gap / 7.0)

# ---------------------------------------------------------------- striker growths

## Explosive growths roll free of a Striker and burst a moment later. `cosmetic` ones
## only look the part: the host of a co-op match decides when and where they go off.
func drop_growths(center: Vector3, count: int, cosmetic: bool = false) -> void:
	for i in range(count):
		var orb := RigidBody3D.new()
		orb.collision_layer = 0
		orb.collision_mask = 1
		orb.mass = 0.8
		orb.linear_damp = 0.6
		orb.angular_damp = 1.2
		var shape := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.15
		shape.shape = ball
		orb.add_child(shape)
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color("c98a86")
		skin.roughness = 0.35
		skin.emission_enabled = true
		skin.emission = Color(1.0, 0.72, 0.2)
		skin.emission_energy_multiplier = 0.3
		var body := MeshInstance3D.new()
		body.mesh = growth_mesh
		body.material_override = skin
		orb.add_child(body)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.75, 0.3)
		glow.light_energy = 0.6
		glow.omni_range = 3.0
		orb.add_child(glow)
		transient.add_child(orb)
		var angle := randf() * TAU
		orb.global_position = center + Vector3(cos(angle), 0, sin(angle)) * 0.2
		orb.linear_velocity = Vector3(cos(angle) * randf_range(1.2, 2.6), randf_range(1.5, 3.0), sin(angle) * randf_range(1.2, 2.6))
		growths.append({"body": orb, "material": skin, "light": glow, "fuse": randf_range(1.7, 2.4) + i * 0.22, "age": 0.0, "cosmetic": cosmetic})
	game.sounds.play_at("squish", center)

## Removes the cosmetic growth closest to a blast the host reported.
func pop_growth_near(at: Vector3) -> void:
	var best := -1
	var best_gap := 6.0
	for i in range(growths.size()):
		if not growths[i].cosmetic:
			continue
		var gap: float = (growths[i].body as RigidBody3D).global_position.distance_to(at)
		if gap < best_gap:
			best_gap = gap
			best = i
	if best >= 0:
		(growths[best].body as RigidBody3D).queue_free()
		growths.remove_at(best)

# ---------------------------------------------------------------- fire

## The sheets flames are drawn with: an upright tongue, and a round one for a jet.
var flame_sheets: Dictionary = {}

func _flame_sheet(tongue: bool) -> QuadMesh:
	if not flame_sheets.has(tongue):
		var sheet := QuadMesh.new()
		sheet.size = Vector2(0.55, 1.25) if tongue else Vector2(1.0, 1.0)
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.albedo_texture = soft_texture
		paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		paint.billboard_keep_scale = true
		paint.vertex_color_use_as_albedo = true
		sheet.material = paint
		flame_sheets[tongue] = sheet
	return flame_sheets[tongue]

## Flames: soft sheets that glow and are added to the picture. Each one alone is a
## saturated orange that turns red and fades; where many lie over each other they add up
## to yellow, so that a fire is brightest at its heart. `tongues`: upright ones that only
## sway (a fire that stands), or round ones that tumble (a jet). Off until switched on.
func _flames(amount: int, lifetime: float, tongues: bool = true) -> CPUParticles3D:
	var fire := CPUParticles3D.new()
	fire.mesh = _flame_sheet(tongues)
	fire.amount = amount
	fire.lifetime = lifetime
	fire.lifetime_randomness = 0.3
	fire.local_coords = false
	fire.direction = Vector3.UP
	fire.angle_min = -14.0 if tongues else 0.0
	fire.angle_max = 14.0 if tongues else 360.0
	fire.angular_velocity_min = -25.0 if tongues else -90.0
	fire.angular_velocity_max = 25.0 if tongues else 90.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.1, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.7, 0.25, 0.0), Color(1.0, 0.5, 0.1, 0.72), Color(0.95, 0.22, 0.03, 0.5), Color(0.3, 0.03, 0.0, 0.0)])
	fire.color_ramp = ramp
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.emitting = false
	return fire

static func _curve(points: Array) -> Curve:
	var curve := Curve.new()
	for point in points:
		curve.add_point(point)
	return curve

## Flames on a burning body of this height and girth: an emitter to hang on it.
func body_flames(height: float, girth: float) -> CPUParticles3D:
	var fire := _flames(14, 0.55)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(girth * 0.8, height * 0.3, girth * 0.8)
	fire.position.y = height * 0.5
	fire.spread = 25.0
	fire.gravity = Vector3(0, 3.5, 0)
	fire.initial_velocity_min = 0.2
	fire.initial_velocity_max = 0.9
	fire.scale_amount_min = 0.45
	fire.scale_amount_max = 0.8
	fire.scale_amount_curve = _curve([Vector2(0.0, 0.6), Vector2(0.3, 1.0), Vector2(1.0, 0.25)])
	return fire

## The stream of a flamethrower: it flies along the emitter's -Z as far as the weapon
## reaches and widens on its way.
func flame_stream() -> CPUParticles3D:
	var fire := _flames(72, 0.6, false)
	fire.direction = Vector3(0, 0, -1)
	fire.spread = 3.5
	fire.gravity = Vector3(0, 1.2, 0)
	fire.initial_velocity_min = 15.0
	fire.initial_velocity_max = 18.0
	fire.scale_amount_min = 0.9
	fire.scale_amount_max = 1.5
	fire.scale_amount_curve = _curve([Vector2(0.0, 0.07), Vector2(0.45, 0.65), Vector2(1.0, 1.3)])
	return fire

## The small flame on the rag of a Molotov cocktail in flight (switched on by the bottle).
func rag_flame() -> CPUParticles3D:
	var fire := _flames(8, 0.3, false)
	fire.spread = 30.0
	fire.gravity = Vector3(0, 2.0, 0)
	fire.initial_velocity_min = 0.1
	fire.initial_velocity_max = 0.5
	fire.scale_amount_min = 0.1
	fire.scale_amount_max = 0.2
	return fire

## Burning petrol on the ground: a ball of fire where the bottle burst, low flames over a
## round patch, smoke above them, a light and a burnt mark. Returns {node, flames, smoke,
## light}; FireField lets it burn down.
func fire_pool(center: Vector3, radius: float) -> Dictionary:
	var holder := Node3D.new()
	transient.add_child(holder)
	holder.global_position = center
	var fire := _flames(int(radius * 36.0), 0.75)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	fire.emission_ring_axis = Vector3.UP
	fire.emission_ring_height = 0.05
	fire.emission_ring_radius = radius * 0.92
	fire.emission_ring_inner_radius = 0.0
	fire.position.y = 0.3
	fire.spread = 14.0
	fire.gravity = Vector3(0, 2.6, 0)
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 1.2
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.3
	fire.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(0.3, 1.0), Vector2(1.0, 0.3)])
	holder.add_child(fire)
	fire.emitting = true
	var sheet := QuadMesh.new()
	sheet.size = Vector2(1.0, 1.0)
	var soot := StandardMaterial3D.new()
	soot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soot.albedo_texture = puff_textures[1]
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	soot.billboard_keep_scale = true
	soot.vertex_color_use_as_albedo = true
	sheet.material = soot
	var smoke := CPUParticles3D.new()
	smoke.mesh = sheet
	smoke.amount = 12
	smoke.lifetime = 2.4
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = radius * 0.55
	smoke.position.y = 1.1
	smoke.direction = Vector3.UP
	smoke.spread = 20.0
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.3
	smoke.angle_max = 360.0
	smoke.scale_amount_min = 1.3
	smoke.scale_amount_max = 2.3
	smoke.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(1.0, 1.4)])
	var thin := Gradient.new()
	thin.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	thin.colors = PackedColorArray([Color(0.1, 0.09, 0.08, 0.0), Color(0.09, 0.08, 0.08, 0.42), Color(0.12, 0.12, 0.12, 0.0)])
	smoke.color_ramp = thin
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(smoke)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.55, 0.2)
	lamp.light_energy = 3.0
	lamp.omni_range = radius * 3.0
	lamp.position.y = 0.9
	lamp.light_volumetric_fog_energy = 0.6
	holder.add_child(lamp)
	decal(center, radius * 2.3, Color(0.02, 0.02, 0.02, 0.85), Vector3.UP, true)
	var ball := _cloud_burst(true, 14, 0.7, Vector3(0, 2.5, 0), 1.0, 5.0, 0.8, 1.9, 5.0)
	ball.color_ramp = fire.color_ramp
	ball.global_position = center + Vector3(0, 0.4, 0)
	return {"node": holder, "flames": fire, "smoke": smoke, "light": lamp}

# ---------------------------------------------------------------- crusher acid

func acid_cloud(center: Vector3, _cosmetic: bool = false) -> void:
	var holder := Node3D.new()
	transient.add_child(holder)
	holder.global_position = floor_below(center + Vector3.UP * 0.5)
	var volume := FogVolume.new()
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	volume.size = Vector3(ACID_RADIUS * 2.2, 4.6, ACID_RADIUS * 2.2)
	volume.position.y = 1.6
	var mist := FogMaterial.new()
	mist.density = ACID_DENSITY
	mist.albedo = Color(0.25, 0.5, 1.0)
	mist.emission = Color(0.008, 0.03, 0.13)
	mist.edge_fade = 0.5
	volume.material = mist
	holder.add_child(volume)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.25, 0.5, 1.0)
	glow.light_energy = ACID_GLOW
	glow.omni_range = ACID_RADIUS * 2.0
	glow.position.y = 1.2
	glow.light_volumetric_fog_energy = 0.8
	holder.add_child(glow)
	var wisp := QuadMesh.new()
	wisp.size = Vector2(1.0, 1.0)
	var wisp_material := StandardMaterial3D.new()
	wisp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_material.albedo_color = Color(0.25, 0.5, 1.0, 0.16)
	wisp_material.albedo_texture = soft_texture
	wisp_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	wisp.material = wisp_material
	var wisps := CPUParticles3D.new()
	wisps.mesh = wisp
	wisps.amount = 34
	wisps.lifetime = 3.0
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = ACID_RADIUS * 0.8
	wisps.gravity = Vector3(0, 0.25, 0)
	wisps.initial_velocity_min = 0.2
	wisps.initial_velocity_max = 0.7
	wisps.spread = 180
	wisps.scale_amount_min = 1.6
	wisps.scale_amount_max = 3.4
	wisps.position.y = 1.0
	wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(wisps)
	clouds.append({"node": holder, "material": mist, "light": glow, "left": ACID_SECONDS})
	decal(holder.global_position, ACID_RADIUS * 1.5, Color(0.05, 0.12, 0.4, 0.8), Vector3.UP, true)
	game.sounds.play_at("hiss", center)

func in_acid(pos: Vector3) -> bool:
	for cloud in clouds:
		var node: Node3D = cloud.node
		var rise := pos.y - node.global_position.y
		if Vector2(pos.x - node.global_position.x, pos.z - node.global_position.z).length() < ACID_RADIUS and rise > -1.0 and rise < 3.2:
			return true
	return false

func _physics_process(delta: float) -> void:
	splat_sound_left -= delta
	for i in range(tracer_pool.size()):
		if tracer_left[i] > 0.0:
			tracer_left[i] -= delta
			if tracer_left[i] <= 0.0:
				tracer_pool[i].hide()
	if game == null or not game.is_playing():
		return
	for i in range(growths.size() - 1, -1, -1):
		var growth: Dictionary = growths[i]
		var orb: RigidBody3D = growth.body
		growth.age += delta
		growth.fuse -= delta
		# The pulse quickens as the growth is about to burst.
		var urgency: float = clampf(1.0 - float(growth.fuse) / 2.2, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(float(growth.age) * (8.0 + urgency * 26.0))
		(growth.material as StandardMaterial3D).emission_energy_multiplier = 0.15 + pulse * (0.45 + urgency * 1.5)
		(growth.light as OmniLight3D).light_energy = 0.3 + pulse * (0.6 + urgency * 1.6)
		orb.get_child(1).scale = Vector3.ONE * (1.0 + urgency * 0.35 + pulse * 0.08)
		if growth.cosmetic:
			# Left over when the host's blast was never reported: fade out quietly.
			if growth.fuse <= -1.5:
				growths.remove_at(i)
				orb.queue_free()
		elif growth.fuse <= 0.0:
			var at := orb.global_position
			growths.remove_at(i)
			orb.queue_free()
			game.explode(at, GROWTH_RADIUS, 28.0, 40.0, "growth")
	acid_tick -= delta
	for i in range(clouds.size() - 1, -1, -1):
		var cloud: Dictionary = clouds[i]
		cloud.left -= delta
		var strength: float = clampf(float(cloud.left) / 2.0, 0.0, 1.0)
		(cloud.material as FogMaterial).density = ACID_DENSITY * strength
		(cloud.light as OmniLight3D).light_energy = ACID_GLOW * strength
		if cloud.left <= 0.0:
			(cloud.node as Node3D).queue_free()
			clouds.remove_at(i)
	if acid_tick <= 0.0:
		acid_tick = 0.5
		# Every machine burns its own survivors; a co-op partner checks for themselves.
		for survivor in game.survivors:
			if is_instance_valid(survivor) and survivor.takes_local_damage() and in_acid(survivor.global_position):
				survivor.receive_damage(5.0 * float(game.rules.harm), survivor.global_position, "acid")
