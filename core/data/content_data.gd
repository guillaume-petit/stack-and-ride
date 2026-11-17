class_name ContentData
extends Resource
## Base class for every piece of game content stored as a .tres file under data/.
##
## The id is the one used in the design document ([pizza], [sprint]...) and must match the
## file name. Player-facing texts are never stored here: their translation keys are derived
## from the id (see name_key() and description_key()), so adding content only needs a .tres
## file and two lines in i18n/fr.po.

@export var id: StringName


## Translation key of the displayed name, e.g. "CARD_SPRINT".
func name_key() -> String:
	return "%s_%s" % [_key_prefix(), String(id).to_upper()]


## Translation key of the displayed description, e.g. "CARD_SPRINT_DESC".
func description_key() -> String:
	return name_key() + "_DESC"


## Whether this kind of content has a description text (dishes and restaurants only have a name).
func has_description() -> bool:
	return true


## Prefix of the translation keys, overridden by each content type.
func _key_prefix() -> String:
	return "CONTENT"
