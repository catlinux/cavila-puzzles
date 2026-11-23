extends "res://core/puzzle_base.gd"
## Vista de Sendero. Arrastra por las casillas desde el inicio hasta el final.
## Superar el número de una fila/columna o terminar con pistas sin cumplir cuesta una vida.

var w := 0
var h := 0
var path: Array = []
var used_r: Array = []
var used_c: Array = []
var cell := 80.0
var origin := Vector2.ZERO
var dragging := false
var last_bad := -1
var hint_cell := -1
var hint_until := 0


func _setup() -> void:
	w = puzzle.w
	h = puzzle.h
	path = [puzzle.start]
	_recount()
	content.draw.connect(_draw_board)
	content.gui_input.connect(_board_input)
	content.resized.connect(content.queue_redraw)
	content.queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	if hint_cell >= 0 and Time.get_ticks_msec() > hint_until:
		hint_cell = -1
	if _playing and not finished:
		content.queue_redraw()


func _recount() -> void:
	var cn: Dictionary = logic.counts(puzzle, path)
	used_r = cn.rows
	used_c = cn.cols
	last_bad = -1


func _layout() -> void:
	var s := content.size
	var clue := 64.0
	cell = minf(minf((s.x - clue - 20.0) / w, (s.y - clue - 20.0) / h), 110.0)
	var tw := clue + cell * w
	var th := clue + cell * h
	origin = Vector2((s.x - tw) / 2.0 + clue, (s.y - th) / 2.0 + clue)


func _cell_center(i: int) -> Vector2:
	return origin + (Vector2(i % w, i / w) + Vector2(0.5, 0.5)) * cell


func _cell_at(pos: Vector2) -> int:
	_layout()
	var q := (pos - origin) / cell
	var x := floori(q.x)
	var y := floori(q.y)
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x


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
	var n := _cell_at(pos)
	if n < 0 or n == path.back():
		return
	if path.size() >= 2 and n == path[path.size() - 2]:
		path.pop_back()
		_recount()
	elif path.has(n):
		path = path.slice(0, path.find(n) + 1)
		_recount()
	else:
		step_to(n)
	content.queue_redraw()


## Intenta avanzar al vecino n (público para tests).
func step_to(n: int) -> void:
	var head: int = path.back()
	if absi(head % w - n % w) + absi(head / w - n / w) != 1 or puzzle.blocked[n]:
		return
	var x := n % w
	var y := n / w
	if used_r[y] >= puzzle.rows[y] or used_c[x] >= puzzle.cols[x]:
		if last_bad != n:
			last_bad = n
			mistake()
		return
	path.append(n)
	if n == puzzle.end:
		if logic.validate(puzzle, path).ok:
			_recount()
			solved()
			return
		path.pop_back()  # llegó al final con pistas sin cumplir
		if last_bad != n:
			last_bad = n
			mistake()
		return
	_recount()


func _give_hint() -> bool:
	var r: Dictionary = logic.solve(puzzle, 1, path)
	if not r.solvable:
		r = logic.solve(puzzle, 1, [puzzle.start])
		if not r.solvable:
			return false
		var k := 0
		while k < path.size() and k < r.solution.size() and path[k] == r.solution[k]:
			k += 1
		path = r.solution.slice(0, k)
		_recount()
	hint_cell = r.solution[path.size()]
	hint_until = Time.get_ticks_msec() + 2500
	content.queue_redraw()
	return true


func _draw_board() -> void:
	if puzzle.is_empty():
		return
	var c := content
	_layout()
	var t := Time.get_ticks_msec() / 1000.0
	# Pistas de filas y columnas en "pastillas": se rellenan al cumplirse.
	for y in h:
		_clue(origin + Vector2(-34, (y + 0.5) * cell), puzzle.rows[y], used_r[y] == puzzle.rows[y])
	for x in w:
		_clue(origin + Vector2((x + 0.5) * cell, -32), puzzle.cols[x], used_c[x] == puzzle.cols[x])
	# Casillas.
	var rad := cell * 0.17
	for i in w * h:
		var r := Rect2(origin + Vector2(i % w, i / w) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6))
		var pts := Kit.rounded_points(r, rad, 4)
		if puzzle.blocked[i]:
			c.draw_colored_polygon(pts, Color8(12, 16, 23))
			var m := r.grow(-cell * 0.3)
			c.draw_line(m.position, m.end, Palette.CORAL_DIM, 4.0, true)
			c.draw_line(Vector2(m.end.x, m.position.y), Vector2(m.position.x, m.end.y), Palette.CORAL_DIM, 4.0, true)
		else:
			var on := path.has(i)
			c.draw_colored_polygon(pts, Palette.TURQUOISE_DIM.darkened(0.35) if on else Color8(37, 49, 65))
			var line := pts.duplicate()
			line.append(pts[0])
			c.draw_polyline(line, Palette.TURQUOISE_DIM if on else Color8(52, 67, 87), 2.0, true)
	# Camino con brillo y uniones redondeadas.
	for i in path.size() - 1:
		Kit.glow_line(c, _cell_center(path[i]), _cell_center(path[i + 1]), Palette.TURQUOISE, cell * 0.2)
	for n in path:
		c.draw_circle(_cell_center(n), cell * 0.1, Palette.TURQUOISE)
	# Inicio (disco con triángulo) y final (diana coral que late).
	var sp := _cell_center(puzzle.start)
	c.draw_circle(sp, cell * 0.3, Palette.TURQUOISE_LIGHT)
	c.draw_colored_polygon(PackedVector2Array([sp + Vector2(cell * 0.11, 0), sp + Vector2(-cell * 0.07, -cell * 0.13), sp + Vector2(-cell * 0.07, cell * 0.13)]), Palette.INK)
	var ep := _cell_center(puzzle.end)
	var beat := 1.0 + 0.06 * sin(t * 5.0)
	Kit.glow_circle(c, ep, cell * 0.2, Palette.CORAL, 0.12)
	c.draw_arc(ep, cell * 0.34 * beat, 0, TAU, 32, Palette.CORAL, 5.0, true)
	c.draw_circle(ep, cell * 0.14, Palette.CORAL_LIGHT)
	# Cabeza.
	if path.size() > 1:
		var hp := _cell_center(path.back())
		Kit.glow_circle(c, hp, cell * 0.2, Palette.TURQUOISE, 0.22)
		c.draw_circle(hp, cell * 0.2, Palette.TURQUOISE_LIGHT)
		c.draw_circle(hp, cell * 0.09, Color.WHITE)
	if hint_cell >= 0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		var hr := Rect2(origin + Vector2(hint_cell % w, hint_cell / w) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6)).grow(pulse * 3)
		var hp2 := Kit.rounded_points(hr, rad, 4)
		hp2.append(hp2[0])
		c.draw_polyline(hp2, Palette.GOLD, 5.0, true)


func _clue(center: Vector2, value: int, satisfied: bool) -> void:
	var r := Rect2(center - Vector2(24, 20), Vector2(48, 40))
	if satisfied:
		Kit.card(content, r, 14, Palette.TURQUOISE, Palette.TURQUOISE_DIM, Color(0, 0, 0, 0), 0.0, false)
		Kit.text_at(content, center, str(value), 30, Palette.INK, true)
	else:
		Kit.card(content, r, 14, Palette.CARD_TOP, Palette.CARD_BOTTOM, Palette.CARD_BORDER, 1.5, false)
		Kit.text_at(content, center, str(value), 30, Palette.TEXT, true)
