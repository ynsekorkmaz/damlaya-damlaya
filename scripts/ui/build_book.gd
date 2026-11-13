extends CanvasLayer
## Yapı kitapçığı (Q, yalnızca çekiç eldeyken): açık bir defter. Sol sayfa bölümler (Kanallar, Bitkiler, Su kaynakları),
## sağ sayfa o bölümün yapıları (ad, açıklama, o anki bedel; kilitliyse soluk ve "Kilitli (Tab)"). Kanallarda malzeme seçimi vardır.
## Tıklama ya da Enter yapıyı seçer ve kitapçığı kapatır. Klavye: yukarı/aşağı satır, sol/sağ bölüm (malzeme satırında malzeme), Q/Esc kapatır.
## Dış bağlantı: add_child'dan önce `game`, `player`, `equipment` atanır; açma/kapama panel_manager.gd üzerinden.

const Pieces = preload("res://scripts/core/canal_pieces.gd")
const Build = preload("res://scripts/core/build.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const PAPER := Color(0.93, 0.87, 0.72)
const PAPER_DARK := Color(0.86, 0.77, 0.59)
const PAPER_HOVER := Color(0.89, 0.80, 0.60, 0.9)
const INK := Color(0.20, 0.13, 0.08)
const INK_DIM := Color(0.20, 0.13, 0.08, 0.42)
const INK_GOLD := Color(0.52, 0.33, 0.06)
const BORDER := Color(0.40, 0.26, 0.15)
const SPINE := Color(0.30, 0.19, 0.10)
const CURSOR_BG := Color(0.97, 0.88, 0.55, 0.85)

const BOOK_SIZE: Vector2 = Vector2(1000.0, 600.0)
const PAGE_PAD: float = 22.0
const ROW_HEIGHT: float = 76.0
const DESC_MAX_LINES: int = 2
const COST_WIDTH: float = 128.0
const TITLE_SIZE: int = 32
const SECTION_SIZE: int = 24
const NAME_SIZE: int = 19
const DESC_SIZE: int = 13
const COST_SIZE: int = 17
const HINT_SIZE: int = 13
const LOCKED_TEXT: String = "Kilitli (Tab)"
const HINT_TEXT: String = "Yukarı / aşağı: seç    Sol / sağ: bölüm ya da malzeme    Enter: seç    Q ya da Esc: kapat"
const SELECTED_TEXT: String = "Elinde"
const SECTIONS: Array[Dictionary] = [
	{"id": "canal", "arg": "kanal", "name_tr": "Kanallar", "blurb_tr": "Su yolları: parçaları alana döşe, pınardan göle ulaştır."},
	{"id": "plants", "arg": "bitki", "name_tr": "Bitkiler", "blurb_tr": "Kıyıya kamış, uzağa gölge ağacı dik; sızıntıyı azaltırlar.", "kinds": ["reeds", "shade_tree"]},
	{"id": "sources", "arg": "kaynak", "name_tr": "Su kaynakları", "blurb_tr": "Kendiliğinden su veren yapılar; vadinin uygun yerlerine kur.", "kinds": ["crack", "dew", "rain_cloud", "spring", "stream_mouth"]},
]

var game: Node
var player: Node
var equipment: Node

var _open: bool = false
var _root: Control
var _section_buttons: Array[Button] = []
var _blurb: Label
var _money_label: Label
var _right_title: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _section: int = 0
var _cursor: int = 0
var _rows: Array[Dictionary] = []   ## {type: "material"/"entry", id, button, locked, ...}
var _material_buttons: Dictionary = {}
var _material_row: HBoxContainer


func _ready() -> void:
	layer = 20
	_build()
	_root.visible = false
	set_process(false)


func is_open() -> bool:
	return _open


func open() -> void:
	open_section("")


## arg: kanal / bitki / kaynak (boşsa son bölüm).
func open_section(arg: String) -> void:
	if _open:
		return
	for i in range(SECTIONS.size()):
		if String(SECTIONS[i]["arg"]) == arg:
			_section = i
	_open = true
	_root.visible = true
	set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		player.set("input_enabled", false)
	_populate()
	_cursor = _start_cursor()
	_apply_cursor()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	set_process(false)
	if player != null:
		player.set("input_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- Girdi ----------

func _input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("build_book"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_move_cursor(1)
	elif event.is_action_pressed("ui_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("ui_right"):
		_horizontal(1)
	elif event.is_action_pressed("ui_left"):
		_horizontal(-1)
	elif event.is_action_pressed("ui_accept"):
		_choose(_cursor)
	else:
		return
	get_viewport().set_input_as_handled()


func _move_cursor(step: int) -> void:
	if _rows.is_empty():
		return
	_cursor = clampi(_cursor + step, 0, _rows.size() - 1)
	_apply_cursor()


func _horizontal(step: int) -> void:
	if not _rows.is_empty() and String(_rows[_cursor]["type"]) == "material":
		_cycle_material(step)
		return
	_set_section(posmod(_section + step, SECTIONS.size()))


func _set_section(index: int) -> void:
	if index == _section:
		return
	_section = index
	_populate()
	_cursor = _start_cursor()
	_apply_cursor()


# ---------- Kurulum ----------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = UiTheme.DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var book := HBoxContainer.new()
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.offset_left = -BOOK_SIZE.x * 0.5
	book.offset_right = BOOK_SIZE.x * 0.5
	book.offset_top = -BOOK_SIZE.y * 0.5
	book.offset_bottom = BOOK_SIZE.y * 0.5
	book.grow_horizontal = Control.GROW_DIRECTION_BOTH
	book.grow_vertical = Control.GROW_DIRECTION_BOTH
	book.add_theme_constant_override("separation", 0)
	_root.add_child(book)

	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(BOOK_SIZE.x * 0.38, 0.0)
	left.add_theme_stylebox_override("panel", _page_style(true))
	book.add_child(left)
	var spine := ColorRect.new()
	spine.color = SPINE
	spine.custom_minimum_size = Vector2(8.0, 0.0)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(spine)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _page_style(false))
	book.add_child(right)

	_build_left(left)
	_build_right(right)


func _page_style(is_left: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = BORDER
	s.set_border_width_all(3)
	s.set_corner_radius_all(4)
	if is_left:
		s.corner_radius_top_left = 14
		s.corner_radius_bottom_left = 14
	else:
		s.corner_radius_top_right = 14
		s.corner_radius_bottom_right = 14
	s.set_content_margin_all(PAGE_PAD)
	return s


func _build_left(page: PanelContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	page.add_child(col)
	col.add_child(UiTheme.label("Yapı Kitapçığı", TITLE_SIZE, INK))
	_money_label = UiTheme.label("", UiTheme.MONEY_SIZE - 6, INK_GOLD)
	col.add_child(_money_label)
	col.add_child(HSeparator.new())
	for i in range(SECTIONS.size()):
		var b := Button.new()
		b.text = String(SECTIONS[i]["name_tr"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0.0, 46.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", SECTION_SIZE)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(key, INK)
		b.pressed.connect(_set_section.bind(i))
		col.add_child(b)
		_section_buttons.append(b)
	_blurb = UiTheme.label("", NAME_SIZE - 3, INK)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_blurb)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)
	var hint: Label = UiTheme.label(HINT_TEXT, HINT_SIZE, INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)


func _build_right(page: PanelContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	page.add_child(col)
	_right_title = UiTheme.label("", SECTION_SIZE + 4, INK)
	col.add_child(_right_title)
	col.add_child(HSeparator.new())
	_material_row = HBoxContainer.new()
	_material_row.add_theme_constant_override("separation", 8)
	col.add_child(_material_row)
	for id: String in Pieces.MATERIAL_IDS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(110.0, 36.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", NAME_SIZE - 2)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(key, INK)
		b.pressed.connect(_pick_material.bind(id))
		_material_row.add_child(b)
		_material_buttons[id] = b
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)


# ---------- İçerik ----------

func _state() -> GameState:
	return game.get("state") as GameState


func _populate() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	_rows.clear()
	var def: Dictionary = SECTIONS[_section]
	_right_title.text = String(def["name_tr"])
	_blurb.text = String(def["blurb_tr"])
	var st: GameState = _state()
	_money_label.text = "Para: " + NumberFormat.format_money(st.money)
	for i in range(_section_buttons.size()):
		_style_section(_section_buttons[i], i == _section)
	var is_canal: bool = String(def["id"]) == "canal"
	_material_row.visible = is_canal
	if is_canal:
		_rows.append({"type": "material", "id": "", "button": null, "locked": false})
		_refresh_materials()
		for id: String in Pieces.PIECE_IDS:
			_add_entry("canal:" + id, id, true)
	else:
		for kind: Variant in def["kinds"]:
			_add_entry("free:" + String(kind), String(kind), false)


func _add_entry(key: String, id: String, is_canal: bool) -> void:
	var st: GameState = _state()
	var name_tr: String = ""
	var desc_tr: String = ""
	var cost_text: String = ""
	var locked: bool = false
	if is_canal:
		var pdef: Dictionary = Pieces.get_piece_def(id)
		name_tr = String(pdef["name_tr"])
		desc_tr = String(pdef["desc_tr"])
		locked = not st.canal_unlocked or not st.unlocked_pieces.has(id)
		var material: String = String(equipment.get("material")) if equipment != null else "earth"
		cost_text = NumberFormat.format_int(float(game.call("canal_piece_cost", id, material))) + " para"
	else:
		var kdef: Dictionary = Build.kind_def(id)
		name_tr = String(kdef["name_tr"])
		desc_tr = String(kdef["desc_tr"])
		locked = not Build.is_unlocked(st, id)
		cost_text = NumberFormat.format_int(Build.next_cost(st, id)) + " para"
		var have: int = Build.count(st, id)
		if have > 0:
			desc_tr += "  Kurulu: %d" % have
	if locked:
		cost_text = LOCKED_TEXT
	var is_current: bool = equipment != null and String(equipment.get("selected")) == key
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_index: int = _rows.size()
	button.pressed.connect(_choose.bind(row_index))
	button.mouse_entered.connect(_hover.bind(row_index))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8 if side == "left" or side == "right" else 3)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10)
	margin.add_child(line)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	var ink: Color = INK_DIM if locked else INK
	var name_label: Label = UiTheme.label(name_tr + ("   (" + SELECTED_TEXT + ")" if is_current else ""), NAME_SIZE, ink)
	texts.add_child(name_label)
	var desc: Label = UiTheme.label(desc_tr, DESC_SIZE, ink)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = DESC_MAX_LINES
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(desc)
	line.add_child(texts)
	var cost: Label = UiTheme.label(cost_text, COST_SIZE, INK_DIM if locked else INK_GOLD)
	cost.custom_minimum_size = Vector2(COST_WIDTH, 0.0)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(cost)
	button.add_child(margin)
	_list.add_child(button)
	_rows.append({"type": "entry", "id": key, "button": button, "locked": locked})


func _style_section(b: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER_DARK if active else Color(0.0, 0.0, 0.0, 0.0)
	s.set_corner_radius_all(6)
	if active:
		s.border_color = INK
		s.border_width_left = 5
	s.set_content_margin_all(8.0)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("hover", _hover_style())
	b.add_theme_stylebox_override("hover_pressed", s)


static func _hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER_HOVER
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8.0)
	return s


func _refresh_materials() -> void:
	var st: GameState = _state()
	var current: String = String(equipment.get("material")) if equipment != null else "earth"
	for id: String in Pieces.MATERIAL_IDS:
		var b: Button = _material_buttons[id]
		var locked: bool = not st.canal_unlocked or not st.unlocked_materials.has(id)
		var active: bool = id == current
		b.text = String(Pieces.MATERIALS[id]["name_tr"]) + (" (kilitli)" if locked else "")
		var s := StyleBoxFlat.new()
		s.bg_color = PAPER_DARK if active else Color(0.0, 0.0, 0.0, 0.0)
		s.border_color = INK if active else INK_DIM
		s.set_border_width_all(2 if active else 1)
		s.set_corner_radius_all(6)
		s.set_content_margin_all(6.0)
		for style_name: String in ["normal", "pressed", "hover", "hover_pressed"]:
			b.add_theme_stylebox_override(style_name, s)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(key, INK_DIM if locked else INK)


# ---------- İmleç ve seçim ----------

func _start_cursor() -> int:
	var sel: String = String(equipment.get("selected")) if equipment != null else ""
	for i in range(_rows.size()):
		if String(_rows[i]["id"]) == sel and not sel.is_empty():
			return i
	for i in range(_rows.size()):
		if String(_rows[i]["type"]) == "entry" and not bool(_rows[i]["locked"]):
			return i
	return 0


func _hover(index: int) -> void:
	if index != _cursor:
		_cursor = index
		_apply_cursor()


func _apply_cursor() -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		if String(row["type"]) != "entry":
			continue
		var b: Button = row["button"]
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.set_content_margin_all(4.0)
		if i == _cursor:
			s.bg_color = CURSOR_BG
			s.border_color = INK
			s.set_border_width_all(2)
		else:
			s.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		for style_name: String in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(style_name, s)
	if _cursor >= 0 and _cursor < _rows.size() and _rows[_cursor]["button"] != null:
		_scroll.ensure_control_visible(_rows[_cursor]["button"] as Control)
	elif not _rows.is_empty() and String(_rows[_cursor]["type"]) == "material":
		_scroll.scroll_vertical = 0


func _cycle_material(step: int) -> void:
	var st: GameState = _state()
	var current: String = String(equipment.get("material"))
	var i: int = Pieces.MATERIAL_IDS.find(current)
	for k in range(Pieces.MATERIAL_IDS.size()):
		i = posmod(i + step, Pieces.MATERIAL_IDS.size())
		var id: String = Pieces.MATERIAL_IDS[i]
		if st.canal_unlocked and st.unlocked_materials.has(id):
			_pick_material(id)
			return


func _pick_material(id: String) -> void:
	var st: GameState = _state()
	if not st.canal_unlocked or not st.unlocked_materials.has(id):
		return
	equipment.set("material", id)
	_populate()
	_apply_cursor()


func _choose(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	if String(row["type"]) != "entry" or bool(row["locked"]):
		return
	var key: String = String(row["id"])
	if key.begins_with("canal:"):
		equipment.set("canal_rotation", int(equipment.get("canal_rotation")))
	equipment.call("select", key)
	close()
