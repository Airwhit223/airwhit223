class_name RelicChest
extends StaticBody3D
## Ancient relic chest rewarding magic gear, blueprints, or celestial artifacts.

signal opened(reward_id: String)

@export var reward_id: String = "magic_gear_aether_glider"
@export var reward_name: String = "Aether Glider Wings"
@export var is_opened: bool = false

var lid_node: Node3D

func _ready() -> void:
	add_to_group("interactable")
	lid_node = get_node_or_null("ChestLid")

func get_prompt() -> String:
	return "" if is_opened else "Open Chest (" + reward_name + ")"

func interact(user: Node) -> void:
	if is_opened:
		return
	is_opened = true
	if lid_node:
		var tween := create_tween()
		tween.tween_property(lid_node, "rotation_degrees:x", -75.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened.emit(reward_id)
	var eb := get_node_or_null("/root/EventBus")
	if eb:
		eb.fire("hud_message", {"text": "Acquired: " + reward_name + "!"})
