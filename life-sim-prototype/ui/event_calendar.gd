class_name EventCalendar
extends PanelContainer
## Compact prototype calendar; it never captures player control.

var _label: Label
var _last_minute := -1

func _ready() -> void:
	position = Vector2(1004, 108)
	custom_minimum_size = Vector2(260, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 9)
	add_child(margin)
	_label = Label.new(); _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; margin.add_child(_label)
	_refresh()

func _process(_delta: float) -> void:
	var now := TimeManager.get_total_minutes()
	if now != _last_minute:
		_last_minute = now
		_refresh()

func _refresh() -> void:
	var lines: Array[String] = ["COMMUNITY CALENDAR"]
	if CommunityEventManager.current_phase == CommunityEventManager.Phase.ACTIVE:
		lines.push_back("NOW — %s" % CommunityEventManager.current_event.event_name)
	for entry in CommunityEventManager.get_upcoming_events(2):
		var event: CommunityEventDefinition = entry["definition"]
		if CommunityEventManager.current_phase == CommunityEventManager.Phase.ACTIVE and event == CommunityEventManager.current_event:
			continue
		var suffix := "PM" if event.start_hour >= 12 else "AM"
		var display_hour := event.start_hour % 12
		if display_hour == 0: display_hour = 12
		lines.push_back("%s\n%d:00 %s — %s" % [TimeManager.DAY_NAMES[event.day_of_week], display_hour, suffix, event.event_name])
	_label.text = "\n".join(lines)
