extends SceneTree
## Girdi akisi (sentetik olaylarla): 1/2 yuva, Q kitapcik, Enter secim, sol tik kur, R dondur, sag tik sok, surukle, Shift+tekerlek.
## Calistirma: godot --path <proje> -s res://tests/input_flow_tests.gd -- --no-save --debug-build=kanal
## Fare yakalama gerektirir; baslik penceresi olmayan (headless) surucuyle yakalama taklit edilemezse testler "atlandi" yazar.

const Pieces = preload("res://scripts/core/canal_pieces.gd")

var _frame: int = 0
var _failures: int = 0
var _checks: int = 0
var _main: Node
var _skipped: bool = false
var _money_before: float = 0.0
var _pieces_before: int = 0


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _mouse(button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.shift_pressed = shift
	ev.position = Vector2(640.0, 360.0)
	Input.parse_input_event(ev)


func _node(path: String) -> Node:
	return _main.get_node(path)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(_main)
		return false
	if _skipped:
		return false
	var equipment: Node = _main.get_node("Equipment")
	var game: Node = _main.get_node("Game")
	var player: Node = null
	var build: Node = _main.get_node("BuildController")
	var book: Node = null
	for child: Node in _main.get_children():
		if child.has_method("open_section") and child.has_method("is_open") and child.get_script().resource_path.ends_with("build_book.gd"):
			book = child
		if child.has_method("get_camera"):
			player = child
	match _frame:
		5:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		8:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				print("ATLANDI: fare yakalanamadi (headless?)")
				_skipped = true
				_finish()
				return false
			check(int(equipment.get("slot")) == 0, "baslangicta su aleti")
			_key(KEY_2, true)
			_key(KEY_2, false)
		10:
			check(int(equipment.get("slot")) == 1 and bool(equipment.call("hammer_active")), "2 tusu cekici eline alir")
			_key(KEY_1, true)
			_key(KEY_1, false)
		12:
			check(int(equipment.get("slot")) == 0, "1 tusu su aletini alir")
			_mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
			_mouse(MOUSE_BUTTON_WHEEL_DOWN, false)
		14:
			check(int(equipment.get("slot")) == 1, "tekerlek cekice gecirir")
			_key(KEY_Q, true)
			_key(KEY_Q, false)
		16:
			check(bool(book.call("is_open")), "Q kitapcigi acar")
			check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not bool(player.get("input_enabled")), "kitapcik acikken fare serbest, oyuncu girdisi kapali")
			_key(KEY_ENTER, true)
			_key(KEY_ENTER, false)
		18:
			check(not bool(book.call("is_open")), "Enter kitapcigi kapatir")
			check(String(equipment.get("selected")).begins_with("canal:"), "Enter secili yapiyi belirler (%s)" % String(equipment.get("selected")))
			check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and bool(player.get("input_enabled")), "kitapcik kapaninca fare yakalanir")
			# bos bir hucreye bak: (-35, 10)'dan (-35, 5) yonune
			(player as Node3D).global_position = Vector3(-35.0, 0.3, 10.0)
			(player as Node3D).rotation.y = 0.0
			(player.call("get_camera") as Camera3D).rotation.x = deg_to_rad(-20.0)
		24:
			var cell: Vector2i = build.get("looked_cell")
			check(cell.x >= 0, "bakilan hucre bulundu (%s)" % str(cell))
			_money_before = float((game.get("state") as Object).get("money"))
			_pieces_before = int((game.get("canal") as Object).call("piece_count"))
			_mouse(MOUSE_BUTTON_LEFT, true)
		26:
			_mouse(MOUSE_BUTTON_LEFT, false)
			var net: Object = game.get("canal")
			check(int(net.call("piece_count")) == _pieces_before + 1, "sol tik parca kurar")
			check(float((game.get("state") as Object).get("money")) < _money_before, "kurulum para dusurur")
			var cell2: Vector2i = build.get("looked_cell")
			check("canal:" + String((net.call("get_piece", cell2.x, cell2.y) as Dictionary).get("piece", "")) == String(equipment.get("selected")), "bakilan hucreye secili parca kuruldu")
			_key(KEY_R, true)
			_key(KEY_R, false)
		28:
			var cell3: Vector2i = build.get("looked_cell")
			var piece: Dictionary = (game.get("canal") as Object).call("get_piece", cell3.x, cell3.y)
			check(int(piece.get("rotation", -1)) == 1, "dolu hucreye bakarken R parcayi doner")
			_money_before = float((game.get("state") as Object).get("money"))
			_mouse(MOUSE_BUTTON_RIGHT, true)
		30:
			_mouse(MOUSE_BUTTON_RIGHT, false)
			check(int((game.get("canal") as Object).call("piece_count")) == _pieces_before, "sag tik parcayi sokar")
			check(float((game.get("state") as Object).get("money")) > _money_before, "sokme iade verir")
			# surukle: sol tus basili, oyuncuyu yana kaydir
			_pieces_before = int((game.get("canal") as Object).call("piece_count"))
			_mouse(MOUSE_BUTTON_LEFT, true)
		32:
			(player as Node3D).global_position = Vector3(-33.0, 0.3, 10.0)
		34:
			(player as Node3D).global_position = Vector3(-31.0, 0.3, 10.0)
		36:
			_mouse(MOUSE_BUTTON_LEFT, false)
			var added: int = int((game.get("canal") as Object).call("piece_count")) - _pieces_before
			check(added >= 3, "basili tutup surukleyince birden cok hucreye doser (%d)" % added)
			_mouse(MOUSE_BUTTON_WHEEL_UP, true, true)
			_mouse(MOUSE_BUTTON_WHEEL_UP, false, true)
		38:
			check(int(equipment.get("slot")) == 1, "Shift+tekerlek yuvayi degistirmez")
			_key(KEY_Q, true)
			_key(KEY_Q, false)
		40:
			check(bool(book.call("is_open")), "Q tekrar acar")
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		42:
			check(not bool(book.call("is_open")), "Esc kitapcigi kapatir")
			_key(KEY_1, true)
			_key(KEY_1, false)
		44:
			check(int(equipment.get("slot")) == 0, "su aleti eldeyken yuva 0")
			_key(KEY_Q, true)
			_key(KEY_Q, false)
		46:
			check(not bool(book.call("is_open")), "su aleti eldeyken Q kitapcigi acmaz")
			# savak (3, 1): su aleti eldeyken E aci/kapatir
			(player as Node3D).global_position = Vector3(-41.0, 0.3, -2.0)
			(player as Node3D).rotation.y = 0.0
			(player.call("get_camera") as Camera3D).rotation.x = deg_to_rad(-20.0)
		52:
			check(bool(build.get("looked_gate")), "savaga bakilirken looked_gate (hucre %s)" % str(build.get("looked_cell")))
			_key(KEY_E, true)
			_key(KEY_E, false)
		54:
			var gate: Dictionary = (game.get("canal") as Object).call("get_piece", 3, 1)
			check(not bool(gate.get("open", true)), "E savagi kapatir")
			_finish()
	return false


func _finish() -> void:
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
