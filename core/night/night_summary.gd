class_name NightSummary
extends RefCounted
## What happened during a night, shown at its end (design doc §9) and read by the bot report.

var night: int
var event: StringName
## Money earned during the night.
var earnings: int = 0
var rent: int = 0
var rent_paid: bool = false
## Money missing to pay the rent (0 when paid).
var shortfall: int = 0
## Accepted orders not delivered.
var undelivered: int = 0
## Rating at the end of the last turn, and after the night penalties, in tenths.
var rating_before: int = 0
var rating_after: int = 0
## Wallet after the rent.
var wallet: int = 0
