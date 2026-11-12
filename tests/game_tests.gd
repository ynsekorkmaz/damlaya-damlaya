extends SceneTree

const Cfg = preload("res://scripts/core/economy_config.gd")
const InputSetup = preload("res://scripts/core/input_setup.gd")
const GameScript = preload("res://scripts/game/game.gd")

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
	g.state.sources["crack"] = 10
	var expect: float = 10 * 0.5 * (1.0 - 0.30) / 5.0 * 60.0
	check(absf(g.income_per_minute() - expect) < 1e-6, "dakika geliri (%f / %f)" % [g.income_per_minute(), expect])
	g.state.sources.clear()

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
	g.free()
	InputSetup.register()
	check(InputMap.has_action("interact") and InputMap.has_action("pour"), "interact ve pour eylemleri kayitli")
	check(_has_mouse("interact", MOUSE_BUTTON_LEFT) and not _has_mouse("interact", MOUSE_BUTTON_RIGHT), "interact sol tik")
	check(_has_mouse("pour", MOUSE_BUTTON_RIGHT) and not _has_mouse("pour", MOUSE_BUTTON_LEFT), "pour sag tik")
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


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
