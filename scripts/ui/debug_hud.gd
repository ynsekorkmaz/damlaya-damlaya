extends CanvasLayer
## Crosshair, fading control hint and a toggleable performance readout.

const CROSSHAIR_SIZE: float = 4.0
const CROSSHAIR_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)
const HINT_TEXT: String = "Tıkla: fareyi yakala   WASD: yürü   Shift: koş   Boşluk: zıpla   Esc: fareyi bırak   F3: bilgi"
const HINT_VISIBLE_SECONDS: float = 8.0
const HINT_FADE_SECONDS: float = 2.0
const HINT_BOTTOM_OFFSET: float = 40.0
const HINT_HEIGHT: float = 30.0
const DEBUG_MARGIN: float = 12.0
const DEBUG_UPDATE_INTERVAL: float = 0.5
const TEXT_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.8)

var _hint_label: Label
var _debug_label: Label
var _debug_timer: float = 0.0


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

	var tween: Tween = create_tween()
	tween.tween_interval(HINT_VISIBLE_SECONDS)
	tween.tween_property(_hint_label, "modulate:a", 0.0, HINT_FADE_SECONDS)

	_debug_label = Label.new()
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_color_override("font_shadow_color", TEXT_SHADOW_COLOR)
	_debug_label.position = Vector2(DEBUG_MARGIN, DEBUG_MARGIN)
	_debug_label.visible = false
	add_child(_debug_label)

	set_process(false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug_label.visible = not _debug_label.visible
		set_process(_debug_label.visible)
		if _debug_label.visible:
			_update_debug_text()
			_debug_timer = 0.0


func _process(delta: float) -> void:
	_debug_timer += delta
	if _debug_timer >= DEBUG_UPDATE_INTERVAL:
		_debug_timer = 0.0
		_update_debug_text()


func _update_debug_text() -> void:
	var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_debug_label.text = "FPS: %d\nÜçgen: %d\nÇizim çağrısı: %d" % [fps, primitives, draw_calls]
