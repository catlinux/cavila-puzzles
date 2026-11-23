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

const MONTHS := {
	"es": ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
	"ca": ["de gener", "de febrer", "de març", "d'abril", "de maig", "de juny", "de juliol", "d'agost", "de setembre", "d'octubre", "de novembre", "de desembre"],
}

var level := 1
var world: Dictionary = {}
var _settings: Control
var _path: Control
var _clock := 0.0


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
	vb.add_theme_constant_override("separation", 34)
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
	var gear := RoundButton.new("gear-six-bold", 70.0)
	gear.pressed.connect(_open_settings)
	head.add_child(gear)

	# Tarjeta del siguiente nivel.
	var hero := Style.card(56, 40)
	vb.add_child(hero)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 26)
	hero.add_child(hv)
	var top := HBoxContainer.new()
	hv.add_child(top)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var wi := Levels.world_index(level)
	info.add_child(Style.label(("%s %d · %s" % [tr("WORLD"), wi + 1, tr(world.key)]).to_upper(), 24, world.a, "body_bold"))
	info.add_child(Style.label("%s %d" % [tr("LEVEL"), level], 86, Style.INK, "display_bold"))
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
	thumb.custom_minimum_size = Vector2(190, 250)
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
	_path.custom_minimum_size = Vector2(0, 116)
	_path.mouse_filter = Control.MOUSE_FILTER_STOP
	_path.draw.connect(_draw_path)
	_path.gui_input.connect(_path_input)
	hv.add_child(_path)
	var play := PillButton.new(tr("PLAY"), true, 122.0)
	play.icon_name = "play-fill"
	play.font_size = 48
	play.set_colors(world.a, world.b)
	play.pressed.connect(Game.start_level.bind(level))
	hv.add_child(play)

	# Reto diario y evento semanal.
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 26)
	vb.add_child(cards)
	var key := Daily.today_key()
	var d0 := Time.get_date_dict_from_system()
	var streak := Progress.streak(key)
	var streak_txt: String = tr("STREAK_NONE") if streak == 0 else (tr("STREAK_LINE_1") if streak == 1 else tr("STREAK_LINE") % streak)
	var daily_done := Progress.daily_done(key)
	var daily := _small_card("calendar-blank-fill", Color8(255, 106, 85), tr("DAILY").to_upper(),
		"%d %s" % [d0.day, MONTHS.get(Game.language(), MONTHS.es)[d0.month - 1]],
		"check-bold" if daily_done else "fire-fill", Color8(16, 185, 129) if daily_done else Color8(255, 122, 61),
		tr("DAILY_DONE") if daily_done else streak_txt)
	daily.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			Game.start_daily())
	cards.add_child(daily)
	var lg := Progress.league("daily")
	var lg_left := int(lg.end) - Progress.now()
	var lg_rows := Progress.league_standings(lg)
	var lg_rank := preload("res://game/leagues.gd").rank_of_you(lg_rows)
	var league := _small_card("crown-fill", Color8(108, 76, 245),
		"%s · %dH" % [(tr("LEAGUE_OF") % tr("LEAGUE_DAILY")).to_upper(), lg_left / 3600],
		(tr("RANK_OF") % [lg_rank, lg_rows.size()]) if int(lg.points) > 0 else tr("PLAY_TO_JOIN"),
		"trophy-fill", Style.GOLD, tr("POINTS") % Style.fmt_int(int(lg.points)))
	league.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			Game.go_leagues("daily"))
	cards.add_child(league)
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
	ic.texture = Style.icon("trophy-fill" if res.rank <= 3 else "crown-fill", Style.GOLD if res.rank <= 3 else world.a, 110)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	vb.add_child(ic)
	vb.add_child(Style.label(tr("LEAGUE_END") % tr("LEAGUE_" + String(res.type).to_upper()).to_lower(), 44, Style.INK, "display_bold", HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(Style.label(tr("YOUR_RANK") % [res.rank, res.size], 34, Style.SUB, "body", HORIZONTAL_ALIGNMENT_CENTER))
	if res.prize > 0:
		vb.add_child(Style.label((tr("HINT_BONUS") if res.prize == 1 else tr("HINT_BONUS_N")) % res.prize, 38, Style.GOLD, "display", HORIZONTAL_ALIGNMENT_CENTER))
	var change := Progress.claim_league(res.key)
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


func _small_card(icon: String, tint: Color, kicker: String, title: String, foot_icon: String, foot_col: Color, foot: String) -> PanelContainer:
	var c := Style.card(44, 30)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 300)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(76, 76)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ic.draw.connect(func():
		Style.fill_round(ic, Rect2(Vector2.ZERO, Vector2(76, 76)), 22.0, Color(tint, 0.13), 6)
		var t := Style.icon(icon, tint, 40)
		ic.draw_texture(t, Vector2(18, 18)))
	v.add_child(ic)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)
	v.add_child(Style.label(kicker, 21, Style.SUB, "body_bold"))
	var t := Style.label(title, 40, Style.INK, "display")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(t)
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 8)
	var fi := TextureRect.new()
	fi.texture = Style.icon(foot_icon, foot_col, 28)
	fi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	foot_row.add_child(fi)
	foot_row.add_child(Style.label(foot, 24, Style.SUB, "body"))
	v.add_child(foot_row)
	return c


func _process(delta: float) -> void:
	_clock += delta
	_path.queue_redraw()


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
			var segs := 24
			for i in segs:
				if i % 2 == 0:
					c.draw_arc(p, 39, TAU * i / segs, TAU * (i + 1) / segs, 4, Color(Style.INK, 0.18), 3.0, true)
			Style.text_at(c, p, str(n), 32, Style.SUB)


func _path_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		for nd in _path_nodes():
			if nd[0] <= level and ev.position.distance_to(nd[1]) < 56:
				Game.start_level(nd[0])
				return
