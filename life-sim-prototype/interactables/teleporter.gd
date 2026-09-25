class_name Teleporter
extends Interactable
## A generic door/transition point — used for both "enter house" and
## "exit house" so the same script covers any future NPC home too. Moves the
## player to `destination`'s position with a short fade, no scene loading.

@export var destination: NodePath
@export var prompt_text: String = "Enter"

func get_prompt() -> String:
	return prompt_text

func interact(player) -> void:
	if destination.is_empty():
		return
	var target: Node = get_node_or_null(destination)
	if target == null and is_inside_tree():
		var dest_str := String(destination)
		if dest_str.begins_with("%"):
			var clean_name := dest_str.substr(1)
			target = get_tree().current_scene.find_child(clean_name, true, false)
		else:
			target = get_tree().current_scene.find_child(dest_str.get_file(), true, false)
	if target and player.has_method("teleport_to"):
		player.teleport_to(target.global_position)
