extends SceneTree
## Cekic, serbest yapilar (kamis, agac, pasif kaynaklar), kanal yerlestirme arayuzu ve kayit gocu.

const Cfg = preload("res://scripts/core/economy_config.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Build = preload("res://scripts/core/build.gd")
const SaveCodec = preload("res://scripts/core/save_codec.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const GameScript = preload("res://scripts/game/game.gd")

const LOCKED_REASON: String = "Önce Geliştirmeler'den (Tab) kilidini aç"
const NO_HAMMER_REASON: String = "Önce dükkândan bir çekiç al"

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	test_hammer_economy()
	test_hammer_game()
	test_structure_gates()
	test_reeds_and_trees()
	test_source_structures()
	test_remove_structure()
	test_canal_reasons()
	test_canal_place_remove()
	test_canal_delivery_tick()
	test_canal_unlocks()
	test_save_roundtrip()
	test_save_migration()
	test_save_corrupt_structures()
	test_legacy_canal_save()
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func near(a: float, b: float, eps: float = 1e-6) -> bool:
	return absf(a - b) <= eps


func _game(money: float = 0.0) -> Node:
	var g: Node = GameScript.new()
	g.setup(false)
	g.state.money = money
	return g


## Cekic elde, kanal acik, para bol.
func _rich_game() -> Node:
	var g: Node = _game(1.0e9)
	g.state.hammer_unlocked = true
	g.state.hammer_owned = true
	g.state.canal_unlocked = true
	return g


# ---------- Cekic ----------

func test_hammer_economy() -> void:
	var s: GameState = GameState.new()
	check(BuildCfg.HAMMER_UNLOCK_COST == 40.0 and BuildCfg.HAMMER_COST == 60.0, "cekic sayilari 40 ve 60")
	check(Economy.cost_hammer_unlock(s) == 40.0 and Economy.cost_hammer(s) == 60.0, "cekic maliyetleri")
	s.money = 1.0e6
	check(not Economy.buy_hammer(s) and not s.hammer_owned and s.money == 1.0e6, "kilitsiz cekic dukkanda alinamaz")
	check(Economy.unlock_hammer(s) and s.hammer_unlocked and near(s.money, 1.0e6 - 40.0), "cekic kilidi acilir, para duser")
	check(not s.hammer_owned and Economy.cost_hammer_unlock(s) < 0.0 and not Economy.unlock_hammer(s), "kilit acmak cekici vermez, bir kez")
	check(Economy.buy_hammer(s) and s.hammer_owned and near(s.money, 1.0e6 - 100.0), "cekic alinir")
	check(not Economy.buy_hammer(s) and Economy.cost_hammer(s) < 0.0, "cekic bir kez alinir")
	# Tab satiri gorunurlugu: kilit maliyetinin yarisi (20), dukkan satiri 30
	var v: GameState = GameState.new()
	check(not Economy.hammer_row_visible(v) and not Economy.hammer_shop_visible(v), "cekic satiri baslangicta gizli")
	v.total_money_earned = 19.0
	check(not Economy.hammer_row_visible(v), "19 paraya gizli")
	v.total_money_earned = 20.0
	check(Economy.hammer_row_visible(v) and not Economy.hammer_shop_visible(v), "20 paraya Tab satiri gorunur")
	v.total_money_earned = 30.0
	check(Economy.hammer_shop_visible(v), "30 paraya dukkan satiri gorunur")
	var w: GameState = GameState.new()
	w.hammer_unlocked = true
	check(Economy.hammer_row_visible(w), "kilidi acik cekic satiri kalir")
	var poor: GameState = GameState.new()
	poor.money = 39.0
	check(not Economy.unlock_hammer(poor) and not poor.hammer_unlocked, "para yetmez")
	# Alet siralamasindan bagimsiz
	var t: GameState = GameState.new()
	t.money = 1.0e6
	Economy.unlock_hammer(t)
	Economy.buy_hammer(t)
	check(t.tool_level == 0 and t.tool_unlocked == 0, "cekic su alet siralamasini degistirmez")


func test_hammer_game() -> void:
	var g: Node = _game(1000.0)
	var bought: Array[String] = []
	g.connect("purchased", func(k: String, i: String) -> void: bought.append(k + ":" + i))
	check(not g.buy_hammer(), "kilitliyken dukkanda alinmaz")
	check(g.unlock_hammer() and g.state.hammer_unlocked, "kilit acilir")
	check(g.buy_hammer() and g.state.hammer_owned and near(g.state.money, 900.0), "cekic alinir")
	check(bought == ["hammer_unlock:hammer", "hammer:hammer"], "cekic sinyalleri (%s)" % str(bought))
	g.free()


# ---------- Yapi kapilari ----------

func test_structure_gates() -> void:
	var g: Node = _game(1.0e9)
	var r: Dictionary = g.can_place_structure("reeds")
	check(not r["ok"] and r["reason_tr"] == NO_HAMMER_REASON, "cekicsiz kamis: neden metni")
	check(not g.place_structure("reeds", 1.0, 1.0, 0.0) and g.state.structures.is_empty() and g.state.money == 1.0e9, "cekicsiz yapi kurulamaz, para ayni")
	g.state.hammer_unlocked = true
	g.state.hammer_owned = true
	# Kilitli kaynak ve kamis/agac: Tab'dan kilit acilmadan kurulamaz
	for kind: String in Build.kind_ids():
		var c: Dictionary = g.can_place_structure(kind)
		check(not c["ok"] and c["reason_tr"] == LOCKED_REASON, "kilitli %s: neden metni (%s)" % [kind, c["reason_tr"]])
		check(not g.place_structure(kind, 1.0, 1.0, 0.0), "kilitli %s kurulamaz" % kind)
	check(g.state.structures.is_empty() and g.state.money == 1.0e9, "kilitliyken hicbir sey kurulmadi")
	check(g.unlock_source("crack") and g.can_place_structure("crack")["ok"], "kilit acilinca kaynak kurulabilir")
	check(not g.can_place_structure("dew")["ok"], "baska kaynagin kilidi ayri")
	check(g.unlock_structure("reeds") and g.can_place_structure("reeds")["ok"], "kamis kilidi acilinca kurulur")
	check(not g.unlock_structure("crack"), "kaynak kilidi unlock_structure ile acilmaz")
	var unk: Dictionary = g.can_place_structure("yok")
	check(not unk["ok"] and unk["cost"] == -1, "bilinmeyen tur")
	# Para yetmiyor
	g.state.money = 1.0
	var poor: Dictionary = g.can_place_structure("crack")
	check(not poor["ok"] and poor["reason_tr"] == "Paran yetmiyor" and poor["cost"] == 15, "para yetmiyor, maliyet doner")
	# Koordinat dogrulamasi
	g.state.money = 1.0e9
	check(not g.place_structure("crack", NAN, 1.0, 0.0) and not g.place_structure("crack", 1.0, INF, 0.0) and not g.place_structure("crack", 1.0, 1.0, NAN), "sonlu olmayan koordinat reddedilir")
	g.free()


func test_reeds_and_trees() -> void:
	var g: Node = _rich_game()
	g.unlock_structure("reeds")
	g.unlock_structure("shade_tree")
	var reed_costs: Array[int] = [60, 90, 135, 202, 303, 455, 683, 1025]
	var tree_costs: Array[int] = [700, 1050, 1575, 2362]
	var signals: Array[int] = [0]
	g.connect("structures_changed", func() -> void: signals[0] += 1)
	for i: int in reed_costs.size():
		var c: Dictionary = g.can_place_structure("reeds")
		check(c["cost"] == reed_costs[i], "kamis maliyeti adet %d: %d" % [i, c["cost"]])
		check(c["ok"], "kamis %d kurulabilir (7den sonra da)" % i)
		check((c["note_tr"] == "Daha fazlası kaybı azaltmaz") == (i >= 7), "kamis %d not metni" % i)
		var before: float = g.state.money
		check(g.place_structure("reeds", float(i), 0.0, 0.0) and near(g.state.money, before - reed_costs[i]), "kamis %d kurulur, para duser" % i)
	check(signals[0] == reed_costs.size(), "structures_changed her kurulusta yayilir")
	for i: int in tree_costs.size():
		check(g.can_place_structure("shade_tree")["cost"] == tree_costs[i], "agac maliyeti adet %d" % i)
		g.place_structure("shade_tree", 0.0, float(i), 0.0)
	check(Build.count(g.state, "reeds") == 8 and Build.effective_count(g.state, "reeds") == 7, "8 kamis, 7 sayilir")
	# Etki: 7 kamis tam, 8. etkisiz
	var s: GameState = GameState.new()
	for i: int in 3:
		Build.add(s, "reeds", 0.0, 0.0, 0.0)
	check(near(Economy.loss_fraction(s), 0.27), "3 kamis: kayip 27")
	for i: int in 4:
		Build.add(s, "reeds", 0.0, 0.0, 0.0)
	check(near(Economy.loss_fraction(s), 0.23), "7 kamis: kayip 23")
	Build.add(s, "reeds", 0.0, 0.0, 0.0)
	check(near(Economy.loss_fraction(s), 0.23), "8. kamis kaybi degistirmez")
	for i: int in 7:
		Build.add(s, "shade_tree", 0.0, 0.0, 0.0)
	check(near(Economy.loss_fraction(s), 0.16), "7 kamis + 7 agac: kayip 16")
	s.loss_upgrades = ["rock_bed", "clay_floor"]
	check(near(Economy.loss_fraction(s), 0.03), "tum kayip kalemleriyle %3")
	check(Cfg.LOSS_UPGRADES.size() == 2 and Economy.loss_def("reed_edge").is_empty() and Economy.loss_def("shade_trees").is_empty(), "eski kamis/agac yukseltmeleri kalkti")
	g.free()


func test_source_structures() -> void:
	var s: GameState = GameState.new()
	s.hammer_owned = true
	s.hammer_unlocked = true
	s.money = 1.0e12
	var expect_costs: Dictionary = {"crack": [15, 19, 25, 32, 42], "dew": [100, 130, 169, 219]}
	for kind: String in expect_costs:
		s.unlocked_sources.append(kind)
		var list: Array = expect_costs[kind]
		for i: int in list.size():
			check(Build.can_place(s, kind)["cost"] == list[i], "%s adet %d maliyeti 1,3 carpanli" % [kind, i])
			check(Build.place(s, kind, 1.0, 2.0, 0.0), "%s kurulur" % kind)
	# Uretim: yapilardan turetilir
	var crack_n: int = 5
	var dew_n: int = 4
	check(Economy.source_count(s, "crack") == crack_n and Economy.source_count(s, "dew") == dew_n, "kaynak sayilari yapilardan turetilir")
	check(near(Economy.passive_rate_gross(s), 0.5 * crack_n + 3.0 * dew_n), "uretim: yapilarin toplami")
	check(near(Economy.passive_rate_net(s), (0.5 * crack_n + 3.0 * dew_n) * 0.7), "net uretim %30 kayipla")
	# sources ile structures tutarli: sayilar listeyle birebir
	var counted: Dictionary = {}
	for item: Dictionary in s.structures:
		counted[item["kind"]] = int(counted.get(item["kind"], 0)) + 1
	check(counted == s.counts, "counts structures listesiyle ayni")
	# Her kaynagin uretimi config ile ayni
	for def: Dictionary in Cfg.SOURCES:
		var t: GameState = GameState.new()
		Build.add(t, def["id"], 0.0, 0.0, 0.0)
		check(near(Economy.passive_rate_gross(t), float(def["rate"])), "uretim %s" % def["id"])
	# Eski buy_source yolu kalmadi: kilit disinda tek yol yapi
	check(Economy.cost_source(s, "yok") < 0.0, "bilinmeyen kaynak -1")
	# 1000 yapida maliyet tasmaz
	var big: GameState = GameState.new()
	for i: int in 400:
		Build.add(big, "stream_mouth", 0.0, 0.0, 0.0)
	check(Build.next_cost(big, "stream_mouth") <= BuildCfg.MAX_COST and Build.next_cost(big, "stream_mouth") > 0.0, "asiri adette maliyet sinirli")


func test_remove_structure() -> void:
	var g: Node = _rich_game()
	g.unlock_source("crack")
	for i: int in 4:
		g.place_structure("crack", float(i), 0.0, 0.0)
	# 4 adet var; sokulunca 3 kalir: iade floor(cost(3 adet var) / 2) = floor(32 / 2): cost_at(3) = floor(15 * 1,3^3) = 32
	var before: float = g.state.money
	var refund: int = g.remove_structure(1)
	check(refund == 16 and near(g.state.money, before + 16.0), "iade: sokulduktan sonraki adet (3) fiyatinin yarisi (%d)" % refund)
	check(Build.count(g.state, "crack") == 3 and g.state.structures.size() == 3, "adet ve liste azalir")
	check(g.state.structures[1]["x"] == 2.0, "dogru yapi sokuldu")
	check(g.remove_structure(99) == 0 and g.remove_structure(-1) == 0, "gecersiz indeks 0")
	g.state.hammer_owned = false
	var n: int = g.state.structures.size()
	check(g.remove_structure(0) == 0 and g.state.structures.size() == n, "cekicsiz sokulemez")
	g.state.hammer_owned = true
	for i: int in 3:
		g.remove_structure(0)
	check(g.state.counts.is_empty() and g.state.structures.is_empty(), "hepsi sokulunce sayim bosalir")
	check(g.structures().is_empty(), "structures() bos")
	# structures() kopya dondurur
	g.place_structure("crack", 5.0, 6.0, 1.0)
	var list: Array = g.structures()
	list[0]["x"] = 99.0
	check(g.state.structures[0]["x"] == 5.0, "structures() kopya")
	# Konumsuz yapiya yer verme
	Build.add(g.state, "crack", 0.0, 0.0, 0.0, false)
	check(g.set_structure_position(1, 3.0, 4.0, 0.5) and bool(g.state.structures[1]["placed"]) and g.state.structures[1]["x"] == 3.0, "konumsuz yapiya yer verilir")
	check(not g.set_structure_position(9, 0.0, 0.0, 0.0) and not g.set_structure_position(1, NAN, 0.0, 0.0), "gecersiz konum reddedilir")
	g.free()


# ---------- Kanal ----------

func test_canal_reasons() -> void:
	var g: Node = _game(1.0e9)
	var r: Dictionary = g.can_place_canal(0, 4, "straight", 0, "earth")
	check(not r["ok"] and r["reason_tr"] == NO_HAMMER_REASON and r["cost"] == 30, "cekic yok")
	g.state.hammer_owned = true
	g.state.hammer_unlocked = true
	r = g.can_place_canal(0, 4, "straight", 0, "earth")
	check(not r["ok"] and r["reason_tr"] == "Önce Geliştirmeler'den (Tab) kanal sistemini aç", "kanal kilitli")
	g.state.canal_unlocked = true
	r = g.can_place_canal(0, 4, "elbow", 0, "earth")
	check(not r["ok"] and r["reason_tr"] == LOCKED_REASON, "parca kilitli")
	r = g.can_place_canal(0, 4, "straight", 0, "wood")
	check(not r["ok"] and r["reason_tr"] == LOCKED_REASON, "malzeme kilitli")
	r = g.can_place_canal(-1, 4, "straight", 0, "earth")
	check(not r["ok"] and r["reason_tr"] == "Burası kanal döşemeye uygun değil", "sinir disi")
	r = g.can_place_canal(14, 0, "straight", 0, "earth")
	check(not r["ok"], "sutun siniri 14")
	check(g.can_place_canal(0, 4, "straight", 0, "earth")["ok"], "dogru kosullarda ok")
	check(g.place_canal(0, 4, "straight", 0, "earth"), "kurulur")
	r = g.can_place_canal(0, 4, "straight", 0, "earth")
	check(not r["ok"] and r["reason_tr"] == "Bu hücre dolu", "hucre dolu")
	g.state.money = 5.0
	r = g.can_place_canal(1, 4, "straight", 0, "earth")
	check(not r["ok"] and r["reason_tr"] == "Paran yetmiyor", "para yetmiyor")
	check(not g.place_canal(1, 4, "straight", 0, "earth") and g.state.money == 5.0, "reddedilince para ayni")
	check(not g.can_place_canal(1, 4, "yok", 0, "earth")["ok"] and not g.can_place_canal(1, 4, "straight", 0, "yok")["ok"], "bilinmeyen parca/malzeme")
	g.free()


func test_canal_place_remove() -> void:
	var g: Node = _rich_game()
	var signals: Array[int] = [0]
	g.connect("structures_changed", func() -> void: signals[0] += 1)
	var before: float = g.state.money
	var cost0: int = g.canal_piece_cost("straight", "earth")
	check(cost0 == 30, "ilk duz kanal 30")
	check(g.place_canal(0, 4, "straight", 0, "earth") and near(g.state.money, before - 30.0), "yerlestirme parayi duser")
	check(g.canal.get_piece(0, 4)["piece"] == "straight", "agda parca var")
	var cost1: int = g.canal_piece_cost("straight", "earth")
	check(cost1 == 31, "ikinci parca 30*1,04 = 31")
	g.place_canal(1, 4, "straight", 0, "earth")
	# Sokme: iade, sokulduktan sonraki sayiyla fiyatin yarisi: floor(31 / 2) = 15 degil, 1 parca kalinca fiyat 31 -> 15
	var money: float = g.state.money
	var refund: int = g.remove_canal(1, 4)
	check(refund == 15 and near(g.state.money, money + 15.0), "iade yariya (%d)" % refund)
	check(g.canal.get_piece(1, 4).is_empty(), "hucre bosaldi")
	check(g.remove_canal(1, 4) == 0, "bos hucre 0")
	check(g.rotate_canal(0, 4) and int(g.canal.get_piece(0, 4)["rotation"]) == 1, "dondurme")
	check(not g.rotate_canal(5, 5), "bos hucre dondurulmez")
	check(not g.toggle_gate(0, 4), "savak olmayan parca")
	check(signals[0] == 4, "structures_changed: kur, kur, sok, dondur (%d)" % signals[0])
	g.state.hammer_owned = false
	check(g.remove_canal(0, 4) == 0 and not g.rotate_canal(0, 4) and not g.canal.get_piece(0, 4).is_empty(), "cekicsiz sokme ve dondurme yok")
	g.free()


func test_canal_delivery_tick() -> void:
	var g: Node = _rich_game()
	check(g.canal_result()["delivered"] == 0.0, "bos agda teslimat 0")
	check(g.open_spring("A"), "pinar A acilir")
	for col: int in Pieces.DEFAULT_COLS:
		check(g.place_canal(col, 4, "straight", 0, "earth"), "duz kanal %d" % col)
	var res: Dictionary = g.canal_result()
	var expected: float = 80.0 * pow(1.0 - 0.05, 14)
	check(near(float(res["delivered"]), expected, 1e-6), "14 parcalik toprak hat: 80 * 0,95^14 (%f)" % float(res["delivered"]))
	check(is_same(res, g.canal_result()), "sonuc onbellekten gelir")
	var drops_before: float = g.state.total_drops
	g._process(2.0)
	check(near(g.state.total_drops - drops_before, expected * 2.0, 1e-6), "tick teslimati gole ekler (kayip uygulanmaz)")
	var money_before: float = g.state.money
	g._process(1.0)
	check(near(g.state.money - money_before, expected / 5.0, 1e-6), "teslim edilen damla paraya cevrilir")
	# Hat kesilince teslimat durur ve onbellek yenilenir
	g.remove_canal(7, 4)
	check(g.canal_result()["delivered"] == 0.0, "hat kesilince teslimat 0")
	g.free()


func test_canal_unlocks() -> void:
	var g: Node = _game(1.0e9)
	check(not g.unlock_piece("elbow") and not g.unlock_material("wood"), "kanal kilitliyken parca/malzeme kilidi acilmaz")
	g.state.canal_unlocked = true
	check(g.state.unlocked_pieces == ["straight"] and g.state.unlocked_materials == ["earth"], "yalniz duz kanal ve toprak baslangicta acik")
	var piece_costs: Dictionary = {"elbow": 50, "tee": 150, "wye": 400, "cross": 600, "gate": 900, "mill": 2500, "aqueduct": 3000, "reservoir": 6000}
	for id: String in piece_costs:
		check(Economy.cost_piece_unlock(g.state, id) == float(piece_costs[id]), "parca kilidi %s" % id)
		var before: float = g.state.money
		check(g.unlock_piece(id) and near(g.state.money, before - float(piece_costs[id])), "parca kilidi acilir %s" % id)
		check(not g.unlock_piece(id), "ikinci kez acilmaz %s" % id)
	check(not g.unlock_piece("straight") and not g.unlock_piece("yok") and not g.unlock_material("earth") and not g.unlock_material("yok"), "acik/bilinmeyen kilit acilmaz")
	check(g.unlock_material("wood") and g.unlock_material("stone") and g.state.unlocked_materials.size() == 3, "malzeme kilitleri")
	check(Economy.cost_material_unlock(GameState.new(), "wood") == 2500.0 and Economy.cost_material_unlock(GameState.new(), "stone") == 30000.0, "malzeme kilit maliyetleri")
	# Kilit acilinca parca kurulabilir
	g.state.hammer_owned = true
	check(g.place_canal(2, 2, "elbow", 1, "wood"), "acilan parca ve malzeme kurulur")
	# Savak: acik/kapat
	check(g.place_canal(3, 2, "gate", 0, "stone") and g.toggle_gate(3, 2) and not bool(g.canal.get_piece(3, 2)["open"]), "savak kapanir")
	# Gorunurluk
	var s: GameState = GameState.new()
	check(not Economy.piece_row_visible(s, "straight") and not Economy.material_row_visible(s, "earth"), "acik parca/malzeme satiri yok")
	check(not Economy.piece_row_visible(s, "elbow"), "dirsek kilidi gorunmez")
	s.total_money_earned = 25.0
	check(Economy.piece_row_visible(s, "elbow") and not Economy.piece_row_visible(s, "tee"), "dirsek 25 paraya gorunur")
	s.total_money_earned = 1250.0
	check(Economy.material_row_visible(s, "wood") and not Economy.material_row_visible(s, "stone"), "ahsap 1250 paraya gorunur")
	g.free()


# ---------- Kayit ----------

func _built_state() -> GameState:
	var s: GameState = GameState.new()
	s.money = 12345.0
	s.total_money_earned = 12345.0
	s.hammer_unlocked = true
	s.hammer_owned = true
	s.canal_unlocked = true
	s.unlocked_pieces = ["straight", "elbow", "gate"]
	s.unlocked_materials = ["earth", "stone"]
	s.unlocked_sources = ["crack", "spring"]
	s.unlocked_structures = ["reeds"]
	Build.add(s, "crack", 1.5, -2.5, 0.25)
	Build.add(s, "crack", 10.0, 20.0, 3.0)
	Build.add(s, "reeds", -4.0, 8.0, 1.0)
	Build.add(s, "spring", 0.0, 0.0, 0.0, false)
	return s


func test_save_roundtrip() -> void:
	var s: GameState = _built_state()
	var d: Dictionary = SaveCodec.to_dict(s)
	check(d["version"] == 3 and d["structures"].size() == 4, "surum ve yapilar yazilir")
	check(not d.has("sources"), "state.sources artik yazilmaz")
	var r: GameState = SaveCodec.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(SaveCodec.to_dict(r) == d, "JSON gidis donus birebir")
	check(r.hammer_owned and r.hammer_unlocked and r.unlocked_pieces == ["straight", "elbow", "gate"], "cekic ve parca kilitleri")
	check(r.unlocked_materials == ["earth", "stone"] and r.unlocked_structures == ["reeds"], "malzeme ve yapi kilitleri")
	check(Build.count(r, "crack") == 2 and Build.count(r, "reeds") == 1 and Build.count(r, "spring") == 1, "sayimlar yapilardan kurulur")
	check(not bool(r.structures[3]["placed"]) and bool(r.structures[0]["placed"]), "placed bayragi korunur")
	check(near(float(r.structures[0]["x"]), 1.5) and near(float(r.structures[0]["z"]), -2.5) and near(float(r.structures[0]["rot"]), 0.25), "konumlar korunur")
	# Yeni oyunda varsayilan kilitler
	var fresh: GameState = SaveCodec.from_dict({})
	check(fresh.unlocked_pieces == ["straight"] and fresh.unlocked_materials == ["earth"] and not fresh.hammer_owned, "yeni oyun varsayilanlari")
	# Cekic sahipligi kilit gerektirir
	var odd: GameState = SaveCodec.from_dict({"version": 3, "hammer_owned": true, "hammer_unlocked": false})
	check(odd.hammer_owned and odd.hammer_unlocked, "alinmis cekic kilitsiz olamaz")
	# Elde olan yapinin kilidi acik sayilir
	var partial: GameState = SaveCodec.from_dict({"version": 3, "structures": [{"kind": "dew", "x": 1.0, "z": 2.0, "rot": 0.0}, {"kind": "shade_tree", "x": 1.0, "z": 2.0, "rot": 0.0}]})
	check(partial.unlocked_sources.has("dew") and partial.unlocked_structures.has("shade_tree"), "kurulu yapinin kilidi acik sayilir")


func test_save_migration() -> void:
	# Surum 1: sources adetleri korunur, kamis/agac yok
	var v1: Dictionary = {"version": 1, "money": 500.0, "sources": {"crack": 3, "dew": 1, "rain_cloud": 2}, "loss_upgrades": ["rock_bed"]}
	var r1: GameState = SaveCodec.from_dict(v1)
	check(r1.structures.size() == 6 and Build.count(r1, "crack") == 3 and Build.count(r1, "rain_cloud") == 2, "v1: kaynak adetleri yapilara doner")
	check(not bool(r1.structures[0]["placed"]) and not bool(r1.structures[5]["placed"]), "v1: yapilar konumsuz")
	check(Economy.source_count(r1, "crack") == 3 and near(Economy.passive_rate_gross(r1), 0.5 * 3 + 3.0 + 20.0 * 2), "v1: uretim kaybolmaz")
	check(r1.unlocked_sources.has("crack") and r1.unlocked_sources.has("rain_cloud"), "v1: sahip olunan kaynak kilidi acik")
	check(r1.loss_upgrades == ["rock_bed"] and not r1.hammer_owned, "v1: diger alanlar, cekic yok")
	# Surum 2: kamis kenari ve golge agaclari -> 7'ser konumsuz yapi
	var v2: Dictionary = {"version": 2, "money": 9.0, "sources": {"crack": 1}, "loss_upgrades": ["rock_bed", "reed_edge", "shade_trees", "clay_floor"], "unlocked_sources": ["crack"]}
	var r2: GameState = SaveCodec.from_dict(v2)
	check(Build.count(r2, "reeds") == 7 and Build.count(r2, "shade_tree") == 7 and Build.count(r2, "crack") == 1, "v2: 7 kamis + 7 agac + 1 catlak")
	check(r2.structures.size() == 15, "v2: toplam 15 yapi")
	var all_unplaced: bool = true
	for item: Dictionary in r2.structures:
		if bool(item["placed"]):
			all_unplaced = false
	check(all_unplaced, "v2: hepsi konumsuz")
	check(r2.loss_upgrades == ["rock_bed", "clay_floor"], "v2: eski kamis/agac yukseltmeleri listeden duser")
	check(r2.unlocked_structures.has("reeds") and r2.unlocked_structures.has("shade_tree"), "v2: kamis/agac kilidi acik")
	check(near(Economy.loss_fraction(r2), 0.03), "v2: kayip eskisi gibi %3 (7+7 etkisi korunur)")
	# Yalniz kamis kenari alinmissa
	var v2b: GameState = SaveCodec.from_dict({"version": 2, "loss_upgrades": ["reed_edge"]})
	check(Build.count(v2b, "reeds") == 7 and Build.count(v2b, "shade_tree") == 0 and near(Economy.loss_fraction(v2b), 0.23), "v2: yalniz kamis")
	# Surumsuz kayit en eski bicim sayilir; goc sonrasi tekrar kaydedince v3, ikinci yukleme kayipsiz
	var again: GameState = SaveCodec.from_dict(JSON.parse_string(JSON.stringify(SaveCodec.to_dict(r2))))
	check(again.structures.size() == 15 and Build.count(again, "reeds") == 7 and SaveCodec.to_dict(again) == SaveCodec.to_dict(r2), "goc sonrasi kayit gidis donus")
	var noversion: GameState = SaveCodec.from_dict({"sources": {"dew": 2}})
	check(Build.count(noversion, "dew") == 2, "surumsuz kayit da goce girer")
	# v3 kaydinda eski "sources" alani yok sayilir (cift sayim olmaz)
	var v3: GameState = SaveCodec.from_dict({"version": 3, "sources": {"crack": 5}})
	check(v3.structures.is_empty(), "v3: sources yok sayilir")


func test_save_corrupt_structures() -> void:
	var bad: Dictionary = {"version": 3, "structures": [
		{"kind": "yok", "x": 1.0, "z": 1.0, "rot": 0.0},
		{"kind": "crack", "x": "bir", "z": 1.0, "rot": 0.0},
		{"kind": "crack", "x": 1.0, "z": INF, "rot": 0.0},
		{"kind": "crack", "x": NAN, "z": 1.0, "rot": 0.0},
		{"kind": "crack", "x": 1.0e30, "z": 1.0, "rot": 0.0},
		{"kind": 5, "x": 1.0, "z": 1.0, "rot": 0.0},
		{"x": 1.0, "z": 1.0},
		"metin", 7, null, [1, 2],
		{"kind": "crack", "x": 2.0, "z": 3.0, "rot": "bozuk"},
		{"kind": "dew", "x": 4.0, "z": 5.0, "rot": 1.5, "placed": true},
		{"kind": "reeds", "placed": false},
	]}
	var r: GameState = SaveCodec.from_dict(bad)
	check(r.structures.size() == 3, "yalniz gecerli yapilar kalir (%d)" % r.structures.size())
	check(r.structures[0]["kind"] == "crack" and near(float(r.structures[0]["rot"]), 0.0) and r.structures[0]["x"] == 2.0, "bozuk donus 0a iner")
	check(r.structures[1]["kind"] == "dew" and bool(r.structures[1]["placed"]), "gecerli yapi")
	check(not bool(r.structures[2]["placed"]) and Build.count(r, "reeds") == 1, "konumsuz yapi koordinatsiz kabul")
	check(r.counts == {"crack": 1, "dew": 1, "reeds": 1}, "sayimlar gecerli yapilardan")
	check(SaveCodec.from_dict({"version": 3, "structures": "bozuk"}).structures.is_empty(), "liste olmayan structures")
	check(SaveCodec.from_dict({"version": 3, "structures": 5}).structures.is_empty(), "sayi structures")
	# En fazla 2000 yapi
	var many: Array = []
	for i: int in 2500:
		many.append({"kind": "crack", "x": float(i), "z": 0.0, "rot": 0.0})
	var capped: GameState = SaveCodec.from_dict({"version": 3, "structures": many})
	check(capped.structures.size() == 2000 and Build.count(capped, "crack") == 2000, "en fazla 2000 yapi")
	var capped_migrate: GameState = SaveCodec.from_dict({"version": 2, "sources": {"crack": 5000}})
	check(capped_migrate.structures.size() == 2000, "goc de 2000 ile sinirli")
	# Bozuk kilit listeleri
	var locks: GameState = SaveCodec.from_dict({"version": 3, "unlocked_pieces": ["elbow", "yok", 5, "elbow"], "unlocked_materials": "x", "unlocked_structures": ["reeds", "crack", "yok"]})
	check(locks.unlocked_pieces == ["straight", "elbow"] and locks.unlocked_materials == ["earth"], "bozuk parca/malzeme kilitleri")
	check(locks.unlocked_structures == ["reeds"], "kaynak kimligi yapi kilidine girmez")
	# Bozuk cekic alani
	var hb: GameState = SaveCodec.from_dict({"version": 3, "hammer_owned": "evet", "hammer_unlocked": 1})
	check(not hb.hammer_owned and not hb.hammer_unlocked, "cekic alani yalniz bool")


func test_legacy_canal_save() -> void:
	var g: Node = _rich_game()
	var old_grid: Dictionary = {"cells": [0, 1, 2, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		"open_springs": ["A", "B"], "width_level": 2, "lining_level": 1}
	g.canal.from_dict(old_grid)
	check(g.canal.piece_count() == 0 and g.canal.open_springs.is_empty() and g.canal.width_level == 0, "eski izgara kaydi bos aga doner")
	check(g.canal_result()["delivered"] == 0.0, "bos agla akis hesabi cokmez")
	g.canal.from_dict("bozuk")
	g.canal.from_dict(null)
	g.canal.from_dict({"cols": 14, "rows": 10, "cells": "x"})
	check(g.canal.piece_count() == 0, "bozuk kanal kayitlari cokertmez")
	# Yeni biçim gidis donus
	g.place_canal(0, 4, "straight", 0, "earth")
	g.place_canal(1, 4, "straight", 1, "earth")
	var back: Variant = JSON.parse_string(JSON.stringify(g.canal.to_dict()))
	var h: Node = _game()
	h.canal.from_dict(back)
	check(h.canal.piece_count() == 2 and int(h.canal.get_piece(1, 4)["rotation"]) == 1, "ag JSON gidis donus")
	h.free()
	g.free()
