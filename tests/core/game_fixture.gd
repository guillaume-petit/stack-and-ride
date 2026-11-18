class_name GameFixture
extends RefCounted
## Builds a run for the tests on a hand-drawn city (see City.from_text()), with a neutral
## profile, an empty app, an empty hand and an empty history, so that each test only sets
## up what it checks.

## Profile without any effect, added to the content of the fixture only.
const NEUTRAL_PROFILE := &"neutral"

## A small city: the base at (0, 0), a restaurant at (1, 0), clients 1 to 4 at (3, 0),
## (2, 1), (0, 2) and (3, 2). The street (1, 1)-(2, 1) is paved, (3, 1)-(3, 2) has road works.
##     B-R-+-C
##     | | | |
##     +-+~C-+
##     | | | #
##     C-+-+-C
const CITY: Array[String] = [
	"B-R-+-C",
	"| | | |",
	"+-+~C-+",
	"| | | #",
	"C-+-+-C",
]
const BASE := Vector2i(0, 0)
const RESTAURANT := Vector2i(1, 0)
const CLIENT_1 := Vector2i(3, 0)
const CLIENT_2 := Vector2i(2, 1)
const CLIENT_3 := Vector2i(0, 2)
const CLIENT_4 := Vector2i(3, 2)

var content: GameContent
var game: Game
var state: GameState


## A run at night 1, turn 1. restaurant_kind gives the menu of the restaurants of the city.
static func start(profile: StringName = NEUTRAL_PROFILE, lines: Array[String] = CITY,
		restaurant_kind: StringName = &"pizza", seed: int = 1) -> GameFixture:
	var fixture := GameFixture.new()
	fixture.content = GameContent.load_from()
	var neutral := ProfileData.new()
	neutral.id = NEUTRAL_PROFILE
	fixture.content.profiles[NEUTRAL_PROFILE] = neutral
	fixture.game = Game.new_run(fixture.content, seed)
	fixture.state = fixture.game.state
	fixture.state.city = City.from_text(PackedStringArray(lines), restaurant_kind)
	fixture.state.courier_position = fixture.state.city.base
	var problem := fixture.game.choose_profile(profile)
	assert(problem == Game.Problem.NONE, "the fixture could not choose the profile %s" % profile)
	fixture.state.offers.clear()
	fixture.state.piles.hand.clear()
	fixture.state.history.clear()
	return fixture


## Replaces the hand.
func give_cards(cards: Array[StringName]) -> void:
	state.piles.hand = cards.duplicate()


## Adds an accepted order, its dish still at the restaurant.
func add_order(dish: StringName, client: Vector2i, deadline: int = 5, pay: int = 10,
		restaurant: Vector2i = RESTAURANT) -> Order:
	var order := Order.new()
	order.id = state.next_order_id
	state.next_order_id += 1
	order.dish = content.dishes[dish]
	order.restaurant = restaurant
	order.client = client
	order.deadline = deadline
	order.pay = pay
	order.modifiers = OrderModifiers.new()
	state.orders.append(order)
	return order


## Puts the dish of the order straight in the bag, dropped in this column, wherever the
## courier is. Returns the bag item.
func carry(order: Order, column: int = 0) -> BagItem:
	var item := BagItem.new(order.id, order.dish)
	order.picked_up = true
	state.bag.take_from_restaurant(item)
	if state.bag.held == item:
		var problem := state.bag.drop_held(column)
		assert(problem == Bag.Problem.NONE, "the fixture could not drop order %d" % order.id)
	return item


## Adds an offer of one dish to the app.
func add_offer(dish: StringName, client: Vector2i, deadline: int = 5, pay: int = 10) -> Offer:
	var offer := Offer.new()
	offer.id = state.next_offer_id
	state.next_offer_id += 1
	offer.restaurant = RESTAURANT
	offer.restaurant_kind = state.city.restaurant_kind_at(RESTAURANT)
	var part := Offer.Part.new()
	part.dish = content.dishes[dish]
	part.client = client
	part.deadline = deadline
	part.pay = pay
	offer.parts.append(part)
	state.offers.append(offer)
	return offer


## Gives equipment to the run (its effects apply at once).
func equip(id: StringName) -> void:
	state.equipment.append(id)
	state.refresh_effects()


## Sets the event of the night (its effects apply at once).
func set_event(id: StringName) -> void:
	state.event = id
	state.refresh_effects()


## History entries of this kind, oldest first.
func events(kind: GameEvent.Kind) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for event in state.history:
		if event.kind == kind:
			out.append(event)
	return out


## Plays the end of the last turn of the night with this much money in the wallet
## (by default the rent of the night and 100 € more).
func finish_night(wallet: int = -1) -> void:
	state.wallet = wallet if wallet >= 0 else state.rent_tonight() + 100
	state.turn = state.config.turns_per_night
	var problem := game.end_turn()
	assert(problem == Game.Problem.NONE, "the fixture could not end the night")


## Ends the night, takes the first free reward and opens the shop.
func open_shop(wallet: int = -1) -> void:
	finish_night(wallet)
	var problem := game.choose_reward(0)
	assert(problem == Game.Problem.NONE, "the fixture could not open the shop")
