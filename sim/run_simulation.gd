extends SceneTree
## Headless balance simulation: the bot plays many runs per profile and writes the report.
##
## Usage: godot --headless --path . --script res://sim/run_simulation.gd -- [runs] [first_seed]
## (or scripts/run_sim.sh). Writes docs/balance-report.md.

const DEFAULT_RUNS := 200
const DEFAULT_FIRST_SEED := 1
const REPORT_PATH := "res://docs/balance-report.md"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else DEFAULT_RUNS
	var first_seed := int(args[1]) if args.size() > 1 else DEFAULT_FIRST_SEED
	var content := GameContent.load_from()
	var problems := content.validate()
	if not problems.is_empty():
		printerr("Content problems:\n" + "\n".join(problems))
		quit(1)
		return
	var start := Time.get_ticks_msec()
	var stats := Simulation.run(content, runs, first_seed)
	var text := Simulation.report(stats, content, runs, first_seed)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write %s" % REPORT_PATH)
		quit(1)
		return
	file.store_string(text + "\n")
	file.close()
	for s in stats:
		print("%-10s %d/%d won" % [s.profile, s.wins, s.runs])
	print("Report written to %s in %.1f s" % [REPORT_PATH, (Time.get_ticks_msec() - start) / 1000.0])
	quit(0)
