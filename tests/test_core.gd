extends "res://tests/test_case.gd"

const Rng = preload("res://core/rng.gd")
const Daily = preload("res://core/daily.gd")
const Registry = preload("res://core/registry.gd")
const PuzzleLogic = preload("res://core/puzzle_logic.gd")
const ProgressScript = preload("res://core/progress.gd")


func _init() -> void:
	name = "core"


func run() -> void:
	# Hash estable (valores de referencia FNV-1a 32 bits).
	check(Rng.hash_string("") == 2166136261, "FNV vacío")
	check(Rng.hash_string("a") == 0xE40C292C, "FNV 'a'")
	check(Rng.level_seed("circuito", 0, 3) == Rng.level_seed("circuito", 0, 3), "semilla estable")
	check(Rng.level_seed("circuito", 0, 3) != Rng.level_seed("circuito", 0, 4), "semillas distintas por nivel")
	check(Rng.level_seed("circuito", 0, 3) != Rng.level_seed("circuito", 1, 3), "semillas distintas por dificultad")
	var r1 := Rng.make(5)
	var r2 := Rng.make(5)
	check(r1.randi() == r2.randi(), "RNG reproducible")
	var arr := Rng.shuffle([1, 2, 3, 4, 5, 6, 7, 8], Rng.make(9))
	check(arr == Rng.shuffle([1, 2, 3, 4, 5, 6, 7, 8], Rng.make(9)), "shuffle reproducible")
	arr.sort()
	check(arr == [1, 2, 3, 4, 5, 6, 7, 8], "shuffle conserva elementos")

	# Puzle diario: depende solo de la fecha.
	check(Daily.puzzle_for("2026-03-01") == Daily.puzzle_for("2026-03-01"), "tipo diario estable")
	check(Registry.ids().has(Daily.puzzle_for("2026-03-02")), "tipo diario registrado")
	check(Daily.difficulty_for("2026-03-01") in [1, 2], "dificultad diaria")
	check(Daily.seed_for("2026-03-01", "sendero") != Daily.seed_for("2026-03-02", "sendero"), "semilla cambia por día")
	check(Daily.today_key().length() == 10, "formato de fecha")
	var types := {}
	for day in 60:
		types[Daily.puzzle_for("2026-04-%02d" % (day % 28 + 1) + str(day))] = true
	check(types.size() == Registry.ids().size(), "el diario rota entre todos los puzles")

	# Registro: todas las entradas existen y su lógica cumple el contrato.
	for e in Registry.all():
		check(ResourceLoader.exists(e.scene), "escena existe: " + e.id)
		var lg = Registry.create_logic(e.id)
		check(lg is PuzzleLogic, "lógica extiende PuzzleLogic: " + e.id)
		for d in 3:
			var p: Dictionary = lg.generate(Rng.level_seed(e.id, d, 0), d)
			check(not p.is_empty(), "%s d%d genera" % [e.id, d])

	# Progreso guardado.
	var path := "user://test_progress.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var pr = ProgressScript.new()
	pr.save_path = path
	pr.load_data()
	check(pr.highest_unlocked("circuito", 0) == 0, "al inicio solo el nivel 0")
	pr.mark_done("circuito", 0, 0, 30.0, 3)
	pr.mark_done("circuito", 0, 1, 20.0, 2)
	pr.mark_done("circuito", 0, 1, 25.0, 1)  # peor tiempo: no pisa el mejor
	pr.mark_daily("2026-03-01", "sendero")
	pr.set_language("ca")
	var pr2 = ProgressScript.new()
	pr2.save_path = path
	pr2.load_data()
	check(pr2.is_done("circuito", 0, 1) and not pr2.is_done("circuito", 0, 2), "persistencia de niveles")
	check(pr2.highest_unlocked("circuito", 0) == 2, "se desbloquea el siguiente")
	check(pr2.done_count("circuito", 0) == 2 and pr2.done_count("circuito", 1) == 0, "contadores por dificultad")
	check(is_equal_approx(pr2.data["levels"]["circuito:0"]["1"]["t"], 20.0), "se conserva el mejor tiempo")
	check(pr2.daily_done("2026-03-01") and not pr2.daily_done("2026-03-02"), "diario completado")
	check(pr2.get_language() == "ca", "idioma guardado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	pr.free()
	pr2.free()
