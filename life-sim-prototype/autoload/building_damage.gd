extends Node
## Structural damage to the world's buildings, and the repairs they need afterwards.
##
## Flying through someone's roof breaks it. A broken building stays broken - nothing here heals on its own - so
## the damage is a debt against the world that somebody has to work off (see repair()). There is no currency in
## this project, so repair is modelled as WORK: hours or materials put in, not money paid.
##
## Buildings are identified by a stable string id (their node name in the world), so the record survives the
## building being rebuilt, re-synced or swapped for a kit piece.

signal building_damaged(building_id: String, total_damage: float, display_name: String)
signal building_repaired(building_id: String, remaining_damage: float)
signal building_destroyed(building_id: String)      # damage hit the cap; needs a full rebuild

const MAX_DAMAGE := 100.0
const ROOF_STRIKE_DAMAGE := 22.0      # one flight through a roof
## Work needed to clear one point of damage. Repairing a roof strike is most of a working day.
const HOURS_PER_POINT := 0.25

var _damage: Dictionary = {}          # building_id -> float
var _names: Dictionary = {}           # building_id -> display name

func report_damage(building_id: String, amount: float, display_name: String = "") -> float:
	if building_id.is_empty():
		return 0.0
	var total: float = minf(MAX_DAMAGE, damage_of(building_id) + amount)
	_damage[building_id] = total
	if not display_name.is_empty():
		_names[building_id] = display_name
	building_damaged.emit(building_id, total, name_of(building_id))
	EventBus.fire("building_damaged", {"building": building_id, "damage": total, "name": name_of(building_id)})
	if total >= MAX_DAMAGE:
		building_destroyed.emit(building_id)
		EventBus.fire("building_destroyed", {"building": building_id, "name": name_of(building_id)})
	return total

func repair(building_id: String, amount: float) -> float:
	if not _damage.has(building_id):
		return 0.0
	var remaining: float = maxf(0.0, _damage[building_id] - amount)
	if remaining <= 0.0:
		_damage.erase(building_id)
	else:
		_damage[building_id] = remaining
	building_repaired.emit(building_id, remaining)
	EventBus.fire("building_repaired", {"building": building_id, "remaining": remaining})
	return remaining

func damage_of(building_id: String) -> float:
	return float(_damage.get(building_id, 0.0))

func is_damaged(building_id: String) -> bool:
	return damage_of(building_id) > 0.0

func name_of(building_id: String) -> String:
	return String(_names.get(building_id, building_id))

## Work left on a building, in hours - what a repair job would cost somebody.
func repair_hours(building_id: String) -> float:
	return damage_of(building_id) * HOURS_PER_POINT

func damaged_buildings() -> Array:
	var out: Array = []
	for id in _damage:
		out.append({"id": id, "name": name_of(id), "damage": _damage[id], "hours": repair_hours(id)})
	out.sort_custom(func(a, b): return a["damage"] > b["damage"])
	return out

func to_dict() -> Dictionary:
	return {"damage": _damage.duplicate(), "names": _names.duplicate()}

func from_dict(data: Dictionary) -> void:
	_damage = (data.get("damage", {}) as Dictionary).duplicate()
	_names = (data.get("names", {}) as Dictionary).duplicate()

func reset() -> void:
	_damage.clear()
	_names.clear()
