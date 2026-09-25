class_name Skateboard
extends Node3D
## Stylized Toon Skateboard with rolling wheels and carving tilt.
## Matches the Akira Toriyama / Dragon Quest / Simpson animated aesthetic.

@export var wheel_radius: float = 0.042 # 84mm wheel in meters
@export var max_steer_tilt: float = 6.5 # degrees of deck roll when turning
@export var tilt_lerp_speed: float = 8.0

# Node references
var deck_pivot: Node3D
var front_truck: Node3D
var rear_truck: Node3D

# Wheels
var wheel_fl: Node3D
var wheel_fr: Node3D
var wheel_bl: Node3D
var wheel_br: Node3D

var current_tilt: float = 0.0
var wheel_rotation: float = 0.0

func _ready() -> void:
	_cache_nodes()

func _cache_nodes() -> void:
	deck_pivot = get_node_or_null("Deck")
	front_truck = get_node_or_null("Deck/FrontTruck")
	rear_truck = get_node_or_null("Deck/RearTruck")
	wheel_fl = get_node_or_null("Deck/FrontTruck/Axle/Wheel_FL")
	wheel_fr = get_node_or_null("Deck/FrontTruck/Axle/Wheel_FR")
	wheel_bl = get_node_or_null("Deck/RearTruck/Axle/Wheel_BL")
	wheel_br = get_node_or_null("Deck/RearTruck/Axle/Wheel_BR")

## Updates wheel roll based on linear distance traveled and carving tilt from steering input
func update_skate(speed: float, turn_input: float, delta: float) -> void:
	if deck_pivot == null:
		_cache_nodes()
		
	# 1. Roll the wheels proportional to ground speed (v = omega * r => d_theta = v * dt / r)
	if absf(speed) > 0.01:
		var delta_rot: float = (speed / wheel_radius) * delta
		wheel_rotation += delta_rot
		_apply_wheel_rotation(wheel_rotation)
	
	# 2. Steer tilt / Carving physics
	var target_tilt: float = -turn_input * max_steer_tilt
	current_tilt = lerpf(current_tilt, target_tilt, tilt_lerp_speed * delta)
	if deck_pivot:
		deck_pivot.rotation_degrees.z = current_tilt
		# Slight truck pivot into the turn (bushing compression)
		if front_truck:
			front_truck.rotation_degrees.y = turn_input * 4.0
		if rear_truck:
			rear_truck.rotation_degrees.y = -turn_input * 4.0

func _apply_wheel_rotation(rot: float) -> void:
	if wheel_fl:
		wheel_fl.rotation.x = rot
	if wheel_fr:
		wheel_fr.rotation.x = rot
	if wheel_bl:
		wheel_bl.rotation.x = rot
	if wheel_br:
		wheel_br.rotation.x = rot

## Customizes the graphic color of the deck underside
func set_deck_graphic_color(color: Color) -> void:
	var graphic_mesh := get_node_or_null("Deck/GraphicSide") as MeshInstance3D
	if graphic_mesh and graphic_mesh.material_override is ShaderMaterial:
		(graphic_mesh.material_override as ShaderMaterial).set_shader_parameter("base_color", color)
		(graphic_mesh.material_override as ShaderMaterial).set_shader_parameter("shadow_color", color.darkened(0.3))
