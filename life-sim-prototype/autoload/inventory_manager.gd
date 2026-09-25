extends Node
## The player's portable items and all placed storage containers - the ONE item store. Farming (seeds, harvests),
## quests (quest items, rewards) and jobs (ranch eggs/produce) all read and write counts here, so anything you pick
## up can be gifted, stored in a chest, or handed in for a quest. Equipment keeps its own slots.

signal inventory_changed
## item_id, new count - for systems that only care about one item (quest objectives, HUD)
signal item_changed(item_id: String, count: int)
signal storage_changed(storage_id: String)

const PLAYER_SLOT_CAPACITY := 24
const RANK_CAPACITY := {1: 12, 2: 24, 3: 48, 4: 80}
const RANK_UPGRADE_COST := {2: 250, 3: 900, 4: 2500}
const STYLE_NAMES := ["Warm Oak", "Coastal Blue", "Forest Green", "Midnight"]
## Small, transparent starting values. NPC-specific loved/liked/disliked taste
## profiles can layer on top of this later without changing dialogue flow.
const GIFT_VALUES := {"turnip_seed": 0.5, "turnip": 1.5}

var items: Dictionary = {}
var storages: Dictionary = {}

func _ready() -> void:
	# Enough to exercise the first chest immediately; farming remains the source
	# of future seeds and harvests.
	if items.is_empty():
		items = {"turnip_seed": 6}

func count(item_id: String) -> int:
	return int(items.get(item_id, 0))

func display_name(item_id: String) -> String:
	if QuestCatalog.ITEMS.has(item_id) or ContractCatalog.ITEMS.has(item_id):
		return QuestCatalog.item_name(item_id)
	if RecipeCatalog.INGREDIENTS.has(item_id):
		return String(RecipeCatalog.INGREDIENTS[item_id])
	return item_id.replace("_", " ").capitalize()

## Quest items stay in your pockets: they can't be gifted away or sold.
func is_quest_item(item_id: String) -> bool:
	return QuestCatalog.ITEMS.has(item_id) or ContractCatalog.ITEMS.has(item_id)

func gift_value(item_id: String) -> float:
	return float(GIFT_VALUES.get(item_id, 1.0))

func used_slots() -> int:
	var total := 0
	for item_id in items:
		if int(items[item_id]) > 0:
			total += 1
	return total

func can_add(item_id: String) -> bool:
	return count(item_id) > 0 or used_slots() < PLAYER_SLOT_CAPACITY

## `force` ignores the slot limit - quest items and rewards must never be lost to a full bag.
func add(item_id: String, amount := 1, force := false) -> bool:
	if amount <= 0 or (not force and not can_add(item_id)):
		return false
	items[item_id] = count(item_id) + amount
	item_changed.emit(item_id, items[item_id])
	inventory_changed.emit()
	return true

func remove(item_id: String, amount := 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	items[item_id] = count(item_id) - amount
	if items[item_id] <= 0:
		items.erase(item_id)
	item_changed.emit(item_id, count(item_id))
	inventory_changed.emit()
	return true

## Set a count directly (tests, starter kits).
func set_count(item_id: String, amount: int) -> void:
	if amount <= 0:
		items.erase(item_id)
	else:
		items[item_id] = amount
	item_changed.emit(item_id, count(item_id))
	inventory_changed.emit()

func ensure_storage(storage_id: String, rank := 1, style_index := 0) -> void:
	if not storages.has(storage_id):
		storages[storage_id] = {"rank": clampi(rank, 1, 4), "style": posmod(style_index, STYLE_NAMES.size()), "items": {}}

func storage_data(storage_id: String) -> Dictionary:
	ensure_storage(storage_id)
	return storages[storage_id]

func storage_capacity(storage_id: String) -> int:
	return int(RANK_CAPACITY.get(int(storage_data(storage_id)["rank"]), 12))

func storage_used_slots(storage_id: String) -> int:
	var stored: Dictionary = storage_data(storage_id)["items"]
	var total := 0
	for item_id in stored:
		if int(stored[item_id]) > 0:
			total += 1
	return total

func storage_count(storage_id: String, item_id: String) -> int:
	return int((storage_data(storage_id)["items"] as Dictionary).get(item_id, 0))

func deposit(storage_id: String, item_id: String, amount := 1) -> bool:
	ensure_storage(storage_id)
	var stored: Dictionary = storage_data(storage_id)["items"]
	if count(item_id) < amount or amount <= 0:
		return false
	if not stored.has(item_id) and storage_used_slots(storage_id) >= storage_capacity(storage_id):
		return false
	remove(item_id, amount)
	stored[item_id] = int(stored.get(item_id, 0)) + amount
	storage_changed.emit(storage_id)
	return true

func withdraw(storage_id: String, item_id: String, amount := 1) -> bool:
	ensure_storage(storage_id)
	var stored: Dictionary = storage_data(storage_id)["items"]
	if int(stored.get(item_id, 0)) < amount or not add(item_id, amount):
		return false
	stored[item_id] = int(stored[item_id]) - amount
	if stored[item_id] <= 0:
		stored.erase(item_id)
	storage_changed.emit(storage_id)
	return true

## Price of the next rank, or 0 at max rank.
func upgrade_cost(storage_id: String) -> int:
	return int(RANK_UPGRADE_COST.get(int(storage_data(storage_id)["rank"]) + 1, 0))

## Paid through Economy - fails (false) at max rank or when you can't afford it.
func upgrade_storage(storage_id: String) -> bool:
	var data := storage_data(storage_id)
	var current := int(data["rank"])
	if current >= 4:
		return false
	var eco := get_node_or_null("/root/Economy")
	if eco and not eco.spend(upgrade_cost(storage_id), "Chest upgrade"):
		return false
	data["rank"] = current + 1
	storage_changed.emit(storage_id)
	return true

func cycle_storage_style(storage_id: String) -> int:
	var data := storage_data(storage_id)
	data["style"] = posmod(int(data["style"]) + 1, STYLE_NAMES.size())
	storage_changed.emit(storage_id)
	return int(data["style"])

func to_dict() -> Dictionary:
	return {"items": items.duplicate(true), "storages": storages.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	items = data.get("items", {}).duplicate(true)
	storages = data.get("storages", {}).duplicate(true)
	inventory_changed.emit()
