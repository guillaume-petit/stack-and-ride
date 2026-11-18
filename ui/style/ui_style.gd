class_name UiStyle
extends RefCounted
## Colors, theme and small widget helpers shared by every screen (provisional look, taken
## from the prototype).
##
## In Godot, a Theme is a resource that gives every Control its default look (fonts, colors,
## styleboxes). It is set once on the root Control of a screen and inherited by all its
## children. A "type variation" (e.g. "AccentButton") is a named variant of a base type that
## a node selects with its theme_type_variation property, like a CSS class.

const BACKGROUND := Color("#eceff3")
const PANEL := Color("#ffffff")
const INK := Color("#1a1e24")
const MUTED := Color("#5d6570")
const LINE := Color("#d3d9e0")
const ROAD := Color("#e2e6eb")
const ACCENT := Color("#e2452b")
const MUSTARD := Color("#f2b705")
const OK := Color("#21925a")
const BAD := Color("#cf3628")
const HOT := Color("#e2452b")
const COLD := Color("#2f86c9")
const BLOCK := Color("#cfd6de")
const STREET := Color("#ffffff")
const PAVED := Color("#b9b0a3")
const WORKS := Color("#e8892b")

## One color per order, by order id, to follow a dish from the app to the map and the bag.
const ORDER_COLORS: Array[Color] = [
	Color("#e4572e"), Color("#2f7fc4"), Color("#23935a"), Color("#9b55cf"),
	Color("#d39a00"), Color("#d0408a"), Color("#3d8c8c"), Color("#7a5c3e"),
]
## Restaurant colors by restaurant id; other ids use RESTAURANT_DEFAULT.
const RESTAURANT_COLORS: Dictionary[StringName, Color] = {
	&"burger": Color("#d9822b"),
	&"pizza": Color("#c4473b"),
	&"sushi": Color("#2c8b80"),
	&"tacos": Color("#b5862a"),
	&"glacier": Color("#6a8bd4"),
}
const RESTAURANT_DEFAULT := Color("#2f7fc4")

const FONT_SIZE := 15
const SMALL_FONT_SIZE := 12
const TITLE_FONT_SIZE := 19
const BIG_FONT_SIZE := 26
const RADIUS := 10
const GAP := 10

## Bold version of the default font, built once.
static var _bold: Font = null


static func order_color(order_id: int) -> Color:
	return ORDER_COLORS[posmod(order_id, ORDER_COLORS.size())]


static func restaurant_color(kind: StringName) -> Color:
	return RESTAURANT_COLORS.get(kind, RESTAURANT_DEFAULT)


static func temperature_color(temperature: DishData.Temperature) -> Color:
	match temperature:
		DishData.Temperature.HOT:
			return HOT
		DishData.Temperature.COLD:
			return COLD
	return MUTED


static func bold_font() -> Font:
	if _bold == null:
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.7
		_bold = variation
	return _bold


## The theme of the game screens.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	theme.set_color("font_color", "Label", INK)

	_set_button(theme, "Button", PANEL, INK, 2, FONT_SIZE)
	theme.set_type_variation("AccentButton", "Button")
	_set_button(theme, "AccentButton", ACCENT, Color.WHITE, 2, FONT_SIZE + 1)
	theme.set_type_variation("YesButton", "Button")
	_set_button(theme, "YesButton", OK, Color.WHITE, 2, FONT_SIZE - 1)
	theme.set_type_variation("SmallButton", "Button")
	_set_button(theme, "SmallButton", PANEL, INK, 2, FONT_SIZE - 1)

	theme.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 14, 12))
	theme.set_type_variation("Inset", "PanelContainer")
	theme.set_stylebox("panel", "Inset", box(ROAD, ROAD, 0, RADIUS, 8))
	theme.set_type_variation("Modal", "PanelContainer")
	var modal := box(PANEL, INK, 2, 16, 18)
	modal.shadow_color = INK
	modal.shadow_offset = Vector2(0, 5)
	theme.set_stylebox("panel", "Modal", modal)

	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	theme.set_stylebox("background", "ProgressBar", box(ROAD, ROAD, 0, 3, 0))
	theme.set_stylebox("fill", "ProgressBar", box(OK, OK, 0, 3, 0))
	theme.set_color("font_color", "TooltipLabel", Color.WHITE)
	theme.set_stylebox("panel", "TooltipPanel", box(INK, INK, 0, 6, 8))
	return theme


## A flat box: background, border width and color, corner radius and inner margin.
static func box(color: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func _set_button(theme: Theme, type: String, color: Color, text: Color, border: int, font_size: int) -> void:
	var normal := box(color, INK, border, RADIUS, 6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.shadow_color = INK
	normal.shadow_offset = Vector2(0, 3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lerp(INK, 0.08) if color != PANEL else Color("#f3f4f6")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.shadow_offset = Vector2(0, 1)
	pressed.content_margin_top += 2
	pressed.content_margin_bottom -= 2
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = color.lerp(BACKGROUND, 0.6)
	disabled.border_color = INK.lerp(BACKGROUND, 0.6)
	disabled.shadow_color = disabled.border_color
	var focus := box(Color.TRANSPARENT, MUSTARD, 3, RADIUS + 2, 0)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, disabled)
	theme.set_stylebox("focus", type, focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, text.lerp(BACKGROUND, 0.5))
	theme.set_font("font", type, bold_font())
	theme.set_font_size("font_size", type, font_size)


# --- Widget helpers -------------------------------------------------------------------------

## A label that is not translated again by Godot: every text is passed through tr() by the
## caller, often with values inserted, so the automatic translation must stay off.
static func label(text: String, size: int = FONT_SIZE, color: Color = INK, bold: bool = false) -> Label:
	var out := Label.new()
	out.text = text
	out.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	out.add_theme_font_size_override("font_size", size)
	out.add_theme_color_override("font_color", color)
	if bold:
		out.add_theme_font_override("font", bold_font())
	return out


## A label that wraps on several lines within the width of its parent.
static func paragraph(text: String, size: int = FONT_SIZE, color: Color = INK) -> Label:
	var out := label(text, size, color)
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Without a minimum width, a wrapping label inside a container can shrink to one word per line.
	out.custom_minimum_size.x = 60
	return out


static func button(text: String, on_pressed: Callable, variation: String = "") -> Button:
	var out := Button.new()
	out.text = text
	out.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	out.theme_type_variation = variation
	out.pressed.connect(on_pressed)
	return out


## A small rounded tag (Urgent, VIP...).
static func chip(text: String, color: Color, text_color: Color = Color.WHITE) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := box(color, color, 0, 9, 0)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label(text.to_upper(), 10, text_color, true))
	return panel


static func hbox(separation: int = GAP) -> HBoxContainer:
	var out := HBoxContainer.new()
	out.add_theme_constant_override("separation", separation)
	return out


static func vbox(separation: int = GAP) -> VBoxContainer:
	var out := VBoxContainer.new()
	out.add_theme_constant_override("separation", separation)
	return out


## A panel with a title row (title on the left, an optional detail on the right) above content.
## Returns the content box; the detail label is the title row's last child.
static func titled_panel(title: String, content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var column := vbox(8)
	panel.add_child(column)
	var row := hbox(8)
	row.add_child(label(title, TITLE_FONT_SIZE, INK, true))
	var detail := label("", SMALL_FONT_SIZE, MUTED)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail.name = "Detail"
	row.add_child(detail)
	column.add_child(row)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	return panel


## Removes every child of a container (they are freed at the end of the frame).
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## A vertical scroll area around a box, for lists that can grow.
static func scroll(content: Control) -> ScrollContainer:
	var area := ScrollContainer.new()
	area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(content)
	return area
