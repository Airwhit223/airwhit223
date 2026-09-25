extends SceneTree
## Run with --script res://tests/regional_landscape_test.gd. Optional -- --screenshots=/absolute/path.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1

func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 12:
		await physics_frame
	var world := main.get_node("RollingTidesWorld")
	var land := world.get_node("RegionalLandscape")
	_expect(land.has_node("SculptedMainland") and land.has_node("OpenOcean"), "main scene installs land and ocean")
	_expect(not world.get_node("Terrain/GroundSurfaces/OverworldGrassCanvas").visible, "old grass canvas hidden")
	var space := main.get_world_3d().direct_space_state
	for location in [Vector3(-400, 150, -400), Vector3(500, 150, 0), Vector3(180, 150, 360)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(location, location - Vector3(0, 200, 0), 1))
		_expect(not hit.is_empty(), "terrain collision at " + str(location))
		if not hit.is_empty() and location.z == 360:
			_expect(hit.position.y < -1.0, "ocean has submerged seabed rather than invisible grass floor")
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			out = arg.trim_prefix("--screenshots=")
	if out != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(out)
		root.get_node("TimeManager").set_process(false)
		for node in root.find_children("*", "CanvasLayer", true, false):
			node.hide()
		var camera := Camera3D.new()
		main.add_child(camera)
		camera.current = true
		camera.far = 12000
		camera.fov = 65
		var views := {
			"coastal-bay": [Vector3(70, 55, 195), Vector3(220, 5, 350)],
			"landscape-overview": [Vector3(-450, 440, 650), Vector3(0, 0, -80)],
			"northern-hills": [Vector3(-280, 55, -255), Vector3(-180, 35, -470)],
			"shore-level": [Vector3(174, 4, 249), Vector3(175, 1, 650)],
		}
		for key in views:
			camera.position = views[key][0]
			camera.look_at(views[key][1])
			for i in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join(key + ".png"))
	print("LANDSCAPE TEST: ", failures, " failures")
	quit(0 if failures == 0 else 1)
