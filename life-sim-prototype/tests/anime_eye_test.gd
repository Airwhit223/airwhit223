extends SceneTree
## Drawn anime eye: Anime_* eye presets swap the modelled eyes for the drawn cards, expressions / blink pick a
## drawn frame, set_look slides the iris. Saves face close-ups to user://anime_eye_test/.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _mesh(ch: Node, n: String) -> MeshInstance3D:
	return ch.find_child(n, true, false) as MeshInstance3D

func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-42, 35, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.27, 0.29, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.62, 0.66)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://anime_eye_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new(); world.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.32

	var cases := [
		["F", "Heroine", "#6A3C8C", "", Vector2.ZERO], ["F", "Curious_Doe", "#7A4424", "", Vector2.ZERO],
		["F", "Sleek_Cat", "#3E7A44", "", Vector2.ZERO], ["F", "Heroine", "#6A3C8C", "Happy", Vector2.ZERO],
		["F", "Heroine", "#6A3C8C", "Surprised", Vector2.ZERO], ["F", "Heroine", "#6A3C8C", "", Vector2(0.9, 0)],
		["M", "Intense_Hero", "#5A3A24", "", Vector2.ZERO], ["M", "Brawler", "#4A2E1C", "Angry", Vector2.ZERO],
		["M", "Toriyama", "#2A2020", "", Vector2.ZERO], ["M", "Focused_Almond", "#2E5A9A", "Sad", Vector2.ZERO],
	]
	var i := 0
	for c in cases:
		var ch := ToriyamaKitCharacter.new()
		world.add_child(ch)
		ch.apply_recipe({"base": c[0], "eye": c[2], "hair": {"cut": ""}, "eye_preset": "Anime_" + c[1], "garments": []})
		var ae := _mesh(ch, "AE_Eye_L")
		_expect(ae != null and ae.visible, "%s: drawn eye shown" % c[1])
		_expect(_mesh(ch, "Eye_L") != null and not _mesh(ch, "Eye_L").visible, "%s: modelled eye hidden" % c[1])
		_expect(ch.anime_eye_materials.size() == 4, "%s: eye + brow materials" % c[1])
		_expect(_mesh(ch, "AE_Brow_L").visible and not _mesh(ch, "Brow_L").visible, "%s: drawn brow replaces the modelled brow" % c[1])
		_expect(_mesh(ch, "AE_Mouth").visible and not _mesh(ch, "Mouth").visible and ch.anime_mouth_materials.size() == 1, "%s: drawn mouth replaces the modelled mouth" % c[1])
		if c[3] != "":
			ch.set_expression(c[3])
		ch.set_look(c[4])
		ch.set_process(false)                      # no random blink during the shot
		ch._step_anime_eye_fade(1.0)               # finish the expression cross-fade before the shot
		var m: ShaderMaterial = ch.anime_eye_materials[0]
		var want := ToriyamaCharacter.ANIME_EYE_FRAMES.find(ch._anime_eye_frame(0.0))
		var want_m := ToriyamaCharacter.ANIME_MOUTH_FRAMES.find(ch._anime_mouth_frame())
		_expect(int(ch.anime_mouth_materials[0].get_shader_parameter("frame_index")) == want_m, "%s %s: mouth %s" % [c[1], c[3], ToriyamaCharacter.ANIME_MOUTH_FRAMES[want_m]])
		_expect(int(m.get_shader_parameter("frame_index")) == want, "%s %s: frame %s" % [c[1], c[3], ToriyamaCharacter.ANIME_EYE_FRAMES[want]])
		await _frames(20)
		var head := ch.head_anchor()
		cam.global_position = ch.global_position + Vector3(0, head.y + 0.07, -2.0)
		cam.look_at(cam.global_position + Vector3(0, 0, 1))
		cam.current = true
		await _frames(4)
		root.get_texture().get_image().save_png("%s%02d_%s_%s_%s.png" % [out, i, c[0], c[1], c[3] if c[3] != "" else ("look" if c[4] != Vector2.ZERO else "open")])
		i += 1
		ch.queue_free()
		await _frames(2)
	# blink and preset switching back to the modelled eyes
	var ch2 := ToriyamaKitCharacter.new(); world.add_child(ch2)
	ch2.apply_recipe({"base": "M", "hair": {"cut": ""}, "eye_preset": "Anime_Heroine", "garments": []})
	ch2._update_anime_eye(1.0)
	_expect(int(ch2.anime_eye_materials[0].get_shader_parameter("frame_index")) == ToriyamaCharacter.ANIME_EYE_FRAMES.find("closed"), "blink closes the drawn eye")
	ch2._update_anime_eye(0.0)
	ch2.set_expression("Angry")
	_expect(float(ch2.anime_eye_materials[0].get_shader_parameter("fade")) < 1.0, "expression change starts a cross-fade")
	for k in 10:
		ch2._step_anime_eye_fade(0.016)
	_expect(is_equal_approx(float(ch2.anime_eye_materials[2].get_shader_parameter("fade")), 1.0), "cross-fade completes on eyes and brows")
	ch2.set_eye_preset("DQ8")
	_expect(not _mesh(ch2, "AE_Eye_L").visible and _mesh(ch2, "Eye_L").visible, "DQ8 preset restores the modelled eye")
	print("OUT ", out)
	print("ANIME_EYE_TEST ", ("FAILED: " + str(failures)) if failures else "ALL PASS")
	quit(1 if failures else 0)
