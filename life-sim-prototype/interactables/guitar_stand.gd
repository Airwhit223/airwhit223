class_name GuitarStand
extends Interactable
## A world-space invitation into the tiny rhythm activity. The challenge is
## an overlay, but it starts and ends from the same continuous neighborhood.

func _ready() -> void:
	super._ready()
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	_build_visual()

func get_prompt() -> String:
	var player = WorldState.player
	if player and player.equipment.get_equipped("hand_l") and player.equipment.get_equipped("hand_l").id == "acoustic_guitar":
		return "Practice Guitar"
	return "Take Guitar & Practice"

## Hands the player the real inventory guitar (same item the wheel selects),
## then starts a set — so the stand is just a convenient spot, not the only way.
func interact(player: Node) -> void:
	if player.has_method("select_hand_tool"):
		player.select_hand_tool("acoustic_guitar", false)
		player.try_play_guitar()

func _build_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.9, 0.8)
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.72, 0.24, 0.08)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.05)

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 0.7
	body.mesh = body_mesh
	body.scale = Vector3(0.75, 1.0, 0.24)
	body.position = Vector3(0, 0.62, 0)
	body.rotation.z = -0.12
	body.material_override = wood
	add_child(body)

	var neck := MeshInstance3D.new()
	var neck_mesh := BoxMesh.new()
	neck_mesh.size = Vector3(0.13, 1.2, 0.08)
	neck.mesh = neck_mesh
	neck.position = Vector3(0.12, 1.35, 0)
	neck.rotation.z = -0.12
	neck.material_override = dark
	add_child(neck)

	var label := Label3D.new()
	label.text = "GUITAR\n[E] Play"
	label.font_size = 34
	label.outline_size = 7
	label.position = Vector3(0, 2.25, 0)
	add_child(label)

