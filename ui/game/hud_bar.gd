class_name HudBar
extends HBoxContainer
## The top bar: night, turn, rating, wallet, rent, profile and event, a hint for the next
## action and the menu button.

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

var _items: HBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 14)
	var title := UiStyle.label(UiText.t("GAME_TITLE"), UiStyle.BIG_FONT_SIZE, UiStyle.ACCENT, true)
	add_child(title)
	_items = UiStyle.hbox(8)
	add_child(_items)
	hint = UiStyle.paragraph("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.max_lines_visible = 3
	add_child(hint)
	var menu := UiStyle.button(UiText.t("HUD_MENU"), func() -> void: menu_pressed.emit(), "SmallButton")
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_add(UiText.t("HUD_RATING"), "%s %s" % [UiText.star_bar(state.rating_tenths), UiText.stars(state.rating_tenths)],
			UiStyle.BAD if low_rating else UiStyle.INK)
	var wallet_color := UiStyle.INK
	if live and state.wallet >= rent:
		wallet_color = UiStyle.OK
	elif live and state.turn >= config.turns_per_night - RENT_WARNING_TURNS:
		wallet_color = UiStyle.BAD
	_add(UiText.t("HUD_WALLET"), UiText.euros(state.wallet), wallet_color)
	_add(UiText.t("HUD_RENT"), UiText.euros(rent))
	if state.profile != &"":
		var profile: ProfileData = state.content.profiles[state.profile]
		_add(UiText.t("HUD_PROFILE"), UiText.name_of(profile), UiStyle.INK, UiText.description_of(profile))
		var event: EventData = state.content.events[state.event]
		_add(UiText.t("HUD_EVENT"), UiText.name_of(event), UiStyle.ACCENT if event.drawable else UiStyle.INK,
				UiText.description_of(event))
	if not state.equipment.is_empty():
		var names := PackedStringArray()
		for id in state.equipment:
			names.append(UiText.name_of(state.content.equipment[id]))
		_add(UiText.t("HUD_EQUIPMENT"), str(state.equipment.size()), UiStyle.INK, "\n".join(names))


func _add(title: String, value: String, color: Color = UiStyle.INK, tooltip: String = "") -> void:
	var panel := PanelContainer.new()
	var style := UiStyle.box(UiStyle.PANEL, UiStyle.ACCENT if color == UiStyle.ACCENT else UiStyle.LINE, 1, UiStyle.RADIUS, 4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = tooltip
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if tooltip != "" else Control.MOUSE_FILTER_IGNORE
	var column := UiStyle.vbox(0)
	column.add_child(UiStyle.label(title.to_upper(), 10, UiStyle.MUTED, true))
	column.add_child(UiStyle.label(value, UiStyle.FONT_SIZE + 1, color, true))
	panel.add_child(column)
	_items.add_child(panel)
