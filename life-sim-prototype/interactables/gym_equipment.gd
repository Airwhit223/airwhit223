class_name GymEquipment
extends Interactable
## One piece of gym equipment (treadmill, bench, bag...). Same object type
## an NPC "exercises" near during their EXERCISE schedule block — the player
## uses the identical world object instead of a workout minigame.

@export var equipment_name: String = "equipment"
@export var fitness_gain: float = 5.0
@export var use_cooldown_msec: int = 2000

var _last_used_msec: int = -999999

func get_prompt() -> String:
	return "Work Out"

func interact(player) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_used_msec < use_cooldown_msec:
		return
	_last_used_msec = now
	AudioManager.play_sfx("gym_equipment", global_position)
	# Workouts feed the weekly body/fitness drift (PlayerStats); the body changes at the next week, not instantly.
	PlayerStats.log_activity("workout", fitness_gain / 5.0)
	EventBus.fire("hud_message", {"text": "You used the %s. Good workout." % equipment_name})
