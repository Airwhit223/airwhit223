extends SceneTree
## Builds Starter Street (docs/STARTER_STREET.md) — materials, every prop as its own reusable scene, the house, the
## shop, the ground, and world/starter_street/starter_street.tscn that places them.
##
##   Godot --path <project> -s res://tools/build_starter_street.gd
##
## Run it WITHOUT --headless: the headless renderer drops MultiMesh instance data (grass tufts, curbs, stones) and
## shader parameter defaults when saving.
##
## Re-run after changing anything here. Hand edits to the generated .tscn files are overwritten, so layout and prop
## changes belong in this file.
##
## Coordinates: +X east, -Z north (the house is north of the road, the shop south). Every prop is built facing +Z,
## with its origin on the ground at its centre (fence sections: at the left post).

const DIR := "res://world/starter_street/"
const TOON := "res://world/shaders/toon_world.gdshader"

## The spec's 7-colour palette (lit, shadow), plus the few accents the spec names (door, shutters, pot, blossom,
## cream shop front, glow cards). Shadow tones for accents are the lit tone darkened ~30%, as the spec does for the
## awning.
const PALETTE := {
	"warm_wood": ["#C4956A", "#8B6842", 0, 0.0],
	"wood_planks": ["#C4956A", "#8B6842", 1, 0.22],     # house + shop siding: horizontal planks
	"wood_crate": ["#C4956A", "#8B6842", 1, 0.15],
	"wood_barrel": ["#C4956A", "#8B6842", 2, 0.12],
	"roof_shingle": ["#7A6B5D", "#5A4E43", 4, 0.24],
	"roof_flat": ["#7A6B5D", "#5A4E43", 0, 0.0],
	"road_dirt": ["#D4B896", "#A8906E", 0, 0.0],
	"cobblestone": ["#B8A88C", "#8C7E68", 3, 0.62],
	"iron": ["#3E4450", "#2A2E36", 0, 0.0],
	"brick": ["#B8A88C", "#8C7E68", 1, 0.16],
	"stone_plain": ["#B8A88C", "#8C7E68", 0, 0.0],
	"living_green": ["#7DB84A", "#5A8A32", 0, 0.0],
	"awning_red": ["#E85D3A", "#A24129", 0, 0.0],
	"awning_yellow": ["#F4E04D", "#AB9D36", 0, 0.0],
	"awning_green": ["#4AA87D", "#347658", 0, 0.0],
	"metal": ["#6B7B8D", "#4A5663", 0, 0.0],
	"metal_ribbed": ["#6B7B8D", "#4A5663", 2, 0.09],
	"door_wood": ["#6B4E36", "#4B3726", 0, 0.0],
	"shutter_teal": ["#5D8A7A", "#416155", 0, 0.0],
	"cream": ["#F0E6D0", "#B8AD98", 0, 0.0],
	"terracotta": ["#C4704A", "#894E34", 0, 0.0],
	"blossom_pink": ["#F0A0B0", "#B8707F", 0, 0.0],
	"bark": ["#8B6842", "#5E4630", 0, 0.0],
	"chalkboard": ["#3A423C", "#2A302C", 0, 0.0],
	"paper_white": ["#F4EFE2", "#C4BDAE", 0, 0.0],
	"paper_blue": ["#9CC7E8", "#6E90AA", 0, 0.0],
	"window_glow": ["#FFD98A", "#D9A860", 0, 0.0],
	"lamp_glow": ["#FFE8B0", "#C9B07A", 0, 0.0],
}

var M := {}
## During _street(), placements are pulled toward the road so the lane reads dense like the target (the house side
## by SQUEEZE_N, the shop side by SQUEEZE_S). Props placed inside the house/shop scenes are local and not squeezed.
var squeeze_on := false
const SQUEEZE_N := 0.8
const SQUEEZE_S := 1.0
var rng := RandomNumberGenerator.new()
var scenes := {}

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	for sub in ["props", "materials", "meshes"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + sub))
	_materials()
	_small_props()
	_house()
	_shop()
	_street()
	print("STARTER_STREET_BUILD done: %d prop scenes" % scenes.size())
	quit()

# ------------------------------------------------------------------ materials
func _materials() -> void:
	for key in PALETTE:
		var p: Array = PALETTE[key]
		var m := ShaderMaterial.new()
		m.shader = load(TOON)
		m.set_shader_parameter("base_color", Color(p[0]))
		m.set_shader_parameter("shadow_color", Color(p[1]))
		m.set_shader_parameter("line_mode", p[2])
		if p[3] > 0.0:
			m.set_shader_parameter("line_spacing", p[3])
		if p[2] > 0:
			# detail lines a shade darker than the shadow tone, so they read softer than the outlines
			m.set_shader_parameter("line_color", Color(p[1]).darkened(0.5))
		if p[2] == 3:
			m.set_shader_parameter("gap_color", Color(PALETTE["road_dirt"][0]))
			m.set_shader_parameter("gap_shadow", Color(PALETTE["road_dirt"][1]))
		_save_res(m, DIR + "materials/%s.tres" % key)
		M[key] = load(DIR + "materials/%s.tres" % key)
	var blob := ShaderMaterial.new()
	blob.shader = load("res://world/shaders/blob_shadow.gdshader")
	_save_res(blob, DIR + "materials/blob_shadow.tres")
	M["blob"] = load(DIR + "materials/blob_shadow.tres")
	var ink := ShaderMaterial.new()
	ink.shader = load("res://world/shaders/ink_screen.gdshader")
	_save_res(ink, DIR + "materials/ink_screen.tres")
	M["ink"] = load(DIR + "materials/ink_screen.tres")
	var tuft := ShaderMaterial.new()
	tuft.shader = load("res://world/shaders/toon_world_noink.gdshader")
	tuft.set_shader_parameter("base_color", Color("#8CC455"))
	tuft.set_shader_parameter("shadow_color", Color("#4F7D2C"))
	tuft.render_priority = 2
	_save_res(tuft, DIR + "materials/grass_tuft.tres")
	M["grass_tuft"] = load(DIR + "materials/grass_tuft.tres")
	var sky := ShaderMaterial.new()
	sky.shader = load("res://world/shaders/toon_sky.gdshader")
	_save_res(sky, DIR + "materials/sky.tres")
	M["sky"] = load(DIR + "materials/sky.tres")

func _save_res(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [path, err])

# ------------------------------------------------------------------ mesh helpers
func _mi(parent: Node, name: String, mesh: Mesh, pos: Vector3, mat: String, rot := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.scale = scl
	if mat != "":
		node.material_override = M[mat]
	parent.add_child(node)
	return node

func box(parent: Node, name: String, size: Vector3, pos: Vector3, mat: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mi(parent, name, mesh, pos, mat, rot)

func cyl(parent: Node, name: String, r_top: float, r_bot: float, h: float, pos: Vector3, mat: String,
		rot := Vector3.ZERO, sides := 14) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	return _mi(parent, name, mesh, pos, mat, rot)

func ball(parent: Node, name: String, r: float, pos: Vector3, mat: String, scl := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mi(parent, name, mesh, pos, mat, Vector3.ZERO, scl)

func prism(parent: Node, name: String, size: Vector3, pos: Vector3, mat: String, lr := 0.5,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.left_to_right = lr
	return _mi(parent, name, mesh, pos, mat, rot)

## A round rod between two points.
func rod(parent: Node, name: String, a: Vector3, b: Vector3, r: float, mat: String) -> MeshInstance3D:
	var node := cyl(parent, name, r, r, a.distance_to(b), (a + b) * 0.5, mat, Vector3.ZERO, 8)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	node.basis = Basis(side, up, side.cross(up))
	return node

## A flat slab from edge `a` to edge `b` in the XY plane, `depth` along Z — roof planes, awning stripes.
func slab(parent: Node, name: String, a: Vector2, b: Vector2, depth: float, thick: float, overhang: float,
		mat: String, z := 0.0) -> MeshInstance3D:
	var dir := (b - a).normalized()
	var a2 := a - dir * overhang
	var normal := Vector2(-dir.y, dir.x)
	if normal.y < 0.0:
		normal = -normal
	var mid := (a2 + b) * 0.5 + normal * thick * 0.5
	return box(parent, name, Vector3(a2.distance_to(b), thick, depth), Vector3(mid.x, mid.y, z), mat,
		Vector3(0, 0, rad_to_deg(atan2(dir.y, dir.x))))

func blob(parent: Node, radius: float, strength := 0.3, pos := Vector3.ZERO) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(radius * 2.0, radius * 2.0)
	var node := _mi(parent, "BlobShadow", mesh, pos + Vector3(0, 0.015, 0), "blob")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if strength != 0.3:
		var m: ShaderMaterial = M["blob"].duplicate()
		m.set_shader_parameter("strength", strength)
		node.material_override = m

func body(name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	return b

func collide_box(b: Node, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = pos
	c.rotation_degrees = rot
	b.add_child(c)

func collide_cyl(b: Node, r: float, h: float, pos: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = pos
	b.add_child(c)

func instance(parent: Node, key: String, pos: Vector3, yaw := 0.0, name := "") -> Node3D:
	var node: Node3D = scenes[key].instantiate()
	if name != "":
		node.name = name
	node.position = squeeze(pos) if squeeze_on else pos
	node.rotation_degrees.y = yaw
	parent.add_child(node)
	return node

func save_scene(root: Node, key: String, folder := "props/") -> void:
	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var path := DIR + folder + key + ".tscn"
	_save_res(ps, path)
	root.free()
	scenes[key] = load(path)

func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		if c.scene_file_path == "":
			_own(c, owner)

# ------------------------------------------------------------------ small props
func _small_props() -> void:
	rng.seed = 20260918

	# --- street lamp: cylinder post + sphere lamp, warm omni at night (StreetLighting toggles the group)
	var lamp := body("StreetLamp")
	cyl(lamp, "Base", 0.12, 0.17, 0.35, Vector3(0, 0.175, 0), "iron", Vector3.ZERO, 8)
	cyl(lamp, "Post", 0.05, 0.06, 2.55, Vector3(0, 1.62, 0), "iron", Vector3.ZERO, 8)
	cyl(lamp, "Collar", 0.11, 0.07, 0.12, Vector3(0, 2.9, 0), "iron", Vector3.ZERO, 8)
	box(lamp, "LanternGlass", Vector3(0.24, 0.32, 0.24), Vector3(0, 3.12, 0), "lamp_glow")
	for cx in [-0.12, 0.12]:
		for cz in [-0.12, 0.12]:
			box(lamp, "LanternBar", Vector3(0.035, 0.36, 0.035), Vector3(cx, 3.12, cz), "iron")
	box(lamp, "LanternFloor", Vector3(0.3, 0.04, 0.3), Vector3(0, 2.95, 0), "iron")
	cyl(lamp, "Cap", 0.02, 0.24, 0.2, Vector3(0, 3.38, 0), "iron", Vector3(0, 45, 0), 4)
	ball(lamp, "Finial", 0.035, Vector3(0, 3.5, 0), "iron")
	var light := OmniLight3D.new()
	light.name = "StreetLampLight"
	light.position = Vector3(0, 3.0, 0)
	light.light_color = Color("#FFD070")
	light.light_energy = 2.4
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.visible = false
	light.add_to_group("street_lamp_light", true)
	lamp.add_child(light)
	collide_cyl(lamp, 0.15, 3.0, Vector3(0, 1.5, 0))
	blob(lamp, 0.35)
	save_scene(lamp, "street_lamp")

	# --- fire hydrant: rounded cylinder + nubs
	var hyd := body("FireHydrant")
	cyl(hyd, "Foot", 0.2, 0.21, 0.06, Vector3(0, 0.03, 0), "awning_red")
	cyl(hyd, "Barrel", 0.14, 0.15, 0.42, Vector3(0, 0.27, 0), "awning_red")
	cyl(hyd, "Band", 0.165, 0.165, 0.05, Vector3(0, 0.42, 0), "awning_red")
	ball(hyd, "Dome", 0.145, Vector3(0, 0.48, 0), "awning_red", Vector3(1, 0.7, 1))
	cyl(hyd, "TopNut", 0.035, 0.045, 0.08, Vector3(0, 0.6, 0), "metal", Vector3.ZERO, 6)
	cyl(hyd, "NubL", 0.055, 0.055, 0.12, Vector3(-0.18, 0.34, 0), "awning_red", Vector3(0, 0, 90), 8)
	cyl(hyd, "NubR", 0.055, 0.055, 0.12, Vector3(0.18, 0.34, 0), "awning_red", Vector3(0, 0, 90), 8)
	cyl(hyd, "NubFront", 0.07, 0.07, 0.1, Vector3(0, 0.3, 0.17), "metal", Vector3(90, 0, 0), 8)
	collide_cyl(hyd, 0.2, 0.64, Vector3(0, 0.32, 0))
	blob(hyd, 0.3)
	save_scene(hyd, "fire_hydrant")

	# --- trash can: ribbed cylinder with lid
	var can := body("TrashCan")
	cyl(can, "Can", 0.28, 0.24, 0.72, Vector3(0, 0.36, 0), "metal_ribbed")
	cyl(can, "Lid", 0.305, 0.305, 0.06, Vector3(0, 0.75, 0), "metal")
	cyl(can, "LidTop", 0.2, 0.28, 0.05, Vector3(0, 0.8, 0), "metal")
	box(can, "Handle", Vector3(0.14, 0.04, 0.04), Vector3(0, 0.85, 0), "metal")
	collide_cyl(can, 0.3, 0.85, Vector3(0, 0.42, 0))
	blob(can, 0.38)
	save_scene(can, "trash_can")

	# --- mailbox: box on a post, flag up
	var mail := body("Mailbox")
	box(mail, "Post", Vector3(0.09, 1.02, 0.09), Vector3(0, 0.51, 0), "warm_wood")
	box(mail, "Body", Vector3(0.24, 0.16, 0.46), Vector3(0, 1.1, 0.04), "metal")
	cyl(mail, "Top", 0.12, 0.12, 0.46, Vector3(0, 1.18, 0.04), "metal", Vector3(90, 0, 0), 12)
	box(mail, "Door", Vector3(0.25, 0.26, 0.02), Vector3(0, 1.14, 0.28), "metal")
	box(mail, "FlagArm", Vector3(0.02, 0.26, 0.03), Vector3(0.135, 1.24, -0.08), "awning_red")
	box(mail, "Flag", Vector3(0.02, 0.08, 0.12), Vector3(0.135, 1.34, -0.02), "awning_red")
	collide_box(mail, Vector3(0.3, 1.3, 0.5), Vector3(0, 0.65, 0))
	blob(mail, 0.25)
	save_scene(mail, "mailbox")

	# --- notice board: two posts, a board, a little roof, pinned paper cards
	var nb := body("NoticeBoard")
	for x in [-0.72, 0.72]:
		box(nb, "Post", Vector3(0.1, 1.55, 0.1), Vector3(x, 0.775, 0), "warm_wood")
	box(nb, "Board", Vector3(1.36, 0.82, 0.06), Vector3(0, 1.02, 0), "warm_wood")
	box(nb, "FrameTop", Vector3(1.46, 0.07, 0.09), Vector3(0, 1.45, 0), "door_wood")
	box(nb, "FrameBottom", Vector3(1.46, 0.07, 0.09), Vector3(0, 0.6, 0), "door_wood")
	slab(nb, "RoofL", Vector2(-0.85, 1.52), Vector2(0.0, 1.68), 0.28, 0.04, 0.0, "roof_flat")
	slab(nb, "RoofR", Vector2(0.85, 1.52), Vector2(0.0, 1.68), 0.28, 0.04, 0.0, "roof_flat")
	var cards := [["paper_white", Vector2(-0.42, 1.14), Vector2(0.26, 0.3)],
		["awning_yellow", Vector2(-0.08, 1.2), Vector2(0.22, 0.2)],
		["paper_blue", Vector2(0.3, 1.1), Vector2(0.28, 0.34)],
		["paper_white", Vector2(-0.3, 0.8), Vector2(0.3, 0.22)],
		["blossom_pink", Vector2(0.12, 0.82), Vector2(0.2, 0.24)],
		["paper_white", Vector2(0.46, 0.78), Vector2(0.18, 0.18)]]
	for i in cards.size():
		var c: Array = cards[i]
		box(nb, "Card%d" % i, Vector3(c[2].x, c[2].y, 0.01), Vector3(c[1].x, c[1].y, 0.036), c[0],
			Vector3(0, 0, rng.randf_range(-9.0, 9.0)))
	collide_box(nb, Vector3(1.6, 1.7, 0.2), Vector3(0, 0.85, 0))
	blob(nb, 0.8, 0.25)
	save_scene(nb, "notice_board")

	# --- bench: plank seat + backrest on legs; an NPC sit spot and the existing Bench interactable
	var bench := body("Bench")
	for z in [-0.14, 0.0, 0.14]:
		box(bench, "Seat", Vector3(1.5, 0.045, 0.12), Vector3(0, 0.45, z), "warm_wood")
	for y in [0.68, 0.84]:
		box(bench, "Back", Vector3(1.5, 0.1, 0.035), Vector3(0, y, -0.25 - (y - 0.68) * 0.2), "warm_wood",
			Vector3(-12, 0, 0))
	for x in [-0.66, 0.66]:
		box(bench, "Leg", Vector3(0.07, 0.45, 0.36), Vector3(x, 0.225, 0), "door_wood")
		box(bench, "BackPost", Vector3(0.07, 0.5, 0.05), Vector3(x, 0.68, -0.25), "door_wood", Vector3(-12, 0, 0))
		box(bench, "Arm", Vector3(0.07, 0.05, 0.42), Vector3(x, 0.64, -0.02), "door_wood")
	collide_box(bench, Vector3(1.55, 0.5, 0.45), Vector3(0, 0.25, 0))
	var sit := Area3D.new()
	sit.name = "BenchInteract"
	sit.set_script(load("res://interactables/bench.gd"))
	sit.collision_layer = 8
	sit.collision_mask = 0
	sit.monitoring = false
	sit.position = Vector3(0, 0.25, 0.3)
	collide_box(sit, Vector3(1.6, 1.0, 1.0), Vector3.ZERO)
	bench.add_child(sit)
	blob(bench, 0.9, 0.25)
	save_scene(bench, "bench")

	# --- bike rack: low metal hoops on two ground rails
	var rack := body("BikeRack")
	for z in [-0.18, 0.18]:
		rod(rack, "Rail", Vector3(-0.42, 0.03, z), Vector3(0.42, 0.03, z), 0.025, "metal")
	for x in [-0.3, 0.0, 0.3]:
		rod(rack, "HoopA", Vector3(x, 0.03, -0.18), Vector3(x, 0.56, -0.18), 0.022, "metal")
		rod(rack, "HoopB", Vector3(x, 0.03, 0.18), Vector3(x, 0.56, 0.18), 0.022, "metal")
		rod(rack, "HoopTop", Vector3(x, 0.56, -0.18), Vector3(x, 0.56, 0.18), 0.022, "metal")
	collide_box(rack, Vector3(0.9, 0.6, 0.45), Vector3(0, 0.3, 0))
	blob(rack, 0.55, 0.22)
	save_scene(rack, "bike_rack")

	# --- bicycle: two wheels, a diamond frame, seat and bars (rideable later)
	var bike := Node3D.new()
	bike.name = "Bicycle"
	var frame := Node3D.new()
	frame.name = "Frame"
	bike.add_child(frame)
	for x in [-0.5, 0.5]:
		var wheel := TorusMesh.new()
		wheel.inner_radius = 0.29
		wheel.outer_radius = 0.34
		wheel.rings = 20
		wheel.ring_segments = 6
		_mi(frame, "Wheel", wheel, Vector3(x, 0.34, 0), "chalkboard", Vector3(90, 0, 0))
		cyl(frame, "Hub", 0.03, 0.03, 0.08, Vector3(x, 0.34, 0), "metal", Vector3(90, 0, 0), 8)
	var rear := Vector3(-0.5, 0.34, 0)
	var bb := Vector3(-0.05, 0.3, 0)
	var seat := Vector3(-0.2, 0.8, 0)
	var head_t := Vector3(0.33, 0.82, 0)
	var head_b := Vector3(0.38, 0.6, 0)
	var front := Vector3(0.5, 0.34, 0)
	for pair in [[rear, seat], [rear, bb], [bb, seat], [seat, head_t], [bb, head_b], [head_t, head_b],
			[head_b, front]]:
		rod(frame, "Tube", pair[0], pair[1], 0.024, "awning_red")
	box(frame, "Saddle", Vector3(0.2, 0.05, 0.1), seat + Vector3(-0.02, 0.07, 0), "chalkboard")
	rod(frame, "Stem", head_t, head_t + Vector3(-0.03, 0.12, 0), 0.02, "metal")
	rod(frame, "Bars", head_t + Vector3(-0.03, 0.12, -0.24), head_t + Vector3(-0.03, 0.12, 0.24), 0.018, "metal")
	cyl(frame, "Crank", 0.06, 0.06, 0.05, bb, "metal", Vector3(90, 0, 0), 10)
	frame.rotation_degrees.x = 9.0          # it leans on the rack
	blob(bike, 0.6, 0.22)
	save_scene(bike, "bicycle")

	# --- fence section: 2 m of posts, rails and pickets; origin at the left post, runs along +X
	var fence := body("FenceSection")
	for x in [0.05, 1.95]:
		box(fence, "Post", Vector3(0.1, 1.08, 0.1), Vector3(x, 0.54, 0), "warm_wood")
		prism(fence, "PostCap", Vector3(0.12, 0.07, 0.12), Vector3(x, 1.115, 0), "warm_wood")
	for y in [0.3, 0.78]:
		box(fence, "Rail", Vector3(1.9, 0.07, 0.04), Vector3(1.0, y, -0.04), "warm_wood")
	var px := 0.2
	while px < 1.85:
		var h := 0.9 + rng.randf_range(-0.03, 0.03)
		box(fence, "Picket", Vector3(0.09, h, 0.03), Vector3(px, h * 0.5, 0.0), "warm_wood",
			Vector3(0, 0, rng.randf_range(-1.5, 1.5)))
		prism(fence, "PicketTip", Vector3(0.09, 0.07, 0.03), Vector3(px, h + 0.035, 0.0), "warm_wood")
		px += 0.2 + rng.randf_range(-0.012, 0.012)
	collide_box(fence, Vector3(2.0, 1.1, 0.14), Vector3(1.0, 0.55, 0))
	save_scene(fence, "fence_section")

	# --- fence gate: 1 m, hung on hinges and left ajar so the yard reads as open
	var gate := body("FenceGate")
	for x in [0.05, 0.95]:
		box(gate, "Post", Vector3(0.1, 1.15, 0.1), Vector3(x, 0.575, 0), "warm_wood")
		prism(gate, "PostCap", Vector3(0.12, 0.07, 0.12), Vector3(x, 1.185, 0), "warm_wood")
		collide_box(gate, Vector3(0.12, 1.15, 0.12), Vector3(x, 0.575, 0))
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(0.11, 0, 0)
	leaf.rotation_degrees.y = -58.0
	gate.add_child(leaf)
	for y in [0.3, 0.75]:
		box(leaf, "Rail", Vector3(0.78, 0.07, 0.04), Vector3(0.39, y, -0.04), "warm_wood")
	var brace := box(leaf, "Brace", Vector3(0.84, 0.06, 0.035), Vector3(0.39, 0.525, -0.04), "warm_wood",
		Vector3(0, 0, 33))
	brace.position.z = -0.05
	for i in 4:
		box(leaf, "Picket", Vector3(0.09, 0.88, 0.03), Vector3(0.08 + i * 0.21, 0.44 + 0.05, 0.0), "warm_wood")
		prism(leaf, "PicketTip", Vector3(0.09, 0.07, 0.03), Vector3(0.08 + i * 0.21, 0.965, 0.0), "warm_wood")
	for y in [0.3, 0.75]:
		box(gate, "Hinge", Vector3(0.1, 0.05, 0.03), Vector3(0.12, y, -0.05), "metal")
	save_scene(gate, "fence_gate")

	# --- garden plot: raised bed facing the road; the existing FarmPlot does the farming (its own soil sits
	# below this bed's dirt, so only its crops show)
	var garden := body("GardenPlot")
	for z in [-0.71, 0.71]:
		box(garden, "BoardLong", Vector3(2.0, 0.26, 0.08), Vector3(0, 0.13, z), "warm_wood")
	for x in [-0.96, 0.96]:
		box(garden, "BoardShort", Vector3(0.08, 0.26, 1.34), Vector3(x, 0.13, 0), "warm_wood")
	box(garden, "Dirt", Vector3(1.84, 0.2, 1.34), Vector3(0, 0.1, 0), "road_dirt")
	for z in [-0.4, 0.0, 0.4]:
		box(garden, "Furrow", Vector3(1.7, 0.035, 0.12), Vector3(0, 0.205, z), "road_dirt")
	collide_box(garden, Vector3(2.0, 0.26, 1.5), Vector3(0, 0.13, 0))
	var plot := Area3D.new()
	plot.name = "FarmPlot"
	plot.set_script(load("res://farming/farm_plot.gd"))
	plot.set("plot_id", "street_garden")
	plot.position = Vector3(0, 0.02, 0)
	garden.add_child(plot)
	save_scene(garden, "garden_plot")

	# --- potted plant (terracotta pot + green bush) and a flowering variant for the shop door
	for variant in ["potted_plant", "potted_flowers"]:
		var pot := Node3D.new()
		pot.name = variant.to_pascal_case()
		cyl(pot, "Pot", 0.15, 0.11, 0.2, Vector3(0, 0.1, 0), "terracotta")
		cyl(pot, "Rim", 0.165, 0.165, 0.05, Vector3(0, 0.2, 0), "terracotta")
		ball(pot, "Leaves", 0.16, Vector3(0, 0.3, 0), "living_green", Vector3(1, 0.85, 1))
		ball(pot, "Leaves2", 0.1, Vector3(0.1, 0.27, 0.05), "living_green")
		if variant == "potted_flowers":
			for i in 6:
				var a := i * TAU / 6.0 + 0.4
				ball(pot, "Flower%d" % i, 0.05, Vector3(cos(a) * 0.12, 0.36 + (i % 2) * 0.05, sin(a) * 0.12),
					"blossom_pink" if i % 2 == 0 else "awning_yellow")
		blob(pot, 0.22)
		save_scene(pot, variant)

	# --- porch chair
	var chair := body("PorchChair")
	box(chair, "Seat", Vector3(0.5, 0.06, 0.48), Vector3(0, 0.45, 0), "warm_wood")
	for x in [-0.21, 0.21]:
		for z in [-0.2, 0.2]:
			box(chair, "Leg", Vector3(0.05, 0.45, 0.05), Vector3(x, 0.225, z), "door_wood")
		box(chair, "BackPost", Vector3(0.05, 0.6, 0.05), Vector3(x, 0.78, -0.22), "door_wood", Vector3(-8, 0, 0))
	for y in [0.66, 0.82, 0.98]:
		box(chair, "Slat", Vector3(0.44, 0.07, 0.025), Vector3(0, y, -0.225 - (y - 0.66) * 0.14), "warm_wood",
			Vector3(-8, 0, 0))
	collide_box(chair, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0))
	blob(chair, 0.35)
	save_scene(chair, "porch_chair")

	var table := body("SideTable")
	cyl(table, "Top", 0.24, 0.24, 0.04, Vector3(0, 0.56, 0), "warm_wood", Vector3.ZERO, 18)
	cyl(table, "Stem", 0.035, 0.04, 0.52, Vector3(0, 0.28, 0), "door_wood")
	cyl(table, "Foot", 0.14, 0.16, 0.03, Vector3(0, 0.015, 0), "door_wood")
	cyl(table, "Mug", 0.04, 0.04, 0.08, Vector3(0.07, 0.62, 0.04), "cream", Vector3.ZERO, 10)
	collide_cyl(table, 0.25, 0.6, Vector3(0, 0.3, 0))
	blob(table, 0.3)
	save_scene(table, "side_table")

	var shoes := Node3D.new()
	shoes.name = "PorchShoes"
	for i in 2:
		var s := Node3D.new()
		s.name = "Shoe%d" % i
		s.position = Vector3(i * 0.15 - 0.075, 0, i * 0.04)
		s.rotation_degrees.y = [8.0, -14.0][i]
		shoes.add_child(s)
		box(s, "Sole", Vector3(0.11, 0.03, 0.27), Vector3(0, 0.015, 0), "cream")
		box(s, "Upper", Vector3(0.1, 0.07, 0.2), Vector3(0, 0.06, -0.03), "shutter_teal")
		ball(s, "Toe", 0.055, Vector3(0, 0.05, 0.08), "shutter_teal", Vector3(1, 0.7, 1.1))
	save_scene(shoes, "porch_shoes")

	# --- crates, barrel, chalkboard sandwich sign (shop front)
	var crate := body("Crate")
	box(crate, "Box", Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), "wood_crate")
	for x in [-0.29, 0.29]:
		for z in [-0.29, 0.29]:
			box(crate, "Corner", Vector3(0.06, 0.62, 0.06), Vector3(x, 0.31, z), "door_wood")
	collide_box(crate, Vector3(0.62, 0.62, 0.62), Vector3(0, 0.31, 0))
	blob(crate, 0.45)
	save_scene(crate, "crate")

	var barrel := body("Barrel")
	cyl(barrel, "Staves", 0.29, 0.29, 0.8, Vector3(0, 0.4, 0), "wood_barrel", Vector3.ZERO, 16)
	cyl(barrel, "Belly", 0.31, 0.31, 0.3, Vector3(0, 0.4, 0), "wood_barrel", Vector3.ZERO, 16)
	for y in [0.12, 0.68]:
		cyl(barrel, "Hoop", 0.305, 0.305, 0.045, Vector3(0, y, 0), "metal", Vector3.ZERO, 16)
	cyl(barrel, "Lid", 0.27, 0.27, 0.02, Vector3(0, 0.805, 0), "door_wood", Vector3.ZERO, 16)
	collide_cyl(barrel, 0.31, 0.8, Vector3(0, 0.4, 0))
	blob(barrel, 0.42)
	save_scene(barrel, "barrel")

	var sign := body("ChalkboardSign")
	for side in [1.0, -1.0]:
		var leaf2 := Node3D.new()
		leaf2.name = "FaceFront" if side > 0 else "FaceBack"
		leaf2.position = Vector3(0, 0.39, 0.09 * side)
		leaf2.rotation_degrees.x = -12.0 * side
		sign.add_child(leaf2)
		box(leaf2, "Frame", Vector3(0.56, 0.78, 0.035), Vector3.ZERO, "warm_wood")
		box(leaf2, "Board", Vector3(0.46, 0.62, 0.01), Vector3(0, 0.02, 0.02 * side), "chalkboard")
		if side > 0:
			var text := Label3D.new()
			text.name = "Chalk"
			text.text = "SKATE\nDecks & Gear\nOPEN"
			text.font_size = 26
			text.pixel_size = 0.0042
			text.modulate = Color("#F4EFE2")
			text.outline_size = 0
			text.shaded = false
			text.double_sided = false
			text.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			text.position = Vector3(0, 0.03, 0.04)
			leaf2.add_child(text)
	collide_box(sign, Vector3(0.6, 0.8, 0.4), Vector3(0, 0.4, 0))
	blob(sign, 0.4)
	save_scene(sign, "chalkboard_sign")

	# --- vegetation
	var tree := body("ShadeTree")
	cyl(tree, "Trunk", 0.22, 0.36, 2.5, Vector3(0, 1.25, 0), "bark")
	for i in 3:
		var a := i * TAU / 3.0 + 0.5
		cyl(tree, "Root%d" % i, 0.05, 0.16, 0.6, Vector3(cos(a) * 0.32, 0.12, sin(a) * 0.32), "bark",
			Vector3(sin(a) * 65.0, 0, -cos(a) * 65.0), 8)
	rod(tree, "BranchL", Vector3(0, 2.0, 0), Vector3(-0.9, 2.9, 0.2), 0.1, "bark")
	rod(tree, "BranchR", Vector3(0, 2.2, 0), Vector3(0.8, 3.0, -0.3), 0.09, "bark")
	var canopy := [[Vector3(0, 3.6, 0), 1.5], [Vector3(1.15, 3.25, 0.3), 1.1], [Vector3(-1.05, 3.35, -0.35), 1.15],
		[Vector3(0.3, 3.15, -1.15), 1.05], [Vector3(-0.4, 3.2, 1.05), 1.0], [Vector3(0.25, 4.45, 0.1), 1.0],
		[Vector3(-0.8, 4.2, 0.5), 0.8], [Vector3(0.9, 4.1, -0.5), 0.8]]
	for i in canopy.size():
		ball(tree, "Leaves%d" % i, canopy[i][1], canopy[i][0], "living_green")
	collide_cyl(tree, 0.38, 2.5, Vector3(0, 1.25, 0))
	blob(tree, 2.3, 0.22)
	save_scene(tree, "shade_tree")

	var bloss := body("BlossomTree")
	var trunk := cyl(bloss, "Trunk", 0.12, 0.2, 1.8, Vector3(0.05, 0.9, 0), "bark")
	trunk.rotation_degrees.z = -4.0
	var puffs := [[Vector3(0, 2.55, 0), 0.9, "living_green"], [Vector3(0.62, 2.35, 0.2), 0.6, "blossom_pink"],
		[Vector3(-0.58, 2.42, -0.2), 0.66, "living_green"], [Vector3(0.12, 3.05, 0.1), 0.6, "blossom_pink"],
		[Vector3(-0.2, 2.25, 0.62), 0.52, "blossom_pink"], [Vector3(0.32, 2.5, -0.62), 0.52, "living_green"],
		[Vector3(-0.45, 2.95, 0.25), 0.45, "blossom_pink"]]
	for i in puffs.size():
		ball(bloss, "Puff%d" % i, puffs[i][1], puffs[i][0], puffs[i][2])
	for i in 12:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		ball(bloss, "Bloom%d" % i, rng.randf_range(0.1, 0.16), Vector3(0, 2.6, 0) + dir * 0.92, "blossom_pink")
	collide_cyl(bloss, 0.22, 1.8, Vector3(0, 0.9, 0))
	blob(bloss, 1.4, 0.22)
	save_scene(bloss, "blossom_tree")

	var bush := Node3D.new()
	bush.name = "BushSmall"
	ball(bush, "Main", 0.36, Vector3(0, 0.27, 0), "living_green", Vector3(1, 0.78, 1))
	ball(bush, "Side", 0.25, Vector3(0.3, 0.2, 0.08), "living_green")
	ball(bush, "Side2", 0.23, Vector3(-0.26, 0.19, -0.1), "living_green")
	blob(bush, 0.55)
	save_scene(bush, "bush_small")

	var flowers := Node3D.new()
	flowers.name = "FlowerClump"
	for i in 7:
		var a := i * 2.4
		var r := 0.05 + 0.03 * i
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := rng.randf_range(0.22, 0.4)
		rod(flowers, "Stem%d" % i, base, base + Vector3(rng.randf_range(-0.04, 0.04), h, 0), 0.012, "living_green")
		ball(flowers, "Bloom%d" % i, 0.045, base + Vector3(0, h, 0), "blossom_pink")
	ball(flowers, "Leaves", 0.12, Vector3(0, 0.06, 0), "living_green", Vector3(1.3, 0.6, 1.3))
	save_scene(flowers, "flower_clump")

	# --- the tree line that closes the street off, like the reference's back row of trees
	var back := Node3D.new()
	back.name = "BackdropTrees"
	var bx := -3.0
	var bi := 0
	while bx <= 3.0:
		var r := rng.randf_range(1.6, 2.4)
		var y := r * 0.85 + rng.randf_range(0.2, 1.2)
		var z := rng.randf_range(-0.8, 0.8)
		ball(back, "Crown%d" % bi, r, Vector3(bx, y, z), "living_green")
		cyl(back, "Trunk%d" % bi, 0.22, 0.32, y, Vector3(bx, y * 0.5, z), "bark")
		bx += rng.randf_range(1.4, 2.0)
		bi += 1
	save_scene(back, "backdrop_trees")

# ------------------------------------------------------------------ house
func window(parent: Node, name: String, pos: Vector3, w: float, h: float, yaw := 0.0, shutters := false,
		trim := "door_wood") -> void:
	var win := Node3D.new()
	win.name = name
	win.position = pos
	win.rotation_degrees.y = yaw
	parent.add_child(win)
	box(win, "Glow", Vector3(w, h, 0.04), Vector3.ZERO, "window_glow")
	box(win, "MullionV", Vector3(0.05, h, 0.03), Vector3(0, 0, 0.03), trim)
	box(win, "MullionH", Vector3(w, 0.05, 0.03), Vector3(0, 0, 0.03), trim)
	box(win, "FrameTop", Vector3(w + 0.2, 0.1, 0.08), Vector3(0, h * 0.5 + 0.05, 0.03), trim)
	box(win, "Sill", Vector3(w + 0.26, 0.08, 0.14), Vector3(0, -h * 0.5 - 0.04, 0.05), trim)
	for s in [-1.0, 1.0]:
		box(win, "FrameSide", Vector3(0.08, h, 0.08), Vector3(s * (w * 0.5 + 0.04), 0, 0.03), trim)
		if shutters:
			box(win, "Shutter", Vector3(w * 0.42, h + 0.08, 0.04), Vector3(s * (w * 0.5 + 0.1 + w * 0.21), 0, 0.03),
				"shutter_teal")

func _house() -> void:
	var house := body("House")
	# 6 m x 5 m, front (+Z) faces the road. Foundation, planked walls, rounded corner posts.
	box(house, "Foundation", Vector3(6.1, 0.5, 5.1), Vector3(0, 0.25, 0), "stone_plain")
	box(house, "Walls", Vector3(6.0, 3.7, 5.0), Vector3(0, 2.35, 0), "wood_planks")
	for x in [-3.0, 3.0]:
		for z in [-2.5, 2.5]:
			cyl(house, "Corner", 0.11, 0.11, 3.7, Vector3(x, 2.35, z), "warm_wood")
	box(house, "FloorBand", Vector3(6.12, 0.12, 5.12), Vector3(0, 2.45, 0), "door_wood")
	# asymmetric gable facing the road: ridge off-centre, gable end planked, shingle slabs with overhang
	var ridge := Vector2(-0.48, 6.3)
	prism(house, "Gable", Vector3(6.0, 2.1, 5.0), Vector3(0, 4.2 + 1.05, 0), "wood_planks", 0.42)
	slab(house, "RoofL", Vector2(-3.0, 4.2), ridge, 5.7, 0.14, 0.4, "roof_shingle")
	slab(house, "RoofR", Vector2(3.0, 4.2), ridge, 5.7, 0.14, 0.4, "roof_shingle")
	box(house, "RidgeCap", Vector3(0.2, 0.14, 5.8), Vector3(ridge.x, ridge.y + 0.14, 0), "roof_flat",
		Vector3(0, 0, 45))
	for x in [-3.18, 3.18]:
		var z := -2.4
		while z <= 2.45:
			box(house, "Rafter", Vector3(0.36, 0.09, 0.08), Vector3(x, 4.13, z), "warm_wood")
			z += 0.6
	box(house, "Chimney", Vector3(0.62, 2.3, 0.62), Vector3(1.6, 5.75, -1.0), "brick")
	box(house, "ChimneyCap", Vector3(0.76, 0.12, 0.76), Vector3(1.6, 6.95, -1.0), "stone_plain")
	window(house, "AtticWindow", Vector3(-0.48, 5.1, 2.52), 0.55, 0.55, 0.0, false)
	# windows: two down flanking the door, two up, one on each side
	window(house, "WinDownL", Vector3(-1.85, 1.6, 2.52), 0.9, 1.1)
	window(house, "WinDownR", Vector3(1.85, 1.6, 2.52), 0.9, 1.1)
	window(house, "WinUpL", Vector3(-1.5, 3.3, 2.52), 0.85, 1.0)
	window(house, "WinUpR", Vector3(1.5, 3.3, 2.52), 0.85, 1.0)
	window(house, "WinSideE", Vector3(3.02, 3.3, 0.4), 0.85, 1.0, 90.0)
	window(house, "WinSideW", Vector3(-3.02, 3.3, -0.4), 0.85, 1.0, -90.0)
	window(house, "WinSideE2", Vector3(3.02, 1.6, -0.9), 0.85, 1.0, 90.0)
	# oversized front door (JRPG proportions)
	box(house, "Door", Vector3(1.2, 2.3, 0.08), Vector3(0, 0.5 + 1.15, 2.53), "door_wood")
	box(house, "DoorPanelTop", Vector3(0.8, 0.7, 0.02), Vector3(0, 2.1, 2.58), "door_wood")
	box(house, "DoorPanelLow", Vector3(0.8, 0.8, 0.02), Vector3(0, 1.05, 2.58), "door_wood")
	ball(house, "Knob", 0.055, Vector3(0.42, 1.55, 2.62), "awning_yellow")
	box(house, "DoorFrameTop", Vector3(1.5, 0.14, 0.1), Vector3(0, 2.87, 2.54), "warm_wood")
	for s in [-1.0, 1.0]:
		box(house, "DoorFrameSide", Vector3(0.14, 2.4, 0.1), Vector3(s * 0.67, 1.7, 2.54), "warm_wood")
	# porch: 1.5 m deep, full width, three steps, railing with simple posts, a roof on four posts
	box(house, "PorchDeck", Vector3(6.1, 0.5, 1.5), Vector3(0, 0.25, 3.25), "warm_wood")
	box(house, "PorchSkirt", Vector3(6.12, 0.3, 1.52), Vector3(0, 0.15, 3.25), "door_wood")
	for i in 3:
		var top := 0.5 - (i + 1) * 0.125
		box(house, "Step%d" % i, Vector3(1.6, top, 0.3), Vector3(0, top * 0.5, 4.15 + i * 0.3), "warm_wood")
	var posts := [-2.98, -0.86, 0.86, 2.98]
	for x in posts:
		box(house, "PorchPost", Vector3(0.14, 2.2, 0.14), Vector3(x, 1.6, 3.92), "warm_wood")
	for x in [-2.98, 2.98]:
		box(house, "PorchPostBack", Vector3(0.14, 2.2, 0.14), Vector3(x, 1.6, 2.6), "warm_wood")
	box(house, "PorchRoof", Vector3(6.4, 0.1, 1.85), Vector3(0, 2.78, 3.3), "roof_shingle", Vector3(8, 0, 0))
	box(house, "PorchBeam", Vector3(6.2, 0.16, 0.16), Vector3(0, 2.66, 3.92), "warm_wood")
	var runs := [[Vector3(-2.98, 0, 3.92), Vector3(-0.86, 0, 3.92)], [Vector3(0.86, 0, 3.92), Vector3(2.98, 0, 3.92)],
		[Vector3(-2.98, 0, 2.6), Vector3(-2.98, 0, 3.92)], [Vector3(2.98, 0, 2.6), Vector3(2.98, 0, 3.92)]]
	for run in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var mid := (a + b) * 0.5
		var along_x := absf(b.x - a.x) > 0.01
		var length := a.distance_to(b)
		var size := Vector3(length, 0.07, 0.07) if along_x else Vector3(0.07, 0.07, length)
		box(house, "RailTop", size, mid + Vector3(0, 1.4, 0), "warm_wood")
		box(house, "RailLow", size, mid + Vector3(0, 0.62, 0), "warm_wood")
		var n := int(length / 0.2)
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			box(house, "Baluster", Vector3(0.045, 0.78, 0.045), p + Vector3(0, 1.01, 0), "warm_wood")
		collide_box(house, size + Vector3(0.05, 1.0, 0.05), mid + Vector3(0, 1.0, 0))
	# porch props live with the house: chair and table on the left, shoes by the door, a plant on the rail
	instance(house, "porch_chair", Vector3(-2.2, 0.5, 3.2), 25.0, "PorchChair")
	instance(house, "side_table", Vector3(-1.55, 0.5, 3.05), 0.0, "SideTable")
	instance(house, "porch_shoes", Vector3(0.95, 0.5, 2.85), -20.0, "PorchShoes")
	instance(house, "potted_plant", Vector3(2.2, 1.435, 3.92), 0.0, "RailPlant")
	# collision: the house, the porch deck, and a ramp over the steps so the player walks up them
	collide_box(house, Vector3(6.1, 6.3, 5.1), Vector3(0, 3.15, 0))
	collide_box(house, Vector3(6.1, 0.5, 1.5), Vector3(0, 0.25, 3.25))
	collide_box(house, Vector3(1.6, 0.1, 1.05), Vector3(0, 0.22, 4.45), Vector3(29, 0, 0))
	var door := Marker3D.new()
	door.name = "DoorPoint"
	door.position = Vector3(0, 0.5, 3.1)
	house.add_child(door)
	blob(house, 4.2, 0.18, Vector3(0, 0, 0.6))
	save_scene(house, "house")

# ------------------------------------------------------------------ shop
func _shop() -> void:
	var shop := body("Shop")
	# 5 m x 4 m, 4.5 m tall; planked walls with a cream-painted front; front (+Z) faces the road
	box(shop, "Foundation", Vector3(5.1, 0.2, 4.1), Vector3(0, 0.1, 0), "stone_plain")
	box(shop, "Walls", Vector3(5.0, 4.1, 4.0), Vector3(0, 2.25, 0), "wood_planks")
	box(shop, "Front", Vector3(5.0, 4.1, 0.06), Vector3(0, 2.25, 2.03), "cream")
	for x in [-2.5, 2.5]:
		box(shop, "CornerBoard", Vector3(0.14, 4.1, 0.14), Vector3(x, 2.25, 2.0), "warm_wood")
	box(shop, "Roof", Vector3(5.5, 0.22, 4.5), Vector3(0, 4.42, 0), "roof_flat")
	box(shop, "RoofEdge", Vector3(5.6, 0.4, 0.2), Vector3(0, 4.38, 2.2), "warm_wood")
	# wide door, propped open with a wedge, warm light spilling out
	box(shop, "Doorway", Vector3(1.6, 2.4, 0.04), Vector3(0, 1.4, 2.07), "window_glow")
	box(shop, "DoorFrameTop", Vector3(1.9, 0.14, 0.1), Vector3(0, 2.66, 2.08), "warm_wood")
	for s in [-1.0, 1.0]:
		box(shop, "DoorFrameSide", Vector3(0.14, 2.5, 0.1), Vector3(s * 0.87, 1.45, 2.08), "warm_wood")
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(0.8, 0.2, 2.1)
	hinge.rotation_degrees.y = 72.0
	shop.add_child(hinge)
	box(hinge, "DoorLeaf", Vector3(1.55, 2.35, 0.06), Vector3(-0.78, 1.18, 0.03), "door_wood")
	box(hinge, "DoorGlass", Vector3(0.9, 1.0, 0.02), Vector3(-0.78, 1.6, 0.07), "window_glow")
	prism(shop, "DoorStop", Vector3(0.1, 0.07, 0.16), Vector3(0.0, 0.235, 3.3), "warm_wood", 1.0)
	# display windows either side of the door
	for s in [-1.0, 1.0]:
		var wx: float = s * 1.72
		box(shop, "DisplayGlow", Vector3(1.2, 1.3, 0.04), Vector3(wx, 1.55, 2.07), "window_glow")
		box(shop, "DisplayMullion", Vector3(0.05, 1.3, 0.03), Vector3(wx, 1.55, 2.1), "warm_wood")
		box(shop, "DisplaySill", Vector3(1.4, 0.1, 0.16), Vector3(wx, 0.86, 2.12), "warm_wood")
		box(shop, "DisplayTop", Vector3(1.4, 0.1, 0.1), Vector3(wx, 2.24, 2.1), "warm_wood")
		for e in [-1.0, 1.0]:
			box(shop, "DisplaySide", Vector3(0.08, 1.3, 0.08), Vector3(wx + e * 0.64, 1.55, 2.1), "warm_wood")
	# striped awning: 1.5 m out, red / yellow / green, sagging in the middle
	var stripes := 9
	var width := 5.3
	var sw := width / stripes
	var colours := ["awning_red", "awning_yellow", "awning_green"]
	for i in stripes:
		var t := (i - (stripes - 1) * 0.5) / ((stripes - 1) * 0.5)
		var sag := 0.13 * (1.0 - t * t)
		var x := -width * 0.5 + sw * (i + 0.5)
		var a := Vector2(2.08, 3.05)                 # (z, y) at the wall
		var b := Vector2(3.58, 2.58 - sag)           # (z, y) at the outer edge
		var dir := (b - a).normalized()
		var mid := (a + b) * 0.5
		box(shop, "Stripe%d" % i, Vector3(sw + 0.005, 0.05, a.distance_to(b)), Vector3(x, mid.y, mid.x), colours[i % 3],
			Vector3(rad_to_deg(atan2(-dir.y, dir.x)), 0, 0))
		# a valance strip with a half-disc hanging under it: the disc's top half hides behind the strip
		var r := sw * 0.5
		box(shop, "Valance%d" % i, Vector3(sw + 0.005, r + 0.02, 0.04), Vector3(x, b.y - r * 0.5, b.x + 0.02), colours[i % 3])
		cyl(shop, "Scallop%d" % i, r, r, 0.03, Vector3(x, b.y - r, b.x - 0.01), colours[i % 3],
			Vector3(90, 0, 0), 16)
	for s in [-1.0, 1.0]:
		rod(shop, "AwningArm", Vector3(s * 2.6, 3.0, 2.08), Vector3(s * 2.6, 2.55, 3.55), 0.025, "metal")
	# hand-painted sign above the awning, a degree off level
	var sign := Node3D.new()
	sign.name = "Sign"
	sign.position = Vector3(0, 5.15, 2.05)
	sign.rotation_degrees.z = 1.2
	shop.add_child(sign)
	box(sign, "Board", Vector3(2.7, 1.05, 0.1), Vector3.ZERO, "warm_wood")
	box(sign, "Trim", Vector3(2.86, 1.2, 0.05), Vector3(0, 0, -0.05), "door_wood")
	for s2 in [-0.9, 0.9]:
		box(sign, "Leg", Vector3(0.1, 0.6, 0.1), Vector3(s2, -0.75, -0.12), "door_wood")
	var label := Label3D.new()
	label.name = "ShopName"
	label.text = "SKATESHOP"
	label.font_size = 76
	label.line_spacing = 0.0
	label.pixel_size = 0.0052
	label.modulate = Color("#D8492C")
	label.outline_modulate = Color("#2A1F24")
	label.outline_size = 16
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.shaded = false
	label.double_sided = false
	label.position = Vector3(0, 0, 0.075)
	sign.add_child(label)
	for s3 in [-1.0, 1.0]:
		var lx: float = s3 * 1.2
		box(shop, "WallLanternArm", Vector3(0.04, 0.04, 0.2), Vector3(lx, 2.55, 2.15), "iron")
		box(shop, "WallLantern", Vector3(0.16, 0.22, 0.16), Vector3(lx, 2.42, 2.25), "lamp_glow")
		cyl(shop, "WallLanternCap", 0.02, 0.14, 0.1, Vector3(lx, 2.58, 2.25), "iron", Vector3(0, 45, 0), 4)
	# exterior skateboard deck display rack mounted on wall right of door
	var rack_x := 2.36
	box(shop, "DeckRackBarL", Vector3(0.04, 1.6, 0.04), Vector3(rack_x - 0.12, 1.5, 2.06), "iron")
	box(shop, "DeckRackBarR", Vector3(0.04, 1.6, 0.04), Vector3(rack_x + 0.12, 1.5, 2.06), "iron")
	var deck_colors := ["awning_red", "awning_yellow", "awning_green", "shutter_teal"]
	for d in 4:
		var dy := 0.9 + d * 0.42
		box(shop, "Deck%d" % d, Vector3(0.22, 0.04, 0.76), Vector3(rack_x, dy, 2.12), deck_colors[d], Vector3(0, 0, 14))
		# small wheels on the deck sides
		for wx in [-0.09, 0.09]:
			for wz in [-0.24, 0.24]:
				cyl(shop, "D%dWheel_%d_%d" % [d, int(wx > 0), int(wz > 0)], 0.025, 0.025, 0.03, Vector3(rack_x + wx, dy - 0.03, 2.12 + wz), "cream", Vector3(0, 0, 90), 8)
	collide_box(shop, Vector3(5.1, 4.5, 4.1), Vector3(0, 2.25, 0))
	var door := Marker3D.new()
	door.name = "DoorPoint"
	door.position = Vector3(0, 0, 2.6)
	shop.add_child(door)
	blob(shop, 3.6, 0.16, Vector3(0, 0, 0.4))
	save_scene(shop, "shop", "")

# ------------------------------------------------------------------ ground + street
## Road centreline: enters from the west as dirt, bends gently, turns to cobble as it passes the shop.
func road_z(x: float) -> float:
	return 0.9 * sin(0.16 * x - 0.3) + 0.2

const ROAD_HALF := 2.0            # a 4 m lane: people walk in it (the spec's 6 m read as a highway next to the target)

func squeeze(p: Vector3) -> Vector3:
	if absf(p.x) > 20.5 or absf(p.z) > 15.5:
		return p                       # the backdrop stays where it is
	return p + Vector3(0, 0, SQUEEZE_N if p.z < road_z(p.x) else -SQUEEZE_S)
const COBBLE_FROM := -2.0

func _is_cobble(x: float, t: float) -> bool:
	return x > COBBLE_FROM + 0.8 * sin(t * 5.0 + 1.0)

func _ground_mesh() -> ArrayMesh:
	var dirt := SurfaceTool.new()
	var cobble := SurfaceTool.new()
	var grass := SurfaceTool.new()
	for st in [dirt, cobble, grass]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# road ribbon, crowned 3 cm in the middle
	var xs := []
	var x := -19.0
	while x <= 19.01:
		xs.append(x)
		x += 0.5
	var across := 8
	for i in xs.size() - 1:
		for j in across:
			var t0 := -1.0 + 2.0 * j / across
			var t1 := -1.0 + 2.0 * (j + 1) / across
			var corners := [
				_road_point(xs[i], t0), _road_point(xs[i + 1], t0), _road_point(xs[i + 1], t1), _road_point(xs[i], t1)]
			var st: SurfaceTool = cobble if _is_cobble((xs[i] + xs[i + 1]) * 0.5, (t0 + t1) * 0.5) else dirt
			_quad(st, corners)
	# yard path (gate to porch steps) and the dirt path running south past the notice board
	_ribbon(dirt, [squeeze(Vector3(-7.5, 0, -3.3)), squeeze(Vector3(-7.5, 0, -5.4))], 1.1)
	_ribbon(dirt, [Vector3(0.5, 0, 1.6), squeeze(Vector3(0.7, 0, 6.0)), squeeze(Vector3(0.3, 0, 9.0)),
		Vector3(0.6, 0, 13.0)], 1.4)
	# grass everywhere else (sits just under the road)
	_quad(grass, [Vector3(-40, 0, -35), Vector3(40, 0, -35), Vector3(40, 0, 35), Vector3(-40, 0, 35)].map(
		func(v): return v + Vector3(0, -0.002, 0)))
	var mesh := ArrayMesh.new()
	for pair in [[grass, "living_green"], [dirt, "road_dirt"], [cobble, "cobblestone"]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, M[pair[1]])
	return mesh

func _road_point(x: float, t: float) -> Vector3:
	return Vector3(x, 0.012 + 0.03 * (1.0 - t * t), road_z(x) + t * ROAD_HALF)

func _quad(st: SurfaceTool, c: Array) -> void:
	# corners go -X/-Z, +X/-Z, +X/+Z, -X/+Z; this order makes the face point up in Godot
	for idx in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(c[idx])

func _ribbon(st: SurfaceTool, points: Array, width: float) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var side := (b - a).cross(Vector3.UP).normalized() * width * 0.5
		var y := Vector3(0, 0.02, 0)
		_quad(st, [a + side + y, a - side + y, b - side + y, b + side + y])

func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := i * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var side := out.cross(Vector3.UP) * 0.02
		var base := out * 0.025
		var h := rng.randf_range(0.11, 0.18)
		var tip := out * 0.07 + Vector3(0, h, 0)
		# both faces, so the blade shows its lit side and its shadow side
		for v in [base - side, tip, base + side, base + side, tip, base - side]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, M["grass_tuft"])
	return mesh

func _street() -> void:
	rng.seed = 7
	squeeze_on = true
	var root := Node3D.new()
	root.name = "StarterStreet"
	root.set_script(load(DIR + "starter_street.gd"))

	# --- environment + lighting
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = M["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)

	var lighting := Node3D.new()
	lighting.name = "Lighting"
	lighting.set_script(load(DIR + "street_lighting.gd"))
	lighting.set("sun_path", ^"Sun")
	lighting.set("environment_path", ^"../WorldEnvironment")
	root.add_child(lighting)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# 30° up, from the west-southwest: warm side-light that still reaches the house front (a sun due west only
	# grazes the south-facing porch and leaves it in shadow)
	sun.rotation_degrees = Vector3(-30, -58, 0)
	sun.light_color = Color("#FFE0B0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	lighting.add_child(sun)

	var envn := Node3D.new()
	envn.name = "Environment"
	root.add_child(envn)
	var ground := body("Ground")
	envn.add_child(ground)
	var gmesh := _ground_mesh()
	_save_res(gmesh, DIR + "meshes/ground.res")
	_mi(ground, "GroundMesh", gmesh, Vector3.ZERO, "")
	collide_box(ground, Vector3(80, 1, 70), Vector3(0, -0.5, 0))

	instance(envn, "house", Vector3(-7.5, 0, -10.2), 0.0, "House")
	instance(envn, "shop", Vector3(7.5, 0, 8.3), 180.0, "Shop")
	instance(envn, "shade_tree", Vector3(-2.3, 0, -10.8), 20.0, "ShadeTree")
	instance(envn, "blossom_tree", Vector3(-5.6, 0, 9.2), 0.0, "BlossomTree")
	# the big tree that leans over the lane between the house and the shop (both targets have one)
	instance(envn, "shade_tree", Vector3(0.9, 0, -3.3), 140.0, "LaneTree")
	_hills(envn)

	# fence: ~10 sections round the front yard, gate on the path. Not evenly spaced, not quite straight.
	var fences := Node3D.new()
	fences.name = "FenceSections"
	envn.add_child(fences)
	var front_starts := [-14.0, -12.0, -10.0, -7.0, -5.0, -3.0]
	for i in front_starts.size():
		instance(fences, "fence_section", Vector3(front_starts[i] + rng.randf_range(-0.04, 0.04), 0,
			-4.2 + rng.randf_range(-0.05, 0.05)), rng.randf_range(-1.5, 1.5), "FenceFront%d" % i)
	for i in 2:
		# +90° turns the section's +X run to point north (-Z), back along the side of the yard
		instance(fences, "fence_section", Vector3(-14.0, 0, -4.2 - i * 2.0), 90.0 + rng.randf_range(-1.5, 1.5),
			"FenceWest%d" % i)
		instance(fences, "fence_section", Vector3(-1.0, 0, -4.2 - i * 2.0), 90.0 + rng.randf_range(-1.5, 1.5),
			"FenceEast%d" % i)
	instance(fences, "fence_gate", Vector3(-8.0, 0, -4.2), 0.0, "FenceGate")

	var back := Node3D.new()
	back.name = "Backdrop"
	envn.add_child(back)
	var spots := [Vector3(-14, 0, -17), Vector3(-6, 0, -18), Vector3(2, 0, -17.5), Vector3(10, 0, -16), Vector3(18, 0, -14),
		Vector3(22, 0, -7), Vector3(22, 0, 9), Vector3(16, 0, 16), Vector3(8, 0, 17), Vector3(-2, 0, 17.5),
		Vector3(-10, 0, 16.5), Vector3(-18, 0, 13), Vector3(-22, 0, 7), Vector3(-22, 0, -9)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		instance(back, "backdrop_trees", p, rad_to_deg(atan2(p.x, p.z)) + 180.0, "Trees%d" % i)

	# --- props: clustered at the doors, nothing perfectly square
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	instance(props, "street_lamp", Vector3(-0.9, 0, 3.9), 0.0, "StreetLamp")
	instance(props, "notice_board", Vector3(-3.1, 0, 4.9), 184.0, "NoticeBoard")
	instance(props, "bench", Vector3(4.1, 0, 5.8), 172.0, "Bench")
	instance(props, "bike_rack", Vector3(-5.6, 0, 5.3), 180.0, "BikeRack")
	instance(props, "bicycle", Vector3(-5.6, 0, 5.12), 180.0, "Bicycle")
	instance(props, "mailbox", Vector3(-6.55, 0, -3.75), 3.0, "Mailbox")
	instance(props, "fire_hydrant", Vector3(3.3, 0, 3.95), 17.0, "FireHydrant")
	instance(props, "trash_can", Vector3(-1.6, 0, -4.75), 0.0, "TrashCan")
	instance(props, "garden_plot", Vector3(-11.6, 0, -5.8), 0.0, "GardenPlot")
	instance(props, "crate", Vector3(10.1, 0, 5.95), 4.0, "Crate1")
	instance(props, "crate", Vector3(10.1, 0.62, 5.95), 16.0, "Crate2")
	instance(props, "crate", Vector3(10.65, 0, 5.2), -9.0, "Crate3")
	instance(props, "barrel", Vector3(9.55, 0, 5.1), 0.0, "Barrel")
	instance(props, "chalkboard_sign", Vector3(10.35, 0, 4.25), 200.0, "ChalkboardSign")
	instance(props, "potted_flowers", Vector3(6.35, 0, 6.0), 0.0, "ShopFlowersL")
	instance(props, "potted_flowers", Vector3(8.65, 0, 6.0), 30.0, "ShopFlowersR")
	var bushes := [[Vector3(-12.9, 0, -4.8), 0.0], [Vector3(-3.6, 0, -4.9), 40.0], [Vector3(-4.2, 0, -9.0), 80.0],
			[Vector3(5.3, 0, 7.9), 10.0], [Vector3(-10.9, 0, -7.9), 120.0]]
	for i in bushes.size():
		instance(props, "bush_small", bushes[i][0], bushes[i][1], "Bush%d" % i)

	# --- NPC spots (spec: 2 m clear at the shop door and bench, 1.5 m clear along the road)
	var spawns := Node3D.new()
	spawns.name = "NPCSpawns"
	root.add_child(spawns)
	for m in [["ShopWorkSpot", Vector3(7.5, 0, 5.7), 180.0], ["BenchSitSpot", Vector3(4.1, 0.0, 5.65), 172.0],
			["PorchSitSpot", Vector3(-9.7, 0.5, -7.0), 25.0], ["HouseDoor", Vector3(-7.5, 0.5, -7.1), 0.0],
			["ShopDoor", Vector3(7.5, 0, 5.7), 180.0], ["PlayerSpawn", Vector3(-11.0, 0.05, 1.0), -90.0]]:
		var mk := Marker3D.new()
		mk.name = m[0]
		mk.position = squeeze(m[1])
		mk.rotation_degrees.y = m[2]
		spawns.add_child(mk)
	var path := Path3D.new()
	path.name = "RoadWalkPath"
	path.curve = Curve3D.new()
	var wx := -18.0
	while wx <= 18.01:
		path.curve.add_point(Vector3(wx, 0.05, road_z(wx) + 1.4))
		wx += 3.0
	spawns.add_child(path)

	# --- grass tufts: road edges, fence bases, cobble cracks
	var tufts := MultiMeshInstance3D.new()
	tufts.name = "GrassTufts"
	tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tuft_mesh()
	var xforms: Array[Transform3D] = []
	var tx := -18.0
	while tx < 18.0:
		for side in [-1.0, 1.0]:
			if side > 0 and tx > -0.4 and tx < 1.6:
				continue                       # the dirt path mouth
			if side < 0 and tx > -8.2 and tx < -6.8:
				continue                       # the yard path mouth
			var z: float = road_z(tx) + side * (ROAD_HALF + rng.randf_range(0.02, 0.5))
			xforms.append(_tuft_xform(Vector3(tx + rng.randf_range(-0.15, 0.15), 0, z), 1.0))
		tx += rng.randf_range(0.22, 0.5)
	var fx := -14.0
	while fx < -1.0:
		if fx < -8.1 or fx > -6.9:
			xforms.append(_tuft_xform(squeeze(Vector3(fx, 0, -4.2 + rng.randf_range(-0.2, 0.2))), 1.1))
		fx += rng.randf_range(0.18, 0.4)
	for i in 70:
		var cx := rng.randf_range(COBBLE_FROM + 1.0, 18.0)
		var t := rng.randf_range(-0.95, 0.95)
		xforms.append(_tuft_xform(_road_point(cx, t), 0.55))
	for i in 40:
		var a := rng.randf() * TAU
		var centre: Vector3 = [Vector3(-0.9, 0, 3.9), Vector3(3.3, 0, 3.95), Vector3(-3.1, 0, 4.9),
			Vector3(-2.3, 0, -10.8), Vector3(-5.6, 0, 9.2)][i % 5]
		xforms.append(_tuft_xform(squeeze(centre) + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 0.9), 1.0))
	for i in 520:
		var g := Vector3(rng.randf_range(-20.0, 20.0), 0, rng.randf_range(-15.0, 15.0))
		if absf(g.z - road_z(g.x)) < ROAD_HALF + 0.1:
			continue
		if g.x > -10.8 and g.x < -4.2 and g.z < -4.2:
			continue                           # under the house
		if g.x > 4.8 and g.x < 10.2 and g.z > 5.0:
			continue                           # under the shop
		xforms.append(_tuft_xform(g, rng.randf_range(0.8, 1.2)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	tufts.multimesh = mm
	root.add_child(tufts)

	# --- curb stones edging the cobbled stretch, and loose stones pressed into the dirt (both targets)
	root.add_child(_curbs())
	root.add_child(_loose_stones())
	var fl := Node3D.new()
	fl.name = "Flowers"
	props.add_child(fl)
	for f in [Vector3(-13.4, 0, -4.55), Vector3(-10.6, 0, -4.5), Vector3(-5.8, 0, -4.55), Vector3(-2.4, 0, -4.5),
			Vector3(-8.6, 0, -4.6), Vector3(-6.9, 0, -3.8), Vector3(-1.4, 0, -6.2), Vector3(-4.9, 0, 8.6),
			Vector3(-3.3, 0, 4.2), Vector3(5.6, 0, 6.2)]:
		instance(fl, "flower_clump", f, rng.randf_range(0, 360), "Flowers%d" % fl.get_child_count())
	# houses further down the lane, so the street continues past the play area
	var far := Node3D.new()
	far.name = "DistantHouses"
	envn.add_child(far)
	for h in [[Vector3(-19.0, 0, -9.5), 70.0, 0.85], [Vector3(20.0, 0, -8.0), -60.0, 0.8],
			[Vector3(21.0, 0, 7.5), -110.0, 0.8]]:
		var node := instance(far, "house", h[0], h[1], "FarHouse%d" % far.get_child_count())
		node.scale = Vector3.ONE * h[2]

	# --- ink pass (screen-space outlines for everything in the world)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var ink := _mi(root, "InkPass", quad, Vector3.ZERO, "ink")
	ink.extra_cull_margin = 16384.0
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- the player
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(-11.0, 0.05, 1.0)
	player.rotation_degrees.y = -90.0
	root.add_child(player)

	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	_save_res(ps, DIR + "starter_street.tscn")
	root.free()

func _tuft_xform(pos: Vector3, scale: float) -> Transform3D:
	var s := scale * rng.randf_range(0.8, 1.3)
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
	return Transform3D(b, pos)

func _curb_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.12, 0.24)
	mesh.material = M["stone_plain"]
	return mesh

func _curbs() -> MultiMeshInstance3D:
	var xforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var x := COBBLE_FROM - 2.0
		while x < 19.0:
			var skip: bool = side > 0 and x > -0.5 and x < 1.7
			if not skip:
				var z: float = road_z(x) + side * (ROAD_HALF + 0.12)
				var tangent := Vector3(1, 0, road_z(x + 0.1) - road_z(x)).normalized()
				var b := Basis(Vector3.UP, atan2(-tangent.z, tangent.x) + rng.randf_range(-0.06, 0.06))
				xforms.append(Transform3D(b, Vector3(x, 0.05 + rng.randf_range(-0.01, 0.01), z)))
			x += 0.53 + rng.randf_range(-0.02, 0.03)
	return _multi("CurbStones", _curb_mesh(), xforms)

func _loose_stones() -> MultiMeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.9
	mesh.bottom_radius = 1.0
	mesh.height = 0.35
	mesh.radial_segments = 9
	mesh.rings = 1
	mesh.material = M["stone_plain"]
	var xforms: Array[Transform3D] = []
	for i in 110:
		var x := rng.randf_range(-18.0, COBBLE_FROM + 1.5)
		var t := rng.randf_range(-1.0, 1.0)
		# more stones near the cobbles, as if the paving is wearing into the dirt
		if rng.randf() > 0.35 + 0.65 * clampf((x + 18.0) / 17.0, 0.0, 1.0):
			continue
		var p := _road_point(x, t)
		var r := rng.randf_range(0.1, 0.24)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, 0.12, r * rng.randf_range(0.7, 1.0))), p))
	for i in 30:
		var z := rng.randf_range(3.4, 12.5)
		var p2 := Vector3(0.5 + rng.randf_range(-0.7, 0.7), 0.02, z)
		var r2 := rng.randf_range(0.1, 0.2)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r2, 0.12, r2 * 0.85)), p2))
	return _multi("LooseStones", mesh, xforms)

func _multi(name: String, mesh: Mesh, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	mmi.multimesh = mm
	return mmi

## Layered background like the target: a second, taller tree row and low rolling hills, a cooler green so they
## sit back in the distance.
func _hills(parent: Node) -> void:
	var hills := Node3D.new()
	hills.name = "Hills"
	parent.add_child(hills)
	var far_green := ShaderMaterial.new()
	far_green.shader = load(TOON)
	far_green.set_shader_parameter("base_color", Color("#8DB86A"))
	far_green.set_shader_parameter("shadow_color", Color("#6C9656"))
	_save_res(far_green, DIR + "materials/far_green.tres")
	M["far_green"] = load(DIR + "materials/far_green.tres")
	for h in [[Vector3(-30, -6, -48), 22.0], [Vector3(8, -8, -55), 28.0], [Vector3(40, -7, -38), 22.0],
			[Vector3(48, -8, 10), 24.0], [Vector3(20, -7, 45), 22.0], [Vector3(-25, -8, 48), 26.0],
			[Vector3(-50, -7, 5), 24.0]]:
		ball(hills, "Hill", h[1], h[0], "far_green", Vector3(1.0, 0.45, 0.8))
	for i in 16:
		var a := i * TAU / 16.0 + 0.2
		var p := Vector3(cos(a) * 30.0, 0, sin(a) * 25.0)
		var tree := instance(hills, "backdrop_trees", p, rad_to_deg(atan2(p.x, p.z)) + 180.0, "FarTrees%d" % i)
		tree.scale = Vector3.ONE * 1.35
