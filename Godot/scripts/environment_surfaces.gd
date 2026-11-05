extends RefCounted
## Distinct dry blood, wet wall runoff, and pooled residue, using authored masks
## and CC0 PBR detail. The source maps remain 4K; runtime imports are capped at 2K.

const BLOOD_ATLAS := "res://assets/generated/blood_variants_v3.png"
const GOO_ATLAS := "res://assets/generated/goo_variants_v3.png"
const WEB_ROOT := "res://assets/third_party/texturecan/cobweb_0015/others_0015_"
const LEAK_ROOT := "res://assets/third_party/ambientcg/"

const GOO_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_roughness : filter_linear_mipmap, repeat_enable;
void fragment() {
    vec4 stain = texture(atlas, UV);
    ALBEDO = stain.rgb * vec3(0.67, 0.64, 0.60);
    ALPHA = stain.a;
    ALPHA_SCISSOR_THRESHOLD = 0.22;
    vec2 packed_normal = texture(detail_normal, UV2).rg;
    vec2 normal_xy = packed_normal * 2.0 - 1.0;
    NORMAL_MAP = vec3(packed_normal, sqrt(max(0.0, 1.0 - dot(normal_xy, normal_xy))) * 0.5 + 0.5);
    NORMAL_MAP_DEPTH = 0.48;
    ROUGHNESS = mix(0.24, 0.62, texture(detail_roughness, UV2).r);
    METALLIC = 0.0;
    SPECULAR = 0.45;
}
"""

const WEB_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D silk_color : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D silk_opacity : filter_linear_mipmap, repeat_disable;
uniform sampler2D silk_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D silk_roughness : filter_linear_mipmap, repeat_disable;
uniform sampler2D silk_ao : filter_linear_mipmap, repeat_disable;
void fragment() {
    ALBEDO = texture(silk_color, UV).rgb * vec3(0.54, 0.50, 0.43);
    ALPHA = texture(silk_opacity, UV).r;
    ALPHA_SCISSOR_THRESHOLD = 0.17;
    vec2 packed_normal = texture(silk_normal, UV).rg;
    vec2 normal_xy = packed_normal * 2.0 - 1.0;
    NORMAL_MAP = vec3(packed_normal, sqrt(max(0.0, 1.0 - dot(normal_xy, normal_xy))) * 0.5 + 0.5);
    NORMAL_MAP_DEPTH = 0.4;
    ROUGHNESS = max(0.78, texture(silk_roughness, UV).r);
    AO = texture(silk_ao, UV).r;
    SPECULAR = 0.12;
}
"""

static func blood_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Dried oxblood / four distinct masks"
	material.albedo_texture = load(BLOOD_ATLAS)
	material.albedo_color = Color(0.58, 0.27, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.22
	material.roughness = 0.94
	material.metallic_specular = 0.15
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

static func goo_material(floor_surface: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GOO_SHADER
	material.shader = shader
	material.resource_name = "Pooled black residue" if floor_surface else "Wet arachnoid wall runoff"
	var asset := "Leaking019C" if floor_surface else "Leaking012C"
	var prefix := LEAK_ROOT + asset + "/" + asset + "_4K-PNG_"
	material.set_shader_parameter("atlas", load(GOO_ATLAS))
	material.set_shader_parameter("detail_normal", load(prefix + "NormalGL.png"))
	material.set_shader_parameter("detail_roughness", load(prefix + "Roughness.png"))
	return material

static func orb_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WEB_SHADER
	material.shader = shader
	material.resource_name = "TextureCan damaged cobweb / CC0 PBR"
	material.set_shader_parameter("silk_color", load(WEB_ROOT + "color_4k.jpg"))
	material.set_shader_parameter("silk_opacity", load(WEB_ROOT + "opacity_4k.jpg"))
	material.set_shader_parameter("silk_normal", load(WEB_ROOT + "normal_opengl_4k.png"))
	material.set_shader_parameter("silk_roughness", load(WEB_ROOT + "roughness_4k.jpg"))
	material.set_shader_parameter("silk_ao", load(WEB_ROOT + "ao_4k.jpg"))
	return material

static func residue_mesh(sites: Array[Dictionary]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	# Three surfaces keep the flashlight response physically different without
	# creating a material/node/draw call for every stain.
	for surface in range(3):
		var selected: Array[Dictionary] = []
		for index in range(sites.size()):
			var site := sites[index].duplicate()
			var is_floor: bool = site.normal.dot(Vector3.UP) > 0.99
			var target := 0 if int(site.kind) == 0 else (2 if is_floor else 1)
			if target != surface: continue
			# The original placement alternates blood/goo. A separate variation
			# sequence avoids giving every blood or goo card the same tile.
			var tile := (2 if is_floor else 0) + floori(index * 0.5) % 2
			site.uv_rect = Rect2(Vector2(float(tile % 2), floorf(tile * 0.5)) * 0.5 + Vector2.ONE * 0.006, Vector2.ONE * 0.488)
			selected.append(site)
		if selected.is_empty(): continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, card_arrays(selected))
		mesh.surface_set_material(mesh.get_surface_count() - 1,
			blood_material() if surface == 0 else goo_material(surface == 2))
	return mesh

static func card_arrays(sites: Array[Dictionary]) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var detail_uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for site in sites:
		var center: Vector3 = site.center
		var u: Vector3 = site.u
		var v: Vector3 = site.v
		var rotation := Basis(u.cross(v).normalized(), float(site.get("tilt", 0.0)))
		u = rotation * u
		v = rotation * v
		var outward: Vector3 = site.normal
		var tangent := u.normalized()
		var handedness := signf(outward.cross(tangent).dot(-v.normalized()))
		var base := vertices.size()
		vertices.append_array(PackedVector3Array([center - u * 0.5 - v * 0.5,
			center + u * 0.5 - v * 0.5, center - u * 0.5 + v * 0.5, center + u * 0.5 + v * 0.5]))
		for corner in range(4):
			normals.append(outward)
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, handedness]))
		var rect: Rect2 = site.get("uv_rect", Rect2(0, 0, 1, 1))
		uvs.append_array(PackedVector2Array([Vector2(rect.position.x, rect.end.y), rect.end,
			rect.position, Vector2(rect.end.x, rect.position.y)]))
		# Detail density is metres-based, independent of the atlas quadrant.
		detail_uvs.append_array(PackedVector2Array([Vector2(0, v.length()),
			Vector2(u.length(), v.length()), Vector2.ZERO, Vector2(u.length(), 0)]))
		if u.cross(v).dot(outward) > 0.0:
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
		else:
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = detail_uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
