extends "res://core/puzzle_logic.gd"
## Circuito: la chispa recorre una cuadrícula de nodos desde la entrada hasta la salida.
## - Los cables (WIRE) se cruzan en ambos sentidos.
## - Los diodos (DIODE) solo dejan pasar en un sentido (a -> b en su estado base).
## - Un diodo con grupo g invierte su sentido cada vez que la chispa pisa un interruptor del grupo g.
## - La chispa no puede pasar dos veces por el mismo nodo.
##
## Puzle: {w, h, start, exit, groups, switches[nodo] = grupo|-1,
##         edges[{a, b, kind, grp}], planted (camino con el que se generó)}

const Rng = preload("res://core/rng.gd")

const WIRE := 0
const DIODE := 1

const CONFIGS := [
	{"w": 4, "h": 4, "groups": 1, "decoys": 0, "min_len": 8, "wire": 0.30, "cut": 0.08, "free_diode": 0.55},
	{"w": 5, "h": 5, "groups": 2, "decoys": 1, "min_len": 12, "wire": 0.22, "cut": 0.10, "free_diode": 0.40},
	{"w": 6, "h": 6, "groups": 3, "decoys": 2, "min_len": 18, "wire": 0.15, "cut": 0.12, "free_diode": 0.30},
]
const SEARCH_BUDGET := 3000000

# Estado temporal del solucionador.
var _adj: Array
var _edges: Array
var _switches: Array
var _visited: PackedByteArray
var _path: Array
var _exit := 0
var _found := 0
var _limit := 1
var _budget := 0
var _ignore := false
var _solution: Array


# --- Generación -------------------------------------------------------------------

func generate(seed_value: int, difficulty: int) -> Dictionary:
	var d := clampi(difficulty, 0, 2)
	var cfg: Dictionary = CONFIGS[d]
	var fallback := {}
	for attempt in 400:
		var rng := Rng.make(Rng.derive(seed_value, attempt))
		var p := _try_generate(rng, cfg)
		if p.is_empty():
			continue
		p["difficulty"] = d
		# Debe ser resoluble (lo comprueba el solucionador, no solo la construcción)...
		if not solve(p).solvable:
			continue
		# ...y en medio/difícil los interruptores deben ser necesarios.
		if d == 0 or not solve(p, [], 1, true).solvable:
			return p
		if fallback.is_empty():
			fallback = p
	return fallback


func _neighbors(w: int, h: int, i: int) -> Array:
	var x := i % w
	var y := i / w
	var out := []
	if x > 0: out.append(i - 1)
	if x < w - 1: out.append(i + 1)
	if y > 0: out.append(i - w)
	if y < h - 1: out.append(i + w)
	return out


## Camino simple aleatorio de start a exit con al menos min_len nodos.
func _random_path(w: int, h: int, start: int, exit: int, min_len: int, rng: RandomNumberGenerator) -> Array:
	var path := [start]
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited[start] = 1
	var orders := [Rng.shuffle(_neighbors(w, h, start), rng)]
	var budget := 30000
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
		if v == exit:
			if path.size() + 1 >= min_len:
				path.append(v)
				return path
			continue
		visited[v] = 1
		path.append(v)
		orders.append(Rng.shuffle(_neighbors(w, h, v), rng))
	return []


func _try_generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var w: int = cfg.w
	var h: int = cfg.h
	var sx := rng.randi() % 2 * (w - 1)
	var sy := rng.randi() % 2 * (h - 1)
	var start := sy * w + sx
	var exit := (h - 1 - sy) * w + (w - 1 - sx)
	var path := _random_path(w, h, start, exit, cfg.min_len, rng)
	if path.is_empty():
		return {}

	# Interruptores: al menos uno por grupo sobre el camino (para que importen) + señuelos.
	var switches := []
	switches.resize(w * h)
	switches.fill(-1)
	var interior := Rng.shuffle(path.slice(1, path.size() - 1), rng)
	var groups := mini(cfg.groups, interior.size())
	for g in groups:
		switches[interior[g]] = g
	if groups > 0:
		var off := []
		for i in w * h:
			if not path.has(i):
				off.append(i)
		Rng.shuffle(off, rng)
		for k in mini(cfg.decoys, off.size()):
			switches[off[k]] = rng.randi() % groups

	# Aristas del camino plantado: su sentido se elige para que sean transitables en el momento
	# exacto en que la chispa las cruza, teniendo en cuenta los interruptores ya pisados.
	var planted := {}
	var mask := 0
	for i in path.size() - 1:
		var u: int = path[i]
		var v: int = path[i + 1]
		var e := {"a": u, "b": v, "kind": WIRE, "grp": -1}
		if rng.randf() >= cfg.wire:
			e.kind = DIODE
			if groups > 0 and rng.randf() >= cfg.free_diode:
				e.grp = rng.randi() % groups
			if e.grp >= 0 and ((mask >> e.grp) & 1) == 1:
				e.a = v
				e.b = u
		planted[mini(u, v) * 1000 + maxi(u, v)] = e
		var sw: int = switches[v]
		if sw >= 0:
			mask ^= 1 << sw

	# Resto de aristas: cortes, cables o diodos aleatorios.
	var edges := []
	for y in h:
		for x in w:
			var i := y * w + x
			for j in [i + 1 if x < w - 1 else -1, i + w if y < h - 1 else -1]:
				if j < 0:
					continue
				var key := mini(i, j) * 1000 + maxi(i, j)
				if planted.has(key):
					edges.append(planted[key])
					continue
				if rng.randf() < cfg.cut:
					continue
				var e := {"a": i, "b": j, "kind": WIRE, "grp": -1}
				if rng.randf() >= cfg.wire:
					e.kind = DIODE
					if groups > 0 and rng.randf() >= cfg.free_diode:
						e.grp = rng.randi() % groups
					if rng.randf() < 0.5:
						e.a = j
						e.b = i
				edges.append(e)

	return {"type": "circuito", "w": w, "h": h, "start": start, "exit": exit, "groups": groups,
		"switches": switches, "edges": edges, "planted": path}


# --- Reglas -----------------------------------------------------------------------

## Índice de la arista entre u y v (o -1). Se cachea en el propio puzle.
func edge_between(puzzle: Dictionary, u: int, v: int) -> int:
	if not puzzle.has("_lk"):
		var lk := {}
		var n: int = puzzle.w * puzzle.h
		for ei in puzzle.edges.size():
			var e: Dictionary = puzzle.edges[ei]
			lk[e.a * n + e.b] = ei
			lk[e.b * n + e.a] = ei
		puzzle["_lk"] = lk
	var n2: int = puzzle.w * puzzle.h
	return puzzle["_lk"].get(u * n2 + v, -1)


## ¿Puede la chispa ir de u a v por la arista ei con el estado de interruptores `mask`?
func can_pass(puzzle: Dictionary, ei: int, u: int, _v: int, mask: int) -> bool:
	var e: Dictionary = puzzle.edges[ei]
	if e.kind == WIRE:
		return true
	var flipped: bool = e.grp >= 0 and ((mask >> e.grp) & 1) == 1
	return (e.a == u) != flipped


## Sentido actual de una arista: [desde, hasta] (null si es cable).
func effective_dir(puzzle: Dictionary, ei: int, mask: int):
	var e: Dictionary = puzzle.edges[ei]
	if e.kind == WIRE:
		return null
	var flipped: bool = e.grp >= 0 and ((mask >> e.grp) & 1) == 1
	return [e.b, e.a] if flipped else [e.a, e.b]


## Reproduce un camino. Devuelve {ok, reason, index, mask, complete}.
func simulate(puzzle: Dictionary, path: Array, ignore_switches := false) -> Dictionary:
	var res := {"ok": false, "reason": "", "index": 0, "mask": 0, "complete": false}
	var n: int = puzzle.w * puzzle.h
	if path.is_empty() or path[0] != puzzle.start:
		res.reason = "bad_start"
		return res
	var seen := {path[0]: true}
	var mask := 0
	for i in range(1, path.size()):
		var u: int = path[i - 1]
		var v: int = path[i]
		res.index = i
		if u == puzzle.exit:
			res.reason = "past_exit"
			return res
		if v < 0 or v >= n:
			res.reason = "bad_node"
			return res
		if seen.has(v):
			res.reason = "revisit"
			return res
		var ei := edge_between(puzzle, u, v)
		if ei < 0:
			res.reason = "no_edge"
			return res
		if not can_pass(puzzle, ei, u, v, mask):
			res.reason = "blocked"
			return res
		seen[v] = true
		var sw: int = puzzle.switches[v]
		if sw >= 0 and not ignore_switches:
			mask ^= 1 << sw
	res.ok = true
	res.mask = mask
	res.complete = path.back() == puzzle.exit
	res.index = path.size() - 1
	return res


func validate(puzzle: Dictionary, attempt) -> Dictionary:
	var r := simulate(puzzle, attempt)
	if r.ok and not r.complete:
		return {"ok": false, "reason": "incomplete"}
	return {"ok": r.ok, "reason": "ok" if r.ok else r.reason}


# --- Solucionador -----------------------------------------------------------------

## Busca caminos válidos continuando `prefix` (por defecto desde la entrada).
## Cuenta hasta `limit` soluciones. Devuelve {solvable, count, solution, exhausted}.
func solve(puzzle: Dictionary, prefix: Array = [], limit: int = 1, ignore_switches := false) -> Dictionary:
	var n: int = puzzle.w * puzzle.h
	_edges = puzzle.edges
	_switches = puzzle.switches
	_adj = []
	for i in n:
		_adj.append([])
	for ei in _edges.size():
		var e: Dictionary = _edges[ei]
		_adj[e.a].append([e.b, ei])
		_adj[e.b].append([e.a, ei])
	_visited = PackedByteArray()
	_visited.resize(n)
	_exit = puzzle.exit
	_found = 0
	_limit = limit
	_budget = SEARCH_BUDGET
	_ignore = ignore_switches
	_solution = []
	var start_path: Array = prefix if not prefix.is_empty() else [puzzle.start]
	var sim := simulate(puzzle, start_path, ignore_switches)
	if not sim.ok:
		return {"solvable": false, "count": 0, "solution": [], "exhausted": false}
	_path = start_path.duplicate()
	for v in _path:
		_visited[v] = 1
	_dfs(_path.back(), sim.mask)
	return {"solvable": _found > 0, "count": _found, "solution": _solution, "exhausted": _budget <= 0}


func _dfs(u: int, mask: int) -> void:
	if _found >= _limit or _budget <= 0:
		return
	_budget -= 1
	if u == _exit:
		_found += 1
		if _found == 1:
			_solution = _path.duplicate()
		return
	for pair in _adj[u]:
		var v: int = pair[0]
		if _visited[v] == 1:
			continue
		var e: Dictionary = _edges[pair[1]]
		if e.kind == DIODE:
			var flipped: bool = e.grp >= 0 and ((mask >> e.grp) & 1) == 1
			if (e.a == u) == flipped:
				continue
		_visited[v] = 1
		_path.append(v)
		var m := mask
		var sw: int = _switches[v]
		if sw >= 0 and not _ignore:
			m ^= 1 << sw
		_dfs(v, m)
		_path.pop_back()
		_visited[v] = 0
