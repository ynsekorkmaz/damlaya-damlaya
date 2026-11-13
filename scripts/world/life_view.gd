extends Node3D
## Canlılar: gölde yüzen balıklar ve gökyüzünde süzülen kuşlar (her tür tek MultiMesh).
## Sayılar Economy.fish_count / bird_count'tan gelir. Kuyruk ve kanat hareketi vertex shader'dadır (CPU'da kemik yok).
## Karede nesne/dizi tahsisi yok: durum PackedArray'lerde, örnek dönüşümleri her karede yazılır.
## Dış bağlantı: bind(game, lake, settings). Balık/kuş gölge atmaz (yalnızca Orta/Yüksek'te sahnede gölge vardır).

const Cfg = preload("res://scripts/core/life_config.gd")
const Economy = preload("res://scripts/core/economy.gd")
const EconomyCfg = preload("res://scripts/core/economy_config.gd")
const LakeShape = preload("res://scripts/core/lake_shape.gd")

const FISH_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
uniform float amp = 0.07;
uniform float hz = 3.2;
uniform float wave = 9.0;
uniform float glow = 0.5;

varying vec3 tint;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float tail = clamp(VERTEX.z / 0.3, 0.0, 1.0);
	VERTEX.x += sin(TIME * hz * cd.g + cd.b - VERTEX.z * wave) * amp * tail * tail;
	tint = vec3(cd.r);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	vec3 silver = vec3(l * 0.95, l * 1.0, l * 1.05) * 0.95 + vec3(0.05, 0.06, 0.08);
	ALBEDO = mix(c, silver, tint.x);
	ROUGHNESS = 0.6;
	EMISSION = ALBEDO * glow;
}
"""

const BIRD_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
uniform float amp = 0.1;
uniform float hz = 3.5;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float f = clamp(abs(VERTEX.x) / 0.52, 0.0, 1.0);
	VERTEX.y += sin(TIME * hz * cd.g + cd.r) * amp * f * f;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
}
"""

var game: Node
var lake: Node

var _rng := RandomNumberGenerator.new()
var _fish_mm: MultiMesh
var _bird_mm: MultiMesh
var _fish_inst: MultiMeshInstance3D
var _bird_inst: MultiMeshInstance3D

var _fish_max: int = 0
var _fish_pos := PackedVector2Array()
var _fish_head := PackedFloat32Array()
var _fish_turn := PackedFloat32Array()
var _fish_wander := PackedFloat32Array()
var _fish_timer := PackedFloat32Array()
var _fish_speed := PackedFloat32Array()
var _fish_scale := PackedFloat32Array()
var _fish_depth := PackedFloat32Array()
var _fish_phase := PackedFloat32Array()
var _fish_shown: float = 0.0
var _fish_placed: bool = false

var _bird_max: int = 0
var _bird_pos := PackedVector2Array()
var _bird_head := PackedFloat32Array()
var _bird_turn := PackedFloat32Array()
var _bird_sign := PackedFloat32Array()
var _bird_timer := PackedFloat32Array()
var _bird_speed := PackedFloat32Array()
var _bird_orbit := PackedFloat32Array()
var _bird_alt := PackedFloat32Array()
var _bird_phase := PackedFloat32Array()
var _clock: float = 0.0
var _shown_fish: int = 0
var _shown_birds: int = 0


func _ready() -> void:
	name = "Life"
	_rng.randomize()
	_fish_max = maxi(_array_max(EconomyCfg.FISH_BY_STAGE), 1)
	_bird_max = maxi(_array_max(EconomyCfg.BIRDS_BY_STAGE), 1)
	_fish_mm = _make_multimesh(Cfg.FISH_MODEL, _fish_max)
	_bird_mm = _make_multimesh(Cfg.BIRD_MODEL, _bird_max)
	_fish_inst = _make_instance("Fish", _fish_mm, FISH_SHADER)
	_bird_inst = _make_instance("Birds", _bird_mm, BIRD_SHADER)
	var fm: ShaderMaterial = _fish_inst.material_override
	fm.set_shader_parameter("amp", Cfg.FISH_WIGGLE_AMP)
	fm.set_shader_parameter("hz", Cfg.FISH_WIGGLE_HZ)
	fm.set_shader_parameter("wave", Cfg.FISH_WIGGLE_WAVE)
	fm.set_shader_parameter("glow", Cfg.FISH_GLOW)
	var bm: ShaderMaterial = _bird_inst.material_override
	bm.set_shader_parameter("amp", Cfg.BIRD_FLAP_AMP)
	bm.set_shader_parameter("hz", Cfg.BIRD_FLAP_HZ)
	_init_fish()
	_init_birds()


func bind(game_node: Node, lake_node: Node, settings: Node = null) -> void:
	game = game_node
	lake = lake_node
	if settings != null and settings.has_signal("quality_changed"):
		settings.connect("quality_changed", _on_quality_changed)


## Balık ve kuş her kalitede görünür; gölge zaten kapalı. Kalite değişince yalnızca görünürlük korunur.
func _on_quality_changed(_level: int) -> void:
	_fish_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bird_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _array_max(values: Array) -> int:
	var best: int = 0
	for v: int in values:
		best = maxi(best, v)
	return best


func _make_multimesh(path: String, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var scene: PackedScene = load(path)
	if scene != null:
		var root: Node = scene.instantiate()
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			mm.mesh = (node as MeshInstance3D).mesh
			break
		root.free()
	if mm.mesh == null:
		mm.mesh = BoxMesh.new()
	mm.instance_count = count
	mm.visible_instance_count = 0
	return mm


func _make_instance(node_name: String, mm: MultiMesh, code: String) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.custom_aabb = AABB(Vector3(-300.0, -60.0, -300.0), Vector3(600.0, 240.0, 600.0))
	add_child(inst)
	return inst


func _init_fish() -> void:
	_fish_pos.resize(_fish_max)
	_fish_head.resize(_fish_max)
	_fish_turn.resize(_fish_max)
	_fish_wander.resize(_fish_max)
	_fish_timer.resize(_fish_max)
	_fish_speed.resize(_fish_max)
	_fish_scale.resize(_fish_max)
	_fish_depth.resize(_fish_max)
	_fish_phase.resize(_fish_max)
	for i in range(_fish_max):
		_fish_head[i] = _rng.randf() * TAU
		_fish_wander[i] = _fish_head[i]
		_fish_timer[i] = _rng.randf_range(Cfg.FISH_WANDER_MIN_SEC, Cfg.FISH_WANDER_MAX_SEC)
		_fish_speed[i] = _rng.randf_range(Cfg.FISH_SPEED_MIN, Cfg.FISH_SPEED_MAX)
		_fish_scale[i] = _rng.randf_range(Cfg.FISH_SCALE_MIN, Cfg.FISH_SCALE_MAX)
		_fish_depth[i] = _rng.randf_range(Cfg.FISH_DEPTH_MIN, Cfg.FISH_DEPTH_MAX)
		_fish_phase[i] = _rng.randf() * TAU
		var silver: float = 1.0 if _rng.randf() < Cfg.FISH_SILVER_CHANCE else 0.0
		_fish_mm.set_instance_custom_data(i, Color(silver, _rng.randf_range(0.8, 1.3), _fish_phase[i], 0.0))


func _init_birds() -> void:
	_bird_pos.resize(_bird_max)
	_bird_head.resize(_bird_max)
	_bird_turn.resize(_bird_max)
	_bird_sign.resize(_bird_max)
	_bird_timer.resize(_bird_max)
	_bird_speed.resize(_bird_max)
	_bird_orbit.resize(_bird_max)
	_bird_alt.resize(_bird_max)
	_bird_phase.resize(_bird_max)
	for i in range(_bird_max):
		var a: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(Cfg.BIRD_ORBIT_MIN, Cfg.BIRD_ORBIT_MAX)
		_bird_pos[i] = Vector2(cos(a), sin(a)) * r
		_bird_head[i] = a + PI * 0.5
		_bird_sign[i] = 1.0 if _rng.randf() < 0.5 else -1.0
		_bird_timer[i] = _rng.randf_range(Cfg.BIRD_REVERSE_MIN_SEC, Cfg.BIRD_REVERSE_MAX_SEC)
		_bird_speed[i] = _rng.randf_range(Cfg.BIRD_SPEED_MIN, Cfg.BIRD_SPEED_MAX)
		_bird_orbit[i] = _rng.randf_range(Cfg.BIRD_ORBIT_MIN, Cfg.BIRD_ORBIT_MAX)
		_bird_alt[i] = _rng.randf_range(Cfg.BIRD_ALT_MIN, Cfg.BIRD_ALT_MAX)
		_bird_phase[i] = _rng.randf() * TAU
		var speed_mul: float = 1.0 + _rng.randf_range(-Cfg.BIRD_FLAP_VARIATION, Cfg.BIRD_FLAP_VARIATION)
		_bird_mm.set_instance_custom_data(i, Color(_bird_phase[i], speed_mul, 0.0, 0.0))


func _process(delta: float) -> void:
	if game == null or lake == null:
		return
	_clock += delta
	var state: Object = game.get("state")
	var radius: float = float(lake.call("shore_radius"))
	var level: float = float(lake.call("water_level"))
	var bottom: float = LakeShape.bottom_level(state.total_drops)
	_update_fish(delta, Economy.fish_count(state), radius, level, level - bottom)
	_update_birds(delta, Economy.bird_count(state), level)


func _update_fish(delta: float, want: int, radius: float, level: float, water_depth: float) -> void:
	var target: float = 1.0 if radius >= Cfg.FISH_MIN_LAKE_RADIUS else 0.0
	_fish_shown = move_toward(_fish_shown, target, delta / maxf(Cfg.FISH_FADE_IN_SEC, 0.01))
	var count: int = mini(want, _fish_max) if _fish_shown > 0.0 else 0
	if count != _shown_fish:
		_shown_fish = count
		_fish_mm.visible_instance_count = count
	if count == 0:
		_fish_placed = false
		return
	var edge: float = radius * Cfg.FISH_EDGE_FRAC
	if not _fish_placed:
		_fish_placed = true
		for i in range(_fish_max):
			var a: float = _rng.randf() * TAU
			var r: float = sqrt(_rng.randf()) * edge * 0.9
			_fish_pos[i] = Vector2(cos(a), sin(a)) * r
	for i in range(count):
		var pos: Vector2 = _fish_pos[i]
		var head: float = _fish_head[i]
		_fish_timer[i] -= delta
		if _fish_timer[i] <= 0.0:
			_fish_timer[i] = _rng.randf_range(Cfg.FISH_WANDER_MIN_SEC, Cfg.FISH_WANDER_MAX_SEC)
			_fish_wander[i] = head + _rng.randf_range(-Cfg.FISH_WANDER_ANGLE, Cfg.FISH_WANDER_ANGLE)
		var desired: float = _fish_wander[i]
		var dist: float = pos.length()
		if dist > edge:
			# kıyıya yaklaşınca yavaşça gölün içine doğru döner; ne kadar aşarsa o kadar kararlı
			var inward: float = atan2(-pos.y, -pos.x)
			var k: float = clampf((dist - edge) / maxf(radius * 0.2, 0.1), 0.0, 1.0)
			desired = head + angle_difference(head, inward) * k + angle_difference(head, desired) * (1.0 - k)
		var diff: float = angle_difference(head, desired)
		var want_turn: float = clampf(diff * 1.5, -Cfg.FISH_TURN_MAX, Cfg.FISH_TURN_MAX)
		_fish_turn[i] = lerpf(_fish_turn[i], want_turn, 1.0 - exp(-Cfg.FISH_TURN_SMOOTH * delta))
		head += _fish_turn[i] * delta
		_fish_head[i] = head
		var speed: float = _fish_speed[i] * (1.0 + Cfg.FISH_SPEED_WAVE * sin(_clock * TAU * Cfg.FISH_SPEED_WAVE_HZ + _fish_phase[i]))
		pos += Vector2(cos(head), sin(head)) * speed * delta
		_fish_pos[i] = pos
		var local_depth: float = water_depth * maxf(1.0 - (dist * dist) / maxf(radius * radius, 0.01), 0.0)
		var dep: float = _fish_depth[i] + Cfg.FISH_DEPTH_WAVE * sin(_clock * TAU * Cfg.FISH_DEPTH_WAVE_HZ + _fish_phase[i] * 2.0)
		dep = minf(dep, local_depth * Cfg.FISH_DEPTH_FRAC)
		dep = maxf(dep, Cfg.FISH_DEPTH_MIN * 0.5)
		# baş -Z: ileri yön (cos head, 0, sin head)
		var fwd := Vector3(cos(head), 0.0, sin(head))
		var z_axis: Vector3 = -fwd
		var x_axis: Vector3 = Vector3.UP.cross(z_axis)
		var roll: float = clampf(_fish_turn[i] * Cfg.FISH_ROLL_PER_TURN, -0.5, 0.5)
		var y_axis: Vector3 = z_axis.cross(x_axis)
		y_axis = y_axis.rotated(fwd, roll)
		x_axis = y_axis.cross(z_axis)
		var sc: float = _fish_scale[i] * smoothstep(0.0, 1.0, _fish_shown)
		var basis := Basis(x_axis * sc, y_axis * sc, z_axis * sc)
		_fish_mm.set_instance_transform(i, Transform3D(basis, Vector3(pos.x, level - dep, pos.y)))


func _update_birds(delta: float, want: int, level: float) -> void:
	var count: int = mini(want, _bird_max)
	if count != _shown_birds:
		_shown_birds = count
		_bird_mm.visible_instance_count = count
	var max_bank: float = deg_to_rad(Cfg.BIRD_MAX_BANK_DEG)
	for i in range(count):
		var pos: Vector2 = _bird_pos[i]
		var head: float = _bird_head[i]
		_bird_timer[i] -= delta
		if _bird_timer[i] <= 0.0:
			_bird_timer[i] = _rng.randf_range(Cfg.BIRD_REVERSE_MIN_SEC, Cfg.BIRD_REVERSE_MAX_SEC)
			_bird_sign[i] = -_bird_sign[i]
			_bird_orbit[i] = _rng.randf_range(Cfg.BIRD_ORBIT_MIN, Cfg.BIRD_ORBIT_MAX)
		var sgn: float = _bird_sign[i]
		var speed: float = _bird_speed[i]
		if pos.length() > Cfg.BIRD_RANGE:
			# merkeze (göle) doğru dön: hedef yön ile bakış arasındaki işarete göre
			var d: float = angle_difference(head, atan2(-pos.y, -pos.x))
			sgn = 1.0 if d >= 0.0 else -1.0
		var want_turn: float = sgn * speed / _bird_orbit[i]
		_bird_turn[i] = lerpf(_bird_turn[i], want_turn, 1.0 - exp(-Cfg.BIRD_TURN_SMOOTH * delta))
		head += _bird_turn[i] * delta
		_bird_head[i] = head
		var fwd := Vector3(cos(head), 0.0, sin(head))
		pos += Vector2(fwd.x, fwd.z) * speed * delta
		_bird_pos[i] = pos
		var alt: float = _bird_alt[i] + Cfg.BIRD_ALT_WAVE * sin(_clock * TAU * Cfg.BIRD_ALT_WAVE_HZ + _bird_phase[i])
		var bank: float = clampf(atan(_bird_turn[i] * speed / Cfg.BIRD_GRAVITY), -max_bank, max_bank)
		# artan başlık açısı = sağa dönüş; sağa dönüşte sağ kanat aşağı (yerel Z çevresinde eksi dönüş)
		var z_axis: Vector3 = -fwd
		var x_axis: Vector3 = Vector3.UP.cross(z_axis)
		var y_axis: Vector3 = z_axis.cross(x_axis)
		y_axis = y_axis.rotated(fwd, bank)
		x_axis = y_axis.cross(z_axis)
		var basis := Basis(x_axis * Cfg.BIRD_SCALE, y_axis * Cfg.BIRD_SCALE, z_axis * Cfg.BIRD_SCALE)
		_bird_mm.set_instance_transform(i, Transform3D(basis, Vector3(pos.x, level + alt, pos.y)))
