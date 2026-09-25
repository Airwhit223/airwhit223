class_name Bench
extends Interactable
## Purely a flavor interactable for now — proves the social space isn't a
## dead prop yard. A real "sit" pose/animation is a later polish pass.

func get_prompt() -> String:
	return "Use Bench"

func interact(_player) -> void:
	AudioManager.play_ui_sfx("interact_click")
	EventBus.fire("hud_message", {"text": "You sit for a moment and take in the neighborhood."})
