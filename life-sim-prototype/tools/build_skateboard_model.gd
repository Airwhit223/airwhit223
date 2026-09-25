extends SceneTree
## Generates res://equipment/skateboard.tscn with 3D deck, kicktails, trucks, and rollable wheels.
## Run with:
##   Godot --path <project> -s res://tools/build_skateboard_model.gd

const TOON := "res://world/shaders/toon_world.gdshader"

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var root := Node3D.new()
	root.name = "Skateboard"
	root.set_script(load("res://equipment/skateboard.gd"))

	# Materials
	var m_grip := _make_mat(Color("#24252A"), Color("#18191C")) # Charcoal grip tape
	var m_deck_edge := _make_mat(Color("#D4A26A"), Color("#9E7245")) # 7-ply maple core
	var m_graphic := _make_mat(Color("#3598DC"), Color("#205F8B")) # Vibrant graphic bottom
	var m_graphic_accent := _make_mat(Color("#E74C3C"), Color("#9B2B20")) # Red accent graphic
	var m_truck := _make_mat(Color("#7F8C8D"), Color("#515A5B")) # Cast aluminum hanger
	var m_baseplate := _make_mat(Color("#34495E"), Color("#212F3D")) # Dark iron baseplate
	var m_bushing := _make_mat(Color("#E67E22"), Color("#A05313")) # Orange rubber bushing
	var m_wheel := _make_mat(Color("#F5F0E6"), Color("#BCB4A4")) # Off-white urethane
	var m_bearing := _make_mat(Color("#1A1A1A"), Color("#0D0D0D")) # Bearing center cap

	var deck := Node3D.new()
	deck.name = "Deck"
	root.add_child(deck)
	deck.owner = root

	# 1. Main Deck Center (0.44m long, 0.22m wide, 0.014m thick)
	var center_mesh := _make_box("CenterPlank", Vector3(0.22, 0.014, 0.44), Vector3(0, 0.05, 0), m_deck_edge)
	deck.add_child(center_mesh)
	center_mesh.owner = root

	var grip_center := _make_box("GripCenter", Vector3(0.21, 0.002, 0.438), Vector3(0, 0.0575, 0), m_grip)
	deck.add_child(grip_center)
	grip_center.owner = root

	var graphic_center := _make_box("GraphicSide", Vector3(0.21, 0.002, 0.438), Vector3(0, 0.0425, 0), m_graphic)
	deck.add_child(graphic_center)
	graphic_center.owner = root

	# Graphic stripe
	var stripe := _make_box("GraphicStripe", Vector3(0.06, 0.0022, 0.438), Vector3(0, 0.0424, 0), m_graphic_accent)
	deck.add_child(stripe)
	stripe.owner = root

	# 2. Nose Kicktail (angled +14 degrees upward)
	var nose := Node3D.new()
	nose.name = "NoseKick"
	nose.position = Vector3(0, 0.05, 0.22)
	nose.rotation_degrees.x = -13.5
	deck.add_child(nose)
	nose.owner = root

	var nose_mesh := _make_box("NoseMesh", Vector3(0.21, 0.014, 0.16), Vector3(0, 0, 0.08), m_deck_edge)
	nose.add_child(nose_mesh)
	nose_mesh.owner = root

	var nose_grip := _make_box("NoseGrip", Vector3(0.20, 0.002, 0.158), Vector3(0, 0.0075, 0.08), m_grip)
	nose.add_child(nose_grip)
	nose_grip.owner = root

	var nose_graphic := _make_box("NoseGraphic", Vector3(0.20, 0.002, 0.158), Vector3(0, -0.0075, 0.08), m_graphic)
	nose.add_child(nose_graphic)
	nose_graphic.owner = root

	# 3. Tail Kicktail (angled +14 degrees upward)
	var tail := Node3D.new()
	tail.name = "TailKick"
	tail.position = Vector3(0, 0.05, -0.22)
	tail.rotation_degrees.x = 13.5
	deck.add_child(tail)
	tail.owner = root

	var tail_mesh := _make_box("TailMesh", Vector3(0.21, 0.014, 0.16), Vector3(0, 0, -0.08), m_deck_edge)
	tail.add_child(tail_mesh)
	tail_mesh.owner = root

	var tail_grip := _make_box("TailGrip", Vector3(0.20, 0.002, 0.158), Vector3(0, 0.0075, -0.08), m_grip)
	tail.add_child(tail_grip)
	tail_grip.owner = root

	var tail_graphic := _make_box("TailGraphic", Vector3(0.20, 0.002, 0.158), Vector3(0, -0.0075, -0.08), m_graphic)
	tail.add_child(tail_graphic)
	tail_graphic.owner = root

	# 4. Front & Rear Trucks with Rolling Wheels
	_build_truck(root, deck, "FrontTruck", Vector3(0, 0.042, 0.16), m_baseplate, m_truck, m_bushing, m_wheel, m_bearing, false)
	_build_truck(root, deck, "RearTruck", Vector3(0, 0.042, -0.16), m_baseplate, m_truck, m_bushing, m_wheel, m_bearing, true)

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://equipment/skateboard.tscn")
	print("SKATEBOARD_BUILD done: res://equipment/skateboard.tscn created!")
	quit()

func _build_truck(root: Node3D, deck: Node3D, truck_name: String, pos: Vector3, m_base: Material, m_truck: Material, m_bushing: Material, m_wheel: Material, m_bearing: Material, is_rear: bool) -> void:
	var truck := Node3D.new()
	truck.name = truck_name
	truck.position = pos
	deck.add_child(truck)
	truck.owner = root

	# Baseplate (mounts under deck)
	var base := _make_box("Baseplate", Vector3(0.07, 0.008, 0.09), Vector3(0, -0.004, 0), m_base)
	truck.add_child(base)
	base.owner = root

	# Kingpin + Bushings
	var bushing := _make_cyl("Bushing", 0.016, 0.016, 0.018, Vector3(0, -0.015, 0), m_bushing, Vector3.ZERO)
	truck.add_child(bushing)
	bushing.owner = root

	# Axle node (spins with steer pivot)
	var axle := Node3D.new()
	axle.name = "Axle"
	axle.position = Vector3(0, -0.024, 0)
	truck.add_child(axle)
	axle.owner = root

	# Hanger
	var hanger := _make_box("Hanger", Vector3(0.18, 0.016, 0.02), Vector3.ZERO, m_truck)
	axle.add_child(hanger)
	hanger.owner = root

	# Left and Right Wheels
	var prefix := "BL" if is_rear else "FL"
	var prefix_r := "BR" if is_rear else "FR"
	_build_wheel(root, axle, "Wheel_" + prefix, Vector3(-0.095, 0, 0), m_wheel, m_bearing)
	_build_wheel(root, axle, "Wheel_" + prefix_r, Vector3(0.095, 0, 0), m_wheel, m_bearing)

func _build_wheel(root: Node3D, axle: Node3D, wheel_name: String, pos: Vector3, m_wheel: Material, m_bearing: Material) -> void:
	var wheel_pivot := Node3D.new()
	wheel_pivot.name = wheel_name
	wheel_pivot.position = pos
	axle.add_child(wheel_pivot)
	wheel_pivot.owner = root

	# Wheel body (cylinder oriented along X axis)
	var wheel_mesh := _make_cyl("Mesh", 0.035, 0.035, 0.028, Vector3.ZERO, m_wheel, Vector3(0, 0, 90))
	wheel_pivot.add_child(wheel_mesh)
	wheel_mesh.owner = root

	# Bearing center cap
	var bearing := _make_cyl("Bearing", 0.014, 0.014, 0.0285, Vector3.ZERO, m_bearing, Vector3(0, 0, 90))
	wheel_pivot.add_child(bearing)
	bearing.owner = root

func _make_box(n_name: String, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n_name
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	return mi

func _make_cyl(n_name: String, rt: float, rb: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n_name
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 16
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	return mi

func _make_mat(base_c: Color, shadow_c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	m.set_shader_parameter("base_color", base_c)
	m.set_shader_parameter("shadow_color", shadow_c)
	m.set_shader_parameter("line_mode", 0)
	return m
