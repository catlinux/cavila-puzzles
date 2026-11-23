extends Control
## Pantalla de juego: tablero de flechas, vidas (luces), pistas, progreso y resultado.

const Style = preload("res://ui/style.gd")
const Arrows = preload("res://game/arrows.gd")
const Levels = preload("res://game/levels.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const RoundButton = preload("res://ui/widgets/round_button.gd")
const PillButton = preload("res://ui/widgets/pill_button.gd")
const Chip = preload("res://ui/widgets/chip.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")

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

var board: Control
var _lives_ctl: Control
var _hint_chip: Control
var _moves_label: Label
## Flechas que pueden salir ahora mismo.
var moves_available := 0
var _progress: Control
var _caption: Label
var _toast: Label
var _overlay: Control
var _live: Array = []  # controles del resultado que se animan cada fotograma


func _ready() -> void:
	world = Game.world()
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 84)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	margin.add_child(vb)

	# Cabecera: volver, título, ajustes.
	var top := HBoxContainer.new()
	vb.add_child(top)
	var back := RoundButton.new("arrow-left-bold")
	back.pressed.connect(Game.go_home)
	top.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", -6)
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
	titles.add_child(Style.label(title_text, 50, Style.INK, "display", HORIZONTAL_ALIGNMENT_CENTER))
	titles.add_child(Style.label(sub_text.to_upper(), 23, Style.SUB, "body_bold", HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(titles)
	var gear := RoundButton.new("gear-six-bold")
	gear.pressed.connect(func(): add_child(SettingsPanel.new(world.a, world.b)))
	top.add_child(gear)

	# Vidas y pistas.
	var row := HBoxContainer.new()
	vb.add_child(row)
	_lives_ctl = Control.new()
	_lives_ctl.custom_minimum_size = Vector2(170, 76)
	_lives_ctl.draw.connect(_draw_lives)
	row.add_child(_lives_ctl)
	var moves_box := HBoxContainer.new()
	moves_box.add_theme_constant_override("separation", 10)
	moves_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var moves_icon := TextureRect.new()
	moves_icon.texture = Style.icon("hand-tap-fill", world.a, 34)
	moves_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	moves_box.add_child(moves_icon)
	_moves_label = Style.label("", 26, Style.SUB, "body_bold")
	moves_box.add_child(_moves_label)
	row.add_child(moves_box)
	_hint_chip = Chip.new("lightbulb-fill", Style.GOLD, str(Progress.hints()))
	_hint_chip.pressed.connect(use_hint)
	row.add_child(_hint_chip)

	# Tablero.
	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_board_input)
	vb.add_child(board)

	_caption = Style.label("", 26, Style.SUB, "body", HORIZONTAL_ALIGNMENT_CENTER)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.visible = false
	vb.add_child(_caption)

	# Progreso y reiniciar.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 26)
	vb.add_child(bottom)
	_progress = Control.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.custom_minimum_size = Vector2(0, 84)
	_progress.draw.connect(_draw_progress)
	bottom.add_child(_progress)
	var restart := RoundButton.new("arrow-counter-clockwise-bold")
	restart.pressed.connect(Game.restart)
	bottom.add_child(restart)

	_toast = Style.label("", 30, Style.INK, "display", HORIZONTAL_ALIGNMENT_CENTER)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-300, 270)
	_toast.size = Vector2(600, 60)
	_toast.modulate.a = 0.0
	add_child(_toast)

	puzzle = Game.puzzle()
	_prepare()
	_update_moves()
	if Game.mode == "level" and Game.level <= 3:
		_caption.text = tr(["TUTORIAL_1", "TUTORIAL_2", "TUTORIAL_3"][Game.level - 1])
		_caption.visible = true
		if Game.level == 1:  # en el primer nivel se señala una flecha libre, sin gastar pistas
			hint_arrow = Arrows.free_arrows(puzzle, removed)[0]
			_hint_until = INF
	Style.fade_in(self)


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


func _update_moves() -> void:
	moves_available = Arrows.free_arrows(puzzle, removed).size()
	_moves_label.text = tr("MOVES_1") if moves_available == 1 else tr("MOVES") % moves_available
	_moves_label.visible = moves_available > 0


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
		Sfx.play_chain(_combo - 1)
		Sfx.vibrate(8, 0.2)
		_update_moves()
		_burst(_px(Vector2(Arrows.head(a))), world.a, 12)
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
	Sfx.vibrate(25, 0.45)
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
	_hint_chip.set_value(str(Progress.hints()))
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
	Sfx.vibrate(15, 0.3)
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
	_cell = minf(minf((s.x - 48.0) / puzzle.w, (s.y - 48.0) / puzzle.h), 92.0)
	_origin = (s - Vector2(puzzle.w, puzzle.h) * _cell) / 2.0


func _px(v: Vector2) -> Vector2:
	return _origin + (v + Vector2(0.5, 0.5)) * _cell


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
	var card := Rect2(_origin, Vector2(puzzle.w, puzzle.h) * _cell).grow(minf(24.0, _cell * 0.6))
	Style.soft_shadow(board, card, 44.0, Style.SHADOW, 22.0, Vector2(0, 12))
	Style.fill_round(board, card, 44.0, Style.CARD)
	var shake := Vector2(sin(_clock * 70.0) * _shake * 12.0, 0)
	board.draw_set_transform(shake)
	var dot := maxf(1.6, _cell * 0.05)
	for y in puzzle.h:
		for x in puzzle.w:
			board.draw_circle(_px(Vector2(x, y)), dot, Style.DOT)
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
	var col: Color = Style.INK
	var wdt := maxf(3.0, _cell * 0.15)
	if i == hint_arrow:
		var pulse := 0.5 + 0.5 * sin(_clock * 6.0)
		col = world.a
		_stroke(pts, Color(world.a, (0.14 + 0.1 * pulse) * alpha), minf(wdt * (2.6 + 0.6 * pulse), _cell * 0.55))
	if _flash.has(i):
		col = col.lerp(Style.RED, clampf(_flash[i] / 0.5, 0.0, 1.0))
	if _anims.has(i) and _anims[i].kind == "exit":
		col = col.lerp(world.a, 0.6)
	col.a = alpha
	var d := Vector2(a.dir)
	if pts.size() >= 2 and pts[pts.size() - 1].distance_to(pts[pts.size() - 2]) > 0.01:
		d = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	var perp := Vector2(-d.y, d.x)
	var hp := pts[pts.size() - 1]
	# El cuerpo acaba en la base de la punta, para que la punta quede limpia.
	var body := pts.duplicate()
	body[body.size() - 1] = hp - d * _cell * 0.12
	_stroke(body, col, wdt)
	var tip := hp + d * _cell * 0.3
	var base := hp - d * _cell * 0.14
	var tri := PackedVector2Array([tip, base + perp * _cell * 0.25, base - perp * _cell * 0.25])
	board.draw_colored_polygon(tri, col)
	var outline := tri.duplicate()
	outline.append(tri[0])
	board.draw_polyline(outline, col, wdt * 0.45, true)


## Trazo con extremos y uniones redondeadas.
func _stroke(pts: PackedVector2Array, col: Color, width: float) -> void:
	board.draw_polyline(pts, col, width, true)
	for p in pts:
		board.draw_circle(p, width * 0.5, col)


func _burst(at: Vector2, col: Color, n: int) -> void:
	for k in n:
		var ang := randf() * TAU
		var sp := randf_range(80.0, 300.0)
		_particles.append({"p": at, "v": Vector2(cos(ang), sin(ang)) * sp, "life": randf_range(0.3, 0.55),
			"max": 0.55, "size": randf_range(2.5, 5.5), "col": col})


## Vidas: destellos del color del mundo; las perdidas, en gris.
func _draw_lives() -> void:
	var c := _lives_ctl
	for i in Game.MAX_LIVES:
		var tex := Style.icon("sparkle-fill", world.a if i < Game.lives else Style.OFF, 46)
		c.draw_texture(tex, Vector2(i * 56.0, (c.size.y - tex.get_height()) / 2.0))


func _draw_progress() -> void:
	var c := _progress
	var n: int = puzzle.arrows.size()
	var txt := tr("ARROWS_PROGRESS") % [removed.size(), n]
	c.draw_string(Style.font("body_bold"), Vector2(2, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Style.SUB)
	var bar := Rect2(Vector2(0, 52), Vector2(c.size.x, 18))
	Style.fill_round(c, bar, 9.0, Style.TRACK, 6)
	var f := float(removed.size()) / maxf(n, 1)
	if f > 0.0:
		Style.gradient_shape(c, Rect2(bar.position, Vector2(maxf(bar.size.x * f, 18.0), bar.size.y)), 9.0, world.a, world.b)


func _show_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# --- Resultado --------------------------------------------------------------------

func _show_result(is_win: bool, stars: int, bonus: int) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(Style.INK, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := Style.card(60, 44)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(580, 0)
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var born := _clock
	var stars_ctl := Control.new()
	stars_ctl.custom_minimum_size = Vector2(0, 190)
	stars_ctl.draw.connect(func(): _draw_result_stars(stars_ctl, is_win, stars, _clock - born))
	vb.add_child(stars_ctl)
	vb.add_child(Style.label(tr("WIN") if is_win else tr("LOSE"), 62, Style.INK, "display_bold", HORIZONTAL_ALIGNMENT_CENTER))
	var t := int(Game.elapsed)
	var info := "%d:%02d" % [t / 60, t % 60] if is_win else tr("LOSE_SUB")
	var info_l := Style.label(info, 30, Style.SUB, "body", HORIZONTAL_ALIGNMENT_CENTER)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info_l)
	if bonus > 0:
		vb.add_child(Style.label((tr("HINT_BONUS") if bonus == 1 else tr("HINT_BONUS_N")) % bonus, 32, Style.GOLD, "display", HORIZONTAL_ALIGNMENT_CENTER))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	vb.add_child(gap)
	var main_btn := PillButton.new(tr("CONTINUE") if is_win else tr("RETRY"), true, 122.0)
	main_btn.font_size = 46
	main_btn.set_colors(world.a, world.b)
	if is_win:
		main_btn.pressed.connect(Game.go_home if Game.mode == "daily" else Game.next_level)
	else:
		main_btn.pressed.connect(Game.restart)
	vb.add_child(main_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	vb.add_child(row)
	if is_win:
		var rep := PillButton.new(tr("REPLAY"), false, 104.0)
		rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rep.pressed.connect(Game.restart)
		row.add_child(rep)
	var home := PillButton.new(tr("HOME"), false, 104.0)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(Game.go_home)
	row.add_child(home)

	if is_win:
		var fx := Control.new()
		fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(fx)
		var bits := []
		var cols := [world.a, world.b, Style.GOLD, Color8(59, 130, 246), Color8(16, 185, 129)]
		for k in 90:
			bits.append({"p": Vector2(randf() * 720.0, randf_range(-1000.0, -20.0)), "v": randf_range(170.0, 380.0),
				"a": randf() * TAU, "w": randf_range(-5.0, 5.0), "s": randf_range(10.0, 18.0), "c": cols[k % cols.size()]})
		fx.draw.connect(func():
			var el := _clock - born
			for b in bits:
				var pos: Vector2 = b.p + Vector2(sin(el * 2.0 + b.a) * 22.0, b.v * el)
				pos.x *= fx.size.x / 720.0
				if pos.y > fx.size.y:
					continue
				var d: Vector2 = Vector2(cos(b.a + b.w * el), sin(b.a + b.w * el)) * b.s
				fx.draw_line(pos - d / 2.0, pos + d / 2.0, b.c, 7.0))
		_live.append(fx)
	_live.append(stars_ctl)

	panel.pivot_offset = Vector2(334, 330)
	panel.scale = Vector2(0.88, 0.88)
	_overlay.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.22)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_result_stars(c: Control, is_win: bool, n: int, el: float) -> void:
	var cx := c.size.x / 2.0
	var cy := c.size.y / 2.0 + 4.0
	if not is_win:
		var t := Style.icon("x-bold", Style.RED, 96)
		c.draw_circle(Vector2(cx, cy), 80, Color(Style.RED, 0.1))
		c.draw_texture(t, Vector2(cx, cy) - t.get_size() / 2.0)
		return
	for i in 3:
		var p := clampf((el - 0.15 - i * 0.22) / 0.4, 0.0, 1.0)
		var pop := 1.0 + 0.35 * sin(p * PI)
		var center := Vector2(cx + (i - 1) * 150.0, cy + (18.0 if i != 1 else -10.0))
		var size := 120.0 if i == 1 else 96.0
		var off := Style.icon("star-fill", Style.OFF, int(size))
		c.draw_texture(off, center - off.get_size() / 2.0)
		if i < n and p > 0.0:
			var s := size * p * pop
			var on := Style.icon("star-fill", Style.GOLD, int(size))
			c.draw_texture_rect(on, Rect2(center - Vector2(s, s) / 2.0, Vector2(s, s)), false)
