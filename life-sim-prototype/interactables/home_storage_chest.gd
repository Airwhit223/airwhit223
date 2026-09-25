class_name HomeStorageChest
extends Interactable
## A placeable home-storage object. Interacting opens the ChestPanel (move items, change style, buy upgrades).

@export var storage_id := "home_chest_1"
var _body: MeshInstance3D
var _lid: MeshInstance3D

func _ready() -> void:
	super._ready()
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	InventoryManager.ensure_storage(storage_id)
	InventoryManager.storage_changed.connect(_on_storage_changed)
	_build_visuals()
	_refresh_visual()

func get_prompt() -> String:
	return "Open chest  (%d/%d stacks)" % [InventoryManager.storage_used_slots(storage_id), InventoryManager.storage_capacity(storage_id)]

func interact(_player: Node) -> void:
	get_tree().root.add_child(ChestPanel.open(storage_id))

func _build_visuals() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(1.15, 0.85, 0.65)
	collision.shape = shape; collision.position.y = 0.43; add_child(collision)
	_body = MeshInstance3D.new(); var body_mesh := BoxMesh.new(); body_mesh.size = Vector3(1.1, 0.62, 0.62); _body.mesh = body_mesh; _body.position.y = 0.31; add_child(_body)
	_lid = MeshInstance3D.new(); var lid_mesh := BoxMesh.new(); lid_mesh.size = Vector3(1.16, 0.18, 0.68); _lid.mesh = lid_mesh; _lid.position.y = 0.71; add_child(_lid)

func _refresh_visual() -> void:
	if _body == null: return
	var style := int(InventoryManager.storage_data(storage_id)["style"])
	var colors := [Color("8b542e"), Color("315b7d"), Color("42653b"), Color("24233b")]
	var mat := StandardMaterial3D.new(); mat.albedo_color = colors[style]; _body.material_override = mat
	var lid_mat := StandardMaterial3D.new(); lid_mat.albedo_color = colors[style].lightened(0.16); _lid.material_override = lid_mat

func _on_storage_changed(changed_id: String) -> void:
	if changed_id == storage_id: _refresh_visual()
