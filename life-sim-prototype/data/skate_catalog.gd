class_name SkateCatalog
extends RefCounted
## The skate shop's Board Builder job (JobManager "skate_builder") - data only; world/skate_shop/skate_shop.gd runs it.
## A customer walks in with a request in their own words; the builder picks a deck, trucks, bearings and wheels off
## the racks, assembles them at the bench, and hands the board over. judge() scores the build against the request.
##
## Component attributes (0..1 unless noted) feed the board's stats:
##   pop        deck        - how well it ollies
##   stability  deck+trucks - steady at speed
##   speed      wheels+bearings
##   grip       wheels+trucks (turn) - control, comfort on rough ground
##   durability bearings+deck
## Compatibility: trucks must match the deck width (within 0.25"), big wheels (58mm+) on a street deck give wheel bite,
## and hover parts only work with hover parts.

const PARTS := {
	"deck": {
		"street_80": {"name": "Street deck 8.0\"", "width": 8.0, "style": "street", "pop": 0.8, "stability": 0.5, "durability": 0.6, "price": 55, "unlock": "street", "color": Color(0.9, 0.35, 0.3)},
		"street_85": {"name": "Street deck 8.5\"", "width": 8.5, "style": "street", "pop": 0.7, "stability": 0.65, "durability": 0.65, "price": 60, "unlock": "street", "color": Color(0.3, 0.5, 0.9)},
		"cruiser_90": {"name": "Cruiser deck 9.0\"", "width": 9.0, "style": "cruiser", "pop": 0.3, "stability": 0.7, "durability": 0.7, "price": 50, "unlock": "cruiser", "color": Color(0.95, 0.75, 0.3)},
		"blank_80": {"name": "Blank deck 8.0\"", "width": 8.0, "style": "street", "pop": 0.55, "stability": 0.45, "durability": 0.4, "price": 28, "unlock": "budget_orders", "color": Color(0.85, 0.75, 0.6)},
		"longboard_95": {"name": "Drop-through longboard", "width": 9.5, "style": "longboard", "pop": 0.1, "stability": 0.95, "durability": 0.8, "price": 90, "unlock": "longboard", "color": Color(0.35, 0.7, 0.45)},
		"hover_90": {"name": "Hover deck (prototype)", "width": 9.0, "style": "hover", "hover": true, "pop": 0.6, "stability": 0.85, "durability": 0.7, "price": 240, "unlock": "hoverboard", "color": Color(0.6, 0.35, 0.95)},
	},
	"trucks": {
		"trucks_80": {"name": "Standard trucks 8.0\"", "width": 8.0, "stability": 0.6, "turn": 0.55, "price": 40, "unlock": "street"},
		"trucks_85": {"name": "Standard trucks 8.5\"", "width": 8.5, "stability": 0.65, "turn": 0.5, "price": 42, "unlock": "street"},
		"cruiser_trucks_90": {"name": "Soft-bushing trucks 9.0\"", "width": 9.0, "stability": 0.55, "turn": 0.85, "price": 40, "unlock": "cruiser"},
		"budget_trucks_80": {"name": "Budget trucks 8.0\"", "width": 8.0, "stability": 0.45, "turn": 0.45, "price": 20, "unlock": "budget_orders"},
		"rkp_95": {"name": "Reverse-kingpin trucks 9.5\"", "width": 9.5, "stability": 0.9, "turn": 0.75, "price": 60, "unlock": "longboard"},
		"grav_emitters": {"name": "Grav emitters", "width": 9.0, "hover": true, "stability": 0.9, "turn": 0.9, "price": 180, "unlock": "hoverboard"},
	},
	"bearings": {
		"abec5": {"name": "ABEC-5 bearings", "speed": 0.5, "durability": 0.6, "price": 15, "unlock": "street"},
		"abec7": {"name": "ABEC-7 bearings", "speed": 0.7, "durability": 0.55, "price": 25, "unlock": "street"},
		"budget_bearings": {"name": "Bargain bearings", "speed": 0.35, "durability": 0.35, "price": 6, "unlock": "budget_orders"},
		"ceramic": {"name": "Ceramic bearings", "speed": 0.92, "durability": 0.85, "price": 60, "unlock": "longboard"},
		"flux_core": {"name": "Flux cores", "hover": true, "speed": 0.95, "durability": 0.8, "price": 120, "unlock": "hoverboard"},
	},
	"wheels": {
		"w52_99": {"name": "52mm 99a street wheels", "size": 52, "speed": 0.55, "grip": 0.3, "price": 30, "unlock": "street", "color": Color(0.95, 0.95, 0.92)},
		"w54_101": {"name": "54mm 101a hard wheels", "size": 54, "speed": 0.65, "grip": 0.25, "price": 34, "unlock": "street", "color": Color(0.95, 0.85, 0.3)},
		"w60_78": {"name": "60mm 78a soft wheels", "size": 60, "speed": 0.7, "grip": 0.8, "price": 36, "unlock": "cruiser", "color": Color(0.35, 0.8, 0.85)},
		"budget_w52": {"name": "52mm bargain wheels", "size": 52, "speed": 0.4, "grip": 0.3, "price": 14, "unlock": "budget_orders", "color": Color(0.8, 0.8, 0.8)},
		"w70_80": {"name": "70mm 80a longboard wheels", "size": 70, "speed": 0.85, "grip": 0.88, "price": 48, "unlock": "longboard", "color": Color(0.95, 0.45, 0.2)},
		"hover_pads": {"name": "Hover pads", "size": 0, "hover": true, "speed": 0.95, "grip": 0.75, "price": 90, "unlock": "hoverboard", "color": Color(0.5, 0.95, 1.0)},
	},
}

## Assembly order at the bench.
const ORDER := ["deck", "trucks", "bearings", "wheels"]
const STATS := ["pop", "speed", "stability", "grip", "durability"]

## Requests: what the customer says, what they actually need (skate_knowledge reveals `wants` on the card).
const REQUESTS := [
	{"id": "first_board", "unlock": "street", "style": "street", "budget": 170,
		"line": "It's my first real board. I want to learn ollies!", "wants": {"pop": 0.7}},
	{"id": "plaza_tech", "unlock": "street", "style": "street", "budget": 190,
		"line": "Something poppy and quick for the plaza ledges.", "wants": {"pop": 0.75, "speed": 0.6}},
	{"id": "big_feet", "unlock": "street", "style": "street", "budget": 190, "width_min": 8.5,
		"line": "I've got big feet - I need a wider, steadier street board.", "wants": {"stability": 0.6, "pop": 0.6}},
	{"id": "boardwalk", "unlock": "cruiser", "style": "cruiser", "budget": 170,
		"line": "I just want to cruise the boardwalk. Smooth and comfy.", "wants": {"grip": 0.75, "speed": 0.6}},
	{"id": "commute", "unlock": "cruiser", "style": "cruiser", "budget": 160,
		"line": "Getting to class over cracked sidewalks - soft wheels, please.", "wants": {"grip": 0.8}},
	{"id": "budget_kid", "unlock": "budget_orders", "style": "street", "budget": 90,
		"line": "My kid wants a board. Can you keep it under $90?", "wants": {"pop": 0.5}},
	{"id": "hill_bomb", "unlock": "longboard", "style": "longboard", "budget": 280,
		"line": "Hill bombing down to Old Shore. It has to be stable at speed.", "wants": {"stability": 0.85, "speed": 0.8}},
	{"id": "sponsored", "unlock": "sponsored", "style": "street", "budget": 999,
		"line": "Team rider. Best of everything - money's no object.", "wants": {"pop": 0.8, "speed": 0.8, "durability": 0.7}},
	{"id": "hover", "unlock": "hoverboard", "style": "hover", "budget": 700,
		"line": "I saw the prototype in the window. Build me one that actually floats.", "wants": {"speed": 0.9, "stability": 0.8}},
]

static func part(kind: String, id: String) -> Dictionary:
	return PARTS.get(kind, {}).get(id, {})

## The board's stats and price from what's mounted ({kind: part_id}).
static func stats(build: Dictionary) -> Dictionary:
	var d := part("deck", build.get("deck", ""))
	var t := part("trucks", build.get("trucks", ""))
	var b := part("bearings", build.get("bearings", ""))
	var w := part("wheels", build.get("wheels", ""))
	var s := {
		"pop": float(d.get("pop", 0.0)),
		"stability": (float(d.get("stability", 0.0)) + float(t.get("stability", 0.0))) / 2.0,
		"speed": (float(w.get("speed", 0.0)) + float(b.get("speed", 0.0))) / 2.0,
		"grip": (float(w.get("grip", 0.0)) + float(t.get("turn", 0.0))) / 2.0,
		"durability": (float(d.get("durability", 0.0)) + float(b.get("durability", 0.0))) / 2.0,
		"price": 0,
	}
	for kind in ORDER:
		s["price"] += int(part(kind, build.get(kind, "")).get("price", 0))
	return s

## Parts that don't work together - each is a problem the customer notices.
static func compatibility(build: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var d := part("deck", build.get("deck", ""))
	var t := part("trucks", build.get("trucks", ""))
	var w := part("wheels", build.get("wheels", ""))
	if not d.is_empty() and not t.is_empty() and absf(float(d["width"]) - float(t["width"])) > 0.25:
		out.append("the trucks don't fit the deck")
	if d.get("style", "") == "street" and int(w.get("size", 0)) >= 58:
		out.append("wheel bite - those wheels are too big for a street deck")
	var hover := 0
	var parts := 0
	for kind in ORDER:
		var p := part(kind, build.get(kind, ""))
		if p.is_empty():
			continue
		parts += 1
		if p.get("hover", false):
			hover += 1
	if hover > 0 and hover < parts:
		out.append("hover parts don't work with regular parts")
	return out

## Score a finished build against a request -> {"ok", "satisfaction", "problems", "stats"}.
static func judge(request: Dictionary, build: Dictionary) -> Dictionary:
	var problems: Array[String] = []
	for kind in ORDER:
		if build.get(kind, "") == "":
			problems.append("it's missing its %s" % kind)
	if not problems.is_empty():
		return {"ok": false, "satisfaction": 0.0, "problems": problems, "stats": {}}
	var s := stats(build)
	var sat := 1.0
	# how well the board does what they asked for
	var wants: Dictionary = request.get("wants", {})
	for k in wants:
		var short := maxf(0.0, float(wants[k]) - float(s[k]))
		if short > 0.05:
			problems.append("not enough %s" % k)
		sat -= short * 1.5
	var broken := compatibility(build)
	for c in broken:
		problems.append(c)
		sat -= 0.3
	if not broken.is_empty():
		sat = minf(sat, 0.4)            # parts that don't fit make a board that doesn't work - never a pass
	var d := part("deck", build["deck"])
	if d.get("style", "") != request.get("style", ""):
		problems.append("that's not a %s board" % request.get("style", ""))
		sat -= 0.35
	if request.has("width_min") and float(d.get("width", 0.0)) < float(request["width_min"]):
		problems.append("the deck's too narrow")
		sat -= 0.2
	var budget := int(request.get("budget", 9999))
	if int(s["price"]) > budget:
		problems.append("$%d is over my $%d budget" % [s["price"], budget])
		sat -= 0.25 + 0.5 * float(int(s["price"]) - budget) / float(budget)
	sat = clampf(sat, 0.0, 1.0)
	return {"ok": sat >= 0.6, "satisfaction": sat, "problems": problems, "stats": s}

## Unlocked parts of one kind, cheapest first.
static func parts_for(kind: String, unlocked: Array) -> Array[String]:
	var out: Array[String] = []
	for id in PARTS[kind]:
		if PARTS[kind][id]["unlock"] in unlocked:
			out.append(id)
	out.sort_custom(func(a, b): return int(PARTS[kind][a]["price"]) < int(PARTS[kind][b]["price"]))
	return out

## Words for a stat value - what a builder without much skate knowledge sees.
static func word(v: float) -> String:
	return "very high" if v >= 0.85 else ("high" if v >= 0.65 else ("medium" if v >= 0.45 else "low"))
