extends RefCounted
## Niveles horneados: los primeros COUNT niveles se guardan ya generados en un fichero, para que
## sean FIJOS (iguales para todos y para siempre, aunque cambie el generador en una
## actualización). Los niveles posteriores se siguen generando por semilla.
##
## Fichero: tamaño sin comprimir (u32) + zstd de var_to_bytes(Array[PackedByteArray]), un bloque por nivel:
##   w, h, depth, nº huecos (2 B), huecos (x, y)..., nº rocas (2 B), rocas (x, y)...,
##   nº flechas (2 B), y por flecha: longitud (2 B), dirección (0..3), casillas (x, y) de cola a cabeza.
## Se regenera con:  godot --headless --path . --script tools/bake_levels.gd

const PATH := "res://game/levels_baked.bin"
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func encode(p: Dictionary) -> PackedByteArray:
	var b := PackedByteArray()
	b.append(int(p.w))
	b.append(int(p.h))
	b.append(clampi(int(p.get("depth", 0)), 0, 255))
	for key in ["holes", "rocks"]:
		var list: Array = p.get(key, [])
		_u16(b, list.size())
		for c in list:
			b.append(c.x)
			b.append(c.y)
	_u16(b, p.arrows.size())
	for a in p.arrows:
		_u16(b, a.cells.size())
		b.append(DIRS.find(a.dir))
		for c in a.cells:
			b.append(c.x)
			b.append(c.y)
	return b


static func decode(b: PackedByteArray) -> Dictionary:
	var p := {"w": b[0], "h": b[1], "depth": b[2], "arrows": [], "holes": [], "rocks": []}
	var k := 3
	for key in ["holes", "rocks"]:
		var n := b[k] * 256 + b[k + 1]
		k += 2
		var list: Array = p[key]
		for _i in n:
			list.append(Vector2i(b[k], b[k + 1]))
			k += 2
	var na := b[k] * 256 + b[k + 1]
	k += 2
	for _i in na:
		var n := b[k] * 256 + b[k + 1]
		var d: Vector2i = DIRS[b[k + 2]]
		k += 3
		var cells := []
		for _j in n:
			cells.append(Vector2i(b[k], b[k + 1]))
			k += 2
		p.arrows.append({"cells": cells, "dir": d})
	return p


static func _u16(b: PackedByteArray, v: int) -> void:
	b.append((v >> 8) & 255)
	b.append(v & 255)


## Lee el fichero: Array de bloques (vacío si no existe).
static func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var raw := FileAccess.get_file_as_bytes(PATH)
	if raw.is_empty():
		return []
	if raw.size() < 4:
		return []
	var size := raw.decode_u32(0)  # tamaño sin comprimir
	var data = bytes_to_var(raw.slice(4).decompress(size, FileAccess.COMPRESSION_ZSTD))
	return data if data is Array else []


static func save_all(blocks: Array) -> int:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var plain := var_to_bytes(blocks)
	f.store_32(plain.size())
	f.store_buffer(plain.compress(FileAccess.COMPRESSION_ZSTD))
	return OK
