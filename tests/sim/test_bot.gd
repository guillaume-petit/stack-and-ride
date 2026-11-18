extends TestCase
## The balancing bot and the simulation report (sim/).

var content: GameContent


func before_each() -> void:
	content = GameContent.load_from()


func test_the_bot_finishes_its_runs() -> void:
	for profile in content.profile_ids():
		for seed in range(1, 4):
			var game := Bot.play_run(content, seed, profile)
			assert_true(game.state.phase in [GameState.Phase.WON, GameState.Phase.LOST],
					"%s, seed %d: stuck at night %d" % [profile, seed, game.state.night])


func test_the_bot_delivers_and_earns() -> void:
	var game := Bot.play_run(content, 1, &"sprinter")
	assert_true(game.state.total_earnings > 0)
	assert_true(game.state.history.any(func(e: GameEvent) -> bool: return e.kind == GameEvent.Kind.DELIVERED))


func test_same_seed_same_run() -> void:
	var a := Bot.play_run(content, 7, &"mule").state
	var b := Bot.play_run(content, 7, &"mule").state
	assert_eq([a.phase, a.night, a.turn, a.wallet, a.rating_tenths, a.history.size()],
			[b.phase, b.night, b.turn, b.wallet, b.rating_tenths, b.history.size()])


func test_the_report_has_every_section_and_every_profile() -> void:
	var stats := Simulation.run(content, 2, 1)
	assert_eq(stats.size(), 4)
	for s in stats:
		assert_eq(s.runs, 2)
		assert_eq(s.wins + s.rent_losses + s.rating_losses + s.stuck, 2)
	var text := Simulation.report(stats, content, 2, 1)
	for title in ["# Rapport d'équilibrage", "## Résultats par profil", "## Gains moyens par soir",
			"## Note moyenne", "## Livraisons", "## Secousses"]:
		assert_true(text.contains(title), title)
	for profile in content.profile_ids():
		assert_true(text.contains("| %s |" % profile), String(profile))
	assert_eq(text, Simulation.report(Simulation.run(content, 2, 1), content, 2, 1), "same report twice")
