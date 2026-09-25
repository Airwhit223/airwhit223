extends SceneTree
## The sword swing: does the rig's phase actually track the attack, and does the stance switch?
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var score := {"pass": 0, "fail": 0}
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))
	var world := Node3D.new(); root.add_child(world)
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	world.add_child(p)
	for i in 8: await physics_frame

	check.call("no blade drawn, no stance", p._sword_stance() == "")
	p.select_hand_tool("test_sword", false)
	for i in 4: await physics_frame
	check.call("one sword gives the katana stance", p._sword_stance() == "katana", p._sword_stance())
	check.call("at rest the swing phase sits at guard", absf(p.body.swing) < 0.001, "%.2f" % p.body.swing)

	var ok: bool = p.perform_basic_attack()
	check.call("the attack starts", ok)
	# 0.55 s at 60 Hz is about 33 frames, so sample INSIDE the cut - past that it has already returned to guard
	var seen: Array[float] = []
	for i in 28:
		await physics_frame
		seen.append(p.body.swing)
	var rose := seen[3] < seen[14] and seen[14] < seen[-1]
	print("   swing phase: %.2f -> %.2f -> %.2f" % [seen[3], seen[14], seen[-1]])
	check.call("the phase advances across the cut", rose)
	check.call("the phase stays inside 0..1", seen.min() >= 0.0 and seen.max() <= 1.0)
	for i in 50: await physics_frame
	check.call("it returns to guard when the cut ends", absf(p.body.swing) < 0.001, "%.2f" % p.body.swing)

	p.equipment.equip(EquipmentCatalog.get_item("test_sword_off"))
	for i in 4: await physics_frame
	check.call("a matched pair gives the dual stance", p._sword_stance() == "dual_katana", p._sword_stance())
	check.call("the main hand kept its blade", p.equipment.get_equipped("hand_r") != null
		and p.equipment.get_equipped("hand_r").id == "test_sword")
	# an unmatched tool must still evict, or the hands become a free-for-all
	p.equipment.equip(EquipmentCatalog.get_item("acoustic_guitar"))
	for i in 4: await physics_frame
	check.call("an unmatched tool still empties the other hand", p._sword_stance() == "", p._sword_stance())

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
