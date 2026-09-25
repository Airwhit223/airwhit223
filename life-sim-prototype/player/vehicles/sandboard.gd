class_name Sandboard
extends "res://player/vehicles/vehicle_base.gd"
## Pharaonic sandboard with hieroglyphic gold engravings.
## Specialized for high-speed sand-skating, dune-drifting, and desert traversal.

@export var sand_hover_height: float = 0.25
@export var sand_boost_multiplier: float = 1.75
@export var drift_multiplier: float = 2.0

var is_drifting: bool = false
var drift_score: float = 0.0
var is_on_sand: bool = true

func _ready() -> void:
	vehicle_name = "Ancient Khem Sandboard"
	max_speed = 18.0
	acceleration = 25.0
	turn_speed = 4.8
	super._ready()

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var boosting := false
	if is_occupied:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		boosting = Input.is_action_pressed("sprint")
		is_drifting = boosting and abs(input.x) > 0.2
		if is_drifting:
			drift_score += delta * 2.0
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = 7.5
		if Input.is_action_just_pressed("interact"):
			dismount()
			return

	# Raycast downward to detect desert sand terrain
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.25, global_position + Vector3.DOWN * 2.0)
	query.collide_with_areas = true
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty():
		var hit_y: float = hit.get("position").y
		var target_y := hit_y + sand_hover_height
		var y_diff := target_y - global_position.y
		velocity.y = y_diff * 14.0
	else:
		velocity.y -= 12.0 * delta

	var current_accel = acceleration * (sand_boost_multiplier if boosting else 1.0)
	var current_max = max_speed * (sand_boost_multiplier if boosting else 1.0)
	
	# Apply vehicle movement
	if is_occupied:
		var forward := -global_transform.basis.z
		var right := global_transform.basis.x
		if input.y != 0.0:
			velocity += forward * (-input.y) * current_accel * delta
		if input.x != 0.0:
			rotation.y -= input.x * turn_speed * delta * (1.3 if is_drifting else 1.0)
		
		# Damp lateral movement for tight carving / drift
		var f_speed := velocity.dot(forward)
		var r_speed := velocity.dot(right)
		var drift_drag := 0.88 if is_drifting else 0.4
		velocity = forward * f_speed + right * (r_speed * drift_drag)
		
		# Cap max planar speed
		var h_vel := Vector2(velocity.x, velocity.z)
		if h_vel.length() > current_max:
			h_vel = h_vel.normalized() * current_max
			velocity.x = h_vel.x
			velocity.z = h_vel.y
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	move_and_slide()
