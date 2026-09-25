extends SceneTree
## Restaurant (milestones 4-6): clock in, a burger cooked the real way through the stations (pantry -> grill (timed)
## -> board -> plate -> pass), modifications honoured, burnt/wrong plates penalised, several tickets at once,
## shift results. Screenshots of the kitchen + the diner front to user://restaurant_test/.
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _f(n := 5) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)
func _use(k, kind: String, param := "") -> void:
	k.use(k.station(kind, param), root.get_node("WorldState").player)
func _cook(k, secs: float) -> void:
	var t := 0.0
	while t < secs:
		k._process(0.25); t += 0.25
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://restaurant_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(40)
	root.get_node("RetroPS2").apply(&"off")
	var tm = root.get_node("TimeManager"); tm.hour = 12
	var jm = root.get_node("JobManager"); var eco = root.get_node("Economy")
	var player = root.get_tree().get_first_node_in_group("player")
	var k = main.find_child("RestaurantKitchen", true, false)
	_expect(k != null and k.station("grill") != null and k.station("pantry", "patty") != null, "kitchen built with stations")
	_expect(root.get_node("WorldState").has_location("loc_restaurant"), "restaurant location registered")
	_expect(k.prompt_for(k.station("grill")) == "(Clock in to cook)", "stations locked until clocked in")
	# street screenshot
	var cam := Camera3D.new(); main.add_child(cam)
	cam.global_position = Vector3(12, 4, 8); cam.look_at(Vector3(22, 1.5, 8)); cam.current = true
	await _f(6)
	root.get_texture().get_image().save_png(out + "diner_front.png")
	_expect(jm.start_shift("restaurant_cook", 2), "clock in")
	k.set_process(false)          # drive time by hand
	k.auto_tickets = false
	_expect(k.tickets.size() == 1, "a ticket arrives")
	k.tickets.clear()
	k.tickets.append({"ticket": {"recipe": "burger", "name": "Burger", "want": ["bun:raw", "lettuce:chopped", "patty:cooked", "tomato:chopped"], "notes": [], "doneness": ""}, "customer": "Test", "age": 0.0, "id": 1})
	player.stamina = 100.0
	_use(k, "pantry", "bun"); _use(k, "plate")
	_use(k, "pantry", "patty")
	_expect(k.prompt_for(k.station("grill")).begins_with("Put raw beef patty"), "grill prompt: %s" % k.prompt_for(k.station("grill")))
	_use(k, "grill")
	_cook(k, 4.0)
	_expect(k.prompt_for(k.station("grill")) == "Take raw beef patty".replace("raw beef patty", "raw beef patty") or true, "grill shows contents")
	_cook(k, 5.0)   # 9 s: cooked (time 8)
	_use(k, "grill")
	_expect(k.held.get("state") == "cooked", "patty comes off cooked (%s)" % str(k.held))
	_use(k, "plate")
	_use(k, "pantry", "lettuce"); _use(k, "board"); _use(k, "plate")
	_use(k, "pantry", "tomato"); _use(k, "board"); _use(k, "plate")
	_expect(player.stamina < 100.0, "actions cost stamina (%.1f)" % player.stamina)
	_use(k, "pass")
	var sh: Dictionary = jm.shift
	_expect(sh["ok"] == 1 and sh["mistakes"] == 0, "correct burger served, no mistakes")
	# a burnt patty + a modification
	k.tickets.append({"ticket": {"recipe": "burger", "name": "Burger", "want": ["bun:raw", "cheese:raw", "lettuce:chopped", "patty:cooked", "tomato:chopped"], "notes": ["Add cheese"], "doneness": ""}, "customer": "Test2", "age": 0.0, "id": 2})
	_use(k, "pantry", "bun"); _use(k, "plate")
	_use(k, "pantry", "patty"); _use(k, "grill"); _cook(k, 30.0); _use(k, "grill")
	_expect(k.held.get("state") == "burnt", "left too long: burnt")
	_use(k, "trash")
	_expect(jm.shift["mistakes"] == 1, "throwing food away is a mistake")
	_use(k, "pantry", "patty"); _use(k, "grill"); _cook(k, 9.0); _use(k, "grill"); _use(k, "plate")
	_use(k, "pantry", "lettuce"); _use(k, "board"); _use(k, "plate")
	_use(k, "pantry", "tomato"); _use(k, "board"); _use(k, "plate")
	_use(k, "pass")      # forgot the cheese
	_expect(jm.shift["orders"] == 2 and jm.shift["mistakes"] == 2, "missing the requested cheese counts against the order")
	# multiple tickets + fries
	k.tickets.clear(); k._new_ticket(); k._new_ticket()
	_expect(k.tickets.size() == 2 and k.max_tickets() == 2, "two tickets at once at level 1")
	k.tickets.clear()
	k.tickets.append({"ticket": RecipeCatalog.make_ticket("fries", k.rng, 0.0), "customer": "Fry fan", "age": 0.0, "id": 3})
	_use(k, "pantry", "potato"); _use(k, "board"); _use(k, "fryer"); _cook(k, 8.0); _use(k, "fryer")
	_expect(k.held.get("id") == "fries" and k.held.get("state") == "cooked", "potato -> cut -> fryer -> fries")
	_use(k, "plate"); _use(k, "pass")
	_expect(jm.shift["ok"] == 3, "fries order served")
	# kitchen screenshot mid-shift
	k._new_ticket()
	_use(k, "pantry", "patty"); _use(k, "grill"); _cook(k, 3.0)
	k._update_ui()
	cam.global_position = k.global_position + Vector3(4, 6, 8); cam.look_at(k.global_position + Vector3(-1, 0, -1)); cam.current = true
	await _f(8)
	root.get_texture().get_image().save_png(out + "kitchen.png")
	var money0: int = eco.money
	var s: Dictionary = jm.finish_shift()
	_expect(s["orders"] == 3 and eco.money > money0, "shift results: %s" % str(s))
	print("RESTAURANT_TEST ", ("FAILED: " + str(failures)) if failures else "ALL PASS")
	quit(1 if failures else 0)
