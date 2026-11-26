extends Control
## Panel de ajustes (sonido, vibración, idioma) con créditos y licencias.

const Style = preload("res://ui/style.gd")
const PillButton = preload("res://ui/widgets/pill_button.gd")

signal closed
signal style_changed

var accent_a: Color
var accent_b: Color


class Switch extends Control:
	signal toggled(on: bool)
	var on := false
	var accent := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(112, 64)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2(0, 6), Vector2(size.x, 52))
		Style.fill_round(self, r, 26.0, accent if on else Style.OFF)
		var kx := r.end.x - 26.0 if on else r.position.x + 26.0
		draw_circle(Vector2(kx, r.get_center().y + 2), 22, Color(0, 0, 0, 0.08))
		draw_circle(Vector2(kx, r.get_center().y), 21, Color.WHITE)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			on = not on
			queue_redraw()
			toggled.emit(on)
			accept_event()


class VolumeSlider extends Control:
	signal changed(v: float)
	var value := 0.8
	var accent := Color.WHITE
	var _drag := false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 56)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var x0 := 62.0
		var w := size.x - x0 - 20.0
		var y := size.y / 2.0
		Style.fill_round(self, Rect2(x0, y - 6, w, 12), 6.0, Style.OFF, 6)
		Style.fill_round(self, Rect2(x0, y - 6, maxf(w * value, 12.0), 12), 6.0, accent, 6)
		var kx := x0 + w * value
		draw_circle(Vector2(kx, y + 2), 19, Color(0, 0, 0, 0.08))
		draw_circle(Vector2(kx, y), 18, Color.WHITE)
		draw_circle(Vector2(kx, y), 7, accent)

	func _set_from(x: float) -> void:
		var x0 := 62.0
		var w := size.x - x0 - 20.0
		value = clampf((x - x0) / w, 0.0, 1.0)
		queue_redraw()
		changed.emit(value)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			_drag = ev.pressed
			if ev.pressed:
				_set_from(ev.position.x)
			accept_event()
		elif ev is InputEventMouseMotion and _drag:
			_set_from(ev.position.x)
			accept_event()


func _init(a: Color, b: Color) -> void:
	accent_a = a
	accent_b = b


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Style.INK, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Style.card(56, 44)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(580, 0)
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(Style.label(tr("SETTINGS"), 56, Style.INK, "display_bold", HORIZONTAL_ALIGNMENT_CENTER))
	_switch_row(vb, "speaker-high-fill", tr("SOUND"), "sound")
	_volume_row(vb, "sfx_volume", func(): Sfx.play("chime3"))
	_switch_row(vb, "music-notes-fill", tr("MUSIC"), "music", func(v): Sfx.set_music(v))
	_volume_row(vb, "music_volume")
	_switch_row(vb, "vibrate-fill", tr("VIBRATION"), "vibration", func(v): if v: Sfx.vibrate(15))
	# Estilo de las piezas.
	vb.add_child(Style.label(tr("PIECE_STYLE"), 30, Style.INK, "body"))
	var styles := HBoxContainer.new()
	styles.add_theme_constant_override("separation", 10)
	vb.add_child(styles)
	var style_btns := []
	for st in ["arrows", "colors", "comets", "soft"]:
		var b := PillButton.new(tr("STYLE_" + st.to_upper()), Progress.setting("piece_style") == st, 84.0)
		b.font_size = 30
		b.set_colors(accent_a, accent_b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		style_btns.append(b)
		styles.add_child(b)
	for k in style_btns.size():
		var key: String = ["arrows", "colors", "comets", "soft"][k]
		style_btns[k].pressed.connect(func():
			Progress.set_setting("piece_style", key)
			for j in style_btns.size():
				style_btns[j].primary = j == k
				style_btns[j].queue_redraw()
			style_changed.emit())
	var row := _row(vb, "translate-bold", tr("LANGUAGE"))
	var lang := PillButton.new(tr("LANG_NAME"), false, 88.0)
	lang.font_size = 40
	lang.custom_minimum_size = Vector2(220, 88)
	lang.pressed.connect(func():
		Game.set_language("ca" if Game.language() == "es" else "es")
		get_tree().reload_current_scene())
	row.add_child(lang)
	var reset := PillButton.new(tr("RESET_PROGRESS"), false, 92.0)
	reset.icon_name = "trash-bold"
	reset.font_size = 40
	reset.pressed.connect(_confirm_reset)
	vb.add_child(reset)
	var reset_lg := PillButton.new(tr("RESET_LEAGUES"), false, 92.0)
	reset_lg.icon_name = "arrow-counter-clockwise-bold"
	reset_lg.font_size = 40
	reset_lg.pressed.connect(_confirm_reset.bind(true))
	vb.add_child(reset_lg)
	var credits := Style.label(tr("CREDITS_TEXT"), 20, Style.SUB, "body_semi", HORIZONTAL_ALIGNMENT_CENTER)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.custom_minimum_size = Vector2(560, 0)
	vb.add_child(credits)
	var close := PillButton.new(tr("CLOSE"), true, 112.0)
	close.set_colors(accent_a, accent_b)
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	vb.add_child(close)
	Style.fade_in(self, 0.18)


func _row(vb: VBoxContainer, icon: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	vb.add_child(row)
	var ic := TextureRect.new()
	ic.texture = Style.icon(icon, Style.INK, 40)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(44, 64)
	row.add_child(ic)
	var l := Style.label(text, 34, Style.INK, "body")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _switch_row(vb: VBoxContainer, icon: String, text: String, key: String, extra: Callable = Callable()) -> void:
	var row := _row(vb, icon, text)
	var sw := Switch.new()
	sw.accent = accent_a
	sw.on = bool(Progress.setting(key))
	sw.toggled.connect(func(v):
		Progress.set_setting(key, v)
		if extra.is_valid():
			extra.call(v)
		Sfx.play("tap"))
	row.add_child(sw)


func _volume_row(vb: VBoxContainer, key: String, preview: Callable = Callable()) -> void:
	var sl := VolumeSlider.new()
	sl.accent = accent_a
	sl.value = float(Progress.setting(key))
	sl.changed.connect(func(v):
		Progress.data["settings"][key] = v
		Sfx.apply_volumes())
	# Guardar y sonar una muestra al soltar.
	sl.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and not ev.pressed:
			Progress.save()
			if preview.is_valid():
				preview.call())
	vb.add_child(sl)


## Confirmación antes de borrar todo el progreso (o solo las ligas).
func _confirm_reset(leagues_only := false) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(Style.INK, 0.3)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := Style.card(56, 44)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(540, 0)
	vb.add_theme_constant_override("separation", 22)
	panel.add_child(vb)
	var ic := TextureRect.new()
	ic.texture = Style.icon("warning-fill", Style.RED, 84)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	vb.add_child(ic)
	vb.add_child(Style.label(tr("RESET_LEAGUES_TITLE" if leagues_only else "RESET_TITLE"), 50, Style.INK, "display_bold", HORIZONTAL_ALIGNMENT_CENTER))
	var txt := Style.label(tr("RESET_LEAGUES_TEXT" if leagues_only else "RESET_TEXT"), 28, Style.SUB, "body", HORIZONTAL_ALIGNMENT_CENTER)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(520, 0)
	vb.add_child(txt)
	var yes := PillButton.new(tr("RESET_LEAGUES_YES" if leagues_only else "RESET_YES"), true, 112.0)
	yes.font_size = 42
	yes.set_colors(Style.RED, Color8(244, 114, 92))
	yes.pressed.connect(func():
		if leagues_only:
			Progress.reset_leagues()
		else:
			Progress.reset()
		Game.go_home())
	vb.add_child(yes)
	var no := PillButton.new(tr("CANCEL"), false, 96.0)
	no.pressed.connect(layer.queue_free)
	vb.add_child(no)
	Style.fade_in(layer, 0.15)
