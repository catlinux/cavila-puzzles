extends Control
## Cápsula blanca con icono y número (estrellas, pistas…). Puede pulsarse.

const Style = preload("res://ui/style.gd")

signal pressed

var icon_name := "star-fill"
var icon_color: Color = Style.GOLD
var value := ""
var _down := false


func _init(icon_id := "star-fill", col: Color = Style.GOLD, text_value := "") -> void:
	icon_name = icon_id
	icon_color = col
	value = text_value


func set_value(v: String) -> void:
	value = v
	_resize()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(58 + Style.text_width(value, 30, "display") + 26, 76)


func _draw() -> void:
	var r := Rect2(Vector2(2, 4), Vector2(size.x - 4, 66))
	Style.soft_shadow(self, r, 33.0, Style.SHADOW, 12.0, Vector2(0, 7))
	Style.fill_round(self, r, 33.0, Style.SOFT if _down else Style.CARD)
	var tex := Style.icon(icon_name, icon_color, 32)
	draw_texture(tex, Vector2(r.position.x + 16, r.get_center().y - 16))
	Style.text_at(self, Vector2(r.position.x + 56 + Style.text_width(value, 30, "display") / 2.0, r.get_center().y), value, 30, Style.INK, "display")


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_down = ev.pressed
		if not ev.pressed and Rect2(Vector2.ZERO, size).has_point(ev.position):
			pressed.emit()
		queue_redraw()
		accept_event()
