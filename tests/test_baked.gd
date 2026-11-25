extends "res://tests/test_case.gd"
## Niveles horneados (fijos) y estabilidad del generador para los niveles que no lo están.

const Arrows = preload("res://game/arrows.gd")
const Levels = preload("res://game/levels.gd")
const Baked = preload("res://game/baked.gd")

## Huella de niveles NO horneados. Si cambia, los jugadores verían otros tableros en esos
## niveles: o es un cambio involuntario del generador, o hay que hornear más niveles antes.
const FINGERPRINTS := {1001: 2763836086, 1010: 3900240948, 1501: 2310019856, 1500: 1688884167, 3000: 638731422}


func _init() -> void:
	name = "niveles fijos"


static func fingerprint(p: Dictionary) -> int:
	return hash(var_to_str([p.w, p.h, p.get("depth", 0), p.arrows, p.get("holes", []), p.get("rocks", [])]))


func run() -> void:
	var all := Baked.load_all()
	check(all.size() == 1000, "hay 1000 niveles horneados (%d)" % all.size())
	# Ida y vuelta exacta del formato.
	for n in [1, 55, 157]:
		var p: Dictionary = Arrows.generate(Levels.seed_for(n), Levels.params_for(n))
		check(fingerprint(Baked.decode(Baked.encode(p))) == fingerprint(p), "codificar y decodificar el nivel %d no cambia nada" % n)
	# Todos los horneados se pueden resolver y respetan sus límites.
	var bad := 0
	var step := 7 if quick else 1
	for k in range(0, all.size(), step):
		var p := Baked.decode(all[k])
		var ok: bool = Arrows.solve(p).solvable and p.arrows.size() >= 2 and p.w <= Levels.MAX_W and p.h <= Levels.MAX_H
		if not ok:
			bad += 1
	check(bad == 0, "todos los niveles horneados tienen solución (%d fallos)" % bad)
	# El generador no ha cambiado para los niveles que aún se generan.
	for n in FINGERPRINTS:
		var fp := fingerprint(Arrows.generate(Levels.seed_for(n), Levels.params_for(n)))
		check(fp == FINGERPRINTS[n], "el nivel %d (no horneado) sigue igual (huella %d)" % [n, fp])
