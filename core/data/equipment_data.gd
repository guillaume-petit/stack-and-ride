class_name EquipmentData
extends ContentData
## A permanent piece of equipment bought in the shop, once per run (design doc §8.4).

@export var shop_price: int = 0
## What it changes in the rules.
@export var effects: EffectData


func _key_prefix() -> String:
	return "EQUIPMENT"
