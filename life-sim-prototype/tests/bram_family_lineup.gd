extends SceneTree
## Bram's family lineup (data/bram_family.gd recipes on the kit) - front and 3/4 renders to user://bram_family/ for
## comparing against docs/references/bram_family/.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 150, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.86, 0.82, 0.74)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.68, 0.64)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://bram_family/")
	DirAccess.make_dir_recursive_absolute(out)
	var defs: Array = BramFamily.build()
	var order := ["garrik", "bram", "lysa", "kip", "nana_ella", "grandpa_bram", "sergio"]
	var x := -((order.size() - 1) * 1.05) / 2.0
	for id in order:
		var d = defs.filter(func(e): return e.id == id)[0]
		var ch := ToriyamaKitCharacter.new()
		world.add_child(ch)
		ch.apply_recipe(d.recipe)
		ch.position = Vector3(x, 0, 0)
		ch.scale = Vector3.ONE * float(d.recipe.get("height", 1.0))
		ch.rotation.y = PI
		var l := Label3D.new(); l.text = d.first_name; l.font_size = 48; l.pixel_size = 0.004; l.position = Vector3(x, -0.15, 0)
		l.modulate = Color(0.1, 0.1, 0.1); l.outline_size = 0
		world.add_child(l)
		x += 1.05
		print("%s shape=%s" % [id, d.recipe.get("shape", {})])
	await _frames(30)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true
	cam.fov = 30
	cam.global_position = Vector3(0, 0.95, 8.2); cam.look_at(Vector3(0, 0.8, 0))
	await _frames(6)
	root.get_texture().get_image().save_png(out + "lineup_front.png")
	cam.global_position = Vector3(4.6, 1.2, 6.8); cam.look_at(Vector3(0, 0.8, 0))
	await _frames(6)
	root.get_texture().get_image().save_png(out + "lineup_34.png")
	print("LINEUP DONE")
	quit()
