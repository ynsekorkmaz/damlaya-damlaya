extends Node3D
## Çukurdaki su: tek disk mesh, iki sinüs dalgalı gölgelendirici, doluluğa göre yükselen seviye
## ve dökme anında genişleyip solan halka dalgalar (hazır havuz).

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const LakeShape = preload("res://scripts/core/lake_shape.gd")
const GraphicsConfig = preload("res://scripts/core/graphics_config.gd")

## Su gölgelendiricisi. Önişlemci ile üç kademe: 0 sade, FRESNEL (Orta), + DETAIL (Yüksek);
## DEPTH_FADE (kıyıda derinliğe göre saydamlık) Compatibility'de eklenmez.
const WATER_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

#ifdef DEPTH_FADE
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
#endif

uniform vec4 shallow_color : source_color;
uniform vec4 deep_color : source_color;
uniform vec4 sky_color : source_color;
uniform float amp1;
uniform float amp2;
uniform float freq1;
uniform float freq2;
uniform float speed1;
uniform float speed2;
uniform float alpha_center;
uniform float alpha_edge;
uniform float fade = 1.0;
uniform float depth_fade_dist = 0.8;
uniform float shore_alpha = 0.15;
uniform float fresnel_power = 4.0;
uniform float fresnel_amount = 0.5;
uniform float water_roughness = 0.2;
uniform float water_specular = 0.35;
uniform float detail_amp = 0.0;

varying vec2 slope;
varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float p1 = w.x * freq1 + w.z * freq1 * 0.4 + TIME * speed1;
	float p2 = w.z * freq2 - w.x * freq2 * 0.3 - TIME * speed2;
	VERTEX.y += amp1 * sin(p1) + amp2 * sin(p2);
	slope = vec2(
		amp1 * freq1 * cos(p1) - amp2 * freq2 * 0.3 * cos(p2),
		amp1 * freq1 * 0.4 * cos(p1) + amp2 * freq2 * cos(p2));
	wpos = w;
}

void fragment() {
	vec2 s = slope;
#ifdef DETAIL
	vec2 q = wpos.xz;
	s += detail_amp * (
		vec2(0.8, 0.6) * cos(dot(q, vec2(0.8, 0.6)) * 6.1 + TIME * 1.3)
		+ vec2(-0.5, 0.86) * cos(dot(q, vec2(-0.5, 0.86)) * 9.7 - TIME * 1.7)
		+ vec2(0.2, -0.98) * cos(dot(q, vec2(0.2, -0.98)) * 14.3 + TIME * 2.1));
#endif
	vec3 n = normalize(vec3(-s.x, 1.0, -s.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float rim = COLOR.r;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, rim);
	float alpha = mix(alpha_center, alpha_edge, rim);
#ifdef DEPTH_FADE
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	behind.xyz /= behind.w;
	float thick = max(VERTEX.z - behind.z, 0.0);
	float k = smoothstep(0.0, depth_fade_dist, thick);
	alpha *= mix(shore_alpha, 1.0, k);
	col = mix(shallow_color.rgb, col, k);
#endif
#ifdef FRESNEL
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	col = mix(col, sky_color.rgb, f * fresnel_amount);
	alpha = mix(alpha, 1.0, f * 0.5);
#endif
	ALBEDO = col;
	ROUGHNESS = water_roughness;
	SPECULAR = water_specular;
	ALPHA = alpha * fade;
}
"""
var game: Node
var player: Node3D

var _water: MeshInstance3D
var _material: ShaderMaterial
var _shaders: Array[Shader] = []   # kalite kademesine göre gölgelendirici
var _water_level_quality: int = -1
var _level: float = 0.0
var _radius: float = 0.0
var _shore_timer: float = 0.0
var _shore_level: float = -1000.0
var _shore_basin: float = -1.0
var _initialized: bool = false
var _ripples: Array[MeshInstance3D] = []
var _ripple_age: Array[float] = []
var _ripple_next: int = 0


func _ready() -> void:
	name = "Lake"
	_material = ShaderMaterial.new()
	_material.shader = shader_for(0)
	_material.set_shader_parameter("shallow_color", Palette.WATER)
	_material.set_shader_parameter("deep_color", Palette.WATER_DEEP)
	_material.set_shader_parameter("amp1", Config.LAKE_WAVE_AMP_1)
	_material.set_shader_parameter("amp2", Config.LAKE_WAVE_AMP_2)
	_material.set_shader_parameter("freq1", Config.LAKE_WAVE_FREQ_1)
	_material.set_shader_parameter("freq2", Config.LAKE_WAVE_FREQ_2)
	_material.set_shader_parameter("speed1", Config.LAKE_WAVE_SPEED_1)
	_material.set_shader_parameter("speed2", Config.LAKE_WAVE_SPEED_2)
	_material.set_shader_parameter("alpha_center", Config.LAKE_ALPHA_CENTER)
	_material.set_shader_parameter("alpha_edge", Config.LAKE_ALPHA_EDGE)
	_material.set_shader_parameter("sky_color", Config.LAKE_SKY_COLOR)
	_material.set_shader_parameter("depth_fade_dist", Config.LAKE_DEPTH_FADE)
	_material.set_shader_parameter("shore_alpha", Config.LAKE_SHORE_ALPHA)
	_material.set_shader_parameter("fresnel_power", Config.LAKE_FRESNEL_POWER)
	_material.set_shader_parameter("fresnel_amount", Config.LAKE_FRESNEL_AMOUNT)

	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.mesh = build_disk_mesh()
	_water.material_override = _material
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.visible = false
	add_child(_water)

	var ring_mesh: ArrayMesh = build_ring_mesh()
	for i in range(Config.RIPPLE_POOL):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(Palette.RIPPLE, 0.0)
		var ring := MeshInstance3D.new()
		ring.name = "Ripple%d" % i
		ring.mesh = ring_mesh
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_ripples.append(ring)
		_ripple_age.append(-1.0)


## Kalite ayarına bağlanır: su gölgelendirici kademesi kalite değişince anında değişir.
func connect_quality(settings: Node) -> void:
	settings.connect("quality_changed", _on_quality_changed)
	_on_quality_changed(settings.get("level"))


func _on_quality_changed(level: int) -> void:
	var tier: int = int(GraphicsConfig.preset(level)["water"])
	if tier == _water_level_quality:
		return
	_water_level_quality = tier
	_material.shader = shader_for(tier)
	var advanced: bool = tier > 0
	_material.set_shader_parameter("water_roughness", Config.LAKE_ROUGHNESS_ADV if advanced else 0.2)
	_material.set_shader_parameter("water_specular", Config.LAKE_SPECULAR_ADV if advanced else 0.35)
	_material.set_shader_parameter("detail_amp", Config.LAKE_DETAIL_AMP if tier >= 2 else 0.0)


## Kademeye göre derlenmiş gölgelendirici (ilk kullanımda üretilir, sonra önbellekten).
## Derinlik dokusu yalnızca Compatibility dışında kullanılır.
func shader_for(tier: int) -> Shader:
	while _shaders.size() <= tier:
		_shaders.append(null)
	if _shaders[tier] == null:
		var defines: String = ""
		if tier >= 1:
			defines += "#define FRESNEL\n"
			if RenderingServer.get_current_rendering_method() != "gl_compatibility":
				defines += "#define DEPTH_FADE\n"
		if tier >= 2:
			defines += "#define DETAIL\n"
		var shader := Shader.new()
		shader.code = defines + WATER_SHADER
		_shaders[tier] = shader
	return _shaders[tier]


func bind(game_node: Node, player_node: Node3D) -> void:
	game = game_node
	player = player_node
	game.connect("poured", _on_poured)


func _process(delta: float) -> void:
	if game == null:
		return
	var state: Object = game.get("state")
	var total: float = state.total_drops
	var basin_r: float = BasinShape.radius(total)
	var basin_d: float = BasinShape.depth(total)
	var target: float = LakeShape.level(total)
	if not _initialized:
		_level = target
		_initialized = true
	else:
		_level = lerpf(_level, target, 1.0 - exp(-Config.LAKE_LEVEL_SPEED * delta))
	# Kıyı hesabı ışın atar: seviye ya da çanak değişince, en sık belirli aralıkla
	_shore_timer += delta
	if _shore_timer >= Config.LAKE_SHORE_INTERVAL and (absf(_level - _shore_level) > 0.003 or absf(basin_r - _shore_basin) > 0.01 or _shore_basin < 0.0):
		_shore_timer = 0.0
		_shore_level = _level
		_shore_basin = basin_r
		_radius = LakeShape.shore_radius(_level, basin_r, basin_d)
	var shown: bool = total > 0.0 and _radius > 0.05
	_water.visible = shown
	if shown:
		var r: float = _radius + Config.LAKE_RADIUS_MARGIN
		_water.position = Vector3(0.0, _level, 0.0)
		_water.scale = Vector3(r, 1.0, r)
		var depth: float = _level - LakeShape.bottom_level(total)
		_material.set_shader_parameter("fade", clampf(depth / Config.LAKE_ALPHA_FADE_IN, 0.0, 1.0))
	_update_ripples(delta)


func _on_poured(_drops: float, _money: float) -> void:
	var pos := Vector2.ZERO
	if player != null:
		pos = Vector2(player.global_position.x, player.global_position.z)
		var limit: float = maxf(_radius * 0.85, 0.0)
		if pos.length() > limit:
			pos = pos.normalized() * limit
	var index: int = _ripple_next
	_ripple_next = (_ripple_next + 1) % Config.RIPPLE_POOL
	_ripple_age[index] = 0.0
	_ripples[index].position = Vector3(pos.x, _level + Config.RIPPLE_LIFT, pos.y)
	_ripples[index].visible = true


func _update_ripples(delta: float) -> void:
	for i in range(_ripples.size()):
		if _ripple_age[i] < 0.0:
			continue
		_ripple_age[i] += delta
		var t: float = _ripple_age[i] / Config.RIPPLE_SECONDS
		var ring: MeshInstance3D = _ripples[i]
		if t >= 1.0:
			_ripple_age[i] = -1.0
			ring.visible = false
			continue
		var grow: float = 1.0 - (1.0 - t) * (1.0 - t)
		var s: float = lerpf(Config.RIPPLE_START_RADIUS, Config.RIPPLE_MAX_RADIUS, grow)
		ring.scale = Vector3(s, 1.0, s)
		ring.position.y = _level + Config.RIPPLE_LIFT
		var mat: StandardMaterial3D = ring.material_override
		mat.albedo_color = Color(Palette.RIPPLE, 0.75 * (1.0 - t) * (1.0 - t))


## Birim yarıçaplı disk; vertex color kırmızı kanalı merkezde 0, kenarda 1.
static func build_disk_mesh() -> ArrayMesh:
	var segs: int = Config.LAKE_SEGMENTS
	var rings: int = Config.LAKE_RINGS
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	colors.append(Color(0.0, 0.0, 0.0, 1.0))
	for ri in range(1, rings + 1):
		var f: float = float(ri) / float(rings)
		for j in range(segs):
			var ang: float = TAU * float(j) / float(segs)
			verts.append(Vector3(cos(ang) * f, 0.0, sin(ang) * f))
			normals.append(Vector3.UP)
			colors.append(Color(f * f, 0.0, 0.0, 1.0))
	for j in range(segs):
		var j2: int = (j + 1) % segs
		idx.append_array([0, 1 + j2, 1 + j])
	for ri in range(1, rings):
		var base: int = 1 + (ri - 1) * segs
		var next: int = base + segs
		for j in range(segs):
			var j2: int = (j + 1) % segs
			idx.append_array([base + j, base + j2, next + j2, base + j, next + j2, next + j])
	return _make(verts, normals, colors, idx)


## Düz halka: dış yarıçap 1, iç yarıçap 1 - RIPPLE_WIDTH.
static func build_ring_mesh() -> ArrayMesh:
	var segs: int = Config.RIPPLE_SEGMENTS
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in range(segs):
		var ang: float = TAU * float(j) / float(segs)
		verts.append(Vector3(cos(ang), 0.0, sin(ang)))
		verts.append(Vector3(cos(ang), 0.0, sin(ang)) * (1.0 - Config.RIPPLE_WIDTH))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	for j in range(segs):
		var j2: int = (j + 1) % segs
		var o1: int = j * 2
		var i1: int = o1 + 1
		var o2: int = j2 * 2
		var i2: int = o2 + 1
		idx.append_array([o1, o2, i2, o1, i2, i1])
	return _make(verts, normals, PackedColorArray(), idx)


static func _make(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		idx: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
