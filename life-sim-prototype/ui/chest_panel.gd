class_name ChestPanel
extends CanvasLayer
## Home storage screen: pockets on the left, the chest on the right. Click an item to move one, Shift-click to move
## the whole stack. Style and the paid rank upgrade are buttons, not key combos. Built in code like JobPanel; movement
## input is locked while it's open.

signal closed

var storage_id := ""
var _pockets: VBoxContainer
var _chest: VBoxContainer
var _header: Label
var _upgrade: Button
var _style: Button
var _status: Label

static func open(id: String) -> ChestPanel:
	var p := ChestPanel.new()
	p.storage_id = id
	return p

func _ready() -> void:
	layer = 20
	_build()
	InventoryManager.inventory_changed.connect(refresh)
	InventoryManager.storage_changed.connect(func(_id): refresh())
	refresh()
	var p = WorldState.player
	if p:
		p.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 420)
	panel.position = Vector2(-310, -210)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 22)
	col.add_child(_header)
	var hint := Label.new()
	hint.text = "Click to move one  ·  Shift-click to move the stack"
	hint.add_theme_font_size_override("font_size", 13)
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	_pockets = _column(row)
	_chest = _column(row)
	var buttons := HBoxContainer.new()
	col.add_child(buttons)
	_style = Button.new()
	_style.pressed.connect(func(): InventoryManager.cycle_storage_style(storage_id))
	buttons.add_child(_style)
	_upgrade = Button.new()
	_upgrade.pressed.connect(_on_upgrade)
	buttons.add_child(_upgrade)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close)
	buttons.add_child(close)
	_status = Label.new()
	col.add_child(_status)

func _column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 250)
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func refresh() -> void:
	if not is_inside_tree():
		return
	var data := InventoryManager.storage_data(storage_id)
	_header.text = "Home Chest  ·  Rank %d  ·  %s" % [data["rank"], InventoryManager.STYLE_NAMES[int(data["style"])]]
	_fill(_pockets, "POCKETS  %d / %d" % [InventoryManager.used_slots(), InventoryManager.PLAYER_SLOT_CAPACITY],
		InventoryManager.items, true)
	_fill(_chest, "CHEST  %d / %d" % [InventoryManager.storage_used_slots(storage_id), InventoryManager.storage_capacity(storage_id)],
		data["items"], false)
	_style.text = "Change style"
	var cost := InventoryManager.upgrade_cost(storage_id)
	_upgrade.text = "Max rank" if cost == 0 else "Upgrade to Rank %d  ($%d)" % [int(data["rank"]) + 1, cost]
	_upgrade.disabled = cost == 0 or not Economy.can_afford(cost)

func _fill(box: VBoxContainer, title: String, stock: Dictionary, from_pockets: bool) -> void:
	for c in box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 16)
	box.add_child(t)
	var ids: Array = stock.keys()
	ids.sort()
	for id in ids:
		var n := int(stock[id])
		if n <= 0:
			continue
		var b := Button.new()
		b.text = "%s  × %d" % [InventoryManager.display_name(String(id)), n]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_move.bind(String(id), from_pockets))
		box.add_child(b)
	if ids.is_empty():
		var e := Label.new()
		e.text = "(empty)"
		box.add_child(e)

func _move(item_id: String, from_pockets: bool) -> void:
	var stack := Input.is_key_pressed(KEY_SHIFT)
	var n := (InventoryManager.count(item_id) if from_pockets else InventoryManager.storage_count(storage_id, item_id)) if stack else 1
	var ok: bool = InventoryManager.deposit(storage_id, item_id, n) if from_pockets else InventoryManager.withdraw(storage_id, item_id, n)
	if not ok:
		_status.text = "The chest is full." if from_pockets else "Your pockets are full."

func _on_upgrade() -> void:
	if InventoryManager.upgrade_storage(storage_id):
		_status.text = "Upgraded! Now holds %d stacks." % InventoryManager.storage_capacity(storage_id)
	else:
		_status.text = "Not enough money."

func _close() -> void:
	var p = WorldState.player
	if p:
		p.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()
