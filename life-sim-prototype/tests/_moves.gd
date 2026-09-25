extends SceneTree
## Phase 3 review: run, jump, sit and swim, rendered as frame strips so the arc can be judged, not just the pose.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38, -140, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.85, 0.87, 0.9)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://moves/")
	DirAccess.make_dir_recursive_absolute(out)
	var rig := CharacterRig.new(); world.add_child(rig)
	rig.set_toriyama_recipe(CreatorData.default_recipe())
	await _frames(12)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 40
	var side := func(): cam.global_position = Vector3(-3.0, 1.05, 0.0); cam.look_at(Vector3(0, 0.88, 0))
	var q34 := func(): cam.global_position = Vector3(-2.3, 1.15, -1.8); cam.look_at(Vector3(0, 0.88, 0))

	# --- run: settle, then 6 frames across one stride
	for i in 90: rig.animate(1.0 / 60.0, 8.5, true); await _frames(1)
	for i in 6:
		for j in 4: rig.animate(1.0 / 60.0, 8.5, true); await _frames(1)
		side.call(); await _frames(1)
		root.get_texture().get_image().save_png(out + "run_%d.png" % i)

	# --- jump: launch, rise, apex, fall, land, recover (vertical speed drives the pose)
	var vy := 7.0
	var steps := [[7.0, false], [4.2, false], [1.2, false], [-1.5, false], [-5.0, false], [0.0, true], [0.0, true]]
	for i in steps.size():
		vy = float(steps[i][0])
		var floored: bool = bool(steps[i][1])
		for j in 6: rig.animate(1.0 / 60.0, 3.0, floored, "normal", vy); await _frames(1)
		side.call(); await _frames(1)
		root.get_texture().get_image().save_png(out + "jump_%d.png" % i)

	# --- sit
	for i in 120: rig.animate(1.0 / 60.0, 0.0, true, "sit"); await _frames(1)
	for v in [["side", side], ["q34", q34]]:
		(v[1] as Callable).call(); await _frames(1)
		root.get_texture().get_image().save_png(out + "sit_%s.png" % v[0])

	# --- swim: 6 frames across one stroke
	for i in 90: rig.animate(1.0 / 60.0, 1.6, true, "swim"); await _frames(1)
	for i in 6:
		for j in 5: rig.animate(1.0 / 60.0, 1.6, true, "swim"); await _frames(1)
		side.call(); await _frames(1)
		root.get_texture().get_image().save_png(out + "swim_%d.png" % i)
	print("MOVES done -> ", out)
	quit()
