extends TestCase
## Draw pile, hand and discard pile (design doc §8.3).

var piles: CardPiles
var rng: GameRng


func before_each() -> void:
	piles = CardPiles.new()
	rng = GameRng.new(4)


func test_a_night_starts_with_the_whole_deck_shuffled() -> void:
	var deck: Array[StringName] = [&"a", &"b", &"c", &"d", &"e"]
	piles.hand = [&"old"] as Array[StringName]
	piles.discard_pile = [&"old"] as Array[StringName]
	piles.start_night(deck, rng)
	assert_eq(piles.hand, [])
	assert_eq(piles.discard_pile, [])
	var sorted := piles.draw_pile.duplicate()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	assert_eq(sorted, deck)
	assert_eq(deck, [&"a", &"b", &"c", &"d", &"e"], "the permanent deck is not changed")


func test_draw_takes_the_top_of_the_draw_pile() -> void:
	piles.draw_pile = [&"a", &"b", &"c"] as Array[StringName]
	assert_eq(piles.draw(2, rng), 2)
	assert_eq(piles.hand, [&"c", &"b"])
	assert_eq(piles.draw_pile, [&"a"])


func test_the_discard_pile_is_shuffled_when_the_draw_pile_is_empty() -> void:
	piles.draw_pile = [&"a"] as Array[StringName]
	piles.discard_pile = [&"b", &"c"] as Array[StringName]
	assert_eq(piles.draw(3, rng), 3)
	assert_eq(piles.hand.size(), 3)
	assert_eq(piles.hand[0], &"a")
	assert_eq(piles.discard_pile, [])
	assert_eq(piles.draw_pile, [])


func test_draw_stops_when_both_piles_are_empty() -> void:
	piles.draw_pile = [&"a"] as Array[StringName]
	assert_eq(piles.draw(4, rng), 1)
	assert_eq(piles.hand, [&"a"])


func test_fill_hand_keeps_the_cards_in_hand() -> void:
	piles.hand = [&"kept"] as Array[StringName]
	piles.draw_pile = [&"a", &"b", &"c", &"d", &"e"] as Array[StringName]
	piles.fill_hand(4, rng)
	assert_eq(piles.hand, [&"kept", &"e", &"d", &"c"])
	piles.fill_hand(4, rng)
	assert_eq(piles.hand.size(), 4, "a full hand draws nothing")


func test_take_from_hand_and_discard() -> void:
	piles.hand = [&"a", &"b"] as Array[StringName]
	assert_eq(piles.take_from_hand(1), &"b")
	piles.discard(&"b")
	assert_eq(piles.hand, [&"a"])
	assert_eq(piles.discard_pile, [&"b"])


func test_cards_added_during_the_night_disappear_with_it() -> void:
	var deck: Array[StringName] = [&"a"]
	piles.start_night(deck, rng)
	piles.discard(&"fatigue")
	piles.start_night(deck, rng)
	assert_eq(piles.draw_pile, [&"a"])
	assert_eq(piles.discard_pile, [])
