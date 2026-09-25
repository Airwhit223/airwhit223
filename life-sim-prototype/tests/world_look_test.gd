extends SceneTree
## The town (main.tscn) in the Starter Street look: checks the ink pass, lighting presets and toon conversion, and
## saves town shots to user://world_look/.

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

func _run() -> void:
	ToriyamaRoster.save_recipe(CreatorData.default_recipe())      # skip the new-game intro
	var out := ProjectSettings.globalize_path("user://world_look/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("RetroPS2").apply(&"off")
	await _frames(120)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_expect(main.has_node("InkPass") and main.has_node("StreetLighting"), "town has the ink pass and lighting")
	var ground: MeshInstance3D = main.get_node("NavRegion/Ground/MeshInstance3D")
	var mat := ground.material_override if ground.material_override else ground.get_active_material(0)
	_expect(mat is ShaderMaterial, "graybox ground uses the toon material")
	_expect(main.has_node("NavRegion/PlayerHomeKit") and main.has_node("NavRegion/StoreKit"),
		"player home and store use the kit buildings")
	var player: Node3D = root.get_tree().get_first_node_in_group("player")
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 55.0
	cam.current = true
	var p := player.global_position
	for shot in [["town_player.png", Vector3(1.5, 2.0, 5.0), Vector3(-0.5, 1.6, -6)],
			["town_high.png", Vector3(-14, 16, 18), Vector3(0, 0, -4)]]:
		cam.global_position = p + shot[1]
		cam.look_at(p + shot[2])
		await _frames(8)
		root.get_texture().get_image().save_png(out + shot[0])
	var store: Vector3 = main.get_node("NavRegion/StoreKit").global_position
	cam.global_position = store + Vector3(2.5, 2.0, -9.0)
	cam.look_at(store + Vector3(0, 2.0, 0))
	await _frames(8)
	root.get_texture().get_image().save_png(out + "town_store.png")
	main.get_node("StreetLighting").set_preset(StreetLighting.Preset.NIGHT)
	await _frames(8)
	root.get_texture().get_image().save_png(out + "town_night.png")
	print("screenshots: %s" % out)
	print("WORLD_LOOK_TEST %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
