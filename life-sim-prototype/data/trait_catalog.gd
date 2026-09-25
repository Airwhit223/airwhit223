class_name TraitCatalog
extends RefCounted
## Where authored traits and pairings live. The real list is written later — what is here is a small placeholder set
## marked as such, so the framework can be exercised and tested before any content exists.
##
## Adding content means adding entries here (or calling TraitSystem.register from anywhere); no other system changes.

const PLACEHOLDER_NOTE := "PLACEHOLDER — replace when the real trait list arrives."

## Traits the player can start with (3 chosen at character creation).
static func starting_traits() -> Array[TraitDefinition]:
	var out: Array[TraitDefinition] = []
	out.append(TraitDefinition.make(&"warm", TraitDefinition.Slot.START, [&"kind", &"social"],
		{"relationship.gain_rate": 0.15, "trade.price": 0.03}, PLACEHOLDER_NOTE))
	out.append(TraitDefinition.make(&"restless", TraitDefinition.Slot.START, [&"bold", &"impatient"],
		{"move.speed": 0.08, "focus.study": -0.10}, PLACEHOLDER_NOTE))
	out.append(TraitDefinition.make(&"careful", TraitDefinition.Slot.START, [&"cautious"],
		{"focus.study": 0.12, "risk.injury": -0.20, "move.speed": -0.03}, PLACEHOLDER_NOTE))
	out.append(TraitDefinition.make(&"scrappy", TraitDefinition.Slot.START, [&"bold", &"physical"],
		{"combat.damage": 0.10, "relationship.gain_rate": -0.05}, PLACEHOLDER_NOTE))
	out.append(TraitDefinition.make(&"tinkerer", TraitDefinition.Slot.START, [&"curious", &"gear"],
		{"repair.quality": 0.20, "work.pay": 0.05}, PLACEHOLDER_NOTE))
	out.append(TraitDefinition.make(&"dreamer", TraitDefinition.Slot.START, [&"curious", &"dream"],
		{"dream.sensitivity": 0.25, "focus.study": -0.05}, PLACEHOLDER_NOTE))
	return out

## The two slots unlocked later through a quest at a level milestone (Milestone 5).
static func power_traits() -> Array[TraitDefinition]:
	var out: Array[TraitDefinition] = []
	out.append(TraitDefinition.make(&"unshaken", TraitDefinition.Slot.POWER, [&"resolve"],
		{"risk.injury": -0.25, "fear.resist": 0.4}, PLACEHOLDER_NOTE))
	out.append(TraitDefinition.make(&"quick_study", TraitDefinition.Slot.POWER, [&"curious"],
		{"focus.study": 0.25, "skill.gain_rate": 0.15}, PLACEHOLDER_NOTE))
	return out

## Filled by achievement rewards.
static func achievement_traits() -> Array[TraitDefinition]:
	var out: Array[TraitDefinition] = []
	out.append(TraitDefinition.make(&"known_face", TraitDefinition.Slot.ACHIEVEMENT, [&"social"],
		{"relationship.gain_rate": 0.10, "trade.price": 0.05}, PLACEHOLDER_NOTE))
	return out

## Bespoke effects for notable pairs. Anything not listed falls back to plain addition.
static func pairings() -> Array[TraitPairing]:
	var out: Array[TraitPairing] = []
	# warm + restless: the friend who is always dragging people somewhere — better at making friends than either
	# trait alone, and the impatience stops costing them study time when there is company
	out.append(TraitPairing.make(&"warm", &"restless",
		{"relationship.gain_rate": 0.35, "focus.study": 0.0, "event.invite_success": 0.2},
		[&"ringleader"], PLACEHOLDER_NOTE))
	# careful + tinkerer: methodical repair work, slower but much better
	out.append(TraitPairing.make(&"careful", &"tinkerer",
		{"repair.quality": 0.45, "work.pay": 0.12, "move.speed": -0.05},
		[&"craftsman"], PLACEHOLDER_NOTE))
	return out

static func all_traits() -> Array[TraitDefinition]:
	var out: Array[TraitDefinition] = []
	out.append_array(starting_traits())
	out.append_array(power_traits())
	out.append_array(achievement_traits())
	return out
