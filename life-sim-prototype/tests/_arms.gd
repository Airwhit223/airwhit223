extends SceneTree
## Idle arm pose: elbow sign vs wrist yaw, judged where it actually matters - standing still, seen from the side.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38, -140, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.86, 0.88, 0.9)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://arms/")
	DirAccess.make_dir_recursive_absolute(out)
	var rig := CharacterRig.new(); world.add_child(rig)
	rig.set_toriyama_recipe(CreatorData.default_recipe())
	await _frames(12)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 26
	for elbow_sign in [1.0, -1.0]:
		for wrist in [1.25, 0.35]:
			for i in 40:
				rig.animate(1.0 / 60.0, 0.0, true)
				# override after animate, the way the rig itself would set them
				for side in ["l", "r"]:
					var sx := -1.0 if side == "l" else 1.0
					var e: Node3D = rig._pivots["elbow_" + side]
					e.rotation.x = elbow_sign * 0.42
					var h: Node3D = rig._pivots.get("hand_" + side)
					if h: h.rotation.y = sx * wrist
				rig.model.sync_from_rig(rig, rig._pivots, 0.94)
				await _frames(1)
			var tag := "%s_wrist%02d" % ["pos" if elbow_sign > 0.0 else "neg", int(wrist * 100)]
			for v in [["side", Vector3(-2.6, 1.05, 0.1)], ["front", Vector3(0.0, 1.05, -2.6)]]:
				cam.global_position = v[1]; cam.look_at(Vector3(0, 0.95, 0))
				await _frames(2)
				root.get_texture().get_image().save_png(out + "%s_%s.png" % [tag, v[0]])
	print("ARMS done -> ", out)
	quit()
