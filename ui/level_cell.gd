extends Control
## Casilla de nivel: número, estado (completado con estrellas, siguiente, bloqueado).

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")

signal pressed

var number := 1
var stars := 0
var done := false
var locked := false
var current := false  # el siguiente nivel por jugar
var _down := false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 118)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(_d: float) -> void:
	if current:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 10))
	if done:
		Kit.card(self, r, 24, Palette.TURQUOISE_DIM.lightened(0.1), Palette.TURQUOISE_DIM.darkened(0.25), Palette.TURQUOISE, 2.0)
	elif locked:
		Kit.card(self, r, 24, Palette.CARD_BOTTOM, Palette.BG_BOTTOM.lightened(0.04), Palette.CARD_BORDER.darkened(0.35), 1.5, false)
	else:
		Kit.card(self, r, 24, Palette.CARD_TOP.lightened(0.05 if _down else 0.0), Palette.CARD_BOTTOM, Palette.CORAL, 2.5)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		draw_polyline(_ring(r.grow(2.0 + pulse * 3.0)), Color(Palette.CORAL, 0.35 * (1.0 - pulse * 0.5)), 2.0, true)
	var col: Color = Palette.MUTED.darkened(0.3) if locked else Palette.TEXT
	var c := r.get_center()
	if locked:
		var body := Rect2(c + Vector2(-13, -2), Vector2(26, 20))
		draw_rect(body, col)
		draw_arc(c + Vector2(0, -2), 9, PI, TAU, 12, col, 4.0, true)
		return
	Kit.text_at(self, c + Vector2(0, -10 if done else 0), str(number), 38, Palette.INK if done else col, true)
	if done:
		for i in 3:
			_star(c + Vector2((i - 1) * 26.0, 28), 10.0, i < stars)


func _ring(r: Rect2) -> PackedVector2Array:
	var p := Kit.rounded_points(r, 26.0, 6)
	p.append(p[0])
	return p


func _star(c: Vector2, rad: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var rr := rad if i % 2 == 0 else rad * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	if filled:
		draw_colored_polygon(pts, Palette.GOLD)
	else:
		pts.append(pts[0])
		draw_polyline(pts, Palette.INK.lightened(0.25), 2.0, true)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
		else:
			if _down and not locked and Rect2(Vector2.ZERO, size).has_point(ev.position):
				pressed.emit()
			_down = false
		queue_redraw()
