extends RefCounted
## Curva de dificultad de los niveles (ilimitados) y mundos.
##
## La dificultad crece de forma logarítmica: muy rápida al principio (aprender) y cada vez
## más suave, hasta estabilizarse hacia el nivel 3000; más allá, cada nivel sigue siendo
## distinto por su semilla. Dentro de cada bloque de 10 hay ritmo: respiros y un nivel reto.

const Rng = preload("res://core/rng.gd")
const Shapes = preload("res://game/shapes.gd")

const LEVELS_PER_WORLD := 30

## Mundos: nombre (clave de traducción) y acento en degradado [a -> b].
const WORLDS := [
	{"key": "WORLD_ALBA", "a": Color8(255, 106, 85), "b": Color8(255, 154, 61)},
	{"key": "WORLD_MAREA", "a": Color8(59, 130, 246), "b": Color8(34, 184, 207)},
	{"key": "WORLD_AMBAR", "a": Color8(245, 158, 11), "b": Color8(249, 115, 22)},
	{"key": "WORLD_BRUMA", "a": Color8(139, 92, 246), "b": Color8(217, 70, 239)},
	{"key": "WORLD_BOSQUE", "a": Color8(16, 185, 129), "b": Color8(101, 192, 40)},
	{"key": "WORLD_ASCUA", "a": Color8(239, 68, 68), "b": Color8(249, 115, 22)},
	{"key": "WORLD_GLACIAR", "a": Color8(6, 182, 212), "b": Color8(59, 130, 246)},
	{"key": "WORLD_NEBULA", "a": Color8(168, 85, 247), "b": Color8(99, 102, 241)},
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
	var t := clampf(pow(log(float(n)) / log(3000.0), 1.3), 0.0, 1.0)
	match beat(n):
		0:
			t -= 0.07
		2:
			t += 0.08
	return clampf(t, 0.0, 1.0)


static func params_for(level: int) -> Dictionary:
	return params_from(difficulty(level), seed_for(level), unlocked_shapes(level), level)


## Formas disponibles según el nivel: se va desbloqueando una nueva cada pocos niveles.
static func unlocked_shapes(level: int) -> int:
	if level < 12:
		return 1
	return mini(Shapes.KINDS.size(), 2 + (level - 12) / 8)


## Parámetros del generador para una dificultad t (0..1). La semilla da a cada nivel su
## propia forma, proporciones y "estilo" (más serpientes largas o más flechas pequeñas).
static func params_from(t: float, seed_value: int = 0, shapes: int = 1, level: int = 0) -> Dictionary:
	var rng := Rng.make(Rng.derive(seed_value, 991))
	var kind := "rect"
	if shapes > 1:
		# Los niveles reto estrenan la última forma desbloqueada; el resto, al azar.
		kind = Shapes.KINDS[1 + rng.randi() % (shapes - 1)] if beat(level) == 2 else Shapes.KINDS[rng.randi() % shapes]
	var base_w := lerpf(5.0, 22.0, t) / sqrt(Shapes.area_ratio(kind))
	var w := clampi(int(round(base_w + rng.randf_range(-1.5, 1.5))), 5, 24)
	var h := clampi(int(round(w * rng.randf_range(1.25, 1.6))), 6, 36)
	var shape := Shapes.make(kind, w, h, rng)
	# Estilo: 0 = flechas pequeñas, 1 = mixto, 2 = serpientes.
	var style := rng.randi() % 3
	var snake_share: float = lerpf(0.0, 0.4, smoothstep(0.1, 0.6, t)) * [0.5, 1.0, 1.5][style]
	var playable: int = w * h - shape.holes.size() - shape.rocks.size()
	var snake_min := int(round(lerpf(7.0, 14.0, t)))
	var snake_max := int(round(lerpf(11.0, 46.0, t)))
	var snakes := int(round(playable * snake_share / ((snake_min + snake_max) / 2.0)))
	return {
		"w": w, "h": h,
		"shape": kind, "holes": shape.holes, "rocks": shape.rocks,
		# Sin flechas de 2 casillas cuando el tablero ya es grande: se ven diminutas.
		"min_len": 2 if t < 0.3 else 3,
		"max_len": int(round(lerpf(4.0, 18.0, t))),
		"long_ratio": lerpf(0.05, 0.3, t),
		"turn": lerpf(0.25, 0.5, t),
		"curl_mid": [0.0, 0.3, 0.6][style] * smoothstep(0.1, 0.5, t),
		"coverage": lerpf(0.75, 0.97, t),
		"snakes": snakes,
		"snake_min": snake_min,
		"snake_max": snake_max,
		"snake_turn": 0.45,
		"curl": 0.75,
		# Al principio pocas dependencias (muchas flechas salen a la primera); después,
		# flechas que apuntan a otras y casi ninguna libre al empezar.
		"long_bias": lerpf(0.0, 0.9, smoothstep(0.0, 0.6, t)),
		"chain_bias": lerpf(0.0, 0.85, smoothstep(0.0, 0.6, t)),
		"target_free": lerpf(0.5, 0.07, smoothstep(0.0, 0.7, t)),
		"target_depth": int(round(lerpf(3.0, 60.0, t))),
		# Relleno de huecos y alargado de colas: apenas en los primeros niveles.
		"fill_pass": lerpf(0.0, 4.0, smoothstep(0.05, 0.4, t)),
		"extend_rounds": int(round(lerpf(0.0, 4.0, smoothstep(0.05, 0.4, t)))),
		"candidates": 3,
	}


static func seed_for(level: int) -> int:
	return Rng.hash_string("nivel:%d" % level)


## 3 estrellas sin choques, 2 con un choque, 1 con dos.
static func stars_for(lives_left: int) -> int:
	return clampi(lives_left, 1, 3)


# --- Puntuación y rival -------------------------------------------------------------

## Tiempo (s) en que la máquina despeja el tablero: depende de las flechas y de la cadena
## de dependencias, con un poco de variación por nivel.
static func rival_time(arrows: int, depth: int, seed_value: int) -> float:
	var rng := Rng.make(Rng.derive(seed_value, 7))
	return (arrows * 1.3 + depth * 0.9 + 6.0) * rng.randf_range(0.9, 1.15)


## Puntos: flechas y vidas (multiplicados por la dificultad), combos y rapidez frente al rival.
static func score(arrows: int, t: float, elapsed: float, lives: int, combo_points: int, rival: float) -> int:
	var mult := 1.0 + 2.0 * t
	var base := arrows * 10 + lives * 100 + combo_points
	var time_bonus := maxf(0.0, rival - elapsed) * 4.0
	return int(round(base * mult + time_bonus))
