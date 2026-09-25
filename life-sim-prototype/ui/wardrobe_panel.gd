class_name WardrobePanel
extends Control
## Deliberately not pretty — a debug wardrobe to prove the equipment pipeline
## end-to-end. One row per slot; < / > cycle through that slot's catalog
## items (plus "None"), calling straight into CharacterEquipment so what you
## see immediately matches the character's actual equipped-item data.

const SLOT_ORDER := ["head", "hair", "top", "bottom", "shoes", "accessory", "back", "hand_l", "hand_r", "hip"]

var _item_labels: Dictionary = {} # slot -> Label
var _index: Dictionary = {} # slot -> 0 (none) or 1-based index into that slot's id list

func _ready() -> void:
	hide()
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = Vector2(16, 100)
	custom_minimum_size = Vector2(340, 40)

	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.custom_minimum_size = Vector2(360, 30 + SLOT_ORDER.size() * 30)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 6)
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Wardrobe — [I] Close"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	for slot in SLOT_ORDER:
		_index[slot] = 0
		var row := HBoxContainer.new()
		vbox.add_child(row)

		var name_label := Label.new()
		name_label.text = slot.capitalize()
		name_label.custom_minimum_size = Vector2(90, 0)
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		var prev_btn := Button.new()
		prev_btn.text = "<"
		prev_btn.custom_minimum_size = Vector2(26, 22)
		prev_btn.pressed.connect(_cycle.bind(slot, -1))
		row.add_child(prev_btn)

		var item_label := Label.new()
		item_label.text = "(none)"
		item_label.custom_minimum_size = Vector2(150, 0)
		item_label.add_theme_font_size_override("font_size", 14)
		row.add_child(item_label)
		_item_labels[slot] = item_label

		var next_btn := Button.new()
		next_btn.text = ">"
		next_btn.custom_minimum_size = Vector2(26, 22)
		next_btn.pressed.connect(_cycle.bind(slot, 1))
		row.add_child(next_btn)

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_all()

func _refresh_all() -> void:
	var player := WorldState.player
	if player == null:
		return
	for slot in SLOT_ORDER:
		var equipped: EquipmentItem = player.equipment.get_equipped(slot)
		var ids := _ids_for(slot)
		if equipped == null:
			_index[slot] = 0
		else:
			var pos: int = ids.find(equipped.id)
			_index[slot] = pos + 1 if pos != -1 else 0
		_item_labels[slot].text = "(none)" if _index[slot] == 0 else equipped.display_name

func _ids_for(slot: String) -> Array:
	var enum_slot = EquipmentItem.SLOT_NAMES.find_key(slot)
	return EquipmentCatalog.ids_for_slot(enum_slot)

func _cycle(slot: String, direction: int) -> void:
	var player := WorldState.player
	if player == null:
		return
	var ids := _ids_for(slot)
	var count: int = ids.size() + 1 # +1 for "None"
	var idx: int = (_index[slot] + direction + count) % count
	_index[slot] = idx
	if idx == 0:
		player.equipment.unequip(slot)
		_item_labels[slot].text = "(none)"
	else:
		var item: EquipmentItem = EquipmentCatalog.get_item(ids[idx - 1])
		player.equipment.equip(item)
		_item_labels[slot].text = item.display_name
