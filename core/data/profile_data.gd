class_name ProfileData
extends ContentData
## A courier profile chosen at the start of a run (design doc §11).

## Bag width for this profile; 0 keeps the default width.
@export var bag_columns: int = 0
## Cards added to the starting deck.
@export var extra_cards: Array[StringName] = []


func _key_prefix() -> String:
	return "PROFILE"
