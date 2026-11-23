extends RefCounted
## Lógica pura del juego (sin nodos): flechas sobre una cuadrícula que hay que despejar.
##
## Cada flecha es una cadena de casillas contiguas (cola -> cabeza). Al tocarla avanza en la
## dirección de su cabeza, en línea recta, y sale del tablero si el camino está libre.
## Si otra flecha se cruza en ese camino, choca y vuelve a su sitio.
##
## Puzle: {w, h, arrows: [{cells: [Vector2i] (cola..cabeza), dir: Vector2i}]}
##
## Generación con solución garantizada: las flechas se colocan una a una y cada nueva flecha
## debe tener libre su camino de salida respecto a las YA colocadas. Así, quitarlas en orden
## inverso a su colocación siempre funciona. Las flechas nuevas sí pueden tapar la salida de
## las antiguas: eso crea las dependencias que hacen el puzle interesante.
## Además, quitar una flecha nunca empeora el tablero, de modo que un solucionador voraz
## (quitar cualquier flecha libre, repetir) decide exactamente si un tablero tiene solución.

const Rng = preload("res://core/rng.gd")
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Valores especiales del mapa de ocupación.
const ROCK := -2   # obstáculo: bloquea las salidas
const HOLE := -3   # hueco (solo en el generador): no se puede ocupar, pero se puede cruzar


static func head(a: Dictionary) -> Vector2i:
	return a.cells[a.cells.size() - 1]


static func inside(p: Dictionary, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < p.w and c.y < p.h


## Mapa casilla -> índice de flecha (-1 vacía), ignorando las flechas de `removed`.
static func occupancy(p: Dictionary, removed: Dictionary = {}) -> PackedInt32Array:
	var occ := PackedInt32Array()
	occ.resize(p.w * p.h)
	occ.fill(-1)
	for c in p.get("rocks", []):
		occ[c.y * p.w + c.x] = ROCK
	for i in p.arrows.size():
		if removed.has(i):
			continue
		for c in p.arrows[i].cells:
			occ[c.y * p.w + c.x] = i
	return occ


## Casillas por las que pasa la cabeza al salir, hasta el borde.
static func exit_path(p: Dictionary, i: int) -> Array:
	var a: Dictionary = p.arrows[i]
	var out := []
	var c: Vector2i = head(a) + a.dir
	while inside(p, c):
		out.append(c)
		c += a.dir
	return out


## {by: flecha que bloquea (-1 si sale, ROCK si es un obstáculo), steps: casillas que avanza antes de chocar}.
static func blocker(p: Dictionary, i: int, occ: PackedInt32Array) -> Dictionary:
	var steps := 0
	for c in exit_path(p, i):
		var o := occ[c.y * p.w + c.x]
		if o != -1 and o != i:
			return {"by": o, "steps": steps}
		steps += 1
	return {"by": -1, "steps": steps}


static func can_exit(p: Dictionary, i: int, occ: PackedInt32Array) -> bool:
	return blocker(p, i, occ).by == -1


## Flechas que pueden salir ahora mismo.
static func free_arrows(p: Dictionary, removed: Dictionary) -> Array:
	var occ := occupancy(p, removed)
	var out := []
	for i in p.arrows.size():
		if not removed.has(i) and can_exit(p, i, occ):
			out.append(i)
	return out


## Solucionador voraz por capas. layers = profundidad de dependencias (medida de dificultad);
## min_free = mínimo de flechas libres a la vez; free0 = libres al empezar.
## Incremental: al quitar una flecha solo se revisan las que estaban esperando a esa.
static func solve(p: Dictionary, removed_in: Dictionary = {}) -> Dictionary:
	var removed := removed_in.duplicate()
	var occ := occupancy(p, removed)
	var n: int = p.arrows.size()
	var waiting := {}  # bloqueadora -> [flechas que esperan]
	var layer := []
	for i in n:
		if removed.has(i):
			continue
		var by: int = blocker(p, i, occ).by
		if by == -1:
			layer.append(i)
		else:
			if not waiting.has(by):
				waiting[by] = []
			waiting[by].append(i)
	var free0 := layer.size()
	var order := []
	var layers := 0
	var min_free := 1 << 30
	while not layer.is_empty():
		layers += 1
		min_free = mini(min_free, layer.size())
		var next := []
		for x in layer:
			order.append(x)
			removed[x] = true
			for c in p.arrows[x].cells:
				occ[c.y * p.w + c.x] = -1
		for x in layer:
			for i in waiting.get(x, []):
				var by: int = blocker(p, i, occ).by
				if by == -1:
					next.append(i)
				else:
					if not waiting.has(by):
						waiting[by] = []
					waiting[by].append(i)
		layer = next
	var ok := order.size() == n - removed_in.size()
	return {"solvable": ok, "order": order, "layers": layers,
		"min_free": min_free if layers > 0 else 0, "free0": free0}


## Comprobación estructural de un puzle. {ok, reason}.
static func validate(p: Dictionary) -> Dictionary:
	var seen := {}
	var bad := {}
	for c in p.get("holes", []):
		bad[c] = true
	var rock_set := {}
	for c in p.get("rocks", []):
		bad[c] = true
		rock_set[c] = true
	for i in p.arrows.size():
		var a: Dictionary = p.arrows[i]
		var cells: Array = a.cells
		if cells.size() < 2:
			return {"ok": false, "reason": "too_short"}
		if cells[cells.size() - 1] - cells[cells.size() - 2] != a.dir:
			return {"ok": false, "reason": "bad_dir"}
		for k in cells.size():
			var c: Vector2i = cells[k]
			if not inside(p, c):
				return {"ok": false, "reason": "outside"}
			if seen.has(c):
				return {"ok": false, "reason": "overlap"}
			if bad.has(c):
				return {"ok": false, "reason": "on_hole_or_rock"}
			seen[c] = true
			if k > 0:
				var d: Vector2i = c - cells[k - 1]
				if absi(d.x) + absi(d.y) != 1:
					return {"ok": false, "reason": "not_contiguous"}
		for c in exit_path(p, i):
			if cells.has(c):
				return {"ok": false, "reason": "self_block"}
			if rock_set.has(c):
				return {"ok": false, "reason": "rock_block"}
	return {"ok": true, "reason": "ok"}


# --- Generación -------------------------------------------------------------------

## params: w, h, min_len, max_len, turn, coverage, target_depth, candidates
## Genera varios candidatos y se queda con el de profundidad más cercana al objetivo.
static func generate(seed_value: int, params: Dictionary) -> Dictionary:
	if params.get("maze", false):
		var m := generate_maze(seed_value, params)
		if not m.is_empty():
			return m
	var best := {}
	var best_score := INF
	for k in params.get("candidates", 4):
		var rng := Rng.make(Rng.derive(seed_value, k))
		var p := _build(rng, params)
		var s := solve(p)
		if not s.solvable or p.arrows.size() < 2:
			continue
		var cov := 0
		for a in p.arrows:
			cov += a.cells.size()
		var free_frac: float = float(s.free0) / p.arrows.size()
		var score: float = absf(s.layers - params.get("target_depth", 3)) * 2.0 \
			+ absf(free_frac - params.get("target_free", 0.1)) * 60.0 \
			- float(cov) / (p.w * p.h) * 20.0
		if score < best_score:
			best_score = score
			best = p
			best["depth"] = s.layers
	return best


static func _build(rng: RandomNumberGenerator, params: Dictionary) -> Dictionary:
	var w: int = params.w
	var h: int = params.h
	var p := {"w": w, "h": h, "arrows": [], "holes": params.get("holes", []), "rocks": params.get("rocks", []),
		"shape": params.get("shape", "rect")}
	# Estado del constructor:
	#   occ      casilla -> flecha
	#   rays_at  casilla -> flechas cuyo camino de salida pasa por ella
	#   waits    flecha -> {flechas que tiene delante y debe esperar}
	#   free     flechas sin nada delante (saldrían al primer toque)
	#   hot      casilla -> nº de flechas libres cuyo camino pasa por ella
	var st := {"w": w, "h": h, "occ": PackedInt32Array(), "rays_at": [], "waits": [], "free": {},
		"hot": PackedInt32Array(), "ray_cells": []}
	st.occ.resize(w * h)
	st.occ.fill(-1)
	for c in p.holes:
		st.occ[c.y * w + c.x] = HOLE
	for c in p.rocks:
		st.occ[c.y * w + c.x] = ROCK
	st.hot.resize(w * h)
	for i in w * h:
		st.rays_at.append([])
	var playable: int = w * h - p.holes.size() - p.rocks.size()
	var filled := 0
	var target := int(params.coverage * playable)
	var long_bias: float = params.get("long_bias", 0.6)
	var chain_bias: float = params.get("chain_bias", 0.5)
	# Fase 0: "serpientes" largas que se enroscan y cruzan el tablero (se colocan primero,
	# cuando aún hay espacio). Después, flechas de todos los tamaños.
	var snakes: int = params.get("snakes", 0)
	var placed_snakes := 0
	for _t in snakes * 30:
		if placed_snakes >= snakes:
			break
		var hd := Vector2i(rng.randi() % w, rng.randi() % h)
		if st.occ[hd.y * w + hd.x] != -1:
			continue
		var dirs := []
		for d in DIRS:
			if _dir_ok(st, hd, d):
				dirs.append(d)
		if dirs.is_empty():
			continue
		var d: Vector2i = dirs[rng.randi() % dirs.size()]
		var want := rng.randi_range(params.get("snake_min", 10), params.get("snake_max", 20))
		var body := _grow(rng, st, hd, d, want, params.get("snake_turn", 0.45), 0.0, params.get("curl", 0.75))
		body = _trim_cycles(p, st, body, d, params.min_len)
		if body.size() < maxi(params.min_len, want / 2):
			continue
		_commit(p, st, body, d)
		filled += body.size()
		placed_snakes += 1
	for phase in 2:
		var max_len: int = params.max_len if phase == 0 else mini(5, params.max_len)
		var tries := w * h * 6 if phase == 0 else int(w * h * params.get("fill_pass", 4.0))
		for _t in tries:
			if phase == 0 and filled >= target:
				break
			var hd := Vector2i(rng.randi() % w, rng.randi() % h)
			if phase == 0 and not st.free.is_empty() and rng.randf() < chain_bias:
				var fk: Array = st.free.keys()
				var j: int = fk[rng.randi() % fk.size()]
				var cand := []
				for k in st.ray_cells[j]:
					if st.occ[k] == -1:
						cand.append(Vector2i(k % w, k / w))
				if not cand.is_empty():
					hd = cand[rng.randi() % cand.size()]
			if st.occ[hd.y * w + hd.x] != -1:
				continue
			# Direcciones posibles y cuántas flechas tendría delante cada una.
			var opts := []
			for d in DIRS:
				var b: Vector2i = hd - d
				if b.x < 0 or b.y < 0 or b.x >= w or b.y >= h or st.occ[b.y * w + b.x] != -1:
					continue
				var ahead := {}
				var c: Vector2i = hd + d
				var blocked := false
				while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
					var o: int = st.occ[c.y * w + c.x]
					if o == ROCK:
						blocked = true
						break
					if o >= 0:
						ahead[o] = true
					c += d
				if not blocked:
					opts.append([d, ahead.size()])
			if opts.is_empty():
				continue
			var d: Vector2i
			if rng.randf() < long_bias:
				# Apuntar hacia otras flechas: más dependencias, menos flechas "regaladas".
				opts.sort_custom(func(x, y): return x[1] > y[1])
				d = opts[0][0]
			else:
				d = opts[rng.randi() % opts.size()][0]
			var body := _grow(rng, st, hd, d, _pick_len(rng, params, max_len), params.turn, chain_bias, params.get("curl_mid", 0.0))
			body = _trim_cycles(p, st, body, d, params.min_len)
			if body.size() < params.min_len:
				continue
			_commit(p, st, body, d)
			filled += body.size()
	_extend_tails(rng, p, st, params, chain_bias)
	return p


## ¿Puede apuntar la cabeza en hd hacia d? (casilla de detrás libre y ninguna roca delante)
static func _dir_ok(st: Dictionary, hd: Vector2i, d: Vector2i) -> bool:
	var w: int = st.w
	var h: int = st.h
	var b: Vector2i = hd - d
	if b.x < 0 or b.y < 0 or b.x >= w or b.y >= h or st.occ[b.y * w + b.x] != -1:
		return false
	var c: Vector2i = hd + d
	while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
		if st.occ[c.y * w + c.x] == ROCK:
			return false
		c += d
	return true


static func _ray_cells(w: int, h: int, hd: Vector2i, d: Vector2i) -> Array:
	var out := []
	var c := hd + d
	while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
		out.append(c.y * w + c.x)
		c += d
	return out


## ¿Se puede llegar desde alguna flecha de `from` a alguna de `targets` siguiendo esperas?
static func _reaches(st: Dictionary, from: Dictionary, targets: Dictionary) -> bool:
	var seen := {}
	var stack: Array = from.keys()
	while not stack.is_empty():
		var x: int = stack.pop_back()
		if targets.has(x):
			return true
		if seen.has(x):
			continue
		seen[x] = true
		for y in st.waits[x]:
			if not seen.has(y):
				stack.append(y)
	return false


## Recorta la cola de una flecha candidata hasta que no cree un ciclo de esperas
## (A espera a B y B espera a A), que haría el tablero irresoluble.
static func _trim_cycles(p: Dictionary, st: Dictionary, body: Array, d: Vector2i, min_len: int) -> Array:
	var w: int = st.w
	var ahead := {}  # flechas que la nueva tendría delante (las espera)
	for k in _ray_cells(w, st.h, body[body.size() - 1], d):
		if st.occ[k] >= 0:
			ahead[st.occ[k]] = true
	while body.size() >= min_len:
		var behind := {}  # flechas que pasarían a esperar a la nueva
		for c in body:
			for j in st.rays_at[c.y * w + c.x]:
				behind[j] = true
		if ahead.is_empty() or behind.is_empty() or not _reaches(st, ahead, behind):
			return body
		body.pop_front()
	return []


static func _commit(p: Dictionary, st: Dictionary, body: Array, d: Vector2i) -> void:
	var w: int = st.w
	var idx: int = p.arrows.size()
	p.arrows.append({"cells": body, "dir": d})
	st.waits.append({})
	var ray := _ray_cells(w, st.h, body[body.size() - 1], d)
	for k in ray:
		if st.occ[k] >= 0:
			st.waits[idx][st.occ[k]] = true
	for c in body:
		_occupy(st, c, idx)
	st.ray_cells.append(ray)
	for k in ray:
		st.rays_at[k].append(idx)
	if st.waits[idx].is_empty():
		st.free[idx] = true
		for k in ray:
			st.hot[k] += 1


## Ocupa una casilla con la flecha idx: quien tenga ahí su camino de salida pasa a esperarla.
static func _occupy(st: Dictionary, c: Vector2i, idx: int) -> void:
	var k: int = c.y * st.w + c.x
	st.occ[k] = idx
	for j in st.rays_at[k]:
		if j == idx:
			continue
		st.waits[j][idx] = true
		if st.free.has(j):
			st.free.erase(j)
			for rk in st.ray_cells[j]:
				st.hot[rk] -= 1


## Hace crecer el cuerpo hacia atrás desde la cabeza (devuelve cola..cabeza). Con
## probabilidad chain_bias prefiere pasar por caminos de flechas libres para taparlas.
static func _grow(rng: RandomNumberGenerator, st: Dictionary, hd: Vector2i, d: Vector2i,
		want: int, turn: float, chain_bias: float, curl := 0.0) -> Array:
	var w: int = st.w
	var h: int = st.h
	var ray := {}
	var c := hd + d
	while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
		ray[c] = true
		c += d
	var b := hd - d
	var body := [hd, b]
	var used := {hd: true, b: true}
	var step := d
	var cur := b
	var sense := 1 if rng.randf() < 0.5 else -1  # sentido de giro preferido (espirales)
	while body.size() < want:
		var perp := [Vector2i(step.y, step.x), Vector2i(-step.y, -step.x)]
		if curl > 0.0:
			# Enroscarse: casi siempre se gira hacia el mismo lado, y a veces se cambia.
			if rng.randf() < 0.1:
				sense = -sense
			var pref: Vector2i = Vector2i(-step.y, step.x) * sense
			perp = [pref, -pref] if rng.randf() < curl else [-pref, pref]
		else:
			Rng.shuffle(perp, rng)
		var opts := [perp[0], perp[1], step] if rng.randf() < turn else [step, perp[0], perp[1]]
		var valid := []
		for s in opts:
			var n: Vector2i = cur - s
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if st.occ[n.y * w + n.x] != -1 or used.has(n) or ray.has(n):
				continue
			valid.append(s)
		if valid.is_empty():
			break
		var pick: Vector2i = valid[0]
		if rng.randf() < chain_bias:
			for s in valid:
				var n2: Vector2i = cur - s
				if st.hot[n2.y * w + n2.x] > 0:
					pick = s
					break
		var nn: Vector2i = cur - pick
		body.append(nn)
		used[nn] = true
		cur = nn
		step = pick
	body.reverse()
	return body


## Largo de una flecha: corta, media o larga según las proporciones del nivel.
static func _pick_len(rng: RandomNumberGenerator, params: Dictionary, max_len: int) -> int:
	var lo: int = params.min_len
	var r := rng.randf()
	var long_ratio: float = params.get("long_ratio", 0.2)
	if r < long_ratio:
		return rng.randi_range(mini(10, max_len), max_len)
	if r < long_ratio + 0.45:
		return rng.randi_range(mini(5, max_len), mini(10, max_len))
	return rng.randi_range(lo, mini(lo + 2, max_len))


## Alarga colas hacia las casillas vacías para llenar el tablero, sin crear ciclos de espera.
## Prefiere casillas que tapan caminos de flechas libres.
static func _extend_tails(rng: RandomNumberGenerator, p: Dictionary, st: Dictionary, params: Dictionary, chain_bias: float) -> void:
	var w: int = p.w
	var h: int = p.h
	var cap: int = int(params.max_len * 1.4)
	var snake_cap: int = params.get("snake_max", cap)
	var order := range(p.arrows.size())
	for _round in params.get("extend_rounds", 4):
		Rng.shuffle(order, rng)
		var grew := false
		for k in order:
			var a: Dictionary = p.arrows[k]
			var own := {}
			for rk in st.ray_cells[k]:
				own[rk] = true
			var me := {k: true}
			var my_cap: int = snake_cap if a.cells.size() > cap else cap
			while a.cells.size() < my_cap:
				var tail: Vector2i = a.cells[0]
				var opts := DIRS.duplicate()
				Rng.shuffle(opts, rng)
				var valid := []
				for d in opts:
					var n: Vector2i = tail + d
					if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
						continue
					var idx := n.y * w + n.x
					if st.occ[idx] != -1 or own.has(idx):
						continue
					# Quien tenga su salida por aquí pasaría a esperar a k: no debe esperarle k.
					var behind := {}
					for j in st.rays_at[idx]:
						if j != k:
							behind[j] = true
					if not behind.is_empty() and _reaches(st, me, behind):
						continue
					valid.append(n)
				if valid.is_empty():
					break
				var pick: Vector2i = valid[0]
				if rng.randf() < chain_bias:
					for n in valid:
						if st.hot[n.y * w + n.x] > 0:
							pick = n
							break
				a.cells.insert(0, pick)
				_occupy(st, pick, k)
				grew = true
		if not grew:
			break


# --- Modo laberinto: flechas muy largas que llenan todo el tablero ------------------

## Genera un tablero "laberinto": primero se cubre el tablero con caminos largos y
## serpenteantes (como los pasillos de un laberinto) y después se decide hacia qué extremo
## apunta cada uno simulando la partida al revés: se va retirando una pieza que pueda salir
## y se fija su punta en ese momento. Ese orden es una solución, así que el tablero siempre
## se puede resolver. Para que sea difícil, se elige la punta que tenga que esperar a más
## piezas (las ya retiradas que hay en su camino de salida).
static func generate_maze(seed_value: int, params: Dictionary) -> Dictionary:
	var best := {}
	var best_score := INF
	for k in params.get("candidates", 3):
		var rng := Rng.make(Rng.derive(seed_value, 500 + k))
		var p := _maze_build(rng, params)
		var s := solve(p)
		if not s.solvable or p.arrows.size() < 2:
			continue
		var free_frac: float = float(s.free0) / p.arrows.size()
		var score: float = absf(s.layers - params.get("target_depth", 20)) * 1.0 + free_frac * 60.0
		if score < best_score:
			best_score = score
			best = p
			best["depth"] = s.layers
	return best


static func _maze_build(rng: RandomNumberGenerator, params: Dictionary) -> Dictionary:
	var w: int = params.w
	var h: int = params.h
	var p := {"w": w, "h": h, "arrows": [], "holes": params.get("holes", []), "rocks": params.get("rocks", []),
		"shape": params.get("shape", "rect"), "maze": true}
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	for c in p.holes:
		blocked[c.y * w + c.x] = 1
	var rock := PackedByteArray()
	rock.resize(w * h)
	for c in p.rocks:
		blocked[c.y * w + c.x] = 1
		rock[c.y * w + c.x] = 1
	var paths := _path_cover(rng, w, h, blocked, params.get("maze_min", 6), params.get("maze_max", 40), params.get("maze_turn", 0.35))
	# Simulación inversa: occ = piezas que siguen en el tablero; gone = de qué pieza retirada
	# era cada casilla (para contar dependencias).
	var occ := PackedInt32Array()
	occ.resize(w * h)
	occ.fill(-1)
	for i in paths.size():
		for c in paths[i]:
			occ[c.y * w + c.x] = i
	var gone := PackedInt32Array()
	gone.resize(w * h)
	gone.fill(-1)
	var remaining := {}
	for i in paths.size():
		remaining[i] = true
	var greed: float = params.get("maze_greed", 0.8)
	var guard := 20000
	var splits := 0
	while not remaining.is_empty() and guard > 0:
		guard -= 1
		var cands := []
		for i in remaining:
			var cells: Array = paths[i]
			for rev in [false, true]:
				var hd: Vector2i = cells[0] if rev else cells[cells.size() - 1]
				var prev: Vector2i = cells[1] if rev else cells[cells.size() - 2]
				var d: Vector2i = hd - prev
				var c: Vector2i = hd + d
				var ok := true
				var deps := {}
				while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
					var k := c.y * w + c.x
					if occ[k] != -1 or rock[k] == 1:
						ok = false
						break
					if gone[k] != -1:
						deps[gone[k]] = true
					c += d
				if ok:
					cands.append([i, rev, deps.size() + rng.randf() * 0.5])
		if cands.is_empty():
			# Nadie puede salir: se busca el corte que deja salir el trozo más largo posible
			# (el extremo nuevo que crea el corte apunta a una zona libre).
			var best_cut := []
			var tried := 0
			for i in remaining:
				var cells2: Array = paths[i]
				if cells2.size() < 4:
					continue
				tried += 1
				if tried > 40:
					break
				for k in range(2, cells2.size() - 1):
					# Trozo A = [0, k) con la punta en k-1; trozo B = [k, fin) con la punta en k.
					for side in 2:
						var hd: Vector2i = cells2[k - 1] if side == 0 else cells2[k]
						var prev: Vector2i = cells2[k - 2] if side == 0 else cells2[k + 1]
						var d: Vector2i = hd - prev
						var c: Vector2i = hd + d
						var ok := true
						while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
							var kk := c.y * w + c.x
							if occ[kk] != -1 or rock[kk] == 1:
								ok = false
								break
							c += d
						if ok:
							var piece_len: int = k if side == 0 else cells2.size() - k
							if best_cut.is_empty() or piece_len > best_cut[2]:
								best_cut = [i, k, piece_len]
			if best_cut.is_empty():
				break
			splits += 1
			var li: int = best_cut[0]
			var cells4: Array = paths[li]
			var tail_part := cells4.slice(best_cut[1])
			paths[li] = cells4.slice(0, best_cut[1])
			paths.append(tail_part)
			var ni := paths.size() - 1
			for cc in tail_part:
				occ[cc.y * w + cc.x] = ni
			remaining[ni] = true
			continue
		var pick: Array
		if rng.randf() < greed:
			cands.sort_custom(func(a, b): return a[2] > b[2])
			pick = cands[rng.randi() % mini(3, cands.size())]
		else:
			pick = cands[rng.randi() % cands.size()]
		var idx: int = pick[0]
		var cells3: Array = paths[idx].duplicate()
		if pick[1]:
			cells3.reverse()
		p.arrows.append({"cells": cells3, "dir": cells3[cells3.size() - 1] - cells3[cells3.size() - 2]})
		var ai: int = p.arrows.size() - 1
		for cc in cells3:
			occ[cc.y * w + cc.x] = -1
			gone[cc.y * w + cc.x] = ai
		remaining.erase(idx)
	p["splits"] = splits
	p["stuck"] = remaining.size()
	return p


## Cubre el tablero con caminos largos y serpenteantes. Cada camino crece por sus dos
## extremos eligiendo casi siempre la casilla vecina con menos salidas libres (regla de
## Warnsdorff), lo que evita dejar huecos aislados. Las casillas sueltas que quedan se pegan
## al extremo de un camino vecino.
static func _path_cover(rng: RandomNumberGenerator, w: int, h: int, blocked: PackedByteArray,
		lmin: int, lmax: int, turn: float) -> Array:
	var used := blocked.duplicate()
	var paths := []
	var order := []
	for i in w * h:
		if used[i] == 0:
			order.append(i)
	Rng.shuffle(order, rng)
	var remaining := order.size()
	while remaining > 0:
		# Empezar por una casilla con pocas salidas (rincones y huecos estrechos).
		var start := -1
		var best_deg := 5
		for i in order:
			if used[i] == 0:
				var dg := _free_deg(used, w, h, i)
				if dg < best_deg:
					best_deg = dg
					start = i
					if dg <= 1:
						break
		var target := rng.randi_range(lmin, lmax)
		var path := [Vector2i(start % w, start / w)]
		used[start] = 1
		remaining -= 1
		for end in 2:
			var last_step := Vector2i.ZERO
			while path.size() < target:
				var cur: Vector2i = path[path.size() - 1] if end == 0 else path[0]
				var opts := []
				for d in DIRS:
					var n: Vector2i = cur + d
					if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or used[n.y * w + n.x] == 1:
						continue
					opts.append([n, d, _free_deg(used, w, h, n.y * w + n.x)])
				if opts.is_empty():
					break
				var pick: Array = opts[rng.randi() % opts.size()]
				var r := rng.randf()
				if r < 0.65:
					opts.sort_custom(func(a, b): return a[2] < b[2])
					pick = opts[0]
				elif r < 0.65 + (1.0 - turn) * 0.35:
					for o in opts:
						if o[1] == last_step:
							pick = o
				var n2: Vector2i = pick[0]
				used[n2.y * w + n2.x] = 1
				remaining -= 1
				last_step = pick[1]
				if end == 0:
					path.append(n2)
				else:
					path.insert(0, n2)
		paths.append(path)
	# Casillas sueltas: pegarlas al extremo de un camino vecino.
	var owner := {}
	for i in paths.size():
		owner[paths[i][0]] = i
		owner[paths[i][paths[i].size() - 1]] = i
	var out := []
	for i in paths.size():
		if paths[i].size() >= 2:
			continue
		var c: Vector2i = paths[i][0]
		for d in DIRS:
			var n: Vector2i = c + d
			if owner.has(n) and owner[n] != i and paths[owner[n]].size() >= 2:
				var j: int = owner[n]
				if paths[j][0] == n:
					paths[j].insert(0, c)
				else:
					paths[j].append(c)
				owner.erase(n)
				owner[c] = j
				paths[i] = []
				break
	for pth in paths:
		if pth.size() >= 2:
			out.append(pth)
	return out


static func _free_deg(used: PackedByteArray, w: int, h: int, i: int) -> int:
	var x := i % w
	var y := i / w
	var n := 0
	if x > 0 and used[i - 1] == 0:
		n += 1
	if x < w - 1 and used[i + 1] == 0:
		n += 1
	if y > 0 and used[i - w] == 0:
		n += 1
	if y < h - 1 and used[i + w] == 0:
		n += 1
	return n
