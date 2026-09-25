class_name ShopRegister
extends Interactable
## The general store's register. This is the "job" — the shift worker
## (see NPCDefinition.occupation "general_store_clerk") physically walks
## here for their scheduled hours; the player can browse whenever someone
## is actually staffing it. No shopping minigame, just world state.

@export var job_id: String = "general_store_clerk"

func get_prompt() -> String:
	return "Use Register"

func interact(_player: Node) -> void:
	AudioManager.play_sfx("register_use", global_position)
	var clerk_id: String = WorldState.get_job_holder(job_id)
	var clerk := WorldState.get_npc(clerk_id) if clerk_id != "" else null
	if clerk and clerk.arrived and clerk.current_activity == NPCBrain.Activity.WORK:
		EventBus.fire("hud_message", {"text": "%s: \"Welcome in, let me know if you need anything.\"" % clerk.definition.first_name})
	else:
		EventBus.fire("hud_message", {"text": "Nobody's at the register right now."})
