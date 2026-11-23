extends Control
## Base de todas las escenas de puzle. Se encarga de: fondo, cabecera (volver, título,
## vidas), texto de ayuda, botón de pista, generación del nivel desde la semilla y
## paso a la pantalla de resultado.
##
## Las escenas hijas sobrescriben:
##   _setup()      -> construir la vista usando `puzzle` y `content`
##   _give_hint()  -> true si se dio una pista (consume una de las disponibles)
## y llaman a mistake() / solved() cuando corresponda.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Registry = preload("res://core/registry.gd")
const Backdrop = preload("res://ui/backdrop.gd")

var logic
var puzzle: Dictionary = {}
var uses_lives := true  # las subclases pueden ponerlo a false en _init()
var content: Control
var finished := false

var _hearts: Control
var _hint_btn: Button
var _loading: Label
var _playing := false
var _heart_poly := PackedVector2Array()
var _sub_label: Label
var _sub_text := ""
var _last_sec := -1


func _ready() -> void:
	var entry: Dictionary = Registry.get_entry(Game.puzzle_id)
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 44)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	var back := Kit.button("<", Palette.MUTED, 38)
	back.custom_minimum_size = Vector2(88, 80)
	back.pressed.connect(_on_back)
	top.add_child(back)
	_sub_text = tr("MENU_DAILY") if Game.daily_key != "" else "%s %d · %s" % [
		tr("LEVEL"), Game.index + 1, tr(["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD"][Game.difficulty])]
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -2)
	names.add_child(Kit.label(tr(entry.title), 40, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	_sub_label = Kit.label(_sub_text, 22, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	names.add_child(_sub_label)
	top.add_child(names)
	_hearts = Control.new()
	_hearts.custom_minimum_size = Vector2(160, 80)
	_hearts.visible = uses_lives
	_hearts.draw.connect(_draw_hearts)
	top.add_child(_hearts)

	var help := Kit.label(tr(entry.help), 21, Palette.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(help)

	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	content.draw.connect(_draw_card_bg)  # se conecta antes que el dibujo del puzle
	vb.add_child(content)

	_hint_btn = Kit.button("", Palette.GOLD, 30)
	_hint_btn.custom_minimum_size = Vector2(0, 92)
	_hint_btn.pressed.connect(_on_hint_pressed)
	var bulb := Control.new()
	bulb.set_anchors_preset(Control.PRESET_FULL_RECT)
	bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulb.draw.connect(_draw_bulb.bind(bulb))
	_hint_btn.add_child(bulb)
	vb.add_child(_hint_btn)

	_loading = Kit.label(tr("GENERATING"), 32, Palette.MUTED)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(_loading)
	_update_hud()
	Kit.fade_in(self)

	# Un par de fotogramas para que se vea "Generando…" antes del cálculo.
	await get_tree().process_frame
	await get_tree().process_frame
	logic = Registry.create_logic(Game.puzzle_id)
	puzzle = logic.generate(Game.seed_value, Game.difficulty)
	_loading.queue_free()
	if puzzle.is_empty():
		content.add_child(Kit.label("No se pudo generar el nivel", 28, Palette.CORAL))
		return
	_setup()
	_playing = true


func _process(delta: float) -> void:
	if _playing and not finished:
		Game.elapsed += delta
		var sec := int(Game.elapsed)
		if sec != _last_sec:
			_last_sec = sec
			_sub_label.text = "%s · %d:%02d" % [_sub_text, sec / 60, sec % 60]


# --- A sobrescribir por cada puzle ------------------------------------------------

func _setup() -> void:
	pass


func _give_hint() -> bool:
	return false


# --- API para las subclases --------------------------------------------------------

## Un error del jugador: cuesta una vida (si el puzle usa vidas).
func mistake() -> void:
	if finished:
		return
	Game.mistakes += 1
	if uses_lives:
		Game.lives -= 1
		_hearts.queue_redraw()
		if Game.lives <= 0:
			finished = true
			await get_tree().create_timer(0.5).timeout
			Game.finish(false)


func solved() -> void:
	if finished:
		return
	finished = true
	await get_tree().create_timer(0.7).timeout
	Game.finish(true)


# --- Interfaz común ----------------------------------------------------------------

func _update_hud() -> void:
	_hint_btn.text = "     %s · %d" % [tr("HINT"), Game.hints_left]
	_hint_btn.disabled = Game.hints_left <= 0 or finished


func _on_hint_pressed() -> void:
	if finished or not _playing or Game.hints_left <= 0:
		return
	if _give_hint():
		Game.hints_left -= 1
		Game.hints_used += 1
		_update_hud()


func _on_back() -> void:
	if Game.daily_key != "":
		Game.go_menu()
	else:
		Game.go_levels(Game.puzzle_id)


func _draw_card_bg() -> void:
	Kit.card(content, Rect2(Vector2(2, 2), content.size - Vector2(4, 10)), 30,
		Color8(31, 41, 55), Color8(20, 27, 37), Palette.CARD_BORDER, 2.0)


func _draw_bulb(c: Control) -> void:
	var col: Color = Palette.GOLD if Game.hints_left > 0 else Palette.MUTED.darkened(0.2)
	var o := Vector2(c.size.x * 0.5 - 92.0, c.size.y / 2.0)
	c.draw_circle(o + Vector2(0, -5), 12, col)
	c.draw_rect(Rect2(o + Vector2(-6, 6), Vector2(12, 7)), col)
	c.draw_line(o + Vector2(-4, 17), o + Vector2(4, 17), col, 3.0, true)


func _draw_hearts() -> void:
	if _heart_poly.is_empty():
		for i in 40:
			var t := TAU * i / 40.0
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			_heart_poly.append(Vector2(x, y) * 1.15)
	for i in Game.MAX_LIVES:
		var c := Vector2(30 + i * 50, 40)
		var pts := PackedVector2Array()
		for p in _heart_poly:
			pts.append(p + c)
		if i < Game.lives:
			Kit.glow_circle(_hearts, c, 14, Palette.CORAL, 0.1)
			_hearts.draw_colored_polygon(pts, Palette.CORAL)
			_hearts.draw_arc(c + Vector2(-7, -5), 7, PI * 1.05, PI * 1.55, 8, Color(1, 1, 1, 0.55), 3.0, true)
		else:
			pts.append(pts[0])
			_hearts.draw_polyline(pts, Palette.CORAL_DIM, 3.0, true)
