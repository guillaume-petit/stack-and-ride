class_name HudBar
extends HBoxContainer
## The top bar: night, turn, rating, wallet, rent, profile and event, a hint for the next
## action and the menu button. A counter with a description shows it when pressed (Toast).
##
## Compact version (phones): the menu button first, no title, wallet and rent together, and the
## hint is left for the game screen to place elsewhere.

signal menu_pressed

## The rating turns red this close (in tenths of a star) to the minimum that ends the run.
const LOW_RATING_MARGIN_TENTHS := 4
## The turn turns red this many turns before the last one.
const LAST_TURNS_WARNING := 1
## Rent not earned yet: the wallet turns red this many turns before the last one.
const RENT_WARNING_TURNS := 2

var game: Game

## What to do next, for a new player (set by GameScreen).
var hint: Label

## Narrowest width of the profile and event counters in the compact bar (their names are cut).
const COMPACT_NAME_WIDTH := 64

var _compact: bool
var _items: HBoxContainer


func _init(compact: bool = false) -> void:
	_compact = compact
	add_theme_constant_override("separation", 8 if compact else 14)
	var menu := UiStyle.button(UiText.t("HUD_MENU"), func() -> void: menu_pressed.emit(), "SmallButton")
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint = UiStyle.paragraph("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.max_lines_visible = 2 if compact else 3
	_items = UiStyle.hbox(6 if compact else 8)
	if compact:
		_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(menu)
		add_child(_items)
		return
	add_child(UiStyle.label(UiText.t("GAME_TITLE"), UiStyle.BIG_FONT_SIZE, UiStyle.ACCENT, true))
	add_child(_items)
	add_child(hint)
	add_child(menu)


func refresh() -> void:
	UiStyle.clear(_items)
	var state := game.state
	var config := state.config
	var live := state.phase == GameState.Phase.PLAYING
	var rent := state.rent_tonight()
	_add(UiText.t("HUD_NIGHT"), "%d/%d" % [state.night, config.nights])
	_add(UiText.t("HUD_TURN"), "%d/%d" % [state.turn, config.turns_per_night],
			UiStyle.BAD if live and state.turn >= config.turns_per_night - LAST_TURNS_WARNING else UiStyle.INK)
	var low_rating := state.rating_tenths < config.min_rating_tenths + LOW_RATING_MARGIN_TENTHS
	var rating := UiText.stars(state.rating_tenths)
	_add(UiText.t("HUD_RATING"), "★ " + rating if _compact else "%s %s" % [UiText.star_bar(state.rating_tenths), rating],
			UiStyle.BAD if low_rating else UiStyle.INK)
	var wallet_color := UiStyle.INK
	if live and state.wallet >= rent:
		wallet_color = UiStyle.OK
	elif live and state.turn >= config.turns_per_night - RENT_WARNING_TURNS:
		wallet_color = UiStyle.BAD
	if _compact:
		_add(UiText.t("HUD_WALLET_RENT"), "%s / %s" % [UiText.euros(state.wallet), UiText.euros(rent)], wallet_color)
	else:
		_add(UiText.t("HUD_WALLET"), UiText.euros(state.wallet), wallet_color)
		_add(UiText.t("HUD_RENT"), UiText.euros(rent))
	if state.profile != &"":
		var profile: ProfileData = state.content.profiles[state.profile]
		_shrinkable(_add(UiText.t("HUD_PROFILE"), UiText.name_of(profile), UiStyle.INK,
				UiText.description_of(profile)))
		var event: EventData = state.content.events[state.event]
		_shrinkable(_add(UiText.t("HUD_EVENT"), UiText.name_of(event), UiStyle.ACCENT if event.drawable else UiStyle.INK,
				UiText.description_of(event)))
	if not state.equipment.is_empty():
		var names := PackedStringArray()
		for id in state.equipment:
			names.append(UiText.name_of(state.content.equipment[id]))
		_add(UiText.t("HUD_EQUIPMENT"), str(state.equipment.size()), UiStyle.INK, "\n".join(names))


func _add(title: String, value: String, color: Color = UiStyle.INK, tooltip: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	var style := UiStyle.box(UiStyle.PANEL, UiStyle.ACCENT if color == UiStyle.ACCENT else UiStyle.LINE, 1, UiStyle.RADIUS, 4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = tooltip
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if tooltip != "" else Control.MOUSE_FILTER_IGNORE
	if tooltip != "":
		UiStyle.explain_on_press(panel)
	var column := UiStyle.vbox(0)
	column.add_child(UiStyle.label(title.to_upper(), 10, UiStyle.MUTED, true))
	column.add_child(UiStyle.label(value, UiStyle.FONT_SIZE + 1, color, true))
	panel.add_child(column)
	_items.add_child(panel)
	return panel


## In the compact bar, a long name is cut with "…" rather than pushing the bar off the screen.
func _shrinkable(panel: PanelContainer) -> void:
	if not _compact:
		return
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = COMPACT_NAME_WIDTH
	for label in panel.find_children("*", "Label", true, false):
		(label as Label).clip_text = true
		(label as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
