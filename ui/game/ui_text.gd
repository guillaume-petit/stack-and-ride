class_name UiText
extends RefCounted
## Turns the state of the core into French text: names, numbers, refusals and the messages of
## the feed. The core never builds player-facing text (see GameEvent).
##
## The translation itself is set up by the project settings (internationalization/locale/translations).

## A message of the feed: who sends it (the app, a client...), the text, and whether it is bad news.
class Line:
	extends RefCounted
	var sender: String
	var text: String
	var bad: bool

	func _init(p_sender: String, p_text: String, p_bad: bool = false) -> void:
		sender = p_sender
		text = p_text
		bad = p_bad


## Translated text of a key (tr() needs an object, these helpers are static).
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## Minus sign used for negative numbers (typographic minus, as in the design document).
const MINUS := "−"


## Rating in stars with a French decimal comma: 47 → "4,7".
static func stars(tenths: int) -> String:
	var sign := MINUS if tenths < 0 else ""
	return "%s%d,%d" % [sign, absi(tenths) / 10, absi(tenths) % 10]


## Signed change in stars: 1 → "+0,1", -3 → "−0,3".
static func stars_change(tenths: int) -> String:
	return ("+" if tenths >= 0 else "") + stars(tenths)


## Text rising from a crossroads when the rating changes: "−0,3 ★".
static func rating_float(tenths: int) -> String:
	return stars_change(tenths) + " ★"


## Text rising from the client's door after a delivery: "+12 €", then the rating change if any.
static func delivery_float(delivery: Delivery) -> String:
	var text := "+" + euros(delivery.total())
	if delivery.rating_tenths != 0:
		text += "  " + rating_float(delivery.rating_tenths)
	return text


## Five stars drawn with the characters ★ and ☆ (rounded to the nearest star).
static func star_bar(tenths: int) -> String:
	var full := clampi(roundi(tenths / 10.0), 0, 5)
	return "★".repeat(full) + "☆".repeat(5 - full)


static func euros(amount: int) -> String:
	return (MINUS if amount < 0 else "") + "%d €" % absi(amount)


## Text of the reason why an action was refused.
static func problem(value: Game.Problem) -> String:
	return t(problem_key(value))


static func problem_key(value: Game.Problem) -> String:
	return "PROBLEM_" + Game.Problem.keys()[value]


static func name_of(content: ContentData) -> String:
	return t(content.name_key())


static func description_of(content: ContentData) -> String:
	return t(content.description_key())


## Short name of a restaurant for the map ("Nonna" for the Pizzeria Nonna).
static func restaurant_short(restaurant: RestaurantData) -> String:
	return t(short_name_key(restaurant))


static func short_name_key(restaurant: RestaurantData) -> String:
	return restaurant.name_key() + "_SHORT"


static func client(state: GameState, crossroads: Vector2i) -> String:
	return t("CLIENT_NUMBER") % state.city.client_number_at(crossroads)


static func restaurant_at(state: GameState, crossroads: Vector2i) -> String:
	return name_of(state.content.restaurants[state.city.restaurant_kind_at(crossroads)])


## "Pizza → n° 4"
static func dish_to_client(state: GameState, dish: DishData, crossroads: Vector2i) -> String:
	return "%s → %s" % [name_of(dish), client(state, crossroads)]


## Content of a reward (card, upgrade or equipment).
static func reward_content(reward: Reward, content: GameContent) -> ContentData:
	match reward.kind:
		Reward.Kind.CARD:
			return content.cards[reward.id]
		Reward.Kind.UPGRADE:
			return content.upgrades[reward.id]
	return content.equipment[reward.id]


static func reward_kind(reward: Reward) -> String:
	return t("REWARD_KIND_" + Reward.Kind.keys()[reward.kind])


## Where the dish of an order is, for the list of accepted orders.
static func order_status(state: GameState, order: Order) -> String:
	if not order.picked_up:
		return t("ORDER_WAITING") % restaurant_at(state, order.restaurant)
	var item := state.bag.find(order.id)
	var damaged := item != null and item.damaged
	match state.bag.location_of(order.id):
		Bag.Location.HELD:
			return t("ORDER_HELD")
		Bag.Location.ASIDE:
			return t("ORDER_ASIDE")
		Bag.Location.CUP_HOLDER:
			return t("ORDER_CUP_HOLDER")
	return t("ORDER_IN_BAG_DAMAGED" if damaged else "ORDER_IN_BAG")


## The modifiers of an offer or an order, as (text, color) pairs for chips.
static func modifier_chips(modifiers: OrderModifiers) -> Array[Array]:
	var out: Array[Array] = []
	if modifiers.urgent:
		out.append([t("MODIFIER_URGENT"), UiStyle.ACCENT])
	if modifiers.vip:
		out.append([t("MODIFIER_VIP"), UiStyle.MUSTARD])
	if modifiers.fifth_floor:
		out.append([t("MODIFIER_FIFTH_FLOOR"), UiStyle.INK])
	if modifiers.grouped:
		out.append([t("MODIFIER_GROUPED"), UiStyle.OK])
	return out


# --- Feed -----------------------------------------------------------------------------------

## The message for something that happened, or null when it needs none.
static func event_line(event: GameEvent, state: GameState) -> Line:
	match event.kind:
		GameEvent.Kind.NIGHT_STARTED:
			var night_event: EventData = state.content.events[event.source]
			var text: String = t("FEED_NIGHT_STARTED") % [event.value, name_of(night_event),
					euros(state.config.rent_for_night(event.value))]
			if night_event.drawable:
				text += " " + description_of(night_event)
			return Line.new(t("SENDER_APP"), text)
		GameEvent.Kind.DELIVERED:
			return _delivery_line(event, state)
		GameEvent.Kind.CANCELLED:
			return Line.new(t("SENDER_CANCELLED"), t("FEED_CANCELLED")
					% [client(state, event.order.client), stars_change(event.rating_tenths)], true)
		GameEvent.Kind.SHAKE:
			var source: String = t("SOURCE_PAVED") if event.source == &"paved" \
					else name_of(state.content.cards[event.source])
			if event.braced:
				return Line.new(t("SENDER_SHAKE"), t("FEED_SHAKE_BRACED") % source)
			if event.order_ids.is_empty():
				return Line.new(t("SENDER_SHAKE"), t("FEED_SHAKE_NOTHING") % source)
			return Line.new(t("SENDER_SHAKE"), t("FEED_SHAKE_DAMAGED")
					% [source, _dishes(state, event.order_ids)], true)
		GameEvent.Kind.CRUSHED:
			return Line.new(t("SENDER_BAG"), t("FEED_CRUSHED") % _dishes(state, event.order_ids), true)
		GameEvent.Kind.FIFTH_FLOOR_WAIT:
			return Line.new(t("SENDER_DELIVERY"), t("FEED_FIFTH_FLOOR")
					% [client(state, event.order.client), state.config.fifth_floor_steps])
		GameEvent.Kind.OFFERS_IGNORED:
			return Line.new(t("SENDER_APP"), t("FEED_OFFERS_IGNORED")
					% [event.value, absi(state.config.ignore_acceptance * event.value)], true)
		GameEvent.Kind.CARD_RATING_COST:
			return Line.new(t("SENDER_REPORT"), t("FEED_CARD_RATING_COST")
					% [name_of(state.content.cards[event.source]), stars_change(event.rating_tenths)], true)
		GameEvent.Kind.DEADLINES_EXTENDED:
			return Line.new(t("SENDER_APP"), t("FEED_DEADLINES_EXTENDED") % event.value)
		GameEvent.Kind.WORKS_MOVED:
			return Line.new(t("SENDER_APP"), t("FEED_WORKS_MOVED"))
		GameEvent.Kind.RETURNED_TO_RESTAURANT:
			return Line.new(t("SENDER_BAG"), t("FEED_RETURNED_TO_RESTAURANT")
					% ["#%d %s" % [event.order.id, name_of(event.order.dish)], restaurant_at(state, event.order.restaurant)])
		GameEvent.Kind.NIGHT_ENDED:
			return Line.new(t("SENDER_APP"), t("FEED_NIGHT_ENDED") % event.value)
	return null


static func _delivery_line(event: GameEvent, state: GameState) -> Line:
	var delivery := event.delivery
	var order := event.order
	var where := client(state, order.client)
	var sender: String = t("SENDER_VIP" if order.modifiers.vip else "SENDER_DELIVERY")
	var change := stars_change(delivery.rating_tenths)
	match delivery.outcome:
		Delivery.Outcome.LATE:
			return Line.new(sender, t("FEED_DELIVERED_LATE") % [where, euros(delivery.pay), change], true)
		Delivery.Outcome.DAMAGED:
			return Line.new(sender, t("FEED_DELIVERED_DAMAGED") % [where, euros(delivery.pay), change], true)
	var text: String = t("FEED_DELIVERED_PERFECT") % [where, euros(delivery.pay), euros(delivery.tip)]
	if delivery.bonus > 0:
		text += " " + t("FEED_DELIVERED_BONUS") % euros(delivery.bonus)
	text += " " + t("FEED_DELIVERED_PERFECT_END") % change
	return Line.new(sender, text)


## "#3 Pizza, #5 Soda" for the dishes of these orders still in the run.
static func _dishes(state: GameState, order_ids: Array[int]) -> String:
	var names := PackedStringArray()
	for id in order_ids:
		var order := state.find_order(id)
		names.append("#%d %s" % [id, name_of(order.dish)] if order != null else "#%d" % id)
	return ", ".join(names)


## The label of the button that takes the dish of this order (by the courier, on the map).
static func take_label(order: Order) -> String:
	return t("MAP_TAKE") % [order.id, name_of(order.dish)]


## Names of the equipment bought during the run.
static func equipment_names(state: GameState) -> PackedStringArray:
	var names := PackedStringArray()
	for id in state.equipment:
		names.append(name_of(state.content.equipment[id]))
	return names


## What the (i) of the narrow top bar shows: the profile, the event of the night and the equipment.
static func night_info(state: GameState) -> String:
	var profile: ProfileData = state.content.profiles[state.profile]
	var event: EventData = state.content.events[state.event]
	var lines := PackedStringArray([
		t("HUD_INFO_LINE") % [t("HUD_PROFILE"), name_of(profile), description_of(profile)],
		t("HUD_INFO_LINE") % [t("HUD_EVENT"), name_of(event), description_of(event)],
	])
	if not state.equipment.is_empty():
		lines.append(t("HUD_INFO_EQUIPMENT") % [t("HUD_EQUIPMENT"), ", ".join(equipment_names(state))])
	return "\n\n".join(lines)
