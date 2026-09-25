extends Node
## How the town grows.
##
## Growth works in two stages, and both matter:
##   1. a BUILDING is unlocked — by reaching a level or by a story milestone — and it goes up empty, with one or
##      more homes standing vacant
##   2. RESIDENTS move into vacancies over time; ordinary arrivals are generated (TownsfolkGenerator), but a
##      milestone can send a SPECIFIC kind of person — a mechanic who keeps to themselves, someone dream-touched —
##      by biasing the generator rather than hand-authoring an NPC
##
## So the town visibly fills in: you see a new place go up, and later you meet who moved in. Nothing arrives from
## nowhere, and a milestone can put exactly the right person in an existing empty house without a new building.

signal building_unlocked(building_id: StringName, data: Dictionary)
signal resident_arrived(definition: NPCDefinition, home_id: String)
signal vacancy_opened(home_id: String)

## Lots are laid out along a lane south of the existing houses; each entry says where and how many homes it holds.
const BUILDINGS := {
	&"rowhouse_east": {"name": "East Rowhouse", "position": Vector3(-8, 0, -34), "homes": 2,
		"requires": {"level": 5}},
	&"workshop_row": {"name": "Workshop Row", "position": Vector3(6, 0, -34), "homes": 1,
		"requires": {"milestone": &"gear_path_started"},
		"arrival": {"job": "mechanic", "traits": [&"tinkerer", &"careful"]}},
	&"quiet_house": {"name": "The Quiet House", "position": Vector3(20, 0, -34), "homes": 1,
		"requires": {"milestone": &"dream_boundary_seen"},
		"arrival": {"job": "teacher", "traits": [&"dreamer", &"careful"]}},
	&"north_terrace": {"name": "North Terrace", "position": Vector3(-22, 0, -34), "homes": 2,
		"requires": {"level": 20}},
}

## Milestones that send someone specific into whatever vacancy already exists — no new building needed.
const MILESTONE_ARRIVALS := {
	&"first_festival_hosted": {"job": "musician", "traits": [&"warm", &"restless"],
		"note": "PLACEHOLDER — a musician hears about the town and moves in."},
}

var _unlocked: Array[StringName] = []
var _milestones: Array[StringName] = []
var _vacancies: Array[String] = []
var _occupied: Dictionary = {}          # home id -> npc id
var _arrival_count := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 90210
	Progression.leveled_up.connect(_on_level_up)

func _on_level_up(_level: int) -> void:
	evaluate()

## Record a story beat. Anything waiting on it unlocks now.
func story_milestone(id: StringName) -> void:
	if _milestones.has(id):
		return
	_milestones.append(id)
	EventBus.fire("town_milestone", {"id": String(id)})
	evaluate()
	if MILESTONE_ARRIVALS.has(id):
		send_specific_resident(MILESTONE_ARRIVALS[id])

func has_milestone(id: StringName) -> bool:
	return _milestones.has(id)

## Apply every growth step whose condition is now met. Safe to call at any time; steps only ever apply once.
func evaluate() -> void:
	for building_id in BUILDINGS:
		if _unlocked.has(building_id):
			continue
		var data: Dictionary = BUILDINGS[building_id]
		var requires: Dictionary = data.get("requires", {})
		var met := true
		if requires.has("level") and Progression.level < int(requires["level"]):
			met = false
		if requires.has("milestone") and not _milestones.has(StringName(requires["milestone"])):
			met = false
		if met:
			_unlock_building(building_id, data)

func _unlock_building(building_id: StringName, data: Dictionary) -> void:
	_unlocked.append(building_id)
	for i in int(data.get("homes", 1)):
		var home_id := "home_%s_%d" % [building_id, i]
		_vacancies.append(home_id)
		vacancy_opened.emit(home_id)
	building_unlocked.emit(building_id, data)
	EventBus.fire("town_building_unlocked", {"id": String(building_id), "name": data.get("name", "")})
	# a building that came with someone in mind gets them straight away; otherwise it waits for an ordinary arrival
	if data.has("arrival"):
		send_specific_resident(data["arrival"])

func unlocked_buildings() -> Array[StringName]:
	return _unlocked.duplicate()

func vacancies() -> Array[String]:
	return _vacancies.duplicate()

# ------------------------------------------------------------------ arrivals
## An ordinary newcomer: generated like any other townsperson.
func send_resident() -> NPCDefinition:
	return _move_in({})

## Someone specific — the same generator, biased toward the job and traits the story asked for, so a milestone can
## produce "the mechanic who moved into the workshop" without hand-authoring an NPC.
func send_specific_resident(kind: Dictionary) -> NPCDefinition:
	return _move_in(kind)

func _move_in(kind: Dictionary) -> NPCDefinition:
	if _vacancies.is_empty():
		return null
	var home_id: String = _vacancies.pop_front()
	_arrival_count += 1
	var definition := TownsfolkGenerator.generate(_rng, 900 + _arrival_count, kind.get("traits", []))
	definition.id = "arrival_%02d" % _arrival_count
	definition.household_id = "household_%s" % definition.id
	definition.home_location_id = home_id
	if kind.has("job"):
		var job_id: String = kind["job"]
		var job: Dictionary = TownsfolkGenerator.JOBS.get(job_id, {})
		if not job.is_empty():
			definition.occupation = job_id
			definition.workplace_location_id = job["place"]
			definition.work_start_hour = job["start"]
			definition.work_end_hour = job["end"]
			definition.skills = (job["skills"] as Dictionary).duplicate()
	if kind.has("traits"):
		definition.traits.assign(kind["traits"])
		definition.register = TownsfolkGenerator.register_for(definition.traits)
	_occupied[home_id] = definition.id
	resident_arrived.emit(definition, home_id)
	EventBus.fire("town_resident_arrived", {"npc_id": definition.id, "home": home_id,
		"name": definition.full_name()})
	return definition

func residents() -> Dictionary:
	return _occupied.duplicate()

# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	return {"unlocked": _unlocked.duplicate(), "milestones": _milestones.duplicate(),
		"vacancies": _vacancies.duplicate(), "occupied": _occupied.duplicate(), "arrivals": _arrival_count}

func from_dict(data: Dictionary) -> void:
	_unlocked.assign(data.get("unlocked", []))
	_milestones.assign(data.get("milestones", []))
	_vacancies.assign(data.get("vacancies", []))
	_occupied = data.get("occupied", {})
	_arrival_count = int(data.get("arrivals", 0))

func reset() -> void:
	_unlocked.clear()
	_milestones.clear()
	_vacancies.clear()
	_occupied.clear()
	_arrival_count = 0
