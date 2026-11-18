class_name GameContent
extends RefCounted
## Every piece of game content loaded from data/: config, dishes, restaurants, cards...
##
## Content is found by listing folders, so adding a .tres file is enough to add content.
## ResourceLoader.list_directory() is used instead of DirAccess because it also works
## in exported games, where .tres files are converted and renamed.

const DEFAULT_ROOT := "res://data"
const CONFIG_PATH := "config/game_config.tres"

var config: GameConfig
var dishes: Dictionary[StringName, DishData] = {}
var restaurants: Dictionary[StringName, RestaurantData] = {}
var cards: Dictionary[StringName, CardData] = {}
var equipment: Dictionary[StringName, EquipmentData] = {}
var upgrades: Dictionary[StringName, UpgradeData] = {}
var profiles: Dictionary[StringName, ProfileData] = {}
var events: Dictionary[StringName, EventData] = {}

## Problems found while loading (wrong type, id not matching the file name...).
var load_errors: PackedStringArray = PackedStringArray()


static func load_from(root: String = DEFAULT_ROOT) -> GameContent:
	var content := GameContent.new()
	content.config = load(root.path_join(CONFIG_PATH)) as GameConfig
	if content.config == null:
		content.load_errors.append("missing or invalid %s" % root.path_join(CONFIG_PATH))
	content._load_folder(root.path_join("dishes"), content.dishes, "DishData")
	content._load_folder(root.path_join("restaurants"), content.restaurants, "RestaurantData")
	content._load_folder(root.path_join("cards"), content.cards, "CardData")
	content._load_folder(root.path_join("equipment"), content.equipment, "EquipmentData")
	content._load_folder(root.path_join("upgrades"), content.upgrades, "UpgradeData")
	content._load_folder(root.path_join("profiles"), content.profiles, "ProfileData")
	content._load_folder(root.path_join("events"), content.events, "EventData")
	return content


## Restaurant ids, sorted so that random draws do not depend on the file system order.
func restaurant_ids() -> Array[StringName]:
	return _sorted_keys(restaurants)


## Dish ids, sorted alphabetically.
func dish_ids() -> Array[StringName]:
	return _sorted_keys(dishes)


## Card, equipment, upgrade and event ids, sorted alphabetically (random draws must not
## depend on the order of the files).
func card_ids() -> Array[StringName]:
	return _sorted_keys(cards)


func equipment_ids() -> Array[StringName]:
	return _sorted_keys(equipment)


func upgrade_ids() -> Array[StringName]:
	return _sorted_keys(upgrades)


func event_ids() -> Array[StringName]:
	return _sorted_keys(events)


func profile_ids() -> Array[StringName]:
	return _sorted_keys(profiles)


## Checks the references between content files. Returns one line per problem.
func validate() -> PackedStringArray:
	var problems := load_errors.duplicate()
	if config == null:
		return problems
	for restaurant: RestaurantData in restaurants.values():
		if restaurant.dishes.is_empty():
			problems.append("restaurant %s has no dish" % restaurant.id)
		for dish_id in restaurant.dishes:
			if not dishes.has(dish_id):
				problems.append("restaurant %s: unknown dish %s" % [restaurant.id, dish_id])
	for card_id in config.starting_deck:
		if not cards.has(card_id):
			problems.append("starting deck: unknown card %s" % card_id)
	for profile: ProfileData in profiles.values():
		for card_id in profile.extra_cards:
			if not cards.has(card_id):
				problems.append("profile %s: unknown card %s" % [profile.id, card_id])
	if not events.values().any(func(event: EventData) -> bool: return event.drawable):
		problems.append("no event can be drawn for the next nights")
	if not cards.has(config.fatigue_card):
		problems.append("fatigue card: unknown card %s" % config.fatigue_card)
	for upgrade: UpgradeData in upgrades.values():
		if upgrade.removes_card != &"" and not cards.has(upgrade.removes_card):
			problems.append("upgrade %s: unknown card %s" % [upgrade.id, upgrade.removes_card])
	for dish: DishData in dishes.values():
		if dish.cells.is_empty():
			problems.append("dish %s has no cell" % dish.id)
	if config.rent_per_night.size() != config.nights:
		problems.append("rent_per_night needs one value per night (%d)" % config.nights)
	if restaurants.size() < config.restaurant_count:
		problems.append("not enough restaurant types for the city")
	problems.append_array(config.city_problems())
	return problems


## Every piece of content, whatever its type.
func all_content() -> Array[ContentData]:
	var out: Array[ContentData] = []
	for table: Dictionary in [dishes, restaurants, cards, equipment, upgrades, profiles, events]:
		for item: ContentData in table.values():
			out.append(item)
	return out


func _load_folder(folder: String, into: Dictionary, expected_class: String) -> void:
	var files := ResourceLoader.list_directory(folder)
	if files.is_empty():
		load_errors.append("missing or empty folder %s" % folder)
		return
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var path := folder.path_join(file_name)
		var item := load(path) as ContentData
		if item == null or item.get_script().get_global_name() != expected_class:
			load_errors.append("%s is not a %s" % [path, expected_class])
			continue
		if String(item.id) != file_name.get_basename():
			load_errors.append("%s: id \"%s\" does not match the file name" % [path, item.id])
		if into.has(item.id):
			load_errors.append("%s: duplicate id %s" % [path, item.id])
		into[item.id] = item


static func _sorted_keys(table: Dictionary) -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in table.keys():
		keys.append(key)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return keys
