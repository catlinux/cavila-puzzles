extends "res://core/puzzle_base.gd"
## Vista de Piezas. Arrastra piezas de la bandeja a la silueta; toca una pieza de la bandeja
## para girarla; toca una pieza ya colocada para devolverla a la bandeja. Aquí no hay vidas.

const Logic = preload("res://puzzles/piezas/piezas_logic.gd")

var w := 0
var h := 0
var pieces: Array = []  # {id, base, rot, cells, placed, origin(Vector2i), pos(Vector2), color}
var cs := 60.0
var tcs := 40.0
var origin := Vector2.ZERO
var drag := -1
var drag_pos := Vector2.ZERO
var drag_off := Vector2.ZERO
var press_pos := Vector2.ZERO
var moved := false
var hint := {}
var hint_until := 0


func _init() -> void:
	uses_lives = false


func _setup() -> void:
	w = puzzle.w
	h = puzzle.h
	for p in puzzle.pieces:
		pieces.append({"id": p.id, "base": p.cells, "rot": p.rot0, "cells": Logic.rotate_cells(p.cells, p.rot0),
			"placed": false, "origin": Vector2i.ZERO, "pos": Vector2.ZERO, "color": Palette.PIECE_COLORS[p.color]})
	content.draw.connect(_draw_board)
	content.gui_input.connect(_board_input)
	content.resized.connect(content.queue_redraw)
	content.queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	if not hint.is_empty():
		if Time.get_ticks_msec() > hint_until:
			hint = {}
		if _playing:
			content.queue_redraw()


# --- Geometría --------------------------------------------------------------------

func _layout() -> void:
	var s := content.size
	var board_h := s.y * 0.54
	cs = minf(minf((s.x - 32.0) / w, (board_h - 16.0) / h), 96.0)
	origin = Vector2((s.x - cs * w) / 2.0, (board_h - cs * h) / 2.0)
	var top := board_h + 8.0
	tcs = minf(cs * 0.8, 60.0)
	while tcs > 14.0:
		if _flow(tcs, s.x, top, s.y - top - 4.0):
			break
		tcs -= 2.0


func _flow(t: float, width: float, top: float, height: float) -> bool:
	var x := 12.0
	var y := top
	var row_h := 0.0
	for p in pieces:
		if p.placed:
			continue
		var b := Logic.bounds(p.cells)
		var pw := b.x * t
		if x + pw > width - 12.0 and x > 12.0:
			x = 12.0
			y += row_h + 16.0
			row_h = 0.0
		p.pos = Vector2(x, y)
		x += pw + 16.0
		row_h = maxf(row_h, b.y * t)
	return y + row_h <= top + height


func _piece_rect(i: int) -> Rect2:
	var p: Dictionary = pieces[i]
	return Rect2(p.pos, Vector2(Logic.bounds(p.cells)) * tcs).grow(8.0)


## Casilla del tablero en la que cae la esquina superior izquierda de la pieza arrastrada.
func _snap_origin() -> Vector2i:
	var tl := drag_pos - drag_off - Vector2(0, cs * 0.8)
	return Vector2i(((tl - origin) / cs).round())


func _fits(i: int, o: Vector2i) -> bool:
	for c in pieces[i].cells:
		var x: int = c.x + o.x
		var y: int = c.y + o.y
		if x < 0 or y < 0 or x >= w or y >= h or not puzzle.cells[y * w + x]:
			return false
		for j in pieces.size():
			if j != i and pieces[j].placed:
				for d in pieces[j].cells:
					if d + pieces[j].origin == Vector2i(x, y):
						return false
	return true


# --- Entrada ----------------------------------------------------------------------

func _board_input(ev: InputEvent) -> void:
	if finished or puzzle.is_empty():
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press(ev.position)
		else:
			_release()
	elif ev is InputEventMouseMotion and drag >= 0:
		drag_pos = ev.position
		if drag_pos.distance_to(press_pos) > 12.0:
			moved = true
		content.queue_redraw()


func _press(pos: Vector2) -> void:
	_layout()
	press_pos = pos
	moved = false
	drag = -1
	# ¿Pieza colocada en el tablero?
	var bc := Vector2i(((pos - origin) / cs).floor())
	for i in pieces.size():
		if pieces[i].placed:
			for c in pieces[i].cells:
				if c + pieces[i].origin == bc:
					pieces[i].placed = false
					drag = i
					drag_off = pos - (origin + Vector2(pieces[i].origin) * cs)
					break
		if drag >= 0:
			break
	if drag < 0:
		for i in pieces.size():
			if not pieces[i].placed and _piece_rect(i).has_point(pos):
				drag = i
				drag_off = (pos - pieces[i].pos) * (cs / tcs)
	drag_pos = pos
	content.queue_redraw()


func _release() -> void:
	if drag < 0:
		return
	var i := drag
	drag = -1
	if moved:
		var o := _snap_origin()
		if _fits(i, o):
			pieces[i].placed = true
			pieces[i].origin = o
			hint = {}
			_check_win()
	elif not pieces[i].placed:
		rotate_piece(i)  # toque: girar
	content.queue_redraw()


func rotate_piece(i: int) -> void:
	pieces[i].rot = (pieces[i].rot + 1) % 4
	pieces[i].cells = Logic.rotate_cells(pieces[i].base, pieces[i].rot)


## Coloca la pieza i en la casilla o del tablero si cabe (público para tests).
func place_piece(i: int, o: Vector2i) -> bool:
	if not _fits(i, o):
		return false
	pieces[i].placed = true
	pieces[i].origin = o
	_check_win()
	return true


func _placements() -> Array:
	var out := []
	for i in pieces.size():
		if pieces[i].placed:
			var cells := []
			for c in pieces[i].cells:
				cells.append(c + pieces[i].origin)
			out.append({"piece": i, "cells": cells})
	return out


func _check_win() -> void:
	if logic.validate(puzzle, _placements()).complete:
		solved()


func _give_hint() -> bool:
	var r: Dictionary = logic.solve(puzzle, 1, _placements())
	if not r.solvable:
		for p in pieces:
			p.placed = false
		r = logic.solve(puzzle, 1, [])
		if not r.solvable:
			return false
	for pl in r.solution:
		if not pieces[pl.piece].placed:
			hint = {"piece": pl.piece, "cells": pl.cells}
			break
	hint_until = Time.get_ticks_msec() + 3500
	content.queue_redraw()
	return not hint.is_empty()


# --- Dibujo -----------------------------------------------------------------------

## Pieza con relieve: degradado por casilla, contorno exterior y brillo en los bordes libres.
func _draw_piece(c: Control, cells: Array, top_left: Vector2, size: float, col: Color, alpha := 1.0, shadow := false) -> void:
	var set := {}
	for q in cells:
		set[Vector2i(q)] = true
	if shadow:
		for q in cells:
			var sr := Rect2(top_left + Vector2(q) * size + Vector2(5, 11), Vector2(size, size))
			c.draw_rect(sr, Color(0, 0, 0, 0.28))
	var top_c := Color(col.lightened(0.2), alpha)
	var bot_c := Color(col.darkened(0.15), alpha)
	for q in cells:
		var r := Rect2(top_left + Vector2(q) * size, Vector2(size, size))
		c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([top_c, top_c, bot_c, bot_c]))
	var edge := Color(col.darkened(0.55), alpha)
	var hi := Color(1, 1, 1, 0.38 * alpha)
	for q in cells:
		var v: Vector2i = q
		var r := Rect2(top_left + Vector2(v) * size, Vector2(size, size))
		if not set.has(v + Vector2i(0, -1)):
			c.draw_line(r.position, Vector2(r.end.x, r.position.y), edge, 3.0)
			c.draw_line(r.position + Vector2(5, 5), Vector2(r.end.x - 5, r.position.y + 5), hi, 2.0, true)
		if not set.has(v + Vector2i(0, 1)):
			c.draw_line(Vector2(r.position.x, r.end.y), r.end, edge, 3.0)
		if not set.has(v + Vector2i(-1, 0)):
			c.draw_line(r.position, Vector2(r.position.x, r.end.y), edge, 3.0)
			c.draw_line(r.position + Vector2(5, 5), Vector2(r.position.x + 5, r.end.y - 5), hi, 2.0, true)
		if not set.has(v + Vector2i(1, 0)):
			c.draw_line(Vector2(r.end.x, r.position.y), r.end, edge, 3.0)


func _draw_board() -> void:
	if puzzle.is_empty():
		return
	var c := content
	_layout()
	# Silueta: huecos hundidos.
	for i in w * h:
		if puzzle.cells[i]:
			var r := Rect2(origin + Vector2(i % w, i / w) * cs, Vector2(cs, cs)).grow(-1.5)
			var pts := Kit.rounded_points(r, cs * 0.12, 4)
			c.draw_colored_polygon(pts, Color8(12, 17, 25))
			var line := pts.duplicate()
			line.append(pts[0])
			c.draw_polyline(line, Color8(54, 69, 90), 2.0, true)
	for i in pieces.size():
		if pieces[i].placed:
			_draw_piece(c, pieces[i].cells, origin + Vector2(pieces[i].origin) * cs, cs, pieces[i].color)
	if not hint.is_empty():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		for q in hint.cells:
			var gr := Rect2(origin + Vector2(q) * cs, Vector2(cs, cs)).grow(-3.0)
			c.draw_rect(gr, Color(Palette.GOLD, 0.18 + 0.25 * pulse))
			c.draw_rect(gr, Palette.GOLD, false, 3.0)
	# Bandeja.
	var sep := origin.y * 2.0 + cs * h + 4.0
	var tray := Rect2(Vector2(10, sep + 4), Vector2(c.size.x - 20, c.size.y - sep - 16))
	Kit.card(c, tray, 24, Color8(16, 22, 31), Color8(13, 18, 26), Color8(45, 58, 77), 1.5, false)
	for i in pieces.size():
		if pieces[i].placed or i == drag:
			continue
		_draw_piece(c, pieces[i].cells, pieces[i].pos, tcs, pieces[i].color)
		if not hint.is_empty() and hint.piece == i:
			var hr := _piece_rect(i)
			var hp := Kit.rounded_points(hr, 12.0, 4)
			hp.append(hp[0])
			c.draw_polyline(hp, Palette.GOLD, 3.0, true)
	# Pieza arrastrada con vista previa del encaje y sombra.
	if drag >= 0:
		var o := _snap_origin()
		if moved and _fits(drag, o):
			for q in pieces[drag].cells:
				var pr := Rect2(origin + Vector2(Vector2i(q) + o) * cs, Vector2(cs, cs)).grow(-2.0)
				c.draw_rect(pr, Color(Palette.TURQUOISE, 0.22))
				c.draw_rect(pr, Palette.TURQUOISE, false, 3.0)
		var tl := drag_pos - drag_off - Vector2(0, cs * 0.8)
		_draw_piece(c, pieces[drag].cells, tl, cs, pieces[drag].color, 0.95, true)
