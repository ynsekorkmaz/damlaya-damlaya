extends SceneTree

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const TerrainBuilder = preload("res://scripts/world/terrain_builder.gd")
const TerrainPatch = preload("res://scripts/world/terrain_patch.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")
const SpringBuilder = preload("res://scripts/world/spring_builder.gd")
const LakeShape = preload("res://scripts/core/lake_shape.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	test_height_deterministic()
	test_basin_table()
	test_pit_depth()
	test_rim_high()
	test_flat_walkable()
	test_spawn_inside_valley()
	test_terrain_mesh()
	test_patch()
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
	check(TerrainShape.height(-30.0, 22.0, 4.0, 1.1) == TerrainShape.height(-30.0, 22.0, 4.0, 1.1), "height belirlenimci 2")


func test_basin_table() -> void:
	var keys: Array[float] = BasinShape.keys()
	check(keys.size() == Config.BASIN_RADII.size() and keys.size() == Config.BASIN_DEPTHS.size(), "canak tablosu anahtarlarla ayni boyda")
	var exact: bool = true
	for i in range(keys.size()):
		if absf(BasinShape.radius(keys[i]) - Config.BASIN_RADII[i]) > 1e-4 or absf(BasinShape.depth(keys[i]) - Config.BASIN_DEPTHS[i]) > 1e-4:
			exact = false
	check(exact, "esiklerde canak yaricapi ve derinligi tablo degerinde")
	check(absf(BasinShape.radius(0.0) - 0.7) < 1e-4 and absf(BasinShape.depth(0.0) - 0.25) < 1e-4, "total 0: kucuk oyuk 0,7 m / 0,25 m")
	check(BasinShape.radius(0.0) < 1.0, "total 0 icin canak kucuk")
	check(absf(BasinShape.radius(Cfg.GAME_END_DROPS * 10.0) - 19.0) < 1e-4, "oyun sonundan sonra 19 m kalir")
	var prev_r: float = 0.0
	var prev_d: float = 0.0
	var mono: bool = true
	var t: float = 0.0
	while t < Cfg.GAME_END_DROPS * 2.0:
		var r: float = BasinShape.radius(t)
		var d: float = BasinShape.depth(t)
		if r < prev_r - 1e-6 or d < prev_d - 1e-6:
			mono = false
		prev_r = r
		prev_d = d
		t = t * 1.05 + 0.5
	check(mono, "canak boyutu tekduze artiyor")
	check(BasinShape.max_radius() == 19.0, "en buyuk canak yaricapi")


func test_pit_depth() -> void:
	for total: float in [0.0, 60.0, 1500.0, 400000.0]:
		var br: float = BasinShape.radius(total)
		var bd: float = BasinShape.depth(total)
		var h0: float = TerrainShape.height(0.0, 0.0, br, bd)
		check(absf(h0 - (LakeShape.rim_level() - bd)) < 1e-4, "cukur merkezi derinlik kadar asagida (total %f)" % total)
		check(absf(TerrainShape.height(br * 1.2, 0.0, br, bd) - TerrainShape.ground(br * 1.2, 0.0)) < 1e-5, "canak disinda arazi degismez (total %f)" % total)
	check(TerrainShape.height(30.0, 5.0) == TerrainShape.ground(30.0, 5.0), "yaricapsiz cagri cukursuz zemin")


func test_rim_high() -> void:
	var h: float = TerrainShape.height(Config.VALLEY_RADIUS + Config.RIM_WIDTH, 0.0)
	check(h > Config.RIM_HEIGHT * 0.8, "cevre tepeler yuksek (h=%f)" % h)


func test_flat_walkable() -> void:
	var max_slope: float = 0.0
	var step: float = 0.5
	var br: float = BasinShape.radius(400000.0)
	var bd: float = BasinShape.depth(400000.0)
	for k in range(24):
		var ang: float = TAU * k / 24.0
		var dir := Vector2(cos(ang), sin(ang))
		var r: float = 0.0
		while r + step <= Config.VALLEY_RADIUS:
			var p0: Vector2 = dir * r
			var p1: Vector2 = dir * (r + step)
			var dh: float = absf(TerrainShape.height(p1.x, p1.y, br, bd) - TerrainShape.height(p0.x, p0.y, br, bd))
			max_slope = maxf(max_slope, dh / step)
			r += step
	check(max_slope < tan(deg_to_rad(32.0)), "canak ve duzluk yurunebilir (en dik egim %f)" % max_slope)


func test_spawn_inside_valley() -> void:
	var d: float = Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z).length()
	check(d < Config.VALLEY_RADIUS, "PLAYER_SPAWN vadinin icinde")
	check(d > BasinShape.max_radius() + 3.0, "PLAYER_SPAWN son gol boyutunun disinda")


func test_terrain_mesh() -> void:
	var mesh: ArrayMesh = TerrainBuilder.build_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tris: int = idx.size() / 3
	var w: int = Config.TERRAIN_CELLS + 1
	check(verts.size() == w * w, "kose paylasimi (%d kose)" % verts.size())
	check(tris < Config.TERRAIN_CELLS * Config.TERRAIN_CELLS * 2 and tris > 17000, "dis arazi ortadan delik (%d ucgen)" % tris)
	var up_ok: bool = true
	for i in range(0, idx.size(), 3):
		# Godot on yuzu saat yonu: (v2-v0)x(v1-v0) yukari bakmali
		var n: Vector3 = (verts[idx[i + 2]] - verts[idx[i]]).cross(verts[idx[i + 1]] - verts[idx[i]])
		if n.y <= 0.0:
			up_ok = false
	check(up_ok, "arazi ucgenleri yukari bakiyor (sarim)")
	var norm_ok: bool = true
	for n in norms:
		if absf(n.length() - 1.0) > 0.001 or n.y <= 0.0:
			norm_ok = false
	check(norm_ok, "arazi normalleri birim uzunlukta ve yukari bakiyor")
	var node: Node3D = TerrainBuilder.build()
	check(node.get_child_count() == 2 and node.get_node_or_null("Outer") != null and node.get_node_or_null("Patch") != null, "Terrain: Outer + Patch")
	check(node.get_node("Outer").get_child_count() == 2, "dis arazi 2 cocuk (mesh + carpisma)")
	node.free()


func test_patch() -> void:
	var lay: Dictionary = TerrainPatch.layout()
	var rs: PackedFloat32Array = lay["r"]
	var idx: PackedInt32Array = lay["indices"]
	var tris: int = idx.size() / 3
	check(tris < 6000, "yama ucgen sayisi 6000 alti (%d)" % tris)
	check(tris > 3000, "yama yeterince sik (%d)" % tris)
	var a: Dictionary = TerrainPatch.build_arrays(BasinShape.radius(400000.0), BasinShape.depth(400000.0))
	var verts: PackedVector3Array = a["verts"]
	var norms: PackedVector3Array = a["normals"]
	var up_ok: bool = true
	var covered := PackedByteArray()
	covered.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var n: Vector3 = (verts[idx[i + 2]] - verts[idx[i]]).cross(verts[idx[i + 1]] - verts[idx[i]])
		if n.y <= 0.0:
			up_ok = false
		covered[idx[i]] = 1
		covered[idx[i + 1]] = 1
		covered[idx[i + 2]] = 1
	check(up_ok, "yama ucgenleri yukari bakiyor")
	var same_h: bool = true
	var br4: float = BasinShape.radius(400000.0)
	var bd4: float = BasinShape.depth(400000.0)
	for i in range(verts.size()):
		if absf(verts[i].y - TerrainShape.height(verts[i].x, verts[i].z, br4, bd4)) > 1e-3:
			same_h = false
	check(same_h, "yama yukseklikleri TerrainShape.height ile ayni")
	var all_used: bool = true
	var norm_ok: bool = true
	for i in range(verts.size()):
		if covered[i] == 0:
			all_used = false
		if absf(norms[i].length() - 1.0) > 0.001 or norms[i].y <= 0.0:
			norm_ok = false
	check(all_used, "yamada kullanilmayan kose yok")
	check(norm_ok, "yama normalleri birim ve yukari")
	# Kenar: yukseklik canaksiz zeminle (dis arazi) ayni, canak etkisi sifir
	var seam_ok: bool = true
	var edge_count: int = 0
	for i in range(verts.size()):
		if rs[i] >= Config.PATCH_RADIUS - 0.001:
			edge_count += 1
			if absf(verts[i].y - TerrainShape.ground(verts[i].x, verts[i].z)) > 1e-4:
				seam_ok = false
	check(edge_count > 60 and seam_ok, "yama kenarinda yukseklik dis arazi ile eslesiyor (%d kose)" % edge_count)
	check(BasinShape.max_radius() + 2.0 < Config.PATCH_RADIUS - Config.PATCH_SEAM_MARGIN, "en buyuk canak dikisten uzak")
	# Dis arazi hucreleri: kesilen alan yamanin icinde, kalan hucreler yamanin altina biraz uzanir
	var mesh: ArrayMesh = TerrainBuilder.build_mesh()
	var oi: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var ov: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var min_kept: float = INF
	var cell: float = Config.TERRAIN_SIZE / float(Config.TERRAIN_CELLS)
	for i in range(oi.size()):
		var v: Vector3 = ov[oi[i]]
		min_kept = minf(min_kept, Vector2(v.x, v.z).length())
	var cut: float = Config.PATCH_RADIUS - Config.PATCH_SEAM_MARGIN
	check(min_kept >= cut - cell * 1.5 and min_kept < Config.PATCH_RADIUS, "dis arazi yamayla ortusur, bosluk yok (%f)" % min_kept)
	check((TerrainPatch.build_arrays(0.7, 0.25)["verts"] as PackedVector3Array).size() == verts.size(), "yama kose sayisi sabit")
	check((TerrainPatch.build_arrays(0.7, 0.25)["verts"] as PackedVector3Array)[0].y < LakeShape.rim_level() - 0.2, "kucuk oyukta merkez asagida")
	# Gercek dugum: mesh + carpisma, carpisma ucgenleri mesh ile ayni
	var patch := StaticBody3D.new()
	patch.set_script(TerrainPatch)
	patch._ready()  # agacta degil: dugum kurulumunu elle calistir
	check(patch.get_child_count() == 2, "yama dugumu mesh + carpisma")
	var shape: ConcavePolygonShape3D = (patch.get_child(1) as CollisionShape3D).shape
	check(shape != null and shape.get_faces().size() == idx.size(), "yama carpisma ucgenleri mesh ile ayni")
	patch.rebuild_now(1500.0)
	var shape2: ConcavePolygonShape3D = (patch.get_child(1) as CollisionShape3D).shape
	check(shape2 != shape and shape2.get_faces().size() == idx.size(), "yeniden kurmada carpisma sekli guncellenir")
	patch.free()


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
		if p.length() < BasinShape.max_radius() + float(a[i]["size"]) * 0.5 or p.distance_to(spawn) < 3.0:
			clear = false
		if a[i]["size"] >= Config.ROCK_BIG_SIZE_MIN:
			big += 1
		if a[i]["size"] <= Config.ROCK_SMALL_SIZE_MAX:
			small += 1
	check(same, "kaya yerlesimi belirlenimci")
	check(clear, "kayalar en buyuk canaga ve dogus noktasina yakin degil")
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
	var root_rocks: Node3D = RocksBuilder.build()
	var mmis: int = 0
	var shapes: int = 0
	for c in root_rocks.get_children():
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
	root_rocks.free()


func test_bowl() -> void:
	# Canak merkezinden disa dogru yukselen, yumusak: yaricap boyunca dip asagi inmez.
	for total: float in [0.0, 60.0, 1500.0, 400000.0]:
		var br: float = BasinShape.radius(total)
		var bd: float = BasinShape.depth(total)
		var prev: float = TerrainShape.height(0.0, 0.0, br, bd)
		var dips: int = 0
		var r: float = 0.1
		while r <= br:
			var h: float = TerrainShape.height(r, 0.0, br, bd)
			if h < prev - 0.25:
				dips += 1
			prev = maxf(prev, h)
			r += 0.1
		check(dips == 0, "canak merkezden disa yukseliyor (total %f, %d dusus)" % [total, dips])
	var sp := Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z)
	var spring := Vector2(Config.SPRING_POSITION.x, Config.SPRING_POSITION.z)
	var gap: float = spring.length() - BasinShape.max_radius() - Config.SPRING_RADIUS
	check(gap > 3.0, "kaynak en buyuk canagin disinda, aralik > 3 m (%f)" % gap)
	check(sp.length() > spring.length(), "dogus noktasi kaynagin ve canagin disinda")
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
	var rim: float = LakeShape.rim_level()
	var no_overflow: bool = true
	var level_ok: bool = true
	var t: float = 0.0
	while t < Cfg.GAME_END_DROPS * 2.0:
		var lv: float = LakeShape.level(t)
		if lv > rim - 0.0001 or lv < LakeShape.bottom_level(t) - 0.0001:
			no_overflow = false
		t = t * 1.3 + 0.7
	check(no_overflow, "su seviyesi hicbir toplamda canak agzini asmiyor")
	check(level_ok, "seviye hesabi")
	check(LakeShape.level(0.0) == LakeShape.bottom_level(0.0), "total 0: su yok (dipte)")
	var thin: float = LakeShape.level(1.0) - LakeShape.bottom_level(1.0)
	check(thin > 0.0 and thin < 0.15, "ilk damlalarda dipte minik birikinti (%f)" % thin)
	var deep: float = LakeShape.level(400000.0) - LakeShape.bottom_level(400000.0)
	check(deep > BasinShape.depth(400000.0) * 0.8, "buyuk golde su canagin buyuk kismini doldurur (%f)" % deep)
	var prev: float = 0.0
	var mono: bool = true
	for total: float in [1.0, 10.0, 50.0, 200.0, 1000.0, 5000.0, 25000.0, 100000.0, 400000.0, 2000000.0]:
		var br: float = BasinShape.radius(total)
		var bd: float = BasinShape.depth(total)
		var sr: float = LakeShape.shore_radius(LakeShape.level(total), br, bd)
		if sr < prev - 0.05:
			mono = false
		prev = sr
		check(sr <= br * 1.15 + 1.0 + 0.001, "kiyi yaricapi canak icinde (total %f, %f / %f)" % [total, sr, br])
	check(mono, "kiyi yaricapi toplamla azalmiyor")
	var total2: float = 1500.0
	var br2: float = BasinShape.radius(total2)
	var bd2: float = BasinShape.depth(total2)
	var level: float = LakeShape.level(total2)
	var sr2: float = LakeShape.shore_radius(level, br2, bd2)
	check(sr2 > br2 * 0.6 and sr2 < br2 * 1.2, "havuzda kiyi canak yaricapina yakin (%f / %f)" % [sr2, br2])
	var worst: float = INF
	for k in range(12):
		var ang: float = TAU * float(k) / 12.0
		var rad: float = sr2 + Config.LAKE_RADIUS_MARGIN + 0.1
		worst = minf(worst, TerrainShape.height(cos(ang) * rad, sin(ang) * rad, br2, bd2))
	check(worst >= level - 0.06, "disk kenari arazinin altinda kaliyor (arazi %f, su %f)" % [worst, level])
	check(Config.LAKE_SEGMENTS * (2 * Config.LAKE_RINGS - 1) < 2000, "gol ucgeni 2000 alti")


func test_spring() -> void:
	var mesh: ArrayMesh = SpringBuilder.build_rock_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var per: int = SpringBuilder.tris_per_blob()
	var tri_count: int = idx.size() / 3
	check(tri_count == per * SpringBuilder.blob_count(), "kaynak kayasi ucgen sayisi kutle basina sabit")
	check(tri_count < 2500, "kaynak kayasi 2500 ucgen alti (%d)" % tri_count)
	# Her ucgen kendi kutlesinin merkezinden disa bakmali: (b-a)x(c-a) icerideyse ters
	var reversed: int = 0
	var flipped_normals: int = 0
	for t in range(tri_count):
		var blob: int = t / per
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var n: Vector3 = (c - a).cross(b - a)
		var mid: Vector3 = (a + b + c) / 3.0
		if n.length() > 0.00001 and n.dot(mid - SpringBuilder.blob_center(blob)) <= 0.0:
			reversed += 1
	check(reversed == 0, "kaynak kayasinda ters ucgen yok (%d)" % reversed)
	for i in range(norms.size()):
		var blob2: int = i / (verts.size() / SpringBuilder.blob_count())
		if absf(norms[i].length() - 1.0) > 0.01 or norms[i].dot(verts[i] - SpringBuilder.blob_center(blob2)) < -0.2:
			flipped_normals += 1
	check(flipped_normals == 0, "kaynak kayasi normalleri birim ve disa dogru (%d)" % flipped_normals)
	var max_y: float = 0.0
	var min_y: float = 0.0
	for v in verts:
		max_y = maxf(max_y, v.y)
		min_y = minf(min_y, v.y)
	check(max_y > 2.0 and max_y < 2.45, "kaynak kayasi en yuksek ~2,2 m (%f)" % max_y)
	check(min_y < -0.2, "kaynak kayasi zemine gomulu (%f)" % min_y)
	# Yarik: ust yukseklikte on iki kutle arasinda gercekten cokuk (on yuzey, yan kutlelerden geride)
	var cleft: float = SpringBuilder.front_z(1.2)
	var left_front: float = SpringBuilder.front_z(1.2)
	check(cleft < 0.85, "yarik ici arkaya cokuk (z %f)" % cleft)
	check(left_front > -1.5, "yarik tabani bulundu")
	var root_node: Node3D = SpringBuilder.build()
	check(root_node.find_children("*", "CollisionShape3D", true, false).size() == SpringBuilder.blob_count(), "kaynak kayasi carpismali (kutle basina)")
	check(root_node.get_node_or_null("Stream") != null and root_node.get_node_or_null("Puddle") != null, "serit ve birikinti var")
	root_node.free()
