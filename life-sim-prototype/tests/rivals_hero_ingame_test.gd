extends SceneTree
## Rolling Tides cast in the world: boots main.tscn, checks the six rivals spawned as NPCs wearing their Toriyama
## models, checks the player's hero look and the F9 look cycle, and saves portraits to user://rivals_hero_test/.

const RIVALS := {"jace": "Jace", "theo": "Theo", "blair": "Blair", "kira": "Kira", "maya_reyes": "Maya", "jones": "Jones"}

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _frames(n := 10) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _portrait(host: Node3D, rig: Node3D, file: String, cam: Camera3D) -> void:
	var fwd: Vector3 = -rig.global_transform.basis.z
	cam.global_position = rig.global_position + fwd * 1.5 + Vector3(0, 1.45, 0)
	cam.look_at(rig.global_position + Vector3(0, 1.2, 0))
	cam.current = true
	await _frames(12)
	root.get_texture().get_image().save_png(file)

func _run() -> void:
	# start from the default look, whatever an earlier play session saved. A saved character also keeps the
	# creator from opening over the world (a brand new game opens it) - that flow has its own test.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ToriyamaRoster.PLAYER_LOOK_SAVE))
	ToriyamaRoster.save_recipe(CreatorData.default_recipe())
	var ws := root.get_node("WorldState")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(150)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var out := ProjectSettings.globalize_path("user://rivals_hero_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new()
	main.add_child(cam)

	var rivals := root.get_tree().get_nodes_in_group("rival")
	_expect(rivals.size() == 6, "six rivals spawned (got %d)" % rivals.size())
	for npc in rivals:
		var id: String = npc.definition.id
		var rig = npc.get_node("Body")
		var want: String = RIVALS.get(id, "?")
		_expect(rig.model != null and rig.toriyama_character == want, "%s wears %s" % [id, want])
		_expect(ws.has_location(npc.definition.home_location_id), "%s has a home spot" % id)
		# stand them in a clear spot for the portrait, facing the camera side
		npc.set_physics_process(false)
		npc.global_position = Vector3(-8, 0.05, 8)
		npc.rotation = Vector3.ZERO
		await _portrait(npc, rig, out + "rival_%s.png" % id, cam)
		npc.set_physics_process(true)
		npc.global_position = ws.get_location_position(npc.definition.home_location_id)

	var player: Node3D = root.get_tree().get_first_node_in_group("player")
	var body = player.get_node("Body")
	_expect(body.model is ToriyamaKitCharacter, "player starts as their created character")
	ToriyamaRoster.clear_recipe()
	body.set_toriyama_character(ToriyamaRoster.DEFAULT_PLAYER_LOOK)
	await _frames(20)
	_expect(body.toriyama_character == ToriyamaRoster.DEFAULT_PLAYER_LOOK and body.model != null, "preset look loads (%s)" % body.toriyama_character)
	player.grant_skateboard()
	await _frames(4)
	player.global_position = Vector3(-8, 0.05, 8)
	player.rotation = Vector3.ZERO
	var looks := ToriyamaRoster.available_player_looks()
	for i in looks.size():
		var look: String = body.toriyama_character
		await _portrait(player, body, out + "player_%s.png" % look, cam)
		player.cycle_look()
		await _frames(6)
		var expected: String = looks[(i + 1) % looks.size()]
		_expect(body.toriyama_character == expected and body.model != null, "F9 look cycle %s -> %s" % [look, expected])
		var back: Node3D = body.get_socket("back")
		_expect(is_instance_valid(back) and back.is_inside_tree() and player.skateboard_mesh.get_parent() == back,
			"skateboard still on the back socket after swap to %s" % expected)
	_expect(FileAccess.file_exists(ToriyamaRoster.PLAYER_LOOK_SAVE), "look choice saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ToriyamaRoster.PLAYER_LOOK_SAVE))
	print("RIVALS_HERO_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures), " out=", out)
	quit(0 if failures.is_empty() else 1)
