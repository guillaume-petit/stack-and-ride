class_name GameEvent
extends RefCounted
## Something that happened during the run, for the player's feed, the tests and the bot.
##
## The core never builds player-facing text: the interface turns each kind into a
## translated message.

enum Kind {
	## A night starts (value: night number).
	NIGHT_STARTED,
	## An order was delivered (delivery holds the details).
	DELIVERED,
	## The client cancelled a late order (rating_tenths).
	CANCELLED,
	## The bag was shaken (source: card id or &"paved"; order_ids: damaged dishes; braced).
	SHAKE,
	## Dishes fell and crushed fragile ones (order_ids).
	CRUSHED,
	## A 5th floor delivery waits for a step (order_id). Reported once per order.
	FIFTH_FLOOR_WAIT,
	## Offers left in the app at the end of the turn (value: count).
	OFFERS_IGNORED,
	## A card cost rating, e.g. the Contresens (source: card id, rating_tenths).
	CARD_RATING_COST,
	## Every accepted order got more time, e.g. Coup de fil (value: turns).
	DEADLINES_EXTENDED,
	## The road works moved (Nuit de travaux).
	WORKS_MOVED,
	## The night is over (value: night number).
	NIGHT_ENDED,
}

var kind: Kind
var order_id: int = -1
var order_ids: Array[int] = []
var value: int = 0
var rating_tenths: int = 0
var source: StringName = &""
var braced: bool = false
var delivery: Delivery = null


func _init(p_kind: Kind) -> void:
	kind = p_kind
