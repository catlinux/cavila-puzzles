extends "res://tests/test_case.gd"

const Rng = preload("res://core/rng.gd")
const Leagues = preload("res://game/leagues.gd")
const ProgressScript = preload("res://core/progress.gd")


func _init() -> void:
	name = "ligas"


func run() -> void:
	# Límites de cada liga (lunes 2026-11-23 10:30 UTC = 1795429800).
	var now := 1795429800
	var fl := Leagues.instance("flash", now)
	check(fl.end - fl.start == 3 * 3600 and fl.start <= now and now < fl.end and fl.start % 10800 == 0, "relámpago de 3 h")
	var dl := Leagues.instance("daily", now)
	check(dl.end - dl.start == 86400 and dl.start % 86400 == 0 and now - dl.start == 10 * 3600 + 1800, "diaria de medianoche a medianoche")
	var wk := Leagues.instance("weekly", now)
	check(wk.end - wk.start == 7 * 86400 and wk.start <= now and now < wk.end, "semanal")
	check(Time.get_datetime_dict_from_unix_time(wk.start).weekday == 1, "la semanal empieza en lunes")
	var dl_madrid := Leagues.instance("daily", now, 60)
	check(dl_madrid.start == dl.start - 3600, "respeta la zona horaria")
	check(Leagues.instance("daily", now + 86400).key != dl.key, "cada día, una liga nueva")

	# Rivales simulados: deterministas, creíbles y con puntos que solo crecen.
	var calib := Leagues.points_per_level(80)
	var b1 := Leagues.bots(dl, calib)
	var b2 := Leagues.bots(dl, calib)
	check(var_to_str(b1) == var_to_str(b2), "mismos rivales para la misma liga")
	check(b1.size() == Leagues.CONFIG.daily.size - 1, "nº de participantes")
	var names := {}
	for b in b1:
		names[b.name] = true
	check(names.size() == b1.size(), "nombres distintos")
	var mono := true
	for b in b1:
		var last := -1
		for k in 25:
			var p := Leagues.bot_points(b, dl, dl.start + k * 3600)
			if p < last:
				mono = false
			last = p
	check(mono, "los puntos de los rivales nunca bajan")
	var at_end := Leagues.standings(dl, calib, 0, 0, dl.end)
	check(at_end[0].points > 0 and at_end[0].points < calib * 200, "el líder tiene una puntuación creíble (%d)" % at_end[0].points)
	check(Leagues.points_per_level(500) > Leagues.points_per_level(5), "la calibración sube con el nivel")
	var rows := Leagues.standings(dl, calib, 0, 999999999, now, "Tú")
	check(rows[0].you and Leagues.rank_of_you(rows) == 1, "con muchos puntos vas primero")
	var sorted_ok := true
	for k in rows.size() - 1:
		if rows[k].points < rows[k + 1].points:
			sorted_ok = false
	check(sorted_ok, "clasificación ordenada")
	check(Leagues.prize("daily", 1) == 4 and Leagues.prize("daily", 4) == 0, "premios")

	# Credibilidad: habituales, saltos, habilidad con cola larga, divisiones y avisos.
	var regs := Leagues.regulars()
	check(regs.size() == Leagues.REGULARS and var_to_str(regs) == var_to_str(Leagues.regulars()), "rivales habituales fijos")
	var reg_names := {}
	for r in regs:
		reg_names[r.name] = true
	var shared := 0
	var wk2 := Leagues.instance("weekly", now + 7 * 86400)
	var names1 := {}
	for b in Leagues.bots(wk, calib):
		names1[b.name] = true
	for b in Leagues.bots(wk2, calib):
		if names1.has(b.name) and reg_names.has(b.name):
			shared += 1
	check(shared >= 1, "algún rival reaparece de una liga a otra (%d)" % shared)
	for ty in Leagues.TYPES:
		var ins := Leagues.instance(ty, now)
		var av := {}
		var nm := {}
		for b in Leagues.bots(ins, calib):
			av[b.avatar] = true
			nm[b.name] = true
		var n_bots: int = Leagues.CONFIG[ty].size - 1
		check(av.size() == n_bots and nm.size() == n_bots, "%s: avatares y nombres distintos con habituales" % ty)
	var steps := {}
	var wbots := Leagues.bots(wk, calib)
	for b in wbots:
		for k in 200:
			var p := Leagues.bot_points(b, wk, wk.start + k * 3000)
			steps[p] = true
	check(steps.size() > 20, "los puntos suben a saltos (%d valores)" % steps.size())
	var sk := []
	for k in 400:
		sk.append(Leagues._skill(Rng.make(k)))
	sk.sort()
	check(sk[200] < 1.0 and sk[395] > 1.6 and sk[0] >= 0.55, "habilidad con cola larga (mediana %.2f, top %.2f)" % [sk[200], sk[395]])
	var lo := 0
	var hi := 0
	for b in Leagues.bots(wk, calib, 0):
		lo += Leagues.bot_points(b, wk, wk.end)
	for b in Leagues.bots(wk, calib, 4):
		hi += Leagues.bot_points(b, wk, wk.end)
	check(hi > lo * 1.3, "rivales más fuertes en divisiones altas (%d vs %d)" % [lo, hi])
	# Actividad: a las 21 h hay más gente jugando que a las 4 h.
	var evening := 0
	var night := 0
	for b in Leagues.bots(wk, calib):
		for s2 in b.sessions:
			var h := int(floorf((wk.start + s2[0]) / 3600.0 + 1.0)) % 24
			if h >= 17 and h <= 22:
				evening += 1
			elif h >= 2 and h <= 5:
				night += 1
	check(evening > night * 2, "más actividad de tarde que de madrugada (%d vs %d)" % [evening, night])
	var rws := [{"name": "A", "points": 500, "you": false}, {"name": "B", "points": 300, "you": false},
		{"name": "Tú", "points": 100, "you": true}]
	var n0 := Leagues.notice(rws, null)
	check(n0.key == "LG_GAP" and n0.args == [200, 2], "aviso: a N puntos del puesto K")
	check(Leagues.notice(rws, ["A"]).key == "LG_PASSED" and Leagues.notice(rws, ["A"]).args == ["B"], "aviso: B te ha adelantado")
	check(Leagues.notice(rws, ["A", "B"]).key == "LG_GAP", "aviso sin novedades")
	var first := [{"name": "Tú", "points": 900, "you": true}, {"name": "A", "points": 500, "you": false}]
	check(Leagues.notice(first, []).key == "LG_LEAD" and Leagues.notice(first, []).args == [400], "aviso: vas primero")

	# Coherencia entre ligas: cada rival es la misma persona en la flash, la diaria y la semanal de
	# su semana, y nunca tiene más puntos en la corta que en la larga que la contiene.
	var wk_n := Leagues.instance("weekly", now)
	var dl_n := Leagues.instance("daily", now)
	var fl_n := Leagues.instance("flash", now)
	var wk_b := {}
	for b in Leagues.bots(wk_n, calib):
		wk_b[b.name] = b
	var in_week := 0
	var nested_bad := 0
	var zero_bad := 0
	for lg_pair in [[dl_n, wk_n], [fl_n, wk_n], [fl_n, dl_n]]:
		var short: Dictionary = lg_pair[0]
		var long: Dictionary = lg_pair[1]
		var long_b := {}
		for b in Leagues.bots(long, calib):
			long_b[b.name] = b
		for b in Leagues.bots(short, calib):
			if not long_b.has(b.name):
				if long.type == "weekly":
					nested_bad += 1  # un rival de la diaria/flash debe estar en la semanal
				continue
			in_week += 1
			for step in range(0, int(short.end - short.start) + 1, 600):
				var t: int = short.start + step
				var ps := Leagues.bot_points(b, short, t)
				var pl := Leagues.bot_points(long_b[b.name], long, t)
				if ps > pl:
					nested_bad += 1
				if ps > 0 and pl == 0:
					zero_bad += 1
	check(in_week > 10, "hay rivales comunes entre ligas (%d)" % in_week)
	check(nested_bad == 0, "los rivales de la diaria y la flash están en la semanal y nunca tienen más puntos en la corta (%d fallos)" % nested_bad)
	check(zero_bad == 0, "nadie tiene puntos en la diaria o la flash y cero en la semanal (%d fallos)" % zero_bad)
	check(Leagues.bots(fl_n, calib).size() == Leagues.CONFIG.flash.size - 1 and Leagues.bots(dl_n, calib).size() == Leagues.CONFIG.daily.size - 1, "tamaño de las ligas corta y diaria")
	var act_fl := 0
	for b in Leagues.bots(fl_n, calib):
		if Leagues.bot_points(b, fl_n, fl_n.end) > 0:
			act_fl += 1
	check(act_fl >= 5, "la liga flash tiene actividad (%d rivales con puntos)" % act_fl)

	# Progreso: puntos en todas las ligas, resultados y ascensos.
	var path := "user://test_leagues.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var pr = ProgressScript.new()
	pr.save_path = path
	pr.load_data()
	pr.now_override = now
	pr.complete_level(1, 3, 1000000)
	check(int(pr.league("flash").points) == 1000000 and int(pr.league("weekly").points) == 1000000, "los puntos suman en todas las ligas")
	check(float(pr.league("flash").calib) == float(pr.league("weekly").calib) and float(pr.league("daily").calib) == float(pr.league("weekly").calib), "las tres ligas comparten calibración")
	# Puntos del jugador: la semanal siempre tiene al menos los de la diaria y la flash.
	check(int(pr.league("weekly").points) >= int(pr.league("daily").points) and int(pr.league("daily").points) >= int(pr.league("flash").points), "el jugador: semanal >= diaria >= flash")
	check(pr.pending_league_results().is_empty(), "sin resultados mientras están en curso")
	pr.now_override = now + 8 * 86400  # han terminado las tres
	var pend: Array = pr.pending_league_results()
	check(pend.size() == 3, "tres ligas terminadas (%d)" % pend.size())
	pr.data["hints"] = 0
	var hints0: int = pr.hints()
	var promoted := 0
	for r in pend:
		check(r.rank == 1, "primero en %s" % r.type)
		promoted += pr.claim_league(r.key)
	check(pr.hints() == mini(hints0 + 3 + 4 + 8, ProgressScript.MAX_HINTS), "premios cobrados sin pasar del máximo (%d)" % pr.hints())
	check(promoted == 1 and int(pr.data.division) == 1, "asciende de división")
	check(pr.pending_league_results().is_empty() and pr.claim_league(pend[0].key) == 0, "no se cobra dos veces")
	# Reiniciar ligas: borra puntos y división, pero no niveles ni estrellas.
	pr.complete_level(2, 3, 500)
	pr.data["division"] = 3
	var lvl_before: int = pr.current_level()
	pr.reset_leagues()
	check(pr.data["leagues"].is_empty() and int(pr.data["division"]) == 0 and pr.current_level() == lvl_before and pr.stars(2) == 3, "reiniciar ligas no toca niveles ni estrellas")
	check(int(pr.league("weekly").points) == 0, "tras reiniciar, la liga empieza de cero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	pr.free()
