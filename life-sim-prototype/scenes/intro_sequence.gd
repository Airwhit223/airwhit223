class_name IntroSequence
extends Node
## The opening of a new game, played in the world rather than on a menu screen.
##
##   1. the player is already standing in their bedroom, looking into the mirror
##   2. the camera sits in the mirror, so the character you are editing is the one in the room
##   3. the creator panel sits beside them; every change is applied to the real character, not a preview
##   4. on "Done" the camera pulls back, the player walks out of the room and the game hands over control
##
## Nothing here is a cutscene system: it drives the same player, mirror, doors and creator the game already uses.

signal finished()

const PULL_BACK_TIME := 1.6
const WALK_TIME := 2.2

var player: Node3D
var mirror: Node3D

var _camera: Camera3D
var _creator: CharacterCreator
var _previous_mouse := Input.MOUSE_MODE_CAPTURED

## `mirror` is the mirror in the player's bedroom; the player is placed in front of it.
func start(player_node: Node3D, mirror_node: Node3D) -> void:
	player = player_node
	mirror = mirror_node
	var facing := mirror.global_position
	var stand := facing + Vector3(0, 0, 1.9)          # in front of the glass, an arm's length back
	player.global_position = Vector3(stand.x, mirror.global_position.y + 0.1, stand.z)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0                            # the rig faces -Z, the mirror is that way
	player.input_locked = true
	player.camera_rig.rotation.y = PI                  # so "forward" later walks them toward the door
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_camera = Camera3D.new()
	_camera.name = "IntroCamera"
	add_child(_camera)
	_camera.global_position = mirror.global_position + Vector3(0, 1.48, 0.28)
	_camera.look_at(player.global_position + Vector3(0, 1.35, 0))
	_camera.fov = 48.0
	_camera.current = true

	_creator = CharacterCreator.new()
	_creator.name = "CharacterCreator"
	_creator.in_world = true
	_creator.target_rig = player.body
	_creator.title_text = "Who are you?"
	var saved := ToriyamaRoster.saved_recipe()
	if not saved.is_empty():
		_creator.recipe = saved.duplicate(true)
	_creator.finished.connect(_on_finished)
	get_tree().root.add_child(_creator)

func _on_finished(recipe: Dictionary) -> void:
	player.apply_recipe(recipe)
	_walk_out()

## Pull the camera back off the mirror, walk the player out through their own front door, then hand over control.
func _walk_out() -> void:
	# stay inside the room: the bedroom is 6m across, so this pulls back to the far corner, not through the wall
	var back := player.global_position + Vector3(0.9, 1.35, 2.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(t: float) -> void:
		_camera.global_position = _camera.global_position.lerp(back, t)
		_camera.look_at(player.global_position + Vector3(0, 1.2, 0)), 0.06, 0.06, PULL_BACK_TIME)
	await tween.finished

	player.input_locked = false
	Input.action_press("move_forward")                 # camera_rig was turned around, so this walks to the door
	await get_tree().create_timer(WALK_TIME).timeout
	Input.action_release("move_forward")

	var door := player.get_tree().get_first_node_in_group("player_home_exit")
	var outside: Vector3 = WorldState.get_location_position("home_player")
	if door and door.has_method("interact"):
		door.interact(player)
	else:
		player.teleport_to(outside)
	await get_tree().create_timer(0.6).timeout

	_camera.current = false
	player.camera.current = true
	player.camera_rig.rotation.y = 0.0
	Input.mouse_mode = _previous_mouse
	EventBus.fire("hud_message", {"text": "A new day. Go take a look around."})
	finished.emit()
	queue_free()
