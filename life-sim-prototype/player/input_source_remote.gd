class_name RemoteInputSource
extends InputSource
## A character driven by somebody else's machine, or by a replay or test harness.
##
## The network layer calls apply() with the intent it received for this peer; the controllers then read it
## exactly as they read a local device. Edge detection is done here so remote abilities see the same
## "just pressed" semantics a local one does, rather than every controller re-deriving it.

var _held: Dictionary = {}
var _previous: Dictionary = {}
var _move := Vector2.ZERO

## Called once per network tick with this peer's intent for the frame.
func apply(held_actions: Array, move: Vector2) -> void:
	_previous = _held.duplicate()
	_held.clear()
	for action in held_actions:
		_held[StringName(action)] = true
	_move = move

func pressed(action: StringName) -> bool:
	return _held.has(action)

func just_pressed(action: StringName) -> bool:
	return _held.has(action) and not _previous.has(action)

func move_vector() -> Vector2:
	return _move

func is_local() -> bool:
	return false
