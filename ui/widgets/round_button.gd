extends Control
## Botón circular blanco con sombra suave e icono.

const Style = preload("res://ui/style.gd")

signal pressed

var icon_name := "arrow-left-bold"
var icon_color: Color = Style.INK
var _down := false


func _init(icon_id := "arrow-left-bold", px := 84.0) -> void:
	icon_name = icon_id
	custom_minimum_size = Vector2(px, px)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 2.0
	for i in 5:
		draw_circle(c + Vector2(0, 7), r + 10.0 - i * 2.0, Color(Style.SHADOW, 0.035))
	draw_circle(c, r, Style.CARD if not _down else Style.SOFT)
	var px := int(r * 0.9)
	var tex := Style.icon(icon_name, icon_color, px)
	draw_texture(tex, c - tex.get_size() / 2.0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			create_tween().tween_property(self, "scale", Vector2(0.92, 0.92), 0.07)
		else:
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)
			if _down and Rect2(Vector2.ZERO, size).has_point(ev.position):
				pressed.emit()
			_down = false
		queue_redraw()
		accept_event()
