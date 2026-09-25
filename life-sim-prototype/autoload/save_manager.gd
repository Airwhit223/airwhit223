extends Node
## Owns the three player-facing save slots.  Systems opt into persistence by
## exposing `to_dict`/`from_dict` or the older `to_save`/`from_save` pair.

signal slots_changed()
signal loaded(slot: int)

const SLOT_COUNT := 3
const SAVE_DIRECTORY := "user://life_sim_saves"
## InventoryManager loads before QuestManager/FarmingManager: older saves kept items in those two, and their
## from_dict merges them into the bag.
const SAVE_SYSTEMS := [
	"GameRules", "TimeManager", "PlayerStats", "TraitSystem", "Progression",
	"TownGrowth", "Hardships", "PowerSystem", "InventoryManager", "QuestManager", "Economy",
	"JobManager", "FarmingManager", "AdventureManager", "RelationshipManager", "PlayerFriendshipManager",
]

var active_slot := 0
var player_identity := ""
var _pending_data: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))

func slot_summary(slot: int) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {"slot": slot, "occupied": false, "title": "Empty journal", "detail": "Begin a new life here."}
	var world: Dictionary = data.get("systems", {}).get("GameRules", {})
	var clock: Dictionary = data.get("systems", {}).get("TimeManager", {})
	var mode := "Story World" if int(world.get("mode", 0)) == GameRules.Mode.ADVENTURE else "Sandbox World"
	return {"slot": slot, "occupied": true, "title": String(data.get("label", mode)), "detail": "%s  •  Day %d  •  %s" % [mode, int(clock.get("day_index", 0)) + 1, String(data.get("saved_at", "Saved"))]}

func save_active_slot(label := "") -> bool:
	return save_slot(active_slot, label)

func save_slot(slot: int, label := "") -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	var systems := {}
	for system_name in SAVE_SYSTEMS:
		var system := get_node_or_null("/root/" + system_name)
		if system == null:
			continue
		if system.has_method("to_save"):
			systems[system_name] = system.to_save()
		elif system.has_method("to_dict"):
			systems[system_name] = system.to_dict()
	var data := {"version": 1, "player_id": player_identity, "label": label if label != "" else GameRules.mode_name() + " World", "saved_at": Time.get_datetime_string_from_system(false, true), "systems": systems}
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save slot %d" % slot)
		return false
	file.store_string(JSON.stringify(data))
	active_slot = slot
	slots_changed.emit()
	return true

func start_new_run(slot: int, mode: int) -> void:
	active_slot = slot
	player_identity = "traveller_%d_%d" % [Time.get_unix_time_from_system(), randi()]
	_pending_data.clear()
	GameRules.start_new_game(mode)

func queue_load(slot: int) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	active_slot = slot
	player_identity = String(data.get("player_id", "traveller_%d_%d" % [Time.get_unix_time_from_system(), randi()]))
	_pending_data = data
	return true

## Main calls this after the world and its managers exist.
func apply_pending_load() -> void:
	if _pending_data.is_empty():
		return
	var systems: Dictionary = _pending_data.get("systems", {})
	for system_name in SAVE_SYSTEMS:
		if not systems.has(system_name):
			continue
		var system := get_node_or_null("/root/" + system_name)
		if system == null:
			continue
		var value: Dictionary = systems[system_name]
		if system.has_method("from_save"):
			system.from_save(value)
		elif system.has_method("from_dict"):
			system.from_dict(value)
	_pending_data.clear()
	loaded.emit(active_slot)

func _read(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT or not FileAccess.file_exists(_path(slot)):
		return {}
	var file := FileAccess.open(_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIRECTORY, slot]
