extends RefCounted
## Paylaşılan su görünümleri: kanal su malzemesi (akış yönüne göre iki kopya), şerit mesh'i, damla/yağmur/fışkırma efekti.
## Hepsi paylaşılan malzemedir; karede nesne üretilmez, hareket gölgelendiricide.

const Config = preload("res://scripts/core/config.gd")

const WATER_SHADER_PATH: String = "res://assets/shaders/canal_water.gdshader"

## Damla efekti: tepe noktalarının rengi {faz, yön x, yön z}; mod 0 yağmur (düşer), 1 fışkırma (parabol).
const DROP_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 drop_color : source_color = vec4(0.75, 0.90, 1.0, 1.0);
uniform float drop_height = 2.5;
uniform float drop_speed = 2.2;
uniform float drop_spread = 0.4;
uniform float mode = 0.0;

varying float fade;

void vertex() {
	float f = fract(COLOR.r + TIME * drop_speed / drop_height);
	if (mode < 0.5) {
		VERTEX.y -= f * drop_height;
		fade = sin(f * 3.14159);
	} else {
		vec2 dir = COLOR.gb * 2.0 - 1.0;
		VERTEX.y += drop_height * 4.0 * f * (1.0 - f);
		VERTEX.xz += dir * drop_spread * f;
		fade = 1.0 - f * 0.5;
	}
}

void fragment() {
	ALBEDO = drop_color.rgb;
	ALPHA = clamp(fade, 0.0, 1.0) * 0.7;
}
"""

static var _water_mats: Dictionary = {}
static var _drop_mats: Dictionary = {}
static var _water_shader: Shader
static var _drop_shader: Shader


## Kanal suyu: sign +1 ise desen +V yönüne, -1 ise -V yönüne akar. edge true ise şerit kenarları saydamlaşır.
static func water_material(sign_dir: int, edge: bool = false) -> ShaderMaterial:
	var key: int = (1 if sign_dir >= 0 else 0) + (2 if edge else 0)
	if _water_mats.has(key):
		return _water_mats[key]
	if _water_shader == null:
		_water_shader = load(WATER_SHADER_PATH)
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	mat.set_shader_parameter("flow_dir", 1.0 if sign_dir >= 0 else -1.0)
	mat.set_shader_parameter("flow_speed", Config.CANAL_WATER_SPEED)
	mat.set_shader_parameter("wave_len", Config.CANAL_WATER_WAVE)
	mat.set_shader_parameter("edge_soft", 1.0 if edge else 0.0)
	_water_mats[key] = mat
	return mat


## Damla malzemesi: mod 0 yağmur, 1 fışkırma.
static func drop_material(mode: int, height: float, spread: float) -> ShaderMaterial:
	var key: String = "%d_%.2f_%.2f" % [mode, height, spread]
	if _drop_mats.has(key):
		return _drop_mats[key]
	if _drop_shader == null:
		_drop_shader = Shader.new()
		_drop_shader.code = DROP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _drop_shader
	mat.set_shader_parameter("mode", float(mode))
	mat.set_shader_parameter("drop_height", height)
	mat.set_shader_parameter("drop_spread", spread)
	mat.set_shader_parameter("drop_speed", 2.2 if mode == 0 else 1.1)
	_drop_mats[key] = mat
	return mat


## Noktalar boyunca düz şerit (yukarı bakar). UV.x 0..1 enine, UV.y yol uzunluğu (metre). Akış noktaların sırasındadır.
static func ribbon_mesh(points: PackedVector3Array, width: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var length: float = 0.0
	for i in range(points.size()):
		var tangent: Vector3
		if i == 0:
			tangent = points[1] - points[0]
		elif i == points.size() - 1:
			tangent = points[i] - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent.y = 0.0
		tangent = tangent.normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x) * width * 0.5
		if i > 0:
			length += points[i].distance_to(points[i - 1])
		verts.append(points[i] - side)
		verts.append(points[i] + side)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, length))
		uvs.append(Vector2(1.0, length))
	for i in range(points.size() - 1):
		var k: int = i * 2
		idx.append_array([k, k + 2, k + 3, k, k + 3, k + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## count adet ince dikey damla; her biri üst konumunda (üst yarıçap radius içinde), COLOR = faz ve yön.
static func drops_mesh(count: int, radius: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var half_w: float = 0.012
	var len: float = 0.12
	for i in range(count):
		var ang: float = rng.randf() * TAU
		var rr: float = sqrt(rng.randf()) * radius
		var c := Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
		var phase: float = rng.randf()
		var d: float = rng.randf() * TAU
		var col := Color(phase, cos(d) * 0.5 + 0.5, sin(d) * 0.5 + 0.5, 1.0)
		var base: int = verts.size()
		for q in range(2):
			var dir := Vector3(1.0, 0.0, 0.0) if q == 0 else Vector3(0.0, 0.0, 1.0)
			var b2: int = verts.size()
			verts.append(c - dir * half_w)
			verts.append(c + dir * half_w)
			verts.append(c + dir * half_w + Vector3(0.0, len, 0.0))
			verts.append(c - dir * half_w + Vector3(0.0, len, 0.0))
			for k in range(4):
				colors.append(col)
			idx.append_array([b2, b2 + 1, b2 + 2, b2, b2 + 2, b2 + 3])
		base += 0
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Yarı saydam çizilen, gölge atmayan görünüm düğümü.
static func make_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
