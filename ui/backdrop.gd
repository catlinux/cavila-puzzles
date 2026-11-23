extends Control
## Fondo común: degradado oscuro, brillos turquesa y coral difusos y una malla de puntos tenue.

const Palette = preload("res://ui/palette.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([Palette.BG_TOP, Palette.BG_TOP, Palette.BG_BOTTOM, Palette.BG_BOTTOM]))
	_glow(Vector2(size.x * 0.15, size.y * 0.06), size.x * 0.55, Palette.TURQUOISE, 0.05)
	_glow(Vector2(size.x * 0.95, size.y * 0.92), size.x * 0.6, Palette.CORAL, 0.045)
	var step := 52.0
	var y := step / 2.0
	while y < size.y:
		var x := step / 2.0
		while x < size.x:
			draw_circle(Vector2(x, y), 1.6, Color(1, 1, 1, 0.045))
			x += step
		y += step


func _glow(c: Vector2, radius: float, color: Color, strength: float) -> void:
	var n := 30
	for i in n:
		draw_circle(c, radius * (1.0 - float(i) / n), Color(color, strength / 6.0))
