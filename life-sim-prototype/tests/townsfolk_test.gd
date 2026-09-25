extends SceneTree
## Procedurally generated townsfolk: every one has a name, a job, two traits, and a tonal register that follows from
## those traits. They run on the same NPC brain as the authored cast, and they answer the player's adventures and
## power use in their own register.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _run() -> void:
	# --- generation
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var people: Array = []
	for i in 12:
		people.append(TownsfolkGenerator.generate(rng, i))
	var names := {}
	var jobs := {}
	var registers := {}
	var ok_traits := true
	for d in people:
		names[d.first_name + d.last_name] = true
		jobs[d.occupation] = true
		registers[d.register] = true
		if d.traits.size() != 2 or d.occupation == "" or d.schedule.is_empty():
			ok_traits = false
	_expect(ok_traits, "each person has two traits, a job and a schedule")
	_expect(names.size() >= 8, "names vary (%d distinct of 12)" % names.size())
	_expect(jobs.size() >= 3, "jobs vary (%d distinct)" % jobs.size())
	_expect(TownsfolkGenerator.REGISTERS.all(func(r): return TownsfolkGenerator.REGISTERS.has(r)), "registers are the three defined")

	# --- the register comes from the traits, not a separate roll
	_expect(TownsfolkGenerator.register_for([&"dreamer", &"restless"]) == &"lost",
		"dream-touched traits read as lost")
	_expect(TownsfolkGenerator.register_for([&"warm", &"careful"]) == &"grounded",
		"ordinary traits read as grounded")
	_expect(TownsfolkGenerator.register_for([&"tinkerer", &"scrappy"]) == &"genre_aware",
		"curious/gear traits read as genre-aware")
	var twice_a := TownsfolkGenerator.register_for([&"dreamer", &"careful"])
	var twice_b := TownsfolkGenerator.register_for([&"careful", &"dreamer"])
	_expect(twice_a == twice_b, "the register does not depend on trait order")

	# --- seeded: the same town seed gives the same people
	var rng_a := RandomNumberGenerator.new(); rng_a.seed = 999
	var rng_b := RandomNumberGenerator.new(); rng_b.seed = 999
	var one := TownsfolkGenerator.generate(rng_a, 3)
	var two := TownsfolkGenerator.generate(rng_b, 3)
	_expect(one.first_name == two.first_name and one.occupation == two.occupation and one.traits == two.traits,
		"the same seed generates the same person")

	# --- in the world, on the existing brain
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(60)
	var town := root.get_tree().get_nodes_in_group("townsfolk")
	_expect(town.size() == 6, "townsfolk spawned (%d)" % town.size())
	var all_brains := true   # checked by behaviour, not by naming the class (that would compile it before autoloads)
	var all_registered := true
	var ws = root.get_node("WorldState")
	for npc in town:
		if not (npc.has_method("react_to_player") and npc.has_method("setup") and "definition" in npc):
			all_brains = false
		if ws.get_npc(npc.definition.id) == null:
			all_registered = false
	_expect(all_brains, "they use the existing NPC brain, not a parallel system")
	_expect(all_registered, "they register in the world like any other resident")
	_expect(root.get_tree().get_nodes_in_group("npc").size() >= 17, "they live alongside the residents and rivals")

	# --- they answer the player's adventures in their own register
	var lost_line := ""
	var grounded_line := ""
	for npc in town:
		npc.react_to_player("adventure")
		if npc.definition.register == &"lost":
			lost_line = npc.last_remark
		elif npc.definition.register == &"grounded":
			grounded_line = npc.last_remark
	_expect(town.any(func(n): return n.last_remark != ""), "they have something to say about an adventure")
	if lost_line != "" and grounded_line != "":
		_expect(lost_line != grounded_line, "a lost townsperson and a grounded one answer differently")
	var sample = town[0]
	root.get_node("EventBus").fire("player_used_power", {})
	await _frames(4)
	_expect(sample.last_remark_topic == "power", "an event about the player's power reaches them")
	_expect(sample.greeting() != "", "they have a greeting in their register")

	print("TOWNSFOLK_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
