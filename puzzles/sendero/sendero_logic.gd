extends "res://core/puzzle_logic.gd"
## Sendero: camino continuo (ortogonal, sin repetir casillas) del inicio al final.
## Los números del borde indican cuántas casillas de cada fila/columna usa el camino.
## Hay casillas bloqueadas. El generador solo acepta niveles con solución ÚNICA,
## comprobada por el solucionador.
##
## Puzle: {w, h, blocked[w*h] (bool), start, end, rows[h], cols[w], planted}

const Rng = preload("res://core/rng.gd")

const CONFIGS := [
	{"w": 5, "h": 5, "min_len": 11, "max_len": 15, "pre_block": 0.3},
	{"w": 6, "h": 6, "min_len": 17, "max_len": 23, "pre_block": 0.3},
	{"w": 8, "h": 8, "min_len": 26, "max_len": 36, "pre_block": 0.5},
]
const SEARCH_BUDGET := 60000
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# Estado temporal del solucionador.
var _w := 0
var _h := 0
var _blocked: Array
var _rows: Array
var _cols: Array
var _used_r: Array
var _used_c: Array
var _visited: PackedByteArray
var _path: Array
var _end := 0
var _total := 0
var _found := 0
var _limit := 2
var _budget := 0
var _solutions: Array
var _seen: PackedInt32Array
var _queue: PackedInt32Array
var _stamp := 0
var _reach_r: Array
var _reach_c: Array


# --- Generación -------------------------------------------------------------------

func generate(seed_value: int, difficulty: int) -> Dictionary:
	var cfg: Dictionary = CONFIGS[clampi(difficulty, 0, 2)]
	for attempt in 600:
		var rng := Rng.make(Rng.derive(seed_value, attempt))
		var p := _try_generate(rng, cfg)
		if not p.is_empty():
			p["difficulty"] = clampi(difficulty, 0, 2)
			return p
	return {}


func _border_cells(w: int, h: int) -> Array:
	var out := []
	for y in h:
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				out.append(y * w + x)
	return out


func _random_path(w: int, h: int, start: int, end: int, min_len: int, max_len: int,
		rng: RandomNumberGenerator) -> Array:
	var path := [start]
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited[start] = 1
	var orders := [_shuffled_dirs(start, w, h, rng)]
	var budget := 40000
	while not path.is_empty() and budget > 0:
		budget -= 1
		var ord: Array = orders.back()
		if ord.is_empty():
			visited[path.back()] = 0
			path.pop_back()
			orders.pop_back()
			continue
		var v: int = ord.pop_back()
		if visited[v] == 1:
			continue
		if v == end:
			if path.size() + 1 >= min_len:
				path.append(v)
				return path
			continue
		if path.size() + 1 >= max_len:
			continue
		visited[v] = 1
		path.append(v)
		orders.append(_shuffled_dirs(v, w, h, rng))
	return []


func _shuffled_dirs(i: int, w: int, h: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	for d in DIRS:
		var nx: int = i % w + d.x
		var ny: int = i / w + d.y
		if nx >= 0 and nx < w and ny >= 0 and ny < h:
			out.append(ny * w + nx)
	return Rng.shuffle(out, rng)


func _try_generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var w: int = cfg.w
	var h: int = cfg.h
	var border := _border_cells(w, h)
	var start: int = border[rng.randi() % border.size()]
	var far := []
	for c in border:
		if absi(c % w - start % w) + absi(c / w - start / w) >= (w + h) / 2:
			far.append(c)
	var end: int = far[rng.randi() % far.size()]
	var path := _random_path(w, h, start, end, cfg.min_len, cfg.max_len, rng)
	if path.is_empty():
		return {}
	var rows := []
	var cols := []
	rows.resize(h)
	rows.fill(0)
	cols.resize(w)
	cols.fill(0)
	var on_path := {}
	for c in path:
		rows[c / w] += 1
		cols[c % w] += 1
		on_path[c] = true
	var blocked := []
	blocked.resize(w * h)
	blocked.fill(false)
	var p := {"type": "sendero", "w": w, "h": h, "blocked": blocked, "start": start, "end": end,
		"rows": rows, "cols": cols, "planted": path}
	var max_blocked := int(w * h * 0.45)
	var n_blocked := 0
	# Bloqueos iniciales aleatorios fuera del camino: reducen la ambigüedad desde el principio.
	var free := []
	for i in w * h:
		if not on_path.has(i):
			free.append(i)
	Rng.shuffle(free, rng)
	for k in int(free.size() * cfg.pre_block):
		blocked[free[k]] = true
		n_blocked += 1
	# Mientras haya más de una solución, se bloquea una casilla de la alternativa que no
	# pertenezca al camino plantado: la plantada sigue siendo válida y la otra desaparece.
	while true:
		var r := solve(p, 2)
		if r.exhausted:
			return {}
		if r.count == 1 and r.solution == path:
			return p
		if r.count == 0:
			return {}
		var alt: Array = []
		for s in r.solutions:
			if s != path:
				alt = s
				break
		if alt.is_empty():
			return {}  # una única solución, pero no es la plantada: no debería pasar
		var cands := []
		for c in alt:
			if not on_path.has(c):
				cands.append(c)
		if cands.is_empty() or n_blocked >= max_blocked:
			return {}
		blocked[cands[rng.randi() % cands.size()]] = true
		n_blocked += 1
	return {}


# --- Reglas -----------------------------------------------------------------------

func counts(puzzle: Dictionary, path: Array) -> Dictionary:
	var rows := []
	var cols := []
	rows.resize(puzzle.h)
	rows.fill(0)
	cols.resize(puzzle.w)
	cols.fill(0)
	for c in path:
		rows[c / puzzle.w] += 1
		cols[c % puzzle.w] += 1
	return {"rows": rows, "cols": cols}


func validate(puzzle: Dictionary, attempt) -> Dictionary:
	var path: Array = attempt
	var w: int = puzzle.w
	if path.is_empty() or path[0] != puzzle.start:
		return {"ok": false, "reason": "bad_start"}
	var seen := {}
	for i in path.size():
		var c: int = path[i]
		if c < 0 or c >= w * puzzle.h or puzzle.blocked[c]:
			return {"ok": false, "reason": "blocked"}
		if seen.has(c):
			return {"ok": false, "reason": "revisit"}
		seen[c] = true
		if i > 0:
			var p: int = path[i - 1]
			if absi(p % w - c % w) + absi(p / w - c / w) != 1:
				return {"ok": false, "reason": "not_adjacent"}
		if c == puzzle.end and i < path.size() - 1:
			return {"ok": false, "reason": "past_end"}
	if path.back() != puzzle.end:
		return {"ok": false, "reason": "incomplete"}
	var cn := counts(puzzle, path)
	if cn.rows != puzzle.rows:
		return {"ok": false, "reason": "row_clue"}
	if cn.cols != puzzle.cols:
		return {"ok": false, "reason": "col_clue"}
	return {"ok": true, "reason": "ok"}


# --- Solucionador -----------------------------------------------------------------

## Cuenta hasta `limit` soluciones (2 basta para comprobar unicidad), continuando `prefix`.
## Devuelve {solvable, count, solution, solutions, exhausted}; exhausted = se agotó el
## presupuesto de búsqueda (el resultado no es concluyente).
func solve(puzzle: Dictionary, limit: int = 2, prefix: Array = []) -> Dictionary:
	_w = puzzle.w
	_h = puzzle.h
	_blocked = puzzle.blocked
	_rows = puzzle.rows
	_cols = puzzle.cols
	_end = puzzle.end
	_total = 0
	for r in _rows:
		_total += r
	_visited = PackedByteArray()
	_visited.resize(_w * _h)
	_used_r = []
	_used_r.resize(_h)
	_used_r.fill(0)
	_used_c = []
	_used_c.resize(_w)
	_used_c.fill(0)
	_found = 0
	_limit = limit
	_budget = SEARCH_BUDGET
	_solutions = []
	_path = []
	_seen = PackedInt32Array()
	_seen.resize(_w * _h)
	_queue = PackedInt32Array()
	_queue.resize(_w * _h)
	_stamp = 0
	_reach_r = []
	_reach_r.resize(_h)
	_reach_c = []
	_reach_c.resize(_w)
	var start_path: Array = prefix if not prefix.is_empty() else [puzzle.start]
	if start_path[0] != puzzle.start:
		return _result()
	for i in start_path.size():
		var c: int = start_path[i]
		if c < 0 or c >= _w * _h or _blocked[c] or _visited[c] == 1:
			return _result()
		if i > 0 and absi(start_path[i - 1] % _w - c % _w) + absi(start_path[i - 1] / _w - c / _w) != 1:
			return _result()
		_visited[c] = 1
		_used_r[c / _w] += 1
		_used_c[c % _w] += 1
		_path.append(c)
	for y in _h:
		if _used_r[y] > _rows[y]:
			return _result()
	for x in _w:
		if _used_c[x] > _cols[x]:
			return _result()
	_dfs(_path.back())
	return _result()


func _result() -> Dictionary:
	return {"solvable": _found > 0, "count": _found,
		"solution": _solutions[0] if _found > 0 else [], "solutions": _solutions,
		"exhausted": _budget <= 0 and _found < _limit}


func _all_match() -> bool:
	for y in _h:
		if _used_r[y] != _rows[y]:
			return false
	for x in _w:
		if _used_c[x] != _cols[x]:
			return false
	return true


## Poda: desde la cabeza, ¿se llega al final por casillas libres y aún caben las casillas
## que faltan en cada fila y columna?
func _feasible(head: int) -> bool:
	_stamp += 1
	_reach_r.fill(0)
	_reach_c.fill(0)
	var qh := 0
	var qt := 1
	_queue[0] = head
	_seen[head] = _stamp
	var end_ok := false
	while qh < qt:
		var c := _queue[qh]
		qh += 1
		var x := c % _w
		var y := c / _w
		for d in DIRS:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or nx >= _w or ny < 0 or ny >= _h:
				continue
			var n := ny * _w + nx
			if _seen[n] == _stamp or _visited[n] == 1 or _blocked[n]:
				continue
			if _used_r[ny] >= _rows[ny] or _used_c[nx] >= _cols[nx]:
				continue
			_seen[n] = _stamp
			_queue[qt] = n
			qt += 1
			_reach_r[ny] += 1
			_reach_c[nx] += 1
			if n == _end:
				end_ok = true
	if not end_ok:
		return false
	for y in _h:
		if _reach_r[y] < _rows[y] - _used_r[y]:
			return false
	for x in _w:
		if _reach_c[x] < _cols[x] - _used_c[x]:
			return false
	return true


func _dfs(c: int) -> void:
	if _found >= _limit or _budget <= 0:
		return
	_budget -= 1
	if c == _end:
		if _path.size() == _total and _all_match():
			_found += 1
			_solutions.append(_path.duplicate())
		return
	if not _feasible(c):
		return
	var x := c % _w
	var y := c / _w
	var ex := _end % _w
	var ey := _end / _w
	var next_len := _path.size() + 1
	for d in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or nx >= _w or ny < 0 or ny >= _h:
			continue
		var n := ny * _w + nx
		if _blocked[n] or _visited[n] == 1:
			continue
		if _used_r[ny] >= _rows[ny] or _used_c[nx] >= _cols[nx]:
			continue
		if n == _end:
			if next_len != _total:
				continue
		elif next_len >= _total or absi(nx - ex) + absi(ny - ey) > _total - next_len:
			continue
		_visited[n] = 1
		_used_r[ny] += 1
		_used_c[nx] += 1
		_path.append(n)
		_dfs(n)
		_path.pop_back()
		_used_r[ny] -= 1
		_used_c[nx] -= 1
		_visited[n] = 0
