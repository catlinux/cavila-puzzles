extends Control
## Selector de nivel: 3 dificultades, niveles ilimitados paginados. Se desbloquea el siguiente
## al completar el anterior.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Registry = preload("res://core/registry.gd")

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
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
	head.add_theme_constant_override("separation", 14)
	vb.add_child(head)
	var back := Kit.button("<", Palette.MUTED, 38)
	back.custom_minimum_size = Vector2(96, 80)
	back.pressed.connect(Game.go_menu)
	head.add_child(back)
	var title := Kit.label(tr(Registry.get_entry(pid).title), 54, Palette.TURQUOISE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Control.new())
	head.get_child(2).custom_minimum_size = Vector2(96, 0)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vb.add_child(tabs)
	for d in 3:
		var b := Kit.button(tr(["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD"][d]), Palette.TURQUOISE, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_diff.bind(d))
		tabs.add_child(b)
		_tabs.append(b)

	_count_label = Kit.label("", 24, Palette.MUTED)
	vb.add_child(_count_label)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_grid)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 14)
	vb.add_child(nav)
	var prev := Kit.button("<", Palette.MUTED, 34)
	prev.custom_minimum_size = Vector2(120, 80)
	prev.pressed.connect(_change_page.bind(-1))
	nav.add_child(prev)
	_page_label = Kit.label("", 28, Palette.MUTED)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_page_label)
	var nxt := Kit.button(">", Palette.MUTED, 34)
	nxt.custom_minimum_size = Vector2(120, 80)
	nxt.pressed.connect(_change_page.bind(1))
	nav.add_child(nxt)
	_refresh()


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
		var b: Button = _tabs[i]
		var on := i == diff
		b.add_theme_stylebox_override("normal", Kit.box(Palette.TURQUOISE_DIM if on else Palette.PANEL, 22, Palette.TURQUOISE, 3))
	for c in _grid.get_children():
		c.queue_free()
	var unlocked := Progress.highest_unlocked(pid, diff)
	_count_label.text = "%s: %d" % [tr("DONE_COUNT"), Progress.done_count(pid, diff)]
	_page_label.text = "%d–%d" % [page * PER_PAGE + 1, (page + 1) * PER_PAGE]
	for i in PER_PAGE:
		var idx := page * PER_PAGE + i
		var done := Progress.is_done(pid, diff, idx)
		var b := Kit.button(str(idx + 1), Palette.TURQUOISE if done else Palette.CORAL, 32)
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if done:
			b.add_theme_stylebox_override("normal", Kit.box(Palette.TURQUOISE_DIM, 22, Palette.TURQUOISE, 3))
		if idx > unlocked:
			b.disabled = true
		else:
			b.pressed.connect(Game.start_level.bind(pid, diff, idx))
		_grid.add_child(b)
