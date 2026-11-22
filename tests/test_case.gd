extends RefCounted
## Mini marco de pruebas: check() acumula fallos; run() lo implementa cada suite.

var name := "suite"
var checks := 0
var failures: Array = []
var quick := false


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func scale(n: int) -> int:
	return maxi(2, n / 5) if quick else n


func run() -> void:
	pass
