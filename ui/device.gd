class_name Device
extends RefCounted
## What the game runs on: the size of the interface, its layout and how the player points
## (mouse or finger).
##
## Godot stretches the 1280 × 720 interface to fill the window (project settings, Display >
## Window > Stretch). On a phone, that makes texts and buttons a few millimetres high: apply_scale()
## enlarges the interface according to the density of the screen. On a narrow screen (a phone
## held upright, is_narrow()), the top bar keeps to one line and the windows stack their cards.
##
## To try the phone version on a computer, give the window the shape of a phone and add
## arguments after "--", e.g. `godot --path . --resolution 540x1200 -- --ui-scale=2.8 --touch`:
## --ui-scale=X enlarges the interface X times, --narrow forces the narrow version,
## --touch makes the mouse behave like a finger.

const BASE_SIZE := Vector2(1280, 720)
## Size of one unit of the interface on a phone, in density-independent pixels (1/160 inch,
## the unit of Android). Above 1, everything is bigger.
const PHONE_UNIT_DP := 0.9
const DP_PER_INCH := 160.0
const MAX_SCALE := 4.0
## Below this width (in units of the interface), the screen is narrow.
const NARROW_BELOW := 700.0

static var _args_read := false
static var _forced_scale := 0.0
static var _forced_narrow := false
static var _forced_touch := false


## Enlarges the interface of the window to suit its screen, then multiplies it by the size the
## player chose in the options (1 = as chosen for the screen). Safe to call more than once.
static func apply_scale(window: Window, player_size: float = 1.0) -> void:
	_read_args()
	var factor := _forced_scale
	if factor <= 0.0 and OS.has_feature("mobile"):
		var screen := DisplayServer.screen_get_size(window.current_screen)
		factor = scale_for(Vector2(screen), DisplayServer.screen_get_dpi(window.current_screen))
	if factor <= 0.0:
		factor = 1.0
	window.content_scale_factor = factor * player_size


## Extra scale so that one unit of the interface measures PHONE_UNIT_DP on a screen of this
## size (pixels) and density (dots per inch). Never below 1: big screens keep the normal size.
static func scale_for(screen_size: Vector2, dpi: int) -> float:
	if dpi <= 0 or screen_size.x <= 0 or screen_size.y <= 0:
		return 1.0
	# What Godot already does: fit the base size in the screen.
	var stretch := minf(screen_size.x / BASE_SIZE.x, screen_size.y / BASE_SIZE.y)
	var wanted := dpi / DP_PER_INCH * PHONE_UNIT_DP
	return clampf(wanted / stretch, 1.0, MAX_SCALE)


## Whether a screen of this size (in units of the interface) is narrow, like a phone held upright.
static func is_narrow(visible_size: Vector2) -> bool:
	_read_args()
	return _forced_narrow or visible_size.x < NARROW_BELOW


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
		if arg == "--narrow":
			_forced_narrow = true
		elif arg == "--touch":
			_forced_touch = true
		elif arg.begins_with("--ui-scale="):
			_forced_scale = maxf(0.0, arg.trim_prefix("--ui-scale=").to_float())
