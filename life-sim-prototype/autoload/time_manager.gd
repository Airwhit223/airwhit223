extends Node
## Simulation clock: minutes -> hours -> days -> weeks -> seasons.
## Everything else (NPC schedules, aging, events) reads its pace from here.

signal minute_passed(hour: int, minute: int)
signal hour_changed(hour: int)
signal day_changed(day_index: int, day_of_week: int)
signal week_changed(week_index: int)
signal season_changed(season_index: int)
signal speed_changed(speed: int)

enum Speed { PAUSED, NORMAL, FAST, VERY_FAST }

const SPEED_SCALES := {
	Speed.PAUSED: 0.0,
	Speed.NORMAL: 1.0,
	Speed.FAST: 4.0,
	Speed.VERY_FAST: 15.0,
}
const SPEED_NAMES := {
	Speed.PAUSED: "Paused",
	Speed.NORMAL: "Normal",
	Speed.FAST: "Fast",
	Speed.VERY_FAST: "Very Fast",
}

const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]
const DAY_NAMES := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAYS_PER_WEEK := 7
const WEEKS_PER_SEASON := 3
const DAYS_PER_SEASON := DAYS_PER_WEEK * WEEKS_PER_SEASON
const MINUTES_PER_DAY := 1440

## How many real seconds one in-game minute takes at Normal (1x) speed.
## 0.6s/min -> a full 24h day takes 864 real seconds (~14.4 minutes) at Normal,
## proportionally faster at Fast/Very Fast. This is independent of player and
## NPC movement speed, which always run at real-world pace.
@export var seconds_per_game_minute: float = 0.6

var current_speed: int = Speed.NORMAL
var time_scale: float = 1.0

var minute: int = 0
var hour: int = 8
var day_index: int = 0
var season_index: int = 0

var _accumulator: float = 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_accumulator += delta * time_scale
	var minute_length := seconds_per_game_minute
	while _accumulator >= minute_length:
		_accumulator -= minute_length
		_advance_minute()

func _advance_minute() -> void:
	minute += 1
	if minute >= 60:
		minute = 0
		_advance_hour()
	minute_passed.emit(hour, minute)

func _advance_hour() -> void:
	hour += 1
	if hour >= 24:
		hour = 0
		_advance_day()
	hour_changed.emit(hour)

func _advance_day() -> void:
	day_index += 1
	var previous_season := season_index
	season_index = (day_index / DAYS_PER_SEASON) % 4
	day_changed.emit(day_index, get_day_of_week())
	if get_day_of_week() == 0:
		week_changed.emit(get_week_index())
	if season_index != previous_season:
		season_changed.emit(season_index)

func get_day_of_week() -> int:
	return day_index % DAYS_PER_WEEK

func get_week_index() -> int:
	return day_index / DAYS_PER_WEEK

func is_weekend() -> bool:
	var dow := get_day_of_week()
	return dow == 5 or dow == 6

func get_season_name() -> String:
	return SEASON_NAMES[season_index]

func get_day_name() -> String:
	return DAY_NAMES[get_day_of_week()]

func get_time_string() -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var display_hour := hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minute, suffix]

func get_speed_name() -> String:
	return SPEED_NAMES[current_speed]

func to_dict() -> Dictionary:
	return {"minute": minute, "hour": hour, "day_index": day_index, "season_index": season_index, "current_speed": current_speed}

func from_dict(data: Dictionary) -> void:
	minute = clampi(int(data.get("minute", 0)), 0, 59)
	hour = clampi(int(data.get("hour", 8)), 0, 23)
	day_index = max(0, int(data.get("day_index", 0)))
	season_index = clampi(int(data.get("season_index", day_index / DAYS_PER_SEASON)), 0, SEASON_NAMES.size() - 1)
	set_speed(clampi(int(data.get("current_speed", Speed.NORMAL)), Speed.PAUSED, Speed.VERY_FAST))

## Sets simulation pace only — player/NPC physical movement speed is entirely
## separate and never scales with this, so the world never becomes uncontrollable.
func set_speed(speed: int) -> void:
	current_speed = speed
	time_scale = SPEED_SCALES[speed]
	speed_changed.emit(current_speed)

func toggle_pause() -> void:
	if current_speed == Speed.PAUSED:
		set_speed(Speed.NORMAL)
	else:
		set_speed(Speed.PAUSED)

## Legacy helper kept for compatibility; prefer set_speed().
func set_time_scale(new_scale: float) -> void:
	time_scale = new_scale

## Total elapsed in-game minutes since day 0, hour 0 — handy for comparing "when" two things happened.
func get_total_minutes() -> int:
	return day_index * MINUTES_PER_DAY + hour * 60 + minute

## Jumps the clock straight to the next occurrence of `wake_hour` (today if
## we haven't reached it yet, otherwise tomorrow) WITHOUT ticking through
## every intermediate minute — used for sleep. Fires day_changed (if a day
## boundary was crossed) and hour_changed once at the destination so NPC
## schedules re-evaluate against the new time, plus a "time_jumped" event
## so systems that care about the skipped duration (like restoring an
## NPC's sleep energy in bulk) can react.
func advance_to_morning(wake_hour: int = 7) -> void:
	var current_minute_of_day := hour * 60 + minute
	var wake_minute_of_day := wake_hour * 60
	var minutes_to_add: int
	if wake_minute_of_day > current_minute_of_day:
		minutes_to_add = wake_minute_of_day - current_minute_of_day
	else:
		minutes_to_add = (MINUTES_PER_DAY - current_minute_of_day) + wake_minute_of_day
	_jump_by_minutes(minutes_to_add)

func _jump_by_minutes(total_minutes_to_add: int) -> void:
	var old_day := day_index
	var new_total := get_total_minutes() + total_minutes_to_add
	day_index = new_total / MINUTES_PER_DAY
	var minute_of_day := new_total % MINUTES_PER_DAY
	hour = minute_of_day / 60
	minute = minute_of_day % 60
	season_index = (day_index / DAYS_PER_SEASON) % 4
	_accumulator = 0.0
	if day_index != old_day:
		day_changed.emit(day_index, get_day_of_week())
	hour_changed.emit(hour)
	EventBus.fire("time_jumped", {"minutes": total_minutes_to_add})
