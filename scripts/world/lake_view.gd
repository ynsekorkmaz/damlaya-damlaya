extends Node3D
## Çukurdaki su: tek disk mesh, iki sinüs dalgalı gölgelendirici, doluluğa göre yükselen seviye
## ve dökme anında genişleyip solan halka dalgalar (hazır havuz).

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const Economy = preload("res://scripts/core/economy.gd")
const LakeShape = preload("res://scripts/core/lake_shape.gd")

const WATER_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 shallow_color : source_color;
uniform vec4 deep_color : source_color;
uniform float amp1;
uniform float amp2;
uniform float freq1;
uniform float freq2;
uniform float speed1;
uniform float speed2;
uniform float alpha_center;
uniform float alpha_edge;
uniform float fade = 1.0;

varying vec2 slope;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float p1 = w.x * freq1 + w.z * freq1 * 0.4 + TIME * speed1;
	float p2 = w.z * freq2 - w.x * freq2 * 0.3 - TIME * speed2;
	VERTEX.y += amp1 * sin(p1) + amp2 * sin(p2);
	slope = vec2(
		amp1 * freq1 * cos(p1) - amp2 * freq2 * 0.3 * cos(p2),
		amp1 * freq1 * 0.4 * cos(p1) + amp2 * freq2 * cos(p2));
}

void fragment() {
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float rim = COLOR.r;
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, rim);
	ROUGHNESS = 0.2;
	SPECULAR = 0.35;
	ALPHA = mix(alpha_center, alpha_edge, rim) * fade;
}
"""

var game: Node
var player: Node3D

var _water: MeshInstance3D
var _material: ShaderMaterial
var _level: float = 0.0
var _radius: float = 0.0
var _initialized: bool = false
var _ripples: Array[MeshInstance3D] = []
var _ripple_age: Array[float] = []
var _ripple_next: int = 0


func _ready() -> void:
	name = "Lake"
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	_material.shader = shader
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

	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.mesh = build_disk_mesh()
	_water.material_override = _material
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
		ring.visible = false
		add_child(ring)
		_ripples.append(ring)
		_ripple_age.append(-1.0)


func bind(game_node: Node, player_node: Node3D) -> void:
	game = game_node
	player = player_node
	game.connect("poured", _on_poured)


func _process(delta: float) -> void:
	if game == null:
		return
	var state: Object = game.get("state")
	var target: float = LakeShape.level_for_fill(Economy.lake_fill(state))
	if not _initialized:
		_level = target
		_initialized = true
	else:
		_level = lerpf(_level, target, 1.0 - exp(-Config.LAKE_LEVEL_SPEED * delta))
	_radius = LakeShape.shore_radius(_level)
	var shown: bool = state.total_drops > 0.0 and _radius > 0.05
	_water.visible = shown
	if shown:
		var r: float = _radius + Config.LAKE_RADIUS_MARGIN
		_water.position = Vector3(0.0, _level, 0.0)
		_water.scale = Vector3(r, 1.0, r)
		var depth: float = _level - LakeShape.bottom_level()
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
