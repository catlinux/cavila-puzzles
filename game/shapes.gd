extends RefCounted
## Formas de tablero. Devuelve las casillas que no se usan:
##   holes: huecos en el borde (fuera del tablero; las flechas pasan volando por encima)
##   rocks: obstáculos infranqueables (ninguna flecha puede apuntar hacia ellos).
##          Todo lo que queda en medio del tablero es siempre roca, nunca hueco.

## Formas en el orden en que se desbloquean.
const KINDS := ["rect", "corners", "oval", "diamond", "cross", "ring", "rocks", "pillar", "hourglass", "steps"]


static func make(kind: String, w: int, h: int, rng: RandomNumberGenerator) -> Dictionary:
	var holes := []
	var rocks := []
	var cx := (w - 1) / 2.0
	var cy := (h - 1) / 2.0
	match kind:
		"corners":
			var k := maxi(1, mini(w, h) / 5)
			for y in h:
				for x in w:
					var dx := mini(x, w - 1 - x)
					var dy := mini(y, h - 1 - y)
					if dx + dy < k:
						holes.append(Vector2i(x, y))
		"oval":
			for y in h:
				for x in w:
					var nx := (x - cx) / (w / 2.0)
					var ny := (y - cy) / (h / 2.0)
					if nx * nx + ny * ny > 1.0:
						holes.append(Vector2i(x, y))
		"diamond":
			for y in h:
				for x in w:
					if absf(x - cx) / (w / 2.0 + 0.5) + absf(y - cy) / (h / 2.0 + 0.5) > 1.0:
						holes.append(Vector2i(x, y))
		"cross":
			var bx := maxi(1, w / 4)
			var by := maxi(1, h / 5)
			for y in h:
				for x in w:
					if (x < bx or x >= w - bx) and (y < by or y >= h - by):
						holes.append(Vector2i(x, y))
		"ring":
			# El centro es un bloque macizo: obstáculo infranqueable (no un hueco).
			var rx := maxi(1, w / 6)
			var ry := maxi(1, h / 7)
			for y in h:
				for x in w:
					if absf(x - cx) <= rx and absf(y - cy) <= ry:
						rocks.append(Vector2i(x, y))
		"hourglass":
			for y in h:
				for x in w:
					var narrow := (1.0 - absf(y - cy) / (h / 2.0)) * w * 0.3
					if x < narrow or x > w - 1 - narrow:
						holes.append(Vector2i(x, y))
		"steps":
			var step := maxi(2, h / 5)
			for y in h:
				for x in w:
					if x < (y / step) and y < h - step:
						holes.append(Vector2i(x, y))
					elif x > w - 1 - ((h - 1 - y) / step) and y >= step:
						holes.append(Vector2i(x, y))
		"pillar":
			var s := maxi(1, mini(w, h) / 6)
			for y in range(int(cy) - s + 1, int(cy) + s + 1):
				for x in range(int(cx) - s + 1, int(cx) + s + 1):
					rocks.append(Vector2i(x, y))
		"rocks":
			var n := 2 + rng.randi() % 3 + (w * h) / 300
			for _k in n:
				var o := Vector2i(rng.randi_range(2, maxi(2, w - 3)), rng.randi_range(2, maxi(2, h - 3)))
				var size := rng.randi_range(1, 3)
				for _j in size:
					if not rocks.has(o):
						rocks.append(o)
					o += [Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2]
	if not holes.is_empty():
		holes = _chunk(holes, w, h, 3 if mini(w, h) >= 12 else 2)
	return {"holes": holes, "rocks": rocks}


## Engorda el contorno en bloques de b x b casillas: cada bloque entero es hueco o es tablero.
## Así los escalones son anchos y planos (las flechas salen siempre de frente contra un lado
## recto, nunca por un rincón), no hay muescas de una casilla y todo hueco toca el borde de la
## cuadrícula (nunca hay agujeros cerrados en medio del tablero). Los bloques se alinean al
## centro, así la forma sigue siendo simétrica.
static func _chunk(holes: Array, w: int, h: int, b: int) -> Array:
	var set := {}
	for c in holes:
		set[c] = true
	var nx := (w + b - 1) / b
	var ny := (h + b - 1) / b
	var ox := (nx * b - w) / 2
	var oy := (ny * b - h) / 2
	var out := []
	for by in ny:
		for bx in nx:
			var cx := clampi(bx * b + b / 2 - ox, 0, w - 1)
			var cy := clampi(by * b + b / 2 - oy, 0, h - 1)
			if not set.has(Vector2i(cx, cy)):
				continue
			for dy in b:
				for dx in b:
					var x := bx * b + dx - ox
					var y := by * b + dy - oy
					if x >= 0 and y >= 0 and x < w and y < h:
						out.append(Vector2i(x, y))
	return _drop_enclosed(out, w, h)


## Quita los huecos que no están conectados con el borde de la cuadrícula (se vuelven tablero).
static func _drop_enclosed(holes: Array, w: int, h: int) -> Array:
	var set := {}
	for c in holes:
		set[c] = true
	var seen := {}
	var stack := []
	for c in holes:
		if c.x == 0 or c.y == 0 or c.x == w - 1 or c.y == h - 1:
			seen[c] = true
			stack.append(c)
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if set.has(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	var out := []
	for c in holes:
		if seen.has(c):
			out.append(c)
	return out


## Proporción del rectángulo que se puede usar (para compensar el tamaño).
static func area_ratio(kind: String) -> float:
	match kind:
		"oval":
			return 0.79
		"diamond":
			return 0.55
		"hourglass", "steps":
			return 0.75
		"cross":
			return 0.8
		"corners", "ring":
			return 0.9
	return 1.0
