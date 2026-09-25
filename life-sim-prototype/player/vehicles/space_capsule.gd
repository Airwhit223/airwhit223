class_name SpaceCapsule
extends "res://player/vehicles/vehicle_base.gd"
## Interplanetary exploration capsule for atmospheric ascent and outer space navigation.

signal launch_sequence_started()
signal space_reached()

@export var is_space_mode: bool = false
@export var space_thrust: float = 25.0

var is_launching: bool = false
var launch_timer: float = 0.0

func _ready() -> void:
	vehicle_name = "Cosmic Space Capsule"
	max_speed = 22.0
	acceleration = 28.0
	turn_speed = 2.8
	super._ready()

func _physics_process(delta: float) -> void:
	if is_launching:
		launch_timer += delta
		velocity.y = 35.0 # High vertical launch speed
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if launch_timer >= 4.0:
			is_launching = false
			is_space_mode = true
			space_reached.emit()
		return

	if is_space_mode:
		_process_space_physics(delta)
		return

	var input := Vector2.ZERO
	if is_occupied:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump"):
			trigger_launch()
		if Input.is_action_just_pressed("interact"):
			dismount()
			return

	update_vehicle_physics(delta, input, false)

func trigger_launch() -> void:
	if is_launching:
		return
	is_launching = true
	launch_timer = 0.0
	launch_sequence_started.emit()

func _process_space_physics(delta: float) -> void:
	var input := Vector2.ZERO
	if is_occupied:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var vert := 0.0
		if Input.is_action_pressed("jump"):
			vert += 1.0
		if Input.is_action_pressed("crouch"):
			vert -= 1.0

		var cam_basis := global_transform.basis
		var forward := -cam_basis.z
		var right := cam_basis.x
		var up := cam_basis.y

		var move_vector := forward * -input.y + right * input.x + up * vert
		velocity = move_vector.normalized() * space_thrust
		if input.x != 0.0:
			rotation.y += -input.x * turn_speed * delta

	move_and_slide()
