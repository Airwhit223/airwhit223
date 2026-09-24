@tool
class_name Beastfolk
extends Node3D
## Attach to an instance of beastfolk_male.glb or beastfolk_female.glb.
## Pick a species and form, and set colors, in the Inspector.

enum Species { HUMAN, CAT, WOLF, FOX, BEAR, SHARK }
enum Form { HYBRID, BEAST }  ## HYBRID: human head + ears + tail. BEAST: animal head, furred body.

const SPECIES_NAMES := ["human", "cat", "wolf", "fox", "bear", "shark"]
## Default fur (primary, markings) per species, used when use_species_colors is on.
const SPECIES_FUR := {
	"cat": [Color(0.55, 0.4, 0.26), Color(0.93, 0.85, 0.72)],
	"wolf": [Color(0.38, 0.4, 0.46), Color(0.78, 0.78, 0.8)],
	"fox": [Color(0.9, 0.42, 0.14), Color(0.98, 0.95, 0.9)],
	"bear": [Color(0.46, 0.28, 0.16), Color(0.72, 0.52, 0.34)],
	"shark": [Color(0.46, 0.5, 0.56), Color(0.86, 0.88, 0.9)],
	"human": [Color(0.5, 0.5, 0.5), Color(0.8, 0.8, 0.8)],
}

@export var species: Species = Species.WOLF:
	set(v): species = v; _apply()
@export var form: Form = Form.HYBRID:
	set(v): form = v; _apply()
@export var show_clothes := true:
	set(v): show_clothes = v; _apply()

@export_group("Colors")
@export var use_species_colors := true:
	set(v): use_species_colors = v; _apply()
@export var fur_color := Color(0.38, 0.4, 0.46):
	set(v): fur_color = v; _apply()
@export var fur_markings := Color(0.78, 0.78, 0.8):
	set(v): fur_markings = v; _apply()
@export var skin_color := Color(0.93, 0.76, 0.62):
	set(v): skin_color = v; _apply()
@export var hair_color := Color(0.1, 0.09, 0.1):
	set(v): hair_color = v; _apply()
@export var hair_highlight := Color(0.25, 0.23, 0.27):
	set(v): hair_highlight = v; _apply()
@export var shirt_color := Color(0.1, 0.1, 0.12):
	set(v): shirt_color = v; _apply()
@export var pants_color := Color(0.33, 0.45, 0.62):
	set(v): pants_color = v; _apply()
@export var boots_color := Color(0.35, 0.27, 0.2):
	set(v): boots_color = v; _apply()
@export var boots_sole := Color(0.15, 0.12, 0.1):
	set(v): boots_sole = v; _apply()
@export var outline_width := 0.006:
	set(v): outline_width = v; _apply()

const SHADER := preload("res://characters/beastfolk/beastfolk_toon.gdshader")


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	var sp: String = SPECIES_NAMES[species]
	var beast := form == Form.BEAST and species != Species.HUMAN
	var fur := fur_color
	var marks := fur_markings
	if use_species_colors:
		fur = SPECIES_FUR[sp][0]
		marks = SPECIES_FUR[sp][1]
	var body_a := fur if beast else skin_color
	var body_b := marks if beast else skin_color

	for mi in find_children("*", "MeshInstance3D", true, false):
		var part := _part_name(mi.name)
		var show := true
		var tint := [body_a, body_b]
		var tinted := true
		match part:
			"body", "hands":
				pass
			"head_human":
				show = not beast
				tint = [skin_color, skin_color]
			"face_human":
				show = not beast
				tinted = false
			"hair":
				show = not beast
				tint = [hair_color, hair_highlight]
			"shirt":
				show = show_clothes
				tint = [shirt_color, shirt_color]
			"pants":
				show = show_clothes
				tint = [pants_color, pants_color]
			"boots":
				show = show_clothes
				tint = [boots_color, boots_sole]
			_:
				var bits := part.split("_")
				var kind := bits[0]
				var owner_sp := bits[1] if bits.size() > 1 else ""
				match kind:
					"ears":
						show = not beast and owner_sp == sp
						tint = [fur, marks]
					"head":
						show = beast and owner_sp == sp
						tint = [fur, marks]
					"face":
						show = beast and owner_sp == sp
						tinted = false
					"tail", "fin":
						show = owner_sp == sp
						tint = [fur, marks]
		mi.visible = show
		if show:
			mi.material_override = _material(tinted, tint[0], tint[1])


func _part_name(node_name: String) -> String:
	# Blender object names come through as node names, sometimes with a suffix.
	for known in ["body", "hands", "head_human", "face_human", "hair", "shirt", "pants", "boots"]:
		if node_name == known or node_name.begins_with(known + "_0") or node_name.begins_with(known + "."):
			return known
	return node_name.get_slice(".", 0)


func _material(tinted: bool, a: Color, b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tinted", tinted)
	mat.set_shader_parameter("primary", a)
	mat.set_shader_parameter("secondary", b)
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.albedo_color = Color(0.08, 0.06, 0.07)
	outline.grow = true
	outline.grow_amount = outline_width
	mat.next_pass = outline
	return mat
