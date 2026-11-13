extends SceneTree

const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const SaveCodec = preload("res://scripts/core/save_codec.gd")
const Build = preload("res://scripts/core/build.gd")

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	test_tools()
	test_fill_pour()
	test_rate()
	test_source_costs()
	test_loss()
	test_tick()
	test_stages()
	test_lake_fill()
	test_buy_fail()
	test_visibility()
	test_offline()
	test_save_roundtrip()
	test_save_corrupt()
	test_tool_unlock()
	test_tool_upgrade()
	test_source_unlock()
	test_canal_unlock()
	test_new_visibility()
	test_save_new_fields()
	test_save_v1_migration()
	test_save_new_corrupt()
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func near(a: float, b: float, eps: float = 1e-6) -> bool:
	return absf(a - b) <= eps


func _state() -> GameState:
	return GameState.new()


## Tum alet, kaynak ve yapi kilitleri acik, cekic elde (satin alma ve kurma testleri icin).
func _unlocked_state() -> GameState:
	var s: GameState = GameState.new()
	s.tool_unlocked = Cfg.TOOLS.size() - 1
	for def: Dictionary in Cfg.SOURCES:
		s.unlocked_sources.append(def["id"])
	s.unlocked_structures.append("reeds")
	s.unlocked_structures.append("shade_tree")
	s.hammer_unlocked = true
	s.hammer_owned = true
	return s


## Konumlu yapi kurar (parali); durumdaki cekic ve kilitler uygunsa true.
func _place(s: GameState, kind: String) -> bool:
	return Build.place(s, kind, 3.0, -2.0, 0.5)


## Odemesiz n yapi ekler (durumu kurmak icin).
func _give(s: GameState, kind: String, n: int) -> void:
	for i: int in n:
		Build.add(s, kind, float(i), 0.0, 0.0)


func _snapshot(s: GameState) -> Dictionary:
	return SaveCodec.to_dict(s)


func test_tools() -> void:
	var s: GameState = _unlocked_state()
	var caps: Array[float] = [5.0, 12.0, 30.0, 120.0, 300.0]
	check(Economy.tool_capacity(s) == 5.0, "baslangic Avuc 5")
	check(Economy.cost_tool(s) == 10.0, "Tas maliyeti 10")
	for i: int in range(1, caps.size()):
		s.money = 1.0e9
		check(Economy.buy_tool(s), "alet %d alinir" % i)
		check(Economy.tool_capacity(s) == caps[i], "alet %d kapasitesi" % i)
	check(not Economy.buy_tool(s), "son aletten sonra alim yok")
	check(Economy.cost_tool(s) < 0.0, "son aletten sonra maliyet -1")
	# Sirali alim: Kova'yi atlayamaz; para yetse de siradaki Tas
	var t: GameState = _unlocked_state()
	t.money = 70.0
	check(Economy.buy_tool(t) and t.tool_level == 1, "once Tas")
	check(Economy.buy_tool(t) and t.tool_level == 2, "sonra Kova")
	check(near(t.money, 0.0), "para duser")


func test_fill_pour() -> void:
	var s: GameState = _state()
	var added: float = Economy.fill(s, 0.3)
	check(near(added, 1.0), "0.3 sn Avuc: 1 damla (%f)" % added)
	Economy.fill(s, 100.0)
	check(s.carried == 5.0, "fill kapasiteyi asmaz")
	check(Economy.fill(s, 1.0) == 0.0, "dolu iken fill 0")
	check(Economy.fill(s, -1.0) == 0.0, "negatif delta 0")
	var money: float = Economy.pour(s)
	check(near(money, 1.0), "5 damla 5:1 = 1 para")
	check(s.carried == 0.0 and s.total_drops == 5.0, "pour sonrasi durum")
	check(near(s.money, 1.0) and near(s.total_money_earned, 1.0), "para eklendi")
	check(Economy.pour(s) == 0.0, "bos pour 0")
	var t: GameState = _state()
	t.tool_level = 4
	Economy.fill(t, 1.5)
	check(near(t.carried, 300.0), "Sirik 1.5 sn'de dolar")


func test_rate() -> void:
	var s: GameState = _state()
	check(Economy.cost_rate(s) == 100.0, "oran 1 maliyeti 100")
	check(not Economy.buy_rate(s), "para yok: oran alinmaz")
	s.money = 100.0
	check(Economy.buy_rate(s) and s.rate_level == 1 and s.money == 0.0, "oran 4:1 alindi")
	s.carried = 8.0
	check(near(Economy.pour(s), 2.0), "8 damla 4:1 = 2 para")
	var expected: Array[float] = [100.0, 5000.0, 80000.0, 700000.0]
	var t: GameState = _state()
	for c: float in expected:
		check(Economy.cost_rate(t) == c, "oran maliyeti %f" % c)
		t.money = c
		Economy.buy_rate(t)
	check(Economy.drops_per_money(t) == 1.0, "son oran 1:1")
	check(Economy.cost_rate(t) < 0.0, "oran bitti")


func test_source_costs() -> void:
	var s: GameState = _unlocked_state()
	var crack: Array[float] = [15.0, 19.0, 25.0, 32.0]
	var dew: Array[float] = [100.0, 130.0, 169.0, 219.0]
	for i: int in 3:
		check(Economy.cost_source(s, "crack") == crack[i], "catlak maliyeti adet %d" % i)
		s.money = 1.0e6
		check(_place(s, "crack"), "catlak kurulur")
	check(Economy.cost_source(s, "crack") == crack[3], "catlak 4. maliyet")
	var t: GameState = _unlocked_state()
	for i: int in 3:
		check(Economy.cost_source(t, "dew") == dew[i], "cig maliyeti adet %d" % i)
		t.money = 1.0e6
		_place(t, "dew")
	check(Economy.cost_source(t, "yok") < 0.0, "bilinmeyen kaynak -1")
	check(not _place(t, "yok"), "bilinmeyen kaynak kurulmaz")
	check(Economy.source_count(s, "crack") == 3, "adet 3")


func test_loss() -> void:
	var s: GameState = _state()
	check(near(Economy.loss_fraction(s), 0.30), "taban kayip 30")
	for def: Dictionary in Cfg.LOSS_UPGRADES:
		s.money = 1.0e9
		check(Economy.buy_loss(s, def["id"]), "kayip yukseltmesi %s" % def["id"])
		check(not Economy.buy_loss(s, def["id"]), "ikinci kez alinmaz")
	check(near(Economy.loss_fraction(s), 0.17), "tek seferlik yukseltmelerle kayip 17")
	var u: GameState = _unlocked_state()
	_give(u, "reeds", 7)
	_give(u, "shade_tree", 7)
	check(near(Economy.loss_fraction(u), 0.16), "7 kamis + 7 agac: kayip 16")
	_give(s, "reeds", 7)
	_give(s, "shade_tree", 7)
	check(near(Economy.loss_fraction(s), 0.03), "tum kalemlerle kayip 3")
	_give(s, "reeds", 5)
	_give(s, "shade_tree", 5)
	check(near(Economy.loss_fraction(s), 0.03), "7 den fazlasi kaybi azaltmaz")
	var t: GameState = _state()
	t.money = 200.0
	Economy.buy_loss(t, "rock_bed")
	check(near(Economy.loss_fraction(t), 0.22), "Kaya yatagi sonrasi 22")


func test_tick() -> void:
	var s: GameState = _state()
	_give(s, "crack", 1)
	check(near(Economy.passive_rate_net(s), 0.35), "catlak net 0.35/sn")
	var added: float = Economy.tick(s, 10.0, 0.0)
	check(near(added, 3.5) and near(s.total_drops, 3.5), "10 sn: 3.5 damla")
	check(near(s.money, 0.7), "3.5 damla 5:1 = 0.7 para")
	var t: GameState = _state()
	var d: float = Economy.tick(t, 10.0, 2.0)
	check(near(d, 20.0), "yalniz kanal: kayipsiz 20 damla")
	var u: GameState = _state()
	_give(u, "crack", 1)
	Economy.tick(u, 10.0, 2.0)
	check(near(u.total_drops, 23.5), "pasif 3.5 + kanal 20")
	var big: GameState = _state()
	_give(big, "dew", 2)
	Economy.tick(big, 1.0e6, 0.0)
	check(near(big.total_drops, 6.0 * 0.7 * 1.0e6, 1.0), "buyuk delta dogru")
	check(Economy.tick(big, 0.0, 5.0) == 0.0, "delta 0")
	check(Economy.tick(big, 1.0, NAN) >= 0.0, "NaN kanal cokmez")


func _at(drops: float) -> GameState:
	var s: GameState = _state()
	s.total_drops = drops
	return s


func test_stages() -> void:
	var pairs: Array = [[0.0, 0], [49.0, 0], [50.0, 1], [3999.0, 1], [4000.0, 2], [349999.0, 2], [350000.0, 3], [3499999.0, 3], [3500000.0, 4], [2.0e7, 4]]
	for p: Array in pairs:
		check(Economy.stage_index(_at(p[0])) == p[1], "asama %f -> %d" % [p[0], p[1]])
	check(Economy.stage_progress(_at(0.0)) == 0.0, "ilerleme 0")
	var mid: float = Economy.stage_progress(_at(7.0))
	check(mid > 0.0 and mid < 1.0, "asama ici ilerleme ara deger")
	check(near(Economy.stage_progress(_at(50.0)), 0.0), "esikte ilerleme 0")
	check(Economy.stage_progress(_at(1.0e9)) == 1.0, "son asama ilerleme 1")
	check(not Economy.is_finished(_at(Cfg.GAME_END_DROPS - 1.0)), "oyun bitmedi")
	check(Economy.is_finished(_at(Cfg.GAME_END_DROPS)), "oyun bitti")
	check(Economy.fish_count(_at(4000.0)) == 2 and Economy.fish_count(_at(1.0e7)) == 9, "balik")
	check(Economy.bird_count(_at(3999.0)) == 0 and Economy.bird_count(_at(350000.0)) == 3 and Economy.bird_count(_at(1.0e7)) == 6, "kus")
	check(not Economy.reeds_visible(_at(3999.0)) and Economy.reeds_visible(_at(4000.0)), "kamis")


func test_lake_fill() -> void:
	var prev: float = -1.0
	var ok: bool = true
	var d: float = 0.0
	while d < 2.0e7:
		var f: float = Economy.lake_fill(_at(d))
		if f < prev or f < 0.0 or f > 1.0:
			ok = false
		prev = f
		d = d * 1.05 + 0.5
	check(ok, "lake_fill tekduze ve 0..1")
	check(Economy.lake_fill(_at(0.0)) == 0.0, "bos gol 0")
	check(Economy.lake_fill(_at(3500000.0)) == 1.0, "son esikte 1")
	check(Economy.lake_fill(_at(2.0e7)) == 1.0, "ote 1")
	for th: float in [50.0, 4000.0, 350000.0, 3500000.0]:
		var a: float = Economy.lake_fill(_at(th - 0.01))
		var b: float = Economy.lake_fill(_at(th))
		check(b >= a and b - a < 1e-3, "esikte surekli %f" % th)


func test_buy_fail() -> void:
	var s: GameState = _state()
	s.money = 5.0
	var before: Dictionary = _snapshot(s)
	check(not Economy.buy_tool(s), "tool yetmez")
	check(not Economy.buy_rate(s), "rate yetmez")
	check(not _place(s, "crack"), "kaynak yetmez")
	check(not Economy.buy_loss(s, "rock_bed"), "kayip yetmez")
	check(_snapshot(s) == before, "basarisiz alimda durum ayni")


func test_visibility() -> void:
	var s: GameState = _state()
	check(not Economy.source_visible(s, "crack"), "baslangicta catlak gizli")
	s.total_money_earned = 7.0
	check(not Economy.source_visible(s, "crack"), "7 < 7.5 gizli")
	s.total_money_earned = 7.5
	check(Economy.source_visible(s, "crack"), "7.5 gorunur")
	check(not Economy.tool_visible(_state()), "Tas gizli")
	var t: GameState = _state()
	t.total_money_earned = 6.0
	check(Economy.tool_visible(t), "Tas 6'da gorunur")
	t.money = 1.0e6
	Economy.buy_loss(t, "rock_bed")
	check(not Economy.loss_visible(t, "rock_bed"), "alinan gizlenir")


func test_offline() -> void:
	var s: GameState = _state()
	_give(s, "crack", 1)
	s.last_seen_unix = 1000
	check(Economy.apply_offline(s, 1029) == 0.0, "29 sn 0")
	check(s.last_seen_unix == 1000, "kisa surede last_seen ayni")
	check(near(Economy.apply_offline(s, 1600), 210.0), "10 dk = 210 damla")
	check(s.last_seen_unix == 1600, "last_seen guncel")
	var t: GameState = _state()
	_give(t, "crack", 1)
	t.last_seen_unix = 1000
	check(near(Economy.apply_offline(t, 1000 + 5 * 3600), 315.0), "5 saat 900 sn ile sinirli")
	var u: GameState = _state()
	_give(u, "crack", 1)
	u.last_seen_unix = 1000
	check(near(Economy.apply_offline(u, 1000 + 5 * 3600, 1.0), 315.0 + 900.0), "kanal teslimati eklenir")
	var v: GameState = _state()
	_give(v, "crack", 1)
	v.last_seen_unix = 5000
	check(Economy.apply_offline(v, 4000) == 0.0, "negatif sure 0")
	check(v.total_drops == 0.0, "negatif sure damla eklemez")


func _rich_state() -> GameState:
	var s: GameState = _state()
	s.money = 1234.5
	s.total_money_earned = 5000.25
	s.total_drops = 31337.0
	s.tool_level = 3
	s.rate_level = 2
	s.carried = 77.5
	_give(s, "crack", 4)
	_give(s, "dew", 2)
	Build.add(s, "reeds", 12.5, -7.25, 1.5)
	Build.add(s, "spring", 0.0, 0.0, 0.0, false)
	s.hammer_unlocked = true
	s.hammer_owned = true
	s.unlocked_structures = ["reeds"]
	s.unlocked_pieces = ["straight", "elbow"]
	s.unlocked_materials = ["earth", "wood"]
	s.tool_unlocked = 3
	s.tool_upgrades = {"cup": 2, "palm": 1}
	s.unlocked_sources = ["crack", "dew", "spring"]
	s.canal_unlocked = true
	s.loss_upgrades = ["rock_bed", "clay_floor"]
	s.last_seen_unix = 1700000000
	return s


func test_save_roundtrip() -> void:
	var s: GameState = _rich_state()
	var d: Dictionary = SaveCodec.to_dict(s)
	check(d["version"] == Cfg.SAVE_VERSION, "surum alani")
	check(SaveCodec.to_dict(SaveCodec.from_dict(d)) == d, "gidis donus ayni")
	var json_back: Variant = JSON.parse_string(JSON.stringify(d))
	var r: GameState = SaveCodec.from_dict(json_back)
	check(SaveCodec.to_dict(r) == d or (r.tool_level == 3 and r.rate_level == 2 and Build.count(r, "crack") == 4), "JSON gidis donus")
	check(r.loss_upgrades == s.loss_upgrades and near(r.money, 1234.5), "JSON alanlari")


func test_save_corrupt() -> void:
	var fresh: Dictionary = SaveCodec.to_dict(_state())
	check(SaveCodec.to_dict(SaveCodec.from_dict({})) == fresh, "bos sozluk yeni oyun")
	check(SaveCodec.to_dict(SaveCodec.from_dict("bozuk")) == fresh, "string girdi yeni oyun")
	check(SaveCodec.to_dict(SaveCodec.from_dict(null)) == fresh, "null girdi yeni oyun")
	check(SaveCodec.to_dict(SaveCodec.from_dict([1, 2])) == fresh, "dizi girdi yeni oyun")
	var bad: Dictionary = {
		"money": "cok", "total_drops": NAN, "carried": INF, "tool_level": 99,
		"rate_level": -1, "sources": {"crack": -3, "yok": 5, "dew": NAN, 7: 2}, "loss_upgrades": ["yok", 5, "rock_bed", "rock_bed"],
		"last_seen_unix": "dun", "total_money_earned": -5.0,
	}
	var r: GameState = SaveCodec.from_dict(bad)
	check(r.money == 0.0 and r.total_drops == 0.0 and r.carried == 0.0, "yanlis tur/NaN/inf varsayilan")
	check(r.tool_level == 0 and r.rate_level == 0, "seviye sinirlari")
	check(r.structures.is_empty() and r.counts.is_empty(), "bozuk kaynaklar atildi")
	check(r.loss_upgrades.size() == 1 and r.loss_upgrades[0] == "rock_bed", "bilinmeyen id atildi, tekrar yok")
	check(r.total_money_earned >= 0.0 and r.last_seen_unix == 0, "negatif/yanlis tur")
	var partial: GameState = SaveCodec.from_dict({"money": 50.0, "tool_level": 2.5, "carried": 1.0e9, "tool_level_x": 1})
	check(near(partial.money, 50.0) and partial.tool_level == 0, "kismi kayit: gecerli alan korunur, kesirli seviye 0")
	check(partial.carried <= Economy.tool_capacity(partial), "carried kapasiteye kirpilir")
	check(SaveCodec.from_dict({"version": "x", "money": 5.0}).money == 0.0, "bozuk surum yeni oyun")
	check(SaveCodec.from_dict({"version": 99, "money": 5.0}).money == 0.0, "gelecek surum yeni oyun")
	check(SaveCodec.from_dict({"money": 1.0e30}).money == 0.0, "asiri buyuk sayi atilir")


func test_tool_unlock() -> void:
	var s: GameState = _state()
	check(Economy.is_tool_unlocked(s, 0) and not Economy.is_tool_unlocked(s, 1), "yalniz Avuc acik baslar")
	check(Economy.cost_tool_unlock(s) == 6.0, "Tas kilidi 6")
	s.money = 1.0e9
	check(not Economy.buy_tool(s) and s.tool_level == 0 and s.money == 1.0e9, "kilitsiz alet dukkanda alinamaz, para ayni")
	check(not Economy.next_tool_unlocked(s), "siradaki kilitli")
	var costs: Array[float] = [6.0, 40.0, 700.0, 8000.0]
	for c: float in costs:
		check(Economy.cost_tool_unlock(s) == c, "kilit maliyeti %f" % c)
		var before: float = s.money
		check(Economy.unlock_tool(s) and near(s.money, before - c), "kilit acilir, para duser %f" % c)
	check(Economy.cost_tool_unlock(s) < 0.0 and not Economy.unlock_tool(s), "son kilitten sonra yok")
	check(s.tool_unlocked == 4 and s.tool_level == 0, "kilit acmak aleti vermez")
	check(Economy.buy_tool(s) and s.tool_level == 1, "kilit acikken dukkandan alinir")
	# Kilitler sirayla acilir
	var t: GameState = _state()
	t.money = 5.0
	check(not Economy.unlock_tool(t) and t.tool_unlocked == 0, "para yetmez")
	t.money = 6.0
	check(Economy.unlock_tool(t) and t.tool_unlocked == 1 and Economy.cost_tool_unlock(t) == 40.0, "siradaki Kova kilidi 40")
	# Siradaki alet kilitliyse para yetse de alinmaz
	var u: GameState = _state()
	u.money = 1.0e9
	Economy.unlock_tool(u)
	check(Economy.buy_tool(u) and u.tool_level == 1, "Tas alinir")
	check(not Economy.next_tool_unlocked(u) and not Economy.buy_tool(u) and u.tool_level == 1, "Kova kilitliyken alinmaz")


func test_tool_upgrade() -> void:
	var s: GameState = _state()
	s.money = 1.0e9
	check(Economy.cost_tool_upgrade(s, 1) < 0.0 and not Economy.upgrade_tool(s, 1), "sahip olunmayan alet yukseltilemez")
	check(Economy.cost_tool_upgrade(s, 0) == 5.0, "Avuc yukseltme 5")
	var palm_costs: Array[float] = [5.0, 9.0, 16.0, 29.0, 52.0] # floor(5 * 1.8^n)
	var palm_caps: Array[float] = [6.0, 7.0, 8.0, 9.0, 10.0]
	for n: int in 5:
		check(Economy.cost_tool_upgrade(s, 0) == palm_costs[n], "Avuc seviye %d maliyeti" % n)
		check(Economy.upgrade_tool(s, 0), "Avuc yukselir %d" % n)
		check(near(Economy.tool_capacity(s), palm_caps[n]), "Avuc kapasite seviye %d" % (n + 1))
	check(Economy.cost_tool_upgrade(s, 0) < 0.0 and not Economy.upgrade_tool(s, 0), "5 seviye tavan")
	check(near(Economy.tool_capacity(s), 10.0), "5 seviyede 2 kat")
	check(Economy.tool_upgrade_level(s, 0) == 5, "seviye 5")
	var t: GameState = _unlocked_state()
	t.tool_level = 1
	t.money = 1.0e9
	check(Economy.cost_tool_upgrade(t, 1) == 8.0 and Economy.upgrade_tool(t, 1), "Tas yukseltme 8")
	check(near(Economy.tool_capacity(t), 14.4), "Tas 12 -> 14,4")
	check(Economy.cost_tool_upgrade(t, 1) == 14.0, "Tas seviye 1 maliyeti floor(8*1.8)")
	check(Economy.tool_upgrade_level(t, 0) == 0 and near(Economy.tool_capacity_at(t, 0), 5.0), "her aletin seviyesi ayri")
	check(Economy.cost_tool_upgrade(t, 2) < 0.0, "sahip olunmayan Kova yukseltilemez")
	var bases: Array[float] = [5.0, 8.0, 40.0, 600.0, 8000.0]
	for i: int in bases.size():
		check(Cfg.TOOLS[i]["upgrade_cost"] == bases[i], "taban yukseltme maliyeti %d" % i)
	t.carried = 0.0
	Economy.fill(t, 100.0)
	check(near(t.carried, 14.4), "dolum yukseltilmis kapasiteye kadar")
	var poor: GameState = _state()
	poor.money = 4.0
	var before: Dictionary = _snapshot(poor)
	check(not Economy.upgrade_tool(poor, 0) and _snapshot(poor) == before, "para yetmezse durum ayni")


func test_source_unlock() -> void:
	var s: GameState = _state()
	s.money = 1.0e9
	s.hammer_owned = true
	check(not _place(s, "crack") and s.money == 1.0e9 and s.structures.is_empty(), "kilitsiz kaynak kurulamaz")
	check(Economy.cost_source_unlock(s, "crack") == 7.0, "catlak kilidi floor(15/2)")
	check(Economy.cost_source_unlock(s, "dew") == 50.0, "cig kilidi 50")
	check(Economy.cost_source_unlock(s, "rain_cloud") == 3500.0 and Economy.cost_source_unlock(s, "stream_mouth") == 350000.0, "kilit maliyetleri")
	check(Economy.cost_source_unlock(s, "yok") < 0.0 and not Economy.unlock_source(s, "yok"), "bilinmeyen kaynak kilidi")
	check(Economy.unlock_source(s, "crack") and Economy.source_unlocked(s, "crack"), "kilit acilir")
	check(Economy.cost_source_unlock(s, "crack") < 0.0 and not Economy.unlock_source(s, "crack"), "ikinci kez acilmaz")
	check(_place(s, "crack") and Economy.source_count(s, "crack") == 1, "kilit acikken kurulur")
	check(Economy.cost_source(s, "crack") == 19.0, "adet maliyeti 1,3 carpanli")
	check(not _place(s, "dew"), "baska kaynagin kilidi ayri")
	var p: GameState = _state()
	p.money = 6.0
	check(not Economy.unlock_source(p, "crack") and p.money == 6.0, "para yetmez")


func test_canal_unlock() -> void:
	var s: GameState = _state()
	check(Economy.cost_canal_unlock(s) == 300.0, "kanal kilidi 300")
	check(not Economy.canal_section_visible(s), "kanal bolumu gizli")
	s.total_drops = 4999.0
	check(not Economy.canal_section_visible(s), "4999 damlada gizli")
	s.total_drops = 5000.0
	check(Economy.canal_section_visible(s), "5000 damlada gorunur")
	s.money = 299.0
	check(not Economy.unlock_canal(s) and not s.canal_unlocked, "para yetmez")
	s.money = 300.0
	check(Economy.unlock_canal(s) and s.canal_unlocked and s.money == 0.0, "kanal acilir")
	check(Economy.cost_canal_unlock(s) < 0.0 and not Economy.unlock_canal(s), "bir kez")
	var t: GameState = _state()
	t.canal_unlocked = true
	check(Economy.canal_section_visible(t), "acik kanal bolumu gorunur")
	check(Economy.spend(t, 0.0) and not Economy.spend(t, 1.0) and not Economy.spend(t, -1.0), "spend")


func test_new_visibility() -> void:
	var s: GameState = _state()
	check(not Economy.tool_row_visible(s, 0), "Avuc satiri baslangicta gizli")
	s.total_money_earned = 2.5
	check(Economy.tool_row_visible(s, 0), "Avuc yukseltmesi 2,5 paraya gorunur")
	check(not Economy.tool_row_visible(s, 1), "Tas kilidi 4 paraya gorunur")
	s.total_money_earned = 4.0
	check(Economy.tool_row_visible(s, 1) and not Economy.tool_row_visible(s, 2), "yalniz siradaki kilit")
	check(not Economy.tool_row_visible(s, 9) and not Economy.tool_row_visible(s, -1), "gecersiz indeks")
	s.tool_unlocked = 1
	check(Economy.tool_row_visible(s, 1), "kilidi acik alet satiri kalir")
	var t: GameState = _state()
	t.total_money_earned = 3.0
	check(not Economy.source_row_visible(t, "crack"), "catlak kilidi 3,5 paraya gorunur")
	t.total_money_earned = 3.5
	check(Economy.source_row_visible(t, "crack"), "catlak kilidi gorunur (7/2)")
	check(not Economy.source_row_visible(t, "yok"), "bilinmeyen kaynak satiri yok")
	t.unlocked_sources.append("dew")
	check(Economy.source_row_visible(t, "dew"), "kilidi acik kaynak satiri her zaman")
	check(not Economy.rate_row_visible(_state()), "oran satiri gizli")


func test_save_new_fields() -> void:
	var d: Dictionary = SaveCodec.to_dict(_rich_state())
	check(Cfg.SAVE_VERSION == 3 and d["version"] == 3, "surum 3")
	var json_back: Variant = JSON.parse_string(JSON.stringify(d))
	var r: GameState = SaveCodec.from_dict(json_back)
	check(r.tool_unlocked == 3 and r.canal_unlocked, "kilitler geri yuklenir")
	check(r.tool_upgrades.get("cup", 0) == 2 and r.tool_upgrades.get("palm", 0) == 1, "alet seviyeleri geri yuklenir")
	check(r.unlocked_sources.size() == 3 and r.unlocked_sources.has("spring"), "kaynak kilitleri geri yuklenir")
	check(SaveCodec.to_dict(r) == d, "yeni alanlar gidis donus")


func test_save_v1_migration() -> void:
	var old: Dictionary = {
		"version": 1, "money": 500.0, "total_money_earned": 900.0, "total_drops": 4000.0,
		"tool_level": 2, "rate_level": 1, "carried": 3.0,
		"sources": {"crack": 3, "dew": 1}, "loss_upgrades": ["rock_bed"], "last_seen_unix": 1700000000,
	}
	var r: GameState = SaveCodec.from_dict(old)
	check(near(r.money, 500.0) and near(r.total_drops, 4000.0) and r.tool_level == 2, "v1 kayit yeni oyun olmaz")
	check(r.tool_unlocked == 2 and Economy.is_tool_unlocked(r, 2) and not Economy.is_tool_unlocked(r, 3), "sahip olunan aletler acik sayilir")
	check(Economy.source_unlocked(r, "crack") and Economy.source_unlocked(r, "dew") and not Economy.source_unlocked(r, "spring"), "sahip olunan kaynaklar acik sayilir")
	check(not r.canal_unlocked and r.tool_upgrades.is_empty(), "yeni alanlar varsayilan")
	check(r.loss_upgrades == ["rock_bed"] and r.rate_level == 1, "eski alanlar korunur")
	r.hammer_owned = true
	check(Build.count(r, "crack") == 3 and Build.count(r, "dew") == 1, "eski kaynak adetleri korunur (yerlestirilmemis yapi)")
	check(r.structures.size() == 4 and not bool(r.structures[0]["placed"]), "goc yapilari konumsuz")
	check(Economy.cost_source(r, "crack") == 32.0 and _place(r, "crack") and Build.count(r, "crack") == 4, "gocten sonra yeni crack 4. adet fiyatiyla kurulur")
	var v0: GameState = SaveCodec.from_dict({"tool_level": 1, "money": 7.0})
	check(v0.tool_unlocked == 1 and near(v0.money, 7.0), "surumsuz kayit da gocer")
	check(SaveCodec.from_dict({"version": 4, "money": 5.0}).money == 0.0, "gelecek surum 4 yeni oyun")


func test_save_new_corrupt() -> void:
	var bad: Dictionary = {
		"version": 2, "tool_level": 1, "tool_unlocked": 99, "tool_upgrades": {"cup": 9, "bucket": 2, "yok": 1, "palm": 1.5, 7: 1, "cup2": "x"},
		"unlocked_sources": ["crack", "yok", 5, "crack"], "canal_unlocked": "evet",
	}
	var r: GameState = SaveCodec.from_dict(bad)
	check(r.tool_unlocked == 1, "sinir disi tool_unlocked tool_level e iner")
	check(r.tool_upgrades.is_empty(), "bozuk/sahip olunmayan/tavan ustu seviyeler atildi (%s)" % str(r.tool_upgrades))
	check(r.unlocked_sources == ["crack"], "bilinmeyen id ve tekrar atildi")
	check(not r.canal_unlocked, "canal_unlocked yalniz true kabul edilir")
	var t: GameState = SaveCodec.from_dict({"tool_level": 1, "tool_upgrades": {"cup": 3, "palm": 5}, "tool_unlocked": 0, "carried": 1.0e9})
	check(t.tool_upgrades.get("cup", 0) == 3 and t.tool_upgrades.get("palm", 0) == 5, "gecerli seviyeler korunur")
	check(t.tool_unlocked == 1, "tool_unlocked en az tool_level")
	check(near(t.carried, Economy.tool_capacity(t)) and near(t.carried, 19.2), "carried yukseltilmis kapasiteye kirpilir")
	check(SaveCodec.from_dict({"tool_upgrades": "bozuk", "unlocked_sources": 5, "tool_unlocked": "x"}).tool_unlocked == 0, "yanlis turler cokertmez")
	var neg: GameState = SaveCodec.from_dict({"tool_level": 1, "tool_upgrades": {"cup": -1}})
	check(neg.tool_upgrades.is_empty(), "negatif seviye atilir")
