class_name LocalInputSource
extends InputSource
## The character this machine's player is driving: reads the real device.
##
## `locked` mirrors the existing player.input_locked behaviour (cutscenes, the character creator) in one place,
## so every ability that goes through this source is silenced together rather than each checking for itself.

var locked := false

func pressed(action: StringName) -> bool:
	return not locked and Input.is_action_pressed(action)

func just_pressed(action: StringName) -> bool:
	return not locked and Input.is_action_just_pressed(action)

func move_vector() -> Vector2:
	if locked:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func is_local() -> bool:
	return true
