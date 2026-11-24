class_name IconButton
extends Control
## A round button with a drawn icon and a badge (a number or "!"), like the icons of a phone:
## the app, the bag, the history of the notifications, the menu, the (i) of the top bar.
##
## The icons are drawn with lines and shapes (provisional look, no image files yet).

signal pressed

enum Icon { PHONE, BAG, HISTORY, MENU, INFO }

const SIZE := 56.0
const BADGE_RADIUS := 11.0

var icon: Icon
## Shown in a red dot at the top right; nothing when empty.
var badge: String = "":
	set(value):
		badge = value
		queue_redraw()
## Drawn in the accent color, e.g. while its window is open or a dish waits in hand.
var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()


func _init(p_icon: Icon, diameter: float = SIZE) -> void:
	icon = p_icon
	custom_minimum_size = Vector2.ONE * diameter
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sfx.play(Sfx.Sound.CLICK)
		pressed.emit()


func _draw() -> void:
	var center := size / 2
	var radius := minf(size.x, size.y) / 2 - 3
	draw_circle(center + Vector2(0, 3), radius, UiStyle.INK)
	draw_circle(center, radius, UiStyle.ACCENT if lit else UiStyle.PANEL)
	draw_arc(center, radius, 0, TAU, 40, UiStyle.INK, 2.0, true)
	var ink := Color.WHITE if lit else UiStyle.INK
	var unit := radius / 10.0
	match icon:
		Icon.PHONE:
			var body := Rect2(center - Vector2(4.2, 6.8) * unit, Vector2(8.4, 13.6) * unit)
			_rounded_outline(body, unit * 1.6, ink, unit * 1.1)
			draw_line(center + Vector2(-1.5, -5.0) * unit, center + Vector2(1.5, -5.0) * unit, ink, unit, true)
			draw_circle(center + Vector2(0, 4.8) * unit, unit * 0.8, ink)
		Icon.BAG:
			# A delivery backpack: a box, a handle, a band across.
			var box := Rect2(center + Vector2(-6.0, -4.0) * unit, Vector2(12.0, 10.5) * unit)
			_rounded_outline(box, unit * 1.2, ink, unit * 1.2)
			draw_arc(center + Vector2(0, -4.0) * unit, unit * 2.6, PI, TAU, 16, ink, unit * 1.1, true)
			draw_line(box.position + Vector2(0, 3.5 * unit), Vector2(box.end.x, box.position.y + 3.5 * unit), ink, unit, true)
		Icon.HISTORY:
			# A speech bubble with lines of text.
			var bubble := Rect2(center + Vector2(-6.5, -5.5) * unit, Vector2(13.0, 9.5) * unit)
			_rounded_outline(bubble, unit * 2.0, ink, unit * 1.1)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-3.0, 3.6) * unit,
					center + Vector2(-4.5, 7.0) * unit, center + Vector2(0.0, 3.6) * unit]), ink)
			for row in 3:
				var y := (-3.0 + row * 2.4) * unit
				draw_line(center + Vector2(-4.0 * unit, y), center + Vector2((4.0 - row * 1.5) * unit, y), ink, unit * 0.9, true)
		Icon.MENU:
			for row in 3:
				var y := (-3.5 + row * 3.5) * unit
				draw_line(center + Vector2(-5.0 * unit, y), center + Vector2(5.0 * unit, y), ink, unit * 1.3, true)
		Icon.INFO:
			draw_circle(center + Vector2(0, -4.2) * unit, unit * 1.3, ink)
			draw_line(center + Vector2(0, -1.0) * unit, center + Vector2(0, 5.0) * unit, ink, unit * 2.0, true)
	if badge != "":
		var at := center + Vector2(radius * 0.72, -radius * 0.72)
		draw_circle(at, BADGE_RADIUS + 2, Color.WHITE)
		draw_circle(at, BADGE_RADIUS, UiStyle.BAD)
		var font := UiStyle.bold_font()
		draw_string(font, at + Vector2(-BADGE_RADIUS, 5), badge, HORIZONTAL_ALIGNMENT_CENTER, BADGE_RADIUS * 2, 14, Color.WHITE)


func _rounded_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(int(ceilf(width)))
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	draw_style_box(style, rect)
