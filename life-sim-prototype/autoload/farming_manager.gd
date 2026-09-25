extends Node
## Crop catalog for the small farming loop. Plots own their growth state; seeds and produce are ordinary items in
## InventoryManager (the one item store), so harvests can be gifted, stored, sold or handed in for quests.

signal inventory_changed

const STARTER_SEEDS := 6

var _crops: Dictionary = {}

func _ready() -> void:
	_build_catalog()

func _inv() -> Node:
	return get_node("/root/InventoryManager")

func _build_catalog() -> void:
	var turnip := CropDefinition.new()
	_crops[turnip.id] = turnip

func get_crop(crop_id: String) -> CropDefinition:
	return _crops.get(crop_id) as CropDefinition

func get_seed_count(crop_id: String) -> int:
	var crop := get_crop(crop_id)
	return _inv().count(crop.seed_item_id) if crop else 0

func get_produce_count(crop_id: String) -> int:
	return _inv().count(crop_id)

func use_seed(crop_id: String) -> bool:
	var crop := get_crop(crop_id)
	if crop == null or not _inv().remove(crop.seed_item_id, 1):
		return false
	inventory_changed.emit()
	return true

func add_harvest(crop_id: String, amount: int) -> void:
	_inv().add(crop_id, amount, true)
	inventory_changed.emit()

func reset_for_tests() -> void:
	if _crops.is_empty():
		_build_catalog()
	_inv().set_count("turnip_seed", STARTER_SEEDS)
	_inv().set_count("turnip", 0)
	inventory_changed.emit()

## Farm items live in InventoryManager's save; nothing of its own to persist. An older save's farm inventory is
## merged into the bag so nothing harvested before the change is lost.
func to_dict() -> Dictionary:
	return {}

func from_dict(data: Dictionary) -> void:
	if _crops.is_empty():
		_build_catalog()
	var old: Dictionary = data.get("inventory", {})
	for item_id in old:
		if int(old[item_id]) > 0:
			_inv().add(String(item_id), int(old[item_id]), true)
	inventory_changed.emit()
