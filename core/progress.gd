extends Node
## Progreso guardado en user:// (JSON). Autoload "Progress".

var save_path := "user://cavila_progress.json"
var data: Dictionary = {}


func _ready() -> void:
	load_data()


func _default() -> Dictionary:
	return {"version": 1, "levels": {}, "daily": {}, "language": ""}


func load_data() -> void:
	data = _default()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				data.merge(parsed, true)


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func _key(puzzle_id: String, difficulty: int) -> String:
	return "%s:%d" % [puzzle_id, difficulty]


func mark_done(puzzle_id: String, difficulty: int, index: int, time_s: float, lives_left: int, stars: int = 0) -> void:
	var levels: Dictionary = data["levels"]
	var k := _key(puzzle_id, difficulty)
	if not levels.has(k):
		levels[k] = {}
	var prev = levels[k].get(str(index), null)
	var best := time_s
	if prev is Dictionary and prev.get("t", INF) < time_s:
		best = prev["t"]
	var best_stars := maxi(stars, int(prev.get("s", 0)) if prev is Dictionary else 0)
	levels[k][str(index)] = {"t": snappedf(best, 0.1), "l": lives_left, "s": best_stars}
	save()


func is_done(puzzle_id: String, difficulty: int, index: int) -> bool:
	var lv = data["levels"].get(_key(puzzle_id, difficulty), {})
	return lv.has(str(index))


func get_stars(puzzle_id: String, difficulty: int, index: int) -> int:
	var e = data["levels"].get(_key(puzzle_id, difficulty), {}).get(str(index), null)
	return int(e.get("s", 0)) if e is Dictionary else 0


func total_done(puzzle_id: String) -> int:
	var n := 0
	for d in 3:
		n += done_count(puzzle_id, d)
	return n


func done_count(puzzle_id: String, difficulty: int) -> int:
	return data["levels"].get(_key(puzzle_id, difficulty), {}).size()


## Índice más alto jugable: el siguiente al mayor nivel completado.
func highest_unlocked(puzzle_id: String, difficulty: int) -> int:
	var best := -1
	for k in data["levels"].get(_key(puzzle_id, difficulty), {}):
		best = maxi(best, int(k))
	return best + 1


func mark_daily(date_key: String, puzzle_id: String) -> void:
	data["daily"][date_key] = puzzle_id
	save()


func daily_done(date_key: String) -> bool:
	return data["daily"].has(date_key)


func get_language() -> String:
	return data.get("language", "")


func set_language(lang: String) -> void:
	data["language"] = lang
	save()
