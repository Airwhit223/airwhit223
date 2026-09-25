class_name SkateboardPickup
extends Interactable
## Foundation for skating-as-traversal: grants the player the ability to
## mount/dismount a skateboard (toggle_mount action) anywhere in the world,
## rather than skating being its own isolated mode or minigame. The world
## prop disappears once carried — it's the same board, just on the player now.

func get_prompt() -> String:
	return "Pick Up Skateboard"

func interact(player) -> void:
	if player.has_method("grant_skateboard"):
		player.grant_skateboard()
	AudioManager.play_ui_sfx("interact_click")
	EventBus.fire("hud_message", {"text": "Picked up the skateboard. Press Q to mount/dismount."})
	queue_free()
