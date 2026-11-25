extends Node
## Autoload "Game": partida en curso (nivel o reto diario), vidas y navegación.

const Daily = preload("res://core/daily.gd")
const Levels = preload("res://game/levels.gd")
const Arrows = preload("res://game/arrows.gd")
const Baked = preload("res://game/baked.gd")
const I18n = preload("res://core/i18n.gd")

const MAX_LIVES := 3
const PLAY_SCENE := "res://ui/play.tscn"
const HOME_SCENE := "res://ui/home.tscn"

var selected_league := "daily"
var mode := "level"  # "level" o "daily"
var level := 1
var daily_key := ""
var lives := MAX_LIVES
var hints_used := 0
var mistakes := 0
var elapsed := 0.0
var _baked: Array = []
var _baked_loaded := false


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
var _mutex := Mutex.new()      # protege la caché de tableros
var _gen_mutex := Mutex.new()  # una sola generación a la vez (ver generate_locked)
var _thread: Thread
var _prefetching := -1


func puzzle() -> Dictionary:
	if mode == "daily":
		return puzzle_for_daily(daily_key)
	return puzzle_for_level(level)


func puzzle_for_level(n: int) -> Dictionary:
	var key := "L%d" % n
	_mutex.lock()
	var cached: Dictionary = _cache.get(key, {})
	_mutex.unlock()
	if not cached.is_empty():
		return cached
	if _prefetching == n and _thread and _thread.is_started():
		_thread.wait_to_finish()  # se estaba preparando: esperar a que termine
		_prefetching = -1
		_mutex.lock()
		cached = _cache.get(key, {})
		_mutex.unlock()
		if not cached.is_empty():
			return cached
	var p := make_level(n)
	_store(key, p)
	return p


## Nivel n: el horneado si existe (fijo para siempre); si no, generado por su semilla.
func make_level(n: int) -> Dictionary:
	_mutex.lock()
	if not _baked_loaded:
		_baked = Baked.load_all()
		_baked_loaded = true
	var blk: PackedByteArray = _baked[n - 1] if n >= 1 and n <= _baked.size() else PackedByteArray()
	_mutex.unlock()
	if not blk.is_empty():
		return Baked.decode(blk)
	return generate_locked(Levels.seed_for(n), Levels.params_for(n))


## El generador no admite dos ejecuciones simultáneas (comparte estado interno y el resultado
## cambiaría según el momento), así que TODAS las generaciones pasan por este candado: la
## precarga en segundo plano y la del hilo principal nunca se solapan.
func generate_locked(seed_value: int, params: Dictionary) -> Dictionary:
	_gen_mutex.lock()
	var p := Arrows.generate(seed_value, params)
	_gen_mutex.unlock()
	return p


func _store(key: String, p: Dictionary) -> void:
	_mutex.lock()
	if _cache.size() > 6:
		_cache.clear()
	_cache[key] = p
	_mutex.unlock()


## Prepara el nivel n en un hilo aparte (para que "Continuar" sea inmediato).
func prefetch(n: int) -> void:
	_mutex.lock()
	var has := _cache.has("L%d" % n)
	_mutex.unlock()
	if has or (_thread and _thread.is_started()):
		return
	_prefetching = n
	_thread = Thread.new()
	_thread.start(func():
		var p := make_level(n)
		_store("L%d" % n, p))


func _process(_d: float) -> void:
	# Recoger el hilo de precarga cuando termina.
	if _thread and _thread.is_started() and not _thread.is_alive():
		_thread.wait_to_finish()
		_prefetching = -1


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func puzzle_for_daily(key: String) -> Dictionary:
	var k := "D" + key
	_mutex.lock()
	var cached: Dictionary = _cache.get(k, {})
	_mutex.unlock()
	if cached.is_empty():
		cached = generate_locked(Daily.seed_for(key), Daily.params_for(key))
		_store(k, cached)
	return cached


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


func go_leagues(type: String = "") -> void:
	if type != "":
		selected_league = type
	get_tree().change_scene_to_file("res://ui/leagues.tscn")


func go_home() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)

