extends SceneTree
## Builds the pet meshes: dogs and cats, one scene per breed.
##
## Husky and Maine Coon are the canonical pair (Rolling_Tides_2D/scripts_2d/pets/pet_ai.gd lists
## SUPPORTED_SPECIES = ["husky", "maine_coon", "red_turtle"]); the rest are breeds around them.
##
## Built procedurally in the world's toon style, the same way the region props are, rather than modelled in
## Blender: a quadruped rig and export path is a much bigger job than this milestone needs, and these can be
## replaced by sculpted models later without touching pets/pet.gd. Each breed is a BODY PLAN plus colours, so a
## husky reads as a husky - erect triangle ears, a curled tail, a masked face - and a Maine Coon reads as a big
## long-haired cat with tufted ears and a plumed tail.
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --path . -s res://tools/build_pets.gd

const OUT := "res://pets/"
const TOON := "res://world/shaders/toon_world.gdshader"

## base coat, shade, belly/points, nose+paw dark
## Coat variations named on the scale reference sheet (docs/reference_images/pets/pet_scale_and_coats.jpg):
## H1 classic black & white, H2 copper red & white, H3 silver & white, H4 all-white (rare);
## M1 classic brown tabby, M2 silver smoke, M3 ginger orange, M4 cream cameo (rare).
## base coat, shade, white underside/mask, nose+paw dark
const COATS := {
	"husky":            ["#3A3A3E", "#1E1E22", "#F4F4F0", "#18181C"],   # H1 classic black & white
	"husky_copper":     ["#A65A2E", "#6E3618", "#F6EFE2", "#201814"],   # H2
	"husky_silver":     ["#9AA3AC", "#616A74", "#F7F8F6", "#1C1E22"],   # H3
	"husky_white":      ["#EDEDE8", "#BDBDB6", "#FFFFFF", "#2A2A2A"],   # H4 rare
	"maine_coon":       ["#8A6A46", "#4E3A26", "#E7D7BE", "#2A2320"],   # M1 classic brown tabby
	"maine_coon_smoke": ["#9EA2A6", "#5E6266", "#E8EAEC", "#26282A"],   # M2
	"maine_coon_ginger":["#D98A46", "#9C5722", "#F6E4CC", "#2A2320"],   # M3
	"maine_coon_cream": ["#E8D7BC", "#B9A588", "#FAF3E7", "#2A2320"],   # M4 rare
	"labrador":         ["#D8B274", "#9A7B46", "#EBD7B0", "#2A2320"],
	"shiba":            ["#D98A4A", "#9C5B28", "#F4E6D2", "#2A2320"],
	"german_shepherd":  ["#8A5A2C", "#4A2E14", "#2E2620", "#1E1A18"],
	"corgi":            ["#D9924E", "#A2642C", "#F6EADA", "#2A2320"],
	"border_collie":    ["#2E2A2A", "#171515", "#F2F0EA", "#1A1818"],
	"tabby":            ["#9A8560", "#5F5138", "#E8DFCB", "#2A2320"],
	"siamese":          ["#E3D6BC", "#B3A184", "#4A3A32", "#2A2320"],
	"black_cat":        ["#2A2A30", "#141418", "#3A3A42", "#101014"],
	"calico":           ["#F0E6D6", "#B9AC99", "#D98A4A", "#2A2320"],
	"orange_cat":       ["#E09246", "#A55F22", "#F6E4CC", "#2A2320"],
}

## kind, display name, shoulder height, body length, leg length, body thickness, muzzle length,
## ear style (erect|folded|tufted|round), tail style (curl|plume|straight|long), coat key
## kind, display, shoulder height, body length, leg length, body thickness, muzzle, ears, tail, coat, ruff
## Heights come from the scale sheet against a ~1.75 m character: the husky reads to the thigh, the Maine Coon
## to the calf. `ruff` adds the neck mane both these breeds are drawn with - it is most of what makes a husky
## look like a husky rather than a generic dog.
const BREEDS := [
	["dog", "Husky",            0.66, 0.86, 0.43, 0.28, 0.18, "erect",  "curl",     "husky", 1.0],
	["dog", "Husky Copper",     0.66, 0.86, 0.43, 0.28, 0.18, "erect",  "curl",     "husky_copper", 1.0],
	["dog", "Husky Silver",     0.66, 0.86, 0.43, 0.28, 0.18, "erect",  "curl",     "husky_silver", 1.0],
	["dog", "Husky White",      0.66, 0.86, 0.43, 0.28, 0.18, "erect",  "curl",     "husky_white", 1.0],
	["dog", "Labrador",         0.58, 0.82, 0.37, 0.27, 0.18, "folded", "straight", "labrador", 0.2],
	["dog", "Shiba Inu",        0.42, 0.56, 0.26, 0.19, 0.12, "erect",  "curl",     "shiba", 0.7],
	["dog", "German Shepherd",  0.63, 0.86, 0.41, 0.26, 0.19, "erect",  "straight", "german_shepherd", 0.5],
	["dog", "Corgi",            0.30, 0.64, 0.14, 0.22, 0.13, "erect",  "plume",    "corgi", 0.4],
	["dog", "Border Collie",    0.54, 0.74, 0.35, 0.22, 0.16, "folded", "plume",    "border_collie", 0.7],
	["cat", "Maine Coon",       0.40, 0.66, 0.24, 0.23, 0.09, "tufted", "plume",    "maine_coon", 0.9],
	["cat", "Maine Coon Smoke", 0.40, 0.66, 0.24, 0.23, 0.09, "tufted", "plume",    "maine_coon_smoke", 0.9],
	["cat", "Maine Coon Ginger",0.40, 0.66, 0.24, 0.23, 0.09, "tufted", "plume",    "maine_coon_ginger", 0.9],
	["cat", "Maine Coon Cream", 0.40, 0.66, 0.24, 0.23, 0.09, "tufted", "plume",    "maine_coon_cream", 0.9],
	["cat", "Tabby",            0.31, 0.48, 0.18, 0.16, 0.07, "erect",  "long",     "tabby", 0.15],
	["cat", "Siamese",          0.32, 0.48, 0.20, 0.14, 0.08, "erect",  "long",     "siamese", 0.0],
	["cat", "Black Cat",        0.31, 0.48, 0.18, 0.16, 0.07, "erect",  "long",     "black_cat", 0.15],
	["cat", "Calico",           0.30, 0.47, 0.17, 0.17, 0.07, "round",  "long",     "calico", 0.2],
	["cat", "Orange Cat",       0.32, 0.49, 0.18, 0.18, 0.07, "erect",  "long",     "orange_cat", 0.2],
]

var M := {}

func _initialize() -> void:
	_build.call_deferred()

func _mat(key: String, which: int) -> Material:
	var id := "%s_%d" % [key, which]
	if M.has(id):
		return M[id]
	var c: Array = COATS[key]
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	m.set_shader_parameter("base_color", Color(c[which]))
	m.set_shader_parameter("shadow_color", Color(c[which]).darkened(0.35))
	m.set_shader_parameter("line_mode", 0)
	ResourceSaver.save(m, OUT + "materials/%s.tres" % id, ResourceSaver.FLAG_CHANGE_PATH)
	M[id] = load(OUT + "materials/%s.tres" % id)
	return M[id]

func _part(parent: Node3D, n: String, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _blob(parent: Node3D, n: String, pos: Vector3, scale: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = SphereMesh.new()
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

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "materials"))
	var made := 0
	for b in BREEDS:
		var kind: String = b[0]
		var display: String = b[1]
		var shoulder: float = b[2]
		var length: float = b[3]
		var leg: float = b[4]
		var thick: float = b[5]
		var muzzle: float = b[6]
		var ears: String = b[7]
		var tail: String = b[8]
		var coat: String = b[9]
		var ruff: float = b[10]
		var id := display.to_snake_case()

		var root := CharacterBody3D.new()
		root.name = display.replace(" ", "")
		# Built GROUND-UP: the body sits at `shoulder`, the legs run from its underside down to y = 0, and the
		# collider is centred on the body. The first pass hung everything off the body centre and the animals
		# floated with their paws in the air.
		var body_y := shoulder
		var belly_r := thick * 0.5
		var leg_len: float = maxf(0.05, body_y - belly_r * 0.9)

		# A box from the paws to the shoulder, NOT a capsule around the torso. A torso capsule's lowest point sits
		# well above the origin, so resting it on the ground buried the origin - and with it the legs - half a
		# metre under the floor. Measured: the husky's back came out at 0.42 m instead of 0.80 m.
		var body_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		var stand_h: float = body_y + thick * 0.45
		box_shape.size = Vector3(thick * 1.05, stand_h, length * 0.9)
		body_shape.shape = box_shape
		body_shape.position = Vector3(0, stand_h * 0.5, 0)
		root.add_child(body_shape)

		var art := Node3D.new()
		art.name = "Art"
		root.add_child(art)

		var coat_mat := _mat(coat, 0)
		var shade_mat := _mat(coat, 1)
		var belly_mat := _mat(coat, 2)
		var dark_mat := _mat(coat, 3)

		# --- torso: overlapping so it reads as one animal, not a string of beads
		# The turnarounds show a deep chest, a tucked waist and a rounded haunch - three masses, not a tube.
		_blob(art, "Chest", Vector3(0, body_y + thick * 0.04, -length * 0.18),
			Vector3(thick * 1.04, thick * 1.12, length * 0.40), coat_mat)
		_blob(art, "Waist", Vector3(0, body_y - thick * 0.02, 0.0),
			Vector3(thick * 0.86, thick * 0.88, length * 0.30), coat_mat)
		_blob(art, "Haunch", Vector3(0, body_y + thick * 0.02, length * 0.20),
			Vector3(thick * 1.10, thick * 1.06, length * 0.36), coat_mat)
		_blob(art, "Belly", Vector3(0, body_y - thick * 0.34, -length * 0.02),
			Vector3(thick * 0.84, thick * 0.48, length * 0.44), belly_mat)

		# --- neck, so the head is attached to something
		var skull := thick * (0.74 if kind == "cat" else 0.70)
		var head_pos := Vector3(0, body_y + thick * 0.34, -length * 0.40)
		var neck_pos := (head_pos + Vector3(0, body_y, -length * 0.18)) * 0.5
		_blob(art, "Neck", neck_pos + Vector3(0, -thick * 0.02, 0),
			Vector3(thick * 0.58, thick * 0.58, thick * 0.64), coat_mat)
		if ruff > 0.05:
			# The mane. On the sheets this is the silhouette: a husky without its ruff is just a dog, and the
			# Maine Coon's chest fur does the same job.
			_blob(art, "Ruff", neck_pos + Vector3(0, -thick * 0.06, thick * 0.10),
				Vector3(thick * (0.78 + 0.34 * ruff), thick * (0.74 + 0.30 * ruff), thick * (0.50 + 0.26 * ruff)),
				coat_mat)
			_blob(art, "RuffBib", neck_pos + Vector3(0, -thick * 0.30, -thick * 0.12),
				Vector3(thick * (0.52 + 0.24 * ruff), thick * (0.46 + 0.22 * ruff), thick * 0.40), belly_mat)

		var head := Node3D.new(); head.name = "Head"
		head.position = head_pos
		art.add_child(head)
		_blob(head, "Skull", Vector3.ZERO, Vector3(skull, skull * 0.94, skull * 0.98), coat_mat)
		_blob(head, "Muzzle", Vector3(0, -skull * 0.26, -skull * 0.72 - muzzle * 0.35),
			Vector3(skull * 0.54, skull * 0.44, muzzle * 0.95 + skull * 0.25),
			belly_mat if coat != "german_shepherd" else shade_mat)
		_blob(head, "Nose", Vector3(0, -skull * 0.20, -skull * 0.95 - muzzle * 0.7), Vector3(0.032, 0.026, 0.026), dark_mat)
		for side in [-1.0, 1.0]:
			var tag := "L" if side < 0.0 else "R"
			_blob(head, "Eye" + tag, Vector3(side * skull * 0.40, skull * 0.10, -skull * 0.70),
				Vector3(0.032, 0.038, 0.022), dark_mat)
			match ears:
				"erect", "tufted":
					var e := _part(head, "Ear" + tag, Vector3(side * skull * 0.44, skull * 0.62, skull * 0.10),
						Vector3(0.012, 0.0, 0.0), coat_mat)
					e.mesh = _cone(skull * 0.30, skull * (0.82 if kind == "cat" else 0.70))
					e.rotation = Vector3(-0.12, 0.0, side * 0.20)
					if ears == "tufted":
						var t := _part(head, "Tuft" + tag, Vector3(side * skull * 0.48, skull * 1.02, skull * 0.08),
							Vector3(0.008, 0.0, 0.0), belly_mat)
						t.mesh = _cone(skull * 0.09, skull * 0.34)
						t.rotation = Vector3(-0.1, 0.0, side * 0.26)
				"folded":
					_blob(head, "Ear" + tag, Vector3(side * skull * 0.58, skull * 0.30, skull * 0.04),
						Vector3(0.026, skull * 0.50, skull * 0.28), shade_mat, Vector3(0.0, 0.0, side * 0.22))
				"round":
					_blob(head, "Ear" + tag, Vector3(side * skull * 0.50, skull * 0.60, 0.0),
						Vector3(skull * 0.26, skull * 0.28, 0.02), coat_mat)
		if coat.begins_with("husky"):
			# white mask over the muzzle and cheeks, a dark cap above it, and the blaze up the forehead
			_blob(head, "Mask", Vector3(0, -skull * 0.06, -skull * 0.56),
				Vector3(skull * 0.86, skull * 0.62, skull * 0.52), belly_mat)
			_blob(head, "Blaze", Vector3(0, skull * 0.26, -skull * 0.62),
				Vector3(skull * 0.16, skull * 0.44, skull * 0.30), belly_mat)
			for side2 in [-1.0, 1.0]:
				_blob(head, "Goggle" + ("L" if side2 < 0.0 else "R"),
					Vector3(side2 * skull * 0.34, skull * 0.20, -skull * 0.58),
					Vector3(skull * 0.30, skull * 0.30, skull * 0.26), coat_mat)
		if coat.begins_with("maine_coon"):
			for side3 in [-1.0, 1.0]:      # cheek fur, the wide face the sheet draws
				_blob(head, "Cheek" + ("L" if side3 < 0.0 else "R"),
					Vector3(side3 * skull * 0.46, -skull * 0.16, -skull * 0.22),
					Vector3(skull * 0.34, skull * 0.46, skull * 0.40), belly_mat)

		# --- legs: they must reach the floor, and be thick enough to see
		for side in [-1.0, 1.0]:
			for pair in [[-1.0, "Fore"], [1.0, "Hind"]]:
				var z: float = float(pair[0]) * length * 0.24
				var tag2: String = String(pair[1]) + ("L" if side < 0.0 else "R")
				var leg_node := Node3D.new()
				leg_node.name = "Leg" + tag2
				leg_node.position = Vector3(side * thick * 0.46, 0.0, z)
				art.add_child(leg_node)
				_blob(leg_node, "Thigh", Vector3(0, body_y - belly_r * 0.55, 0),
					Vector3(thick * 0.36, leg_len * 0.34, thick * 0.40), coat_mat)
				_part(leg_node, "Shin", Vector3(0, leg_len * 0.46, 0),
					Vector3(thick * 0.28, leg_len * 0.92, thick * 0.28), coat_mat)
				_part(leg_node, "Paw", Vector3(0, 0.035, -thick * 0.06),
					Vector3(thick * 0.34, 0.07, thick * 0.44), belly_mat)

		# --- tail
		var tail_node := Node3D.new()
		tail_node.name = "Tail"
		tail_node.position = Vector3(0, body_y + thick * 0.10, length * 0.34)
		art.add_child(tail_node)
		match tail:
			"curl":
				# the sickle the tail-detail panel is all about: segments sweeping up and over the back
				var seg := 6
				for i in seg:
					var t: float = float(i) / float(seg - 1)
					var a: float = lerpf(-0.35, 2.5, t)         # sweeps up and forward over the haunch
					var r: float = thick * 0.62
					var fluff: float = 0.052 + 0.020 * sin(t * PI)
					_blob(tail_node, "Curl%d" % i,
						Vector3(0, r * sin(a) + thick * 0.10, r * cos(a) * 0.65),
						Vector3(fluff, fluff, fluff * 1.25),
						belly_mat if i >= seg - 2 else coat_mat)
			"plume":
				var pseg := 5
				for i in pseg:
					var t2: float = float(i) / float(pseg - 1)
					var fluff2: float = 0.050 + 0.026 * sin(t2 * PI)
					_blob(tail_node, "Plume%d" % i,
						Vector3(0, thick * (0.10 + t2 * 0.42), 0.04 + t2 * 0.26),
						Vector3(fluff2, fluff2, fluff2 * 1.2),
						belly_mat if i == pseg - 1 else coat_mat)
			"long":
				_blob(tail_node, "Tail", Vector3(0, thick * 0.28, 0.12), Vector3(0.032, 0.036, 0.20), coat_mat, Vector3(-0.75, 0, 0))
				_blob(tail_node, "Tip", Vector3(0, thick * 0.56, 0.21), Vector3(0.03, 0.032, 0.055), dark_mat)
			_:
				_blob(tail_node, "Tail", Vector3(0, thick * 0.02, 0.15), Vector3(0.042, 0.042, 0.19), coat_mat, Vector3(-0.2, 0, 0))

		root.set_script(load("res://pets/pet.gd"))
		root.set("breed_id", id)
		root.set("display_name", display)
		root.set("species", "cat" if kind == "cat" else "dog")
		root.set("shoulder_height", shoulder)

		for child in root.get_children():
			_own(child, root)
		var packed := PackedScene.new()
		if packed.pack(root) != OK:
			push_error("pack failed for " + display)
			continue
		if ResourceSaver.save(packed, OUT + "%s.tscn" % id, ResourceSaver.FLAG_CHANGE_PATH) == OK:
			made += 1
	print("PETS built: %d breeds -> %s" % [made, OUT])
	quit()

func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)
