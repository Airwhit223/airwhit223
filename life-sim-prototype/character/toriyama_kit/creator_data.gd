class_name CreatorData
## Choices the character creator offers: palettes (from the Blender faction/creator palettes), body slots, movement
## styles and the starting recipe. Part lists themselves come from the kit folders, so exporting a new part in
## Blender makes it appear here with no code change.

const SKIN_TONES := {
	"Porcelain": "#F6D6C0", "Light": "#ECC0A2", "Tan": "#CE9872", "Brown": "#9E6C52", "Deep": "#704836",
	"Warm": "#E0B08A", "Olive": "#B98A62", "Rich": "#5E3C2C",
}
const EYE_COLORS := {
	"Brown": "#784624", "Amber": "#B06826", "Hazel": "#8A6A34", "Green": "#3E8446", "Blue": "#2E66BA",
	"Violet": "#8C48B4", "Grey": "#6E7480", "Dark": "#3A2A22",
}
const HAIR_COLORS := {
	"Black": "#1E1A1A", "Dark Brown": "#3A2419", "Chestnut": "#5C3A24", "Auburn": "#6E3222", "Blonde": "#D8B36A",
	"Sandy": "#A98A56", "Ash": "#6A6A70", "White": "#D8D4CC", "Red": "#A8322A", "Pink": "#D8338C",
	"Magenta": "#B8326E", "Cyan": "#23A7D8", "Teal": "#2E8C8C", "Purple": "#6E3A8C", "Green": "#3E8C4A",
}
## General clothing palette — any garment role can take any of these.
const GARMENT_COLORS := {
	"Black": "#1B1A1F", "Charcoal": "#3A3A40", "Grey": "#6E7078", "White": "#EFE9DC", "Cream": "#D8C9A0",
	"Navy": "#223A5E", "Denim": "#4F6A8C", "Sky": "#7AA8D8", "Teal": "#2E8C8C", "Forest": "#2F5D3A",
	"Olive": "#5A5438", "Mustard": "#C9A24E", "Rust": "#C4602C", "Red": "#B81E2A", "Maroon": "#6E2028",
	"Pink": "#E0558E", "Magenta": "#B8326E", "Purple": "#6E3A8C", "Lavender": "#B6A8D8", "Brown": "#6A4A2E",
	"Tan": "#B49A6A", "Gold": "#D4AF55", "Silver": "#C9CED8", "Mint": "#9ED8B8",
}
## Body slots in the order the creator shows them. "" means nothing worn in that slot.
const SLOTS := ["outerwear", "top", "bottom", "legwear", "shoes", "headwear", "eyewear", "accessory"]
const SLOT_LABELS := {
	"outerwear": "Jacket", "top": "Top", "bottom": "Bottoms", "legwear": "Legwear", "shoes": "Shoes",
	"headwear": "Hat", "eyewear": "Glasses", "accessory": "Accessory",
}
## Weapons are not a garment slot: a prop bone-attaches to a socket instead of being skinned, so the creator shows
## it separately (recipe["weapon"], see ToriyamaKitCharacter.set_weapon).
const WEAPON_CARRY := {"hip": "On the hip", "back": "Across the back"}
## How the character moves — the rig blends the same walk with different weights (see CharacterRig.MOVEMENT_STYLES).
const MOVEMENT_STYLES := {
	"neutral": "Neutral", "masculine": "Masculine", "feminine": "Feminine", "eager": "Eager",
	"athletic": "Athletic", "shy": "Shy",
}
const BUILDS := {
	"Lean": {"mass": 0.2, "muscle": 0.35}, "Average": {"mass": 0.5, "muscle": 0.5},
	"Athletic": {"mass": 0.45, "muscle": 0.8}, "Stocky": {"mass": 0.8, "muscle": 0.4},
	"Strong": {"mass": 0.75, "muscle": 0.85},
}
const BASE_LABELS := {"M": "Masculine build", "F": "Feminine build"}
## Body definition sliders (shape keys on top of the base body) — these are what make swimwear and close-fitting
## clothes read properly.
const DEFINITION := {
	"Bust": "Chest (bust)", "Hips": "Hips", "Waist": "Waist (narrower)", "Shoulders": "Shoulders",
	"Pecs": "Chest (pecs)", "Back": "Back width",
}
const DEFINITION_DEFAULTS := {
	"M": {"Shoulders": 0.35, "Pecs": 0.3, "Back": 0.25, "Waist": 0.15, "Bust": 0.0, "Hips": 0.0},
	"F": {"Bust": 0.45, "Hips": 0.45, "Waist": 0.4, "Shoulders": 0.05, "Pecs": 0.0, "Back": 0.05},
}
## Eye shapes, each a separate face shape rather than a slider position.
const EYE_PRESETS := {
	"DQ8": "Classic", "DB": "Anime Sharp", "Sharp": "Fighter", "Wide": "Wide (unsettling)",
	"Round": "Soft Round", "Narrow": "Sly", "Sleepy": "Sleepy",
	# drawn anime eyes (character/toriyama_kit/anime_eye), built from the user's eye reference sheets
	"Anime_Curious_Doe": "Doe (drawn)", "Anime_Sleek_Cat": "Cat Almond (drawn)", "Anime_Heroine": "Heroine (drawn)",
	"Anime_Intense_Hero": "Hero (drawn)", "Anime_Focused_Almond": "Focused (drawn)", "Anime_Brawler": "Brawler (drawn)",
	"Anime_Toriyama": "Toriyama (drawn)",
}

static func default_recipe() -> Dictionary:
	return {
		"name": "", "base": "M", "skin": SKIN_TONES["Tan"], "eye": EYE_COLORS["Brown"], "eye_preset": "DQ8", "chin": 1.0, "jaw": 0.6, "eye_dq": 0.0, "ears": {"size": 0.0, "point": 0.0, "out": 0.0}, "body_type": "Teen", "widths": {"hips": 0.15, "waist": 0.0, "chest": 0.1},
		"build": {"mass": 0.5, "muscle": 0.5}, "movement": "neutral",
		# three traits chosen at creation; the picker arrives with the authored trait list, and they are never
		# shown in a list afterwards - see autoload/trait_system.gd
		"traits": [],
		"definition": (DEFINITION_DEFAULTS["M"] as Dictionary).duplicate(),
		"hair": {"cut": "RT_M_Curly_Medium", "bangs": "", "accessory": "", "color": HAIR_COLORS["Dark Brown"],
			"accent": HAIR_COLORS["Dark Brown"], "tie": GARMENT_COLORS["Black"]},
		"garments": [
			{"part": "Shirt_Casual_01", "colors": {"top": GARMENT_COLORS["White"]}},
			{"part": "Pants_Casual_01", "colors": {"bottom": GARMENT_COLORS["Denim"]}},
			{"part": "Shoes_Sneaker_01", "colors": {"shoe": GARMENT_COLORS["Charcoal"]}},
		],
	}

## Hair pieces are named F_Base_* / F_Bangs_* / F_Accessory_*; everything else is a whole style.
## Body types from the user's own construction notes (references/characters/hero/CREATOR_BASE_CONSTRUCTION_NOTES.md),
## in head-heights: adult male ~6.5 H with 2.2 H shoulders, adult female ~6.5 H with 1.8 H shoulders and wider hips,
## stocky ~6.0 H and broad, petite ~6.0 H and narrow, teen ~5.5 H (the base body's own proportions), child ~4.5 H.
## Height comes from the head scale (a smaller head reads as more heads tall) plus leg length; widths come from the
## TR_*_Width channels, which the base body needs because Def_Hips alone barely changes hip width.
const BODY_TYPES := {
	# the stocky character-sheet build (SB_Sheet_* shapes): thicker legs, fuller torso, bigger hands and feet
	"Sheet build": {"base": "M", "head_scale": 0.80, "leg_length": 0.0, "sheet_build": 1.0, "widths": {},
		"definition": {"Shoulders": 0.25, "Pecs": 0.2, "Back": 0.1}, "build": {"mass": 0.5, "muscle": 0.5}},
	"Sheet build female": {"base": "F", "head_scale": 0.80, "leg_length": 0.0, "sheet_build": 1.0, "widths": {},
		"definition": {"Bust": 0.45, "Hips": 0.3, "Waist": 0.3}, "build": {"mass": 0.5, "muscle": 0.5}},
	"Teen": {"base": "M", "head_scale": 0.80, "leg_length": 0.0, "widths": {"hips": 0.15, "waist": 0.0, "chest": 0.1},
		"definition": {"Shoulders": 0.25, "Waist": 0.2, "Hips": 0.1, "Pecs": 0.15, "Back": 0.1},
		"build": {"mass": 0.45, "muscle": 0.45}},
	"Adult male": {"base": "M", "head_scale": 0.71, "leg_length": 0.5, "widths": {"hips": 0.45, "waist": 0.2, "chest": 0.5},
		"definition": {"Shoulders": 0.8, "Waist": 0.45, "Hips": 0.2, "Pecs": 0.6, "Back": 0.55},
		"build": {"mass": 0.5, "muscle": 0.68}},
	"Adult female": {"base": "F", "head_scale": 0.71, "leg_length": 0.65, "widths": {"hips": 1.0, "waist": -0.15, "chest": 0.2},
		"definition": {"Shoulders": 0.15, "Waist": 0.9, "Hips": 0.9, "Bust": 0.7, "Pecs": 0.0, "Back": 0.1},
		"build": {"mass": 0.46, "muscle": 0.42}},
	"Athletic female": {"base": "F", "head_scale": 0.72, "leg_length": 0.6, "widths": {"hips": 0.8, "waist": -0.2, "chest": 0.3},
		"definition": {"Shoulders": 0.45, "Waist": 0.85, "Hips": 0.7, "Bust": 0.45, "Back": 0.35},
		"build": {"mass": 0.47, "muscle": 0.62}},
	"Curvy female": {"base": "F", "head_scale": 0.73, "leg_length": 0.45, "widths": {"hips": 1.2, "waist": 0.05, "chest": 0.3},
		"definition": {"Shoulders": 0.15, "Waist": 0.95, "Hips": 1.0, "Bust": 0.9, "Back": 0.1},
		"build": {"mass": 0.6, "muscle": 0.42}},
	"Broad": {"base": "M", "head_scale": 0.76, "leg_length": -0.35, "widths": {"hips": 0.7, "waist": 0.85, "chest": 0.9},
		"definition": {"Shoulders": 1.0, "Waist": 0.0, "Hips": 0.35, "Pecs": 0.7, "Back": 0.9},
		"build": {"mass": 0.8, "muscle": 0.7}},
	"Petite": {"base": "F", "head_scale": 0.78, "leg_length": 0.1, "widths": {"hips": 0.65, "waist": -0.2, "chest": 0.05},
		"definition": {"Shoulders": 0.05, "Waist": 0.9, "Hips": 0.75, "Bust": 0.45},
		"build": {"mass": 0.4, "muscle": 0.4}},
	"Child": {"base": "M", "head_scale": 1.02, "leg_length": -0.9, "widths": {"hips": 0.25, "waist": 0.35, "chest": 0.2},
		"definition": {"Shoulders": 0.0, "Waist": 0.0, "Hips": 0.1},
		"build": {"mass": 0.45, "muscle": 0.3}},
}

## ------------------------------------------------------------------ shop
## What a part will cost once the in-game currency lands. NOTHING IS LOCKED YET: `is_unlocked` returns true for
## everything, so the creator offers the whole catalogue today (user, 2026-09-24: "we'll put them all accessible to
## the player now but later will have to be paid for with in-game currency"). When the wallet exists, make
## `is_unlocked` ask the save file for owned parts instead of returning early - the prices below are already the
## intended ones, and every caller already goes through these two functions.
const SHOP_OPEN := true               # flip to false the day the currency ships
const STARTER_PARTS := ["Shirt_Casual_01", "Pants_Casual_01", "Shoes_Sneaker_01"]
const DEFAULT_PRICE := 120
const PRICES := {
	# skate shoes (2026-09-24)
	"TR_Skate_Hi": 260, "TR_Skate_Lo": 220, "TR_Chunky_Hi": 340, "TR_Chunky_Lo": 300,
	# katana variants, sold as a prop (sword + its scabbard)
	"Classic": 900, "Black": 1100, "BlackRed": 1400,
}

static func price_of(part_name: String) -> int:
	if part_name in STARTER_PARTS:
		return 0
	return int(PRICES.get(part_name, DEFAULT_PRICE))

## Can the player wear this yet? `owned` may be passed explicitly (tests, another character); left empty it asks
## Economy for what this save actually owns, which is where purchases land.
static func is_unlocked(part_name: String, owned: Array = []) -> bool:
	if SHOP_OPEN:
		return true
	if part_name in STARTER_PARTS or price_of(part_name) == 0:
		return true
	if part_name in owned:
		return true
	return owns_through_economy(part_name)

## The bridge to the wallet. Static, so the creator's static helpers can ask without holding a node reference.
static func owns_through_economy(part_name: String) -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var eco = (loop as SceneTree).root.get_node_or_null("Economy")
		if eco:
			return bool(eco.owns(part_name))
	return false

## {name: price} for every weapon prop, for the shop screen and the creator's Weapon tab.
static func weapons() -> Array:
	var out: Array = []
	for name in ToriyamaKitCharacter.list_parts("prop"):
		out.append(name)
	return out

static func weapon_label(name: String) -> String:
	return {"Classic": "Classic Samurai", "Black": "Black Blade", "BlackRed": "Black & Crimson"}.get(name, name)

static func weapon_roles(name: String) -> Array:
	return ToriyamaKitCharacter.kit_json("prop", name).get("roles", [])

## Ear sliders shown in the creator's Face tab. Point is the elf taper (also what the Race Bible's elves use).
const EARS := {"size": "Ear size", "point": "Elf point", "out": "Stick out"}

static func hair_styles() -> Array:
	var out: Array = []
	for name in ToriyamaKitCharacter.list_parts("hair"):
		if name.begins_with("F_Bangs_") or name.begins_with("F_Accessory_"):
			continue
		out.append(name)
	return out

static func bangs_options() -> Array:
	var out: Array = ["", ]
	for name in ToriyamaKitCharacter.list_parts("hair"):
		if name.begins_with("F_Bangs_"):
			out.append(name.trim_prefix("F_Bangs_"))
	return out

static func hair_label(name: String) -> String:
	return name.trim_prefix("F_Base_").trim_prefix("RT_").replace("_", " ")

## {slot: [garment names]} from the kit folders.
static func garments_by_slot() -> Dictionary:
	var out: Dictionary = {}
	for slot in SLOTS:
		out[slot] = []
	for name in ToriyamaKitCharacter.list_parts("garment"):
		var kit := ToriyamaKitCharacter.kit_json("garment", name)
		var slot: String = kit.get("slot", "accessory")
		if not out.has(slot):
			out[slot] = []
		out[slot].append(name)
	return out

static func garment_label(name: String) -> String:
	return name.replace("TR_", "").replace("_", " ")

static func garment_roles(name: String) -> Array:
	return ToriyamaKitCharacter.kit_json("garment", name).get("roles", [])

static func random_recipe(rng: RandomNumberGenerator) -> Dictionary:
	var recipe := default_recipe()
	recipe["base"] = ["M", "F"][rng.randi() % 2]
	recipe["skin"] = SKIN_TONES.values()[rng.randi() % SKIN_TONES.size()]
	recipe["eye"] = EYE_COLORS.values()[rng.randi() % EYE_COLORS.size()]
	recipe["eye_preset"] = EYE_PRESETS.keys()[rng.randi() % EYE_PRESETS.size()]
	recipe["chin"] = snappedf(rng.randf_range(0.7, 1.3), 0.05)
	recipe["jaw"] = snappedf(rng.randf_range(0.2, 1.2), 0.05)
	recipe["ears"] = {"size": snappedf(rng.randf_range(-0.4, 0.8), 0.05), "point": 0.0,
		"out": snappedf(rng.randf_range(-0.2, 0.8), 0.05)}
	recipe["movement"] = MOVEMENT_STYLES.keys()[rng.randi() % MOVEMENT_STYLES.size()]
	recipe["build"] = BUILDS.values()[rng.randi() % BUILDS.size()].duplicate()
	var definition: Dictionary = (DEFINITION_DEFAULTS[recipe["base"]] as Dictionary).duplicate()
	for key in definition:
		definition[key] = clampf(float(definition[key]) + rng.randf_range(-0.2, 0.25), 0.0, 1.0)
	recipe["definition"] = definition
	var styles := hair_styles()
	if not styles.is_empty():
		var cut: String = styles[rng.randi() % styles.size()]
		var color: String = HAIR_COLORS.values()[rng.randi() % HAIR_COLORS.size()]
		var bangs := ""
		if cut.begins_with("F_Base_"):
			var options := bangs_options()
			bangs = options[rng.randi() % options.size()]
		recipe["hair"] = {"cut": cut, "bangs": bangs, "accessory": "", "color": color, "accent": color,
			"tie": GARMENT_COLORS.values()[rng.randi() % GARMENT_COLORS.size()]}
	var garments: Array = []
	var by_slot := garments_by_slot()
	for slot in ["top", "bottom", "shoes", "outerwear"]:
		var items: Array = by_slot.get(slot, [])
		if items.is_empty():
			continue
		if slot == "outerwear" and rng.randf() < 0.45:
			continue
		var part: String = items[rng.randi() % items.size()]
		var colors := {}
		for role in garment_roles(part):
			colors[role] = GARMENT_COLORS.values()[rng.randi() % GARMENT_COLORS.size()]
		garments.append({"part": part, "colors": colors})
	recipe["garments"] = garments
	return recipe
