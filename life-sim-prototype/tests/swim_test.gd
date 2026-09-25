extends SceneTree
## Walk the player off the beach into the sea and back, checking the states, the float and the stamina.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 2) -> void:
	for i in n: await physics_frame
func _run() -> void:
	var score := {"pass": 0, "fail": 0}
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))
	var world := Node3D.new(); root.add_child(world)
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	world.add_child(p)
	p.set_process_input(false)
	await _frames(4)

	# dry land in town
	p.global_position = Vector3(0, 12, 0)
	await _frames(4)
	check.call("dry on land", p.water_state == "" and not p.is_swimming, p.water_state)

	# out at sea: the float should catch them rather than letting them sink
	p.global_position = Vector3(0, 6, 600)
	var lowest := 999.0
	for i in 180:
		await physics_frame
		lowest = minf(lowest, p.global_position.y)
	var surface: float = Water.surface_y(p.global_position)
	print("   surface %.2f   settled at %.2f   lowest %.2f   seabed %.2f" % [surface, p.global_position.y, lowest, Water.bed_y(p.global_position)])
	check.call("dropped into the sea, they swim", p.is_swimming)
	check.call("they float near the surface, not on the seabed",
		absf(p.global_position.y - (surface - p.FLOAT_DEPTH)) < 0.5,
		"%.2f vs %.2f" % [p.global_position.y, surface - p.FLOAT_DEPTH])
	check.call("they never sank to the bottom", lowest > Water.bed_y(p.global_position) + 2.0)

	# stamina drains while swimming and comes back on land
	p.stamina = 100.0
	for i in 60: await physics_frame
	var after_swim: float = p.stamina
	check.call("swimming costs stamina", after_swim < 100.0, "%.1f" % after_swim)
	p.global_position = Vector3(0, 12, 0)
	await _frames(4)
	for i in 60: await physics_frame
	check.call("stamina comes back on dry land", p.stamina > after_swim, "%.1f" % p.stamina)
	check.call("out of the water they stop swimming", not p.is_swimming)

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
