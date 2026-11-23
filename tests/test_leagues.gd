extends "res://tests/test_case.gd"

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

	# Progreso: puntos en todas las ligas, resultados y ascensos.
	var path := "user://test_leagues.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var pr = ProgressScript.new()
	pr.save_path = path
	pr.load_data()
	pr.now_override = now
	pr.complete_level(1, 3, 1000000)
	check(int(pr.league("flash").points) == 1000000 and int(pr.league("weekly").points) == 1000000, "los puntos suman en todas las ligas")
	check(pr.pending_league_results().is_empty(), "sin resultados mientras están en curso")
	pr.now_override = now + 8 * 86400  # han terminado las tres
	var pend: Array = pr.pending_league_results()
	check(pend.size() == 3, "tres ligas terminadas (%d)" % pend.size())
	var hints0: int = pr.hints()
	var promoted := 0
	for r in pend:
		check(r.rank == 1, "primero en %s" % r.type)
		promoted += pr.claim_league(r.key)
	check(pr.hints() == hints0 + 3 + 4 + 8, "premios cobrados")
	check(promoted == 1 and int(pr.data.division) == 1, "asciende de división")
	check(pr.pending_league_results().is_empty() and pr.claim_league(pend[0].key) == 0, "no se cobra dos veces")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	pr.free()
