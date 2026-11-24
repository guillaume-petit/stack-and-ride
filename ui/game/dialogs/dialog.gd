class_name Dialog
extends PanelContainer
## Base of the windows shown over the board (profile, end of night, shop, end of run):
## a framed panel with a title, filled by setup() in each subclass.

var game: Game
## Narrow screen (a phone held upright): set before setup(), cards are stacked instead of side
## by side.
var narrow: bool = false
## Contents go in this box, under the title.
var body: VBoxContainer


func _init() -> void:
	theme_type_variation = "Modal"
	body = UiStyle.vbox(12)
	add_child(body)


## Builds the contents from the state of the run.
func setup(p_game: Game) -> void:
	game = p_game


func add_title(text: String) -> void:
	body.add_child(UiStyle.label(text, UiStyle.BIG_FONT_SIZE, UiStyle.INK, true))


func add_text(text: String, color: Color = UiStyle.INK) -> Label:
	var label := UiStyle.paragraph(text, UiStyle.FONT_SIZE, color)
	body.add_child(label)
	return label


## A row of buttons aligned to the right.
func add_buttons(buttons: Array[Button]) -> void:
	var row := UiStyle.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	for button in buttons:
		row.add_child(button)
	body.add_child(row)


## The accounts of a night (§9): earnings, rent, wallet, undelivered orders, rating.
static func ledger(summary: NightSummary, state: GameState) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 3)
	var rows: Array[Array] = [
		[UiText.t("LEDGER_EARNINGS"), UiText.euros(summary.earnings)],
		[UiText.t("LEDGER_RENT"), UiText.euros(-summary.rent) if summary.rent_paid
				else UiText.t("LEDGER_RENT_UNPAID") % UiText.euros(summary.shortfall)],
		[UiText.t("LEDGER_WALLET"), UiText.euros(summary.wallet)],
		[UiText.t("LEDGER_UNDELIVERED"), str(summary.undelivered)],
		[UiText.t("LEDGER_ACCEPTANCE"), "%d %%" % state.acceptance],
		[UiText.t("LEDGER_RATING"), "%s → %s" % [UiText.stars(summary.rating_before), UiText.stars(summary.rating_after)]],
	]
	for row in rows:
		grid.add_child(UiStyle.label(row[0]))
		var value := UiStyle.label(row[1], UiStyle.FONT_SIZE, UiStyle.INK, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	return grid


## A reward as a clickable card: its kind, name and description.
static func reward_card(reward: Reward, content: GameContent) -> ClickCard:
	var card := ClickCard.new(UiStyle.BACKGROUND, UiStyle.LINE)
	var data := UiText.reward_content(reward, content)
	card.add(UiStyle.label(UiText.reward_kind(reward).to_upper(), 10, UiStyle.ACCENT, true))
	card.add(UiStyle.label(UiText.name_of(data), UiStyle.FONT_SIZE + 1, UiStyle.INK, true))
	card.add(UiStyle.paragraph(UiText.description_of(data), UiStyle.SMALL_FONT_SIZE + 1, UiStyle.MUTED))
	return card
