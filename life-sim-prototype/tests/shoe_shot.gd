extends SceneTree
## One shoe at a time, so a slow rebuild cannot stall the whole run: `-- <shoe>`.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 4) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _shot(cam: Camera3D, path: String, from: Vector3, aim: Vector3) -> void:
	cam.global_position = from; cam.look_at(aim); cam.current = true
	await _frames(3)
	root.get_texture().get_image().save_png(path)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shoe := args[0] if args.size() > 0 else "TR_Chunky_Lo"
	var out := ProjectSettings.globalize_path("user://gear/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	world.add_child(env)
	if root.has_node("RetroPS2"): root.get_node("RetroPS2").apply(&"off")
	var cam := Camera3D.new(); world.add_child(cam)
	var rig := CharacterRig.new()
	var r := CreatorData.default_recipe()
	r["garments"] = [{"part": "Shirt_Casual_01", "colors": {"top": "#EFE9DC"}},
		{"part": "TR_Cargo_Shorts", "colors": {"bottom": "#5A5438"}},
		{"part": shoe, "colors": {"shoe": "#1B1A1F", "sole": "#EFE9DC", "midsole": "#EFE9DC",
			"shoe_accent": "#B81E2A", "lace": "#EFE9DC", "metal": "#C9CED8"}}]
	r["hair"]["cut"] = ""
	rig.toriyama_recipe = r
	world.add_child(rig)
	await _frames(10)
	for k in 20: rig.animate(1.0 / 60.0, 0.0, true, "normal")
	await _shot(cam, "%s%s_feet.png" % [out, shoe], Vector3(0.5, 0.28, -0.7), Vector3(0, 0.11, 0))
	await _shot(cam, "%s%s_side.png" % [out, shoe], Vector3(0.85, 0.26, 0), Vector3(0, 0.11, 0))
	for k in 2:
		for s in 13: rig.animate(1.0 / 60.0, 3.5, true, "normal")
		await _shot(cam, "%s%s_walk%d.png" % [out, shoe, k], Vector3(0.9, 0.30, 0.15), Vector3(0, 0.15, 0))
	print("OUT ", shoe)
	quit()
