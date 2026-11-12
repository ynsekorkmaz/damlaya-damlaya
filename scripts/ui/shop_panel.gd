extends CanvasLayer
## Dükkân paneli: alet, su değeri, pasif kaynak ve kayıp azaltma satın alımları.
## Dış bağlantı: add_child'dan önce `game` ve `player` atanır. E ya da Esc kapatır.
## Yalnızca Economy'nin "görünür" dediği öğeler listelenir.

const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")

const KIND_TOOL: String = "tool"
const KIND_RATE: String = "rate"
const KIND_SOURCE: String = "source"
const KIND_LOSS: String = "loss"

const PANEL_SIZE: Vector2 = Vector2(840.0, 600.0)
const PANEL_PAD: float = 18.0
const ROW_PAD: float = 10.0
const INFO_WIDTH: float = 190.0
const COST_WIDTH: float = 96.0
const BUTTON_SIZE: Vector2 = Vector2(86.0, 42.0)
const TITLE_SIZE: int = 34
const MONEY_SIZE: int = 26
const SECTION_SIZE: int = 20
const NAME_SIZE: int = 20
const DESC_SIZE: int = 15
const INFO_SIZE: int = 16
const COST_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 19
const HINT_SIZE: int = 14
const REFRESH_INTERVAL: float = 0.25

const DIM_COLOR := Color(0.0, 0.02, 0.04, 0.45)
const PANEL_BG := Color(0.05, 0.08, 0.11, 0.95)
const PANEL_BORDER := Color(0.45, 0.70, 0.85, 0.8)
const ROW_BG := Color(0.12, 0.17, 0.21, 0.9)
const TEXT := Color(0.97, 0.97, 0.94)
const TEXT_DIM := Color(0.74, 0.80, 0.82)
const SECTION_COLOR := Color(0.55, 0.85, 0.95)
const MONEY_COLOR := Color(1.0, 0.82, 0.30)
const BUY_BG := Color(0.18, 0.55, 0.38)
const BUY_HOVER := Color(0.24, 0.68, 0.46)
const BUY_PRESSED := Color(0.12, 0.42, 0.29)
const BUY_OFF_BG := Color(0.20, 0.24, 0.27, 0.6)
const FOCUS_COLOR := Color(1.0, 0.93, 0.55)
const CLEAR := Color(0.0, 0.0, 0.0, 0.0)

var game: Node
var player: Node

var _root: Control
var _content: VBoxContainer
var _money_label: Label
var _empty_label: Label
var _scroll: ScrollContainer
var _rows: Array[Dictionary] = []
var _timer: float = 0.0
var _open: bool = false


func _ready() -> void:
	layer = 20
	_build()
	_root.visible = false
	set_process(false)
	if game != null and game.has_signal("shop_requested"):
		game.connect("shop_requested", open)


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	_root.visible = true
	set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		player.set("input_enabled", false)
	_rebuild(true)


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	set_process(false)
	if player != null:
		player.set("input_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("shop")) and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")) \
			and get_viewport().gui_get_focus_owner() == null:
		_focus_first_enabled()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < REFRESH_INTERVAL:
		return
	_timer = 0.0
	_refresh()


# ---------- Kurulum ----------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(PANEL_PAD)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = _label("Dükkân", TITLE_SIZE, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = _label("", MONEY_SIZE, MONEY_COLOR)
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_money_label)

	column.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content)

	_empty_label = _label("Henüz alınacak bir şey yok. Su dök, para kazan.", NAME_SIZE, TEXT_DIM)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hint: Label = _label("Yukarı / aşağı: seç    Enter: al    E ya da Esc: kapat", HINT_SIZE, TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6.0)
	return style


func _make_buy_button() -> Button:
	var button := Button.new()
	button.text = "Al"
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.68, 0.70, 0.7))
	button.add_theme_stylebox_override("normal", _make_button_style(BUY_BG, CLEAR, 0))
	button.add_theme_stylebox_override("hover", _make_button_style(BUY_HOVER, CLEAR, 0))
	button.add_theme_stylebox_override("pressed", _make_button_style(BUY_PRESSED, CLEAR, 0))
	button.add_theme_stylebox_override("disabled", _make_button_style(BUY_OFF_BG, CLEAR, 0))
	button.add_theme_stylebox_override("focus", _make_button_style(CLEAR, FOCUS_COLOR, 3))
	return button


func _add_section(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label(title, SECTION_SIZE, SECTION_COLOR))
	_content.add_child(box)
	return box


func _add_row(section: VBoxContainer, kind: String, id: String) -> Dictionary:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG
	style.set_corner_radius_all(8)
	style.set_content_margin_all(ROW_PAD)
	row.add_theme_stylebox_override("panel", style)
	section.add_child(row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	line.add_child(texts)
	var name_label: Label = _label("", NAME_SIZE, TEXT)
	texts.add_child(name_label)
	var desc_label: Label = _label("", DESC_SIZE, TEXT_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 120.0
	texts.add_child(desc_label)

	var info_label: Label = _label("", INFO_SIZE, TEXT_DIM)
	info_label.custom_minimum_size.x = INFO_WIDTH
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(info_label)

	var cost_label: Label = _label("", COST_SIZE, MONEY_COLOR)
	cost_label.custom_minimum_size.x = COST_WIDTH
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(cost_label)

	var button: Button = _make_buy_button()
	line.add_child(button)
	button.pressed.connect(_on_buy.bind(kind, id))
	return {
		"kind": kind, "id": id, "name": name_label, "desc": desc_label,
		"info": info_label, "cost": cost_label, "button": button,
	}


# ---------- Veri ----------

func _state() -> GameState:
	if game == null:
		return null
	return game.get("state") as GameState


## Görünür öğelerin sırası: [[kind, id], ...]
func _wanted() -> Array:
	var out: Array = []
	var state: GameState = _state()
	if state == null:
		return out
	if Economy.tool_visible(state):
		out.append([KIND_TOOL, String(Cfg.TOOLS[state.tool_level + 1]["id"])])
	if Economy.rate_visible(state):
		out.append([KIND_RATE, "rate"])
	for def: Dictionary in Cfg.SOURCES:
		if Economy.source_visible(state, def["id"]):
			out.append([KIND_SOURCE, String(def["id"])])
	for def: Dictionary in Cfg.LOSS_UPGRADES:
		if Economy.has_loss_upgrade(state, def["id"]) or Economy.loss_visible(state, def["id"]):
			out.append([KIND_LOSS, String(def["id"])])
	return out


func _section_title(kind: String) -> String:
	match kind:
		KIND_TOOL:
			return "Aletler"
		KIND_RATE:
			return "Su değeri"
		KIND_SOURCE:
			return "Kaynaklar"
	return "Kayıp azaltma"


func _same_layout(wanted: Array) -> bool:
	if wanted.size() != _rows.size():
		return false
	for i: int in wanted.size():
		if _rows[i]["kind"] != wanted[i][0] or _rows[i]["id"] != wanted[i][1]:
			return false
	return true


func _rebuild(grab_focus: bool) -> void:
	var focus_kind: String = ""
	var focus_id: String = ""
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for row: Dictionary in _rows:
		if row["button"] == focused:
			focus_kind = row["kind"]
			focus_id = row["id"]
	if _empty_label.get_parent() != null:
		_content.remove_child(_empty_label)
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rows.clear()
	var wanted: Array = _wanted()
	var section: VBoxContainer = null
	var last_kind: String = ""
	for item: Array in wanted:
		if item[0] != last_kind:
			last_kind = item[0]
			section = _add_section(_section_title(item[0]))
		_rows.append(_add_row(section, item[0], item[1]))
	if wanted.is_empty():
		_content.add_child(_empty_label)
	_refresh_texts()
	if grab_focus or not focus_kind.is_empty():
		_restore_focus(focus_kind, focus_id)


func _restore_focus(kind: String, id: String) -> void:
	for row: Dictionary in _rows:
		var exact: Button = row["button"]
		if row["kind"] == kind and row["id"] == id and not exact.disabled:
			exact.grab_focus()
			return
	for row: Dictionary in _rows:
		var button: Button = row["button"]
		if row["kind"] == kind and not button.disabled:
			button.grab_focus()
			return
	_focus_first_enabled()


func _focus_first_enabled() -> void:
	for row: Dictionary in _rows:
		var button: Button = row["button"]
		if not button.disabled:
			button.grab_focus()
			return


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


## Liste değiştiyse yeniden kurar, yoksa yalnızca metin ve düğme durumunu günceller.
func _refresh() -> void:
	if _state() == null:
		return
	if not _same_layout(_wanted()):
		_rebuild(false)
		return
	_refresh_texts()


func _refresh_texts() -> void:
	var state: GameState = _state()
	if state == null:
		return
	_set_text(_money_label, "Para: " + NumberFormat.format_money(state.money))
	for row: Dictionary in _rows:
		_fill_row(state, row)


func _fill_row(state: GameState, row: Dictionary) -> void:
	var kind: String = row["kind"]
	var id: String = row["id"]
	var cost: float = -1.0
	var bought: bool = false
	var name_text: String = ""
	var desc_text: String = ""
	var info_text: String = ""
	match kind:
		KIND_TOOL:
			var next: Dictionary = Cfg.TOOLS[state.tool_level + 1]
			cost = Economy.cost_tool(state)
			name_text = next["name_tr"]
			desc_text = next["desc_tr"]
			info_text = "Taşıma: %s → %s damla" % [NumberFormat.format_int(Economy.tool_capacity(state)), NumberFormat.format_int(next["capacity"])]
		KIND_RATE:
			cost = Economy.cost_rate(state)
			name_text = Cfg.RATE_NAME_TR
			var next_rate: float = Cfg.RATE_LEVELS[state.rate_level + 1]["drops_per_money"]
			desc_text = "%s damla = 1 para  →  %s damla = 1 para" % [NumberFormat.format_int(Economy.drops_per_money(state)), NumberFormat.format_int(next_rate)]
			info_text = "Döktüğün her damla daha çok kazandırır."
		KIND_SOURCE:
			var def: Dictionary = Economy.source_def(id)
			cost = Economy.cost_source(state, id)
			name_text = def["name_tr"]
			desc_text = def["desc_tr"]
			info_text = "%s damla/sn   Sahip: %s" % [NumberFormat.format_money(def["rate"]), NumberFormat.format_int(Economy.source_count(state, id))]
		KIND_LOSS:
			var ldef: Dictionary = Economy.loss_def(id)
			bought = Economy.has_loss_upgrade(state, id)
			cost = Economy.cost_loss(state, id)
			name_text = ldef["name_tr"]
			desc_text = ldef["desc_tr"]
			var points: float = ldef["points"]
			if bought:
				info_text = "Kayıp -%s puan" % NumberFormat.format_int(points)
			else:
				var now: float = Economy.loss_fraction(state) * 100.0
				info_text = "Kayıp %%%s → %%%s" % [NumberFormat.format_int(now), NumberFormat.format_int(maxf(now - points, Cfg.MIN_LOSS_PERCENT))]
	_set_text(row["name"], name_text)
	_set_text(row["desc"], desc_text)
	_set_text(row["info"], info_text)
	_set_text(row["cost"], "" if bought else NumberFormat.format_money(maxf(cost, 0.0)))
	var button: Button = row["button"]
	var can_buy: bool = not bought and cost >= 0.0 and state.money >= cost
	var label: String = "Alındı" if bought else "Al"
	if button.text != label:
		button.text = label
	var disabled: bool = not can_buy
	if button.disabled != disabled:
		button.disabled = disabled
		if disabled and button.has_focus():
			button.release_focus()


# ---------- Satın alma ----------

func _on_buy(kind: String, id: String) -> void:
	if game == null:
		return
	var ok: bool = false
	match kind:
		KIND_TOOL:
			ok = game.call("buy_tool")
		KIND_RATE:
			ok = game.call("buy_rate")
		KIND_SOURCE:
			ok = game.call("buy_source", id)
		KIND_LOSS:
			ok = game.call("buy_loss", id)
	if ok:
		_rebuild(true)
