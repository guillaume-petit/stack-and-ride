class_name RunSummary
extends RefCounted
## The numbers of a finished run (or of a run given up), for the balance reports: the runs of the
## bot (Simulation) and the runs played by people, kept by the game (RunSave.archive()).
##
## A plain Dictionary that can be written as JSON: it stays readable even when the rules change
## later (a run kept as its actions could no longer be played again).

## How the run ended.
const WON := "WON"
const LOST_RENT := "RENT"
const LOST_RATING := "RATING"
## Stopped before its end (given up, or a bot stuck).
const UNFINISHED := "UNFINISHED"


static func of(state: GameState) -> Dictionary:
	var outcome := UNFINISHED
	match state.phase:
		GameState.Phase.WON:
			outcome = WON
		GameState.Phase.LOST:
			outcome = LOST_RENT if state.loss_reason == GameState.LossReason.RENT else LOST_RATING
	var nights: Array = []
	for summary in state.night_summaries:
		nights.append({
			"night": summary.night,
			"earnings": summary.earnings,
			"rating": summary.rating_after,
			"wallet": summary.wallet,
			"undelivered": summary.undelivered,
		})
	var out := {
		"profile": String(state.profile),
		"outcome": outcome,
		"night": state.night,
		"acceptance": state.acceptance,
		"rating": state.rating_tenths,
		"total_earnings": state.total_earnings,
		"nights": nights,
		"perfect": 0,
		"late": 0,
		"damaged": 0,
		"cancelled": 0,
		"crushed": 0,
		"shakes": {},
		"shake_damage": {},
	}
	for event in state.history:
		match event.kind:
			GameEvent.Kind.DELIVERED:
				match event.delivery.outcome:
					Delivery.Outcome.PERFECT:
						out["perfect"] += 1
					Delivery.Outcome.LATE:
						out["late"] += 1
					Delivery.Outcome.DAMAGED:
						out["damaged"] += 1
			GameEvent.Kind.CANCELLED:
				out["cancelled"] += 1
			GameEvent.Kind.SHAKE:
				var source := String(event.source)
				out["shakes"][source] = out["shakes"].get(source, 0) + 1
				out["shake_damage"][source] = out["shake_damage"].get(source, 0) + event.order_ids.size()
			GameEvent.Kind.CRUSHED:
				out["crushed"] += event.order_ids.size()
	return out
