extends SceneTree
## One item store: farming, quests, gifts and the chest all share InventoryManager.
## Run: godot --headless -s tests/inventory_test.gd

var fails := 0

func _init() -> void:
	_run.call_deferred()

func _expect(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	for i in 3:
		await process_frame
	var inv = root.get_node("InventoryManager")
	var farm = root.get_node("FarmingManager")
	var qm = root.get_node("QuestManager")
	var eco = root.get_node("Economy")
	qm.reset_for_tests()
	farm.reset_for_tests()

	# farming reads and writes the bag
	_expect(inv.count("turnip_seed") == farm.STARTER_SEEDS, "starter seeds are in the bag")
	farm.use_seed("turnip")
	_expect(inv.count("turnip_seed") == farm.STARTER_SEEDS - 1, "planting takes a seed from the bag")
	farm.add_harvest("turnip", 3)
	_expect(inv.count("turnip") == 3 and farm.get_produce_count("turnip") == 3, "harvest lands in the bag")

	# a quest item objective completes from farm produce
	qm.add_quest({"id": "turnip_q", "title": "Turnips", "giver": "nobody",
		"stages": [{"journal": "Grow 5 turnips", "objectives": [{"type": "item", "item": "turnip", "count": 5}]},
			{"journal": "Done", "objectives": [{"type": "flag", "flag": "never"}]}]})
	qm.handle_topic("nobody", "quest:turnip_q:offer")
	_expect(qm.stage_index("turnip_q") == 0, "turnip quest active, 3/5 not enough")
	farm.add_harvest("turnip", 2)
	_expect(qm.stage_index("turnip_q") == 1, "two more harvested turnips complete the objective")

	# quest items: in the bag, never lost to a full bag, not giftable
	qm.give_item("medicine_herb")
	_expect(inv.count("medicine_herb") == 1 and inv.is_quest_item("medicine_herb"), "quest item stored in the bag")
	_expect(inv.display_name("medicine_herb") == "Moonroot herb", "quest item uses its catalog name")
	for k in inv.PLAYER_SLOT_CAPACITY:
		inv.add("junk_%d" % k)
	_expect(not inv.add("one_more"), "full bag refuses ordinary items")
	qm.give_item("relic_shard")
	_expect(inv.count("relic_shard") == 1, "quest rewards still arrive in a full bag")
	for k in inv.PLAYER_SLOT_CAPACITY:
		inv.set_count("junk_%d" % k, 0)

	# chest
	var cid := "test_chest"
	inv.ensure_storage(cid)
	_expect(inv.deposit(cid, "turnip", 5) and inv.count("turnip") == 0 and inv.storage_count(cid, "turnip") == 5, "deposit a stack")
	_expect(inv.withdraw(cid, "turnip", 2) and inv.count("turnip") == 2, "withdraw part of it")
	eco.money = 100
	_expect(not inv.upgrade_storage(cid) and int(inv.storage_data(cid)["rank"]) == 1, "can't afford the $250 upgrade")
	eco.money = 300
	_expect(inv.upgrade_storage(cid) and eco.money == 50 and inv.storage_capacity(cid) == 24, "upgrade paid through Economy")

	# chest panel builds and lists both sides
	var panel = load("res://ui/chest_panel.gd").open(cid)
	root.add_child(panel)
	await process_frame
	await process_frame
	_expect(panel._chest.get_child_count() >= 2 and panel._pockets.get_child_count() >= 2, "chest panel lists pockets and chest")
	_expect(panel._upgrade.text.contains("$900"), "panel shows the next upgrade price: " + panel._upgrade.text)
	panel._close()

	# save: the bag carries everything; old saves migrate into it
	var saved: Dictionary = inv.to_dict()
	inv.items.clear()
	inv.from_dict(saved)
	_expect(inv.count("turnip") == 2 and inv.count("medicine_herb") == 1, "bag round-trips")
	farm.from_dict({"inventory": {"turnip": 4}})
	qm.from_dict({"state": {}, "items": {"explorer_map": 1}, "flags": {}})
	_expect(inv.count("turnip") == 6 and inv.count("explorer_map") == 1, "old farm/quest item saves merge into the bag")
	_expect(not qm.to_dict().has("items") and farm.to_dict().is_empty(), "no second item store is saved")

	print("INVENTORY_TEST ALL PASS" if fails == 0 else "INVENTORY_TEST %d FAILED" % fails)
	quit()
