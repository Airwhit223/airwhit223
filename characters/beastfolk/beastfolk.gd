@tool
class_name Beastfolk
extends Node3D
## Attach to a Node3D whose child is an instance of beastfolk_male.glb or
## beastfolk_female.glb. Pick species, form, outfit and colors in the Inspector.

enum Species { HUMAN, CAT, WOLF, FOX, BEAR, SHARK, LIZARD, FISH, EEL, OCTOPUS, MANTA, CORAL }
enum Form { HYBRID, BEAST }  ## HYBRID: human head + ears/fins + tail. BEAST: animal head.
enum Top { TEE, TANK, NONE }
enum Bottom { PANTS, SHORTS, NONE }

const SPECIES_NAMES := ["human", "cat", "wolf", "fox", "bear", "shark", "lizard", "fish", "eel", "octopus",
	"manta", "coral"]
## Species with an animal head for the BEAST form.
const HEADS := ["cat", "wolf", "fox", "bear", "shark", "lizard", "octopus", "manta", "eel"]
## Species whose skin is their species color even in HYBRID form.
const COLORED_SKIN := ["shark", "lizard", "fish", "eel", "octopus", "manta", "coral"]
## Species that are bald in HYBRID form.
const BALD := ["fish", "eel", "octopus", "manta", "shark", "lizard"]
## Hybrid ear part per species.
const EARS := {"cat": "ears_cat", "wolf": "ears_wolf", "fox": "ears_fox", "bear": "ears_bear",
	"fish": "ears_fish", "eel": "ears_fish", "coral": "ears_coral"}
## Default colors per species: [main, markings, spots].
const SPECIES_COLORS := {
	"human": [Color(0.93, 0.76, 0.62), Color(0.93, 0.76, 0.62), Color(0.93, 0.76, 0.62)],
	"cat": [Color(0.55, 0.4, 0.26), Color(0.93, 0.85, 0.72), Color(0.35, 0.24, 0.15)],
	"wolf": [Color(0.38, 0.4, 0.46), Color(0.78, 0.78, 0.8), Color(0.28, 0.3, 0.34)],
	"fox": [Color(0.9, 0.42, 0.14), Color(0.98, 0.95, 0.9), Color(0.7, 0.3, 0.1)],
	"bear": [Color(0.46, 0.28, 0.16), Color(0.72, 0.52, 0.34), Color(0.36, 0.2, 0.1)],
	"shark": [Color(0.4, 0.55, 0.72), Color(0.86, 0.9, 0.93), Color(0.34, 0.47, 0.62)],
	"lizard": [Color(0.82, 0.68, 0.42), Color(0.95, 0.88, 0.72), Color(0.45, 0.32, 0.18)],
	"fish": [Color(0.55, 0.85, 0.8), Color(0.75, 0.62, 0.9), Color(0.45, 0.72, 0.8)],
	"eel": [Color(0.12, 0.2, 0.28), Color(0.2, 0.3, 0.4), Color(0.3, 0.95, 0.85)],
	"octopus": [Color(0.55, 0.45, 0.85), Color(0.6, 0.85, 0.75), Color(0.4, 0.75, 0.7)],
	"manta": [Color(0.3, 0.32, 0.36), Color(0.85, 0.87, 0.9), Color(0.25, 0.27, 0.3)],
	"coral": [Color(0.97, 0.6, 0.55), Color(1.0, 0.8, 0.75), Color(0.9, 0.45, 0.45)],
}

@export var species: Species = Species.WOLF:
	set(v): species = v; _apply()
@export var form: Form = Form.HYBRID:
	set(v): form = v; _apply()

@export_group("Outfit")
@export var top: Top = Top.TEE:
	set(v): top = v; _apply()
@export var bottom: Bottom = Bottom.PANTS:
	set(v): bottom = v; _apply()
@export var show_boots := true:
	set(v): show_boots = v; _apply()

@export_group("Colors")
@export var use_species_colors := true:
	set(v): use_species_colors = v; _apply()
@export var fur_color := Color(0.38, 0.4, 0.46):
	set(v): fur_color = v; _apply()
@export var fur_markings := Color(0.78, 0.78, 0.8):
	set(v): fur_markings = v; _apply()
@export var spot_color := Color(0.3, 0.3, 0.3):
	set(v): spot_color = v; _apply()
@export var skin_color := Color(0.93, 0.76, 0.62):
	set(v): skin_color = v; _apply()
@export var hair_color := Color(0.1, 0.09, 0.1):
	set(v): hair_color = v; _apply()
@export var hair_highlight := Color(0.25, 0.23, 0.27):
	set(v): hair_highlight = v; _apply()
@export var top_color := Color(0.1, 0.1, 0.12):
	set(v): top_color = v; _apply()
@export var bottom_color := Color(0.33, 0.45, 0.62):
	set(v): bottom_color = v; _apply()
@export var boots_color := Color(0.35, 0.27, 0.2):
	set(v): boots_color = v; _apply()
@export var boots_sole := Color(0.15, 0.12, 0.1):
	set(v): boots_sole = v; _apply()
@export var outline_width := 0.006:
	set(v): outline_width = v; _apply()

const SHADER := preload("res://characters/beastfolk/beastfolk_toon.gdshader")
const SPOTTED := ["lizard", "eel", "octopus", "cat", "shark"]


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	var sp: String = SPECIES_NAMES[species]
	var beast := form == Form.BEAST and sp in HEADS
	var cols: Array = SPECIES_COLORS[sp] if use_species_colors else [fur_color, fur_markings, spot_color]
	var fur: Color = cols[0]
	var marks: Color = cols[1]
	var spot: Color = cols[2]
	var colored_skin := beast or sp in COLORED_SKIN
	var skin := fur if colored_skin else skin_color
	var body := [skin, marks if beast else skin, spot]
	var bald := sp in BALD

	for mi in find_children("*", "MeshInstance3D", true, false):
		var part := _part_name(mi.name)
		var show := true
		var tint := body
		var tinted := true
		match part:
			"body", "hands":
				pass
			"head_human":
				show = not beast
				tint = [skin, skin, spot]
			"face_human":
				show = not beast
				tinted = false
			"hair":
				show = not beast and not bald
				tint = [hair_color, hair_highlight, hair_color]
			"shirt":
				show = top == Top.TEE
				tint = [top_color, top_color, top_color]
			"tank":
				show = top == Top.TANK
				tint = [top_color, top_color, top_color]
			"pants":
				show = bottom == Bottom.PANTS
				tint = [bottom_color, bottom_color, bottom_color]
			"shorts":
				show = bottom == Bottom.SHORTS
				tint = [bottom_color, bottom_color, bottom_color]
			"boots":
				show = show_boots
				tint = [boots_color, boots_sole, boots_color]
			_:
				var bits := part.split("_")
				var kind := bits[0]
				var owner_sp := bits[1] if bits.size() > 1 else ""
				tint = [fur, marks, spot]
				match kind:
					"ears":
						show = not beast and EARS.get(sp, "") == part
						if owner_sp == "coral":
							tint = [marks, fur, spot]
					"head":
						show = beast and owner_sp == sp
					"face":
						show = beast and owner_sp == sp
						tinted = false
					"tail", "fin":
						show = owner_sp == sp
		mi.visible = show
		if show:
			mi.material_override = _material(tinted, tint, sp in SPOTTED)


func _part_name(node_name: String) -> String:
	for known in ["body", "hands", "head_human", "face_human", "hair", "shirt", "tank", "pants", "shorts", "boots"]:
		if node_name == known or node_name.begins_with(known + "_0") or node_name.begins_with(known + "."):
			return known
	return node_name.get_slice(".", 0)


func _material(tinted: bool, tint: Array, spotted: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tinted", tinted)
	mat.set_shader_parameter("primary", tint[0])
	mat.set_shader_parameter("secondary", tint[1])
	mat.set_shader_parameter("tertiary", tint[2])
	mat.set_shader_parameter("use_spots", spotted)
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.albedo_color = Color(0.08, 0.06, 0.07)
	outline.grow = true
	outline.grow_amount = outline_width
	mat.next_pass = outline
	return mat
