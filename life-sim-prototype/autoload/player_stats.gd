extends Node
## Player stats that drift week to week from what the player actually does.
##   Mass   0..1  body weight / softness        } two separate axes, so heavy-and-strong, lean-and-strong,
##   Muscle 0..1  tone / strength               } heavy-and-soft and lean-and-soft builds are all reachable
##   Book Smarts 0..100  (same weekly tick, never touches the body)
## Activity is logged all week (gym, farming, combat, sport, walking, studying, sleeping); at each new week the log is
## evaluated, the stats nudge by a few percent, and the player's Toriyama model blends toward its body archetypes
## (Lean / Stocky / Athletic / Bulk). Long stretches of doing nothing ease Mass and Muscle back toward neutral.
## Later path / power systems read the accessors below; no path logic lives here.

signal week_evaluated(week_index: int, summary: Dictionary)
signal body_changed(mass: float, muscle: float)
signal book_smarts_changed(value: float)

## Starting builds offered at character creation (initial Mass, Muscle).
const ARCHETYPES := {
	"Lean": Vector2(0.20, 0.45),
	"Athletic": Vector2(0.35, 0.75),
	"Stocky": Vector2(0.80, 0.30),
	"Muscular-Bulk": Vector2(0.80, 0.80),
	"Average": Vector2(0.50, 0.50),
}
## Activity units per logged action (tune here).
const UNITS := {
	"workout": 1.0,      # one gym equipment use
	"labor": 0.35,       # one farming action (plant / water); harvest counts double
	"combat": 0.25,      # attack landed / dodge
	"sport": 0.5,        # basket scored
	"walk": 1.0,         # per WALK_METERS_PER_UNIT on foot
	"study": 1.0,        # one study session
}
const WALK_METERS_PER_UNIT := 250.0
const MAX_WEEKLY_MUSCLE_GAIN := 0.10
const MAX_WEEKLY_MASS_LOSS := 0.07
const LOW_ACTIVITY_UNITS := 4.0          # below this, the week counts as sedentary
const IDLE_WEEK_UNITS := 1.0             # at or below this, the week counts as idle
const IDLE_WEEKS_BEFORE_DECAY := 2
const DECAY_TOWARD_NEUTRAL := 0.15       # share of the distance to 0.5 recovered per idle week after that

var mass := 0.5
var muscle := 0.5
var book_smarts := 0.0
var idle_weeks := 0
var week_log: Dictionary = {}
var last_week_index := 0
var history: Array[Dictionary] = []

var _last_player_pos := Vector3.INF
var _applied_to: Object = null


func _ready() -> void:
	_reset_log()
	TimeManager.day_changed.connect(_on_day_changed)
	EventBus.event_fired.connect(_on_event)
	last_week_index = TimeManager.get_week_index()


# ------------------------------------------------------------------ accessors (for path / power systems)
func get_mass() -> float:
	return mass

func get_muscle() -> float:
	return muscle

## 0..100 physical fitness: mostly muscle, a little penalty for high mass.
func get_fitness_level() -> float:
	return clampf(100.0 * (0.8 * muscle + 0.2 * (1.0 - absf(mass - 0.4) / 0.6)), 0.0, 100.0)

func get_book_smarts() -> float:
	return book_smarts

func get_body_descriptor() -> String:
	var heavy := mass >= 0.62
	var light := mass <= 0.38
	var strong := muscle >= 0.62
	var weak := muscle <= 0.38
	if heavy and strong: return "Burly"
	if heavy and weak: return "Soft"
	if heavy: return "Stocky"
	if light and strong: return "Athletic"
	if light and weak: return "Slight"
	if light: return "Lean"
	if strong: return "Toned"
	if weak: return "Out of shape"
	return "Average"


# ------------------------------------------------------------------ setup
func set_starting_archetype(archetype: String) -> void:
	var v: Vector2 = ARCHETYPES.get(archetype, ARCHETYPES["Average"])
	mass = v.x
	muscle = v.y
	_apply_body()

## Anything can log activity: log_activity("study"), log_activity("workout", 2.0) ...
func log_activity(kind: String, amount := 1.0) -> void:
	week_log[kind] = float(week_log.get(kind, 0.0)) + amount * float(UNITS.get(kind, 1.0))


# ------------------------------------------------------------------ logging sources
func _reset_log() -> void:
	week_log = {"workout": 0.0, "labor": 0.0, "combat": 0.0, "sport": 0.0, "walk": 0.0, "study": 0.0, "rest_hours": 0.0}

func _on_event(event_name: String, data: Dictionary) -> void:
	match event_name:
		"crop_planted", "crop_watered":
			log_activity("labor")
		"crop_harvested":
			log_activity("labor", 2.0)
		"player_attack_landed", "player_dodged":
			log_activity("combat")
		"basketball_scored":
			log_activity("sport")
		"time_jumped":
			week_log["rest_hours"] = float(week_log.get("rest_hours", 0.0)) + float(data.get("minutes", 0)) / 60.0

func _physics_process(_delta: float) -> void:
	var player = WorldState.player
	if player == null or not is_instance_valid(player):
		return
	if _applied_to != player:
		_applied_to = player
		_apply_body()
	var pos: Vector3 = player.global_position
	if _last_player_pos != Vector3.INF and player.is_on_floor() and not player.get("is_mounted_skateboard"):
		var step := Vector2(pos.x - _last_player_pos.x, pos.z - _last_player_pos.z).length()
		if step < 2.0:          # ignore teleports (doors, spawns)
			log_activity("walk", step / WALK_METERS_PER_UNIT)
	_last_player_pos = pos


# ------------------------------------------------------------------ weekly evaluation
## TimeManager.week_changed doesn't fire when sleep jumps the clock over a week boundary, so weeks are counted
## from day_changed (every week crossed gets evaluated, in order).
func _on_day_changed(_day_index: int, _dow: int) -> void:
	var week := TimeManager.get_week_index()
	while last_week_index < week:
		last_week_index += 1
		evaluate_week(last_week_index)

func evaluate_week(week_index: int) -> Dictionary:
	var w := week_log
	var physical := float(w.workout) + float(w.labor) + float(w.combat) + float(w.sport) + float(w.walk)
	var d_muscle := minf(0.012 * float(w.workout) + 0.006 * (float(w.labor) + float(w.combat) + float(w.sport)) + 0.004 * float(w.walk),
		MAX_WEEKLY_MUSCLE_GAIN)
	var d_mass := -minf(0.005 * float(w.workout) + 0.004 * (float(w.labor) + float(w.combat) + float(w.sport)) + 0.004 * float(w.walk),
		MAX_WEEKLY_MASS_LOSS)
	var rule := "active"
	if physical <= IDLE_WEEK_UNITS and float(w.study) <= 0.0:
		idle_weeks += 1
	else:
		idle_weeks = 0
	if idle_weeks >= IDLE_WEEKS_BEFORE_DECAY:
		# long inactivity: ease back toward the neutral midpoint instead of drifting to an extreme
		rule = "decay"
		d_mass = (0.5 - mass) * DECAY_TOWARD_NEUTRAL
		d_muscle = (0.5 - muscle) * DECAY_TOWARD_NEUTRAL
	elif physical < LOW_ACTIVITY_UNITS:
		rule = "sedentary"
		var lack := 1.0 - physical / LOW_ACTIVITY_UNITS
		d_mass += 0.045 * lack
		d_muscle -= 0.035 * lack
	mass = clampf(mass + d_mass, 0.0, 1.0)
	muscle = clampf(muscle + d_muscle, 0.0, 1.0)
	var d_smarts := minf(4.0 * float(w.study), 10.0) if float(w.study) > 0.0 else -1.0
	book_smarts = clampf(book_smarts + d_smarts, 0.0, 100.0)
	var summary := {"week": week_index, "log": w.duplicate(), "rule": rule, "mass": mass, "muscle": muscle,
		"d_mass": d_mass, "d_muscle": d_muscle, "book_smarts": book_smarts, "descriptor": get_body_descriptor()}
	history.push_back(summary)
	_reset_log()
	_apply_body()
	body_changed.emit(mass, muscle)
	book_smarts_changed.emit(book_smarts)
	week_evaluated.emit(week_index, summary)
	return summary


func _apply_body() -> void:
	var player = WorldState.player
	if player == null or not is_instance_valid(player):
		return
	var rig = player.get_node_or_null("Body")
	if rig and rig.get("model") and rig.model:
		rig.model.set_body(mass, muscle)


# ------------------------------------------------------------------ persistence (no save system yet; ready for one)
func to_dict() -> Dictionary:
	return {"mass": mass, "muscle": muscle, "book_smarts": book_smarts, "idle_weeks": idle_weeks,
		"week_log": week_log.duplicate(), "last_week_index": last_week_index}

func from_dict(d: Dictionary) -> void:
	mass = float(d.get("mass", 0.5))
	muscle = float(d.get("muscle", 0.5))
	book_smarts = float(d.get("book_smarts", 0.0))
	idle_weeks = int(d.get("idle_weeks", 0))
	if d.has("week_log"):
		week_log = d["week_log"]
	last_week_index = int(d.get("last_week_index", TimeManager.get_week_index()))
	_apply_body()
