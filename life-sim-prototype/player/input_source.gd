class_name InputSource
extends RefCounted
## Where a character's intent comes from.
##
## Ability controllers must never call `Input` directly. In multiplayer every peer runs the same scripts, so a
## controller that polls the keyboard makes EVERY character on the machine answer the local player - four fliers
## all taking off at once. Each character instead owns an InputSource: the locally controlled one reads the real
## device, remote ones are fed replicated intent by the network layer, and an AI or a replay can drive the same
## interface without either the controller or the network knowing the difference.
##
## Written before the co-op port on purpose - converting two ability controllers now is cheap, converting a
## dozen later is not. See docs/MULTIPLAYER_PLAN.md.

## Held this frame.
func pressed(_action: StringName) -> bool:
	return false

## Went down this frame.
func just_pressed(_action: StringName) -> bool:
	return false

## Movement intent as a 2D vector, already in the game's left/right, forward/back convention.
func move_vector() -> Vector2:
	return Vector2.ZERO

## True for the character this machine's player is actually driving. Ability controllers use it to decide whether
## to run local-only work such as camera shake or UI prompts.
func is_local() -> bool:
	return false
