extends RefCounted
## Utilidades de interfaz con el estilo de Cavila: tarjetas con degradado y sombra, brillos,
## texto en negrita y animaciones sencillas. Todo se dibuja por código.

const Palette = preload("res://ui/palette.gd")
const PButton = preload("res://ui/pbutton.gd")

static var _bold: FontVariation


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
	return _bold


static func box(color: Color, radius: int = 20, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 20
	s.content_margin_right = 20
	return s


static func button(text: String, accent: Color = Palette.TURQUOISE, font_size: int = 32, primary := false) -> Button:
	var b := PButton.new()
	b.setup(text, accent, font_size, primary)
	return b


static func label(text: String, size: int = 30, color: Color = Palette.TEXT,
		align: int = HORIZONTAL_ALIGNMENT_CENTER, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold())
	return l


## Texto centrado en `center`. Con is_bold usa la fuente en negrita.
static func text_at(ci: CanvasItem, center: Vector2, s: String, size: int, color: Color, is_bold := false) -> void:
	var font: Font = bold() if is_bold else ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(center.x - w / 2.0, center.y + size * 0.35), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Texto alineado a la izquierda (x = inicio, y = centro vertical).
static func text_left(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, is_bold := false) -> void:
	var font: Font = bold() if is_bold else ThemeDB.fallback_font
	ci.draw_string(font, Vector2(pos.x, pos.y + size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func rounded_points(r: Rect2, rad: float, seg: int = 8) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(rad, rad), PI],
		[Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (PI / 2.0) * i / seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Rectángulo redondeado con degradado vertical, borde, sombra suave y brillo superior.
static func card(ci: CanvasItem, rect: Rect2, rad: float, top: Color = Palette.CARD_TOP,
		bottom: Color = Palette.CARD_BOTTOM, border: Color = Palette.CARD_BORDER, bw := 2.0,
		shadow := true) -> void:
	if shadow:
		for i in 5:
			ci.draw_colored_polygon(rounded_points(Rect2(rect.position + Vector2(0, 7), rect.size).grow(i * 3.0), rad + i * 3.0, 6),
				Color(0, 0, 0, 0.07))
	var pts := rounded_points(rect, rad)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	if border.a > 0.0:
		var line := pts.duplicate()
		line.append(pts[0])
		ci.draw_polyline(line, border, bw, true)
	var hr := minf(rad, rect.size.y / 2.0)
	ci.draw_line(rect.position + Vector2(hr, 1.5), Vector2(rect.end.x - hr, rect.position.y + 1.5),
		Color(1, 1, 1, 0.08), 2.0, true)


static func glow_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	ci.draw_line(a, b, Color(color, 0.07), width * 3.4, true)
	ci.draw_line(a, b, Color(color, 0.12), width * 2.3, true)
	ci.draw_line(a, b, Color(color, 0.25), width * 1.5, true)
	ci.draw_line(a, b, color, width, true)


static func glow_circle(ci: CanvasItem, c: Vector2, radius: float, color: Color, strength := 0.1) -> void:
	var n := 18
	for i in range(n, 0, -1):
		ci.draw_circle(c, radius * (0.4 + 2.4 * i / n), Color(color, strength / n * 1.4))


## Aparece suavemente al entrar en una pantalla.
static func fade_in(n: CanvasItem, t := 0.28) -> void:
	n.modulate.a = 0.0
	n.create_tween().tween_property(n, "modulate:a", 1.0, t)
