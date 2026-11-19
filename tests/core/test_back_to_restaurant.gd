extends TestCase
## A dish taken at the restaurant can go back there as long as the courier has not left,
## even after it was set aside or rearranged in the bag (§6.8, decision of 19/11/2026).
## Without it, a dish that fits nowhere in the bag blocked the run: set aside, it could
## neither move, nor be delivered, nor let the turn end.

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()
	f.state.courier_position = GameFixture.RESTAURANT


## A 2 × 2 bag with an ice cream at the bottom: a pizza (2 × 2) fits nowhere.
func _bag_without_room_for_a_pizza() -> Order:
	f.state.bag = Bag.new(2, 2)
	f.carry(f.add_order(&"glace", GameFixture.CLIENT_2))
	return f.add_order(&"pizza", GameFixture.CLIENT_1)


func test_a_dish_set_aside_can_go_back_to_the_restaurant() -> void:
	var pizza := _bag_without_room_for_a_pizza()
	f.game.take_dish(pizza.id)
	assert_eq(f.game.drop_held(0), Game.Problem.NO_ROOM)
	f.game.set_held_aside()
	assert_eq(f.game.end_turn_problem(), Game.Problem.SORTING)
	f.game.take_from_aside(pizza.id)
	assert_true(f.state.bag.held_returns_to_restaurant(), "the cancel button sends it back")
	assert_eq(f.game.cancel_held(), Game.Problem.NONE)
	assert_false(pizza.picked_up, "the dish waits at the restaurant again")
	assert_eq(f.state.bag.location_of(pizza.id), Bag.Location.NONE)
	assert_false(f.state.bag.is_sorting())
	assert_eq(f.game.end_turn(), Game.Problem.NONE, "the turn can end")
	assert_true(f.state.find_order(pizza.id) != null, "the order is still accepted")


func test_a_dish_rearranged_in_the_bag_can_still_go_back() -> void:
	f.state.bag = Bag.new(2, 2)
	var pizza := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.game.take_dish(pizza.id)
	f.game.drop_held(0)
	f.game.lift(pizza.id)
	assert_false(f.state.bag.held_returns_to_restaurant(), "lifted from the bag: cancel puts it back in its place")
	f.game.set_held_aside()
	f.game.take_from_aside(pizza.id)
	f.game.cancel_held()
	assert_false(pizza.picked_up)


func test_once_the_courier_left_a_dish_aside_stays_aside() -> void:
	var pizza := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.game.take_dish(pizza.id)
	f.game.drop_held(0)
	f.state.steps = 1
	f.game.move_to(GameFixture.BASE)
	f.state.steps = 1
	f.game.move_to(GameFixture.RESTAURANT)
	f.game.lift(pizza.id)
	f.game.set_held_aside()
	f.game.take_from_aside(pizza.id)
	assert_false(f.state.bag.held_returns_to_restaurant())
	f.game.cancel_held()
	assert_true(pizza.picked_up, "a dish carried since an earlier stop is not given back")
	assert_eq(f.state.bag.location_of(pizza.id), Bag.Location.ASIDE)


func test_a_dish_damaged_before_going_back_stays_damaged() -> void:
	var pizza := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.game.take_dish(pizza.id)
	f.game.drop_held(1)
	f.give_cards([&"sprint"])
	f.game.play_card(0)
	assert_true(f.state.bag.find(pizza.id).damaged, "loose in the bag, shaken by the sprint")
	f.game.lift(pizza.id)
	f.game.set_held_aside()
	f.game.take_from_aside(pizza.id)
	f.game.cancel_held()
	f.game.take_dish(pizza.id)
	assert_true(f.state.bag.held.damaged, "giving it back does not repair it")
