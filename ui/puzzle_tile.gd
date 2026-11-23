extends Control
## Casilla de la cuadrícula del menú: tarjeta con icono dibujado por código, nombre y progreso.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Icons = preload("res://ui/puzzle_icons.gd")

signal pressed

var puzzle_id := ""
var title := ""
var done := 0
var locked := false
var _down := false


func _ready() -> void:
	custom_minimum_size = Vector2(200, 250)
	mouse_filter = Control.MOUSE_FILTER_PASS
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)


func _draw() -> void:
	var r := Rect2(Vector2(4, 2), size - Vector2(8, 14))
	if locked:
		Kit.card(self, r, 28, Palette.CARD_BOTTOM, Palette.BG_BOTTOM.lightened(0.05), Palette.CARD_BORDER.darkened(0.3), 2.0)
	else:
		Kit.card(self, r, 28, Palette.CARD_TOP.lightened(0.04 if _down else 0.0), Palette.CARD_BOTTOM, Palette.TURQUOISE_DIM, 2.5)
	var accent := Palette.WIRE if locked else Palette.TURQUOISE
	var alt := Palette.WIRE.darkened(0.2) if locked else Palette.CORAL
	var icon_rect := Rect2(r.position + Vector2(22, 16), Vector2(r.size.x - 44, r.size.y - 100))
	if not locked:
		Kit.glow_circle(self, icon_rect.get_center(), icon_rect.size.y * 0.28, Palette.TURQUOISE, 0.07)
	Icons.draw(self, puzzle_id, icon_rect, accent, alt)
	Kit.text_at(self, Vector2(size.x / 2, r.end.y - 52), title, 25, Palette.MUTED if locked else Palette.TEXT, true)
	if locked:
		Kit.text_at(self, Vector2(size.x / 2, r.end.y - 24), tr("SOON"), 18, Palette.MUTED.darkened(0.25))
	elif done > 0:
		var cx := size.x / 2.0
		var w := ThemeDB.fallback_font.get_string_size(str(done), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var x0 := cx - (w + 26) / 2.0
		var cy := r.end.y - 24
		draw_polyline(PackedVector2Array([Vector2(x0, cy), Vector2(x0 + 6, cy + 6), Vector2(x0 + 16, cy - 6)]), Palette.TURQUOISE, 3.0, true)
		Kit.text_left(self, Vector2(x0 + 26, cy), str(done), 20, Palette.TURQUOISE, true)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			if not locked:
				create_tween().tween_property(self, "scale", Vector2(0.96, 0.96), 0.08)
		else:
			if not locked:
				create_tween().tween_property(self, "scale", Vector2.ONE, 0.08)
			if _down and Rect2(Vector2.ZERO, size).has_point(ev.position) and not locked:
				pressed.emit()
			_down = false
		queue_redraw()
