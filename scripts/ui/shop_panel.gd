extends CanvasLayer
## Dükkân paneli: yalnızca elle tutulan eşyalar (kilidi Geliştirmeler'den açılmış aletler).
## Dış bağlantı: add_child'dan önce `game` ve `player` atanır; açma panel_manager.gd üzerinden.
## E ya da Esc kapatır. Kilidi açılmamış sıradaki alet soluk ve açıklamalı görünür.

const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const PANEL_SIZE: Vector2 = Vector2(760.0, 360.0)
const INFO_WIDTH: float = 190.0
const COST_WIDTH: float = 96.0
const LOCKED_TEXT: String = "Kilitli: Geliştirmeler'den (Tab) aç"
const EMPTY_TEXT: String = "Henüz alınacak bir şey yok. Su dök, para kazan."
const DONE_TEXT: String = "Tüm aletler sende."
const FOOT_TEXT: String = "Yükseltmeler için Tab"
const HINT_TEXT: String = "Enter: al    E ya da Esc: kapat"

var game: Node
var player: Node

var _root: Control
var _content: VBoxContainer
var _money_label: Label
var _empty_label: Label
var _row: PanelContainer
var _name: Label
var _desc: Label
var _info: Label
var _cost: Label
var _button: Button
var _timer: float = 0.0
var _open: bool = false


func _ready() -> void:
	layer = 20
	_build()
	_root.visible = false
	set_process(false)


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
	_refresh()
	if not _button.disabled:
		_button.grab_focus()


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
			and get_viewport().gui_get_focus_owner() == null and not _button.disabled:
		_button.grab_focus()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < UiTheme.REFRESH_INTERVAL:
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
	dim.color = UiTheme.DIM_COLOR
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
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = UiTheme.label("Dükkân", UiTheme.TITLE_SIZE, UiTheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = UiTheme.label("", UiTheme.MONEY_SIZE, UiTheme.MONEY_COLOR)
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_money_label)
	column.add_child(HSeparator.new())

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	column.add_child(_content)
	_content.add_child(UiTheme.label("Aletler", UiTheme.SECTION_SIZE, UiTheme.SECTION_COLOR))

	_empty_label = UiTheme.label(EMPTY_TEXT, UiTheme.NAME_SIZE, UiTheme.TEXT_DIM)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_empty_label)
	_build_row()

	var foot: Label = UiTheme.label(FOOT_TEXT, UiTheme.INFO_SIZE, UiTheme.SECTION_COLOR)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(foot)
	var hint: Label = UiTheme.label(HINT_TEXT, UiTheme.HINT_SIZE, UiTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _build_row() -> void:
	_row = PanelContainer.new()
	_row.add_theme_stylebox_override("panel", UiTheme.row_style())
	_content.add_child(_row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	_row.add_child(line)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	line.add_child(texts)
	_name = UiTheme.label("", UiTheme.NAME_SIZE, UiTheme.TEXT)
	texts.add_child(_name)
	_desc = UiTheme.label("", UiTheme.DESC_SIZE, UiTheme.TEXT_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 120.0
	texts.add_child(_desc)

	_info = UiTheme.label("", UiTheme.INFO_SIZE, UiTheme.TEXT_DIM)
	_info.custom_minimum_size.x = INFO_WIDTH
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(_info)

	_cost = UiTheme.label("", UiTheme.COST_SIZE, UiTheme.MONEY_COLOR)
	_cost.custom_minimum_size.x = COST_WIDTH
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(_cost)

	_button = UiTheme.buy_button("Al")
	line.add_child(_button)
	_button.pressed.connect(_on_buy)


# ---------- Veri ----------

func _state() -> GameState:
	if game == null:
		return null
	return game.get("state") as GameState


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _refresh() -> void:
	var state: GameState = _state()
	if state == null:
		return
	_set_text(_money_label, "Para: " + NumberFormat.format_money(state.money))
	var has_next: bool = Economy.has_next_tool(state)
	var show_row: bool = has_next and Economy.tool_visible(state)
	_row.visible = show_row
	_empty_label.visible = not show_row
	_set_text(_empty_label, EMPTY_TEXT if has_next else DONE_TEXT)
	if not show_row:
		return
	var next: Dictionary = Cfg.TOOLS[state.tool_level + 1]
	var unlocked: bool = Economy.next_tool_unlocked(state)
	var cost: float = Economy.cost_tool(state)
	_set_text(_name, next["name_tr"])
	_set_text(_desc, next["desc_tr"] if unlocked else LOCKED_TEXT)
	_set_text(_info, "Taşıma: %s → %s damla" % [NumberFormat.format_int(Economy.tool_capacity(state)), NumberFormat.format_int(next["capacity"])])
	_set_text(_cost, NumberFormat.format_money(cost))
	var can_buy: bool = unlocked and state.money >= cost
	var label: String = "Al" if unlocked else "Kilitli"
	if _button.text != label:
		_button.text = label
	_row.modulate.a = 1.0 if unlocked else UiTheme.DISABLED_ALPHA
	var disabled: bool = not can_buy
	if _button.disabled != disabled:
		_button.disabled = disabled
		if disabled and _button.has_focus():
			_button.release_focus()
		elif not disabled and _open and get_viewport().gui_get_focus_owner() == null:
			_button.grab_focus()


func _on_buy() -> void:
	if game != null and game.call("buy_tool"):
		_refresh()
