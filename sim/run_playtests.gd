extends SceneTree
## Report of the runs played by people: the game keeps every run that is over in user://runs
## (RunSave.archive()); this gathers their numbers in the same tables as the bot's report.
##
## Usage: godot --headless --path . --script res://sim/run_playtests.gd -- [folder] [version]
## (or scripts/run_playtests.sh). Without a folder: the runs played on this computer. With a version
## (e.g. 0.0.2): only the runs played with that version of the game. Writes docs/playtest-report.md.

const REPORT_PATH := "res://docs/playtest-report.md"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if args.size() > 0 and args[0] != "" else RunSave.ARCHIVE_FOLDER
	var version := args[1] if args.size() > 1 else ""
	var content := GameContent.load_from()
	var report := PlaytestReport.new(content)
	if not report.read_folder(folder, version):
		printerr("Cannot open the folder %s" % folder)
		quit(1)
		return
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write %s" % REPORT_PATH)
		quit(1)
		return
	file.store_string(report.text(folder, version) + "\n")
	file.close()
	print("%d runs read, %d files skipped. Report written to %s" % [report.runs.size(), report.skipped, REPORT_PATH])
	quit(0)
