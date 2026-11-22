extends "res://core/puzzle_base.gd"
## Vista de Circuito. Arrastra el dedo de nodo en nodo desde la entrada hasta la salida;
## arrastrar hacia atrás deshace. Pisar un diodo al revés cuesta una vida.

var w := 0
var h := 0
var path: Array = []
var mask := 0
var cell := 100.0
var origin := Vector2.ZERO
var dragging := false
var last_bad := -1
var hint_node := -1
var hint_until := 0


func _setup() -> void:
	w = puzzle.w
	h = puzzle.h
	path = [puzzle.start]
	content.draw.connect(_draw_board)
	content.gui_input.connect(_board_input)
	content.resized.connect(content.queue_redraw)
	content.queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	if hint_node >= 0:
		if Time.get_ticks_msec() > hint_until:
			hint_node = -1
		if _playing:
			content.queue_redraw()


# --- Geometría --------------------------------------------------------------------

func _layout() -> void:
	var s := content.size
	cell = minf((s.x - 100.0) / maxf(w - 1, 1), (s.y - 100.0) / maxf(h - 1, 1))
	cell = minf(cell, 150.0)
	origin = (s - Vector2((w - 1) * cell, (h - 1) * cell)) / 2.0


func _np(i: int) -> Vector2:
	return origin + Vector2(i % w, i / w) * cell


func _node_at(pos: Vector2) -> int:
	_layout()
	var best := -1
	var best_d := cell * 0.45
	for i in w * h:
		var d := _np(i).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


# --- Entrada ----------------------------------------------------------------------

func _board_input(ev: InputEvent) -> void:
	if finished or puzzle.is_empty():
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		dragging = ev.pressed
		last_bad = -1
		if ev.pressed:
			_pointer(ev.position)
	elif ev is InputEventMouseMotion and dragging:
		_pointer(ev.position)


func _pointer(pos: Vector2) -> void:
	var n := _node_at(pos)
	if n < 0 or n == path.back():
		return
	if path.size() >= 2 and n == path[path.size() - 2]:
		path.pop_back()
		_recompute()
	elif path.has(n):
		path = path.slice(0, path.find(n) + 1)
		_recompute()
	else:
		step_to(n)
	content.queue_redraw()


func _recompute() -> void:
	mask = logic.simulate(puzzle, path).mask
	last_bad = -1


## Intenta avanzar la chispa al nodo n (público para tests y pistas).
func step_to(n: int) -> void:
	var head: int = path.back()
	var ei: int = logic.edge_between(puzzle, head, n)
	if ei < 0:
		return
	if not logic.can_pass(puzzle, ei, head, n, mask):
		if last_bad != n:
			last_bad = n
			mistake()
		return
	path.append(n)
	var sw: int = puzzle.switches[n]
	if sw >= 0:
		mask ^= 1 << sw
	last_bad = -1
	if n == puzzle.exit:
		solved()


func _give_hint() -> bool:
	var r: Dictionary = logic.solve(puzzle, path)
	if not r.solvable:
		r = logic.solve(puzzle, [puzzle.start])
		if not r.solvable:
			return false
		var k := 0
		while k < path.size() and k < r.solution.size() and path[k] == r.solution[k]:
			k += 1
		path = r.solution.slice(0, k)
		_recompute()
	hint_node = r.solution[path.size()]
	hint_until = Time.get_ticks_msec() + 2500
	content.queue_redraw()
	return true


# --- Dibujo -----------------------------------------------------------------------

func _draw_board() -> void:
	if puzzle.is_empty():
		return
	var c := content
	_layout()
	for ei in puzzle.edges.size():
		var e: Dictionary = puzzle.edges[ei]
		var pa := _np(e.a)
		var pb := _np(e.b)
		if e.kind == 0:
			c.draw_line(pa, pb, Palette.WIRE, 8.0, true)
			continue
		var col: Color = Palette.WIRE.lightened(0.25) if e.grp < 0 else Palette.GROUP_COLORS[e.grp]
		c.draw_line(pa, pb, col.darkened(0.45), 6.0, true)
		var ft: Array = logic.effective_dir(puzzle, ei, mask)
		var f := _np(ft[0])
		var t := _np(ft[1])
		var mid := (f + t) / 2.0
		var dir := (t - f).normalized()
		var perp := Vector2(-dir.y, dir.x)
		c.draw_colored_polygon(PackedVector2Array([mid + dir * 17, mid - dir * 13 + perp * 15, mid - dir * 13 - perp * 15]), col)
		if e.grp >= 0:
			Kit.text_at(c, mid + perp * 28, str(e.grp + 1), 20, col)

	for i in path.size() - 1:
		c.draw_line(_np(path[i]), _np(path[i + 1]), Palette.TURQUOISE, 14.0, true)

	for i in w * h:
		var p := _np(i)
		var sw: int = puzzle.switches[i]
		if sw >= 0:
			var col2: Color = Palette.GROUP_COLORS[sw]
			c.draw_rect(Rect2(p - Vector2(22, 22), Vector2(44, 44)), col2)
			c.draw_rect(Rect2(p - Vector2(22, 22), Vector2(44, 44)), Palette.BG, false, 3.0)
			Kit.text_at(c, p, str(sw + 1), 28, Palette.BG)
		else:
			c.draw_circle(p, 15, Palette.TURQUOISE if path.has(i) else Palette.PANEL_HI)
			c.draw_arc(p, 15, 0, TAU, 24, Palette.WIRE, 3.0, true)
	# Entrada (triángulo) y salida (diana).
	var sp := _np(puzzle.start)
	c.draw_arc(sp, 30, 0, TAU, 32, Palette.TURQUOISE, 5.0, true)
	c.draw_colored_polygon(PackedVector2Array([sp + Vector2(9, 0), sp + Vector2(-6, -10), sp + Vector2(-6, 10)]), Palette.TURQUOISE)
	var xp := _np(puzzle.exit)
	c.draw_arc(xp, 32, 0, TAU, 32, Palette.CORAL, 5.0, true)
	c.draw_arc(xp, 19, 0, TAU, 32, Palette.CORAL, 5.0, true)
	c.draw_circle(xp, 8, Palette.CORAL)
	# Chispa.
	var hp := _np(path.back())
	c.draw_circle(hp, 28, Color(Palette.TURQUOISE, 0.25))
	c.draw_circle(hp, 16, Palette.TURQUOISE)
	c.draw_circle(hp, 8, Color.WHITE)
	if hint_node >= 0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		c.draw_arc(_np(hint_node), 26 + pulse * 8, 0, TAU, 32, Palette.GOLD, 5.0, true)
