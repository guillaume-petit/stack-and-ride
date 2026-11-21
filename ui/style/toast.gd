class_name Toast
extends PanelContainer
## A short message at the bottom of the screen that fades away by itself: why an action was
## refused, or what a greyed out button or a counter of the top bar means (phones show no
## tooltips).
##
## Any node can show one with Toast.show_from(): the message goes through a group (Godot's way
## to call every node tagged with a name), so a view does not need to know the screen.

const GROUP := &"toast"
const SHOW_SECONDS := 2.8
const FADE_SECONDS := 0.25
const BOTTOM_MARGIN := 18
const MAX_WIDTH := 560.0

var _label: Label
var _tween: Tween


## Shows a message in the toast of the screen that contains this node, if any.
static func show_from(node: Node, text: String) -> void:
	if text != "" and node.is_inside_tree():
		node.get_tree().call_group(GROUP, &"show_text", text)


func _init() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyle.box(UiStyle.INK, UiStyle.INK, 0, UiStyle.RADIUS, 10))
	_label = UiStyle.paragraph("", UiStyle.FONT_SIZE, Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	visible = false


## The current message ("" when none is shown).
func text() -> String:
	return _label.text if visible else ""


func show_text(message: String) -> void:
	_label.text = message
	visible = true
	modulate.a = 1.0
	var width := minf(MAX_WIDTH, get_parent_area_size().x - 2 * BOTTOM_MARGIN) if is_inside_tree() else MAX_WIDTH
	_label.custom_minimum_size.x = minf(width, _label.get_theme_font("font").get_string_size(message,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE).x + 4)
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, BOTTOM_MARGIN)
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		return
	_tween = create_tween()
	modulate.a = 0.0
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide)
