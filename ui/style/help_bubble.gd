class_name HelpBubble
extends Control
## A help bubble pointing at something on the screen (the phone icon, the hand, the courier...):
## a short text saying what to do, with a tail toward its target. It fades away by itself and
## lets clicks through to what is under it.

## Where the bubble goes, relative to its target.
enum Placement { LEFT, ABOVE, BELOW }

const SHOW_SECONDS := 6.0
const FADE_SECONDS := 0.3
const TAIL := 10.0
const MAX_WIDTH := 270.0
const FONT_SIZE := UiStyle.SMALL_FONT_SIZE + 1
## Room kept between the bubble and the edges of the screen.
const EDGE := 8.0

var _panel: PanelContainer
var _label: Label
var _placement := Placement.ABOVE
## Where the tail touches the target, in the bubble's coordinates.
var _tip := Vector2.ZERO
var _tween: Tween


func _init() -> void:
	# Clicks go through: the bubble often sits over the crossroads it tells to touch.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The tail is drawn over the border of the bubble, so that they join.
	_panel.show_behind_parent = true
	_panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.MUSTARD, 2, 12, 10))
	_label = UiStyle.paragraph("", FONT_SIZE, UiStyle.INK)
	_panel.add_child(_label)
	add_child(_panel)
	visible = false


## The text shown ("" when hidden).
func text() -> String:
	return _label.text if visible else ""


## Shows the text next to a point of the screen (in the coordinates of the bubble's parent).
func point_at(message: String, target: Vector2, placement: Placement) -> void:
	_label.text = message
	_placement = placement
	# Measured from the font: the sizes of the label are only updated at the next frame.
	var font := _label.get_theme_font("font")
	var width := 0.0
	for line in message.split("\n"):
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	width = minf(MAX_WIDTH, width + 4)
	_label.custom_minimum_size.x = width
	var text_size := font.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE)
	var lines := maxi(1, roundi(text_size.y / font.get_height(FONT_SIZE)))
	var style := _panel.get_theme_stylebox("panel")
	var box := Vector2(width, text_size.y + lines * _label.get_theme_constant("line_spacing")) + style.get_minimum_size()
	# A control never gets smaller than its minimum size, and a wrapping label measures its
	# minimum height from its current width: give it the new width, then shrink the panel.
	_label.size = Vector2(width, 0)
	_panel.custom_minimum_size = box
	_panel.reset_size()
	_panel.size = box
	# The panel sorts its label at the end of the frame; then it may shrink to its true size.
	_panel.reset_size.call_deferred()
	size = box + (Vector2(TAIL, 0) if placement == Placement.LEFT else Vector2(0, TAIL))
	_panel.position = Vector2(0, TAIL) if placement == Placement.BELOW else Vector2.ZERO
	var at := target - Vector2(box.x / 2, size.y)
	if placement == Placement.LEFT:
		at = target - Vector2(size.x, box.y / 2)
	elif placement == Placement.BELOW:
		at = target - Vector2(box.x / 2, 0)
	var area := get_parent_area_size() if is_inside_tree() else Vector2(INF, INF)
	position = at.clamp(Vector2.ONE * EDGE, (area - size - Vector2.ONE * EDGE).max(Vector2.ONE * EDGE))
	_tip = target - position
	visible = true
	queue_redraw()
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		return
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide)


## The tail: a yellow triangle with a white inside, toward the target.
func _draw() -> void:
	var box := _panel.size
	var outer: PackedVector2Array
	var inward: Vector2
	match _placement:
		Placement.LEFT:
			var y := clampf(_tip.y, 14, box.y - 14)
			outer = PackedVector2Array([Vector2(box.x - 2, y - 9), Vector2(box.x + TAIL, y), Vector2(box.x - 2, y + 9)])
			inward = Vector2.LEFT
		Placement.ABOVE:
			var x := clampf(_tip.x, 16, box.x - 16)
			outer = PackedVector2Array([Vector2(x - 9, box.y - 2), Vector2(x, box.y + TAIL), Vector2(x + 9, box.y - 2)])
			inward = Vector2.UP
		Placement.BELOW:
			var x := clampf(_tip.x, 16, box.x - 16)
			outer = PackedVector2Array([Vector2(x - 9, TAIL + 2), Vector2(x, 0), Vector2(x + 9, TAIL + 2)])
			inward = Vector2.DOWN
	draw_colored_polygon(outer, UiStyle.MUSTARD)
	# The white inside: the same triangle, moved inward and narrowed by the border width.
	var middle := (outer[0] + outer[2]) / 2
	var inner := PackedVector2Array([outer[0] + (middle - outer[0]).normalized() * 3.0 + inward,
			outer[1] + inward * 4.0, outer[2] + (middle - outer[2]).normalized() * 3.0 + inward])
	draw_colored_polygon(inner, UiStyle.PANEL)
