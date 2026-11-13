extends CanvasLayer
## Dükkân paneli: yalnızca elle tutulan eşyalar (kilidi Geliştirmeler'den açılmış aletler).
## Dış bağlantı: add_child'dan önce `game` ve `player` atanır; açma panel_manager.gd üzerinden.
## E ya da Esc kapatır. Kilidi açılmamış sıradaki alet soluk ve açıklamalı görünür.

const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const PANEL_SIZE: Vector2 = Vector2(760.0, 420.0)
const INFO_WIDTH: float = 190.0
const COST_WIDTH: float = 96.0
const LOCKED_TEXT: String = "Kilitli: Geliştirmeler'den (Tab) aç"
const EMPTY_TEXT: String = "Henüz alınacak bir şey yok. Su dök, para kazan."
const DONE_TEXT: String = "Tüm aletler sende."
const OWNED_TEXT: String = "Alındı"
const FOOT_TEXT: String = "Yükseltmeler için Tab"
const HINT_TEXT: String = "Enter: al    E ya da Esc: kapat"

var game: Node
var player: Node

var _root: Control
var _content: VBoxContainer
var _money_label: Label
var _empty_label: Label
var _tool_row: Dictionary = {} ## alet satırı: row, name, desc, info, cost, button
var _hammer_row: Dictionary = {} ## çekiç satırı (aletlerden bağımsız)
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
	_focus_first_enabled()


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
			and get_viewport().gui_get_focus_owner() == null and _focus_first_enabled():
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
	_tool_row = _build_row(_on_buy_tool)
	_hammer_row = _build_row(_on_buy_hammer)

	var foot: Label = UiTheme.label(FOOT_TEXT, UiTheme.INFO_SIZE, UiTheme.SECTION_COLOR)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(foot)
	var hint: Label = UiTheme.label(HINT_TEXT, UiTheme.HINT_SIZE, UiTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _build_row(on_buy: Callable) -> Dictionary:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiTheme.row_style())
	_content.add_child(row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	line.add_child(texts)
	var name_label: Label = UiTheme.label("", UiTheme.NAME_SIZE, UiTheme.TEXT)
	texts.add_child(name_label)
	var desc_label: Label = UiTheme.label("", UiTheme.DESC_SIZE, UiTheme.TEXT_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 120.0
	texts.add_child(desc_label)

	var info_label: Label = UiTheme.label("", UiTheme.INFO_SIZE, UiTheme.TEXT_DIM)
	info_label.custom_minimum_size.x = INFO_WIDTH
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(info_label)

	var cost_label: Label = UiTheme.label("", UiTheme.COST_SIZE, UiTheme.MONEY_COLOR)
	cost_label.custom_minimum_size.x = COST_WIDTH
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(cost_label)

	var button: Button = UiTheme.buy_button("Al")
	line.add_child(button)
	button.pressed.connect(on_buy)
	return {"row": row, "name": name_label, "desc": desc_label, "info": info_label, "cost": cost_label, "button": button}


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
	var show_tool: bool = has_next and Economy.tool_visible(state)
	var show_hammer: bool = Economy.hammer_shop_visible(state)
	(_tool_row["row"] as Control).visible = show_tool
	(_hammer_row["row"] as Control).visible = show_hammer
	_empty_label.visible = not show_tool and not show_hammer
	_set_text(_empty_label, EMPTY_TEXT if has_next else DONE_TEXT)
	if show_tool:
		var next: Dictionary = Cfg.TOOLS[state.tool_level + 1]
		var unlocked: bool = Economy.next_tool_unlocked(state)
		var cost: float = Economy.cost_tool(state)
		_fill(_tool_row, {
			"name": next["name_tr"],
			"desc": next["desc_tr"] if unlocked else LOCKED_TEXT,
			"info": "Taşıma: %s → %s damla" % [NumberFormat.format_int(Economy.tool_capacity(state)), NumberFormat.format_int(next["capacity"])],
			"cost": NumberFormat.format_money(cost),
			"label": "Al" if unlocked else "Kilitli",
			"enabled": unlocked and state.money >= cost,
			"alpha": 1.0 if unlocked else UiTheme.DISABLED_ALPHA,
		})
	if show_hammer:
		var owned: bool = state.hammer_owned
		var unlocked_h: bool = state.hammer_unlocked
		var cost_h: float = Economy.cost_hammer(state)
		_fill(_hammer_row, {
			"name": BuildCfg.HAMMER_NAME_TR,
			"desc": BuildCfg.HAMMER_DESC_TR if unlocked_h else LOCKED_TEXT,
			"info": "Yapı kurar (Q)",
			"cost": "" if owned else NumberFormat.format_money(cost_h),
			"label": OWNED_TEXT if owned else ("Al" if unlocked_h else "Kilitli"),
			"enabled": not owned and unlocked_h and state.money >= cost_h,
			"alpha": 0.8 if owned else (1.0 if unlocked_h else UiTheme.DISABLED_ALPHA),
		})


## Satırın metinlerini ve düğme durumunu günceller; yalnızca değişeni yazar.
func _fill(row: Dictionary, v: Dictionary) -> void:
	_set_text(row["name"], v["name"])
	_set_text(row["desc"], v["desc"])
	_set_text(row["info"], v["info"])
	_set_text(row["cost"], v["cost"])
	var button: Button = row["button"]
	if button.text != v["label"]:
		button.text = v["label"]
	var panel: Control = row["row"]
	if panel.modulate.a != v["alpha"]:
		panel.modulate.a = v["alpha"]
	var disabled: bool = not v["enabled"]
	if button.disabled != disabled:
		button.disabled = disabled
		if disabled and button.has_focus():
			button.release_focus()
		elif not disabled and _open and get_viewport().gui_get_focus_owner() == null:
			button.grab_focus()


## Etkin ilk düğmeye odaklanır; yoksa false.
func _focus_first_enabled() -> bool:
	for row: Dictionary in [_tool_row, _hammer_row]:
		var button: Button = row["button"]
		if (row["row"] as Control).visible and not button.disabled:
			button.grab_focus()
			return true
	return false


func _on_buy_tool() -> void:
	if game != null and game.call("buy_tool"):
		_refresh()


func _on_buy_hammer() -> void:
	if game != null and game.call("buy_hammer"):
		_refresh()
