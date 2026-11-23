extends Control
## Panel de ajustes (sonido, vibración, idioma) con créditos y licencias.

const Style = preload("res://ui/style.gd")
const PillButton = preload("res://ui/widgets/pill_button.gd")

signal closed

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
	vb.add_theme_constant_override("separation", 26)
	panel.add_child(vb)
	vb.add_child(Style.label(tr("SETTINGS"), 56, Style.INK, "display_bold", HORIZONTAL_ALIGNMENT_CENTER))
	_switch_row(vb, "speaker-high-fill", tr("SOUND"), "sound")
	_switch_row(vb, "vibrate-fill", tr("VIBRATION"), "vibration")
	var row := _row(vb, "translate-bold", tr("LANGUAGE"))
	var lang := PillButton.new(tr("LANG_NAME"), false, 88.0)
	lang.font_size = 40
	lang.custom_minimum_size = Vector2(220, 88)
	lang.pressed.connect(func():
		Game.set_language("ca" if Game.language() == "es" else "es")
		get_tree().reload_current_scene())
	row.add_child(lang)
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


func _switch_row(vb: VBoxContainer, icon: String, text: String, key: String) -> void:
	var row := _row(vb, icon, text)
	var sw := Switch.new()
	sw.accent = accent_a
	sw.on = bool(Progress.setting(key))
	sw.toggled.connect(func(v):
		Progress.set_setting(key, v)
		Sfx.play("tap"))
	row.add_child(sw)
