extends Control
## Botón redondo de cristal con icono dibujado por código y contador opcional.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")

signal pressed

var icon := "back"  # back, hint, restart, gear, close
var badge := -1
var accent := Color8(94, 234, 212)
var _down := false


func _init(icon_name := "back", size_px := 84.0) -> void:
	icon = icon_name
	custom_minimum_size = Vector2(size_px, size_px)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	for i in 4:
		draw_circle(c + Vector2(0, 5), r + i * 2.0, Color(0, 0, 0, 0.06))
	draw_circle(c, r, Color(1, 1, 1, 0.10 if _down else 0.07))
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.16), 2.0, true)
	draw_arc(c, r - 2.0, PI * 1.15, PI * 1.85, 16, Color(1, 1, 1, 0.12), 2.0, true)
	var col := Palette.TEXT
	var u := r * 0.42
	match icon:
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(u * 0.35, -u), c + Vector2(-u * 0.55, 0), c + Vector2(u * 0.35, u)]), col, 5.0, true)
		"close":
			draw_line(c + Vector2(-u, -u) * 0.8, c + Vector2(u, u) * 0.8, col, 5.0, true)
			draw_line(c + Vector2(u, -u) * 0.8, c + Vector2(-u, u) * 0.8, col, 5.0, true)
		"hint":
			var bc := Palette.GOLD
			draw_circle(c + Vector2(0, -u * 0.25), u * 0.78, bc)
			draw_rect(Rect2(c + Vector2(-u * 0.38, u * 0.45), Vector2(u * 0.76, u * 0.45)), bc)
			draw_line(c + Vector2(-u * 0.28, u * 1.08), c + Vector2(u * 0.28, u * 1.08), bc, 3.0, true)
			draw_arc(c + Vector2(0, -u * 0.25), u * 0.42, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.7), 3.0, true)
		"restart":
			draw_arc(c, u * 0.9, PI * 0.35, PI * 2.05, 24, col, 5.0, true)
			var tip := c + Vector2(cos(PI * 0.35), sin(PI * 0.35)) * u * 0.9
			draw_colored_polygon(PackedVector2Array([tip + Vector2(u * 0.45, -u * 0.1), tip + Vector2(-u * 0.2, -u * 0.45), tip + Vector2(-u * 0.05, u * 0.35)]), col)
		"gear":
			var pts := PackedVector2Array()
			for i in 48:
				var a := TAU * i / 48.0
				var rr := u * (1.0 if (i % 6) < 3 else 0.78)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)
			draw_circle(c, u * 0.38, Palette.BG_BOTTOM)
	if badge >= 0:
		var bp := c + Vector2(r * 0.72, -r * 0.72)
		draw_circle(bp, 17, Palette.CORAL if badge == 0 else accent)
		Kit.text_at(self, bp, str(badge), 20, Palette.INK, true)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			create_tween().tween_property(self, "scale", Vector2(0.9, 0.9), 0.07)
		else:
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.1)
			if _down and Rect2(Vector2.ZERO, size).has_point(ev.position):
				pressed.emit()
			_down = false
		queue_redraw()
		accept_event()
