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


static func head(a: Dictionary) -> Vector2i:
	return a.cells[a.cells.size() - 1]


static func inside(p: Dictionary, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < p.w and c.y < p.h


## Mapa casilla -> índice de flecha (-1 vacía), ignorando las flechas de `removed`.
static func occupancy(p: Dictionary, removed: Dictionary = {}) -> PackedInt32Array:
	var occ := PackedInt32Array()
	occ.resize(p.w * p.h)
	occ.fill(-1)
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


## {by: flecha que bloquea (-1 si sale), steps: casillas que avanza antes de chocar}.
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
## min_free = mínimo de flechas libres a la vez (menos opciones = más difícil).
static func solve(p: Dictionary, removed_in: Dictionary = {}) -> Dictionary:
	var removed := removed_in.duplicate()
	var order := []
	var layers := 0
	var min_free := 1 << 30
	var remaining: int = p.arrows.size() - removed.size()
	while remaining > 0:
		var free := free_arrows(p, removed)
		if free.is_empty():
			return {"solvable": false, "order": order, "layers": layers, "min_free": 0}
		layers += 1
		min_free = mini(min_free, free.size())
		for i in free:
			removed[i] = true
			order.append(i)
		remaining -= free.size()
	return {"solvable": true, "order": order, "layers": layers, "min_free": min_free if layers > 0 else 0}


## Comprobación estructural de un puzle. {ok, reason}.
static func validate(p: Dictionary) -> Dictionary:
	var seen := {}
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
			seen[c] = true
			if k > 0:
				var d: Vector2i = c - cells[k - 1]
				if absi(d.x) + absi(d.y) != 1:
					return {"ok": false, "reason": "not_contiguous"}
		for c in exit_path(p, i):
			if cells.has(c):
				return {"ok": false, "reason": "self_block"}
	return {"ok": true, "reason": "ok"}


# --- Generación -------------------------------------------------------------------

## params: w, h, min_len, max_len, turn, coverage, target_depth, candidates
## Genera varios candidatos y se queda con el de profundidad más cercana al objetivo.
static func generate(seed_value: int, params: Dictionary) -> Dictionary:
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
		var score: float = absf(s.layers - params.get("target_depth", 3)) * 10.0 \
			- float(cov) / (p.w * p.h) * 5.0
		if score < best_score:
			best_score = score
			best = p
			best["depth"] = s.layers
	return best


static func _build(rng: RandomNumberGenerator, params: Dictionary) -> Dictionary:
	var w: int = params.w
	var h: int = params.h
	var p := {"w": w, "h": h, "arrows": []}
	var occ := PackedInt32Array()
	occ.resize(w * h)
	occ.fill(-1)
	var filled := 0
	var target := int(params.coverage * w * h)
	var long_bias: float = params.get("long_bias", 0.6)
	var chain_bias: float = params.get("chain_bias", 0.5)
	# Fase 1: flechas de longitud normal. Fase 2: relleno de huecos con flechas cortas.
	for phase in 2:
		var max_len: int = params.max_len if phase == 0 else mini(3, params.max_len)
		var tries := w * h * (10 if phase == 0 else 6)
		for _t in tries:
			if phase == 0 and filled >= target:
				break
			var hd := Vector2i(rng.randi() % w, rng.randi() % h)
			# Encadenar: poner la cabeza en el camino de salida de una flecha reciente, que
			# tendrá que esperar a esta. Así se forman cadenas largas de dependencias.
			if phase == 0 and not p.arrows.is_empty() and rng.randf() < chain_bias:
				var r: int = p.arrows.size() - 1 - rng.randi() % mini(3, p.arrows.size())
				var ra: Dictionary = p.arrows[r]
				var free_ray := []
				var rc: Vector2i = ra.cells[ra.cells.size() - 1] + ra.dir
				while rc.x >= 0 and rc.y >= 0 and rc.x < w and rc.y < h:
					if occ[rc.y * w + rc.x] == -1:
						free_ray.append(rc)
					rc += ra.dir
				if not free_ray.is_empty():
					hd = free_ray[rng.randi() % free_ray.size()]
			if occ[hd.y * w + hd.x] != -1:
				continue
			# Direcciones con salida libre y su longitud de recorrido.
			var opts := []
			for d in DIRS:
				var b: Vector2i = hd - d
				if b.x < 0 or b.y < 0 or b.x >= w or b.y >= h or occ[b.y * w + b.x] != -1:
					continue
				var c: Vector2i = hd + d
				var n := 0
				var ok := true
				while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
					if occ[c.y * w + c.x] != -1:
						ok = false
						break
					n += 1
					c += d
				if ok:
					opts.append([d, n])
			if opts.is_empty():
				continue
			var d: Vector2i
			if rng.randf() < long_bias:
				# La que cruza más tablero: así las flechas siguientes la taparán (dependencias).
				opts.sort_custom(func(x, y): return x[1] > y[1])
				d = opts[0][0]
			else:
				d = opts[rng.randi() % opts.size()][0]
			var arrow := _grow(rng, occ, w, h, hd, d, rng.randi_range(params.min_len, max_len), params.turn)
			if arrow.size() < params.min_len:
				continue
			var idx: int = p.arrows.size()
			for cc in arrow:
				occ[cc.y * w + cc.x] = idx
			p.arrows.append({"cells": arrow, "dir": d})
			filled += arrow.size()
	return p


## Hace crecer el cuerpo hacia atrás desde la cabeza. Devuelve las casillas cola..cabeza.
static func _grow(rng: RandomNumberGenerator, occ: PackedInt32Array, w: int, h: int,
		hd: Vector2i, d: Vector2i, want: int, turn: float) -> Array:
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
	while body.size() < want:
		var perp := [Vector2i(step.y, step.x), Vector2i(-step.y, -step.x)]
		Rng.shuffle(perp, rng)
		var opts := [perp[0], perp[1], step] if rng.randf() < turn else [step, perp[0], perp[1]]
		var moved := false
		for s in opts:
			var n: Vector2i = cur - s
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if occ[n.y * w + n.x] != -1 or used.has(n) or ray.has(n):
				continue
			body.append(n)
			used[n] = true
			cur = n
			step = s
			moved = true
			break
		if not moved:
			break
	body.reverse()
	return body
