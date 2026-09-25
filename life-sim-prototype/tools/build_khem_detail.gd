extends SceneTree
## Landscape detail for the Kingdom of Khem, read off the drawn references in
## docs/reference_images/gameplay_targets (khem_mudbrick_village, khem_plaza_beastfolk, desert_nomad_campfire,
## khem_dune_sandboarding). The built region had the monuments but none of the lived-in middle: no statues
## flanking the approach, no banners, no village, no market, no camp out in the dunes.
##
## This is an ADDITIVE layer in world/detail/, not an edit to rolling_tides_world.tscn - that file comes from the
## Antigravity copy and gets re-synced, which would wipe anything written into it.
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --path . -s res://tools/build_khem_detail.gd

const OUT := "res://world/detail/"
const MATS := "res://world/rolling_tides_world/materials/"
const TOON := "res://world/shaders/toon_world.gdshader"

## Sand-coloured walls on sand-coloured ground vanish: the quarter needs its own value, darker and warmer than
## the dune it stands on. base, shadow, line_mode, line_spacing
const LOCAL_PALETTE := {
	"mudbrick_wall": ["#C98A52", "#8A5527", 3, 0.55],
	"mudbrick_parapet": ["#B2763F", "#77461F", 0, 0.0],
	"mudbrick_shade": ["#E0B27A", "#9C6B35", 0, 0.0],
}

## Landmarks already in the world, for reference:
##   Great Pyramid (275, -220)   obelisk avenue (235..295, -165)   temple (255, -185)
##   oasis (195, -145)           bazaar (205, -120)                Anubis watchpoint (255, -138)
const PLAZA := Vector3(258, 0, -190)

var M := {}

func _initialize() -> void:
	_build.call_deferred()

func _m(name_: String) -> Material:
	if not M.has(name_):
		M[name_] = load(MATS + name_ + ".tres")
	return M[name_]

func _local_materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "materials"))
	for key in LOCAL_PALETTE:
		var p: Array = LOCAL_PALETTE[key]
		var m := ShaderMaterial.new()
		m.shader = load(TOON)
		m.set_shader_parameter("base_color", Color(p[0]))
		m.set_shader_parameter("shadow_color", Color(p[1]))
		m.set_shader_parameter("line_mode", p[2])
		if p[3] > 0.0:
			m.set_shader_parameter("line_spacing", p[3])
		if p[2] > 0:
			m.set_shader_parameter("line_color", Color(p[1]).darkened(0.4))
		ResourceSaver.save(m, OUT + "materials/%s.tres" % key, ResourceSaver.FLAG_CHANGE_PATH)
		M[key] = load(OUT + "materials/%s.tres" % key)

func _box(parent: Node3D, n: String, pos: Vector3, size: Vector3, mat: Material, yaw := 0.0, collide := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	mi.material_override = mat
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mi.add_child(body)
	return mi

func _shape(parent: Node3D, n: String, pos: Vector3, mesh: Mesh, mat: Material, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cone(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	return c

## A seated colossus: the references put two of these either side of every approach, and they carry the scale.
func _colossus(parent: Node3D, n: String, pos: Vector3, yaw: float) -> void:
	var s := Node3D.new(); s.name = n; s.position = pos; s.rotation.y = yaw
	s.scale = Vector3(0.55, 0.55, 0.55)      # matched to the pyramids as built, not to the reference art
	parent.add_child(s)
	var stone := _m("pyramid_limestone")
	_box(s, "Plinth", Vector3(0, 1.5, 0), Vector3(9, 3, 11), stone)
	_box(s, "Legs", Vector3(0, 4.0, 2.2), Vector3(6.5, 2.2, 6.0), stone)
	_box(s, "Torso", Vector3(0, 7.6, -0.6), Vector3(6.5, 5.6, 3.6), stone)
	_box(s, "ArmL", Vector3(-3.9, 5.6, 1.4), Vector3(1.6, 1.6, 6.2), stone)
	_box(s, "ArmR", Vector3(3.9, 5.6, 1.4), Vector3(1.6, 1.6, 6.2), stone)
	_box(s, "Head", Vector3(0, 11.4, -0.6), Vector3(3.4, 3.4, 3.4), stone)
	_box(s, "Nemes", Vector3(0, 12.0, -0.6), Vector3(4.6, 2.4, 4.4), _m("egypt_lapis"), 0.0, false)
	_box(s, "Beard", Vector3(0, 9.6, 1.2), Vector3(1.0, 2.2, 0.8), _m("egypt_gold"), 0.0, false)

## Banner poles - tall cloth with a sigil, the thing that makes a plaza read as inhabited.
func _banner(parent: Node3D, n: String, pos: Vector3, yaw: float) -> void:
	var b := Node3D.new(); b.name = n; b.position = pos; b.rotation.y = yaw; parent.add_child(b)
	_shape(b, "Pole", Vector3(0, 2.3, 0), CylinderMesh.new(), _m("palm_trunk"), Vector3(0.14, 2.3, 0.14))
	_box(b, "Cloth", Vector3(0, 3.3, 0.10), Vector3(1.25, 2.1, 0.08), _m("egypt_lapis"), 0.0, false)
	_box(b, "Sigil", Vector3(0, 3.5, 0.15), Vector3(0.55, 0.55, 0.05), _m("egypt_gold"), 0.0, false)
	_box(b, "Finial", Vector3(0, 4.7, 0), Vector3(0.26, 0.45, 0.26), _m("egypt_gold"), 0.0, false)

func _palm(parent: Node3D, n: String, pos: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var p := Node3D.new(); p.name = n; p.position = pos; parent.add_child(p)
	_shape(p, "Trunk", Vector3(0, height * 0.5, 0), CylinderMesh.new(), _m("palm_trunk"),
		Vector3(0.34, height * 0.5, 0.34), Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06)))
	for i in 7:
		var a := i * TAU / 7.0 + rng.randf_range(-0.18, 0.18)
		var droop := rng.randf_range(0.42, 0.72)          # fronds hang, they do not lie flat
		var reach := 1.5
		var frond := _shape(p, "Frond%d" % i, Vector3(sin(a) * reach, height - 0.15 - droop * 0.9, cos(a) * reach),
			BoxMesh.new(), _m("palm_frond"), Vector3(0.52, 0.10, 3.0), Vector3(droop, -a, 0))
		frond.rotation = Vector3(0, -a, 0)
		frond.rotate_object_local(Vector3.RIGHT, -droop)
	_shape(p, "Crown", Vector3(0, height - 0.1, 0), SphereMesh.new(), _m("palm_frond"), Vector3(0.5, 0.35, 0.5))

func _tent(parent: Node3D, n: String, pos: Vector3, yaw: float, mat: Material) -> void:
	var t := Node3D.new(); t.name = n; t.position = pos; t.rotation.y = yaw; parent.add_child(t)
	_shape(t, "Canopy", Vector3(0, 1.9, 0), _cone(3.4, 3.8), mat)
	_box(t, "Door", Vector3(0, 0.9, 2.5), Vector3(1.4, 1.8, 0.1), _m("egypt_lapis"), 0.0, false)

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_local_materials()
	var rng := RandomNumberGenerator.new(); rng.seed = 20260923
	var root := Node3D.new(); root.name = "KhemDetail"

	# --- the plaza in front of the temple: tiled floor, pool, banners, palms -------------------------------------
	var plaza := Node3D.new(); plaza.name = "TemplePlaza"; plaza.position = PLAZA; root.add_child(plaza)
	_box(plaza, "Paving", Vector3(0, 0.12, 0), Vector3(54, 0.24, 46), _m("stone_plain"))
	_box(plaza, "PavingInlay", Vector3(0, 0.26, 0), Vector3(30, 0.06, 24), _m("egypt_lapis"), 0.0, false)
	_shape(plaza, "ReflectingPool", Vector3(0, 0.3, 4.0), CylinderMesh.new(), _m("egypt_lapis"),
		Vector3(9.0, 0.22, 9.0))
	_shape(plaza, "PoolRim", Vector3(0, 0.22, 4.0), TorusMesh.new(), _m("pyramid_limestone"), Vector3(4.9, 1.2, 4.9))
	for i in 6:
		var a := i * TAU / 6.0
		_banner(plaza, "Banner%d" % (i + 1), Vector3(sin(a) * 22.0, 0, cos(a) * 18.0), -a)
	for i in 8:
		var a2 := i * TAU / 8.0 + 0.4
		_palm(plaza, "PlazaPalm%d" % (i + 1), Vector3(sin(a2) * 26.0, 0, cos(a2) * 21.0),
			rng.randf_range(6.0, 9.0), rng)

	# --- colossi flanking the pyramid approach ------------------------------------------------------------------
	var approach := Node3D.new(); approach.name = "PyramidApproach"; root.add_child(approach)
	_colossus(approach, "ColossusWest", Vector3(252, 0, -203), 0.0)
	_colossus(approach, "ColossusEast", Vector3(298, 0, -203), 0.0)
	_box(approach, "ProcessionalWay", Vector3(275, 0.1, -190), Vector3(16, 0.2, 60), _m("stone_plain"), 0.0, false)
	# sphinx-flanked avenue running down to the obelisks
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var step := float(i / 2)
		var pos := Vector3(275 + side * 11.0, 0, -176 + step * 9.0)
		var sx := Node3D.new(); sx.name = "Sphinx%d" % (i + 1); sx.position = pos; sx.rotation.y = -side * PI * 0.5
		sx.scale = Vector3(0.7, 0.7, 0.7)
		approach.add_child(sx)
		_box(sx, "Plinth", Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 5.2), _m("pyramid_limestone"))
		_box(sx, "Body", Vector3(0, 1.7, 0.4), Vector3(2.0, 1.6, 4.2), _m("pyramid_limestone"))
		_box(sx, "Head", Vector3(0, 3.0, -1.7), Vector3(1.5, 1.5, 1.5), _m("pyramid_limestone"))
		_box(sx, "Headdress", Vector3(0, 3.3, -1.7), Vector3(2.1, 1.1, 1.9), _m("egypt_gold"), 0.0, false)

	# --- the mudbrick village by the bazaar ---------------------------------------------------------------------
	var village := Node3D.new(); village.name = "MudbrickQuarter"; village.position = Vector3(203, 0, -113)
	root.add_child(village)
	var sand := _m("mudbrick_wall")
	for i in 9:
		var gx := float(i % 3) * 13.0 - 13.0
		var gz := float(i / 3) * 12.0 - 12.0
		var h := rng.randf_range(4.0, 8.0)
		var block := Node3D.new(); block.name = "Dwelling%d" % (i + 1)
		block.position = Vector3(gx + rng.randf_range(-1.6, 1.6), 0, gz + rng.randf_range(-1.6, 1.6))
		block.rotation.y = rng.randf_range(-0.2, 0.2)
		village.add_child(block)
		_box(block, "Walls", Vector3(0, h * 0.5, 0), Vector3(7.5, h, 7.0), sand)
		_box(block, "Parapet", Vector3(0, h + 0.4, 0), Vector3(8.1, 0.8, 7.6), _m("mudbrick_parapet"), 0.0, false)
		_box(block, "Door", Vector3(0, 1.2, 3.6), Vector3(1.4, 2.4, 0.2), _m("palm_trunk"), 0.0, false)
		if i % 2 == 0:      # the roof ladders and awnings in the reference
			_box(block, "Awning", Vector3(0, h - 0.6, 4.4), Vector3(6.0, 0.15, 2.4), _m("mudbrick_shade"), 0.0, false)
		if i % 3 == 0:
			_shape(block, "RoofJar", Vector3(2.0, h + 1.2, -1.4), SphereMesh.new(), _m("palm_trunk"),
				Vector3(0.6, 0.8, 0.6))
	# market row: stalls with striped cloth along the road into the quarter
	for i in 5:
		var stall := Node3D.new(); stall.name = "MarketStall%d" % (i + 1)
		stall.position = Vector3(-22.0, 0, -14.0 + i * 7.0)
		village.add_child(stall)
		_box(stall, "Counter", Vector3(0, 0.6, 0), Vector3(3.4, 1.2, 2.2), _m("palm_trunk"))
		_box(stall, "Canopy", Vector3(0, 2.6, 0), Vector3(4.6, 0.16, 3.4),
			_m("tent_cloth") if i % 2 == 0 else _m("egypt_lapis"), 0.0, false)
		for corner in [Vector3(-2.0, 1.3, -1.4), Vector3(2.0, 1.3, -1.4), Vector3(-2.0, 1.3, 1.4), Vector3(2.0, 1.3, 1.4)]:
			_shape(stall, "Post%d" % corner.x, corner, CylinderMesh.new(), _m("palm_trunk"), Vector3(0.1, 1.3, 0.1))

	# --- nomad camp out in the dunes ------------------------------------------------------------------------------
	var camp := Node3D.new(); camp.name = "NomadCamp"; camp.position = Vector3(172, 0, -168); root.add_child(camp)
	for i in 5:
		var a := i * TAU / 5.0
		_tent(camp, "Tent%d" % (i + 1), Vector3(sin(a) * 9.0, 0, cos(a) * 9.0), -a,
			_m("tent_cloth") if i % 2 == 0 else _m("egypt_lapis"))
	_box(camp, "FirePit", Vector3(0, 0.2, 0), Vector3(2.6, 0.4, 2.6), _m("stone_plain"), 0.0, false)
	_shape(camp, "Fire", Vector3(0, 1.0, 0), _cone(0.9, 1.8), _m("egypt_gold"))
	for i in 4:
		var a2 := i * TAU / 4.0 + 0.6
		_box(camp, "Rug%d" % (i + 1), Vector3(sin(a2) * 3.4, 0.08, cos(a2) * 3.4), Vector3(2.6, 0.06, 1.7),
			_m("egypt_lapis"), -a2, false)
	for i in 3:
		_palm(camp, "CampPalm%d" % (i + 1), Vector3(-14.0 + i * 6.0, 0, -13.0), rng.randf_range(5.0, 7.5), rng)

	# --- oasis planting, so the water in the dunes reads from a distance -------------------------------------------
	var oasis := Node3D.new(); oasis.name = "OasisPlanting"; oasis.position = Vector3(195, 0, -145); root.add_child(oasis)
	for i in 10:
		var a3 := i * TAU / 10.0 + 0.25
		_palm(oasis, "OasisPalm%d" % (i + 1), Vector3(sin(a3) * 13.0, 0, cos(a3) * 11.0),
			rng.randf_range(6.5, 10.0), rng)

	for child in root.get_children():
		_own(child, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed"); quit(1); return
	var err := ResourceSaver.save(packed, OUT + "khem_detail.tscn", ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("save failed %d" % err); quit(1); return
	print("KHEM DETAIL built: ", _count(root), " nodes -> ", OUT + "khem_detail.tscn")
	quit()

func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)

func _count(n: Node) -> int:
	var c := 1
	for child in n.get_children():
		c += _count(child)
	return c
