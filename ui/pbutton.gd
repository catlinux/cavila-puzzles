extends Button
## Botón de Cavila: relieve, sombra y pequeña animación al pulsar.

const Palette = preload("res://ui/palette.gd")

var accent: Color = Palette.TURQUOISE
var primary := false
var _tween: Tween


func setup(txt: String, acc: Color, font_size: int, is_primary: bool) -> void:
	text = txt
	accent = acc
	primary = is_primary
	custom_minimum_size = Vector2(0, 88)
	add_theme_font_size_override("font_size", font_size)
	add_theme_font_override("font", _bold())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	apply_style()


func _bold() -> Font:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.4
	return f


func apply_style(selected := false) -> void:
	var txt_col: Color = Palette.INK if (primary or selected) else Palette.TEXT
	add_theme_stylebox_override("normal", _style(_fill(selected, 0), selected))
	add_theme_stylebox_override("hover", _style(_fill(selected, 1), selected))
	add_theme_stylebox_override("pressed", _style(_fill(selected, 2), selected))
	var dis := _style(Palette.CARD_BOTTOM, false)
	dis.border_color = Palette.CARD_BORDER.darkened(0.2)
	dis.shadow_size = 0
	add_theme_stylebox_override("disabled", dis)
	for n in ["font_color", "font_hover_color", "font_pressed_color"]:
		add_theme_color_override(n, txt_col)
	add_theme_color_override("font_disabled_color", Palette.MUTED.darkened(0.2))


func _fill(selected: bool, state: int) -> Color:
	if primary or selected:
		return [accent, accent.lightened(0.12), accent.darkened(0.15)][state]
	return [Palette.CARD_TOP, Palette.CARD_TOP.lightened(0.08), accent.darkened(0.45)][state]


func _style(fill: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(26)
	s.set_border_width_all(2)
	s.border_color = accent.lightened(0.2) if (primary or selected) else accent.darkened(0.25)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 22
	s.content_margin_right = 22
	return s


func _ready() -> void:
	resized.connect(func(): pivot_offset = size / 2.0)
	pivot_offset = size / 2.0
	button_down.connect(_squish.bind(0.965))
	button_up.connect(_squish.bind(1.0))


func _squish(to: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(to, to), 0.08)
