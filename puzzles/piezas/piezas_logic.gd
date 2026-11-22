extends "res://core/puzzle_logic.gd"
## Piezas: rellenar una silueta con piezas tipo poliominó que se pueden girar.
## La silueta se genera colocando piezas una a una (cada nueva pieza toca a las anteriores),
## así que siempre existe al menos un teselado. El solucionador lo comprueba por búsqueda
## exacta (backtracking sobre la primera casilla libre).
##
## Puzle: {w, h, cells[w*h] (bool), pieces[{id, shape, cells[Vector2i], color, rot0}], planted}
## Colocación: {piece: int, cells: [Vector2i absolutas]}

const Rng = preload("res://core/rng.gd")

const SHAPES := {
	"I3": ["###"], "L3": ["#.", "##"],
	"I4": ["####"], "O4": ["##", "##"], "T4": ["###", ".#."], "S4": [".##", "##."],
	"Z4": ["##.", ".##"], "L4": ["#.", "#.", "##"], "J4": [".#", ".#", "##"],
	"F5": [".##", "##.", ".#."], "I5": ["#####"], "L5": ["#.", "#.", "#.", "##"],
	"N5": [".#", ".#", "##", "#."], "P5": ["##", "##", "#."], "T5": ["###", ".#.", ".#."],
	"U5": ["#.#", "###"], "V5": ["#..", "#..", "###"], "W5": ["#..", "##.", ".##"],
	"X5": [".#.", "###", ".#."], "Y5": [".#", "##", ".#", ".#"], "Z5": ["##.", ".#.", ".##"],
}

const CONFIGS := [
	{"grid": 6, "count": 4, "pool": ["I3", "L3", "I4", "O4", "T4", "S4", "Z4", "L4", "J4"]},
	{"grid": 7, "count": 6, "pool": ["I4", "O4", "T4", "S4", "Z4", "L4", "J4", "L5", "N5", "P5", "T5", "U5", "V5", "Y5"]},
	{"grid": 8, "count": 8, "pool": ["F5", "L5", "N5", "P5", "T5", "U5", "V5", "W5", "X5", "Y5", "Z5", "I5"]},
]
const SEARCH_BUDGET := 400000

# Estado temporal del solucionador.
var _w := 0
var _h := 0
var _grid: PackedInt32Array
var _orients: Array
var _keys: Array
var _used: Array
var _placements: Array
var _found := 0
var _limit := 1
var _budget := 0
var _solutions: Array


# --- Geometría de piezas (estático, reutilizable por la UI) -------------------------

static func parse_shape(id: String) -> Array:
	var out := []
	var rows: Array = SHAPES[id]
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				out.append(Vector2i(x, y))
	return out


static func _sort_cells(cells: Array) -> Array:
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


## Gira k cuartos de vuelta y normaliza (esquina mínima en 0,0; ordenadas por fila).
static func rotate_cells(cells: Array, k: int) -> Array:
	var out := []
	for c in cells:
		var v: Vector2i = c
		for _i in posmod(k, 4):
			v = Vector2i(-v.y, v.x)
		out.append(v)
	var mn := Vector2i(1000000, 1000000)
	for v in out:
		mn = Vector2i(mini(mn.x, v.x), mini(mn.y, v.y))
	for i in out.size():
		out[i] = out[i] - mn
	return _sort_cells(out)


## Rotaciones distintas de una pieza.
static func orientations(cells: Array) -> Array:
	var out := []
	var seen := {}
	for k in 4:
		var o := rotate_cells(cells, k)
		var key := str(o)
		if not seen.has(key):
			seen[key] = true
			out.append(o)
	return out


static func bounds(cells: Array) -> Vector2i:
	var mx := Vector2i.ZERO
	for c in cells:
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	return mx + Vector2i.ONE


## Clave canónica de una forma (igual para todas sus rotaciones).
static func shape_key(cells: Array) -> String:
	var best := ""
	for o in orientations(cells):
		var s := str(o)
		if best == "" or s < best:
			best = s
	return best


# --- Generación -------------------------------------------------------------------

func generate(seed_value: int, difficulty: int) -> Dictionary:
	var d := clampi(difficulty, 0, 2)
	var cfg: Dictionary = CONFIGS[d]
	for attempt in 200:
		var rng := Rng.make(Rng.derive(seed_value, attempt))
		var p := _try_generate(rng, cfg)
		if p.is_empty():
			continue
		p["difficulty"] = d
		if solve(p).solvable:
			return p
	return {}


func _try_generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var g: int = cfg.grid
	var occ := PackedInt32Array()
	occ.resize(g * g)
	occ.fill(-1)
	var placed := []  # [{shape, cells(abs)}]
	var used_shapes := {}
	for i in cfg.count:
		var order := Rng.shuffle(cfg.pool.duplicate(), rng)
		order.sort_custom(func(a, b): return int(used_shapes.has(a)) < int(used_shapes.has(b)))
		var chosen := {}
		for sid in order:
			var cand := _candidates(sid, g, occ, i > 0)
			if cand.is_empty():
				continue
			var best_score := -1
			for c in cand:
				best_score = maxi(best_score, c.score)
			var pick: Dictionary
			if rng.randf() < 0.7:
				var top := cand.filter(func(c): return c.score == best_score)
				pick = top[rng.randi() % top.size()]
			else:
				pick = cand[rng.randi() % cand.size()]
			chosen = {"shape": sid, "cells": pick.cells}
			break
		if chosen.is_empty():
			return {}
		used_shapes[chosen.shape] = true
		for c in chosen.cells:
			occ[c.y * g + c.x] = i
		placed.append(chosen)

	# Recortar al rectángulo mínimo.
	var mn := Vector2i(g, g)
	var mx := Vector2i(-1, -1)
	for pl in placed:
		for c in pl.cells:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var w := mx.x - mn.x + 1
	var h := mx.y - mn.y + 1
	var cells := []
	cells.resize(w * h)
	cells.fill(false)
	var pieces := []
	var planted := []
	for i in placed.size():
		var abs_cells := []
		for c in placed[i].cells:
			var q: Vector2i = c - mn
			cells[q.y * w + q.x] = true
			abs_cells.append(q)
		planted.append({"piece": i, "cells": abs_cells})
		pieces.append({"id": i, "shape": placed[i].shape, "cells": parse_shape(placed[i].shape),
			"color": i % PIECE_COLOR_COUNT, "rot0": rng.randi() % 4})
	return {"type": "piezas", "w": w, "h": h, "cells": cells, "pieces": pieces, "planted": planted}


const PIECE_COLOR_COUNT := 8


## Colocaciones posibles de una forma (todas las rotaciones y posiciones) dentro del tablero g×g.
func _candidates(sid: String, g: int, occ: PackedInt32Array, must_touch: bool) -> Array:
	var out := []
	for o in orientations(parse_shape(sid)):
		var b := bounds(o)
		for oy in range(0, g - b.y + 1):
			for ox in range(0, g - b.x + 1):
				var ok := true
				var touch := 0
				var cells := []
				for c in o:
					var x: int = c.x + ox
					var y: int = c.y + oy
					if occ[y * g + x] != -1:
						ok = false
						break
					cells.append(Vector2i(x, y))
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = x + d.x
						var ny: int = y + d.y
						if nx >= 0 and nx < g and ny >= 0 and ny < g and occ[ny * g + nx] != -1:
							touch += 1
				if ok and (touch > 0 or not must_touch):
					out.append({"cells": cells, "score": touch})
	return out


# --- Reglas -----------------------------------------------------------------------

## Comprueba una colocación (parcial o completa). {ok, complete, reason}.
func validate(puzzle: Dictionary, attempt) -> Dictionary:
	var w: int = puzzle.w
	var h: int = puzzle.h
	var covered := {}
	var used := {}
	for pl in attempt:
		var pi: int = pl.piece
		if pi < 0 or pi >= puzzle.pieces.size() or used.has(pi):
			return {"ok": false, "complete": false, "reason": "bad_piece"}
		used[pi] = true
		var base: Array = puzzle.pieces[pi].cells
		if shape_key(pl.cells) != shape_key(base) or pl.cells.size() != base.size():
			return {"ok": false, "complete": false, "reason": "wrong_shape"}
		for c in pl.cells:
			if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or not puzzle.cells[c.y * w + c.x]:
				return {"ok": false, "complete": false, "reason": "outside"}
			if covered.has(c):
				return {"ok": false, "complete": false, "reason": "overlap"}
			covered[c] = true
	var total := 0
	for v in puzzle.cells:
		if v:
			total += 1
	var complete: bool = covered.size() == total and used.size() == puzzle.pieces.size()
	return {"ok": true, "complete": complete, "reason": "ok" if complete else "incomplete"}


# --- Solucionador -----------------------------------------------------------------

## Cuenta hasta `limit` teselados que respeten las colocaciones `fixed`.
## Devuelve {solvable, count, solution: [colocaciones], exhausted}.
func solve(puzzle: Dictionary, limit: int = 1, fixed: Array = []) -> Dictionary:
	_w = puzzle.w
	_h = puzzle.h
	_grid = PackedInt32Array()
	_grid.resize(_w * _h)
	var total := 0
	for i in _w * _h:
		_grid[i] = -1 if puzzle.cells[i] else -2
		if puzzle.cells[i]:
			total += 1
	var size_sum := 0
	_orients = []
	_keys = []
	_used = []
	for p in puzzle.pieces:
		size_sum += p.cells.size()
		_orients.append(orientations(p.cells))
		_keys.append(shape_key(p.cells))
		_used.append(false)
	_found = 0
	_limit = limit
	_budget = SEARCH_BUDGET
	_solutions = []
	_placements = []
	if size_sum != total:
		return _result()
	for f in fixed:
		for c in f.cells:
			var idx: int = c.y * _w + c.x
			if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h or _grid[idx] != -1:
				return _result()
			_grid[idx] = f.piece
		_used[f.piece] = true
		_placements.append({"piece": f.piece, "cells": f.cells.duplicate()})
	_rec(0)
	return _result()


func _result() -> Dictionary:
	return {"solvable": _found > 0, "count": _found,
		"solution": _solutions[0] if _found > 0 else [],
		"exhausted": _budget <= 0 and _found < _limit}


func _rec(from: int) -> void:
	if _found >= _limit or _budget <= 0:
		return
	_budget -= 1
	var cell := from
	while cell < _w * _h and _grid[cell] != -1:
		cell += 1
	if cell >= _w * _h:
		_found += 1
		var sol := []
		for pl in _placements:
			sol.append({"piece": pl.piece, "cells": pl.cells.duplicate()})
		_solutions.append(sol)
		return
	var cx := cell % _w
	var cy := cell / _w
	var tried := {}
	for pi in _orients.size():
		if _used[pi] or tried.has(_keys[pi]):
			continue
		tried[_keys[pi]] = true
		for o in _orients[pi]:
			# La primera casilla (fila, columna) de la orientación cubre la casilla libre.
			var ax: int = o[0].x
			var ay: int = o[0].y
			var abs_cells := []
			var ok := true
			for c in o:
				var x: int = cx + c.x - ax
				var y: int = cy + c.y - ay
				if x < 0 or x >= _w or y < 0 or y >= _h or _grid[y * _w + x] != -1:
					ok = false
					break
				abs_cells.append(Vector2i(x, y))
			if not ok:
				continue
			for c in abs_cells:
				_grid[c.y * _w + c.x] = pi
			_used[pi] = true
			_placements.append({"piece": pi, "cells": abs_cells})
			_rec(cell + 1)
			_placements.pop_back()
			_used[pi] = false
			for c in abs_cells:
				_grid[c.y * _w + c.x] = -1
			if _found >= _limit or _budget <= 0:
				return
