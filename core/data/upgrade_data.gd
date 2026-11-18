class_name UpgradeData
extends ContentData
## A reward that is neither a card nor an equipment: bigger bag, deck trim,
## new restaurant (design doc §8.5).

## Price in the shop; 0 means it is only offered as a free reward.
@export var shop_price: int = 0
## Columns and rows added to the bag (Sac plus large / plus haut), up to the config maximum.
@export var extra_columns: int = 0
@export var extra_rows: int = 0
## Card removed from the deck (Désencombrer); &"" for none.
@export var removes_card: StringName = &""
## A restaurant of a type missing from the city opens (Nouveau partenaire).
@export var opens_restaurant: bool = false


func sold_in_shop() -> bool:
	return shop_price > 0


func _key_prefix() -> String:
	return "UPGRADE"
