extends Node
## Global event framework. Anything interesting that happens in the sim fires
## through here instead of being wired NPC-to-NPC or NPC-to-UI directly.
##
## Milestone 1 only fires "mundane" events (shift started, invite accepted,
## relationship changed, basketball scored, birthdays...). The point of routing
## even these small things through one bus is that later, bigger life-sim
## events (arguments, crushes, confessions, festivals, cookouts...) are just
## more calls to fire()/schedule() plus new listeners — no new plumbing.

signal event_fired(event_name: String, data: Dictionary)

const HISTORY_LIMIT := 200

var recent_events: Array[Dictionary] = []
var _scheduled: Array[Dictionary] = []

func fire(event_name: String, data: Dictionary = {}) -> void:
	var entry := {
		"name": event_name,
		"data": data,
		"day": TimeManager.day_index,
		"hour": TimeManager.hour,
		"minute": TimeManager.minute,
	}
	recent_events.push_back(entry)
	if recent_events.size() > HISTORY_LIMIT:
		recent_events.pop_front()
	event_fired.emit(event_name, data)

## Queue an event for a future in-game day/hour. Checked once per hour tick.
func schedule(event_name: String, data: Dictionary, at_day: int, at_hour: int) -> void:
	_scheduled.push_back({
		"name": event_name,
		"data": data,
		"day": at_day,
		"hour": at_hour,
	})

func _ready() -> void:
	TimeManager.hour_changed.connect(_on_hour_changed)

func _on_hour_changed(_hour: int) -> void:
	var due: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for entry in _scheduled:
		if entry.day < TimeManager.day_index or (entry.day == TimeManager.day_index and entry.hour <= TimeManager.hour):
			due.push_back(entry)
		else:
			remaining.push_back(entry)
	_scheduled = remaining
	for entry in due:
		fire(entry.name, entry.data)
