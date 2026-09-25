extends Node
## Money, what it buys, and where it is bought.
##
## `money` is the single balance for the player's life — jobs pay into it (JobManager), chest upgrades and shops
## take out of it (InventoryManager, the shops below), and SaveManager persists it. One balance rather than a pot
## per system, so "can I afford this" has exactly one answer.
##
## On top of that sits the price book: one place decides what anything costs, so a jacket has the same base price
## in the creator, in a shop window and in a quest reward. A shop applies its own markup (ShopDefinition) rather
## than keeping a second list that can drift.
##
## Not everything is buyable, deliberately: `building_damage.gd` still settles repairs in hours of WORK.

signal money_changed(balance: int, delta: int, reason: String)
signal purchase_made(item_id: String, price: int, shop_id: String)
signal purchase_refused(item_id: String, price: int, reason: String)
signal shop_registered(shop_id: String)

const CreatorDataScript := preload("res://character/toriyama_kit/creator_data.gd")

## Prices for things the creator does not already price. Creator parts (garments, props) carry their own in
## CreatorData.PRICES; this is everything else.
const PRICES := {
	# food and rest — small and frequent, the things an ordinary day is made of
	"meal_simple": 18, "meal_good": 42, "coffee": 9, "snack": 6,
	# skate shop components (the board-building job's raw material)
	"deck_basic": 95, "deck_pro": 210, "trucks_basic": 60, "trucks_pro": 140,
	"wheels_soft": 45, "wheels_hard": 45, "bearings_basic": 25, "bearings_pro": 70,
	"grip_tape": 12, "hardware": 10,
	# complete boards
	"board_beginner": 240, "board_street": 430, "board_park": 455, "longboard": 380, "hoverboard": 1800,
	"helmet": 65, "pads": 48,
}

var money: int = 0
## Item ids this character has bought or been given — creator parts, props, gear. Kept beside the money that
## bought them so a save is one object and the creator can ask one question: do they own this yet.
var owned: Dictionary = {}
## Recent movements, newest last, for a wallet screen and for "where did it all go".
var history: Array[Dictionary] = []
const HISTORY_MAX := 40

var _shops: Dictionary = {}          # shop_id -> ShopDefinition

func _ready() -> void:
	var rules := get_node_or_null("/root/GameRules")
	if rules:
		money = int(rules.value("starting_money", 250))
	_register_default_shops()

static func format(amount: int) -> String:
	return "$%s" % String.num_int64(amount)

# ------------------------------------------------------------------ money
func can_afford(amount: int) -> bool:
	return money >= amount

## Wages, sales, gifts, quest rewards.
func earn(amount: int, reason := "work") -> void:
	if amount <= 0:
		return
	money += amount
	_log(amount, reason)
	money_changed.emit(money, amount, reason)

## Returns false and changes nothing when there is not enough — a partial payment is never what anyone wants.
func spend(amount: int, reason := "purchase") -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false
	money -= amount
	_log(-amount, reason)
	money_changed.emit(money, -amount, reason)
	return true

func _log(delta: int, reason: String) -> void:
	var tm := get_node_or_null("/root/TimeManager")
	history.append({"delta": delta, "reason": reason, "balance": money,
		"day": int(tm.day_index) if tm else 0, "hour": int(tm.hour) if tm else 0})
	while history.size() > HISTORY_MAX:
		history.pop_front()

# ------------------------------------------------------------------ owning
func owns(item_id: String) -> bool:
	return owned.has(item_id)

## Given rather than bought: the starter kit, quest rewards, gifts.
func grant(item_id: String, reason := "gift") -> void:
	if item_id == "" or owned.has(item_id):
		return
	owned[item_id] = {"reason": reason, "paid": 0}

func owned_ids() -> Array:
	return owned.keys()

# ------------------------------------------------------------------ prices
## The book price of anything, wherever it is defined.
func base_price(item_id: String) -> int:
	if PRICES.has(item_id):
		return int(PRICES[item_id])
	return CreatorDataScript.price_of(item_id)

func price_at(shop_id: String, item_id: String) -> int:
	var shop := get_shop(shop_id)
	var base := base_price(item_id)
	return base if shop == null else shop.price_for(base)

# ------------------------------------------------------------------- shops
func register_shop(shop: ShopDefinition) -> void:
	if shop == null or shop.id == "":
		return
	_shops[shop.id] = shop
	shop_registered.emit(shop.id)

func get_shop(shop_id: String) -> ShopDefinition:
	return _shops.get(shop_id, null)

func shops() -> Array:
	return _shops.values()

func shop_at_location(location_id: String) -> ShopDefinition:
	for s in _shops.values():
		if (s as ShopDefinition).location_id == location_id:
			return s
	return null

## Open only when the hours say so AND somebody is behind the counter. A shop with nobody in it is shut, which is
## what makes the NPC schedules matter to the player rather than being scenery.
func is_open(shop_id: String) -> bool:
	var shop := get_shop(shop_id)
	if shop == null:
		return false
	var tm := get_node_or_null("/root/TimeManager")
	if tm and not shop.is_open_at(int(tm.hour), bool(tm.is_weekend())):
		return false
	if shop.job_id == "":
		return true
	var ws := get_node_or_null("/root/WorldState")
	if ws == null:
		return true
	return String(ws.get_job_holder(shop.job_id)) != ""

# -------------------------------------------------------------- buy / sell
## {"ok": bool, "price": int, "reason": String}. Never takes the money without handing over the item.
func buy(item_id: String, shop_id := "") -> Dictionary:
	if owns(item_id):
		return _refuse(item_id, 0, "already owned")
	if shop_id != "" and not is_open(shop_id):
		return _refuse(item_id, 0, "shop closed")
	var price := price_at(shop_id, item_id)
	if price < 0:
		return _refuse(item_id, price, "not for sale")
	if not can_afford(price):
		return _refuse(item_id, price, "cannot afford")
	spend(price, shop_id if shop_id != "" else "purchase")
	owned[item_id] = {"reason": shop_id, "paid": price}
	purchase_made.emit(item_id, price, shop_id)
	return {"ok": true, "price": price, "reason": ""}

func _refuse(item_id: String, price: int, reason: String) -> Dictionary:
	purchase_refused.emit(item_id, price, reason)
	return {"ok": false, "price": price, "reason": reason}

func sell(item_id: String, shop_id: String) -> Dictionary:
	var shop := get_shop(shop_id)
	if shop == null or not owns(item_id):
		return {"ok": false, "price": 0, "reason": "nothing to sell"}
	if not is_open(shop_id):
		return {"ok": false, "price": 0, "reason": "shop closed"}
	var price := shop.sell_back_for(base_price(item_id))
	owned.erase(item_id)
	earn(price, "sold to " + shop_id)
	return {"ok": true, "price": price, "reason": ""}

## Everything a shop has on its shelves right now, as [{id, price, owned}].
func stock_of(shop_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shop := get_shop(shop_id)
	if shop == null:
		return out
	var ids: Array = shop.stock_ids.duplicate()
	if ids.is_empty():
		if shop.stock_kinds.has("garment"):
			ids.append_array(ToriyamaKitCharacter.list_parts("garment"))
		if shop.stock_kinds.has("prop"):
			ids.append_array(ToriyamaKitCharacter.list_parts("prop"))
		if shop.stock_kinds.has("food"):
			ids.append_array(["meal_simple", "meal_good", "coffee", "snack"])
		if shop.stock_kinds.has("board_part"):
			ids.append_array(["deck_basic", "deck_pro", "trucks_basic", "trucks_pro", "wheels_soft",
				"wheels_hard", "bearings_basic", "bearings_pro", "grip_tape", "hardware",
				"board_beginner", "board_street", "board_park", "longboard"])
	for id in ids:
		var name := String(id)
		if CreatorDataScript.STARTER_PARTS.has(name):
			continue                                    # already theirs; nothing to sell
		out.append({"id": name, "price": shop.price_for(base_price(name)), "owned": owns(name)})
	return out

# ------------------------------------------------------------------ setup
func _register_default_shops() -> void:
	var store := ShopDefinition.new()
	store.id = "general_store"; store.display_name = "The General Store"
	store.location_id = "loc_store"; store.job_id = "general_store_clerk"
	store.stock_kinds.assign(["garment", "food"])
	register_shop(store)

	var skate := ShopDefinition.new()
	skate.id = "skate_shop"; skate.display_name = "Rolling Tides Boards"
	skate.location_id = "loc_skate_shop"; skate.job_id = "skate_shop_clerk"
	skate.stock_kinds.assign(["board_part"])
	skate.open_hour = 11
	skate.close_hour = 20
	register_shop(skate)

# ------------------------------------------------------------------- save
func to_dict() -> Dictionary:
	return {"money": money, "owned": owned.duplicate(true), "history": history.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	money = int(d.get("money", money))
	owned = (d.get("owned", {}) as Dictionary).duplicate(true)
	history.assign(d.get("history", []))
	money_changed.emit(money, 0, "load")

func reset_for_tests() -> void:
	money = 0
	owned.clear()
	history.clear()
	_shops.clear()
	_register_default_shops()
