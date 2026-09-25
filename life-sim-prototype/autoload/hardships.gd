extends Node
## People in town who are struggling — and the few whose struggle has a Dream Realm cause.
##
## Design rules (from the milestone spec):
##   * most hardships are ordinary: debt, a bad job, grief, a sick parent, no sleep because of the new baby
##   * a MINORITY have a dream-remnant cause, and they are NOT flagged in advance: a remnant hardship shows the same
##     surface symptom as an ordinary one ("hasn't been sleeping"), so the player only finds out by looking into it
##   * looking into it means clues — talking to them, to people who know them, visiting where it happens. Enough clues
##     reveal the real cause, whichever it is
##   * resolving a remnant storyline makes that person recruitable as a companion later
##
## Keeping it a minority is what stops struggle from becoming a genre gimmick: the supernatural ones have to feel
## earned. `REMNANT_SHARE` caps it, and assignment is seeded so a town's stories are stable.

signal hardship_noticed(npc_id: String, symptom: String)
signal clue_found(npc_id: String, clue: String, found: int, needed: int)
signal cause_revealed(npc_id: String, cause: StringName, remnant: bool)
signal hardship_resolved(npc_id: String, remnant: bool)
signal companion_available(npc_id: String)

## At most this share of struggling people have a supernatural cause.
const REMNANT_SHARE := 0.25
## Clues needed before the real cause is clear.
const CLUES_NEEDED := 3

## Surface symptoms — what anyone would notice. Each lists ordinary causes and one remnant cause that looks the same
## from the outside. PLACEHOLDER content: the real storylines are authored later; the structure is what is built.
const SYMPTOMS := {
	"no_sleep": {
		"surface": "hasn't been sleeping",
		"mundane": [&"new_baby", &"night_shifts", &"worry_over_money"],
		"remnant": &"dream_bleed",
		"clues": ["tired eyes, jumpy", "talks about the same hallway every night",
			"the clocks in their house all stopped at the same minute"],
	},
	"withdrawn": {
		"surface": "stopped coming out",
		"mundane": [&"grief", &"lost_job", &"falling_out"],
		"remnant": &"hollow_echo",
		"clues": ["cancels on everyone", "keeps saying people's names wrong — old names",
			"their shadow is a beat late when they move"],
	},
	"money_trouble": {
		"surface": "is struggling for money",
		"mundane": [&"debt", &"medical_bills", &"bad_harvest"],
		"remnant": &"remnant_hunger",
		"clues": ["selling things they love", "buys the same odd trinkets over and over",
			"the trinkets are all from places that don't exist on any map"],
	},
	"memory_gaps": {
		"surface": "keeps forgetting things",
		"mundane": [&"overwork", &"getting_older", &"medication"],
		"remnant": &"memory_thief",
		"clues": ["misses appointments", "remembers things that didn't happen, very clearly",
			"the missing memories are all about one person nobody else remembers"],
	},
}

var _hardships: Dictionary = {}        # npc_id -> {symptom, cause, remnant, clues[], revealed, resolved}
var _companions: Array[String] = []
var _rng := RandomNumberGenerator.new()

## Give hardships to some of the given NPC ids. `share` is how many are struggling at all; within that, at most
## REMNANT_SHARE get a remnant cause — the rest, and anyone past the cap, get an ordinary one.
func assign(npc_ids: Array, seed_value: int = 424242, share := 0.5) -> void:
	_rng.seed = seed_value
	var struggling: Array = []
	for id in npc_ids:
		if _rng.randf() < share:
			struggling.append(String(id))
	var remnant_cap := int(floor(struggling.size() * REMNANT_SHARE))
	if struggling.size() >= 2:
		remnant_cap = maxi(remnant_cap, 1)      # a town with struggles has at least one worth looking into
	var remnant_given := 0
	for npc_id in struggling:
		var symptom: String = SYMPTOMS.keys()[_rng.randi() % SYMPTOMS.size()]
		var data: Dictionary = SYMPTOMS[symptom]
		var is_remnant := remnant_given < remnant_cap and _rng.randf() < 0.5
		if is_remnant:
			remnant_given += 1
		var mundane: Array = data["mundane"]
		var cause: StringName = data["remnant"] if is_remnant else mundane[_rng.randi() % mundane.size()]
		_hardships[npc_id] = {"symptom": symptom, "cause": cause, "remnant": is_remnant, "clues": [],
			"revealed": false, "resolved": false}
	# guarantee the minority exists even when the coin flips were unkind
	if remnant_given < remnant_cap:
		for npc_id in struggling:
			if remnant_given >= remnant_cap:
				break
			var entry: Dictionary = _hardships[npc_id]
			if not entry["remnant"]:
				entry["remnant"] = true
				entry["cause"] = SYMPTOMS[entry["symptom"]]["remnant"]
				remnant_given += 1

func has_hardship(npc_id: String) -> bool:
	return _hardships.has(npc_id) and not _hardships[npc_id]["resolved"]

## What the player can see without investigating. Identical wording whatever the cause — nothing is flagged.
func surface(npc_id: String) -> String:
	if not _hardships.has(npc_id):
		return ""
	return SYMPTOMS[_hardships[npc_id]["symptom"]]["surface"]

func notice(npc_id: String) -> void:
	if _hardships.has(npc_id):
		hardship_noticed.emit(npc_id, surface(npc_id))

## Looking into it: each call turns up the next clue. The last clue is the one that tells ordinary from remnant — the
## earlier ones read the same either way.
func investigate(npc_id: String) -> String:
	if not has_hardship(npc_id):
		return ""
	var entry: Dictionary = _hardships[npc_id]
	var found: Array = entry["clues"]
	if found.size() >= CLUES_NEEDED:
		return ""
	var clues: Array = SYMPTOMS[entry["symptom"]]["clues"]
	var index := found.size()
	var clue: String = clues[mini(index, clues.size() - 1)]
	if index == CLUES_NEEDED - 1 and not entry["remnant"]:
		clue = "it's just %s — hard, but ordinary" % String(entry["cause"]).replace("_", " ")
	found.append(clue)
	clue_found.emit(npc_id, clue, found.size(), CLUES_NEEDED)
	if found.size() >= CLUES_NEEDED and not entry["revealed"]:
		entry["revealed"] = true
		cause_revealed.emit(npc_id, entry["cause"], entry["remnant"])
	return clue

func is_revealed(npc_id: String) -> bool:
	return _hardships.has(npc_id) and _hardships[npc_id]["revealed"]

## Only a revealed cause can be dealt with. Resolving a remnant storyline is what earns the companion.
func resolve(npc_id: String) -> bool:
	if not has_hardship(npc_id) or not is_revealed(npc_id):
		return false
	var entry: Dictionary = _hardships[npc_id]
	entry["resolved"] = true
	hardship_resolved.emit(npc_id, entry["remnant"])
	EventBus.fire("hardship_resolved", {"npc_id": npc_id, "remnant": entry["remnant"]})
	if entry["remnant"] and not _companions.has(npc_id):
		_companions.append(npc_id)
		companion_available.emit(npc_id)
		EventBus.fire("companion_available", {"npc_id": npc_id})
	return true

## Whether the cause is supernatural — for systems that need to know AFTER the reveal. Before it, returns null so
## nothing can accidentally leak the answer into dialogue.
func is_remnant(npc_id: String):
	if not is_revealed(npc_id):
		return null
	return _hardships[npc_id]["remnant"]

func recruitable_companions() -> Array[String]:
	return _companions.duplicate()

func struggling() -> Array:
	var out: Array = []
	for npc_id in _hardships:
		if not _hardships[npc_id]["resolved"]:
			out.append(npc_id)
	return out

## Counts for balance checks (not player-facing).
func remnant_count() -> int:
	var count := 0
	for npc_id in _hardships:
		if _hardships[npc_id]["remnant"]:
			count += 1
	return count

func to_dict() -> Dictionary:
	return {"hardships": _hardships.duplicate(true), "companions": _companions.duplicate()}

func from_dict(data: Dictionary) -> void:
	_hardships = (data.get("hardships", {}) as Dictionary).duplicate(true)
	_companions.assign(data.get("companions", []))

func reset() -> void:
	_hardships.clear()
	_companions.clear()
