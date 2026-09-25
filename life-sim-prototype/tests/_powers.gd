extends SceneTree
## Tier I flight + vehicles. Drives real input actions rather than poking values, so it exercises the same path
## the player does.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _press(action: String, down: bool) -> void:
	if down: Input.action_press(action)
	else: Input.action_release(action)
func _run() -> void:
	var PS: Node = null
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(45)
	PS = root.get_node_or_null("/root/PowerSystem")
	if PS == null:
		print("NO POWERSYSTEM AUTOLOAD"); quit(); return
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var player: CharacterBody3D = null
	for n in root.find_children("*", "CharacterBody3D", true, false):
		if n.has_method("_ground_reference_y"):
			player = n; break
	if player == null:
		print("NO PLAYER"); quit(); return
	print("SPAWN player at (%.1f, %.1f, %.1f)" % [player.global_position.x, player.global_position.y, player.global_position.z])
	var wsp = root.get_node_or_null("/root/WorldState")
	if wsp and wsp.has_location("home_player"):
		var hp = wsp.get_location_position("home_player")
		print("HOME_PLAYER marker at (%.1f, %.1f, %.1f)" % [hp.x, hp.y, hp.z])
	var flight = player.flight
	print("FLIGHT unlocked at start=", flight.unlocked(), " mastery=", flight.mastery())

	# grant the awakening the debug Power Lab would grant (bible §21)
	PS.profile.universal_mastery["flight"] = 2.0
	print("AWAKENED mastery=", flight.mastery(), " top_speed=%.1f ceiling=%.1f drain=%.1f" % [flight.top_speed(), flight.ceiling(), flight.drain_rate()])

	var start_y := player.global_position.y
	var start_energy: float = PS.profile.energy
	# jump, then a second jump in the air to take off, then hold jump to climb
	_press("jump", true); await _frames(2); _press("jump", false)
	await _frames(6)
	_press("jump", true); await _frames(2); _press("jump", false)
	await _frames(2)
	_press("jump", true)
	await _frames(420)
	var peak := player.global_position.y
	_press("jump", false)
	print("FLYING active=", flight.active, " climbed=%.1f m" % (peak - start_y),
		" energy %.0f -> %.0f" % [start_energy, PS.profile.energy],
		" mastery now %.2f" % flight.mastery())
	var out := ProjectSettings.globalize_path("user://powers/")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new(); (main as Node3D).add_child(cam); cam.current = true; cam.fov = 60
	cam.global_position = player.global_position + Vector3(9, 4, 9)
	cam.look_at(player.global_position)
	await _frames(3)
	root.get_texture().get_image().save_png(out + "flight.png")

	# descend and land: releasing jump is the descent
	await _frames(240)
	print("LANDED active=", flight.active, " y=%.1f" % player.global_position.y)

	# vehicles
	var vehicles := root.get_tree().get_nodes_in_group("vehicle")
	print("VEHICLES in world=", vehicles.size(), " names=", vehicles.map(func(v): return v.vehicle_name))
	if vehicles.size() > 0:
		var v = vehicles[0]
		v.interact(player)
		await _frames(10)
		print("MOUNTED ", v.vehicle_name, " occupied=", v.is_occupied)
		cam.global_position = v.global_position + Vector3(7, 3.5, 7)
		cam.look_at(v.global_position)
		await _frames(3)
		root.get_texture().get_image().save_png(out + "vehicle.png")
		v.dismount()
		await _frames(6)
		print("DISMOUNTED occupied=", v.is_occupied)
	print("POWERS done -> ", out)
	quit()
