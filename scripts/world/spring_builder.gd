extends RefCounted
## Su kaynağı: koddan üretilmiş yumuşak gölgeli kaya kütlesi (çarpışmalı), üstünde koyu çatlak,
## çatlaktan süzülen ince su şeridi ve dibinde ıslak birikinti.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")

const STREAM_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 light_color : source_color;
uniform vec4 dark_color : source_color;
uniform float scroll_speed = 3.0;
uniform float wave_length = 0.45;

void fragment() {
	float s = 0.5 + 0.5 * sin((UV.y / wave_length - TIME * scroll_speed) * 6.2831);
	float side = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	ALBEDO = mix(dark_color.rgb, light_color.rgb, s);
	ROUGHNESS = 0.15;
	ALPHA = side * (0.55 + 0.4 * s);
}
"""


## Kaynağın dünyadaki taban noktası (y: kayanın yerleştiği yükseklik, gömülme dahil).
static func origin() -> Vector3:
	var p: Vector3 = Config.SPRING_POSITION
	var ground: float = TerrainShape.height(p.x, p.z)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		ground = minf(ground, TerrainShape.height(p.x + cos(a) * Config.SPRING_RADIUS, p.z + sin(a) * Config.SPRING_RADIUS))
	return Vector3(p.x, ground - Config.SPRING_SINK, p.z)


## Kayanın +Z yüzü doğuş noktasına dönük olsun.
static func yaw() -> float:
	var o: Vector3 = Config.SPRING_POSITION
	var s: Vector3 = Config.PLAYER_SPAWN
	return atan2(s.x - o.x, s.z - o.z)


## Yüzey noktası: a açı (0 = +Z), t yükseklik oranı 0..1.
static func surface_point(a: float, t: float) -> Vector3:
	var taper: float = (1.0 - Config.SPRING_TAPER * t) * sqrt(maxf(1.0 - pow(t, Config.SPRING_TOP_POWER), 0.0))
	var bump: float = 1.0 + Config.SPRING_BUMP * (
		0.55 * sin(3.0 * a + 4.0 * t + 0.7)
		+ 0.30 * sin(5.0 * a - 7.0 * t + 2.1)
		+ 0.15 * sin(2.0 * a + 11.0 * t))
	var r: float = Config.SPRING_RADIUS * taper * bump
	return Vector3(r * sin(a) * 1.1, Config.SPRING_HEIGHT * t, r * cos(a) * 0.92)


static func _outward_normal(a: float, t: float) -> Vector3:
	var e: float = 0.01
	var da: Vector3 = surface_point(a + e, t) - surface_point(a - e, t)
	var dt: Vector3 = surface_point(a, minf(t + e, 0.999)) - surface_point(a, maxf(t - e, 0.0))
	var n: Vector3 = dt.cross(da).normalized()
	var p: Vector3 = surface_point(a, t)
	if n.dot(Vector3(p.x, 0.0, p.z)) < 0.0:
		n = -n
	return n


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Spring"
	root.position = origin()
	root.rotation.y = yaw()

	var body := StaticBody3D.new()
	body.name = "SpringRock"
	var rock_mesh: ArrayMesh = build_rock_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = rock_mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = rock_mesh.create_convex_shape()
	body.add_child(cs)
	root.add_child(body)

	var crack := MeshInstance3D.new()
	crack.name = "Crack"
	crack.mesh = _build_crack()
	root.add_child(crack)

	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = _build_stream()
	root.add_child(stream)

	var puddle := MeshInstance3D.new()
	puddle.name = "Puddle"
	puddle.mesh = _build_puddle(root.position, root.rotation.y)
	root.add_child(puddle)
	return root


## Dış yüzü saat yönünde sarılı, yumuşak gölgeli kaya. Alt kutup tabanı kapatır.
static func build_rock_mesh() -> ArrayMesh:
	var rings: int = Config.SPRING_RINGS
	var segs: int = Config.SPRING_SEGMENTS
	var verts := PackedVector3Array()
	verts.append(Vector3.ZERO)  # alt kutup
	for i in range(rings):
		var t: float = float(i) / float(rings)
		for j in range(segs):
			verts.append(surface_point(TAU * float(j) / float(segs), t))
	verts.append(Vector3(0.0, Config.SPRING_HEIGHT, 0.0))  # üst kutup
	var top: int = verts.size() - 1
	var center := Vector3(0.0, Config.SPRING_HEIGHT * 0.5, 0.0)

	var tris: Array[int] = []
	for j in range(segs):
		var j2: int = (j + 1) % segs
		_add_tri(tris, verts, center, 0, 1 + j, 1 + j2)
	for i in range(rings - 1):
		for j in range(segs):
			var j2: int = (j + 1) % segs
			var a: int = 1 + i * segs + j
			var b: int = 1 + i * segs + j2
			var c: int = 1 + (i + 1) * segs + j
			var d: int = 1 + (i + 1) * segs + j2
			_add_tri(tris, verts, center, a, b, d)
			_add_tri(tris, verts, center, a, d, c)
	var last: int = 1 + (rings - 1) * segs
	for j in range(segs):
		var j2: int = (j + 1) % segs
		_add_tri(tris, verts, center, last + j, last + j2, top)

	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for k in range(0, tris.size(), 3):
		var fn: Vector3 = (verts[tris[k + 2]] - verts[tris[k]]).cross(verts[tris[k + 1]] - verts[tris[k]])
		for q in range(3):
			normals[tris[k + q]] += fn
	var colors := PackedColorArray()
	for k in range(verts.size()):
		normals[k] = normals[k].normalized() if normals[k].length() > 0.0 else Vector3.UP
		var v: Vector3 = verts[k]
		var h: float = v.y / Config.SPRING_HEIGHT
		var wave: float = 0.5 + 0.5 * sin(v.x * 2.3 + v.z * 1.7 + v.y * 3.1)
		var col: Color = Palette.SPRING_ROCK_DARK.lerp(Palette.SPRING_ROCK, clampf(h * 1.4, 0.0, 1.0))
		colors.append(col.lerp(Palette.ROCK_LIGHT, wave * 0.25 * h))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(tris)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	return mesh


## Üçgeni dışa bakacak (Godot: ön yüz saat yönü) biçimde ekler.
static func _add_tri(tris: Array[int], verts: PackedVector3Array, center: Vector3, a: int, b: int, c: int) -> void:
	var n: Vector3 = (verts[c] - verts[a]).cross(verts[b] - verts[a])
	var mid: Vector3 = (verts[a] + verts[b] + verts[c]) / 3.0
	if n.dot(mid - center) >= 0.0:
		tris.append_array([a, b, c])
	else:
		tris.append_array([a, c, b])


static func _build_crack() -> ArrayMesh:
	var rows: int = Config.SPRING_STREAM_ROWS
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in range(rows + 1):
		var s: float = float(i) / float(rows)
		var t: float = lerpf(Config.SPRING_CRACK_BOTTOM, Config.SPRING_CRACK_TOP, s)
		var half: float = Config.SPRING_CRACK_WIDTH * 0.5 * pow(sin(PI * s), 0.6)
		var n: Vector3 = _outward_normal(0.0, t)
		var sway: float = 0.05 * sin(s * 9.0)
		var rad: float = surface_point(0.0, t).z
		for side in [-1.0, 1.0]:
			var a: float = (sway + side * half) / maxf(rad, 0.1)
			verts.append(surface_point(a, t) + n * Config.SPRING_SURFACE_OFFSET)
			normals.append(n)
	for i in range(rows):
		var k: int = i * 2
		idx.append_array([k, k + 1, k + 3, k, k + 3, k + 2])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.CRACK
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mesh_from(verts, normals, PackedVector2Array(), PackedColorArray(), idx, mat)


static func _build_stream() -> ArrayMesh:
	var rows: int = Config.SPRING_STREAM_ROWS
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var length: float = 0.0
	var prev := Vector3.ZERO
	for i in range(rows + 1):
		var s: float = float(i) / float(rows)
		var t: float = lerpf(Config.SPRING_CRACK_BOTTOM, Config.SPRING_STREAM_BOTTOM, s)
		var n: Vector3 = _outward_normal(0.0, t)
		var rad: float = surface_point(0.0, t).z
		var mid: Vector3 = surface_point(0.0, t) + n * Config.SPRING_SURFACE_OFFSET * 2.0
		if i > 0:
			length += mid.distance_to(prev)
		prev = mid
		for side in [-1.0, 1.0]:
			var a: float = side * Config.SPRING_STREAM_WIDTH * 0.5 / maxf(rad, 0.1)
			verts.append(surface_point(a, t) + n * Config.SPRING_SURFACE_OFFSET * 2.0)
			normals.append(n)
			uvs.append(Vector2(0.0 if side < 0.0 else 1.0, length))
	for i in range(rows):
		var k: int = i * 2
		idx.append_array([k, k + 1, k + 3, k, k + 3, k + 2])
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = STREAM_SHADER
	mat.shader = shader
	mat.set_shader_parameter("light_color", Palette.WATER_STREAM)
	mat.set_shader_parameter("dark_color", Palette.WATER_STREAM_DARK)
	mat.set_shader_parameter("scroll_speed", Config.SPRING_STREAM_SCROLL)
	mat.set_shader_parameter("wave_length", Config.SPRING_STREAM_WAVELENGTH)
	return _mesh_from(verts, normals, uvs, PackedColorArray(), idx, mat)


## Dipteki ıslak birikinti: merkez su, kenara doğru ıslak toprak ve şeffaflaşma.
static func _build_puddle(root_pos: Vector3, root_yaw: float) -> ArrayMesh:
	var segs: int = Config.SPRING_PUDDLE_SEGMENTS
	var basis := Basis(Vector3.UP, root_yaw)
	var center := Vector3(0.0, 0.0, surface_point(0.0, 0.0).z + Config.SPRING_PUDDLE_RADIUS * 0.45)
	var ring_scale: Array[float] = [0.0, 0.55, 1.0, 1.4]
	var ring_color: Array[Color] = [
		Color(Palette.WATER, 0.85),
		Color(Palette.WATER_DEEP, 0.8),
		Color(Palette.WET_EARTH, 0.6),
		Color(Palette.WET_EARTH, 0.0),
	]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for ri in range(ring_scale.size()):
		var count: int = 1 if ri == 0 else segs
		for j in range(count):
			var ang: float = TAU * float(j) / float(segs)
			var rr: float = Config.SPRING_PUDDLE_RADIUS * ring_scale[ri]
			var local := center + Vector3(cos(ang) * rr * 1.2, 0.0, sin(ang) * rr * 0.9)
			var world: Vector3 = root_pos + basis * local
			local.y = TerrainShape.height(world.x, world.z) + Config.SPRING_PUDDLE_LIFT - root_pos.y
			verts.append(local)
			normals.append(Vector3.UP)
			colors.append(ring_color[ri])
	# merkez yelpazesi + halkalar arası şerit (üstten bakınca saat yönü)
	for j in range(segs):
		var j2: int = (j + 1) % segs
		idx.append_array([0, 1 + j2, 1 + j])
	for ri in range(1, ring_scale.size() - 1):
		var base: int = 1 + (ri - 1) * segs
		var next: int = base + segs
		for j in range(segs):
			var j2: int = (j + 1) % segs
			idx.append_array([base + j, base + j2, next + j2, base + j, next + j2, next + j])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mesh_from(verts, normals, PackedVector2Array(), colors, idx, mat)


static func _mesh_from(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, idx: PackedInt32Array, mat: Material) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh
