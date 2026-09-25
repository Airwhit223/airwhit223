extends SceneTree
## In-world check for the Toriyama character on the player: boots main.tscn, walks the player, advances game days
## through the hair growth states, services the hair, and saves screenshots to user://toriyama_test/.

func _initialize() -> void:
	_run.call_deferred()

func _frames(n := 10) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(40)
	var player: Node3D = root.get_tree().get_first_node_in_group("player")
	var rig = player.get_node("Body")
	var ok: bool = rig.model != null
	print("TR_INGAME model=", ok, " hair=", rig.model.hair_state if ok else "-")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://toriyama_test"))
	var out := ProjectSettings.globalize_path("user://toriyama_test/")
	var cam: Camera3D = player.get_node("CameraRig/SpringArm3D/Camera3D")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.get_texture().get_image().save_png(out + "idle.png")
	Input.action_press("move_forward")
	await _frames(45)
	root.get_texture().get_image().save_png(out + "walk_a.png")
	Input.action_release("move_forward")
	Input.action_press("move_left")
	await _frames(25)
	root.get_texture().get_image().save_png(out + "walk_b.png")
	Input.action_release("move_left")
	await _frames(40)
	# close front view for hair states
	var close := Camera3D.new()
	player.add_child(close)
	var fwd: Vector3 = -rig.global_transform.basis.z
	close.global_position = rig.global_position + fwd * 1.3 + Vector3(0, 1.62, 0)
	close.look_at(rig.global_position + Vector3(0, 1.55, 0))
	close.current = true
	var tm = root.get_node("TimeManager")
	var days: float = rig.model.manifest["hair"]["days_to_overgrown"]
	for d in [0, int(days * 0.6), int(days)]:
		tm.day_changed.emit(d, 0)
		await _frames(8)
		print("TR_INGAME day=", d, " state=", rig.model.hair_state)
		root.get_texture().get_image().save_png(out + "hair_day%02d.png" % d)
	var receipt: Dictionary = rig.model.perform_service("stylist", "restyle", float(days), func(_n, cost): return cost["amount"] <= 100)
	await _frames(8)
	print("TR_INGAME service=", receipt, " state=", rig.model.hair_state)
	root.get_texture().get_image().save_png(out + "hair_after_service.png")
	# NPCs: every resident with a roster entry wears their Toriyama model
	var npcs := root.get_tree().get_nodes_in_group("npc")
	if npcs.is_empty():
		npcs = main.find_children("*", "CharacterBody3D", true, false).filter(func(n): return n.has_method("setup") and n != player)
	for npc in npcs:
		var r = npc.get_node_or_null("Body")
		var id: String = npc.definition.id if "definition" in npc and npc.definition else String(npc.name)
		var wanted := ToriyamaRoster.for_npc(id)
		var has_model: bool = r != null and r.model != null
		print("TR_INGAME npc=", id, " model=", r.model.character_name if has_model else "none", " expected=", wanted if wanted != "" else "none")
		if has_model:
			var c2 := Camera3D.new()
			npc.add_child(c2)
			var f2: Vector3 = -r.global_transform.basis.z
			c2.global_position = r.global_position + f2 * 2.6 + Vector3(0.6, 1.3, 0)
			c2.look_at(r.global_position + Vector3(0, 1.0, 0))
			c2.current = true
			await _frames(8)
			root.get_texture().get_image().save_png(out + "npc_%s.png" % id)
			c2.queue_free()
	print("TR_INGAME shots=", out)
	quit(0)
