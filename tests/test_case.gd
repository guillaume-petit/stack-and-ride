class_name TestCase
extends RefCounted
## Base class for the project's tests.
##
## A test file is a script named test_*.gd under res://tests that extends
## TestCase. Every method whose name starts with "test_" is a test.
## before_each() runs before every test.

var _failures: PackedStringArray = PackedStringArray()


func before_each() -> void:
	pass


## Returns the failures recorded since the last call and clears them.
func take_failures() -> PackedStringArray:
	var out := _failures
	_failures = PackedStringArray()
	return out


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail(_with_context("expected true, got false", message))


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail(_with_context("expected false, got true", message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same(actual, expected):
		fail(_with_context("expected %s, got %s" % [_show(expected), _show(actual)], message))


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _same(actual, unexpected):
		fail(_with_context("did not expect %s" % _show(unexpected), message))


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail(_with_context("expected null, got %s" % _show(value), message))


func _same(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) != typeof(b) and not (typeof(a) in numeric and typeof(b) in numeric):
		return false
	return a == b


func _show(value: Variant) -> String:
	if value is String:
		return "\"%s\"" % value
	return str(value)


func _with_context(detail: String, message: String) -> String:
	return detail if message.is_empty() else "%s (%s)" % [message, detail]
