extends RefCounted
## Dükkân ve Geliştirmeler panellerinin ortak renk, boyut ve düğme yardımcıları.

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
const BUY_OFF_TEXT := Color(0.62, 0.68, 0.70, 0.7)
const FOCUS_COLOR := Color(1.0, 0.93, 0.55)
const SIDE_BG := Color(0.14, 0.20, 0.25)
const SIDE_HOVER := Color(0.20, 0.29, 0.35)
const SIDE_ACTIVE := Color(0.20, 0.42, 0.52)
const CLEAR := Color(0.0, 0.0, 0.0, 0.0)

const PANEL_PAD: float = 18.0
const ROW_PAD: float = 10.0
const TITLE_SIZE: int = 34
const MONEY_SIZE: int = 26
const SECTION_SIZE: int = 20
const NAME_SIZE: int = 20
const DESC_SIZE: int = 15
const INFO_SIZE: int = 16
const COST_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 19
const HINT_SIZE: int = 14
const BUTTON_SIZE: Vector2 = Vector2(110.0, 42.0)
const REFRESH_INTERVAL: float = 0.25
const DISABLED_ALPHA: float = 0.55


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(6.0)
	return s


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = PANEL_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(PANEL_PAD)
	return s


static func row_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ROW_BG
	s.set_corner_radius_all(8)
	s.set_content_margin_all(ROW_PAD)
	return s


static func buy_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, TEXT)
	button.add_theme_color_override("font_disabled_color", BUY_OFF_TEXT)
	button.add_theme_stylebox_override("normal", style(BUY_BG, CLEAR, 0))
	button.add_theme_stylebox_override("hover", style(BUY_HOVER, CLEAR, 0))
	button.add_theme_stylebox_override("pressed", style(BUY_PRESSED, CLEAR, 0))
	button.add_theme_stylebox_override("disabled", style(BUY_OFF_BG, CLEAR, 0))
	button.add_theme_stylebox_override("focus", style(CLEAR, FOCUS_COLOR, 3))
	return button


## Sol sütundaki bölüm düğmesi; seçili bölüm "active" biçimiyle çizilir.
static func side_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", NAME_SIZE)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, TEXT)
	button.add_theme_color_override("font_disabled_color", BUY_OFF_TEXT)
	button.add_theme_stylebox_override("normal", style(SIDE_BG, CLEAR, 0))
	button.add_theme_stylebox_override("hover", style(SIDE_HOVER, CLEAR, 0))
	button.add_theme_stylebox_override("pressed", style(SIDE_ACTIVE, CLEAR, 0))
	button.add_theme_stylebox_override("hover_pressed", style(SIDE_ACTIVE, CLEAR, 0))
	button.add_theme_stylebox_override("disabled", style(Color(0.10, 0.14, 0.17, 0.5), CLEAR, 0))
	button.add_theme_stylebox_override("focus", style(CLEAR, FOCUS_COLOR, 3))
	return button
