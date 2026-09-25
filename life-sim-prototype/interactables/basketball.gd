class_name Basketball
extends RigidBody3D
## A single physical ball shared by the player and every NPC on the court.
## One possession model for everyone: reserve it, carry it, shoot it, then
## it's loose again until someone reserves it — no infinite replacement balls.
##
## A miss just stays wherever it lands (pick it back up in place). A make
## gets a short delay before this same ball reappears at the rest spot, so
## the court doesn't need a rack of replacement balls.
##
## While held, the carrier positions it every frame (CharacterRig's
## two-handed hold point); this script only handles possession and physics.

const SHOOT_SPEED := 7.0
const AVAILABLE_SPEED_THRESHOLD := 1.0
const SCORE_RESET_DELAY := 1.5
const FELL_THROUGH_WORLD_Y := -10.0
## How long the holder keeps ignoring the ball's collision after releasing it,
## so a shot launched from right against the body doesn't shove the thrower.
const RELEASE_GRACE := 0.35

@export var rest_position: Vector3 = Vector3.ZERO # set by main.gd on spawn

var possessor = null # Player or NPCBrain currently carrying the ball
var _reserved_by = null # who is currently walking over to pick it up
var _pending_score_reset: bool = false
var _exception_body: PhysicsBody3D = null

func _ready() -> void:
	add_to_group("basketballs")
	if rest_position == Vector3.ZERO:
		rest_position = global_position

func _physics_process(_delta: float) -> void:
	if global_position.y < FELL_THROUGH_WORLD_Y:
		_reset_to_rest()

## True while someone is holding it, or another NPC has already called dibs
## on retrieving it — either way, nobody else should try to grab it.
func is_claimed() -> bool:
	return possessor != null or _reserved_by != null

func get_prompt() -> String:
	if possessor != null:
		return ""
	return "Pick Up Basketball"

func is_held() -> bool:
	return possessor != null

## Loose and slow enough to walk up and grab — a miss sitting on the ground
## qualifies immediately, no forced return-to-center required.
func is_available() -> bool:
	return possessor == null and _reserved_by == null and linear_velocity.length() < AVAILABLE_SPEED_THRESHOLD

func reserve(who) -> bool:
	if not is_available():
		return false
	_reserved_by = who
	return true

func cancel_reservation(who) -> void:
	if _reserved_by == who:
		_reserved_by = null

func pick_up(who) -> void:
	possessor = who
	_reserved_by = null
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_ignore_holder(who)
	AudioManager.play_sfx("basketball_bounce", global_position)

## Releases the ball with a shot toward `direction` at `speed`. Used by both
## the player's aimed shot and an NPC's shove-away when leaving mid-hold.
func shoot(direction: Vector3, speed: float = SHOOT_SPEED) -> void:
	possessor = null
	freeze = false
	linear_velocity = direction.normalized() * speed
	angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	_restore_holder_collision_later()
	AudioManager.play_sfx("basketball_shot", global_position)

## Computes a shot from the ball's CURRENT position (wherever it's being held)
## toward the hoop, with `skill` (0-100) controlling accuracy vs. a miss.
func shoot_toward_hoop(skill: float) -> void:
	var hoop = get_tree().get_first_node_in_group("basketball_hoops")
	if hoop == null:
		return
	var target: Vector3 = hoop.get_scoring_position()
	var accuracy := clampf(skill / 100.0, 0.05, 0.98)
	var miss_offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * (1.0 - accuracy) * 1.5
	var aim_point := target + miss_offset
	var displacement := aim_point - global_position
	var flat_dist := Vector2(displacement.x, displacement.z).length()
	var travel_time := clampf(flat_dist / 4.0, 0.4, 1.6)
	var vel := Vector3(
		displacement.x / travel_time,
		(displacement.y + 0.5 * 9.8 * travel_time * travel_time) / travel_time,
		displacement.z / travel_time
	)
	possessor = null
	freeze = false
	linear_velocity = vel
	angular_velocity = Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	_restore_holder_collision_later()
	AudioManager.play_sfx("basketball_shot", global_position)

## Called by BasketballHoop when this ball scores. Leaves it to physics for a
## moment (falling through the net looks right) then brings the SAME ball
## back to the rest spot instead of spawning a new one.
func schedule_reset_after_score() -> void:
	if _pending_score_reset:
		return
	_pending_score_reset = true
	await get_tree().create_timer(SCORE_RESET_DELAY).timeout
	_pending_score_reset = false
	if possessor == null:
		_reset_to_rest()

func _reset_to_rest() -> void:
	possessor = null
	_reserved_by = null
	global_position = rest_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	_restore_holder_collision_later()
	await get_tree().create_timer(0.15).timeout
	if possessor == null and _reserved_by == null:
		freeze = false

## The ball is moved to the holder's hands every frame, right up against their
## collision capsule. Without this exception the holder's move_and_slide gets
## shoved out of the ball each frame (walking with it covered ~3x the normal
## distance).
func _ignore_holder(who) -> void:
	if not (who is PhysicsBody3D):
		return
	if _exception_body != null and _exception_body != who and is_instance_valid(_exception_body):
		_drop_exception(_exception_body)
	_exception_body = who
	add_collision_exception_with(who)
	who.add_collision_exception_with(self)

func _restore_holder_collision_later() -> void:
	var body := _exception_body
	if body == null:
		return
	await get_tree().create_timer(RELEASE_GRACE).timeout
	if possessor == body or _exception_body != body:
		return # re-grabbed by the same body, or someone else took over meanwhile
	if is_instance_valid(body):
		_drop_exception(body)
	_exception_body = null

func _drop_exception(body: PhysicsBody3D) -> void:
	remove_collision_exception_with(body)
	body.remove_collision_exception_with(self)
