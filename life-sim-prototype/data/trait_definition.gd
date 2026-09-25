class_name TraitDefinition
extends Resource
## One trait. Traits are never listed in a UI: they exist to bend gameplay and dialogue quietly, so everything here
## is authoring data, not player-facing text.
##
## `effects` is a flat dictionary of effect keys to numbers, e.g.
##     {"relationship.gain_rate": 0.15, "work.pay": -0.05}
## Systems ask TraitSystem for a key and get the resolved total; they never need to know which traits are active.

enum Slot {
	START,        ## chosen at character creation (3 of these)
	POWER,        ## unlocked later through a quest at a level milestone (2 of these)
	ACHIEVEMENT,  ## earned slots, filled by whatever the achievement grants
}

@export var id: StringName = &""
@export var slot: Slot = Slot.START
## Short authoring note — why this trait exists. Never shown to the player.
@export_multiline var note: String = ""
## Tags let dialogue and events ask "is this person bold?" without naming traits.
@export var tags: Array[StringName] = []
@export var effects: Dictionary = {}

static func make(id_: StringName, slot_: Slot, tags_: Array, effects_: Dictionary, note_ := "") -> TraitDefinition:
	var t := TraitDefinition.new()
	t.id = id_
	t.slot = slot_
	t.note = note_
	t.tags.assign(tags_)
	t.effects = effects_
	return t
