class_name PressurePlate
extends Area3D
## Dungeon floor pressure plate activating gates and secret doors.

signal pressed()
signal released()

@export var is_locked_down: bool = false
var bodies_on_plate: int = 0
var plate_mesh: Node3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	plate_mesh = get_node_or_null("PlateMesh")

func _on_body_entered(b: Node) -> void:
	bodies_on_plate += 1
	if bodies_on_plate == 1:
		if plate_mesh:
			plate_mesh.position.y = -0.05
		pressed.emit()

func _on_body_exited(b: Node) -> void:
	bodies_on_plate = maxi(0, bodies_on_plate - 1)
	if bodies_on_plate == 0 and not is_locked_down:
		if plate_mesh:
			plate_mesh.position.y = 0.0
		released.emit()
