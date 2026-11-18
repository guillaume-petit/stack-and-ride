class_name ProfileDialog
extends Dialog
## Start of the run: the player picks a profile for the whole run (§11).

signal profile_chosen(id: StringName)


func setup(p_game: Game) -> void:
	super(p_game)
	custom_minimum_size.x = 640
	add_title(UiText.t("PROFILE_TITLE"))
	add_text(UiText.t("PROFILE_INTRO"), UiStyle.MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in game.state.content.profile_ids():
		var profile: ProfileData = game.state.content.profiles[id]
		var card := ClickCard.new(UiStyle.BACKGROUND, UiStyle.LINE)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add(UiStyle.label(UiText.t("PROFILE_KIND").to_upper(), 10, UiStyle.ACCENT, true))
		card.add(UiStyle.label(UiText.name_of(profile), UiStyle.TITLE_FONT_SIZE, UiStyle.INK, true))
		card.add(UiStyle.paragraph(UiText.description_of(profile), UiStyle.SMALL_FONT_SIZE + 1, UiStyle.MUTED))
		card.pressed.connect(func() -> void: profile_chosen.emit(id))
		grid.add_child(card)
	body.add_child(grid)
