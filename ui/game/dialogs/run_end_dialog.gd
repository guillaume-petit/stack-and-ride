class_name RunEndDialog
extends Dialog
## End of the run: won after the last night, or lost (rent not paid, rating too low).

signal new_run_pressed
signal menu_pressed


func setup(p_game: Game) -> void:
	super(p_game)
	custom_minimum_size.x = 520
	var state := game.state
	var won := state.phase == GameState.Phase.WON
	var key: String = "WON" if won else GameState.LossReason.keys()[state.loss_reason]
	add_title(UiText.t("RUN_END_TITLE_" + key))
	# The accounts are only shown when the run ended with the night (not during a turn).
	var summary: NightSummary = state.night_summaries.back() if not state.night_summaries.is_empty() else null
	if summary != null and summary.night == state.night:
		body.add_child(ledger(summary, state))
	var text := UiText.t("RUN_END_TEXT_" + key)
	if not won and state.loss_reason == GameState.LossReason.RENT and summary != null:
		text = text % UiText.euros(summary.shortfall)
	elif not won and state.loss_reason == GameState.LossReason.RATING:
		text = text % UiText.stars(state.config.min_rating_tenths)
	add_text(text)
	var deliveries := 0
	for event in state.history:
		if event.kind == GameEvent.Kind.DELIVERED:
			deliveries += 1
	add_text(UiText.t("RUN_END_STATS") % [state.night, deliveries, UiText.euros(state.total_earnings),
			UiText.stars(state.rating_tenths)], UiStyle.MUTED)
	add_buttons([
		UiStyle.button(UiText.t("RUN_END_MENU"), func() -> void: menu_pressed.emit()),
		UiStyle.button(UiText.t("RUN_END_NEW_RUN"), func() -> void: new_run_pressed.emit(), "AccentButton"),
	])
