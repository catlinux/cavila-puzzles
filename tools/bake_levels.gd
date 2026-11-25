extends SceneTree
## Hornea los niveles 1..COUNT en game/levels_baked.bin.
## Uso:  godot --headless --path . --script tools/bake_levels.gd -- [desde] [hasta] [salida_parcial]
## Sin argumentos genera todo. Con rango, guarda un trozo (var_to_bytes) en `salida_parcial`
## para poder hornear en varios procesos a la vez y unirlos con --merge.

const Arrows = preload("res://game/arrows.gd")
const Levels = preload("res://game/levels.gd")
const Baked = preload("res://game/baked.gd")

const COUNT := 1000


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "--merge":
		var all := []
		for k in range(1, args.size()):
			all.append_array(bytes_to_var(FileAccess.get_file_as_bytes(args[k])))
		print("unidos ", all.size(), " niveles: ", Baked.save_all(all))
		quit()
		return
	var a := 1
	var z := COUNT
	if args.size() >= 2:
		a = int(args[0])
		z = int(args[1])
	var blocks := []
	var t0 := Time.get_ticks_msec()
	for n in range(a, z + 1):
		var p: Dictionary = Arrows.generate(Levels.seed_for(n), Levels.params_for(n))
		var s: Dictionary = Arrows.solve(p)
		if not s.solvable:
			push_error("nivel %d sin solución" % n)
			quit(1)
			return
		blocks.append(Baked.encode(p))
		if n % 50 == 0:
			print("nivel ", n, " (", (Time.get_ticks_msec() - t0) / 1000, " s)")
	if args.size() >= 3:
		var f := FileAccess.open(args[2], FileAccess.WRITE)
		f.store_buffer(var_to_bytes(blocks))
		print("trozo ", a, "-", z, " guardado")
	else:
		print("guardado: ", Baked.save_all(blocks))
	quit()
