class_name PlayerPowerProfile
extends RefCounted
## Central data model for a character's power identity in the Rolling Tides Universe.
##
## CORE RULES:
## - BODY: Mutation (1 slot max)
## - SOUL: Magic (1 slot max)
## - WORLD: Gear (independent)
## - ANCESTRY: Race (independent)
## - UNIVERSAL: Physical capacity pool (Strength, Speed, etc. - independent)

signal power_state_changed()
signal affinity_changed(slot_type: String, new_affinity: String)
signal transformation_started(trans_id: String, axis: String)
signal transformation_ended(trans_id: String)
signal artificial_power_applied(effect_id: String, duration: float)
signal artificial_power_expired(effect_id: String)
signal power_tier_advanced(new_tier: int)

# --- 1. Race / Ancestry (Independent Axis) ---
var race_id: String = "human"
var race_mastery: float = 10.0 # 0.0 to 100.0

# --- 2. Hard Two-Affinity Rule (1 Mutation, 1 Magic) ---
var mutation_affinity: String = "" # Exactly 1 Mutation Affinity ID
var mutation_mastery: float = 0.0 # 0.0 to 100.0

var magic_affinity: String = "" # Exactly 1 Magic Discipline ID
var magic_mastery: float = 0.0 # 0.0 to 100.0

# --- 3. Universal Physical Abilities Pool (1.0 to 10.0) ---
var universal_mastery: Dictionary = {
	"strength": 1.0,
	"speed": 1.0,
	"resistance": 1.0,
	"mobility": 1.0,
	"flight": 0.0,          # Flight / Supernatural Mobility - starts dormant, awakens at 1.0 (see FlightController)
	"reflex": 1.0,
	"agility": 1.0,
	"senses": 1.0,
	"stamina": 1.0,
	"recovery": 1.0,
}

# --- 4. Adaptations (Tier II: Physical vs Soul) ---
var current_adaptation: String = "none" # "none", "physical", "soul"

# --- 5. Unlocks & Active Loadout ---
var unlocked_abilities: Array[String] = []
var active_loadout: Dictionary = {
	"primary": "",
	"secondary": "",
	"mobility": "",
	"defensive": "",
	"utility": "",
	"transformation": "",
	"gear_quick": ""
}

# --- 6. Active Transformations & Energy ---
## Set by an ability that is actively costing the body something (flight holds it while airborne). Suppresses
## passive recovery, so a power you are using cannot be funded by the same tick that is meant to refill you.
var exerting: bool = false
var energy: float = 100.0
var max_energy: float = 100.0
var active_transformation_axis: String = "" # "", "race", "mutation", "magic", "fusion"
var active_transformation_id: String = ""
var transformation_time_remaining: float = 0.0

# --- 7. Gear & Artificial Powers ---
var gear_powers: Array[String] = []
var active_artificial_powers: Array[Dictionary] = []

# ----------------- Two-Affinity Rule Enforcement -----------------
func set_mutation_affinity(new_mutation: String) -> void:
	if mutation_affinity == new_mutation:
		return
	mutation_affinity = new_mutation
	# Re-evaluating available abilities
	_refresh_unlocked_abilities()
	affinity_changed.emit("mutation", mutation_affinity)
	power_state_changed.emit()

func set_magic_affinity(new_magic: String) -> void:
	if magic_affinity == new_magic:
		return
	magic_affinity = new_magic
	_refresh_unlocked_abilities()
	affinity_changed.emit("magic", magic_affinity)
	power_state_changed.emit()

func set_race(new_race: String) -> void:
	race_id = new_race
	power_state_changed.emit()

func set_adaptation(new_adapt: String) -> void:
	current_adaptation = new_adapt
	power_state_changed.emit()

# ----------------- Mastery Manipulation & Growth -----------------
func add_universal_mastery(ability_key: String, amount: float) -> void:
	if universal_mastery.has(ability_key):
		universal_mastery[ability_key] = clampf(universal_mastery[ability_key] + amount, 1.0, 10.0)
		power_state_changed.emit()

func set_universal_mastery(ability_key: String, val: float) -> void:
	if universal_mastery.has(ability_key):
		universal_mastery[ability_key] = clampf(val, 1.0, 10.0)
		power_state_changed.emit()

func add_mutation_mastery(amount: float) -> void:
	mutation_mastery = clampf(mutation_mastery + amount, 0.0, 100.0)
	_refresh_unlocked_abilities()
	power_state_changed.emit()

func add_magic_mastery(amount: float) -> void:
	magic_mastery = clampf(magic_mastery + amount, 0.0, 100.0)
	_refresh_unlocked_abilities()
	power_state_changed.emit()

func add_race_mastery(amount: float) -> void:
	race_mastery = clampf(race_mastery + amount, 0.0, 100.0)
	_refresh_unlocked_abilities()
	power_state_changed.emit()

# ----------------- Power Tiers (Tier 0 to VI) -----------------
func get_power_tier() -> int:
	# Tier VI: Fusion available
	if can_fuse():
		return 6
	# Tier V: Mutation or Magic transformation available
	if is_mutation_transformation_unlocked() or is_magic_transformation_unlocked():
		return 5
	# Tier IV: Race transformation unlocked
	if is_race_transformation_unlocked():
		return 4
	# Tier III: Affinity manifestation
	if (mutation_mastery >= 25.0 and mutation_affinity != "") or (magic_mastery >= 25.0 and magic_affinity != ""):
		return 3
	# Tier II: Adaptation unlocked
	if current_adaptation != "none":
		return 2
	# Tier I: Awakened body
	for k in universal_mastery:
		if universal_mastery[k] > 2.0:
			return 1
	return 0

# ----------------- Synergies Calculation -----------------
## Returns effective stat multiplier including universal mastery, race modifiers,
## elemental synergies, active transformations, and artificial serums.
func get_effective_stat(stat_key: String) -> float:
	var base_val: float = universal_mastery.get(stat_key, 1.0)
	var multiplier := 1.0 + (base_val - 1.0) * 0.12 # e.g. level 10 = +108%

	# Racial modifier
	var races := PowerCatalog.get_races()
	if races.has(race_id):
		var r_data: Dictionary = races[race_id]
		var mods: Dictionary = r_data.get("stat_modifiers", {})
		if mods.has(stat_key):
			multiplier *= float(mods[stat_key])

	# Synergy bonus between universal stat and current element affinities
	var univ_data := PowerCatalog.get_universal_abilities()
	if univ_data.has(stat_key):
		var synergy_elements: Array = univ_data[stat_key].get("synergy_elements", [])
		var mut_elements := PowerCatalog.get_mutation_affinities()
		if mut_elements.has(mutation_affinity):
			var elem = mut_elements[mutation_affinity].get("element", "")
			if elem in synergy_elements:
				multiplier += (mutation_mastery / 100.0) * 0.25 # up to +25% synergy bonus
		var mag_elements := PowerCatalog.get_magic_disciplines()
		if mag_elements.has(magic_affinity):
			var elem = mag_elements[magic_affinity].get("element", "")
			if elem in synergy_elements:
				multiplier += (magic_mastery / 100.0) * 0.25

	# Active Transformation multiplier
	if is_transformed():
		var all_trans := PowerCatalog.get_transformations()
		if all_trans.has(active_transformation_id):
			var t_data: Dictionary = all_trans[active_transformation_id]
			var t_mods: Dictionary = t_data.get("stat_multipliers", {})
			if t_mods.has(stat_key):
				multiplier *= float(t_mods[stat_key])

	# Artificial Power buffs
	for art in active_artificial_powers:
		var art_mods: Dictionary = art.get("stat_modifiers", {})
		if art_mods.has(stat_key):
			multiplier *= float(art_mods[stat_key])

	return multiplier

# ----------------- Transformation System (3 Axes & Fusions) -----------------
func is_race_transformation_unlocked() -> bool:
	var races := PowerCatalog.get_races()
	if not races.has(race_id):
		return false
	var req: float = races[race_id].get("required_race_mastery_for_transform", 60.0)
	return race_mastery >= req

func is_mutation_transformation_unlocked() -> bool:
	return mutation_affinity != "" and mutation_mastery >= 75.0

func is_magic_transformation_unlocked() -> bool:
	return magic_affinity != "" and magic_mastery >= 75.0

func can_fuse() -> bool:
	# Tier VI Fusion requires high Race Mastery (>= 50) and high Mutation/Magic (>= 75)
	if race_mastery < 50.0:
		return false
	if race_id == "wolf_beastfolk" and mutation_affinity == "lightning" and mutation_mastery >= 75.0:
		return true
	if race_id == "dragon_kin" and mutation_affinity == "flame" and mutation_mastery >= 75.0:
		return true
	return false

func is_transformed() -> bool:
	return active_transformation_axis != "" and transformation_time_remaining > 0.0

func get_transformation_id_for_axis(axis: String) -> String:
	match axis:
		"race":
			var races := PowerCatalog.get_races()
			return races.get(race_id, {}).get("race_transformation_id", "")
		"mutation":
			var muts := PowerCatalog.get_mutation_affinities()
			return muts.get(mutation_affinity, {}).get("transformation_id", "")
		"magic":
			var mags := PowerCatalog.get_magic_disciplines()
			return mags.get(magic_affinity, {}).get("transformation_id", "")
		"fusion":
			if race_id == "wolf_beastfolk" and mutation_affinity == "lightning":
				return "lightning_beast"
			if race_id == "dragon_kin" and mutation_affinity == "flame":
				return "inferno_dragon"
	return ""

func can_activate_transformation(axis: String) -> bool:
	if is_transformed():
		return false
	if energy < 20.0:
		return false
	match axis:
		"race":
			return is_race_transformation_unlocked()
		"mutation":
			return is_mutation_transformation_unlocked()
		"magic":
			return is_magic_transformation_unlocked()
		"fusion":
			return can_fuse()
	return false

func activate_transformation(axis: String) -> bool:
	if not can_activate_transformation(axis):
		return false

	var trans_id := get_transformation_id_for_axis(axis)
	if trans_id == "":
		return false

	var all_trans := PowerCatalog.get_transformations()
	if not all_trans.has(trans_id):
		return false

	var t_data: Dictionary = all_trans[trans_id]
	active_transformation_axis = axis
	active_transformation_id = trans_id
	transformation_time_remaining = float(t_data.get("base_duration", 25.0))
	transformation_started.emit(trans_id, axis)
	power_state_changed.emit()
	return true

func deactivate_transformation() -> void:
	if not is_transformed():
		return
	var old_id := active_transformation_id
	active_transformation_axis = ""
	active_transformation_id = ""
	transformation_time_remaining = 0.0
	transformation_ended.emit(old_id)
	power_state_changed.emit()

func update_runtime(delta: float) -> void:
	# Tick active transformation
	if is_transformed():
		var all_trans := PowerCatalog.get_transformations()
		var drain_rate: float = 8.0
		if all_trans.has(active_transformation_id):
			drain_rate = float(all_trans[active_transformation_id].get("energy_drain_per_sec", 8.0))

		energy = maxf(0.0, energy - drain_rate * delta)
		transformation_time_remaining -= delta
		if transformation_time_remaining <= 0.0 or energy <= 0.0:
			deactivate_transformation()

	# Passive energy recovery when not transformed AND not exerting. Flight sets `exerting` while it is holding
	# the character up: without this the +6/s trickle paid most of flight's cost and staying airborne was nearly
	# free, which is not what using a power should feel like.
	elif energy < max_energy and not exerting:
		var rec_stat := get_effective_stat("recovery")
		energy = minf(max_energy, energy + delta * 6.0 * rec_stat)

	# Tick active artificial powers
	var expired_indices: Array[int] = []
	for i in range(active_artificial_powers.size()):
		var art: Dictionary = active_artificial_powers[i]
		var rem: float = float(art.get("time_remaining", 0.0)) - delta
		art["time_remaining"] = rem
		if rem <= 0.0:
			expired_indices.append(i)

	for i in range(expired_indices.size() - 1, -1, -1):
		var idx: int = expired_indices[i]
		var removed_id: String = String(active_artificial_powers[idx].get("id", ""))
		active_artificial_powers.remove_at(idx)
		artificial_power_expired.emit(removed_id)
		power_state_changed.emit()

# ----------------- Artificial Powers -----------------
func apply_artificial_power(effect_id: String) -> bool:
	var catalog := PowerCatalog.get_artificial_powers()
	if not catalog.has(effect_id):
		return false
	var effect_data: Dictionary = catalog[effect_id].duplicate(true)
	effect_data["time_remaining"] = float(effect_data.get("total_duration", 30.0))

	# Replace existing if already applied
	for i in range(active_artificial_powers.size()):
		if active_artificial_powers[i].get("id") == effect_id:
			active_artificial_powers[i] = effect_data
			artificial_power_applied.emit(effect_id, effect_data["time_remaining"])
			power_state_changed.emit()
			return true

	active_artificial_powers.append(effect_data)
	artificial_power_applied.emit(effect_id, effect_data["time_remaining"])
	power_state_changed.emit()
	return true

# ----------------- Internal Helpers -----------------
func _refresh_unlocked_abilities() -> void:
	unlocked_abilities.clear()
	# Mutation unlocks
	var mut_cat := PowerCatalog.get_mutation_affinities()
	if mut_cat.has(mutation_affinity):
		var m_data: Dictionary = mut_cat[mutation_affinity]
		unlocked_abilities.append_array(m_data.get("ability_ids_early", []))
		if mutation_mastery >= 25.0:
			unlocked_abilities.append_array(m_data.get("ability_ids_developed", []))
		if mutation_mastery >= 50.0:
			unlocked_abilities.append_array(m_data.get("ability_ids_advanced", []))
		if mutation_mastery >= 75.0:
			unlocked_abilities.append_array(m_data.get("ability_ids_mastered", []))

	# Magic unlocks
	var mag_cat := PowerCatalog.get_magic_disciplines()
	if mag_cat.has(magic_affinity):
		var s_data: Dictionary = mag_cat[magic_affinity]
		unlocked_abilities.append_array(s_data.get("ability_ids_early", []))
		if magic_mastery >= 25.0:
			unlocked_abilities.append_array(s_data.get("ability_ids_developed", []))
		if magic_mastery >= 50.0:
			unlocked_abilities.append_array(s_data.get("ability_ids_advanced", []))
		if magic_mastery >= 75.0:
			unlocked_abilities.append_array(s_data.get("ability_ids_mastered", []))

# ----------------- Save / Load Persistence -----------------
func to_dict() -> Dictionary:
	return {
		"race_id": race_id,
		"race_mastery": race_mastery,
		"mutation_affinity": mutation_affinity,
		"mutation_mastery": mutation_mastery,
		"magic_affinity": magic_affinity,
		"magic_mastery": magic_mastery,
		"universal_mastery": universal_mastery.duplicate(true),
		"current_adaptation": current_adaptation,
		"unlocked_abilities": unlocked_abilities.duplicate(),
		"active_loadout": active_loadout.duplicate(true),
		"energy": energy,
		"max_energy": max_energy,
		"active_transformation_axis": active_transformation_axis,
		"active_transformation_id": active_transformation_id,
		"transformation_time_remaining": transformation_time_remaining,
		"active_artificial_powers": active_artificial_powers.duplicate(true),
		"gear_powers": gear_powers.duplicate()
	}

func from_dict(data: Dictionary) -> void:
	race_id = String(data.get("race_id", "human"))
	race_mastery = float(data.get("race_mastery", 10.0))
	mutation_affinity = String(data.get("mutation_affinity", ""))
	mutation_mastery = float(data.get("mutation_mastery", 0.0))
	magic_affinity = String(data.get("magic_affinity", ""))
	magic_mastery = float(data.get("magic_mastery", 0.0))
	if data.has("universal_mastery"):
		var u_dict: Dictionary = data["universal_mastery"]
		for k in u_dict:
			universal_mastery[k] = float(u_dict[k])
	current_adaptation = String(data.get("current_adaptation", "none"))
	var unl: Array = data.get("unlocked_abilities", [])
	unlocked_abilities.assign(unl)
	if data.has("active_loadout"):
		var l_dict: Dictionary = data["active_loadout"]
		for k in l_dict:
			active_loadout[k] = String(l_dict[k])
	energy = float(data.get("energy", 100.0))
	max_energy = float(data.get("max_energy", 100.0))
	active_transformation_axis = String(data.get("active_transformation_axis", ""))
	active_transformation_id = String(data.get("active_transformation_id", ""))
	transformation_time_remaining = float(data.get("transformation_time_remaining", 0.0))
	var arts: Array = data.get("active_artificial_powers", [])
	active_artificial_powers.assign(arts)
	var g: Array = data.get("gear_powers", [])
	gear_powers.assign(g)
	_refresh_unlocked_abilities()
	power_state_changed.emit()

func reset_to_defaults() -> void:
	race_id = "human"
	race_mastery = 10.0
	mutation_affinity = ""
	mutation_mastery = 0.0
	magic_affinity = ""
	magic_mastery = 0.0
	for k in universal_mastery:
		universal_mastery[k] = 1.0
	current_adaptation = "none"
	unlocked_abilities.clear()
	for k in active_loadout:
		active_loadout[k] = ""
	energy = 100.0
	max_energy = 100.0
	active_transformation_axis = ""
	active_transformation_id = ""
	transformation_time_remaining = 0.0
	active_artificial_powers.clear()
	gear_powers.clear()
	power_state_changed.emit()
