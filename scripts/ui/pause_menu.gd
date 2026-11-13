extends CanvasLayer
## Duraklatma menüsü (Esc): devam et, grafik kalitesi, FPS göstergesi, oyundan çık.
## Oyun mantığı (pasif gelir) akmaya devam eder; yalnızca oyuncu girdisi kapanır, fare serbest kalır.
## Dış bağlantı: add_child'dan önce `game`, `player`, `settings` atanır. Dükkân paneli açıkken
## Esc önce onu kapatır (panel olayı tüketir), menü açılmaz.
## Düğümler kodla kurulur. Klavye: yukarı/aşağı satır, sol/sağ kalite, Enter seç.

const GraphicsConfig = preload("res://scripts/core/graphics_config.gd")
const AudioConfig = preload("res://scripts/core/audio_config.gd")

const FPS_TEXT_ON: String = "FPS göster: Açık"
const FPS_TEXT_OFF: String = "FPS göster: Kapalı"
const SOUND_TEXT_ON: String = "Ses: Açık"
const SOUND_TEXT_OFF: String = "Ses: Kapalı"
const VOLUME_TEXT: String = "Ses düzeyi: %%%d    (◄ ►)"
const PANEL_WIDTH: float = 460.0
const PANEL_PAD: float = 24.0
const TITLE_SIZE: int = 32
const LABEL_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 20
const HINT_SIZE: int = 14
const ROW_HEIGHT: float = 46.0
const SEPARATION: int = 14

const DIM_COLOR := Color(0.0, 0.02, 0.04, 0.55)
const PANEL_BG := Color(0.05, 0.08, 0.11, 0.96)
const PANEL_BORDER := Color(0.45, 0.70, 0.85, 0.8)
const TEXT := Color(0.97, 0.97, 0.94)
const TEXT_DIM := Color(0.74, 0.80, 0.82)
const BTN_BG := Color(0.16, 0.22, 0.27)
const BTN_HOVER := Color(0.22, 0.31, 0.38)
const BTN_ON := Color(0.18, 0.55, 0.38)
const BTN_ON_HOVER := Color(0.24, 0.68, 0.46)
const QUIT_BG := Color(0.45, 0.18, 0.16)
const QUIT_HOVER := Color(0.60, 0.24, 0.20)
const FOCUS_COLOR := Color(1.0, 0.93, 0.55)
const CLEAR := Color(0.0, 0.0, 0.0, 0.0)

var game: Node
var player: Node
var settings: Node

var _root: Control
var _resume: Button
var _quality_buttons: Array[Button] = []
var _fps_toggle: Button
var _sound_toggle: Button
var _volume_button: Button
var _quit: Button
var _open: bool = false


func _ready() -> void:
	layer = 30
	_build()
	_root.visible = false
	if settings != null:
		settings.connect("quality_changed", _on_quality_changed)
		settings.connect("show_fps_changed", _on_show_fps_changed)
		_on_quality_changed(int(settings.get("level")))
		_on_show_fps_changed(bool(settings.get("show_fps")))
		settings.connect("sound_changed", _on_sound_changed)
		_on_sound_changed(bool(settings.get("sound_on")), float(settings.get("volume")))


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		player.set("input_enabled", false)
	_resume.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if player != null:
		player.set("input_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if _open:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


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
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
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
	column.add_theme_constant_override("separation", SEPARATION)
	panel.add_child(column)

	var title: Label = _label("Duraklatıldı", TITLE_SIZE, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(HSeparator.new())

	_resume = _make_button("Devam et", BTN_BG, BTN_HOVER)
	_resume.pressed.connect(close)
	column.add_child(_resume)

	column.add_child(_label("Grafik kalitesi", LABEL_SIZE, TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var group := ButtonGroup.new()
	for level: int in range(GraphicsConfig.LEVEL_COUNT):
		var b: Button = _make_button(GraphicsConfig.LEVEL_NAMES[level], BTN_BG, BTN_HOVER)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_quality_pressed.bind(level))
		row.add_child(b)
		_quality_buttons.append(b)

	_fps_toggle = _make_button("", BTN_BG, BTN_HOVER)
	_fps_toggle.toggle_mode = true
	_fps_toggle.toggled.connect(_on_fps_toggled)
	column.add_child(_fps_toggle)

	_sound_toggle = _make_button("", BTN_BG, BTN_HOVER)
	_sound_toggle.toggle_mode = true
	_sound_toggle.toggled.connect(_on_sound_toggled)
	column.add_child(_sound_toggle)

	_volume_button = _make_button("", BTN_BG, BTN_HOVER)
	_volume_button.gui_input.connect(_on_volume_input)
	column.add_child(_volume_button)

	_quit = _make_button("Oyundan çık", QUIT_BG, QUIT_HOVER)
	_quit.pressed.connect(_on_quit)
	column.add_child(_quit)

	var hint: Label = _label("Yukarı / aşağı: satır    Sol / sağ: kalite, ses    Enter: seç    Esc: devam", HINT_SIZE, TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6.0)
	return style


func _make_button(text: String, bg: Color, hover: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, TEXT)
	button.add_theme_stylebox_override("normal", _style(bg, CLEAR, 0))
	button.add_theme_stylebox_override("hover", _style(hover, CLEAR, 0))
	button.add_theme_stylebox_override("pressed", _style(BTN_ON, CLEAR, 0))
	button.add_theme_stylebox_override("hover_pressed", _style(BTN_ON_HOVER, CLEAR, 0))
	button.add_theme_stylebox_override("focus", _style(CLEAR, FOCUS_COLOR, 3))
	return button


# ---------- Olaylar ----------

func _on_quality_pressed(level: int) -> void:
	if settings != null:
		settings.call("set_level", level)
	_on_quality_changed(level)


func _on_quality_changed(level: int) -> void:
	for i: int in range(_quality_buttons.size()):
		_quality_buttons[i].set_pressed_no_signal(i == level)


func _on_fps_toggled(on: bool) -> void:
	_fps_toggle.text = FPS_TEXT_ON if on else FPS_TEXT_OFF
	if settings != null:
		settings.call("set_show_fps", on)


func _on_show_fps_changed(on: bool) -> void:
	_fps_toggle.set_pressed_no_signal(on)
	_fps_toggle.text = FPS_TEXT_ON if on else FPS_TEXT_OFF


func _on_sound_toggled(on: bool) -> void:
	_sound_toggle.text = SOUND_TEXT_ON if on else SOUND_TEXT_OFF
	if settings != null:
		settings.call("set_sound_on", on)


func _on_sound_changed(on: bool, volume: float) -> void:
	_sound_toggle.set_pressed_no_signal(on)
	_sound_toggle.text = SOUND_TEXT_ON if on else SOUND_TEXT_OFF
	_volume_button.text = VOLUME_TEXT % AudioConfig.volume_percent(volume)


## Ses düzeyi satırı: sol/sağ ok ya da satırın sol/sağ yarısına tıklama %10 adım; Enter bir adım artırır (en üstten sıfıra döner).
func _on_volume_input(event: InputEvent) -> void:
	if settings == null:
		return
	var step: float = 0.0
	if event is InputEventKey and (event as InputEventKey).pressed:
		if event.is_action_pressed("ui_left"):
			step = -AudioConfig.VOLUME_STEP
		elif event.is_action_pressed("ui_right"):
			step = AudioConfig.VOLUME_STEP
		elif event.is_action_pressed("ui_accept"):
			var v: float = float(settings.get("volume"))
			step = AudioConfig.VOLUME_STEP if v < 1.0 - 0.001 else -1.0
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		step = AudioConfig.VOLUME_STEP if mb.position.x >= _volume_button.size.x * 0.5 else -AudioConfig.VOLUME_STEP
	if step == 0.0:
		return
	_volume_button.accept_event()
	settings.call("set_volume", float(settings.get("volume")) + step)
	if not bool(settings.get("sound_on")) and step > 0.0:
		settings.call("set_sound_on", true)


## Kaydedip kapatır (oyun kaydı game.gd'de; ayarlar değişince zaten yazılmıştır).
func _on_quit() -> void:
	if game != null:
		game.call("save")
	get_tree().quit()
