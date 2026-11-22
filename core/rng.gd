extends RefCounted
## Semillas deterministas. Mismo texto/semilla => mismos niveles en cualquier dispositivo.

## Hash FNV-1a de 32 bits, estable entre ejecuciones y plataformas.
static func hash_string(s: String) -> int:
	var h := 2166136261
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h


## Semilla del nivel `index` de un puzle y dificultad. Infinitos niveles.
static func level_seed(puzzle_id: String, difficulty: int, index: int) -> int:
	return hash_string("%s:%d:%d" % [puzzle_id, difficulty, index])


## Semilla derivada para el intento n-ésimo de un generador.
static func derive(seed_value: int, attempt: int) -> int:
	return hash_string("%d/%d" % [seed_value, attempt])


static func make(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## Fisher-Yates con generador propio (Array.shuffle usa el global y no es reproducible).
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
	return arr
