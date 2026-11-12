extends RefCounted
## Vadiye serpilmiş düşük poligonlu kayalar, tek MultiMeshInstance3D.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")

const _T := 1.6180339887
const _ICO_VERTS: Array[Vector3] = [
	Vector3(-1, _T, 0), Vector3(1, _T, 0), Vector3(-1, -_T, 0), Vector3(1, -_T, 0),
	Vector3(0, -1, _T), Vector3(0, 1, _T), Vector3(0, -1, -_T), Vector3(0, 1, -_T),
	Vector3(_T, 0, -1), Vector3(_T, 0, 1), Vector3(-_T, 0, -1), Vector3(-_T, 0, 1),
]
const _ICO_FACES: Array[int] = [
	0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
	1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
	3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
	4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
]


static func build() -> MultiMeshInstance3D:
	var placements: Array[Transform3D] = make_placements()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = build_rock_mesh()
	mm.instance_count = placements.size()
	for i in range(placements.size()):
		mm.set_instance_transform(i, placements[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rocks"
	mmi.multimesh = mm
	return mmi


## Tohumlu, belirlenimci yerleşim. Çukura ve doğuş noktasına yaklaşmaz.
static func make_placements() -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = Config.ROCK_SEED
	var out: Array[Transform3D] = []
	var spawn := Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z)
	var r_min: float = Config.PIT_RADIUS + Config.ROCK_PIT_CLEARANCE
	var r_max: float = Config.VALLEY_RADIUS - Config.ROCK_RIM_CLEARANCE
	var tries: int = 0
	while out.size() < Config.ROCK_COUNT and tries < Config.ROCK_COUNT * Config.ROCK_MAX_TRIES:
		tries += 1
		var angle: float = rng.randf() * TAU
		var r: float = rng.randf_range(r_min, r_max)
		var pos := Vector2(cos(angle), sin(angle)) * r
		if pos.distance_to(spawn) < Config.ROCK_SPAWN_CLEARANCE:
			continue
		var s := Vector3(
			rng.randf_range(Config.ROCK_SCALE_MIN.x, Config.ROCK_SCALE_MAX.x),
			rng.randf_range(Config.ROCK_SCALE_MIN.y, Config.ROCK_SCALE_MAX.y),
			rng.randf_range(Config.ROCK_SCALE_MIN.z, Config.ROCK_SCALE_MAX.z))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(s)
		var y: float = TerrainShape.height(pos.x, pos.y) + s.y * 0.5 - Config.ROCK_SINK
		out.append(Transform3D(basis, Vector3(pos.x, y, pos.y)))
	return out


static func build_rock_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = Config.ROCK_SEED + 1
	var verts: Array[Vector3] = []
	for v in _ICO_VERTS:
		var jitter: float = 1.0 + rng.randf_range(-Config.ROCK_VERTEX_JITTER, Config.ROCK_VERTEX_JITTER)
		verts.append(v.normalized() * 0.5 * jitter)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for f in range(0, _ICO_FACES.size(), 3):
		var a: Vector3 = verts[_ICO_FACES[f]]
		var b: Vector3 = verts[_ICO_FACES[f + 1]]
		var c: Vector3 = verts[_ICO_FACES[f + 2]]
		# Godot ön yüzü saat yönü: dışa bakan normal (c-a)x(b-a) olmalı
		var n: Vector3 = (c - a).cross(b - a)
		if n.dot(a + b + c) < 0.0:
			var tmp: Vector3 = b
			b = c
			c = tmp
			n = -n
		n = n.normalized()
		var col: Color = Palette.ROCK.lerp(Palette.ROCK_DARK, rng.randf())
		for v in [a, b, c]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(v)
	return st.commit()
