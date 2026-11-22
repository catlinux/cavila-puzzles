extends RefCounted
## Utilidades de interfaz con el estilo de Cavila.

const Palette = preload("res://ui/palette.gd")


static func box(color: Color, radius: int = 20, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 20
	s.content_margin_right = 20
	return s


static func button(text: String, accent: Color = Palette.TURQUOISE, font_size: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", box(Palette.PANEL, 22, accent.darkened(0.35), 3))
	b.add_theme_stylebox_override("hover", box(Palette.PANEL_HI, 22, accent, 3))
	b.add_theme_stylebox_override("pressed", box(accent.darkened(0.25), 22, accent, 3))
	b.add_theme_stylebox_override("disabled", box(Palette.PANEL, 22, Palette.PANEL_HI, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Palette.TEXT)
	b.add_theme_color_override("font_hover_color", Palette.TEXT)
	b.add_theme_color_override("font_pressed_color", Palette.TEXT)
	b.add_theme_color_override("font_disabled_color", Palette.MUTED)
	return b


static func label(text: String, size: int = 30, color: Color = Palette.TEXT,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Dibuja texto centrado (horizontal y verticalmente) en `center`.
static func text_at(ci: CanvasItem, center: Vector2, s: String, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(center.x - w / 2.0, center.y + size * 0.35), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
