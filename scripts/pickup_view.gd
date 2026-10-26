extends RefCounted
## Grounded field equipment: fabric, straps, latches and a quiet pool of light.
static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = metal
	paint.roughness = 0.78 if metal == 0.0 else 0.4
	paint.vertex_color_use_as_albedo = true
	return paint

static func build(kind: String) -> Node3D:
	# (A crate of throwables is a model of its own: see GrenadeFinds.)
	if kind == GrenadeFinds.KIND:
		return GrenadeFinds.build_view()
	var root := Node3D.new()
	var batch := MeshBatch.new()
	var fabric := material(Color("733d36") if kind == "health" else Color("454e3c"))
	var rubber := material(Color("222b29"))
	var metal := material(Color("8e9894"), 0.65)
	var white := material(Color("d9dfcf"))
	var brass := material(Color("b89a58"), 0.7)
	var tint := Color("83b99c") if kind == "health" else Color("c7b183")
	batch.box(fabric, Vector3(0, 0.09, 0), Vector3(0.36, 0.16, 0.25))
	batch.box(rubber, Vector3(0, 0.015, 0), Vector3(0.37, 0.025, 0.26))
	batch.box(fabric, Vector3(0, 0.178, 0), Vector3(0.35, 0.018, 0.245))
	for x in [-0.12, 0.12]:
		batch.box(rubber, Vector3(x, 0.09, -0.128), Vector3(0.026, 0.16, 0.012))
		batch.box(rubber, Vector3(x, 0.19, 0), Vector3(0.026, 0.012, 0.25))
		batch.box(metal, Vector3(x, 0.09, -0.14), Vector3(0.036, 0.04, 0.012))
	for x in [-0.045, 0.045]:
		batch.box(rubber, Vector3(x, 0.208, 0.07), Vector3(0.012, 0.04, 0.014))
	batch.box(rubber, Vector3(0, 0.228, 0.07), Vector3(0.102, 0.013, 0.014))
	if kind == "health":
		batch.box(rubber, Vector3(0, 0.1, -0.13), Vector3(0.118, 0.1, 0.006))
		batch.box(white, Vector3(0, 0.1, -0.135), Vector3(0.075, 0.024, 0.004))
		batch.box(white, Vector3(0, 0.1, -0.136), Vector3(0.024, 0.075, 0.004))
		batch.box(white, Vector3(0, 0.19, -0.035), Vector3(0.08, 0.004, 0.024))
		batch.box(white, Vector3(0, 0.191, -0.035), Vector3(0.024, 0.004, 0.08))
	else:
		batch.box(white, Vector3(0, 0.1, -0.133), Vector3(0.12, 0.034, 0.004))
		batch.box(fabric, Vector3(0, 0.1, -0.136), Vector3(0.103, 0.021, 0.003))
		for x in [-0.05, 0.0, 0.05]:
			batch.cylinder(brass, Vector3(x, 0.233, -0.045), 0.011, 0.011, 0.09, Color.WHITE, 8)
			batch.cylinder(metal, Vector3(x, 0.29, -0.045), 0.0, 0.011, 0.024, Color.WHITE, 8)
	batch.commit(root, "Equipment", true)
	var light := OmniLight3D.new()
	light.name = "PickupGlow"
	light.light_color = tint
	light.light_energy = 0.32
	light.omni_range = 1.25
	light.omni_attenuation = 2.0
	light.position.y = 0.18
	light.light_cull_mask = 1
	root.add_child(light)
	var halo := MeshInstance3D.new()
	halo.name = "GroundHalo"
	var plane := QuadMesh.new()
	plane.size = Vector2(0.8, 0.65)
	halo.mesh = plane
	halo.rotation.x = -PI * 0.5
	halo.position.y = 0.006
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
void fragment() {
	float d = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = tint.rgb;
	ALPHA = (1.0 - smoothstep(0.15, 1.0, d)) * 0.13;
}
"""
	var glow := ShaderMaterial.new()
	glow.shader = shader
	glow.set_shader_parameter("tint", tint)
	halo.material_override = glow
	root.add_child(halo)
	return root
