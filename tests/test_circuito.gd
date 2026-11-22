extends "res://tests/test_case.gd"

const Logic = preload("res://puzzles/circuito/circuito_logic.gd")


func _init() -> void:
	name = "circuito"


func run() -> void:
	var lg = Logic.new()
	for d in 3:
		var n := scale(25)
		var with_switch_needed := 0
		for s in n:
			var p: Dictionary = lg.generate(1000 + s, d)
			var tag := "d%d seed%d" % [d, s]
			check(not p.is_empty(), "genera " + tag)
			if p.is_empty():
				continue
			var r: Dictionary = lg.solve(p)
			check(r.solvable and not r.exhausted, "resoluble " + tag)
			check(lg.validate(p, r.solution).ok, "solución del solver válida " + tag)
			check(lg.validate(p, p.planted).ok, "camino plantado válido " + tag)
			check(p.planted.size() >= Logic.CONFIGS[d].min_len, "longitud mínima " + tag)
			if d > 0 and not lg.solve(p, [], 1, true).solvable:
				with_switch_needed += 1
		if d > 0:
			check(with_switch_needed >= n * 3 / 4, "los interruptores son necesarios (d%d): %d/%d" % [d, with_switch_needed, n])

	# Determinismo.
	var a: Dictionary = lg.generate(42, 1)
	var b: Dictionary = lg.generate(42, 1)
	check(var_to_str(a) == var_to_str(b), "misma semilla => mismo puzle")
	check(var_to_str(lg.generate(43, 1)) != var_to_str(a), "otra semilla => otro puzle")

	# Puzle a mano 3x1: 0 -> 1 -> 2, con un interruptor (grupo 0) en el nodo 1.
	#  arista 0->1 cable; arista 1->2 diodo de sentido 2->1 con grupo 0: solo se puede cruzar
	#  1->2 DESPUÉS de pisar el interruptor del nodo 1.
	var hand := {"type": "circuito", "w": 3, "h": 1, "start": 0, "exit": 2, "groups": 1,
		"switches": [-1, 0, -1],
		"edges": [{"a": 0, "b": 1, "kind": 0, "grp": -1}, {"a": 2, "b": 1, "kind": 1, "grp": 0}]}
	check(lg.solve(hand).solvable, "a mano: resoluble gracias al interruptor")
	check(not lg.solve(hand, [], 1, true).solvable, "a mano: sin interruptores no se resuelve")
	check(lg.validate(hand, [0, 1, 2]).ok, "a mano: [0,1,2] válido")
	check(lg.validate(hand, [0, 1]).reason == "incomplete", "a mano: incompleto")
	check(lg.validate(hand, [0, 2]).reason == "no_edge", "a mano: sin arista")
	check(lg.validate(hand, [1, 2]).reason == "bad_start", "a mano: inicio erróneo")
	# Mismo puzle sin interruptor: el diodo bloquea.
	var hand2: Dictionary = hand.duplicate(true)
	hand2.switches = [-1, -1, -1]
	check(lg.validate(hand2, [0, 1, 2]).reason == "blocked", "a mano: diodo bloquea sin interruptor")
	check(not lg.solve(hand2).solvable, "a mano: irresoluble sin interruptor")
	# No se puede revisitar nodos.
	var loop := {"type": "circuito", "w": 2, "h": 2, "start": 0, "exit": 3, "groups": 0,
		"switches": [-1, -1, -1, -1],
		"edges": [{"a": 0, "b": 1, "kind": 0, "grp": -1}, {"a": 1, "b": 3, "kind": 0, "grp": -1}]}
	check(lg.validate(loop, [0, 1, 0, 1, 3]).reason == "revisit", "no se repiten nodos")
	check(lg.validate(loop, [0, 1, 3]).ok, "camino simple válido")
	# Reanudar desde un prefijo (pistas).
	var r := lg.solve(lg.generate(7, 2), [])
	check(r.solvable, "d2 seed7 resoluble")
	var p7: Dictionary = lg.generate(7, 2)
	var pre: Array = r.solution.slice(0, 3)
	check(lg.solve(p7, pre).solvable, "se puede continuar desde un prefijo correcto")
