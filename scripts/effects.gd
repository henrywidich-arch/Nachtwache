class_name CombatEffects
extends Node3D
## Short-lived combat visuals and hazards: blood and gore, impacts, tracers, explosions,
## gibs, the Striker's explosive growths and the Crusher's acid cloud.

const MAX_DECALS := 190
const GROWTH_RADIUS := 3.1
const ACID_RADIUS := 4.3
const ACID_SECONDS := 9.0
const ACID_DENSITY := 0.42
const ACID_GLOW := 1.6
const BLOOD := Color(0.26, 0.012, 0.01, 0.95)
const BLOOD_DARK := Color(0.16, 0.006, 0.006, 0.95)
## Blood on a surface: its colour is in its picture, near black where it lies thick and a
## dull dark red where it was thrown thin (sRGB). It reads as wet by its gloss and the
## relief of its edges (its own roughness and normal maps), never by a bright colour.
const BLOOD_THIN := Color(0.24, 0.034, 0.028)
const BLOOD_THICK := Color(0.072, 0.009, 0.008)
## How many pictures there are of each kind of blood mark. splat: a hit's splash with drops
## and streaks around it; spray: drops flung one way (along the picture's x), stretched the
## faster they flew; run: a splash on a wall with drips running down (along the picture's
## z); pool: a ragged pool; drip: one rivulet.
const BLOOD_KINDS := {"splat": 3, "spray": 3, "run": 2, "pool": 2, "drip": 1}
## Out in the rain on wet ground blood is darker, as the ground itself is.
const BLOOD_WET_SHADE := 0.74
## What the second exploding infected is full of: the colour of blood orange, on the floor
## and in the air. Its puddle: how wide it gets (metres), how long it lies before it
## dries away, how long that takes, and how much it glows in the dark.
const OOZE := Color(0.9, 0.31, 0.04, 0.95)
const OOZE_DARK := Color(0.55, 0.15, 0.02, 0.95)
const PUDDLE_SIZE := 5.4
const PUDDLE_SECONDS := 16.0
const PUDDLE_FADE := 5.0
const PUDDLE_GLOW := 0.22

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
## The pictures of blood marks by kind: lists of [colour, relief, gloss].
var blood_maps: Dictionary = {}
## The second exploder's puddle (a picture of its own, with the colour in it, so that it
## can glow), the puddles that lie about, and the drops and the haze of its burst.
var puddle_texture: ImageTexture
var puddles: Array[Decal] = []
var ooze_mesh: SphereMesh
var ooze_mist: QuadMesh
var drop_mesh: SphereMesh
var mist_mesh: QuadMesh
var gib_mesh: SphereMesh
## Torn scraps of flesh: lumps pulled out of shape, no two alike.
var gib_meshes: Array[ArrayMesh] = []
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
	puddle_texture = _puddle_texture()
	var marks: Array = [[soft_texture], [puddle_texture]]
	for texture in splat_textures:
		marks.append([texture])
	for kind in BLOOD_KINDS:
		blood_maps[kind] = []
		for variant in range(int(BLOOD_KINDS[kind])):
			var maps := _blood_picture(String(kind), variant)
			blood_maps[kind].append(maps)
			marks.append(maps)
	for pictures: Array in marks:
		var anchor := Decal.new()
		anchor.texture_albedo = pictures[0]
		if pictures.size() > 1:
			anchor.texture_normal = pictures[1]
			anchor.texture_orm = pictures[2]
		anchor.size = Vector3(0.1, 0.1, 0.1)
		anchor.position = Vector3(0, -60, 0)
		add_child(anchor)
	gib_mesh = SphereMesh.new()
	gib_mesh.radius = 0.5
	gib_mesh.height = 1.0
	gib_mesh.radial_segments = 7
	gib_mesh.rings = 4
	for variant in range(5):
		gib_meshes.append(_torn_lump(variant))
	# Torn flesh, dark and wet, a lump of fat and a splinter of bone.
	for color in [Color("3a0907"), Color("4f1d18"), Color("230504"), Color("5a0f0c"), Color("6e5f52"), Color("8f8574")]:
		var flesh := StandardMaterial3D.new()
		flesh.albedo_color = color
		flesh.roughness = 0.5 if color.v > 0.4 else 0.22
		flesh.metallic_specular = 0.6
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
	ooze_mesh = drop_mesh.duplicate() as SphereMesh
	# Drops of blood: dark, without any glow of their own; only a light makes them shine.
	# Longer than wide, they lie along their way (particle_flag_align_y).
	var blood_material := StandardMaterial3D.new()
	blood_material.albedo_color = Color("3c0605")
	blood_material.roughness = 0.12
	blood_material.metallic_specular = 0.7
	drop_mesh.material = blood_material
	drop_mesh.height = 1.7
	for i in range(12):
		var spray := _burst(drop_mesh, 30, 0.6, Vector3(0, -11, 0), 1.8, 5.6, 0.009, 0.03, 48.0)
		spray.particle_flag_align_y = true
		blood_pool.append(spray)
	var ooze_material := StandardMaterial3D.new()
	ooze_material.albedo_color = Color(OOZE.r, OOZE.g, OOZE.b)
	ooze_material.roughness = 0.25
	ooze_material.emission_enabled = true
	ooze_material.emission = Color(0.3, 0.09, 0.012)
	ooze_mesh.material = ooze_material
	# Longer than wide: in flight a drop lies along its way (see _ooze_blast).
	ooze_mesh.height = 2.4
	# A fine red haze hangs in the air for a moment where a bullet went through.
	mist_mesh = QuadMesh.new()
	mist_mesh.size = Vector2(1.0, 1.0)
	var mist_material := StandardMaterial3D.new()
	mist_material.albedo_color = Color(0.24, 0.02, 0.018, 0.42)
	mist_material.albedo_texture = soft_texture
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mist_material.vertex_color_use_as_albedo = true
	mist_mesh.material = mist_material
	for i in range(8):
		var mist := _burst(mist_mesh, 5, 0.55, Vector3(0, -0.6, 0), 0.3, 1.3, 0.22, 0.5, 70.0)
		mist.color_ramp = _fade()
		mist_pool.append(mist)
	ooze_mist = mist_mesh.duplicate() as QuadMesh
	var haze_material := mist_material.duplicate() as StandardMaterial3D
	haze_material.albedo_color = Color(0.85, 0.33, 0.06, 0.4)
	ooze_mist.material = haze_material
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

## One picture of a blood mark of `kind` (see BLOOD_KINDS): [colour, relief, gloss]. It is
## drawn as a height field of domed drops and lobes - the thicker, the darker and glossier,
## with a little rim of relief where the film ends.
func _blood_picture(kind: String, variant: int) -> Array:
	var size := 128
	var height := PackedFloat32Array()
	height.resize(size * size)
	# [centre (shares of the picture), radius, axis of its length, length over width, depth]
	var blobs: Array = []
	var middle := Vector2(0.5, 0.5)
	match kind:
		"splat":
			var core := 0.13 - variant * 0.02
			for i in range(6):
				blobs.append([middle + Vector2.from_angle(random.randf() * TAU) * random.randf_range(0.0, 0.08), random.randf_range(core * 0.55, core), Vector2.from_angle(random.randf() * TAU), random.randf_range(1.0, 1.5), random.randf_range(0.8, 1.0)])
			for i in range(18 + variant * 10):
				var way := Vector2.from_angle(random.randf() * TAU)
				var reach := random.randf_range(0.14, 0.46)
				var radius := random.randf_range(0.006, 0.03) * (1.2 - reach)
				# The further a drop flew, the longer it is drawn out along its way.
				blobs.append([middle + way * reach, radius, way, 1.0 + reach * 1.6, 0.6])
				if random.randf() < 0.3:
					# A streak: a thin tail back towards the splash, the drop at its end.
					for step in range(1, 6):
						blobs.append([middle + way * (reach - step * 0.012), radius * (0.8 - step * 0.12), way, 1.6, 0.45])
		"spray":
			var origin := Vector2(0.1, 0.5)
			for i in range(4):
				blobs.append([origin + Vector2(random.randf_range(0.0, 0.08), random.randf_range(-0.04, 0.04)), random.randf_range(0.03, 0.06), Vector2.RIGHT, random.randf_range(1.6, 2.6), 0.85])
			for i in range(42 + variant * 16):
				var angle := (random.randf() + random.randf() - 1.0) * (0.35 + variant * 0.1)
				var way := Vector2.from_angle(angle)
				var reach := 0.04 + pow(random.randf(), 0.75) * 0.8
				var radius := lerpf(0.03, 0.008, reach / 0.84) * random.randf_range(0.55, 1.25)
				var at := origin + way * reach
				if at.x > 0.97 or absf(at.y - 0.5) > 0.47:
					continue
				blobs.append([at, radius, way, 1.1 + reach * 1.8, 0.55])
				if random.randf() < 0.14:
					# A fast drop with a short tail behind it.
					blobs.append([at - way * radius * 2.2, radius * 0.5, way, 2.4, 0.4])
		"run":
			var top := Vector2(0.5, 0.26)
			for i in range(5):
				blobs.append([top + Vector2(random.randf_range(-0.08, 0.08), random.randf_range(-0.05, 0.05)), random.randf_range(0.06, 0.12), Vector2.from_angle(random.randf() * TAU), random.randf_range(1.0, 1.4), 0.9])
			for i in range(16):
				var way := Vector2.from_angle(random.randf() * TAU)
				var reach := random.randf_range(0.14, 0.32)
				blobs.append([top + way * reach, random.randf_range(0.006, 0.02), way, 1.0 + reach * 1.6, 0.55])
			# Drips: from the lower edge of the splash down the wall, thinning, a bead at the end.
			for i in range(3 + variant * 2):
				var x := top.x + random.randf_range(-0.12, 0.12)
				var start := top.y + random.randf_range(0.04, 0.1)
				var length := random.randf_range(0.18, 0.62)
				var wide := random.randf_range(0.011, 0.02)
				var wobble := random.randf() * TAU
				var steps := int(length / 0.006)
				for k in range(steps):
					var t := float(k) / steps
					blobs.append([Vector2(x + sin(wobble + t * 5.0) * 0.006, start + length * t), wide * (1.0 - t * 0.35), Vector2.DOWN, 1.0, 0.7])
				blobs.append([Vector2(x + sin(wobble + 5.0) * 0.006, start + length), wide * 1.5, Vector2.DOWN, 1.3, 0.85])
		"pool":
			# Lobes that ran their own ways: wide bays, tongues, never a round disc.
			blobs.append([middle, 0.15, Vector2.RIGHT, 1.2, 1.0])
			for i in range(11):
				var way := Vector2.from_angle(random.randf() * TAU)
				blobs.append([middle + way * random.randf_range(0.06, 0.22), random.randf_range(0.06, 0.16), way, random.randf_range(1.1, 2.0), random.randf_range(0.75, 1.0)])
			for i in range(10):
				var way := Vector2.from_angle(random.randf() * TAU)
				blobs.append([middle + way * random.randf_range(0.33, 0.44), random.randf_range(0.01, 0.03), way, 1.4, 0.6])
		"drip":
			for k in range(150):
				var t := k / 150.0
				blobs.append([Vector2(0.5 + sin(t * 6.0) * 0.03, 0.06 + t * 0.78), lerpf(0.11, 0.07, t), Vector2.DOWN, 1.0, 0.75])
			blobs.append([Vector2(0.5 + sin(6.0) * 0.03, 0.86), 0.15, Vector2.DOWN, 1.25, 0.9])
	for blob: Array in blobs:
		var centre: Vector2 = (blob[0] as Vector2) * size
		var radius: float = maxf(0.8, float(blob[1]) * size)
		var axis: Vector2 = blob[2]
		var long: float = blob[3]
		var depth: float = blob[4]
		var reach := radius * long + 1.0
		for y in range(maxi(0, int(centre.y - reach)), mini(size, int(centre.y + reach + 2))):
			for x in range(maxi(0, int(centre.x - reach)), mini(size, int(centre.x + reach + 2))):
				var gap := Vector2(x + 0.5, y + 0.5) - centre
				var along := gap.dot(axis) / (radius * long)
				var across := gap.dot(axis.orthogonal()) / radius
				var q := along * along + across * across
				if q < 1.0:
					var index := y * size + x
					# Lobes that meet run together into one thicker film.
					height[index] = maxf(height[index], sqrt(1.0 - q) * depth) + (0.12 * depth * (1.0 - q) if height[index] > 0.0 else 0.0)
	var noise := FastNoiseLite.new()
	noise.seed = 3301 + variant * 41 + kind.length() * 7
	noise.frequency = 0.09
	var grain := noise.get_image(size, size)
	var colour := PackedByteArray()
	var relief := PackedByteArray()
	var gloss := PackedByteArray()
	colour.resize(size * size * 4)
	relief.resize(size * size * 4)
	gloss.resize(size * size * 4)
	for y in range(size):
		for x in range(size):
			var index := y * size + x
			var wobble := grain.get_pixel(x, y).r
			var h := height[index] + (wobble - 0.5) * (0.32 if kind == "pool" else 0.1) * float(height[index] > 0.0)
			var cover := smoothstep(0.05, 0.16, h)
			var thick := smoothstep(0.2, 0.85, h)
			var tint := BLOOD_THIN.lerp(BLOOD_THICK, thick) * (0.88 + 0.24 * wobble)
			colour[index * 4] = int(clampf(tint.r, 0.0, 1.0) * 255.0)
			colour[index * 4 + 1] = int(clampf(tint.g, 0.0, 1.0) * 255.0)
			colour[index * 4 + 2] = int(clampf(tint.b, 0.0, 1.0) * 255.0)
			colour[index * 4 + 3] = int(cover * 242.0)
			var left := height[y * size + maxi(0, x - 1)]
			var right := height[y * size + mini(size - 1, x + 1)]
			var up := height[maxi(0, y - 1) * size + x]
			var down := height[mini(size - 1, y + 1) * size + x]
			var normal := Vector3((left - right) * 2.2, (up - down) * 2.2, 1.0).normalized()
			relief[index * 4] = int((normal.x * 0.5 + 0.5) * 255.0)
			relief[index * 4 + 1] = int((normal.y * 0.5 + 0.5) * 255.0)
			relief[index * 4 + 2] = int((normal.z * 0.5 + 0.5) * 255.0)
			relief[index * 4 + 3] = 255
			# Occlusion, roughness, metallic: wet and smooth where it lies thick.
			gloss[index * 4] = 255
			gloss[index * 4 + 1] = int(lerpf(0.34, 0.06, thick) * 255.0)
			gloss[index * 4 + 2] = 0
			gloss[index * 4 + 3] = 255
	var maps: Array = []
	for data in [colour, relief, gloss]:
		var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
		image.generate_mipmaps()
		maps.append(ImageTexture.create_from_image(image))
	return maps

## A lump of torn flesh about a metre across (scaled down where it is used): a sphere
## pulled out of shape by noise, ragged and lopsided.
func _torn_lump(variant: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 6
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 61 + variant * 19
	noise.frequency = 2.2
	for i in range(points.size()):
		var at := points[i]
		# The same point on the seam is moved the same way, so the lump stays closed.
		var push := 0.62 + 0.55 * noise.get_noise_3dv(at * 1.0) + 0.18 * noise.get_noise_3dv(at * 3.7 + Vector3.ONE * 5.0)
		points[i] = at * push * Vector3(1.0, 0.8 + variant * 0.06, 1.0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		tool.add_vertex(points[index])
	tool.index()
	tool.generate_normals()
	return tool.commit()

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
	puddles.clear()
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
	for style in ["growth", "charger", "boomer", "blast"]:
		explosion(center, 2.0, style)
	charger_burst(center)
	boomer_burst(center)
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
	var ahead := Vector3(shot_direction.x, 0.0, shot_direction.z)
	if heavy or random.randf() < 0.6:
		# The exit spray lands on the floor beyond the wound, flung away from the shooter, and
		# a few heavier drops fall short of it.
		var floor_hit := _ray(point, point + Vector3.DOWN * 2.6 + shot_direction * 0.9)
		if not floor_hit.is_empty():
			var spot: Vector3 = floor_hit.position
			blood_mark(spot, random.randf_range(0.45, 0.8) * (1.5 if heavy else 1.0), floor_hit.normal, "spray", ahead, 1.5)
			for i in range(1 + int(heavy) + random.randi() % 2):
				var drop := floor_below(spot - ahead.normalized() * random.randf_range(0.15, 0.6) + Vector3(random.randf_range(-0.2, 0.2), 0.3, random.randf_range(-0.2, 0.2)), 1.5)
				blood_mark(drop, random.randf_range(0.1, 0.22), Vector3.UP, "splat")
	if heavy or random.randf() < 0.5:
		# The exit spray lands on the wall behind: flung across it, or a splash that runs.
		var wall_hit := _ray(point, point + shot_direction * 3.6 + Vector3.DOWN * 0.3)
		if not wall_hit.is_empty():
			var reach: float = point.distance_to(wall_hit.position)
			# The further it flew, the wider it spread.
			var size := random.randf_range(0.45, 0.85) * (1.4 if heavy else 1.0) * (0.8 + reach * 0.15)
			var upright := absf((wall_hit.normal as Vector3).y) < 0.6
			if upright and random.randf() < 0.55:
				var mark := blood_mark(wall_hit.position, size, wall_hit.normal, "run")
				if heavy and mark != null:
					drip(mark.global_position + Vector3.DOWN * size * 0.15, wall_hit.normal, random.randf_range(0.35, 0.8))
			else:
				blood_mark(wall_hit.position, size, wall_hit.normal, "spray", shot_direction, 1.4)

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

## A blood mark of `kind` (see BLOOD_KINDS) on the surface at `point` whose normal is
## `normal`. Sprays are turned to run along `along` (away from the wound) and drawn out by
## `stretch`; runs and drips are turned so that they run down. Darker out on wet ground in
## the rain, as the ground is.
func blood_mark(point: Vector3, size: float, normal: Vector3 = Vector3.UP, kind: String = "splat", along: Vector3 = Vector3.ZERO, stretch: float = 1.0) -> Decal:
	var pictures: Array = blood_maps[kind]
	var maps: Array = pictures[random.randi() % pictures.size()]
	var mark := Decal.new()
	mark.texture_albedo = maps[0]
	mark.texture_normal = maps[1]
	mark.texture_orm = maps[2]
	var shade := random.randf_range(0.82, 1.05) * _blood_shade(point, normal)
	mark.modulate = Color(shade, shade, shade, 1.0)
	mark.size = Vector3(size * stretch, 0.5, size * random.randf_range(0.8, 1.15))
	mark.cull_mask = 1
	mark.normal_fade = 0.35
	mark.upper_fade = 0.02
	mark.lower_fade = 0.02
	transient.add_child(mark)
	var up := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var basis := Basis.IDENTITY
	if kind in ["run", "drip"] and absf(up.y) < 0.9:
		var down := (Vector3.DOWN - up * up.dot(Vector3.DOWN)).normalized()
		basis = Basis(up.cross(down), up, down)
	else:
		var way := along - up * up.dot(along)
		if way.length() < 0.05:
			way = Basis(up, random.randf() * TAU) * (Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD)
			way = (way - up * up.dot(way))
		way = way.normalized()
		# (A spray's picture starts at its left edge: it is moved on by half its length.)
		if kind == "spray":
			point += way * mark.size.x * 0.4
		basis = Basis(way, up, way.cross(up))
	mark.global_transform = Transform3D(basis.orthonormalized(), point + up * 0.08)
	_keep(mark)
	return mark

func _keep(mark: Decal) -> void:
	decals.append(mark)
	if decals.size() > MAX_DECALS:
		var oldest: Decal = decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

## How light blood looks at a place: out in the rain on the wet ground it is darkened as
## the ground is (and so never stands out from it bright); under a roof it is as it is.
func _blood_shade(point: Vector3, normal: Vector3) -> float:
	var map: Node = game.get("cabin") if game != null else null
	if map == null or not is_instance_valid(map):
		return 1.0
	var rain: Node3D = map.get("rain")
	if rain == null or not rain.visible:
		return 1.0
	return BLOOD_WET_SHADE if _ray(point + normal * 0.15, point + Vector3.UP * 30.0).is_empty() else 1.0

## Blood running down a wall from `point` for `length` metres, slowing as it goes.
func drip(point: Vector3, normal: Vector3, length: float) -> void:
	var rivulet := blood_mark(point, 0.07, normal, "drip")
	var top := rivulet.global_position
	var down := rivulet.global_basis.z.normalized()
	var width := random.randf_range(0.1, 0.16)
	var run := func(reach: float) -> void:
		rivulet.size = Vector3(width, 0.5, reach)
		rivulet.global_position = top + down * reach * 0.5
	run.call(0.06)
	rivulet.create_tween().tween_method(run, 0.06, length, random.randf_range(2.5, 4.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## A pool that slowly spreads under a body, darkest where it lies deepest.
func blood_pool_at(point: Vector3, size: float) -> void:
	var ground := floor_below(point + Vector3.UP * 0.5)
	var pool := blood_mark(ground, size, Vector3.UP, "pool")
	var full := pool.size
	pool.size = Vector3(full.x * 0.2, full.y, full.z * 0.2)
	pool.create_tween().tween_property(pool, "size", full, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	# Killed by a heavy blow (Survivor._melee_strike): a sledgehammer or an axe caves the
	# head in, a blade takes off an arm.
	var blow: Array = enemy.get_meta("melee_blow", [])
	if two_legged and blow.size() == 2:
		var weight: float = blow[0]
		if weight >= 0.7 and not bool(blow[1]):
			headshot = true
			overkill = true
		elif bool(blow[1]) and weight >= 0.4 and random.randf() < weight + 0.2:
			if weight >= 0.7 and random.randf() < 0.5:
				headshot = true
			overkill = true
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
			blood_mark(at, random.randf_range(0.6, 1.2), Vector3.UP, "spray", direction, 1.5)
	# The body hits the floor a moment later and starts to bleed out.
	var timer := enemy.create_tween()
	timer.tween_interval(0.85)
	timer.tween_callback(_body_landed.bind(enemy))

## A blow with a melee weapon lands at `point`, driving along `direction`. `weight`: how
## heavy it is (0 a knife, 1 the sledgehammer); `edged`: it cuts. A cut throws blood in a
## sheet across the way of the blade; a heavy blunt blow bursts and spatters, tears loose
## scraps and paints the survivor who swung it.
func melee_hit(enemy: Infected, point: Vector3, direction: Vector3, weight: float, edged: bool) -> void:
	var across := direction.cross(Vector3.UP).normalized()
	blood(point, direction, weight >= 0.4)
	if edged:
		# The sheet along the cut: away from the blade, to the left, as it was swung.
		for i in range(1 + int(weight * 3.0)):
			var at := point + across * random.randf_range(-0.25, 0.25) + Vector3.UP * random.randf_range(-0.15, 0.2)
			blood(at, (direction * 0.4 - across + Vector3.UP * random.randf_range(-0.1, 0.3)).normalized(), true)
		var gap := floor_below(point + direction * 0.4 - across * 0.4)
		blood_mark(gap, 0.6 + weight * 0.7, Vector3.UP, "spray", -across + direction * 0.5, 1.7)
	else:
		var burst := mist_pool[mist_next]
		mist_next = (mist_next + 1) % mist_pool.size()
		burst.global_position = point
		burst.direction = direction
		burst.restart()
		burst.emitting = true
		if weight >= 0.5:
			chunks(point, int(weight * 4.0), 0.4 + weight * 0.3, direction * (2.0 + weight * 3.0) + Vector3.UP)
			for i in range(int(weight * 3.0)):
				var around := direction.rotated(Vector3.UP, random.randf_range(-0.9, 0.9))
				blood_mark(floor_below(point + around * random.randf_range(0.6, 1.8)), random.randf_range(0.4, 0.9), Vector3.UP, "spray", around, 1.5)
	# Close enough, it reaches whoever swung.
	if weight >= 0.4 and game.player.global_position.distance_to(point) < 2.6:
		game.hud.splatter(0.18 + weight * 0.3)
	if weight >= 0.7:
		_splat_sound(point, "gib")

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
	jet.particle_flag_align_y = true
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
	jet.scale_amount_min = 0.01
	jet.scale_amount_max = 0.03
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stump.add_child(jet)
	var life := jet.create_tween()
	life.tween_interval(1.3)
	life.tween_callback(func() -> void: jet.emitting = false)
	life.tween_interval(0.9)
	life.tween_callback(jet.queue_free)
	blood_mark(floor_below(stump.global_position), random.randf_range(0.7, 1.1), Vector3.UP, "splat")

## A spent shotgun shell flips out of the ejection port and rolls away. `big`: an empty
## 40 mm case from the drum of the M32 instead.
func spent_shell(at: Vector3, velocity: Vector3, big: bool = false) -> void:
	var shell := RigidBody3D.new()
	shell.collision_layer = 0
	shell.collision_mask = 1
	shell.mass = 0.05
	var shape := CollisionShape3D.new()
	var tube := CylinderShape3D.new()
	tube.radius = 0.021 if big else 0.011
	tube.height = 0.05 if big else 0.065
	shape.shape = tube
	shell.add_child(shape)
	var parts := [[0.011, 0.05, Color("9e1614"), 0.008], [0.0115, 0.015, Color("c9a04e"), -0.025]]
	if big:
		# An aluminium case with its brass-coloured base, open at the top.
		parts = [[0.0205, 0.042, Color("8c8f93"), 0.004], [0.021, 0.008, Color("b08a3c"), -0.021]]
	for part in parts:
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
		piece.mesh = gib_meshes[random.randi() % gib_meshes.size()]
		var tissue := random.randi() % gib_materials.size()
		piece.material_override = gib_materials[tissue]
		# Mostly small scraps, now and then a long strip or a heavy lump; bone in splinters.
		var bulk := random.randf_range(0.05, 0.12) * (1.6 if random.randf() < 0.15 else 1.0)
		piece.scale = Vector3(bulk, bulk * random.randf_range(0.4, 0.8), bulk * random.randf_range(0.7, 2.2))
		if tissue == gib_materials.size() - 1:
			piece.scale = Vector3(bulk * 0.3, bulk * 0.3, bulk * random.randf_range(1.2, 2.0))
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
		# It smears along the way it was going.
		blood_mark(hit.position, random.randf_range(0.22, 0.45), hit.normal, "spray", chunk.linear_velocity, 1.3)
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
	elif style == "boomer":
		_ooze_blast(center, radius)
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
	spray.particle_flag_align_y = true
	globs.particle_flag_align_y = true
	var ground := floor_below(center)
	blood_pool_at(center, 3.6)
	blood_mark(ground, 2.6, Vector3.UP, "splat")
	for i in range(14):
		var reach := random.randf_range(0.9, 4.6)
		var around := random.randf() * TAU
		var out := Vector3(cos(around), 0, sin(around))
		blood_mark(floor_below(center + out * reach), random.randf_range(0.6, 1.6), Vector3.UP, "spray", out, 1.5)
	# Whatever stands around the blast gets painted, and it runs down the walls.
	for i in range(12):
		var angle := TAU * i / 12.0 + random.randf_range(-0.2, 0.2)
		var out := Vector3(cos(angle), random.randf_range(-0.15, 0.45), sin(angle)).normalized()
		var hit := _ray(center, center + out * 5.5)
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7:
			var size := random.randf_range(0.9, 1.9)
			blood_mark(hit.position, size, hit.normal, "run" if i % 2 == 0 else "spray", out, 1.3)
			drip((hit.position as Vector3) + Vector3.DOWN * size * 0.1, hit.normal, random.randf_range(0.5, 1.2))
	var above := _ray(center, center + Vector3.UP * 3.6)
	if not above.is_empty():
		blood_mark(above.position, random.randf_range(1.6, 2.4), above.normal, "splat")
	game.sounds.play_at("gore_burst", center)
	var gap: float = game.player.global_position.distance_to(center)
	if gap < 7.0:
		game.hud.splatter(1.0 - gap / 7.0)

# ---------------------------------------------------------------- the second exploder

## The picture of its puddle: one ragged pool with lobes and a few drops thrown clear. The
## colour is in the picture and thins out with it, so that the same picture can make the
## puddle glow a little (a decal's glow takes no notice of how see-through it is).
func _puddle_texture() -> ImageTexture:
	var size := 128
	var outline := FastNoiseLite.new()
	outline.seed = 2202
	outline.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	outline.frequency = 1.0
	var mottle := FastNoiseLite.new()
	mottle.seed = 517
	mottle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mottle.frequency = 0.06
	# Drops that were thrown clear of the pool: [middle, radius], in shares of the picture.
	var drops: Array = []
	for i in range(14):
		drops.append([Vector2.from_angle(random.randf() * TAU) * random.randf_range(0.36, 0.47), random.randf_range(0.007, 0.026)])
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var spot := Vector2(x + 0.5, y + 0.5) / size - Vector2(0.5, 0.5)
			var away := spot.length()
			var ray := Vector2.from_angle(spot.angle())
			# The edge wanders in and out: wide bays, and smaller tongues on top of them.
			var edge := 0.29 + 0.085 * outline.get_noise_2d(ray.x * 1.5, ray.y * 1.5) + 0.04 * outline.get_noise_2d(ray.x * 4.5 + 9.0, ray.y * 4.5)
			var cover := clampf((edge - away) / 0.028 + 0.5, 0.0, 1.0)
			for drop: Array in drops:
				cover = maxf(cover, clampf((float(drop[1]) - spot.distance_to(drop[0])) / 0.012 + 0.5, 0.0, 1.0))
			# Deeper, and so darker, towards the middle; and never quite even.
			var shade := (1.0 - 0.28 * clampf(1.0 - away / 0.26, 0.0, 1.0)) * (0.86 + 0.14 * mottle.get_noise_2d(x, y))
			image.set_pixel(x, y, Color(OOZE.r * cover * shade, OOZE.g * cover * shade, OOZE.b * cover * shade, cover * OOZE.a))
	return ImageTexture.create_from_image(image)

## A puddle of it spreads on the floor below `point`, lies there for a while and dries
## away. It only looks the part: nothing happens to whoever walks through it.
func ooze_puddle(point: Vector3, size: float = PUDDLE_SIZE) -> Decal:
	var ground := floor_below(point + Vector3.UP * 0.5)
	var pool := Decal.new()
	pool.texture_albedo = puddle_texture
	pool.texture_emission = puddle_texture
	pool.emission_energy = PUDDLE_GLOW
	pool.size = Vector3(size * 0.3, 0.5, size * 0.3)
	pool.cull_mask = 1
	pool.normal_fade = 0.35
	pool.upper_fade = 0.02
	pool.lower_fade = 0.02
	transient.add_child(pool)
	pool.global_transform = Transform3D(Basis(Vector3.UP, random.randf() * TAU), ground + Vector3.UP * 0.08)
	puddles.append(pool)
	var life := pool.create_tween()
	life.tween_property(pool, "size", Vector3(size, 0.5, size * random.randf_range(0.82, 1.0)), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	life.tween_interval(PUDDLE_SECONDS)
	life.tween_property(pool, "modulate:a", 0.0, PUDDLE_FADE)
	life.parallel().tween_property(pool, "emission_energy", 0.0, PUDDLE_FADE)
	life.tween_callback(_puddle_gone.bind(pool))
	# (The checks run it to its end without waiting.)
	pool.set_meta("life", life)
	return pool

func _puddle_gone(pool: Decal) -> void:
	puddles.erase(pool)
	pool.queue_free()

## The second exploding infected does not go off like a shell: it bursts open low and
## wide. A dull flash the colour of blood orange, a sheet of drops thrown out flat over
## the ground, and a haze that hangs knee-high - no fire, no smoke, no burn on the floor.
## (What its blast does is the Charger's; this is only how it looks.)
func _ooze_blast(center: Vector3, radius: float) -> void:
	var ground := floor_below(center)
	var low := ground + Vector3(0, 0.45, 0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.42, 0.1)
	flash.light_energy = 3.4
	flash.omni_range = radius * 1.9
	transient.add_child(flash)
	flash.global_position = low
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.34)
	fade.tween_callback(flash.queue_free)
	# It spills over the ground: a glow that runs out as far as the blast reaches.
	var spill := _glow_sprite(soft_texture, Color(1.5, 0.5, 0.1, 0.55), true)
	spill.global_position = ground + Vector3(0, 0.07, 0)
	spill.rotation.x = -PI / 2
	spill.scale = Vector3.ONE * 0.5
	var run := spill.create_tween().set_parallel(true)
	run.tween_property(spill, "scale", Vector3.ONE * radius * 1.25, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	run.tween_property(spill.material_override, "albedo_color:a", 0.0, 0.32)
	run.chain().tween_callback(spill.queue_free)
	# Drops thrown out flat, all the way round: each a streak along its way.
	var sheet := _one_shot(ooze_mesh, 160, 0.9, Vector3(0, -7.5, 0), 4.0, radius * 2.6, 0.022, 0.06, 180.0)
	sheet.direction = Vector3.FORWARD
	sheet.flatness = 0.9
	sheet.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	sheet.global_position = low
	var globs := _one_shot(ooze_mesh, 44, 1.2, Vector3(0, -9.0, 0), 2.0, radius * 1.5, 0.05, 0.12, 180.0)
	globs.direction = Vector3.FORWARD
	globs.flatness = 0.7
	globs.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	globs.global_position = low
	var haze := _one_shot(ooze_mist, 26, 2.0, Vector3(0, -0.25, 0), 2.0, radius * 2.1, radius * 0.22, radius * 0.44, 180.0)
	haze.direction = Vector3.FORWARD
	haze.flatness = 0.93
	haze.damping_min = 1.7
	haze.damping_max = 2.6
	haze.color_ramp = _fade()
	haze.global_position = low + Vector3(0, 0.1, 0)

## What is left of it: scraps thrown low and wide, its insides across the floor and up to
## the knees of whatever stands around, and the puddle. (The sound of it comes with the
## blast, see Game.explode.)
func boomer_burst(center: Vector3) -> void:
	chunks(center + Vector3.DOWN * 0.3, 30, 1.35, Vector3(0, -2.2, 0))
	ooze_puddle(center)
	for i in range(16):
		var reach := random.randf_range(1.4, 6.2)
		var around := random.randf() * TAU
		decal(floor_below(center + Vector3(cos(around), 0, sin(around)) * reach), random.randf_range(0.6, 1.7), OOZE_DARK if i % 3 == 0 else OOZE)
	for i in range(10):
		var angle := TAU * i / 10.0 + random.randf_range(-0.25, 0.25)
		var out := Vector3(cos(angle), random.randf_range(-0.28, 0.02), sin(angle)).normalized()
		var hit := _ray(center, center + out * 6.0)
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7:
			decal(hit.position, random.randf_range(0.9, 1.8), OOZE, hit.normal)
	var gap: float = game.player.global_position.distance_to(center)
	if gap < 7.0:
		game.hud.splatter(1.0 - gap / 7.0)

# ---------------------------------------------------------------- striker growths

## Explosive growths roll free of a Striker and burst a moment later. `cosmetic` ones
## only look the part: the host of a co-op match decides when and where they go off.
## `spent` ones come from a Striker that burnt (the sweeper's ability): charred, and they
## only fizzle out.
func drop_growths(center: Vector3, count: int, cosmetic: bool = false, spent: bool = false) -> void:
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
		skin.albedo_color = Color("3a2a26") if spent else Color("c98a86")
		skin.roughness = 0.9 if spent else 0.35
		skin.emission_enabled = true
		skin.emission = Color(1.0, 0.35, 0.08) if spent else Color(1.0, 0.72, 0.2)
		skin.emission_energy_multiplier = 0.3
		var body := MeshInstance3D.new()
		body.mesh = growth_mesh
		body.material_override = skin
		orb.add_child(body)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.75, 0.3)
		glow.light_energy = 0.6
		glow.omni_range = 1.2 if spent else 3.0
		orb.add_child(glow)
		transient.add_child(orb)
		var angle := randf() * TAU
		orb.global_position = center + Vector3(cos(angle), 0, sin(angle)) * 0.2
		orb.linear_velocity = Vector3(cos(angle) * randf_range(1.2, 2.6), randf_range(1.5, 3.0), sin(angle) * randf_range(1.2, 2.6))
		growths.append({"body": orb, "material": skin, "light": glow, "fuse": randf_range(1.7, 2.4) + i * 0.22, "age": 0.0, "cosmetic": cosmetic, "spent": spent})
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
		if growth.spent:
			# Burnt out: it glows down like an ember, shrinks and is gone with a hiss.
			(growth.material as StandardMaterial3D).emission_energy_multiplier = 0.5 * (1.0 - urgency)
			(growth.light as OmniLight3D).light_energy = 0.25 * (1.0 - urgency)
			orb.get_child(1).scale = Vector3.ONE * (1.0 - urgency * 0.45)
			if growth.fuse <= 0.0:
				var where := orb.global_position
				growths.remove_at(i)
				orb.queue_free()
				dust(where, Vector3.UP)
				game.sounds.play_at("hiss", where, -9.0, 1.5)
			continue
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
