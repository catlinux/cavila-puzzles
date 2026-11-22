extends Node
## Autoload "Game": nivel en curso, vidas, pistas, tiempo y navegación entre escenas.

const Rng = preload("res://core/rng.gd")
const Daily = preload("res://core/daily.gd")
const Registry = preload("res://core/registry.gd")
const I18n = preload("res://core/i18n.gd")

const MAX_LIVES := 3
const MAX_HINTS := 3

var puzzle_id := ""
var difficulty := 0
var index := 0
var seed_value := 0
var daily_key := ""  # no vacío si se juega el puzle diario

var lives := MAX_LIVES
var hints_left := MAX_HINTS
var hints_used := 0
var mistakes := 0
var elapsed := 0.0
var last_result: Dictionary = {}

## Selección recordada por el selector de niveles.
var selected_puzzle := ""
var selected_diff := 0


func _ready() -> void:
	I18n.install()
	var lang := Progress.get_language()
	if lang == "":
		lang = I18n.default_language()
	TranslationServer.set_locale(lang)


func toggle_language() -> void:
	var cur := TranslationServer.get_locale().substr(0, 2)
	var nxt := "ca" if cur == "es" else "es"
	TranslationServer.set_locale(nxt)
	Progress.set_language(nxt)


## Prepara el estado de un nivel sin cambiar de escena (útil para tests).
func begin(pid: String, diff: int, idx: int, daily := "") -> void:
	puzzle_id = pid
	difficulty = diff
	index = idx
	daily_key = daily
	seed_value = Daily.seed_for(daily, pid) if daily != "" else Rng.level_seed(pid, diff, idx)
	lives = MAX_LIVES
	hints_left = MAX_HINTS
	hints_used = 0
	mistakes = 0
	elapsed = 0.0


func start_level(pid: String, diff: int, idx: int) -> void:
	begin(pid, diff, idx)
	_open_puzzle()


func start_daily() -> void:
	var key := Daily.today_key()
	begin(Daily.puzzle_for(key), Daily.difficulty_for(key), 0, key)
	_open_puzzle()


func restart() -> void:
	begin(puzzle_id, difficulty, index, daily_key)
	_open_puzzle()


func next_level() -> void:
	start_level(puzzle_id, difficulty, index + 1)


func _open_puzzle() -> void:
	get_tree().change_scene_to_file(Registry.get_entry(puzzle_id).scene)


func finish(won: bool) -> void:
	last_result = {"won": won, "time": elapsed, "lives": lives, "hints": hints_used}
	if won:
		if daily_key != "":
			Progress.mark_daily(daily_key, puzzle_id)
		else:
			Progress.mark_done(puzzle_id, difficulty, index, elapsed, lives)
	get_tree().change_scene_to_file.call_deferred("res://ui/victory.tscn")


func go_menu() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func go_levels(pid: String = "") -> void:
	if pid != "":
		selected_puzzle = pid
	get_tree().change_scene_to_file("res://ui/level_select.tscn")
