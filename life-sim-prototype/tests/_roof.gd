extends SceneTree
## Energy exertion + flying through a roof. Checks the warning fires BEFORE any damage is recorded.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(45)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var PS := root.get_node_or_null("/root/PowerSystem")
	var BD := root.get_node_or_null("/root/BuildingDamage")
	var player: CharacterBody3D = null
	for n in root.find_children("*", "CharacterBody3D", true, false):
		if n.has_method("_ground_reference_y"):
			player = n; break
	var flight = player.flight
	PS.profile.universal_mastery["flight"] = 3.0

	var warnings: Array = []
	var breaks: Array = []
	flight.roof_warning.connect(func(b, s): if warnings.is_empty() or warnings[-1] != b: warnings.append(b))
	flight.roof_broken.connect(func(b, d): breaks.append("%s:%.0f" % [b, d]))

	# --- energy under exertion: hover and watch it actually fall
	player.input_locked = false
	player.global_position = Vector3(-7.5, 0.5, 0.0)      # the street outside the designed house
	await _frames(5)
	var e0: float = PS.profile.energy
	Input.action_press("jump"); await _frames(2); Input.action_release("jump")
	await _frames(6)
	Input.action_press("jump"); await _frames(2)
	await _frames(180)
	var e1: float = PS.profile.energy
	print("EXERTION energy %.1f -> %.1f over 3s (exerting=%s)" % [e0, e1, PS.profile.exerting])

	# --- fly up under the house roof
	var house := main.find_child("PlayerHouse", true, false)
	if house == null:
		print("NO HOUSE FOUND"); Input.action_release("jump"); quit(); return
	Input.action_release("jump")
	await _frames(4)
	# put the flier inside the house just under its roof, then take off again from there
	player.global_position = house.global_position + Vector3(0, 2.6, 0)
	player.velocity = Vector3.ZERO
	await _frames(8)
	Input.action_press("jump"); await _frames(2); Input.action_release("jump")
	await _frames(4)
	Input.action_press("jump"); await _frames(2)
	await _frames(4)
	print("UNDER ROOF at ", player.global_position.round(), " flying=", flight.active,
		" damaged_before=", BD.damaged_buildings().size())
	var shapes: Array = []
	for c in house.find_children("*", "CollisionShape3D", true, false):
		shapes.append("%s@%.1f" % [c.name, c.global_position.y])
	print("HOUSE ", house.name, " colliders=", shapes.size(), " ", shapes.slice(0, 6))
	var space := player.get_world_3d().direct_space_state
	for h in [1.0, 2.0, 3.0, 4.0, 6.0]:
		var from := player.global_position + Vector3(0, 0.9, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, h, 0))
		q.exclude = [player.get_rid()]
		var r := space.intersect_ray(q)
		print("   probe %.0fm -> " % h, (r["collider"].name if r else "nothing"))
	await _frames(40)       # inside the grace window
	print("STRUCTURES scanned=", flight._structures.size(), " nearest=", (flight._structure_under_climb().get("name", "none")))
	print("DURING GRACE warnings=", warnings, " damage_records=", BD.damaged_buildings().size())
	await _frames(90)       # past it
	Input.action_release("jump")
	await _frames(10)
	print("AFTER GRACE breaks=", breaks)
	for entry in BD.damaged_buildings():
		print("   DAMAGED ", entry["name"], " %.0f%%" % entry["damage"], " repair %.1f h" % entry["hours"])
	# repair it
	if BD.damaged_buildings().size() > 0:
		var id = BD.damaged_buildings()[0]["id"]
		BD.repair(id, 10.0)
		print("AFTER PARTIAL REPAIR %.0f%% left" % BD.damage_of(id))
		BD.repair(id, 100.0)
		print("AFTER FULL REPAIR damaged=", BD.is_damaged(id))
	print("ROOF TEST done")
	quit()
