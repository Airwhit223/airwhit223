extends SceneTree
## Milestone 2: three bars that mean three different things.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var score := {"pass": 0, "fail": 0}
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))
	var VitalsScript: GDScript = load("res://player/vitals.gd")
	var v = VitalsScript.new()
	root.add_child(v)
	await process_frame

	print("[the three bars]")
	check.call("all three start full", v.health == 100.0 and v.energy == 100.0 and v.stamina == 100.0)

	# stamina: spent, then recovers on its own
	v.spend_stamina("sprint", 1.0)
	var after_sprint: float = v.stamina
	check.call("sprinting spends stamina", after_sprint < 100.0, "%.1f" % after_sprint)
	v._regen_block = 0.0
	v.tick(1.0)
	check.call("stamina comes back by itself", v.stamina > after_sprint, "%.1f" % v.stamina)

	# ...but not instantly after spending
	v.spend_stamina("sprint", 1.0)
	var blocked: float = v.stamina
	v.tick(0.2)
	check.call("recovery pauses right after spending", is_equal_approx(v.stamina, blocked))

	print("[energy is not stamina]")
	v.energy = 100.0
	v.tick(10.0)
	check.call("energy does NOT regenerate on its own", v.energy == 100.0, "%.1f" % v.energy)
	v.spend_energy(30.0)
	v.restore_energy(10.0, "eat")
	check.call("energy comes back only when restored", is_equal_approx(v.energy, 80.0), "%.1f" % v.energy)

	print("[tired costs more and recovers slower]")
	v.energy = 100.0
	var rested_cost: float = v.cost_of("sprint", 1.0)
	v.energy = 0.0
	var tired_cost: float = v.cost_of("sprint", 1.0)
	print("   sprint costs %.2f rested, %.2f exhausted" % [rested_cost, tired_cost])
	check.call("low energy makes stamina cost more", tired_cost > rested_cost)
	v.stamina = 50.0; v._regen_block = 0.0; v.tick(1.0)
	var tired_regen: float = v.stamina - 50.0
	v.energy = 100.0
	v.stamina = 50.0; v._regen_block = 0.0; v.tick(1.0)
	var rested_regen: float = v.stamina - 50.0
	print("   regen %.2f/s exhausted vs %.2f/s rested" % [tired_regen, rested_regen])
	check.call("low energy makes stamina recover slower", tired_regen < rested_regen)

	print("[mastery pays for itself]")
	var ps = root.get_node_or_null("PowerSystem")
	if ps and ps.profile:
		ps.profile.set_universal_mastery("speed", 1.0)
		var novice: float = v.cost_of("sprint", 1.0)
		ps.profile.set_universal_mastery("speed", 10.0)
		var master: float = v.cost_of("sprint", 1.0)
		print("   sprint costs %.2f at mastery 1, %.2f at mastery 10" % [novice, master])
		check.call("mastery cuts the cost", master < novice)
		check.call("at full mastery an ordinary action is free", is_zero_approx(master))
		ps.profile.set_universal_mastery("speed", 1.0)
	else:
		print("   (no PowerSystem profile - mastery discount not exercised)")

	print("[one-shot actions are all or nothing]")
	v.stamina = 100.0
	check.call("a dodge lands when there is stamina", v.spend_stamina("dodge", 1.0, false))
	v.stamina = 1.0
	var before: float = v.stamina
	check.call("a dodge is refused when there is not", not v.spend_stamina("dodge", 1.0, false))
	check.call("...and nothing is spent on the refusal", is_equal_approx(v.stamina, before))

	print("[sleep pays the day back]")
	v.energy = 20.0; v.health = 70.0
	v.sleep_restore(8.0)
	check.call("a full night restores energy", v.energy > 90.0, "%.1f" % v.energy)
	check.call("...and heals a little", v.health > 70.0, "%.1f" % v.health)
	v.energy = 20.0
	v.sleep_restore(2.0)
	check.call("a short night gives less", v.energy < 60.0, "%.1f" % v.energy)

	print("[health]")
	v.health = 100.0
	var died := {"n": 0}
	v.collapsed.connect(func(): died["n"] += 1)
	v.damage(60.0)
	check.call("damage reduces health", is_equal_approx(v.health, 40.0), "%.1f" % v.health)
	v.damage(60.0)
	check.call("health floors at zero", v.health == 0.0)
	check.call("collapsing fires once", died["n"] == 1, str(died["n"]))

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
