extends SceneTree
## Milestone 3: money, a price book, shops that can be shut, and ownership the creator can read.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	await process_frame
	var score := {"pass": 0, "fail": 0}
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))
	var eco = root.get_node("Economy")
	var rules = root.get_node("GameRules")
	eco.reset_for_tests()

	print("[money]")
	eco.money = 0
	eco.earn(120, "shift")
	check.call("earning adds up", eco.money == 120, str(eco.money))
	check.call("spending what you have works", eco.spend(50, "lunch") and eco.money == 70, str(eco.money))
	check.call("spending what you don't have is refused", not eco.spend(500, "boat"))
	check.call("...and takes nothing", eco.money == 70, str(eco.money))
	check.call("the movement is logged", eco.history.size() >= 2 and eco.history[-1]["reason"] == "lunch")

	print("[a price book, not several]")
	check.call("food is priced here", eco.base_price("meal_simple") == 18)
	check.call("creator parts keep their own price", eco.base_price("TR_Chunky_Hi") == CreatorData.price_of("TR_Chunky_Hi"),
		str(eco.base_price("TR_Chunky_Hi")))
	check.call("starter clothes are free", eco.base_price("Shirt_Casual_01") == 0)

	print("[shops mark the book price up, they do not keep a second list]")
	var shop: ShopDefinition = eco.get_shop("general_store")
	check.call("the default shops registered", eco.shops().size() >= 2, str(eco.shops().size()))
	shop.markup = 1.5
	check.call("markup applies on top of the book", eco.price_at("general_store", "meal_good") == 63,
		str(eco.price_at("general_store", "meal_good")))
	shop.markup = 1.0

	print("[buying]")
	# open the doors first: the shop-closed path is exercised in its own section below
	var tm0 = root.get_node("TimeManager"); tm0.hour = 12
	root.get_node("WorldState").assign_job("general_store_clerk", "town_00")
	eco.money = 400
	var r: Dictionary = eco.buy("TR_Chunky_Hi", "general_store")
	print("   bought for %d, %d left" % [int(r["price"]), eco.money])
	check.call("a purchase goes through", bool(r["ok"]))
	check.call("the money left the wallet", eco.money == 400 - int(r["price"]))
	check.call("and the item arrived", eco.owns("TR_Chunky_Hi"))
	check.call("buying it twice is refused", not bool(eco.buy("TR_Chunky_Hi", "general_store")["ok"]))
	eco.money = 5
	var poor: Dictionary = eco.buy("TR_Skate_Hi", "general_store")
	check.call("no money, no sale", not bool(poor["ok"]) and String(poor["reason"]) == "cannot afford")
	check.call("...and the money is untouched", eco.money == 5, str(eco.money))

	print("[a shop with nobody in it is shut]")
	var tm = tm0
	tm.hour = 3
	check.call("closed outside its hours", not eco.is_open("general_store"))
	tm.hour = 12
	var ws = root.get_node("WorldState")
	ws.vacate_job("general_store_clerk")
	check.call("closed when nobody is behind the counter", not eco.is_open("general_store"))
	ws.assign_job("general_store_clerk", "town_00")
	check.call("open when staffed and in hours", eco.is_open("general_store"))
	eco.money = 9999
	check.call("you cannot buy from a shut shop", not bool(eco.buy("TR_Skate_Lo", "skate_shop")["ok"]),
		String(eco.buy("TR_Skate_Lo", "skate_shop")["reason"]))

	print("[the creator reads ownership]")
	check.call("an owned part is unlocked", CreatorData.owns_through_economy("TR_Chunky_Hi"))
	check.call("an unowned part is not", not CreatorData.owns_through_economy("TR_Varsity_Jacket"))
	check.call("starter clothes need no purchase", CreatorData.is_unlocked("Shirt_Casual_01"))

	print("[sandbox dials reach it]")
	rules.start_new_game(rules.Mode.SANDBOX, {"starting_money": 1000})
	check.call("starting money is a sandbox setting", int(rules.value("starting_money")) == 1000)

	print("[saves]")
	eco.money = 321
	var blob: Dictionary = eco.to_dict()
	eco.reset_for_tests()
	eco.from_dict(blob)
	check.call("money and belongings survive a save", eco.money == 321 and eco.owns("TR_Chunky_Hi"))

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
