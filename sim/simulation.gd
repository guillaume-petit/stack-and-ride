class_name Simulation
extends RefCounted
## Plays many runs with the bot and gathers the numbers of the balance report.
##
## Every profile plays the same seeds (so the same cities), to compare them fairly.


## The numbers of one profile.
class ProfileStats:
	extends RefCounted
	var profile: StringName
	var runs: int = 0
	var wins: int = 0
	var rent_losses: int = 0
	var rating_losses: int = 0
	## Runs where the bot got stuck before the end (a bot bug).
	var stuck: int = 0
	## Index n: runs that ended during night n (index 0 unused).
	var ended_on_night: Array[int] = []
	## Index n: runs that played night n until its end, and the sums over them.
	var nights_played: Array[int] = []
	var night_earnings: Array[int] = []
	var night_rating: Array[int] = []
	var night_wallet: Array[int] = []
	var perfect: int = 0
	var late: int = 0
	var damaged: int = 0
	var cancelled: int = 0
	var undelivered: int = 0
	var acceptance_sum: int = 0
	## Source (card id or &"paved") -> number of shakes, and dishes damaged by them.
	var shakes: Dictionary[StringName, int] = {}
	var shake_damage: Dictionary[StringName, int] = {}
	var crushed: int = 0

	func _init(p_profile: StringName, nights: int) -> void:
		profile = p_profile
		for table: Array[int] in [ended_on_night, nights_played, night_earnings, night_rating, night_wallet]:
			table.resize(nights + 1)
			table.fill(0)

	func deliveries() -> int:
		return perfect + late + damaged


## Plays runs_per_profile runs for each profile, with the seeds first_seed, first_seed + 1...
static func run(content: GameContent, runs_per_profile: int, first_seed: int) -> Array[ProfileStats]:
	var out: Array[ProfileStats] = []
	for profile in content.profile_ids():
		var stats := ProfileStats.new(profile, content.config.nights)
		for i in runs_per_profile:
			var game := Bot.play_run(content, first_seed + i, profile)
			if game != null:
				_add_run(stats, game.state)
		out.append(stats)
	return out


static func _add_run(stats: ProfileStats, state: GameState) -> void:
	stats.runs += 1
	match state.phase:
		GameState.Phase.WON:
			stats.wins += 1
		GameState.Phase.LOST:
			if state.loss_reason == GameState.LossReason.RENT:
				stats.rent_losses += 1
			else:
				stats.rating_losses += 1
		_:
			stats.stuck += 1
	stats.ended_on_night[state.night] += 1
	stats.acceptance_sum += state.acceptance
	for summary in state.night_summaries:
		stats.nights_played[summary.night] += 1
		stats.night_earnings[summary.night] += summary.earnings
		stats.night_rating[summary.night] += summary.rating_after
		stats.night_wallet[summary.night] += summary.wallet
		stats.undelivered += summary.undelivered
	for event in state.history:
		match event.kind:
			GameEvent.Kind.DELIVERED:
				match event.delivery.outcome:
					Delivery.Outcome.PERFECT:
						stats.perfect += 1
					Delivery.Outcome.LATE:
						stats.late += 1
					Delivery.Outcome.DAMAGED:
						stats.damaged += 1
			GameEvent.Kind.CANCELLED:
				stats.cancelled += 1
			GameEvent.Kind.SHAKE:
				stats.shakes[event.source] = stats.shakes.get(event.source, 0) + 1
				stats.shake_damage[event.source] = stats.shake_damage.get(event.source, 0) + event.order_ids.size()
			GameEvent.Kind.CRUSHED:
				stats.crushed += event.order_ids.size()


## The report, in Markdown (for the team: French, like the other documents).
static func report(all: Array[ProfileStats], content: GameContent, runs_per_profile: int,
		first_seed: int) -> String:
	var config := content.config
	var lines := PackedStringArray()
	lines.append("# Rapport d'équilibrage")
	lines.append("")
	lines.append("Généré par `scripts/run_sim.sh %d %d` : ne pas modifier à la main." % [runs_per_profile, first_seed])
	lines.append("")
	lines.append("- %d parties par profil, graines %d à %d (les mêmes quartiers pour chaque profil)."
			% [runs_per_profile, first_seed, first_seed + runs_per_profile - 1])
	lines.append("- Joueur : le bot « raisonnable » de `sim/bot.gd` (une stratégie simple et gourmande, pas optimale).")
	lines.append("  Ses résultats donnent des tendances, pas la difficulté ressentie par un humain.")
	lines.append("")

	lines.append("## Résultats par profil")
	lines.append("")
	lines.append("| Profil | Victoires | Défaites (loyer) | Défaites (note) | Bloquées | Taux d'acceptation final |")
	lines.append("|---|---|---|---|---|---|")
	for s in all:
		lines.append("| %s | %s | %s | %s | %d | %d %% |" % [s.profile, _percent(s.wins, s.runs),
				_percent(s.rent_losses, s.runs), _percent(s.rating_losses, s.runs), s.stuck,
				roundi(_average(s.acceptance_sum, s.runs))])
	lines.append("")

	lines.append("## Soir où la partie se termine")
	lines.append("")
	lines.append(_night_header("Profil", config.nights))
	for s in all:
		var cells := PackedStringArray()
		for night in range(1, config.nights + 1):
			cells.append(_percent(s.ended_on_night[night], s.runs))
		lines.append("| %s | %s |" % [s.profile, " | ".join(cells)])
	lines.append("")

	lines.append("## Gains moyens par soir comparés au loyer")
	lines.append("")
	lines.append("Moyenne sur les parties qui ont joué ce soir jusqu'au bout (entre parenthèses : leur nombre).")
	lines.append("")
	lines.append(_night_header("", config.nights))
	var rents := PackedStringArray()
	for night in range(1, config.nights + 1):
		rents.append("%d €" % config.rent_for_night(night))
	lines.append("| Loyer | %s |" % " | ".join(rents))
	for s in all:
		lines.append(_night_row(s, s.night_earnings, config.nights, "%d €"))
	lines.append("")

	lines.append("## Portefeuille moyen après le loyer")
	lines.append("")
	lines.append(_night_header("Profil", config.nights))
	for s in all:
		lines.append(_night_row(s, s.night_wallet, config.nights, "%d €"))
	lines.append("")

	lines.append("## Note moyenne en fin de soir")
	lines.append("")
	lines.append(_night_header("Profil", config.nights))
	for s in all:
		var cells := PackedStringArray()
		for night in range(1, config.nights + 1):
			var played := s.nights_played[night]
			cells.append("—" if played == 0 else "%.1f" % (s.night_rating[night] / 10.0 / played))
		lines.append("| %s | %s |" % [s.profile, " | ".join(cells)])
	lines.append("")

	lines.append("## Livraisons")
	lines.append("")
	lines.append("| Profil | Livraisons par partie | Parfaites | En retard | Abîmées | Annulations par partie | Non livrées par partie |")
	lines.append("|---|---|---|---|---|---|---|")
	for s in all:
		lines.append("| %s | %.1f | %s | %s | %s | %.1f | %.1f |" % [s.profile, _average(s.deliveries(), s.runs),
				_percent(s.perfect, s.deliveries()), _percent(s.late, s.deliveries()),
				_percent(s.damaged, s.deliveries()), _average(s.cancelled, s.runs), _average(s.undelivered, s.runs)])
	lines.append("")

	lines.append("## Secousses")
	lines.append("")
	lines.append("Par partie : nombre de secousses et de plats abîmés, selon la source.")
	lines.append("")
	var sources: Array[StringName] = []
	for s in all:
		for source in s.shakes.keys():
			if not sources.has(source):
				sources.append(source)
	sources.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var header := "| Profil |"
	var rule := "|---|"
	for source in sources:
		header += " %s |" % source
		rule += "---|"
	lines.append(header + " Écrasés |")
	lines.append(rule + "---|")
	for s in all:
		var row := "| %s |" % s.profile
		for source in sources:
			row += " %.1f (%.1f abîmés) |" % [_average(s.shakes.get(source, 0), s.runs),
					_average(s.shake_damage.get(source, 0), s.runs)]
		lines.append(row + " %.1f |" % _average(s.crushed, s.runs))
	lines.append("")
	return "\n".join(lines)


static func _night_header(first: String, nights: int) -> String:
	var titles := PackedStringArray()
	var rule := PackedStringArray()
	for night in range(1, nights + 1):
		titles.append("Soir %d" % night)
		rule.append("---")
	return "| %s | %s |\n|---| %s |" % [first, " | ".join(titles), " | ".join(rule)]


static func _night_row(s: ProfileStats, sums: Array[int], nights: int, format: String) -> String:
	var cells := PackedStringArray()
	for night in range(1, nights + 1):
		var played := s.nights_played[night]
		cells.append("—" if played == 0 else (format % roundi(_average(sums[night], played))) + " (%d)" % played)
	return "| %s | %s |" % [s.profile, " | ".join(cells)]


static func _average(total: int, count: int) -> float:
	return 0.0 if count == 0 else total / float(count)


static func _percent(part: int, total: int) -> String:
	return "—" if total == 0 else "%d %%" % roundi(100.0 * part / total)
