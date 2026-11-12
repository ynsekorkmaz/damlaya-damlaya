extends RefCounted
## Yumuşak gölgeli, indeksli arazi: StaticBody3D + MeshInstance3D + çarpışma.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")


static func build() -> StaticBody3D:
	var mesh: ArrayMesh = build_mesh()
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


static func build_mesh() -> ArrayMesh:
	var cells: int = Config.TERRAIN_CELLS
	var step: float = Config.TERRAIN_SIZE / float(cells)
	var half: float = Config.TERRAIN_SIZE * 0.5
	var heights: Array[float] = []
	for iz in range(cells + 1):
		for ix in range(cells + 1):
			heights.append(TerrainShape.height(-half + ix * step, -half + iz * step))

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	var w: int = cells + 1
	for iz in range(w):
		for ix in range(w):
			var x: float = -half + ix * step
			var z: float = -half + iz * step
			var y: float = heights[iz * w + ix]
			var n: Vector3 = normal_at(x, z)
			st.set_normal(n)
			st.set_color(_color_for(x, y, z, n))
			st.add_vertex(Vector3(x, y, z))
	for iz in range(cells):
		for ix in range(cells):
			var a: int = iz * w + ix
			var b: int = a + 1
			var c: int = a + w
			var d: int = c + 1
			# Yukarıdan bakınca saat yönü (Godot ön yüzü)
			for k in [a, b, d, a, d, c]:
				st.add_index(k)
	return st.commit()


## Normal, height fonksiyonunun merkezi farkından: yüz normaline bağlı değil.
static func normal_at(x: float, z: float) -> Vector3:
	var e: float = Config.NORMAL_EPS
	var dx: float = TerrainShape.height(x + e, z) - TerrainShape.height(x - e, z)
	var dz: float = TerrainShape.height(x, z + e) - TerrainShape.height(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


static func _color_for(x: float, y: float, z: float, n: Vector3) -> Color:
	var wave: float = 0.5 + 0.5 * sin(x * Config.COLOR_WAVE_FREQ_X + 1.3) * cos(z * Config.COLOR_WAVE_FREQ_Z - 0.7)
	var col: Color = Palette.GRASS.lerp(Palette.GRASS_DARK, wave * Config.COLOR_WAVE_AMOUNT)
	var hill: float = smoothstep(Config.HILLTOP_DRY_START, Config.HILLTOP_DRY_END, y / Config.RIM_HEIGHT)
	col = col.lerp(Palette.DRY_EARTH, hill * Config.HILLTOP_DRY_AMOUNT)
	var earth: float = 1.0 - smoothstep(Config.EARTH_HEIGHT_LOW, Config.EARTH_HEIGHT_HIGH, y)
	col = col.lerp(Palette.DRY_EARTH, earth)
	var rock: float = 1.0 - smoothstep(Config.ROCK_NORMAL_Y_LOW, Config.ROCK_NORMAL_Y_HIGH, n.y)
	return col.lerp(Palette.ROCK.lerp(Palette.ROCK_DARK, wave), rock)
