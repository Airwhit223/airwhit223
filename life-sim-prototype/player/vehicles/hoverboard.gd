class_name Hoverboard
extends "res://player/vehicles/vehicle_base.gd"
## Anti-gravity hoverboard capable of gliding over rough terrain and water surfaces.

@export var hover_height: float = 0.38
@export var hover_damping: float = 12.0
@export var water_glide_speed: float = 14.0

var is_over_water: bool = false

func _ready() -> void:
	vehicle_name = "Anti-Grav Hoverboard"
	max_speed = 13.5
	acceleration = 22.0
	turn_speed = 4.2
	super._ready()

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var boosting := false
	if is_occupied:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		boosting = Input.is_action_pressed("sprint")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = 6.8
		if Input.is_action_just_pressed("interact"):
			dismount()
			return

	# Raycast downward to simulate repulsor cushion over land or water
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 2.0)
	query.collide_with_areas = true
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty():
		var col = hit.get("collider")
		is_over_water = col and (col.is_in_group("water") or col.name.contains("Water") or col.name.contains("Ocean"))
		var hit_y: float = hit.get("position").y
		var target_y := hit_y + hover_height
		var y_diff := target_y - global_position.y
		velocity.y = y_diff * hover_damping
	else:
		velocity.y -= 9.8 * delta

	update_vehicle_physics(delta, input, boosting)
