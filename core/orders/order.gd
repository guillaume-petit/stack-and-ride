class_name Order
extends RefCounted
## An accepted order: one dish to take at a restaurant and deliver to a client (design doc §7).
##
## Where its dish is (in hand, in the bag, aside...) is only known by the bag
## (Bag.location_of(id)), so that there is a single source of truth.

var id: int
var dish: DishData
var restaurant: Vector2i
var client: Vector2i
## Turns left; negative when late (§7.3).
var deadline: int
var pay: int
var modifiers: OrderModifiers
## False while the dish waits at the restaurant (§7.1).
var picked_up: bool = false
## The player was told once that a step is needed to climb to the 5th floor (§7.2).
var fifth_floor_warned: bool = false


func is_late() -> bool:
	return deadline < 0
