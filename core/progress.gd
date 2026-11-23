extends Node
## Progreso guardado en user:// (JSON). Autoload "Progress".

var save_path := "user://cavila_save.json"
var data: Dictionary = {}


func _ready() -> void:
	load_data()


func _default() -> Dictionary:
	return {"version": 2, "level": 1, "stars": {}, "hints": 3, "daily": {},
		"streak": {"last": "", "count": 0},
		"settings": {"lang": "", "sound": true, "vibration": true}}


func load_data() -> void:
	data = _default()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary and int(parsed.get("version", 0)) == 2:
				for k in parsed:
					data[k] = parsed[k]


func reset() -> void:
	data = _default()
	save()


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


# --- Niveles ----------------------------------------------------------------------

## Siguiente nivel por jugar (el más alto desbloqueado).
func current_level() -> int:
	return int(data["level"])


func stars(level: int) -> int:
	return int(data["stars"].get(str(level), 0))


func total_stars() -> int:
	var n := 0
	for k in data["stars"]:
		n += int(data["stars"][k])
	return n


## Registra un nivel superado. Cada 5 niveles nuevos se gana una pista.
## Devuelve {"first": bool, "hint_bonus": int}.
func complete_level(level: int, star_count: int) -> Dictionary:
	var first: bool = not data["stars"].has(str(level))
	data["stars"][str(level)] = maxi(star_count, stars(level))
	if level >= current_level():
		data["level"] = level + 1
	var bonus := 0
	if first and level % 5 == 0:
		bonus = 1
		data["hints"] = hints() + 1
	save()
	return {"first": first, "hint_bonus": bonus}


# --- Pistas -----------------------------------------------------------------------

func hints() -> int:
	return int(data["hints"])


func use_hint() -> bool:
	if hints() <= 0:
		return false
	data["hints"] = hints() - 1
	save()
	return true


# --- Reto diario y racha ------------------------------------------------------------

func daily_done(date_key: String) -> bool:
	return data["daily"].has(date_key)


## Marca el reto del día. Mantiene la racha de días seguidos y da 2 pistas.
func complete_daily(date_key: String) -> Dictionary:
	if daily_done(date_key):
		return {"hint_bonus": 0}
	data["daily"][date_key] = true
	var last: String = data["streak"]["last"]
	if last != "" and days_between(last, date_key) == 1:
		data["streak"]["count"] = int(data["streak"]["count"]) + 1
	elif last != date_key:
		data["streak"]["count"] = 1
	data["streak"]["last"] = date_key
	data["hints"] = hints() + 2
	save()
	return {"hint_bonus": 2}


## Racha vigente a fecha `today` (se pierde si ayer no se jugó).
func streak(today: String) -> int:
	var last: String = data["streak"]["last"]
	if last == "":
		return 0
	var gap := days_between(last, today)
	return int(data["streak"]["count"]) if gap <= 1 else 0


static func days_between(a: String, b: String) -> int:
	var ta := Time.get_unix_time_from_datetime_string(a + "T12:00:00")
	var tb := Time.get_unix_time_from_datetime_string(b + "T12:00:00")
	return int(round((tb - ta) / 86400.0))


# --- Ajustes ----------------------------------------------------------------------

func setting(key: String):
	return data["settings"].get(key)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save()
