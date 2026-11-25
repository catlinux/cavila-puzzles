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
	check(lgs._notice.text != "", "aviso en vivo en la pantalla de ligas: " + lgs._notice.text)
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
	# Se ilumina la flecha elegida al apoyar el dedo, el resaltado sigue al dedo y se activa al soltar.
	var fa := -1
	var fb := -1
	for x in Arrows.free_arrows(vz.puzzle, vz.removed):
		var px: Vector2 = vz._origin + (Vector2(vz.puzzle.arrows[x].cells[0]) + Vector2(0.5, 0.5)) * vz._cell
		if vz.arrow_at(px) == x:
			if fa == -1:
				fa = x
			elif fb == -1:
				fb = x
	check(fa != -1 and fb != -1, "hay dos flechas libres distinguibles")
	var pa: Vector2 = vz._origin + (Vector2(vz.puzzle.arrows[fa].cells[0]) + Vector2(0.5, 0.5)) * vz._cell
	var pb: Vector2 = vz._origin + (Vector2(vz.puzzle.arrows[fb].cells[0]) + Vector2(0.5, 0.5)) * vz._cell
	vz._board_input(_touch(0, true, pa))
	check(vz._cand == fa and vz.removed.size() == 1, "al apoyar el dedo se ilumina la flecha y todavía no se activa")
	vz._board_input(_drag(0, pb))
	check(vz._cand == fb, "el resaltado sigue al dedo")
	vz._board_input(_touch(0, false, pb))
	check(vz.removed.has(fb) and not vz.removed.has(fa) and vz._cand == -1, "al soltar se activa la flecha de debajo del dedo")
	# Deslizar a un punto vacío y soltar cancela, sin gastar luz.
	var lives_c: int = Game.lives
	vz._board_input(_touch(0, true, pa))
	vz._board_input(_drag(0, Vector2(-400.0, -400.0)))
	check(vz._cand == -1, "fuera de las flechas no hay candidata")
	vz._board_input(_touch(0, false, Vector2(-400.0, -400.0)))
	check(not vz.removed.has(fa) and Game.lives == lives_c, "soltar en vacío cancela")
	check(vz._max_zoom() > 1.0, "los tableros grandes permiten zoom")
	var c0: Vector2 = vz.board.size / 2.0
	vz._board_input(_touch(0, true, c0 - Vector2(50, 0)))
	vz._board_input(_touch(1, true, c0 + Vector2(50, 0)))
	vz._board_input(_drag(1, c0 + Vector2(150, 0)))
	check(vz._zoom > 1.5, "pellizcar hace zoom (%.2f)" % vz._zoom)
	vz._board_input(_touch(1, false, c0 + Vector2(150, 0)))
	vz._board_input(_touch(0, false, c0 - Vector2(50, 0)))
	var pan_before: Vector2 = vz._pan
	var removed_before: int = vz.removed.size()
	vz._board_input(_touch(0, true, c0))
	vz._board_input(_drag(0, c0 + Vector2(60, 40)))
	check(vz._cand == -1, "al desplazar con zoom no hay candidata")
	vz._board_input(_touch(0, false, c0 + Vector2(60, 40)))
	check(vz._pan != pan_before and vz.removed.size() == removed_before, "arrastrar con zoom mueve el tablero sin activar nada")
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
		var got_a: int = vt.arrow_at(edge)
		var qd: Vector2 = (edge - vt._origin) / vt._cell - Vector2(0.5, 0.5)
		check(got_a == pair[1], "toque dudoso: se elige la flecha que puede salir (nivel=%d modo=%s hash=%d arrows=%d got=%d pair=%s cell=%.1f board=%s d_blq=%.2f d_libre=%.2f d_got=%.2f)" % [
			Game.level, Game.mode, hash(var_to_str(vt.puzzle.arrows)), vt.puzzle.arrows.size(), got_a, str(pair), vt._cell, str(vt.board.size), vt._dist_to_arrow(pair[0], qd), vt._dist_to_arrow(pair[1], qd),
			vt._dist_to_arrow(got_a, qd) if got_a >= 0 else -1.0])
		var center: Vector2 = vt._origin + cb * vt._cell
		check(vt.arrow_at(center) == pair[0], "toque claro en una bloqueada: cuenta como esa (sin abusos)")
		var far: Vector2 = vt._origin + (cb + Vector2(0, 0) + (cb - cf) * 0.0) * vt._cell
		check(vt.arrow_at(vt._origin + Vector2(-5, -5) * vt._cell) == -1, "tocar fuera del tablero no selecciona nada")
	vt.queue_free()
	await _frames(1)

	# Salir al exterior visible (una muesca grande) = salir del tablero: la flecha sale sin perder luz
	# aunque más allá haya otras flechas, y desaparece enseguida. Los huecos de margen se cruzan.
	var found_lv := -1
	var found_i := -1
	var Levels = load("res://game/levels.gd")
	for lv in range(30, 140):
		var par = Levels.params_for(lv)
		if par.holes.is_empty():
			continue
		var pz = Arrows.generate(Levels.seed_for(lv), par)
		var xm = Arrows.exit_mask(pz.w, pz.h, pz.holes)
		var oc = Arrows.occupancy(pz)
		for i in pz.arrows.size():
			var ar = pz.arrows[i]
			var cc = Arrows.head(ar) + ar.dir
			var entered := false
			while Arrows.inside(pz, cc) and found_i == -1:
				if xm[cc.y * pz.w + cc.x] == 1:
					entered = true
				elif entered and oc[cc.y * pz.w + cc.x] >= 0 and Arrows.can_exit(pz, i, oc):
					found_lv = lv
					found_i = i
				cc += ar.dir
			if found_i != -1:
				break
		if found_i != -1:
			break
	check(found_i != -1, "hay un nivel con una flecha que sale al exterior con algo más allá")
	if found_i != -1:
		var vh = await _play("level", found_lv)
		var lives0: int = Game.lives
		check(vh.tap_arrow(found_i) == "exit" and Game.lives == lives0, "la flecha que sale al exterior sale sin chocar")
		check(vh._exit_hole[found_i], "su animación es de salida al exterior")
		await get_tree().create_timer(1.5).timeout
		check(vh._gone.has(found_i), "desaparece enseguida tras salir del tablero")
		vh.queue_free()
		await _frames(1)

	# Determinismo con la precarga en segundo plano: lo que sale de Game es idéntico a generar el
	# nivel en solitario, aunque se solapen la precarga y la generación del hilo principal.
	var Lv = load("res://game/levels.gd")
	var det_bad := 0
	for rep in 12:
		Game._cache.clear()
		Game.prefetch(301)
		var mine: Dictionary = Game.puzzle_for_level(300)  # se solapa con la precarga de 301
		Game.begin("level", 300)  # reutiliza el hilo si sigue vivo
		await _frames(1)
		var solo300 = Game.generate_locked(Lv.seed_for(300), Lv.params_for(300))
		var pre301: Dictionary = Game.puzzle_for_level(301)
		var solo301 = Game.generate_locked(Lv.seed_for(301), Lv.params_for(301))
		if var_to_str(mine.arrows) != var_to_str(solo300.arrows) or var_to_str(pre301.arrows) != var_to_str(solo301.arrows):
			det_bad += 1
	check(det_bad == 0, "los niveles son idénticos con y sin precarga solapada (%d de 12 distintos)" % det_bad)

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

	# Ligas: avatares y nombres únicos y coherentes; texturas disponibles.
	var LG = preload("res://game/leagues.gd")
	var Style = preload("res://ui/style.gd")
	for t in LG.TYPES:
		for k in 6:
			var ids: Array = LG.identities("%s:%d" % [t, k], int(LG.CONFIG[t].size) - 1)
			var av := {}
			var kin := {}
			var nm := {}
			for e in ids:
				av[e.avatar] = true
				kin[LG.AVATAR_KIN[e.avatar]] = true
				nm[e.name] = true
				if LG.AVATAR_KIND[e.avatar] == "f":
					check(not LG.NAMES_M.has(e.name), "avatar femenino sin nombre masculino")
				if LG.AVATAR_KIND[e.avatar] == "m":
					check(not LG.NAMES_F.has(e.name), "avatar masculino sin nombre femenino")
			check(av.size() == ids.size() and nm.size() == ids.size(), "avatares y nombres únicos en %s" % t)
			check(kin.size() == ids.size(), "sin avatares gemelos en %s" % t)
	check(LG.AVATAR_KIND.length() == LG.AVATAR_COUNT and LG.AVATAR_KIN.size() == LG.AVATAR_COUNT, "metadatos de avatares")
	for i in LG.AVATAR_COUNT:
		check(Style.avatar(i) != null, "avatar %d carga" % i)
	for t in LG.TYPES:
		check(Style.league_art(t) != null, "imagen de liga " + t)
	for n in ["trophy", "laurel", "chest", "flag", "popper", "arch", "banner", "stars", "rise", "progress"]:
		check(Style.reward_art(n) != null, "premio " + n)
