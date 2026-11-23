extends Control
## Menú principal: logo, puzle diario y cuadrícula con los tipos de puzle.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Registry = preload("res://core/registry.gd")
const Daily = preload("res://core/daily.gd")
const Tile = preload("res://ui/puzzle_tile.gd")
const Icons = preload("res://ui/puzzle_icons.gd")
const Backdrop = preload("res://ui/backdrop.gd")


func _ready() -> void:
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 48)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 24)
	scroll.add_child(vb)

	# Cabecera: marca + idioma.
	var head := HBoxContainer.new()
	vb.add_child(head)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(96, 96)
	logo.draw.connect(_draw_logo.bind(logo))
	head.add_child(logo)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -4)
	names.add_child(Kit.label("Cavila", 70, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	names.add_child(Kit.label(tr("TAGLINE"), 24, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(names)
	var lang := Kit.button(tr("LANG_NAME"), Palette.CORAL, 26)
	lang.custom_minimum_size = Vector2(96, 64)
	lang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lang.pressed.connect(func():
		Game.toggle_language()
		get_tree().reload_current_scene())
	head.add_child(lang)

	# Puzle diario.
	var key := Daily.today_key()
	var dpid := Daily.puzzle_for(key)
	var done := Progress.daily_done(key)
	var daily := Control.new()
	daily.custom_minimum_size = Vector2(0, 176)
	daily.mouse_filter = Control.MOUSE_FILTER_PASS
	daily.draw.connect(_draw_daily.bind(daily, dpid, done))
	daily.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			Game.start_daily())
	vb.add_child(daily)

	vb.add_child(Kit.label(tr("MENU_PICK"), 26, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for e in Registry.all():
		var t := Tile.new()
		t.puzzle_id = e.id
		t.title = tr(e.title)
		t.done = Progress.total_done(e.id)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(Game.go_levels.bind(e.id))
		grid.add_child(t)
	for e in Registry.UPCOMING:
		var t := Tile.new()
		t.puzzle_id = e.id
		t.title = tr(e.title)
		t.locked = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	Kit.fade_in(self)


## Marca: un camino con nodos (chispa) sobre una placa redondeada.
func _draw_logo(c: Control) -> void:
	var r := Rect2(Vector2(4, 4), c.size - Vector2(8, 8))
	Kit.card(c, r, 26, Palette.CARD_TOP, Palette.CARD_BOTTOM, Palette.TURQUOISE_DIM, 2.5)
	var pts := [Vector2(0.22, 0.74), Vector2(0.22, 0.46), Vector2(0.5, 0.46), Vector2(0.5, 0.24), Vector2(0.78, 0.24)]
	for i in pts.size() - 1:
		Kit.glow_line(c, r.position + pts[i] * r.size, r.position + pts[i + 1] * r.size, Palette.TURQUOISE, 5.0)
	c.draw_circle(r.position + pts[0] * r.size, 8, Palette.TURQUOISE)
	var end: Vector2 = r.position + pts[4] * r.size
	Kit.glow_circle(c, end, 8, Palette.CORAL, 0.18)
	c.draw_circle(end, 9, Palette.CORAL)


func _draw_daily(c: Control, pid: String, done: bool) -> void:
	var r := Rect2(Vector2(2, 2), c.size - Vector2(4, 12))
	Kit.card(c, r, 30, Color8(78, 40, 46), Color8(44, 28, 38), Palette.CORAL, 2.5)
	Kit.glow_circle(c, Vector2(r.end.x - 110, r.get_center().y), 60, Palette.CORAL, 0.07)
	Icons.draw(c, pid, Rect2(Vector2(r.end.x - 210, r.position.y + 10), Vector2(200, r.size.y - 20)), Palette.CORAL_LIGHT, Palette.TURQUOISE)
	Kit.text_left(c, Vector2(r.position.x + 32, r.position.y + 40), tr("MENU_DAILY").to_upper(), 22, Palette.CORAL_LIGHT, true)
	Kit.text_left(c, Vector2(r.position.x + 32, r.position.y + 92), tr(Registry.get_entry(pid).title), 44, Palette.TEXT, true)
	if done:
		var p := r.position + Vector2(36, 136)
		c.draw_polyline(PackedVector2Array([p, p + Vector2(7, 7), p + Vector2(19, -8)]), Palette.TURQUOISE, 4.0, true)
		Kit.text_left(c, p + Vector2(30, 0), tr("DAILY_DONE"), 22, Palette.TURQUOISE, true)
	else:
		Kit.text_left(c, r.position + Vector2(32, 136), tr("DAILY_SUB"), 22, Palette.MUTED)
