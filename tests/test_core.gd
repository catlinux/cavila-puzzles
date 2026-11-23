extends "res://tests/test_case.gd"

const Rng = preload("res://core/rng.gd")
const Daily = preload("res://core/daily.gd")
const Arrows = preload("res://game/arrows.gd")
const ProgressScript = preload("res://core/progress.gd")
const Levels = preload("res://game/levels.gd")


func _init() -> void:
	name = "núcleo"


func run() -> void:
	# Hash estable (valores de referencia FNV-1a 32 bits).
	check(Rng.hash_string("") == 2166136261, "FNV vacío")
	check(Rng.hash_string("a") == 0xE40C292C, "FNV 'a'")
	var r1 := Rng.make(5)
	var r2 := Rng.make(5)
	check(r1.randi() == r2.randi(), "RNG reproducible")
	var arr := Rng.shuffle([1, 2, 3, 4, 5, 6, 7, 8], Rng.make(9))
	check(arr == Rng.shuffle([1, 2, 3, 4, 5, 6, 7, 8], Rng.make(9)), "shuffle reproducible")
	arr.sort()
	check(arr == [1, 2, 3, 4, 5, 6, 7, 8], "shuffle conserva elementos")

	# Reto diario: depende solo de la fecha y siempre es resoluble.
	check(Daily.today_key().length() == 10, "formato de fecha")
	check(Daily.seed_for("2026-03-01") == Daily.seed_for("2026-03-01"), "semilla diaria estable")
	check(Daily.seed_for("2026-03-01") != Daily.seed_for("2026-03-02"), "cambia cada día")
	for day in scale(15):
		var key := "2026-05-%02d" % (day + 1)
		var p := Arrows.generate(Daily.seed_for(key), Daily.params_for(key))
		check(not p.is_empty() and Arrows.solve(p).solvable, "reto diario resoluble " + key)

	check(Levels.stars_for(3) == 3 and Levels.stars_for(2) == 2 and Levels.stars_for(1) == 1, "estrellas por luces")

	# Progreso guardado.
	var path := "user://test_progress.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var pr = ProgressScript.new()
	pr.save_path = path
	pr.load_data()
	check(pr.current_level() == 1 and pr.hints() == 3, "estado inicial")
	pr.complete_level(1, 3)
	pr.complete_level(2, 1)
	pr.complete_level(2, 2)  # mejora: se guarda la mejor
	pr.complete_level(1, 1)  # peor: no pisa
	var b5: Dictionary = {}
	for n in range(3, 6):
		b5 = pr.complete_level(n, 3)
	check(b5.hint_bonus == 1 and pr.hints() == 4, "pista extra cada 5 niveles")
	check(pr.complete_level(5, 3).hint_bonus == 0, "la pista extra solo la primera vez")
	check(pr.use_hint() and pr.hints() == 3, "gastar pista")
	pr.complete_daily("2026-03-01")
	pr.complete_daily("2026-03-02")
	pr.complete_daily("2026-03-02")  # repetido: no cuenta
	pr.set_setting("sound", false)
	var pr2 = ProgressScript.new()
	pr2.save_path = path
	pr2.load_data()
	check(pr2.current_level() == 6, "nivel actual persistente")
	check(pr2.stars(1) == 3 and pr2.stars(2) == 2, "mejores estrellas")
	check(pr2.total_stars() == 3 + 2 + 9, "total de estrellas")
	check(pr2.daily_done("2026-03-02") and not pr2.daily_done("2026-03-03"), "diario completado")
	check(pr2.streak("2026-03-02") == 2 and pr2.streak("2026-03-03") == 2, "racha vigente")
	check(pr2.streak("2026-03-05") == 0, "racha perdida")
	check(pr2.hints() == 3 + 4, "pistas por reto diario")
	check(pr2.setting("sound") == false and pr2.setting("vibration") == true, "ajustes")
	pr2.complete_daily("2026-03-04")  # se saltó un día: la racha vuelve a 1
	check(pr2.streak("2026-03-04") == 1, "racha reiniciada")
	check(ProgressScript.days_between("2026-02-28", "2026-03-01") == 1, "días entre fechas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	pr.free()
	pr2.free()
