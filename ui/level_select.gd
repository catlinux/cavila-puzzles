extends Control
## Selector de nivel: 3 dificultades, niveles ilimitados paginados. Se desbloquea el siguiente
## al completar el anterior.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Registry = preload("res://core/registry.gd")
const Icons = preload("res://ui/puzzle_icons.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const LevelCell = preload("res://ui/level_cell.gd")

const PER_PAGE := 20
const COLS := 4

var pid := ""
var diff := 0
var page := 0
var _grid: GridContainer
var _page_label: Label
var _count_label: Label
var _tabs: Array = []


func _ready() -> void:
	pid = Game.selected_puzzle
	diff = Game.selected_diff
	page = Progress.highest_unlocked(pid, diff) / PER_PAGE
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 48)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	margin.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	var back := Kit.button("<", Palette.MUTED, 38)
	back.custom_minimum_size = Vector2(88, 80)
	back.pressed.connect(Game.go_menu)
	head.add_child(back)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", -2)
	title.add_child(Kit.label(tr(Registry.get_entry(pid).title), 54, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	_count_label = Kit.label("", 24, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	title.add_child(_count_label)
	head.add_child(title)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(120, 80)
	icon.draw.connect(func():
		Kit.glow_circle(icon, icon.size / 2.0, 20, Palette.TURQUOISE, 0.06)
		Icons.draw(icon, pid, Rect2(Vector2.ZERO, icon.size), Palette.TURQUOISE, Palette.CORAL))
	head.add_child(icon)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vb.add_child(tabs)
	for d in 3:
		var b := Kit.button(tr(["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD"][d]), Palette.TURQUOISE, 28)
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_diff.bind(d))
		tabs.add_child(b)
		_tabs.append(b)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_grid)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 14)
	vb.add_child(nav)
	var prev := Kit.button("<", Palette.MUTED, 34)
	prev.custom_minimum_size = Vector2(120, 80)
	prev.pressed.connect(_change_page.bind(-1))
	nav.add_child(prev)
	_page_label = Kit.label("", 28, Palette.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_page_label)
	var nxt := Kit.button(">", Palette.MUTED, 34)
	nxt.custom_minimum_size = Vector2(120, 80)
	nxt.pressed.connect(_change_page.bind(1))
	nav.add_child(nxt)
	_refresh()
	Kit.fade_in(self)


func _set_diff(d: int) -> void:
	diff = d
	Game.selected_diff = d
	page = Progress.highest_unlocked(pid, diff) / PER_PAGE
	_refresh()


func _change_page(delta: int) -> void:
	page = maxi(0, page + delta)
	_refresh()


func _refresh() -> void:
	for i in _tabs.size():
		_tabs[i].apply_style(i == diff)
	for c in _grid.get_children():
		c.queue_free()
		_grid.remove_child(c)
	var unlocked := Progress.highest_unlocked(pid, diff)
	_count_label.text = "%s: %d" % [tr("DONE_COUNT"), Progress.done_count(pid, diff)]
	_page_label.text = "%d – %d" % [page * PER_PAGE + 1, (page + 1) * PER_PAGE]
	for i in PER_PAGE:
		var idx := page * PER_PAGE + i
		var cell := LevelCell.new()
		cell.number = idx + 1
		cell.done = Progress.is_done(pid, diff, idx)
		cell.stars = Progress.get_stars(pid, diff, idx)
		cell.locked = idx > unlocked
		cell.current = idx == unlocked
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not cell.locked:
			cell.pressed.connect(Game.start_level.bind(pid, diff, idx))
		_grid.add_child(cell)
