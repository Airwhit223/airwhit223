extends SceneTree
## Gaze: ToriyamaCharacter.look_target turns the eyes toward a target (drawn anime eye: iris slide; modelled eye:
## Look_* shapes), gives up when the target is behind, and in the real scene an NPC looks at the player walking up
## and during dialogue. Renders to user://gaze_test/.

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
	if mi == null: return -1.0
	var i := mi.find_blend_shape_by_name(shape)
	return mi.get_blend_shape_value(i) if i >= 0 else -1.0

func _settle(ch: ToriyamaCharacter) -> void:
	for k in 30:
		ch._update_gaze(1.0 / 60.0)

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://gaze_test/")
	DirAccess.make_dir_recursive_absolute(out)
	# --- unit: a lone character facing -Z; its left is -X -------------------------------------------------------
	var world := Node3D.new(); root.add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.27, 0.29, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	for preset in ["Anime_Heroine", "DQ8"]:
		var ch := ToriyamaKitCharacter.new(); world.add_child(ch)
		ch.apply_recipe({"base": "F", "hair": {"cut": ""}, "eye_preset": preset, "garments": []})
		ch.set_process(false)
		await _frames(3)
		var eye := ch.eye_world_position()
		_expect(eye.y > 1.2 and eye.y < 1.9, "%s: eye point at head height (%.2f m)" % [preset, eye.y])
		var target := Node3D.new(); world.add_child(target)
		ch.look_target = target
		target.global_position = eye + Vector3(-1.0, 0, -2.0)          # front-left
		_settle(ch)
		_expect(ch._gaze.x > 0.4, "%s: looks to its left (x=%.2f)" % [preset, ch._gaze.x])
		target.global_position = eye + Vector3(1.0, 0, -2.0)           # front-right
		_settle(ch)
		_expect(ch._gaze.x < -0.4, "%s: looks to its right (x=%.2f)" % [preset, ch._gaze.x])
		if preset == "DQ8":
			_expect(_shape(ch, "Eye_L", "Look_Right") > 0.4 and _shape(ch, "Eye_L", "Look_Left") == 0.0, "DQ8: Look_Right shape driven")
		else:
			_expect(float(ch.anime_eye_materials[0].get_shader_parameter("look").x) < -0.4, "anime: iris slides right")
		target.global_position = eye + Vector3(0, 0.9, -2.0)           # above
		_settle(ch)
		_expect(ch._gaze.y > 0.5 and absf(ch._gaze.x) < 0.1, "%s: looks up (y=%.2f)" % [preset, ch._gaze.y])
		target.global_position = eye + Vector3(0, 0, 2.0)             # behind: gives up, idle glance range
		ch._glance = Vector2.ZERO
		ch._glance_timer = 99.0
		_settle(ch)
		_expect(ch._gaze.length() < 0.1, "%s: ignores a target behind the head" % preset)
		ch.queue_free(); target.queue_free()
		await _frames(2)
	world.queue_free()
	await _frames(2)

	# --- in the world: an NPC notices the player walking up, and holds eye contact in dialogue ------------------
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(60)
	var player = root.get_tree().get_first_node_in_group("player")
	var npc = null
	for n in root.get_tree().get_nodes_in_group("npc"):
		if n.body and n.body.model:
			npc = n
			break
	_expect(npc != null, "found an NPC wearing a Toriyama model")
	if npc:
		var fwd: Vector3 = -npc.body.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var side := fwd.cross(Vector3.UP)
		npc.set_physics_process(false)          # hold them still for the check
		player.global_position = npc.global_position + fwd * 2.0 + side * 0.6
		await _frames(4)
		npc._gaze_timer = 0.0
		npc.set_physics_process(true)
		await _frames(2)
		npc.set_physics_process(false)
		_expect(npc.body.model.look_target == player, "NPC looks at the player standing in front of them")
		for k in 30:
			npc.body.model._update_gaze(1.0 / 60.0)
		var g: Vector2 = npc.body.model._gaze
		_expect(absf(g.x) > 0.05 and absf(g.x) < 1.0, "NPC's eyes turned toward the player (x=%.2f)" % g.x)
		# close-up of the NPC's face looking at the player
		var cam := Camera3D.new(); main.add_child(cam)
		var eye: Vector3 = npc.body.model.eye_world_position()
		cam.global_position = eye + fwd * 0.9 + Vector3(0, 0.02, 0)
		cam.look_at(eye)
		cam.current = true
		await _frames(6)
		root.get_texture().get_image().save_png(out + "npc_looks_at_player.png")
		# dialogue: they keep looking at the player even when the player steps out to the side
		player._talk_to(npc)
		player.global_position = npc.global_position + fwd * 1.5 - side * 1.6
		npc._gaze_timer = 0.0
		npc.set_physics_process(true)
		await _frames(2)
		npc.set_physics_process(false)
		_expect(npc.body.model.look_target == player, "NPC holds eye contact during dialogue")
		for k in 30:
			npc.body.model._update_gaze(1.0 / 60.0)
		await _frames(6)
		root.get_texture().get_image().save_png(out + "npc_dialogue_side.png")
		player._close_dialogue()
	print("OUT ", out)
	print("GAZE_TEST ", ("FAILED: " + str(failures)) if failures else "ALL PASS")
	quit(1 if failures else 0)
