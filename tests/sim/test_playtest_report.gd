extends TestCase
## The report of the runs played by people: it reads the runs kept by the game and gives the same
## numbers as the bot's report for the same runs.

const FOLDER := "user://test_playtests"

var content: GameContent


func before_each() -> void:
	if content == null:
		content = GameContent.load_from()
	_empty()


func test_same_numbers_as_the_report_of_the_bot() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var bot_stats: Array[Simulation.ProfileStats] = []
	for profile in content.profile_ids():
		var stats := Simulation.ProfileStats.new(profile, content.config.nights)
		for seed in [1, 2]:
			var game := Bot.play_run(content, seed, profile)
			Simulation._add_run(stats, game.state)
			var file := FileAccess.open(FOLDER.path_join("%s_%d.json" % [profile, seed]), FileAccess.WRITE)
			var data := RunSave.to_data(game)
			data["summary"] = RunSummary.of(game.state)
			data["version"] = "test"
			data["date"] = "2026-11-24T20:00:00"
			file.store_string(JSON.stringify(data))
			file.close()
		bot_stats.append(stats)
	var report := PlaytestReport.new(content)
	assert_true(report.read_folder(FOLDER))
	assert_eq(report.runs.size(), 2 * content.profile_ids().size())
	assert_eq(Simulation.tables(report.stats(), content, "Abandonnées"), Simulation.tables(bot_stats, content, "Abandonnées"))
	var text := report.text(FOLDER, "")
	assert_true(text.contains("| Date | Version | Profil |"), "the list of the runs")
	_empty()


func test_other_versions_and_damaged_files_are_skipped() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var game := Bot.play_run(content, 3, &"mule")
	RunSave.archive(game, FOLDER)
	var file := FileAccess.open(FOLDER.path_join("broken.json"), FileAccess.WRITE)
	file.store_string("{\"summary\": 3}")
	file.close()
	var report := PlaytestReport.new(content)
	report.read_folder(FOLDER)
	assert_eq(report.runs.size(), 1)
	assert_eq(report.skipped, 1)
	var only_other := PlaytestReport.new(content)
	only_other.read_folder(FOLDER, "9.9.9")
	assert_eq(only_other.runs.size(), 0)
	assert_eq(only_other.skipped, 2)
	_empty()


func test_no_folder() -> void:
	assert_false(PlaytestReport.new(content).read_folder("user://no_such_folder"))


func _empty() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(FOLDER)
