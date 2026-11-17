extends SceneTree
## Headless test runner.
##
## Usage: godot --headless --path . --script res://tests/run_tests.gd
## Optional filter: append "-- name_part" to run only files whose path contains it.
## Exits with code 0 when every test passes, 1 otherwise.
## A test also fails when the engine reports an error while it runs (see ErrorCatcher).

const TESTS_ROOT := "res://tests"


func _initialize() -> void:
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		filter = user_args[0]

	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var files := _find_test_files(TESTS_ROOT)
	files.sort()
	var passed := 0
	var failed := 0

	for path in files:
		if not filter.is_empty() and not path.contains(filter):
			continue
		var script: GDScript = load(path)
		if script == null:
			print("✗ %s : could not load the script" % path)
			failed += 1
			continue
		var suite: Object = script.new()
		if not suite is TestCase:
			print("✗ %s : must extend TestCase" % path)
			failed += 1
			continue
		print("\n%s" % path.trim_prefix(TESTS_ROOT + "/"))
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			catcher.take_errors()
			suite.before_each()
			suite.call(method_name)
			var failures: PackedStringArray = suite.take_failures()
			failures.append_array(suite.check_engine_errors(catcher.take_errors()))
			if failures.is_empty():
				passed += 1
				print("  ✓ %s" % method_name)
			else:
				failed += 1
				print("  ✗ %s" % method_name)
				for f in failures:
					print("      %s" % f)

	OS.remove_logger(catcher)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _find_test_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_find_test_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			found.append(dir_path.path_join(file))
	return found
