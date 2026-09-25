class_name SuperpowerController
extends Node
## Superpower and biological mutation traversal controller.
## Provides:
## - Kinetic Dash: High-speed burst with invulnerability frames and motion trail.
## - Super Jump / Air Jump: Charged jump velocity and mid-air double jump.
## - Ground Smash: Downward aerial slam dealing AoE damage and shattering destructible barriers.
## - Variable Gravity: Allows low-gravity floating (space) or heavy drops.

signal power_used(power_name: String, details: Dictionary)
signal ground_smash_landed(position: Vector3, radius: float)

@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.28
@export var dash_cooldown: float = 0.75

@export var super_jump_velocity: float = 9.5
@export var double_jump_velocity: float = 7.5

@export var ground_smash_speed: float = 24.0
@export var ground_smash_radius: float = 5.0
@export var ground_smash_damage: int = 50

var player: CharacterBody3D
var has_double_jump: bool = true
var has_kinetic_dash: bool = true
var has_ground_smash: bool = true

var is_dashing: bool = false
var is_ground_smashing: bool = false
var dash_time_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var jumps_made: int = 0

var gravity_scale: float = 1.0

func setup(p: CharacterBody3D) -> void:
	player = p

func _process(delta: float) -> void:
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)

func update_powers(delta: float) -> bool:
	if player == null:
		return false

	# Dash handling
	if is_dashing:
		dash_time_remaining -= delta
		player.velocity.x = dash_direction.x * dash_speed
		player.velocity.z = dash_direction.z * dash_speed
		player.velocity.y = 0.0
		if dash_time_remaining <= 0.0:
			is_dashing = false
		return true

	# Ground smash handling
	if is_ground_smashing:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.velocity.y = -ground_smash_speed
		if player.is_on_floor():
			is_ground_smashing = false
			_execute_ground_smash_impact()
		return true

	if player.is_on_floor():
		jumps_made = 0

	return false

func try_dash(cam_basis: Basis, input_dir: Vector2) -> bool:
	if not has_kinetic_dash or is_dashing or dash_cooldown_remaining > 0.0:
		return false

	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := forward * -input_dir.y + right * input_dir.x
	if dir.length() < 0.1:
		dir = -player.global_transform.basis.z
		dir.y = 0.0
		dir = dir.normalized()
	else:
		dir = dir.normalized()

	dash_direction = dir
	is_dashing = true
	dash_time_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	power_used.emit("kinetic_dash", {"direction": dir, "speed": dash_speed})
	return true

func try_jump(current_velocity_y: float) -> float:
	if player.is_on_floor() or jumps_made == 0:
		jumps_made = 1
		power_used.emit("super_jump", {"velocity": super_jump_velocity})
		return super_jump_velocity
	elif has_double_jump and jumps_made == 1:
		jumps_made = 2
		power_used.emit("air_jump", {"velocity": double_jump_velocity})
		return double_jump_velocity
	return current_velocity_y

func try_ground_smash() -> bool:
	if not has_ground_smash or player.is_on_floor() or is_ground_smashing:
		return false
	is_ground_smashing = true
	power_used.emit("ground_smash_start", {})
	return true

func _execute_ground_smash_impact() -> void:
	ground_smash_landed.emit(player.global_position, ground_smash_radius)
	power_used.emit("ground_smash_impact", {"position": player.global_position, "radius": ground_smash_radius})

	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = ground_smash_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), player.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var results := space_state.intersect_shape(query, 32)
	for r in results:
		var collider = r.get("collider")
		if collider == null or collider == player:
			continue
		if collider.has_method("break_rock"):
			collider.break_rock(ground_smash_damage)
		elif collider.has_method("take_damage"):
			collider.take_damage(ground_smash_damage, player.global_position)
