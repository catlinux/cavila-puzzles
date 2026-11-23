extends Node
## Autoload "Game": partida en curso (nivel o reto diario), vidas y navegación.

const Daily = preload("res://core/daily.gd")
const Levels = preload("res://game/levels.gd")
const Arrows = preload("res://game/arrows.gd")
const I18n = preload("res://core/i18n.gd")

const MAX_LIVES := 3
const PLAY_SCENE := "res://ui/play.tscn"
const HOME_SCENE := "res://ui/home.tscn"

var mode := "level"  # "level" o "daily"
var level := 1
var daily_key := ""
var lives := MAX_LIVES
var hints_used := 0
var mistakes := 0
var elapsed := 0.0


func _ready() -> void:
	I18n.install()
	var lang: String = Progress.setting("lang")
	if lang == null or lang == "":
		lang = I18n.default_language()
	TranslationServer.set_locale(lang)


func set_language(lang: String) -> void:
	TranslationServer.set_locale(lang)
	Progress.set_setting("lang", lang)


func language() -> String:
	return TranslationServer.get_locale().substr(0, 2)


## Prepara una partida sin cambiar de escena (útil para tests).
func begin(new_mode: String, n: int = 1, key: String = "") -> void:
	mode = new_mode
	level = n
	daily_key = key
	lives = MAX_LIVES
	hints_used = 0
	mistakes = 0
	elapsed = 0.0


var _cache := {}  # tableros ya generados (la miniatura del inicio y la partida comparten)


func puzzle() -> Dictionary:
	if mode == "daily":
		return puzzle_for_daily(daily_key)
	return puzzle_for_level(level)


func puzzle_for_level(n: int) -> Dictionary:
	var key := "L%d" % n
	if not _cache.has(key):
		if _cache.size() > 6:
			_cache.clear()
		_cache[key] = Arrows.generate(Levels.seed_for(n), Levels.params_for(n))
	return _cache[key]


func puzzle_for_daily(key: String) -> Dictionary:
	var k := "D" + key
	if not _cache.has(k):
		_cache[k] = Arrows.generate(Daily.seed_for(key), Daily.params_for(key))
	return _cache[k]


## Dificultad (0..1) de la partida en curso.
func difficulty() -> float:
	return Daily.difficulty(daily_key) if mode == "daily" else Levels.difficulty(level)


func seed_value() -> int:
	return Daily.seed_for(daily_key) if mode == "daily" else Levels.seed_for(level)


func world() -> Dictionary:
	return Daily.world_for(daily_key) if mode == "daily" else Levels.world(level)


func start_level(n: int) -> void:
	begin("level", n)
	get_tree().change_scene_to_file(PLAY_SCENE)


func start_daily() -> void:
	begin("daily", 0, Daily.today_key())
	get_tree().change_scene_to_file(PLAY_SCENE)


func restart() -> void:
	begin(mode, level, daily_key)
	get_tree().change_scene_to_file(PLAY_SCENE)


func next_level() -> void:
	start_level(level + 1)


func go_home() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)

