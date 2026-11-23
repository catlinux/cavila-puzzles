extends "res://tests/test_case.gd"

const Arrows = preload("res://game/arrows.gd")
const Levels = preload("res://game/levels.gd")


func _init() -> void:
	name = "flechas"


func _arrow(cells: Array) -> Dictionary:
	return {"cells": cells, "dir": cells[cells.size() - 1] - cells[cells.size() - 2]}


func run() -> void:
	# --- Reglas con tableros hechos a mano -----------------------------------------
	# 3x1: flecha 0 en (0,0)->(1,0) apunta a la derecha; sale libre.
	var p := {"w": 3, "h": 1, "arrows": [_arrow([Vector2i(0, 0), Vector2i(1, 0)])]}
	check(Arrows.validate(p).ok, "válido simple")
	check(Arrows.exit_path(p, 0) == [Vector2i(2, 0)], "camino de salida")
	check(Arrows.can_exit(p, 0, Arrows.occupancy(p)), "sale libre")

	# Bloqueo: flecha 0 apunta a la derecha hacia la flecha 1 (vertical en x=3).
	var q := {"w": 4, "h": 3, "arrows": [
		_arrow([Vector2i(0, 1), Vector2i(1, 1)]),
		_arrow([Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0)])]}
	var occ := Arrows.occupancy(q)
	var bl := Arrows.blocker(q, 0, occ)
	check(bl.by == 1 and bl.steps == 1, "choca con la 1 tras avanzar 1 (%s)" % [bl])
	check(Arrows.can_exit(q, 1, occ), "la 1 sale hacia arriba")
	var s := Arrows.solve(q)
	check(s.solvable and s.order == [1, 0] and s.layers == 2, "orden de solución %s" % [s])
	check(Arrows.can_exit(q, 0, Arrows.occupancy(q, {1: true})), "tras quitar la 1, la 0 sale")

	# Bloqueo mutuo: dos flechas enfrentadas => sin solución.
	var dead := {"w": 4, "h": 1, "arrows": [
		_arrow([Vector2i(0, 0), Vector2i(1, 0)]),
		_arrow([Vector2i(3, 0), Vector2i(2, 0)])]}
	check(not Arrows.solve(dead).solvable, "bloqueo mutuo detectado")

	# Validación estructural.
	var bad := {"w": 3, "h": 3, "arrows": [{"cells": [Vector2i(0, 0), Vector2i(1, 1)], "dir": Vector2i(1, 1)}]}
	check(Arrows.validate(bad).reason == "not_contiguous", "no contigua")
	var over := {"w": 3, "h": 1, "arrows": [_arrow([Vector2i(0, 0), Vector2i(1, 0)]), _arrow([Vector2i(1, 0), Vector2i(2, 0)])]}
	check(Arrows.validate(over).reason == "overlap", "solapadas")
	var selfb := {"w": 3, "h": 3, "arrows": [_arrow([Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1)])]}
	check(Arrows.validate(selfb).ok, "giro sin taparse")
	var selfb2 := {"w": 3, "h": 3, "arrows": [_arrow([Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1)])]}
	check(Arrows.validate(selfb2).reason == "self_block", "se tapa a sí misma")

	# --- Generador sobre la curva de niveles ----------------------------------------
	var samples := [1, 2, 3, 5, 8, 10, 15, 20, 30, 45, 60, 90, 120, 200, 350, 500, 800, 1200, 2000, 5000]
	var extra := scale(60)
	for k in extra:
		samples.append(1 + (k * 7919) % 3000)
	var t0 := Time.get_ticks_msec()
	var worst := 0
	for lv in samples:
		var t1 := Time.get_ticks_msec()
		var par := Levels.params_for(lv)
		var g := Arrows.generate(Levels.seed_for(lv), par)
		worst = maxi(worst, Time.get_ticks_msec() - t1)
		var tag := "nivel %d" % lv
		check(not g.is_empty(), "genera " + tag)
		if g.is_empty():
			continue
		check(Arrows.validate(g).ok, "estructura válida " + tag + " " + str(Arrows.validate(g)))
		var sol := Arrows.solve(g)
		check(sol.solvable and sol.order.size() == g.arrows.size(), "resoluble " + tag)
		check(g.w == par.w and g.h == par.h, "tamaño " + tag)
		var cov := 0
		for a in g.arrows:
			cov += a.cells.size()
			check(a.cells.size() <= maxi(int(par.max_len * 1.4), par.snake_max), "longitud máxima " + tag)
		var playable: int = g.w * g.h - g.holes.size() - g.rocks.size()
		check(float(cov) / playable >= (0.6 if lv < 10 else 0.85), "tablero bien lleno " + tag + " (%.2f)" % (float(cov) / playable))
		# Reproducir la solución tocando flechas una a una.
		var removed := {}
		var all_ok := true
		for i in sol.order:
			if not Arrows.can_exit(g, i, Arrows.occupancy(g, removed)):
				all_ok = false
			removed[i] = true
		check(all_ok, "la solución se puede jugar paso a paso " + tag)
	print("    generador: %d niveles en %d ms (peor %d ms)" % [samples.size(), Time.get_ticks_msec() - t0, worst])

	# Formas y obstáculos.
	var rock_p := {"w": 5, "h": 3, "rocks": [Vector2i(4, 1)], "holes": [Vector2i(0, 0)], "arrows": [_arrow([Vector2i(1, 1), Vector2i(2, 1)])]}
	check(Arrows.validate(rock_p).reason == "rock_block", "una roca no puede tapar una salida")
	check(Arrows.blocker(rock_p, 0, Arrows.occupancy(rock_p)).by == Arrows.ROCK, "la roca bloquea")
	var hole_p := {"w": 3, "h": 1, "rocks": [], "holes": [Vector2i(0, 0)], "arrows": [_arrow([Vector2i(0, 0), Vector2i(1, 0)])]}
	check(Arrows.validate(hole_p).reason == "on_hole_or_rock", "no hay flechas en los huecos")
	var hole_fly := {"w": 4, "h": 1, "rocks": [], "holes": [Vector2i(3, 0)], "arrows": [_arrow([Vector2i(0, 0), Vector2i(1, 0)])]}
	check(Arrows.can_exit(hole_fly, 0, Arrows.occupancy(hole_fly)), "las flechas cruzan los huecos")
	var kinds := {}
	var with_rocks := 0
	for lv in range(1, 300, 3):
		var par := Levels.params_for(lv)
		kinds[par.shape] = true
		if not par.rocks.is_empty():
			with_rocks += 1
	check(kinds.size() >= 8, "variedad de formas (%d)" % kinds.size())
	check(with_rocks >= 5, "hay niveles con obstáculos (%d)" % with_rocks)
	check(Levels.params_for(1).shape == "rect" and Levels.params_for(11).shape == "rect", "los primeros niveles son rectangulares")
	# Variedad de largos en niveles altos: hay serpientes largas y flechas cortas a la vez.
	var long_ok := 0
	for lv in [301, 455, 702, 1003]:
		var g := Arrows.generate(Levels.seed_for(lv), Levels.params_for(lv))
		var mx := 0
		var mn := 99
		for a in g.arrows:
			mx = maxi(mx, a.cells.size())
			mn = mini(mn, a.cells.size())
		if mx >= 18 and mn <= 4:
			long_ok += 1
	check(long_ok >= 3, "serpientes largas y flechas cortas en niveles altos (%d/4)" % long_ok)
	# Puntuación y rival.
	check(Levels.score(50, 0.5, 30.0, 3, 0, 60.0) > Levels.score(50, 0.5, 90.0, 3, 0, 60.0), "más rápido, más puntos")
	check(Levels.score(50, 0.5, 30.0, 3, 0, 60.0) > Levels.score(50, 0.5, 30.0, 1, 0, 60.0), "menos errores, más puntos")
	check(Levels.score(50, 0.9, 30.0, 3, 0, 60.0) > Levels.score(50, 0.1, 30.0, 3, 0, 60.0), "más difícil, más puntos")
	check(Levels.rival_time(100, 40, 5) > Levels.rival_time(20, 5, 5), "el rival tarda más en tableros grandes")

	# Determinismo.
	var a1 := Arrows.generate(Levels.seed_for(77), Levels.params_for(77))
	var a2 := Arrows.generate(Levels.seed_for(77), Levels.params_for(77))
	check(var_to_str(a1) == var_to_str(a2), "misma semilla => mismo nivel")
	check(var_to_str(a1) != var_to_str(Arrows.generate(Levels.seed_for(78), Levels.params_for(78))), "otro nivel => otro tablero")

	# Curva: crece en media y los primeros niveles son pequeños.
	check(Levels.params_for(1).w <= 6 and Levels.params_for(1).h <= 10, "nivel 1 pequeño")
	var avg_lo := 0.0
	var avg_hi := 0.0
	for k in 20:
		avg_lo += Levels.difficulty(11 + k)
		avg_hi += Levels.difficulty(500 + k)
	check(avg_hi > avg_lo, "la dificultad crece")
	check(Levels.params_for(100000).w <= 24 and Levels.params_for(100000).h <= 36, "tamaño máximo acotado (móvil)")
	check(Levels.beat(10) == 2 and Levels.beat(11) == 0 and Levels.beat(12) == 1, "ritmo de 10 niveles")
	check(Levels.world_index(1) == 0 and Levels.world_index(30) == 0 and Levels.world_index(31) == 1, "mundos de 30")
	# Profundidad media creciente.
	var d_lo := 0
	var d_hi := 0
	for k in 6:
		d_lo += Arrows.generate(Levels.seed_for(3 + k), Levels.params_for(3 + k)).depth
		d_hi += Arrows.generate(Levels.seed_for(900 + k), Levels.params_for(900 + k)).depth
	check(d_hi > d_lo, "más dependencias en niveles altos (%d vs %d)" % [d_lo, d_hi])
	# Niveles altos: pocas flechas libres al empezar; primeros niveles: muchas.
	var hi := Arrows.solve(Arrows.generate(Levels.seed_for(700), Levels.params_for(700)))
	var g700 := Arrows.generate(Levels.seed_for(700), Levels.params_for(700))
	check(float(hi.free0) / g700.arrows.size() < 0.2, "nivel 700: pocas libres al empezar")
	var g1 := Arrows.generate(Levels.seed_for(1), Levels.params_for(1))
	check(float(Arrows.solve(g1).free0) / g1.arrows.size() > 0.3, "nivel 1: muchas libres al empezar")
