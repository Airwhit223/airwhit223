class_name BramFamily
extends RefCounted
## Bram's family, from the user's character sheets (docs/references/bram_family/, docs/BRAM_FAMILY_BIBLE.md).
## They run The Good Place - "food, rest, repairs, brighter journeys" - the inn in Olde Town, and live there together.
## Sergio, Grandpa's twin, lives alone in his cliffside workshop far from the village.
##
## Looks are kit recipes built from the creator's existing parts - a FIRST PASS. What the sheets need that the kit
## doesn't have yet (bald-with-fringe hair, big white mustaches, Garrik's beard, aprons, the striped suits, Sergio's
## long coat, Bram's orange pack) is listed in the bible; the stand-ins here are marked "stand-in".

const HOUSEHOLD := "household_good_place"
const HOME := "loc_good_place"
const SERGIO_HOME := "home_sergio"

## The twins share a face: same chin, jaw, ears, eye shape - only their lives differ.
const TWIN_FACE := {"chin": 0.95, "jaw": 0.75, "ears": {"size": 0.35, "point": 0.0, "out": 0.3}, "eye_preset": "DQ8",
	"eye": "#3A2A22"}

static func build() -> Array[NPCDefinition]:
	var out: Array[NPCDefinition] = []
	# ---- Bram: big heart, bigger surprises. Early-game protector (docs/BRAM_CHARACTER_BIBLE.md).
	out.append(_npc("bram", "Bram", 19, 30, "#9E6C52",
		_look("M", "#9E6C52", "#3A2A22", "DQ8", "Sheet build", {"mass": 0.85, "muscle": 0.72},
			{"belly": 0.55, "definition": 0.2}, "RT_M_Spiky_Short", "#1E1A1A", [
			_g("Shirt_Casual_01", {"top": "#1B1A1F", "top_trim": "#1B1A1F", "top_seam": "#3A3A40"}),
			_g("Mechanic_Cargo_Pants", {"bottom": "#5A5438", "stitch": "#3A3A40", "belt": "#1B1A1F", "pouch": "#5A5438"}),
			_g("Mechanic_Work_Boots", {"boot": "#6A4A2E", "sole": "#D8C9A0", "boot_trim": "#C9A24E"}),
			_g("Jones_Scarf", {"scarf": "#EFE9DC"}),                       # the towel round his neck
			_g("TR_Crossbody_Bag", {"bag": "#C4602C", "strap": "#6A4A2E", "metal": "#C9CED8"}),   # stand-in: the orange pack
		], {"height": 1.06, "widths": {"chest": 1.1, "waist": 1.3, "hips": 1.0}}),
		["exploring", "food", "ruins"], {"strength": 70.0, "exploration": 55.0},
		{"extroversion": 0.75, "kindness": 0.95, "ambition": 0.5, "humor": 0.7, "discipline": 0.5},
		[{"day": "ALL", "start": 7, "end": 9, "activity": "HOME_LIFE", "location": HOME},
		 {"day": "ALL", "start": 9, "end": 15, "activity": "ADVENTURE", "location": "loc_adventure"},
		 {"day": "ALL", "start": 17, "end": 22, "activity": "SOCIALIZE", "location": HOME}]))
	# ---- Garrik (Dad): hard work, good food, happy people. Everyone thought he was exaggerating. He wasn't.
	out.append(_npc("garrik", "Garrik", 48, 12, "#9E6C52",
		_look("M", "#9E6C52", "#3A2A22", "DQ8", "Sheet build", {"mass": 0.9, "muscle": 0.85},
			{"belly": 0.4, "definition": 0.35}, "RT_M_Spiky_Short", "#6A6A70", [          # stand-in: no beard yet
			_g("Shirt_Casual_01", {"top": "#3A3A40", "top_trim": "#3A3A40", "top_seam": "#1B1A1F"}),
			_g("Jones_Cargo_Pants", {"bottom": "#1B1A1F", "bottom_trim": "#3A3A40"}),
			_g("Jones_Rugged_Boots", {"boot": "#6A4A2E", "sole": "#3A3A40"}),
			_g("Jones_Scarf", {"scarf": "#EFE9DC"}),
			_g("Jones_Gloves", {"gloves": "#6A4A2E"}),
		], {"jaw": 1.1, "chin": 1.1, "height": 1.12, "widths": {"chest": 1.3, "waist": 1.2, "hips": 0.9}}),
		["cooking", "carpentry"], {"strength": 85.0, "cooking": 60.0},
		{"extroversion": 0.8, "kindness": 0.85, "ambition": 0.45, "humor": 0.8, "discipline": 0.7},
		[{"day": "ALL", "start": 6, "end": 22, "activity": "WORK", "location": HOME}]))
	# ---- Lysa (Mom): a full belly is a happy journey.
	out.append(_npc("lysa", "Lysa", 46, 55, "#9E6C52",
		_look("F", "#9E6C52", "#3A2A22", "Round", "Sheet build female", {"mass": 0.85, "muscle": 0.6},
			{"belly": 0.4}, "RT_F_Curly_Long", "#3A2419", [
			_g("Shirt_Casual_01", {"top": "#EFE9DC", "top_trim": "#D8C9A0", "top_seam": "#D8C9A0"}),
			_g("TR_Pleated_Skirt", {"skirt": "#2F5D3A", "skirt_trim": "#D8C9A0"}),   # stand-in: the green apron dress
			_g("Jones_Rugged_Boots", {"boot": "#6A4A2E", "sole": "#3A3A40"}),
			_g("TR_Headband", {"band": "#C4602C", "band_accent": "#D8C9A0"}),
		], {"height": 1.0, "widths": {"chest": 0.9, "waist": 1.1, "hips": 1.3}}),
		["cooking", "gardening"], {"cooking": 80.0, "strength": 60.0},
		{"extroversion": 0.8, "kindness": 0.95, "ambition": 0.4, "humor": 0.75, "discipline": 0.7},
		[{"day": "ALL", "start": 6, "end": 21, "activity": "WORK", "location": HOME}]))
	# ---- Kip (little sibling): shorter, louder, still hits harder.
	out.append(_npc("kip", "Kip", 11, 70, "#9E6C52",
		_look("M", "#9E6C52", "#3A2A22", "Anime_Brawler", "Child", {"mass": 0.65, "muscle": 0.6},
			{"belly": 0.2}, "RT_M_Spiky_Medium", "#1E1A1A", [
			_g("Shirt_Casual_01", {"top": "#EFE9DC", "top_trim": "#B81E2A", "top_seam": "#B81E2A"}),
			_g("TR_Cargo_Shorts", {"bottom": "#6E7078", "bottom_trim": "#3A3A40", "bottom_seam": "#3A3A40", "stitch": "#3A3A40", "metal": "#C9CED8"}),
			_g("Mechanic_Work_Boots", {"boot": "#6A4A2E", "sole": "#D8C9A0", "boot_trim": "#3A3A40"}),
			_g("Jones_Scarf", {"scarf": "#B81E2A"}),                       # the red bandana
		], {"sheet_build": 0.6, "height": 0.74, "widths": {"chest": 0.6, "waist": 0.7, "hips": 0.5}}),
		["wrestling", "exploring"], {"strength": 40.0},
		{"extroversion": 0.95, "kindness": 0.6, "ambition": 0.8, "humor": 0.7, "discipline": 0.2},
		[{"day": "ALL", "start": 8, "end": 12, "activity": "HOME_LIFE", "location": HOME},
		 {"day": "ALL", "start": 12, "end": 18, "activity": "SOCIALIZE", "location": HOME}]))
	# ---- Nana Ella (Grandma): looks sweet? Good. Keep underestimating me.
	out.append(_npc("nana_ella", "Ella", 76, 5, "#9E6C52",
		_look("F", "#9E6C52", "#3A2A22", "Sleepy", "Sheet build female", {"mass": 0.8, "muscle": 0.55},
			{"belly": 0.35, "posture": 0.3}, "Town_Bun", "#D8D4CC", [
			_g("Shirt_Casual_01", {"top": "#EFE9DC", "top_trim": "#D8C9A0", "top_seam": "#D8C9A0"}),
			_g("TR_Pleated_Skirt", {"skirt": "#6E3A8C", "skirt_trim": "#D8C9A0"}),
			_g("Jones_Utility_Jacket", {"outer": "#6E3A8C"}),              # stand-in: her purple shawl
			_g("Jones_Rugged_Boots", {"boot": "#6A4A2E", "sole": "#3A3A40"}),
			_g("TR_Glasses", {"frame": "#D4AF55", "lens": "#C9CED8"}),
		], {"height": 0.93, "widths": {"chest": 1.0, "waist": 1.1, "hips": 1.2}}),
		["gardening", "stories"], {"cooking": 70.0, "wisdom": 75.0},
		{"extroversion": 0.55, "kindness": 0.8, "ambition": 0.3, "humor": 0.85, "discipline": 0.8},
		[{"day": "ALL", "start": 7, "end": 20, "activity": "HOME_LIFE", "location": HOME}]))
	# ---- Grandpa: fixes everything, moves faster than he looks. "Old parts. New stories."
	out.append(_npc("grandpa_bram", "Grandpa", 78, 40, "#CE9872",
		_look("M", "#CE9872", TWIN_FACE["eye"], TWIN_FACE["eye_preset"], "Sheet build", {"mass": 0.95, "muscle": 0.6},
			{"belly": 1.0, "posture": 0.15}, "Short_Crop", "#D8D4CC", [       # stand-in: bald with a white fringe
			_g("Shirt_Casual_01", {"top": "#C9A24E", "top_trim": "#6A4A2E", "top_seam": "#6A4A2E"}),   # stand-in: striped vest
			_g("Pants_Casual_01", {"bottom": "#C9A24E", "bottom_trim": "#6A4A2E", "bottom_seam": "#6A4A2E", "stitch": "#6A4A2E", "metal": "#D4AF55"}),
			_g("TR_Blazer", {"outer": "#EFE9DC", "top_trim": "#D8C9A0", "metal": "#D4AF55", "top_seam": "#D8C9A0"}),   # his white coat
			_g("Mechanic_Work_Boots", {"boot": "#6A4A2E", "sole": "#D8C9A0", "boot_trim": "#C9A24E"}),
			_g("TR_Glasses", {"frame": "#D4AF55", "lens": "#C9CED8"}),
		], _merge(TWIN_FACE, {"height": 0.98, "widths": {"chest": 1.0, "waist": 1.5, "hips": 1.1}})),
		["tinkering", "food", "stories"], {"mechanical": 95.0, "speed": 80.0},
		{"extroversion": 0.85, "kindness": 0.95, "ambition": 0.5, "humor": 0.95, "discipline": 0.4},
		[{"day": "ALL", "start": 7, "end": 21, "activity": "WORK", "location": HOME}]))
	# ---- Sergio: the other brother. "People break. Machines are more honest."
	out.append(_npc("sergio", "Sergio", 78, 40, "#CE9872",
		_look("M", "#CE9872", TWIN_FACE["eye"], "Narrow", "Adult male", {"mass": 0.3, "muscle": 0.4},
			{"posture": 0.35}, "Short_Crop", "#D8D4CC", [
			_g("Shirt_Casual_01", {"top": "#C9A24E", "top_trim": "#3A2419", "top_seam": "#3A2419"}),
			_g("Pants_Casual_01", {"bottom": "#C9A24E", "bottom_trim": "#3A2419", "bottom_seam": "#3A2419", "stitch": "#3A2419", "metal": "#D4AF55"}),
			_g("Jones_Utility_Jacket", {"outer": "#3A2419"}),              # stand-in: his long torn coat
			_g("Mechanic_Work_Gloves", {"gloves": "#1B1A1F", "glove_trim": "#D4AF55"}),
			_g("Mechanic_Work_Boots", {"boot": "#1B1A1F", "sole": "#3A3A40", "boot_trim": "#D4AF55"}),
			_g("TR_Glasses", {"frame": "#6A4A2E", "lens": "#C9CED8"}),
		], {"chin": TWIN_FACE["chin"], "jaw": TWIN_FACE["jaw"], "ears": TWIN_FACE["ears"], "height": 1.12,
			"widths": {"chest": 0.1, "waist": -0.3, "hips": -0.1}}),
		["tinkering", "inventions"], {"mechanical": 98.0, "speed": 75.0},
		{"extroversion": 0.1, "kindness": 0.35, "ambition": 0.7, "humor": 0.2, "discipline": 0.9},
		[{"day": "ALL", "start": 6, "end": 23, "activity": "WORK", "location": SERGIO_HOME}], SERGIO_HOME, "household_sergio"))
	return out

## Everyone at The Good Place is one household; Sergio keeps his own.
static func households() -> Dictionary:
	return {HOUSEHOLD: ["bram", "garrik", "lysa", "kip", "nana_ella", "grandpa_bram"], "household_sergio": ["sergio"]}

## Family ties for RelationshipManager.declare_family.
const FAMILY_PAIRS := [["garrik", "lysa"], ["garrik", "bram"], ["lysa", "bram"], ["garrik", "kip"], ["lysa", "kip"],
	["bram", "kip"], ["nana_ella", "garrik"], ["grandpa_bram", "garrik"], ["grandpa_bram", "nana_ella"],
	["grandpa_bram", "bram"], ["grandpa_bram", "kip"], ["nana_ella", "bram"], ["nana_ella", "kip"],
	["grandpa_bram", "sergio"], ["sergio", "garrik"], ["sergio", "bram"]]

# ------------------------------------------------------------------ helpers
static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate(true)
	for k in b:
		r[k] = b[k]
	return r

static func _g(part: String, colors: Dictionary) -> Dictionary:
	return {"part": part, "colors": colors}

static func _look(base: String, skin: String, eye: String, eye_preset: String, body_type: String, build: Dictionary,
		shape: Dictionary, hair_cut: String, hair_color: String, garments: Array, extra := {}) -> Dictionary:
	var spec: Dictionary = CreatorData.BODY_TYPES[body_type]
	var r := {
		"base": base, "skin": skin, "eye": eye, "eye_preset": eye_preset, "body_type": body_type,
		"head_scale": spec.get("head_scale", 0.8), "leg_length": spec.get("leg_length", 0.0),
		"sheet_build": spec.get("sheet_build", 0.0), "widths": (spec.get("widths", {}) as Dictionary).duplicate(),
		"definition": (spec.get("definition", {}) as Dictionary).duplicate(), "build": build, "shape": shape,
		"hair": {"cut": hair_cut, "bangs": "", "accessory": "", "color": hair_color, "accent": hair_color, "tie": "#1B1A1F"},
		"garments": garments,
	}
	for k in extra:
		r[k] = extra[k]
	return r

static func _npc(id: String, first: String, age: int, birthday: int, skin: String, recipe: Dictionary, interests: Array,
		skills: Dictionary, personality: Dictionary, schedule: Array, home := HOME, household := HOUSEHOLD) -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = id
	d.first_name = first
	d.last_name = ""
	d.age_years = age
	d.birthday_day_of_year = birthday
	d.household_id = household
	d.home_location_id = home
	d.skin_tone = Color(skin)
	recipe["name"] = first
	d.recipe = recipe
	d.starting_equipment = {}
	d.is_romanceable = age >= 18 and id == "bram"
	d.interests.assign(interests)
	d.skills = skills
	d.personality = personality
	d.schedule.assign(schedule)
	d.recalculate_life_stage()
	return d
