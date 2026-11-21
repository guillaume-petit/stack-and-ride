class_name FeedView
extends ScrollContainer
## The notifications: what happened (read from the history of the run) and why an action was
## refused. Newest first.

const MAX_LINES := 40

var game: Game

var _list: VBoxContainer
## History entries already shown.
var _seen: int = 0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UiStyle.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)


## Adds the lines of the events that happened since the last call.
func refresh() -> void:
	var history := game.state.history
	for index in range(_seen, history.size()):
		var line := UiText.event_line(history[index], game.state)
		if line != null:
			add_line(line)
	_seen = history.size()


func add_line(line: UiText.Line) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Inset"
	var column := UiStyle.vbox(1)
	column.add_child(UiStyle.label(line.sender.to_upper(), 10, UiStyle.BAD if line.bad else UiStyle.ACCENT, true))
	column.add_child(UiStyle.paragraph(line.text, UiStyle.SMALL_FONT_SIZE + 1))
	panel.add_child(column)
	_list.add_child(panel)
	_list.move_child(panel, 0)
	Motion.appear(panel)
	while _list.get_child_count() > MAX_LINES:
		var last := _list.get_child(_list.get_child_count() - 1)
		_list.remove_child(last)
		last.queue_free()
	scroll_vertical = 0


## A refused action, from the app's point of view.
func add_problem(problem: Game.Problem) -> void:
	add_line(UiText.Line.new(UiText.t("SENDER_REFUSED"), UiText.problem(problem), true))
