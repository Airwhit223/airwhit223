extends SceneTree
## Ancient Primal Form on the real character: normal / Controlled / Dark renders (user://primal_test/), and that ending
## the form restores the hair, eyes and body exactly.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://primal_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.18, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.74)
	env.environment.glow_enabled = true
	env.environment.glow_hdr_threshold = 1.0
	env.environment.glow_intensity = 0.6
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var cam := Camera3D.new(); world.add_child(cam)
	var rig := CharacterRig.new()
	var r := CreatorData.default_recipe()
	r["eye_preset"] = "Anime_Intense_Hero"
	r["garments"] = [{"part": "TR_Baggy_Jeans", "colors": {"bottom": "#4F6A8C"}}]     # bare chest: markings show
	rig.toriyama_recipe = r
	world.add_child(rig)
	await _frames(10)
	for k in 20: rig.animate(1.0 / 60.0, 0.0, true, "normal")
	var ch: ToriyamaCharacter = rig.model
	var hair_before := ch.hair_state
	var eye_before = ch.anime_eye_materials[0].get_shader_parameter("eye_color")
	for state in ["normal", "controlled", "dark"]:
		var pf: PrimalForm = null
		if state != "normal":
			pf = PrimalForm.begin(ch, state == "dark")
			for k in 50:
				rig.animate(1.0 / 60.0, 0.0, true, "normal")
				await process_frame
		for view in [["front", Vector3(0, 0, -1)], ["q34", Vector3(0.75, 0, -0.75)]]:
			var aim := Vector3(0, 1.15, 0)
			cam.global_position = aim + (view[1] as Vector3).normalized() * 2.6
			cam.look_at(aim)
			cam.current = true
			await _frames(4)
			root.get_texture().get_image().save_png("%s%s_%s.png" % [out, state, view[0]])
		# close-ups: head (hair, eyes, face markings), torso front and back (markings)
		for shot in [["head", Vector3(0, 1.62, -0.95), Vector3(0, 1.6, 0)], ["torso", Vector3(0, 1.3, -1.3), Vector3(0, 1.2, 0)],
				["back", Vector3(0, 1.3, 1.3), Vector3(0, 1.2, 0)]]:
			cam.global_position = shot[1]
			cam.look_at(shot[2])
			await _frames(4)
			root.get_texture().get_image().save_png("%s%s_%s.png" % [out, state, shot[0]])
		if pf:
			if state == "dark":
				_expect(float(ch._expr.get("Angry", 0.0)) == 1.0, "dark: face turns angry")
			_expect(String(ch.recipe["hair"]["cut"]) == ("RT_M_Curly_Medium__Bolt" if state == "dark" else "RT_M_Curly_Medium__Loose"), "%s: hair swaps to its primal version" % state)
			pf.end(true)
			await _frames(2)
			_expect(ch.hair_state == hair_before, "%s ends: hair state restored" % state)
			_expect(ch.recipe["hair"]["cut"] == "RT_M_Curly_Medium", "%s ends: the original cut is back" % state)
			_expect(ch.anime_eye_materials[0].get_shader_parameter("eye_color") == eye_before, "%s ends: eye colour restored" % state)
			_expect(float(ch._expr.get("Angry", 0.0)) == 0.0, "%s ends: expression back to calm" % state)
	print("OUT ", out)
	print("PRIMAL_TEST ", ("FAILED: " + str(failures)) if failures else "ALL PASS")
	quit(1 if failures else 0)
