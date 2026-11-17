class_name DishData
extends ContentData
## A dish that goes in the bag (design doc §8.1).

enum Temperature { NEUTRAL, HOT, COLD }

## Cells of the shape as (column, row), row 0 at the top of the shape.
@export var cells: Array[Vector2i] = [Vector2i.ZERO]
@export var temperature: Temperature = Temperature.NEUTRAL
## A fragile dish cannot have another dish placed right above it.
@export var fragile: bool = false


func cell_count() -> int:
	return cells.size()


func has_description() -> bool:
	return false


func _key_prefix() -> String:
	return "DISH"
