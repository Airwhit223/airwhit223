extends SceneTree
## Talking mouths: ToriyamaCharacter.talk() flicks the drawn mouth through speaking frames and pulses the modelled
## mouth's own shapes (eyes untouched), then settles back; in the real scene an NPC talks when the player opens a
## dialogue and stops when it closes. Saves a strip of drawn talk frames to user://talk_test/.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _shape(ch: Node, mesh: String, shape: String) -> float:
	var mi := ch.find_child(mesh, true, false) as MeshInstance3D
	var i := mi.find_blend_shape_by_name(shape) if mi else -1
	return mi.get_blend_shape_value(i) if i >= 0 else -1.0

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://talk_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.27, 0.29, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	_expect(ToriyamaCharacter.talk_seconds("Hi.") == 0.8 and ToriyamaCharacter.talk_seconds("x".repeat(40)) > 2.0,
		"line length sets how long they talk")

	# drawn mouth
	var ch := ToriyamaKitCharacter.new(); world.add_child(ch)
	ch.apply_recipe({"base": "F", "hair": {"cut": ""}, "eye_preset": "Anime_Heroine", "garments": []})
	ch.set_process(false)
	var m: ShaderMaterial = ch.anime_mouth_materials[0]
	ch.talk(1.0)
	var seen := {}
	var changes := 0
	var last := -1
	for k in 60:                                        # 1 s at 60 fps
		ch._update_talk(1.0 / 60.0)
		var f := int(m.get_shader_parameter("frame_index"))
		seen[ToriyamaCharacter.ANIME_MOUTH_FRAMES[f]] = true
		if f != last:
			changes += 1
			last = f
	_expect(seen.has("talk_a") and (seen.has("talk_e") or seen.has("talk_o")), "drawn mouth uses the talk frames: %s" % [seen.keys()])
	_expect(changes >= 8 and changes <= 32, "mouth opens and closes per syllable (%d changes in 1 s)" % changes)
	for k in 20:
		ch._update_talk(1.0 / 60.0)
	_expect(not ch.is_talking() and int(m.get_shader_parameter("frame_index")) == 0, "mouth settles back to neutral")
	# shots mid-talk
	var cam := Camera3D.new(); world.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.22
	var eye := ch.eye_world_position()
	cam.global_position = eye + Vector3(0, -0.035, -1.5)
	cam.look_at(cam.global_position + Vector3(0, 0, 1))
	cam.current = true
	for fr in ["neutral", "talk_a", "talk_e", "talk_o", "small"]:
		ch._syllable = fr
		ch._talk_left = 1.0
		ch._apply_talk()
		ch._step_anime_eye_fade(1.0)
		await _frames(4)
		root.get_texture().get_image().save_png("%s%s.png" % [out, fr])
	ch.stop_talking(); ch._update_talk(0.016)
	ch.queue_free()
	await _frames(2)

	# modelled mouth (DQ8 preset): the Mouth mesh's own shapes pulse, the eyes do not
	var ch2 := ToriyamaKitCharacter.new(); world.add_child(ch2)
	ch2.apply_recipe({"base": "M", "hair": {"cut": ""}, "eye_preset": "DQ8", "garments": []})
	ch2.set_process(false)
	ch2.talk(1.0)
	var mouth_max := 0.0
	var eye_max := 0.0
	for k in 60:
		ch2._update_talk(1.0 / 60.0)
		mouth_max = maxf(mouth_max, maxf(_shape(ch2, "Mouth", "Expr_Laughing"), _shape(ch2, "Mouth", "Expr_Surprised")))
		eye_max = maxf(eye_max, maxf(_shape(ch2, "Eye_L", "Expr_Laughing"), _shape(ch2, "Eye_L", "Expr_Surprised")))
	_expect(mouth_max > 0.2, "modelled mouth opens while talking (%.2f)" % mouth_max)
	_expect(eye_max <= 0.0, "the eyes' shapes of the same name are left alone")
	for k in 20:
		ch2._update_talk(1.0 / 60.0)
	_expect(_shape(ch2, "Mouth", "Expr_Laughing") == 0.0 and _shape(ch2, "Mouth", "Expr_Surprised") == 0.0, "modelled mouth closes after")
	ch2.queue_free()
	world.queue_free()
	await _frames(2)

	# voice: a line becomes a syllable plan; same word -> same syllables; questions rise; mouth follows the vowels
	var v := ToriyamaVoice.for_identity("Test", false)
	var p1 := v.plan("Hello there.")
	var p2 := v.plan("Hello friend?")
	_expect(p1.size() >= 3 and p1[0]["name"] == p2[0]["name"] and p1[1]["name"] == p2[1]["name"], "the same word always babbles the same (%s)" % [p1.map(func(x): return x["name"])])
	_expect(float(p2[-1]["pitch"]) > float(p1[-1]["pitch"]) + 0.05, "a question rises at the end")
	_expect(p1[0]["mouth"] == "talk_e" and String(p1[0]["name"]).ends_with("e"), "vowel of 'hello' -> e sound and e mouth")
	_expect(ToriyamaVoice.for_character("June").pitch > ToriyamaVoice.for_character("Tomas").pitch, "feminine voices sit higher")
	_expect(ToriyamaVoice.sample("ba") != null and ToriyamaVoice.sample("ku") != null, "syllable bank loads")
	var ch3 := ToriyamaKitCharacter.new(); root.add_child(ch3)
	ch3.apply_recipe({"base": "F", "hair": {"cut": ""}, "eye_preset": "Anime_Heroine", "garments": []})
	ch3.set_process(false)
	_expect(ch3.voice != null, "kit characters get a voice")
	ch3.talk_line("Are you heading to the skate shop later?")
	var t := 0.0
	var played := 0
	var mouths := {}
	var last_stream = null
	while ch3.is_talking() and t < 6.0:
		ch3._update_talk(1.0 / 60.0)
		t += 1.0 / 60.0
		mouths[ch3._syllable] = true
		if ch3._voice_player and ch3._voice_player.stream != last_stream:
			played += 1
			last_stream = ch3._voice_player.stream
	_expect(played >= 8, "a syllable sound per syllable (%d)" % played)
	_expect(t > 1.0 and t < 4.0, "the line takes a speaking length (%.2f s)" % t)
	_expect(mouths.has("talk_a") and mouths.has("small") and mouths.has("neutral"), "mouth opens, closes between syllables and rests between words")
	ch3.queue_free()

	# in the world: dialogue makes the NPC talk, closing it stops them
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(60)
	var player = root.get_tree().get_first_node_in_group("player")
	var npc = null
	for n in root.get_tree().get_nodes_in_group("npc"):
		if n.body and n.body.model:
			npc = n
			break
	if npc:
		player._talk_to(npc)
		_expect(npc.body.model.is_talking(), "NPC talks when the player opens a dialogue")
		player._close_dialogue()
		_expect(not npc.body.model.is_talking(), "NPC stops when the dialogue closes")
	else:
		_expect(false, "found an NPC")
	print("OUT ", out)
	print("TALK_TEST ", ("FAILED: " + str(failures)) if failures else "ALL PASS")
	quit(1 if failures else 0)
