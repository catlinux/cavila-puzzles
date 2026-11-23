extends Control
## Pantalla de ligas: relámpago, diaria y semanal, con cuenta atrás, premios y clasificación.

const Style = preload("res://ui/style.gd")
const Levels = preload("res://game/levels.gd")
const Leagues = preload("res://game/leagues.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const RoundButton = preload("res://ui/widgets/round_button.gd")
const PillButton = preload("res://ui/widgets/pill_button.gd")

var type := "daily"
var world: Dictionary = {}
var _tabs: Array = []
var _info: Control
var _list: VBoxContainer
var _refresh := 0.0


func _ready() -> void:
	world = Levels.world(Progress.current_level())
	type = Game.selected_league
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 84)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	margin.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	vb.add_child(top)
	var back := RoundButton.new("arrow-left-bold")
	back.pressed.connect(Game.go_home)
	top.add_child(back)
	var title := Style.label(tr("LEAGUES"), 54, Style.INK, "display_bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	vb.add_child(tabs)
	for t in Leagues.TYPES:
		var b := PillButton.new(tr("LEAGUE_" + t.to_upper()), t == type, 88.0)
		b.font_size = 36
		b.set_colors(world.a, world.b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select.bind(t))
		tabs.add_child(b)
		_tabs.append(b)

	_info = Control.new()
	_info.custom_minimum_size = Vector2(0, 200)
	_info.draw.connect(_draw_info)
	vb.add_child(_info)

	var card := Style.card(44, 18)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_rebuild()
	Style.fade_in(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.go_home()


func _select(t: String) -> void:
	type = t
	Game.selected_league = t
	for k in _tabs.size():
		_tabs[k].primary = Leagues.TYPES[k] == t
		_tabs[k].queue_redraw()
	_rebuild()


func _process(delta: float) -> void:
	_refresh += delta
	_info.queue_redraw()
	if _refresh > 5.0:  # los rivales siguen jugando: refrescar la tabla
		_refresh = 0.0
		_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var lg := Progress.league(type)
	var rows := Progress.league_standings(lg)
	for k in rows.size():
		_list.add_child(_row(k + 1, rows[k], rows.size()))


func _row(rank: int, r: Dictionary, total: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 92)
	var promo := type == "weekly" and (rank <= Leagues.PROMOTE or rank > total - Leagues.PROMOTE)
	c.draw.connect(func():
		var rect := Rect2(Vector2(0, 4), c.size - Vector2(0, 8))
		if r.you:
			Style.fill_round(c, rect, 26.0, Color(world.a, 0.14))
		var cy := rect.get_center().y
		# Puesto (medalla para el podio).
		var medal := [Style.GOLD, Color8(176, 186, 201), Color8(214, 140, 90)]
		if rank <= 3:
			c.draw_circle(Vector2(42, cy), 24, medal[rank - 1])
			Style.text_at(c, Vector2(42, cy), str(rank), 28, Color.WHITE)
		else:
			var col := Style.SUB
			if promo:
				col = Color8(16, 185, 129) if rank <= Leagues.PROMOTE else Style.RED
			Style.text_at(c, Vector2(42, cy), str(rank), 28, col)
		# Avatar con inicial.
		c.draw_circle(Vector2(112, cy), 30, r.color)
		var initial: String = "★" if r.you else String(r.name).substr(0, 1).to_upper()
		if r.you:
			var ic := Style.icon("user-fill", Color.WHITE, 32)
			c.draw_texture(ic, Vector2(112, cy) - ic.get_size() / 2.0)
		else:
			Style.text_at(c, Vector2(112, cy), initial, 30, Color.WHITE)
		c.draw_string(Style.font("display" if r.you else "body"), Vector2(164, cy + 12), r.name,
			HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 360, 32, Style.INK)
		var pts := Style.fmt_int(r.points)
		var w := Style.text_width(pts, 32, "display")
		c.draw_string(Style.font("display"), Vector2(c.size.x - 24 - w, cy + 12), pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Style.INK))
	return c


func _draw_info() -> void:
	var c := _info
	var lg := Progress.league(type)
	var r := Rect2(Vector2(2, 2), c.size - Vector2(4, 12))
	Style.soft_shadow(c, r, 40.0, Color(world.a, 0.3), 16.0, Vector2(0, 8))
	Style.gradient_shape(c, r, 40.0, world.a, world.b)
	var left := int(lg.end) - Progress.now()
	var h := left / 3600
	var m := (left % 3600) / 60
	var s := left % 60
	var time_txt := ("%dd %dh" % [h / 24, h % 24]) if h >= 24 else ("%d:%02d:%02d" % [h, m, s])
	var tex := Style.icon("trophy-fill", Color.WHITE, 64)
	c.draw_texture(tex, Vector2(r.position.x + 34, r.position.y + 34))
	c.draw_string(Style.font("display_bold"), Vector2(r.position.x + 120, r.position.y + 70),
		tr("LEAGUE_OF") % tr("LEAGUE_" + type.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	c.draw_string(Style.font("body_bold"), Vector2(r.position.x + 120, r.position.y + 108),
		tr("ENDS_IN") % time_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.9))
	var p: Array = Leagues.CONFIG[type].prizes
	var line := tr("PRIZES") % [p[0], p[1], p[2]]
	if type == "weekly":
		line = "%s · %s" % [tr(Leagues.DIVISIONS[int(Progress.data.division)]), tr("PROMO_INFO") % [Leagues.PROMOTE, Leagues.PROMOTE]]
	c.draw_string(Style.font("body"), Vector2(r.position.x + 34, r.position.y + 156), line,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 23, Color(1, 1, 1, 0.92))
