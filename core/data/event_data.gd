class_name EventData
extends ContentData
## An evening event (design doc §12).

## Calm evenings are never drawn for the next night (night 1 is always calm).
@export var drawable: bool = true
## What it changes in the rules; null for none (calm evening).
@export var effects: EffectData


func _key_prefix() -> String:
	return "EVENT"
