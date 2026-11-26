extends RefCounted
## Ligas: relámpago (3 h), diaria y semanal. Mientras no haya servidor, los demás
## participantes son SIMULADOS: cada liga genera de forma determinista (por su clave) sus
## jugadores, con un ritmo y unas sesiones de juego propias. Su puntuación en cada momento
## depende solo de la hora, así que la clasificación evoluciona de forma creíble y coherente
## aunque se cierre el juego. El ritmo se calibra con el nivel del jugador al entrar.
##
## Para que parezca gente real: más actividad por la tarde y la noche, habilidad con cola
## larga (pocos muy buenos, muchos casuales), puntos a saltos al terminar cada nivel, un grupo
## de rivales "habituales" que reaparecen entre ligas con su propio nivel, y rivales más fuertes
## en las divisiones altas. La interfaz avisa de que son simulados; al pasar a rivales reales
## (servidor), quitar ese aviso.

const Rng = preload("res://core/rng.gd")
const Levels = preload("res://game/levels.gd")
const Countries = preload("res://game/countries.gd")

const TYPES := ["flash", "daily", "weekly"]
const CONFIG := {
	"flash": {"hours": 3, "size": 15, "prizes": [3, 2, 1]},
	"daily": {"hours": 24, "size": 20, "prizes": [4, 2, 1]},
	"weekly": {"hours": 168, "size": 30, "prizes": [8, 5, 3]},
}
const DIVISIONS := ["DIV_BRONZE", "DIV_SILVER", "DIV_GOLD", "DIV_PLATINUM", "DIV_DIAMOND"]
const PROMOTE := 5  # en la semanal suben los 5 primeros y bajan los 5 últimos

## Avatares (assets/avatars/av_NN.png). Tipo: n = animal/robot, f = persona de aspecto femenino,
## m = persona de aspecto masculino. Dos avatares con el mismo "kin" son casi gemelos (misma
## plantilla): nunca coinciden en una misma liga.
const AVATAR_KIND := "nnnnnnnnnnnnnnnnnnnnnfffffffmmmmmmmm"
const AVATAR_KIN := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 22, 25, 23, 26, 27, 28, 29, 30, 31, 32, 33]
const AVATAR_COUNT := 36

## Liga en curso de un tipo: {key, type, start, end} (tiempos unix). `bias_min` = zona horaria.
static func instance(type: String, now: int, bias_min: int = 0) -> Dictionary:
	var local := now + bias_min * 60
	var start := 0
	var length := int(CONFIG[type].hours) * 3600
	match type:
		"flash":
			start = (local / 10800) * 10800 - bias_min * 60
		"daily":
			start = (local / 86400) * 86400 - bias_min * 60
		"weekly":
			var day := local / 86400
			start = (day - (day + 3) % 7) * 86400 - bias_min * 60  # lunes
	return {"key": "%s:%d" % [type, start], "type": type, "start": start, "end": start + length, "bias": bias_min}


## Puntos que se esperan de un nivel típico para un jugador en el nivel `level`.
static func points_per_level(level: int) -> float:
	var t := Levels.difficulty(maxi(level, 1))
	var arrows := int(lerpf(12.0, 140.0, t))
	var rival := Levels.rival_time(arrows, int(lerpf(4.0, 55.0, t)), 0)
	return float(Levels.score(arrows, t, rival * 0.85, 2, 40, rival))


## Segundos que tarda en superar un nivel típico un jugador de nivel `level` (el tiempo del rival).
static func pace_per_level(level: int) -> float:
	var t := Levels.difficulty(maxi(level, 1))
	var arrows := int(lerpf(12.0, 140.0, t))
	return Levels.rival_time(arrows, int(lerpf(4.0, 55.0, t)), 0)


## Actividad relativa por hora local (0-23): poca de madrugada, mucha por la tarde y la noche.
const ACTIVITY := [0.35, 0.22, 0.15, 0.12, 0.12, 0.15, 0.25, 0.45, 0.55, 0.60, 0.60, 0.70,
	0.85, 0.90, 0.75, 0.70, 0.80, 0.95, 1.00, 1.00, 1.00, 0.95, 0.80, 0.55]
const REGULARS := 14   # rivales habituales que reaparecen entre ligas


## Rivales habituales: siempre los mismos (avatar + nombre + habilidad propia).
static func regulars() -> Array:
	var ids := _pick_identities("habituales", REGULARS, [], {})
	for r in ids:
		r["skill"] = _skill(Rng.make(Rng.hash_string("hab:" + r.name)))
	return ids


## Habilidad con cola larga: la mayoría casuales (~0,6-1,0) y muy pocos muy buenos (hasta ~2,4).
static func _skill(rng: RefCounted) -> float:
	return 0.55 + 1.9 * pow(rng.randf(), 3.0)


## Elige `count` identidades distintas evitando avatares/familias/nombres ya usados.
static func _pick_identities(key: String, count: int, taken_avatars: Array, taken_names: Dictionary) -> Array:
	var rng := Rng.make(Rng.hash_string("liga-id:" + key))
	var order: Array = Rng.shuffle(range(AVATAR_COUNT), rng)
	var used_kin := {}
	for a in taken_avatars:
		used_kin[AVATAR_KIN[a]] = true
	var picks := []
	for a in order:
		if picks.size() >= count:
			break
		if used_kin.has(AVATAR_KIN[a]) or taken_avatars.has(a):
			continue
		used_kin[AVATAR_KIN[a]] = true
		picks.append(a)
	for a in order:  # solo si faltaran avatares con kin distinto
		if picks.size() >= count:
			break
		if not picks.has(a) and not taken_avatars.has(a):
			picks.append(a)
	var nicks: Array = Rng.shuffle(Countries.NICKS.duplicate(), rng)
	var out := []
	for a in picks:
		var kind: String = AVATAR_KIND[a]
		var country := Countries.pick(rng)
		var gender := kind
		if kind == "n":
			# Avatar de animal: casi siempre un apodo; a veces la persona usa su nombre de pila.
			gender = "n" if rng.randf() >= 0.45 else ("f" if rng.randf() < 0.5 else "m")
		var nm := ""
		if gender == "n":
			while not nicks.is_empty() and nm == "":
				var cand: String = nicks.pop_back()
				if not taken_names.has(cand):
					nm = cand
			if nm == "":
				gender = "f" if rng.randf() < 0.5 else "m"
		if nm == "":
			nm = Countries.make_name(rng, country, gender, taken_names)
		taken_names[nm] = true
		out.append({"avatar": a, "name": nm, "country": country, "gender": gender})
	return out


## Identidades de los participantes simulados de una liga. Deterministas por la clave de la
## liga: una parte son rivales habituales (los mismos de otras ligas) y el resto, nuevos; todos
## con avatares, familias y nombres distintos y coherentes entre sí.
static func identities(key: String, count: int) -> Array:
	var rng := Rng.make(Rng.hash_string("liga-reg:" + key))
	var pool: Array = Rng.shuffle(regulars(), rng)
	var out := []
	var used_av := []
	var used_nm := {}
	var used_kin := {}
	var want := mini(maxi(count / 3, 1), pool.size())
	for r in pool:
		if out.size() >= want:
			break
		if used_kin.has(AVATAR_KIN[r.avatar]):
			continue
		used_kin[AVATAR_KIN[r.avatar]] = true
		used_av.append(r.avatar)
		used_nm[r.name] = true
		out.append(r.duplicate())
	if out.size() < count:
		out.append_array(_pick_identities(key, count - out.size(), used_av, used_nm))
	return Rng.shuffle(out, rng)


## La semana (liga semanal) a la que pertenece una liga. Flash y diaria caben dentro de una semana.
static func week_of(inst: Dictionary) -> Dictionary:
	if inst.type == "weekly":
		return inst
	return instance("weekly", int(inst.start), int(inst.get("bias", 0)))


## Los 29 rivales simulados de una semana. Cada uno es UNA persona con una única agenda de
## partidas para toda la semana: sus puntos en cualquier liga (flash, diaria, semanal) son lo que
## ha ganado dentro de la ventana de esa liga. Por eso nunca tiene más puntos en la diaria que en
## la semanal, ni puntos en una y cero en la otra. Las sesiones son [inicio, duración] en segundos
## desde el inicio de la semana.
static func week_bots(week: Dictionary, calib: float, division: int = 0, pace: float = 60.0) -> Array:
	var n: int = int(CONFIG.weekly.size) - 1
	var rng := Rng.make(Rng.hash_string("liga:" + week.key))
	var ids := identities(week.key, n)
	var out := []
	var dur := float(week.end - week.start)
	for k in n:
		var skill: float = float(ids[k].skill) if ids[k].has("skill") else _skill(rng)
		skill *= 1.0 + 0.18 * division  # en divisiones altas se juega más fuerte
		# Ritmo real: lo que tarda un buen jugador en un nivel de este nivel de dificultad, dividido
		# por su habilidad, más unos segundos entre niveles. Los hábiles puntúan algo más por nivel
		# (rapidez y menos errores), pero ganan sobre todo jugando más niveles.
		var secs_per_level := pace / maxf(skill, 0.4) + 12.0
		var lvl_per_hour := 3600.0 / secs_per_level
		var per_level := calib * (0.8 + 0.2 * skill) * rng.randf_range(0.9, 1.1)
		var sessions := []
		var country: String = ids[k].country
		var offset_h: int = Countries.offset(rng, country)  # juega en SUS horas normales
		if rng.randf() > 0.06:  # unos pocos se apuntan y no juegan en toda la semana
			var count := 24 + rng.randi() % 22
			for _s in count:
				var len_s := rng.randf_range(5.0, 15.0) * 60.0
				sessions.append([_session_start(rng, week, dur, len_s, offset_h), len_s])
		out.append({"name": ids[k].name, "avatar": ids[k].avatar, "country": country, "per_level": per_level,
			"lph": lvl_per_hour / 3600.0, "rate": per_level * lvl_per_hour / 3600.0, "sessions": sessions,
			"week_start": int(week.start)})
	return out


## Participantes simulados de una liga (sin contar al jugador). La semanal son los 29 de la semana;
## la diaria y la flash son subgrupos de esos mismos, con preferencia por los que juegan en su
## ventana (así hay actividad) y, si faltan, se completan con otros.
static func bots(inst: Dictionary, calib: float, division: int = 0, pace: float = 60.0) -> Array:
	var week := week_of(inst)
	var all := week_bots(week, calib, division, pace)
	if inst.type == "weekly":
		return all
	var want: int = int(CONFIG[inst.type].size) - 1
	var rng := Rng.make(Rng.hash_string("liga-sub:" + inst.key))
	var t0 := float(inst.start - week.start)
	var t1 := float(inst.end - week.start)
	var active := []
	var idle := []
	for b in all:
		var plays := false
		for s in b.sessions:
			if s[0] < t1 and s[0] + s[1] > t0:
				plays = true
		(active if plays else idle).append(b)
	var out: Array = Rng.shuffle(active, rng)
	out.append_array(Rng.shuffle(idle, rng))
	return out.slice(0, want)


## Inicio de una sesión de juego: más probable a las horas de más actividad EN LA HORA LOCAL DEL
## RIVAL (`offset_h` = su huso respecto a UTC; `inst.start` es hora UTC).
static func _session_start(rng: RefCounted, inst: Dictionary, dur: float, len_s: float, offset_h: int = 0) -> float:
	var at := 0.0
	for _try in 12:
		at = rng.randf_range(0.0, maxf(dur - len_s, 1.0))
		var hour := posmod(int(floorf((float(inst.start) + at) / 3600.0)) + offset_h, 24)
		if rng.randf() < ACTIVITY[hour]:
			break
	return at


## Puntos acumulados desde el inicio de la semana hasta `t` (segundos desde ese inicio): suben a
## saltos, al completar cada nivel, y nunca bajan.
static func _cum(bot: Dictionary, t: float) -> int:
	var total := 0
	for s in bot.sessions:
		var levels := int(floorf(clampf(t - s[0], 0.0, s[1]) * bot.lph))
		total += int(levels * bot.per_level)
	return total


## Puntos de un participante simulado en la liga `inst` en el instante `now`: lo ganado dentro
## de la ventana de esa liga. Si el jugador reinició las ligas (`inst.floor`), solo cuenta lo
## ganado desde ese momento: todos vuelven a empezar de cero.
static func bot_points(bot: Dictionary, inst: Dictionary, now: int) -> int:
	var t1 := float(mini(now, int(inst.end)) - int(bot.week_start))
	var t0 := float(maxi(int(inst.start), int(inst.get("floor", 0))) - int(bot.week_start))
	if t1 <= t0:
		return 0
	return _cum(bot, t1) - (_cum(bot, t0) if t0 > 0.0 else 0)


## Clasificación: [{name, points, avatar (-1 = tú), you}] ordenada de mayor a menor.
static func standings(inst: Dictionary, calib: float, division: int, your_points: int, now: int, your_name := "", pace: float = 60.0) -> Array:
	var rows := []
	for b in bots(inst, calib, division, pace):
		rows.append({"name": b.name, "points": bot_points(b, inst, mini(now, inst.end)), "avatar": b.avatar, "you": false, "country": b.country})
	rows.append({"name": your_name, "points": your_points, "avatar": -1, "you": true, "country": ""})
	rows.sort_custom(func(a, b): return a.points > b.points or (a.points == b.points and a.you))
	return rows


static func rank_of_you(rows: Array) -> int:
	for k in rows.size():
		if rows[k].you:
			return k + 1
	return rows.size()


static func prize(type: String, rank: int) -> int:
	var p: Array = CONFIG[type].prizes
	return p[rank - 1] if rank >= 1 and rank <= p.size() else 0


## Aviso en vivo para el jugador. `seen` = nombres que iban por delante la última vez que miró
## (null si es la primera vez). Devuelve {key, args, ahead}: "X te ha adelantado" si alguien
## nuevo le supera; si no, los puntos que le faltan para el puesto anterior, o su ventaja si va primero.
static func notice(rows: Array, seen: Variant) -> Dictionary:
	var rank := rank_of_you(rows)
	var ahead := []
	for k in rank - 1:
		ahead.append(rows[k].name)
	var out := {"key": "", "args": [], "ahead": ahead}
	if seen != null:
		for k in range(rank - 2, -1, -1):  # el más cercano primero
			if not seen.has(rows[k].name):
				out.key = "LG_PASSED"
				out.args = [rows[k].name]
				return out
	if rank > 1:
		out.key = "LG_GAP"
		out.args = [maxi(int(rows[rank - 2].points) - int(rows[rank - 1].points), 1), rank - 1]
	elif rows.size() > 1:
		out.key = "LG_LEAD"
		out.args = [int(rows[0].points) - int(rows[1].points)]
	return out
