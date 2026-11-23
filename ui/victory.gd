extends Control
## Pantalla de resultado: estrellas con animación, estadísticas y confeti (si se gana).

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Backdrop = preload("res://ui/backdrop.gd")

var _won := false
var _res: Dictionary = {}
var _star_t := [0.0, 0.0, 0.0]  # progreso 0..1 de la animación de cada estrella
var _confetti: Array = []
var _fx: Control
var _age := 0.0


func _ready() -> void:
	_res = Game.last_result
	_won = _res.get("won", false)
	add_child(Backdrop.new())
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom", "top"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 26)
	margin.add_child(vb)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 250)  # hueco para las estrellas (se dibujan en _fx)
	vb.add_child(spacer)
	vb.add_child(Kit.label(tr("WIN_TITLE") if _won else tr("LOSE_TITLE"), 76,
		Palette.TURQUOISE_LIGHT if _won else Palette.CORAL_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var stats := Control.new()
	stats.custom_minimum_size = Vector2(0, 130)
	stats.draw.connect(_draw_stats.bind(stats))
	vb.add_child(stats)

	if _won and Game.daily_key == "":
		var nxt := Kit.button(tr("NEXT"), Palette.TURQUOISE, 34, true)
		nxt.pressed.connect(Game.next_level)
		vb.add_child(nxt)
	var again := Kit.button(tr("REPLAY") if _won else tr("RETRY"), Palette.CORAL, 34, not _won)
	again.pressed.connect(Game.restart)
	vb.add_child(again)
	var menu := Kit.button(tr("MENU"), Palette.MUTED, 32)
	menu.pressed.connect(Game.go_menu)
	vb.add_child(menu)

	if _won:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 70:
			_confetti.append({"p": Vector2(rng.randf_range(0, 720), rng.randf_range(-700, -20)),
				"v": Vector2(rng.randf_range(-30, 30), rng.randf_range(150, 330)), "a": rng.randf() * TAU,
				"w": rng.randf_range(-4, 4), "s": rng.randf_range(8, 16),
				"c": [Palette.TURQUOISE, Palette.CORAL, Palette.GOLD, Palette.VIOLET][rng.randi() % 4]})
	Kit.fade_in(self)


func _process(delta: float) -> void:
	_age += delta
	var n := int(_res.get("stars", 0)) if _won else 0
	for i in 3:
		if i < n or not _won:
			_star_t[i] = clampf((_age - 0.35 - i * 0.28) / 0.45, 0.0, 1.0)
	for c in _confetti:
		c.p += c.v * delta
		c.a += c.w * delta
	_fx.queue_redraw()


func _draw_fx() -> void:
	var cx := size.x / 2.0
	var cy := 40.0 + size.y * 0.5 - 380.0
	cy = maxf(cy, 150.0)
	if not _won:
		Kit.glow_circle(_fx, Vector2(cx, cy), 60, Palette.CORAL, 0.08)
		_fx.draw_arc(Vector2(cx, cy), 72, 0, TAU, 48, Palette.CORAL, 10.0, true)
		_fx.draw_line(Vector2(cx - 28, cy - 28), Vector2(cx + 28, cy + 28), Palette.CORAL, 12.0, true)
		_fx.draw_line(Vector2(cx + 28, cy - 28), Vector2(cx - 28, cy + 28), Palette.CORAL, 12.0, true)
		return
	Kit.glow_circle(_fx, Vector2(cx, cy), 90, Palette.GOLD, 0.05)
	var earned := int(_res.get("stars", 0))
	for i in 3:
		var t: float = _star_t[i]
		var pop := 1.0 + 0.35 * sin(t * PI)  # rebote
		var center := Vector2(cx + (i - 1) * 150.0, cy + (28.0 if i != 1 else -10.0))
		var rad := (52.0 if i == 1 else 42.0) * pop
		if i < earned:
			var s := _star_points(center, rad * (0.4 + 0.6 * t))
			Kit.glow_circle(_fx, center, rad * 0.8, Palette.GOLD, 0.05 * t)
			_fx.draw_colored_polygon(s, Palette.GOLD.lerp(Color.WHITE, 0.15))
		else:
			var o := _star_points(center, rad)
			o.append(o[0])
			_fx.draw_polyline(o, Palette.CARD_BORDER, 4.0, true)
	for c in _confetti:
		if c.p.y > size.y:
			continue
		var d: Vector2 = Vector2(cos(c.a), sin(c.a)) * c.s
		_fx.draw_line(c.p - d / 2.0, c.p + d / 2.0, c.c, 5.0)


func _star_points(c: Vector2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var rr := rad if i % 2 == 0 else rad * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw_stats(c: Control) -> void:
	var t: float = _res.get("time", 0.0)
	var items := [
		[tr("STAT_TIME"), "%d:%02d" % [int(t) / 60, int(t) % 60], Palette.TURQUOISE],
		[tr("STAT_LIVES"), str(_res.get("lives", 0)), Palette.CORAL],
		[tr("STAT_HINTS"), str(_res.get("hints", 0)), Palette.GOLD],
	]
	var w := (c.size.x - 28.0) / 3.0
	for i in 3:
		var r := Rect2(Vector2(i * (w + 14.0), 4), Vector2(w, c.size.y - 14))
		Kit.card(c, r, 24, Palette.CARD_TOP, Palette.CARD_BOTTOM, Palette.CARD_BORDER, 2.0)
		Kit.text_at(c, r.get_center() + Vector2(0, -14), items[i][1], 44, items[i][2], true)
		Kit.text_at(c, r.get_center() + Vector2(0, 28), items[i][0], 18, Palette.MUTED)
