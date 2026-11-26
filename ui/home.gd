extends Control
## Inicio: marca, estrellas y pistas, tarjeta del siguiente nivel (miniatura, progreso del
## mundo, camino de niveles y Jugar), reto diario y evento semanal.

const Style = preload("res://ui/style.gd")
const Levels = preload("res://game/levels.gd")
const Daily = preload("res://core/daily.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const RoundButton = preload("res://ui/widgets/round_button.gd")
const PillButton = preload("res://ui/widgets/pill_button.gd")
const Chip = preload("res://ui/widgets/chip.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const Leagues = preload("res://game/leagues.gd")

## Colores de las ligas: relámpago, diaria y semanal (según la división).
const LEAGUE_COLORS := {
	"flash": [Color8(255, 122, 69), Color8(255, 176, 32)],
	"daily": [Color8(108, 76, 245), Color8(168, 85, 247)],
}
const DIVISION_COLORS := [
	[Color8(176, 112, 64), Color8(214, 150, 96)],   # bronce
	[Color8(120, 134, 156), Color8(168, 180, 198)], # plata
	[Color8(214, 158, 20), Color8(245, 196, 66)],   # oro
	[Color8(13, 148, 136), Color8(45, 212, 191)],   # platino
	[Color8(37, 99, 235), Color8(103, 232, 249)],   # diamante
]

const MONTHS := {
	"es": ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
	"ca": ["de gener", "de febrer", "de març", "d'abril", "de maig", "de juny", "de juliol", "d'agost", "de setembre", "d'octubre", "de novembre", "de desembre"],
}

var level := 1
var world: Dictionary = {}
var _settings: Control
var _path: Control
var _clock := 0.0
var _league_cards: Array = []
var _tick := 0.0


func _ready() -> void:
	level = Progress.current_level()
	world = Levels.world(level)
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 84)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 28)
	margin.add_child(vb)

	# Cabecera.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(76, 80)
	mark.draw.connect(_draw_mark.bind(mark))
	head.add_child(mark)
	var name_l := Style.label("Cavila", 50, Style.INK, "display_bold")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	head.add_child(Chip.new("star-fill", Style.GOLD, str(Progress.total_stars())))
	head.add_child(Chip.new("lightbulb-fill", Style.GOLD, str(Progress.hints())))
	if Progress.play_streak() > 0:  # racha de días jugados
		head.add_child(Chip.new("fire-fill", Color8(255, 122, 61), str(Progress.play_streak())))
	var gear := RoundButton.new("gear-six-bold", 70.0)
	gear.pressed.connect(_open_settings)
	head.add_child(gear)

	# Ligas, en portada: una tarjeta por liga con cuenta atrás y tu puesto.
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 16)
	vb.add_child(lrow)
	for t in Leagues.TYPES:
		var lc := Control.new()
		lc.custom_minimum_size = Vector2(0, 212)
		lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lc.mouse_filter = Control.MOUSE_FILTER_STOP
		lc.draw.connect(_draw_league_card.bind(lc, t))
		lc.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
				Game.go_leagues(t))
		lrow.add_child(lc)
		_league_cards.append(lc)

	# Tarjeta del siguiente nivel.
	var hero := Style.card(56, 40)
	vb.add_child(hero)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 20)
	hero.add_child(hv)
	var top := HBoxContainer.new()
	hv.add_child(top)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var wi := Levels.world_index(level)
	var tier := Levels.tier(level)
	var kicker := ("%s %d · %s" % [tr("WORLD"), wi + 1, tr(world.key)]).to_upper()
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 10)
	krow.add_child(Style.label(kicker, 24, world.a, "body_bold"))
	if Style.TIER_COLORS.has(tier):
		var badge := Control.new()
		var btxt: String = tr("TIER_" + tier.to_upper()).to_upper()
		badge.custom_minimum_size = Vector2(Style.text_width(btxt, 20, "display") + 28, 36)
		badge.draw.connect(func():
			Style.fill_round(badge, Rect2(Vector2(0, 2), badge.size - Vector2(0, 4)), 16.0, Style.TIER_COLORS[tier], 6)
			Style.text_at(badge, badge.size / 2.0, btxt, 20, Color.WHITE))
		krow.add_child(badge)
	info.add_child(krow)
	info.add_child(Style.label("%s %d" % [tr("LEVEL"), level], 78, Style.INK, "display_bold"))
	var in_world := (level - 1) % Levels.LEVELS_PER_WORLD
	var puzzle := Game.puzzle_for_level(level)
	var meta := Style.label("%d %s %d %s · %d %s" % [in_world, tr("OF"), Levels.LEVELS_PER_WORLD, tr("LEVELS_IN_WORLD"),
		puzzle.arrows.size(), tr("ARROWS_LEFT")], 25, Style.SUB, "body")
	info.add_child(meta)
	var pts_row := HBoxContainer.new()
	pts_row.add_theme_constant_override("separation", 8)
	var pi := TextureRect.new()
	pi.texture = Style.icon("trophy-fill", Style.GOLD, 28)
	pi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pts_row.add_child(pi)
	pts_row.add_child(Style.label(tr("TOTAL_POINTS") % Style.fmt_int(Progress.total_score()), 25, Style.SUB, "body"))
	info.add_child(pts_row)
	top.add_child(info)
	var thumb := Control.new()
	thumb.custom_minimum_size = Vector2(160, 206)
	thumb.draw.connect(_draw_thumb.bind(thumb, puzzle))
	top.add_child(thumb)
	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 16)
	track.draw.connect(func():
		var r := Rect2(Vector2.ZERO, track.size)
		Style.fill_round(track, r, 8.0, Style.TRACK, 6)
		var f := maxf(float(in_world) / Levels.LEVELS_PER_WORLD, 0.04)
		Style.gradient_shape(track, Rect2(r.position, Vector2(r.size.x * f, r.size.y)), 8.0, world.a, world.b))
	hv.add_child(track)
	_path = Control.new()
	_path.custom_minimum_size = Vector2(0, 104)
	_path.mouse_filter = Control.MOUSE_FILTER_STOP
	_path.draw.connect(_draw_path)
	_path.gui_input.connect(_path_input)
	hv.add_child(_path)
	var play := PillButton.new(tr("PLAY"), true, 114.0)
	play.icon_name = "play-fill"
	play.font_size = 48
	play.set_colors(world.a, world.b)
	play.pressed.connect(Game.start_level.bind(level))
	hv.add_child(play)

	# Reto diario: franja compacta.
	var key := Daily.today_key()
	var daily := Control.new()
	daily.custom_minimum_size = Vector2(0, 150)
	daily.mouse_filter = Control.MOUSE_FILTER_STOP
	daily.draw.connect(_draw_daily_strip.bind(daily, key))
	daily.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			Game.start_daily())
	vb.add_child(daily)
	Style.fade_in(self)
	_show_league_results()


## Si ha terminado alguna liga en la que participaste, muestra el resultado y da el premio.
func _show_league_results() -> void:
	var pending := Progress.pending_league_results()
	if pending.is_empty():
		return
	var res: Dictionary = pending[0]
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(Style.INK, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := Style.card(56, 44)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 0)
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var ic := TextureRect.new()
	var hints_before := Progress.hints()
	var change := Progress.claim_league(res.key)
	if change > 0:
		ic.texture = Style.reward_art("rise")  # ascenso de división
		ic.custom_minimum_size = Vector2(0, 150)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		ic.texture = Style.icon("trophy-fill" if res.rank <= 3 else "crown-fill", Style.GOLD if res.rank <= 3 else world.a, 110)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	vb.add_child(ic)
	vb.add_child(Style.label(tr("LEAGUE_END") % tr("LEAGUE_" + String(res.type).to_upper()).to_lower(), 44, Style.INK, "display_bold", HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(Style.label(tr("YOUR_RANK") % [res.rank, res.size], 34, Style.SUB, "body", HORIZONTAL_ALIGNMENT_CENTER))
	var got := Progress.hints() - hints_before
	if got > 0:
		vb.add_child(Style.label((tr("HINT_BONUS") if got == 1 else tr("HINT_BONUS_N")) % got, 38, Style.GOLD, "display", HORIZONTAL_ALIGNMENT_CENTER))
	elif res.prize > 0:
		vb.add_child(Style.label(tr("HINTS_FULL") % Progress.MAX_HINTS, 28, Style.SUB, "body", HORIZONTAL_ALIGNMENT_CENTER))
	if change != 0:
		var div_name: String = tr(preload("res://game/leagues.gd").DIVISIONS[int(Progress.data.division)])
		vb.add_child(Style.label((tr("PROMOTED") if change > 0 else tr("DEMOTED")) % div_name, 34,
			Color8(16, 185, 129) if change > 0 else Style.RED, "display", HORIZONTAL_ALIGNMENT_CENTER))
	var ok := PillButton.new(tr("OK"), true, 112.0)
	ok.set_colors(world.a, world.b)
	ok.pressed.connect(func():
		layer.queue_free()
		get_tree().reload_current_scene())
	vb.add_child(ok)
	Sfx.play("win")


func _process(delta: float) -> void:
	_clock += delta
	_path.queue_redraw()
	_tick += delta
	if _tick >= 1.0:  # cuenta atrás de las ligas
		_tick = 0.0
		for c in _league_cards:
			c.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings:
			_settings.queue_free()
			_settings = null
		else:
			get_tree().quit()


func _open_settings() -> void:
	_settings = SettingsPanel.new(world.a, world.b)
	_settings.closed.connect(func(): _settings = null)
	add_child(_settings)


# --- Dibujo -----------------------------------------------------------------------

func _league_colors(t: String) -> Array:
	if t == "weekly":
		return DIVISION_COLORS[int(Progress.data.division)]
	return LEAGUE_COLORS[t]


## Tarjeta de liga: icono, nombre, cuenta atrás y tu puesto (o invitación a entrar).
func _draw_league_card(c: Control, t: String) -> void:
	var cols := _league_colors(t)
	var r := Rect2(Vector2(2, 2), c.size - Vector2(4, 14))
	Style.soft_shadow(c, r, 34.0, Color(cols[0], 0.35), 12.0, Vector2(0, 8))
	Style.gradient_shape(c, r, 34.0, cols[0], cols[1])
	var lg := Progress.league(t)
	c.draw_texture_rect(Style.league_art(t), Rect2(Vector2(r.end.x - 72, r.position.y + 10), Vector2(62, 62)), false)
	var name: String = tr("LEAGUE_" + t.to_upper())
	if t == "weekly":
		name = tr(Leagues.DIVISIONS[int(Progress.data.division)])
	c.draw_string(Style.font("display"), r.position + Vector2(20, 96), name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30, 28, Color.WHITE)
	var left := maxi(0, int(lg.end) - Progress.now())
	var h := left / 3600
	var time_txt := ("%dd %dh" % [h / 24, h % 24]) if h >= 24 else ("%d:%02d:%02d" % [h, (left % 3600) / 60, left % 60])
	c.draw_string(Style.font("body_bold"), r.position + Vector2(20, 128), time_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))
	var big := "—"
	if int(lg.points) > 0:
		var rows := Progress.league_standings(lg)
		big = "%d.º" % Leagues.rank_of_you(rows)
	c.draw_string(Style.font("display_bold"), r.position + Vector2(20, 176), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	if int(lg.points) > 0:
		var tw := Style.text_width(big, 40, "display_bold")
		c.draw_string(Style.font("body_bold"), r.position + Vector2(26 + tw, 176), "/%d" % int(Leagues.CONFIG[t].size), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))


## Franja del reto diario: icono, fecha, racha y botón.
func _draw_daily_strip(c: Control, key: String) -> void:
	var r := Rect2(Vector2(2, 2), c.size - Vector2(4, 14))
	Style.soft_shadow(c, r, 40.0, Style.SHADOW, 16.0, Vector2(0, 10))
	Style.fill_round(c, r, 40.0, Style.CARD)
	var tint := Color8(255, 106, 85)
	Style.fill_round(c, Rect2(r.position + Vector2(24, (r.size.y - 76) / 2.0), Vector2(76, 76)), 22.0, Color(tint, 0.13), 6)
	c.draw_texture(Style.icon("calendar-blank-fill", tint, 40), r.position + Vector2(42, r.size.y / 2.0 - 20))
	var d0 := Time.get_date_dict_from_system()
	var done := Progress.daily_done(key)
	c.draw_string(Style.font("body_bold"), r.position + Vector2(124, r.size.y / 2.0 - 12), tr("DAILY").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Style.SUB)
	c.draw_string(Style.font("display"), r.position + Vector2(124, r.size.y / 2.0 + 28), "%d %s" % [d0.day, MONTHS.get(Game.language(), MONTHS.es)[d0.month - 1]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Style.INK)
	var streak := Progress.streak(key)
	var pill := Rect2(Vector2(r.end.x - 196, r.get_center().y - 34), Vector2(172, 68))
	if done:
		c.draw_texture(Style.icon("check-bold", Color8(16, 185, 129), 34), Vector2(pill.position.x + 20, pill.get_center().y - 17))
		c.draw_string(Style.font("display"), Vector2(pill.position.x + 62, pill.get_center().y + 10), tr("DAILY_DONE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color8(16, 185, 129))
	else:
		Style.gradient_shape(c, pill, 34.0, tint, Color8(255, 154, 61))
		Style.text_at(c, pill.get_center(), tr("DAILY_GO"), 30, Color.WHITE)
	if streak > 0:
		var fx := r.position.x + 124 + Style.text_width("%d %s" % [d0.day, MONTHS.get(Game.language(), MONTHS.es)[d0.month - 1]], 36, "display") + 22
		c.draw_texture(Style.icon("fire-fill", Color8(255, 122, 61), 28), Vector2(fx, r.size.y / 2.0 + 2))
		c.draw_string(Style.font("display"), Vector2(fx + 32, r.size.y / 2.0 + 26), str(streak), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color8(255, 122, 61))

## Marca: flecha que gira hacia arriba sobre una placa con el degradado del mundo.
func _draw_mark(c: Control) -> void:
	var r := Rect2(Vector2(2, 6), Vector2(68, 68))
	Style.soft_shadow(c, r, 22.0, Color(world.a, 0.3), 10.0, Vector2(0, 6))
	Style.gradient_shape(c, r, 22.0, world.a, world.b)
	var o := r.position
	var s := r.size.x / 26.0
	c.draw_polyline(PackedVector2Array([o + Vector2(7, 20) * s, o + Vector2(7, 13) * s, o + Vector2(14, 13) * s, o + Vector2(14, 8) * s]), Color.WHITE, 3.4 * s)
	for p in [Vector2(7, 20), Vector2(7, 13), Vector2(14, 13)]:
		c.draw_circle(o + p * s, 1.7 * s, Color.WHITE)
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(14, 3.2) * s, o + Vector2(18.6, 8.8) * s, o + Vector2(9.4, 8.8) * s]), Color.WHITE)
	c.draw_circle(o + Vector2(20, 20) * s, 2.5 * s, Color(1, 1, 1, 0.85))


func _draw_thumb(c: Control, p: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	Style.fill_round(c, r, 34.0, Style.SOFT)
	var inner := r.grow(-16)
	var cs := minf(inner.size.x / p.w, inner.size.y / p.h)
	var o := inner.position + (inner.size - Vector2(p.w, p.h) * cs) / 2.0
	var wdt := maxf(1.4, cs * 0.2)
	for a in p.arrows:
		var pts := PackedVector2Array()
		for cell in a.cells:
			pts.append(o + (Vector2(cell) + Vector2(0.5, 0.5)) * cs)
		c.draw_polyline(pts, Style.INK, wdt, true)
		var hp := pts[pts.size() - 1]
		var d := Vector2(a.dir)
		var pr := Vector2(-d.y, d.x)
		c.draw_colored_polygon(PackedVector2Array([hp + d * cs * 0.35, hp - d * cs * 0.1 + pr * cs * 0.28, hp - d * cs * 0.1 - pr * cs * 0.28]), Style.INK)


func _path_nodes() -> Array:
	var out := []
	var first := maxi(1, level - 2)
	var w := _path.size.x
	for k in 5:
		out.append([first + k, Vector2(w * (0.1 + 0.2 * k), _path.size.y / 2.0)])
	return out


func _draw_path() -> void:
	var c := _path
	for nd in _path_nodes():
		var n: int = nd[0]
		var p: Vector2 = nd[1]
		if n < level:
			c.draw_circle(p, 40, Color(world.a, 0.13))
			Style.text_at(c, p, str(n), 32, world.a)
		elif n == level:
			var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
			for i in 6:
				c.draw_circle(p + Vector2(0, 10), 54.0 + i * 3.0, Color(world.a, 0.035 * (1.0 + pulse * 0.5)))
			var r := Rect2(p - Vector2(52, 52), Vector2(104, 104))
			Style.gradient_shape(c, r, 52.0, world.a, world.b)
			Style.text_at(c, p, str(n), 42, Color.WHITE)
		else:
			var t := Levels.tier(n)
			var ring_col: Color = Style.TIER_COLORS.get(t, Color(Style.INK, 0.18)) if t != "easy" else Color(Style.INK, 0.18)
			var segs := 24
			for i in segs:
				if i % 2 == 0 or t in ["hard", "super", "extra"]:
					c.draw_arc(p, 39, TAU * i / segs, TAU * (i + 1) / segs, 4, ring_col, 3.0 if t not in ["super", "extra"] else 5.0, true)
			Style.text_at(c, p, str(n), 32, ring_col if t in ["hard", "super", "extra"] else Style.SUB)


func _path_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		for nd in _path_nodes():
			if nd[0] <= level and ev.position.distance_to(nd[1]) < 56:
				Game.start_level(nd[0])
				return
