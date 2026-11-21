class_name ClickCard
extends PanelContainer
## A clickable panel that sizes itself to its content: movement cards, profiles, rewards.
##
## A Button does not grow with the labels put inside it, a PanelContainer does; this one adds
## the hover and disabled looks and a pressed signal, like a button.

signal pressed

var disabled: bool = false:
	set(value):
		disabled = value
		mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_POINTING_HAND
		modulate.a = 0.45 if value else 1.0
		_update_style()

## Contents go in this box.
var content: VBoxContainer

var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _hovered: bool = false


## color: background; border: border color (also the shadow under the card).
func _init(color: Color = UiStyle.PANEL, border: Color = UiStyle.INK, dashed_look: bool = false) -> void:
	_normal = UiStyle.box(color, border, 2, 12, 9)
	_normal.shadow_color = border
	_normal.shadow_offset = Vector2(0, 3)
	if dashed_look:
		_normal.shadow_offset = Vector2.ZERO
		_normal.border_color = UiStyle.MUTED
	_hover = _normal.duplicate() as StyleBoxFlat
	_hover.border_color = UiStyle.ACCENT
	_hover.shadow_color = UiStyle.ACCENT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	content = UiStyle.vbox(3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	# After a tap, a finger leaves the mouse where it was: no hover look on phones.
	mouse_entered.connect(func() -> void:
		_hovered = not Device.touch_screen()
		_update_style())
	mouse_exited.connect(func() -> void:
		_hovered = false
		_update_style())
	_update_style()


## Adds a child to the content; labels and boxes must let the clicks through.
func add(control: Control) -> Control:
	_ignore_mouse(control)
	content.add_child(control)
	return control


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if disabled:
		# Why it cannot be used (see UiStyle.explain_on_press()).
		Toast.show_from(self, tooltip_text)
	else:
		pressed.emit()


func _update_style() -> void:
	add_theme_stylebox_override("panel", _hover if _hovered and not disabled else _normal)


static func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)
