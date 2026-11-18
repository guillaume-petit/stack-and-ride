class_name CardData
extends ContentData
## A movement card (design doc §8.3).
##
## The rules that use these fields are in Game.play_card().

## Base number of steps (0 for cards that give no steps).
@export var steps: int = 0
## Extra steps when a non-free card was already played this turn (Feu orange).
@export var steps_bonus_if_not_first: int = 0
## Free cards do not count towards the cards-per-turn limit.
@export var free: bool = false
## Playing the card shakes the bag.
@export var shakes: bool = false
## Playing the card puts a Fatigue card in the discard pile.
@export var adds_fatigue: bool = false
## Road works can be crossed until the end of the turn (Contresens).
@export var crosses_works: bool = false
## Rating lost when playing the card, in tenths of a star.
@export var rating_cost_tenths: int = 0
## Number of cards drawn when playing the card.
@export var draws: int = 0
## Extra turns of deadline given to every accepted order (Coup de fil).
@export var deadline_bonus: int = 0
## Cancels the next shake of the turn (Caler le sac).
@export var cancels_next_shake: bool = false
## Removed from the game once played (Fatigue).
@export var removed_when_played: bool = false
## Removed from the deck at the end of the night (Fatigue). The rules need not read it: such a
## card only enters the discard pile, never the permanent deck, and CardPiles.start_night()
## rebuilds the piles from that deck.
@export var temporary: bool = false
## Price in the shop; 0 means the card is never sold nor offered as a reward.
@export var shop_price: int = 0


func gives_steps() -> bool:
	return steps > 0


func _key_prefix() -> String:
	return "CARD"
