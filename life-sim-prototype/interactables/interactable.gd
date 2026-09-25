class_name Interactable
extends Area3D
## Base for every world object the player can walk up to and press E on.
## Concrete interactables (register, gym equipment, skateboard) override
## get_prompt() and interact(). This is intentionally minimal — the point is
## that jobs and activities use these ordinary world objects instead of
## loading a separate minigame scene.

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "Interact"

func interact(_player: Node) -> void:
	pass
