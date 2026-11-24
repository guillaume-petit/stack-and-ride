class_name HowToPlayDialog
extends Dialog
## "How to play": the rules in a few short pages, read one after the other. Opens by itself before
## the first run, and from the menus.

signal closed

## One page per entry: its texts are HOWTO_<page>_TITLE and HOWTO_<page>_TEXT.
const PAGES: Array[String] = ["GOAL", "APP", "CARDS", "BAG", "DELIVER", "NIGHTS"]

## Page shown, from 0.
var page: int = 0


func setup(p_game: Game) -> void:
	super(p_game)
	custom_minimum_size.x = 520
	show_page(0)


func show_page(index: int) -> void:
	page = clampi(index, 0, PAGES.size() - 1)
	UiStyle.clear(body)
	var header := UiStyle.hbox(8)
	var title := UiStyle.label(UiText.t("HOWTO_%s_TITLE" % PAGES[page]), UiStyle.BIG_FONT_SIZE, UiStyle.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiStyle.label(UiText.t("HOWTO_PAGE") % [page + 1, PAGES.size()], UiStyle.SMALL_FONT_SIZE,
			UiStyle.MUTED))
	body.add_child(header)
	for paragraph in UiText.t("HOWTO_%s_TEXT" % PAGES[page]).split("\n"):
		add_text(paragraph)
	var last := page == PAGES.size() - 1
	var buttons: Array[Button] = []
	if page > 0:
		buttons.append(UiStyle.button(UiText.t("HOWTO_PREVIOUS"), show_page.bind(page - 1)))
	else:
		buttons.append(UiStyle.button(UiText.t("HOWTO_SKIP"), func() -> void: closed.emit()))
	if last:
		buttons.append(UiStyle.button(UiText.t("HOWTO_DONE"), func() -> void: closed.emit(), "AccentButton"))
	else:
		buttons.append(UiStyle.button(UiText.t("HOWTO_NEXT"), show_page.bind(page + 1), "AccentButton"))
	add_buttons(buttons)
	if is_inside_tree():
		Motion.appear(body)
