extends RefCounted
## Puzle diario: tipo, dificultad y semilla dependen solo de la fecha.

const Rng = preload("res://core/rng.gd")
const Registry = preload("res://core/registry.gd")


static func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func puzzle_for(date_key: String) -> String:
	var ids := Registry.ids()
	return ids[Rng.hash_string("daily-type:" + date_key) % ids.size()]


static func difficulty_for(date_key: String) -> int:
	return 1 + Rng.hash_string("daily-diff:" + date_key) % 2  # medio o difícil


static func seed_for(date_key: String, puzzle_id: String) -> int:
	return Rng.hash_string("daily:%s:%s" % [date_key, puzzle_id])
