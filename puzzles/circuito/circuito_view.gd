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
	if hint_node >= 0 and Time.get_ticks_msec() > hint_until:
		hint_node = -1
	if _playing and not finished:
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
	var t := Time.get_ticks_msec() / 1000.0
	# Cables y diodos (con contorno oscuro para dar relieve).
	for ei in puzzle.edges.size():
		var e: Dictionary = puzzle.edges[ei]
		var pa := _np(e.a)
		var pb := _np(e.b)
		c.draw_line(pa, pb, Color8(12, 17, 24), 14.0, true)
		if e.kind == 0:
			c.draw_line(pa, pb, Palette.WIRE, 8.0, true)
			c.draw_line(pa, pb, Color(1, 1, 1, 0.12), 2.0, true)
			continue
		var col: Color = Palette.WIRE.lightened(0.3) if e.grp < 0 else Palette.GROUP_COLORS[e.grp]
		c.draw_line(pa, pb, col.darkened(0.5), 8.0, true)
		var ft: Array = logic.effective_dir(puzzle, ei, mask)
		var f := _np(ft[0])
		var to := _np(ft[1])
		var mid := (f + to) / 2.0
		var dir := (to - f).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var tri := PackedVector2Array([mid + dir * 19, mid - dir * 14 + perp * 17, mid - dir * 14 - perp * 17])
		var outline := tri.duplicate()
		outline.append(tri[0])
		c.draw_colored_polygon(tri, col)
		c.draw_polyline(outline, Color8(12, 17, 24), 3.0, true)
		if e.grp >= 0:
			Kit.text_at(c, mid + perp * 31, str(e.grp + 1), 20, col, true)

	# Camino recorrido con brillo.
	for i in path.size() - 1:
		Kit.glow_line(c, _np(path[i]), _np(path[i + 1]), Palette.TURQUOISE, 9.0)
		c.draw_line(_np(path[i]), _np(path[i + 1]), Palette.TURQUOISE_LIGHT, 3.0, true)

	# Nodos e interruptores.
	for i in w * h:
		var p := _np(i)
		var sw: int = puzzle.switches[i]
		if sw >= 0:
			var col2: Color = Palette.GROUP_COLORS[sw]
			var r := Rect2(p - Vector2(25, 25), Vector2(50, 50))
			Kit.glow_circle(c, p, 16, col2, 0.07)
			Kit.card(c, r, 12, col2.lightened(0.25), col2.darkened(0.15), Color8(12, 17, 24), 3.0, false)
			Kit.text_at(c, p + Vector2(0, 1), str(sw + 1), 30, Palette.INK, true)
		else:
			var on := path.has(i)
			c.draw_circle(p, 19, Color8(12, 17, 24))
			c.draw_circle(p, 15, Palette.TURQUOISE if on else Palette.PANEL_HI.lightened(0.1))
			c.draw_circle(p + Vector2(-4, -4), 5, Color(1, 1, 1, 0.35 if on else 0.15))

	# Entrada: anillo con triángulo. Salida: diana con arcos giratorios.
	var sp := _np(puzzle.start)
	Kit.glow_circle(c, sp, 22, Palette.TURQUOISE, 0.09)
	c.draw_arc(sp, 31, 0, TAU, 40, Palette.TURQUOISE, 5.0, true)
	c.draw_colored_polygon(PackedVector2Array([sp + Vector2(10, 0), sp + Vector2(-7, -11), sp + Vector2(-7, 11)]), Palette.TURQUOISE)
	var xp := _np(puzzle.exit)
	Kit.glow_circle(c, xp, 22, Palette.CORAL, 0.1)
	c.draw_circle(xp, 24, Color8(12, 17, 24))
	c.draw_arc(xp, 33, t * 1.5, t * 1.5 + PI * 1.4, 24, Palette.CORAL, 5.0, true)
	c.draw_arc(xp, 33, t * 1.5 + PI * 1.4 + 0.3, t * 1.5 + TAU - 0.1, 8, Palette.CORAL_DIM, 5.0, true)
	c.draw_arc(xp, 17, 0, TAU, 28, Palette.CORAL, 4.0, true)
	c.draw_circle(xp, 7, Palette.CORAL_LIGHT)

	# Chispa (late).
	var hp := _np(path.back())
	var beat := 1.0 + 0.12 * sin(t * 6.0)
	Kit.glow_circle(c, hp, 22 * beat, Palette.TURQUOISE, 0.22)
	c.draw_circle(hp, 17 * beat, Palette.TURQUOISE_LIGHT)
	c.draw_circle(hp, 9, Color.WHITE)
	if hint_node >= 0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		c.draw_arc(_np(hint_node), 28 + pulse * 8, 0, TAU, 32, Palette.GOLD, 5.0, true)
