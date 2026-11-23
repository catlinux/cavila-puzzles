extends RefCounted
## Estilo "Porcelana": fondo claro, tarjetas blancas con sombra suave, tinta azul marino
## y un acento de color por mundo. Fuentes Fredoka (títulos) y Nunito (texto), con licencia
## SIL OFL 1.1 (assets/fonts). Iconos Phosphor, licencia MIT (ui/icon_data.gd).

const IconData = preload("res://ui/icon_data.gd")

const INK := Color8(29, 40, 66)
const SUB := Color8(122, 133, 156)
const BG := Color8(242, 244, 249)
const CARD := Color8(255, 255, 255)
const SOFT := Color8(246, 247, 251)
const DOT := Color8(227, 231, 240)
const TRACK := Color(0.114, 0.157, 0.259, 0.08)
const GOLD := Color8(255, 176, 32)
const RED := Color8(229, 72, 77)
const OFF := Color8(213, 218, 229)
const SHADOW := Color(0.114, 0.157, 0.259, 0.10)

const FONT_FILES := {
	"display": "res://assets/fonts/fredoka-600.woff2",
	"display_bold": "res://assets/fonts/fredoka-700.woff2",
	"display_medium": "res://assets/fonts/fredoka-500.woff2",
	"body": "res://assets/fonts/nunito-700.woff2",
	"body_semi": "res://assets/fonts/nunito-600.woff2",
	"body_bold": "res://assets/fonts/nunito-800.woff2",
}

static var _fonts := {}
static var _icons := {}


static func font(kind: String) -> Font:
	if not _fonts.has(kind):
		_fonts[kind] = load(FONT_FILES[kind])
	return _fonts[kind]


## Icono Phosphor rasterizado al tamaño y color pedidos (con caché).
static func icon(name: String, color: Color, px: int) -> Texture2D:
	var key := "%s|%s|%d" % [name, color.to_html(true), px]
	if _icons.has(key):
		return _icons[key]
	var svg: String = IconData.SVG[name].replace("#FFFFFF", "#" + color.to_html(false))
	var img := Image.new()
	img.load_svg_from_string(svg, px / 256.0)
	if color.a < 1.0:
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				c.a *= color.a
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


static func label(text: String, size: int, color: Color = INK, kind := "body",
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Tarjeta blanca redondeada con sombra suave.
static func card_box(radius: int = 56, color: Color = CARD, pad: int = 40, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = SHADOW
		s.shadow_size = 34
		s.shadow_offset = Vector2(0, 14)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func card(radius: int = 56, pad: int = 40, color: Color = CARD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(radius, color, pad))
	return p


static func text_width(s: String, size: int, kind := "body") -> float:
	return font(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Texto centrado en `center` (horizontal y verticalmente).
static func text_at(ci: CanvasItem, center: Vector2, s: String, size: int, color: Color, kind := "display") -> void:
	var f := font(kind)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	ci.draw_string(f, Vector2(center.x - w / 2.0, center.y + (asc - desc) / 2.0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func rounded_points(r: Rect2, rad: float, seg: int = 10) -> PackedVector2Array:
	if r.size.x < 2.0 or r.size.y < 2.0:
		return PackedVector2Array()
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
			var q: Vector2 = c[0] + Vector2(cos(a), sin(a)) * rad
			# Sin puntos repetidos (cuando la forma es tan estrecha que las esquinas se tocan).
			if pts.is_empty() or pts[pts.size() - 1].distance_to(q) > 0.05:
				pts.append(q)
	if pts.size() > 1 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.05:
		pts.remove_at(pts.size() - 1)
	return pts


## Relleno redondeado de un color (ignora formas sin tamaño).
static func fill_round(ci: CanvasItem, r: Rect2, rad: float, col: Color, seg: int = 10) -> void:
	var pts := rounded_points(r, rad, seg)
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


## Forma redondeada con degradado horizontal (c1 -> c2).
static func gradient_shape(ci: CanvasItem, r: Rect2, rad: float, c1: Color, c2: Color) -> void:
	var pts := rounded_points(r, rad)
	if pts.size() < 3:
		return
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c1.lerp(c2, clampf((p.x - r.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)


## Sombra suave (capas translúcidas) bajo una forma redondeada.
static func soft_shadow(ci: CanvasItem, r: Rect2, rad: float, color: Color = SHADOW, spread := 18.0, offset := Vector2(0, 10)) -> void:
	var n := 6
	for i in n:
		var g := spread * (1.0 - float(i) / n)
		fill_round(ci, Rect2(r.position + offset, r.size).grow(g), rad + g, Color(color, color.a / n * 1.6), 6)


## 12340 -> "12.340"
static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func fmt_time(t: float) -> String:
	var n := int(t)
	return "%d:%02d" % [n / 60, n % 60]


static func fade_in(n: CanvasItem, t := 0.25) -> void:
	n.modulate.a = 0.0
	n.create_tween().tween_property(n, "modulate:a", 1.0, t)
