extends SceneTree
## The eight modelled breeds in a line with a 1.78 m reference figure for scale. Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 6) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://gear/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.70)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.77, 0.80)
	world.add_child(env)
	if root.has_node("RetroPS2"): root.get_node("RetroPS2").apply(&"off")
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.42, 0.48, 0.40); ground.material_override = gm
	world.add_child(ground)
	# a person-sized reference so the pets can be judged against the player
	var person: Node3D = load("res://characters/hoodie_guy.glb").instantiate()
	person.position = Vector3(-6.2, 0, 0); person.rotation.y = PI
	world.add_child(person)
	var breeds := ["husky", "husky_copper", "husky_silver", "husky_white",
		"maine_coon", "maine_coon_smoke", "maine_coon_ginger", "maine_coon_cream"]
	for i in breeds.size():
		var p: Node3D = load("res://pets/%s.tscn" % breeds[i]).instantiate()
		world.add_child(p)
		p.global_position = Vector3(-4.6 + i * 1.35, 0, 0)
		p.rotation.y = deg_to_rad(200)
		p.set_physics_process(false)
	var cam := Camera3D.new(); world.add_child(cam)
	cam.position = Vector3(-1.0, 1.9, 7.4); cam.look_at(Vector3(-1.0, 0.7, 0)); cam.fov = 46; cam.current = true
	await _frames(24)
	root.get_texture().get_image().save_png(out + "pets_ingame.png")
	print("OUT ok")
	quit()
