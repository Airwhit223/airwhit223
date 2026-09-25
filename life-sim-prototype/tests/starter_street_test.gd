extends SceneTree
## Starter Street: loads the generated scene, checks the spec's structure and placement rules, and saves look-test
## screenshots to user://starter_street/ — the player view (compare with references/.../street_player.jpg), the
## overview (street_overview.jpg), and the same player view at night.

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _frames(n := 10) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _shot(file: String) -> void:
	await _frames(8)
	root.get_texture().get_image().save_png(file)

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://starter_street/")
	DirAccess.make_dir_recursive_absolute(out)
	var street: Node3D = load("res://world/starter_street/starter_street.tscn").instantiate()
	street.get_node("Lighting").follow_time = false
	root.add_child(street)
	# compare against the references without the PS2 filter; one shot with it on is taken at the end
	var retro := root.get_node("RetroPS2")
	retro.apply(&"off")
	await _frames(60)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# structure from the spec
	for path in ["Environment/Ground", "Environment/House", "Environment/Shop", "Environment/ShadeTree",
			"Environment/BlossomTree", "Environment/FenceSections", "Props/StreetLamp", "Props/NoticeBoard",
			"Props/Bench", "Props/BikeRack", "Props/Bicycle", "Props/Mailbox", "Props/FireHydrant", "Props/TrashCan",
			"Props/GardenPlot", "NPCSpawns/ShopWorkSpot", "NPCSpawns/BenchSitSpot", "NPCSpawns/PorchSitSpot",
			"NPCSpawns/RoadWalkPath", "Lighting/Sun", "GrassTufts", "InkPass"]:
		_expect(street.has_node(path), "has %s" % path)
	var fence_count := street.get_node("Environment/FenceSections").get_child_count()
	_expect(fence_count >= 10, "fence encloses the yard (%d pieces)" % fence_count)
	_expect(street.get_node("Props/GardenPlot/FarmPlot").get_script().resource_path == "res://farming/farm_plot.gd", "garden reuses the farming plot")
	_expect(street.get_node("Props/Bench/BenchInteract").get_script().resource_path == "res://interactables/bench.gd", "bench is an interactable sit spot")
	var world := root.get_node("WorldState")
	_expect(world.has_location("street_shop_work_spot") and world.has_location("street_bench_sit_spot"),
		"street spots registered with WorldState")

	# placement rule 5: 2 m clear at the shop door and the bench (props other than the bench itself)
	var door: Vector3 = street.get_node("NPCSpawns/ShopDoor").global_position
	var bench: Vector3 = street.get_node("Props/Bench").global_position
	for prop in street.get_node("Props").get_children():
		var p: Vector3 = prop.global_position
		if prop.name.begins_with("ShopFlowers") or prop.name == "Flowers":
			continue          # flower pots hug the wall beside the door, as the spec asks
		if prop.name != "Bench":
			_expect(Vector2(p.x - bench.x, p.z - bench.z).length() >= 1.95 or prop.name == "Flowers",
				"%s keeps clear of the bench" % prop.name)
		_expect(Vector2(p.x - door.x, p.z - door.z).length() >= 1.95, "%s keeps clear of the shop door" % prop.name)

	# lighting presets
	var lighting = street.get_node("Lighting")
	var lamp: Light3D = street.get_node("Props/StreetLamp/StreetLampLight")
	lighting.set_preset(StreetLighting.Preset.GOLDEN_HOUR)
	await _frames(2)
	var sun: DirectionalLight3D = street.get_node("Lighting/Sun")
	_expect(not lamp.visible and sun.light_energy >= 1.0, "golden hour: full sun, lamp off")

	# player view, framed like street_player.jpg
	var player: Node3D = street.get_node("Player")
	player.set_physics_process(false)
	var cam := Camera3D.new()
	street.add_child(cam)
	cam.fov = 58.0
	cam.current = true
	# walking east along the road: the house porch on the left, the shop ahead on the right
	player.global_position = Vector3(-15.0, 0.05, -0.4)
	var body: Node3D = player.get_node("Body")
	body.global_rotation.y = -PI * 0.5 + 0.15
	cam.fov = 55.0
	cam.global_position = Vector3(-17.8, 2.0, -0.1)
	cam.look_at(Vector3(-8.0, 1.0, -0.4))
	await _shot(out + "player_view_golden.png")
	lighting.set_preset(StreetLighting.Preset.NIGHT)
	await _frames(2)
	_expect(lamp.visible and sun.light_energy < 0.5, "night: lamp on, sun dimmed to moonlight")
	await _shot(out + "player_view_night.png")
	lighting.set_preset(StreetLighting.Preset.GOLDEN_HOUR)

	# overview, framed like street_overview.jpg (high, looking down across the yard to the shop)
	cam.fov = 50.0
	cam.global_position = Vector3(-14.0, 11.0, 10.0)
	cam.look_at(Vector3(-4.0, 0.0, -2.5))
	await _shot(out + "overview_golden.png")
	# down the dirt path toward the shop, the other direction
	cam.global_position = Vector3(2.5, 1.9, 12.0)
	cam.look_at(Vector3(-1.0, 1.0, -2.0))
	await _shot(out + "south_path.png")
	# shop front close-up
	cam.global_position = Vector3(6.2, 2.0, -2.8)
	cam.look_at(Vector3(7.5, 2.8, 6.0))
	await _shot(out + "shop_front.png")
	# house and yard close-up
	cam.global_position = Vector3(-4.0, 2.2, 1.5)
	cam.look_at(Vector3(-8.5, 1.5, -7.0))
	await _shot(out + "house_yard.png")

	# the same player view with the game's default soft PS2 filter
	cam.fov = 55.0
	cam.global_position = Vector3(-18.0, 2.05, 0.2)
	cam.look_at(Vector3(-8.0, 1.0, -0.6))
	retro.apply(&"soft")
	await _shot(out + "player_view_golden_retro.png")
	retro.apply(&"off")
	print("screenshots: %s" % out)
	if failures.is_empty():
		print("STARTER_STREET_TEST PASS")
	else:
		print("STARTER_STREET_TEST FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)
