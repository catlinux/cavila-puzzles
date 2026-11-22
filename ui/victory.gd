extends Control
## Pantalla de resultado (victoria o sin vidas).

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")


func _ready() -> void:
	var res: Dictionary = Game.last_result
	var won: bool = res.get("won", false)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom", "top"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	margin.add_child(vb)

	var burst := Control.new()
	burst.custom_minimum_size = Vector2(0, 260)
	burst.draw.connect(_draw_burst.bind(burst, won))
	vb.add_child(burst)
	vb.add_child(Kit.label(tr("WIN_TITLE") if won else tr("LOSE_TITLE"), 72, Palette.TURQUOISE if won else Palette.CORAL))
	var t: float = res.get("time", 0.0)
	vb.add_child(Kit.label("%s: %d:%02d" % [tr("STAT_TIME"), int(t) / 60, int(t) % 60], 32, Palette.TEXT))
	vb.add_child(Kit.label("%s: %d" % [tr("STAT_LIVES"), res.get("lives", 0)], 32, Palette.TEXT))
	vb.add_child(Kit.label("%s: %d" % [tr("STAT_HINTS"), res.get("hints", 0)], 32, Palette.TEXT))
	vb.add_child(Control.new())

	if won and Game.daily_key == "":
		var nxt := Kit.button(tr("NEXT"), Palette.TURQUOISE, 34)
		nxt.pressed.connect(Game.next_level)
		vb.add_child(nxt)
	var again := Kit.button(tr("REPLAY") if won else tr("RETRY"), Palette.CORAL, 34)
	again.pressed.connect(Game.restart)
	vb.add_child(again)
	var menu := Kit.button(tr("MENU"), Palette.MUTED, 34)
	menu.pressed.connect(Game.go_menu)
	vb.add_child(menu)


func _draw_burst(c: Control, won: bool) -> void:
	var center := Vector2(c.size.x / 2, c.size.y / 2)
	var col := Palette.TURQUOISE if won else Palette.CORAL
	if won:
		for i in 12:
			var a := TAU * i / 12.0
			var dir := Vector2(cos(a), sin(a))
			c.draw_line(center + dir * 70, center + dir * (110 + 30 * (i % 2)), Palette.CORAL if i % 2 else Palette.TURQUOISE, 10, true)
		c.draw_polyline(PackedVector2Array([center + Vector2(-40, 0), center + Vector2(-12, 30), center + Vector2(42, -30)]), col, 16, true)
	else:
		c.draw_arc(center, 70, 0, TAU, 48, col, 10, true)
		c.draw_line(center + Vector2(-30, -30), center + Vector2(30, 30), col, 12, true)
		c.draw_line(center + Vector2(30, -30), center + Vector2(-30, 30), col, 12, true)
