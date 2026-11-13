extends SceneTree
## Dunya katmani: hucre <-> dunya donusumu, gorsel donus ile canal_pieces tutarliligi, serbest yapi yer kurallari,
## otomatik yer verme, dere yolu, kaya yuzeyi, arazi duzlestirme.

const Config = preload("res://scripts/core/config.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")
const BuildRules = preload("res://scripts/core/build_rules.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const StreamPath = preload("res://scripts/core/stream_path.gd")
const CanalView = preload("res://scripts/world/canal_view.gd")
const RockSurface = preload("res://scripts/world/rock_surface.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")
const Placeholders = preload("res://scripts/world/placeholder_models.gd")
const StructuresView = preload("res://scripts/world/structures_view.gd")

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	test_field_config()
	test_cell_world()
	test_rotation_vectors()
	test_model_rotation()
	test_water_sign()
	test_rules()
	test_auto_place()
	test_stream_path()
	test_rock_surface()
	test_flat_field()
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func near(a: float, b: float, eps: float = 1e-4) -> bool:
	return absf(a - b) <= eps


func test_field_config() -> void:
	check(Config.CANAL_FIELD_COLS == Pieces.DEFAULT_COLS and Config.CANAL_FIELD_ROWS == Pieces.DEFAULT_ROWS, "alan boyutu canal_pieces ile ayni")
	check(near(CanalField.west(), -48.0) and near(CanalField.east(), -20.0), "alan x araligi -48..-20")
	check(near(CanalField.north(), -10.0) and near(CanalField.south(), 10.0), "alan z araligi -10..10")
	check(CanalField.east() < -BasinShape.max_radius(), "alan en buyuk gol yaricapinin disinda")
	check(Config.CANAL_FIELD_COLS * Config.CANAL_CELL_SIZE == 28.0, "28 m genislik")
	var shop := Vector2(Config.SHOP_POSITION.x, Config.SHOP_POSITION.z)
	var spring := Vector2(Config.SPRING_POSITION.x, Config.SPRING_POSITION.z)
	var spawn := Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z)
	for p: Vector2 in [shop, spring, spawn]:
		check(CanalField.distance_to(p.x, p.y) > 10.0, "dukkan, kaynak ve dogus noktasi alanin disinda (%s)" % str(p))
	for r: Dictionary in RocksBuilder.make_rocks():
		var o: Vector3 = (r["transform"] as Transform3D).origin
		check(CanalField.distance_to(o.x, o.z) > Config.CANAL_FIELD_ROCK_CLEARANCE, "kaya alanin disinda")
		if CanalField.distance_to(o.x, o.z) <= Config.CANAL_FIELD_ROCK_CLEARANCE:
			break


func test_cell_world() -> void:
	var ok: bool = true
	for row in range(Config.CANAL_FIELD_ROWS):
		for col in range(Config.CANAL_FIELD_COLS):
			var c: Vector2 = CanalField.cell_center(col, row)
			if CanalField.world_to_cell(c.x, c.y) != Vector2i(col, row):
				ok = false
			# hucre koselerinin hemen icindeki noktalar da ayni hucreye duser
			var e: float = 0.01
			var a: Vector2 = c + Vector2(-1.0 + e, -1.0 + e)
			var b: Vector2 = c + Vector2(1.0 - e, 1.0 - e)
			if CanalField.world_to_cell(a.x, a.y) != Vector2i(col, row) or CanalField.world_to_cell(b.x, b.y) != Vector2i(col, row):
				ok = false
	check(ok, "hucre merkezi ve koseleri hucreye geri doner")
	check(CanalField.world_to_cell(-49.0, 0.0) == CanalField.NONE, "bati disi")
	check(CanalField.world_to_cell(-19.9, 0.0) == CanalField.NONE, "dogu disi")
	check(CanalField.world_to_cell(-30.0, -10.1) == CanalField.NONE, "kuzey disi")
	check(CanalField.world_to_cell(-30.0, 10.1) == CanalField.NONE, "guney disi")
	var c0: Vector2 = CanalField.cell_center(0, 0)
	check(near(c0.x, -47.0) and near(c0.y, -9.0), "sutun 0 satir 0 merkezi (-47, -9)")
	var c1: Vector2 = CanalField.cell_center(13, 9)
	check(near(c1.x, -21.0) and near(c1.y, 9.0), "sutun 13 satir 9 merkezi (-21, 9)")
	check(near(CanalField.spring_point(4).y, CanalField.cell_center(0, 4).y), "pinar satirin ortasinda")
	check(CanalField.spring_point(4).x < CanalField.west(), "pinar alanin bati disinda")
	check(near(CanalField.exit_point(1).x, -20.0), "cikis dogu kenarinda")


func test_rotation_vectors() -> void:
	var ok: bool = true
	for rot in range(4):
		var basis := Basis(Vector3.UP, CanalField.yaw_of_rotation(rot))
		for dir in range(4):
			var got: Vector3 = basis * CanalField.port_vector(dir)
			var want: Vector3 = CanalField.port_vector((dir + rot) % 4)
			if got.distance_to(want) > 1e-4:
				ok = false
	check(ok, "yaw_of_rotation: ag yonu + donus = dondurulmus yon (saat yonu)")
	var e_rot1: Vector3 = Basis(Vector3.UP, CanalField.yaw_of_rotation(1)) * Vector3.RIGHT
	check(e_rot1.distance_to(Vector3(0.0, 0.0, 1.0)) < 1e-4, "donus 1: Dogu -> Guney")


## Gercek (ya da yer tutucu) modelin oluk kutusu, donusten sonra rotated_nodes'in verdigi hucre kenarlarina ulasir.
func test_model_rotation() -> void:
	for id: String in Pieces.PIECE_IDS:
		for rot in range(4):
			var node: Node3D = CanalView.make_piece(id, "wood")
			node.rotation.y = CanalField.yaw_of_rotation(rot)
			var channel: MeshInstance3D = node.get_node_or_null("Channel") as MeshInstance3D
			check(channel != null, "%s: Channel nesnesi var" % id)
			if channel == null:
				node.free()
				continue
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, CanalField.yaw_of_rotation(rot)), Vector3.ZERO) * channel.transform
			var box: AABB = xf * channel.get_aabb()
			var want: Array[bool] = [false, false, false, false]
			for group: Variant in Pieces.rotated_nodes(id, rot):
				for d: Variant in (group as Array):
					want[int(d)] = true
			var reach: Array[bool] = [
				box.position.z <= -0.97,                 # Kuzey
				box.position.x + box.size.x >= 0.97,     # Dogu
				box.position.z + box.size.z >= 0.97,     # Guney
				box.position.x <= -0.97,                 # Bati
			]
			for d in range(4):
				check(reach[d] == want[d], "%s donus %d: yon %s oluk kenarina %s (kutu %s)" % [id, rot, Pieces.DIR_NAMES_TR[d], "ulasmali" if want[d] else "ulasmamali", str(box)])
			node.free()
	# Yer tutucular da ayni sozlesmeyi izler
	for id: String in Pieces.PIECE_IDS:
		var ph: Node3D = Placeholders.canal_piece(id)
		check(ph.get_node_or_null("Channel") != null and ph.get_node_or_null("Water") != null, "%s yer tutucusu Channel ve Water icerir" % id)
		ph.free()
	var mill: Node3D = Placeholders.canal_piece("mill")
	check(mill.get_node_or_null("Wheel") != null, "degirmen yer tutucusunda Wheel")
	mill.free()
	var gate: Node3D = Placeholders.canal_piece("gate")
	check(gate.get_node_or_null("Gate") != null, "savak yer tutucusunda Gate")
	gate.free()
	var aq: Node3D = Placeholders.canal_piece("aqueduct")
	check(aq.get_node_or_null("Water_001") != null, "su kemeri yer tutucusunda ikinci su")
	aq.free()


func test_water_sign() -> void:
	# V yuksek agizlar: duz hatta bati; akis dogu yonundeyse -V
	check(CanalView.water_sign("straight", 0, Pieces.E) == -1, "duz kanal dogu cikisi: -V")
	check(CanalView.water_sign("straight", 0, Pieces.W) == 1, "duz kanal bati cikisi: +V")
	check(CanalView.water_sign("elbow", 0, Pieces.S) == -1, "dirsek guney cikisi: -V")
	check(CanalView.water_sign("cross", 0, Pieces.S) == 1, "arti kanal guney cikisi: +V")
	check(CanalView.water_sign("aqueduct", 1, Pieces.S) == 1, "su kemeri N-S hatti guney: +V")
	check(CanalView.water_sign("aqueduct", 1, Pieces.N) == -1, "su kemeri N-S hatti kuzey: -V")
	check(CanalView.dir_index(Vector2i(1, 0)) == Pieces.E and CanalView.dir_index(Vector2i(0, 1)) == Pieces.S, "dir_index")


func _ctx(shore: float, structures: Array = [], on_rock: bool = false) -> Dictionary:
	return {"shore": shore, "max_radius": BasinShape.max_radius(), "structures": structures, "on_rock": on_rock}


func test_rules() -> void:
	var shore: float = 9.0
	# Kamis
	check(BuildRules.check_free("reeds", 9.5, 0.0, _ctx(shore))["ok"], "kamis kiyida konur")
	check(BuildRules.check_free("reeds", 7.0, 0.0, _ctx(shore))["ok"], "kamis kiyinin icinde (2 m) konur")
	check(not BuildRules.check_free("reeds", 20.0, 0.0, _ctx(shore))["ok"], "kamis kiyidan uzak konmaz")
	check(not BuildRules.check_free("reeds", 3.0, 0.0, _ctx(shore))["ok"], "kamis kiyidan 6 m iceride konmaz")
	var reed_list: Array = [{"kind": "reeds", "x": 9.5, "z": 0.0, "rot": 0.0, "placed": true}]
	check(not BuildRules.check_free("reeds", 9.9, 0.0, _ctx(shore, reed_list))["ok"], "kamis ustuste konmaz")
	# Golge agaci
	check(BuildRules.check_free("shade_tree", 25.0, 0.0, _ctx(shore))["ok"], "agac gol disinda konur")
	check(not BuildRules.check_free("shade_tree", 15.0, 0.0, _ctx(shore))["ok"], "agac en buyuk yaricap icinde konmaz")
	var tree_list: Array = [{"kind": "shade_tree", "x": 25.0, "z": 0.0, "rot": 0.0, "placed": true}]
	check(not BuildRules.check_free("shade_tree", 27.0, 0.0, _ctx(shore, tree_list))["ok"], "agac baska agaca 3 m'den yakin konmaz")
	check(BuildRules.check_free("shade_tree", 28.5, 0.0, _ctx(shore, tree_list))["ok"], "agac baska agaca 3 m'den uzak konur")
	check(BuildRules.check_free("shade_tree", 25.0, 1.0, _ctx(shore, [{"kind": "reeds", "x": 25.0, "z": 0.0, "rot": 0.0, "placed": true}]))["ok"], "agac kamisa yakin olabilir")
	# Gol suyu
	check(not BuildRules.check_free("dew", 3.0, 0.0, _ctx(shore))["ok"], "cig otu gol suyunun icine konmaz")
	check(String(BuildRules.check_free("dew", 3.0, 0.0, _ctx(shore))["reason_tr"]) == BuildCfg.REASON_IN_LAKE_TR, "gol suyu nedeni Turkce")
	# Catlak
	check(not BuildRules.check_free("crack", 30.0, 10.0, _ctx(shore, [], false))["ok"], "catlak kayasiz konmaz")
	check(BuildRules.check_free("crack", 30.0, 10.0, _ctx(shore, [], true))["ok"], "catlak kayaya bakarken konur")
	check(BuildRules.check_free("crack", Config.SPRING_POSITION.x, Config.SPRING_POSITION.z, _ctx(shore, [], true))["ok"], "catlak kaynak kayasina konur")
	# Dere agzi
	check(not BuildRules.check_free("stream_mouth", 30.0, 0.0, _ctx(shore))["ok"], "dere agzi vadi ortasinda konmaz")
	check(BuildRules.check_free("stream_mouth", 0.0, 47.0, _ctx(shore))["ok"], "dere agzi vadi kenarinda konur")
	# Diger kurallar
	check(not BuildRules.check_free("dew", -30.0, 0.0, _ctx(shore))["ok"], "kanal alanina konmaz")
	check(not BuildRules.check_free("dew", -19.5, 0.0, _ctx(shore))["ok"], "kanal alani kenar payina konmaz")
	check(not BuildRules.check_free("dew", Config.SHOP_POSITION.x + 1.0, Config.SHOP_POSITION.z, _ctx(shore))["ok"], "dukkana konmaz")
	check(not BuildRules.check_free("spring", Config.SPRING_POSITION.x + 1.0, Config.SPRING_POSITION.z, _ctx(shore))["ok"], "kaynak kayasina konmaz")
	check(not BuildRules.check_free("dew", 70.0, 0.0, _ctx(shore))["ok"], "vadi disina konmaz")
	var dew_list: Array = [{"kind": "dew", "x": 20.0, "z": 20.0, "rot": 0.0, "placed": true}]
	check(not BuildRules.check_free("rain_cloud", 20.5, 20.9, _ctx(shore, dew_list))["ok"], "baska yapiya 1,5 m'den yakin konmaz")
	check(BuildRules.check_free("rain_cloud", 22.0, 20.0, _ctx(shore, dew_list))["ok"], "baska yapiya 1,5 m'den uzak konur")
	var unplaced: Array = [{"kind": "dew", "x": 0.0, "z": 0.0, "rot": 0.0, "placed": false}]
	check(BuildRules.check_free("dew", 20.0, 20.0, _ctx(shore, unplaced))["ok"], "konumsuz yapi mesafeyi etkilemez")
	check(BuildRules.effective_shore(0.0, 0.7) == 0.7 and BuildRules.effective_shore(12.0, 0.7) == 12.0, "etkili kiyi")


func test_auto_place() -> void:
	var shore: float = 9.0
	var structures: Array = []
	var ctx: Dictionary = {"shore": shore, "max_radius": BasinShape.max_radius(), "structures": structures, "rock_spots": StructuresView._rock_spots()}
	var kinds: Array[String] = ["reeds", "shade_tree", "crack", "dew", "rain_cloud", "spring", "stream_mouth"]
	for kind: String in kinds:
		var count: int = 7 if kind == "reeds" or kind == "shade_tree" else 2
		for i in range(count):
			var res: Dictionary = BuildRules.auto_place(kind, i, ctx)
			check(bool(res["found"]), "%s %d icin yer bulundu" % [kind, i])
			if not bool(res["found"]):
				continue
			var c2: Dictionary = ctx.duplicate()
			c2["on_rock"] = kind == "crack"
			check(bool(BuildRules.check_free(kind, float(res["x"]), float(res["z"]), c2)["ok"]), "%s %d kurallara uyar" % [kind, i])
			structures.append({"kind": kind, "x": res["x"], "z": res["z"], "rot": res["rot"], "placed": true})
			ctx["structures"] = structures


func test_stream_path() -> void:
	var start: Vector2 = CanalField.exit_point(1)
	var pts: PackedVector3Array = StreamPath.points(start, 6.0, BasinShape.radius(1000.0), BasinShape.depth(1000.0), Config.CANAL_STREAM_STEP)
	check(pts.size() >= 2, "dere yolu noktalari")
	check(Vector2(pts[0].x, pts[0].z).distance_to(start) < 1e-3, "dere yolu cikistan baslar")
	var last: Vector2 = Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z)
	check(last.length() < 6.0 and last.length() > 5.0, "dere yolu kiyiya ulasir (%f)" % last.length())
	var shorter: PackedVector3Array = StreamPath.points(start, 15.0, 0.0, 0.0, Config.CANAL_STREAM_STEP)
	check(shorter.size() > 0 and Vector2(shorter[shorter.size() - 1].x, shorter[shorter.size() - 1].z).length() < 15.0, "kiyi buyuyunce dere kisalir")
	check(StreamPath.points(start, 25.0, 0.0, 0.0, Config.CANAL_STREAM_STEP).is_empty(), "kiyi cikisa ulasinca dere yok")
	var on_ground: bool = true
	for p: Vector3 in pts:
		if p.y < TerrainShape.height(p.x, p.z, BasinShape.radius(1000.0), BasinShape.depth(1000.0)):
			on_ground = false
	check(on_ground, "dere zemini izler")


func test_rock_surface() -> void:
	check(RockSurface.rock_count() > 0, "kaya yuzeyi: buyuk kaya var")
	var rocks: Array[Dictionary] = RocksBuilder.make_rocks()
	var tested: bool = false
	for r: Dictionary in rocks:
		if float(r["size"]) < Config.ROCK_COLLIDE_MIN_SIZE:
			continue
		var o: Vector3 = (r["transform"] as Transform3D).origin
		var hit: Dictionary = RockSurface.project_down(o.x, o.z)
		check(not hit.is_empty(), "kaya tepesine izdusum")
		if not hit.is_empty():
			check((hit["position"] as Vector3).y > o.y and (hit["normal"] as Vector3).y > 0.5, "izdusum kayanin ustunde, normal yukari")
		var side: Dictionary = RockSurface.ray_hit(o + Vector3(6.0, 0.2, 0.0), Vector3(-1.0, 0.0, 0.0), 10.0)
		check(not side.is_empty() and float(side["t"]) > 3.0, "yandan isin kayaya carpar")
		tested = true
		break
	check(tested, "test edilecek buyuk kaya bulundu")
	check(RockSurface.project_down(-60.0, 0.0).is_empty(), "kayasiz yerde izdusum bos")


func test_flat_field() -> void:
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	var br: float = BasinShape.radius(400000.0)
	var bd: float = BasinShape.depth(400000.0)
	var x: float = CanalField.west()
	while x <= CanalField.east() + 0.001:
		var z: float = CanalField.north()
		while z <= CanalField.south() + 0.001:
			var h: float = TerrainShape.height(x, z, br, bd)
			lo = minf(lo, h)
			hi = maxf(hi, h)
			z += 0.5
		x += 0.5
	check(hi - lo < 0.02, "alan icinde yukseklik farki < 2 cm (%f)" % (hi - lo))
	check(near(TerrainShape.height(-34.0, 0.0), Config.CANAL_FIELD_HEIGHT, 0.02), "alan sabit yuksekte")
	# Disariya yumusak gecis: 3 m sonra dalgalar geri gelir, ani siçrama yok
	var worst: float = 0.0
	var prev: float = TerrainShape.height(CanalField.west() - 0.0, 0.0)
	var px: float = CanalField.west()
	while px > CanalField.west() - 8.0:
		px -= 0.25
		var h2: float = TerrainShape.height(px, 0.0)
		worst = maxf(worst, absf(h2 - prev) / 0.25)
		prev = h2
	check(worst < 0.6, "alan kenarinda egim yumusak (%f)" % worst)
	check(CanalField.flat_mask(-34.0, 0.0) == 1.0 and CanalField.flat_mask(-60.0, 0.0) == 0.0, "duzlestirme maskesi")
