extends SceneTree
## HUD'i sahte oyunla tek basina gosterir ve ekran goruntusu alir.
## Kullanim: godot --path . -s res://tests/hud_view.gd -- --out="yol.png"

const GameState = preload("res://scripts/core/game_state.gd")
const HudScript = preload("res://scripts/ui/hud.gd")

const FAKE_SOURCE: String = "extends Node\nsignal poured(drops: float, money: float)\nsignal stage_changed(index: int)\nsignal prompt_changed(text: String)\nvar state\nvar prompt_text: String = \"\"\nfunc income_per_minute() -> float:\n\treturn 12.5\n"

var _frame: int = 0
var _out: String = "hud.png"
var _game: Node
var _emitted_at: float = -1.0
var _elapsed: float = 0.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	var back := ColorRect.new()
	back.color = Color(0.45, 0.66, 0.78)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var ground := ColorRect.new()
	ground.color = Color(0.47, 0.62, 0.30)
	ground.anchor_top = 0.6
	ground.anchor_right = 1.0
	ground.anchor_bottom = 1.0
	root.add_child(ground)

	var script := GDScript.new()
	script.source_code = FAKE_SOURCE
	script.reload()
	_game = Node.new()
	_game.set_script(script)
	var state := GameState.new()
	state.money = 1234.5
	state.total_drops = 30000.0
	state.carried = 12.0
	state.tool_level = 2
	_game.set("state", state)
	_game.set("prompt_text", "Sol tık: suyu dök")
	root.add_child(_game)

	var hud: CanvasLayer = HudScript.new()
	hud.set("game", _game)
	root.add_child(hud)


func _process(delta: float) -> bool:
	_frame += 1
	_elapsed += delta
	if _frame == 5:
		_game.emit_signal("poured", 15.0, 3.0)
		_game.emit_signal("stage_changed", 3)
		_emitted_at = _elapsed
	if _emitted_at >= 0.0 and _elapsed - _emitted_at >= 0.5:
		var image: Image = root.get_texture().get_image()
		var err: Error = image.save_png(_out)
		print("Kaydedildi: %s (hata: %d, boyut: %s)" % [_out, err, str(image.get_size())])
		quit(0 if err == OK else 1)
	return false
