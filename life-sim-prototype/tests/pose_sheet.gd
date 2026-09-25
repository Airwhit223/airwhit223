extends SceneTree
## Every animation state the rig can be in, side-on and 3/4, so a bad pose can be SEEN rather than argued about.
## (character/character_rig.gd's own note: measure the sign with a render, reasoning from the rest pose gets it wrong.)
## Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 4) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

const STATES := [
	# label,           speed, on_floor, state,    vertical, settle seconds
	["idle",            0.0, true,  "normal", 0.0, 1.2],
	["walk",            4.5, true,  "normal", 0.0, 1.2],
	["run",             8.5, true,  "normal", 0.0, 1.2],
	["jump up",         3.0, false, "normal", 6.0, 0.5],
	["falling",         3.0, false, "normal", -6.0, 0.5],
	["sit",             0.0, true,  "sit",    0.0, 1.2],
	["hold ball",       0.0, true,  "hold",   0.0, 1.2],
	["skate",           7.0, true,  "ride",   0.0, 1.2],
	["swim",            2.6, true,  "swim",   0.0, 2.0],
	["katana guard",    0.0, true,  "katana", 0.0, 1.2],
	["katana cut",      0.0, true,  "katana", 0.0, 1.2],
	["dual guard",      0.0, true,  "dual_katana", 0.0, 1.2],
	["dual cut",        0.0, true,  "dual_katana", 0.0, 1.2],
]

func _run() -> void:
	var out: String = ProjectSettings.globalize_path("user://poses/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 25, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.58, 0.63, 0.70)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.79, 0.82)
	world.add_child(env)
	if root.has_node("RetroPS2"): root.get_node("RetroPS2").apply(&"off")
	var rig := CharacterRig.new()
	rig.toriyama_recipe = CreatorData.default_recipe()
	world.add_child(rig)
	await _frames(20)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 40
	for entry in STATES:
		var label: String = entry[0]
		rig.swing = 0.55 if label.ends_with("cut") else 0.0
		var t := 0.0
		while t < float(entry[5]):
			rig.animate(1.0 / 60.0, float(entry[1]), bool(entry[2]), String(entry[3]), float(entry[4]))
			t += 1.0 / 60.0
		for view in [["side", Vector3(3.1, 1.05, 0.0)], ["q34", Vector3(2.2, 1.25, -2.2)]]:
			cam.global_position = Vector3(view[1])
			cam.look_at(Vector3(0, 0.95, 0))
			await _frames(3)
			root.get_texture().get_image().save_png("%s%s_%s.png" % [out, label.replace(" ", "_"), view[0]])
	print("OUT ", out)
	quit()
