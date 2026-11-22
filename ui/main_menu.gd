extends Control
## Menú principal: puzle diario + cuadrícula con los tipos de puzle.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Registry = preload("res://core/registry.gd")
const Daily = preload("res://core/daily.gd")
const Tile = preload("res://ui/puzzle_tile.gd")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 52)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 22)
	scroll.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Kit.label("Cavila", 84, Palette.TURQUOISE, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var lang := Kit.button(tr("LANG_NAME"), Palette.CORAL, 28)
	lang.custom_minimum_size = Vector2(100, 70)
	lang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lang.pressed.connect(func():
		Game.toggle_language()
		get_tree().reload_current_scene())
	head.add_child(lang)

	var key := Daily.today_key()
	var dpid := Daily.puzzle_for(key)
	var done := Progress.daily_done(key)
	var daily := Kit.button("%s · %s" % [tr("MENU_DAILY"), tr(Registry.get_entry(dpid).title)], Palette.CORAL, 34)
	daily.custom_minimum_size = Vector2(0, 120)
	if done:
		daily.text += "\n" + tr("DAILY_DONE")
	daily.pressed.connect(Game.start_daily)
	vb.add_child(daily)

	vb.add_child(Kit.label(tr("MENU_PICK"), 28, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	vb.add_child(grid)
	for e in Registry.all():
		var t := Tile.new()
		t.puzzle_id = e.id
		t.title = tr(e.title)
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
