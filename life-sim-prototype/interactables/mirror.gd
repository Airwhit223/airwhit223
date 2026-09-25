class_name Mirror
extends Interactable
## A standing mirror at the player's home: reopens the character creator so a look can be changed later.
## Hair length still comes from the growth system (a barber or stylist), so the mirror is about everything else.

func _ready() -> void:
	super._ready()
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	_build_visual()

func get_prompt() -> String:
	return "Change Your Look"

func interact(player: Node) -> void:
	if player.has_method("open_creator"):
		player.open_creator(true, self)

func _build_visual() -> void:
	if get_child_count() > 0:
		return
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 2.0, 0.6)
	collision.shape = shape
	collision.position.y = 1.0
	add_child(collision)

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.36, 0.24, 0.16)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.68, 0.76, 0.82)
	glass.metallic = 0.6
	glass.roughness = 0.1

	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.9, 1.9, 0.12)
	frame.mesh = frame_mesh
	frame.position = Vector3(0, 1.0, 0)
	frame.material_override = frame_material
	add_child(frame)

	var pane := MeshInstance3D.new()
	var pane_mesh := BoxMesh.new()
	pane_mesh.size = Vector3(0.74, 1.7, 0.04)
	pane.mesh = pane_mesh
	pane.position = Vector3(0, 1.0, -0.07)
	pane.material_override = glass
	add_child(pane)

	var label := Label3D.new()
	label.text = "MIRROR"
	label.font_size = 28
	label.outline_size = 6
	label.position = Vector3(0, 2.1, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
