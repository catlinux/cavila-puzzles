extends RefCounted
## Registro de puzles. Añadir una entrada aquí hace que aparezca en el menú.

const PUZZLES := [
	{"id": "circuito", "title": "PUZZLE_CIRCUITO", "help": "HELP_CIRCUITO",
		"scene": "res://puzzles/circuito/circuito.tscn", "logic": "res://puzzles/circuito/circuito_logic.gd"},
	{"id": "sendero", "title": "PUZZLE_SENDERO", "help": "HELP_SENDERO",
		"scene": "res://puzzles/sendero/sendero.tscn", "logic": "res://puzzles/sendero/sendero_logic.gd"},
	{"id": "piezas", "title": "PUZZLE_PIEZAS", "help": "HELP_PIEZAS",
		"scene": "res://puzzles/piezas/piezas.tscn", "logic": "res://puzzles/piezas/piezas_logic.gd"},
]

## Puzles previstos: solo se muestran bloqueados en el menú (sin lógica todavía).
const UPCOMING := [
	{"id": "binario", "title": "PUZZLE_BINARIO"},
	{"id": "desigualdades", "title": "PUZZLE_DESIGUALDADES"},
	{"id": "mosaico", "title": "PUZZLE_MOSAICO"},
	{"id": "enlaces", "title": "PUZZLE_ENLACES"},
	{"id": "apagon", "title": "PUZZLE_APAGON"},
	{"id": "secuencia", "title": "PUZZLE_SECUENCIA"},
]


static func all() -> Array:
	return PUZZLES


static func ids() -> Array:
	var out := []
	for p in PUZZLES:
		out.append(p.id)
	return out


static func get_entry(id: String) -> Dictionary:
	for p in PUZZLES:
		if p.id == id:
			return p
	return {}


static func create_logic(id: String):
	return load(get_entry(id).logic).new()
