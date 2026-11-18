class_name Offer
extends RefCounted
## An offer of the app: one restaurant, one dish per client (design doc §5.2).


## One dish for one client, with its own deadline and pay (§5.3).
class Part:
	extends RefCounted
	var dish: DishData
	var client: Vector2i
	## In turns.
	var deadline: int
	## In euros.
	var pay: int


var id: int
var restaurant: Vector2i
var restaurant_kind: StringName
var parts: Array[Part] = []
var modifiers := OrderModifiers.new()


## Clients of the offer, to know which ones are busy.
func clients() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for part in parts:
		out.append(part.client)
	return out
