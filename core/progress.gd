extends Node
## Progreso guardado en user:// (JSON). Autoload "Progress".

var save_path := "user://cavila_save.json"
var data: Dictionary = {}


func _ready() -> void:
	load_data()


func _default() -> Dictionary:
	return {"version": 2, "level": 1, "stars": {}, "scores": {}, "hints": 3, "daily": {},
		"streak": {"last": "", "count": 0},
		"event": {"week": -1, "count": 0, "claimed": false},
		"leagues": {}, "division": 0,
		"settings": {"lang": "", "sound": true, "vibration": true, "music": true,
			"music_volume": 0.8, "sfx_volume": 0.8, "piece_style": "arrows"}}


func load_data() -> void:
	data = _default()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary and int(parsed.get("version", 0)) == 2:
				var defaults := _default()
				for k in parsed:
					data[k] = parsed[k]
				for k in defaults["settings"]:
					if not data["settings"].has(k):
						data["settings"][k] = defaults["settings"][k]


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
func complete_level(level: int, star_count: int, points: int = 0) -> Dictionary:
	var first: bool = not data["stars"].has(str(level))
	data["stars"][str(level)] = maxi(star_count, stars(level))
	var record := points > best_score(level)
	if record:
		data["scores"][str(level)] = points
	if level >= current_level():
		data["level"] = level + 1
	var bonus := 0
	if first and level % 5 == 0:
		bonus = 1
	if first:
		# Premio extra la primera vez que se supera un nivel súper difícil o extra.
		bonus += {"super": 1, "extra": 2}.get(preload("res://game/levels.gd").tier(level), 0)
	bonus = add_hints(bonus) + _event_progress()
	add_league_points(points)
	save()
	return {"first": first, "hint_bonus": bonus, "record": record and not first}


func best_score(level: int) -> int:
	return int(data["scores"].get(str(level), 0))


func total_score() -> int:
	var n := 0
	for k in data["scores"]:
		n += int(data["scores"][k])
	return n


# --- Evento semanal -----------------------------------------------------------------

const EVENT_GOAL := 20
const EVENT_REWARD := 3


## Semana actual (número de semanas desde 1970, empezando en lunes).
static func week_index(date_key: String = "") -> int:
	var t := Time.get_unix_time_from_datetime_string((date_key if date_key != "" else Time.get_date_string_from_system()) + "T12:00:00")
	var days := int(floor(t / 86400.0))
	return (days + 3) / 7


static func days_left_in_week(date_key: String = "") -> int:
	var t := Time.get_unix_time_from_datetime_string((date_key if date_key != "" else Time.get_date_string_from_system()) + "T12:00:00")
	var days := int(floor(t / 86400.0))
	return 7 - (days + 3) % 7


func event_state() -> Dictionary:
	var ev: Dictionary = data["event"]
	if int(ev["week"]) != week_index():
		return {"week": week_index(), "count": 0, "claimed": false}
	return ev


## Suma un nivel al evento de la semana; al llegar a la meta da pistas (una vez).
func _event_progress() -> int:
	var ev := event_state()
	ev["count"] = int(ev["count"]) + 1
	var reward := 0
	if int(ev["count"]) >= EVENT_GOAL and not ev["claimed"]:
		ev["claimed"] = true
		reward = add_hints(EVENT_REWARD)
	data["event"] = ev
	return reward


# --- Ligas ------------------------------------------------------------------------

const Leagues = preload("res://game/leagues.gd")

## Hora actual (unix) y zona horaria; se pueden fijar en los tests.
var now_override := -1


func now() -> int:
	return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())


func tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


## Liga en curso de un tipo, creada si no existía. La diaria y la flash comparten con la semanal
## la calibración, la división y la zona horaria: sus rivales son los mismos de la semana.
func league(type: String) -> Dictionary:
	var inst := Leagues.instance(type, now(), tz_bias())
	var all: Dictionary = data["leagues"]
	if not all.has(inst.key):
		var calib := 0.0
		var division := 0
		var bias := tz_bias()
		if type == "weekly":
			calib = Leagues.points_per_level(current_level())
			division = int(data["division"])
		else:
			var wk := league("weekly")
			calib = float(wk.calib)
			division = int(wk.division)
			bias = int(wk.get("bias", bias))
		all[inst.key] = {"type": type, "start": inst.start, "end": inst.end, "points": 0,
			"calib": calib, "division": division, "bias": bias, "claimed": false}
	return all[inst.key]


func add_league_points(points: int) -> void:
	if points <= 0:
		return
	for type in Leagues.TYPES:
		var lg := league(type)
		lg["points"] = int(lg["points"]) + points


func league_standings(lg: Dictionary, at: int = -1) -> Array:
	var inst := {"key": "%s:%d" % [lg.type, int(lg.start)], "type": lg.type, "start": int(lg.start), "end": int(lg.end),
		"bias": int(lg.get("bias", tz_bias()))}
	return Leagues.standings(inst, float(lg.calib), int(lg.division), int(lg.points), now() if at < 0 else at, tr("YOU"))


## Aviso en vivo de una liga ("X te ha adelantado", "a N puntos del puesto K"); recuerda
## quién iba por delante para detectar adelantamientos la próxima vez.
func league_notice(lg: Dictionary) -> Dictionary:
	var n := Leagues.notice(league_standings(lg), lg.get("seen", null))
	lg["seen"] = n.ahead
	save()
	return n


## Ligas terminadas en las que has participado y aún no has visto el resultado.
func pending_league_results() -> Array:
	var out := []
	for key in data["leagues"]:
		var lg: Dictionary = data["leagues"][key]
		if int(lg.end) <= now() and not lg.claimed and int(lg.points) > 0:
			var rows := league_standings(lg, int(lg.end))
			var rank := Leagues.rank_of_you(rows)
			out.append({"key": key, "type": lg.type, "rank": rank, "size": rows.size(),
				"prize": Leagues.prize(lg.type, rank)})
	return out


## Cobra el premio de una liga terminada. En la semanal, sube o baja de división.
## Devuelve el cambio de división (-1, 0, +1).
func claim_league(key: String) -> int:
	var lg: Dictionary = data["leagues"][key]
	if lg.claimed:
		return 0
	lg.claimed = true
	var rows := league_standings(lg, int(lg.end))
	var rank := Leagues.rank_of_you(rows)
	add_hints(Leagues.prize(lg.type, rank))
	var change := 0
	if lg.type == "weekly":
		if rank <= Leagues.PROMOTE and int(data["division"]) < Leagues.DIVISIONS.size() - 1:
			change = 1
		elif rank > rows.size() - Leagues.PROMOTE and int(data["division"]) > 0:
			change = -1
		data["division"] = int(data["division"]) + change
	# Limpieza: olvidar ligas de hace más de dos semanas.
	for k in data["leagues"].keys():
		if int(data["leagues"][k].end) < now() - 14 * 86400:
			data["leagues"].erase(k)
	save()
	return change


# --- Pistas -----------------------------------------------------------------------

## Máximo de pistas que se pueden guardar.
const MAX_HINTS := 5


func hints() -> int:
	return mini(int(data["hints"]), MAX_HINTS)


## Suma pistas sin pasar del máximo. Devuelve las que se han añadido de verdad.
func add_hints(n: int) -> int:
	var before := hints()
	data["hints"] = mini(before + maxi(n, 0), MAX_HINTS)
	return int(data["hints"]) - before


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
	var got := add_hints(2)
	save()
	return {"hint_bonus": got}


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
