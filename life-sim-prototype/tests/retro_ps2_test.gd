extends SceneTree
## Retro PS2 look check: boots main.tscn and saves a gameplay view and a close portrait of the player's Toriyama
## character under each RetroPS2 preset to user://retro_ps2_test/. Also checks the preset cycle and global params.

func _initialize() -> void:
	_run.call_deferred()

func _frames(n := 10) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(150)   # let every character shader variant finish compiling before capturing
	var retro = root.get_node("RetroPS2")
	var player: Node3D = root.get_tree().get_first_node_in_group("player")
	var rig = player.get_node("Body")
	var out := ProjectSettings.globalize_path("user://retro_ps2_test/")
	DirAccess.make_dir_recursive_absolute(out)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var failures := 0
	var game_cam := root.get_viewport().get_camera_3d()
	var close := Camera3D.new()
	player.add_child(close)
	var fwd: Vector3 = -rig.global_transform.basis.z
	close.global_position = rig.global_position + fwd * 1.15 + Vector3(0, 1.6, 0)
	close.look_at(rig.global_position + Vector3(0, 1.5, 0))
	for p in [&"off", &"soft", &"ps2"]:
		retro.apply(p)
		var amount: float = retro.globals[&"retro_ps2"]
		var expect := 0.0 if p == &"off" else 1.0
		if not is_equal_approx(amount, expect):
			failures += 1
			print("RETRO FAIL preset=", p, " retro_ps2=", amount)
		game_cam.current = true
		await _frames(20)
		root.get_texture().get_image().save_png(out + "game_%s.png" % p)
		close.current = true
		await _frames(20)
		root.get_texture().get_image().save_png(out + "portrait_%s.png" % p)
		print("RETRO preset=", p, " scale=", root.scaling_3d_scale, " retro_ps2=", amount)
	retro.apply(&"ps2")
	retro.cycle()
	if retro.preset != &"off":
		failures += 1
		print("RETRO FAIL cycle from ps2 gave ", retro.preset)
	retro.apply(&"soft")
	print("RETRO_TEST ", "PASS" if failures == 0 else "FAIL (%d)" % failures, " out=", out)
	quit(1 if failures else 0)
