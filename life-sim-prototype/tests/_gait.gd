extends SceneTree
## Walk/idle review: frames across one stride, from the side and 3/4, at gameplay distance.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38, -140, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.85, 0.87, 0.9)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var tag: String = OS.get_environment("GAIT_TAG")
	var out := ProjectSettings.globalize_path("user://gait/")
	DirAccess.make_dir_recursive_absolute(out)
	var rig := CharacterRig.new(); world.add_child(rig)
	var recipe := CreatorData.default_recipe()
	var style: String = OS.get_environment("GAIT_STYLE")
	if style != "":
		recipe["movement"] = style
		if style == "feminine":
			recipe["base"] = "F"
			recipe["definition"] = (CreatorData.DEFINITION_DEFAULTS["F"] as Dictionary).duplicate()
	rig.set_toriyama_recipe(recipe)
	rig.movement_style = style if style != "" else rig.movement_style
	await _frames(12)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 40
	# walk: 8 frames across one stride, side view
	for i in 60:
		rig.animate(1.0 / 60.0, 3.2, true)
		await _frames(1)
	for i in 8:
		for j in 5:
			rig.animate(1.0 / 60.0, 3.2, true)
			await _frames(1)
		cam.global_position = Vector3(-3.0, 1.0, 0.0); cam.look_at(Vector3(0, 0.88, 0))
		await _frames(1)
		root.get_texture().get_image().save_png(out + "%s_walk_%d.png" % [tag, i])
	# idle: 4 frames a second apart
	for i in 4:
		for j in 60:
			rig.animate(1.0 / 60.0, 0.0, true)
			await _frames(1)
		cam.global_position = Vector3(-2.2, 1.05, -1.7); cam.look_at(Vector3(0, 0.90, 0))
		await _frames(1)
		root.get_texture().get_image().save_png(out + "%s_idle_%d.png" % [tag, i])
	print("GAIT done ", tag)
	quit()
