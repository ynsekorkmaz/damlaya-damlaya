extends SceneTree

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const TerrainBuilder = preload("res://scripts/world/terrain_builder.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	test_height_deterministic()
	test_pit_depth()
	test_rim_high()
	test_flat_walkable()
	test_spawn_inside_valley()
	test_terrain_mesh()
	test_rocks()
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func test_height_deterministic() -> void:
	check(TerrainShape.height(12.3, -4.5) == TerrainShape.height(12.3, -4.5), "height belirlenimci")
	check(TerrainShape.height(-30.0, 22.0) == TerrainShape.height(-30.0, 22.0), "height belirlenimci 2")


func test_pit_depth() -> void:
	var h: float = TerrainShape.height(0.0, 0.0)
	check(absf(h + Config.PIT_DEPTH) < 0.3, "cukur merkezi PIT_DEPTH'e yakin (h=%f)" % h)


func test_rim_high() -> void:
	var h: float = TerrainShape.height(Config.VALLEY_RADIUS + Config.RIM_WIDTH, 0.0)
	check(h > Config.RIM_HEIGHT * 0.8, "cevre tepeler yuksek (h=%f)" % h)


func test_flat_walkable() -> void:
	var max_slope: float = 0.0
	var step: float = 0.5
	for k in range(24):
		var ang: float = TAU * k / 24.0
		var dir := Vector2(cos(ang), sin(ang))
		var r: float = Config.PIT_RADIUS
		while r + step <= Config.VALLEY_RADIUS:
			var p0: Vector2 = dir * r
			var p1: Vector2 = dir * (r + step)
			var dh: float = absf(TerrainShape.height(p1.x, p1.y) - TerrainShape.height(p0.x, p0.y))
			max_slope = maxf(max_slope, dh / step)
			r += step
	check(max_slope < tan(deg_to_rad(45.0)), "duzluk yurunebilir (en dik egim %f)" % max_slope)


func test_spawn_inside_valley() -> void:
	var d: float = Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z).length()
	check(d < Config.VALLEY_RADIUS, "PLAYER_SPAWN vadinin icinde")
	check(d > Config.PIT_RADIUS, "PLAYER_SPAWN cukurun disinda")


func test_terrain_mesh() -> void:
	var mesh: ArrayMesh = TerrainBuilder.build_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tris: int = idx.size() / 3
	var w: int = Config.TERRAIN_CELLS + 1
	check(verts.size() == w * w, "kose paylasimi (%d kose)" % verts.size())
	check(tris == Config.TERRAIN_CELLS * Config.TERRAIN_CELLS * 2, "ucgen sayisi (%d)" % tris)
	check(tris <= 25000, "arazi ucgen butcesi")
	var up_ok: bool = true
	for i in range(0, idx.size(), 3):
		# Godot ön yüzü saat yönü: (v2-v0)x(v1-v0) yukarı bakmalı
		var n: Vector3 = (verts[idx[i + 2]] - verts[idx[i]]).cross(verts[idx[i + 1]] - verts[idx[i]])
		if n.y <= 0.0:
			up_ok = false
	check(up_ok, "arazi ucgenleri yukari bakiyor (sarim)")
	var norm_ok: bool = true
	for n in norms:
		if absf(n.length() - 1.0) > 0.001 or n.y <= 0.0:
			norm_ok = false
	check(norm_ok, "arazi normalleri birim uzunlukta ve yukari bakiyor")
	var body: StaticBody3D = TerrainBuilder.build()
	check(body.get_child_count() == 2, "StaticBody3D 2 cocuk")
	body.free()


func test_rocks() -> void:
	var a: Array[Transform3D] = RocksBuilder.make_placements()
	var b: Array[Transform3D] = RocksBuilder.make_placements()
	check(a.size() == Config.ROCK_COUNT, "kaya sayisi (%d)" % a.size())
	var same: bool = true
	var clear: bool = true
	var spawn := Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z)
	for i in range(a.size()):
		if a[i] != b[i]:
			same = false
		var p := Vector2(a[i].origin.x, a[i].origin.z)
		if p.length() < Config.PIT_RADIUS or p.distance_to(spawn) < 3.0:
			clear = false
	var rock_mesh: ArrayMesh = RocksBuilder.build_rock_mesh()
	var ri: PackedInt32Array = rock_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	check(ri.size() / 3 * Config.ROCK_COUNT < 4000, "kaya ucgen butcesi (%d)" % (ri.size() / 3 * Config.ROCK_COUNT))
	check(same, "kaya yerlesimi belirlenimci")
	check(clear, "kayalar cukura ve dogus noktasina yakin degil")
