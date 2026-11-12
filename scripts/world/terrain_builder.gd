extends RefCounted
## Arazi: dış arazi (durağan, indeksli ızgara, ortası çanak yamasına bırakılmış) ve
## merkezdeki çanak yaması (terrain_patch.gd, çanak büyüdükçe yeniden kurulur).

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var mesh: ArrayMesh = build_mesh()
	var body := StaticBody3D.new()
	body.name = "Outer"
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)

	var patch := StaticBody3D.new()
	patch.set_script(preload("res://scripts/world/terrain_patch.gd"))
	patch.name = "Patch"
	root.add_child(patch)
	return root


static var _material: ShaderMaterial


## Dış arazi ve yama aynı malzemeyi paylaşır (dikişte doku/renk farkı olmaz).
static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	var mat := ShaderMaterial.new()
	mat.shader = load(Config.TERRAIN_SHADER_PATH)
	mat.set_shader_parameter("grass_tex", load(Config.TERRAIN_TEX_GRASS))
	mat.set_shader_parameter("soil_tex", load(Config.TERRAIN_TEX_SOIL))
	mat.set_shader_parameter("rock_tex", load(Config.TERRAIN_TEX_ROCK))
	mat.set_shader_parameter("tile_near", Config.TERRAIN_TILE_NEAR)
	mat.set_shader_parameter("tile_far", Config.TERRAIN_TILE_FAR)
	mat.set_shader_parameter("far_mix_min", Config.TERRAIN_FAR_MIX_MIN)
	mat.set_shader_parameter("far_mix_max", Config.TERRAIN_FAR_MIX_MAX)
	mat.set_shader_parameter("far_dist_start", Config.TERRAIN_FAR_DIST_START)
	mat.set_shader_parameter("far_dist_end", Config.TERRAIN_FAR_DIST_END)
	mat.set_shader_parameter("grass_tint", _tint(Palette.GRASS, Config.TERRAIN_GRASS_GAIN))
	mat.set_shader_parameter("grass_dark_tint", _tint(Palette.GRASS_DARK, Config.TERRAIN_GRASS_GAIN))
	mat.set_shader_parameter("dry_tint", _tint(Palette.DRY_GRASS, Config.TERRAIN_DRY_GAIN))
	mat.set_shader_parameter("soil_tint", _tint(Palette.HILL_EARTH, Config.TERRAIN_SOIL_GAIN))
	mat.set_shader_parameter("soil_dark_tint", _tint(Palette.HILL_EARTH_DARK, Config.TERRAIN_SOIL_GAIN))
	mat.set_shader_parameter("rock_tint", _tint(Palette.ROCK, Config.TERRAIN_ROCK_GAIN))
	mat.set_shader_parameter("rock_dark_tint", _tint(Palette.HILL_EARTH_DARK, Config.TERRAIN_ROCK_GAIN))
	mat.set_shader_parameter("wave_freq", Vector2(Config.COLOR_WAVE_FREQ_X, Config.COLOR_WAVE_FREQ_Z))
	mat.set_shader_parameter("wave_amount", Config.COLOR_WAVE_AMOUNT)
	mat.set_shader_parameter("hill_wave_freq", Config.HILL_WAVE_FREQ)
	mat.set_shader_parameter("hill_wave_amount", Config.HILL_WAVE_AMOUNT)
	_material = mat
	return mat


static func _tint(c: Color, gain: float) -> Color:
	return Color.WHITE.lerp(Color(c.r * gain, c.g * gain, c.b * gain), Config.TERRAIN_TINT_STRENGTH)


## Dış arazi: çanaksız yükseklik; merkezdeki hücreler (yama altında kalanlar) çıkarılmıştır.
static func build_mesh() -> ArrayMesh:
	var cells: int = Config.TERRAIN_CELLS
	var step: float = Config.TERRAIN_SIZE / float(cells)
	var half: float = Config.TERRAIN_SIZE * 0.5
	var w: int = cells + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in range(w):
		for ix in range(w):
			var x: float = -half + ix * step
			var z: float = -half + iz * step
			var y: float = TerrainShape.ground(x, z)
			var g: Vector2 = gradient_at(x, z)
			var n := Vector3(-g.x, 1.0, -g.y).normalized()
			verts.append(Vector3(x, y, z))
			normals.append(n)
			colors.append(weights_for(x, y, z, n))
	var cut: float = Config.PATCH_RADIUS - Config.PATCH_SEAM_MARGIN
	var idx := PackedInt32Array()
	for iz in range(cells):
		for ix in range(cells):
			var a: int = iz * w + ix
			var b: int = a + 1
			var c: int = a + w
			var d: int = c + 1
			if _corner_r(verts[a]) < cut and _corner_r(verts[b]) < cut and _corner_r(verts[c]) < cut and _corner_r(verts[d]) < cut:
				continue
			# Yukarıdan bakınca saat yönü (Godot ön yüzü)
			idx.append_array([a, b, d, a, d, c])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


static func _corner_r(v: Vector3) -> float:
	return sqrt(v.x * v.x + v.z * v.z)


## Çanaksız zeminin eğimi (dh/dx, dh/dz): merkezi fark, yüz normaline bağlı değil.
static func gradient_at(x: float, z: float) -> Vector2:
	var e: float = Config.NORMAL_EPS
	var dx: float = TerrainShape.ground(x + e, z) - TerrainShape.ground(x - e, z)
	var dz: float = TerrainShape.ground(x, z + e) - TerrainShape.ground(x, z - e)
	return Vector2(dx, dz) / (2.0 * e)


static func normal_at(x: float, z: float) -> Vector3:
	var g: Vector2 = gradient_at(x, z)
	return Vector3(-g.x, 1.0, -g.y).normalized()


## Renk çeşitlemesi için konuma bağlı sinüs bileşenleri (önbelleğe alınabilir).
static func waves_at(x: float, z: float) -> Vector2:
	var wave: float = 0.5 + 0.5 * sin(x * Config.COLOR_WAVE_FREQ_X + 1.3) * cos(z * Config.COLOR_WAVE_FREQ_Z - 0.7)
	var hwave: float = 0.5 + 0.5 * sin(x * Config.HILL_WAVE_FREQ + 0.6) * sin(z * Config.HILL_WAVE_FREQ * 1.3 + 1.9)
	return Vector2(wave, hwave)


## Karışım ağırlıkları (vertex rengi): R çimen, G toprak, B kaya (toplam 1), A çimenin kuruma oranı.
## Dış arazi ve yama aynı fonksiyonu kullanır.
static func weights_for(x: float, y: float, z: float, n: Vector3) -> Color:
	var w: Vector2 = waves_at(x, z)
	return weights_from(w.y, y, n.y)


static func weights_from(hwave: float, y: float, ny: float) -> Color:
	var t: float = y / Config.RIM_HEIGHT
	var dry: float = smoothstep(Config.HILLTOP_DRY_START, Config.HILLTOP_DRY_END, t) * Config.HILLTOP_DRY_AMOUNT
	# Çimen -> sıcak toprak/kaya, yükseklikle yumuşak geçiş
	var up: float = smoothstep(Config.HILL_EARTH_START, Config.HILL_EARTH_END, t) * Config.HILL_EARTH_AMOUNT
	var rock_mix: float = Config.HILL_ROCK_MIX * hwave
	var g: float = 1.0 - up
	var s: float = up * (1.0 - rock_mix)
	var r: float = up * rock_mix
	# Çukur içi: toprak
	var low: float = 1.0 - smoothstep(Config.EARTH_HEIGHT_LOW, Config.EARTH_HEIGHT_HIGH, y)
	g *= 1.0 - low
	r *= 1.0 - low
	s = s * (1.0 - low) + low
	# Dik yüzey: kaya
	var rk: float = (1.0 - smoothstep(Config.ROCK_NORMAL_Y_LOW, Config.ROCK_NORMAL_Y_HIGH, ny)) * Config.ROCK_SLOPE_AMOUNT
	g *= 1.0 - rk
	s *= 1.0 - rk
	r = r * (1.0 - rk) + rk
	return Color(g, s, r, dry)
