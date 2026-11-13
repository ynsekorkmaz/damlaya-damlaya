extends SceneTree

const Pieces = preload("res://scripts/core/canal_pieces.gd")
const Network = preload("res://scripts/core/canal_network.gd")
const Flow = preload("res://scripts/core/canal_network_flow.gd")

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
	test_perpendicular_cuts_line()
	test_elbow_turns()
	test_tee_and_cross()
	test_wye()
	test_aqueduct()
	test_aqueduct_single_line()
	test_gate()
	test_blocked_spring_start()
	test_exit_needs_east_port()
	test_mixed_materials()
	test_reservoir()
	test_mill_cap()
	test_default_layout()
	test_costs()
	test_refund()
	test_place_rules_and_version()
	test_cache()
	test_flow_dir_straight()
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

func legacy_net() -> RefCounted:
	return Network.new(Pieces.LEGACY_COLS, Pieces.LEGACY_ROWS, Pieces.LEGACY_SPRINGS)


func put(net: RefCounted, col: int, row: int, piece: String, rot: int = 0, mat: String = "earth") -> void:
	var ok: bool = net.place(col, row, piece, rot, mat)
	check(ok, "yerlestirme basarisiz: %s (%d,%d)" % [piece, col, row])


## Satirda duz parcalar (E-W); skip_col verilen sutun atlanir.
func hline(net: RefCounted, row: int, skip_col: int = -1) -> void:
	for col in range(net.cols):
		if col != skip_col:
			put(net, col, row, "straight")


func open_all(net: RefCounted) -> void:
	for id in net.spring_ids():
		net.open_spring(id)


func three_lines(skip_col: int = -1) -> RefCounted:
	var g: RefCounted = legacy_net()
	open_all(g)
	hline(g, 0, skip_col)
	hline(g, 2, skip_col)
	hline(g, 4, skip_col)
	return g


## Sutun 3'te bes satiri dikey baglayan parcalar (sati 0 T asagi, 2 arti, 4 T yukari).
func add_vertical_links(g: RefCounted) -> void:
	put(g, 3, 0, "tee", 0)
	put(g, 3, 1, "straight", 1)
	put(g, 3, 2, "cross", 0)
	put(g, 3, 3, "straight", 1)
	put(g, 3, 4, "tee", 2)


func print_result(label: String, r: Dictionary) -> void:
	print("%s: delivered=%.2f leaked=%.2f overflow=%.2f wasted=%.2f input=%.2f" % [
		label, r["delivered"], r["leaked"], r["overflow"], r["wasted"], r["input"]])


func a_net() -> RefCounted:
	var g: RefCounted = legacy_net()
	g.open_spring("A")
	return g


# --- Belge 5.4 senaryolari ---

func test_scenario_1() -> void:
	var g: RefCounted = a_net()
	hline(g, 2)
	var r: Dictionary = Flow.compute(g)
	print_result("Senaryo 1", r)
	near(r["delivered"], 39.81, "s1 delivered")
	near(r["leaked"], 20.19, "s1 leaked")
	near(r["wasted"], 0.0, "s1 wasted")
	near(r["input"], 60.0, "s1 input")


func test_scenario_2() -> void:
	var g: RefCounted = legacy_net()
	open_all(g)
	hline(g, 2)
	var r: Dictionary = Flow.compute(g)
	print_result("Senaryo 2", r)
	near(r["wasted"], 660.0, "s2 wasted")
	near(r["delivered"], 39.81, "s2 delivered")


func test_scenario_3() -> void:
	var g: RefCounted = three_lines()
	var r: Dictionary = Flow.compute(g)
	print_result("Senaryo 3", r)
	near(r["delivered"], 199.81, "s3 delivered")
	near(r["overflow"], 277.86, "s3 overflow")
	near(r["leaked"], 242.34, "s3 leaked")


func test_scenario_4() -> void:
	var g: RefCounted = three_lines(3)
	add_vertical_links(g)
	var r: Dictionary = Flow.compute(g)
	print_result("Senaryo 4", r)
	near(r["delivered"], 240.0, "s4 delivered")
	near(r["overflow"], 237.66, "s4 overflow")


func test_scenario_5() -> void:
	var g: RefCounted = three_lines(3)
	add_vertical_links(g)
	g.remove(4, 2)
	put(g, 4, 2, "mill")
	var r: Dictionary = Flow.compute(g)
	print_result("Senaryo 5", r)
	near(r["delivered"], 259.2, "s5 delivered")


func test_scenario_6() -> void:
	var g: RefCounted = three_lines(3)
	add_vertical_links(g)
	g.remove(4, 2)
	put(g, 4, 2, "mill")
	for i in range(3):
		g.upgrade_lining()
	g.upgrade_width()
	g.upgrade_width()
	var r: Dictionary = Flow.compute(g)
	print_result("Senaryo 6", r)
	near(r["delivered"], 729.2, "s6 delivered")
	near(r["overflow"], 0.0, "s6 overflow")


# --- Baglanti kurallari ---

func test_perpendicular_cuts_line() -> void:
	var g: RefCounted = a_net()
	hline(g, 2, 4)
	put(g, 4, 2, "straight", 1)
	var r: Dictionary = Flow.compute(g)
	near(r["wasted"], 60.0, "dik parca hatti keser: wasted")
	near(r["delivered"], 0.0, "dik parca hatti keser: delivered")
	check(r["per_spring"]["A"]["reached"] == false, "dik parca: reached false")
	g.remove(4, 2)
	put(g, 4, 2, "straight", 0)
	check(Flow.compute(g)["per_spring"]["A"]["reached"], "duz parca ile hat bagli")


func test_elbow_turns() -> void:
	check(Pieces.elbow_rotation(Pieces.E, true) == 0, "dogu giden su sag dirsek donusu 0")
	check(Pieces.elbow_rotation(Pieces.E, false) == 1, "dogu giden su sol dirsek donusu 1")
	check(Pieces.elbow_rotation(Pieces.S, false) == 2, "guney giden su sol dirsek donusu 2")
	check(Pieces.elbow_rotation(Pieces.N, true) == 3, "kuzey giden su sag dirsek donusu 3")
	# Dogru donuslerle kose yol: L = 9
	var g: RefCounted = a_net()
	put(g, 0, 2, "straight")
	put(g, 1, 2, "straight")
	put(g, 2, 2, "elbow", Pieces.elbow_rotation(Pieces.E, true))
	put(g, 2, 3, "elbow", Pieces.elbow_rotation(Pieces.S, false))
	for col in range(3, 8):
		put(g, col, 3, "straight")
	var r: Dictionary = Flow.compute(g)
	var s: Dictionary = r["per_spring"]["A"]
	check(s["reached"], "dirsekli yol ulasir")
	check(s["path_length"] == 9, "kose yolda L=9, gelen %d" % s["path_length"])
	near(s["arrived"], 60.0 * pow(0.95, 9), "kose yol varis")
	near(r["delivered"], 60.0 * pow(0.95, 9), "kose yol delivered")
	# Yanlis donus keser
	g.rotate(2, 2)
	check(not Flow.compute(g)["per_spring"]["A"]["reached"], "yanlis dirsek donusu hatti keser")
	# Sol dirsek: kuzeye cikip doguya donen yol
	var h: RefCounted = a_net()
	put(h, 0, 2, "straight")
	put(h, 1, 2, "elbow", Pieces.elbow_rotation(Pieces.E, false))
	put(h, 1, 1, "elbow", Pieces.elbow_rotation(Pieces.N, true))
	for col in range(2, 8):
		put(h, col, 1, "straight")
	var s2: Dictionary = Flow.compute(h)["per_spring"]["A"]
	check(s2["reached"] and s2["path_length"] == 9, "sol dirsek yolu L=9")


func test_tee_and_cross() -> void:
	# T: dogu kolu eksik, yalniz guney kolundan cikis. L = 10
	for kind in ["tee", "cross"]:
		var g: RefCounted = a_net()
		put(g, 0, 2, "straight")
		put(g, 1, 2, "straight")
		put(g, 2, 2, "straight")
		put(g, 3, 2, kind, 0)
		put(g, 3, 3, "straight", 1)
		put(g, 3, 4, "elbow", Pieces.elbow_rotation(Pieces.S, false))
		for col in range(4, 8):
			put(g, col, 4, "straight")
		var s: Dictionary = Flow.compute(g)["per_spring"]["A"]
		check(s["reached"] and s["path_length"] == 10, "%s guney koldan yol L=10 (gelen %d)" % [kind, s["path_length"]])
	# T'nin ters donmusu (W yok) pinar girisini kesmez cunku W donusle gelir; N,S,W ile dene
	var h: RefCounted = a_net()
	put(h, 0, 2, "tee", 1)
	check(not Flow.compute(h)["per_spring"]["A"]["reached"], "tek T cikisa ulasmaz")
	check(Flow.compute(h)["wasted"] == 60.0, "tek T: wasted (cikis yok)")
	# T donusu 2: ağızlar W,E,N; kuzey kolu var, bati ağzi var
	var t2: Array = Pieces.rotated_nodes("tee", 2)
	check(t2[0].has(Pieces.N) and t2[0].has(Pieces.W) and t2[0].has(Pieces.E) and not t2[0].has(Pieces.S), "T donus 2 agizlari W,E,N")


func test_wye() -> void:
	# Govdeden guney koluna: L=10; yarim sizinti
	var g: RefCounted = a_net()
	for col in range(0, 3):
		put(g, col, 2, "straight")
	put(g, 3, 2, "wye", 0)
	put(g, 3, 3, "straight", 1)
	put(g, 3, 4, "elbow", Pieces.elbow_rotation(Pieces.S, false))
	for col in range(4, 8):
		put(g, col, 4, "straight")
	var s: Dictionary = Flow.compute(g)["per_spring"]["A"]
	check(s["reached"] and s["path_length"] == 10, "Y govdeden guney kola L=10")
	near(s["arrived"], 60.0 * pow(0.95, 9) * (1.0 - 0.025), "Y yarim sizinti")
	# Govdeden kuzey koluna
	var h: RefCounted = a_net()
	for col in range(0, 3):
		put(h, col, 2, "straight")
	put(h, 3, 2, "wye", 0)
	put(h, 3, 1, "straight", 1)
	put(h, 3, 0, "elbow", Pieces.elbow_rotation(Pieces.N, true))
	for col in range(4, 8):
		put(h, col, 0, "straight")
	check(Flow.compute(h)["per_spring"]["A"]["reached"], "Y govdeden kuzey kola ulasir")
	# Koldan kola gecis yok: donus 1 govde N, kollar E ve W; su W kolundan girer, E koluna gecemez
	var k: RefCounted = a_net()
	put(k, 0, 2, "straight")
	put(k, 1, 2, "straight")
	put(k, 2, 2, "wye", 1)
	for col in range(3, 8):
		put(k, col, 2, "straight")
	var r: Dictionary = Flow.compute(k)
	check(not r["per_spring"]["A"]["reached"], "Y: koldan kola gecis yok")
	near(r["wasted"], 60.0, "Y koldan kola: wasted")
	# Koldan govdeye gecis serbest: Y donus 3 (govde S, kollar W ve E?) yerine W kolundan govdeye cikis
	var m: RefCounted = a_net()
	put(m, 0, 2, "straight")
	put(m, 1, 2, "straight")
	put(m, 2, 2, "wye", 1)
	put(m, 2, 1, "straight", 1)
	put(m, 2, 0, "elbow", Pieces.elbow_rotation(Pieces.N, true))
	for col in range(3, 8):
		put(m, col, 0, "straight")
	check(Flow.compute(m)["per_spring"]["A"]["reached"], "Y: koldan govdeye gecis serbest")


func test_aqueduct() -> void:
	var g: RefCounted = legacy_net()
	g.open_spring("A")
	g.open_spring("B")
	# A: satir 2 duz hat, sutun 3 su kemeri (E-W hatti)
	for col in range(8):
		if col == 3:
			put(g, col, 2, "aqueduct", 0)
		else:
			put(g, col, 2, "straight")
	# B: satir 0 -> sutun 3'te asagi -> su kemerinin N-S hatti -> satir 4 -> doguya
	put(g, 0, 0, "straight")
	put(g, 1, 0, "straight")
	put(g, 2, 0, "straight")
	put(g, 3, 0, "elbow", Pieces.elbow_rotation(Pieces.E, true))
	put(g, 3, 1, "straight", 1)
	put(g, 3, 3, "straight", 1)
	put(g, 3, 4, "elbow", Pieces.elbow_rotation(Pieces.S, false))
	for col in range(4, 8):
		put(g, col, 4, "straight")
	var r: Dictionary = Flow.compute(g)
	var a: Dictionary = r["per_spring"]["A"]
	var b: Dictionary = r["per_spring"]["B"]
	check(a["reached"] and a["path_length"] == 8, "kemer: A yolu L=8")
	check(b["reached"] and b["path_length"] == 12, "kemer: B yolu L=12 (gelen %d)" % b["path_length"])
	# Iki ayri bilesen: B kendi 80 kapasitesinde tasar, A'ya karismaz
	var b_arr: float = 180.0 * pow(0.95, 12)
	near(r["overflow"], b_arr - 80.0, "kemer: iki hat ayri bilesen")
	near(r["delivered"], 60.0 * pow(0.95, 8) + 80.0, "kemer: delivered")
	var fd: Vector2i = r["flow_dir"][Vector2i(3, 2)]
	check(fd == Vector2i(0, 1), "kemer: baskin hat (B, asagi) yonu, gelen %s" % str(fd))


func test_aqueduct_single_line() -> void:
	# Yalnizca A acik: kemerin yalniz dogu-bati hatti akar; kuzey-guney hatti kurudur.
	var g: RefCounted = legacy_net()
	g.open_spring("A")
	for col in range(8):
		put(g, col, 2, "aqueduct" if col == 3 else "straight")
	put(g, 3, 1, "straight", 1)
	put(g, 3, 3, "straight", 1)
	var r: Dictionary = Flow.compute(g)
	check(r.has("flowing_nodes"), "kemer tek hat: flowing_nodes anahtari var")
	var fn: Dictionary = r["flowing_nodes"]
	check(fn.has(Vector2i(3, 2)), "kemer tek hat: kemer akan hucre")
	var mouths: Array = fn.get(Vector2i(3, 2), [])
	check(mouths.has(Pieces.E) and mouths.has(Pieces.W), "kemer tek hat: dogu-bati agizlari akiyor")
	check(not mouths.has(Pieces.N) and not mouths.has(Pieces.S), "kemer tek hat: kuzey-guney agizlari akmiyor")
	check(not fn.has(Vector2i(3, 1)) and not fn.has(Vector2i(3, 3)), "kemer tek hat: dik hatta bagli parcalar kuru")
	# Dondurulmus kemer: ayni hat artik kuzey-guney eksenindedir.
	var h: RefCounted = legacy_net()
	h.open_spring("A")
	for col in range(8):
		put(h, col, 2, "aqueduct" if col == 3 else "straight")
	h.rotate(3, 2)
	put(h, 3, 1, "straight", 1)
	put(h, 3, 3, "straight", 1)
	# Dondurulunce E-W hatti N-S'ye gecer; A hatti kemere girince kesilir.
	var r2: Dictionary = Flow.compute(h)
	check(not r2["flowing_nodes"].has(Vector2i(3, 2)) or not (r2["flowing_nodes"][Vector2i(3, 2)] as Array).has(Pieces.N), "kemer donuk: akis olmayan hat akmaz")
	# Iki hat da akinca ikisi de listelenir.
	var d: RefCounted = legacy_net()
	d.open_spring("A")
	d.open_spring("B")
	for col in range(8):
		put(d, col, 2, "aqueduct" if col == 3 else "straight")
	put(d, 0, 0, "straight")
	put(d, 1, 0, "straight")
	put(d, 2, 0, "straight")
	put(d, 3, 0, "elbow", Pieces.elbow_rotation(Pieces.E, true))
	put(d, 3, 1, "straight", 1)
	put(d, 3, 3, "straight", 1)
	put(d, 3, 4, "elbow", Pieces.elbow_rotation(Pieces.S, false))
	for col in range(4, 8):
		put(d, col, 4, "straight")
	var m: Array = Flow.compute(d)["flowing_nodes"].get(Vector2i(3, 2), [])
	check(m.size() == 4, "kemer iki hat: dort agiz akiyor (gelen %d)" % m.size())


func test_gate() -> void:
	var g: RefCounted = a_net()
	hline(g, 2, 3)
	put(g, 3, 2, "gate", 0)
	check(g.get_piece(3, 2)["open"] == true, "savak baslangicta acik")
	near(Flow.compute(g)["delivered"], 39.81, "acik savak bagli")
	check(g.toggle_gate(3, 2), "savak kapatilir")
	var r: Dictionary = Flow.compute(g)
	near(r["wasted"], 60.0, "kapali savak hatti keser")
	near(r["delivered"], 0.0, "kapali savak: delivered")
	g.toggle_gate(3, 2)
	near(Flow.compute(g)["delivered"], 39.81, "savak acilinca bagli")
	check(not g.toggle_gate(4, 2), "savak olmayan hucrede toggle false")
	check(not g.toggle_gate(4, 4), "bos hucrede toggle false")
	# Cikistaki kapali savak cikis sayilmaz
	var h: RefCounted = a_net()
	hline(h, 2, 7)
	put(h, 7, 2, "gate", 0)
	h.toggle_gate(7, 2)
	near(Flow.compute(h)["wasted"], 60.0, "cikistaki kapali savak cikis degil")


func test_blocked_spring_start() -> void:
	var g: RefCounted = a_net()
	hline(g, 2, 0)
	var r: Dictionary = Flow.compute(g)
	near(r["wasted"], 60.0, "pinar hucresi bos: wasted")
	put(g, 0, 2, "straight", 1)
	r = Flow.compute(g)
	near(r["wasted"], 60.0, "pinar hucresinde bati agzi yok: wasted")
	g.rotate(0, 2)
	r = Flow.compute(g)
	near(r["wasted"], 0.0, "bati agzi gelince wasted yok")
	near(r["delivered"], 39.81, "bati agzi gelince delivered")


func test_exit_needs_east_port() -> void:
	var g: RefCounted = a_net()
	hline(g, 2, 7)
	put(g, 7, 2, "straight", 1)
	near(Flow.compute(g)["wasted"], 60.0, "son sutunda dogu agzi olmayan parca cikis degil")
	var h: RefCounted = a_net()
	hline(h, 2, 7)
	put(h, 7, 2, "elbow", 0)
	near(Flow.compute(h)["wasted"], 60.0, "dirsek (W,S) cikis degil")
	h.remove(7, 2)
	put(h, 7, 2, "elbow", 3)
	check(Pieces.rotated_nodes("elbow", 3)[0].has(Pieces.E), "elbow donus 3 dogu agzi var")
	check(not Flow.compute(h)["per_spring"]["A"]["reached"], "elbow donus 3: bati agzi yok, ulasmaz")


func test_mixed_materials() -> void:
	var g: RefCounted = a_net()
	for col in range(8):
		var mat: String = "earth"
		if col >= 4:
			mat = "stone"
		elif col >= 2:
			mat = "wood"
		put(g, col, 2, "straight", 0, mat)
	var r: Dictionary = Flow.compute(g)
	var expected: float = 60.0 * pow(0.95, 2) * pow(0.97, 2) * pow(0.988, 4)
	near(r["delivered"], expected, "karisik malzeme varis")
	near(r["delivered"], 60.0 * 0.9025 * 0.9409 * 0.952859, "karisik malzeme elle")
	g.upgrade_lining()
	r = Flow.compute(g)
	var e1: float = 60.0 * pow(1.0 - 0.035, 2) * pow(1.0 - 0.021, 2) * pow(1.0 - 0.0084, 4)
	near(r["delivered"], e1, "karisik malzeme + kaplama 1")
	near(Pieces.leak("straight", "earth", 1), 0.035, "toprak kaplama 1 = 0.035")
	near(Pieces.leak("straight", "earth", 2), 0.02, "toprak kaplama 2 = 0.02")
	near(Pieces.leak("straight", "earth", 3), 0.008, "toprak kaplama 3 = 0.008")
	near(Pieces.leak("wye", "earth", 0), 0.025, "Y yarim sizinti")


func test_reservoir() -> void:
	# C (480) satir 4: varis 480*0.95^8 = 318.4; kapasite 80 + 40 * min(havuz, 2)
	var arrival: float = 480.0 * pow(0.95, 8)
	var expect_over: Array = [arrival - 80.0, arrival - 120.0, arrival - 160.0, arrival - 160.0]
	for n in range(4):
		var g: RefCounted = legacy_net()
		g.open_spring("C")
		for col in range(8):
			if col >= 1 and col <= n:
				put(g, col, 4, "reservoir", 0)
			else:
				put(g, col, 4, "straight")
		near(Flow.compute(g)["overflow"], expect_over[n], "havuz sayisi %d: overflow" % n)
	# Genislik 1: havuz eki 80, cikis 160
	var h: RefCounted = legacy_net()
	h.open_spring("C")
	for col in range(8):
		if col == 1:
			put(h, col, 4, "reservoir", 0)
		else:
			put(h, col, 4, "straight")
	h.upgrade_width()
	near(Flow.compute(h)["overflow"], arrival - 240.0, "havuz eki genislikle buyur")
	near(Pieces.reservoir_extra(2), 160.0, "havuz eki 40*2^2")


func test_mill_cap() -> void:
	# C hatti: varis 318.4 > 80, taban 80; degirmen bonusu en fazla 3
	var expected: Array = [80.0, 86.4, 92.8, 99.2, 99.2]
	for n in range(5):
		var g: RefCounted = legacy_net()
		g.open_spring("C")
		for col in range(8):
			if col >= 1 and col <= n:
				put(g, col, 4, "mill", 0)
			else:
				put(g, col, 4, "straight")
		near(Flow.compute(g)["delivered"], expected[n], "degirmen sayisi %d" % n)


func test_default_layout() -> void:
	var g: RefCounted = Network.new()
	check(g.cols == 14 and g.rows == 10, "varsayilan 14x10")
	check(g.spring_ids() == ["A", "B", "C"], "varsayilan pinarlar")
	check(g.spring_defs["A"]["row"] == 4 and g.spring_defs["B"]["row"] == 1 and g.spring_defs["C"]["row"] == 8, "varsayilan pinar satirlari")
	g.open_spring("A")
	for col in range(14):
		put(g, col, 4, "straight")
	var r: Dictionary = Flow.compute(g)
	near(r["delivered"], 80.0 * pow(0.95, 14), "14 sutunluk hat")
	check(r["per_spring"]["A"]["path_length"] == 14, "14 sutun L=14")
	check(not g.place(14, 0, "straight", 0, "earth"), "sinir disi (sutun)")
	check(not g.place(0, 10, "straight", 0, "earth"), "sinir disi (satir)")


# --- Maliyet ---

func test_costs() -> void:
	var g: RefCounted = Network.new()
	check(g.cost("straight", "earth") == 30, "duz toprak 30")
	check(g.cost("straight", "wood") == 75, "duz ahsap 75")
	check(g.cost("straight", "stone") == 180, "duz tas 180")
	check(g.cost("elbow", "earth") == 32, "dirsek 32")
	check(g.cost("tee", "earth") == 45, "T 45")
	check(g.cost("wye", "earth") == 60, "Y 60")
	check(g.cost("cross", "earth") == 60, "arti 60")
	check(g.cost("gate", "earth") == 90, "savak 90")
	check(g.cost("aqueduct", "earth") == 150, "kemer 150")
	check(g.cost("reservoir", "earth") == 400, "havuz 400")
	check(g.cost("mill", "earth") == 600, "degirmen 600")
	check(g.cost("mill", "wood") == 1500, "degirmen ahsap 1500")
	check(g.cost("mill", "stone") == 3600, "degirmen tas 3600")
	check(g.cost("nope", "earth") == -1 and g.cost("straight", "nope") == -1, "bilinmeyen -1")
	for i in range(10):
		put(g, i, 0, "straight")
	check(g.cost("straight", "earth") == 44, "10 parca sonra duz 44, gelen %d" % g.cost("straight", "earth"))
	check(g.cost("elbow", "earth") == 47, "10 parca sonra dirsek 47")
	check(g.cost("straight", "stone") == 266, "10 parca sonra tas duz 266")
	# Degirmen kendi artisiyla: parca sayisindan bagimsiz
	put(g, 0, 1, "mill")
	put(g, 1, 1, "mill")
	check(g.cost("mill", "earth") == 1350, "2 degirmen sonra 1350, gelen %d" % g.cost("mill", "earth"))
	check(g.mill_count() == 2 and g.piece_count() == 12 and g.count_of("straight") == 10, "sayimlar")
	check(g.width_cost() == 12000 and g.lining_cost() == 15000, "yukseltme ilk maliyetleri")
	g.upgrade_width()
	g.upgrade_lining()
	check(g.width_cost() == 48000 and g.lining_cost() == 60000, "yukseltme ikinci maliyetleri")
	check(Pieces.width_upgrade_cost(4) == -1 and Pieces.lining_upgrade_cost(3) == -1, "azami seviyede -1")
	check(g.spring_cost("C") == 250000 and g.spring_cost("Z") == -1, "pinar maliyeti")


func test_refund() -> void:
	var g: RefCounted = Network.new()
	for i in range(10):
		put(g, i, 0, "straight")
	# 9 parca sonra: floor(30 * 1.04^9) = 42, iade 21
	check(g.removal_refund(9, 0) == 21, "iade onizleme 21")
	check(g.remove(9, 0) == 21, "duz iade 21")
	check(g.get_piece(9, 0).is_empty() and g.piece_count() == 9, "sokulen hucre bosalir")
	check(g.remove(9, 0) == 0, "bos hucre iadesi 0")
	put(g, 9, 0, "straight", 0, "wood")
	# 9 parca sonra ahsap: floor(75 * 1.04^9) = 106, iade 53
	check(g.remove(9, 0) == 53, "ahsap iade 53")
	put(g, 0, 1, "mill")
	put(g, 1, 1, "mill")
	# Bir degirmen sokulunce kalan 1 degirmen: floor(600*1.5)=900, iade 450
	check(g.remove(1, 1) == 450, "degirmen iade 450")
	check(g.remove(0, 1) == 300, "son degirmen iade 300")


func test_place_rules_and_version() -> void:
	var g: RefCounted = legacy_net()
	var v0: int = g.version
	check(g.place(1, 1, "straight", 0, "earth"), "bos hucreye konur")
	check(g.version > v0, "place version artirir")
	var v1: int = g.version
	check(not g.place(1, 1, "elbow", 0, "earth"), "dolu hucreye konmaz")
	check(g.version == v1, "basarisiz place version artirmaz")
	check(not g.place(1, 2, "bogus", 0, "earth"), "bilinmeyen parca reddedilir")
	check(not g.place(1, 2, "straight", 0, "bogus"), "bilinmeyen malzeme reddedilir")
	check(not g.place(-1, 0, "straight", 0, "earth"), "negatif sutun")
	check(g.place(2, 2, "straight", 5, "earth") and g.get_piece(2, 2)["rotation"] == 1, "donus 4'e indirgenir")
	check(g.rotate(1, 1) and g.get_piece(1, 1)["rotation"] == 1, "rotate")
	check(g.version > v1, "rotate version artirir")
	for i in range(3):
		g.rotate(1, 1)
	check(g.get_piece(1, 1)["rotation"] == 0, "dort rotate basa doner")
	check(not g.rotate(5, 4) and not g.rotate(9, 9), "bos/sinir disi rotate false")
	check(g.get_piece(0, 0) == {}, "bos hucre {}")
	var v2: int = g.version
	g.remove(1, 1)
	check(g.version > v2, "remove version artirir")
	var v3: int = g.version
	g.open_spring("A")
	check(g.version > v3 and not g.open_spring("A") and not g.open_spring("Z"), "open_spring")
	var v4: int = g.version
	g.upgrade_width()
	g.upgrade_lining()
	check(g.version > v4 + 1, "yukseltmeler version artirir")
	for i in range(10):
		g.upgrade_width()
		g.upgrade_lining()
	check(g.width_level == 4 and g.lining_level == 3, "azami seviye")
	check(not g.upgrade_width() and not g.upgrade_lining(), "azami seviyede false")


func test_cache() -> void:
	var g: RefCounted = a_net()
	hline(g, 2)
	var cache: Dictionary = {}
	var r1: Dictionary = Flow.compute_cached(g, cache)
	var r2: Dictionary = Flow.compute_cached(g, cache)
	check(is_same(r1, r2), "ayni surumde onbellek ayni sonucu verir")
	g.remove(7, 2)
	var r3: Dictionary = Flow.compute_cached(g, cache)
	check(not is_same(r1, r3), "degisince yeniden hesaplanir")
	near(r3["wasted"], 60.0, "yeni sonuc dogru")
	var other: RefCounted = a_net()
	hline(other, 2)
	check(not is_same(Flow.compute_cached(other, cache), r3), "baska izgara icin onbellek kullanilmaz")


func test_flow_dir_straight() -> void:
	var g: RefCounted = a_net()
	hline(g, 2)
	var r: Dictionary = Flow.compute(g)
	check(r["flowing"].size() == 8, "8 akan hucre")
	var all_east: bool = true
	for col in range(8):
		if r["flow_dir"].get(Vector2i(col, 2), Vector2i.ZERO) != Vector2i(1, 0):
			all_east = false
	check(all_east, "duz hatta flow_dir hep (1,0)")
	# Yoldan disaridaki kol da cikisa dogru yonelir
	put(g, 4, 1, "elbow", Pieces.elbow_rotation(Pieces.N, true))
	var r2: Dictionary = Flow.compute(g)
	check(not r2["flowing"].has(Vector2i(4, 1)), "bagli olmayan parca akmaz")


func test_serialization() -> void:
	var g: RefCounted = three_lines(3)
	add_vertical_links(g)
	g.remove(4, 2)
	put(g, 4, 2, "mill", 0, "wood")
	g.remove(5, 2)
	put(g, 5, 2, "gate", 0, "stone")
	g.toggle_gate(5, 2)
	g.upgrade_width()
	g.upgrade_lining()
	var json: String = JSON.stringify(g.to_dict())
	var parsed: Variant = JSON.parse_string(json)
	var h: RefCounted = legacy_net()
	h.from_dict(parsed)
	check(h.to_dict() == g.to_dict(), "gidis-donus ayni durum")
	check(h.get_piece(5, 2)["open"] == false, "savak durumu korunur")
	near(Flow.compute(h)["delivered"], Flow.compute(g)["delivered"], "gidis-donus ayni sonuc")
	# Dogrudan sozluk (JSON'suz) gidis-donus
	var k: RefCounted = legacy_net()
	k.from_dict(g.to_dict())
	check(k.to_dict() == g.to_dict(), "sozluk gidis-donus")
	# Varsayilan boyut
	var d: RefCounted = Network.new()
	put(d, 13, 9, "elbow", 2, "stone")
	var d2: RefCounted = Network.new()
	d2.from_dict(d.to_dict())
	check(d2.get_piece(13, 9)["piece"] == "elbow" and d2.get_piece(13, 9)["rotation"] == 2, "14x10 gidis-donus")


func test_bad_data() -> void:
	var g: RefCounted = legacy_net()
	put(g, 0, 0, "straight")
	g.from_dict(null)
	check(g.piece_count() == 0, "null: bos izgara")
	g.from_dict(42)
	check(g.piece_count() == 0, "sayi: bos izgara")
	g.from_dict({"cols": 8, "rows": 5, "cells": "abc"})
	check(g.piece_count() == 0, "cells dizi degil: bos")
	g.from_dict({"cols": 8, "rows": 5, "cells": [{}, {}]})
	check(g.piece_count() == 0, "yanlis hucre sayisi: bos")
	var good: RefCounted = legacy_net()
	put(good, 1, 1, "straight")
	put(good, 2, 1, "elbow", 1)
	put(good, 3, 1, "tee", 2)
	var d: Dictionary = good.to_dict()
	var w: RefCounted = Network.new()
	w.from_dict(d)
	check(w.piece_count() == 0, "yanlis boyut: bos izgara")
	# Bilinmeyen parca/malzeme/donus hucreyi bosaltir
	var cells: Array = d["cells"]
	cells[8 * 1 + 1] = {"piece": "banana", "rotation": 0, "material": "earth"}
	cells[8 * 1 + 2] = {"piece": "elbow", "rotation": 1, "material": "gold"}
	cells[8 * 1 + 3] = {"piece": "tee", "rotation": 9, "material": "earth"}
	cells[8 * 1 + 4] = {"piece": "straight", "rotation": 1.0, "material": "stone"}
	cells[8 * 1 + 5] = 7
	cells[8 * 1 + 6] = {"piece": "mill"}
	d["open_springs"] = ["A", "Z", 5, "A"]
	d["width_level"] = 99
	d["lining_level"] = -3
	var h: RefCounted = legacy_net()
	h.from_dict(d)
	check(h.piece_count() == 1, "gecersiz hucreler bosalir, 1 gecerli kalir (kalan %d)" % h.piece_count())
	check(h.get_piece(4, 1)["piece"] == "straight" and h.get_piece(4, 1)["rotation"] == 1, "float donus kabul edilir")
	check(h.open_springs == ["A"], "gecersiz pinar elenir")
	check(h.width_level == 4 and h.lining_level == 0, "seviyeler sinirlanir")
	# Bozuk durumda hesap cokmez
	Flow.compute(h)
	check(true, "bozuk veriden sonra hesap calisir")
