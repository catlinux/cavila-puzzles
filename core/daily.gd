extends RefCounted
## Reto diario: el tablero depende solo de la fecha (igual para todo el mundo).

const Rng = preload("res://core/rng.gd")
const Levels = preload("res://game/levels.gd")


static func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func seed_for(date_key: String) -> int:
	return Rng.hash_string("diario:" + date_key)


## Dificultad media-alta que varía cada día.
static func params_for(date_key: String) -> Dictionary:
	var t := 0.45 + 0.3 * float(Rng.hash_string("diario-dif:" + date_key) % 100) / 100.0
	return Levels.params_from(t)


static func world_for(date_key: String) -> Dictionary:
	return Levels.WORLDS[Rng.hash_string("diario-mundo:" + date_key) % Levels.WORLDS.size()]
