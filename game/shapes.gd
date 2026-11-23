extends RefCounted
## Formas de tablero. Devuelve las casillas que no se usan:
##   holes: huecos (fuera del tablero; las flechas pasan volando por encima)
##   rocks: obstáculos (bloquean el paso: ninguna flecha puede apuntar hacia ellos)

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
			var rx := maxi(1, w / 6)
			var ry := maxi(1, h / 7)
			for y in h:
				for x in w:
					if absf(x - cx) <= rx and absf(y - cy) <= ry:
						holes.append(Vector2i(x, y))
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
			var s := maxi(1, mini(w, h) / 7)
			for y in range(int(cy) - s + 1, int(cy) + s + 1):
				for x in range(int(cx) - s + 1, int(cx) + s + 1):
					rocks.append(Vector2i(x, y))
		"rocks":
			var n := 2 + rng.randi() % 3
			for _k in n:
				var o := Vector2i(rng.randi_range(2, maxi(2, w - 3)), rng.randi_range(2, maxi(2, h - 3)))
				var size := rng.randi_range(1, 3)
				for _j in size:
					if not rocks.has(o):
						rocks.append(o)
					o += [Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2]
	return {"holes": holes, "rocks": rocks}


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
