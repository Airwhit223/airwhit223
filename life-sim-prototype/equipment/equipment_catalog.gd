class_name EquipmentCatalog
extends RefCounted
## A tiny test inventory of placeholder items — enough to prove every slot
## and outfit combination works, not a real item database. Add a new item
## by adding one entry here; nothing else needs to change.

static var _items: Dictionary = {}

static func get_item(id: String) -> EquipmentItem:
	if _items.is_empty():
		_build()
	return _items.get(id, null)

static func all_ids() -> Array:
	if _items.is_empty():
		_build()
	return _items.keys()

static func ids_for_slot(slot: EquipmentItem.Slot) -> Array:
	if _items.is_empty():
		_build()
	var result: Array = []
	for id in _items:
		if _items[id].slot == slot:
			result.append(id)
	return result

static func _build() -> void:
	var B := EquipmentItem.Shape.BOX
	var S := EquipmentItem.Shape.SPHERE
	var C := EquipmentItem.Shape.CYLINDER
	var Slot := EquipmentItem.Slot

	# Clothing wraps CharacterRig body parts (see character/character_rig.gd).
	var short_sleeve := ["torso", "upper_arm_l", "upper_arm_r"]
	var long_sleeve := ["torso", "upper_arm_l", "upper_arm_r", "lower_arm_l", "lower_arm_r"]
	var pants := ["hips", "upper_leg_l", "upper_leg_r", "lower_leg_l", "lower_leg_r"]
	var feet := ["foot_l", "foot_r"]

	# --- Tops (inflated more than bottoms, so a shirt reads as over the pants) --
	_add_clothing("white_tshirt", "White T-Shirt", Slot.TOP, Color(0.92, 0.92, 0.9), short_sleeve, 0.02)
	_add_clothing("black_tshirt", "Black T-Shirt", Slot.TOP, Color(0.1, 0.1, 0.12), short_sleeve, 0.02)
	_add_clothing("red_hoodie", "Red Hoodie", Slot.TOP, Color(0.7, 0.15, 0.15), long_sleeve, 0.034)
	_add_clothing("blue_hoodie", "Blue Hoodie", Slot.TOP, Color(0.15, 0.25, 0.65), long_sleeve, 0.034)
	_add_clothing("striped_shirt", "Striped Shirt", Slot.TOP, Color(0.12, 0.12, 0.14), short_sleeve, 0.022,
		"stripes", Color(0.92, 0.92, 0.9))

	# --- Bottoms --------------------------------------------------------
	_add_clothing("blue_jeans", "Blue Jeans", Slot.BOTTOM, Color(0.2, 0.3, 0.55), pants, 0.015)
	_add_clothing("black_pants", "Black Pants", Slot.BOTTOM, Color(0.12, 0.12, 0.14), pants, 0.013)
	_add_clothing("gray_sweatpants", "Gray Sweatpants", Slot.BOTTOM, Color(0.5, 0.5, 0.52), pants, 0.024)

	# --- Shoes ----------------------------------------------------------
	_add_clothing("white_sneakers", "White Sneakers", Slot.SHOES, Color(0.95, 0.95, 0.93), feet, 0.022)
	_add_clothing("black_sneakers", "Black Sneakers", Slot.SHOES, Color(0.08, 0.08, 0.08), feet, 0.022)
	_add_clothing("red_sneakers", "Red Sneakers", Slot.SHOES, Color(0.65, 0.1, 0.1), feet, 0.022)

	# --- Headwear (head radius is 0.17; hats must be at least as wide as the
	# head where their brim sits or skin bulges out below them) ------------
	_add("black_beanie", "Black Beanie", Slot.HEAD, Color(0.08, 0.08, 0.1), C, Vector3(0.31, 0.12, 0.31))
	_add("baseball_cap", "Baseball Cap", Slot.HEAD, Color(0.15, 0.35, 0.6), C, Vector3(0.33, 0.08, 0.33))

	# --- Accessory --------------------------------------------------------
	_add("simple_necklace", "Simple Necklace", Slot.ACCESSORY, Color(0.85, 0.7, 0.3), S, Vector3(0.06, 0.035, 0.06))

	# --- Back -------------------------------------------------------------
	_add("backpack", "Backpack", Slot.BACK, Color(0.45, 0.3, 0.15), B, Vector3(0.3, 0.36, 0.14), Vector3(0, 0, 0.09))

	# --- Hand / hip (weapon & tool test items) — held pointing forward -------
	_add("test_sword", "Test Sword", Slot.HAND_R, Color(0.6, 0.6, 0.65), B, Vector3(0.035, 0.55, 0.035),
		Vector3(0, -0.02, -0.25), Vector3(90, 0, 0))
	# `tool_type` marks a held tool: tools occupy the hands exclusively (see
	# CharacterEquipment.equip), so picking one puts the other away.
	_items["test_sword"].stats = {"tool_type": "weapon", "damage": 15, "pairs_with": "test_sword_off"}
	# The off-hand blade. `pairs_with` is what lets the two coexist: every other held tool still evicts whatever is
	# in the other hand, so only a matched pair can be dual-wielded (see CharacterEquipment.equip).
	_add("test_sword_off", "Test Sword (off hand)", Slot.HAND_L, Color(0.6, 0.6, 0.65), B, Vector3(0.035, 0.55, 0.035),
		Vector3(0, -0.02, -0.25), Vector3(90, 0, 0))
	_items["test_sword_off"].stats = {"tool_type": "weapon", "damage": 12, "pairs_with": "test_sword"}
	_add("test_tool", "Test Tool", Slot.HAND_L, Color(0.55, 0.4, 0.2), C, Vector3(0.05, 0.32, 0.05),
		Vector3(0, -0.02, -0.14), Vector3(90, 0, 0))
	_add("acoustic_guitar", "Acoustic Guitar", Slot.HAND_L, Color(0.72, 0.24, 0.08), B, Vector3(0.3, 0.65, 0.08),
		Vector3(0.18, -0.08, -0.22), Vector3(15, 0, -62))
	_items["acoustic_guitar"].stats = {"tool_type": "instrument", "activity": "guitar", "visual": "guitar"}
	_add("pouch", "Belt Pouch", Slot.HIP, Color(0.65, 0.55, 0.4), B, Vector3(0.07, 0.1, 0.13), Vector3(0.035, 0, 0))

	# --- Hair (reserved slot, one placeholder) ----------------------------
	# A dome slightly larger than the head, centered up and back (via the hair
	# socket) so it covers crown/back/sides but stops above the eyes.
	_add("brown_hair", "Brown Hair", Slot.HAIR, Color(0.35, 0.2, 0.12), S, Vector3(0.38, 0.26, 0.38))

static func _add_clothing(id: String, display_name: String, slot: EquipmentItem.Slot, color: Color,
		coverage: Array, inflate: float, pattern: String = "", accent: Color = Color.WHITE) -> void:
	var item := EquipmentItem.new()
	item.id = id
	item.display_name = display_name
	item.slot = slot
	item.color = color
	item.coverage.assign(coverage)
	item.inflate = inflate
	item.pattern = pattern
	item.accent_color = accent
	_items[id] = item

static func _add(id: String, display_name: String, slot: EquipmentItem.Slot, color: Color,
		shape: EquipmentItem.Shape, size: Vector3, local_offset: Vector3 = Vector3.ZERO,
		local_rotation: Vector3 = Vector3.ZERO) -> void:
	var item := EquipmentItem.new()
	item.id = id
	item.display_name = display_name
	item.slot = slot
	item.color = color
	item.shape = shape
	item.size = size
	item.local_offset = local_offset
	item.local_rotation_degrees = local_rotation
	_items[id] = item
