extends CanvasLayer
## Çekiç arayüzü göstergeleri: sağ altta iki yuva (1 su aleti, 2 çekiç) ve çekiç eldeyken kanal alanı yakınında
## sol altta kanal bilgi kutusu (pınarlardan gelen, göle ulaşan, sızan, taşan, boşa giden; damla/sn).
## Dış bağlantı: add_child'dan önce `game`, `equipment`, `player` atanır. Yalnızca değişince güncellenir.

const Config = preload("res://scripts/core/config.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const MARGIN: float = 24.0
const SLOT_SIZE: Vector2 = Vector2(78.0, 46.0)
const SLOT_ABOVE: float = 104.0          # sağ alttaki su kutusunun üstünde
const INFO_FONT: int = 17
const SLOT_BG := Color(0.05, 0.08, 0.11, 0.62)
const SLOT_ACTIVE_BORDER := Color(1.0, 0.93, 0.55, 1.0)
const SLOT_IDLE_BORDER := Color(0.45, 0.70, 0.85, 0.35)
const TEXT := Color(0.97, 0.97, 0.94)
const TEXT_DIM := Color(0.74, 0.80, 0.82, 0.7)
const OUTLINE := Color(0.05, 0.08, 0.12, 0.9)
const CHECK_INTERVAL: float = 0.2

var game: Node
var equipment: Node
var player: Node3D

var _slot_panels: Array[PanelContainer] = []
var _slot_names: Array[Label] = []
var _slot_state: Array[int] = [-1, -1]
var _info_box: PanelContainer
var _info_label: Label
var _info_shown: bool = false
var _last_values: Array[float] = []
var _timer: float = 0.0


func _ready() -> void:
	layer = 6
	_build_slots()
	_build_info()
	_info_box.visible = false
	if equipment != null:
		equipment.connect("slot_changed", _on_slot_changed)
	_refresh_slots()


static func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(5.0)
	return s


func _build_slots() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = -MARGIN
	row.offset_right = -MARGIN
	row.offset_top = -(MARGIN + SLOT_ABOVE)
	row.offset_bottom = -(MARGIN + SLOT_ABOVE)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var labels: Array[String] = ["Su", "Çekiç"]
	for i in range(2):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = SLOT_SIZE
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", -2)
		panel.add_child(col)
		var num: Label = _label(str(i + 1), 13)
		col.add_child(num)
		var nm: Label = _label(labels[i], 19)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		row.add_child(panel)
		_slot_panels.append(panel)
		_slot_names.append(nm)


func _build_info() -> void:
	_info_box = PanelContainer.new()
	_info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_box.anchor_left = 0.0
	_info_box.anchor_right = 0.0
	_info_box.anchor_top = 1.0
	_info_box.anchor_bottom = 1.0
	_info_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_box.offset_left = MARGIN
	_info_box.offset_bottom = -MARGIN
	_info_box.add_theme_stylebox_override("panel", _style(SLOT_BG, Color(0.45, 0.70, 0.85, 0.5), 1))
	_info_label = _label("", INFO_FONT)
	_info_box.add_child(_info_label)
	add_child(_info_box)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _on_slot_changed(_slot: int) -> void:
	_refresh_slots()


## Yuva görünümü: 0 pasif, 1 elde, 2 yok (çekiç alınmamış).
func _refresh_slots() -> void:
	if equipment == null:
		return
	var slot: int = equipment.get("slot")
	var owned: bool = bool(equipment.call("hammer_owned"))
	var wanted: Array[int] = [1 if slot == 0 else 0, (1 if slot == 1 else 0) if owned else 2]
	for i in range(2):
		if _slot_state[i] == wanted[i]:
			continue
		_slot_state[i] = wanted[i]
		var border: Color = SLOT_ACTIVE_BORDER if wanted[i] == 1 else SLOT_IDLE_BORDER
		_slot_panels[i].add_theme_stylebox_override("panel", _style(SLOT_BG, border, 3 if wanted[i] == 1 else 1))
		_slot_panels[i].modulate = Color(1.0, 1.0, 1.0, 0.45 if wanted[i] == 2 else 1.0)
		_slot_names[i].add_theme_color_override("font_color", TEXT_DIM if wanted[i] != 1 else TEXT)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < CHECK_INTERVAL:
		return
	_timer = 0.0
	_refresh_slots()
	var want: bool = false
	if game != null and equipment != null and player != null and bool(equipment.call("hammer_active")) \
			and bool((game.get("state") as Object).get("canal_unlocked")):
		want = CanalField.distance_to(player.global_position.x, player.global_position.z) < Config.CANAL_FIELD_NEAR
	if want != _info_shown:
		_info_shown = want
		_info_box.visible = want
		_last_values.clear()
	if want:
		_update_info()


func _update_info() -> void:
	var r: Dictionary = game.call("canal_result")
	var values: Array[float] = [float(r["input"]), float(r["delivered"]), float(r["leaked"]), float(r["overflow"]), float(r["wasted"])]
	if values == _last_values:
		return
	_last_values = values
	_info_label.text = "Pınarlardan: %s\nGöle ulaşan: %s\nSızan: %s\nTaşan: %s\nBoşa giden: %s\n(damla/sn)" % [
		_fmt(values[0]), _fmt(values[1]), _fmt(values[2]), _fmt(values[3]), _fmt(values[4])]


## 100'den küçükte tek ondalık (virgül), büyükte tam sayı (binlik noktası).
static func _fmt(v: float) -> String:
	if v >= 100.0:
		return NumberFormat.format_int(v)
	if v <= 0.0:
		return "0"
	if is_equal_approx(v, roundf(v)):
		return NumberFormat.format_int(v)
	return String.num(roundf(v * 10.0) / 10.0, 1).replace(".", ",")
