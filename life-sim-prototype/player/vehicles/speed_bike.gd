class_name SpeedBike
extends "res://player/vehicles/vehicle_base.gd"
## High-speed Capsule-Corp style overland speed bike.

@export var boost_speed: float = 20.0
@export var boost_duration: float = 3.0

var boost_energy: float = 100.0

func _ready() -> void:
	vehicle_name = "Speed Bike"
	max_speed = 16.0
	acceleration = 24.0
	turn_speed = 3.2
	super._ready()

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var is_boosting := false
	if is_occupied:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_pressed("sprint") and boost_energy > 0.0:
			is_boosting = true
			boost_energy = maxf(0.0, boost_energy - delta * 30.0)
		else:
			boost_energy = minf(100.0, boost_energy + delta * 15.0)

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = 5.2
		if Input.is_action_just_pressed("interact"):
			dismount()
			return

	update_vehicle_physics(delta, input, is_boosting)
