class_name RestaurantData
extends ContentData
## A restaurant type (design doc §8.2).

## Dish ids drawn for an offer. A dish listed twice is twice as likely.
@export var dishes: Array[StringName] = []


func has_description() -> bool:
	return false


func _key_prefix() -> String:
	return "RESTAURANT"
