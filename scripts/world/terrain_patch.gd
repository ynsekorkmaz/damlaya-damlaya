extends StaticBody3D
## Çanak yaması: merkezde kutupsal ızgara. Çanak yarıçapı eşikten fazla değişince
## ArrayMesh yüzeyi yeniden üretilir (kareye bölünerek), çarpışma şekli güncellenir. Düğüm yaratılmaz.

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const TerrainBuilder = preload("res://scripts/world/terrain_builder.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")

static var _layout: Dictionary = {}

var game: Node

var _mesh: ArrayMesh = ArrayMesh.new()
var _mi: MeshInstance3D
var _cs: CollisionShape3D
var _verts: PackedVector3Array
var _normals: PackedVector3Array
var _colors: PackedColorArray
var _built_radius: float = -1.0
var _built_depth: float = -1.0
var _target_radius: float = 0.0
var _target_depth: float = 0.0
var _cursor: int = -1
var _limit: int = 0


func _ready() -> void:
	var lay: Dictionary = layout()
	_verts = PackedVector3Array()
	_verts.resize(lay["count"])
	_normals = PackedVector3Array()
	_normals.resize(lay["count"])
	_colors = PackedColorArray()
	_colors.resize(lay["count"])
	_mi = MeshInstance3D.new()
	_mi.name = "PatchMesh"
	_mi.mesh = _mesh
	_mi.material_override = TerrainBuilder.material()
	add_child(_mi)
	_cs = CollisionShape3D.new()
	_cs.name = "PatchShape"
	add_child(_cs)
	rebuild_now(0.0)


## Oyun durumuna bağlar ve hemen o anki çanak boyutuyla kurar.
func bind(game_node: Node) -> void:
	game = game_node
	rebuild_now(_total())


func _total() -> float:
	if game == null:
		return 0.0
	return float((game.get("state") as Object).total_drops)


func _process(_delta: float) -> void:
	if game == null:
		return
	if _cursor < 0:
		var total: float = _total()
		var r: float = BasinShape.radius(total)
		var d: float = BasinShape.depth(total)
		if absf(r - _built_radius) > Config.BASIN_REBUILD_DELTA or absf(d - _built_depth) > Config.BASIN_REBUILD_DELTA:
			_begin(r, d)
	if _cursor >= 0:
		_step(Config.PATCH_VERTS_PER_FRAME)


func rebuild_now(total: float) -> void:
	_cursor = -1
	_built_radius = -1.0
	_begin(BasinShape.radius(total), BasinShape.depth(total))
	_step(1 << 30)


func _begin(r: float, d: float) -> void:
	_target_radius = r
	_target_depth = d
	var lay: Dictionary = layout()
	var rs: PackedFloat32Array = lay["r"]
	_limit = rs.size()
	if _built_radius >= 0.0:
		var reach: float = maxf(r, _built_radius) + 0.01
		_limit = 0
		while _limit < rs.size() and rs[_limit] <= reach:
			_limit += 1
	_cursor = 0


func _step(count: int) -> void:
	var lay: Dictionary = layout()
	var end: int = mini(_cursor + count, _limit)
	for i in range(_cursor, end):
		fill_vertex(lay, i, _target_radius, _target_depth, _verts, _normals, _colors)
	_cursor = end
	if _cursor >= _limit:
		_commit(lay)
		_cursor = -1


func _commit(lay: Dictionary) -> void:
	_mesh.clear_surfaces()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = lay["indices"]
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape: ConcavePolygonShape3D = _mesh.create_trimesh_shape()
	shape.backface_collision = true
	_cs.shape = shape
	_built_radius = _target_radius
	_built_depth = _target_depth


## Tam diziler (test ve araçlar için): verts, normals, colors, indices.
static func build_arrays(basin_radius: float, basin_depth: float) -> Dictionary:
	var lay: Dictionary = layout()
	var n: int = lay["count"]
	var verts := PackedVector3Array()
	verts.resize(n)
	var normals := PackedVector3Array()
	normals.resize(n)
	var colors := PackedColorArray()
	colors.resize(n)
	for i in range(n):
		fill_vertex(lay, i, basin_radius, basin_depth, verts, normals, colors)
	return {"verts": verts, "normals": normals, "colors": colors, "indices": lay["indices"]}


static func fill_vertex(lay: Dictionary, i: int, br: float, bd: float,
		verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var xz: PackedVector2Array = lay["xz"]
	var rs: PackedFloat32Array = lay["r"]
	var gh: PackedFloat32Array = lay["h"]
	var grad: PackedVector2Array = lay["grad"]
	var wv: PackedVector2Array = lay["waves"]
	var wh: PackedFloat32Array = lay["wh"]
	var wgrad: PackedVector2Array = lay["wgrad"]
	var x: float = xz[i].x
	var z: float = xz[i].y
	var r: float = rs[i]
	var keep: float = BasinShape.wave_keep(r, br)
	var pg: float = BasinShape.pit_slope(r, br, bd) + wh[i] * BasinShape.wave_keep_slope(r, br)
	var gx: float = grad[i].x + wgrad[i].x * (keep - 1.0)
	var gz: float = grad[i].y + wgrad[i].y * (keep - 1.0)
	if pg != 0.0 and r > 0.000001:
		gx += pg * x / r
		gz += pg * z / r
	var y: float = gh[i] + wh[i] * (keep - 1.0) + BasinShape.pit(r, br, bd)
	var nrm := Vector3(-gx, 1.0, -gz).normalized()
	verts[i] = Vector3(x, y, z)
	normals[i] = nrm
	colors[i] = TerrainBuilder.weights_from(wv[i].y, y, nrm.y)


static func cell_size(r: float) -> float:
	return Config.PATCH_CELL_MIN + Config.PATCH_CELL_GROWTH * r


## Önbellekli düzen: halkalar merkezden dışa, farklı sayıdaki halkalar fermuarla bağlanır.
static func layout() -> Dictionary:
	if not _layout.is_empty():
		return _layout
	var radii: Array[float] = [0.0]
	var r: float = 0.0
	while r < Config.PATCH_RADIUS - cell_size(r) * 0.5:
		r += cell_size(r)
		radii.append(r)
	radii.append(Config.PATCH_RADIUS)
	var xz := PackedVector2Array()
	var rs := PackedFloat32Array()
	var starts: Array[int] = []
	var counts: Array[int] = []
	for k in range(radii.size()):
		var n: int = 1 if k == 0 else maxi(6, int(round(TAU * radii[k] / cell_size(radii[k]))))
		starts.append(xz.size())
		counts.append(n)
		var offset: float = 0.5 * TAU / float(n) if k % 2 == 1 else 0.0
		for j in range(n):
			var ang: float = TAU * float(j) / float(n) + offset
			xz.append(Vector2(cos(ang), sin(ang)) * radii[k])
			rs.append(radii[k])
	var hs := PackedFloat32Array()
	var grad := PackedVector2Array()
	var wv := PackedVector2Array()
	var wh := PackedFloat32Array()
	var wgrad := PackedVector2Array()
	var e: float = Config.NORMAL_EPS
	for i in range(xz.size()):
		var px: float = xz[i].x
		var pz: float = xz[i].y
		wh.append(TerrainShape.waves(px, pz))
		wgrad.append(Vector2(TerrainShape.waves(px + e, pz) - TerrainShape.waves(px - e, pz),
			TerrainShape.waves(px, pz + e) - TerrainShape.waves(px, pz - e)) / (2.0 * e))
		hs.append(TerrainShape.ground(xz[i].x, xz[i].y))
		grad.append(TerrainBuilder.gradient_at(xz[i].x, xz[i].y))
		wv.append(TerrainBuilder.waves_at(xz[i].x, xz[i].y))
	var idx := PackedInt32Array()
	for k in range(radii.size() - 1):
		_zipper(idx, xz, starts[k], counts[k], starts[k + 1], counts[k + 1])
	_layout = {"count": xz.size(), "xz": xz, "r": rs, "h": hs, "grad": grad, "waves": wv, "wh": wh, "wgrad": wgrad, "indices": idx}
	return _layout


static func _zipper(idx: PackedInt32Array, xz: PackedVector2Array, s0: int, n: int, s1: int, m: int) -> void:
	var i: int = 0
	var j: int = 0
	var inner_steps: int = 0 if n == 1 else n
	while i < inner_steps or j < m:
		var advance_inner: bool = i < inner_steps and (j >= m or float(i + 1) / float(n) <= float(j + 1) / float(m))
		if advance_inner:
			_tri(idx, xz, s0 + i % n, s1 + j % m, s0 + (i + 1) % n)
			i += 1
		else:
			_tri(idx, xz, s0 + i % n, s1 + j % m, s1 + (j + 1) % m)
			j += 1


## Yukarıdan bakınca saat yönü (Godot ön yüzü): (c-a)x(b-a) y > 0 olacak sırada ekler.
static func _tri(idx: PackedInt32Array, xz: PackedVector2Array, a: int, b: int, c: int) -> void:
	var pa: Vector2 = xz[a]
	var cy: float = (xz[c] - pa).y * (xz[b] - pa).x - (xz[c] - pa).x * (xz[b] - pa).y
	if cy > 0.0:
		idx.append_array([a, b, c])
	else:
		idx.append_array([a, c, b])
