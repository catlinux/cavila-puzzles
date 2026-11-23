extends Node
## Prueba de humo con los autoloads reales: inicio, partida completa tocando flechas,
## choques, derrota, pistas y reto diario.
## Ejecutar:  godot --headless --path . res://tests/smoke.tscn

const Arrows = preload("res://game/arrows.gd")

var failures := 0
var checks := 0


func _ready() -> void:
	Progress.save_path = "user://smoke_save.json"
	Progress.reset()
	Progress.set_setting("sound", false)
	await _run()
	check(checks >= 30, "el smoke test llegó al final (%d comprobaciones)" % checks)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.json"))
	print("SMOKE: %s (%d comprobaciones)" % ["OK" if failures == 0 else "%d FALLOS" % failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FALLO: ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _spawn(scene: String) -> Node:
	var v: Node = load(scene).instantiate()
	add_child(v)
	await _frames(3)
	return v


func _play(mode: String, n: int = 1, key: String = "") -> Node:
	Game.begin(mode, n, key)
	return await _spawn("res://ui/play.tscn")


func _run() -> void:
	var home = await _spawn("res://ui/home.tscn")
	home._open_settings()
	await _frames(2)
	home._settings._confirm_reset()
	await _frames(2)
	home._settings.queue_free()
	Progress.complete_level(1, 3)
	Progress.reset()
	check(Progress.current_level() == 1 and Progress.total_stars() == 0 and Progress.hints() == 3, "borrar progreso")
	check(Progress.setting("music") == true, "ajuste de música por defecto")
	home.queue_free()
	await _frames(1)

	# Partidas completas: tocar las flechas en el orden del solucionador, por posición en pantalla.
	for lv in [1, 2, 10, 57, 400]:
		var v = await _play("level", lv)
		var sol: Array = Arrows.solve(v.puzzle).order
		check(v.moves_available == Arrows.free_arrows(v.puzzle, {}).size() and v.moves_available > 0, "nivel %d: movimientos posibles al empezar" % lv)
		var ok := true
		for i in sol:
			var cell: Vector2i = v.puzzle.arrows[i].cells[0]
			v._layout()
			var pos: Vector2 = v._origin + (Vector2(cell) + Vector2(0.5, 0.5)) * v._cell
			check(v.arrow_at(pos) == i, "nivel %d: el toque encuentra la flecha %d" % [lv, i])
			if v.tap_arrow(i) != "exit":
				ok = false
			if v.moves_available != Arrows.free_arrows(v.puzzle, v.removed).size():
				ok = false
		check(ok and v.finished and v.won, "nivel %d resuelto" % lv)
		check(Game.lives == 3, "nivel %d sin choques" % lv)
		await get_tree().create_timer(0.8).timeout
		check(v._overlay != null, "nivel %d: aparece el resultado" % lv)
		check(Progress.current_level() == lv + 1 or Progress.current_level() > lv, "nivel %d: progreso guardado" % lv)
		v.queue_free()
		await _frames(1)

	# Choques: tocar flechas bloqueadas resta luces y al tercer choque se pierde.
	var v2 = await _play("level", 300)
	var bumps := 0
	for i in v2.puzzle.arrows.size():
		if not Arrows.can_exit(v2.puzzle, i, Arrows.occupancy(v2.puzzle)):
			check(v2.tap_arrow(i) == "bump", "choque detectado")
			bumps += 1
			if bumps == 3:
				break
	check(bumps == 3 and Game.lives == 0 and v2.finished and not v2.won, "derrota tras 3 choques")
	await get_tree().create_timer(0.9).timeout
	check(v2._overlay != null, "pantalla de derrota")
	v2.queue_free()
	await _frames(1)

	# Pistas: gastan del contador y señalan una flecha que puede salir.
	var v3 = await _play("level", 30)
	var before := Progress.hints()
	v3.use_hint()
	check(Progress.hints() == before - 1, "la pista se descuenta")
	check(v3.hint_arrow >= 0 and Arrows.can_exit(v3.puzzle, v3.hint_arrow, Arrows.occupancy(v3.puzzle, v3.removed)), "la pista señala una flecha libre")
	while Progress.hints() > 0:
		Progress.use_hint()
	v3.use_hint()
	check(Progress.hints() == 0, "sin pistas no se descuenta")
	v3.queue_free()
	await _frames(1)

	# Reto diario.
	var v4 = await _play("daily", 0, "2026-11-23")
	for i in Arrows.solve(v4.puzzle).order:
		v4.tap_arrow(i)
	check(v4.won and Progress.daily_done("2026-11-23"), "reto diario completado")
	await get_tree().create_timer(0.8).timeout
	v4.queue_free()
	await _frames(1)
