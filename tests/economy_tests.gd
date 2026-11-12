extends SceneTree

const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const SaveCodec = preload("res://scripts/core/save_codec.gd")

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


func _snapshot(s: GameState) -> Dictionary:
	return SaveCodec.to_dict(s)


func test_tools() -> void:
	var s: GameState = _state()
	var caps: Array[float] = [5.0, 15.0, 50.0, 140.0, 400.0]
	check(Economy.tool_capacity(s) == 5.0, "baslangic Avuc 5")
	check(Economy.cost_tool(s) == 12.0, "Tas maliyeti 12")
	for i: int in range(1, caps.size()):
		s.money = 1.0e9
		check(Economy.buy_tool(s), "alet %d alinir" % i)
		check(Economy.tool_capacity(s) == caps[i], "alet %d kapasitesi" % i)
	check(not Economy.buy_tool(s), "son aletten sonra alim yok")
	check(Economy.cost_tool(s) < 0.0, "son aletten sonra maliyet -1")
	# Sirali alim: Kova'yi atlayamaz; para yetse de siradaki Tas
	var t: GameState = _state()
	t.money = 102.0
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
	check(near(t.carried, 400.0), "Sirik 1.5 sn'de dolar")


func test_rate() -> void:
	var s: GameState = _state()
	check(Economy.cost_rate(s) == 60.0, "oran 1 maliyeti 60")
	check(not Economy.buy_rate(s), "para yok: oran alinmaz")
	s.money = 60.0
	check(Economy.buy_rate(s) and s.rate_level == 1 and s.money == 0.0, "oran 4:1 alindi")
	s.carried = 8.0
	check(near(Economy.pour(s), 2.0), "8 damla 4:1 = 2 para")
	var expected: Array[float] = [60.0, 600.0, 8000.0, 120000.0]
	var t: GameState = _state()
	for c: float in expected:
		check(Economy.cost_rate(t) == c, "oran maliyeti %f" % c)
		t.money = c
		Economy.buy_rate(t)
	check(Economy.drops_per_money(t) == 1.0, "son oran 1:1")
	check(Economy.cost_rate(t) < 0.0, "oran bitti")


func test_source_costs() -> void:
	var s: GameState = _state()
	var crack: Array[float] = [15.0, 17.0, 19.0, 22.0]
	var dew: Array[float] = [100.0, 115.0, 132.0, 152.0]
	for i: int in 3:
		check(Economy.cost_source(s, "crack") == crack[i], "catlak maliyeti adet %d" % i)
		s.money = 1.0e6
		check(Economy.buy_source(s, "crack"), "catlak alinir")
	check(Economy.cost_source(s, "crack") == crack[3], "catlak 4. maliyet")
	var t: GameState = _state()
	for i: int in 3:
		check(Economy.cost_source(t, "dew") == dew[i], "cig maliyeti adet %d" % i)
		t.money = 1.0e6
		Economy.buy_source(t, "dew")
	check(Economy.cost_source(t, "yok") < 0.0, "bilinmeyen kaynak -1")
	check(not Economy.buy_source(t, "yok"), "bilinmeyen kaynak alinmaz")
	check(Economy.source_count(s, "crack") == 3, "adet 3")


func test_loss() -> void:
	var s: GameState = _state()
	check(near(Economy.loss_fraction(s), 0.30), "taban kayip 30")
	for def: Dictionary in Cfg.LOSS_UPGRADES:
		s.money = 1.0e9
		check(Economy.buy_loss(s, def["id"]), "kayip yukseltmesi %s" % def["id"])
		check(not Economy.buy_loss(s, def["id"]), "ikinci kez alinmaz")
	check(near(Economy.loss_fraction(s), 0.03), "tum yukseltmelerle kayip 3")
	var t: GameState = _state()
	t.money = 200.0
	Economy.buy_loss(t, "rock_bed")
	check(near(Economy.loss_fraction(t), 0.22), "Kaya yatagi sonrasi 22")


func test_tick() -> void:
	var s: GameState = _state()
	s.sources["crack"] = 1
	check(near(Economy.passive_rate_net(s), 0.35), "catlak net 0.35/sn")
	var added: float = Economy.tick(s, 10.0, 0.0)
	check(near(added, 3.5) and near(s.total_drops, 3.5), "10 sn: 3.5 damla")
	check(near(s.money, 0.7), "3.5 damla 5:1 = 0.7 para")
	var t: GameState = _state()
	var d: float = Economy.tick(t, 10.0, 2.0)
	check(near(d, 20.0), "yalniz kanal: kayipsiz 20 damla")
	var u: GameState = _state()
	u.sources["crack"] = 1
	Economy.tick(u, 10.0, 2.0)
	check(near(u.total_drops, 23.5), "pasif 3.5 + kanal 20")
	var big: GameState = _state()
	big.sources["dew"] = 2
	Economy.tick(big, 1.0e6, 0.0)
	check(near(big.total_drops, 6.0 * 0.7 * 1.0e6, 1.0), "buyuk delta dogru")
	check(Economy.tick(big, 0.0, 5.0) == 0.0, "delta 0")
	check(Economy.tick(big, 1.0, NAN) >= 0.0, "NaN kanal cokmez")


func _at(drops: float) -> GameState:
	var s: GameState = _state()
	s.total_drops = drops
	return s


func test_stages() -> void:
	var pairs: Array = [[0.0, 0], [49.0, 0], [50.0, 1], [999.0, 1], [1000.0, 2], [24999.0, 2], [25000.0, 3], [399999.0, 3], [400000.0, 4], [5.0e6, 4]]
	for p: Array in pairs:
		check(Economy.stage_index(_at(p[0])) == p[1], "asama %f -> %d" % [p[0], p[1]])
	check(Economy.stage_progress(_at(0.0)) == 0.0, "ilerleme 0")
	var mid: float = Economy.stage_progress(_at(7.0))
	check(mid > 0.0 and mid < 1.0, "asama ici ilerleme ara deger")
	check(near(Economy.stage_progress(_at(50.0)), 0.0), "esikte ilerleme 0")
	check(Economy.stage_progress(_at(1.0e9)) == 1.0, "son asama ilerleme 1")
	check(not Economy.is_finished(_at(1999999.0)), "oyun bitmedi")
	check(Economy.is_finished(_at(2000000.0)), "oyun bitti")
	check(Economy.fish_count(_at(1000.0)) == 2 and Economy.fish_count(_at(1.0e6)) == 9, "balik")
	check(Economy.bird_count(_at(999.0)) == 0 and Economy.bird_count(_at(25000.0)) == 3 and Economy.bird_count(_at(1.0e6)) == 6, "kus")
	check(not Economy.reeds_visible(_at(999.0)) and Economy.reeds_visible(_at(1000.0)), "kamis")


func test_lake_fill() -> void:
	var prev: float = -1.0
	var ok: bool = true
	var d: float = 0.0
	while d < 1.0e7:
		var f: float = Economy.lake_fill(_at(d))
		if f < prev or f < 0.0 or f > 1.0:
			ok = false
		prev = f
		d = d * 1.05 + 0.5
	check(ok, "lake_fill tekduze ve 0..1")
	check(Economy.lake_fill(_at(0.0)) == 0.0, "bos gol 0")
	check(Economy.lake_fill(_at(400000.0)) == 1.0, "son esikte 1")
	check(Economy.lake_fill(_at(1.0e7)) == 1.0, "ote 1")
	for th: float in [50.0, 1000.0, 25000.0, 400000.0]:
		var a: float = Economy.lake_fill(_at(th - 0.01))
		var b: float = Economy.lake_fill(_at(th))
		check(b >= a and b - a < 1e-3, "esikte surekli %f" % th)


func test_buy_fail() -> void:
	var s: GameState = _state()
	s.money = 5.0
	var before: Dictionary = _snapshot(s)
	check(not Economy.buy_tool(s), "tool yetmez")
	check(not Economy.buy_rate(s), "rate yetmez")
	check(not Economy.buy_source(s, "crack"), "kaynak yetmez")
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
	s.sources["crack"] = 1
	s.last_seen_unix = 1000
	check(Economy.apply_offline(s, 1029) == 0.0, "29 sn 0")
	check(s.last_seen_unix == 1000, "kisa surede last_seen ayni")
	check(near(Economy.apply_offline(s, 1600), 210.0), "10 dk = 210 damla")
	check(s.last_seen_unix == 1600, "last_seen guncel")
	var t: GameState = _state()
	t.sources["crack"] = 1
	t.last_seen_unix = 1000
	check(near(Economy.apply_offline(t, 1000 + 5 * 3600), 315.0), "5 saat 900 sn ile sinirli")
	var u: GameState = _state()
	u.sources["crack"] = 1
	u.last_seen_unix = 1000
	check(near(Economy.apply_offline(u, 1000 + 5 * 3600, 1.0), 315.0 + 900.0), "kanal teslimati eklenir")
	var v: GameState = _state()
	v.sources["crack"] = 1
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
	s.sources = {"crack": 4, "dew": 2}
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
	check(SaveCodec.to_dict(r) == d or (r.tool_level == 3 and r.rate_level == 2 and r.sources.get("crack", 0) == 4), "JSON gidis donus")
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
	check(r.sources.is_empty(), "bozuk kaynaklar atildi")
	check(r.loss_upgrades.size() == 1 and r.loss_upgrades[0] == "rock_bed", "bilinmeyen id atildi, tekrar yok")
	check(r.total_money_earned >= 0.0 and r.last_seen_unix == 0, "negatif/yanlis tur")
	var partial: GameState = SaveCodec.from_dict({"money": 50.0, "tool_level": 2.5, "carried": 1.0e9, "tool_level_x": 1})
	check(near(partial.money, 50.0) and partial.tool_level == 0, "kismi kayit: gecerli alan korunur, kesirli seviye 0")
	check(partial.carried <= Economy.tool_capacity(partial), "carried kapasiteye kirpilir")
	check(SaveCodec.from_dict({"version": "x", "money": 5.0}).money == 0.0, "bozuk surum yeni oyun")
	check(SaveCodec.from_dict({"version": 99, "money": 5.0}).money == 0.0, "gelecek surum yeni oyun")
	check(SaveCodec.from_dict({"money": 1.0e30}).money == 0.0, "asiri buyuk sayi atilir")
