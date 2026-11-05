shader_type spatial;
render_mode cull_disabled;

uniform sampler2D garment_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D garment_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D leather_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D leather_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D leather_arm : filter_linear_mipmap, repeat_enable;
uniform vec3 leather_tint : source_color = vec3(0.92, 0.82, 0.70);
uniform float tile_scale = 4.0;
uniform float source_normal_strength = 0.20;

void fragment() {
	vec3 source = texture(garment_color, UV).rgb;
	float seam = clamp(dot(source, vec3(0.2126, 0.7152, 0.0722)) * 0.5 + 0.63, 0.63, 1.0);
	vec2 tile_uv = UV * tile_scale;
	ALBEDO = texture(leather_color, tile_uv).rgb * leather_tint * seam;
	vec3 arm = texture(leather_arm, tile_uv).rgb;
	AO = arm.r;
	ROUGHNESS = clamp(arm.g * 0.40 + 0.55, 0.72, 0.94);
	SPECULAR = 0.28;
	METALLIC = 0.0;
	vec3 source_n = texture(garment_normal, UV).rgb * 2.0 - 1.0;
	vec3 leather_n = texture(leather_normal, tile_uv).rgb * 2.0 - 1.0;
	source_n.z = sqrt(max(0.001, 1.0-dot(source_n.xy,source_n.xy)));
	leather_n.z = sqrt(max(0.001, 1.0-dot(leather_n.xy,leather_n.xy)));
	NORMAL_MAP = normalize(vec3(source_n.xy * source_normal_strength + leather_n.xy * 0.10,
		max(0.1, source_n.z * leather_n.z))) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
