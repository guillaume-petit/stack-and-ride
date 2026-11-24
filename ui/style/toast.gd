class_name Toast
extends VBoxContainer
## The snack bar: short messages in dark bars at the bottom of the map, that fade away by
## themselves. What happens in the run (a delivery, a shake...), why an action was refused, what
## a greyed out button or a counter means (phones show no tooltips). The newest is at the bottom;
## the whole list stays in the history window.
##
## Any node can show a message with Toast.show_from(): it goes through a group (Godot's way to
## call every node tagged with a name), so a view does not need to know the screen.

## Every bar is gone.
signal cleared

const GROUP := &"toast"
const SHOW_SECONDS := 3.5
const FADE_SECONDS := 0.25
## Bars shown at once: a new one pushes out the oldest.
const MAX_BARS := 2
const MAX_WIDTH := 560.0
const SIDE := 12.0

## Last message shown, for the tests ("" when every bar is gone).
var _last: String = ""
## Bottom edge of the snack bar, in the coordinates of its parent.
var _bottom: float = 0.0


## Shows a message in the snack bar of the screen that contains this node, if any.
static func show_from(node: Node, text: String) -> void:
	if text != "" and node.is_inside_tree():
		node.get_tree().call_group(GROUP, &"show_text", text)


func _init() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)


## The newest message still shown ("" when none).
func text() -> String:
	return _last


## Keeps the snack bar centered, as wide as the screen allows, its bottom edge at this height.
func place(bottom: float, width: float) -> void:
	place_in(Rect2(0, 0, width, bottom))


## Keeps the snack bar in a column of the screen (left edge and width), its bottom edge at the
## bottom of the column.
func place_in(column: Rect2) -> void:
	_bottom = column.end.y
	custom_minimum_size.x = minf(MAX_WIDTH, column.size.x - 2 * SIDE)
	position.x = column.position.x + (column.size.x - custom_minimum_size.x) / 2
	_stay_above_bottom()


## A plain message (a refusal, an explanation).
func show_text(message: String) -> void:
	show_line(UiText.Line.new("", message))


## A message with its sender (the app, a client...), in red when it is bad news.
func show_line(line: UiText.Line) -> void:
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.box(Color(UiStyle.INK, 0.93), UiStyle.INK, 0, 8, 12)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	bar.add_theme_stylebox_override("panel", style)
	var column := UiStyle.vbox(1)
	if line.sender != "":
		column.add_child(UiStyle.label(line.sender.to_upper(), 10, UiStyle.BAD.lightened(0.3) if line.bad else UiStyle.MUSTARD, true))
	column.add_child(UiStyle.paragraph(line.text, UiStyle.SMALL_FONT_SIZE + 1, Color.WHITE))
	bar.add_child(column)
	add_child(bar)
	_last = line.text
	while get_child_count() > MAX_BARS:
		_remove(get_child(0) as Control)
	_stay_above_bottom()
	if not is_inside_tree():
		return
	bar.modulate.a = 0.0
	var tween := bar.create_tween()
	tween.tween_property(bar, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(SHOW_SECONDS)
	tween.tween_property(bar, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_remove.bind(bar))


func _remove(bar: Control) -> void:
	if bar.get_parent() != self:
		return
	remove_child(bar)
	bar.queue_free()
	if get_child_count() == 0:
		_last = ""
		cleared.emit()
	_stay_above_bottom()


func _stay_above_bottom() -> void:
	reset_size()
	position.y = _bottom - get_combined_minimum_size().y
