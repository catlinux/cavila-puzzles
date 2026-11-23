extends RefCounted
## Curva de dificultad de los niveles (ilimitados) y mundos.
##
## La dificultad crece de forma logarítmica: muy rápida al principio (aprender) y cada vez
## más suave, hasta estabilizarse hacia el nivel 2000; más allá, cada nivel sigue siendo
## distinto por su semilla. Dentro de cada bloque de 10 hay ritmo: respiros y un nivel reto.

const Rng = preload("res://core/rng.gd")

const LEVELS_PER_WORLD := 30

## Mundos: nombre (clave de traducción) y paleta [color A, color B, fondo arriba, fondo abajo].
const WORLDS := [
	{"key": "WORLD_ALBA", "a": Color8(94, 234, 212), "b": Color8(125, 211, 252), "top": Color8(16, 34, 48), "bottom": Color8(7, 12, 22)},
	{"key": "WORLD_MAREA", "a": Color8(96, 165, 250), "b": Color8(129, 140, 248), "top": Color8(18, 26, 56), "bottom": Color8(7, 10, 26)},
	{"key": "WORLD_AMBAR", "a": Color8(251, 191, 36), "b": Color8(251, 113, 133), "top": Color8(44, 26, 34), "bottom": Color8(15, 10, 18)},
	{"key": "WORLD_BRUMA", "a": Color8(196, 181, 253), "b": Color8(244, 114, 182), "top": Color8(36, 24, 56), "bottom": Color8(12, 9, 24)},
	{"key": "WORLD_BOSQUE", "a": Color8(134, 239, 172), "b": Color8(190, 242, 100), "top": Color8(14, 38, 32), "bottom": Color8(6, 14, 12)},
	{"key": "WORLD_ASCUA", "a": Color8(253, 164, 175), "b": Color8(253, 186, 116), "top": Color8(48, 20, 26), "bottom": Color8(16, 8, 12)},
	{"key": "WORLD_GLACIAR", "a": Color8(224, 242, 254), "b": Color8(103, 232, 249), "top": Color8(22, 38, 54), "bottom": Color8(8, 14, 24)},
	{"key": "WORLD_NEBULA", "a": Color8(232, 121, 249), "b": Color8(129, 140, 248), "top": Color8(34, 16, 50), "bottom": Color8(10, 6, 20)},
]


static func world_index(level: int) -> int:
	return (maxi(level, 1) - 1) / LEVELS_PER_WORLD


static func world(level: int) -> Dictionary:
	return WORLDS[world_index(level) % WORLDS.size()]


## 0 = respiro, 1 = normal, 2 = reto (último de cada 10).
static func beat(level: int) -> int:
	var m := maxi(level, 1) % 10
	if m == 0:
		return 2
	return 0 if m == 1 or m == 6 else 1


static func difficulty(level: int) -> float:
	var n := maxi(level, 1)
	var t := clampf(pow(log(float(n)) / log(2000.0), 1.25), 0.0, 1.0)
	match beat(n):
		0:
			t -= 0.07
		2:
			t += 0.08
	return clampf(t, 0.0, 1.0)


static func params_for(level: int) -> Dictionary:
	return params_from(difficulty(level))


static func params_from(t: float) -> Dictionary:
	var w := int(round(lerpf(4.0, 16.0, t)))
	var h := mini(int(round(w * 1.5)), 24)
	return {
		"w": w, "h": h,
		"min_len": 2,
		"max_len": int(round(lerpf(3.0, 9.0, t))),
		"turn": lerpf(0.2, 0.5, t),
		"coverage": lerpf(0.62, 0.92, t),
		"long_bias": lerpf(0.3, 0.85, t),
		"chain_bias": lerpf(0.2, 0.75, t),
		"target_depth": int(round(lerpf(2.0, 22.0, t))),
		"candidates": 4,
	}


static func seed_for(level: int) -> int:
	return Rng.hash_string("nivel:%d" % level)


## 3 estrellas sin choques, 2 con un choque, 1 con dos.
static func stars_for(lives_left: int) -> int:
	return clampi(lives_left, 1, 3)
