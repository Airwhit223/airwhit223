extends SceneTree
## Grandpa's ranch (milestones 7-8): clock in at the task board, the board matches the job level, each chore done the
## physical way (feed bin -> trough, pump -> water trough x N, nests -> egg crate), wrong-trough mistakes, stamina per
## action (free at mastery), fence repair once promoted, the loose-hen event, unfinished chores count against the shift,
## Grandpa's bonus and egg gift. Screenshots to user://ranch_test/.
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _f(n := 5) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)
var r
var player
func _use(kind: String, param := "") -> void:
	r.use(r.station(kind, param), player)
func _task(id: String) -> Dictionary:
	for t in r.board:
		if t["id"] == id: return t
	return {}
func _all_eggs() -> void:
	var guard := 0
	while int(_task("eggs")["done"]) < int(_task("eggs")["need"]) and guard < 40:
		guard += 1
		for n in r._nests:
			if n.get_meta("has_egg"):
				r.use(n, player)
		_use("egg_crate")

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://ranch_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(40)
	root.get_node("RetroPS2").apply(&"off")
	var tm = root.get_node("TimeManager"); tm.hour = 8
	var jm = root.get_node("JobManager"); var inv = root.get_node("InventoryManager")
	player = root.get_tree().get_first_node_in_group("player")
	r = main.find_child("GrandpasRanch", true, false)
	_expect(r != null and r.station("feed_bin") != null and r._nests.size() == 6, "ranch built with stations")
	_expect(root.get_node("WorldState").has_location("loc_ranch"), "ranch location registered")
	_expect(absf(r.global_position.y) < 1.0, "ranch sits on the ground (y=%.2f)" % r.global_position.y)
	_expect(r.prompt_for(r.station("feed_bin")) == "Chicken feed", "stations idle until clocked in")

	# ---- level 1, 2-hour shift: feed / water / eggs
	r.rng.seed = 7
	_expect(jm.start_shift("ranch_hand", 2), "clock in at the task board")
	r.grandpa_here = true
	var ids: Array = r.board.map(func(t): return t["id"])
	_expect(ids.slice(0, 3) == ["feed_chickens", "water", "eggs"], "level-1 board: %s" % str(ids))
	r.board = r.board.filter(func(t): return t["id"] in ["feed_chickens", "water", "eggs"])   # event-free for the checks
	player.stamina = 100.0
	# feed the chickens
	_expect(r.prompt_for(r.station("feed_bin")) == "Take chicken feed", "feed bin prompt")
	_use("feed_bin")
	_expect(r.held["id"] == "chicken_feed", "holding chicken feed")
	_expect(r.prompt_for(r.station("chicken_trough")).begins_with("Put chicken feed"), "trough prompt: %s" % r.prompt_for(r.station("chicken_trough")))
	_use("chicken_trough")
	_expect(int(_task("feed_chickens")["done"]) == 1 and jm.shift["ok"] == 1, "chickens fed -> one chore done")
	_expect(player.stamina < 100.0, "actions cost stamina (%.1f)" % player.stamina)
	# wrong trough is a mistake
	_use("pump")
	_use("chicken_trough")
	_expect(jm.shift["mistakes"] == 1 and r.held["id"] == "", "water in the chicken trough is a mistake")
	# water: N trips
	var need: int = _task("water")["need"]
	for i in need:
		_use("pump"); _use("water_trough")
	_expect(int(_task("water")["done"]) == need, "water trough filled in %d trips" % need)
	# eggs: nests match the board, eggs carried in a stack, crate counts them (cracks are made up by new eggs)
	var laid := 0
	for n in r._nests:
		if n.get_meta("has_egg"): laid += 1
	_expect(laid == int(_task("eggs")["need"]), "nests hold today's eggs (%d)" % laid)
	_all_eggs()
	_expect(int(_task("eggs")["done"]) == int(_task("eggs")["need"]), "eggs collected into the crate")
	_expect(r._cleared, "board cleared")
	# screenshot mid-yard
	var cam := Camera3D.new(); main.add_child(cam)
	cam.global_position = r.global_position + Vector3(0, 14, 22); cam.look_at(r.global_position + Vector3(0, 0, 0)); cam.current = true
	await _f(6)
	root.get_texture().get_image().save_png(out + "ranch_yard.png")
	var eggs_before: int = inv.count("egg")
	var s: Dictionary = jm.finish_shift()
	print("summary: ", s)
	_expect(s["orders"] == 3 and s["grade"] in ["Great", "Excellent"], "good shift graded %s" % s["grade"])
	_expect(inv.count("egg") == eggs_before + 2, "Grandpa sends two eggs home to the bag")
	_expect(r.board.is_empty() and r._ui == null, "board and UI cleared after the shift")

	# ---- unfinished chores count against you
	tm.hour = 9
	_expect(jm.start_shift("ranch_hand", 2), "second shift")
	var s2: Dictionary = jm.finish_shift()
	_expect(s2["attempted"] >= 3 and s2["orders"] == 0 and s2["grade"] == "Poor", "walking off leaves chores undone: %s" % s2["grade"])

	# ---- promotion unlocks fence repair; 4-hour board; loose hen event
	jm.jobs["ranch_hand"]["level"] = 2
	tm.hour = 10
	_expect(jm.start_shift("ranch_hand", 4), "4-hour shift at level 2")
	ids = r.board.map(func(t): return t["id"])
	_expect("fence" in ids, "fence repair on the board: %s" % str(ids))
	var broken := 0
	for f in r._fences:
		if f.get_meta("broken"): broken += 1
	_expect(broken == int(_task("fence")["need"]), "broken sections match the board (%d)" % broken)
	player.stamina = 100.0
	for f in r._fences:
		if f.get_meta("broken"):
			_use("lumber"); r.use(f, player)
	_expect(int(_task("fence")["done"]) == int(_task("fence")["need"]), "fence repaired with boards from the lumber pile")
	if _task("loose_chicken").is_empty():
		r.start_event("loose_chicken")
	_expect(r._hen.visible and r.prompt_for(r._hen) == "Catch the hen", "a hen got loose")
	r.use(r._hen, player)
	_expect(int(_task("loose_chicken")["done"]) == 1 and not r._hen.visible, "caught the hen")
	cam.global_position = r.global_position + Vector3(-18, 6, 6); cam.look_at(r.global_position + Vector3(-8, 0, 4))
	await _f(6)
	root.get_texture().get_image().save_png(out + "ranch_coop.png")
	jm.finish_shift()

	# ---- mastery: stamina free
	jm.skills["strength"] = 100.0
	jm.jobs["ranch_hand"]["level"] = 1
	tm.hour = 12
	player.energy = 100.0          # four shifts in one test day would leave anyone too tired to clock in
	_expect(jm.start_shift("ranch_hand", 2), "clock in again after resting")
	player.stamina = player.max_stamina * 0.5
	var before: float = player.stamina
	_use("pump"); _use("water_trough")
	_expect(is_equal_approx(player.stamina, before) and int(_task("water")["done"]) == 1, "master's water trips cost no stamina (%s->%s done %s held %s)" % [before, player.stamina, _task("water"), r.held])
	jm.finish_shift()

	print("RANCH_TEST ALL PASS" if failures.is_empty() else "RANCH_TEST FAILED: %s" % str(failures))
	quit()
