extends Node
## Genera capturas PNG (necesita render: xvfb-run, sin --headless).
## Uso: xvfb-run -a godot --path . res://tests/shots.tscn -- <carpeta_salida>

const Arrows = preload("res://game/arrows.gd")


func _ready() -> void:
	var out := "user://shots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(720, 1280)
	Progress.save_path = "user://shots_save.json"
	Progress.reset()
	Progress.set_setting("sound", false)
	for n in range(1, 12):
		Progress.complete_level(n, [3, 2, 3, 1, 3][n % 5])
	Progress.complete_daily("2026-11-22")
	var home = await _shot("res://ui/home.tscn", out + "/inicio.png", 0.6)
	home = load("res://ui/home.tscn").instantiate()
	add_child(home)
	await get_tree().create_timer(0.3).timeout
	home._open_settings()
	await get_tree().create_timer(0.4).timeout
	await _save(out + "/ajustes.png")
	home.queue_free()
	for lv in [1, 12, 45, 140, 900]:
		Game.begin("level", lv)
		var v = load("res://ui/play.tscn").instantiate()
		add_child(v)
		await get_tree().create_timer(0.4).timeout
		# Quitar algunas flechas y dejar una saliendo, para ver el juego en marcha.
		var order: Array = Arrows.solve(v.puzzle).order
		for k in mini(order.size() / 3, 12):
			v.tap_arrow(order[k])
		if lv == 45:
			v.use_hint()
		await get_tree().create_timer(0.08).timeout
		await _save("%s/nivel_%d.png" % [out, lv])
		v.queue_free()
		await get_tree().process_frame
	# Resultado de victoria.
	Game.begin("level", 12)
	var w = load("res://ui/play.tscn").instantiate()
	add_child(w)
	await get_tree().create_timer(0.3).timeout
	for i in Arrows.solve(w.puzzle).order:
		w.tap_arrow(i)
	await get_tree().create_timer(2.0).timeout
	await _save(out + "/victoria.png")
	get_tree().quit()


func _shot(scene: String, file: String, wait := 0.3) -> Node:
	var n: Node = load(scene).instantiate()
	add_child(n)
	await get_tree().create_timer(wait).timeout
	await _save(file)
	n.queue_free()
	await get_tree().process_frame
	return n


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
