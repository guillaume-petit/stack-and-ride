class_name EndTurnButton
extends ClickCard
## The end-of-turn button, which also shows the cards of the turn: one small card per card that
## may be played, filled once played, and the cards left in the draw pile.

const PIP_SIZE := Vector2(11, 15)
const PIP_GAP := 4.0

var game: Game

var _title: Label
var _pips: Control
var _pile: Label


func _init() -> void:
	super(UiStyle.ACCENT, UiStyle.INK)
	sound = Sfx.Sound.CLICK
	_title = UiStyle.label("", UiStyle.FONT_SIZE + 2, Color.WHITE, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(_title)
	var row := UiStyle.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips = Control.new()
	_pips.draw.connect(_draw_pips)
	row.add_child(_pips)
	_pile = UiStyle.label("", UiStyle.SMALL_FONT_SIZE, Color(1, 1, 1, 0.85), true)
	row.add_child(_pile)
	add(row)
	custom_minimum_size.x = 150


func refresh() -> void:
	var state := game.state
	var last_turn := state.turn >= state.config.turns_per_night
	_title.text = UiText.t("TURN_END_NIGHT" if last_turn else "TURN_END")
	_pile.text = UiText.t("TURN_DRAW_PILE") % state.piles.draw_pile.size()
	_pips.custom_minimum_size = Vector2(state.max_paid_cards() * (PIP_SIZE.x + PIP_GAP) - PIP_GAP, PIP_SIZE.y)
	_pips.queue_redraw()
	var problem := game.end_turn_problem()
	disabled = problem != Game.Problem.NONE
	tooltip_text = UiText.problem(problem) if disabled else UiText.t("TURN_CARDS_TOOLTIP") % [
			state.paid_cards_played, state.max_paid_cards()]


## One small card per card that may be played this turn: filled once played.
func _draw_pips() -> void:
	var state := game.state
	for index in state.max_paid_cards():
		var rect := Rect2(Vector2(index * (PIP_SIZE.x + PIP_GAP), 0), PIP_SIZE)
		var style := UiStyle.box(Color.WHITE if index < state.paid_cards_played else Color.TRANSPARENT,
				Color.WHITE, 2, 3, 0)
		_pips.draw_style_box(style, rect)
