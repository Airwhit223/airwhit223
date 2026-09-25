class_name ElementalBrazier
extends StaticBody3D
## Brazier that lights with fire spells/torches and douses with ice.

signal lit()
signal extinguished()

@export var is_lit: bool = false
var fire_light: OmniLight3D
var fire_mesh: Node3D

func _ready() -> void:
	add_to_group("elemental_target")
	fire_light = get_node_or_null("FireLight")
	fire_mesh = get_node_or_null("FireMesh")
	_update_visuals()

func on_elemental_hit(element: String, _hit_pos: Vector3) -> void:
	if element == "fire" and not is_lit:
		is_lit = true
		_update_visuals()
		lit.emit()
	elif element == "ice" and is_lit:
		is_lit = false
		_update_visuals()
		extinguished.emit()

func _update_visuals() -> void:
	if fire_light:
		fire_light.visible = is_lit
	if fire_mesh:
		fire_mesh.visible = is_lit
