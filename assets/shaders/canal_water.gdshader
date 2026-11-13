// Kanal suyu: UV'nin V ekseni akış yönündedir; desen flow_dir yönünde kayar. Yarı saydam mavi, hafif dalga.
// Forward+ ve Compatibility'de derlenir (derinlik dokusu, ekran dokusu kullanılmaz).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 shallow_color : source_color = vec4(0.55, 0.80, 0.95, 1.0);
uniform vec4 deep_color : source_color = vec4(0.20, 0.50, 0.78, 1.0);
uniform float flow_speed = 0.9;
uniform float flow_dir = 1.0;      // +1: desen +V yönüne akar, -1: -V yönüne
uniform float wave_len = 0.5;      // V biriminde (metre) dalga boyu
uniform float alpha_base = 0.74;
uniform float edge_soft = 0.0;     // 1: UV.x kenarlarında saydamlaşır (dere şeritleri)
uniform float cross_freq = 9.0;

void fragment() {
	float t = TIME * flow_speed * flow_dir;
	float a = sin((UV.y - t) * 6.2831 / wave_len);
	float b = sin((UV.y * 1.7 - t * 1.3) * 6.2831 / wave_len + UV.x * cross_freq);
	float s = 0.5 + 0.25 * a + 0.25 * b;
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, s);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	float edge = mix(1.0, smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x), edge_soft);
	ALPHA = alpha_base * (0.85 + 0.15 * s) * edge;
}
