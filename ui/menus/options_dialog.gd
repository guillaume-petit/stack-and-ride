class_name OptionsDialog
extends Dialog
## The options: volume of the sounds, size of the interface, full screen (computers), help bubbles.
## Every change applies at once and is saved (see Settings).

signal closed

## Width of the slider of the volume.
const SLIDER_WIDTH := 200
const VOLUME_STEP := 10


func setup(p_game: Game) -> void:
	super(p_game)
	custom_minimum_size.x = 480
	add_title(UiText.t("OPTIONS_TITLE"))

	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = VOLUME_STEP
	volume.value = roundf(Settings.volume * 100)
	volume.custom_minimum_size.x = SLIDER_WIDTH
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var volume_text := UiStyle.label(_volume_text(volume.value), UiStyle.FONT_SIZE, UiStyle.MUTED)
	volume_text.custom_minimum_size.x = 56
	volume.value_changed.connect(func(value: float) -> void:
		volume_text.text = _volume_text(value)
		Settings.volume = value / 100.0
		_apply())
	# A sound when the slider is let go, to hear the new volume.
	volume.drag_ended.connect(func(_changed: bool) -> void: Sfx.play(Sfx.Sound.CLICK))
	var volume_box := UiStyle.hbox(8)
	volume_box.add_child(volume)
	volume_box.add_child(volume_text)
	_add_row(UiText.t("OPTIONS_VOLUME"), volume_box)

	var size_names: Array[String] = []
	for i in Settings.UI_SIZES.size():
		size_names.append(UiText.t("OPTIONS_SIZE_%d" % i))
	var sizes := _choices(size_names, Settings.UI_SIZES.find(Settings.ui_size), func(index: int) -> void:
		Settings.ui_size = Settings.UI_SIZES[index]
		_apply())
	for choice in sizes.get_children():
		(choice as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(UiStyle.label(UiText.t("OPTIONS_SIZE")))
	body.add_child(sizes)

	if Settings.can_go_fullscreen():
		_add_row(UiText.t("OPTIONS_FULLSCREEN"), _on_off(Settings.fullscreen, func(on: bool) -> void:
			Settings.fullscreen = on
			_apply()))

	_add_row(UiText.t("OPTIONS_HELP"), _on_off(Settings.help_bubbles, func(on: bool) -> void:
		Settings.help_bubbles = on
		_apply()))
	var restart_help := UiStyle.button(UiText.t("OPTIONS_HELP_RESTART"), func() -> void: pass, "SmallButton")
	restart_help.pressed.connect(func() -> void:
		Settings.helps_seen.clear()
		Settings.how_to_play_seen = false
		Settings.help_bubbles = true
		Settings.save()
		restart_help.text = UiText.t("OPTIONS_HELP_RESTARTED")
		restart_help.disabled = true)
	restart_help.tooltip_text = UiText.t("OPTIONS_HELP_RESTARTED")
	restart_help.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(restart_help)

	add_buttons([UiStyle.button(UiText.t("OPTIONS_CLOSE"), func() -> void: closed.emit(), "AccentButton")])


## A line of the options: its name on the left, its control on the right.
func _add_row(title: String, control: Control) -> void:
	var row := UiStyle.hbox(12)
	var name_label := UiStyle.label(title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	row.add_child(control)
	body.add_child(row)


## Buttons side by side, one of them chosen; picked(index) is called with the new choice.
func _choices(names: Array[String], chosen: int, picked: Callable) -> HBoxContainer:
	var row := UiStyle.hbox(6)
	var group := ButtonGroup.new()
	for i in names.size():
		var choice := UiStyle.button(names[i], picked.bind(i), "ChoiceButton")
		choice.toggle_mode = true
		choice.button_group = group
		choice.button_pressed = i == chosen
		row.add_child(choice)
	return row


## "No" and "Yes": changed(on) is called with the new choice.
func _on_off(on: bool, changed: Callable) -> HBoxContainer:
	return _choices([UiText.t("OPTIONS_OFF"), UiText.t("OPTIONS_ON")], 1 if on else 0,
			func(index: int) -> void: changed.call(index == 1))


func _apply() -> void:
	if is_inside_tree():
		Settings.apply(get_window())
	Settings.save()


static func _volume_text(value: float) -> String:
	return UiText.t("OPTIONS_VOLUME_OFF") if value <= 0 else "%d %%" % value
