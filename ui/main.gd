extends Control
## Start screen: continue the saved run, start a new one, read how to play, change the options,
## quit (computers only).

const GAME_SCREEN := "res://ui/game/game_screen.tscn"

## The run saved, played again to check that it still works (null when none).
var _saved: Game = null
var _buttons: VBoxContainer
## Window over the menu (how to play, options, new run), with the menu dimmed behind it.
var _overlay: Control
var _overlay_center: CenterContainer


func _ready() -> void:
	Settings.use_file()
	Settings.apply(get_window())
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
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	column.add_child(spacer)

	_buttons = UiStyle.vbox(12)
	_buttons.custom_minimum_size = Vector2(300, 0)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_buttons)

	var broken := _load_save()
	if _saved != null:
		var resume := _add_button(UiText.t("MENU_CONTINUE"), _start_game, "AccentButton")
		var detail := _centered(UiStyle.label(UiText.saved_run(_saved.state), UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		_buttons.add_child(detail)
		_add_button(UiText.t("MENU_NEW_RUN"), _ask_new_run)
		resume.grab_focus()
	else:
		_add_button(UiText.t("MENU_NEW_RUN"), _new_run, "AccentButton").grab_focus()
	_add_button(UiText.t("MENU_HOW_TO_PLAY"), _show_how_to_play)
	_add_button(UiText.t("MENU_OPTIONS"), func() -> void: _show(OptionsDialog.new()))
	# There is no window to close on phones: quitting is left to the system there.
	if not OS.has_feature("mobile"):
		_add_button(UiText.t("MENU_QUIT"), func() -> void: get_tree().quit())
	if broken:
		var warning := UiStyle.paragraph(UiText.t("MENU_SAVE_BROKEN"), UiStyle.SMALL_FONT_SIZE, UiStyle.BAD)
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_buttons.add_child(warning)

	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	var footer := UiStyle.label(UiText.t("MENU_VERSION") % version, 14, UiStyle.MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(footer)
	_build_overlay()


## Reads the saved run. Returns true when there was one that no longer works with this version
## of the game: it is erased.
func _load_save() -> bool:
	if not RunSave.has_save():
		return false
	var content := GameContent.load_from()
	_saved = RunSave.load_game(content)
	if _saved == null:
		RunSave.erase()
		return true
	return false


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.BACKGROUND, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(scroll)
	_overlay_center = CenterContainer.new()
	_overlay_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_overlay_center)
	add_child(_overlay)


## Shows a window over the menu; its signal "closed" (or a button) closes it.
func _show(dialog: Dialog) -> void:
	_close()
	dialog.narrow = Device.is_narrow(size)
	dialog.setup(null)
	dialog.custom_minimum_size.x = minf(dialog.custom_minimum_size.x, size.x - 24)
	if dialog.has_signal("closed"):
		dialog.connect("closed", _close)
	_overlay_center.add_child(dialog)
	_overlay.visible = true
	Motion.appear(dialog)


func _close() -> void:
	UiStyle.clear(_overlay_center)
	_overlay.visible = false


## Read here, the rules do not open again before the first run.
func _show_how_to_play() -> void:
	var how_to := HowToPlayDialog.new()
	how_to.closed.connect(func() -> void:
		Settings.how_to_play_seen = true
		Settings.save())
	_show(how_to)


## A run is saved: starting a new one loses it, so the player confirms.
func _ask_new_run() -> void:
	var confirm := Dialog.new()
	confirm.custom_minimum_size.x = 420
	confirm.add_title(UiText.t("MENU_NEW_RUN_TITLE"))
	confirm.add_text(UiText.t("MENU_NEW_RUN_TEXT"), UiStyle.MUTED)
	confirm.add_buttons([
		UiStyle.button(UiText.t("MENU_CANCEL"), _close),
		UiStyle.button(UiText.t("MENU_NEW_RUN_CONFIRM"), _new_run, "AccentButton"),
	])
	_show(confirm)


## The game screen resumes the saved run when there is one: erasing it starts a new run.
func _new_run() -> void:
	RunSave.erase()
	_start_game()


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCREEN)


## The back button of Android closes the window open, or leaves the game.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _overlay != null and _overlay.visible:
		_close()
	else:
		get_tree().quit()


func _add_button(text: String, on_pressed: Callable, variation: String = "") -> Button:
	var button := UiStyle.button(text, on_pressed, variation)
	button.custom_minimum_size.y = 48
	_buttons.add_child(button)
	return button


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
