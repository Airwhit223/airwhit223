extends SceneTree
## QuestManager: a quest offered through an NPC's real conversation, a talk objective, an item objective, a delivery,
## a follower stage, a zone objective, completion + reward flags.
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _f(n := 5) -> void:
	for i in n: await process_frame
func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(40)
	var qm = root.get_node("QuestManager")
	var npcs := root.get_tree().get_nodes_in_group("npc")
	_expect(npcs.size() >= 2, "town has NPCs")
	var a = npcs[0]; var b = npcs[1]
	var ida: String = a.definition.id; var idb: String = b.definition.id
	qm.add_quest({"id": "test_q", "title": "Test Errand", "giver": ida, "ask_label": "Need anything?",
		"offer_line": "Could you help me?",
		"stages": [
			{"journal": "Talk to B.", "objectives": [{"type": "talk", "npc": idb, "label": "A sent me.", "line": "Ah, here's what they need."}]},
			{"journal": "Walk with A to the park.", "follower": ida, "objectives": [{"type": "reach", "zone": "test_zone"}]},
			{"journal": "Find the widget.", "objectives": [{"type": "item", "item": "widget", "count": 2}]},
			{"journal": "Give A the widgets.", "objectives": [{"type": "deliver", "npc": ida, "item": "widget", "count": 2, "label": "Here.", "line": "Perfect!"}]},
		], "set_flags": ["test_done"]})
	# the same calls NPCConversation.grouped_topics()/say() make (NPCConversation itself can't compile under -s)
	var offer := ""
	for t in qm.topics_for(ida):
		if String(t["id"]).begins_with("quest:test_q:offer"): offer = t["id"]
	_expect(offer != "", "giver offers the quest in conversation")
	var r: Dictionary = qm.handle_topic(ida, offer)
	_expect(qm.status("test_q") == qm.Status.ACTIVE and r["line"] == "Could you help me?", "accepting starts the quest")
	_expect(qm.tracker_lines().size() >= 1 and "Talk to B" in qm.tracker_lines()[0], "tracker shows the objective")
	var talk := ""
	for t in qm.topics_for(idb):
		if String(t["id"]).begins_with("quest:test_q:talk"): talk = t["id"]
	_expect(talk != "", "second NPC has the talk topic")
	qm.handle_topic(idb, talk)
	_expect(qm.stage_index("test_q") == 1, "talk objective advances")
	_expect(a.is_following_player, "follower stage: A follows the player")
	root.get_tree().get_first_node_in_group("player").enter_zone("test_zone")
	_expect(qm.stage_index("test_q") == 2, "reaching the zone advances")
	_expect(not a.is_following_player, "follower goes home when the stage ends")
	qm.give_item("widget")
	_expect(qm.stage_index("test_q") == 2, "one widget is not enough")
	qm.give_item("widget")
	_expect(qm.stage_index("test_q") == 3, "two widgets complete the item objective")
	var deliver := ""
	for t in qm.topics_for(ida):
		if String(t["id"]).begins_with("quest:test_q:deliver"): deliver = t["id"]
	_expect(deliver != "", "delivery topic appears when holding the items")
	qm.handle_topic(ida, deliver)
	_expect(qm.status("test_q") == qm.Status.DONE and qm.flags.get("test_done", false) and int(qm.items.get("widget", 0)) == 0, "delivery completes the quest, takes items, sets flags")
	var saved: Dictionary = qm.to_dict()
	_expect(saved["state"]["test_q"]["status"] == qm.Status.DONE, "state saves")
	print("QUEST_TEST ", ("FAILED: " + str(failures)) if failures else "ALL PASS")
	quit(1 if failures else 0)
