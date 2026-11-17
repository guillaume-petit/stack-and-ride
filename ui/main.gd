extends Control
## Temporary start screen. It only proves that the project boots,
## that translations load and that the layout scales in landscape.

const BACKGROUND := Color("#eceff3")
const INK := Color("#1a1e24")
const ACCENT := Color("#e2452b")
const MUTED := Color("#5d6570")


func _ready() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	column.add_child(_label(tr("GAME_TITLE"), 72, ACCENT))
	column.add_child(_label(tr("GAME_TAGLINE"), 28, INK))
	column.add_child(_label(tr("MENU_COMING_SOON"), 18, MUTED))
	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	column.add_child(_label(tr("MENU_VERSION") % version, 16, MUTED))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
