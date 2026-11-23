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


func _touch(idx: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = pressed
	e.position = pos
	return e


func _drag(idx: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	return e


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

	# Ligas: pantalla con las tres pestañas y aviso de resultado al terminar una.
	Progress.complete_level(1, 3, 5000)
	var lgs = await _spawn("res://ui/leagues.tscn")
	check(lgs._list.get_child_count() == 20, "clasificación diaria de 20")
	lgs._select("weekly")
	await _frames(2)
	check(lgs._list.get_child_count() == 30, "clasificación semanal de 30")
	lgs._select("flash")
	await _frames(2)
	check(lgs._list.get_child_count() == 15, "clasificación relámpago de 15")
	lgs.queue_free()
	await _frames(1)
	Progress.now_override = Progress.now() + 9 * 86400
	var h2 = await _spawn("res://ui/home.tscn")
	check(Progress.pending_league_results().size() <= 2, "al abrir el inicio se cobra un resultado de liga")
	h2.queue_free()
	await _frames(1)
	Progress.now_override = -1
	Progress.reset()
	Progress.set_setting("sound", false)

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

	# Dedo real: pulsar y soltar sobre una flecha libre la saca; arrastrar no; zoom y desplazamiento.
	var vz = await _play("level", 900)
	var free_i: int = Arrows.free_arrows(vz.puzzle, {})[0]
	vz._layout()
	var pos: Vector2 = vz._origin + (Vector2(vz.puzzle.arrows[free_i].cells[0]) + Vector2(0.5, 0.5)) * vz._cell
	vz._board_input(_touch(0, true, pos))
	vz._board_input(_touch(0, false, pos))
	check(vz.removed.has(free_i), "un toque con el dedo saca la flecha")
	var other: int = Arrows.free_arrows(vz.puzzle, vz.removed)[0]
	var pos2: Vector2 = vz._origin + (Vector2(vz.puzzle.arrows[other].cells[0]) + Vector2(0.5, 0.5)) * vz._cell
	vz._board_input(_touch(0, true, pos2))
	vz._board_input(_drag(0, pos2 + Vector2(120, 0)))
	vz._board_input(_touch(0, false, pos2 + Vector2(120, 0)))
	check(not vz.removed.has(other), "un arrastre no cuenta como toque")
	check(vz._max_zoom() > 1.0, "los tableros grandes permiten zoom")
	var c0: Vector2 = vz.board.size / 2.0
	vz._board_input(_touch(0, true, c0 - Vector2(50, 0)))
	vz._board_input(_touch(1, true, c0 + Vector2(50, 0)))
	vz._board_input(_drag(1, c0 + Vector2(150, 0)))
	check(vz._zoom > 1.5, "pellizcar hace zoom (%.2f)" % vz._zoom)
	vz._board_input(_touch(1, false, c0 + Vector2(150, 0)))
	vz._board_input(_touch(0, false, c0 - Vector2(50, 0)))
	var pan_before: Vector2 = vz._pan
	vz._board_input(_touch(0, true, c0))
	vz._board_input(_drag(0, c0 + Vector2(60, 40)))
	vz._board_input(_touch(0, false, c0 + Vector2(60, 40)))
	check(vz._pan != pan_before, "arrastrar con zoom mueve el tablero")
	check(vz._fit_btn.visible, "aparece el botón de ver todo")
	vz._fit_btn.pressed.emit()
	check(vz._zoom == 1.0 and vz._pan == Vector2.ZERO, "ver todo restablece el zoom")
	vz.queue_free()
	await _frames(1)

	# Tolerancia de toque: entre una flecha que chocaría y otra libre casi igual de cerca,
	# gana la libre; tocar el centro de una bloqueada sigue siendo un choque.
	var vt = await _play("level", 300)
	vt._layout()
	var occ: PackedInt32Array = Arrows.occupancy(vt.puzzle)
	var pair := []
	for i in vt.puzzle.arrows.size():
		if pair.size() > 0:
			break
		if Arrows.can_exit(vt.puzzle, i, occ):
			continue
		for c in vt.puzzle.arrows[i].cells:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if Arrows.inside(vt.puzzle, n):
					var j: int = occ[n.y * vt.puzzle.w + n.x]
					if j >= 0 and j != i and Arrows.can_exit(vt.puzzle, j, occ) and pair.is_empty():
						pair = [i, j, c, n]
	check(not pair.is_empty(), "hay una flecha bloqueada junto a una libre")
	if not pair.is_empty():
		var cb: Vector2 = Vector2(pair[2]) + Vector2(0.5, 0.5)
		var cf: Vector2 = Vector2(pair[3]) + Vector2(0.5, 0.5)
		var edge: Vector2 = vt._origin + cb.lerp(cf, 0.42) * vt._cell  # algo más cerca de la bloqueada
		check(vt.arrow_at(edge) == pair[1], "toque dudoso: se elige la flecha que puede salir")
		var center: Vector2 = vt._origin + cb * vt._cell
		check(vt.arrow_at(center) == pair[0], "toque claro en una bloqueada: cuenta como esa (sin abusos)")
		var far: Vector2 = vt._origin + (cb + Vector2(0, 0) + (cb - cf) * 0.0) * vt._cell
		check(vt.arrow_at(vt._origin + Vector2(-5, -5) * vt._cell) == -1, "tocar fuera del tablero no selecciona nada")
	vt.queue_free()
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
