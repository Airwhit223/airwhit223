extends SceneTree
## The cut as a filmstrip, with the katana actually in hand. Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 4) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out: String = ProjectSettings.globalize_path("user://poses/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 25, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.58, 0.63, 0.70)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.79, 0.82)
	world.add_child(env)
	if root.has_node("RetroPS2"): root.get_node("RetroPS2").apply(&"off")
	var rig := CharacterRig.new()
	rig.toriyama_recipe = CreatorData.default_recipe()
	world.add_child(rig)
	await _frames(20)
	# the blade itself, on the hand socket
	var kit = null
	for c in rig.find_children("*", "ToriyamaKitCharacter", true, false): kit = c
	await _frames(4)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 42
	for pass_ in [["katana", 1], ["dual_katana", 1]]:
		var state: String = pass_[0]
		rig.swing_side = int(pass_[1])
		if kit:
			kit.set_weapon("Classic", "hip", {}, state == "dual_katana")
			kit.set_weapon_drawn(true)
		await _frames(6)
		for i in 6:
			var ph := float(i) / 5.0
			rig.swing = ph
			for j in 14:
				rig.animate(1.0 / 60.0, 0.0, true, state, 0.0)
			cam.global_position = Vector3(2.1, 1.25, -2.3)
			cam.look_at(Vector3(0, 0.95, 0))
			await _frames(3)
			root.get_texture().get_image().save_png("%sstrip_%s_%d.png" % [out, state, i])
	print("OUT ok")
	quit()
