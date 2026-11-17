class_name UpgradeData
extends ContentData
## A reward that is neither a card nor an equipment: bigger bag, deck trim,
## new restaurant (design doc §8.5).

## Price in the shop; 0 means it is only offered as a free reward.
@export var shop_price: int = 0


func sold_in_shop() -> bool:
	return shop_price > 0


func _key_prefix() -> String:
	return "UPGRADE"
