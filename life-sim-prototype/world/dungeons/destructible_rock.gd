class_name DestructibleRock
extends StaticBody3D
## Destructible boulder / cracked cave barrier broken by Ground Smash or heavy damage.

signal rock_broken(pos: Vector3)

@export var max_durability: int = 50
var current_durability: int = 50
var is_broken: bool = false

func _ready() -> void:
	add_to_group("destructible")
	current_durability = max_durability

func break_rock(damage: int) -> void:
	if is_broken:
		return
	current_durability -= damage
	if current_durability <= 0:
		is_broken = true
		rock_broken.emit(global_position)
		# Hide visual and disable collision
		visible = false
		for child in get_children():
			if child is CollisionShape3D:
				child.disabled = true
		# Clean up after sound/particles
		queue_free()

func take_damage(amount: int, _from_pos: Vector3 = Vector3.ZERO) -> void:
	break_rock(amount)
