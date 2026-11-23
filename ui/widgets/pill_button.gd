extends Control
## Botón en forma de píldora. Principal: degradado del acento con texto blanco y brillo de
## color. Secundario: blanco con texto en tinta.

const Style = preload("res://ui/style.gd")

signal pressed

var text := ""
var icon_name := ""
var c1: Color = Color8(255, 106, 85)
var c2: Color = Color8(255, 154, 61)
var primary := true
var font_size := 44
var _down := false


func _init(label_text := "", is_primary := true, height := 116.0) -> void:
	text = label_text
	primary = is_primary
	custom_minimum_size = Vector2(0, height)


func set_colors(a: Color, b: Color) -> void:
	c1 = a
	c2 = b
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)


func _draw() -> void:
	var r := Rect2(Vector2(4, 2), size - Vector2(8, 14))
	var rad := r.size.y / 2.0
	if primary:
		Style.soft_shadow(self, r, rad, Color(c1, 0.35), 16.0, Vector2(0, 10))
		Style.gradient_shape(self, r, rad, c1.darkened(0.06) if _down else c1, c2.darkened(0.06) if _down else c2)
	else:
		Style.soft_shadow(self, r, rad, Style.SHADOW, 14.0, Vector2(0, 8))
		Style.fill_round(self, r, rad, Style.SOFT if _down else Style.CARD)
	var col: Color = Color.WHITE if primary else Style.INK
	var fs := font_size if primary else int(font_size * 0.8)
	var tw := Style.text_width(text, fs, "display")
	var iw := 0.0
	var tex: Texture2D = null
	if icon_name != "":
		tex = Style.icon(icon_name, col, int(fs * 0.95))
		iw = tex.get_width() + 16.0
	var x0 := r.get_center().x - (tw + iw) / 2.0
	if tex:
		draw_texture(tex, Vector2(x0, r.get_center().y - tex.get_height() / 2.0))
	Style.text_at(self, Vector2(x0 + iw + tw / 2.0, r.get_center().y), text, fs, col, "display")


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			create_tween().tween_property(self, "scale", Vector2(0.97, 0.97), 0.07)
		else:
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)
			if _down and Rect2(Vector2.ZERO, size).has_point(ev.position):
				pressed.emit()
			_down = false
		queue_redraw()
		accept_event()
