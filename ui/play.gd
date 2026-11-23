extends Control
## Pantalla de juego: tablero de flechas, vidas (luces), pistas, progreso y resultado.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Arrows = preload("res://game/arrows.gd")
const Levels = preload("res://game/levels.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const IconButton = preload("res://ui/icon_button.gd")

var puzzle: Dictionary = {}
var world: Dictionary = {}
var removed := {}
var finished := false
var won := false
var hint_arrow := -1

var _occ := PackedInt32Array()
var _anims := {}       # flecha -> animación en curso (salida o choque)
var _gone := {}        # flechas que ya salieron de la pantalla
var _flash := {}       # flecha -> segundos de destello coral
var _tracks: Array = []  # recorrido de cada flecha en coordenadas de casilla
var _exit_len: Array = []
var _particles: Array = []
var _hint_until := 0.0
var _shake := 0.0
var _combo := 0
var _last_exit := -10.0
var _clock := 0.0
var _cell := 40.0
var _origin := Vector2.ZERO

var _bg: Control
var board: Control
var _lives_ctl: Control
var _hint_btn: Control
var _progress: Control
var _caption: Label
var _toast: Label
var _overlay: Control
var _live: Array = []  # controles del resultado que se animan cada fotograma


func _ready() -> void:
	world = Game.world()
	_bg = Backdrop.new()
	add_child(_bg)
	_bg.set_world(world)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 52)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	# Cabecera.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	var back := IconButton.new("back")
	back.pressed.connect(Game.go_home)
	top.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", -4)
	var title_text: String
	var sub_text: String
	if Game.mode == "daily":
		title_text = tr("DAILY")
		sub_text = Game.daily_key
	else:
		title_text = "%s %d" % [tr("LEVEL"), Game.level]
		sub_text = "%s %d · %s" % [tr("WORLD"), Levels.world_index(Game.level) + 1, tr(world.key)]
		if Levels.beat(Game.level) == 2:
			sub_text += " · " + tr("CHALLENGE")
	titles.add_child(Kit.label(title_text, 40, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	titles.add_child(Kit.label(sub_text, 21, world.a.lerp(Palette.TEXT, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(titles)
	_lives_ctl = Control.new()
	_lives_ctl.custom_minimum_size = Vector2(134, 84)
	_lives_ctl.draw.connect(_draw_lives)
	top.add_child(_lives_ctl)

	# Tablero.
	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.clip_contents = true
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_board_input)
	vb.add_child(board)

	_caption = Kit.label("", 24, world.a.lerp(Palette.TEXT, 0.5))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.visible = false
	vb.add_child(_caption)

	# Barra inferior: progreso, reiniciar y pista.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	vb.add_child(bottom)
	_progress = Control.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.custom_minimum_size = Vector2(0, 92)
	_progress.draw.connect(_draw_progress)
	bottom.add_child(_progress)
	var restart := IconButton.new("restart", 92.0)
	restart.pressed.connect(Game.restart)
	bottom.add_child(restart)
	_hint_btn = IconButton.new("hint", 92.0)
	_hint_btn.accent = world.a
	_hint_btn.badge = Progress.hints()
	_hint_btn.pressed.connect(use_hint)
	bottom.add_child(_hint_btn)

	_toast = Kit.label("", 26, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-300, 170)
	_toast.size = Vector2(600, 60)
	_toast.modulate.a = 0.0
	add_child(_toast)

	puzzle = Game.puzzle()
	_prepare()
	if Game.mode == "level" and Game.level <= 3:
		_caption.text = tr(["TUTORIAL_1", "TUTORIAL_2", "TUTORIAL_3"][Game.level - 1])
		_caption.visible = true
		if Game.level == 1:  # en el primer nivel se señala una flecha libre, sin gastar pistas
			hint_arrow = Arrows.free_arrows(puzzle, removed)[0]
			_hint_until = INF
	Kit.fade_in(self)


func _prepare() -> void:
	_occ = Arrows.occupancy(puzzle)
	_tracks.clear()
	_exit_len.clear()
	for i in puzzle.arrows.size():
		var a: Dictionary = puzzle.arrows[i]
		var tr_pts := PackedVector2Array()
		for c in a.cells:
			tr_pts.append(Vector2(c))
		var r := Arrows.exit_path(puzzle, i).size()
		var hd := Vector2(Arrows.head(a))
		for k in range(1, r + a.cells.size() + 3):
			tr_pts.append(hd + Vector2(a.dir) * k)
		_tracks.append(tr_pts)
		_exit_len.append(r)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.go_home()


# --- Juego ------------------------------------------------------------------------

## Toca la flecha i. Devuelve "exit", "bump" o "none".
func tap_arrow(i: int) -> String:
	if finished or i < 0 or removed.has(i):
		return "none"
	var a: Dictionary = puzzle.arrows[i]
	var bl := Arrows.blocker(puzzle, i, _occ)
	if bl.by == -1:
		removed[i] = true
		_occ = Arrows.occupancy(puzzle, removed)
		_anims[i] = {"kind": "exit", "t": 0.0, "v": 7.0, "end": float(_exit_len[i] + a.cells.size() + 1)}
		_combo = _combo + 1 if _clock - _last_exit < 1.2 else 1
		_last_exit = _clock
		Sfx.play("pop", 1.0 + 0.06 * mini(_combo - 1, 10))
		Sfx.vibrate(12)
		_burst(_px(Vector2(Arrows.head(a))), _color(i), 12)
		if i == hint_arrow:
			hint_arrow = -1
		if Game.level == 1 and Game.mode == "level" and hint_arrow == -1:
			var free := Arrows.free_arrows(puzzle, removed)
			if not free.is_empty():
				hint_arrow = free[0]
				_hint_until = INF
		if removed.size() == puzzle.arrows.size():
			_win()
		return "exit"
	_anims[i] = {"kind": "bump", "tau": 0.0, "dur": 0.07 + bl.steps * 0.03, "amp": bl.steps + 0.28}
	_flash[i] = 0.5
	_flash[bl.by] = 0.5
	_shake = 0.5
	_combo = 0
	Game.lives -= 1
	Game.mistakes += 1
	_lives_ctl.queue_redraw()
	Sfx.play("bump")
	Sfx.vibrate(60)
	if Game.lives <= 0:
		_lose()
	return "bump"


func use_hint() -> void:
	if finished:
		return
	if Progress.hints() <= 0:
		_show_toast(tr("NO_HINTS"))
		return
	var free := Arrows.free_arrows(puzzle, removed)
	if free.is_empty():
		return
	# La más útil: la que desbloquea más flechas.
	var best: int = free[0]
	var best_n := -1
	for f in free:
		var n := 0
		for j in puzzle.arrows.size():
			if not removed.has(j) and j != f and Arrows.blocker(puzzle, j, _occ).by == f:
				n += 1
		if n > best_n:
			best_n = n
			best = f
	Progress.use_hint()
	Game.hints_used += 1
	hint_arrow = best
	_hint_until = _clock + 4.0
	_hint_btn.badge = Progress.hints()
	_hint_btn.queue_redraw()
	Sfx.play("hint")


func _win() -> void:
	finished = true
	won = true
	var stars := Levels.stars_for(Game.lives)
	var bonus := 0
	if Game.mode == "daily":
		bonus = Progress.complete_daily(Game.daily_key).hint_bonus
	else:
		bonus = Progress.complete_level(Game.level, stars).hint_bonus
	await get_tree().create_timer(0.6).timeout
	Sfx.play("win")
	Sfx.vibrate(30)
	_show_result(true, stars, bonus)


func _lose() -> void:
	finished = true
	await get_tree().create_timer(0.7).timeout
	Sfx.play("lose")
	_show_result(false, 0, 0)


func _process(delta: float) -> void:
	_clock += delta
	if not finished:
		Game.elapsed += delta
	for i in _anims.keys():
		var an: Dictionary = _anims[i]
		if an.kind == "exit":
			an.v += 75.0 * delta
			an.t += an.v * delta
			if an.t >= an.end:
				_anims.erase(i)
				_gone[i] = true
		else:
			an.tau += delta
			if an.tau >= an.dur * 2.0:
				_anims.erase(i)
	for i in _flash.keys():
		_flash[i] -= delta
		if _flash[i] <= 0.0:
			_flash.erase(i)
	for p in _particles:
		p.p += p.v * delta
		p.v *= pow(0.04, delta)
		p.life -= delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	if hint_arrow >= 0 and _clock > _hint_until:
		hint_arrow = -1
	board.queue_redraw()
	_progress.queue_redraw()
	for c in _live:
		c.queue_redraw()


# --- Entrada ----------------------------------------------------------------------

func _board_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		var i := arrow_at(ev.position)
		if i >= 0:
			tap_arrow(i)


## Flecha bajo el punto (coordenadas del tablero), con tolerancia para dedos.
func arrow_at(pos: Vector2) -> int:
	_layout()
	var q := (pos - _origin) / _cell
	var c := Vector2i(floori(q.x), floori(q.y))
	if Arrows.inside(puzzle, c) and _occ[c.y * puzzle.w + c.x] != -1:
		return _occ[c.y * puzzle.w + c.x]
	var best := -1
	var best_d := 0.8
	for i in puzzle.arrows.size():
		if removed.has(i):
			continue
		for cc in puzzle.arrows[i].cells:
			var d := q.distance_to(Vector2(cc) + Vector2(0.5, 0.5))
			if d < best_d:
				best_d = d
				best = i
	return best


# --- Dibujo -----------------------------------------------------------------------

func _layout() -> void:
	var s := board.size
	_cell = minf(minf((s.x - 24.0) / puzzle.w, (s.y - 24.0) / puzzle.h), 96.0)
	_origin = (s - Vector2(puzzle.w, puzzle.h) * _cell) / 2.0


func _px(v: Vector2) -> Vector2:
	return _origin + (v + Vector2(0.5, 0.5)) * _cell


func _color(i: int) -> Color:
	var hd := Arrows.head(puzzle.arrows[i])
	var f := float(hd.x + hd.y) / maxf(puzzle.w + puzzle.h - 2, 1)
	return world.a.lerp(world.b, f).lightened(0.06)


func _track_at(tr_pts: PackedVector2Array, x: float) -> Vector2:
	var k := clampi(floori(x), 0, tr_pts.size() - 2)
	return tr_pts[k].lerp(tr_pts[k + 1], x - k)


## Puntos (en píxeles) de la flecha i desplazada t casillas a lo largo de su recorrido.
func _window(i: int, t: float) -> PackedVector2Array:
	var tr_pts: PackedVector2Array = _tracks[i]
	var n: int = puzzle.arrows[i].cells.size()
	var s0 := t
	var s1 := t + n - 1
	var out := PackedVector2Array([_px(_track_at(tr_pts, s0))])
	for k in range(floori(s0) + 1, ceili(s1)):
		out.append(_px(tr_pts[k]))
	out.append(_px(_track_at(tr_pts, s1)))
	return out


func _offset(i: int) -> float:
	if not _anims.has(i):
		return 0.0
	var an: Dictionary = _anims[i]
	if an.kind == "exit":
		return an.t
	var p: float = an.tau / an.dur
	if p < 1.0:
		return an.amp * ease(p, 0.4)
	return an.amp * (1.0 - ease(p - 1.0, 1.8))


func _draw_board() -> void:
	if puzzle.is_empty():
		return
	_layout()
	var shake := Vector2(sin(_clock * 70.0) * _shake * 12.0, 0)
	board.draw_set_transform(shake)
	var grid := Rect2(_origin - Vector2(12, 12), Vector2(puzzle.w, puzzle.h) * _cell + Vector2(24, 24))
	Kit.card(board, grid, 26, Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 1.5, false)
	var dot := maxf(1.5, _cell * 0.045)
	for y in puzzle.h:
		for x in puzzle.w:
			board.draw_circle(_px(Vector2(x, y)), dot, Color(1, 1, 1, 0.09))
	# Primero las quietas; encima las que se mueven.
	for pass_moving in [false, true]:
		for i in puzzle.arrows.size():
			if _gone.has(i) or _anims.has(i) != pass_moving:
				continue
			_draw_arrow(i)
	for p in _particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		board.draw_circle(p.p, p.size * a, Color(p.col, a))
	board.draw_set_transform(Vector2.ZERO)


func _draw_arrow(i: int) -> void:
	var a: Dictionary = puzzle.arrows[i]
	var t := _offset(i)
	var alpha := 1.0
	if _anims.has(i) and _anims[i].kind == "exit" and t > _exit_len[i]:
		alpha = clampf(1.0 - (t - _exit_len[i]) / (a.cells.size() + 1.0), 0.0, 1.0)
	var pts := _window(i, t)
	var col := _color(i)
	var wdt := maxf(3.0, _cell * 0.17)
	if i == hint_arrow:
		var pulse := 0.5 + 0.5 * sin(_clock * 7.0)
		col = col.lerp(Palette.GOLD, 0.55 + 0.35 * pulse)
		_stroke(pts, Color(Palette.GOLD.lerp(world.bottom, 0.55 - 0.2 * pulse), alpha), wdt * (3.6 + pulse))
	if _flash.has(i):
		col = col.lerp(Palette.CORAL, clampf(_flash[i] / 0.5, 0.0, 1.0))
	col.a = alpha
	# Halo opaco (mezclado con el fondo) para que las uniones queden redondas y sin manchas.
	_stroke(pts, Color(col.lerp(world.bottom, 0.72), alpha), wdt * 2.3)
	_stroke(pts, col, wdt)
	var d := Vector2(a.dir)
	if pts.size() >= 2 and pts[pts.size() - 1].distance_to(pts[pts.size() - 2]) > 0.01:
		d = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	var perp := Vector2(-d.y, d.x)
	var hp := pts[pts.size() - 1]
	board.draw_colored_polygon(PackedVector2Array([hp + d * _cell * 0.3,
		hp - d * _cell * 0.13 + perp * _cell * 0.25, hp - d * _cell * 0.13 - perp * _cell * 0.25]), col)
	# Brillo interior para dar volumen.
	board.draw_polyline(pts, Color(1, 1, 1, 0.22 * alpha), maxf(1.0, wdt * 0.28), true)


## Trazo con extremos y uniones redondeadas.
func _stroke(pts: PackedVector2Array, col: Color, width: float) -> void:
	board.draw_polyline(pts, col, width, true)
	for p in pts:
		board.draw_circle(p, width * 0.5, col)


func _burst(at: Vector2, col: Color, n: int) -> void:
	for k in n:
		var ang := randf() * TAU
		var sp := randf_range(80.0, 320.0)
		_particles.append({"p": at, "v": Vector2(cos(ang), sin(ang)) * sp, "life": randf_range(0.3, 0.6),
			"max": 0.6, "size": randf_range(2.0, 5.0), "col": col.lerp(Color.WHITE, 0.3)})


## Vidas como destellos de luz de cuatro puntas.
func _draw_lives() -> void:
	var c := _lives_ctl
	for i in Game.MAX_LIVES:
		var p := Vector2(24 + i * 43.0, c.size.y / 2.0)
		var pts := PackedVector2Array()
		for k in 8:
			var ang := -PI / 2.0 + TAU * k / 8.0
			pts.append(p + Vector2(cos(ang), sin(ang)) * (17.0 if k % 2 == 0 else 5.5))
		if i < Game.lives:
			Kit.glow_circle(c, p, 9, world.a, 0.22)
			c.draw_colored_polygon(pts, world.a.lerp(Color.WHITE, 0.25))
			c.draw_circle(p, 3.5, Color.WHITE)
		else:
			pts.append(pts[0])
			c.draw_polyline(pts, Color(1, 1, 1, 0.22), 2.0, true)


func _draw_progress() -> void:
	var c := _progress
	var n: int = puzzle.arrows.size()
	var left := n - removed.size()
	Kit.text_left(c, Vector2(6, 26), "%d %s" % [left, tr("ARROWS_LEFT")], 24, Palette.TEXT, true)
	var bar := Rect2(Vector2(6, 54), Vector2(c.size.x - 12, 16))
	c.draw_colored_polygon(Kit.rounded_points(bar, 8.0, 4), Color(1, 1, 1, 0.08))
	var f := float(removed.size()) / maxf(n, 1)
	if f > 0.0:
		var fill := Rect2(bar.position, Vector2(maxf(bar.size.x * f, 16.0), bar.size.y))
		var pts := Kit.rounded_points(fill, 8.0, 4)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(world.a.lerp(world.b, (p.x - bar.position.x) / bar.size.x))
		c.draw_polygon(pts, cols)


func _show_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# --- Resultado --------------------------------------------------------------------

func _show_result(is_win: bool, stars: int, bonus: int) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(world.top.lightened(0.06), 0.96)
	sb.set_corner_radius_all(40)
	sb.set_border_width_all(2)
	sb.border_color = Color(world.a, 0.45)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 34
	sb.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 0)
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)

	var stars_ctl := Control.new()
	stars_ctl.custom_minimum_size = Vector2(0, 170)
	var born := _clock
	stars_ctl.draw.connect(func(): _draw_result_stars(stars_ctl, is_win, stars, _clock - born))
	vb.add_child(stars_ctl)
	vb.add_child(Kit.label(tr("WIN") if is_win else tr("LOSE"), 54,
		world.a.lerp(Color.WHITE, 0.25) if is_win else Palette.CORAL_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var t := int(Game.elapsed)
	var info := "%d:%02d" % [t / 60, t % 60] if is_win else tr("LOSE_SUB")
	vb.add_child(Kit.label(info, 26, Palette.MUTED))
	if bonus > 0:
		vb.add_child(Kit.label((tr("HINT_BONUS") if bonus == 1 else tr("HINT_BONUS_N")) % bonus, 28, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	vb.add_child(gap)

	var main_btn := Kit.button(tr("CONTINUE") if is_win else tr("RETRY"), world.a, 36, true)
	main_btn.custom_minimum_size = Vector2(0, 104)
	if is_win:
		main_btn.pressed.connect(Game.go_home if Game.mode == "daily" else Game.next_level)
	else:
		main_btn.pressed.connect(Game.restart)
	vb.add_child(main_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	if is_win:
		var rep := Kit.button(tr("REPLAY"), Palette.MUTED, 28)
		rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rep.pressed.connect(Game.restart)
		row.add_child(rep)
	var home := Kit.button(tr("HOME"), Palette.MUTED, 28)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(Game.go_home)
	row.add_child(home)

	if is_win:
		var fx := Control.new()
		fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(fx)
		var bits := []
		for k in 80:
			bits.append({"p": Vector2(randf() * 720.0, randf_range(-900.0, -20.0)), "v": randf_range(160.0, 360.0),
				"a": randf() * TAU, "w": randf_range(-5.0, 5.0), "s": randf_range(8.0, 16.0),
				"c": [world.a, world.b, Palette.GOLD, Color.WHITE][k % 4]})
		fx.draw.connect(func():
			var el := _clock - born
			for b in bits:
				var pos: Vector2 = b.p + Vector2(sin(el * 2.0 + b.a) * 20.0, b.v * el)
				pos.x *= fx.size.x / 720.0
				if pos.y > fx.size.y:
					continue
				var d: Vector2 = Vector2(cos(b.a + b.w * el), sin(b.a + b.w * el)) * b.s
				fx.draw_line(pos - d / 2.0, pos + d / 2.0, b.c, 5.0))
		_live.append(fx)
	_live.append(stars_ctl)

	panel.pivot_offset = Vector2(320, 300)
	panel.scale = Vector2(0.85, 0.85)
	_overlay.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.22)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_result_stars(c: Control, is_win: bool, n: int, el: float) -> void:
	var cx := c.size.x / 2.0
	var cy := c.size.y / 2.0 + 6.0
	if not is_win:
		for i in Game.MAX_LIVES:
			c.draw_arc(Vector2(cx + (i - 1) * 70.0, cy), 18, 0, TAU, 24, Color(1, 1, 1, 0.25), 3.0, true)
		return
	Kit.glow_circle(c, Vector2(cx, cy), 60, Palette.GOLD, 0.07)
	for i in 3:
		var p := clampf((el - 0.15 - i * 0.22) / 0.4, 0.0, 1.0)
		var pop := 1.0 + 0.4 * sin(p * PI)
		var center := Vector2(cx + (i - 1) * 130.0, cy + (16.0 if i != 1 else -12.0))
		var rad := (56.0 if i == 1 else 44.0)
		var pts := _star(center, rad)
		pts.append(pts[0])
		c.draw_polyline(pts, Color(1, 1, 1, 0.2), 3.0, true)
		if i < n and p > 0.0:
			Kit.glow_circle(c, center, rad * 0.6, Palette.GOLD, 0.1 * p)
			c.draw_colored_polygon(_star(center, rad * p * pop), Palette.GOLD.lerp(Color.WHITE, 0.1))


func _star(c: Vector2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var rr := rad if i % 2 == 0 else rad * 0.46
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts
