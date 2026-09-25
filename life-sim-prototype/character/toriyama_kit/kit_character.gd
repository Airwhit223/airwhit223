class_name ToriyamaKitCharacter
extends ToriyamaCharacter
## A character assembled at runtime from kit parts (res://character/toriyama_kit/) — what the character creator and
## the custom player use. It is a ToriyamaCharacter, so the skeleton driving, sockets, expressions, blink, body
## archetypes and hair growth all work the same; only how the model is built and coloured differs.
##
## Each part was baked in Blender with its colours set to WHITE, so its texture (or vertex colours) holds just the
## painted shading. Colour is applied here: albedo = shade * tint. That matches the Blender look for any colour, so
## skin, hair and every garment piece recolour with no new art.
##
## A recipe is a plain Dictionary (saved with the game):
##   {base: "M"|"F", skin: "#RRGGBB", eye: "#RRGGBB", eye_style: 0.0-1.0,
##    hair: {cut: "...", bangs: "Curtain", accessory: "Headband", color: "#3A2419", accent: ..., tie: ...},
##    garments: [{part: "TR_Hooded_Jacket", colors: {"outer": "#C4602C"}}],
##    weapon: {part: "Classic", carry: "hip"|"back", drawn: false, colors: {"saya": "#6E2028"}}}

const KIT := "res://character/toriyama_kit/"
const UNLIT_MATERIALS := ["MAT_Eye_White", "M9_Eye_Shine", "M9_Pupil", "M9_Face_Ink", "CA_Sclera_Shade"]
const HAIR_COLOR_KEY := {"TR_Hair": "color", "TR_Hair_Accent": "accent", "TR_Hair_Tie": "tie"}
const DEFAULT_SKIN := "#CE9872"
const DEFAULT_EYE := "#784624"
const DEFAULT_HAIR := "#3A2419"

var recipe: Dictionary = {}

## "hair" / "bangs" / "accessory" / garment part name -> {root, meshes, attachments}.
## A part's meshes are moved onto the shared skeleton when it is attached, so the GLB root it arrived in is empty
## afterwards — removing a part means freeing the meshes (and any bone attachment made for them), not the root.
var _part_roots: Dictionary = {}
var _hair_kit: Dictionary = {}

# ------------------------------------------------------------------ kit data
static func kit_json(part: String, name: String) -> Dictionary:
	var path := "%s%s/%s/kit.json" % [KIT, part, name]
	if name == "" or not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

static func list_parts(part: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(KIT + part)
	if dir:
		for name in dir.get_directories():
			if FileAccess.file_exists("%s%s/%s/kit.json" % [KIT, part, name]):
				out.append(name)
	out.sort()
	return out

static func srgb(value) -> Color:
	if value is Color:
		return value
	if value is String and value != "":
		return Color(value)
	if value is Array and value.size() >= 3:
		return Color8(int(value[0]), int(value[1]), int(value[2]))
	return Color.WHITE

# ------------------------------------------------------------------ assembly
func setup(name_: String) -> void:
	# a kit character is built from a recipe; setup(name) is kept so a plain look name still works
	apply_recipe({"base": name_})

func apply_recipe(new_recipe: Dictionary) -> void:
	recipe = new_recipe.duplicate(true)
	for child in get_children():
		child.queue_free()
	_part_roots.clear()
	hair_meshes.clear()
	_blend_meshes.clear()
	anime_eye_materials.clear()
	anime_mouth_materials.clear()
	var base_name: String = recipe.get("base", "M")
	var base_kit := kit_json("base", base_name)
	if base_kit.is_empty():
		push_warning("ToriyamaKitCharacter: no base kit '%s'" % base_name)
		return
	character_name = recipe.get("name", "Custom")
	model = _instance_part("base", base_name)
	model.name = "Model"
	model.rotation.y = PI               # glTF faces +Z; CharacterRig faces -Z
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_dress(model, base_kit, "base", base_name)
	_apply_hair()
	for garment in recipe.get("garments", []):
		_add_garment(garment)
	manifest = {"hair": {"days_to_overgrown": _hair_kit.get("days_to_overgrown", 30),
			"structure": _hair_kit.get("structure", "loose"),
			"thresholds": _hair_kit.get("thresholds", {"fresh": 0.0, "needs_maintenance": 0.5, "overgrown": 0.85})},
		"services": base_kit.get("services", _default_services()), "eye_style": recipe.get("eye_style", 0.35)}
	_prepare_skeleton()
	# babble voice (voice.gd): stable per identity, lower range on the masculine base; a recipe may pin the pitch
	voice = ToriyamaVoice.for_identity("%s|%s|%s" % [recipe.get("name", ""), recipe.get("skin", ""), recipe.get("eye", "")],
		base_name == "F")
	if recipe.has("voice_pitch"):
		voice.pitch = clampf(float(recipe["voice_pitch"]), 0.6, 2.0)
	set_eye_preset(String(recipe.get("eye_preset", "DQ8")))
	var build: Dictionary = recipe.get("build", {})
	set_body(float(build.get("mass", 0.5)), float(build.get("muscle", 0.5)))
	set_definition(recipe.get("definition", {}))
	set_chin(float(recipe.get("chin", CHIN_DEFAULT)))
	_set_shape("TR_Neck", 1.0)            # see ToriyamaCharacter.setup
	_set_shape("TR_Head_Shape", 1.0)
	set_jaw(float(recipe.get("jaw", JAW_DEFAULT)))
	set_eye_dq(float(recipe.get("eye_dq", EYE_DQ_DEFAULT)))
	_set_shape("TR_Ear_Detail", 1.0)
	set_ears(recipe.get("ears", {}))
	set_widths(recipe.get("widths", {}))
	set_sheet_build(float(recipe.get("sheet_build", 0.0)))
	set_shape_channels(recipe.get("shape", {}))
	set_proportions(float(recipe.get("head_scale", HEAD_SCALE)), float(recipe.get("leg_length", 0.0)))
	_set_shape("Pose_Rest", 1.0)          # arms-down corrective, see ToriyamaCharacter.setup
	_update_cover()
	set_hair_state(&"fresh")
	_apply_weapon()
	_register_motion()
	var rig := get_parent()
	if rig and rig.has_method("refresh_sockets"):
		rig.refresh_sockets()

func _instance_part(part: String, name: String) -> Node3D:
	var scene: PackedScene = load("%s%s/%s/%s.glb" % [KIT, part, name, name])
	var node: Node3D = scene.instantiate()
	add_child(node)
	return node

## Move a part's meshes onto the base skeleton. Every part came from the same rig, so the skin binds by bone name.
## `attachments` collects any BoneAttachment3D made along the way, so the part can be removed cleanly later.
func _adopt(node: Node3D, attachments: Array = []) -> Array[MeshInstance3D]:
	var moved: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if node == model:
			moved.append(mi)
			continue
		var attach := mi.get_parent() as BoneAttachment3D
		if attach:
			var bone := BoneAttachment3D.new()
			bone.name = "Kit_" + attach.bone_name
			bone.bone_name = attach.bone_name
			skeleton.add_child(bone)
			mi.reparent(bone, false)
			attachments.append(bone)
		else:
			mi.reparent(skeleton, false)
			mi.skeleton = mi.get_path_to(skeleton)
		moved.append(mi)
	return moved

## Take a part off the character: its meshes live on the skeleton, so free those, then the holder and the empty
## bone attachments. Without this a new hairstyle would simply pile on top of the old one.
func _remove_part(key: String) -> void:
	var entry: Dictionary = _part_roots.get(key, {})
	_part_roots.erase(key)
	for mesh in entry.get("meshes", []):
		if is_instance_valid(mesh):
			(mesh as Node).queue_free()
	for attachment in entry.get("attachments", []):
		if is_instance_valid(attachment):
			(attachment as Node).queue_free()
	var root_node = entry.get("root", null)
	if is_instance_valid(root_node):
		(root_node as Node).queue_free()
	_blend_meshes = _blend_meshes.filter(func(mi): return is_instance_valid(mi) and not mi.is_queued_for_deletion())

func _dress(node: Node3D, kit: Dictionary, part: String, name: String, part_key := "") -> Array[MeshInstance3D]:
	var attachments: Array = []
	var meshes := _adopt(node, attachments)
	if part_key != "":
		_part_roots[part_key] = {"root": node, "meshes": meshes.duplicate(), "attachments": attachments}
	var mesh_info: Dictionary = kit.get("meshes", {})
	var face_materials: Dictionary = kit.get("face_materials", {})
	for mi in meshes:
		var info: Dictionary = mesh_info.get(String(mi.name), {})
		var tex: Texture2D = null
		if info.get("texture", null) != null:
			tex = load("%s%s/%s/%s" % [KIT, part, name, info["texture"]])
		for surface in info.get("surfaces", []):
			var index := int(surface["index"])
			if index < mi.mesh.get_surface_count():
				mi.set_surface_override_material(index, _surface_material(surface, info, tex, face_materials, part, name, part_key))
		if String(mi.name).begins_with("AE_Eye_"):
			mi.set_surface_override_material(0, _anime_eye_material(String(mi.name).ends_with("_L")))
			mi.visible = false                  # shown by an Anime_* eye preset
		elif String(mi.name).begins_with("AE_Brow_"):
			mi.set_surface_override_material(0, _anime_brow_material())
			mi.visible = false
		elif String(mi.name) == "AE_Mouth":
			mi.set_surface_override_material(0, _anime_mouth_material())
			mi.visible = false
		if mi.mesh.get_blend_shape_count() > 0:
			_blend_meshes.append(mi)
	# Ancient Primal ancestral markings: the base bakes a mask per pattern (kit.json primal_marks); PrimalForm lights it
	var marks: Dictionary = kit.get("primal_marks", {})
	for mi in meshes:
		var by_pattern: Dictionary = marks.get(String(mi.name), {})
		if by_pattern.is_empty():
			continue
		var pattern := String(recipe.get("marking_pattern", "Rising"))
		var rel: String = by_pattern.get(pattern, by_pattern.values()[0])
		var tex: Texture2D = load("%s%s/%s/%s" % [KIT, part, name, rel])
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m:
				m.set_shader_parameter("primal_mask", tex)
	return meshes

## The kit bases never carried hair-service specs; borrow the baked characters' (they are identical for everyone).
static func _default_services() -> Dictionary:
	var path := "res://character/toriyama/June/manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (data as Dictionary).get("services", {}) if data is Dictionary else {}

## The drawn anime eye (Blender work/anime_eye): one card per eye, textured from two atlases (types x frames).
const ANIME_EYE_SHADER := preload("res://character/toriyama_kit/anime_eye/anime_eye.gdshader")
const ANIME_EYE_LIDS := preload("res://character/toriyama_kit/anime_eye/anime_eye_lids.png")
const ANIME_EYE_IRIS := preload("res://character/toriyama_kit/anime_eye/anime_eye_iris.png")
## Atlas row order (anime_eye.json). Creator presets are "Anime_" + one of these.
const ANIME_EYE_TYPES := ["Curious_Doe", "Sleek_Cat", "Heroine", "Intense_Hero", "Focused_Almond", "Brawler", "Toriyama"]

func _anime_eye_material(left: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ANIME_EYE_SHADER
	m.set_shader_parameter("lids", ANIME_EYE_LIDS)
	m.set_shader_parameter("iris", ANIME_EYE_IRIS)
	m.set_shader_parameter("grid", Vector2(ANIME_EYE_FRAMES.size(), ANIME_EYE_TYPES.size()))
	m.set_shader_parameter("side", 1.0 if left else -1.0)
	m.set_shader_parameter("eye_color", eye_color())
	anime_eye_materials.append(m)
	return m

## The matching drawn brow (ae_brow.py), hair-coloured, driven by the same frame/type uniforms as the eyes.
const ANIME_BROW_SHADER := preload("res://character/toriyama_kit/anime_eye/anime_brow.gdshader")
const ANIME_BROW_MASKS := preload("res://character/toriyama_kit/anime_eye/anime_brow.png")

func _anime_brow_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ANIME_BROW_SHADER
	m.set_shader_parameter("brows", ANIME_BROW_MASKS)
	m.set_shader_parameter("grid", Vector2(ANIME_EYE_FRAMES.size(), ANIME_EYE_TYPES.size()))
	m.set_shader_parameter("brow_color", hair_color())
	anime_eye_materials.append(m)
	return m

## The drawn mouth (ae_mouth.py): plain style on the masculine base, soft (lower-lip hint) on the feminine one.
const ANIME_MOUTH_SHADER := preload("res://character/toriyama_kit/anime_eye/anime_mouth.gdshader")
const ANIME_MOUTH_ATLAS := preload("res://character/toriyama_kit/anime_eye/anime_mouth.png")
const ANIME_MOUTH_TONGUE := preload("res://character/toriyama_kit/anime_eye/anime_mouth_tongue.png")

func _anime_mouth_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ANIME_MOUTH_SHADER
	m.set_shader_parameter("mouth", ANIME_MOUTH_ATLAS)
	m.set_shader_parameter("tongue", ANIME_MOUTH_TONGUE)
	m.set_shader_parameter("grid", Vector2(ANIME_MOUTH_FRAMES.size(), 2))
	m.set_shader_parameter("type_index", 1 if String(recipe.get("base", "M")) == "F" else 0)
	anime_mouth_materials.append(m)
	return m

func _surface_material(surface: Dictionary, info: Dictionary, tex: Texture2D, face_materials: Dictionary,
		part: String, name: String, part_key: String) -> ShaderMaterial:
	var material_name: String = surface.get("material", "")
	if face_materials.has(material_name) and material_name != "MAT_Skin":
		return _face_material(material_name, face_materials[material_name], part, name)
	var mat: ShaderMaterial
	if info.get("vertex_colors", null) != null:
		mat = _paint(1)
		mat.next_pass = _ink(2.0)
	else:
		mat = _paint(0, tex)
		mat.next_pass = _ink(2.4)
	mat.set_shader_parameter("tint", _tint_for(surface, part, part_key))
	return mat

func _face_material(material_name: String, face: Dictionary, part: String, name: String) -> ShaderMaterial:
	if face.get("texture", null) != null:      # the iris, tinted by eye colour
		var mat := _paint(0, load("%s%s/%s/%s" % [KIT, part, name, face["texture"]]), Color.WHITE, true)
		mat.set_shader_parameter("tint", eye_color())
		mat.set_shader_parameter("retro_detail", 4.0)
		return mat
	var flat := _paint(2, null, _face_color(material_name, face), material_name in UNLIT_MATERIALS)
	flat.set_shader_parameter("retro_detail", 3.0)
	return flat

## Colour for one surface: the recipe's choice for that role, else the colour the part was designed in.
func _tint_for(surface: Dictionary, part: String, part_key: String) -> Color:
	var role: String = surface.get("role", "cloth")
	var material_name: String = surface.get("material", "")
	if part == "hair":
		var hair: Dictionary = recipe.get("hair", {})
		var key: String = HAIR_COLOR_KEY.get(material_name, "color")
		if hair.has(key):
			return srgb(hair[key])
		if hair.has("color"):
			return srgb(hair["color"])
	elif material_name == "MAT_Skin" or role == "skin":
		return skin_color()
	elif part == "garment":
		var colors := garment_colors(part_key)
		if colors.has(role):
			return srgb(colors[role])
		if colors.has(material_name):
			return srgb(colors[material_name])
	elif part == "prop":
		var wcolors := weapon_colors()
		if wcolors.has(role):
			return srgb(wcolors[role])
		if wcolors.has(material_name):
			return srgb(wcolors[material_name])
	if surface.get("default_srgb", null) != null:
		return srgb(surface["default_srgb"])
	return Color.WHITE

func garment_colors(part_name: String) -> Dictionary:
	for garment in recipe.get("garments", []):
		if String(garment.get("part", "")) == part_name:
			return garment.get("colors", {})
	return {}

func skin_color() -> Color:
	return srgb(recipe.get("skin", DEFAULT_SKIN))

func eye_color() -> Color:
	return srgb(recipe.get("eye", DEFAULT_EYE))

func hair_color() -> Color:
	return srgb((recipe.get("hair", {}) as Dictionary).get("color", DEFAULT_HAIR))

## Brows follow the hair, darker — the same rule the Blender materials use.
func _face_color(material_name: String, face: Dictionary) -> Color:
	if material_name == "CA_Brow":
		var c := hair_color()
		return Color(c.r * 0.3, c.g * 0.3, c.b * 0.3)
	if material_name == "MAT_Skin" or face.get("role", "") == "skin":
		return skin_color()
	return srgb(face.get("srgb", [128, 128, 128]))

# ------------------------------------------------------------------ parts
func _add_garment(garment: Dictionary) -> void:
	var part_name: String = garment.get("part", "")
	var kit := kit_json("garment", part_name)
	if kit.is_empty():
		push_warning("ToriyamaKitCharacter: no garment kit '%s'" % part_name)
		return
	var node := _instance_part("garment", part_name)
	node.name = "Garment_" + part_name
	_dress(node, kit, "garment", part_name, part_name)
	set_definition(recipe.get("definition", {}))
	_set_shape("Pose_Rest", 1.0)
	if skeleton:
		_register_motion()

## Hair is itself modular: a style, optional bangs and an optional accessory, stacked on the same head.
func _apply_hair() -> void:
	var hair: Dictionary = recipe.get("hair", {})
	hair_meshes.clear()
	_hair_kit = {}
	var pieces := {"hair": String(hair.get("cut", ""))}
	if String(hair.get("bangs", "")) != "":
		pieces["bangs"] = "F_Bangs_" + String(hair["bangs"])
	if String(hair.get("accessory", "")) != "":
		pieces["accessory"] = "F_Accessory_" + String(hair["accessory"])
	for key in pieces:
		var cut: String = pieces[key]
		var kit := kit_json("hair", cut)
		if kit.is_empty():
			continue
		if key == "hair":
			_hair_kit = kit
		var node := _instance_part("hair", cut)
		node.name = "Hair_" + cut
		for mi in _dress(node, kit, "hair", cut, key):
			var info: Dictionary = kit["meshes"].get(String(mi.name), {})
			var state := StringName(info.get("state", "fresh"))
			hair_meshes[state] = hair_meshes.get(state, []) if hair_meshes.get(state) is Array else []
			var list: Array = hair_meshes[state]
			list.append(mi)
			hair_meshes[state] = list

## hair_meshes holds a list per state here (style + bangs + accessory), so show/hide the whole set.
func set_hair_state(state: StringName) -> void:
	for s in hair_meshes:
		for mi in (hair_meshes[s] as Array):
			(mi as MeshInstance3D).visible = (s == state)
	if state != hair_state:
		hair_state = state
		hair_state_changed.emit(state)
	hair_state = state

## Body definition shapes (added on top of the locked base body): fuller chest and hips, a narrower waist,
## broader shoulders, a chest plate, lat spread. 0..1 each, all 0 by default.
const DEFINITION := ["Bust", "Hips", "Waist", "Shoulders", "Pecs", "Back"]

func set_definition(values: Dictionary) -> void:
	var current: Dictionary = recipe.get("definition", {})
	for key in values:
		current[key] = clampf(float(values[key]), 0.0, 1.0)
	recipe["definition"] = current
	for key in DEFINITION:
		_set_shape("Def_" + key, float(current.get(key, 0.0)))

## Chin (TR_Chin on the head, tr_fit_fixes.py): the base head sloped straight back from the lip to the neck, so every
## character holds this at 1 unless the creator's Chin slider moves it (0 = the old flat chin, 1.5 = strong).
const CHIN_DEFAULT := 1.0

func set_widths(values: Dictionary) -> void:
	var current: Dictionary = recipe.get("widths", {})
	for key in values:
		current[key] = clampf(float(values[key]), -0.5, 1.5)
	recipe["widths"] = current
	super.set_widths(current)

## Sheet build (SB_Sheet_M / SB_Sheet_F, Blender work/sheet_body): the stocky character-sheet body - thicker legs,
## fuller torso, bigger hands and feet, thicker neck - on the body, its neck and every garment together. 0 = the
## standard base, 1 = the sheets. Only the key matching the base mesh is used; the other is held at 0.
func set_sheet_build(amount: float) -> void:
	recipe["sheet_build"] = clampf(amount, 0.0, 1.0)
	var base_name := String(recipe.get("base", "M"))
	for tag in ["M", "F"]:
		_set_shape("SB_Sheet_" + tag, recipe["sheet_build"] if tag == base_name else 0.0)

## Body channels (Blender tr_body_shapes.py, on the body, head, face and every garment): "belly" (round forward mass,
## no shoulder term - Bram, Grandpa), "posture" (rounded upper back, head forward - old age, Sergio's stoop) and
## "definition" (muscle relief). recipe["shape"] = {"belly": 0..1, "posture": 0..1, "definition": 0..1}.
const SHAPE_CHANNELS := {"belly": "TR_Belly", "posture": "TR_Posture", "definition": "TR_Definition"}

func set_shape_channels(values: Dictionary) -> void:
	var current: Dictionary = recipe.get("shape", {})
	for key in values:
		current[key] = clampf(float(values[key]), 0.0, 1.0)
	recipe["shape"] = current
	for key in SHAPE_CHANNELS:
		_set_shape(SHAPE_CHANNELS[key], float(current.get(key, 0.0)))

## One of CreatorData.BODY_TYPES: sets height (head scale + leg length), widths and the definition channels at once.
func set_body_type(type_name: String) -> void:
	var spec: Dictionary = CreatorData.BODY_TYPES.get(type_name, {})
	if spec.is_empty():
		return
	recipe["body_type"] = type_name
	var want_base: String = String(spec.get("base", recipe.get("base", "M")))
	if want_base != String(recipe.get("base", "M")):
		# a different base mesh: fold the whole preset into the recipe and reassemble ONCE (re-entering after
		# apply_recipe touched meshes it had just freed)
		var next_recipe: Dictionary = recipe.duplicate(true)
		next_recipe["base"] = want_base
		next_recipe["body_type"] = type_name
		next_recipe["head_scale"] = float(spec.get("head_scale", HEAD_SCALE))
		next_recipe["leg_length"] = float(spec.get("leg_length", 0.0))
		next_recipe["sheet_build"] = float(spec.get("sheet_build", 0.0))
		next_recipe["widths"] = (spec.get("widths", {}) as Dictionary).duplicate()
		next_recipe["definition"] = (spec.get("definition", {}) as Dictionary).duplicate()
		if spec.has("build"):
			next_recipe["build"] = (spec["build"] as Dictionary).duplicate()
		apply_recipe(next_recipe)
		return
	recipe["head_scale"] = float(spec.get("head_scale", HEAD_SCALE))
	recipe["leg_length"] = float(spec.get("leg_length", 0.0))
	set_proportions(recipe["head_scale"], recipe["leg_length"])
	set_sheet_build(float(spec.get("sheet_build", 0.0)))
	set_widths(spec.get("widths", {}))
	set_definition(spec.get("definition", {}))
	var build: Dictionary = spec.get("build", {})
	if not build.is_empty():
		recipe["build"] = build.duplicate()
		set_body(float(build.get("mass", 0.5)), float(build.get("muscle", 0.5)))

func set_ears(values: Dictionary) -> void:
	var current: Dictionary = recipe.get("ears", {})
	for key in values:
		current[key] = clampf(float(values[key]), -1.0, 1.5)
	recipe["ears"] = current
	super.set_ears(current)

func set_eye_dq(amount: float) -> void:
	recipe["eye_dq"] = clampf(amount, 0.0, 1.0)
	_set_shape("TR_Eye_DQ", recipe["eye_dq"])

func set_jaw(amount: float) -> void:
	recipe["jaw"] = clampf(amount, 0.0, 1.5)
	_set_shape("TR_Jaw", recipe["jaw"])

func set_chin(amount: float) -> void:
	recipe["chin"] = clampf(amount, 0.0, 1.5)
	_set_shape("TR_Chin", recipe["chin"])

## Eye shape presets, each its own blend shape on the eyes and brows (the brows follow the eyes):
## DQ8 (the base), DB (Dragon Ball), Sharp, Wide, Round, Narrow, Sleepy.
const EYE_PRESETS := ["DQ8", "DB", "Sharp", "Wide", "Round", "Narrow", "Sleepy"]

func set_eye_preset(preset: String) -> void:
	recipe["eye_preset"] = preset
	# Anime_<Type>: the drawn eye cards replace the modelled eyes (brows stay); anything else shows the modelled eyes
	var anime := ANIME_EYE_TYPES.find(preset.trim_prefix("Anime_")) if preset.begins_with("Anime_") else -1
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false) if model else []:
		var n := String(mi.name)
		if n.begins_with("AE_Eye_") or n.begins_with("AE_Brow_") or n == "AE_Mouth":
			mi.visible = anime >= 0
		elif n in ["Eye_L", "Eye_R", "Brow_L", "Brow_R", "Mouth"]:
			mi.visible = anime < 0
	if anime >= 0:
		for m in anime_eye_materials:
			m.set_shader_parameter("type_index", anime)
		_update_anime_eye()
	for name in EYE_PRESETS:
		if name == "DQ8":
			continue
		_set_shape("Eye_Style_" + name, 1.0 if name == preset else 0.0)
		_set_shape("Brow_Style_" + name, 1.0 if name == preset else 0.0)

# ------------------------------------------------------------------ live edits (the creator)
func set_skin(color) -> void:
	recipe["skin"] = srgb(color).to_html(false)
	_recolor()

func set_eye_color(color) -> void:
	recipe["eye"] = srgb(color).to_html(false)
	_recolor()

func set_hair_colors(colors: Dictionary) -> void:
	var hair: Dictionary = recipe.get("hair", {})
	for key in colors:
		hair[key] = srgb(colors[key]).to_html(false)
	recipe["hair"] = hair
	_recolor()

func set_hair_style(cut: String, bangs := "", accessory := "") -> void:
	var hair: Dictionary = recipe.get("hair", {})
	hair["cut"] = cut
	hair["bangs"] = bangs
	hair["accessory"] = accessory
	recipe["hair"] = hair
	for key in ["hair", "bangs", "accessory"]:
		_remove_part(key)
	_apply_hair()
	set_hair_state(hair_state)
	set_eye_preset(String(recipe.get("eye_preset", "DQ8")))
	_register_motion()

func set_garment(slot: String, part_name: String, colors := {}) -> void:
	var garments: Array = recipe.get("garments", [])
	for i in range(garments.size() - 1, -1, -1):
		var existing: Dictionary = garments[i]
		if garment_slot(existing.get("part", "")) == slot:
			_remove_part(String(existing.get("part", "")))
			garments.remove_at(i)
	if part_name != "":
		garments.append({"part": part_name, "colors": colors})
	recipe["garments"] = garments
	if part_name != "":
		_add_garment({"part": part_name, "colors": colors})
	set_sheet_build(float(recipe.get("sheet_build", 0.0)))
	set_shape_channels(recipe.get("shape", {}))
	_update_cover()
	var build: Dictionary = recipe.get("build", {})
	set_body(float(build.get("mass", 0.5)), float(build.get("muscle", 0.5)))

func set_garment_color(part_name: String, role: String, color) -> void:
	for garment in recipe.get("garments", []):
		if String(garment.get("part", "")) == part_name:
			var colors: Dictionary = garment.get("colors", {})
			colors[role] = srgb(color).to_html(false)
			garment["colors"] = colors
	_recolor()

# ------------------------------------------------------------------ weapons (props)
## A prop is not skinned. Each of its meshes bone-attaches to a socket, placed by the WORLD 4x4 the Blender export
## recorded with the rig at rest (kit.json meshes.<mesh>.sockets.<SOCKET-name>).
##
## Not a bone-relative matrix: Blender bones run along their own +Y and glTF has no such rule, so the exporter is
## free to re-axis a bone and a bone-space matrix would not survive the trip. Instead the world matrix is converted
## with the single axis swap glTF applies to the whole scene ((x, y, z) -> (x, z, -y)) and the bone's rest is then
## divided out using what GODOT reports, which already includes whatever the exporter did.
## (The model's own 180 degree spin onto CharacterRig's -Z forward sits above the skeleton, so it does not enter.)
##
## The sword and the saya were modelled in the SAME space, the blade sitting inside the scabbard, so "sheathed" needs
## no second pose: both meshes simply take the carry socket's transform, and drawing moves the sword alone to the hand.
const WEAPON_CARRY := {"hip": "SOCKET-hip", "back": "SOCKET-back"}
const WEAPON_HAND := "SOCKET-hand.R"
const WEAPON_OFFHAND := "SOCKET-hand.L"
const WEAPON_KEY := "__weapon"
static var BLENDER_TO_GODOT := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

## The prop's rest pose in skeleton space: the Blender world matrix with glTF's axis swap applied to both sides.
static func _skeleton_space(mesh_info: Dictionary, socket: String) -> Transform3D:
	var rows: Array = (mesh_info.get("sockets", {}) as Dictionary).get(socket, [])
	if rows.size() < 4:
		return Transform3D.IDENTITY
	# kit.json stores the matrix row-major; a Basis is built from its COLUMNS
	var b := Basis(Vector3(rows[0][0], rows[1][0], rows[2][0]), Vector3(rows[0][1], rows[1][1], rows[2][1]),
		Vector3(rows[0][2], rows[1][2], rows[2][2]))
	var o := Vector3(rows[0][3], rows[1][3], rows[2][3])
	var c := BLENDER_TO_GODOT
	return Transform3D(c * b * c.inverse(), c * o)

func _attach_to_bone(mi: MeshInstance3D, bone_name: String, rest_pose: Transform3D, attachments: Array) -> void:
	if skeleton == null:
		return
	var idx := skeleton.find_bone(bone_name)
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "Kit_" + bone_name
	att.bone_name = bone_name
	skeleton.add_child(att)
	if mi.get_parent():
		mi.get_parent().remove_child(mi)
	att.add_child(mi)
	# the attachment IS the bone, so the mesh's local transform is its rest pose with the bone's rest divided out
	mi.transform = skeleton.get_bone_global_rest(idx).affine_inverse() * rest_pose
	attachments.append(att)

func _apply_weapon() -> void:
	_remove_part(WEAPON_KEY)
	_remove_part(WEAPON_KEY + "_off")
	var weapon: Dictionary = recipe.get("weapon", {})
	var part_name := String(weapon.get("part", ""))
	if part_name == "":
		return
	var kit := kit_json("prop", part_name)
	if kit.is_empty():
		push_warning("ToriyamaKitCharacter: no prop kit '%s'" % part_name)
		return
	var node := _instance_part("prop", part_name)
	node.name = "Weapon_" + part_name
	var carry := String(weapon.get("carry", "hip"))
	var carry_bone: String = WEAPON_CARRY.get(carry, "SOCKET-hip")
	var drawn := bool(weapon.get("drawn", false))
	var mesh_info: Dictionary = kit.get("meshes", {})
	var attachments: Array = []
	var meshes: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var info: Dictionary = mesh_info.get(String(mi.name), {})
		var is_sword := String(mi.name) == String(kit.get("sword", ""))
		var bone := WEAPON_HAND if (is_sword and drawn) else carry_bone
		_attach_to_bone(mi, bone, _skeleton_space(info, bone), attachments)
		var tex: Texture2D = null
		if info.get("texture", null) != null:
			tex = load("%sprop/%s/%s" % [KIT, part_name, info["texture"]])
		for surface in info.get("surfaces", []):
			var index := int(surface["index"])
			if index < mi.mesh.get_surface_count():
				mi.set_surface_override_material(index, _surface_material(surface, info, tex, {}, "prop", part_name, WEAPON_KEY))
		meshes.append(mi)
	# Dual wield: a second copy of the prop, with only its blade kept and hung on the LEFT hand. The export records
	# every socket for both meshes, so the off-hand transform is already there; what is not is a second scabbard,
	# which would sit inside the first one on the same hip - so the spare saya is dropped rather than stacked.
	if bool(weapon.get("dual", false)) and drawn:
		var off := _instance_part("prop", part_name)
		off.name = "WeaponOff_" + part_name
		for mi: MeshInstance3D in off.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name) != String(kit.get("sword", "")):
				mi.queue_free()
				continue
			var info2: Dictionary = mesh_info.get(String(mi.name), {})
			_attach_to_bone(mi, WEAPON_OFFHAND, _skeleton_space(info2, WEAPON_OFFHAND), attachments)
			var tex2: Texture2D = null
			if info2.get("texture", null) != null:
				tex2 = load("%sprop/%s/%s" % [KIT, part_name, info2["texture"]])
			for surface in info2.get("surfaces", []):
				var index2 := int(surface["index"])
				if index2 < mi.mesh.get_surface_count():
					mi.set_surface_override_material(index2, _surface_material(surface, info2, tex2, {}, "prop", part_name, WEAPON_KEY))
			meshes.append(mi)
		_part_roots[WEAPON_KEY + "_off"] = {"root": off, "meshes": [], "attachments": []}
	_part_roots[WEAPON_KEY] = {"root": node, "meshes": meshes.duplicate(), "attachments": attachments}

## Pick a weapon (a prop kit name, "" for none). `carry` is where the scabbard rides when the sword is away.
func set_weapon(part_name: String, carry := "hip", colors := {}, dual := false) -> void:
	if part_name == "":
		recipe.erase("weapon")
	else:
		var weapon: Dictionary = recipe.get("weapon", {})
		weapon["part"] = part_name
		weapon["carry"] = carry
		weapon["colors"] = colors if not colors.is_empty() else weapon.get("colors", {})
		weapon["drawn"] = bool(weapon.get("drawn", false))
		weapon["dual"] = dual
		recipe["weapon"] = weapon
	_apply_weapon()

## Draw or sheathe: only the sword moves, the scabbard stays where it is carried.
func set_weapon_drawn(drawn: bool) -> void:
	var weapon: Dictionary = recipe.get("weapon", {})
	if weapon.is_empty():
		return
	weapon["drawn"] = drawn
	recipe["weapon"] = weapon
	_apply_weapon()

func weapon_colors() -> Dictionary:
	return (recipe.get("weapon", {}) as Dictionary).get("colors", {})

## Body regions under clothing draw in ~1-1.4 cm (Cover_* keys, body only) so skin never pokes through - at the
## shoulder seams, under a tank top, at the knees while walking, through shoes. Each key follows what is worn:
## tops cover the torso; long bottoms thighs + shins, shorts/skirts thighs only; thigh-highs the shins; shoes the feet.
const SHORT_BOTTOMS := ["TR_Cargo_Shorts", "TR_Pleated_Skirt"]
func _update_cover() -> void:
	var cover := {"Top": false, "Thighs": false, "Shins": false, "Feet": false}
	for g in recipe.get("garments", []):
		var part := String(g.get("part", ""))
		match garment_slot(part):
			"top", "outerwear":
				cover["Top"] = true
			"bottom":
				cover["Thighs"] = true
				if part not in SHORT_BOTTOMS:
					cover["Shins"] = true
			"legwear":
				if part == "TR_Thigh_Highs":
					cover["Shins"] = true
			"shoes":
				cover["Feet"] = true
	for region in cover:
		_set_shape("Cover_" + region, 1.0 if cover[region] else 0.0)

static func garment_slot(part_name: String) -> String:
	var kit := kit_json("garment", part_name)
	return kit.get("slot", "accessory")

## Re-tint everything in place (cheap: no meshes are rebuilt), after a colour change.
func _recolor() -> void:
	var base_kit := kit_json("base", recipe.get("base", "M"))
	_retint(model, base_kit, "base", recipe.get("base", "M"), "")
	for m in anime_eye_materials:
		m.set_shader_parameter("eye_color", eye_color())
		m.set_shader_parameter("brow_color", hair_color())
	for key in _part_roots:
		var node: Node3D = (_part_roots[key] as Dictionary).get("root", null)
		if not is_instance_valid(node):
			continue
		if key in ["hair", "bangs", "accessory"]:
			var cut: String = String(node.name).trim_prefix("Hair_")
			_retint(node, kit_json("hair", cut), "hair", cut, key)
		else:
			_retint(node, kit_json("garment", key), "garment", key, key)

func _retint(node: Node3D, kit: Dictionary, part: String, name: String, part_key: String) -> void:
	var mesh_info: Dictionary = kit.get("meshes", {})
	var face_materials: Dictionary = kit.get("face_materials", {})
	for mesh_name in mesh_info:
		var mi := skeleton.find_child(mesh_name, true, false) as MeshInstance3D
		if mi == null:
			mi = node.find_child(mesh_name, true, false) as MeshInstance3D
		if mi == null:
			continue
		var info: Dictionary = mesh_info[mesh_name]
		for surface in info.get("surfaces", []):
			var index := int(surface["index"])
			var mat := mi.get_surface_override_material(index) as ShaderMaterial
			if mat == null:
				continue
			var material_name: String = surface.get("material", "")
			if face_materials.has(material_name) and material_name != "MAT_Skin":
				var face: Dictionary = face_materials[material_name]
				if face.get("texture", null) != null:
					mat.set_shader_parameter("tint", eye_color())
				else:
					mat.set_shader_parameter("flat_color", _face_color(material_name, face))
			else:
				mat.set_shader_parameter("tint", _tint_for(surface, part, part_key))
