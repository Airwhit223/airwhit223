extends SceneTree
## Adventure Contracts (milestones 14-18): promotion hooks, contract data -> quests, the contract board, the Old Crypt
## retrieval contract end to end, the Stolen Shipment (goblins, skeletons, Hollowed Moon thugs; counted faction kills +
## crates; the optional ledger), rank and rewards, tracking glow, saving. Screenshots to user://contract_test/.
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _f(n := 5) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _phys(n := 4) -> void:
	for i in n: await physics_frame
## a door: the player's teleport fades out first, then moves
func _through(door, player) -> void:
	door.interact(player)
	await create_timer(1.2).timeout
	await _phys(4)
func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://contract_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var qm = root.get_node("QuestManager"); var am = root.get_node("AdventureManager"); var jm = root.get_node("JobManager")
	var eco = root.get_node("Economy"); var inv = root.get_node("InventoryManager")
	var CB = load("res://world/contracts/contract_board.gd")

	# ---- 14: progression hooks - a promotion offer shows in the job panel with an accept button
	jm.jobs["ranch_hand"]["memory"]["promotion_offered"] = 2
	var jp = load("res://ui/job_panel.gd").open_start("ranch_hand")
	root.add_child(jp)
	await process_frame
	var texts: Array = jp.find_children("*", "Button", true, false).map(func(b): return b.text)
	_expect("Accept the promotion" in texts, "promotion offer in the job panel: %s" % str(texts))
	jp.find_children("*", "Button", true, false).filter(func(b): return b.text == "Accept the promotion")[0].pressed.emit()
	await process_frame
	_expect(jm.job_level("ranch_hand") == 2, "accepting from the panel promotes")
	for n in root.get_children():
		if n is CanvasLayer and n.get_script() == load("res://ui/job_panel.gd"): n.queue_free()

	# ---- 15: contract data becomes quests
	var qid := ContractCatalog.quest_id("lost_keepsake")
	_expect(not QuestCatalog.by_id(qid).is_empty() and QuestCatalog.by_id(qid)["stages"].size() == 3, "contract -> 3-stage quest")
	_expect(qm.status(ContractCatalog.quest_id("stolen_shipment")) == qm.Status.LOCKED, "stolen shipment locked until the first contract")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(40)
	root.get_node("RetroPS2").apply(&"off")
	var player = root.get_tree().get_first_node_in_group("player")
	var board = main.find_child("ContractBoard", true, false)
	var crypt = main.find_child("Dungeon_old_crypt", true, false)
	var cellar = main.find_child("Dungeon_smuggler_cellar", true, false)
	var crypt_door = main.find_child("old_crypt_entrance", true, false)
	var cellar_door = main.find_child("smuggler_cellar_entrance", true, false)
	_expect(board != null and crypt != null and cellar != null and crypt_door != null and cellar_door != null, "board, dungeons and entrances in the world")
	_expect(crypt.enemies().is_empty(), "dungeons are empty until a contract is taken")
	var cam := Camera3D.new(); main.add_child(cam); cam.current = true
	cam.global_position = board.global_position + Vector3(-2.5, 2.5, 5); cam.look_at(crypt_door.global_position + Vector3(0, 0.5, 0))
	await _f(6)
	root.get_texture().get_image().save_png(out + "board_and_crypt_stairs.png")
	cam.global_position = cellar_door.global_position + Vector3(4, 4, 6); cam.look_at(cellar_door.global_position)
	await _f(6)
	root.get_texture().get_image().save_png(out + "cellar_hatch.png")
	print("cellar hatch at ", cellar_door.global_position)

	# ---- 16: the retrieval contract
	var money0: int = eco.money
	var rep0: float = am.reputation
	var expl0: float = jm.skill("exploration")
	CB.accept("lost_keepsake")
	_expect(qm.status(qid) == qm.Status.ACTIVE, "contract taken")
	_expect(crypt.enemies().size() == 3 and crypt.chests().size() == 1, "crypt populated: 3 skeletons, 1 chest")
	_expect(crypt.enemies()[0].kind == "skeleton" and crypt.enemies()[0].MAX_HEALTH == 40, "skeletons have their own stats")
	await _through(crypt_door, player)
	_expect(qm.stage_index(qid) == 1, "going down the stairs completes 'reach' (stage %d)" % qm.stage_index(qid))
	cam.global_position = crypt.global_position + Vector3(0, 9, 9); cam.look_at(crypt.global_position + Vector3(0, 0, -2))
	await _f(8)
	root.get_texture().get_image().save_png(out + "old_crypt.png")
	crypt.chests()[0].interact(player)
	_expect(inv.count("silver_locket") == 1 and qm.stage_index(qid) == 2, "locket recovered -> return stage")
	_expect(not inv.is_quest_item("silver_locket") == false, "the locket is a quest item")
	var line: String = CB.turn_in("lost_keepsake")
	_expect(qm.status(qid) == qm.Status.DONE and line.contains("locket"), "turned in: %s" % line)
	_expect(eco.money == money0 + 120 and am.reputation == rep0 + 12 and am.rank() == "Bronze", "paid $120, +12 rep, rank %s" % am.rank())
	_expect(jm.skill("exploration") > expl0, "exploration skill grew")
	_expect(inv.count("silver_locket") == 0, "the locket went back to its owner")

	# ---- 17: the stolen goods contract
	var sq := ContractCatalog.quest_id("stolen_shipment")
	_expect(qm.status(sq) == qm.Status.AVAILABLE, "stolen shipment unlocked")
	jm.skills["tracking"] = 30.0
	CB.accept("stolen_shipment")
	var kinds: Array = cellar.enemies().map(func(e): return e.kind)
	_expect(kinds.count("goblin") == 3 and kinds.count("moon_thug") == 2 and kinds.count("skeleton") == 2, "cellar: goblins, thugs, skeletons %s" % str(kinds))
	_expect(cellar.chests().size() == 4 and cellar.chests().all(func(c): return c._glow != null), "4 chests, glowing for a tracker")
	await _through(cellar_door, player)
	_expect(qm.stage_index(sq) == 1, "found the hideout")
	cam.global_position = cellar.global_position + Vector3(0, 13, 12); cam.look_at(cellar.global_position + Vector3(0, 0, -1))
	await _f(8)
	root.get_texture().get_image().save_png(out + "smuggler_cellar.png")
	for e in cellar.enemies().filter(func(e): return e.kind == "goblin"):
		e.take_damage(999)
	_expect(qm.progress_text(sq) == "0/2, 0/3", "goblins don't count as thugs (%s)" % qm.progress_text(sq))
	var thugs: Array = cellar.enemies().filter(func(e): return e.kind == "moon_thug")
	thugs[0].take_damage(999)
	_expect(qm.progress_text(sq) == "1/2, 0/3", "one thug down (%s)" % qm.progress_text(sq))
	_expect(qm.tracker_lines().any(func(l): return l.contains("1/2")), "tracker shows the count")
	# save mid-contract keeps the count
	var saved: Dictionary = qm.to_dict()
	_expect(int(saved["state"][sq]["counts"]["0"]) == 1, "kill count saves")
	thugs[1].take_damage(999)
	for c in cellar.chests():
		c.interact(player)
	_expect(inv.count("shipment_crate") == 3 and inv.count("moon_ledger") == 1, "three crates and the ledger in the bag")
	_expect(qm.stage_index(sq) == 2, "thugs + crates -> return stage")
	var m1: int = eco.money
	line = CB.turn_in("stolen_shipment")
	_expect(qm.status(sq) == qm.Status.DONE, "stolen shipment done: %s" % line)
	_expect(eco.money == m1 + 260 + 80 and qm.flags.get("found_moon_ledger", false), "paid $260 + $80 ledger bonus, story flag set")
	_expect(inv.count("shipment_crate") == 0 and inv.count("moon_ledger") == 0, "crates and ledger handed over")
	var ad: Dictionary = am.to_dict()
	_expect(float(ad["reputation"]) == rep0 + 37.0, "adventure reputation saves (%s)" % ad["reputation"])

	# ---- the board panel renders every state
	var panel = load("res://ui/contract_panel.gd").open()
	root.add_child(panel)
	await _f(4)
	var labels: Array = panel.find_children("*", "Label", true, false).map(func(l): return l.text)
	_expect(labels.count("Completed.") == 2, "board panel lists both contracts as completed")
	panel._close()

	print("CONTRACT_TEST ALL PASS" if failures.is_empty() else "CONTRACT_TEST FAILED: %s" % str(failures))
	quit()
