extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _frames(n := 3) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38, -145, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.88, 0.89, 0.9)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://body/")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 32
	# no top so the torso is visible; swim/beach is the case the detail is for
	var r := CreatorData.default_recipe()
	r["hair"] = {"cut": ""}
	r["garments"] = []
	var rig := CharacterRig.new(); world.add_child(rig)
	rig.set_toriyama_recipe(r)
	await _frames(10)
	rig.animate(1.0 / 60.0, 0.0, true)
	await _frames(4)
	for body in ["Adult male", "Athletic female", "Adult female", "Broad"]:
		if rig.model.has_method("set_body_type"):
			rig.model.set_body_type(body)
		await _frames(6)
		for v in [["front", Vector3(0, 1.20, -1.55)], ["q34", Vector3(-1.15, 1.22, -1.05)], ["far", Vector3(0, 1.35, -3.4)]]:
			cam.global_position = v[1]; cam.look_at(Vector3(0, 1.15, 0))
			await _frames(3)
			root.get_texture().get_image().save_png(out + "%s_%s.png" % [body.replace(" ", "_"), v[0]])
	print("BODYDETAIL done -> ", out)
	quit()
