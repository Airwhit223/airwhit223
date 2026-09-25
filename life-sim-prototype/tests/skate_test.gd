extends SceneTree
## Skate shop (milestones 9-13): shell + door, request data, component attributes, compatibility + scoring, assembly
## at the bench (order enforced, tighten step), hand-over scoring and pay, the wall of builds, skill-gated info,
## level unlocks, mastery. Screenshots to user://skate_test/.
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _f(n := 5) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)
var sh
var player
func _use(kind: String, param := "") -> void:
	sh.use(sh.station(kind, param), player)
func _assemble(b: Dictionary, tighten := true) -> void:
	for kind in ["deck", "trucks", "bearings", "wheels"]:
		sh.pick(kind, b[kind]); _use("bench")
	if tighten:
		_use("bench")
func _serve(request_id: String, b: Dictionary, tighten := true) -> Dictionary:
	sh.customers.clear()
	sh.new_customer(request_id)
	_assemble(b, tighten)
	var before: Dictionary = root.get_node("JobManager").shift.duplicate(true)
	_use("counter")
	return before

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://skate_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var jm = root.get_node("JobManager")

	# ---- pure data: attributes, compatibility, scoring
	var street := {"deck": "street_80", "trucks": "trucks_80", "bearings": "abec5", "wheels": "w52_99"}
	var cruiser := {"deck": "cruiser_90", "trucks": "cruiser_trucks_90", "bearings": "abec7", "wheels": "w60_78"}
	var st: Dictionary = SkateCatalog.stats(street)
	_expect(st["price"] == 140 and is_equal_approx(st["pop"], 0.8), "board stats from parts: %s" % str(st))
	_expect(SkateCatalog.compatibility(street).is_empty(), "matched street parts are compatible")
	_expect("the trucks don't fit the deck" in SkateCatalog.compatibility({"deck": "street_80", "trucks": "cruiser_trucks_90"}), "truck width mismatch caught")
	_expect(SkateCatalog.compatibility({"deck": "street_80", "wheels": "w60_78"}).size() == 1, "wheel bite caught")
	_expect(SkateCatalog.compatibility({"deck": "hover_90", "trucks": "trucks_80"}).size() >= 1, "hover + regular parts caught")
	var req_first: Dictionary = SkateCatalog.REQUESTS.filter(func(r): return r["id"] == "first_board")[0]
	var req_walk: Dictionary = SkateCatalog.REQUESTS.filter(func(r): return r["id"] == "boardwalk")[0]
	var good := SkateCatalog.judge(req_first, street)
	_expect(good["ok"] and good["problems"].is_empty() and good["satisfaction"] >= 0.95, "street board fits a first-board request")
	var wrong := SkateCatalog.judge(req_walk, street)
	_expect(not wrong["ok"] and "that's not a cruiser board" in wrong["problems"], "street board fails a cruiser request: %s" % str(wrong["problems"]))
	_expect(SkateCatalog.judge(req_walk, cruiser)["ok"], "cruiser build fits the boardwalk request")
	# every request can be met well at its level (the data is solvable)
	var best := {
		"first_board": street, "plaza_tech": {"deck": "street_80", "trucks": "trucks_80", "bearings": "abec7", "wheels": "w54_101"},
		"big_feet": {"deck": "street_85", "trucks": "trucks_85", "bearings": "abec5", "wheels": "w52_99"},
		"boardwalk": cruiser, "commute": cruiser,
		"budget_kid": {"deck": "blank_80", "trucks": "budget_trucks_80", "bearings": "budget_bearings", "wheels": "budget_w52"},
		"hill_bomb": {"deck": "longboard_95", "trucks": "rkp_95", "bearings": "ceramic", "wheels": "w70_80"},
		"sponsored": {"deck": "street_80", "trucks": "trucks_80", "bearings": "ceramic", "wheels": "w54_101"},
		"hover": {"deck": "hover_90", "trucks": "grav_emitters", "bearings": "flux_core", "wheels": "hover_pads"},
	}
	var unsolved: Array = []
	for r in SkateCatalog.REQUESTS:
		var j := SkateCatalog.judge(r, best[r["id"]])
		if float(j["satisfaction"]) < 0.9: unsolved.append("%s %.2f %s" % [r["id"], j["satisfaction"], j["problems"]])
	_expect(unsolved.is_empty(), "every request has a strong build: %s" % str(unsolved))

	# ---- the shop in the world
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(40)
	root.get_node("RetroPS2").apply(&"off")
	var tm = root.get_node("TimeManager"); tm.hour = 12
	player = root.get_tree().get_first_node_in_group("player")
	sh = main.find_child("SkateShopWorkshop", true, false)
	_expect(sh != null and sh.station("bench") != null and sh.station("rack", "wheels") != null, "workshop built")
	var door = main.find_child("SkateShopDoor", true, false)
	_expect(door != null and door.get_node(door.destination) == sh.get_node("ShopEntry"), "street door leads into the workshop")
	var shop_shell = main.find_child("Skateshop", true, false)
	_expect(shop_shell != null and door.global_position.distance_to(shop_shell.global_position) < 3.5, "door is on the skateshop building")
	_expect(sh.prompt_for(sh.station("bench")) == "(Clock in to build)", "bench idle until clocked in")
	# street front screenshot
	var cam := Camera3D.new(); main.add_child(cam)
	cam.global_position = Vector3(7.5, 3, -2); cam.look_at(Vector3(7.5, 1.5, 8)); cam.current = true
	await _f(6)
	root.get_texture().get_image().save_png(out + "shop_front.png")

	_expect(jm.start_shift("skate_builder", 2), "clock in")
	sh.auto_customers = false
	_expect(sh.customers.size() == 1, "a customer arrives")
	player.stamina = player.max_stamina
	# assembly order enforced
	sh.customers.clear(); sh.new_customer("first_board")
	_expect(not sh.pick("deck", "longboard_95"), "level-1 builder can't take a longboard deck")
	sh.pick("wheels", "w52_99")
	_expect(sh.prompt_for(sh.station("bench")) == "Mount the deck first", "wheels before the deck is refused")
	_use("rack", "wheels")
	_expect(sh.held.is_empty(), "put the wheels back on the rack")
	sh.pick("deck", "street_80"); _use("bench")
	_expect(sh.build.get("deck") == "street_80" and sh._bench_board.get_child_count() == 1, "deck mounted and shown on the bench")
	sh.pick("trucks", "trucks_80"); _use("bench")
	sh.pick("bearings", "abec5"); _use("bench")
	sh.pick("wheels", "w52_99"); _use("bench")
	_expect(sh._bench_board.get_child_count() == 7, "trucks and wheels appear on the bench board")
	_expect(sh.prompt_for(sh.station("bench")) == "Tighten & check the board", "tighten step")
	_expect(player.stamina < player.max_stamina, "mounting costs stamina")
	_use("bench")
	_expect(sh.tightened, "tightened")
	# a close-up of the bench mid-shift
	player.global_position = sh.global_position + Vector3(0, 0, 3)
	cam.global_position = sh.global_position + Vector3(3.5, 3.2, 4.2); cam.look_at(sh.global_position + Vector3(-0.8, 0.8, -1.5))
	await _f(8)
	root.get_texture().get_image().save_png(out + "workshop.png")
	_use("counter")
	_expect(jm.shift["ok"] == 1 and jm.shift["mistakes"] == 0, "perfect first board handed over")
	_expect(sh.build.is_empty() and sh.recent.size() == 1 and sh.recent[0]["stars"] == 5, "board goes up on the wall with 5 stars")
	_expect(int(jm.jobs["skate_builder"]["memory"]["boards_built"]) == 1, "shop remembers boards built")
	# mistakes: loose hardware, mismatched trucks
	var before: Dictionary = _serve("first_board", street, false)
	_expect(jm.shift["mistakes"] == before["mistakes"] + 1, "forgot to tighten -> a mistake")
	jm.skills["mechanical"] = 0.0
	before = _serve("first_board", {"deck": "street_80", "trucks": "cruiser_trucks_90", "bearings": "abec5", "wheels": "w52_99"})
	_expect(jm.shift["mistakes"] > before["mistakes"] and jm.shift["ok"] == before["ok"], "9.0 cruiser trucks on an 8.0 deck fails the order")
	before = _serve("boardwalk_locked_check", street)   # unknown id -> no customer, nothing served
	_expect(jm.shift["orders"] == before["orders"], "no customer, nothing to hand over")
	sh.build = {}; sh.tightened = false; sh.held = {}
	# skill-gated information
	sh.customers.clear(); sh.new_customer("plaza_tech")
	sh._update_ui()
	_expect(not sh._ui_label.text.contains("needs pop"), "a new builder only hears the customer's words")
	jm.skills["skate_knowledge"] = 30.0
	sh._update_ui()
	_expect(sh._ui_label.text.contains("needs pop high, speed medium"), "Skate Knowledge 25+ reveals what they need")
	_expect(sh.stat_text(0.8) == "high", "part stats in words below 50 knowledge")
	jm.skills["skate_knowledge"] = 60.0
	_expect(sh.stat_text(0.8) == "0.80", "numbers at 50+ knowledge")
	var s: Dictionary = jm.finish_shift()
	print("summary: ", s)
	_expect(s["total"] > 0 and s["attempted"] >= 3, "shift paid out ($%d)" % s["total"])

	# ---- level 2: longboards; mastery: free stamina
	jm.jobs["skate_builder"]["level"] = 2
	jm.skills["mechanical"] = 100.0
	jm.skills["crafting"] = 100.0
	player.energy = 100.0
	_expect(jm.start_shift("skate_builder", 2), "level-2 shift")
	sh.auto_customers = false
	player.stamina = player.max_stamina * 0.5
	var stam: float = player.stamina
	_serve("hill_bomb", best["hill_bomb"])
	_expect(jm.shift["ok"] >= 1, "hill-bomb longboard built at level 2")
	_expect(is_equal_approx(player.stamina, stam), "a master builder spends no stamina")
	# the wall with two boards
	cam.global_position = sh.global_position + Vector3(2.5, 1.8, -0.5); cam.look_at(sh.global_position + Vector3(5.7, 1.5, -0.5))
	await _f(8)
	root.get_texture().get_image().save_png(out + "build_wall.png")
	jm.finish_shift()

	print("SKATE_TEST ALL PASS" if failures.is_empty() else "SKATE_TEST FAILED: %s" % str(failures))
	quit()
