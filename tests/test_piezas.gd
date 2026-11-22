extends "res://tests/test_case.gd"

const Logic = preload("res://puzzles/piezas/piezas_logic.gd")


func _init() -> void:
	name = "piezas"


func run() -> void:
	var lg = Logic.new()
	# Geometría.
	var l4: Array = Logic.parse_shape("L4")
	check(l4.size() == 4, "L4 tiene 4 casillas")
	check(Logic.orientations(Logic.parse_shape("O4")).size() == 1, "O tiene 1 orientación")
	check(Logic.orientations(Logic.parse_shape("I4")).size() == 2, "I tiene 2 orientaciones")
	check(Logic.orientations(l4).size() == 4, "L tiene 4 orientaciones")
	check(Logic.shape_key(Logic.rotate_cells(l4, 1)) == Logic.shape_key(l4), "clave canónica invariante al giro")
	check(Logic.shape_key(Logic.parse_shape("S4")) != Logic.shape_key(Logic.parse_shape("Z4")), "S y Z distintas (sin espejo)")
	for id in Logic.SHAPES:
		check(Logic.parse_shape(id).size() == int(id.substr(id.length() - 1)), "tamaño de " + id)

	for d in 3:
		var n := scale(25)
		var t0 := Time.get_ticks_msec()
		for s in n:
			var p: Dictionary = lg.generate(3000 + s, d)
			var tag := "d%d seed%d" % [d, s]
			check(not p.is_empty(), "genera " + tag)
			if p.is_empty():
				continue
			var total := 0
			for v in p.cells:
				if v:
					total += 1
			var sizes := 0
			for pc in p.pieces:
				sizes += pc.cells.size()
			check(total == sizes, "área = suma de piezas " + tag)
			check(p.pieces.size() == Logic.CONFIGS[d].count, "nº de piezas " + tag)
			var v1: Dictionary = lg.validate(p, p.planted)
			check(v1.ok and v1.complete, "teselado plantado válido " + tag)
			var r: Dictionary = lg.solve(p)
			check(r.solvable and not r.exhausted, "resoluble " + tag)
			var v2: Dictionary = lg.validate(p, r.solution)
			check(v2.ok and v2.complete, "solución del solver válida " + tag)
		print("    piezas d%d: %d niveles en %d ms" % [d, n, Time.get_ticks_msec() - t0])

	check(var_to_str(lg.generate(11, 2)) == var_to_str(lg.generate(11, 2)), "determinista")

	# Irresoluble: quitar una pieza (el área deja de coincidir) o dos cuadrados 1x... no encajan.
	var p: Dictionary = lg.generate(5, 1)
	var broken: Dictionary = p.duplicate(true)
	broken.pieces.pop_back()
	check(not lg.solve(broken).solvable, "sin una pieza no hay solución")
	# Silueta 2x2 con dos piezas I3 (área 4 vs 6): no.
	var o4 := {"type": "piezas", "w": 2, "h": 2, "cells": [true, true, true, true],
		"pieces": [{"id": 0, "shape": "O4", "cells": Logic.parse_shape("O4"), "color": 0, "rot0": 0}]}
	check(lg.solve(o4).solvable, "O4 rellena 2x2")
	# Misma área pero forma que no encaja: I4 en 2x2.
	var bad: Dictionary = o4.duplicate(true)
	bad.pieces[0].cells = Logic.parse_shape("I4")
	check(not lg.solve(bad).solvable, "I4 no rellena 2x2")
	# Validación: giro permitido, forma errónea no.
	var dom := {"type": "piezas", "w": 3, "h": 1, "cells": [true, true, true],
		"pieces": [{"id": 0, "shape": "I3", "cells": Logic.parse_shape("I3"), "color": 0, "rot0": 0}]}
	check(lg.validate(dom, [{"piece": 0, "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]}]).complete, "I3 horizontal")
	check(lg.validate(dom, [{"piece": 0, "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]}]).reason == "outside", "fuera de silueta")
	check(lg.validate(dom, [{"piece": 0, "cells": [Vector2i(0, 0), Vector2i(1, 0)]}]).reason == "wrong_shape", "forma errónea")
	# Pistas con piezas ya colocadas (fixed).
	var q: Dictionary = lg.generate(21, 1)
	var first = q.planted[0]
	var rf: Dictionary = lg.solve(q, 1, [first])
	check(rf.solvable, "se resuelve respetando una pieza fija")
	check(lg.validate(q, rf.solution).complete, "solución con pieza fija válida")
