class_name CityView
extends Control
## The neighbourhood map: streets, buildings, the courier, the crossroads the courier can
## reach, the path to the crossroads under the mouse and a pin for each accepted order.
##
## Everything is drawn in _draw() (Godot calls it after queue_redraw()), sized to the space
## the screen gives the map. A click on a crossroads emits crossroads_clicked.
##
## With a finger there is no hover: a first touch on a crossroads within reach shows the path,
## a second touch on the same crossroads emits crossroads_clicked.

signal crossroads_clicked(crossroads: Vector2i)
## The courier, riding, reached the next crossroads of its path (for the sound of the pedals).
signal rode_past(crossroads: Vector2i)

## A text that rises from a crossroads and fades: money earned, stars lost.
class Floater:
	extends RefCounted
	var crossroads: Vector2i
	var text: String
	var color: Color
	## From 0 (appears) to 1 (gone); below 0 while it waits for the courier.
	var time: float = 0.0

const MARGIN := 34.0
## Street width and the other sizes are relative to the distance between two crossroads.
const STREET_RATIO := 0.17
const PIN_SIZE := 17.0
## How far from a crossroads a click still selects it, relative to the spacing.
const MOUSE_REACH := 1.0 / 3.0
const TOUCH_REACH := 0.5
## Seconds to ride from one crossroads to the next.
const RIDE_STEP_SECONDS := 0.12
const FLOAT_SECONDS := 1.4
const FLOAT_RISE := 42.0
const FLOAT_FONT_SIZE := 20

var game: Game
## Crossroads to ring, e.g. the restaurant and clients of the offer under the mouse.
var highlighted: Array[Vector2i] = []

## Crossroads under the mouse, or chosen by a first touch.
var _hovered := City.NOWHERE
## Paths from the courier and crossroads within reach, computed once per refresh().
var _paths: CityPaths
var _reachable: Array[Vector2i] = []
## The path being ridden (from the start crossroads), empty when the courier stands still.
var _ride: Array[Vector2i] = []
## How far along _ride the courier is drawn, in streets.
var _ride_progress: float = 0.0
var _ride_tween: Tween
var _floaters: Array[Floater] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func refresh() -> void:
	_paths = game.paths()
	_reachable = game.reachable()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var crossroads := _crossroads_at(motion.position)
		if crossroads != _hovered:
			_hovered = crossroads
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if crossroads in _reachable \
					else Control.CURSOR_ARROW
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var crossroads := _crossroads_at(click.position)
		if crossroads == City.NOWHERE:
			return
		accept_event()
		if Device.is_touch(event) and crossroads in _reachable and crossroads != _hovered:
			_hovered = crossroads
			queue_redraw()
			return
		crossroads_clicked.emit(crossroads)


func _notification(what: int) -> void:
	# A finger leaves the mouse on the map after a touch: keep the chosen crossroads.
	if what == NOTIFICATION_MOUSE_EXIT and _hovered != City.NOWHERE and not Device.touch_screen():
		_hovered = City.NOWHERE
		queue_redraw()


# --- Animations -----------------------------------------------------------------------------

## Seconds the ride along this many streets lasts.
static func ride_seconds(streets: int) -> float:
	return RIDE_STEP_SECONDS * streets


## Shows the courier riding along the path, from its first crossroads to its last. The game has
## already moved it: only the drawing catches up.
func ride(path: Array[Vector2i]) -> void:
	if not is_inside_tree() or path.size() < 2:
		return
	if _ride_tween != null:
		_ride_tween.kill()
	_ride = path
	_ride_progress = 0.0
	_ride_tween = create_tween()
	_ride_tween.tween_method(_set_ride_progress, 0.0, float(path.size() - 1), ride_seconds(path.size() - 1))
	_ride_tween.tween_callback(func() -> void:
		_ride = []
		queue_redraw())


func _set_ride_progress(value: float) -> void:
	var passed := floori(value)
	if passed > floori(_ride_progress) and passed < _ride.size():
		rode_past.emit(_ride[passed])
	_ride_progress = value
	queue_redraw()


## A text rising from a crossroads, after delay seconds (e.g. once the courier gets there).
func float_text(crossroads: Vector2i, text: String, color: Color, delay: float = 0.0) -> void:
	if not is_inside_tree():
		return
	var floater := Floater.new()
	floater.crossroads = crossroads
	floater.text = text
	floater.color = color
	floater.time = -1.0
	_floaters.append(floater)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(value: float) -> void:
		floater.time = value
		queue_redraw(), 0.0, 1.0, FLOAT_SECONDS)
	tween.tween_callback(func() -> void:
		_floaters.erase(floater)
		queue_redraw())


func _draw_floaters() -> void:
	var font := UiStyle.bold_font()
	for floater in _floaters:
		if floater.time < 0.0:
			continue
		var ease_out := 1.0 - pow(1.0 - floater.time, 3)
		var at := _point(floater.crossroads) - Vector2(0, 18 + FLOAT_RISE * ease_out)
		var alpha := 1.0 if floater.time < 0.6 else (1.0 - floater.time) / 0.4
		var width := font.get_string_size(floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT_SIZE).x
		var start := at - Vector2(width / 2, 0)
		draw_string_outline(font, start, floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT_SIZE, 6,
				Color(Color.WHITE, alpha))
		draw_string(font, start, floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT_SIZE,
				Color(floater.color, alpha))


# --- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	if game == null or _paths == null:
		return
	var city := game.state.city
	var spacing := _spacing()
	var street_width := spacing * STREET_RATIO
	draw_rect(Rect2(_point(Vector2i.ZERO), Vector2(city.columns - 1, city.rows - 1) * spacing), UiStyle.BLOCK)
	for street in [City.Street.NORMAL, City.Street.PAVED, City.Street.WORKS]:
		for key in city.streets_of(street):
			_draw_street(key, street, street_width)
	for y in city.rows:
		for x in city.columns:
			draw_circle(_point(Vector2i(x, y)), street_width / 2, UiStyle.STREET)
	for place in [City.Place.BASE, City.Place.RESTAURANT, City.Place.CLIENT]:
		for crossroads in city.crossroads_with(place):
			_draw_building(crossroads, place, spacing, street_width)
	for crossroads in _reachable:
		draw_circle(_point(crossroads), street_width * 0.75, Color(UiStyle.MUSTARD, 0.35))
		draw_arc(_point(crossroads), street_width * 0.75, 0, TAU, 24, UiStyle.MUSTARD, 2.5, true)
	if _hovered in _reachable and _ride.is_empty():
		_draw_path(street_width)
	for crossroads in highlighted:
		draw_arc(_point(crossroads), street_width * 1.1, 0, TAU, 32, UiStyle.ACCENT, 3.5, true)
	_draw_pins(street_width)
	_draw_courier(street_width)
	_draw_floaters()


func _draw_street(key: Vector4i, street: City.Street, width: float) -> void:
	var ends := City.street_ends(key)
	var from := _point(ends[0])
	var to := _point(ends[1])
	match street:
		City.Street.NORMAL:
			draw_line(from, to, UiStyle.STREET, width)
		City.Street.PAVED:
			draw_line(from, to, UiStyle.PAVED.lerp(UiStyle.STREET, 0.4), width)
			# Cobbles: a row of dots along the street.
			for i in range(1, 9):
				draw_circle(from.lerp(to, i / 9.0), width * 0.16, UiStyle.PAVED.darkened(0.25))
		City.Street.WORKS:
			# Orange and white stripes, with a barrier across the middle.
			var count := 8
			for i in count:
				var color := UiStyle.WORKS if i % 2 == 0 else UiStyle.STREET
				draw_line(from.lerp(to, float(i) / count), from.lerp(to, float(i + 1) / count), color, width)
			var middle := (from + to) / 2
			var across := (to - from).normalized().orthogonal() * width * 0.8
			draw_line(middle - across, middle + across, UiStyle.INK, 4.0)


## The building takes the corner of its block that touches its crossroads, with a "door"
## line to the crossroads.
func _draw_building(crossroads: Vector2i, place: City.Place, spacing: float, street_width: float) -> void:
	var city := game.state.city
	var block := city.building_block(crossroads)
	if block == City.NOWHERE:
		return
	var corner := _point(crossroads)
	var block_center := _point(block) + Vector2.ONE * spacing / 2
	var toward := (block_center - corner).sign()
	var near := corner + toward * (street_width / 2 + 2)
	var far := block_center - toward * 3
	var rect := Rect2(near, Vector2.ZERO).expand(far)
	var color := UiStyle.INK
	var text_color := Color.WHITE
	var text := ""
	match place:
		City.Place.BASE:
			text = UiText.t("MAP_BASE")
		City.Place.RESTAURANT:
			var kind := city.restaurant_kind_at(crossroads)
			color = UiStyle.restaurant_color(kind)
			text = UiText.restaurant_short(game.state.content.restaurants[kind])
		City.Place.CLIENT:
			color = Color("#f6f3ee")
			text_color = UiStyle.MUTED
			text = UiText.client(game.state, crossroads)
	draw_line(corner, near, color.darkened(0.15), 4.0)
	draw_rect(rect, color)
	if place == City.Place.CLIENT:
		draw_rect(rect, UiStyle.LINE, false, 1.0)
	# The name may be wider than the building: it is written on a tag centered on it.
	var font := UiStyle.bold_font()
	var font_size := int(clampf(spacing * 0.15, 10, 13))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var tag := Rect2(rect.get_center() - Vector2(text_size.x / 2 + 3, font_size * 0.65),
			Vector2(text_size.x + 6, font_size * 1.3))
	if tag.size.x > rect.size.x:
		draw_rect(tag, color)
		if place == City.Place.CLIENT:
			draw_rect(tag, UiStyle.LINE, false, 1.0)
	draw_string(font, Vector2(tag.position.x + 3, tag.get_center().y + font_size * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


## The path the courier would take to the hovered crossroads, and its length in steps.
func _draw_path(street_width: float) -> void:
	var paths := _paths
	var points := PackedVector2Array([_point(game.state.courier_position)])
	for crossroads in paths.path_to(_hovered):
		points.append(_point(crossroads))
	draw_polyline(points, UiStyle.MUSTARD.darkened(0.1), street_width * 0.45, true)
	var target := _point(_hovered)
	var radius := street_width * 0.9
	draw_circle(target, radius, UiStyle.INK)
	draw_string(UiStyle.bold_font(), target + Vector2(-radius, radius * 0.4), str(paths.distance_to(_hovered)),
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2, int(radius * 1.1), Color.WHITE)


## A round pin at the restaurant for each dish to pick up, a square pin at the client for
## each dish picked up; colored by order, with the order number.
func _draw_pins(street_width: float) -> void:
	var by_place: Dictionary[Vector2i, Array] = {}
	for order in game.state.orders:
		var where := order.client if order.picked_up else order.restaurant
		if not by_place.has(where):
			by_place[where] = []
		by_place[where].append(order)
	var font := UiStyle.bold_font()
	var city := game.state.city
	for where: Vector2i in by_place:
		# On the side of the crossroads opposite to the building, so that its name stays readable.
		var toward := Vector2(1, -1)
		var block := city.building_block(where)
		if block != City.NOWHERE:
			toward = -(_point(block) + Vector2.ONE * _spacing() / 2 - _point(where)).sign()
		var orders: Array = by_place[where]
		var row_width := orders.size() * (PIN_SIZE + 2) - 2
		var anchor := _point(where) + toward * (street_width * 0.6 + PIN_SIZE / 2)
		var start := anchor - Vector2(PIN_SIZE / 2 if toward.x > 0 else row_width - PIN_SIZE / 2, PIN_SIZE / 2)
		var index := 0
		for order: Order in orders:
			var rect := Rect2(start + Vector2(index * (PIN_SIZE + 2), 0), Vector2(PIN_SIZE, PIN_SIZE))
			var color := UiStyle.order_color(order.id)
			if order.picked_up:
				draw_rect(rect.grow(2), Color.WHITE)
				draw_rect(rect, color)
			else:
				draw_circle(rect.get_center(), PIN_SIZE / 2 + 2, Color.WHITE)
				draw_circle(rect.get_center(), PIN_SIZE / 2, color)
			draw_string(font, Vector2(rect.position.x, rect.end.y - 4), str(order.id),
					HORIZONTAL_ALIGNMENT_CENTER, PIN_SIZE, 11, Color.WHITE)
			index += 1


## A red disc with a small bike.
func _draw_courier(street_width: float) -> void:
	var center := _point(game.state.courier_position)
	if not _ride.is_empty():
		var street := mini(floori(_ride_progress), _ride.size() - 2)
		center = _point(_ride[street]).lerp(_point(_ride[street + 1]), _ride_progress - street)
	var radius := maxf(street_width * 1.05, 13.0)
	draw_circle(center + Vector2(0, 2), radius + 2, Color(0, 0, 0, 0.25))
	draw_circle(center, radius + 2, Color.WHITE)
	draw_circle(center, radius, UiStyle.ACCENT)
	var wheel := radius * 0.3
	var back := center + Vector2(-radius * 0.42, radius * 0.18)
	var front := center + Vector2(radius * 0.42, radius * 0.18)
	var seat := center + Vector2(-radius * 0.12, -radius * 0.3)
	var bar := center + Vector2(radius * 0.3, -radius * 0.38)
	for wheel_center in [back, front]:
		draw_arc(wheel_center, wheel, 0, TAU, 16, Color.WHITE, 2.0, true)
	draw_polyline(PackedVector2Array([back, seat, center + Vector2(0, radius * 0.18), back]), Color.WHITE, 2.0, true)
	draw_polyline(PackedVector2Array([seat, bar, front]), Color.WHITE, 2.0, true)


# --- Geometry -------------------------------------------------------------------------------

func _spacing() -> float:
	var city := game.state.city
	var free := size - Vector2.ONE * MARGIN * 2
	return maxf(10.0, minf(free.x / maxi(1, city.columns - 1), free.y / maxi(1, city.rows - 1)))


## Screen position of a crossroads, the map being centered in the view.
func _point(crossroads: Vector2i) -> Vector2:
	var city := game.state.city
	var spacing := _spacing()
	var map_size := Vector2(city.columns - 1, city.rows - 1) * spacing
	return (size - map_size) / 2 + Vector2(crossroads) * spacing


## Crossroads close enough to a position, or NOWHERE. A finger is less precise than a mouse:
## it may land anywhere around the crossroads.
func _crossroads_at(position: Vector2) -> Vector2i:
	var city := game.state.city
	var spacing := _spacing()
	var origin := _point(Vector2i.ZERO)
	var crossroads := Vector2i(((position - origin) / spacing).round())
	var reach := spacing * (TOUCH_REACH if Device.touch_screen() else MOUSE_REACH)
	if not city.is_inside(crossroads) or position.distance_to(_point(crossroads)) > reach:
		return City.NOWHERE
	return crossroads
