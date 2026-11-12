extends CanvasLayer
## Geliştirmeler ekranı (Tab): alet kilitleri ve kapasite, su değeri, pasif kaynaklar, kayıp azaltma, kanal.
## Dış bağlantı: add_child'dan önce `game` ve `player` atanır; Tab ile açma/kapama panel_manager.gd'de, Esc burada.
## Klavye: sol/sağ sütun, yukarı/aşağı satır, Enter seç. Yalnızca Economy'nin "görünür" dediği öğeler listelenir.
## Düğümler kodla kurulur; yenileme yalnızca panel açıkken ve aralıklarla çalışır.

const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const CanalConfig = preload("res://scripts/core/canal_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const K_TOOL: String = "tool"
const K_RATE: String = "rate"
const K_SOURCE: String = "source"
const K_LOSS: String = "loss"
const K_CANAL: String = "canal_unlock"
const K_SPRING: String = "spring"
const K_WIDTH: String = "width"
const K_LINING: String = "lining"

## arg: --open-upgrades=<arg> için kısa ad.
const SECTIONS: Array[Dictionary] = [
	{"id": "tools", "arg": "aletler", "name_tr": "Aletler"},
	{"id": "rate", "arg": "su", "name_tr": "Su değeri"},
	{"id": "sources", "arg": "kaynaklar", "name_tr": "Kaynaklar"},
	{"id": "loss", "arg": "kayip", "name_tr": "Kayıp azaltma"},
	{"id": "canal", "arg": "kanal", "name_tr": "Kanal"},
]
const CANAL_SECTION: int = 4

const MARGIN_X: float = 48.0
const MARGIN_Y: float = 28.0
const SIDE_WIDTH: float = 230.0
const INFO_WIDTH: float = 230.0
const COST_WIDTH: float = 100.0
const DONE_ALPHA: float = 0.8
const EMPTY_TEXT: String = "Burada henüz bir şey yok. Su dök, para kazan."
const HINT_TEXT: String = "Sol / sağ: sütun    Yukarı / aşağı: seç    Enter: al    Tab ya da Esc: kapat"
const ACT_UNLOCK: String = "Kilidi aç"
const ACT_UPGRADE: String = "Yükselt"
const ACT_BUY: String = "Al"
const ACT_OPEN: String = "Aç"
const ACT_DONE: String = "Tamamlandı"
const ACT_SHOP: String = "Dükkânda"

var game: Node
var player: Node

var _root: Control
var _money_label: Label
var _title_label: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _empty_label: Label
var _side_buttons: Array[Button] = []
var _rows: Array[Dictionary] = []
var _section: int = 0
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
	_update_sections()
	_rebuild(false)
	_side_buttons[_section].grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	set_process(false)
	if player != null:
		player.set("input_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Ekran görüntüsü argümanı için: bölümü kısa adıyla seçer ("aletler", "su", "kaynaklar", "kayip", "kanal").
func open_section(arg: String) -> void:
	for i: int in SECTIONS.size():
		if SECTIONS[i]["arg"] == arg:
			_section = i
	open()


func _input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var on_side: bool = focused != null and _side_buttons.has(focused)
	var on_row: bool = focused != null and _row_index(focused) >= 0
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var step: int = 1 if event.is_action_pressed("ui_down") else -1
		if on_side:
			_move_focus_side(step)
		elif on_row:
			_move_focus_row(step)
		else:
			_focus_side()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		if on_side:
			_focus_first_row()
		elif focused == null:
			_focus_side()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		if on_row:
			_focus_side()
		elif focused == null:
			_focus_side()
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
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MARGIN_X
	panel.offset_right = -MARGIN_X
	panel.offset_top = MARGIN_Y
	panel.offset_bottom = -MARGIN_Y
	var panel_style: StyleBoxFlat = UiTheme.panel_style()
	panel_style.bg_color.a = 1.0 # tam ekrana yakın: arkadaki HUD yazıları sızmasın
	panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = UiTheme.label("Geliştirmeler", UiTheme.TITLE_SIZE, UiTheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = UiTheme.label("", UiTheme.MONEY_SIZE, UiTheme.MONEY_COLOR)
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_money_label)
	column.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	for i: int in SECTIONS.size():
		var b: Button = UiTheme.side_button(String(SECTIONS[i]["name_tr"]))
		b.toggle_mode = true
		b.focus_entered.connect(_on_side_focus.bind(i))
		b.pressed.connect(_on_side_pressed.bind(i))
		side.add_child(b)
		_side_buttons.append(b)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_title_label = UiTheme.label("", UiTheme.SECTION_SIZE, UiTheme.SECTION_COLOR)
	right.add_child(_title_label)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	right.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)

	_empty_label = UiTheme.label(EMPTY_TEXT, UiTheme.NAME_SIZE, UiTheme.TEXT_DIM)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hint: Label = UiTheme.label(HINT_TEXT, UiTheme.HINT_SIZE, UiTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _add_row(kind: String, id: String) -> Dictionary:
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

	var button: Button = UiTheme.buy_button(ACT_BUY)
	line.add_child(button)
	button.pressed.connect(_on_press.bind(kind, id))
	return {
		"kind": kind, "id": id, "row": row, "name": name_label, "desc": desc_label,
		"info": info_label, "cost": cost_label, "button": button,
	}


# ---------- Veri ----------

func _state() -> GameState:
	if game == null:
		return null
	return game.get("state") as GameState


func _canal() -> Object:
	if game == null:
		return null
	return game.get("canal") as Object


## Bölümün görünür satırları: [[tür, id], ...]
func _wanted(section: int) -> Array:
	var out: Array = []
	var state: GameState = _state()
	if state == null:
		return out
	match section:
		0:
			for i: int in Cfg.TOOLS.size():
				if Economy.tool_row_visible(state, i):
					out.append([K_TOOL, String(Cfg.TOOLS[i]["id"])])
		1:
			if Economy.rate_row_visible(state):
				out.append([K_RATE, "rate"])
		2:
			for def: Dictionary in Cfg.SOURCES:
				if Economy.source_row_visible(state, def["id"]):
					out.append([K_SOURCE, String(def["id"])])
		3:
			for def: Dictionary in Cfg.LOSS_UPGRADES:
				if Economy.has_loss_upgrade(state, def["id"]) or Economy.loss_visible(state, def["id"]):
					out.append([K_LOSS, String(def["id"])])
		4:
			_wanted_canal(state, out)
	return out


func _wanted_canal(state: GameState, out: Array) -> void:
	var canal: Object = _canal()
	if canal == null or not Economy.canal_section_visible(state):
		return
	if not state.canal_unlocked:
		out.append([K_CANAL, "canal"])
		return
	for id: String in CanalConfig.SPRING_IDS:
		var cost: int = canal.call("spring_cost", id)
		if canal.call("is_spring_open", id) or Economy.is_visible(state, float(cost)):
			out.append([K_SPRING, id])
	if int(canal.get("width_level")) > 0 or Economy.is_visible(state, float(canal.call("width_cost"))):
		out.append([K_WIDTH, "width"])
	if int(canal.get("lining_level")) > 0 or Economy.is_visible(state, float(canal.call("lining_cost"))):
		out.append([K_LINING, "lining"])


func _same_layout(wanted: Array) -> bool:
	if wanted.size() != _rows.size():
		return false
	for i: int in wanted.size():
		if _rows[i]["kind"] != wanted[i][0] or _rows[i]["id"] != wanted[i][1]:
			return false
	return true


## Sol sütun: boş bölümler soluk ve seçilemez, kanal kilit koşulu sağlanana kadar gizli.
func _update_sections() -> void:
	var state: GameState = _state()
	for i: int in SECTIONS.size():
		var button: Button = _side_buttons[i]
		var has_items: bool = not _wanted(i).is_empty()
		if i == CANAL_SECTION:
			var shown: bool = state != null and Economy.canal_section_visible(state)
			if button.visible != shown:
				button.visible = shown
		if button.disabled == has_items:
			button.disabled = not has_items
			if not has_items and button.has_focus():
				button.release_focus()
		button.modulate.a = 1.0 if has_items else UiTheme.DISABLED_ALPHA
	if _wanted(_section).is_empty():
		for i: int in SECTIONS.size():
			if not _side_buttons[i].disabled and _side_buttons[i].visible:
				_section = i
				break
	for i: int in SECTIONS.size():
		_side_buttons[i].set_pressed_no_signal(i == _section)


func _rebuild(restore_focus: bool) -> void:
	var focus_kind: String = ""
	var focus_id: String = ""
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_index: int = _row_index(focused)
	if focus_index >= 0:
		focus_kind = _rows[focus_index]["kind"]
		focus_id = _rows[focus_index]["id"]
	for child: Node in _content.get_children():
		_content.remove_child(child)
		if child != _empty_label:
			child.queue_free()
	_rows.clear()
	var wanted: Array = _wanted(_section)
	for item: Array in wanted:
		_rows.append(_add_row(item[0], item[1]))
	if wanted.is_empty():
		_content.add_child(_empty_label)
	_title_label.text = String(SECTIONS[_section]["name_tr"])
	_refresh_texts()
	if restore_focus or not focus_kind.is_empty():
		_restore_row_focus(focus_kind, focus_id)


func _restore_row_focus(kind: String, id: String) -> void:
	for row: Dictionary in _rows:
		var exact: Button = row["button"]
		if row["kind"] == kind and row["id"] == id and not exact.disabled:
			exact.grab_focus()
			return
	if not _focus_first_row():
		_focus_side()


func _row_index(control: Control) -> int:
	if control == null:
		return -1
	for i: int in _rows.size():
		if _rows[i]["button"] == control:
			return i
	return -1


func _focus_side() -> void:
	_side_buttons[_section].grab_focus()


func _focus_first_row() -> bool:
	for row: Dictionary in _rows:
		var button: Button = row["button"]
		if not button.disabled:
			button.grab_focus()
			return true
	return false


func _move_focus_row(step: int) -> void:
	var index: int = _row_index(get_viewport().gui_get_focus_owner()) + step
	while index >= 0 and index < _rows.size():
		var button: Button = _rows[index]["button"]
		if not button.disabled:
			button.grab_focus()
			return
		index += step


func _move_focus_side(step: int) -> void:
	var index: int = _side_buttons.find(get_viewport().gui_get_focus_owner()) + step
	while index >= 0 and index < _side_buttons.size():
		var button: Button = _side_buttons[index]
		if not button.disabled and button.visible:
			button.grab_focus()
			return
		index += step


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _refresh() -> void:
	if _state() == null:
		return
	_update_sections()
	if not _same_layout(_wanted(_section)):
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


## Satırın metinlerini ve düğme durumunu günceller.
func _fill_row(state: GameState, row: Dictionary) -> void:
	var d: Dictionary = _describe(state, row["kind"], row["id"])
	var cost: float = d["cost"]
	var action: String = d["action"]
	var done: bool = action == ACT_DONE
	var can: bool = d["actionable"] and cost >= 0.0 and state.money >= cost
	_set_text(row["name"], d["name"])
	_set_text(row["desc"], d["desc"])
	_set_text(row["info"], d["info"])
	_set_text(row["cost"], NumberFormat.format_money(cost) if cost >= 0.0 else "")
	var button: Button = row["button"]
	if button.text != action:
		button.text = action
	var panel: Control = row["row"]
	var alpha: float = 1.0
	if done:
		alpha = DONE_ALPHA
	elif not can:
		alpha = UiTheme.DISABLED_ALPHA
	if panel.modulate.a != alpha:
		panel.modulate.a = alpha
	var disabled: bool = not can
	if button.disabled != disabled:
		button.disabled = disabled
		if disabled and button.has_focus():
			button.release_focus()


## name, desc, info, cost (-1: yok), action (düğme yazısı), actionable (düğme etkin olabilir mi).
func _describe(state: GameState, kind: String, id: String) -> Dictionary:
	var d: Dictionary = {"name": "", "desc": "", "info": "", "cost": -1.0, "action": ACT_BUY, "actionable": true}
	match kind:
		K_TOOL:
			_describe_tool(state, id, d)
		K_RATE:
			d["name"] = Cfg.RATE_NAME_TR
			d["info"] = "Döktüğün her damla\ndaha çok kazandırır."
			var now: String = NumberFormat.format_int(Economy.drops_per_money(state))
			if Economy.has_next_rate(state):
				var next_rate: float = Cfg.RATE_LEVELS[state.rate_level + 1]["drops_per_money"]
				d["desc"] = "%s damla = 1 para  →  %s damla = 1 para" % [now, NumberFormat.format_int(next_rate)]
				d["cost"] = Economy.cost_rate(state)
				d["action"] = ACT_UPGRADE
			else:
				d["desc"] = "%s damla = 1 para" % now
				d["action"] = ACT_DONE
		K_SOURCE:
			_describe_source(state, id, d)
		K_LOSS:
			var ldef: Dictionary = Economy.loss_def(id)
			d["name"] = ldef["name_tr"]
			d["desc"] = ldef["desc_tr"]
			var points: float = ldef["points"]
			if Economy.has_loss_upgrade(state, id):
				d["info"] = "Kayıp -%s puan" % NumberFormat.format_int(points)
				d["action"] = ACT_DONE
			else:
				var pct: float = Economy.loss_fraction(state) * 100.0
				d["info"] = "Kayıp %%%s → %%%s" % [NumberFormat.format_int(pct), NumberFormat.format_int(maxf(pct - points, Cfg.MIN_LOSS_PERCENT))]
				d["cost"] = Economy.cost_loss(state, id)
		_:
			_describe_canal(state, kind, id, d)
	return d


func _describe_tool(state: GameState, id: String, d: Dictionary) -> void:
	var index: int = Economy.tool_index(id)
	var def: Dictionary = Cfg.TOOLS[index]
	d["name"] = def["name_tr"]
	d["desc"] = def["desc_tr"]
	var level: int = Economy.tool_upgrade_level(state, index)
	var cap_now: String = NumberFormat.format_int(Economy.tool_capacity_at(state, index))
	if Economy.is_tool_owned(state, index):
		var cost: float = Economy.cost_tool_upgrade(state, index)
		var level_text: String = "Seviye %d / %d" % [level, Cfg.TOOL_UPGRADE_MAX_LEVEL]
		if cost < 0.0:
			d["info"] = "Kapasite: %s damla\n%s" % [cap_now, level_text]
			d["action"] = ACT_DONE
		else:
			var cap_next: String = NumberFormat.format_int(Economy.tool_capacity_for(index, level + 1))
			d["info"] = "Kapasite: %s → %s damla\n%s" % [cap_now, cap_next, level_text]
			d["cost"] = cost
			d["action"] = ACT_UPGRADE
	elif Economy.is_tool_unlocked(state, index):
		d["info"] = "Kapasite: %s damla\nDükkândan satın al (E)" % cap_now
		d["action"] = ACT_SHOP
		d["actionable"] = false
	else:
		d["info"] = "Kapasite: %s damla\nKilitli" % cap_now
		d["cost"] = Economy.cost_tool_unlock(state)
		d["action"] = ACT_UNLOCK


func _describe_source(state: GameState, id: String, d: Dictionary) -> void:
	var def: Dictionary = Economy.source_def(id)
	d["name"] = def["name_tr"]
	d["desc"] = def["desc_tr"]
	var rate: String = NumberFormat.format_money(def["rate"])
	if Economy.source_unlocked(state, id):
		var cost: float = Economy.cost_source(state, id)
		d["info"] = "%s damla/sn\nSahip: %s" % [rate, NumberFormat.format_int(Economy.source_count(state, id))]
		d["cost"] = cost
		d["action"] = ACT_BUY if cost >= 0.0 else ACT_DONE
	else:
		d["info"] = "%s damla/sn\nKilitli" % rate
		d["cost"] = Economy.cost_source_unlock(state, id)
		d["action"] = ACT_UNLOCK


func _describe_canal(state: GameState, kind: String, id: String, d: Dictionary) -> void:
	var canal: Object = _canal()
	match kind:
		K_CANAL:
			d["name"] = Cfg.CANAL_NAME_TR
			d["desc"] = Cfg.CANAL_DESC_TR
			d["info"] = "Pınar ve kanal\nyükseltmeleri açılır."
			d["cost"] = Economy.cost_canal_unlock(state)
			d["action"] = ACT_UNLOCK
		K_SPRING:
			d["name"] = "%s %s" % [Cfg.CANAL_SPRING_NAME_TR, id]
			d["desc"] = Cfg.CANAL_SPRING_DESC_TR
			var flow: String = NumberFormat.format_int(float(CanalConfig.SPRINGS[id]["flow"]))
			if canal.call("is_spring_open", id):
				d["info"] = "Akış: %s damla/sn\nAçık" % flow
				d["action"] = ACT_DONE
			else:
				d["info"] = "Akış: %s damla/sn" % flow
				d["cost"] = float(canal.call("spring_cost", id))
				d["action"] = ACT_OPEN
		K_WIDTH:
			d["name"] = Cfg.CANAL_WIDTH_NAME_TR
			d["desc"] = Cfg.CANAL_WIDTH_DESC_TR
			_describe_canal_level(canal, "width_level", "width_cost", CanalConfig.WIDTH_MAX_LEVEL, d)
		K_LINING:
			d["name"] = Cfg.CANAL_LINING_NAME_TR
			d["desc"] = Cfg.CANAL_LINING_DESC_TR
			_describe_canal_level(canal, "lining_level", "lining_cost", CanalConfig.LINING_MAX_LEVEL, d)


func _describe_canal_level(canal: Object, level_prop: String, cost_func: String, max_level: int, d: Dictionary) -> void:
	var level: int = canal.get(level_prop)
	var cost: float = float(canal.call(cost_func))
	d["info"] = "Seviye %d / %d" % [level, max_level]
	if cost < 0.0:
		d["action"] = ACT_DONE
	else:
		d["cost"] = cost
		d["action"] = ACT_UPGRADE


# ---------- Olaylar ----------

func _on_side_focus(index: int) -> void:
	_select_section(index)


func _on_side_pressed(index: int) -> void:
	_select_section(index)


func _select_section(index: int) -> void:
	if index == _section and not _rows.is_empty():
		_side_buttons[index].set_pressed_no_signal(true)
		return
	_section = index
	for i: int in _side_buttons.size():
		_side_buttons[i].set_pressed_no_signal(i == index)
	_rebuild(false)


func _on_press(kind: String, id: String) -> void:
	if game == null:
		return
	var ok: bool = false
	var state: GameState = _state()
	match kind:
		K_TOOL:
			var index: int = Economy.tool_index(id)
			if not Economy.is_tool_unlocked(state, index):
				ok = game.call("unlock_tool")
			elif Economy.is_tool_owned(state, index):
				ok = game.call("upgrade_tool", id)
		K_RATE:
			ok = game.call("buy_rate")
		K_SOURCE:
			if Economy.source_unlocked(state, id):
				ok = game.call("buy_source", id)
			else:
				ok = game.call("unlock_source", id)
		K_LOSS:
			ok = game.call("buy_loss", id)
		K_CANAL:
			ok = game.call("unlock_canal")
		K_SPRING:
			ok = game.call("open_spring", id)
		K_WIDTH:
			ok = game.call("upgrade_canal_width")
		K_LINING:
			ok = game.call("upgrade_canal_lining")
	if ok:
		_update_sections()
		_rebuild(true)
