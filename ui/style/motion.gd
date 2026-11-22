class_name Motion
extends RefCounted
## Small animations shared by the views: things that appear, counters that change.
##
## They use tweens: a Tween changes a property of a node little by little over a given time
## (Node.create_tween()). Nothing moves outside the scene tree (the tests build the views
## without adding them to it), and an animation never changes the game: it only shows it.

## Durations in seconds.
const APPEAR := 0.22
const PULSE := 0.3
const STAGGER := 0.05
## How much a counter grows when its value changes, and a new card or window when it appears.
const PULSE_SCALE := 1.18
const APPEAR_SCALE := 0.92


## Fades the control in, growing slightly from its center (or from its bottom with from_bottom).
static func appear(control: Control, delay: float = 0.0, from_bottom: bool = false) -> void:
	if not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	# The size of a control in a container is only known once the container has sorted it.
	control.resized.connect(func() -> void: _set_pivot(control, from_bottom), CONNECT_ONE_SHOT)
	_set_pivot(control, from_bottom)
	control.scale = Vector2.ONE * APPEAR_SCALE
	var tween := control.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, APPEAR).set_delay(delay)
	# A container resets the scale of its children when it sorts them (before the tween starts):
	# from() keeps the start value.
	tween.tween_property(control, "scale", Vector2.ONE, APPEAR).from(Vector2.ONE * APPEAR_SCALE).set_delay(delay)


## Makes a counter grow and shrink back, to show that its value changed.
static func pulse(control: Control) -> void:
	if not control.is_inside_tree():
		return
	control.resized.connect(func() -> void: _set_pivot(control, false), CONNECT_ONE_SHOT)
	_set_pivot(control, false)
	control.scale = Vector2.ONE * PULSE_SCALE
	var tween := control.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, PULSE).from(Vector2.ONE * PULSE_SCALE)


static func _set_pivot(control: Control, bottom: bool) -> void:
	control.pivot_offset = Vector2(control.size.x / 2, control.size.y if bottom else control.size.y / 2)
