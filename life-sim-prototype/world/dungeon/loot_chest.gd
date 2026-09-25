class_name LootChest
extends Interactable
## A chest in a contract dungeon holding one contract item (goes into the bag through QuestManager.give_item, so item
## objectives tick). Tracking skill 25+ makes the chests you're looking for glow - the builder's Skate Knowledge,
## the adventurer's Tracking.

const TRACKING_GLOW := 25.0

var item_id := ""
var count := 1
var opened := false
var _lid: MeshInstance3D
var _glow: OmniLight3D

func _ready() -> void:
	super._ready()
	collision_layer = 8
	collision_mask = 0
	var col := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(1.4, 1.2, 1.2); col.shape = sh
	col.position.y = 0.5
	add_child(col)
	var body := StaticBody3D.new()
	var bc := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.9, 0.55, 0.6); bc.shape = bs
	bc.position.y = 0.28
	body.add_child(bc)
	add_child(body)
	var box := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.9, 0.5, 0.6); box.mesh = bm
	box.position.y = 0.25
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.3, 0.16); box.material_override = mat
	add_child(box)
	_lid = MeshInstance3D.new(); var lm := BoxMesh.new(); lm.size = Vector3(0.94, 0.14, 0.64); _lid.mesh = lm
	_lid.position.y = 0.57
	var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color(0.6, 0.45, 0.2); _lid.material_override = lmat
	add_child(_lid)
	if JobManager.skill("tracking") >= TRACKING_GLOW:
		_glow = OmniLight3D.new(); _glow.light_color = Color(1.0, 0.85, 0.4); _glow.omni_range = 3.0
		_glow.light_energy = 2.0; _glow.position.y = 1.0
		add_child(_glow)

func get_prompt() -> String:
	return "Empty chest" if opened else "Open chest"

func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	_lid.rotation.x = -1.1
	_lid.position += Vector3(0, 0.15, -0.25)
	if _glow:
		_glow.queue_free()
	QuestManager.give_item(item_id, count)
	EventBus.fire("dungeon_loot_taken", {"item": item_id, "count": count})
