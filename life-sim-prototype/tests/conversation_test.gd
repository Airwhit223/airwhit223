extends SceneTree
## The social pass (2026-09-24): outlook groups, the standing topic list, and answers built from the resident's own
## simulated day. Data only - no rendering - so it can run headless.

func _initialize() -> void: _run.call_deferred()

func _frames(n := 4) -> void:
	for i in n: await process_frame

func _run() -> void:
	var rm = root.get_node("RelationshipManager")
	# loaded here, not preloaded: under --script the autoload identifiers these classes use are not registered
	# until the tree exists, so compiling them at parse time fails
	var ConvoScript: GDScript = load("res://npc/npc_conversation.gd")
	var score := {"pass": 0, "fail": 0}          # a Dictionary, because a lambda captures plain ints by value
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))

	# --- outlook groups are derived, stable, and spread across the roster
	print("[outlook]")
	var rng := RandomNumberGenerator.new(); rng.seed = 4321
	var counts := {}
	var defs: Array = []
	for i in 40:
		var d := TownsfolkGenerator.generate(rng, i)
		defs.append(d)
		var g := NPCOutlook.for_definition(d)
		counts[g] = int(counts.get(g, 0)) + 1
	print("   spread ", counts)
	check.call("every resident lands in a known group", counts.keys().all(func(g): return g in NPCOutlook.GROUPS))
	check.call("more than one group is represented", counts.size() >= 3, str(counts.size()) + " groups")
	check.call("derivation is stable", NPCOutlook.for_definition(defs[0]) == NPCOutlook.for_definition(defs[0]))

	# --- topic gating opens up as the relationship grows
	print("[topics]")
	var state := {"friendship": 0.0, "romance": 0.0, "romanceable": true, "following": false, "asked_today": []}
	var cold := SocialTopics.available(state)
	state["friendship"] = 50.0
	var warm := SocialTopics.available(state)
	state["romance"] = 40.0
	var loved := SocialTopics.available(state)
	print("   stranger %d topics -> friend %d -> romance %d" % [cold.size(), warm.size(), loved.size()])
	check.call("a stranger gets small talk only", cold.size() < warm.size())
	check.call("romance topics need romance", loved.size() > warm.size())
	check.call("flirt is hidden from strangers", not cold.any(func(t): return t["id"] == "flirt"))
	check.call("flirt appears for a friend", warm.any(func(t): return t["id"] == "flirt"))
	check.call("ask_out needs real romance", not warm.any(func(t): return t["id"] == "ask_out")
		and loved.any(func(t): return t["id"] == "ask_out"))
	state["romanceable"] = false
	check.call("un-romanceable residents never show romance topics",
		not SocialTopics.available(state).any(func(t): return int(t["cat"]) == SocialTopics.Cat.ROMANCE))

	# --- a live resident: the day log fills in, and the answer is built from it
	print("[conversation]")
	var world := Node3D.new(); root.add_child(world)
	var brain = load("res://scenes/npc.tscn").instantiate()
	brain.definition = defs[0]
	world.add_child(brain)
	brain.set_physics_process(false)          # no navmesh in this harness; we only need the brain's data side
	await _frames(2)
	brain.day_log.clear()
	brain.day_log.append({"hour": 8, "kind": "activity", "detail": "WORK", "with": ""})
	brain.day_log.append({"hour": 13, "kind": "social", "detail": "have lunch", "with": "Marta"})
	brain.day_log.append({"hour": 16, "kind": "activity", "detail": "EXERCISE", "with": ""})
	var convo = ConvoScript.new(brain)
	print("   %s is %s (%s)" % [defs[0].first_name, NPCOutlook.LABELS[convo.outlook], defs[0].register])
	var opening: String = convo.opening_line()
	print("   opening: ", opening)
	check.call("they open with something", opening.length() > 3)
	var day: Dictionary = convo.say("your_day")
	print("   day:     ", day["line"])
	check.call("the day answer names what they actually did", "shift" in String(day["line"]) or "workout" in String(day["line"]))
	check.call("the day answer names who they actually saw", "Marta" in String(day["line"]))
	check.call("asking twice is blocked for the day", "your_day" in convo.asked_today())
	var job: Dictionary = convo.say("your_work")
	print("   job:     ", job["line"])
	check.call("the job answer names their job", defs[0].occupation.replace("_", " ") in String(job["line"]))
	check.call("goodbye closes the box", bool(convo.say("bye")["closes"]))

	# --- the same day told by every outlook group
	print("[one day, six voices]")
	for group in NPCOutlook.GROUPS:
		print("   %-12s %s" % [group, NPCOutlook.phrase(group, "day_prefix", [], null)])

	# --- topics move the relationship
	print("[effects]")
	rm.reset_for_tests()
	var before: float = rm.get_relationship("player", defs[0].id)["friendship"]
	var convo2 = ConvoScript.new(brain)
	convo2.say("compliment")
	var after: float = rm.get_relationship("player", defs[0].id)["friendship"]
	check.call("a compliment raises friendship", after > before, "%.1f -> %.1f" % [before, after])
	rm.modify_romance("player", defs[0].id, 40.0)
	var r_before: float = rm.get_romance("player", defs[0].id)
	convo2.say("ask_out")
	check.call("asking them out raises romance", rm.get_romance("player", defs[0].id) > r_before)

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
