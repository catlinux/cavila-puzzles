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
