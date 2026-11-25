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
## Flecha que se activará al soltar el dedo (se ilumina mientras se mantiene pulsado).
var _cand := -1

var _occ := PackedInt32Array()
var _anims := {}       # flecha -> animación en curso (salida o choque)
var _gone := {}        # flechas que ya salieron de la pantalla
var _flash := {}       # flecha -> segundos de destello coral
var _tracks: Array = []  # recorrido de cada flecha en coordenadas de casilla
var _boxes: Array = []   # rectángulo que ocupa cada flecha (para descartar rápido al tocar)
var _exit_len: Array = []
var _exit_enclosed: Array = []  # true si tras el hueco de salida vuelve a haber tablero
var _exit_hole: Array = []  # true si la salida termina en un hueco (no en el borde del tablero)
var _particles: Array = []
var _hint_until := 0.0
var _shake := 0.0
var _combo := 0
var _combo_points := 0
var rival_time := 60.0
var score := 0
var _rival_announced := false
var _record := false
var _last_exit := -10.0
var _clock := 0.0
var _cell := 40.0
var _origin := Vector2.ZERO
# Zoom y desplazamiento (tableros grandes).
var _zoom := 1.0
var _pan := Vector2.ZERO
var _touches := {}
var _press_pos := Vector2.ZERO
var _pan0 := Vector2.ZERO
var _moved := false
var _mouse_down := false
var _pinch_d0 := 1.0
var _zoom0 := 1.0
var _last_mid := Vector2.ZERO
var _fit_btn: Control
var _holes := {}
var _corridor := {}  # huecos por los que salen las flechas: se pintan como tablero
var _fx: Control  # capa de piezas en movimiento, destellos y partículas
var _dyn_key := ""
var piece_style := "arrows"
## Estilo "colores": un tono suave por dirección (arriba, abajo, izquierda, derecha).
const DIRS_ORDER := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const DIR_COLORS := [Color8(37, 99, 235), Color8(13, 148, 136), Color8(192, 38, 211), Color8(234, 88, 12)]
var _rocks := {}

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
		if Levels.params_for(Game.level).maze:
			sub_text += " · " + tr("MAZE")
	titles.add_child(Style.label(title_text, 50, Style.INK, "display", HORIZONTAL_ALIGNMENT_CENTER))
	titles.add_child(Style.label(sub_text.to_upper(), 23, Style.SUB, "body_bold", HORIZONTAL_ALIGNMENT_CENTER))
	var tier := Levels.tier(Game.level) if Game.mode == "level" else "normal"
	if Style.TIER_COLORS.has(tier):
		titles.add_child(Style.label(tr("TIER_" + tier.to_upper()).to_upper(), 24, Style.TIER_COLORS[tier], "display", HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(titles)
	var gear := RoundButton.new("gear-six-bold")
	gear.pressed.connect(func():
		var sp := SettingsPanel.new(world.a, world.b)
		sp.style_changed.connect(func():
			piece_style = Progress.setting("piece_style")
			board.queue_redraw())
		add_child(sp))
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
	board.clip_contents = true
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	board.add_child(_fx)
	piece_style = Progress.setting("piece_style")
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
	_progress.custom_minimum_size = Vector2(0, 108)
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
	for c in puzzle.get("holes", []):
		_holes[c] = true
	for c in puzzle.get("rocks", []):
		_rocks[c] = true
	_prepare()
	if Game.mode == "level":
		Game.prefetch(Game.level + 1)
	rival_time = Levels.rival_time(puzzle.arrows.size(), int(puzzle.get("depth", 0)), Game.seed_value())
	_update_moves()
	# Botón para volver a ver el tablero entero (solo visible con zoom).
	_fit_btn = RoundButton.new("arrows-in-simple-bold", 76.0)
	_fit_btn.visible = false
	_fit_btn.pressed.connect(func():
		_zoom = 1.0
		_pan = Vector2.ZERO
		_fit_btn.visible = false
		board.queue_redraw())
	board.add_child(_fit_btn)
	board.resized.connect(func(): _fit_btn.position = Vector2(board.size.x - 92, 8))
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
	_exit_hole.clear()
	_exit_enclosed.clear()
	_boxes.clear()
	for i in puzzle.arrows.size():
		var a: Dictionary = puzzle.arrows[i]
		var box := Rect2(Vector2(a.cells[0]), Vector2.ZERO)
		for c in a.cells:
			box = box.expand(Vector2(c))
		_boxes.append(box)
		var tr_pts := PackedVector2Array()
		for c in a.cells:
			tr_pts.append(Vector2(c))
		var r := Arrows.exit_path(puzzle, i).size()
		var hd := Vector2(Arrows.head(a))
		for k in range(1, r + a.cells.size() + 3):
			tr_pts.append(hd + Vector2(a.dir) * k)
		_tracks.append(tr_pts)
		_exit_len.append(r)
		# La salida termina en un hueco si la casilla siguiente a su último tramo sigue dentro de la
		# cuadrícula (si no, ha llegado al borde del tablero).
		_exit_hole.append(Arrows.inside(puzzle, Arrows.head(a) + a.dir * (r + 1)))
		var q: Vector2i = Arrows.head(a) + a.dir * (r + 1)
		while Arrows.inside(puzzle, q) and _holes.has(q):
			q += a.dir
		_exit_enclosed.append(_exit_hole[_exit_hole.size() - 1] and Arrows.inside(puzzle, q))


## Cuánto se tarda en desvanecerse una flecha que sale (en casillas de recorrido). Al salir por
## un hueco desaparece enseguida: ya está fuera del tablero y no debe sobrevolar el resto.
func _fade_len(i: int) -> float:
	if _exit_enclosed[i]:
		return 1.5  # sale por un hueco y detrás hay más tablero: no debe sobrevolarlo
	return 3.0 if _exit_hole[i] else float(puzzle.arrows[i].cells.size() + 1)


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
		_anims[i] = {"kind": "exit", "t": 0.0, "v": 7.0, "end": float(_exit_len[i]) + _fade_len(i)}
		_combo = _combo + 1 if _clock - _last_exit < 1.2 else 1
		if _combo >= 3:
			_combo_points += 5 * (_combo - 2)
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
	score = Levels.score(puzzle.arrows.size(), Game.difficulty(), Game.elapsed, Game.lives, _combo_points, rival_time)
	var bonus := 0
	_record = false
	if Game.mode == "daily":
		bonus = Progress.complete_daily(Game.daily_key).hint_bonus
		Progress.add_league_points(score)
		Progress.save()
	else:
		var r := Progress.complete_level(Game.level, stars, score)
		bonus = r.hint_bonus
		_record = r.record
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
		if not _rival_announced and Game.elapsed >= rival_time:
			_rival_announced = true
			_show_toast(tr("RIVAL_DONE"))
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
	# La capa fija solo se redibuja cuando cambia qué piezas se mueven (o durante una sacudida).
	var dyn := "%s|%s|%d|%d" % [_anims.keys(), _flash.keys(), hint_arrow, _cand]
	if dyn != _dyn_key or _shake > 0.0:
		_dyn_key = dyn
		board.queue_redraw()
	_fx.queue_redraw()
	_progress.queue_redraw()
	for c in _live:
		c.queue_redraw()


# --- Entrada ----------------------------------------------------------------------

func _board_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_press_pos = ev.position
				_pan0 = _pan
				_moved = false
				_set_cand(arrow_at(ev.position))
			elif _touches.size() == 2:
				var pts: Array = _touches.values()
				_pinch_d0 = maxf(pts[0].distance_to(pts[1]), 1.0)
				_zoom0 = _zoom
				_last_mid = (pts[0] + pts[1]) / 2.0
				_moved = true
				_set_cand(-1)
		else:
			_touches.erase(ev.index)
			if _touches.is_empty():
				_release()
			elif _touches.size() == 1:
				_press_pos = _touches.values()[0]
				_pan0 = _pan
	elif ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var mid: Vector2 = (pts[0] + pts[1]) / 2.0
			_zoom_at(_zoom0 * pts[0].distance_to(pts[1]) / _pinch_d0, mid)
			_pan += mid - _last_mid
			_last_mid = mid
			_clamp_pan()
		elif _touches.size() == 1:
			_drag_to(ev.position)
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = ev.pressed
			if ev.pressed:
				_press_pos = ev.position
				_pan0 = _pan
				_moved = false
				_set_cand(arrow_at(ev.position))
			else:
				_release()
		elif ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(_zoom * (1.15 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), ev.position)
	elif ev is InputEventMouseMotion and _mouse_down and ev.device != InputEvent.DEVICE_ID_EMULATION:
		_drag_to(ev.position)
	elif ev is InputEventMagnifyGesture:
		_zoom_at(_zoom * ev.factor, ev.position)


func _set_cand(i: int) -> void:
	if i != _cand:
		_cand = i
		board.queue_redraw()


## Al soltar: se activa la flecha iluminada (si la hay y no se ha arrastrado el tablero).
func _release() -> void:
	var i := _cand
	var panned := _moved
	_set_cand(-1)
	if i >= 0 and not panned:
		tap_arrow(i)


## Arrastre de un dedo: con zoom desplaza el tablero (pasados unos píxeles); sin zoom, o
## mientras no se supere ese umbral, el resaltado sigue al dedo para poder corregir la elección.
func _drag_to(pos: Vector2) -> void:
	var dist := pos.distance_to(_press_pos)
	if _zoom > 1.01 and (_moved or dist > 14.0):
		_moved = true
		_pan = _pan0 + (pos - _press_pos)
		_clamp_pan()
		_set_cand(-1)
	else:
		_set_cand(arrow_at(pos))


func _base_cell() -> float:
	var s := board.size
	return minf(minf((s.x - 48.0) / puzzle.w, (s.y - 48.0) / puzzle.h), 92.0)


## Zoom máximo: casillas de unos 60 px (solo los tableros grandes permiten zoom).
func _max_zoom() -> float:
	return clampf(60.0 / _base_cell(), 1.0, 3.5)


## Cambia el zoom manteniendo fijo el punto del tablero que está bajo `at`.
func _zoom_at(z: float, at: Vector2) -> void:
	_layout()
	var q := (at - _origin) / _cell
	_zoom = clampf(z, 1.0, _max_zoom())
	var cell2 := _base_cell() * _zoom
	var origin2 := at - q * cell2
	_pan = origin2 - board.size / 2.0 + Vector2(puzzle.w, puzzle.h) * cell2 / 2.0
	_clamp_pan()


func _clamp_pan() -> void:
	if _zoom <= 1.001:
		_pan = Vector2.ZERO
	else:
		var extra := (Vector2(puzzle.w, puzzle.h) * _base_cell() * _zoom - board.size) / 2.0 + Vector2(40, 40)
		extra = extra.max(Vector2.ZERO)
		_pan = _pan.clamp(-extra, extra)
	if _fit_btn:
		_fit_btn.visible = _zoom > 1.01
	board.queue_redraw()


## Radio del dedo (px de pantalla de diseño) y margen para preferir una flecha libre.
const DOT_COL := Color8(196, 204, 221)  # puntos del fondo, más marcados que Style.DOT
const FINGER_PX := 46.0
const FAIR_PX := 22.0


## Flecha bajo el punto (coordenadas del tablero), con tolerancia para dedos:
##  - se mide la distancia al trazo completo de cada flecha (cuerpo y punta);
##  - solo cuentan las flechas dentro del radio de un dedo;
##  - si el toque es dudoso entre una flecha que chocaría y otra casi igual de cerca que
##    puede salir, se elige la que puede salir. Tocar claramente una flecha bloqueada
##    sigue contando como choque.
func arrow_at(pos: Vector2) -> int:
	_layout()
	var q := (pos - _origin) / _cell - Vector2(0.5, 0.5)  # en casillas, centros enteros
	var radius := clampf(FINGER_PX / _cell, 0.7, 1.5)
	var slack := clampf(FAIR_PX / _cell, 0.3, 0.6)
	var cands := []
	for i in puzzle.arrows.size():
		if removed.has(i):
			continue
		var box: Rect2 = _boxes[i]
		if not box.grow(radius + 0.5).has_point(q):
			continue
		var d := _dist_to_arrow(i, q)
		if d <= radius:
			cands.append([d, i])
	if cands.is_empty():
		return -1
	cands.sort_custom(func(x, y): return x[0] < y[0])
	var best: int = cands[0][1]
	if not Arrows.can_exit(puzzle, best, _occ):
		for c in cands:
			if c[0] <= cands[0][0] + slack and Arrows.can_exit(puzzle, c[1], _occ):
				return c[1]
	return best


## Distancia (en casillas) de un punto al dibujo de la flecha i: su cuerpo y su punta.
func _dist_to_arrow(i: int, q: Vector2) -> float:
	var a: Dictionary = puzzle.arrows[i]
	var cells: Array = a.cells
	var best := INF
	for k in cells.size():
		var p0 := Vector2(cells[k])
		var p1 := Vector2(cells[k]) + Vector2(a.dir) * 0.3 if k == cells.size() - 1 else Vector2(cells[k + 1])
		best = minf(best, _seg_dist(q, p0, p1))
	return best


static func _seg_dist(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() == 0.0 else clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return q.distance_to(a + ab * t)


# --- Dibujo -----------------------------------------------------------------------

func _layout() -> void:
	_cell = _base_cell() * _zoom
	_origin = board.size / 2.0 + _pan - Vector2(puzzle.w, puzzle.h) * _cell / 2.0


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


func _is_dynamic(i: int) -> bool:
	return _anims.has(i) or _flash.has(i) or i == hint_arrow or i == _cand


## Capa fija: forma del tablero, puntos, rocas y piezas quietas.
func _draw_board() -> void:
	if puzzle.is_empty():
		return
	_layout()
	_draw_shape()
	board.draw_set_transform(_shake_offset())
	var dot := maxf(2.2, _cell * 0.075)
	for y in puzzle.h:
		for x in puzzle.w:
			var c := Vector2i(x, y)
			if _holes.has(c):
				continue
			if _rocks.has(c):
				_draw_rock(c)
			else:
				board.draw_circle(_px(Vector2(x, y)), dot, DOT_COL)
	for i in puzzle.arrows.size():
		if not _gone.has(i) and not _is_dynamic(i):
			_draw_arrow(board, i)
	board.draw_set_transform(Vector2.ZERO)


## Capa en movimiento: piezas saliendo o chocando, pista y partículas (cada fotograma).
func _draw_fx() -> void:
	if puzzle.is_empty():
		return
	_layout()
	_fx.draw_set_transform(_shake_offset())
	for i in puzzle.arrows.size():
		if not _gone.has(i) and _is_dynamic(i):
			_draw_arrow(_fx, i)
	for p in _particles:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		_fx.draw_circle(p.p, p.size * a, Color(p.col, a))
	_fx.draw_set_transform(Vector2.ZERO)


func _shake_offset() -> Vector2:
	return Vector2(sin(_clock * 70.0) * _shake * 12.0, 0)


func _draw_arrow(c: CanvasItem, i: int) -> void:
	var a: Dictionary = puzzle.arrows[i]
	var t := _offset(i)
	var alpha := 1.0
	if _anims.has(i) and _anims[i].kind == "exit" and t > _exit_len[i]:
		alpha = clampf(1.0 - (t - _exit_len[i]) / _fade_len(i), 0.0, 1.0)
	var pts := _round_corners(_window(i, t), _cell * CORNER_RADIUS)
	var col: Color = Style.INK
	var wdt := maxf(3.0, _cell * 0.15)
	if piece_style == "colors":
		col = DIR_COLORS[DIRS_ORDER.find(a.dir)]
	if i == hint_arrow:
		var pulse := 0.5 + 0.5 * sin(_clock * 6.0)
		col = Style.GOLD
		_stroke(c, pts, Color(Style.GOLD, (0.18 + 0.12 * pulse) * alpha), minf(wdt * (2.6 + 0.6 * pulse), _cell * 0.55))
	if i == _cand and not _anims.has(i):
		# Elegida con el dedo: halo y color del mundo (no revela si está bloqueada).
		col = col.lerp(world.a, 0.75)
		_stroke(c, pts, Color(world.a, 0.28 * alpha), minf(wdt * 3.6, _cell * 0.8))
	if _flash.has(i):
		col = col.lerp(Style.RED, clampf(_flash[i] / 0.5, 0.0, 1.0))
	if _anims.has(i) and _anims[i].kind == "exit":
		col = col.lerp(world.a, 0.6)
	col.a = alpha
	var moving: bool = _anims.has(i) and _anims[i].kind == "exit"
	if moving or (i == _cand and not _anims.has(i)):
		# Contorno blanco: la pieza se distingue de las que pasan por debajo.
		_stroke(c, pts, Color(Style.CARD, 0.92 * alpha), wdt + maxf(3.0, _cell * 0.1))
	var d := Vector2(a.dir)
	if pts.size() >= 2 and pts[pts.size() - 1].distance_to(pts[pts.size() - 2]) > 0.01:
		d = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	match piece_style:
		"comets":
			_draw_comet(c, pts, d, col, wdt)
		"soft":
			_draw_soft(c, pts, d, col, wdt)
		"colors":
			_draw_arrow_shape(c, pts, d, col, wdt)
		_:
			_draw_arrow_shape(c, pts, d, col, wdt)


## Flecha clásica: trazo con punta triangular.
func _draw_arrow_shape(c: CanvasItem, pts: PackedVector2Array, d: Vector2, col: Color, wdt: float) -> void:
	var perp := Vector2(-d.y, d.x)
	var hp := pts[pts.size() - 1]
	# El cuerpo acaba en la base de la punta, para que la punta quede limpia.
	var body := pts.duplicate()
	body[body.size() - 1] = hp - d * _cell * 0.12
	_stroke(c, body, col, wdt)
	var tip := hp + d * _cell * 0.3
	var base := hp - d * _cell * 0.14
	var tri := PackedVector2Array([tip, base + perp * _cell * 0.25, base - perp * _cell * 0.25])
	c.draw_colored_polygon(tri, col)
	var outline := tri.duplicate()
	outline.append(tri[0])
	c.draw_polyline(outline, col, wdt * 0.45, true)


## Cometa: trazo que se afina hacia la cola y termina en una cabeza redonda con un brillo
## en la parte delantera. Avanza hacia la cabeza.
func _draw_comet(c: CanvasItem, pts: PackedVector2Array, d: Vector2, col: Color, wdt: float) -> void:
	var total := 0.0
	for k in pts.size() - 1:
		total += pts[k].distance_to(pts[k + 1])
	var step := maxf(1.5, wdt * 0.35)
	var walked := 0.0
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var seg := a.distance_to(b)
		var s := 0.0
		while s < seg:
			var f := (walked + s) / maxf(total, 1.0)
			var r := lerpf(wdt * 0.32, wdt * 0.62, f)
			c.draw_circle(a.lerp(b, s / seg), r, Color(col, col.a * lerpf(0.55, 1.0, f)))
			s += step
		walked += seg
	var hp := pts[pts.size() - 1]
	var hr := maxf(wdt * 1.5, _cell * 0.27)
	c.draw_circle(hp, hr, col)
	c.draw_circle(hp + d * hr * 0.42, hr * 0.32, Color(1, 1, 1, 0.9 * col.a))


## Suave: trazo limpio con la punta en forma de gota (redonda detrás, afilada delante).
func _draw_soft(c: CanvasItem, pts: PackedVector2Array, d: Vector2, col: Color, wdt: float) -> void:
	var hp := pts[pts.size() - 1]
	var r := _cell * 0.26
	var center := hp - d * r * 0.25
	var body := pts.duplicate()
	body[body.size() - 1] = center
	_stroke(c, body, col, wdt)
	var perp := Vector2(-d.y, d.x)
	var drop := PackedVector2Array()
	for k in 17:
		var ang := PI * 0.5 + PI * k / 16.0  # media circunferencia trasera
		drop.append(center + (d * cos(ang) + perp * sin(ang)) * r)
	drop.append(center + d * r * 2.0)  # punta
	c.draw_colored_polygon(drop, col)


## Fondo blanco con la silueta del tablero (unión de casillas redondeadas, sin los huecos).
func _draw_shape() -> void:
	var g := minf(22.0, _cell * 0.55)
	if _holes.is_empty():
		var card := Rect2(_origin, Vector2(puzzle.w, puzzle.h) * _cell).grow(g)
		Style.soft_shadow(board, card, 44.0, Style.SHADOW, 22.0, Vector2(0, 12))
		Style.fill_round(board, card, 44.0, Style.CARD)
		return
	if _corridor.is_empty():
		# Huecos por los que salen las flechas (los que recorre su cabeza al desvanecerse).
		for i in puzzle.arrows.size():
			if _exit_hole[i]:
				var hd: Vector2i = Arrows.head(puzzle.arrows[i]) + puzzle.arrows[i].dir * (_exit_len[i] + 1)
				for k in 3:
					var cc: Vector2i = hd + puzzle.arrows[i].dir * k
					if not _holes.has(cc):
						break
					_corridor[cc] = true
		_corridor[Vector2i(-1, -1)] = true  # marca de "ya calculado"
	# Casillas solapadas con esquinas poco redondeadas: el borde queda escalonado y limpio.
	# Margen amplio y esquinas grandes: los entrantes se suavizan y las flechas del borde
	# quedan claramente dentro del tablero.
	g = _cell * 0.62
	var rad := _cell * 0.55
	for pass_i in 2:
		for y in puzzle.h:
			for x in puzzle.w:
				if _holes.has(Vector2i(x, y)):
					continue
				var r := Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell)).grow(g)
				if pass_i == 0:
					Style.fill_round(board, Rect2(r.position + Vector2(0, 10), r.size).grow(6), rad, Color(Style.SHADOW, 0.035), 4)
				else:
					Style.fill_round(board, r, rad, Style.CARD, 4)
	# Canales de salida: el hueco por el que sale una flecha es EXTERIOR al tablero. Se pinta
	# del color del fondo, de una casilla de ancho y centrado en la línea de la flecha: así se ve
	# dónde sale y que lo que haya más allá ya no cuenta.
	for c in _corridor:
		if c.x < 0:
			continue
		var cr := Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))
		Style.fill_round(board, cr, _cell * 0.3, Color(Style.BG, 1.0), 4)
		Style.fill_round(board, Rect2(cr.position, Vector2(cr.size.x, _cell * 0.1)), _cell * 0.05, Color(Style.SHADOW, 0.05), 3)


## Obstáculo: bloque de piedra oscuro con relieve, claramente infranqueable.
func _draw_rock(c: Vector2i) -> void:
	var r := Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell)).grow(-_cell * 0.04)
	var rad := _cell * 0.2
	Style.fill_round(board, Rect2(r.position + Vector2(0, _cell * 0.08), r.size), rad, Color8(92, 102, 122), 4)
	Style.fill_round(board, r, rad, Color8(132, 142, 162), 4)
	Style.fill_round(board, Rect2(r.position + Vector2(r.size.x * 0.16, r.size.y * 0.14), r.size * Vector2(0.42, 0.16)), _cell * 0.07, Color(1, 1, 1, 0.35), 3)
	# Dos grietas para que se lea como piedra.
	var o := r.position
	var s := r.size.x
	board.draw_line(o + Vector2(0.62, 0.45) * s, o + Vector2(0.78, 0.68) * s, Color8(100, 110, 130), maxf(1.0, _cell * 0.05), true)
	board.draw_line(o + Vector2(0.3, 0.6) * s, o + Vector2(0.42, 0.8) * s, Color8(100, 110, 130), maxf(1.0, _cell * 0.05), true)


## Trazo con extremos redondeados (las esquinas ya vienen suavizadas con _round_corners).
func _stroke(c: CanvasItem, pts: PackedVector2Array, col: Color, width: float) -> void:
	c.draw_polyline(pts, col, width, true)
	if pts.size() > 0:
		c.draw_circle(pts[0], width * 0.5, col)
		c.draw_circle(pts[pts.size() - 1], width * 0.5, col)


## Radio de las curvas, en casillas (0.5 = el máximo: el giro ocupa media casilla).
const CORNER_RADIUS := 0.2


## Sustituye cada esquina del recorrido por un arco (curva de Bézier cuadrática), sin pasar
## de la mitad de los tramos vecinos. Los tramos rectos no se tocan.
func _round_corners(pts: PackedVector2Array, radius: float) -> PackedVector2Array:
	if pts.size() < 3 or radius < 1.5:
		return pts
	var out := PackedVector2Array([pts[0]])
	for k in range(1, pts.size() - 1):
		var a := pts[k - 1]
		var b := pts[k]
		var c := pts[k + 1]
		var d1 := (b - a)
		var d2 := (c - b)
		var l1 := d1.length()
		var l2 := d2.length()
		if l1 < 0.01 or l2 < 0.01:
			continue
		d1 /= l1
		d2 /= l2
		if absf(d1.cross(d2)) < 0.01:  # tramo recto: no hay esquina
			out.append(b)
			continue
		var r := minf(radius, minf(l1, l2) * 0.5)
		var p0 := b - d1 * r
		var p2 := b + d2 * r
		var steps := 6
		for s in range(steps + 1):
			var t := float(s) / steps
			out.append((1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * b + t * t * p2)
	out.append(pts[pts.size() - 1])
	return out


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


## Dos barras: la tuya (flechas despejadas) y la de la máquina (avanza con el tiempo).
func _draw_progress() -> void:
	var c := _progress
	var n: int = puzzle.arrows.size()
	var txt := tr("ARROWS_PROGRESS") % [removed.size(), n]
	c.draw_string(Style.font("body_bold"), Vector2(2, 26), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Style.SUB)
	var left := 70.0
	var you := Style.icon("user-fill", world.a, 26)
	var bot := Style.icon("robot-fill", Style.SUB, 26)
	var bar := Rect2(Vector2(left, 46), Vector2(c.size.x - left, 16))
	c.draw_texture(you, Vector2(8, bar.get_center().y - 13))
	Style.fill_round(c, bar, 8.0, Style.TRACK, 6)
	var f := float(removed.size()) / maxf(n, 1)
	if f > 0.0:
		Style.gradient_shape(c, Rect2(bar.position, Vector2(maxf(bar.size.x * f, 16.0), bar.size.y)), 8.0, world.a, world.b)
	var bar2 := Rect2(Vector2(left, 80), Vector2(c.size.x - left, 12))
	c.draw_texture(bot, Vector2(8, bar2.get_center().y - 13))
	Style.fill_round(c, bar2, 6.0, Style.TRACK, 6)
	var rf := clampf(Game.elapsed / rival_time, 0.0, 1.0)
	if rf > 0.0:
		Style.fill_round(c, Rect2(bar2.position, Vector2(maxf(bar2.size.x * rf, 12.0), bar2.size.y)), 6.0, Color(Style.INK, 0.35), 6)


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

	if is_win:
		var rw := "flag"
		var tier := Levels.tier(Game.level)
		if Game.mode == "daily":
			rw = "banner"
		elif Game.level % Levels.LEVELS_PER_WORLD == 0:
			rw = "arch"  # último nivel del mundo
		elif tier == "super" or tier == "extra":
			rw = "laurel"
		elif _record:
			rw = "popper"
		elif bonus > 0:
			rw = "chest"
		elif stars >= 3:
			rw = "trophy"
		var rt := TextureRect.new()
		rt.texture = Style.reward_art(rw)
		rt.custom_minimum_size = Vector2(0, 150)
		rt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(rt)
	var born := _clock
	var stars_ctl := Control.new()
	stars_ctl.custom_minimum_size = Vector2(0, 120 if is_win else 160)
	stars_ctl.draw.connect(func(): _draw_result_stars(stars_ctl, is_win, stars, _clock - born))
	vb.add_child(stars_ctl)
	vb.add_child(Style.label(tr("WIN") if is_win else tr("LOSE"), 62, Style.INK, "display_bold", HORIZONTAL_ALIGNMENT_CENTER))
	if is_win:
		vb.add_child(Style.label(tr("POINTS") % Style.fmt_int(score), 44, world.a, "display", HORIZONTAL_ALIGNMENT_CENTER))
		if _record:
			vb.add_child(Style.label(tr("NEW_RECORD"), 28, Style.GOLD, "display", HORIZONTAL_ALIGNMENT_CENTER))
		var diff := rival_time - Game.elapsed
		var rival_txt: String = (tr("BEAT_RIVAL") % Style.fmt_time(diff)) if diff >= 0.0 else (tr("LOST_RIVAL") % Style.fmt_time(rival_time))
		var row_r := HBoxContainer.new()
		row_r.alignment = BoxContainer.ALIGNMENT_CENTER
		row_r.add_theme_constant_override("separation", 10)
		var ri := TextureRect.new()
		ri.texture = Style.icon("robot-fill", Style.SUB, 30)
		ri.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row_r.add_child(ri)
		row_r.add_child(Style.label("%s · %s" % [Style.fmt_time(Game.elapsed), rival_txt], 26, Style.SUB, "body"))
		vb.add_child(row_r)
	else:
		var info_l := Style.label(tr("LOSE_SUB"), 30, Style.SUB, "body", HORIZONTAL_ALIGNMENT_CENTER)
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
