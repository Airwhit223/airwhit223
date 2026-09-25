extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _frames(n := 3) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, -150, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.88, 0.89, 0.9)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://head/")
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 24
	var r := CreatorData.default_recipe(); r["hair"] = {"cut": ""}
	var rig := CharacterRig.new(); world.add_child(rig)
	rig.set_toriyama_recipe(r)
	await _frames(8)
	rig.animate(1.0 / 60.0, 0.0, true)
	await _frames(4)
	var cases := [["default", {}], ["big", {"size": 1.0}], ["elf", {"point": 1.0, "size": 0.3}], ["out", {"out": 1.0}]]
	for c in cases:
		rig.model.set_ears({"size": 0.0, "point": 0.0, "out": 0.0})
		rig.model.set_ears(c[1])
		await _frames(2)
		for v in [["front", Vector3(0, 1.62, -1.0)], ["side", Vector3(-1.0, 1.63, 0.02)]]:
			cam.global_position = v[1]; cam.look_at(Vector3(0, 1.61, 0))
			await _frames(3)
			root.get_texture().get_image().save_png(out + "ear_%s_%s.png" % [c[0], v[0]])
	print("EARS done")
	quit()
