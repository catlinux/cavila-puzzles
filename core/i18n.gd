extends RefCounted
## Traducciones es/ca registradas en el TranslationServer de Godot.
## Se usan con tr("CLAVE"). El español es el idioma por defecto.

const LANGS := ["es", "ca"]

const STRINGS := {
	"MENU_PICK": ["Elige un puzle", "Tria un puzle"],
	"MENU_DAILY": ["Puzle diario", "Puzle diari"],
	"DAILY_DONE": ["Completado hoy", "Completat avui"],
	"SOON": ["Próximamente", "Aviat"],
	"PUZZLE_CIRCUITO": ["Circuito", "Circuit"],
	"PUZZLE_SENDERO": ["Sendero", "Sender"],
	"PUZZLE_PIEZAS": ["Piezas", "Peces"],
	"PUZZLE_BINARIO": ["Binario", "Binari"],
	"PUZZLE_DESIGUALDADES": ["Desigualdades", "Desigualtats"],
	"PUZZLE_MOSAICO": ["Mosaico", "Mosaic"],
	"PUZZLE_ENLACES": ["Enlaces", "Enllaços"],
	"PUZZLE_APAGON": ["Apagón", "Apagada"],
	"PUZZLE_SECUENCIA": ["Secuencia", "Seqüència"],
	"HELP_CIRCUITO": [
		"Traza el camino de la entrada a la salida. Las puertas solo dejan pasar en el sentido de su flecha; los interruptores invierten las puertas de su color.",
		"Traça el camí de l'entrada a la sortida. Les portes només deixen passar en el sentit de la fletxa; els interruptors inverteixen les portes del seu color."],
	"HELP_SENDERO": [
		"Une el inicio con el final sin repetir casillas. Los números indican cuántas casillas de cada fila y columna usa el camino.",
		"Uneix l'inici amb el final sense repetir caselles. Els números indiquen quantes caselles de cada fila i columna fa servir el camí."],
	"HELP_PIEZAS": [
		"Arrastra las piezas para rellenar la silueta. Toca una pieza de la bandeja para girarla.",
		"Arrossega les peces per omplir la silueta. Toca una peça de la safata per girar-la."],
	"DIFF_EASY": ["Fácil", "Fàcil"],
	"DIFF_MEDIUM": ["Medio", "Mitjà"],
	"DIFF_HARD": ["Difícil", "Difícil"],
	"LEVEL": ["Nivel", "Nivell"],
	"DONE_COUNT": ["Completados", "Completats"],
	"HINT": ["Pista", "Pista"],
	"GENERATING": ["Generando…", "Generant…"],
	"WIN_TITLE": ["¡Resuelto!", "Resolt!"],
	"LOSE_TITLE": ["Sin vidas", "Sense vides"],
	"STAT_TIME": ["Tiempo", "Temps"],
	"STAT_LIVES": ["Vidas restantes", "Vides restants"],
	"STAT_HINTS": ["Pistas usadas", "Pistes usades"],
	"NEXT": ["Siguiente nivel", "Nivell següent"],
	"RETRY": ["Reintentar", "Torna-ho a provar"],
	"REPLAY": ["Jugar de nuevo", "Torna a jugar"],
	"MENU": ["Menú", "Menú"],
	"TAGLINE": ["Puzles para pensar", "Puzles per pensar"],
	"DAILY_SUB": ["Un reto nuevo cada día", "Un repte nou cada dia"],
	"PLAYED": ["niveles", "nivells"],
	"LEVELS": ["Niveles", "Nivells"],
	"LANG_NAME": ["ES", "CA"],
}


static func install() -> void:
	for i in LANGS.size():
		var t := Translation.new()
		t.locale = LANGS[i]
		for key in STRINGS:
			t.add_message(key, STRINGS[key][i])
		TranslationServer.add_translation(t)


## Idioma por defecto: catalán si el sistema está en catalán, si no español.
static func default_language() -> String:
	return "ca" if OS.get_locale_language() == "ca" else "es"
