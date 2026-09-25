extends Node
## Player levelling.
##
## Levels 1-60 are the designed range: that is where trait slots, power unlocks and story-relevant milestones are
## tuned, so a player who reaches 60 has seen the whole progression. Levelling does not stop there — it simply stops
## handing out content. Past 60 each level grants one small buff that shrinks as you go (a long tail for players who
## keep playing), never a new unlock.
##
## The two power trait slots open at levels 15 and 25, but reaching the level only makes the unlock QUEST available.
## Nothing pops up and nothing is granted automatically: the player does the small quest, and finishing it opens the
## slot (see TraitSystem.unlock_power_slot). That matches how paths and powers unlock elsewhere.

signal leveled_up(level: int)
signal unlock_quest_available(quest_id: StringName, level: int)
signal unlock_quest_completed(quest_id: StringName, slot: int)

## Where authored content stops. Levelling continues past this.
const CONTENT_CAP := 60
## XP for the first level-up; each level costs a little more.
const BASE_XP := 120.0
const CURVE := 1.115
## Past the cap: the first extra level is worth this much, and each one after is worth 6% less.
const BEYOND_STEP := 0.004
const BEYOND_DECAY := 0.94

## The unlock quests. They become AVAILABLE at these levels; completing them opens a power trait slot.
const UNLOCK_QUESTS := {
	&"quest_first_power": {"level": 15, "slot": 0,
		"note": "PLACEHOLDER — the small quest that opens the first power trait slot."},
	&"quest_second_power": {"level": 25, "slot": 1,
		"note": "PLACEHOLDER — the small quest that opens the second power trait slot."},
}

## XP awarded by things the game already fires. Deliberately small: living is the main source.
const XP_EVENTS := {
	"crop_harvested": 8.0,
	"enemy_defeated": 25.0,
	"adventure_reward_found": 60.0,
	"basketball_scored": 4.0,
	"guitar_minigame_completed": 20.0,
	"npc_arrived_for_invite": 6.0,
	"community_event_ended": 15.0,
}

var level := 1
var xp := 0.0                       ## xp earned toward the next level
var total_xp := 0.0

var _available: Array[StringName] = []
var _completed: Array[StringName] = []

func _ready() -> void:
	EventBus.event_fired.connect(_on_event_fired)

func _on_event_fired(event_name: String, _data: Dictionary) -> void:
	if XP_EVENTS.has(event_name):
		add_xp(float(XP_EVENTS[event_name]), event_name)

# ------------------------------------------------------------------ levelling
## XP needed to go from `from_level` to the next one.
func xp_for_next(from_level: int) -> float:
	return BASE_XP * pow(CURVE, maxf(0.0, from_level - 1))

func add_xp(amount: float, source := "") -> void:
	if amount <= 0.0:
		return
	xp += amount
	total_xp += amount
	while xp >= xp_for_next(level):
		xp -= xp_for_next(level)
		level += 1
		leveled_up.emit(level)
		_offer_unlocks()

func xp_to_next() -> float:
	return maxf(0.0, xp_for_next(level) - xp)

## True once the player is past the designed content range — everything authored has been seen.
func is_beyond_content() -> bool:
	return level > CONTENT_CAP

## The long tail: a single small bonus that grows with each level past the cap and shrinks as it goes, so level 200
## is meaningfully ahead of 61 without ever doubling anyone's power.
func beyond_bonus() -> float:
	var total := 0.0
	var step := BEYOND_STEP
	for i in range(CONTENT_CAP, level):
		total += step
		step *= BEYOND_DECAY
	return total

# ------------------------------------------------------------------ unlock quests
func _offer_unlocks() -> void:
	for quest_id in UNLOCK_QUESTS:
		var quest: Dictionary = UNLOCK_QUESTS[quest_id]
		if level >= int(quest["level"]) and not _available.has(quest_id) and not _completed.has(quest_id):
			_available.append(quest_id)
			unlock_quest_available.emit(quest_id, int(quest["level"]))

## Quests the player could take right now. Nothing has been granted by reaching the level.
func available_unlock_quests() -> Array[StringName]:
	return _available.duplicate()

func is_unlock_quest_available(quest_id: StringName) -> bool:
	return _available.has(quest_id)

## Finishing the quest is what opens the slot.
func complete_unlock_quest(quest_id: StringName) -> bool:
	if not _available.has(quest_id) or _completed.has(quest_id):
		return false
	var quest: Dictionary = UNLOCK_QUESTS[quest_id]
	_available.erase(quest_id)
	_completed.append(quest_id)
	var slot := int(quest["slot"])
	TraitSystem.unlock_power_slot(slot)
	unlock_quest_completed.emit(quest_id, slot)
	EventBus.fire("power_trait_slot_opened", {"quest": String(quest_id), "slot": slot})
	return true

func completed_unlock_quests() -> Array[StringName]:
	return _completed.duplicate()

# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "total_xp": total_xp,
		"available": _available.duplicate(), "completed": _completed.duplicate()}

func from_dict(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = float(data.get("xp", 0.0))
	total_xp = float(data.get("total_xp", 0.0))
	_available.assign(data.get("available", []))
	_completed.assign(data.get("completed", []))

func reset() -> void:
	level = 1
	xp = 0.0
	total_xp = 0.0
	_available.clear()
	_completed.clear()
