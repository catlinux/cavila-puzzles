extends Control
## Pantalla de inicio: marca, reto diario, constelación de niveles y botón Jugar.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Levels = preload("res://game/levels.gd")
const Daily = preload("res://core/daily.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const IconButton = preload("res://ui/icon_button.gd")

const MONTHS := {
	"es": ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
	"ca": ["de gener", "de febrer", "de març", "d'abril", "de maig", "de juny", "de juliol", "d'agost", "de setembre", "d'octubre", "de novembre", "de desembre"],
}

var level := 1
var world: Dictionary = {}
var _constellation: Control
var _nodes: Array = []  # [posición, nivel, radio]
var _clock := 0.0
var _settings: Control


func _ready() -> void:
	level = Progress.current_level()
	world = Levels.world(level)
	var bg := Backdrop.new()
	add_child(bg)
	bg.set_world(world)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	margin.add_child(vb)

	# Cabecera.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(84, 84)
	logo.draw.connect(_draw_logo.bind(logo))
	head.add_child(logo)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -6)
	names.add_child(Kit.label("Cavila", 54, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	names.add_child(Kit.label(tr("TAGLINE"), 22, world.a.lerp(Palette.TEXT, 0.4), HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(names)
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(120, 84)
	chip.draw.connect(_draw_hint_chip.bind(chip))
	head.add_child(chip)
	var gear := IconButton.new("gear")
	gear.pressed.connect(_open_settings)
	head.add_child(gear)

	# Reto diario.
	var daily := Control.new()
	daily.custom_minimum_size = Vector2(0, 176)
	daily.mouse_filter = Control.MOUSE_FILTER_STOP
	daily.draw.connect(_draw_daily.bind(daily))
	daily.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			Game.start_daily())
	vb.add_child(daily)

	# Constelación de niveles.
	_constellation = Control.new()
	_constellation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_constellation.mouse_filter = Control.MOUSE_FILTER_STOP
	_constellation.draw.connect(_draw_constellation)
	_constellation.gui_input.connect(_constellation_input)
	vb.add_child(_constellation)

	var play := Kit.button("%s · %s %d" % [tr("PLAY"), tr("LEVEL"), level], world.a, 38, true)
	play.custom_minimum_size = Vector2(0, 118)
	play.pressed.connect(Game.start_level.bind(level))
	vb.add_child(play)
	Kit.fade_in(self)


func _process(delta: float) -> void:
	_clock += delta
	_constellation.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings:
			_close_settings()
		else:
			get_tree().quit()


# --- Dibujo -----------------------------------------------------------------------

func _draw_logo(c: Control) -> void:
	var r := Rect2(Vector2(2, 2), c.size - Vector2(4, 4))
	Kit.card(c, r, 24, world.top.lightened(0.12), world.bottom, Color(world.a, 0.5), 2.0)
	var u := r.size.x
	var p0 := r.position + Vector2(0.28, 0.76) * u
	var p1 := r.position + Vector2(0.28, 0.5) * u
	var p2 := r.position + Vector2(0.56, 0.5) * u
	var p3 := r.position + Vector2(0.56, 0.3) * u
	for seg in [[p0, p1], [p1, p2], [p2, p3]]:
		Kit.glow_line(c, seg[0], seg[1], world.a, 6.0)
	c.draw_circle(p1, 3.0, world.a)
	c.draw_circle(p2, 3.0, world.a)
	c.draw_colored_polygon(PackedVector2Array([p3 + Vector2(0, -12), p3 + Vector2(-10, 3), p3 + Vector2(10, 3)]), world.a)
	c.draw_circle(r.position + Vector2(0.76, 0.72) * u, 6.0, world.b)


func _draw_hint_chip(c: Control) -> void:
	var r := Rect2(Vector2(4, 14), Vector2(c.size.x - 8, 56))
	Kit.card(c, r, 28, Color(1, 1, 1, 0.09), Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.14), 1.5, false)
	var b := Vector2(r.position.x + 30, r.get_center().y - 3)
	c.draw_circle(b, 11, Palette.GOLD)
	c.draw_rect(Rect2(b + Vector2(-5, 8), Vector2(10, 7)), Palette.GOLD)
	Kit.text_left(c, Vector2(r.position.x + 54, r.get_center().y), str(Progress.hints()), 28, Palette.TEXT, true)


func _draw_daily(c: Control) -> void:
	var key := Daily.today_key()
	var dw := Daily.world_for(key)
	var done := Progress.daily_done(key)
	var r := Rect2(Vector2(2, 2), c.size - Vector2(4, 12))
	Kit.card(c, r, 32, Color(dw.top.lightened(0.18), 0.92), Color(dw.bottom.lightened(0.06), 0.92), Color(dw.a, 0.6), 2.0)
	Kit.glow_circle(c, Vector2(r.end.x - 120, r.get_center().y), 50, dw.a, 0.08)
	# Ilustración: tres flechas pequeñas.
	var o := Vector2(r.end.x - 175, r.position.y + 40)
	var arrows := [[Vector2(0, 80), Vector2(0, 30), Vector2(40, 30), Vector2(40, 0)],
		[Vector2(70, 90), Vector2(110, 90), Vector2(110, 40)], [Vector2(150, 10), Vector2(150, 70)]]
	for k in arrows.size():
		var pts := PackedVector2Array()
		for q in arrows[k]:
			pts.append(o + q)
		var col: Color = dw.a.lerp(dw.b, k / 2.0)
		c.draw_polyline(pts, Color(col, 0.15), 18.0, true)
		c.draw_polyline(pts, col, 7.0, true)
		var hp: Vector2 = pts[pts.size() - 1]
		var d: Vector2 = (hp - pts[pts.size() - 2]).normalized()
		var pp := Vector2(-d.y, d.x)
		c.draw_colored_polygon(PackedVector2Array([hp + d * 14, hp - d * 4 + pp * 11, hp - d * 4 - pp * 11]), col)
	var d0 := Time.get_date_dict_from_system()
	var lang := Game.language()
	var date := "%d %s" % [d0.day, MONTHS.get(lang, MONTHS.es)[d0.month - 1]]
	Kit.text_left(c, r.position + Vector2(32, 40), tr("DAILY").to_upper(), 21, dw.a, true)
	Kit.text_left(c, r.position + Vector2(32, 86), date, 40, Palette.TEXT, true)
	var streak := Progress.streak(key)
	var line_y := r.position.y + 132
	if done:
		var p := Vector2(r.position.x + 34, line_y)
		c.draw_polyline(PackedVector2Array([p, p + Vector2(8, 8), p + Vector2(22, -9)]), dw.a, 4.0, true)
		Kit.text_left(c, p + Vector2(34, 0), tr("DAILY_DONE"), 24, dw.a, true)
	else:
		var pill := Rect2(Vector2(r.position.x + 30, line_y - 22), Vector2(120, 44))
		Kit.card(c, pill, 22, dw.a, dw.a.darkened(0.2), Color(0, 0, 0, 0), 0.0, false)
		Kit.text_at(c, pill.get_center(), tr("DAILY_GO"), 24, Palette.INK, true)
	if streak > 0:
		var sx := r.position.x + (210.0 if not done else 230.0)
		_star(c, Vector2(sx, line_y), 11.0, Palette.GOLD)
		Kit.text_left(c, Vector2(sx + 18, line_y), "%s %d %s" % [tr("STREAK"), streak, tr("DAY") if streak == 1 else tr("DAYS")], 22, Palette.GOLD, true)


func _draw_constellation() -> void:
	var c := _constellation
	var wi := Levels.world_index(level)
	var in_world := (level - 1) % Levels.LEVELS_PER_WORLD
	# Cabecera del mundo y su progreso.
	Kit.text_at(c, Vector2(c.size.x / 2.0, 24), "%s %d · %s" % [tr("WORLD"), wi + 1, tr(world.key)], 30, Palette.TEXT, true)
	var bar := Rect2(Vector2(c.size.x * 0.3, 52), Vector2(c.size.x * 0.4, 8))
	c.draw_colored_polygon(Kit.rounded_points(bar, 4.0, 3), Color(1, 1, 1, 0.1))
	var f := float(in_world) / Levels.LEVELS_PER_WORLD
	if f > 0.0:
		c.draw_colored_polygon(Kit.rounded_points(Rect2(bar.position, Vector2(maxf(bar.size.x * f, 8.0), 8)), 4.0, 3), world.a)
	# Nodos: 3 superados (abajo), el actual y 3 por venir (arriba).
	_nodes.clear()
	var first := maxi(1, level - 3)
	var last := first + 6
	var top_y := 110.0
	var bottom_y := c.size.y - 60.0
	var step := (bottom_y - top_y) / 6.0
	var pts := []
	for n in range(first, last + 1):
		var k := n - first
		var y := bottom_y - k * step
		var x := c.size.x / 2.0 + sin(n * 1.35) * c.size.x * 0.28
		pts.append(Vector2(x, y))
	for k in pts.size() - 1:
		var n := first + k
		if n < level:
			Kit.glow_line(c, pts[k], pts[k + 1], world.a, 3.0)
		else:
			_dashed(c, pts[k], pts[k + 1], Color(1, 1, 1, 0.18))
	for k in pts.size():
		var n := first + k
		var p: Vector2 = pts[k]
		var challenge := Levels.beat(n) == 2
		if n < level:
			var s := Progress.stars(n)
			Kit.glow_circle(c, p, 16, world.a, 0.1)
			c.draw_circle(p, 31, world.a.darkened(0.35))
			c.draw_arc(p, 31, 0, TAU, 32, world.a, 3.0, true)
			Kit.text_at(c, p, str(n), 26, Palette.TEXT, true)
			for si in 3:
				_star(c, p + Vector2((si - 1) * 18.0, 45), 8.0, Palette.GOLD if si < s else Color(1, 1, 1, 0.2))
			_nodes.append([p, n, 38.0])
		elif n == level:
			var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
			Kit.glow_circle(c, p, 34 + pulse * 6, world.a, 0.2)
			c.draw_arc(p, 54 + pulse * 6, 0, TAU, 48, Color(world.a, 0.35 * (1.0 - pulse)), 3.0, true)
			c.draw_circle(p, 50, world.a)
			c.draw_arc(p, 50, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
			Kit.text_at(c, p, str(n), 40, Palette.INK, true)
			_nodes.append([p, n, 56.0])
		else:
			var col := Palette.GOLD if challenge else Color(1, 1, 1, 0.25)
			c.draw_circle(p, 30, Color(1, 1, 1, 0.05))
			c.draw_arc(p, 30, 0, TAU, 32, col, 2.5, true)
			Kit.text_at(c, p, str(n), 25, Palette.MUTED if not challenge else Palette.GOLD, true)
			if challenge:
				_star(c, p + Vector2(0, -38), 9.0, Palette.GOLD)


func _dashed(c: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var len := a.distance_to(b)
	var d := (b - a) / len
	var s := 0.0
	while s < len:
		c.draw_line(a + d * s, a + d * minf(s + 9.0, len), col, 3.0, true)
		s += 18.0


func _star(c: Control, center: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(center + Vector2(cos(a), sin(a)) * (rad if i % 2 == 0 else rad * 0.46))
	c.draw_colored_polygon(pts, col)


func _constellation_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		for nd in _nodes:
			if ev.position.distance_to(nd[0]) <= nd[2]:
				Game.start_level(nd[1])
				return


# --- Ajustes ----------------------------------------------------------------------

func _open_settings() -> void:
	_settings = Control.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(world.top.lightened(0.06), 0.97)
	sb.set_corner_radius_all(36)
	sb.set_border_width_all(2)
	sb.border_color = Color(world.a, 0.4)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 30
	sb.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 0)
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	vb.add_child(Kit.label(tr("SETTINGS"), 44, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	_setting_row(vb, tr("SOUND"), "sound")
	_setting_row(vb, tr("VIBRATION"), "vibration")
	var row := HBoxContainer.new()
	vb.add_child(row)
	var l := Kit.label(tr("LANGUAGE"), 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var lang := Kit.button(tr("LANG_NAME"), world.a, 28)
	lang.custom_minimum_size = Vector2(200, 80)
	lang.pressed.connect(func():
		Game.set_language("ca" if Game.language() == "es" else "es")
		get_tree().reload_current_scene())
	row.add_child(lang)
	var close := Kit.button(tr("CLOSE"), world.a, 30, true)
	close.pressed.connect(_close_settings)
	vb.add_child(close)
	Kit.fade_in(_settings, 0.18)


func _setting_row(vb: VBoxContainer, label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	vb.add_child(row)
	var l := Kit.label(label_text, 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var on: bool = Progress.setting(key)
	var b := Kit.button(tr("ON") if on else tr("OFF"), world.a, 28)
	b.custom_minimum_size = Vector2(200, 80)
	b.apply_style(on)
	b.pressed.connect(func():
		var v: bool = not Progress.setting(key)
		Progress.set_setting(key, v)
		b.text = tr("ON") if v else tr("OFF")
		b.apply_style(v)
		Sfx.play("tap"))
	row.add_child(b)


func _close_settings() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
