extends RefCounted
## Düz gölgeli düşük poligonlu arazi: StaticBody3D + MeshInstance3D + çarpışma.

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
	for iz in range(cells):
		for ix in range(cells):
			var x0: float = -half + ix * step
			var z0: float = -half + iz * step
			var a := Vector3(x0, heights[iz * (cells + 1) + ix], z0)
			var b := Vector3(x0 + step, heights[iz * (cells + 1) + ix + 1], z0)
			var c := Vector3(x0, heights[(iz + 1) * (cells + 1) + ix], z0 + step)
			var d := Vector3(x0 + step, heights[(iz + 1) * (cells + 1) + ix + 1], z0 + step)
			# Yukarıdan bakınca saat yönü (Godot ön yüzü)
			_add_triangle(st, a, b, d)
			_add_triangle(st, a, d, c)
	return st.commit()


static func _add_triangle(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3) -> void:
	var n: Vector3 = (v2 - v0).cross(v1 - v0).normalized()
	var color: Color = _color_for((v0 + v1 + v2) / 3.0, n)
	for v in [v0, v1, v2]:
		st.set_normal(n)
		st.set_color(color)
		st.add_vertex(v)


static func _color_for(p: Vector3, n: Vector3) -> Color:
	var jitter: float = 0.5 + 0.5 * sin(p.x * Config.COLOR_HASH_X + p.z * Config.COLOR_HASH_Z)
	var col: Color = Palette.GRASS.lerp(Palette.GRASS_DARK, jitter * Config.COLOR_JITTER)
	var hill: float = smoothstep(Config.HILLTOP_DRY_START, Config.HILLTOP_DRY_END, p.y / Config.RIM_HEIGHT)
	col = col.lerp(Palette.DRY_EARTH, hill * Config.HILLTOP_DRY_AMOUNT)
	var earth: float = 1.0 - smoothstep(Config.EARTH_HEIGHT_LOW, Config.EARTH_HEIGHT_HIGH, p.y)
	col = col.lerp(Palette.DRY_EARTH, earth)
	var rock: float = 1.0 - smoothstep(Config.ROCK_NORMAL_Y_LOW, Config.ROCK_NORMAL_Y_HIGH, n.y)
	var rock_col: Color = Palette.ROCK.lerp(Palette.ROCK_DARK, jitter)
	return col.lerp(rock_col, rock)
