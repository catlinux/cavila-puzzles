extends RefCounted
## Traducciones es/ca registradas en el TranslationServer de Godot (se usan con tr()).

const LANGS := ["es", "ca"]

const STRINGS := {
	"TAGLINE": ["Libera la luz", "Allibera la llum"],
	"PLAY": ["Jugar", "Juga"],
	"LEVEL": ["Nivel", "Nivell"],
	"DAILY": ["Reto diario", "Repte diari"],
	"DAILY_DONE": ["Completado", "Completat"],
	"DAILY_GO": ["Jugar", "Juga"],
	"STREAK": ["Racha", "Ratxa"],
	"DAYS": ["días", "dies"],
	"DAY": ["día", "dia"],
	"WORLD": ["Mundo", "Món"],
	"WORLD_ALBA": ["Alba", "Alba"],
	"WORLD_MAREA": ["Marea", "Marea"],
	"WORLD_AMBAR": ["Ámbar", "Ambre"],
	"WORLD_BRUMA": ["Bruma", "Boira"],
	"WORLD_BOSQUE": ["Bosque", "Bosc"],
	"WORLD_ASCUA": ["Ascua", "Brasa"],
	"WORLD_GLACIAR": ["Glaciar", "Glacera"],
	"WORLD_NEBULA": ["Nébula", "Nebulosa"],
	"CHALLENGE": ["Reto", "Repte"],
	"BREATHER": ["Respiro", "Respir"],
	"WIN": ["¡Cielo despejado!", "Cel serè!"],
	"LOSE": ["Sin luces", "Sense llums"],
	"LOSE_SUB": ["Demasiados choques. ¡Piensa el orden!", "Massa xocs. Pensa l'ordre!"],
	"CONTINUE": ["Continuar", "Continua"],
	"RETRY": ["Reintentar", "Torna-ho a provar"],
	"REPLAY": ["Repetir", "Repeteix"],
	"HOME": ["Inicio", "Inici"],
	"NO_HINTS": ["No te quedan pistas", "No et queden pistes"],
	"HINT_BONUS": ["+%d pista", "+%d pista"],
	"HINT_BONUS_N": ["+%d pistas", "+%d pistes"],
	"TUTORIAL_1": ["Toca una flecha: sale hacia donde apunta.", "Toca una fletxa: surt cap on apunta."],
	"TUTORIAL_2": ["Si choca con otra, pierdes una luz. ¡Elige bien el orden!", "Si xoca amb una altra, perds una llum. Tria bé l'ordre!"],
	"TUTORIAL_3": ["Las flechas largas también salen enteras.", "Les fletxes llargues també surten senceres."],
	"ARROWS_LEFT": ["flechas", "fletxes"],
	"SETTINGS": ["Ajustes", "Configuració"],
	"SOUND": ["Sonido", "So"],
	"VIBRATION": ["Vibración", "Vibració"],
	"LANGUAGE": ["Idioma", "Idioma"],
	"ON": ["Sí", "Sí"],
	"OFF": ["No", "No"],
	"CLOSE": ["Cerrar", "Tanca"],
	"LANG_NAME": ["Español", "Català"],
	"STARS": ["estrellas", "estrelles"],
	"OF": ["de", "de"],
	"LEVELS_IN_WORLD": ["niveles", "nivells"],
	"EVENT": ["Evento", "Esdeveniment"],
	"DAYS_LEFT": ["%d días", "%d dies"],
	"DAY_LEFT": ["1 día", "1 dia"],
	"EVENT_DONE": ["¡Completado!", "Completat!"],
	"EVENT_0": ["Semana espiral", "Setmana espiral"],
	"EVENT_1": ["Semana veloz", "Setmana veloç"],
	"EVENT_2": ["Semana estelar", "Setmana estel·lar"],
	"EVENT_3": ["Semana serena", "Setmana serena"],
	"EVENT_4": ["Semana del laberinto", "Setmana del laberint"],
	"STREAK_LINE": ["Racha de %d días", "Ratxa de %d dies"],
	"STREAK_LINE_1": ["Racha de 1 día", "Ratxa d'1 dia"],
	"STREAK_NONE": ["Empieza tu racha", "Comença la ratxa"],
	"CREDITS": ["Créditos", "Crèdits"],
	"MUSIC": ["Música", "Música"],
	"RESET_PROGRESS": ["Borrar progreso", "Esborra el progrés"],
	"RESET_TITLE": ["¿Empezar de cero?", "Començar de zero?"],
	"RESET_TEXT": ["Se borrarán tus niveles, estrellas, pistas y rachas. No se puede deshacer.", "S'esborraran els nivells, estrelles, pistes i ratxes. No es pot desfer."],
	"RESET_YES": ["Sí, borrar todo", "Sí, esborra-ho tot"],
	"CANCEL": ["Cancelar", "Cancel·la"],
	"MOVES": ["%d movimientos posibles", "%d moviments possibles"],
	"MOVES_1": ["1 movimiento posible", "1 moviment possible"],
	"CREDITS_TEXT": ["Fuentes Fredoka y Nunito (SIL Open Font License 1.1). Iconos Phosphor (licencia MIT). Hecho con Godot Engine (licencia MIT).",
		"Fonts Fredoka i Nunito (SIL Open Font License 1.1). Icones Phosphor (llicència MIT). Fet amb Godot Engine (llicència MIT)."],
	"ARROWS_PROGRESS": ["%d de %d flechas", "%d de %d fletxes"],
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
