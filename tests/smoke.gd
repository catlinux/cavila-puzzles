extends Node
## Prueba de humo de la interfaz: instancia cada escena con los autoloads reales, simula
## entradas y comprueba que se pueden resolver.
## Ejecutar:  godot --headless --path . res://tests/smoke.tscn
## (busca "SCRIPT ERROR" en la salida además del código de salida).

const PiezasLogic = preload("res://puzzles/piezas/piezas_logic.gd")

var failures := 0
var checks := 0


func _ready() -> void:
	await _run()
	print("SMOKE: %s (%d comprobaciones)" % ["OK" if failures == 0 else "%d FALLOS" % failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FALLO: ", msg)


func _spawn(pid: String, diff: int, idx: int) -> Node:
	var Registry = load("res://core/registry.gd")
	Game.begin(pid, diff, idx)
	var v: Node = load(Registry.get_entry(pid).scene).instantiate()
	add_child(v)
	for i in 4:
		await get_tree().process_frame
	return v


func _run() -> void:
	# Menús.
	for scn in ["res://ui/main_menu.tscn", "res://ui/level_select.tscn", "res://ui/victory.tscn"]:
		Game.selected_puzzle = "circuito"
		Game.last_result = {"won": true, "time": 65.0, "lives": 2, "hints": 1}
		var m: Node = load(scn).instantiate()
		add_child(m)
		for i in 3:
			await get_tree().process_frame
		m.queue_free()
		print("  escena ok: ", scn)

	await _pointer_tests()
	for diff in 3:
		# Circuito: reproducir la solución del solver nodo a nodo.
		var v = await _spawn("circuito", diff, 0)
		check(not v.puzzle.is_empty(), "circuito genera d%d" % diff)
		var sol: Array = v.logic.solve(v.puzzle).solution
		for n in sol.slice(1):
			v.step_to(n)
		check(v.finished, "circuito resuelto d%d" % diff)
		v.queue_free()
		await get_tree().process_frame

		# Circuito: un movimiento ilegal cuesta una vida y una pista funciona.
		v = await _spawn("circuito", diff, 1)
		var before := Game.lives
		for ei in v.puzzle.edges.size():
			var e: Dictionary = v.puzzle.edges[ei]
			if e.kind == 1 and (e.a == v.puzzle.start or e.b == v.puzzle.start):
				var other: int = e.b if e.a == v.puzzle.start else e.a
				if not v.logic.can_pass(v.puzzle, ei, v.puzzle.start, other, 0):
					v.step_to(other)
					break
		if v.puzzle.edges.any(func(e): return e.kind == 1 and e.b == v.puzzle.start and (e.grp < 0)):
			check(Game.lives < before, "diodo al revés resta vida d%d" % diff)
		v._on_hint_pressed()
		check(Game.hints_left == Game.MAX_HINTS - 1 and v.hint_node >= 0, "pista circuito d%d" % diff)
		v.queue_free()
		await get_tree().process_frame

		# Sendero.
		v = await _spawn("sendero", diff, 0)
		check(not v.puzzle.is_empty(), "sendero genera d%d" % diff)
		for n in v.puzzle.planted.slice(1):
			v.step_to(n)
		check(v.finished, "sendero resuelto d%d" % diff)
		v.queue_free()
		await get_tree().process_frame
		v = await _spawn("sendero", diff, 2)
		v._on_hint_pressed()
		check(v.hint_cell >= 0, "pista sendero d%d" % diff)
		v.queue_free()
		await get_tree().process_frame

		# Piezas: colocar el teselado plantado.
		v = await _spawn("piezas", diff, 0)
		check(not v.puzzle.is_empty(), "piezas genera d%d" % diff)
		var by_piece := {}
		for pl in v.puzzle.planted:
			by_piece[pl.piece] = pl.cells
		for i in v.pieces.size():
			var cells: Array = by_piece[i]
			var mn := Vector2i(1000, 1000)
			for c in cells:
				mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			# Girar hasta que coincida con la forma plantada.
			var want: Array = PiezasLogic.rotate_cells(cells, 0)
			var tries := 0
			while str(v.pieces[i].cells) != str(want) and tries < 4:
				v.rotate_piece(i)
				tries += 1
			check(v.place_piece(i, mn), "colocar pieza %d d%d" % [i, diff])
		check(v.finished, "piezas resuelto d%d" % diff)
		v.queue_free()
		await get_tree().process_frame
		v = await _spawn("piezas", diff, 1)
		v._on_hint_pressed()
		check(not v.hint.is_empty(), "pista piezas d%d" % diff)
		v.queue_free()
		await get_tree().process_frame


func _mouse(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	return e


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


## Resuelve con eventos de ratón reales (arrastre), para cubrir la entrada de cada vista.
func _pointer_tests() -> void:
	var v = await _spawn("circuito", 0, 5)
	var sol: Array = v.logic.solve(v.puzzle).solution
	v._layout()
	v._board_input(_mouse(true, v._np(sol[0])))
	for n in sol.slice(1):
		v._board_input(_motion(v._np(n)))
	v._board_input(_mouse(false, v._np(sol.back())))
	check(v.finished and v.path == sol, "circuito resuelto arrastrando")
	v.queue_free()
	await get_tree().process_frame

	v = await _spawn("sendero", 0, 5)
	var pl: Array = v.puzzle.planted
	v._layout()
	v._board_input(_mouse(true, v._cell_center(pl[0])))
	for n in pl.slice(1):
		v._board_input(_motion(v._cell_center(n)))
	check(v.finished and v.path == pl, "sendero resuelto arrastrando")
	v.queue_free()
	await get_tree().process_frame

	# Deshacer arrastrando hacia atrás y vida perdida al exceder una pista.
	v = await _spawn("sendero", 0, 6)
	pl = v.puzzle.planted
	v._layout()
	v._board_input(_mouse(true, v._cell_center(pl[0])))
	v._board_input(_motion(v._cell_center(pl[1])))
	v._board_input(_motion(v._cell_center(pl[2])))
	v._board_input(_motion(v._cell_center(pl[1])))
	check(v.path == [pl[0], pl[1]], "arrastrar atrás deshace")
	v.queue_free()
	await get_tree().process_frame

	v = await _spawn("piezas", 0, 5)
	v._layout()
	# Tocar una pieza de la bandeja la gira.
	var rot_before: int = v.pieces[0].rot
	var rect: Rect2 = v._piece_rect(0)
	v._board_input(_mouse(true, rect.get_center()))
	v._board_input(_mouse(false, rect.get_center()))
	check(v.pieces[0].rot == (rot_before + 1) % 4, "tocar gira la pieza")
	# Arrastrar la primera pieza a su sitio del teselado plantado.
	var by := {}
	for pl2 in v.puzzle.planted:
		by[pl2.piece] = pl2.cells
	for i in v.pieces.size():
		var cells: Array = by[i]
		var mn := Vector2i(1000, 1000)
		for c in cells:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		var tries := 0
		while str(v.pieces[i].cells) != str(PiezasLogic.rotate_cells(cells, 0)) and tries < 4:
			v.rotate_piece(i)
			tries += 1
		v._layout()
		var start: Vector2 = v._piece_rect(i).get_center()
		v._board_input(_mouse(true, start))
		var off: Vector2 = v.drag_off
		# Posición del puntero que deja la esquina de la pieza sobre la casilla mn (compensando el "lift").
		var target: Vector2 = v.origin + Vector2(mn) * v.cs + off + Vector2(0, v.cs * 0.8)
		v._board_input(_motion(start + Vector2(30, 0)))
		v._board_input(_motion(target))
		v._board_input(_mouse(false, target))
	check(v.finished, "piezas resuelto arrastrando")
	v.queue_free()
	await get_tree().process_frame
