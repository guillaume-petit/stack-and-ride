extends TestCase
## The bag (design doc §6). Grids are checked with Bag.to_text(): one line per row, the top
## row first, "." for an empty cell and the order id for a dish.

var content: GameContent


func before_each() -> void:
	content = GameContent.load_from()


func _item(order_id: int, dish: StringName) -> BagItem:
	return BagItem.new(order_id, content.dishes[dish])


## Takes the dish at the restaurant, turns it and drops it in the column.
func _drop(bag: Bag, order_id: int, dish: StringName, column: int, turns: int = 0) -> Bag.Problem:
	assert_true(bag.take_from_restaurant(_item(order_id, dish)), "hand should be free")
	for _turn in turns:
		bag.rotate_held()
	return bag.drop_held(column)


## Drops a dish that must fit.
func _put(bag: Bag, order_id: int, dish: StringName, column: int, turns: int = 0) -> BagItem:
	assert_eq(_drop(bag, order_id, dish, column, turns), Bag.Problem.NONE, "dropping %s" % dish)
	return bag.find(order_id)


func _grid(bag: Bag) -> Array:
	return Array(bag.to_text())


# --- Shapes ---------------------------------------------------------------------------------

func test_rotation_turns_the_shape_a_quarter_turn() -> void:
	var burger := _item(1, &"burger")
	assert_eq(burger.width(), 2)
	burger.rotate()
	assert_eq(burger.shape, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])
	assert_eq(burger.width(), 1)


func test_four_rotations_give_the_shape_back() -> void:
	for dish: StringName in content.dishes:
		var item := _item(1, dish)
		var start := item.shape.duplicate()
		for _turn in 4:
			item.rotate()
		assert_eq(item.shape, start, String(dish))


func test_rotating_the_l_shape() -> void:
	var tacos := _item(1, &"tacos")
	tacos.rotate()
	# X X        X X
	# X     ->     X
	assert_eq(tacos.shape, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i])


# --- Dropping (§6.2) ------------------------------------------------------------------------

func test_a_dish_falls_to_the_bottom() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 1)
	assert_eq(_grid(bag), ["....", "....", ".11."])
	assert_null(bag.held)


func test_a_dish_lands_on_another_one() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"pizza", 0)
	_put(bag, 2, &"burger", 1)
	assert_eq(_grid(bag), [".22.", "11..", "11.."])


func test_the_anchor_column_is_moved_left_when_the_shape_is_too_wide() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"sushi", 3)
	assert_eq(_grid(bag), ["....", "....", ".111"])


func test_the_l_shape_hooks_over_a_lower_dish() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 1)
	_put(bag, 2, &"tacos", 0)
	assert_eq(_grid(bag), ["...", "22.", "211"])


func test_no_room_at_the_top_of_the_column() -> void:
	var bag := Bag.new(2, 2)
	_put(bag, 1, &"burger", 0, 1)
	_put(bag, 2, &"burger", 1, 1)
	assert_eq(_drop(bag, 3, &"soda", 0), Bag.Problem.NO_ROOM)
	assert_eq(bag.held.order_id, 3, "the dish stays in hand")
	assert_eq(_grid(bag), ["12", "12"])


func test_no_room_when_the_shape_is_wider_than_the_bag() -> void:
	var bag := Bag.new(2, 3)
	assert_eq(_drop(bag, 1, &"family", 0), Bag.Problem.NO_ROOM)
	assert_eq(bag.drop_cells(bag.held.shape, 0), [] as Array[Vector2i])


func test_drop_cells_previews_without_changing_the_bag() -> void:
	var bag := Bag.new(4, 3)
	var pizza := _item(1, &"pizza")
	assert_eq(bag.drop_cells(pizza.shape, 3),
		[Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 2), Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(_grid(bag), ["....", "....", "...."])


func test_nothing_can_be_dropped_on_a_fragile_dish() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"sushi", 0)
	assert_eq(_drop(bag, 2, &"burger", 1), Bag.Problem.ON_FRAGILE)
	assert_eq(_grid(bag), ["...", "...", "111"])
	bag.cancel_held()
	assert_eq(_drop(bag, 3, &"soda", 2), Bag.Problem.ON_FRAGILE, "not even another fragile dish")


func test_one_cell_above_a_fragile_dish_is_enough_to_refuse() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"soda", 0)
	_put(bag, 2, &"burger", 1)
	# Pizza on columns 0-1 would rest on the burger with a cell right above the soda.
	assert_eq(_drop(bag, 3, &"pizza", 0), Bag.Problem.ON_FRAGILE)


func test_a_dish_can_sit_next_to_a_fragile_dish_or_diagonally_above_it() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"soda", 0)
	_put(bag, 2, &"burger", 1)
	_put(bag, 3, &"burger", 1, 1)
	assert_eq(_grid(bag), [".3.", ".3.", "122"])


func test_a_fragile_dish_can_be_put_on_a_normal_one() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"poke", 0)
	_put(bag, 2, &"sushi", 0)
	assert_eq(_grid(bag), ["...", "222", "11."])


func test_hot_and_cold_cannot_touch_side_by_side() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0)
	assert_eq(_drop(bag, 2, &"poke", 2), Bag.Problem.HOT_COLD_TOUCH)
	assert_eq(_grid(bag), ["....", "....", "11.."])


func test_hot_and_cold_cannot_touch_one_above_the_other() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"poke", 0)
	assert_eq(_drop(bag, 2, &"burger", 0), Bag.Problem.HOT_COLD_TOUCH)


func test_cold_cannot_be_put_next_to_hot_either() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"poke", 0)
	assert_eq(_drop(bag, 2, &"tacos", 2), Bag.Problem.HOT_COLD_TOUCH)


func test_hot_and_cold_may_touch_diagonally() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"tacos", 0)
	# The tacos overhangs (1, 2): the ice cream only touches it diagonally.
	_put(bag, 2, &"glace", 2)
	assert_eq(_grid(bag), ["....", "11..", "1.2."])


func test_neutral_dishes_touch_anything() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"soda", 2)
	_put(bag, 3, &"glace", 3)
	assert_eq(_grid(bag), ["....", "....", "1123"])


func test_same_temperatures_touch() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"pizza", 2)
	assert_eq(_grid(bag), ["....", "..22", "1122"])


func test_the_separator_lets_hot_and_cold_touch() -> void:
	var bag := Bag.new(4, 3)
	bag.set_equipment(true, false, false)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"poke", 2)
	_put(bag, 3, &"poke", 0)
	assert_eq(_grid(bag), ["....", "33..", "1122"])


func test_the_fragile_rule_is_checked_before_the_temperature() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"glace", 0)
	assert_eq(_drop(bag, 2, &"burger", 0), Bag.Problem.ON_FRAGILE)


func test_dropping_needs_a_dish_in_hand() -> void:
	var bag := Bag.new(3, 3)
	assert_eq(bag.drop_held(0), Bag.Problem.NOTHING_HELD)
	assert_true(bag.is_empty())


# --- Taking, lifting, cancelling (§6.3, §6.8) ---------------------------------------------------

func test_only_one_dish_in_hand() -> void:
	var bag := Bag.new(3, 3)
	assert_true(bag.take_from_restaurant(_item(1, &"burger")))
	assert_false(bag.take_from_restaurant(_item(2, &"pizza")))
	assert_eq(bag.held.order_id, 1)


func test_lifting_a_free_dish() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0, 1)
	assert_eq(bag.lift(1), Bag.Problem.NONE)
	assert_eq(bag.held.order_id, 1)
	assert_eq(bag.location_of(1), Bag.Location.HELD)
	assert_eq(bag.held.shape, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i], "keeps its orientation")
	assert_eq(_grid(bag), ["....", "....", "...."])


func test_a_dish_with_something_on_it_cannot_be_lifted() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"pizza", 0)
	_put(bag, 2, &"burger", 1)
	assert_eq(bag.lift(1), Bag.Problem.SOMETHING_ON_TOP)
	assert_null(bag.held)
	assert_eq(bag.lift(2), Bag.Problem.NONE, "the top one can")


func test_a_dish_cannot_be_lifted_while_another_is_in_hand() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 0)
	bag.take_from_restaurant(_item(2, &"pizza"))
	assert_eq(bag.lift(1), Bag.Problem.HAND_BUSY)


func test_cancel_puts_a_lifted_dish_back_exactly_in_place() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"pizza", 0)
	_put(bag, 2, &"tacos", 2, 1)
	var before := _grid(bag)
	assert_eq(bag.lift(2), Bag.Problem.NONE)
	bag.rotate_held()
	bag.rotate_held()
	assert_null(bag.cancel_held())
	assert_eq(_grid(bag), before)
	assert_eq(bag.find(2).shape, BagItem.normalized(bag.find(2).cells))


func test_lifting_a_dish_that_is_not_in_the_grid() -> void:
	var bag := Bag.new(3, 3)
	assert_eq(bag.lift(1), Bag.Problem.NOT_IN_BAG)
	bag.take_from_restaurant(_item(2, &"burger"))
	bag.set_held_aside()
	assert_eq(bag.lift(2), Bag.Problem.NOT_IN_BAG, "aside, not in the grid")


func test_cancel_still_restores_when_another_dish_left_elsewhere() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"burger", 2)
	bag.lift(1)
	bag.remove(2)
	assert_null(bag.cancel_held())
	assert_eq(_grid(bag), ["....", "....", "11.."])


func test_cancel_sets_the_dish_aside_when_its_place_no_longer_rests_on_anything() -> void:
	var bag := Bag.new(2, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"burger", 0)
	_put(bag, 3, &"burger", 0)
	assert_eq(bag.lift(3), Bag.Problem.NONE)
	# Delivering the bottom burger while the top one is in hand: the middle one falls.
	bag.remove(1)
	assert_eq(_grid(bag), ["..", "..", "22"])
	assert_null(bag.cancel_held())
	assert_eq(_grid(bag), ["..", "..", "22"], "not left floating")
	assert_eq(bag.location_of(3), Bag.Location.ASIDE)
	assert_true(bag.is_sorting())


func test_cancel_sets_the_dish_aside_when_another_dish_fell_into_its_place() -> void:
	var bag := Bag.new(2, 4)
	_put(bag, 1, &"soda", 0)
	_put(bag, 2, &"burger", 1, 1)
	_put(bag, 3, &"burger", 0)
	assert_eq(_grid(bag), ["..", "33", ".2", "12"])
	assert_eq(bag.lift(1), Bag.Problem.NONE)
	# The burger on top rested on the standing one only: once delivered, it falls to the bottom.
	bag.remove(2)
	assert_eq(_grid(bag), ["..", "..", "..", "33"])
	assert_null(bag.cancel_held())
	assert_eq(bag.location_of(1), Bag.Location.ASIDE)
	assert_eq(_grid(bag), ["..", "..", "..", "33"])


func test_cancel_sends_a_dish_from_the_restaurant_back() -> void:
	var bag := Bag.new(3, 3)
	var burger := _item(1, &"burger")
	bag.take_from_restaurant(burger)
	assert_eq(bag.cancel_held(), burger)
	assert_eq(bag.location_of(1), Bag.Location.NONE)
	assert_true(bag.is_empty())


func test_a_lifted_dish_can_be_dropped_elsewhere() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0)
	bag.lift(1)
	assert_eq(bag.drop_held(2), Bag.Problem.NONE)
	assert_eq(_grid(bag), ["....", "....", "..11"])
	assert_eq(bag.items().size(), 1)


func test_setting_a_dish_aside_and_taking_it_back() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 0)
	assert_false(bag.is_sorting())
	bag.lift(1)
	assert_true(bag.is_sorting(), "a dish in hand")
	bag.set_held_aside()
	assert_null(bag.held)
	assert_true(bag.is_sorting(), "a dish aside")
	assert_eq(bag.location_of(1), Bag.Location.ASIDE)
	assert_false(bag.is_ready_to_deliver(1), "not delivered from beside the bag")
	assert_true(bag.take_from_aside(1))
	assert_eq(bag.held_origin, Bag.Origin.ASIDE)
	bag.drop_held(1)
	assert_false(bag.is_sorting())
	assert_true(bag.is_ready_to_deliver(1))


func test_several_dishes_can_wait_aside() -> void:
	var bag := Bag.new(3, 3)
	bag.take_from_restaurant(_item(1, &"burger"))
	bag.set_held_aside()
	bag.take_from_restaurant(_item(2, &"pizza"))
	bag.set_held_aside()
	assert_eq(bag.aside_items().size(), 2)
	assert_true(bag.take_from_aside(2))
	assert_false(bag.take_from_aside(1), "hand already busy")


func test_cancel_puts_a_dish_taken_from_aside_back_aside() -> void:
	var bag := Bag.new(3, 3)
	bag.take_from_restaurant(_item(1, &"burger"))
	# The courier rode on since the restaurant: the dish can no longer go back there.
	bag.leave_stop()
	bag.rotate_held()
	bag.set_held_aside()
	bag.take_from_aside(1)
	assert_null(bag.cancel_held())
	assert_eq(bag.location_of(1), Bag.Location.ASIDE)
	assert_eq(bag.find(1).width(), 1, "keeps its orientation")


func test_a_dish_from_this_restaurant_goes_back_there_from_aside() -> void:
	var bag := Bag.new(3, 3)
	var burger := _item(1, &"burger")
	bag.take_from_restaurant(burger)
	bag.set_held_aside()
	bag.take_from_aside(1)
	assert_true(bag.held_returns_to_restaurant())
	assert_true(bag.cancel_held() == burger, "back to the restaurant")
	assert_eq(bag.location_of(1), Bag.Location.NONE)
	assert_false(bag.is_sorting())


func test_the_damage_follows_the_dish() -> void:
	var bag := Bag.new(3, 3)
	var burger := _put(bag, 1, &"burger", 0)
	bag.shake()
	assert_true(burger.damaged)
	bag.lift(1)
	bag.set_held_aside()
	bag.take_from_aside(1)
	bag.drop_held(0)
	assert_true(bag.find(1).damaged)


# --- Wedged dishes (§6.4) -----------------------------------------------------------------------

func test_a_dish_across_the_whole_bag_is_wedged() -> void:
	var bag := Bag.new(3, 3)
	var sushi := _put(bag, 1, &"sushi", 0)
	assert_true(bag.is_wedged(sushi))


func test_a_dish_touching_one_wall_is_loose() -> void:
	var bag := Bag.new(4, 3)
	var burger := _put(bag, 1, &"burger", 0)
	assert_false(bag.is_wedged(burger))
	assert_eq(bag.loose_items(), [burger])


func test_dishes_wedge_each_other_against_the_walls() -> void:
	var bag := Bag.new(4, 3)
	var burger := _put(bag, 1, &"burger", 0)
	var soda := _put(bag, 2, &"soda", 2)
	assert_false(bag.is_wedged(soda), "nothing on its right yet")
	var glace := _put(bag, 3, &"glace", 3)
	for item in [burger, soda, glace]:
		assert_true(bag.is_wedged(item))
	assert_eq(bag.loose_items(), [])


func test_left_and_right_blocks_may_come_from_different_cells() -> void:
	var bag := Bag.new(3, 3)
	var tacos := _put(bag, 1, &"tacos", 0)
	# 11.
	# 1..   left: the wall; right: nothing.
	assert_false(bag.is_wedged(tacos))
	_put(bag, 2, &"burger", 2, 1)
	# 112
	# 1.2   left blocked on both rows, right only on the top row.
	assert_eq(_grid(bag), ["...", "112", "1.2"])
	assert_true(bag.is_wedged(tacos))


func test_the_own_cells_of_a_dish_do_not_wedge_it() -> void:
	var bag := Bag.new(5, 3)
	var burger := _put(bag, 1, &"burger", 1)
	assert_false(bag.is_wedged(burger))


# --- Shakes (§6.5) ------------------------------------------------------------------------------

func test_a_shake_damages_the_loose_dishes_only() -> void:
	var bag := Bag.new(4, 3)
	var burger := _put(bag, 1, &"burger", 0)
	var soda := _put(bag, 2, &"soda", 2)
	var glace := _put(bag, 4, &"glace", 3)
	var pizza := _put(bag, 3, &"pizza", 0)
	# The bottom row is full: wedged. The pizza on top touches nothing on its right.
	assert_eq(_grid(bag), ["33..", "33..", "1124"])
	var result := bag.shake()
	assert_false(result.braced)
	assert_eq(result.damaged, [pizza])
	assert_true(pizza.damaged)
	for item in [burger, soda, glace]:
		assert_false(item.damaged)


func test_a_dish_is_damaged_only_once() -> void:
	var bag := Bag.new(4, 3)
	var burger := _put(bag, 1, &"burger", 0)
	assert_eq(bag.shake().damaged, [burger])
	assert_eq(bag.shake().damaged, [])
	assert_true(burger.damaged)


func test_the_straps_protect_the_non_fragile_dishes() -> void:
	var bag := Bag.new(4, 3)
	bag.set_equipment(false, true, false)
	var burger := _put(bag, 1, &"burger", 0)
	var soda := _put(bag, 2, &"soda", 3)
	assert_eq(bag.shake().damaged, [soda])
	assert_false(burger.damaged)


func test_bracing_cancels_the_next_shake_only() -> void:
	var bag := Bag.new(4, 3)
	var burger := _put(bag, 1, &"burger", 0)
	bag.brace()
	var first := bag.shake()
	assert_true(first.braced)
	assert_eq(first.damaged, [])
	assert_false(burger.damaged)
	assert_false(bag.braced, "used up")
	assert_eq(bag.shake().damaged, [burger])


func test_bracing_is_used_up_even_with_an_empty_bag() -> void:
	var bag := Bag.new(4, 3)
	bag.brace()
	assert_true(bag.shake().braced)
	assert_false(bag.braced)


func test_dishes_in_hand_or_aside_are_never_shaken() -> void:
	var bag := Bag.new(4, 3)
	bag.take_from_restaurant(_item(1, &"burger"))
	bag.set_held_aside()
	bag.take_from_restaurant(_item(2, &"pizza"))
	assert_eq(bag.shake().damaged, [])
	assert_false(bag.find(1).damaged)
	assert_false(bag.find(2).damaged)


# --- Cup holder (§6.9) --------------------------------------------------------------------------

func test_without_cup_holder_a_soda_goes_to_the_hand() -> void:
	var bag := Bag.new(3, 3)
	bag.take_from_restaurant(_item(1, &"soda"))
	assert_eq(bag.location_of(1), Bag.Location.HELD)


func test_the_cup_holder_takes_sodas_straight_away() -> void:
	var bag := Bag.new(3, 3)
	bag.set_equipment(false, false, true)
	assert_true(bag.take_from_restaurant(_item(1, &"soda")))
	assert_null(bag.held)
	assert_eq(bag.location_of(1), Bag.Location.CUP_HOLDER)
	assert_true(bag.is_ready_to_deliver(1))
	assert_eq(_grid(bag), ["...", "...", "..."], "takes no cell")
	assert_eq(bag.dish_count(), 1)
	assert_false(bag.is_sorting())


func test_the_cup_holder_only_takes_sodas() -> void:
	var bag := Bag.new(3, 3)
	bag.set_equipment(false, false, true)
	bag.take_from_restaurant(_item(1, &"glace"))
	assert_eq(bag.location_of(1), Bag.Location.HELD)


func test_sodas_in_the_cup_holder_are_never_shaken() -> void:
	var bag := Bag.new(3, 3)
	bag.set_equipment(false, false, true)
	bag.take_from_restaurant(_item(1, &"soda"))
	assert_eq(bag.shake().damaged, [])
	assert_false(bag.find(1).damaged)


func test_the_only_dish_with_a_cup_holder_flag_is_the_soda() -> void:
	for dish: DishData in content.dishes.values():
		assert_eq(dish.fits_cup_holder, dish.id == &"soda", String(dish.id))


# --- Leaving the bag, falling and crushing (§6.7) -------------------------------------------------

func test_removing_the_bottom_dish_lets_the_upper_one_fall() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"pizza", 0)
	assert_eq(_grid(bag), ["22.", "22.", "11."])
	assert_eq(bag.remove(1), [])
	assert_eq(_grid(bag), ["...", "22.", "22."])
	assert_eq(bag.location_of(1), Bag.Location.NONE)


func test_a_dish_resting_on_another_dish_does_not_fall() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"burger", 2)
	_put(bag, 3, &"pizza", 1)
	assert_eq(_grid(bag), [".33.", ".33.", "1122"])
	bag.remove(1)
	# The pizza still rests on the second burger: it does not move.
	assert_eq(_grid(bag), [".33.", ".33.", "..22"])


func test_falls_are_repeated_until_nothing_moves() -> void:
	var bag := Bag.new(2, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"soda", 0)
	_put(bag, 3, &"burger", 1, 1)
	assert_eq(_grid(bag), [".3", "23", "11"])
	bag.remove(1)
	assert_eq(_grid(bag), ["..", ".3", "23"])


func test_a_stack_falls_together() -> void:
	var bag := Bag.new(2, 4)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"burger", 0)
	bag.set_equipment(true, false, false)
	_put(bag, 3, &"poke", 0)
	_put(bag, 4, &"burger", 0)
	assert_eq(_grid(bag), ["44", "33", "22", "11"])
	bag.remove(2)
	assert_eq(_grid(bag), ["..", "44", "33", "11"])


func test_a_fragile_dish_is_crushed_when_a_dish_falls_on_it() -> void:
	var bag := Bag.new(2, 3)
	var soda := _put(bag, 1, &"soda", 0)
	_put(bag, 2, &"burger", 1, 1)
	_put(bag, 3, &"burger", 0)
	assert_eq(_grid(bag), ["33", ".2", "12"])
	assert_eq(bag.remove(2), [soda])
	assert_eq(_grid(bag), ["..", "33", "1."])
	assert_true(soda.damaged)


func test_an_already_damaged_fragile_dish_is_not_crushed_again() -> void:
	var bag := Bag.new(2, 3)
	var soda := _put(bag, 1, &"soda", 0)
	soda.damaged = true
	_put(bag, 2, &"burger", 1, 1)
	_put(bag, 3, &"burger", 0)
	assert_eq(bag.remove(2), [])
	assert_true(soda.damaged)


func test_nothing_falls_when_the_removed_dish_held_nothing() -> void:
	var bag := Bag.new(4, 3)
	_put(bag, 1, &"burger", 0)
	_put(bag, 2, &"soda", 2)
	_put(bag, 3, &"soda", 3)
	assert_eq(bag.remove(1), [])
	assert_eq(_grid(bag), ["....", "....", "..23"])


func test_removing_a_dish_from_the_hand_aside_or_cup_holder() -> void:
	var bag := Bag.new(3, 3)
	bag.set_equipment(false, false, true)
	bag.take_from_restaurant(_item(1, &"soda"))
	bag.take_from_restaurant(_item(2, &"burger"))
	bag.set_held_aside()
	bag.take_from_restaurant(_item(3, &"pizza"))
	for order_id in [1, 2, 3]:
		assert_eq(bag.remove(order_id), [])
		assert_eq(bag.location_of(order_id), Bag.Location.NONE)
	assert_true(bag.is_empty())


func test_removing_an_unknown_dish_does_nothing() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 0)
	assert_eq(bag.remove(42), [])
	assert_eq(_grid(bag), ["...", "...", "11."])


# --- Size and new night ---------------------------------------------------------------------------

func test_growing_keeps_the_dishes_at_the_bottom() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 0)
	bag.grow(1, 1)
	assert_eq(_grid(bag), ["....", "....", "....", "11.."])
	_put(bag, 2, &"pizza", 3)
	assert_eq(_grid(bag), ["....", "....", "..22", "1122"])


func test_growing_while_a_dish_is_lifted_keeps_its_place() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 0)
	bag.lift(1)
	bag.grow(0, 1)
	bag.cancel_held()
	assert_eq(_grid(bag), ["...", "...", "...", "11."])


func test_clear_empties_everything_but_keeps_the_size_and_equipment() -> void:
	var bag := Bag.new(4, 3)
	bag.set_equipment(false, false, true)
	bag.brace()
	_put(bag, 1, &"burger", 0)
	bag.take_from_restaurant(_item(2, &"soda"))
	bag.take_from_restaurant(_item(3, &"pizza"))
	bag.set_held_aside()
	bag.take_from_restaurant(_item(4, &"poke"))
	bag.clear()
	assert_true(bag.is_empty())
	assert_false(bag.braced)
	assert_true(bag.has_cup_holder)
	assert_eq([bag.columns, bag.rows], [4, 3])
	assert_eq(bag.dish_count(), 0)


func test_items_are_listed_from_the_bottom_up() -> void:
	var bag := Bag.new(3, 3)
	_put(bag, 1, &"burger", 0, 1)
	_put(bag, 2, &"soda", 0)
	_put(bag, 3, &"burger", 1)
	var ids: Array[int] = []
	for item in bag.items():
		ids.append(item.order_id)
	assert_eq(ids, [1, 3, 2])
