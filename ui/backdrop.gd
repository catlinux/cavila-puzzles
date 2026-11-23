extends Control
## Fondo animado: cielo nocturno con degradado, bandas de aurora que ondulan y estrellas
## que titilan. Los colores vienen del mundo actual.

var top := Color8(16, 34, 48)
var bottom := Color8(7, 12, 22)
var color_a := Color8(94, 234, 212)
var color_b := Color8(125, 211, 252)
var animate := true

var _t := 0.0
var _acc := 0.0
var _stars: Array = []


func set_world(w: Dictionary) -> void:
	top = w.top
	bottom = w.bottom
	color_a = w.a
	color_b = w.b
	queue_redraw()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.75), rng.randf_range(0.8, 2.2), rng.randf() * TAU])
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not animate:
		return
	_t += delta
	_acc += delta
	if _acc >= 1.0 / 30.0:  # 30 fps para el fondo es suficiente
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	# Aurora: bandas onduladas muy translúcidas.
	for k in 3:
		var col := color_a.lerp(color_b, k / 2.0)
		var base_y := size.y * (0.16 + 0.1 * k)
		var pts := PackedVector2Array()
		var x := -60.0
		while x <= size.x + 60.0:
			var y := base_y + sin(x * 0.006 + _t * (0.25 + 0.08 * k) + k * 1.7) * 46.0 \
				+ sin(x * 0.013 - _t * 0.18 + k) * 18.0
			pts.append(Vector2(x, y))
			x += 40.0
		draw_polyline(pts, Color(col, 0.035), 190.0, true)
		draw_polyline(pts, Color(col, 0.045), 110.0, true)
		draw_polyline(pts, Color(col, 0.06), 46.0, true)
	# Estrellas.
	for s in _stars:
		var a := 0.25 + 0.3 * (0.5 + 0.5 * sin(_t * 1.3 + s[2]))
		draw_circle(Vector2(s[0].x * size.x, s[0].y * size.y), s[1], Color(1, 1, 1, a))
	# Viñeta inferior suave.
	draw_polygon(PackedVector2Array([Vector2(0, size.y * 0.7), Vector2(size.x, size.y * 0.7), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([Color(bottom, 0.0), Color(bottom, 0.0), Color(bottom, 0.8), Color(bottom, 0.8)]))
