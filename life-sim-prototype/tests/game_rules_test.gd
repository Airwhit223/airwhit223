extends SceneTree
## Milestone 1: Adventure and Sandbox are the same world under different rules.
func _initialize() -> void:
	var gr = root.get_node("GameRules")
	var score := {"pass": 0, "fail": 0}
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))

	gr.reset_for_tests()
	check.call("a fresh run has not started yet", not gr.started)

	gr.start_new_game(gr.Mode.ADVENTURE)
	check.call("adventure runs the main story", gr.allows("main_story_enabled"))
	check.call("adventure plays cutscenes", gr.allows("story_cutscenes_enabled"))
	check.call("adventure is named", gr.mode_name() == "Adventure")

	gr.start_new_game(gr.Mode.SANDBOX)
	check.call("sandbox does not advance the main story", not gr.allows("main_story_enabled"))
	check.call("sandbox keeps NPC personal quests", gr.allows("npc_personal_quests_enabled"))
	check.call("sandbox keeps random world events", gr.allows("random_world_events_enabled"))
	check.call("sandbox is not adventure mode", not gr.is_adventure_mode())

	# the point of flags over a mode check: a sandbox save can be given the story later
	gr.set_flag("main_story_enabled", true)
	check.call("the story can be switched on inside a sandbox save", gr.allows("main_story_enabled"))
	check.call("...without turning it into adventure mode", not gr.is_adventure_mode())

	gr.start_new_game(gr.Mode.SANDBOX, {"starting_money": 1000, "combat_difficulty": 0.5})
	check.call("overrides apply at start", int(gr.value("starting_money")) == 1000
		and abs(float(gr.value("combat_difficulty")) - 0.5) < 0.001)
	check.call("an unknown flag is refused, not silently stored", not gr.flags.has("nonsense"))

	var saved: Dictionary = gr.to_save()
	gr.reset_for_tests()
	gr.from_save(saved)
	check.call("rules survive a save/load round trip",
		gr.mode == gr.Mode.SANDBOX and int(gr.value("starting_money")) == 1000)

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
