class_name TraitPairing
extends Resource
## A bespoke effect for two traits held together — the interesting half of the trait system.
##
## Resolution is tiered: a pairing REPLACES both traits' own contributions for every key it defines, and may add
## keys neither trait had. Any combination without a pairing simply adds the traits' solo effects together, so the
## system stays complete no matter which traits are authored.

@export var a: StringName = &""
@export var b: StringName = &""
@export_multiline var note: String = ""
@export var tags: Array[StringName] = []
@export var effects: Dictionary = {}

static func make(a_: StringName, b_: StringName, effects_: Dictionary, tags_ := [], note_ := "") -> TraitPairing:
	var p := TraitPairing.new()
	p.a = a_
	p.b = b_
	p.effects = effects_
	p.tags.assign(tags_)
	p.note = note_
	return p

func matches(active: Array) -> bool:
	return active.has(a) and active.has(b)

## Stable identity, so two pairings competing for the same effect key always resolve the same way.
func key() -> String:
	var pair := [String(a), String(b)]
	pair.sort()
	return "|".join(pair)
