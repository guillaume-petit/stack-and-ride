class_name NightDialog
extends Dialog
## End of a night (§9): the accounts, then the free reward to pick, or a button to go to the
## shop when no reward is available.

signal reward_chosen(index: int)
signal continue_pressed


func setup(p_game: Game) -> void:
	super(p_game)
	custom_minimum_size.x = 620
	var state := game.state
	var summary: NightSummary = state.night_summaries.back()
	add_title(UiText.t("NIGHT_END_TITLE") % summary.night)
	body.add_child(ledger(summary, state))
	if state.phase == GameState.Phase.CHOOSING_REWARD:
		add_text(UiText.t("NIGHT_END_REWARD"))
		var row := UiStyle.hbox(10)
		for index in state.reward_choices.size():
			var card := reward_card(state.reward_choices[index], state.content)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.custom_minimum_size.x = 170
			card.pressed.connect(func() -> void: reward_chosen.emit(index))
			row.add_child(card)
		body.add_child(row)
	else:
		add_text(UiText.t("NIGHT_END_NO_REWARD"), UiStyle.MUTED)
		add_buttons([UiStyle.button(UiText.t("NIGHT_END_TO_SHOP"), func() -> void: continue_pressed.emit(), "AccentButton")])
