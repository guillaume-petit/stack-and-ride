class_name HandFan
extends Control
## The cards in hand, fanned out at the bottom of the screen as if held: they overlap when the
## screen is narrow, each one slightly turned. A card that cannot be played now is greyed out;
## clicking a card emits card_clicked with its index in the hand. The cards are dealt (they
## appear one after the other) at each new turn.
##
## The cards are placed by hand, not by a container: a container would reset their rotation.

signal card_clicked(hand_index: int)

const CARD_SIZE := Vector2(124, 140)
## Turn between two neighbour cards, in degrees, and how much lower the outer cards sit.
const TILT_DEGREES := 3.0
const DROP := 5.0
const GAP := 8.0
## Room left on each side of the hand.
const SIDE := 14.0

var game: Game
## Size of a card (smaller on a phone).
var card_size := CARD_SIZE

var _cards: Array[ClickCard] = []
## Height of every card: the tallest one's, so that the hand stays even.
var _height: float = 0.0
var _empty: Label
var _dealt_turn: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty = UiStyle.paragraph(UiText.t("HAND_EMPTY"), UiStyle.FONT_SIZE, UiStyle.MUTED)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_empty)
	resized.connect(_place)


func refresh() -> void:
	for card in _cards:
		remove_child(card)
		card.queue_free()
	_cards.clear()
	var state := game.state
	var turn := state.night * 100 + state.turn
	var deal := turn != _dealt_turn and state.phase == GameState.Phase.PLAYING
	if deal:
		_dealt_turn = turn
	for index in state.piles.hand.size():
		var card := make_card(game, index, card_size.x)
		card.custom_minimum_size = card_size
		card.pressed.connect(func() -> void: card_clicked.emit(index))
		add_child(card)
		_cards.append(card)
	_empty.visible = _cards.is_empty()
	_height = card_size.y
	for card in _cards:
		_height = maxf(_height, card.get_combined_minimum_size().y)
	custom_minimum_size.y = _height + DROP * 4
	_place()
	if deal:
		for index in _cards.size():
			Motion.appear(_cards[index], index * Motion.STAGGER, true)


## Spreads the cards along the width, overlapping them if needed, the middle ones higher.
func _place() -> void:
	var count := _cards.size()
	if count == 0:
		return
	var step := card_size.x + GAP
	if count > 1:
		step = minf(step, (size.x - 2 * SIDE - card_size.x) / (count - 1))
	var left := (size.x - card_size.x - step * (count - 1)) / 2
	var middle := (count - 1) / 2.0
	for index in count:
		var card := _cards[index]
		var offset := index - middle
		card.size = Vector2(card_size.x, _height)
		card.pivot_offset = Vector2(card_size.x / 2, card.size.y)
		card.position = Vector2(left + index * step, DROP + offset * offset * DROP * 0.6)
		card.rotation_degrees = offset * TILT_DEGREES


## A card of the hand: its steps (or a star), name, description and tags. Greyed out when it
## cannot be played now, with the reason as its tooltip.
static func make_card(p_game: Game, index: int, width: float = CARD_SIZE.x) -> ClickCard:
	var state := p_game.state
	var card: CardData = state.content.cards[state.piles.hand[index]]
	var tired := card.removed_when_played
	var view := ClickCard.new(UiStyle.ROAD if tired else UiStyle.PANEL, UiStyle.INK, tired)
	view.sound = Sfx.Sound.CARD
	var value := UiText.t("CARD_STEPS") % p_game.card_steps(card.id) if card.gives_steps() else ("…" if tired else "★")
	view.add(UiStyle.label(value, UiStyle.BIG_FONT_SIZE - 4, UiStyle.MUTED if tired else UiStyle.ACCENT, true))
	view.add(UiStyle.label(UiText.name_of(card), UiStyle.FONT_SIZE - 1, UiStyle.INK, true))
	var description := UiStyle.paragraph(UiText.description_of(card), UiStyle.SMALL_FONT_SIZE - 1, UiStyle.MUTED)
	# Its width sets its height: without it, the text would wrap one word per line.
	description.custom_minimum_size.x = width - 22
	view.add(description)
	var tags := PackedStringArray()
	if card.free:
		view.add(UiStyle.label(UiText.t("CARD_TAG_FREE").to_upper(), 10, UiStyle.OK, true))
	if card.shakes and not state.effects.cards_never_shake:
		tags.append(UiText.t("CARD_TAG_SHAKE"))
	if card.rating_cost_tenths > 0 and not state.effects.no_card_rating_cost:
		tags.append(UiText.stars_change(-card.rating_cost_tenths) + " ★")
	if not tags.is_empty():
		view.add(UiStyle.label(" · ".join(tags).to_upper(), 10, UiStyle.BAD, true))
	var problem := p_game.card_problem(index)
	view.disabled = problem != Game.Problem.NONE
	view.tooltip_text = UiText.description_of(card) if problem == Game.Problem.NONE else UiText.problem(problem)
	return view
