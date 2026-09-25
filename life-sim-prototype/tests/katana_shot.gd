extends SceneTree
## Katana in game: carried on the hip, across the back, and drawn into the right hand. Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()

func _frames(n := 4) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _shot(cam: Camera3D, path: String, from: Vector3, aim: Vector3) -> void:
	cam.global_position = from
	cam.look_at(aim)
	cam.current = true
	await _frames(3)
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://gear/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	world.add_child(env)
	if root.has_node("RetroPS2"):
		root.get_node("RetroPS2").apply(&"off")
	var cam := Camera3D.new(); world.add_child(cam)
	var rig := CharacterRig.new()
	var r := CreatorData.default_recipe()
	r["weapon"] = {"part": "Classic", "carry": "hip", "drawn": false}
	rig.toriyama_recipe = r
	world.add_child(rig)
	await _frames(10)
	for k in 20: rig.animate(1.0 / 60.0, 0.0, true, "normal")
	var kit: ToriyamaKitCharacter = null
	for c in rig.find_children("*", "ToriyamaKitCharacter", true, false):
		kit = c
	print("KIT_FOUND ", kit != null)
	for carry in ["hip", "back"]:
		if kit: kit.set_weapon("Classic", carry)
		await _frames(6)
		await _shot(cam, "%skatana_%s_34.png" % [out, carry], Vector3(1.4, 1.25, -1.5), Vector3(0, 0.95, 0))
		await _shot(cam, "%skatana_%s_side.png" % [out, carry], Vector3(2.1, 1.0, 0), Vector3(0, 0.95, 0))
		await _shot(cam, "%skatana_%s_back.png" % [out, carry], Vector3(0.9, 1.25, 1.9), Vector3(0, 0.95, 0))
	if kit:
		kit.set_weapon("Classic", "hip")
		kit.set_weapon_drawn(true)
		await _frames(6)
		await _shot(cam, "%skatana_drawn.png" % out, Vector3(1.8, 1.25, -1.8), Vector3(-0.2, 0.95, -0.2))
	print("OUT ", out)
	quit()
