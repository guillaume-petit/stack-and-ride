class_name PlaytestReport
extends RefCounted
## Gathers the runs kept by the game (RunSave.archive()) into a report, with the tables of the
## bot's report (Simulation.tables()) to compare people and bot.

var content: GameContent
## The files read: their data (see RunSave.archive()), oldest first.
var runs: Array[Dictionary] = []
## Files that could not be read, or of another version.
var skipped: int = 0


func _init(p_content: GameContent) -> void:
	content = p_content


## Reads every .json file of the folder (only the runs of this version, if given). Returns false if
## the folder cannot be opened.
func read_folder(folder: String, version: String = "") -> bool:
	var dir := DirAccess.open(folder)
	if dir == null:
		return false
	var names := Array(dir.get_files())
	names.sort()
	for name: String in names:
		if not name.ends_with(".json"):
			continue
		var data := RunSave.read_json(folder.path_join(name))
		if not _is_run(data) or (version != "" and data.get("version") != version):
			skipped += 1
			continue
		runs.append(data)
	return true


func text(folder: String, version: String) -> String:
	var lines := PackedStringArray()
	lines.append("# Parties de test")
	lines.append("")
	lines.append("Généré par `scripts/run_playtests.sh` : ne pas modifier à la main.")
	lines.append("")
	var versions: Array[String] = []
	for run in runs:
		if not versions.has(str(run.get("version", "?"))):
			versions.append(str(run.get("version", "?")))
	lines.append("- %d parties jouées par des personnes, lues dans `%s`%s." % [runs.size(), folder,
			" (version %s seulement)" % version if version != "" else ""])
	if not versions.is_empty():
		lines.append("- Versions du jeu : %s. Les chiffres changent d'une version à l'autre : comparer des parties de la même version." % ", ".join(versions))
	if skipped > 0:
		lines.append("- %d fichiers ignorés (illisibles ou d'une autre version)." % skipped)
	lines.append("- À comparer avec le rapport du bot, [balance-report.md](balance-report.md).")
	lines.append("")
	lines.append("## Les parties")
	lines.append("")
	lines.append("| Date | Version | Profil | Fin | Soir | Gains | Note |")
	lines.append("|---|---|---|---|---|---|---|")
	for run in runs:
		var summary: Dictionary = run["summary"]
		lines.append("| %s | %s | %s | %s | %d | %d € | %s |" % [str(run.get("date", "?")).replace("T", " "),
				str(run.get("version", "?")), summary["profile"], _outcome(summary["outcome"]), summary["night"],
				summary["total_earnings"], ("%.1f" % (summary["rating"] / 10.0)).replace(".", ",")])
	lines.append("")
	lines.append_array(Simulation.tables(stats(), content, "Abandonnées"))
	return "\n".join(lines)


## The numbers of each profile that has runs, in the order of the content.
func stats() -> Array[Simulation.ProfileStats]:
	var by_profile: Dictionary[String, Simulation.ProfileStats] = {}
	for run in runs:
		var summary: Dictionary = run["summary"]
		var profile: String = summary["profile"]
		if not by_profile.has(profile):
			by_profile[profile] = Simulation.ProfileStats.new(StringName(profile), content.config.nights)
		Simulation.add_summary(by_profile[profile], summary)
	var out: Array[Simulation.ProfileStats] = []
	for id in content.profile_ids():
		if by_profile.has(String(id)):
			out.append(by_profile[String(id)])
			by_profile.erase(String(id))
	out.append_array(by_profile.values())
	return out


static func _outcome(outcome: String) -> String:
	match outcome:
		RunSummary.WON:
			return "victoire"
		RunSummary.LOST_RENT:
			return "loyer impayé"
		RunSummary.LOST_RATING:
			return "note trop basse"
	return "abandon"


## A run kept by the game: its summary has every number of the report.
static func _is_run(data: Dictionary) -> bool:
	var summary: Variant = data.get("summary")
	if not summary is Dictionary:
		return false
	for key in ["profile", "outcome", "night", "acceptance", "rating", "total_earnings", "perfect", "late",
			"damaged", "cancelled", "crushed"]:
		if not summary.has(key):
			return false
	return summary["nights"] is Array and summary["shakes"] is Dictionary and summary["shake_damage"] is Dictionary \
			and summary["profile"] is String and summary["outcome"] is String
