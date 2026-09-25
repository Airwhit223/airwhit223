extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _frames(n := 3) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-25, -100, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.9, 0.9, 0.92)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://head/")
	var r := CreatorData.default_recipe(); r["hair"] = {"cut": ""}
	var rig := CharacterRig.new(); world.add_child(rig)
	rig.set_toriyama_recipe(r)
	await _frames(8)
	rig.animate(1.0 / 60.0, 0.0, true)
	await _frames(4)
	var has := rig.model.find_children("Ear_Ink", "MeshInstance3D", true, false).size() > 0
	print("EARINK mesh present: ", has)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true
	var shots := [["ear", Vector3(-0.62, 1.60, 0.0), Vector3(-0.118, 1.59, 0.0), 20.0],
		["q34", Vector3(-0.60, 1.62, -0.45), Vector3(-0.09, 1.59, 0.0), 22.0],
		["head", Vector3(-0.95, 1.62, -0.35), Vector3(0, 1.58, 0), 30.0]]
	for s in shots:
		cam.fov = s[3]; cam.global_position = s[1]; cam.look_at(s[2])
		await _frames(3)
		root.get_texture().get_image().save_png(out + "ink_%s.png" % s[0])
	print("EARINK done")
	quit()
