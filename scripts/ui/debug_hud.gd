extends CanvasLayer
## Crosshair, fading control hint and a toggleable performance readout.

const CROSSHAIR_SIZE: float = 4.0
const CROSSHAIR_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)
const HINT_TEXT: String = "WASD: yürü   Shift: koş   Tab: geliştirmeler   Esc: menü"
const HINT_CLICK: String = "Tıkla: oyuna dön"
const HINT_HAMMER: String = "Q: yapılar   Sol tık: kur   Sağ tık: sök   R: döndür   1: su aleti"
const HINT_WATER_AGAIN: String = "2: çekiç   Tab: geliştirmeler   Esc: menü"
const HINT_HAMMER_LOCKED: String = "Çekiç için: Tab ile Geliştirmeler'den kilidini aç"
const HINT_HAMMER_UNBOUGHT: String = "Çekici dükkândan satın al (E)"
const HINT_VISIBLE_SECONDS: float = 12.0   ## Fare yakalıyken geçen oyun süresi
const HINT_FADE_SECONDS: float = 2.0
const HINT_WATER_SECONDS: float = 6.0
const HINT_TEMP_SECONDS: float = 3.0
const HINT_BOTTOM_OFFSET: float = 40.0
const HINT_HEIGHT: float = 30.0
const DEBUG_MARGIN: float = 12.0
const DEBUG_UPDATE_INTERVAL: float = 0.5
const TEXT_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.8)

## Grafik ayarları (isteğe bağlı): menüdeki "FPS göster" anahtarı bilgi kutusunu açar/kapatır.
var settings: Node

## Çekiç yuvası (isteğe bağlı): çekiç eldeyken alt satır yapı ipuçlarını gösterir.
var equipment: Node

## Oyuncu (isteğe bağlı): bir panel açıkken "Tıkla: oyuna dön" gösterilmez.
var player: Node

var _hint_label: Label
var _debug_label: Label
var _debug_timer: float = 0.0
var _play_time: float = 0.0
var _temp_text: String = ""
var _temp_left: float = 0.0


func _ready() -> void:
	var crosshair := ColorRect.new()
	crosshair.color = CROSSHAIR_COLOR
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	var half: float = CROSSHAIR_SIZE * 0.5
	crosshair.offset_left = -half
	crosshair.offset_right = half
	crosshair.offset_top = -half
	crosshair.offset_bottom = half
	add_child(crosshair)

	_hint_label = Label.new()
	_hint_label.text = HINT_TEXT
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_shadow_color", TEXT_SHADOW_COLOR)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -(HINT_BOTTOM_OFFSET + HINT_HEIGHT)
	_hint_label.offset_bottom = -HINT_BOTTOM_OFFSET
	add_child(_hint_label)

	_debug_label = Label.new()
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_color_override("font_shadow_color", TEXT_SHADOW_COLOR)
	_debug_label.position = Vector2(DEBUG_MARGIN, DEBUG_MARGIN)
	_debug_label.visible = false
	add_child(_debug_label)

	if equipment != null:
		equipment.connect("slot_changed", _on_slot_changed)
		equipment.connect("hammer_denied", _on_hammer_denied)
	if settings != null:
		settings.connect("show_fps_changed", _set_info_visible)
		_set_info_visible(bool(settings.get("show_fps")))


func _show_temp(text: String, seconds: float) -> void:
	_temp_text = text
	_temp_left = seconds


## Çekiç eldeyken bağlama göre ipucu kalıcı görünür; su aletine dönünce kısa süre gösterilir.
func _on_slot_changed(slot: int) -> void:
	if slot == 0:
		_show_temp(HINT_WATER_AGAIN, HINT_WATER_SECONDS)
	else:
		_temp_left = 0.0


## Çekiç yokken 2'ye basılınca nedenini söyler.
func _on_hammer_denied(unlocked: bool) -> void:
	_show_temp(HINT_HAMMER_UNBOUGHT if unlocked else HINT_HAMMER_LOCKED, HINT_TEMP_SECONDS)


func _update_hint(delta: float) -> void:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var text: String = ""
	var alpha: float = 1.0
	if _temp_left > 0.0:
		_temp_left -= delta
		text = _temp_text
	elif not captured:
		if player == null or bool(player.get("input_enabled")):
			text = HINT_CLICK
	elif equipment != null and bool(equipment.call("hammer_active")):
		text = HINT_HAMMER
	else:
		_play_time += delta
		if _play_time < HINT_VISIBLE_SECONDS + HINT_FADE_SECONDS:
			text = HINT_TEXT
			alpha = clampf((HINT_VISIBLE_SECONDS + HINT_FADE_SECONDS - _play_time) / HINT_FADE_SECONDS, 0.0, 1.0)
	if _hint_label.text != text:
		_hint_label.text = text
	_hint_label.modulate.a = alpha


func _set_info_visible(on: bool) -> void:
	_debug_label.visible = on
	if on:
		_update_debug_text()
		_debug_timer = 0.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		if settings != null:
			settings.call("set_show_fps", not _debug_label.visible)
		else:
			_set_info_visible(not _debug_label.visible)


func _process(delta: float) -> void:
	_update_hint(delta)
	if not _debug_label.visible:
		return
	_debug_timer += delta
	if _debug_timer >= DEBUG_UPDATE_INTERVAL:
		_debug_timer = 0.0
		_update_debug_text()


func _update_debug_text() -> void:
	var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_debug_label.text = "FPS: %d\nÜçgen: %d\nÇizim çağrısı: %d" % [fps, primitives, draw_calls]
