class_name Bed
extends Interactable
## The player's own bed. Sleeping jumps the shared simulation clock straight
## to morning (see TimeManager.advance_to_morning) instead of ticking through
## the night frame-by-frame — NPCs react to that jump the same way they'd
## react to any other schedule re-evaluation.
##
## Restricted to nighttime for now (no daytime napping) — but that's always
## communicated, never a silent no-op.

const NIGHT_START_HOUR := 21
const NIGHT_END_HOUR := 7

func get_prompt() -> String:
	return "Sleep"

func interact(player) -> void:
	var tm = get_node_or_null("/root/TimeManager")
	var hour: int = tm.hour if tm != null else 0
	if hour >= NIGHT_START_HOUR or hour < NIGHT_END_HOUR:
		if player.has_method("sleep_until_morning"):
			player.sleep_until_morning()
	else:
		var bus = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.fire("hud_message", {"text": "It's too early to sleep."})
