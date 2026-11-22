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
	if hint_cell >= 0:
		if Time.get_ticks_msec() > hint_until:
			hint_cell = -1
		if _playing:
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
	# Pistas de filas y columnas.
	for y in h:
		var done: bool = used_r[y] == puzzle.rows[y]
		Kit.text_at(c, origin + Vector2(-32, (y + 0.5) * cell), str(puzzle.rows[y]), 34,
			Palette.TURQUOISE if done else Palette.TEXT)
	for x in w:
		var done2: bool = used_c[x] == puzzle.cols[x]
		Kit.text_at(c, origin + Vector2((x + 0.5) * cell, -32), str(puzzle.cols[x]), 34,
			Palette.TURQUOISE if done2 else Palette.TEXT)
	# Casillas.
	for i in w * h:
		var r := Rect2(origin + Vector2(i % w, i / w) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6))
		if puzzle.blocked[i]:
			c.draw_rect(r, Palette.BG.lightened(0.04))
			var m := r.grow(-cell * 0.28)
			c.draw_line(m.position, m.end, Palette.CORAL_DIM, 5.0, true)
			c.draw_line(Vector2(m.end.x, m.position.y), Vector2(m.position.x, m.end.y), Palette.CORAL_DIM, 5.0, true)
		else:
			c.draw_rect(r, Palette.TURQUOISE_DIM if path.has(i) else Palette.PANEL)
	for i in path.size() - 1:
		c.draw_line(_cell_center(path[i]), _cell_center(path[i + 1]), Palette.TURQUOISE, cell * 0.25, true)
	# Inicio y fin.
	var sp := _cell_center(puzzle.start)
	c.draw_arc(sp, cell * 0.36, 0, TAU, 32, Palette.TURQUOISE, 5.0, true)
	c.draw_colored_polygon(PackedVector2Array([sp + Vector2(cell * 0.12, 0), sp + Vector2(-cell * 0.08, -cell * 0.14), sp + Vector2(-cell * 0.08, cell * 0.14)]), Palette.TURQUOISE)
	var ep := _cell_center(puzzle.end)
	c.draw_arc(ep, cell * 0.38, 0, TAU, 32, Palette.CORAL, 5.0, true)
	c.draw_circle(ep, cell * 0.14, Palette.CORAL)
	# Cabeza.
	if path.size() > 1:
		var hp := _cell_center(path.back())
		c.draw_circle(hp, cell * 0.22, Palette.TURQUOISE)
		c.draw_circle(hp, cell * 0.1, Color.WHITE)
	if hint_cell >= 0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		c.draw_rect(Rect2(origin + Vector2(hint_cell % w, hint_cell / w) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6)).grow(pulse * 3), Palette.GOLD, false, 5.0)
