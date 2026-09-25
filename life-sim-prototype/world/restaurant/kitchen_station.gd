class_name KitchenStation
extends Interactable
## One spot in the restaurant kitchen (pantry bin, prep board, grill, fryer, pot, plate counter, pass, trash).
## All behaviour lives in the Kitchen; a station only knows what it is and draws itself as a placeholder block.

var kitchen                       # Kitchen
var kind := ""                    # pantry / board / grill / fryer / pot / plate / pass / trash
var param := ""                   # pantry: ingredient id
var label: Label3D
var slot_meshes: Array[MeshInstance3D] = []

func setup(k, station_kind: String, station_param := "", title := "", color := Color(0.6, 0.6, 0.6), size := Vector3(1.0, 0.9, 0.8)) -> void:
	kitchen = k
	kind = station_kind
	param = station_param
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.4, 0.6, 0.4)
	col.shape = shape
	col.position.y = size.y * 0.5
	add_child(col)
	var body := StaticBody3D.new()
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = size
	bcol.shape = bshape
	bcol.position.y = size.y * 0.5
	body.add_child(bcol)
	add_child(body)
	# A real prop where one exists (props/restaurant/), the coloured placeholder block where one does not. The
	# collision box above is unchanged either way, so interaction does not depend on the art.
	var prop: Node3D = FoodProps.spawn(self, FoodProps.station_scene(station_kind), true)
	if prop == null:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.position.y = size.y * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.material_override = mat
		add_child(mesh)
	elif station_kind == "pantry" and param != "":
		# a pantry bin shows what is in it
		var sample: Node3D = FoodProps.spawn(self, FoodProps.ingredient_scene(param))
		if sample:
			sample.position.y = size.y
	if prop == null and station_kind == "pantry" and param != "":
		var on_top: Node3D = FoodProps.spawn(self, FoodProps.ingredient_scene(param))
		if on_top:
			on_top.position.y = size.y
	label = Label3D.new()
	label.text = title
	label.font_size = 36
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = size.y + 0.35
	label.outline_size = 8
	add_child(label)

## What is on the grill or in the fryer right now — the actual food model where there is one, tinted by doneness
## so raw / cooked / burnt still reads at a glance.
var _slot_props: Array = []
func show_slot(i: int, item: Dictionary) -> void:
	while slot_meshes.size() <= i:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.22, 0.06, 0.22)
		m.mesh = b
		m.material_override = StandardMaterial3D.new()
		m.position = Vector3(-0.25 + 0.5 * slot_meshes.size(), 0.95, 0)
		add_child(m)
		slot_meshes.append(m)
		_slot_props.append(null)
	var want := String(item.get("id", ""))
	if want != "" and _slot_props[i] == null:
		var food: Node3D = FoodProps.spawn(self, FoodProps.ingredient_scene(want))
		if food:
			food.position = slot_meshes[i].position
			_slot_props[i] = food
	if _slot_props[i] != null:
		var fp: Node3D = _slot_props[i]
		fp.visible = not item.is_empty()
		slot_meshes[i].visible = false
		if not item.is_empty():
			# The toon material paints from vertex colours, so doneness is a multiply on albedo: the food keeps its
			# outline and its own colours and simply darkens as it cooks and then chars.
			var tint := Color(1, 1, 1)
			match String(item.get("state", "")):
				"cooked": tint = Color(0.80, 0.64, 0.50) if not item.get("well", false) else Color(0.60, 0.44, 0.30)
				"burnt": tint = Color(0.24, 0.19, 0.16)
			for mi: MeshInstance3D in fp.find_children("*", "MeshInstance3D", true, false):
				var m := mi.material_override as StandardMaterial3D
				if m == null:
					continue
				if not m.resource_local_to_scene:
					m = m.duplicate() as StandardMaterial3D
					m.resource_local_to_scene = true
					mi.material_override = m
				m.albedo_color = tint
		return
	var mm: MeshInstance3D = slot_meshes[i]
	mm.visible = not item.is_empty()
	if item.is_empty():
		return
	var c := Color(0.8, 0.25, 0.25)
	match String(item.get("state", "")):
		"cooked": c = Color(0.55, 0.33, 0.15) if not item.get("well", false) else Color(0.4, 0.22, 0.1)
		"burnt": c = Color(0.08, 0.06, 0.05)
	if item.get("id") in ["potato", "fries"]:
		c = Color(0.95, 0.8, 0.3) if item.get("state") == "cooked" else (Color(0.2, 0.15, 0.05) if item.get("state") == "burnt" else Color(0.9, 0.9, 0.7))
	(mm.material_override as StandardMaterial3D).albedo_color = c

func get_prompt() -> String:
	return kitchen.prompt_for(self) if kitchen else "..."

func interact(player: Node) -> void:
	if kitchen:
		kitchen.use(self, player)
