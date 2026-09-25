class_name LocationZone
extends Area3D
## Marks a named area of the neighborhood (the court, the gym...) so the
## player's current_zone can drive contextual invites — e.g. inviting an NPC
## while standing on the court proposes basketball instead of a generic hangout.

@export var location_id: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		body.enter_zone(location_id)

func _on_body_exited(body) -> void:
	if body.is_in_group("player"):
		body.exit_zone(location_id)
