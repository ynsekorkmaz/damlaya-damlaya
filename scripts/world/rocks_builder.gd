extends RefCounted
## Vadiye serpilmiş yumuşak normalli, yuvarlak kayalar, tek MultiMeshInstance3D.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")

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
	var rings: int = Config.ROCK_RINGS
	var segs: int = Config.ROCK_SEGMENTS
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	# Dilimli küre: köşe konumu yönün yumuşak sinüs dalgasıyla şişirilir, normal küre normalidir
	for r in range(rings + 1):
		var phi: float = PI * r / float(rings)
		for s in range(segs + 1):
			var theta: float = TAU * s / float(segs)
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var f: float = Config.ROCK_BUMP_FREQ
			var bump: float = (sin(dir.x * f + 0.7) + sin(dir.y * f * 1.3 + 2.1) + sin(dir.z * f + 4.0)) / 3.0
			st.set_normal(dir)
			st.set_color(Palette.ROCK_DARK.lerp(Palette.ROCK, smoothstep(-0.9, 0.9, dir.y)))
			st.add_vertex(dir * 0.5 * (1.0 + Config.ROCK_BUMP * bump))
	var w: int = segs + 1
	for r in range(rings):
		for s in range(segs):
			var a: int = r * w + s
			var b: int = a + 1
			var c: int = a + w
			var d: int = c + 1
			# Godot ön yüzü saat yönü, dışa bakar
			if r > 0:
				for k in [a, b, c]:
					st.add_index(k)
			if r < rings - 1:
				for k in [b, d, c]:
					st.add_index(k)
	return st.commit()
