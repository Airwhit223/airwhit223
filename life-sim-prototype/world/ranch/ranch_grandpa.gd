class_name RanchGrandpa
extends Interactable
## Grandpa on the barn porch (placeholder figure until he gets a kit character). Around on most shift days; talking
## to him gives a line from Ranch.grandpa_line() - remembers your last shift through JobManager.employer_remark().

var ranch                          # Ranch

func _ready() -> void:
	super._ready()
	var col := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(1.2, 2.0, 1.2); col.shape = sh
	col.position.y = 1.0
	add_child(col)
	var body := MeshInstance3D.new(); var cap := CapsuleMesh.new(); cap.radius = 0.32; cap.height = 1.6; body.mesh = cap
	body.position.y = 0.8
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.35, 0.45, 0.6); body.material_override = m
	add_child(body)
	var hat := MeshInstance3D.new(); var hb := CylinderMesh.new(); hb.top_radius = 0.22; hb.bottom_radius = 0.42; hb.height = 0.22
	hat.mesh = hb; hat.position.y = 1.72
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.85, 0.75, 0.45); hat.material_override = hm
	add_child(hat)
	var l := Label3D.new(); l.text = "Grandpa"; l.font_size = 36; l.pixel_size = 0.004; l.position.y = 2.15
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.outline_size = 8
	add_child(l)

func get_prompt() -> String:
	return "Talk to Grandpa"

func interact(_player: Node) -> void:
	if ranch:
		EventBus.fire("hud_message", {"text": "Grandpa: \"%s\"" % ranch.grandpa_line()})

func set_present(on: bool) -> void:
	visible = on
	monitorable = on
