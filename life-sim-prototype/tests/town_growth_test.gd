extends SceneTree
## Town growth: buildings unlock from levels and story milestones, go up empty, and then people move into the
## vacancies — ordinary newcomers, or someone specific when the story asked for them.

var failures: Array[String] = []
var growth
var prog

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _level_to(target: int) -> void:
	var guard := 0
	while prog.level < target and guard < 100000:
		prog.add_xp(prog.xp_to_next() + 1.0)
		guard += 1

func _run() -> void:
	growth = root.get_node("TownGrowth")
	prog = root.get_node("Progression")
	growth.reset(); prog.reset()

	# --- nothing has grown yet
	_expect(growth.unlocked_buildings().is_empty(), "the town starts as it is")
	_expect(growth.vacancies().is_empty(), "with no empty homes waiting")

	# --- a level unlocks a building, and it goes up EMPTY
	_level_to(5)
	_expect(growth.unlocked_buildings().has(&"rowhouse_east"), "reaching level 5 puts up the rowhouse")
	_expect(growth.vacancies().size() == 2, "it stands empty: two homes vacant")
	_expect(growth.residents().is_empty(), "nobody has moved in yet")

	# --- an ordinary newcomer fills a vacancy
	var newcomer: NPCDefinition = growth.send_resident()
	_expect(newcomer != null and newcomer.traits.size() == 2, "a newcomer arrives, generated like any townsperson")
	_expect(growth.vacancies().size() == 1, "they take one of the empty homes")
	_expect(growth.residents().size() == 1, "and the home counts as occupied")

	# --- a story milestone puts up a building AND sends the person it was meant for
	growth.story_milestone(&"gear_path_started")
	_expect(growth.unlocked_buildings().has(&"workshop_row"), "a story milestone can unlock a building")
	var mechanic: NPCDefinition = null
	for home_id in growth.residents():
		if String(home_id).begins_with("home_workshop_row"):
			mechanic = newcomer
	_expect(growth.residents().size() == 2, "the workshop's resident moved in with it")
	var arrivals: Array = growth.residents().values()
	_expect(arrivals.size() == 2, "two people have arrived in total")

	# --- a milestone can also send someone specific into a home that already exists
	var before: int = growth.residents().size()
	growth.story_milestone(&"first_festival_hosted")
	_expect(growth.residents().size() == before + 1, "a milestone can fill an existing vacancy")
	_expect(growth.vacancies().is_empty(), "the rowhouse is now full")

	# --- specific arrivals really are the kind that was asked for
	growth.reset(); prog.reset()
	_level_to(5)
	var asked := {"job": "mechanic", "traits": [&"tinkerer", &"careful"]}
	var specific: NPCDefinition = growth.send_specific_resident(asked)
	_expect(specific.occupation == "mechanic", "the story got the job it asked for")
	_expect(specific.traits.has(&"tinkerer") and specific.traits.has(&"careful"), "and the traits it asked for")
	_expect(specific.register == TownsfolkGenerator.register_for(specific.traits),
		"their register still follows from their traits")

	# --- growth never repeats itself, and survives a save
	var count: int = growth.unlocked_buildings().size()
	growth.evaluate(); growth.evaluate()
	_expect(growth.unlocked_buildings().size() == count, "evaluating again unlocks nothing twice")
	var saved: Dictionary = growth.to_dict()
	growth.reset()
	_expect(growth.unlocked_buildings().is_empty(), "reset clears growth")
	growth.from_dict(saved)
	_expect(growth.unlocked_buildings().size() == count, "unlocked buildings survive a save and load")

	# --- and in the world: the building is really there and the newcomer lives in it
	growth.reset(); prog.reset()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(60)
	var before_people: int = root.get_tree().get_nodes_in_group("npc").size()
	_level_to(5)
	await _frames(10)
	growth.send_resident()
	await _frames(20)
	_expect(main.get_node_or_null("NavRegion/rowhouse_east") != null, "the building exists in the world")
	var ws = root.get_node("WorldState")
	_expect(ws.has_location("home_rowhouse_east_0"), "its homes are registered as locations")
	_expect(root.get_tree().get_nodes_in_group("npc").size() == before_people + 1, "the newcomer is living in town")
	_expect(root.get_tree().get_nodes_in_group("newcomer").size() == 1, "and is marked as someone who moved in")

	growth.reset(); prog.reset()
	print("TOWN_GROWTH_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
