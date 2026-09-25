extends Node
## The player's traits: what they are, which slots are open, and what the combination actually does.
##
## Design rules this follows:
##   * 3 traits are chosen at character creation, and 2 "power" slots stay locked until a quest unlocks them
##     (levels 15 and 25 — see the levelling milestone); achievements can grant further slots.
##   * Effects resolve in tiers: a bespoke pairing for two traits held together REPLACES both traits' own numbers
##     for the keys it defines; anything without a pairing simply adds. So every combination works, and the
##     interesting ones can be authored by hand.
##   * Traits are never listed in a UI. Systems ask `effect("some.key")` or `has_tag("bold")`; the player only ever
##     sees the consequences in play and in dialogue.
##
## Nothing here knows what any specific trait means — the catalogue holds that, and the real list lands later.

signal traits_changed()
signal slot_unlocked(slot: String)

const START_SLOTS := 3
const POWER_SLOTS := 2

var _traits: Dictionary = {}          # id -> TraitDefinition
var _pairings: Array[TraitPairing] = []
var _start: Array[StringName] = []
var _power: Array[StringName] = []     # parallel to _power_unlocked
var _power_unlocked: Array[bool] = [false, false]
var _achievement: Array[StringName] = []
var _achievement_slots: Array[StringName] = []   # achievement id per earned slot
var _cache: Dictionary = {}
var _cache_tags: Dictionary = {}

func _ready() -> void:
	load_catalog()

func load_catalog() -> void:
	for definition in TraitCatalog.all_traits():
		register(definition)
	for pairing in TraitCatalog.pairings():
		register_pairing(pairing)

func register(definition: TraitDefinition) -> void:
	_traits[definition.id] = definition
	_invalidate()

func register_pairing(pairing: TraitPairing) -> void:
	for existing in _pairings:
		if existing.key() == pairing.key():
			_pairings.erase(existing)
			break
	_pairings.append(pairing)
	_pairings.sort_custom(func(x, y): return x.key() < y.key())
	_invalidate()

func definition(id: StringName) -> TraitDefinition:
	return _traits.get(id, null)

func ids_for_slot(slot: TraitDefinition.Slot) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _traits:
		if (_traits[id] as TraitDefinition).slot == slot:
			out.append(id)
	out.sort()
	return out

# ------------------------------------------------------------------ slots
## Character creation: the three traits the player starts with. Extra entries are ignored.
func choose_starting(ids: Array) -> void:
	_start.clear()
	for id in ids:
		var key := StringName(id)
		if _traits.has(key) and _start.size() < START_SLOTS and not _start.has(key):
			_start.append(key)
	_invalidate()
	traits_changed.emit()

## Power slots stay closed until their unlock quest is finished (never an automatic menu pop-up).
func unlock_power_slot(index: int) -> bool:
	if index < 0 or index >= POWER_SLOTS or _power_unlocked[index]:
		return false
	_power_unlocked[index] = true
	slot_unlocked.emit("power_%d" % (index + 1))
	return true

func is_power_slot_unlocked(index: int) -> bool:
	return index >= 0 and index < POWER_SLOTS and _power_unlocked[index]

func set_power_trait(index: int, id: StringName) -> bool:
	if not is_power_slot_unlocked(index) or not _traits.has(id):
		return false
	while _power.size() < POWER_SLOTS:
		_power.append(&"")
	_power[index] = id
	_invalidate()
	traits_changed.emit()
	return true

## An achievement can hand over a slot, and optionally the trait that fills it.
func grant_achievement_slot(achievement_id: StringName, id: StringName = &"") -> void:
	if not _achievement_slots.has(achievement_id):
		_achievement_slots.append(achievement_id)
		slot_unlocked.emit("achievement:%s" % achievement_id)
	if id != &"" and _traits.has(id) and not _achievement.has(id):
		if _achievement.size() < _achievement_slots.size():
			_achievement.append(id)
			_invalidate()
			traits_changed.emit()

func slots_open() -> Dictionary:
	var power := 0
	for unlocked in _power_unlocked:
		if unlocked:
			power += 1
	return {"start": START_SLOTS, "power": power, "achievement": _achievement_slots.size()}

## Every trait currently in effect, in slot order.
func active() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(_start)
	for i in _power.size():
		if i < POWER_SLOTS and _power_unlocked[i] and _power[i] != &"":
			out.append(_power[i])
	out.append_array(_achievement)
	return out

# ------------------------------------------------------------------ resolution
## Bespoke pairings win over plain addition. If two pairings claim the same effect key, the one whose key sorts
## first wins — so the result never depends on the order traits happened to be chosen.
func _resolve() -> void:
	var ids := active()
	var totals: Dictionary = {}
	var claimed: Dictionary = {}     # effect key -> pairing key that owns it
	var tags: Dictionary = {}
	var paired: Dictionary = {}      # trait id -> array of effect keys it no longer contributes
	for pairing in _pairings:
		if not pairing.matches(ids):
			continue
		for key in pairing.effects:
			if claimed.has(key):
				continue
			claimed[key] = pairing.key()
			totals[key] = float(pairing.effects[key])
			for id in [pairing.a, pairing.b]:
				var list: Array = paired.get(id, [])
				list.append(key)
				paired[id] = list
		for tag in pairing.tags:
			tags[tag] = true
	for id in ids:
		var definition: TraitDefinition = _traits.get(id)
		if definition == null:
			continue
		var suppressed: Array = paired.get(id, [])
		for key in definition.effects:
			if suppressed.has(key):
				continue                      # a pairing speaks for this trait on this key
			totals[key] = float(totals.get(key, 0.0)) + float(definition.effects[key])
		for tag in definition.tags:
			tags[tag] = true
	_cache = totals
	_cache_tags = tags

func _invalidate() -> void:
	_cache.clear()
	_cache_tags.clear()

func _ensure() -> void:
	if _cache.is_empty() and _cache_tags.is_empty():
		_resolve()

## The resolved value of one effect key. `default` is what a character with no relevant traits gets.
func effect(key: String, default := 0.0) -> float:
	_ensure()
	return float(_cache.get(key, default))

## Convenience for the common "multiply something by 1 + bonus" case.
func multiplier(key: String) -> float:
	return 1.0 + effect(key, 0.0)

func has_tag(tag: StringName) -> bool:
	_ensure()
	return _cache_tags.has(tag)

## Tags are how dialogue and events react without ever naming a trait.
func tags() -> Array[StringName]:
	_ensure()
	var out: Array[StringName] = []
	for tag in _cache_tags:
		out.append(tag)
	out.sort()
	return out

func effects() -> Dictionary:
	_ensure()
	return _cache.duplicate()

# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	return {"start": _start.duplicate(), "power": _power.duplicate(), "power_unlocked": _power_unlocked.duplicate(),
		"achievement": _achievement.duplicate(), "achievement_slots": _achievement_slots.duplicate()}

func from_dict(data: Dictionary) -> void:
	_start.assign(data.get("start", []))
	_power.assign(data.get("power", []))
	var unlocked: Array = data.get("power_unlocked", [false, false])
	_power_unlocked = [bool(unlocked[0]) if unlocked.size() > 0 else false,
		bool(unlocked[1]) if unlocked.size() > 1 else false]
	_achievement.assign(data.get("achievement", []))
	_achievement_slots.assign(data.get("achievement_slots", []))
	_invalidate()
	traits_changed.emit()

func reset() -> void:
	_start.clear()
	_power.clear()
	_power_unlocked = [false, false]
	_achievement.clear()
	_achievement_slots.clear()
	_invalidate()
	traits_changed.emit()
