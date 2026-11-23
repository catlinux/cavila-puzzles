extends RefCounted
## Ligas: relámpago (3 h), diaria y semanal. Mientras no haya servidor, los demás
## participantes son SIMULADOS: cada liga genera de forma determinista (por su clave) sus
## jugadores, con un ritmo y unas sesiones de juego propias. Su puntuación en cada momento
## depende solo de la hora, así que la clasificación evoluciona de forma creíble y coherente
## aunque se cierre el juego. El ritmo se calibra con el nivel del jugador al entrar.
##
## IMPORTANTE: antes de publicar, sustituir por jugadores reales (servidor) o indicar en la
## interfaz que los rivales son simulados.

const Rng = preload("res://core/rng.gd")
const Levels = preload("res://game/levels.gd")

const TYPES := ["flash", "daily", "weekly"]
const CONFIG := {
	"flash": {"hours": 3, "size": 15, "prizes": [3, 2, 1]},
	"daily": {"hours": 24, "size": 20, "prizes": [4, 2, 1]},
	"weekly": {"hours": 168, "size": 30, "prizes": [8, 5, 3]},
}
const DIVISIONS := ["DIV_BRONZE", "DIV_SILVER", "DIV_GOLD", "DIV_PLATINUM", "DIV_DIAMOND"]
const PROMOTE := 5  # en la semanal suben los 5 primeros y bajan los 5 últimos

const NAMES := ["Lucía M.", "marc_puig", "Aitana", "JaviG", "NoraLuna", "pau13", "Carmen R.", "Iker",
	"sofia88", "Jordi B.", "Valen", "Mireia", "Hugo_V", "martina.v", "LeoZ", "Ainhoa", "Oriol",
	"Daniela", "Álex P.", "Nil", "emma_c", "Bruno", "Laia", "Mateo", "Clàudia", "raul92", "Irene",
	"Gael", "Noa", "Pol R.", "sara_lm", "Adrián", "Júlia", "Biel", "Lola", "Arnau", "Paula G.",
	"Unai", "Vega", "Hèctor", "Elena", "quim_s", "Marina", "Thiago", "Abril", "Rubén", "Nerea",
	"Ferran", "Olivia", "dani_k", "Candela", "Marcos", "Jana", "Izan", "Berta", "Cristina", "Tomás",
	"Ona", "Eric", "Lucas", "Carla", "Miguel A.", "Mar", "Enzo", "Alba S.", "Joel", "Rocío",
	"Sergi", "Inés", "Teo", "Aina", "Gonzalo", "Lía", "Xavi", "Celia"]
const AVATAR_COLORS := [Color8(255, 106, 85), Color8(59, 130, 246), Color8(16, 185, 129), Color8(245, 158, 11),
	Color8(139, 92, 246), Color8(236, 72, 153), Color8(6, 182, 212), Color8(132, 204, 22)]


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
	return {"key": "%s:%d" % [type, start], "type": type, "start": start, "end": start + length}


## Puntos que se esperan de un nivel típico para un jugador en el nivel `level`.
static func points_per_level(level: int) -> float:
	var t := Levels.difficulty(maxi(level, 1))
	var arrows := int(lerpf(12.0, 140.0, t))
	var rival := Levels.rival_time(arrows, int(lerpf(4.0, 55.0, t)), 0)
	return float(Levels.score(arrows, t, rival * 0.85, 2, 40, rival))


## Participantes simulados de una liga (sin contar al jugador).
static func bots(inst: Dictionary, calib: float, division: int = 0) -> Array:
	var cfg: Dictionary = CONFIG[inst.type]
	var rng := Rng.make(Rng.hash_string("liga:" + inst.key))
	var names: Array = Rng.shuffle(NAMES.duplicate(), rng)
	var out := []
	var dur := float(inst.end - inst.start)
	for k in int(cfg.size) - 1:
		var lvl_per_hour := rng.randf_range(5.0, 13.0)
		var skill := rng.randf_range(0.75, 1.25) * (1.0 + 0.12 * division)
		var sessions := []
		if rng.randf() > 0.08:  # unos pocos se apuntan y no juegan
			var n := 1 + rng.randi() % (2 if inst.type == "flash" else (3 if inst.type == "daily" else 10))
			for _s in n:
				var len_s := rng.randf_range(6.0, 35.0) * 60.0
				var at := rng.randf_range(0.0, maxf(dur - len_s, 1.0))
				sessions.append([at, len_s])
		out.append({"name": names[k % names.size()], "color": AVATAR_COLORS[k % AVATAR_COLORS.size()],
			"rate": calib * lvl_per_hour * skill / 3600.0, "sessions": sessions})
	return out


## Puntos de un participante simulado en el instante `now` (crece con el tiempo).
static func bot_points(bot: Dictionary, inst: Dictionary, now: int) -> int:
	var t := float(now - inst.start)
	var total := 0.0
	for s in bot.sessions:
		total += clampf(t - s[0], 0.0, s[1]) * bot.rate
	return int(total)


## Clasificación: [{name, points, color, you}] ordenada de mayor a menor.
static func standings(inst: Dictionary, calib: float, division: int, your_points: int, now: int, your_name := "") -> Array:
	var rows := []
	for b in bots(inst, calib, division):
		rows.append({"name": b.name, "points": bot_points(b, inst, mini(now, inst.end)), "color": b.color, "you": false})
	rows.append({"name": your_name, "points": your_points, "color": Color8(29, 40, 66), "you": true})
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
