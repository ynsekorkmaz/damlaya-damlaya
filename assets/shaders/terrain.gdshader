shader_type spatial;
render_mode specular_disabled;
// Arazi: dünya XZ koordinatından doku örnekler. Vertex rengi karışım ağırlığıdır:
// R = çimen, G = toprak, B = kaya, A = çimenin kuruma oranı.
// Her katman yakın ve uzak ölçekte (uzak olan döndürülmüş) örneklenip karıştırılır; döşeme tekrarı belli olmaz.
// Ağırlığı sıfıra yakın katman hiç örneklenmez.
// Normal haritası (normal_strength > 0): XZ düzlemine izdüşüm, UDN karışımı (köşegen yüzeylerde bozulmaz);
// aynı hesap dış arazi ve çanak yamasında olduğundan dikiş çıkmaz. Forward+ ve Compatibility'de aynı derlenir.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float normal_strength = 0.0; // 0 = normal haritası kapalı (doku örneklenmez)
uniform float tile_near = 3.0;   // m, yakın ölçekte bir döşeme
uniform float tile_far = 13.0;   // m, uzak ölçek
uniform float far_mix_min = 0.3; // uzak ölçeğin yakındaki payı
uniform float far_mix_max = 0.65;// uzakta payı
uniform float far_dist_start = 8.0;
uniform float far_dist_end = 60.0;
uniform float far_rotation = 0.55; // radyan
uniform float far_mip_bias = 0.0;   // uzakta dokuyu bulanıklaştırır (2k doku uzak tepelerde gürültülü durmasın)

uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 grass_dark_tint : source_color = vec3(0.8);
uniform vec3 dry_tint : source_color = vec3(1.0);
uniform vec3 soil_tint : source_color = vec3(1.0);
uniform vec3 soil_dark_tint : source_color = vec3(0.8);
uniform vec3 rock_tint : source_color = vec3(1.0);
uniform vec3 rock_dark_tint : source_color = vec3(0.8);

uniform vec2 wave_freq = vec2(0.045, 0.037);
uniform float wave_amount = 0.55;
uniform float hill_wave_freq = 0.11;
uniform float hill_wave_amount = 0.35;

varying vec3 wpos;

vec3 layer(sampler2D tex, vec2 xz, float far_t, float bias) {
	vec3 a = texture(tex, xz / tile_near, bias).rgb;
	float c = cos(far_rotation);
	float s = sin(far_rotation);
	vec2 r = vec2(c * xz.x - s * xz.y, s * xz.x + c * xz.y) / tile_far + vec2(0.37, 0.61);
	vec3 b = texture(tex, r, bias).rgb;
	return mix(a, b, far_t);
}

// Normal haritasından dünya XZ eğim sapması (UDN). Yeşil kanal görüntüde yukarı = dünyada -Z.
vec2 nlayer(sampler2D tex, vec2 xz, float far_t) {
	vec2 a = texture(tex, xz / tile_near).rg * 2.0 - 1.0;
	float c = cos(far_rotation);
	float s = sin(far_rotation);
	vec2 r = vec2(c * xz.x - s * xz.y, s * xz.x + c * xz.y) / tile_far + vec2(0.37, 0.61);
	vec2 b = texture(tex, r).rg * 2.0 - 1.0;
	vec2 pa = vec2(a.x, -a.y);
	vec2 pb = vec2(b.x, -b.y);
	// döndürülmüş örneklemenin eğimini dünyaya geri döndür
	pb = vec2(c * pb.x + s * pb.y, -s * pb.x + c * pb.y);
	return mix(pa, pb, far_t);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 w = COLOR;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float far_t = mix(far_mix_min, far_mix_max, smoothstep(far_dist_start, far_dist_end, dist));
	float bias = far_mip_bias * smoothstep(far_dist_start * 2.0, far_dist_end * 1.5, dist);
	float wave = 0.5 + 0.5 * sin(wpos.x * wave_freq.x + 1.3) * cos(wpos.z * wave_freq.y - 0.7);
	float hwave = 0.5 + 0.5 * sin(wpos.x * hill_wave_freq + 0.6) * sin(wpos.z * hill_wave_freq * 1.3 + 1.9);
	vec3 col = vec3(0.0);
	vec2 slope = vec2(0.0);
	bool use_n = normal_strength > 0.0;
	float total = w.r + w.g + w.b + 0.0001;
	if (w.r > 0.004) {
		vec3 g = layer(grass_tex, wpos.xz, far_t, bias);
		float lum = dot(g, vec3(0.3, 0.55, 0.15));
		vec3 green = g * mix(grass_tint, grass_dark_tint, wave * wave_amount);
		vec3 dry = vec3(lum) * dry_tint;
		col += mix(green, dry, w.a) * w.r;
		if (use_n) {
			slope += nlayer(grass_nor, wpos.xz, far_t) * w.r;
		}
	}
	if (w.g > 0.004) {
		col += layer(soil_tex, wpos.xz, far_t, bias) * mix(soil_tint, soil_dark_tint, hwave * hill_wave_amount) * w.g;
		if (use_n) {
			slope += nlayer(soil_nor, wpos.xz, far_t) * w.g;
		}
	}
	if (w.b > 0.004) {
		col += layer(rock_tex, wpos.xz, far_t, bias) * mix(rock_tint, rock_dark_tint, hwave) * w.b;
		if (use_n) {
			slope += nlayer(rock_nor, wpos.xz, far_t) * w.b;
		}
	}
	ALBEDO = col / total;
	ROUGHNESS = 1.0;
	if (use_n) {
		// Uzakta normal ayrıntısı sönsün (parıltı ve tekrar desenini önler)
		float fade = 1.0 - smoothstep(far_dist_start * 1.5, far_dist_end, dist);
		vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		wn = normalize(vec3(wn.x + slope.x * normal_strength * fade / total, wn.y, wn.z + slope.y * normal_strength * fade / total));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}
