class_name EventData
extends ContentData
## An evening event (design doc §12). Its effects come with the game flow (iteration 3).

## Calm evenings are never drawn for the next night (night 1 is always calm).
@export var drawable: bool = true


func _key_prefix() -> String:
	return "EVENT"
