extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://underworld/")
	DirAccess.make_dir_recursive_absolute(out)
	var packed: PackedScene = load("res://world/sky_island_planet/underworld/underworld.tscn")
	if packed == null:
		print("LOAD FAILED"); quit(); return
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.03, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.42, 0.34, 0.58)
	env.environment.ambient_light_energy = 1.5
	world.add_child(env)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-55, -130, 0)
	key.light_energy = 0.7; key.light_color = Color(0.72, 0.66, 0.95)
	world.add_child(key)
	await _frames(20)
	print("UNDERWORLD loaded, children=", world.get_child_count())
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 62
	var shots := {
		"village": [Vector3(0, 26, 62), Vector3(0, 4, -8)],
		"hearth": [Vector3(16, 6, 24), Vector3(0, 2, 0)],
		"ember": [Vector3(0, 18, -78), Vector3(0, 2, -120)],
		"aether": [Vector3(-70, 16, -10), Vector3(-114, 4, -37)],
		"cavern": [Vector3(120, 44, 150), Vector3(0, 8, 0)],
	}
	for k in shots:
		cam.global_position = shots[k][0]; cam.look_at(shots[k][1])
		await _frames(4)
		root.get_texture().get_image().save_png(out + k + ".png")
	print("SHOTS done -> ", out)
	quit()
