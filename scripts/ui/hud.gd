extends CanvasLayer
## Oyun ici gostergeler: para, asama, baglam ipucu, tasinan su ve "+N para" yazilari.
## Dis baglanti: add_child'dan once hud.set("game", game).

const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")

const UPDATE_INTERVAL: float = 0.2
const MARGIN: float = 24.0

const TEXT_COLOR: Color = Color(0.97, 0.97, 0.94)
const TEXT_DIM_COLOR: Color = Color(0.86, 0.88, 0.88)
const OUTLINE_COLOR: Color = Color(0.05, 0.08, 0.12, 0.9)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const COIN_COLOR: Color = Color(1.0, 0.82, 0.30)
const COIN_RIM_COLOR: Color = Color(0.70, 0.50, 0.12)
const BAR_BACK_COLOR: Color = Color(0.05, 0.08, 0.12, 0.65)
const STAGE_BAR_COLOR: Color = Color(0.55, 0.85, 0.95)
const WATER_BAR_COLOR: Color = Color(0.45, 0.72, 0.90)
const WATER_FULL_COLOR: Color = Color(1.0, 0.82, 0.30)
const GAIN_COLOR: Color = Color(1.0, 0.90, 0.45)

const MONEY_FONT_SIZE: int = 40
const INFO_FONT_SIZE: int = 18
const STAGE_FONT_SIZE: int = 26
const BANNER_TITLE_SIZE: int = 44
const BANNER_TEXT_SIZE: int = 22
const PROMPT_FONT_SIZE: int = 24
const CARRY_FONT_SIZE: int = 22
const POPUP_FONT_SIZE: int = 34
const OUTLINE_SIZE: int = 6

const COIN_SIZE: float = 30.0
const STAGE_BAR_SIZE: Vector2 = Vector2(220.0, 8.0)
const WATER_BAR_SIZE: Vector2 = Vector2(200.0, 10.0)
const STAGE_BOX_TOP: float = 100.0 ## F3 yazisinin (sol ust, ~3 satir) altinda kalir
const PROMPT_ANCHOR_Y: float = 0.60 ## Nisangahin biraz alti, tus ipucunun ustu
const BANNER_TOP: float = 70.0
const BANNER_HOLD_SECONDS: float = 3.5
const BANNER_FADE_SECONDS: float = 1.5
const UPGRADES_HINT: String = "Tab: geliştirmeleri aç"
const UPGRADES_HINT_MONEY: float = 5.0 ## Para ilk kez bunu geçince bir kez gösterilir
const POPUP_POOL_SIZE: int = 4
const POPUP_ANCHOR_Y: float = 0.40
const POPUP_HEIGHT: float = 48.0
const POPUP_RISE: float = 70.0
const POPUP_SECONDS: float = 1.4

var game: Node

var _timer: float = 0.0
var _money_label: Label
var _drops_label: Label
var _income_label: Label
var _stage_label: Label
var _stage_bar: ProgressBar
var _prompt_label: Label
var _tool_label: Label
var _carry_label: Label
var _water_bar: ProgressBar
var _water_fill: StyleBoxFlat
var _banner_box: VBoxContainer
var _banner_title: Label
var _banner_text: Label
var _banner_tween: Tween
var _popups: Array[Label] = []
var _popup_tweens: Array[Tween] = []
var _popup_next: int = 0
var _water_full: bool = false
var _prev_money: float = 0.0
var _hint_shown: bool = false


func _ready() -> void:
	layer = 5
	_build_money_box()
	_build_stage_box()
	_build_banner()
	_build_prompt()
	_build_carry_box()
	_build_popups()
	if game != null:
		if game.has_signal("poured"):
			game.connect("poured", _on_poured)
		if game.has_signal("purchased"):
			game.connect("purchased", _on_purchased)
		if game.has_signal("stage_changed"):
			game.connect("stage_changed", _on_stage_changed)
		if game.has_signal("prompt_changed"):
			game.connect("prompt_changed", _on_prompt_changed)
	var start_state: GameState = _get_state()
	if start_state != null:
		_prev_money = start_state.money
		_hint_shown = start_state.money > UPGRADES_HINT_MONEY
	_refresh()
	_apply_prompt(_read_prompt())


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_refresh()


# ---------- Kurulum ----------

func _make_label(font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _make_bar(size: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = size
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	var back := StyleBoxFlat.new()
	back.bg_color = BAR_BACK_COLOR
	back.set_corner_radius_all(int(size.y * 0.5))
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(int(size.y * 0.5))
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_box(anchor_x: float, anchor_y: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = anchor_x
	box.anchor_right = anchor_x
	box.anchor_top = anchor_y
	box.anchor_bottom = anchor_y
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	return box


func _build_money_box() -> void:
	var box: VBoxContainer = _make_box(1.0, 0.0)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -MARGIN
	box.offset_right = -MARGIN
	box.offset_top = MARGIN
	box.offset_bottom = MARGIN

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	_money_label = _make_label(MONEY_FONT_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(_money_label)

	var coin := Panel.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.custom_minimum_size = Vector2(COIN_SIZE, COIN_SIZE)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin_style := StyleBoxFlat.new()
	coin_style.bg_color = COIN_COLOR
	coin_style.border_color = COIN_RIM_COLOR
	coin_style.set_border_width_all(3)
	coin_style.set_corner_radius_all(int(COIN_SIZE))
	coin.add_theme_stylebox_override("panel", coin_style)
	row.add_child(coin)

	_drops_label = _make_label(INFO_FONT_SIZE, TEXT_DIM_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_drops_label)
	_income_label = _make_label(INFO_FONT_SIZE, TEXT_DIM_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_income_label)


func _build_stage_box() -> void:
	var box: VBoxContainer = _make_box(0.0, 0.0)
	box.offset_left = MARGIN
	box.offset_right = MARGIN
	box.offset_top = STAGE_BOX_TOP
	box.offset_bottom = STAGE_BOX_TOP
	_stage_label = _make_label(STAGE_FONT_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_stage_label)
	_stage_bar = _make_bar(STAGE_BAR_SIZE, STAGE_BAR_COLOR)
	box.add_child(_stage_bar)


func _build_banner() -> void:
	_banner_box = _make_box(0.5, 0.0)
	_banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_box.offset_top = BANNER_TOP
	_banner_box.offset_bottom = BANNER_TOP
	_banner_title = _make_label(BANNER_TITLE_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_box.add_child(_banner_title)
	_banner_text = _make_label(BANNER_TEXT_SIZE, TEXT_DIM_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_box.add_child(_banner_text)
	_banner_box.modulate.a = 0.0


func _build_prompt() -> void:
	_prompt_label = _make_label(PROMPT_FONT_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = PROMPT_ANCHOR_Y
	_prompt_label.anchor_bottom = PROMPT_ANCHOR_Y
	_prompt_label.grow_vertical = Control.GROW_DIRECTION_END
	_prompt_label.visible = false
	add_child(_prompt_label)


func _build_carry_box() -> void:
	var box: VBoxContainer = _make_box(1.0, 1.0)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -MARGIN
	box.offset_right = -MARGIN
	box.offset_top = -MARGIN
	box.offset_bottom = -MARGIN
	_tool_label = _make_label(INFO_FONT_SIZE, TEXT_DIM_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_tool_label)
	_carry_label = _make_label(CARRY_FONT_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_carry_label)
	_water_bar = _make_bar(WATER_BAR_SIZE, WATER_BAR_COLOR)
	_water_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_water_fill = _water_bar.get_theme_stylebox("fill") as StyleBoxFlat
	box.add_child(_water_bar)


func _build_popups() -> void:
	for i: int in POPUP_POOL_SIZE:
		var label: Label = _make_label(POPUP_FONT_SIZE, GAIN_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
		label.anchor_left = 0.0
		label.anchor_right = 1.0
		label.anchor_top = POPUP_ANCHOR_Y
		label.anchor_bottom = POPUP_ANCHOR_Y
		label.offset_top = 0.0
		label.offset_bottom = POPUP_HEIGHT
		label.modulate.a = 0.0
		label.visible = false
		add_child(label)
		_popups.append(label)
		_popup_tweens.append(null)


# ---------- Veri okuma ----------

func _get_state() -> GameState:
	if game == null:
		return null
	return game.get("state") as GameState


func _read_prompt() -> String:
	if game == null:
		return ""
	var value: Variant = game.get("prompt_text")
	return value if value is String else ""


# ---------- Guncelleme ----------

func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _refresh() -> void:
	var state: GameState = _get_state()
	if state == null:
		_set_text(_money_label, "")
		_set_text(_drops_label, "")
		_set_text(_income_label, "")
		_set_text(_stage_label, "")
		_set_text(_tool_label, "")
		_set_text(_carry_label, "")
		_stage_bar.value = 0.0
		_water_bar.value = 0.0
		return
	_set_text(_money_label, NumberFormat.format_money(state.money))
	if not _hint_shown and state.money > UPGRADES_HINT_MONEY and _prev_money <= UPGRADES_HINT_MONEY:
		_hint_shown = true
		_show_banner("", UPGRADES_HINT)
	_prev_money = state.money
	_set_text(_drops_label, "Damla: " + NumberFormat.format_int(state.total_drops))
	var income: float = 0.0
	if game.has_method("income_per_minute"):
		income = game.call("income_per_minute")
	_set_text(_income_label, "dk başına: " + NumberFormat.format_money(income))

	_set_text(_stage_label, String(Economy.stage_def(state)["name_tr"]))
	var progress: float = Economy.stage_progress(state)
	if not is_equal_approx(_stage_bar.value, progress):
		_stage_bar.value = progress

	var capacity: float = Economy.tool_capacity(state)
	_set_text(_tool_label, Economy.tool_name(state))
	_set_text(_carry_label, "%s / %s" % [NumberFormat.format_int(state.carried), NumberFormat.format_int(capacity)])
	var ratio: float = clampf(state.carried / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0
	if not is_equal_approx(_water_bar.value, ratio):
		_water_bar.value = ratio
	var full: bool = capacity > 0.0 and state.carried >= capacity - 0.001
	if full != _water_full:
		_water_full = full
		_water_fill.bg_color = WATER_FULL_COLOR if full else WATER_BAR_COLOR


func _apply_prompt(text: String) -> void:
	var show_it: bool = not text.is_empty()
	if show_it:
		_set_text(_prompt_label, text)
	if _prompt_label.visible != show_it:
		_prompt_label.visible = show_it


# ---------- Sinyaller ----------

func _on_prompt_changed(text: String) -> void:
	_apply_prompt(text)


func _on_purchased(_kind: String, _id: String) -> void:
	_refresh()


func _on_poured(_drops: float, money: float) -> void:
	_refresh()
	if not (money > 0.0) or is_inf(money):
		return
	var text: String
	if money < 1.0:
		# Yuvarlayinca 0 olacak kazanc: iki ondalikla goster.
		text = "+%s para" % String.num(money, 2).replace(".", ",")
	else:
		text = "+%s para" % NumberFormat.format_money(money)
	_show_popup(text)


func _show_popup(text: String) -> void:
	var index: int = _popup_next
	_popup_next = (_popup_next + 1) % POPUP_POOL_SIZE
	var label: Label = _popups[index]
	var old: Tween = _popup_tweens[index]
	if old != null and old.is_valid():
		old.kill()
	var base_y: float = get_viewport().get_visible_rect().size.y * POPUP_ANCHOR_Y
	label.text = text
	label.position.y = base_y
	label.modulate.a = 1.0
	label.visible = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", base_y - POPUP_RISE, POPUP_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, POPUP_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.hide)
	_popup_tweens[index] = tween


func _on_stage_changed(index: int) -> void:
	if index < 0 or index >= Cfg.STAGES.size():
		return
	var def: Dictionary = Cfg.STAGES[index]
	_show_banner(String(def["name_tr"]), String(def["text_tr"]))
	_refresh()


func _show_banner(title: String, text: String) -> void:
	_banner_title.text = title
	_banner_title.visible = not title.is_empty()
	_banner_text.text = text
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_box.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(BANNER_HOLD_SECONDS)
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, BANNER_FADE_SECONDS)
