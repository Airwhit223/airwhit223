class_name DangerZone
extends Area3D

@export var zone_id: String = "wooded_ruins"

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		AdventureManager.enter_danger_zone(zone_id)
		body.current_zone = zone_id

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		AdventureManager.leave_danger_zone(zone_id)
		if body.current_zone == zone_id:
			body.current_zone = ""
