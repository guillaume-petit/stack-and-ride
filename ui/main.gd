extends Control
## Start screen: title, new run, quit. The full menus (continue, options) come with saving
## (iteration 6).

const GAME_SCREEN := "res://ui/game/game_screen.tscn"


func _ready() -> void:
	Device.apply_scale(get_window())
	theme = UiStyle.make_theme()
	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := UiStyle.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	column.add_child(_centered(UiStyle.label(UiText.t("GAME_TITLE"), 72, UiStyle.ACCENT, true)))
	column.add_child(_centered(UiStyle.label(UiText.t("GAME_TAGLINE"), 28, UiStyle.INK)))
	column.add_child(_centered(UiStyle.label(UiText.t("MENU_PITCH"), 17, UiStyle.MUTED)))

	var buttons := UiStyle.vbox(12)
	buttons.custom_minimum_size = Vector2(280, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var play := UiStyle.button(UiText.t("MENU_NEW_RUN"), _on_new_run, "AccentButton")
	play.custom_minimum_size.y = 48
	buttons.add_child(play)
	# There is no window to close on phones: quitting is left to the system there.
	if not OS.has_feature("mobile"):
		buttons.add_child(UiStyle.button(UiText.t("MENU_QUIT"), func() -> void: get_tree().quit()))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	column.add_child(spacer)
	column.add_child(buttons)
	play.grab_focus()

	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	var footer := UiStyle.label(UiText.t("MENU_VERSION") % version, 14, UiStyle.MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(footer)


## The back button of Android leaves the game from the start screen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _on_new_run() -> void:
	get_tree().change_scene_to_file(GAME_SCREEN)


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
