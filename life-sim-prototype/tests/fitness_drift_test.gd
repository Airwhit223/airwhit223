extends SceneTree
## Fitness & body-type drift checks (PlayerStats). Run: godot --headless --path . --script res://tests/fitness_drift_test.gd

var failures: Array[String] = []

func _expect(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stats = root.get_node("PlayerStats")
	var tm = root.get_node("TimeManager")
	tm.set_speed(tm.Speed.PAUSED)

	stats.set_starting_archetype("Average")
	_expect(is_equal_approx(stats.mass, 0.5) and is_equal_approx(stats.muscle, 0.5), "Average start sits at the neutral midpoint")

	# One typical active week: gym 4x, some farming and walking
	for i in 4: stats.log_activity("workout")
	for i in 6: stats.log_activity("labor")
	stats.log_activity("walk", 4.0)
	var s1: Dictionary = stats.evaluate_week(1)
	_expect(s1.d_muscle > 0.0 and s1.d_mass < 0.0, "Active week: muscle up, mass down")
	_expect(absf(s1.d_muscle) <= 0.10 and absf(s1.d_mass) <= 0.10, "Weekly change stays gradual (at most 10 percent of the range)")
	_expect(s1.d_muscle >= 0.05, "Typical engagement moves muscle roughly 5-10 percent per week (got %.3f)" % s1.d_muscle)

	# Many workout weeks can't exceed the caps
	for wk in 30:
		for i in 12: stats.log_activity("workout")
		stats.evaluate_week(2 + wk)
	_expect(stats.muscle <= 1.0 and stats.mass >= 0.0, "Mass and muscle stay clamped to 0..1")
	_expect(stats.get_body_descriptor() == "Athletic", "Sustained training reads as Athletic (got %s)" % stats.get_body_descriptor())

	# Sedentary week: mass up, muscle down
	stats.set_starting_archetype("Average")
	stats.idle_weeks = 0
	stats.log_activity("walk", 2.0)
	var s2: Dictionary = stats.evaluate_week(40)
	_expect(s2.rule == "sedentary" and s2.d_mass > 0.0 and s2.d_muscle < 0.0, "Low-activity week: mass up, muscle down")

	# Long inactivity decays toward neutral instead of running to an extreme
	stats.mass = 0.95
	stats.muscle = 0.1
	stats.idle_weeks = 0
	var before := absf(stats.mass - 0.5) + absf(stats.muscle - 0.5)
	for wk in 8:
		stats.evaluate_week(41 + wk)
	var after := absf(stats.mass - 0.5) + absf(stats.muscle - 0.5)
	_expect(after < before * 0.6, "Several idle weeks pull both axes back toward neutral (%.2f -> %.2f)" % [before, after])

	# Book smarts: separate stat, same tick, never touches the body
	stats.set_starting_archetype("Average")
	var m0: float = stats.mass
	var u0: float = stats.muscle
	stats.idle_weeks = 0
	var smarts0: float = stats.book_smarts
	for i in 2: stats.log_activity("study")
	for i in 8: stats.log_activity("workout")        # keep the body rule neutral-ish so we only test smarts
	var s3: Dictionary = stats.evaluate_week(60)
	_expect(stats.book_smarts > smarts0, "Studying raises Book Smarts")
	stats.idle_weeks = 0
	for i in 8: stats.log_activity("workout")
	stats.evaluate_week(61)
	_expect(stats.book_smarts < s3.book_smarts, "Book Smarts decays slightly in weeks without study")

	# Events feed the log; gym equipment routes through PlayerStats
	stats._reset_log()
	root.get_node("EventBus").fire("crop_harvested", {"plot_id": "t", "crop_id": "turnip", "amount": 1})
	root.get_node("EventBus").fire("player_attack_landed", {"weapon_id": "sword"})
	_expect(stats.week_log.labor > 0.0 and stats.week_log.combat > 0.0, "Farming and combat events are logged")
	var gym = load("res://interactables/gym_equipment.gd").new()
	gym._last_used_msec = -999999
	gym.interact(Node3D.new())
	_expect(stats.week_log.workout > 0.0, "Gym equipment logs a workout instead of the old +5 stub")
	gym.free()

	# Week boundaries crossed by a sleep jump still get evaluated
	var n_before: int = stats.history.size()
	stats.last_week_index = tm.get_week_index()
	tm._jump_by_minutes(tm.MINUTES_PER_DAY * 8)
	_expect(stats.history.size() > n_before, "Weeks crossed by a time jump (sleep) are evaluated")

	# Accessors for future path/power systems
	_expect(stats.get_fitness_level() >= 0.0 and stats.get_fitness_level() <= 100.0, "get_fitness_level() is a 0..100 read hook")
	var saved: Dictionary = stats.to_dict()
	stats.mass = 0.0
	stats.from_dict(saved)
	_expect(is_equal_approx(stats.mass, saved.mass), "Stats round-trip through to_dict/from_dict")

	print("Result: ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
