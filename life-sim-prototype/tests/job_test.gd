extends SceneTree
## Job framework (milestones 1-3): start a shift at a workplace, record orders/mistakes, finish, get graded pay,
## reputation, skill XP, energy drain; hours gating; mastery hooks; promotion offer.
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
	var jm = root.get_node("JobManager"); var eco = root.get_node("Economy"); var tm = root.get_node("TimeManager")
	var player = root.get_tree().get_first_node_in_group("player")
	tm.hour = 3
	_expect(jm.can_start("restaurant_cook") != "", "closed at 3am")
	tm.hour = 12
	_expect(jm.can_start("restaurant_cook") == "", "open at noon")
	var money0: int = eco.money
	var energy0: float = player.energy
	_expect(jm.start_shift("restaurant_cook", 2), "shift starts")
	_expect(not jm.start_shift("ranch_hand", 2), "can't start a second shift")
	for i in 4: jm.record("order", {"ok": true, "satisfaction": 0.95})
	jm.record("mistake", {"what": "burnt patty"})
	var s: Dictionary = jm.finish_shift()
	_expect(s["orders"] == 4 and s["mistakes"] == 1, "summary counts orders and mistakes (%s)" % str(s))
	_expect(s["grade"] in ["Good", "Great", "Excellent"], "strong shift grades well (%s)" % s["grade"])
	_expect(s["base_pay"] == 28 and s["tips"] > 0 and eco.money == money0 + s["total"], "paid base + tips into the wallet ($%d)" % s["total"])
	_expect(player.energy < energy0, "work drains energy (%.1f -> %.1f)" % [energy0, player.energy])
	_expect(jm.skill("cooking") > 0.0, "cooking skill improves (%.2f)" % jm.skill("cooking"))
	_expect(jm.reputation("restaurant_cook") > 0.0, "reputation grows")
	_expect(jm.employer_remark("restaurant_cook") != "", "employer remembers the shift: %s" % jm.employer_remark("restaurant_cook"))
	jm.start_shift("skate_builder", 2)
	jm.record("order", {"ok": false, "satisfaction": 0.1})
	jm.record("mistake"); jm.record("mistake")
	var bad: Dictionary = jm.finish_shift()
	_expect(bad["grade"] == "Poor" and bad["tips"] == 0, "bad shift: poor, no tips")
	jm.skills["cooking"] = 100.0
	_expect(is_zero_approx(jm.stamina_cost(10.0, "cooking")) and jm.timing_window(1.0, "cooking") == 2.0, "mastery: free stamina, double timing window")
	jm.jobs["restaurant_cook"]["reputation"] = 29.0
	player.energy = 100.0
	jm.start_shift("restaurant_cook", 2)
	for i in 5: jm.record("order", {"ok": true, "satisfaction": 1.0})
	jm.finish_shift()
	_expect(jm.jobs["restaurant_cook"]["memory"].get("promotion_offered", 0) == 2, "promotion offered at the reputation threshold")
	_expect(jm.accept_promotion("restaurant_cook") and jm.job_level("restaurant_cook") == 2 and jm.unlocked("restaurant_cook", "soup"), "accepting unlocks level-2 recipes")
	print("JOB_TEST ", ("FAILED: " + str(failures)) if failures else "ALL PASS")
	quit(1 if failures else 0)
