extends RefCounted
## Iconos de los tipos de puzle, dibujados solo con formas (sin imágenes externas).

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")


static func draw(ci: CanvasItem, id: String, rect: Rect2, accent: Color, alt: Color) -> void:
	var c := rect.get_center()
	var u := minf(rect.size.x, rect.size.y) / 6.0  # unidad
	match id:
		"circuito":
			var pts := [Vector2(-2, 2), Vector2(-2, 0), Vector2(0, 0), Vector2(0, -2), Vector2(2, -2)]
			for i in pts.size() - 1:
				ci.draw_line(c + pts[i] * u, c + pts[i + 1] * u, accent, u * 0.45, true)
			for p in pts:
				ci.draw_circle(c + p * u, u * 0.4, accent)
			ci.draw_circle(c + Vector2(2, -2) * u, u * 0.62, alt)
			var m := c + Vector2(-1, 0) * u
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0.5, 0) * u, m + Vector2(-0.3, -0.5) * u, m + Vector2(-0.3, 0.5) * u]), alt)
		"sendero":
			for gy in 3:
				for gx in 3:
					var r := Rect2(c + Vector2(gx - 1.5, gy - 1.5) * u * 1.6, Vector2(u * 1.4, u * 1.4))
					ci.draw_rect(r, Palette.PANEL_HI)
			ci.draw_rect(Rect2(c + Vector2(0.1, -1.5) * u * 1.6, Vector2(u * 1.4, u * 1.4)), alt.darkened(0.3))
			var path := [Vector2(-1, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]
			for i in path.size() - 1:
				ci.draw_line(c + path[i] * u * 1.6, c + path[i + 1] * u * 1.6, accent, u * 0.5, true)
		"piezas":
			var cells := {accent: [Vector2(-2, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)],
				alt: [Vector2(0, -1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]}
			for col in cells:
				for q in cells[col]:
					ci.draw_rect(Rect2(c + q * u * 1.2 + Vector2(-0.6, -0.6) * u, Vector2(1.1, 1.1) * u), col)
		"binario":
			Kit.text_at(ci, c + Vector2(-1.3, 0) * u, "0", int(u * 3.2), accent)
			Kit.text_at(ci, c + Vector2(1.3, 0) * u, "1", int(u * 3.2), alt)
		"desigualdades":
			for gx in 3:
				ci.draw_rect(Rect2(c + Vector2(gx * 1.9 - 3.1, -0.9) * u, Vector2(1.6, 1.8) * u), Palette.PANEL_HI)
			Kit.text_at(ci, c + Vector2(-1.15, 0) * u, "<", int(u * 1.6), accent)
			Kit.text_at(ci, c + Vector2(0.75, 0) * u, ">", int(u * 1.6), alt)
		"mosaico":
			for gy in 4:
				for gx in 4:
					var on := (gx + gy * 2) % 3 != 0
					ci.draw_rect(Rect2(c + Vector2(gx - 2, gy - 2) * u * 0.95 + Vector2(0.05, 0.05) * u, Vector2(0.85, 0.85) * u), accent if on else Palette.PANEL_HI)
		"enlaces":
			ci.draw_line(c + Vector2(-2, 1.5) * u, c + Vector2(2, -1.5) * u, accent, u * 0.4, true)
			ci.draw_circle(c + Vector2(-2, 1.5) * u, u * 0.6, accent)
			ci.draw_circle(c + Vector2(2, -1.5) * u, u * 0.6, accent)
			ci.draw_circle(c + Vector2(-2, -1.5) * u, u * 0.6, alt)
			ci.draw_circle(c + Vector2(2, 1.5) * u, u * 0.6, alt)
		"apagon":
			ci.draw_circle(c, u * 1.5, accent)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * u * 2.0, c + Vector2(cos(a), sin(a)) * u * 2.7, alt, u * 0.3, true)
		"secuencia":
			var cols := [accent, alt, Palette.GOLD, Palette.VIOLET]
			for i in 4:
				ci.draw_rect(Rect2(c + Vector2(i % 2 - 1, i / 2 - 1) * u * 1.7 + Vector2(0.1, 0.1) * u, Vector2(1.5, 1.5) * u), cols[i])
		_:
			Kit.text_at(ci, c, "?", int(u * 3), accent)
