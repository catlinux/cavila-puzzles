extends RefCounted
## Contrato de la lógica pura de un puzle (sin nodos ni UI, apta para tests headless).
##
## Para añadir un puzle nuevo (binario, desigualdades, nonograma...):
##   1. Crear puzzles/<nombre>/<nombre>_logic.gd que extienda este script.
##   2. Crear la escena puzzles/<nombre>/<nombre>.tscn con un script que extienda
##      core/puzzle_base.gd y sobrescriba _setup() y _give_hint().
##   3. Registrarlo en core/registry.gd y añadir sus textos en core/i18n.gd.

const EASY := 0
const MEDIUM := 1
const HARD := 2

## Genera un puzle resoluble de forma determinista a partir de la semilla.
## Devuelve un Diccionario (vacío si fallase) con todos los datos del puzle.
func generate(_seed_value: int, _difficulty: int) -> Dictionary:
	return {}


## Resuelve el puzle. Debe devolver al menos {"solvable": bool, "count": int, "solution": ...}.
func solve(_puzzle: Dictionary) -> Dictionary:
	return {"solvable": false, "count": 0, "solution": null}


## Comprueba un intento del jugador. Devuelve {"ok": bool, "reason": String}.
func validate(_puzzle: Dictionary, _attempt) -> Dictionary:
	return {"ok": false, "reason": "not_implemented"}
