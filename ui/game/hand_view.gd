class_name HandView
extends ScrollContainer
## The cards in hand. A card that cannot be played now is greyed out; clicking a card emits
## card_clicked with its index in the hand.

signal card_clicked(hand_index: int)

const CARD_SIZE := Vector2(112, 132)

var game: Game

var _row: HBoxContainer


func _init() -> void:
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size.y = CARD_SIZE.y + 12
	_row = UiStyle.hbox(8)
	add_child(_row)


func refresh() -> void:
	UiStyle.clear(_row)
	var hand := game.state.piles.hand
	if hand.is_empty():
		_row.add_child(UiStyle.label(UiText.t("HAND_EMPTY"), UiStyle.FONT_SIZE, UiStyle.MUTED))
	for index in hand.size():
		_row.add_child(_card(index))


func _card(index: int) -> ClickCard:
	var content := game.state.content
	var card: CardData = content.cards[game.state.piles.hand[index]]
	var tired := card.removed_when_played
	var view := ClickCard.new(UiStyle.ROAD if tired else UiStyle.PANEL, UiStyle.INK, tired)
	view.custom_minimum_size = CARD_SIZE
	var value := UiText.t("CARD_STEPS") % game.card_steps(card.id) if card.gives_steps() else ("…" if tired else "★")
	view.add(UiStyle.label(value, UiStyle.BIG_FONT_SIZE - 4, UiStyle.MUTED if tired else UiStyle.ACCENT, true))
	view.add(UiStyle.label(UiText.name_of(card), UiStyle.FONT_SIZE - 1, UiStyle.INK, true))
	var description := UiStyle.paragraph(UiText.description_of(card), UiStyle.SMALL_FONT_SIZE - 1, UiStyle.MUTED)
	description.custom_minimum_size.x = CARD_SIZE.x - 20
	view.add(description)
	var tags := PackedStringArray()
	if card.free:
		view.add(UiStyle.label(UiText.t("CARD_TAG_FREE").to_upper(), 10, UiStyle.OK, true))
	if card.shakes and not game.state.effects.cards_never_shake:
		tags.append(UiText.t("CARD_TAG_SHAKE"))
	if card.rating_cost_tenths > 0 and not game.state.effects.no_card_rating_cost:
		tags.append(UiText.stars_change(-card.rating_cost_tenths) + " ★")
	if not tags.is_empty():
		view.add(UiStyle.label(" · ".join(tags).to_upper(), 10, UiStyle.BAD, true))
	var problem := game.card_problem(index)
	view.disabled = problem != Game.Problem.NONE
	view.tooltip_text = UiText.description_of(card) if problem == Game.Problem.NONE else UiText.problem(problem)
	view.pressed.connect(func() -> void: card_clicked.emit(index))
	return view
