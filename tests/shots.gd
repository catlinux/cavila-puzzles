extends Node
## Genera capturas PNG de las pantallas (necesita render: xvfb-run, sin --headless).
## Uso: xvfb-run -a godot --path . res://tests/shots.tscn -- <carpeta_salida>

func _ready() -> void:
	var out := "user://shots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(720, 1280)
	await _shot("res://ui/main_menu.tscn", out + "/menu.png")
	Game.selected_puzzle = "sendero"
	await _shot("res://ui/level_select.tscn", out + "/niveles.png")
	for pid in ["circuito", "sendero", "piezas"]:
		for diff in [0, 2]:
			Game.begin(pid, diff, 3)
			var Registry = load("res://core/registry.gd")
			var v = await _shot(Registry.get_entry(pid).scene, "%s/%s_%d.png" % [out, pid, diff], 0.9, true)
	Game.last_result = {"won": true, "time": 83.0, "lives": 2, "hints": 1}
	await _shot("res://ui/victory.tscn", out + "/victoria.png")
	get_tree().quit()


func _shot(scene: String, file: String, wait := 0.3, hint := false) -> Node:
	var n: Node = load(scene).instantiate()
	add_child(n)
	await get_tree().create_timer(wait).timeout
	if hint and n.has_method("_on_hint_pressed"):
		n._on_hint_pressed()
		await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
	n.queue_free()
	await get_tree().process_frame
	return n
