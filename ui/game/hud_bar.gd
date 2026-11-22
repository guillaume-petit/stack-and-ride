class_name HudBar
extends HBoxContainer
## The top bar: the menu, then night, turn, rating, wallet and rent. A counter that changes
## pulses; one with a description shows it when pressed (Toast).
##
## On a wide screen the profile, the event of the night and the equipment follow, by name. On a
## narrow one (a phone), the bar keeps to one line: they hide behind an (i) button on the right,
## lit when the night has a special event.

signal menu_pressed
## The (i) button of the narrow bar: show the profile, the event and the equipment.
signal info_pressed

## The rating turns red this close (in tenths of a star) to the minimum that ends the run.
const LOW_RATING_MARGIN_TENTHS := 4
## The turn turns red this many turns before the last one.
const LAST_TURNS_WARNING := 1
## Rent not earned yet: the wallet turns red this many turns before the last one.
const RENT_WARNING_TURNS := 2
const ICON_SIZE := 46.0

var game: Game
## Only in the narrow bar.
var info_button: IconButton

var _narrow: bool
var _items: HBoxContainer
## Value of each counter at the last refresh, by title: a counter that changed pulses.
var _values: Dictionary[String, String] = {}
var _new_values: Dictionary[String, String] = {}


func _init(narrow: bool = false) -> void:
	_narrow = narrow
	add_theme_constant_override("separation", 6 if narrow else 10)
	var menu := IconButton.new(IconButton.Icon.MENU, ICON_SIZE)
	menu.tooltip_text = UiText.t("HUD_MENU")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(menu)
	_items = UiStyle.hbox(5 if narrow else 8)
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_items)
	if narrow:
		info_button = IconButton.new(IconButton.Icon.INFO, ICON_SIZE)
		info_button.pressed.connect(func() -> void: info_pressed.emit())
		add_child(info_button)


func refresh() -> void:
	UiStyle.clear(_items)
	_new_values = {}
	var state := game.state
	var config := state.config
	var live := state.phase == GameState.Phase.PLAYING
	var rent := state.rent_tonight()
	_add(UiText.t("HUD_NIGHT"), "%d/%d" % [state.night, config.nights])
	_add(UiText.t("HUD_TURN"), "%d/%d" % [state.turn, config.turns_per_night],
			UiStyle.BAD if live and state.turn >= config.turns_per_night - LAST_TURNS_WARNING else UiStyle.INK)
	var low_rating := state.rating_tenths < config.min_rating_tenths + LOW_RATING_MARGIN_TENTHS
	_add(UiText.t("HUD_RATING"), "★ " + UiText.stars(state.rating_tenths), UiStyle.BAD if low_rating else UiStyle.INK)
	var wallet_color := UiStyle.INK
	if live and state.wallet >= rent:
		wallet_color = UiStyle.OK
	elif live and state.turn >= config.turns_per_night - RENT_WARNING_TURNS:
		wallet_color = UiStyle.BAD
	_add(UiText.t("HUD_WALLET_RENT"), "%s / %s" % [UiText.euros(state.wallet), UiText.euros(rent)], wallet_color)
	if state.profile != &"":
		_add_profile(state)
	_values = _new_values


func _add_profile(state: GameState) -> void:
	var event: EventData = state.content.events[state.event]
	if _narrow:
		info_button.lit = event.drawable
		info_button.tooltip_text = info_text(state)
	else:
		var profile: ProfileData = state.content.profiles[state.profile]
		_add(UiText.t("HUD_PROFILE"), UiText.name_of(profile), UiStyle.INK, UiText.description_of(profile))
		_add(UiText.t("HUD_EVENT"), UiText.name_of(event), UiStyle.ACCENT if event.drawable else UiStyle.INK,
				UiText.description_of(event))
		if not state.equipment.is_empty():
			_add(UiText.t("HUD_EQUIPMENT"), str(state.equipment.size()), UiStyle.INK, _equipment(state))


## What the (i) of the narrow bar shows: the profile, the event of the night and the equipment.
static func info_text(state: GameState) -> String:
	var profile: ProfileData = state.content.profiles[state.profile]
	var event: EventData = state.content.events[state.event]
	var lines := PackedStringArray([
		UiText.t("HUD_INFO_LINE") % [UiText.t("HUD_PROFILE"), UiText.name_of(profile), UiText.description_of(profile)],
		UiText.t("HUD_INFO_LINE") % [UiText.t("HUD_EVENT"), UiText.name_of(event), UiText.description_of(event)],
	])
	if not state.equipment.is_empty():
		lines.append(UiText.t("HUD_INFO_EQUIPMENT") % [UiText.t("HUD_EQUIPMENT"), _equipment(state).replace("\n", ", ")])
	return "\n\n".join(lines)


static func _equipment(state: GameState) -> String:
	var names := PackedStringArray()
	for id in state.equipment:
		names.append(UiText.name_of(state.content.equipment[id]))
	return "\n".join(names)


func _add(title: String, value: String, color: Color = UiStyle.INK, tooltip: String = "") -> void:
	var panel := PanelContainer.new()
	var style := UiStyle.box(UiStyle.PANEL, UiStyle.ACCENT if color == UiStyle.ACCENT else UiStyle.LINE, 1, UiStyle.RADIUS, 4)
	style.content_margin_left = 8 if _narrow else 10
	style.content_margin_right = 8 if _narrow else 10
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.tooltip_text = tooltip
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if tooltip != "" else Control.MOUSE_FILTER_IGNORE
	if tooltip != "":
		UiStyle.explain_on_press(panel)
	var column := UiStyle.vbox(0)
	column.add_child(UiStyle.label(title.to_upper(), 10, UiStyle.MUTED, true))
	column.add_child(UiStyle.label(value, UiStyle.FONT_SIZE + 1, color, true))
	panel.add_child(column)
	_items.add_child(panel)
	_new_values[title] = value
	if _values.has(title) and _values[title] != value:
		Motion.pulse(panel)
