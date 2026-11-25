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

## Avatares (assets/avatars/av_NN.png). Tipo: n = animal/robot, f = persona de aspecto femenino,
## m = persona de aspecto masculino. Dos avatares con el mismo "kin" son casi gemelos (misma
## plantilla): nunca coinciden en una misma liga.
const AVATAR_KIND := "nnnnnnnnnnnnnnnnnnnnnfffffffmmmmmmmm"
const AVATAR_KIN := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 22, 25, 23, 26, 27, 28, 29, 30, 31, 32, 33]
const AVATAR_COUNT := 36

const NAMES_F := ["Lucía M.", "Aitana", "Carmen R.", "sofia88", "Mireia", "martina.v", "Ainhoa", "Daniela",
	"emma_c", "Laia", "Clàudia", "Irene", "Júlia", "sara_lm", "Lola", "Paula G.", "Vega", "Elena", "Marina",
	"Abril", "Nerea", "Olivia", "Candela", "Jana", "Berta", "Cristina", "Ona", "Carla", "Mar", "Alba S.",
	"Rocío", "Inés", "Aina", "Lía", "Noa", "Celia", "Valeria", "Anna P.", "Gemma", "Maite", "Sílvia", "Núria",
	"Paloma", "Rosa M."]
const NAMES_M := ["marc_puig", "JaviG", "Iker", "pau13", "Jordi B.", "Hugo_V", "LeoZ", "Oriol", "Álex P.", "Nil",
	"Bruno", "Mateo", "raul92", "Gael", "Pol R.", "Adrián", "Biel", "Arnau", "Unai", "Hèctor", "quim_s", "Thiago",
	"Rubén", "Ferran", "dani_k", "Marcos", "Izan", "Tomás", "Eric", "Lucas", "Miguel A.", "Enzo", "Joel", "Sergi",
	"Teo", "Gonzalo", "Xavi", "Andreu", "Roger", "Víctor", "Dídac", "Samuel", "Pere", "Jaume"]
## Apodos para quien usa un avatar de animal (también hay quien usa su nombre real).
const NAMES_N := ["LunaFox", "zenpanda", "n0va", "KoalaKid", "Bruma", "pixel_owl", "Tito99", "Mochi", "Cometa",
	"Nube", "TigreRoig", "ElOso", "sloth_mode", "PinguiX", "Kiwi", "Churro", "Pistacho", "Ondas", "Brisa", "Zorro_",
	"Tortuga77", "MarAzul", "Bambú", "Cacao", "Trufa", "Valen", "NoraLuna", "Sombra", "Chispa7", "Menta"]


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


## Identidades (avatar + nombre) de los participantes simulados de una liga. Deterministas por
## la clave de la liga, con avatares y nombres todos distintos y coherentes entre sí.
static func identities(key: String, count: int) -> Array:
	var rng := Rng.make(Rng.hash_string("liga-id:" + key))
	var order: Array = Rng.shuffle(range(AVATAR_COUNT), rng)
	var used_kin := {}
	var picks := []
	for a in order:
		if picks.size() >= count:
			break
		if used_kin.has(AVATAR_KIN[a]):
			continue
		used_kin[AVATAR_KIN[a]] = true
		picks.append(a)
	for a in order:  # solo si faltaran avatares con kin distinto
		if picks.size() >= count:
			break
		if not picks.has(a):
			picks.append(a)
	var pools := {"f": Rng.shuffle(NAMES_F.duplicate(), rng), "m": Rng.shuffle(NAMES_M.duplicate(), rng),
		"n": Rng.shuffle(NAMES_N.duplicate(), rng)}
	var out := []
	for a in picks:
		var kind: String = AVATAR_KIND[a]
		var pool_key := kind
		if kind == "n" and rng.randf() < 0.45:
			pool_key = "f" if rng.randf() < 0.5 else "m"  # animal con nombre real
		if pools[pool_key].is_empty():
			pool_key = "n" if not pools["n"].is_empty() else ("f" if not pools["f"].is_empty() else "m")
		out.append({"avatar": a, "name": pools[pool_key].pop_back()})
	return out


## Participantes simulados de una liga (sin contar al jugador).
static func bots(inst: Dictionary, calib: float, division: int = 0) -> Array:
	var cfg: Dictionary = CONFIG[inst.type]
	var rng := Rng.make(Rng.hash_string("liga:" + inst.key))
	var ids := identities(inst.key, int(cfg.size) - 1)
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
		out.append({"name": ids[k].name, "avatar": ids[k].avatar,
			"rate": calib * lvl_per_hour * skill / 3600.0, "sessions": sessions})
	return out


## Puntos de un participante simulado en el instante `now` (crece con el tiempo).
static func bot_points(bot: Dictionary, inst: Dictionary, now: int) -> int:
	var t := float(now - inst.start)
	var total := 0.0
	for s in bot.sessions:
		total += clampf(t - s[0], 0.0, s[1]) * bot.rate
	return int(total)


## Clasificación: [{name, points, avatar (-1 = tú), you}] ordenada de mayor a menor.
static func standings(inst: Dictionary, calib: float, division: int, your_points: int, now: int, your_name := "") -> Array:
	var rows := []
	for b in bots(inst, calib, division):
		rows.append({"name": b.name, "points": bot_points(b, inst, mini(now, inst.end)), "avatar": b.avatar, "you": false})
	rows.append({"name": your_name, "points": your_points, "avatar": -1, "you": true})
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
