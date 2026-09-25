class_name VehicleBase
extends CharacterBody3D
## Base class for drivable vehicles (Hoverboard, Speed Bike, Space Capsule).

signal player_mounted(driver: Node)
signal player_dismounted(driver: Node)

@export var vehicle_name: String = "Vehicle"
@export var max_speed: float = 12.0
@export var acceleration: float = 18.0
@export var turn_speed: float = 3.5
@export var mount_offset: Vector3 = Vector3(0, 0.4, 0)
@export var camera_distance: float = 4.8
@export var camera_height: float = 2.0

var driver: CharacterBody3D = null
var is_occupied: bool = false
var current_speed: float = 0.0
var steering: float = 0.0

func _ready() -> void:
	add_to_group("vehicle")
	add_to_group("interactable")

func get_prompt() -> String:
	return "Mount " + vehicle_name if not is_occupied else ""

func interact(user: Node) -> void:
	if is_occupied:
		if user == driver:
			dismount()
	else:
		if user is CharacterBody3D:
			mount(user)

func mount(user: CharacterBody3D) -> void:
	if is_occupied:
		return
	driver = user
	is_occupied = true
	
	# Reparent/hide or freeze player character while operating vehicle
	driver.set_physics_process(false)
	driver.visible = false
	driver.global_position = global_position + mount_offset
	driver.reparent(self)
	
	player_mounted.emit(driver)

func dismount() -> void:
	if not is_occupied or driver == null:
		return
	
	var user := driver
	driver = null
	is_occupied = false
	
	user.reparent(get_parent())
	user.global_position = global_position + global_transform.basis.x * 1.5 + Vector3.UP * 0.2
	user.visible = true
	user.set_physics_process(true)
	
	current_speed = 0.0
	velocity = Vector3.ZERO
	player_dismounted.emit(user)

func update_vehicle_physics(delta: float, input_vector: Vector2, is_boosting: bool = false) -> void:
	if not is_occupied:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	# Handle driver input
	var target_speed := max_speed * (1.5 if is_boosting else 1.0)
	if input_vector.y != 0.0:
		current_speed = move_toward(current_speed, -input_vector.y * target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, acceleration * 0.8 * delta)

	if absf(current_speed) > 0.1:
		rotation.y += -input_vector.x * turn_speed * delta * signf(current_speed)

	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed

	if not is_on_floor():
		velocity.y -= 9.8 * delta

	move_and_slide()
