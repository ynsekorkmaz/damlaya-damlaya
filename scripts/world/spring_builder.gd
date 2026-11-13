extends RefCounted
## Su kaynağı: iç içe geçmiş 3 yassı kaya kütlesi (çarpışmalı), ön iki kütle arasında geometriyle
## çökük yarık, yarıktan süzülen ince su şeridi ve dipte küçük, yumuşak kenarlı birikinti.

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
	ALPHA = side * (0.5 + 0.4 * s);
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


static func blob_count() -> int:
	return Config.SPRING_BLOBS.size()


static func blob_center(i: int) -> Vector3:
	return Config.SPRING_BLOBS[i]["center"]


static func blob_radii(i: int) -> Vector3:
	return Config.SPRING_BLOBS[i]["radii"]


## i. kütlenin yüzey noktası: dir birim yön. Yassı, alt yarıda etekli, düşük frekanslı bozulmalı.
static func blob_point(i: int, dir: Vector3) -> Vector3:
	var ph: float = float(i) * 1.9
	var bump: float = 1.0 + Config.SPRING_BUMP * (
		0.55 * sin(2.6 * dir.x + 1.7 * dir.z + ph + 0.7)
		+ 0.30 * sin(4.1 * dir.y - 3.3 * dir.x + ph + 2.1)
		+ 0.15 * sin(6.0 * dir.z + 2.0 * dir.y + ph))
	var skirt: float = 1.0 + Config.SPRING_SKIRT * clampf(-dir.y, 0.0, 1.0)
	var shaped := Vector3(dir.x * skirt, dir.y, dir.z * skirt)
	return blob_center(i) + shaped * blob_radii(i) * bump


## Nokta herhangi bir kütlenin içinde mi (yaklaşık).
static func _inside(p: Vector3) -> bool:
	for i in range(blob_count()):
		var d: Vector3 = p - blob_center(i)
		var q: Vector3 = d / blob_radii(i)
		if q.length() < 0.0001:
			return true
		var sp: Vector3 = blob_point(i, q.normalized()) - blob_center(i)
		if d.length() <= sp.length():
			return true
	return false


## x = 0 düzleminde, y yüksekliğinde ön yüzeyin z'si (yarığın tabanı).
static func front_z(y: float) -> float:
	var z: float = 2.5
	while z > -2.0 and not _inside(Vector3(0.0, y, z)):
		z -= 0.02
	return z


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Spring"
	root.position = origin()
	root.rotation.y = yaw()

	var body := StaticBody3D.new()
	body.name = "SpringRock"
	body.add_to_group("rock")
	var mi := MeshInstance3D.new()
	mi.mesh = build_rock_mesh()
	body.add_child(mi)
	for i in range(blob_count()):
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = _blob(i)["verts"]
		cs.shape = shape
		body.add_child(cs)
	root.add_child(body)

	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = _build_stream()
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stream)

	var puddle := MeshInstance3D.new()
	puddle.name = "Puddle"
	puddle.mesh = _build_puddle(root.position, root.rotation.y)
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(puddle)
	return root


static func tris_per_blob() -> int:
	return 2 * Config.SPRING_SEGMENTS * (Config.SPRING_RINGS - 1)


## Üç kütle tek yüzeyde (kütle sırasıyla art arda). Dış yüzü saat yönünde sarılı.
static func build_rock_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for i in range(blob_count()):
		var blob: Dictionary = _blob(i)
		var base: int = verts.size()
		verts.append_array(blob["verts"])
		normals.append_array(blob["normals"])
		colors.append_array(blob["colors"])
		for k: int in blob["indices"]:
			idx.append(base + k)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	return mesh


static func _blob(i: int) -> Dictionary:
	var rings: int = Config.SPRING_RINGS
	var segs: int = Config.SPRING_SEGMENTS
	var verts := PackedVector3Array()
	verts.append(blob_point(i, Vector3.UP))
	for r in range(1, rings):
		var phi: float = PI * float(r) / float(rings)
		for j in range(segs):
			var th: float = TAU * float(j) / float(segs)
			verts.append(blob_point(i, Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))))
	verts.append(blob_point(i, Vector3.DOWN))
	var bottom: int = verts.size() - 1
	var center: Vector3 = blob_center(i)

	var tris: Array[int] = []
	for j in range(segs):
		var j2: int = (j + 1) % segs
		_add_tri(tris, verts, center, 0, 1 + j, 1 + j2)
	for r in range(rings - 2):
		for j in range(segs):
			var j2: int = (j + 1) % segs
			var a: int = 1 + r * segs + j
			var b: int = 1 + r * segs + j2
			var c: int = 1 + (r + 1) * segs + j
			var d: int = 1 + (r + 1) * segs + j2
			_add_tri(tris, verts, center, a, b, d)
			_add_tri(tris, verts, center, a, d, c)
	var last: int = 1 + (rings - 2) * segs
	for j in range(segs):
		var j2: int = (j + 1) % segs
		_add_tri(tris, verts, center, last + j, last + j2, bottom)

	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for k in range(0, tris.size(), 3):
		var fn: Vector3 = (verts[tris[k + 2]] - verts[tris[k]]).cross(verts[tris[k + 1]] - verts[tris[k]])
		for q in range(3):
			normals[tris[k + q]] += fn
	var colors := PackedColorArray()
	for k in range(verts.size()):
		normals[k] = normals[k].normalized() if normals[k].length() > 0.0 else Vector3.UP
		colors.append(_vertex_color(i, verts[k], normals[k]))
	return {"verts": verts, "normals": normals, "colors": colors, "indices": PackedInt32Array(tris)}


## Sıcak gri/krem; komşu kütleye yakın (yarık içi) yüzeyler yumuşak koyu tona iner.
static func _vertex_color(i: int, v: Vector3, n: Vector3) -> Color:
	var h: float = clampf(v.y / Config.SPRING_HEIGHT, 0.0, 1.0)
	var wave: float = 0.5 + 0.5 * sin(v.x * 2.3 + v.z * 1.7 + v.y * 3.1)
	var col: Color = Palette.SPRING_ROCK_DARK.lerp(Palette.SPRING_ROCK, clampf(h * 1.6, 0.0, 1.0))
	col = col.lerp(Palette.ROCK_LIGHT, wave * 0.25 * h + 0.25 * clampf(n.y, 0.0, 1.0) * h)
	var occ: float = 0.0
	for j in range(blob_count()):
		if j == i:
			continue
		var q: Vector3 = (v - blob_center(j)) / blob_radii(j)
		var d: float = (q.length() - 1.0) * minf(blob_radii(j).x, blob_radii(j).y)
		occ = maxf(occ, clampf(1.0 - d / Config.SPRING_AO_DIST, 0.0, 1.0))
	occ *= smoothstep(0.1, 0.9, v.y)  # tabanda kararma yok, yarık yukarıda derinleşir
	return col.lerp(Palette.CREVICE, occ * Config.SPRING_AO_AMOUNT)


## Üçgeni dışa bakacak (Godot: ön yüz saat yönü) biçimde ekler.
static func _add_tri(tris: Array[int], verts: PackedVector3Array, center: Vector3, a: int, b: int, c: int) -> void:
	var n: Vector3 = (verts[c] - verts[a]).cross(verts[b] - verts[a])
	var mid: Vector3 = (verts[a] + verts[b] + verts[c]) / 3.0
	if n.dot(mid - center) >= 0.0:
		tris.append_array([a, b, c])
	else:
		tris.append_array([a, c, b])


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
		var y: float = lerpf(Config.SPRING_STREAM_TOP, Config.SPRING_STREAM_BOTTOM, s)
		var z: float = front_z(y) + Config.SPRING_STREAM_OFFSET
		var dz: float = front_z(y - 0.05) - front_z(y + 0.05)
		var n := Vector3(0.0, dz / 0.1, 1.0).normalized()
		var sway: float = 0.035 * sin(s * 7.0) * (1.0 - s)
		var half: float = Config.SPRING_STREAM_WIDTH * 0.5 * (1.0 + 0.8 * s)
		var mid := Vector3(sway, y, z)
		if i > 0:
			length += mid.distance_to(prev)
		prev = mid
		verts.append(Vector3(sway - half, y, z))
		verts.append(Vector3(sway + half, y, z))
		normals.append(n)
		normals.append(n)
		uvs.append(Vector2(0.0, length))
		uvs.append(Vector2(1.0, length))
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


## Dipteki küçük birikinti: su, kenara doğru yumuşakça ıslak toprağa ve şeffaflığa iner (sert hâle yok).
static func _build_puddle(root_pos: Vector3, root_yaw: float) -> ArrayMesh:
	var segs: int = Config.SPRING_PUDDLE_SEGMENTS
	var basis := Basis(Vector3.UP, root_yaw)
	var center := Vector3(0.0, 0.0, front_z(0.0) + Config.SPRING_PUDDLE_RADIUS * 0.55)
	var ring_scale: Array[float] = [0.0, 0.45, 0.85, 1.0, 1.2]
	var ring_color: Array[Color] = [
		Color(Palette.WATER, 0.88),
		Color(Palette.WATER, 0.85),
		Color(Palette.WATER.lerp(Palette.WET_EARTH, 0.4), 0.55),
		Color(Palette.WET_EARTH, 0.2),
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
			# Kenar hafif düzensiz: doğal görünsün
			var wobble: float = 1.0 + 0.12 * sin(3.0 * ang + 0.5) + 0.07 * sin(5.0 * ang + 2.0)
			var rr: float = Config.SPRING_PUDDLE_RADIUS * ring_scale[ri] * wobble
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
	mat.roughness = 0.3
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
