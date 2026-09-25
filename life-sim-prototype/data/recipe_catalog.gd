class_name RecipeCatalog
extends RefCounted
## Restaurant recipes - data only (the kitchen runs them). An item in the kitchen is {"id", "state"}:
##   raw ingredients come from the pantry; PREP turns them into their prepped state on the board;
##   COOK stations (grill / fryer / pot) turn them cooked -> burnt on a timer (the "cooked" window widens with skill).
## A recipe is the plate it must arrive as: `base` items always, plus `toppings` - `default_toppings` unless the
## ticket's modifications change them ("No onions", "Extra cheese", "Add bacon"...). `doneness` mods check how long
## the cooked item sat in its window ("Well done" = the later half).

const INGREDIENTS := {
	"bun": "Bun", "patty": "Beef patty", "cheese": "Cheese slice", "lettuce": "Lettuce", "tomato": "Tomato",
	"onion": "Onion", "potato": "Potato", "carrot": "Carrot", "steak": "Steak",
}
## raw id -> the state prepping leaves it in
const PREP := {"lettuce": "chopped", "tomato": "chopped", "onion": "chopped", "potato": "cut", "carrot": "chopped"}
## what each cook station takes: "<id>:<state>" -> {"time": seconds to cooked, "window": seconds before it burns}
const COOK := {
	"grill": {"patty:raw": {"time": 8.0, "window": 5.0}, "steak:raw": {"time": 11.0, "window": 5.0}},
	"fryer": {"potato:cut": {"time": 7.0, "window": 5.0, "becomes": "fries"}},
}
## the soup pot takes these (prepped) and simmers them into one bowl
const POT := {"needs": ["carrot:chopped", "potato:cut", "onion:chopped"], "time": 12.0, "window": 8.0, "becomes": "soup"}

const RECIPES := {
	"burger": {"name": "Burger", "difficulty": 2,
		"base": ["bun:raw", "patty:cooked"],
		"toppings": {"cheese": "cheese:raw", "lettuce": "lettuce:chopped", "tomato": "tomato:chopped", "onion": "onion:chopped"},
		"default_toppings": ["lettuce", "tomato"],
		"mods": [["No tomato", {"remove": "tomato"}], ["Add cheese", {"add": "cheese"}], ["Add onion", {"add": "onion"}],
			["Well done", {"doneness": "well"}], ["No lettuce", {"remove": "lettuce"}]]},
	"fries": {"name": "Fries", "difficulty": 1, "base": ["fries:cooked"], "toppings": {}, "default_toppings": [],
		"mods": [["Extra crispy", {"doneness": "well"}]]},
	"salad": {"name": "Salad", "difficulty": 1, "base": ["lettuce:chopped", "tomato:chopped"],
		"toppings": {"onion": "onion:chopped", "cheese": "cheese:raw"}, "default_toppings": ["onion"],
		"mods": [["No onions", {"remove": "onion"}], ["Add cheese", {"add": "cheese"}]]},
	"soup": {"name": "Vegetable Soup", "difficulty": 3, "base": ["soup:cooked"], "toppings": {}, "default_toppings": [],
		"mods": []},
	"grilled_meat": {"name": "Grilled Steak", "difficulty": 3, "base": ["steak:cooked", "fries:cooked"], "toppings": {},
		"default_toppings": [], "mods": [["Well done", {"doneness": "well"}], ["Salad instead of fries",
			{"swap": ["fries:cooked", ["lettuce:chopped", "tomato:chopped"]]}]]},
}

static func item_name(item: Dictionary) -> String:
	var id := String(item.get("id", ""))
	var state := String(item.get("state", "raw"))
	var base := String(INGREDIENTS.get(id, id.capitalize()))
	if id == "fries": base = "Fries"
	if id == "soup": base = "Soup"
	match state:
		"raw": return base if id in ["bun", "cheese", "lettuce", "tomato", "onion", "potato", "carrot"] else "Raw " + base.to_lower()
		"chopped": return "Chopped " + base.to_lower()
		"cut": return "Cut " + base.to_lower()
		"cooking": return base + " (cooking)"
		"cooked": return "Cooked " + base.to_lower() if id not in ["fries", "soup"] else base
		"burnt": return "Burnt " + base.to_lower()
	return base

## A ticket: the recipe with its modifications applied -> the exact plate wanted.
static func make_ticket(recipe_id: String, rng: RandomNumberGenerator, mod_chance := 0.5) -> Dictionary:
	var r: Dictionary = RECIPES[recipe_id]
	var toppings: Array = (r["default_toppings"] as Array).duplicate()
	var notes: Array[String] = []
	var doneness := ""
	var swaps: Array = []
	var mods: Array = r["mods"]
	if not mods.is_empty() and rng.randf() < mod_chance:
		var m: Array = mods[rng.randi() % mods.size()]
		notes.append(String(m[0]))
		var eff: Dictionary = m[1]
		if eff.has("remove"): toppings.erase(eff["remove"])
		if eff.has("add") and not toppings.has(eff["add"]): toppings.append(eff["add"])
		if eff.has("doneness"): doneness = eff["doneness"]
		if eff.has("swap"): swaps.append(eff["swap"])
	var want: Array = (r["base"] as Array).duplicate()
	for s in swaps:
		want.erase(s[0])
		want.append_array(s[1])
	for t in toppings:
		want.append(r["toppings"][t])
	want.sort()
	return {"recipe": recipe_id, "name": r["name"], "want": want, "notes": notes, "doneness": doneness}

## Score a plate against a ticket -> {"ok", "satisfaction", "problems": [...]}
static func judge(ticket: Dictionary, plate: Array) -> Dictionary:
	var got: Array = []
	var problems: Array[String] = []
	var well_ok := true
	for item in plate:
		if item.get("state", "") == "burnt":
			problems.append("burnt " + String(item["id"]))
		got.append("%s:%s" % [item["id"], "cooked" if item.get("state") == "burnt" else item.get("state", "raw")])
		if ticket.get("doneness", "") == "well" and item.get("state") == "cooked" and not item.get("well", false) \
				and String(item["id"]) in ["patty", "steak", "fries"]:
			well_ok = false
	got.sort()
	var want: Array = ticket["want"]
	for w in want:
		if not got.has(w):
			problems.append("missing " + String(w).split(":")[0])
		else:
			got.erase(w)
	for extra in got:
		problems.append("didn't want " + String(extra).split(":")[0])
	if not well_ok:
		problems.append("not well done")
	var sat := clampf(1.0 - 0.3 * problems.size(), 0.0, 1.0)
	return {"ok": problems.is_empty() or sat >= 0.7, "satisfaction": sat, "problems": problems}
