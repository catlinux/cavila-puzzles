extends Control
## Casilla de la cuadrícula del menú: icono dibujado por código + nombre.

const Palette = preload("res://ui/palette.gd")
const Kit = preload("res://ui/kit.gd")
const Icons = preload("res://ui/puzzle_icons.gd")

signal pressed

var puzzle_id := ""
var title := ""
var locked := false
var _down := false


func _ready() -> void:
	custom_minimum_size = Vector2(200, 230)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := Palette.PANEL_HI if _down else Palette.PANEL
	draw_style_box(Kit.box(bg, 26, Palette.MUTED.darkened(0.5) if locked else Palette.TURQUOISE_DIM, 3), r)
	var accent := Palette.MUTED.darkened(0.3) if locked else Palette.TURQUOISE
	var alt := Palette.WIRE if locked else Palette.CORAL
	Icons.draw(self, puzzle_id, Rect2(Vector2(20, 14), Vector2(size.x - 40, size.y - 90)), accent, alt)
	Kit.text_at(self, Vector2(size.x / 2, size.y - 42), title, 28, Palette.MUTED if locked else Palette.TEXT)
	if locked:
		Kit.text_at(self, Vector2(size.x / 2, size.y - 16), tr("SOON"), 18, Palette.MUTED.darkened(0.2))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
		else:
			if _down and Rect2(Vector2.ZERO, size).has_point(ev.position) and not locked:
				pressed.emit()
			_down = false
		queue_redraw()
