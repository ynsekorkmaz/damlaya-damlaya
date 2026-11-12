extends SceneTree

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const TerrainBuilder = preload("res://scripts/world/terrain_builder.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")
const SpringBuilder = preload("res://scripts/world/spring_builder.gd")
const LakeShape = preload("res://scripts/core/lake_shape.gd")

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
	test_bowl()
	test_lake_shape()
	test_spring()
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
	check(Config.PIT_RADIUS >= 15.0 and Config.PIT_DEPTH >= 3.0, "cukur genis ve derin")
	var edge: float = TerrainShape.height(Config.PIT_RADIUS * 1.5, 0.0)
	check(edge > h + 2.5, "cukur kenari dipten en az 2,5 m yuksek (kenar %f, dip %f)" % [edge, h])


func test_rim_high() -> void:
	var h: float = TerrainShape.height(Config.VALLEY_RADIUS + Config.RIM_WIDTH, 0.0)
	check(h > Config.RIM_HEIGHT * 0.8, "cevre tepeler yuksek (h=%f)" % h)


func test_flat_walkable() -> void:
	var max_slope: float = 0.0
	var step: float = 0.5
	for k in range(24):
		var ang: float = TAU * k / 24.0
		var dir := Vector2(cos(ang), sin(ang))
		var r: float = 0.0
		while r + step <= Config.VALLEY_RADIUS:
			var p0: Vector2 = dir * r
			var p1: Vector2 = dir * (r + step)
			var dh: float = absf(TerrainShape.height(p1.x, p1.y) - TerrainShape.height(p0.x, p0.y))
			max_slope = maxf(max_slope, dh / step)
			r += step
	check(max_slope < tan(deg_to_rad(32.0)), "cukur ve duzluk yurunebilir (en dik egim %f)" % max_slope)


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
	var a: Array[Dictionary] = RocksBuilder.make_rocks()
	var b: Array[Dictionary] = RocksBuilder.make_rocks()
	check(a.size() == Config.ROCK_COUNT, "kaya sayisi (%d)" % a.size())
	var same: bool = a.size() == b.size()
	var clear: bool = true
	var big: int = 0
	var small: int = 0
	var spawn := Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z)
	for i in range(a.size()):
		if same and (a[i]["transform"] != b[i]["transform"] or a[i]["variant"] != b[i]["variant"]):
			same = false
		var o: Vector3 = (a[i]["transform"] as Transform3D).origin
		var p := Vector2(o.x, o.z)
		if p.length() < Config.PIT_RADIUS or p.distance_to(spawn) < 3.0:
			clear = false
		if a[i]["size"] >= Config.ROCK_BIG_SIZE_MIN:
			big += 1
		if a[i]["size"] <= Config.ROCK_SMALL_SIZE_MAX:
			small += 1
	check(same, "kaya yerlesimi belirlenimci")
	check(clear, "kayalar cukura ve dogus noktasina yakin degil")
	check(big >= 3 and small >= 3, "kaya boy cesitliligi (buyuk %d, kucuk %d)" % [big, small])
	check(Config.ROCK_VARIANTS <= 3, "en fazla 3 MultiMesh")
	var tris: int = 0
	var counts: Array[int] = []
	counts.resize(Config.ROCK_VARIANTS)
	counts.fill(0)
	for r in a:
		counts[r["variant"]] += 1
	for v in range(Config.ROCK_VARIANTS):
		var m: ArrayMesh = RocksBuilder.build_rock_mesh(v)
		var ri: PackedInt32Array = m.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		tris += ri.size() / 3 * counts[v]
	check(tris <= Config.ROCK_TRI_BUDGET, "kaya ucgen butcesi (%d)" % tris)
	var root: Node3D = RocksBuilder.build()
	var mmis: int = 0
	var shapes: int = 0
	for c in root.get_children():
		if c is MultiMeshInstance3D:
			mmis += 1
		elif c is StaticBody3D:
			shapes = c.get_child_count()
	var expect_col: int = 0
	for r in a:
		if r["size"] >= Config.ROCK_COLLIDE_MIN_SIZE:
			expect_col += 1
	check(mmis >= 1 and mmis <= 3, "MultiMesh sayisi (%d)" % mmis)
	check(shapes == expect_col and shapes > 0, "buyuk kayalara carpisma (%d / %d)" % [shapes, expect_col])
	root.free()


func test_bowl() -> void:
	# Cukur merkezinden dista dogru yukselen, yumusak canak: yaricap boyunca dip asagi inmez.
	var prev: float = TerrainShape.height(0.0, 0.0)
	var dips: int = 0
	var r: float = 0.5
	while r <= Config.PIT_RADIUS:
		var h: float = TerrainShape.height(r, 0.0)
		if h < prev - 0.25:
			dips += 1
		prev = maxf(prev, h)
		r += 0.5
	check(dips == 0, "canak merkezden disa yukseliyor (%d dusus)" % dips)
	var sp := Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z)
	var spring := Vector2(Config.SPRING_POSITION.x, Config.SPRING_POSITION.z)
	var gap: float = spring.length() - Config.PIT_RADIUS
	check(gap > 9.0 and gap < 15.0, "kaynak cukur kenarindan ~12 m (%f)" % gap)
	check(sp.length() > spring.length(), "dogus noktasi kaynagin ve cukurun disinda")
	check(sp.distance_to(spring) < 30.0, "kaynak dogus noktasindan gorulebilir mesafede")
	# Kayalar kaynaga binmesin
	var rocks: Array[Dictionary] = RocksBuilder.make_rocks()
	var overlap: bool = false
	for rock in rocks:
		var o: Vector3 = (rock["transform"] as Transform3D).origin
		if Vector2(o.x, o.z).distance_to(spring) < Config.SPRING_RADIUS + float(rock["size"]) * 0.6 + 0.5:
			overlap = true
	check(not overlap, "kayalar su kaynagiyla cakismiyor")


func test_lake_shape() -> void:
	var bottom: float = LakeShape.bottom_level()
	check(LakeShape.level_for_fill(0.0) > bottom, "fill 0 seviyesi dibin ustunde")
	check(LakeShape.level_for_fill(1.0) <= Config.LAKE_TOP_LEVEL + 0.0001, "fill 1 seviyesi ust sinirda")
	check(LakeShape.level_for_fill(1.0) > LakeShape.level_for_fill(0.5), "seviye fill ile artiyor")
	check(LakeShape.level_for_fill(-1.0) == LakeShape.level_for_fill(0.0), "fill alt sinira kenetli")
	var last: float = -1.0
	var mono: bool = true
	for i in range(0, 41):
		var rr: float = LakeShape.shore_radius(LakeShape.level_for_fill(float(i) / 40.0))
		if rr < last - 0.0001:
			mono = false
		last = rr
	check(mono, "kiyi yaricapi seviye ile azalmiyor")
	var top_r: float = LakeShape.shore_radius(Config.LAKE_TOP_LEVEL)
	check(top_r > Config.PIT_RADIUS * 0.7 and top_r < Config.POUR_ZONE_RADIUS, "tam dolu kiyi yaricapi canak icinde (%f)" % top_r)
	var level: float = LakeShape.level_for_fill(0.6)
	var sr: float = LakeShape.shore_radius(level)
	var worst: float = INF
	for k in range(12):
		var a: float = TAU * float(k) / 12.0
		var rad: float = sr + Config.LAKE_RADIUS_MARGIN + 0.1
		worst = minf(worst, TerrainShape.height(cos(a) * rad, sin(a) * rad))
	check(worst >= level - 0.02, "disk kenari arazinin altinda kalmiyor (arazi %f, su %f)" % [worst, level])
	check(Config.LAKE_SEGMENTS * (2 * Config.LAKE_RINGS - 1) < 2000, "gol ucgeni 2000 alti")


func test_spring() -> void:
	var mesh: ArrayMesh = SpringBuilder.build_rock_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var center := Vector3(0.0, Config.SPRING_HEIGHT * 0.5, 0.0)
	var outward_ok: bool = true
	for i in range(0, idx.size(), 3):
		var n: Vector3 = (verts[idx[i + 2]] - verts[idx[i]]).cross(verts[idx[i + 1]] - verts[idx[i]])
		var mid: Vector3 = (verts[idx[i]] + verts[idx[i + 1]] + verts[idx[i + 2]]) / 3.0
		if n.length() > 0.00001 and n.dot(mid - center) <= 0.0:
			outward_ok = false
	check(outward_ok, "kaynak kayasi disa bakan sarim")
	var norm_ok: bool = true
	for i in range(norms.size()):
		if absf(norms[i].length() - 1.0) > 0.01 or norms[i].dot(verts[i] - center) < -0.2:
			norm_ok = false
	check(norm_ok, "kaynak kayasi normalleri birim ve disa dogru")
	var max_y: float = 0.0
	for v in verts:
		max_y = maxf(max_y, v.y)
	check(absf(max_y - Config.SPRING_HEIGHT) < 0.01, "kaynak kayasi yuksekligi")
	check(idx.size() / 3 < 1200, "kaynak kayasi ucgen sayisi (%d)" % (idx.size() / 3))
	var root: Node3D = SpringBuilder.build()
	check(root.find_children("*", "CollisionShape3D", true, false).size() == 1, "kaynak kayasi carpismali")
	check(root.get_node_or_null("Crack") != null and root.get_node_or_null("Stream") != null and root.get_node_or_null("Puddle") != null, "catlak, serit, birikinti var")
	root.free()
