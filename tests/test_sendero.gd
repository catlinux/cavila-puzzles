extends "res://tests/test_case.gd"

const Logic = preload("res://puzzles/sendero/sendero_logic.gd")


func _init() -> void:
	name = "sendero"


func run() -> void:
	var lg = Logic.new()
	for d in 3:
		var n := scale(12)
		var t0 := Time.get_ticks_msec()
		for s in n:
			var p: Dictionary = lg.generate(2000 + s, d)
			var tag := "d%d seed%d" % [d, s]
			check(not p.is_empty(), "genera " + tag)
			if p.is_empty():
				continue
			var r: Dictionary = lg.solve(p, 2)
			check(r.count == 1 and not r.exhausted, "solución única " + tag + " (count=%d)" % r.count)
			check(lg.validate(p, r.solution).ok, "solución válida " + tag)
			check(r.solution == p.planted, "la solución es la plantada " + tag)
			var cn: Dictionary = lg.counts(p, p.planted)
			check(cn.rows == p.rows and cn.cols == p.cols, "pistas coherentes " + tag)
			check(not p.blocked[p.start] and not p.blocked[p.end], "inicio/fin libres " + tag)
		print("    sendero d%d: %d niveles en %d ms" % [d, n, Time.get_ticks_msec() - t0])

	check(var_to_str(lg.generate(5, 1)) == var_to_str(lg.generate(5, 1)), "determinista")

	# A mano 3x3 sin bloqueos, de 0 a 8, con todas las pistas a 3: hay dos recorridos
	# (una serpiente por filas y otra por columnas) => 2 soluciones.
	var amb := {"type": "sendero", "w": 3, "h": 3, "blocked": [false, false, false, false, false, false, false, false, false],
		"start": 0, "end": 8, "rows": [3, 3, 3], "cols": [3, 3, 3]}
	check(lg.solve(amb, 5).count == 2, "detecta ambigüedad (2 soluciones)")
	# A mano 2x2 con una casilla bloqueada: queda una sola.
	var base := {"type": "sendero", "w": 2, "h": 2, "blocked": [false, false, false, false],
		"start": 0, "end": 3, "rows": [2, 2], "cols": [2, 2]}
	# Bloqueando la casilla 2 queda una sola.
	var uniq: Dictionary = base.duplicate(true)
	uniq.blocked[2] = true
	uniq.rows = [2, 1]
	uniq.cols = [1, 2]
	var ru: Dictionary = lg.solve(uniq, 5)
	check(ru.count == 1 and ru.solution == [0, 1, 3], "solución única a mano")
	# Pistas imposibles.
	var bad: Dictionary = uniq.duplicate(true)
	bad.rows = [2, 2]
	check(not lg.solve(bad).solvable, "pistas inconsistentes => sin solución")
	# Validación de intentos.
	check(lg.validate(uniq, [0, 1, 3]).ok, "válido")
	check(lg.validate(uniq, [0, 2, 3]).reason == "blocked", "casilla bloqueada")
	check(lg.validate(uniq, [0, 3]).reason == "not_adjacent", "no adyacente")
	check(lg.validate(uniq, [0, 1]).reason == "incomplete", "incompleto")
	check(lg.validate(base, [0, 1, 0, 1, 3]).reason == "revisit", "repetir casilla")
	check(lg.validate(base, [0, 1, 3]).reason == "row_clue", "pistas de fila no cumplidas (2,2 vs 2,1)")
	check(lg.validate(uniq, [1, 3]).reason == "bad_start", "inicio erróneo")
	# Continuar desde prefijo.
	var p: Dictionary = lg.generate(9, 0)
	check(lg.solve(p, 2, p.planted.slice(0, 4)).count == 1, "continuar desde prefijo")
