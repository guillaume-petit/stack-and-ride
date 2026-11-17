class_name ErrorCatcher
extends Logger
## Records the errors reported by the engine (script errors, failed asserts, push_error...)
## so that the test runner can fail the test during which they happened.
## Without it, a script error only prints a message and the test still counts as passed.

var _errors: PackedStringArray = PackedStringArray()
## Loggers can be called from any thread.
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var text := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("engine error: %s (%s:%d in %s)" % [text, file, line, function])
	_mutex.unlock()


## Returns the errors recorded since the last call and clears them.
func take_errors() -> PackedStringArray:
	_mutex.lock()
	var out := _errors
	_errors = PackedStringArray()
	_mutex.unlock()
	return out
