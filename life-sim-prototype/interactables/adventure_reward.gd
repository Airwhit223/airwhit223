class_name AdventureReward
extends Interactable

func _ready() -> void:
	super._ready()
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true

func get_prompt() -> String:
	if AdventureManager.ruin_relic_found:
		return "Ruin Relic collected"
	if AdventureManager.enemies_defeated < 1:
		return "Ruin Relic (guarded)"
	return "Take Ruin Relic"

func interact(_player: Node) -> void:
	if AdventureManager.claim_relic():
		visible = false
		set_process(false)
	else:
		EventBus.fire("hud_message", {"text": "The relic is still guarded."})
