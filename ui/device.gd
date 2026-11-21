class_name Device
extends RefCounted
## What the game runs on: the size of the interface, its layout and how the player points
## (mouse or finger).
##
## Godot stretches the 1280 × 720 interface to fill the window (project settings, Display >
## Window > Stretch). On a phone, that makes texts and buttons a few millimetres high: apply_scale()
## enlarges the interface according to the density of the screen, and the game screen then
## picks its compact layout (is_compact()).
##
## To try the phone version on a computer, add arguments after "--" when launching the game,
## e.g. `godot --path . -- --ui-scale=1.6 --touch`:
## --ui-scale=X enlarges the interface X times, --compact forces the compact layout,
## --touch makes the mouse behave like a finger.

const BASE_SIZE := Vector2(1280, 720)
## Size of one unit of the interface on a phone, in density-independent pixels (1/160 inch,
## the unit of Android). Above 1, everything is bigger.
const PHONE_UNIT_DP := 0.9
const DP_PER_INCH := 160.0
const MAX_SCALE := 3.0
## Below this size (in units of the interface), the compact layout is used.
const COMPACT_BELOW := Vector2(1100, 600)

static var _args_read := false
static var _forced_scale := 0.0
static var _forced_compact := false
static var _forced_touch := false


## Enlarges the interface of the window to suit its screen. Safe to call more than once.
static func apply_scale(window: Window) -> void:
	_read_args()
	var factor := _forced_scale
	if factor <= 0.0 and OS.has_feature("mobile"):
		var screen := DisplayServer.screen_get_size(window.current_screen)
		factor = scale_for(Vector2(screen), DisplayServer.screen_get_dpi(window.current_screen))
	if factor > 0.0:
		window.content_scale_factor = factor


## Extra scale so that one unit of the interface measures PHONE_UNIT_DP on a screen of this
## size (pixels) and density (dots per inch). Never below 1: big screens keep the normal size.
static func scale_for(screen_size: Vector2, dpi: int) -> float:
	if dpi <= 0 or screen_size.x <= 0 or screen_size.y <= 0:
		return 1.0
	# What Godot already does: fit the base size in the screen.
	var stretch := minf(screen_size.x / BASE_SIZE.x, screen_size.y / BASE_SIZE.y)
	var wanted := dpi / DP_PER_INCH * PHONE_UNIT_DP
	return clampf(wanted / stretch, 1.0, MAX_SCALE)


## Whether a screen of this size (in units of the interface) needs the compact layout.
static func is_compact(visible_size: Vector2) -> bool:
	_read_args()
	return _forced_compact or visible_size.x < COMPACT_BELOW.x or visible_size.y < COMPACT_BELOW.y


## Whether the player plays with a finger: texts say "touche" instead of "clique" and nothing
## changes on hover.
static func touch_screen() -> bool:
	_read_args()
	return _forced_touch or OS.has_feature("mobile")


## Whether this click comes from a finger. Godot turns a touch into a mouse click (project
## setting Input Devices > Pointing > Emulate Mouse From Touch) and marks it with a special device.
static func is_touch(event: InputEvent) -> bool:
	_read_args()
	return _forced_touch or event.device == InputEvent.DEVICE_ID_EMULATION


## Room to leave on each side for the notch and rounded corners of a phone, in units of the
## interface: [left, top, right, bottom].
static func safe_margins(viewport: Viewport) -> PackedFloat32Array:
	var out := PackedFloat32Array([0, 0, 0, 0])
	if not OS.has_feature("mobile"):
		return out
	var window := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0:
		return out
	var units := viewport.get_visible_rect().size / Vector2(window)
	out[0] = safe.position.x * units.x
	out[1] = safe.position.y * units.y
	out[2] = (window.x - safe.end.x) * units.x
	out[3] = (window.y - safe.end.y) * units.y
	return out


static func _read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for arg in OS.get_cmdline_user_args():
		if arg == "--compact":
			_forced_compact = true
		elif arg == "--touch":
			_forced_touch = true
		elif arg.begins_with("--ui-scale="):
			_forced_scale = maxf(0.0, arg.trim_prefix("--ui-scale=").to_float())
