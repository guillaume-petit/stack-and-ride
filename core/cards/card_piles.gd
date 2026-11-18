class_name CardPiles
extends RefCounted
## The cards of the night: draw pile, hand and discard pile (design doc §8.3).
##
## They are rebuilt every night from the permanent deck (GameState.deck), so a card added to
## the discard pile during the night (Fatigue) disappears at the end of the night.
## The top of the draw pile is its last element.

var draw_pile: Array[StringName] = []
var hand: Array[StringName] = []
var discard_pile: Array[StringName] = []


## New night: the draw pile is the shuffled deck, the hand and the discard pile are empty.
func start_night(deck: Array[StringName], rng: GameRng) -> void:
	draw_pile = deck.duplicate()
	rng.shuffle(draw_pile)
	hand.clear()
	discard_pile.clear()


## Draws cards into the hand. When the draw pile is empty, the discard pile is shuffled to
## form a new one. Returns the number of cards drawn (fewer when both piles are empty).
func draw(count: int, rng: GameRng) -> int:
	var drawn := 0
	for i in count:
		if draw_pile.is_empty():
			draw_pile = discard_pile
			discard_pile = []
			rng.shuffle(draw_pile)
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn


## Draws until the hand holds size cards (or both piles are empty).
func fill_hand(size: int, rng: GameRng) -> void:
	draw(maxi(0, size - hand.size()), rng)


## Removes the card at this index from the hand and returns it.
func take_from_hand(index: int) -> StringName:
	var card := hand[index]
	hand.remove_at(index)
	return card


func discard(card: StringName) -> void:
	discard_pile.append(card)
