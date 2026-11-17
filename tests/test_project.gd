extends TestCase
## Smoke tests on the project setup itself.


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Stack & Ride")


func test_landscape_base_resolution() -> void:
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_true(w > h, "the game is designed for landscape")


func test_french_translation_file_exists() -> void:
	assert_true(FileAccess.file_exists("res://i18n/fr.po"))


func test_main_scene_exists() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(path), "main scene %s is missing" % path)
