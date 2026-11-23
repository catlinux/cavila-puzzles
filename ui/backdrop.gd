extends Control
## Fondo claro: degradado suave de blanco (arriba) a gris porcelana.

const Style = preload("res://ui/style.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var top := Color.WHITE
	var mid := Style.BG
	var y := size.y * 0.45
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, y), Vector2(0, y)]),
		PackedColorArray([top, top, mid, mid]))
	draw_rect(Rect2(0, y, size.x, size.y - y), mid)
