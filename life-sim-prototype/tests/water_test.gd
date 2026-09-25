extends SceneTree
## The water query layer: where the sea is, how deep, and what that means for a body standing in it.
func _initialize() -> void:
	var score := {"pass": 0, "fail": 0}
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))

	var inland := Vector3(0, 0, 0)
	var sea := Vector3(0, 0, 600)
	check.call("town is not water", not Water.is_water(inland))
	check.call("open sea is water", Water.is_water(sea))
	check.call("the sea has a surface", Water.surface_y(sea) != -INF, str(Water.surface_y(sea)))
	check.call("the sea has depth", Water.depth_at(sea) > Water.SWIM_DEPTH, "%.2f m" % Water.depth_at(sea))
	check.call("dry land reports no state", Water.state_at(inland) == "")
	check.call("deep water means swim", Water.state_at(Vector3(0, -0.5, 600)) == "swim", Water.state_at(Vector3(0, -0.5, 600)))

	# walk out from the beach and the state should escalate, never jump straight to swimming
	var seen: Array[String] = []
	for z in range(270, 340, 4):
		var st := Water.state_at(Vector3(0, -0.5, float(z)))
		if seen.is_empty() or seen[-1] != st:
			seen.append(st)
	print("   wading out from the beach: ", seen)
	check.call("the shore ramps dry -> shallow -> wade -> swim", seen.size() >= 3 and seen[-1] == "swim")
	check.call("a swimmer above the surface is dry", Water.state_at(Vector3(0, 6.0, 600)) == "")

	# a registered pond
	Water.register_volume("test_pond", AABB(Vector3(-2, -1, -2), Vector3(4, 2, 4)), 0.5)
	check.call("a registered pond is water", Water.is_water(Vector3(0, 0.2, 0)))
	Water.unregister_volume("test_pond")
	check.call("unregistering removes it", not Water.is_water(Vector3(0, 0.2, 0)))

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
