extends SceneTree

const CanalConfig = preload("res://scripts/core/canal_config.gd")
const CanalGrid = preload("res://scripts/core/canal_grid.gd")
const CanalFlow = preload("res://scripts/core/canal_flow.gd")

const TOL: float = 0.01

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	test_scenario_1()
	test_scenario_2()
	test_scenario_3()
	test_scenario_4()
	test_scenario_5()
	test_scenario_6()
	test_prices()
	test_refund()
	test_mill_only_on_canal()
	test_mill_removal_keeps_canal()
	test_blocked_spring_start()
	test_l_shaped_path()
	test_version_and_cache()
	test_flow_dir_straight()
	test_flow_dir_branch()
	test_upgrades()
	test_serialization()
	test_bad_data()
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func near(actual: float, expected: float, msg: String) -> void:
	check(absf(actual - expected) <= TOL, "%s (beklenen %f, gelen %f)" % [msg, expected, actual])


# --- Yardimcilar ---

func make_grid() -> RefCounted:
	return CanalGrid.new()


func line(grid: RefCounted, row: int) -> void:
	for col in range(CanalConfig.COLS):
		grid.place_canal(col, row)


## Satir 0, 2, 4 icin duz hatlar; A, B, C acik.
func three_lines() -> RefCounted:
	var g: RefCounted = make_grid()
	for id in CanalConfig.SPRING_IDS:
		g.open_spring(id)
	line(g, 0)
	line(g, 2)
	line(g, 4)
	return g


func print_result(name: String, r: Dictionary) -> void:
	print("%s: delivered=%.2f leaked=%.2f overflow=%.2f wasted=%.2f input=%.2f" % [
		name, r["delivered"], r["leaked"], r["overflow"], r["wasted"], r["input"]])


# --- Belge 5.4 senaryolari ---

func test_scenario_1() -> void:
	var g: RefCounted = make_grid()
	g.open_spring("A")
	line(g, 2)
	var r: Dictionary = CanalFlow.compute(g)
	print_result("Senaryo 1", r)
	near(r["delivered"], 39.81, "S1 delivered")
	near(r["leaked"], 20.19, "S1 leaked")
	near(r["wasted"], 0.0, "S1 wasted")
	near(r["input"], 60.0, "S1 input")
	check(r["flowing"].size() == 8, "S1 akan hucre sayisi")


func test_scenario_2() -> void:
	var g: RefCounted = make_grid()
	for id in CanalConfig.SPRING_IDS:
		g.open_spring(id)
	line(g, 2)
	var r: Dictionary = CanalFlow.compute(g)
	print_result("Senaryo 2", r)
	near(r["wasted"], 660.0, "S2 wasted")
	near(r["delivered"], 39.81, "S2 delivered")
	near(r["input"], 720.0, "S2 input")


func test_scenario_3() -> void:
	var g: RefCounted = three_lines()
	var r: Dictionary = CanalFlow.compute(g)
	print_result("Senaryo 3", r)
	near(r["delivered"], 199.81, "S3 delivered")
	near(r["overflow"], 277.86, "S3 overflow")
	near(r["leaked"], 242.34, "S3 leaked")
	near(r["wasted"], 0.0, "S3 wasted")


func connector_grid() -> RefCounted:
	var g: RefCounted = three_lines()
	for row in range(CanalConfig.ROWS):
		g.place_canal(3, row)  # satir 0, 2, 4 zaten dolu; 1 ve 3 eklenir
	return g


func test_scenario_4() -> void:
	var g: RefCounted = connector_grid()
	var r: Dictionary = CanalFlow.compute(g)
	print_result("Senaryo 4", r)
	near(r["delivered"], 240.0, "S4 delivered")
	near(r["overflow"], 237.66, "S4 overflow")
	near(r["leaked"], 242.34, "S4 leaked")


func test_scenario_5() -> void:
	var g: RefCounted = connector_grid()
	check(g.place_mill(4, 2), "S5 degirmen kurulur")
	var r: Dictionary = CanalFlow.compute(g)
	print_result("Senaryo 5", r)
	near(r["delivered"], 259.2, "S5 delivered")


func test_scenario_6() -> void:
	var g: RefCounted = connector_grid()
	g.place_mill(4, 2)
	for i in range(3):
		g.upgrade_lining()
	for i in range(2):
		g.upgrade_width()
	var r: Dictionary = CanalFlow.compute(g)
	print_result("Senaryo 6", r)
	near(r["delivered"], 729.2, "S6 delivered")
	near(r["overflow"], 0.0, "S6 overflow")


# --- Ek testler ---

func test_prices() -> void:
	var g: RefCounted = make_grid()
	check(g.canal_cost() == 30, "kanal 0. parca 30")
	g.place_canal(0, 0)
	check(g.canal_cost() == 31, "kanal 1 parca sonrasi 31")
	g.place_canal(1, 0)
	check(g.canal_cost() == 32, "kanal 2 parca sonrasi 32")
	g.place_canal(2, 0)
	check(g.canal_cost() == 33, "kanal 3 parca sonrasi 33")
	for col in range(3, 8):
		g.place_canal(col, 0)
	for col in range(2):
		g.place_canal(col, 1)
	check(g.piece_count() == 10, "10 parca")
	check(g.canal_cost() == 44, "kanal 10 parca sonrasi 44")
	check(g.mill_cost() == 600, "ilk degirmen 600")
	g.place_mill(0, 0)
	check(g.mill_cost() == 900, "ikinci degirmen 900")
	g.place_mill(1, 0)
	check(g.mill_cost() == 1350, "ucuncu degirmen 1350")
	g.place_mill(2, 0)
	check(g.mill_cost() == 2025, "dorduncu degirmen 2025")
	check(g.piece_count() == 10, "degirmen parca sayisini arttirmaz")
	check(g.mill_count() == 3, "degirmen sayisi 3")
	check(g.spring_cost("A") == 4000 and g.spring_cost("B") == 30000 and g.spring_cost("C") == 200000, "pinar maliyetleri")
	check(g.width_cost() == 3000, "genis kanal seviye 0 maliyeti")
	check(g.lining_cost() == 5000, "tas kaplama seviye 0 maliyeti")
	g.upgrade_width()
	g.upgrade_lining()
	check(g.width_cost() == 12000, "genis kanal seviye 1 maliyeti")
	check(g.lining_cost() == 20000, "tas kaplama seviye 1 maliyeti")
	g.upgrade_width()
	g.upgrade_width()
	g.upgrade_lining()
	check(g.lining_cost() == 80000, "tas kaplama seviye 2 maliyeti")
	g.upgrade_lining()
	check(g.width_cost() == 192000, "genis kanal seviye 3 maliyeti")
	check(g.lining_cost() == -1, "tas kaplama azami seviyede -1")


func test_refund() -> void:
	var g: RefCounted = make_grid()
	g.place_canal(0, 0)
	g.place_canal(1, 0)
	g.place_canal(2, 0)
	# Sokulunce 2 parca kalir: fiyat 32, iade 16
	check(g.remove(2, 0) == 16, "kanal iadesi 16")
	check(g.get_cell(2, 0) == 0, "kanal sokulunce hucre bos")
	check(g.remove(2, 0) == 0, "bos hucreden iade 0")
	check(g.remove(-1, 9) == 0, "sinir disi iade 0")
	# Ilk parca: sokulunce 0 parca kalir, fiyat 30, iade 15
	g.remove(1, 0)
	check(g.remove(0, 0) == 15, "son kanal iadesi 15")
	# Degirmen: ilk degirmen iadesi 300, iki degirmenden biri 450
	g.place_canal(0, 0)
	g.place_canal(1, 0)
	g.place_mill(0, 0)
	g.place_mill(1, 0)
	check(g.remove(1, 0) == 450, "ikinci degirmen iadesi 450")
	check(g.remove(0, 0) == 300, "ilk degirmen iadesi 300")


func test_mill_only_on_canal() -> void:
	var g: RefCounted = make_grid()
	check(not g.place_mill(3, 3), "bos hucreye degirmen konmaz")
	check(g.mill_count() == 0, "degirmen sayisi 0")
	g.place_canal(3, 3)
	check(g.place_mill(3, 3), "kanala degirmen konur")
	check(not g.place_mill(3, 3), "degirmenin ustune degirmen konmaz")
	check(not g.place_canal(3, 3), "degirmenin ustune kanal konmaz")
	check(not g.place_canal(8, 0) and not g.place_canal(0, 5) and not g.place_canal(-1, 0), "sinir disi kanal konmaz")


func test_mill_removal_keeps_canal() -> void:
	var g: RefCounted = make_grid()
	g.place_canal(2, 2)
	g.place_mill(2, 2)
	g.remove(2, 2)
	check(g.get_cell(2, 2) == CanalConfig.CELL_CANAL, "degirmen sokulunce kanal kalir")
	check(g.piece_count() == 1 and g.mill_count() == 0, "sayilar dogru")


func test_blocked_spring_start() -> void:
	var g: RefCounted = make_grid()
	g.open_spring("A")
	for col in range(1, 8):
		g.place_canal(col, 2)  # sutun 0 bos
	var r: Dictionary = CanalFlow.compute(g)
	near(r["wasted"], 60.0, "pinar basi bossa wasted")
	near(r["delivered"], 0.0, "teslimat yok")
	check(r["flowing"].is_empty(), "akan hucre yok")


func test_l_shaped_path() -> void:
	var g: RefCounted = make_grid()
	g.open_spring("A")
	for col in range(0, 4):
		g.place_canal(col, 2)
	g.place_canal(3, 1)
	g.place_canal(3, 0)
	for col in range(4, 8):
		g.place_canal(col, 0)
	var r: Dictionary = CanalFlow.compute(g)
	# Yol: 4 (satir 2) + 2 (dikey) + 4 (satir 0) = 10 hucre
	near(r["delivered"], 60.0 * pow(0.95, 10), "L yol 10 hucre")
	check(r["flowing"].size() == 10, "L yolda 10 akan hucre")
	check(r["flow_dir"][Vector2i(3, 2)] == Vector2i(0, -1), "kosede yon yukari")
	check(r["flow_dir"][Vector2i(7, 0)] == Vector2i(1, 0), "cikis hucresi (1,0)")


func test_version_and_cache() -> void:
	var g: RefCounted = make_grid()
	var v0: int = g.version
	g.place_canal(0, 2)
	check(g.version > v0, "place_canal version arttirir")
	var v1: int = g.version
	g.place_canal(0, 2)  # basarisiz
	check(g.version == v1, "basarisiz islem version degistirmez")
	g.place_mill(0, 2)
	check(g.version > v1, "place_mill version arttirir")
	var v2: int = g.version
	g.remove(0, 2)
	check(g.version > v2, "remove version arttirir")
	var v3: int = g.version
	g.open_spring("A")
	check(g.version > v3, "open_spring version arttirir")
	var v4: int = g.version
	g.upgrade_width()
	check(g.version > v4, "upgrade_width version arttirir")
	var v5: int = g.version
	g.upgrade_lining()
	check(g.version > v5, "upgrade_lining version arttirir")

	var cache: Dictionary = {}
	var a: Dictionary = CanalFlow.compute_cached(g, cache)
	var b: Dictionary = CanalFlow.compute_cached(g, cache)
	check(is_same(a, b), "ayni versiyonda onbellekten gelir")
	for col in range(8):
		g.place_canal(col, 2)
	var c: Dictionary = CanalFlow.compute_cached(g, cache)
	check(not is_same(a, c), "versiyon degisince yeniden hesaplanir")
	check(c["delivered"] > 0.0, "yeni sonuc guncel")
	var other: RefCounted = make_grid()
	var d: Dictionary = CanalFlow.compute_cached(other, cache)
	check(not is_same(c, d), "baska izgara ayni onbellegi yanlis kullanmaz")


func test_flow_dir_straight() -> void:
	var g: RefCounted = make_grid()
	g.open_spring("A")
	line(g, 2)
	var r: Dictionary = CanalFlow.compute(g)
	var all_right: bool = true
	for col in range(8):
		if r["flow_dir"].get(Vector2i(col, 2), Vector2i.ZERO) != Vector2i(1, 0):
			all_right = false
	check(all_right, "duz hatta yon hep (1,0)")


func test_flow_dir_branch() -> void:
	# Pinar yolunda olmayan dal en yakin cikisa yonelir.
	var g: RefCounted = make_grid()
	g.open_spring("A")
	line(g, 2)
	g.place_canal(4, 3)
	g.place_canal(4, 4)
	var r: Dictionary = CanalFlow.compute(g)
	check(r["flowing"].size() == 10, "dal hucreleri de akiyor")
	check(r["flow_dir"][Vector2i(4, 4)] == Vector2i(0, -1), "dal ucu yukari (kanala) akar")
	check(r["flow_dir"][Vector2i(4, 3)] == Vector2i(0, -1), "dal ortasi yukari akar")


func test_upgrades() -> void:
	var g: RefCounted = make_grid()
	for i in range(4):
		check(g.upgrade_width(), "genis kanal yukseltilir")
	check(not g.upgrade_width(), "genis kanal azami seviyede false")
	for i in range(3):
		check(g.upgrade_lining(), "tas kaplama yukseltilir")
	check(not g.upgrade_lining(), "tas kaplama azami seviyede false")
	check(g.width_level == 4 and g.lining_level == 3, "seviyeler")
	check(g.open_spring("B"), "pinar acilir")
	check(not g.open_spring("B"), "acik pinar tekrar acilmaz")
	check(not g.open_spring("Z"), "bilinmeyen pinar acilmaz")


func test_serialization() -> void:
	var g: RefCounted = connector_grid()
	g.place_mill(4, 2)
	g.upgrade_width()
	g.upgrade_lining()
	var d: Dictionary = g.to_dict()
	# JSON gidis-donusu (sayilar float olur)
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var h: RefCounted = make_grid()
	h.from_dict(parsed)
	check(h.cells == g.cells, "hucreler ayni")
	check(h.open_springs == g.open_springs, "pinarlar ayni")
	check(h.width_level == 1 and h.lining_level == 1, "seviyeler ayni")
	near(CanalFlow.compute(h)["delivered"], CanalFlow.compute(g)["delivered"], "akis ayni")
	var k: RefCounted = make_grid()
	k.from_dict(d)
	check(k.cells == g.cells, "dogrudan sozluk gidis-donusu")


func test_bad_data() -> void:
	var g: RefCounted = make_grid()
	g.place_canal(0, 0)
	g.from_dict("bozuk")
	check(g.piece_count() == 0, "sozluk olmayan veri bos izgara")
	g.from_dict(null)
	check(g.piece_count() == 0, "null veri bos izgara")
	g.from_dict({"cells": [1, 2, 3]})
	check(g.piece_count() == 0, "yanlis boyutlu izgara bos")
	var bad: Array = []
	for i in range(40):
		bad.append(7)
	bad[0] = 1
	bad[1] = 2
	bad[2] = -1
	bad[3] = "x"
	bad[4] = 1.5
	bad[5] = null
	g.from_dict({"cells": bad, "open_springs": ["A", "Z", 5, "A", "C"], "width_level": 99, "lining_level": -3})
	check(g.get_cell(0, 0) == 1 and g.get_cell(1, 0) == 2, "gecerli hucreler korunur")
	check(g.get_cell(2, 0) == 0 and g.get_cell(3, 0) == 0 and g.get_cell(4, 0) == 0 and g.get_cell(5, 0) == 0, "gecersiz hucreler 0")
	check(g.get_cell(7, 4) == 0, "aralik disi deger 0")
	check(g.open_springs == ["A", "C"], "gecersiz ve tekrar eden pinarlar elenir")
	check(g.width_level == CanalConfig.WIDTH_MAX_LEVEL and g.lining_level == 0, "seviyeler kisitlanir")
	g.from_dict({"cells": "abc", "open_springs": 3, "width_level": "x"})
	check(g.piece_count() == 0 and g.width_level == 0 and g.open_springs.is_empty(), "yanlis turler varsayilana doner")
