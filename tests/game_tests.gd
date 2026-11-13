extends SceneTree

const Cfg = preload("res://scripts/core/economy_config.gd")
const InputSetup = preload("res://scripts/core/input_setup.gd")
const GameScript = preload("res://scripts/game/game.gd")
const Build = preload("res://scripts/core/build.gd")

var _failures: int = 0
var _checks: int = 0
var _poured_drops: float = 0.0
var _poured_money: float = 0.0
var _filled_total: float = 0.0
var _prompts: Array[String] = []
var _stages: Array[int] = []


func _init() -> void:
	var g: Node = GameScript.new()
	g.setup(false)
	g.connect("poured", func(d: float, m: float) -> void:
		_poured_drops += d
		_poured_money += m)
	g.connect("filled", func(a: float) -> void: _filled_total += a)
	g.connect("prompt_changed", func(t: String) -> void: _prompts.append(t))
	g.connect("stage_changed", func(i: int) -> void: _stages.append(i))

	check(g.try_pour() == 0.0 and _poured_drops == 0.0, "bos elle dokme sinyal vermez")
	var added: float = g.try_fill(0.5)
	check(added > 0.0 and absf(_filled_total - added) < 1e-9, "doldurma sinyali")
	for i in range(10):
		g.try_fill(0.5)
	check(g.state.carried == Cfg.TOOLS[0]["capacity"], "kapasiteye kadar dolar")
	check(g.try_fill(0.5) == 0.0, "doluyken eklenmez")
	var money: float = g.try_pour()
	check(money > 0.0 and absf(money - _poured_money) < 1e-9, "dokme para ve sinyal")
	check(g.state.carried == 0.0 and g.state.total_drops == Cfg.TOOLS[0]["capacity"], "dokme sonrasi durum")
	check(g.income_per_minute() == 0.0, "kaynak yokken gelir 0")
	for i: int in 10:
		Build.add(g.state, "crack", float(i), 0.0, 0.0)
	var expect: float = 10 * 0.5 * (1.0 - 0.30) / 5.0 * 60.0
	check(absf(g.income_per_minute() - expect) < 1e-6, "dakika geliri (%f / %f)" % [g.income_per_minute(), expect])
	g.state.structures.clear()
	g.state.counts.clear()

	g.set_prompt("a")
	g.set_prompt("a")
	g.set_prompt("b")
	check(_prompts == ["a", "b"] and g.prompt_text == "b", "ipucu yalniz degisince yayilir")

	g._process(0.016)
	g.state.total_drops = 60.0
	g._process(0.016)
	check(_stages == [1], "asama degisimi sinyali (%s)" % str(_stages))
	g._process(0.016)
	check(_stages == [1], "ayni asama tekrar yayilmaz")
	test_purchases()
	g.free()
	InputSetup.register()
	check(InputMap.has_action("interact") and InputMap.has_action("pour"), "interact ve pour eylemleri kayitli")
	check(_has_mouse("interact", MOUSE_BUTTON_LEFT) and not _has_mouse("interact", MOUSE_BUTTON_RIGHT), "interact sol tik")
	check(_has_mouse("pour", MOUSE_BUTTON_RIGHT) and not _has_mouse("pour", MOUSE_BUTTON_LEFT), "pour sag tik")
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func test_purchases() -> void:
	var g: Node = GameScript.new()
	g.setup(false)
	var bought: Array[String] = []
	g.connect("purchased", func(k: String, i: String) -> void: bought.append(k + ":" + i))
	check(not g.buy_tool() and not g.buy_rate() and not g.buy_hammer() and not g.buy_loss("rock_bed"), "para yokken hicbiri alinmaz")
	check(not g.unlock_tool() and not g.upgrade_tool("palm") and not g.unlock_source("crack") and not g.unlock_canal(), "para yokken kilit ve yukseltme yok")
	check(bought.is_empty() and g.state.tool_level == 0, "basarisiz alimda sinyal ve seviye degismez")
	g.state.money = 10000.0
	check(not g.buy_tool() and g.state.tool_level == 0 and g.state.money == 10000.0, "kilitsiz alet dukkanda alinmaz")
	check(not g.buy_hammer() and not g.upgrade_tool("cup") and not g.upgrade_tool("yok"), "kilitsiz cekic ve sahipsiz alet")
	check(g.unlock_tool() and g.state.tool_unlocked == 1 and absf(g.state.money - 9994.0) < 1e-9, "alet kilidi acma (6)")
	check(g.buy_tool() and g.state.tool_level == 1 and absf(g.state.money - (9994.0 - Cfg.TOOLS[1]["cost"])) < 1e-9, "alet alimi")
	var before: float = g.state.money
	check(g.upgrade_tool("cup") and g.state.tool_upgrades["cup"] == 1 and absf(g.state.money - (before - 8.0)) < 1e-9, "alet kapasite yukseltme")
	check(g.buy_rate() and g.state.rate_level == 1, "oran alimi")
	check(g.unlock_source("crack"), "kaynak kilidi")
	g.state.hammer_owned = true
	check(g.place_structure("crack", 1.0, 2.0, 0.0) and Build.count(g.state, "crack") == 1, "kaynak yapisi kurulur")
	check(g.buy_loss("rock_bed") and g.state.loss_upgrades.has("rock_bed"), "kayip alimi")
	check(not g.buy_loss("rock_bed"), "alinmis kayip tekrar alinmaz")
	check(not g.place_structure("yok", 0.0, 0.0, 0.0) and not g.unlock_source("yok"), "bilinmeyen kaynak kurulmaz")
	check(bought == ["tool_unlock:cup", "tool:cup", "tool_upgrade:cup", "rate:rate", "source_unlock:crack", "loss:rock_bed"], "satin alma sinyalleri (%s)" % str(bought))
	g.state.money = 0.5
	check(not g.place_structure("crack", 1.0, 2.0, 0.0) and Build.count(g.state, "crack") == 1 and g.state.money == 0.5, "para yetmezse false, durum ayni")
	g.free()
	test_canal_wrappers()


func test_canal_wrappers() -> void:
	var g: Node = GameScript.new()
	g.setup(false)
	var bought: Array[String] = []
	g.connect("purchased", func(k: String, i: String) -> void: bought.append(k + ":" + i))
	g.state.money = 1.0e7
	check(not g.open_spring("A") and not g.upgrade_canal_width() and not g.upgrade_canal_lining(), "kanal kilitliyken hicbiri alinmaz")
	check(g.state.money == 1.0e7 and bought.is_empty(), "kilitliyken para ayni")
	check(g.unlock_canal() and g.state.canal_unlocked and absf(g.state.money - (1.0e7 - Cfg.CANAL_UNLOCK_COST)) < 1e-6, "kanal kilidi parayi duser")
	check(not g.unlock_canal(), "kanal kilidi bir kez")
	var money: float = g.state.money
	check(g.open_spring("A") and g.canal.is_spring_open("A"), "pinar acilir")
	check(absf(g.state.money - (money - 6000.0)) < 1e-6, "pinar parayi duser")
	check(not g.open_spring("A") and absf(g.state.money - (money - 6000.0)) < 1e-6, "acik pinar tekrar acilmaz, para ayni")
	check(not g.open_spring("Z"), "bilinmeyen pinar")
	money = g.state.money
	check(g.upgrade_canal_width() and g.canal.width_level == 1 and absf(g.state.money - (money - 12000.0)) < 1e-6, "genis kanal")
	money = g.state.money
	check(g.upgrade_canal_lining() and g.canal.lining_level == 1 and absf(g.state.money - (money - 15000.0)) < 1e-6, "tas kaplama")
	check(bought == ["canal_unlock:canal", "canal_spring:A", "canal_width:width", "canal_lining:lining"], "kanal sinyalleri (%s)" % str(bought))
	g.state.money = 100.0
	check(not g.open_spring("B") and not g.canal.is_spring_open("B") and g.state.money == 100.0, "para yetmezse pinar acilmaz")
	check(not g.upgrade_canal_width() and g.canal.width_level == 1, "para yetmezse genis kanal olmaz")
	g.state.money = 1.0e12
	for i: int in 10:
		g.upgrade_canal_width()
		g.upgrade_canal_lining()
	check(g.canal.width_level == 4 and g.canal.lining_level == 3, "seviye tavani")
	var after: float = g.state.money
	check(not g.upgrade_canal_width() and g.state.money == after, "tavanda para dusmez")
	g.free()


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func _has_mouse(action: String, button: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == button:
			return true
	return false
