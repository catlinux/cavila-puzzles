extends RefCounted
## Banderas dibujadas por código (sin imágenes ni emojis, que no se ven igual en todos los móviles).
## `Flags.draw(canvas, rect, "ES")` dibuja la bandera con un borde blanco fino. Los países válidos son
## los de `game/countries.gd`.

const CODES := ["ES", "MX", "AR", "CO", "CL", "PE", "VE", "EC", "BR", "FR", "DE", "IT", "GB", "PT", "US"]


static func _hbands(c: CanvasItem, r: Rect2, cols: Array, parts: Array) -> void:
	var total := 0.0
	for p in parts:
		total += p
	var y := r.position.y
	for k in cols.size():
		var hh: float = r.size.y * float(parts[k]) / total
		c.draw_rect(Rect2(r.position.x, y, r.size.x, hh + 0.5), cols[k])
		y += hh


static func _vbands(c: CanvasItem, r: Rect2, cols: Array) -> void:
	var w := r.size.x / cols.size()
	for k in cols.size():
		c.draw_rect(Rect2(r.position.x + w * k, r.position.y, w + 0.5, r.size.y), cols[k])


static func draw(c: CanvasItem, r: Rect2, code: String) -> void:
	c.draw_rect(r.grow(2.0), Color.WHITE)  # borde blanco: se lee sobre cualquier fondo
	var ctr := r.get_center()
	match code:
		"ES":
			_hbands(c, r, [Color8(170, 21, 27), Color8(241, 191, 0), Color8(170, 21, 27)], [1, 2, 1])
		"MX":
			_vbands(c, r, [Color8(0, 104, 71), Color.WHITE, Color8(206, 17, 38)])
			c.draw_circle(ctr, r.size.y * 0.18, Color8(150, 110, 60))
		"AR":
			_hbands(c, r, [Color8(116, 172, 223), Color.WHITE, Color8(116, 172, 223)], [1, 1, 1])
			c.draw_circle(ctr, r.size.y * 0.13, Color8(246, 180, 14))
		"CO":
			_hbands(c, r, [Color8(252, 209, 22), Color8(0, 56, 147), Color8(206, 17, 38)], [2, 1, 1])
		"CL":
			_hbands(c, r, [Color.WHITE, Color8(213, 43, 30)], [1, 1])
			var sq := Rect2(r.position, Vector2(r.size.y * 0.5, r.size.y * 0.5))
			c.draw_rect(sq, Color8(0, 57, 166))
			c.draw_circle(sq.get_center(), sq.size.y * 0.2, Color.WHITE)
		"PE":
			_vbands(c, r, [Color8(217, 16, 35), Color.WHITE, Color8(217, 16, 35)])
		"VE":
			_hbands(c, r, [Color8(255, 207, 0), Color8(0, 36, 125), Color8(207, 20, 43)], [1, 1, 1])
		"EC":
			_hbands(c, r, [Color8(255, 221, 0), Color8(3, 78, 162), Color8(237, 28, 36)], [2, 1, 1])
		"BR":
			c.draw_rect(r, Color8(0, 156, 59))
			c.draw_colored_polygon(PackedVector2Array([Vector2(ctr.x, r.position.y + r.size.y * 0.1), Vector2(r.end.x - r.size.x * 0.1, ctr.y),
				Vector2(ctr.x, r.end.y - r.size.y * 0.1), Vector2(r.position.x + r.size.x * 0.1, ctr.y)]), Color8(255, 223, 0))
			c.draw_circle(ctr, r.size.y * 0.22, Color8(0, 39, 118))
		"FR":
			_vbands(c, r, [Color8(0, 85, 164), Color.WHITE, Color8(239, 65, 53)])
		"DE":
			_hbands(c, r, [Color.BLACK, Color8(221, 0, 0), Color8(255, 206, 0)], [1, 1, 1])
		"IT":
			_vbands(c, r, [Color8(0, 146, 70), Color.WHITE, Color8(206, 43, 55)])
		"GB":
			c.draw_rect(r, Color8(1, 33, 105))
			c.draw_line(r.position, r.end, Color.WHITE, r.size.y * 0.26)
			c.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Color.WHITE, r.size.y * 0.26)
			c.draw_line(r.position, r.end, Color8(200, 16, 46), r.size.y * 0.1)
			c.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Color8(200, 16, 46), r.size.y * 0.1)
			c.draw_rect(Rect2(r.position.x, ctr.y - r.size.y * 0.17, r.size.x, r.size.y * 0.34), Color.WHITE)
			c.draw_rect(Rect2(ctr.x - r.size.y * 0.17, r.position.y, r.size.y * 0.34, r.size.y), Color.WHITE)
			c.draw_rect(Rect2(r.position.x, ctr.y - r.size.y * 0.1, r.size.x, r.size.y * 0.2), Color8(200, 16, 46))
			c.draw_rect(Rect2(ctr.x - r.size.y * 0.1, r.position.y, r.size.y * 0.2, r.size.y), Color8(200, 16, 46))
		"PT":
			c.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.4, r.size.y)), Color8(0, 102, 0))
			c.draw_rect(Rect2(r.position.x + r.size.x * 0.4, r.position.y, r.size.x * 0.6 + 0.5, r.size.y), Color8(255, 0, 0))
			c.draw_circle(Vector2(r.position.x + r.size.x * 0.4, ctr.y), r.size.y * 0.2, Color8(255, 221, 0))
		"US":
			for k in 7:
				c.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * k / 7.0, r.size.x, r.size.y / 7.0 + 0.5),
					Color8(178, 34, 52) if k % 2 == 0 else Color.WHITE)
			var cant := Rect2(r.position, Vector2(r.size.x * 0.46, r.size.y * 4.0 / 7.0))
			c.draw_rect(cant, Color8(60, 59, 110))
			for ix in 3:
				for iy in 2:
					c.draw_circle(cant.position + Vector2(cant.size.x * (ix + 0.7) / 3.4, cant.size.y * (iy + 0.8) / 2.6), maxf(1.0, r.size.y * 0.05), Color.WHITE)
		_:
			c.draw_rect(r, Color8(200, 205, 215))
	c.draw_rect(r, Color(0, 0, 0, 0.18), false, 1.0)
