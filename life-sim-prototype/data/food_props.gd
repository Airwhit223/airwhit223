class_name FoodProps
extends RefCounted
## Which model stands for which ingredient, station and dish.
##
## One map, so the kitchen, a menu screen and a plated dish all show the same burger. Ingredients with no model yet
## simply are not listed — callers fall back to the coloured placeholder block rather than showing the wrong food.
##
## Heights come from props/restaurant/README.md: the pieces are modelled to stack into a real burger, origin at the
## bottom centre, so plating is just placing each layer at its documented height.

const DIR := "res://props/restaurant/"
const SMALL_MAT := DIR + "toon_small.tres"     # thin outline: food and small items
const LARGE_MAT := DIR + "toon_large.tres"     # thick outline: furniture and equipment

## ingredient id (RecipeCatalog.INGREDIENTS) -> model file
const INGREDIENT := {
	"bun": "bottom_bun.glb",
	"patty": "patty.glb",
	"cheese": "cheese.glb",
	"lettuce": "lettuce.glb",
	"tomato": "tomato.glb",
	"pickle": "pickle.glb",
	"fries": "fry_carton_full.glb",
	"sausage": "sausage.glb",
}
## Finished dishes, for the pass window and menus.
const DISH := {"burger": "burger.glb", "hotdog": "hotdog.glb", "fries": "fry_carton_full.glb"}
## Station furniture. Anything absent keeps the placeholder block.
const STATION := {"grill": "grill.glb", "fryer": "fryer.glb", "pass": "cash_register.glb"}
## Where each burger layer sits above the plate, straight out of the README.
const STACK_HEIGHT := {"bun": 0.0, "patty": 0.027, "cheese": 0.045, "lettuce": 0.05,
	"tomato": 0.059, "pickle": 0.067, "top_bun": 0.07}

static func ingredient_scene(id: String) -> PackedScene:
	return _load(INGREDIENT.get(id, ""))

static func station_scene(kind: String) -> PackedScene:
	return _load(STATION.get(kind, ""))

static func dish_scene(id: String) -> PackedScene:
	return _load(DISH.get(id, ""))

static func _load(file: String) -> PackedScene:
	if file == "":
		return null
	var path := DIR + file
	return load(path) if ResourceLoader.exists(path) else null

## Drop a prop in, outlined like the rest of the restaurant. Returns the instance, or null when there is no model.
static func spawn(parent: Node3D, file_scene: PackedScene, large := false) -> Node3D:
	if file_scene == null or parent == null:
		return null
	var n: Node3D = file_scene.instantiate()
	var mat: Material = load(LARGE_MAT if large else SMALL_MAT)
	if mat:
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mat
	parent.add_child(n)
	return n
