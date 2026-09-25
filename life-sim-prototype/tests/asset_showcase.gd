extends SceneTree
## Everything imported, lined up: the 8 pet coats playing idle, the 5 characters, and a toon-water plane behind them.
## Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 6) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://gear/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-42, 28, 0); sun.light_energy = 1.2
	world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.75, 0.80)
	world.add_child(env)
	if root.has_node("RetroPS2"): root.get_node("RetroPS2").apply(&"off")

	# toon water behind everything, on a plane with enough vertices for the waves
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60); plane.subdivide_width = 100; plane.subdivide_depth = 100
	water.mesh = plane
	water.material_override = load("res://water/toon_water.tres")
	water.position = Vector3(0, -0.9, -8)
	world.add_child(water)

	var pets := ["husky", "husky_copper", "husky_silver", "husky_white",
		"maine_coon", "maine_coon_silver", "maine_coon_ginger", "maine_coon_cream"]
	for i in pets.size():
		var n: Node3D = load("res://pets/%s.glb" % pets[i]).instantiate()
		n.position = Vector3(-5.6 + i * 1.6, 0, 1.6)
		n.rotation.y = deg_to_rad(155)
		world.add_child(n)
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("idle")
	var chars := ["hoodie_guy", "hoodie_guy_black", "casual_girl", "egyptian_queen", "egyptian_queen_meshy"]
	for i in chars.size():
		var n: Node3D = load("res://characters/%s.glb" % chars[i]).instantiate()
		n.position = Vector3(-4.4 + i * 2.2, 0, -1.4)
		n.rotation.y = deg_to_rad(180)
		world.add_child(n)

	var cam := Camera3D.new(); world.add_child(cam)
	cam.position = Vector3(0, 2.6, 8.2); cam.look_at(Vector3(0, 0.9, 0)); cam.current = true
	cam.fov = 48
	await _frames(20)
	root.get_texture().get_image().save_png(out + "asset_showcase.png")
	cam.position = Vector3(0, 1.1, 4.4); cam.look_at(Vector3(0, 0.55, 1.0))
	await _frames(8)
	root.get_texture().get_image().save_png(out + "asset_showcase_pets.png")
	print("OUT ", out)
	quit()
