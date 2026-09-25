class_name CommunityEventDefinition
extends Resource
## Reusable calendar/event data. Runtime state lives in CommunityEventManager.

@export var id: String = ""
@export var event_name: String = ""
@export_range(0, 6) var day_of_week: int = 5
@export_range(0, 23) var start_hour: int = 18
@export_range(1, 12) var duration_hours: int = 3
@export var location_id: String = "loc_social"
@export_range(0.0, 1.0) var importance: float = 0.5
@export var interest_tags: Array[String] = []
@export var participant_roles: Array[String] = []
@export var setup_lead_hours: int = 1
@export var activity_hooks: Array[String] = []

func end_hour() -> int:
	return (start_hour + duration_hours) % 24

func minutes_until(day_index: int, hour: int, minute: int) -> int:
	var days_ahead := posmod(day_of_week - (day_index % 7), 7)
	var result := days_ahead * TimeManager.MINUTES_PER_DAY + (start_hour - hour) * 60 - minute
	if result < 0:
		result += 7 * TimeManager.MINUTES_PER_DAY
	return result
